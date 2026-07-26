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

// MARK: - ResearchSessionsSummaryTests

/// Tests the Research Sessions pane's log-row copy and its delete.
///
/// Version history:
///   1.0 — initial implementation
///   1.1 — Wave R-2a: counting is over the derived trail, and the pane's delete is
///          `HistoryTrailAdmin.deleteAll` (the whole trail) rather than
///          `ResearchSessionAdmin.deleteAll` (the retired tables). The `.nullify` assertion that
///          made the old delete correct is kept, because the migration still relies on it.
///   1.2 — Wave R-2a review fixes: the truncated-scan floor wording, the exactness flag, and the
///          undated-row store whose delete control disabled itself
struct ResearchSessionsSummaryTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer.makeTestContainer()
    }

    /// A visit at a fixed instant.
    @MainActor
    private func insertVisit(_ context: ModelContext, at seconds: TimeInterval) {
        let visit = ReadingHistoryEntry(documentId: "d\(Int(seconds))", volumeId: "frus1969-76v01")
        visit.accessedAt = Date(timeIntervalSince1970: seconds)
        context.insert(visit)
    }

    // MARK: - Copy

    /// An empty log says so in words rather than "0 sessions · 0 events", which reads as a broken
    /// counter rather than a log nothing has been written to.
    @Test("An empty log says nothing is recorded")
    func emptyCopy() {
        #expect(ResearchSessionsSummary.empty.text() == "Nothing recorded yet")
        #expect(ResearchSessionsSummary.empty.isEmpty)
    }

    /// A session recorded today is timed; one from before is dated. A bare time on a three-week-
    /// old log would read as current.
    @Test("Today is timed, earlier is dated")
    func recencyWording() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let today = ResearchSessionsSummary(sessionCount: 3, eventCount: 40,
                                            lastSessionStart: now.addingTimeInterval(-600))
        #expect(today.text(now: now).contains("last today"))

        let older = ResearchSessionsSummary(sessionCount: 3, eventCount: 40,
                                            lastSessionStart: now.addingTimeInterval(-60 * 60 * 24 * 9))
        let text = older.text(now: now)
        #expect(!text.contains("last today"))
        #expect(text.contains("last "))
    }

    /// Both counts appear, and both agree in number.
    @Test("Counts agree in number")
    func countAgreement() {
        #expect(ResearchSessionsSummary.sessions(1) == "1 session")
        #expect(ResearchSessionsSummary.sessions(0) == "0 sessions")
        #expect(ResearchSessionsSummary.sessions(12) == "12 sessions")
        #expect(ResearchSessionsSummary.events(1) == "1 event")
        #expect(ResearchSessionsSummary.events(340) == "340 events")

        let summary = ResearchSessionsSummary(sessionCount: 1, eventCount: 1, lastSessionStart: nil)
        #expect(summary.text() == "1 session · 1 event")
    }

    /// A summary with counts but no start date still reports the counts — every timestamp column
    /// is optional for CloudKit compatibility, so a legacy or partially-written row must not blank
    /// the row.
    @Test("A missing start date does not blank the line")
    func missingStartDate() {
        let summary = ResearchSessionsSummary(sessionCount: 2, eventCount: 5, lastSessionStart: nil)
        #expect(summary.text() == "2 sessions · 5 events")
    }

    /// **The magnitude the delete dialog used to understate.** The session count comes off a
    /// 1,000-activity scan; the delete is unbounded. A measured run had the confirmation say "1000
    /// sessions" and destroy 1,200. When the scan is truncated the row says "at least", and the
    /// dialog quotes the exact activity total instead.
    @Test("A truncated scan is reported as a floor, not a total")
    func approximateSessionCountSaysSo() {
        #expect(ResearchSessionsSummary.sessions(12, exact: false) == "at least 12 sessions")
        #expect(ResearchSessionsSummary.sessions(1, exact: false) == "at least 1 session")
        #expect(ResearchSessionsSummary.sessions(12) == "12 sessions", "the exact form is unchanged")

        let approximate = ResearchSessionsSummary(sessionCount: 1_000, eventCount: 12_400,
                                                  lastSessionStart: nil,
                                                  isSessionCountExact: false)
        #expect(approximate.text() == "at least 1000 sessions · 12400 events")
    }

    /// The scan limit is where the flag flips, and the activity total stays exact on both sides of
    /// it — it is three `fetchCount`s, which is why it is what the confirmation dialog quotes.
    @Test("The exactness flag follows the scan limit")
    @MainActor
    func exactnessFollowsTheScanLimit() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Comfortably inside the window.
        insertVisit(context, at: 1_000)
        insertVisit(context, at: 2_000)
        try context.save()
        let small = ResearchSessionsSummary.fetch(from: context)
        #expect(small.isSessionCountExact)
        #expect(small.eventCount == 2)

        // Fill the scan window exactly, which is the point at which older rows may exist unseen.
        for index in 0..<ResearchSessionsSummary.activityScanLimit {
            insertVisit(context, at: 100_000 + Double(index) * 60)
        }
        try context.save()
        let large = ResearchSessionsSummary.fetch(from: context)
        #expect(large.isSessionCountExact == false)
        #expect(large.eventCount == ResearchSessionsSummary.activityScanLimit + 2,
                "the activity total is exact whatever the scan saw")
    }

    /// **The delete control that disabled itself over the user's data.** `isEmpty` used to ask
    /// whether any session could be derived. A row with no timestamp derives none — so a store
    /// holding recorded query text reported itself empty, greyed out "Delete Recorded Sessions…",
    /// and left that text in the user's iCloud database with no way to remove it.
    @Test("Undated rows still enable the delete")
    @MainActor
    func undatedRowsAreStillDeletable() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let undated = SearchHistoryEntry(queryText: "a query the user wants gone", resultCount: 3)
        undated.executedAt = nil
        context.insert(undated)
        try context.save()

        let summary = ResearchSessionsSummary.fetch(from: context)
        #expect(summary.sessionCount == 0, "no timestamp, so no session can be derived")
        #expect(summary.eventCount == 1)
        #expect(summary.isEmpty == false, "there is something to delete, so the control is live")

        HistoryTrailAdmin.deleteAll(context: context)
        #expect(try context.fetchCount(FetchDescriptor<SearchHistoryEntry>()) == 0)
    }

    // MARK: - Counting

    /// The summary counts the derived sessions and the raw activities behind them.
    ///
    /// Two visits eleven minutes apart are one session; a third an hour later is a second. The
    /// activity total is all three, and the reported start is the **newest** session's — the row
    /// answers "when did it last record?".
    @Test("Fetch counts derived sessions and their activities")
    @MainActor
    func fetchCounts() throws {
        let container = try makeContainer()
        let context = container.mainContext

        insertVisit(context, at: 1_000)
        insertVisit(context, at: 1_000 + 11 * 60)
        context.insert(SearchHistoryEntry(queryText: "détente", resultCount: 4,
                                          executedAt: Date(timeIntervalSince1970: 1_000 + 12 * 60)))
        insertVisit(context, at: 1_000 + 3_600)
        try context.save()

        let summary = ResearchSessionsSummary.fetch(from: context)
        #expect(summary.sessionCount == 2)
        #expect(summary.eventCount == 4)
        #expect(summary.lastSessionStart == Date(timeIntervalSince1970: 1_000 + 3_600),
                "newest session should win")
    }

    /// An empty trail reports empty, whatever is left in the retired tables.
    ///
    /// A stray `SessionEvent` synced in from a device on an older build must not make the pane
    /// claim there is something to look at: the log does not read those rows, and the migration
    /// will retire them at the next pass.
    @Test("Legacy session rows alone do not make the summary non-empty")
    @MainActor
    func legacyRowsDoNotCount() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let session = ResearchSession(startedAt: Date(timeIntervalSince1970: 500))
        context.insert(session)
        let event = SessionEvent(sessionId: session.id,
                                 timestamp: Date(timeIntervalSince1970: 500),
                                 kind: .documentOpen(volumeId: "v", documentId: "d", title: "T"),
                                 sortOrder: 0)
        event.session = session
        context.insert(event)
        try context.save()

        #expect(ResearchSessionsSummary.fetch(from: context).isEmpty)
    }

    // MARK: - Deleting

    /// The whole point of the pane's delete: nothing the user can see survives it.
    ///
    /// Since Wave R-2a "Delete Recorded Sessions…" reaches the whole trail. It has to: sessions
    /// are derived from these rows, so a delete that spared them would count twelve sessions in
    /// its confirmation dialog and then leave all twelve on screen.
    @Test("The pane's delete removes the whole trail")
    @MainActor
    func deleteAllRemovesTheTrail() throws {
        let container = try makeContainer()
        let context = container.mainContext

        insertVisit(context, at: 1_000)
        insertVisit(context, at: 2_000)
        context.insert(SearchHistoryEntry(queryText: "quadripartite", resultCount: 31))
        context.insert(ExportHistoryEntry(format: "pdf", documentCount: 4))
        // A legacy row a device on an older build might still be syncing in.
        let session = ResearchSession(startedAt: Date(timeIntervalSince1970: 100))
        context.insert(session)
        let event = SessionEvent(sessionId: session.id,
                                 timestamp: Date(timeIntervalSince1970: 100),
                                 kind: .searchSubmit(query: "quadripartite", resultCount: 31),
                                 sortOrder: 0)
        event.session = session
        context.insert(event)
        try context.save()

        let removed = HistoryTrailAdmin.deleteAll(context: context)
        #expect(removed.visits == 2)
        #expect(removed.searches == 1)
        #expect(removed.exports == 1)
        #expect(removed.legacyEvents == 1)
        #expect(removed.legacySessions == 1)
        #expect(removed.trailTotal == 4)

        #expect(ResearchSessionsSummary.fetch(from: context).isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<ReadingHistoryEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SearchHistoryEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ExportHistoryEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SessionEvent>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ResearchSession>()) == 0)
    }

    /// The delete leaves everything else alone, which is exactly what the confirmation copy
    /// promises. A destructive action whose blast radius is stated in words needs the words to be
    /// checkable.
    @Test("The trail delete does not touch notes, tags or collections")
    @MainActor
    func deleteAllSparesOtherRecords() throws {
        let container = try makeContainer()
        let context = container.mainContext

        context.insert(ResearchNote(documentId: "d1", volumeId: "frus1969-76v01",
                                    bodyText: "A note"))
        context.insert(UserTag(name: "Berlin"))
        context.insert(Collection(name: "Détente"))
        insertVisit(context, at: 1_000)
        try context.save()

        HistoryTrailAdmin.deleteAll(context: context)

        #expect(try context.fetchCount(FetchDescriptor<ResearchNote>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<UserTag>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Collection>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ReadingHistoryEntry>()) == 0)
    }

    /// Deleting an empty trail is a no-op, not a crash.
    @Test("Delete on an empty trail does nothing")
    @MainActor
    func deleteEmptyIsSafe() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let removed = HistoryTrailAdmin.deleteAll(context: context)
        #expect(removed == HistoryTrailAdmin.DeletedCounts())
    }

    /// The legacy sweep the migration still depends on.
    ///
    /// Events are deleted explicitly rather than left to the relationship's delete rule:
    /// `ResearchSession.events` is `.nullify`, so deleting only the sessions would leave orphaned
    /// events alive with a dangling `sessionId` — invisible everywhere and impossible to remove.
    /// This is the assertion that catches a well-meant "just delete the sessions, the cascade
    /// handles it", and it matters more now than it did: `ResearchTrailMigration` finishes by
    /// calling this.
    @Test("The legacy sweep deletes events explicitly, not by cascade")
    @MainActor
    func legacySweepDeletesEventsExplicitly() throws {
        let container = try makeContainer()
        let context = container.mainContext

        for index in 0..<3 {
            let session = ResearchSession(startedAt: Date(timeIntervalSince1970: Double(index * 100)))
            context.insert(session)
            let event = SessionEvent(sessionId: session.id,
                                     timestamp: Date(timeIntervalSince1970: Double(index * 100 + 1)),
                                     kind: .searchSubmit(query: "quadripartite", resultCount: 31),
                                     sortOrder: 0)
            event.session = session
            context.insert(event)
        }
        try context.save()

        let removed = ResearchSessionAdmin.deleteAll(context: context)
        #expect(removed.sessions == 3)
        #expect(removed.events == 3)
        #expect(try context.fetchCount(FetchDescriptor<SessionEvent>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ResearchSession>()) == 0)
    }
}
