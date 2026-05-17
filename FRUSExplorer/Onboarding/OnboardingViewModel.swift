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

/// View model for the three-step onboarding flow.
///
/// Drives the welcome → download scope → project setup wizard.
///
/// ## Steps
/// 1. **welcome** — static app intro, "Get Started" CTA.
/// 2. **downloadScope** — three-choice scope picker (corpus / subseries / volume).
///    The user selects a scope and taps "Next"; `selectedScope` carries the choice.
/// 3. **projectSetup** — project creation with defaults pre-filled from the corpus.
///
/// ## Default Project Pre-fill
/// On init, `projectName` is pre-filled with "Onboarding", `projectQuestion` with
/// "Explore app", and the date range with the corpus min/max years from `ManifestStore`.
/// All fields are editable.
///
/// ## Subseries Lookup
/// The subseries picker in step 2 shows all known subseries sorted by start year
/// descending (most recent first), matching the browser's sort order.
///
/// ## Volume Filtering
/// All volume lists exclude entries with `sizeBytes < 20_000`.
///
/// Version history:
///   1.0 — Session 10: initial implementation
///   1.1 — Session 32: removed `fetchIntroText()` — intro text is now static (bundled only)
///   2.0 — Session 49: redesigned to three-step flow; added DownloadScope; default project
///          pre-fill; subseries/tag pickers moved to DownloadManagerSettingsView
@Observable
@MainActor
final class OnboardingViewModel {

    // MARK: - Step

    enum Step {
        case welcome        // Step 1: app intro / welcome screen
        case downloadScope  // Step 2: choose download scope
        case projectSetup   // Step 3: create project
    }

    // MARK: - Navigation State

    var step: Step = .welcome

    // MARK: - Download Scope State (Step 2)

    /// The user's chosen download scope. Defaults to `.corpus`.
    var selectedScope: DownloadScope = .corpus

    /// The subseries selected when `selectedScope == .subseries(…)`.
    var selectedSubseries: String = ""

    /// Search text for the single-volume picker when `selectedScope == .volume(…)`.
    var singleVolumeSearchText: String = ""

    // MARK: - Project Setup State (Step 3)

    var projectName: String = "Onboarding"
    var projectQuestion: String = "Explore app"
    var projectDateStart: Date?
    var projectDateEnd: Date?
    var projectSubjectTagIds: Set<String> = []

    // MARK: - Intro Text

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

        // Pre-fill project dates from corpus range.
        let range = manifestStore.corpusDateRange
        self.projectDateStart = range.lowerBound
        self.projectDateEnd   = range.upperBound
    }

    // MARK: - Derived: All Volumes

    /// All known volumes with sizeBytes ≥ 20 000.
    var allVolumes: [VolumeManifestEntry] {
        let source = manifestStore.diffResult?.known ?? manifestStore.bundledEntries
        return source.filter { $0.sizeBytes >= 20_000 }
    }

    // MARK: - Derived: Subseries Groups

    /// All distinct subseries identifiers, sorted by start year descending (newest first).
    var allSubseries: [String] {
        let unique = Set(allVolumes.map(\.subseries))
        return unique.sorted { lhs, rhs in
            Self.startYear(from: lhs) > Self.startYear(from: rhs)
        }
    }

    // MARK: - Derived: Single Volume Search

    /// Volumes matching `singleVolumeSearchText` (case-insensitive) for the single-volume picker.
    var singleVolumeResults: [VolumeManifestEntry] {
        let query = singleVolumeSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let lower = query.lowercased()
        return allVolumes.filter {
            $0.title.lowercased().contains(lower) || $0.volumeId.lowercased().contains(lower)
        }
        .prefix(20)
        .map { $0 }
    }

    // MARK: - Validation

    var canProceedFromDownloadScope: Bool {
        switch selectedScope {
        case .corpus:
            return true
        case .subseries:
            return !selectedSubseries.isEmpty
        case .volume(let id):
            return !id.isEmpty
        }
    }

    var canProceedFromProjectSetup: Bool {
        !projectName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Resolved scope

    /// The resolved `DownloadScope` incorporating the currently entered subseries / volume.
    var resolvedScope: DownloadScope {
        switch selectedScope {
        case .corpus:
            return .corpus
        case .subseries:
            return .subseries(selectedSubseries)
        case .volume:
            // Extract volumeId from the currently chosen single volume, or fall back to
            // the raw search text if the user typed the ID directly.
            let id = singleVolumeSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
            return .volume(id)
        }
    }

    // MARK: - Actions

    /// Enqueues volumes corresponding to `resolvedScope` via `DownloadManager`.
    func enqueueScope(downloadManager: DownloadManager) async {
        let volumes = volumesForScope(resolvedScope)
        for entry in volumes {
            let url = "https://raw.githubusercontent.com/HistoryAtState/frus/master/volumes/\(entry.filename)"
            await downloadManager.enqueueDownload(volumeId: entry.volumeId, downloadUrl: url)
        }
        #if DEBUG
        print("[Onboarding] Enqueued \(volumes.count) volumes for scope \(resolvedScope).")
        #endif
    }

    /// Returns the manifest entries covered by a given scope.
    func volumesForScope(_ scope: DownloadScope) -> [VolumeManifestEntry] {
        switch scope {
        case .corpus:
            return allVolumes
        case .subseries(let id):
            return allVolumes.filter { $0.subseries == id }
        case .volume(let id):
            if let entry = allVolumes.first(where: { $0.volumeId == id }) {
                return [entry]
            }
            return []
        }
    }

    /// Creates and inserts a `Project` into the provided `ModelContext`.
    @discardableResult
    func createProject(context: ModelContext) -> Project {
        let project = Project(
            name: projectName.trimmingCharacters(in: .whitespaces),
            researchQuestion: projectQuestion.trimmingCharacters(in: .whitespaces).isEmpty
                ? nil
                : projectQuestion.trimmingCharacters(in: .whitespaces),
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
        return Int(subseries.prefix(4)) ?? 0
    }
}
