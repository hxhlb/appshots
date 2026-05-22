import AppKit

@MainActor
final class AppshotCaptureAnimator {
    private var activeWindows: [NSWindow] = []

    func animate(record: AppshotRecord, destinationPoint: CGPoint?) {
        guard let screenshotURL = record.screenshotURL,
              let image = NSImage(contentsOf: screenshotURL)
        else {
            return
        }

        let startFrame = startFrame(for: record, image: image)
        guard startFrame.width > 8, startFrame.height > 8 else {
            return
        }

        let destination = destinationPoint ?? fallbackDestinationPoint(from: startFrame)
        let finalSize = CGSize(width: 28, height: 28)
        let endFrame = CGRect(
            x: destination.x - finalSize.width / 2,
            y: destination.y - finalSize.height / 2,
            width: finalSize.width,
            height: finalSize.height
        )

        let overlayView = AppshotCaptureOverlayView(frame: CGRect(origin: .zero, size: startFrame.size))
        overlayView.image = image

        let window = NSWindow(
            contentRect: startFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = .clear
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.contentView = overlayView
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isOpaque = false
        window.level = .screenSaver
        window.alphaValue = 1

        activeWindows.append(window)
        window.orderFrontRegardless()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self, weak window, weak overlayView] in
            guard let self,
                  let window,
                  let overlayView
            else {
                return
            }

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.36
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(endFrame, display: true)
                overlayView.flashView.animator().alphaValue = 0
            } completionHandler: {
                Task { @MainActor in
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = 0.07
                        window.animator().alphaValue = 0
                    } completionHandler: {
                        Task { @MainActor in
                            window.orderOut(nil)
                            self.activeWindows.removeAll { $0 === window }
                        }
                    }
                }
            }
        }
    }

    private func startFrame(for record: AppshotRecord, image: NSImage) -> CGRect {
        if let frame = appKitFrame(fromAXFrame: record.windowFrame),
           frame.isUsableForAppshotAnimation {
            return frame
        }

        let screenFrame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1280, height: 800)
        let imageSize = image.size
        let maxWidth = screenFrame.width * 0.72
        let maxHeight = screenFrame.height * 0.72
        let scale = min(maxWidth / max(imageSize.width, 1), maxHeight / max(imageSize.height, 1), 1)
        let size = CGSize(width: max(imageSize.width * scale, 240), height: max(imageSize.height * scale, 160))
        return CGRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private func fallbackDestinationPoint(from startFrame: CGRect) -> CGPoint {
        let screen = NSScreen.screens.first { $0.frame.intersects(startFrame) } ?? NSScreen.main
        let frame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1280, height: 800)
        return CGPoint(
            x: frame.maxX - frame.width * 0.30,
            y: frame.maxY - frame.height * 0.30
        )
    }

    private func appKitFrame(fromAXFrame axFrame: CGRect) -> CGRect? {
        guard axFrame.isUsableForAppshotAnimation else {
            return nil
        }

        guard let space = displaySpace(containingAXPoint: CGPoint(x: axFrame.midX, y: axFrame.midY)) else {
            return axFrame
        }

        let x = space.appKitFrame.minX + (axFrame.minX - space.axFrame.minX)
        let y = space.appKitFrame.maxY - (axFrame.maxY - space.axFrame.minY)
        return CGRect(x: x, y: y, width: axFrame.width, height: axFrame.height)
    }

    private func displaySpace(containingAXPoint point: CGPoint) -> DisplaySpace? {
        let spaces = NSScreen.screens.compactMap(DisplaySpace.init(screen:))
        return spaces.first { $0.axFrame.contains(point) }
            ?? spaces.min {
                $0.axFrame.distanceSquared(to: point) < $1.axFrame.distanceSquared(to: point)
            }
    }
}

private final class AppshotCaptureOverlayView: NSView {
    let flashView = NSView()
    private let imageView = NSImageView()

    var image: NSImage? {
        get { imageView.image }
        set { imageView.image = newValue }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func layout() {
        super.layout()
        imageView.frame = bounds
        flashView.frame = bounds
        layer?.shadowPath = CGPath(rect: bounds, transform: nil)
    }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.white.cgColor
        layer?.shadowOffset = .zero
        layer?.shadowOpacity = 0.85
        layer?.shadowRadius = 22

        imageView.imageAlignment = .alignCenter
        imageView.imageFrameStyle = .none
        imageView.imageScaling = .scaleAxesIndependently
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 6
        imageView.layer?.masksToBounds = true
        addSubview(imageView)

        flashView.wantsLayer = true
        flashView.alphaValue = 1
        flashView.layer?.backgroundColor = NSColor.white.cgColor
        flashView.layer?.cornerRadius = 6
        flashView.layer?.masksToBounds = true
        addSubview(flashView)
    }
}

private struct DisplaySpace {
    let appKitFrame: CGRect
    let axFrame: CGRect

    init?(screen: NSScreen) {
        guard let number = screen.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")
        ] as? NSNumber else {
            return nil
        }

        appKitFrame = screen.frame
        axFrame = CGDisplayBounds(CGDirectDisplayID(number.uint32Value))
    }
}

private extension CGRect {
    var isUsableForAppshotAnimation: Bool {
        minX.isFinite &&
            minY.isFinite &&
            width.isFinite &&
            height.isFinite &&
            width > 8 &&
            height > 8
    }

    func distanceSquared(to point: CGPoint) -> CGFloat {
        let dx: CGFloat = if point.x < minX {
            minX - point.x
        } else if point.x > maxX {
            point.x - maxX
        } else {
            0
        }

        let dy: CGFloat = if point.y < minY {
            minY - point.y
        } else if point.y > maxY {
            point.y - maxY
        } else {
            0
        }

        return (dx * dx) + (dy * dy)
    }
}
