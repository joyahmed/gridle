import AppKit
import ApplicationServices
import PanesCore

/// Snap by dragging: grab a window by its title bar, push the pointer to a screen edge,
/// and a preview shows where it will land. Letting go snaps it.
final class DragSnapper {
    static let shared = DragSnapper()

    private enum Phase {
        case idle
        case watching  // mouse is down on a window; not yet known to be a move
        case moving  // the window itself is moving
        case ignored  // a resize, or a window we leave alone
    }

    private var monitors: [Any] = []
    private var phase = Phase.idle
    private var window: AXUIElement?
    private var startFrame: Rect?
    private var zone: (action: Action, screen: Int)?

    private init() {}

    func start() {
        guard monitors.isEmpty else { return }
        let add = { (mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> Void) in
            if let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler) {
                self.monitors.append(monitor)
            }
        }
        add(.leftMouseDown) { [weak self] _ in self?.mouseDown() }
        add(.leftMouseDragged) { [weak self] _ in self?.mouseDragged() }
        add(.leftMouseUp) { [weak self] _ in self?.mouseUp() }
    }

    func stop() {
        for monitor in monitors { NSEvent.removeMonitor(monitor) }
        monitors = []
        reset()
    }

    private func reset() {
        SnapPreview.shared.hide()
        phase = .idle
        window = nil
        startFrame = nil
        zone = nil
    }

    // MARK: - Events

    private func mouseDown() {
        reset()
        guard AX.isAllowed, let found = windowUnderPointer(), let frame = AX.frame(of: found) else { return }
        window = found
        startFrame = frame
        phase = .watching
    }

    private func mouseDragged() {
        switch phase {
        case .idle, .ignored: return
        case .watching:
            // A move changes the position and keeps the size. Anything that changes the
            // size is a resize and never snaps.
            guard let window, let start = startFrame, let now = AX.frame(of: window) else {
                phase = .ignored
                return
            }
            if abs(now.w - start.w) > 1 || abs(now.h - start.h) > 1 {
                phase = .ignored
                return
            }
            guard abs(now.x - start.x) > 1 || abs(now.y - start.y) > 1 else { return }
            phase = .moving
            updateZone()
        case .moving:
            updateZone()
        }
    }

    private func mouseUp() {
        let snap = phase == .moving ? zone : nil
        let target = window
        reset()
        guard let snap, let target else { return }
        // Snap on the screen under the pointer, the same one the preview showed.
        let screens = Screens.all()
        guard screens.indices.contains(snap.screen) else { return }
        _ = WindowMover.apply(snap.action, window: target, on: screens[snap.screen])
        #if PANES_PRO
            Tiler.shared.stop(on: screens[snap.screen])
        #endif
    }

    // MARK: - Zone

    private func updateZone() {
        let mouse = NSEvent.mouseLocation
        let primaryHeight = Double(NSScreen.screens.first?.frame.height ?? 0)
        let point = (x: Double(mouse.x), y: primaryHeight - Double(mouse.y))
        let fulls = NSScreen.screens.map {
            Layout.axRect(fromCocoa: Rect($0.frame), primaryHeight: primaryHeight)
        }
        // Inclusive on every side: the pointer can sit exactly on the far edge.
        guard
            let index = fulls.firstIndex(where: {
                point.x >= $0.x && point.x <= $0.x + $0.w && point.y >= $0.y && point.y <= $0.y + $0.h
            }),
            let action = SnapZones.action(atX: point.x, y: point.y, onScreen: fulls[index])
        else {
            if zone != nil { zone = nil }
            SnapPreview.shared.hide()
            return
        }
        if let zone, zone.action == action, zone.screen == index { return }
        let visible = Screens.all()
        guard visible.indices.contains(index),
            let target = Layout.frame(for: action, in: visible[index], gap: WindowMover.gap)
        else { return }
        zone = (action, index)
        SnapPreview.shared.show(axRect: target)
    }

    // MARK: - Finding the window

    private func windowUnderPointer() -> AXUIElement? {
        let mouse = NSEvent.mouseLocation
        let primaryHeight = Double(NSScreen.screens.first?.frame.height ?? 0)
        var hit: AXUIElement?
        guard
            AXUIElementCopyElementAtPosition(
                AXUIElementCreateSystemWide(), Float(mouse.x), Float(primaryHeight - Double(mouse.y)), &hit)
                == .success,
            let hit
        else { return nil }

        var pid: pid_t = 0
        guard AXUIElementGetPid(hit, &pid) == .success, pid != getpid() else { return nil }
        let bundle = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
        guard !Settings.shared.isIgnored(bundle) else { return nil }

        if role(of: hit) == kAXWindowRole as String { return hit }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(hit, kAXWindowAttribute as CFString, &value) == .success,
            let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }

    private func role(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value)
        return value as? String
    }
}
