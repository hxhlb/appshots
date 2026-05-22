import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppshotsModel()
    private let frontmostTracker = FrontmostAppTracker()
    private let captureAnimator = AppshotCaptureAnimator()
    private var hotKeyMonitor: OptionPairHotKeyMonitor?
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        frontmostTracker.start()
        model.frontmostTracker = frontmostTracker
        model.playCaptureAnimation = { [weak self] record in
            guard let self else { return }
            captureAnimator.animate(
                record: record,
                destinationPoint: statusItemIconCenterPoint()
            )
        }
        model.startSession()
        _ = AppshotsUpdateManager.shared

        setupStatusItem()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.setupHotKeyMonitor()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyMonitor?.stop()
        frontmostTracker.stop()
        model.endSession()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "camera.viewfinder",
            accessibilityDescription: "Appshots"
        )
        item.button?.target = self
        item.button?.action = #selector(togglePopover(_:))
        statusItem = item
    }

    private func ensurePopover() -> NSPopover {
        if let popover {
            return popover
        }

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 400, height: 620)
        popover.contentViewController = NSHostingController(
            rootView: AppshotsPopoverView(model: model)
        )
        self.popover = popover
        return popover
    }

    private func setupHotKeyMonitor() {
        guard hotKeyMonitor == nil else { return }

        let monitor = OptionPairHotKeyMonitor { [weak self] in
            Task { @MainActor in
                self?.model.captureFrontmostApp()
            }
        }
        monitor.start()
        hotKeyMonitor = monitor
    }

    @objc
    private func togglePopover(_ sender: Any?) {
        let popover = ensurePopover()
        model.refreshPermissions()

        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        let popover = ensurePopover()
        guard let button = statusItem?.button, popover.isShown == false else {
            return
        }

        model.refreshPermissions()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func statusItemIconCenterPoint() -> CGPoint? {
        guard let button = statusItem?.button,
              let window = button.window
        else {
            return nil
        }

        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        let buttonFrameOnScreen = window.convertToScreen(buttonFrameInWindow)
        return CGPoint(x: buttonFrameOnScreen.midX, y: buttonFrameOnScreen.midY)
    }
}
