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

// MARK: - UserTagAssign

/// What ``UserTagAdmin/assign(tagIds:to:context:fetch:save:)`` did (#1576 lane 5).
///
/// Version history:
///   1.0 — #1576 lane 5: initial implementation
struct UserTagAssign: Equatable, Sendable {

    /// The ids of the assignment rows inserted. Ids and not the rows: an undo re-fetches by id
    /// and treats a miss as already undone.
    let insertedAssignmentIds: [UUID]
    /// The documents that gained at least one tag, in the order they were given.
    let taggedDocuments: [CollectionDocumentRef]
    /// How many of the documents asked for carried every tag asked for already, and gained none.
    let alreadyTagged: Int
    /// Every tag each document asked for carries now, keyed by `CollectionDocumentRef.key`.
    ///
    /// Read from the store's assignments at the moment of the write, never from a result row: a
    /// row's tags are a snapshot from when its search ran, and a tag given to the document since,
    /// here or on another device, is in the store and not in the row.
    let tagIdsByDocument: [String: Set<UUID>]
}

// MARK: - UserTagRemoval

/// What ``UserTagAdmin/removeAssignments(withIds:context:fetch:save:)`` did (#1576 lane 5).
///
/// Version history:
///   1.0 — #1576 lane 5: initial implementation
struct UserTagRemoval: Equatable, Sendable {

    /// The documents an assignment row was removed from, each once, in the order their rows
    /// were asked for.
    let documents: [CollectionDocumentRef]
    /// Every tag each of those documents still carries, keyed by `CollectionDocumentRef.key`. A
    /// document left with none has an empty set, and is in the dictionary.
    let tagIdsByDocument: [String: Set<UUID>]
}

// MARK: - UserTagAssignRefusal

/// Why ``UserTagAdmin/assign(tagIds:to:context:fetch:save:)`` tagged nothing.
///
/// Version history:
///   1.0 — #1576 lane 5: initial implementation
enum UserTagAssignRefusal: Error, Equatable {

    /// More documents than one bulk tag takes (the owner's decision 5 on #1576).
    case overLimit(count: Int, limit: Int)
}

// MARK: - assign

extension UserTagAdmin {

    /// Every assignment in the store: the one read ``assign(tagIds:to:context:fetch:save:)`` and
    /// ``removeAssignments(withIds:context:fetch:save:)`` each make.
    nonisolated static func allAssignments(in context: ModelContext) throws -> [DocumentTagAssignment] {
        try context.fetch(FetchDescriptor<DocumentTagAssignment>())
    }

    /// Gives several documents several tags at one stroke, and saves (#1576 lane 5).
    ///
    /// ## How it differs from the tag picker's own writer
    ///
    /// The picker, opened on one document, **replaces** that document's whole tag set with what
    /// its toggles show on Done. That is right for one document whose tags are in front of the
    /// reader, and wrong for forty whose tags are not: run over a selection it would take every
    /// other tag off every document in it. This only **adds**.
    ///
    /// ## What it guarantees
    ///
    /// - **One fetch of every assignment**, grouped by document. A (document, tag) pair is
    ///   inserted only where no row holds it, so a second run inserts nothing, and a pair the
    ///   store already holds twice (two devices tagged before they synced) counts as present.
    /// - **A fetch that fails stops the command.** It is thrown, and never read as "no tags yet":
    ///   on that reading every pair would be inserted a second time.
    /// - **One save, here.** A save that fails inserts nothing: the rows are taken back out of the
    ///   context before the error is thrown.
    /// - A list over `CollectionDocumentDiscovery.bulkDocumentLimit` is refused before anything
    ///   is read or written.
    /// - With nothing to insert, nothing is saved.
    /// - The answer carries each document's whole tag set as the store has it now
    ///   (``UserTagAssign/tagIdsByDocument``), for the rows on screen.
    ///
    /// The index's copy of the tags is not written here. The caller rewrites it for
    /// ``UserTagAssign/taggedDocuments`` with `DocumentTagAssignment.reindexTagColumn`, which
    /// re-reads the store after this save: ``assignAndIndex(tagIds:to:context:pipeline:rewrite:)`` does both.
    ///
    /// - Parameters:
    ///   - tagIds: The tags to give. A tag named twice is given once.
    ///   - documents: The documents to tag. The caller freezes this list when the command is
    ///     chosen. A document named twice is one document.
    ///   - context: The context the rows are inserted into and saved through.
    ///   - fetch: How every assignment is read. The default is the context's own fetch; a test
    ///     passes one that throws, since nothing else makes an in-memory store refuse a read.
    ///   - save: How the context is saved. The default is `ModelContext.save()`; a test passes
    ///     one that throws, for the same reason.
    /// - Returns: The rows inserted, the documents that gained a tag, and every asked document's
    ///   tags now.
    /// - Throws: ``UserTagAssignRefusal`` when the list is over the limit, or the fetch's or the
    ///   save's error.
    @discardableResult
    static func assign(
        tagIds: [UUID],
        to documents: [CollectionDocumentRef],
        context: ModelContext,
        fetch: (ModelContext) throws -> [DocumentTagAssignment] = allAssignments,
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) throws -> UserTagAssign {
        var asked: Set<CollectionDocumentRef> = []
        let distinct = documents.filter { asked.insert($0).inserted }
        let limit = CollectionDocumentDiscovery.bulkDocumentLimit
        guard distinct.count <= limit else {
            throw UserTagAssignRefusal.overLimit(count: distinct.count, limit: limit)
        }
        var named: Set<UUID> = []
        let tags = tagIds.filter { named.insert($0).inserted }

        // Thrown, not defaulted: an unreadable store is not a store with no tags in it.
        let existing = try fetch(context)
        var held: [String: Set<UUID>] = [:]
        for assignment in existing {
            held[CollectionDocumentDiscovery.documentKey(volumeId: assignment.volumeId,
                                                         documentId: assignment.documentId),
                 default: []].insert(assignment.tagId)
        }

        var inserted: [DocumentTagAssignment] = []
        var tagged: [CollectionDocumentRef] = []
        for document in distinct {
            let missing = tags.filter { !(held[document.key]?.contains($0) ?? false) }
            guard !missing.isEmpty else { continue }
            for tagId in missing {
                let row = DocumentTagAssignment(volumeId: document.volumeId,
                                                documentId: document.documentId, tagId: tagId)
                context.insert(row)
                inserted.append(row)
            }
            held[document.key, default: []].formUnion(missing)
            tagged.append(document)
        }

        var now: [String: Set<UUID>] = [:]
        for document in distinct { now[document.key] = held[document.key] ?? [] }
        guard !inserted.isEmpty else {
            return UserTagAssign(insertedAssignmentIds: [], taggedDocuments: [],
                                 alreadyTagged: distinct.count, tagIdsByDocument: now)
        }
        do {
            try save(context)
        } catch {
            for row in inserted { context.delete(row) }
            throw error
        }
        return UserTagAssign(insertedAssignmentIds: inserted.map(\.id), taggedDocuments: tagged,
                             alreadyTagged: distinct.count - tagged.count, tagIdsByDocument: now)
    }

    /// Takes a bulk tag back: deletes the assignment rows with these ids, and saves
    /// (#1576 lane 5).
    ///
    /// It is the Undo of ``assign(tagIds:to:context:fetch:save:)``, which answers with the ids it
    /// inserted. An id that finds nothing is a row the reader, the tag picker or another device
    /// removed since: that one is already undone, and is not an error. Rows the command did not
    /// insert are never touched, so a tag a document carried before the command stays, and so
    /// does one it has gained since.
    ///
    /// - Parameters:
    ///   - ids: The ids `assign` returned.
    ///   - context: The context to delete in and save through.
    ///   - fetch: How every assignment is read; a test passes one that throws.
    ///   - save: How the context is saved; a test passes one that throws.
    /// - Returns: The documents a row was removed from, and the tags each still carries.
    /// - Throws: The fetch's or the save's error. After a failed save nothing is put back: the
    ///   rows are deleted in the context and will go with its next save. Nothing is told to the
    ///   index or to the rows on screen then, so both keep the tag until the next reconcile
    ///   (`DocumentTagAssignment.reconcileTagColumn`, at launch and when an iCloud import settles).
    @discardableResult
    static func removeAssignments(
        withIds ids: [UUID],
        context: ModelContext,
        fetch: (ModelContext) throws -> [DocumentTagAssignment] = allAssignments,
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) throws -> UserTagRemoval {
        let doomed = Set(ids)
        guard !doomed.isEmpty else { return UserTagRemoval(documents: [], tagIdsByDocument: [:]) }
        // One fetch for both halves: the rows to delete, and what the documents keep.
        let all = try fetch(context)
        var found: [UUID: DocumentTagAssignment] = [:]
        var kept: [String: Set<UUID>] = [:]
        for assignment in all {
            if doomed.contains(assignment.id) {
                found[assignment.id] = assignment
            } else {
                kept[CollectionDocumentDiscovery.documentKey(volumeId: assignment.volumeId,
                                                             documentId: assignment.documentId),
                     default: []].insert(assignment.tagId)
            }
        }
        // In the order asked, which is the order the command tagged them in: a store answers a
        // fetch in no order of its own.
        var documents: [CollectionDocumentRef] = []
        var seen: Set<CollectionDocumentRef> = []
        for id in ids {
            guard let assignment = found.removeValue(forKey: id) else { continue }
            let document = CollectionDocumentRef(volumeId: assignment.volumeId,
                                                 documentId: assignment.documentId)
            if seen.insert(document).inserted { documents.append(document) }
            context.delete(assignment)
        }
        guard !documents.isEmpty else { return UserTagRemoval(documents: [], tagIdsByDocument: [:]) }
        try save(context)
        var remaining: [String: Set<UUID>] = [:]
        for document in documents { remaining[document.key] = kept[document.key] ?? [] }
        return UserTagRemoval(documents: documents, tagIdsByDocument: remaining)
    }
}

// MARK: - With the index

extension UserTagAdmin {

    /// ``assign(tagIds:to:context:fetch:save:)``, and then the index's tag column for the documents that
    /// gained a tag, rewritten off the main actor in one task (#1576 lane 5).
    ///
    /// The rewrite re-reads each document's assignments from the store, in a context of its own,
    /// after the save: the string it writes is the document's whole tag set as the store has it,
    /// and never one built from a row on screen. Rewrites run one after another, in the order
    /// they were asked for.
    ///
    /// - Parameters:
    ///   - tagIds: The tags to give.
    ///   - documents: The documents to tag.
    ///   - context: The context to write through.
    ///   - pipeline: The index whose tag column to rewrite, or `nil` when there is none.
    ///   - rewrite: What rewrites the column. The default is the one the app has; a test passes
    ///     one it can hold, to see that the next waits for it.
    /// - Returns: What the assign did.
    /// - Throws: Whatever `assign` throws. Nothing is written to the index then.
    @discardableResult
    static func assignAndIndex(
        tagIds: [UUID],
        to documents: [CollectionDocumentRef],
        context: ModelContext,
        pipeline: IndexingPipeline?,
        rewrite: @escaping TagColumnRewrite = DocumentTagAssignment.reindexTagColumn
    ) throws -> UserTagAssign {
        let outcome = try assign(tagIds: tagIds, to: documents, context: context)
        reindex(outcome.taggedDocuments, container: context.container, pipeline: pipeline, rewrite: rewrite)
        return outcome
    }

    /// ``removeAssignments(withIds:context:fetch:save:)``, and then the index's tag column for the
    /// documents a row was removed from (#1576 lane 5). The Undo of
    /// ``assignAndIndex(tagIds:to:context:pipeline:rewrite:)``.
    ///
    /// - Parameters:
    ///   - ids: The ids the assign returned.
    ///   - context: The context to write through.
    ///   - pipeline: The index whose tag column to rewrite, or `nil` when there is none.
    ///   - rewrite: What rewrites the column; see ``assignAndIndex(tagIds:to:context:pipeline:rewrite:)``.
    /// - Returns: What the removal did.
    /// - Throws: Whatever `removeAssignments` throws. Nothing is written to the index then.
    @discardableResult
    static func removeAssignmentsAndIndex(
        withIds ids: [UUID],
        context: ModelContext,
        pipeline: IndexingPipeline?,
        rewrite: @escaping TagColumnRewrite = DocumentTagAssignment.reindexTagColumn
    ) throws -> UserTagRemoval {
        let removal = try removeAssignments(withIds: ids, context: context)
        reindex(removal.documents, container: context.container, pipeline: pipeline, rewrite: rewrite)
        return removal
    }

    /// What rewrites the index's tag column for some documents: `DocumentTagAssignment.reindexTagColumn`
    /// in the app.
    typealias TagColumnRewrite =
        @Sendable (_ documents: [DocumentTagAssignment.DocumentKey], _ container: ModelContainer,
                   _ pipeline: IndexingPipeline) async -> Void

    /// The last rewrite of the index's tag column that ``assignAndIndex(tagIds:to:context:pipeline:rewrite:)``
    /// or ``removeAssignmentsAndIndex(withIds:context:pipeline:rewrite:)`` started, or `nil` before
    /// the first. The next one waits for it, and a test awaits it.
    ///
    /// **It orders these two callers and no other writer of the column.** The tag picker opened
    /// on a document, the Research rail's Remove Tag, `deleteCascading` and the launch reconcile
    /// each write on their own. A tag taken off one document by hand while a bulk rewrite of the
    /// same document is under way can therefore be written back by it, and stays in the index
    /// until the next reconcile.
    private(set) static var pendingReindex: Task<Void, Never>?

    /// Rewrites the index's tag column for `documents` from the store, in one detached task
    /// that starts when the rewrite before it has finished.
    ///
    /// **In order, and not merely off the main actor.** A rewrite reads the store once and then
    /// writes a row at a time. Left to run side by side, a tagging's rewrite that had read the
    /// store could finish its writes after the rewrite of an Undo pressed straight away, and
    /// leave in the index the tags the Undo had just taken out of the store. Each rewrite reads
    /// the store when it starts, so run one after another the last to run writes what the store
    /// holds.
    private static func reindex(_ documents: [CollectionDocumentRef], container: ModelContainer,
                                pipeline: IndexingPipeline?, rewrite: @escaping TagColumnRewrite) {
        guard let pipeline, !documents.isEmpty else { return }
        let keys = documents.map { (volumeId: $0.volumeId, documentId: $0.documentId) }
        pendingReindex = after(pendingReindex) {
            await rewrite(keys, container, pipeline)
        }
    }

    /// Starts `work` off the main actor once `previous` has finished: the link that makes the
    /// rewrites run in the order they were asked for.
    ///
    /// - Parameters:
    ///   - previous: The task to wait for, or `nil` to start at once.
    ///   - work: What to run.
    /// - Returns: The task running `work`, for the next link to wait on.
    nonisolated static func after(_ previous: Task<Void, Never>?,
                                  _ work: @escaping @Sendable () async -> Void) -> Task<Void, Never> {
        Task.detached(priority: .utility) {
            await previous?.value
            await work()
        }
    }
}
