import AppKit

// Manual entry point so the executable target produces a proper app process
// without requiring a full Xcode project. The menu bar UI is owned by
// `AppDelegate`.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// LSUIElement-equivalent: we do not want a Dock icon.
app.setActivationPolicy(.accessory)
app.run()
