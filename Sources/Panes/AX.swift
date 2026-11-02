import AppKit
import ApplicationServices
import PanesCore

/// Small helpers over the Accessibility API, the only way to move another app's window.
/// Every call here needs the Accessibility permission.
enum AX {
    static var isAllowed: Bool { AXIsProcessTrusted() }

    /// Shows macOS's own "allow Panes to control your computer" prompt.
    static func askForPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func focusedWindow(of pid: pid_t) -> AXUIElement? {
        element(AXUIElementCreateApplication(pid), kAXFocusedWindowAttribute)
    }

    static func windows(of pid: pid_t) -> [AXUIElement] {
        var value: CFTypeRef?
        let app = AXUIElementCreateApplication(pid)
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
            let list = value as? [AXUIElement]
        else { return [] }
        return list
    }

    /// A normal window: not a panel, sheet or popover, and not minimised.
    static func isNormal(_ window: AXUIElement) -> Bool {
        var subrole: CFTypeRef?
        var minimised: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subrole)
        AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimised)
        return (subrole as? String) == kAXStandardWindowSubrole && (minimised as? Bool) != true
    }

    static func title(of window: AXUIElement) -> String {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &value)
        return (value as? String) ?? ""
    }

    static func frame(of window: AXUIElement) -> Rect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
            AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
            let posRef, let sizeRef
        else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        return Rect(x: point.x, y: point.y, w: size.width, h: size.height)
    }

    /// Size, then position, then size again: some apps clamp the size to the
    /// screen they are on, so the second resize lands it after the move.
    static func set(_ window: AXUIElement, to r: Rect) {
        var point = CGPoint(x: r.x, y: r.y)
        var size = CGSize(width: r.w, height: r.h)
        guard let pos = AXValueCreate(.cgPoint, &point), let sz = AXValueCreate(.cgSize, &size) else { return }
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sz)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pos)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sz)
    }

    /// Moves without resizing.
    static func setPosition(_ window: AXUIElement, to r: Rect) {
        var point = CGPoint(x: r.x, y: r.y)
        guard let pos = AXValueCreate(.cgPoint, &point) else { return }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pos)
    }

    private static func element(_ parent: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(parent, attribute as CFString, &value) == .success,
            let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }
}

/// The usable area of every screen (menu bar and Dock removed), in Accessibility coordinates.
enum Screens {
    static func all() -> [Rect] {
        let primaryHeight = Double(NSScreen.screens.first?.frame.height ?? 0)
        return NSScreen.screens.map { Layout.axRect(fromCocoa: Rect($0.visibleFrame), primaryHeight: primaryHeight) }
    }
}

extension Rect {
    init(_ r: CGRect) { self.init(x: r.origin.x, y: r.origin.y, w: r.width, h: r.height) }
}
