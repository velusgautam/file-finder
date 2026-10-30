import AppKit
import Foundation

// Standard macOS Icon Specification:
// Canvas: 1024 x 1024
// Icon frame: 824 x 824 centered at (100, 100)
// Corner radius: 185 px (macOS squircle continuous curve)
// Outer region: 100% transparent RGBA (0, 0, 0, 0)
// Shadow: Subtle bottom contact drop shadow matching macOS Sonoma/Sequoia guidelines

func processIcon(inputPath: String, outputPath: String, backgroundColor: NSColor? = nil) {
    guard let inputImage = NSImage(contentsOfFile: inputPath) else {
        print("Error: Could not load \(inputPath)")
        exit(1)
    }

    let canvasSize = NSSize(width: 1024, height: 1024)
    let iconRect = NSRect(x: 100, y: 100, width: 824, height: 824)
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
    let context = NSGraphicsContext(bitmapImageRep: bitmapRep)!
    NSGraphicsContext.current = context

    let cgContext = context.cgContext
    // Clear whole canvas to completely transparent
    cgContext.clear(CGRect(origin: .zero, size: canvasSize))

    // 1. Draw subtle ambient drop shadow beneath the squircle
    cgContext.saveGState()
    let shadowPath = NSBezierPath(roundedRect: iconRect.offsetBy(dx: 0, dy: -12), xRadius: cornerRadius, yRadius: cornerRadius)
    cgContext.setShadow(
        offset: CGSize(width: 0, height: -14),
        blur: 24,
        color: NSColor.black.withAlphaComponent(0.28).cgColor
    )
    NSColor.black.withAlphaComponent(0.15).setFill()
    shadowPath.fill()
    cgContext.restoreGState()

    // 2. Draw sharp contact shadow
    cgContext.saveGState()
    let contactPath = NSBezierPath(roundedRect: iconRect.offsetBy(dx: 0, dy: -4), xRadius: cornerRadius, yRadius: cornerRadius)
    cgContext.setShadow(
        offset: CGSize(width: 0, height: -4),
        blur: 8,
        color: NSColor.black.withAlphaComponent(0.20).cgColor
    )
    NSColor.black.withAlphaComponent(0.10).setFill()
    contactPath.fill()
    cgContext.restoreGState()

    // 3. Clip to squircle path
    let squirclePath = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)

    cgContext.saveGState()
    squirclePath.addClip()

    // Optional solid white / clean background
    if let bg = backgroundColor {
        bg.setFill()
        squirclePath.fill()
    }

    // Draw the image inside the clipped squircle
    inputImage.draw(in: iconRect, from: NSRect(origin: .zero, size: inputImage.size), operation: .sourceOver, fraction: 1.0)

    // Inner bevel / subtle highlight border around the squircle (1px semi-transparent white top highlight)
    cgContext.setStrokeColor(NSColor.white.withAlphaComponent(0.25).cgColor)
    cgContext.setLineWidth(2.0)
    squirclePath.stroke()

    cgContext.restoreGState()

    NSGraphicsContext.restoreGraphicsState()

    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        print("Error: Could not encode to PNG")
        exit(1)
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: outputPath))
        print("Successfully generated masked macOS icon at: \(outputPath)")
    } catch {
        print("Error writing output: \(error)")
        exit(1)
    }
}

let args = CommandLine.arguments
if args.count < 3 {
    print("Usage: swift make_macos_icon.swift <input_image> <output_png> [--white-bg]")
    exit(1)
}

let input = args[1]
let output = args[2]
let whiteBg = args.contains("--white-bg") ? NSColor.white : nil

processIcon(inputPath: input, outputPath: output, backgroundColor: whiteBg)
