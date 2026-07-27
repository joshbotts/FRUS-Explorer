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
import SwiftData
@testable import FRUSExplorer

// MARK: - Characterization tests for the live onboarding flow

/// Pins what onboarding does today, so O-4 can rewrite the view around the word-cloud
/// backdrop and prove it changed nothing.
///
/// **These tests must pass unchanged after O-4.** That is the whole point of them: before
/// O-0, the 583-line `OnboardingView` had no behavioural coverage at all. The two suites
/// named for onboarding — `OnboardingViewModelTests` and `OnboardingTests` — exercise
/// `OnboardingViewModel`, which does not drive the shipped flow; its only live caller is
/// the static `hasDownloadedVolumes(in:)`. If a change here is needed to make a later
/// session compile, that is a signal the flow's contract moved, not a test to relax.
///
/// The contract, from the design hand-off's acceptance checklist: "existing onboarding
/// completion side-effects (default project, download enqueue, `hasCompletedOnboarding`)
/// untouched".
///
/// Version history:
///   1.0 — O-0: initial implementation
@Suite("Onboarding — scope resolution (characterization)")
struct OnboardingScopeResolverTests {

    // MARK: - Fixtures

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

    /// Three subseries, five volumes, deliberately out of year order in the source array.
    private var standardCorpus: [VolumeManifestEntry] {
        [
            makeEntry(volumeId: "frus1969-76v01", subseries: "1969-76"),
            makeEntry(volumeId: "frus1861v01",    subseries: "1861"),
            makeEntry(volumeId: "frus1977-80v01", subseries: "1977-80"),
            makeEntry(volumeId: "frus1969-76v02", subseries: "1969-76"),
            makeEntry(volumeId: "frus1969-76v03", subseries: "1969-76"),
        ]
    }

    // MARK: - The volume floor

    @Test("Entries below the 20 000-byte floor are never offered")
    func volumeFloorExcludesStubs() {
        let resolver = OnboardingScopeResolver(manifestEntries: [
            makeEntry(volumeId: "real",  subseries: "1969-76", sizeBytes: 500_000),
            makeEntry(volumeId: "stub",  subseries: "1969-76", sizeBytes: 1_000),
            makeEntry(volumeId: "under", subseries: "1969-76", sizeBytes: 19_999),
            makeEntry(volumeId: "exact", subseries: "1969-76", sizeBytes: 20_000),
        ])

        // The floor is inclusive: exactly 20 000 is offerable.
        #expect(resolver.volumes.map(\.volumeId) == ["real", "exact"])
    }

    @Test("The floor applies to every list, not just the volume picker")
    func volumeFloorAppliesToSubseriesToo() {
        // "1861" has only a stub, so it must not appear as a choosable subseries at all —
        // otherwise a user picks an era and Continue enqueues nothing.
        let resolver = OnboardingScopeResolver(manifestEntries: [
            makeEntry(volumeId: "frus1969-76v01", subseries: "1969-76", sizeBytes: 500_000),
            makeEntry(volumeId: "frus1861v01",    subseries: "1861",    sizeBytes: 900),
        ])

        #expect(resolver.subseries == ["1969-76"])
        #expect(resolver.enqueueSet(scope: .subseries, selectedSubseries: "1861",
                                    selectedVolumeId: "").isEmpty)
    }

    // MARK: - Subseries order

    @Test("Subseries are newest-first by leading year")
    func subseriesSortedNewestFirst() {
        let resolver = OnboardingScopeResolver(manifestEntries: standardCorpus)
        #expect(resolver.subseries == ["1977-80", "1969-76", "1861"])
    }

    @Test("startYear parses the leading four digits, and 0 for anything else")
    func startYearParsing() {
        #expect(OnboardingScopeResolver.startYear(from: "1969-76")   == 1969)
        #expect(OnboardingScopeResolver.startYear(from: "1861")      == 1861)
        #expect(OnboardingScopeResolver.startYear(from: "1993-2000") == 1993)
        #expect(OnboardingScopeResolver.startYear(from: "notayear")  == 0)
        #expect(OnboardingScopeResolver.startYear(from: "")          == 0)
    }

    @Test("Same-start-year subseries have a stable order, and it does not drift between builds")
    func tiedStartYearsAreDeterministic() {
        // The eight tied pairs in the shipped manifest. Before O-0 these sorted by year
        // alone out of a Set, so their relative order was unspecified and could differ
        // launch to launch. Ties now break on the identifier, ascending.
        let tied = ["1914", "1914-20", "1917", "1917-72", "1931", "1931-41",
                    "1933", "1933-39", "1941", "1941-43", "1945", "1945-50",
                    "1950", "1950-55", "1951", "1951-54"]
        let entries = tied.enumerated().map {
            makeEntry(volumeId: "v\($0.offset)", subseries: $0.element)
        }

        let expected = ["1951", "1951-54", "1950", "1950-55", "1945", "1945-50",
                        "1941", "1941-43", "1933", "1933-39", "1931", "1931-41",
                        "1917", "1917-72", "1914", "1914-20"]

        // Rebuild repeatedly: a Set's iteration order varies per process *and* per
        // instance, so a single pass can pass by luck where the old sort would not.
        for _ in 0..<25 {
            let resolver = OnboardingScopeResolver(manifestEntries: entries.shuffled())
            #expect(resolver.subseries == expected)
        }
    }

    // MARK: - Grouping

    @Test("Volumes group under their subseries, groups in subseries order")
    func groupingFollowsSubseriesOrder() {
        let grouped = OnboardingScopeResolver(manifestEntries: standardCorpus).volumesBySubseries

        #expect(grouped.map(\.subseries) == ["1977-80", "1969-76", "1861"])
        #expect(grouped.map(\.volumes.count) == [1, 3, 1])
        #expect(grouped[1].volumes.map(\.volumeId)
                == ["frus1969-76v01", "frus1969-76v02", "frus1969-76v03"])
    }

    @Test("volumeCount matches what the grouped picker shows")
    func volumeCountAgreesWithGrouping() {
        let resolver = OnboardingScopeResolver(manifestEntries: standardCorpus)
        for group in resolver.volumesBySubseries {
            #expect(resolver.volumeCount(inSubseries: group.subseries) == group.volumes.count)
        }
        #expect(resolver.volumeCount(inSubseries: "no-such-era") == 0)
    }

    // MARK: - Continue is enabled

    @Test("Corpus needs no selection; the other two do")
    func canProceedRules() {
        let resolver = OnboardingScopeResolver(manifestEntries: standardCorpus)

        #expect(resolver.canProceed(scope: .corpus, selectedSubseries: "", selectedVolumeId: ""))

        #expect(!resolver.canProceed(scope: .subseries, selectedSubseries: "", selectedVolumeId: ""))
        #expect(resolver.canProceed(scope: .subseries, selectedSubseries: "1969-76",
                                    selectedVolumeId: ""))

        #expect(!resolver.canProceed(scope: .volume, selectedSubseries: "", selectedVolumeId: ""))
        #expect(resolver.canProceed(scope: .volume, selectedSubseries: "",
                                    selectedVolumeId: "frus1861v01"))
    }

    @Test("Continue is enabled on a selection that matches nothing")
    func canProceedDoesNotValidateTheSelection() {
        // Characterization, not endorsement: the shipped flow enables Continue on any
        // non-empty string, so a stale id advances the user to Ready having enqueued
        // nothing. `enqueueSetIsEmptyForUnknownSelection` pins the other half.
        let resolver = OnboardingScopeResolver(manifestEntries: standardCorpus)
        #expect(resolver.canProceed(scope: .volume, selectedSubseries: "",
                                    selectedVolumeId: "frus9999v99"))
    }

    // MARK: - What Continue enqueues

    @Test("Corpus enqueues every offerable volume")
    func enqueueCorpus() {
        let resolver = OnboardingScopeResolver(manifestEntries: standardCorpus)
        let set = resolver.enqueueSet(scope: .corpus, selectedSubseries: "", selectedVolumeId: "")
        #expect(set.count == 5)
        #expect(set.map(\.volumeId) == resolver.volumes.map(\.volumeId))
    }

    @Test("Subseries enqueues exactly that subseries")
    func enqueueSubseries() {
        let resolver = OnboardingScopeResolver(manifestEntries: standardCorpus)
        let set = resolver.enqueueSet(scope: .subseries, selectedSubseries: "1969-76",
                                      selectedVolumeId: "")
        #expect(set.map(\.volumeId)
                == ["frus1969-76v01", "frus1969-76v02", "frus1969-76v03"])
    }

    @Test("Volume enqueues exactly one, even if the manifest repeats the id")
    func enqueueVolumeIsCappedAtOne() {
        let resolver = OnboardingScopeResolver(manifestEntries: [
            makeEntry(volumeId: "dupe", subseries: "1969-76"),
            makeEntry(volumeId: "dupe", subseries: "1969-76"),
            makeEntry(volumeId: "other", subseries: "1969-76"),
        ])
        let set = resolver.enqueueSet(scope: .volume, selectedSubseries: "",
                                      selectedVolumeId: "dupe")
        #expect(set.count == 1)
        #expect(set.first?.volumeId == "dupe")
    }

    @Test("An unmatched selection enqueues nothing — it never widens to the corpus")
    func enqueueSetIsEmptyForUnknownSelection() {
        let resolver = OnboardingScopeResolver(manifestEntries: standardCorpus)
        #expect(resolver.enqueueSet(scope: .volume, selectedSubseries: "",
                                    selectedVolumeId: "frus9999v99").isEmpty)
        #expect(resolver.enqueueSet(scope: .subseries, selectedSubseries: "1900-05",
                                    selectedVolumeId: "").isEmpty)
    }

    @Test("The selection for the other scope is ignored")
    func selectionsDoNotCrossScopes() {
        // Both fields are always passed; only the one the scope names may be read. The
        // view keeps stale values in `@State` after a scope switch, so this is the rule
        // that stops a previously-picked subseries leaking into a volume download.
        let resolver = OnboardingScopeResolver(manifestEntries: standardCorpus)
        let set = resolver.enqueueSet(scope: .volume, selectedSubseries: "1969-76",
                                      selectedVolumeId: "frus1861v01")
        #expect(set.map(\.volumeId) == ["frus1861v01"])
    }

    @Test("An empty manifest resolves to empty everywhere rather than trapping")
    func emptyManifest() {
        let resolver = OnboardingScopeResolver(manifestEntries: [])
        #expect(resolver.volumes.isEmpty)
        #expect(resolver.subseries.isEmpty)
        #expect(resolver.volumesBySubseries.isEmpty)
        #expect(resolver.enqueueSet(scope: .corpus, selectedSubseries: "",
                                    selectedVolumeId: "").isEmpty)
        // Corpus stays enabled on an empty manifest — Continue advances, enqueuing nothing.
        #expect(resolver.canProceed(scope: .corpus, selectedSubseries: "", selectedVolumeId: ""))
    }
}

// MARK: - Completion side-effects

/// Pins the Finish-button guarantees the design hand-off marks untouchable.
///
/// Version history:
///   1.0 — O-0: initial implementation
@Suite("Onboarding — completion side-effects (characterization)")
@MainActor
struct OnboardingCompletionTests {

    /// An in-memory container for the models this path touches.
    ///
    /// Returns the container, never a bare `mainContext`: `ModelContext` holds its
    /// container weakly, and a dropped container SIGTRAPs the test host.
    /// `cloudKitDatabase: .none` keeps the entitled host from starting real sync.
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: Project.self, configurations: config)
    }

    @Test("A user with no projects gets exactly one, named My Research")
    func createsDefaultProjectWhenNoneExists() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let newId = OnboardingCompletion.ensureDefaultProjectExists(in: context)

        let projects = try context.fetch(FetchDescriptor<Project>())
        #expect(projects.count == 1)
        #expect(projects.first?.name == "My Research")
        #expect(newId != nil)
        #expect(newId == projects.first?.id)
    }

    @Test("The new project is saved, not left pending in the context")
    func defaultProjectIsPersisted() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        OnboardingCompletion.ensureDefaultProjectExists(in: context)

        // A second, independent context over the same container sees only saved rows —
        // so this fails if the insert was never committed.
        let reader = ModelContext(container)
        #expect(try reader.fetchCount(FetchDescriptor<Project>()) == 1)
    }

    @Test("A user who already has a project gets no second one, and no id back")
    func doesNotCreateWhenAProjectExists() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(Project(name: "Cold War Diplomacy"))
        try context.save()

        let newId = OnboardingCompletion.ensureDefaultProjectExists(in: context)

        // nil is what tells the caller to leave the active project alone — returning an
        // id here would silently switch a returning user off their own project.
        #expect(newId == nil)
        let projects = try context.fetch(FetchDescriptor<Project>())
        #expect(projects.count == 1)
        #expect(projects.first?.name == "Cold War Diplomacy")
    }

    @Test("Finishing twice is idempotent")
    func runningTwiceCreatesOneProject() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let first  = OnboardingCompletion.ensureDefaultProjectExists(in: context)
        let second = OnboardingCompletion.ensureDefaultProjectExists(in: context)

        #expect(first != nil)
        #expect(second == nil)
        #expect(try context.fetchCount(FetchDescriptor<Project>()) == 1)
    }

    // MARK: - The flag that stops onboarding coming back

    @Test("hasCompletedOnboarding survives the launch that set it")
    func completionFlagPersists() {
        // `completeOnboarding()` sets this unconditionally, and it is the only thing
        // standing between a finished user and seeing the flow again next launch. Pinned
        // through the persistence round-trip rather than the assignment, because the
        // assignment is not what could break.
        //
        // No `await` between save and restore: these run to completion on the main actor,
        // so the shared default cannot be observed half-changed by a sibling test.
        let key = "hasCompletedOnboarding"
        let original = UserDefaults.standard.object(forKey: key)
        defer {
            if let original { UserDefaults.standard.set(original, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }

        UserDefaults.standard.set(false, forKey: key)
        let state = AppState()
        #expect(state.hasCompletedOnboarding == false)

        state.hasCompletedOnboarding = true
        #expect(UserDefaults.standard.bool(forKey: key))
        #expect(AppState().hasCompletedOnboarding)
    }
}
