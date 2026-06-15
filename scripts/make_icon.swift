// Renders the AppTwin app icon (a "twin squares" motif) to a 1024×1024 PNG.
// Usage: swift scripts/make_icon.swift <output.png>
import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/apptwin-icon.png"
let S: CGFloat = 1024

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func roundedRect(_ r: NSRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius)
}

// macOS squircle background with a small margin.
let margin: CGFloat = 90
let bg = NSRect(x: margin, y: margin, width: S - margin * 2, height: S - margin * 2)
let bgPath = roundedRect(bg, 200)
bgPath.addClip()

let gradient = NSGradient(colors: [
    NSColor(srgbRed: 0.39, green: 0.40, blue: 0.95, alpha: 1),   // indigo
    NSColor(srgbRed: 0.26, green: 0.56, blue: 0.97, alpha: 1),   // blue
])!
gradient.draw(in: bg, angle: -45)

// Two overlapping rounded squares = a clone / twin.
let tile: CGFloat = 360
let tileRadius: CGFloat = 86
let cx = S / 2, cy = S / 2
let off: CGFloat = 70

// Back tile (translucent).
let back = NSRect(x: cx - tile / 2 - off, y: cy - tile / 2 + off, width: tile, height: tile)
NSColor(white: 1, alpha: 0.35).setFill()
roundedRect(back, tileRadius).fill()

// Front tile (solid) with a soft shadow.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 40,
              color: NSColor(white: 0, alpha: 0.28).cgColor)
let front = NSRect(x: cx - tile / 2 + off, y: cy - tile / 2 - off, width: tile, height: tile)
NSColor.white.setFill()
roundedRect(front, tileRadius).fill()
ctx.restoreGState()

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("icon render failed\n".utf8)); exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
