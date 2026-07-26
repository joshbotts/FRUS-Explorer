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

    /// One summary input, with the Wave R-6 "could not describe it" flag defaulted off.
    private func event(_ h: Double, _ hasError: Bool,
                       undiagnosed: Bool = false) -> SyncLogSummary.Event {
        .init(timestamp: hoursAgo(h), hasError: hasError, isUndiagnosed: undiagnosed)
    }

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
            entries: [event(1, false), event(2, false)], now: now, calendar: calendar)
        #expect(summary.lastEvent == hoursAgo(1))
        #expect(!summary.hasErrors)
        #expect(summary.text(now: now, calendar: calendar).hasSuffix("no errors today"))
    }

    @Test("Errors today are counted and agree in number")
    func errorsToday() {
        let one = SyncLogSummary.make(entries: [event(1, true)], now: now, calendar: calendar)
        #expect(one.hasErrors)
        #expect(one.text(now: now, calendar: calendar).hasSuffix("1 error today"))

        let many = SyncLogSummary.make(
            entries: [event(1, true), event(2, true), event(3, false)],
            now: now, calendar: calendar)
        #expect(many.text(now: now, calendar: calendar).hasSuffix("2 errors today"))
    }

    /// Yesterday's failures are not today's problem — the row says "today" and has to mean it.
    @Test("Errors from earlier days are not counted as today's")
    func errorsFromOtherDays() {
        let summary = SyncLogSummary.make(
            entries: [event(50, true), event(80, true), event(1, false)],
            now: now, calendar: calendar)
        #expect(summary.errorsToday == 0)
        #expect(!summary.hasErrors)
        #expect(summary.text(now: now, calendar: calendar).hasSuffix("no errors today"))
    }

    // MARK: Undescribed failures (Wave R-6)

    /// The row used to collapse every failure to "an error", so #488 — a `partialFailure` the app
    /// could not describe — looked exactly like a fully diagnosed one.
    @Test("An error the app could not describe is called out")
    func undescribedErrorIsDistinguished() {
        let described = SyncLogSummary.make(entries: [event(1, true)], now: now, calendar: calendar)
        let undescribed = SyncLogSummary.make(entries: [event(1, true, undiagnosed: true)],
                                              now: now, calendar: calendar)

        #expect(described.undiagnosedToday == 0)
        #expect(undescribed.undiagnosedToday == 1)
        #expect(described.text(now: now, calendar: calendar)
                != undescribed.text(now: now, calendar: calendar))
        #expect(undescribed.text(now: now, calendar: calendar)
                .hasSuffix("1 error today, no detail recorded"))
    }

    @Test("A mix reports both counts")
    func mixedErrors() {
        let summary = SyncLogSummary.make(
            entries: [event(1, true, undiagnosed: true), event(2, true), event(3, true)],
            now: now, calendar: calendar)
        #expect(summary.errorsToday == 3)
        #expect(summary.undiagnosedToday == 1)
        #expect(summary.text(now: now, calendar: calendar)
                .hasSuffix("3 errors today, 1 with no detail"))
    }

    /// The two counts appear in one sentence, so the second must never exceed the first.
    @Test("An undescribed non-error is impossible by construction")
    func undescribedImpliesError() {
        let summary = SyncLogSummary.make(
            entries: [.init(timestamp: hoursAgo(1), hasError: false, isUndiagnosed: true)],
            now: now, calendar: calendar)
        #expect(summary.errorsToday == 0)
        #expect(summary.undiagnosedToday == 0)
    }

    @Test("Undescribed errors from earlier days are not today's either")
    func undescribedFromOtherDays() {
        let summary = SyncLogSummary.make(
            entries: [event(50, true, undiagnosed: true), event(1, false)],
            now: now, calendar: calendar)
        #expect(summary.undiagnosedToday == 0)
        #expect(summary.text(now: now, calendar: calendar).hasSuffix("no errors today"))
    }

    /// A log that stopped three weeks ago would otherwise read as current, because a bare "12:04"
    /// gives no hint of the date.
    @Test("A stale log shows a date, not just a time")
    func staleLogShowsDate() {
        let stale = SyncLogSummary.make(entries: [event(24 * 21, false)],
                                        now: now, calendar: calendar)
        let recent = SyncLogSummary.make(entries: [event(1, false)],
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
            entries: [event(5, false), event(1, false), event(3, false)],
            now: now, calendar: calendar)
        #expect(summary.lastEvent == hoursAgo(1))
    }
}
