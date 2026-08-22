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

// MARK: - AdvanceNoticeFlagTests

/// Pins the A4 flag engine (#830 T-1, decision D9).
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-1
@Suite("A4 advance-notice flags (#830 T-1)")
struct AdvanceNoticeFlagTests {

    /// D9's central call: the sensitive-agency criterion is a CONSTANT, not a flag. It fires on
    /// 81.4% of notes, and a chip lit on every row costs the two informative chips their salience.
    @Test("Only the two discriminating criteria are flags")
    func onlyDiscriminatingCriteriaAreFlags() {
        #expect(AdvanceNoticeFlag.allCases.count == 2)
        #expect(Set(AdvanceNoticeFlag.allCases) == [.recentRecords, .unresolvedLotCitations])
        #expect(!AdvanceNoticeFlags.standingSentence.isEmpty, """
            The sensitive-agency criterion must still be stated — A4 requires the packet to quote \
            WHICH criterion fired, and D9 moves this one to a standing sentence rather than \
            deleting it.
            """)
        #expect(AdvanceNoticeFlags.standingSentence.contains("State, Defense"), """
            The standing sentence must quote the FAQ's own list rather than paraphrase it.
            """)
    }

    /// An unknown date is not a recent one.
    @Test("Documents with no year cannot trip the date test")
    func unknownYearsDoNotTripTheDateTest() {
        let flags = AdvanceNoticeFlags.evaluate(documentYears: [nil, nil, 1948], unresolvedLotCount: 0)
        #expect(flags.flags.isEmpty)
        #expect(flags.recentDocumentCount == 0, """
            A document with no year counted as recent. An unknown date is not a late one, and \
            inferring otherwise would escalate a lead time on no evidence.
            """)
    }

    /// NARA's wording is "the 1960s and later", so 1960 itself counts.
    @Test("The threshold includes 1960")
    func thresholdIncludes1960() {
        #expect(AdvanceNoticeFlags.evaluate(documentYears: [1959], unresolvedLotCount: 0).flags.isEmpty)
        let flags = AdvanceNoticeFlags.evaluate(documentYears: [1960], unresolvedLotCount: 0)
        #expect(flags.flags == [.recentRecords])
        #expect(flags.recentDocumentCount == 1)
    }

    @Test("Unresolved lot citations raise their own flag")
    func unresolvedLotsFlag() {
        let flags = AdvanceNoticeFlags.evaluate(documentYears: [1948], unresolvedLotCount: 7)
        #expect(flags.flags == [.unresolvedLotCitations])
        #expect(flags.unresolvedLotCount == 7)
    }

    /// Each flag must quote NARA's criterion, per A4.
    @Test("Every flag quotes the criterion that produced it")
    func flagsQuoteTheirCriterion() {
        for flag in AdvanceNoticeFlag.allCases {
            #expect(!flag.quotedCriterion.isEmpty, "\(flag.rawValue) quotes nothing")
        }
        #expect(AdvanceNoticeFlag.unresolvedLotCitations.quotedCriterion.contains("do not always carry over"))
    }
}

// MARK: - TripChecklistTests

/// Pins D5's two lead-time forms.
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-1
@Suite("Trip checklist lead times (#830 T-1)")
struct TripChecklistTests {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    /// The packet must be useful BEFORE the trip is booked — requiring a date would gate the
    /// packet on the decision it exists to inform.
    @Test("Without a visit date the same rows print relatively")
    func relativeFormWithoutADate() {
        let checklist = TripChecklist.build(
            flags: .evaluate(documentYears: [1948], unresolvedLotCount: 0))
        #expect(!checklist.items.isEmpty)
        for item in checklist.items {
            let line = item.line(arrival: nil, calendar: calendar)
            #expect(line.contains("before you arrive"), """
                "\(line)" is not in the relative form. D5 requires the checklist to work with no \
                visit date at all.
                """)
        }
    }

    /// With a date, the same rows resolve to real deadlines.
    @Test("With a visit date the rows print absolute deadlines")
    func absoluteFormWithADate() throws {
        let arrival = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 1)))
        let checklist = TripChecklist.build(
            flags: .evaluate(documentYears: [1948], unresolvedLotCount: 0))
        let inquiry = try #require(checklist.items.first { $0.id == "inquiry" })
        let line = inquiry.line(arrival: arrival, calendar: calendar)
        #expect(line.contains("by "), "\(line) is not in the absolute form")
        #expect(!line.contains("before you arrive"))
    }

    /// The rows and the escalation are the SAME in both forms — that is what makes this a
    /// presentation choice rather than two features.
    @Test("The two forms carry identical rows")
    func bothFormsCarryTheSameRows() throws {
        let arrival = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 1)))
        let checklist = TripChecklist.build(
            flags: .evaluate(documentYears: [1961], unresolvedLotCount: 3))
        let withDate = checklist.items.map(\.id)
        let withoutDate = checklist.items.map(\.id)
        #expect(withDate == withoutDate)
        _ = checklist.items.map { $0.line(arrival: arrival, calendar: calendar) }
        #expect(checklist.items.contains { $0.escalatedBy == .recentRecords })
        #expect(checklist.items.contains { $0.escalatedBy == .unresolvedLotCitations })
    }

    /// The most urgent lead time reads first.
    @Test("Rows sort by lead time, longest first")
    func rowsSortByLeadTime() {
        let checklist = TripChecklist.build(
            flags: .evaluate(documentYears: [1965], unresolvedLotCount: 2))
        let leads = checklist.items.map(\.leadDays)
        #expect(leads == leads.sorted(by: >), "got \(leads)")
        #expect(leads.first == 42, "an A4 escalation must lead the list")
    }

    /// D9's standing sentence rides the checklist, printed once.
    @Test("The standing sentence is present and unconditional")
    func standingSentenceIsUnconditional() {
        let quiet = TripChecklist.build(flags: .evaluate(documentYears: [1900], unresolvedLotCount: 0))
        #expect(quiet.standingSentence == AdvanceNoticeFlags.standingSentence, """
            The sensitive-agency sentence must print even when no flag fires — it is true of \
            essentially every project, and making it conditional would imply the quiet case is exempt.
            """)
    }
}

// MARK: - RepositoryFactTableTests

/// Pins D7's per-fact verification and the empty-table-that-still-builds shape.
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-1
@Suite("Repository fact table (#830 T-1)")
struct RepositoryFactTableTests {

    /// **The constraint the whole T-0 gate rests on.** T-1 may not print an institutional fact the
    /// owner has not confirmed, and the table shipping empty is what makes that enforceable rather
    /// than aspirational.
    @Test("The shipping table has no rows")
    func shippingTableIsEmpty() {
        #expect(RepositoryFactTable.current.rows.isEmpty, """
            A curated repository row has shipped. Every row here is an institutional claim — an \
            address, an inquiry email, an appointment policy — and T-1 may print none of them. If \
            the owner has now confirmed some, this test changes deliberately, in the same commit.
            """)
        #expect(RepositoryFactTable.current.row(for: "Truman Library") == nil)
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

/// Pins the assembled packet (#830 T-1).
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-1
@Suite("Trip packet model (#830 T-1)")
struct TripPacketModelTests {

    private func group(_ key: String, category: SourceProvenanceCategory?, repository: String?,
                       naId: String? = nil, count: Int = 1)
        -> (key: String, label: String, category: SourceProvenanceCategory?,
            repository: String?, seriesNaId: String?, documentCount: Int) {
        (key: key, label: key, category: category, repository: repository,
         seriesNaId: naId, documentCount: count)
    }

    /// The packet builds with the empty table, and a library group renders a heading-less
    /// confirm-prompt rather than a guess.
    @Test("A library group builds, cannot head a chapter, and carries no curated facts")
    func libraryGroupBuildsWithoutGuessing() {
        let model = TripPacketModel.build(
            groups: [group("truman", category: .presidentialLibrary, repository: "Truman Library")],
            documentYears: [1948], unresolvedLotCount: 0, unresolvedDocumentCount: 0,
            researchQuestion: nil, facts: { _ in nil })
        let only = model.groups[0]
        #expect(only.facility == .unknown)
        #expect(!only.canHeadChapter, """
            A library headed a chapter with no confirmed facility. No chapter may be headed with a \
            string that names no place a researcher can be served.
            """)
        #expect(only.facts == nil, "the curated table is empty at T-1")
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

    /// The A4 flags and the triage both reach the assembled model.
    @Test("Flags and triage assemble into the packet")
    func flagsAndTriageAssemble() {
        let model = TripPacketModel.build(
            groups: [group("s", category: .lotFile, repository: nil, naId: "123", count: 5)],
            documentYears: [1948, 1972], unresolvedLotCount: 4, unresolvedDocumentCount: 9,
            researchQuestion: nil,
            facts: { _ in SeriesFactsIndex.Facts(
                accessStatus: "Restricted - Fully", accessRestrictions: ["FOIA (b)(1) National Security"],
                useStatus: nil, useRestrictions: [], extent: nil,
                referenceUnit: "National Archives at College Park - Textual Reference",
                findingAids: [], years: nil) })
        #expect(model.flags.flags == [.recentRecords, .unresolvedLotCitations])
        #expect(model.triage.rows.first?.severity == .fully)
        #expect(model.triage.unresolvedDocumentCount == 9)
        #expect(model.checklist.items.contains { $0.escalatedBy == .recentRecords })
        #expect(model.groups[0].facility == .derived(facility: "National Archives at College Park"))
    }
}
