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

private let planId = UUID(uuidString: "6F1D3C2A-9B4E-4A7C-8D21-3E5F7A9B0C1D")!
private let created = Date(timeIntervalSince1970: 1_790_000_000)
private let now = Date(timeIntervalSince1970: 1_795_000_000)

private func seed(_ key: String, source: Bool = true, refs: Bool = true,
                  id: UUID? = nil) -> ArchiveVisitDocumentExport {
    ArchiveVisitDocumentExport(id: id ?? ArchiveVisitPlanWrites.derivedChildId(planId: planId, key: key),
                               documentKey: key, includeSource: source, includeExternalRefs: refs,
                               createdAt: created, lastModified: created)
}

private func target(_ key: String, tier: UUID? = nil, included: Bool = true, note: String? = nil,
                    id: UUID? = nil) -> ArchiveVisitTargetExport {
    ArchiveVisitTargetExport(id: id ?? ArchiveVisitPlanWrites.derivedChildId(planId: planId, key: key),
                             targetKey: key, tierId: tier, included: included, userNote: note,
                             createdAt: created, lastModified: created)
}

private func plan(name: String = "Berlin blockade", inquiry: String? = nil,
                  tiers: [ArchiveVisitTier] = [], documents: [ArchiveVisitDocumentExport] = [],
                  targets: [ArchiveVisitTargetExport] = []) -> ArchiveVisitPlanExport {
    ArchiveVisitPlanExport(id: planId, name: name, inquiryText: inquiry, projectIds: [],
                           tiers: tiers, deliverables: ArchiveVisitDeliverables(), documents: documents,
                           targets: targets, createdAt: created, lastModified: created)
}

// MARK: - ArchiveVisitDerivedIdTests

/// The id a plan's child row is minted under, held to the values the app's own code gives, so that a host on
/// Linux, where the hash is swift-crypto's, mints the rows the app mints.
///
/// The six ids were computed on the Mac by `v2`'s `ArchiveVisitPlan.derivedChildId(planId:key:)` (CryptoKit) at
/// `3b2d299f`, and again by Python's `hashlib` over the same bytes; a key with an en dash holds the UTF-8 of a
/// character outside ASCII to them, and a plan's id read from lower case derives as from upper, since a UUID is
/// written in upper case on every platform.
///
/// Version history:
///   1.0 — 2026-11-24: FRUS Explorer Light's S30b — the derived id moved into FRUSCoreKit
@Suite("Archive Visit derived ids — the app's on every platform")
struct ArchiveVisitDerivedIdTests {

    static let pinned: [(plan: String, key: String, id: String)] = [
        ("00000000-0000-0000-0000-000000000001", "class|611.51", "9AE440C6-81FC-8729-ABF1-8F85BDD2FB31"),
        ("AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", "lot|64D199", "63D5E602-B2B3-842C-ADD2-93896C4DDCEF"),
        ("AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", "frus1948v02/d3", "E6B732FD-DA61-8F24-AF90-B532F012A6C7"),
        ("6F1D3C2A-9B4E-4A7C-8D21-3E5F7A9B0C1D", "coll|Harry S. Truman Library|Papers of Dean Acheson",
         "D9B03584-9B49-8042-A97D-773C18D2D796"),
        ("6F1D3C2A-9B4E-4A7C-8D21-3E5F7A9B0C1D",
         "r|Source: Department of State, Central Files, 611.61/1–1559. Secret.",
         "AC4A1715-7F32-8381-A9F5-58478444700F"),
        ("6F1D3C2A-9B4E-4A7C-8D21-3E5F7A9B0C1D", "decimal|737.00/1-161", "44F5D613-6528-815D-B083-331ED7234644"),
    ]

    @Test("Each pinned plan and key derives the id the app's code derives")
    func pinnedIdsHold() throws {
        for entry in Self.pinned {
            let plan = try #require(UUID(uuidString: entry.plan))
            #expect(ArchiveVisitPlanWrites.derivedChildId(planId: plan, key: entry.key).uuidString == entry.id,
                    "\(entry.plan) | \(entry.key)")
        }
    }

    @Test("A plan's id read from lower case derives what it derives from upper case")
    func caseOfThePlanIdDoesNotMatter() throws {
        let lower = try #require(UUID(uuidString: "6f1d3c2a-9b4e-4a7c-8d21-3e5f7a9b0c1d"))
        #expect(lower.uuidString == "6F1D3C2A-9B4E-4A7C-8D21-3E5F7A9B0C1D")
        #expect(ArchiveVisitPlanWrites.derivedChildId(planId: lower, key: "decimal|737.00/1-161").uuidString
                == "44F5D613-6528-815D-B083-331ED7234644")
    }

    @Test("Every id is the deterministic custom form: version nibble 8, variant 10")
    func idsCarryTheirShape() throws {
        for entry in Self.pinned {
            let bytes = ArchiveVisitPlanWrites.derivedChildId(planId: try #require(UUID(uuidString: entry.plan)),
                                                              key: entry.key).uuid
            #expect(bytes.6 & 0xF0 == 0x80, "version nibble must be 8")
            #expect(bytes.8 & 0xC0 == 0x80, "variant bits must be 10xxxxxx")
        }
    }

    @Test("Every row a rule mints carries its derived id")
    func mintedRowsCarryTheirDerivedIds() {
        let seeds = ArchiveVisitPlanWrites.addingSeeds([("frus1948v02", "d3")], includeSource: true,
                                                       includeExternalRefs: true, to: [], planId: planId, now: now)
        #expect(seeds.inserted.map(\.id)
                == [ArchiveVisitPlanWrites.derivedChildId(planId: planId, key: "frus1948v02/d3")])
        let minted = ArchiveVisitPlanWrites.targetRow(forKey: "lot|64D199", resolvedBy: nil, mintIfMissing: true,
                                                      among: [], planId: planId, now: now)
        #expect(minted?.record.id == ArchiveVisitPlanWrites.derivedChildId(planId: planId, key: "lot|64D199"))
    }
}

// MARK: - ArchiveVisitPlanWritesTests

/// The plan's writes as rules over its records: a new plan's seeding, a rename, a duplicate, the delete's
/// cascade, an added seed, a re-seed and its topic, a target's tier, note and exclusion, and the tiers' add,
/// rename, reorder and removal — what the app's `ArchiveVisitPlanTests` and `ArchiveVisitPhase3Tests` pin over
/// SwiftData, here over values, as a host without SwiftData writes them.
///
/// Version history:
///   1.0 — 2026-11-24: FRUS Explorer Light's S30b — the plan's write rules moved into FRUSCoreKit
@Suite("Archive Visit plan writes — the rules over records")
struct ArchiveVisitPlanWritesTests {

    // MARK: Names

    @Test("A rename writes the trimmed draft, and an empty one writes nothing")
    func renameReadsItsDraft() {
        #expect(ArchiveVisitPlanWrites.name(fromDraft: "  Berlin blockade \n") == "Berlin blockade")
        #expect(ArchiveVisitPlanWrites.name(fromDraft: " \n\t ") == nil)
        #expect(ArchiveVisitPlanWrites.name(fromDraft: "") == nil)
        #expect(ArchiveVisitPlanWrites.displayName(of: "") == ArchiveVisitPlanWrites.untitledName)
        #expect(ArchiveVisitPlanWrites.displayName(of: "P") == "P")
        #expect(ArchiveVisitPlanWrites.untitledName == "Untitled Archives Visit")
    }

    // MARK: A new plan

    @Test("A plan made under a project belongs to it and copies its question; a global one has neither")
    func newPlanSeedsFromItsProject() {
        let project = UUID()
        let made = ArchiveVisitPlanWrites.newPlan(name: "Berlin", projectId: project,
                                                  researchQuestion: "  How did the airlift work?  ",
                                                  id: planId, now: now)
        #expect(made.id == planId)
        #expect(made.name == "Berlin")
        #expect(made.projectIds == [project])
        #expect(made.inquiryText == TripPacketTopicSentence.written("  How did the airlift work?  "))
        #expect(made.tiers.isEmpty && made.documents.isEmpty && made.targets.isEmpty)
        #expect(made.deliverables == ArchiveVisitDeliverables())
        #expect(made.createdAt == now && made.lastModified == now)

        let global = ArchiveVisitPlanWrites.newPlan(name: "", projectId: nil, researchQuestion: nil)
        #expect(global.projectIds.isEmpty)
        #expect(global.inquiryText == nil)
        let blank = ArchiveVisitPlanWrites.newPlan(name: "", projectId: project, researchQuestion: " \n ")
        #expect(blank.inquiryText == nil, "a blank question copies nothing, and the export prints the placeholder")
        #expect(blank.projectIds == [project])
    }

    // MARK: Duplication

    @Test("A duplicate takes the copy grammar, keeps tier ids, and re-derives every child id")
    func duplicateRederivesChildIds() {
        let tier = ArchiveVisitTier(label: "First morning", order: 0)
        var toggles = ArchiveVisitDeliverables()
        toggles.includeCitationCrib = true
        var original = plan(inquiry: "The airlift's arithmetic.", tiers: [tier],
                            documents: [seed("frus1948v02/d3", refs: false)],
                            targets: [target("lot|64D199", tier: tier.id, note: "Ask about the divided series.")])
        original.projectIds = [UUID()]
        original.deliverables = toggles
        let copyId = UUID()
        let copy = ArchiveVisitPlanWrites.duplicate(of: original, id: copyId, now: now)

        #expect(copy.id == copyId)
        #expect(copy.name == "Berlin blockade copy")
        #expect(copy.inquiryText == original.inquiryText)
        #expect(copy.projectIds == original.projectIds)
        #expect(copy.deliverables.includeCitationCrib)
        #expect(copy.tiers == [tier], "tier ids are not re-minted: the copied assignments point at them")
        #expect(copy.documents.map(\.id)
                == [ArchiveVisitPlanWrites.derivedChildId(planId: copyId, key: "frus1948v02/d3")])
        #expect(copy.documents.first?.includeExternalRefs == false)
        #expect(copy.targets.map(\.id)
                == [ArchiveVisitPlanWrites.derivedChildId(planId: copyId, key: "lot|64D199")])
        #expect(copy.targets.first?.tierId == tier.id)
        #expect(copy.targets.first?.userNote == "Ask about the divided series.")
        #expect(copy.targets.first?.included == true)
        #expect(copy.documents.allSatisfy { $0.createdAt == now } && copy.targets.allSatisfy { $0.createdAt == now })
        #expect(ArchiveVisitPlanWrites.duplicate(of: plan(name: "")).name
                == "\(ArchiveVisitPlanWrites.untitledName) copy")
    }

    // MARK: Deletion

    @Test("The delete's cascade names the plan, every seed and every stored target, orphans included")
    func deletionCascades() {
        let doomed = plan(documents: [seed("v1/d1"), seed("v1/d2")],
                          targets: [target("lot|60D1"), target("decimal|737.00/1-161")])
        let deletion = ArchiveVisitPlanWrites.deletion(of: doomed)
        #expect(deletion == ArchiveVisitPlanWrites.Deletion(
            planId: planId, documentIds: doomed.documents.map(\.id), targetIds: doomed.targets.map(\.id)))
        #expect(ArchiveVisitPlanWrites.deletion(of: plan()).documentIds.isEmpty)
    }

    // MARK: Seeds

    @Test("Adding seeds unions flags, never switches one off, and mints a new document once")
    func addingSeedsUnions() {
        let first = ArchiveVisitPlanWrites.addingSeeds([("v1", "d1")], includeSource: true, includeExternalRefs: false,
                                                       to: [], planId: planId, now: now)
        #expect(first.mintedCount == 1)
        #expect(first.inserted == [ArchiveVisitDocumentExport(
            id: ArchiveVisitPlanWrites.derivedChildId(planId: planId, key: "v1/d1"), documentKey: "v1/d1",
            includeSource: true, includeExternalRefs: false, createdAt: now, lastModified: now)])
        #expect(first.updated.isEmpty)

        // A second surface adds the OTHER claim: union, not overwrite.
        let stored = first.inserted
        let again = ArchiveVisitPlanWrites.addingSeeds([("v1", "d1")], includeSource: false,
                                                       includeExternalRefs: true, to: stored, planId: planId)
        #expect(again.inserted.isEmpty, "an existing seed is upserted, never duplicated")
        #expect(again.updated.count == 1)
        #expect(again.updated.first?.index == 0)
        #expect(again.updated.first?.record.includeSource == true,
                "adding references must not switch off the source another surface added")
        #expect(again.updated.first?.record.includeExternalRefs == true)

        // A no-claims add writes nothing.
        let none = ArchiveVisitPlanWrites.addingSeeds([("v1", "d2")], includeSource: false,
                                                      includeExternalRefs: false, to: stored, planId: planId)
        #expect(none == ArchiveVisitPlanWrites.SeedAddition(inserted: [], updated: []))
    }

    @Test("A seed already on gets the write the app always gave it, and a repeated document is one write")
    func addingSeedsListsEveryStoredSeedNamed() {
        let stored = [seed("v1/d1"), seed("v1/d2", source: true, refs: false)]
        let addition = ArchiveVisitPlanWrites.addingSeeds([("v1", "d1"), ("v1", "d3"), ("v1", "d1"), ("v1", "d3")],
                                                          includeSource: true, includeExternalRefs: false,
                                                          to: stored, planId: planId, now: now)
        #expect(addition.updated == [ArchiveVisitPlanWrites.StoredRow(index: 0, record: stored[0])],
                "d1 was on already: listed once, unchanged")
        #expect(addition.inserted.map(\.documentKey) == ["v1/d3"])
        #expect(addition.inserted.first?.includeExternalRefs == false)
    }

    @Test("Two stored copies of one seed: the first of the key is the one written")
    func addingSeedsWritesTheFirstCopy() {
        let copy = seed("v1/d1", refs: false)
        let addition = ArchiveVisitPlanWrites.addingSeeds([("v1", "d1")], includeSource: false, includeExternalRefs: true,
                                                          to: [seed("v1/d9"), copy, copy], planId: planId)
        #expect(addition.updated.map(\.index) == [1])
        #expect(addition.updated.first?.record.includeExternalRefs == true)
    }

    // MARK: Re-seed from Project

    @Test("The topic's re-seed fills an empty topic, leaves one that reads the question, and asks otherwise")
    func topicReseedDecides() {
        #expect(ArchiveVisitPlanWrites.topicReseed(inquiryText: nil, question: nil) == .unchanged)
        #expect(ArchiveVisitPlanWrites.topicReseed(inquiryText: "Mine", question: " \n ") == .unchanged)
        #expect(ArchiveVisitPlanWrites.topicReseed(inquiryText: nil, question: "Why?") == .filled(question: "Why?"))
        #expect(ArchiveVisitPlanWrites.topicReseed(inquiryText: "  ", question: "Why?") == .filled(question: "Why?"))
        #expect(ArchiveVisitPlanWrites.topicReseed(inquiryText: "Why?", question: "Why?") == .unchanged)
        #expect(ArchiveVisitPlanWrites.topicReseed(inquiryText: "Mine", question: "Why?")
                == .needsConfirmation(question: "Why?", current: "Mine"))
    }

    @Test("Re-seed adds the project's documents with both halves on, and offers its question")
    func reseedAddsAndOffers() {
        let current = plan(inquiry: nil, documents: [seed("v1/d1", source: true, refs: false)])
        let reseed = ArchiveVisitPlanWrites.reseed(
            current, fromProject: .init(researchQuestion: "Why the airlift?",
                                        seedKeys: ["v1/d1", "v1/d2", "not a key"]),
            now: now)
        #expect(reseed.seeds.inserted.map(\.documentKey) == ["v1/d2"])
        #expect(reseed.seeds.inserted.first.map { $0.includeSource && $0.includeExternalRefs } == true)
        #expect(reseed.seeds.updated.map(\.record.includeExternalRefs) == [true],
                "a seed already in the plan gains the half it lacked; nothing is switched off")
        #expect(reseed.topic == .filled(question: "Why the airlift?"))

        let gone = ArchiveVisitPlanWrites.reseed(current, fromProject: nil)
        #expect(gone == ArchiveVisitPlanWrites.Reseed(seeds: .init(inserted: [], updated: []), topic: .unchanged),
                "a project that no longer exists changes nothing")
    }

    // MARK: A target's stored state

    @Test("A target's row is the one stored under the key the overlay resolves, else minted under its own key")
    func targetRowResolvesThroughTheOverlay() {
        let respelled = target("r|No . 1259.]", tier: UUID())
        var overlay = ArchiveVisitOverlay()
        overlay.storedKeys["r|No. 1259.]"] = "r|No . 1259.]"
        let stored = ArchiveVisitPlanWrites.targetRow(forKey: "r|No. 1259.]", resolvedBy: overlay,
                                                      mintIfMissing: true, among: [target("lot|1"), respelled],
                                                      planId: planId)
        #expect(stored == .stored(.init(index: 1, record: respelled)),
                "a row minted under a key the re-index re-spelled is found, not minted again")
        #expect(ArchiveVisitPlanWrites.targetRow(forKey: "r|No. 1259.]", resolvedBy: nil, mintIfMissing: false,
                                                 among: [respelled], planId: planId) == nil)
        let minted = ArchiveVisitPlanWrites.targetRow(forKey: "lot|64D199", resolvedBy: overlay, mintIfMissing: true,
                                                      among: [respelled], planId: planId, now: now)
        #expect(minted == .minted(ArchiveVisitTargetExport(
            id: ArchiveVisitPlanWrites.derivedChildId(planId: planId, key: "lot|64D199"), targetKey: "lot|64D199",
            tierId: nil, included: true, userNote: nil, createdAt: now, lastModified: now)))
    }

    @Test("A tier, an exclusion and a note each mint the row, or change the stored one")
    func settersMintOrChange() {
        let tier = UUID()
        let stored = [target("lot|1", note: "Box 4")]
        #expect(ArchiveVisitPlanWrites.settingTier(tier, forKey: "lot|1", resolvedBy: nil, among: stored,
                                                   planId: planId)
                == .stored(.init(index: 0, record: target("lot|1", tier: tier, note: "Box 4"))))
        let excluded = ArchiveVisitPlanWrites.settingIncluded(false, forKey: "lot|2", resolvedBy: nil, among: stored,
                                                              planId: planId, now: now)
        #expect(excluded.record.included == false)
        #expect(excluded.record.targetKey == "lot|2")
        if case .minted = excluded {} else { Issue.record("excluding a target with no row mints one: \(excluded)") }
        #expect(ArchiveVisitPlanWrites.settingTier(nil, forKey: "lot|1", resolvedBy: nil, among: stored,
                                                   planId: planId).record.tierId == nil,
                "clearing back to Unprioritized keeps the row")
        #expect(ArchiveVisitPlanWrites.settingNote(fromDraft: "  Ask first \n", forKey: "lot|1", resolvedBy: nil,
                                                   among: stored, planId: planId).record.userNote == "Ask first")
        let emptyNote = ArchiveVisitPlanWrites.settingNote(fromDraft: " ", forKey: "lot|3", resolvedBy: nil,
                                                           among: stored, planId: planId, now: now)
        #expect(emptyNote == .minted(ArchiveVisitTargetExport(
            id: ArchiveVisitPlanWrites.derivedChildId(planId: planId, key: "lot|3"), targetKey: "lot|3", tierId: nil,
            included: true, userNote: nil, createdAt: now, lastModified: now)),
            "an empty note mints the row with no note, as the editor's Save always has")
        #expect(ArchiveVisitPlanWrites.note(fromDraft: "\n") == nil)
    }

    @Test("Remove names the stored row by its own key, and nothing when none is stored")
    func removingStateFindsTheStoredRow() {
        let stored = [target("lot|1"), target("r|Old note")]
        #expect(ArchiveVisitPlanWrites.removingState(forKey: "r|Old note", resolvedBy: nil, among: stored)
                == ArchiveVisitPlanWrites.StoredRow(index: 1, record: stored[1]))
        #expect(ArchiveVisitPlanWrites.removingState(forKey: "lot|9", resolvedBy: nil, among: stored) == nil)
    }

    // MARK: Tiers

    @Test("A new tier is unlabeled and ordered after the tiers before it")
    func addingTierAppends() {
        let first = ArchiveVisitTier(label: "Day one", order: 0)
        let id = UUID()
        #expect(ArchiveVisitPlanWrites.addingTier(to: [first], id: id)
                == [first, ArchiveVisitTier(id: id, label: nil, order: 1)])
        #expect(ArchiveVisitPlanWrites.addingTier(to: [], id: id) == [ArchiveVisitTier(id: id, label: nil, order: 0)])
    }

    @Test("A tier is relabeled from a trimmed draft, an empty draft clears it, and an unknown tier writes nothing")
    func relabelingTier() {
        let tier = ArchiveVisitTier(label: "Day one", order: 0)
        #expect(ArchiveVisitPlanWrites.relabelingTier(tier.id, toDraft: "  If time allows ", in: [tier])?.first?.label
                == "If time allows")
        #expect(ArchiveVisitPlanWrites.relabelingTier(tier.id, toDraft: "  ", in: [tier])?.first?.label == nil)
        #expect(ArchiveVisitPlanWrites.relabelingTier(UUID(), toDraft: "X", in: [tier]) == nil)
    }

    @Test("Moving tiers lands them before the destination, in their order, and numbers the list again")
    func movingTiersRenumbers() {
        // SwiftUI's own example for `move(fromOffsets:toOffset:)`.
        #expect(ArchiveVisitPlanWrites.moving(["one", "two", "three", "four", "five"],
                                              fromOffsets: IndexSet([1, 3]), toOffset: 0)
                == ["two", "four", "one", "three", "five"])
        #expect(ArchiveVisitPlanWrites.moving(["a", "b", "c", "d"], fromOffsets: IndexSet([0]), toOffset: 3)
                == ["b", "c", "a", "d"])
        #expect(ArchiveVisitPlanWrites.moving(["a", "b", "c"], fromOffsets: IndexSet([0]), toOffset: 3)
                == ["b", "c", "a"])
        let tiers = (0..<3).map { ArchiveVisitTier(label: "T\($0)", order: $0) }
        let moved = ArchiveVisitPlanWrites.movingTiers(fromOffsets: IndexSet([2]), toOffset: 0, in: tiers)
        #expect(moved.map(\.label) == ["T2", "T0", "T1"])
        #expect(moved.map(\.order) == [0, 1, 2])
        #expect(moved.map(\.id) == [tiers[2].id, tiers[0].id, tiers[1].id])
    }

    @Test("Removing a tier numbers the rest again and clears its members to Unprioritized")
    func removingTierClearsMembers() {
        let first = ArchiveVisitTier(label: "Day one", order: 0)
        let second = ArchiveVisitTier(label: "Day two", order: 1)
        let third = ArchiveVisitTier(label: nil, order: 2)
        let targets = [target("lot|1", tier: second.id), target("lot|2", tier: first.id),
                       target("lot|3", tier: second.id, note: "Kept")]
        let removal = ArchiveVisitPlanWrites.removingTier(second.id, from: [first, second, third], targets: targets)
        #expect(removal.tiers == [first, ArchiveVisitTier(id: third.id, label: nil, order: 1)])
        #expect(removal.clearedTargets == [.init(index: 0, record: target("lot|1")),
                                           .init(index: 2, record: target("lot|3", note: "Kept"))])
    }

    @Test("A plan's tiers are kept by order, equal orders as they came")
    func storedOrderIsStable() {
        let a = ArchiveVisitTier(label: "A", order: 1), b = ArchiveVisitTier(label: "B", order: 0)
        let c = ArchiveVisitTier(label: "C", order: 1)
        #expect(ArchiveVisitPlanWrites.storedOrder([a, b, c]) == [b, a, c])
    }
}

// MARK: - DuplicateRecordOrderTests

/// The order a record is kept over its duplicate by, which a target's shown row reads.
///
/// Version history:
///   1.0 — 2026-11-24: FRUS Explorer Light's S30b — out of the app's `DuplicateRecordCleanup`
@Suite("Duplicate record order — the earlier, then the lower id")
struct DuplicateRecordOrderTests {

    @Test("The earlier creation is kept, a missing date last, and a tie goes to the lower id")
    func earlierThenLowerId() {
        let low = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let high = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let early = Date(timeIntervalSince1970: 1), late = Date(timeIntervalSince1970: 2)
        #expect(DuplicateRecordOrder.isKept((early, high), over: (late, low)))
        #expect(!DuplicateRecordOrder.isKept((late, low), over: (early, high)))
        #expect(DuplicateRecordOrder.isKept((late, high), over: (nil, low)), "a missing date sorts last")
        #expect(DuplicateRecordOrder.isKept((early, low), over: (early, high)))
        #expect(!DuplicateRecordOrder.isKept((early, high), over: (early, high)), "a record is not kept over itself")
    }
}
