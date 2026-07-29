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

import Testing
import Foundation
@testable import FRUSExplorer

/// The Query Inspector's controller: what it refreshes, and what it refuses to (Q-2b).
///
/// The interesting behaviour here is *restraint*. The cheap pass may run on typing; the
/// expensive one must not. A controller that quietly ran a query per operand on every
/// keystroke would look fine in a fixture and make the app unusable at 314k documents.
///
/// Version history:
///   1.0 — Q-2b: initial implementation
@Suite("Query inspector controller")
@MainActor
struct QueryInspectorControllerTests {

    private func makeFixture() async throws -> (dir: URL, service: SearchService) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSCtl-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        try """
        <?xml version="1.0"?>
        <TEI><text><body>
        <div type="document" xml:id="d1">
          <head>1. Memorandum</head>
          <p>The doctrine of containment shaped policy toward europe.</p>
        </div>
        </body></text></TEI>
        """.data(using: .utf8)!.write(to: volDir.appendingPathComponent("vol1.xml"))

        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(
            fts5Store: fts5, databaseURL: dbURL, volumesDirectory: volDir, concurrencyLimit: 1)
        try await pipeline.indexVolume("vol1")
        return (dir, SearchService(fts5Store: fts5, pipeline: pipeline))
    }

    private func cleanUp(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    // MARK: - The cheap pass

    @Test("A refresh populates the inspection but runs no search")
    func refreshIsCheap() async throws {
        let (dir, service) = try await makeFixture()
        defer { cleanUp(dir) }

        let controller = QueryInspectorController()
        await controller.refresh(parameters: SearchParameters(keywords: "containment europe"),
                                 service: service, indexedVolumeCount: 1)

        let inspection = try #require(controller.inspection)
        #expect(inspection.operands.count == 2)
        #expect(inspection.operands.allSatisfy { $0.scopedCount == nil },
                "the cheap pass must not have run a per-operand search")
        #expect(inspection.operands.allSatisfy { $0.corpusDocumentFrequency != nil },
                "but it must have done the free vocabulary lookups")
    }

    @Test("Refreshing with no service is a no-op rather than a crash")
    func noServiceIsSafe() async {
        let controller = QueryInspectorController()
        await controller.refresh(parameters: SearchParameters(keywords: "x"),
                                 service: nil, indexedVolumeCount: 0)
        #expect(controller.inspection == nil)
    }

    /// A stale decomposition would blame a term the researcher has since edited away.
    @Test("A new refresh clears the previous decomposition")
    func refreshClearsStaleBlame() async throws {
        let (dir, service) = try await makeFixture()
        defer { cleanUp(dir) }

        let controller = QueryInspectorController()
        let empty = SearchParameters(keywords: "europe formosa")
        await controller.refresh(parameters: empty, service: service, indexedVolumeCount: 1)
        await controller.decomposeZeroResult(parameters: empty, service: service)
        #expect(!controller.emptyConjuncts.isEmpty, "formosa should be blamed")

        await controller.refresh(parameters: SearchParameters(keywords: "europe"),
                                 service: service, indexedVolumeCount: 1)
        #expect(controller.emptyConjuncts.isEmpty,
                "the blame must not survive into a query that no longer contains the term")
    }

    // MARK: - The expensive pass

    @Test("Scoped counts fill in on demand, preserving the rest of the inspection")
    func scopedCountsFillIn() async throws {
        let (dir, service) = try await makeFixture()
        defer { cleanUp(dir) }

        let controller = QueryInspectorController()
        let params = SearchParameters(keywords: "containment europe")
        await controller.refresh(parameters: params, service: service, indexedVolumeCount: 7)
        await controller.loadScopedCounts(parameters: params, service: service)

        let inspection = try #require(controller.inspection)
        #expect(inspection.operands.allSatisfy { $0.scopedCount != nil })
        #expect(inspection.indexedVolumeCount == 7, "the denominator must survive the update")
        #expect(inspection.expression != nil, "so must the expression")
        #expect(inspection.operands.allSatisfy { $0.stem != nil },
                "and the stems, which the expensive pass does not recompute")
    }

    @Test("Loading scoped counts before any inspection exists is a no-op")
    func scopedCountsNeedAnInspection() async throws {
        let (dir, service) = try await makeFixture()
        defer { cleanUp(dir) }

        let controller = QueryInspectorController()
        await controller.loadScopedCounts(parameters: SearchParameters(keywords: "x"),
                                          service: service)
        #expect(controller.inspection == nil)
        #expect(!controller.isCountingScoped)
    }

    @Test("The counting flag is cleared even when the pass finishes")
    func countingFlagIsCleared() async throws {
        let (dir, service) = try await makeFixture()
        defer { cleanUp(dir) }

        let controller = QueryInspectorController()
        let params = SearchParameters(keywords: "containment")
        await controller.refresh(parameters: params, service: service, indexedVolumeCount: 1)
        await controller.loadScopedCounts(parameters: params, service: service)
        #expect(!controller.isCountingScoped, "a stuck flag hides the button forever")
    }

    // MARK: - Decomposition

    @Test("Decomposition names the empty conjunct")
    func decompositionNamesTheCulprit() async throws {
        let (dir, service) = try await makeFixture()
        defer { cleanUp(dir) }

        let controller = QueryInspectorController()
        let params = SearchParameters(keywords: "europe formosa")
        await controller.refresh(parameters: params, service: service, indexedVolumeCount: 1)
        await controller.decomposeZeroResult(parameters: params, service: service)
        #expect(controller.emptyConjuncts.map(\.text) == ["formosa"])
    }

    @Test("Decomposition without an inspection leaves no blame behind")
    func decompositionNeedsAnInspection() async throws {
        let (dir, service) = try await makeFixture()
        defer { cleanUp(dir) }

        let controller = QueryInspectorController()
        await controller.decomposeZeroResult(parameters: SearchParameters(keywords: "formosa"),
                                             service: service)
        #expect(controller.emptyConjuncts.isEmpty)
    }

    // MARK: - The debounce

    /// Not a timing test — those are flaky. This pins the constant against the band the
    /// design asks for, so a careless edit to "0" (making every keystroke a query burst)
    /// or to something long enough to feel broken fails here.
    @Test("The debounce is in the band the design specifies")
    func debounceIsInBand() {
        #expect(QueryInspectorController.debounce >= .milliseconds(150),
                "shorter and a fast typist triggers a lookup per character")
        #expect(QueryInspectorController.debounce <= .milliseconds(600),
                "longer and the expression stops feeling connected to the typing")
    }
}
