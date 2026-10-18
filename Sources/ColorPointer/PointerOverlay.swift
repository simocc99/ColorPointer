import AppKit

/// Reads the color of the single screen pixel under the mouse.
/// Windows above the overlay are excluded, so the overlay never samples itself.
enum ScreenSampler {

    static func color(at mouseLocation: NSPoint, excludingWindow windowID: CGWindowID) -> NSColor? {
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return nil }

        // AppKit uses a bottom-left origin, CoreGraphics a top-left origin on the primary display.
        let rect = CGRect(x: mouseLocation.x, y: primaryHeight - mouseLocation.y, width: 1, height: 1)

        guard let image = CGWindowListCreateImage(
            rect,
            .optionOnScreenBelowWindow,
            windowID,
            [.bestResolution]
        ) else { return nil }

        let rep = NSBitmapImageRep(cgImage: image)
        guard rep.pixelsWide > 0, rep.pixelsHigh > 0 else { return nil }
        // On Retina the capture may be 2x2 pixels: take the one closest to the pointer.
        return rep.colorAt(x: rep.pixelsWide / 2, y: rep.pixelsHigh / 2)
    }
}

/// Floating label that follows the pointer and shows the color name (and optionally the hex code).
final class PointerOverlay {

    private let panel: NSPanel
    private let labelView = ColorLabelView()
    private var timer: Timer?

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

    var windowID: CGWindowID { CGWindowID(panel.windowNumber) }

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
        let mouse = NSEvent.mouseLocation
        let color = ScreenSampler.color(at: mouse, excludingWindow: windowID) ?? .gray

        labelView.update(
            name: ColorNamer.name(for: color),
            hex: Settings.showHex ? ColorNamer.hex(for: color) : nil,
            swatch: color,
            scale: Settings.textScale
        )
        panel.setFrame(frame(for: labelView.intrinsicSize, near: mouse), display: true)
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
