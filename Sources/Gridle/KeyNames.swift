import AppKit
import GridleCore

/// Turns a typed key into the pieces a KeyBinding needs.
enum KeyNames {
    /// The held modifier keys as Carbon numbers.
    static func mods(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.control) { m |= Mods.control }
        if flags.contains(.option) { m |= Mods.option }
        if flags.contains(.shift) { m |= Mods.shift }
        if flags.contains(.command) { m |= Mods.command }
        return m
    }

    /// What to show for the key itself, like ← or Return or K.
    static func label(_ event: NSEvent) -> String {
        switch event.keyCode {
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 36: return "Return"
        case 49: return "Space"
        case 48: return "Tab"
        case 51: return "Delete"
        default: return (event.charactersIgnoringModifiers ?? "?").uppercased()
        }
    }
}
