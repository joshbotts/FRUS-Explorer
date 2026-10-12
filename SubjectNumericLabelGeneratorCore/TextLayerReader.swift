// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CoreGraphics
import Foundation

// MARK: - TextRun

/// One string a page's content stream shows, with the geometry the stream itself gives it (#1644).
struct TextRun: Sendable, Equatable {
    /// The string as the stream holds it, a trailing space included.
    let text: String
    /// Where the string begins, in points from the page's left.
    let minX: Double
    /// The right edge of its last character that is not a space.
    let maxX: Double
    /// Its baseline, in points from the page's bottom.
    let baseline: Double
    /// The top of its line, by ``StandardFontMetrics/Font/ascent``.
    let top: Double
    /// Its type size, in points.
    let size: Double
    /// Half the width of a space in its font, at its own horizontal stretch.
    let halfSpace: Double
}

// MARK: - TextLayerReader

/// Reads a scanned page's text layer from its content stream, and nothing from the system (#1644).
///
/// ## What went wrong, measured
/// The generator used to take a page's lines from PDFKit (`selectionsByLine()`). PDFKit decides
/// for itself where one word ends and the next begins, and that decision is the operating
/// system's: the same generator, the same handbooks and the same inputs wrote one table on macOS
/// 26 and another on macOS 27. Run inside four runtimes, the generator at the commit that wrote
/// the shipped table gave the shipped spacing under iOS 26.5 and, under iOS 27.0, the same 78
/// respaced subject labels of the 1963 schedule that macOS 27.0.1 gives (`REAL PROPER TY` for
/// `REAL PROPERTY` one way, and `US IS` for `USIS` the other, which made `US` an abbreviation's
/// expansion and renamed 121 country pairs).
///
/// ## What the text layer says for itself
/// Acrobat's Paper Capture wrote both layers, and wrote each recognised word as its own string at
/// its own position. The 1963 layer puts no space in any string; the 1965 layer ends each word's
/// string with one. So the layer states where nearly every word break is, and this reader takes
/// its word for it. Where two strings follow one another with no space written, the gap between
/// them decides, by the rule PDFKit applied until macOS 27: a new word begins where the gap is
/// wider than half a space of the earlier string's font. Fitted against iOS 26.5's own output,
/// that threshold comes out at 0.500 of a space in the 1963 handbook and 0.498 in the 1965 one,
/// and it disagrees with that system on 238 of 71,193 pairs and 3 of 1,290.
///
/// ## What is refused
/// The two files use a narrow part of PDF: eight standard fonts in `WinAnsiEncoding`, one hidden
/// composite font with a `ToUnicode` map and a default width, upright text matrices, and no form
/// XObject, rise, or rotated page. Anything else THROWS. A reader that guessed at a construct it
/// does not model would move text silently, which is the failure this file exists to end.
///
/// Version history:
///   1.0 — #1644: initial implementation
enum TextLayerReader {

    // MARK: Lines

    /// How far apart two baselines may be, as a share of the smaller type size, and still be one
    /// line.
    ///
    /// The capture set the parts of one printed line a fraction of a point apart where their type
    /// differs: a designator in eleven-point figures sits half a point from its nine-point label.
    /// A quarter of the type size takes that in, and the skew of a scanned page across the width
    /// of one line, and is far inside the tightest leading in either handbook (about ten and a
    /// half points at nine). The SMALLER size, because the scans' margins hold stray marks read
    /// as letters thirty and forty points tall, and measured by their own size they would reach
    /// into the line beside them.
    static let baselineTolerance = 0.25

    /// The gap, as a multiple of the smaller type size, at which a line is cut in two.
    ///
    /// A table's columns stand further apart than its words do. Of the pairs of runs that follow
    /// one another on a baseline, 72,198 in the 1963 handbook and 75,211 in the 1965 one, 69,581
    /// and 73,403 stand closer than one and a half type sizes, 2,486 and 1,518 stand two apart or
    /// more, and 131 and 290 lie between. Two typed spaces after a full stop come to 1.6 (`c. Use`,
    /// 14.09 points at 8.8), and a label of the 1963 outlines stands 2.2 from the instruction the
    /// capture wrote on its line (`INT 6`, 20.85 points at 9.3). PDFKit gave such a pair as one
    /// line, and 15 labels of that schedule shipped with a sentence run on.
    ///
    /// The cut falls in a thin part of the distribution and not in a gap, so whatever stands near
    /// it has to read the same on either side: a designator and its label are one row whether
    /// they are one line or two (``OutlineEntryParser/rowGroups(_:)``), and so are an appendix's
    /// code and the dash after it, most of which stand 1.9 to 2.1 apart. Measured on the table as
    /// shipped, a cut of 2.5 or of 3.0 changes one label (`INT 6` keeps its instruction), and a
    /// cut of 1.75 changes one (a designator of the 1965 travel outline, 1.94 from the end of a
    /// line of the column beside it, becomes a line of its own and its entry is read).
    static let columnGap = 2.0

    /// Groups a page's runs into lines: runs that follow one another in the stream, each to the
    /// right of the last and on its baseline, cut at a column's width of space.
    ///
    /// ## The stream's order says which runs are one line, and nothing more is taken from it
    /// The capture wrote each line it recognised as a sequence of strings, left to right, and
    /// then went on to the next: so two strings that follow one another, the second to the right
    /// of the first on the same baseline, are one line of its reading. Position alone does not
    /// say as much. The 1965 outlines set two columns close, and a line of the left one ends
    /// within thirteen points of a designator of the right on the same baseline, nearer than a
    /// wide space inside a label; the capture read them as two lines, and the stream keeps them
    /// apart.
    ///
    /// What the stream's order does NOT give is a table's rows. The 1963 outlines hold every
    /// designator of a page before any label, so the lines are placed by their geometry and the
    /// rows put together from them by height, later (``OutlineEntryParser/rowGroups(_:)``).
    ///
    /// - Parameter runs: A page's runs, in the stream's order.
    /// - Returns: The lines, top to bottom and then left to right.
    static func lines(from runs: [TextRun]) -> [PageLine] {
        var out: [PageLine] = []
        var piece: [TextRun] = []
        var reach = -Double.infinity
        for run in runs {
            if let last = piece.last {
                let size = min(last.size, run.size)
                let follows = abs(run.baseline - last.baseline) <= baselineTolerance * size
                    && run.minX >= last.minX
                if !follows || run.minX - reach > columnGap * size {
                    out.append(line(of: piece))
                    piece = []
                    reach = -Double.infinity
                }
            }
            piece.append(run)
            reach = max(reach, run.maxX)
        }
        if !piece.isEmpty { out.append(line(of: piece)) }
        // Stable on the stream's order for lines that tie on both keys, so the result never
        // depends on the sort's choice between equals.
        return out.enumerated().filter { !$0.element.text.isEmpty }.sorted { lhs, rhs in
            if lhs.element.y != rhs.element.y { return lhs.element.y > rhs.element.y }
            if lhs.element.x != rhs.element.x { return lhs.element.x < rhs.element.x }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    /// One line from the runs that make it, left to right.
    ///
    /// - Parameter runs: The line's runs, in reading order; never empty.
    /// - Returns: The line, placed at its first run's left edge and its tallest run's top.
    private static func line(of runs: [TextRun]) -> PageLine {
        var text = ""
        for (index, run) in runs.enumerated() {
            if index > 0, startsWord(run, after: runs[index - 1]), !text.hasSuffix(" ") {
                text += " "
            }
            text += run.text
        }
        let squeezed = text.split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
        // The tallest run places the line: its top is the line's, and its size the line's height.
        let tallest = runs.max { $0.top < $1.top } ?? runs[0]
        return PageLine(text: squeezed, x: runs[0].minX, y: tallest.top, height: tallest.size)
    }

    /// Whether a run begins a new word after the run before it on the line.
    ///
    /// The text layer's own space decides where it wrote one. Where it wrote none, the gap does:
    /// wider than half a space of the earlier run's font is a new word.
    ///
    /// - Parameters:
    ///   - run: The later run.
    ///   - previous: The run before it.
    /// - Returns: `true` when a space belongs between the two.
    static func startsWord(_ run: TextRun, after previous: TextRun) -> Bool {
        if previous.text.hasSuffix(" ") { return true }
        return run.minX - previous.maxX > previous.halfSpace
    }

    // MARK: Runs

    /// Every string a page's content stream shows, in the stream's own order.
    ///
    /// - Parameter page: A page of an open document.
    /// - Returns: The page's runs.
    /// - Throws: ``GenerationError`` when the page uses a construct this reader does not model.
    static func runs(of page: CGPDFPage) throws -> [TextRun] {
        guard page.rotationAngle == 0 else {
            throw GenerationError(description: "page \(page.pageNumber) is rotated by "
                + "\(page.rotationAngle) degrees, which the text-layer reader does not model")
        }
        guard let table = CGPDFOperatorTableCreate() else {
            throw GenerationError(description: "cannot create a PDF operator table")
        }
        defer { CGPDFOperatorTableRelease(table) }
        register(on: table)

        let stream = CGPDFContentStreamCreateWithPage(page)
        defer { CGPDFContentStreamRelease(stream) }
        let state = ScanState(stream: stream)
        let scanner = CGPDFScannerCreate(stream, table, Unmanaged.passUnretained(state).toOpaque())
        defer { CGPDFScannerRelease(scanner) }
        guard CGPDFScannerScan(scanner) else {
            throw GenerationError(description: "page \(page.pageNumber): its content stream "
                + "could not be read to the end")
        }
        guard state.unsupported.isEmpty else {
            throw GenerationError(description: "page \(page.pageNumber) uses what the text-layer "
                + "reader does not model: " + state.unsupported.sorted().joined(separator: "; "))
        }
        return state.runs
    }

    // MARK: Scan state

    /// How the strings of one font are decoded and measured.
    private enum FontReading {
        /// A standard font in `WinAnsiEncoding`: one byte a character, widths from the table.
        case standard(StandardFontMetrics.Font)
        /// The capture's hidden composite font: two bytes a character through its `ToUnicode`
        /// map, every character one type size wide.
        case hidden([UInt16: String])
        /// A font the reader could not make sense of. Reported when a string is shown in it.
        case unreadable(String)
    }

    /// The graphics and text state a content stream builds up, and the runs read so far.
    private final class ScanState {
        let stream: CGPDFContentStreamRef
        var runs: [TextRun] = []
        var unsupported: Set<String> = []

        var transform = CGAffineTransform.identity
        var saved: [CGAffineTransform] = []
        var textMatrix = CGAffineTransform.identity
        var lineMatrix = CGAffineTransform.identity
        var font: FontReading?
        var fontSize = 0.0
        var characterSpacing = 0.0
        var wordSpacing = 0.0
        var horizontalScale = 1.0
        var leading = 0.0
        /// Fonts already read, by the address of their dictionary.
        var fonts: [Int: FontReading] = [:]

        init(stream: CGPDFContentStreamRef) { self.stream = stream }

        /// Records one shown string and moves the text position past it.
        func show(_ string: CGPDFStringRef) {
            let count = CGPDFStringGetLength(string)
            guard count > 0, let pointer = CGPDFStringGetBytePtr(string) else { return }
            let bytes = UnsafeBufferPointer(start: pointer, count: count)
            guard let font else {
                unsupported.insert("a string shown before any font is set")
                return
            }

            var text = ""
            var advance = 0.0   // in text space, to the end of the string
            var ink = 0.0       // in text space, to the end of its last character that is no space
            // The hidden font's values: a character is one type size wide, a space included,
            // and PDFKit placed its line top one type size above the baseline.
            var ascent = 1.0
            var spaceWidth = 1.0

            switch font {
            case .standard(let metrics):
                ascent = metrics.ascent
                spaceWidth = Double(metrics.space) / 1000
                for byte in bytes {
                    guard let scalar = StandardFontMetrics.scalar(of: byte),
                          let width = metrics.width(of: byte) else {
                        unsupported.insert(String(format: "character code 0x%02X in a standard "
                                                  + "font, which has no width here", byte))
                        continue
                    }
                    text.unicodeScalars.append(scalar)
                    let glyph = Double(width) / 1000 * fontSize * horizontalScale
                    if byte != 0x20 { ink = advance + glyph }
                    advance += glyph
                        + (characterSpacing + (byte == 0x20 ? wordSpacing : 0)) * horizontalScale
                }
            case .hidden(let toUnicode):
                guard count % 2 == 0 else {
                    unsupported.insert("a string of odd length in the two-byte hidden font")
                    return
                }
                for index in stride(from: 0, to: count, by: 2) {
                    let code = UInt16(bytes[index]) << 8 | UInt16(bytes[index + 1])
                    guard let characters = toUnicode[code] else {
                        unsupported.insert(String(format: "code 0x%04X of the hidden font, which "
                                                  + "its ToUnicode map does not name", code))
                        continue
                    }
                    text += characters
                    let glyph = fontSize * horizontalScale
                    if characters != " " { ink = advance + glyph }
                    advance += glyph + characterSpacing * horizontalScale
                }
            case .unreadable(let reason):
                unsupported.insert(reason)
                return
            }

            // The run's place on the page: the text matrix, then the page's own transform.
            let matrix = textMatrix.concatenating(transform)
            guard abs(matrix.b) < 1e-9, abs(matrix.c) < 1e-9, matrix.a > 0, matrix.d > 0 else {
                unsupported.insert("text that is rotated, skewed or mirrored")
                return
            }
            let stretch = Double(matrix.a)
            let size = fontSize * Double(matrix.d)
            let minX = Double(matrix.tx)
            let baseline = Double(matrix.ty)
            if !text.isEmpty {
                runs.append(TextRun(text: text, minX: minX, maxX: minX + ink * stretch,
                                    baseline: baseline, top: baseline + ascent * size, size: size,
                                    halfSpace: 0.5 * spaceWidth * fontSize * horizontalScale
                                        * stretch))
            }
            textMatrix = CGAffineTransform(translationX: CGFloat(advance), y: 0)
                .concatenating(textMatrix)
        }

        /// Moves to the start of a new line, offset from the start of the current one.
        func moveLine(x: Double, y: Double) {
            lineMatrix = CGAffineTransform(translationX: CGFloat(x), y: CGFloat(y))
                .concatenating(lineMatrix)
            textMatrix = lineMatrix
        }

        /// Sets the font a `Tf` operator names.
        func setFont(named name: UnsafePointer<CChar>, size: Double) {
            fontSize = size
            guard let object = CGPDFContentStreamGetResource(stream, "Font", name) else {
                font = .unreadable("a font the page's resources do not hold")
                return
            }
            var dictionary: CGPDFDictionaryRef?
            guard CGPDFObjectGetValue(object, .dictionary, &dictionary), let dictionary else {
                font = .unreadable("a font resource that is not a dictionary")
                return
            }
            let key = unsafeBitCast(dictionary, to: Int.self)
            if let known = fonts[key] {
                font = known
                return
            }
            let reading = TextLayerReader.reading(of: dictionary)
            fonts[key] = reading
            font = reading
        }
    }

    // MARK: Fonts

    /// Works out how a font's strings are to be read.
    ///
    /// - Parameter dictionary: A font dictionary.
    /// - Returns: The reading, `.unreadable` naming what was unexpected.
    private static func reading(of dictionary: CGPDFDictionaryRef) -> FontReading {
        func name(_ key: String) -> String {
            var pointer: UnsafePointer<CChar>?
            guard CGPDFDictionaryGetName(dictionary, key, &pointer), let pointer else { return "" }
            return String(cString: pointer)
        }
        let subtype = name("Subtype")
        let baseFont = name("BaseFont")
        let encoding = name("Encoding")

        if subtype == "Type1" {
            var widths: CGPDFArrayRef?
            guard !CGPDFDictionaryGetArray(dictionary, "Widths", &widths) else {
                return .unreadable("the font \(baseFont) with a /Widths array of its own")
            }
            guard encoding == "WinAnsiEncoding" else {
                return .unreadable("the font \(baseFont) in the encoding '\(encoding)'")
            }
            guard let metrics = StandardFontMetrics.font(named: baseFont) else {
                return .unreadable("the font \(baseFont), whose widths this generator does not "
                                   + "carry")
            }
            return .standard(metrics)
        }

        if subtype == "Type0" {
            guard encoding == "Identity-H" else {
                return .unreadable("the composite font \(baseFont) in the encoding '\(encoding)'")
            }
            var descendants: CGPDFArrayRef?
            var descendant: CGPDFDictionaryRef?
            guard CGPDFDictionaryGetArray(dictionary, "DescendantFonts", &descendants),
                  let descendants, CGPDFArrayGetDictionary(descendants, 0, &descendant),
                  let descendant else {
                return .unreadable("the composite font \(baseFont) with no descendant font")
            }
            var perGlyph: CGPDFArrayRef?
            guard !CGPDFDictionaryGetArray(descendant, "W", &perGlyph) else {
                return .unreadable("the composite font \(baseFont) with per-character widths")
            }
            var defaultWidth: CGPDFReal = 1000
            if CGPDFDictionaryGetNumber(descendant, "DW", &defaultWidth), defaultWidth != 1000 {
                return .unreadable("the composite font \(baseFont) with a default width of "
                                   + "\(defaultWidth)")
            }
            var stream: CGPDFStreamRef?
            var format = CGPDFDataFormat.raw
            guard CGPDFDictionaryGetStream(dictionary, "ToUnicode", &stream), let stream,
                  let data = CGPDFStreamCopyData(stream, &format) as Data?,
                  let map = ToUnicodeMap.parse(data) else {
                return .unreadable("the composite font \(baseFont) with no readable ToUnicode map")
            }
            return .hidden(map)
        }
        return .unreadable("the font \(baseFont) of subtype '\(subtype)'")
    }

    // MARK: Operators

    /// The state a scanner callback was handed.
    private static func scanState(_ info: UnsafeMutableRawPointer?) -> ScanState {
        // The pointer is the `ScanState` `runs(of:)` created, alive for the whole scan.
        Unmanaged<ScanState>.fromOpaque(info!).takeUnretainedValue()
    }

    /// Pops one number off the scanner's operand stack, or zero.
    private static func number(_ scanner: CGPDFScannerRef) -> Double {
        var value: CGPDFReal = 0
        return CGPDFScannerPopNumber(scanner, &value) ? Double(value) : 0
    }

    /// Pops a transformation matrix's six operands, which arrive last first.
    private static func matrix(_ scanner: CGPDFScannerRef) -> CGAffineTransform {
        let ty = number(scanner), tx = number(scanner)
        let d = number(scanner), c = number(scanner), b = number(scanner), a = number(scanner)
        return CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
    }

    /// Registers the operators that place or show text. Everything else in a content stream (the
    /// scan's image, paths, colours, marked-content brackets) leaves the text where it is.
    private static func register(on table: CGPDFOperatorTableRef) {
        CGPDFOperatorTableSetCallback(table, "q") { _, info in
            let state = TextLayerReader.scanState(info)
            state.saved.append(state.transform)
        }
        CGPDFOperatorTableSetCallback(table, "Q") { _, info in
            let state = TextLayerReader.scanState(info)
            if let restored = state.saved.popLast() { state.transform = restored }
        }
        CGPDFOperatorTableSetCallback(table, "cm") { scanner, info in
            let state = TextLayerReader.scanState(info)
            state.transform = TextLayerReader.matrix(scanner).concatenating(state.transform)
        }
        CGPDFOperatorTableSetCallback(table, "BT") { _, info in
            let state = TextLayerReader.scanState(info)
            state.textMatrix = .identity
            state.lineMatrix = .identity
        }
        CGPDFOperatorTableSetCallback(table, "Tf") { scanner, info in
            let state = TextLayerReader.scanState(info)
            let size = TextLayerReader.number(scanner)
            var name: UnsafePointer<CChar>?
            guard CGPDFScannerPopName(scanner, &name), let name else {
                state.unsupported.insert("a Tf operator with no font name")
                return
            }
            state.setFont(named: name, size: size)
        }
        CGPDFOperatorTableSetCallback(table, "Tc") { scanner, info in
            TextLayerReader.scanState(info).characterSpacing = TextLayerReader.number(scanner)
        }
        CGPDFOperatorTableSetCallback(table, "Tw") { scanner, info in
            TextLayerReader.scanState(info).wordSpacing = TextLayerReader.number(scanner)
        }
        CGPDFOperatorTableSetCallback(table, "Tz") { scanner, info in
            TextLayerReader.scanState(info).horizontalScale = TextLayerReader.number(scanner) / 100
        }
        CGPDFOperatorTableSetCallback(table, "TL") { scanner, info in
            TextLayerReader.scanState(info).leading = TextLayerReader.number(scanner)
        }
        CGPDFOperatorTableSetCallback(table, "Ts") { scanner, info in
            if TextLayerReader.number(scanner) != 0 { TextLayerReader.scanState(info).unsupported.insert("text rise") }
        }
        CGPDFOperatorTableSetCallback(table, "Tm") { scanner, info in
            let state = TextLayerReader.scanState(info)
            state.lineMatrix = TextLayerReader.matrix(scanner)
            state.textMatrix = state.lineMatrix
        }
        CGPDFOperatorTableSetCallback(table, "Td") { scanner, info in
            let y = TextLayerReader.number(scanner), x = TextLayerReader.number(scanner)
            TextLayerReader.scanState(info).moveLine(x: x, y: y)
        }
        CGPDFOperatorTableSetCallback(table, "TD") { scanner, info in
            let state = TextLayerReader.scanState(info)
            let y = TextLayerReader.number(scanner), x = TextLayerReader.number(scanner)
            state.leading = -y
            state.moveLine(x: x, y: y)
        }
        CGPDFOperatorTableSetCallback(table, "T*") { _, info in
            let state = TextLayerReader.scanState(info)
            state.moveLine(x: 0, y: -state.leading)
        }
        CGPDFOperatorTableSetCallback(table, "Tj") { scanner, info in
            var string: CGPDFStringRef?
            guard CGPDFScannerPopString(scanner, &string), let string else { return }
            TextLayerReader.scanState(info).show(string)
        }
        CGPDFOperatorTableSetCallback(table, "TJ") { scanner, info in
            let state = TextLayerReader.scanState(info)
            var array: CGPDFArrayRef?
            guard CGPDFScannerPopArray(scanner, &array), let array else { return }
            // ONE RUN TO EACH STRING. A number between two strings moves the text position, and
            // the space it leaves is judged as the space between two `Tj` strings is.
            for index in 0..<CGPDFArrayGetCount(array) {
                var object: CGPDFObjectRef?
                guard CGPDFArrayGetObject(array, index, &object), let object else { continue }
                switch CGPDFObjectGetType(object) {
                case .string:
                    var string: CGPDFStringRef?
                    if CGPDFObjectGetValue(object, .string, &string), let string {
                        state.show(string)
                    }
                case .integer, .real:
                    var shift: CGPDFReal = 0
                    guard CGPDFObjectGetValue(object, .real, &shift) else { continue }
                    let move = -Double(shift) / 1000 * state.fontSize * state.horizontalScale
                    state.textMatrix = CGAffineTransform(translationX: CGFloat(move), y: 0)
                        .concatenating(state.textMatrix)
                default:
                    state.unsupported.insert("a TJ array holding something other than strings "
                                             + "and numbers")
                }
            }
        }
        // Operators that show text in ways neither file uses. Named so that a file which does
        // use one is refused, where an unregistered operator would be passed over in silence.
        CGPDFOperatorTableSetCallback(table, "'") { _, info in
            TextLayerReader.scanState(info).unsupported.insert("the ' text operator")
        }
        CGPDFOperatorTableSetCallback(table, "\"") { _, info in
            TextLayerReader.scanState(info).unsupported.insert("the \" text operator")
        }
        CGPDFOperatorTableSetCallback(table, "Do") { scanner, info in
            let state = TextLayerReader.scanState(info)
            var name: UnsafePointer<CChar>?
            guard CGPDFScannerPopName(scanner, &name), let name,
                  let object = CGPDFContentStreamGetResource(state.stream, "XObject", name)
            else { return }
            var stream: CGPDFStreamRef?
            var subtype: UnsafePointer<CChar>?
            guard CGPDFObjectGetValue(object, .stream, &stream), let stream,
                  let dictionary = CGPDFStreamGetDictionary(stream),
                  CGPDFDictionaryGetName(dictionary, "Subtype", &subtype), let subtype
            else { return }
            // A form XObject can hold text of its own, which this scan would never see.
            if String(cString: subtype) == "Form" {
                state.unsupported.insert("a form XObject")
            }
        }
    }
}

// MARK: - ToUnicodeMap

/// The `ToUnicode` map of the capture's hidden font: which characters each two-byte code stands
/// for (#1644).
enum ToUnicodeMap {

    /// Parses a `ToUnicode` CMap.
    ///
    /// Reads `bfchar` pairs and the `bfrange` form that gives one starting value. The form that
    /// lists every value in an array is not used by either handbook and is refused.
    ///
    /// - Parameter data: The decoded CMap stream.
    /// - Returns: `code -> characters`, or `nil` when the stream is not text or uses the array form.
    static func parse(_ data: Data) -> [UInt16: String]? {
        guard let text = String(data: data, encoding: .isoLatin1) else { return nil }
        var map: [UInt16: String] = [:]

        for body in sections(of: text, from: "beginbfchar", to: "endbfchar") {
            let tokens = hexTokens(in: body)
            for pair in stride(from: 0, to: tokens.count - 1, by: 2) {
                guard let code = tokens[pair].first else { continue }
                map[code] = String(utf16CodeUnits: tokens[pair + 1], count: tokens[pair + 1].count)
            }
        }
        for body in sections(of: text, from: "beginbfrange", to: "endbfrange") {
            guard !body.contains("[") else { return nil }
            let tokens = hexTokens(in: body)
            for triple in stride(from: 0, to: tokens.count - 2, by: 3) {
                guard let low = tokens[triple].first, let high = tokens[triple + 1].first,
                      let last = tokens[triple + 2].last, high >= low else { continue }
                let prefix = tokens[triple + 2].dropLast()
                for offset in 0...(high - low) {
                    let units = Array(prefix) + [last &+ offset]
                    map[low + offset] = String(utf16CodeUnits: units, count: units.count)
                }
            }
        }
        return map
    }

    /// The text between each `from` … `to` pair of keywords.
    private static func sections(of text: String, from: String, to: String) -> [Substring] {
        var out: [Substring] = []
        var rest = text[...]
        while let opening = rest.range(of: from),
              let closing = rest.range(of: to, range: opening.upperBound..<rest.endIndex) {
            out.append(rest[opening.upperBound..<closing.lowerBound])
            rest = rest[closing.upperBound...]
        }
        return out
    }

    /// Every `<…>` token of a CMap section, as 16-bit units.
    private static func hexTokens(in body: Substring) -> [[UInt16]] {
        var out: [[UInt16]] = []
        var rest = body
        while let opening = rest.firstIndex(of: "<"),
              let closing = rest[opening...].firstIndex(of: ">") {
            let digits = rest[rest.index(after: opening)..<closing].filter { !$0.isWhitespace }
            var units: [UInt16] = []
            var index = digits.startIndex
            while index < digits.endIndex {
                let end = digits.index(index, offsetBy: 4, limitedBy: digits.endIndex)
                    ?? digits.endIndex
                units.append(UInt16(digits[index..<end], radix: 16) ?? 0)
                index = end
            }
            out.append(units)
            rest = rest[rest.index(after: closing)...]
        }
        return out
    }
}
