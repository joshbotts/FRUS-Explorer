// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - CollectionToCStyle

/// Controls what label appears for each document in the collection table of contents.
///
/// Version history:
///   1.0 — Session 128: introduced alongside `CollectionExportOptions`
enum CollectionToCStyle: String, CaseIterable, Identifiable, Sendable {
    /// Use the formatted `history.state.gov`-style citation string (default).
    case citation
    /// Use the document's heading and dateline extracted from the TEI body.
    case headerAndDateline

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .citation:          return String(localized: "export.tocStyle.citation",
                                               defaultValue: "Citation")
        case .headerAndDateline: return String(localized: "export.tocStyle.headerAndDateline",
                                               defaultValue: "Header & Dateline")
        }
    }
}

// MARK: - CollectionExportOptions

// MARK: - CollectionBodyDepth

/// Controls how much of each document's body appears in a collection export.
///
/// Version history:
///   1.0 — Session 153: introduced alongside `CollectionFootnoteStyle`
enum CollectionBodyDepth: String, CaseIterable, Identifiable, Sendable {
    /// Full document body — current default. Respects the document as written.
    case full
    /// Replace the body with an AI-generated summary. Requires Apple Intelligence.
    /// Summaries are generated on demand during export if none already exist for
    /// the selected prompt. Export fails with an error if generation fails.
    case summaryOnly
    /// No body text — citation, date, and research notes only. Produces a compact
    /// reference list or briefing outline.
    case index

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .full:        return String(localized: "export.bodyDepth.full",
                                         defaultValue: "Full document")
        case .summaryOnly: return String(localized: "export.bodyDepth.summaryOnly",
                                         defaultValue: "Summary only")
        case .index:       return String(localized: "export.bodyDepth.index",
                                         defaultValue: "Index / outline")
        }
    }

    /// The body depths a user can choose given the device / AI configuration.
    /// `.summaryOnly` is gated on Apple Intelligence being available.
    @MainActor
    static var available: [CollectionBodyDepth] {
        AppleIntelligenceProvider.shared.isAvailable
            ? allCases
            : allCases.filter { $0 != .summaryOnly }
    }

    /// A document's effective body depth (Phase 3c cascade, most specific wins): the entry's
    /// own override → the section override (the nearest preceding heading's) → the collection
    /// default. Inputs are `CollectionBodyDepth` raw values; `nil` means "not set".
    static func resolve(entryOverride: String?,
                        sectionOverride: String?,
                        collectionDefault: String) -> CollectionBodyDepth {
        CollectionBodyDepth(rawValue: entryOverride ?? sectionOverride ?? collectionDefault) ?? .full
    }
}

// MARK: - CollectionFootnoteStyle

/// Controls which footnotes are included in each exported document.
///
/// Version history:
///   1.0 — Session 153: initial implementation
enum CollectionFootnoteStyle: String, CaseIterable, Identifiable, Sendable {
    /// No footnotes — body text only.
    case none
    /// Archival source note only — strips editorial/explanatory footnotes but
    /// appends a "Source:" block showing the document's archival provenance.
    case sourceNoteOnly
    /// All footnotes — current default behavior.
    case all

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:           return String(localized: "export.footnoteStyle.none",
                                            defaultValue: "None")
        case .sourceNoteOnly: return String(localized: "export.footnoteStyle.sourceNoteOnly",
                                            defaultValue: "Source note only")
        case .all:            return String(localized: "export.footnoteStyle.all",
                                            defaultValue: "All footnotes")
        }
    }
}

// MARK: - ExportHighlight

/// A snapshot of one `DocumentHighlight` used by exporters to annotate the
/// document body. Carries flat-text character offsets (same coordinate space as
/// `DocumentHighlight.startOffset`/`endOffset`) and the highlight colour.
///
/// Version history:
///   1.0 — Session 153: initial implementation
struct ExportHighlight: Sendable {
    let startOffset: Int
    let endOffset:   Int
    let color:       DocumentHighlight.Color
}

// MARK: - HighlightPaintTracker

/// Walks exported text in flat-text traversal order, partitioning each chunk into
/// maximal left-to-right sub-ranges that share the same overlapping `ExportHighlight`
/// colour (or no highlight at all). Shared by `PDFCollectionExporter` and
/// `DocxCollectionExporter` so both formats annotate inline highlights using the
/// same flat-text coordinate space as `buildFlatText` and
/// `FRUSRenderNodeHTMLSerializer.injectHighlights`.
///
/// ## Usage contract
/// Callers must invoke `partition(_:)` exactly once, in left-to-right traversal
/// order, for every chunk of text that contributes to the document's flat text —
/// i.e. the same leaf content `appendFlatText` counts (`.plainText`, `.formulaText`,
/// and `.lineBreak` content). Structural separators that `appendFlatText` does not
/// count (list bullets, table-cell join strings, footnote labels, figure captions,
/// paragraph spacing, etc.) must NOT be passed to `partition(_:)`, or the internal
/// position counter will drift out of alignment with the stored offsets. Each call
/// advances that counter by `text.count` (Unicode scalar count, matching
/// `DocumentHighlight.startOffset`/`endOffset`).
///
/// Overlapping highlights are resolved by preferring the one that opens first,
/// mirroring `FRUSRenderNodeHTMLSerializer.injectHighlights`.
///
/// Version history:
///   1.0 — Future (unnumbered): PDF/DOCX inline highlight annotation
final class HighlightPaintTracker {
    private let sorted: [ExportHighlight]
    private var flatPos = 0

    init(_ highlights: [ExportHighlight]) {
        sorted = highlights.sorted { $0.startOffset < $1.startOffset }
    }

    /// `true` when there is at least one highlight to annotate. Callers may use
    /// this as a fast-path check to skip partitioning work entirely.
    var isActive: Bool { !sorted.isEmpty }

    /// Partitions `text` into maximal left-to-right sub-ranges sharing the same
    /// highlight colour (`color == nil` means unhighlighted), and advances the
    /// flat-text position counter by `text.count`.
    ///
    /// - Returns: An ordered, non-overlapping list of `(range, color)` pairs whose
    ///   ranges concatenate to cover all of `text`. When inactive or `text` is
    ///   empty, returns the whole string as a single unhighlighted span.
    func partition(_ text: String) -> [(range: Range<String.Index>, color: DocumentHighlight.Color?)] {
        let chunkStart = flatPos
        let chunkLen = text.count
        flatPos += chunkLen

        guard isActive, chunkLen > 0 else {
            return [(text.startIndex..<text.endIndex, nil)]
        }

        // Collect every highlight start/end boundary that falls strictly inside
        // this chunk — those are the only points where the active colour can change.
        var boundaries = Set<Int>([0, chunkLen])
        for hl in sorted {
            let s = hl.startOffset - chunkStart
            let e = hl.endOffset - chunkStart
            if s > 0, s < chunkLen { boundaries.insert(s) }
            if e > 0, e < chunkLen { boundaries.insert(e) }
        }
        let cuts = boundaries.sorted()

        var spans: [(Range<String.Index>, DocumentHighlight.Color?)] = []
        spans.reserveCapacity(cuts.count - 1)
        for i in 0..<(cuts.count - 1) {
            let localStart = cuts[i], localEnd = cuts[i + 1]
            guard localStart < localEnd,
                  let startIdx = text.index(text.startIndex, offsetBy: localStart, limitedBy: text.endIndex),
                  let endIdx = text.index(text.startIndex, offsetBy: localEnd, limitedBy: text.endIndex)
            else { continue }
            // Probe the midpoint-equivalent (the span start) to find the
            // overlapping highlight, preferring the earliest-opening one.
            let probe = chunkStart + localStart
            let color = sorted.first { $0.startOffset <= probe && probe < $0.endOffset }?.color
            spans.append((startIdx..<endIdx, color))
        }
        return spans
    }
}

// MARK: - CollectionExportOptions

/// Rendering options passed to every exporter.
///
/// Version history:
///   1.0 — Session 128: initial implementation
///   1.1 — Session 153: added `bodyDepth`, `footnoteStyle`, `applyHighlights`,
///          `includeNotes`, and `summaryPromptId`
///   1.2 — Collections rework Phase 1b: `bodyDepth` moved to per-document
///          `CollectionExportDocument.bodyDepth` (per-entry override); removed here
struct CollectionExportOptions: Sendable {
    /// Which label style to use in the table of contents.
    var tocStyle: CollectionToCStyle = .citation
    /// Which footnotes to include per document.
    var footnoteStyle: CollectionFootnoteStyle = .all
    /// When `true`, inline user highlights are annotated in the document body.
    /// Implemented for all three export formats: HTML (`FRUSRenderNodeHTMLSerializer.injectHighlights`),
    /// PDF (`PDFCollectionExporter.drawFrameWithHighlights`), and DOCX
    /// (`DocxCollectionExporter.runsXML(for:props:tracker:)`).
    var applyHighlights: Bool = false
    /// When `true`, attached research notes appear below each document body.
    /// Default `true`; set `false` for a clean primary-source reader.
    var includeNotes: Bool = true
    /// The `SummarizationPrompt.id` to use when `bodyDepth == .summaryOnly`.
    /// Summaries are generated on demand if none exist for this prompt.
    var summaryPromptId: UUID? = nil
    /// When `true`, a word-cloud overview page/section of the collection's most
    /// frequent terms is included. Supported by the PDF and HTML exporters.
    var includeWordCloud: Bool = false
}

// MARK: - ExportFormat

/// Supported output formats for collection export.
///
/// Version history:
///   1.0 — Session 22: initial implementation
///   1.1 — Session 82: added `.docx` backed by `DocxCollectionExporter`
///   1.2 — Session 155: added `.zoteroJSON` backed by `ZoteroCollectionExporter`
///          (Zotero JSON exchange format, one item per document)
///   1.3 — Session 164: `.zoteroJSON` now emits RIS (`.ris`)
///   1.4 — Zotero strategy: `.zoteroJSON` (RIS) is the **Zotero desktop**
///          fallback only — iOS Zotero has no RIS import. The annotation-
///          preserving path on both platforms is the Zotero Web API (separate).
///   1.5 — Collections rework Phase 4 (D7): added `.bibtex` (`.bib`) backed by
///          `BibTeXCollectionExporter`, for LaTeX / non-Zotero reference managers.
///   1.6 — Collections rework Phase 4 (D9): added `.fruscollection` — the native,
///          round-trippable collection file. It is not a `CollectionExporter` (it
///          serializes the collection's *source* via `NativeCollectionSerializer`), so
///          `makeExporter()` returns `nil` for it and the export flow special-cases it.
enum ExportFormat: String, CaseIterable, Identifiable {
    case pdf
    case html
    case docx
    case zoteroJSON
    case bibtex
    case fruscollection

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pdf:        return "PDF"
        case .html:       return "HTML"
        case .docx:       return "DOCX"
        case .zoteroJSON: return String(localized: "export.format.zotero",
                                        defaultValue: "Zotero RIS (desktop)")
        case .bibtex:     return String(localized: "export.format.bibtex",
                                        defaultValue: "BibTeX")
        case .fruscollection: return String(localized: "export.format.native",
                                            defaultValue: "FRUS Collection (shareable)")
        }
    }

    var fileExtension: String {
        switch self {
        case .zoteroJSON:     return "ris"
        case .bibtex:         return "bib"
        case .fruscollection: return NativeCollectionSerializer.fileExtension
        default:              return rawValue
        }
    }

    /// Returns a fresh exporter instance for this format, or `nil` for `.fruscollection`,
    /// which is produced by `NativeCollectionSerializer` (it serializes the collection's
    /// source rather than rendering resolved content) and handled directly by the export flow.
    func makeExporter() -> (any CollectionExporter)? {
        switch self {
        case .pdf:            return PDFCollectionExporter()
        case .html:           return HTMLCollectionExporter()
        case .docx:           return DocxCollectionExporter()
        case .zoteroJSON:     return ZoteroCollectionExporter()
        case .bibtex:         return BibTeXCollectionExporter()
        case .fruscollection: return nil
        }
    }
}

// MARK: - CollectionExportDocument

/// A pre-resolved document payload used by exporters.
///
/// The caller (typically `CollectionEditorView`) resolves titles, dates, body
/// text, and optional note text before handing off to an exporter. Exporters
/// are pure data consumers and perform no I/O other than writing the output file.
///
/// `renderModel` carries structured render-node output for rich formatting.
/// When non-nil, HTML and PDF exporters emit structured output (headings,
/// datelines, footnotes, emphasis); when nil they fall back to the flat
/// `bodyText` string.
///
/// Version history:
///   1.0 — Session 22: initial implementation
///   1.1 — Session 73: added `citation` (formatted citation string) and `historyStateGovURL`
///          fields with empty-string defaults; both included in PDF and HTML exports
///   1.2 — Session 81: added `renderModel: FRUSDocumentRenderModel?` for rich export output;
///          flat-text fallback preserved when render model is unavailable
///   1.3 — Session 128: added `header`, `dateline` (for headerAndDateline ToC style);
///          replaced single `noteText` with `noteTexts: [String]` (multi-note per entry);
///          added `includeDocumentBody: Bool`; `noteText` retained as computed backward-compat accessor
///   1.4 — Session 155: added `zoteroItem: ZoteroJSONExporter.Item?` for `.zoteroJSON` export
struct CollectionExportDocument: Sendable {
    /// The FRUS document identifier (e.g. `"d1"`).
    let documentId: String
    /// The containing volume identifier (e.g. `"frus1969-76v01"`).
    let volumeId: String
    /// Position within the collection (ascending).
    let sortOrder: Int
    /// How much of this document's body to render — the per-entry effective depth
    /// (`CollectionEntry.bodyDepthOverride`, else the collection's `defaultBodyDepth`).
    /// Exporters switch on this per document, so one collection can mix full documents,
    /// summaries, and citation-only entries.
    let bodyDepth: CollectionBodyDepth
    /// Human-readable document title (volume title + document ID).
    let title: String
    /// ISO 8601 date string, if known.
    let date: String?
    /// Plain-text body of the document. Preserved as fallback when `renderModel` is nil.
    let bodyText: String
    /// Research note texts linked to this entry (one per linked `ResearchNote`).
    let noteTexts: [String]
    /// Formatted citation string (history.state.gov style).
    let citation: String
    /// `https://history.state.gov/historicaldocuments/{volumeId}/{documentId}`
    let historyStateGovURL: String
    /// Fully converted render model for structured export output.
    /// Non-nil when the volume XML was successfully parsed during collection assembly.
    let renderModel: FRUSDocumentRenderModel?
    /// The document heading extracted from the TEI body (e.g. `"1. Memorandum From…"`).
    let header: String
    /// The dateline extracted from the TEI body.
    let dateline: String?
    /// AI-generated summary text for this document. Populated when
    /// `options.bodyDepth == .summaryOnly`; `nil` otherwise.
    let summaryText: String?
    /// User highlights to annotate inline in the body. Populated when
    /// `options.applyHighlights == true`; empty otherwise.
    let highlights: [ExportHighlight]
    /// Raw archival source note text. Populated when
    /// `options.footnoteStyle == .sourceNoteOnly`; `nil` otherwise.
    let sourceNoteText: String?
    /// Pre-built Zotero JSON item for `.zoteroJSON` export. `nil` if volume
    /// metadata was unavailable when this document was resolved.
    let zoteroItem: ZoteroJSONExporter.Item?

    /// Backward-compatible single-note accessor.
    var noteText: String? { noteTexts.first }

    /// Returns the ToC label appropriate for the given display style.
    func tocLabel(style: CollectionToCStyle) -> String {
        switch style {
        case .citation:
            return citation.isEmpty ? title : citation
        case .headerAndDateline:
            guard !header.isEmpty else { return citation.isEmpty ? title : citation }
            if let dl = dateline, !dl.isEmpty { return "\(header) — \(dl)" }
            return header
        }
    }

    init(
        documentId: String,
        volumeId: String,
        sortOrder: Int,
        bodyDepth: CollectionBodyDepth = .full,
        title: String,
        date: String? = nil,
        bodyText: String,
        noteText: String? = nil,
        noteTexts: [String]? = nil,
        citation: String = "",
        historyStateGovURL: String = "",
        renderModel: FRUSDocumentRenderModel? = nil,
        header: String = "",
        dateline: String? = nil,
        summaryText: String? = nil,
        highlights: [ExportHighlight] = [],
        sourceNoteText: String? = nil,
        zoteroItem: ZoteroJSONExporter.Item? = nil
    ) {
        self.documentId = documentId
        self.volumeId = volumeId
        self.sortOrder = sortOrder
        self.bodyDepth = bodyDepth
        self.title = title
        self.date = date
        self.bodyText = bodyText
        if let noteTexts {
            self.noteTexts = noteTexts
        } else if let noteText {
            self.noteTexts = [noteText]
        } else {
            self.noteTexts = []
        }
        self.citation = citation
        self.historyStateGovURL = historyStateGovURL
        self.renderModel = renderModel
        self.header = header
        self.dateline = dateline
        self.summaryText = summaryText
        self.highlights = highlights
        self.sourceNoteText = sourceNoteText
        self.zoteroItem = zoteroItem
    }

    /// Returns a copy of this document with `summaryText` set — used after on-demand
    /// summary generation, which only runs for entries whose effective `bodyDepth`
    /// is `.summaryOnly`. All other fields (including `bodyDepth`) are preserved.
    func withSummary(_ text: String) -> CollectionExportDocument {
        CollectionExportDocument(
            documentId: documentId, volumeId: volumeId, sortOrder: sortOrder,
            bodyDepth: bodyDepth, title: title, date: date, bodyText: bodyText,
            noteTexts: noteTexts, citation: citation, historyStateGovURL: historyStateGovURL,
            renderModel: renderModel, header: header, dateline: dateline,
            summaryText: text, highlights: highlights, sourceNoteText: sourceNoteText,
            zoteroItem: zoteroItem)
    }
}

// MARK: - CollectionExportMetadata

/// Sendable snapshot of a `Collection`'s display properties for use by exporters.
///
/// Extracted from the SwiftData model before crossing async boundaries so that
/// exporters can run without holding a reference to the `@MainActor`-bound model.
///
/// Version history:
///   1.0 — Session 32: introduced to satisfy Swift 6 Sendable requirements
struct CollectionExportMetadata: Sendable {
    let name: String
    let note: String?
}

// MARK: - CollectionExportItem

/// One item in a composed collection export: a resolved document, a section heading, or an
/// editorial prose block. Exporters render an ordered `[CollectionExportItem]`, so a
/// collection can be an authored, sectioned reader rather than a flat document list (Phase 3a).
enum CollectionExportItem: Sendable {
    /// A FRUS document, fully resolved.
    case document(CollectionExportDocument)
    /// A section heading (the title text).
    case heading(String)
    /// An editorial prose block, as **RTF** data (Phase 3b). Exporters decode it to an
    /// `NSAttributedString` to render bold/italic/underline/colour, or read its `.string` for
    /// the plain-text projection. `Data` (unlike `NSAttributedString`) is `Sendable`.
    case prose(Data)
}

extension Array where Element == CollectionExportItem {
    /// The `.document` payloads, in order (heading/prose items dropped). Used where an
    /// exporter needs the documents alone — e.g. the collection word cloud.
    var documents: [CollectionExportDocument] {
        compactMap { if case .document(let doc) = $0 { return doc } else { return nil } }
    }
}

// MARK: - ProseFormattedSpan

/// One run of editorial-prose text plus the concrete inline formatting decoded from a
/// Phase 3b rich-text blob. Bold/italic come from the run's `NSFont`/`UIFont` symbolic
/// traits, underline from the underline-style attribute, and `colorHex` from the
/// foreground colour. Produced by `CollectionProse.paragraphs(fromRTF:)`.
struct ProseFormattedSpan: Sendable {
    /// The run's text. May contain single `\n` line breaks; paragraph breaks (blank
    /// lines) are already split out into separate paragraphs by the decoder.
    let text: String
    /// `true` when the run's font carries the bold symbolic trait.
    let bold: Bool
    /// `true` when the run's font carries the italic symbolic trait.
    let italic: Bool
    /// `true` when the run carries a non-zero underline style.
    let underline: Bool
    /// Uppercase `RRGGBB` (no leading `#`), or `nil` for (near-)black default text so
    /// ordinary prose isn't tagged with a redundant colour.
    let colorHex: String?
}

// MARK: - CollectionProse

/// Shared decoder that turns a rich-text prose block — supplied as **RTF** `Data`
/// (as carried by `CollectionExportItem.prose`) — into paragraphs of `ProseFormattedSpan`,
/// so every exporter (HTML, DOCX, PDF) reads prose formatting through one code path and
/// cannot drift. Blank lines (`"\n\n"`) split paragraphs; each paragraph is an ordered list
/// of spans covering its text.
///
/// **Data-loss guard.** A payload that fails the RTF decode is *not* dropped: a legacy
/// Phase 3b blob (the `AttributedString`'s own JSON `Codable` encoding, written before the
/// RTF switch and still reachable via CloudKit sync or `.fruscollection` files) is decoded
/// directly, with bold/italic recovered from `inlinePresentationIntent`. Only data that is
/// neither format yields `[]` — and `ProseRichText.exportRTF(from:)` never emits such a
/// payload, falling back to the entry's plain `text` instead.
enum CollectionProse {
    /// Decodes `rtf` into paragraphs of formatted spans, resolving paragraph breaks *before*
    /// spans are emitted so callers never straddle a paragraph boundary with a single run.
    /// Falls back to the legacy Phase 3b JSON `AttributedString` encoding when the RTF
    /// decode fails (see the type doc), so pre-RTF prose still renders in every exporter.
    ///
    /// - Returns: One inner array per paragraph; empty (`[]`) when the data is empty or is
    ///   decodable as neither RTF nor the legacy JSON encoding.
    static func paragraphs(fromRTF rtf: Data) -> [[ProseFormattedSpan]] {
        if let ns = ProseRichText.decodedRTF(rtf) {
            return ns.length > 0 ? paragraphs(fromDecoded: ns) : []
        }
        if let legacy = ProseRichText.legacyJSONAttributedString(rtf) {
            return paragraphs(fromLegacy: legacy)
        }
        return []
    }

    /// Emits spans for a decoded RTF body: bold/italic from the run's concrete font traits,
    /// underline from the underline-style attribute, colour from the foreground colour.
    private static func paragraphs(fromDecoded ns: NSAttributedString) -> [[ProseFormattedSpan]] {
        var paragraphs: [[ProseFormattedSpan]] = [[]]
        let plain = ns.string as NSString
        ns.enumerateAttributes(in: NSRange(location: 0, length: ns.length), options: []) { attrs, range, _ in
            var bold = false, italic = false, underline = false
            var colorHex: String?
            #if canImport(AppKit)
            if let font = attrs[.font] as? NSFont {
                let traits = font.fontDescriptor.symbolicTraits
                bold = traits.contains(.bold); italic = traits.contains(.italic)
            }
            if let color = attrs[.foregroundColor] as? NSColor { colorHex = hexColor(color) }
            #elseif canImport(UIKit)
            if let font = attrs[.font] as? UIFont {
                let traits = font.fontDescriptor.symbolicTraits
                bold = traits.contains(.traitBold); italic = traits.contains(.traitItalic)
            }
            if let color = attrs[.foregroundColor] as? UIColor { colorHex = hexColor(color) }
            #endif
            if let style = attrs[.underlineStyle] as? Int, style != 0 { underline = true }

            append(text: plain.substring(with: range), bold: bold, italic: italic,
                   underline: underline, colorHex: colorHex, to: &paragraphs)
        }
        return paragraphs
    }

    /// Emits spans for a legacy Phase 3b body: bold/italic from each run's Foundation
    /// `inlinePresentationIntent` (the only formatting that encoding carried — Phase 3b had
    /// no underline or colour affordances).
    private static func paragraphs(fromLegacy attributed: AttributedString) -> [[ProseFormattedSpan]] {
        guard !attributed.characters.isEmpty else { return [] }
        var paragraphs: [[ProseFormattedSpan]] = [[]]
        for run in attributed.runs {
            let intent = run.inlinePresentationIntent ?? []
            append(text: String(attributed.characters[run.range]),
                   bold: intent.contains(.stronglyEmphasized),
                   italic: intent.contains(.emphasized),
                   underline: false, colorHex: nil, to: &paragraphs)
        }
        return paragraphs
    }

    /// Splits one formatted run on blank lines (`"\n\n"`) and appends the resulting spans,
    /// starting a new paragraph at each blank line — the single splitting rule both decode
    /// paths share.
    private static func append(text: String, bold: Bool, italic: Bool, underline: Bool,
                               colorHex: String?, to paragraphs: inout [[ProseFormattedSpan]]) {
        let parts = text.components(separatedBy: "\n\n")
        for (index, part) in parts.enumerated() {
            if index > 0 { paragraphs.append([]) }   // a blank line starts a new paragraph
            if !part.isEmpty {
                paragraphs[paragraphs.count - 1].append(
                    ProseFormattedSpan(text: part, bold: bold, italic: italic,
                                       underline: underline, colorHex: colorHex))
            }
        }
    }

    // MARK: - Colour helpers

    #if canImport(AppKit)
    /// `RRGGBB` for a colour, or `nil` for (near-)black default text.
    private static func hexColor(_ color: NSColor) -> String? {
        guard let c = color.usingColorSpace(.sRGB) else { return nil }
        return hex(r: c.redComponent, g: c.greenComponent, b: c.blueComponent)
    }
    #elseif canImport(UIKit)
    /// `RRGGBB` for a colour, or `nil` for (near-)black default text.
    private static func hexColor(_ color: UIColor) -> String? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return hex(r: r, g: g, b: b)
    }
    #endif

    /// Formats an RGB triple as uppercase `RRGGBB`, returning `nil` for (near-)black so
    /// ordinary prose isn't tagged with a redundant colour.
    private static func hex(r: CGFloat, g: CGFloat, b: CGFloat) -> String? {
        if r < 0.08, g < 0.08, b < 0.08 { return nil }   // (near-)black default text
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - CollectionExporter

/// Protocol for turning a `CollectionExportMetadata` + its ordered items into a file on disk.
///
/// Implementations must write their output to a temporary URL and return it.
/// The caller is responsible for presenting a share sheet or saving the file.
///
/// All methods are `async` to accommodate I/O and rendering work.
///
/// Version history:
///   1.0 — Session 22: initial implementation
///   1.1 — Session 32: replaced `Collection` parameter with `CollectionExportMetadata`
///   1.2 — Session 73: `export()` marked `@MainActor` to satisfy CoreGraphics/CoreText
///          thread-safety requirements; previously crashed when called off the main thread
///   1.3 — Session 128: `options: CollectionExportOptions` parameter added; backward-compat
///          no-options overload provided via protocol extension
///   1.4 — Collections rework Phase 3a: primary parameter is now an ordered
///          `[CollectionExportItem]` (documents + headings + prose); a `documents:`
///          convenience overload wraps a flat document list as `.document` items
protocol CollectionExporter {
    /// Exports `metadata` and its ordered `items` to a temporary file using the given `options`.
    ///
    /// - Returns: A `file://` URL pointing to the written output.
    /// - Throws: `ExportError` on rendering or I/O failure.
    @MainActor
    func export(
        metadata: CollectionExportMetadata,
        items: [CollectionExportItem],
        options: CollectionExportOptions
    ) async throws -> URL
}

extension CollectionExporter {
    /// Convenience: export a flat list of documents, wrapped as `.document` items.
    @MainActor
    func export(
        metadata: CollectionExportMetadata,
        documents: [CollectionExportDocument],
        options: CollectionExportOptions = CollectionExportOptions()
    ) async throws -> URL {
        try await export(metadata: metadata, items: documents.map { .document($0) }, options: options)
    }

    /// Backward-compatible overload that uses default `CollectionExportOptions`.
    @MainActor
    func export(
        metadata: CollectionExportMetadata,
        items: [CollectionExportItem]
    ) async throws -> URL {
        try await export(metadata: metadata, items: items, options: CollectionExportOptions())
    }
}

// MARK: - ExportError

enum ExportError: Error, LocalizedError {
    case renderingFailed
    case writeFailure(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .renderingFailed:
            return String(localized: "export.error.rendering",
                          defaultValue: "The export could not be rendered.")
        case .writeFailure(let e):
            return String(localized: "export.error.write",
                          defaultValue: "Could not write export file: \(e.localizedDescription)")
        }
    }
}
