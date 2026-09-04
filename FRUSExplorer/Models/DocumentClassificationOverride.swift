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

// MARK: - DocumentClassificationOverride

/// A user's correction of one document's editorial-note-vs-document classification (#279 / W-4).
///
/// FRUS TEI mistags some documents — `subtype="editorial-note"` present where the content is a
/// primary document, or absent where it is an editorial note — and the app's flag
/// (`document_cache.is_editorial_note`) is a faithful read of that attribute, so the mistag
/// reaches every badge, filter, facet, count, and export. This record is the researcher's
/// reversible assertion of the correct classification.
///
/// ## The CloudKit compatibility contract (the `PersonClusterOverride` precedent)
/// Anchors are the STABLE `(volumeId, documentId)` pair — never a rowid, which reindexing can
/// reassign. All stored properties have defaults; there are no `@Relationship` declarations.
/// An override whose volume is not indexed on this device is a silent no-op that reactivates
/// automatically when the volume is indexed (the same rule `PersonClusterOverride` states).
///
/// ## How it is applied — and why the original value is stored
/// `IndexingPipeline.applyClassificationOverrides` writes the override INTO
/// `document_cache.is_editorial_note` (value-guarded; the column is UNINDEXED in FTS5, so the
/// update needs no index maintenance and is instantly visible to every query). A re-index
/// restores the parsed TEI value — the upsert's `DO UPDATE SET` deliberately keeps doing that,
/// because an upstream TEI fix must keep propagating for every non-overridden document — so
/// overrides are REPLAYED after indexing, the same way summaries and notes are.
/// ``parsedIsEditorialNote`` records what the TEI said at override time, so REMOVING an
/// override can restore the original without a re-parse.
///
/// **It is written once and NOTHING ever refreshes it** — not `setOverride`'s update branch
/// (which is unreachable from the app: the rail removes rather than re-sets), and not a re-index.
/// `applyClassificationOverrides` writes only `document_cache.is_editorial_note`; a re-index
/// corrects THAT COLUMN for un-overridden documents and then the replay re-asserts the override
/// over it, so the snapshot on this record never moves. An earlier version of this comment claimed
/// the re-index corrected the drift; it does not, and R-5 P3b-5 (design Q-11 i) is what that cost:
/// after the Office of the Historian fixed the same mistag a reader had corrected, the rail said
/// "FRUS tags this as…" from the stale value and un-overriding wrote it back into the index.
/// Both surfaces now prefer the live parse, by DIFFERENT routes and with different fallbacks, and
/// the difference matters to anyone deciding whether this field still earns its place. The research
/// rail reads `DocumentViewModel.parsedIsEditorialNote` — the AST is already in hand — and falls
/// back here only while the document has not finished loading. The Settings corrections sheet has
/// no document at all, so it re-parses the TEI through ``liveParsedIsEditorialNote`` and falls back
/// here whenever the volume is not on this device, which is the ORDINARY case for a correction made
/// before the volume was freed. So this field is not a brief load-time placeholder: it is the value
/// the Settings Undo uses on every override whose volume is gone, and the value of record for what
/// was observed AT OVERRIDE TIME.
///
/// One override per document: ``DocumentClassificationOverrideStore/setOverride`` upserts on
/// the anchor rather than inserting duplicates.
///
/// Version history:
///   1.0 — W-4 (#279): initial implementation
@Model final class DocumentClassificationOverride {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Anchor

    /// The document's volume — half of the stable anchor.
    var volumeId: String = ""
    /// The document's id within it — the other half.
    var documentId: String = ""

    // MARK: - The assertion

    /// The user's classification: `true` = this IS an editorial note, `false` = this is a
    /// primary document.
    var isEditorialNote: Bool = false

    /// What the TEI's own parse said when the override was created — the restore value for
    /// the un-override path. A snapshot, corrected by the next re-index if upstream changed.
    var parsedIsEditorialNote: Bool = false

    // MARK: - Timestamp

    /// Optional for CloudKit schema compatibility — always non-nil in practice. The dedupe
    /// keeper tie-break reads it.
    var createdAt: Date? = nil

    // MARK: - Init

    init(volumeId: String, documentId: String,
         isEditorialNote: Bool, parsedIsEditorialNote: Bool) {
        self.id = UUID()
        self.volumeId = volumeId
        self.documentId = documentId
        self.isEditorialNote = isEditorialNote
        self.parsedIsEditorialNote = parsedIsEditorialNote
        self.createdAt = Date()
    }

    /// The stable anchor key, matching the composite the index speaks.
    var documentKey: String { "\(volumeId)/\(documentId)" }

    /// A `Sendable` snapshot for crossing into the `IndexingPipeline` actor.
    var snapshot: DocumentClassificationOverrideData {
        DocumentClassificationOverrideData(volumeId: volumeId, documentId: documentId,
                                           isEditorialNote: isEditorialNote,
                                           parsedIsEditorialNote: parsedIsEditorialNote)
    }
}

// MARK: - DocumentClassificationOverrideData

/// The `Sendable` value form of an override, for the SwiftData → pipeline-actor crossing.
/// `public` because `IndexingPipeline`'s (public) apply entry point takes it.
public struct DocumentClassificationOverrideData: Equatable, Sendable {
    /// The document's volume — half of the stable anchor.
    public let volumeId: String
    /// The document's id within it — the other half.
    public let documentId: String
    /// The user's classification assertion.
    public let isEditorialNote: Bool
    /// The TEI's own value at override time — the restore value.
    public let parsedIsEditorialNote: Bool

    /// Memberwise, spelled out because `public` suppresses the synthesized one.
    public init(volumeId: String, documentId: String,
                isEditorialNote: Bool, parsedIsEditorialNote: Bool) {
        self.volumeId = volumeId
        self.documentId = documentId
        self.isEditorialNote = isEditorialNote
        self.parsedIsEditorialNote = parsedIsEditorialNote
    }
}

// MARK: - DocumentClassificationOverrideStore

/// Static helpers over the override records — fetch, upsert, remove — plus the shared
/// persist-and-apply tail, mirroring `PersonClusterOverrideStore`'s shape (no caching;
/// every call re-fetches, because another device can change the set at any time).
///
/// Version history:
///   1.0 — W-4 (#279): initial implementation
@MainActor
enum DocumentClassificationOverrideStore {

    /// Every override, newest first.
    static func fetchAll(context: ModelContext) -> [DocumentClassificationOverride] {
        let descriptor = FetchDescriptor<DocumentClassificationOverride>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    /// The `Sendable` snapshots of every override, OLDEST first — the apply pass writes them
    /// in order and the last write wins, so a same-anchor conflict (two devices overriding
    /// the same document before a sync) resolves to the NEWEST assertion.
    static func snapshot(context: ModelContext) -> [DocumentClassificationOverrideData] {
        fetchAll(context: context).reversed().map(\.snapshot)
    }

    /// The override for one document, or `nil`.
    static func override(volumeId: String, documentId: String,
                         context: ModelContext) -> DocumentClassificationOverride? {
        fetchAll(context: context).first {
            $0.volumeId == volumeId && $0.documentId == documentId
        }
    }

    /// Upserts the override for one document — ONE override per anchor, so a second call
    /// updates the assertion (and refreshes `createdAt`, since it is a new correction)
    /// rather than stacking a contradiction.
    @discardableResult
    static func setOverride(volumeId: String, documentId: String,
                            isEditorialNote: Bool, parsedIsEditorialNote: Bool,
                            context: ModelContext) -> DocumentClassificationOverride {
        if let existing = override(volumeId: volumeId, documentId: documentId,
                                   context: context) {
            existing.isEditorialNote = isEditorialNote
            existing.createdAt = Date()
            return existing
        }
        let override = DocumentClassificationOverride(
            volumeId: volumeId, documentId: documentId,
            isEditorialNote: isEditorialNote, parsedIsEditorialNote: parsedIsEditorialNote)
        context.insert(override)
        return override
    }

    /// The value an un-override should put back: FRUS's classification of this document as the
    /// TEI reads NOW, or `nil` when it cannot be established here (R-5 P3b-5, design Q-11 i).
    ///
    /// **It has to come from the TEI, and it cannot come from the index.** Once an override exists
    /// the replay has written the reader's own assertion into `document_cache.is_editorial_note`,
    /// so reading the column back would restore the correction the reader is undoing. And it
    /// cannot come from the stored ``DocumentClassificationOverride/parsedIsEditorialNote``,
    /// which is frozen at override time and never refreshed — the whole reason this exists.
    ///
    /// Returns `nil` when the volume is not on this device, which is the ordinary case in Settings
    /// for a correction made before the volume was freed. The caller then falls back to the stored
    /// snapshot, which is today's behaviour: this is an improvement with a graceful floor, never a
    /// reason to refuse the Undo.
    ///
    /// The rule it applies is `FRUSDocumentAST.isShapedAsEditorialNote`, whose own doc records that
    /// it is the exact rule `IndexingPipeline` applies at index time, so the two cannot drift.
    /// - Parameter volumeURL: the volume's file on this device, or `nil` when there is no download
    ///   manager to ask — both are the same answer here, so the caller need not spell one out.
    static func liveParsedIsEditorialNote(volumeId: String, documentId: String,
                                          volumeURL: URL?) async -> Bool? {
        guard let volumeURL, FileManager.default.fileExists(atPath: volumeURL.path) else { return nil }
        guard let ast = try? await FRUSDocumentParser().parseDocument(
            documentId: documentId, volumeURL: volumeURL) else { return nil }
        return ast.isShapedAsEditorialNote
    }

    /// Removes an override. The caller restores the index column (through the shared tail
    /// below) and saves.
    static func remove(_ override: DocumentClassificationOverride, context: ModelContext) {
        context.delete(override)
    }

    /// The shared persist → apply tail: saves, snapshots the surviving set, and replays it
    /// into the index. A just-removed override's document is restored to its parsed value
    /// FIRST, through the volume-scoped entry point — deliberately not folded into the
    /// whole-set call, which caches its set on the pipeline actor for the per-volume
    /// replay: a cached restore entry would re-assert a STALE parsed snapshot over a
    /// later re-index's fresh value.
    static func saveAndApply(context: ModelContext, pipeline: IndexingPipeline,
                             restoring restore: DocumentClassificationOverrideData? = nil) async {
        try? context.save()
        if let restore {
            let restoreEntry = DocumentClassificationOverrideData(
                volumeId: restore.volumeId, documentId: restore.documentId,
                isEditorialNote: restore.parsedIsEditorialNote,
                parsedIsEditorialNote: restore.parsedIsEditorialNote)
            try? await pipeline.applyClassificationOverrides([restoreEntry],
                                                             volumeId: restore.volumeId)
        }
        try? await pipeline.applyClassificationOverrides(snapshot(context: context))
    }
}
