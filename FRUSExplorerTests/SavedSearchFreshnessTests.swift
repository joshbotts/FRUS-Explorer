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
import SwiftData
import Testing
@testable import FRUSExplorer

// MARK: - Watermark

/// The `SavedSearch` freshness watermark's storage contract (W-5 / #266).
@Suite("SavedSearch freshness watermark")
@MainActor
struct SavedSearchFreshnessWatermarkTests {

    private func makeSearch() -> SavedSearch {
        var params = SearchParameters()
        params.keywords = "vietnam"
        return SavedSearch(name: "Test", parameters: params)
    }

    @Test("A record starts with no watermark — never run means no badge, not a fake zero")
    func startsNil() {
        #expect(makeSearch().freshness == nil)
    }

    @Test("recordRun stores the exact count, the time, and the volume count")
    func recordRunStores() throws {
        let search = makeSearch()
        search.recordRun(matchCount: 42, indexedVolumeCount: 12)
        let mark = try #require(search.freshness)
        #expect(mark.matchCountAtLastRun == 42)
        #expect(mark.indexedVolumeCountAtLastRun == 12)
        #expect(try #require(mark.lastRunAt).timeIntervalSinceNow > -60)
    }

    @Test("A nil-count run CLEARS the baseline rather than keeping a stale one")
    func nilCountRunClearsBaseline() throws {
        let search = makeSearch()
        search.recordRun(matchCount: 42, indexedVolumeCount: 12)
        search.recordRun(matchCount: nil, indexedVolumeCount: 13)
        let mark = try #require(search.freshness)
        // The user just SAW the current results via the hand-off; the old baseline would
        // keep claiming "+N" about results already seen. Cleared, for the evaluator to
        // backfill.
        #expect(mark.matchCountAtLastRun == nil)
        #expect(mark.lastRunAt != nil)
    }

    @Test("A corrupt blob degrades to no watermark, never a crash")
    func corruptBlobIsNil() {
        let search = makeSearch()
        search.freshnessData = Data("not json".utf8)
        #expect(search.freshness == nil)
    }

    @Test("Unknown fields are ignored and a wrong-typed field degrades per-field")
    func tolerantDecoding() throws {
        // A blob from a future build: an extra field, and one field of the wrong type.
        // Date rides as a Double (JSONDecoder's default deferredToDate), so 0 = epoch.
        let json = """
        {"lastRunAt": 0, "matchCountAtLastRun": "twelve", "someFutureField": true}
        """
        let mark = try JSONDecoder().decode(SavedSearchFreshness.self, from: Data(json.utf8))
        #expect(mark.lastRunAt == Date(timeIntervalSinceReferenceDate: 0))
        #expect(mark.matchCountAtLastRun == nil)   // wrong type → that field only degrades
        #expect(mark.indexedVolumeCountAtLastRun == nil)
    }

    @Test("The stamper reaches SavedSearch — the merge tiebreaker the record never had")
    func stamperReachesSavedSearch() throws {
        let container = try ModelContainer(
            for: SavedSearch.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        let stamper = ModelModificationStamper()
        stamper.start(observing: context)
        defer { stamper.stop() }
        let epoch = Date(timeIntervalSince1970: 0)

        let search = makeSearch()
        context.insert(search)
        try context.save()
        search.lastModified = epoch
        try context.save()

        search.recordRun(matchCount: 5, indexedVolumeCount: 1)
        try context.save()
        #expect(try #require(search.lastModified) > epoch)
    }
}

// MARK: - Verdict

/// The freshness verdict arithmetic (W-5 / #266).
@Suite("SavedSearch freshness verdict")
struct SavedSearchFreshnessVerdictTests {

    @Test("Growth yields the exact positive delta")
    func growthIsDelta() async {
        #expect(await SavedSearchFreshnessEvaluator.verdict(current: 50, baseline: 42) == 8)
        #expect(await SavedSearchFreshnessEvaluator.verdict(current: 1, baseline: 0) == 1)
    }

    @Test("No change and shrinkage both yield no badge")
    func noGrowthIsNil() async {
        #expect(await SavedSearchFreshnessEvaluator.verdict(current: 42, baseline: 42) == nil)
        // Results going AWAY (a removed volume) is not news the NEW capsule should claim.
        #expect(await SavedSearchFreshnessEvaluator.verdict(current: 30, baseline: 42) == nil)
    }
}

// MARK: - Evaluator over a live index

/// The evaluator end to end (W-5 / #266): a real pipeline, a real `SearchService.searchCount`,
/// a real SwiftData record — so the baseline/backfill/verdict seams are the shipped ones.
@Suite("SavedSearch freshness evaluator")
@MainActor
struct SavedSearchFreshnessEvaluatorTests {

    /// One volume, two documents mentioning "vietnam"; a second volume adds a third.
    private func writeVolume(to url: URL, volumeId: String, docs: [(String, String)]) throws {
        let blocks = docs.map {
            "<div type=\"document\" xml:id=\"\($0.0)\" n=\"\($0.0)\"><head>\($0.0)</head><p>\($0.1)</p></div>"
        }.joined(separator: "\n")
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
          <teiHeader><fileDesc><titleStmt><title>\(volumeId)</title></titleStmt>
          <publicationStmt><date>2003</date></publicationStmt>
          <sourceDesc><p>Test fixture</p></sourceDesc></fileDesc></teiHeader>
          <text><body><div type="compilation" xml:id="comp1">\(blocks)</div></body></text>
        </TEI>
        """
        try xml.data(using: .utf8)!.write(to: url)
    }

    private func makeContext() throws -> (ModelContainer, ModelContext) {
        let container = try ModelContainer(
            for: SavedSearch.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        return (container, container.mainContext)
    }

    @Test("New results since the recorded baseline badge with the exact delta")
    func newResultsBadge() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSFreshness-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let (pipeline, store) = try await makeTestPipeline(dir: dir)
        let volDir = dir.appendingPathComponent("volumes")
        try writeVolume(to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                        volumeId: "frus1969-76v01",
                        docs: [("d1", "vietnam negotiations"), ("d2", "vietnam ceasefire")])
        try await pipeline.indexVolume("frus1969-76v01")
        let service = SearchService(fts5Store: store, pipeline: pipeline)

        let (container, context) = try makeContext()
        _ = container
        var params = SearchParameters()
        params.keywords = "vietnam"
        let search = SavedSearch(name: "Vietnam", parameters: params)
        context.insert(search)
        // The last run saw 1 result; the index now holds 2.
        search.recordRun(matchCount: 1, indexedVolumeCount: 1)
        try context.save()

        let verdict = await SavedSearchFreshnessEvaluator.newResultCount(
            for: search, service: service, context: context)
        #expect(verdict == 1)
    }

    @Test("Never run means no badge; a nil baseline is backfilled once, silently")
    func neverRunAndBackfill() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSFreshness-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let (pipeline, store) = try await makeTestPipeline(dir: dir)
        let volDir = dir.appendingPathComponent("volumes")
        try writeVolume(to: volDir.appendingPathComponent("frus1969-76v01.xml"),
                        volumeId: "frus1969-76v01",
                        docs: [("d1", "vietnam negotiations"), ("d2", "vietnam ceasefire")])
        try await pipeline.indexVolume("frus1969-76v01")
        let service = SearchService(fts5Store: store, pipeline: pipeline)

        let (container, context) = try makeContext()
        _ = container
        var params = SearchParameters()
        params.keywords = "vietnam"
        let search = SavedSearch(name: "Vietnam", parameters: params)
        context.insert(search)
        try context.save()

        // Never run: no watermark, no badge, and no watermark invented.
        #expect(await SavedSearchFreshnessEvaluator.newResultCount(
            for: search, service: service, context: context) == nil)
        #expect(search.freshness == nil)

        // A hand-off run: time stamped, count unknown.
        search.recordRun(matchCount: nil, indexedVolumeCount: 1)
        try context.save()
        let lastRun = search.freshness?.lastRunAt

        // First evaluation backfills the baseline (2) without advancing lastRunAt — no badge.
        #expect(await SavedSearchFreshnessEvaluator.newResultCount(
            for: search, service: service, context: context) == nil)
        #expect(search.freshness?.matchCountAtLastRun == 2)
        #expect(search.freshness?.lastRunAt == lastRun)

        // The corpus grows; the next evaluation badges against the backfilled baseline.
        try writeVolume(to: volDir.appendingPathComponent("frus1969-76v02.xml"),
                        volumeId: "frus1969-76v02",
                        docs: [("d1", "vietnam aftermath")])
        try await pipeline.indexVolume("frus1969-76v02")
        #expect(await SavedSearchFreshnessEvaluator.newResultCount(
            for: search, service: service, context: context) == 1)
    }
}
