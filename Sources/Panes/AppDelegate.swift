import AppKit
import PanesCore
import ServiceManagement

/// Starts Panes: takes the keys, puts the icon in the menu bar, asks for permission.
/// Two extra ways to start it, for checking without clicking:
///   --status    print permission and open-at-login state, then quit
///   --selftest  move Panes's own test windows and report pass or fail, then quit
///   --settings  start normally and open the settings window
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var failedKeys: [KeyBinding] = []

    /// Opening Panes again (Spotlight, Finder, `open`) while it runs shows Settings,
    /// since a menu-bar app has no other window to show.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        SettingsWindow.shared.show()
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        if args.contains("--status") { return printStatusAndQuit() }
        if args.contains("--selftest") { return SelfTest.start() }
        if args.contains("--dummy") { return SelfTest.startDummy() }
        if let i = args.firstIndex(of: "--settings-shots"), i + 1 < args.count {
            SettingsSnapshot.write(to: args[i + 1])
            exit(0)
        }

        registerKeys()
        Settings.shared.onKeysChanged = { [weak self] in self?.registerKeys() }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.split.2x2", accessibilityDescription: "Panes")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item

        turnOnOpenAtLoginOnce()
        if !AX.isAllowed { AX.askForPermission() }
        startWatchingWindows()
        if args.contains("--settings") { SettingsWindow.shared.show() }
    }

    /// Takes every key in Settings from scratch. Called at launch and whenever a key changes.
    func registerKeys() {
        HotKeys.shared.unregisterAll()
        let all = Settings.shared.bindings
        failedKeys = all.filter { binding in
            !HotKeys.shared.register(keyCode: binding.keyCode, modifiers: binding.modifiers) {
                AppDelegate.run(binding.action)
            }
        }
        NSLog("Panes: %d of %d keys registered", all.count - failedKeys.count, all.count)
    }

    static func run(_ action: Action) {
        if action == .showDesktop { return Desktop.toggle() }
        guard AX.isAllowed else { return AX.askForPermission() }
        let front = NSWorkspace.shared.frontmostApplication.flatMap { AX.focusedWindow(of: $0.processIdentifier) }
        switch action {
        #if PANES_PRO
            case .stack: Tiler.shared.start(.stack, focused: front)
            case .grid: Tiler.shared.start(.grid, focused: front)
        #endif
        case .nextScreen:
            if front.map(WindowMover.sendToNextScreen) != true { NSSound.beep() }
        default:
            #if PANES_PRO
                // A single-window snap means "I'm arranging this screen by hand now".
                if let screen = WindowMover.apply(action) { Tiler.shared.stop(on: screen) }
            #else
                WindowMover.apply(action)
            #endif
        }
    }

    /// Auto re-stack and drag-to-snap need the permission; if it is not there yet, try again every 2 s.
    private func startWatchingWindows() {
        guard AX.isAllowed else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.startWatchingWindows() }
            return
        }
        #if PANES_PRO
            WindowWatcher.shared.onChange = { Tiler.shared.retileAll() }
            WindowWatcher.shared.start()
        #endif
        if Settings.shared.dragToSnap { DragSnapper.shared.start() }
    }

    // MARK: - Open at login

    /// Panes replaces Rectangle, so it should start with the Mac. Done once; if the user
    /// turns it off in the menu, it stays off.
    private func turnOnOpenAtLoginOnce() {
        let key = "openAtLoginSetOnce"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        try? SMAppService.mainApp.register()
    }

    private func printStatusAndQuit() {
        print("accessibility: \(AX.isAllowed ? "allowed" : "NOT allowed")")
        print("open at login: \(SMAppService.mainApp.status == .enabled ? "on" : "off")")
        exit(0)
    }

    // MARK: - Menu (rebuilt every time it opens, so it always shows the real state)

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if !AX.isAllowed {
            menu.addItem(item("Allow window control…", #selector(askPermission)))
            menu.addItem(.separator())
        }
        menu.addItem(item("Show desktop", #selector(showDesktop)))
        menu.addItem(.separator())
        for binding in Settings.shared.bindings where binding.action != .showDesktop {
            let entry = item("\(binding.action.title)    \(binding.display)", #selector(runFromMenu(_:)))
            entry.representedObject = binding.action.rawValue
            menu.addItem(entry)
        }
        if !failedKeys.isEmpty {
            menu.addItem(.separator())
            let labels = failedKeys.map { $0.display }.joined(separator: " ")
            let warn = NSMenuItem(title: "Taken by another app: \(labels)", action: nil, keyEquivalent: "")
            warn.isEnabled = false
            menu.addItem(warn)
        }
        menu.addItem(.separator())
        #if PANES_PRO
            menu.addItem(layoutsMenuItem())
        #endif
        menu.addItem(item("Settings…", #selector(openSettings), key: ","))
        let login = item("Open at login", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(item("Quit Panes", #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: key)
        entry.target = self
        return entry
    }

    @objc private func runFromMenu(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let action = Action(rawValue: raw) else { return }
        AppDelegate.run(action)
    }

    @objc private func openSettings() { SettingsWindow.shared.show() }

    @objc private func showDesktop() { Desktop.toggle() }

    @objc private func askPermission() { AX.askForPermission() }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Panes: open at login failed: %@", error.localizedDescription)
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
