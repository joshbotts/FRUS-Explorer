// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData
import Testing
@testable import FRUSExplorer

// MARK: - HistoryPaneSnapshotTests

/// Pins the reading half of the research trail — the data ``HistoryView`` renders on both
/// platforms (Wave R-3).
///
/// ## What is worth pinning here, and why
/// Three of these tests exist because the thing they check **cannot fail at compile time**:
///
/// 1. **The scope predicates translate.** `HistoryScope` pushes its project filter into a
///    `#Predicate` rather than filtering after the fetch, which is what makes a bounded page
///    correct rather than a global page that the scope mostly throws away. SwiftData translates
///    predicates at *runtime*; a form it cannot handle throws or traps when the fetch runs, not
///    when the file compiles. `ProjectEngagedDocuments` establishes that scalar `==` on
///    `projectId` works, but the `== nil` form used for "Not in a Project" had no precedent in
///    this codebase before R-3.
/// 2. **`fetchCount` ignores the page limit.** The snapshot builds separate descriptors for the
///    page and the count precisely because `fetchCount` honours `fetchLimit` — reuse the page
///    descriptor and the total equals the page size, "Show More" never appears, and the view
///    silently claims a truncated list is the whole trail.
/// 3. **Per-entry delete reaches `SearchHistoryEntry`.** Before R-3 there was no delete path for
///    that type anywhere in the app.
///
/// Version history:
///   1.0 — Wave R-3: initial implementation
///   1.1 — Wave R-2a review fixes: same-`id` rows get distinct identities and a delete that
///          removes every copy, and the export table is loaded, scoped, filtered and deletable
///          like the other two
@MainActor
struct HistoryPaneSnapshotTests {

    // MARK: - Fixtures

    /// Inserts a document visit. Returns the entry so a test can read its id.
    ///
    /// `accessedAt` is stamped by the initialiser, so ordering fixtures are written by
    /// overwriting it afterwards — the field is `var` and the model is not immutable in the
    /// SwiftData sense, only by convention.
    @discardableResult
    private func insertVisit(_ context: ModelContext,
                             documentId: String = "d1",
                             volumeId: String = "frus1969-76v01",
                             title: String? = nil,
                             projectId: UUID? = nil,
                             accessedAt: Date? = nil) -> ReadingHistoryEntry {
        let entry = ReadingHistoryEntry(documentId: documentId,
                                        volumeId: volumeId,
                                        displayTitle: title,
                                        projectId: projectId)
        if let accessedAt { entry.accessedAt = accessedAt }
        context.insert(entry)
        return entry
    }

    @discardableResult
    private func insertSearch(_ context: ModelContext,
                              query: String = "détente",
                              resultCount: Int = 3,
                              projectId: UUID? = nil,
                              executedAt: Date? = nil) -> SearchHistoryEntry {
        let entry = SearchHistoryEntry(queryText: query,
                                       resultCount: resultCount,
                                       projectId: projectId)
        if let executedAt { entry.executedAt = executedAt }
        context.insert(entry)
        return entry
    }

    // MARK: - Scope, as a pure function

    /// The in-memory mirror. Cheap, but it is the thing the fetch predicates have to agree with.
    @Test("HistoryScope matches the projects it says it does")
    func scopeMatchesInMemory() {
        let a = UUID(), b = UUID()

        #expect(HistoryScope.all.matches(nil))
        #expect(HistoryScope.all.matches(a))

        #expect(HistoryScope.unfiled.matches(nil))
        #expect(HistoryScope.unfiled.matches(a) == false)

        #expect(HistoryScope.project(a).matches(a))
        #expect(HistoryScope.project(a).matches(b) == false)
        // The case that a sentinel-UUID design gets wrong: an unfiled entry must NOT fall into
        // some project's bucket just because "no project" was encoded as a UUID.
        #expect(HistoryScope.project(a).matches(nil) == false)
    }

    // MARK: - Scope, in the fetch

    /// **The test that could only fail at runtime.** Each scope's `#Predicate` has to survive
    /// SwiftData's translation and return the same rows `matches(_:)` would.
    @Test("Each scope's fetch predicate returns exactly the entries its in-memory mirror accepts")
    func scopePredicatesAgreeWithTheirMirror() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let projectA = UUID(), projectB = UUID()

        insertVisit(context, documentId: "d1", projectId: projectA)
        insertVisit(context, documentId: "d2", projectId: projectB)
        insertVisit(context, documentId: "d3", projectId: nil)
        insertSearch(context, query: "berlin", projectId: projectA)
        insertSearch(context, query: "cuba", projectId: nil)
        try context.save()

        let all = HistoryPaneSnapshot.fetch(from: context, scope: .all)
        #expect(all.totalDocuments == 3)
        #expect(all.totalSearches == 2)

        // `== nil` inside a #Predicate — the form with no precedent in this codebase before R-3.
        let unfiled = HistoryPaneSnapshot.fetch(from: context, scope: .unfiled)
        #expect(unfiled.documents.map(\.documentId) == ["d3"])
        #expect(unfiled.searches.map(\.queryText) == ["cuba"])
        #expect(unfiled.totalDocuments == 1)

        let scopedA = HistoryPaneSnapshot.fetch(from: context, scope: .project(projectA))
        #expect(scopedA.documents.map(\.documentId) == ["d1"])
        #expect(scopedA.searches.map(\.queryText) == ["berlin"])

        let scopedB = HistoryPaneSnapshot.fetch(from: context, scope: .project(projectB))
        #expect(scopedB.documents.map(\.documentId) == ["d2"])
        #expect(scopedB.searches.isEmpty)
    }

    /// Newest first, both sections — the order the view relies on and the reason the page limit
    /// is meaningful at all (a limit over an unsorted fetch would drop arbitrary rows).
    @Test("Both sections come back newest first")
    func rowsAreNewestFirst() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        insertVisit(context, documentId: "oldest", accessedAt: base)
        insertVisit(context, documentId: "newest", accessedAt: base.addingTimeInterval(600))
        insertVisit(context, documentId: "middle", accessedAt: base.addingTimeInterval(300))
        insertSearch(context, query: "old", executedAt: base)
        insertSearch(context, query: "new", executedAt: base.addingTimeInterval(600))
        try context.save()

        let snapshot = HistoryPaneSnapshot.fetch(from: context)
        #expect(snapshot.documents.map(\.documentId) == ["newest", "middle", "oldest"])
        #expect(snapshot.searches.map(\.queryText) == ["new", "old"])
    }

    // MARK: - The page limit

    /// The bounded fetch caps the rows **and** reports the honest total, so the view can say
    /// "Showing 2 of 5" rather than implying the page is everything.
    ///
    /// This is the assertion that catches a "simplification" to one shared descriptor:
    /// `fetchCount` honours `fetchLimit`, so a reused descriptor would make `totalDocuments`
    /// equal `documents.count`, `hasMoreDocuments` permanently false, and "Show More" invisible.
    @Test("The page limit caps the rows but not the reported total")
    func pageLimitCapsRowsNotTheTotal() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        for i in 0..<5 {
            insertVisit(context, documentId: "d\(i)",
                        accessedAt: base.addingTimeInterval(Double(i)))
            insertSearch(context, query: "q\(i)",
                         executedAt: base.addingTimeInterval(Double(i)))
        }
        try context.save()

        let page = HistoryPaneSnapshot.fetch(from: context, limit: 2)
        #expect(page.documents.count == 2)
        #expect(page.searches.count == 2)
        #expect(page.totalDocuments == 5)
        #expect(page.totalSearches == 5)
        #expect(page.hasMoreDocuments)
        #expect(page.hasMoreSearches)
        // Newest survive the cut, oldest are the ones left behind.
        #expect(page.documents.map(\.documentId) == ["d4", "d3"])

        let wider = HistoryPaneSnapshot.fetch(from: context, limit: 100)
        #expect(wider.documents.count == 5)
        #expect(wider.hasMoreDocuments == false)
        #expect(wider.hasMoreSearches == false)
    }

    /// The count is scoped too: "Showing 2 of 5" must mean five *in this scope*, not five in the
    /// whole store, or the reader is told rows exist that the picker will never show them.
    @Test("The reported total respects the scope, not just the page")
    func totalIsScoped() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let project = UUID()

        for i in 0..<4 { insertVisit(context, documentId: "global\(i)") }
        for i in 0..<2 { insertVisit(context, documentId: "scoped\(i)", projectId: project) }
        try context.save()

        let scoped = HistoryPaneSnapshot.fetch(from: context, scope: .project(project), limit: 1)
        #expect(scoped.documents.count == 1)
        #expect(scoped.totalDocuments == 2)      // not 6
        #expect(scoped.hasMoreDocuments)
    }

    // MARK: - Row shaping

    /// Pre-1.1 entries carry no captured title and fall back to `"volumeId · documentId"` —
    /// the same fallback the macOS window drew before R-3 (F-021).
    @Test("A row with no captured title falls back to volume and document ids")
    func titleFallsBackForLegacyRows() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext

        insertVisit(context, documentId: "d7", volumeId: "frus1969-76v01", title: nil)
        insertVisit(context, documentId: "d8", volumeId: "frus1969-76v01", title: "Memorandum")
        try context.save()

        let snapshot = HistoryPaneSnapshot.fetch(from: context)
        let byId = Dictionary(uniqueKeysWithValues: snapshot.documents.map { ($0.documentId, $0) })
        #expect(byId["d7"]?.title == "frus1969-76v01 · d7")
        #expect(byId["d8"]?.title == "Memorandum")
    }

    /// The free-text filter reaches the title and both identifiers, so a reader who remembers
    /// only the volume id still finds the visit.
    @Test("The document filter matches title, volume id, and document id")
    func documentFilterMatchesEveryDisplayedField() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext

        insertVisit(context, documentId: "d42", volumeId: "frus1969-76v01", title: "Berlin Crisis")
        insertVisit(context, documentId: "d99", volumeId: "frus1952-54v08", title: "Suez")
        try context.save()

        let snapshot = HistoryPaneSnapshot.fetch(from: context)
        #expect(snapshot.filteredDocuments(matching: "berlin").map(\.documentId) == ["d42"])
        #expect(snapshot.filteredDocuments(matching: "1952-54").map(\.documentId) == ["d99"])
        #expect(snapshot.filteredDocuments(matching: "d42").map(\.documentId) == ["d42"])
        // Empty and whitespace-only terms are not filters.
        #expect(snapshot.filteredDocuments(matching: "").count == 2)
        #expect(snapshot.filteredDocuments(matching: "   ").count == 2)
    }

    /// The search filter reads the query text — the field whose presence in a synced store is
    /// the reason per-entry delete had to ship with this view.
    @Test("The search filter matches query text")
    func searchFilterMatchesQueryText() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext

        insertSearch(context, query: "Berlin blockade")
        insertSearch(context, query: "Suez")
        try context.save()

        let snapshot = HistoryPaneSnapshot.fetch(from: context)
        #expect(snapshot.filteredSearches(matching: "blockade").map(\.queryText) == ["Berlin blockade"])
        #expect(snapshot.filteredSearches(matching: "zzz").isEmpty)
    }

    // MARK: - Copy

    /// "Showing N of M" appears only when the page is smaller than the scope, so a complete list
    /// does not carry a redundant "Showing 12 of 12".
    @Test("The showing-count line is omitted when the page is everything")
    func showingCountIsOmittedWhenComplete() {
        #expect(HistoryPaneSnapshot.showingCount(shown: 12, of: 12) == nil)
        #expect(HistoryPaneSnapshot.showingCount(shown: 13, of: 12) == nil)
        #expect(HistoryPaneSnapshot.showingCount(shown: 2, of: 5) == "Showing 2 of 5")
    }

    // MARK: - Deletion

    /// **The gap this closes.** `SearchHistoryEntry` had no delete path anywhere in the app: the
    /// app recorded the user's search text, mirrored it to their iCloud private database, and
    /// offered no way to remove it.
    @Test("Deleting a search removes exactly that entry")
    func deletingASearchRemovesOnlyIt() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext

        let keep = insertSearch(context, query: "keep me")
        let drop = insertSearch(context, query: "delete me")
        try context.save()

        #expect(HistoryTrailAdmin.deleteSearch(id: drop.id, in: context))

        let remaining = try context.fetch(FetchDescriptor<SearchHistoryEntry>())
        #expect(remaining.map(\.id) == [keep.id])
    }

    @Test("Deleting a document visit removes exactly that entry")
    func deletingAVisitRemovesOnlyIt() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext

        let keep = insertVisit(context, documentId: "keep")
        let drop = insertVisit(context, documentId: "drop")
        try context.save()

        #expect(HistoryTrailAdmin.deleteDocumentVisit(id: drop.id, in: context))

        let remaining = try context.fetch(FetchDescriptor<ReadingHistoryEntry>())
        #expect(remaining.map(\.documentId) == [keep.documentId])
        #expect(remaining.first?.id == keep.id)
    }

    /// A delete of something already gone reports `false` rather than pretending it worked —
    /// which is how the view knows its snapshot is stale and re-reads instead of leaving a
    /// phantom row on screen.
    @Test("Deleting an entry that no longer exists reports failure")
    func deletingAMissingEntryReportsFailure() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext

        #expect(HistoryTrailAdmin.deleteSearch(id: UUID(), in: context) == false)
        #expect(HistoryTrailAdmin.deleteDocumentVisit(id: UUID(), in: context) == false)
    }

    /// Deleting is visible to the next snapshot, including in the reported total — the view
    /// re-reads after every delete and would otherwise keep claiming the row exists.
    @Test("A deleted entry is gone from the next snapshot and its total")
    func deleteIsVisibleToTheNextSnapshot() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext

        insertVisit(context, documentId: "stays")
        let doomed = insertVisit(context, documentId: "goes")
        try context.save()

        #expect(HistoryPaneSnapshot.fetch(from: context).totalDocuments == 2)
        HistoryTrailAdmin.deleteDocumentVisit(id: doomed.id, in: context)

        let after = HistoryPaneSnapshot.fetch(from: context)
        #expect(after.totalDocuments == 1)
        #expect(after.documents.map(\.documentId) == ["stays"])
    }

    // MARK: - Empty store

    /// A fresh install: no rows, no totals, nothing claiming to be truncated.
    @Test("An empty store produces an empty snapshot with nothing hidden")
    func emptyStoreIsEmpty() throws {
        let container = try ModelContainer.makeTestContainer()
        let snapshot = HistoryPaneSnapshot.fetch(from: container.mainContext)

        #expect(snapshot.isEmpty)
        #expect(snapshot.documents.isEmpty)
        #expect(snapshot.searches.isEmpty)
        #expect(snapshot.hasMoreDocuments == false)
        #expect(snapshot.hasMoreSearches == false)
        #expect(HistoryPaneSnapshot.empty.isEmpty)
    }

    /// The scope picker's options come from the same fetch, so a project created in another
    /// window appears in the picker on the next refresh.
    @Test("Projects are carried for the scope picker, sorted by name")
    func projectsArePresentAndSorted() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext

        context.insert(Project(name: "Zanzibar"))
        context.insert(Project(name: "Berlin"))
        try context.save()

        let snapshot = HistoryPaneSnapshot.fetch(from: context)
        #expect(snapshot.projects.map(\.name) == ["Berlin", "Zanzibar"])
    }

    // MARK: - Same-id duplicates

    /// **The mitigation that broke its own premise.** `ResearchTrailMigration` accepts a residual
    /// where two devices write a row carrying the same `id`, on the grounds that the duplicate is
    /// "visible and individually deletable". It was neither: `ForEach(visibleSearches)` put two
    /// elements under one `Identifiable` id — SwiftUI's documented-undefined case — and
    /// `deleteSearch` re-fetched with `fetchLimit = 1`, so the swipe reported success and left the
    /// row on screen.
    ///
    /// Half one: every loaded row has a distinct identity, whatever the entries' ids are.
    @Test("Two entries sharing an id become two distinctly identified rows")
    func sameIdEntriesGetDistinctRowIdentities() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let shared = UUID()

        let base = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(SearchHistoryEntry(id: shared, queryText: "détente", resultCount: 4,
                                          executedAt: base))
        context.insert(SearchHistoryEntry(id: shared, queryText: "détente", resultCount: 4,
                                          executedAt: base))
        let visit = insertVisit(context, documentId: "d1")
        let twin = ReadingHistoryEntry(documentId: "d1", volumeId: "frus1969-76v01")
        twin.id = visit.id
        context.insert(twin)
        try context.save()

        let snapshot = HistoryPaneSnapshot.fetch(from: context)
        #expect(snapshot.searches.count == 2)
        #expect(Set(snapshot.searches.map(\.id)).count == 2, "ForEach needs two distinct ids")
        #expect(snapshot.searches.allSatisfy { $0.entryID == shared })
        #expect(snapshot.documents.count == 2)
        #expect(Set(snapshot.documents.map(\.id)).count == 2)
    }

    /// Half two: the delete removes every copy, so the swipe does what it says. They are identical
    /// rows standing for one recorded thing.
    @Test("Deleting a duplicated entry removes every copy")
    func deletingADuplicatedEntryRemovesEveryCopy() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let shared = UUID()

        context.insert(SearchHistoryEntry(id: shared, queryText: "détente", resultCount: 4))
        context.insert(SearchHistoryEntry(id: shared, queryText: "détente", resultCount: 4))
        let survivor = insertSearch(context, query: "Berlin")
        try context.save()

        #expect(HistoryTrailAdmin.deleteSearch(id: shared, in: context))
        let remaining = try context.fetch(FetchDescriptor<SearchHistoryEntry>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.id == survivor.id)
        #expect(HistoryPaneSnapshot.fetch(from: context).searches.count == 1)
    }

    // MARK: - Exports

    /// The third trail type was not loaded here at all, which is what made "individually
    /// deletable" untrue of it. Rows, totals, scope and delete now behave like the other two.
    @Test("Exports are loaded, scoped, counted and deletable")
    func exportsAreLoadedScopedAndDeletable() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let project = UUID()
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        let scoped = ExportHistoryEntry(format: "pdf", documentCount: 12,
                                        collectionName: "Détente Reader",
                                        projectId: project, exportedAt: base)
        context.insert(scoped)
        context.insert(ExportHistoryEntry(format: "zotero-api", documentCount: 3,
                                          exportedAt: base.addingTimeInterval(60)))
        try context.save()

        let all = HistoryPaneSnapshot.fetch(from: context)
        #expect(all.totalExports == 2)
        #expect(all.exports.map(\.documentCount) == [3, 12], "newest first")
        #expect(all.isEmpty == false, "a store with only exports is not an empty trail")

        let scopedSnapshot = HistoryPaneSnapshot.fetch(from: context, scope: .project(project))
        #expect(scopedSnapshot.exports.map(\.entryID) == [scoped.id])
        let unfiled = HistoryPaneSnapshot.fetch(from: context, scope: .unfiled)
        #expect(unfiled.exports.map(\.format) == ["zotero-api"])

        #expect(HistoryTrailAdmin.deleteExport(id: scoped.id, in: context))
        #expect(HistoryPaneSnapshot.fetch(from: context).totalExports == 1)
        #expect(HistoryTrailAdmin.deleteExport(id: UUID(), in: context) == false)
    }

    /// The export row's copy: a collection name when one was recorded, the format's own wording
    /// when not — which is every row the migration produced, since the legacy payload carried no
    /// name. And the filter reaches both spellings of the format.
    @Test("An export row titles itself and filters on name and format")
    func exportRowCopyAndFilter() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext

        let base = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(ExportHistoryEntry(format: "pdf", documentCount: 12,
                                          collectionName: "Détente Reader", exportedAt: base))
        context.insert(ExportHistoryEntry(format: "zotero-api", documentCount: 3,
                                          exportedAt: base.addingTimeInterval(60)))
        try context.save()

        let snapshot = HistoryPaneSnapshot.fetch(from: context)
        let named = try #require(snapshot.exports.first { $0.format == "pdf" })
        let migrated = try #require(snapshot.exports.first { $0.format == "zotero-api" })
        #expect(named.title == "Détente Reader")
        #expect(named.formatDisplayName == "PDF")
        #expect(migrated.collectionName == nil)
        #expect(migrated.title == "Zotero (web)", "no name recorded, so the format is the title")

        #expect(snapshot.filteredExports(matching: "détente").map(\.format) == ["pdf"])
        #expect(snapshot.filteredExports(matching: "PDF").map(\.format) == ["pdf"])
        #expect(snapshot.filteredExports(matching: "zotero").map(\.format) == ["zotero-api"])
        #expect(snapshot.filteredExports(matching: "").count == 2)
    }
}
