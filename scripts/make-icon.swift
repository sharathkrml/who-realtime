#!/usr/bin/env swift
// Draws the Who Realtime app icon (dark slate squircle, white waveform bars,
// red center bar) and writes build/WhoRealtime.icns. No assets, no deps —
// AppKit only. Run by make-app.sh.
import AppKit

func drawCore(_ side: CGFloat) {
    let inset = side * 0.10
    let content = side - inset * 2
    let rect = NSRect(x: inset, y: inset, width: content, height: content)
    let radius = content * 0.225

    // Squircle background.
    let background = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.16, green: 0.17, blue: 0.19, alpha: 1),
        NSColor(srgbRed: 0.05, green: 0.05, blue: 0.06, alpha: 1),
    ])
    gradient?.draw(in: background, angle: -90)

    // Waveform: five capsule bars, the center one red.
    let heights: [CGFloat] = [0.32, 0.60, 0.96, 0.60, 0.32]
    let barWidth = content * 0.086
    let gap = content * 0.052
    let totalWidth = barWidth * 5 + gap * 4
    var x = rect.midX - totalWidth / 2
    for (index, height) in heights.enumerated() {
        let barHeight = content * height
        let bar = NSRect(x: x, y: rect.midY - barHeight / 2, width: barWidth, height: barHeight)
        let path = NSBezierPath(roundedRect: bar, xRadius: barWidth / 2, yRadius: barWidth / 2)
        (index == 2 ? NSColor(srgbRed: 1.0, green: 0.30, blue: 0.25, alpha: 1) : NSColor.white).setFill()
        path.fill()
        x += barWidth + gap
    }
}

let setDir = "build/WhoRealtime.iconset"
try? FileManager.default.createDirectory(atPath: setDir, withIntermediateDirectories: true)
let sizes = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]
for (pixels, name) in sizes {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawCore(CGFloat(pixels))
    NSGraphicsContext.restoreGraphicsState()
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: "\(setDir)/\(name)"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", setDir, "-o", "build/WhoRealtime.icns"]
try! iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(atPath: setDir)
print("build/WhoRealtime.icns")
