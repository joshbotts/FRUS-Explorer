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

    /// A short label for the compact override chip on a document row (Composer redesign 3):
    /// "Full" / "Summary" / "Index" — briefer than `displayName`, which labels full controls.
    var chipLabel: String {
        switch self {
        case .full:        return String(localized: "collection.entry.chip.bodyDepth.full",
                                         defaultValue: "Full")
        case .summaryOnly: return String(localized: "collection.entry.chip.bodyDepth.summary",
                                         defaultValue: "Summary")
        case .index:       return String(localized: "collection.entry.chip.bodyDepth.index",
                                         defaultValue: "Index")
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
/// **Legacy vocabulary (Authoring Phase 5).** The tri-state is superseded by the
/// `Collection.includeFootnotes`/`includeSourceNote` Bool pair (which can express
/// "all footnotes AND the source note"); the enum remains the raw-value vocabulary of
/// the synced `Collection.footnoteStyle` field, which keeps being written for old
/// readers, and of `.fruscollection` files. New code reads the collection's
/// `effectiveIncludeFootnotes`/`effectiveIncludeSourceNote` instead.
///
/// Version history:
///   1.0 — Session 153: initial implementation
///   1.1 — Authoring Phase 5: demoted to the legacy raw-value vocabulary (see above)
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
///   1.3 — Authoring Phase 5: `footnoteStyle` replaced by the `includeFootnotes` +
///          `includeSourceNote` Bool pair (both now expressible together). Callers build
///          these from `Collection.effectiveIncludeFootnotes`/`effectiveIncludeSourceNote`,
///          whose nil-pair derivation reproduces each legacy tri-state value exactly
struct CollectionExportOptions: Sendable {
    /// Which label style to use in the table of contents.
    var tocStyle: CollectionToCStyle = .citation
    /// When `true`, document footnotes are rendered where footnote rendering is gated
    /// (the shared HTML renderer / live preview). Defaults to `true` — the legacy
    /// `.all` behavior. (The PDF/DOCX exporters have never gated footnotes on the old
    /// tri-state; that pre-existing behavior is deliberately unchanged so untouched
    /// collections keep exporting byte-identically.)
    var includeFootnotes: Bool = true
    /// When `true`, the resolver fetches each document's archival source note and every
    /// format appends a "Source:" block. Defaults to `false` — pre-Phase-5, only the
    /// legacy `.sourceNoteOnly` style resolved it.
    var includeSourceNote: Bool = false
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
    /// The collection-level default a document entry's `includeHeadnote == nil` (Default) resolves
    /// to (Composer redesign). `false` by default, so collections that never set a headnote default
    /// resolve exactly as before. Set from `Collection.defaultIncludeHeadnote`.
    var includeHeadnoteDefault: Bool = false
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
///   1.5 — Authoring Phase 5: added `includeHeadnote` + `headnoteText` (an opt-in italic
///          abstract above the body; a requested headnote with no stored summary renders
///          a placeholder note — headnote generation-on-demand is out of scope)
///   1.6 — Authoring Phase 5 (overrides): added the resolved per-entry override trio
///          `applyHighlightsOverride`/`includeNotesOverride`/`includeFootnotesOverride`
///          (nil = inherit `options`, so renderers gate on `doc.x ?? options.x`),
///          `summaryPromptIdOverride` (the effective prompt for `.summaryOnly`
///          generation/lookup), and `relatedDocumentCitations` — the pre-resolved
///          "See also:" line (decision A10). Carried on the document payload rather
///          than a new `CollectionExportItem` case so the exporter contract is
///          unchanged and every format renders the line inside the document section
///          it belongs to. All defaulted, so existing construction sites — and every
///          untouched collection — render byte-identically
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
    /// The user's per-entry title override (M3, D4). `nil`/empty uses the derived heading
    /// (`exportHeading`). A non-empty value replaces **both** the ToC label (`tocLabel`,
    /// for both styles) and the top-of-document export heading. Defaulted `nil` at every
    /// construction site so untouched exports stay byte-identical.
    let titleOverride: String?
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
    /// `options.includeSourceNote == true`; `nil` otherwise.
    let sourceNoteText: String?
    /// Whether this entry requested a headnote (Authoring Phase 5). When `true` and
    /// `headnoteText` is empty/nil, renderers emit a placeholder note instead — the
    /// resolver never generates a summary for a headnote.
    let includeHeadnote: Bool
    /// The resolved headnote text — the chosen (or fallback) stored `GeneratedSummary`.
    /// Rendered as an italic abstract above the body when `includeHeadnote` is `true`.
    let headnoteText: String?
    /// The headnote summary's provenance (Composer redesign) — drives the export attribution so a
    /// user-edited/-written headnote is not labeled "AI-generated". `.aiGenerated` when no headnote.
    let headnoteAuthorship: SummaryAuthorship
    /// The entry/section highlight override resolved by the cascade (Authoring Phase 5).
    /// `nil` = inherit — renderers gate inline highlights on
    /// `applyHighlightsOverride ?? options.applyHighlights`, so the default reproduces
    /// the collection-level behavior exactly.
    let applyHighlightsOverride: Bool?
    /// The entry/section research-notes override resolved by the cascade (Phase 5).
    /// `nil` = inherit — renderers gate note blocks on
    /// `includeNotesOverride ?? options.includeNotes`.
    let includeNotesOverride: Bool?
    /// The entry/section footnote override resolved by the cascade (Phase 5). `nil` =
    /// inherit — every renderer (the shared HTML renderer / preview, PDF, and DOCX —
    /// the latter two gated since the 2026-07-03 owner decision) gates footnote bodies
    /// on `includeFootnotesOverride ?? options.includeFootnotes`.
    let includeFootnotesOverride: Bool?
    /// The entry/section summary-prompt override resolved by the cascade (Phase 5).
    /// `nil` = inherit the collection's `summaryPromptId`. Drives which prompt's stored
    /// summary attaches (preview) or generates (export) for a `.summaryOnly` body, and
    /// the headnote fallback pick.
    let summaryPromptIdOverride: UUID?
    /// The resolved "See also:" citations (decision A10, Authoring Phase 5): documents
    /// this one cross-references that are **also in the collection**, in collection
    /// order, deduplicated, self excluded. Empty (the default, and whenever the entry's
    /// `includeRelatedDocuments` resolves off) renders nothing — untouched collections
    /// are byte-identical.
    let relatedDocumentCitations: [String]
    /// Pre-built Zotero JSON item for `.zoteroJSON` export. `nil` if volume
    /// metadata was unavailable when this document was resolved.
    let zoteroItem: ZoteroJSONExporter.Item?

    /// Backward-compatible single-note accessor.
    var noteText: String? { noteTexts.first }

    /// The top-of-document export heading (M3, D4): the user's `titleOverride` when
    /// non-empty, else the citation (or `title` when no citation). The single centralizer
    /// so the three exporters (HTML/PDF/DOCX) stay in lockstep — each renders this instead
    /// of re-deriving `citation.isEmpty ? title : citation`.
    var exportHeading: String {
        if let override = titleOverride, !override.isEmpty { return override }
        return citation.isEmpty ? title : citation
    }

    /// Returns the ToC label appropriate for the given display style. A non-empty
    /// `titleOverride` wins first for **both** styles (M3, D4), so the ToC label and the
    /// export heading name the document identically.
    func tocLabel(style: CollectionToCStyle) -> String {
        if let override = titleOverride, !override.isEmpty { return override }
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
        titleOverride: String? = nil,
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
        includeHeadnote: Bool = false,
        headnoteText: String? = nil,
        headnoteAuthorship: SummaryAuthorship = .aiGenerated,
        applyHighlightsOverride: Bool? = nil,
        includeNotesOverride: Bool? = nil,
        includeFootnotesOverride: Bool? = nil,
        summaryPromptIdOverride: UUID? = nil,
        relatedDocumentCitations: [String] = [],
        zoteroItem: ZoteroJSONExporter.Item? = nil
    ) {
        self.documentId = documentId
        self.volumeId = volumeId
        self.sortOrder = sortOrder
        self.bodyDepth = bodyDepth
        self.title = title
        self.titleOverride = titleOverride
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
        self.includeHeadnote = includeHeadnote
        self.headnoteText = headnoteText
        self.headnoteAuthorship = headnoteAuthorship
        self.applyHighlightsOverride = applyHighlightsOverride
        self.includeNotesOverride = includeNotesOverride
        self.includeFootnotesOverride = includeFootnotesOverride
        self.summaryPromptIdOverride = summaryPromptIdOverride
        self.relatedDocumentCitations = relatedDocumentCitations
        self.zoteroItem = zoteroItem
    }

    /// Returns a copy of this document with `summaryText` set — used after on-demand
    /// summary generation, which only runs for entries whose effective `bodyDepth`
    /// is `.summaryOnly`. All other fields (including `bodyDepth`) are preserved.
    func withSummary(_ text: String) -> CollectionExportDocument {
        CollectionExportDocument(
            documentId: documentId, volumeId: volumeId, sortOrder: sortOrder,
            bodyDepth: bodyDepth, title: title, titleOverride: titleOverride,
            date: date, bodyText: bodyText,
            noteTexts: noteTexts, citation: citation, historyStateGovURL: historyStateGovURL,
            renderModel: renderModel, header: header, dateline: dateline,
            summaryText: text, highlights: highlights, sourceNoteText: sourceNoteText,
            includeHeadnote: includeHeadnote, headnoteText: headnoteText,
            applyHighlightsOverride: applyHighlightsOverride,
            includeNotesOverride: includeNotesOverride,
            includeFootnotesOverride: includeFootnotesOverride,
            summaryPromptIdOverride: summaryPromptIdOverride,
            relatedDocumentCitations: relatedDocumentCitations,
            zoteroItem: zoteroItem)
    }
}

// MARK: - CollectionExportMetadata

/// Sendable snapshot of a `Collection`'s display properties for use by exporters.
///
/// Extracted from the SwiftData model before crossing async boundaries so that
/// exporters can run without holding a reference to the `@MainActor`-bound model.
///
/// The Phase 4 title-page fields (`subtitle`, `authorLine`) and the colophon opt-in are
/// **metadata-driven rendering**, not export items: they are frame furniture with fixed
/// positions (title block leading, colophon trailing) derived from `Collection` fields,
/// so `[CollectionExportItem]` stays a pure content stream and the byte-compat guarantee
/// is provable per renderer — every unset field renders exactly the pre-Phase-4 output.
///
/// Version history:
///   1.0 — Session 32: introduced to satisfy Swift 6 Sendable requirements
///   1.1 — Authoring Phase 4: `subtitle`, `authorLine`, `includeColophon` (defaulted so
///          every existing construction site and no-frame collection is unchanged)
struct CollectionExportMetadata: Sendable {
    /// The collection's display name — the export title.
    let name: String
    /// Optional one-line description rendered under the title (pre-Phase-4 behavior).
    let note: String?
    /// Optional title-page subtitle (Authoring Phase 4). `nil`/empty renders nothing,
    /// keeping the export header byte-identical to pre-Phase-4 output.
    let subtitle: String?
    /// Optional title-page author/byline (Authoring Phase 4). `nil`/empty renders nothing.
    let authorLine: String?
    /// When `true`, renderers append a trailing colophon (`CollectionColophon`).
    /// Defaults to `false`, so collections that never opt in export exactly as today.
    let includeColophon: Bool

    /// Creates a metadata snapshot. The Phase 4 parameters default to "feature unused"
    /// so pre-Phase-4 call sites compile — and render — unchanged.
    init(name: String, note: String?, subtitle: String? = nil,
         authorLine: String? = nil, includeColophon: Bool = false) {
        self.name = name
        self.note = note
        self.subtitle = subtitle
        self.authorLine = authorLine
        self.includeColophon = includeColophon
    }
}

// MARK: - CollectionColophon

/// Shared colophon text builder (Authoring Phase 4) — the single source for the trailing
/// "how this artifact was produced" line, so HTML, PDF, and DOCX cannot drift. Rendered
/// only when `CollectionExportMetadata.includeColophon` is set.
///
/// Version history:
///   1.0 — Authoring Phase 4: initial implementation
enum CollectionColophon {
    /// The colophon line for a resolved item list: app attribution, document/volume
    /// counts, and the compilation date.
    ///
    /// - Parameters:
    ///   - items: The resolved items whose `.document` payloads are counted.
    ///   - date: The compilation date (defaults to now; injectable for tests).
    /// - Returns: A single localized colophon line.
    static func text(for items: [CollectionExportItem], date: Date = Date()) -> String {
        let docs = items.documents
        let docCount = docs.count
        let volCount = Set(docs.map(\.volumeId)).count
        let df = DateFormatter(); df.dateStyle = .long; df.timeStyle = .none
        return String(
            localized: "export.colophon.line",
            defaultValue: "Compiled with FRUS Explorer · \(docCount) document\(docCount == 1 ? "" : "s") from \(volCount) volume\(volCount == 1 ? "" : "s") · \(df.string(from: date))")
    }
}

// MARK: - CollectionAIAttribution

/// Shared AI-attribution caption builder (Session 2026-07-03) — the single source for
/// the "this text was written by a model, not a person" label that every exported
/// generated summary (a `.summaryOnly` body or a Phase 5 headnote) carries, so HTML,
/// PDF, DOCX, and the live preview cannot drift. Mirrors the in-app labeling
/// (`SummaryBlockView`'s "AI summary" badge and the Apple Intelligence wording used
/// throughout Summarization).
///
/// Version history:
///   1.0 — Session 2026-07-03: initial implementation
enum CollectionAIAttribution {
    /// The attribution caption for an exported generated summary.
    ///
    /// `GeneratedSummary` does not currently store a producing-model identifier — the
    /// app's sole `SummarizationProvider` is Apple Intelligence's on-device system
    /// language model (FoundationModels) — so callers today always take the generic
    /// wording. The `modelName` parameter is the seam a stored per-summary model name
    /// would flow through if one is ever recorded.
    ///
    /// - Parameter modelName: The producing model's display name, when the stored
    ///   summary carries one; `nil` (today, always) selects the generic wording.
    /// - Returns: A single localized attribution line.
    static func label(modelName: String? = nil) -> String {
        if let modelName, !modelName.isEmpty {
            return String(
                localized: "export.aiAttribution.model",
                defaultValue: "AI-generated summary · \(modelName)")
        }
        return String(
            localized: "export.aiAttribution.generic",
            defaultValue: "AI-generated summary · Apple Intelligence (on-device)")
    }

    /// The attribution caption for an exported **headnote**, honoring its authorship (Composer
    /// redesign). An AI-written headnote keeps the standard "AI-generated summary" label; an
    /// AI-seeded headnote the user edited is disclosed as such; a headnote the user wrote from
    /// scratch carries **no** AI attribution (returns `nil`, so renderers emit no caption). This is
    /// how a user-authored key takeaway is kept out of the app's "label AI-generated content" policy.
    ///
    /// - Parameter authorship: The headnote summary's provenance.
    /// - Returns: The localized caption, or `nil` when no AI attribution should appear.
    static func headnoteLabel(authorship: SummaryAuthorship) -> String? {
        switch authorship {
        case .aiGenerated:
            return label()
        case .aiEdited:
            return String(localized: "export.aiAttribution.edited",
                          defaultValue: "AI-generated summary, edited by you")
        case .userWritten:
            return nil
        }
    }
}

// MARK: - CollectionExportExcerpt

/// A resolved excerpt payload (Authoring Phase 5): the frozen verbatim passage plus the
/// provenance metadata renderers need for the auto-citation source line and the optional
/// colour accent. Deliberately minimal — the entry's stored offsets/renderingVersion are
/// anchoring metadata for a later precision-rendering flip (A9), not rendering inputs, so
/// they never travel on the item.
///
/// Version history:
///   1.0 — Authoring Phase 5 (excerpts): initial implementation
struct CollectionExportExcerpt: Sendable {
    /// The frozen verbatim passage (the excerpt entry's `text`).
    let text: String
    /// The source FRUS document identifier (provenance).
    let documentId: String
    /// The source volume identifier (provenance).
    let volumeId: String
    /// The formatted history.state.gov-style citation for the source line — the same
    /// citation formatting document items use; empty when no provenance could be
    /// resolved (renderers then omit the source line).
    let citation: String
    /// The source highlight's colour raw value (`DocumentHighlight.Color`), when the
    /// excerpt was created from a highlight — drives the quote block's accent. `nil`
    /// for excerpts captured from a plain selection.
    let colorTag: String?

    /// The typed colour accent, when `colorTag` carries a known value.
    var color: DocumentHighlight.Color? {
        colorTag.flatMap { DocumentHighlight.Color(rawValue: $0) }
    }
}

// MARK: - CollectionGeneratedRow

/// One row of a resolved generated apparatus block (Authoring Phase 6): text plus
/// optional secondary text, an optional external link, and an optional indent level —
/// generic enough that every block type (bibliography entry, chronology line, archival
/// collection, person, tag) renders through one row shape, so each exporter styles rows
/// in exactly ONE switch arm total (per-block designed layouts are a later,
/// exporter-local upgrade).
///
/// Version history:
///   1.0 — Authoring Phase 6 (core): initial implementation
struct CollectionGeneratedRow: Sendable {
    /// The row's primary text (e.g. a citation, a person's name, a tag).
    let text: String
    /// Optional secondary text rendered after/below the primary (e.g. a description or
    /// a "Documents 3, 7, 12" reference list). `nil` renders nothing.
    let secondaryText: String?
    /// Optional external link for the row (e.g. a NARA catalog URL). HTML links the
    /// row text; DOCX emits a real hyperlink relationship; PDF renders the URL as
    /// visible small text (CoreText frame drawing has no link annotations — documented
    /// tradeoff in `PDFCollectionExporter`).
    let url: String?
    /// Nesting indent (0 = flush; each level steps the row inward). Used by outline-
    /// shaped blocks such as the archival-sources tree.
    let indentLevel: Int

    /// Creates a row; secondary text, URL, and indent default to "none".
    init(text: String, secondaryText: String? = nil, url: String? = nil, indentLevel: Int = 0) {
        self.text = text
        self.secondaryText = secondaryText
        self.url = url
        self.indentLevel = indentLevel
    }
}

// MARK: - CollectionGeneratedBlock

/// A fully **pre-resolved** generated apparatus block (Authoring Phase 6): the block
/// type, its localized title, and the resolved rows. Exporters are pure consumers — all
/// computation happens in `CollectionGeneratedBlocks.resolve` inside the single resolve
/// pipeline, so preview and every export format render identical block content.
///
/// Rows are never serialized anywhere; only the block *type* persists (on the entry and
/// in `.fruscollection` files) and rows re-resolve against the current data every time.
///
/// Version history:
///   1.0 — Authoring Phase 6 (core): initial implementation
struct CollectionGeneratedBlock: Sendable {
    /// Which apparatus block this is.
    let type: CollectionGeneratedBlockType
    /// The localized block title — the rendered section title and the ToC label.
    let title: String
    /// The resolved rows, in display order.
    let rows: [CollectionGeneratedRow]
}

// MARK: - CollectionExportItem

/// One item in a composed collection export: a resolved document, a section heading, an
/// editorial prose block, an excerpt quotation, or a generated apparatus block.
/// Exporters render an ordered `[CollectionExportItem]`, so a collection can be an
/// authored, sectioned reader rather than a flat document list (Phase 3a).
///
/// Version history (contract changes are compile-caught across all exporters and covered
/// by the exporter contract tests):
///   Phase 3a — `document` / `heading` / `prose`
///   Authoring Phase 4 — `heading` gains `level: Int` (1...`CollectionOutline.maxLevel`);
///     producers emit `CollectionOutline`-resolved depths, renderers clamp defensively.
///     Level 1 renders exactly the pre-Phase-4 heading in every format.
///   Authoring Phase 5 — `excerpt(CollectionExportExcerpt)`: a frozen quotation rendered
///     as a styled block quote + auto-citation source line in HTML/PDF/DOCX; the
///     reference formats (Zotero RIS, BibTeX) skip it by design, like heading/prose.
///   Authoring Phase 6 — `generated(CollectionGeneratedBlock)`: a pre-resolved apparatus
///     block rendered as a titled plain table/list in HTML/PDF/DOCX and listed in ToCs
///     by title (like sections); the reference formats skip it by design.
enum CollectionExportItem: Sendable {
    /// A FRUS document, fully resolved.
    case document(CollectionExportDocument)
    /// A section heading: the title text plus its resolved nesting level (1 = top-level,
    /// exactly the pre-Phase-4 rendering; 2–3 render as stepped sub-section headings).
    case heading(String, level: Int)
    /// An editorial prose block, as **RTF** data (Phase 3b). Exporters decode it to an
    /// `NSAttributedString` to render bold/italic/underline/colour, or read its `.string` for
    /// the plain-text projection. `Data` (unlike `NSAttributedString`) is `Sendable`.
    case prose(Data)
    /// A frozen verbatim quotation with provenance (Authoring Phase 5) — rendered as a
    /// quote block plus a source-citation line in the rich formats; dropped by the
    /// flat reference formats.
    case excerpt(CollectionExportExcerpt)
    /// A pre-resolved generated apparatus block (Authoring Phase 6) — rendered as a
    /// titled row list in the rich formats; dropped by the flat reference formats.
    case generated(CollectionGeneratedBlock)
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
/// traits, underline from the underline-style attribute, `colorHex` from the
/// foreground colour, and `linkURL` from the `.link` attribute (Session 2026-07-03 —
/// the editor's Link control; RTF round-trips it as a `HYPERLINK` field). Produced by
/// `CollectionProse.paragraphs(fromRTF:)`.
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
    /// The run's `.link` URL as a string, or `nil` for unlinked text. HTML renders it as
    /// an `<a href>`, DOCX as a real `<w:hyperlink>` relationship, PDF as underlined text
    /// followed by the visible URL (CoreText frame drawing has no link annotations).
    let linkURL: String?
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
    /// underline from the underline-style attribute, colour from the foreground colour,
    /// link URL from the `.link` attribute (`URL` or `String` valued — the RTF reader
    /// restores `HYPERLINK` fields as `NSURL`).
    private static func paragraphs(fromDecoded ns: NSAttributedString) -> [[ProseFormattedSpan]] {
        var paragraphs: [[ProseFormattedSpan]] = [[]]
        let plain = ns.string as NSString
        ns.enumerateAttributes(in: NSRange(location: 0, length: ns.length), options: []) { attrs, range, _ in
            var bold = false, italic = false, underline = false
            var colorHex: String?
            var linkURL: String?
            if let link = attrs[.link] {
                linkURL = (link as? URL)?.absoluteString ?? (link as? String)
            }
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
                   underline: underline, colorHex: colorHex, linkURL: linkURL, to: &paragraphs)
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
                   underline: false, colorHex: nil, linkURL: nil, to: &paragraphs)
        }
        return paragraphs
    }

    /// Splits one formatted run on blank lines (`"\n\n"`) and appends the resulting spans,
    /// starting a new paragraph at each blank line — the single splitting rule both decode
    /// paths share.
    private static func append(text: String, bold: Bool, italic: Bool, underline: Bool,
                               colorHex: String?, linkURL: String?,
                               to paragraphs: inout [[ProseFormattedSpan]]) {
        let parts = text.components(separatedBy: "\n\n")
        for (index, part) in parts.enumerated() {
            if index > 0 { paragraphs.append([]) }   // a blank line starts a new paragraph
            if !part.isEmpty {
                paragraphs[paragraphs.count - 1].append(
                    ProseFormattedSpan(text: part, bold: bold, italic: italic,
                                       underline: underline, colorHex: colorHex,
                                       linkURL: linkURL))
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
