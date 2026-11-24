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

// The app's half of an Archives Visit plan's derivation and writes (FRUS Explorer Light, S30b): its SwiftData rows
// mapped to the research export's records, which FRUSCoreKit's derivation and write rules read
// (`ArchiveVisitDerivation`, `ArchiveVisitPlanWrites`), and the rows each rule answers applied through the plan's
// `ModelContext`. The forms the views and tests called before the move keep their names and signatures; the editor's
// target and tier writes, which wrote the rows in the view, are the plan's forms beside them. A rule answers a stored
// row by its index in the rows it read; each form reads the plan's relationship once and writes through that same
// array, and writes a stored row's fields only where the rule changes them — a target's one field, a seed's requested
// halves — as the write sites always did, so no other key of the row is set, observed or synced. The app makes a row
// through its initialiser, which derives its id as the rule did and stamps the moment it is made, and copies what the
// records do not carry — each row's reserved `stateData`, and the tiers' and deliverables' blobs as stored — from its
// own rows.
//
// Version history:
//   1.0 — 2026-11-24 (FRUS Explorer Light, S30b): initial implementation, when the derivation and the plan's
//          write rules moved into FRUSCoreKit; the plan-state extension is `ArchiveVisitDerivation.swift`'s as it
//          was, each write through the kit's rule, with the editor's tier and target writes beside it

// MARK: - ArchiveVisitDerivation over the plan's rows

extension ArchiveVisitDerivation {

    /// ``derive(plan:indexedVolumeIds:dataSource:indexes:)`` over the plan's rows, as their records, and the
    /// app's bundled indexes: the form the editor, the list's row, the packet sheet and the tests call.
    @MainActor
    static func derive(
        plan: ArchiveVisitPlan,
        indexedVolumeIds: Set<String>,
        dataSource: some TripPacketReferenceDataSource
    ) async -> Derived {
        await derive(plan: plan.record(documents: plan.documents ?? [], targets: plan.targets ?? []),
                     indexedVolumeIds: indexedVolumeIds, dataSource: dataSource, indexes: .bundled)
    }

    /// ``inputSignature(plan:indexedVolumeIds:)`` over the plan's rows: each seed row's three attributes and each
    /// state row's six, read from the rows themselves in the one pass the editor's and the list row's bodies pay
    /// for on every pass, through the rule both forms count by.
    @MainActor
    static func inputSignature(plan: ArchiveVisitPlan, indexedVolumeIds: Set<String>) -> InputSignature {
        inputSignature(
            seeds: (plan.documents ?? []).lazy.map {
                InputSignature.Seed(documentKey: $0.documentKey, includeSource: $0.includeSource,
                                    includeExternalRefs: $0.includeExternalRefs)
            },
            inquiryText: plan.inquiryText, tiers: plan.tiers,
            targets: (plan.targets ?? []).lazy.map {
                InputSignature.StoredTarget(targetKey: $0.targetKey, tierId: $0.tierId,
                                            included: $0.included, userNote: $0.userNote,
                                            createdAt: $0.createdAt, id: $0.id)
            },
            indexedVolumeIds: indexedVolumeIds)
    }
}

// MARK: - Plan state mutation

extension ArchiveVisitPlan {

    /// The plan as the research export's records, over `documents` and `targets`, its rows as the caller holds
    /// them, each in that order: what the kit's derivation and write rules read, which answer a stored row by its
    /// index there.
    func record(documents: [ArchiveVisitDocument], targets: [ArchiveVisitTarget]) -> ArchiveVisitPlanExport {
        ArchiveVisitPlanExport(self, documents: documents.map(ArchiveVisitDocumentExport.init),
                               targets: targets.map(ArchiveVisitTargetExport.init))
    }

    /// Offers the project's current research question to this plan's topic — the decision
    /// behind Re-seed from Project's second half (#1366; the rule is
    /// ``ArchiveVisitPlanWrites/topicReseed(inquiryText:question:)``).
    /// Writes only into an empty topic; text of the reader's own is never replaced here.
    /// The caller saves.
    ///
    /// - Parameter question: the project's research question as it stands now.
    func reseedTopic(fromProjectQuestion question: String?) -> ArchiveVisitTopicReseed {
        let outcome = ArchiveVisitPlanWrites.topicReseed(inquiryText: inquiryText, question: question)
        if case .filled(let question) = outcome { inquiryText = question }
        return outcome
    }

    /// Replaces the topic with the project's question — the confirmed half of
    /// ``ArchiveVisitTopicReseed/needsConfirmation(question:current:)``. The caller saves.
    func replaceInquiryTopic(with question: String) {
        inquiryText = question
    }

    /// 1e's explicit Re-seed from Project: adds the project's CURRENT leads union as new seeds
    /// (both contributions on, never removing anything — a mirror would silently erase choices),
    /// then offers the project's current research question to the topic through
    /// ``reseedTopic(fromProjectQuestion:)`` (#1366) — the kit's
    /// ``ArchiveVisitPlanWrites/reseed(_:fromProject:now:)``. Before #1366 it moved documents only, so a
    /// question written after the plan was made could never reach it.
    ///
    /// A project that no longer exists changes nothing and reports `.unchanged` (#1366 review): a
    /// deleted project's notes and collections keep its id — "kept but unlinked", per the delete
    /// confirmation — so gathering over that id would re-seed from records the reader was told
    /// had left the project. The editor offers no Re-seed then; this holds for a menu drawn
    /// before the delete.
    ///
    /// Saves `context` before it gathers (#1457 review): the project's seed is gathered on a fresh
    /// context, which reads only saved data, and a note, a focus tag or an attach made moments
    /// earlier may not be saved yet — `ProjectLeadsService.recompute` and Project Home's engaged set
    /// save first for the same reason. The caller saves what this writes, and asks the reader on
    /// ``ArchiveVisitTopicReseed/needsConfirmation(question:current:)``.
    @MainActor
    func reseed(fromProject projectId: UUID, in context: ModelContext) async
        -> ArchiveVisitTopicReseed {
        guard let project = Self.project(withId: projectId, in: context) else { return .unchanged }
        // Read before the await: the project is not touched again after it.
        let question = project.researchQuestion
        try? context.save()
        let keys = await ProjectLeadsService.gatherSeed(
            forProject: projectId, container: context.container).seedKeys
        // The plan as it stands after the await, which other writes may have changed.
        let rows = documents ?? []
        let reseed = ArchiveVisitPlanWrites.reseed(
            record(documents: rows, targets: []),
            fromProject: .init(researchQuestion: question, seedKeys: keys))
        apply(reseed.seeds, to: rows, in: context)
        if case .filled(let question) = reseed.topic { inquiryText = question }
        return reseed.topic
    }

    /// Renames the plan. `lastModified` is stamped at save time by `ModelModificationStamper`.
    /// The name a draft writes is ``ArchiveVisitPlanWrites/name(fromDraft:)``'s, which each rename calls first.
    func rename(to newName: String) {
        name = newName
    }

    /// The stored state row for a target key, minting one when `mint` and none exists —
    /// the §2a overlay rule: a row exists only once the user gives the target state, and
    /// its id is DERIVED so two devices minting the same row create a collapsible pair
    /// (``ArchiveVisitPlanWrites/targetRow(forKey:resolvedBy:mintIfMissing:among:planId:now:)``).
    ///
    /// `overlay` is the one the caller rendered from. Through its ``ArchiveVisitOverlay/storedKeys``
    /// a target whose row was minted under a key the re-index re-spelled finds that row (#1421
    /// review); without it the lookup minted a second row beside it, and the target's tier and
    /// note stayed on the first. A new row is minted under the target's current key. The parameter
    /// has no default (#1421 review, round 2): the editor's four write sites are covered by no test,
    /// so a site that dropped it would still compile and would mint the duplicate again. Pass `nil`
    /// only where nothing has been rendered yet.
    ///
    /// The caller saves the context.
    func targetState(forKey key: String, resolvedBy overlay: ArchiveVisitOverlay?,
                     mintIfMissing mint: Bool,
                     in context: ModelContext) -> ArchiveVisitTarget? {
        let rows = targets ?? []
        switch ArchiveVisitPlanWrites.targetRow(forKey: key, resolvedBy: overlay, mintIfMissing: mint,
                                                among: rows.map(ArchiveVisitTargetExport.init),
                                                planId: id) {
        case .stored(let stored)?: return rows[stored.index]
        case .minted(let record)?: return insertTarget(record, in: context)
        case nil: return nil
        }
    }

    /// Assigns the target `key` a tier, or Unprioritized with `nil`, minting its row
    /// (``ArchiveVisitPlanWrites/settingTier(_:forKey:resolvedBy:among:planId:now:)``); the row's tier alone is
    /// written. `overlay` as ``targetState(forKey:resolvedBy:mintIfMissing:in:)`` takes it. The caller saves.
    func setTier(_ tierId: UUID?, forKey key: String, resolvedBy overlay: ArchiveVisitOverlay?,
                 in context: ModelContext) {
        let rows = targets ?? []
        let written = ArchiveVisitPlanWrites.settingTier(tierId, forKey: key, resolvedBy: overlay,
                                                         among: rows.map(ArchiveVisitTargetExport.init),
                                                         planId: id)
        row(written, among: rows, in: context).tierId = written.record.tierId
    }

    /// Keeps the target `key` in the packet or excludes it, minting its row
    /// (``ArchiveVisitPlanWrites/settingIncluded(_:forKey:resolvedBy:among:planId:now:)``); the row's exclusion
    /// alone is written. The caller saves.
    func setIncluded(_ included: Bool, forKey key: String, resolvedBy overlay: ArchiveVisitOverlay?,
                     in context: ModelContext) {
        let rows = targets ?? []
        let written = ArchiveVisitPlanWrites.settingIncluded(included, forKey: key, resolvedBy: overlay,
                                                             among: rows.map(ArchiveVisitTargetExport.init),
                                                             planId: id)
        row(written, among: rows, in: context).included = written.record.included
    }

    /// Writes the target `key`'s note from the reader's draft, minting its row
    /// (``ArchiveVisitPlanWrites/settingNote(fromDraft:forKey:resolvedBy:among:planId:now:)``); the row's note
    /// alone is written. The caller saves.
    func setNote(fromDraft draft: String, forKey key: String, resolvedBy overlay: ArchiveVisitOverlay?,
                 in context: ModelContext) {
        let rows = targets ?? []
        let written = ArchiveVisitPlanWrites.settingNote(fromDraft: draft, forKey: key, resolvedBy: overlay,
                                                         among: rows.map(ArchiveVisitTargetExport.init),
                                                         planId: id)
        row(written, among: rows, in: context).userNote = written.record.userNote
    }

    /// The row `written`, a rule's answer for one target, names among `rows`, the stored targets it read: the
    /// stored row, or a new one for a minted record, which its caller writes its one field to.
    private func row(_ written: ArchiveVisitPlanWrites.TargetRow, among rows: [ArchiveVisitTarget],
                     in context: ModelContext) -> ArchiveVisitTarget {
        switch written {
        case .stored(let stored): rows[stored.index]
        case .minted(let record): insertTarget(record, in: context)
        }
    }

    /// A new stored row for `record`, a minted target, under the id its key derives.
    private func insertTarget(_ record: ArchiveVisitTargetExport, in context: ModelContext) -> ArchiveVisitTarget {
        let row = ArchiveVisitTarget(planId: id, targetKey: record.targetKey)
        row.plan = self
        context.insert(row)
        return row
    }

    /// Adds seeds to the plan — the one write path every add flow shares.
    ///
    /// Upserts by derived id: a document already seeded gains the requested contributions
    /// (flags turn ON, never off — adding "references" from Source Explorer must not silently
    /// switch off a source contribution another surface added), and a new document mints its
    /// row with exactly the requested flags. Returns how many NEW seed rows were minted. The rule
    /// is ``ArchiveVisitPlanWrites/addingSeeds(_:includeSource:includeExternalRefs:to:planId:now:)``.
    /// The caller saves the context.
    @discardableResult
    func addSeeds(_ documents: [(volumeId: String, documentId: String)],
                  includeSource: Bool, includeExternalRefs: Bool,
                  in context: ModelContext) -> Int {
        let rows = self.documents ?? []
        let addition = ArchiveVisitPlanWrites.addingSeeds(
            documents, includeSource: includeSource, includeExternalRefs: includeExternalRefs,
            to: rows.map(ArchiveVisitDocumentExport.init), planId: id)
        apply(addition, to: rows, in: context)
        return addition.mintedCount
    }

    /// Writes `addition` to `rows`, the stored seeds it read: each stored seed it names is written in the halves the
    /// add turns on, and those alone, and each new record becomes a row.
    private func apply(_ addition: ArchiveVisitPlanWrites.SeedAddition, to rows: [ArchiveVisitDocument],
                       in context: ModelContext) {
        for update in addition.updated {
            let seed = rows[update.index]
            if addition.turnsOnSource { seed.includeSource = update.record.includeSource }
            if addition.turnsOnExternalRefs { seed.includeExternalRefs = update.record.includeExternalRefs }
        }
        for record in addition.inserted {
            let seed = ArchiveVisitDocument(planId: id, documentKey: record.documentKey)
            seed.plan = self
            seed.includeSource = record.includeSource
            seed.includeExternalRefs = record.includeExternalRefs
            context.insert(seed)
        }
    }

    // MARK: Tiers (artboard 1c)

    /// Adds an unlabeled tier at the end (``ArchiveVisitPlanWrites/addingTier(to:id:)``). The caller saves.
    func addTier() {
        tiers = ArchiveVisitPlanWrites.addingTier(to: tiers)
    }

    /// Relabels the tier `tierId` from the reader's draft (``ArchiveVisitPlanWrites/relabelingTier(_:toDraft:in:)``);
    /// `false`, writing nothing, when the plan no longer has the tier. The caller saves.
    @discardableResult
    func relabelTier(_ tierId: UUID, toDraft draft: String) -> Bool {
        guard let relabeled = ArchiveVisitPlanWrites.relabelingTier(tierId, toDraft: draft, in: tiers)
        else { return false }
        tiers = relabeled
        return true
    }

    /// Reorders the tiers as the list's drag moved them
    /// (``ArchiveVisitPlanWrites/movingTiers(fromOffsets:toOffset:in:)``). The caller saves.
    func moveTiers(fromOffsets source: IndexSet, toOffset destination: Int) {
        tiers = ArchiveVisitPlanWrites.movingTiers(fromOffsets: source, toOffset: destination, in: tiers)
    }

    /// Removes the tier `tierId`, its members dropping to Unprioritized
    /// (``ArchiveVisitPlanWrites/removingTier(_:from:targets:)``). The caller saves.
    func removeTier(_ tierId: UUID) {
        let rows = targets ?? []
        let removal = ArchiveVisitPlanWrites.removingTier(tierId, from: tiers,
                                                          targets: rows.map(ArchiveVisitTargetExport.init))
        tiers = removal.tiers
        for cleared in removal.clearedTargets {
            rows[cleared.index].tierId = cleared.record.tierId
        }
    }
}
