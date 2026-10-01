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

// MARK: - Fix iCloud Sync while an upload is unrecovered (#1531)

/// Fix iCloud Sync deletes this device's store and downloads iCloud's copy, so while an upload has
/// failed with none succeeding since it discards real work — in #1531, everything a Mac made in the
/// week its uploads were refused. Each place the action is offered says so then, and says nothing
/// new otherwise. These drive the three functions the view renders. Idiom-agnostic.
@Suite("Fix iCloud Sync warning (#1531)")
@MainActor
struct FixICloudSyncWarningTests {

    private let run = UnrecoveredExport(
        firstFailedAt: Date(timeIntervalSince1970: 1_790_000_000),
        lastFailedAt: Date(timeIntervalSince1970: 1_790_003_600), firstLaunchID: UUID(),
        message: "CKErrorDomain partialFailure", schemaIdentifiers: nil)

    /// The owner's confirmation text (lane WB, 2026-09-30), which ships unchanged in both states.
    private let ownerMessage = "This clears the local copy of your synced data and downloads it again. Nothing in iCloud is deleted, but unsynced local data could be lost. The app returns to onboarding while it restores. The clearing happens the next time the app starts, so quit and reopen it."

    @Test("With nothing unrecovered the confirmation is the owner's message alone")
    func healthyConfirmationIsUnchanged() {
        #expect(DataRecoveryView.fixSyncMessage(unrecovered: nil) == ownerMessage)
    }

    @Test("While an upload is unrecovered the confirmation warns first, then says the same")
    func confirmationWarnsFirst() {
        let message = DataRecoveryView.fixSyncMessage(unrecovered: run)
        #expect(message.hasSuffix("\n\n" + ownerMessage), "the owner's message was changed or dropped")
        #expect(message.hasPrefix("Warning:"))
        #expect(message.contains(SyncStoppedCopy.since(run)), "the warning does not say since when")
        #expect(message.contains("Fix iCloud Sync would discard them"))
    }

    /// The row and the footer are seen BEFORE the dialog; the footer's "deletes nothing" is false
    /// of Fix iCloud Sync in this state.
    @Test("The row and the ladder's footer warn too, and only while an upload is unrecovered")
    func rowAndFooter() {
        #expect(DataRecoveryView.fixSyncRowDetail(unrecovered: nil) == "Re-download from iCloud at next launch")
        #expect(DataRecoveryView.fixSyncRowDetail(unrecovered: run) == "Would discard changes not yet in iCloud")
        let healthy = DataRecoveryView.recoveryFooter(unrecovered: nil)
        #expect(healthy.contains("deletes nothing"))
        let warned = DataRecoveryView.recoveryFooter(unrecovered: run)
        #expect(!warned.contains("deletes nothing"),
                "the footer still calls Fix iCloud Sync the rung that deletes nothing")
        #expect(warned.contains("Fix iCloud Sync would discard them"))
    }

    /// The view renders those three functions and reads the run from `AppState` — not from the
    /// status summary, which shows a failure begun THIS launch as `.failed` and would have hidden
    /// the warning then. Read with comments and strings masked.
    @Test("Data & Recovery renders the three from AppState.unrecoveredExport")
    func viewReadsTheRun() throws {
        let code = String(decoding: CodingStandardsAuditTests.maskedCode(
            try DebugStoreSeparationTests.appSource("FRUSExplorer/Settings/DataRecoveryView.swift")),
            as: UTF8.self)
        for call in ["Text(Self.fixSyncMessage(unrecovered: appState.unrecoveredExport))",
                     "detail: Self.fixSyncRowDetail(unrecovered: appState.unrecoveredExport)",
                     "Text(Self.recoveryFooter(unrecovered: appState.unrecoveredExport))"] {
            #expect(code.contains(call), Comment(rawValue: "DataRecoveryView no longer renders \(call)"))
        }
    }
}
