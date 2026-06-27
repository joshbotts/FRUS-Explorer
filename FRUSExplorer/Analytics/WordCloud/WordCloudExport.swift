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

/// A generated export artifact ready to share or save.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
struct WordCloudExportItem: Identifiable {
    /// Stable identity for `.sheet(item:)`.
    let id = UUID()
    /// Location of the written file in the temporary directory.
    let url: URL
    /// Display filename (with extension).
    let filename: String
}

/// Image output formats for a word-cloud export.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
enum WordCloudImageFormat {
    /// Rasterised PNG.
    case png
    /// Vector PDF.
    case pdf
}

/// Renders word-cloud exports (PNG, PDF, CSV) to temporary files.
///
/// Image exports use SwiftUI `ImageRenderer` over a non-interactive
/// `WordCloudImageContent`, so the exported artwork matches the on-screen cloud
/// layout. All entry points run on the main actor because `ImageRenderer` does.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
enum WordCloudExporter {

    /// Fixed export canvas size (4:3, comfortable for slides and print).
    private static let canvas = CGSize(width: 1200, height: 900)

    /// Writes a `term,count` CSV for the cloud's terms.
    ///
    /// - Parameters:
    ///   - terms: The ranked terms.
    ///   - title: Scope title, used for the filename.
    /// - Returns: The written export item, or `nil` on failure.
    static func csv(terms: [TermCount], title: String) -> WordCloudExportItem? {
        var lines = ["term,count"]
        for term in terms {
            // Quote the term and escape embedded quotes for CSV safety.
            let escaped = term.term.replacingOccurrences(of: "\"", with: "\"\"")
            lines.append("\"\(escaped)\",\(term.count)")
        }
        let csv = lines.joined(separator: "\n").appending("\n")
        let filename = "\(safeName(title)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try csv.data(using: .utf8)?.write(to: url, options: .atomic)
            return WordCloudExportItem(url: url, filename: filename)
        } catch {
            #if DEBUG
            print("[WordCloudExporter] CSV write failed: \(error)")
            #endif
            return nil
        }
    }

    /// Renders the cloud to a PNG or PDF file.
    ///
    /// - Parameters:
    ///   - terms: The ranked terms.
    ///   - title: Scope title, drawn as a caption and used for the filename.
    ///   - format: PNG or PDF.
    ///   - palette: The colour palette to draw words with.
    ///   - sentimentColors: When `true`, words are coloured by sentiment polarity
    ///     instead of the rank palette, matching the on-screen sentiment lens.
    /// - Returns: The written export item, or `nil` on failure.
    @MainActor
    static func image(
        terms: [TermCount],
        title: String,
        format: WordCloudImageFormat,
        palette: [Color],
        sentimentColors: Bool = false
    ) -> WordCloudExportItem? {
        // Leave a caption band at the bottom; lay words out above it.
        let captionBand: CGFloat = 56
        let layoutSize = CGSize(width: canvas.width, height: canvas.height - captionBand)
        let placements = WordCloudLayout.place(
            terms: terms, in: layoutSize, maxWords: 140, minFontSize: 16, maxFontSize: 96
        )
        let content = WordCloudImageContent(
            placements: placements, title: title, size: canvas,
            captionBand: captionBand, palette: palette, sentimentColors: sentimentColors
        )

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2

        switch format {
        case .png:
            guard let cgImage = renderer.cgImage else { return nil }
            let filename = "\(safeName(title)).png"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            guard let destination = CGImageDestinationCreateWithURL(
                url as CFURL, UTType.png.identifier as CFString, 1, nil
            ) else { return nil }
            CGImageDestinationAddImage(destination, cgImage, nil)
            guard CGImageDestinationFinalize(destination) else { return nil }
            return WordCloudExportItem(url: url, filename: filename)

        case .pdf:
            let filename = "\(safeName(title)).pdf"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            var wrote = false
            renderer.render { size, draw in
                var box = CGRect(origin: .zero, size: size)
                guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
                pdf.beginPDFPage(nil)
                draw(pdf)
                pdf.endPDFPage()
                pdf.closePDF()
                wrote = true
            }
            return wrote ? WordCloudExportItem(url: url, filename: filename) : nil
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
        let tokenizer = WordCloudTokenizer(
            stopwords: WordCloudStopwords.active(includeDiplomatic: excludeBoilerplate)
        )
        var counts: [String: Int] = [:]
        for text in texts { tokenizer.accumulate(from: text, into: &counts) }
        let terms = counts
            .map { TermCount(term: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.term < $1.term }
        guard !terms.isEmpty else { return nil }

        let captionBand: CGFloat = 56
        let layoutSize = CGSize(width: canvas.width, height: canvas.height - captionBand)
        let placements = WordCloudLayout.place(
            terms: Array(terms.prefix(140)), in: layoutSize,
            maxWords: 140, minFontSize: 16, maxFontSize: 96
        )
        let content = WordCloudImageContent(
            placements: placements, title: title, size: canvas,
            captionBand: captionBand, palette: palette
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

    /// Sanitises a scope title into a filesystem-safe base filename.
    private static func safeName(_ title: String) -> String {
        let base = title.isEmpty ? "word-cloud" : title
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let cleaned = String(base.unicodeScalars.filter { allowed.contains($0) })
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "-")
        return cleaned.isEmpty ? "word-cloud" : "FRUS-WordCloud-\(cleaned)"
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

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
            ForEach(placements) { word in
                Text(word.term)
                    .font(.system(size: word.fontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(color(for: word))
                    .fixedSize()
                    .rotationEffect(.degrees(word.rotationDegrees))
                    .position(word.center)
            }
            VStack(spacing: 0) {
                Spacer()
                HStack {
                    Text(title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.black)
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

/// A sheet presenting a generated export with a system share control.
///
/// Uses `ShareLink`, which presents the platform share sheet on iOS and the
/// share picker on macOS, so one implementation covers both.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
struct WordCloudShareSheet: View {
    /// The artifact to share.
    let item: WordCloudExportItem

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                Text(item.filename)
                    .font(.headline)
                    .lineLimit(1)
                ShareLink(item: item.url) {
                    Label(String(localized: "wordcloud.share.button", defaultValue: "Share…"),
                          systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(String(localized: "wordcloud.share.title", defaultValue: "Export"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done", defaultValue: "Done")) { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 280)
        #endif
    }
}
