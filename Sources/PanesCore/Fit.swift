/// Windows that refuse a size (a fixed-size settings window, an app with a minimum size)
/// keep their own size. `fit` then places that size against the right edge or corner of
/// the area the action wanted, so "top right" still means top right.
extension Layout {
    /// `keep`: this action does not say where on that axis, so the window stays where it is.
    enum Edge { case start, middle, end, keep }

    /// Which side of the target area each action hugs: (horizontal, vertical).
    static func anchor(for action: Action) -> (Edge, Edge) {
        switch action {
        case .leftHalf, .leftThird: (.start, .keep)
        case .rightHalf, .rightThird: (.end, .keep)
        case .middleThird: (.middle, .keep)
        case .topHalf: (.keep, .start)
        case .bottomHalf: (.keep, .end)
        case .topLeft: (.start, .start)
        case .topRight: (.end, .start)
        case .bottomLeft: (.start, .end)
        case .bottomRight: (.end, .end)
        default: (.middle, .middle)
        }
    }

    /// A `w` × `h` window placed in `target` the way `action` asks, kept on `screen`.
    /// `from` is where the window was before the key: on an axis the action leaves open
    /// (Up says nothing about left or right), the window keeps that position.
    public static func fit(
        w: Double, h: Double, in target: Rect, for action: Action, screen: Rect, from: Rect? = nil
    ) -> Rect {
        let (ax, ay) = anchor(for: action)
        func place(_ edge: Edge, _ start: Double, _ room: Double, _ size: Double, _ was: Double?) -> Double {
            switch edge {
            case .start: return start
            case .middle: return start + (room - size) / 2
            case .end: return start + room - size
            case .keep:
                guard let was else { return start + (room - size) / 2 }
                return min(max(was, start), max(start, start + room - size))  // stay inside the area
            }
        }
        var x = place(ax, target.x, target.w, w, from?.x)
        var y = place(ay, target.y, target.h, h, from?.y)
        // Never push a window off the screen it belongs to.
        x = min(max(x, screen.x), max(screen.x, screen.x + screen.w - w))
        y = min(max(y, screen.y), max(screen.y, screen.y + screen.h - h))
        return Rect(x: x, y: y, w: w, h: h)
    }
}
