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
/// - A statement that ends before the handler's first call, and a snippet pass with no rows, still
///   give a cancelled task no answer: the checks after them throw.
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
        await fixture.pipeline.setSearchStatementTestHook { moment in
            if moment == .prepared { prepared.record() }
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
        #expect(prepared.count == 0,
                "a statement was prepared for a task already cancelled")
    }

    /// The test hook cancels the running task once the statement is prepared, after the check at its
    /// start, so only the progress handler can stop it before its end. The hook's second moment says
    /// whether it did: a statement left to run reaches `.ranToItsEnd`, and its answer would then be
    /// dropped by the check after it, which would hide a handler that never acted. Driven on the
    /// pipeline itself, since `SearchService`'s snippet pass would hide it too.
    @Test("A statement whose task is cancelled while it runs stops: the progress handler stops it")
    func aStatementCancelledWhileItRunsStops() async throws {
        let fixture = try await makeFixture()
        defer { cleanUp(fixture.dir) }
        let pipeline = fixture.pipeline
        let (corpus, user) = try await fixture.service.matchExpressions(for: Self.containment)
        let filters = await fixture.service.filtersForTesting(Self.containment)
        let hookCalls = HookCalls()
        let ranToItsEnd = HookCalls()
        await pipeline.setSearchStatementTestHook { moment in
            switch moment {
            case .prepared:
                hookCalls.record()
                withUnsafeCurrentTask { $0?.cancel() }
            case .ranToItsEnd:
                ranToItsEnd.record()
            }
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
        // Both statements reached the hook, so the check at their start had passed, and neither ran to
        // its end: the handler stopped both.
        #expect(hookCalls.count == 2)
        #expect(ranToItsEnd.count == 0, "a statement whose task was cancelled ran to its end")

        // With the hook gone, the same statements run, so the connection was left as it was.
        await pipeline.setSearchStatementTestHook(nil)
        let again = try await pipeline.searchDocuments(corpusMatch: corpus, userContentMatch: user,
                                                       filters: filters, limit: 100, offset: 0)
        #expect(again.count == 100)
        #expect(try await pipeline.searchDocumentsCount(corpusMatch: corpus, userContentMatch: user,
                                                        filters: filters) == Self.documents)
    }

    /// A statement over a word in no document runs a few dozen instructions and ends before the
    /// handler is ever called, so only the check after it can keep its answer from a cancelled task.
    @Test("A statement that ends before the handler's first call gives a cancelled task no answer")
    func aStatementTooShortForTheHandlerGivesNoAnswer() async throws {
        let fixture = try await makeFixture()
        defer { cleanUp(fixture.dir) }
        let pipeline = fixture.pipeline
        let nowhere = SearchParameters(keywords: "xylophonic")
        let (corpus, user) = try await fixture.service.matchExpressions(for: nowhere)
        let filters = await fixture.service.filtersForTesting(nowhere)
        // Anti-vacuity: uncancelled, the statements answer, with nothing.
        #expect(try await pipeline.searchDocumentsCount(corpusMatch: corpus, userContentMatch: user,
                                                        filters: filters) == 0)
        let ranToItsEnd = HookCalls()
        await pipeline.setSearchStatementTestHook { moment in
            switch moment {
            case .prepared: withUnsafeCurrentTask { $0?.cancel() }
            case .ranToItsEnd: ranToItsEnd.record()
            }
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
        // Both ended on their own, so the check after them is what threw.
        #expect(ranToItsEnd.count == 2, "fixture guard: a statement over no match did not run to its end")
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
        // With no row to check at, the check after the loop is the one that answers.
        let noRows = Task { () async throws -> [SearchResult] in
            withUnsafeCurrentTask { $0?.cancel() }
            return try await service.results(from: [], parameters: Self.containment)
        }
        await #expect(throws: CancellationError.self) { try await noRows.value }
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

/// How many times a test's prepared-statement hook ran, shared with the `@Sendable` hook, which runs on
/// the pipeline's executor. A lock rather than an atomic: a suite here imports nothing the kit does not.
private final class HookCalls: @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0

    /// Counts one call.
    func record() {
        lock.lock()
        calls += 1
        lock.unlock()
    }

    /// The calls counted so far.
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }
}
