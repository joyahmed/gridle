import Carbon

/// System-wide keys through Carbon's RegisterEventHotKey. Needs no permission.
/// A key another app already holds fails to register and is reported, never hidden.
final class HotKeys {
    static let shared = HotKeys()
    private var refs: [EventHotKeyRef] = []
    private var handlers: [UInt32: () -> Void] = [:]
    private var installed = false

    /// One handler for all our keys; it looks up which key fired by its id.
    private func installHandler() {
        guard !installed else { return }
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ in
                var id = EventHotKeyID()
                GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
                HotKeys.shared.handlers[id.id]?()
                return noErr
            }, 1, &spec, nil, nil)
    }

    /// `modifiers` (Carbon mask) + `keyCode`. Returns false when the key could not be taken.
    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) -> Bool {
        installHandler()
        let id = UInt32(handlers.count + 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode, modifiers,
            EventHotKeyID(signature: OSType(0x504E_4553), id: id),  // "PNES"
            GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        refs.append(ref)
        handlers[id] = action
        return true
    }

    /// Gives every key back, so the keys can be registered again from scratch.
    func unregisterAll() {
        for ref in refs { UnregisterEventHotKey(ref) }
        refs = []
        handlers = [:]
    }
}
