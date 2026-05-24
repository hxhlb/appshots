import AppKit

enum AppshotsHotKey: String, CaseIterable, Codable, Identifiable {
    case command
    case option
    case shift
    case none

    var id: String { rawValue }

    static let defaultValue: AppshotsHotKey = .option

    var displayText: String {
        switch self {
        case .command:
            "⌘ + ⌘"
        case .option:
            "⌥ + ⌥"
        case .shift:
            "⇧ + ⇧"
        case .none:
            "None"
        }
    }

    var instructionText: String {
        switch self {
        case .command:
            "Press both ⌘ keys simultaneously"
        case .option:
            "Press both ⌥ keys simultaneously"
        case .shift:
            "Press both ⇧ keys simultaneously"
        case .none:
            "Hotkey disabled"
        }
    }

    var encodedString: String {
        rawValue
    }

    private var requiredMasks: (left: UInt, right: UInt)? {
        // Device-specific modifier masks from IOLLEvent.h.
        switch self {
        case .command:
            (left: 0x00000008, right: 0x00000010)
        case .option:
            (left: 0x00000020, right: 0x00000040)
        case .shift:
            (left: 0x00000002, right: 0x00000004)
        case .none:
            nil
        }
    }

    private static let modifierDeviceMask: UInt =
        0x00000001 | // left control
        0x00002000 | // right control
        0x00000002 | // left shift
        0x00000004 | // right shift
        0x00000008 | // left command
        0x00000010 | // right command
        0x00000020 | // left option
        0x00000040   // right option

    static func decode(from rawValue: String?) -> AppshotsHotKey {
        guard let rawValue else {
            return .defaultValue
        }

        if let hotKey = AppshotsHotKey(rawValue: rawValue) {
            return hotKey
        }

        return decodeLegacyJSON(from: rawValue) ?? .defaultValue
    }

    private static func decodeLegacyJSON(from rawValue: String) -> AppshotsHotKey? {
        guard let data = rawValue.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        if let modifierPair = object["modifierPair"] as? String {
            return AppshotsHotKey(rawValue: modifierPair)
        }

        if let modifierKeys = object["modifierKeys"] as? [String] {
            let keySet = Set(modifierKeys)
            if keySet == ["leftCommand", "rightCommand"] {
                return .command
            }
            if keySet == ["leftOption", "rightOption"] {
                return .option
            }
            if keySet == ["leftShift", "rightShift"] {
                return .shift
            }
        }

        return nil
    }

    func matches(_ event: NSEvent) -> Bool {
        guard event.type == .flagsChanged,
              let requiredMasks
        else {
            return false
        }

        let expected = requiredMasks.left | requiredMasks.right
        let pressed = event.modifierFlags.rawValue & Self.modifierDeviceMask
        return pressed == expected
    }
}

@MainActor
final class AppshotsHotKeyMonitor {
    private var hotKey: AppshotsHotKey
    private let onTrigger: @MainActor () -> Void
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var triggeredWhileModifierPairDown = false

    init(
        hotKey: AppshotsHotKey,
        onTrigger: @escaping @MainActor () -> Void
    ) {
        self.hotKey = hotKey
        self.onTrigger = onTrigger
    }

    func updateHotKey(_ hotKey: AppshotsHotKey) {
        guard self.hotKey != hotKey else { return }
        self.hotKey = hotKey
        triggeredWhileModifierPairDown = false
    }

    func start() {
        guard globalMonitor == nil, localMonitor == nil else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                self?.handle(event)
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
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
        let isDown = hotKey.matches(event)
        if isDown, triggeredWhileModifierPairDown == false {
            triggeredWhileModifierPairDown = true
            onTrigger()
        } else if isDown == false {
            triggeredWhileModifierPairDown = false
        }
    }
}
