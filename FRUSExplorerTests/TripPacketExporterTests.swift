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
@Suite("Trip packet exporter (#830 T-2)")
struct TripPacketExporterTests {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    /// The scope doc's own oracle fixture.
    private func oracleModel(researchQuestion: String? = "US policy toward Berlin, 1948")
        -> TripPacketModel {
        TripPacketModel.build(
            groups: [
                (key: "cdf", label: "Central Decimal File 762.00", category: .centralDecimalFile,
                 repository: nil, seriesNaId: nil, documentCount: 30),
                (key: "lot-resolved", label: "Lot 64 D 199", category: .lotFile,
                 repository: nil, seriesNaId: "555", documentCount: 8),
                (key: "lot-unresolved", label: "Lot 71 D 483", category: .lotFile,
                 repository: nil, seriesNaId: nil, documentCount: 3),
                (key: "library", label: "Truman Library, President's Secretary's Files",
                 category: .presidentialLibrary, repository: "Truman Library",
                 seriesNaId: nil, documentCount: 12),
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
                    findingAids: [], years: nil) : nil
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

    /// D13: the crib attributes rather than prescribes, and says what is missing.
    @Test("The citation crib attributes and does not prescribe")
    func citationCribAttributes() {
        let text = exporter().export()
        #expect(text.contains("governed by your publisher"))
        #expect(text.contains("reports that guidance as NARA's rather than prescribing it"))
        #expect(text.contains("have not been deposited"), """
            The crib must say its worked examples are missing rather than paraphrasing guidance \\
            nobody has checked.
            """)
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
}
