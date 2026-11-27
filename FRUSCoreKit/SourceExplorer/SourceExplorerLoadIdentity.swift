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
///   1.3 — index version 72: `SourceExplorerDocumentContext.storedClassification`, the one read both
///         views make of the marking the index stores, for a document that prints it in its opener
///   1.4 — 2026-11-10 (FRUS Explorer Light, S22b): moved into FRUSCoreKit with the classifier, whose
///         `documentYear(fromDateline:)` `hydrate` reads; `SourceExplorerDocumentContext` is public, since
///         `SourceExplorerResolution` holds it; `document(volumeId:documentId:rawSourceNote:documentYear:)`, the
///         key less the pipeline, for a view to tell a load of the document it shows from a load of another
///   1.5 — 2026-11-26 (#1976, plan of record row L31): `SourceExplorerDocumentContext` falls back to the index's
///         own date for a year the dateline does not give (`year(dateline:indexDateISO:)`, the owner's
///         decision 175), carries the days the pre-1906 section matches rolls by (`rollDates`), and gives the
///         Source Explorer export the same year for a parsed document (`year(of:)`)
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

    /// The document a load explains: the key with the pipeline's availability left out, so a view can tell
    /// a load of the document it already shows — shown again, refreshed, or reloaded as the index comes up —
    /// from a load of another, and keep what is on screen until each step replaces it
    /// (`SourceExplorerResolution.resolvingAgain()`).
    static func document(volumeId: String?, documentId: String?, rawSourceNote: String,
                         documentYear: Int?) -> String {
        make(volumeId: volumeId, documentId: documentId, rawSourceNote: rawSourceNote,
             documentYear: documentYear, pipelineAvailable: false)
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
public struct SourceExplorerDocumentContext: Sendable, Equatable {
    /// The header the classifier reads.
    public let header: String
    /// The dateline the classifier reads, or `nil`.
    public let dateline: String?
    /// The year every year-dependent section reads, or `nil`.
    public let year: Int?
    /// The serial FRUS prints above the document, from the index, or `nil`.
    public let despatchSerial: String?
    /// The days the pre-1906 section looks the document's own rolls up by, and where they come from.
    public let rollDates: CountrySeriesRollDates

    /// Fills in what the route did not supply. One rule per case:
    ///
    /// - **R1** — the route supplied a dateline: it wins, and so does the route's header unless that
    ///   is blank or is the document id (a placeholder), in which case the index header is used.
    /// - **R2** — no route dateline, and the index has a row: take BOTH the dateline and the header
    ///   from the index. A route that had no dateline had no real header either.
    /// - **R3** — no index row: keep the route's values.
    /// - **R4** — the serial always comes from the index.
    ///
    /// The year is the route's when it passed one, else ``year(dateline:indexDateISO:)``'s: the chosen
    /// dateline's, else the index's own date for the document (#1976, the owner's decision 175: "views
    /// fall back to the index's date"). A blank dateline counts as none. The roll dates are
    /// ``CountrySeriesRollDates/reading(dateline:indexed:)``'s.
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
            year: routeYear ?? year(dateline: dateline, indexDateISO: indexed?.dateISO),
            despatchSerial: indexed?.despatchSerial,
            rollDates: .reading(dateline: dateline, indexed: indexed))
    }

    /// The year Source Explorer gives a document from its dateline and its own date: the dateline's
    /// (`CentralFilesClassifier.documentYear(fromDateline:)`), else the date's, `yyyy-MM-dd` as
    /// `document_dates` stores it, else `nil`.
    ///
    /// The one rule the views' hydration and the Source Explorer export read a year by (#1976): the
    /// export read `frus:doc-dateTime-min` alone where the views read the dateline alone, and the two gave
    /// 8,175 documents of the catalogue different years.
    static func year(dateline: String?, indexDateISO: String?) -> Int? {
        CentralFilesClassifier.documentYear(fromDateline: dateline) ?? indexDateISO.flatMap { Int($0.prefix(4)) }
    }

    /// The year Source Explorer gives a parsed document, from the dateline and the first day the index
    /// stores for it: ``year(dateline:indexDateISO:)`` over `IndexingPipeline.extractDateline(from:)` and
    /// the first day of `IndexingPipeline.extractDateRange(from:dateTimeMin:dateTimeMax:)`, the two
    /// functions the index stores them by.
    ///
    /// For the Source Explorer export, which parses each volume as the index does
    /// (`FRUSDocumentParser.parseVolumeFull(volumeData:named:)`) and so reads the year the views hydrate
    /// from an index of the same file. `SourceExplorerEvaluationTests.yearOfAParseIsTheHydratedYear` holds the
    /// two to each other.
    ///
    /// - Parameter document: One document of a volume's parse.
    /// - Returns: The year, or `nil` when neither the dateline nor the document's date gives one.
    public static func year(of document: FRUSDocumentAST) -> Int? {
        year(dateline: IndexingPipeline.extractDateline(from: document.nodes),
             indexDateISO: IndexingPipeline.extractDateRange(from: document.nodes, dateTimeMin: document.dateTimeMin,
                                                             dateTimeMax: document.dateTimeMax).min)
    }

    /// The document's own day from the index (`IndexingPipeline.documentDay`), or `nil` when there
    /// is no pipeline, no document key, no day at day grain, or the read fails (#1407 review).
    ///
    /// Both views read it through `SourceExplorerResolution.resolved` and hand it to
    /// `DecimalFileSegment` — the iOS view for its Archival Neighbors basis line and Filing Period row,
    /// the Mac window for its Filing Period box — so a date-form file number that misprints the
    /// document's own day under another year (`740.0011 EW/8–2045` on a document of 20 August 1943) is
    /// banded by the document's year, as the neighbours beside it are. One function, so the two views
    /// cannot read the day two ways.
    static func documentDay(pipeline: IndexingPipeline?, volumeId: String?,
                            documentId: String?) async -> DecimalFileSegment.DocumentDay? {
        guard let pipeline, let volumeId, let documentId else { return nil }
        return (try? await pipeline.documentDay(volumeId: volumeId, documentId: documentId)) ?? nil
    }

    /// The classification marking the index stores for the document
    /// (`IndexingPipeline.storedClassification`), or `nil` when there is no pipeline, no document key,
    /// no stored marking, or the read fails.
    ///
    /// Both views read it through `SourceExplorerResolution.resolved` and show
    /// `IndexingPipeline.classificationMarking(sourceNote:stored:)` beside the note, so a document of the
    /// volumes covering 1932–1954, which prints its marking in its opener rather than its note (index
    /// version 72), has its chip, as its search row does. One function, so the two views cannot read it
    /// two ways.
    static func storedClassification(pipeline: IndexingPipeline?, volumeId: String?,
                                     documentId: String?) async -> String? {
        guard let pipeline, let volumeId, let documentId else { return nil }
        return (try? await pipeline.storedClassification(volumeId: volumeId, documentId: documentId)) ?? nil
    }

    /// `value`, or `nil` when it is absent, empty, or only whitespace.
    private static func nonBlank(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }
}
