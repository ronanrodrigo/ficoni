// mknative.swift — sidebar-style glyph icons
// usage: mknative iconset <symbol> <hex> <outDir>      -> .iconset of blue outline glyphs (app-icon route)
//        mknative preview <hex> <out.png> <symbol>...  -> contact sheet to pick a symbol
import AppKit
import Foundation

func hex(_ h: String) -> NSColor {
    var s = h; if s.hasPrefix("#") { s.removeFirst() }
    let v = UInt32(s, radix: 16) ?? 0
    return NSColor(srgbRed: CGFloat((v >> 16) & 0xff)/255, green: CGFloat((v >> 8) & 0xff)/255, blue: CGFloat(v & 0xff)/255, alpha: 1)
}

func render(px: Int, symbol: String, fg: NSColor, scale: CGFloat, weight: NSFont.Weight) -> NSBitmapImageRep? {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let cfg = NSImage.SymbolConfiguration(pointSize: s * 0.7, weight: weight)
        .applying(NSImage.SymbolConfiguration(paletteColors: [fg]))
    if let sym = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
        let sz = sym.size
        let k = min(s * scale / max(sz.width, 1), s * scale / max(sz.height, 1))
        let w = sz.width * k, h = sz.height * k
        sym.draw(in: NSRect(x: (s - w)/2, y: (s - h)/2, width: w, height: h), from: .zero, operation: .sourceOver, fraction: 1)
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let a = CommandLine.arguments
if a[1] == "iconset" {
    let symbol = a[2], color = hex(a[3]), outDir = a[4]
    try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
    let sizes: [(String, Int)] = [("icon_16x16.png",16),("icon_16x16@2x.png",32),("icon_32x32.png",32),("icon_32x32@2x.png",64),("icon_128x128.png",128),("icon_128x128@2x.png",256),("icon_256x256.png",256),("icon_256x256@2x.png",512),("icon_512x512.png",512),("icon_512x512@2x.png",1024)]
    for (n, px) in sizes {
        guard let r = render(px: px, symbol: symbol, fg: color, scale: 0.86, weight: .regular),
              let d = r.representation(using: .png, properties: [:]) else { exit(1) }
        try! d.write(to: URL(fileURLWithPath: outDir + "/" + n))
    }
    print("iconset ok: \(outDir)")
} else if a[1] == "preview" {
    let color = hex(a[2]), out = a[3]
    let symbols = Array(a[4...])
    let cell = 128, pad = 12
    let W = (cell + pad) * symbols.count + pad, H = cell + pad * 2
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.white.setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()
    for (i, sym) in symbols.enumerated() {
        guard let g = render(px: cell, symbol: sym, fg: color, scale: 0.86, weight: .regular), let cg = g.cgImage else { continue }
        NSImage(cgImage: cg, size: NSSize(width: cell, height: cell))
            .draw(in: NSRect(x: pad + i * (cell + pad), y: pad, width: cell, height: cell))
    }
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
    print("preview: \(out)  \(symbols.joined(separator: " | "))")
}
