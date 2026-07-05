// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - Test Helpers

/// Writes a minimal FRUS volume XML fixture (a single compilation div of documents).
private func writeAnalyticsVolume(
    to url: URL,
    volumeId: String,
    documents: [(id: String, xml: String)]
) throws {
    let docBlocks = documents.map { doc in
        "<div type=\"document\" xml:id=\"\(doc.id)\">\(doc.xml)</div>"
    }.joined(separator: "\n")

    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
      <teiHeader><fileDesc><titleStmt><title>\(volumeId)</title></titleStmt>
      <publicationStmt><date>2003</date></publicationStmt>
      <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
      <text><body>
        <div type="compilation" xml:id="comp1">
          \(docBlocks)
        </div>
      </body></text>
    </TEI>
    """
    try xml.data(using: .utf8)!.write(to: url)
}

/// Creates a temporary directory, calls `body`, and cleans up after.
private func withAnalyticsTempDir<T>(_ body: (URL) async throws -> T) async throws -> T {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FRUSAnalyticsTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    return try await body(dir)
}

/// Builds a pipeline + store pair backed by a temp database, with a `volumes/` dir.
private func makeAnalyticsPipeline(dir: URL) async throws -> (pipeline: IndexingPipeline, store: FTS5Store) {
    let dbURL = dir.appendingPathComponent("test.sqlite")
    let volDir = dir.appendingPathComponent("volumes")
    try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)

    let store = try FTS5Store(databaseURL: dbURL)
    let pipeline = try IndexingPipeline(
        fts5Store: store,
        databaseURL: dbURL,
        volumesDirectory: volDir,
        subjectTagStore: SubjectTagStore(entries: [], appearances: []),
        concurrencyLimit: 2
    )
    return (pipeline, store)
}

// MARK: - CorpusAnalyticsServiceTests

/// Verifies the By-Volume analytics axis (`termFrequencyByVolume`).
///
/// Version history:
///   1.0 — Session 163: initial implementation
@Suite("CorpusAnalyticsService — By Volume")
struct CorpusAnalyticsServiceTests {

    /// A term that appears in two of three indexed volumes must yield exactly those
    /// two `VolumeFrequency` rows (with correct per-volume counts), omit the volume
    /// with no match entirely, and be sorted ascending by volume ID.
    @Test("termFrequencyByVolume buckets matches per volume and omits non-matching volumes")
    func byVolumeBucketsAndOmits() async throws {
        try await withAnalyticsTempDir { dir in
            let (pipeline, store) = try await makeAnalyticsPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            // frus1969-76v01 mentions "treaty" in two documents.
            try writeAnalyticsVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [
                    ("d1", "<head>1. Memorandum</head><p>Negotiation of the treaty continued.</p>"),
                    ("d2", "<head>2. Memorandum</head><p>A second treaty draft circulated.</p>"),
                ]
            )
            // frus1969-76v02 (same subseries) does NOT mention the term.
            try writeAnalyticsVolume(
                to: volDir.appendingPathComponent("frus1969-76v02.xml"),
                volumeId: "frus1969-76v02",
                documents: [
                    ("d1", "<head>1. Memorandum</head><p>Economic policy discussion only.</p>"),
                ]
            )
            // frus1977-80v01 (different subseries) mentions the term once.
            try writeAnalyticsVolume(
                to: volDir.appendingPathComponent("frus1977-80v01.xml"),
                volumeId: "frus1977-80v01",
                documents: [
                    ("d1", "<head>1. Memorandum</head><p>The treaty was ratified.</p>"),
                ]
            )

            try await pipeline.indexVolume("frus1969-76v01")
            try await pipeline.indexVolume("frus1969-76v02")
            try await pipeline.indexVolume("frus1977-80v01")

            let service = CorpusAnalyticsService(fts5Store: store, pipeline: pipeline)
            let result = try await service.termFrequencyByVolume(term: "treaty")

            let counts = Dictionary(uniqueKeysWithValues: result.map { ($0.volumeId, $0.count) })
            #expect(counts["frus1969-76v01"] == 2, "v01 mentions the term in two documents")
            #expect(counts["frus1977-80v01"] == 1, "frus1977-80v01 mentions the term once")
            #expect(counts["frus1969-76v02"] == nil, "Volume with no match must be omitted")
            #expect(result.count == 2, "Only matching volumes appear")
            #expect(result.map(\.volumeId) == ["frus1969-76v01", "frus1977-80v01"],
                    "Results are sorted ascending by volume ID")
        }
    }

    /// An empty / whitespace-only term yields no rows (no searchable keywords).
    @Test("termFrequencyByVolume returns empty for a blank term")
    func byVolumeEmptyForBlankTerm() async throws {
        try await withAnalyticsTempDir { dir in
            let (pipeline, store) = try await makeAnalyticsPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            try writeAnalyticsVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [("d1", "<head>1. Memorandum</head><p>Some content here.</p>")]
            )
            try await pipeline.indexVolume("frus1969-76v01")

            let service = CorpusAnalyticsService(fts5Store: store, pipeline: pipeline)
            let result = try await service.termFrequencyByVolume(term: "   ")
            #expect(result.isEmpty, "A blank term has no searchable keywords")
        }
    }

    /// A `volumeIds` scope must restrict every axis to documents in those volumes
    /// (the Word Cloud → Analytics handoff), and scoped results must not collide in
    /// the cache with the corpus-wide results for the same term. Verifies both the
    /// filtering and that scoped/unscoped calls in either order each return the
    /// correct shape.
    @Test("volumeIds scope restricts counts and does not collide with the corpus-wide cache")
    func volumeScopeRestrictsAndIsolatesCache() async throws {
        try await withAnalyticsTempDir { dir in
            let (pipeline, store) = try await makeAnalyticsPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            // "treaty" appears in v01 (×2) and in frus1977-80v01 (×1).
            try writeAnalyticsVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [
                    ("d1", "<head>1. Memo</head><p>Negotiation of the treaty continued.</p>"),
                    ("d2", "<head>2. Memo</head><p>A second treaty draft circulated.</p>"),
                ]
            )
            try writeAnalyticsVolume(
                to: volDir.appendingPathComponent("frus1977-80v01.xml"),
                volumeId: "frus1977-80v01",
                documents: [
                    ("d1", "<head>1. Memo</head><p>The treaty was ratified.</p>"),
                ]
            )
            try await pipeline.indexVolume("frus1969-76v01")
            try await pipeline.indexVolume("frus1977-80v01")

            let service = CorpusAnalyticsService(fts5Store: store, pipeline: pipeline)
            let scope: Set<String> = ["frus1969-76v01"]

            // Corpus-wide first, then scoped — the scoped call must NOT be served the
            // cached corpus-wide result.
            let corpusWide = try await service.termFrequencyByVolume(term: "treaty")
            #expect(corpusWide.count == 2, "Corpus-wide query sees both volumes")

            let scoped = try await service.termFrequencyByVolume(term: "treaty", volumeIds: scope)
            #expect(scoped.map(\.volumeId) == ["frus1969-76v01"], "Scope restricts to the one volume")
            #expect(scoped.first?.count == 2, "Per-volume count is preserved under scope")

            // Corpus-wide again must still return both volumes (caches are independent).
            let corpusWideAgain = try await service.termFrequencyByVolume(term: "treaty")
            #expect(corpusWideAgain.count == 2, "Corpus-wide cache entry is unaffected by the scoped call")

            // The date axis honours the scope too: only v01's two documents count.
            let scopedYears = try await service.termFrequencyByYear(term: "treaty", volumeIds: scope)
            #expect(scopedYears.reduce(0) { $0 + $1.count } == 2,
                    "By-Year counts are restricted to the scoped volume's documents")
        }
    }

    /// A quoted phrase must match only adjacent occurrences (like Search), where an
    /// unquoted query is a loose AND of the words. Regression test for analytics
    /// previously stripping quotes and over-reporting phrase queries.
    @Test("quoted phrase matches adjacency only, unquoted is a loose AND")
    func quotedPhraseMatchesAdjacencyOnly() async throws {
        try await withAnalyticsTempDir { dir in
            let (pipeline, store) = try await makeAnalyticsPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            try writeAnalyticsVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [
                    // Adjacent phrase "second treaty".
                    ("d1", "<head>1. Memo</head><p>The second treaty was signed in March.</p>"),
                    // Both words present, but NOT adjacent / not in order.
                    ("d2", "<head>2. Memo</head><p>The treaty came second on the agenda.</p>"),
                ]
            )
            try await pipeline.indexVolume("frus1969-76v01")

            let service = CorpusAnalyticsService(fts5Store: store, pipeline: pipeline)

            let phrase = try await service.termFrequencyByVolume(term: "\"second treaty\"")
            let phraseCount = phrase.first { $0.volumeId == "frus1969-76v01" }?.count ?? 0
            #expect(phraseCount == 1, "Quoted phrase matches only the adjacent occurrence (d1)")

            let loose = try await service.termFrequencyByVolume(term: "second treaty")
            let looseCount = loose.first { $0.volumeId == "frus1969-76v01" }?.count ?? 0
            #expect(looseCount == 2, "Unquoted query is a loose AND, matching both documents")
        }
    }

    // MARK: - Corpus Document Totals (Prep-B / CA-4 denominator)

    /// `documentTotalsByYear` counts every indexed document per year (by its stored
    /// `date_iso`), independent of any search term — the normalization denominator.
    /// `documentTotalsByDecade` buckets those totals into ten-year windows.
    @Test("documentTotalsByYear/Decade count all indexed documents per period")
    func documentTotalsBucketByPeriod() async throws {
        try await withAnalyticsTempDir { dir in
            let (pipeline, store) = try await makeAnalyticsPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            // Two documents dated 1971, one dated 1975, one dated 1978 — regardless
            // of content, all four count toward the corpus totals.
            try writeAnalyticsVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [
                    ("d1", "<head>1. Memo</head><dateline><date when=\"1971-03-01\">March 1, 1971</date></dateline><p>Alpha.</p>"),
                    ("d2", "<head>2. Memo</head><dateline><date when=\"1971-06-01\">June 1, 1971</date></dateline><p>Beta.</p>"),
                    ("d3", "<head>3. Memo</head><dateline><date when=\"1975-01-01\">Jan 1, 1975</date></dateline><p>Gamma.</p>"),
                ]
            )
            try writeAnalyticsVolume(
                to: volDir.appendingPathComponent("frus1977-80v01.xml"),
                volumeId: "frus1977-80v01",
                documents: [
                    ("d1", "<head>1. Memo</head><dateline><date when=\"1978-02-01\">Feb 1, 1978</date></dateline><p>Delta.</p>"),
                ]
            )
            try await pipeline.indexVolume("frus1969-76v01")
            try await pipeline.indexVolume("frus1977-80v01")

            let service = CorpusAnalyticsService(fts5Store: store, pipeline: pipeline)

            let byYear = try await service.documentTotalsByYear()
            #expect(byYear[1971] == 2, "Two documents are dated 1971")
            #expect(byYear[1975] == 1, "One document is dated 1975")
            #expect(byYear[1978] == 1, "One document is dated 1978")
            #expect(byYear[1972] == nil, "A year with no documents is absent, not zero")

            let byDecade = try await service.documentTotalsByDecade()
            #expect(byDecade[1970] == 4, "All four documents fall in the 1970s bucket")
        }
    }

    /// A `volumeIds` scope restricts the totals denominator to documents in those
    /// volumes, so a scoped share divides by the within-scope document count.
    @Test("documentTotalsByYear/Decade honor the volume scope")
    func documentTotalsHonorScope() async throws {
        try await withAnalyticsTempDir { dir in
            let (pipeline, store) = try await makeAnalyticsPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            try writeAnalyticsVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [
                    ("d1", "<head>1. Memo</head><dateline><date when=\"1971-03-01\">March 1, 1971</date></dateline><p>Alpha.</p>"),
                    ("d2", "<head>2. Memo</head><dateline><date when=\"1971-06-01\">June 1, 1971</date></dateline><p>Beta.</p>"),
                ]
            )
            try writeAnalyticsVolume(
                to: volDir.appendingPathComponent("frus1977-80v01.xml"),
                volumeId: "frus1977-80v01",
                documents: [
                    ("d1", "<head>1. Memo</head><dateline><date when=\"1971-09-01\">Sept 1, 1971</date></dateline><p>Gamma.</p>"),
                ]
            )
            try await pipeline.indexVolume("frus1969-76v01")
            try await pipeline.indexVolume("frus1977-80v01")

            let service = CorpusAnalyticsService(fts5Store: store, pipeline: pipeline)

            // Corpus-wide: three documents in 1971.
            let corpusWide = try await service.documentTotalsByYear()
            #expect(corpusWide[1971] == 3, "Three documents are dated 1971 corpus-wide")

            // Scoped to v01: only its two 1971 documents count.
            let scoped = try await service.documentTotalsByYear(volumeIds: ["frus1969-76v01"])
            #expect(scoped[1971] == 2, "Scope restricts the denominator to v01's two documents")

            let scopedDecade = try await service.documentTotalsByDecade(volumeIds: ["frus1969-76v01"])
            #expect(scopedDecade[1970] == 2, "Scoped decade total matches the scoped year total")

            // An empty scope is treated as whole-corpus (unscoped).
            let emptyScope = try await service.documentTotalsByYear(volumeIds: [])
            #expect(emptyScope[1971] == 3, "An empty scope means the whole corpus")
        }
    }

    /// The `% of documents` normalization (CA-4) is `matches / total * 100` per period.
    /// This proves the arithmetic the By-Year chart plots: numerator from
    /// `termFrequencyByYear`, denominator from `documentTotalsByYear`, both scoped
    /// identically — plus the scoped-denominator and zero-total (absent period) guards.
    @Test("normalization share is matches/total per year, honoring scope and the zero guard")
    func normalizationShareMatchesMatchesOverTotal() async throws {
        try await withAnalyticsTempDir { dir in
            let (pipeline, store) = try await makeAnalyticsPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            // 1971: four documents total, two mention "treaty" → 50% share.
            //   v01 has 3 docs (2 treaty, 1 not); v02 has 1 doc (not treaty).
            try writeAnalyticsVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [
                    ("d1", "<head>1. Memo</head><dateline><date when=\"1971-03-01\">March 1, 1971</date></dateline><p>The treaty was signed.</p>"),
                    ("d2", "<head>2. Memo</head><dateline><date when=\"1971-06-01\">June 1, 1971</date></dateline><p>A second treaty draft.</p>"),
                    ("d3", "<head>3. Memo</head><dateline><date when=\"1971-09-01\">Sept 1, 1971</date></dateline><p>Economic policy only.</p>"),
                ]
            )
            try writeAnalyticsVolume(
                to: volDir.appendingPathComponent("frus1969-76v02.xml"),
                volumeId: "frus1969-76v02",
                documents: [
                    ("d1", "<head>1. Memo</head><dateline><date when=\"1971-12-01\">Dec 1, 1971</date></dateline><p>Trade talks resumed.</p>"),
                ]
            )
            try await pipeline.indexVolume("frus1969-76v01")
            try await pipeline.indexVolume("frus1969-76v02")

            let service = CorpusAnalyticsService(fts5Store: store, pipeline: pipeline)

            // Corpus-wide: 2 treaty matches / 4 documents in 1971 → 50%.
            let matches = try await service.termFrequencyByYear(term: "treaty")
            let totals = try await service.documentTotalsByYear()
            let match1971 = matches.first { $0.year == 1971 }?.count ?? 0
            let total1971 = totals[1971] ?? 0
            #expect(match1971 == 2 && total1971 == 4)
            #expect(Double(match1971) / Double(total1971) * 100.0 == 50.0,
                    "Corpus-wide 1971 share is 2/4 = 50%")

            // Scoped to v01: 2 matches / 3 documents → 66.6…%. Numerator and denominator
            // must both be scoped so the within-scope share is correct.
            let scope: Set<String> = ["frus1969-76v01"]
            let scopedMatches = try await service.termFrequencyByYear(term: "treaty", volumeIds: scope)
            let scopedTotals = try await service.documentTotalsByYear(volumeIds: scope)
            let sMatch = scopedMatches.first { $0.year == 1971 }?.count ?? 0
            let sTotal = scopedTotals[1971] ?? 0
            #expect(sMatch == 2 && sTotal == 3, "Scoped numerator and denominator both restrict to v01")

            // Zero guard: a year with no indexed documents has no total entry, so the
            // view's normalizedValue returns nil (period omitted) rather than dividing
            // by zero.
            #expect(totals[1850] == nil, "A period with no documents has no denominator entry")
        }
    }
}
