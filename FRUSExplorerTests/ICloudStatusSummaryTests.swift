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

// MARK: - ICloudStatusSummaryTests

/// The one iCloud status the Settings root and the macOS status bar show.
///
/// ## The defect this pins
/// On a device not signed in to iCloud (observed 2026-09-22, build 48, iPad Pro 13-inch on
/// iOS 27.0), the iOS Settings root's iCloud Sync section showed THREE rows, each titled
/// "Status", that contradicted one another — **Sync Error**, **Private Zone Missing** and
/// **Account Issue** — because the view rendered each of `AppState`'s iCloud facts on its own.
/// All three were true at once, and each is a real state of `AppState` on that device:
///
/// - `checkCloudKitHealth()` wrote the account description into `cloudKitSyncState` as `.failed`,
///   so the event channel said "Sync Error" with the account's own words (it no longer does, but
///   an event can still fail for the same underlying reason, so the fixtures keep the combination);
/// - the zone check listed a private database that cannot be listed without an account, and the
///   failed listing read as "zone missing";
/// - and the account status itself said `.noAccount`, which was the only cause.
///
/// So the fixtures below set every fact AT ONCE. A fixture that set only the account status would
/// pass under any precedence at all, and would not have caught the three-row screen.
///
/// The same screen had a second, separate defect — rows padded with blank space — whose cause was
/// the `Label` style, not the state; the last test pins that.
///
/// Version history:
///   1.0 — one status row for a signed-out device
///   1.1 — the zone-listing rule (a failed listing is unknown, not missing) and the three
///          `checkCloudKitHealth()` wirings a unit test cannot drive, pinned by source
@Suite("iCloud status summary")
@MainActor
struct ICloudStatusSummaryTests {

    /// The redacted text the health check used to write into the event channel for a signed-out
    /// device — taken from the real function, so the fixture is the state the device was actually in.
    private var signedOutMessage: String { AppState.accountStatusDescription(.noAccount) }

    // MARK: - The reported screen

    /// The whole defect in one assertion: every fact the signed-out iPad had, resolved to one
    /// status, and that status is the account — the cause, not either symptom.
    @Test("A signed-out device resolves to the account, not to three rows")
    func signedOutDeviceIsOneAccountStatus() {
        let summary = ICloudStatusSummary.resolve(
            cloudKitEnabled: true,
            initError: nil,
            syncState: .failed(signedOutMessage),
            accountStatus: .noAccount,
            zoneVerified: false
        )
        #expect(summary == .accountUnavailable(.noAccount))
    }

    /// Every non-available account status is the cause of whatever the zone check and the event
    /// stream report — restricted and undetermined accounts cannot list a private zone either.
    @Test("Every unavailable account outranks a missing zone and a failed event",
          arguments: [CKAccountStatus.noAccount, .restricted, .couldNotDetermine,
                      .temporarilyUnavailable])
    func unavailableAccountOutranksSymptoms(status: CKAccountStatus) {
        let summary = ICloudStatusSummary.resolve(
            cloudKitEnabled: true,
            initError: nil,
            syncState: .failed(AppState.accountStatusDescription(status)),
            accountStatus: status,
            zoneVerified: false
        )
        #expect(summary == .accountUnavailable(status))
    }

    // MARK: - The rest of the precedence

    /// A container that never came up with CloudKit makes every other fact meaningless, and its
    /// diagnostic must survive the resolution — it is the only place the init error is shown.
    @Test("Local-only outranks everything and keeps its diagnostic")
    func localOnlyOutranksEverything() {
        let summary = ICloudStatusSummary.resolve(
            cloudKitEnabled: false,
            initError: "CKErrorDomain serverRejectedRequest",
            syncState: .failed("x"),
            accountStatus: .noAccount,
            zoneVerified: false
        )
        #expect(summary == .localOnly(diagnostic: "CKErrorDomain serverRejectedRequest"))
    }

    /// With the account fine, a missing zone is the cause and a failed event its symptom.
    @Test("With the account available, a missing zone outranks a failed event")
    func zoneOutranksFailure() {
        let summary = ICloudStatusSummary.resolve(
            cloudKitEnabled: true, initError: nil,
            syncState: .failed("Zone not found"),
            accountStatus: .available, zoneVerified: false
        )
        #expect(summary == .zoneMissing)
    }

    /// A missing zone is the silent failure the event stream does not report — which is why the
    /// zone check exists — so a succeeded event must not paper over it.
    @Test("A missing zone outranks a succeeded or in-flight event")
    func zoneOutranksHealthyEvents() {
        for state: CloudKitSyncState in [.succeeded(.now), .syncing, .unknown] {
            let summary = ICloudStatusSummary.resolve(
                cloudKitEnabled: true, initError: nil, syncState: state,
                accountStatus: .available, zoneVerified: false
            )
            #expect(summary == .zoneMissing,
                    Comment(rawValue: "a missing zone was hidden behind \(state)"))
        }
    }

    /// Facts not yet checked are not problems: `nil` account status and `nil` zone verification
    /// must let the event stream through, and must not mask a failure it reports.
    @Test("Unchecked account and zone let the event stream through")
    func uncheckedFactsAreNotProblems() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let cases: [(CloudKitSyncState, ICloudStatusSummary)] = [
            (.failed("Quota exceeded"), .failed(message: "Quota exceeded")),
            (.syncing, .syncing),
            (.succeeded(date), .succeeded(date)),
            (.unknown, .idle),
        ]
        for (state, expected) in cases {
            for account: CKAccountStatus? in [nil, .available] {
                for zone: Bool? in [nil, true] {
                    let summary = ICloudStatusSummary.resolve(
                        cloudKitEnabled: true, initError: nil, syncState: state,
                        accountStatus: account, zoneVerified: zone
                    )
                    #expect(summary == expected, Comment(rawValue:
                        "\(state) with account \(String(describing: account)) and zone \(String(describing: zone)) resolved to \(summary)"))
                }
            }
        }
    }

    /// An account check that has not returned yet must not hide a zone the check DID find missing.
    @Test("An unchecked account does not hide a missing zone")
    func uncheckedAccountDoesNotHideZone() {
        let summary = ICloudStatusSummary.resolve(
            cloudKitEnabled: true, initError: nil, syncState: .unknown,
            accountStatus: nil, zoneVerified: false
        )
        #expect(summary == .zoneMissing)
    }

    // MARK: - Wiring

    /// The views read `AppState.iCloudStatusSummary`, so the property must hand the resolver the
    /// REAL four facts. Driven through a live `AppState` in the reported state, so dropping or
    /// swapping one of its arguments fails here rather than on a signed-out device.
    @Test("AppState's summary resolves its own four facts")
    func appStateSummaryReadsItsOwnFacts() {
        let appState = AppState()
        appState.cloudKitSyncEnabled = true
        appState.cloudKitSyncState = .failed(signedOutMessage)
        appState.cloudKitAccountStatus = .noAccount
        appState.cloudKitZoneVerified = false
        #expect(appState.iCloudStatusSummary == .accountUnavailable(.noAccount))

        appState.cloudKitAccountStatus = .available
        #expect(appState.iCloudStatusSummary == .zoneMissing)

        appState.cloudKitZoneVerified = true
        #expect(appState.iCloudStatusSummary == .failed(message: signedOutMessage))

        appState.cloudKitSyncEnabled = false
        appState.cloudKitInitError = "diag"
        #expect(appState.iCloudStatusSummary == .localOnly(diagnostic: "diag"))
    }

    /// The zone check is not run for an account that cannot list a private database, so it cannot
    /// record a "missing" zone that was never looked for. `nil` — the account check threw — still
    /// runs it, as before: an unknown account is not evidence either way.
    @Test("The zone check runs only when the account can answer it")
    func zoneCheckNeedsAnAccount() {
        #expect(AppState.zoneCheckApplies(afterAccountStatus: .available))
        #expect(AppState.zoneCheckApplies(afterAccountStatus: nil))
        for status: CKAccountStatus in [.noAccount, .restricted, .couldNotDetermine,
                                        .temporarilyUnavailable] {
            #expect(!AppState.zoneCheckApplies(afterAccountStatus: status),
                    Comment(rawValue: "the zone check ran for account status \(status.rawValue)"))
        }
    }

    /// A missing zone is a listing that SUCCEEDED without it. A listing that failed — offline at
    /// launch, a rate limit — establishes nothing, and used to be recorded as missing: a red row,
    /// and now that the workspace banner announces a missing zone, a red banner too.
    @Test("A failed zone listing is unknown; only a successful one can find the zone missing")
    func failedListingIsNotAMissingZone() {
        #expect(AppState.zoneVerification(listedZoneNames: nil) == nil,
                "a failed listing was recorded as a verdict")
        #expect(AppState.zoneVerification(listedZoneNames: []) == false)
        #expect(AppState.zoneVerification(listedZoneNames: ["some.other.zone"]) == false)
        #expect(AppState.zoneVerification(
            listedZoneNames: ["some.other.zone", "com.apple.coredata.cloudkit.zone"]) == true)
    }

    /// `checkCloudKitHealth()` and the CloudKit event observer need a live `CKContainer`, so the
    /// three rules they apply are pinned by the lines that apply them — each the exact call, so a
    /// comment explaining the rule cannot satisfy it:
    ///
    /// - the account check no longer writes into the sync-EVENT state (it titled the iOS banner
    ///   "iCloud Sync Failed" and outlived a sign-in);
    /// - the zone listing's failure path goes through `zoneVerification(listedZoneNames:)`;
    /// - a successful `setup` event re-runs the health check, so a zone that setup was still
    ///   creating at launch is not left recorded as missing.
    @Test("The health check's CloudKit-bound wiring applies the tested rules")
    func healthCheckWiring() throws {
        let appState = try appSource("FRUSExplorer/App/AppState.swift")
        #expect(!appState.contains("cloudKitSyncState = .failed(Self.accountStatusDescription"),
                "the account check writes into the sync-event state again")
        #expect(appState.contains("cloudKitZoneVerified = Self.zoneVerification(listedZoneNames: nil)"),
                "the failed-listing path no longer goes through zoneVerification(listedZoneNames:)")
        #expect(!appState.contains("cloudKitZoneVerified = false"),
                "a hard-coded missing-zone verdict is back")
        let app = try appSource("FRUSExplorer/App/FRUSExplorerApp.swift")
        #expect(app.contains(#"if phase == "setup" { appState.checkCloudKitHealth() }"#),
                "a successful setup event no longer re-runs the health check")
    }

    // MARK: - The views read the summary, not the facts

    private func appSource(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        #expect(text.count > 1_000, Comment(rawValue: "\(path) is implausibly small — did it move?"))
        return text
    }

    /// A SwiftUI body has no seam a unit test can drive, so this reads the two files that render
    /// iCloud status. Each must switch on the summary, and neither may read the three facts it
    /// resolves — reading any one of them directly is how the extra rows got there. The forbidden
    /// strings are member accesses on `appState`, which no comment in either file spells.
    @Test("The Settings row and the macOS status chip switch on the summary alone",
          arguments: ["FRUSExplorer/Settings/SettingsView.swift",
                      "FRUSExplorer/App/SupportingViews.swift"])
    func viewsSwitchOnTheSummary(path: String) throws {
        let source = try appSource(path)
        #expect(source.contains("switch appState.iCloudStatusSummary {"),
                Comment(rawValue: "\(path) no longer switches on the resolved summary"))
        for fact in ["appState.cloudKitSyncState", "appState.cloudKitAccountStatus",
                     "appState.cloudKitZoneVerified"] {
            #expect(!source.contains(fact), Comment(rawValue:
                "\(path) reads \(fact) directly — a second status row can come back that way"))
        }
    }

    /// The blank space under the status row was a `Label` left at its automatic style inside a
    /// `LabeledContent` value: on iOS 27 in this `Form` that sized the row about 180 pt too tall,
    /// signed in or out. An explicit `.titleAndIcon` style is what keeps it one line high, and the
    /// failure has no runtime signature a unit test can read, so this counts the source instead —
    /// every `Label(` in the status row and its cell must carry the style.
    ///
    /// Comment text is stripped before counting, because the cell's doc comment names the style in
    /// prose and would otherwise pay for a `Label` that lacks it.
    @Test("Every Label in the Settings status row sets .titleAndIcon explicitly")
    func settingsStatusLabelsSetTheirStyle() throws {
        let source = try appSource("FRUSExplorer/Settings/SettingsView.swift")
        let start = try #require(source.range(of: "private var iCloudSyncStatusRow: some View {"))
        let end = try #require(source.range(of: "// MARK: - SideloadError",
                                             range: start.upperBound..<source.endIndex))
        let code = source[start.lowerBound..<end.lowerBound]
            .components(separatedBy: "\n")
            .map { line in line.range(of: "//").map { String(line[..<$0.lowerBound]) } ?? line }
            .joined(separator: "\n")
        let labels = code.components(separatedBy: "Label(").count - 1
        let styled = code.components(separatedBy: ".labelStyle(.titleAndIcon)").count - 1
        #expect(labels >= 3, Comment(rawValue:
            "fixture guard: expected the cell's Label plus Synced and iCloud Sync Enabled, found \(labels)"))
        #expect(labels == styled, Comment(rawValue:
            "\(labels) Label(s) in the iCloud status row but \(styled) .labelStyle(.titleAndIcon) — a Label left at the automatic style brings back ~180 pt of blank row"))
    }
}
