import AppKit

// Top-level code isn't treated as main-actor isolated in Swift 5 mode, but it always runs on the main thread.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    // Menu bar only: no Dock icon, never steals focus from the app you're dragging from.
    app.setActivationPolicy(.accessory)
    // run() blocks for the app's lifetime, which keeps `delegate` (held weakly by app) alive.
    app.run()
}
