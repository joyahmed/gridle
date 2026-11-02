import Testing

@testable import PanesCore

private let screen = Rect(x: 0, y: 25, w: 1200, h: 800)

/// A fixed 480 × 420 window, like Panes Settings.
private func fitted(_ action: Action) -> Rect {
    let target = Layout.frame(for: action, in: screen)!
    return Layout.fit(w: 480, h: 420, in: target, for: action, screen: screen)
}

@Test func fixedWindowGoesIntoTheRightCorner() {
    #expect(fitted(.topRight) == Rect(x: 720, y: 25, w: 480, h: 420))
    #expect(fitted(.bottomRight) == Rect(x: 720, y: 405, w: 480, h: 420))
    #expect(fitted(.topLeft) == Rect(x: 0, y: 25, w: 480, h: 420))
    #expect(fitted(.bottomLeft) == Rect(x: 0, y: 405, w: 480, h: 420))
}

@Test func fixedWindowHugsTheRightEdge() {
    let r = fitted(.rightHalf)
    #expect(r.x + r.w == 1200)
    #expect(r.midY == screen.midY)  // no earlier position known: middle
}

@Test func upFromTheRightEdgeStaysOnTheRight() {
    // Bug seen 2026-11-03: Ctrl+Alt+Up from the right slid the window to the middle.
    let atRight = Rect(x: 720, y: 215, w: 480, h: 420)
    let target = Layout.frame(for: .topHalf, in: screen)!
    let r = Layout.fit(w: 480, h: 420, in: target, for: .topHalf, screen: screen, from: atRight)
    #expect(r == Rect(x: 720, y: 25, w: 480, h: 420))
}

@Test func downFromTheLeftEdgeStaysOnTheLeft() {
    let atLeft = Rect(x: 0, y: 215, w: 480, h: 420)
    let target = Layout.frame(for: .bottomHalf, in: screen)!
    let r = Layout.fit(w: 480, h: 420, in: target, for: .bottomHalf, screen: screen, from: atLeft)
    #expect(r == Rect(x: 0, y: 405, w: 480, h: 420))
}

@Test func rightFromTheTopStaysAtTheTop() {
    let atTop = Rect(x: 360, y: 25, w: 480, h: 420)
    let target = Layout.frame(for: .rightHalf, in: screen)!
    let r = Layout.fit(w: 480, h: 420, in: target, for: .rightHalf, screen: screen, from: atTop)
    #expect(r == Rect(x: 720, y: 25, w: 480, h: 420))
}

@Test func centerStillMeansTheMiddle() {
    let atCorner = Rect(x: 0, y: 25, w: 480, h: 420)
    let target = Layout.frame(for: .center, in: screen)!
    let r = Layout.fit(w: 480, h: 420, in: target, for: .center, screen: screen, from: atCorner)
    #expect(r.midX == screen.midX && r.midY == screen.midY)
}

@Test func fixedWindowSitsInTheMiddleForCenterAndFill() {
    #expect(fitted(.center).midX == screen.midX && fitted(.center).midY == screen.midY)
    #expect(fitted(.fill).midX == screen.midX)
}

@Test func aWindowBiggerThanTheAreaStaysOnScreen() {
    // A corner is 600 × 400; this window insists on 700 × 500.
    let target = Layout.frame(for: .bottomRight, in: screen)!
    let r = Layout.fit(w: 700, h: 500, in: target, for: .bottomRight, screen: screen)
    #expect(r.x + r.w == 1200 && r.y + r.h == 825)
    #expect(r.x >= 0 && r.y >= 25)
}

@Test func aWindowThatTookTheSizeIsUnchanged() {
    let target = Layout.frame(for: .topRight, in: screen)!
    #expect(Layout.fit(w: target.w, h: target.h, in: target, for: .topRight, screen: screen) == target)
}
