import Foundation
import AppKit

/// Composites a small corner badge onto an .icns so a clone is recognizable in
/// Finder, Launchpad and the Dock. Best-effort: on any failure the original
/// icon is left untouched.
enum IconBadger {
    /// Adds a badge to the .icns at `iconURL` in place. Returns true on success.
    @discardableResult
    static func badge(iconURL: URL, glyph: String = "2", tint: NSColor = .systemBlue) -> Bool {
        guard let base = NSImage(contentsOf: iconURL) else { return false }
        let size = NSSize(width: 1024, height: 1024)

        let composed = NSImage(size: size)
        composed.lockFocus()
        base.draw(in: NSRect(origin: .zero, size: size),
                  from: .zero, operation: .copy, fraction: 1.0)

        // Badge geometry: a filled circle in the lower-right quadrant.
        let d = size.width * 0.42
        let rect = NSRect(x: size.width - d - size.width * 0.04,
                          y: size.height * 0.04,
                          width: d, height: d)
        let circle = NSBezierPath(ovalIn: rect)
        NSColor.white.setFill(); NSBezierPath(ovalIn: rect.insetBy(dx: -d * 0.06, dy: -d * 0.06)).fill()
        tint.setFill(); circle.fill()

        let para = NSMutableParagraphStyle(); para.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: d * 0.6, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: para,
        ]
        let str = NSAttributedString(string: glyph, attributes: attrs)
        let textSize = str.size()
        str.draw(at: NSPoint(x: rect.midX - textSize.width / 2,
                             y: rect.midY - textSize.height / 2))
        composed.unlockFocus()

        return writeICNS(composed, to: iconURL)
    }

    private static func writeICNS(_ image: NSImage, to dest: URL) -> Bool {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("apptwin-\(UUID().uuidString).iconset")
        defer { try? fm.removeItem(at: tmp) }
        do {
            try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        } catch { return false }

        // Standard iconset sizes (pt) with @1x and @2x.
        let entries: [(name: String, px: Int)] = [
            ("icon_16x16", 16), ("icon_16x16@2x", 32),
            ("icon_32x32", 32), ("icon_32x32@2x", 64),
            ("icon_128x128", 128), ("icon_128x128@2x", 256),
            ("icon_256x256", 256), ("icon_256x256@2x", 512),
            ("icon_512x512", 512), ("icon_512x512@2x", 1024),
        ]
        for entry in entries {
            guard let png = pngData(from: image, pixels: entry.px) else { return false }
            do { try png.write(to: tmp.appendingPathComponent("\(entry.name).png")) }
            catch { return false }
        }
        let result = try? ShellRunner.run(
            "/usr/bin/iconutil", ["-c", "icns", tmp.path, "-o", dest.path], check: false)
        return result?.ok ?? false
    }

    private static func pngData(from image: NSImage, pixels: Int) -> Data? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        rep.size = NSSize(width: pixels, height: pixels)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
                   from: .zero, operation: .copy, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }
}
