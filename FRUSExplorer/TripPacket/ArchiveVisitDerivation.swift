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

// MARK: - ArchiveVisitOverlay

/// A plan's stored per-target state, joined onto a derived ``TripPacketModel`` at render time
/// (Archive-Visit-Plan-Design §2a): tier assignments, exclusions, notes, and the stored-row
/// accounting the coverage report owes.
///
/// A value type the exporter and the editor both read, so the artifact and the screen cannot
/// apply a plan's state differently. The model itself stays a pure derivation from the seeds —
/// state is an overlay HERE, never merged into the model, which is what lets an untouched
/// target keep deriving correctly as volumes index.
///
/// Version history:
///   1.0 — Archive Visits Phase 3: initial implementation
struct ArchiveVisitOverlay: Equatable, Sendable {

    /// The plan's tiers, in order. Empty for a plan that never prioritized.
    var tiers: [ArchiveVisitTier] = []
    /// `targetKey` → assigned tier id. A key absent here — or assigned a tier id no longer in
    /// ``tiers`` — is Unprioritized, which always sorts last.
    var tierAssignments: [String: UUID] = [:]
    /// Target keys the user excluded from the rendered packet.
    var excludedKeys: Set<String> = []
    /// `targetKey` → the researcher's note.
    var notes: [String: String] = [:]
    /// How many state rows the plan stores in all.
    var storedKeyCount: Int = 0
    /// Stored keys that no longer derive from the current seeds — kept with their tier and
    /// notes, disclosed by the coverage report, never deleted (the owner's orphan decision).
    var orphanKeys: [String] = []

    /// The tier a target key resolves to, or `nil` for Unprioritized (including a dangling
    /// tier id, which reads as Unprioritized — degraded, never crashed).
    func tier(for key: String) -> ArchiveVisitTier? {
        guard let tierId = tierAssignments[key] else { return nil }
        return tiers.first { $0.id == tierId }
    }

    /// The tier's sort position for a target key — its index in ``tiers``, or `Int.max` for
    /// Unprioritized, so the implicit group always sorts last.
    func tierOrderIndex(for key: String) -> Int {
        guard let tier = tier(for: key),
              let index = tiers.firstIndex(of: tier) else { return Int.max }
        return index
    }

    /// The display name for a tier — its label, or the positional fallback the 1c artboard
    /// specifies ("An unlabeled tier reads 'Priority 1'").
    func displayName(for tier: ArchiveVisitTier) -> String {
        if let label = tier.label, !label.isEmpty { return label }
        let position = (tiers.firstIndex(of: tier) ?? 0) + 1
        return String(format: String(localized: "archiveVisit.tier.unnamed %lld",
                                     defaultValue: "Priority %lld"), Int64(position))
    }
}

// MARK: - ArchiveVisitDerivation

/// Derives the rendered state of an ``ArchiveVisitPlan``: the packet model from its seeds
/// through the §5 two-list seam, plus the state overlay and the seed-coverage numbers.
///
/// ONE derivation path — the editor's target list, the export sheet, and the list row's
/// summary all read this, so no two surfaces can disagree about what a plan's targets are.
///
/// Version history:
///   1.0 — Archive Visits Phase 3: initial implementation
@MainActor
enum ArchiveVisitDerivation {

    /// Everything a surface needs to render a plan.
    struct Derived {
        /// The packet model, built from the plan's seeds under its contribution flags, with
        /// the plan's edited inquiry text applied to the topic sentence.
        let model: TripPacketModel
        /// The plan's stored state, joined at render time.
        let overlay: ArchiveVisitOverlay
        /// How many documents seed the plan.
        let seededDocumentCount: Int
        /// How many of those seeds live in volumes indexed on this device — the
        /// `WorkingCorpusResolver` membership rule (by volume, one set lookup per key).
        let indexedDocumentCount: Int
    }

    /// Splits a `"volumeId/documentId"` key into the tuple every pipeline call takes.
    static func documentTuple(fromKey key: String) -> (volumeId: String, documentId: String)? {
        guard let slash = key.firstIndex(of: "/") else { return nil }
        let volumeId = String(key[..<slash])
        let documentId = String(key[key.index(after: slash)...])
        guard !volumeId.isEmpty, !documentId.isEmpty else { return nil }
        return (volumeId: volumeId, documentId: documentId)
    }

    /// Derives a plan's rendered state.
    ///
    /// - Parameters:
    ///   - plan: the plan.
    ///   - indexedVolumeIds: the device's indexed volumes, for the seed-coverage numbers.
    ///   - dataSource: the packet's pipeline seam.
    static func derive(
        plan: ArchiveVisitPlan,
        indexedVolumeIds: Set<String>,
        dataSource: some TripPacketReferenceDataSource
    ) async -> Derived {
        // The seeds, in a stable order so two devices derive identically.
        let seeds = (plan.documents ?? []).sorted { $0.documentKey < $1.documentKey }

        // The §5 projection: contribution flags become two lists AT THE SEAM, and are never
        // threaded through the build loops.
        let sourceDocuments = seeds.filter(\.includeSource)
            .compactMap { documentTuple(fromKey: $0.documentKey) }
        let referenceDocuments = seeds.filter(\.includeExternalRefs)
            .compactMap { documentTuple(fromKey: $0.documentKey) }

        var model = await TripPacketBuilder.build(
            sourceDocuments: sourceDocuments,
            referenceDocuments: referenceDocuments,
            researchQuestion: plan.projectResearchQuestionSeed,
            dataSource: dataSource)
        // The plan's persistent inquiry text is the edited topic sentence — the same slot the
        // ephemeral sheet writes, so the exporter's forExport rule needs no second reader.
        if let inquiryText = plan.inquiryText,
           !inquiryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            model.topicSentence.edited = inquiryText
        }

        // The overlay: stored rows joined by key; a stored key with no derived target is an
        // orphan — kept and disclosed, never deleted.
        let derivedKeys = Set(model.targets.map(\.key))
        var overlay = ArchiveVisitOverlay(tiers: plan.tiers)
        let storedRows = plan.targets ?? []
        overlay.storedKeyCount = storedRows.count
        for row in storedRows.sorted(by: { $0.targetKey < $1.targetKey }) {
            if let tierId = row.tierId { overlay.tierAssignments[row.targetKey] = tierId }
            if !row.included { overlay.excludedKeys.insert(row.targetKey) }
            if let note = row.userNote, !note.isEmpty { overlay.notes[row.targetKey] = note }
            if !derivedKeys.contains(row.targetKey) { overlay.orphanKeys.append(row.targetKey) }
        }

        let indexed = seeds.filter { seed in
            guard let volumeId = seed.documentKey.split(separator: "/").first else { return false }
            return indexedVolumeIds.contains(String(volumeId))
        }.count

        return Derived(model: model, overlay: overlay,
                       seededDocumentCount: seeds.count, indexedDocumentCount: indexed)
    }
}

// MARK: - Plan state mutation

extension ArchiveVisitPlan {

    /// The research question that seeds the plan's topic sentence when no edit exists yet —
    /// reserved for a project join at render time. Phase 3 renders `nil` here (a plan's
    /// persistent `inquiryText` is the researcher's own text; the project's question seeds
    /// only at creation, so a later project edit cannot silently rewrite a draft).
    var projectResearchQuestionSeed: String? { nil }

    /// Renames the plan. `lastModified` is stamped at save time by `ModelModificationStamper`.
    func rename(to newName: String) {
        name = newName
    }

    /// The stored state row for a target key, minting one when `mint` and none exists —
    /// the §2a overlay rule: a row exists only once the user gives the target state, and
    /// its id is DERIVED so two devices minting the same row create a collapsible pair.
    ///
    /// The caller saves the context.
    func targetState(forKey key: String, mintIfMissing mint: Bool,
                     in context: ModelContext) -> ArchiveVisitTarget? {
        if let existing = (targets ?? []).first(where: { $0.targetKey == key }) {
            return existing
        }
        guard mint else { return nil }
        let row = ArchiveVisitTarget(planId: id, targetKey: key)
        row.plan = self
        context.insert(row)
        return row
    }

    /// Adds seeds to the plan — the one write path every add flow shares.
    ///
    /// Upserts by derived id: a document already seeded gains the requested contributions
    /// (flags turn ON, never off — adding "references" from Source Explorer must not silently
    /// switch off a source contribution another surface added), and a new document mints its
    /// row with exactly the requested flags. Returns how many NEW seed rows were minted.
    /// The caller saves the context.
    @discardableResult
    func addSeeds(_ documents: [(volumeId: String, documentId: String)],
                  includeSource: Bool, includeExternalRefs: Bool,
                  in context: ModelContext) -> Int {
        guard includeSource || includeExternalRefs else { return 0 }
        var existingByKey = Dictionary((self.documents ?? []).map { ($0.documentKey, $0) },
                                       uniquingKeysWith: { first, _ in first })
        var minted = 0
        for document in documents {
            let key = "\(document.volumeId)/\(document.documentId)"
            if let existing = existingByKey[key] {
                if includeSource { existing.includeSource = true }
                if includeExternalRefs { existing.includeExternalRefs = true }
                continue
            }
            let seed = ArchiveVisitDocument(planId: id, documentKey: key)
            seed.plan = self
            seed.includeSource = includeSource
            seed.includeExternalRefs = includeExternalRefs
            context.insert(seed)
            existingByKey[key] = seed
            minted += 1
        }
        return minted
    }
}
