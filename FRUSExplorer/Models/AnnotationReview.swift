// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CryptoKit
import Foundation
import SwiftData

// MARK: - AnnotationReviewKind

/// What a review row is *about* (R-5 P3b-2).
///
/// Stored as a raw `String` on the model, the `PersonClusterOverride.kind` shape, because a
/// non-optional custom type added to an already-persisted model traps on a legacy NULL.
///
/// **Only `document` has a writer in this build.** The rest are reserved deliberately: their
/// per-annotation controls are the design's P3b-4 (excerpt entries) and P3b-5 (notes, tags,
/// summaries, visit seeds), and minting the vocabulary later would cost a SECOND CloudKit
/// Production promotion for two columns that already exist. Shipping the vocabulary now costs
/// nothing beyond the two identifiers this promotion already carries.
///
/// **`highlight` is absent, and its absence is a decision.** `DocumentHighlight.renderingVersion`
/// is already mirrored, already deployed, and already rewritten by `HighlightReview.confirm` — so
/// a highlight's review state syncs today, and a ledger row would be a second source of truth.
/// Worse, the two key on different hashes: `renderingVersion` is compared against the revision
/// row's `body_hash` (the highlight coordinate space) while this ledger keys on `content_hash`,
/// and an apparatus-only correction moves one and not the other. There is no non-arbitrary rule
/// for which wins, so highlights keep the field they have.
///
/// Version history:
///   1.0 — R-5 P3b-2: initial implementation
enum AnnotationReviewKind: String, CaseIterable, Sendable {
    /// The whole document — the reader pressed *Mark Reviewed*. The only kind written today.
    case document
    /// One `ResearchNote`. Reserved for P3b-5.
    case note
    /// One `UserTag` on a document — keyed by the **tag's** id, never the assignment's, because
    /// `UserTagPickerSheet` deletes and re-inserts every `DocumentTagAssignment` row on save.
    /// Reserved for P3b-5.
    case tag
    /// One `CollectionEntry`. Reserved for P3b-4 (excerpts) and P3b-5.
    case collectionEntry
    /// One `GeneratedSummary`. Reserved for P3b-5.
    case summary
    /// One `ArchiveVisitDocument` seed. Reserved for P3b-5.
    case visitDocument
}

// MARK: - AnnotationReview

/// One reader's disposition of one change, carried across devices (R-5 P3b-2, design §8.2 Q-3/Q-6).
///
/// ## What a row asserts, and why nothing expires it
/// *"At the moment this document's content hash was `contentHash`, this reader looked at this
/// thing."* It counts as reviewed only while the document's CURRENT
/// `document_revisions.content_hash` still equals it. A later correction moves that hash and the
/// row simply stops applying — no bookkeeping, no expiry pass, no deletion.
///
/// ## Why one ledger rather than a field on each annotation type
/// The design's Q-6 weighed a field on four to seven mirrored models (four to seven times the
/// Production promotion) against one record type. One type also gives the review state a shape
/// the annotation models do not have to know about, and lets a kind gain a writer later without
/// touching its model.
///
/// ## Why the id is derived, and why it is derived over the HASH
/// SwiftData under CloudKit cannot declare `@Attribute(.unique)`, and `DuplicateRecordCleanup`
/// groups by `id` — so a random id would hide the exact case this ledger creates, two devices
/// reviewing the same thing. `ArchiveVisitPlan.derivedChildId` is the precedent and this copies
/// its construction.
///
/// Deriving over `(kind, annotationId, document, contentHash)` rather than over the annotation
/// alone makes the ledger **append-only**, and that is the load-bearing half. Keyed on the
/// annotation alone, a row would be mutable — a re-review rewrites `contentHash` — and two
/// devices that reviewed the same annotation at different hashes would merge under CloudKit's
/// last-writer-wins with no tiebreaker: the survivor names one hash and the other device's review
/// is destroyed silently. Keyed on the hash too, the two devices mint a byte-identical row that
/// `DuplicateRecordCleanup` collapses losslessly, and no merge can lose information because there
/// is nothing to merge. The cost is one row per (annotation, correction) — bounded by how often
/// the Office of the Historian corrects a volume.
///
/// It also removes the need for `lastModified`: nothing is ever updated in place, so there is no
/// merge for a timestamp to arbitrate. **Do not add a `didSet`** — the observers on `@Model`
/// stored properties never fire (`ModelModificationStamper`).
///
/// ## Reading a ledger
/// Treat "at least one matching row" as reviewed, never "exactly one". Duplicates are collapsed
/// by a boot-time pass, not by a database constraint, so two identical rows can coexist for a
/// session.
///
/// ## The CloudKit compatibility contract
/// All stored properties carry defaults; there are no `@Relationship` declarations; the id is a
/// plain `UUID`. Adding this type is a schema change — deploy to Production before shipping.
///
/// Version history:
///   1.0 — R-5 P3b-2: initial implementation
@Model
final class AnnotationReview {

    /// Deterministic — see ``derivedId(kind:annotationId:volumeId:documentId:contentHash:)``.
    var id: UUID = UUID()

    /// The raw value of ``AnnotationReviewKind``.
    var annotationType: String = ""

    /// The annotation's own id, or `nil` for a document-grain row. For a tag this is the
    /// `UserTag.id`, never the assignment's.
    var annotationId: UUID? = nil

    /// The volume half of the document anchor.
    var volumeId: String = ""

    /// The document half of the document anchor.
    var documentId: String = ""

    /// The `document_revisions.content_hash` the reader dispositioned. The row applies only
    /// while the document still hashes to this.
    var contentHash: String = ""

    /// The `document_revisions.change_kind` the reader dispositioned — `"body"`, `"apparatus"`,
    /// `"vanished"`, or `nil` for a row with no recorded change.
    ///
    /// **The hash alone is not enough, and the case that proves it is a restoration.** A vanished
    /// document keeps its hash ("the row itself is kept, hashes and all"), and when the Office of
    /// the Historian restores it unchanged the upsert re-opens the row at that SAME hash. Matching
    /// on the hash alone, a review made before the document vanished would silently stamp the
    /// restoration as reviewed — the reader would never learn their document came back. Matching
    /// on the kind as well says what a review actually asserts: *I looked at this change*, not
    /// *I have seen this text*. It also lets a vanished document's disposition cross devices,
    /// which a blanket refusal of vanished rows could not.
    var changeKind: String? = nil

    /// When the reader looked. Optional for CloudKit schema compatibility; always non-nil in
    /// practice.
    var reviewedAt: Date? = nil

    /// Creates a row. Callers should go through ``AnnotationReviewStore/record(kind:annotationId:volumeId:documentId:contentHash:reviewedAt:context:)``,
    /// which derives the id and refuses a duplicate.
    init(kind: AnnotationReviewKind, annotationId: UUID?, volumeId: String,
         documentId: String, contentHash: String, changeKind: String?, reviewedAt: Date = Date()) {
        self.id = Self.derivedId(kind: kind, annotationId: annotationId,
                                 volumeId: volumeId, documentId: documentId,
                                 contentHash: contentHash, changeKind: changeKind)
        self.annotationType = kind.rawValue
        self.annotationId = annotationId
        self.volumeId = volumeId
        self.documentId = documentId
        self.contentHash = contentHash
        self.changeKind = changeKind
        self.reviewedAt = reviewedAt
    }

    /// The kind, or `nil` for a raw value this build does not know — a row written by a newer
    /// build. Unknown kinds are ignored rather than guessed at.
    var kind: AnnotationReviewKind? { AnnotationReviewKind(rawValue: annotationType) }

    /// The document anchor as the index spells it.
    var documentKey: String { "\(volumeId)/\(documentId)" }

    /// `DeduplicableRecord`'s tie-break input, computed rather than stored: the row is created
    /// when it is reviewed, so a second mirrored column would carry the same value at the cost of
    /// one more identifier in the Production schema.
    var createdAt: Date? { reviewedAt }

    /// The deterministic id for a review row — a namespace hash, **not** a random UUID.
    ///
    /// SHA-256 over the UTF-8 of `"AnnotationReview|<kind>|<annotationId or ->|<volume>/<document>|<hash>"`,
    /// first 16 bytes, with RFC-4122 variant bits and a version nibble of 8 (a deterministic
    /// custom UUID, deliberately not claiming v5, which specifies SHA-1). Stable across devices,
    /// platforms and app versions by construction.
    static func derivedId(kind: AnnotationReviewKind, annotationId: UUID?,
                          volumeId: String, documentId: String, contentHash: String,
                          changeKind: String?) -> UUID {
        let key = "AnnotationReview|\(kind.rawValue)|\(annotationId?.uuidString ?? "-")|\(volumeId)/\(documentId)|\(contentHash)|\(changeKind ?? "-")"
        let digest = SHA256.hash(data: Data(key.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x80   // version nibble: 8 (custom, deterministic)
        bytes[8] = (bytes[8] & 0x3F) | 0x80   // RFC-4122 variant: 10xxxxxx
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3],
                           bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11],
                           bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    /// A `Sendable` snapshot, for the crossing into the `IndexingPipeline` actor.
    var snapshot: AnnotationReviewData {
        AnnotationReviewData(annotationType: annotationType, volumeId: volumeId,
                             documentId: documentId, contentHash: contentHash,
                             changeKind: changeKind)
    }
}

// MARK: - AnnotationReviewData

/// The `Sendable` value form of a review row — what crosses into the pipeline actor.
///
/// Carries only what the reconcile's SQL binds. `public` because the pipeline's entry point is.
public struct AnnotationReviewData: Equatable, Sendable, Hashable {
    /// The raw kind, so the actor can filter without knowing the enum.
    public let annotationType: String
    /// The volume half of the anchor.
    public let volumeId: String
    /// The document half.
    public let documentId: String
    /// The content hash the reader dispositioned.
    public let contentHash: String
    /// The change kind the reader dispositioned, or `nil`.
    public let changeKind: String?

    /// Memberwise, spelled out because `public` suppresses the synthesized one.
    public init(annotationType: String, volumeId: String, documentId: String,
                contentHash: String, changeKind: String?) {
        self.annotationType = annotationType
        self.volumeId = volumeId
        self.documentId = documentId
        self.contentHash = contentHash
        self.changeKind = changeKind
    }
}

// MARK: - AnnotationReviewStore

/// Writing and reconciling the review ledger (R-5 P3b-2).
///
/// Two directions, both run by ``reconcile(container:pipeline:)``:
///
/// - **Down** — a row synced from another device stamps this device's
///   `document_revisions.reviewed_at`, but only where the hash AND the change kind still match.
///   The hash carries most of it: a correction moves `content_hash` in the same statement that
///   NULLs `reviewed_at`, so a cleared stamp cannot be re-applied by the row that caused it. The
///   kind covers what the hash cannot see — a document that vanished and was then restored
///   unchanged, which the upsert re-opens at the very hash the reader already reviewed.
/// - **Up** — a stamp this device made before the ledger existed (every review since P3a) gets a
///   row, so those reviews start propagating instead of staying local for ever.
///
/// Nothing here deletes. A row whose annotation the reader later deleted is an orphan that
/// nothing renders and nothing acts on; it is bookkeeping about the reader's own act rather than
/// research, so §7's no-auto-deletion rule does not reach it, and a purge would risk deleting a
/// row whose annotation is merely un-synced on this device.
enum AnnotationReviewStore {

    /// What one reconcile pass did.
    struct Outcome: Equatable, Sendable {
        /// Local revision rows this pass stamped from a synced ledger row.
        var stamped = 0
        /// Ledger rows minted for local stamps that had none.
        var backfilled = 0
        /// `true` when the backfill hit its per-pass cap and has more to do next time.
        var backfillIncomplete = false
        /// Whether anything changed — the caller bumps `revisionReviewToken` only when true.
        var changedAnything: Bool { stamped > 0 || backfilled > 0 }
    }

    /// How many rows one pass will backfill before leaving the rest for the next one.
    static let backfillLimit = 500

    /// The key the backfill dedupes on — the four facts that make a row, so a review of a
    /// restoration is not mistaken for the review of the change before it.
    static func backfillKey(_ volumeId: String, _ documentId: String,
                            _ contentHash: String, _ changeKind: String?) -> String {
        "\(volumeId)/\(documentId)|\(contentHash)|\(changeKind ?? "-")"
    }

    /// Records one disposition, or returns the existing row when this device already holds it.
    ///
    /// The id is derived, so a second call with the same inputs is a no-op rather than a
    /// duplicate — which is also what makes two devices converge.
    @discardableResult
    static func record(kind: AnnotationReviewKind, annotationId: UUID? = nil,
                       volumeId: String, documentId: String, contentHash: String,
                       changeKind: String?, reviewedAt: Date = Date(),
                       context: ModelContext) -> AnnotationReview? {
        guard !volumeId.isEmpty, !documentId.isEmpty, !contentHash.isEmpty else { return nil }
        let derived = AnnotationReview.derivedId(kind: kind, annotationId: annotationId,
                                                 volumeId: volumeId, documentId: documentId,
                                                 contentHash: contentHash, changeKind: changeKind)
        let existing = try? context.fetch(
            FetchDescriptor<AnnotationReview>(predicate: #Predicate { $0.id == derived })).first
        if let existing { return existing }
        let row = AnnotationReview(kind: kind, annotationId: annotationId, volumeId: volumeId,
                                   documentId: documentId, contentHash: contentHash,
                                   changeKind: changeKind, reviewedAt: reviewedAt)
        context.insert(row)
        return row
    }

    /// Every row, as `Sendable` values for the actor crossing.
    static func snapshot(context: ModelContext) -> [AnnotationReviewData] {
        let rows = (try? context.fetch(FetchDescriptor<AnnotationReview>())) ?? []
        return rows.map(\.snapshot)
    }

    /// Runs both directions and saves. Idempotent, and a no-op on a device that has never
    /// reviewed anything, so it is safe on every launch and after every sync.
    ///
    /// Main-actor because it reads `container.mainContext`, the shape the boot replay already
    /// uses for the classification overrides. Callers off the main actor `await` it and hop.
    @MainActor
    @discardableResult
    static func reconcile(container: ModelContainer, pipeline: IndexingPipeline) async -> Outcome {
        var outcome = Outcome()
        let context = container.mainContext
        let ledger = snapshot(context: context)

        // Down: stamp what other devices reviewed, where this device's text still matches.
        let documentRows = ledger.filter { $0.annotationType == AnnotationReviewKind.document.rawValue }
        if !documentRows.isEmpty {
            outcome.stamped = (try? await pipeline.applyAnnotationReviews(documentRows)) ?? 0
        }

        // Up: give this device's own stamps a row, so they leave the device.
        let known = Set(documentRows.map { Self.backfillKey($0.volumeId, $0.documentId, $0.contentHash, $0.changeKind) })
        let reviewed = (try? await pipeline.reviewedDocumentRevisions()) ?? []
        for revision in reviewed
        where !known.contains(Self.backfillKey(revision.volumeId, revision.documentId,
                                               revision.contentHash, revision.changeKind)) {
            // Bounded per pass: a parse change moves every hash at once, so a library with a
            // thousand reviewed documents would otherwise mint a thousand rows in one main-actor
            // block. The rest are picked up at the next launch or sync.
            guard outcome.backfilled < backfillLimit else { outcome.backfillIncomplete = true; break }
            let stampedAt = revision.reviewedAt.flatMap(Self.date(fromISO8601:)) ?? Date()
            if record(kind: .document, volumeId: revision.volumeId, documentId: revision.documentId,
                      contentHash: revision.contentHash, changeKind: revision.changeKind,
                      reviewedAt: stampedAt, context: context) != nil {
                outcome.backfilled += 1
            }
        }
        if outcome.backfilled > 0 { try? context.save() }
        return outcome
    }

    /// Parses the ISO-8601 stamp `document_revisions` stores, so a backfilled row carries the
    /// date the reader actually reviewed rather than the date of the backfill.
    static func date(fromISO8601 string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
