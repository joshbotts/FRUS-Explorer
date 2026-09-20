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

// MARK: - StandardPromptRefreshTests (#1329)

/// Carrying a reworded standard template onto rows that were seeded before it (#1329).
///
/// ## The shape of the bug
/// `seed(in:)` skips a template whose NAME is already present and never reads what the row says,
/// so editing a template literal reached a fresh install and nothing else — generation runs the
/// stored row, not the literal. Three templates asked the on-device model for a person's OFFICE,
/// and on the 266 of 553 volumes that publish no list of persons nothing on the device can
/// corroborate one; rewording them would have left every existing install asking for it anyway.
///
/// ## What these guard
/// Four things, in descending order of how quietly they would break. That the refresh compares
/// the SCHEMA and not only the prose — three of the office asks were structured field
/// descriptions, which are stored on the row and reach the model verbatim. That it stamps
/// `lastModified`, because the model's `didSet` observers never fire and a device still on the old
/// wording would otherwise win the CloudKit merge and put the stale text back. That it leaves a
/// reader's own prompt alone. And that the reworded templates actually say what the issue asked
/// for, which no mechanism test can see.
///
/// Version history:
///   1.0 — #1329: initial implementation
@Suite("Standard prompt refresh (#1329)")
@MainActor
struct StandardPromptRefreshTests {

    private func container() throws -> ModelContainer {
        try ModelContainer.makeTestContainer()
    }

    /// The template a test refreshes against, looked up by the name the seeder keys on.
    private func template(_ name: String) throws -> PromptTemplate {
        try #require(SummarizationPromptSeeder.standardTemplates.first { $0.name == name },
                     """
                     No standard template is named \(name). The name is the only key the seeder, \
                     the collapse and the refresh have; renaming one strands every seeded row.
                     """)
    }

    private func standardRow(named name: String,
                             promptText: String,
                             responseFormat: ResponseFormat = .general,
                             schema: StructuredSummarySchema? = nil) -> SummarizationPrompt {
        SummarizationPrompt(name: name, promptText: promptText,
                            responseFormat: responseFormat, isStandard: true, schema: schema)
    }

    // MARK: - The prose

    @Test("A standard row seeded with older wording is rewritten")
    func staleTextIsRefreshed() throws {
        let container = try container()
        let context = container.mainContext
        let general = try template("Standard Summary")
        let row = standardRow(named: general.name, promptText: "Identify who is involved.")
        context.insert(row)

        #expect(SummarizationPromptSeeder.refreshStandardPrompts(context: context) == 1)
        #expect(row.promptText == general.promptText, """
            The row still says: \(row.promptText)
            Editing the literal reaches only fresh installs unless the refresh rewrites the row.
            """)
    }

    /// The test that kills a `promptText`-only implementation. Three of the seven office asks were
    /// structured FIELD DESCRIPTIONS, stored on the row and handed to the model verbatim, so a
    /// refresh that compared only the prose would ship the reworded prompt beside a schema still
    /// asking for an official capacity.
    @Test("A stale schema is refreshed even when the prose already matches")
    func staleSchemaIsRefreshed() throws {
        let container = try container()
        let context = container.mainContext
        let meeting = try template("Meeting Record")
        let staleSchema = StructuredSummarySchema(fields: [
            .init(name: "KeyParticipants", description: "Principal speakers and their official capacity"),
        ])
        let row = standardRow(named: meeting.name,
                              promptText: meeting.promptText,            // prose ALREADY current
                              responseFormat: .structured(schema: staleSchema),
                              schema: staleSchema)
        context.insert(row)

        #expect(SummarizationPromptSeeder.refreshStandardPrompts(context: context) == 1)
        #expect(row.schema == meeting.schema, """
            The stored schema was not refreshed. Its field descriptions reach the model verbatim, \
            so a prose-only refresh leaves the office ask standing.
            """)
        #expect(row.responseFormat == meeting.responseFormat)
    }

    @Test("A row that already matches its template is not rewritten")
    func currentRowIsUntouched() throws {
        let container = try container()
        let context = container.mainContext
        let general = try template("Standard Summary")
        context.insert(standardRow(named: general.name, promptText: general.promptText))

        #expect(SummarizationPromptSeeder.refreshStandardPrompts(context: context) == 0)
    }

    /// A refresh writes through CloudKit, so it must be idempotent: a second run on a settled store
    /// writes nothing, and the boot pass and the post-import pass both run on every launch.
    @Test("A second run writes nothing")
    func refreshIsIdempotent() throws {
        let container = try container()
        let context = container.mainContext
        let general = try template("Standard Summary")
        context.insert(standardRow(named: general.name, promptText: "old"))

        #expect(SummarizationPromptSeeder.refreshStandardPrompts(context: context) == 1)
        #expect(SummarizationPromptSeeder.refreshStandardPrompts(context: context) == 0)
    }

    // MARK: - lastModified

    /// `SummarizationPrompt`'s five `didSet { lastModified = .now }` observers never fire — the
    /// `@Model` macro discards them — and the type is not a `LastModifiedStamping` conformer, so
    /// nothing else moves the field. Left frozen, a device still running the old wording wins the
    /// merge and the refresh silently undoes itself.
    @Test("The refresh stamps lastModified, because nothing else will")
    func refreshStampsLastModified() throws {
        let container = try container()
        let context = container.mainContext
        let general = try template("Standard Summary")
        let row = standardRow(named: general.name, promptText: "old")
        let frozen = Date(timeIntervalSince1970: 1_000)
        row.lastModified = frozen
        context.insert(row)

        SummarizationPromptSeeder.refreshStandardPrompts(context: context)
        let stamped = try #require(row.lastModified)
        #expect(stamped > frozen, """
            lastModified is still \(stamped). CloudKit resolves this row last-writer-wins on that \
            field, so a frozen stamp lets a device on the old wording overwrite the refresh.
            """)
    }

    // MARK: - What it must not touch

    /// The mirror of `userPromptsAreSafe`: a reader's own prompt may share a name with a standard
    /// one, and rewriting it would replace wording they chose with wording the app chose.
    @Test("A reader's own prompt sharing a name is never rewritten")
    func userPromptIsNeverRefreshed() throws {
        let container = try container()
        let context = container.mainContext
        let general = try template("Standard Summary")
        let mine = SummarizationPrompt(name: general.name, promptText: "mine",
                                       responseFormat: .general, isStandard: false)
        context.insert(mine)

        #expect(SummarizationPromptSeeder.refreshStandardPrompts(context: context) == 0)
        #expect(mine.promptText == "mine")
    }

    /// A standard row from a release whose template has since been renamed or retired has no
    /// template to be refreshed against, and must be left as it is rather than matched loosely.
    @Test("A standard row matching no template is left alone")
    func unknownStandardRowIsLeftAlone() throws {
        let container = try container()
        let context = container.mainContext
        let orphan = standardRow(named: "Retired Template", promptText: "old")
        context.insert(orphan)

        #expect(SummarizationPromptSeeder.refreshStandardPrompts(context: context) == 0)
        #expect(orphan.promptText == "old")
    }

    // MARK: - End to end, and the wiring

    /// The defect's actual shape: a store that already holds all eight rows, seeded under older
    /// wording. `seed` used to skip every one of them by name and return "nothing to do".
    @Test("seed carries a reworded template onto a row it would otherwise skip")
    func seedRefreshesExistingRows() throws {
        let container = try container()
        let context = container.mainContext
        for template in SummarizationPromptSeeder.standardTemplates {
            context.insert(standardRow(named: template.name, promptText: "seeded under old wording"))
        }
        try context.save()

        SummarizationPromptSeeder.seed(in: container)

        let rows = try container.mainContext.fetch(FetchDescriptor<SummarizationPrompt>())
        #expect(rows.count == SummarizationPromptSeeder.standardTemplates.count, """
            \(rows.count) rows after seeding \(SummarizationPromptSeeder.standardTemplates.count) \
            templates — the refresh must not insert.
            """)
        for template in SummarizationPromptSeeder.standardTemplates {
            let row = try #require(rows.first { $0.name == template.name })
            #expect(row.promptText == template.promptText, """
                \(template.name) still says: \(row.promptText)
                """)
        }
    }

    /// Boot's pass cannot see the rows a second device is about to receive: seeding runs once
    /// inside boot and SwiftData's CloudKit import lands after it, carrying the first device's rows
    /// under their older wording. Same debounce, same reason as the collapse beside it.
    @Test("The refresh is wired into the post-import debounce")
    func wiredIntoPostImportDebounce() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let app = try String(contentsOf: root.appending(path: "FRUSExplorer/App/FRUSExplorerApp.swift"),
                             encoding: .utf8)
        #expect(app.contains("SummarizationPromptSeeder.refreshStandardPrompts("), """
            The refresh must run from the debounced post-import block. A boot-only refresh leaves \
            a second device on the wording the import just delivered until its next cold launch.
            """)
    }

    // MARK: - What the templates say

    /// The mechanism tests above would pass just as well on the wording #1329 was filed about, so
    /// this is the one that pins the change itself: every template that asks the model about a
    /// person must tie the answer to the document in front of it.
    @Test("Every template that asks about a person constrains the answer to the document")
    func peopleTemplatesAreConstrainedToTheDocument() throws {
        let markers = ["as the document names them", "the document gives them",
                       "the document states", "the document presents them",
                       "does not state", "does not give"]
        var checked = 0
        for name in ["Standard Summary", "Meeting Record", "Diplomatic Exchange",
                     "Individual Role Trace"] {
            let template = try self.template(name)
            let whole = ([template.promptText] + template.fields.map(\.description)).joined(separator: "\n")
            #expect(markers.contains(where: whole.contains), """
                \(name) asks the model about people without tying the answer to the document:
                \(whole)
                """)
            checked += 1
        }
        #expect(checked == 4)
    }

    /// The three asks #1329 names, spelled as they shipped, so a revert is loud. Two of the three
    /// are field descriptions — the half a prose-only reading of the issue would have missed.
    @Test("No template asks for an office the document need not have stated")
    func noTemplateAsksForAnUnsourcedOffice() {
        let retired = [
            "Principal speakers and their official capacity",
            "Sending and receiving parties, including their governments and positions",
            "The individual's role or official capacity in this document",
            "Identify the key participants and their roles",
            "Describe the capacity in which they appear",
        ]
        for template in SummarizationPromptSeeder.standardTemplates {
            let whole = ([template.promptText] + template.fields.map(\.description)).joined(separator: "\n")
            for phrase in retired {
                #expect(!whole.contains(phrase), """
                    \(template.name) carries the retired phrase: \(phrase)
                    It asks the on-device model for an office the document need not print, and on \
                    the 266 volumes with no list of persons nothing here can check one.
                    """)
            }
        }
    }
}
