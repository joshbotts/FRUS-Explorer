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
/// for the Sources block. Two things are shared rather than re-derived:
///
/// - **the display label** (`tripPacketLabel`) — so a packet group reads like a Sources-block
///   group;
/// - **the query** — both reach `IndexingPipeline.documentSourcesByKey`, so neither can see a
///   different set of source notes.
///
/// **The grouping key deliberately diverges** (Phase 1, §2b): the Sources block's key rides the
/// per-document file identifier for central files (it lands in `seriesName`), which is document
/// grain, not unit grain — measured, a 30-document pre-1950 project minted ~25 groups where a
/// researcher consults perhaps three classes. The packet's targets key on the FORM-AWARE unit
/// (`targetKey(for:category:)`), because a target is the thing a researcher asks an archivist
/// about.
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
///   1.2 — Archive Visits Phase 1: form-aware target keys (§2b — the class grain for central
///          files, `lotFileNorm` folding for lots) and the pointed-at channel
///          (`external_citations` through ``TripPacketReferenceDataSource``)
@MainActor
enum TripPacketBuilder {

    /// Builds the packet model for a document set.
    ///
    /// - Parameters:
    ///   - documents: the reading list — a project's engaged set, or a collection's documents.
    ///   - researchQuestion: seeds the inquiry's topic sentence (D8).
    ///   - dataSource: the same source the collection blocks use, refined with the packet's
    ///     one extra query (the refs channel).
    ///
    /// `@MainActor`, matching `CollectionGeneratedBlockDataSource` and every existing caller of it:
    /// the heavy work happens inside the awaited pipeline calls, off the main thread.
    static func build(
        documents: [(volumeId: String, documentId: String)],
        researchQuestion: String?,
        dataSource: some TripPacketReferenceDataSource
    ) async -> TripPacketModel {
        let records = await dataSource.documentSources(for: documents)
        let dates = await dataSource.dateMetadata(for: documents)
        let externalCitations = await dataSource.externalCitations(for: documents)

        let recordsByKey = Dictionary(
            records.map { ("\($0.volumeId)/\($0.documentId)", $0) },
            uniquingKeysWith: { first, _ in first })

        // ── The drawn-from channel, under the FORM-AWARE keys of §2b. Phase 0's packet
        // grouped by `tripPacketGroupKey`, which is the Sources block's key — and for
        // central files that key rides the per-document file identifier (it lands in
        // `seriesName`), so a 30-document pre-1950 project minted ~25 "targets" where a
        // researcher consults perhaps three classes. The target grain is the UNIT a
        // researcher asks an archivist about: the class for central files, the lot for lot
        // files (folded by `lotFileNorm`, the same normalizer `external_citations` stores,
        // so the two channels merge exactly), the repository|collection pair for libraries,
        // and the raw text when nothing parsed — claim-free, because the claim lives on the
        // seeding (§2).
        var grouped: [String: (record: CollectionGeneratedBlocks.SourceRecord,
                               label: String,
                               lotAsPrinted: String?,
                               documents: [TripPacketModel.Group.DocumentRef])] = [:]
        var order: [String] = []
        var placed = 0
        // The substitute lookup's input, one entry per PLACED document. A document with no
        // indexed source note contributes nothing rather than a nil: it was never testable,
        // and counting it as a tested miss would understate the coverage report. The year
        // rides along because it, not the number's form, is what separates the two
        // substitute routes; the document key is what lets the per-seeding markers land.
        var citedFiles: [MandatorySubstitutes.CitedFile] = []
        let parser = SourceNoteParser()
        for document in documents {
            let documentKey = "\(document.volumeId)/\(document.documentId)"
            guard let record = recordsByKey[documentKey] else {
                continue   // no source note indexed — counted as unresolved below
            }
            placed += 1
            // One parse per document, consumed twice: the substitute lookup keeps its
            // deliberately-narrow central-file identifier, and the seeding row keeps
            // whatever file or folder designation the note carries.
            let parsed = parser.parse(record.rawText)
            citedFiles.append(.init(
                identifier: Self.centralFileIdentifier(from: parsed),
                year: dates[documentKey].flatMap { Int($0.dateISO.prefix(4)) },
                documentKey: documentKey))
            let category = record.citationEra.map {
                SourceProvenanceCategory.from(citationEra: $0, repository: record.repository)
            }
            let keyed = Self.targetKey(for: record, category: category)
            if grouped[keyed.key] == nil {
                grouped[keyed.key] = (record, keyed.label, keyed.lotAsPrinted, [])
                order.append(keyed.key)
            }
            grouped[keyed.key]?.documents.append(.init(
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
                                                lotAsPrinted: String?,
                                                resolution: ArchivalResolution?,
                                                documents: [TripPacketModel.Group.DocumentRef])? in
            guard let entry = grouped[key] else { return nil }
            let record = entry.record
            // The parser's own classification, never a second one derived from the parsed fields.
            let category = record.citationEra.map {
                SourceProvenanceCategory.from(citationEra: $0, repository: record.repository)
            }
            return (key: key,
                    label: entry.label,
                    category: category,
                    repository: record.repository,
                    lotAsPrinted: entry.lotAsPrinted,
                    // The WHOLE resolution — reducing it to `.naId` here is exactly what
                    // starved chapters 2, 3, 5 and 6 of the fields the app already knows.
                    resolution: ArchivalResolver.documentResolution(lotFile: record.lotFile),
                    documents: entry.documents)
        }

        // A lot citation that produced no series is exactly A4's "lot numbers do not always carry
        // over" case. Counted at GROUP grain, because the criterion is about the citation.
        let unresolvedLots = groups.filter { $0.category == .lotFile && $0.resolution == nil }.count

        // ── The pointed-at channel (§2): footnotes citing archival units FRUS did not print
        // from. Lot and library citations only — the class anchor is deferred by design
        // (#784's own scope), and admitting it would flood the packet with the corpus's
        // commonest footnote idiom. Keys share the drawn-from vocabulary above, so a unit
        // cited both ways becomes ONE target with both claims itemized inside it.
        var refGrouped: [String: (form: TripPacketModel.Target.Form, label: String,
                                  repository: String?, lotAsPrinted: String?,
                                  seedings: [TripPacketModel.RefSeeding])] = [:]
        var refOrder: [String] = []
        var documentsWithReferences = 0
        for document in documents {
            let documentKey = "\(document.volumeId)/\(document.documentId)"
            let relevant = (externalCitations[documentKey] ?? [])
                .filter { $0.anchor != "centralFileClass" }
            guard !relevant.isEmpty else { continue }
            documentsWithReferences += 1
            for citation in relevant {
                let keyed = Self.referenceKey(for: citation)
                if refGrouped[keyed.key] == nil {
                    refGrouped[keyed.key] = (keyed.form, keyed.label,
                                             citation.repository, keyed.lotAsPrinted, [])
                    refOrder.append(keyed.key)
                }
                refGrouped[keyed.key]?.seedings.append(.init(
                    volumeId: document.volumeId,
                    documentId: document.documentId,
                    citation: dataSource.citation(volumeId: document.volumeId,
                                                  documentId: document.documentId),
                    // The stored ordinal counts body footnotes from zero; readers count
                    // from one, and the printed marker is what they will look for.
                    footnoteNumber: citation.noteOrdinal + 1,
                    rawText: citation.rawText,
                    inherited: citation.inherited))
            }
        }
        let references = refOrder.compactMap { key -> (key: String,
                                                       form: TripPacketModel.Target.Form,
                                                       label: String, repository: String?,
                                                       lotAsPrinted: String?,
                                                       seedings: [TripPacketModel.RefSeeding])? in
            guard let entry = refGrouped[key] else { return nil }
            return (key: key, form: entry.form, label: entry.label,
                    repository: entry.repository, lotAsPrinted: entry.lotAsPrinted,
                    seedings: entry.seedings)
        }

        return TripPacketModel.build(
            groups: groups,
            documentYears: documents.map { document in
                dates["\(document.volumeId)/\(document.documentId)"]
                    .flatMap { Int($0.dateISO.prefix(4)) }
            },
            citedFiles: citedFiles,
            unresolvedLotCount: unresolvedLots,
            // Documents whose source note was never indexed. Reported rather than dropped — the
            // coverage report says so, because a packet silently covering part of a reading list
            // reads as a clean bill of health for the rest.
            unresolvedDocumentCount: documents.count - placed,
            researchQuestion: researchQuestion,
            references: references,
            // Scanned means the documents handed to this builder: the seed resolver already
            // dropped what this device cannot read, so every remaining document's volume has
            // an indexed `external_citations` table. The report's job is to keep a thin
            // channel reading as sparse data (references sit on a small minority of
            // documents corpus-wide), never as a failed scan.
            referenceCoverage: .init(documentsWithReferences: documentsWithReferences,
                                     documentsScanned: documents.count))
    }

    // MARK: - Target keys (§2b)

    /// The form-aware, claim-free key for a drawn-from source record, with its display label
    /// and — for lots — the citation as printed, which the claimants lookup folds itself.
    ///
    /// | form | key | why this grain |
    /// |---|---|---|
    /// | central file | `class\|611.51` | the class is what a researcher consults; the file number is the seeding's detail |
    /// | lot file | `lot\|60D627` | `lotFileNorm`, the normalizer `external_citations` stores — merge parity by construction |
    /// | library / collection | `coll\|repo\|series` | the box/folder is the seeding's detail |
    /// | unparsed | `r\|<raw>` | distinct notes must never merge on a guess |
    ///
    /// The model reads these prefixes back into ``TripPacketModel/Target/Form`` — the two
    /// switch statements must agree, and `TripPacketBuilderTests` pins the round trip.
    static func targetKey(
        for record: CollectionGeneratedBlocks.SourceRecord,
        category: SourceProvenanceCategory?
    ) -> (key: String, label: String, lotAsPrinted: String?) {
        switch category {
        case .centralDecimalFile, .centralForeignPolicyFile:
            // The canonical class function — the same grammar `document_sources.decimal_class`
            // stores, so this grain matches the archival-analytics vocabulary.
            if let cls = SourceNoteParser.decimalClassLocation(inCitation: record.rawText) {
                // By the FORM of the designator, not the era field: a letter-led leaf is
                // subject-numeric whatever year the document carries.
                let label = cls.first?.isLetter == true
                    ? "Subject-Numeric File \(cls)"
                    : "Central Decimal File \(cls)"
                return ("class|\(cls)", label, nil)
            }
            return ("r|\(record.rawText)",
                    CollectionGeneratedBlocks.tripPacketLabel(for: record), nil)
        case .lotFile:
            if let lot = record.lotFile, !lot.isEmpty {
                return ("lot|\(SourceNoteParser.lotFileNorm(lot))",
                        CollectionGeneratedBlocks.tripPacketLabel(for: record), lot)
            }
            return ("r|\(record.rawText)",
                    CollectionGeneratedBlocks.tripPacketLabel(for: record), nil)
        default:
            let repository = record.repository ?? ""
            let series = record.seriesName ?? ""
            if !repository.isEmpty || !series.isEmpty {
                return ("coll|\(repository)|\(series)",
                        CollectionGeneratedBlocks.tripPacketLabel(for: record), nil)
            }
            return ("r|\(record.rawText)",
                    CollectionGeneratedBlocks.tripPacketLabel(for: record), nil)
        }
    }

    /// The same key vocabulary for a footnote citation — what makes a unit cited both ways
    /// land on ONE target.
    static func referenceKey(
        for citation: ExternalCitation
    ) -> (key: String, form: TripPacketModel.Target.Form, label: String, lotAsPrinted: String?) {
        if citation.anchor == "lotFile", let norm = citation.lotFileNorm, !norm.isEmpty {
            let label = citation.lotFile.map { "Lot \($0)" } ?? norm
            return ("lot|\(norm)", .lotFile, label, citation.lotFile)
        }
        let repository = citation.repository ?? ""
        let collection = citation.collection ?? ""
        if !repository.isEmpty || !collection.isEmpty {
            return ("coll|\(repository)|\(collection)", .collection,
                    citation.displayLabel, nil)
        }
        // A citation naming neither a lot nor a place: keyed on its raw text, exactly as an
        // unparsed source note is, so distinct citations never merge.
        return ("r|\(citation.rawText)", .raw, citation.displayLabel, nil)
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

// MARK: - TripPacketReferenceDataSource

/// The packet's refs-channel requirement — a REFINEMENT of `CollectionGeneratedBlockDataSource`
/// rather than an addition to it, because the collection blocks never read `external_citations`
/// and a requirement there would force every collections conformer to implement a query only
/// the packet runs. `TripPacketBuilder.build` requires the refinement, so there is no silent
/// "data source without references" path: a caller either supplies the query or does not compile.
@MainActor
protocol TripPacketReferenceDataSource: CollectionGeneratedBlockDataSource {
    /// The documents' `external_citations` rows, keyed `volumeId/documentId`, in
    /// `(noteOrdinal, citationIndex)` order within each document — where FRUS's editorial
    /// footnotes point OUTSIDE the printed record (#784). A document with no references is
    /// simply absent.
    func externalCitations(
        for documents: [(volumeId: String, documentId: String)]
    ) async -> [String: [ExternalCitation]]
}

// MARK: - TripPacketDataSource

/// The packet's own conformance to ``TripPacketReferenceDataSource`` (#830 T-2, refs Phase 1).
///
/// Exists because `LiveGeneratedBlockDataSource` is built around a collection's `BatchContext`, and
/// the Project Home entry point has no collection. It calls the **same pipeline methods**, so the
/// two cannot see different source notes; only the batch plumbing differs.
///
/// The three members the packet never reads return empty rather than trapping: this type conforms
/// to a protocol written for a richer consumer, and pretending otherwise would invite someone to
/// wire a packet chapter to a method that has never been exercised.
@MainActor
struct TripPacketDataSource: TripPacketReferenceDataSource {

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

    func externalCitations(
        for documents: [(volumeId: String, documentId: String)]
    ) async -> [String: [ExternalCitation]] {
        (try? await pipeline.externalCitationsByKey(documents)) ?? [:]
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
