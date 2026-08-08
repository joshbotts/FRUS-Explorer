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

/// POCOM career-index parsing (#736).
///
/// Fixtures are trimmed copies of real records from the checkout, not invented shapes — the two
/// parsing traps this suite pins (nested event dates, the role stated only in a
/// principal-position header) both come from the actual files.
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
}
