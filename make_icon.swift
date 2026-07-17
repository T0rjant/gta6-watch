// Génère l'icône de l'app : dégradé Vice City + "VI"
import AppKit

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let iconsetURL = URL(fileURLWithPath: "build/AppIcon.iconset")
try? FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func drawIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let img = NSImage(size: NSSize(width: s, height: s))
    img.lockFocus()

    let rect = NSRect(x: s * 0.04, y: s * 0.04, width: s * 0.92, height: s * 0.92)
    let path = NSBezierPath(roundedRect: rect, xRadius: s * 0.21, yRadius: s * 0.21)
    let gradient = NSGradient(colors: [
        NSColor(red: 0.48, green: 0.18, blue: 0.97, alpha: 1),
        NSColor(red: 1.00, green: 0.18, blue: 0.51, alpha: 1),
        NSColor(red: 1.00, green: 0.56, blue: 0.21, alpha: 1),
    ])!
    gradient.draw(in: path, angle: -60)

    // Soleil Vice City
    let sun = NSBezierPath(ovalIn: NSRect(x: s * 0.30, y: s * 0.42, width: s * 0.40, height: s * 0.40))
    NSColor(red: 1, green: 0.85, blue: 0.4, alpha: 0.9).setFill()
    sun.fill()

    // Texte "VI"
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: s * 0.42, weight: .black),
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph,
    ]
    let text = NSAttributedString(string: "VI", attributes: attrs)
    text.draw(in: NSRect(x: 0, y: s * 0.08, width: s, height: s * 0.55))

    img.unlockFocus()
    return img
}

for size in sizes {
    let img = drawIcon(size: size)
    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    let base = size <= 512 ? size : 512
    let name = size == 1024 ? "icon_512x512@2x.png" : "icon_\(base)x\(base).png"
    try? png.write(to: iconsetURL.appendingPathComponent(name))
    if size >= 32 && size < 1024 {
        try? png.write(to: iconsetURL.appendingPathComponent("icon_\(size / 2)x\(size / 2)@2x.png"))
    }
}
print("iconset généré")
