// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ResetService

/// Shared "local data" reset logic used by the Settings reset panes on both
/// platforms.
///
/// Extracted from the macOS `SettingsResetPane` in Session 153 so the iOS
/// `ResetView` can offer the same least-destructive "Reset local data" tier
/// (between "Reset iCloud Sync" and "Reset all data"), and so the
/// volume-files-and-search-index step isn't duplicated across the macOS
/// local/full and iOS full reset paths.
///
/// ## What this clears
/// - Every downloaded volume `.xml` file (`DownloadManager.volumesDirectory`).
/// - The full-text search index (`frus.db`), via
///   `IndexingPipeline.removeAllVolumesFromIndex()`.
/// - `AppState.hasCompletedOnboarding`, returning the app to onboarding so a
///   fresh download/index pass can begin.
///
/// ## What this deliberately leaves untouched
/// - The local SwiftData store (research notes, projects, tags, collections,
///   summaries) — that is the *Sync* tier's concern, and the *Full* tier's.
/// - App preferences in `UserDefaults` (e.g. `SettingsKeys.citationStyle`,
///   `SettingsKeys.concurrentDownloadLimit`) — these are device settings, not
///   downloaded content or user data.
/// - The NARA Catalog API key in the Keychain — it is synchronizable via
///   iCloud Keychain (`NARAAPIKeyStore`), so deleting it here would remove it
///   from the user's other devices too.
/// - The CloudKit zone — nothing here issues a CloudKit delete. Notes,
///   collections, tags, and projects remain in iCloud and will be restored on
///   next launch.
///
/// Version history:
///   1.0 — Session 153: extracted from `SettingsResetPane.performReset(includeCloudKit:)`
///   1.1 — Word Cloud fixes: flushes `WordFrequencyService`'s in-memory cache after
///          clearing the index, so an open session can't keep serving stale clouds
///   1.1 — Corpus Analytics cache fix: flushes `CorpusAnalyticsService`'s caches after
///          clearing the index, so an open session can't keep serving stale counts
@MainActor
struct ResetService {

    private init() {}

    /// Deletes downloaded volume XML files and clears the search index, then
    /// returns the app to onboarding.
    static func resetLocalData(appState: AppState) async {
        // Delete every .xml file in volumesDirectory directly via the filesystem.
        // Iterating manifest entries misses any file not in the manifest, which would
        // leave hasDownloadedVolumes() returning true and block OnboardingView.
        if let dm = appState.downloadManager {
            let dir = dm.volumesDirectory
            if let files = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
            ) {
                for file in files where file.pathExtension.lowercased() == "xml" {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }

        // Remove the search index — one bulk DELETE per table, not one call per manifest entry.
        if let pipeline = appState.indexingPipeline {
            do {
                try await pipeline.removeAllVolumesFromIndex()
                appState.indexedVolumeIds = []
                appState.indexGeneration += 1
                // Flush cached word-cloud results computed against the now-empty
                // index; unlike the disk cache, the in-memory cache key carries no
                // index fingerprint, so stale results would otherwise survive here.
                await appState.wordFrequencyService?.invalidateCache()
                // Flush Corpus Analytics results computed against the now-empty
                // index; the cache keys are bare query terms with no index
                // fingerprint, so stale counts would otherwise survive here.
                await appState.analyticsService?.invalidateCache()
            } catch {
                #if DEBUG
                print("[ResetService] removeAllVolumesFromIndex failed: \(error)")
                #endif
            }
        }

        appState.hasCompletedOnboarding = false
    }
}
