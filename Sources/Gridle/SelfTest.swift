import AppKit
import GridleCore

/// End-to-end check that never touches the user's own apps.
///
/// A second Gridle process (`--dummy`) shows plain test windows. This process moves
/// THOSE windows through Accessibility, the same code a key press runs, then reads
/// back where each one landed and compares it with `Layout`.
///
/// Run: `open -n -W --stdout /tmp/gridle-selftest.txt ~/Applications/Gridle.app --args --selftest`
/// (through `open`, so macOS checks Gridle's own Accessibility permission, not the terminal's).
enum SelfTest {
    private static var dummy: Process?
    private static var passes = 0
    private static var failures = 0

    // MARK: - The test side

    static func start() {
        guard AX.isAllowed else {
            say("FAIL  Accessibility is not allowed for Gridle")
            return finish()
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        process.arguments = ["--dummy"]
        do { try process.run() } catch {
            say("FAIL  could not start the test-window process: \(error)")
            return finish()
        }
        dummy = process
        after(1.0) { placement() }
    }

    /// Every action that places one window: move the test window there and check it.
    private static func placement() {
        guard let pid = dummy?.processIdentifier else { return finish() }
        let actions = Action.allCases.filter { Layout.frame(for: $0, in: Rect(x: 0, y: 0, w: 1, h: 1)) != nil }
        let steps = actions.map { action in
            {
                guard let window = AX.focusedWindow(of: pid), let screen = WindowMover.apply(action, window: window)
                else { return check(action.title, false, "no test window found") }
                after(0.2) {
                    let landed = AX.frame(of: window)
                    let wanted = Layout.frame(for: action, in: screen, gap: WindowMover.gap)
                    check(action.title, close(landed, wanted), "landed \(text(landed)), wanted \(text(wanted))")
                }
            }
        }
        sequence(steps, every: 0.35) { fixedSize() }
    }

    /// A window that cannot be resized (300 × 200) must still land in the corner or edge asked for.
    private static func fixedSize() {
        guard let pid = dummy?.processIdentifier else { return finish() }
        kill(pid, SIGUSR2)  // dummy opens its fixed-size window
        after(0.8) {
            let actions: [Action] = [
                .topRight, .bottomRight, .bottomLeft, .rightHalf, .topHalf, .leftHalf, .bottomHalf, .center,
            ]
            let steps = actions.map { action in
                {
                    guard let window = AX.windows(of: pid).first(where: { AX.title(of: $0) == "Gridle fixed test" }),
                        let before = AX.frame(of: window),
                        let screen = WindowMover.apply(action, window: window),
                        let target = Layout.frame(for: action, in: screen, gap: WindowMover.gap)
                    else { return check("Fixed-size: \(action.title)", false, "no fixed test window") }
                    after(0.2) {
                        let landed = AX.frame(of: window)
                        // The real size includes the title bar, so take it from the window itself.
                        let size = landed ?? Rect(x: 0, y: 0, w: 0, h: 0)
                        let wanted = Layout.fit(
                            w: size.w, h: size.h, in: target, for: action, screen: screen, from: before)
                        let refused = abs(size.w - 300) <= 2  // it really kept its own width
                        check(
                            "Fixed-size: \(action.title)", refused && close(landed, wanted),
                            "landed \(text(landed)), wanted \(text(wanted))")
                    }
                }
            }
            sequence(steps, every: 0.35) {
                kill(pid, SIGUSR2)  // dummy closes it again, so the tiling tests count 1 window
                #if GRIDLE_PRO
                    after(0.5) { tiling(pid) }
                #else
                    finish()  // the free edition ends here: stack, grid and layouts are Pro
                #endif
            }
        }
    }

    // MARK: - The test-window side (`--dummy`)

    private static var dummyWindows: [NSWindow] = []
    private static var dummySignal: DispatchSourceSignal?

    static func startDummy() {
        NSApp.setActivationPolicy(.regular)
        openDummyWindow()
        // SIGUSR1 = "open one more window" (lets the test side add windows on demand).
        signal(SIGUSR1, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        source.setEventHandler {
            // `data` = how many signals arrived since the last call, in case some were merged.
            for _ in 0..<max(1, Int(source.data)) { openDummyWindow() }
        }
        source.resume()
        dummySignal = source
        signal(SIGUSR2, SIG_IGN)
        let fixed = DispatchSource.makeSignalSource(signal: SIGUSR2, queue: .main)
        fixed.setEventHandler { toggleFixedWindow() }
        fixed.resume()
        fixedSignal = fixed
        // SIGINFO = the demo's "show desktop": take every window off screen for one second, then back.
        // Asking from the outside did not hide these windows during a recording on macOS 27.
        signal(SIGINFO, SIG_IGN)
        let hide = DispatchSource.makeSignalSource(signal: SIGINFO, queue: .main)
        hide.setEventHandler {
            // Take the windows off screen directly: inside the demo, NSApp.hide left them visible.
            let shown = (dummyWindows + [fixedWindow].compactMap { $0 }).filter { $0.isVisible }
            for window in shown { window.orderOut(nil) }
            SelfTest.after(1.0) { for window in shown { window.orderFront(nil) } }
        }
        hide.resume()
        hideSignal = hide
    }

    private static var hideSignal: DispatchSourceSignal?

    private static var fixedWindow: NSWindow?
    private static var fixedSignal: DispatchSourceSignal?

    /// SIGUSR2 toggles a 300 × 200 window that cannot be resized.
    private static func toggleFixedWindow() {
        if let window = fixedWindow {
            window.close()
            fixedWindow = nil
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 300, y: 300, width: 300, height: 200), styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        window.title = "Gridle fixed test"
        if DemoStyle.isOn { DemoStyle.decorateFixed(window) }
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        fixedWindow = window
    }

    private static func openDummyWindow() {
        let n = dummyWindows.count + 1
        let window = NSWindow(
            contentRect: NSRect(x: 160 + n * 40, y: 160 + n * 40, width: 420, height: 300),
            styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Gridle self-test \(n)"
        if DemoStyle.isOn { DemoStyle.decorate(window, number: n) }
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        dummyWindows.append(window)
    }

    // MARK: - Helpers

    static func check(_ name: String, _ ok: Bool, _ detail: String) {
        if ok { passes += 1 } else { failures += 1 }
        say("\(ok ? "pass" : "FAIL")  \(name)\(ok ? "" : " - \(detail)")")
    }

    /// Within 2 points on every edge: AppKit rounds window frames to whole points.
    static func close(_ a: Rect?, _ b: Rect?) -> Bool {
        guard let a, let b else { return false }
        return abs(a.x - b.x) <= 2 && abs(a.y - b.y) <= 2 && abs(a.w - b.w) <= 2 && abs(a.h - b.h) <= 2
    }

    static func text(_ r: Rect?) -> String {
        guard let r else { return "nothing" }
        return "\(Int(r.x)),\(Int(r.y)) \(Int(r.w))x\(Int(r.h))"
    }

    static func after(_ seconds: Double, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    static func sequence(_ steps: [() -> Void], every seconds: Double, then done: @escaping () -> Void) {
        guard let first = steps.first else { return done() }
        first()
        after(seconds) { sequence(Array(steps.dropFirst()), every: seconds, then: done) }
    }

    static func say(_ line: String) {
        print(line)
        fflush(stdout)
    }

    static func finish() {
        dummy?.terminate()
        // Nothing passed means nothing was tested, and that is never green.
        let green = failures == 0 && passes > 0
        say("\(green ? "GREEN" : "RED") - \(passes) passed, \(failures) failed")
        exit(green ? 0 : 1)
    }
}
