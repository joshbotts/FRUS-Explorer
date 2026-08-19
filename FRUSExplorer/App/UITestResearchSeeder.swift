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
/// research so nobody mistakes a seeded store for a used one. Idempotent by lookup on the body
/// text: the UI-test store survives between runs, and a second launch must not mint a second row.
enum UITestResearchSeeder {

    /// The launch-environment key a UI test sets to request the seed.
    static let environmentKey = "FRUS_UI_TEST_SEED_NOTE"

    /// The seeded note's body — the top-anchored row text scenario 5 asserts on.
    static let noteBody = "UI Test Research Note"

    /// Seeds the note if requested. Runs on the main-actor boot path that already holds the
    /// container's `mainContext` (beside `DuplicateRecordCleanup`), so it needs no new plumbing.
    @MainActor
    static func seedIfRequested(context: ModelContext) {
        guard ProcessInfo.processInfo.environment[environmentKey] == "1" else { return }
        let body = noteBody
        let existing = (try? context.fetchCount(FetchDescriptor<ResearchNote>(
            predicate: #Predicate { $0.bodyText == body }))) ?? 0
        guard existing == 0 else { return }
        let volumeId = ProcessInfo.processInfo
            .environment[UITestVolumeSeeder.environmentKey] ?? "frus1961-63v06"
        let note = ResearchNote(documentId: "d01", volumeId: volumeId, bodyText: body)
        context.insert(note)
        try? context.save()
        print("[UITestResearchSeeder] Seeded one research note")
    }
}
#endif
