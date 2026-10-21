// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CitedPageMap

/// The bundled `cited-page-map.json` (A18b, index version 71, plan of record decision 80): for
/// every printed page of another volume that the corpus cites, the documents on that page, as the
/// kit's own resolver reads them from a full index of the catalogue volumes. With it a device
/// resolves a reference to a page of a volume it does not hold, and every device resolves it to the
/// same document.
///
/// ## What it holds
/// An entry for every page a single-page reference cites, and for both end pages of every range
/// whose two end pages name the same one document — the pages rule C resolves
/// (``PageSpanResolver/citedDocument(inVolume:page:form:citing:map:)``). An entry is what
/// ``PageSpanResolver/documents(onPage:in:)`` answered over the target volume's `page_ranges` rows:
/// the claim, and the document ids in source order. For the documents on a page that names
/// several, and for every document on a page of a volume that numbers its pages per document, it
/// carries the facts the tie-break reads (``CitedDocumentFacts``): the printed number and the day.
///
/// A page that names nothing — front matter, apparatus between documents — has no entry. A page
/// cited only with "ff." or as an end of a range across documents has none either, unless another
/// reference cites it on its own; a device resolves neither form in any case.
///
/// ## Why a device resolves from the map alone
/// Volumes download from the corpus head, unpinned, so a device's copy of a target volume can be
/// newer or older than the build's. The map is regenerated with each build's corpus and the
/// indexer reads only it (plan of record §0, A18b), so every device indexes the same files to the
/// same rows, and the census that compares a device's re-index with a fresh index holds row for
/// row. A volume re-published after a build can disagree with the map until the next build: 2 of
/// 553 changed their page layout in the 18 days to corpus `6170e4b32`.
///
/// ## Encoding
/// Like `resolved-edge-index.json`'s: `volumes` sorted; `documents` a per-volume vocabulary of the
/// ids on its cited pages, sorted; `pages` one row per volume of `[page, claim, index…]`, ascending
/// by page, the claim ``claimCode(_:)``'s and each index into the volume's vocabulary; `facts` one
/// row per volume of `[index, printedNumber, day]`, `""` for a fact the document lacks, the day as
/// `yyyy-MM-dd` and only for a document dated to the day. Written by `ResolvedEdgeIndexGenerator`,
/// which writes the two files from one run.
///
/// Version history:
///   1.0 — A18b (index version 71, plan of record decision 80): initial implementation
public struct CitedPageMap: Codable, Sendable, Equatable {

    // MARK: Entry

    /// What one cited page names.
    public struct Entry: Sendable, Equatable {
        /// How the documents stand on the page (``PageSpanResolver/Claim``).
        public let claim: PageSpanResolver.Claim
        /// The documents on the page, in source order. Never empty.
        public let documentIds: [String]

        /// An entry as given.
        public init(claim: PageSpanResolver.Claim, documentIds: [String]) {
            self.claim = claim
            self.documentIds = documentIds
        }
    }

    // MARK: Fact

    /// One document's facts as the file carries them: `[index, printedNumber, day]`.
    public struct Fact: Codable, Sendable, Equatable {
        /// The document's index into its volume's ``CitedPageMap/documents`` row.
        public let document: Int
        /// The printed number (`document_cache.document_number`), or `""`.
        public let printedNumber: String
        /// The day the document is dated, `yyyy-MM-dd`, or `""` when its date is not to the day.
        public let day: String

        /// A fact as given.
        public init(document: Int, printedNumber: String, day: String) {
            self.document = document
            self.printedNumber = printedNumber
            self.day = day
        }

        public init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            document = try c.decode(Int.self)
            printedNumber = try c.decode(String.self)
            day = try c.decode(String.self)
        }

        public func encode(to encoder: any Encoder) throws {
            var c = encoder.unkeyedContainer()
            try c.encode(document)
            try c.encode(printedNumber)
            try c.encode(day)
        }

        /// The facts the tie-break compares (``CitedDocumentFacts``).
        public var citedDocumentFacts: CitedDocumentFacts {
            CitedDocumentFacts(printedNumber: printedNumber.isEmpty ? nil : printedNumber,
                               dateISO: day.isEmpty ? nil : day,
                               precision: day.isEmpty ? nil : "day")
        }
    }

    /// Artifact schema version.
    public let schemaVersion: Int
    /// The generator run's date stamp (`yyyy-MM-dd`).
    public let generated: String
    /// The index version whose parse the page rows were read from (`IndexingPipeline.currentDateIndexVersion`
    /// at generation).
    public let indexVersion: Int
    /// The volumes with a cited page, sorted.
    public let volumes: [String]
    /// The ids on each volume's cited pages, parallel to ``volumes``, each sorted.
    public let documents: [[String]]
    /// Each volume's cited pages, parallel to ``volumes``: `[page, claim, index…]`, ascending by page.
    public let pages: [[[Int]]]
    /// Each volume's facts, parallel to ``volumes``, for the documents on its pages that name several.
    public let facts: [[Fact]]

    /// `volume → page → entry`, built once on decode.
    private let entriesByVolume: [String: [Int: Entry]]
    /// `volume → document id → facts`, built once on decode.
    private let factsByVolume: [String: [String: CitedDocumentFacts]]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, generated, indexVersion, volumes, documents, pages, facts
    }

    /// A map as given. Throws ``CitedPageMapError`` when a row names an index outside its volume's
    /// vocabulary or a claim code the map does not define, since a short read would name another
    /// document and invent a citation.
    public init(schemaVersion: Int, generated: String, indexVersion: Int, volumes: [String],
                documents: [[String]], pages: [[[Int]]], facts: [[Fact]]) throws {
        self.schemaVersion = schemaVersion
        self.generated = generated
        self.indexVersion = indexVersion
        self.volumes = volumes
        self.documents = documents
        self.pages = pages
        self.facts = facts
        (entriesByVolume, factsByVolume) = try Self.lookups(volumes: volumes, documents: documents,
                                                            pages: pages, facts: facts)
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(schemaVersion: try c.decode(Int.self, forKey: .schemaVersion),
                      generated: try c.decode(String.self, forKey: .generated),
                      indexVersion: try c.decode(Int.self, forKey: .indexVersion),
                      volumes: try c.decode([String].self, forKey: .volumes),
                      documents: try c.decode([[String]].self, forKey: .documents),
                      pages: try c.decode([[[Int]]].self, forKey: .pages),
                      facts: try c.decode([[Fact]].self, forKey: .facts))
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(generated, forKey: .generated)
        try c.encode(indexVersion, forKey: .indexVersion)
        try c.encode(volumes, forKey: .volumes)
        try c.encode(documents, forKey: .documents)
        try c.encode(pages, forKey: .pages)
        try c.encode(facts, forKey: .facts)
    }

    // MARK: Lookups

    /// What `page` of `volumeId` names, or `nil` when the map has no entry for it: the page names
    /// nothing, no reference cites it in a form rule C resolves, or the volume is outside the
    /// catalogue the map was generated from.
    public func entry(volumeId: String, page: Int) -> Entry? {
        entriesByVolume[volumeId]?[page]
    }

    /// The facts of `documentIds` in `volumeId`, by id, for those the map carries facts for.
    public func facts(volumeId: String, documentIds: [String]) -> [String: CitedDocumentFacts] {
        guard let byId = factsByVolume[volumeId] else { return [:] }
        var result: [String: CitedDocumentFacts] = [:]
        for id in documentIds { if let fact = byId[id] { result[id] = fact } }
        return result
    }

    /// The cited pages of every volume, `(volumeId, page, entry)`, in file order.
    public var entries: [(volumeId: String, page: Int, entry: Entry)] {
        volumes.indices.flatMap { v -> [(volumeId: String, page: Int, entry: Entry)] in
            let byPage = entriesByVolume[volumes[v]] ?? [:]
            return byPage.keys.sorted().compactMap { page in
                byPage[page].map { (volumes[v], page, $0) }
            }
        }
    }

    /// Entries in the map.
    public var pageCount: Int { pages.reduce(0) { $0 + $1.count } }

    // MARK: Claim codes

    /// The claim a row stores: 0 begins, 1 printed, 2 numbered per document.
    public static func claimCode(_ claim: PageSpanResolver.Claim) -> Int {
        switch claim {
        case .begins: return 0
        case .printed: return 1
        case .numberedPerDocument: return 2
        }
    }

    /// The claim `code` stores, or `nil` for a code the map does not define.
    public static func claim(ofCode code: Int) -> PageSpanResolver.Claim? {
        switch code {
        case 0: return .begins
        case 1: return .printed
        case 2: return .numberedPerDocument
        default: return nil
        }
    }

    private static func lookups(volumes: [String], documents: [[String]], pages: [[[Int]]],
                                facts: [[Fact]]) throws
        -> ([String: [Int: Entry]], [String: [String: CitedDocumentFacts]]) {
        guard documents.count == volumes.count, pages.count == volumes.count,
              facts.count == volumes.count else {
            throw CitedPageMapError.raggedVolumes(volumes: volumes.count, documents: documents.count,
                                                  pages: pages.count, facts: facts.count)
        }
        var entries: [String: [Int: Entry]] = [:]
        var byId: [String: [String: CitedDocumentFacts]] = [:]
        for v in volumes.indices {
            let vocabulary = documents[v]
            var byPage: [Int: Entry] = [:]
            for row in pages[v] {
                guard row.count >= 3, let claim = claim(ofCode: row[1]) else {
                    throw CitedPageMapError.malformedPage(volumeId: volumes[v], row: row)
                }
                let ids = try row[2...].map { index -> String in
                    guard vocabulary.indices.contains(index) else {
                        throw CitedPageMapError.malformedPage(volumeId: volumes[v], row: row)
                    }
                    return vocabulary[index]
                }
                byPage[row[0]] = Entry(claim: claim, documentIds: ids)
            }
            entries[volumes[v]] = byPage
            var volumeFacts: [String: CitedDocumentFacts] = [:]
            for fact in facts[v] {
                guard vocabulary.indices.contains(fact.document) else {
                    throw CitedPageMapError.malformedFact(volumeId: volumes[v], document: fact.document)
                }
                volumeFacts[vocabulary[fact.document]] = fact.citedDocumentFacts
            }
            byId[volumes[v]] = volumeFacts
        }
        return (entries, byId)
    }
}

// MARK: - CitedPageMapError

/// Why a map refused to decode.
public enum CitedPageMapError: Error, Equatable, CustomStringConvertible {
    /// The four per-volume arrays are not the same length.
    case raggedVolumes(volumes: Int, documents: Int, pages: Int, facts: Int)
    /// A page row is too short, names a claim code the map does not define, or an index outside
    /// its volume's vocabulary.
    case malformedPage(volumeId: String, row: [Int])
    /// A fact names an index outside its volume's vocabulary.
    case malformedFact(volumeId: String, document: Int)

    public var description: String {
        switch self {
        case .raggedVolumes(let volumes, let documents, let pages, let facts):
            return "cited-page-map: \(volumes) volumes but \(documents) document rows, \(pages) page rows and \(facts) fact rows"
        case .malformedPage(let volumeId, let row):
            return "cited-page-map: \(volumeId) has a malformed page row \(row)"
        case .malformedFact(let volumeId, let document):
            return "cited-page-map: \(volumeId) has a fact for document index \(document), outside its vocabulary"
        }
    }
}
