import AppKit

@MainActor
final class OptionPairHotKeyMonitor {
    private let onTrigger: @MainActor () -> Void
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var triggeredWhileBothDown = false

    private let leftOptionMask: UInt = 0x00000020
    private let rightOptionMask: UInt = 0x00000040

    init(onTrigger: @escaping @MainActor () -> Void) {
        self.onTrigger = onTrigger
    }

    func start() {
        guard globalMonitor == nil, localMonitor == nil else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                self?.handle(event)
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                self?.handle(event)
            }
            return event
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handle(_ event: NSEvent) {
        let raw = event.modifierFlags.rawValue
        let leftDown = (raw & leftOptionMask) != 0
        let rightDown = (raw & rightOptionMask) != 0
        let bothDown = leftDown && rightDown

        if bothDown, triggeredWhileBothDown == false {
            triggeredWhileBothDown = true
            onTrigger()
        } else if bothDown == false {
            triggeredWhileBothDown = false
        }
    }
}
