/// Which action a dragged window snaps to, from where the pointer is on a screen.
/// Like Windows Aero Snap: left/right edge = halves, top edge = fill, corners = quarters.
public enum SnapZones {
    /// `full` is the screen's FULL frame (not the visible one: the pointer reaches the
    /// menu-bar area). `edge` is how close to a side counts as "at the edge"; `corner` is
    /// how close to the adjacent side makes it a corner. The bottom edge alone gives nil.
    public static func action(
        atX x: Double, y: Double, onScreen full: Rect, edge: Double = 6, corner: Double = 60
    ) -> Action? {
        guard x >= full.x, x <= full.x + full.w, y >= full.y, y <= full.y + full.h else { return nil }
        let left = x - full.x
        let right = full.x + full.w - x
        let top = y - full.y
        let bottom = full.y + full.h - y

        let nearLeft = left <= edge
        let nearRight = right <= edge
        let nearTop = top <= edge
        let nearBottom = bottom <= edge

        if (nearLeft && top <= corner) || (nearTop && left <= corner) { return .topLeft }
        if (nearRight && top <= corner) || (nearTop && right <= corner) { return .topRight }
        if (nearLeft && bottom <= corner) || (nearBottom && left <= corner) { return .bottomLeft }
        if (nearRight && bottom <= corner) || (nearBottom && right <= corner) { return .bottomRight }
        if nearLeft { return .leftHalf }
        if nearRight { return .rightHalf }
        if nearTop { return .fill }
        return nil
    }
}
