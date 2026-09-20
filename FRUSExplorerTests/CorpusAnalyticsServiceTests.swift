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

// The three fixture helpers below are `internal`, not `private`: `OccurrenceCountTests` builds the
// same real-index fixtures to assert the occurrence numerator against this file's document numerator,
// and the two must be measuring the same corpus for that comparison to mean anything.

// MARK: - Test Helpers

/// Writes a minimal FRUS volume XML fixture (a single compilation div of documents).
func writeAnalyticsVolume(
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
func withAnalyticsTempDir<T>(_ body: (URL) async throws -> T) async throws -> T {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("FRUSAnalyticsTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    return try await body(dir)
}

/// Builds a pipeline + store pair backed by a temp database, with a `volumes/` dir.
func makeAnalyticsPipeline(dir: URL) async throws -> (pipeline: IndexingPipeline, store: FTS5Store) {
    let dbURL = dir.appendingPathComponent("test.sqlite")
    let volDir = dir.appendingPathComponent("volumes")
    try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)

    let store = try FTS5Store(databaseURL: dbURL)
    let pipeline = try IndexingPipeline(
        fts5Store: store,
        databaseURL: dbURL,
        volumesDirectory: volDir,
        concurrencyLimit: 2
    )
    return (pipeline, store)
}

// MARK: - CorpusAnalyticsServiceTests

/// Verifies the By-Volume analytics axis (`termFrequencyByVolume`).
///
/// Version history:
///   1.0 — Session 163: initial implementation
///   1.1 — #1297 rounds 1–3: an `=` mark the parser ignores charts the stem, and the exact-word refusal is pinned
///         operand by operand — `(=containment OR alliance) containment` and `=containment OR containment alliance`
///         chart, `(=containment OR alliance) =containment`, `-(alliance -=containment)` and, under parser 6.5's D4,
///         `=containment OR =containment alliance` refuse
///   1.2 — #1297 round 4: a word is named once however its marks are spelled (parser 6.6 compares them as the filter
///         reads words), in the spelling of its first applied mark, and a word marked in every alternative in two
///         spellings refuses
@Suite("CorpusAnalyticsService — By Volume")
struct CorpusAnalyticsServiceTests {

    // MARK: - Subseries parity with the Corpus Browser (#208)

    @Test("subseries(fromVolumeId:) uses the leading-year algorithm — the structural cases the old trailing-strip failed")
    func subseriesLeadingYearStructuralCases() {
        func sub(_ id: String) -> String? { CorpusAnalyticsService.subseries(fromVolumeId: id) }
        // Pre-1918 annuals / part-only / appendix ids (old algorithm returned nil — no vNN marker).
        #expect(sub("frus1861") == "1861")
        #expect(sub("frus1863p2") == "1863")
        #expect(sub("frus1894app1") == "1894")
        // Conference / area / supplement tokens (old algorithm kept them in the bucket key).
        #expect(sub("frus1945Berlinv01") == "1945")
        #expect(sub("frus1943CairoTehran") == "1943")
        #expect(sub("frus1919Parisv13") == "1919")
        #expect(sub("frus1917Supp01v01") == "1917")
        // Year ranges, area-code, edition, Vietnam extras.
        #expect(sub("frus1969-76v01") == "1969-76")
        #expect(sub("frus1969-76ve01") == "1969-76")
        #expect(sub("frus1952-54Gv01") == "1952-54")
        #expect(sub("frus1951-54IranEd2") == "1951-54")
        #expect(sub("frus1993-2000v01") == "1993-2000")
        // Non-frus / malformed → nil.
        #expect(sub("notfrus1969") == nil)
        #expect(sub("frusABCD") == nil)
    }

    /// The only assertion that `CorpusAnalyticsService`'s subseries derivation agrees with the
    /// manifest for **every** volume — which is exactly what a new volume-id shape breaks, and a new
    /// volume is the event that just happened (`frus1981-88v16`, #1258).
    ///
    /// **It used to `return` on an empty manifest and pass having measured nothing.** The comment
    /// called that "empty during development"; the effect was that the one guard against a
    /// volume-id shape this derivation cannot parse was also the one that reported success when the
    /// corpus failed to load at all. `#require` is the repo's own pattern for this
    /// (`SemanticMapFrameSequenceTests`, `CaptureStateSeederTests`, `SharedManifestDecodeTests`),
    /// and the floor is well below 553 so it survives a corpus that shrinks without becoming
    /// vacuous again.
    @Test("subseries(fromVolumeId:) equals every bundled manifest entry's subseries (whole-corpus browser parity)")
    @MainActor
    func subseriesMatchesBundledManifest() throws {
        let entries = ManifestStore().bundledEntries
        try #require(entries.count > 500, "the bundled manifest must load — an empty one makes this vacuous")
        for entry in entries {
            #expect(CorpusAnalyticsService.subseries(fromVolumeId: entry.volumeId) == entry.subseries,
                    "\(entry.volumeId): analytics subseries must equal the manifest's '\(entry.subseries)'")
        }
    }

    @Test("distilledVolumeLabel stays unique and unmangled with the leading-year subseries (#208)")
    func distilledLabelUniqueForConferenceVolumes() {
        // Conference / supplement volumes stay distinct from a plain annual of the same year —
        // the descriptive topic prefix disambiguates even though the subseries is the leading year.
        let plain = ChronologyViewModel.distilledVolumeLabel(
            volumeId: "frus1945v01", subseries: "1945",
            title: "Foreign Relations of the United States, 1945, Volume I")
        let berlin = ChronologyViewModel.distilledVolumeLabel(
            volumeId: "frus1945Berlinv01", subseries: "1945",
            title: "Foreign Relations of the United States, The Conference of Berlin, 1945")
        #expect(plain != berlin)
        #expect(berlin.contains("Berlin"))
        let annual = ChronologyViewModel.distilledVolumeLabel(
            volumeId: "frus1917v01", subseries: "1917",
            title: "Papers Relating to the Foreign Relations of the United States, 1917")
        let supp = ChronologyViewModel.distilledVolumeLabel(
            volumeId: "frus1917Supp01v01", subseries: "1917",
            title: "Papers Relating to the Foreign Relations of the United States, 1917, Supplement 1")
        #expect(annual != supp)

        // Regression guard: boilerplate-titled appendix / edition ids must NOT be mangled into a
        // stray area fragment. frus1894app1 renders the clean "1894 pt.1" (not "1894 ap pt.1"); the
        // 1951-54 Iran edition stays distinct from the base volume via its full id suffix.
        let appendix = ChronologyViewModel.distilledVolumeLabel(
            volumeId: "frus1894app1", subseries: "1894",
            title: "Papers Relating to the Foreign Relations of the United States, 1894, Appendix I")
        #expect(!appendix.contains(" ap "))
        #expect(!appendix.contains("Sup "))
    }

    /// Label collisions are a whole-corpus property, so an empty manifest cannot show one. This
    /// guarded with `return` and passed on nothing; see `subseriesMatchesBundledManifest` for why
    /// that is the worse half of the pair — a uniqueness proof over zero labels is trivially true.
    @Test("distilledVolumeLabel is unique across the whole bundled corpus (#208)")
    @MainActor
    func distilledLabelUniqueAcrossBundledCorpus() throws {
        let entries = ManifestStore().bundledEntries
        try #require(entries.count > 500, "the bundled manifest must load — an empty one makes this vacuous")
        var seen: [String: String] = [:]
        for entry in entries {
            let label = ChronologyViewModel.distilledVolumeLabel(
                volumeId: entry.volumeId, subseries: entry.subseries, title: entry.title)
            #expect(seen[label] == nil,
                    "Chronology label collision: '\(label)' for both \(seen[label] ?? "") and \(entry.volumeId)")
            seen[label] = entry.volumeId
        }
    }

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

    /// Regression for the CA-4 adversarial-review HIGH finding: **undated** matched
    /// documents fall back to the volume start year in the numerator, so the
    /// denominator MUST count them there too (via the same start-year fallback),
    /// otherwise the "% of documents" share can exceed 100%.
    ///
    /// Reproduces the shape of `frus1919Parisv13` (a handful of dated documents plus
    /// many undated ones that all bucket into the volume's start year, 1919): before
    /// the fix the denominator counted only the dated documents, so a term matching the
    /// undated documents produced `matches / dated-total` far above 100%.
    @Test("undated matches count in both numerator and denominator — share stays ≤ 100%")
    func undatedDocumentsKeepShareWithinBounds() async throws {
        try await withAnalyticsTempDir { dir in
            let (pipeline, store) = try await makeAnalyticsPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")

            // Two DATED documents (1919) and several UNDATED documents (no dateline) —
            // the undated ones all mention "commission" and fall back to the volume's
            // start year (1919) in both numerator and denominator.
            var docs: [(id: String, xml: String)] = [
                ("d1", "<head>1. Memo</head><dateline><date when=\"1919-03-01\">March 1, 1919</date></dateline><p>Peace terms discussed.</p>"),
                ("d2", "<head>2. Memo</head><dateline><date when=\"1919-06-01\">June 1, 1919</date></dateline><p>Treaty drafting continued.</p>"),
            ]
            for i in 1...6 {
                docs.append(("u\(i)", "<head>Undated \(i)</head><p>The commission reviewed the reparations schedule.</p>"))
            }

            try writeAnalyticsVolume(
                to: volDir.appendingPathComponent("frus1919Parisv13.xml"),
                volumeId: "frus1919Parisv13",
                documents: docs
            )
            try await pipeline.indexVolume("frus1919Parisv13")

            let service = CorpusAnalyticsService(fts5Store: store, pipeline: pipeline)
            let scope: Set<String> = ["frus1919Parisv13"]

            // Numerator: "commission" matches the 6 undated docs, bucketed at 1919 (the
            // volume start year, since they have no date_iso).
            let matches = try await service.termFrequencyByYear(term: "commission", volumeIds: scope)
            let match1919 = matches.first { $0.year == 1919 }?.count ?? 0
            #expect(match1919 == 6, "All six undated 'commission' documents bucket into the start year 1919")

            // Denominator: MUST include those undated documents (start-year fallback),
            // so the 1919 total is 8 (2 dated + 6 undated), not 2 (dated only).
            let totals = try await service.documentTotalsByYear(volumeIds: scope)
            let total1919 = totals[1919] ?? 0
            #expect(total1919 == 8, "The denominator counts undated docs at the start year too (2 dated + 6 undated)")

            // The share is therefore 6/8 = 75% — never above 100%. Before the fix the
            // denominator was 2, giving 300%.
            let share = Double(match1919) / Double(total1919) * 100.0
            #expect(share <= 100.0, "Normalized share must not exceed 100%")
            #expect(share == 75.0, "6 of 8 documents in 1919 → 75%")

            // By-Decade inherits the same fix (numerator reuses termFrequencyByYear,
            // denominator reuses documentTotalsByYear).
            let decadeMatches = try await service.termFrequencyByDecade(term: "commission", volumeIds: scope)
            let decadeTotals = try await service.documentTotalsByDecade(volumeIds: scope)
            let m1910s = decadeMatches.first { $0.decadeStart == 1910 }?.count ?? 0
            let t1910s = decadeTotals[1910] ?? 0
            #expect(m1910s == 6 && t1910s == 8, "The 1910s decade bucket mirrors the 1919 year bucket")
            #expect(Double(m1910s) / Double(t1910s) * 100.0 <= 100.0, "By-Decade share also stays ≤ 100%")
        }
    }

    // MARK: - Exact-word queries are refused, not silently widened (R-2 PR-A)

    /// An `=word` query must return NO analytics data rather than data for the word's stem.
    ///
    /// `=word` is a post-filter: the MATCH expression is the stem, and only Search applies
    /// `frus_exact_word` afterwards. This service goes straight to `matchedDocumentKeys`, a bare
    /// MATCH, so charting the expression counted every document containing the STEM — while the
    /// chart's own "View N documents" button sent the researcher to Search, which filters, and showed
    /// fewer. Two authoritative-looking numbers for one query.
    ///
    /// The fixture is the case that makes the difference visible: `containment` and `container` share
    /// the Porter stem `contain`, so a stem-based count is 2 where an exact count is 1.
    @Test("an =exact query yields no analytics series, and the plain stem still charts both documents")
    func exactWordQueriesAreRefusedRatherThanWidened() async throws {
        try await withAnalyticsTempDir { dir in
            let (pipeline, store) = try await makeAnalyticsPipeline(dir: dir)
            let volDir = dir.appendingPathComponent("volumes")
            try writeAnalyticsVolume(
                to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                volumeId: "frus1969-76v01",
                documents: [
                    ("d1", "<head>1. Memo</head><dateline><date when=\"1971-03-01\">March 1, 1971</date></dateline><p>The containment doctrine held.</p>"),
                    ("d2", "<head>2. Memo</head><dateline><date when=\"1971-06-01\">June 1, 1971</date></dateline><p>A shipping container arrived.</p>"),
                ]
            )
            try await pipeline.indexVolume("frus1969-76v01")
            let service = CorpusAnalyticsService(fts5Store: store, pipeline: pipeline)

            // Control: both documents share the stem, so the unmarked query charts 2. Without this
            // the test below would pass just as well against a fixture the index never matched.
            let stemmed = try await service.termFrequencyByYear(term: "containment")
            #expect(stemmed.first { $0.year == 1971 }?.count == 2,
                    "Precondition: the plain query is stem-based and matches BOTH documents — this is exactly the over-count that must not be charted under an =exact query")

            // Every date-bucketed and categorical entry point must refuse, not just the one.
            #expect(try await service.termFrequencyByYear(term: "=containment").isEmpty)
            #expect(try await service.termFrequencyByDecade(term: "=containment").isEmpty)
            #expect(try await service.termFrequencyBySubseries(term: "=containment").isEmpty)
            #expect(try await service.termFrequencyByVolume(term: "=containment").isEmpty)

            // And the refusal must be reportable, or the UI shows a bare "No Results" — which reads
            // as "this word never appears", the opposite of the truth.
            #expect(CorpusAnalyticsService.unsupportedExactTerms(in: "=containment") == ["containment"])
            #expect(CorpusAnalyticsService.unsupportedExactTerms(in: "containment").isEmpty)
            #expect(CorpusAnalyticsService.unsupportedExactTerms(in: "treaty =containment =alliance")
                        == ["containment", "alliance"],
                    "Every exact operand is named, in typed order, so the explanation can list them")

            // Parser 6.3 (#1297 D1): an `=` is an exact filter only where every match must contain the word. In one OR
            // alternative Search ignores it and runs the word by its stem, so Analytics charts the stem too — refusing
            // would name a filter Search does not apply. This was `["containment", "alliance"]` before 6.3.
            #expect(CorpusAnalyticsService.unsupportedExactTerms(in: "treaty =containment OR =alliance").isEmpty)
            #expect(try await service.termFrequencyByYear(term: "=containment OR zzznothing")
                        .first { $0.year == 1971 }?.count == 2,
                    "The ignored mark charts the stem, both documents, exactly as Search runs the query")

            // Parser 6.4 (#1297 round 2): the mark is read from each operand (`ParsedOperand.isExactApplied`). An
            // unmarked containment every match requires does not make the alternative's mark apply, so that query charts
            // by stem; a second, required mark applies, and refuses. Parser 6.5 (round 3, D4) decides the field by
            // requirement over marked operands, so a word marked in every alternative refuses too, and a word one
            // alternative holds unmarked charts. Each answer is the parser's field. Parser 6.6 (round 4) compares marks as
            // the filter reads words, so a word is named once however its marks are spelled, as its first applied mark
            // spells it.
            let perOperand: [(term: String, unsupported: [String])] = [
                ("(=containment OR alliance) containment", []),
                ("(=containment OR alliance) =containment", ["containment"]),
                ("-(alliance -=containment)", ["containment"]),
                ("=containment OR =containment alliance", ["containment"]),
                ("=containment OR containment alliance", []),
                ("=Containment =containment", ["Containment"]),
                ("(=containment OR alliance) =Containment.", ["containment"]),
                ("=Containment. OR =containment alliance", ["Containment."]),
            ]
            for (term, unsupported) in perOperand {
                #expect(CorpusAnalyticsService.unsupportedExactTerms(in: term) == unsupported, "\(term)")
                #expect(FTS5InlineQueryParser.parseDetailed(term).operands.contains(where: \.isExactApplied)
                            == !unsupported.isEmpty,
                        "\(term): refused exactly when an operand's own mark applies")
            }
            #expect(try await service.termFrequencyByYear(term: "(=containment OR alliance) containment")
                        .first { $0.year == 1971 }?.count == 2,
                    "Beside an unmarked required containment, no mark applies, and the stem charts both documents")
            #expect(try await service.termFrequencyByYear(term: "(=containment OR alliance) =containment").isEmpty,
                    "A required mark still refuses rather than charting the stem")
            #expect(try await service.termFrequencyByYear(term: "=containment OR =containment alliance").isEmpty,
                    "Marked in every alternative, every match holds the literal word, so the stem is not charted")
            #expect(try await service.termFrequencyByYear(term: "=containment OR containment alliance")
                        .first { $0.year == 1971 }?.count == 2,
                    "Unmarked in one alternative, no mark applies, and the stem charts both documents")
            #expect(try await service.termFrequencyByYear(term: "=Containment. OR =containment alliance").isEmpty,
                    "Marked in every alternative in two spellings of one word, the stem is not charted either")
        }
    }
}
// MARK: - ByDayTimeZoneTests (#1327)

/// The By-Day series' dates read back as the day they were stored (#1327).
///
/// `date_iso` is a calendar day with no time and no zone. The series used to turn it into an
/// instant at UTC midnight while every consumer — the year-range filter, the totals footnote, the
/// "View N documents" hand-off — read that instant back through a calendar in the DEVICE's zone.
/// West of UTC every 1 January point then reported the previous year, while the table beside it
/// printed the true day. 793 documents in the corpus sit on a 1 January.
///
/// **These tests pin a non-UTC zone deliberately.** On a UTC machine the defect is invisible, so a
/// test that used the ambient zone would have passed on the bug half the time.
///
/// Version history:
///   1.0 — 2026-09-20: #1327
@Suite("Corpus analytics — By Day is zone-consistent (#1327)")
struct ByDayTimeZoneTests {

    /// Runs `body` with the process time zone pinned, then restores it.
    private func withTimeZone(_ identifier: String, _ body: () async throws -> Void) async throws {
        let original = getenv("TZ").map { String(cString: $0) }
        setenv("TZ", identifier, 1)
        NSTimeZone.resetSystemTimeZone()
        defer {
            if let original { setenv("TZ", original, 1) } else { unsetenv("TZ") }
            NSTimeZone.resetSystemTimeZone()
        }
        try await body()
    }

    /// Indexes one document dated `day` (a `yyyy-MM-dd` string) and returns a service over it.
    private func indexDocument(dated day: String, in dir: URL) async throws -> CorpusAnalyticsService {
        let (pipeline, store) = try await makeAnalyticsPipeline(dir: dir)
        let volDir = dir.appendingPathComponent("volumes")
        try writeAnalyticsVolume(
            to: volDir.appendingPathComponent("frus1935v03.xml"),
            volumeId: "frus1935v03",
            documents: [("d1", "<head>1. Telegram</head><dateline><date when=\"\(day)\">\(day)</date></dateline><p>A mandate question.</p>")]
        )
        try await pipeline.indexVolume("frus1935v03")
        return CorpusAnalyticsService(fts5Store: store, pipeline: pipeline)
    }

    @Test("West of UTC, a 1 January document stays in its own day and year")
    func januaryFirstStaysInItsYearWestOfUTC() async throws {
        try await withTimeZone("America/New_York") {
            try await withAnalyticsTempDir { dir in
                let service = try await self.indexDocument(dated: "1935-01-01", in: dir)
                let days = try await service.termFrequencyByDay(term: "mandate")
                let day = try #require(days.first)

                // What the year-range filter, the totals footnote and the "View N documents"
                // hand-off all read (#1327).
                #expect(day.label == "1935-01-01", """
                    The row is labelled \(day.label). The stored day is what every consumer reads; \
                    a label derived from an instant moves west of UTC.
                    """)
                // `DayFrequency.year` is what both year-range filters call.
                #expect(day.year == 1935, """
                    The row reports year \(day.year.map(String.init) ?? "nil"). A year read off the \
                    plotting instant is the year in whichever zone reads it.
                    """)

                // What Swift Charts plots, against the domain the chart builds the same way.
                let plottedYear = Calendar(identifier: .gregorian).component(.year, from: day.date)
                #expect(plottedYear == 1935, """
                    The plotting date reports \(plottedYear) in this zone. Built at UTC midnight and \
                    read back in a western zone, 1 January falls into the previous year — and the \
                    chart domain is built in the device's calendar.
                    """)
            }
        }
    }

    @Test("East of UTC, the same document does not move either")
    func januaryFirstStaysInItsYearEastOfUTC() async throws {
        try await withTimeZone("Asia/Tokyo") {
            try await withAnalyticsTempDir { dir in
                let service = try await self.indexDocument(dated: "1935-01-01", in: dir)
                let days = try await service.termFrequencyByDay(term: "mandate")
                let day = try #require(days.first)
                #expect(day.label == "1935-01-01")
                // Asserted in an EASTERN zone on purpose: a `year` re-derived from the plotting
                // instant — in UTC, say — survives every western check and fails only here.
                #expect(day.year == 1935, """
                    The row reports year \(day.year.map(String.init) ?? "nil") east of UTC.
                    """)
                let calendar = Calendar(identifier: .gregorian)
                #expect(calendar.component(.year, from: day.date) == 1935)
                #expect(calendar.component(.month, from: day.date) == 1)
                #expect(calendar.component(.day, from: day.date) == 1)
            }
        }
    }

    @Test("A 31 December point falls inside the chart domain for its own year")
    func lastDayOfTheYearIsInsideTheDomain() async throws {
        // East of UTC is the half that broke in the other direction: a domain whose upper bound is
        // local midnight on 31 December sits BEFORE a point built at UTC midnight that same day, so
        // the row was counted and not plotted. 1,226 corpus documents sit on a 31 December.
        for zone in ["Asia/Tokyo", "Europe/Berlin", "America/New_York"] {
            try await withTimeZone(zone) {
                try await withAnalyticsTempDir { dir in
                    let service = try await self.indexDocument(dated: "1935-12-31", in: dir)
                    let days = try await service.termFrequencyByDay(term: "mandate")
                    let day = try #require(days.first)

                    // The expression `dayChartSection` uses for `chartXScale(domain:)`, and
                    // `exportDateDomain` for the exported figure.
                    let cal = Calendar(identifier: .gregorian)
                    let start = try #require(cal.date(from: DateComponents(year: 1935, month: 1, day: 1)))
                    let end = try #require(cal.date(from: DateComponents(year: 1935, month: 12, day: 31)))
                    #expect(day.date >= start && day.date <= end, """
                        In \(zone) the 1935-12-31 point sits outside the 1935 domain, so it is \
                        counted in the totals and not drawn.
                        """)
                }
            }
        }
    }

    @Test("The plotting date names the label's own day in the device's zone")
    func plottingDateAgreesWithTheLabel() async throws {
        // The invariant that keeps the two halves joined: whatever builds `date` must build it in
        // the same calendar the chart domain and the axis ticks are read in.
        for zone in ["America/Los_Angeles", "GMT", "Asia/Tokyo"] {
            try await withTimeZone(zone) {
                try await withAnalyticsTempDir { dir in
                    let service = try await self.indexDocument(dated: "1944-06-06", in: dir)
                    let days = try await service.termFrequencyByDay(term: "mandate")
                    let day = try #require(days.first)
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    let rendered = formatter.string(from: day.date)
                    #expect(rendered == day.label, """
                        In \(zone) the plotting date renders as \(rendered) beside a label of \
                        \(day.label).
                        """)
                }
            }
        }
    }

    @Test("The day series and the month series agree about which year a date is in")
    func dayAndMonthAxesAgree() async throws {
        try await withTimeZone("America/New_York") {
            try await withAnalyticsTempDir { dir in
                let service = try await self.indexDocument(dated: "1935-01-01", in: dir)
                let calendar = Calendar(identifier: .gregorian)
                let days = try await service.termFrequencyByDay(term: "mandate")
                let months = try await service.termFrequencyByMonth(term: "mandate")
                let firstDay = try #require(days.first)
                let dayYear = try #require(firstDay.year)
                let monthYear = calendar.component(.year, from: try #require(months.first).date)
                #expect(dayYear == monthYear, """
                    The two date axes disagree about the same document: By Day says \(dayYear), \
                    By Month says \(monthYear). They share the year-range filter.
                    """)
            }
        }
    }
}
