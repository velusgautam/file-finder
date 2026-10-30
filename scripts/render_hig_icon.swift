import AppKit
import Foundation

// Apple Human Interface Guidelines macOS App Icon Renderer
// Standard 1024x1024 canvas
// 824x824 icon body centered at (100, 110) to allow for Apple standard drop shadow
// Corner radius: 185 px (superellipse/continuous curve)
// Outer canvas: 100% transparent (alpha = 0)

let inputPath = "/Users/velugautam/.gemini/antigravity-cli/brain/9740c700-690e-40d5-a555-2ca43bfe5ad8/file_finder_app_icon_1793364701406.jpg"
guard let inputImage = NSImage(contentsOfFile: inputPath) else {
    print("Could not load input image")
    exit(1)
}

let canvasSize = NSSize(width: 1024, height: 1024)
// Standard macOS icon rectangle: 824x824, slightly shifted up to y=115 for proper shadow breathing room
let iconRect = NSRect(x: 100, y: 112, width: 824, height: 824)
let cornerRadius: CGFloat = 185.0

let bitmapRep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvasSize.width),
    pixelsHigh: Int(canvasSize.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 32
)!

NSGraphicsContext.saveGraphicsState()
guard let context = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
    exit(1)
}
NSGraphicsContext.current = context
let cgContext = context.cgContext

// 1. Clear everything outside to 100% transparent
cgContext.clear(CGRect(origin: .zero, size: canvasSize))

// 2. Ambient drop shadow under squircle
cgContext.saveGState()
let shadowPath = NSBezierPath(roundedRect: iconRect.offsetBy(dx: 0, dy: -10), xRadius: cornerRadius, yRadius: cornerRadius)
cgContext.setShadow(
    offset: CGSize(width: 0, height: -18),
    blur: 28,
    color: NSColor.black.withAlphaComponent(0.24).cgColor
)
NSColor.black.withAlphaComponent(0.12).setFill()
shadowPath.fill()
cgContext.restoreGState()

// 3. Crisp contact shadow
cgContext.saveGState()
let contactPath = NSBezierPath(roundedRect: iconRect.offsetBy(dx: 0, dy: -4), xRadius: cornerRadius, yRadius: cornerRadius)
cgContext.setShadow(
    offset: CGSize(width: 0, height: -4),
    blur: 10,
    color: NSColor.black.withAlphaComponent(0.18).cgColor
)
NSColor.black.withAlphaComponent(0.10).setFill()
contactPath.fill()
cgContext.restoreGState()

// 4. Draw squircle content
let squirclePath = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)
cgContext.saveGState()
squirclePath.addClip()

// Clean white base background
NSColor.white.setFill()
squirclePath.fill()

// Draw the artwork scaled to fit the squircle with a nice balanced margin
// Scale artwork so its folder & prism fill the squircle beautifully
let artRect = iconRect.insetBy(dx: -40, dy: -40)
inputImage.draw(in: artRect, from: NSRect(origin: .zero, size: inputImage.size), operation: .sourceOver, fraction: 1.0)

// 5. Subtle Apple-style inner highlight border (top light reflection)
let innerStroke = NSBezierPath(roundedRect: iconRect.insetBy(dx: 1, dy: 1), xRadius: cornerRadius - 1, yRadius: cornerRadius - 1)
cgContext.setStrokeColor(NSColor.white.withAlphaComponent(0.60).cgColor)
cgContext.setLineWidth(2.0)
innerStroke.stroke()

// Subtle bottom rim darkening
let outerRim = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)
cgContext.setStrokeColor(NSColor.black.withAlphaComponent(0.08).cgColor)
cgContext.setLineWidth(1.0)
outerRim.stroke()

cgContext.restoreGState()
NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
    print("Could not generate PNG data")
    exit(1)
}

let outputPath = "Resources/AppIcon_1024.png"
try pngData.write(to: URL(fileURLWithPath: outputPath))
print("Successfully generated curved macOS squircle icon at \(outputPath)")
