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
        // This drives `POCOMCareer.lifespanText` — the real emitter — not a re-implementation.
        let index = try decode(POCOMIndex.self, achesonJSON)
        let acheson = try #require(index.career(forSlug: "acheson-dean-gooderham"))
        #expect(acheson.lifespanText == "1893–1971")
        #expect(!(acheson.lifespanText ?? "").contains(","))

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
        #expect(try career(1893, nil).lifespanText == "born 1893")
        #expect(try career(nil, 1971).lifespanText == "died 1971")
        #expect(try career(nil, nil).lifespanText == nil)
        #expect(try !(career(1893, nil).lifespanText ?? "").contains(","))
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
}
