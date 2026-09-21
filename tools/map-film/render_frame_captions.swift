#!/usr/bin/env swift
//
// Renders the map film's PER-FRAME caption — the volume that lands on each frame — as one
// transparent PNG per frame, for a band BELOW the map (VM §7 step 11 / F-1, revised 2026-09-20).
//
// WHY BURNED IN, when this used to be a soft subtitle track. The track was muxed with
// `disposition:default=1`, so every player showed it, and a player draws a subtitle wherever it
// likes — which in practice is over the bottom of the picture. Each cue ran to three lines (year ·
// id · totals, then two lines of title), so the caption sat on the lower map for the whole film.
// Padding the frame cannot fix that, because the placement is the player's, not the file's. Burned
// in, the caption lands exactly where the layout puts it: in its own band, under the map.
//
// WHY TWO FIXED BASELINES. At 12 fps each caption is on screen for 83 ms, so any geometry that
// depends on the text makes the band twitch. Line positions come from the FONT's metrics, never
// from the string, so every one of the 554 PNGs has identical text geometry and the only thing that
// moves between frames is the words. The closing frame, which has no title, keeps line 1 exactly
// where every other frame has it.
//
// WHY TRUNCATE BY WIDTH. Titles run to 498 characters. `make_subtitles.py` wraps the sidecar by
// COLUMN count, which is right for a subtitle the player sets in its own font and wrong here: only
// the renderer knows how wide a line of HelveticaNeue-Light is. `CTLineCreateTruncatedLine` cuts the
// title at the width it actually has and ends it with an ellipsis. The HEADER is never truncated —
// it carries the volume id, which is the whole point of the caption — so a header that does not fit
// on one line fails the run, naming the frame, rather than losing the id.
//
// The text itself comes from `make_subtitles.py --captions-tsv`, the same formatter that writes the
// `.srt` sidecar, so the burned-in caption and the sidecar cannot disagree about what a frame says.
//
// Usage:
//   swift render_frame_captions.swift --tsv frame-captions.tsv --out-dir captions \
//        --width 1440 --font-size 20 --margin-x 70 --margin-y 8

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

guard let tsvPath = argument("tsv"), let outDir = argument("out-dir") else {
    fail("usage: --tsv <frame-captions.tsv> --out-dir <dir> [--width --font-size --margin-x --margin-y --opacity --title-opacity]")
}
let width = Int(argument("width", default: "1440")!)!
let fontSize = CGFloat(Double(argument("font-size", default: "20")!)!)
let marginX = CGFloat(Double(argument("margin-x", default: "70")!)!)
let marginY = CGFloat(Double(argument("margin-y", default: "8")!)!)
// The header carries the id and the running totals, so it is set at the film's caption opacity; the
// title sits a step back. Two levels, so a glance lands on the line that identifies the frame.
let opacity = CGFloat(Double(argument("opacity", default: "0.72")!)!)
let titleOpacity = CGFloat(Double(argument("title-opacity", default: "0.55")!)!)

// The film's own typography — the same face, kerning and colour as `render_caption.swift`, so the
// band under the map reads as the same hand as the line above it.
let font = CTFontCreateWithName("HelveticaNeue-Light" as CFString, fontSize, nil)
let ascent = CTFontGetAscent(font)
let descent = CTFontGetDescent(font)
let leading = CTFontGetLeading(font)
let lineHeight = (ascent + descent + leading).rounded(.up)
let lineGap = (fontSize * 0.22).rounded()
let available = CGFloat(width) - 2 * marginX

// The band's height, from the font alone. Rounded up to an even number because the band is stacked
// into an h264 frame, whose dimensions must be even.
let rawHeight = marginY + lineHeight + lineGap + lineHeight + marginY
let height = Int(rawHeight.rounded(.up)) + Int(rawHeight.rounded(.up)) % 2

// Baselines in Core Graphics coordinates (origin bottom-left), fixed for every frame.
let baseline1 = CGFloat(height) - marginY - ascent
let baseline2 = baseline1 - lineHeight - lineGap

func attributed(_ text: String, alpha: CGFloat) -> NSAttributedString {
    // CoreText's own attribute keys — the `.font` / `.foregroundColor` conveniences are AppKit and
    // UIKit declarations, and this script needs no UI framework.
    NSAttributedString(string: text, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String):
            CGColor(red: 1, green: 1, blue: 1, alpha: alpha),
        NSAttributedString.Key(kCTKernAttributeName as String): fontSize * 0.02,
    ])
}

func lineWidth(_ line: CTLine) -> CGFloat {
    CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
}

guard let raw = try? String(contentsOfFile: tsvPath, encoding: .utf8) else {
    fail("could not read \(tsvPath)")
}
let rows = raw.split(separator: "\n", omittingEmptySubsequences: true).map {
    $0.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
}
guard !rows.isEmpty else { fail("no rows in \(tsvPath); a film with no captions is a broken build") }

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
let ellipsis = CTLineCreateWithAttributedString(attributed("…", alpha: titleOpacity))
var truncated = 0

for (position, fields) in rows.enumerated() {
    guard fields.count >= 2, let frame = Int(fields[0]) else {
        fail("row \(position + 1) is not frame<TAB>header<TAB>title")
    }
    // A hole here would slide every later caption onto the wrong frame of the film.
    guard frame == position else { fail("frame column is not 0..\(rows.count - 1) with no gaps (row \(position + 1) says \(frame))") }
    let header = fields[1]
    let title = fields.count > 2 ? fields[2] : ""

    let headerLine = CTLineCreateWithAttributedString(attributed(header, alpha: opacity))
    guard lineWidth(headerLine) <= available else {
        fail("frame \(frame): the header needs \(Int(lineWidth(headerLine))) px and the band has \(Int(available)); it carries the volume id and is never truncated — lower --font-size or --margin-x")
    }

    var titleLine: CTLine?
    if !title.isEmpty {
        let full = CTLineCreateWithAttributedString(attributed(title, alpha: titleOpacity))
        if lineWidth(full) > available {
            truncated += 1
            titleLine = CTLineCreateTruncatedLine(full, Double(available), .end, ellipsis)
        } else {
            titleLine = full
        }
    }

    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fail("could not create the bitmap context")
    }
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    context.setAllowsAntialiasing(true)
    context.setShouldSmoothFonts(true)

    // Centred horizontally, like the caption above the map; fixed baselines vertically.
    context.textPosition = CGPoint(x: ((CGFloat(width) - lineWidth(headerLine)) / 2).rounded(),
                                   y: baseline1)
    CTLineDraw(headerLine, context)
    if let titleLine {
        context.textPosition = CGPoint(x: ((CGFloat(width) - lineWidth(titleLine)) / 2).rounded(),
                                       y: baseline2)
        CTLineDraw(titleLine, context)
    }

    guard let image = context.makeImage() else { fail("frame \(frame): could not snapshot the context") }
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(String(format: "caption-%04d.png", frame))
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fail("frame \(frame): could not open \(url.path) for writing")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fail("frame \(frame): could not write \(url.path)") }
}

print("wrote \(rows.count) captions to \(outDir): \(width)x\(height) at \(Int(fontSize))pt, \(truncated) titles truncated to width")
