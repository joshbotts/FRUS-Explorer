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

/// The app side of the POCOM career index and the schema-v2 authority fields (#736).
///
/// The JSON is the contract between the generator and the app, so these decode the shapes the
/// generator actually emits — including a schema-v1 file, which must keep working, since a build
/// can ship either.
///
/// Version history:
///   1.0 — Session 2026-08-07: #736
///   1.1 — 2026-09-13: POCOM index version 2 — the `chiefs`, `names` and `roles` tables, and the
///         bundled Dayton row the Source Explorer addressee rule depends on
///   1.2 — 2026-09-23 (#1370): the lifespan tests drive `PersonLifespan`, the sheet's one lifespan
///         line, now that `POCOMCareer.lifespanText` is gone; `PersonLifespanTests` pins its order
///         of sources
@Suite("POCOM index and authority schema v2")
struct POCOMIndexTests {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    // MARK: - Authority schema tolerance

    @Test("A schema-v1 authority file still decodes, with the v2 fields absent")
    func decodesSchemaV1() throws {
        // The shipped v1 file carried only n/b/d/v. A build that regressed on this would lose the
        // whole crosswalk, not merely the career section.
        let index = try decode(PersonAuthorityIndex.self, """
            {"version":1,"generated":"2026-06-18","source":"HistoryAtState/people",
             "crosswalk":{"frus1952-54v01":{"p_AD1":100001}},
             "authority":{"100001":{"n":"Acheson, Dean","b":1893,"d":1971}}}
            """)
        #expect(index.version == 1)
        #expect(index.canonicalId(volumeId: "frus1952-54v01", ref: "p_AD1") == 100001)
        let entry = try #require(index.entry(for: 100001))
        #expect(entry.n == "Acheson, Dean")
        #expect(entry.s == nil)
        #expect(entry.q == nil)
        #expect(index.pocomSlug(for: 100001) == nil)
    }

    @Test("A schema-v2 file exposes the slug, Wikidata and role text")
    func decodesSchemaV2() throws {
        let index = try decode(PersonAuthorityIndex.self, """
            {"version":2,"generated":"2026-08-07","source":"…",
             "crosswalk":{"frus1952-54v01":{"p_AD1":100001}},
             "authority":{"100001":{"n":"Acheson, Dean","b":1893,"d":1971,
               "v":"12345","s":"acheson-dean-gooderham","q":"Q193236",
               "r":"Secretary of State"}}}
            """)
        #expect(index.version == 2)
        let entry = try #require(index.entry(for: 100001))
        #expect(entry.s == "acheson-dean-gooderham")
        #expect(entry.q == "Q193236")
        #expect(entry.r == "Secretary of State")
        #expect(index.pocomSlug(for: 100001) == "acheson-dean-gooderham")
    }

    @Test("An empty slug reads as no slug, not as a lookup key")
    func emptySlugIsNoSlug() throws {
        // An empty string would send `career(forSlug:)` looking for "" and return nothing anyway,
        // but it would also make `authorityEntry?.s` non-nil and render an empty Career section.
        let index = try decode(PersonAuthorityIndex.self, """
            {"version":2,"crosswalk":{},"authority":{"1":{"n":"X","s":""}}}
            """)
        #expect(index.pocomSlug(for: 1) == nil)
    }

    @Test("Identifier URLs are built only when the identifier is there")
    func identifierURLs() throws {
        let index = try decode(PersonAuthorityIndex.self, """
            {"version":2,"crosswalk":{},"authority":{
              "1":{"n":"A","v":"12345","q":"Q193236"},
              "2":{"n":"B"}}}
            """)
        let withIds = try #require(index.entry(for: 1))
        #expect(withIds.wikidataURL?.absoluteString == "https://www.wikidata.org/wiki/Q193236")
        #expect(withIds.viafURL?.absoluteString == "https://viaf.org/viaf/12345")
        let without = try #require(index.entry(for: 2))
        #expect(without.wikidataURL == nil)
        #expect(without.viafURL == nil)
    }

    // MARK: - POCOM index

    /// Acheson's real record from the shipped artifact, trimmed to three posts.
    private let achesonJSON = """
        {"version":1,"generated":"2026-08-07","source":"HistoryAtState/pocom",
         "careers":{"acheson-dean-gooderham":{
           "n":"Acheson, Dean Gooderham","b":1893,"d":1971,
           "a":[{"r":"Assistant Secretary of State","ap":"1941-01-31","st":"1941-02-01"},
                {"r":"Under Secretary of State","ap":"1945-08-16","st":"1945-08-16","en":"1947-06-30"},
                {"r":"Secretary of State","ap":"1949-01-19","st":"1949-01-21","en":"1953-01-20"}]}}}
        """

    @Test("A career decodes with its assignments in the generator's order")
    func decodesCareer() throws {
        let index = try decode(POCOMIndex.self, achesonJSON)
        let career = try #require(index.career(forSlug: "acheson-dean-gooderham"))
        #expect(career.n == "Acheson, Dean Gooderham")
        #expect(career.b == 1893)
        #expect(career.a.map(\.r) == ["Assistant Secretary of State",
                                      "Under Secretary of State",
                                      "Secretary of State"])
        #expect(index.career(forSlug: "nobody") == nil)
    }

    @Test("An assignment shows the service span, not the appointment date, when it has both")
    func prefersServiceDates() throws {
        // The question beside a document is who held the post *then*, not when the paperwork was
        // signed — Acheson was appointed 1949-01-19 and took office 1949-01-21.
        let index = try decode(POCOMIndex.self, achesonJSON)
        let career = try #require(index.career(forSlug: "acheson-dean-gooderham"))
        let secretary = try #require(career.a.last)
        #expect(secretary.dateRangeText == "1949-01-21 – 1953-01-20")
    }

    @Test("A one-sided or absent date range reads correctly")
    func partialDateRanges() {
        let openEnded = POCOMAssignment(r: "Ambassador", p: "France", ap: nil,
                                        st: "1961-03-01", en: nil, nt: nil)
        #expect(openEnded.dateRangeText == "from 1961-03-01")

        let endOnly = POCOMAssignment(r: "Consul", p: "Peru", ap: nil, st: nil,
                                      en: "1899", nt: nil)
        #expect(endOnly.dateRangeText == "until 1899")

        let undated = POCOMAssignment(r: "Consul", p: "Peru", ap: nil, st: nil, en: nil, nt: nil)
        #expect(undated.dateRangeText == nil, "no invented dates for an undated post")

        // Falls back to the appointment date when the register has no service date.
        let appointedOnly = POCOMAssignment(r: "Minister", p: "Siam", ap: "1882",
                                            st: nil, en: nil, nt: nil)
        #expect(appointedOnly.dateRangeText == "from 1882")
    }

    @Test("Partial dates are shown as the register writes them")
    func partialDatesAreNotReformatted() {
        // The register records "1935" with no month for many early appointments. Any formatter
        // would have to invent the missing precision.
        let bareYear = POCOMAssignment(r: "Minister", p: "Siam", ap: nil, st: "1882",
                                       en: "1885", nt: nil)
        #expect(bareYear.dateRangeText == "1882 – 1885")
    }

    @Test("A post inside the Department shows no place")
    func departmentPostHasNoPlace() {
        let principal = POCOMAssignment(r: "Under Secretary of State", p: nil, ap: nil,
                                        st: "1945", en: nil, nt: nil)
        #expect(principal.titleText == "Under Secretary of State")

        let abroad = POCOMAssignment(r: "Ambassador", p: "France", ap: nil, st: nil,
                                     en: nil, nt: nil)
        #expect(abroad.titleText == "Ambassador — France")

        // Defensive: the shipped artifact carries no empty place strings, but the JSON contract
        // permits one, and it would render as a title with a dangling em dash.
        let emptyPlace = POCOMAssignment(r: "Ambassador", p: "", ap: nil, st: nil,
                                         en: nil, nt: nil)
        #expect(emptyPlace.titleText == "Ambassador")
    }

    @Test("Two posts sharing a role title are still two rows")
    func repeatedRoleTitlesKeepDistinctIdentities() throws {
        // Not hypothetical: **394 of the shipped index's 1,240 careers (32%) repeat a role
        // title**, because an ambassador is an ambassador wherever they are sent. Abramowitz is
        // one — Thailand 1978, Turkey 1989 — and an id keyed on the title alone collapses a third
        // of everyone's career to a single row.
        let index = try decode(POCOMIndex.self, """
            {"version":1,"careers":{"abramowitz-morton-isaac":{
              "n":"Abramowitz, Morton Isaac",
              "a":[{"r":"Ambassador Extraordinary and Plenipotentiary","p":"Thailand",
                    "ap":"1978-06-27","st":"1978-08-09","en":"1981-07-31","nt":"Left post on"},
                   {"r":"Ambassador Extraordinary and Plenipotentiary","p":"Turkey",
                    "ap":"1989-06-23","st":"1989-08-01","en":"1991-07-25","nt":"Left post on"}]}}}
            """)
        let career = try #require(index.career(forSlug: "abramowitz-morton-isaac"))
        #expect(career.a.count == 2)
        #expect(Set(career.a.map(\.id)).count == 2, "ForEach would render one row, not two")
    }

    @Test("Assignments in one career have distinct identities")
    func assignmentIdsAreDistinct() throws {
        let index = try decode(POCOMIndex.self, achesonJSON)
        let career = try #require(index.career(forSlug: "acheson-dean-gooderham"))
        #expect(Set(career.a.map(\.id)).count == career.a.count)
    }

    // MARK: - Year formatting

    @Test("A lifespan never carries a thousands separator")
    func lifespanHasNoGroupingSeparator() throws {
        // The shipped bug: the Career footer read "1,893–1,971". `String(localized:)` interpolates
        // an Int through a number formatter; plain Swift interpolation does not, which is why the
        // People list's own `role · era` subtitles were always right and this line was not.
        //
        // This drives `PersonLifespan.text` — the real emitter, and since #1370 the sheet's only
        // lifespan line — not a re-implementation. The career alone reaches it here.
        let index = try decode(POCOMIndex.self, achesonJSON)
        let acheson = try #require(index.career(forSlug: "acheson-dean-gooderham"))
        let line = PersonLifespan.text(authority: nil, career: acheson)
        #expect(line == "1893–1971")
        #expect(!(line ?? "").contains(","))

        // The guard is not vacuous: unformatted interpolation really does group on this platform.
        #expect(String(localized: "test.year.grouped", defaultValue: "\(1893)") != "1893",
                "if this ever equals 1893 the platform stopped grouping and the fix is moot")
    }

    @Test("A one-sided or absent lifespan reads correctly, still ungrouped")
    func partialLifespans() throws {
        func career(_ born: Int?, _ died: Int?) throws -> POCOMCareer {
            try decode(POCOMCareer.self, """
                {"n":"X","a":[]\(born.map { ",\"b\":\($0)" } ?? "")\(died.map { ",\"d\":\($0)" } ?? "")}
                """)
        }
        // Capitalised since #1370, because the line now stands alone under the name rather than
        // beginning a footer.
        func line(_ born: Int?, _ died: Int?) throws -> String? {
            PersonLifespan.text(authority: nil, career: try career(born, died))
        }
        #expect(try line(1893, nil) == "Born 1893")
        #expect(try line(nil, 1971) == "Died 1971")
        #expect(try line(nil, nil) == nil)
        #expect(try !(line(1893, nil) ?? "").contains(","))
    }

    @Test("A malformed or empty index decodes to no careers rather than throwing")
    func tolerantDecoding() throws {
        // The store returns nil on a decode failure and the section disappears; a partial file
        // should behave the same way rather than crashing a detail sheet.
        let empty = try decode(POCOMIndex.self, "{}")
        #expect(empty.careers.isEmpty)
        #expect(empty.version == 1)
        #expect(empty.career(forSlug: "anyone") == nil)
    }

    @Test("The authority decoder tolerates every field being absent")
    func authorityDecoderIsFullyTolerant() throws {
        // The whole point of the hand-written initializer: a file missing `version`, `crosswalk`
        // or `authority` must degrade to an empty index, never fail to decode and take the
        // crosswalk down with it.
        let bare = try decode(PersonAuthorityIndex.self, "{}")
        #expect(bare.version == 1)
        #expect(bare.crosswalk.isEmpty)
        #expect(bare.authority.isEmpty)
        #expect(bare.generated.isEmpty)

        let noVersion = try decode(PersonAuthorityIndex.self, """
            {"crosswalk":{"frus1952-54v01":{"p_A1":1}},"authority":{"1":{"n":"X"}}}
            """)
        #expect(noVersion.version == 1, "defaults rather than throwing")
        #expect(noVersion.canonicalId(volumeId: "frus1952-54v01", ref: "p_A1") == 1)
    }

    // MARK: - Chiefs of mission (version 2)

    /// A version-2 file in the generator's own shape: sorted keys, and absent dates omitted.
    private func chiefsIndex(_ rows: String, names: String) throws -> POCOMIndex {
        try decode(POCOMIndex.self, """
            {"careers":{},"chiefs":{"mexico":[\(rows)]},"generated":"2026-09-13",
             "names":{\(names)},
             "roles":{"envoy-extraordinary-minister-plenipotentiary":"Envoy Extraordinary and Minister Plenipotentiary"},
             "source":"HistoryAtState/pocom (CC0 / public domain), checkout test","version":2}
            """)
    }

    @Test("A version-2 file decodes its chiefs, names and roles into a resolved chief of mission")
    func decodesV2Chiefs() throws {
        // Dayton's real row from the register, as the generator writes it.
        let index = try decode(POCOMIndex.self, """
            {"careers":{},"chiefs":{"france":[{"ap":"1861-03-18","en":"1864-12-01",
               "r":"envoy-extraordinary-minister-plenipotentiary","s":"dayton-william-lewis","st":"1861-05-19"}]},
             "generated":"2026-09-13",
             "names":{"dayton-william-lewis":{"a":"William L. Dayton","fn":"William Lewis","sn":"Dayton"}},
             "roles":{"envoy-extraordinary-minister-plenipotentiary":"Envoy Extraordinary and Minister Plenipotentiary"},
             "source":"HistoryAtState/pocom (CC0 / public domain), checkout test","version":2}
            """)
        #expect(index.version == 2)
        #expect(index.chiefTerritoryIds == ["france"])
        #expect(index.chiefs(territoryId: "france") == [POCOMChiefOfMission(
            slug: "dayton-william-lewis", surname: "Dayton", forename: "William Lewis",
            displayName: "William L. Dayton",
            roleLabel: "Envoy Extraordinary and Minister Plenipotentiary", territoryId: "france",
            firstDayISO: "1861-03-18", lastDayISO: "1864-12-01")])
        #expect(index.chiefs(territoryId: "spain").isEmpty)
    }

    @Test("A partial end date ceils to the last day of its month or year")
    func partialEndCeilsToMonthEnd() throws {
        // April has 30 days, so a ceiling that always answers the 31st fails here. Both rows state
        // a full appointment date, so only the end differs in shape.
        let index = try chiefsIndex("""
            {"ap":"1864-04-01","en":"1866-04","r":"envoy-extraordinary-minister-plenipotentiary","s":"corwin-thomas"},
            {"ap":"1861-02-01","en":"1864","r":"envoy-extraordinary-minister-plenipotentiary","s":"year-end"}
            """, names: """
            "corwin-thomas":{"fn":"Thomas","sn":"Corwin"},"year-end":{"fn":"Year","sn":"End"}
            """)
        let chiefs = index.chiefs(territoryId: "mexico")
        #expect(chiefs.map(\.slug) == ["corwin-thomas", "year-end"])
        #expect(chiefs.first { $0.slug == "corwin-thomas" }?.lastDayISO == "1866-04-30")
        #expect(chiefs.first { $0.slug == "year-end" }?.lastDayISO == "1864-12-31")
    }

    @Test("A partial start date floors to the first day of its month or year")
    func partialStartFloorsToMonthStart() throws {
        // The register's own shape: mx-1864-corw-01 states only `st: 1864-04`, and it is the second Corwin in the
        // Mexico collision. A floor that filled in the month's LAST day would open the tenure weeks late.
        let index = try chiefsIndex("""
            {"en":"1866-04","r":"envoy-extraordinary-minister-plenipotentiary","s":"corwin-william-henry","st":"1864-04"},
            {"ap":"1866","en":"1867-01-01","r":"envoy-extraordinary-minister-plenipotentiary","s":"year-start"}
            """, names: """
            "corwin-william-henry":{"a":"William H. Corwin","fn":"William Henry","sn":"Corwin"},"year-start":{"fn":"Year","sn":"Start"}
            """)
        let chiefs = index.chiefs(territoryId: "mexico")
        #expect(chiefs.map(\.slug) == ["corwin-william-henry", "year-start"])
        #expect(chiefs.first { $0.slug == "corwin-william-henry" }?.firstDayISO == "1864-04-01")
        #expect(chiefs.first { $0.slug == "year-start" }?.firstDayISO == "1866-01-01")
    }

    @Test("A row with no end and no derived end has no last day; a derived end supplies one")
    func nilLastDayWhenNoEnd() throws {
        // The two rows differ only in `ex`.
        let index = try chiefsIndex("""
            {"ap":"1890-12-11","r":"envoy-extraordinary-minister-plenipotentiary","s":"open-ended"},
            {"ap":"1890-12-11","ex":"1891-06-30","r":"envoy-extraordinary-minister-plenipotentiary","s":"derived-end"}
            """, names: """
            "open-ended":{"fn":"Open","sn":"Ended"},"derived-end":{"fn":"Derived","sn":"End"}
            """)
        let chiefs = index.chiefs(territoryId: "mexico")
        let open = try #require(chiefs.first { $0.slug == "open-ended" })
        #expect(open.lastDayISO == nil)
        #expect(open.firstDayISO == "1890-12-11")
        let derived = try #require(chiefs.first { $0.slug == "derived-end" })
        #expect(derived.lastDayISO == "1891-06-30")
    }

    @Test("A version-1 file still decodes, with empty chiefs, names and roles")
    func v1FileStillDecodesWithEmptyChiefs() throws {
        let index = try decode(POCOMIndex.self, achesonJSON)
        #expect(index.version == 1)
        #expect(index.career(forSlug: "acheson-dean-gooderham") != nil, "fixture guard: careers decoded")
        #expect(index.chiefs.isEmpty)
        #expect(index.names.isEmpty)
        #expect(index.roles.isEmpty)
        #expect(index.chiefTerritoryIds.isEmpty)
        #expect(index.chiefs(territoryId: "france").isEmpty)
    }

    @Test("The bundled index names Dayton as the chief of mission to France on 1863-11-10")
    func bundledStoreCarriesDayton() throws {
        // Through the store, not a #filePath read, so a resource missing from the bundle fails.
        // frus1863p2/d573 ("Mr. Seward to Mr. Dayton", 10 November 1863) is the type case.
        let index = try #require(POCOMIndexStore.shared, "pocom-index.json should be bundled and decodable")
        let date = "1863-11-10"
        let daytons = index.chiefs(territoryId: "france").filter { chief in
            guard chief.surname == "Dayton", let last = chief.lastDayISO else { return false }
            return chief.firstDayISO <= date && date <= last
        }
        #expect(daytons.count == 1)
        let dayton = try #require(daytons.first)
        #expect(dayton.slug == "dayton-william-lewis")
        #expect(dayton.firstDayISO == "1861-03-18")
        #expect(dayton.lastDayISO == "1864-12-01")
        #expect(dayton.displayName == "William L. Dayton")
    }

    @Test("A display name is the altname plus any suffix it omits, and never carries the suffix twice")
    func displayNamePrefersAltname() {
        // The register's own name parts. Dayton Jr.'s altname omits his suffix, which printed him exactly
        // as his father; Thomas's altname already carries its own.
        let rows: [(POCOMPersonName, String)] = [
            (POCOMPersonName(sn: "Dayton", fn: "William Lewis", g: nil, a: "William L. Dayton"), "William L. Dayton"),
            (POCOMPersonName(sn: "Dayton", fn: "William Lewis", g: "Jr.", a: "William L. Dayton"), "William L. Dayton Jr."),
            (POCOMPersonName(sn: "Thomas", fn: "William Widgery", g: "Jr.", a: "William W. Thomas Jr."), "William W. Thomas Jr."),
            (POCOMPersonName(sn: "Thomas", fn: "William Widgery", g: "Jr.", a: "William W. Thomas, Jr"), "William W. Thomas, Jr"),
            (POCOMPersonName(sn: "Jay", fn: "John", g: "II", a: nil), "John Jay II"),
            (POCOMPersonName(sn: "Bigelow", fn: "John", g: nil, a: nil), "John Bigelow"),
            (POCOMPersonName(sn: "Bigelow", fn: "John", g: nil, a: "  "), "John Bigelow"),
        ]
        var checked = 0
        for (name, expected) in rows {
            #expect(name.displayName == expected, "\(name)")
            checked += 1
        }
        #expect(checked == 7)
    }

    @Test("The bundled names table prints Dayton's son as a different person from Dayton")
    func bundledDaytonJuniorIsDistinct() throws {
        let index = try #require(POCOMIndexStore.shared)
        #expect(index.names["dayton-william-lewis"]?.displayName == "William L. Dayton")
        #expect(index.names["dayton-william-lewis-jr"]?.displayName == "William L. Dayton Jr.")
    }

    /// Through `ChiefsOfMissionRoster.init(index:)` — the initializer `.bundled` uses — from JSON in the
    /// generator's shape, so the ceiling, the altname and the dropped rows are the decoder's (the floor has its
    /// own test, `partialStartFloorsToMonthStart`).
    @Test("A decoded version-2 file becomes a roster that decides d573 for Dayton, and drops unplaceable rows")
    func rosterFromDecodedIndexDecidesD573() throws {
        let index = try decode(POCOMIndex.self, """
            {"careers":{},"chiefs":{"france":[
               {"ap":"1861-03-18","en":"1864-12-01","r":"envoy-extraordinary-minister-plenipotentiary","s":"dayton-william-lewis","st":"1861-05-19"},
               {"ap":"1865-03-15","en":"1866-12","r":"envoy-extraordinary-minister-plenipotentiary","s":"bigelow-john"},
               {"ap":"1870","en":"1872","r":"envoy-extraordinary-minister-plenipotentiary","s":"no-name-entry"},
               {"en":"1880","r":"envoy-extraordinary-minister-plenipotentiary","s":"bigelow-john"}]},
             "generated":"2026-09-13",
             "names":{"bigelow-john":{"fn":"John","sn":"Bigelow"},
                      "dayton-william-lewis":{"a":"William L. Dayton","fn":"William Lewis","sn":"Dayton"}},
             "roles":{"envoy-extraordinary-minister-plenipotentiary":"Envoy Extraordinary and Minister Plenipotentiary"},
             "source":"test","version":2}
            """)
        #expect(index.chiefs(territoryId: "france").map(\.slug) == ["dayton-william-lewis", "bigelow-john"],
                "a row whose person has no names entry, and a row with no start, are both dropped")
        #expect(index.chiefs(territoryId: "france").last?.lastDayISO == "1866-12-31")
        let roster = ChiefsOfMissionRoster(index: index)
        let chief = try #require(roster.decide(header: "Mr. Seward to Mr. Dayton.",
                                               dateline: "Department of State , Washington , November 10, 1863.",
                                               geoKeys: ["france"]))
        #expect(chief.slug == "dayton-william-lewis")
        #expect(chief.displayName == "William L. Dayton")
        #expect(chief.roleLabel == "Envoy Extraordinary and Minister Plenipotentiary")
        #expect(roster.decide(header: "Mr. Seward to Mr. Dayton.",
                              dateline: "Department of State , Washington , November 10, 1863.",
                              geoKeys: ["spain"]) == nil, "control: the post is part of the decision")
    }

    /// `POCOMIndexBuilder` admits rows whose last day falls up to 90 days before 1861
    /// (`chiefsWindowEarliestLastDay`, 1860-10-03), because a letter of early 1861 reaches such a chief
    /// under the app's grace and the rule decides only when one person can. The two constants live in
    /// different targets, so this is where they meet.
    @Test("The bundled table reaches back before 1861 as far as the addressee rule's grace does")
    func bundledTableCoversTheGrace() throws {
        #expect(ChiefsOfMissionRoster.graceDaysAfterLastDay <= 90,
                "the grace reaches past the generator's window: widen chiefsWindowGraceDays and regenerate")
        let index = try #require(POCOMIndexStore.shared)
        let ward = index.chiefs(territoryId: "china").filter { $0.slug == "ward-john-elliott" }
        #expect(ward.map(\.lastDayISO) == ["1860-12-15"],
                "the first row the grace admits is missing — the table was cut at 1861 again")
    }
}

// MARK: - PersonLifespanTests

/// The person sheet's one lifespan line (#1370).
///
/// Life years used to reach the sheet twice and wrongly: the rollup wrote the name authority's
/// birth and death years into the columns the sheet labels **Active**, and the Career footer printed
/// POCOM's. They are now read once, here, at display time — the authority's year first, POCOM's
/// only for a year the authority lacks.
@Suite("Person lifespan")
struct PersonLifespanTests {

    private func career(_ born: Int?, _ died: Int?) throws -> POCOMCareer {
        try JSONDecoder().decode(POCOMCareer.self, from: Data("""
            {"n":"X","a":[]\(born.map { ",\"b\":\($0)" } ?? "")\(died.map { ",\"d\":\($0)" } ?? "")}
            """.utf8))
    }

    @Test("The authority's years come first and POCOM fills only a year the authority lacks")
    func authorityFirstPOCOMFillsGaps() throws {
        typealias Entry = PersonAuthorityIndex.AuthorityEntry
        // Kissinger: the authority has no death year; POCOM's 2023 is the only one either source has.
        let kissinger = PersonLifespan.years(authority: Entry(n: "Kissinger", b: 1923),
                                             career: try career(1923, 2023))
        #expect(kissinger.born == 1923 && kissinger.died == 2023)
        // Byrnes: the two sources disagree on the birth year, and the authority wins.
        let byrnes = PersonLifespan.years(authority: Entry(n: "Byrnes", b: 1879, d: 1972),
                                          career: try career(1882, 1972))
        #expect(byrnes.born == 1879 && byrnes.died == 1972)
        // A president: authority years and no POCOM career at all — 18 people, 13 of them presidents.
        #expect(PersonLifespan.text(authority: Entry(n: "Truman", b: 1884, d: 1972), career: nil)
                == "1884–1972")
        #expect(PersonLifespan.text(authority: Entry(n: "Shaw", b: 1923), career: nil) == "Born 1923")
        #expect(PersonLifespan.text(authority: nil, career: try career(nil, 1971)) == "Died 1971")
        #expect(PersonLifespan.text(authority: Entry(n: "Nobody"), career: try career(nil, nil)) == nil)
        #expect(PersonLifespan.text(authority: nil, career: nil) == nil)
    }

    /// Driven through the shipped artifacts rather than fixtures, because the join is the point:
    /// the sheet reaches POCOM only through the authority's slug.
    @Test("Over the shipped artifacts, the line takes the authority first and reaches the presidents")
    func shippedArtifacts() throws {
        let authority = try #require(PersonAuthorityIndexStore.shared, "person-authority-index.json")
        let pocom = try #require(POCOMIndexStore.shared, "pocom-index.json")
        func line(_ id: Int) -> String? {
            let entry = authority.entry(for: id)
            let career = entry?.s.flatMap { pocom.career(forSlug: $0) }
            return PersonLifespan.text(authority: entry, career: career)
        }
        #expect(line(107252) == "1923–2023", "Kissinger: his death year is only in POCOM")
        #expect(line(102048) == "1879–1972", "Byrnes: the authority's 1879, not POCOM's 1882")
        #expect(line(103340) == "1910–2007", "Deming: the authority's 1910, not POCOM's 1909")
        #expect(line(113770) == "1884–1972", "Truman has no POCOM career, and had no lifespan line")
    }
}
