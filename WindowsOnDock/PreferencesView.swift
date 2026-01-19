import SwiftUI

struct PreferencesView: View {
    @ObservedObject var preferences = Preferences.shared

    var sortedApps: [String] {
        Preferences.availableApps.keys.sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Launch at Login toggle
            HStack {
                Toggle(isOn: $preferences.launchAtLogin) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at Login")
                            .font(.body)
                            .fontWeight(.medium)
                        Text("Start WindowsOnDock when you log in")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }
            .padding()

            Divider()

            // Header
            HStack {
                Text("Supported Applications")
                    .font(.headline)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 4)

            // App list with checkboxes
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(sortedApps, id: \.self) { appName in
                        AppToggleRow(
                            appName: appName,
                            patterns: Preferences.availableApps[appName] ?? [],
                            isEnabled: preferences.isAppEnabled(appName),
                            onToggle: {
                                preferences.toggleApp(appName)
                            }
                        )
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Button("Reset to Defaults") {
                    preferences.resetToDefaults()
                }

                Spacer()

                Text("\(preferences.enabledApps.count) of \(Preferences.availableApps.count) enabled")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .frame(width: 400, height: 450)
    }
}

struct AppToggleRow: View {
    let appName: String
    let patterns: [String]
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isEnabled ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundColor(isEnabled ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(appName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(patterns.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

class PreferencesWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 450),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferences"
        window.center()
        window.contentView = NSHostingView(rootView: PreferencesView())

        self.init(window: window)
    }
}

#Preview {
    PreferencesView()
}
