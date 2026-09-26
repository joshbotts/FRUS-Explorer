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
/// pointed-at-only lot, a presidential-library collection, which heads its own chapter (#1459),
/// and a foreign-archive group no repository serves, which is what "Confirm before you travel"
/// is left for. The resolved lot is DIVIDED (two claimant series, one unmeasured), and one
/// seeded document carries a digitized substitute. **A packet claim with no source in the
/// design is a defect**, and most tests below walk one rule each.
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-2
///   1.1 — Archive Visits Phase 0: chapter 3's roster caps and the edited topic sentence
///   2.0 — Archive Visits Phase 1: rewritten for the narrowed artifact — the chapter tests
///          left with their chapters (ch1/ch3/ch7 dropped, ch4/ch5 folded); new coverage for
///          target minting, the §3d claims separation, per-seeding substitute markers, the
///          claimant-aware access line, the divided-lot inquiry question, repository scoping,
///          and the opt-in citation appendix with its fixed Example-8 gate
///   2.1 — 2026-09-25: #1459 — a presidential library heads its own chapter and gets an
///          inquiry draft that says what contact the app does not hold; the header counts every
///          included target; the confirm list and the coverage line honour the plan's
///          exclusions; Copy inquiry draft offers the libraries. The oracle gains a
///          foreign-archive group so the confirm list keeps a real member.
@Suite("Trip packet exporter (Archive Visits Phase 1)")
struct TripPacketExporterTests {

    /// `n` seeding rows for a fixture target.
    ///
    /// The citations END IN A PERIOD, as every `CitationFormatter` output does. They did not
    /// until #1392, and that is why no test here saw the packet print "Document 41., footnote 3":
    /// a hand-written citation without the formatter's period hides any join made after it.
    static func refs(_ n: Int, volume: String = "frus1948v02",
                     designation: (Int) -> String? = { _ in nil },
                     note: String = "A source note.") -> [TripPacketModel.Group.DocumentRef] {
        (1...n).map { i in
            .init(volumeId: volume, documentId: "d\(i)",
                  citation: "FRUS 1948 II, Document \(i).",
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

    /// The plan #1458 and #1459 were found on, in the shape the Mac by-eye check of 2026-09-25
    /// recorded: six targets in three repositories — two College Park lots, two Eisenhower Library
    /// collections (one spelled "Dwight D. Eisenhower Library", as the corpus often does) and two
    /// Kennedy Library collections, one of them cited only in a footnote, which the model types
    /// `.presidentialLibrary` whatever its repository. `withForeignArchive` adds a seventh target no
    /// repository serves. Built through `TripPacketModel.build` against the SHIPPING repository
    /// table, so the resolver decides where every target goes.
    static func libraryPlan(withForeignArchive: Bool = false) -> TripPacketModel {
        var groups: [(key: String, label: String, category: SourceProvenanceCategory?,
                      repository: String?, lotAsPrinted: String?,
                      resolution: ArchivalResolution?,
                      documents: [TripPacketModel.Group.DocumentRef])] = [
            (key: "lot|60D1", label: "Lot 60 D 1", category: .lotFile,
             repository: "Department of State", lotAsPrinted: "60 D 1", resolution: nil,
             documents: refs(2, volume: "frus1958-60v01")),
            (key: "lot|61D2", label: "Lot 61 D 2", category: .lotFile,
             repository: "Department of State", lotAsPrinted: "61 D 2", resolution: nil,
             documents: refs(1, volume: "frus1958-60v02")),
            (key: "coll|Eisenhower Library|Whitman File",
             label: "Eisenhower Library, Whitman File", category: .presidentialLibrary,
             repository: "Eisenhower Library", lotAsPrinted: nil, resolution: nil,
             documents: refs(3, volume: "frus1958-60v03")),
            (key: "coll|Dwight D. Eisenhower Library|Dulles Papers",
             label: "Dwight D. Eisenhower Library, Dulles Papers", category: .presidentialLibrary,
             repository: "Dwight D. Eisenhower Library", lotAsPrinted: nil, resolution: nil,
             documents: refs(1, volume: "frus1958-60v04")),
            (key: "coll|Kennedy Library|National Security Files",
             label: "Kennedy Library, National Security Files", category: .presidentialLibrary,
             repository: "Kennedy Library", lotAsPrinted: nil, resolution: nil,
             documents: refs(4, volume: "frus1961-63v05")),
        ]
        if withForeignArchive {
            groups.append((key: "r|Foreign Office records", label: "British Foreign Office records",
                           category: .foreignArchive, repository: nil, lotAsPrinted: nil,
                           resolution: nil, documents: refs(1, volume: "frus1958-60v07")))
        }
        return TripPacketModel.build(
            groups: groups,
            documentYears: [1959, 1962], unresolvedLotCount: 2, unresolvedDocumentCount: 0,
            researchQuestion: "Berlin contingency planning, 1958-1962",
            facts: { _ in nil },
            references: [
                (key: "coll|Kennedy Library|President's Office Files", form: .collection,
                 label: "Kennedy Library, President's Office Files",
                 repository: "Kennedy Library", lotAsPrinted: nil,
                 seedings: [
                    .init(volumeId: "frus1961-63v14", documentId: "d7",
                          citation: "FRUS 1961-63 XIV, Document 7.", footnoteLabel: "2",
                          rawText: "Kennedy Library, President's Office Files, Berlin; not printed.",
                          inherited: false),
                 ]),
            ],
            referenceCoverage: .init(documentsWithReferences: 1, documentsScanned: 12),
            claimants: { _ in nil })
    }

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
                // #1459: the target no repository serves — a foreign government's archive —
                // which is what "Confirm before you travel" is left for once a library is placed.
                (key: "r|Quai d'Orsay, Europe 1944-1949",
                 label: "Archives of the French Ministry of Foreign Affairs",
                 category: .foreignArchive, repository: nil,
                 lotAsPrinted: nil, resolution: nil,
                 documents: Self.refs(2, volume: "frus1948v06")),
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
                          citation: "FRUS 1948 II, Document 40.", footnoteLabel: "3",
                          rawText: "Not printed. (Department of State, Lot 64 D 199, CF 1)",
                          inherited: false),
                    .init(volumeId: "frus1948v02", documentId: "d41",
                          citation: "FRUS 1948 II, Document 41.", footnoteLabel: "2",
                          rawText: "Ibid., CF 2, not printed.",
                          inherited: true),
                 ]),
                // Pointed-at only, unresolved — the "beyond FRUS" case the channel exists for.
                (key: "lot|99Z999", form: .lotFile, label: "Lot 99 Z 999",
                 repository: "Department of State", lotAsPrinted: "99 Z 999",
                 seedings: [
                    .init(volumeId: "frus1948v02", documentId: "d42",
                          citation: "FRUS 1948 II, Document 42.", footnoteLabel: "5",
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

    /// The lines under `heading` — up to the next heading of the same or a higher level — or `nil`
    /// when the text has no such heading line.
    static func section(of text: String, headed heading: String) -> String? {
        let lines = text.components(separatedBy: "\n")
        guard let start = lines.firstIndex(of: heading) else { return nil }
        let level = heading.prefix { $0 == "#" }.count
        var out: [String] = []
        for line in lines[(start + 1)...] {
            let hashes = line.prefix { $0 == "#" }.count
            if hashes > 0, hashes <= level, line.dropFirst(hashes).hasPrefix(" ") { break }
            out.append(line)
        }
        return out.joined(separator: "\n")
    }

    /// A presidential library heads its own chapter and gets its own inquiry draft, which says
    /// what contact the app does not hold rather than inventing one (#1459, changed deliberately).
    ///
    /// This was "A library gets A12's ask, not a drafted letter" (D11): a library could not be
    /// placed, so it sat under "Confirm before you travel" beside a sentence saying so — while the
    /// same packet printed the library's own links and the editor filed it under the library. The
    /// owner's decision of 2026-09-25 is that a library IS a repository: its chapter carries its
    /// (a) links and (b) targets, and its (c) draft names no recipient, because the table holds no
    /// confirmed address or email for any library, and points at the finding aids instead. The
    /// confirm list keeps A12's ask for the one target no repository serves.
    @Test("A library heads its own chapter and gets a draft that invents no contact")
    func libraryHeadsItsOwnChapterWithAnHonestDraft() throws {
        let text = exporter().export()
        let chapter = try #require(Self.section(of: text,
                                                headed: "## Harry S. Truman Presidential Library"),
                                   "no Truman Library chapter:\n\(text)")
        #expect(chapter.contains("Plan a research visit: "
                                 + "https://www.trumanlibrary.gov/library/researching-our-holdings"))
        #expect(chapter.contains("### Truman Library, President's Secretary's Files"))

        let inquiry = try #require(Self.section(of: text, headed: "## Advance inquiry"))
        let draft = try #require(Self.section(of: inquiry,
                                              headed: "### Harry S. Truman Presidential Library"),
                                 "no Truman Library draft:\n\(inquiry)")
        #expect(!draft.contains("To:"), "the table holds no confirmed library email:\n\(draft)")
        #expect(draft.contains("This app holds no confirmed postal address or reference email for "
                               + "Harry S. Truman Presidential Library, so this draft has no "
                               + "recipient yet — find the current contact on its own pages below "
                               + "before you send it."), "draft:\n\(draft)")
        #expect(draft.contains("Finding aids — what is held: "
                               + "https://www.trumanlibrary.gov/library/truman-papers"))
        #expect(!draft.contains("Appointment policy changes"), """
            D15's in-flux sentence is the owner's finding about College Park; it is not a claim \
            this app may make about a library.
            """)
        #expect(draft.contains("Topic: US policy toward Berlin, 1948"))
        #expect(draft.contains("  - Truman Library, President's Secretary's Files "
                               + "(drawn from 12 documents)"))

        let collegePark = try #require(Self.section(of: inquiry,
                                                    headed: "### National Archives at College Park"))
        #expect(collegePark.contains("To: Archives2reference@nara.gov"))
        #expect(!collegePark.contains("This app holds no confirmed"),
                "College Park's address and email ARE confirmed")

        let confirm = try #require(Self.section(of: text, headed: "### Confirm before you travel"))
        #expect(!confirm.contains("Truman"), "a placed library is not unplaceable:\n\(confirm)")
        #expect(confirm.contains("Archives of the French Ministry of Foreign Affairs"))
        #expect(confirm.contains("confirm the materials are at that location"), """
            The confirm-prompt must carry A12's actual ask for what no repository serves.
            """)
    }

    // MARK: - Target minting and the §3d claims separation

    /// The header's counts are claim-separated, never summed — 55 drawn documents and 3
    /// footnotes stay two numbers — and, since #1459, count every target the export includes,
    /// the library's chapter and the confirm list's foreign archive among them.
    @Test("The header counts drawn documents and footnotes separately")
    func headerCountsAreClaimSeparated() {
        let text = exporter().export()
        #expect(text.contains("\n6 research targets across 2 repositories · "
                              + "drawn from 55 documents · cited by 3 footnotes\n"), """
            The rendered header must carry both channels as separate counts — a single total \
            would erase the #783 separation at the first line a reader sees.
            """)
    }

    // MARK: - Presidential libraries are repositories (#1459)

    /// The packet's header counts what the plan editor counts, and never calls a library target
    /// unplaceable — the plan the Mac by-eye check of 2026-09-25 exported as "2 research targets
    /// across 1 repository", with four library targets "could not be placed at any repository".
    @Test("The packet's header counts what the editor counts")
    func headerAgreesWithTheEditor() {
        let model = Self.libraryPlan()
        let text = TripPacketExporter(model: model, projectName: "Berlin").export()
        #expect(text.contains("\n6 research targets across 3 repositories · drawn from 11 documents "
                              + "· cited by 1 footnote\n"), "header:\n\(text.prefix(400))")
        #expect(ArchiveVisitCounts.editorSummary(of: model) == "6 targets across 3 repositories.")
        for repository in ArchiveVisitRepositoryCountTests.fixtureRepositories {
            #expect(text.contains("\n## \(repository)\n"), "no chapter for \(repository)")
        }
        #expect(!text.contains("could not be placed"), """
            The coverage report called a library target unplaceable. Every target in this plan is \
            at a repository.
            """)
        #expect(!text.contains("### Confirm before you travel"))
    }

    /// Options ▸ Repository and Options ▸ Copy inquiry draft both list
    /// `TripPacketModel.repositoryNames`; each library there has its own draft, naming only its
    /// own targets.
    @Test("Options ▸ Repository and Copy inquiry draft offer every library")
    func optionsOfferTheLibraries() {
        let model = Self.libraryPlan()
        #expect(model.repositoryNames == ArchiveVisitRepositoryCountTests.fixtureRepositories)
        for repository in model.repositoryNames {
            let draft = TripPacketExporter.copiedInquiryDraft(
                model: model, projectName: "Berlin", overlay: nil, repository: repository)
            #expect(draft.contains("\n### \(repository)\n"), "\(repository):\n\(draft)")
            #expect(!draft.contains("no inquiry to draft"), "\(repository):\n\(draft)")
        }
        let kennedy = TripPacketExporter.copiedInquiryDraft(
            model: model, projectName: "Berlin", overlay: nil,
            repository: "John F. Kennedy Presidential Library")
        #expect(kennedy.contains("  - Kennedy Library, National Security Files "
                                 + "(drawn from 4 documents)"))
        #expect(kennedy.contains("  - Kennedy Library, President's Office Files "
                                 + "(cited by 1 footnote)"))
        #expect(!kennedy.contains("Lot 60 D 1"), "a library's draft names only its own targets")
        #expect(kennedy.contains("so this draft has no recipient yet"))
        #expect(kennedy.contains("Finding aids — what is held: https://www.jfklibrary.org/"))
    }

    /// A library-scoped export is that library's self-contained slice.
    @Test("A library-scoped export renders the library's chapter and draft alone")
    func libraryScopedExport() throws {
        var scoped = TripPacketExporter(model: Self.libraryPlan(), projectName: "Berlin")
        scoped.facilityScope = "Dwight D. Eisenhower Presidential Library"
        let text = scoped.export()
        #expect(text.contains("Scoped to Dwight D. Eisenhower Presidential Library"))
        #expect(text.contains("\n2 research targets across 1 repository · drawn from 4 documents\n"))
        let chapter = try #require(Self.section(
            of: text, headed: "## Dwight D. Eisenhower Presidential Library"))
        #expect(chapter.contains("### Dwight D. Eisenhower Library, Dulles Papers"))
        #expect(chapter.contains("### Eisenhower Library, Whitman File"))
        #expect(!text.contains("## National Archives at College Park"))
        #expect(text.contains("This export renders only Dwight D. Eisenhower Presidential Library; "
                              + "4 targets at other repositories are not shown here."))
    }

    /// A plan whose only targets sit at one library still exports a chapter and a draft — before
    /// #1459 it exported "0 research targets" and "no inquiry to draft".
    @Test("A library-only plan exports a library chapter and an inquiry draft")
    func libraryOnlyPlanExportsAChapterAndADraft() throws {
        let model = TripPacketModel.build(
            groups: [(key: "coll|Eisenhower Library|Whitman File",
                      label: "Eisenhower Library, Whitman File", category: .presidentialLibrary,
                      repository: "Eisenhower Library", lotAsPrinted: nil, resolution: nil,
                      documents: Self.refs(3, volume: "frus1958-60v03"))],
            documentYears: [1959], unresolvedLotCount: 0, unresolvedDocumentCount: 0,
            researchQuestion: "Eisenhower and Berlin", facts: { _ in nil },
            claimants: { _ in nil })
        let text = exporter(model: model).export()
        #expect(text.contains("\n1 research target across 1 repository · drawn from 3 documents\n"))
        let chapter = try #require(Self.section(
            of: text, headed: "## Dwight D. Eisenhower Presidential Library"))
        #expect(chapter.contains("Plan your visit:"))
        #expect(chapter.contains("### Eisenhower Library, Whitman File"))
        let inquiry = try #require(Self.section(of: text, headed: "## Advance inquiry"))
        #expect(!inquiry.contains("no inquiry to draft"))
        let draft = try #require(Self.section(
            of: inquiry, headed: "### Dwight D. Eisenhower Presidential Library"))
        #expect(draft.contains("so this draft has no recipient yet"))
        #expect(draft.contains("Finding aids — what is held: "
                               + "https://www.eisenhowerlibrary.gov/research/finding-aids"))
        #expect(draft.contains("Topic: Eisenhower and Berlin"))
        #expect(!text.contains("Confirm before you travel"))
        #expect(!text.contains("could not be placed"))
    }

    /// A facility the table has no row for — here a NARA reference unit other than College Park —
    /// gets the same honesty, without the links a row would have given it.
    @Test("A facility with no curated row gets a draft that says it has no contact")
    func facilityWithoutARowSaysSo() throws {
        let resolution = ArchivalResolution(
            naId: "901", catalogURL: "https://catalog.archives.gov/id/901",
            title: "Records of a Regional Office", recordGroup: "84", matchType: "lot",
            hmsMlrEntryNumbers: nil, levelOfDescription: "series",
            seriesNaId: nil, seriesTitle: nil, seriesHmsMlrEntryNumbers: nil)
        let model = TripPacketModel.build(
            groups: [(key: "lot|70D1", label: "Lot 70 D 1", category: .lotFile, repository: nil,
                      lotAsPrinted: "70 D 1", resolution: resolution, documents: Self.refs(1))],
            documentYears: [1970], unresolvedLotCount: 0, unresolvedDocumentCount: 0,
            researchQuestion: nil,
            facts: { naId in
                naId == "901" ? SeriesFactsIndex.Facts(
                    accessStatus: nil, accessRestrictions: [], useStatus: nil,
                    useRestrictions: [], extent: nil,
                    referenceUnit: "National Archives at Kansas City - Textual Reference",
                    findingAids: [], years: nil) : nil
            },
            claimants: { _ in nil })
        #expect(model.repositoryNames == ["National Archives at Kansas City"],
                "fixture premise: the reference unit is the heading")
        let inquiry = try #require(Self.section(of: exporter(model: model).export(),
                                                headed: "## Advance inquiry"))
        let draft = try #require(Self.section(of: inquiry,
                                              headed: "### National Archives at Kansas City"))
        #expect(draft.contains("This app holds no confirmed postal address or reference email for "
                               + "National Archives at Kansas City, so this draft has no recipient "
                               + "yet — find the current contact on its own website before you "
                               + "send it."), "draft:\n\(draft)")
        #expect(!draft.contains("To:"))
        #expect(!draft.contains("Archives2reference@nara.gov") && !draft.contains("8601 Adelphi"), """
            The draft printed College Park's contact for another facility — the heading was \
            looked up through the fold, which reads any "National Archives at …" as College Park.
            """)
        #expect(!draft.contains("pages below"), "there are no pages below to point at")
    }

    /// The confirm list prints no repository's pages. A foreign archive whose name the fold reads
    /// as College Park carries College Park's row as its `facts`, and the list used to print a
    /// target's `facts` links — which is how it printed each library's pages.
    @Test("The confirm list prints no repository's pages")
    func confirmListPrintsNoPages() throws {
        let model = TripPacketModel.build(
            groups: [(key: "r|NAA", label: "National Archives of Australia, A1838",
                      category: .foreignArchive, repository: "National Archives of Australia",
                      lotAsPrinted: nil, resolution: nil, documents: Self.refs(1))],
            documentYears: [1965], unresolvedLotCount: 0, unresolvedDocumentCount: 0,
            researchQuestion: nil, facts: { _ in nil }, claimants: { _ in nil })
        #expect(model.targets.first?.facts?.id == ResearchFacilityResolver.collegePark,
                "fixture premise: the fold gives the foreign archive College Park's row")
        let confirm = try #require(Self.section(of: exporter(model: model).export(),
                                                headed: "### Confirm before you travel"))
        #expect(confirm.contains("National Archives of Australia, A1838"))
        #expect(!confirm.contains("archives.gov"), """
            College Park's pages printed beside a foreign archive:\n\(confirm)
            """)
    }

    // MARK: - The plan's exclusions reach every list (#1459)

    /// A plan with one College Park lot and two targets no repository serves.
    private func twoUnplacedModel() -> TripPacketModel {
        TripPacketModel.build(
            groups: [
                (key: "lot|60D1", label: "Lot 60 D 1", category: .lotFile,
                 repository: "Department of State", lotAsPrinted: "60 D 1", resolution: nil,
                 documents: Self.refs(2, volume: "frus1958-60v01")),
                (key: "r|Quai d'Orsay", label: "Archives of the French Ministry of Foreign Affairs",
                 category: .foreignArchive, repository: nil, lotAsPrinted: nil, resolution: nil,
                 documents: Self.refs(1, volume: "frus1958-60v06")),
                (key: "r|An unparsed note", label: "An unparsed source note",
                 category: .unrecognized, repository: nil, lotAsPrinted: nil, resolution: nil,
                 documents: Self.refs(1, volume: "frus1958-60v08")),
            ],
            documentYears: [1959], unresolvedLotCount: 1, unresolvedDocumentCount: 0,
            researchQuestion: nil, facts: { _ in nil }, claimants: { _ in nil })
    }

    /// An excluded target is neither listed under "Confirm before you travel" nor counted in the
    /// header, and the coverage line says how many of the unplaced were excluded.
    @Test("An excluded unplaced target leaves the confirm list, and the report says so")
    func excludedUnplacedTargetLeavesTheConfirmList() throws {
        var exporter = exporter(model: twoUnplacedModel())
        exporter.overlay = ArchiveVisitOverlay(excludedKeys: ["r|An unparsed note"])
        let text = exporter.export()
        #expect(text.contains("\n2 research targets across 1 repository · drawn from 3 documents\n"),
                "the header counts the plan's 3 targets less the 1 excluded")
        let confirm = try #require(Self.section(of: text, headed: "### Confirm before you travel"))
        #expect(confirm.contains("Archives of the French Ministry of Foreign Affairs"))
        #expect(!confirm.contains("An unparsed source note"), """
            An excluded target was listed under "Confirm before you travel":\n\(confirm)
            """)
        #expect(text.contains("3 research targets: 0 resolve to a NARA series; 2 could not be "
                              + "placed at any repository — 1 listed under \"Confirm before you "
                              + "travel\", 1 excluded by you."), "report:\n\(text)")
    }

    /// Every unplaced target excluded: no confirm list at all, and the report says why.
    @Test("With every unplaced target excluded there is no confirm list")
    func everyUnplacedTargetExcluded() {
        var exporter = exporter(model: twoUnplacedModel())
        exporter.overlay = ArchiveVisitOverlay(
            excludedKeys: ["r|An unparsed note", "r|Quai d'Orsay"])
        let text = exporter.export()
        #expect(!text.contains("### Confirm before you travel"))
        #expect(text.contains("3 research targets: 0 resolve to a NARA series; 2 could not be "
                              + "placed at any repository and are excluded from this export by "
                              + "you."), "report:\n\(text)")
    }

    /// Copy inquiry draft reads the plan's exclusions, as the shared packet's own drafts do —
    /// it used to build its exporter with no overlay, so a target the reader excluded reached
    /// the one text meant to be pasted into an email.
    @Test("Copy inquiry draft leaves out the targets the plan excludes")
    func copiedDraftHonoursExclusions() {
        let draft = TripPacketExporter.copiedInquiryDraft(
            model: Self.libraryPlan(), projectName: "Berlin",
            overlay: ArchiveVisitOverlay(excludedKeys: ["lot|61D2"]),
            repository: ResearchFacilityResolver.collegePark)
        #expect(draft.contains("  - Lot 60 D 1"))
        #expect(!draft.contains("Lot 61 D 2"), "an excluded target reached the draft:\n\(draft)")
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
        // The whole line, so the join is pinned too (#1392): the citation's own period comes
        // off before " — file", and the line ends in the packet's.
        #expect(text.contains("\n  - FRUS 1948 II, Document 3 — file 762.00/2-348.\n"))
        #expect(text.contains("https://history.state.gov/historicaldocuments/frus1948v02/d3"))
    }

    /// A pointed-at seeding quotes the footnote VERBATIM with its anchor, and an inherited
    /// row says so — an `Ibid.` is the previous footnote's assertion, not this one's.
    @Test("Pointed-at seedings quote the footnote verbatim, and disclose inheritance")
    func pointedAtSeedingsQuoteVerbatim() {
        let text = exporter().export()
        #expect(text.contains("\n  - FRUS 1948 II, Document 40, footnote 3.\n"))
        #expect(text.contains(
            "Cited as: Not printed. (Department of State, Lot 64 D 199, CF 1)"))
        #expect(text.contains("Cited as: Ibid., CF 2, not printed."))
        #expect(text.contains("inherited from the preceding footnote's citation"), """
            The inherited row must say the unit came from the previous note — a reader \
            checking the printed page will not find these words in footnote 2.
            """)
    }

    /// A footnote the volume never numbered says so, and a symbol label survives verbatim.
    ///
    /// `footnoteLabel` is nil in two situations a reader cannot tell apart — the volume printed
    /// no `@n`, or the row was harvested before index v53 — so the line must be true of both and
    /// must not invent a digit (#1322). 11,125 notes corpus-wide print a symbol rather than a
    /// number, and the packet quotes what the page shows.
    @Test("A footnote with no printed number claims none, and a symbol prints as printed")
    func unnumberedAndSymbolFootnotes() {
        let unnumbered = TripPacketModel.RefSeeding(
            volumeId: "frus1948v02", documentId: "d43",
            citation: "FRUS 1948 II, Document 43.", footnoteLabel: nil,
            rawText: "Lot 99 Z 999, Box 5; not printed.", inherited: false)
        let symbol = TripPacketModel.RefSeeding(
            volumeId: "frus1948v02", documentId: "d44",
            citation: "FRUS 1948 II, Document 44.", footnoteLabel: "*",
            rawText: "Lot 99 Z 999, Box 6; not printed.", inherited: false)

        let unnumberedLine = TripPacketExporter.footnoteLine(for: unnumbered)
        #expect(unnumberedLine == "FRUS 1948 II, Document 43, footnote (no printed number recorded).",
                "got \(unnumberedLine)")
        #expect(!unnumberedLine.contains(where: \.isNumber) || unnumberedLine.contains("1948"), """
            A nil label must not become a digit: \(unnumberedLine)
            """)
        #expect(TripPacketExporter.footnoteLine(for: symbol)
                == "FRUS 1948 II, Document 44, footnote *.")
    }

    // MARK: - #1392: a citation continued, not doubled

    /// The drawn-from line's two shapes, one fixture each. Naming a file, the citation's period
    /// comes off before " — file" and the line ends in the packet's own; a designation that
    /// already ends in a period does not get a second. Naming none, the citation stands alone and
    /// keeps the formatter's period.
    ///
    /// The model is built by hand, so this pins `drawnFromLine(for:)` alone, over whatever
    /// designation reaches it. The one here is what `SourceNoteParser` returns for "Source:
    /// Department of State, Central Files, 611.93/12–854. Secret." — the builder now cuts that to
    /// "611.93/12–854" before the model sees it (`TripPacketBuilderTests`), but the exporter still
    /// owes one period to the kinds the builder passes through, and 843 library designations
    /// corpus-wide end in one ("files under 741.6111/10–1144."). (The third shape, a designation
    /// with no period, is the oracle's `762.00/2-348`, pinned as a whole line above.)
    @Test("A drawn-from line ends in exactly one period, with or without a file (#1392)")
    func drawnFromLineEndsInOnePeriod() {
        let model = TripPacketModel.build(
            groups: [(key: "class|611.93", label: "Central Decimal File 611.93",
                      category: .centralDecimalFile, repository: nil, lotAsPrinted: nil,
                      resolution: nil,
                      documents: [
                        .init(volumeId: "frus1952-54v01p1", documentId: "d5",
                              citation: "FRUS 1952–1954 I, Document 5.",
                              fileDesignation: "611.93/12–854. Secret.",
                              sourceNote: "Source: Department of State, Central Files, "
                                + "611.93/12–854. Secret."),
                        .init(volumeId: "frus1952-54v01p1", documentId: "d6",
                              citation: "FRUS 1952–1954 I, Document 6.",
                              fileDesignation: nil,
                              sourceNote: "Source: Department of State, Central Files."),
                      ])],
            documentYears: [1954], unresolvedLotCount: 0, unresolvedDocumentCount: 0,
            researchQuestion: nil, facts: { _ in nil }, claimants: { _ in nil })
        let lines = TripPacketExporter(model: model, projectName: "P").export()
            .components(separatedBy: "\n")

        #expect(lines.contains("  - FRUS 1952–1954 I, Document 5 — file 611.93/12–854. Secret."), """
            The file line must drop the citation's period before " — file" and end in ONE period \
            even though the designation brings its own. Seeding lines were: \
            \(lines.filter { $0.hasPrefix("  - ") })
            """)
        #expect(lines.contains("  - FRUS 1952–1954 I, Document 6."), """
            With no file to name, the citation stands alone and keeps its own period. Seeding \
            lines were: \(lines.filter { $0.hasPrefix("  - ") })
            """)
    }

    /// A packet built through the REAL chain — pipeline → `TripPacketDataSource` →
    /// `HistoryAtStateCitationFormatter` over the bundled manifest entry → builder — with the
    /// citations every line must continue, less their closing period.
    ///
    /// The fixture volume is `frus1952-54v01p1` so the formatter prints what a reader sees —
    /// "(Washington, D.C.: Government Printing Office, 1983)" — and so its editor list includes
    /// "William F. Sanford, Jr., and Ilana M. Stern". d41 carries a numbered footnote (3) and an
    /// unnumbered one; d41a is an id that is not `d` plus an integer, so the formatter gets no
    /// number and ends on the publication parenthetical. Both source notes cite a central file in
    /// the post-1945 narrative form, whose designation the parser returns with its marking
    /// attached ("611.93/12–854. Secret."), so both documents are drawn-from rows naming a file.
    ///
    /// d41's numbered footnote cites `Lot 99 D 999`, an invented lot that NONE of the bundled
    /// indexes answers (checked against `central-files-index.json` and `lot-claimants-index.json`,
    /// the volume-sources and collection-authority indexes), so it is the
    /// one unresolved pointed-at target and the inquiry's help-me-locate appendix prints its line.
    /// The other two footnotes cite `Lot 63 D 351`, which the bundle resolves — which is why,
    /// before this fixture changed, that appendix printed nothing and no test read it. If a
    /// future harvest ever resolves 99D999 the appendix goes quiet again, and the exact count
    /// in `realCitationJoinsCarryOnePeriod` fails rather than passing for the wrong reason.
    @MainActor
    private static func realChainPacket(
        in dir: URL
    ) async throws -> (model: TripPacketModel, numbered: String, unnumbered: String) {
        let volumeId = "frus1952-54v01p1"
        let entry = try #require(
            ManifestStore().bundledEntries.first { $0.volumeId == volumeId },
            "the bundled manifest must carry \(volumeId)")
        let pipeline = try await Self.indexedPipeline("""
            <TEI xmlns:frus="http://history.state.gov/frus/ns/1.0"><text><body>
              <div type="document" xml:id="d41" n="41">
                <head>Memorandum<note n="1" type="source" xml:id="d41fn1">Source: Department of State, Central Files, 611.93/12–854. Secret.</note></head>
                <p>Body.<note n="3" xml:id="d41fn3">Not printed. (Department of State, Lot 99 D 999, CF 1)</note>\
            <note xml:id="d41fn4">Not printed. (Department of State, Lot 63 D 351, CF 2)</note></p>
              </div>
              <div type="document" xml:id="d41a" n="41a">
                <head>Memorandum<note n="1" type="source" xml:id="d41afn1">Source: Department of State, Central Files, 611.93/12–954. Secret.</note></head>
                <p>Body.<note n="2" xml:id="d41afn2">Not printed. (Department of State, Lot 63 D 351, CF 3)</note></p>
              </div>
            </body></text></TEI>
            """, volumeId: volumeId, in: dir)

        let dataSource = TripPacketDataSource(pipeline: pipeline, manifestMap: [volumeId: entry])
        let model = await TripPacketBuilder.build(
            documents: [(volumeId, "d41"), (volumeId, "d41a")],
            researchQuestion: nil, dataSource: dataSource)

        // The teeth: the stored citations are the formatter's, period and all. Were they the
        // fallback there would be nothing to double, and every assertion on the lines would pass.
        let pointed = model.targets.flatMap(\.pointedAt)
        let drawn = model.targets.flatMap(\.drawnFrom)
        try #require(pointed.count == 3, "expected three footnote seedings, got \(pointed.count)")
        try #require(drawn.count == 2, "expected two drawn-from seedings, got \(drawn.count)")
        for citation in pointed.map(\.citation) + drawn.map(\.citation) {
            #expect(citation.hasPrefix("_Foreign Relations of the United States_, 1952–1954"),
                    "not the formatter's citation: \(citation)")
            #expect(citation.hasSuffix("."), "the formatter's citation lost its period: \(citation)")
        }
        // Each citation as the lines must continue it: the formatter's text, less its period.
        let numbered = String(try #require(drawn.first { $0.documentId == "d41" }).citation.dropLast())
        let unnumbered = String(try #require(drawn.first { $0.documentId == "d41a" }).citation.dropLast())
        #expect(numbered.hasSuffix(", Document 41"))
        #expect(unnumbered.hasSuffix("(Washington, D.C.: Government Printing Office, 1983)"))
        return (model, numbered, unnumbered)
    }

    /// **The test #1392 asked for: the four continued-citation lines, built through the REAL
    /// chain** (`realChainPacket`). Every other test here writes its citation by hand, and
    /// #1322's end-to-end test passes `manifestMap: [:]`, so its citation was the
    /// `volumeId/documentId` fallback with no period to double; that is how "Document 41.,
    /// footnote 3" shipped.
    ///
    /// Each shape is one exact line. The editor list is why the guard below names the three
    /// JOINS rather than refusing ".," anywhere: a bare `!contains("., ")` fails on real text.
    @MainActor
    @Test("Packet lines continue a real formatter citation with one period, never two (#1392)")
    func realCitationJoinsCarryOnePeriod() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("packet-1392-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let (model, numbered, unnumbered) = try await Self.realChainPacket(in: dir)
        let lines = TripPacketExporter(model: model, projectName: "Test").export()
            .components(separatedBy: "\n")

        // The house form, one expectation per shape.
        #expect(lines.contains("  - \(numbered), footnote 3."), "numbered footnote line")
        #expect(lines.contains("  - \(numbered), footnote (no printed number recorded)."),
                "unnumbered footnote line")
        #expect(lines.contains("  - \(unnumbered), footnote 2."), "no-plain-number footnote line")
        // The drawn-from line names the file number alone: the builder cuts the note's "Secret."
        // off the designation the parser returns, and the line ends in the packet's own period.
        #expect(lines.contains("  - \(numbered) — file 611.93/12–854."),
                "numbered drawn-from line: \(lines.filter { $0.contains(" — file ") })")
        #expect(lines.contains("  - \(unnumbered) — file 611.93/12–954."),
                "no-plain-number drawn-from line: \(lines.filter { $0.contains(" — file ") })")
        // The inquiry's help-me-locate appendix repeats the unresolved lot's footnote line.
        #expect(lines.contains("      \(numbered), footnote 3."), """
            The pointed-at help-me-locate appendix must print the unresolved lot's footnote line \
            in the house form. Appendix-indented lines were: \
            \(lines.filter { $0.hasPrefix("      ") })
            """)

        // The class guard, over EVERY line that carries a citation: three pointed-at seedings,
        // two drawn-from seedings, and the appendix's one. An exact count, because a guard over
        // "at least" these lines would pass with the appendix silent — as it was before.
        let citationLines = lines.filter { $0.contains("_Foreign Relations of the United States_") }
        #expect(citationLines.count == 6, "the guard read \(citationLines.count) lines")
        for line in citationLines {
            for join in ["., footnote", ". — file", ".; "] {
                #expect(!line.contains(join), "\"\(join)\" — a citation's period doubled: \(line)")
            }
        }
    }

    /// The citation appendix interpolates a designation into NARA's template, mid-sentence, so it
    /// must be the file number alone. Built through the real chain, where the parser returns
    /// "611.93/12–854. Secret." for the note's designation: the appendix used to print "file
    /// 611.93/12–854. Secret., Central Decimal File, RG 59 …" — the ".," join #1392 removes
    /// elsewhere, with a classification marking inside a citation.
    @MainActor
    @Test("The citation appendix's template carries the file number, not the note's marking")
    func citationCribCarriesTheFileNumberAlone() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("packet-crib-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let (model, _, _) = try await Self.realChainPacket(in: dir)
        var withCrib = TripPacketExporter(model: model, projectName: "Test")
        withCrib.deliverables.includeCitationCrib = true
        let text = withCrib.export()
        let crib = try #require(text.components(separatedBy: "## Citing what you find").last,
                                "the appendix is on, so its heading must print")
        let prefill = crib.components(separatedBy: "\n")
            .filter { $0.hasPrefix("  ⟨Sender⟩") && $0.contains("Central Decimal File") }
        try #require(prefill.count == 1, "one decimal template line, got \(prefill)")
        #expect(prefill[0].contains(", file 611.93/12–854, "),
                "the template must name the file number alone: \(prefill[0])")
        #expect(!prefill[0].contains("Secret"),
                "a classification marking is not part of a citation: \(prefill[0])")
        #expect(!prefill[0].contains(".,"), "a designation continued with \".,\": \(prefill[0])")
    }

    /// Indexes one fixture volume into a fresh database and returns its pipeline — the
    /// `ExternalCitationTests` recipe, so the packet reads exactly what a real index stores.
    private static func indexedPipeline(_ xml: String, volumeId: String,
                                        in dir: URL) async throws -> IndexingPipeline {
        let volumes = dir.appendingPathComponent("volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        try Data(xml.utf8).write(to: volumes.appendingPathComponent("\(volumeId).xml"))
        let dbURL = dir.appendingPathComponent("test.sqlite")
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: dbURL,
                                            volumesDirectory: volumes, concurrencyLimit: 1)
        try await pipeline.indexVolume(volumeId)
        return pipeline
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
        // The citation line above it, whole: this list repeats the footnote line, and a join
        // made here instead of through `footnoteLine(for:)` printed "Document 42., footnote 5"
        // with every other assertion in this test still passing (#1392 review).
        #expect(inquiry.contains("\n      FRUS 1948 II, Document 42, footnote 5.\n"), """
            The help-me-locate list must quote the footnote in the house form. Its lines were: \
            \(inquiry.components(separatedBy: "\n").filter { $0.hasPrefix("      ") })
            """)
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
        withCrib.deliverables.includeCitationCrib = true
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
        withCrib.deliverables.includeCitationCrib = true
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
