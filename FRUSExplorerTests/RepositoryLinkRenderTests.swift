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

// MARK: - RepositoryLinkRenderTests

/// Pins the link render path and D12's structural half (#830 T-3).
///
/// T-0 §3.4 splits D12 in two: an owner-run checker that needs the network, and **an offline test
/// that every printed link carries a stamp** — checkable in CI precisely because it asks nothing of
/// the network. This suite is that offline half, plus the key folding that decides whether a
/// curated row is reachable at all.
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-3, the link render path
///   1.1 — Archive Visits Phase 1: the visit-day-card test left with its chapter (ch7
///          dropped); the confirm-prompt test reads the whole export, since the prompt is
///          now its own section rather than part of the inquiry
@Suite("Repository link rendering (#830 T-3)")
struct RepositoryLinkRenderTests {

    private let stamped = Date(timeIntervalSince1970: 1_787_000_000)

    // MARK: - D12's structural half

    /// Every link the shipping table can print carries a `verifiedDate`.
    ///
    /// The whole D12 gate in one assertion. An unstamped link is an unverified institutional fact,
    /// and D7's rule for those is omission — so an unstamped link that reached the page would be a
    /// claim nobody had checked, printed to someone deciding whether to fly somewhere.
    @Test("Every shipping link is stamped")
    func everyShippingLinkIsStamped() {
        let links = RepositoryFactTable.current.rows.flatMap(\.links)
        #expect(!links.isEmpty, "fixture drift: the table ships no links, so this proves nothing")
        for link in links {
            #expect(link.verifiedDate != nil, "unstamped link would not print: \(link.url)")
            #expect(link.url.hasPrefix("https://"), "insecure link: \(link.url)")
        }
    }

    /// A stamp is worthless if it is the build date — it would refresh itself without anyone
    /// checking, which is the one failure mode D7's "when was this last known true" phrasing exists
    /// to rule out. So the shipping stamp must be a fixed past date, not `Date()`.
    @Test("The shipping stamp is a fixed date, not the build date")
    func shippingStampIsNotTheBuildDate() {
        guard let confirmed = RepositoryFactTable.confirmed else {
            Issue.record("the shipping table has no confirmation date")
            return
        }
        #expect(confirmed < Date(), "a stamp at or after now is a build date in disguise")
        for link in RepositoryFactTable.current.rows.flatMap(\.links) {
            #expect(link.verifiedDate == confirmed)
        }
    }

    /// An unstamped link is filtered out of the rendered lines entirely.
    @Test("An unstamped link does not print")
    func unstampedLinkDoesNotPrint() {
        let lines = TripPacketExporter.linkLines([
            RepositoryLink(url: "https://example.org/a", label: "Stamped", verifiedDate: stamped),
            RepositoryLink(url: "https://example.org/b", label: "Never checked", verifiedDate: nil),
        ], asOf: stamped)
        #expect(lines.count == 1)
        #expect(lines[0].contains("https://example.org/a"))
        #expect(!lines.joined().contains("example.org/b"))
    }

    /// Staleness degrades the SENTENCE, never the row: withholding the link would leave the reader
    /// with nothing where they had something slightly old.
    @Test("A stale link still prints, with its age stated")
    func staleLinkPrintsWithItsAge() {
        let link = RepositoryLink(url: "https://example.org/a", label: "Visit", verifiedDate: stamped)
        let old = stamped.addingTimeInterval(RepositoryLink.freshnessWindow + 86_400)

        let fresh = TripPacketExporter.linkLines([link], asOf: stamped)
        #expect(fresh == ["Visit: https://example.org/a"])

        let aged = TripPacketExporter.linkLines([link], asOf: old)
        #expect(aged.count == 1)
        #expect(aged[0].contains("https://example.org/a"), "a stale link must still be usable")
        #expect(aged[0].contains("last checked"))
        #expect(aged[0].contains("confirm current guidance"))
    }

    /// The line is pasted into an email and read months later, and this packet's whole subject is
    /// transatlantic archives — `8/22/26` is ambiguous, `2026-08-22` is not.
    @Test("Stamps print in ISO form regardless of locale")
    func stampsPrintInISOForm() {
        let link = RepositoryLink(url: "https://example.org/a", label: "Visit",
                                  verifiedDate: Date(timeIntervalSince1970: 1_787_011_200))
        let aged = TripPacketExporter.linkLines(
            [link], asOf: Date(timeIntervalSince1970: 1_787_011_200)
                .addingTimeInterval(RepositoryLink.freshnessWindow + 86_400))
        #expect(aged[0].contains("2026-08-"), "expected an ISO date, got: \(aged[0])")
    }

    // MARK: - Key folding

    /// **The lookup defect this PR exists to fix.** `row(for:)` was an exact lowercase comparison
    /// against the raw corpus string, and measured over the export sample 43 of 126
    /// presidential-library records match no canonical form — including `Nixon Presidential
    /// Materials`, the corpus's commonest Nixon spelling, which alone rides roughly 7,000 notes.
    @Test("The corpus's own spellings reach their curated row")
    func corpusSpellingsFold() {
        let table = RepositoryFactTable.current
        let cases: [(String, String)] = [
            ("Nixon Presidential Materials", "Nixon"),
            ("Nixon Library", "Nixon"),
            ("Gerald R. Ford Presidential Library", "Ford Library"),
            ("Copy obtained from the Franklin D. Roosevelt Library", "Roosevelt Library"),
            ("George H.W. Bush Library", "Bush Library"),
            ("Truman Library", "Truman Library"),
        ]
        for (spelling, expected) in cases {
            #expect(table.row(for: spelling)?.id == expected,
                    "\(spelling) did not fold onto \(expected)")
        }
    }

    /// The two key spaces are real, and this documents why the exporter needs both lookups: a
    /// facility name reaches College Park, and the repository a State document cites does not.
    @Test("Facility names and repository names are different key spaces")
    func facilityAndRepositoryAreDifferentKeySpaces() {
        let table = RepositoryFactTable.current
        #expect(table.row(for: ResearchFacilityResolver.collegePark)?.id
                == ResearchFacilityResolver.collegePark)
        #expect(table.row(for: "National Archives")?.id == ResearchFacilityResolver.collegePark,
                "a NARA-cited group is College Park material (D3)")
        #expect(table.row(for: "Department of State") == nil, """
            `Department of State` is its own canonical keyword and must NOT reach the College Park \
            row by folding — the FACILITY resolver is what routes it there (D3), and a fact-table \
            match would bypass the provenance distinction that resolver exists to draw.
            """)
    }

    /// D14: Hoover and Clinton are "not yet", not "never". Nothing may encode ten — the table is
    /// data, and a library with no cited documents is simply never looked up.
    @Test("An uncited library is absent, and adding one later is one row")
    func addingALibraryLaterIsOneRow() {
        #expect(RepositoryFactTable.current.row(for: "Clinton Library") == nil)
        #expect(RepositoryFactTable.current.row(for: "Hoover Library") == nil)

        // The whole D14 claim: one row, no other change.
        let grown = RepositoryFactTable(rows: RepositoryFactTable.current.rows + [
            RepositoryFactRow(id: "Clinton Library", displayName: "William J. Clinton Library",
                              address: .unverified(""), inquiryEmail: .unverified(""),
                              appointmentPolicy: .unverified(""),
                              links: [RepositoryLink(url: "https://example.org/clinton",
                                                     label: "Plan a research visit",
                                                     verifiedDate: Date())]),
        ])
        #expect(grown.row(for: "William J. Clinton Presidential Library")?.id == "Clinton Library")
        #expect(grown.row(for: "Nixon Presidential Materials")?.id == "Nixon",
                "growing the table must not disturb the rows already in it")

        // A constraint worth knowing before those volumes ship: `canonicalRepository` folds a
        // presidential library by SURNAME only when the string also contains "Librar" — except for
        // Nixon, which is a bare keyword because the corpus writes `Nixon Presidential Materials`.
        // A Clinton-era spelling that omits "Library" would need the same treatment, or an alias
        // in `matchKeys`.
        #expect(grown.row(for: "Clinton Presidential Materials Project") == nil, """
            If this now resolves, the fold gained a bare `Clinton` keyword — check it does not \
            also swallow unrelated strings before relying on it.
            """)
    }

    // MARK: - What reaches the page

    /// D11's other half: the ask, beside the page that answers it. A library never resolves to a
    /// facility heading (D3), so `Target.facts` is the ONLY lookup that can reach it.
    @Test("A library's link reaches the confirm-before-you-travel prompt")
    func libraryLinkReachesTheConfirmPrompt() {
        let model = TripPacketModel.build(
            groups: [(key: "nixon", label: "Nixon Presidential Materials, NSC Files",
                      category: .presidentialLibrary, repository: "Nixon Presidential Materials",
                      lotAsPrinted: nil, resolution: nil,
                      documents: TripPacketExporterTests.refs(40))],
            documentYears: [1971], unresolvedLotCount: 0, unresolvedDocumentCount: 0,
            researchQuestion: nil, facts: { _ in nil }, claimants: { _ in nil })
        let text = TripPacketExporter(model: model, projectName: "P").export()

        #expect(text.contains("Confirm before you travel"))
        #expect(text.contains("nixonlibrary.gov"), """
            The library's own page did not reach the prompt. D11 reduced this chapter from a \
            drafted letter to an ask beside the page that answers it — without the link it is \
            only the ask.
            """)
    }
}
