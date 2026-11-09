/// Moving a window between screens.
extension Layout {
    /// The screen after `current`, left to right (then top to bottom), wrapping round.
    /// nil when there is only one screen.
    public static func nextScreen(after current: Rect, among screens: [Rect]) -> Rect? {
        guard screens.count > 1 else { return nil }
        let ordered = screens.sorted { ($0.x, $0.y) < ($1.x, $1.y) }
        guard let i = ordered.firstIndex(of: current) else { return ordered.first }
        return ordered[(i + 1) % ordered.count]
    }

    /// Moves `window` from one screen to another, keeping its relative spot and size.
    public static func move(_ window: Rect, from: Rect, to: Rect) -> Rect {
        let sx = to.w / from.w
        let sy = to.h / from.h
        let w = min(window.w * sx, to.w)
        let h = min(window.h * sy, to.h)
        let x = to.x + (window.x - from.x) * sx
        let y = to.y + (window.y - from.y) * sy
        return Rect(x: min(max(x, to.x), to.x + to.w - w), y: min(max(y, to.y), to.y + to.h - h), w: w, h: h)
    }
}
