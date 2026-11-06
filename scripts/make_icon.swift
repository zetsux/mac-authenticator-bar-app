// Draws the app icon into an .iconset folder. Usage: swift make_icon.swift <output-dir>
import AppKit

let outDir = CommandLine.arguments[1]

func render(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(size)

    let plate = NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
    let path = NSBezierPath(roundedRect: plate, xRadius: s * 0.18, yRadius: s * 0.18)
    NSGradient(
        starting: NSColor(red: 0.25, green: 0.58, blue: 1.0, alpha: 1),
        ending: NSColor(red: 0.07, green: 0.24, blue: 0.70, alpha: 1)
    )!.draw(in: path, angle: -90)

    let config = NSImage.SymbolConfiguration(pointSize: s * 0.44, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor(red: 0.10, green: 0.32, blue: 0.85, alpha: 1), .white]))
    if let symbol = NSImage(systemSymbolName: "lock.shield.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let sz = symbol.size
        symbol.draw(in: NSRect(x: (s - sz.width) / 2, y: (s - sz.height) / 2, width: sz.width, height: sz.height))
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
let files: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, size) in files {
    try render(size: size).write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}
