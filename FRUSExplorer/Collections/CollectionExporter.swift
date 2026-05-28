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

/// Rendering options passed to every exporter.
///
/// Version history:
///   1.0 — Session 128: initial implementation
struct CollectionExportOptions: Sendable {
    /// Which label style to use in the table of contents.
    var tocStyle: CollectionToCStyle = .citation
}

// MARK: - ExportFormat

/// Supported output formats for collection export.
///
/// Version history:
///   1.0 — Session 22: initial implementation
///   1.1 — Session 82: added `.docx` backed by `DocxCollectionExporter`
enum ExportFormat: String, CaseIterable, Identifiable {
    case pdf
    case html
    case docx

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pdf:  return "PDF"
        case .html: return "HTML"
        case .docx: return "DOCX"
        }
    }

    var fileExtension: String { rawValue }

    /// Returns a fresh exporter instance for this format.
    func makeExporter() -> any CollectionExporter {
        switch self {
        case .pdf:  return PDFCollectionExporter()
        case .html: return HTMLCollectionExporter()
        case .docx: return DocxCollectionExporter()
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
struct CollectionExportDocument: Sendable {
    /// The FRUS document identifier (e.g. `"d1"`).
    let documentId: String
    /// The containing volume identifier (e.g. `"frus1969-76v01"`).
    let volumeId: String
    /// Position within the collection (ascending).
    let sortOrder: Int
    /// Human-readable document title (volume title + document ID).
    let title: String
    /// ISO 8601 date string, if known.
    let date: String?
    /// Plain-text body of the document. Preserved as fallback when `renderModel` is nil.
    let bodyText: String
    /// Whether the exporter should include the full document body for this entry.
    let includeDocumentBody: Bool
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
    /// Used when `tocStyle == .headerAndDateline`.
    let header: String
    /// The dateline extracted from the TEI body. Used with `header` for the headerAndDateline ToC style.
    let dateline: String?

    /// Backward-compatible single-note accessor. Returns the first note text, or `nil` when empty.
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
        title: String,
        date: String? = nil,
        bodyText: String,
        includeDocumentBody: Bool = true,
        noteText: String? = nil,
        noteTexts: [String]? = nil,
        citation: String = "",
        historyStateGovURL: String = "",
        renderModel: FRUSDocumentRenderModel? = nil,
        header: String = "",
        dateline: String? = nil
    ) {
        self.documentId = documentId
        self.volumeId = volumeId
        self.sortOrder = sortOrder
        self.title = title
        self.date = date
        self.bodyText = bodyText
        self.includeDocumentBody = includeDocumentBody
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

// MARK: - CollectionExporter

/// Protocol for turning a `CollectionExportMetadata` + its resolved documents into a file on disk.
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
protocol CollectionExporter {
    /// Exports `metadata` and its `documents` to a temporary file using the given `options`.
    ///
    /// - Returns: A `file://` URL pointing to the written output.
    /// - Throws: `ExportError` on rendering or I/O failure.
    @MainActor
    func export(
        metadata: CollectionExportMetadata,
        documents: [CollectionExportDocument],
        options: CollectionExportOptions
    ) async throws -> URL
}

extension CollectionExporter {
    /// Backward-compatible overload that uses default `CollectionExportOptions`.
    @MainActor
    func export(
        metadata: CollectionExportMetadata,
        documents: [CollectionExportDocument]
    ) async throws -> URL {
        try await export(metadata: metadata, documents: documents, options: CollectionExportOptions())
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
