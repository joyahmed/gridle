import AppKit
import GridleCore

/// `--demo`: a slow, hands-free show on screen, made to be screen-recorded (README GIF, short video).
///
/// It hides every other app, starts the `--dummy` window process (styled like real apps),
/// then moves THOSE windows with the same code a key press runs, while a key overlay shows
/// the shortcut being "pressed". Only the dummy's windows are ever moved, never the user's.
/// `--demo-free` skips the Pro scenes even in the Pro build (for the public GIF).
///
/// Run through `open`, so macOS checks Gridle's own Accessibility permission:
/// `open -n -W --stdout /tmp/gridle-demo.txt ~/Applications/Gridle.app --args --demo`
enum Demo {
    /// One scene: the keys shown, a caption, and what to do a moment after they appear.
    struct Step {
        var keys: [String] = []
        var caption: String
        var run: () -> Void = {}
        /// Seconds from the keys appearing to the next step.
        var wait = 1.3
        /// Seconds from the keys appearing to the window moving.
        var lead = 0.35
    }

    static var pid: pid_t = 0

    /// GRIDLE_DEMO_PACE=2 plays every step twice as slowly (the long video); default 1 (GIF, Short).
    static let pace = Double(ProcessInfo.processInfo.environment["GRIDLE_DEMO_PACE"] ?? "") ?? 1
    private static var dummy: Process?
    private static var hiddenByDemo: [NSRunningApplication] = []
    private static var finished = false
    private static var stopSignals: [DispatchSourceSignal] = []

    // MARK: - Run

    static func start() {
        guard AX.isAllowed else { return finish(error: "Accessibility is not allowed for Gridle") }
        for number in [SIGINT, SIGTERM] {
            signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
            source.setEventHandler { finish(error: "interrupted") }
            source.resume()
            stopSignals.append(source)
        }
        WindowMover.gapOverride = 16
        DemoStage.shared.show()
        clearStage()
        SelfTest.after(0.8) { startDummy() }
    }

    /// Hides every other regular app, remembering exactly which, so `finish` can bring back those and no others.
    private static func clearStage() {
        let me = ProcessInfo.processInfo.processIdentifier
        let visible = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isHidden && $0.processIdentifier != me
        }
        for app in visible { forceHide(app) }
        hiddenByDemo = visible
    }

    /// `hide()` alone can be refused for the app in front (macOS lets the active app keep its
    /// windows). Setting the Accessibility "hidden" flag cannot be refused while Gridle has the
    /// Accessibility permission, so do both.
    private static func forceHide(_ app: NSRunningApplication) {
        app.hide()
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetAttributeValue(element, kAXHiddenAttribute as CFString, kCFBooleanTrue)
    }

    /// With GRIDLE_DEMO_SIGNALS=<folder> (set by scripts/record-demo.sh) the demo and the recorder
    /// take turns: the demo writes `<say>` there, then waits up to 8 s for the recorder to write
    /// `<waitFor>`. Without the variable it does nothing.
    private static func handshake(say: String, waitFor: String) {
        guard let folder = ProcessInfo.processInfo.environment["GRIDLE_DEMO_SIGNALS"] else { return }
        let dir = URL(fileURLWithPath: folder)
        FileManager.default.createFile(atPath: dir.appendingPathComponent(say).path, contents: nil)
        let wanted = dir.appendingPathComponent(waitFor).path
        let deadline = Date().addingTimeInterval(8)
        while !FileManager.default.fileExists(atPath: wanted) && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
    }

    /// Puts the demo windows' app in front, the same way: through Accessibility.
    private static func bringDemoToFront() {
        guard pid != 0 else { return }
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(element, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
    }

    private static func startDummy() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        process.arguments = ["--dummy"]
        var environment = ProcessInfo.processInfo.environment
        environment["GRIDLE_DUMMY_STYLE"] = "demo"
        process.environment = environment
        do { try process.run() } catch { return finish(error: "could not start the demo windows: \(error)") }
        dummy = process
        pid = process.processIdentifier
        waitForWindow(named: "Code", tries: 24) {
            bringDemoToFront()
            // Anything that ignored the first hide (it was in front) is hidden again now.
            for app in hiddenByDemo where !app.isHidden { forceHide(app) }
            // Recording: start the recorder only now that the screen shows nothing private.
            handshake(say: "ready", waitFor: "recording")
            DemoOverlay.shared.card("Gridle — Windows-style window snapping for Mac")
            SelfTest.after(1.2) { play(steps(), then: { endCard() }) }
        }
    }

    private static func waitForWindow(named title: String, tries: Int, then ready: @escaping () -> Void) {
        if window(title) != nil { return SelfTest.after(0.4, ready) }
        guard tries > 0 else { return finish(error: "the demo window \"\(title)\" never appeared") }
        SelfTest.after(0.25) { waitForWindow(named: title, tries: tries - 1, then: ready) }
    }

    private static func play(_ list: [Step], then done: @escaping () -> Void) {
        guard let step = list.first else { return done() }
        if !step.caption.isEmpty { SelfTest.say("scene: \(step.caption)") }
        if !step.keys.isEmpty || !step.caption.isEmpty {
            DemoOverlay.shared.show(keys: step.keys, caption: step.caption)
        }
        SelfTest.after(step.lead * pace) { step.run() }
        SelfTest.after(step.wait * pace) { play(Array(list.dropFirst()), then: done) }
    }

    private static func endCard() {
        DemoOverlay.shared.card("Free · github.com/joyahmed/gridle")
        SelfTest.after(1.5) { finish(error: nil) }
    }

    /// The single way out: puts the stage back (always), says how it went, exits.
    static func finish(error: String?) {
        guard !finished else { return }
        finished = true
        // Recording: let the recorder stop BEFORE the user's apps come back on screen.
        handshake(say: "done", waitFor: "stopped")
        dummy?.terminate()
        for app in hiddenByDemo where !app.isTerminated {
            app.unhide()
            AXUIElementSetAttributeValue(
                AXUIElementCreateApplication(app.processIdentifier), kAXHiddenAttribute as CFString, kCFBooleanFalse)
        }
        DemoOverlay.shared.hide()
        DemoStage.shared.hide()
        if let error {
            SelfTest.say("DEMO FAILED: \(error)")
            exit(1)
        }
        SelfTest.say("DEMO DONE")
        exit(0)
    }

    // MARK: - The script

    private static func steps() -> [Step] {
        var list: [Step] = [
            snap(.leftHalf, "Code"), snap(.rightHalf, "Code"), snap(.topHalf, "Code"),
            snap(.topLeft, "Code"), snap(.topRight, "Code"), snap(.bottomLeft, "Code"), snap(.bottomRight, "Code"),
            openWindows(2, caption: "Two more windows"),
            snap(.leftThird, "Code"), snap(.middleThird, "Browser"), snap(.rightThird, "Terminal"),
            snap(.fill, "Browser"), snap(.center, "Browser"),
            Step(caption: "", run: { Demo.signalDummy(SIGUSR2) }, wait: 1.0),
            snap(.rightHalf, "Settings", caption: "A fixed-size window still lands right"),
            snap(.topHalf, "Settings", caption: "Up: it goes to the top-right"),
            Step(caption: "", run: { Demo.signalDummy(SIGUSR2) }, wait: 0.6),
            showDesktop(),
        ]
        #if GRIDLE_PRO
            if !CommandLine.arguments.contains("--demo-free") { list += proSteps() }
        #endif
        return list
    }

    /// Presses `action`'s default keys and moves the named window.
    static func snap(_ action: Action, _ title: String, caption: String? = nil) -> Step {
        Step(
            keys: chord(action), caption: caption ?? action.title,
            run: {
                guard let target = window(title) else { return finish(error: "no demo window \"\(title)\"") }
                raise(target)
                if WindowMover.apply(action, window: target) == nil { finish(error: "could not move \"\(title)\"") }
            })
    }

    /// Asks the demo windows for `count` more windows, quietly (no overlay change).
    static func openWindows(_ count: Int, caption: String) -> Step {
        Step(
            caption: "",
            run: {
                // One request every 0.25 s: macOS merges signals sent at the same instant.
                for n in 0..<count { SelfTest.after(Double(n) * 0.25) { Demo.signalDummy(SIGUSR1) } }
            }, wait: 0.35 + Double(count) * 0.25 + 0.5)
    }

    private static func showDesktop() -> Step {
        Step(
            keys: chord(.showDesktop), caption: "Show desktop — and back",
            run: {
                // The same calls as the real Show desktop key.
                let app = NSRunningApplication(processIdentifier: pid)
                app?.hide()
                AX.setHidden(pid, true)
                SelfTest.after(1.0) {
                    app?.unhide()
                    AX.setHidden(pid, false)
                }
            }, wait: 2.6)
    }

    // MARK: - Helpers

    static func chord(_ action: Action) -> [String] {
        let label = Keymap.defaults.first { $0.action == action }?.label ?? "?"
        return ["Ctrl", "Alt", label == "Return" ? "↩" : label]
    }

    static func window(_ title: String) -> AXUIElement? {
        AX.windows(of: pid).first { AX.title(of: $0) == title }
    }

    /// Signals the demo's window process (SIGUSR1 = one more window, SIGUSR2 = toggle the fixed-size one).
    static func signalDummy(_ number: Int32) { Darwin.kill(pid, number) }

    static func raise(_ window: AXUIElement) {
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }
}

// MARK: - Dummy windows that look like apps

/// With `GRIDLE_DUMMY_STYLE=demo`, the `--dummy` windows get app-like titles and a simple content view.
enum DemoStyle {
    static var isOn: Bool { ProcessInfo.processInfo.environment["GRIDLE_DUMMY_STYLE"] == "demo" }

    private static let apps: [(title: String, color: NSColor, lines: [String])] = [
        (
            "Code", rgb(52, 120, 246),
            [
                "func snap(_ window: Window) {", "    let frame = layout.frame(for: .leftHalf)",
                "    window.move(to: frame)", "}",
            ]
        ),
        (
            "Browser", rgb(242, 140, 40),
            ["github.com/joyahmed/gridle", "Windows-style snapping for Mac", "Fast. Native. Free."]
        ),
        ("Terminal", rgb(142, 90, 214), ["$ swift build", "Compiling Gridle", "Build complete!"]),
        ("Notes", rgb(52, 178, 96), ["Shopping list", "Call the dentist", "Ideas for the weekend"]),
        ("Music", rgb(88, 100, 120), ["Now playing", "Morning Light", "Up next: Slow Waves"]),
    ]

    private static func rgb(_ r: Double, _ g: Double, _ b: Double) -> NSColor {
        NSColor(calibratedRed: r / 255, green: g / 255, blue: b / 255, alpha: 1)
    }

    /// The numbered resizable window: n = 1 is Code, 2 Browser, and so on, round again after five.
    static func decorate(_ window: NSWindow, number n: Int) {
        let app = apps[(n - 1) % apps.count]
        window.title = app.title
        window.setContentSize(NSSize(width: 560, height: 380))
        fill(window, color: app.color, header: app.title, lines: app.lines)
    }

    /// The fixed-size window, titled "Settings".
    static func decorateFixed(_ window: NSWindow) {
        window.title = "Settings"
        fill(window, color: rgb(110, 118, 135), header: "Settings", lines: ["General", "Shortcuts", "About"])
    }

    private static func fill(_ window: NSWindow, color: NSColor, header: String, lines: [String]) {
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = DemoContentView(color: color, header: header, lines: lines)
    }
}

/// A coloured header strip with a few placeholder text lines under it.
private final class DemoContentView: NSView {
    private let strip = NSView()
    private let headline: NSTextField
    private let rows: [NSTextField]

    init(color: NSColor, header: String, lines: [String]) {
        headline = NSTextField(labelWithString: header)
        headline.font = .systemFont(ofSize: 17, weight: .semibold)
        headline.textColor = .white
        rows = lines.map { text in
            let label = NSTextField(labelWithString: text)
            label.font = .systemFont(ofSize: 14)
            label.textColor = NSColor(white: 0.3, alpha: 1)
            return label
        }
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.97, alpha: 1).cgColor
        strip.wantsLayer = true
        strip.layer?.backgroundColor = color.cgColor
        addSubview(strip)
        addSubview(headline)
        for row in rows { addSubview(row) }
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        strip.frame = NSRect(x: 0, y: 0, width: bounds.width, height: 44)
        headline.sizeToFit()
        headline.frame.origin = NSPoint(x: 18, y: (44 - headline.frame.height) / 2)
        for (i, row) in rows.enumerated() {
            row.sizeToFit()
            row.frame.origin = NSPoint(x: 18, y: 66 + CGFloat(i) * 28)
        }
    }
}

// MARK: - Key overlay

/// A floating panel near the bottom of the main screen showing the key being "pressed" as keycap chips,
/// with a caption under them. It never takes focus and never catches clicks.
final class DemoOverlay {
    static let shared = DemoOverlay()

    private let panel: NSPanel
    private let backdrop = NSView()
    private let stack = NSStackView()

    private init() {
        panel = NSPanel(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.alphaValue = 0

        // Solid, not see-through: a busy wallpaper behind a blur made the keys unreadable.
        backdrop.wantsLayer = true
        backdrop.layer?.backgroundColor = NSColor(red: 0.04, green: 0.07, blue: 0.13, alpha: 0.94).cgColor
        backdrop.layer?.borderWidth = 1
        backdrop.layer?.borderColor = NSColor(red: 0.37, green: 0.71, blue: 1, alpha: 0.35).cgColor
        backdrop.layer?.cornerRadius = 20
        backdrop.layer?.masksToBounds = true
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 22, left: 30, bottom: 22, right: 30)
        stack.translatesAutoresizingMaskIntoConstraints = false
        backdrop.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor),
            stack.topAnchor.constraint(equalTo: backdrop.topAnchor),
            stack.bottomAnchor.constraint(equalTo: backdrop.bottomAnchor),
        ])
        panel.contentView = backdrop
    }

    /// Fades to the given keys and caption. Either may be empty.
    func show(keys: [String], caption: String) {
        swap(centered: false) {
            if !keys.isEmpty {
                let row = NSStackView(views: keys.map { self.chip($0) })
                row.orientation = .horizontal
                row.spacing = 12
                self.stack.addArrangedSubview(row)
            }
            if !caption.isEmpty {
                self.stack.addArrangedSubview(self.label(caption, size: 22, weight: .medium, alpha: 0.85))
            }
        }
    }

    /// Fades to a big title in the middle of the screen.
    func card(_ text: String) {
        swap(centered: true) { self.stack.addArrangedSubview(self.label(text, size: 34, weight: .semibold, alpha: 1)) }
    }

    func hide() {
        panel.alphaValue = 0
        panel.orderOut(nil)
    }

    private func swap(centered: Bool, build: @escaping () -> Void) {
        let apply = {
            for view in self.stack.arrangedSubviews {
                self.stack.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
            build()
            self.place(centered: centered)
            self.fade(to: 1)
        }
        if panel.alphaValue > 0.01 {
            fade(to: 0, then: apply)
        } else {
            apply()
        }
    }

    private func fade(to alpha: CGFloat, then done: (() -> Void)? = nil) {
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.2
                panel.animator().alphaValue = alpha
            }, completionHandler: { done?() })
    }

    private func place(centered: Bool) {
        backdrop.layoutSubtreeIfNeeded()
        let size = stack.fittingSize
        let area = (NSScreen.screens.first ?? NSScreen.main)?.visibleFrame ?? .zero
        let y = centered ? area.midY - size.height / 2 : area.minY + 90
        panel.setFrame(
            NSRect(x: area.midX - size.width / 2, y: y, width: size.width, height: size.height), display: true)
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = NSColor.white.withAlphaComponent(alpha)
        field.alignment = .center
        return field
    }

    /// One keycap: big rounded text on a lighter rounded chip.
    private func chip(_ key: String) -> NSView {
        let text = label(key, size: 44, weight: .semibold, alpha: 1)
        if let rounded = text.font?.fontDescriptor.withDesign(.rounded) {
            text.font = NSFont(descriptor: rounded, size: 44)
        }
        let chip = NSView()
        chip.wantsLayer = true
        chip.layer?.cornerRadius = 14
        chip.layer?.backgroundColor = NSColor(red: 0.37, green: 0.71, blue: 1, alpha: 0.18).cgColor
        chip.layer?.borderWidth = 1
        chip.layer?.borderColor = NSColor(red: 0.37, green: 0.71, blue: 1, alpha: 0.65).cgColor
        text.translatesAutoresizingMaskIntoConstraints = false
        chip.addSubview(text)
        NSLayoutConstraint.activate([
            text.leadingAnchor.constraint(equalTo: chip.leadingAnchor, constant: 20),
            text.trailingAnchor.constraint(equalTo: chip.trailingAnchor, constant: -20),
            text.topAnchor.constraint(equalTo: chip.topAnchor, constant: 8),
            text.bottomAnchor.constraint(equalTo: chip.bottomAnchor, constant: -8),
            chip.widthAnchor.constraint(greaterThanOrEqualToConstant: 76),
        ])
        return chip
    }
}

/// A plain dark-blue backdrop over the desktop for the length of the demo, behind every window.
/// It hides the wallpaper and desktop icons, so a recording shows only the demo windows.
final class DemoStage {
    static let shared = DemoStage()
    private var windows: [NSWindow] = []

    func show() {
        for screen in NSScreen.screens {
            let window = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .stationary]
            let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.wantsLayer = true
            let gradient = CAGradientLayer()
            gradient.frame = view.bounds
            gradient.colors = [
                NSColor(red: 0.04, green: 0.07, blue: 0.13, alpha: 1).cgColor,
                NSColor(red: 0.07, green: 0.20, blue: 0.36, alpha: 1).cgColor,
            ]
            gradient.startPoint = CGPoint(x: 0, y: 0)
            gradient.endPoint = CGPoint(x: 1, y: 1)
            view.layer?.addSublayer(gradient)
            window.contentView = view
            window.orderFrontRegardless()
            windows.append(window)
        }
    }

    func hide() {
        for window in windows { window.close() }
        windows = []
    }
}
