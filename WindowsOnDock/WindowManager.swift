import Cocoa
import ApplicationServices

struct WindowInfo: Hashable {
    let windowNumber: Int
    let appPID: pid_t
    let appName: String
    let windowTitle: String
    let appBundleIdentifier: String?
    let windowIndex: Int

    func hash(into hasher: inout Hasher) {
        hasher.combine(windowNumber)
        hasher.combine(appPID)
    }

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        return lhs.windowNumber == rhs.windowNumber && lhs.appPID == rhs.appPID
    }
}

class WindowManager: ObservableObject {
    private var timer: Timer?
    private var previousWindows: Set<WindowInfo> = []
    private var updateCallback: (([WindowInfo]) -> Void)?

    func startMonitoring(updateCallback: @escaping ([WindowInfo]) -> Void) {
        self.updateCallback = updateCallback
        updateWindows()

        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateWindows()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func forceUpdate() {
        updateWindows()
    }

    private func updateWindows() {
        let currentWindows = getAllWindows()

        if currentWindows != previousWindows {
            previousWindows = currentWindows
            updateCallback?(Array(currentWindows))
        }
    }

    private func getAllWindows() -> Set<WindowInfo> {
        var windowInfos: Set<WindowInfo> = []

        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return windowInfos
        }

        let runningApps = NSWorkspace.shared.runningApplications

        var windowTitleCache: [pid_t: [String]] = [:]
        for pid in Set(windowList.compactMap { $0[kCGWindowOwnerPID as String] as? pid_t }) {
            windowTitleCache[pid] = getWindowTitles(forPID: pid)
        }

        var appWindowIndex: [pid_t: Int] = [:]

        for window in windowList {
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t,
                  let windowNumber = window[kCGWindowNumber as String] as? Int,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0 else {
                continue
            }

            guard let app = runningApps.first(where: { $0.processIdentifier == pid }),
                  let appName = app.localizedName else {
                continue
            }

            var windowTitle = (window[kCGWindowName as String] as? String) ?? ""

            if windowTitle.isEmpty, let titles = windowTitleCache[pid], !titles.isEmpty {
                if let axTitle = titles.first, !axTitle.isEmpty {
                    windowTitle = axTitle
                    var updatedTitles = titles
                    updatedTitles.removeFirst()
                    windowTitleCache[pid] = updatedTitles
                }
            }

            if windowTitle.isEmpty {
                windowTitle = "[No Title]"
            }

            if windowTitle == "Untitled" {
                windowTitle = "Untitled-\(windowNumber)"
            }

            let currentIndex = appWindowIndex[pid, default: 0] + 1
            appWindowIndex[pid] = currentIndex

            let windowInfo = WindowInfo(
                windowNumber: windowNumber,
                appPID: pid,
                appName: appName,
                windowTitle: windowTitle.isEmpty ? "\(appName) - Window \(currentIndex)" : windowTitle,
                appBundleIdentifier: app.bundleIdentifier,
                windowIndex: currentIndex
            )

            windowInfos.insert(windowInfo)
        }

        return windowInfos
    }

    private func getWindowTitles(forPID pid: pid_t) -> [String] {
        var titles: [String] = []

        let appRef = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef)

        if result == .success, let windows = windowsRef as? [AXUIElement] {
            for window in windows {
                var titleRef: CFTypeRef?
                let titleResult = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)

                if titleResult == .success, let windowTitle = titleRef as? String {
                    titles.append(windowTitle)
                }
            }
        } else {
            titles = getWindowTitlesViaAppleScript(forPID: pid)
        }

        return titles
    }

    private func getWindowTitlesViaAppleScript(forPID pid: pid_t) -> [String] {
        var titles: [String] = []

        let runningApps = NSWorkspace.shared.runningApplications
        guard let app = runningApps.first(where: { $0.processIdentifier == pid }),
              let bundleId = app.bundleIdentifier else {
            return titles
        }

        let script = """
        tell application "System Events"
            tell process (get name of first application process whose bundle identifier is "\(bundleId)")
                get name of every window
            end tell
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let output = scriptObject.executeAndReturnError(&error)
            if error == nil, let windowList = output.coerce(toDescriptorType: typeAEList) {
                for i in 1...windowList.numberOfItems {
                    if let item = windowList.atIndex(i), let windowTitle = item.stringValue {
                        titles.append(windowTitle)
                    }
                }
            }
        }

        return titles
    }

    static func activateWindow(withTitle title: String, bundleIdentifier: String) {
        let runningApps = NSWorkspace.shared.runningApplications
        guard let app = runningApps.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            return
        }

        let pid = app.processIdentifier
        app.activate(options: [.activateIgnoringOtherApps])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let appRef = AXUIElementCreateApplication(pid)

            var windowsRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef)

            if result == .success, let windows = windowsRef as? [AXUIElement] {
                var foundWindow: AXUIElement? = nil

                // Try exact match first
                for window in windows {
                    var titleRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)

                    if let windowTitle = titleRef as? String, windowTitle == title {
                        foundWindow = window
                        break
                    }
                }

                // Try partial match if exact match failed
                if foundWindow == nil {
                    let titleParts = title.components(separatedBy: " — ")
                    var searchKey = title
                    if titleParts.count >= 2 {
                        var projectPart = titleParts[1]
                        if let parenRange = projectPart.range(of: " (") {
                            projectPart = String(projectPart[..<parenRange.lowerBound])
                        }
                        searchKey = projectPart.trimmingCharacters(in: .whitespaces)
                    }

                    for window in windows {
                        var titleRef: CFTypeRef?
                        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)

                        if let windowTitle = titleRef as? String, windowTitle.contains(searchKey) {
                            foundWindow = window
                            break
                        }
                    }
                }

                if let window = foundWindow {
                    AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                    AXUIElementSetAttributeValue(appRef, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
                }
            }
        }
    }
}
