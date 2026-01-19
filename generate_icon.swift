#!/usr/bin/env swift

import Cocoa

func createIcon(size: Int) -> NSBitmapImageRep {
    let s = CGFloat(size)

    // Create bitmap with explicit pixel dimensions (no Retina scaling)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let rect = NSRect(x: 0, y: 0, width: s, height: s)
    let scale = s / 512.0

    // Background gradient (blue to purple)
    let gradient = NSGradient(colors: [
        NSColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1.0),
        NSColor(red: 0.5, green: 0.3, blue: 0.8, alpha: 1.0)
    ])!

    // Rounded rectangle background
    let cornerRadius = 100 * scale
    let bgPath = NSBezierPath(roundedRect: rect.insetBy(dx: 10 * scale, dy: 10 * scale), xRadius: cornerRadius, yRadius: cornerRadius)
    gradient.draw(in: bgPath, angle: -45)

    // Draw dock bar at bottom
    let dockHeight = 60 * scale
    let dockY = 50 * scale
    let dockRect = NSRect(x: 60 * scale, y: dockY, width: s - 120 * scale, height: dockHeight)
    let dockPath = NSBezierPath(roundedRect: dockRect, xRadius: 15 * scale, yRadius: 15 * scale)
    NSColor(white: 0.95, alpha: 0.9).setFill()
    dockPath.fill()

    // Draw window icons on dock
    let windowColors = [
        NSColor(red: 0.95, green: 0.3, blue: 0.3, alpha: 1.0),
        NSColor(red: 0.3, green: 0.7, blue: 0.95, alpha: 1.0),
        NSColor(red: 0.3, green: 0.85, blue: 0.4, alpha: 1.0),
        NSColor(red: 0.95, green: 0.7, blue: 0.2, alpha: 1.0),
    ]

    let iconSize = 40 * scale
    let iconSpacing = 20 * scale
    let totalWidth = 4 * iconSize + 3 * iconSpacing
    let startX = (s - totalWidth) / 2
    let iconY = dockY + (dockHeight - iconSize) / 2

    for i in 0..<4 {
        let iconX = startX + CGFloat(i) * (iconSize + iconSpacing)
        let iconRect = NSRect(x: iconX, y: iconY, width: iconSize, height: iconSize)
        let iconPath = NSBezierPath(roundedRect: iconRect, xRadius: 8 * scale, yRadius: 8 * scale)
        windowColors[i].setFill()
        iconPath.fill()

        let titleBarRect = NSRect(x: iconX, y: iconY + iconSize - 10 * scale, width: iconSize, height: 10 * scale)
        let titlePath = NSBezierPath(roundedRect: titleBarRect, xRadius: 8 * scale, yRadius: 8 * scale)
        NSColor(white: 1.0, alpha: 0.3).setFill()
        titlePath.fill()
    }

    // Draw floating windows above dock
    let windowWidth = 140 * scale
    let windowHeight = 100 * scale

    let win1Rect = NSRect(x: 80 * scale, y: 180 * scale, width: windowWidth, height: windowHeight)
    drawWindow(rect: win1Rect, color: NSColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0), scale: scale)

    let win2Rect = NSRect(x: 290 * scale, y: 200 * scale, width: windowWidth, height: windowHeight)
    drawWindow(rect: win2Rect, color: NSColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0), scale: scale)

    let win3Rect = NSRect(x: 170 * scale, y: 250 * scale, width: windowWidth + 30 * scale, height: windowHeight + 20 * scale)
    drawWindow(rect: win3Rect, color: NSColor.white, scale: scale, shadow: true)

    // Draw arrow pointing down to dock
    let arrowPath = NSBezierPath()
    let arrowCenterX = s / 2
    let arrowTopY = 180 * scale
    let arrowBottomY = 130 * scale
    let arrowWidth = 30 * scale

    arrowPath.move(to: NSPoint(x: arrowCenterX, y: arrowBottomY))
    arrowPath.line(to: NSPoint(x: arrowCenterX - arrowWidth, y: arrowTopY))
    arrowPath.line(to: NSPoint(x: arrowCenterX - arrowWidth/3, y: arrowTopY))
    arrowPath.line(to: NSPoint(x: arrowCenterX - arrowWidth/3, y: arrowTopY + 30 * scale))
    arrowPath.line(to: NSPoint(x: arrowCenterX + arrowWidth/3, y: arrowTopY + 30 * scale))
    arrowPath.line(to: NSPoint(x: arrowCenterX + arrowWidth/3, y: arrowTopY))
    arrowPath.line(to: NSPoint(x: arrowCenterX + arrowWidth, y: arrowTopY))
    arrowPath.close()

    NSColor.white.setFill()
    arrowPath.fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func drawWindow(rect: NSRect, color: NSColor, scale: CGFloat, shadow: Bool = false) {
    if shadow {
        let shadowRect = rect.offsetBy(dx: 3 * scale, dy: -3 * scale)
        let shadowPath = NSBezierPath(roundedRect: shadowRect, xRadius: 8 * scale, yRadius: 8 * scale)
        NSColor(white: 0.0, alpha: 0.2).setFill()
        shadowPath.fill()
    }

    let windowPath = NSBezierPath(roundedRect: rect, xRadius: 8 * scale, yRadius: 8 * scale)
    color.setFill()
    windowPath.fill()

    let titleBarHeight = 20 * scale
    let titleBarRect = NSRect(x: rect.minX, y: rect.maxY - titleBarHeight, width: rect.width, height: titleBarHeight)
    NSColor(white: 0.9, alpha: 1.0).setFill()
    let titlePath = NSBezierPath(roundedRect: titleBarRect, xRadius: 8 * scale, yRadius: 8 * scale)
    titlePath.fill()

    let buttonY = rect.maxY - titleBarHeight/2 - 4 * scale
    let buttonSize = 8 * scale
    let buttonSpacing = 12 * scale

    let redButton = NSBezierPath(ovalIn: NSRect(x: rect.minX + 10 * scale, y: buttonY, width: buttonSize, height: buttonSize))
    NSColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0).setFill()
    redButton.fill()

    let yellowButton = NSBezierPath(ovalIn: NSRect(x: rect.minX + 10 * scale + buttonSpacing, y: buttonY, width: buttonSize, height: buttonSize))
    NSColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 1.0).setFill()
    yellowButton.fill()

    let greenButton = NSBezierPath(ovalIn: NSRect(x: rect.minX + 10 * scale + 2 * buttonSpacing, y: buttonY, width: buttonSize, height: buttonSize))
    NSColor(red: 0.4, green: 0.85, blue: 0.4, alpha: 1.0).setFill()
    greenButton.fill()

    let lineY1 = rect.minY + rect.height * 0.5
    let lineY2 = rect.minY + rect.height * 0.35
    let lineY3 = rect.minY + rect.height * 0.2

    NSColor(white: 0.85, alpha: 1.0).setFill()
    NSBezierPath(rect: NSRect(x: rect.minX + 15 * scale, y: lineY1, width: rect.width * 0.7, height: 6 * scale)).fill()
    NSBezierPath(rect: NSRect(x: rect.minX + 15 * scale, y: lineY2, width: rect.width * 0.5, height: 6 * scale)).fill()
    NSBezierPath(rect: NSRect(x: rect.minX + 15 * scale, y: lineY3, width: rect.width * 0.6, height: 6 * scale)).fill()
}

func saveBitmap(_ bitmap: NSBitmapImageRep, to path: String) {
    if let pngData = bitmap.representation(using: .png, properties: [:]) {
        try? pngData.write(to: URL(fileURLWithPath: path))
    }
}

let outputDir = "/Users/leguan/Library/CloudStorage/Dropbox/coding/windowdock/WindowsOnDock/Assets.xcassets/AppIcon.appiconset"

// Required sizes: (base size, actual pixel size, filename)
let iconSpecs: [(Int, Int, String)] = [
    (16, 16, "icon_16x16.png"),
    (16, 32, "icon_16x16@2x.png"),
    (32, 32, "icon_32x32.png"),
    (32, 64, "icon_32x32@2x.png"),
    (128, 128, "icon_128x128.png"),
    (128, 256, "icon_128x128@2x.png"),
    (256, 256, "icon_256x256.png"),
    (256, 512, "icon_256x256@2x.png"),
    (512, 512, "icon_512x512.png"),
    (512, 1024, "icon_512x512@2x.png"),
]

for (_, pixels, filename) in iconSpecs {
    let bitmap = createIcon(size: pixels)
    let path = "\(outputDir)/\(filename)"
    saveBitmap(bitmap, to: path)
    print("Created \(filename) (\(pixels)x\(pixels))")
}

print("Icons created successfully!")
