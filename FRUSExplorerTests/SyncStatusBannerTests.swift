// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - SyncStatusBannerTests

/// The iOS workspace iCloud indicator, and the debounce behind it (#665).
///
/// ## What each half is for
/// `AppState.cloudKitSyncState` has driven the macOS status bar since #188; on iOS it reached
/// only `SettingsView`, three taps from the workspace. A state whose entire purpose is "your
/// data is silently not moving" was living where nobody would look.
///
/// The banner is deliberately **quiet**. It speaks for local-only and for failure — the two
/// states a researcher can act on — and says nothing while sync is healthy or merely in flight.
/// A spinner on every import would be its own churn, which is the thing #665 was filed about.
///
/// Version history:
///   1.0 — Session 2026-08-07: #665
@Suite("iCloud workspace indicator")
struct SyncStatusBannerTests {

    // MARK: - What it speaks for

    /// The state that matters most: work done now does not leave this device.
    @Test("Local-only always shows, whatever the sync state says")
    func localOnlyAlwaysShows() {
        for state: CloudKitSyncState in [.unknown, .syncing, .succeeded(.now), .failed("x")] {
            #expect(SyncStatusBanner.isWorthShowing(state: state, cloudKitEnabled: false),
                    Comment(rawValue: "local-only was silent for \(state)"))
        }
    }

    @Test("A failure shows")
    func failureShows() {
        #expect(SyncStatusBanner.isWorthShowing(state: .failed("Quota exceeded"),
                                                cloudKitEnabled: true))
    }

    // MARK: - What it stays quiet about

    /// **The restraint is the feature.** A banner that appears on every import would interrupt
    /// the workspace on exactly the schedule #665 complained about.
    @Test("A healthy or in-flight sync says nothing")
    func healthySyncIsSilent() {
        for state: CloudKitSyncState in [.unknown, .syncing, .succeeded(.now)] {
            #expect(!SyncStatusBanner.isWorthShowing(state: state, cloudKitEnabled: true),
                    Comment(rawValue: "the banner interrupted for \(state)"))
        }
    }

    // MARK: - Wiring

    private func appSource(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        #expect(text.count > 1_000, Comment(rawValue: "\(path) is implausibly small — did it move?"))
        return text
    }

    /// The banner shares the indexing inset, and indexing must win: it is transient and
    /// finishes, while local-only waits and will still be true when the space frees up.
    @Test("Indexing keeps the banner slot when both want it")
    func indexingWinsTheSlot() throws {
        let text = try appSource("FRUSExplorer/App/MainTabView.swift")
        let banner = try #require(text.range(of: "SyncStatusBanner("))
        let head = String(text[text.startIndex..<banner.lowerBound].suffix(600))
        #expect(head.contains("appState.indexingBatch == nil"),
                "the sync banner can displace an in-flight indexing banner")
        #expect(head.contains("completedIndexingMetadata == nil"),
                "the sync banner can displace the indexing summary card")
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
