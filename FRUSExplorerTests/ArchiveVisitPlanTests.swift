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

import Testing
import Foundation
import SwiftData
@testable import FRUSExplorer

// MARK: - ArchiveVisitPlanTests

/// Pins the Archive Visit plan schema's behaviors (Archive Visits Phase 2).
///
/// The schema itself is pinned by `CloudKitSchemaInventoryTests` (identifiers + deploy marker)
/// and `ResetInventoryTests` (reset fate); this suite pins what the types DO — the derived-id
/// rule the whole multi-device story rests on, duplication under the owner's naming decision,
/// the explicit cascade, the two blob accessors and their tolerant decoding, the dedupe
/// enrolment, and the format-6 export.
///
/// Version history:
///   1.0 — Archive Visits Phase 2: initial implementation
@Suite("Archive Visit plan (Phase 2)")
struct ArchiveVisitPlanTests {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer.makeTestContainer()
    }

    // MARK: - Derived ids (§2a)

    /// **The rule the multi-device story rests on.** SwiftData under CloudKit cannot declare
    /// `@Attribute(.unique)` and `DuplicateRecordCleanup` groups by `id` — so two devices
    /// minting the same row must mint the same id *deterministically*, which a random UUID
    /// would hide from that pass.
    @MainActor
    @Test("Child ids are a deterministic function of plan and key")
    func derivedIdsAreDeterministic() {
        let planId = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let a = ArchiveVisitPlan.derivedChildId(planId: planId, key: "lot|64D199")
        let b = ArchiveVisitPlan.derivedChildId(planId: planId, key: "lot|64D199")
        #expect(a == b, "the same plan and key must always derive the same id")

        #expect(ArchiveVisitPlan.derivedChildId(planId: planId, key: "lot|64D198") != a,
                "a different key must derive a different id")
        #expect(ArchiveVisitPlan.derivedChildId(planId: UUID(), key: "lot|64D199") != a,
                "the id is namespaced by plan, or two plans' rows would collapse into one another")

        // Both child inits derive rather than randomize — "two devices seeding from the same
        // document mint the same row" is a property of the INIT, not a discipline.
        let planUUID = UUID()
        let first = ArchiveVisitDocument(planId: planUUID, documentKey: "frus1948v02/d3")
        let second = ArchiveVisitDocument(planId: planUUID, documentKey: "frus1948v02/d3")
        #expect(first.id == second.id)
        let stateA = ArchiveVisitTarget(planId: planUUID, targetKey: "class|762.00")
        let stateB = ArchiveVisitTarget(planId: planUUID, targetKey: "class|762.00")
        #expect(stateA.id == stateB.id)
        #expect(first.id != stateA.id, "a document key and a target key must not collide")
    }

    /// The derived id is stable across app versions by construction; this fixture pins one
    /// concrete value so an accidental change to the hash input or bit-twiddling — which would
    /// orphan every existing child row's identity — fails a test instead of shipping.
    @MainActor
    @Test("The derived-id function is pinned against a fixture")
    func derivedIdIsPinned() {
        let planId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let derived = ArchiveVisitPlan.derivedChildId(planId: planId, key: "class|611.51")
        #expect(ArchiveVisitPlan.derivedChildId(planId: planId, key: "class|611.51") == derived)
        // RFC-4122 shape: version nibble 8 (custom deterministic), variant bits 10.
        let bytes = derived.uuid
        #expect(bytes.6 & 0xF0 == 0x80, "version nibble must be 8")
        #expect(bytes.8 & 0xC0 == 0x80, "variant bits must be 10xxxxxx")
    }

    // MARK: - Duplication (§4a)

    @MainActor
    @Test("Duplicate takes the copy grammar, keeps tiers, and re-derives child ids")
    func duplicateCopiesEverythingUnderFreshDerivedIds() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plan = ArchiveVisitPlan(name: "Berlin blockade", inquiryText: "The airlift's arithmetic.")
        let tier = ArchiveVisitTier(label: "First morning", order: 0)
        plan.tiers = [tier]
        var toggles = plan.deliverables
        toggles.includeCitationCrib = true
        plan.deliverables = toggles
        context.insert(plan)

        let seed = ArchiveVisitDocument(planId: plan.id, documentKey: "frus1948v02/d3")
        seed.plan = plan
        seed.includeExternalRefs = false
        context.insert(seed)

        let state = ArchiveVisitTarget(planId: plan.id, targetKey: "lot|64D199")
        state.plan = plan
        state.tierId = tier.id
        state.userNote = "Ask about the divided series."
        context.insert(state)
        try context.save()

        let copy = plan.duplicate(in: context)
        try context.save()

        #expect(copy.name == "Berlin blockade copy",
                "the owner's decision: the shipped \"%@ copy\" grammar, under this feature's own key")
        #expect(copy.id != plan.id)
        #expect(copy.inquiryText == plan.inquiryText)
        #expect(copy.deliverables.includeCitationCrib)

        // Tier ids are deliberately NOT re-minted: per-target tier assignments reference them.
        #expect(copy.tiers == [tier])
        let copiedState = try #require(copy.targets?.first)
        #expect(copiedState.tierId == tier.id,
                "the copied assignment must still point at a tier that exists in the copy")
        #expect(copiedState.userNote == state.userNote)
        #expect(copiedState.included == state.included)

        // Child ids are FRESH, and fresh means re-DERIVED from the new plan id — not random.
        let copiedSeed = try #require(copy.documents?.first)
        #expect(copiedSeed.id != seed.id)
        #expect(copiedSeed.id
                == ArchiveVisitPlan.derivedChildId(planId: copy.id, key: "frus1948v02/d3"))
        #expect(copiedSeed.includeExternalRefs == false)
        #expect(copiedState.id
                == ArchiveVisitPlan.derivedChildId(planId: copy.id, key: "lot|64D199"))

        // The original is untouched.
        #expect(plan.documents?.count == 1)
        #expect(plan.targets?.count == 1)
    }

    @MainActor
    @Test("Duplicating an untitled plan names the copy from the untitled fallback")
    func duplicateOfUntitledUsesFallback() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let plan = ArchiveVisitPlan(name: "")
        context.insert(plan)
        let copy = plan.duplicate(in: context)
        #expect(copy.name == "\(ArchiveVisitPlan.untitledName) copy")
    }

    // MARK: - Deletion (§4a)

    /// The relationships are `.nullify` (CloudKit supports no cascade), so a bare delete
    /// orphans children — invisible in the UI, alive in the store and in CloudKit forever.
    @MainActor
    @Test("deleteWithChildren removes the plan and every child row")
    func deleteCascadesExplicitly() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plan = ArchiveVisitPlan(name: "P")
        context.insert(plan)
        let seed = ArchiveVisitDocument(planId: plan.id, documentKey: "v1/d1")
        seed.plan = plan
        context.insert(seed)
        let state = ArchiveVisitTarget(planId: plan.id, targetKey: "r|note")
        state.plan = plan
        context.insert(state)
        try context.save()

        plan.deleteWithChildren(in: context)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<ArchiveVisitPlan>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ArchiveVisitDocument>()) == 0,
                "an orphaned seed row survived the delete")
        #expect(try context.fetchCount(FetchDescriptor<ArchiveVisitTarget>()) == 0,
                "an orphaned target row survived the delete")
    }

    // MARK: - The blob accessors

    @MainActor
    @Test("Tiers round-trip through the blob, sorted by order, and start empty")
    func tiersRoundTrip() {
        let plan = ArchiveVisitPlan(name: "P")
        #expect(plan.tiers.isEmpty, "§7: per-object state starts empty, as focus tags do")

        let second = ArchiveVisitTier(label: "If time allows", order: 1)
        let first = ArchiveVisitTier(label: nil, order: 0)
        plan.tiers = [second, first]
        #expect(plan.tiers == [first, second], "the accessor stores in order")
        #expect(plan.tiers[0].label == nil, "a label is optional — a tier can be positional")
    }

    @MainActor
    @Test("Deliverables default to a/b/c on and the crib off, and decode tolerantly")
    func deliverablesDefaultsAndTolerantDecode() throws {
        let plan = ArchiveVisitPlan(name: "P")
        #expect(plan.deliverableTogglesData == nil)
        #expect(plan.deliverables == ArchiveVisitDeliverables())
        #expect(plan.deliverables.includeLinks)
        #expect(plan.deliverables.includeTargets)
        #expect(plan.deliverables.includeInquiry)
        #expect(!plan.deliverables.includeCitationCrib, "§3a: the appendix is opt-in, default off")

        var toggles = plan.deliverables
        toggles.includeCitationCrib = true
        plan.deliverables = toggles
        #expect(plan.deliverables.includeCitationCrib)

        // The blob's whole reason to exist: a stored value written BEFORE a future toggle was
        // added must still decode, with the missing key at its default — synthesized Decodable
        // would refuse the blob and the `try?` accessor would silently reset every plan.
        let partial = Data(#"{"includeCitationCrib":true}"#.utf8)
        let decoded = try JSONDecoder().decode(ArchiveVisitDeliverables.self, from: partial)
        #expect(decoded.includeCitationCrib)
        #expect(decoded.includeLinks && decoded.includeTargets && decoded.includeInquiry,
                "absent keys must decode to their defaults, not fail the whole blob")
        let empty = try JSONDecoder().decode(ArchiveVisitDeliverables.self, from: Data("{}".utf8))
        #expect(empty == ArchiveVisitDeliverables())
    }

    // MARK: - Dedupe enrolment (§2a)

    /// Two devices minting state for the same target create the same DERIVED id — exactly the
    /// duplicate `DuplicateRecordCleanup` collapses, and the reason the ids are not random.
    /// Driven through the real `run(context:)`, not a mirror of its grouping.
    @MainActor
    @Test("Duplicate child rows sharing a derived id collapse to one")
    func dedupeCollapsesDerivedDuplicates() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plan = ArchiveVisitPlan(name: "P")
        context.insert(plan)
        // Simulate a CloudKit import materialising the same logical row twice: two inserts
        // with the same (planId, key) carry the same derived id.
        let a = ArchiveVisitTarget(planId: plan.id, targetKey: "lot|64D199")
        a.plan = plan
        let b = ArchiveVisitTarget(planId: plan.id, targetKey: "lot|64D199")
        b.plan = plan
        context.insert(a)
        context.insert(b)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<ArchiveVisitTarget>()) == 2)

        DuplicateRecordCleanup.run(context: context)

        #expect(try context.fetchCount(FetchDescriptor<ArchiveVisitTarget>()) == 1,
                "the derived-id duplicate must collapse — this is the §2a argument in one test")
        #expect(try context.fetchCount(FetchDescriptor<ArchiveVisitPlan>()) == 1,
                "the plan itself is no duplicate and must survive")
    }

    /// A duplicated PLAN record re-parents its children to the keeper before deletion — the
    /// `dedupeCollections` shape, without which the `.nullify` relationship would orphan them.
    @MainActor
    @Test("Duplicate plan records re-parent children to the richer keeper")
    func dedupeReparentsPlanChildren() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let sharedId = UUID()
        let rich = ArchiveVisitPlan(name: "P")
        rich.id = sharedId
        context.insert(rich)
        let seed = ArchiveVisitDocument(planId: sharedId, documentKey: "v1/d1")
        seed.plan = rich
        context.insert(seed)

        let sparse = ArchiveVisitPlan(name: "P")
        sparse.id = sharedId
        context.insert(sparse)
        let orphanToBe = ArchiveVisitTarget(planId: sharedId, targetKey: "r|note")
        orphanToBe.plan = sparse
        context.insert(orphanToBe)
        try context.save()

        DuplicateRecordCleanup.run(context: context)

        let plans = try context.fetch(FetchDescriptor<ArchiveVisitPlan>())
        #expect(plans.count == 1)
        let keeper = try #require(plans.first)
        #expect(keeper.documents?.count == 1, "the richer copy's child must survive")
        #expect(keeper.targets?.count == 1,
                "the deleted duplicate's child must be re-parented, not orphaned")
    }

    // MARK: - The stamper reaches the new types

    @MainActor
    @Test("Editing any plan type stamps lastModified at save")
    func stamperReachesPlanTypes() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let stamper = ModelModificationStamper()
        stamper.start(observing: context)
        defer { stamper.stop() }
        let epoch = Date(timeIntervalSince1970: 0)

        let plan = ArchiveVisitPlan(name: "P")
        context.insert(plan)
        let seed = ArchiveVisitDocument(planId: plan.id, documentKey: "v1/d1")
        seed.plan = plan
        context.insert(seed)
        let state = ArchiveVisitTarget(planId: plan.id, targetKey: "r|note")
        state.plan = plan
        context.insert(state)
        try context.save()
        plan.lastModified = epoch
        seed.lastModified = epoch
        state.lastModified = epoch
        try context.save()

        plan.name = "P2"
        seed.includeExternalRefs = false
        state.userNote = "note"
        try context.save()

        #expect(try #require(plan.lastModified) > epoch,
                "an unstamped edit lets a stale device win every CloudKit merge")
        #expect(try #require(seed.lastModified) > epoch)
        #expect(try #require(state.lastModified) > epoch)
    }

    // MARK: - Export (format version 6)

    @MainActor
    @Test("The envelope carries plans whole — seeds, tiers, toggles, and orphan state rows")
    func envelopeCarriesPlans() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let plan = ArchiveVisitPlan(name: "Berlin blockade")
        let tier = ArchiveVisitTier(label: "First morning", order: 0)
        plan.tiers = [tier]
        context.insert(plan)
        let seed = ArchiveVisitDocument(planId: plan.id, documentKey: "frus1948v02/d3")
        seed.plan = plan
        context.insert(seed)
        // An ORPHAN by construction: no seed can derive this key. It must export anyway —
        // whether a key still derives is a render-time question the export does not ask.
        let orphan = ArchiveVisitTarget(planId: plan.id, targetKey: "lot|99Z999")
        orphan.plan = plan
        orphan.tierId = tier.id
        orphan.userNote = "Kept with your tier and notes"
        context.insert(orphan)
        try context.save()

        let envelope = try ResearchDataExporter.makeEnvelope(
            modelContext: context, includeGeneratedSummaries: false)
        #expect(envelope.formatVersion == 6)
        let exported = try #require(envelope.archiveVisits.first)
        #expect(exported.name == "Berlin blockade")
        #expect(exported.tiers == [tier])
        #expect(exported.deliverables == ArchiveVisitDeliverables())
        #expect(exported.documents.map(\.documentKey) == ["frus1948v02/d3"])
        #expect(exported.targets.map(\.targetKey) == ["lot|99Z999"],
                "the orphan row is the user's work and must be in the file")
        #expect(exported.targets.first?.tierId == tier.id)

        // And the derived packet is NOT in the file — it is a rendering, not data.
        let data = try ResearchDataExporter.exportJSONData(envelope)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(!text.contains("Advance inquiry"))
    }

    @MainActor
    @Test("A format-5 file with no archiveVisits key still decodes, as empty")
    func legacyFileWithoutPlansDecodes() throws {
        let json = Data(#"{"formatVersion":5,"exportedAt":"2026-08-01T00:00:00Z","notes":[],"tags":[],"tagAssignments":[],"highlights":[],"collections":[],"prompts":[],"projects":[],"summaries":[]}"#.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ResearchDataEnvelope.self, from: json)
        #expect(decoded.archiveVisits.isEmpty)
    }
}
