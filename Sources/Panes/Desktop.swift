import AppKit

/// Show desktop, like Win + D: the first press hides every visible app,
/// the second press brings back exactly the apps it hid.
enum Desktop {
    private static var hiddenByUs: [NSRunningApplication] = []

    static func toggle() {
        let stillHidden = hiddenByUs.filter { !$0.isTerminated && $0.isHidden }
        if !stillHidden.isEmpty {
            for app in stillHidden { app.unhide() }
            hiddenByUs = []
            return
        }
        let me = Bundle.main.bundleIdentifier
        let visible = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isHidden && $0.bundleIdentifier != me
        }
        for app in visible { app.hide() }
        hiddenByUs = visible
    }
}
