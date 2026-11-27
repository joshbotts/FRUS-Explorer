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
import SwiftUI
import SQLite3
#if os(iOS)
import UIKit
#endif
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
///   1.1 — #1431: the sweep must also reach `BrowseOpenDoorMark.body` in `CorpusView.swift`, the one
///          place Browse's corpus-root doors paint their open fill
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
    private static let corpusView = "FRUSExplorer/Browser/CorpusView.swift"

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
        // …and Browse's (#1431): every corpus-root door row paints its fill through this one
        // modifier's `body`, which `BrowseRootOpenMarkSourceTests` requires each door to call.
        #expect(sites.contains("\(Self.corpusView) body"), "the scan did not reach BrowseOpenDoorMark.body: \(sites)")
    }
}

// MARK: - ResearchDocumentRowTextTests

/// A Research document row names its document by number above its head (L21, UI review MAC-5,
/// #1921).
///
/// Before L21 a row printed the head and the volume, so Documents 474, 475 and 476 of
/// `frus1946v06`, each "The Chargé in the Soviet Union (Kennan) to the Secretary of State", read
/// alike on the `macos/research` capture. `ResearchView` is shared by iPhone, iPad and the Mac, so
/// the rule's cases run here on every destination; the source gate holds the row to drawing it.
///
/// Version history:
///   1.0 — L21 (MAC-5): initial implementation
@Suite("Research rows — the document's number (MAC-5)")
struct ResearchDocumentRowTextTests {

    /// Facts as `CrossReferenceStore.documentTitleFacts(for:)` returns them for one document.
    private func facts(_ header: String?, _ number: String?, note: Bool = false) -> DocumentDisplayTitle.Facts {
        DocumentDisplayTitle.Facts(header: header, documentNumber: number, isEditorialNote: note)
    }

    @Test("three same-headed telegrams read apart by their numbers")
    func sameHeadedTelegramsReadApart() {
        let head = "The Chargé in the Soviet Union (Kennan) to the Secretary of State"
        // Typed: an untyped literal is inferred as `[String?]` from `facts`' parameter, and the id
        // would read `dOptional("474")`.
        let numbers: [String] = ["474", "475", "476"]
        let rows = numbers.map {
            ResearchDocumentRowText.parts(facts: facts(head, $0), documentId: "d\($0)")
        }
        #expect(rows.map(\.label) == ["Document 474", "Document 475", "Document 476"])
        #expect(rows.map(\.title) == [head, head, head], "the head is printed whole, as before")
    }

    @Test("a head that opens with its own number gives it to the line above")
    func numberedHeadLosesItsNumber() {
        let row = ResearchDocumentRowText.parts(
            facts: facts("81. Memorandum From the Director of the Policy Planning Staff (Bowie) to the Secretary of State", "81"),
            documentId: "d81")
        #expect(row.label == "Document 81")
        #expect(row.title == "Memorandum From the Director of the Policy Planning Staff (Bowie) to the Secretary of State")
        // A head that opens with another number keeps it: there the number is part of the title.
        let other = ResearchDocumentRowText.parts(facts: facts("1. Sir Edward Thornton to Mr. Fish.", "17"),
                                                  documentId: "d17")
        #expect(other == (label: "Document 17", title: "1. Sir Edward Thornton to Mr. Fish."))
    }

    @Test("before the head loads, the id names the number, and the row keeps both lines")
    func provisionalRow() {
        let row = ResearchDocumentRowText.parts(facts: nil, documentId: "d475")
        #expect(row == (label: "Document 475", title: "d475"))
        // An id that is not a number: the line is the id, as the Mac collection manager's row is.
        let section = ResearchDocumentRowText.parts(facts: nil, documentId: "ch1")
        #expect(section == (label: "ch1", title: "ch1"))
    }

    @Test("an unnumbered document and an editorial note are named as the other lists name them")
    func unnumberedAndEditorialNote() {
        let potsdam = ResearchDocumentRowText.parts(
            facts: facts("The Secretary of State to the Acting Secretary of State",
                         "[Unnumbered document following Document 710 (#1)]"),
            documentId: "d710a-1")
        #expect(potsdam == (label: "Unnumbered (d710a-1)",
                            title: "The Secretary of State to the Acting Secretary of State"))
        let note = ResearchDocumentRowText.parts(facts: facts("Editorial Note", "304", note: true),
                                                 documentId: "d304")
        #expect(note == (label: "Document 304", title: "Editorial Note 304"))
    }

    /// The row draws the rule: the number's line, then the title, where the title alone was drawn.
    @Test("the Research row draws the number's line above the title (MAC-5)")
    func rowDrawsTheNumber() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appending(path: "FRUSExplorer/Research/ResearchView.swift"),
                                encoding: .utf8)
        let code = NaturalLanguageReadinessScanTests.code(source)
        let start = try #require(code.range(of: "private func documentRow(_ entry: ResearchDocumentEntry) -> some View"),
                                 "ResearchView has no documentRow")
        let range = try #require(NaturalLanguageReadinessScanTests.braceBody(in: code, after: start.upperBound))
        let row = code[range].split(whereSeparator: \.isWhitespace).joined(separator: " ")
        #expect(row.contains("let naming = ResearchDocumentRowText.parts(facts: facts, documentId: entry.documentId) "
                             + "Text(naming.label) .font(.caption.weight(.medium)) .foregroundStyle(.secondary) .lineLimit(1) "
                             + "Text(naming.title) .font(.body)"),
                "the row does not draw the number's line above the title: \(row.prefix(600))")
        #expect(!row.contains("Text(DocumentDisplayTitle.text(facts, documentId: entry.documentId))"),
                "the row draws the bare title again, with no number")
    }
}

#if os(iOS)
// MARK: - ResearchRowHeadsTests

/// The Research rows' heads load once the cross-reference store is there, whenever it comes (L38,
/// #1946).
///
/// On the Mac the Research window showed each row's id where its head belongs (*d474*, *d473*, …)
/// and kept it until the sidebar's selection changed. The heads come from `AppState`'s
/// cross-reference store, which boot sets after a window that opens first may already be up, and
/// which `AppState.refreshReadOnlyStores()` replaces after every indexing batch; the load was made
/// once for each set of documents, and one that found no store kept nothing. (The check copy also
/// showed rows that kept their ids after a read that found all their heads, which the rows' redraw
/// answers, `ResearchRowsRedrawSourceTests`, below.)
///
/// These host the rows' loader, `View.researchRowHeads(for:from:into:)`, in a real hosting
/// controller in a window of the test host's scene, since what failed is when SwiftUI runs a task,
/// which no value-level test can see. The store reads a database of one table, `document_cache`,
/// with the four columns `CrossReferenceStore.documentTitleFacts(for:)` reads.
///
/// Version history:
///   1.0 — L38 (#1946): initial implementation
@Suite("Research rows — the heads load once the store is there (#1946)")
@MainActor
struct ResearchRowHeadsTests {

    /// What the hosted loader reads and writes: the store it is given, and the heads it loaded.
    @Observable
    final class Probe {
        /// The rows' documents.
        var documentKeys = ["frus1946v06/d474"]
        /// The store the loader is given; `nil`, as before boot sets it.
        var store: CrossReferenceStore?
        /// The heads the loader wrote.
        var headers: [String: CrossReferenceStore.DocumentTitleFacts] = [:]
    }

    /// The loader, hosted as `ResearchView` hosts it.
    private struct Rows: View {
        @Bindable var probe: Probe

        var body: some View {
            Color.white.researchRowHeads(for: probe.documentKeys, from: probe.store, into: $probe.headers)
        }
    }

    /// The head `frus1946v06` d474 prints.
    private static let head = "The Chargé in the Soviet Union (Kennan) to the Secretary of State"

    /// A database holding `document_cache` for `rows` (key → head), in a folder of its own.
    private struct Database {
        let folder: URL
        let url: URL

        init(rows: [String: String]) throws {
            folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("ResearchRowHeads-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            url = folder.appendingPathComponent("frus.db")
            try execute("""
                CREATE TABLE document_cache (volume_id TEXT NOT NULL, document_id TEXT NOT NULL,
                    header TEXT, document_number TEXT, is_editorial_note INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY (volume_id, document_id));
                """)
            for (key, head) in rows { try add(key, head: head) }
        }

        /// Adds a document's row, as an index pass writes one, through a connection of its own.
        func add(_ key: String, head: String) throws {
            let parts = key.split(separator: "/").map(String.init)
            let number = parts[1].dropFirst()
            let quoted = head.replacingOccurrences(of: "'", with: "''")
            try execute("INSERT INTO document_cache VALUES ('\(parts[0])', '\(parts[1])', '\(quoted)', '\(number)', 0);")
        }

        private func execute(_ sql: String) throws {
            var db: OpaquePointer?
            guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK,
                  let db else { throw CrossReferenceError.databaseOpenFailed(message: "fixture") }
            defer { sqlite3_close_v2(db) }
            guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
                throw CrossReferenceError.queryFailed(message: String(cString: sqlite3_errmsg(db)))
            }
        }

        /// A store over this database: a new instance each call, as `refreshReadOnlyStores()` makes one.
        func store() throws -> CrossReferenceStore { try CrossReferenceStore(databaseURL: url) }

        func remove() { try? FileManager.default.removeItem(at: folder) }
    }

    /// Hosts `root` in a window of the test host's scene, and takes the window down when `body` returns.
    private func withHost<Root: View>(_ root: Root, body: () async throws -> Void) async throws {
        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
            "The test host has no window scene to lay out in")
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        window.rootViewController = UIHostingController(rootView: root)
        window.isHidden = false
        window.layoutIfNeeded()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        try await body()
    }

    /// Waits up to three seconds for `condition`, letting the main queue run between looks.
    private func settles(_ condition: () -> Bool) async throws -> Bool {
        for _ in 0..<150 {
            if condition() { return true }
            try await Task.sleep(for: .milliseconds(20))
        }
        return condition()
    }

    /// The control: with the store there from the start, the head loads. So a failure below is the
    /// loader's, not the host's.
    @Test("With the store there from the start, the row's head loads")
    func headLoadsWithTheStoreThere() async throws {
        let database = try Database(rows: ["frus1946v06/d474": Self.head])
        defer { database.remove() }
        let probe = Probe()
        probe.store = try database.store()
        try await withHost(Rows(probe: probe)) {
            let loaded = try await settles { probe.headers["frus1946v06/d474"]?.header == Self.head }
            #expect(loaded, "the head did not load with the store there: \(probe.headers)")
        }
    }

    /// #1946's first sighting: the window was up before boot set the store.
    @Test("A row up before the store loads its head when the store arrives")
    func headLoadsWhenTheStoreArrives() async throws {
        let database = try Database(rows: ["frus1946v06/d474": Self.head])
        defer { database.remove() }
        let probe = Probe()
        try await withHost(Rows(probe: probe)) {
            // The load has run with no store, and kept nothing.
            try await Task.sleep(for: .milliseconds(300))
            #expect(probe.headers.isEmpty)
            probe.store = try database.store()
            let loaded = try await settles { probe.headers["frus1946v06/d474"]?.header == Self.head }
            #expect(loaded, "the store arrived and the row kept its id: no load was made with it")
        }
    }

    /// The stores are reopened after every indexing batch (`AppState.refreshReadOnlyStores()`). A
    /// load made while the volume's rows were not there, as in the middle of its re-index, is made
    /// again with the new store.
    @Test("A row whose head was not in the index loads it when the store is reopened")
    func headLoadsWhenTheStoreIsReopened() async throws {
        let before = try Database(rows: [:])
        defer { before.remove() }
        let after = try Database(rows: ["frus1946v06/d474": Self.head])
        defer { after.remove() }
        let probe = Probe()
        probe.store = try before.store()
        try await withHost(Rows(probe: probe)) {
            // The load has run with the first store, which has no row for the document.
            try await Task.sleep(for: .milliseconds(300))
            #expect(probe.headers.isEmpty)
            probe.store = try after.store()
            let loaded = try await settles { probe.headers["frus1946v06/d474"]?.header == Self.head }
            #expect(loaded, "the store was reopened and the row kept its id: no load was made with it")
        }
    }
}
#endif

// MARK: - ResearchRowsRedrawSourceTests

/// `ResearchView`'s body reads the rows' heads, as the rows do (L38, #1946).
///
/// In the Mac check copy, with the Research window opened from the menu after launch, the log said
/// all nine heads were read from the store and merged while every row still showed its id (*d474*,
/// *d473*, …) until the sidebar's selection changed. The rows read `documentHeaders` inside the
/// list's `ForEach`, under the split view's detail column, and the view's own body never read it.
/// The body now reads it too, so a merge runs the body again and builds the rows anew; the rows still
/// read the state themselves, so a list pushed on the iPhone's stack sees the heads whether or not
/// its destination closure runs again. The unit target runs no Mac code; this reads the view's
/// source, comments removed, and the check copy shows the rows themselves.
///
/// Version history:
///   1.0 — L38 (#1946): initial implementation
@Suite("Research rows — the view's body reads the heads (#1946)")
struct ResearchRowsRedrawSourceTests {

    private static func code() throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return NaturalLanguageReadinessScanTests.code(
            try String(contentsOf: root.appending(path: "FRUSExplorer/Research/ResearchView.swift"), encoding: .utf8))
    }

    /// One function's or property's brace body, whitespace collapsed.
    private static func body(after declaration: String, in code: String) throws -> String {
        let start = try #require(code.range(of: declaration), "ResearchView has no \(declaration)")
        let range = try #require(NaturalLanguageReadinessScanTests.braceBody(in: code, after: start.upperBound))
        return code[range].split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    @Test("The body reads the heads before it builds any layout")
    func bodyReadsTheHeads() throws {
        let container = try Self.body(after: "private var navigationContainerBody: some View", in: try Self.code())
        #expect(container.hasPrefix("let _ = documentHeaders"),
                "the body does not read the heads, so a merge may not redraw the Mac's rows: \(container.prefix(200))")
    }

    @Test("A row still reads its head from the state")
    func rowsReadTheState() throws {
        let row = try Self.body(after: "private func documentRow(_ entry: ResearchDocumentEntry) -> some View",
                                in: try Self.code())
        #expect(row.contains("let facts = documentHeaders[entry.id]"),
                "a row no longer reads its head from the state, which a list pushed on the iPhone's stack needs")
    }
}
