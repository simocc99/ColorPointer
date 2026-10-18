import AppKit

/// Converts an RGB color into a human-readable Italian name, e.g. "rosso scuro" or "azzurro chiaro".
enum ColorNamer {

    static func name(for color: NSColor) -> String {
        let c = color.usingColorSpace(.sRGB) ?? color
        let r = Double(c.redComponent)
        let g = Double(c.greenComponent)
        let b = Double(c.blueComponent)

        let maxV = max(r, g, b)
        let minV = min(r, g, b)
        let delta = maxV - minV

        let value = maxV
        let saturation = maxV == 0 ? 0 : delta / maxV

        // Achromatic colors: white, black, grays.
        // Use the absolute spread between channels (delta), not the relative saturation:
        // on dark colors a tiny tint gives a high saturation (e.g. 20/255 vs 30/255 looks "blue").
        if delta < 0.12 || saturation < 0.12 {
            if value > 0.92 { return "bianco" }
            if value < 0.06 { return "nero" }
            if value > 0.70 { return "grigio chiaro" }
            if value < 0.40 { return "grigio scuro" }
            return "grigio"
        }

        let hue = hueDegrees(r: r, g: g, b: b, max: maxV, delta: delta)
        let base = baseName(hue: hue, value: value, saturation: saturation)

        // Modifiers for lightness
        if base == "rosso" && value > 0.85 && saturation < 0.5 { return "rosa" }
        if value < 0.52 && base != "marrone" { return "\(base) scuro" }
        if value > 0.85 && saturation < 0.60 { return "\(base) chiaro" }
        return base
    }

    /// Hex string such as "#FF8800" (useful for designers / developers).
    static func hex(for color: NSColor) -> String {
        let c = color.usingColorSpace(.sRGB) ?? color
        let r = Int(round(c.redComponent * 255))
        let g = Int(round(c.greenComponent * 255))
        let b = Int(round(c.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    // MARK: - Private

    private static func hueDegrees(r: Double, g: Double, b: Double, max maxV: Double, delta: Double) -> Double {
        var h: Double
        if maxV == r {
            h = 60 * ((g - b) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxV == g {
            h = 60 * ((b - r) / delta + 2)
        } else {
            h = 60 * ((r - g) / delta + 4)
        }
        if h < 0 { h += 360 }
        return h
    }

    private static func baseName(hue h: Double, value v: Double, saturation s: Double) -> String {
        // Dark orange / red-orange is perceived as brown
        if v < 0.55 && h >= 10 && h < 50 { return "marrone" }

        switch h {
        case 0..<15, 345...360: return "rosso"
        case 15..<45:           return "arancione"
        case 45..<70:           return "giallo"
        case 70..<160:          return "verde"
        case 160..<195:         return "ciano"
        case 195..<215:         return "azzurro"
        case 215..<260:         return "blu"
        case 260..<310:         return "viola"
        default:                return "fucsia"   // 310..<345
        }
    }
}
