// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if os(macOS) && DIRECT_DISTRIBUTION

import Sparkle
import SwiftUI

// MARK: - SparkleUpdater

/// Wraps the Sparkle `SPUUpdater` for use in the Direct Distribution macOS build.
///
/// Sparkle is only linked in the `DirectDistribution` build configuration via `project.yml`.
/// This file is compiled only when the `DIRECT_DISTRIBUTION` Swift flag is active, so it
/// is excluded from App Store and iOS builds entirely.
///
/// ## Usage
/// - Instantiate once and store in `AppState` or the SwiftUI environment.
/// - Call `checkForUpdates()` from the Settings view or a menu item.
/// - The `canCheckForUpdates` published property reflects whether a check is currently
///   in progress; bind it to disable the "Check for Updates…" button while busy.
///
/// ## Feed URL
/// The `SUFeedURL` Info.plist key is set to `https://frusexplorer.example.com/appcast.xml`
/// in `project.yml` under the `DirectDistribution` configuration. Update the URL to a
/// real Sparkle appcast before shipping the first DirectDistribution release.
///
/// Version history:
///   1.0 — Session 128: initial stub for `CodingStandardsAuditTests` compliance;
///          full implementation deferred until first DirectDistribution release.
@MainActor
final class SparkleUpdater: NSObject, ObservableObject {

    // MARK: - Published State

    /// `true` while Sparkle is able to check for updates (no check already in progress).
    @Published var canCheckForUpdates = false

    // MARK: - Private

    private let updaterController: SPUStandardUpdaterController

    // MARK: - Initializer

    override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    // MARK: - Public API

    /// Checks for updates and presents the Sparkle update UI if a new version is available.
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}

#endif // os(macOS) && DIRECT_DISTRIBUTION
