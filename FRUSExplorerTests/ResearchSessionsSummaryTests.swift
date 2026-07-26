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
struct ResearchSessionsSummaryTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ResearchSession.self, SessionEvent.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
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

    /// A summary with counts but no start date still reports the counts — `startedAt` is optional
    /// on the model, so a legacy or partially-written row must not blank the row.
    @Test("A missing start date does not blank the line")
    func missingStartDate() {
        let summary = ResearchSessionsSummary(sessionCount: 2, eventCount: 5, lastSessionStart: nil)
        #expect(summary.text() == "2 sessions · 5 events")
    }

    // MARK: - Counting

    /// The summary counts what is actually stored.
    @Test("Fetch counts sessions and events")
    @MainActor
    func fetchCounts() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let older = ResearchSession(startedAt: Date(timeIntervalSince1970: 1_000))
        let newer = ResearchSession(startedAt: Date(timeIntervalSince1970: 9_000))
        context.insert(older)
        context.insert(newer)
        for order in 0..<3 {
            let event = SessionEvent(sessionId: newer.id,
                                     timestamp: Date(timeIntervalSince1970: 9_100),
                                     kind: .documentOpen(volumeId: "v", documentId: "d", title: "T"),
                                     sortOrder: order)
            event.session = newer
            context.insert(event)
        }
        try context.save()

        let summary = ResearchSessionsSummary.fetch(from: context)
        #expect(summary.sessionCount == 2)
        #expect(summary.eventCount == 3)
        #expect(summary.lastSessionStart == newer.startedAt, "newest session should win")
    }

    // MARK: - Deleting

    /// The whole point of the delete: nothing recorded survives it.
    @Test("Delete removes every session and event")
    @MainActor
    func deleteAllRemovesEverything() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

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
        #expect(ResearchSessionsSummary.fetch(from: context).sessionCount == 3)

        let removed = ResearchSessionAdmin.deleteAll(context: context)
        #expect(removed.sessions == 3)
        #expect(removed.events == 3)

        // Events are deleted explicitly because the relationship's rule is `.nullify` — deleting
        // only the sessions would leave orphaned events alive with a dangling sessionId, invisible
        // to the log and unreachable from the UI. This is the assertion that catches a well-meant
        // "just delete the sessions, the cascade handles it".
        let summary = ResearchSessionsSummary.fetch(from: context)
        #expect(summary.isEmpty)
        #expect(summary.eventCount == 0)
        #expect((try context.fetchCount(FetchDescriptor<SessionEvent>())) == 0)
    }

    /// Deleting an empty log is a no-op, not a crash.
    @Test("Delete on an empty log does nothing")
    @MainActor
    func deleteEmptyIsSafe() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let removed = ResearchSessionAdmin.deleteAll(context: context)
        #expect(removed.sessions == 0)
        #expect(removed.events == 0)
    }
}
