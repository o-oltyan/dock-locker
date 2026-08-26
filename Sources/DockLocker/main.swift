import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// .accessory covers running the bare binary during development; the bundle's
// LSUIElement covers the installed app.
app.setActivationPolicy(.accessory)
app.run()
