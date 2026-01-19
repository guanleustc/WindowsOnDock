import SwiftUI
import AppKit

class ManagementWindowController: NSWindowController, NSWindowDelegate {
    var contentView: ContentView?
    var onClose: (() -> Void)?

    override init(window: NSWindow?) {
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    convenience init() {
        let contentView = ContentView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "WindowsOnDock - Manage Window Helpers"
        window.center()
        window.contentView = NSHostingView(rootView: contentView)

        self.init(window: window)
        self.contentView = contentView
        window.delegate = self
    }

    func windowWillClose(_ notification: Notification) {
        contentView?.stopMonitoring()
        contentView = nil
        onClose?()
    }
}
