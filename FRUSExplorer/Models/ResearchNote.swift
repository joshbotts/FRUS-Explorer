// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftData

// MARK: - ResearchNote

/// A user annotation attached to a specific FRUS document.
///
/// ## Project Tagging
/// `projectIds` carries the project tags applied to this note. A note is created
/// with the currently active project's ID (if any). Users can subsequently add or
/// remove project tags. A note is never deleted when a project tag is removed —
/// removal only hides the note from that project's lens.
///
/// ## Cross-Project Visibility
/// When a user views a document in a project that does not own this note, the note
/// is hidden by default but signaled via a disclosure indicator. The user can reveal
/// and optionally promote the note to the current project by adding its ID to
/// `projectIds`.
///
/// ## Selected Summaries
/// `selectedSummaryIds` lists `GeneratedSummary.id` values the user has promoted
/// to draft content in this note. The summaries are not embedded in the note —
/// they are referenced by ID so that note text remains the user's own words.
///
/// Version history:
///   1.0 — Session 04: initial implementation
///   1.1 — #1275: `richText`, the formatted body, with `bodyText` kept as its plain projection
@Model final class ResearchNote {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Document Reference

    /// The FRUS document this note is attached to.
    var documentId: String = "" {
        didSet { lastModified = .now }
    }

    /// The volume containing the document.
    var volumeId: String = "" {
        didSet { lastModified = .now }
    }

    // MARK: - Content

    /// The user's note text as PLAIN text — and the authoritative copy for everything that reads a
    /// note without rendering it.
    ///
    /// Since #1275 it is the plain projection of ``richText`` when that is present, exactly as
    /// `CollectionEntry.text` projects `CollectionEntry.richText`. Search indexing, the Zotero and
    /// Obsidian exports, the JSON envelope and all five in-app previews read THIS and are unchanged
    /// by rich text existing — which is the whole reason the formatted copy is stored beside the
    /// plain one rather than replacing it.
    var bodyText: String = "" {
        didSet { lastModified = .now }
    }

    /// The note body as RTF, when the reader has formatted it (#1275).
    ///
    /// `nil` for a note written before rich text, or one whose body carries no formatting — and a
    /// reader of a note must treat `nil` as "use ``bodyText``", never as "empty". The exact shape
    /// `CollectionEntry.richText` established, down to the `Data?`: RTF rather than an encoded
    /// `AttributedString`, because the three collection exporters already render RTF spans, and
    /// rather than Markdown-in-`bodyText`, which would have shipped literal asterisks to five
    /// in-app previews, three export formats and the reader's Zotero library.
    ///
    /// **This property is why #1275 needed a CloudKit Production deploy** — see
    /// `CloudKitSchemaInventory`.
    ///
    /// ## What does NOT carry it
    /// A `.fruscollection` file writes a document's notes as bare strings and rebuilds them from
    /// `bodyText` alone, so formatting survives this device and iCloud but not a collection shared
    /// with a colleague and reimported — while a formatted prose block a few bytes away in the same
    /// file does survive, because that format carries `CollectionEntry.richText`. Widening the note
    /// payload is a file-format change and is deliberately not part of #1275; both manuals say so.
    var richText: Data? {
        didSet { lastModified = .now }
    }

    // MARK: - Tags and References

    /// IDs of `Project` records whose lens this note appears in.
    var projectIds: [UUID] = [] {
        didSet { lastModified = .now }
    }

    /// IDs of `UserTag` records the user has applied to this note.
    var userTagIds: [UUID] = [] {
        didSet { lastModified = .now }
    }

    /// IDs of `GeneratedSummary` records the user has promoted to draft content here.
    var selectedSummaryIds: [UUID] = [] {
        didSet { lastModified = .now }
    }

    // MARK: - Timestamps

    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var createdAt: Date?
    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var lastModified: Date?

    // MARK: - Search indexing

    /// The separator between two notes in a document's indexed text.
    ///
    /// A blank line, because that is how the notes read when a reader sees them listed — and
    /// because FTS5's `unicode61` tokenizer treats it as a token boundary, so no word is joined to
    /// its neighbour across it. It is never displayed: result snippets are cut from the TEI body
    /// (`SearchService.makeContextSnippet`), never from this column.
    ///
    /// **One residue, accepted deliberately.** Adjacent token POSITIONS survive the separator, so a
    /// quoted phrase whose first word ends one note and whose second word begins the next can match.
    /// Suppressing that needs a sentinel token in the text, which would itself be searchable and
    /// would surface in any future snippet built from this column. The false positive returns a
    /// document the reader annotated twice, on words they themselves wrote — the cheapest possible
    /// kind of wrong answer, and cheaper than the cure.
    static let indexedTextSeparator = "\n\n"

    /// One indexed text per document: every note on it, oldest first.
    ///
    /// ## Why a JOIN, where summaries take the newest
    /// `GeneratedSummary.newestNonDraftPerDocument` picks ONE, because a document has one current
    /// summary and the others are superseded or collection-private drafts. Notes are the opposite:
    /// each is the reader's own writing, kept on purpose, and the Research tab lists them all. A
    /// document can carry many — `DocumentView` opens a fresh editor for every new note and again
    /// per highlighted passage — so picking one would be the defect rather than the fix.
    ///
    /// ## Ordering is a TOTAL order, and not by `lastModified`
    /// `createdAt` then `id`. `lastModified` is a SAVE stamp that `ModelModificationStamper` bumps
    /// for unrelated reasons, so ordering on it would let a bulk rewrite silently reshuffle the
    /// indexed text; `createdAt` is never stamped. The id tie-break makes the result reproducible
    /// when two notes share a timestamp, so two devices' replays write identical text and the
    /// row-skipping UPDATE stays a no-op instead of churning the FTS5 index.
    ///
    /// Notes with a blank id pair are skipped: they can index nothing. Empty bodies are dropped
    /// before joining, so a blank note cannot pad the text with separators.
    ///
    /// - Parameter notes: Every note to consider, in any order.
    /// - Returns: One row per document that has at least one non-empty note, keyed for the caller.
    static func indexedTextPerDocument(
        _ notes: [ResearchNote]
    ) -> [(volumeId: String, documentId: String, text: String)] {
        var byDocument: [String: [ResearchNote]] = [:]
        for note in notes where !note.volumeId.isEmpty && !note.documentId.isEmpty {
            byDocument["\(note.volumeId)/\(note.documentId)", default: []].append(note)
        }
        return byDocument.keys.sorted().compactMap { key in
            guard let group = byDocument[key] else { return nil }
            let ordered = group.sorted {
                let left = $0.createdAt ?? .distantPast
                let right = $1.createdAt ?? .distantPast
                if left != right { return left < right }
                return $0.id.uuidString < $1.id.uuidString
            }
            let text = ordered.map(\.bodyText)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: indexedTextSeparator)
            guard !text.isEmpty else { return nil }
            let first = ordered[0]
            return (volumeId: first.volumeId, documentId: first.documentId, text: text)
        }
    }


    /// What a rebuild should do to one document's `document_cache.note_text` (#1280).
    enum IndexWrite: Equatable {
        /// Write this text — the document's notes, joined.
        case write(String)
        /// Empty the column: the document's last note is gone.
        case clear
        /// Touch nothing.
        case skip
    }

    /// The write a document's notes call for, with **no notes at all** and **no notes readable**
    /// held apart (#1280).
    ///
    /// The distinction is the whole reason this is a function rather than three lines at the call
    /// site. Both answers available on the evidence of a failed read are destructive: clearing
    /// erases a document's notes from the index, and writing the one note the caller happens to
    /// hold hides the others. So an unreadable set is ``IndexWrite/skip`` — the row keeps whatever
    /// it holds, and the boot replay rebuilds it from every note at the next launch. An empty set
    /// that really is empty is ``IndexWrite/clear``, because nothing else ever empties this column.
    ///
    /// - Parameter notes: **One document's** notes, or `nil` when they could not be read. A set
    ///   spanning several documents yields the lowest-keyed one's text, which the caller would then
    ///   write under the key it asked about — so fetch by `(volumeId, documentId)`, as
    ///   ``reindexNoteText(volumeId:documentId:in:pipeline:)`` does.
    /// - Returns: What to do with the column.
    static func noteTextWrite(for notes: [ResearchNote]?) -> IndexWrite {
        guard let notes else { return .skip }
        if let text = indexedTextPerDocument(notes).first?.text { return .write(text) }
        return .clear
    }

    /// The whole library's note-text plan: what to write, and what to clear (#1280).
    ///
    /// The replay half of the rule ``reindexNoteText(volumeId:documentId:in:pipeline:)`` applies per
    /// document. It is a function rather than a loop inside the replay because the decision it
    /// makes is destructive and the loop around it is not the place to argue one.
    ///
    /// ## No note RECORDS at all is not a fact about the reader, and it may not clear anything
    /// The clear half is the only code in the app that empties this column in bulk, so it refuses
    /// the one input that is far likelier to be a store than a decision: **an empty or unreadable
    /// note set while the index still carries rows.**
    ///
    /// `nil` is the thrown fetch — ``noteTextWrite(for:)``'s distinction at the grain of a library,
    /// where `?? []` at the call site would read a failure as "no notes". But a SUCCESSFUL fetch
    /// returning nothing is the more dangerous reading, because no `try?` can catch it: the local
    /// store is a file on disk that survives launches, so a reader holding indexed note text and
    /// zero note records has almost certainly just had that store rebuilt or swapped. **Two
    /// mechanisms in this app do exactly that, and `frus.db` — where this column lives — is a
    /// different file that neither touches:**
    ///
    /// - `PendingStoreReset` (Settings ▸ Data & Recovery ▸ Fix iCloud Sync) deletes `default.store`
    ///   at the next launch and lets CloudKit refill it.
    /// - `makeFRUSContainer` falls back to `makeLocalContainer`, a **different store file**
    ///   (`FRUSExplorerLocal.store`), whenever the CloudKit container fails to initialise. Nothing
    ///   throws and nothing is lost; the fetch simply reads a store that has never held a note.
    ///
    /// Sweeping in either case would empty every note row the reader owns at the exact moment their
    /// notes are safe elsewhere and have simply not arrived. The two readings are one refusal
    /// because they are one condition; they are named separately because only the second is a
    /// judgement — and because only the first is what a `nil` check would have caught.
    ///
    /// **The floor counts RECORDS, not indexable text.** A reader whose notes all have empty bodies
    /// has a store that plainly loaded, and their column should go back to empty — so that case
    /// clears, where a floor written on the joined text would have refused it.
    ///
    /// **The refusal has a cost and it is the right way round.** A reader whose LAST note was
    /// deleted on another device keeps that one row until they write another note anywhere — every
    /// in-app deletion still clears through `reindexNoteText`, so this is only the cross-device
    /// case, and only for the final note. Set against emptying a whole library's indexed notes after
    /// a sync repair, one stale row is the cheaper mistake.
    ///
    /// - Parameters:
    ///   - notes: Every note to replay, or `nil` when they could not be read.
    ///   - carrying: The documents whose column currently holds text —
    ///     ``IndexingPipeline/documentsWithNoteText()``. Read it at the same moment as `notes`: the
    ///     two are opposite sides of one subtraction, and a gap between the reads lets a note
    ///     written in between be planned for clearing.
    /// - Returns: The rows to write, and the rows to clear.
    ///
    /// **Library-grained, with no volume scope, and that is the floor's doing.** A plan scoped to
    /// one volume would read "this reader has no notes IN THIS VOLUME" — the ordinary state of
    /// almost every volume — as the store being broken, and refuse on it. The floor is a statement
    /// about the whole store, so only a whole-store read can make it.
    static func noteTextPlan(
        for notes: [ResearchNote]?,
        carrying: [(volumeId: String, documentId: String)]
    ) -> (writes: [(volumeId: String, documentId: String, text: String)],
          clears: [(volumeId: String, documentId: String)]) {
        // One guard, because unreadable and empty are one condition — and it counts RECORDS, not
        // the joined text, so a reader whose notes all have empty bodies still clears.
        guard let notes, !notes.isEmpty || carrying.isEmpty else { return (writes: [], clears: []) }
        let writes = indexedTextPerDocument(notes)
        let kept = Set(writes.map { "\($0.volumeId)/\($0.documentId)" })
        let clears = carrying.filter { !kept.contains("\($0.volumeId)/\($0.documentId)") }
        return (writes: writes, clears: clears)
    }

    /// Replays every note into the index, and — when asked — clears the rows no note accounts for.
    ///
    /// The library-grained twin of ``reindexNoteText(volumeId:documentId:in:pipeline:)``, and the
    /// only caller of ``noteTextPlan(for:carrying:)``.
    ///
    /// ## Why the sweep is a parameter and not simply what this does
    /// The write half is safe anywhere — it is value-guarded and idempotent — and must run at boot,
    /// or a note written in a previous session never reaches a rebuilt index. The clear half is the
    /// only bulk delete of a reader's writing in the app, and its floor (see `noteTextPlan`) is
    /// disarmed by a store that is PARTIALLY loaded: one note arrived from CloudKit is enough to
    /// make the set non-empty, and every document whose note is in a later batch would be cleared.
    ///
    /// So the sweep runs where this app already puts reconciliation that must not see a half-synced
    /// store — the import-settle debounce, beside `OrphanedTagRepair`, `DuplicateRecordCleanup` and
    /// `AnnotationReviewStore.reconcile`, whose comments make the same argument. At boot it runs
    /// only when CloudKit is off, because then no import can arrive to make the store fuller than
    /// it already is, and deferring would mean a reader with no iCloud account never swept at all.
    ///
    /// - Parameters:
    ///   - container: The model container to read the reader's notes from.
    ///   - pipeline: The index to write through.
    ///   - sweepingStaleRows: Whether to apply the clear half.
    nonisolated static func reconcileNoteText(
        container: ModelContainer,
        pipeline: IndexingPipeline,
        sweepingStaleRows: Bool
    ) async {
        let context = ModelContext(container)
        // Both sides of the subtraction in ONE expression, before any suspension: an index read
        // taken after the write loop's awaits sees a note written DURING the replay that the note
        // snapshot does not, and plans a clear for it.
        let plan = noteTextPlan(
            for: try? context.fetch(FetchDescriptor<ResearchNote>()),
            carrying: sweepingStaleRows ? ((try? pipeline.documentsWithNoteText()) ?? []) : [])
        // Clears first, so the window in which a note written by `reindexNoteText` during this pass
        // could be cleared is the length of this loop — usually empty — rather than the length of
        // the write loop below it.
        for row in plan.clears {
            try? await pipeline.clearNoteText(volumeId: row.volumeId, documentId: row.documentId)
        }
        for entry in plan.writes {
            // Text only — a note has no business writing the document's TAG column (#1275).
            try? await pipeline.updateNoteText(volumeId: entry.volumeId,
                                               documentId: entry.documentId, bodyText: entry.text)
        }
    }

    /// Rewrites one document's `document_cache.note_text` from the notes it still has (#1280).
    ///
    /// **The only per-document writer of that column.** Four callers used to write it, each pushing
    /// the body of the ONE note it happened to be holding — no fetch of the document's other notes,
    /// no join, and no clear anywhere, which is the whole of #1280. They are one call now for the
    /// reason the Source Explorer twins record: a rule written out four times is four places for it
    /// to diverge, and this one had already diverged in its arguments before it diverged in its
    /// answer. (The library-grained replays go through
    /// ``reconcileNoteText(container:pipeline:sweepingStaleRows:)`` instead — same rule, a grain
    /// this per-document entry point cannot express.)
    ///
    /// ## It re-reads rather than being told
    /// Every caller has a note in hand — the one just written, or the one just deleted — and none of
    /// them may speak for the column, because it is per DOCUMENT and a document can carry many
    /// notes. Callers must `save()` first: the fetch is what includes a note just added and excludes
    /// one just deleted, which is what lets a delete path reuse this with no separate clear.
    ///
    /// - Parameters:
    ///   - volumeId: The document's volume.
    ///   - documentId: The document.
    ///   - context: The context holding the reader's notes.
    ///   - pipeline: The index to write through.
    @MainActor
    static func reindexNoteText(
        volumeId: String,
        documentId: String,
        in context: ModelContext,
        pipeline: IndexingPipeline
    ) async {
        let descriptor = FetchDescriptor<ResearchNote>(
            predicate: #Predicate { $0.volumeId == volumeId && $0.documentId == documentId })
        switch noteTextWrite(for: try? context.fetch(descriptor)) {
        case .write(let text):
            try? await pipeline.updateNoteText(volumeId: volumeId, documentId: documentId,
                                               bodyText: text)
        case .clear:
            // The document's last note is gone. Nothing else empties this column, so without the
            // clear the deleted words stay searchable for the life of the install.
            try? await pipeline.clearNoteText(volumeId: volumeId, documentId: documentId)
        case .skip:
            break
        }
    }

    // MARK: - Initializer

    init(
        documentId: String,
        volumeId: String,
        bodyText: String = "",
        projectIds: [UUID] = [],
        userTagIds: [UUID] = [],
        selectedSummaryIds: [UUID] = []
    ) {
        self.id = UUID()
        self.documentId = documentId
        self.volumeId = volumeId
        self.bodyText = bodyText
        self.projectIds = projectIds
        self.userTagIds = userTagIds
        self.selectedSummaryIds = selectedSummaryIds
        let now = Date.now
        createdAt = now
        lastModified = now

        #if DEBUG
        print("[SwiftData] ResearchNote created: \(id) for \(volumeId)/\(documentId)")
        #endif
    }
}
