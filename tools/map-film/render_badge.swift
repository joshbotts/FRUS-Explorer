#!/usr/bin/env swift
//
// Renders the film's corner badge — the app icon and the wordmark beside it — to a transparent PNG
// (map film, 2026-09-20).
//
// THE ICON IS READ FROM THE APP'S OWN ASSET CATALOG, never copied into this directory. The film is a
// publication asset made from the app's data by the app's own code; a second copy of the icon here
// would be a second thing to update when the icon changes, and it would go stale silently — the
// badge would keep rendering, just with last year's mark.
//
// It is ROUNDED, because the source is a full-bleed square. `AppIcon-1024.png` is the unmasked
// artwork iOS itself masks at draw time, so drawing it as-is would put a hard-cornered red square in
// the corner of the frame — the one place in this film with a straight edge. The radius is 22.37% of
// the side, the standard approximation of the platform's continuous-corner squircle; at badge size
// the difference between that and the real superellipse is well under a pixel.
//
// The wordmark is the film's own face and colour (`render_caption.swift`'s HelveticaNeue-Light), a
// step brighter than a caption because a mark should read as a mark and not as another line of text.
//
// The PNG is sized to its contents and the size is printed, so the caller places it by measurement
// rather than by a number agreed in two places.
//
// Usage:
//   swift render_badge.swift --out badge.png --icon …/AppIcon-1024.png \
//        --icon-size 52 --font-size 22 --gap 12 --opacity 0.82 --text "FRUS Explorer"

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

func argument(_ name: String, default fallback: String? = nil) -> String? {
    let args = CommandLine.arguments
    guard let index = args.firstIndex(of: "--\(name)"), index + 1 < args.count else { return fallback }
    return args[index + 1]
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

guard let outPath = argument("out"), let iconPath = argument("icon") else {
    fail("usage: --out <png> --icon <png> [--icon-size --font-size --gap --opacity --text]")
}
let iconSize = CGFloat(Double(argument("icon-size", default: "52")!)!)
let fontSize = CGFloat(Double(argument("font-size", default: "22")!)!)
let gap = CGFloat(Double(argument("gap", default: "12")!)!)
let opacity = CGFloat(Double(argument("opacity", default: "0.82")!)!)
let text = argument("text", default: "FRUS Explorer")!

guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: iconPath) as CFURL, nil),
      let icon = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fail("could not read the app icon at \(iconPath)")
}

let font = CTFontCreateWithName("HelveticaNeue-Light" as CFString, fontSize, nil)
let attributed = NSAttributedString(string: text, attributes: [
    NSAttributedString.Key(kCTFontAttributeName as String): font,
    NSAttributedString.Key(kCTForegroundColorAttributeName as String):
        CGColor(red: 1, green: 1, blue: 1, alpha: opacity),
    NSAttributedString.Key(kCTKernAttributeName as String): fontSize * 0.02,
])
let line = CTLineCreateWithAttributedString(attributed)
var ascent: CGFloat = 0, descent: CGFloat = 0
let textWidth = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))

let width = Int((iconSize + gap + textWidth).rounded(.up))
let height = Int(max(iconSize, ascent + descent).rounded(.up))

guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                              bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fail("could not create the bitmap context")
}
context.clear(CGRect(x: 0, y: 0, width: width, height: height))
context.setAllowsAntialiasing(true)
context.setShouldSmoothFonts(true)

// The icon, masked to the platform's corner radius.
let iconRect = CGRect(x: 0, y: (CGFloat(height) - iconSize) / 2, width: iconSize, height: iconSize)
context.saveGState()
context.addPath(CGPath(roundedRect: iconRect,
                       cornerWidth: iconSize * 0.2237, cornerHeight: iconSize * 0.2237,
                       transform: nil))
context.clip()
context.draw(icon, in: iconRect)
context.restoreGState()

// The wordmark, its cap height centred on the icon rather than its baseline: the ascent-to-descent
// box is taller than the letters, so baseline-centring sits the word visibly low.
context.textPosition = CGPoint(x: iconRect.maxX + gap,
                               y: (CGFloat(height) - (ascent - descent)) / 2)
CTLineDraw(line, context)

guard let image = context.makeImage() else { fail("could not snapshot the context") }
guard let destination = CGImageDestinationCreateWithURL(
    URL(fileURLWithPath: outPath) as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fail("could not open \(outPath) for writing")
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fail("could not write \(outPath)") }
print("wrote \(outPath): \(width)x\(height), icon \(Int(iconSize))pt + \"\(text)\" at \(Int(fontSize))pt")
