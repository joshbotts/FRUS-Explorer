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

/// Pins the packet exporter (#830 T-2).
///
/// The scope doc names its own verification oracle: build the packet for a fixture spanning a
/// decimal-file citation, a lot file (one resolved, one unresolved), a presidential-library
/// collection and a post-1960 document, then walk NARA's advisories showing each is satisfied by a
/// section or consciously excluded. **A packet claim with no source in that table is a defect.**
/// That fixture is `oracleModel` below, and most of these tests walk one advisory each.
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-2
///   1.1 — Archive Visits Phase 0: chapter 3's roster caps (20/group with exact remainder,
///          the 200-row packet budget, the ≥500 elision) and the edited topic sentence's
///          route into the export — each driven through the real exporter
@Suite("Trip packet exporter (#830 T-2)")
struct TripPacketExporterTests {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    /// `n` roster rows for a fixture group.
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

    /// The scope doc's own oracle fixture.
    private func oracleModel(researchQuestion: String? = "US policy toward Berlin, 1948")
        -> TripPacketModel {
        TripPacketModel.build(
            groups: [
                (key: "cdf", label: "Central Decimal File 762.00", category: .centralDecimalFile,
                 repository: nil, resolution: nil,
                 documents: Self.refs(30, designation: { "762.00/2-\($0)48" },
                                      note: "Department of State, Central Files, 762.00")),
                (key: "lot-resolved", label: "Lot 64 D 199", category: .lotFile,
                 repository: nil, resolution: Self.lotResolution,
                 documents: Self.refs(8, designation: { _ in "Germany 1948" },
                                      note: "Department of State, Lot 64 D 199, Germany 1948")),
                (key: "lot-unresolved", label: "Lot 71 D 483", category: .lotFile,
                 repository: nil, resolution: nil,
                 documents: Self.refs(3, note: "Department of State, Lot 71 D 483, Box 2")),
                (key: "library", label: "Truman Library, President's Secretary's Files",
                 category: .presidentialLibrary, repository: "Truman Library",
                 resolution: nil, documents: Self.refs(12)),
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
            })
    }

    private func exporter(arrival: Date? = nil, model: TripPacketModel? = nil)
        -> TripPacketExporter {
        TripPacketExporter(model: model ?? oracleModel(), projectName: "Berlin 1948",
                           arrival: arrival, calendar: calendar)
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
            The packet printed the unverified appointment policy. D7: an unverified fact is \\
            omitted, never printed undated — the exporter must read `printable`, not `value`.
            """)
        #expect(text.contains("Appointment policy changes"), """
            With the policy unconfirmed the packet must still tell the researcher to check. \\
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
            The confirm-prompt must carry A12's actual ask. At collection grain the packet can name \\
            neither series nor NAID, so a drafted letter would imply a precision the data lacks.
            """)
    }

    // MARK: - D5's two forms

    @Test("Without a visit date the packet says so and prints relative deadlines")
    func relativeFormWithoutADate() {
        let text = exporter(arrival: nil).export()
        #expect(text.contains("No visit date set"))
        #expect(text.contains("before you arrive"))
    }

    @Test("With a visit date the packet prints absolute deadlines")
    func absoluteFormWithADate() throws {
        let arrival = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 1)))
        let text = exporter(arrival: arrival).export()
        #expect(text.contains("Visit: "))
        #expect(text.contains(" — by "))
    }

    // MARK: - The advisories

    /// A4: the standing sentence and both discriminating flags.
    @Test("A4's criteria all reach the checklist, quoted")
    func a4CriteriaReachTheChecklist() {
        let text = exporter().export()
        #expect(text.contains("State, Defense"), "the standing sentence quotes the FAQ's own list")
        #expect(text.contains("dated 1960 or later"), "the date flag fired on the 1972 document")
        #expect(text.contains("do not always carry over"), "the unresolved-lot flag quotes NARA")
    }

    /// A3 / A2: one draft per facility, and the topic sentence carried.
    @Test("The inquiry carries the project's topic and one heading per facility")
    func inquiryIsPerFacilityAndCarriesTheTopic() {
        let text = exporter().export()
        #expect(text.contains("Topic: US policy toward Berlin, 1948"))
        // Scoped to the INQUIRY chapter: since the worksheet is now grouped by facility the same
        // heading legitimately appears there too, and a whole-document count would fail for a
        // reason that has nothing to do with A2.
        let inquiry = text.components(separatedBy: "## Advance inquiry")[1]
            .components(separatedBy: "## Pull worksheet")[0]
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

    /// D4 / A10: restriction triage, worst first, with the unresolved remainder disclosed.
    @Test("Restriction triage reports both what is restricted and what is unknown")
    func triageReportsRestrictedAndUnknown() {
        let text = exporter().export()
        #expect(text.contains("Access restrictions"))
        #expect(text.contains("Restricted - Partly"))
        #expect(text.contains("FOIA (b)(1) National Security"))
        #expect(text.contains("cite no series this app could resolve"), """
            The 4 unresolved documents must be disclosed. A triage silently covering part of a \\
            reading list reads as a clean bill of health for the rest.
            """)
    }

    /// D13: the crib attributes rather than prescribes — and now quotes the worked examples
    /// transcribed from the deposited "Citing Foreign Affairs Records" (D17), selected by the
    /// packet's own series types and pre-filled from its own fields.
    @Test("The citation crib attributes, quotes the deposited examples, and pre-fills")
    func citationCribAttributes() {
        let text = exporter().export()
        #expect(text.contains("governed by your publisher"))
        #expect(text.contains("reports that guidance as NARA's rather than prescribing it"))
        #expect(!text.contains("have not been deposited"), """
            The governing PDF was deposited 2026-08-22 (D17); the old sentence claiming \
            otherwise was false in shipped output and must not return.
            """)
        // The oracle's decimal designations are date-form, so Example 5 is the match.
        #expect(text.contains("Example 5, telegram with date numbering"))
        #expect(text.contains("611.93/12-854"), "NARA's example quoted verbatim, not paraphrased")
        // The pre-fill substitutes only what the packet KNOWS; the rest stays a placeholder.
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
        #expect(!text.contains("Subject-Numeric File"), "no SNF citations in this packet")
    }

    /// A3: the inquiry identifies resolved records by NARA's own four fields, with the link.
    @Test("The inquiry's records of interest carry A3's four-field line")
    func inquiryCarriesRecordsLine() {
        let text = exporter().export()
        let inquiry = text.components(separatedBy: "## Advance inquiry")[1]
            .components(separatedBy: "## Pull worksheet")[0]
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
    @Test("Unresolved citations appear verbatim in the inquiry as help-me-locate items")
    func unresolvedNotesQuotedInInquiry() {
        let text = exporter().export()
        let inquiry = text.components(separatedBy: "## Advance inquiry")[1]
            .components(separatedBy: "## Pull worksheet")[0]
        #expect(inquiry.contains("Please help me locate"))
        #expect(inquiry.contains("Lot 71 D 483"))
        #expect(inquiry.contains("Cited as: Department of State, Lot 71 D 483, Box 2"),
                "the note must be quoted verbatim — staff match on the printed designation")
        #expect(inquiry.contains("FRUS 1948 II, Document 1"), "each note carries its FRUS citation")
        #expect(inquiry.contains("did not carry over"), "the FAQ's own explanation frames the ask")
        // The RESOLVED lot is not a locate request — it resolved.
        let locate = inquiry.components(separatedBy: "Please help me locate")[1]
        #expect(!locate.contains("Lot 64 D 199"))
    }

    /// Chapter 3's roster: one row per document — FRUS citation · file/folder · blank Box.
    @Test("The pull worksheet has a per-document roster under each group")
    func worksheetHasDocumentRoster() {
        let text = exporter().export()
        let worksheet = text.components(separatedBy: "## Pull worksheet")[1]
            .components(separatedBy: "## Use these instead")[0]
        #expect(worksheet.contains("| FRUS citation | File / folder | Box |"))
        #expect(worksheet.contains("| FRUS 1948 II, Document 3 | 762.00/2-348 | |"),
                "a roster row is the citation, the cited file designation, and a blank box")
        #expect(worksheet.contains("| FRUS 1948 II, Document 2 | Germany 1948 | |"),
                "a lot's folder designation is a roster designation too")
        // The series line above the roster, same composed A3 line as the inquiry.
        #expect(worksheet.contains("NAID 555"))
    }

    /// Chapter 5 names the series the resolution knew, instead of a bare NAID.
    @Test("The triage names its series")
    func triageNamesItsSeries() {
        let text = exporter().export()
        #expect(text.contains("Records of the Policy Planning Staff, 1947-1953 — NAID 555 — "
                              + "Restricted - Partly (8 documents)"), """
            A row reading "NAID 555 — Restricted - Partly" is a number the reader cannot \
            act on; the resolution carried the title all along.
            """)
    }

    /// Chapter 5 disclosed nothing when it truncated — and its dropped tail is closed
    /// series, which is precisely what the chapter exists to surface before a flight is
    /// booked. Mirror of chapter 4's disclosure rule, driven over a >limit fixture.
    @Test("A triage longer than the row limit discloses its remainder")
    func triageDisclosesTruncation() {
        let counts = Dictionary(uniqueKeysWithValues: (1...25).map { ("naid-\($0)", 1) })
        let model = TripPacketModel.build(
            groups: [], documentYears: [], unresolvedLotCount: 0, unresolvedDocumentCount: 0,
            researchQuestion: nil, facts: { _ in nil })
        let triage = RestrictionTriage.build(
            documentCountsByNaId: counts, unresolvedDocumentCount: 0,
            facts: { _ in SeriesFactsIndex.Facts(
                accessStatus: "Restricted - Fully", accessRestrictions: [],
                useStatus: nil, useRestrictions: [], extent: nil,
                referenceUnit: nil, findingAids: [], years: nil) })
        let patched = TripPacketModel(
            groups: model.groups, triage: triage, substitutes: model.substitutes,
            flags: model.flags, checklist: model.checklist, topicSentence: model.topicSentence)
        let text = exporter(model: patched).export()
        #expect(text.contains("5 further flagged series are not listed here"), """
            25 flagged series against a limit of 20 must disclose the remainder — a list \
            that silently stops reads as complete.
            """)
    }

    /// A10's second half: the withdrawal-notice / FOIA / MDR explainer.
    @Test("Chapter 5 explains the withdrawal notice and names the remedy")
    func withdrawalExplainerPrints() {
        let text = exporter().export()
        #expect(text.contains("withdrawal notice"))
        #expect(text.contains("Mandatory Declassification Review"))
        #expect(text.contains("FOIA"))
        #expect(text.contains("not lost"), """
            The explainer's job is the case that survives the trip: what the slip of paper \
            where a document used to be means, and that a remedy exists.
            """)
    }

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
        // The oracle packet runs several pages at 9pt monospaced; a one-page result would
        // mean the pagination loop stopped after the first frame.
        #expect(document.numberOfPages >= 2, "the oracle packet does not fit one page")
    }

    /// T-0 §3.2: the fastest-rotting claims are absent.
    @Test("The visit-day card omits every claim T-0 negated")
    func visitDayCardOmitsRottingClaims() {
        let text = exporter().export()
        for negated in ["5:15", "Wednesday", "3rd floor", "9:30", "one box"] {
            #expect(!text.contains(negated), """
                The packet printed "\\(negated)", which T-0 §3.2 negated. One person's calendar is \\
                the fastest-rotting claim available, and a trip booked around a slot that no longer \\
                exists is a trip lost.
                """)
        }
        #expect(text.contains("Lockers are provided"), "the rules that survive A14's test remain")
        #expect(text.contains("must be used in those forms"), "A6's mandatory-substitute rule")
    }

    /// **The worksheet becomes pull slips**, so mixing facilities in one table invites a
    /// researcher to request material that is a plane ride away. Found by reading the rendered
    /// packet, not by an assertion — which is why the exporter has a render test at all.
    @Test("The pull worksheet is grouped by facility, with unplaceable groups separated")
    func worksheetIsGroupedByFacility() {
        let text = exporter().export()
        let worksheet = text.components(separatedBy: "## Pull worksheet")[1]
            .components(separatedBy: "## Access restrictions")[0]
        #expect(worksheet.contains("### National Archives at College Park"))
        #expect(worksheet.contains("### Location not confirmed"))
        #expect(worksheet.contains("Do not take these to a reading room"), """
            The unplaceable groups must carry their own warning. A flat table would let a Truman \
            Library item be requested at College Park.
            """)
        let collegeParkBlock = worksheet
            .components(separatedBy: "### National Archives at College Park")[1]
            .components(separatedBy: "### Location not confirmed")[0]
        #expect(!collegeParkBlock.contains("Truman Library"), """
            A library group appeared under the College Park heading.
            """)
    }

    /// A packet a researcher emails to archivists should not say "1 lot citations". Also found by
    /// reading the output.
    @Test("Counted sentences agree in number")
    func countedSentencesAgree() {
        let text = exporter().export()
        #expect(text.contains("1 lot citation could not be resolved"))
        #expect(text.contains("1 of your documents is dated"))
        #expect(text.contains("Confirm the location of 1 collection "))
        #expect(text.contains("1 of 1 cited series carries"))
        for wrong in ["1 lot citations", "1 documents", "1 collection(s)", "document(s)"] {
            #expect(!text.contains(wrong), "the packet printed \"\(wrong)\"")
        }
    }

    /// D10: `numberingNote` is gone, and the worksheet still works.
    @Test("The pull worksheet omits numberingNote")
    func worksheetOmitsNumberingNote() {
        let text = exporter().export()
        #expect(text.contains("Pull worksheet"))
        #expect(text.contains("| Group | Documents | Box |"))
        #expect(!text.lowercased().contains("numbering note"))
    }

    /// Every chapter has a defined empty behaviour, and none of them is silence.
    @Test("An empty packet still says what it could not do")
    func emptyPacketStillSpeaks() {
        let empty = TripPacketModel.build(
            groups: [], documentYears: [], unresolvedLotCount: 0, unresolvedDocumentCount: 0,
            researchQuestion: nil, facts: { _ in nil })
        let text = exporter(model: empty).export()
        #expect(text.contains("no resolvable source notes"))
        #expect(text.contains("no inquiry to draft"))
        #expect(text.contains("Nothing to report"))
        #expect(!text.isEmpty)
    }

    // MARK: - Chapter 3 roster caps (Archive Visits Phase 0)

    /// A group past 20 documents prints exactly 20 rows and an exact-count remainder — the
    /// oracle's 30-document decimal group is the fixture, so this drives the shipping path.
    @Test("A group's roster caps at 20 rows with an exact remainder")
    func rosterCapsPerGroup() {
        let text = exporter().export()
        let rows = text.components(separatedBy: "| FRUS 1948 II, Document ").count - 1
        // The 30-document group prints 20; the 8-, 3- and 12-document groups print in full
        // (3 of the 12-doc library rows are also in the worksheet only if placeable — count
        // against the whole packet, which is what a reader receives).
        #expect(text.contains("… and 10 more documents — the app's Sources view carries this group's full roster."),
                "the 30-document group must disclose its exact remainder")
        #expect(rows < 30 + 8 + 3 + 12, "the uncapped roster is back")
    }

    /// At 500 documents the roster elides outright: the records line and the exact count stay,
    /// the finding-aid sentence replaces the table, and the chapter's closing line counts it.
    @Test("A 500-document group elides its roster and keeps its exact count")
    func rosterElidesAtThreshold() {
        let model = TripPacketModel.build(
            groups: [
                (key: "big", label: "Central Decimal File 611.51", category: .centralDecimalFile,
                 repository: nil, resolution: nil,
                 documents: Self.refs(TripPacketExporter.rosterElisionThreshold,
                                      note: "Department of State, Central Files, 611.51")),
            ],
            documentYears: [1950], unresolvedLotCount: 0, unresolvedDocumentCount: 0,
            researchQuestion: nil, facts: { _ in nil })
        let text = exporter(model: model).export()
        #expect(text.contains("All 500 documents cite this file — too many to roster here."),
                "the elision must state the exact count")
        #expect(text.contains("Work from the series' own finding aid at the pull desk"),
                "the finding-aid sentence is the elision's replacement, not silence")
        #expect(!text.contains("| FRUS 1948 II, Document 1 |"),
                "an elided group must print no roster rows")
        #expect(text.contains("1 group's roster was elided above"),
                "the chapter must close by counting what it elided")
    }

    /// The packet-wide budget: groups spend it in order, and a group past it keeps its header
    /// and count while its roster elides — never a silent disappearance.
    @Test("The 200-row packet budget elides later groups with their counts intact")
    func rosterBudgetAcrossGroups() {
        // Twelve 20-document groups: the first ten spend the 200-row budget exactly; the
        // eleventh and twelfth must elide with counts.
        let groups: [(key: String, label: String, category: SourceProvenanceCategory?,
                      repository: String?, resolution: ArchivalResolution?,
                      documents: [TripPacketModel.Group.DocumentRef])] =
            (1...12).map { i in
                (key: "g\(i)", label: "Lot 6\(i) D 199 group \(i)", category: .lotFile,
                 repository: nil, resolution: nil,
                 documents: Self.refs(TripPacketExporter.rosterRowsPerGroupLimit,
                                      note: "Department of State, Lot 6\(i) D 199"))
            }
        let model = TripPacketModel.build(
            groups: groups, documentYears: [1950], unresolvedLotCount: 0,
            unresolvedDocumentCount: 0, researchQuestion: nil, facts: { _ in nil })
        let text = exporter(model: model).export()
        let rows = text.components(separatedBy: "| FRUS 1948 II, Document ").count - 1
        #expect(rows == TripPacketExporter.rosterRowBudget,
                "the worksheet printed \(rows) rows against a budget of \(TripPacketExporter.rosterRowBudget)")
        #expect(text.contains("roster elided; this worksheet caps at \(TripPacketExporter.rosterRowBudget) rows"),
                "a budget-elided group must say why its roster is missing")
        #expect(text.contains("2 groups' rosters were elided above"),
                "the closing disclosure must count both elided groups")
        for i in 1...12 {
            #expect(text.contains("**Lot 6\(i) D 199 group \(i)** (20 documents)"),
                    "group \(i)'s header and exact count must survive the budget")
        }
    }

    // MARK: - The edited topic sentence (Phase 0 — the missing writer's route)

    /// The exporter reads the EDITED value, never the stored note — the rule
    /// `TripPacketTopicSentence`'s doc comment states and nothing exercised until now.
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
