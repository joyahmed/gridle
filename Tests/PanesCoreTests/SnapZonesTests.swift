import Testing

@testable import PanesCore

private let screen = Rect(x: 0, y: 0, w: 1000, h: 800)
private let second = Rect(x: -1200, y: 100, w: 1200, h: 700)

private func zone(_ x: Double, _ y: Double, on s: Rect = screen) -> Action? {
    SnapZones.action(atX: x, y: y, onScreen: s)
}

@Test func edgesGiveHalvesAndFill() {
    #expect(zone(0, 400) == .leftHalf)
    #expect(zone(1000, 400) == .rightHalf)
    #expect(zone(500, 0) == .fill)
}

@Test func cornersGiveQuarters() {
    #expect(zone(0, 0) == .topLeft)
    #expect(zone(1000, 0) == .topRight)
    #expect(zone(0, 800) == .bottomLeft)
    #expect(zone(1000, 800) == .bottomRight)
    #expect(zone(30, 0) == .topLeft)
    #expect(zone(0, 30) == .topLeft)
    #expect(zone(970, 800) == .bottomRight)
}

@Test func middleAndBottomEdgeGiveNothing() {
    #expect(zone(500, 400) == nil)
    #expect(zone(500, 800) == nil)
    #expect(zone(500, 795) == nil)
    #expect(zone(100, 790) == nil)
}

@Test func edgeBoundaryIsSixPoints() {
    #expect(zone(6, 400) == .leftHalf)
    #expect(zone(6.5, 400) == nil)
    #expect(zone(994, 400) == .rightHalf)
    #expect(zone(993.5, 400) == nil)
    #expect(zone(500, 6) == .fill)
    #expect(zone(500, 6.5) == nil)
}

@Test func cornerBoundaryIsSixtyPoints() {
    #expect(zone(0, 60) == .topLeft)
    #expect(zone(0, 61) == .leftHalf)
    #expect(zone(60, 0) == .topLeft)
    #expect(zone(61, 0) == .fill)
    #expect(zone(1000, 740) == .bottomRight)
    #expect(zone(1000, 739) == .rightHalf)
    #expect(zone(60, 800) == .bottomLeft)
    #expect(zone(61, 800) == nil)
}

@Test func secondScreenWithNegativeX() {
    #expect(zone(-1200, 400, on: second) == .leftHalf)
    #expect(zone(0, 400, on: second) == .rightHalf)
    #expect(zone(-600, 100, on: second) == .fill)
    #expect(zone(-1200, 100, on: second) == .topLeft)
    #expect(zone(-1, 800, on: second) == .bottomRight)
    #expect(zone(-600, 450, on: second) == nil)
}

@Test func outsideTheScreenGivesNothing() {
    #expect(zone(-5, 400) == nil)
    #expect(zone(500, 900) == nil)
}
