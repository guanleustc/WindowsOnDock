import SwiftUI

struct ContentView: View {
    @StateObject private var windowManager = WindowManager()
    @ObservedObject private var helperManager = HelperAppManager.shared
    @ObservedObject private var preferences = Preferences.shared
    @State private var editorWindows: [WindowInfo] = []
    @State private var selectedWindows: Set<String> = []

    // Group windows by app name
    var windowsByApp: [(appName: String, windows: [WindowInfo])] {
        let grouped = Dictionary(grouping: editorWindows) { $0.appName }
        return grouped.sorted { $0.key < $1.key }.map { (appName: $0.key, windows: $0.value) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)

                VStack(alignment: .leading) {
                    Text("WindowsOnDock")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Create dock icons for individual windows")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: refreshWindows) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            // Window list
            if editorWindows.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No editor windows found")
                        .font(.headline)

                    Text("Open windows in supported apps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Refresh") {
                        refreshWindows()
                    }
                    .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(windowsByApp, id: \.appName) { group in
                            AppGroupSection(
                                appName: group.appName,
                                windows: group.windows,
                                selectedWindows: $selectedWindows,
                                helperManager: helperManager
                            )
                        }
                    }
                    .padding()
                }
            }

            Divider()

            // Actions
            HStack {
                Text("\(selectedWindows.count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    refreshState()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh helper state")

                Button("Clear All Helpers") {
                    clearAllHelpers()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button("Add to Dock") {
                    createHelpersForSelected()
                }
                .disabled(selectedWindows.isEmpty)

                Button("Remove from Dock") {
                    removeHelpersForSelected()
                }
                .disabled(selectedWindows.isEmpty)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .onAppear {
            startMonitoring()
        }
        .background(
            Button("") {
                selectAllWindows()
            }
            .keyboardShortcut("a", modifiers: .command)
            .hidden()
        )
    }

    func selectAllWindows() {
        for window in editorWindows {
            selectedWindows.insert(window.windowKey)
        }
    }

    func startMonitoring() {
        windowManager.startMonitoring { windows in
            DispatchQueue.main.async {
                self.editorWindows = windows.filter { window in
                    guard let bundleId = window.appBundleIdentifier else { return false }
                    return Preferences.shared.isAppSupported(bundleId: bundleId)
                }
            }
        }
    }

    func refreshWindows() {
        windowManager.forceUpdate()
    }

    func refreshState() {
        // Reload helper state from disk and refresh window list
        helperManager.reloadHelpers()
        windowManager.forceUpdate()
    }

    func toggleSelection(for window: WindowInfo) {
        if selectedWindows.contains(window.windowKey) {
            selectedWindows.remove(window.windowKey)
        } else {
            selectedWindows.insert(window.windowKey)
        }
    }

    func createHelpersForSelected() {
        for windowKey in selectedWindows {
            if let window = editorWindows.first(where: { $0.windowKey == windowKey }) {
                if !helperManager.hasHelper(for: window) {
                    do {
                        try helperManager.createHelper(for: window)
                    } catch {
                        showError("Failed to create helper: \(error.localizedDescription)")
                    }
                }
            }
        }

        // Restart Dock once after all helpers are created
        helperManager.restartDock()
        selectedWindows.removeAll()

        // Force UI refresh
        helperManager.objectWillChange.send()
    }

    func removeHelpersForSelected() {
        for windowKey in selectedWindows {
            if let window = editorWindows.first(where: { $0.windowKey == windowKey }) {
                if helperManager.hasHelper(for: window) {
                    helperManager.removeHelper(for: window)
                }
            }
        }

        // Restart Dock once after all helpers are removed
        helperManager.restartDock()
        selectedWindows.removeAll()

        // Force UI refresh
        helperManager.objectWillChange.send()
    }

    func clearAllHelpers() {
        // Show confirmation alert
        let alert = NSAlert()
        alert.messageText = "Clear All Helpers"
        alert.informativeText = "This will remove all WindowsOnDock helper icons from the dock. Are you sure?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            helperManager.removeAllHelpers()
        }
    }

    func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

struct AppGroupSection: View {
    let appName: String
    let windows: [WindowInfo]
    @Binding var selectedWindows: Set<String>
    @ObservedObject var helperManager: HelperAppManager

    var allSelected: Bool {
        windows.allSatisfy { selectedWindows.contains($0.windowKey) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // App header with select all toggle
            HStack {
                Text(appName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("(\(windows.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(allSelected ? "Deselect All" : "Select All") {
                    if allSelected {
                        for window in windows {
                            selectedWindows.remove(window.windowKey)
                        }
                    } else {
                        for window in windows {
                            selectedWindows.insert(window.windowKey)
                        }
                    }
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 4)

            // Windows in this app
            VStack(spacing: 6) {
                ForEach(windows, id: \.windowKey) { window in
                    WindowRowCheckbox(
                        window: window,
                        hasHelper: helperManager.hasHelper(for: window),
                        isSelected: selectedWindows.contains(window.windowKey),
                        onToggleSelection: {
                            if selectedWindows.contains(window.windowKey) {
                                selectedWindows.remove(window.windowKey)
                            } else {
                                selectedWindows.insert(window.windowKey)
                            }
                        }
                    )
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(10)
    }
}

struct WindowRowCheckbox: View {
    let window: WindowInfo
    let hasHelper: Bool
    let isSelected: Bool
    let onToggleSelection: () -> Void

    var body: some View {
        Button(action: onToggleSelection) {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .blue : .secondary)

                // Window title only (app name shown in section header)
                Text(window.windowTitle)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                // Status badge
                if hasHelper {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("In Dock")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .cornerRadius(12)
                } else {
                    Text("Not in Dock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            .padding(10)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

extension WindowInfo {
    var windowKey: String {
        return "\(appPID)_\(windowNumber)"
    }
}

#Preview {
    ContentView()
}
