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

import CryptoKit
import Foundation
import SwiftData

// MARK: - ArchiveVisitPlan

/// A persistent archival research plan — the Archive Visits program's stored state
/// (Archive-Visit-Plan-Design §2, Phase 2).
///
/// ## Three record types, and why not one blob
/// The owner's condition for this shape was genuine multi-device protection, and §2a answers it
/// mechanically: SwiftData mirrors one `@Model` to one CKRecord, so two devices editing
/// **different** targets touch different records and nothing conflicts — where a single blob makes
/// every edit rewrite one field, and the loser of that merge loses its *whole session* (every
/// tier, note, and newly minted target), silently. The child model's residual cost is duplicate
/// rows, which are visible and repairable; a silent revert is neither.
///
/// ## Targets are a STATE OVERLAY, not a materialized list
/// An ``ArchiveVisitTarget`` row is minted only when the user gives that target state — a tier,
/// a note, an exclusion. An untouched target is a pure render-time derivation from the plan's
/// seeds, so record count is bounded by what the user touched, and two devices deriving the same
/// target list independently create **zero** records. The rendered list is
/// `derived(seeds) ∪ stored-state rows` — which is also the coverage-reporting doctrine for
/// orphans: a stored row whose key no longer derives from the seeds is disclosed, never deleted.
///
/// ## Identity is citation-derived, never resolved
/// A target key is the form-aware, claim-free key of §2b (`TripPacketBuilder.targetKey` /
/// `referenceKey`): the decimal CLASS, the normalized lot, the repository|collection pair, or the
/// raw note text — never a NAID, never anything an artifact refresh or reindex re-mints.
/// Resolution stays render-time, so improving artifacts improve a plan's display without touching
/// stored state.
///
/// ## CloudKit
/// Enrolled in `frusModelTypes` (**three new CloudKit record types: deploy the schema to
/// Production before shipping** — the reserved W-4+W-5 promotion, per the owner's timing
/// decision; `CloudKitSchemaInventory.identifiersAwaitingDeploy` is the holding state until
/// then). All relationships are `.nullify` with inverses (CloudKit supports no cascade), so
/// deletion goes through ``deleteWithChildren(in:)``. No property observers — the `@Model` macro
/// silently discards `didSet` bodies (see `ModelModificationStamper`); `lastModified` is stamped
/// at save time by that stamper, which all three types conform to.
///
/// Version history:
///   1.0 — Archive Visits Phase 2: initial implementation
@Model final class ArchiveVisitPlan {

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Display

    /// User-visible name. Not unique — duplicates are allowed and disambiguated by `id`, because
    /// uniqueness across CloudKit devices cannot be guaranteed. Empty renders as
    /// ``untitledName``.
    var name: String = ""

    // MARK: - The inquiry

    /// The researcher's edited topic sentence for the advance-inquiry drafts — the persistent
    /// home of `TripPacketTopicSentence.edited`. `nil` falls back to the active project's
    /// research question at render time (D8), exactly as the ephemeral sheet does.
    var inquiryText: String?

    // MARK: - Association

    /// Projects this plan belongs to, by raw UUID — the `Collection.projectIds` pattern
    /// (no `@Relationship`; deletion order in `ResetInventory` is what protects the reference).
    var projectIds: [UUID] = []

    // MARK: - Tiers

    /// The user-defined priority tiers, as an encoded ``ArchiveVisitTier`` array — a blob, not a
    /// child model, because a tier is a tiny plan-scoped value (id · optional label · order) that
    /// is always read and written as a whole ordered list. Read and write through ``tiers``;
    /// never mutate the decoded array in place expecting persistence.
    ///
    /// New plans start with **no** tiers (§7: per-object state starts empty, as focus tags do);
    /// the implicit Unprioritized group always exists and holds everything unassigned.
    var tiersData: Data?

    // MARK: - Deliverables (§3b)

    /// The per-plan deliverable toggles, as an encoded ``ArchiveVisitDeliverables`` — per-plan
    /// rather than global by owner decision, so a plan re-opened on another device renders the
    /// same artifact. `nil` means the defaults ((a)/(b)/(c) on, the citation appendix off);
    /// read and write through ``deliverables``. A blob rather than four Bool columns for the
    /// `SavedSearch.parametersData` reason: a future appendix toggle costs no CloudKit deploy,
    /// and the field-drop class (a new toggle silently reverting on old records) is
    /// unrepresentable because the whole value is archived.
    var deliverableTogglesData: Data?

    // MARK: - Children

    /// The plan's seeded documents. `deleteRule: .nullify` is required for CloudKit sync
    /// compatibility — delete children explicitly via ``deleteWithChildren(in:)``.
    @Relationship(deleteRule: .nullify, inverse: \ArchiveVisitDocument.plan)
    var documents: [ArchiveVisitDocument]?

    /// The plan's stored per-target state — the overlay, not the target list (see the type
    /// comment). Same delete rule and the same explicit-deletion obligation.
    @Relationship(deleteRule: .nullify, inverse: \ArchiveVisitTarget.plan)
    var targets: [ArchiveVisitTarget]?

    // MARK: - Timestamps

    /// Optional for CloudKit schema compatibility — always non-nil in practice.
    var createdAt: Date?
    /// Optional for CloudKit schema compatibility — always non-nil in practice. Stamped at save
    /// time by `ModelModificationStamper`; what CloudKit's last-writer-wins resolves on.
    var lastModified: Date?

    // MARK: - Init

    /// Creates a plan.
    ///
    /// - Parameters:
    ///   - name: the user-visible name; pass `""` for an untitled plan.
    ///   - inquiryText: the inquiry topic sentence, when seeded with one.
    ///   - projectIds: owning projects.
    init(name: String, inquiryText: String? = nil, projectIds: [UUID] = []) {
        self.id = UUID()
        self.name = name
        self.inquiryText = inquiryText
        self.projectIds = projectIds
        self.createdAt = Date()
        self.lastModified = Date()
    }

    // MARK: - Names

    /// The fallback display name for a plan with an empty `name` (§4a: created plans auto-name
    /// from their seed; an unseeded plan is untitled and renameable in place).
    static var untitledName: String {
        String(localized: "archiveVisit.untitled.name", defaultValue: "Untitled Archive Visit")
    }

    /// The name shown in lists — the stored name, or the untitled fallback.
    var displayName: String { name.isEmpty ? Self.untitledName : name }

    // MARK: - Tiers accessor

    /// The decoded tier list, in `order`. Assign a whole array to persist — assignment
    /// re-encodes into ``tiersData``, which is what actually syncs.
    var tiers: [ArchiveVisitTier] {
        get {
            guard let tiersData else { return [] }
            return (try? JSONDecoder().decode([ArchiveVisitTier].self, from: tiersData)) ?? []
        }
        set {
            tiersData = try? JSONEncoder().encode(newValue.sorted { $0.order < $1.order })
        }
    }

    // MARK: - Deliverables accessor

    /// The decoded deliverable toggles, defaulting per §3b when none were ever stored.
    var deliverables: ArchiveVisitDeliverables {
        get {
            guard let deliverableTogglesData else { return ArchiveVisitDeliverables() }
            return (try? JSONDecoder().decode(ArchiveVisitDeliverables.self,
                                              from: deliverableTogglesData))
                ?? ArchiveVisitDeliverables()
        }
        set {
            deliverableTogglesData = try? JSONEncoder().encode(newValue)
        }
    }

    // MARK: - Derived child ids (§2a)

    /// The deterministic id for a child row of this plan — a namespace hash over
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
    /// - Parameters:
    ///   - planId: the owning plan's id.
    ///   - key: the child's stable key — a target key (§2b) or a `volumeId/documentId`.
    static func derivedChildId(planId: UUID, key: String) -> UUID {
        let digest = SHA256.hash(data: Data("\(planId.uuidString)|\(key)".utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x80   // version nibble: 8 (custom, deterministic)
        bytes[8] = (bytes[8] & 0x3F) | 0x80   // RFC-4122 variant: 10xxxxxx
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3],
                           bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11],
                           bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    // MARK: - Duplication (§4a)

    /// Creates an independent copy of this plan — seeds, tiers, toggles and every stored target
    /// state — and inserts it into `context`. Returns the new plan; the caller saves.
    ///
    /// The copy's name takes the shipped `"%@ copy"` grammar under this feature's **own**
    /// localization key (reusing `collection.duplicate.name %@` would be a silent i18n
    /// collision), and keeps it until the user renames it (owner decision, 2026-08-26).
    ///
    /// Child rows get **fresh derived ids** — recomputed from the new plan's id, since a derived
    /// id is a function of `planId | key` and the keys are unchanged. Tier ids are deliberately
    /// NOT re-minted: `ArchiveVisitTarget.tierId` references them, and re-minting would strand
    /// every copied assignment in the implicit Unprioritized group.
    @discardableResult
    func duplicate(in context: ModelContext) -> ArchiveVisitPlan {
        let base = name.isEmpty ? Self.untitledName : name
        let copy = ArchiveVisitPlan(
            name: String(format: String(localized: "archiveVisit.duplicate.name %@",
                                        defaultValue: "%@ copy"), base),
            inquiryText: inquiryText,
            projectIds: projectIds)
        copy.tiersData = tiersData
        copy.deliverableTogglesData = deliverableTogglesData
        context.insert(copy)

        for document in documents ?? [] {
            let seed = ArchiveVisitDocument(planId: copy.id, documentKey: document.documentKey)
            seed.plan = copy
            seed.includeSource = document.includeSource
            seed.includeExternalRefs = document.includeExternalRefs
            seed.stateData = document.stateData
            context.insert(seed)
        }
        for target in targets ?? [] {
            let state = ArchiveVisitTarget(planId: copy.id, targetKey: target.targetKey)
            state.plan = copy
            state.tierId = target.tierId
            state.included = target.included
            state.userNote = target.userNote
            state.stateData = target.stateData
            context.insert(state)
        }
        return copy
    }

    // MARK: - Deletion (§4a)

    /// Deletes this plan **and its children** from `context`. The caller saves.
    ///
    /// The one supported way to delete a plan: the relationships are `.nullify` (CloudKit
    /// supports no cascade), so a bare `context.delete(plan)` would orphan every child row —
    /// invisible in the UI but alive in the store and in CloudKit forever.
    func deleteWithChildren(in context: ModelContext) {
        for document in documents ?? [] { context.delete(document) }
        for target in targets ?? [] { context.delete(target) }
        context.delete(self)
    }
}

// MARK: - ArchiveVisitDocument

/// One seeded document of an ``ArchiveVisitPlan``, with its per-document contribution flags —
/// which of the document's two archival claims feed the plan's targets.
///
/// A child `@Model` rather than a blob entry so two devices editing different documents' flags
/// never conflict (§2a). The id is **derived** (`ArchiveVisitPlan.derivedChildId`), so two
/// devices seeding the same document mint the same row and `DuplicateRecordCleanup` can collapse
/// the pair.
///
/// Version history:
///   1.0 — Archive Visits Phase 2: initial implementation
@Model final class ArchiveVisitDocument {

    // MARK: - Identity

    /// Derived from `planId | documentKey` — see ``ArchiveVisitPlan/derivedChildId(planId:key:)``.
    var id: UUID = UUID()

    // MARK: - Parent

    /// Back-reference to the owning plan. Required by CloudKit sync (all relationships must have
    /// inverses). Managed by `ArchiveVisitPlan.documents`; do not set directly.
    var plan: ArchiveVisitPlan?

    /// The parent plan's id, carried explicitly for fast lookups that don't need the full graph —
    /// the `CollectionEntry.collectionId` pattern.
    var planId: UUID = UUID()

    // MARK: - The seed

    /// The seeded document, as `"volumeId/documentId"` — the same composite key the index and
    /// the packet builder speak, so no translation layer stands between stored state and the
    /// query that applies it.
    var documentKey: String = ""

    /// Whether this document's own source note (the drawn-from claim) feeds the plan.
    var includeSource: Bool = true

    /// Whether this document's footnote citations (the pointed-at claim) feed the plan.
    /// References exist on a small minority of documents; the UI captions the absent half
    /// rather than rendering a dead toggle (§4).
    var includeExternalRefs: Bool = true

    // MARK: - Evolution

    /// Reserved evolution column (the `SavedSearch.parametersData` pattern) — future per-document
    /// properties are added to its payload, costing no further CloudKit deploy.
    var stateData: Data?

    // MARK: - Timestamps

    /// Optional for CloudKit schema compatibility — always non-nil in practice. The dedupe
    /// keeper tie-break reads it.
    var createdAt: Date?
    /// Stamped at save time by `ModelModificationStamper`.
    var lastModified: Date?

    // MARK: - Init

    /// Creates a seed row. The id is derived, never random — see the type comment.
    init(planId: UUID, documentKey: String) {
        self.id = ArchiveVisitPlan.derivedChildId(planId: planId, key: documentKey)
        self.planId = planId
        self.documentKey = documentKey
        self.createdAt = Date()
        self.lastModified = Date()
    }
}

// MARK: - ArchiveVisitTarget

/// Stored per-target state of an ``ArchiveVisitPlan`` — the overlay row, minted only when the
/// user gives a target state (a tier, a note, an exclusion). Never a materialized target list:
/// an untouched target derives at render time and stores nothing (§2a).
///
/// `targetKey` is §2b's form-aware, claim-free key (`class|…` / `lot|…` / `coll|…` / `r|…`),
/// citation-derived so no artifact refresh or authority re-clustering ever moves it. A row whose
/// key no longer derives from the plan's seeds is an **orphan**: kept with its tier and note,
/// disclosed by the coverage report, never deleted by the app.
///
/// Version history:
///   1.0 — Archive Visits Phase 2: initial implementation
@Model final class ArchiveVisitTarget {

    // MARK: - Identity

    /// Derived from `planId | targetKey` — see ``ArchiveVisitPlan/derivedChildId(planId:key:)``.
    var id: UUID = UUID()

    // MARK: - Parent

    /// Back-reference to the owning plan. Required by CloudKit sync; managed by
    /// `ArchiveVisitPlan.targets`; do not set directly.
    var plan: ArchiveVisitPlan?

    /// The parent plan's id, carried explicitly for fast lookups.
    var planId: UUID = UUID()

    // MARK: - The state

    /// The target's stable key (§2b) — the unit's identity, never its resolution.
    var targetKey: String = ""

    /// The assigned tier's id (an ``ArchiveVisitTier/id`` in the plan's ``ArchiveVisitPlan/tiers``),
    /// or `nil` for the implicit Unprioritized group. A dangling tier id (its tier deleted on
    /// another device) reads as Unprioritized — degraded, never crashed.
    var tierId: UUID?

    /// Whether the target is included in the rendered packet. Excluding is state, so setting
    /// this `false` is one of the acts that mints the row.
    var included: Bool = true

    /// The researcher's note on this target, shown in the editor and carried to exports.
    var userNote: String?

    // MARK: - Evolution

    /// Reserved evolution column — see ``ArchiveVisitDocument/stateData``.
    var stateData: Data?

    // MARK: - Timestamps

    /// Optional for CloudKit schema compatibility — always non-nil in practice. The dedupe
    /// keeper tie-break reads it.
    var createdAt: Date?
    /// Stamped at save time by `ModelModificationStamper`.
    var lastModified: Date?

    // MARK: - Init

    /// Creates a state row. The id is derived, never random — see the type comment.
    init(planId: UUID, targetKey: String) {
        self.id = ArchiveVisitPlan.derivedChildId(planId: planId, key: targetKey)
        self.planId = planId
        self.targetKey = targetKey
        self.createdAt = Date()
        self.lastModified = Date()
    }
}

// MARK: - ArchiveVisitTier

/// One user-defined priority tier of a plan (§2): an id targets assign to, an optional label,
/// and a position. Any number per plan; the implicit Unprioritized group is not a tier and
/// always sorts last.
///
/// A `Codable` value in ``ArchiveVisitPlan/tiersData``, not a `@Model`: a tier is read and
/// written as part of the plan's whole ordered list, and its only cross-record reference is
/// `ArchiveVisitTarget.tierId` — which survives a tier's deletion as a dangling id that reads
/// as Unprioritized.
struct ArchiveVisitTier: Codable, Equatable, Sendable, Identifiable {
    /// Stable identity — what `ArchiveVisitTarget.tierId` references. Survives relabeling.
    var id: UUID = UUID()
    /// Optional display label ("If time allows"). `nil` renders as a positional name.
    var label: String?
    /// Sort position among the plan's tiers, ascending.
    var order: Int = 0
}

// MARK: - ArchiveVisitDeliverables

/// The per-plan deliverable toggles (§3b): the three core deliverables, on by default, and the
/// citation-guidance appendix, off by default (owner decision — an opt-in appendix).
///
/// ## The decoder is hand-written, and that is load-bearing
/// Swift's synthesized `Decodable` ignores a property's default value, so a future toggle added
/// to this struct would make every already-stored blob undecodable — silently resetting every
/// plan's toggles to the defaults through the accessor's `try?`. `decodeIfPresent ?? default`
/// per field is what makes the blob actually evolvable, which is the reason it is a blob.
struct ArchiveVisitDeliverables: Codable, Equatable, Sendable {
    /// Deliverable (a): the repository visit-planning links.
    var includeLinks = true
    /// Deliverable (b): the target list.
    var includeTargets = true
    /// Deliverable (c): the per-repository inquiry drafts.
    var includeInquiry = true
    /// The NARA citation-guidance appendix (§3a: opt-in, default off).
    var includeCitationCrib = false

    init(includeLinks: Bool = true, includeTargets: Bool = true,
         includeInquiry: Bool = true, includeCitationCrib: Bool = false) {
        self.includeLinks = includeLinks
        self.includeTargets = includeTargets
        self.includeInquiry = includeInquiry
        self.includeCitationCrib = includeCitationCrib
    }

    enum CodingKeys: String, CodingKey {
        case includeLinks, includeTargets, includeInquiry, includeCitationCrib
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        includeLinks = try container.decodeIfPresent(Bool.self, forKey: .includeLinks) ?? true
        includeTargets = try container.decodeIfPresent(Bool.self, forKey: .includeTargets) ?? true
        includeInquiry = try container.decodeIfPresent(Bool.self, forKey: .includeInquiry) ?? true
        includeCitationCrib =
            try container.decodeIfPresent(Bool.self, forKey: .includeCitationCrib) ?? false
    }
}
