// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import POCOMIndexGeneratorCore

/// POCOM career-index parsing (#736), plus the version-2 chiefs-of-mission tables.
///
/// Fixtures are trimmed copies of real records from the checkout, not invented shapes — the two
/// parsing traps this suite pins (nested event dates, the role stated only in a
/// principal-position header) both come from the actual files. The version-2 tests build small
/// synthetic checkouts in the register's real element shape. In each, a row differs from its twin
/// in the one condition under test.
@Suite("POCOM index builder")
struct POCOMIndexBuilderTests {

    // MARK: - Fixtures

    /// A real `missions-countries/afghanistan.xml` chief, trimmed.
    let countryMission = """
        <country-mission>
          <territory-id>afghanistan</territory-id>
          <chiefs>
            <chief>
              <id>af-1935-horn-01</id>
              <person-id>hornibrook-william-harrison</person-id>
              <role-title-id>envoy-extraordinary-minister-plenipotentiary</role-title-id>
              <contemporary-territory-id>afghanistan</contemporary-territory-id>
              <appointed><date>1935-01-22</date><note/></appointed>
              <arrived><date/><note/></arrived>
              <started><date>1935-05-04</date><note/></started>
              <ended><date>1936-03-16</date><note>Left Tehran on</note></ended>
            </chief>
            <chief>
              <id>af-1940-drey-01</id>
              <person-id>dreyfus-louis-goethe-jr</person-id>
              <role-title-id>envoy-extraordinary-minister-plenipotentiary</role-title-id>
              <contemporary-territory-id>afghanistan</contemporary-territory-id>
              <appointed><date>1940-02-16</date><note/></appointed>
              <started><date/><note/></started>
              <ended><date/><note/></ended>
            </chief>
          </chiefs>
        </country-mission>
        """

    /// A `positions-principals` file: the role is named once, in the header.
    let principalPosition = """
        <principal-position>
          <id>under-secretary</id>
          <class>principal</class>
          <names><singular>Under Secretary of State</singular>
                 <plural>Under Secretaries of State</plural></names>
          <start>1919</start>
          <description><div><p>Congress provided for the position…</p></div></description>
          <principals>
            <principal>
              <id>secr-1919-polk</id>
              <person-id>polk-frank-lyon</person-id>
              <appointed><date>1919-06-28</date><note/></appointed>
              <started><date>1919-07-01</date><note/></started>
              <ended><date>1920-06-15</date><note>Resigned</note></ended>
            </principal>
          </principals>
        </principal-position>
        """

    let personRecord = """
        <person>
          <id>aaron-david-laurence</id>
          <persName><surname>Aaron</surname><forename>David Laurence</forename></persName>
          <birth>1938</birth>
          <death/>
          <career-type>non-career</career-type>
        </person>
        """

    // MARK: - People

    @Test("A person record yields slug, 'Surname, Given', and life years")
    func parsesPerson() throws {
        let p = try #require(POCOMIndexBuilder.parsePerson(xml: personRecord))
        #expect(p.slug == "aaron-david-laurence")
        #expect(p.name == "Aaron, David Laurence")
        #expect(p.birth == 1938)
        #expect(p.death == nil, "an empty <death/> is not a year")
    }

    @Test("A record with no name at all is skipped rather than emitted nameless")
    func skipsNamelessPerson() {
        let xml = "<person><id>x</id><persName></persName></person>"
        #expect(POCOMIndexBuilder.parsePerson(xml: xml) == nil)
    }

    @Test("A surname with no forename still yields a usable name")
    func surnameOnly() throws {
        let xml = "<person><id>x</id><persName><surname>Metternich</surname></persName></person>"
        let p = try #require(POCOMIndexBuilder.parsePerson(xml: xml))
        #expect(p.name == "Metternich")
    }

    // MARK: - Appointments

    @Test("Chief dates come from the <date> nested inside each event block")
    func parsesNestedEventDates() throws {
        // The trap: `<appointed>` does not contain the year directly — it wraps `<date>` and
        // `<note>`. A scan for `<appointed>(\\d{4})` finds nothing and reports a clean run.
        let found = POCOMIndexBuilder.parseAppointments(xml: countryMission, tag: "chief")
        #expect(found.count == 2)
        let first = try #require(found.first)
        #expect(first.personId == "hornibrook-william-harrison")
        #expect(first.appointed == "1935-01-22")
        #expect(first.started == "1935-05-04")
        #expect(first.ended == "1936-03-16")
        #expect(first.endNote == "Left Tehran on")
        #expect(first.placeId == "afghanistan")
    }

    @Test("An empty <date/> reads as absent, not as an empty string")
    func emptyDateIsNil() throws {
        let found = POCOMIndexBuilder.parseAppointments(xml: countryMission, tag: "chief")
        let second = try #require(found.last)
        #expect(second.appointed == "1940-02-16")
        #expect(second.started == nil)
        #expect(second.ended == nil)
    }

    @Test("A principal's role comes from the file header, not from the officeholder")
    func principalRoleFallsBackToHeader() throws {
        // Principal-position files state the role once. Without the fallback every Secretary,
        // Under Secretary and Assistant Secretary would carry an empty role label.
        let found = POCOMIndexBuilder.parseAppointments(
            xml: principalPosition, tag: "principal", fallbackRoleId: "under-secretary")
        let only = try #require(found.first)
        #expect(only.personId == "polk-frank-lyon")
        #expect(only.roleId == "under-secretary")
        #expect(only.placeId == nil, "a Department post has no territory")
        #expect(only.endNote == "Resigned")
    }

    @Test("An appointment naming no person is dropped, not emitted anonymously")
    func dropsPersonlessAppointment() {
        let xml = "<chiefs><chief><id>x</id><appointed><date>1900</date></appointed></chief></chiefs>"
        #expect(POCOMIndexBuilder.parseAppointments(xml: xml, tag: "chief").isEmpty)
    }

    // MARK: - Role tables

    @Test("A role table yields id → singular name")
    func parsesRoleTable() throws {
        let xml = """
            <role mode="active"><id>acting-principal-officer</id><class>chief</class>
            <names><singular>Acting Principal Officer</singular>
            <plural>Acting Principal Officers</plural></names></role>
            """
        let role = try #require(POCOMIndexBuilder.parseRoleTable(xml: xml))
        #expect(role.id == "acting-principal-officer")
        #expect(role.name == "Acting Principal Officer")
    }

    @Test("A hard-wrapped title collapses to one line")
    func collapsesWrappedRoleName() throws {
        // Real shape: `positions-principals` wraps long titles inside the element, so the text
        // node carries a newline and twelve spaces. Trimming alone leaves it, and the label
        // reaches the UI broken across a line.
        let xml = """
            <principal-position><id>assistant-secretary-for-narcotics-and-law</id>
            <names><singular>Assistant Secretary of State for International Narcotics and Law Enforcement
                        Affairs</singular><plural>x</plural></names></principal-position>
            """
        let role = try #require(POCOMIndexBuilder.parseRoleTable(xml: xml))
        #expect(role.name
                == "Assistant Secretary of State for International Narcotics and Law Enforcement Affairs")
        #expect(!role.name.contains("\n"))
        #expect(!role.name.contains("  "), "internal runs collapse to a single space")
    }

    @Test("Organisation acronyms are upper-cased, not title-cased")
    func humanizesOrgAcronyms() {
        // POCOM ships no label table for missions-orgs roles, so these 13 ids fall through to
        // the humaniser. Without the acronym set they render "Representative to Nato".
        #expect(POCOMIndexBuilder.humanize(territoryId: "representative-to-nato")
                == "Representative to NATO")
        #expect(POCOMIndexBuilder.humanize(territoryId: "representative-to-un")
                == "Representative to UN")
        #expect(POCOMIndexBuilder.humanize(territoryId: "representative-to-oecd")
                == "Representative to OECD")
        #expect(POCOMIndexBuilder.humanize(territoryId: "representative-uneo")
                == "Representative UNEO")
        // And an acronym must not be mistaken for a small word to lower-case.
        #expect(POCOMIndexBuilder.humanize(territoryId: "representative-to-eu")
                == "Representative to EU")
    }

    @Test("A principal-position header parses as a role table too")
    func principalPositionIsARoleTable() throws {
        let role = try #require(POCOMIndexBuilder.parseRoleTable(xml: principalPosition))
        #expect(role.id == "under-secretary")
        #expect(role.name == "Under Secretary of State")
    }

    // MARK: - Place labels

    @Test("Territory slugs humanize, keeping conjunctions lower-case")
    func humanizesTerritories() {
        #expect(POCOMIndexBuilder.humanize(territoryId: "afghanistan") == "Afghanistan")
        #expect(POCOMIndexBuilder.humanize(territoryId: "united-kingdom") == "United Kingdom")
        #expect(POCOMIndexBuilder.humanize(territoryId: "antigua-and-barbuda")
                == "Antigua and Barbuda")
        #expect(POCOMIndexBuilder.humanize(territoryId: "republic-of-the-congo")
                == "Republic of the Congo")
    }

    @Test("A trailing year disambiguator is dropped from the label")
    func dropsYearSuffix() {
        // `albania-1946` distinguishes two mission *records*, not two places; the assignment's
        // own dates already say which era it is, and "Albania 1946" in a place column reads as a
        // different country.
        #expect(POCOMIndexBuilder.humanize(territoryId: "albania-1946") == "Albania")
        #expect(POCOMIndexBuilder.humanize(territoryId: "germany-1955") == "Germany")
    }

    @Test("The real slug shapes all humanize sensibly")
    func humanizesRealSlugs() {
        // Every one of the checkout's 204 territory/org slugs matches [a-z0-9-]+, so these are
        // the shapes that actually occur — including the longest, which is where a small-word
        // rule earns its keep.
        #expect(POCOMIndexBuilder.humanize(territoryId: "kingdom-of-two-sicilies-1861")
                == "Kingdom of Two Sicilies")
        #expect(POCOMIndexBuilder.humanize(
            territoryId: "socialist-federal-republic-of-yugoslavia-1992")
                == "Socialist Federal Republic of Yugoslavia")
        #expect(POCOMIndexBuilder.humanize(territoryId: "south-vietnam-1975") == "South Vietnam")
    }

    // MARK: - Assignment ordering

    @Test("Assignments sort by their earliest date, undated last")
    func assignmentOrdering() {
        let dated = POCOMAssignment(r: "Ambassador", p: "France", ap: "1961-03-01",
                                    st: nil, en: nil, nt: nil)
        let later = POCOMAssignment(r: "Ambassador", p: "Spain", ap: nil, st: "1970-01-01",
                                    en: nil, nt: nil)
        let undated = POCOMAssignment(r: "Consul", p: "Peru", ap: nil, st: nil, en: nil, nt: nil)
        #expect(dated.sortKey == "1961-03-01")
        #expect(later.sortKey == "1970-01-01", "falls through to <started> when unappointed")
        #expect(undated.sortKey == "9999", "date-unknown sorts last, where a reader expects it")
        #expect([undated, later, dated].sorted { $0.sortKey < $1.sortKey }
                    .map(\.p) == ["France", "Spain", "Peru"])
    }

    // MARK: - Full build

    @Test("A checkout folds into per-person careers with resolved labels")
    func buildsFromCheckout() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("POCOMTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        func write(_ text: String, _ path: String) throws {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try text.data(using: .utf8)!.write(to: url)
        }
        try write(personRecord, "people/a/aaron.xml")
        try write("""
            <person><id>hornibrook-william-harrison</id>
            <persName><surname>Hornibrook</surname><forename>William Harrison</forename></persName>
            <birth>1884</birth><death>1946</death></person>
            """, "people/h/hornibrook.xml")
        try write(countryMission, "missions-countries/afghanistan.xml")
        try write("""
            <role><id>envoy-extraordinary-minister-plenipotentiary</id>
            <names><singular>Envoy Extraordinary and Minister Plenipotentiary</singular></names></role>
            """, "roles-country-chiefs/envoy.xml")

        let (index, stats) = try POCOMIndexBuilder.build(
            checkout: root, version: 1, generated: "2026-08-07", source: "test")

        #expect(stats.countryChiefs == 2)
        // Only Hornibrook has both a person file and an appointment; Dreyfus has an appointment
        // but no person file, and Aaron a person file but no appointment.
        #expect(index.careers.count == 1)
        #expect(stats.appointmentsWithNoPerson == 1)
        let career = try #require(index.careers["hornibrook-william-harrison"])
        #expect(career.n == "Hornibrook, William Harrison")
        #expect(career.b == 1884)
        let post = try #require(career.a.first)
        #expect(post.r == "Envoy Extraordinary and Minister Plenipotentiary")
        #expect(post.p == "Afghanistan")
        #expect(post.nt == "Left Tehran on")
    }

    @Test("keepSlug restricts the build to the people the app can reach")
    func honoursKeepSlug() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("POCOMTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        func write(_ text: String, _ path: String) throws {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try text.data(using: .utf8)!.write(to: url)
        }
        try write("""
            <person><id>hornibrook-william-harrison</id>
            <persName><surname>Hornibrook</surname><forename>William</forename></persName></person>
            """, "people/h/hornibrook.xml")
        try write(countryMission, "missions-countries/afghanistan.xml")

        let (kept, _) = try POCOMIndexBuilder.build(
            checkout: root, version: 1, generated: "d", source: "s",
            keepSlug: ["hornibrook-william-harrison"])
        #expect(kept.careers.count == 1)

        let (none, _) = try POCOMIndexBuilder.build(
            checkout: root, version: 1, generated: "d", source: "s",
            keepSlug: ["someone-else"])
        #expect(none.careers.isEmpty)
    }

    @Test("An unresolved role id is reported, and its assignment still ships")
    func unknownRoleIsReportedNotDropped() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("POCOMTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        func write(_ text: String, _ path: String) throws {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try text.data(using: .utf8)!.write(to: url)
        }
        try write("""
            <person><id>hornibrook-william-harrison</id>
            <persName><surname>Hornibrook</surname><forename>William</forename></persName></person>
            """, "people/h/hornibrook.xml")
        try write(countryMission, "missions-countries/afghanistan.xml")
        // No role table written at all.

        let (index, stats) = try POCOMIndexBuilder.build(
            checkout: root, version: 1, generated: "d", source: "s")
        #expect(stats.unknownRoleIds.contains("envoy-extraordinary-minister-plenipotentiary"))
        let post = try #require(index.careers["hornibrook-william-harrison"]?.a.first)
        #expect(post.r == "Envoy Extraordinary Minister Plenipotentiary",
                "falls back to a humanised slug rather than an empty label")
    }

    // MARK: - Version 2: careers golden

    /// A checkout of real records, trimmed. France's served Dayton and Bigelow rows are included, as
    /// is its `<other-nominees>` Pinckney row, plus Seward as Secretary of State.
    /// ``careersGolden`` is what the builder made of it BEFORE the version-2 tables existed.
    static let goldenCheckoutFiles: [String: String] = [
        "people/d/dayton-william-lewis.xml": """
            <person><id>dayton-william-lewis</id>
            <persName><surname>Dayton</surname><forename>William Lewis</forename>
            <altname>William L. Dayton</altname></persName>
            <birth>1807</birth><death>1864</death><career-type>pre-1915</career-type></person>
            """,
        "people/b/bigelow-john.xml": """
            <person><id>bigelow-john</id>
            <persName><surname>Bigelow</surname><forename>John</forename></persName>
            <birth>1817</birth><death>1911</death></person>
            """,
        "people/p/pinckney-charles-cotesworth.xml": """
            <person><id>pinckney-charles-cotesworth</id>
            <persName><surname>Pinckney</surname><forename>Charles Cotesworth</forename></persName>
            <birth>1746</birth><death>1825</death></person>
            """,
        "people/s/seward-william-henry.xml": """
            <person><id>seward-william-henry</id>
            <persName><surname>Seward</surname><forename>William Henry</forename></persName>
            <birth>1801</birth><death>1872</death></person>
            """,
        "roles-country-chiefs/envoy-extraordinary-minister-plenipotentiary.xml": """
            <role mode="active"><id>envoy-extraordinary-minister-plenipotentiary</id>
            <class>chief</class><category>country</category>
            <names><singular>Envoy Extraordinary and Minister Plenipotentiary</singular>
            <plural>Envoys Extraordinary and Ministers Plenipotentiary</plural></names></role>
            """,
        "positions-principals/secretary.xml": """
            <principal-position><id>secretary</id><class>principal</class>
            <names><singular>Secretary of State</singular><plural>Secretaries of State</plural></names>
            <principals><principal><id>secr-1861-sewa</id><person-id>seward-william-henry</person-id>
            <role-title-id>secretary</role-title-id>
            <appointed><date>1861-03-05</date><note/></appointed>
            <started><date>1861-03-06</date><note/></started>
            <ended><date>1869-03-04</date><note/></ended></principal></principals>
            </principal-position>
            """,
        "missions-countries/france.xml": """
            <country-mission>
              <territory-id>france</territory-id>
              <chiefs>
                <chief>
                  <id>fr-1861-dayt-01</id>
                  <person-id>dayton-william-lewis</person-id>
                  <role-title-id>envoy-extraordinary-minister-plenipotentiary</role-title-id>
                  <contemporary-territory-id>france</contemporary-territory-id>
                  <appointed><date>1861-03-18</date><note/></appointed>
                  <arrived><date/><note/></arrived>
                  <started><date>1861-05-19</date><note/></started>
                  <ended><date>1864-12-01</date><note>Died at post on</note></ended>
                </chief>
                <chief>
                  <id>fr-1865-bige-01</id>
                  <person-id>bigelow-john</person-id>
                  <role-title-id>envoy-extraordinary-minister-plenipotentiary</role-title-id>
                  <contemporary-territory-id>france</contemporary-territory-id>
                  <appointed><date>1865-03-15</date><note/></appointed>
                  <arrived><date/><note/></arrived>
                  <started><date>1865-04-23</date><note/></started>
                  <ended><date>1866-12-23</date><note>Presented recall on</note></ended>
                </chief>
              </chiefs>
              <other-nominees>
                <chief>
                  <id>fr-1796-pinc-01</id>
                  <person-id>pinckney-charles-cotesworth</person-id>
                  <role-title-id>minister-plenipotentiary</role-title-id>
                  <contemporary-territory-id>france</contemporary-territory-id>
                  <appointed><date>1796-09-09</date><note/></appointed>
                  <arrived><date/><note/></arrived>
                  <started><date/><note/></started>
                  <ended><date/><note/></ended>
                </chief>
              </other-nominees>
            </country-mission>
            """,
    ]

    /// `careers` as the builder at `ab37a469` encoded it over ``goldenCheckoutFiles``, with the
    /// runner's encoder options. That builder predates the version-2 tables. Captured by running
    /// it, not written by hand, and it keeps the nominee Pinckney: excluding nominees from careers
    /// is a separate decision.
    static let careersGolden = #"{"bigelow-john":{"a":[{"ap":"1865-03-15","en":"1866-12-23","nt":"Presented recall on","p":"France","r":"Envoy Extraordinary and Minister Plenipotentiary","st":"1865-04-23"}],"b":1817,"d":1911,"n":"Bigelow, John"},"dayton-william-lewis":{"a":[{"ap":"1861-03-18","en":"1864-12-01","nt":"Died at post on","p":"France","r":"Envoy Extraordinary and Minister Plenipotentiary","st":"1861-05-19"}],"b":1807,"d":1864,"n":"Dayton, William Lewis"},"pinckney-charles-cotesworth":{"a":[{"ap":"1796-09-09","p":"France","r":"Minister Plenipotentiary"}],"b":1746,"d":1825,"n":"Pinckney, Charles Cotesworth"},"seward-william-henry":{"a":[{"ap":"1861-03-05","en":"1869-03-04","r":"Secretary of State","st":"1861-03-06"}],"b":1801,"d":1872,"n":"Seward, William Henry"}}"#

    // MARK: - Version 2: fixture builders

    /// A `<chief>` in the register's element order. An absent date is written as `<date/>`, the
    /// way the register writes it. The contemporary territory id deliberately differs from every
    /// file's `<territory-id>`, so each test that reads `chiefs` by key also checks the key.
    static func chiefXML(_ id: String, _ person: String, role: String = "minister-resident",
                         ap: String? = nil, st: String? = nil, en: String? = nil) -> String {
        func event(_ name: String, _ date: String?) -> String {
            "<\(name)>" + (date.map { "<date>\($0)</date>" } ?? "<date/>") + "<note/></\(name)>"
        }
        return "<chief><id>\(id)</id><person-id>\(person)</person-id>"
            + "<role-title-id>\(role)</role-title-id>"
            + "<contemporary-territory-id>contemporary-name</contemporary-territory-id>"
            + event("appointed", ap) + event("arrived", nil) + event("started", st) + event("ended", en)
            + "<note/></chief>"
    }

    /// A country-mission file: served chiefs inside `<chiefs>`, nominees inside `<other-nominees>`.
    static func missionXML(_ territory: String, chiefs: [String], nominees: [String] = []) -> String {
        "<country-mission><territory-id>\(territory)</territory-id><chiefs>" + chiefs.joined()
            + "</chiefs>"
            + (nominees.isEmpty ? "" : "<other-nominees>" + nominees.joined() + "</other-nominees>")
            + "</country-mission>"
    }

    /// A person record with the register's name parts.
    static func personXML(_ slug: String, surname: String, forename: String,
                          genName: String? = nil, altnames: [String] = []) -> String {
        "<person><id>\(slug)</id><persName><surname>\(surname)</surname>"
            + "<forename>\(forename)</forename>"
            + (genName.map { "<genName>\($0)</genName>" } ?? "")
            + altnames.map { "<altname>\($0)</altname>" }.joined()
            + "</persName><birth/><death/></person>"
    }

    /// Person files for `slugs`, so every row in a fixture has a name and fails only on what it tests.
    static func people(_ slugs: [String]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: slugs.map { slug in
            ("people/\(slug.prefix(1))/\(slug).xml",
             personXML(slug, surname: slug.capitalized, forename: "Test"))
        })
    }

    /// Writes `files` (path → contents) under a new temporary directory, creating them in `order`.
    private func writeCheckout(_ files: [String: String], order: [String]? = nil) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("POCOMTest-\(UUID().uuidString)", isDirectory: true)
        for path in order ?? files.keys.sorted() {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try Data(files[path, default: ""].utf8).write(to: url)
        }
        return root
    }

    /// Writes, builds and removes a checkout.
    private func buildCheckout(_ files: [String: String], keepSlug: Set<String>? = nil)
    throws -> (index: POCOMIndex, stats: POCOMBuildStats) {
        let root = try writeCheckout(files)
        defer { try? FileManager.default.removeItem(at: root) }
        return try POCOMIndexBuilder.build(checkout: root, version: 2, generated: "2026-09-13",
                                           source: "test", keepSlug: keepSlug)
    }

    // MARK: - Version 2: chiefs

    @Test("The chiefs table reads served rows inside <chiefs> and never <other-nominees>")
    func chiefsSkipOtherNominees() throws {
        // The nominee row is otherwise valid: it is in the window, dated and named. Only where it
        // sits in the file keeps it out.
        var files = Self.people(["dayton-william-lewis", "nominee-person"])
        files["missions-countries/france.xml"] = Self.missionXML(
            "france",
            chiefs: [Self.chiefXML("fr-1861-dayt-01", "dayton-william-lewis",
                                   ap: "1861-03-18", en: "1864-12-01")],
            nominees: [Self.chiefXML("fr-1862-nomi-01", "nominee-person",
                                     ap: "1862-01-01", en: "1863-01-01")])
        let (index, stats) = try buildCheckout(files)
        #expect(index.chiefs.keys.sorted() == ["france"], "keyed by <territory-id>")
        #expect(index.chiefs["france"]?.map(\.s) == ["dayton-william-lewis"])
        #expect(index.names.keys.sorted() == ["dayton-william-lewis"])
        #expect(stats.servedChiefRows == 1)
        #expect(stats.otherNomineeChiefRows == 1)
        // Careers still harvest the nomination; nominee exclusion there is out of scope.
        #expect(index.careers["nominee-person"]?.a.count == 1)
    }

    @Test("keepSlug restricts careers but not the chiefs table")
    func chiefsIgnoreKeepSlug() throws {
        let files = [
            "people/d/dayton-william-lewis.xml": Self.personXML(
                "dayton-william-lewis", surname: "Dayton", forename: "William Lewis"),
            "missions-countries/france.xml": Self.missionXML("france", chiefs: [
                Self.chiefXML("fr-1861-dayt-01", "dayton-william-lewis", ap: "1861-03-18", en: "1864-12-01"),
            ]),
        ]
        let (index, _) = try buildCheckout(files, keepSlug: ["someone-else"])
        #expect(index.careers.isEmpty, "fixture guard: keepSlug did exclude Dayton from careers")
        #expect(index.chiefs["france"]?.map(\.s) == ["dayton-william-lewis"])
        #expect(index.names["dayton-william-lewis"]?.sn == "Dayton")
    }

    @Test("A row is kept when its widened tenure overlaps 1861-01-01…1906-12-31, both edges inclusive")
    func chiefsWindowBoundaries() throws {
        #expect(POCOMIndexBuilder.chiefsWindowFirstDay == "1861-01-01")
        #expect(POCOMIndexBuilder.chiefsWindowLastDay == "1906-12-31")
        // Each pair differs in one date, across one edge. A partial date widens: an end of `1861`
        // runs to 1861-12-31, and a start of `1906-12` opens on 1906-12-01. Every row states its
        // end, or the edge would be moved by a derived end instead.
        let cases: [(slug: String, ap: String, en: String, kept: Bool)] = [
            ("end-1860", "1850-01-01", "1860", false),
            ("end-1861", "1850-01-01", "1861", true),
            ("end-1860-12", "1850-01-01", "1860-12", false),
            ("end-1861-01", "1850-01-01", "1861-01", true),
            ("end-1860-12-31", "1850-01-01", "1860-12-31", false),
            ("end-1861-01-01", "1850-01-01", "1861-01-01", true),
            ("start-1906", "1906", "1910-01-01", true),
            ("start-1907", "1907", "1910-01-01", false),
            ("start-1906-12", "1906-12", "1910-01-01", true),
            ("start-1907-01", "1907-01", "1910-01-01", false),
            ("start-1906-12-31", "1906-12-31", "1910-01-01", true),
            ("start-1907-01-01", "1907-01-01", "1910-01-01", false),
        ]
        var files = Self.people(cases.map(\.slug))
        files["missions-countries/peru.xml"] = Self.missionXML("peru", chiefs: cases.enumerated().map {
            Self.chiefXML("pe-\($0.offset)", $0.element.slug, ap: $0.element.ap, en: $0.element.en)
        })
        let (index, stats) = try buildCheckout(files)
        let kept = Set(index.chiefs["peru"]?.map(\.s) ?? [])
        var checked = 0
        for row in cases {
            #expect(kept.contains(row.slug) == row.kept, "\(row.slug)")
            checked += 1
        }
        #expect(checked == 12)
        #expect(stats.chiefRowsOutsideWindow == 6)
    }

    @Test("A row with neither an appointment nor a start date is skipped")
    func chiefsSkipRowWithoutStart() throws {
        var files = Self.people(["undated-start", "dated-start"])
        files["missions-countries/chile.xml"] = Self.missionXML("chile", chiefs: [
            Self.chiefXML("ch-1", "undated-start", en: "1870-01-01"),
            Self.chiefXML("ch-2", "dated-start", st: "1869-01-01", en: "1870-01-01"),
        ])
        let (index, stats) = try buildCheckout(files)
        #expect(index.chiefs["chile"]?.map(\.s) == ["dated-start"])
        #expect(stats.chiefRowsWithoutStart == 1)
        #expect(index.names["undated-start"] == nil)
    }

    @Test("A row's start is the earlier of its appointment and start dates")
    func chiefsStartIsEarliestOfAppointedStarted() throws {
        var files = Self.people(["open-before-late", "appointed-late",
                                 "open-before-early", "appointed-early"])
        // The appointment FOLLOWS the start here, as in do-1885-thom-01. Taking the appointment
        // first opens this tenure in 1907, outside the window, and moves the open row's derived end.
        files["missions-countries/dominican-republic.xml"] = Self.missionXML("dominican-republic", chiefs: [
            Self.chiefXML("do-1", "open-before-late", ap: "1900-01-01"),
            Self.chiefXML("do-2", "appointed-late", ap: "1907-03-01", st: "1906-12-15", en: "1908-01-01"),
        ])
        // The ordinary order: appointment, then start. Taking the start first moves the open
        // row's derived end.
        files["missions-countries/haiti.xml"] = Self.missionXML("haiti", chiefs: [
            Self.chiefXML("ht-1", "open-before-early", ap: "1880-01-01"),
            Self.chiefXML("ht-2", "appointed-early", ap: "1890-01-01", st: "1890-06-01", en: "1895-01-01"),
        ])
        let (index, _) = try buildCheckout(files)
        let dominican = try #require(index.chiefs["dominican-republic"])
        #expect(dominican.map(\.s) == ["open-before-late", "appointed-late"])
        #expect(dominican.first { $0.s == "open-before-late" }?.ex == "1906-12-14")
        let haiti = try #require(index.chiefs["haiti"])
        #expect(haiti.first { $0.s == "open-before-early" }?.ex == "1889-12-31")
    }

    @Test("An open row ends the day before the next strictly later start at its territory, register-wide")
    func chiefsOpenEndCappedByNextRow() throws {
        var files = Self.people(["pacheco-romualdo", "same-day-colleague", "later-minister",
                                 "open-late", "beyond-window", "open-early", "next-early",
                                 "open-leap", "next-leap", "open-year", "next-year"])
        // Modelled on Pacheco's commissions: gt-1890-pach-01 is open, noting only "Recommissioned".
        // A row starting the SAME day is not later. Of the two later rows the earliest caps, and
        // its partial start (`1891-07`) floors before the day is taken off.
        files["missions-countries/guatemala.xml"] = Self.missionXML("guatemala", chiefs: [
            Self.chiefXML("gt-1890-pach-01", "pacheco-romualdo", ap: "1890-12-11", st: "1891-02-28"),
            Self.chiefXML("gt-1890-same-01", "same-day-colleague", ap: "1890-12-11", en: "1891-01-01"),
            Self.chiefXML("gt-1892-late-01", "later-minister", ap: "1892-01-01", en: "1893-01-01"),
            Self.chiefXML("gt-1891-pach-01", "pacheco-romualdo", ap: "1891-07", en: "1893-06-12"),
        ])
        // The capping row starts in 1910, is outside the window and is not emitted. The cap is
        // computed over the register, not over the table.
        files["missions-countries/spain.xml"] = Self.missionXML("spain", chiefs: [
            Self.chiefXML("sp-1905-open-01", "open-late", ap: "1905-03-01"),
            Self.chiefXML("sp-1910-beyo-01", "beyond-window", ap: "1910-03-01", en: "1912-01-01"),
        ])
        // Left open, this pre-war row would overlap the window; capped in 1855, it does not.
        files["missions-countries/peru.xml"] = Self.missionXML("peru", chiefs: [
            Self.chiefXML("pe-1850-open-01", "open-early", ap: "1850-01-01"),
            Self.chiefXML("pe-1855-next-01", "next-early", ap: "1855-03-01", en: "1856-01-01"),
        ])
        // The day before 1 March of a leap year, and the day before 1 January.
        files["missions-countries/chile.xml"] = Self.missionXML("chile", chiefs: [
            Self.chiefXML("ch-1880-open-01", "open-leap", ap: "1880-05-01"),
            Self.chiefXML("ch-1892-next-01", "next-leap", ap: "1892-03-01", en: "1893-01-01"),
        ])
        files["missions-countries/denmark.xml"] = Self.missionXML("denmark", chiefs: [
            Self.chiefXML("dk-1875-open-01", "open-year", ap: "1875-01-01"),
            Self.chiefXML("dk-1881-next-01", "next-year", ap: "1881-01-01", en: "1882-01-01"),
        ])
        let (index, stats) = try buildCheckout(files)
        let guatemala = try #require(index.chiefs["guatemala"])
        let open = try #require(guatemala.first { $0.s == "pacheco-romualdo" && $0.en == nil })
        #expect(open.ex == "1891-06-30")
        #expect(index.chiefs["spain"]?.map(\.s) == ["open-late"])
        #expect(index.chiefs["spain"]?.first?.ex == "1910-02-28")
        #expect(index.chiefs["peru"] == nil, "both Peru rows end before 1861 once the open one is capped")
        #expect(index.chiefs["chile"]?.first { $0.s == "open-leap" }?.ex == "1892-02-29")
        #expect(index.chiefs["denmark"]?.first { $0.s == "open-year" }?.ex == "1880-12-31")
        #expect(stats.derivedEndsWritten == 4, "Guatemala, Spain, Chile and Denmark each write one")
    }

    @Test("No derived end without a later row at the same territory, nor on a row with its own end")
    func chiefsNoExWithoutLaterRow() throws {
        var files = Self.people(["earlier-minister", "last-open", "elsewhere-later",
                                 "ended-minister", "successor"])
        // Japan: the open row is its territory's latest. An EARLIER row does not cap it.
        files["missions-countries/japan.xml"] = Self.missionXML("japan", chiefs: [
            Self.chiefXML("ja-1890-earl-01", "earlier-minister", ap: "1890-01-01", en: "1895-01-01"),
            Self.chiefXML("ja-1900-last-01", "last-open", ap: "1900-01-01"),
        ])
        // Korea: a later start at ANOTHER territory does not cap Japan's open row.
        files["missions-countries/korea.xml"] = Self.missionXML("korea", chiefs: [
            Self.chiefXML("ko-1902-else-01", "elsewhere-later", ap: "1902-01-01", en: "1904-01-01"),
        ])
        // Thailand: a row that states its end gets no derived one, successor or not.
        files["missions-countries/thailand.xml"] = Self.missionXML("thailand", chiefs: [
            Self.chiefXML("th-1880-ende-01", "ended-minister", ap: "1880-01-01", en: "1885-01-01"),
            Self.chiefXML("th-1886-succ-01", "successor", ap: "1886-01-01", en: "1890-01-01"),
        ])
        let (index, stats) = try buildCheckout(files)
        let lastOpen = try #require(index.chiefs["japan"]?.first { $0.s == "last-open" })
        #expect(lastOpen.en == nil)
        #expect(lastOpen.ex == nil)
        let ended = try #require(index.chiefs["thailand"]?.first { $0.s == "ended-minister" })
        #expect(ended.ex == nil)
        #expect(stats.derivedEndsWritten == 0)
    }

    @Test("Rows order by (first day, slug, chief id), whatever order the file lists them in")
    func chiefsTotalOrderOnSharedStart() throws {
        // Named against the expectation. Each of these alone gives a different sequence: slug
        // order, chief-id order, end-date order, first day then chief id, first day then slug then
        // file order, and file order.
        var files = Self.people(["zeta-person", "alpha-person", "beta-person"])
        files["missions-countries/france.xml"] = Self.missionXML("france", chiefs: [
            Self.chiefXML("fr-2", "beta-person", ap: "1880-01-01", en: "1881-01-01"),
            Self.chiefXML("fr-0", "beta-person", ap: "1880-01-01", en: "1882-01-01"),
            Self.chiefXML("fr-1", "alpha-person", st: "1880-01-01", en: "1883-01-01"),
            Self.chiefXML("fr-3", "zeta-person", ap: "1870-01-01", en: "1871-01-01"),
        ])
        let (index, _) = try buildCheckout(files)
        let order = try #require(index.chiefs["france"]).map { "\($0.s) \($0.en ?? "-")" }
        #expect(order == ["zeta-person 1871-01-01", "alpha-person 1883-01-01",
                          "beta-person 1882-01-01", "beta-person 1881-01-01"])
    }

    // MARK: - Version 2: names and roles

    @Test("names captures surname, forename and genName, and an empty genName reads as absent")
    func namesCaptureGenName() throws {
        var files: [String: String] = [
            "people/a/ackerson-garret-g.xml": Self.personXML(
                "ackerson-garret-g", surname: "Ackerson", forename: "Garret G.", genName: "Jr."),
            "people/b/blank-gen.xml": Self.personXML(
                "blank-gen", surname: "Blank", forename: "Gen", genName: " "),
        ]
        files["missions-countries/liberia.xml"] = Self.missionXML("liberia", chiefs: [
            Self.chiefXML("lr-1", "ackerson-garret-g", ap: "1870-01-01", en: "1871-01-01"),
            Self.chiefXML("lr-2", "blank-gen", ap: "1872-01-01", en: "1873-01-01"),
        ])
        let (index, _) = try buildCheckout(files)
        #expect(index.names["ackerson-garret-g"]
                == POCOMPersonName(sn: "Ackerson", fn: "Garret G.", g: "Jr.", a: nil))
        #expect(index.names["blank-gen"] == POCOMPersonName(sn: "Blank", fn: "Gen", g: nil, a: nil))
    }

    @Test("names keeps the first non-empty altname, whitespace-collapsed")
    func namesCaptureFirstAltname() throws {
        let files: [String: String] = [
            "people/d/dayton-william-lewis.xml": Self.personXML(
                "dayton-william-lewis", surname: "Dayton", forename: "William Lewis",
                altnames: ["William L. Dayton", "W. L. Dayton"]),
            // Real: the register's altname carries a trailing space.
            "people/v/vass-laurence-coolidge.xml": Self.personXML(
                "vass-laurence-coolidge", surname: "Vass", forename: "Laurence Coolidge",
                altnames: ["Laurence C. Vass "]),
            "people/n/no-altname.xml": Self.personXML("no-altname", surname: "Plain", forename: "Name"),
            "missions-countries/france.xml": Self.missionXML("france", chiefs: [
                Self.chiefXML("fr-1", "dayton-william-lewis", ap: "1861-03-18", en: "1864-12-01"),
                Self.chiefXML("fr-2", "vass-laurence-coolidge", ap: "1865-01-01", en: "1866-01-01"),
                Self.chiefXML("fr-3", "no-altname", ap: "1867-01-01", en: "1868-01-01"),
            ]),
        ]
        let (index, _) = try buildCheckout(files)
        #expect(index.names["dayton-william-lewis"]?.a == "William L. Dayton")
        #expect(index.names["vass-laurence-coolidge"]?.a == "Laurence C. Vass")
        let plain = try #require(index.names["no-altname"])
        #expect(plain.a == nil)
    }

    @Test("roles maps each role id the chiefs use to its singular label, and holds no other")
    func rolesUseSingularLabel() throws {
        var files = Self.people(["envoy-person", "resident-person"])
        files["roles-country-chiefs/envoy.xml"] = """
            <role mode="active"><id>envoy-extraordinary-minister-plenipotentiary</id><class>chief</class>
            <names><singular>Envoy Extraordinary and Minister Plenipotentiary</singular>
            <plural>Envoys Extraordinary and Ministers Plenipotentiary</plural></names></role>
            """
        files["roles-country-chiefs/minister-resident.xml"] = """
            <role mode="active"><id>minister-resident</id><class>chief</class>
            <names><singular>Minister Resident</singular><plural>Ministers Resident</plural></names></role>
            """
        files["roles-country-chiefs/charge-daffaires.xml"] = """
            <role mode="active"><id>charge-daffaires</id><class>chief</class>
            <names><singular>Chargé d'Affaires</singular><plural>Chargés d'Affaires</plural></names></role>
            """
        files["missions-countries/brazil.xml"] = Self.missionXML("brazil", chiefs: [
            Self.chiefXML("br-1", "envoy-person", role: "envoy-extraordinary-minister-plenipotentiary",
                          ap: "1870-01-01", en: "1871-01-01"),
            Self.chiefXML("br-2", "resident-person", role: "minister-resident",
                          ap: "1872-01-01", en: "1873-01-01"),
        ])
        let (index, stats) = try buildCheckout(files)
        #expect(index.roles == [
            "envoy-extraordinary-minister-plenipotentiary": "Envoy Extraordinary and Minister Plenipotentiary",
            "minister-resident": "Minister Resident",
        ])
        #expect(stats.unknownRoleIds.isEmpty)
    }

    // MARK: - Version 2: careers and determinism

    @Test("careers encode byte-for-byte as the version-1 builder wrote them")
    func careersUnchangedByChiefs() throws {
        let (index, _) = try buildCheckout(Self.goldenCheckoutFiles)
        // Positive control: this build made the chiefs table, without the nominee.
        #expect(index.chiefs["france"]?.map(\.s) == ["dayton-william-lewis", "bigelow-john"])
        let careers = String(decoding: try POCOMIndexRunner.makeEncoder().encode(index.careers),
                             as: UTF8.self)
        #expect(careers == Self.careersGolden)
    }

    @Test("Two builds of one checkout, written in opposite file orders, encode to identical bytes")
    func rebuildIsByteIdentical() throws {
        var files = Self.goldenCheckoutFiles
        files.merge(Self.people(["pacheco-romualdo", "same-day-colleague"])) { current, _ in current }
        // A second territory, a shared first day and a derived end, listed out of order.
        files["missions-countries/guatemala.xml"] = Self.missionXML("guatemala", chiefs: [
            Self.chiefXML("gt-1891-pach-01", "pacheco-romualdo", ap: "1891-07", en: "1893-06-12"),
            Self.chiefXML("gt-1890-same-01", "same-day-colleague", ap: "1890-12-11", en: "1891-01-01"),
            Self.chiefXML("gt-1890-pach-01", "pacheco-romualdo", ap: "1890-12-11", st: "1891-02-28"),
        ])
        let forward = try writeCheckout(files, order: files.keys.sorted())
        let backward = try writeCheckout(files, order: Array(files.keys.sorted().reversed()))
        defer {
            try? FileManager.default.removeItem(at: forward)
            try? FileManager.default.removeItem(at: backward)
        }
        let first = try POCOMIndexBuilder.build(checkout: forward, version: 2,
                                                generated: "2026-09-13", source: "s").index
        let second = try POCOMIndexBuilder.build(checkout: backward, version: 2,
                                                 generated: "2026-09-13", source: "s").index
        #expect(first.chiefs.keys.sorted() == ["france", "guatemala"], "fixture guard")
        #expect(first.chiefs["guatemala"]?.contains { $0.ex == "1891-06-30" } == true, "fixture guard")
        let firstBytes = try POCOMIndexRunner.encode(first)
        let secondBytes = try POCOMIndexRunner.encode(second)
        #expect(firstBytes == secondBytes)
    }

    // MARK: - Version 2: the runner's refusal

    @Test("The runner refuses a chiefs table under 600 rows, or one without Dayton under France")
    func runnerRefusesThinOrSentinelLessChiefs() {
        func index(filler: Int, daytonUnder territory: String?) -> POCOMIndex {
            var chiefs: [String: [POCOMChiefRow]] = [
                "filler": (0..<filler).map {
                    POCOMChiefRow(s: "filler-\($0)", r: "r", ap: "1870", st: nil, en: nil, ex: nil)
                },
            ]
            if let territory {
                chiefs[territory, default: []].append(POCOMChiefRow(
                    s: "dayton-william-lewis", r: "r", ap: "1861-03-18", st: nil, en: "1864-12-01", ex: nil))
            }
            return POCOMIndex(version: 2, generated: "g", source: "s", careers: [:], chiefs: chiefs)
        }
        #expect(POCOMIndexRunner.chiefsMinimumRows == 600)
        #expect(POCOMIndexRunner.chiefsRefusal(index(filler: 599, daytonUnder: "france")) == nil)
        #expect(POCOMIndexRunner.chiefsRefusal(index(filler: 598, daytonUnder: "france")) == .tooFewRows(599))
        #expect(POCOMIndexRunner.chiefsRefusal(index(filler: 599, daytonUnder: "spain")) == .missingSentinel)
    }
}
