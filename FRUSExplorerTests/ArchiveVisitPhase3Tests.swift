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

// MARK: - Fixtures

/// A stub data source for the derivation tests — the same seam `TripPacketBuilderTests`
/// drives, redeclared here because that suite's stub is private to it.
@MainActor
private struct DerivationStub: TripPacketReferenceDataSource {
    var sources: [CollectionGeneratedBlocks.SourceRecord] = []
    var citations: [String: [ExternalCitation]] = [:]

    func citation(volumeId: String, documentId: String) -> String { "\(volumeId)/\(documentId)" }
    func dateMetadata(for documents: [(volumeId: String, documentId: String)])
        async -> [String: DocumentDateMetadata] { [:] }
    func documentSources(for documents: [(volumeId: String, documentId: String)])
        async -> [CollectionGeneratedBlocks.SourceRecord] {
        // Honor the request list — the two-list seam is the thing under test, and a stub
        // that ignored its argument would pass whatever the builder asked for.
        let requested = Set(documents.map { "\($0.volumeId)/\($0.documentId)" })
        return sources.filter { requested.contains("\($0.volumeId)/\($0.documentId)") }
    }
    func externalCitations(for documents: [(volumeId: String, documentId: String)])
        async -> [String: [ExternalCitation]] {
        let requested = Set(documents.map { "\($0.volumeId)/\($0.documentId)" })
        return citations.filter { requested.contains($0.key) }
    }
    func archivalResolution(recordGroup: String?, lotFile: String?)
        -> CollectionGeneratedBlocks.ArchivalLink? { nil }
    func personMentions(for documents: [(volumeId: String, documentId: String)])
        async -> [CollectionGeneratedBlocks.PersonMention] { [] }
    func tagRecords() async -> [CollectionGeneratedBlocks.TagRecord] { [] }
}

private func lotRecord(_ volume: String, _ document: String,
                       lot: String) -> CollectionGeneratedBlocks.SourceRecord {
    .init(volumeId: volume, documentId: document, repository: nil,
          recordGroup: "59", lotFile: lot, seriesName: nil,
          rawText: "Department of State, Lot \(lot)", citationEra: "lot_file")
}

private func lotCitation(lot: String, norm: String) -> ExternalCitation {
    ExternalCitation(anchor: "lotFile", repository: "Department of State", collection: nil,
                     lotFile: lot, lotFileNorm: norm, fileId: nil, inherited: false,
                     rawText: "Not printed. (Lot \(lot))", noteOrdinal: 0)
}

// MARK: - ArchiveVisitDerivationTests

/// Pins the plan → packet derivation (Phase 3): the §5 two-list projection, the overlay
/// join, and the seed-coverage numbers — the ONE path the editor, the list row, and the
/// export sheet all render from.
///
/// Version history:
///   1.0 — Archive Visits Phase 3: initial implementation
@Suite("Archive Visit derivation (Phase 3)")
struct ArchiveVisitDerivationTests {

    @MainActor
    private func makePlan(in context: ModelContext) -> ArchiveVisitPlan {
        let plan = ArchiveVisitPlan(name: "P")
        context.insert(plan)
        return plan
    }

    /// **The §5 seam.** A document's contribution flags decide which CHANNEL it feeds —
    /// resolved at the boundary, never inside the build loops.
    @MainActor
    @Test("Contribution flags project into the two channels")
    func flagsProjectIntoChannels() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let plan = makePlan(in: context)
        // A: source only. B: refs only. C: both. All three carry a source note AND a
        // footnote citation in the stub, so any leakage across the seam is visible.
        plan.addSeeds([("v1", "dA")], includeSource: true, includeExternalRefs: false,
                      in: context)
        plan.addSeeds([("v1", "dB")], includeSource: false, includeExternalRefs: true,
                      in: context)
        plan.addSeeds([("v1", "dC")], includeSource: true, includeExternalRefs: true,
                      in: context)
        try context.save()

        let stub = DerivationStub(
            sources: [lotRecord("v1", "dA", lot: "60 D 1"),
                      lotRecord("v1", "dB", lot: "60 D 1"),
                      lotRecord("v1", "dC", lot: "60 D 1")],
            citations: ["v1/dA": [lotCitation(lot: "60 D 2", norm: "60D2")],
                        "v1/dB": [lotCitation(lot: "60 D 2", norm: "60D2")],
                        "v1/dC": [lotCitation(lot: "60 D 2", norm: "60D2")]])
        let derived = await ArchiveVisitDerivation.derive(
            plan: plan, indexedVolumeIds: ["v1"], dataSource: stub)

        let drawn = derived.model.targets.first { $0.key == "lot|60D1" }
        #expect(drawn?.drawnFrom.map(\.documentId).sorted() == ["dA", "dC"], """
            The drawn-from channel must hold exactly the includeSource documents — dB's
            source note exists in the stub, and only the flag keeps it out.
            """)
        let pointed = derived.model.targets.first { $0.key == "lot|60D2" }
        #expect(pointed?.pointedAt.map(\.documentId).sorted() == ["dB", "dC"], """
            The pointed-at channel must hold exactly the includeExternalRefs documents.
            """)
        #expect(derived.model.referenceCoverage.documentsScanned == 2,
                "refs are scanned over the refs list only — dA was never scanned")
    }

    @MainActor
    @Test("The overlay joins stored state and detects orphans")
    func overlayJoinsStoredState() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let plan = makePlan(in: context)
        plan.addSeeds([("v1", "d1")], includeSource: true, includeExternalRefs: false,
                      in: context)
        let tier = ArchiveVisitTier(label: "Day one", order: 0)
        plan.tiers = [tier]

        let state = ArchiveVisitTarget(planId: plan.id, targetKey: "lot|60D1")
        state.plan = plan
        state.tierId = tier.id
        state.userNote = "Ask first"
        context.insert(state)
        let excluded = ArchiveVisitTarget(planId: plan.id, targetKey: "lot|60D1X")
        excluded.plan = plan
        excluded.included = false
        context.insert(excluded)
        // An orphan by construction: nothing derives this key.
        let orphan = ArchiveVisitTarget(planId: plan.id, targetKey: "lot|99Z999")
        orphan.plan = plan
        context.insert(orphan)
        try context.save()

        let stub = DerivationStub(sources: [lotRecord("v1", "d1", lot: "60 D 1")])
        let derived = await ArchiveVisitDerivation.derive(
            plan: plan, indexedVolumeIds: ["v1"], dataSource: stub)

        #expect(derived.overlay.tierAssignments["lot|60D1"] == tier.id)
        #expect(derived.overlay.notes["lot|60D1"] == "Ask first")
        #expect(derived.overlay.excludedKeys.contains("lot|60D1X"))
        #expect(derived.overlay.storedKeyCount == 3)
        #expect(derived.overlay.orphanKeys.contains("lot|99Z999"), """
            A stored key that no longer derives is an ORPHAN — kept and disclosed; only
            the derived-key set decides, never deletion.
            """)
        #expect(!derived.overlay.orphanKeys.contains("lot|60D1"),
                "a deriving key is not an orphan")
    }

    @MainActor
    @Test("The plan's inquiry text becomes the edited topic sentence")
    func inquiryTextBecomesEditedTopic() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let plan = makePlan(in: context)
        plan.inquiryText = "The airlift's supply arithmetic."
        plan.addSeeds([("v1", "d1")], includeSource: true, includeExternalRefs: false,
                      in: context)
        try context.save()
        let derived = await ArchiveVisitDerivation.derive(
            plan: plan, indexedVolumeIds: [], dataSource: DerivationStub())
        #expect(derived.model.topicSentence.forExport == "The airlift's supply arithmetic.")
    }

    @MainActor
    @Test("Seed coverage counts by indexed volume")
    func seedCoverageCountsByVolume() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let plan = makePlan(in: context)
        plan.addSeeds([("v1", "d1"), ("v2", "d1"), ("v2", "d2")],
                      includeSource: true, includeExternalRefs: true, in: context)
        try context.save()
        let derived = await ArchiveVisitDerivation.derive(
            plan: plan, indexedVolumeIds: ["v2"], dataSource: DerivationStub())
        #expect(derived.seededDocumentCount == 3)
        #expect(derived.indexedDocumentCount == 2,
                "coverage is by VOLUME membership — the WorkingCorpusResolver rule")
    }

    @MainActor
    @Test("documentTuple parses composite keys and refuses malformed ones")
    func documentTupleParses() {
        let tuple = ArchiveVisitDerivation.documentTuple(fromKey: "frus1948v02/d3")
        #expect(tuple?.volumeId == "frus1948v02")
        #expect(tuple?.documentId == "d3")
        #expect(ArchiveVisitDerivation.documentTuple(fromKey: "nokey") == nil)
        #expect(ArchiveVisitDerivation.documentTuple(fromKey: "/d3") == nil)
        #expect(ArchiveVisitDerivation.documentTuple(fromKey: "v1/") == nil)
    }

    // MARK: - addSeeds (the one write path)

    @MainActor
    @Test("addSeeds unions flags and never switches one off")
    func addSeedsUnionsFlags() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let plan = makePlan(in: context)

        let minted = plan.addSeeds([("v1", "d1")], includeSource: true,
                                   includeExternalRefs: false, in: context)
        #expect(minted == 1)
        let seed = try #require(plan.documents?.first)
        #expect(seed.includeSource && !seed.includeExternalRefs)

        // A second surface adds the OTHER claim: union, not overwrite.
        let mintedAgain = plan.addSeeds([("v1", "d1")], includeSource: false,
                                        includeExternalRefs: true, in: context)
        #expect(mintedAgain == 0, "an existing seed is upserted, never duplicated")
        #expect(plan.documents?.count == 1)
        #expect(seed.includeSource, """
            Adding references must NOT switch off the source contribution another surface
            added — flags turn on through this path, never off.
            """)
        #expect(seed.includeExternalRefs)

        // A no-claims add writes nothing.
        let none = plan.addSeeds([("v1", "d2")], includeSource: false,
                                 includeExternalRefs: false, in: context)
        #expect(none == 0)
        #expect(plan.documents?.count == 1)
    }
}

// MARK: - ArchiveVisitExporterOverlayTests

/// Pins the exporter's plan-state rendering (Phase 3): exclusions, tier grouping, notes,
/// the stored-rows coverage line, and the §3b deliverable gating.
///
/// Version history:
///   1.0 — Archive Visits Phase 3: initial implementation
@Suite("Archive Visit exporter overlay (Phase 3)")
struct ArchiveVisitExporterOverlayTests {

    /// A two-lot model at one facility, for tier and exclusion rules.
    private func model() -> TripPacketModel {
        TripPacketModel.build(
            groups: [
                (key: "lot|60D1", label: "Lot 60 D 1", category: .lotFile,
                 repository: nil, lotAsPrinted: "60 D 1", resolution: nil,
                 documents: TripPacketExporterTests.refs(2, note: "Lot 60 D 1 note")),
                (key: "lot|60D2", label: "Lot 60 D 2", category: .lotFile,
                 repository: nil, lotAsPrinted: "60 D 2", resolution: nil,
                 documents: TripPacketExporterTests.refs(2, volume: "frus1948v03",
                                                         note: "Lot 60 D 2 note")),
            ],
            documentYears: [1950], unresolvedLotCount: 2, unresolvedDocumentCount: 0,
            researchQuestion: nil, facts: { _ in nil }, claimants: { _ in nil })
    }

    private func overlay() -> ArchiveVisitOverlay {
        let tier = ArchiveVisitTier(label: "Day one", order: 0)
        var overlay = ArchiveVisitOverlay(tiers: [tier])
        // The LATER-sorting lot gets the tier, so tier order must beat label order.
        overlay.tierAssignments["lot|60D2"] = tier.id
        overlay.notes["lot|60D2"] = "Ask about the folder list."
        overlay.storedKeyCount = 3
        overlay.orphanKeys = ["lot|99Z999"]
        return overlay
    }

    @Test("Tier assignments prefix the heading and order targets within a facility")
    func tierOrdersAndPrefixes() throws {
        var exporter = TripPacketExporter(model: model(), projectName: "P")
        exporter.overlay = overlay()
        let text = exporter.export()
        #expect(text.contains("### [Day one] Lot 60 D 2"),
                "the assigned tier rides the heading as the 1g bracket prefix")
        let d2 = try #require(text.range(of: "### [Day one] Lot 60 D 2"))
        let d1 = try #require(text.range(of: "### Lot 60 D 1"))
        #expect(d2.lowerBound < d1.lowerBound, """
            Within a repository the tiered target must render BEFORE the unprioritized one
            (§5: repository → priority; Unprioritized always last) — label order alone would
            put Lot 60 D 1 first, which is what makes this fixture a real test.
            """)
        #expect(text.contains("Note: Ask about the folder list."),
                "the researcher's note rides the target row")
    }

    @Test("An excluded target leaves the export, and the coverage report says so")
    func exclusionFiltersAndDiscloses() {
        var exporter = TripPacketExporter(model: model(), projectName: "P")
        var state = overlay()
        state.excludedKeys = ["lot|60D1"]
        exporter.overlay = state
        let text = exporter.export()
        #expect(!text.contains("### Lot 60 D 1"), "the excluded target must not render")
        #expect(text.contains("### [Day one] Lot 60 D 2"))
        #expect(text.contains("1 target excluded from this export by you."),
                "an exclusion is disclosed, never silently applied")
    }

    @Test("The stored-rows coverage line uses the 1h both-numbers grammar")
    func storedRowsCoverageLine() {
        var exporter = TripPacketExporter(model: model(), projectName: "P")
        exporter.overlay = overlay()
        let text = exporter.export()
        #expect(text.contains("2 of 3 stored target rows derive from the current seeds — "
                              + "1 kept and labeled, never deleted."), """
            The coverage report owes the stored-row accounting: 3 stored, 1 orphan.
            """)
    }

    @Test("Deliverable toggles gate their sections, and the honesty block never goes")
    func deliverablesGateSections() {
        var exporter = TripPacketExporter(model: model(), projectName: "P")
        exporter.deliverables = ArchiveVisitDeliverables(
            includeLinks: false, includeTargets: false,
            includeInquiry: false, includeCitationCrib: false)
        let text = exporter.export()
        #expect(!text.contains("### Lot"), "targets off → no target rows")
        #expect(!text.contains("## Advance inquiry"), "inquiry off → no drafts")
        #expect(!text.contains("Plan your visit:"), "links off → no link block")
        #expect(text.contains("## What this packet covers"), """
            The coverage report is NOT a deliverable and renders whatever is toggled off —
            the honesty block is not optional (§3c).
            """)
        #expect(text.contains("# Archive visit packet"))

        var linksOnly = TripPacketExporter(model: model(), projectName: "P")
        linksOnly.deliverables = ArchiveVisitDeliverables(
            includeLinks: true, includeTargets: false,
            includeInquiry: false, includeCitationCrib: false)
        let linksText = linksOnly.export()
        #expect(linksText.contains("## National Archives at College Park"),
                "links on → the repository sections render for their link blocks")
        #expect(!linksText.contains("### Lot"), "…without target rows")
    }
}
