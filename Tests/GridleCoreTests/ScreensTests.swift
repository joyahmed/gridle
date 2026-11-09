import Testing

@testable import GridleCore

private let screen = Rect(x: 0, y: 25, w: 1200, h: 800)

@Test func nextScreenGoesLeftToRightAndWraps() {
    let left = Rect(x: -1920, y: 0, w: 1920, h: 1080)
    let main = Rect(x: 0, y: 25, w: 1440, h: 875)
    let right = Rect(x: 1440, y: 0, w: 1920, h: 1080)
    let all = [main, right, left]
    #expect(Layout.nextScreen(after: left, among: all) == main)
    #expect(Layout.nextScreen(after: main, among: all) == right)
    #expect(Layout.nextScreen(after: right, among: all) == left)
}

@Test func nextScreenWithOneScreenIsNil() {
    #expect(Layout.nextScreen(after: screen, among: [screen]) == nil)
}

@Test func moveKeepsTheRelativeSpot() {
    let small = Rect(x: 0, y: 0, w: 1000, h: 500)
    let big = Rect(x: 1000, y: 0, w: 2000, h: 1000)
    let leftHalf = Rect(x: 0, y: 0, w: 500, h: 500)
    #expect(Layout.move(leftHalf, from: small, to: big) == Rect(x: 1000, y: 0, w: 1000, h: 1000))
}

@Test func moveNeverLeavesTheTargetScreen() {
    let from = Rect(x: 0, y: 0, w: 1000, h: 1000)
    let to = Rect(x: 1000, y: 0, w: 500, h: 500)
    let poking = Rect(x: 900, y: 900, w: 300, h: 300)  // hangs off the bottom-right
    let r = Layout.move(poking, from: from, to: to)
    #expect(r.x + r.w <= to.x + to.w && r.y + r.h <= to.y + to.h)
}
