// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import CloudKit
@testable import FRUSExplorer

// MARK: - SyncStatusBannerTests

/// The iOS workspace iCloud indicator, and the debounce behind it (#665).
///
/// ## What each half is for
/// `AppState.cloudKitSyncState` has driven the macOS status bar since #188; on iOS it reached
/// only `SettingsView`, three taps from the workspace. A state whose entire purpose is "your
/// data is silently not moving" was living where nobody would look.
///
/// The banner is deliberately **quiet**. It speaks for local-only, an account problem, a missing
/// sync zone and a failure — the states a researcher can act on — and says nothing while sync is
/// healthy or merely in flight. A spinner on every import would be its own churn, which is the
/// thing #665 was filed about.
///
/// ## Why it reads the summary
/// It used to read the raw event state, and the account check wrote an unavailable account into
/// that state as a failure — so a researcher who had never signed in to iCloud was shown
/// **iCloud Sync Failed**. The banner now reads `ICloudStatusSummary`, the one status the Settings
/// row and the macOS status bar show, and the wording tests below drive `content(for:)` — the
/// function the view renders — rather than a copy of it.
///
/// Version history:
///   1.0 — Session 2026-08-07: #665
///   1.1 — the banner reads `ICloudStatusSummary`: an account problem is titled as one, and a missing
///          sync zone is announced
@Suite("iCloud workspace indicator")
@MainActor
struct SyncStatusBannerTests {

    /// The failure title, taken from the function under test so no assertion restates the string.
    private var failedTitle: String? {
        SyncStatusBanner.content(for: .failed(message: "x"))?.title
    }

    // MARK: - What it speaks for

    /// The state that matters most: work done now does not leave this device.
    @Test("Local-only shows, with or without a diagnostic")
    func localOnlyShows() throws {
        for diagnostic: String? in [nil, "CKErrorDomain serverRejectedRequest"] {
            let content = try #require(SyncStatusBanner.content(for: .localOnly(diagnostic: diagnostic)))
            #expect(content.title == "Local Only")
            #expect(content.systemImage == "icloud.slash")
        }
    }

    /// **The defect this version fixes.** An account that is not available is an account problem,
    /// and the banner must say so in the account's own words — never "iCloud Sync Failed", which is
    /// what a signed-out researcher was told while the banner read the raw event state.
    @Test("An unavailable account is titled as one, not as a failed sync",
          arguments: [CKAccountStatus.noAccount, .restricted, .couldNotDetermine,
                      .temporarilyUnavailable])
    func accountProblemIsNotASyncFailure(status: CKAccountStatus) throws {
        let content = try #require(SyncStatusBanner.content(for: .accountUnavailable(status)))
        #expect(content.title == "iCloud Account Issue")
        #expect(content.title != failedTitle,
                "an account problem was announced as a failed sync")
        #expect(content.detail == AppState.accountStatusDescription(status),
                "the detail must be the account's own explanation, the words the Settings row shows")
    }

    /// A missing zone means nothing uploads or downloads — the silent failure the zone check
    /// exists for. It is announced now that a failed LISTING records "unknown", not "missing".
    @Test("A missing sync zone shows")
    func zoneMissingShows() throws {
        let content = try #require(SyncStatusBanner.content(for: .zoneMissing))
        #expect(content.title == "iCloud Sync Zone Missing")
        #expect(content.systemImage == "exclamationmark.icloud.fill")
    }

    @Test("A failure shows, with the observer's message as its detail")
    func failureShows() throws {
        let content = try #require(SyncStatusBanner.content(for: .failed(message: "Quota exceeded")))
        #expect(content.title == "iCloud Sync Failed")
        #expect(content.detail == "Quota exceeded")
    }

    // MARK: - What it stays quiet about

    /// **The restraint is the feature.** A banner that appears on every import would interrupt
    /// the workspace on exactly the schedule #665 complained about.
    @Test("A healthy, in-flight or idle sync says nothing")
    func healthySyncIsSilent() {
        for summary: ICloudStatusSummary in [.syncing, .succeeded(.now), .idle] {
            #expect(SyncStatusBanner.content(for: summary) == nil,
                    Comment(rawValue: "the banner spoke for \(summary)"))
            #expect(!SyncStatusBanner.isWorthShowing(summary),
                    Comment(rawValue: "the banner interrupted for \(summary)"))
        }
    }

    /// `isWorthShowing` is what reserves the inset, and `content(for:)` is what draws in it. If the
    /// two disagreed the host would reserve space for a banner that renders nothing, or the reverse.
    @Test("isWorthShowing agrees with what the banner would draw")
    func visibilityAgreesWithContent() {
        let every: [ICloudStatusSummary] = [
            .localOnly(diagnostic: nil), .accountUnavailable(.noAccount), .zoneMissing,
            .failed(message: "x"), .syncing, .succeeded(.now), .idle,
        ]
        for summary in every {
            #expect(SyncStatusBanner.isWorthShowing(summary)
                        == (SyncStatusBanner.content(for: summary) != nil),
                    Comment(rawValue: "visibility and content disagree for \(summary)"))
        }
    }

    /// The reported device, end to end: a live `AppState` that is signed out AND has a failed sync
    /// event (the container's own setup fails for the same reason) must reach the banner as the
    /// account problem. Read through the same property `MainTabView` passes the banner.
    @Test("A signed-out device with a failed event is shown the account, not the failure")
    func signedOutAppStateReachesTheBannerAsTheAccount() throws {
        let appState = AppState()
        appState.cloudKitSyncEnabled = true
        appState.cloudKitSyncState = .failed("CKErrorDomain notAuthenticated")
        appState.cloudKitAccountStatus = .noAccount
        appState.cloudKitZoneVerified = nil
        let content = try #require(SyncStatusBanner.content(for: appState.iCloudStatusSummary))
        #expect(content.title == "iCloud Account Issue")
        #expect(content.detail == AppState.accountStatusDescription(.noAccount))
    }

    // MARK: - Wiring

    private func appSource(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        #expect(text.count > 1_000, Comment(rawValue: "\(path) is implausibly small — did it move?"))
        return text
    }

    /// The banner shares the indexing inset, and transient work must win: it finishes, while
    /// local-only waits and will still be true when the space frees up.
    ///
    /// **This used to scan `MainTabView` for the old chain's literal conditions.** B-6 moved the
    /// precedence into `IndexingInsetState.resolve` — because a decision inside a view body had no
    /// seam and was hiding a hole — so the assertion now drives that rule instead. It is a
    /// stronger test than the scan it replaces: the scan would have passed on any code that merely
    /// mentioned the conditions, and it covers the queued-download case the scan could not see.
    @Test("Indexing keeps the banner slot when both want it")
    func indexingWinsTheSlot() {
        func state(batch: Bool = false, metadata: Bool = false,
                   queueEmpty: Bool = true) -> IndexingInsetState {
            IndexingInsetState.resolve(keyboardIsVisible: false, hasBatch: batch,
                                       hasCompletedMetadata: metadata,
                                       downloadQueueIsEmpty: queueEmpty, syncIsWorthShowing: true)
        }
        #expect(state(batch: true) == .batch,
                "the sync banner must not displace an in-flight indexing banner")
        #expect(state(metadata: true) == .summary,
                "nor the indexing summary card")
        #expect(state(queueEmpty: false) == .downloadsQueued,
                "nor a queued download — B-6 extended the same rule to it")
        #expect(state() == .sync, "and it takes the slot when nothing else wants it")
    }

    /// The settings pull must be debounced, not run per event.
    ///
    /// Undebounced, `syncNowIfEnabled()` is a `FetchDescriptor<SyncedPreferences>` fetch, a
    /// possible `context.save()`, and a UserDefaults write that fans out to every
    /// `@AppStorage`-bound view — once per success event of a large import, on the main actor.
    /// Its two neighbours in the same closure were already debounced for the same reason.
    @Test("The settings pull runs on a debounce, not on every sync event")
    func settingsPullIsDebounced() throws {
        let text = try appSource("FRUSExplorer/App/FRUSExplorerApp.swift")
        let call = try #require(text.range(of: "settingsSync?.syncNowIfEnabled()"))
        let head = String(text[text.startIndex..<call.lowerBound].suffix(400))
        #expect(head.contains("settingsPullDebounce"),
                """
                The CloudKit success path calls syncNowIfEnabled() without a debounce, so a \
                fetch, a save and a UserDefaults fan-out run on the main actor for every event \
                of an import.
                """)
        #expect(head.contains("Task.sleep"),
                "the debounce does not wait, so it collapses nothing")
    }
}
