// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SwiftData
@testable import FRUSExplorer

// MARK: - ResearchDocumentAggregationTests

/// `ResearchView`'s document aggregation, now six sources wide (R-5 P2).
///
/// The design's §5.6 counted four sources — notes, tags, collections, highlights — and P2 adds
/// the two a correction is most likely to supersede: a `GeneratedSummary` is derived from the
/// text, and an `ArchiveVisitDocument`'s plan from the source note. Each case here plants a
/// document carrying ONLY one source, because that is the document the pre-P2 view never listed.
/// The set is also what the storage hubs' post-update summary intersects with, so it is pinned
/// once here for both.
///
/// Version history:
///   1.0 — R-5 P2: initial implementation
///   1.1 — R-5 P3b-4: the collections source admits excerpt entries (design Q-7 b)
@Suite("Research aggregation — the six annotation sources")
struct ResearchDocumentAggregationTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ResearchNote.self, DocumentTagAssignment.self, Collection.self, CollectionEntry.self,
                 DocumentHighlight.self, GeneratedSummary.self,
                 ArchiveVisitPlan.self, ArchiveVisitDocument.self, ArchiveVisitTarget.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    /// One document per source, none overlapping, so each key's presence names its source.
    @Test("Each of the six sources contributes its own document")
    @MainActor
    func eachSourceContributes() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let note = ResearchNote(documentId: "d1", volumeId: "v1", bodyText: "a note", projectIds: [])
        context.insert(note)
        context.insert(DocumentTagAssignment(volumeId: "v1", documentId: "d2", tagId: UUID()))
        let collection = Collection(name: "C", projectIds: [])
        context.insert(collection)
        let entry = CollectionEntry(collectionId: collection.id, documentId: "d3", volumeId: "v1", sortOrder: 0)
        entry.kind = CollectionEntryKind.document.rawValue
        context.insert(entry)
        entry.collection = collection    // the inverse; `documentEntries?.append` no-ops on a fresh collection
        context.insert(DocumentHighlight(volumeId: "v1", documentId: "d4", startOffset: 0, endOffset: 3,
                                         noteId: nil, renderingVersion: "1"))
        context.insert(GeneratedSummary(documentId: "d5", volumeId: "v1", promptId: UUID(), responseText: "sum"))
        let plan = ArchiveVisitPlan(name: "Trip")
        context.insert(plan)
        context.insert(ArchiveVisitDocument(planId: plan.id, documentKey: "v1/d6"))
        try context.save()

        let keys = ResearchDocumentAggregation.annotatedKeys(
            notes: try context.fetch(FetchDescriptor<ResearchNote>()),
            tagAssignments: try context.fetch(FetchDescriptor<DocumentTagAssignment>()),
            collections: try context.fetch(FetchDescriptor<Collection>()),
            highlights: try context.fetch(FetchDescriptor<DocumentHighlight>()),
            summaries: try context.fetch(FetchDescriptor<GeneratedSummary>()),
            visitDocuments: try context.fetch(FetchDescriptor<ArchiveVisitDocument>()))
        #expect(keys == ["v1/d1", "v1/d2", "v1/d3", "v1/d4", "v1/d5", "v1/d6"])
    }

    /// R-5 P3b-5 (design Q-11 b). The row is a way IN to a note, not a place to read it, so it
    /// prints the note's first line and never its body.
    @Test("A note row shows its first line, trimmed, and says so when there is nothing to show")
    func noteRowTitles() {
        func note(_ body: String) -> ResearchNote {
            ResearchNote(documentId: "d1", volumeId: "v1", bodyText: body, projectIds: [])
        }
        #expect(DocumentChangeReviewSheet.noteRowTitle(note("Ambassador's read of the meeting"))
                == "Ambassador's read of the meeting")
        // Only the FIRST line: a long note must not push every other row off the sheet.
        #expect(DocumentChangeReviewSheet.noteRowTitle(note("First line\nSecond line\nThird"))
                == "First line")
        // Leading whitespace is the ordinary shape of a pasted note.
        #expect(DocumentChangeReviewSheet.noteRowTitle(note("   indented\nmore")) == "indented")
        // An empty note is reachable: the editor saves a row before the reader types.
        let placeholder = DocumentChangeReviewSheet.noteRowTitle(note(""))
        #expect(placeholder == "Open note")
        #expect(DocumentChangeReviewSheet.noteRowTitle(note("\n\n")) == placeholder)
        // The first line with something IN it, not literally the first line: a note that opens on a
        // blank line still has a first line worth showing, and printing the placeholder for it
        // would hide a note that is not empty at all.
        #expect(DocumentChangeReviewSheet.noteRowTitle(note("   \n x")) == "x")
        #expect(DocumentChangeReviewSheet.noteRowTitle(note("\n\nAmbassador's read")) == "Ambassador's read")
        // CRLF. `CharacterSet.whitespaces` is space and tab only, so trimming with it would leave a
        // carriage return here and print an invisible control character as the row's title.
        #expect(DocumentChangeReviewSheet.noteRowTitle(note("\r\n\r\nAmbassador's read\r\nmore"))
                == "Ambassador's read")
        #expect(DocumentChangeReviewSheet.noteRowTitle(note("\r\n\r\n")) == placeholder)
    }

    /// Design Q-7 (b). The excerpt is the annotation whose entire content is a verbatim copy of
    /// the text an update corrects, and before P3b-4 a document carrying only one was absent from
    /// "All Research Documents" and from "Changed by an update" — while the SAME document appeared
    /// under its collection in the same sidebar, because that grouping counts every entry with a
    /// document id.
    @Test("An excerpt-only document is annotated; a heading, prose, generated or future entry is not")
    @MainActor
    func excerptEntriesCount() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let collection = Collection(name: "C", projectIds: [])
        context.insert(collection)

        // Every non-excerpt kind is planted WITH a document id, so the test proves the kind rule
        // rather than the empty-id guard that `blankIdsAreSkipped` already covers.
        func entry(_ kind: String, _ documentId: String, order: Int) {
            let e = CollectionEntry(collectionId: collection.id, documentId: documentId,
                                    volumeId: "v1", sortOrder: order)
            e.kind = kind
            context.insert(e)
            e.collection = collection
        }
        entry(CollectionEntryKind.document.rawValue, "d1", order: 0)
        entry(CollectionEntryKind.excerpt.rawValue, "d2", order: 1)
        entry(CollectionEntryKind.heading.rawValue, "d3", order: 2)
        entry(CollectionEntryKind.prose.rawValue, "d4", order: 3)
        entry(CollectionEntryKind.generated.rawValue, "d5", order: 4)
        entry("someKindAFutureBuildWrote", "d6", order: 5)
        try context.save()

        let keys = ResearchDocumentAggregation.annotatedKeys(
            notes: [], tagAssignments: [],
            collections: try context.fetch(FetchDescriptor<Collection>()),
            highlights: [], summaries: [], visitDocuments: [])
        #expect(keys == ["v1/d1", "v1/d2"])
    }

    /// The Research sidebar's per-collection number. It must equal the length of the list the row
    /// opens, which is why it is a set of documents and not a count of entries: the old
    /// `documentEntries.count` counted a heading and a prose block as documents, and after P3b-4
    /// would additionally have counted an excerpt and its own document entry as two.
    @Test("The sidebar count is distinct documents, not entries")
    @MainActor
    func sidebarCountIsDistinctDocuments() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let collection = Collection(name: "C", projectIds: [])
        context.insert(collection)
        func entry(_ kind: CollectionEntryKind, _ documentId: String, _ volumeId: String = "v1", order: Int) {
            let e = CollectionEntry(collectionId: collection.id, documentId: documentId,
                                    volumeId: volumeId, sortOrder: order)
            e.kind = kind.rawValue
            context.insert(e)
            e.collection = collection
        }
        entry(.document, "d1", order: 0)
        entry(.document, "d2", order: 1)
        // The same document, quoted twice and also present as a document entry: ONE document.
        entry(.excerpt, "d2", order: 2)
        entry(.excerpt, "d2", order: 3)
        // A document reached only by a quotation still counts.
        entry(.excerpt, "d3", order: 4)
        // Structure carries no document even when the ids are filled in.
        entry(.heading, "d4", order: 5)
        entry(.prose, "d5", order: 6)
        entry(.generated, "d6", order: 7)
        // The same document id in a different volume is a different document.
        entry(.document, "d1", "v2", order: 8)
        try context.save()

        let entries = try #require(try context.fetch(FetchDescriptor<Collection>()).first?.documentEntries)
        #expect(entries.count == 9, "the fixture must plant every entry, or the count proves nothing")
        let keys = ResearchDocumentAggregation.distinctDocumentKeys(in: entries)
        #expect(keys == ["v1/d1", "v1/d2", "v1/d3", "v2/d1"])
        #expect(keys.count == 4, "nine entries, four documents")
    }

    /// The rule itself, so the three engagement consumers that must NOT widen have something to
    /// point at: they test `.document` directly and never call this.
    @Test("countsAsAnnotation admits document and excerpt, and refuses every other kind by name")
    func countsAsAnnotationVocabulary() {
        #expect(ResearchDocumentAggregation.countsAsAnnotation(CollectionEntryKind.document.rawValue))
        #expect(ResearchDocumentAggregation.countsAsAnnotation(CollectionEntryKind.excerpt.rawValue))
        for kind in [CollectionEntryKind.heading, .prose, .generated, .unrecognized] {
            #expect(!ResearchDocumentAggregation.countsAsAnnotation(kind.rawValue),
                    "\(kind.rawValue) must not put a document into the reader's research")
        }
        #expect(!ResearchDocumentAggregation.countsAsAnnotation(""))
        #expect(!ResearchDocumentAggregation.countsAsAnnotation("someKindAFutureBuildWrote"))
    }

    @Test("A summary-only document and a visit-plan-only document are the two P2 adds")
    func theTwoAdds() {
        let summaries = [GeneratedSummary(documentId: "d5", volumeId: "v1", promptId: UUID(), responseText: "s")]
        let visits = [ArchiveVisitDocument(planId: UUID(), documentKey: "v2/d9")]
        let withBoth = ResearchDocumentAggregation.annotatedKeys(
            notes: [], tagAssignments: [], collections: [], highlights: [],
            summaries: summaries, visitDocuments: visits)
        #expect(withBoth == ["v1/d5", "v2/d9"])
        let withoutEither = ResearchDocumentAggregation.annotatedKeys(
            notes: [], tagAssignments: [], collections: [], highlights: [], summaries: [], visitDocuments: [])
        #expect(withoutEither.isEmpty)
    }

    @Test("Blank ids never mint a key")
    func blankIdsAreSkipped() {
        let keys = ResearchDocumentAggregation.annotatedKeys(
            notes: [ResearchNote(documentId: "", volumeId: "v1", bodyText: "x", projectIds: [])],
            tagAssignments: [DocumentTagAssignment(volumeId: "", documentId: "d1", tagId: UUID())],
            collections: [], highlights: [],
            summaries: [GeneratedSummary(documentId: "d1", volumeId: "", promptId: UUID(), responseText: "s")],
            visitDocuments: [ArchiveVisitDocument(planId: UUID(), documentKey: "")])
        #expect(keys.isEmpty)
    }

    /// The row's sentence per kind — the three the index writes, and nothing for one it does not.
    @Test("changeLine names each kind and hedges only the body kind")
    func changeLines() throws {
        func rev(_ kind: String?) -> IndexingPipeline.DocumentRevision {
            .init(volumeId: "v1", documentId: "d1", contentHash: "c", bodyHash: "b",
                  changedAt: "2026-09-03T00:00:00Z", changeKind: kind, reviewedAt: nil)
        }
        let body = try #require(ResearchDocumentAggregation.changeLine(for: rev("body")))
        let apparatus = try #require(ResearchDocumentAggregation.changeLine(for: rev("apparatus")))
        let vanished = try #require(ResearchDocumentAggregation.changeLine(for: rev("vanished")))
        #expect(body.hasPrefix("Text changed") && body.contains("may have moved"))
        #expect(apparatus.hasPrefix("Footnotes, source note, or heading changed") && apparatus.contains("the text did not"))
        #expect(vanished.contains("No longer in the volume"))
        #expect(ResearchDocumentAggregation.changeLine(for: rev(nil)) == nil)
        #expect(ResearchDocumentAggregation.changeLine(for: rev("renumbered")) == nil)
    }

    /// Design Q-8: a headnote draft is collection-private and excluded from every carousel, so it
    /// must not make a document "annotated" by itself, nor count as one of its summaries.
    @Test("Headnote drafts neither annotate a document nor count as its summaries")
    func draftsAreExcluded() {
        let draft = GeneratedSummary(documentId: "d7", volumeId: "v1", promptId: UUID(), responseText: "own words",
                                     isHeadnoteDraft: true)
        let live = GeneratedSummary(documentId: "d8", volumeId: "v1", promptId: UUID(), responseText: "ai")
        let keys = ResearchDocumentAggregation.annotatedKeys(
            notes: [], tagAssignments: [], collections: [], highlights: [],
            summaries: [draft, live], visitDocuments: [])
        #expect(keys == ["v1/d8"])
        let counts = ResearchDocumentAggregation.summaryCounts([draft, live, live])
        #expect(counts == ["v1/d8": 2])
    }

    // MARK: - The per-document rebuild (build 45 hang)

    /// **`documents(for:)` must hoist its five dictionaries before the loop, not read them inside.**
    ///
    /// `directlyTaggedDocs`, `collectionMemberships`, `highlightedDocs`, `summarizedDocs` and
    /// `visitPlanDocs` are COMPUTED properties: each walks a whole `@Query` array and builds a new
    /// dictionary. Read inside `compactMap` they were rebuilt once per document, making the
    /// Research list O(documents × annotations).
    ///
    /// It beachballed build 45 on a real library. A `sample` of the hung process put **2,393 of
    /// 2,626 samples** in `summarizedDocs` → `summaryCounts`, which reads three properties on every
    /// `GeneratedSummary` — and every one of those reads goes through SwiftData's
    /// `persistentBackingData`, so it is far more expensive than an array read.
    ///
    /// A timing test would flake under parallel load, and the aggregation is a private method on a
    /// `View`, so this pins the structural fix instead: the hoists exist and precede the loop.
    @Test("The document aggregation hoists its dictionaries out of the per-document loop")
    func aggregationHoistsItsDictionaries() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Research/ResearchView.swift")
        let source = try String(contentsOf: url, encoding: .utf8)

        let fn = try #require(source.range(of: "private func documents(for item: ResearchSidebarItem)"))
        let loop = try #require(source.range(of: "return grouped.compactMap", range: fn.upperBound..<source.endIndex))
        let preamble = String(source[fn.upperBound..<loop.lowerBound])

        for name in ["directlyTaggedDocs", "collectionMemberships", "highlightedDocs",
                     "summarizedDocs", "visitPlanDocs"] {
            #expect(preamble.contains("let \(name) = \(name)"),
                    Comment(rawValue: "\(name) must be hoisted before the loop — reading the computed property inside compactMap rebuilds it once per document"))
        }
    }

    /// Design Q-11 (h): a vanished document routes to the review sheet whether or not its change
    /// has been reviewed — vanished-ness is a fact about the volume, review state is not. The
    /// first version keyed on the unreviewed row and lost the route the moment Mark Reviewed ran.
    @Test("rowDestination: vanished routes to the sheet regardless of review state; everything else opens the document")
    func rowDestination() {
        func rev(_ kind: String?, reviewed: Bool = false) -> IndexingPipeline.DocumentRevision {
            .init(volumeId: "v1", documentId: "d1", contentHash: "c", bodyHash: "b",
                  changedAt: "2026-09-03T00:00:00Z", changeKind: kind, reviewedAt: reviewed ? "2026-09-03T01:00:00Z" : nil)
        }
        #expect(ResearchDocumentAggregation.rowDestination(revision: rev("vanished"), isVanished: true) == .reviewSheet)
        #expect(ResearchDocumentAggregation.rowDestination(revision: nil, isVanished: true) == .reviewSheet)
        #expect(ResearchDocumentAggregation.rowDestination(revision: rev("vanished", reviewed: true), isVanished: true) == .reviewSheet)
        #expect(ResearchDocumentAggregation.rowDestination(revision: rev("body"), isVanished: false) == .document)
        #expect(ResearchDocumentAggregation.rowDestination(revision: rev("apparatus"), isVanished: false) == .document)
        #expect(ResearchDocumentAggregation.rowDestination(revision: nil, isVanished: false) == .document)
    }
}

// MARK: - ResearchSidebarRowIdentityTests

/// The Research sidebar's row identifiers (#1362), which `ResearchSidebarSelectionTests` finds the
/// category rows by — every one of them at once, by prefix, to prove the open category is the ONLY row
/// marked in the iPad two-pane.
///
/// That sweep is only as sound as the identifiers are distinct: two rows sharing one would let a mark
/// on the wrong row pass as the right one. The UI target cannot import the app, so it spells the
/// identifiers out, and the exact strings are pinned here as well.
///
/// Version history:
///   1.0 — #1362: initial implementation
@Suite("Research sidebar — row identifiers")
struct ResearchSidebarRowIdentityTests {

    /// Every case, with a tag and a collection deliberately sharing ONE UUID — the collision an
    /// identifier built from the payload alone would make.
    private static let everyRow: [ResearchSidebarItem] = {
        let shared = UUID()
        return [.allAnnotated, .hasNotes, .notes, .history, .updated,
                .tag(shared), .collection(shared), .tag(UUID()), .collection(UUID())]
            + DocumentHighlight.Color.allCases.map { .highlightColor($0) }
    }()

    @Test("Every row's identifier is distinct, including a tag and a collection that share a UUID")
    func identifiersAreDistinct() {
        let identifiers = Self.everyRow.map(\.rowAccessibilityIdentifier)
        #expect(Set(identifiers).count == identifiers.count,
                "two sidebar rows share an identifier: \(identifiers)")
        let shared = UUID()
        #expect(ResearchSidebarItem.tag(shared).rowAccessibilityIdentifier
                != ResearchSidebarItem.collection(shared).rowAccessibilityIdentifier)
    }

    @Test("Every row's identifier starts with the prefix the UI test sweeps by")
    func identifiersShareThePrefix() {
        let prefix = ResearchSidebarItem.rowAccessibilityIdentifierPrefix
        #expect(prefix == "research.sidebar.row.")
        for item in Self.everyRow {
            #expect(item.rowAccessibilityIdentifier.hasPrefix(prefix),
                    "\(item) does not start with \(prefix): \(item.rowAccessibilityIdentifier)")
            #expect(item.rowAccessibilityIdentifier.count > prefix.count, "\(item) has an empty key")
        }
    }

    /// The four rows iOS always draws, spelled exactly as `ResearchSidebarSelectionTests` spells them.
    @Test("The four always-drawn rows carry the identifiers the UI test names")
    func alwaysDrawnIdentifiers() {
        #expect(ResearchSidebarItem.allAnnotated.rowAccessibilityIdentifier == "research.sidebar.row.allAnnotated")
        #expect(ResearchSidebarItem.hasNotes.rowAccessibilityIdentifier == "research.sidebar.row.hasNotes")
        #expect(ResearchSidebarItem.notes.rowAccessibilityIdentifier == "research.sidebar.row.notes")
        #expect(ResearchSidebarItem.history.rowAccessibilityIdentifier == "research.sidebar.row.history")
    }
}

// MARK: - ResearchSidebarOpenMarkSourceTests

/// The open category's mark in Research's iPad two-pane (#1362), read from the source — because its
/// visible half has no runtime signature a UI test can read.
///
/// The mark is two modifiers on one row: `.accessibilityAddTraits(.isSelected)`, which VoiceOver
/// announces and `ResearchSidebarSelectionTests` reads through XCUI's `isSelected`, and
/// `.listRowBackground`, the fill the eye sees. Neither reads the other, and a fill changes no trait,
/// so deleting the fill, clearing it, or keying it on the wrong condition leaves the UI suite green —
/// the #1362 review found exactly that mutant surviving. This suite pins both modifiers in the
/// two-pane branch of `ResearchView.sidebarRow`, on the one `isOpen` condition, and `isOpen` as
/// `selectedItem == item`, the value the detail pane renders from.
///
/// **What it cannot see** is whether the fill is visible: its colour against the list, and the list
/// drawing a row background under a plain button. That is the UI suite's kept screenshots, by eye.
///
/// The second test is the class #1362 belongs to, across the app: a list row that paints a
/// CONDITIONAL fill must announce `.isSelected` on the same condition, in the same declaration.
/// `ReferenceListPanel.nodeRow`, whose fill #1362 copied, painted it without the trait until the
/// #1362 review.
///
/// Version history:
///   1.0 — #1362 review, round 1: initial implementation
@Suite("Research sidebar — the open category's mark, as written")
struct ResearchSidebarOpenMarkSourceTests {

    /// One `.listRowBackground(<condition> ? …)` call, with the declaration that encloses it.
    private struct ConditionalFill {
        /// The ternary's condition — a bare identifier, such as `isOpen`.
        let condition: String
        /// The enclosing function's name, or `nil` when no function encloses the call.
        let declaration: String?
        /// The enclosing function's body, comments already removed.
        let scope: String?
    }

    private static let researchView = "FRUSExplorer/Research/ResearchView.swift"
    private static let referenceListPanel = "FRUSExplorer/CrossReference/ReferenceListPanel.swift"

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func source(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }

    /// `text` without its comment lines, so a comment that names a modifier cannot stand in for it.
    private static func code(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// The range from the brace at `start` to the brace that closes it, or `nil` when unbalanced.
    private static func balanced(from start: String.Index, in text: String) -> Range<String.Index>? {
        var depth = 0
        var cursor = start
        while cursor < text.endIndex {
            if text[cursor] == "{" { depth += 1 }
            if text[cursor] == "}" {
                depth -= 1
                if depth == 0 { return start..<text.index(after: cursor) }
            }
            cursor = text.index(after: cursor)
        }
        return nil
    }

    /// Every `.listRowBackground(<identifier> ? …)` call in `text` (comments removed), each with the
    /// innermost function whose body contains it. A signature is `func name` up to its first brace,
    /// which holds for every declaration that paints a fill today; one it cannot read reports a `nil`
    /// scope, and the caller fails on that rather than passing it.
    private static func conditionalFills(in text: String) throws -> [ConditionalFill] {
        let whole = NSRange(text.startIndex..., in: text)
        let fill = try NSRegularExpression(pattern: #"\.listRowBackground\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*\?"#)
        let function = try NSRegularExpression(pattern: #"func\s+([A-Za-z_][A-Za-z0-9_]*)[^{]*\{"#)
        let functions: [(name: String, body: Range<String.Index>)] = function.matches(in: text, range: whole)
            .compactMap { match in
                guard let name = Range(match.range(at: 1), in: text),
                      let head = Range(match.range, in: text),
                      let body = balanced(from: text.index(before: head.upperBound), in: text)
                else { return nil }
                return (name: String(text[name]), body: body)
            }
        return fill.matches(in: text, range: whole).compactMap { match in
            guard let call = Range(match.range, in: text),
                  let condition = Range(match.range(at: 1), in: text) else { return nil }
            let enclosing = functions.filter { $0.body.contains(call.lowerBound) }
                .min { text.distance(from: $0.body.lowerBound, to: $0.body.upperBound)
                    < text.distance(from: $1.body.lowerBound, to: $1.body.upperBound) }
            return ConditionalFill(condition: String(text[condition]), declaration: enclosing?.name,
                                   scope: enclosing.map { String(text[$0.body]) })
        }
    }

    /// Whether `scope` announces `.isSelected` on `condition`, in either spelling the app uses.
    private static func announcesSelected(_ condition: String, in scope: String) -> Bool {
        scope.contains(".accessibilityAddTraits(\(condition) ? .isSelected")
            || scope.contains(".accessibilityAddTraits(\(condition) ? [.isSelected")
    }

    @Test("The two-pane row paints the fill and announces the trait, both on the open category")
    func twoPaneRowCarriesBothHalvesOfTheMark() throws {
        let text = Self.code(try Self.source(Self.researchView))
        let function = try #require(text.range(of: "private func sidebarRow<"),
                                    "\(Self.researchView): no `sidebarRow` declaration")
        let branchHead = try #require(text.range(of: "if isTwoPane {", range: function.upperBound..<text.endIndex),
                                      "\(Self.researchView): `sidebarRow` has no `if isTwoPane {` branch")
        let branchRange = try #require(Self.balanced(from: text.index(before: branchHead.upperBound), in: text),
                                       "\(Self.researchView): unbalanced braces in the two-pane branch")
        let branch = String(text[branchRange])

        #expect(branch.contains("let isOpen = selectedItem == item"),
                "the two-pane row's `isOpen` is no longer `selectedItem == item` — the mark would stop following the detail")
        #expect(branch.contains("Button { selectedItem = item }"),
                "the two-pane row no longer sets `selectedItem`, the value both the mark and the detail read")
        #expect(branch.contains(".accessibilityAddTraits(isOpen ? .isSelected : [])"),
                "the two-pane row no longer announces `.isSelected` on `isOpen`")
        #expect(branch.contains(".listRowBackground(isOpen ? Color.accentColor.opacity(0.12) : nil)"),
                "the two-pane row no longer paints the open category's fill on `isOpen` — the eye sees no mark, and no UI test can tell")
        let backgrounds = branch.components(separatedBy: ".listRowBackground(").count - 1
        #expect(backgrounds == 1,
                "the two-pane row sets its background \(backgrounds) times, not once: none draws no mark, and a second call can undo the fill")
        // The fill is the reference list's selected row, which the comment above the branch says it is.
        let panel = Self.code(try Self.source(Self.referenceListPanel))
        #expect(panel.contains(".listRowBackground(isSelected ? Color.accentColor.opacity(0.12) : nil)"),
                "\(Self.referenceListPanel): the fill #1362 copied has changed; the two should match")
    }

    @Test("Every row that paints a conditional fill announces the selected trait on the same condition")
    func everyConditionalFillAnnouncesTheTrait() throws {
        let appRoot = Self.repoRoot.appending(path: "FRUSExplorer")
        let paths = try FileManager.default.subpathsOfDirectory(atPath: appRoot.path)
            .filter { $0.hasSuffix(".swift") }
            .sorted()
        #expect(paths.count > 100, "Only \(paths.count) Swift files under FRUSExplorer/ — the scan path is wrong.")

        var sites: [String] = []
        for path in paths {
            let relative = "FRUSExplorer/\(path)"
            for fill in try Self.conditionalFills(in: Self.code(try Self.source(relative))) {
                guard let declaration = fill.declaration, let scope = fill.scope else {
                    Issue.record("\(relative): no function the scan can read encloses `.listRowBackground(\(fill.condition) ? …)`")
                    continue
                }
                sites.append("\(relative) \(declaration)")
                #expect(Self.announcesSelected(fill.condition, in: scope), """
                    \(relative) \(declaration) paints a fill on `\(fill.condition)` but never announces \
                    `.isSelected` on it, so VoiceOver cannot hear which row the fill marks
                    """)
            }
        }
        // The sweep has to reach the two rows #1362 is about, or it has proved nothing.
        #expect(sites.contains("\(Self.researchView) sidebarRow"), "the scan did not reach ResearchView.sidebarRow: \(sites)")
        #expect(sites.contains("\(Self.referenceListPanel) nodeRow"), "the scan did not reach ReferenceListPanel.nodeRow: \(sites)")
    }
}
