// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - ResearchDocumentAggregation

/// The rule for which documents the Research list shows, and the sentence a recorded change gets
/// (R-5 P2). Pure, so the coverage claim the design's §5.6 rests on — *a review flow is a filter
/// over this aggregation* — can be tested without a view.
///
/// Version history:
///   1.0 — R-5 P2: extracted from `ResearchView` and widened to six sources
///   1.1 — R-5 P3b-1: `rowDestination`, and headnote drafts excluded
///   1.2 — R-5 P3b-4: `countsAsAnnotation` — excerpt entries join the collections source
///   1.3 — Session 2026-10-25 (FRUS Explorer Light, S17b): moved into FRUSCoreKit from the app's
///          `Research/ResearchView.swift`, public, its rules over values (``distinctDocumentKeys(among:)``,
///          ``annotatedKeys(among:)``, ``summaryCounts(among:)``) and otherwise unchanged, for the web
///          edition's Research page; the overloads over the app's models stay in `ResearchView.swift`, and
///          pass their rows here as values
public enum ResearchDocumentAggregation {

    /// Which collection-entry kinds put their document into the reader's research (R-5 P3b-4,
    /// design Q-7 b).
    ///
    /// A `.document` entry says *this document belongs in my collection*; an `.excerpt` says
    /// *these words from it do*, which is a stronger claim about the text, not a weaker one — an
    /// excerpt is the one annotation whose whole content is a verbatim copy of what an update can
    /// correct. Before P3b-4 a document carrying only an excerpt was absent from "All Research
    /// Documents" and from "Changed by an update", while the same document DID appear under its
    /// collection in the same sidebar (`collectionMemberships` counts every entry with a document
    /// id), so widening this settles a disagreement inside one view. It also makes the hub's
    /// footer true: it promises a "collection entry" counts, and an excerpt is one.
    ///
    /// The other kinds cannot contribute and are refused by name rather than by their empty ids:
    /// `.heading` and `.prose` carry no document, `.generated` is computed at every resolve, and
    /// `.unrecognized` is a kind written by a NEWER build — admitting it would let a future entry
    /// type silently claim a document this build cannot describe.
    ///
    /// **This rule is the review filter's alone.** `ProjectEngagedDocuments`,
    /// `ProjectLeadsService` and `DocumentEngagementService` keep the `.document` test: they
    /// answer *what have I worked on in this project*, they feed published coverage numbers and
    /// an exported method appendix, and a quotation is not a document a reader engaged with.
    public static func countsAsAnnotation(_ entryKind: String) -> Bool {
        entryKind == CollectionEntryKind.document.rawValue
            || entryKind == CollectionEntryKind.excerpt.rawValue
    }

    /// The DISTINCT documents a collection's entries name, under ``countsAsAnnotation``.
    ///
    /// This is the Research sidebar's per-collection number, and it is a set rather than a count
    /// so that it equals the length of the list the row opens. The number used to be
    /// `documentEntries.count` — every entry of every kind — so a collection of three documents
    /// under two headings showed "5" and opened a list of three, and a document both quoted and
    /// added counted twice. Both were already wrong before P3b-4; what P3b-4 changes is that the
    /// list this number labels now includes documents reached only by a quotation, so a count that
    /// disagreed with it would disagree more visibly.
    ///
    /// **It deliberately differs from the Collections feature's own per-collection counts**
    /// (`Collection.documentCount`, read by the Collections list, `CollectionPickerSheet` and the
    /// macOS manager since #1358; and `CollectionEditorView`, `CollectionExportSheet`,
    /// `CollectionPreviewView`), which count `.document` ENTRIES. Those answer *how many documents
    /// does this collection contain*, which is a fact about its composition. This one labels a row
    /// that opens a list of the reader's annotated documents, so it answers *how many documents
    /// will I see if I tap this*, and it must equal that list or it is simply wrong.
    public static func distinctDocumentKeys(among entries: [Entry]) -> Set<String> {
        var keys = Set<String>()
        for e in entries where countsAsAnnotation(e.kind) && !e.volumeId.isEmpty && !e.documentId.isEmpty {
            keys.insert("\(e.volumeId)/\(e.documentId)")
        }
        return keys
    }

    /// Every `"volumeId/documentId"` carrying at least one annotation, across six sources.
    ///
    /// The two added for P2 are the ones a correction is most likely to supersede: a
    /// `GeneratedSummary` is derived from the text, and an `ArchiveVisitDocument`'s plan from the
    /// source note. Before P2 a document carrying only one of those did not appear here at all.
    /// The collections source counts the kinds ``countsAsAnnotation`` admits — since P3b-4 that
    /// includes excerpts, whose frozen text is a verbatim copy of what an update corrects.
    public static func annotatedKeys(among sources: Sources) -> Set<String> {
        var keys = Set<String>()
        for n in sources.notes where !n.volumeId.isEmpty && !n.documentId.isEmpty { keys.insert("\(n.volumeId)/\(n.documentId)") }
        for t in sources.tagAssignments where !t.volumeId.isEmpty && !t.documentId.isEmpty { keys.insert("\(t.volumeId)/\(t.documentId)") }
        for c in sources.collections {
            for e in c where ResearchDocumentAggregation.countsAsAnnotation(e.kind)
                && !e.volumeId.isEmpty && !e.documentId.isEmpty {
                keys.insert("\(e.volumeId)/\(e.documentId)")
            }
        }
        for h in sources.highlights where !h.volumeId.isEmpty && !h.documentId.isEmpty { keys.insert("\(h.volumeId)/\(h.documentId)") }
        // Headnote DRAFTS are excluded (R-5 P3b-1, design Q-8): they are collection-private, the only
        // user-authored summaries, and excluded from every carousel — a row reading "1 summaries"
        // for one would name research the document view never lists. The draft's owning entry
        // already puts the document in this set through the collections loop.
        for g in sources.summaries where !g.isHeadnoteDraft && !g.volumeId.isEmpty && !g.documentId.isEmpty {
            keys.insert("\(g.volumeId)/\(g.documentId)")
        }
        for v in sources.visitDocumentKeys where !v.isEmpty { keys.insert(v) }
        return keys
    }

    /// Per-document count of the summaries a Research row may name — drafts excluded, for the
    /// reason `annotatedKeys` gives.
    public static func summaryCounts(among summaries: [Summary]) -> [String: Int] {
        var result: [String: Int] = [:]
        for summary in summaries where !summary.isHeadnoteDraft
            && !summary.volumeId.isEmpty && !summary.documentId.isEmpty {
            result["\(summary.volumeId)/\(summary.documentId)", default: 0] += 1
        }
        return result
    }

    /// Where a tap on a row goes (R-5 P3b-1, design Q-11 h).
    public enum RowDestination: Equatable, Sendable {
        /// The review sheet — the only surface that can open on a document that no longer exists.
        case reviewSheet
        /// The document itself.
        case document
    }

    /// A vanished document routes to the sheet whether or not its change has been reviewed;
    /// `revision` alone is not enough, because it is nil once the reader has marked it reviewed.
    public static func rowDestination(revision: IndexingPipeline.DocumentRevision?, isVanished: Bool) -> RowDestination {
        if isVanished || revision?.changeKind == "vanished" { return .reviewSheet }
        return .document
    }

    /// The one sentence for a document an update removed, shared by the unreviewed line and the
    /// reviewed-but-still-gone line.
    public static var vanishedLine: String {
        String(localized: "research.row.changed.vanished", defaultValue: "No longer in the volume")
    }

    /// The row's sentence for a recorded change, or `nil` for a kind the app does not know.
    ///
    /// Each names what is provable from two hashes and no more: "changed", "positions may have
    /// moved", "no longer in the volume". None says the reader's annotation is wrong.
    public static func changeLine(for revision: IndexingPipeline.DocumentRevision) -> String? {
        switch revision.changeKind {
        case "body":
            return String(localized: "research.row.changed.body",
                          defaultValue: "Text changed in an update — highlight positions may have moved")
        case "apparatus":
            return String(localized: "research.row.changed.apparatus",
                          defaultValue: "Footnotes, source note, or heading changed in an update — the text did not")
        case "vanished":
            return vanishedLine
        default:
            return nil
        }
    }
}

// MARK: - The values the rules read

extension ResearchDocumentAggregation {

    /// A collection entry's values, as the rules read them (`CollectionEntry`'s).
    public struct Entry: Sendable, Equatable {
        /// The entry's kind, as `CollectionEntry.kind` stores it.
        public var kind: String
        /// The named document's volume, empty for an entry that names none.
        public var volumeId: String
        /// The named document, empty for an entry that names none.
        public var documentId: String

        /// Creates an entry's values.
        public init(kind: String, volumeId: String, documentId: String) {
            self.kind = kind
            self.volumeId = volumeId
            self.documentId = documentId
        }
    }

    /// A document a note, a tag assignment or a highlight is on.
    public struct DocumentRef: Sendable, Equatable {
        /// The document's volume, empty for a record on no document.
        public var volumeId: String
        /// The document, empty for a record on no document.
        public var documentId: String

        /// Creates a reference.
        public init(volumeId: String, documentId: String) {
            self.volumeId = volumeId
            self.documentId = documentId
        }
    }

    /// A summary's values, as the rules read them (`GeneratedSummary`'s).
    public struct Summary: Sendable, Equatable {
        /// The summarized document's volume.
        public var volumeId: String
        /// The summarized document.
        public var documentId: String
        /// Whether the summary is a collection's headnote draft.
        public var isHeadnoteDraft: Bool

        /// Creates a summary's values.
        public init(volumeId: String, documentId: String, isHeadnoteDraft: Bool) {
            self.volumeId = volumeId
            self.documentId = documentId
            self.isHeadnoteDraft = isHeadnoteDraft
        }
    }

    /// The six sources ``annotatedKeys(among:)`` reads, as values.
    public struct Sources: Sendable, Equatable {
        /// Every research note.
        public var notes: [DocumentRef]
        /// Every direct document-tag assignment.
        public var tagAssignments: [DocumentRef]
        /// Every collection, as its entries.
        public var collections: [[Entry]]
        /// Every highlight.
        public var highlights: [DocumentRef]
        /// Every generated summary, drafts included; the rule leaves the drafts out.
        public var summaries: [Summary]
        /// Every archive-visit document, as its `documentKey`.
        public var visitDocumentKeys: [String]

        /// Creates the sources.
        public init(notes: [DocumentRef], tagAssignments: [DocumentRef], collections: [[Entry]],
                    highlights: [DocumentRef], summaries: [Summary], visitDocumentKeys: [String]) {
            self.notes = notes
            self.tagAssignments = tagAssignments
            self.collections = collections
            self.highlights = highlights
            self.summaries = summaries
            self.visitDocumentKeys = visitDocumentKeys
        }
    }
}
