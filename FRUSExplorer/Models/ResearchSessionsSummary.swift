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
///   1.1 — Wave R-2a: counted from the derived trail (``ResearchTrailSessions``) rather than from
///          the retired `ResearchSession`/`SessionEvent` tables. The wording is unchanged, so the
///          localisation keys are reused as-is; what an "event" is has simply become "a recorded
///          activity" — a document opened, a search run, a collection exported
struct ResearchSessionsSummary: Equatable, Sendable {

    /// How many sessions have been recorded — derived, not stored.
    var sessionCount: Int = 0
    /// How many recorded activities across all of them.
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

    /// Counts what the trail holds, grouped into sessions.
    ///
    /// ## Why this loads rows rather than counting them
    /// A session is not a stored row any more, so `sessionCount` cannot come from a `fetchCount` —
    /// the grouping has to see the timestamps. The activity total *is* three `fetchCount`s and is
    /// exact whatever the page size; only the session count and the last start are computed from
    /// the loaded page. On a trail longer than ``activityScanLimit`` the session count therefore
    /// describes the recent window rather than the whole history. That is the right trade for a
    /// Settings row whose job is "is there anything in here, and when did it last record?", and it
    /// is why the two numbers are derived differently rather than both being approximations.
    ///
    /// - Parameter context: The SwiftData context to read.
    @MainActor
    static func fetch(from context: ModelContext) -> ResearchSessionsSummary {
        let activities = ResearchTrailSessions.activities(in: context, limit: activityScanLimit)
        let sessions = ResearchTrailSessions.group(activities)
        return ResearchSessionsSummary(
            sessionCount: sessions.count,
            eventCount: ResearchTrailSessions.totalActivityCount(in: context),
            lastSessionStart: sessions.first?.startedAt)
    }

    /// How many activities the summary loads to count sessions with.
    ///
    /// Matches ``SessionLogSnapshot/defaultPageLimit``, so the row's session count and the log's
    /// first page describe the same window.
    static let activityScanLimit = SessionLogSnapshot.defaultPageLimit
}

// MARK: - ResearchSessionAdmin

/// Emptying the **legacy** `ResearchSession`/`SessionEvent` tables.
///
/// Separated from the view for the reason `UserTagAdmin` is: a destructive operation with a
/// cascade should be one named thing that can be read, reviewed, and tested, not a closure inside
/// a confirmation dialog.
///
/// ## Who calls this now
/// Since Wave R-2a, ``ResearchTrailMigration`` — as its last step, once the two event kinds worth
/// keeping have been re-homed. The Research Sessions pane's "Delete Recorded Sessions…" no longer
/// calls it directly: sessions are derived from the typed trail, so a delete that reached only
/// these two tables would report "12 sessions will be deleted" and remove nothing the user can
/// see. That button calls ``HistoryTrailAdmin/deleteAll(context:)``, which reaches the whole trail
/// **and** these tables.
///
/// R-2b deletes this type along with the models it operates on.
///
/// Version history:
///   1.0 — initial implementation
///   1.1 — Wave R-2a: no longer the delete behind the Settings button; kept as the migration's
///          legacy-table sweep and as the one place that documents the `.nullify` hazard
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
