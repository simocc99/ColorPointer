import AppKit
import Carbon.HIToolbox
import CoreGraphics

/// Identifiers for the Carbon hotkeys.
private enum HotkeyID {
    static let toggle: UInt32 = 1
    static let escape: UInt32 = 2
}

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let hotkeys = HotkeyManager()
    private let overlay = PointerOverlay()
    private var statusItem: NSStatusItem!
    private var toggleMenuItem: NSMenuItem!
    private var preferences: PreferencesWindowController?
    private var isActive = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "eyedropper", accessibilityDescription: "Selettore colore")

        buildMenu()

        hotkeys.onPressed = { [weak self] id in
            switch id {
            case HotkeyID.toggle: self?.toggle()
            case HotkeyID.escape: self?.deactivate()
            default: break
            }
        }
        registerToggleShortcut()
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()

        toggleMenuItem = NSMenuItem(title: "", action: #selector(toggle), keyEquivalent: "")
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)
        updateToggleMenuTitle()

        menu.addItem(.separator())

        let prefs = NSMenuItem(title: "Preferenze…", action: #selector(showPreferences), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Esci", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func updateToggleMenuTitle() {
        toggleMenuItem.title = "Attiva / disattiva  (\(Shortcut.load().displayString))"
    }

    // MARK: - Shortcut

    private func registerToggleShortcut() {
        let shortcut = Shortcut.load()
        if !hotkeys.register(id: HotkeyID.toggle, keyCode: shortcut.keyCode, modifiers: shortcut.modifiers) {
            showAlert(
                title: "Scorciatoia non disponibile",
                text: "La combinazione \(shortcut.displayString) è già usata da un'altra app o dal sistema. Scegline un'altra in Preferenze."
            )
        }
        updateToggleMenuTitle()
    }

    // MARK: - Activation

    @objc private func toggle() {
        isActive ? deactivate() : activate()
    }

    private func activate() {
        guard !isActive else { return }
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            showPermissionAlert()
            return
        }
        isActive = true
        overlay.start()
        // Esc exits the picker. Only registered while the picker is on.
        hotkeys.register(id: HotkeyID.escape, keyCode: UInt32(kVK_Escape), modifiers: 0)
    }

    private func deactivate() {
        guard isActive else { return }
        isActive = false
        overlay.stop()
        hotkeys.unregister(id: HotkeyID.escape)
    }

    // MARK: - Preferences

    @objc private func showPreferences() {
        if preferences == nil {
            let controller = PreferencesWindowController()
            controller.onRecordingChanged = { [weak self] recording in
                // Pause the global hotkeys while the user is recording a new one
                guard let self else { return }
                if recording {
                    self.hotkeys.unregister(id: HotkeyID.toggle)
                } else {
                    self.registerToggleShortcut()
                }
            }
            controller.onShortcutChanged = { [weak self] _ in
                self?.registerToggleShortcut()
            }
            preferences = controller
        }
        NSApp.activate(ignoringOtherApps: true)
        preferences?.showWindow(nil)
        preferences?.window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Alerts

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Serve il permesso di registrazione dello schermo"
        alert.informativeText = """
        Per leggere il colore sotto il puntatore, ColorPointer deve essere autorizzato in \
        Impostazioni di Sistema › Privacy e sicurezza › Registrazione dello schermo. \
        Dopo averlo attivato, potrebbe servire riaprire l'app.
        """
        alert.addButton(withTitle: "Apri Impostazioni")
        alert.addButton(withTitle: "Annulla")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    private func showAlert(title: String, text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // menu bar only, no Dock icon
app.run()
