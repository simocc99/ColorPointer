import AppKit
import ScreenCaptureKit

/// Reads the color of the screen pixel under the mouse with ScreenCaptureKit.
/// All windows of this app (the overlay and Preferences) are excluded, so the label never samples itself.
final class ScreenSampler {

    private var content: SCShareableContent?
    private var filters: [CGDirectDisplayID: SCContentFilter] = [:]

    /// Returns nil when the screen cannot be read (for example, no Screen Recording permission).
    func color(at mouseLocation: NSPoint) async -> NSColor? {
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return nil }

        // AppKit uses a bottom-left origin, ScreenCaptureKit a top-left origin on the primary display.
        let point = CGPoint(x: mouseLocation.x, y: primaryHeight - mouseLocation.y)

        if content == nil {
            content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        }
        guard let content, let display = content.displays.first(where: { $0.frame.contains(point) }) else {
            content = nil   // retry next time (display layout may have changed or permission was just granted)
            return nil
        }

        let filter: SCContentFilter
        if let cached = filters[display.displayID] {
            filter = cached
        } else {
            let ownApps = content.applications.filter { $0.processID == getpid() }
            filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
            filters[display.displayID] = filter
        }

        let config = SCStreamConfiguration()
        // sourceRect is in display points, relative to the display's top-left corner
        config.sourceRect = CGRect(
            x: point.x - display.frame.minX,
            y: point.y - display.frame.minY,
            width: 1,
            height: 1
        )
        config.width = 2
        config.height = 2
        config.showsCursor = false

        guard let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) else {
            return nil
        }
        let rep = NSBitmapImageRep(cgImage: image)
        guard rep.pixelsWide > 0, rep.pixelsHigh > 0 else { return nil }

        // Average all captured pixels: this removes per-pixel noise that made the name flicker
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, n: CGFloat = 0
        for x in 0..<rep.pixelsWide {
            for y in 0..<rep.pixelsHigh {
                guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                r += c.redComponent; g += c.greenComponent; b += c.blueComponent; n += 1
            }
        }
        guard n > 0 else { return nil }
        return NSColor(srgbRed: r / n, green: g / n, blue: b / n, alpha: 1)
    }
}

/// Floating label that follows the pointer and shows the color name (and optionally the hex code).
final class PointerOverlay {

    private let panel: NSPanel
    private let labelView = ColorLabelView()
    private var timer: Timer?
    private let sampler = ScreenSampler()
    private var isSampling = false

    private let sampleRate: TimeInterval = 1.0 / 30.0   // 30 updates per second
    private let offset: CGFloat = 22

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 50),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true          // clicks go through to the app below
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = labelView
    }

    func start() {
        panel.orderFrontRegardless()
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: sampleRate, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        panel.orderOut(nil)
    }

    private func tick() {
        // Skip this tick if the previous capture is still running
        guard !isSampling else { return }
        isSampling = true
        let mouse = NSEvent.mouseLocation

        Task { @MainActor in
            let color = await sampler.color(at: mouse)
            isSampling = false

            if let color {
                labelView.update(
                    name: ColorNamer.name(for: color),
                    hex: Settings.showHex ? ColorNamer.hex(for: color) : nil,
                    swatch: color,
                    scale: Settings.textScale
                )
            } else {
                labelView.update(name: "Nessun dato: controlla il permesso", hex: nil, swatch: .gray, scale: Settings.textScale)
            }
            panel.setFrame(frame(for: labelView.intrinsicSize, near: mouse), display: true)
        }
    }

    /// Places the label to the lower-right of the pointer, flipping it when it would leave the screen.
    private func frame(for size: NSSize, near mouse: NSPoint) -> NSRect {
        var origin = NSPoint(x: mouse.x + offset, y: mouse.y - offset - size.height)

        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        if let visible = screen?.frame {
            if origin.x + size.width > visible.maxX { origin.x = mouse.x - offset - size.width }
            if origin.y < visible.minY { origin.y = mouse.y + offset }
        }
        return NSRect(origin: origin, size: size)
    }
}

/// Draws the dark rounded box with a color swatch and high-contrast text.
final class ColorLabelView: NSView {

    private var name = ""
    private var hex: String?
    private var swatch: NSColor = .gray
    private var scale: CGFloat = 1

    private let padding: CGFloat = 12

    func update(name: String, hex: String?, swatch: NSColor, scale: CGFloat) {
        self.name = name.prefix(1).uppercased() + name.dropFirst()
        self.hex = hex
        self.swatch = swatch
        self.scale = scale
        needsDisplay = true
    }

    private var nameAttributes: [NSAttributedString.Key: Any] {
        [.font: NSFont.systemFont(ofSize: 18 * scale, weight: .bold), .foregroundColor: NSColor.white]
    }

    private var hexAttributes: [NSAttributedString.Key: Any] {
        [.font: NSFont.monospacedSystemFont(ofSize: 13 * scale, weight: .medium),
         .foregroundColor: NSColor.white.withAlphaComponent(0.85)]
    }

    private var swatchDiameter: CGFloat { round(24 * scale) }

    /// Size needed to show the current content.
    var intrinsicSize: NSSize {
        let nameSize = (name as NSString).size(withAttributes: nameAttributes)
        var textHeight = nameSize.height
        var textWidth = nameSize.width
        if let hex {
            let hexSize = (hex as NSString).size(withAttributes: hexAttributes)
            textHeight += hexSize.height
            textWidth = max(textWidth, hexSize.width)
        }
        let width = padding + swatchDiameter + 10 + textWidth + padding
        let height = max(textHeight, swatchDiameter) + padding * 2
        return NSSize(width: ceil(width), height: ceil(height))
    }

    override func draw(_ dirtyRect: NSRect) {
        // Background
        NSColor.black.withAlphaComponent(0.80).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12).fill()

        // Color swatch with a white ring so it stays visible on any background
        let d = swatchDiameter
        let swatchRect = NSRect(x: padding, y: (bounds.height - d) / 2, width: d, height: d)
        (swatch.usingColorSpace(.sRGB) ?? swatch).setFill()
        NSBezierPath(ovalIn: swatchRect).fill()
        let ring = NSBezierPath(ovalIn: swatchRect.insetBy(dx: -1.5, dy: -1.5))
        ring.lineWidth = 2
        NSColor.white.setStroke()
        ring.stroke()

        // Text, top-aligned block
        let textX = padding + d + 10
        let nameSize = (name as NSString).size(withAttributes: nameAttributes)
        var y = bounds.height - padding - nameSize.height
        (name as NSString).draw(at: NSPoint(x: textX, y: y), withAttributes: nameAttributes)

        if let hex {
            let hexSize = (hex as NSString).size(withAttributes: hexAttributes)
            y -= hexSize.height
            (hex as NSString).draw(at: NSPoint(x: textX, y: y), withAttributes: hexAttributes)
        }
    }
}
