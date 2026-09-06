#!/usr/bin/env swift
//
// Renders a caption strip to a transparent PNG, for the map film's burned-in grain sentence
// (VM §7 step 11 / F-1).
//
// WHY THIS EXISTS AT ALL: the ffmpeg on this machine has NO text rendering. `drawtext`, `subtitles`
// and `ass` are all absent from `ffmpeg -filters`, and the build carries neither `--enable-libfreetype`
// nor `--enable-libass` — it can MUX a subtitle track (mov_text/srt/webvtt encoders are present) but
// it cannot draw a glyph. So the one line the film must carry in the image, rather than in a sidecar
// a copy of the file would lose, has to be rasterised somewhere else and overlaid. CoreText is the
// renderer this machine has, and Swift is the language the repo is written in.
//
// It is a `swift <file>` script and NOT an SPM target on purpose: nothing in the app links it, it
// produces no bundled resource, and enrolling it would mean an `xcodegen generate` plus the scheme
// restore for a tool that renders one PNG.
//
// IT PRINTS THE MEASURED TEXT HEIGHT AND FAILS WHEN THE TEXT DOES NOT FIT. CoreText clips silently:
// a frame too short simply drops the lines that do not fit, and the result is a caption missing its
// last sentence with nothing anywhere saying so — which on a disclosure line is the one failure that
// matters. `CTFrameGetVisibleStringRange` is what makes the clip detectable, and a short frame exits
// non-zero rather than writing.
//
// Usage:
//   swift render_caption.swift --out band.png --width 1440 --height 109 \
//        --font-size 22 --margin-x 60 --margin-y 14 --text "…"

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

guard let outPath = argument("out"), let text = argument("text") else {
    FileHandle.standardError.write(Data("usage: --out <png> --text <string> [--width --height --font-size --margin-x --margin-y --opacity --align]\n".utf8))
    exit(2)
}
let width = Int(argument("width", default: "1440")!)!
let height = Int(argument("height", default: "109")!)!
let fontSize = CGFloat(Double(argument("font-size", default: "22")!)!)
let marginX = CGFloat(Double(argument("margin-x", default: "60")!)!)
let marginY = CGFloat(Double(argument("margin-y", default: "14")!)!)
let opacity = CGFloat(Double(argument("opacity", default: "0.72")!)!)
let alignRaw = argument("align", default: "center")!

// The film's own typography: a humanist sans at a modest weight, tracked slightly open so a light
// grey line stays legible over a near-black ground at video bitrates.
let font = CTFontCreateWithName("HelveticaNeue-Light" as CFString, fontSize, nil)
var alignment: CTTextAlignment = alignRaw == "left" ? .left : (alignRaw == "right" ? .right : .center)
var lineSpacing = fontSize * 0.42
var settings = [
    CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: &alignment),
    CTParagraphStyleSetting(spec: .lineSpacingAdjustment, valueSize: MemoryLayout<CGFloat>.size, value: &lineSpacing),
]
let paragraph = CTParagraphStyleCreate(&settings, settings.count)

// The attribute keys are CoreText's own constants, NOT the `.font` / `.foregroundColor`
// conveniences: those are declared by AppKit and UIKit, so reaching for them would pull a UI
// framework into a script that draws into an offscreen bitmap and needs no window server.
let attributed = NSAttributedString(string: text, attributes: [
    NSAttributedString.Key(kCTFontAttributeName as String): font,
    NSAttributedString.Key(kCTForegroundColorAttributeName as String):
        CGColor(red: 1, green: 1, blue: 1, alpha: opacity),
    NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraph,
    NSAttributedString.Key(kCTKernAttributeName as String): fontSize * 0.02,
])

let textRect = CGRect(x: marginX, y: marginY,
                      width: CGFloat(width) - 2 * marginX,
                      height: CGFloat(height) - 2 * marginY)
let framesetter = CTFramesetterCreateWithAttributedString(attributed)
let path = CGPath(rect: textRect, transform: nil)
let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)

// The clip check, before anything is drawn.
let visible = CTFrameGetVisibleStringRange(frame)
guard visible.length == attributed.length else {
    FileHandle.standardError.write(Data(
        "caption does not fit: \(visible.length) of \(attributed.length) characters fit a \(width)x\(height) band at \(fontSize)pt. Raise --height, lower --font-size, or widen --width.\n".utf8))
    exit(1)
}

// The natural height the text actually wants, so the caller can size the band from a measurement.
let suggested = CTFramesetterSuggestFrameSizeWithConstraints(
    framesetter, CFRangeMake(0, 0), nil, CGSize(width: textRect.width, height: .greatestFiniteMagnitude), nil)
let lines = (CTFrameGetLines(frame) as! [CTLine]).count

guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                              bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    FileHandle.standardError.write(Data("could not create the bitmap context\n".utf8))
    exit(1)
}
context.clear(CGRect(x: 0, y: 0, width: width, height: height))
context.setAllowsAntialiasing(true)
context.setShouldSmoothFonts(true)
CTFrameDraw(frame, context)

guard let image = context.makeImage() else {
    FileHandle.standardError.write(Data("could not snapshot the context\n".utf8))
    exit(1)
}
let url = URL(fileURLWithPath: outPath)
guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    FileHandle.standardError.write(Data("could not open \(outPath) for writing\n".utf8))
    exit(1)
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    FileHandle.standardError.write(Data("could not write \(outPath)\n".utf8))
    exit(1)
}
print("wrote \(outPath): \(width)x\(height), \(lines) lines, text wants \(Int(suggested.height.rounded()))pt of the \(Int(textRect.height))pt available at \(Int(fontSize))pt")
