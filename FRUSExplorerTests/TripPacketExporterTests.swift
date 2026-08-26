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
import CoreGraphics
@testable import FRUSExplorer

// MARK: - TripPacketExporterTests

/// Pins the Archive Visit packet exporter — the narrowed (a)/(b)/(c) artifact of
/// Archive-Visit-Plan-Design §3.
///
/// The oracle fixture spans both channels and every rendering rule that has one: a decimal
/// CLASS target (30 documents), a resolved lot cited BOTH ways (drawn from 8 documents,
/// pointed at by 2 footnotes — one inherited), an unresolved drawn-from lot, an unresolved
/// pointed-at-only lot, and a presidential-library collection the packet cannot place. The
/// resolved lot is DIVIDED (two claimant series, one unmeasured), and one seeded document
/// carries a digitized substitute. **A packet claim with no source in the design is a
/// defect**, and most tests below walk one rule each.
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-2
///   1.1 — Archive Visits Phase 0: chapter 3's roster caps and the edited topic sentence
///   2.0 — Archive Visits Phase 1: rewritten for the narrowed artifact — the chapter tests
///          left with their chapters (ch1/ch3/ch7 dropped, ch4/ch5 folded); new coverage for
///          target minting, the §3d claims separation, per-seeding substitute markers, the
///          claimant-aware access line, the divided-lot inquiry question, repository scoping,
///          and the opt-in citation appendix with its fixed Example-8 gate
@Suite("Trip packet exporter (Archive Visits Phase 1)")
struct TripPacketExporterTests {

    /// `n` seeding rows for a fixture target.
    static func refs(_ n: Int, volume: String = "frus1948v02",
                     designation: (Int) -> String? = { _ in nil },
                     note: String = "A source note.") -> [TripPacketModel.Group.DocumentRef] {
        (1...n).map { i in
            .init(volumeId: volume, documentId: "d\(i)",
                  citation: "FRUS 1948 II, Document \(i)",
                  fileDesignation: designation(i), sourceNote: note)
        }
    }

    /// The resolved lot's resolution — the fields the builder used to discard.
    static let lotResolution = ArchivalResolution(
        naId: "555", catalogURL: "https://catalog.archives.gov/id/555",
        title: "Records of the Policy Planning Staff, 1947-1953",
        recordGroup: "59", matchType: "lot",
        hmsMlrEntryNumbers: ["A1 558"], levelOfDescription: "series",
        seriesNaId: nil, seriesTitle: nil, seriesHmsMlrEntryNumbers: nil)

    /// The divided lot's two claimants: the resolved series (measured Restricted - Partly
    /// through `facts`) and a second series with no measured status.
    static func claimants(forRawLot lot: String) -> [LotClaimant]? {
        guard lot == "64 D 199" else { return nil }
        return [
            LotClaimant(naId: "555", title: "Records of the Policy Planning Staff, 1947-1953",
                        recordGroup: "59", hmsMlrEntryNumbers: ["A1 558"],
                        dateRange: "1947-1953", evidence: "controlNumber"),
            LotClaimant(naId: "777", title: "Policy Planning Council Subject Files",
                        recordGroup: "59", hmsMlrEntryNumbers: nil,
                        dateRange: nil, evidence: "consolidationNote"),
        ]
    }

    /// The substitutes fixture: one filmed roll claiming document d3, injected whole so the
    /// per-seeding marker is driven without index fixtures (`MandatorySubstitutesTests` pins
    /// the matching itself).
    static let substitutesFixture = MandatorySubstitutes(
        rows: [.init(naId: "888", title: "M1284 Roll 5", route: .digitizedRange,
                     objectCount: 1200, documentCount: 1, isSoleClaimant: true)],
        documentsTested: 30,
        documentsWithSubstitute: 1,
        partiallyDigitizedCount: 2,
        matchesByDocument: ["frus1948v02/d3": ["888"]])

    /// The design's oracle fixture — see the type comment.
    private func oracleModel(researchQuestion: String? = "US policy toward Berlin, 1948")
        -> TripPacketModel {
        TripPacketModel.build(
            groups: [
                (key: "class|762.00", label: "Central Decimal File 762.00",
                 category: .centralDecimalFile, repository: nil, lotAsPrinted: nil,
                 resolution: nil,
                 documents: Self.refs(30, designation: { "762.00/2-\($0)48" },
                                      note: "Department of State, Central Files, 762.00")),
                // Each group seeds from its own volume: a document has ONE source note, so
                // reusing ids across groups would make the header's distinct-document count
                // dedupe documents that are supposed to be different.
                (key: "lot|64D199", label: "Lot 64 D 199", category: .lotFile,
                 repository: nil, lotAsPrinted: "64 D 199", resolution: Self.lotResolution,
                 documents: Self.refs(8, volume: "frus1948v03",
                                      designation: { _ in "Germany 1948" },
                                      note: "Department of State, Lot 64 D 199, Germany 1948")),
                (key: "lot|71D483", label: "Lot 71 D 483", category: .lotFile,
                 repository: nil, lotAsPrinted: "71 D 483", resolution: nil,
                 documents: Self.refs(3, volume: "frus1948v04",
                                      note: "Department of State, Lot 71 D 483, Box 2")),
                (key: "coll|Truman Library|President's Secretary's Files",
                 label: "Truman Library, President's Secretary's Files",
                 category: .presidentialLibrary, repository: "Truman Library",
                 lotAsPrinted: nil, resolution: nil,
                 documents: Self.refs(12, volume: "frus1948v05")),
            ],
            documentYears: [1948, 1948, 1972],
            unresolvedLotCount: 1,
            unresolvedDocumentCount: 4,
            researchQuestion: researchQuestion,
            facts: { naId in
                naId == "555" ? SeriesFactsIndex.Facts(
                    accessStatus: "Restricted - Partly",
                    accessRestrictions: ["FOIA (b)(1) National Security"],
                    useStatus: nil, useRestrictions: [], extent: nil,
                    referenceUnit: "National Archives at College Park - Textual Reference",
                    findingAids: [], years: "1947-1953") : nil
            },
            substitutes: { _ in Self.substitutesFixture },
            references: [
                // The both-ways case: the resolved lot is also cited by two footnotes.
                (key: "lot|64D199", form: .lotFile, label: "Lot 64 D 199",
                 repository: "Department of State", lotAsPrinted: "64 D 199",
                 seedings: [
                    .init(volumeId: "frus1948v02", documentId: "d40",
                          citation: "FRUS 1948 II, Document 40", footnoteNumber: 3,
                          rawText: "Not printed. (Department of State, Lot 64 D 199, CF 1)",
                          inherited: false),
                    .init(volumeId: "frus1948v02", documentId: "d41",
                          citation: "FRUS 1948 II, Document 41", footnoteNumber: 2,
                          rawText: "Ibid., CF 2, not printed.",
                          inherited: true),
                 ]),
                // Pointed-at only, unresolved — the "beyond FRUS" case the channel exists for.
                (key: "lot|99Z999", form: .lotFile, label: "Lot 99 Z 999",
                 repository: "Department of State", lotAsPrinted: "99 Z 999",
                 seedings: [
                    .init(volumeId: "frus1948v02", documentId: "d42",
                          citation: "FRUS 1948 II, Document 42", footnoteNumber: 5,
                          rawText: "Memorandum of conversation, in Department of State, "
                              + "Lot 99 Z 999, Box 4; not printed.",
                          inherited: false),
                 ]),
            ],
            referenceCoverage: .init(documentsWithReferences: 2, documentsScanned: 53),
            claimants: Self.claimants(forRawLot:))
    }

    private func exporter(model: TripPacketModel? = nil) -> TripPacketExporter {
        TripPacketExporter(model: model ?? oracleModel(), projectName: "Berlin 1948")
    }

    // MARK: - The prohibition

    /// **The test that matters most.** The appointment policy is unconfirmed, so the packet must
    /// ask rather than assert — and must never print the unverified value.
    @Test("An unconfirmed fact never reaches the page")
    func unconfirmedFactsNeverPrint() {
        let text = exporter().export()
        // Read from the SHIPPING row rather than typed as a literal. A hardcoded string goes
        // vacuously green the moment the curated value is reworded — which is exactly what
        // happened when D15 rewrote this policy, and the old assertion would have kept passing
        // while proving nothing.
        let unverified = RepositoryFactTable.nacp.appointmentPolicy.value
        #expect(!unverified.isEmpty, "fixture drift: the row carries no unverified policy to hide")
        #expect(!text.contains(unverified), """
            The packet printed the unverified appointment policy. D7: an unverified fact is \
            omitted, never printed undated — the exporter must read `printable`, not `value`.
            """)
        #expect(text.contains("Appointment policy changes"), """
            With the policy unconfirmed the packet must still tell the researcher to check. \
            Silence would read as "no appointment needed".
            """)
        // Every library row ships an empty, unverified address and email; none may reach the page.
        for row in RepositoryFactTable.presidentialLibraries {
            #expect(row.address.printable == nil)
            #expect(row.inquiryEmail.printable == nil)
        }
    }

    /// The two facts the owner confirmed on 2026-08-22 do print — A2's one-address rule is the
    /// inquiry mechanic and a draft needs a recipient.
    @Test("Confirmed facts do print, and reach the inquiry draft")
    func confirmedFactsPrint() {
        let text = exporter().export()
        #expect(text.contains("Archives2reference@nara.gov"))
        #expect(text.contains("8601 Adelphi Road"))
        #expect(text.contains("College Park, MD 20740"))
    }

    /// A library has no curated row, so it appears under the confirm-prompt — never with an
    /// invented address (D11).
    @Test("A library gets A12's ask, not a drafted letter")
    func libraryGetsConfirmPromptNotALetter() {
        let text = exporter().export()
        #expect(text.contains("Confirm before you travel"))
        #expect(text.contains("Truman Library"))
        #expect(text.contains("confirm the materials are at that location"), """
            The confirm-prompt must carry A12's actual ask. At collection grain the packet can name \
            neither series nor NAID, so a drafted letter would imply a precision the data lacks.
            """)
    }

    // MARK: - Target minting and the §3d claims separation

    /// The header's counts are claim-separated, never summed — 41 drawn documents and 3
    /// footnotes stay two numbers.
    @Test("The header counts drawn documents and footnotes separately")
    func headerCountsAreClaimSeparated() {
        let text = exporter().export()
        #expect(text.contains("4 research targets across 1 repository · "
                              + "drawn from 41 documents · cited by 3 footnotes"), """
            The rendered header must carry both channels as separate counts — a single total \
            would erase the #783 separation at the first line a reader sees.
            """)
    }

    /// The both-ways unit renders as ONE target row with both claims itemized inside it,
    /// its counts line reading "drawn from 8 documents · cited by 2 footnotes" — never "10".
    @Test("A unit cited both ways is one target with claims itemized, never summed")
    func bothWaysTargetItemizesClaims() {
        let text = exporter().export()
        let sections = text.components(separatedBy: "### Lot 64 D 199")
        #expect(sections.count >= 2, "the merged target must render")
        let row = sections[1].components(separatedBy: "### ")[0]
        #expect(row.contains("drawn from 8 documents · cited by 2 footnotes"))
        #expect(!row.contains("(10 "), "counts must never sum across claims (§3d)")
        #expect(row.contains("Published from this file:"))
        #expect(row.contains("Cited in footnotes, not printed"))
    }

    /// A pointed-at-only target exists even though FRUS printed nothing from it — with the
    /// claim stated on its counts line and no drawn-from list.
    @Test("A pointed-at-only unit becomes its own target")
    func pointedAtOnlyTargetRenders() {
        let text = exporter().export()
        let sections = text.components(separatedBy: "### Lot 99 Z 999")
        #expect(sections.count == 2, "the pointed-at-only lot must mint exactly one target")
        let row = sections[1].components(separatedBy: "### ")[0]
        #expect(row.contains("cited by 1 footnote"))
        #expect(!row.contains("drawn from"), "nothing was published from this unit")
        #expect(!row.contains("Published from this file:"))
    }

    // MARK: - Seedings

    /// Every drawn-from seeding carries its FRUS link and its cited file designation — the
    /// old pull worksheet's one unique payload, moved to the row it belonged on.
    @Test("Drawn-from seedings carry the document link and the file designation")
    func drawnFromSeedingsCarryLinkAndDesignation() {
        let text = exporter().export()
        #expect(text.contains("FRUS 1948 II, Document 3 — file 762.00/2-348"))
        #expect(text.contains("https://history.state.gov/historicaldocuments/frus1948v02/d3"))
    }

    /// A pointed-at seeding quotes the footnote VERBATIM with its anchor, and an inherited
    /// row says so — an `Ibid.` is the previous footnote's assertion, not this one's.
    @Test("Pointed-at seedings quote the footnote verbatim, and disclose inheritance")
    func pointedAtSeedingsQuoteVerbatim() {
        let text = exporter().export()
        #expect(text.contains("FRUS 1948 II, Document 40, footnote 3"))
        #expect(text.contains(
            "Cited as: Not printed. (Department of State, Lot 64 D 199, CF 1)"))
        #expect(text.contains("Cited as: Ibid., CF 2, not printed."))
        #expect(text.contains("inherited from the preceding footnote's citation"), """
            The inherited row must say the unit came from the previous note — a reader \
            checking the printed page will not find these words in footnote 2.
            """)
    }

    /// A seeding list past 8 rows discloses its exact remainder — the packet's truncation
    /// grammar, applied at the seeding grain (the design's answer to the old roster caps).
    @Test("A seeding list past the cap discloses its exact remainder")
    func seedingListsCapWithDisclosedRemainder() {
        let text = exporter().export()
        #expect(text.contains("…and 22 more documents — the app carries the full list."),
                "the 30-document class target must print 8 seedings and the exact remainder")
        #expect(!text.contains("Document 9 — file"),
                "rows past the cap must not print")
    }

    /// The chapter-4 fold: a seeding whose citation landed in a digitized unit says so on
    /// its own line, at the document grain the match actually has.
    @Test("A digitized document's seeding line carries the substitute marker")
    func substituteMarkerRidesTheSeeding() {
        let text = exporter().export()
        #expect(text.contains("Digitized or filmed — use M1284 Roll 5 (NAID 888) "
                              + "instead of pulling."))
        // The marker is per-document: the un-matched neighbour rows must not carry it.
        let markers = text.components(separatedBy: "Digitized or filmed — use").count - 1
        #expect(markers == 1, "exactly one seeded document matched the fixture substitute")
    }

    // MARK: - The claimant-aware access line (§3a)

    /// A divided lot's line states the worst COVERED status, names its series, and counts
    /// the unmeasured — one line, never a badge, never one claimant's status as the lot's.
    @Test("A divided lot's access line is claimant-aware")
    func dividedLotAccessLineIsClaimantAware() {
        let text = exporter().export()
        #expect(text.contains("Access: Restricted - Partly — the status of Records of the "
                              + "Policy Planning Staff, 1947-1953, one of 2 series claiming "
                              + "this lot; 1 claimant carries no recorded status."))
    }

    /// The divided lot routes into the inquiry AS A QUESTION — which is what it is.
    @Test("A divided lot becomes an inquiry question")
    func dividedLotBecomesInquiryQuestion() {
        let text = exporter().export()
        #expect(text.contains("Questions:"))
        #expect(text.contains("NARA's catalog lists 2 series claiming Lot 64 D 199, 1 with "
                              + "no recorded access status — which should I consult"))
    }

    /// §3a's one crib fold: the no-box rule prints on central-file targets only.
    @Test("The no-box line prints on the central-file target only")
    func noBoxLineOnCentralTargetsOnly() {
        let text = exporter().export()
        let occurrences = text.components(separatedBy: "No box numbers, on purpose").count - 1
        #expect(occurrences == 1, """
            The oracle holds one central-file target; the rule must print there and nowhere \
            else — on a lot target it would be false (lots pull by box).
            """)
        let classSection = text.components(separatedBy: "### Central Decimal File 762.00")[1]
            .components(separatedBy: "### ")[0]
        #expect(classSection.contains("No box numbers, on purpose"))
    }

    // MARK: - The inquiry (deliverable c)

    /// A3 / A2: one draft per facility, and the topic sentence carried.
    @Test("The inquiry carries the project's topic and one heading per facility")
    func inquiryIsPerFacilityAndCarriesTheTopic() {
        let text = exporter().export()
        #expect(text.contains("Topic: US policy toward Berlin, 1948"))
        let inquiry = text.components(separatedBy: "## Advance inquiry")[1]
            .components(separatedBy: "## What this packet covers")[0]
        #expect(inquiry.components(separatedBy: "### National Archives at College Park").count == 2, """
            Expected exactly one College Park heading in the inquiry chapter. A2 requires sending \
            to only ONE address, so a facility must not be drafted twice.
            """)
    }

    /// D8: a project with no research question gets the instruction, not an empty paragraph.
    @Test("A project with no research question gets the placeholder")
    func missingResearchQuestionGetsPlaceholder() {
        let text = exporter(model: oracleModel(researchQuestion: nil)).export()
        #expect(text.contains("Describe your research topic"), """
            An inquiry with a blank topic is the one thing A3 says never to send.
            """)
    }

    /// A3: the inquiry identifies resolved records by NARA's own four fields, with the link.
    @Test("The inquiry's records of interest carry A3's four-field line")
    func inquiryCarriesRecordsLine() {
        let text = exporter().export()
        let inquiry = text.components(separatedBy: "## Advance inquiry")[1]
            .components(separatedBy: "## What this packet covers")[0]
        #expect(inquiry.contains("RG 59 · Entry A1 558 · Records of the Policy Planning Staff, "
                                 + "1947-1953 · NAID 555 · 1947-1953"), """
            The effective-inquiry spec asks records be identified by RG + entry + series \
            title, with NAID links — the fields the builder used to compute and discard.
            """)
        #expect(inquiry.contains("https://catalog.archives.gov/id/555"))
    }

    /// A5: an unresolved lot's source notes appear VERBATIM, each with its FRUS citation,
    /// inside the inquiry — the advance route for exactly the citations NARA's FAQ says
    /// cannot be resolved "while researchers wait in a research room".
    @Test("Unresolved drawn-from citations appear verbatim as help-me-locate items")
    func unresolvedNotesQuotedInInquiry() {
        let text = exporter().export()
        let inquiry = text.components(separatedBy: "## Advance inquiry")[1]
            .components(separatedBy: "## What this packet covers")[0]
        #expect(inquiry.contains("Please help me locate"))
        #expect(inquiry.contains("Lot 71 D 483"))
        #expect(inquiry.contains("Cited as: Department of State, Lot 71 D 483, Box 2"),
                "the note must be quoted verbatim — staff match on the printed designation")
        #expect(inquiry.contains("FRUS 1948 II, Document 1"), "each note carries its FRUS citation")
        #expect(inquiry.contains("did not carry over"), "the FAQ's own explanation frames the ask")
        // The RESOLVED lot is not a locate request — it resolved.
        let locate = inquiry.components(separatedBy: "Please help me locate")[1]
        #expect(!locate.contains("- Lot 64 D 199"))
    }

    /// The pointed-at channel's help-me-locate: the same A5 rule, with the claim stated —
    /// "the editors cite it" is a different warrant than "the document came from it".
    @Test("Unresolved pointed-at citations get their own help-me-locate list, claim stated")
    func unresolvedPointedAtQuotedInInquiry() {
        let text = exporter().export()
        let inquiry = text.components(separatedBy: "## Advance inquiry")[1]
            .components(separatedBy: "## What this packet covers")[0]
        #expect(inquiry.contains("cite the following files in footnotes without printing"))
        #expect(inquiry.contains("Lot 99 Z 999"))
        #expect(inquiry.contains("Cited as: Memorandum of conversation, in Department of "
                                 + "State, Lot 99 Z 999, Box 4; not printed."))
    }

    // MARK: - The coverage report (§3c)

    /// The report prints the refs channel's reach in true denominators, and keeps a thin
    /// channel reading as sparse data.
    @Test("The coverage report states the refs channel's reach")
    func coverageReportStatesRefsReach() {
        let text = exporter().export()
        #expect(text.contains("## What this packet covers"))
        #expect(text.contains("Footnote references were scanned on 53 documents; 2 carry"))
        #expect(text.contains("a short list is expected and not a failure to look"))
    }

    /// An empty refs channel over a pre-1946 reading list is the filing practice, not a gap
    /// — and the report says which.
    @Test("An empty refs channel on a pre-1946 list gets the filing-practice sentence")
    func preWarEmptyRefsGetFilingPracticeSentence() {
        let model = TripPacketModel.build(
            groups: [
                (key: "class|763.72", label: "Central Decimal File 763.72",
                 category: .centralDecimalFile, repository: nil, lotAsPrinted: nil,
                 resolution: nil,
                 documents: Self.refs(5, note: "File No. 763.72/1234")),
            ],
            documentYears: [1914, 1915, 1916],
            unresolvedLotCount: 0, unresolvedDocumentCount: 0,
            researchQuestion: nil, facts: { _ in nil },
            referenceCoverage: .init(documentsWithReferences: 0, documentsScanned: 5),
            claimants: { _ in nil })
        let text = exporter(model: model).export()
        #expect(text.contains("that is the filing practice, not a gap"), """
            #784 measured the pre-war decades at 0/0/2 references at the shipped scope: lot \
            files and libraries are post-war practice, and the report owes that sentence \
            wherever the emptiness would otherwise read as a failed scan.
            """)
    }

    /// The folded chapters' homeless facts all land in the report: the substitute
    /// denominators, the layered warning, the citation rule, the restriction aggregate, and
    /// the unresolved remainder.
    @Test("The coverage report carries every homeless fact")
    func coverageReportCarriesHomelessFacts() {
        let text = exporter().export()
        let report = text.components(separatedBy: "## What this packet covers")[1]
        #expect(report.contains("Checked 30 documents that cite a file number; 1 lands"))
        #expect(report.contains("partly digitized, but not the part they name"))
        #expect(report.contains("the microfilm publication number"))
        #expect(report.contains("1 of 1 cited series carries a restriction"))
        #expect(report.contains("1 claimant series carries no recorded access status — "
                                + "absence of a ruling, not openness"))
        #expect(report.contains("4 documents cite no series this app could resolve"), """
            The 4 unresolved documents must be disclosed. A report silently covering part of \
            a reading list reads as a clean bill of health for the rest.
            """)
    }

    // MARK: - Scoping (the export-scoping amendment)

    /// A scoped export is that repository's self-contained slice — and the coverage report
    /// still describes the whole plan, because the honesty block is not divisible.
    @Test("A repository-scoped export filters sections but keeps the whole-plan report")
    func scopedExportKeepsWholePlanReport() {
        var scoped = exporter()
        scoped.facilityScope = "National Archives at College Park"
        let text = scoped.export()
        #expect(text.contains("Scoped to National Archives at College Park"))
        #expect(text.contains("## What this packet covers"))
        #expect(text.contains("4 documents cite no series"), "the report stays plan-level")
        #expect(!text.contains("### Confirm before you travel"),
                "the unplaced set belongs to the full-plan export")
        #expect(text.contains("listed under \"Confirm before you travel\" in the full-plan "
                              + "export"),
                "the scoped report must still point at the unplaced targets")
    }

    // MARK: - The citation appendix (§3a: opt-in, default off)

    /// The appendix does not print unless asked for.
    @Test("The citation crib is absent by default")
    func cribAbsentByDefault() {
        let text = exporter().export()
        #expect(!text.contains("Citing what you find"))
        #expect(!text.contains("governed by your publisher"))
    }

    /// With the appendix on: attribution not prescription, the deposited examples selected
    /// by the packet's own designations, pre-filled from its own fields — and the fixed
    /// Example-8 gate (any non-central target, not just lots).
    @Test("The opt-in crib attributes, quotes the deposited examples, and pre-fills")
    func cribAttributesWhenEnabled() {
        var withCrib = exporter()
        withCrib.includeCitationCrib = true
        let text = withCrib.export()
        #expect(text.contains("governed by your publisher"))
        #expect(text.contains("reports that guidance as NARA's rather than prescribing it"))
        // The oracle's decimal designations are date-form, so Example 5 is the match.
        #expect(text.contains("Example 5, telegram with date numbering"))
        #expect(text.contains("611.93/12-854"), "NARA's example quoted verbatim, not paraphrased")
        #expect(text.contains("file 762.00/2-148"), "the packet's own file number is substituted")
        #expect(text.contains("⟨Sender⟩"), "what is read off the document stays a placeholder")
        // The lot example, pre-filled from the resolved lot's own fields.
        #expect(text.contains("also serves as a model"))
        #expect(text.contains("Entry P-5"), "Example 8 quoted verbatim")
        #expect(text.contains("Records of the Policy Planning Staff, 1947-1953, Entry A1 558, RG 59"),
                "the resolved lot's series title, entry and RG pre-fill NARA's form")
        // No subject-numeric designation in the oracle, so Example 7 must NOT print — an
        // example for a series type the packet does not hold would be noise wearing help's
        // clothes.
        #expect(!text.contains("Subject-Numeric File"), "no SNF designations in this packet")
    }

    /// The Example-8 gate defect, fixed: a packet holding ONLY a library target still gets
    /// the example NARA's own note extends to "all other records entries".
    @Test("Example 8 prints for non-central targets that are not lots")
    func example8GateCoversCollections() {
        let model = TripPacketModel.build(
            groups: [
                (key: "coll|Truman Library|PSF", label: "Truman Library, PSF",
                 category: .presidentialLibrary, repository: "Truman Library",
                 lotAsPrinted: nil, resolution: nil, documents: Self.refs(2)),
            ],
            documentYears: [1950], unresolvedLotCount: 0, unresolvedDocumentCount: 0,
            researchQuestion: nil, facts: { _ in nil }, claimants: { _ in nil })
        var withCrib = exporter(model: model)
        withCrib.includeCitationCrib = true
        let text = withCrib.export()
        #expect(text.contains("also serves as a model"), """
            The old gate was `category == .lotFile`, which skipped collections and raw \
            targets NARA's note plainly covers (§3a named this a live defect to fix).
            """)
    }

    // MARK: - Rendering hygiene

    /// The PDF share renders the exporter's own string — a readable multi-page PDF, driven
    /// through the real renderer and read back through CGPDFDocument.
    @Test("The PDF renderer paginates the packet into a readable PDF")
    func pdfRendersAndReadsBack() throws {
        let text = exporter().export()
        let url = try #require(TripPacketPDFRenderer.render(packet: text, title: "Berlin/1948"))
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(!url.lastPathComponent.contains("/") || url.lastPathComponent.hasSuffix(".pdf"))
        let document = try #require(CGPDFDocument(url as CFURL),
                                    "the produced file must be a PDF CoreGraphics can open")
        #expect(document.numberOfPages >= 1)
    }

    /// A packet a researcher emails to archivists should not say "1 claimants". Found by
    /// reading the output.
    @Test("Counted sentences agree in number")
    func countedSentencesAgree() {
        let text = exporter().export()
        #expect(text.contains("1 claimant carries no recorded status"))
        #expect(text.contains("cited by 1 footnote)"))
        for wrong in ["1 claimants", "1 footnotes)", " 1 documents", "document(s)"] {
            #expect(!text.contains(wrong), "the packet printed \"\(wrong)\"")
        }
    }

    /// Every section has a defined empty behaviour, and none of them is silence.
    @Test("An empty packet still says what it could not do")
    func emptyPacketStillSpeaks() {
        let empty = TripPacketModel.build(
            groups: [], documentYears: [], unresolvedLotCount: 0, unresolvedDocumentCount: 0,
            researchQuestion: nil, facts: { _ in nil }, claimants: { _ in nil })
        let text = exporter(model: empty).export()
        #expect(text.contains("0 research targets"))
        #expect(text.contains("no inquiry to draft"))
        #expect(text.contains("can say nothing either way"),
                "the substitutes coverage line prints unconditionally")
        #expect(!text.isEmpty)
    }

    // MARK: - The edited topic sentence (Phase 0 — the missing writer's route)

    /// The exporter reads the EDITED value, never the stored note — the rule
    /// `TripPacketTopicSentence`'s doc comment states.
    @Test("An edited topic sentence replaces the seeded research question in the drafts")
    func editedTopicOverridesSeed() {
        var model = oracleModel(researchQuestion: "US policy toward Berlin, 1948")
        model.topicSentence.edited = "The airlift's supply arithmetic, June-December 1948."
        let text = exporter(model: model).export()
        #expect(text.contains("Topic: The airlift's supply arithmetic, June-December 1948."))
        #expect(!text.contains("Topic: US policy toward Berlin, 1948"),
                "the stored project note must never reach the draft once an edit exists")
    }
}
