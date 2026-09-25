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

/// Seeds one custom volume scope with a FIXED id, so a UI test can narrow Browse to it (#1364).
///
/// ## Why the id is fixed
/// The browse-within filter is a scope id in UserDefaults (`AppState.browseScopeFilterId`), and a
/// UI test that launches with the filter already on has to name that id in its launch arguments
/// before the scope exists. The UI-test store is in memory (see `UITestResearchSeeder`), so the
/// scope is re-seeded on every launch and the same id comes back each time.
///
/// ## Contract — the two seeders' own
/// `#if DEBUG`, and inert unless `FRUS_UI_TEST_SEED_SCOPE` is `1`. Its two members are real
/// manifest volumes in two subseries, so the scope narrows the subseries list to two eras; neither
/// needs to be downloaded, because Browse lists the manifest, not the device.
///
/// Version history:
///   1.0 — #1364: initial implementation
enum UITestScopeSeeder {

    /// The launch-environment key a UI test sets to request the seed.
    static let environmentKey = "FRUS_UI_TEST_SEED_SCOPE"

    /// The seeded scope's id. `BrowseWithinScopeTests` repeats it, because a UI-test target cannot
    /// import the app.
    static let scopeIdString = "13640000-B4B4-4B4B-8B4B-000000001364"

    /// The seeded scope's name.
    static let scopeName = "UI Test Scope"

    /// The seeded scope's members: one Kennedy and one Nixon-Ford volume.
    static let volumeIds = ["frus1961-63v06", "frus1969-76v01"]

    /// Seeds the scope if requested, once per store. Runs at the top of the boot path, before its
    /// first `await` — not beside `UITestResearchSeeder`, which waits for the search pipeline (see
    /// the call site in `FRUSExplorerApp.bootDownloadManager`).
    @MainActor
    static func seedIfRequested(context: ModelContext) {
        guard ProcessInfo.processInfo.environment[environmentKey] == "1",
              let scopeId = UUID(uuidString: scopeIdString) else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<CustomVolumeScope>(
            predicate: #Predicate { $0.id == scopeId }))) ?? 0
        guard existing == 0 else { return }
        let scope = CustomVolumeScope(name: scopeName, volumeIds: volumeIds)
        scope.id = scopeId
        context.insert(scope)
        try? context.save()
        print("[UITestScopeSeeder] Seeded scope \(scopeIdString)")
    }
}
#endif
