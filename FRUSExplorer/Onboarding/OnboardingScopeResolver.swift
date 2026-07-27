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
import SwiftData

// MARK: - OnboardingScopeChoice

/// The download scope a user picks on onboarding's second step.
///
/// Lifted out of `OnboardingView`'s private `ScopeChoice` in Workstream O session O-0.
/// The name carries the feature because two unrelated private `ScopeChoice` enums already
/// live in `VolumesStorageHubView` and `MacVolumesStorageHub`; a third at file scope would
/// read as the same type.
///
/// Distinct from `DownloadScope` (`DownloadModels.swift`), which carries its selection as
/// an associated value. Onboarding keeps the choice and the selection in separate pieces of
/// `@State`, because the picker must remember a partially-made choice — "subseries, none
/// picked yet" is a state the user sits in while the list is on screen.
enum OnboardingScopeChoice: String, CaseIterable, Equatable, Sendable {
    /// Every volume in the manifest.
    case corpus
    /// One subseries, named by `selectedSubseries`.
    case subseries
    /// One volume, named by `selectedVolumeId`.
    case volume
}

// MARK: - OnboardingScopeResolver

/// The volume lists, validity rule, and enqueue set behind onboarding's scope picker.
///
/// This is the pure half of `OnboardingView`'s step 2, extracted in O-0 so the behaviour
/// O-4 must preserve can be pinned by tests before the view is rewritten around the word
/// cloud. It holds no view state: the caller passes the current choice and selection, and
/// gets back what the flow would do with them.
///
/// ## Volume floor
/// Every list excludes manifest entries under ``minimumVolumeSizeBytes``. These are stub
/// entries in the published manifest — a few hundred bytes of header with no document body
/// — and downloading one produces a volume that cannot be read or searched.
///
/// ## Subseries order
/// Newest-first by leading four-digit year, ties broken by identifier ascending. The
/// tiebreak is **new in O-0 and deliberate**: the previous ordering sorted a `Set` by year
/// alone, and Swift's sort is not stable over an unordered collection, so the eight
/// same-start-year pairs in the shipped manifest (`1914`/`1914-20`, `1917`/`1917-72`,
/// `1931`/`1931-41`, `1933`/`1933-39`, `1941`/`1941-43`, `1945`/`1945-50`, `1950`/`1950-55`,
/// `1951`/`1951-54`) could appear in either order from launch to launch. Determinism is a
/// precondition for characterizing this list at all, and O-4 renders it as a 107-row sheet
/// where a self-shuffling order would be plainly wrong.
///
/// `OnboardingViewModel.allSubseries` still carries the untiebroken sort. It drives nothing
/// — the view model has one live caller, the static `hasDownloadedVolumes(in:)` — so it is
/// left alone rather than fixed in two places; retiring it is out of scope for this wave.
///
/// Version history:
///   1.0 — O-0: extracted from `OnboardingView` (`allVolumes` — which the view no longer
///         keeps in any form — plus `allSubseries`, `volumesBySubseries`,
///         `startYear(from:)`, `canProceedFromScope`, and the scope switch inside
///         `enqueueAndAdvance()`), plus the deterministic subseries tiebreak.
struct OnboardingScopeResolver: Equatable, Sendable {

    /// Manifest entries smaller than this are stubs, not volumes, and never offered.
    static let minimumVolumeSizeBytes = 20_000

    /// Every offerable volume, in manifest order.
    let volumes: [VolumeManifestEntry]

    /// Builds a resolver over the offerable subset of `manifestEntries`.
    ///
    /// - Parameter manifestEntries: the caller's current view of the manifest — the live
    ///   flow passes `diffResult?.known ?? bundledEntries`, so a refreshed manifest wins
    ///   over the bundled one.
    init(manifestEntries: [VolumeManifestEntry]) {
        self.volumes = manifestEntries.filter { $0.sizeBytes >= Self.minimumVolumeSizeBytes }
    }

    // MARK: - Derived lists

    /// Distinct subseries identifiers, newest-first, ties broken by identifier ascending.
    var subseries: [String] {
        Set(volumes.map(\.subseries)).sorted { lhs, rhs in
            let lhsYear = Self.startYear(from: lhs)
            let rhsYear = Self.startYear(from: rhs)
            return lhsYear == rhsYear ? lhs < rhs : lhsYear > rhsYear
        }
    }

    /// Volumes grouped under their subseries, groups in ``subseries`` order.
    var volumesBySubseries: [(subseries: String, volumes: [VolumeManifestEntry])] {
        subseries.map { sub in
            (sub, volumes.filter { $0.subseries == sub })
        }
    }

    /// The number of offerable volumes in `subseries`.
    func volumeCount(inSubseries subseries: String) -> Int {
        volumes.count { $0.subseries == subseries }
    }

    /// The leading four-digit year of a subseries identifier, or `0` if it has none.
    ///
    /// `"1969-76"` → 1969, `"1861"` → 1861. Anything unparseable sorts last.
    static func startYear(from subseries: String) -> Int {
        Int(subseries.prefix(4)) ?? 0
    }

    // MARK: - Validity

    /// Whether Continue is enabled for the given choice and selection.
    ///
    /// Corpus needs nothing; the other two need their selection made.
    func canProceed(
        scope: OnboardingScopeChoice,
        selectedSubseries: String,
        selectedVolumeId: String
    ) -> Bool {
        switch scope {
        case .corpus:    return true
        case .subseries: return !selectedSubseries.isEmpty
        case .volume:    return !selectedVolumeId.isEmpty
        }
    }

    // MARK: - Enqueue set

    /// The volumes Continue would enqueue for the given choice and selection.
    ///
    /// A `.volume` scope yields at most one entry even if the manifest carries a duplicate
    /// id, and an unmatched selection yields none rather than falling back to a wider scope
    /// — enqueuing the whole corpus because a volume id went stale is the failure this
    /// guards against.
    func enqueueSet(
        scope: OnboardingScopeChoice,
        selectedSubseries: String,
        selectedVolumeId: String
    ) -> [VolumeManifestEntry] {
        switch scope {
        case .corpus:
            return volumes
        case .subseries:
            return volumes.filter { $0.subseries == selectedSubseries }
        case .volume:
            return volumes.filter { $0.volumeId == selectedVolumeId }.prefix(1).map { $0 }
        }
    }
}

// MARK: - OnboardingCompletion

/// The side-effects onboarding performs when the user taps Finish.
///
/// Extracted in O-0 for one reason: these are the guarantees O-4 is not allowed to break,
/// and a guarantee that only exists inside a 583-line view body cannot be tested. The
/// acceptance contract in the design hand-off names them explicitly — "existing onboarding
/// completion side-effects (default project, download enqueue, `hasCompletedOnboarding`)
/// untouched".
@MainActor
enum OnboardingCompletion {

    /// The name given to the project created for a user who has never made one.
    static let defaultProjectName = "My Research"

    /// Creates the default research project, but only if the user has none.
    ///
    /// - Returns: the new project's id, or `nil` if a project already existed or the insert
    ///   failed. The caller makes a returned id active; a `nil` deliberately leaves the
    ///   current active project alone.
    ///
    /// Failure is swallowed rather than propagated, matching the shipped behaviour: a user
    /// who cannot be given a starter project should still finish onboarding and reach the
    /// app, and can create one by hand.
    @discardableResult
    static func ensureDefaultProjectExists(in context: ModelContext) -> UUID? {
        do {
            let descriptor = FetchDescriptor<Project>()
            let count = try context.fetchCount(descriptor)
            guard count == 0 else { return nil }

            let defaultProject = Project(name: defaultProjectName)
            context.insert(defaultProject)
            try context.save()

            #if DEBUG
            print("[OnboardingCompletion] Default project created: \(defaultProject.id)")
            #endif
            return defaultProject.id
        } catch {
            #if DEBUG
            print("[OnboardingCompletion] Failed to create default project: \(error)")
            #endif
            return nil
        }
    }
}
