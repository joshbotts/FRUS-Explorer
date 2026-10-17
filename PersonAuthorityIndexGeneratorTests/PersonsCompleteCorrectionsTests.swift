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

/// The overlay entries held apart (#1657): `FRUS-14666` filed Jeane Kirkpatrick's 1981–1988 anchors
/// and identifiers under Helen P. Kirkpatrick's people-id, and `FRUS-14463` filed Ahmad Khomeini's
/// vol. XI Part 1 entry and Wikidata id under his father's. The fixtures are those entries, cut down.
@Suite("persons-complete corrections")
struct PersonsCompleteCorrectionsTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    // MARK: - Fixtures

    /// The registry as `HistoryAtState/people` has it: Helen P. with her vol. XI anchor and no
    /// identifier, Jeane Jordan with vol. III, and Ruhollah Khomeini with vol. I of 1977–1980.
    private func registry() -> (crosswalk: [String: [String: Int]], authority: [String: AuthorityEntry]) {
        (["frus1952-54v11p1": ["p_KHP1": 107235],
          "frus1981-88v03": ["p_KJJ_1": 107237],
          "frus1977-80v01": ["p_KA_1": 107120]],
         ["107235": AuthorityEntry(n: "Kirkpatrick, Helen P.", b: nil, d: nil, v: nil),
          "107237": AuthorityEntry(n: "Kirkpatrick, Jeane Jordan", b: 1926, d: 2006, v: nil,
                                   s: "kirkpatrick-jeane-jordan"),
          "107120": AuthorityEntry(n: "Khomeini, Ruhollah", b: nil, d: nil, v: nil)])
    }

    /// `FRUS-14666`, `FRUS-14668` and `FRUS-14463`, in that order, with the anchors and ids that matter.
    private func entries() -> [PersonsCompleteOverlay.Entry] {
        [PersonsCompleteOverlay.parseEntry("""
            <person xml:id="FRUS-14666"><persName type="main">Kirkpatrick, Helen P.</persName>
            <persName type="variant">Kirkpatrick, Jeane J.</persName>
            <occupation>Public Affairs Adviser, Bureau of European Affairs, Department of
                State</occupation>
            <idno type="people-id">107235</idno>
            <idno type="VIAF">71474039</idno><idno type="Wikidata">Q240534</idno>
            <idno type="frus-ref">frus1952-54v11p1/persons#p_KHP1</idno>
            <idno type="frus-ref">frus1952-54v11p2/persons#p_KHP1</idno>
            <idno type="frus-ref">frus1981-88v01/persons#p_KJJ_1</idno>
            <idno type="frus-ref">frus1981-88v03/persons#p_KJJ_1</idno>
            <idno type="frus-ref">frus1981-88v04/persons#p_KJJ_1</idno></person>
            """),
         PersonsCompleteOverlay.parseEntry("""
            <person xml:id="FRUS-14668"><persName type="main">Kirkpatrick, Jeane Jordan</persName>
            <occupation>Professor of Government, Georgetown University, [Reagan]</occupation>
            <idno type="people-id">107237</idno>
            <idno type="VIAF">71474039</idno><idno type="Wikidata">Q240534</idno>
            <idno type="frus-ref">frus1981-88v01/persons#p_KJJ_1</idno></person>
            """),
         PersonsCompleteOverlay.parseEntry("""
            <person xml:id="FRUS-14463"><persName type="main">Khomeini, Ruhollah</persName>
            <persName type="variant">Khomeini, Ahmad</persName>
            <occupation>dissident Iranian religious leader</occupation>
            <occupation>son of the Ayatollah Khomeini</occupation>
            <idno type="people-id">107120</idno>
            <idno type="VIAF">88036173</idno><idno type="Wikidata">Q400619</idno>
            <idno type="frus-ref">frus1977-80v01/persons#p_KA_1</idno>
            <idno type="frus-ref">frus1977-80v11p1/persons#p_KAR_1</idno>
            <idno type="frus-ref">frus1977-80v11p1/persons#p_KA_1</idno></person>
            """)]
    }

    private let kirkpatrick = PersonsCompleteCorrections.HeldApart(
        peopleId: "107235", registryName: "Kirkpatrick, Helen P.", otherPerson: "Kirkpatrick, Jeane J.",
        anchors: ["frus1981-88v01/persons#p_KJJ_1", "frus1981-88v03/persons#p_KJJ_1",
                  "frus1981-88v04/persons#p_KJJ_1"],
        wikidata: "Q240534", viaf: "71474039", reason: "#1657")

    private let khomeini = PersonsCompleteCorrections.HeldApart(
        peopleId: "107120", registryName: "Khomeini, Ruhollah", otherPerson: "Khomeini, Ahmad",
        anchors: ["frus1977-80v11p1/persons#p_KA_1"], wikidata: "Q400619", viaf: nil, reason: "#1657")

    private func apply(_ corrections: [PersonsCompleteCorrections.HeldApart])
        -> (crosswalk: [String: [String: Int]], authority: [String: AuthorityEntry], stats: BuildStats) {
        var (crosswalk, authority) = registry()
        var stats = BuildStats()
        PersonAuthorityIndexBuilder.applyOverlay(
            .init(entries: entries(), flaggedPeopleIds: [], corrections: corrections),
            crosswalk: &crosswalk, authority: &authority, keepVolume: nil, stats: &stats)
        return (crosswalk, authority, stats)
    }

    // MARK: - Holding apart

    @Test("Without the corrections the fixture is #1657: Jeane J. and her ids filed under Helen P.")
    func withoutCorrectionsTheMergeLands() throws {
        // The other half of every test below: what the generator did before. If this stops holding,
        // the fixture no longer has the shape of the two entries, and the tests below prove nothing.
        let (crosswalk, authority, _) = apply([])
        #expect(crosswalk["frus1981-88v04"]?["p_KJJ_1"] == 107235)
        #expect(crosswalk["frus1981-88v01"]?["p_KJJ_1"] == 107235, "FRUS-14666 comes first and takes it")
        #expect(try #require(authority["107235"]).q == "Q240534")
        #expect(crosswalk["frus1977-80v11p1"]?["p_KA_1"] == 107120)
        #expect(try #require(authority["107120"]).q == "Q400619")
    }

    @Test("A correction keeps the other person's anchors and ids off the entry's people-id, and nothing else")
    func heldApartAnchorsAndIdentifiers() throws {
        let (crosswalk, authority, stats) = apply([kirkpatrick, khomeini])

        let helen = try #require(authority["107235"])
        #expect(helen.q == nil, "Q240534 is Jeane Kirkpatrick's")
        #expect(helen.v == nil, "71474039 is Jeane Kirkpatrick's")
        #expect(helen.r == "Public Affairs Adviser, Bureau of European Affairs, Department of State",
                "the entry's role text is Helen P.'s, and stays")
        #expect(crosswalk["frus1952-54v11p2"]?["p_KHP1"] == 107235, "Helen P.'s own new anchor still joins her")
        #expect(crosswalk["frus1981-88v04"]?["p_KJJ_1"] == nil,
                "a held-apart anchor no other source names joins no one; the app's clusterer places it")
        // Jeane Kirkpatrick's own entry now reaches vol. I, and the registry keeps vol. III.
        #expect(crosswalk["frus1981-88v01"]?["p_KJJ_1"] == 107237)
        #expect(crosswalk["frus1981-88v03"]?["p_KJJ_1"] == 107237)
        let jeane = try #require(authority["107237"])
        #expect(jeane.q == "Q240534")
        #expect(jeane.v == "71474039")

        let ruhollah = try #require(authority["107120"])
        #expect(ruhollah.q == nil, "Q400619 is Ahmad Khomeini's")
        #expect(ruhollah.v == "88036173", "the VIAF id is Ruhollah Khomeini's own, and stays")
        #expect(ruhollah.r == "dissident Iranian religious leader")
        #expect(crosswalk["frus1977-80v11p1"]?["p_KA_1"] == nil, "Ahmad Khomeini's entry")
        #expect(crosswalk["frus1977-80v11p1"]?["p_KAR_1"] == 107120, "his father's, in the same volume")

        #expect(stats.overlayAnchorsHeldApart == 4, "three of FRUS-14666's and one of FRUS-14463's")
        #expect(stats.overlayIdentifiersWithheld == 3, "two of Jeane Kirkpatrick's and one of Ahmad's")
        #expect(stats.crosswalkConflicts.isEmpty,
                "vol. III's anchor is held apart, not a disagreement with the registry, and vol. I's is no longer claimed twice")
    }

    @Test("A correction holds apart from every people-id of the entry, whichever is canonical")
    func everyPeopleIdOfTheEntry() throws {
        // The anchor joins the first id the registry knows; the correction is keyed on the second.
        var (crosswalk, authority) = registry()
        var stats = BuildStats()
        let merged = PersonsCompleteOverlay.parseEntry("""
            <person xml:id="FRUS-1"><idno type="people-id">107237</idno><idno type="people-id">107235</idno>
            <idno type="Wikidata">Q240534</idno>
            <idno type="frus-ref">frus1981-88v04/persons#p_KJJ_1</idno></person>
            """)
        PersonAuthorityIndexBuilder.applyOverlay(
            .init(entries: [merged], flaggedPeopleIds: [], corrections: [kirkpatrick]),
            crosswalk: &crosswalk, authority: &authority, keepVolume: nil, stats: &stats)
        #expect(crosswalk["frus1981-88v04"]?["p_KJJ_1"] == nil)
        #expect(try #require(authority["107237"]).q == nil)
        #expect(try #require(authority["107235"]).q == nil)
    }

    // MARK: - Refusals

    @Test("Corrections that fit the registry and the overlay pass")
    func fittingCorrectionsPass() {
        let names = registry().authority
        #expect(PersonsCompleteCorrections.misfit(
            of: [kirkpatrick, khomeini], entries: entries(), registryName: { names[$0]?.n }) == nil)
    }

    @Test("A correction whose people-id the registry names otherwise is refused")
    func registryNameMustMatch() {
        let names = registry().authority
        let typo = PersonsCompleteCorrections.HeldApart(
            peopleId: "107237", registryName: "Kirkpatrick, Helen P.", otherPerson: "x",
            anchors: ["frus1981-88v01/persons#p_KJJ_1"], wikidata: nil, viaf: nil, reason: "x")
        #expect(PersonsCompleteCorrections.misfit(of: [typo], entries: entries(), registryName: { names[$0]?.n })
                == .registryNameDiffers(peopleId: "107237", expected: "Kirkpatrick, Helen P.",
                                        found: "Kirkpatrick, Jeane Jordan"))
    }

    @Test("A correction that no longer matches the overlay is refused, not left to do nothing")
    func staleCorrectionsAreRefused() {
        let names = registry().authority
        func misfit(_ correction: PersonsCompleteCorrections.HeldApart,
                    entries: [PersonsCompleteOverlay.Entry]) -> PersonsCompleteCorrections.Problem? {
            PersonsCompleteCorrections.misfit(of: [correction], entries: entries,
                                              registryName: { names[$0]?.n })
        }
        // Upstream fixed or re-minted the entry: no entry carries the id.
        #expect(misfit(kirkpatrick, entries: Array(entries().dropFirst()))
                == .noOverlayEntry(peopleId: "107235"))
        // An anchor the entry does not list.
        let wrongAnchor = PersonsCompleteCorrections.HeldApart(
            peopleId: "107235", registryName: "Kirkpatrick, Helen P.", otherPerson: "x",
            anchors: ["frus1981-88v16/persons#p_KJJ_1"], wikidata: nil, viaf: nil, reason: "x")
        #expect(misfit(wrongAnchor, entries: entries())
                == .anchorNotInEntry(peopleId: "107235", anchor: "frus1981-88v16/persons#p_KJJ_1"))
        // An identifier the entry does not have.
        let wrongId = PersonsCompleteCorrections.HeldApart(
            peopleId: "107120", registryName: "Khomeini, Ruhollah", otherPerson: "x",
            anchors: [], wikidata: "Q38823", viaf: nil, reason: "x")
        #expect(misfit(wrongId, entries: entries())
                == .identifierNotInEntry(peopleId: "107120", identifier: "Q38823"))
    }

    @Test("build refuses a misfit before it applies the overlay")
    func buildThrowsOnAMisfit() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("paig-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try """
        <person><id>107237</id><names><preferred><name>Kirkpatrick, Jeane Jordan</name></preferred>
          <originals><original>
            <source-url>https://history.state.gov/historicaldocuments/frus1981-88v03/persons#p_KJJ_1</source-url>
          </original></originals></names><birth-year>1926</birth-year><death-year>2006</death-year>
        </person>
        """.write(to: dir.appendingPathComponent("107237.xml"), atomically: true, encoding: .utf8)
        // 107235 is not in this registry, so the correction cannot fit it.
        #expect(throws: PersonsCompleteCorrections.Problem.registryNameDiffers(
            peopleId: "107235", expected: "Kirkpatrick, Helen P.", found: nil)) {
            try PersonAuthorityIndexBuilder.build(
                dataDirectory: dir, version: 2, generated: "test", source: "test",
                overlay: .init(entries: entries(), flaggedPeopleIds: [], corrections: [kirkpatrick]))
        }
    }

    // MARK: - The file

    @Test("A corrections file that is incomplete, has a malformed anchor or repeats an id is refused")
    func loadRefusesBadFiles() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("paig-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        func load(_ json: String) throws -> [PersonsCompleteCorrections.HeldApart] {
            let url = dir.appendingPathComponent("\(UUID().uuidString).json")
            try json.write(to: url, atomically: true, encoding: .utf8)
            return try PersonsCompleteCorrections.load(path: url.path)
        }
        func entry(_ id: String, anchors: String = #"["frus1981-88v04/persons#p_KJJ_1"]"#,
                   reason: String = "r") -> String {
            #"{"peopleId":"\#(id)","registryName":"n","otherPerson":"o","anchors":\#(anchors),"wikidata":null,"viaf":null,"reason":"\#(reason)"}"#
        }
        #expect(try load(#"{"heldApart":[\#(entry("1"))]}"#).count == 1)
        #expect(throws: PersonsCompleteCorrections.Problem.incomplete(peopleId: "1")) {
            try load(#"{"heldApart":[\#(entry("1", reason: " "))]}"#)
        }
        #expect(throws: PersonsCompleteCorrections.Problem.incomplete(peopleId: "1")) {
            try load(#"{"heldApart":[\#(entry("1", anchors: "[]"))]}"#)
        }
        #expect(throws: PersonsCompleteCorrections.Problem.badAnchor(peopleId: "1", anchor: "frus1981-88v04#p_KJJ_1")) {
            try load(#"{"heldApart":[\#(entry("1", anchors: #"["frus1981-88v04#p_KJJ_1"]"#))]}"#)
        }
        #expect(throws: PersonsCompleteCorrections.Problem.duplicatePeopleId("1")) {
            try load(#"{"heldApart":[\#(entry("1")),\#(entry("1"))]}"#)
        }
        #expect(throws: PersonsCompleteCorrections.Problem.self) { try load(#"{"tags":[]}"#) }
        #expect(throws: PersonsCompleteCorrections.Problem.self) {
            try PersonsCompleteCorrections.load(path: dir.appendingPathComponent("absent.json").path)
        }
    }

    @Test("The committed corrections hold apart the two entries #1657 names")
    func committedCorrections() throws {
        let corrections = try PersonsCompleteCorrections.load(
            path: Self.repoRoot.appendingPathComponent(PersonsCompleteCorrections.defaultPath).path)
        #expect(corrections.map(\.peopleId) == ["107235", "107120"])
        let helen = try #require(corrections.first)
        #expect(helen.anchors.count == 10, "ten of Jeane J.'s anchors, none of Helen P.'s two")
        #expect(!helen.anchors.contains { $0.contains("p_KHP1") })
        #expect(helen.wikidata == "Q240534" && helen.viaf == "71474039")
        let ruhollah = try #require(corrections.last)
        #expect(ruhollah.anchors == ["frus1977-80v11p1/persons#p_KA_1"])
        #expect(ruhollah.wikidata == "Q400619")
        #expect(ruhollah.viaf == nil, "88036173 is Ruhollah Khomeini's own VIAF id")
    }

    /// The shipped file, read from the repository: regenerated with the corrections, it gives none of
    /// the held-apart anchors or identifiers to the people-id their entry was keyed to. Before #1657's
    /// regeneration it gave all of them.
    @Test("The bundled index gives no held-apart anchor or identifier to the entry's people-id")
    func bundledIndexHoldsThemApart() throws {
        let corrections = try PersonsCompleteCorrections.load(
            path: Self.repoRoot.appendingPathComponent(PersonsCompleteCorrections.defaultPath).path)
        let data = try Data(contentsOf: Self.repoRoot
            .appendingPathComponent("FRUSExplorer/Resources/person-authority-index.json"))
        let index = try JSONDecoder().decode(PersonAuthorityIndex.self, from: data)
        var checked = 0
        for correction in corrections {
            let id = try #require(Int(correction.peopleId))
            for anchor in correction.parsedAnchors {
                #expect(index.crosswalk[anchor.volumeId]?[anchor.ref] != id,
                        "\(anchor.volumeId)#\(anchor.ref) is \(correction.otherPerson)'s")
                checked += 1
            }
            let entry = try #require(index.authority[correction.peopleId])
            #expect(entry.n == correction.registryName)
            if let wikidata = correction.wikidata { #expect(entry.q != wikidata) }
            if let viaf = correction.viaf { #expect(entry.v != viaf) }
        }
        #expect(checked == 11, "every held-apart anchor was looked up")
        // Where the sources do name the other person, the index follows them.
        #expect(index.crosswalk["frus1981-88v01"]?["p_KJJ_1"] == 107237, "FRUS-14668, Jeane Kirkpatrick's own entry")
        #expect(index.crosswalk["frus1981-88v03"]?["p_KJJ_1"] == 107237, "the registry")
        #expect(index.authority["107120"]?.v == "88036173")
        #expect(index.source.contains("held apart"), "the provenance names the corrections")
    }
}
