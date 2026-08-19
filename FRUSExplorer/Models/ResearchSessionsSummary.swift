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
///   1.2 — Wave R-2a review fixes: ``isEmpty`` asks whether there is anything **to delete**, not
///          whether any session could be derived (an all-undated store had rows and a disabled
///          delete button); and ``isSessionCountExact`` says when the session count came off a
///          truncated scan, so neither the row nor the confirmation dialog can understate an
///          irreversible action by an order of magnitude
struct ResearchSessionsSummary: Equatable, Sendable {

    /// How many sessions have been recorded — derived, not stored. Approximate when
    /// ``isSessionCountExact`` is `false`.
    var sessionCount: Int = 0
    /// How many recorded activities exist — every row in the three trail tables, which is exactly
    /// what "Delete Recorded Sessions…" would remove. Exact at any size: three `fetchCount`s.
    var eventCount: Int = 0
    /// When the most recent session began, or `nil` if nothing has been recorded.
    var lastSessionStart: Date?

    /// Whether ``sessionCount`` describes the whole trail or only the newest
    /// ``activityScanLimit`` activities of it.
    ///
    /// Sessions cannot be counted with a `fetchCount` — the grouping has to see the timestamps —
    /// so a trail longer than the scan limit yields a floor, not a total. Saying so is not a
    /// nicety: the delete this pane offers is unbounded and irreversible, and a measured run had
    /// the dialog announce "1000 sessions" while destroying 1,200.
    var isSessionCountExact: Bool = true

    /// Nothing recorded yet.
    static let empty = ResearchSessionsSummary()

    /// Whether there is anything to show or delete.
    ///
    /// Keyed to the **row count**, not the session count. A row with no timestamp cannot be placed
    /// in a session, so a store of nothing but undated rows derives zero sessions — and if that
    /// disabled the delete control, the user's recorded query text would sit in their iCloud
    /// database with no way to remove it, which is the privacy gap this wave exists to close.
    var isEmpty: Bool { eventCount == 0 }

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
        var parts = [Self.sessions(sessionCount, exact: isSessionCountExact),
                     Self.events(eventCount)]
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

    /// "1 session" / "N sessions" — or "at least N sessions" when the count came off a truncated
    /// scan. No String Catalog ships, so every form is spelled out under its own key.
    ///
    /// - Parameters:
    ///   - count: How many sessions were counted.
    ///   - exact: Whether that is the whole trail. `false` adds the floor wording; the two
    ///     approximate forms are new keys rather than rewrites of the exact ones, because reusing
    ///     a key with different text is a silent collision without a catalogue.
    static func sessions(_ count: Int, exact: Bool = true) -> String {
        guard exact else {
            return count == 1
                ? String(localized: "settings.sessions.count.atLeast.one",
                         defaultValue: "at least 1 session")
                : String(format: String(localized: "settings.sessions.count.atLeast.many %lld",
                                        defaultValue: "at least %lld sessions"), Int64(count))
        }
        return count == 1
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
    /// describes the recent window rather than the whole history — and ``isSessionCountExact``
    /// says so, so the number is never quoted as a total in the one place it must not be: the
    /// confirmation for an unbounded, irreversible, CloudKit-propagating delete.
    ///
    /// - Parameter context: The SwiftData context to read.
    @MainActor
    static func fetch(from context: ModelContext) -> ResearchSessionsSummary {
        let activities = ResearchTrailSessions.activities(in: context, limit: activityScanLimit)
        let sessions = ResearchTrailSessions.group(activities)
        return ResearchSessionsSummary(
            sessionCount: sessions.count,
            eventCount: ResearchTrailSessions.totalActivityCount(in: context),
            lastSessionStart: sessions.first?.startedAt,
            // The scan filled its window, so there may be older activities — and therefore older
            // sessions — that this count cannot see.
            isSessionCountExact: activities.count < activityScanLimit)
    }

    /// How many activities the summary loads to count sessions with.
    ///
    /// Matches ``SessionLogSnapshot/defaultPageLimit``, so the row's session count and the log's
    /// first page describe the same window.
    static let activityScanLimit = SessionLogSnapshot.defaultPageLimit
}

// MARK: - (ResearchSessionAdmin retired in R-2b with the session models it operated on)
