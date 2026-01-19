# WindowDock Usage Guide

## Quick Start

1. **Build and Launch**
   - Open `WindowDock.xcodeproj` in Xcode
   - Press ⌘R to build and run
   - WindowDock will appear in your menu bar as a grid icon

2. **Grant Permissions**
   - When prompted, grant Accessibility permissions
   - Open System Settings > Privacy & Security > Accessibility
   - Enable WindowDock

3. **Open Your Editor Windows**
   - Open multiple projects or files in your text editor
   - For example, in VSCode, open 2-3 different project folders
   - Each project window will be detected separately

4. **Create Dock Icons**
   - Click the WindowDock menu bar icon
   - Select "Manage Window Helpers" (or press ⌘M)
   - Click "Refresh Windows" to scan
   - Select the windows you want as dock icons
   - Click "Create Helpers"
   - The new dock icons will appear

5. **Use Your New Dock Icons**
   - Click any helper dock icon to switch to that window
   - The window will come to front immediately

## Examples

### Example: Multiple VSCode Projects

If you have:
- Project A: `/Users/you/projects/website` (window title: "website — Visual Studio Code")
- Project B: `/Users/you/projects/backend` (window title: "backend — Visual Studio Code")
- Project C: `/Users/you/projects/mobile` (window title: "mobile — Visual Studio Code")

WindowDock will create three helper apps:
- `WD_website — Visual Studio Code.app`
- `WD_backend — Visual Studio Code.app`
- `WD_mobile — Visual Studio Code.app`

Each appears in your dock and switches directly to that project.

### Example: Xcode Projects

With multiple Xcode projects open:
- iOS app (window title: "MyApp — Xcode")
- macOS app (window title: "DesktopApp — Xcode")

Two helpers created:
- `WD_MyApp — Xcode.app`
- `WD_DesktopApp — Xcode.app`

## Tips

- **Refresh regularly**: Click "Refresh Windows" when you open new editor windows
- **Descriptive window titles**: Use project names that are easy to identify
- **Clean up**: Remove helpers for closed projects to keep dock tidy
- **Multiple selections**: Shift+Click or Cmd+Click to select multiple windows at once

## Troubleshooting

### "No editor windows found"
- Make sure you have opened windows in a supported editor (VSCode, Xcode, Sublime, JetBrains)
- Click "Refresh" to scan again
- Check that the editor application has multiple windows open

### Helper doesn't activate the right window
- Window titles may have changed (e.g., you renamed a project)
- Remove the old helper and create a new one with the updated title

### Permission denied errors
- Ensure Accessibility permissions are granted
- Try quitting and restarting WindowDock
- Check System Settings > Privacy & Security > Accessibility

### Helper appears in dock but doesn't work
- macOS may prompt you to allow the helper to control the editor
- Accept the permission prompt
- The helper should work after granting permission

## Advanced

### Customizing Which Apps Are Detected

Edit `WindowDock/WindowDockApp.swift` and `WindowDock/ContentView.swift` to add more bundle identifiers:

```swift
bundleId.contains("com.microsoft.VSCode") ||
bundleId.contains("com.yourapp.identifier")
```

### Helper App Location

Helpers are stored in:
```
~/Library/Application Support/WindowDock/Helpers/
```

### Manual Cleanup

If you need to manually remove helpers:
1. Drag helpers out of the dock
2. Delete from the Helpers folder above
3. Empty trash
