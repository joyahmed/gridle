import AppKit
import PanesCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab().tabItem { Text("General") }
            KeysTab().tabItem { Text("Keys") }
            #if PANES_PRO
                LayoutsTab().tabItem { Text("Layouts") }
            #endif
            IgnoreTab().tabItem { Text("Ignore") }
        }
        .padding(16)
        .frame(width: 480, height: 420)
    }
}

// MARK: - General

private struct GeneralTab: View {
    @State private var settings = Settings.shared
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            HStack {
                Slider(value: $settings.gap, in: 0...24, step: 2) { Text("Gap between windows") }
                Text("\(Int(settings.gap)) pt").monospacedDigit().frame(width: 50, alignment: .trailing)
            }
            Toggle(
                "Drag a window to a screen edge to snap it",
                isOn: Binding(
                    get: { settings.dragToSnap },
                    set: { on in
                        settings.dragToSnap = on
                        if on { DragSnapper.shared.start() } else { DragSnapper.shared.stop() }
                    }))
            Toggle(
                "Open at login",
                isOn: Binding(
                    get: { openAtLogin },
                    set: { on in
                        do {
                            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            NSLog("Panes: open at login failed: %@", error.localizedDescription)
                        }
                        openAtLogin = SMAppService.mainApp.status == .enabled
                    }))
        }
        .formStyle(.grouped)
    }
}

// MARK: - Keys

private struct KeysTab: View {
    @State private var settings = Settings.shared
    @State private var recording: Action?
    @State private var message = ""
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .leading) {
            List(settings.bindings, id: \.action) { binding in
                HStack {
                    Text(binding.action.title)
                    Spacer()
                    Button(recording == binding.action ? "Press a key…" : binding.display) {
                        start(binding.action)
                    }
                    .frame(minWidth: 110)
                }
            }
            if !message.isEmpty { Text(message).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Reset to defaults") {
                    finish()
                    settings.bindings = Keymap.defaults
                }
            }
        }
        .padding()
        .onDisappear { finish() }
    }

    private func start(_ action: Action) {
        finish()
        recording = action
        message = ""
        HotKeys.shared.unregisterAll()  // so the keys already in use reach this window
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event, for: action)
            return nil
        }
    }

    private func handle(_ event: NSEvent, for action: Action) {
        if event.keyCode == 53 { return finish() }
        let mods = KeyNames.mods(event.modifierFlags)
        guard mods != 0 else {
            message = "Hold at least one of Ctrl, Alt, Shift or Cmd."
            return
        }
        let candidate = KeyBinding(
            keyCode: UInt32(event.keyCode), label: KeyNames.label(event), action: action, modifiers: mods)
        if let other = Keymap.conflict(candidate, in: settings.bindings) {
            message = "\(candidate.display) is already used by \(other.title)."
            return
        }
        finish()
        settings.bindings = Keymap.replacing(candidate, in: settings.bindings)
    }

    /// Stops listening and gives the keys back to the whole system.
    private func finish() {
        guard recording != nil || monitor != nil else { return }
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = nil
        (NSApp.delegate as? AppDelegate)?.registerKeys()
    }
}

// MARK: - Ignore

private struct IgnoreTab: View {
    @State private var settings = Settings.shared

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.bundleIdentifier != nil
                && $0.bundleIdentifier != Bundle.main.bundleIdentifier
        }
    }

    private func name(for id: String) -> String {
        runningApps.first { $0.bundleIdentifier == id }?.localizedName ?? id
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Panes never moves these apps.")
            List(settings.ignored, id: \.self) { id in
                HStack {
                    Text(name(for: id))
                    Spacer()
                    Button("Remove") { settings.ignored.removeAll { $0 == id } }
                }
            }
            .overlay {
                if settings.ignored.isEmpty {
                    Text("No apps ignored. Panes moves every window.").foregroundStyle(.secondary)
                }
            }
            Menu("Add a running app") {
                ForEach(addable, id: \.id) { app in
                    Button(app.name) { settings.ignored.append(app.id) }
                }
            }
        }
        .padding()
    }

    private var addable: [(id: String, name: String)] {
        var seen = Set<String>()
        var out: [(id: String, name: String)] = []
        for app in runningApps {
            guard let id = app.bundleIdentifier, !settings.isIgnored(id), seen.insert(id).inserted else { continue }
            out.append((id, app.localizedName ?? id))
        }
        return out.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

/// Draws each settings tab to a PNG, in light and dark, without showing a window or changing
/// the Mac's theme. Run: `Panes --settings-shots <folder>`. Used to check the screens by eye.
enum SettingsSnapshot {
    static func write(to folder: String) {
        var tabs: [(String, AnyView)] = [("general", AnyView(GeneralTab())), ("keys", AnyView(KeysTab()))]
        #if PANES_PRO
            tabs.append(("layouts", AnyView(LayoutsTab())))
        #endif
        tabs.append(("ignore", AnyView(IgnoreTab())))
        for (name, view) in tabs {
            for (theme, look) in [("light", NSAppearance.Name.aqua), ("dark", NSAppearance.Name.darkAqua)] {
                let host = NSHostingView(
                    rootView: view.padding(20).frame(width: 480, height: 420)
                        .background(Color(nsColor: .windowBackgroundColor)))
                host.appearance = NSAppearance(named: look)
                host.frame = NSRect(x: 0, y: 0, width: 480, height: 420)
                let window = NSWindow(
                    contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
                window.appearance = NSAppearance(named: look)
                window.contentView = host
                host.layoutSubtreeIfNeeded()
                guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
                host.cacheDisplay(in: host.bounds, to: rep)
                let url = URL(fileURLWithPath: folder).appendingPathComponent("settings-\(name)-\(theme).png")
                try? rep.representation(using: .png, properties: [:])?.write(to: url)
            }
        }
    }
}
