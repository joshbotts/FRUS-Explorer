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
struct SyncLogSummary: Equatable, Sendable {

    /// When the most recent event was recorded, or `nil` if the log is empty.
    var lastEvent: Date?
    /// How many of today's events carried an error code.
    var errorsToday: Int = 0

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

        let errors: String
        switch errorsToday {
        case 0:
            errors = String(localized: "settings.dataRecovery.sync.noErrors",
                            defaultValue: "no errors today")
        case 1:
            errors = String(localized: "settings.dataRecovery.sync.oneError",
                            defaultValue: "1 error today")
        default:
            errors = String(format: String(localized: "settings.dataRecovery.sync.manyErrors %lld",
                                           defaultValue: "%lld errors today"), Int64(errorsToday))
        }
        return when + " · " + errors
    }

    /// Builds the summary from raw log entries.
    ///
    /// - Parameters:
    ///   - entries: `(timestamp, hasError)` per recorded event, in any order.
    ///   - now: The reference time for "today".
    ///   - calendar: The calendar defining the day boundary.
    static func make(entries: [(timestamp: Date, hasError: Bool)],
                     now: Date = .now,
                     calendar: Calendar = .current) -> SyncLogSummary {
        SyncLogSummary(
            lastEvent: entries.map(\.timestamp).max(),
            errorsToday: entries.filter {
                $0.hasError && calendar.isDate($0.timestamp, inSameDayAs: now)
            }.count
        )
    }
}
