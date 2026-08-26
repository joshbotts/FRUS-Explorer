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

// MARK: - RepositoryFactTableTests

/// Pins D7's per-fact verification and the empty-table-that-still-builds shape.
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-1
@Suite("Repository fact table (#830 T-1)")
struct RepositoryFactTableTests {

    /// **The constraint the whole T-0 gate rests on**, now at its second state.
    ///
    /// At T-1 this asserted the table was EMPTY, and said: "if the owner has now confirmed some,
    /// this test changes deliberately, in the same commit." That happened on 2026-08-22 — the NACP
    /// address and inquiry email were confirmed — so this now pins exactly what is confirmed and
    /// exactly what is not, which is the stronger claim.
    @Test("Only owner-confirmed facts are printable, and the rest stay dark")
    func onlyConfirmedFactsArePrintable() throws {
        let row = try #require(
            RepositoryFactTable.current.row(for: ResearchFacilityResolver.collegePark))
        #expect(row.address.printable?.contains("8601 Adelphi Road") == true, """
            The NACP address is confirmed (2026-08-22) and must print — A2's one-address rule is \
            the inquiry mechanic and a generated draft needs a recipient.
            """)
        #expect(row.inquiryEmail.printable == "Archives2reference@nara.gov")
        #expect(row.appointmentPolicy.printable == nil, """
            The appointment policy printed. A1 distinguishes DC-area rooms from other facilities, \
            and which applies is per-row policy the owner has NOT confirmed — so the packet must \
            ask the researcher to check rather than assert.
            """)
    }

    /// A library row now exists — and carries **only** a link.
    ///
    /// This test used to assert the libraries were absent entirely, which was true while the table
    /// was empty and became false the moment the ten rows landed. The premise was never the point:
    /// D2/D11's actual guarantee is that no unconfirmed institutional fact prints, and that survives
    /// the rows arriving. So it now pins the guarantee rather than the emptiness — a row may hold a
    /// stamped URL, and its address, email and appointment policy must all stay dark.
    @Test("A library row carries a stamped link and no unconfirmed prose")
    func librariesCarryLinksOnly() {
        for library in ["Truman Library", "Kennedy Library", "Johnson Library"] {
            guard let row = RepositoryFactTable.current.row(for: library) else {
                Issue.record("\(library) is cited by the corpus but has no curated row")
                continue
            }
            #expect(row.address.printable == nil, """
                \(library) would print an address nobody confirmed. D11 reduced the library chapter \
                to a confirm-before-you-travel prompt precisely because the packet cannot name a \
                series or a NAID at collection grain — an address here would imply it could.
                """)
            #expect(row.inquiryEmail.printable == nil)
            #expect(row.appointmentPolicy.printable == nil)
            #expect(row.links.allSatisfy { $0.isPrintable }, "an unstamped link would not print")
            #expect(row.hasAnythingToPrint, "a row that renders nothing should not be in the table")
        }
    }

    /// An unverified fact is omitted, never printed undated.
    @Test("An unverified fact refuses to be printed")
    func unverifiedFactsAreOmitted() {
        let unverified = VerifiedFact.unverified("8601 Adelphi Road, College Park, MD")
        #expect(unverified.printable == nil, """
            An unverified address was printable. D7: omitted, never greyed or marked provisional — \
            a plausible-looking address with a caveat beside it is more dangerous than a gap, \
            because the caveat is the part people skim.
            """)
        let verified = VerifiedFact(value: "8601 Adelphi Road", verifiedDate: Date())
        #expect(verified.printable == "8601 Adelphi Road")
    }

    /// A row with nothing verified renders nothing — the normal state at T-1, not a bug.
    @Test("A row with no verified facts prints nothing")
    func fullyUnverifiedRowPrintsNothing() {
        let row = RepositoryFactRow(
            id: "truman library", displayName: "Truman Library",
            address: .unverified("x"), inquiryEmail: .unverified("y"),
            appointmentPolicy: .unverified("z"),
            links: [RepositoryLink(url: "https://example.org", label: "Finding aid", verifiedDate: nil)])
        #expect(!row.hasAnythingToPrint)
    }

    /// One confirmed fact lights up one line — D7's incrementality, which is what lets the gate
    /// proceed fact by fact instead of waiting on one sitting.
    @Test("Confirming one fact lights up that fact alone")
    func confirmationIsIncremental() {
        let row = RepositoryFactRow(
            id: "truman library", displayName: "Truman Library",
            address: VerifiedFact(value: "500 W US Hwy 24", verifiedDate: Date()),
            inquiryEmail: .unverified("truman.library@nara.gov"),
            appointmentPolicy: .unverified("required"),
            links: [])
        #expect(row.hasAnythingToPrint)
        #expect(row.address.printable != nil)
        #expect(row.inquiryEmail.printable == nil, "an unconfirmed sibling must stay dark")
        #expect(row.appointmentPolicy.printable == nil)
    }

    /// D12: a link with no stamp is an unverified fact like any other, and an old stamp hedges the
    /// sentence rather than withholding the link.
    @Test("Link staleness degrades the sentence, never the build")
    func linkStalenessDegrades() {
        let never = RepositoryLink(url: "https://a", label: "l", verifiedDate: nil)
        #expect(!never.isPrintable)
        #expect(never.isStale(), "a link never checked is stale by definition")

        let now = Date()
        let fresh = RepositoryLink(url: "https://b", label: "l", verifiedDate: now)
        #expect(fresh.isPrintable)
        #expect(!fresh.isStale(asOf: now))

        let old = RepositoryLink(url: "https://c", label: "l",
                                 verifiedDate: now.addingTimeInterval(-400 * 24 * 60 * 60))
        #expect(old.isPrintable, """
            A stale link stopped being printable. D12: staleness degrades the SENTENCE around a \
            link, never the build — withholding it would hide the one fact class a researcher can \
            check themselves.
            """)
        #expect(old.isStale(asOf: now))
    }
}

// MARK: - TripPacketModelTests

/// Pins the assembled packet (#830 T-1; targets since Archive Visits Phase 1).
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-1
///   2.0 — Archive Visits Phase 1: the checklist and advance-notice suites left with their
///          chapters; new coverage for target assembly (channel merge under one claim-free
///          key, form detection from the builder's key prefixes, the claimant-aware
///          restriction rule, and the pre-1946 flag)
@Suite("Trip packet model (#830 T-1)")
struct TripPacketModelTests {

    private func group(_ key: String, category: SourceProvenanceCategory?, repository: String?,
                       naId: String? = nil, count: Int = 1, lotAsPrinted: String? = nil)
        -> (key: String, label: String, category: SourceProvenanceCategory?,
            repository: String?, lotAsPrinted: String?, resolution: ArchivalResolution?,
            documents: [TripPacketModel.Group.DocumentRef]) {
        (key: key, label: key, category: category, repository: repository,
         lotAsPrinted: lotAsPrinted,
         resolution: naId.map { naId in
             ArchivalResolution(naId: naId,
                                catalogURL: "https://catalog.archives.gov/id/\(naId)",
                                title: "Series \(naId)", recordGroup: "59", matchType: "lot",
                                hmsMlrEntryNumbers: nil, levelOfDescription: "series",
                                seriesNaId: nil, seriesTitle: nil,
                                seriesHmsMlrEntryNumbers: nil)
         },
         documents: TripPacketExporterTests.refs(count))
    }

    /// The packet builds with the empty table, and a library group renders a heading-less
    /// confirm-prompt rather than a guess.
    @Test("A library group builds, cannot head a chapter, and carries no curated facts")
    func libraryGroupBuildsWithoutGuessing() {
        let model = TripPacketModel.build(
            groups: [group("truman", category: .presidentialLibrary, repository: "Truman Library")],
            documentYears: [1948], unresolvedLotCount: 0, unresolvedDocumentCount: 0,
            researchQuestion: nil, facts: { _ in nil }, claimants: { _ in nil })
        let only = model.groups[0]
        #expect(only.facility == .unknown)
        #expect(!only.canHeadChapter, """
            A library headed a chapter with no confirmed facility. No chapter may be headed with a \
            string that names no place a researcher can be served.
            """)
        // T-1 asserted this was nil because the table was empty. The table now ships ten library
        // rows, so the meaningful assertion is that the group reached ITS row — and only its own.
        #expect(only.facts?.id == "Truman Library", """
            A library group did not reach its curated row. `Group.facts` is the ONLY lookup that \
            reaches a library: a library never resolves to a facility heading (D3), so the \
            exporter's facility-keyed lookup cannot serve it.
            """)
        // D16's full pairing (D21 discharged): the visit-planning page AND the finding aids,
        // separately labelled — never merged into one "more information" link.
        #expect(only.facts?.links.count == 2)
        #expect(only.facts?.links.map(\.label) == ["Plan a research visit",
                                                   "Finding aids — what is held"])
        #expect(model.needingConfirmation.map(\.id) == ["truman"], """
            A group the packet cannot place must be REPORTED — it is exactly what the reader has to \
            ring ahead about, and dropping it would leave part of their reading unplanned.
            """)
    }

    /// Groups sort by how much of the reading they carry.
    @Test("Groups sort most-cited first")
    func groupsSortByReach() {
        let model = TripPacketModel.build(
            groups: [group("a", category: .centralDecimalFile, repository: nil, count: 3),
                     group("b", category: .centralDecimalFile, repository: nil, count: 40),
                     group("c", category: .centralDecimalFile, repository: nil, count: 12)],
            documentYears: [], unresolvedLotCount: 0, unresolvedDocumentCount: 0,
            researchQuestion: nil, facts: { _ in nil })
        #expect(model.groups.map(\.id) == ["b", "c", "a"])
    }

    /// D8: the exporter reads the EDITED value, never the stored research question.
    @Test("The topic sentence prefers the edit, then the seed, then an instruction")
    func topicSentencePrefersTheEdit() {
        var sentence = TripPacketTopicSentence.seeded(from: "Why did Kennan write the Long Telegram?")
        #expect(sentence.forExport == "Why did Kennan write the Long Telegram?")
        #expect(!sentence.needsAttention)

        sentence.edited = "US policy toward the Soviet Union, 1946-1947"
        #expect(sentence.forExport == "US policy toward the Soviet Union, 1946-1947", """
            The export used the stored research question over the researcher's edit. The stored \
            value is an internal note; the export is an email to NARA staff.
            """)

        let empty = TripPacketTopicSentence.seeded(from: nil)
        #expect(empty.forExport == TripPacketTopicSentence.placeholder)
        #expect(empty.needsAttention, """
            A project with no research question must get the placeholder and be flagged — an \
            inquiry with a blank topic is the one thing A3 says never to send.
            """)
        #expect(TripPacketTopicSentence.seeded(from: "   ").forExport == TripPacketTopicSentence.placeholder,
                "whitespace is not a topic")
    }

    /// The triage reaches the assembled model, and a resolved series' facility is NARA's own.
    @Test("Triage assembles into the packet")
    func triageAssembles() {
        let model = TripPacketModel.build(
            groups: [group("s", category: .lotFile, repository: nil, naId: "123", count: 5)],
            documentYears: [1948, 1972], unresolvedLotCount: 4, unresolvedDocumentCount: 9,
            researchQuestion: nil,
            facts: { _ in SeriesFactsIndex.Facts(
                accessStatus: "Restricted - Fully", accessRestrictions: ["FOIA (b)(1) National Security"],
                useStatus: nil, useRestrictions: [], extent: nil,
                referenceUnit: "National Archives at College Park - Textual Reference",
                findingAids: [], years: nil) },
            claimants: { _ in nil })
        #expect(model.triage.rows.first?.severity == .fully)
        #expect(model.triage.unresolvedDocumentCount == 9)
        #expect(model.groups[0].facility == .derived(facility: "National Archives at College Park"))
    }

    // MARK: - Target assembly (Archive Visits Phase 1)

    /// Both channels land under one claim-free key: a unit drawn from AND pointed at becomes
    /// ONE target with the two claims itemized inside it, never merged into one count.
    @Test("A unit cited in both channels becomes one target with claims kept apart")
    func channelsMergeUnderOneKey() {
        let seeding = TripPacketModel.RefSeeding(
            volumeId: "v9", documentId: "d9", citation: "FRUS 1950 I, Document 9",
            footnoteNumber: 2, rawText: "Not printed. (Lot 62 D 1, CF 1)", inherited: false)
        let model = TripPacketModel.build(
            groups: [group("lot|62D1", category: .lotFile, repository: nil, naId: "123",
                           count: 3, lotAsPrinted: "62 D 1")],
            documentYears: [1950], unresolvedLotCount: 0, unresolvedDocumentCount: 0,
            researchQuestion: nil, facts: { _ in nil },
            references: [(key: "lot|62D1", form: .lotFile, label: "Lot 62 D 1",
                          repository: nil, lotAsPrinted: "62 D 1", seedings: [seeding])],
            claimants: { _ in nil })
        #expect(model.targets.count == 1, "the shared key must merge, not duplicate")
        let target = model.targets[0]
        #expect(target.drawnFrom.count == 3)
        #expect(target.pointedAt == [seeding])
        #expect(target.form == .lotFile)
    }

    /// A pointed-at-only unit mints its own target — the "beyond FRUS" case the channel
    /// exists for — with an empty drawn-from list, never a fabricated one.
    @Test("A pointed-at-only unit mints a target of its own")
    func pointedAtOnlyMintsTarget() {
        let seeding = TripPacketModel.RefSeeding(
            volumeId: "v9", documentId: "d9", citation: "FRUS 1950 I, Document 9",
            footnoteNumber: 1, rawText: "Truman Library, PSF, not printed.", inherited: false)
        let model = TripPacketModel.build(
            groups: [], documentYears: [], unresolvedLotCount: 0, unresolvedDocumentCount: 0,
            researchQuestion: nil, facts: { _ in nil },
            references: [(key: "coll|Truman Library|PSF", form: .collection,
                          label: "Truman Library, PSF", repository: "Truman Library",
                          lotAsPrinted: nil, seedings: [seeding])],
            claimants: { _ in nil })
        #expect(model.targets.count == 1)
        #expect(model.targets[0].drawnFrom.isEmpty)
        #expect(model.targets[0].pointedAt == [seeding])
        #expect(model.targets[0].form == .collection)
        #expect(model.targets[0].facts?.id == "Truman Library", """
            A pointed-at library target must reach its curated row the same way a drawn-from \
            group does — D11's ask needs the link beside it.
            """)
    }

    /// The claimant-aware restriction rule (§3a): worst COVERED status with its series named
    /// and the unmeasured counted; divided-with-nothing-measured is a line of its own; a lot
    /// with one claimant and no measurement gets silence, not a guess.
    @Test("The restriction line states the worst covered status at claimant grain")
    func restrictionRuleIsClaimantAware() {
        let claimants: [LotClaimant] = [
            LotClaimant(naId: "1", title: "Open Series", recordGroup: "59",
                        hmsMlrEntryNumbers: nil, dateRange: nil, evidence: "controlNumber"),
            LotClaimant(naId: "2", title: "Closed Series", recordGroup: "59",
                        hmsMlrEntryNumbers: nil, dateRange: nil, evidence: "controlNumber"),
            LotClaimant(naId: "3", title: "Unmeasured Series", recordGroup: "59",
                        hmsMlrEntryNumbers: nil, dateRange: nil, evidence: "controlNumber"),
        ]
        let facts: (String) -> SeriesFactsIndex.Facts? = { naId in
            let status = ["1": "Unrestricted", "2": "Restricted - Fully"][naId]
            return status.map { SeriesFactsIndex.Facts(
                accessStatus: $0, accessRestrictions: [], useStatus: nil, useRestrictions: [],
                extent: nil, referenceUnit: nil, findingAids: [], years: nil) }
        }
        let divided = TripPacketModel.restriction(
            form: .lotFile, resolution: nil, lotAsPrinted: "60 D 1",
            facts: facts, claimants: { _ in claimants })
        #expect(divided?.worstCoveredStatus == "Restricted - Fully",
                "the worst MEASURED status leads, whatever order the claimants arrive in")
        #expect(divided?.claimantSeriesTitle == "Closed Series",
                "the status must name the series it belongs to — it is not the lot's status")
        #expect(divided?.claimantCount == 3)
        #expect(divided?.unmeasuredClaimantCount == 1)
        #expect(divided?.isDivided == true)

        let nothingMeasured = TripPacketModel.restriction(
            form: .lotFile, resolution: nil, lotAsPrinted: "60 D 2",
            facts: { _ in nil }, claimants: { _ in Array(claimants.prefix(2)) })
        #expect(nothingMeasured?.worstCoveredStatus == "", """
            A divided lot with nothing measured is itself worth a line — "several series, \
            none measured" is the question the inquiry carries.
            """)
        #expect(nothingMeasured?.worstSeverity == .unknown)

        let single = TripPacketModel.restriction(
            form: .lotFile, resolution: nil, lotAsPrinted: "60 D 3",
            facts: { _ in nil }, claimants: { _ in [claimants[2]] })
        #expect(single == nil, "one claimant, nothing measured: silence beats a guess")
    }

    /// Targets sort facility-first, label-second — stable and deterministic, since Phase 1
    /// has no user tiers yet.
    @Test("Targets sort by facility, then label")
    func targetsSortByFacilityThenLabel() {
        let model = TripPacketModel.build(
            groups: [
                group("truman", category: .presidentialLibrary, repository: "Truman Library"),
                group("lot|b", category: .lotFile, repository: nil),
                group("lot|a", category: .lotFile, repository: nil),
            ],
            documentYears: [], unresolvedLotCount: 0, unresolvedDocumentCount: 0,
            researchQuestion: nil, facts: { _ in nil }, claimants: { _ in nil })
        #expect(model.targets.map(\.key) == ["lot|a", "lot|b", "truman"], """
            The placeable lots sort by label under their shared facility; the unplaceable \
            library sorts last (no facility heading).
            """)
    }

    /// The pre-1946 flag: set only when every KNOWN year predates 1946 and at least one is
    /// known — the coverage report's licence for the filing-practice sentence.
    @Test("seededSpanPredates1946 requires known, uniformly pre-1946 years")
    func preWarFlagRules() {
        func build(_ years: [Int?]) -> Bool {
            TripPacketModel.build(
                groups: [], documentYears: years, unresolvedLotCount: 0,
                unresolvedDocumentCount: 0, researchQuestion: nil,
                facts: { _ in nil }, claimants: { _ in nil }).seededSpanPredates1946
        }
        #expect(build([1914, 1915, nil]))
        #expect(!build([1914, 1948]), "one post-war year defeats the claim")
        #expect(!build([nil, nil]), "no known year is no evidence of a pre-war span")
        #expect(!build([]))
    }

    // MARK: - The collection seed rule (Archive Visits Phase 0)

    /// `TripPacketSeed.staticSeedDocuments` is the one place the three collection surfaces
    /// derive a packet's reading list, so its rules are pinned here: excerpts count as the
    /// documents they quote, duplicates collapse first-occurrence-wins, order is `sortOrder`,
    /// and non-document kinds contribute nothing.
    @Test("The static seed takes documents and excerpts, deduplicated, in sort order")
    @MainActor
    func staticSeedRule() throws {
        let container = try ModelContainer.makeTestContainer()
        let context = container.mainContext
        let collection = Collection(name: "Seed fixture")
        context.insert(collection)

        // Deliberately out of creation order so sortOrder is the only thing that can produce
        // the expected sequence.
        let excerpt = CollectionEntry(collectionId: collection.id, documentId: "d2",
                                      volumeId: "v1", sortOrder: 0)
        excerpt.entryKind = .excerpt
        let doc = CollectionEntry(collectionId: collection.id, documentId: "d1",
                                  volumeId: "v1", sortOrder: 1)
        let duplicate = CollectionEntry(collectionId: collection.id, documentId: "d2",
                                        volumeId: "v1", sortOrder: 2)
        let heading = CollectionEntry(collectionId: collection.id, documentId: "",
                                      volumeId: "", sortOrder: 3)
        heading.entryKind = .heading
        let emptyExcerpt = CollectionEntry(collectionId: collection.id, documentId: "",
                                           volumeId: "", sortOrder: 4)
        emptyExcerpt.entryKind = .excerpt
        for e in [doc, excerpt, duplicate, heading, emptyExcerpt] { context.insert(e) }
        try context.save()

        let seeded = TripPacketSeed.staticSeedDocuments(
            from: [doc, excerpt, duplicate, heading, emptyExcerpt])
        #expect(seeded.map(\.documentId) == ["d2", "d1"], """
            Expected the excerpt's document first (sortOrder 0), the document second, the \
            duplicate collapsed, and the heading and id-less excerpt contributing nothing — \
            got \(seeded).
            """)
        #expect(seeded.map(\.volumeId) == ["v1", "v1"])
    }
}
