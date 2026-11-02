import AppKit

// The app starts here. `.accessory` = no Dock icon, no main window; Panes lives in the menu bar.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
