// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData
import Testing
@testable import FRUSExplorer

// MARK: - ResearchTrailMigrationTests

/// The riskiest change in Wave R, pinned.
///
/// `ResearchTrailMigration` moves `.searchSubmit` and `.export` events out of the retired
/// `SessionEvent` store and deletes what is left. Every failure mode is a durable one — a doubled
/// reading history, a duplicated query log, or a silently lost record — and all of them are
/// CloudKit-mirrored, so a mistake propagates to every device the user owns. Hence a test per
/// failure mode rather than a happy path.
///
/// | Risk | Test |
/// |---|---|
/// | reading history doubled | ``documentOpensAreDroppedNotMigrated`` |
/// | pre-R-4 searches lost | ``preR4SearchesAreMigrated`` |
/// | post-R-4 searches doubled | ``postR4SearchesArePairedNotDuplicated`` |
/// | pairing too greedy | ``aLaterRepeatOfTheSameQueryIsNotSwallowed``, ``eachEntryPairsWithOneEventOnly`` |
/// | a second pass duplicating | ``runningTwiceChangesNothing``, ``reImportedEventsAreRecognised`` |
/// | exports lost | ``exportsAreMigratedWithTheirPayload`` |
/// | note saves resurrected | ``noteSavesAreDropped`` |
/// | a launch paying for a no-op | ``anEmptyStoreIsANoOp`` |
///
/// Version history:
///   1.0 — Wave R-2a: initial implementation
@MainActor
struct ResearchTrailMigrationTests {

    // MARK: - Fixtures

    private static let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer.makeTestContainer()
    }

    /// Inserts a legacy event exactly as the retired `AppState.logEvent` would have written it —
    /// through the same `ResearchEventKind` encoding, attached to a `ResearchSession`.
    @discardableResult
    private func insertEvent(_ kind: ResearchEventKind,
                             at offset: TimeInterval,
                             in context: ModelContext,
                             session: ResearchSession? = nil) -> SessionEvent {
        let owner: ResearchSession
        if let session {
            owner = session
        } else {
            owner = ResearchSession(startedAt: Self.epoch.addingTimeInterval(offset))
            context.insert(owner)
        }
        let event = SessionEvent(sessionId: owner.id,
                                 timestamp: Self.epoch.addingTimeInterval(offset),
                                 kind: kind,
                                 sortOrder: owner.events?.count ?? 0)
        event.session = owner
        context.insert(event)
        return event
    }

    /// A visit recorded at a fixed instant, as `recordReadingHistory` would have.
    @discardableResult
    private func insertVisit(_ documentId: String,
                             at offset: TimeInterval,
                             in context: ModelContext) -> ReadingHistoryEntry {
        let visit = ReadingHistoryEntry(documentId: documentId,
                                        volumeId: "frus1969-76v01",
                                        displayTitle: "Memorandum of Conversation")
        visit.accessedAt = Self.epoch.addingTimeInterval(offset)
        context.insert(visit)
        return visit
    }

    // MARK: - Trap 1: reading history must not double

    /// **The trap this migration exists around.** `logEvent(.documentOpen)` and
    /// `recordReadingHistory` fired from the same two views, ~50 lines apart, so every
    /// `.documentOpen` event already has a matching `ReadingHistoryEntry`. Migrating them would
    /// double every user's reading history — the table 11 read sites are built on, including
    /// Project Home's recents, the storage hubs' "opened" dates and Free Up Space ordering.
    @Test("Document-open events are dropped, and reading history is untouched")
    func documentOpensAreDroppedNotMigrated() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // The pair the two views wrote together, three times over.
        for index in 0..<3 {
            let offset = Double(index) * 120
            insertVisit("d\(index)", at: offset, in: context)
            insertEvent(.documentOpen(volumeId: "frus1969-76v01",
                                      documentId: "d\(index)",
                                      title: "Memorandum of Conversation"),
                        at: offset, in: context)
        }
        try context.save()

        let result = ResearchTrailMigration.run(context: context)

        #expect(result.documentOpensDropped == 3)
        #expect(try context.fetchCount(FetchDescriptor<ReadingHistoryEntry>()) == 3,
                "reading history must be exactly what it was")
        #expect(try context.fetchCount(FetchDescriptor<SessionEvent>()) == 0)
    }

    // MARK: - Trap 3: searches, both shapes

    /// The pre-R-4 shape: an iOS `.searchSubmit` with no `SearchHistoryEntry` anywhere near it.
    /// These are the **only** record of those searches, so they must come across — with their
    /// query text, their result count, and their original time.
    @Test("A search event with no counterpart is migrated, keeping its text, count and time")
    func preR4SearchesAreMigrated() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let event = insertEvent(.searchSubmit(query: "détente", resultCount: 12),
                                at: 0, in: context)
        try context.save()

        let result = ResearchTrailMigration.run(context: context)

        #expect(result.searchesMigrated == 1)
        #expect(result.searchesPairedWithExistingEntry == 0)

        let rows = try context.fetch(FetchDescriptor<SearchHistoryEntry>())
        #expect(rows.count == 1)
        #expect(rows.first?.queryText == "détente")
        #expect(rows.first?.resultCount == 12)
        #expect(rows.first?.executedAt == Self.epoch)
        // The row takes the event's id, which is what makes a second pass a no-op.
        #expect(rows.first?.id == event.id)
        // `SessionEvent` carried no project, so inventing one would be a fabricated attribution.
        #expect(rows.first?.projectId == nil)
    }

    /// The post-R-4 shape: R-4 added the iOS `SearchHistoryEntry` producer and **kept** the event,
    /// so a search made since then wrote both records within the same main-actor continuation.
    /// Migrating the event would show the user the same search twice.
    @Test("A search event paired with an existing entry is not migrated")
    func postR4SearchesArePairedNotDuplicated() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Exactly what `SearchView.runSearch()` produced: the event, then the entry a hair later.
        insertEvent(.searchSubmit(query: "détente", resultCount: 12), at: 0, in: context)
        context.insert(SearchHistoryEntry(queryText: "détente", resultCount: 12,
                                          executedAt: Self.epoch.addingTimeInterval(0.05)))
        try context.save()

        let result = ResearchTrailMigration.run(context: context)

        #expect(result.searchesPairedWithExistingEntry == 1)
        #expect(result.searchesMigrated == 0)
        #expect(try context.fetchCount(FetchDescriptor<SearchHistoryEntry>()) == 1)
    }

    /// The tolerance has an outside. A user who runs the same query again ten minutes later ran
    /// two searches, and the log is a method appendix (contract D5) — dropping the second because
    /// its text matches an earlier one would silently delete research history.
    @Test("A later repeat of the same query is migrated, not swallowed by the earlier entry")
    func aLaterRepeatOfTheSameQueryIsNotSwallowed() throws {
        let container = try makeContainer()
        let context = container.mainContext

        context.insert(SearchHistoryEntry(queryText: "détente", resultCount: 12,
                                          executedAt: Self.epoch))
        insertEvent(.searchSubmit(query: "détente", resultCount: 12),
                    at: 10 * 60, in: context)
        try context.save()

        let result = ResearchTrailMigration.run(context: context)

        #expect(result.searchesMigrated == 1)
        #expect(result.searchesPairedWithExistingEntry == 0)
        #expect(try context.fetchCount(FetchDescriptor<SearchHistoryEntry>()) == 2)
    }

    /// The boundary itself, from both sides. Two seconds is the documented window; three is not.
    @Test("Pairing holds inside the tolerance and stops outside it")
    func pairingBoundaryHolds() throws {
        for (gap, expectPaired) in [(1.5, true), (3.0, false)] {
            let container = try makeContainer()
            let context = container.mainContext

            context.insert(SearchHistoryEntry(queryText: "quadripartite", resultCount: 4,
                                              executedAt: Self.epoch.addingTimeInterval(gap)))
            insertEvent(.searchSubmit(query: "quadripartite", resultCount: 4), at: 0, in: context)
            try context.save()

            let result = ResearchTrailMigration.run(context: context)
            #expect(result.searchesPairedWithExistingEntry == (expectPaired ? 1 : 0),
                    "gap \(gap)s should \(expectPaired ? "" : "not ")pair")
            #expect(result.searchesMigrated == (expectPaired ? 0 : 1))
        }
    }

    /// One entry absorbs one event, not all of them. Two events for the same query moments apart
    /// with only one existing entry means one was already recorded and one was not.
    @Test("An existing entry pairs with at most one event")
    func eachEntryPairsWithOneEventOnly() throws {
        let container = try makeContainer()
        let context = container.mainContext

        context.insert(SearchHistoryEntry(queryText: "Berlin", resultCount: 9,
                                          executedAt: Self.epoch))
        insertEvent(.searchSubmit(query: "Berlin", resultCount: 9), at: 0, in: context)
        insertEvent(.searchSubmit(query: "Berlin", resultCount: 9), at: 600, in: context)
        try context.save()

        let result = ResearchTrailMigration.run(context: context)

        #expect(result.searchesPairedWithExistingEntry == 1)
        #expect(result.searchesMigrated == 1)
        #expect(try context.fetchCount(FetchDescriptor<SearchHistoryEntry>()) == 2)
    }

    /// Identical events seconds apart — a filter-only re-run under the old writer, which fired the
    /// event but wrote no entry — collapse to one row. The row this pass inserts joins the
    /// pairable pool and, unlike a pre-existing entry, absorbs **every** near-identical event that
    /// follows: that is what `lastRecordedHistoryQuery` did live, and the reason a
    /// migrated row is not "claimed" the way an existing entry is.
    @Test("Repeated identical events within the tolerance collapse to one row")
    func repeatedEventsWithinToleranceCollapse() throws {
        let container = try makeContainer()
        let context = container.mainContext

        for offset in [0.0, 0.5, 1.2] {
            insertEvent(.searchSubmit(query: "Ostpolitik", resultCount: 3),
                        at: offset, in: context)
        }
        try context.save()

        let result = ResearchTrailMigration.run(context: context)

        #expect(result.searchesMigrated == 1)
        #expect(result.searchesPairedWithExistingEntry == 2)
        #expect(try context.fetchCount(FetchDescriptor<SearchHistoryEntry>()) == 1)
    }

    /// The two writers trimmed differently — `.whitespaces` versus `.whitespacesAndNewlines` — so
    /// a pasted query with a trailing newline did not match itself byte for byte.
    @Test("Pairing survives the two writers' different trimming")
    func pairingNormalisesWhitespace() throws {
        let container = try makeContainer()
        let context = container.mainContext

        context.insert(SearchHistoryEntry(queryText: "détente", resultCount: 12,
                                          executedAt: Self.epoch))
        insertEvent(.searchSubmit(query: "détente\n", resultCount: 12), at: 0, in: context)
        try context.save()

        let result = ResearchTrailMigration.run(context: context)
        #expect(result.searchesPairedWithExistingEntry == 1)
        #expect(try context.fetchCount(FetchDescriptor<SearchHistoryEntry>()) == 1)
    }

    /// Case is not folded: two searches differing only in case are two searches, and the recorded
    /// text is the user's own wording.
    @Test("Pairing is case-sensitive")
    func pairingIsCaseSensitive() throws {
        let container = try makeContainer()
        let context = container.mainContext

        context.insert(SearchHistoryEntry(queryText: "Berlin", resultCount: 9,
                                          executedAt: Self.epoch))
        insertEvent(.searchSubmit(query: "berlin", resultCount: 9), at: 0, in: context)
        try context.save()

        #expect(ResearchTrailMigration.run(context: context).searchesMigrated == 1)
    }

    // MARK: - Exports (contract D1)

    /// Exports are the one kind with no counterpart anywhere, so they migrate unconditionally —
    /// format and document count intact, at their original time.
    @Test("Export events are migrated with their payload")
    func exportsAreMigratedWithTheirPayload() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let event = insertEvent(.export(format: "zotero-api", documentCount: 7), at: 30, in: context)
        insertEvent(.export(format: "pdf", documentCount: 2), at: 60, in: context)
        try context.save()

        let result = ResearchTrailMigration.run(context: context)

        #expect(result.exportsMigrated == 2)
        let rows = try context.fetch(FetchDescriptor<ExportHistoryEntry>())
        #expect(rows.count == 2)
        let zotero = rows.first { $0.format == "zotero-api" }
        #expect(zotero?.documentCount == 7)
        #expect(zotero?.exportedAt == Self.epoch.addingTimeInterval(30))
        #expect(zotero?.id == event.id)
        #expect(zotero?.collectionName == nil,
                "the legacy payload carried no collection name; a migrated row says so")
    }

    // MARK: - Contract D2

    /// Note saves are dropped: `ResearchNote` carries `createdAt` and `lastModified` of its own,
    /// and nothing but the session log ever read the event.
    @Test("Note-save events are dropped and leave nothing behind")
    func noteSavesAreDropped() throws {
        let container = try makeContainer()
        let context = container.mainContext

        insertEvent(.noteSave(noteId: UUID(), documentId: "d1", volumeId: "frus1969-76v01"),
                    at: 0, in: context)
        try context.save()

        let result = ResearchTrailMigration.run(context: context)

        #expect(result.noteSavesDropped == 1)
        #expect(result.searchesMigrated == 0)
        #expect(result.exportsMigrated == 0)
        #expect(try context.fetchCount(FetchDescriptor<SearchHistoryEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ExportHistoryEntry>()) == 0)
    }

    // MARK: - Idempotence

    /// Running twice changes nothing — the second pass has no legacy rows left and exits on a
    /// `fetchCount`.
    @Test("Running the migration twice changes nothing")
    func runningTwiceChangesNothing() throws {
        let container = try makeContainer()
        let context = container.mainContext

        insertEvent(.searchSubmit(query: "détente", resultCount: 12), at: 0, in: context)
        insertEvent(.export(format: "pdf", documentCount: 2), at: 60, in: context)
        insertVisit("d1", at: 30, in: context)
        insertEvent(.documentOpen(volumeId: "frus1969-76v01", documentId: "d1", title: "Memo"),
                    at: 30, in: context)
        try context.save()

        let first = ResearchTrailMigration.run(context: context)
        #expect(first.didRun)

        func searchIds() throws -> [String] {
            try context.fetch(FetchDescriptor<SearchHistoryEntry>())
                .map(\.id.uuidString).sorted()
        }
        let afterFirst = try searchIds()
        let exportsAfterFirst = try context.fetchCount(FetchDescriptor<ExportHistoryEntry>())

        let second = ResearchTrailMigration.run(context: context)
        #expect(second.didRun == false, "nothing left to look at")
        #expect(second == ResearchTrailMigration.Result())

        let afterSecond = try searchIds()
        #expect(afterSecond == afterFirst)
        #expect(try context.fetchCount(FetchDescriptor<ExportHistoryEntry>()) == exportsAfterFirst)
        #expect(try context.fetchCount(FetchDescriptor<ReadingHistoryEntry>()) == 1)
    }

    /// **The multi-device case.** Device A migrates and deletes; the same events arrive again from
    /// device B, which was still on an older build and re-synced them. The second pass must
    /// recognise its own earlier work by id and write nothing — this is the one thing standing
    /// between the design and a query log that grows a copy per sync.
    @Test("Events that arrive again after a migration are recognised, not re-migrated")
    func reImportedEventsAreRecognised() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let searchEvent = insertEvent(.searchSubmit(query: "détente", resultCount: 12),
                                      at: 0, in: context)
        let exportEvent = insertEvent(.export(format: "pdf", documentCount: 2), at: 60, in: context)
        let searchId = searchEvent.id
        let exportId = exportEvent.id
        try context.save()

        ResearchTrailMigration.run(context: context)
        #expect(try context.fetchCount(FetchDescriptor<SearchHistoryEntry>()) == 1)

        // The same two events land again — a CloudKit import from the other device. Same ids,
        // which is exactly what SwiftData would materialise for the same logical records.
        let resurrected = ResearchSession(startedAt: Self.epoch)
        context.insert(resurrected)
        let search = SessionEvent(sessionId: resurrected.id, timestamp: Self.epoch,
                                  kind: .searchSubmit(query: "détente", resultCount: 12),
                                  sortOrder: 0)
        search.id = searchId
        search.session = resurrected
        context.insert(search)
        let export = SessionEvent(sessionId: resurrected.id,
                                  timestamp: Self.epoch.addingTimeInterval(60),
                                  kind: .export(format: "pdf", documentCount: 2), sortOrder: 1)
        export.id = exportId
        export.session = resurrected
        context.insert(export)
        try context.save()

        let second = ResearchTrailMigration.run(context: context)

        #expect(second.didRun)
        #expect(second.searchesAlreadyMigrated == 1)
        #expect(second.exportsAlreadyMigrated == 1)
        #expect(second.searchesMigrated == 0)
        #expect(second.exportsMigrated == 0)
        #expect(try context.fetchCount(FetchDescriptor<SearchHistoryEntry>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ExportHistoryEntry>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<SessionEvent>()) == 0)
    }

    // MARK: - Sweeping up

    /// The legacy tables are emptied, events before sessions (the relationship is `.nullify`, so
    /// the other order orphans them), and a session with no events goes too.
    @Test("The legacy tables are emptied, including sessions with no events")
    func legacyTablesAreEmptied() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let session = ResearchSession(startedAt: Self.epoch)
        context.insert(session)
        insertEvent(.searchSubmit(query: "détente", resultCount: 1), at: 0, in: context,
                    session: session)
        context.insert(ResearchSession(startedAt: Self.epoch.addingTimeInterval(-9_000)))
        try context.save()

        let result = ResearchTrailMigration.run(context: context)

        #expect(result.legacyEventsDeleted == 1)
        #expect(result.legacySessionsDeleted == 2)
        #expect(try context.fetchCount(FetchDescriptor<SessionEvent>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ResearchSession>()) == 0)
    }

    /// An empty store costs one `fetchCount` and reports that it did nothing — which is what makes
    /// running this on every launch, rather than once behind a flag, affordable.
    @Test("An empty store is a no-op")
    func anEmptyStoreIsANoOp() throws {
        let container = try makeContainer()
        let result = ResearchTrailMigration.run(context: container.mainContext)
        #expect(result.didRun == false)
        #expect(result == ResearchTrailMigration.Result())
    }

    /// An event whose payload cannot be read is counted and dropped rather than migrated as an
    /// empty row. A blank query in the log would be indistinguishable from a real search for
    /// nothing.
    @Test("An unreadable event is dropped, not migrated as a blank row")
    func unreadableEventsAreDropped() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let session = ResearchSession(startedAt: Self.epoch)
        context.insert(session)

        // No payload at all.
        let empty = SessionEvent(sessionId: session.id, timestamp: Self.epoch,
                                 kind: .searchSubmit(query: "x", resultCount: 0), sortOrder: 0)
        empty.payload = nil
        empty.session = session
        context.insert(empty)

        // A type nothing knows.
        let unknown = SessionEvent(sessionId: session.id, timestamp: Self.epoch,
                                   kind: .searchSubmit(query: "x", resultCount: 0), sortOrder: 1)
        unknown.eventType = "somethingElse"
        unknown.session = session
        context.insert(unknown)

        // A whitespace-only query, which would render as an empty row.
        insertEvent(.searchSubmit(query: "   ", resultCount: 0), at: 0, in: context,
                    session: session)
        try context.save()

        let result = ResearchTrailMigration.run(context: context)

        #expect(result.unreadableDropped == 3)
        #expect(result.searchesMigrated == 0)
        #expect(try context.fetchCount(FetchDescriptor<SearchHistoryEntry>()) == 0)
    }

    /// The migration is **not** gated on the research-logging preference, and that is deliberate:
    /// it moves records the user already has rather than collecting new ones, and skipping it
    /// while the switch is off would quietly destroy them at the moment the legacy tables are
    /// swept. The switch's own copy promises the opposite — "anything recorded before you turned
    /// it off stays until you delete it".
    @Test("The migration runs regardless of the research-logging switch")
    func migrationIgnoresTheLoggingGate() throws {
        let suiteName = "frus.tests.trailMigration.\(UUID().uuidString)"
        let scratch = UserDefaults(suiteName: suiteName)!
        scratch.set(false, forKey: AppState.researchLoggingPreferenceKey)
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        #expect(AppState.isResearchLoggingEnabled(in: scratch) == false)

        let container = try makeContainer()
        let context = container.mainContext
        insertEvent(.searchSubmit(query: "détente", resultCount: 12), at: 0, in: context)
        try context.save()

        #expect(ResearchTrailMigration.run(context: context).searchesMigrated == 1)
    }

    // MARK: - The legacy payload grammar

    /// The migration's payload reader is the inverse of the encoder the retired writer used, so
    /// the two are pinned against each other rather than by hand-copied JSON.
    @Test("Every legacy event kind round-trips through encode and decode")
    func eventKindsRoundTrip() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let noteId = UUID()

        let kinds: [ResearchEventKind] = [
            .documentOpen(volumeId: "frus1969-76v01", documentId: "d1", title: "Memo"),
            .noteSave(noteId: noteId, documentId: "d1", volumeId: "frus1969-76v01"),
            .searchSubmit(query: "détente", resultCount: 12),
            .export(format: "pdf", documentCount: 3),
        ]
        for (index, kind) in kinds.enumerated() {
            let event = insertEvent(kind, at: Double(index), in: context)
            let decoded = try #require(ResearchEventKind.decode(from: event))
            #expect(decoded.typeString == kind.typeString)
            switch (decoded, kind) {
            case (.searchSubmit(let q, let c), .searchSubmit(let eq, let ec)):
                #expect(q == eq)
                #expect(c == ec)
            case (.export(let f, let c), .export(let ef, let ec)):
                #expect(f == ef)
                #expect(c == ec)
            case (.noteSave(let id, _, _), .noteSave(let expected, _, _)):
                #expect(id == expected)
            default:
                break
            }
        }
    }
}
