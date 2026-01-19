import SwiftUI

@main
struct WindowsOnDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var windowManager: WindowManager?
    var helperAppManager: HelperAppManager { HelperAppManager.shared }
    var managementWindowController: ManagementWindowController?
    var preferencesWindowController: PreferencesWindowController?
    private var hasPromptedForAccess = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleWindowActivationRequest(_:)),
            name: NSNotification.Name("com.windowsondock.activateWindow"),
            object: nil
        )

        let accessEnabled = AXIsProcessTrusted()

        if !accessEnabled {
            if !hasPromptedForAccess {
                hasPromptedForAccess = true
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                _ = AXIsProcessTrustedWithOptions(options)

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.showAccessibilityAlert()
                }
            }
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "WindowsOnDock")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Manage Window Helpers", action: #selector(openManagement), keyEquivalent: "m"))
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Refresh Windows", action: #selector(refreshWindows), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Clear All Helpers", action: #selector(clearAllHelpers), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About WindowsOnDock", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem?.menu = menu
        windowManager = WindowManager()
        startMonitoring()
    }

    func startMonitoring() {
        windowManager?.startMonitoring { _ in }
    }

    @objc func openManagement() {
        if managementWindowController == nil {
            managementWindowController = ManagementWindowController()
        }
        managementWindowController?.showWindow(nil)
        managementWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController()
        }
        preferencesWindowController?.showWindow(nil)
        preferencesWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func refreshWindows() {
        windowManager?.forceUpdate()
    }

    @objc func clearAllHelpers() {
        let alert = NSAlert()
        alert.messageText = "Clear All Helpers"
        alert.informativeText = "This will remove all WindowsOnDock helper icons from the dock. Are you sure?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            helperAppManager.removeAllHelpers()
        }
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "WindowsOnDock"
        alert.informativeText = "Creates separate dock icons for individual application windows.\n\nVersion 1.0"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func quit() {
        if helperAppManager.hasAnyHelpers {
            helperAppManager.removeAllHelpers()
            Thread.sleep(forTimeInterval: 1.0)
        }
        NSApplication.shared.terminate(nil)
    }

    func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "WindowsOnDock needs accessibility permissions to monitor windows. Please grant permission in System Settings > Privacy & Security > Accessibility."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        windowManager?.stopMonitoring()
        DistributedNotificationCenter.default().removeObserver(self)
        if helperAppManager.hasAnyHelpers {
            helperAppManager.removeAllHelpers()
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if helperAppManager.hasAnyHelpers {
            helperAppManager.removeAllHelpers()
            Thread.sleep(forTimeInterval: 1.5)
        }
        return .terminateNow
    }

    @objc func handleWindowActivationRequest(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let windowTitle = userInfo["windowTitle"] as? String,
              let bundleIdentifier = userInfo["bundleIdentifier"] as? String else {
            return
        }

        WindowManager.activateWindow(withTitle: windowTitle, bundleIdentifier: bundleIdentifier)
    }
}
