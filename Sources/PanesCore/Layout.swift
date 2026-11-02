/// A rectangle in screen points. PanesCore uses the Accessibility coordinate
/// system: origin at the TOP-left of the primary screen, y grows downward.
public struct Rect: Equatable, Sendable, Codable {
    public var x: Double, y: Double, w: Double, h: Double
    public init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }
    public var midX: Double { x + w / 2 }
    public var midY: Double { y + h / 2 }
    public func contains(x px: Double, y py: Double) -> Bool {
        px >= x && px < x + w && py >= y && py < y + h
    }
    func inset(_ d: Double) -> Rect { Rect(x: x + d, y: y + d, w: w - 2 * d, h: h - 2 * d) }
}

/// Everything a key can do.
public enum Action: String, CaseIterable, Sendable, Codable {
    case leftHalf, rightHalf, topHalf, bottomHalf, fill, center
    case topLeft, topRight, bottomLeft, bottomRight
    case leftThird, middleThird, rightThird
    case showDesktop
    case stack, grid, nextScreen

    public var title: String {
        switch self {
        case .leftHalf: "Left half"
        case .rightHalf: "Right half"
        case .topHalf: "Top half"
        case .bottomHalf: "Bottom half"
        case .fill: "Fill screen"
        case .center: "Center"
        case .topLeft: "Top left"
        case .topRight: "Top right"
        case .bottomLeft: "Bottom left"
        case .bottomRight: "Bottom right"
        case .leftThird: "Left third"
        case .middleThird: "Middle third"
        case .rightThird: "Right third"
        case .showDesktop: "Show desktop"
        case .stack: "Stack all"
        case .grid: "Grid all"
        case .nextScreen: "Next screen"
        }
    }
}

public enum Layout {
    /// Where a window goes for `action` on a screen whose usable area is `screen`
    /// (menu bar and Dock already removed). `gap` is the space between windows and
    /// around the screen edge. Returns nil for actions that do not place one window.
    public static func frame(for action: Action, in screen: Rect, gap: Double = 0) -> Rect? {
        let s = screen.inset(gap / 2)
        let (hw, hh, tw) = (s.w / 2, s.h / 2, s.w / 3)
        let r: Rect
        switch action {
        case .leftHalf: r = Rect(x: s.x, y: s.y, w: hw, h: s.h)
        case .rightHalf: r = Rect(x: s.x + hw, y: s.y, w: hw, h: s.h)
        case .topHalf: r = Rect(x: s.x, y: s.y, w: s.w, h: hh)
        case .bottomHalf: r = Rect(x: s.x, y: s.y + hh, w: s.w, h: hh)
        case .fill: r = s
        case .center:
            let w = s.w * 0.7
            let h = s.h * 0.8
            r = Rect(x: s.x + (s.w - w) / 2, y: s.y + (s.h - h) / 2, w: w, h: h)
        case .topLeft: r = Rect(x: s.x, y: s.y, w: hw, h: hh)
        case .topRight: r = Rect(x: s.x + hw, y: s.y, w: hw, h: hh)
        case .bottomLeft: r = Rect(x: s.x, y: s.y + hh, w: hw, h: hh)
        case .bottomRight: r = Rect(x: s.x + hw, y: s.y + hh, w: hw, h: hh)
        case .leftThird: r = Rect(x: s.x, y: s.y, w: tw, h: s.h)
        case .middleThird: r = Rect(x: s.x + tw, y: s.y, w: tw, h: s.h)
        case .rightThird: r = Rect(x: s.x + 2 * tw, y: s.y, w: tw, h: s.h)
        case .showDesktop, .stack, .grid, .nextScreen: return nil
        }
        return r.inset(gap / 2)
    }

    /// Converts an AppKit rect (origin bottom-left of the primary screen, y up)
    /// to the Accessibility system PanesCore uses (origin top-left, y down).
    public static func axRect(fromCocoa r: Rect, primaryHeight: Double) -> Rect {
        Rect(x: r.x, y: primaryHeight - (r.y + r.h), w: r.w, h: r.h)
    }

    /// The screen a window belongs to: the one holding the window's centre,
    /// else the first screen. Screens must already be in AX coordinates.
    public static func screen(for window: Rect, among screens: [Rect]) -> Rect? {
        screens.first { $0.contains(x: window.midX, y: window.midY) } ?? screens.first
    }
}
