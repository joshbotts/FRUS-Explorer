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
import Synchronization
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif
// The package builds FTS5Store as a module of its own; Xcode compiles it into the app.
#if canImport(FTS5Store)
import FTS5Store
#endif

/// #1680: a search stops when the task running it is cancelled, and nothing else on the pipeline's
/// connection does.
///
/// ## What is pinned
/// - A search in a task already cancelled throws `CancellationError` and returns nothing, for the
///   rows and the count, through `SearchService` (on the code before #1680 both returned their answer).
/// - A statement whose task is cancelled after the check at its start, so that only the progress
///   handler can stop it, stops (the pipeline's prepared-statement hook cancels the task there).
/// - The snippet pass stops at its next row.
/// - Nothing unarmed is stopped: a keyed read and a whole volume's indexing, both on the same
///   connection and both in a cancelled task, run to their end.
///
/// The fixture's statements are long enough for the handler to be called: every document matches,
/// and SQLite calls the handler once every `SearchStatementStop.instructionsBetweenChecks`
/// instructions, a few rows of a ranking pass.
///
/// Version history:
///   1.0 — #1680: initial implementation
@Suite("A cancelled search stops, and nothing else on its connection does")
struct SearchCancellationTests {

    /// How many documents the fixture's volume holds. Each matches the search.
    private static let documents = 400

    /// A service over one volume of `documents` documents that all say "containment", and the folder
    /// that holds it, with a second volume beside it on disk and not yet indexed.
    private func makeFixture() async throws -> (dir: URL, service: SearchService, pipeline: IndexingPipeline) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSCancel-\(UUID().uuidString)", isDirectory: true)
        let volDir = dir.appendingPathComponent("volumes")
        try FileManager.default.createDirectory(at: volDir, withIntermediateDirectories: true)
        for volume in ["vol1", "vol2"] {
            var xml = "<?xml version=\"1.0\"?>\n<TEI><text><body>\n"
            for index in 0..<Self.documents {
                xml += "<div type=\"document\" xml:id=\"d\(index)\"><head>\(index + 1). Item \(index)</head>"
                    + "<p>The doctrine of containment shaped policy toward Europe in \(1945 + index % 8).</p></div>\n"
            }
            xml += "</body></text></TEI>"
            try Data(xml.utf8).write(to: volDir.appendingPathComponent("\(volume).xml"))
        }
        let dbURL = dir.appendingPathComponent("t.sqlite")
        let fts5 = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(fts5Store: fts5, databaseURL: dbURL,
                                            volumesDirectory: volDir, concurrencyLimit: 1)
        try await pipeline.indexVolume("vol1")
        return (dir, SearchService(fts5Store: fts5, pipeline: pipeline), pipeline)
    }

    private func cleanUp(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private static let containment = SearchParameters(keywords: "containment")

    /// The task the caller runs in is cancelled before the search reaches the pipeline, which then
    /// prepares no statement at all: the hook that runs once a statement is prepared never runs.
    @Test("A search in a task already cancelled throws CancellationError, for the rows and the count, and prepares nothing")
    func aSearchInACancelledTaskStops() async throws {
        let fixture = try await makeFixture()
        defer { cleanUp(fixture.dir) }
        let service = fixture.service

        // Anti-vacuity: uncancelled, the fixture answers.
        #expect(try await service.search(parameters: Self.containment, limit: 100).count == 100)
        #expect(try await service.searchCount(parameters: Self.containment) == Self.documents)

        let prepared = HookCalls()
        await fixture.pipeline.setSearchStatementPreparedTestHook {
            _ = prepared.count.wrappingAdd(1, ordering: .relaxed)
        }
        let rows = Task { () async throws -> [SearchResult] in
            withUnsafeCurrentTask { $0?.cancel() }
            return try await service.search(parameters: Self.containment, limit: 100)
        }
        await #expect(throws: CancellationError.self) { try await rows.value }
        let count = Task { () async throws -> Int in
            withUnsafeCurrentTask { $0?.cancel() }
            return try await service.searchCount(parameters: Self.containment)
        }
        await #expect(throws: CancellationError.self) { try await count.value }
        #expect(prepared.count.load(ordering: .relaxed) == 0,
                "a statement was prepared for a task already cancelled")
    }

    /// The prepared-statement hook cancels the running task after the check at the statement's start,
    /// so only the progress handler can stop it: a statement left to run returns its rows or its count.
    /// Driven on the pipeline itself, since `SearchService`'s snippet pass would stop a search whose rows
    /// had come back, and so hide a handler that never acted.
    @Test("A statement whose task is cancelled while it runs stops: the progress handler stops it")
    func aStatementCancelledWhileItRunsStops() async throws {
        let fixture = try await makeFixture()
        defer { cleanUp(fixture.dir) }
        let pipeline = fixture.pipeline
        let (corpus, user) = try await fixture.service.matchExpressions(for: Self.containment)
        let filters = await fixture.service.filtersForTesting(Self.containment)
        let hookCalls = HookCalls()
        await pipeline.setSearchStatementPreparedTestHook {
            _ = hookCalls.count.wrappingAdd(1, ordering: .relaxed)
            withUnsafeCurrentTask { $0?.cancel() }
        }

        let rows = Task { () async throws -> [IndexedSearchRow] in
            try await pipeline.searchDocuments(corpusMatch: corpus, userContentMatch: user, filters: filters,
                                               limit: 100, offset: 0)
        }
        await #expect(throws: CancellationError.self) { try await rows.value }
        let count = Task { () async throws -> Int in
            try await pipeline.searchDocumentsCount(corpusMatch: corpus, userContentMatch: user, filters: filters)
        }
        await #expect(throws: CancellationError.self) { try await count.value }
        // Both statements reached the hook, so the check at their start had passed and the handler
        // was all that could stop them.
        #expect(hookCalls.count.load(ordering: .relaxed) == 2)

        // With the hook gone, the same statements run, so the connection was left as it was.
        await pipeline.setSearchStatementPreparedTestHook(nil)
        let again = try await pipeline.searchDocuments(corpusMatch: corpus, userContentMatch: user,
                                                       filters: filters, limit: 100, offset: 0)
        #expect(again.count == 100)
        #expect(try await pipeline.searchDocumentsCount(corpusMatch: corpus, userContentMatch: user,
                                                        filters: filters) == Self.documents)
    }

    /// The snippet pass is `SearchService`'s own loop over the rows, outside SQLite: it checks at
    /// every row, since on the Mac it is most of a search's time.
    @Test("The snippet pass stops at its next row when its task is cancelled")
    func theSnippetPassStops() async throws {
        let fixture = try await makeFixture()
        defer { cleanUp(fixture.dir) }
        let service = fixture.service
        let (corpus, user) = try await service.matchExpressions(for: Self.containment)
        let filters = await service.filtersForTesting(Self.containment)
        let rows = try await fixture.pipeline.searchDocuments(
            corpusMatch: corpus, userContentMatch: user, filters: filters, limit: 100, offset: 0)
        #expect(rows.count == 100)
        #expect(try await service.results(from: rows, parameters: Self.containment).count == 100)

        let cancelled = Task { () async throws -> [SearchResult] in
            withUnsafeCurrentTask { $0?.cancel() }
            return try await service.results(from: rows, parameters: Self.containment)
        }
        await #expect(throws: CancellationError.self) { try await cancelled.value }
    }

    /// The handler belongs to the whole connection, so what keeps it off every other statement is the
    /// arming. A keyed read and a volume's indexing, both on the pipeline's connection, run in a
    /// cancelled task as before: neither is armed.
    @Test("Statements nothing arms run to their end in a cancelled task: a keyed read and a volume's indexing")
    func unarmedStatementsRunInACancelledTask() async throws {
        let fixture = try await makeFixture()
        defer { cleanUp(fixture.dir) }
        let pipeline = fixture.pipeline
        let keys = (0..<Self.documents).map { (volumeId: "vol1", documentId: "d\($0)") }

        let read = await Task { () -> Result<Int, any Error> in
            withUnsafeCurrentTask { $0?.cancel() }
            do { return .success(try await pipeline.semanticResultRows(forKeys: keys).count) }
            catch { return .failure(error) }
        }.value
        #expect(try read.get() == Self.documents)

        let indexed = await Task { () -> Result<Void, any Error> in
            withUnsafeCurrentTask { $0?.cancel() }
            do { return .success(try await pipeline.indexVolume("vol2")) }
            catch { return .failure(error) }
        }.value
        #expect(throws: Never.self) { try indexed.get() }
        // Every document of the volume indexed in the cancelled task is there to find.
        #expect(try await fixture.service.searchCount(parameters: Self.containment) == 2 * Self.documents)
    }
}

/// How many times a test's prepared-statement hook ran, shared with the `@Sendable` hook.
private final class HookCalls: Sendable {
    let count = Atomic<Int>(0)
}
