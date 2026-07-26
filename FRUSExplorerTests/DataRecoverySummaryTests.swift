// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - SyncLogSummaryTests

/// Tests the Sync Log row's one-line state (S-4b).
///
/// The row exists so "is anything wrong with sync?" can be answered without opening a monospaced
/// dump. Its two traps are both about honesty: an empty log must not read as a healthy one, and a
/// log whose newest entry is weeks old must not read as current.
struct SyncLogSummaryTests {

    private let calendar = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func hoursAgo(_ h: Double) -> Date { now.addingTimeInterval(-h * 3600) }

    @Test("An empty log says so rather than claiming health")
    func emptyLog() {
        let summary = SyncLogSummary.make(entries: [], now: now, calendar: calendar)
        #expect(summary.lastEvent == nil)
        #expect(!summary.hasErrors)
        let text = summary.text(now: now, calendar: calendar)
        #expect(text == "No sync events recorded yet")
        #expect(!text.contains("no errors"), "an empty log must not read as a clean bill of health")
    }

    @Test("A clean log today reports the last event and no errors")
    func cleanToday() {
        let summary = SyncLogSummary.make(
            entries: [(hoursAgo(1), false), (hoursAgo(2), false)], now: now, calendar: calendar)
        #expect(summary.lastEvent == hoursAgo(1))
        #expect(!summary.hasErrors)
        #expect(summary.text(now: now, calendar: calendar).hasSuffix("no errors today"))
    }

    @Test("Errors today are counted and agree in number")
    func errorsToday() {
        let one = SyncLogSummary.make(entries: [(hoursAgo(1), true)], now: now, calendar: calendar)
        #expect(one.hasErrors)
        #expect(one.text(now: now, calendar: calendar).hasSuffix("1 error today"))

        let many = SyncLogSummary.make(
            entries: [(hoursAgo(1), true), (hoursAgo(2), true), (hoursAgo(3), false)],
            now: now, calendar: calendar)
        #expect(many.text(now: now, calendar: calendar).hasSuffix("2 errors today"))
    }

    /// Yesterday's failures are not today's problem — the row says "today" and has to mean it.
    @Test("Errors from earlier days are not counted as today's")
    func errorsFromOtherDays() {
        let summary = SyncLogSummary.make(
            entries: [(hoursAgo(50), true), (hoursAgo(80), true), (hoursAgo(1), false)],
            now: now, calendar: calendar)
        #expect(summary.errorsToday == 0)
        #expect(!summary.hasErrors)
        #expect(summary.text(now: now, calendar: calendar).hasSuffix("no errors today"))
    }

    /// A log that stopped three weeks ago would otherwise read as current, because a bare "12:04"
    /// gives no hint of the date.
    @Test("A stale log shows a date, not just a time")
    func staleLogShowsDate() {
        let stale = SyncLogSummary.make(entries: [(hoursAgo(24 * 21), false)],
                                        now: now, calendar: calendar)
        let recent = SyncLogSummary.make(entries: [(hoursAgo(1), false)],
                                         now: now, calendar: calendar)
        #expect(stale.text(now: now, calendar: calendar)
                != recent.text(now: now, calendar: calendar))
        // The stale line carries a date component the fresh one does not.
        #expect(stale.text(now: now, calendar: calendar).count
                > recent.text(now: now, calendar: calendar).count)
    }

    @Test("The last event is the newest, regardless of the order entries arrive in")
    func lastEventIsNewest() {
        let summary = SyncLogSummary.make(
            entries: [(hoursAgo(5), false), (hoursAgo(1), false), (hoursAgo(3), false)],
            now: now, calendar: calendar)
        #expect(summary.lastEvent == hoursAgo(1))
    }
}
