// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CollectionToCStyle

/// Controls what label appears for each document in the collection table of contents.
///
/// Version history:
///   1.0 — Session 128: introduced alongside `CollectionExportOptions`
///   1.1 — 2026-10-25 (FRUS Explorer Light, S18a): moved to FRUSCoreKit with the export's other
///          payloads and options, public
public enum CollectionToCStyle: String, CaseIterable, Identifiable, Sendable {
    /// Use the formatted `history.state.gov`-style citation string (default).
    case citation
    /// Use the document's heading and dateline extracted from the TEI body.
    case headerAndDateline

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .citation:          return String(localized: "export.tocStyle.citation",
                                               defaultValue: "Citation")
        case .headerAndDateline: return String(localized: "export.tocStyle.headerAndDateline",
                                               defaultValue: "Header & Dateline")
        }
    }
}

// MARK: - CollectionPreset

/// A one-tap starting composition for a `Collection` (Composer redesign 4a). Applying a preset
/// **overwrites** the collection's export-composition *fields* (body depth, footnotes, source note,
/// notes, headnotes, highlights, word cloud, ToC style) and **appends** the apparatus blocks the
/// preset calls for — non-destructively: existing apparatus and all document entries are left
/// untouched, and everything stays fully editable afterward.
///
/// The field mappings are opinionated (they encode the editor's intent for four common shapes) but
/// not locked. Note: `applyHighlights` only renders over a **full** body, so on the summary-only
/// Briefing packet it is a deliberate no-op unless a document overrides its depth to full.
///
/// Applying a preset has two parts with different owners: `applyFields(to:)` overwrites the
/// collection's composition fields directly (safe — every host reads them live via `@Bindable`),
/// while the apparatus blocks (`apparatusBlocks`) must be inserted through the **host's** entry
/// management (which keeps its `sortedEntries` mirror + `sortOrder` consistent), so the host drives
/// insertion via `apparatusBlocks(notAlreadyIn:)`.
///
/// The recipe is FRUSCoreKit's (`recipe`), and so are the names and the apparatus; `applyFields(to:)`
/// and `matches(_:)`, which read and write a SwiftData `Collection`, are the app's
/// (`CollectionExporter+App.swift`). A host with collections of its own reads the same `recipe`.
///
/// Version history:
///   1.0 — Composer redesign 4a: the four presets
///   1.1 — 2026-10-25 (FRUS Explorer Light, S18a): moved to FRUSCoreKit, public, with `recipe` and
///          `Recipe` public; `applyFields(to:)` and `matches(_:)` stay in the app
public enum CollectionPreset: String, CaseIterable, Identifiable, Sendable {
    /// Full text with the researcher's notes, an archival source note, and an opening persons index
    /// + chronology — a classroom reader.
    case teachingReader
    /// AI summaries with key-takeaway headnotes and a thematic word-cloud overview — a policy brief.
    case briefingPacket
    /// Index/outline entries with archival source notes and a Sources & Archives appendix.
    case sourceDossier
    /// Everything on, full apparatus — a scholarly edition.
    case scholarlyEdition

    public var id: String { rawValue }

    /// The preset's display name.
    public var displayName: String {
        switch self {
        case .teachingReader:   return String(localized: "collection.preset.teachingReader",
                                              defaultValue: "Teaching reader")
        case .briefingPacket:   return String(localized: "collection.preset.briefingPacket",
                                              defaultValue: "Briefing packet")
        case .sourceDossier:    return String(localized: "collection.preset.sourceDossier",
                                              defaultValue: "Source dossier")
        case .scholarlyEdition: return String(localized: "collection.preset.scholarlyEdition",
                                              defaultValue: "Scholarly edition")
        }
    }

    /// A one-line summary of what the preset composes.
    public var subtitle: String {
        switch self {
        case .teachingReader:   return String(localized: "collection.preset.teachingReader.subtitle",
                                              defaultValue: "Full text · notes · chronology")
        case .briefingPacket:   return String(localized: "collection.preset.briefingPacket.subtitle",
                                              defaultValue: "Summaries · headnotes · word cloud")
        case .sourceDossier:    return String(localized: "collection.preset.sourceDossier.subtitle",
                                              defaultValue: "Outline · source notes · sources")
        case .scholarlyEdition: return String(localized: "collection.preset.scholarlyEdition.subtitle",
                                              defaultValue: "Everything · full apparatus")
        }
    }

    /// The row/menu icon (SF Symbol).
    public var systemImage: String {
        switch self {
        case .teachingReader:   return "book"
        case .briefingPacket:   return "doc.text.magnifyingglass"
        case .sourceDossier:    return "archivebox"
        case .scholarlyEdition: return "books.vertical"
        }
    }

    /// A one-word name for the compact (iPhone) preset chip, where the full `displayName`
    /// ("Briefing packet") is too wide (Composer v2 §C preset row).
    public var shortName: String {
        switch self {
        case .teachingReader:   return String(localized: "collection.preset.teachingReader.short", defaultValue: "Teaching")
        case .briefingPacket:   return String(localized: "collection.preset.briefingPacket.short", defaultValue: "Briefing")
        case .sourceDossier:    return String(localized: "collection.preset.sourceDossier.short", defaultValue: "Dossier")
        case .scholarlyEdition: return String(localized: "collection.preset.scholarlyEdition.short", defaultValue: "Scholarly")
        }
    }

    /// A one-word descriptor under the compact preset chip ("full text" / "summaries" / …).
    public var shortTag: String {
        switch self {
        case .teachingReader:   return String(localized: "collection.preset.teachingReader.tag", defaultValue: "full text")
        case .briefingPacket:   return String(localized: "collection.preset.briefingPacket.tag", defaultValue: "summaries")
        case .sourceDossier:    return String(localized: "collection.preset.sourceDossier.tag", defaultValue: "sources")
        case .scholarlyEdition: return String(localized: "collection.preset.scholarlyEdition.tag", defaultValue: "everything")
        }
    }

    /// The apparatus blocks the preset composes (each placed front/back per its type by the host).
    public var apparatusBlocks: [CollectionGeneratedBlockType] { recipe.apparatus }

    /// The preset's apparatus blocks that are **not** already present, given the set of
    /// `generatedBlockType` raw values the collection already carries — the append-only,
    /// non-destructive filter the host uses to decide which blocks to insert.
    public func apparatusBlocks(notAlreadyIn presentRawValues: Set<String>) -> [CollectionGeneratedBlockType] {
        recipe.apparatus.filter { !presentRawValues.contains($0.rawValue) }
    }

    /// The resolved field set for one preset — one place so `apply` and `apparatusBlocks` agree.
    public struct Recipe: Sendable {
        /// The collection's default body depth.
        public let bodyDepth: CollectionBodyDepth
        /// Whether footnotes are included.
        public let footnotes: Bool
        /// Whether each document's archival source note is included.
        public let sourceNote: Bool
        /// Whether research notes are included.
        public let notes: Bool
        /// Whether a document's headnote is on by default.
        public let headnotes: Bool
        /// Whether highlights are drawn.
        public let highlights: Bool
        /// Whether the word-cloud overview is drawn.
        public let wordCloud: Bool
        /// The contents' label style.
        public let toc: CollectionToCStyle
        /// The apparatus blocks the preset appends, in order.
        public let apparatus: [CollectionGeneratedBlockType]
    }

    /// The preset's recipe: the fields `applyFields(to:)` writes and `matches(_:)` compares, and the
    /// apparatus `apparatusBlocks` lists.
    public var recipe: Recipe {
        switch self {
        case .teachingReader:
            return Recipe(bodyDepth: .full, footnotes: false, sourceNote: true, notes: true,
                          headnotes: false, highlights: false, wordCloud: false,
                          toc: .headerAndDateline, apparatus: [.personsIndex, .chronology])
        case .briefingPacket:
            return Recipe(bodyDepth: .summaryOnly, footnotes: false, sourceNote: false, notes: false,
                          headnotes: true, highlights: true, wordCloud: true,
                          toc: .headerAndDateline, apparatus: [])
        case .sourceDossier:
            return Recipe(bodyDepth: .index, footnotes: false, sourceNote: true, notes: false,
                          headnotes: false, highlights: false, wordCloud: false,
                          toc: .citation, apparatus: [.archivalSources])
        case .scholarlyEdition:
            return Recipe(bodyDepth: .full, footnotes: true, sourceNote: true, notes: true,
                          headnotes: true, highlights: true, wordCloud: true,
                          toc: .citation,
                          apparatus: [.bibliography, .chronology, .archivalSources, .personsIndex, .thematicIndex])
        }
    }
}

// MARK: - CollectionExportOptions

// MARK: - CollectionBodyDepth

/// Controls how much of each document's body appears in a collection export.
///
/// Version history:
///   1.0 — Session 153: introduced alongside `CollectionFootnoteStyle`
///   1.1 — 2026-10-25 (FRUS Explorer Light, S18a): moved to FRUSCoreKit, public; `available`, which
///          asks Apple Intelligence, stays in the app (`CollectionExporter+App.swift`)
public enum CollectionBodyDepth: String, CaseIterable, Identifiable, Sendable {
    /// Full document body — current default. Respects the document as written.
    case full
    /// Replace the body with an AI-generated summary. Requires Apple Intelligence.
    /// Summaries are generated on demand during export if none already exist for
    /// the selected prompt. Export fails with an error if generation fails.
    case summaryOnly
    /// No body text — citation, date, and research notes only. Produces a compact
    /// reference list or briefing outline.
    case index

    public var id: String { rawValue }

    public var displayName: String {
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
    public var chipLabel: String {
        switch self {
        case .full:        return String(localized: "collection.entry.chip.bodyDepth.full",
                                         defaultValue: "Full")
        case .summaryOnly: return String(localized: "collection.entry.chip.bodyDepth.summary",
                                         defaultValue: "Summary")
        case .index:       return String(localized: "collection.entry.chip.bodyDepth.index",
                                         defaultValue: "Index")
        }
    }

    /// A document's effective body depth (Phase 3c cascade, most specific wins): the entry's
    /// own override → the section override (the nearest preceding heading's) → the collection
    /// default. Inputs are `CollectionBodyDepth` raw values; `nil` means "not set".
    public static func resolve(entryOverride: String?,
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
///   1.2 — 2026-10-25 (FRUS Explorer Light, S18a): moved to FRUSCoreKit, public
public enum CollectionFootnoteStyle: String, CaseIterable, Identifiable, Sendable {
    /// No footnotes — body text only.
    case none
    /// Archival source note only — strips editorial/explanatory footnotes but
    /// appends a "Source:" block showing the document's archival provenance.
    case sourceNoteOnly
    /// All footnotes — current default behavior.
    case all

    public var id: String { rawValue }

    public var displayName: String {
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
/// advances that counter by `text.utf16.count`.
///
/// ## The unit is UTF-16
/// `DocumentHighlight.startOffset`/`endOffset` are UTF-16 code-unit positions — the JS
/// `charToNode` map holds one entry per code unit — so both the counter and the slicing
/// index in UTF-16. This counted in Swift `Character` (grapheme clusters) on both, which
/// made `hl.startOffset - chunkStart` a UTF-16 number minus a grapheme-space one; a single
/// astral character or combining sequence earlier in the document shifted every later
/// PDF/DOCX shading by one, and kept shifting.
///
/// **Measured 2026-09-10: no shippable volume can trigger it.** All 744 corpus files carry
/// zero non-BMP characters, zero combining marks and zero CR, and the only numeric character
/// references are `&#x93;`/`&#x94;`, both BMP. So the correction changes no export today —
/// which is also why nothing caught it, since this type had no tests at all and the
/// serializer's suite minted its offsets with `String.distance`, in the walker's own
/// wrong unit.
///
/// Overlapping highlights are resolved by preferring the one that opens first,
/// mirroring `FRUSRenderNodeHTMLSerializer.injectHighlights`.
///
/// Version history:
///   1.0 — Future (unnumbered): PDF/DOCX inline highlight annotation
///   1.1 — 2026-10-25 (FRUS Explorer Light, S18a): moved to FRUSCoreKit with the Word exporter;
///          its colour is the kit's `HighlightColor`, which `DocumentHighlight.Color` names
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
    func partition(_ text: String) -> [(range: Range<String.Index>, color: HighlightColor?)] {
        let chunkStart = flatPos
        let chunkLen = text.utf16.count
        flatPos += chunkLen

        guard isActive, chunkLen > 0 else {
            return [(text.startIndex..<text.endIndex, nil)]
        }

        // Every Character boundary of `text`, as a (UTF-16 offset, index) pair. Built in
        // one pass so a cut costs a lookup rather than a re-walk, and so a cut can be
        // SNAPPED rather than dropped: the returned spans must concatenate to cover all
        // of `text`, so a cut that is not on a boundary has to move to one, never vanish.
        var boundaryOffsets: [Int] = []
        var boundaryIndices: [String.Index] = []
        var offset = 0
        var index = text.startIndex
        while true {
            boundaryOffsets.append(offset)
            boundaryIndices.append(index)
            if index == text.endIndex { break }
            offset += text[index].utf16.count
            index = text.index(after: index)
        }

        /// The boundary at or immediately after `utf16Offset`. A stored offset can only
        /// fall inside a grapheme cluster if the web view produced a mid-cluster
        /// selection; shading half a cluster is not representable, so the whole cluster
        /// goes to the span that follows.
        func boundarySlot(_ utf16Offset: Int) -> Int {
            var lo = 0, hi = boundaryOffsets.count - 1
            while lo < hi {
                let mid = (lo + hi) / 2
                if boundaryOffsets[mid] < utf16Offset { lo = mid + 1 } else { hi = mid }
            }
            return lo
        }

        // Collect every highlight start/end boundary that falls strictly inside
        // this chunk — those are the only points where the active colour can change.
        var slots = Set<Int>([0, boundaryOffsets.count - 1])
        for hl in sorted {
            let s = hl.startOffset - chunkStart
            let e = hl.endOffset - chunkStart
            if s > 0, s < chunkLen { slots.insert(boundarySlot(s)) }
            if e > 0, e < chunkLen { slots.insert(boundarySlot(e)) }
        }
        let cuts = slots.sorted()

        var spans: [(Range<String.Index>, HighlightColor?)] = []
        spans.reserveCapacity(cuts.count - 1)
        for i in 0..<(cuts.count - 1) {
            let startSlot = cuts[i], endSlot = cuts[i + 1]
            let startIdx = boundaryIndices[startSlot], endIdx = boundaryIndices[endSlot]
            guard startIdx < endIdx else { continue }
            // Probe the span start to find the overlapping highlight, preferring the
            // earliest-opening one. The probe is a UTF-16 position, matching the offsets.
            let probe = chunkStart + boundaryOffsets[startSlot]
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
///   1.4 — 2026-10-09: #1585 — `init(composing:)`, the one place a collection's composition
///          becomes options, which the export sheet and the content resolver each wrote out
///   1.5 — 2026-10-25 (FRUS Explorer Light, S18a): moved to FRUSCoreKit, public, with its
///          initialiser spelled out with the same defaults; `init(composing:)`, which reads a
///          SwiftData `Collection`, stays in the app (`CollectionExporter+App.swift`)
public struct CollectionExportOptions: Sendable {
    /// Which label style to use in the table of contents.
    public var tocStyle: CollectionToCStyle = .citation
    /// When `true`, document footnotes are rendered where footnote rendering is gated
    /// (the shared HTML renderer / live preview). Defaults to `true` — the legacy
    /// `.all` behavior. (The PDF/DOCX exporters have never gated footnotes on the old
    /// tri-state; that pre-existing behavior is deliberately unchanged so untouched
    /// collections keep exporting byte-identically.)
    public var includeFootnotes: Bool = true
    /// When `true`, the resolver fetches each document's archival source note and every
    /// format appends a "Source:" block. Defaults to `false` — pre-Phase-5, only the
    /// legacy `.sourceNoteOnly` style resolved it.
    public var includeSourceNote: Bool = false
    /// When `true`, inline user highlights are annotated in the document body.
    /// Implemented for all three export formats: HTML (`FRUSRenderNodeHTMLSerializer.injectHighlights`),
    /// PDF (`PDFCollectionExporter.drawFrameWithHighlights`), and DOCX
    /// (`DocxCollectionExporter.runsXML(for:props:tracker:)`).
    public var applyHighlights: Bool = false
    /// When `true`, attached research notes appear below each document body.
    /// Default `true`; set `false` for a clean primary-source reader.
    public var includeNotes: Bool = true
    /// The `SummarizationPrompt.id` to use when `bodyDepth == .summaryOnly`.
    /// Summaries are generated on demand if none exist for this prompt.
    public var summaryPromptId: UUID? = nil
    /// When `true`, a word-cloud overview page/section of the collection's most
    /// frequent terms is included. The PDF, HTML and Word exporters draw it; the HTML and Word
    /// exporters, FRUSCoreKit's, with the drawing they are handed (`wordCloud`), which
    /// `ExportFormat.makeExporter()` passes, and none when they are handed none.
    public var includeWordCloud: Bool = false
    /// The collection-level default a document entry's `includeHeadnote == nil` (Default) resolves
    /// to (Composer redesign). `false` by default, so collections that never set a headnote default
    /// resolve exactly as before. Set from `Collection.defaultIncludeHeadnote`.
    public var includeHeadnoteDefault: Bool = false

    /// Creates options; every one defaults to the standard export, so `CollectionExportOptions()`
    /// is the look an untouched collection exports with.
    public init(tocStyle: CollectionToCStyle = .citation, includeFootnotes: Bool = true,
                includeSourceNote: Bool = false, applyHighlights: Bool = false,
                includeNotes: Bool = true, summaryPromptId: UUID? = nil,
                includeWordCloud: Bool = false, includeHeadnoteDefault: Bool = false) {
        self.tocStyle = tocStyle
        self.includeFootnotes = includeFootnotes
        self.includeSourceNote = includeSourceNote
        self.applyHighlights = applyHighlights
        self.includeNotes = includeNotes
        self.summaryPromptId = summaryPromptId
        self.includeWordCloud = includeWordCloud
        self.includeHeadnoteDefault = includeHeadnoteDefault
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
///   1.7 — 2026-10-25 (FRUS Explorer Light, S18a): moved to FRUSCoreKit, public, so a host outside
///          the app resolves a document into the payload the app's exporters render
public struct CollectionExportDocument: Sendable {
    /// The FRUS document identifier (e.g. `"d1"`).
    public let documentId: String
    /// The containing volume identifier (e.g. `"frus1969-76v01"`).
    public let volumeId: String
    /// Position within the collection (ascending).
    public let sortOrder: Int
    /// How much of this document's body to render — the per-entry effective depth
    /// (`CollectionEntry.bodyDepthOverride`, else the collection's `defaultBodyDepth`).
    /// Exporters switch on this per document, so one collection can mix full documents,
    /// summaries, and citation-only entries.
    public let bodyDepth: CollectionBodyDepth
    /// Human-readable document title (volume title + document ID).
    public let title: String
    /// The user's per-entry title override (M3, D4). `nil`/empty uses the derived heading
    /// (`exportHeading`). A non-empty value replaces **both** the ToC label (`tocLabel`,
    /// for both styles) and the top-of-document export heading. Defaulted `nil` at every
    /// construction site so untouched exports stay byte-identical.
    public let titleOverride: String?
    /// ISO 8601 date string, if known.
    public let date: String?
    /// Plain-text body of the document. Preserved as fallback when `renderModel` is nil.
    public let bodyText: String
    /// Research note texts linked to this entry (one per linked `ResearchNote`).
    public let noteTexts: [String]
    /// Formatted citation string (history.state.gov style).
    public let citation: String
    /// `https://history.state.gov/historicaldocuments/{volumeId}/{documentId}`
    public let historyStateGovURL: String
    /// Fully converted render model for structured export output.
    /// Non-nil when the volume XML was successfully parsed during collection assembly.
    public let renderModel: FRUSDocumentRenderModel?
    /// The document heading extracted from the TEI body (e.g. `"1. Memorandum From…"`).
    public let header: String
    /// The dateline extracted from the TEI body.
    public let dateline: String?
    /// AI-generated summary text for this document. Populated when
    /// `options.bodyDepth == .summaryOnly`; `nil` otherwise.
    public let summaryText: String?
    /// User highlights to annotate inline in the body. Populated when
    /// `options.applyHighlights == true`; empty otherwise.
    public let highlights: [ExportHighlight]
    /// Raw archival source note text. Populated when
    /// `options.includeSourceNote == true`; `nil` otherwise.
    public let sourceNoteText: String?
    /// Whether this entry requested a headnote (Authoring Phase 5). When `true` and
    /// `headnoteText` is empty/nil, renderers emit a placeholder note instead — the
    /// resolver never generates a summary for a headnote.
    public let includeHeadnote: Bool
    /// The resolved headnote text — the chosen (or fallback) stored `GeneratedSummary`.
    /// Rendered as an italic abstract above the body when `includeHeadnote` is `true`.
    public let headnoteText: String?
    /// The headnote summary's provenance (Composer redesign) — drives the export attribution so a
    /// user-edited/-written headnote is not labeled "AI-generated". `.aiGenerated` when no headnote.
    public let headnoteAuthorship: SummaryAuthorship
    /// The entry/section highlight override resolved by the cascade (Authoring Phase 5).
    /// `nil` = inherit — renderers gate inline highlights on
    /// `applyHighlightsOverride ?? options.applyHighlights`, so the default reproduces
    /// the collection-level behavior exactly.
    public let applyHighlightsOverride: Bool?
    /// The entry/section research-notes override resolved by the cascade (Phase 5).
    /// `nil` = inherit — renderers gate note blocks on
    /// `includeNotesOverride ?? options.includeNotes`.
    public let includeNotesOverride: Bool?
    /// The entry/section footnote override resolved by the cascade (Phase 5). `nil` =
    /// inherit — every renderer (the shared HTML renderer / preview, PDF, and DOCX —
    /// the latter two gated since the 2026-07-03 owner decision) gates footnote bodies
    /// on `includeFootnotesOverride ?? options.includeFootnotes`.
    public let includeFootnotesOverride: Bool?
    /// The entry/section summary-prompt override resolved by the cascade (Phase 5).
    /// `nil` = inherit the collection's `summaryPromptId`. Drives which prompt's stored
    /// summary attaches (preview) or generates (export) for a `.summaryOnly` body, and
    /// the headnote fallback pick.
    public let summaryPromptIdOverride: UUID?
    /// The resolved "See also:" citations (decision A10, Authoring Phase 5): documents
    /// this one cross-references that are **also in the collection**, in collection
    /// order, deduplicated, self excluded. Empty (the default, and whenever the entry's
    /// `includeRelatedDocuments` resolves off) renders nothing — untouched collections
    /// are byte-identical.
    public let relatedDocumentCitations: [String]
    /// Pre-built Zotero JSON item for `.zoteroJSON` export. `nil` if volume
    /// metadata was unavailable when this document was resolved.
    public let zoteroItem: ZoteroJSONExporter.Item?

    /// Backward-compatible single-note accessor.
    public var noteText: String? { noteTexts.first }

    /// The top-of-document export heading (M3, D4): the user's `titleOverride` when
    /// non-empty, else the citation (or `title` when no citation). The single centralizer
    /// so the three exporters (HTML/PDF/DOCX) stay in lockstep — each renders this instead
    /// of re-deriving `citation.isEmpty ? title : citation`.
    public var exportHeading: String {
        if let override = titleOverride, !override.isEmpty { return override }
        return citation.isEmpty ? title : citation
    }

    /// Returns the ToC label appropriate for the given display style. A non-empty
    /// `titleOverride` wins first for **both** styles (M3, D4), so the ToC label and the
    /// export heading name the document identically.
    public func tocLabel(style: CollectionToCStyle) -> String {
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

    public init(
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
    public func withSummary(_ text: String) -> CollectionExportDocument {
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
///   1.2 — #377 Phase 4: `projectName`, `projectResearchQuestion` (the active project's
///          provenance, opt-in per `Collection.includeProjectProvenance`; defaulted `nil`)
///   1.3 — M-2: `methodAppendixLines` (the project's query log, opt-in per
///          `Collection.includeMethodAppendix`; defaulted empty, which every renderer skips)
///   1.4 — #1463: `init` resolves `name` through `CollectionExportNaming.title(savedName:)`, so a
///          collection with no name exports titled "Untitled Collection" rather than blank
///   1.5 — 2026-10-25 (FRUS Explorer Light, S18a): moved to FRUSCoreKit, public, with `exportDate`
///          (defaulted `nil`, the app's case: an export is dated when it is rendered, as before);
///          `methodAppendix(enabled:appendix:)`, which reads the app's `QueryMethodAppendix`, stays
///          in the app (`CollectionExporter+App.swift`)
public struct CollectionExportMetadata: Sendable {
    /// The collection's display name — the export title. Never empty: `init` stores the name it is
    /// given trimmed, or "Untitled Collection" when that has no text (`CollectionExportNaming.title`).
    public let name: String
    /// Optional one-line description rendered under the title (pre-Phase-4 behavior).
    public let note: String?
    /// Optional title-page subtitle (Authoring Phase 4). `nil`/empty renders nothing,
    /// keeping the export header byte-identical to pre-Phase-4 output.
    public let subtitle: String?
    /// Optional title-page author/byline (Authoring Phase 4). `nil`/empty renders nothing.
    public let authorLine: String?
    /// Optional project provenance — the name of the project this export was generated under
    /// (#377 Phase 4). `nil` unless the collection opts in (`includeProjectProvenance`) *and* a
    /// project is active; renders a "Project: …" line between the author and the note. The value
    /// is the **live** active project at export time (like `authorLine`'s placeholder), not a
    /// value stored on the collection.
    public let projectName: String?
    /// Optional project research question, rendered under the project name (#377 Phase 4). `nil`
    /// unless a project is active with a non-empty question and the collection opts in.
    public let projectResearchQuestion: String?
    /// When `true`, renderers append a trailing colophon (`CollectionColophon`).
    /// Defaults to `false`, so collections that never opt in export exactly as today.
    public let includeColophon: Bool

    /// The method appendix as flat lines, or empty (M-2).
    ///
    /// Pre-rendered rather than carried as a `QueryMethodAppendix`, because the gating and the
    /// project narrowing both happen at the call site where the SwiftData fetch lives, and a
    /// renderer that received the whole appendix could render an un-narrowed one by mistake.
    /// Empty is the "feature unused" state and every renderer emits nothing for it, so a
    /// collection that never opts in exports byte-identically to before.
    public let methodAppendixLines: [String]

    /// The day the export is dated: what the Word cover's "Exported" line and every colophon print.
    ///
    /// `nil`, which the app passes, dates the export when it is rendered, in the device's own
    /// calendar, as every export always has. A host that must print the same bytes for the same
    /// collection wherever it runs (FRUS Explorer Light, S18a) names the moment, the locale and the
    /// time zone: in the app's Foundation the long date reads "October 26, 2026" in `en_US` and
    /// "26 October 2026" in `en_001`, the locale a Linux server takes when none is set.
    public let exportDate: CollectionExportDate?

    /// Creates a metadata snapshot. The Phase 4 parameters default to "feature unused"
    /// so pre-Phase-4 call sites compile — and render — unchanged.
    ///
    /// `name` is the collection's SAVED name, which may be empty (#1463); the snapshot's `name` is
    /// the title every exporter prints, resolved here so that no construction site can pass a blank
    /// one through.
    public init(name: String, note: String?, subtitle: String? = nil,
                authorLine: String? = nil, projectName: String? = nil,
                projectResearchQuestion: String? = nil, includeColophon: Bool = false,
                methodAppendixLines: [String] = [], exportDate: CollectionExportDate? = nil) {
        self.name = CollectionExportNaming.title(savedName: name)
        self.note = note
        self.subtitle = subtitle
        self.authorLine = authorLine
        self.projectName = projectName
        self.projectResearchQuestion = projectResearchQuestion
        self.includeColophon = includeColophon
        self.methodAppendixLines = methodAppendixLines
        self.exportDate = exportDate
    }

    /// Resolves the export's project provenance from the toggle + the active project's fields —
    /// pure, so the gating is unit-testable without the SwiftData `@Query` lookup at the call site.
    /// Returns `(nil, nil)` when disabled or when there's no active project with a non-empty name;
    /// the research question is dropped when blank. The name is the anchor: no name → no provenance.
    public static func projectProvenance(enabled: Bool, projectName: String?, researchQuestion: String?)
        -> (name: String?, question: String?) {
        guard enabled,
              let name = projectName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty
        else { return (nil, nil) }
        let question = researchQuestion?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (name, (question?.isEmpty == false) ? question : nil)
    }
}

// MARK: - CollectionExportDate

/// The moment an export is dated, and the calendar its day is written in: the Word cover's
/// "Exported" line and every colophon print the day, long, with no time.
///
/// The app never names one (`CollectionExportMetadata.exportDate` is `nil`), so an export is dated
/// when it is rendered, in the device's locale and time zone, as it always has been. A host outside
/// the app names all three, so the same collection prints the same bytes wherever it is rendered.
///
/// Version history:
///   1.0 — 2026-10-25 (FRUS Explorer Light, S18a): the date the Word exporter and the colophon each
///          took from `Date()` and a `DateFormatter` of the device's locale, passed in
public struct CollectionExportDate: Sendable {
    /// The moment the export is dated.
    public var date: Date
    /// The locale the day is written in; `nil` writes it in the device's own.
    public var locale: Locale?
    /// The time zone the day is read in; `nil` reads it in the device's own.
    public var timeZone: TimeZone?

    /// Creates an export date: now, in the device's locale and time zone, unless told otherwise.
    public init(date: Date = Date(), locale: Locale? = nil, timeZone: TimeZone? = nil) {
        self.date = date
        self.locale = locale
        self.timeZone = timeZone
    }

    /// The formatter an export writes the day with: `.long`, with no time, in this date's locale and
    /// time zone where it names them — otherwise exactly the formatter the exporters made for
    /// themselves.
    public var formatter: DateFormatter {
        let df = DateFormatter(); df.dateStyle = .long; df.timeStyle = .none
        if let locale { df.locale = locale }
        if let timeZone { df.timeZone = timeZone }
        return df
    }
}

// MARK: - CollectionColophon

/// Shared colophon text builder (Authoring Phase 4) — the single source for the trailing
/// "how this artifact was produced" line, so HTML, PDF, and DOCX cannot drift. Rendered
/// only when `CollectionExportMetadata.includeColophon` is set.
///
/// Version history:
///   1.0 — Authoring Phase 4: initial implementation
///   1.1 — Lane EXPORT review round 1 (PV-1): `sourceLines(for:embedsWordCloud:)` names the app's word lists when
///          the export embeds the collection's word cloud
///   1.2 — 2026-10-25 (FRUS Explorer Light, S18a): moved to FRUSCoreKit, public; `text(for:dated:)`
///          takes the export's date (`CollectionExportMetadata.exportDate`), `nil` being now, as before
public enum CollectionColophon {
    /// The colophon line for a resolved item list: app attribution, document/volume
    /// counts, and the compilation date.
    ///
    /// - Parameters:
    ///   - items: The resolved items whose `.document` payloads are counted.
    ///   - exportDate: The compilation date; `nil`, the default, is now, in the device's calendar.
    /// - Returns: A single localized colophon line.
    public static func text(for items: [CollectionExportItem],
                            dated exportDate: CollectionExportDate? = nil) -> String {
        let docs = items.documents
        let docCount = docs.count
        let volCount = Set(docs.map(\.volumeId)).count
        let exportDate = exportDate ?? CollectionExportDate()
        let df = exportDate.formatter, date = exportDate.date
        return String(
            localized: "export.colophon.line",
            defaultValue: "Compiled with FRUS Explorer · \(docCount) document\(docCount == 1 ? "" : "s") from \(volCount) volume\(volCount == 1 ? "" : "s") · \(df.string(from: date))")
    }

    /// The sources block that follows the colophon line (PV-1).
    ///
    /// **Here rather than in each renderer, for the reason this type already exists**: it is the
    /// single source for the trailing "how this artifact was produced" text, so HTML, PDF and DOCX
    /// cannot drift. A sources sentence added to one renderer would ship in one format and vanish
    /// from the other two — the failure W-13 recorded when it found `preambleLines` was not shared.
    ///
    /// The set is derived from the items, never passed in, so an export cannot name a source it did
    /// not use. Empty for a collection of headings alone, and the callers render nothing then.
    ///
    /// The one addition the items cannot show is the word cloud a rich export can embed
    /// (`CollectionExportOptions.includeWordCloud`, which the export sheet sets for PDF, HTML and
    /// Word, `ExportFormat.drawsWordCloud`): it is an export option, not an item, and it is
    /// counted through the app's own lexicons and stopwords, so it adds ``ProvenanceSource/appWordLists``
    /// — what the standalone word-cloud export states (`WordCloudView`). Each renderer passes whether
    /// it actually drew one (the image it holds, not the option, since a collection with no countable
    /// words draws none), so the block names the lists exactly when the figure is there (review round 1).
    ///
    /// - Parameters:
    ///   - items: The resolved items the export prints.
    ///   - embedsWordCloud: Whether this export draws the collection's word cloud.
    public static func sourceLines(for items: [CollectionExportItem], embedsWordCloud: Bool) -> [String] {
        // **No `includesCuratedResolutions`, and the omission is measured rather than an oversight.**
        // PV-1 shipped this call passing `true` whenever an archival-sources block was present, on
        // the assumption that such a block "may carry an identifier the owner matched by hand". It
        // cannot. The block's identifiers come from `ArchivalResolver.documentResolution`, which
        // reads `CentralFilesIndexStore` and `VolumeSourcesIndexStore` and nothing else — and two
        // shipped assertions in `CuratedLotResolutionsTests` prove curated rows are absent from
        // both of the artifacts behind them: `curatedLotsAreNotInCentralFilesIndex` and
        // `curatedLotsHaveNoAuthorityNAID`. `curated-lot-resolutions.json` says the same about
        // itself, and gives the reason: those bundles "feed surfaces that cannot express doubt".
        //
        // So the sentence added doubt to every archival-sources export that the app had in fact
        // guaranteed away — the opposite of this wave's purpose, and worse than saying nothing.
        // Every reader of the curated tables (`CuratedLotResolutionsStore`,
        // `CuratedLibraryResolutionsStore`) is a Source Explorer *view*; the trip packet's
        // `archivalResolution` returns `nil` outright. If an export path ever does render a curated
        // outcome, this is where the disclosure goes back in — `ProvenanceStatementTests` pins the
        // absence so that change cannot be silent. (It named `CollectionExporterTests`, which does
        // not exist; the pinning test is `archivalSourcesDoesNotClaimCuration`.)
        // PV §5 / Q-1: the residual is stated when — and only when — the export actually carries
        // an archival-sources block, since that block is a parse of the volumes' source notes.
        // Derived from the content, not passed by the caller, for the same reason the curated
        // sentence above was removed: a flag a caller sets is a flag a caller sets wrongly.
        let restsOnParse = items.contains { item in
            if case .generated(let block) = item, block.type == .archivalSources { return true }
            return false
        }
        let sources = items.provenanceSources.union(embedsWordCloud ? [.appWordLists] : [])
        return ProvenanceStatement.block(for: sources, restsOnSourceNoteParse: restsOnParse)
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
///   1.1 — 2026-10-25 (FRUS Explorer Light, S18a): moved to FRUSCoreKit, public
public enum CollectionAIAttribution {
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
    public static func label(modelName: String? = nil) -> String {
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
    public static func headnoteLabel(authorship: SummaryAuthorship) -> String? {
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
///   1.1 — 2026-10-25 (FRUS Explorer Light, S18a): moved to FRUSCoreKit, public, with its
///          initialiser spelled out; `color` is the kit's `HighlightColor`, which
///          `DocumentHighlight.Color` names
public struct CollectionExportExcerpt: Sendable {
    /// The frozen verbatim passage (the excerpt entry's `text`).
    public let text: String
    /// The source FRUS document identifier (provenance).
    public let documentId: String
    /// The source volume identifier (provenance).
    public let volumeId: String
    /// The formatted history.state.gov-style citation for the source line — the same
    /// citation formatting document items use; empty when no provenance could be
    /// resolved (renderers then omit the source line).
    public let citation: String
    /// The source highlight's colour raw value (`DocumentHighlight.Color`), when the
    /// excerpt was created from a highlight — drives the quote block's accent. `nil`
    /// for excerpts captured from a plain selection.
    public let colorTag: String?

    /// Creates an excerpt payload.
    public init(text: String, documentId: String, volumeId: String, citation: String, colorTag: String?) {
        self.text = text
        self.documentId = documentId
        self.volumeId = volumeId
        self.citation = citation
        self.colorTag = colorTag
    }

    /// The typed colour accent, when `colorTag` carries a known value.
    public var color: HighlightColor? {
        colorTag.flatMap { HighlightColor(rawValue: $0) }
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
///   1.1 — 2026-10-25 (FRUS Explorer Light, S18a): moved to FRUSCoreKit, public
public struct CollectionGeneratedRow: Sendable {
    /// The row's primary text (e.g. a citation, a person's name, a tag).
    public let text: String
    /// Optional secondary text rendered after/below the primary (e.g. a description or
    /// a "Documents 3, 7, 12" reference list). `nil` renders nothing.
    public let secondaryText: String?
    /// Optional external link for the row (e.g. a NARA catalog URL). HTML links the
    /// row text; DOCX emits a real hyperlink relationship; PDF renders the URL as
    /// visible small text (CoreText frame drawing has no link annotations — documented
    /// tradeoff in `PDFCollectionExporter`).
    public let url: String?
    /// Nesting indent (0 = flush; each level steps the row inward). Used by outline-
    /// shaped blocks such as the archival-sources tree.
    public let indentLevel: Int

    /// Creates a row; secondary text, URL, and indent default to "none".
    public init(text: String, secondaryText: String? = nil, url: String? = nil, indentLevel: Int = 0) {
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
///   1.1 — 2026-10-25 (FRUS Explorer Light, S18a): moved to FRUSCoreKit, public, with its
///          initialiser spelled out
public struct CollectionGeneratedBlock: Sendable {
    /// Which apparatus block this is.
    public let type: CollectionGeneratedBlockType
    /// The localized block title — the rendered section title and the ToC label.
    public let title: String
    /// The resolved rows, in display order.
    public let rows: [CollectionGeneratedRow]

    /// Creates a resolved block.
    public init(type: CollectionGeneratedBlockType, title: String, rows: [CollectionGeneratedRow]) {
        self.type = type
        self.title = title
        self.rows = rows
    }
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
///   2026-10-25 (FRUS Explorer Light, S18a) — moved to FRUSCoreKit, public; `prose` carries the
///     block's paragraphs of `ProseFormattedSpan`, decoded when the item is resolved, where it
///     carried the stored RTF and each exporter decoded it with `CollectionProse.paragraphs(fromRTF:)`
public enum CollectionExportItem: Sendable {
    /// A FRUS document, fully resolved.
    case document(CollectionExportDocument)
    /// A section heading: the title text plus its resolved nesting level (1 = top-level,
    /// exactly the pre-Phase-4 rendering; 2–3 render as stepped sub-section headings).
    case heading(String, level: Int)
    /// An editorial prose block (Phase 3b), as the paragraphs of formatted spans every format
    /// renders: bold, italic, underline, colour and links. The host decodes the stored rich text
    /// once, when it resolves the item — the app's resolver with
    /// `CollectionProse.paragraphs(fromRTF:)`, a host outside the app with its own reader of the
    /// same RTF — so HTML, Word and PDF render the same spans. `[]` renders nothing.
    case prose([[ProseFormattedSpan]])
    /// A frozen verbatim quotation with provenance (Authoring Phase 5) — rendered as a
    /// quote block plus a source-citation line in the rich formats; dropped by the
    /// flat reference formats.
    case excerpt(CollectionExportExcerpt)
    /// A pre-resolved generated apparatus block (Authoring Phase 6) — rendered as a
    /// titled row list in the rich formats; dropped by the flat reference formats.
    case generated(CollectionGeneratedBlock)
}

extension Array where Element == CollectionExportItem {

    /// What this collection's contents actually drew on, for the export's sources block (PV-1).
    ///
    /// **Derived from the items rather than declared by the caller**, so an export cannot claim a
    /// source it did not use or omit one it did. The mapping is per item kind and per apparatus
    /// block, and each entry is a claim about where the bytes came from:
    ///
    /// - a document or a frozen quotation is the printed record, so ``ProvenanceSource/frusText``;
    /// - a `.summaryOnly` body was written by the on-device model, so ``ProvenanceSource/appModel``
    ///   — the one case where the exported prose is not the record's;
    /// - the researcher's own prose, and a thematic index built from their tags, are
    ///   ``ProvenanceSource/yourReading``;
    /// - an archival-sources block carries NARA identifiers where they resolved, so it adds
    ///   ``ProvenanceSource/naraCatalog`` — and the note it parsed remains FRUS's;
    /// - a persons index is rolled up through the authority join, so
    ///   ``ProvenanceSource/ohPeopleRegister``.
    ///
    /// A bibliography and a chronology add nothing: both are built from the documents' own
    /// metadata, which `frusText` already covers.
    public var provenanceSources: Set<ProvenanceSource> {
        var out: Set<ProvenanceSource> = []
        for item in self {
            switch item {
            case .document(let d):
                out.insert(.frusText)
                if d.bodyDepth == .summaryOnly { out.insert(.appModel) }
            case .excerpt:
                out.insert(.frusText)
            case .prose:
                out.insert(.yourReading)
            case .heading:
                break
            case .generated(let block):
                switch block.type {
                case .bibliography, .chronology: out.insert(.frusText)
                case .archivalSources:           out.formUnion([.frusText, .naraCatalog])
                case .personsIndex:              out.formUnion([.frusText, .ohPeopleRegister])
                case .thematicIndex:             out.insert(.yourReading)
                }
            }
        }
        return out
    }

    /// The `.document` payloads, in order (heading/prose items dropped). Used where an
    /// exporter needs the documents alone — e.g. the collection word cloud.
    public var documents: [CollectionExportDocument] {
        compactMap { if case .document(let doc) = $0 { return doc } else { return nil } }
    }
}

// MARK: - ProseFormattedSpan

/// One run of editorial-prose text plus the concrete inline formatting decoded from a
/// Phase 3b rich-text blob. Bold/italic come from the run's `NSFont`/`UIFont` symbolic
/// traits, underline from the underline-style attribute, `colorHex` from the
/// foreground colour, and `linkURL` from the `.link` attribute (Session 2026-07-03 —
/// the editor's Link control; RTF round-trips it as a `HYPERLINK` field). Produced by
/// `CollectionProse.append(text:bold:italic:underline:colorHex:linkURL:to:)`, which the app's
/// `CollectionProse.paragraphs(fromRTF:)` calls for each run it reads, and a host's own reader
/// for each of its runs.
///
/// Version history:
///   1.0 — 2026-07-01: with `CollectionProse`
///   1.1 — 2026-10-25 (FRUS Explorer Light, S18a): moved to FRUSCoreKit, public, with its
///          initialiser spelled out
public struct ProseFormattedSpan: Sendable {
    /// The run's text. May contain single `\n` line breaks; paragraph breaks (blank
    /// lines) are already split out into separate paragraphs by the decoder.
    public let text: String
    /// `true` when the run's font carries the bold symbolic trait.
    public let bold: Bool
    /// `true` when the run's font carries the italic symbolic trait.
    public let italic: Bool
    /// `true` when the run carries a non-zero underline style.
    public let underline: Bool
    /// Uppercase `RRGGBB` (no leading `#`), or `nil` for (near-)black default text so
    /// ordinary prose isn't tagged with a redundant colour. The colour as the light
    /// appearance draws it, whatever appearance the export runs under, so typed text is
    /// `nil` in dark mode too (see `CollectionProse`).
    public let colorHex: String?
    /// The run's `.link` URL as a string, or `nil` for unlinked text. HTML renders it as
    /// an `<a href>`, DOCX as a real `<w:hyperlink>` relationship, PDF as underlined text
    /// followed by the visible URL (CoreText frame drawing has no link annotations).
    public let linkURL: String?

    /// Creates a span.
    public init(text: String, bold: Bool, italic: Bool, underline: Bool, colorHex: String?,
                linkURL: String?) {
        self.text = text
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.colorHex = colorHex
        self.linkURL = linkURL
    }
}

// MARK: - CollectionProse

/// The rules that turn a rich-text prose block's formatted runs into the paragraphs of
/// `ProseFormattedSpan` every exporter (HTML, DOCX, PDF) renders, so no format reads prose
/// formatting its own way. Blank lines (`"\n\n"`) split paragraphs; each paragraph is an ordered
/// list of spans covering its text.
///
/// The host decodes a stored block into runs and hands each run to `append`: the app reads the
/// editor's RTF, or a legacy Phase 3b JSON blob, with `paragraphs(fromRTF:)`, which stays in the
/// app with AppKit and UIKit (`CollectionExporter+App.swift`); FRUS Explorer Light reads the same
/// RTF with a codec of its own, held to the app's reading by golden spans. A colour reaches a span
/// as `hex(r:g:b:)` writes it, as the light appearance draws it (see the app's extension).
///
/// Version history:
///   1.0 — 2026-07-01: the shared decoder, as PDF and DOCX began rendering headings and prose
///   1.1 — 2026-07-02: a legacy Phase 3b JSON payload decodes instead of being dropped
///   1.2 — 2026-07-03: `linkURL`, from the editor's Link control
///   1.3 — Session 2026-10-24 (FRUS Explorer Light, S15d's follow-up): a colour is read as the
///          light appearance draws it, whatever appearance the export or the live preview runs
///          under, so typed text is no longer white in either when that appearance is dark
///   1.4 — Session 2026-10-25: a colour outside sRGB is clamped to it before it is formatted, so
///          iOS writes six hex digits for it, as the Mac does
///   1.5 — 2026-10-25 (FRUS Explorer Light, S18a): the span rules, `append(text:bold:italic:
///          underline:colorHex:linkURL:to:)` and `hex(r:g:b:)`, are FRUSCoreKit's and public; decoding
///          a stored block stays in the app, whose resolver now decodes it when it builds the item
public enum CollectionProse {
    /// Splits one formatted run on blank lines (`"\n\n"`) and appends the resulting spans,
    /// starting a new paragraph at each blank line — the single splitting rule both decode
    /// paths share.
    public static func append(text: String, bold: Bool, italic: Bool, underline: Bool,
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

    /// Formats an RGB triple as uppercase `RRGGBB`, returning `nil` for (near-)black so
    /// ordinary prose isn't tagged with a redundant colour.
    ///
    /// Each component is clamped to 0…1 first. UIKit reads a colour outside sRGB, such as a
    /// Display P3 red, back from RTF as extended sRGB (1.093, −0.227, −0.150), and `%02X` wrote
    /// that as `116FFFFFFC7FFFFFFDA`: no colour in HTML, and a `w:val` Word may call damaged. The
    /// Mac's `usingColorSpace(.sRGB)` already clamps, so both write `FF0000`. A component is
    /// still truncated, not rounded, so no colour inside sRGB changes its hex.
    public static func hex(r: CGFloat, g: CGFloat, b: CGFloat) -> String? {
        if r < 0.08, g < 0.08, b < 0.08 { return nil }   // (near-)black default text
        func byte(_ x: CGFloat) -> Int { Int(min(max(x, 0), 1) * 255) }
        return String(format: "%02X%02X%02X", byte(r), byte(g), byte(b))
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
///   1.5 — 2026-10-25 (FRUS Explorer Light, S18a): moved to FRUSCoreKit, public, so an exporter in
///          the kit conforms to it; the PDF exporter, the app's, conforms as before
public protocol CollectionExporter {
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
    public func export(
        metadata: CollectionExportMetadata,
        documents: [CollectionExportDocument],
        options: CollectionExportOptions = CollectionExportOptions()
    ) async throws -> URL {
        try await export(metadata: metadata, items: documents.map { .document($0) }, options: options)
    }

    /// Backward-compatible overload that uses default `CollectionExportOptions`.
    @MainActor
    public func export(
        metadata: CollectionExportMetadata,
        items: [CollectionExportItem]
    ) async throws -> URL {
        try await export(metadata: metadata, items: items, options: CollectionExportOptions())
    }
}

// MARK: - Source-note display

/// The one label rule every export surface applies to a stored source note (#960).
///
/// Post-1969 volumes' stored notes ALREADY lead with `Source:` — the TEI carries the label —
/// while every renderer prepends its own. Before this rule the doubling shipped in all three
/// formats **and the in-app preview** (the preview is the HTML renderer), masked in HTML from
/// naive search because the label carries markup (`<strong>Source:</strong> Source: …`).
/// Fixing it per-renderer would be three sites that can drift; this is the single point.
public enum SourceNoteDisplay {
    /// `sourceNote` without any leading `Source:` label, ready for a renderer that adds its own.
    public static func withoutLeadingLabel(_ sourceNote: String) -> String {
        var t = sourceNote.trimmingCharacters(in: .whitespaces)
        if let r = t.range(of: #"^Source\s*:\s*"#, options: [.regularExpression, .caseInsensitive]) {
            t.removeSubrange(r)
        }
        return t
    }
}

// MARK: - CollectionExportNaming

/// The name an export of a collection carries, in its title and in its file name (#1463).
///
/// A collection can be saved with no name: a reader clears it, or exports a new collection from its
/// editor before naming it — the editor names it "Untitled Collection" only when it closes. The export
/// sheet passed the saved name through, and each exporter named its file with a private sanitizer that
/// only replaced `/:\?%*|"<>`. So an unnamed collection exported as a hidden `.html`, `.docx`, `.pdf` or
/// `.bib` file (or as `-zotero.ris`) under a blank title, a name opening with a dot hid its file too,
/// and the live preview, which had a fallback of its own, was the one place that read "Untitled
/// Collection".
///
/// The title is #1359's rule for a collection listed by name, `CollectionEditorNaming.listName` — the
/// name trimmed, or "Untitled Collection" — applied by `CollectionExportMetadata.init`, so the HTML
/// `<title>` and heading, the Word and PDF covers and the word-cloud figure all print it. Every
/// exporter, and the shareable `.fruscollection` file, names its file through `fileName`.
///
/// Version history:
///   1.0 — #1463: initial implementation, replacing the five exporters' private `sanitized(_:)` and
///          the export sheet's inline copy of it for the native file
///   1.1 — #1498: `fileName` cuts a stem too long for the file system (`ExportFileName`); #1497:
///          `zoteroCollectionName`, the name of the Zotero collection a send creates
///   1.2 — 2026-10-25 (FRUS Explorer Light, S18a): moved to FRUSCoreKit, public, with
///          `CollectionEditorNaming`, whose `listName` the title is
public enum CollectionExportNaming {

    /// The characters a file name may not carry here, each written as `-` — the set that the five
    /// exporters' private sanitizers and the export sheet's inline copy, which this replaces, each
    /// wrote as `-`: the path separators `/` and `:`, and `\?%*|"<>`.
    private static let hostileCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")

    /// The title an export of a collection saved under `savedName` carries: the name trimmed, or
    /// "Untitled Collection" when it has no text — what a list row names the same collection.
    public static func title(savedName: String) -> String {
        CollectionEditorNaming.listName(savedName: savedName)
    }

    /// The file name an export of a collection saved under `savedName` is written under, ending in
    /// `suffix` (".html", "-zotero.ris"): its `title`, each hostile character written as `-`, with the
    /// dots and spaces that open it removed — so the file is never hidden. A title with nothing else
    /// in it names the file "Untitled Collection".
    ///
    /// A title too long for a file name is cut, on a whole character, so the name and its suffix fit
    /// (`ExportFileName`, #1498): uncut, a name past the file system's 255 UTF-16 units failed every
    /// format's write in the temporary directory. The export's title, and a `.fruscollection` file's own
    /// name field, keep the whole name; only the file's name is cut.
    public static func fileName(savedName: String, suffix: String) -> String {
        let written = title(savedName: savedName)
            .components(separatedBy: hostileCharacters)
            .joined(separator: "-")
        let stem = ExportFileName.fitting(String(written.drop(while: { $0 == "." || $0.isWhitespace })),
                                          reserving: ExportFileName.length(of: suffix))
        return (stem.isEmpty ? title(savedName: "") : stem) + suffix
    }

    /// The name of the Zotero collection a collection saved under `savedName` becomes when the export
    /// sheet sends it to the reader's Zotero library (#1497): the name trimmed, or "FRUS Explorer
    /// Collection - yyyy-mm-dd" for a collection with no name — the owner's decision D16 (2026-09-28).
    ///
    /// The send passed the saved name through untrimmed, and no name at all when it was empty, so an
    /// unnamed collection's items landed loose in the library, and a name of spaces made a Zotero
    /// collection named with spaces. Only the Zotero send reads this: a file export keeps "Untitled
    /// Collection" (`title`), while a send lands in a library that keeps every earlier one, where the
    /// day tells two unnamed sends apart.
    ///
    /// - Parameters:
    ///   - savedName: The collection's saved name, which may be empty or padded.
    ///   - date: When the send is made.
    ///   - timeZone: The zone the day is read in — the reader's own, so it is the day on their
    ///     calendar.
    public static func zoteroCollectionName(savedName: String, on date: Date = Date(),
                                            timeZone: TimeZone = .current) -> String {
        let trimmed = savedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return String(format: String(localized: "export.zotero.collection.untitled %@",
                                     defaultValue: "FRUS Explorer Collection - %@"),
                      formatter.string(from: date))
    }

    /// Where an export of a collection saved under `savedName` is written: `fileName(savedName:suffix:)`
    /// in the temporary directory.
    public static func temporaryFileURL(savedName: String, suffix: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName(savedName: savedName, suffix: suffix))
    }
}

// MARK: - ExportFileName

/// An export's file name, cut to fit the file system (#1498).
///
/// Nothing capped the names the app writes: a collection's name became its export's stem whole, and an analytics
/// figure's title its file's. Both now pass through here — `CollectionExportNaming.fileName`, which every collection
/// exporter and the `.fruscollection` writer name their file through, `AnalyticsExportDelivery.filenameStem`, and the
/// Archives Visit packet's PDF (`TripPacketPDFRenderer.fileName(title:)`).
///
/// **What the limit counts was measured, and it is not bytes** (review round 1, 2026-10-01, on APFS — the build Mac's
/// temporary directory, which is also where the iOS simulator writes). A name may take 255 UTF-16 units of its
/// canonically DECOMPOSED form, the form Foundation hands the file system: 255 `a` or 251 `外` and `.pdf` (757 bytes of
/// UTF-8) are written, and one more of either fails with errno 63, "File name too long" — the error
/// `CollectionExportNamingTests` met. A file URL holds its last component decomposed too: `appendingPathComponent`
/// returns `ǖ` (U+01D6, two bytes as typed) as `u` and two combining marks, five bytes. A character can decompose into
/// more units than it takes bytes as typed — `ǖ` is 2 bytes and 1 unit, but 3 units decomposed — so 118 of them and
/// `.pdf`, 240 bytes as typed, failed the write. The 2026-09-27 triage measured 255 and 256 with ASCII names, which
/// cannot tell bytes from units, and this type first budgeted the bytes as typed, which let that name through.
///
/// So `length(of:)` counts the UTF-8 bytes of the decomposed form. That is never less than the UTF-16 units APFS
/// counts (a scalar takes at least as many UTF-8 bytes as UTF-16 units), it is the same whichever form a name arrives
/// in, and it is what a file system that limits bytes would be handed — ext4 and most Linux file systems, behind a
/// share — which is reasoned, not measured. The cost falls on decomposing scripts: an accented letter counts 3, a
/// Hangul syllable 6 to 9.
///
/// Version history:
///   1.0 — #1498 and the 2026-09-28 audit's analytics stem: initial implementation
///   1.1 — #1498 review, round 1: `length(of:)` counts the decomposed form's UTF-8 bytes, which bounds the UTF-16 units
///          the file system counts, and `maxBytes` is `maxLength`; the trip packet's PDF names its file here too
///   1.2 — 2026-10-25 (FRUS Explorer Light, S18a): moved to FRUSCoreKit, public, with `CollectionExportNaming`
public enum ExportFileName {

    /// The longest a file name may be here, suffix included, by `length(of:)`: the file system's 255, less 15, so a
    /// name the system lengthens when the reader keeps a second copy beside the first — Finder adds " 2" — still fits.
    public static let maxLength = 240

    /// How long `name` is for a file name: the UTF-8 bytes of its canonically decomposed form, the form Foundation
    /// hands the file system. The count is additive over a string's characters and the same for every normalization
    /// of one name, so a name read back from a file URL — decomposed — measures what it measured when it was made.
    public static func length(of name: String) -> Int {
        name.decomposedStringWithCanonicalMapping.utf8.count
    }

    /// `stem` cut so that it, and `reservedLength` more, fit within `maxLength` by `length(of:)` — whole when it
    /// already fits. The cut falls between two characters, never inside one (a combining accent stays on its letter, a
    /// flag stays a flag), and any whitespace it leaves at the end is dropped.
    ///
    /// - Parameters:
    ///   - stem: The name's own part.
    ///   - reservedLength: The `length(of:)` of what the caller puts around it — a suffix, a prefix and a date.
    /// - Returns: The stem, cut to fit; empty when nothing fits.
    public static func fitting(_ stem: String, reserving reservedLength: Int) -> String {
        let budget = max(maxLength - reservedLength, 0)
        guard length(of: stem) > budget else { return stem }
        var used = 0
        var end = stem.startIndex
        for index in stem.indices {
            let size = length(of: String(stem[index]))
            if used + size > budget { break }
            used += size
            end = stem.index(after: index)
        }
        var cut = String(stem[..<end])
        while let last = cut.last, last.isWhitespace { cut.removeLast() }
        return cut
    }
}

// MARK: - CollectionWordCloud

/// A collection's word-cloud overview as an export embeds it: a PNG and its size in pixels
/// (#960, #1585). The HTML export embeds the PNG as a `data:` URL; the Word export stores it as
/// `word/media/wordcloud.png` and sizes its drawing by the pixels.
///
/// Version history:
///   1.0 — 2026-10-25 (FRUS Explorer Light, S18a): the image the HTML and Word exporters took from
///          the app's `WordCloudExporter.collectionCloudImage`, handed to them as data now that they
///          are FRUSCoreKit's
public struct CollectionWordCloud: Sendable {
    /// The image, as PNG.
    public let png: Data
    /// Its width in pixels.
    public let pixelWidth: Int
    /// Its height in pixels.
    public let pixelHeight: Int

    /// Creates a word-cloud image.
    public init(png: Data, pixelWidth: Int, pixelHeight: Int) {
        self.png = png
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}

/// Draws the word cloud of a collection's documents — their body texts, in order — titled with
/// the collection's name, or returns `nil` when there is nothing to count. The app draws it with its
/// own tokenizer and SwiftUI renderer (`CollectionWordCloud.drawnByTheApp`, in the app).
public typealias CollectionWordCloudDrawing = @MainActor (_ texts: [String], _ title: String) async -> CollectionWordCloud?

// MARK: - ExportError

/// Why a collection export failed: it could not be rendered, or its file could not be written.
/// FRUSCoreKit's since FRUS Explorer Light's S18a, with the exporters that throw it.
public enum ExportError: Error, LocalizedError {
    case renderingFailed
    case writeFailure(underlying: Error)

    public var errorDescription: String? {
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
