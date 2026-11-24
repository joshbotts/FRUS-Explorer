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
import SwiftUI
import Testing
@testable import FRUSExplorer

// MARK: - Fixtures

/// A stub data source for the app's forms of the derivation, as `ArchiveVisitPhase3Tests`' is.
@MainActor
private struct AppFormsStub: TripPacketReferenceDataSource {
    var sources: [CollectionGeneratedBlocks.SourceRecord] = []

    func citation(volumeId: String, documentId: String, printedNumber: String?) -> String {
        "\(volumeId)/\(documentId)"
    }
    func dateMetadata(for documents: [(volumeId: String, documentId: String)])
        async -> [String: DocumentDateMetadata] { [:] }
    func documentNumbers(for documents: [(volumeId: String, documentId: String)])
        async -> [String: String] { [:] }
    func documentSources(for documents: [(volumeId: String, documentId: String)])
        async -> [CollectionGeneratedBlocks.SourceRecord] {
        let requested = Set(documents.map { "\($0.volumeId)/\($0.documentId)" })
        return sources.filter { requested.contains("\($0.volumeId)/\($0.documentId)") }
    }
    func externalCitations(for documents: [(volumeId: String, documentId: String)])
        async -> [String: [ExternalCitation]] { [:] }
    func archivalResolution(recordGroup: String?, lotFile: String?)
        -> CollectionGeneratedBlocks.ArchivalLink? { nil }
    func personMentions(for documents: [(volumeId: String, documentId: String)])
        async -> [CollectionGeneratedBlocks.PersonMention] { [] }
    func tagRecords() async -> [CollectionGeneratedBlocks.TagRecord] { [] }
}

// MARK: - ArchiveVisitAppWritesTests

/// The app's half of the plan's derivation and writes (`ArchiveVisitDerivation+App.swift`): FRUSCoreKit's rules
/// over the plan's records, applied to the SwiftData rows through the context — each row's id, keys and values the
/// records', its reserved state and the blobs copied from the rows — and the tiers' reorder held to SwiftUI's move,
/// which the tier sheet called before the rules moved. `ArchiveVisitPlanTests` and `ArchiveVisitPhase3Tests` pin
/// the same writes as they always have; these pin what the move added.
///
/// Version history:
///   1.0 — 2026-11-24: FRUS Explorer Light's S30b — the derivation and the plan's write rules moved into
///          FRUSCoreKit
@Suite("Archive Visit writes — the kit's rules applied to the app's rows")
struct ArchiveVisitAppWritesTests {

    /// Every set of offsets and every destination, up to six elements: 769 moves.
    @Test("The kit's move is SwiftUI's move(fromOffsets:toOffset:) for every offset set and destination")
    func kitMoveIsSwiftUIs() {
        var moves = 0
        for count in 0...6 {
            let elements = Array(0..<count)
            for mask in 0..<(1 << count) {
                let source = IndexSet((0..<count).filter { mask & (1 << $0) != 0 })
                for destination in 0...count {
                    var expected = elements
                    expected.move(fromOffsets: source, toOffset: destination)
                    let moved = ArchiveVisitPlanWrites.moving(elements, fromOffsets: source, toOffset: destination)
                    #expect(moved == expected, "\(elements) moving \(Array(source)) to \(destination)")
                    moves += 1
                }
            }
        }
        #expect(moves == 769)
    }

    @MainActor
    @Test("The tier sheet's add, rename, reorder and delete write the plan as the sheet did")
    func tierWrites() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let plan = ArchiveVisitPlan(name: "P")
        context.insert(plan)

        plan.addTier()
        plan.addTier()
        plan.addTier()
        #expect(plan.tiers.map(\.order) == [0, 1, 2])
        #expect(plan.tiers.allSatisfy { $0.label == nil }, "a new tier reads by its position")
        let ids = plan.tiers.map(\.id)

        #expect(plan.relabelTier(ids[1], toDraft: "  Day two "))
        #expect(plan.tiers[1].label == "Day two")
        #expect(!plan.relabelTier(UUID(), toDraft: "X"), "a tier the plan no longer has writes nothing")

        // The sheet's reorder, as SwiftUI's move and the renumbering wrote it.
        var expected = plan.tiers
        expected.move(fromOffsets: IndexSet([2]), toOffset: 0)
        for index in expected.indices { expected[index].order = index }
        plan.moveTiers(fromOffsets: IndexSet([2]), toOffset: 0)
        #expect(plan.tiers == expected)
        #expect(plan.tiers.map(\.id) == [ids[2], ids[0], ids[1]])

        plan.setTier(ids[1], forKey: "lot|1", resolvedBy: nil, in: context)
        plan.setTier(ids[0], forKey: "lot|2", resolvedBy: nil, in: context)
        try context.save()
        plan.removeTier(ids[1])
        try context.save()
        #expect(plan.tiers.map(\.id) == [ids[2], ids[0]])
        #expect(plan.tiers.map(\.order) == [0, 1])
        let rows = Dictionary(uniqueKeysWithValues: (plan.targets ?? []).map { ($0.targetKey, $0) })
        #expect(rows.count == 2, "nothing is removed from the plan")
        #expect(rows["lot|1"]?.tierId == nil, "the removed tier's member drops to Unprioritized")
        #expect(rows["lot|2"]?.tierId == ids[0])
    }

    @MainActor
    @Test("A target's exclusion, note and tier mint one row under its derived id, and change that row after")
    func targetWrites() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let plan = ArchiveVisitPlan(name: "P")
        context.insert(plan)
        let tier = UUID()

        plan.setIncluded(false, forKey: "lot|9", resolvedBy: nil, in: context)
        plan.setNote(fromDraft: "  Ask first \n", forKey: "lot|9", resolvedBy: nil, in: context)
        plan.setTier(tier, forKey: "lot|9", resolvedBy: nil, in: context)
        try context.save()
        let row = try #require(plan.targets?.first)
        #expect(plan.targets?.count == 1, "one row per target, minted once")
        #expect(row.id == ArchiveVisitPlanWrites.derivedChildId(planId: plan.id, key: "lot|9"))
        #expect(!row.included)
        #expect(row.userNote == "Ask first")
        #expect(row.tierId == tier)

        plan.setNote(fromDraft: " ", forKey: "lot|9", resolvedBy: nil, in: context)
        #expect(row.userNote == nil)
        #expect(row.tierId == tier && !row.included, "a note's write leaves the tier and the exclusion")
        plan.setNote(fromDraft: "", forKey: "lot|10", resolvedBy: nil, in: context)
        #expect(plan.targets?.count == 2, "an empty note mints the row, as the editor's Save always has")
    }

    @MainActor
    @Test("A duplicate takes the kit's copy, each row's reserved state, and the blobs as stored")
    func duplicateCarriesWhatTheRecordsDoNot() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let plan = ArchiveVisitPlan(name: "Berlin blockade")
        plan.tiers = [ArchiveVisitTier(label: "First morning", order: 0)]
        context.insert(plan)
        #expect(plan.deliverableTogglesData == nil)
        plan.addSeeds([("frus1948v02", "d3")], includeSource: true, includeExternalRefs: false, in: context)
        plan.documents?.first?.stateData = Data([1, 2, 3])
        plan.setNote(fromDraft: "Box 4", forKey: "lot|64D199", resolvedBy: nil, in: context)
        plan.targets?.first?.stateData = Data([4])
        try context.save()

        let copy = plan.duplicate(in: context)
        try context.save()
        #expect(copy.name == "Berlin blockade copy")
        #expect(copy.tiersData == plan.tiersData)
        #expect(copy.deliverableTogglesData == nil, "the toggles' blob is copied as stored, never re-encoded")
        let seed = try #require(copy.documents?.first)
        #expect(seed.id == ArchiveVisitPlanWrites.derivedChildId(planId: copy.id, key: "frus1948v02/d3"))
        #expect(seed.stateData == Data([1, 2, 3]))
        #expect(seed.includeSource && !seed.includeExternalRefs)
        let state = try #require(copy.targets?.first)
        #expect(state.id == ArchiveVisitPlanWrites.derivedChildId(planId: copy.id, key: "lot|64D199"))
        #expect(state.stateData == Data([4]))
        #expect(state.userNote == "Box 4")
    }

    @MainActor
    @Test("The app's forms derive and sign what the kit's give over the plan's records")
    func appFormsAreTheKits() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let plan = ArchiveVisitPlan(name: "P", inquiryText: "The airlift.")
        plan.tiers = [ArchiveVisitTier(label: "Day one", order: 0)]
        context.insert(plan)
        plan.addSeeds([("v1", "d1"), ("v1", "d2")], includeSource: true, includeExternalRefs: true, in: context)
        plan.setTier(plan.tiers.first?.id, forKey: "lot|60D1", resolvedBy: nil, in: context)
        plan.setIncluded(false, forKey: "lot|99Z999", resolvedBy: nil, in: context)
        try context.save()

        let stub = AppFormsStub(sources: [
            .init(volumeId: "v1", documentId: "d1", repository: nil, recordGroup: "59", lotFile: "60 D 1",
                  seriesName: nil, rawText: "Department of State, Lot 60 D 1", citationEra: "lot_file"),
        ])
        let record = plan.record(documents: plan.documents ?? [], targets: plan.targets ?? [])
        let app = await ArchiveVisitDerivation.derive(plan: plan, indexedVolumeIds: ["v1"], dataSource: stub)
        let kit = await ArchiveVisitDerivation.derive(plan: record, indexedVolumeIds: ["v1"], dataSource: stub,
                                                      indexes: .bundled)
        #expect(app == kit)
        #expect(app.overlay.orphanKeys == ["lot|99Z999"])
        #expect(ArchiveVisitDerivation.inputSignature(plan: plan, indexedVolumeIds: ["v1", "v2"])
                == ArchiveVisitDerivation.inputSignature(plan: record, indexedVolumeIds: ["v1", "v2"]))
    }
}
