import Foundation
import Testing

@testable import GridleCore

// MARK: - Keys

@Test func numberPadFiresTheSameThirdsAndFillAsTheMainKeys() {
    let twins = Keymap.twinKeys(for: Keymap.defaults)
    #expect(twins.first { $0.action == .leftThird }?.keyCode == 83)
    #expect(twins.first { $0.action == .middleThird }?.keyCode == 84)
    #expect(twins.first { $0.action == .rightThird }?.keyCode == 85)
    #expect(twins.first { $0.action == .fill }?.keyCode == 76)
    #expect(twins.count == 4)  // letters and arrows have no twin
}

@Test func aKeyRecordedOnTheNumberPadAlsoFiresFromTheTopRow() {
    let pad = KeyBinding(keyCode: 83, label: "1", action: .fill)
    #expect(Keymap.twinKeys(for: [pad]).first?.keyCode == 18)
}

@Test func aTwinNeverTakesAKeyAnotherActionChose() {
    let top = KeyBinding(keyCode: 18, label: "1", action: .leftThird)
    let pad = KeyBinding(keyCode: 83, label: "1", action: .fill)
    #expect(Keymap.twinKeys(for: [top, pad]).isEmpty)
    // The same key with other modifiers is a different key, so the twin stays.
    let padCmd = KeyBinding(keyCode: 83, label: "1", action: .fill, modifiers: Mods.command)
    #expect(Keymap.twinKeys(for: [top, padCmd]).count == 2)
}

@Test func defaultKeysShowAsCtrlAlt() {
    #expect(Keymap.defaults[0].display == "Ctrl+Alt+←")
    #expect(Mods.words(Mods.control | Mods.shift | Mods.command) == "Ctrl+Shift+Win+")
}

@Test func aKeyUsedByAnotherActionIsAConflict() {
    let taken = KeyBinding(keyCode: 123, label: "←", action: .fill)  // Ctrl+Alt+← belongs to left half
    #expect(Keymap.conflict(taken, in: Keymap.defaults) == .leftHalf)
}

@Test func reRecordingTheSameKeyIsNotAConflict() {
    let same = KeyBinding(keyCode: 123, label: "←", action: .leftHalf)
    #expect(Keymap.conflict(same, in: Keymap.defaults) == nil)
}

@Test func sameKeyWithOtherModifiersIsFree() {
    let cmdLeft = KeyBinding(keyCode: 123, label: "←", action: .fill, modifiers: Mods.command | Mods.option)
    #expect(Keymap.conflict(cmdLeft, in: Keymap.defaults) == nil)
}

@Test func replacingKeepsOrderAndCount() {
    let newFill = KeyBinding(keyCode: 3, label: "F", action: .fill)
    let out = Keymap.replacing(newFill, in: Keymap.defaults)
    #expect(out.count == Keymap.defaults.count)
    #expect(out.firstIndex { $0.action == .fill } == Keymap.defaults.firstIndex { $0.action == .fill })
    #expect(out.first { $0.action == .fill }?.label == "F")
}

@Test func mergedAddsActionsMissingFromAnOldSave() {
    let oldSave = [KeyBinding(keyCode: 3, label: "F", action: .fill)]
    let out = Keymap.merged(saved: oldSave)
    #expect(out.count == Keymap.defaults.count)
    #expect(out.first { $0.action == .fill }?.label == "F")
    #expect(out.first { $0.action == .nextScreen } == Keymap.defaults.first { $0.action == .nextScreen })
}

@Test func keysSurviveSavingAndLoading() throws {
    let data = try JSONEncoder().encode(Keymap.defaults)
    #expect(try JSONDecoder().decode([KeyBinding].self, from: data) == Keymap.defaults)
}
