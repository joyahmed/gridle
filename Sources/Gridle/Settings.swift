import Foundation
import GridleCore
import Observation

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
    #if GRIDLE_PRO
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
        Settings.copyFromPanesOnce(defaults)
        gap = defaults.object(forKey: "gap") == nil ? 8 : defaults.double(forKey: "gap")
        bindings = Keymap.merged(saved: Settings.load([KeyBinding].self, key: "bindings") ?? [])
        #if GRIDLE_PRO
            layouts = Settings.load([SavedLayout].self, key: "layouts") ?? []
        #endif
        ignored = defaults.stringArray(forKey: "ignored") ?? []
        dragToSnap = defaults.object(forKey: "dragToSnap") == nil ? true : defaults.bool(forKey: "dragToSnap")
    }

    /// Gridle was called Panes up to 0.1.0, with the app ID `com.joyahmed.panes`. A new app ID means
    /// a new settings file, so the first start copies the old keys, gap and ignore list across once.
    /// A key Gridle already has is never overwritten.
    private static func copyFromPanesOnce(_ defaults: UserDefaults) {
        guard !defaults.bool(forKey: "copiedFromPanes") else { return }
        defaults.set(true, forKey: "copiedFromPanes")
        guard let old = defaults.persistentDomain(forName: "com.joyahmed." + "panes") else { return }
        for key in ["gap", "bindings", "layouts", "ignored", "dragToSnap"] where defaults.object(forKey: key) == nil {
            if let value = old[key] { defaults.set(value, forKey: key) }
        }
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
