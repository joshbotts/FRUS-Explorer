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

#if DEBUG
import Foundation
import SwiftData

/// Seeds one research note for UI tests, so drilled-into research lists have CONTENT (#312).
///
/// ## The gap this closes
/// `UIObstructionTests` scenario 5 gates the Research detail's push and its top chrome — but on
/// a fresh install every document list is legitimately empty and renders a *centered*
/// `ContentUnavailableView`, so there is no top-anchored row for a mis-computed safe area to
/// hide, and "no assertion over an empty list can distinguish the fix from the bug." The volume
/// seeder (`UITestVolumeSeeder`) closed the same shape of gap for Browse; nothing seeded
/// research data. This is that half.
///
/// ## Contract — mirrors `UITestVolumeSeeder` deliberately
/// Gated twice over: `#if DEBUG` (absent from AppStore and DirectDistribution builds), and inert
/// unless `FRUS_UI_TEST_SEED_NOTE` is set. The note's body is deliberately implausible as real
/// research so nobody mistakes a seeded store for a used one. Under `FRUS_UI_TEST_MODE` the
/// SwiftData store is in memory (`makeEphemeralContainer` in `ModelContainer+FRUS.swift`), so every
/// launch starts empty and the lookup on the body text only stops a second seed within one process.
/// This comment used to say the store survived between runs; it has not since that store landed.
///
/// ## Which document the note is on
/// `"d01"` by default: an id no fixture volume contains, so the row opens a document that cannot
/// load. That is all the obstruction and tab-scoped-reading suites need, and it keeps them clear of a
/// live WKWebView, whose queries time out on iPhone. A test that must READ the document — turn its
/// page, say — names a real one with `FRUS_UI_TEST_SEED_NOTE_DOCUMENT`, such as `d1` of the volume
/// `FRUS_UI_TEST_SEED_VOLUME` seeds.
///
/// Version history:
///   1.0 — #312: initial implementation
///   1.1 — #1273: `FRUS_UI_TEST_SEED_NOTE_DOCUMENT`, and the persistence note corrected
enum UITestResearchSeeder {

    /// The launch-environment key a UI test sets to request the seed.
    static let environmentKey = "FRUS_UI_TEST_SEED_NOTE"

    /// The launch-environment key that puts the note on a named document instead of `"d01"`.
    static let documentEnvironmentKey = "FRUS_UI_TEST_SEED_NOTE_DOCUMENT"

    /// The seeded note's body — the top-anchored row text scenario 5 asserts on.
    static let noteBody = "UI Test Research Note"

    /// Seeds the note if requested. Runs on the main-actor boot path that already holds the
    /// container's `mainContext` (beside `DuplicateRecordCleanup`), so it needs no new plumbing.
    @MainActor
    static func seedIfRequested(context: ModelContext) {
        let environment = ProcessInfo.processInfo.environment
        guard environment[environmentKey] == "1" else { return }
        let body = noteBody
        let existing = (try? context.fetchCount(FetchDescriptor<ResearchNote>(
            predicate: #Predicate { $0.bodyText == body }))) ?? 0
        guard existing == 0 else { return }
        let volumeId = environment[UITestVolumeSeeder.environmentKey] ?? "frus1961-63v06"
        let documentId = environment[documentEnvironmentKey].flatMap { $0.isEmpty ? nil : $0 } ?? "d01"
        let note = ResearchNote(documentId: documentId, volumeId: volumeId, bodyText: body)
        context.insert(note)
        try? context.save()
        print("[UITestResearchSeeder] Seeded one research note")
    }
}

/// Seeds two custom volume scopes with FIXED ids, so a UI test can narrow the subseries hierarchy
/// to one of them (#1364).
///
/// ## Why the ids are fixed
/// The browse-within filter is a scope id in UserDefaults (`AppState.browseScopeFilterId`), and a
/// UI test that launches with the filter already on has to name that id in its launch arguments
/// before the scope exists. The UI-test store is in memory (see `UITestResearchSeeder`), so the
/// scopes are re-seeded on every launch and the same ids come back each time.
///
/// ## Why two
/// Everything My Scopes shows about the filter is per scope: the row mark, and the long-press menu
/// offering Stop Browsing Within on the scope the list is narrowed to and Browse Within This Scope
/// on every other. With one scope on screen, "marks the narrowed scope" and "marks every row while
/// any filter is on" look the same, so `BrowseWithinScopeTests` narrows to the first and asserts
/// the second reads as un-narrowed.
///
/// ## Contract — the two seeders' own
/// `#if DEBUG`, and inert unless `FRUS_UI_TEST_SEED_SCOPE` is `1`. The first scope's two members
/// are real manifest volumes in two subseries, so it narrows the subseries list to two eras; the
/// second holds one volume from a third era. None needs to be downloaded, because Browse lists the
/// manifest, not the device.
///
/// Version history:
///   1.0 — #1364: initial implementation
///   1.1 — #1364 review round 1: a second scope, so a row mark on every row cannot pass for one
enum UITestScopeSeeder {

    /// The launch-environment key a UI test sets to request the seed.
    static let environmentKey = "FRUS_UI_TEST_SEED_SCOPE"

    /// The first seeded scope's id — the one the UI suite narrows to. `BrowseWithinScopeTests`
    /// repeats it, because a UI-test target cannot import the app.
    static let scopeIdString = "13640000-B4B4-4B4B-8B4B-000000001364"

    /// The first seeded scope's name.
    static let scopeName = "UI Test Scope"

    /// The first seeded scope's members: one Kennedy and one Nixon-Ford volume.
    static let volumeIds = ["frus1961-63v06", "frus1969-76v01"]

    /// The second seeded scope's id — the one the filter is NOT on while the suite narrows to the
    /// first.
    static let otherScopeIdString = "13640000-B4B4-4B4B-8B4B-000000002364"

    /// The second seeded scope's name. It does not begin with the first's, so a test can find
    /// either row by the start of its accessibility label.
    static let otherScopeName = "Other UI Test Scope"

    /// The second seeded scope's member: one 1945 volume.
    static let otherVolumeIds = ["frus1945v01"]

    /// Seeds both scopes if requested, each once per store. Runs at the top of the boot path,
    /// before its first `await` — not beside `UITestResearchSeeder`, which waits for the search
    /// pipeline (see the call site in `FRUSExplorerApp.bootDownloadManager`).
    @MainActor
    static func seedIfRequested(context: ModelContext) {
        guard ProcessInfo.processInfo.environment[environmentKey] == "1" else { return }
        for (idString, name, members) in [(scopeIdString, scopeName, volumeIds),
                                          (otherScopeIdString, otherScopeName, otherVolumeIds)] {
            guard let scopeId = UUID(uuidString: idString) else { continue }
            let existing = (try? context.fetchCount(FetchDescriptor<CustomVolumeScope>(
                predicate: #Predicate { $0.id == scopeId }))) ?? 0
            guard existing == 0 else { continue }
            let scope = CustomVolumeScope(name: name, volumeIds: members)
            scope.id = scopeId
            context.insert(scope)
            print("[UITestScopeSeeder] Seeded scope \(idString)")
        }
        try? context.save()
    }
}
#endif
