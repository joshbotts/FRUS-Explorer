// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

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
// MARK: - ResetInventory

/// Which `@Model` types "Erase Everything" deletes, and which it deliberately keeps (#746).
///
/// ## Why this is a list and not a sequence of hand-written `delete` calls
/// `performReset` used to spell out its deletes inline, and the list fell behind the schema
/// **twice**: Wave R-2a found it reaching `ReadingHistoryEntry` alone and extended it for the
/// research trail, and the 2026-08 navigation/state audit then found five more types surviving a
/// double-confirmed erase — `SavedSearch` and `PersonClusterOverride` (never in the list at all),
/// plus `CustomVolumeScope` (#258), `ProjectLeadEntry` (#377) and `WorkingCorpus` (M-1), each
/// added to `frusModelTypes` after the last time anyone looked here. Every one of them is
/// CloudKit-synced, so they survived on the user's other devices too, under a screen that
/// promises the app "returns to onboarding as if newly installed".
///
/// A hand-written list cannot be kept honest by reviewers who are looking at a different file.
/// `ResetInventoryTests` asserts `erased + deliberatelyRetained` covers `frusModelTypes` exactly,
/// so adding a `@Model` without deciding its reset fate fails the suite with the type named.
///
/// Version history:
///   1.0 — Session 2026-08-08: extracted from `performReset` (#746)
@MainActor
enum ResetInventory {

    /// Types "Erase Everything" deletes, **in deletion order**.
    ///
    /// Order is load-bearing and the sequence is not transactional: a dependent must be deleted
    /// BEFORE whatever it references, so an interrupted reset leaves a harmless orphaned child
    /// rather than a dangling reference to a deleted parent. Two cases are documented scars —
    /// `DocumentTagAssignment` before `UserTag`, or the boot-time `OrphanedTagRepair` resurrects
    /// deleted tags as "Recovered Tag" placeholders (#406); and `CollectionEntry` before
    /// `Collection`, whose delete rule is `.nullify`, not cascade. `SessionEvent` precedes
    /// `ResearchSession` for the same `.nullify` reason. The three added in #746 that reference a
    /// parent by raw `UUID` — `ProjectLeadEntry.projectId`, `WorkingCorpus`, `SavedSearch` — go
    /// before `Project` on the same principle, even though no `@Relationship` makes it structural.
    static let erased: [any PersistentModel.Type] = [
        // Dependents first.
        DocumentTagAssignment.self,
        DocumentHighlight.self,
        CollectionEntry.self,
        ResearchNote.self,
        UserTag.self,
        Collection.self,
        GeneratedSummary.self,
        // The research trail (Wave R-2a): every document opened, search run, collection exported.
        ReadingHistoryEntry.self,
        SearchHistoryEntry.self,
        ExportHistoryEntry.self,
        SessionEvent.self,
        ResearchSession.self,
        // Retiring (R-2b removes them from the schema); still deleted while enrolled so a reset
        // does not leave rows a later migration would read back.
        SummarizationPrompt.self,
        // #746 additions — all CloudKit-synced user data that survived every previous reset.
        SavedSearch.self,
        PersonClusterOverride.self,
        CustomVolumeScope.self,
        WorkingCorpus.self,
        ProjectLeadEntry.self,
        // Parent last.
        Project.self,
    ]

    /// Types "Erase Everything" deliberately does NOT delete, each with its reason.
    ///
    /// `SyncedPreferences` mirrors device settings — word-cloud tuning, citation style, default
    /// document mode, the research-logging toggle, and the user's own custom stopword lists — to
    /// iCloud. It is retained because deleting it here would not achieve what it appears to:
    /// `ResetService.resetLocalData` clears volumes, the index and caches but **not** the
    /// `@AppStorage` keys these values mirror, so the local copies would immediately re-publish a
    /// fresh record. Erasing preferences honestly means clearing the local defaults too, which is
    /// a larger change than this reset does today. Recorded here as a decision rather than left
    /// as an omission — which is what it was until #746.
    static let deliberatelyRetained: [any PersistentModel.Type] = [
        SyncedPreferences.self,
    ]

    /// Stable identifiers for the two lists, for tests and diagnostics.
    static var erasedNames: [String] { erased.map { String(describing: $0) } }
    /// Stable identifiers for the retained list.
    static var retainedNames: [String] { deliberatelyRetained.map { String(describing: $0) } }
}

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
