// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - MacSourceExplorerLoadIdentity

/// The `.task(id:)` key both Source Explorer views use to decide that the document being
/// explained has changed.
///
/// ## The bug it exists to prevent
/// `MacSourceExplorerView` lives inside a persistent `Window`, not a sheet: SwiftUI keeps one
/// view instance alive and swaps its properties as the user opens documents. With a bare
/// `.task`, `load()` ran **once, ever** — so `rawSourceNote`, read directly in `body`,
/// tracked the current document while the parsed lot number, record group, archival
/// collection, NARA query and results all stayed pinned to whichever document was open
/// first. On screen that reads as one document's source note above another document's
/// provenance, which is worse than showing nothing.
///
/// Shared rather than duplicated because the iOS view keys on the same identity, and the two
/// Source Explorer views have drifted before.
///
/// Version history:
///   1.0 — Session 2026-08-04: N-8 stale-state fix
///   1.1 — 2026-09-13: pipeline availability joins the key, and `SourceExplorerDocumentContext`
///         fills in the header, dateline and serial a route did not supply
///   1.2 — 2026-09-26: #1407 review, round 1 — `SourceExplorerDocumentContext.documentDay`, the one
///         read both views make of the document's own day
enum MacSourceExplorerLoadIdentity {

    /// A key that changes whenever anything `load()` reads changes.
    ///
    /// Includes the raw note as well as the identifiers because some hosts pass no
    /// `documentId`, and because two documents sharing a note byte-for-byte are, for this
    /// view's purposes, the same citation. Joined on U+001F (unit separator) so a value
    /// containing the delimiter cannot forge a different key.
    ///
    /// `pipelineAvailable` is there because the pipeline is created once, after launch: a window
    /// restored at cold launch rendered before it existed, and with the key unchanged its load never
    /// re-ran — so it said "not checked" forever. It has no default, so a view cannot leave it out.
    /// A Bool suffices while the pipeline is assigned exactly once.
    static func make(volumeId: String?, documentId: String?,
                     rawSourceNote: String, documentYear: Int?, pipelineAvailable: Bool) -> String {
        [volumeId ?? "", documentId ?? "", documentYear.map(String.init) ?? "", rawSourceNote,
         pipelineAvailable ? "pipeline" : ""]
            .joined(separator: "\u{1F}")
    }
}

// MARK: - SourceExplorerDocumentContext

/// The document Source Explorer explains, with the opening route's gaps filled from the index.
///
/// Several routes open Source Explorer with the xml:id for a header and no dateline — History, a
/// related-document tap, a restored window — and a pre-1906 document with no dateline cannot be
/// placed. The index holds both, so the view hydrates from it instead of every host having to.
///
/// **Hydrated values stay out of the load key.** The key reads only what the host passed; hydration
/// writes view state. Keying on a hydrated value would reload the view every time it hydrated.
struct SourceExplorerDocumentContext: Sendable, Equatable {
    /// The header the classifier reads.
    let header: String
    /// The dateline the classifier reads, or `nil`.
    let dateline: String?
    /// The year every year-dependent section reads, or `nil`.
    let year: Int?
    /// The serial FRUS prints above the document, from the index, or `nil`.
    let despatchSerial: String?

    /// Fills in what the route did not supply. One rule per case:
    ///
    /// - **R1** — the route supplied a dateline: it wins, and so does the route's header unless that
    ///   is blank or is the document id (a placeholder), in which case the index header is used.
    /// - **R2** — no route dateline, and the index has a row: take BOTH the dateline and the header
    ///   from the index. A route that had no dateline had no real header either.
    /// - **R3** — no index row: keep the route's values.
    /// - **R4** — the serial always comes from the index.
    ///
    /// The year is the route's when it passed one, else the chosen dateline's
    /// (`CentralFilesClassifier.documentYear(fromDateline:)`). A blank dateline counts as none.
    static func hydrate(routeHeader: String?, routeDateline: String?, routeYear: Int?,
                        documentId: String?,
                        indexed: IndexingPipeline.SourceExplorerFacts?) -> SourceExplorerDocumentContext {
        let routeDatelineValue = nonBlank(routeDateline)
        let header: String
        let dateline: String?
        if let routeDatelineValue {
            dateline = routeDatelineValue
            let trimmed = routeHeader?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let placeholder = trimmed.isEmpty || trimmed == documentId
            header = placeholder ? (indexed?.header ?? routeHeader ?? "") : (routeHeader ?? "")
        } else if let indexed {
            dateline = nonBlank(indexed.dateline)
            header = indexed.header
        } else {
            dateline = nil
            header = routeHeader ?? ""
        }
        return SourceExplorerDocumentContext(
            header: header, dateline: dateline,
            year: routeYear ?? CentralFilesClassifier.documentYear(fromDateline: dateline),
            despatchSerial: indexed?.despatchSerial)
    }

    /// The document's own day from the index (`IndexingPipeline.documentDay`), or `nil` when there
    /// is no pipeline, no document key, no day at day grain, or the read fails (#1407 review).
    ///
    /// Both views read it in `load()` and hand it to `DecimalFileSegment` — the iOS view for its
    /// Archival Neighbors basis line and Filing Period row, the Mac window for its Filing Period
    /// box — so a date-form file number that misprints the document's own day under another year
    /// (`740.0011 EW/8–2045` on a document of 20 August 1943) is banded by the document's year, as
    /// the neighbours beside it are. One function, so the two views cannot read the day two ways.
    static func documentDay(pipeline: IndexingPipeline?, volumeId: String?,
                            documentId: String?) async -> DecimalFileSegment.DocumentDay? {
        guard let pipeline, let volumeId, let documentId else { return nil }
        return (try? await pipeline.documentDay(volumeId: volumeId, documentId: documentId)) ?? nil
    }

    /// `value`, or `nil` when it is absent, empty, or only whitespace.
    private static func nonBlank(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }
}
