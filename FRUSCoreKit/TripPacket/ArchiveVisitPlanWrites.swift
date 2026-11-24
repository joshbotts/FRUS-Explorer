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

#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
import Foundation

// MARK: - ArchiveVisitPlanWrites

/// The writes an Archives Visit plan takes, as rules over the research export's records of a plan,
/// its documents and its targets (`ArchiveVisitPlanExport`, `ArchiveVisitDocumentExport`,
/// `ArchiveVisitTargetExport`): each answers the rows to write, and a host applies them to its own
/// store — the app through its `ModelContext` (`ArchiveVisitDerivation+App.swift`), FRUS Explorer Light
/// to its tables. A child row's id is derived (``derivedChildId(planId:key:)``), so two hosts that
/// mint one row mint one id.
///
/// **A rule reads the rows as the host stores them, in the order it holds them,** and answers a
/// stored row by its index in what it was given (``StoredRow``), so a host holding two copies of one
/// row — two devices' mints, which share a derived id until the app's `DuplicateRecordCleanup`
/// collapses them — writes the copy it always wrote: the first of a key.
///
/// **A rule stamps no date on a row it changes.** A host stamps its own writes, as the app's
/// `ModelModificationStamper` does at save. A record a rule mints carries `now` as its creation and
/// modification date; the app makes its rows through their initialisers, which stamp the moment they
/// are made, and takes each record's id, keys and values.
///
/// What stays the host's: finding the project a plan is made or re-seeded under, gathering its seeds,
/// asking the reader before a topic is replaced, and saving.
///
/// Version history:
///   1.0 — 2026-11-24 (FRUS Explorer Light, S30b): initial implementation, out of the app's
///          `ArchiveVisitPlan` (the derived id, the untitled name, a new plan, the duplicate and the
///          delete), its plan-state extension (a re-seed, its topic, an added seed and a target's stored
///          row) and the editor's commits (a rename's and a note's draft, and the tiers' add, rename,
///          reorder and removal), each unchanged in what it writes
public enum ArchiveVisitPlanWrites {

    // MARK: - Derived child ids (§2a)

    /// The deterministic id for a child row of a plan — a namespace hash over
    /// `planId | key`, **not** a random UUID.
    ///
    /// SwiftData under CloudKit cannot declare `@Attribute(.unique)`, and
    /// `DuplicateRecordCleanup` groups by `id` — so two devices minting state for the same
    /// target (or seeding the same document) create the same row *deterministically*, which is
    /// exactly the case a random id would hide from that pass. SHA-256 over the UTF-8 of
    /// `"<planId>|<key>"`, first 16 bytes, with RFC-4122 variant bits and a version nibble of 8
    /// (a deterministic custom UUID, deliberately not claiming RFC-4122 v5, which specifies
    /// SHA-1). Stable across devices, platforms, and app versions by construction.
    ///
    /// Where CryptoKit is missing, on Linux, the hash is swift-crypto's `Crypto`, the same SHA-256,
    /// which FRUS Explorer Light's package supplies; the plan's id is written as Foundation writes a
    /// UUID there too, in upper case, so a host on Linux mints the app's ids
    /// (`ArchiveVisitDerivedIdTests` holds six to the values the app's code gives).
    ///
    /// - Parameters:
    ///   - planId: the owning plan's id.
    ///   - key: the child's stable key — a target key (§2b) or a `volumeId/documentId`.
    public static func derivedChildId(planId: UUID, key: String) -> UUID {
        let digest = SHA256.hash(data: Data("\(planId.uuidString)|\(key)".utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x80   // version nibble: 8 (custom, deterministic)
        bytes[8] = (bytes[8] & 0x3F) | 0x80   // RFC-4122 variant: 10xxxxxx
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3],
                           bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11],
                           bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    // MARK: - Names (§4a)

    /// The fallback display name for a plan with an empty `name` (§4a: created plans auto-name
    /// from their seed; an unseeded plan is untitled and renameable in place).
    public static var untitledName: String {
        String(localized: "archiveVisit.untitled.name", defaultValue: "Untitled Archives Visit")
    }

    /// The name shown in lists — the stored name, or the untitled fallback.
    public static func displayName(of name: String) -> String {
        name.isEmpty ? untitledName : name
    }

    /// The name a rename writes from the reader's draft: the draft without the white space and new
    /// lines around it, or `nil` when nothing is left, which writes nothing — an empty commit never
    /// clears a plan to Untitled (the Working Corpora rule). The list ignores such a commit and the
    /// editor and the Mac's manager put the plan's name back in the field.
    public static func name(fromDraft draft: String) -> String? {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// A duplicate's name: the shipped `"%@ copy"` grammar under this feature's **own** localization
    /// key (reusing `collection.duplicate.name %@` would be a silent i18n collision), over the
    /// plan's display name, kept until the reader renames it (owner decision, 2026-08-26).
    public static func duplicateName(of name: String) -> String {
        String(format: String(localized: "archiveVisit.duplicate.name %@",
                              defaultValue: "%@ copy"), displayName(of: name))
    }

    // MARK: - A new plan (#1366)

    /// A new plan, as every creation site makes one: the Research tab's New Archives Visit, the Mac
    /// window's New, the Add to Archives Visit picker's New row and Project Home's Plan a Visit
    /// (`ArchiveVisitPlan.make(name:activeProject:)` in the app).
    ///
    /// A plan created under a project **belongs to it** — `projectIds`, as collections and notes
    /// created under the active project do — and **copies its research question into the inquiry
    /// text**, so the packet sheet's topic field shows exactly what the export prints. A blank
    /// question copies nothing, and the export prints the placeholder rather than an empty topic.
    /// The copy is taken once, here: a later edit to the project's question reaches the plan only by
    /// an explicit Re-seed from Project (``reseed(_:fromProject:now:)``). A new plan has no seeds, no
    /// stored targets, no tiers and the default deliverables; a site that seeds it adds its documents
    /// next (``addingSeeds(_:includeSource:includeExternalRefs:to:planId:now:)``, both halves on from
    /// Project Home, the picker's own from the picker).
    ///
    /// - Parameters:
    ///   - name: the user-visible name; `""` for an untitled plan.
    ///   - projectId: the project the plan is created under, or `nil` in the global context; a host
    ///     whose active project no longer exists passes `nil`, as the app does.
    ///   - researchQuestion: that project's research question.
    ///   - id: the new plan's id, random unless a test names one.
    ///   - now: its creation and modification date.
    public static func newPlan(name: String, projectId: UUID?, researchQuestion: String?,
                               id: UUID = UUID(), now: Date = Date()) -> ArchiveVisitPlanExport {
        ArchiveVisitPlanExport(
            id: id,
            name: name,
            inquiryText: TripPacketTopicSentence.written(researchQuestion),
            projectIds: projectId.map { [$0] } ?? [],
            tiers: [],
            deliverables: ArchiveVisitDeliverables(),
            documents: [],
            targets: [],
            createdAt: now,
            lastModified: now)
    }

    // MARK: - Duplication (§4a)

    /// An independent copy of `plan` — seeds, tiers, toggles and every stored target state — under
    /// ``duplicateName(of:)``.
    ///
    /// Child rows get **fresh derived ids** — recomputed from the new plan's id, since a derived
    /// id is a function of `planId | key` and the keys are unchanged. Tier ids are deliberately
    /// NOT re-minted: a stored target's `tierId` references them, and re-minting would strand
    /// every copied assignment in the implicit Unprioritized group. Every row is created `now`.
    ///
    /// What the records do not carry, the app's reserved `stateData` of each seed and stored target
    /// and the tiers' and deliverables' blobs as stored, the app copies from the plan's own rows.
    ///
    /// - Parameters:
    ///   - plan: the plan, with its seeds and stored targets.
    ///   - id: the copy's id, random unless a test names one.
    ///   - now: the copy's rows' creation and modification date.
    public static func duplicate(of plan: ArchiveVisitPlanExport, id: UUID = UUID(),
                                 now: Date = Date()) -> ArchiveVisitPlanExport {
        ArchiveVisitPlanExport(
            id: id,
            name: duplicateName(of: plan.name),
            inquiryText: plan.inquiryText,
            projectIds: plan.projectIds,
            tiers: plan.tiers,
            deliverables: plan.deliverables,
            documents: plan.documents.map { document in
                ArchiveVisitDocumentExport(
                    id: derivedChildId(planId: id, key: document.documentKey),
                    documentKey: document.documentKey,
                    includeSource: document.includeSource,
                    includeExternalRefs: document.includeExternalRefs,
                    createdAt: now, lastModified: now)
            },
            targets: plan.targets.map { target in
                ArchiveVisitTargetExport(
                    id: derivedChildId(planId: id, key: target.targetKey),
                    targetKey: target.targetKey,
                    tierId: target.tierId,
                    included: target.included,
                    userNote: target.userNote,
                    createdAt: now, lastModified: now)
            },
            createdAt: now,
            lastModified: now)
    }

    // MARK: - Deletion (§4a)

    /// The rows a plan's delete removes: the plan **and its children**.
    public struct Deletion: Equatable, Sendable {
        /// The plan's id.
        public let planId: UUID
        /// Every seed's id.
        public let documentIds: [UUID]
        /// Every stored target's id, orphans and superseded rows among them.
        public let targetIds: [UUID]

        /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
        public init(planId: UUID, documentIds: [UUID], targetIds: [UUID]) {
            self.planId = planId
            self.documentIds = documentIds
            self.targetIds = targetIds
        }
    }

    /// The delete's cascade: every seed and every stored target of `plan` goes with it. The one
    /// supported way to delete a plan — the app's relationships are `.nullify` (CloudKit supports no
    /// cascade), so a bare delete of the plan would orphan every child row, invisible in the UI but
    /// alive in the store and in CloudKit forever; a host whose store cascades deletes these too.
    public static func deletion(of plan: ArchiveVisitPlanExport) -> Deletion {
        Deletion(planId: plan.id, documentIds: plan.documents.map(\.id),
                 targetIds: plan.targets.map(\.id))
    }

    // MARK: - Stored rows

    /// A stored row a write changes: its index in the rows the rule was given, and the record as it
    /// is after the write.
    public struct StoredRow<Record: Equatable & Sendable>: Equatable, Sendable {
        /// The row's index in the rows the rule read.
        public let index: Int
        /// The row after the write.
        public let record: Record

        /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
        public init(index: Int, record: Record) {
            self.index = index
            self.record = record
        }
    }

    // MARK: - Seeds

    /// What adding documents to a plan writes.
    public struct SeedAddition: Equatable, Sendable {
        /// The new seed rows, in the order their documents were given.
        public let inserted: [ArchiveVisitDocumentExport]
        /// Every stored seed the documents name, the first of its key, with the halves it has after
        /// the add: the requested ones on, the others as they were. A seed whose halves were
        /// already on is listed too, since the app has always written them (and its stamper dates the
        /// row's change); a host may skip it.
        public let updated: [StoredRow<ArchiveVisitDocumentExport>]

        /// How many NEW seed rows were minted.
        public var mintedCount: Int { inserted.count }

        /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
        public init(inserted: [ArchiveVisitDocumentExport],
                    updated: [StoredRow<ArchiveVisitDocumentExport>]) {
            self.inserted = inserted
            self.updated = updated
        }
    }

    /// Adds seeds to a plan — the one write path every add flow shares.
    ///
    /// Upserts by key: a document already seeded gains the requested contributions
    /// (flags turn ON, never off — adding "references" from Source Explorer must not silently
    /// switch off a source contribution another surface added), and a new document mints its
    /// row with exactly the requested flags, under its derived id. A request for neither half
    /// writes nothing.
    ///
    /// - Parameters:
    ///   - documents: the documents to add, as `(volumeId, documentId)`.
    ///   - includeSource: whether their own source notes contribute.
    ///   - includeExternalRefs: whether their footnotes' citations contribute.
    ///   - seeds: the plan's stored seeds, in the order the host holds them.
    ///   - planId: the plan's id.
    ///   - now: a new row's creation and modification date.
    public static func addingSeeds(_ documents: [(volumeId: String, documentId: String)],
                                   includeSource: Bool, includeExternalRefs: Bool,
                                   to seeds: [ArchiveVisitDocumentExport], planId: UUID,
                                   now: Date = Date()) -> SeedAddition {
        guard includeSource || includeExternalRefs else { return SeedAddition(inserted: [], updated: []) }
        var storedByKey: [String: Int] = [:]
        for (index, seed) in seeds.enumerated() where storedByKey[seed.documentKey] == nil {
            storedByKey[seed.documentKey] = index
        }
        var inserted: [ArchiveVisitDocumentExport] = []
        var insertedKeys = Set<String>()
        var updated: [StoredRow<ArchiveVisitDocumentExport>] = []
        var updatedIndexes = Set<Int>()
        for document in documents {
            let key = "\(document.volumeId)/\(document.documentId)"
            if let index = storedByKey[key] {
                guard updatedIndexes.insert(index).inserted else { continue }
                var record = seeds[index]
                if includeSource { record.includeSource = true }
                if includeExternalRefs { record.includeExternalRefs = true }
                updated.append(StoredRow(index: index, record: record))
                continue
            }
            guard insertedKeys.insert(key).inserted else { continue }
            inserted.append(ArchiveVisitDocumentExport(
                id: derivedChildId(planId: planId, key: key), documentKey: key,
                includeSource: includeSource, includeExternalRefs: includeExternalRefs,
                createdAt: now, lastModified: now))
        }
        return SeedAddition(inserted: inserted, updated: updated)
    }

    // MARK: - Re-seed from Project (1e, #1366)

    /// What offering the project's current research question to a plan's topic does — the
    /// decision behind Re-seed from Project's second half (#1366; ``ArchiveVisitTopicReseed``).
    /// ``ArchiveVisitTopicReseed/filled(question:)`` writes the question as the inquiry text, which
    /// was empty; the other outcomes write nothing, and text of the reader's own is never replaced
    /// here: on ``ArchiveVisitTopicReseed/needsConfirmation(question:current:)`` the host asks, and
    /// writes the question only on the reader's yes.
    ///
    /// - Parameters:
    ///   - inquiryText: the plan's inquiry text, as stored.
    ///   - question: the project's research question as it stands now.
    public static func topicReseed(inquiryText: String?, question: String?) -> ArchiveVisitTopicReseed {
        guard let question = TripPacketTopicSentence.written(question) else { return .unchanged }
        guard let current = TripPacketTopicSentence.written(inquiryText) else {
            return .filled(question: question)
        }
        if TripPacketTopicSentence.sameText(current, question) { return .unchanged }
        return .needsConfirmation(question: question, current: current)
    }

    /// The project a plan is re-seeded from, as its host read it: its research question now, and
    /// the composite keys (`volumeId/documentId`) of its current leads union, which the app gathers
    /// through `ProjectLeadsService.gatherSeed` over saved data.
    public struct ProjectSeed: Equatable, Sendable {
        /// The project's research question as it stands now.
        public let researchQuestion: String?
        /// The project's seed documents' composite keys.
        public let seedKeys: [String]

        /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
        public init(researchQuestion: String?, seedKeys: [String]) {
            self.researchQuestion = researchQuestion
            self.seedKeys = seedKeys
        }
    }

    /// What Re-seed from Project writes: the seeds it adds, and its topic's outcome.
    public struct Reseed: Equatable, Sendable {
        /// The project's documents added as seeds, both halves on.
        public let seeds: SeedAddition
        /// The topic's outcome; ``ArchiveVisitTopicReseed/filled(question:)`` writes the question.
        public let topic: ArchiveVisitTopicReseed

        /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
        public init(seeds: SeedAddition, topic: ArchiveVisitTopicReseed) {
            self.seeds = seeds
            self.topic = topic
        }
    }

    /// 1e's explicit Re-seed from Project: adds the project's CURRENT leads union as new seeds
    /// (both contributions on, never removing anything — a mirror would silently erase choices),
    /// then offers the project's current research question to the topic through
    /// ``topicReseed(inquiryText:question:)`` (#1366). Before #1366 it moved documents only, so a
    /// question written after the plan was made could never reach it.
    ///
    /// A project that no longer exists (`project` is `nil`) changes nothing and reports `.unchanged`
    /// (#1366 review): a deleted project's notes and collections keep its id — "kept but unlinked",
    /// per the delete confirmation — so gathering over that id would re-seed from records the reader
    /// was told had left the project. The editor offers no Re-seed then.
    ///
    /// - Parameters:
    ///   - plan: the plan, with its seeds, as stored after the host gathered the project's seed.
    ///   - project: the project as the host read it, or `nil` when it no longer exists.
    ///   - now: a new seed's creation and modification date.
    public static func reseed(_ plan: ArchiveVisitPlanExport, fromProject project: ProjectSeed?,
                              now: Date = Date()) -> Reseed {
        guard let project else {
            return Reseed(seeds: SeedAddition(inserted: [], updated: []), topic: .unchanged)
        }
        let documents = project.seedKeys.compactMap { DocumentKey(compositeString: $0)?.tuple }
        return Reseed(
            seeds: addingSeeds(documents, includeSource: true, includeExternalRefs: true,
                               to: plan.documents, planId: plan.id, now: now),
            topic: topicReseed(inquiryText: plan.inquiryText, question: project.researchQuestion))
    }

    // MARK: - A target's stored state (§2a)

    /// A target's stored row, as a write finds it: the row the plan stores, or one minted for it.
    public enum TargetRow: Equatable, Sendable {
        /// The row the plan stores for the target.
        case stored(StoredRow<ArchiveVisitTargetExport>)
        /// A new row, minted under the target's current key and its derived id.
        case minted(ArchiveVisitTargetExport)

        /// The row's record, as the write leaves it.
        public var record: ArchiveVisitTargetExport {
            switch self {
            case .stored(let row): row.record
            case .minted(let record): record
            }
        }
    }

    /// The stored state row for a target key, minting one when `mint` and none exists —
    /// the §2a overlay rule: a row exists only once the user gives the target state, and
    /// its id is DERIVED so two devices minting the same row create a collapsible pair.
    ///
    /// `overlay` is the one the caller rendered from. Through its ``ArchiveVisitOverlay/storedKeys``
    /// a target whose row was minted under a key the re-index re-spelled finds that row (#1421
    /// review); without it the lookup minted a second row beside it, and the target's tier and
    /// note stayed on the first. A new row is minted under the target's current key. The parameter
    /// has no default (#1421 review, round 2): the editor's four write sites are covered by no test,
    /// so a site that dropped it would still compile and would mint the duplicate again. Pass `nil`
    /// only where nothing has been rendered yet.
    ///
    /// - Parameters:
    ///   - key: the derived target's key.
    ///   - overlay: the overlay the caller rendered from, or `nil`.
    ///   - mint: whether to mint a row when none is stored.
    ///   - targets: the plan's stored targets, in the order the host holds them.
    ///   - planId: the plan's id.
    ///   - now: a minted row's creation and modification date.
    /// - Returns: The stored row, the first of its key; a minted one; or `nil` when none is stored and
    ///   `mint` is false.
    public static func targetRow(forKey key: String, resolvedBy overlay: ArchiveVisitOverlay?,
                                 mintIfMissing mint: Bool, among targets: [ArchiveVisitTargetExport],
                                 planId: UUID, now: Date = Date()) -> TargetRow? {
        if let stored = storedRow(forKey: key, resolvedBy: overlay, among: targets) {
            return .stored(stored)
        }
        guard mint else { return nil }
        return .minted(mintedRow(forKey: key, planId: planId, now: now))
    }

    /// Assigns a target a tier, or Unprioritized with `nil`. Assigning a tier is STATE, so it mints
    /// the overlay row (§2a); clearing back to Unprioritized keeps the row — an explicit choice is
    /// state too.
    public static func settingTier(_ tierId: UUID?, forKey key: String,
                                   resolvedBy overlay: ArchiveVisitOverlay?,
                                   among targets: [ArchiveVisitTargetExport], planId: UUID,
                                   now: Date = Date()) -> TargetRow {
        writing(forKey: key, resolvedBy: overlay, among: targets, planId: planId, now: now) {
            $0.tierId = tierId
        }
    }

    /// Keeps a target in the packet, or excludes it: excluding is state, so it mints the row.
    public static func settingIncluded(_ included: Bool, forKey key: String,
                                       resolvedBy overlay: ArchiveVisitOverlay?,
                                       among targets: [ArchiveVisitTargetExport], planId: UUID,
                                       now: Date = Date()) -> TargetRow {
        writing(forKey: key, resolvedBy: overlay, among: targets, planId: planId, now: now) {
            $0.included = included
        }
    }

    /// Writes a target's note from the reader's draft (``note(fromDraft:)``); committing a note,
    /// even an empty one, mints the row, as the editor's Save always has.
    public static func settingNote(fromDraft draft: String, forKey key: String,
                                   resolvedBy overlay: ArchiveVisitOverlay?,
                                   among targets: [ArchiveVisitTargetExport], planId: UUID,
                                   now: Date = Date()) -> TargetRow {
        writing(forKey: key, resolvedBy: overlay, among: targets, planId: planId, now: now) {
            $0.userNote = note(fromDraft: draft)
        }
    }

    /// The note a draft writes: the draft without the white space and new lines around it, or
    /// `nil` when nothing is left.
    public static func note(fromDraft draft: String) -> String? {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// The stored row a Remove deletes — the editor's Stored targets, for an orphan or a superseded
    /// row, which is written by its own key: the stored row for `key`, or `nil` when none is stored.
    public static func removingState(forKey key: String, resolvedBy overlay: ArchiveVisitOverlay?,
                                     among targets: [ArchiveVisitTargetExport])
        -> StoredRow<ArchiveVisitTargetExport>? {
        storedRow(forKey: key, resolvedBy: overlay, among: targets)
    }

    /// The stored row for `key`, through the overlay's ``ArchiveVisitOverlay/storedKey(for:)``: the
    /// first of the plan's rows with that key.
    private static func storedRow(forKey key: String, resolvedBy overlay: ArchiveVisitOverlay?,
                                  among targets: [ArchiveVisitTargetExport])
        -> StoredRow<ArchiveVisitTargetExport>? {
        let storedKey = overlay?.storedKey(for: key) ?? key
        guard let index = targets.firstIndex(where: { $0.targetKey == storedKey }) else { return nil }
        return StoredRow(index: index, record: targets[index])
    }

    /// A new row for `key`: no tier, included, no note, under its derived id.
    private static func mintedRow(forKey key: String, planId: UUID, now: Date) -> ArchiveVisitTargetExport {
        ArchiveVisitTargetExport(id: derivedChildId(planId: planId, key: key), targetKey: key,
                                 tierId: nil, included: true, userNote: nil,
                                 createdAt: now, lastModified: now)
    }

    /// The stored or minted row for `key` with `change` applied.
    private static func writing(forKey key: String, resolvedBy overlay: ArchiveVisitOverlay?,
                                among targets: [ArchiveVisitTargetExport], planId: UUID, now: Date,
                                _ change: (inout ArchiveVisitTargetExport) -> Void) -> TargetRow {
        if let stored = storedRow(forKey: key, resolvedBy: overlay, among: targets) {
            var record = stored.record
            change(&record)
            return .stored(StoredRow(index: stored.index, record: record))
        }
        var record = mintedRow(forKey: key, planId: planId, now: now)
        change(&record)
        return .minted(record)
    }

    // MARK: - Tiers (artboard 1c)

    /// `tiers` in the order a plan stores them: by `order`, ascending, equal orders as they came —
    /// the plan's `tiers` setter's sort, so the list a rule answers is the one the plan keeps.
    public static func storedOrder(_ tiers: [ArchiveVisitTier]) -> [ArchiveVisitTier] {
        tiers.sorted { $0.order < $1.order }
    }

    /// A new, unlabeled tier at the end: its `order` is the count of the tiers before it, and it
    /// reads "Priority N" until it is labeled. A new plan starts with NO tiers (§7).
    ///
    /// - Parameters:
    ///   - tiers: the plan's tiers, in order.
    ///   - id: the new tier's id, random unless a test names one.
    public static func addingTier(to tiers: [ArchiveVisitTier], id: UUID = UUID()) -> [ArchiveVisitTier] {
        var tiers = tiers
        tiers.append(ArchiveVisitTier(id: id, label: nil, order: tiers.count))
        return storedOrder(tiers)
    }

    /// A tier relabeled from the reader's draft: trimmed, and an empty draft clears the label, so the
    /// tier reads by its position again. `nil` when no tier has `id`, which writes nothing.
    public static func relabelingTier(_ id: UUID, toDraft draft: String,
                                      in tiers: [ArchiveVisitTier]) -> [ArchiveVisitTier]? {
        guard let index = tiers.firstIndex(where: { $0.id == id }) else { return nil }
        var tiers = tiers
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        tiers[index].label = trimmed.isEmpty ? nil : trimmed
        return storedOrder(tiers)
    }

    /// The tiers reordered: those at `source`, in their order, moved to before the tier at
    /// `destination` (or to the end at the count), as a list's drag moves them, then numbered in
    /// their new order. The move is SwiftUI's `move(fromOffsets:toOffset:)`, which the app's tier
    /// sheet called and a test holds this to.
    public static func movingTiers(fromOffsets source: IndexSet, toOffset destination: Int,
                                   in tiers: [ArchiveVisitTier]) -> [ArchiveVisitTier] {
        var moved = moving(tiers, fromOffsets: source, toOffset: destination)
        for index in moved.indices { moved[index].order = index }
        return moved
    }

    /// The elements at `source`, in their order, moved to before the element at `destination`, the
    /// others keeping theirs: SwiftUI's `MutableCollection.move(fromOffsets:toOffset:)`, which a
    /// kit cannot import. An offset past the end is read as the end.
    static func moving<Element>(_ elements: [Element], fromOffsets source: IndexSet,
                                toOffset destination: Int) -> [Element] {
        let end = min(max(destination, 0), elements.count)
        var before: [Element] = [], moved: [Element] = [], after: [Element] = []
        for (offset, element) in elements.enumerated() {
            if source.contains(offset) {
                moved.append(element)
            } else if offset < end {
                before.append(element)
            } else {
                after.append(element)
            }
        }
        return before + moved + after
    }

    /// What removing a tier writes.
    public struct TierRemoval: Equatable, Sendable {
        /// The tiers left, numbered in their order.
        public let tiers: [ArchiveVisitTier]
        /// Every stored target the tier held, its tier cleared to Unprioritized.
        public let clearedTargets: [StoredRow<ArchiveVisitTargetExport>]

        /// The memberwise initialiser, spelled out because a synthesized one is never `public`.
        public init(tiers: [ArchiveVisitTier], clearedTargets: [StoredRow<ArchiveVisitTargetExport>]) {
            self.tiers = tiers
            self.clearedTargets = clearedTargets
        }
    }

    /// Removes a tier: its members drop to Unprioritized, and nothing is removed from the plan.
    /// The members move NOW rather than dangling, for the device that removes it; a row that names
    /// the tier from another device still reads as Unprioritized, by the overlay's dangling-id rule.
    ///
    /// - Parameters:
    ///   - id: the tier's id.
    ///   - tiers: the plan's tiers, in order.
    ///   - targets: the plan's stored targets, in the order the host holds them.
    public static func removingTier(_ id: UUID, from tiers: [ArchiveVisitTier],
                                    targets: [ArchiveVisitTargetExport]) -> TierRemoval {
        var kept = tiers.filter { $0.id != id }
        for index in kept.indices { kept[index].order = index }
        let cleared = targets.indices.filter { targets[$0].tierId == id }.map { index in
            var record = targets[index]
            record.tierId = nil
            return StoredRow(index: index, record: record)
        }
        return TierRemoval(tiers: kept, clearedTargets: cleared)
    }
}
