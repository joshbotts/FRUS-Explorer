// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - SyncLogSummary

/// The Sync Log row's one-line state (S-4b).
///
/// ## Why the row says this much
/// The question a reader has about a diagnostic log is "is anything wrong?", and the old row —
/// a bare "Sync Diagnostics" push — could only be answered by opening it and reading a monospaced
/// dump. This answers it on the row.
///
/// Pure so the wording can be tested without standing up the log actor.
///
/// Version history:
///   1.0 — S-4b: initial implementation
///   1.1 — Wave R-6: counts how many of today's errors the app could not describe. The row
///          collapsed every failed event to "an error", so #488 — a `partialFailure` with no
///          sub-errors and no named record type — read exactly like a fully diagnosed one.
struct SyncLogSummary: Equatable, Sendable {

    /// One recorded event, reduced to what the row needs.
    ///
    /// A struct rather than a tuple so ``undiagnosedToday`` could be added without rewriting every
    /// call site, and so the next such field can be added the same way.
    struct Event: Equatable, Sendable {
        /// When the event was recorded.
        var timestamp: Date
        /// Whether it carried an error code.
        var hasError: Bool
        /// Whether it was an error the app could not describe beyond a domain and a code
        /// (see `SyncDiagnosticsEntry.isUndiagnosedFailure`). Always `false` when `hasError` is.
        var isUndiagnosed: Bool = false

        /// Creates one summary input.
        init(timestamp: Date, hasError: Bool, isUndiagnosed: Bool = false) {
            self.timestamp = timestamp
            self.hasError = hasError
            self.isUndiagnosed = hasError && isUndiagnosed
        }
    }

    /// When the most recent event was recorded, or `nil` if the log is empty.
    var lastEvent: Date?
    /// How many of today's events carried an error code.
    var errorsToday: Int = 0
    /// How many of ``errorsToday`` the app could not describe beyond a domain and a code. Never
    /// exceeds ``errorsToday`` — ``Event`` enforces that at construction.
    var undiagnosedToday: Int = 0

    /// Whether the row should read as a problem.
    var hasErrors: Bool { errorsToday > 0 }

    /// "Last event 12:04 · no errors today", or the empty-log equivalent.
    ///
    /// - Parameters:
    ///   - now: The reference time, injected so the "today" boundary is testable.
    ///   - calendar: Injected for the same reason.
    func text(now: Date = .now, calendar: Calendar = .current) -> String {
        guard let lastEvent else {
            return String(localized: "settings.dataRecovery.sync.empty",
                          defaultValue: "No sync events recorded yet")
        }

        let when: String
        if calendar.isDate(lastEvent, inSameDayAs: now) {
            when = String(localized: "settings.dataRecovery.sync.lastToday",
                          defaultValue: "Last event \(lastEvent.formatted(date: .omitted, time: .shortened))")
        } else {
            // A stale log is worth distinguishing: "Last event 12:04" on a log whose newest entry
            // is from three weeks ago would read as current.
            when = String(localized: "settings.dataRecovery.sync.lastOlder",
                          defaultValue: "Last event \(lastEvent.formatted(date: .abbreviated, time: .shortened))")
        }

        return when + " · " + errorClause()
    }

    /// The error half of the row.
    ///
    /// Splitting the undescribed count out is the whole of R-6's contribution here: "2 errors
    /// today" was the same sentence whether the app knew what went wrong or not, and #488 spent
    /// its diagnosis time on that ambiguity.
    private func errorClause() -> String {
        switch (errorsToday, undiagnosedToday) {
        case (0, _):
            return String(localized: "settings.dataRecovery.sync.noErrors",
                          defaultValue: "no errors today")
        case (1, 0):
            return String(localized: "settings.dataRecovery.sync.oneError",
                          defaultValue: "1 error today")
        case (1, _):
            return String(localized: "settings.dataRecovery.sync.oneErrorNoDetail",
                          defaultValue: "1 error today, no detail recorded")
        case (_, 0):
            return String(format: String(localized: "settings.dataRecovery.sync.manyErrors %lld",
                                         defaultValue: "%lld errors today"), Int64(errorsToday))
        default:
            return String(
                format: String(localized: "settings.dataRecovery.sync.manyErrorsSomeNoDetail %lld %lld",
                               defaultValue: "%1$lld errors today, %2$lld with no detail"),
                Int64(errorsToday), Int64(undiagnosedToday))
        }
    }

    /// Builds the summary from raw log entries.
    ///
    /// - Parameters:
    ///   - entries: One ``Event`` per recorded log row, in any order.
    ///   - now: The reference time for "today".
    ///   - calendar: The calendar defining the day boundary.
    static func make(entries: [Event],
                     now: Date = .now,
                     calendar: Calendar = .current) -> SyncLogSummary {
        let today = entries.filter { calendar.isDate($0.timestamp, inSameDayAs: now) }
        return SyncLogSummary(
            lastEvent: entries.map(\.timestamp).max(),
            errorsToday: today.filter(\.hasError).count,
            undiagnosedToday: today.filter(\.isUndiagnosed).count
        )
    }
}
