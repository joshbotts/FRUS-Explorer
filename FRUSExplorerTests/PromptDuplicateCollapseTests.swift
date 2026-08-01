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
import Testing
@testable import FRUSExplorer

// MARK: - PromptDuplicateCollapseTests

/// Collapsing duplicate standard prompts (#561).
///
/// ## The shape of the bug
/// Standard prompts are seeded **per device** with fresh ids and identified by **name**. Seeding
/// runs once inside boot — and SwiftData's CloudKit initial import lands *after* that. So a second
/// device boots to an empty store, seeds 8, then receives the first device's 8, and shows 16 for
/// the rest of the session: the pass that would have collapsed them had already run.
///
/// ## What these guard
/// Deleting a duplicate is destructive and synced, so two properties matter more than the count:
/// **which** record survives (two devices choosing differently would delete each other's survivor
/// and the prompt would vanish everywhere), and that nothing is left pointing at a deleted id.
///
/// Version history:
///   1.0 — #561: initial implementation
@Suite("Prompt duplicate collapse")
@MainActor
struct PromptDuplicateCollapseTests {

    private func container() throws -> ModelContainer {
        try ModelContainer.makeTestContainer()
    }

    private func prompt(_ name: String, createdAt: Date?, id: UUID = UUID()) -> SummarizationPrompt {
        let p = SummarizationPrompt(name: name, promptText: "text",
                                    responseFormat: .general, isStandard: true)
        p.id = id
        p.createdAt = createdAt
        return p
    }

    // MARK: - The count

    @Test("Duplicates by name collapse to one")
    func duplicatesCollapse() throws {
        let container = try container()
        let context = container.mainContext
        context.insert(prompt("Standard Summary", createdAt: Date(timeIntervalSince1970: 100)))
        context.insert(prompt("Standard Summary", createdAt: Date(timeIntervalSince1970: 200)))
        context.insert(prompt("Key Points", createdAt: Date(timeIntervalSince1970: 100)))

        #expect(SummarizationPromptSeeder.collapseDuplicates(context: context) == 1)
        let remaining = try context.fetch(FetchDescriptor<SummarizationPrompt>())
        #expect(remaining.count == 2)
        #expect(Set(remaining.map(\.name)) == ["Standard Summary", "Key Points"])
    }

    @Test("A store with no duplicates is untouched")
    func noDuplicatesNoOp() throws {
        let container = try container()
        let context = container.mainContext
        context.insert(prompt("Standard Summary", createdAt: Date(timeIntervalSince1970: 100)))
        #expect(SummarizationPromptSeeder.collapseDuplicates(context: context) == 0)
        #expect(try context.fetch(FetchDescriptor<SummarizationPrompt>()).count == 1)
    }

    /// A user's own prompt may legitimately share a name with a standard one, and must not be
    /// collapsed into it — it is not a duplicate, it is theirs.
    @Test("A user prompt sharing a name is never collapsed")
    func userPromptsAreSafe() throws {
        let container = try container()
        let context = container.mainContext
        context.insert(prompt("Standard Summary", createdAt: Date(timeIntervalSince1970: 100)))
        let mine = SummarizationPrompt(name: "Standard Summary", promptText: "mine",
                                       responseFormat: .general, isStandard: false)
        context.insert(mine)

        #expect(SummarizationPromptSeeder.collapseDuplicates(context: context) == 0)
        #expect(try context.fetch(FetchDescriptor<SummarizationPrompt>()).count == 2)
    }

    // MARK: - Which record survives

    @Test("The earliest record is kept")
    func earliestWins() throws {
        let container = try container()
        let context = container.mainContext
        let old = prompt("Standard Summary", createdAt: Date(timeIntervalSince1970: 100))
        let new = prompt("Standard Summary", createdAt: Date(timeIntervalSince1970: 999))
        context.insert(new)   // inserted first, so fetch order cannot be what decides it
        context.insert(old)

        SummarizationPromptSeeder.collapseDuplicates(context: context)
        let remaining = try context.fetch(FetchDescriptor<SummarizationPrompt>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.id == old.id)
    }

    /// The load-bearing tiebreak. With `createdAt` nil on both sides — legacy rows — a
    /// `createdAt`-only rule leaves the comparison equal in both directions and the survivor
    /// depends on fetch order, which two devices need not share. They would then delete each
    /// other's survivor and the prompt would be gone everywhere.
    @Test("Equal timestamps are broken by id, not by fetch order")
    func tieBreakIsDeterministic() throws {
        let lowId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let highId = UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000001")!

        // Run it twice with the two insertion orders. A fetch-order-dependent rule would keep a
        // different record each time.
        for reversed in [false, true] {
            let container = try container()
            let context = container.mainContext
            let a = prompt("Standard Summary", createdAt: nil, id: lowId)
            let b = prompt("Standard Summary", createdAt: nil, id: highId)
            if reversed { context.insert(b); context.insert(a) }
            else { context.insert(a); context.insert(b) }

            SummarizationPromptSeeder.collapseDuplicates(context: context)
            let remaining = try context.fetch(FetchDescriptor<SummarizationPrompt>())
            #expect(remaining.count == 1)
            #expect(remaining.first?.id == lowId,
                    """
                    Insertion order \(reversed ? "reversed" : "normal") changed the survivor — two \
                    devices would delete each other's and the prompt would vanish everywhere.
                    """)
        }
    }

    // MARK: - Nothing is left pointing at a deleted prompt

    /// Three referrers store a prompt id, and all three must follow the keeper. A summary that
    /// loses its prompt loses its provenance; a collection that loses its default silently falls
    /// back to another one.
    @Test("Every referrer is re-pointed at the keeper")
    func referrersFollowTheKeeper() throws {
        let container = try container()
        let context = container.mainContext
        let keeper = prompt("Standard Summary", createdAt: Date(timeIntervalSince1970: 100))
        let doomed = prompt("Standard Summary", createdAt: Date(timeIntervalSince1970: 900))
        context.insert(keeper)
        context.insert(doomed)

        let summary = GeneratedSummary(documentId: "d1", volumeId: "v1", promptId: doomed.id,
                                       responseText: "text", responseFormat: .general)
        context.insert(summary)
        let collection = Collection(name: "C")
        collection.summaryPromptId = doomed.id
        context.insert(collection)
        let entry = CollectionEntry(collectionId: collection.id, documentId: "d1",
                                    volumeId: "v1", sortOrder: 0)
        entry.summaryPromptIdOverride = doomed.id
        context.insert(entry)

        SummarizationPromptSeeder.collapseDuplicates(context: context)

        #expect(summary.promptId == keeper.id, "a summary's provenance must survive the collapse")
        #expect(collection.summaryPromptId == keeper.id,
                "a collection's default prompt must not be left dangling")
        #expect(entry.summaryPromptIdOverride == keeper.id,
                "a per-entry override must not be left dangling")
    }

    /// A referrer pointing at an unrelated prompt must be left alone — the remap is keyed on the
    /// doomed ids, not applied wholesale.
    @Test("Unrelated references are untouched")
    func unrelatedReferencesSurvive() throws {
        let container = try container()
        let context = container.mainContext
        let keeper = prompt("Standard Summary", createdAt: Date(timeIntervalSince1970: 100))
        let doomed = prompt("Standard Summary", createdAt: Date(timeIntervalSince1970: 900))
        let other = prompt("Key Points", createdAt: Date(timeIntervalSince1970: 100))
        [keeper, doomed, other].forEach(context.insert)

        let summary = GeneratedSummary(documentId: "d1", volumeId: "v1", promptId: other.id,
                                       responseText: "t", responseFormat: .general)
        context.insert(summary)

        SummarizationPromptSeeder.collapseDuplicates(context: context)
        #expect(summary.promptId == other.id)
    }

    // MARK: - It runs after import, not only at boot

    /// The whole point of the change: seeding runs inside boot, the CloudKit import lands after it,
    /// so the collapse has to be reachable from the post-import debounce as well.
    @Test("The collapse is wired into the post-import debounce")
    func wiredIntoPostImportDebounce() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let app = try String(contentsOf: root.appending(path: "FRUSExplorer/App/FRUSExplorerApp.swift"),
                             encoding: .utf8)
        #expect(app.contains("SummarizationPromptSeeder.collapseDuplicates("),
                """
                The collapse must run from the debounced post-import block. Seeding runs once inside \
                boot, before the CloudKit import exists, so a boot-only collapse leaves a second \
                device showing 16 prompts until its next cold launch.
                """)
        // Beside its two neighbours, which exist for the same reason.
        #expect(app.contains("OrphanedTagRepair.run(context: modelContainer.mainContext)"))
    }
}
