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

// MARK: - AnnotationReviewTests

/// The cross-device review ledger (R-5 P3b-2, design §8.2 Q-3/Q-6).
///
/// The reconcile cases drive the real `IndexingPipeline` over a real corpus — they reuse
/// `DocumentRevisionsTests.Harness`, whose standard is that nothing is mocked — because the claim
/// under test is *a review made on one device reaches another*, and the whole safety of it rests
/// on one SQL term matching a hash the shipped upsert wrote.
///
/// Version history:
///   1.0 — R-5 P3b-2: initial implementation
@Suite("Annotation review ledger — the disposition that crosses devices")
struct AnnotationReviewTests {

    private let vol = "frus1958-60v01"
    private var base: [DocumentRevisionsTests.Doc] {
        [.init(id: "d1", head: "Memorandum of Conversation", body: "The Ambassador called at noon.",
               footnote: "See Document 4.", sourceNote: "Department of State, Central Files, 611.51/1-1558."),
         .init(id: "d2", head: "Telegram From the Embassy", body: "Nothing to report from Paris."),
         .init(id: "d3", head: "Editorial Note", body: "The conference adjourned without result.")]
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: AnnotationReview.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }

    // MARK: - The derived id

    /// Two devices reviewing the same thing at the same text must mint the SAME row, or
    /// `DuplicateRecordCleanup` (which groups by id) cannot collapse them and CloudKit's
    /// last-writer-wins destroys one review. Including the hash is what makes the ledger
    /// append-only.
    @Test("The id is deterministic, and every component changes it — the hash included")
    func derivedIdIsDeterministic() {
        let a = AnnotationReview.derivedId(kind: .document, annotationId: nil,
                                           volumeId: "v1", documentId: "d1", contentHash: "H1", changeKind: "body")
        #expect(a == AnnotationReview.derivedId(kind: .document, annotationId: nil,
                                                volumeId: "v1", documentId: "d1", contentHash: "H1", changeKind: "body"))
        #expect(a != AnnotationReview.derivedId(kind: .document, annotationId: nil,
                                                volumeId: "v1", documentId: "d1", contentHash: "H2", changeKind: "body"))
        #expect(a != AnnotationReview.derivedId(kind: .note, annotationId: nil,
                                                volumeId: "v1", documentId: "d1", contentHash: "H1", changeKind: "body"))
        #expect(a != AnnotationReview.derivedId(kind: .document, annotationId: UUID(),
                                                volumeId: "v1", documentId: "d1", contentHash: "H1", changeKind: "body"))
        #expect(a != AnnotationReview.derivedId(kind: .document, annotationId: nil,
                                                volumeId: "v1", documentId: "d2", contentHash: "H1", changeKind: "body"))
        #expect(a != AnnotationReview.derivedId(kind: .document, annotationId: nil,
                                                volumeId: "v2", documentId: "d1", contentHash: "H1", changeKind: "body"))
        #expect(a != AnnotationReview.derivedId(kind: .document, annotationId: nil,
                                                volumeId: "v1", documentId: "d1", contentHash: "H1", changeKind: "apparatus"),
                "a review of a restoration is not a review of the change before it")
        // Version nibble 8 and the RFC-4122 variant, as the ArchiveVisitPlan precedent sets.
        let hex = a.uuidString.replacingOccurrences(of: "-", with: "")
        #expect(hex[hex.index(hex.startIndex, offsetBy: 12)] == "8")
        #expect("89ab".contains(hex[hex.index(hex.startIndex, offsetBy: 16)]))
    }

    @Test("A kind this build does not know is read as nil, never guessed")
    func unknownKindIsIgnored() {
        let row = AnnotationReview(kind: .document, annotationId: nil, volumeId: "v1",
                                   documentId: "d1", contentHash: "H", changeKind: "body")
        #expect(row.kind == .document)
        row.annotationType = "somethingNewer"
        #expect(row.kind == nil)
        #expect(AnnotationReviewKind.allCases.map(\.rawValue).contains("document"))
        #expect(!AnnotationReviewKind.allCases.map(\.rawValue).contains("highlight"),
                "highlights keep renderingVersion — a ledger row would be a second source of truth")
    }

    @Test("record is idempotent, and refuses a row with nothing to anchor")
    @MainActor
    func recordIsIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let first = AnnotationReviewStore.record(kind: .document, volumeId: "v1", documentId: "d1",
                                                 contentHash: "H", changeKind: "body", context: context)
        let second = AnnotationReviewStore.record(kind: .document, volumeId: "v1", documentId: "d1",
                                                  contentHash: "H", changeKind: "body", context: context)
        try context.save()
        #expect(first != nil)
        #expect(second?.id == first?.id)
        #expect(try context.fetchCount(FetchDescriptor<AnnotationReview>()) == 1)
        #expect(AnnotationReviewStore.record(kind: .document, volumeId: "", documentId: "d1",
                                             contentHash: "H", changeKind: "body", context: context) == nil)
        #expect(AnnotationReviewStore.record(kind: .document, volumeId: "v1", documentId: "d1",
                                             contentHash: "", changeKind: "body", context: context) == nil)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<AnnotationReview>()) == 1)
    }

    // MARK: - The reconcile, through the real pipeline

    /// **The case the feature exists for.** Another device reviewed this document at the text this
    /// device now holds; the stamp must land. Without this test the self-guard case below would
    /// pass against a reconcile that never stamps anything at all.
    @Test("A synced row stamps this device when the hash matches")
    @MainActor
    func reconcileStampsAMatchingRow() async throws {
        let h = try DocumentRevisionsTests.Harness()
        let container = try makeContainer()
        try h.write(vol, base)
        _ = try await h.index(vol)
        var edited = base
        edited[1].body = "Nothing to report from Paris, except the rain."
        try h.write(vol, edited)
        let after = try await h.index(vol)
        let changed = try #require(after["d2"])
        #expect(try await h.pipeline.unreviewedDocumentRevisions().map(\.documentId) == ["d2"])

        // The other device's row, at the hash this device now holds.
        AnnotationReviewStore.record(kind: .document, volumeId: vol, documentId: "d2",
                                     contentHash: changed.contentHash, changeKind: changed.changeKind,
                                     context: container.mainContext)
        try container.mainContext.save()

        let outcome = await AnnotationReviewStore.reconcile(container: container, pipeline: h.pipeline)
        #expect(outcome.stamped == 1)
        #expect(outcome.changedAnything)
        #expect(try await h.pipeline.unreviewedDocumentRevisions().isEmpty)
        let row = try #require(try await h.pipeline.documentRevision(volumeId: vol, documentId: "d2"))
        #expect(row.reviewedAt != nil)

        // Idempotent: a second pass stamps nothing more.
        #expect(await AnnotationReviewStore.reconcile(container: container, pipeline: h.pipeline).stamped == 0)
    }

    /// **The self-guard.** A review of the OLD text must not clear a flag raised by a NEW change.
    /// `reviewed_at` is NULLed only in the statement that writes the new hash, so the guard is one
    /// SQL term — this pins that it is actually there.
    /// The fixture is TWO successive body changes, so the ledger row and the local row agree on
    /// the change kind and differ ONLY in the hash — otherwise the kind term alone would refuse
    /// this, and the hash term could be deleted with every test still green.
    @Test("A synced row does not stamp a change it never saw")
    @MainActor
    func reconcileRefusesAStaleRow() async throws {
        let h = try DocumentRevisionsTests.Harness()
        let container = try makeContainer()
        try h.write(vol, base)
        _ = try await h.index(vol)
        var edited = base
        edited[1].body = "Nothing to report from Paris, except the rain."
        try h.write(vol, edited)
        let firstChange = try await h.index(vol)
        let originalHash = try #require(firstChange["d2"]?.contentHash)
        #expect(firstChange["d2"]?.changeKind == "body")

        // Reviewed at the FIRST change.
        AnnotationReviewStore.record(kind: .document, volumeId: vol, documentId: "d2",
                                     contentHash: originalHash, changeKind: "body",
                                     context: container.mainContext)
        try container.mainContext.save()
        #expect(await AnnotationReviewStore.reconcile(container: container, pipeline: h.pipeline).stamped == 1)

        // A SECOND body change: same kind, different hash.
        edited[1].body = "Nothing to report from Paris, except the fog."
        try h.write(vol, edited)
        let secondChange = try await h.index(vol)
        #expect(secondChange["d2"]?.changeKind == "body", "the kind matches; only the hash moved")
        #expect(secondChange["d2"]?.contentHash != originalHash)

        let outcome = await AnnotationReviewStore.reconcile(container: container, pipeline: h.pipeline)
        #expect(outcome.stamped == 0)
        #expect(try await h.pipeline.unreviewedDocumentRevisions().map(\.documentId) == ["d2"],
                "the reader has never seen this change")
    }

    /// **The exception the hash cannot cover.** `auxMarkVanishedRevisions` NULLs `reviewed_at` and
    /// leaves `content_hash` alone, so a row written while the document EXISTED still compares
    /// equal after an update deleted it. Stamping it would silence the one case §7 forbids hiding;
    /// the change-kind term is what refuses it, since the reader reviewed no vanishing.
    @Test("A review of the document is not a review of its disappearance")
    @MainActor
    func reconcileRefusesAVanishedDocument() async throws {
        let h = try DocumentRevisionsTests.Harness()
        let container = try makeContainer()
        try h.write(vol, base)
        let first = try await h.index(vol)
        let hash = try #require(first["d3"]?.contentHash)
        AnnotationReviewStore.record(kind: .document, volumeId: vol, documentId: "d3",
                                     contentHash: hash, changeKind: first["d3"]?.changeKind,
                                     context: container.mainContext)
        try container.mainContext.save()

        try h.write(vol, Array(base.dropLast()))          // d3 removed by the update
        let after = try await h.index(vol)
        #expect(after["d3"]?.changeKind == "vanished")
        #expect(after["d3"]?.contentHash == hash, "the vanished mark leaves the hash alone")

        let outcome = await AnnotationReviewStore.reconcile(container: container, pipeline: h.pipeline)
        #expect(outcome.stamped == 0)
        #expect(try await h.pipeline.vanishedDocumentKeys() == ["\(vol)/d3"])
        #expect(try await h.pipeline.unreviewedDocumentRevisions().map(\.documentId).contains("d3"))
    }

    /// **The backfill.** Every review made since P3a is device-local with no ledger row; without
    /// this direction those reviews would never leave the device and the feature's first
    /// impression would be that it does not work.
    @Test("A local stamp with no ledger row gets one, carrying the date it was reviewed")
    @MainActor
    func reconcileBackfillsLocalStamps() async throws {
        let h = try DocumentRevisionsTests.Harness()
        let container = try makeContainer()
        try h.write(vol, base)
        _ = try await h.index(vol)
        var edited = base
        edited[1].body = "Nothing to report from Paris, except the rain."
        try h.write(vol, edited)
        let after = try await h.index(vol)
        let hash = try #require(after["d2"]?.contentHash)
        #expect(try await h.pipeline.markDocumentRevisionReviewed(volumeId: vol, documentId: "d2"))

        let outcome = await AnnotationReviewStore.reconcile(container: container, pipeline: h.pipeline)
        #expect(outcome.backfilled == 1)
        let rows = try container.mainContext.fetch(FetchDescriptor<AnnotationReview>())
        #expect(rows.count == 1)
        let row = try #require(rows.first)
        #expect(row.kind == .document)
        #expect(row.documentKey == "\(vol)/d2")
        #expect(row.contentHash == hash)
        #expect(row.annotationId == nil)
        let stamped = try #require(try await h.pipeline.documentRevision(volumeId: vol, documentId: "d2")?.reviewedAt)
        #expect(row.reviewedAt == AnnotationReviewStore.date(fromISO8601: stamped),
                "the row records when the reader reviewed, not when the backfill ran")

        // Idempotent: the row already exists, so a second pass mints nothing.
        #expect(await AnnotationReviewStore.reconcile(container: container, pipeline: h.pipeline).backfilled == 0)
    }

    /// A document that has never CHANGED has nothing to review, so a ledger row naming its
    /// first-index hash must stamp nothing — `changed_at IS NOT NULL` is the term that says so,
    /// and without it a reconcile would mint a disposition for a change that never happened.
    @Test("A row for an unchanged document stamps nothing")
    @MainActor
    func reconcileRefusesAnUnchangedDocument() async throws {
        let h = try DocumentRevisionsTests.Harness()
        let container = try makeContainer()
        try h.write(vol, base)
        let first = try await h.index(vol)
        let hash = try #require(first["d2"]?.contentHash)
        #expect(first["d2"]?.changedAt == nil, "a first index stamps nothing")
        AnnotationReviewStore.record(kind: .document, volumeId: vol, documentId: "d2",
                                     contentHash: hash, changeKind: first["d2"]?.changeKind,
                                     context: container.mainContext)
        try container.mainContext.save()

        let outcome = await AnnotationReviewStore.reconcile(container: container, pipeline: h.pipeline)
        #expect(outcome.stamped == 0)
        #expect(try await h.pipeline.documentRevision(volumeId: vol, documentId: "d2")?.reviewedAt == nil)
    }

    @Test("An outcome that changed nothing does not ask the readers to reload")
    func outcomeReportsWhetherAnythingChanged() {
        #expect(!AnnotationReviewStore.Outcome().changedAnything)
        #expect(AnnotationReviewStore.Outcome(stamped: 1, backfilled: 0).changedAnything)
        #expect(AnnotationReviewStore.Outcome(stamped: 0, backfilled: 1).changedAnything)
    }

    /// **The case the hash alone cannot see, and the reason the ledger records the change kind.**
    /// A vanished document keeps its content hash, and a restoration re-opens the row at that very
    /// hash — so a review made before the document vanished would silently stamp the restoration
    /// as seen, and the reader would never learn their document came back.
    @Test("A review made before a document vanished does not stamp its restoration")
    @MainActor
    func reconcileRefusesARestoration() async throws {
        let h = try DocumentRevisionsTests.Harness()
        let container = try makeContainer()
        try h.write(vol, base)
        _ = try await h.index(vol)
        var edited = base
        edited[2].body = "The conference adjourned without result, twice."
        try h.write(vol, edited)
        let changed = try await h.index(vol)
        let reviewedHash = try #require(changed["d3"]?.contentHash)
        #expect(changed["d3"]?.changeKind == "body")

        AnnotationReviewStore.record(kind: .document, volumeId: vol, documentId: "d3",
                                     contentHash: reviewedHash, changeKind: "body",
                                     context: container.mainContext)
        try container.mainContext.save()
        #expect(await AnnotationReviewStore.reconcile(container: container, pipeline: h.pipeline).stamped == 1)

        // The document vanishes, then returns with the identical text.
        try h.write(vol, Array(edited.dropLast()))
        _ = try await h.index(vol)
        try h.write(vol, edited)
        let restored = try await h.index(vol)
        #expect(restored["d3"]?.contentHash == reviewedHash, "a restoration re-opens the SAME hash")
        #expect(restored["d3"]?.reviewedAt == nil, "the upsert re-opened it")

        let outcome = await AnnotationReviewStore.reconcile(container: container, pipeline: h.pipeline)
        #expect(outcome.stamped == 0, "the reader has not seen the restoration")
        #expect(try await h.pipeline.unreviewedDocumentRevisions().map(\.documentId).contains("d3"))
    }

    /// The vanished disposition itself DOES cross devices — an orphan the reader has explicitly
    /// looked at should stop being raised everywhere, which a blanket refusal of vanished rows
    /// could not deliver.
    @Test("A review of the vanishing itself crosses devices")
    @MainActor
    func reconcileStampsAReviewedVanishing() async throws {
        let h = try DocumentRevisionsTests.Harness()
        let container = try makeContainer()
        try h.write(vol, base)
        _ = try await h.index(vol)
        try h.write(vol, Array(base.dropLast()))
        let after = try await h.index(vol)
        let gone = try #require(after["d3"])
        #expect(gone.changeKind == "vanished")

        AnnotationReviewStore.record(kind: .document, volumeId: vol, documentId: "d3",
                                     contentHash: gone.contentHash, changeKind: "vanished",
                                     context: container.mainContext)
        try container.mainContext.save()
        #expect(await AnnotationReviewStore.reconcile(container: container, pipeline: h.pipeline).stamped == 1)
        #expect(try await h.pipeline.unreviewedDocumentRevisions().isEmpty)
        #expect(try await h.pipeline.vanishedDocumentKeys() == ["\(vol)/d3"],
                "still gone — the review says the reader looked, not that it came back")
    }

    /// A review of a RESTORATION is a different row from a review of the change before it, so the
    /// backfill's dedupe key must carry the change kind — without it the second review is read as
    /// already known and never leaves the device.
    @Test("The backfill mints a row when only the change kind differs")
    @MainActor
    func backfillKeysOnTheChangeKind() async throws {
        let h = try DocumentRevisionsTests.Harness()
        let container = try makeContainer()
        try h.write(vol, base)
        _ = try await h.index(vol)
        var edited = base
        edited[2].body = "The conference adjourned without result, twice."
        try h.write(vol, edited)
        let changed = try await h.index(vol)
        let hash = try #require(changed["d3"]?.contentHash)

        // A ledger row for the BODY change, as another device would have written it.
        AnnotationReviewStore.record(kind: .document, volumeId: vol, documentId: "d3",
                                     contentHash: hash, changeKind: "body",
                                     context: container.mainContext)
        try container.mainContext.save()

        // The document vanishes and returns; the reader reviews the restoration locally.
        try h.write(vol, Array(edited.dropLast()))
        _ = try await h.index(vol)
        try h.write(vol, edited)
        let restored = try await h.index(vol)
        #expect(restored["d3"]?.contentHash == hash, "the same hash, a different change")
        #expect(restored["d3"]?.changeKind == "apparatus")
        #expect(try await h.pipeline.markDocumentRevisionReviewed(volumeId: vol, documentId: "d3"))

        let outcome = await AnnotationReviewStore.reconcile(container: container, pipeline: h.pipeline)
        #expect(outcome.backfilled == 1, "the restoration's review is not the earlier one")
        let kinds = try container.mainContext.fetch(FetchDescriptor<AnnotationReview>())
            .filter { $0.documentId == "d3" }.compactMap(\.changeKind).sorted()
        #expect(kinds == ["apparatus", "body"])
    }

    /// Only `document` rows have a writer in this build; the rest of the vocabulary is reserved.
    /// A row of a reserved kind must not stamp the document, or shipping P3b-4's writers would
    /// retroactively change what every already-synced row means.
    @Test("A reserved-kind row does not stamp the document")
    @MainActor
    func reservedKindsDoNotStamp() async throws {
        let h = try DocumentRevisionsTests.Harness()
        let container = try makeContainer()
        try h.write(vol, base)
        _ = try await h.index(vol)
        var edited = base
        edited[1].body = "Nothing to report from Paris, except the rain."
        try h.write(vol, edited)
        let changed = try await h.index(vol)
        let hash = try #require(changed["d2"]?.contentHash)

        AnnotationReviewStore.record(kind: .note, annotationId: UUID(), volumeId: vol,
                                     documentId: "d2", contentHash: hash, changeKind: "body",
                                     context: container.mainContext)
        try container.mainContext.save()

        let outcome = await AnnotationReviewStore.reconcile(container: container, pipeline: h.pipeline)
        #expect(outcome.stamped == 0, "a note review is not a document review")
        #expect(try await h.pipeline.unreviewedDocumentRevisions().map(\.documentId) == ["d2"])
    }
}
