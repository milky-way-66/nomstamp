import AppKit
import CoreGraphics

// Food Map's app icon: the stamp that the whole interface is built around (ADR-005),
// printed in two inks on pandan green.

let S: CGFloat = 1024
let paper   = CGColor(srgbRed: 0.945, green: 0.961, blue: 0.945, alpha: 1)   // F1F5F1
let pandan  = CGColor(srgbRed: 0.043, green: 0.369, blue: 0.271, alpha: 1)   // 0B5E45
let pandanD = CGColor(srgbRed: 0.024, green: 0.235, blue: 0.176, alpha: 1)   // deeper, for the ground
let indigo  = CGColor(srgbRed: 0.118, green: 0.227, blue: 0.290, alpha: 1)   // 1E3A4A

func stampPath(in rect: CGRect, perforations: Int = 11) -> CGPath {
    var path = CGPath(roundedRect: rect, cornerWidth: rect.width * 0.12,
                      cornerHeight: rect.width * 0.12, transform: nil)
    let r = min(rect.width, rect.height) / CGFloat(perforations) / 2
    let columns = max(Int(rect.width / (r * 2)), 1)
    let rows = max(Int(rect.height / (r * 2)), 1)
    func bite(_ x: CGFloat, _ y: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2), transform: nil)
    }
    for c in 0...columns {
        let x = rect.minX + rect.width * CGFloat(c) / CGFloat(columns)
        path = path.subtracting(bite(x, rect.minY))
        path = path.subtracting(bite(x, rect.maxY))
    }
    for r0 in 0...rows {
        let y = rect.minY + rect.height * CGFloat(r0) / CGFloat(rows)
        path = path.subtracting(bite(rect.minX, y))
        path = path.subtracting(bite(rect.maxX, y))
    }
    return path
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
// No alpha: App Store Connect rejects an icon with a transparency channel.
guard let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8,
                          bytesPerRow: 0, space: space,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { exit(1) }

// The ground: pandan, lit from the top-left like paper under a lamp.
let grad = CGGradient(colorsSpace: space, colors: [pandan, pandanD] as CFArray,
                      locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])

let side = S * 0.66
let frame = CGRect(x: (S - side) / 2, y: (S - side) / 2, width: side, height: side)
let stamp = stampPath(in: frame)

// The second ink, a shade off register — the printing motif the app uses everywhere.
ctx.saveGState()
ctx.translateBy(x: -S * 0.014, y: -S * 0.012)
ctx.addPath(stamp)
ctx.setFillColor(indigo.copy(alpha: 0.85)!)
ctx.fillPath()
ctx.restoreGState()

ctx.addPath(stamp)
ctx.setFillColor(paper)
ctx.fillPath()

// An inner rule, the way a real stamp frames its picture.
let inner = frame.insetBy(dx: side * 0.11, dy: side * 0.11)
ctx.addPath(CGPath(roundedRect: inner, cornerWidth: inner.width * 0.06,
                   cornerHeight: inner.width * 0.06, transform: nil))
ctx.setStrokeColor(pandan.copy(alpha: 0.35)!)
ctx.setLineWidth(S * 0.006)
ctx.strokePath()

// The glyph: the same fork and knife a visited pin carries.
let config = NSImage.SymbolConfiguration(pointSize: 512, weight: .semibold)
if let symbol = NSImage(systemSymbolName: "fork.knife", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let target = inner.insetBy(dx: inner.width * 0.20, dy: inner.height * 0.10)
    var box = CGRect(origin: .zero, size: symbol.size)
    let scale = min(target.width / box.width, target.height / box.height)
    box.size = CGSize(width: box.width * scale, height: box.height * scale)
    box.origin = CGPoint(x: target.midX - box.width / 2, y: target.midY - box.height / 2)
    if let cg = symbol.cgImage(forProposedRect: &box, context: nil, hints: nil) {
        ctx.saveGState()
        ctx.clip(to: box, mask: cg)
        ctx.setFillColor(pandan)
        ctx.fill(box)
        ctx.restoreGState()
    }
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("wrote \(out.path)")
