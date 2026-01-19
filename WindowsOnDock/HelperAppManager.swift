import Foundation
import Cocoa

class HelperAppManager: ObservableObject {
    static let shared = HelperAppManager()

    private let helpersDirectory: URL
    @Published private var helperApps: Set<String> = []

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        helpersDirectory = appSupport.appendingPathComponent("WindowsOnDock/Helpers")

        try? FileManager.default.createDirectory(at: helpersDirectory, withIntermediateDirectories: true, attributes: [
            .posixPermissions: 0o755
        ])

        loadExistingHelpers()
    }

    private func loadExistingHelpers() {
        helperApps.removeAll()
        guard let contents = try? FileManager.default.contentsOfDirectory(at: helpersDirectory, includingPropertiesForKeys: nil) else {
            return
        }

        for url in contents where url.pathExtension == "app" {
            helperApps.insert(url.lastPathComponent)
        }
    }

    func reloadHelpers() {
        loadExistingHelpers()
        objectWillChange.send()
    }

    var hasAnyHelpers: Bool {
        return !helperApps.isEmpty
    }

    func hasHelper(for window: WindowInfo) -> Bool {
        let helperName = sanitizedHelperName(for: window)
        return helperApps.contains(helperName + ".app")
    }

    func createHelper(for window: WindowInfo) throws {
        guard let bundleId = window.appBundleIdentifier else {
            throw HelperError.missingBundleIdentifier
        }

        let helperName = sanitizedHelperName(for: window)
        let helperURL = helpersDirectory.appendingPathComponent(helperName + ".app")

        let contentsURL = helperURL.appendingPathComponent("Contents")
        let macOSURL = contentsURL.appendingPathComponent("MacOS")
        let resourcesURL = contentsURL.appendingPathComponent("Resources")

        try FileManager.default.createDirectory(at: macOSURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)

        let infoPlist = createInfoPlist(helperName: helperName, windowTitle: window.windowTitle)
        let infoPlistURL = contentsURL.appendingPathComponent("Info.plist")
        try infoPlist.write(to: infoPlistURL)

        let script = createLauncherScript(windowTitle: window.windowTitle, bundleIdentifier: bundleId, windowNumber: window.windowNumber)
        let executableURL = macOSURL.appendingPathComponent(helperName)
        try script.write(to: executableURL, atomically: true, encoding: .utf8)

        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)

        // Copy app icon
        if let iconURL = findAppIcon(bundleIdentifier: bundleId) {
            let destIconURL = resourcesURL.appendingPathComponent("AppIcon.icns")
            try? FileManager.default.copyItem(at: iconURL, to: destIconURL)
        }

        helperApps.insert(helperName + ".app")
        addToDock(helperURL)
    }

    func removeHelper(for window: WindowInfo) {
        let helperName = sanitizedHelperName(for: window)
        let helperFileName = helperName + ".app"
        let helperURL = helpersDirectory.appendingPathComponent(helperFileName)

        removeFromDock(helperURL)
        try? FileManager.default.removeItem(at: helperURL)
        helperApps.remove(helperFileName)
    }

    func removeAllHelpers() {
        cleanupDockIcons()

        guard let contents = try? FileManager.default.contentsOfDirectory(at: helpersDirectory, includingPropertiesForKeys: nil) else {
            restartDock()
            return
        }

        for url in contents where url.pathExtension == "app" {
            try? FileManager.default.removeItem(at: url)
        }

        helperApps.removeAll()
        restartDock()
    }

    private func findAppIcon(bundleIdentifier: String) -> URL? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
              let bundle = Bundle(url: appURL),
              let resourcesURL = bundle.resourceURL else {
            return nil
        }

        // Try CFBundleIconFile first
        if let iconName = bundle.infoDictionary?["CFBundleIconFile"] as? String {
            // Try with .icns extension
            var iconURL = resourcesURL.appendingPathComponent(iconName)
            if FileManager.default.fileExists(atPath: iconURL.path) {
                return iconURL
            }
            // Try adding .icns if not present
            if !iconName.hasSuffix(".icns") {
                iconURL = resourcesURL.appendingPathComponent(iconName + ".icns")
                if FileManager.default.fileExists(atPath: iconURL.path) {
                    return iconURL
                }
            }
        }

        // Try CFBundleIconName (used by some apps)
        if let iconName = bundle.infoDictionary?["CFBundleIconName"] as? String {
            let iconURL = resourcesURL.appendingPathComponent(iconName + ".icns")
            if FileManager.default.fileExists(atPath: iconURL.path) {
                return iconURL
            }
        }

        // Fallback: look for AppIcon.icns or any .icns file
        let fallbackNames = ["AppIcon.icns", "app.icns", "icon.icns"]
        for name in fallbackNames {
            let iconURL = resourcesURL.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: iconURL.path) {
                return iconURL
            }
        }

        // Last resort: find any .icns file in Resources
        if let contents = try? FileManager.default.contentsOfDirectory(at: resourcesURL, includingPropertiesForKeys: nil) {
            for url in contents where url.pathExtension == "icns" {
                return url
            }
        }

        return nil
    }

    private func sanitizedHelperName(for window: WindowInfo) -> String {
        var sanitized = window.windowTitle
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .prefix(50)

        if window.windowTitle == "Untitled" || window.windowTitle.isEmpty || window.windowTitle == "[No Title]" {
            sanitized = Substring("Window_\(window.windowNumber)")
        }

        return "WD_\(sanitized)"
    }

    private func createInfoPlist(helperName: String, windowTitle: String) -> Data {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleExecutable</key>
            <string>\(helperName)</string>
            <key>CFBundleIdentifier</key>
            <string>com.windowsondock.helper.\(helperName)</string>
            <key>CFBundleName</key>
            <string>\(windowTitle)</string>
            <key>CFBundleDisplayName</key>
            <string>\(windowTitle)</string>
            <key>CFBundlePackageType</key>
            <string>APPL</string>
            <key>CFBundleShortVersionString</key>
            <string>1.0</string>
            <key>CFBundleVersion</key>
            <string>1</string>
            <key>CFBundleIconFile</key>
            <string>AppIcon</string>
            <key>LSUIElement</key>
            <false/>
            <key>NSHighResolutionCapable</key>
            <true/>
        </dict>
        </plist>
        """
        return plist.data(using: .utf8)!
    }

    private func createLauncherScript(windowTitle: String, bundleIdentifier: String, windowNumber: Int) -> String {
        let escapedTitle = windowTitle
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let escapedBundleId = bundleIdentifier
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        return """
        #!/bin/bash
        osascript -l JavaScript <<'JSSCRIPT'
        ObjC.import('Foundation');
        var center = $.NSDistributedNotificationCenter.defaultCenter;
        var userInfo = $.NSMutableDictionary.alloc.init;
        userInfo.setObjectForKey($("\(escapedTitle)"), $("windowTitle"));
        userInfo.setObjectForKey($("\(escapedBundleId)"), $("bundleIdentifier"));
        userInfo.setObjectForKey($(\(windowNumber)), $("windowNumber"));
        center.postNotificationNameObjectUserInfoDeliverImmediately(
            $("com.windowsondock.activateWindow"),
            $(),
            userInfo,
            true
        );
        JSSCRIPT
        exit 0
        """
    }

    private func addToDock(_ appURL: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = [
            "write",
            "com.apple.dock",
            "persistent-apps",
            "-array-add",
            "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>\(appURL.path)</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
        ]
        try? process.run()
        process.waitUntilExit()
    }

    func restartDock() {
        let syncProcess = Process()
        syncProcess.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        syncProcess.arguments = ["-u", NSUserName(), "cfprefsd"]
        try? syncProcess.run()
        syncProcess.waitUntilExit()

        Thread.sleep(forTimeInterval: 0.3)

        let killDock = Process()
        killDock.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killDock.arguments = ["Dock"]
        try? killDock.run()
        killDock.waitUntilExit()
    }

    private func removeFromDock(_ appURL: URL) {
        removeFromDockByPath(appURL.lastPathComponent)
    }

    private func removeFromDockByPath(_ appName: String) {
        let dockPlistPath = NSHomeDirectory() + "/Library/Preferences/com.apple.dock.plist"

        let syncProcess = Process()
        syncProcess.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        syncProcess.arguments = ["-u", NSUserName(), "cfprefsd"]
        try? syncProcess.run()
        syncProcess.waitUntilExit()
        Thread.sleep(forTimeInterval: 0.2)

        guard let plistData = FileManager.default.contents(atPath: dockPlistPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let persistentApps = plist["persistent-apps"] as? [[String: Any]] else {
            return
        }

        var indicesToDelete: [Int] = []
        for (index, item) in persistentApps.enumerated() {
            if let tileData = item["tile-data"] as? [String: Any],
               let fileData = tileData["file-data"] as? [String: Any],
               let urlString = fileData["_CFURLString"] as? String {
                let decodedUrlString = urlString.removingPercentEncoding ?? urlString
                if (urlString.contains(appName) || decodedUrlString.contains(appName)) &&
                   (urlString.contains("WindowsOnDock/Helpers/") || urlString.contains("WindowsOnDock%2FHelpers%2F")) {
                    indicesToDelete.append(index)
                }
            }
        }

        for index in indicesToDelete.reversed() {
            let deleteProcess = Process()
            deleteProcess.executableURL = URL(fileURLWithPath: "/usr/libexec/PlistBuddy")
            deleteProcess.arguments = ["-c", "Delete :persistent-apps:\(index)", dockPlistPath]
            deleteProcess.standardError = FileHandle.nullDevice
            try? deleteProcess.run()
            deleteProcess.waitUntilExit()
        }
    }

    private func cleanupDockIcons() {
        let dockPlistPath = NSHomeDirectory() + "/Library/Preferences/com.apple.dock.plist"

        let syncProcess = Process()
        syncProcess.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        syncProcess.arguments = ["-u", NSUserName(), "cfprefsd"]
        try? syncProcess.run()
        syncProcess.waitUntilExit()
        Thread.sleep(forTimeInterval: 0.3)

        guard let plistData = FileManager.default.contents(atPath: dockPlistPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let persistentApps = plist["persistent-apps"] as? [[String: Any]] else {
            return
        }

        var indicesToDelete: [Int] = []
        for (index, item) in persistentApps.enumerated() {
            if let tileData = item["tile-data"] as? [String: Any],
               let fileData = tileData["file-data"] as? [String: Any],
               let urlString = fileData["_CFURLString"] as? String {
                if urlString.contains("WindowsOnDock/Helpers/WD_") || urlString.contains("WindowsOnDock%2FHelpers%2FWD_") {
                    indicesToDelete.append(index)
                }
            }
        }

        for index in indicesToDelete.reversed() {
            let deleteProcess = Process()
            deleteProcess.executableURL = URL(fileURLWithPath: "/usr/libexec/PlistBuddy")
            deleteProcess.arguments = ["-c", "Delete :persistent-apps:\(index)", dockPlistPath]
            deleteProcess.standardError = FileHandle.nullDevice
            try? deleteProcess.run()
            deleteProcess.waitUntilExit()
        }
    }
}

enum HelperError: Error {
    case missingBundleIdentifier
}
