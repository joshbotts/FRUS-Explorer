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

// MARK: - ResearchTrailSessionsTests

/// Pins the read-time session grouping that replaced the stored `ResearchSession` (Wave R-2a).
///
/// ## Why the boundary tests are the point
/// The stored model had a defect the contract calls "inherited, to fix rather than carry over":
/// `endedAt` was stamped only when a later event arrived after the idle interval **in the same
/// process**, so a session ended by quitting the app kept `endedAt == nil` forever and read as
/// "Ongoing" in the log. ``never-closed-session`` below is that case, and it passes now for the
/// only reason that counts: nothing stores an end, so nothing can fail to.
///
/// Version history:
///   1.0 — Wave R-2a: initial implementation
///   1.1 — Wave R-2a review fixes: `nilTimestampIsSkipped` **rewritten** as
///          ``nilTimestampIsSkippedFromBothSides``. It asserted `totalActivities == 2` for a store
///          whose page could only ever draw one row — pinning the desynchronisation that made
///          "Show More" endless — so the assertion had to be inverted rather than kept. Two new
///          cases cover the `#Predicate` behind the fix and the all-undated store
struct ResearchTrailSessionsTests {

    // MARK: - Fixtures

    private static let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    /// An activity at `offset` seconds from the epoch.
    private func activity(_ offset: TimeInterval,
                          kind: ResearchTrailActivity.Kind = .documentOpen(
                            volumeId: "frus1969-76v01", documentId: "d1", displayTitle: "Memo"),
                          id: UUID = UUID(),
                          projectId: UUID? = nil) -> ResearchTrailActivity {
        ResearchTrailActivity(id: id,
                              kind: kind,
                              timestamp: Self.epoch.addingTimeInterval(offset),
                              projectId: projectId)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer.makeTestContainer()
    }

    // MARK: - Grouping

    /// Nothing in, nothing out.
    @Test("An empty trail derives no sessions")
    func emptyDerivesNothing() {
        #expect(ResearchTrailSessions.group([]).isEmpty)
    }

    /// Activities inside the idle window are one session, in order, with both bounds set.
    @Test("Activities within the idle window form one session")
    func withinWindowIsOneSession() throws {
        let sessions = ResearchTrailSessions.group([
            activity(0), activity(10 * 60), activity(25 * 60),
        ])

        #expect(sessions.count == 1)
        let session = try #require(sessions.first)
        #expect(session.activityCount == 3)
        #expect(session.startedAt == Self.epoch)
        #expect(session.endedAt == Self.epoch.addingTimeInterval(25 * 60))
        #expect(session.duration == 25 * 60)
    }

    /// **The boundary.** A gap of exactly the idle interval still joins; one second more splits.
    /// Pinned in both directions because an off-by-one here silently re-groups every user's log.
    @Test("The idle boundary joins at exactly 30 minutes and splits one second later")
    func idleBoundaryIsInclusive() {
        let joined = ResearchTrailSessions.group([
            activity(0), activity(ResearchTrailSessions.idleInterval),
        ])
        #expect(joined.count == 1)

        let split = ResearchTrailSessions.group([
            activity(0), activity(ResearchTrailSessions.idleInterval + 1),
        ])
        #expect(split.count == 2)
    }

    /// Sessions come back newest first, and each holds its own activities oldest first — the
    /// order the log draws them in.
    @Test("Sessions are newest first, activities within them oldest first")
    func orderingIsNewestSessionFirst() {
        let sessions = ResearchTrailSessions.group([
            activity(0), activity(60),
            activity(3 * 3_600), activity(3 * 3_600 + 60),
        ])

        #expect(sessions.count == 2)
        #expect(sessions.first?.startedAt == Self.epoch.addingTimeInterval(3 * 3_600))
        #expect(sessions.last?.startedAt == Self.epoch)
        let newest = sessions.first
        #expect(newest?.activities.first?.timestamp == Self.epoch.addingTimeInterval(3 * 3_600))
        #expect(newest?.activities.last?.timestamp == Self.epoch.addingTimeInterval(3 * 3_600 + 60))
    }

    /// Input order does not matter: the grouping sorts first. The log's three source fetches come
    /// back newest-first and interleaved, so this is the real calling convention.
    @Test("Grouping is independent of input order")
    func shuffledInputGroupsIdentically() {
        let activities = [activity(0), activity(60), activity(3 * 3_600), activity(3 * 3_600 + 60)]
        let forward = ResearchTrailSessions.group(activities)
        let backward = ResearchTrailSessions.group(activities.reversed())
        #expect(forward == backward)
    }

    /// Two activities sharing a timestamp to the microsecond are ordered by id, so two runs over
    /// the same data produce the same sessions — and the same `ForEach` identities.
    @Test("A timestamp tie is broken deterministically")
    func timestampTieIsDeterministic() {
        let a = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
        let b = UUID(uuidString: "00000000-0000-0000-0000-0000000000BB")!
        let first = ResearchTrailSessions.group([activity(0, id: b), activity(0, id: a)])
        let second = ResearchTrailSessions.group([activity(0, id: a), activity(0, id: b)])
        #expect(first == second)
        #expect(first.first?.id == a)
    }

    // MARK: - The inherited defect

    /// **The never-closed session.** Under the stored model, a session interrupted by quitting the
    /// app kept `endedAt == nil` forever and the log read "Ongoing" for it years later. A derived
    /// session's end is its last activity, so a long-past session is closed, has a real duration,
    /// and is not ongoing — with no fallback logic in the view to make it so.
    @Test("A session the app never closed still has a real end and is not ongoing")
    func neverClosedSessionIsClosed() throws {
        let sessions = ResearchTrailSessions.group([activity(0), activity(5 * 60)])
        let session = try #require(sessions.first)

        #expect(session.startedAt == Self.epoch)
        #expect(session.endedAt == Self.epoch.addingTimeInterval(5 * 60))
        #expect(session.duration == TimeInterval(300))
        // `epoch` is 2023; "now" is years later.
        #expect(session.isOngoing(asOf: .now) == false)
    }

    /// And the newest session *is* ongoing while the idle window is still open — the state the
    /// stored model could only express by accident.
    @Test("A session whose last activity is recent reads as ongoing")
    func recentSessionIsOngoing() {
        let now = Date.now
        let session = DerivedResearchSession(id: UUID(),
                                             startedAt: now.addingTimeInterval(-600),
                                             endedAt: now.addingTimeInterval(-60),
                                             activities: [])
        #expect(session.isOngoing(asOf: now))
        #expect(session.isOngoing(asOf: now.addingTimeInterval(
            ResearchTrailSessions.idleInterval + 120)) == false)
    }

    // MARK: - Loading

    /// All three tables feed the log, and each keeps its own payload.
    @Test("Reading, search and export history all become activities")
    @MainActor
    func allThreeTypesLoad() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let visit = ReadingHistoryEntry(documentId: "d1", volumeId: "frus1969-76v01",
                                        displayTitle: "Memorandum of Conversation")
        visit.accessedAt = Self.epoch
        context.insert(visit)
        context.insert(SearchHistoryEntry(queryText: "détente", resultCount: 12,
                                          executedAt: Self.epoch.addingTimeInterval(60)))
        context.insert(ExportHistoryEntry(format: "pdf", documentCount: 3,
                                          collectionName: "Berlin",
                                          exportedAt: Self.epoch.addingTimeInterval(120)))
        try context.save()

        let snapshot = SessionLogSnapshot.fetch(from: context)
        #expect(snapshot.totalActivities == 3)
        #expect(snapshot.sessions.count == 1)

        let kinds = snapshot.sessions.first?.activities.map(\.kind) ?? []
        #expect(kinds.count == 3)
        #expect(kinds.contains(.documentOpen(volumeId: "frus1969-76v01",
                                             documentId: "d1",
                                             displayTitle: "Memorandum of Conversation")))
        #expect(kinds.contains(.search(query: "détente", resultCount: 12)))
        #expect(kinds.contains(.export(format: "pdf", documentCount: 3, collectionName: "Berlin")))
    }

    /// The page is the newest *N* activities across all three tables, not *N* of each.
    ///
    /// Without the second truncation the window would be skewed — a table with sparse recent rows
    /// would contribute rows far older than the cut-off, and the sessions derived down there would
    /// be missing the activity that belongs beside them.
    @Test("The page limit is a global newest-N window, not N per table")
    @MainActor
    func pageLimitIsGlobal() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Ten recent visits, and one search from long before them.
        for index in 0..<10 {
            let visit = ReadingHistoryEntry(documentId: "d\(index)", volumeId: "v")
            visit.accessedAt = Self.epoch.addingTimeInterval(Double(index))
            context.insert(visit)
        }
        context.insert(SearchHistoryEntry(queryText: "old", resultCount: 1,
                                          executedAt: Self.epoch.addingTimeInterval(-100_000)))
        try context.save()

        let snapshot = SessionLogSnapshot.fetch(from: context, limit: 5)
        #expect(snapshot.loadedActivities == 5)
        #expect(snapshot.totalActivities == 11, "the total ignores the page limit")
        #expect(snapshot.hasMore)

        let loadedKinds = snapshot.sessions.flatMap(\.activities).map(\.kind)
        #expect(!loadedKinds.contains(.search(query: "old", resultCount: 1)),
                "the old search is outside the newest-5 window even though it is the only search")
    }

    /// A row whose timestamp column is `nil` — possible only on a partially-written or legacy row,
    /// since the columns are optional purely for CloudKit — is dropped rather than placed at some
    /// invented point on the timeline, **and the total drops it too**.
    ///
    /// The first version of this test asserted `totalActivities == 2` "because the count is of
    /// rows, and both rows exist". That is the defect, not the contract: the page skips the
    /// undated row and the total counted it, so `loadedActivities < totalActivities` was true
    /// however far the reader paged and "Show More" could never exhaust.
    @Test("An activity with no timestamp is skipped by the page and by the total alike")
    @MainActor
    func nilTimestampIsSkippedFromBothSides() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let dated = ReadingHistoryEntry(documentId: "d1", volumeId: "v")
        dated.accessedAt = Self.epoch
        context.insert(dated)
        let undated = ReadingHistoryEntry(documentId: "d2", volumeId: "v")
        undated.accessedAt = nil
        context.insert(undated)
        try context.save()

        let snapshot = SessionLogSnapshot.fetch(from: context)
        #expect(snapshot.loadedActivities == 1)
        #expect(snapshot.totalActivities == 1,
                "the total describes the rows the page can draw, or Show More never ends")
        #expect(snapshot.hasMore == false)
        #expect(snapshot.sessions.count == 1)

        // The row is still there — it is undeletable-by-log, not deleted.
        #expect(try context.fetchCount(FetchDescriptor<ReadingHistoryEntry>()) == 2)
        #expect(ResearchTrailSessions.totalActivityCount(in: context) == 2,
                "the delete-magnitude count is of rows and must still see both")
    }

    /// **The predicate that can only fail at runtime.** `datedActivityCount` compares three
    /// optional `Date` columns against a typed `nil` binding inside a `#Predicate`, and a
    /// translation failure would surface as a swallowed `try?` returning zero — which reads as
    /// "empty trail" rather than as an error. So each table is exercised with a mix.
    @Test("The dated-activity count sees every table and excludes exactly the undated rows")
    @MainActor
    func datedActivityCountCoversAllThreeTables() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let visit = ReadingHistoryEntry(documentId: "d1", volumeId: "v")
        visit.accessedAt = Self.epoch
        context.insert(visit)
        let undatedVisit = ReadingHistoryEntry(documentId: "d2", volumeId: "v")
        undatedVisit.accessedAt = nil
        context.insert(undatedVisit)

        context.insert(SearchHistoryEntry(queryText: "détente", resultCount: 1,
                                          executedAt: Self.epoch))
        let undatedSearch = SearchHistoryEntry(queryText: "Berlin", resultCount: 1)
        undatedSearch.executedAt = nil
        context.insert(undatedSearch)

        context.insert(ExportHistoryEntry(format: "pdf", documentCount: 2,
                                          exportedAt: Self.epoch))
        let undatedExport = ExportHistoryEntry(format: "html", documentCount: 1)
        undatedExport.exportedAt = nil
        context.insert(undatedExport)
        try context.save()

        #expect(ResearchTrailSessions.totalActivityCount(in: context) == 6)
        #expect(ResearchTrailSessions.datedActivityCount(in: context) == 3)
    }

    /// The worst version of the desynchronisation: a store of nothing but undated rows derived no
    /// sessions, reported itself non-empty, and drew a blank `List` where the empty state belongs.
    @Test("A store of nothing but undated rows reports itself empty to the log")
    @MainActor
    func anAllUndatedStoreShowsTheEmptyState() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let undated = ReadingHistoryEntry(documentId: "d1", volumeId: "v")
        undated.accessedAt = nil
        context.insert(undated)
        let undatedSearch = SearchHistoryEntry(queryText: "détente", resultCount: 1)
        undatedSearch.executedAt = nil
        context.insert(undatedSearch)
        try context.save()

        let snapshot = SessionLogSnapshot.fetch(from: context)
        #expect(snapshot.isEmpty)
        #expect(snapshot.hasMore == false)
        #expect(snapshot.sessions.isEmpty)
    }

    /// An empty store produces an empty snapshot with nothing hidden behind "Show More".
    @Test("An empty store produces an empty snapshot")
    @MainActor
    func emptyStoreIsEmpty() throws {
        let container = try makeContainer()
        let snapshot = SessionLogSnapshot.fetch(from: container.mainContext)
        #expect(snapshot.isEmpty)
        #expect(!snapshot.hasMore)
        #expect(snapshot.sessions.isEmpty)
    }

    /// The retired tables are not a source. A `SessionEvent` synced in from a device on an older
    /// build shows up in the log only once the migration has re-homed it — which is the honest
    /// behaviour, since the log's job is to describe the trail, not the thing being retired.
    @Test("Legacy session rows are not a source for the derived log")
    @MainActor
    func legacyRowsAreNotASource() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let session = ResearchSession(startedAt: Self.epoch)
        context.insert(session)
        let event = SessionEvent(sessionId: session.id,
                                 timestamp: Self.epoch,
                                 kind: .documentOpen(volumeId: "v", documentId: "d", title: "T"),
                                 sortOrder: 0)
        event.session = session
        context.insert(event)
        try context.save()

        #expect(SessionLogSnapshot.fetch(from: context).isEmpty)
    }
}
