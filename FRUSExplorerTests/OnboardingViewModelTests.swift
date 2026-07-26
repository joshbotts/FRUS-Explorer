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

import Testing
import Foundation
@testable import FRUSExplorer

/// Tests for `OnboardingViewModel` and the `ManifestStore` date helpers it reads.
///
/// **This does not cover the onboarding flow.** `OnboardingViewModel` does not drive the
/// shipped flow — `OnboardingView` carries its own step state and actions, and the view
/// model survives in the app through a single static helper, `hasDownloadedVolumes(in:)`,
/// called from `ContentView`. The flow itself is covered by
/// `OnboardingScopeResolverTests`.
///
/// The file was named `OnboardingFlowTests` until O-0, which is precisely how the
/// Workstream O recon came to believe the flow had coverage.
///
/// Version history:
///   1.0 — Session 49: initial implementation
///   1.1 — O-0: renamed from `OnboardingFlowTests` to name what it actually exercises
@MainActor
struct OnboardingViewModelTests {

    // MARK: - Helpers

    /// Creates a `VolumeManifestEntry` with the given fields; sensible defaults elsewhere.
    private func makeEntry(
        volumeId: String,
        subseries: String,
        sizeBytes: Int = 500_000
    ) -> VolumeManifestEntry {
        VolumeManifestEntry(
            volumeId: volumeId,
            filename: "\(volumeId).xml",
            subseries: subseries,
            title: "Volume \(volumeId)",
            dateRange: DateRange(earliest: nil, latest: nil),
            publicationDate: "2000",
            status: .published,
            editors: [],
            generalEditor: nil,
            documentCount: 0,
            sizeBytes: sizeBytes,
            tags: []
        )
    }

    /// Returns a `ManifestStore` seeded with the given entries (bypasses bundle I/O).
    private func makeManifestStore(_ entries: [VolumeManifestEntry]) -> ManifestStore {
        ManifestStore(bundledEntries: entries)
    }

    private func makeViewModel(entries: [VolumeManifestEntry]) -> OnboardingViewModel {
        let store = makeManifestStore(entries)
        return OnboardingViewModel(manifestStore: store, volumesDirectory: nil)
    }

    // MARK: - corpusDateRange

    @Test("corpusDateRangeDerivedFromManifest — min/max years extracted from subseries")
    func corpusDateRangeDerivedFromManifest() {
        let entries = [
            makeEntry(volumeId: "frus1969-76v01", subseries: "1969-76"),
            makeEntry(volumeId: "frus1861v01",    subseries: "1861"),
            makeEntry(volumeId: "frus1977-80v01", subseries: "1977-80"),
        ]
        let store = makeManifestStore(entries)
        let range = store.corpusDateRange

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let minComponents = cal.dateComponents([.year, .month, .day], from: range.lowerBound)
        let maxComponents = cal.dateComponents([.year, .month, .day], from: range.upperBound)

        #expect(minComponents.year  == 1861)
        #expect(minComponents.month == 1)
        #expect(minComponents.day   == 1)
        #expect(maxComponents.year  == 1980)   // end year of the latest subseries "1977-80"
        #expect(maxComponents.month == 12)
        #expect(maxComponents.day   == 31)
    }

    @Test("corpusDateRange fallback — empty manifest returns 1861...1992")
    func corpusDateRangeFallback() {
        let store = makeManifestStore([])
        let range = store.corpusDateRange

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let minYear = cal.component(.year, from: range.lowerBound)
        let maxYear = cal.component(.year, from: range.upperBound)

        #expect(minYear == 1861)
        #expect(maxYear == 1992)
    }

    @Test("subseriesEndYear — expands 2-digit ends, handles 4-digit ends, bare years, rollover")
    func subseriesEndYearParsing() {
        #expect(ManifestStore.subseriesEndYear("1969-76")   == 1976)
        #expect(ManifestStore.subseriesEndYear("1989-92")   == 1992)   // the reported 1989 cap
        #expect(ManifestStore.subseriesEndYear("1977-80")   == 1980)
        #expect(ManifestStore.subseriesEndYear("1993-2000") == 2000)   // 4-digit end
        #expect(ManifestStore.subseriesEndYear("1861")      == 1861)   // bare single-year
        #expect(ManifestStore.subseriesEndYear("1899-01")   == 1901)   // century rollover
        #expect(ManifestStore.subseriesEndYear("notayear")  == nil)
    }

    // MARK: - DownloadScope — corpus

    @Test("downloadScopeCorpus — resolvedScope enqueues all volumes")
    func downloadScopeCorpusEnqueuesAllVolumes() {
        let entries = [
            makeEntry(volumeId: "frus1969-76v01", subseries: "1969-76"),
            makeEntry(volumeId: "frus1977-80v01", subseries: "1977-80"),
            makeEntry(volumeId: "frus1861v01",    subseries: "1861"),
        ]
        let vm = makeViewModel(entries: entries)
        vm.selectedScope = .corpus
        let covered = vm.volumesForScope(vm.resolvedScope)
        #expect(covered.count == 3)
    }

    // MARK: - DownloadScope — subseries filter

    @Test("downloadScopeSubseries — resolvedScope filters to matching subseries")
    func downloadScopeSubseriesFiltersCorrectly() {
        let entries = [
            makeEntry(volumeId: "frus1969-76v01", subseries: "1969-76"),
            makeEntry(volumeId: "frus1969-76v02", subseries: "1969-76"),
            makeEntry(volumeId: "frus1977-80v01", subseries: "1977-80"),
        ]
        let vm = makeViewModel(entries: entries)
        vm.selectedScope = .subseries("1969-76")
        vm.selectedSubseries = "1969-76"
        let covered = vm.volumesForScope(vm.resolvedScope)
        #expect(covered.count == 2)
        #expect(covered.allSatisfy { $0.subseries == "1969-76" })
    }

    // MARK: - Default project pre-fill

    @Test("defaultProjectPreFill — name, question, and dates pre-populated from corpus")
    func defaultProjectPreFillUsesCorpusDates() {
        let entries = [
            makeEntry(volumeId: "frus1969-76v01", subseries: "1969-76"),
            makeEntry(volumeId: "frus1861v01",    subseries: "1861"),
        ]
        let vm = makeViewModel(entries: entries)

        #expect(vm.projectName     == "Onboarding")
        #expect(vm.projectQuestion == "Explore app")

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!

        let startYear = vm.projectDateStart.map { cal.component(.year, from: $0) }
        let endYear   = vm.projectDateEnd.map   { cal.component(.year, from: $0) }

        #expect(startYear == 1861)
        #expect(endYear   == 1976)   // end year of the latest subseries "1969-76"
    }

    // MARK: - Subseries sort order

    @Test("allSubseries — sorted descending by start year")
    func allSubseriesSortedDescending() {
        let entries = [
            makeEntry(volumeId: "frus1977-80v01", subseries: "1977-80"),
            makeEntry(volumeId: "frus1861v01",    subseries: "1861"),
            makeEntry(volumeId: "frus1969-76v01", subseries: "1969-76"),
        ]
        let vm = makeViewModel(entries: entries)
        let years = vm.allSubseries.compactMap { Int($0.prefix(4)) }
        #expect(years == years.sorted(by: >))
    }

    // MARK: - Small-volume exclusion

    @Test("allVolumes — entries below 20 000 bytes excluded")
    func smallVolumesExcluded() {
        let entries = [
            makeEntry(volumeId: "frus1969-76v01", subseries: "1969-76", sizeBytes: 500_000),
            makeEntry(volumeId: "frus1969-76v02", subseries: "1969-76", sizeBytes: 1_000),
        ]
        let vm = makeViewModel(entries: entries)
        #expect(vm.allVolumes.count == 1)
        #expect(vm.allVolumes.first?.volumeId == "frus1969-76v01")
    }

    // MARK: - canProceedFromDownloadScope

    @Test("canProceedFromDownloadScope — corpus always true")
    func canProceedCorpus() {
        let vm = makeViewModel(entries: [makeEntry(volumeId: "v1", subseries: "1969-76")])
        vm.selectedScope = .corpus
        #expect(vm.canProceedFromDownloadScope)
    }

    @Test("canProceedFromDownloadScope — subseries requires non-empty selectedSubseries")
    func canProceedSubseries() {
        let vm = makeViewModel(entries: [makeEntry(volumeId: "v1", subseries: "1969-76")])
        vm.selectedScope = .subseries("")
        vm.selectedSubseries = ""
        #expect(!vm.canProceedFromDownloadScope)

        vm.selectedSubseries = "1969-76"
        vm.selectedScope = .subseries("1969-76")
        #expect(vm.canProceedFromDownloadScope)
    }
}
