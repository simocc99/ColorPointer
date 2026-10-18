import AppKit
import Carbon.HIToolbox

/// User settings, stored in UserDefaults.
enum Settings {
    private static let showHexKey = "showHex"
    private static let textSizeKey = "textSizeIndex"

    static var showHex: Bool {
        get { UserDefaults.standard.bool(forKey: showHexKey) }
        set { UserDefaults.standard.set(newValue, forKey: showHexKey) }
    }

    /// 0 = Normale, 1 = Grande, 2 = Molto grande
    static var textSizeIndex: Int {
        get { UserDefaults.standard.integer(forKey: textSizeKey) }
        set { UserDefaults.standard.set(newValue, forKey: textSizeKey) }
    }

    static var textScale: CGFloat {
        switch textSizeIndex {
        case 1: return 1.4
        case 2: return 1.9
        default: return 1.0
        }
    }
}

/// Preferences window: change the activation shortcut, hex display and text size.
final class PreferencesWindowController: NSWindowController {

    /// Called after the user records a new shortcut.
    var onShortcutChanged: ((Shortcut) -> Void)?
    /// Called with `true` when recording starts and `false` when it ends, so global hotkeys can be paused.
    var onRecordingChanged: ((Bool) -> Void)?

    private let shortcutButton = NSButton(title: "", target: nil, action: nil)
    private let hexCheckbox = NSButton(checkboxWithTitle: "Mostra anche il codice esadecimale (#RRGGBB)", target: nil, action: nil)
    private let sizePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private var recordingMonitor: Any?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 230),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferenze Selettore Colore"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        buildUI(in: window.contentView!)
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - UI

    private func buildUI(in content: NSView) {
        let shortcutLabel = NSTextField(labelWithString: "Scorciatoia per attivare / disattivare:")
        shortcutButton.bezelStyle = .rounded
        shortcutButton.target = self
        shortcutButton.action = #selector(beginRecording)
        shortcutButton.font = .monospacedSystemFont(ofSize: 14, weight: .semibold)
        shortcutButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let shortcutRow = NSStackView(views: [shortcutLabel, shortcutButton])
        shortcutRow.orientation = .horizontal
        shortcutRow.spacing = 12

        let hint = NSTextField(wrappingLabelWithString:
            "Premi il pulsante, poi la nuova combinazione. Usa almeno ⌘, ⌥ o ⌃. Esc annulla.")
        hint.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: 12)

        hexCheckbox.target = self
        hexCheckbox.action = #selector(hexToggled)

        sizePopup.addItems(withTitles: ["Normale", "Grande", "Molto grande"])
        sizePopup.target = self
        sizePopup.action = #selector(sizeChanged)
        let sizeLabel = NSTextField(labelWithString: "Dimensione testo:")
        let sizeRow = NSStackView(views: [sizeLabel, sizePopup])
        sizeRow.orientation = .horizontal
        sizeRow.spacing = 12

        let resetButton = NSButton(title: "Ripristina predefinita", target: self, action: #selector(resetShortcut))
        resetButton.bezelStyle = .rounded

        let stack = NSStackView(views: [shortcutRow, hint, hexCheckbox, sizeRow, resetButton])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            hint.widthAnchor.constraint(lessThanOrEqualToConstant: 420)
        ])
    }

    private func refresh() {
        if recordingMonitor == nil {
            shortcutButton.title = Shortcut.load().displayString
        }
        hexCheckbox.state = Settings.showHex ? .on : .off
        sizePopup.selectItem(at: Settings.textSizeIndex)
    }

    // MARK: - Actions

    @objc private func hexToggled() {
        Settings.showHex = hexCheckbox.state == .on
    }

    @objc private func sizeChanged() {
        Settings.textSizeIndex = sizePopup.indexOfSelectedItem
    }

    @objc private func resetShortcut() {
        guard recordingMonitor == nil else { return }
        Shortcut.defaultToggle.save()
        refresh()
        onShortcutChanged?(Shortcut.defaultToggle)
    }

    @objc private func beginRecording() {
        guard recordingMonitor == nil else { return }
        shortcutButton.title = "Premi la combinazione…"
        onRecordingChanged?(true)
        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleRecordedKey(event) ?? event
        }
    }

    /// Returns nil to swallow the event while recording.
    private func handleRecordedKey(_ event: NSEvent) -> NSEvent? {
        // Esc cancels
        if event.keyCode == UInt16(kVK_Escape) {
            endRecording()
            return nil
        }

        let modifiers = Shortcut.carbonModifiers(from: event.modifierFlags)
        let needsModifier = UInt32(cmdKey | optionKey | controlKey)
        guard modifiers & needsModifier != 0 else {
            NSSound.beep()
            return nil
        }

        let shortcut = Shortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        shortcut.save()
        endRecording()
        onShortcutChanged?(shortcut)
        return nil
    }

    private func endRecording() {
        if let recordingMonitor {
            NSEvent.removeMonitor(recordingMonitor)
            self.recordingMonitor = nil
        }
        onRecordingChanged?(false)
        refresh()
    }
}
