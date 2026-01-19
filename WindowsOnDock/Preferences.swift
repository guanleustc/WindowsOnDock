import Foundation
import SwiftUI

class Preferences: ObservableObject {
    static let shared = Preferences()

    private let enabledAppsKey = "enabledApps"

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
            save()
        }
    }

    init() {
        if let savedApps = UserDefaults.standard.array(forKey: enabledAppsKey) as? [String] {
            enabledApps = Set(savedApps)
        } else {
            enabledApps = Self.defaultEnabledApps
        }
    }

    private func save() {
        UserDefaults.standard.set(Array(enabledApps), forKey: enabledAppsKey)
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
