/// Modifier keys, numbered the way macOS's hotkey API (Carbon) numbers them.
public enum Mods {
    public static let command: UInt32 = 0x0100
    public static let shift: UInt32 = 0x0200
    public static let option: UInt32 = 0x0800
    public static let control: UInt32 = 0x1000
    public static let ctrlOpt = control | option

    /// Plain words for the keys, as printed on a Windows keyboard: "Ctrl+Alt+".
    /// The Mac's Command key is the Windows key there, so it is called "Win".
    public static func words(_ m: UInt32) -> String {
        var parts: [String] = []
        if m & control != 0 { parts.append("Ctrl") }
        if m & option != 0 { parts.append("Alt") }
        if m & shift != 0 { parts.append("Shift") }
        if m & command != 0 { parts.append("Win") }
        return parts.map { $0 + "+" }.joined()
    }
}

/// One global key: a macOS virtual key code, its modifiers, and the action it runs.
/// Every default uses Ctrl + Option (Ctrl + Alt on a Windows keyboard).
public struct KeyBinding: Equatable, Sendable, Codable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    public var label: String
    public var action: Action

    public init(keyCode: UInt32, label: String, action: Action, modifiers: UInt32 = Mods.ctrlOpt) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.label = label
        self.action = action
    }

    /// What the menu and Settings show, like Ctrl+Alt+←.
    public var display: String { Mods.words(modifiers) + label }

    public func sameKeys(as other: KeyBinding) -> Bool { keyCode == other.keyCode && modifiers == other.modifiers }
}

public enum Keymap {
    /// Every default key, in menu order. Stack and grid (S, G) exist only in Pro.
    public static let defaults: [KeyBinding] = snaps + pro + [KeyBinding(keyCode: 45, label: "N", action: .nextScreen)]

    private static let snaps: [KeyBinding] = [
        KeyBinding(keyCode: 123, label: "←", action: .leftHalf),
        KeyBinding(keyCode: 124, label: "→", action: .rightHalf),
        KeyBinding(keyCode: 126, label: "↑", action: .topHalf),
        KeyBinding(keyCode: 125, label: "↓", action: .bottomHalf),
        KeyBinding(keyCode: 36, label: "Return", action: .fill),
        KeyBinding(keyCode: 8, label: "C", action: .center),
        KeyBinding(keyCode: 32, label: "U", action: .topLeft),
        KeyBinding(keyCode: 34, label: "I", action: .topRight),
        KeyBinding(keyCode: 38, label: "J", action: .bottomLeft),
        KeyBinding(keyCode: 40, label: "K", action: .bottomRight),
        KeyBinding(keyCode: 18, label: "1", action: .leftThird),
        KeyBinding(keyCode: 19, label: "2", action: .middleThird),
        KeyBinding(keyCode: 20, label: "3", action: .rightThird),
        KeyBinding(keyCode: 2, label: "D", action: .showDesktop),
    ]

    #if PANES_PRO
        private static let pro: [KeyBinding] = [
            KeyBinding(keyCode: 1, label: "S", action: .stack),
            KeyBinding(keyCode: 5, label: "G", action: .grid),
        ]
    #else
        private static let pro: [KeyBinding] = []
    #endif

    /// The OTHER action that already uses `candidate`'s keys, or nil when they are free.
    public static func conflict(_ candidate: KeyBinding, in bindings: [KeyBinding]) -> Action? {
        bindings.first { $0.action != candidate.action && $0.sameKeys(as: candidate) }?.action
    }

    /// `bindings` with `candidate` in place of the old key for the same action, order kept.
    public static func replacing(_ candidate: KeyBinding, in bindings: [KeyBinding]) -> [KeyBinding] {
        guard let i = bindings.firstIndex(where: { $0.action == candidate.action }) else {
            return bindings + [candidate]
        }
        var out = bindings
        out[i] = candidate
        return out
    }

    /// Saved keys, plus the default for any action added to Panes since they were saved.
    public static func merged(saved: [KeyBinding]) -> [KeyBinding] {
        defaults.map { d in saved.first { $0.action == d.action } ?? d }
    }
}
