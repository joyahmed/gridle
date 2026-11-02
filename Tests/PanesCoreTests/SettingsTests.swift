import Foundation
import Testing

@testable import PanesCore

// MARK: - Keys

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
