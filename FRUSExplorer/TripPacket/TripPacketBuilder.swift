// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

// MARK: - TripPacketBuilder

/// Turns a set of documents into a ``TripPacketModel`` (#830 T-2).
///
/// ## What is shared with the Sources block, precisely
/// The scope doc says both entry points "feed the same aggregation: documents → parses →
/// resolutions → repository/RG/series rollup", and `CollectionGeneratedBlocks` already walks that
/// for the Sources block. Two things are therefore shared rather than re-derived:
///
/// - **the grouping key and label** (`tripPacketGroupKey` / `tripPacketLabel`) — so a packet group
///   IS a Sources-block group rather than merely resembling one. Two surfaces disagreeing about
///   which archives a project draws on would be an invisible defect;
/// - **the query** — both reach `IndexingPipeline.documentSourcesByKey`, so neither can see a
///   different set of source notes.
///
/// What is NOT shared is the data-source *instance*. `LiveGeneratedBlockDataSource` is built around
/// a collection's `BatchContext`, and the Project Home entry point has no collection — it works
/// over a project's engaged set. So the packet supplies its own thin conformance
/// (``TripPacketDataSource``) over the same pipeline calls. The parts that could drift are shared;
/// the part that cannot is not.
///
/// ## What it adds that the Sources block does not need
/// The packet needs three things the block never asked for: the provenance CATEGORY (which decides
/// the facility), the series NAID (which reaches NARA's own restriction and reference-unit data),
/// and each document's YEAR (for the A4 date test). The first now rides on `SourceRecord`; the
/// other two come from the resolver and the date metadata the data source already vends.
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-2
///   1.1 — Session 2026-08-22: #830 T-3, per-document cited file numbers for chapter 4
@MainActor
enum TripPacketBuilder {

    /// Builds the packet model for a document set.
    ///
    /// - Parameters:
    ///   - documents: the reading list — a project's engaged set, or a collection's documents.
    ///   - researchQuestion: seeds the inquiry's topic sentence (D8).
    ///   - dataSource: the same source the collection blocks use.
    ///
    /// `@MainActor`, matching `CollectionGeneratedBlockDataSource` and every existing caller of it:
    /// the heavy work happens inside the awaited pipeline calls, off the main thread.
    static func build(
        documents: [(volumeId: String, documentId: String)],
        researchQuestion: String?,
        dataSource: some CollectionGeneratedBlockDataSource
    ) async -> TripPacketModel {
        let records = await dataSource.documentSources(for: documents)
        let dates = await dataSource.dateMetadata(for: documents)

        // Group by the SAME key the Sources block uses, so the two surfaces cannot disagree about
        // what a group is.
        let recordsByKey = Dictionary(
            records.map { ("\($0.volumeId)/\($0.documentId)", $0) },
            uniquingKeysWith: { first, _ in first })

        var grouped: [String: (record: CollectionGeneratedBlocks.SourceRecord,
                               documents: [TripPacketModel.Group.DocumentRef])] = [:]
        var order: [String] = []
        var placed = 0
        // Chapter 4's input, one entry per PLACED document. A document with no indexed source note
        // contributes nothing rather than a nil: it was never testable, and counting it as a tested
        // miss would understate the chapter's own coverage. The year rides along because it, not
        // the number's form, is what separates the two substitute routes.
        var citedFiles: [MandatorySubstitutes.CitedFile] = []
        let parser = SourceNoteParser()
        for document in documents {
            let documentKey = "\(document.volumeId)/\(document.documentId)"
            guard let record = recordsByKey[documentKey] else {
                continue   // no source note indexed — counted as unresolved below
            }
            placed += 1
            // One parse per document, consumed twice: chapter 4's substitute lookup keeps
            // its deliberately-narrow central-file identifier, and the roster row keeps
            // whatever file or folder designation the note carries.
            let parsed = parser.parse(record.rawText)
            citedFiles.append(.init(
                identifier: Self.centralFileIdentifier(from: parsed),
                year: dates[documentKey].flatMap { Int($0.dateISO.prefix(4)) }))
            let key = CollectionGeneratedBlocks.tripPacketGroupKey(for: record)
            if grouped[key] == nil {
                grouped[key] = (record, [])
                order.append(key)
            }
            grouped[key]?.documents.append(.init(
                volumeId: document.volumeId,
                documentId: document.documentId,
                citation: dataSource.citation(volumeId: document.volumeId,
                                              documentId: document.documentId),
                fileDesignation: Self.fileDesignation(from: parsed),
                sourceNote: record.rawText))
        }

        let groups = order.compactMap { key -> (key: String, label: String,
                                                category: SourceProvenanceCategory?,
                                                repository: String?,
                                                resolution: ArchivalResolution?,
                                                documents: [TripPacketModel.Group.DocumentRef])? in
            guard let entry = grouped[key] else { return nil }
            let record = entry.record
            // The parser's own classification, never a second one derived from the parsed fields.
            let category = record.citationEra.map {
                SourceProvenanceCategory.from(citationEra: $0, repository: record.repository)
            }
            return (key: key,
                    label: CollectionGeneratedBlocks.tripPacketLabel(for: record),
                    category: category,
                    repository: record.repository,
                    // The WHOLE resolution — reducing it to `.naId` here is exactly what
                    // starved chapters 2, 3, 5 and 6 of the fields the app already knows.
                    resolution: ArchivalResolver.documentResolution(lotFile: record.lotFile),
                    documents: entry.documents)
        }

        // A lot citation that produced no series is exactly A4's "lot numbers do not always carry
        // over" case. Counted at GROUP grain, because the criterion is about the citation.
        let unresolvedLots = groups.filter { $0.category == .lotFile && $0.resolution == nil }.count

        return TripPacketModel.build(
            groups: groups,
            documentYears: documents.map { document in
                dates["\(document.volumeId)/\(document.documentId)"]
                    .flatMap { Int($0.dateISO.prefix(4)) }
            },
            citedFiles: citedFiles,
            unresolvedLotCount: unresolvedLots,
            // Documents whose source note was never indexed. Reported rather than dropped — the
            // triage says so, because a packet silently covering part of a reading list reads as a
            // clean bill of health for the rest.
            unresolvedDocumentCount: documents.count - placed,
            researchQuestion: researchQuestion)
    }

    /// The central-file number a source note cites, or `nil`.
    ///
    /// **Deliberately narrower than "any file identifier the parser found."** Chapter 4 has exactly
    /// two lookups — decimal serial ranges and 1906–1910 case numbers — and both live under
    /// ``ParsedSourceNote/centralFiles(recordGroup:fileIdentifier:)``. The other cases also carry a
    /// `fileIdentifier`, but a lot file's is a folder designation and a library's is a box or
    /// folder, so feeding either in would add documents to ``MandatorySubstitutes/documentsTested``
    /// that no route could ever match — inflating the denominator and making the chapter report a
    /// worse hit rate than it earned, over documents it never actually tested.
    ///
    /// `.cfpfFile` is excluded for a data reason rather than a shape one: the digitised-range index
    /// covers the Central Decimal File's NAIDs, and the CFPF is a different series, so a 1973–79
    /// citation cannot land in it.
    static func centralFileIdentifier(in sourceNote: String,
                                      parser: SourceNoteParser = SourceNoteParser()) -> String? {
        centralFileIdentifier(from: parser.parse(sourceNote))
    }

    /// The same rule over an already-parsed note, so the builder parses once.
    static func centralFileIdentifier(from parsed: ParsedSourceNote) -> String? {
        guard case .centralFiles(_, let fileIdentifier) = parsed else { return nil }
        return fileIdentifier
    }

    /// The file or folder designation for a roster row — DELIBERATELY WIDER than
    /// ``centralFileIdentifier(from:)``, and the two must not be merged: chapter 4's rule
    /// excludes lot folders and library boxes because they would inflate its tested
    /// denominator, while chapter 3's roster wants exactly those designations, because a
    /// pull slip is written against whatever the note names.
    static func fileDesignation(from parsed: ParsedSourceNote) -> String? {
        switch parsed {
        case .centralFiles(_, let fileIdentifier):               return fileIdentifier
        case .cfpfFile(let fileIdentifier):                      return fileIdentifier
        case .lotFile(_, _, let fileIdentifier):                 return fileIdentifier
        case .presidentialLibrary(_, _, let fileIdentifier):     return fileIdentifier
        case .namedFileSeries(_, let fileIdentifier):            return fileIdentifier
        default:                                                 return nil
        }
    }
}

// MARK: - TripPacketDataSource

/// The packet's own conformance to ``CollectionGeneratedBlockDataSource`` (#830 T-2).
///
/// Exists because `LiveGeneratedBlockDataSource` is built around a collection's `BatchContext`, and
/// the Project Home entry point has no collection. It calls the **same pipeline methods**, so the
/// two cannot see different source notes; only the batch plumbing differs.
///
/// The three members the packet never reads return empty rather than trapping: this type conforms
/// to a protocol written for a richer consumer, and pretending otherwise would invite someone to
/// wire a packet chapter to a method that has never been exercised.
@MainActor
struct TripPacketDataSource: CollectionGeneratedBlockDataSource {

    /// The pipeline every method reads through.
    let pipeline: IndexingPipeline

    /// The manifest entries the citation formatter reads — the same
    /// `diffResult?.known ?? bundledEntries` set `CollectionContentResolver` batches.
    let manifestMap: [String: VolumeManifestEntry]

    /// The house citation style — a pure struct, so held rather than re-made per call.
    private let formatter = HistoryAtStateCitationFormatter()

    init(pipeline: IndexingPipeline, manifestMap: [String: VolumeManifestEntry] = [:]) {
        self.pipeline = pipeline
        self.manifestMap = manifestMap
    }

    /// The history.state.gov-style citation — the exact mirror of
    /// `CollectionContentResolver.shortCitation`, header-independent by the same design:
    /// the formatter reads only volume metadata and the document number, so no volume XML
    /// is ever needed. This used to return the protocol's documented UNKNOWN-VOLUME
    /// fallback unconditionally, so the first chapter to print a citation would have
    /// printed `frus1948v02/d123` for every document.
    func citation(volumeId: String, documentId: String) -> String {
        let docNum: String? = documentId.hasPrefix("d")
            ? Int(documentId.dropFirst()).map { String($0) }
            : nil
        let docMeta = FRUSDocumentMetadata(
            documentId: documentId, documentNumber: docNum,
            header: "", dateline: nil)
        return manifestMap[volumeId]
            .map { formatter.format(document: docMeta, volume: FRUSVolumeMetadata($0)) }
            ?? "\(volumeId)/\(documentId)"
    }

    func dateMetadata(
        for documents: [(volumeId: String, documentId: String)]
    ) async -> [String: DocumentDateMetadata] {
        (try? await pipeline.dateMetadataByDocumentKey(documents)) ?? [:]
    }

    func documentSources(
        for documents: [(volumeId: String, documentId: String)]
    ) async -> [CollectionGeneratedBlocks.SourceRecord] {
        let rows = (try? await pipeline.documentSourcesByKey(documents)) ?? [:]
        return rows.values.map {
            CollectionGeneratedBlocks.SourceRecord(
                volumeId: $0.volumeId, documentId: $0.documentId, repository: $0.repository,
                recordGroup: $0.recordGroup, lotFile: $0.lotFile, seriesName: $0.seriesName,
                rawText: $0.rawText, citationEra: $0.citationEra)
        }
    }

    // Unused by the packet — see the type's note.
    func archivalResolution(recordGroup: String?, lotFile: String?)
        -> CollectionGeneratedBlocks.ArchivalLink? { nil }
    func personMentions(
        for documents: [(volumeId: String, documentId: String)]
    ) async -> [CollectionGeneratedBlocks.PersonMention] { [] }
    func tagRecords() async -> [CollectionGeneratedBlocks.TagRecord] { [] }
}
