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

    func citation(volumeId: String, documentId: String, printedNumber: String?) -> String {
        "\(volumeId)/\(documentId)"
    }
    func dateMetadata(for documents: [(volumeId: String, documentId: String)])
        async -> [String: DocumentDateMetadata] { [:] }
    func documentNumbers(for documents: [(volumeId: String, documentId: String)])
        async -> [String: String] { [:] }
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

// MARK: - ArchiveVisitKeyStabilityTests (#1421 review)

/// A plan made before the v59 re-index still finds its targets after it (#1421 review).
///
/// `r|` and `coll|` target keys carry the stored note text, and v59 removed spaces from that text:
/// measured over the corpus, it re-spelled the key of 5,243 source notes and 6 footnote citations.
/// Each fixture below is one of those measured notes, given as the two SOURCE RECORDS the index
/// stores before and after — the stored row's key is minted from the v58 record by the builder's
/// own `targetKey(for:category:)`, and the plan derives from the v59 record, so neither key is typed
/// by hand. One fixture per way a key moves: an `r|` key, a `coll|` series, a foreign-archive
/// series cut at 80 characters, and a footnote citation's collection. The subject-numeric note is
/// the control the other way: its target really changed (`r|…` to `class|…`), and it must stay an
/// orphan rather than lend its tier to a unit it never named.
///
/// Version history:
///   1.0 — #1421 review: initial implementation
@Suite("Archive Visit keys across the v59 re-index (#1421 review)")
struct ArchiveVisitKeyStabilityTests {

    /// One source note as the index stores it before (v58) and after (v59) the re-index.
    struct Note {
        let document: String
        let v58: CollectionGeneratedBlocks.SourceRecord
        let v59: CollectionGeneratedBlocks.SourceRecord
        /// Whether the plan must still find the row minted under the v58 key.
        let joins: Bool
    }

    private static func record(_ document: String, raw: String, era: String,
                               repository: String? = nil,
                               series: String? = nil) -> CollectionGeneratedBlocks.SourceRecord {
        let parts = document.split(separator: "/").map(String.init)
        return .init(volumeId: parts[0], documentId: parts[1], repository: repository,
                     recordGroup: nil, lotFile: nil, seriesName: series, rawText: raw,
                     citationEra: era)
    }

    /// `frus1964-68v11` d1's note, as the parser hands it to the foreign-archive row.
    private static let seaborgV58 = "Glenn T. Seaborg , Journal of Glenn T. Seaborg , Chairman, U.S. Atomic "
        + "Energy Commission, 1961-1971 , Vol. 7, pp. 187-188."
    private static let seaborgV59 = "Glenn T. Seaborg, Journal of Glenn T. Seaborg, Chairman, U.S. Atomic "
        + "Energy Commission, 1961-1971, Vol. 7, pp. 187-188."

    /// The measured notes, one per way a key moves, and the control that must not join.
    static let notes: [Note] = [
        // `r|` — an unparsed pre-1906 serial.
        Note(document: "frus1866p1/d153",
             v58: record("frus1866p1/d153", raw: "No . 1259.]", era: "unrecognized"),
             v59: record("frus1866p1/d153", raw: "No. 1259.]", era: "unrecognized"),
             joins: true),
        // `coll|` — a named file series.
        Note(document: "frus1918Supp01v01/d119",
             v58: record("frus1918Supp01v01/d119", raw: "President Wilson ’s Files",
                         era: "named_series", series: "President Wilson ’s Files"),
             v59: record("frus1918Supp01v01/d119", raw: "President Wilson’s Files",
                         era: "named_series", series: "President Wilson’s Files"),
             joins: true),
        // `coll||<80 characters>` — a foreign-archive series, cut after the spaces went.
        Note(document: "frus1964-68v11/d1",
             v58: record("frus1964-68v11/d1", raw: "Source: " + seaborgV58, era: "foreign",
                         series: String(seaborgV58.prefix(IndexingPipeline.foreignArchiveSeriesLength))),
             v59: record("frus1964-68v11/d1", raw: "Source: " + seaborgV59, era: "foreign",
                         series: String(seaborgV59.prefix(IndexingPipeline.foreignArchiveSeriesLength))),
             joins: true),
        // The control: the class the v58 text hid is readable now, so the TARGET changed.
        Note(document: "frus1964-68v13/d4",
             v58: record("frus1964-68v13/d4",
                         raw: "Source: Department of State, Central Files, DEF ( MLF ) 9–5. Confidential.",
                         era: "decimal", repository: "Department of State"),
             v59: record("frus1964-68v13/d4",
                         raw: "Source: Department of State, Central Files, DEF (MLF) 9–5. Confidential.",
                         era: "decimal", repository: "Department of State"),
             joins: false),
    ]

    /// `frus1964-68v06` d147's footnote citation of the Johnson Library, before and after.
    private static func johnsonCitation(_ collection: String) -> ExternalCitation {
        ExternalCitation(anchor: "presidentialLibrary", repository: "Johnson Library",
                         collection: collection, lotFile: nil, lotFileNorm: nil, fileId: nil,
                         inherited: false, rawText: "Johnson Library, \(collection)", noteOrdinal: 1)
    }

    /// The key the builder mints for `record`.
    @MainActor
    private static func key(_ record: CollectionGeneratedBlocks.SourceRecord) -> String {
        TripPacketBuilder.targetKey(
            for: record,
            category: record.citationEra.map {
                SourceProvenanceCategory.from(citationEra: $0, repository: record.repository)
            }).key
    }

    private struct Built {
        let plan: ArchiveVisitPlan
        let tier: ArchiveVisitTier
        let stub: DerivationStub
    }

    /// A plan seeded with every fixture, whose stored rows were minted under the v58 keys, and a
    /// data source that answers with the v59 records.
    @MainActor
    private func planMadeBeforeTheReindex(in context: ModelContext) throws -> Built {
        let plan = ArchiveVisitPlan(name: "Made on v58")
        context.insert(plan)
        let tier = ArchiveVisitTier(label: "Day one", order: 0)
        plan.tiers = [tier]
        for note in Self.notes {
            let parts = note.document.split(separator: "/").map(String.init)
            plan.addSeeds([(parts[0], parts[1])], includeSource: true, includeExternalRefs: false,
                          in: context)
            let row = ArchiveVisitTarget(planId: plan.id, targetKey: Self.key(note.v58))
            row.plan = plan
            row.tierId = tier.id
            row.userNote = "note for \(note.document)"
            context.insert(row)
        }
        plan.addSeeds([("frus1964-68v06", "d147")], includeSource: false, includeExternalRefs: true,
                      in: context)
        let citationRow = ArchiveVisitTarget(
            planId: plan.id,
            targetKey: TripPacketBuilder.referenceKey(
                for: Self.johnsonCitation("Tom Johnson ’s Notes of Meetings")).key)
        citationRow.plan = plan
        citationRow.included = false
        context.insert(citationRow)
        try context.save()
        let stub = DerivationStub(
            sources: Self.notes.map(\.v59),
            citations: ["frus1964-68v06/d147": [Self.johnsonCitation("Tom Johnson’s Notes of Meetings")]])
        return Built(plan: plan, tier: tier, stub: stub)
    }

    @MainActor
    @Test("A plan made before the v59 re-index keeps each target's tier, note and exclusion after it")
    func planFromBeforeTheReindexFindsItsTargets() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let built = try planMadeBeforeTheReindex(in: context)
        let derived = await ArchiveVisitDerivation.derive(
            plan: built.plan, indexedVolumeIds: [], dataSource: built.stub)

        for note in Self.notes {
            let old = Self.key(note.v58), new = Self.key(note.v59)
            #expect(old != new, "\(note.document): the fixture no longer moves its key, so it proves nothing")
            #expect(derived.model.targets.contains { $0.key == new },
                    "\(note.document): the plan does not derive «\(new)»")
            if note.joins {
                #expect(derived.overlay.tierAssignments[new] == built.tier.id,
                        "\(note.document): the tier set on «\(old)» did not reach «\(new)»")
                #expect(derived.overlay.notes[new] == "note for \(note.document)")
                #expect(!derived.overlay.orphanKeys.contains(old), "\(note.document) was orphaned")
                #expect(derived.overlay.storedKey(for: new) == old)
            } else {
                #expect(derived.overlay.orphanKeys.contains(old),
                        "\(note.document): a row whose target changed must stay an orphan, not lend its tier")
                #expect(derived.overlay.tierAssignments[new] == nil)
            }
        }
        let citationKey = TripPacketBuilder.referenceKey(
            for: Self.johnsonCitation("Tom Johnson’s Notes of Meetings")).key
        #expect(derived.overlay.excludedKeys.contains(citationKey),
                "the exclusion set on the footnote citation's v58 key did not reach its v59 key")
        #expect(derived.overlay.orphanKeys.count == 1, "only the re-grouped note is an orphan")
        #expect(derived.overlay.storedKeyCount == Self.notes.count + 1)
    }

    /// The editor's write path: a tier set on a target whose row was minted under the v58 key
    /// updates THAT row. Resolved without the overlay, the lookup found no row with the v59 key and
    /// minted a second one, leaving the target's note behind on the first.
    @MainActor
    @Test("Setting a tier after the re-index updates the row minted before it, and mints nothing")
    func writeAfterTheReindexUpdatesTheOldRow() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let built = try planMadeBeforeTheReindex(in: context)
        let derived = await ArchiveVisitDerivation.derive(
            plan: built.plan, indexedVolumeIds: [], dataSource: built.stub)
        let note = Self.notes[0]
        let rowsBefore = built.plan.targets?.count ?? 0
        let later = ArchiveVisitTier(label: "If time allows", order: 1)
        built.plan.tiers = [built.tier, later]

        let row = try #require(built.plan.targetState(forKey: Self.key(note.v59),
                                                      resolvedBy: derived.overlay,
                                                      mintIfMissing: true, in: context))
        #expect(row.targetKey == Self.key(note.v58), "the write reached a row other than the one minted on v58")
        row.tierId = later.id
        try context.save()
        #expect(built.plan.targets?.count == rowsBefore, "a second row was minted beside the v58 one")

        let again = await ArchiveVisitDerivation.derive(
            plan: built.plan, indexedVolumeIds: [], dataSource: built.stub)
        #expect(again.overlay.tierAssignments[Self.key(note.v59)] == later.id)
        #expect(again.overlay.notes[Self.key(note.v59)] == "note for \(note.document)")
    }

    /// The resolution rule's conjuncts, one fixture each.
    @Test("A stored key joins exactly one derived key, never by a guess")
    func resolutionRefusesAmbiguity() {
        typealias K = ArchiveVisitTargetKeys
        // Spaces only: joins.
        #expect(K.resolve(storedKeys: ["r|No . 1259.]"], derivedKeys: ["r|No. 1259.]"])
                == ["r|No . 1259.]": "r|No. 1259.]"])
        // An exact match wins, and its derived key is not offered to the re-spelled row.
        #expect(K.resolve(storedKeys: ["r|No. 1259.]", "r|No . 1259.]"], derivedKeys: ["r|No. 1259.]"])
                == ["r|No. 1259.]": "r|No. 1259.]"])
        // One stored key, two derived keys it could name: neither.
        #expect(K.resolve(storedKeys: ["r|No . 1259.]"],
                          derivedKeys: ["r|No. 1259.]", "r|No .1259.]"]).isEmpty)
        // Two stored keys, one derived key both could name: neither.
        #expect(K.resolve(storedKeys: ["r|No . 1259.]", "r|No. 1259 .]"],
                          derivedKeys: ["r|No. 1259.]"]).isEmpty)
        // A different note does not join because it merely shares a prefix.
        #expect(K.resolve(storedKeys: ["r|No . 1259.]"], derivedKeys: ["r|No. 1260.]"]).isEmpty)
    }

    /// The foreign-archive cut, one fixture per conjunct: both `coll|`, the shorter series exactly
    /// the cut's length, and the longer beginning with the shorter once spaces are removed.
    @Test("A series cut at 80 characters joins the longer cut it begins, and nothing else does")
    func truncatedSeriesJoinsOnlyAtTheCut() {
        typealias K = ArchiveVisitTargetKeys
        let cut = IndexingPipeline.foreignArchiveSeriesLength
        let old = "coll||" + String(Self.seaborgV58.prefix(cut))
        let new = "coll||" + String(Self.seaborgV59.prefix(cut))
        #expect(old != new && K.spacingInsensitive(old) != K.spacingInsensitive(new),
                "the fixture must be a cut, not a spacing-only change")
        #expect(K.sameTarget(stored: old, derived: new))
        #expect(K.sameTarget(stored: new, derived: old), "a row minted on v59, read on v58")
        // Shorter than the cut: the series is whole, so a prefix is a different series.
        let whole = "coll||" + String(Self.seaborgV58.prefix(cut - 1))
        #expect(!K.sameTarget(stored: whole, derived: new))
        // Not a `coll|` key: a raw note with a bar in it has a third component of the cut's length
        // too, and it is not a series.
        #expect(!K.sameTarget(stored: "r|Filed|" + String(Self.seaborgV58.prefix(cut)),
                              derived: "r|Filed|" + String(Self.seaborgV59.prefix(cut))))
        // The cut, but a different series.
        #expect(!K.sameTarget(stored: old, derived: "coll||" + String(("Glenn T. Seaborg, Diary "
            + Self.seaborgV59).prefix(cut))))
    }
}

// MARK: - ArchiveVisitTopicSeedingTests

/// Pins #1366's rule for the inquiry topic sentence: **seeded at creation on every path, refreshed
/// only by an explicit Re-seed from Project** — never read from the project at render time.
///
/// Every test drives the real paths: plans come out of `ArchiveVisitPlan.make` (the factory all
/// four creation sites call — `TripPacketEntryPointParityTests` pins that no site bypasses it),
/// Re-seed runs `ArchiveVisitPlan.reseed(fromProject:in:)` against a saved project in a real
/// container, and what the plan would print is read from `ArchiveVisitDerivation.derive` and
/// `TripPacketExporter.inquiryDrafts` — the same two calls the packet sheet makes. Before #1366
/// three of the four creation sites passed a bare name, so a plan made under a project with a
/// research question exported the placeholder and carried no project at all.
///
/// Version history:
///   1.0 — #1366: initial implementation
///   1.1 — #1366 review: the render-time rule is pinned where it can fail (an empty topic under a
///         project whose question is set), and a project merge and delete are driven through
///         `ProjectAdminService` — a merged project's plans follow it, a deleted one's offer no
///         Re-seed and Re-seed against it changes nothing
///   1.2 — #1366 review, round 2: the merge fixture gains the one plan whose order tells in-place
///         re-pointing from filter-then-append, and the render-time rule is pinned on the packet
///         sheet's path too, through `TripPacketTopicSentence.openPlanDraft`
///   1.3 — #1377: the packet sheet's Done commits a topic the debounce has not yet taken, through
///         `TripPacketTopicSentence.isUncommitted`
///   1.4 — #1377 review, round 1: the predicate test's comment names what it does not pin — the
///         commit inside `finish()`, which `tripPacketSheetFinishCommitsBeforeClosing` now pins
@Suite("Archives Visit topic seeding (#1366)")
@MainActor
struct ArchiveVisitTopicSeedingTests {

    /// A question long enough that a substring match could not come from anything else.
    private static let question = "How did the airlift's tonnage targets change over 1948?"
    /// A second question — the project's question after the plan was made.
    private static let laterQuestion = "Who in Washington set the airlift's winter tonnage target?"

    /// Inserts and SAVES a project: `ProjectLeadsService.gatherSeed` reads through a fresh
    /// context, which sees only saved rows.
    private func makeProject(question: String?, in context: ModelContext) throws -> Project {
        let project = Project(name: "Berlin", researchQuestion: question)
        context.insert(project)
        try context.save()
        return project
    }

    /// The plan's packet model, derived the way the packet sheet derives it — through
    /// `ArchiveVisitDerivation` — over one RG 59 lot seed so a facility draft exists.
    private func derivedModel(_ plan: ArchiveVisitPlan,
                              in context: ModelContext) async throws -> TripPacketModel {
        plan.addSeeds([("v1", "d1")], includeSource: true, includeExternalRefs: false,
                      in: context)
        try context.save()
        return await ArchiveVisitDerivation.derive(
            plan: plan, indexedVolumeIds: ["v1"],
            dataSource: DerivationStub(sources: [lotRecord("v1", "d1", lot: "60 D 1")])).model
    }

    /// What the plan's inquiry drafts print as their topic, and the drafts themselves, over
    /// ``derivedModel(_:in:)``.
    private func export(_ plan: ArchiveVisitPlan,
                        in context: ModelContext) async throws -> (topic: String, drafts: String) {
        let model = try await derivedModel(plan, in: context)
        let drafts = TripPacketExporter(model: model, projectName: plan.displayName)
            .inquiryDrafts
        #expect(drafts.contains("Topic: "), """
            Fixture guard: the lot seed must place at a facility, or there is no draft whose \
            topic line this suite could read.
            """)
        return (model.topicSentence.forExport, drafts)
    }

    // MARK: - Creation

    /// **The issue's own failure.** A plan created under a project whose research question is set
    /// must export that question — not the placeholder — and belong to the project.
    @Test("A plan made under a project exports the project's question")
    func planMadeUnderAProjectExportsItsQuestion() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let project = try makeProject(question: Self.question, in: context)

        // The form the list, the Mac window and the picker call.
        let plan = ArchiveVisitPlan.make(name: "", activeProjectId: project.id, in: context)
        context.insert(plan)
        #expect(plan.projectIds == [project.id], """
            A plan made under the active project must belong to it, as collections and notes do — \
            without the id, Re-seed from Project is never offered and Project Home cannot find it.
            """)
        #expect(plan.inquiryText == Self.question,
                "the question is copied into the plan at creation, so the sheet's field shows it")
        let exported = try await export(plan, in: context)
        #expect(exported.topic == Self.question)
        #expect(exported.drafts.contains("Topic: \(Self.question)"))
        #expect(!exported.drafts.contains(TripPacketTopicSentence.placeholder), """
            The draft printed the placeholder under a project with a research question — #1366.
            """)

        // Project Home's form, over the project it shows, seeds the same two fields.
        let home = ArchiveVisitPlan.make(name: project.name, activeProject: project)
        #expect(home.projectIds == [project.id])
        #expect(home.inquiryText == Self.question)
        #expect(home.name == "Berlin")
    }

    /// With no active project there is nothing to copy: the placeholder, and no project.
    @Test("A plan made in the global context exports the placeholder and has no project")
    func planMadeWithNoProjectExportsThePlaceholder() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        _ = try makeProject(question: Self.question, in: context)   // exists, but is not active

        let plan = ArchiveVisitPlan.make(name: "", activeProjectId: nil, in: context)
        context.insert(plan)
        #expect(plan.projectIds.isEmpty)
        #expect(plan.inquiryText == nil)
        let exported = try await export(plan, in: context)
        #expect(exported.topic == TripPacketTopicSentence.placeholder)
        #expect(!exported.drafts.contains(Self.question),
                "a project that is not active must not reach the plan")
    }

    /// An active id whose project no longer exists (deleted on another device) attaches nothing —
    /// the `flatMap` branch of `make(name:activeProjectId:in:)`.
    @Test("An active project id that no longer resolves attaches nothing")
    func unresolvedProjectIdAttachesNothing() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        _ = try makeProject(question: Self.question, in: context)

        let plan = ArchiveVisitPlan.make(name: "", activeProjectId: UUID(), in: context)
        context.insert(plan)
        #expect(plan.projectIds.isEmpty, """
            A dangling id must not be attached: no Project Home can open the plan through it, and \
            Re-seed from Project would find no question behind it.
            """)
        #expect(plan.inquiryText == nil)
        #expect(try await export(plan, in: context).topic == TripPacketTopicSentence.placeholder)
    }

    /// A project with no question, and one whose question is only whitespace, each copy nothing —
    /// one fixture per half of `TripPacketTopicSentence.written`'s guard. The plan still belongs to
    /// the project, which is what later lets Re-seed from Project offer a question written after.
    @Test("A project with a nil or blank question copies no topic")
    func nilOrBlankQuestionCopiesNothing() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        for question in [nil, "  \n\t "] as [String?] {
            let project = try makeProject(question: question, in: context)
            let plan = ArchiveVisitPlan.make(name: "", activeProjectId: project.id, in: context)
            context.insert(plan)
            #expect(plan.projectIds == [project.id])
            #expect(plan.inquiryText == nil, """
                A \(question == nil ? "nil" : "blank") question was stored as the topic — an empty \
                field would then look like a written topic.
                """)
            #expect(try await export(plan, in: context).topic
                    == TripPacketTopicSentence.placeholder)
        }
    }

    // MARK: - Re-seed from Project

    /// **The explicit refresh.** The project's question changes after the plan was made: Re-seed
    /// offers the new question and writes nothing until the reader confirms; confirming exports it.
    @Test("Re-seed after the question changes offers the new one and waits for confirmation")
    func reseedOffersTheChangedQuestion() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let project = try makeProject(question: Self.question, in: context)
        let plan = ArchiveVisitPlan.make(name: "", activeProjectId: project.id, in: context)
        context.insert(plan)
        try context.save()

        project.researchQuestion = Self.laterQuestion
        try context.save()

        // The stored topic stands until the reader asks. This cannot tell a render-time seed from
        // none — a stored topic wins over any seed — so that rule is pinned where the topic is
        // empty, in `reseedFillsAnEmptyTopic`.
        #expect(try await export(plan, in: context).topic == Self.question)

        let outcome = await plan.reseed(fromProject: project.id, in: context)
        #expect(outcome == .needsConfirmation(question: Self.laterQuestion,
                                              current: Self.question), """
            Re-seed must offer the project's CURRENT question — before #1366 it moved documents \
            only, so a changed question could never reach the plan.
            """)
        #expect(plan.inquiryText == Self.question, "nothing is written before the reader confirms")

        plan.replaceInquiryTopic(with: Self.laterQuestion)
        #expect(try await export(plan, in: context).topic == Self.laterQuestion)
    }

    /// A topic the reader wrote is never replaced without confirmation.
    @Test("Re-seed never overwrites an edited topic without confirmation")
    func reseedNeverOverwritesAnEditedTopic() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let project = try makeProject(question: Self.question, in: context)
        let plan = ArchiveVisitPlan.make(name: "", activeProjectId: project.id, in: context)
        context.insert(plan)
        let mine = "Tonnage figures in the 1948 airlift planning papers."
        plan.inquiryText = mine
        try context.save()

        let outcome = await plan.reseed(fromProject: project.id, in: context)
        #expect(outcome == .needsConfirmation(question: Self.question, current: mine))
        #expect(plan.inquiryText == mine)
        #expect(try await export(plan, in: context).topic == mine)
    }

    /// A question written AFTER the plan was made reaches an empty topic in one tap — the fill
    /// branch, which asks nothing because there is nothing to lose.
    ///
    /// It is also where **"never seeded at render time"** is pinned for the export, because it is
    /// the one state that can fail it: no stored topic, under a project whose question is set.
    /// Before the Re-seed, the drafts must print the placeholder; a derivation that read the
    /// project's question at render time — the fallback the model's old comment promised — would
    /// print it. The packet sheet's field is pinned in the same state by
    /// `packetSheetOpensThePlansOwnTopic`.
    @Test("Re-seed fills an empty topic with a question written after the plan")
    func reseedFillsAnEmptyTopic() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let project = try makeProject(question: nil, in: context)
        let plan = ArchiveVisitPlan.make(name: "", activeProjectId: project.id, in: context)
        context.insert(plan)
        try context.save()
        #expect(plan.inquiryText == nil, "fixture guard: the plan starts with no topic")

        project.researchQuestion = Self.laterQuestion
        try context.save()
        #expect(try await export(plan, in: context).topic == TripPacketTopicSentence.placeholder, """
            The project's question reached an empty topic before any Re-seed — the derivation \
            seeded it at render time, which the owner's rule (#1366, §4 item 1) refuses: the \
            packet sheet's field would be empty while the drafts printed the question.
            """)
        let outcome = await plan.reseed(fromProject: project.id, in: context)
        #expect(outcome == .filled(question: Self.laterQuestion))
        #expect(plan.inquiryText == Self.laterQuestion)
        #expect(try await export(plan, in: context).topic == Self.laterQuestion)
    }

    /// A topic that already reads the question — including one differing only in surrounding
    /// whitespace — is left alone, and nothing is asked.
    @Test("Re-seed leaves a topic that already reads the question")
    func reseedLeavesAMatchingTopic() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let project = try makeProject(question: Self.question, in: context)
        let plan = ArchiveVisitPlan.make(name: "", activeProjectId: project.id, in: context)
        context.insert(plan)
        try context.save()
        #expect(await plan.reseed(fromProject: project.id, in: context) == .unchanged)

        plan.inquiryText = "  \(Self.question)\n"
        #expect(await plan.reseed(fromProject: project.id, in: context) == .unchanged, """
            A topic that differs from the question only by surrounding whitespace says the same \
            thing — asking would offer the reader a replacement that changes nothing.
            """)
        #expect(plan.inquiryText == "  \(Self.question)\n")
    }

    /// No question to offer — the project has none, or no longer exists — changes nothing. One
    /// fixture per way `reseedTopic`'s first guard is reached.
    @Test("Re-seed with no question to offer changes nothing")
    func reseedWithNoQuestionChangesNothing() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let project = try makeProject(question: nil, in: context)
        let plan = ArchiveVisitPlan.make(name: "", activeProjectId: project.id, in: context)
        context.insert(plan)
        plan.inquiryText = "Mine."
        try context.save()

        #expect(await plan.reseed(fromProject: project.id, in: context) == .unchanged)
        #expect(plan.inquiryText == "Mine.")
        #expect(await plan.reseed(fromProject: UUID(), in: context) == .unchanged,
                "a project that no longer exists offers nothing")
        #expect(plan.inquiryText == "Mine.")
    }

    // MARK: - A project merged or deleted (#1366 review)

    /// **A merged project's plans follow it.** `ProjectAdminService.merge` re-pointed notes,
    /// collections, summaries and history but never a plan, so after a merge a plan still named
    /// the deleted source: the target's Project Home could not find it, and Re-seed from Project
    /// was offered with nothing behind it. Since #1366 every plan made under a project carries its
    /// id, so a merge would have stranded far more of them.
    @Test("A merged project's plans follow it, and Re-seed offers the target's question")
    func mergedProjectsPlansFollowIt() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let appState = AppState()
        let source = try makeProject(question: Self.question, in: context)
        let target = Project(name: "Airlift", researchQuestion: Self.laterQuestion)
        let bystander = Project(name: "Occupation")
        context.insert(target)
        context.insert(bystander)
        let plan = ArchiveVisitPlan.make(name: "", activeProjectId: source.id, in: context)
        // A plan naming another project FIRST: re-pointed in place, so its owner stays the same.
        let shared = ArchiveVisitPlan(name: "Shared", projectIds: [bystander.id, source.id])
        // A plan already naming the target: re-pointed without a duplicate.
        let both = ArchiveVisitPlan(name: "Both", projectIds: [source.id, target.id])
        // A plan owned by the SOURCE that also names another project: the one fixture where
        // in-place re-pointing ([target, bystander]) and the Collection rule's
        // filter-then-append ([bystander, target]) disagree (#1366 round 2). The other three get
        // the same answer under either rule, so without this one the order is claimed, not tested.
        let owned = ArchiveVisitPlan(name: "Owned", projectIds: [source.id, bystander.id])
        for made in [plan, shared, both, owned] { context.insert(made) }
        try context.save()

        ProjectAdminService.merge(source, into: target, context: context, appState: appState)
        try context.save()

        #expect(plan.projectIds == [target.id], """
            A merge must move the plan to the target, as it moves collections — left on the deleted \
            source's id, the target's Project Home cannot find it.
            """)
        #expect(shared.projectIds == [bystander.id, target.id],
                "re-pointed in place: the first id — the plan's owning project — must not change")
        #expect(both.projectIds == [target.id], "the target must not be named twice")
        #expect(owned.projectIds == [target.id, bystander.id], """
            The source's place must go to the target — filtering the source out and appending the \
            target (the rule notes and collections follow) hands the plan to the bystander, the \
            project it named second.
            """)
        let projects = try context.fetch(FetchDescriptor<Project>())
        #expect(owned.owningProject(among: projects)?.id == target.id,
                "Re-seed from Project must offer the target's question, not the bystander's")
        #expect(plan.owningProject(among: projects)?.id == target.id,
                "the editor's gate: Re-seed from Project stays offered, now for the target")
        #expect(plan.owningProject(in: context)?.id == target.id)
        #expect(plan.inquiryText == Self.question, "the topic text survives the merge")
        #expect(await plan.reseed(fromProject: target.id, in: context)
                == .needsConfirmation(question: Self.laterQuestion, current: Self.question))
    }

    /// **A deleted project's plans offer no Re-seed.** A delete keeps the id on the plan, as it
    /// keeps notes' and collections' ("kept but unlinked from this project"), so the editor used to
    /// offer Re-seed from Project with no question behind it. The gate resolves the id instead, and
    /// Re-seed against it changes nothing — not even documents from the deleted project's notes,
    /// which the reader was told had left it. The bystander project makes the id match
    /// load-bearing: a gate that took any project would find one.
    @Test("A deleted project's plans keep its id but offer no Re-seed, and Re-seed changes nothing")
    func deletedProjectsPlansOfferNoReseed() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let appState = AppState()
        let project = try makeProject(question: Self.question, in: context)
        context.insert(Project(name: "Occupation", researchQuestion: Self.laterQuestion))
        let plan = ArchiveVisitPlan.make(name: "", activeProjectId: project.id, in: context)
        context.insert(plan)
        context.insert(ResearchNote(documentId: "d7", volumeId: "v2", bodyText: "n",
                                    projectIds: [project.id]))
        try context.save()
        let projectId = project.id
        #expect(plan.owningProject(among: try context.fetch(FetchDescriptor<Project>()))?.id
                == projectId, "fixture guard: Re-seed is offered before the delete")

        ProjectAdminService.delete(project, context: context, appState: appState)
        try context.save()

        #expect(plan.projectIds == [projectId],
                "a delete keeps the plan's id, as it keeps notes' and collections'")
        #expect(plan.owningProject(among: try context.fetch(FetchDescriptor<Project>())) == nil,
                "the editor's gate: no Re-seed from Project once the project is gone")
        #expect(plan.owningProject(in: context) == nil)
        #expect(await plan.reseed(fromProject: projectId, in: context) == .unchanged)
        #expect((plan.documents ?? []).isEmpty, """
            Re-seed against a deleted project seeded its orphaned note's document — records the \
            reader was told had left the project.
            """)
        #expect(plan.inquiryText == Self.question)
    }

    /// Moving Re-seed into the model kept its first half: the project's engaged documents still
    /// arrive as seeds, both contributions on.
    @Test("Re-seed still adds the project's engaged documents")
    func reseedStillAddsEngagedDocuments() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let project = try makeProject(question: Self.question, in: context)
        let plan = ArchiveVisitPlan.make(name: "", activeProjectId: project.id, in: context)
        context.insert(plan)
        context.insert(ResearchNote(documentId: "d7", volumeId: "v2", bodyText: "n",
                                    projectIds: [project.id]))
        try context.save()

        _ = await plan.reseed(fromProject: project.id, in: context)
        let seed = try #require(plan.documents?.first { $0.documentKey == "v2/d7" },
                                "the noted document must be seeded by Re-seed from Project")
        #expect(seed.includeSource && seed.includeExternalRefs)
    }

    // MARK: - The packet sheet's caption

    /// The caption says "Seeded from your project's research question" only while the field
    /// still reads it — before #1366 it tested the question alone, which was always `nil`.
    @Test("The seeded caption shows only while the field reads the project's question")
    func seededCaptionFollowsTheField() {
        #expect(TripPacketTopicSentence.showsSeededCaption(draft: Self.question,
                                                           researchQuestion: Self.question))
        #expect(TripPacketTopicSentence.showsSeededCaption(draft: "\(Self.question)\n",
                                                           researchQuestion: Self.question),
                "a trailing newline from the vertical field does not un-seed the topic")
        #expect(!TripPacketTopicSentence.showsSeededCaption(draft: "My own topic.",
                                                            researchQuestion: Self.question),
                "a rewritten topic is the reader's, not the project's")
        #expect(!TripPacketTopicSentence.showsSeededCaption(draft: "",
                                                            researchQuestion: Self.question),
                "an empty field exports the placeholder, not the question")
        #expect(!TripPacketTopicSentence.showsSeededCaption(draft: Self.question,
                                                            researchQuestion: nil))
        #expect(!TripPacketTopicSentence.showsSeededCaption(draft: "", researchQuestion: " "),
                "two blanks are not a match: neither says anything")
    }

    /// **The packet sheet opens the plan's own topic, never the project's question** (#1366
    /// review, round 2). The editor hands the sheet the project's question for its caption, so the
    /// sheet's `.plan` rebuild could fill an empty field from it: a render-time seed on the sheet's
    /// path, which `reseedFillsAnEmptyTopic` cannot see, because it reads the export and not the
    /// field. The rule is `TripPacketTopicSentence.openPlanDraft`, driven here over the sheet's own
    /// derivation. That the sheet calls it with the plan's stored topic, and names the question
    /// nowhere else, is `TripPacketEntryPointParityTests.packetSheetOpensThePlansOwnTopic`'s.
    @Test("The packet sheet opens an empty topic empty, whatever the project's question")
    func packetSheetOpensThePlansOwnTopic() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let project = try makeProject(question: nil, in: context)
        let plan = ArchiveVisitPlan.make(name: "", activeProjectId: project.id, in: context)
        context.insert(plan)
        try context.save()
        project.researchQuestion = Self.laterQuestion
        try context.save()

        var opened = try await derivedModel(plan, in: context)
        let field = opened.topicSentence.openPlanDraft(draft: "", stored: plan.inquiryText)
        #expect(field.isEmpty, """
            The sheet's topic field opened with "\(field)" over a plan whose topic is empty — the \
            project's question reached it at render time, which the owner's rule (#1366, §4 \
            item 1) refuses. Only creation and Re-seed from Project copy it.
            """)
        #expect(opened.topicSentence.forExport == TripPacketTopicSentence.placeholder,
                "the drafts must print the placeholder while the field is empty")
        #expect(!TripPacketTopicSentence.showsSeededCaption(draft: field,
                                                            researchQuestion: project.researchQuestion))

        #expect(await plan.reseed(fromProject: project.id, in: context)
                == .filled(question: Self.laterQuestion))
        var reseeded = try await derivedModel(plan, in: context)
        let filled = reseeded.topicSentence.openPlanDraft(draft: "", stored: plan.inquiryText)
        #expect(filled == Self.laterQuestion,
                "with no live draft the field mirrors the plan's stored topic")
        #expect(reseeded.topicSentence.forExport == Self.laterQuestion)
        #expect(TripPacketTopicSentence.showsSeededCaption(draft: filled,
                                                           researchQuestion: project.researchQuestion))

        let mine = "Tonnage figures in the 1948 airlift planning papers."
        let live = reseeded.topicSentence.openPlanDraft(draft: mine, stored: plan.inquiryText)
        #expect(live == mine, "a rebuild must not replace a live draft with the stored topic")
        #expect(reseeded.topicSentence.forExport == mine,
                "a live draft is what the drafts send until it is committed")
    }

    // MARK: - Done commits the field (#1377)

    /// **Done commits a topic the debounce has not yet taken** (#1377). The sheet commits its topic
    /// field half a second after typing stops. On the Mac, Done became the sheet's default button,
    /// so Return in the field can reach it sooner, and `TripPacketSheet.finish()` asks this before
    /// it closes. `edited` is what the sheet last committed: `nil` for a blank field, the text as
    /// typed otherwise. This pins the predicate only. That both Done buttons call `finish()` is
    /// `MacSheetToolbarPlacementAuditTests.tripPacketSheetMacBodyHoldsItsControls`'s, and that
    /// `finish()` cancels the debounce, commits when this says so, and only then dismisses is
    /// `tripPacketSheetFinishCommitsBeforeClosing`'s.
    @Test("Done commits the topic field only when it holds an edit the model has not taken")
    func doneCommitsOnlyAnUncommittedTopic() {
        #expect(!TripPacketTopicSentence.isUncommitted(draft: "", edited: nil),
                "nothing typed, nothing to commit")
        #expect(!TripPacketTopicSentence.isUncommitted(draft: "  \n", edited: nil),
                "a blank field commits as nil, which the model already holds")
        #expect(!TripPacketTopicSentence.isUncommitted(draft: " ", edited: "  "),
                "two blanks say the same nothing")
        #expect(!TripPacketTopicSentence.isUncommitted(draft: Self.question, edited: Self.question),
                "a field the model already took")
        #expect(TripPacketTopicSentence.isUncommitted(draft: Self.question, edited: nil),
                "a first topic, typed and not yet taken")
        #expect(TripPacketTopicSentence.isUncommitted(draft: Self.laterQuestion, edited: Self.question),
                "a rewritten topic")
        #expect(TripPacketTopicSentence.isUncommitted(draft: "", edited: Self.question),
                "a cleared field, whose drafts must go back to the placeholder")
        #expect(TripPacketTopicSentence.isUncommitted(draft: "\(Self.question) ", edited: Self.question),
                "the drafts send the field as typed, trailing space and all")
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
