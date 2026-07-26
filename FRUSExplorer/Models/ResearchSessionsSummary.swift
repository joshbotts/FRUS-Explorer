// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - ResearchSessionsSummary

/// How much research activity has been recorded, in one line.
///
/// The Research Sessions pane's log row answers "is there anything in here, and when did it last
/// record?" before the reader opens it — the same job `SyncLogSummary` does for the sync log, and
/// the same shape: a pure value type, so the wording is testable without standing up a store.
///
/// It matters more here than it does for a diagnostic log. What is recorded includes the text of
/// the searches the user ran, so "how much of this exists" is a question they are entitled to an
/// answer to without having to go looking.
///
/// Version history:
///   1.0 — initial implementation
struct ResearchSessionsSummary: Equatable, Sendable {

    /// How many sessions have been recorded.
    var sessionCount: Int = 0
    /// How many events across all of them.
    var eventCount: Int = 0
    /// When the most recent session began, or `nil` if nothing has been recorded.
    var lastSessionStart: Date?

    /// Nothing recorded yet.
    static let empty = ResearchSessionsSummary()

    /// Whether there is anything to show or delete.
    var isEmpty: Bool { sessionCount == 0 }

    /// "12 sessions · 340 events · last today 21:04", or the empty-log equivalent.
    ///
    /// - Parameters:
    ///   - now: The reference time, injected so the "today" boundary is testable.
    ///   - calendar: Injected for the same reason.
    func text(now: Date = .now, calendar: Calendar = .current) -> String {
        guard !isEmpty else {
            return String(localized: "settings.sessions.log.empty",
                          defaultValue: "Nothing recorded yet")
        }
        var parts = [Self.sessions(sessionCount), Self.events(eventCount)]
        if let last = lastSessionStart {
            if calendar.isDate(last, inSameDayAs: now) {
                parts.append(String(localized: "settings.sessions.log.lastToday",
                                    defaultValue: "last today \(last.formatted(date: .omitted, time: .shortened))"))
            } else {
                // A stale log is worth distinguishing: "last 21:04" on a log whose newest session
                // is from three weeks ago would read as current.
                parts.append(String(localized: "settings.sessions.log.lastOlder",
                                    defaultValue: "last \(last.formatted(date: .abbreviated, time: .omitted))"))
            }
        }
        return parts.joined(separator: " · ")
    }

    /// "1 session" / "N sessions". No String Catalog ships, so the two forms are spelled out.
    static func sessions(_ count: Int) -> String {
        count == 1
            ? String(localized: "settings.sessions.count.one", defaultValue: "1 session")
            : String(format: String(localized: "settings.sessions.count.many %lld",
                                    defaultValue: "%lld sessions"), Int64(count))
    }

    /// "1 event" / "N events".
    static func events(_ count: Int) -> String {
        count == 1
            ? String(localized: "settings.sessions.events.one", defaultValue: "1 event")
            : String(format: String(localized: "settings.sessions.events.many %lld",
                                    defaultValue: "%lld events"), Int64(count))
    }

    // MARK: - Building

    /// Counts what is stored, in two fetches.
    ///
    /// - Parameter context: The SwiftData context to read.
    @MainActor
    static func fetch(from context: ModelContext) -> ResearchSessionsSummary {
        let sessions = (try? context.fetch(
            FetchDescriptor<ResearchSession>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]))) ?? []
        let events = (try? context.fetchCount(FetchDescriptor<SessionEvent>())) ?? 0
        return ResearchSessionsSummary(
            sessionCount: sessions.count,
            eventCount: events,
            lastSessionStart: sessions.first?.startedAt)
    }
}

// MARK: - ResearchSessionAdmin

/// Deleting recorded research sessions.
///
/// Separated from the view for the reason `UserTagAdmin` is: a destructive operation with a
/// cascade should be one named thing that can be read, reviewed, and tested, not a closure inside
/// a confirmation dialog.
///
/// Version history:
///   1.0 — initial implementation
enum ResearchSessionAdmin {

    /// Deletes every recorded session and event.
    ///
    /// Events are deleted explicitly rather than left to the relationship's delete rule:
    /// `ResearchSession.events` is declared `.nullify`, so deleting a session would otherwise
    /// orphan its events — they would survive with a dangling `sessionId`, invisible to the
    /// session list and impossible to remove from the UI. That is the opposite of what a user
    /// pressing "Delete Recorded Sessions" is asking for.
    ///
    /// - Parameter context: The SwiftData context to mutate.
    /// - Returns: How many sessions and events were removed.
    @MainActor
    @discardableResult
    static func deleteAll(context: ModelContext) -> (sessions: Int, events: Int) {
        let events = (try? context.fetch(FetchDescriptor<SessionEvent>())) ?? []
        for event in events { context.delete(event) }

        let sessions = (try? context.fetch(FetchDescriptor<ResearchSession>())) ?? []
        for session in sessions { context.delete(session) }

        // Flush, so the deletion reaches other contexts (and CloudKit) promptly rather than at
        // whenever the autosave timer next fires.
        try? context.save()
        return (sessions.count, events.count)
    }
}
