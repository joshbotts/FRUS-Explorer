// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import PersonAuthorityIndexGeneratorCore

/// The identifier rule (#1767, item 1; the identifier assessment's (b4)), one test at a time over made-up
/// items. The corpus's own cases are `PersonIdentifierRuleCorpusTests`.
@Suite("person identifier rule")
struct PersonIdentifierRuleTests {

    // MARK: - Fixtures

    /// A record of the 1960s: Jane Q. Smith, born 1920, Ambassador to Ruritania.
    private let smith = PersonIdentifierRule.Record(
        name: "Smith, Jane Q.", birthYear: 1920, deathYear: nil,
        remarks: ["Ambassador to Ruritania from 1961"], firstVolumeYear: 1961)

    /// An item that fits `smith` and that nothing corroborates: no life year, no VIAF id, no role.
    private let plainSmith = WikidataSnapshot.Item(human: true, names: ["Jane Smith", "Jane Q. Smith"])

    private func rule(_ items: [String: WikidataSnapshot.Item], holders: [String: [String]] = [:],
                      deprecated: [String: [String]] = [:]) -> PersonIdentifierRule {
        PersonIdentifierRule(snapshot: WikidataSnapshot(fetched: "2026-10-29", items: items, viafHolders: holders,
                                                        viafDeprecatedHolders: deprecated))
    }

    private func verdict(_ item: WikidataSnapshot.Item, record: PersonIdentifierRule.Record? = nil,
                         recordVIAF: String? = nil, holders: [String: [String]] = [:]) -> PersonIdentifierRule.Verdict {
        rule(["Q1": item], holders: holders).test("Q1", against: record ?? smith, recordVIAF: recordVIAF)
    }

    // MARK: - The hard tests

    @Test("An item that is not a person fails, and so does an id that names no item")
    func notAPerson() {
        let carrier = WikidataSnapshot.Item(human: false, names: ["Admiral Kuznetsov", "Leonid Brezhnev"])
        let brezhnev = PersonIdentifierRule.Record(name: "Brezhnev, Leonid I.", birthYear: nil, deathYear: nil,
                                                   firstVolumeYear: 1952)
        #expect(verdict(carrier, record: brezhnev).hard == [.notAPerson])
        #expect(rule([:]).test("Q404", against: smith, recordVIAF: nil).hard == [.deleted])
        let deleted = WikidataSnapshot.Item(human: false, names: [], missing: true)
        #expect(verdict(deleted).hard == [.deleted])
    }

    @Test("A surname none of the item's names shares fails; an alternate name's surname fits")
    func surname() {
        let jones = WikidataSnapshot.Item(human: true, names: ["Jane Jones"])
        #expect(verdict(jones).hard == [.surname])
        let married = PersonIdentifierRule.Record(name: "Smith, Jane Q.", birthYear: nil, deathYear: nil,
                                                  alternateNames: ["Jones, Jane Q."], firstVolumeYear: 1961)
        #expect(verdict(jones, record: married).hard.isEmpty)
        // Particles and single letters are not a surname's words: "van" alone fits nothing.
        let vanDer = PersonIdentifierRule.Record(name: "van der Berg, Jan", birthYear: nil, deathYear: nil, firstVolumeYear: nil)
        #expect(verdict(WikidataSnapshot.Item(human: true, names: ["Jan van Dyke"]), record: vanDer).hard == [.surname])
        #expect(verdict(WikidataSnapshot.Item(human: true, names: ["Jan van den Berg"]), record: vanDer).hard.isEmpty)
    }

    @Test("A German umlaut fits its transliteration, and ß fits ss")
    func transliteration() {
        let woerner = PersonIdentifierRule.Record(name: "Woerner, Manfred", birthYear: 1934, deathYear: 1994, firstVolumeYear: 1969)
        let item = WikidataSnapshot.Item(human: true, names: ["Manfred Wörner"], born: [1934], died: [1994])
        #expect(verdict(item, record: woerner).hard.isEmpty)
        #expect(AuthorityText.words("Wörner") == ["worner", "woerner"])
        #expect(AuthorityText.words("Strauß") == ["strauss"])
        // Folding leaves ł, which is not a to z, and it divides the word.
        #expect(AuthorityText.words("Mikołajczyk, Stanisław") == ["miko", "ajczyk", "stanis", "aw"])
        #expect(AuthorityText.words("Muñiz") == ["muniz"])
    }

    @Test("A life year more than a year from the registry's fails; one within a year agrees")
    func lifeYears() {
        let older = WikidataSnapshot.Item(human: true, names: ["Jane Smith"], born: [1917], died: [1999])
        #expect(verdict(older).hard == [.birthYear])
        let near = WikidataSnapshot.Item(human: true, names: ["Jane Smith"], born: [1921])
        #expect(verdict(near).hard.isEmpty)
        #expect(verdict(near).registryYearsAgree)
        let dead = PersonIdentifierRule.Record(name: "Smith, Jane Q.", birthYear: nil, deathYear: 1990, firstVolumeYear: 1961)
        #expect(verdict(WikidataSnapshot.Item(human: true, names: ["Jane Smith"], died: [1985]), record: dead).hard == [.deathYear])
        // Any year of the item's within one counts; the item's first is the one its era is read from.
        #expect(verdict(WikidataSnapshot.Item(human: true, names: ["Jane Smith"], born: [1950, 1920])).hard == [.tooYoung])
    }

    @Test("An item born under fifteen years before the first volume, or dead over forty before it, fails")
    func era() {
        let young = PersonIdentifierRule.Record(name: "Smith, Jane Q.", birthYear: nil, deathYear: nil, firstVolumeYear: 1961)
        #expect(verdict(WikidataSnapshot.Item(human: true, names: ["Jane Smith"], born: [1947]), record: young).hard == [.tooYoung])
        #expect(verdict(WikidataSnapshot.Item(human: true, names: ["Jane Smith"], born: [1946]), record: young).hard.isEmpty)
        #expect(verdict(WikidataSnapshot.Item(human: true, names: ["Jane Smith"], died: [1920]), record: young).hard == [.diedLongBefore])
        #expect(verdict(WikidataSnapshot.Item(human: true, names: ["Jane Smith"], died: [1921]), record: young).hard.isEmpty)
        let noEra = PersonIdentifierRule.Record(name: "Smith, Jane Q.", birthYear: nil, deathYear: nil, firstVolumeYear: nil)
        #expect(verdict(WikidataSnapshot.Item(human: true, names: ["Jane Smith"], born: [1999]), record: noEra).hard.isEmpty)
        #expect(RegistryFacts.year(ofVolume: "frus1961-63v14") == 1961)
        #expect(RegistryFacts.year(ofVolume: "frus1917-72PubDipv08") == nil)
        let facts = RegistryFacts(record: PersonAuthorityRecord(
            canonicalId: 1, name: "n", birthYear: nil, deathYear: nil, viaf: nil,
            frusAnchors: [.init(volumeId: "frus1969-76v36", ref: "a"), .init(volumeId: "frus1917-72PubDipv08", ref: "b"),
                          .init(volumeId: "frus1958-60v03", ref: "c")]))
        #expect(facts.firstVolumeYear == 1958)
    }

    // MARK: - The soft tests

    @Test("A first given name no name of the item opens with fails softly; a nickname, a prefix or a second name fits")
    func givenName() {
        #expect(verdict(WikidataSnapshot.Item(human: true, names: ["Mary Smith"])).soft == [.givenName])
        // Any name of the item's that fits is enough.
        #expect(verdict(WikidataSnapshot.Item(human: true, names: ["Mary Smith", "Jane Smith"])).soft.isEmpty)
        let robert = PersonIdentifierRule.Record(name: "Kennedy, Robert F.", birthYear: nil, deathYear: nil, firstVolumeYear: 1961)
        #expect(verdict(WikidataSnapshot.Item(human: true, names: ["Bobby Kennedy"]), record: robert).soft.isEmpty)
        #expect(verdict(WikidataSnapshot.Item(human: true, names: ["Rob Kennedy"]), record: robert).soft.isEmpty)
        // The second given name opens a word of the item's, or the two disagree.
        #expect(verdict(WikidataSnapshot.Item(human: true, names: ["Robert Francis Kennedy"]), record: robert).soft.isEmpty)
        #expect(verdict(WikidataSnapshot.Item(human: true, names: ["Robert Neely Kennedy"]), record: robert).soft == [.givenName])
        // A name that is the surname alone tells nothing, and honorifics are not given names.
        #expect(verdict(WikidataSnapshot.Item(human: true, names: ["Smith"])).soft.isEmpty)
        #expect(verdict(WikidataSnapshot.Item(human: true, names: ["Sir Jane Smith"])).soft.isEmpty)
    }

    @Test("The record's VIAF id held by another item fails softly; held by this one, it agrees")
    func recordVIAF() {
        #expect(verdict(plainSmith, recordVIAF: "77", holders: ["77": ["Q9"]]).soft == [.viafHeldByAnotherItem])
        let holding = WikidataSnapshot.Item(human: true, names: ["Jane Smith"], viaf: ["77"])
        #expect(verdict(holding, recordVIAF: "77", holders: ["77": ["Q1", "Q9"]]).holdsRecordVIAF)
        #expect(verdict(plainSmith, recordVIAF: "77", holders: ["77": ["Q1"]]).holdsRecordVIAF,
                "a holder query that names the item counts as its own claim")
        // A VIAF id no item holds tells nothing either way.
        let nobody = verdict(plainSmith, recordVIAF: "77", holders: ["77": []])
        #expect(nobody.soft.isEmpty && !nobody.holdsRecordVIAF)
        // Deprecated holders still hold it, for this test.
        let deprecatedOnly = rule(["Q1": plainSmith], holders: ["77": []], deprecated: ["77": ["Q9"]])
        #expect(deprecatedOnly.test("Q1", against: smith, recordVIAF: "77").soft == [.viafHeldByAnotherItem])
    }

    // MARK: - Corroboration

    @Test("A Wikidata id that passes every test is taken only when the years, the VIAF id or a role word agrees")
    func wikidataNeedsCorroboration() {
        let byYears = rule(["Q1": WikidataSnapshot.Item(human: true, names: ["Jane Smith"], born: [1920])])
        #expect(byYears.decideWikidata("Q1", for: smith, recordVIAF: nil) == .init(accepted: true, reason: "registry-years-agree"))
        let byVIAF = rule(["Q1": WikidataSnapshot.Item(human: true, names: ["Jane Smith"], viaf: ["77"])], holders: ["77": ["Q1"]])
        #expect(byVIAF.decideWikidata("Q1", for: smith, recordVIAF: "77").accepted)
        let byRole = rule(["Q1": WikidataSnapshot.Item(human: true, names: ["Jane Smith"],
                                                       description: "American diplomat, ambassador to Ruritania")])
        #expect(byRole.decideWikidata("Q1", for: smith, recordVIAF: nil)
                == .init(accepted: true, reason: "role words ambassador,ruritania"))
        #expect(rule(["Q1": plainSmith]).decideWikidata("Q1", for: smith, recordVIAF: nil)
                == .init(accepted: false, reason: "uncorroborated"))
        // A failed test is never outweighed.
        let failing = rule(["Q1": WikidataSnapshot.Item(human: true, names: ["Mary Smith"], born: [1920])])
        #expect(failing.decideWikidata("Q1", for: smith, recordVIAF: nil) == .init(accepted: false, reason: "given-name"))
    }

    @Test("Role words are four letters or more, and no stopword, nationality, digit run or surname")
    func roleWords() {
        let record = PersonIdentifierRule.Record(
            name: "Ambassador, Jane", birthYear: nil, deathYear: nil,
            remarks: ["American Ambassador to the United States Department of State, 1961–1964; head of the Navy"],
            firstVolumeYear: 1961)
        let item = WikidataSnapshot.Item(human: true, names: ["Jane Ambassador"],
                                         description: "American official of the State Department in 1961",
                                         roles: ["Navy", "head of state", "ambassador"])
        #expect(rule(["Q1": item]).roleWords(of: record, in: "Q1") == ["navy"],
                "american, department, state, head and 1961 are not role words, and ambassador is her surname")
        #expect(PersonIdentifierRule.roleTokens(["Président du Conseil"]) == ["president", "conseil"])
        // A country is a role word, where its adjective is not (#1767's follow-up). Left out with the
        // nationalities, measured against the control, it took 19 ids off the bundle: Gustav Dahrendorf's
        // son's item and Major General Inam-ul-Haq's namesake's, and 17 right ones whose only word in
        // common with their item is the country (Kiichi Aichi, Liu Chieh, Pham Dang Lam, J. A. Ankrah's VIAF
        // id). The owner chose corrections for the two (2026-11-01).
        #expect(PersonIdentifierRule.roleTokens(["Foreign Minister of Japan"]) == ["foreign", "minister", "japan"])
    }

    // MARK: - A VIAF id

    @Test("A VIAF id is taken when the item the record carries holds it, at a deprecated rank when no other does")
    func viafAgrees() {
        let r = rule(["Q1": plainSmith], holders: ["77": ["Q1"], "78": []], deprecated: ["78": ["Q1"]])
        #expect(r.decideVIAF("77", for: smith, acceptedItem: "Q1") == .init(accepted: true, reason: "held by Q1"))
        #expect(r.decideVIAF("78", for: smith, acceptedItem: "Q1").accepted)
        #expect(r.decideVIAF("77", for: smith, acceptedItem: nil) == .init(accepted: false, reason: "held by Q1 uncorroborated"))
        // A redirected id agrees through its redirect.
        let moved = rule(["Q5": WikidataSnapshot.Item(human: true, names: ["Jane Smith"], redirect: "Q1"),
                          "Q1": plainSmith], holders: ["77": ["Q1"]])
        #expect(moved.decideVIAF("77", for: smith, acceptedItem: "Q5").accepted)
    }

    @Test("A VIAF id no accepted item holds is taken when a holder fits and the years or a role word agree")
    func viafByItsHolder() {
        let holder = WikidataSnapshot.Item(human: true, names: ["Jane Smith"], born: [1920], viaf: ["77"])
        #expect(rule(["Q2": holder], holders: ["77": ["Q2"]]).decideVIAF("77", for: smith, acceptedItem: nil)
                == .init(accepted: true, reason: "held by Q2: registry-years-agree"))
        let byRole = WikidataSnapshot.Item(human: true, names: ["Jane Smith"], viaf: ["77"], roles: ["ambassador"])
        #expect(rule(["Q2": byRole], holders: ["77": ["Q2"]]).decideVIAF("77", for: smith, acceptedItem: nil)
                == .init(accepted: true, reason: "held by Q2: role words ambassador"))
        // Holding the id is no corroboration, since every holder holds it.
        let holdsOnly = WikidataSnapshot.Item(human: true, names: ["Jane Smith"], viaf: ["77"])
        #expect(rule(["Q2": holdsOnly], holders: ["77": ["Q2"]]).decideVIAF("77", for: smith, acceptedItem: nil)
                == .init(accepted: false, reason: "held by Q2 uncorroborated"))
        let wrong = WikidataSnapshot.Item(human: true, names: ["Jane Smith"], born: [1850], viaf: ["77"])
        #expect(rule(["Q2": wrong], holders: ["77": ["Q2"]]).decideVIAF("77", for: smith, acceptedItem: nil)
                == .init(accepted: false, reason: "held by Q2 birth-year"))
        // A holder of the id at a deprecated rank only is not tested.
        #expect(rule(["Q2": holder], holders: ["77": []], deprecated: ["77": ["Q2"]])
                .decideVIAF("77", for: smith, acceptedItem: nil) == .init(accepted: false, reason: "held at a deprecated rank only"))
        #expect(rule([:], holders: ["77": []]).decideVIAF("77", for: smith, acceptedItem: nil)
                == .init(accepted: false, reason: "held by no item"))
    }

    // MARK: - The build

    /// A registry of one record, Jane Q. Smith, with an anchor, a remark and an alternate name.
    private func registryDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pir-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try """
        <person><id>100001</id><names><preferred><name>Smith, Jane Q.</name></preferred>
          <alternates><name>Jones,
             Jane Q.</name></alternates>
          <originals><original>
            <source-url>https://history.state.gov/historicaldocuments/frus1961-63v01/persons#p_SJQ1</source-url>
          </original></originals></names><birth-year>1920</birth-year><death-year/>
          <remarks><remark><p>Ambassador to   Ruritania
             from 1961</p><source-url>https://history.state.gov/historicaldocuments/frus1961-63v01/persons#p_SJQ1</source-url></remark></remarks>
        </person>
        """.write(to: dir.appendingPathComponent("100001.xml"), atomically: true, encoding: .utf8)
        return dir
    }

    private let smithEntry = PersonsCompleteOverlay.parseEntry("""
        <person xml:id="FRUS-1"><idno type="people-id">100001</idno>
        <idno type="Wikidata">Q1</idno><idno type="VIAF">77</idno><idno type="VIAF">78</idno></person>
        """)

    @Test("The registry's remarks and alternate names are read with each record")
    func parsesRemarks() throws {
        let dir = try registryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let xml = try String(contentsOf: dir.appendingPathComponent("100001.xml"), encoding: .utf8)
        let record = try #require(try PersonAuthorityIndexBuilder.parseRecord(xml: xml))
        #expect(record.remarks == ["Ambassador to Ruritania from 1961"])
        #expect(record.alternateNames == ["Jones, Jane Q."])
        #expect(RegistryFacts(record: record).firstVolumeYear == 1961)
    }

    @Test("build refuses an overlay id the snapshot has no facts for, before it applies the overlay")
    func buildRefusesUnreadIdentifiers() throws {
        let dir = try registryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        func build(_ snapshot: WikidataSnapshot, takes: Bool = true) throws -> PersonAuthorityIndex {
            try PersonAuthorityIndexBuilder.build(
                dataDirectory: dir, version: 2, generated: "test", source: "test",
                overlay: .init(entries: [smithEntry], flaggedPeopleIds: [], takesIdentifiers: takes,
                               identifierRule: PersonIdentifierRule(snapshot: snapshot))).index
        }
        #expect(throws: WikidataSnapshot.Problem.identifiersWithoutFacts(count: 2, ids: ["Q1", "VIAF 77"])) {
            try build(WikidataSnapshot(fetched: "t", items: [:], viafHolders: [:]))
        }
        // An id the run would not take is not owed facts.
        #expect(try build(WikidataSnapshot(fetched: "t", items: [:], viafHolders: [:]), takes: false)
            .authority["100001"]?.q == nil)
        // With them, the item holds the entry's VIAF id and fits the record, and both are stamped.
        let read = WikidataSnapshot(
            fetched: "t", items: ["Q1": WikidataSnapshot.Item(human: true, names: ["Jane Smith"], viaf: ["77"])],
            viafHolders: ["77": ["Q1"]])
        let entry = try #require(try build(read).authority["100001"])
        #expect(entry.q == "Q1" && entry.v == "77")
    }

    @Test("A withheld id is listed once, with why, and an id another entry's agreement let in is not")
    func withheldList() {
        let ship = PersonsCompleteOverlay.parseEntry("""
            <person xml:id="FRUS-2"><idno type="people-id">100001</idno><idno type="Wikidata">Q2</idno></person>
            """)
        // Q1 with a VIAF id another item holds: the soft test withholds it, and the id with it.
        let disagreeing = PersonsCompleteOverlay.parseEntry("""
            <person xml:id="FRUS-3"><idno type="people-id">100001</idno>
            <idno type="Wikidata">Q1</idno><idno type="VIAF">99</idno></person>
            """)
        let snapshot = WikidataSnapshot(
            fetched: "t",
            items: ["Q1": WikidataSnapshot.Item(human: true, names: ["Jane Smith"], viaf: ["77"]),
                    "Q2": WikidataSnapshot.Item(human: false, names: ["Jane Smith"]),
                    "Q9": WikidataSnapshot.Item(human: true, names: ["John Doe"], viaf: ["99"])],
            viafHolders: ["77": ["Q1"], "99": ["Q9"]])
        var crosswalk: [String: [String: Int]] = [:]
        var authority = ["100001": AuthorityEntry(n: "Smith, Jane Q.", b: 1920, d: nil, v: nil)]
        var stats = BuildStats()
        PersonAuthorityIndexBuilder.applyOverlay(
            .init(entries: [ship, ship, disagreeing, smithEntry], flaggedPeopleIds: [], takesIdentifiers: true,
                  identifierRule: PersonIdentifierRule(snapshot: snapshot)),
            crosswalk: &crosswalk, authority: &authority, keepVolume: nil, stats: &stats)
        #expect(authority["100001"]?.q == "Q1" && authority["100001"]?.v == "77",
                "the last entry's VIAF id agrees with Q1, and both are stamped")
        #expect(stats.identifiersWithheldByRule == [
            WithheldIdentifier(peopleId: "100001", name: "Smith, Jane Q.", kind: .wikidata, identifier: "Q2",
                               reason: "not-a-person"),
            WithheldIdentifier(peopleId: "100001", name: "Smith, Jane Q.", kind: .viaf, identifier: "99",
                               reason: "held by Q9 surname,given-name")])
    }

    // MARK: - The snapshot

    @Test("A snapshot that lists a holder it has no facts for, or is not a snapshot, is refused")
    func snapshotChecks() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("wikidata-snapshot-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        func load(_ json: String) throws -> WikidataSnapshot {
            let url = dir.appendingPathComponent("s.json")
            try Data(json.utf8).write(to: url)
            return try WikidataSnapshot.load(path: url.path)
        }
        let good = try load(#"{"fetched":"2026-10-29","items":{"Q1":{"human":true,"names":["A B"],"born":[1900]},"Q2":{"missing":true}},"viafHolders":{"7":["Q1"],"8":[]}}"#)
        #expect(good.items["Q1"]?.born == [1900] && good.items["Q1"]?.died == [])
        #expect(good.items["Q2"]?.missing == true && good.viafDeprecatedHolders.isEmpty)
        #expect(throws: WikidataSnapshot.Problem.holderWithoutFacts(viaf: "7", item: "Q3")) {
            try load(#"{"fetched":"2026-10-29","items":{},"viafHolders":{"7":["Q3"]}}"#)
        }
        #expect(throws: WikidataSnapshot.Problem.self) { try load(#"{"items":{}}"#) }
        #expect(throws: WikidataSnapshot.Problem.self) {
            try WikidataSnapshot.load(path: dir.appendingPathComponent("absent.json").path)
        }
    }
}
