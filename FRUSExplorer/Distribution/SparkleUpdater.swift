// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#if os(macOS) && DIRECT_DISTRIBUTION
import Sparkle

// MARK: - SparkleUpdater

/// Wraps `SPUStandardUpdaterController` for the DirectDistribution macOS build.
///
/// Exposes a single entry point (`checkForUpdates()`) called from the
/// "Check for Updates…" menu item in `FRUSExplorerApp`. The controller is
/// started lazily when the app finishes launching; Sparkle will perform its
/// own background check according to the `SUScheduledCheckInterval` in the
/// app's Info.plist.
///
/// This type is compiled only when `DIRECT_DISTRIBUTION` is defined, which
/// is set exclusively in the DirectDistribution build configuration. App Store
/// and debug builds never link or instantiate this class.
///
/// Version history:
///   1.0 — Session 29: initial Sparkle integration
@MainActor
final class SparkleUpdater: NSObject {

    // MARK: - Singleton

    static let shared = SparkleUpdater()

    // MARK: - State

    private let controller: SPUStandardUpdaterController

    // MARK: - Init

    private override init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    // MARK: - Public

    /// Presents the Sparkle update UI. Suitable for wiring to a menu item action.
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    /// Whether the updater currently supports checking for updates.
    /// Useful for enabling/disabling the menu item.
    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }
}
#endif
