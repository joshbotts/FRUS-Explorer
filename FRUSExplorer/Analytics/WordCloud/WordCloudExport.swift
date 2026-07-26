// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Renders word-cloud artwork for export.
///
/// Image exports use SwiftUI `ImageRenderer` over a non-interactive
/// `WordCloudImageContent`, so the exported artwork matches the on-screen cloud
/// layout. All entry points run on the main actor because `ImageRenderer` does.
///
/// Since D3 Phase 4 the image entry point returns **bytes**, not a written file, so it composes with
/// `AnalyticsExportDelivery` — the macOS save panel and the per-export iOS temp directory the rest of
/// the analytics exports already use — and so a failure can be reported rather than swallowed.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
///   1.1 — D3 Phase 4: `csv` removed (the view builds a provenance-stamped table instead);
///          `image` returns `Data?` and takes an optional provenance caption line
enum WordCloudExporter {

    /// Fixed export canvas size (4:3, comfortable for slides and print).
    private static let canvas = CGSize(width: 1200, height: 900)

    /// The most words the export layout will place. The cloud can hold many more ranked terms than
    /// this — the CSV carries all of them — so anything the plate says about "terms shown" has to be
    /// counted from the placements, not from the caller's list.
    static let maxDrawnWords = 140

    /// Renders the cloud to PNG or PDF bytes.
    ///
    /// - Parameters:
    ///   - terms: The ranked terms.
    ///   - title: Scope title, drawn in the caption band.
    ///   - provenanceLine: Builds the identifying facts drawn under the title, given **the number of
    ///     words actually placed on the plate**. It takes that count rather than a finished string
    ///     because the layout draws at most `maxDrawnWords` and can drop more that do not fit, so a
    ///     caption built from the caller's term count would overstate what the reader can see. Pass
    ///     `nil` to leave the band title-only.
    ///   - format: PNG or PDF.
    ///   - palette: The colour palette to draw words with.
    ///   - sentimentColors: When `true`, words are coloured by sentiment polarity
    ///     instead of the rank palette, matching the on-screen sentiment lens.
    ///   - sentimentMarks: When `true`, words are prefixed with a polarity mark
    ///     (`+`/`−`) so the sentiment lens reads without colour (A8 —
    ///     `differentiateWithoutColor`), matching the on-screen marked terms.
    /// - Returns: The encoded bytes, or `nil` when the renderer produced nothing (the caller turns
    ///   that into a user-visible failure).
    @MainActor
    static func imageData(
        terms: [TermCount],
        title: String,
        provenanceLine: ((Int) -> String)? = nil,
        format: AnalyticsFigureFormat,
        palette: [Color],
        sentimentColors: Bool = false,
        sentimentMarks: Bool = false
    ) -> Data? {
        // Leave a caption band at the bottom; lay words out above it. The provenance variant is
        // sized for a two-line title (FRUS volume titles routinely wrap) plus the facts line.
        let captionBand: CGFloat = provenanceLine == nil ? 56 : 92
        let layoutSize = CGSize(width: canvas.width, height: canvas.height - captionBand)
        let design = WordCloudSettings.fontDesign
        // A8: lay out the marked display terms so the polarity prefixes get the
        // width they render with, matching the on-screen path.
        let layoutTerms = sentimentMarks
            ? terms.map { TermCount(term: WordCloudLexicons.markedTerm($0.term), count: $0.count) }
            : terms
        let placements = WordCloudLayout.place(
            terms: layoutTerms, in: layoutSize, maxWords: maxDrawnWords, minFontSize: 16, maxFontSize: 96,
            spacingScale: WordCloudSettings.density.spacingScale, widthFactor: design.widthFactor
        )
        let content = WordCloudImageContent(
            placements: placements, title: title, size: canvas,
            captionBand: captionBand, palette: palette, sentimentColors: sentimentColors,
            fontDesign: design.swiftUIDesign, provenanceLine: provenanceLine?(placements.count)
        )

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2

        switch format {
        case .png:
            guard let cgImage = renderer.cgImage else { return nil }
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(
                data as CFMutableData, UTType.png.identifier as CFString, 1, nil
            ) else { return nil }
            CGImageDestinationAddImage(destination, cgImage, nil)
            guard CGImageDestinationFinalize(destination) else { return nil }
            return data as Data

        case .pdf:
            let data = NSMutableData()
            var wrote = false
            renderer.render { size, draw in
                var box = CGRect(origin: .zero, size: size)
                guard let consumer = CGDataConsumer(data: data as CFMutableData),
                      let pdf = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
                pdf.beginPDFPage(nil)
                draw(pdf)
                pdf.endPDFPage()
                pdf.closePDF()
                wrote = true
            }
            return wrote ? data as Data : nil
        }
    }

    /// Default colour palette for exported clouds (system colours; adapt nowhere —
    /// the export canvas is always light).
    static let palette: [Color] = [
        .blue, .teal, .indigo, .purple, .pink, .orange, .green, .red, .cyan, .mint
    ]

    /// Builds a word-cloud image from raw document texts, for embedding in
    /// collection exports. Tokenises the texts directly (no index needed) and
    /// renders to a `CGImage` plus a base64 PNG string.
    ///
    /// - Parameters:
    ///   - texts: Document body texts to analyse.
    ///   - title: Caption drawn under the cloud.
    ///   - excludeBoilerplate: Whether to drop diplomatic-boilerplate words.
    /// - Returns: The rendered `CGImage` and its base64-encoded PNG, or `nil` when
    ///   there is no usable text.
    @MainActor
    static func collectionCloudImage(
        texts: [String],
        title: String,
        excludeBoilerplate: Bool = true
    ) -> (cgImage: CGImage, pngBase64: String)? {
        let tuning = WordCloudSettings.tuning
        let tokenizer = WordCloudTokenizer.configured(
            tuning: tuning,
            includeDiplomatic: excludeBoilerplate,
            extraStopwords: WordCloudSettings.extraStopwords(for: .allTerms)
        )
        var counts: [String: Int] = [:]
        for text in texts { tokenizer.accumulate(from: text, into: &counts) }
        let terms = counts
            .filter { $0.value >= tuning.minimumCount }
            .map { TermCount(term: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.term < $1.term }
        guard !terms.isEmpty else { return nil }

        let captionBand: CGFloat = 56
        let layoutSize = CGSize(width: canvas.width, height: canvas.height - captionBand)
        let design = WordCloudSettings.fontDesign
        let placements = WordCloudLayout.place(
            terms: Array(terms.prefix(140)), in: layoutSize,
            maxWords: 140, minFontSize: 16, maxFontSize: 96,
            spacingScale: WordCloudSettings.density.spacingScale, widthFactor: design.widthFactor
        )
        let content = WordCloudImageContent(
            placements: placements, title: title, size: canvas,
            captionBand: captionBand, palette: palette,
            fontDesign: design.swiftUIDesign
        )
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let cgImage = renderer.cgImage else { return nil }

        let mutable = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutable as CFMutableData, UTType.png.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return (cgImage, (mutable as Data).base64EncodedString())
    }

}

/// Non-interactive word-cloud artwork used as the source for image exports.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
struct WordCloudImageContent: View {
    /// Pre-computed word placements (in the layout sub-rect above the caption).
    let placements: [PlacedWord]
    /// Scope title drawn in the caption band.
    let title: String
    /// Full canvas size.
    let size: CGSize
    /// Height of the bottom caption band.
    let captionBand: CGFloat
    /// Colour palette.
    let palette: [Color]
    /// When `true`, words are coloured by sentiment polarity instead of `palette`.
    var sentimentColors: Bool = false
    /// Typeface family for the rendered words (mirrors the user's cloud preference).
    var fontDesign: Font.Design = .rounded
    /// The identifying facts drawn beneath the title — scope, documents counted, app version, export
    /// date — or `nil` for a title-only band.
    ///
    /// Defaults to `nil` **deliberately**: the collection-embedded cloud
    /// (`WordCloudExporter.collectionCloudImage`) renders inside a document that carries its own
    /// provenance, so it must keep the band it has always had.
    var provenanceLine: String?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
            ForEach(placements) { word in
                Text(word.term)
                    .font(.system(size: word.fontSize, weight: .semibold, design: fontDesign))
                    .foregroundStyle(color(for: word))
                    .fixedSize()
                    .rotationEffect(.degrees(word.rotationDegrees))
                    .position(word.center)
            }
            VStack(spacing: 0) {
                Spacer()
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.black)
                            // FRUS volume titles are long enough to need a second line; without this
                            // a wrapped title squeezes the provenance line out of the band.
                            .lineLimit(2)
                        if let provenanceLine {
                            Text(provenanceLine)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.black.opacity(0.6))
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Text(verbatim: "FRUS Explorer")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 28)
                .frame(height: captionBand)
                .background(Color(white: 0.96))
            }
        }
        .frame(width: size.width, height: size.height)
    }

    /// Colour for a word: sentiment polarity when `sentimentColors` is set,
    /// otherwise the rank palette. Neutral words use a mid grey, legible on the
    /// white export canvas.
    private func color(for word: PlacedWord) -> Color {
        guard sentimentColors else { return palette[word.colorIndex % palette.count] }
        switch WordCloudLexicons.polarity(of: word.term) {
        case .positive: return .green
        case .negative: return .red
        case .none:     return Color(white: 0.4)
        }
    }
}

// `WordCloudShareSheet` and `WordCloudExportItem` were removed in D3 Phase 4. The cloud now delivers
// through `AnalyticsExportDelivery` / `AnalyticsExportShareSheet` alongside the rest of the analytics
// exports, which gets it the macOS save panel it never had, a per-export iOS temp directory instead
// of flat writes that overwrote one another, and a reported failure instead of a silent no-op.
