import Testing

@testable import PanesCore

private let screen = Rect(x: 0, y: 25, w: 1200, h: 800)

@Test func halvesSplitTheScreen() {
    #expect(Layout.frame(for: .leftHalf, in: screen) == Rect(x: 0, y: 25, w: 600, h: 800))
    #expect(Layout.frame(for: .rightHalf, in: screen) == Rect(x: 600, y: 25, w: 600, h: 800))
    #expect(Layout.frame(for: .topHalf, in: screen) == Rect(x: 0, y: 25, w: 1200, h: 400))
    #expect(Layout.frame(for: .bottomHalf, in: screen) == Rect(x: 0, y: 425, w: 1200, h: 400))
}

@Test func cornersAreQuarters() {
    #expect(Layout.frame(for: .topLeft, in: screen) == Rect(x: 0, y: 25, w: 600, h: 400))
    #expect(Layout.frame(for: .bottomRight, in: screen) == Rect(x: 600, y: 425, w: 600, h: 400))
}

@Test func bottomLeftCorner() {
    #expect(Layout.frame(for: .bottomLeft, in: screen) == Rect(x: 0, y: 425, w: 600, h: 400))
}

@Test func thirdsTileWithoutOverlap() {
    let l = Layout.frame(for: .leftThird, in: screen)!
    let m = Layout.frame(for: .middleThird, in: screen)!
    let r = Layout.frame(for: .rightThird, in: screen)!
    #expect(l.x + l.w == m.x)
    #expect(m.x + m.w == r.x)
    #expect(r.x + r.w == 1200)
}

@Test func fillAndCenter() {
    #expect(Layout.frame(for: .fill, in: screen) == screen)
    let c = Layout.frame(for: .center, in: screen)!
    #expect(c.w == 840 && c.h == 640)
    #expect(c.midX == screen.midX && c.midY == screen.midY)
}

@Test func gapAppearsBetweenWindowsAndAtEdges() {
    let l = Layout.frame(for: .leftHalf, in: screen, gap: 8)!
    let r = Layout.frame(for: .rightHalf, in: screen, gap: 8)!
    #expect(l.x == 8 && l.y == 33)
    #expect(r.x - (l.x + l.w) == 8)
    #expect(1200 - (r.x + r.w) == 8)
}

@Test func showDesktopPlacesNoWindow() {
    #expect(Layout.frame(for: .showDesktop, in: screen) == nil)
}

@Test func cocoaToAxFlipsY() {
    // Primary 1440x900; menu bar 25 pt at the top, so visibleFrame starts at y=0, h=875.
    let ax = Layout.axRect(fromCocoa: Rect(x: 0, y: 0, w: 1440, h: 875), primaryHeight: 900)
    #expect(ax == Rect(x: 0, y: 25, w: 1440, h: 875))
    // A second screen placed ABOVE the primary has a negative AX y.
    let above = Layout.axRect(fromCocoa: Rect(x: 0, y: 900, w: 1920, h: 1080), primaryHeight: 900)
    #expect(above.y == -1080)
}

@Test func windowGoesToTheScreenHoldingItsCentre() {
    let left = Rect(x: 0, y: 0, w: 1000, h: 800)
    let right = Rect(x: 1000, y: 0, w: 1000, h: 800)
    let win = Rect(x: 900, y: 100, w: 400, h: 300)  // centre x = 1100
    #expect(Layout.screen(for: win, among: [left, right]) == right)
    let offscreen = Rect(x: 5000, y: 5000, w: 10, h: 10)
    #expect(Layout.screen(for: offscreen, among: [left, right]) == left)
}

@Test func everyActionHasExactlyOneDefaultKey() {
    let actions = Keymap.defaults.map(\.action)
    #expect(Set(actions).count == actions.count)
    #if PANES_PRO
        #expect(Set(actions) == Set(Action.allCases))
    #else
        // The free edition has no stack or grid key.
        #expect(Set(actions) == Set(Action.allCases).subtracting([.stack, .grid]))
    #endif
    let codes = Keymap.defaults.map(\.keyCode)
    #expect(Set(codes).count == codes.count)
}
