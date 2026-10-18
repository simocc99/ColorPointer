import AppKit
import Carbon.HIToolbox

/// A keyboard shortcut made of a virtual key code and Carbon modifier flags.
/// Stored in UserDefaults so the user can change it from the Preferences window.
struct Shortcut: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32   // Carbon flags: cmdKey, optionKey, controlKey, shiftKey

    /// Default: ⌘⌥4
    static let defaultToggle = Shortcut(keyCode: 21, modifiers: UInt32(cmdKey | optionKey))

    private static let keyCodeDefaultsKey = "shortcutKeyCode"
    private static let modifiersDefaultsKey = "shortcutModifiers"

    static func load() -> Shortcut {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: keyCodeDefaultsKey) != nil else { return defaultToggle }
        return Shortcut(
            keyCode: UInt32(defaults.integer(forKey: keyCodeDefaultsKey)),
            modifiers: UInt32(defaults.integer(forKey: modifiersDefaultsKey))
        )
    }

    func save() {
        UserDefaults.standard.set(Int(keyCode), forKey: Shortcut.keyCodeDefaultsKey)
        UserDefaults.standard.set(Int(modifiers), forKey: Shortcut.modifiersDefaultsKey)
    }

    /// Readable form such as "⌘⌥4".
    var displayString: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + KeyNames.name(for: keyCode)
    }

    /// Converts AppKit modifier flags to Carbon flags.
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        return m
    }
}

/// Human-readable names for virtual key codes (US/ISO layout).
enum KeyNames {
    private static let names: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 25: "9", 26: "7", 28: "8", 29: "0",
        31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
        36: "↩", 48: "⇥", 49: "Spazio", 51: "⌫", 53: "⎋",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
    ]

    static func name(for keyCode: UInt32) -> String {
        names[keyCode] ?? "Tasto \(keyCode)"
    }
}
