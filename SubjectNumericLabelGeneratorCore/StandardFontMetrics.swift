// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - StandardFontMetrics

/// The advance widths of the standard fonts the handbooks' text layers name (#1644).
///
/// ## Why the generator carries font metrics at all
/// Both scans were made searchable by Acrobat's Paper Capture, which writes each recognised word
/// in one of the PDF standard fonts (`Times-Roman`, `Helvetica` and their bold and italic faces),
/// invisibly, and stretches it to the word's width on the scan. A standard font is never embedded
/// and carries no `/Widths` array: a reader is expected to know its metrics. So where a word ENDS
/// — which decides whether the next one is a new word, and whether it stands in another column —
/// can only be computed from these numbers.
///
/// Until #1644 the generator asked PDFKit, which answered from the operating system's copies of
/// the faces and with the operating system's rule for where a space falls. That rule changed
/// between macOS 26 and macOS 27, and the table the generator wrote changed with it. The widths
/// here are the fonts' own (Adobe's published metrics for the standard 14, 1,000 units to the em),
/// so the reading no longer depends on the system the generator runs on.
///
/// ## Only the codes the handbooks use
/// The 95 printable ASCII codes, and seven `WinAnsiEncoding` codes above them that the two text
/// layers contain. Any other code is REFUSED by the reader (it throws) rather than given a
/// guessed width: a wrong width moves a word's edge silently.
///
/// Version history:
///   1.0 — #1644: initial implementation
enum StandardFontMetrics {

    /// One standard font's metrics.
    struct Font: Sendable, Equatable {
        /// Advance widths for codes `0x20...0x7E`, in thousandths of the type size.
        let ascii: [Int]
        /// Advance widths for the `WinAnsiEncoding` codes above ASCII that the handbooks use.
        let high: [UInt8: Int]
        /// How far above the baseline a line of this face is taken to reach, as a share of the
        /// type size.
        ///
        /// A convention, not a measurement of ink. Every vertical threshold of the parse (the
        /// footer floor, the strips a corner mark is read from, the five points that make a row)
        /// was set against the line tops PDFKit reported on macOS, which are these shares: 0.75
        /// for the Times faces and 0.77 for the Helvetica ones. They are fixed here so that those
        /// thresholds keep meaning what they meant.
        let ascent: Double

        /// The advance width of one code, or `nil` when the handbooks' text layers never use it.
        ///
        /// - Parameter code: A `WinAnsiEncoding` character code.
        /// - Returns: The width in thousandths of the type size, or `nil`.
        func width(of code: UInt8) -> Int? {
            if code >= 0x20, code <= 0x7E { return ascii[Int(code) - 0x20] }
            return high[code]
        }

        /// The advance width of a space.
        var space: Int { ascii[0] }
    }

    /// The metrics of a standard font, by the name its font dictionary gives as `/BaseFont`.
    ///
    /// - Parameter baseFont: `Times-Roman`, `Helvetica-Bold`, and so on.
    /// - Returns: The font's metrics, or `nil` for a font this table does not carry.
    static func font(named baseFont: String) -> Font? {
        fonts[baseFont]
    }

    /// The Unicode scalar a `WinAnsiEncoding` code stands for, or `nil` for a code the handbooks'
    /// text layers never use.
    ///
    /// - Parameter code: A character code.
    /// - Returns: The scalar, or `nil`.
    static func scalar(of code: UInt8) -> Unicode.Scalar? {
        if code >= 0x20, code <= 0x7E { return Unicode.Scalar(code) }
        return highScalars[code]
    }

    /// The seven codes above ASCII, as `WinAnsiEncoding` assigns them.
    private static let highScalars: [UInt8: Unicode.Scalar] = [
        0x80: "\u{20AC}",  // Euro
        0x95: "\u{2022}",  // bullet
        0xA2: "\u{00A2}",  // cent
        0xA3: "\u{00A3}",  // sterling
        0xA5: "\u{00A5}",  // yen
        0xAD: "-",         // the encoding's second code for the hyphen
        0xB7: "\u{00B7}",  // periodcentered
    ]

    /// The share of the type size a Times line reaches above its baseline.
    private static let timesAscent = 0.75
    /// The share of the type size a Helvetica line reaches above its baseline.
    private static let helveticaAscent = 0.77

    private static let helveticaHigh: [UInt8: Int] = [
        0x80: 556, 0x95: 350, 0xA2: 556, 0xA3: 556, 0xA5: 556, 0xAD: 333, 0xB7: 278,
    ]
    private static let timesHigh: [UInt8: Int] = [
        0x80: 500, 0x95: 350, 0xA2: 500, 0xA3: 500, 0xA5: 500, 0xAD: 333, 0xB7: 250,
    ]

    private static let helvetica: [Int] = [
        278, 278, 355, 556, 556, 889, 667, 191, 333, 333, 389, 584, 278, 333, 278, 278, 556, 556, 556,
        556, 556, 556, 556, 556, 556, 556, 278, 278, 584, 584, 584, 556, 1015, 667, 667, 722, 722, 667,
        611, 778, 722, 278, 500, 667, 556, 833, 722, 778, 667, 778, 722, 667, 611, 722, 667, 944, 667,
        667, 611, 278, 278, 278, 469, 556, 333, 556, 556, 500, 556, 556, 278, 556, 556, 222, 222, 500,
        222, 833, 556, 556, 556, 556, 333, 500, 278, 556, 500, 722, 500, 500, 500, 334, 260, 334, 584,
    ]
    private static let helveticaBold: [Int] = [
        278, 333, 474, 556, 556, 889, 722, 238, 333, 333, 389, 584, 278, 333, 278, 278, 556, 556, 556,
        556, 556, 556, 556, 556, 556, 556, 333, 333, 584, 584, 584, 611, 975, 722, 722, 722, 722, 667,
        611, 778, 722, 278, 556, 722, 611, 833, 722, 778, 667, 778, 722, 667, 611, 722, 667, 944, 667,
        667, 611, 333, 278, 333, 584, 556, 333, 556, 611, 556, 611, 556, 333, 611, 611, 278, 278, 556,
        278, 889, 611, 611, 611, 611, 389, 556, 333, 611, 556, 778, 556, 556, 500, 389, 280, 389, 584,
    ]
    private static let timesRoman: [Int] = [
        250, 333, 408, 500, 500, 833, 778, 180, 333, 333, 500, 564, 250, 333, 250, 278, 500, 500, 500,
        500, 500, 500, 500, 500, 500, 500, 278, 278, 564, 564, 564, 444, 921, 722, 667, 667, 722, 611,
        556, 722, 722, 333, 389, 722, 611, 889, 722, 722, 556, 722, 667, 556, 611, 722, 722, 944, 722,
        722, 611, 333, 278, 333, 469, 500, 333, 444, 500, 444, 500, 444, 333, 500, 500, 278, 278, 500,
        278, 778, 500, 500, 500, 500, 333, 389, 278, 500, 500, 722, 500, 500, 444, 480, 200, 480, 541,
    ]
    private static let timesBold: [Int] = [
        250, 333, 555, 500, 500, 1000, 833, 278, 333, 333, 500, 570, 250, 333, 250, 278, 500, 500, 500,
        500, 500, 500, 500, 500, 500, 500, 333, 333, 570, 570, 570, 500, 930, 722, 667, 722, 722, 667,
        611, 778, 778, 389, 500, 778, 667, 944, 722, 778, 611, 778, 722, 556, 667, 722, 722, 1000, 722,
        722, 667, 333, 278, 333, 581, 500, 333, 500, 556, 444, 556, 444, 333, 500, 556, 278, 333, 556,
        278, 833, 556, 500, 556, 556, 444, 389, 333, 556, 500, 722, 500, 500, 444, 394, 220, 394, 520,
    ]
    private static let timesItalic: [Int] = [
        250, 333, 420, 500, 500, 833, 778, 214, 333, 333, 500, 675, 250, 333, 250, 278, 500, 500, 500,
        500, 500, 500, 500, 500, 500, 500, 333, 333, 675, 675, 675, 500, 920, 611, 611, 667, 722, 611,
        611, 722, 722, 333, 444, 667, 556, 833, 667, 722, 611, 722, 611, 500, 556, 722, 611, 833, 611,
        556, 556, 389, 278, 389, 422, 500, 333, 500, 500, 444, 500, 444, 278, 500, 500, 278, 278, 444,
        278, 722, 500, 500, 500, 500, 389, 389, 278, 500, 444, 667, 444, 444, 389, 400, 275, 400, 541,
    ]
    private static let timesBoldItalic: [Int] = [
        250, 389, 555, 500, 500, 833, 778, 278, 333, 333, 500, 570, 250, 333, 250, 278, 500, 500, 500,
        500, 500, 500, 500, 500, 500, 500, 333, 333, 570, 570, 570, 500, 832, 667, 667, 667, 722, 667,
        667, 722, 778, 389, 500, 667, 611, 889, 722, 722, 611, 722, 667, 556, 611, 722, 667, 889, 667,
        611, 611, 333, 278, 333, 570, 500, 333, 500, 500, 444, 500, 444, 333, 500, 556, 278, 278, 500,
        278, 778, 556, 500, 500, 500, 389, 389, 278, 556, 444, 667, 500, 444, 389, 348, 220, 348, 570,
    ]

    /// The eight faces, by `/BaseFont`. The oblique Helveticas share the upright faces' widths.
    private static let fonts: [String: Font] = [
        "Helvetica": Font(ascii: helvetica, high: helveticaHigh, ascent: helveticaAscent),
        "Helvetica-Bold": Font(ascii: helveticaBold, high: helveticaHigh, ascent: helveticaAscent),
        "Helvetica-Oblique": Font(ascii: helvetica, high: helveticaHigh, ascent: helveticaAscent),
        "Helvetica-BoldOblique": Font(ascii: helveticaBold, high: helveticaHigh,
                                      ascent: helveticaAscent),
        "Times-Roman": Font(ascii: timesRoman, high: timesHigh, ascent: timesAscent),
        "Times-Bold": Font(ascii: timesBold, high: timesHigh, ascent: timesAscent),
        "Times-Italic": Font(ascii: timesItalic, high: timesHigh, ascent: timesAscent),
        "Times-BoldItalic": Font(ascii: timesBoldItalic, high: timesHigh, ascent: timesAscent),
    ]
}
