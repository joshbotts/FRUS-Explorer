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

/// "Erase Everything" must account for every enrolled `@Model` (#746).
///
/// ## Why this suite exists
/// The reset delete list fell behind the schema **twice**. Wave R-2a found it reaching
/// `ReadingHistoryEntry` alone and extended it for the research trail; the 2026-08 navigation and
/// state audit then found five more CloudKit-synced user-data types surviving a double-confirmed
/// erase — `SavedSearch` and `PersonClusterOverride`, which had never been in the list, plus
/// `CustomVolumeScope` (#258), `ProjectLeadEntry` (#377) and `WorkingCorpus` (M-1), each enrolled
/// in `frusModelTypes` long after anyone last read the reset function.
///
/// Reviewers cannot hold two hand-written lists in agreement across files, so this suite makes the
/// schema itself the authority: **the union of erased and deliberately-retained must equal
/// `frusModelTypes` exactly.** Add a `@Model` without deciding its reset fate and the suite fails
/// naming the type.
///
/// The comparison is deliberately made on `frusModelTypes` — the same list
/// `ModelContainer+FRUS` hands to `Schema(...)` and `CloudKitSchemaInventoryTests` pins — and not
/// on a copy, so this cannot pass against a mirror that has itself drifted.
///
/// Version history:
///   1.0 — Session 2026-08-08: #746
@MainActor
@Suite("Reset inventory")
struct ResetInventoryTests {

    private var enrolledNames: Set<String> {
        Set(ModelContainer.frusModelTypes.map { String(describing: $0) })
    }

    // MARK: - The coverage contract

    @Test("Every enrolled model type is either erased or deliberately retained")
    func everyModelTypeIsAccountedFor() {
        let erased = Set(ResetInventory.erasedNames)
        let retained = Set(ResetInventory.retainedNames)
        let accounted = erased.union(retained)

        let unaccounted = enrolledNames.subtracting(accounted)
        #expect(unaccounted.isEmpty, """
            These @Model types are enrolled in frusModelTypes but "Erase Everything" neither \
            deletes nor deliberately retains them: \(unaccounted.sorted().joined(separator: ", ")).
            Add each to ResetInventory.erased (with a reason if its delete order matters) or to \
            ResetInventory.deliberatelyRetained (with the reason it survives a reset).
            """)
    }

    @Test("Nothing is listed for deletion that the schema does not enrol")
    func noPhantomEntries() {
        let listed = Set(ResetInventory.erasedNames).union(ResetInventory.retainedNames)
        let phantom = listed.subtracting(enrolledNames)
        #expect(phantom.isEmpty, """
            ResetInventory names types that are not in frusModelTypes: \
            \(phantom.sorted().joined(separator: ", ")). A retired model must leave both lists, \
            or the reset will try to delete a type the container does not know.
            """)
    }

    @Test("The two lists are disjoint and free of duplicates")
    func listsAreWellFormed() {
        let erased = ResetInventory.erasedNames
        let retained = ResetInventory.retainedNames
        #expect(Set(erased).count == erased.count, "duplicate in erased: \(erased)")
        #expect(Set(retained).count == retained.count, "duplicate in retained: \(retained)")
        #expect(Set(erased).isDisjoint(with: Set(retained)),
                "a type cannot be both erased and retained")
    }

    // MARK: - The types the audit found surviving

    @Test("The five types #746 found alive after a reset are now erased")
    func theFiveAuditFindingsAreErased() {
        // Named individually rather than counted: a count assertion passes when someone swaps one
        // type for another, and these five are the specific user-data types — saved queries,
        // captured result sets, custom scopes, person corrections, project leads — that a
        // double-confirmed erase left on the user's devices AND in their iCloud account.
        for name in ["SavedSearch", "PersonClusterOverride", "CustomVolumeScope",
                     "WorkingCorpus", "ProjectLeadEntry"] {
            #expect(ResetInventory.erasedNames.contains(name),
                    "\(name) must be deleted by Erase Everything (#746)")
        }
    }

    @Test("The research trail stays erased — Wave R-2a's fix is not regressed")
    func researchTrailStaysErased() {
        for name in ["ReadingHistoryEntry", "SearchHistoryEntry", "ExportHistoryEntry",
                     "SessionEvent", "ResearchSession"] {
            #expect(ResetInventory.erasedNames.contains(name),
                    "\(name) must stay in the reset list (Wave R-2a)")
        }
    }

    @Test("SyncedPreferences is retained, and that is the only retention")
    func onlyDeliberateRetention() {
        // If this ever grows, the erase screen's copy must grow with it — the screen promises the
        // app "returns to onboarding as if newly installed", and every retained type is a
        // qualification on that promise.
        #expect(ResetInventory.retainedNames == ["SyncedPreferences"])
    }

    // MARK: - Delete order

    @Test("Dependents are deleted before the records they reference")
    func deleteOrderPutsDependentsFirst() {
        // The sequence is not transactional, so order decides what an interrupted reset leaves
        // behind: a harmless orphaned child, or a dangling reference to a deleted parent. Each
        // pair below is a documented scar, not a hypothetical.
        let order = ResetInventory.erasedNames
        func index(_ name: String) -> Int? { order.firstIndex(of: name) }

        let pairs: [(String, String, String)] = [
            // #406: OrphanedTagRepair resurrects deleted tags as "Recovered Tag" placeholders if
            // assignments outlive them.
            ("DocumentTagAssignment", "UserTag", "#406 orphaned-tag resurrection"),
            // Collection's delete rule is .nullify, not cascade.
            ("CollectionEntry", "Collection", ".nullify delete rule"),
            // Same .nullify reason, documented by ResearchSessionAdmin.
            ("SessionEvent", "ResearchSession", ".nullify delete rule"),
            // Raw-UUID references to Project — no @Relationship makes these structural, so only
            // the ordering protects them.
            ("ProjectLeadEntry", "Project", "ProjectLeadEntry.projectId is a raw UUID"),
            ("WorkingCorpus", "Project", "raw-UUID project reference"),
            ("SavedSearch", "Project", "raw-UUID project reference"),
        ]
        for (dependent, parent, why) in pairs {
            guard let d = index(dependent), let p = index(parent) else {
                Issue.record("\(dependent) or \(parent) missing from the erased list")
                continue
            }
            #expect(d < p, "\(dependent) must be deleted before \(parent) — \(why)")
        }
    }

    @Test("Project is deleted last, so nothing that references it outlives it")
    func projectIsLast() {
        #expect(ResetInventory.erasedNames.last == "Project")
    }

    // MARK: - The delete actually runs

    @Test("Erasing an in-memory store clears every erased type, including the five additions")
    func deletingEveryErasedTypeEmptiesTheStore() throws {
        // Drives `modelContext.delete(model:)` over the real inventory against a real container —
        // the same call `performReset` makes — so a type listed but undeletable (a schema the
        // container does not accept) fails here rather than at a user's reset.
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: Schema(ModelContainer.frusModelTypes), configurations: config)
        let context = container.mainContext

        context.insert(SavedSearch(name: "Berlin 1961", parameters: SearchParameters(keywords: "berlin")))
        context.insert(CustomVolumeScope(name: "Crisis volumes", volumeIds: ["frus1961-63v14"]))
        context.insert(UserTag(name: "to read"))
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<SavedSearch>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<CustomVolumeScope>()) == 1)

        for modelType in ResetInventory.erased {
            try context.delete(model: modelType)
        }
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<SavedSearch>()) == 0,
                "SavedSearch survived the reset — the #746 regression")
        #expect(try context.fetchCount(FetchDescriptor<CustomVolumeScope>()) == 0,
                "CustomVolumeScope survived the reset — the #746 regression")
        #expect(try context.fetchCount(FetchDescriptor<UserTag>()) == 0)
        // Retained by decision, and the container must still hold it afterwards.
        #expect(try context.fetchCount(FetchDescriptor<SyncedPreferences>()) == 0,
                "no SyncedPreferences was inserted; this asserts the fetch itself still works")
    }

    // MARK: - performReset actually uses the inventory

    /// The wiring guard, in the style of `CodingStandardsAuditTests`: read the source.
    ///
    /// Every other test here proves `ResetInventory` is *complete*. None of them would notice if
    /// `performReset` stopped reading it and went back to spelling out its deletes — which is
    /// exactly how this defect was born, and would leave the whole suite passing while the reset
    /// silently drifted again. So this asserts the call site itself.
    @Test("performReset iterates ResetInventory and hard-codes no deletes of its own")
    func performResetIsWiredToTheInventory() throws {
        let settingsView = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Settings/SettingsView.swift")
        let source = try String(contentsOf: settingsView, encoding: .utf8)

        #expect(source.contains("for modelType in ResetInventory.erased"),
                "performReset must delete by iterating ResetInventory.erased")

        // No literal `delete(model: SomeType.self)` anywhere in the file — that is the shape the
        // inventory replaced. Comments mentioning the old calls are fine; code is not.
        let offenders = source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") else { return false }
                return trimmed.contains("delete(model:") && !trimmed.contains("modelType")
            }
        #expect(offenders.isEmpty, """
            SettingsView.swift hard-codes model deletes again — add the type to             ResetInventory instead: \(offenders.joined(separator: " | "))
            """)
    }
}
