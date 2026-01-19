import SwiftUI
import AppKit

class ManagementWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "WindowsOnDock - Manage Window Helpers"
        window.center()
        window.contentView = NSHostingView(rootView: ContentView())

        self.init(window: window)
    }
}
