// Generates Resources/AppIcon.icns. Run: swift scripts/make-icon.swift
// Draws at each size from vectors so every variant is crisp.
import AppKit

func drawIcon(canvas: CGFloat) -> NSImage {
    let s = canvas / 1024.0
    let image = NSImage(size: NSSize(width: canvas, height: canvas))
    image.lockFocus()

    // Background squircle on the macOS icon grid (~100px margin at 1024).
    let bg = NSBezierPath(
        roundedRect: NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s),
        xRadius: 185 * s, yRadius: 185 * s)
    NSGradient(
        colors: [
            NSColor(calibratedRed: 0.28, green: 0.56, blue: 0.98, alpha: 1),
            NSColor(calibratedRed: 0.08, green: 0.22, blue: 0.62, alpha: 1),
        ])!.draw(in: bg, angle: -90)

    // Mini dock bar near the bottom.
    let dock = NSBezierPath(
        roundedRect: NSRect(x: 210 * s, y: 190 * s, width: 604 * s, height: 118 * s),
        xRadius: 36 * s, yRadius: 36 * s)
    NSColor.white.withAlphaComponent(0.92).setFill()
    dock.fill()

    // Three app tiles on the dock.
    let tileColors = [
        NSColor(calibratedRed: 0.98, green: 0.42, blue: 0.36, alpha: 1),
        NSColor(calibratedRed: 0.99, green: 0.75, blue: 0.28, alpha: 1),
        NSColor(calibratedRed: 0.33, green: 0.80, blue: 0.46, alpha: 1),
    ]
    for (index, color) in tileColors.enumerated() {
        let tile = NSBezierPath(
            roundedRect: NSRect(
                x: (258 + CGFloat(index) * 180) * s, y: 215 * s,
                width: 148 * s, height: 68 * s),
            xRadius: 18 * s, yRadius: 18 * s)
        color.setFill()
        tile.fill()
    }

    // Padlock above the dock: shackle + body.
    NSColor.white.setStroke()
    let shackle = NSBezierPath()
    shackle.lineWidth = 58 * s
    shackle.appendArc(
        withCenter: NSPoint(x: 512 * s, y: 640 * s), radius: 118 * s,
        startAngle: 0, endAngle: 180)
    shackle.stroke()

    let body = NSBezierPath(
        roundedRect: NSRect(x: 330 * s, y: 400 * s, width: 364 * s, height: 260 * s),
        xRadius: 48 * s, yRadius: 48 * s)
    NSColor.white.setFill()
    body.fill()

    // Keyhole.
    let hole = NSBezierPath(
        ovalIn: NSRect(x: 478 * s, y: 505 * s, width: 68 * s, height: 68 * s))
    hole.appendRect(NSRect(x: 496 * s, y: 448 * s, width: 32 * s, height: 70 * s))
    NSColor(calibratedRed: 0.08, green: 0.22, blue: 0.62, alpha: 1).setFill()
    hole.fill()

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL, pixels: Int) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

let iconsetURL = URL(fileURLWithPath: "Resources/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconsetURL)
try! FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = base * scale
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        writePNG(drawIcon(canvas: CGFloat(pixels)), to: iconsetURL.appendingPathComponent(name), pixels: pixels)
    }
}
print("iconset written")
