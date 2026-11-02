import AppKit
import PanesCore

/// The translucent box that shows where a dragged window will land.
final class SnapPreview {
    static let shared = SnapPreview()

    private let panel: NSPanel

    private init() {
        panel = NSPanel(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.isReleasedWhenClosed = false
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.25).cgColor
        view.layer?.borderColor = NSColor.controlAccentColor.cgColor
        view.layer?.borderWidth = 2
        view.layer?.cornerRadius = 10
        panel.contentView = view
    }

    /// Shows the box over `r` (Accessibility coordinates). Slides if it is already showing.
    func show(axRect r: Rect) {
        let primaryHeight = Double(NSScreen.screens.first?.frame.height ?? 0)
        let frame = CGRect(x: r.x, y: primaryHeight - (r.y + r.h), width: r.w, height: r.h)
        if panel.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
            panel.orderFrontRegardless()
        }
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
    }
}
