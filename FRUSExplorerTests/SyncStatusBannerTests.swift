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
///   1.2 — #1531: a failure's detail is the kept-changes sentence, never the error, on screen and to
///          VoiceOver; the error stays on the Settings row Details opens
///   1.3 — #1531 review: the body draws `content.detail` and reads `summary` only through
///          `content(for:)`, so the line on screen is the one the wording tests check
///   1.4 — #1531, lane SYNC: a stopped sync's own words, and a remembered failure that a
///          successful import cannot quiet
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

    /// #1531: after the build-48 update the banner's whole explanation was
    /// "CKErrorDomain partialFailure (2)". The detail now says what the reader needs — the changes
    /// are safe here, and a relaunch tries again — and the error itself stays on the Settings row.
    @Test("A failure shows, saying the changes are kept rather than naming the error")
    func failureShows() throws {
        let error = "CKErrorDomain partialFailure (2)"
        let content = try #require(SyncStatusBanner.content(for: .failed(message: error)))
        #expect(content.title == "iCloud Sync Failed")
        #expect(content.detail
                == "Your changes are kept on this device. Relaunch the app to try again.")
        #expect(!content.detail.contains(error), "the banner shows the raw error again")
        #expect(content.accessibilityLabel
                == "iCloud Sync Failed. Your changes are kept on this device. Relaunch the app to try again.",
                "VoiceOver must hear the title and the same detail line")
        #expect(!content.accessibilityLabel.contains(error), "VoiceOver reads the raw error again")
    }

    /// #1531, lane SYNC: an upload failure remembered from an earlier launch has words of its own.
    /// The reader has relaunched already, so it may not borrow the failure's "Relaunch the app to
    /// try again", and it promises no retry at all.
    @Test("A stopped sync shows, saying the changes are kept here and promising no retry")
    func stoppedShows() throws {
        let export = UnrecoveredExport(firstFailedAt: .now, lastFailedAt: .now, firstLaunchID: UUID(),
                                       message: "CKErrorDomain partialFailure", schemaIdentifiers: nil)
        let content = try #require(SyncStatusBanner.content(for: .stopped(export)))
        #expect(content.title == "iCloud Sync Stopped")
        #expect(content.detail == "Sync stopped on this device; your changes are kept here.")
        #expect(content.title != failedTitle, "a remembered failure borrowed the one-event title")
        #expect(!content.detail.localizedCaseInsensitiveContains("relaunch"),
                "the stopped state tells a reader who has relaunched to relaunch")
        #expect(!content.detail.localizedCaseInsensitiveContains("try again"))
        #expect(!content.detail.contains("CKErrorDomain"), "the banner shows the raw error")
        #expect(content.accessibilityLabel
                == "iCloud Sync Stopped. Sync stopped on this device; your changes are kept here.")
    }

    /// "Never quiet": the reported device, end to end. An upload failed in an earlier launch, and
    /// this launch's import then SUCCEEDED — the state that read as healthy in #1531.
    @Test("A remembered failure keeps the banner up through a successful import")
    func rememberedFailureIsNeverQuiet() throws {
        let appState = AppState()
        appState.cloudKitSyncEnabled = true
        appState.cloudKitAccountStatus = .available
        appState.cloudKitZoneVerified = true
        appState.cloudKitSyncState = .succeeded(.now)
        #expect(SyncStatusBanner.content(for: appState.iCloudStatusSummary) == nil,
                "fixture guard: a healthy device must show nothing before the failure is remembered")
        appState.unrecoveredExport = UnrecoveredExport(
            firstFailedAt: .now, lastFailedAt: .now, firstLaunchID: UUID(), message: nil,
            schemaIdentifiers: nil)
        let content = try #require(SyncStatusBanner.content(for: appState.iCloudStatusSummary),
                                   "a stopped sync was quiet after a successful import")
        #expect(content.title == "iCloud Sync Stopped")
    }

    /// The detail no longer depends on the message, so two different errors read alike — and the
    /// message is not lost: `ICloudStatusSummary` still carries it to the Settings row.
    @Test("Every failure reads the same detail, and the summary still carries the error")
    func failureDetailIgnoresTheMessage() throws {
        let quota = try #require(SyncStatusBanner.content(for: .failed(message: "Quota exceeded")))
        let partial = try #require(SyncStatusBanner.content(for: .failed(message: "CKErrorDomain partialFailure (2)")))
        #expect(quota == partial)

        let appState = AppState()
        appState.cloudKitSyncEnabled = true
        appState.cloudKitSyncState = .failed("Quota exceeded")
        appState.cloudKitAccountStatus = .available
        appState.cloudKitZoneVerified = true
        #expect(appState.iCloudStatusSummary == .failed(message: "Quota exceeded"),
                "the Settings row reads the error from the summary; it must still be there")
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
            .stopped(UnrecoveredExport(firstFailedAt: .now, lastFailedAt: .now, firstLaunchID: UUID(),
                                       message: nil, schemaIdentifiers: nil)),
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

    /// `failureShows` drives `Content.accessibilityLabel`; this pins that the banner hands VoiceOver
    /// that property and composes no label of its own, so the two cannot say different things.
    @Test("The banner's VoiceOver label is Content.accessibilityLabel")
    func voiceOverReadsTheContentLabel() throws {
        let text = try appSource("FRUSExplorer/App/SyncStatusBanner.swift")
        let body = try #require(text.range(of: "var body: some View {"),
                                "SyncStatusBanner.body not found — the scan would read nothing")
        let view = String(text[body.lowerBound...])
        #expect(view.components(separatedBy: ".accessibilityLabel(").count - 1 == 1,
                "the banner sets more than one VoiceOver label, or none")
        #expect(view.contains(".accessibilityLabel(Text(verbatim: content.accessibilityLabel))"),
                "the banner composes its VoiceOver label instead of reading Content.accessibilityLabel")
    }

    /// `failureShows` drives `content(for:)`; this pins that the line on screen is that function's
    /// `detail` and that the body reads `summary` nowhere else. A body that read the failure's
    /// message itself — `if case .failed(let message) = summary` — would put "CKErrorDomain
    /// partialFailure (2)" back on screen while every wording test and the VoiceOver label stayed
    /// green (#1531, review). Read with comments and strings masked, so only code counts.
    @Test("The banner draws only what content(for:) produced")
    func bodyDrawsOnlyTheContent() throws {
        let text = try appSource("FRUSExplorer/App/SyncStatusBanner.swift")
        let body = try #require(
            CodingStandardsAuditTests.maskedDeclarationBody("var body: some View {", in: text),
            "SyncStatusBanner.body is not declared exactly once — the scan would read nothing")
        #expect(body.ranges(of: "Text(content.detail)").count == 1,
                "the banner does not draw content.detail as its detail line, or draws it twice")
        #expect(body.ranges(of: "summary").count == 1,
                "the banner reads `summary` beyond content(for:), so it can draw a text no wording test sees")
        #expect(body.ranges(of: "Self.content(for: summary)").count == 1,
                "the banner does not build what it draws with Self.content(for: summary)")
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
