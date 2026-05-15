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

import Foundation
import Observation
import SwiftData

/// View model for the multi-step onboarding flow.
///
/// Drives the intro → volume picker → download confirm → project setup → prompt setup
/// wizard. All mutation is @MainActor; `hasDownloadedVolumes(in:)` is nonisolated static
/// so ContentView can call it synchronously without actor hopping.
///
/// ## Intro Text
/// The intro screen displays a static bundled description of FRUS. An earlier version
/// fetched live text from history.state.gov; this was removed and the intro now uses
/// only bundled copy to avoid a network dependency on first launch.
///
/// ## Volume Filtering
/// Volumes with `sizeBytes < 20_000` are excluded from all display lists.
///
/// ## Subseries Sort
/// Groups by subseries string, then sorts by the first 4-character year prefix.
/// "1969-76" → 1969, "1977-80" → 1977, "1861" → 1861.
///
/// Version history:
///   1.0 — Session 10: initial implementation
///   1.1 — Session 32: removed `fetchIntroText()` — intro text is now static (bundled only)
@Observable
@MainActor
final class OnboardingViewModel {

    // MARK: - Step

    enum Step {
        case intro, volumePicker, downloadConfirm, projectSetup, promptSetup
    }

    // MARK: - Sort Mode

    enum SortMode {
        case bySubseries, byTag
    }

    // MARK: - Navigation State

    var step: Step = .intro

    // MARK: - Volume Picker State

    var sortMode: SortMode = .bySubseries
    var selectedTagSlugs: Set<String> = []
    var tagSearchText: String = ""
    var selectedVolumeIds: Set<String> = []

    // MARK: - Project Setup State

    var projectName: String = ""
    var projectQuestion: String = ""
    var projectDateStart: Date? = nil
    var projectDateEnd: Date? = nil
    var projectSubjectTagIds: Set<String> = []

    // MARK: - Intro

    var introText: String = OnboardingViewModel.bundledIntroText

    // MARK: - Dependencies

    let manifestStore: ManifestStore
    let tagStore: VolumeLevelTagStore
    let volumesDirectory: URL?

    // MARK: - Initialization

    init(manifestStore: ManifestStore, tagStore: VolumeLevelTagStore, volumesDirectory: URL?) {
        self.manifestStore = manifestStore
        self.tagStore = tagStore
        self.volumesDirectory = volumesDirectory
    }

    // MARK: - Derived: All Volumes

    /// All known volumes with sizeBytes >= 20_000.
    private var allVolumes: [VolumeManifestEntry] {
        let source = manifestStore.diffResult?.known ?? manifestStore.bundledEntries
        return source.filter { $0.sizeBytes >= 20_000 }
    }

    // MARK: - Derived: Display Volumes

    /// Volumes to display, filtered by selected tags when in byTag mode.
    var displayVolumes: [VolumeManifestEntry] {
        guard sortMode == .byTag, !selectedTagSlugs.isEmpty else {
            return allVolumes
        }
        let matchingIds = Set(tagStore.volumes(forTagSlugs: Array(selectedTagSlugs)))
        return allVolumes.filter { matchingIds.contains($0.volumeId) }
    }

    // MARK: - Derived: Volumes by Subseries

    /// Volumes grouped by subseries and sorted by start year ascending.
    var volumesBySubseries: [(subseries: String, volumes: [VolumeManifestEntry])] {
        var grouped: [String: [VolumeManifestEntry]] = [:]
        for volume in displayVolumes {
            grouped[volume.subseries, default: []].append(volume)
        }
        return grouped
            .map { key, value in (subseries: key, volumes: value) }
            .sorted { lhs, rhs in
                let lhsYear = Self.startYear(from: lhs.subseries)
                let rhsYear = Self.startYear(from: rhs.subseries)
                return lhsYear < rhsYear
            }
    }

    // MARK: - Derived: Newly Available

    /// Newly available volumes (from live diff) with sizeBytes >= 20_000.
    var newlyAvailableVolumes: [NewlyAvailableVolume] {
        (manifestStore.diffResult?.newlyAvailable ?? [])
            .filter { $0.sizeBytes >= 20_000 }
    }

    // MARK: - Derived: Selected Bytes

    /// Sum of sizeBytes for all selected volumes.
    var selectedBytes: Int {
        let knownBytes = allVolumes
            .filter { selectedVolumeIds.contains($0.volumeId) }
            .reduce(0) { $0 + $1.sizeBytes }
        let newlyBytes = newlyAvailableVolumes
            .filter { selectedVolumeIds.contains($0.filename) }
            .reduce(0) { $0 + $1.sizeBytes }
        return knownBytes + newlyBytes
    }

    // MARK: - Validation

    var canProceedFromVolumePicker: Bool { !selectedVolumeIds.isEmpty }

    var canProceedFromProjectSetup: Bool {
        !projectName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Actions

    /// Adds `slug` to `selectedTagSlugs` and sets `sortMode` to `.byTag`.
    func activateTagFilter(slug: String) {
        selectedTagSlugs.insert(slug)
        sortMode = .byTag
    }

    /// Enqueues all selected volumes for download via `DownloadManager`.
    func enqueueSelectedDownloads(downloadManager: DownloadManager) async {
        // Known volumes
        for volume in allVolumes where selectedVolumeIds.contains(volume.volumeId) {
            let url = "https://raw.githubusercontent.com/HistoryAtState/frus/master/volumes/\(volume.filename)"
            await downloadManager.enqueueDownload(volumeId: volume.volumeId, downloadUrl: url)
        }
        // Newly available volumes
        for volume in newlyAvailableVolumes where selectedVolumeIds.contains(volume.filename) {
            await downloadManager.enqueueDownload(volumeId: volume.filename, downloadUrl: volume.downloadUrl)
        }
        #if DEBUG
        print("[Onboarding] Enqueued \(selectedVolumeIds.count) volumes for download.")
        #endif
    }

    /// Creates and inserts a `Project` into the provided `ModelContext`.
    @discardableResult
    func createProject(context: ModelContext) -> Project {
        let project = Project(
            name: projectName.trimmingCharacters(in: .whitespaces),
            researchQuestion: projectQuestion.trimmingCharacters(in: .whitespaces).isEmpty ? nil : projectQuestion.trimmingCharacters(in: .whitespaces),
            defaultDateRangeStart: projectDateStart,
            defaultDateRangeEnd: projectDateEnd,
            defaultSubjectTagIds: Array(projectSubjectTagIds),
            defaultCountryTagIds: []
        )
        project.lastModified = .now
        context.insert(project)
        #if DEBUG
        print("[Onboarding] Created project '\(project.name)' id=\(project.id)")
        #endif
        return project
    }

    // MARK: - Static Helpers

    /// Returns `true` if any `.xml` file exists in `directory`.
    /// Synchronous FileManager check — nonisolated.
    nonisolated static func hasDownloadedVolumes(in directory: URL?) -> Bool {
        guard let dir = directory else { return false }
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return false }
        return contents.contains { $0.pathExtension.lowercased() == "xml" }
    }

    // MARK: - Bundled Intro Text

    static let bundledIntroText: String = """
        Foreign Relations of the United States (FRUS) is the official documentary record of U.S. foreign policy. Published by the Office of the Historian, U.S. Department of State, the series documents the major foreign policy decisions and diplomatic activity of the U.S. Government.

        The FRUS series began in 1861 and now comprises more than 450 volumes covering U.S. foreign policy from 1776 through the 1980s. Each volume contains declassified State Department cables, presidential directives, memoranda of conversations, and other primary source materials selected to illuminate the historical record.

        FRUS Explorer provides full-text search, document browsing, AI-assisted summarization, and citation tools for the complete digital corpus, which is freely available at history.state.gov and in the HistoryAtState GitHub repository.
        """

    // MARK: - Private Helpers

    /// Parses the start year from a subseries string like "1969-76", "1977-80", or "1861".
    private static func startYear(from subseries: String) -> Int {
        guard subseries.count >= 4 else { return 0 }
        let prefix = subseries.prefix(4)
        return Int(prefix) ?? 0
    }
}
