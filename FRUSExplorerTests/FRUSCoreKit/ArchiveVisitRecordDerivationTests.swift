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
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - Fixtures

/// A stub data source for the derivation over records — the seam `ArchiveVisitPhase3Tests` drives through
/// the app's rows, redeclared here because that suite's stub is private to it.
@MainActor
private struct RecordDerivationStub: TripPacketReferenceDataSource {
    var sources: [CollectionGeneratedBlocks.SourceRecord] = []
    var citations: [String: [ExternalCitation]] = [:]

    func citation(volumeId: String, documentId: String, printedNumber: String?) -> String {
        "\(volumeId)/\(documentId)"
    }
    func dateMetadata(for documents: [(volumeId: String, documentId: String)])
        async -> [String: DocumentDateMetadata] { [:] }
    func documentNumbers(for documents: [(volumeId: String, documentId: String)])
        async -> [String: String] { [:] }
    func documentSources(for documents: [(volumeId: String, documentId: String)])
        async -> [CollectionGeneratedBlocks.SourceRecord] {
        // Honor the request list, so a stub that ignored its argument cannot pass the seam's test.
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

private func rawRecord(_ volume: String, _ document: String, note: String) -> CollectionGeneratedBlocks.SourceRecord {
    .init(volumeId: volume, documentId: document, repository: nil, recordGroup: nil, lotFile: nil,
          seriesName: nil, rawText: note, citationEra: nil)
}

private func lotCitation(lot: String, norm: String) -> ExternalCitation {
    ExternalCitation(anchor: "lotFile", repository: "Department of State", collection: nil,
                     lotFile: lot, lotFileNorm: norm, fileId: nil, inherited: false,
                     rawText: "Not printed. (Lot \(lot))", noteOrdinal: 0)
}

private let planId = UUID(uuidString: "0B1C2D3E-4F50-4617-8293-A4B5C6D7E8F9")!
private let day = Date(timeIntervalSince1970: 1_780_000_000)

private func seed(_ key: String, source: Bool = true, refs: Bool = true) -> ArchiveVisitDocumentExport {
    ArchiveVisitDocumentExport(id: ArchiveVisitPlanWrites.derivedChildId(planId: planId, key: key), documentKey: key,
                               includeSource: source, includeExternalRefs: refs, createdAt: day, lastModified: day)
}

private func stored(_ key: String, tier: UUID? = nil, included: Bool = true, note: String? = nil,
                    created: Date? = day, id: UUID? = nil) -> ArchiveVisitTargetExport {
    ArchiveVisitTargetExport(id: id ?? ArchiveVisitPlanWrites.derivedChildId(planId: planId, key: key),
                             targetKey: key, tierId: tier, included: included, userNote: note,
                             createdAt: created, lastModified: created)
}

private func plan(inquiry: String? = nil, tiers: [ArchiveVisitTier] = [],
                  documents: [ArchiveVisitDocumentExport], targets: [ArchiveVisitTargetExport] = [])
    -> ArchiveVisitPlanExport {
    ArchiveVisitPlanExport(id: planId, name: "P", inquiryText: inquiry, projectIds: [], tiers: tiers,
                           deliverables: ArchiveVisitDeliverables(), documents: documents, targets: targets,
                           createdAt: day, lastModified: day)
}

// MARK: - ArchiveVisitRecordDerivationTests

/// The plan → packet derivation over the research export's records (Phase 3, as `ArchiveVisitDerivationTests`
/// pins it over the app's rows): the §5 two-list projection, the overlay's join with its orphans and superseded
/// rows, the topic, the seed coverage and the input signature — what a host without SwiftData derives, with no
/// bundled index.
///
/// Version history:
///   1.0 — 2026-11-24: FRUS Explorer Light's S30b — the derivation moved into FRUSCoreKit over records
@Suite("Archive Visit derivation — over the plan's records")
@MainActor
struct ArchiveVisitRecordDerivationTests {

    private func derive(_ plan: ArchiveVisitPlanExport, indexed: Set<String> = ["v1"],
                        stub: RecordDerivationStub) async -> ArchiveVisitDerivation.Derived {
        await ArchiveVisitDerivation.derive(plan: plan, indexedVolumeIds: indexed, dataSource: stub,
                                            indexes: TripPacketIndexes())
    }

    /// **The §5 seam.** A document's contribution flags decide which CHANNEL it feeds.
    @Test("Contribution flags project into the two channels")
    func flagsProjectIntoChannels() async {
        let stub = RecordDerivationStub(
            sources: [lotRecord("v1", "dA", lot: "60 D 1"), lotRecord("v1", "dB", lot: "60 D 1"),
                      lotRecord("v1", "dC", lot: "60 D 1")],
            citations: ["v1/dA": [lotCitation(lot: "60 D 2", norm: "60D2")],
                        "v1/dB": [lotCitation(lot: "60 D 2", norm: "60D2")],
                        "v1/dC": [lotCitation(lot: "60 D 2", norm: "60D2")]])
        let derived = await derive(plan(documents: [seed("v1/dA", refs: false), seed("v1/dB", source: false),
                                                    seed("v1/dC")]), stub: stub)
        #expect(derived.model.targets.first { $0.key == "lot|60D1" }?.drawnFrom.map(\.documentId).sorted()
                == ["dA", "dC"], "the drawn-from channel holds exactly the includeSource documents")
        #expect(derived.model.targets.first { $0.key == "lot|60D2" }?.pointedAt.map(\.documentId).sorted()
                == ["dB", "dC"], "the pointed-at channel holds exactly the includeExternalRefs documents")
        #expect(derived.model.referenceCoverage.documentsScanned == 2,
                "refs are scanned over the refs list only — dA was never scanned")
    }

    @Test("The overlay joins stored state, and a key nothing derives is an orphan, kept with its state")
    func overlayJoinsAndKeepsOrphans() async {
        let tier = ArchiveVisitTier(label: "Day one", order: 0)
        let derived = await derive(
            plan(tiers: [tier], documents: [seed("v1/d1", refs: false)],
                 targets: [stored("lot|60D1", tier: tier.id, note: "Ask first"),
                           stored("lot|60D1X", included: false),
                           stored("lot|99Z999", tier: tier.id, note: "Kept")]),
            stub: RecordDerivationStub(sources: [lotRecord("v1", "d1", lot: "60 D 1")]))
        #expect(derived.overlay.tiers == [tier])
        #expect(derived.overlay.tierAssignments["lot|60D1"] == tier.id)
        #expect(derived.overlay.notes["lot|60D1"] == "Ask first")
        #expect(derived.overlay.excludedKeys.contains("lot|60D1X"))
        #expect(derived.overlay.storedKeyCount == 3)
        #expect(derived.overlay.orphanKeys == ["lot|60D1X", "lot|99Z999"], "in key order, never deleted")
        #expect(derived.overlay.tierAssignments["lot|99Z999"] == tier.id && derived.overlay.notes["lot|99Z999"] == "Kept",
                "an orphan keeps its tier and note")
    }

    /// FRUS Explorer Light's import fixture stores a target under `decimal|737.00/1-161`, a key of none of the
    /// builder's four forms: it derives as an orphan, its exclusion kept, beside a lot that joins.
    @Test("An imported plan's key of no form the builder mints is an orphan, beside a stored lot that joins")
    func importedPlanDerivesAsItsExportSays() async {
        let first = ArchiveVisitTier(label: "First morning", order: 0)
        let imported = ArchiveVisitPlanExport(
            id: planId, name: "College Park", inquiryText: "The Zapata files", projectIds: [UUID()],
            tiers: [first, ArchiveVisitTier(order: 1)],
            deliverables: ArchiveVisitDeliverables(includeLinks: false, includeCitationCrib: true),
            documents: [ArchiveVisitDocumentExport(id: UUID(), documentKey: "frus1961-63v06/d3", includeSource: true,
                                                   includeExternalRefs: false),
                        ArchiveVisitDocumentExport(id: UUID(), documentKey: "frus1961-63v06/d4", includeSource: false,
                                                   includeExternalRefs: true)],
            targets: [ArchiveVisitTargetExport(id: UUID(), targetKey: "lot|61D21", tierId: first.id, included: true,
                                               userNote: "Box 4"),
                      ArchiveVisitTargetExport(id: UUID(), targetKey: "decimal|737.00/1-161", included: false)])
        let derived = await derive(imported, indexed: ["frus1961-63v06"], stub: RecordDerivationStub(
            sources: [lotRecord("frus1961-63v06", "d3", lot: "61 D 21")]))
        #expect(derived.model.targets.map(\.key) == ["lot|61D21"])
        #expect(derived.overlay.tierAssignments["lot|61D21"] == first.id)
        #expect(derived.overlay.notes["lot|61D21"] == "Box 4")
        #expect(derived.overlay.orphanKeys == ["decimal|737.00/1-161"])
        #expect(derived.overlay.excludedKeys == ["decimal|737.00/1-161"])
        #expect(derived.model.topicSentence.forExport == "The Zapata files")
        #expect(derived.seededDocumentCount == 2 && derived.indexedDocumentCount == 2)
    }

    @Test("A re-spelled key answers for its target under the target's key, and a write finds it there")
    func respelledKeyJoins() async {
        let note = "No. 1259.]"
        let derived = await derive(
            plan(documents: [seed("v1/d1", refs: false)],
                 targets: [stored("r|No . 1259.]", note: "Minted on v58")]),
            stub: RecordDerivationStub(sources: [rawRecord("v1", "d1", note: note)]))
        let key = try? #require(derived.model.targets.first?.key)
        #expect(key == "r|\(note)")
        #expect(derived.overlay.orphanKeys.isEmpty)
        #expect(derived.overlay.notes["r|\(note)"] == "Minted on v58")
        #expect(derived.overlay.storedKeys == ["r|\(note)": "r|No . 1259.]"])
        let row = ArchiveVisitPlanWrites.targetRow(forKey: "r|\(note)", resolvedBy: derived.overlay,
                                                   mintIfMissing: true,
                                                   among: [stored("r|No . 1259.]", note: "Minted on v58")],
                                                   planId: planId)
        #expect(row?.record.targetKey == "r|No . 1259.]", "the write lands on the row minted before the re-index")
    }

    @Test("A target several rows answer for shows its own key's row, else the first created, and lists the rest")
    func severalRowsShowOne() async {
        let note = "No. 1259.]"
        let stub = RecordDerivationStub(sources: [rawRecord("v1", "d1", note: note)])
        let own = stored("r|\(note)", included: true, note: "Own", created: day.addingTimeInterval(60))
        let respelled = stored("r|No . 1259.]", included: false, note: "Older", created: day)
        let both = await derive(plan(documents: [seed("v1/d1", refs: false)], targets: [respelled, own]),
                                stub: stub)
        #expect(both.overlay.notes["r|\(note)"] == "Own", "the target's own key's row is shown")
        #expect(both.overlay.superseded["r|No . 1259.]"]
                == ArchiveVisitOverlay.Superseded(targetKey: "r|\(note)", excluded: true))
        #expect(both.overlay.notes["r|No . 1259.]"] == "Older", "a superseded row keeps its note under its own key")
        #expect(!both.overlay.excludedKeys.contains("r|\(note)"), "its exclusion is not applied to the target")

        let later = stored("r|No .1259.]", note: "Later", created: day.addingTimeInterval(120))
        let respelledOnly = await derive(plan(documents: [seed("v1/d1", refs: false)], targets: [later, respelled]),
                                         stub: stub)
        #expect(respelledOnly.overlay.storedKeys["r|\(note)"] == "r|No . 1259.]", "the first created is shown")
        #expect(respelledOnly.overlay.superseded.keys.sorted() == ["r|No .1259.]"])
    }

    @Test("The overlay alone, over a model already derived, is the derivation's")
    func overlayOverAModelIsTheDerivations() async {
        let current = plan(documents: [seed("v1/d1", refs: false)],
                           targets: [stored("lot|60D1", note: "Ask"), stored("lot|1Z1")])
        let derived = await derive(current, stub: RecordDerivationStub(sources: [lotRecord("v1", "d1", lot: "60 D 1")]))
        #expect(ArchiveVisitDerivation.overlay(for: current, over: derived.model) == derived.overlay)
    }

    @Test("The plan's inquiry text becomes the edited topic sentence, and a blank one leaves the placeholder")
    func inquiryTextBecomesTheTopic() async {
        let written = await derive(plan(inquiry: "The airlift's supply arithmetic.", documents: [seed("v1/d1")]),
                                   indexed: [], stub: RecordDerivationStub())
        #expect(written.model.topicSentence.forExport == "The airlift's supply arithmetic.")
        let blank = await derive(plan(inquiry: " \n ", documents: [seed("v1/d1")]), indexed: [],
                                 stub: RecordDerivationStub())
        #expect(blank.model.topicSentence.forExport == TripPacketTopicSentence.placeholder)
    }

    @Test("Seed coverage counts rows by indexed volume")
    func seedCoverageCountsByVolume() async {
        let derived = await derive(plan(documents: [seed("v1/d1"), seed("v2/d1"), seed("v2/d2")]), indexed: ["v2"],
                                   stub: RecordDerivationStub())
        #expect(derived.seededDocumentCount == 3)
        #expect(derived.indexedDocumentCount == 2, "coverage is by VOLUME membership — the WorkingCorpusResolver rule")
    }

    @Test("documentTuple parses composite keys and refuses malformed ones; a seed's volume is its key's first part")
    func keysParse() {
        let tuple = ArchiveVisitDerivation.documentTuple(fromKey: "frus1948v02/d3")
        #expect(tuple?.volumeId == "frus1948v02" && tuple?.documentId == "d3")
        #expect(ArchiveVisitDerivation.documentTuple(fromKey: "nokey") == nil)
        #expect(ArchiveVisitDerivation.documentTuple(fromKey: "/d3") == nil)
        #expect(ArchiveVisitDerivation.documentTuple(fromKey: "v1/") == nil)
        #expect(ArchiveVisitDerivation.volumeId(ofSeedKey: "frus1948v02/d3") == "frus1948v02")
    }

    @Test("The input signature counts the rows the derivation reads, and the seeds' indexed volumes alone")
    func inputSignatureOverRecords() {
        let tier = ArchiveVisitTier(label: "T", order: 0)
        let current = plan(inquiry: "Q", tiers: [tier], documents: [seed("v1/d1"), seed("v1/d1"), seed("v2/d1")],
                           targets: [stored("lot|1", tier: tier.id)])
        let signature = ArchiveVisitDerivation.inputSignature(plan: current, indexedVolumeIds: ["v1", "v9"])
        #expect(signature.seeds == [.init(documentKey: "v1/d1", includeSource: true, includeExternalRefs: true): 2,
                                    .init(documentKey: "v2/d1", includeSource: true, includeExternalRefs: true): 1],
                "two rows of one seed are counted, not merged")
        #expect(signature.indexedSeedVolumes == ["v1"], "an indexed volume no seed is in is not read")
        #expect(signature.inquiryText == "Q" && signature.tiers == [tier])
        #expect(signature.targets.count == 1)

        var renamed = current
        renamed.name = "Another name"
        #expect(ArchiveVisitDerivation.inputSignature(plan: renamed, indexedVolumeIds: ["v1"])
                == ArchiveVisitDerivation.inputSignature(plan: current, indexedVolumeIds: ["v1"]),
                "the derivation never reads the name")
        var flagged = current
        flagged.documents[2].includeExternalRefs = false
        #expect(ArchiveVisitDerivation.inputSignature(plan: flagged, indexedVolumeIds: ["v1"])
                != ArchiveVisitDerivation.inputSignature(plan: current, indexedVolumeIds: ["v1"]))
        var noted = current
        noted.targets[0].userNote = "N"
        #expect(ArchiveVisitDerivation.inputSignature(plan: noted, indexedVolumeIds: ["v1"])
                != ArchiveVisitDerivation.inputSignature(plan: current, indexedVolumeIds: ["v1"]))
    }
}
