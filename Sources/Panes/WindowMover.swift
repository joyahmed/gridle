import AppKit
import PanesCore

/// Moves the front window of the front app to where `Layout` says it goes.
enum WindowMover {
    static var gap: Double { Settings.shared.gap }

    /// Moves the front window. Returns the screen it used, or nil when nothing moved.
    @discardableResult
    static func apply(_ action: Action) -> Rect? {
        guard AX.isAllowed else {
            AX.askForPermission()
            return nil
        }
        let front = NSWorkspace.shared.frontmostApplication
        guard !Settings.shared.isIgnored(front?.bundleIdentifier) else {
            NSSound.beep()
            return nil
        }
        guard let pid = front?.processIdentifier,
            let window = AX.focusedWindow(of: pid), let screen = apply(action, window: window)
        else {
            NSSound.beep()
            return nil
        }
        return screen
    }

    /// Moves one given window. The self-test uses this to move only its own test windows.
    /// `on`: the screen to use. A drag passes the screen under the pointer; keys pass nil
    /// and use the screen holding the window's centre.
    static func apply(_ action: Action, window: AXUIElement, on chosen: Rect? = nil) -> Rect? {
        guard let current = AX.frame(of: window),
            let screen = chosen ?? Layout.screen(for: current, among: Screens.all()),
            let target = Layout.frame(for: action, in: screen, gap: gap)
        else { return nil }
        AX.set(window, to: target)
        // A window that refused the size (fixed-size, or a minimum size) is pushed into
        // the corner or edge the action asked for, instead of sitting at the area's top-left.
        if let landed = AX.frame(of: window), abs(landed.w - target.w) > 2 || abs(landed.h - target.h) > 2 {
            let placed = Layout.fit(
                w: landed.w, h: landed.h, in: target, for: action, screen: screen, from: current)
            AX.setPosition(window, to: placed)
        }
        return screen
    }

    /// Sends a window to the next screen, keeping its relative spot. False with one screen.
    static func sendToNextScreen(_ window: AXUIElement) -> Bool {
        let screens = Screens.all()
        guard let frame = AX.frame(of: window), let current = Layout.screen(for: frame, among: screens),
            let next = Layout.nextScreen(after: current, among: screens)
        else { return false }
        AX.set(window, to: Layout.move(frame, from: current, to: next))
        return true
    }
}
