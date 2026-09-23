// make_sidebar_icon.swift <symbolName> <outIconsetDir>
// Writes a .iconset with icon_* (colored squircle app icon) and sidebar_* (black+alpha templates).
import AppKit
import Foundation

let args = CommandLine.arguments
let symbolName = args[1]
let outDir = args[2]
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func render(px: Int, symbol: String, fg: NSColor, bg: NSColor?, scale: CGFloat) -> Data? {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    if let bg = bg {
        let inset = s * 0.045
        let rect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.2237, yRadius: rect.width * 0.2237)
        bg.setFill(); path.fill()
    }
    let cfg = NSImage.SymbolConfiguration(pointSize: s * 0.5, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [fg]))
    if let sym = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
        let sz = sym.size
        let k = min(s * scale / max(sz.width, 1), s * scale / max(sz.height, 1))
        let w = sz.width * k, h = sz.height * k
        sym.draw(in: NSRect(x: (s - w) / 2, y: (s - h) / 2, width: w, height: h), from: .zero, operation: .sourceOver, fraction: 1)
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

func hex(_ v: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255, blue: CGFloat(v & 0xff) / 255, alpha: 1)
}
// edit the palette per project; Developer = ink/cream, Downloads = taupe/ink
let isDev = symbolName.contains("forwardslash")
let appBg = isDev ? hex(0x2B2118) : hex(0x9A8C79)
let appFg = isDev ? hex(0xF5EFE6) : hex(0x2B2118)

let appSizes: [(String, Int)] = [("icon_16x16.png", 16), ("icon_16x16@2x.png", 32), ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64), ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256), ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512), ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)]
for (n, px) in appSizes { try! render(px: px, symbol: symbolName, fg: appFg, bg: appBg, scale: 0.60)!.write(to: URL(fileURLWithPath: outDir + "/" + n)) }
let sideSizes: [(String, Int)] = [("sidebar_16x16.png", 16), ("sidebar_16x16@2x.png", 32), ("sidebar_18x18.png", 32), ("sidebar_18x18@2x.png", 64), ("sidebar_32x32.png", 128), ("sidebar_32x32@2x.png", 256)]
for (n, px) in sideSizes { try! render(px: px, symbol: symbolName, fg: .black, bg: nil, scale: 0.92)!.write(to: URL(fileURLWithPath: outDir + "/" + n)) }
