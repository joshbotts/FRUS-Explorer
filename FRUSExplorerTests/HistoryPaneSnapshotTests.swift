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
///   1.2 — #1298 follow-up: the search filter folds typographic double quotation marks on both sides, so one row
///          refreshed by a curly and a straight run is found by a filter typed in either spelling
///   1.3 — #1361: a document row's caption names the document, and a stored title that is only its
///          volume's manifest title reads as no title — in the row, through the fetch, and in the
///          one-line label the History menu and Project Home draw. Review fixes: the identifier-pair
///          branch, `fetch` handed a `ManifestStore`, and the rule pinned at its three call sites
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

    /// The manifest for tests that are not about volume titles: it lists no volume, so no stored
    /// title is ever recognised as one (#1361).
    private var noManifest: ManifestStore { ManifestStore(bundledEntries: []) }

    /// A document row built directly, for the tests of what a row draws.
    private func documentRow(volumeId: String = "frus1961-63v11",
                             documentId: String = "d21",
                             displayTitle: String?,
                             volumeTitle: String?) -> HistoryPaneSnapshot.DocumentRow {
        HistoryPaneSnapshot.DocumentRow(id: HistoryRowID(entryID: UUID(), copy: 0),
                                        volumeId: volumeId,
                                        documentId: documentId,
                                        displayTitle: displayTitle,
                                        volumeTitle: volumeTitle,
                                        accessedAt: nil,
                                        projectId: nil)
    }

    /// The Cuban Missile Crisis volume's manifest title, which #1361 found stored as the title of
    /// every visit opened from a `frusexplorer://` link into it.
    private static let cubaVolumeTitle =
        "Foreign Relations of the United States, 1961–1963, Volume XI, Cuban Missile Crisis and Aftermath"

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

        let all = HistoryPaneSnapshot.fetch(from: context, scope: .all, manifest: noManifest)
        #expect(all.totalDocuments == 3)
        #expect(all.totalSearches == 2)

        // `== nil` inside a #Predicate — the form with no precedent in this codebase before R-3.
        let unfiled = HistoryPaneSnapshot.fetch(from: context, scope: .unfiled, manifest: noManifest)
        #expect(unfiled.documents.map(\.documentId) == ["d3"])
        #expect(unfiled.searches.map(\.queryText) == ["cuba"])
        #expect(unfiled.totalDocuments == 1)

        let scopedA = HistoryPaneSnapshot.fetch(from: context, scope: .project(projectA),
                                                manifest: noManifest)
        #expect(scopedA.documents.map(\.documentId) == ["d1"])
        #expect(scopedA.searches.map(\.queryText) == ["berlin"])

        let scopedB = HistoryPaneSnapshot.fetch(from: context, scope: .project(projectB),
                                                manifest: noManifest)
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

        let snapshot = HistoryPaneSnapshot.fetch(from: context, manifest: noManifest)
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

        let page = HistoryPaneSnapshot.fetch(from: context, limit: 2, manifest: noManifest)
        #expect(page.documents.count == 2)
        #expect(page.searches.count == 2)
        #expect(page.totalDocuments == 5)
        #expect(page.totalSearches == 5)
        #expect(page.hasMoreDocuments)
        #expect(page.hasMoreSearches)
        // Newest survive the cut, oldest are the ones left behind.
        #expect(page.documents.map(\.documentId) == ["d4", "d3"])

        let wider = HistoryPaneSnapshot.fetch(from: context, limit: 100, manifest: noManifest)
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

        let scoped = HistoryPaneSnapshot.fetch(from: context, scope: .project(project), limit: 1,
                                               manifest: noManifest)
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

        let snapshot = HistoryPaneSnapshot.fetch(from: context, manifest: noManifest)
        let byId = Dictionary(uniqueKeysWithValues: snapshot.documents.map { ($0.documentId, $0) })
        #expect(byId["d7"]?.title == "frus1969-76v01 · d7")
        #expect(byId["d8"]?.title == "Memorandum")
    }

    // MARK: - #1361: the row names the document

    /// **The row's second line names the document.** Before #1361 it drew the volume id alone, so
    /// three visits to one document and visits to three documents sharing a heading read the same
    /// except for the time, although `documentId` was loaded and the filter already matched on it.
    @Test("A titled row's caption is volume id · document id (#1361)")
    func captionNamesTheDocumentUnderATitle() {
        let heading = "21. Telegram From the Department of State to the Embassy in the Soviet Union"
        let row = documentRow(displayTitle: heading, volumeTitle: Self.cubaVolumeTitle)
        #expect(row.title == heading)
        #expect(row.caption == "frus1961-63v11 · d21")
        #expect(row.caption?.contains(row.documentId) == true)
    }

    /// **Two visits to documents sharing a heading are told apart by the caption.** The title line
    /// cannot do it, since it is the same heading.
    @Test("Rows sharing a heading differ in their captions (#1361)")
    func sharedHeadingsDifferInTheirCaptions() {
        let first = documentRow(documentId: "d4", displayTitle: "Editorial Note", volumeTitle: nil)
        let second = documentRow(documentId: "d9", displayTitle: "Editorial Note", volumeTitle: nil)
        #expect(first.title == second.title)
        #expect(first.caption != second.caption)
    }

    /// **A row whose title line already is the identifier pair draws no caption before the time**:
    /// the pair twice says nothing. One fixture per way a row reaches that fallback.
    @Test("A row titled by its identifiers draws them once, not twice (#1361)")
    func captionIsOmittedWhenTheTitleIsTheIdentifier() {
        let untitled = documentRow(displayTitle: nil, volumeTitle: Self.cubaVolumeTitle)
        #expect(untitled.title == "frus1961-63v11 · d21")
        #expect(untitled.caption == nil)

        let empty = documentRow(displayTitle: "", volumeTitle: Self.cubaVolumeTitle)
        #expect(empty.title == "frus1961-63v11 · d21")
        #expect(empty.caption == nil)

        let volumeTitled = documentRow(displayTitle: Self.cubaVolumeTitle, volumeTitle: Self.cubaVolumeTitle)
        #expect(volumeTitled.title == "frus1961-63v11 · d21")
        #expect(volumeTitled.caption == nil)

        // Stored as the pair itself — what a reopen from this list recorded for a headless document
        // or a failed macOS load before the writer refused it. Read as a title, it drew twice.
        let identifierTitled = documentRow(displayTitle: "frus1961-63v11 · d21", volumeTitle: Self.cubaVolumeTitle)
        #expect(identifierTitled.title == "frus1961-63v11 · d21")
        #expect(identifierTitled.caption == nil, "the identifier pair is drawn twice")
    }

    /// **The display-time rule, one fixture per branch.** A stored title that is exactly its
    /// volume's manifest title names the volume and is treated as absent; anything else stored is
    /// the document's title — including a title that merely BEGINS like its volume's, which is why
    /// the test is equality rather than a prefix or a fuzzy match; and a volume the manifest does
    /// not list has nothing to compare against, so its stored title stands.
    @Test("A stored title equal to its volume's manifest title is treated as absent (#1361)")
    func storedVolumeTitleIsTreatedAsAbsent() {
        let volume = Self.cubaVolumeTitle
        func read(_ stored: String?, _ volumeTitle: String?) -> String? {
            ReadingHistoryTitle.documentTitle(stored: stored, volumeTitle: volumeTitle,
                                              volumeId: "frus1961-63v11", documentId: "d21")
        }
        #expect(read(volume, volume) == nil)
        #expect(read("21. Telegram", volume) == "21. Telegram")
        #expect(read(volume + ", Part 2", volume) == volume + ", Part 2")
        #expect(read(volume, nil) == volume)
        #expect(read("", volume) == nil)
        #expect(read(nil, volume) == nil)
        #expect(ReadingHistoryTitle.identifier(volumeId: "frus1961-63v11", documentId: "d21")
                == "frus1961-63v11 · d21")
    }

    /// **The rule's other branch: a stored title that is the visit's own identifier pair is no
    /// title.** The History list reopens an untitled row with that pair as its header, and until the
    /// writer refused it a reopen with no parsed title stored it; a row read that way drew the pair
    /// as its title and again as its caption. Equality with the visit's OWN pair — another
    /// document's pair is stored text like any other — and with no manifest at all, so the
    /// volume-title branch cannot be what refuses it.
    @Test("A stored title equal to the visit's own identifier pair is treated as absent (#1361)")
    func storedIdentifierPairIsTreatedAsAbsent() {
        func read(_ stored: String?) -> String? {
            ReadingHistoryTitle.documentTitle(stored: stored, volumeTitle: nil,
                                              volumeId: "frus1961-63v11", documentId: "d21")
        }
        #expect(read("frus1961-63v11 · d21") == nil)
        #expect(read("frus1961-63v11 · d22") == "frus1961-63v11 · d22")
        #expect(read("frus1961-63v11") == "frus1961-63v11")
    }

    /// **Through the fetch, against the real manifest.** A visit written the way the
    /// `frusexplorer://` handler wrote them — its title is the manifest entry's own `title` — and
    /// read through the fetch `HistoryView` calls, handed the bundled manifest as `HistoryView` hands
    /// it `appState.manifestStore`. The volume-title lookup is the fetch's own, not a copy built
    /// here, so replacing it with one that answers nothing fails this test. The row falls back to
    /// its identifiers with no migration, while a visit stored under a real heading in the same
    /// volume keeps it — and the filter follows what is drawn, so the old volume title no longer
    /// finds the row.
    @Test("A visit stored under its volume's title reads by its identifiers, via the real manifest (#1361)")
    func fetchRecognisesAStoredVolumeTitle() throws {
        let manifest = ManifestStore()
        let volumeTitle = try #require(manifest.entry(forVolumeId: "frus1961-63v11")?.title)
        #expect(volumeTitle == Self.cubaVolumeTitle, "the manifest decodes its title whitespace-collapsed")

        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        insertVisit(context, documentId: "d21", volumeId: "frus1961-63v11", title: volumeTitle)
        let heading = "22. Telegram From the Department of State to the Embassy in the Soviet Union"
        insertVisit(context, documentId: "d22", volumeId: "frus1961-63v11", title: heading)
        try context.save()

        let snapshot = HistoryPaneSnapshot.fetch(from: context, manifest: manifest)
        let byId = Dictionary(uniqueKeysWithValues: snapshot.documents.map { ($0.documentId, $0) })
        let deepLinked = try #require(byId["d21"])
        #expect(deepLinked.volumeTitle == volumeTitle)
        #expect(deepLinked.displayTitle == volumeTitle, "the stored value is read, not rewritten")
        #expect(deepLinked.title == "frus1961-63v11 · d21")
        #expect(deepLinked.caption == nil)
        let titled = try #require(byId["d22"])
        #expect(titled.title == heading)
        #expect(titled.caption == "frus1961-63v11 · d22")
        // The filter matches the drawn title and the ids, so a word only the volume's title held
        // no longer finds a visit that was stored under it.
        #expect(snapshot.filteredDocuments(matching: "Cuban").isEmpty)
    }

    /// **The one-line label the macOS History menu and Project Home's Recently Read draw**, through
    /// the real manifest: a visit stored under its volume's title reads by its identifiers, a
    /// visit with a real title keeps it, and a visit in a volume the manifest does not list keeps
    /// whatever it stored.
    @Test("The one-line visit label applies the volume-title rule against the real manifest (#1361)")
    func oneLineLabelAppliesTheRule() throws {
        let manifest = ManifestStore()
        let volumeTitle = try #require(manifest.entry(forVolumeId: "frus1961-63v11")?.title)
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext

        let deepLinked = insertVisit(context, documentId: "d21", volumeId: "frus1961-63v11",
                                     title: volumeTitle)
        let titled = insertVisit(context, documentId: "d22", volumeId: "frus1961-63v11",
                                 title: "22. Telegram")
        let untitled = insertVisit(context, documentId: "d23", volumeId: "frus1961-63v11", title: nil)
        let unlisted = insertVisit(context, documentId: "d1", volumeId: "frus-not-in-the-manifest",
                                   title: volumeTitle)
        try context.save()

        #expect(ReadingHistoryTitle.label(for: deepLinked, in: manifest) == "frus1961-63v11 · d21")
        #expect(ReadingHistoryTitle.label(for: titled, in: manifest) == "22. Telegram")
        #expect(ReadingHistoryTitle.label(for: untitled, in: manifest) == "frus1961-63v11 · d23")
        #expect(ReadingHistoryTitle.label(for: unlisted, in: manifest) == volumeTitle)
    }

    // MARK: - #1361: the rule at each of its three call sites

    /// The app's own source, for the three wiring tests below.
    private static func appSource(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer")
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    /// A file's CODE as one line: comment lines dropped, whitespace runs collapsed to one space — so
    /// a call wrapped across lines reads as one string, and a comment naming a call cannot stand in
    /// for it.
    private static func code(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") }
            .joined(separator: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// **The History list reads against the app's manifest.** The rule's lookup lives inside
    /// `fetch` and is driven above; what only the view can get wrong is what it hands `fetch`.
    /// `fetch` takes a `ManifestStore`, not a lookup closure, so the one call site cannot pass
    /// `{ _ in nil }` at all — it does not type-check — and this pins it to `appState`'s manifest
    /// rather than an empty store, and pins that it is the view's only fetch.
    @Test("The History list's fetch is handed appState's manifest (#1361)")
    func historyListReadsAgainstTheManifest() throws {
        let code = Self.code(try Self.appSource("History/HistoryView.swift"))
        #expect(code.components(separatedBy: "HistoryPaneSnapshot.fetch(").count == 2,
                "HistoryView reads the snapshot somewhere other than refresh()")
        #expect(code.contains(
            "HistoryPaneSnapshot.fetch(from: modelContext, scope: scope, limit: pageLimit, manifest: appState.manifestStore)"),
                "HistoryView does not hand the fetch appState's manifest")
    }

    /// **The macOS History menu draws, and reopens, each visit through the rule.** The menu is
    /// macOS-only and a `View`, so this target cannot render it; the call is pinned instead, and
    /// the label it calls is driven above against the real manifest. Reverting either line to the
    /// stored `displayTitle` fails here.
    @Test("The macOS History menu labels and reopens a visit through ReadingHistoryTitle (#1361)")
    func historyMenuLabelsThroughTheRule() throws {
        let code = Self.code(try Self.appSource("App/HistoryWindowView.swift"))
        #expect(code.contains(
            "Button(ReadingHistoryTitle.label(for: entry, in: appState.manifestStore)) { openDocument(entry) }"),
                "the menu item is not labelled through the rule")
        #expect(code.contains("header: ReadingHistoryTitle.label(for: entry, in: appState.manifestStore)"),
                "the menu does not reopen a visit with its label")
        #expect(!code.contains("displayTitle"), "the menu reads a visit's stored title raw")
    }

    /// **Project Home's Recently Read draws, and reopens, each visit through the rule.** Pinned the
    /// same way as the menu, for the same reason: the view cannot be rendered here, and the label
    /// is driven above.
    @Test("Project Home's Recently Read labels and reopens a visit through ReadingHistoryTitle (#1361)")
    func projectHomeLabelsThroughTheRule() throws {
        let code = Self.code(try Self.appSource("ProjectContext/ProjectHomeView.swift"))
        #expect(code.contains(
            #"recentRow(title: ReadingHistoryTitle.label(for: visit, in: appState.manifestStore), systemImage: "book")"#),
                "Recently Read does not label a visit through the rule")
        #expect(code.contains(
            "openDocument(volumeId: visit.volumeId, documentId: visit.documentId, title: ReadingHistoryTitle.label(for: visit, in: appState.manifestStore))"),
                "Recently Read does not reopen a visit with its label")
        #expect(!code.contains("visit.displayTitle"), "Recently Read reads a visit's stored title raw")
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

        let snapshot = HistoryPaneSnapshot.fetch(from: context, manifest: noManifest)
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

        let snapshot = HistoryPaneSnapshot.fetch(from: context, manifest: noManifest)
        #expect(snapshot.filteredSearches(matching: "blockade").map(\.queryText) == ["Berlin blockade"])
        #expect(snapshot.filteredSearches(matching: "zzz").isEmpty)
    }

    /// A curly and a straight run of one query are ONE history row since #1298, which keeps the later run's spelling, so
    /// a filter typed in the other spelling must still find it — and on an iPad the filter field itself types curly
    /// marks. `localizedStandardContains` does not equate `“` or `«` or `＂` with `"`, so without folding both sides a
    /// researcher who remembers typing `"cold war"` finds nothing once a curly re-run has refreshed the row.
    @Test("The search filter reads typographic and straight quotation marks alike, in both directions")
    func searchFilterEquatesQuotationMarks() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext

        insertSearch(context, query: "\u{201C}cold war\u{201D} origins")
        insertSearch(context, query: "\"Berlin blockade\"")
        insertSearch(context, query: "\u{00AB}d\u{00E9}tente\u{00BB}")
        insertSearch(context, query: "\u{FF02}Suez crisis\u{FF02}")
        insertSearch(context, query: "12\u{2033} guns")
        try context.save()

        let snapshot = HistoryPaneSnapshot.fetch(from: context, manifest: noManifest)
        func found(_ term: String) -> Set<String> { Set(snapshot.filteredSearches(matching: term).map(\.queryText)) }

        // Straight filter, typographic rows.
        #expect(found("\"cold war\"") == ["\u{201C}cold war\u{201D} origins"])
        #expect(found("\"d\u{00E9}tente\"") == ["\u{00AB}d\u{00E9}tente\u{00BB}"])
        #expect(found("\"Suez crisis\"") == ["\u{FF02}Suez crisis\u{FF02}"])
        // Typographic filter, straight row — curly, guillemet and fullwidth.
        #expect(found("\u{201C}Berlin blockade\u{201D}") == ["\"Berlin blockade\""])
        #expect(found("\u{00AB}Berlin") == ["\"Berlin blockade\""])
        #expect(found("blockade\u{FF02}") == ["\"Berlin blockade\""])
        // Typographic filter, row in other typographic marks.
        #expect(found("\u{00BB}Suez") == ["\u{FF02}Suez crisis\u{FF02}"])
        // Still case- and diacritic-insensitive.
        #expect(found("\"DETENTE") == ["\u{00AB}d\u{00E9}tente\u{00BB}"])
        // A double prime is not a quotation mark, on either side.
        #expect(found("12\"").isEmpty)
        #expect(found("\u{2033}cold").isEmpty)
        #expect(found("12\u{2033}") == ["12\u{2033} guns"])
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

        #expect(HistoryPaneSnapshot.fetch(from: context, manifest: noManifest).totalDocuments == 2)
        HistoryTrailAdmin.deleteDocumentVisit(id: doomed.id, in: context)

        let after = HistoryPaneSnapshot.fetch(from: context, manifest: noManifest)
        #expect(after.totalDocuments == 1)
        #expect(after.documents.map(\.documentId) == ["stays"])
    }

    // MARK: - Empty store

    /// A fresh install: no rows, no totals, nothing claiming to be truncated.
    @Test("An empty store produces an empty snapshot with nothing hidden")
    func emptyStoreIsEmpty() throws {
        let container = try ModelContainer.makeTestContainer()
        let snapshot = HistoryPaneSnapshot.fetch(from: container.mainContext, manifest: noManifest)

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

        let snapshot = HistoryPaneSnapshot.fetch(from: context, manifest: noManifest)
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

        let snapshot = HistoryPaneSnapshot.fetch(from: context, manifest: noManifest)
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
        #expect(HistoryPaneSnapshot.fetch(from: context, manifest: noManifest).searches.count == 1)
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

        let all = HistoryPaneSnapshot.fetch(from: context, manifest: noManifest)
        #expect(all.totalExports == 2)
        #expect(all.exports.map(\.documentCount) == [3, 12], "newest first")
        #expect(all.isEmpty == false, "a store with only exports is not an empty trail")

        let scopedSnapshot = HistoryPaneSnapshot.fetch(from: context, scope: .project(project),
                                                       manifest: noManifest)
        #expect(scopedSnapshot.exports.map(\.entryID) == [scoped.id])
        let unfiled = HistoryPaneSnapshot.fetch(from: context, scope: .unfiled, manifest: noManifest)
        #expect(unfiled.exports.map(\.format) == ["zotero-api"])

        #expect(HistoryTrailAdmin.deleteExport(id: scoped.id, in: context))
        #expect(HistoryPaneSnapshot.fetch(from: context, manifest: noManifest).totalExports == 1)
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

        let snapshot = HistoryPaneSnapshot.fetch(from: context, manifest: noManifest)
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
