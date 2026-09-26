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

// MARK: - ResearchFacilityTests

/// Pins the trip packet's facility derivation (#830 T-1, decisions D2 and D3).
///
/// The governing constraint is not a behaviour but a prohibition: **T-1 may not print an
/// institutional fact the owner has not confirmed.** Most of what follows tests that the resolver
/// declines to answer, which is a strange-looking suite until you notice that a fabricated address
/// is the failure this whole workstream exists to prevent — a researcher who flies somewhere on a
/// sentence the app invented has lost the trip.
///
/// Version history:
///   1.0 — Session 2026-08-22: #830 T-1
///   1.1 — 2026-09-25: #1458/#1459 — a presidential library with a curated row resolves to that
///          row (the owner's decision that a library is a repository, everywhere), and
///          `libraryDoesNotGuess` changes deliberately, as its own message said it would; review,
///          round 1: the library walk guards on "not empty" rather than "ten" (D14), and the
///          National Archives case is the drawn-from citation the corpus prints, not a footnote
@Suite("Research facility derivation (#830 T-1)")
struct ResearchFacilityTests {

    // MARK: - D2: derive from NARA's own reference unit

    /// The premise D2 scoped the curation against, checked against the shipped artifact rather
    /// than quoted from the plan.
    @MainActor
    @Test("NARA's reference unit answers for essentially every series")
    func referenceUnitAnswersForNearlyEverySeries() throws {
        let index = try #require(SeriesFactsIndexStore.shared,
                                 "series-facts-index.json must decode from the app bundle")
        var withUnit = 0, total = 0, collegePark = 0
        for naId in index.byNaId.keys {
            guard let facts = index.facts(forNaId: naId) else { continue }
            total += 1
            guard let unit = facts.referenceUnit, !unit.isEmpty else { continue }
            withUnit += 1
            if ResearchFacilityResolver.normalisedReferenceUnit(unit)
                == ResearchFacilityResolver.collegePark { collegePark += 1 }
        }
        #expect(total > 600, "expected the ~695-series index; got \(total)")
        #expect(withUnit == total, """
            \(total - withUnit) series carry no reference unit. D2 scoped hand-curation to the tail \
            on the basis that the NARA side is DATA; a gap here moves rows back into curation.
            """)
        #expect(collegePark >= total - 2, """
            Only \(collegePark) of \(total) series serve at College Park. Measured at 694 of 695 \
            when D2 was decided — if that has spread, the packet needs more than one NARA chapter.
            """)
    }

    /// The derived path, driven through the real resolver against a real NAID.
    @MainActor
    @Test("A series NAID resolves to its reference unit, suffix dropped")
    func seriesNaIdDerivesItsFacility() throws {
        let index = try #require(SeriesFactsIndexStore.shared)
        let naId = try #require(index.byNaId.keys.sorted().first)
        let facility = ResearchFacilityResolver.facility(
            naId: naId, category: .lotFile, repository: nil,
            facts: { index.facts(forNaId: $0) })
        #expect(facility == .derived(facility: ResearchFacilityResolver.collegePark), """
            Got \(facility). A series with a reference unit must derive from it — that is the half \
            of D2 that is data rather than curation.
            """)
        #expect(facility.chapterHeading == ResearchFacilityResolver.collegePark)
    }

    /// The suffix names a reading room, not a building. Dropping it is deliberate.
    @Test("The reference unit's service suffix is dropped, not mapped")
    func serviceSuffixIsDropped() {
        #expect(ResearchFacilityResolver.normalisedReferenceUnit(
            "National Archives at College Park - Textual Reference") == "National Archives at College Park")
        #expect(ResearchFacilityResolver.normalisedReferenceUnit(
            "National Archives at College Park - Motion Pictures") == "National Archives at College Park")
        #expect(ResearchFacilityResolver.normalisedReferenceUnit("Somewhere Else") == "Somewhere Else",
                "a unit with no suffix must survive intact")
    }

    // MARK: - D3: agencies are provenance, never destinations

    @Test("A creating agency routes to where the records are served, and is named as provenance")
    func agencyStringsRouteToCollegePark() {
        for spelling in ["Department of State", "department of state", "  State Department  "] {
            let facility = ResearchFacilityResolver.facility(
                naId: nil, category: nil, repository: spelling, facts: { _ in nil })
            #expect(facility == .servedAt(facility: ResearchFacilityResolver.collegePark,
                                          provenance: "Department of State"), """
                "\(spelling)" resolved to \(facility). D3: the agency is provenance and never a \
                destination — no reader can visit "Department of State".
                """)
        }
    }

    /// CIA-cited material is read as CREST at NACP, not at CIA — the case D3 calls out by name.
    @Test("CIA citations are served at College Park")
    func ciaRoutesToCollegePark() {
        let facility = ResearchFacilityResolver.facility(
            naId: nil, category: .intelligence, repository: nil, facts: { _ in nil })
        #expect(facility == .servedAt(facility: ResearchFacilityResolver.collegePark,
                                      provenance: "Central Intelligence Agency"))
        #expect(facility.chapterHeading == ResearchFacilityResolver.collegePark)
    }

    /// A records centre is a real institution and still may not head a chapter.
    @Test("A records centre asks for confirmation and heads nothing")
    func recordsCentreHeadsNoChapter() {
        let facility = ResearchFacilityResolver.facility(
            naId: nil, category: nil, repository: "Washington National Records Center",
            facts: { _ in nil })
        #expect(facility == .confirmBeforeTravelling(named: "Washington National Records Center"))
        #expect(facility.chapterHeading == nil, """
            A records centre produced a chapter heading. D3 forbids it: the records may since have \
            been accessioned, so sending a researcher there is sending them to the wrong building.
            """)
    }

    /// The 72.9% case, and it has no repository string to key on.
    @Test("Record-group material derives its facility from the category alone")
    func centralFilesResolveWithoutARepositoryString() {
        for category in [SourceProvenanceCategory.centralDecimalFile, .centralForeignPolicyFile,
                         .lotFile, .naraCollection, .namedFileSeries] {
            let facility = ResearchFacilityResolver.facility(
                naId: nil, category: category, repository: nil, facts: { _ in nil })
            #expect(facility == .servedAt(facility: ResearchFacilityResolver.collegePark,
                                          provenance: "Department of State"), """
                \(category.rawValue) resolved to \(facility) with no repository string. Central \
                files alone are 72.9% of the corpus's notes, and keying on a string that is usually \
                absent would leave most of the packet unplaced. An UNRESOLVED lot file belongs here \
                too: not knowing its series is not the same as not knowing its building, and filing \
                it under "confirm where these are" would give the wrong advice for a record whose \
                location is not in doubt.
                """)
        }
    }

    // MARK: - The prohibition, and the curated libraries (#1458, #1459)

    /// **The most important test here, changed deliberately.** Until 2026-09-25 a library resolved
    /// to `unknown` "until its row is curated", and this test said it would change when the table
    /// landed. The table has carried the ten library rows since 2026-08-23 (#1062; every link
    /// re-verified and stamped 2026-08-28), and the owner's decision of 2026-09-25 is that a
    /// presidential library IS a repository, everywhere:
    /// it heads its own section in the editor and its own chapter in the packet, under the row's
    /// display name. The heading is the ROW's name, never the citation's spelling — no chapter is
    /// headed with a string the owner has not confirmed names a place.
    @Test("A presidential library with a curated row resolves to that row")
    func libraryResolvesToItsCuratedRow() {
        let facility = ResearchFacilityResolver.facility(
            naId: nil, category: .presidentialLibrary, repository: "Truman Library",
            facts: { _ in nil })
        #expect(facility == .curated(repository: "Harry S. Truman Presidential Library"), """
            A library with a curated row resolved to \(facility). Owner decision, 2026-09-25: a \
            presidential library is a repository — the editor already filed it under the row's \
            name, and the packet must file it in the same place (#1459).
            """)
        #expect(facility.chapterHeading == "Harry S. Truman Presidential Library")
    }

    /// Every shipping library resolves under its own row, and its heading finds that row again.
    ///
    /// The second half is load-bearing: the packet's chapter and draft and the editor's section
    /// header find their links by looking the HEADING up (`row(forHeading:)`), so a heading that
    /// did not lead back to its own row would head a chapter with another repository's links, or
    /// none. Display names must therefore be unique across the table.
    ///
    /// The guard asks only that there be libraries to walk, so the loop is never vacuous. It does
    /// not count them: nothing may encode "ten", because adding Clinton later is one row and no
    /// other change (D14, `RepositoryFactTable.presidentialLibraries`).
    @Test("Every curated library's heading leads back to its own row")
    func everyLibraryHeadingRoundTrips() throws {
        let table = RepositoryFactTable.current
        try #require(!RepositoryFactTable.presidentialLibraries.isEmpty,
                     "no library rows to walk — this test would pass vacuously")
        #expect(Set(table.rows.map(\.displayName)).count == table.rows.count,
                "two rows share a display name, so a heading cannot say which it means")
        for row in RepositoryFactTable.presidentialLibraries {
            let facility = ResearchFacilityResolver.facility(
                naId: nil, category: .presidentialLibrary, repository: row.id, facts: { _ in nil })
            #expect(facility == .curated(repository: row.displayName),
                    "\(row.id) resolved to \(facility)")
            #expect(table.row(forHeading: row.displayName)?.id == row.id, """
                "\(row.displayName)" leads to \(table.row(forHeading: row.displayName)?.id ?? "no row"), \
                not \(row.id) — its chapter would print another repository's links, or none.
                """)
        }
    }

    /// A heading is matched exactly, never folded: the fold reads any "National Archives at …"
    /// as College Park, so a regional facility's chapter and draft would print College Park's
    /// pages, address and email. No shipped data reaches that case (both reference units in
    /// `series-facts-index.json` are College Park's); `TripPacketExporterTests
    /// .facilityWithoutARowSaysSo` pins the packet's two call sites.
    @Test("A chapter heading finds its row by exact name, not by the fold")
    func headingLookupIsExact() {
        let table = RepositoryFactTable.current
        #expect(table.row(for: "National Archives at Kansas City")?.id
                == ResearchFacilityResolver.collegePark,
                "fixture premise: the fold answers a regional facility with College Park's row")
        #expect(table.row(forHeading: "National Archives at Kansas City") == nil)
        #expect(table.row(forHeading: ResearchFacilityResolver.collegePark)?.id
                == ResearchFacilityResolver.collegePark)
    }

    /// A library the owner has not curated still says the app cannot tell — D14's "not yet".
    @Test("A presidential library with no curated row still resolves to unknown")
    func uncuratedLibraryDoesNotGuess() {
        let facility = ResearchFacilityResolver.facility(
            naId: nil, category: .presidentialLibrary, repository: "Clinton Library",
            facts: { _ in nil })
        #expect(facility == .unknown, """
            A library with NO curated row resolved to \(facility). Only a row the owner confirmed \
            may name a place; the citation's own spelling is not one.
            """)
        #expect(facility.chapterHeading == nil)
    }

    /// The rule reads the table it is given, not the shipping one — so a test, and the model's
    /// own `table:` parameter, drive the real rule.
    @Test("The resolver reads the injected table")
    func resolverReadsTheInjectedTable() {
        let facility = ResearchFacilityResolver.facility(
            naId: nil, category: .presidentialLibrary, repository: "Truman Library",
            facts: { _ in nil }, table: RepositoryFactTable(rows: []))
        #expect(facility == .unknown, "an empty table curates nothing; got \(facility)")
    }

    /// A foreign archive is never curated, even when the table's fold would match it: the fold
    /// reads any string containing "National Archives" as College Park, and a foreign national
    /// archive is not College Park.
    ///
    /// DEFENSIVE, and the fixture is not shipped data: `IndexingPipeline.baseDocumentSourceRow`
    /// stores a foreign-government archive with NO repository, and a footnote reference is never
    /// typed `.foreignArchive`, so no shipped citation reaches step 3 with a string to fold. The
    /// guard is for a future parser that captures the archive's name.
    @Test("A foreign archive is never filed under a curated row")
    func foreignArchiveIsNeverCurated() {
        #expect(RepositoryFactTable.current.row(for: "National Archives of Australia")?.id
                == ResearchFacilityResolver.collegePark,
                "fixture premise: the fold matches this string to the College Park row")
        let facility = ResearchFacilityResolver.facility(
            naId: nil, category: .foreignArchive, repository: "National Archives of Australia",
            facts: { _ in nil })
        #expect(facility == .unknown, """
            A foreign archive resolved to \(facility) — it would head College Park's chapter and \
            join its inquiry to NARA.
            """)
    }

    /// The editor's old fallback, kept at the source: a citation the parser could not classify
    /// that names a curated repository is filed there, as the editor always filed it.
    @Test("An unclassified citation naming a curated repository is filed there")
    func unclassifiedCitationNamingACuratedRowIsFiled() {
        let facility = ResearchFacilityResolver.facility(
            naId: nil, category: nil, repository: "Truman Library", facts: { _ in nil })
        #expect(facility == .curated(repository: "Harry S. Truman Presidential Library"),
                "got \(facility)")
    }

    /// A source note the parser reads in the library form but whose repository names the National
    /// Archives is typed `.presidentialLibrary` — `SourceProvenanceCategory.from` keeps
    /// `.naraCollection` for the exact string "National Archives" alone — and its curated row is
    /// College Park's, so it heads the SAME chapter as the College Park lots: one section and one
    /// draft. The July source-explorer export carries 3 such notes, naming "National Archives and
    /// Records Administration". (A footnote cannot reach this: the footnote grammar captures only
    /// a presidential library's name or the Hoover Institution.)
    @Test("A library-form citation naming the National Archives shares College Park's chapter")
    func nationalArchivesReferenceSharesCollegePark() {
        let facility = ResearchFacilityResolver.facility(
            naId: nil, category: .presidentialLibrary,
            repository: "National Archives and Records Administration", facts: { _ in nil })
        #expect(facility.chapterHeading == ResearchFacilityResolver.collegePark, "got \(facility)")
    }

    /// The same for a foreign archive, and for anything unparsed.
    @Test("Unresolvable citations say so rather than reprinting themselves")
    func unresolvableCitationsAreUnknown() {
        for (category, repository) in [(SourceProvenanceCategory.foreignArchive, "Public Record Office"),
                                       (.unrecognized, nil),
                                       (.previouslyPublished, nil)] as [(SourceProvenanceCategory, String?)] {
            let facility = ResearchFacilityResolver.facility(
                naId: nil, category: category, repository: repository, facts: { _ in nil })
            #expect(facility == .unknown, "\(category.rawValue) resolved to \(facility)")
            #expect(facility.chapterHeading == nil, """
                \(category.rawValue) produced a chapter heading. No chapter may be headed with a \
                string that names no place a researcher can be served.
                """)
        }
    }

    /// Data beats the rules: a citation that reached a series uses NARA's answer even when its
    /// category would otherwise route it.
    @MainActor
    @Test("A resolved series wins over the category route")
    func derivedBeatsCategory() throws {
        let index = try #require(SeriesFactsIndexStore.shared)
        let naId = try #require(index.byNaId.keys.sorted().first)
        let facility = ResearchFacilityResolver.facility(
            naId: naId, category: .presidentialLibrary, repository: "Truman Library",
            facts: { index.facts(forNaId: $0) })
        #expect(facility == .derived(facility: ResearchFacilityResolver.collegePark), """
            Got \(facility). When NARA has stated a reference unit for the series, that is data and \
            outranks every inference below it.
            """)
    }
}
