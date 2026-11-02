import Foundation
import Observation
import PanesCore

/// Everything the user can change, kept in UserDefaults so it survives a restart.
@Observable
final class Settings {
    static let shared = Settings()

    var gap: Double {
        didSet { UserDefaults.standard.set(gap, forKey: "gap") }
    }
    var bindings: [KeyBinding] {
        didSet {
            Settings.save(bindings, key: "bindings")
            onKeysChanged?()
        }
    }
    #if PANES_PRO
        var layouts: [SavedLayout] {
            didSet { Settings.save(layouts, key: "layouts") }
        }
    #endif
    var ignored: [String] {
        didSet { UserDefaults.standard.set(ignored, forKey: "ignored") }
    }

    var dragToSnap: Bool {
        didSet { UserDefaults.standard.set(dragToSnap, forKey: "dragToSnap") }
    }

    /// Called after the keys change so they can be registered again.
    @ObservationIgnored var onKeysChanged: (() -> Void)?

    private init() {
        let defaults = UserDefaults.standard
        gap = defaults.object(forKey: "gap") == nil ? 8 : defaults.double(forKey: "gap")
        bindings = Keymap.merged(saved: Settings.load([KeyBinding].self, key: "bindings") ?? [])
        #if PANES_PRO
            layouts = Settings.load([SavedLayout].self, key: "layouts") ?? []
        #endif
        ignored = defaults.stringArray(forKey: "ignored") ?? []
        dragToSnap = defaults.object(forKey: "dragToSnap") == nil ? true : defaults.bool(forKey: "dragToSnap")
    }

    func isIgnored(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return ignored.contains(bundleID)
    }

    private static func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: key) }
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
