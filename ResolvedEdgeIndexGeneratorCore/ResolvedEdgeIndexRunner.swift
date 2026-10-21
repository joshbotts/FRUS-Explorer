// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CrossRefKit
import CrossRefValidationGeneratorCore
import FRUSCoreKit
import FTS5Store
import Foundation
import GeneratorKit
import ProvenanceFlowIndexGeneratorCore

// MARK: - ResolvedEdgeError

/// Why a run refused to write.
public enum ResolvedEdgeError: Error, CustomStringConvertible {
    /// The scan produced no cross-volume edges at all.
    case noEdges(documentEdges: Int, volumes: Int)
    /// The run was asked to read page rows from an index that is not there.
    case noIndex(URL)

    public var description: String {
        switch self {
        case .noEdges(let documentEdges, let volumes):
            return """
                Refusing to write an empty resolved-edge index: \(documentEdges) document edges \
                across \(volumes) volumes yielded no cross-volume citation. The corpus is known to \
                carry roughly 8,600 of them, so this is a broken harvest — an empty artifact would \
                disable inbound-citation completion while the build exits 0.
                """
        case .noIndex(let url):
            return "INDEX_DB names \(url.path), which is not a file"
        }
    }
}

// MARK: - ResolvedEdgeIndexRunner

/// Builds `resolved-edge-index.json` (#262): every cross-volume citation of a document in the
/// shippable corpus, grouped by the document cited — and, since A18b, `cited-page-map.json` from
/// the same run.
///
/// A citation is a reference to a document, to a note in one (`RefDestination.citedDocument`), or
/// (A18b) to a printed page of another volume that rule C resolves, from a row the app's index
/// holds: a document, or the text a section prints at its own level.
/// - **From a document, by id**: the validator's `RefHarvester` with `CrossRefGrammar` and #764's
///   `DocumentIdInventory`, so an edge here is an edge in the cross-reference report and in the
///   provenance flow matrix, and the funnel's document counts are that matrix's.
/// - **From a section, by id** (#1693): the rows the kit's own parser gives a section — a
///   division's own text (#1536), a container's (#1510), a prose section such as an introduction
///   or an errata list — which is how the index decides them, so a section cites here under the id
///   the app's local table stores it under, and `CrossReferenceStore.completingInboundEdges` merges
///   the two as one citer. A reference in a section holds no document, so `RefHarvester` never
///   gives it one and the two passes cannot count a reference twice.
/// - **By page** (A18b, plan of record decision 80): every row the kit's parser emits, documents'
///   and sections' alike, is walked as the index walks it (`references(in:)`), and a reference to a
///   page of another volume is classified by its printed form (`PageReferenceForm`) and given what
///   its note names (`PageCitationHint`), as `IndexingPipeline.collectDocumentRefs` does. The run
///   then builds a full index of the same volumes through the kit's own pipeline, reads each cited
///   page's documents and facts from it through the reader's own store (`PageRangeStore`), writes
///   them as the map, and resolves each reference through
///   `PageSpanResolver.citedDocument(inVolume:page:form:citing:map:)` over that map — the one
///   function the device's store pass calls — so the pair here is the row the device stores. A page
///   reference is in no document-to-document count, so it is not counted twice.
///
/// Entirely offline and deterministic: a filename-sorted scan, sorted vocabularies, rows sorted by
/// key, and `sortedKeys` on the encoder. The index it builds is deterministic in what the map
/// reads: a volume's `page_ranges` rows are written in one pass in source order, and the facts are
/// each document's own.
///
/// Version history:
///   1.0 — Session 2026-08-09: #262
///   1.1 — #1693: a reference to a note is a citation of its document under the grammar's
///          `.footnote` case, and a section's row cites (`sectionReferences(in:)`), counted in the
///          funnel's three section fields; `build` is `async`, for the kit's parser
///   1.2 — A18b: a reference to a page of another volume cites under rule C; the run builds a full
///          index of the volumes (`buildIndex(of:in:)`), writes `cited-page-map.json` from it
///          (`pageMap(for:in:generated:)`) and resolves the references over the map
///          (`citedPages(in:)`); `build(files:generated:index:)` returns both files, and
///          `parsedRows(in:)` (was `sectionReferences(in:)`) keeps every row with each reference's
///          form and hint
public enum ResolvedEdgeIndexRunner {

    /// Where the run reads page rows and facts from.
    public enum IndexSource: Sendable {
        /// Build a full index of the run's volumes in this folder, through the kit's own pipeline;
        /// the folder is created, and left for the caller to remove.
        case build(in: URL)
        /// Read an index already built at the current index version — a development convenience
        /// (`INDEX_DB`); the shipped files come from a run that built its own.
        case existing(URL)
    }

    /// Runs the generator from the environment.
    public static func run() async throws {
        let environment = ProcessInfo.processInfo.environment
        let volumesDirectory = URL(fileURLWithPath:
            environment["VOLUMES_DIR"] ?? "/Users/jbotts/Development/frus/volumes")
        let manifest = URL(fileURLWithPath:
            environment["MANIFEST"] ?? "FRUSExplorer/Resources/manifest.json")
        let output = URL(fileURLWithPath:
            environment["OUTPUT"] ?? "FRUSExplorer/Resources/resolved-edge-index.json")
        let pageMapOutput = URL(fileURLWithPath:
            environment["PAGE_MAP_OUTPUT"] ?? "FRUSExplorer/Resources/cited-page-map.json")
        let generated = environment["GENERATED_DATE"] ?? Self.today()

        // The manifest defines the shippable set, the same filter every sibling generator uses —
        // an edge into a volume the app cannot show is not a citation the reader can follow.
        let shippable = try Self.shippableVolumeIds(manifest: manifest)
        let files = try VolumeCorpusEnumerator.volumeFiles(in: volumesDirectory)
            .filter { shippable.contains(VolumeCorpusEnumerator.volumeId(for: $0)) }
        print("[ResolvedEdgeIndex] scanning \(files.count) volumes…")

        // The full index the page map is read from: one the run builds (in INDEX_DIR, kept, or a
        // temporary folder, removed), or one given by INDEX_DB.
        let source: IndexSource
        var temporary: URL?
        if let existing = environment["INDEX_DB"] {
            source = .existing(URL(fileURLWithPath: existing))
        } else if let kept = environment["INDEX_DIR"] {
            source = .build(in: URL(fileURLWithPath: kept))
        } else {
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("resolved-edge-index-\(UUID().uuidString)", isDirectory: true)
            temporary = folder
            source = .build(in: folder)
        }
        defer { if let temporary { try? FileManager.default.removeItem(at: temporary) } }

        let built = try await build(files: files, generated: generated, index: source)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(built.edges).write(to: output)
        try encoder.encode(built.pages).write(to: pageMapOutput)
        let size = (try? Data(contentsOf: output).count) ?? 0
        let mapSize = (try? Data(contentsOf: pageMapOutput).count) ?? 0
        let coverage = built.edges.coverage
        print("""
            [ResolvedEdgeIndex] \(coverage.storedEdges) cross-volume edges into \
            \(coverage.targetCount) documents, cited from \
            \(coverage.citingVolumeCount) volumes.
            [ResolvedEdgeIndex] \(coverage.documentEdges) document edges scanned; \
            \(coverage.sameVolumeEdges) same-volume edges excluded (the local table already \
            holds them).
            [ResolvedEdgeIndex] \(coverage.referencesInSections) references in sections' own \
            rows; \(coverage.sectionEdges) of them cite a document, \
            \(coverage.sameVolumeSectionEdges) in their own volume.
            [ResolvedEdgeIndex] \(coverage.crossVolumePageReferences) references to a page of \
            another volume; \(coverage.pageEdges) of them cite the document on the page under rule C.
            [ResolvedEdgeIndex] wrote \(size / 1024) KB to \(output.path)
            [ResolvedEdgeIndex] page map: \(built.pages.pageCount) pages in \
            \(built.pages.volumes.count) volumes, naming \(built.pages.documents.reduce(0) { $0 + $1.count }) \
            documents; wrote \(mapSize / 1024) KB to \(pageMapOutput.path)
            """)
    }

    /// The pure build, so tests can drive it over a fixture corpus: the edge index and the page
    /// map, from one scan and one full index of `files`.
    public static func build(files: [URL], generated: String,
                             index: IndexSource) async throws -> (edges: ResolvedEdgeIndex, pages: CitedPageMap) {
        // Pass 1: every volume's real document ids. The narrower inventory, not the validator's
        // anchor inventory — 49,799 index-entry anchors resolve as documents under the grammar
        // and would mint phantom citations (#764's finding, and it applies identically here).
        var documentIds: [String: Set<String>] = [:]
        var volumeOrder: [String] = []
        for file in files {
            let volumeId = VolumeCorpusEnumerator.volumeId(for: file)
            documentIds[volumeId] = DocumentIdInventory.documentIds(in: try Data(contentsOf: file))
            volumeOrder.append(volumeId)
        }

        // Pass 2: harvest, resolve, and keep only what crosses a volume boundary.
        struct Endpoint: Hashable { let volume: String; let document: String }
        var sourcesByTarget: [Endpoint: Set<Endpoint>] = [:]
        var footnoteSourcesByTarget: [Endpoint: Set<Endpoint>] = [:]
        var referencesScanned = 0
        var referencesInsideDocuments = 0
        var documentEdges = 0
        var sameVolumeEdges = 0
        var citingVolumes = Set<String>()

        /// Where `rawTarget`, written in `sourceVolume`, cites a document of a shippable volume, or
        /// `nil`: the target must be a real document div, not merely what the grammar reads as one.
        func citedEndpoint(_ rawTarget: String, in sourceVolume: String) -> Endpoint? {
            guard let (volumeOverride, targetDocument) =
                    CrossRefGrammar.resolveDestination(rawTarget, volumeId: sourceVolume).citedDocument
            else { return nil }
            let targetVolume = volumeOverride ?? sourceVolume
            guard documentIds[targetVolume]?.contains(targetDocument) == true else { return nil }
            return Endpoint(volume: targetVolume, document: targetDocument)
        }

        /// Keeps one citation from `source`, which a reader counting "documents that cite this"
        /// counts once however often it cites (a Set).
        func keep(_ source: Endpoint, cites target: Endpoint, fromNote isInsideNote: Bool) {
            sourcesByTarget[target, default: []].insert(source)
            if isInsideNote { footnoteSourcesByTarget[target, default: []].insert(source) }
            citingVolumes.insert(source.volume)
        }

        for file in files {
            let data = try Data(contentsOf: file)
            let sourceVolume = VolumeCorpusEnumerator.volumeId(for: file)
            let refs = RefHarvester.harvest(from: data)
            referencesScanned += refs.count
            for ref in refs {
                guard let sourceDocument = ref.enclosingDocument else { continue }
                referencesInsideDocuments += 1
                guard let target = citedEndpoint(ref.rawTarget, in: sourceVolume) else { continue }
                documentEdges += 1
                guard target.volume != sourceVolume else {
                    sameVolumeEdges += 1
                    continue
                }
                keep(Endpoint(volume: sourceVolume, document: sourceDocument), cites: target,
                     fromNote: ref.isInsideNote)
            }
        }

        // Pass 3 (#1693): the rows the index holds for sections. A row the parser gives a document
        // div was harvested above; every other row is a section's.
        var referencesInSections = 0
        var sectionEdges = 0
        var sameVolumeSectionEdges = 0
        let parsedRows = try await parsedRows(in: files)
        for file in files {
            let sourceVolume = VolumeCorpusEnumerator.volumeId(for: file)
            let documentsHere = documentIds[sourceVolume] ?? []
            for row in parsedRows[sourceVolume] ?? []
            where !row.rowId.isEmpty && !documentsHere.contains(row.rowId) {
                referencesInSections += row.references.count
                for reference in row.references {
                    guard let target = citedEndpoint(reference.target, in: sourceVolume)
                    else { continue }
                    sectionEdges += 1
                    guard target.volume != sourceVolume else {
                        sameVolumeSectionEdges += 1
                        continue
                    }
                    keep(Endpoint(volume: sourceVolume, document: row.rowId), cites: target,
                         fromNote: reference.isInsideNote)
                }
            }
        }

        // Pass 4 (A18b): a page of another volume. The map first, read from a full index of these
        // volumes; then each reference resolved over it, through the device's own function.
        let pageReferences = crossVolumePageReferences(in: parsedRows, files: files)
        let map = try await pageMap(for: pageReferences, in: index, files: files, generated: generated)
        var pageEdges = 0
        for file in files {
            let sourceVolume = VolumeCorpusEnumerator.volumeId(for: file)
            for row in parsedRows[sourceVolume] ?? [] where !row.rowId.isEmpty {
                for reference in row.references {
                    guard let page = reference.page, let form = reference.pageForm else { continue }
                    guard let cited = PageSpanResolver.citedDocument(
                        inVolume: page.volumeId, page: page.page, form: form,
                        citing: reference.citing, map: map) else { continue }
                    pageEdges += 1
                    keep(Endpoint(volume: sourceVolume, document: row.rowId),
                         cites: Endpoint(volume: page.volumeId, document: cited),
                         fromNote: reference.isInsideNote)
                }
            }
        }

        guard !sourcesByTarget.isEmpty else {
            throw ResolvedEdgeError.noEdges(documentEdges: documentEdges, volumes: files.count)
        }

        // Only volumes and documents that actually appear at an endpoint are interned, so the
        // vocabulary is the artifact's own and not a copy of the manifest.
        var used: [String: Set<String>] = [:]
        for (target, sources) in sourcesByTarget {
            used[target.volume, default: []].insert(target.document)
            for source in sources { used[source.volume, default: []].insert(source.document) }
        }
        let volumes = used.keys.sorted()
        let volumeIndex = Dictionary(uniqueKeysWithValues: volumes.enumerated().map { ($1, $0) })
        let documents = volumes.map { (used[$0] ?? []).sorted() }
        let documentIndex: [[String: Int]] = documents.map { row in
            Dictionary(uniqueKeysWithValues: row.enumerated().map { ($1, $0) })
        }

        func pair(_ endpoint: Endpoint) -> (Int, Int)? {
            guard let volume = volumeIndex[endpoint.volume],
                  let document = documentIndex[volume][endpoint.document] else { return nil }
            return (volume, document)
        }

        let targets = sourcesByTarget
            .compactMap { target, sources -> ResolvedEdgeIndex.TargetEdges? in
                guard let (volume, document) = pair(target) else { return nil }
                let footnotes = footnoteSourcesByTarget[target] ?? []
                let ordered = sources.compactMap(pair).sorted { $0 < $1 }
                return ResolvedEdgeIndex.TargetEdges(
                    volume: volume, document: document,
                    sources: ordered.flatMap { [$0.0, $0.1] },
                    footnoteSources: footnotes.count)
            }
            .sorted { a, b in
                if a.volume != b.volume { return a.volume < b.volume }
                return a.document < b.document
            }

        let edges = ResolvedEdgeIndex(
            schemaVersion: 1, generated: generated, volumes: volumes, documents: documents,
            targets: targets,
            coverage: ResolvedEdgeIndex.Coverage(
                volumesScanned: files.count, referencesScanned: referencesScanned,
                referencesInsideDocuments: referencesInsideDocuments,
                documentEdges: documentEdges, sameVolumeEdges: sameVolumeEdges,
                referencesInSections: referencesInSections, sectionEdges: sectionEdges,
                sameVolumeSectionEdges: sameVolumeSectionEdges,
                crossVolumePageReferences: pageReferences.count, pageEdges: pageEdges,
                targetCount: targets.count, citingVolumeCount: citingVolumes.count))
        return (edges, map)
    }

    // MARK: - The rows the index holds (#1693, A18b)

    /// One row the kit's parser emits for a volume, with the `<ref>`s it holds.
    struct ParsedRowReferences: Sendable {
        /// The row's id: a document div's `xml:id`, or the section's.
        let rowId: String
        /// The row's references, in document order.
        let references: [ParsedReference]
    }

    /// One `<ref>` in a parsed row.
    struct ParsedReference: Sendable, Equatable {
        /// The verbatim `target`.
        let target: String
        /// Whether a `<note>` holds it, as `HarvestedRef.isInsideNote` says of a document's.
        let isInsideNote: Bool
        /// For a reference to a page of ANOTHER volume: the page, as written.
        let page: (volumeId: String, page: Int)?
        /// For a reference to a page of another volume: its printed form, classified from its
        /// siblings as the index classifies it (`PageReferenceForm.form(ofPageReferenceAt:in:)`).
        let pageForm: PageReferenceForm?
        /// For a reference to a page inside a note: what the note names, as the index builds it.
        let citing: PageCitationHint?

        static func == (lhs: ParsedReference, rhs: ParsedReference) -> Bool {
            lhs.target == rhs.target && lhs.isInsideNote == rhs.isInsideNote
                && lhs.page?.volumeId == rhs.page?.volumeId && lhs.page?.page == rhs.page?.page
                && lhs.pageForm == rhs.pageForm && lhs.citing == rhs.citing
        }
    }

    /// Every row the kit's parser emits for each volume, by volume id, with its references.
    ///
    /// The parse is `FRUSDocumentParser.parse(volumeURL:)`, the whole-volume parse whose rows the
    /// app's index stores, so a section here is a section there: since index version 68 a
    /// division that holds documents and prints text of its own is a row of that text alone, a
    /// container of sections with text of its own is a row of it (#1510), and a prose section is a
    /// row whole. Six volumes are parsed at a time; the result is keyed, not ordered, so it does
    /// not depend on which finishes first.
    static func parsedRows(in files: [URL]) async throws -> [String: [ParsedRowReferences]] {
        let concurrency = 6
        return try await withThrowingTaskGroup(
            of: (String, [ParsedRowReferences]).self
        ) { group in
            var result: [String: [ParsedRowReferences]] = [:]
            var pending = files.makeIterator()
            func addNext() -> Bool {
                guard let file = pending.next() else { return false }
                group.addTask {
                    let volumeId = VolumeCorpusEnumerator.volumeId(for: file)
                    let rows = try await FRUSDocumentParser().parse(volumeURL: file)
                    return (volumeId, rows.map { row in
                        ParsedRowReferences(rowId: row.documentId,
                                            references: references(in: row.nodes, volumeId: volumeId))
                    })
                }
                return true
            }
            for _ in 0..<concurrency where !addNext() { break }
            while let (volumeId, rows) = try await group.next() {
                result[volumeId] = rows
                _ = addNext()
            }
            return result
        }
    }

    /// The `<ref>`s in `nodes`, in document order, walked as the index's walk
    /// (`IndexingPipeline.collectDocumentRefs`) walks them: a `<ref>` inside another one included,
    /// and a `.footnote` node a `<note>`, whose children are what a page reference's hint is built
    /// from. An empty or external target is kept here and cites nothing later, as the index stores
    /// no row for it. A reference to a page of another volume — not `volumeId`'s own, by its prefix
    /// or bare — carries its form and its hint, as the index's row does (A18b).
    static func references(in nodes: [FRUSASTNode], volumeId: String,
                           noteChildren: [FRUSASTNode]? = nil) -> [ParsedReference] {
        var found: [ParsedReference] = []
        for (index, node) in nodes.enumerated() {
            switch node {
            case .crossReference(let target, let targetVolumeId, let children):
                var page: (volumeId: String, page: Int)?
                var form: PageReferenceForm?
                var citing: PageCitationHint?
                if case .page(let pageVolumeId, let number) =
                    FRUSURLScheme.resolveCrossRefTarget(target, volumeId: targetVolumeId) {
                    if let noteChildren { citing = PageCitationHint(noteChildren: noteChildren) }
                    if let pageVolumeId, pageVolumeId != volumeId {
                        page = (pageVolumeId, number)
                        form = PageReferenceForm.form(ofPageReferenceAt: index, in: nodes)
                    }
                }
                found.append(ParsedReference(target: target, isInsideNote: noteChildren != nil,
                                             page: page, pageForm: form, citing: citing))
                found.append(contentsOf: references(in: children, volumeId: volumeId,
                                                    noteChildren: noteChildren))
            case .footnote(_, _, _, let children):
                found.append(contentsOf: references(in: children, volumeId: volumeId,
                                                    noteChildren: children))
            case .editorialNote(let children):
                // An editorial note's own text is in no footnote: no hint, as the index gives
                // none (`collectDocumentRefs` passes `citingNote: nil` there).
                found.append(contentsOf: references(in: children, volumeId: volumeId,
                                                    noteChildren: nil))
            default:
                found.append(contentsOf: references(in: node.children, volumeId: volumeId,
                                                    noteChildren: noteChildren))
            }
        }
        return found
    }

    // MARK: - The page map (A18b)

    /// One reference to a page of another volume, as the map and the pairs read it.
    struct PageReference: Sendable {
        /// The volume the page is in.
        let volumeId: String
        /// The page.
        let page: Int
        /// The printed form.
        let form: PageReferenceForm
    }

    /// Every reference to a page of another volume in the parsed rows, in `files`' order.
    static func crossVolumePageReferences(in rows: [String: [ParsedRowReferences]],
                                          files: [URL]) -> [PageReference] {
        var found: [PageReference] = []
        for file in files {
            for row in rows[VolumeCorpusEnumerator.volumeId(for: file)] ?? [] where !row.rowId.isEmpty {
                for reference in row.references {
                    guard let page = reference.page, let form = reference.pageForm else { continue }
                    found.append(PageReference(volumeId: page.volumeId, page: page.page, form: form))
                }
            }
        }
        return found
    }

    /// The map for `references`: an entry for every page a single-page reference cites and for
    /// both ends of every range whose two end pages name the same one document, read from the
    /// index `source` gives — one the run builds of `files` through the kit's own pipeline, or one
    /// already built — through the reader's own store, `PageRangeStore`, with the facts of the
    /// documents on a page that names several.
    ///
    /// A page cited only with "ff." or as an end of a range across documents gets no entry, so the
    /// device leaves such a reference on the volume however it reads the map; a page that names
    /// nothing gets none either.
    static func pageMap(for references: [PageReference], in source: IndexSource, files: [URL],
                        generated: String) async throws -> CitedPageMap {
        let database: URL
        switch source {
        case .build(let folder):
            database = try await buildIndex(of: files, in: folder)
        case .existing(let url):
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw ResolvedEdgeError.noIndex(url)
            }
            database = url
        }
        let store = try PageRangeStore(databaseURL: database)

        // The pages to look up, by volume: single pages, and both ends of every range.
        var singles: [String: Set<Int>] = [:]
        var ranges: [String: Set<[Int]>] = [:]
        for reference in references {
            switch reference.form {
            case .single:
                singles[reference.volumeId, default: []].insert(reference.page)
            case .rangeStart(let end):
                ranges[reference.volumeId, default: []].insert([reference.page, end])
            case .rangeEnd(let start):
                ranges[reference.volumeId, default: []].insert([start, reference.page])
            case .andFollowing:
                continue
            }
        }

        var volumes: [String] = []
        var documents: [[String]] = []
        var pages: [[[Int]]] = []
        var facts: [[CitedPageMap.Fact]] = []
        for volumeId in Set(singles.keys).union(ranges.keys).sorted() {
            var wanted = singles[volumeId] ?? []
            for range in ranges[volumeId] ?? [] { wanted.formUnion(range) }
            var entries: [Int: PageSpanResolver.PageClaimants] = [:]
            for page in wanted.sorted() {
                if let claimants = try await store.documents(forPage: page, inVolume: volumeId) {
                    entries[page] = claimants
                }
            }
            // A range's ends are kept only when they name the same one document (rule C); a
            // single page is kept whenever it names anything.
            var kept = (singles[volumeId] ?? []).filter { entries[$0] != nil }
            for range in ranges[volumeId] ?? [] {
                guard let a = entries[range[0]], let b = entries[range[1]],
                      a.documents.count == 1, b.documents.count == 1,
                      a.documents[0].documentId == b.documents[0].documentId else { continue }
                kept.formUnion(range)
            }
            guard !kept.isEmpty else { continue }

            let ids = Set(kept.flatMap { entries[$0]?.documents.map(\.documentId) ?? [] }).sorted()
            let index = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
            var rows: [[Int]] = []
            var withFacts = Set<String>()
            for page in kept.sorted() {
                guard let claimants = entries[page] else { continue }
                rows.append([page, CitedPageMap.claimCode(claimants.claim)]
                            + claimants.documents.compactMap { index[$0.documentId] })
                if claimants.isAmbiguous {
                    for document in claimants.documents { withFacts.insert(document.documentId) }
                }
            }
            var volumeFacts: [CitedPageMap.Fact] = []
            if !withFacts.isEmpty {
                let read = await store.citedDocumentFacts(inVolume: volumeId)
                for id in withFacts.sorted() {
                    guard let fact = read[id], let position = index[id],
                          fact.printedNumber != nil || fact.day != nil else { continue }
                    let day = fact.day.map { String(format: "%04d-%02d-%02d", $0.year ?? 0, $0.month, $0.day) } ?? ""
                    volumeFacts.append(CitedPageMap.Fact(document: position,
                                                         printedNumber: fact.printedNumber ?? "",
                                                         day: day))
                }
                volumeFacts.sort { $0.document < $1.document }
            }
            volumes.append(volumeId)
            documents.append(ids)
            pages.append(rows)
            facts.append(volumeFacts)
        }
        return try CitedPageMap(schemaVersion: 1, generated: generated,
                                indexVersion: IndexingPipeline.currentDateIndexVersion,
                                volumes: volumes, documents: documents, pages: pages, facts: facts)
    }

    /// Builds a full index of `files` in `folder` through the kit's own pipeline — the parse the
    /// app's index stores, at the current index version — and returns the database. The files
    /// are cloned into `folder/volumes`, since the pipeline indexes a folder; with no bundled
    /// resources, since none reaches a page row or a document's number and day.
    static func buildIndex(of files: [URL], in folder: URL) async throws -> URL {
        let volumes = folder.appendingPathComponent("volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        for file in files {
            let copy = volumes.appendingPathComponent(file.lastPathComponent)
            if FileManager.default.fileExists(atPath: copy.path) {
                try FileManager.default.removeItem(at: copy)
            }
            try FileManager.default.copyItem(at: file, to: copy)
        }
        let database = folder.appendingPathComponent("frus.db")
        let store = try FTS5Store(databaseURL: database)
        let pipeline = try IndexingPipeline(
            fts5Store: store, databaseURL: database, volumesDirectory: volumes,
            resources: .none, concurrencyLimit: 6, defaults: InMemoryIndexingStampStore())
        print("[ResolvedEdgeIndex] indexing \(files.count) volumes at version \(IndexingPipeline.currentDateIndexVersion) in \(folder.path)…")
        let started = Date()
        try await pipeline.indexAllVolumes()
        print("[ResolvedEdgeIndex] indexed in \(Int(Date().timeIntervalSince(started))) s")
        return database
    }

    /// The manifest's shippable volume-id set — the same filter every sibling generator applies.
    ///
    /// Decoded through a minimal shape rather than the app's `VolumeManifestEntry`: this target
    /// needs one field, and depending on the app's model to read it would couple the generator to
    /// every future change in the manifest's other columns.
    static func shippableVolumeIds(manifest: URL) throws -> Set<String> {
        struct Entry: Decodable { let volumeId: String }
        let entries = try JSONDecoder().decode([Entry].self, from: try Data(contentsOf: manifest))
        return Set(entries.map(\.volumeId))
    }

    private static func today() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }
}
