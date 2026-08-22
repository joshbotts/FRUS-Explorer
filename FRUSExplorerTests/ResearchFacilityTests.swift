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
    @Test("State's central files derive their facility from the category alone")
    func centralFilesResolveWithoutARepositoryString() {
        for category in [SourceProvenanceCategory.centralDecimalFile, .centralForeignPolicyFile] {
            let facility = ResearchFacilityResolver.facility(
                naId: nil, category: category, repository: nil, facts: { _ in nil })
            #expect(facility == .servedAt(facility: ResearchFacilityResolver.collegePark,
                                          provenance: "Department of State"), """
                \(category.rawValue) resolved to \(facility) with no repository string. This is \
                72.9% of the corpus's notes; keying it on a string that is usually absent would \
                leave most of the packet unplaced.
                """)
        }
    }

    // MARK: - The prohibition

    /// **The most important test here.** A presidential library wants a curated row, the owner has
    /// not confirmed one, and T-1 may not invent it.
    @Test("A presidential library resolves to unknown until its row is curated")
    func libraryDoesNotGuess() {
        let facility = ResearchFacilityResolver.facility(
            naId: nil, category: .presidentialLibrary, repository: "Truman Library",
            facts: { _ in nil })
        #expect(facility == .unknown, """
            A library resolved to \(facility). D2 scopes libraries to hand-curation and T-1 may not \
            print an unconfirmed institutional fact — so the honest answer is that the app cannot \
            say yet. When the curated table lands, this test changes deliberately.
            """)
        #expect(facility.chapterHeading == nil)
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
