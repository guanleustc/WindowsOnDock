import Foundation
import SwiftUI
import ServiceManagement

class Preferences: ObservableObject {
    static let shared = Preferences()

    private let enabledAppsKey = "enabledApps"
    private let launchAtLoginKey = "launchAtLogin"

    // All available apps with their bundle ID patterns
    static let availableApps: [String: [String]] = [
        "VSCode": ["vscode", "microsoft.code"],
        "Sublime Text": ["sublimetext", "sublime"],
        "Xcode": ["xcode"],
        "JetBrains": ["jetbrains", "intellij", "pycharm", "webstorm"],
        "iTerm": ["iterm"],
        "Terminal": ["apple.terminal"],
        "Word": ["microsoft.word"],
        "PowerPoint": ["microsoft.powerpoint"],
        "Excel": ["microsoft.excel"],
        "TextEdit": ["textedit"]
    ]

    // Default enabled apps
    static let defaultEnabledApps: Set<String> = [
        "VSCode", "Sublime Text", "Xcode", "JetBrains", "iTerm"
    ]

    @Published var enabledApps: Set<String> {
        didSet {
            saveEnabledApps()
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            setLaunchAtLogin(launchAtLogin)
        }
    }

    init() {
        if let savedApps = UserDefaults.standard.array(forKey: enabledAppsKey) as? [String] {
            enabledApps = Set(savedApps)
        } else {
            enabledApps = Self.defaultEnabledApps
        }

        // Check current login item status
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func saveEnabledApps() {
        UserDefaults.standard.set(Array(enabledApps), forKey: enabledAppsKey)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
        }
    }

    func isAppSupported(bundleId: String) -> Bool {
        let lowercased = bundleId.lowercased()
        for appName in enabledApps {
            if let patterns = Self.availableApps[appName] {
                for pattern in patterns {
                    if lowercased.contains(pattern.lowercased()) {
                        return true
                    }
                }
            }
        }
        return false
    }

    func isAppEnabled(_ appName: String) -> Bool {
        enabledApps.contains(appName)
    }

    func toggleApp(_ appName: String) {
        if enabledApps.contains(appName) {
            enabledApps.remove(appName)
        } else {
            enabledApps.insert(appName)
        }
    }

    func resetToDefaults() {
        enabledApps = Self.defaultEnabledApps
    }
}
