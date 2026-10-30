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
/// A4c's are `FRUS-00645`, which filed Richard V. Allen's anchors, identifiers and role text under
/// Richard F. Allen, and two entries carrying one people-id, cut down.
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
        // Identifiers taken, so these tests see what a correction withholds (decision 55 takes none).
        PersonAuthorityIndexBuilder.applyOverlay(
            .init(entries: entries(), flaggedPeopleIds: [], corrections: corrections, takesIdentifiers: true),
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
            .init(entries: [merged], flaggedPeopleIds: [], corrections: [kirkpatrick], takesIdentifiers: true),
            crosswalk: &crosswalk, authority: &authority, keepVolume: nil, stats: &stats)
        #expect(crosswalk["frus1981-88v04"]?["p_KJJ_1"] == nil)
        #expect(try #require(authority["107237"]).q == nil)
        #expect(try #require(authority["107235"]).q == nil)
    }

    // MARK: - Role text, and the record held-apart anchors join (A4c)

    /// The registry as it has the two Richard Allens: Richard F. of the 1951 mission to Yugoslavia,
    /// with vol. VIII of 1952–1954's plain "Allen, Richard", and Richard V., with 1981–1988 vol. III.
    private func allenRegistry() -> (crosswalk: [String: [String: Int]], authority: [String: AuthorityEntry]) {
        (["frus1952-54v08": ["p_AR1": 100307], "frus1981-88v03": ["p_ARV_1": 100308]],
         ["100307": AuthorityEntry(n: "Allen, Richard F.", b: nil, d: nil, v: nil),
          "100308": AuthorityEntry(n: "Allen, Richard V.", b: nil, d: nil, v: nil)])
    }

    /// `FRUS-00645` as the overlay has it, cut down: Richard F. Allen's people-id, a first occupation
    /// that is Richard V. Allen's, his identifiers, and three of his anchors, one the registry's.
    private func allenEntry() -> PersonsCompleteOverlay.Entry {
        PersonsCompleteOverlay.parseEntry("""
            <person xml:id="FRUS-00645"><persName type="main">Allen, Richard F.</persName>
            <note type="bio">Chief, ECA Mission in Yugoslavia</note>
            <occupation>planning staff, National Security Council; member, Inter-Agency Youth
                Committee</occupation>
            <occupation>Chief, ECA Mission in Yugoslavia</occupation>
            <idno type="people-id">100307</idno>
            <idno type="VIAF">44887512</idno><idno type="Wikidata">Q517683</idno>
            <idno type="frus-ref">frus1952-54v08/persons#p_AR1</idno>
            <idno type="frus-ref">frus1981-88v03/persons#p_ARV_1</idno>
            <idno type="frus-ref">frus1981-88v04/persons#p_ARV_1</idno>
            <idno type="frus-ref">frus1981-88v38/persons#p_ARV_1</idno></person>
            """)
    }

    private let allen = PersonsCompleteCorrections.HeldApart(
        peopleId: "100307", registryName: "Allen, Richard F.", otherPerson: "Allen, Richard V.",
        anchors: ["frus1981-88v03/persons#p_ARV_1", "frus1981-88v04/persons#p_ARV_1",
                  "frus1981-88v38/persons#p_ARV_1"],
        joins: .init(peopleId: "100308", registryName: "Allen, Richard V."),
        wikidata: "Q517683", viaf: "44887512",
        role: "planning staff, National Security Council; member, Inter-Agency Youth Committee",
        reason: "A4c")

    private func applyAllen(_ corrections: [PersonsCompleteCorrections.HeldApart],
                            entries extra: [PersonsCompleteOverlay.Entry] = [])
        -> (crosswalk: [String: [String: Int]], authority: [String: AuthorityEntry], stats: BuildStats) {
        var (crosswalk, authority) = allenRegistry()
        var stats = BuildStats()
        PersonAuthorityIndexBuilder.applyOverlay(
            .init(entries: [allenEntry()] + extra, flaggedPeopleIds: [], corrections: corrections,
                  takesIdentifiers: true),
            crosswalk: &crosswalk, authority: &authority, keepVolume: nil, stats: &stats)
        return (crosswalk, authority, stats)
    }

    @Test("Without the correction, Richard F. Allen wears Richard V. Allen's anchors, ids and role text")
    func withoutTheAllenCorrection() throws {
        // The other half of the two tests below: what the generator did before A4c.
        let (crosswalk, authority, _) = applyAllen([])
        #expect(crosswalk["frus1981-88v38"]?["p_ARV_1"] == 100307)
        let richardF = try #require(authority["100307"])
        #expect(richardF.q == "Q517683")
        #expect(richardF.r == "planning staff, National Security Council; member, Inter-Agency Youth Committee")
    }

    @Test("A correction withholds the entry's role text when it lists it, and only that text")
    func withheldRoleText() throws {
        let (_, authority, stats) = applyAllen([allen])
        let richardF = try #require(authority["100307"])
        #expect(richardF.r == nil, "the entry's first occupation is Richard V. Allen's")
        #expect(richardF.q == nil && richardF.v == nil)
        #expect(stats.overlayRolesWithheld == 1)
        #expect(try #require(authority["100308"]).r == nil, "a withheld role reaches no record")

        // Another entry carrying the people-id still gives the record its own role text.
        let own = PersonsCompleteOverlay.parseEntry("""
            <person xml:id="FRUS-1"><occupation>Chief, ECA Mission in Yugoslavia</occupation>
            <idno type="people-id">100307</idno></person>
            """)
        let (_, withOwn, _) = applyAllen([allen], entries: [own])
        #expect(try #require(withOwn["100307"]).r == "Chief, ECA Mission in Yugoslavia")

        // A correction without a role leaves the role text alone.
        let noRole = PersonsCompleteCorrections.HeldApart(
            peopleId: "100307", registryName: "Allen, Richard F.", otherPerson: "Allen, Richard V.",
            anchors: allen.anchors, wikidata: nil, viaf: nil, reason: "A4c")
        let (_, kept, keptStats) = applyAllen([noRole])
        #expect(try #require(kept["100307"]).r
                == "planning staff, National Security Council; member, Inter-Agency Youth Committee")
        #expect(keptStats.overlayRolesWithheld == 0)
    }

    @Test("Held-apart anchors join the record the correction names where no source answers, and only there")
    func heldApartAnchorsJoinTheirRecord() {
        let (crosswalk, _, stats) = applyAllen([allen])
        #expect(crosswalk["frus1981-88v04"]?["p_ARV_1"] == 100308)
        #expect(crosswalk["frus1981-88v38"]?["p_ARV_1"] == 100308)
        #expect(crosswalk["frus1981-88v03"]?["p_ARV_1"] == 100308, "the registry's own answer")
        #expect(crosswalk["frus1952-54v08"]?["p_AR1"] == 100307, "Richard F. Allen's own anchor stays his")
        #expect(stats.overlayAnchorsJoined == 2, "vol. III's was the registry's already")
        #expect(stats.crosswalkConflicts.isEmpty)

        // A join never overrides the registry, even when the registry names someone else.
        var (crosswalk2, authority2) = allenRegistry()
        crosswalk2["frus1981-88v04"] = ["p_ARV_1": 100307]
        var stats2 = BuildStats()
        PersonAuthorityIndexBuilder.applyOverlay(
            .init(entries: [allenEntry()], flaggedPeopleIds: [], corrections: [allen]),
            crosswalk: &crosswalk2, authority: &authority2, keepVolume: nil, stats: &stats2)
        #expect(crosswalk2["frus1981-88v04"]?["p_ARV_1"] == 100307)

        // Without a join, a held-apart anchor joins no one.
        let unjoined = PersonsCompleteCorrections.HeldApart(
            peopleId: "100307", registryName: "Allen, Richard F.", otherPerson: "Allen, Richard V.",
            anchors: allen.anchors, wikidata: nil, viaf: nil, reason: "A4c")
        let (crosswalk3, _, stats3) = applyAllen([unjoined])
        #expect(crosswalk3["frus1981-88v38"]?["p_ARV_1"] == nil)
        #expect(stats3.overlayAnchorsJoined == 0)
    }

    @Test("A join only reaches volumes the run keeps")
    func joinsKeepTheManifest() {
        var (crosswalk, authority) = allenRegistry()
        var stats = BuildStats()
        PersonAuthorityIndexBuilder.applyOverlay(
            .init(entries: [allenEntry()], flaggedPeopleIds: [], corrections: [allen]),
            crosswalk: &crosswalk, authority: &authority, keepVolume: { $0 != "frus1981-88v38" },
            stats: &stats)
        #expect(crosswalk["frus1981-88v38"] == nil)
        #expect(crosswalk["frus1981-88v04"]?["p_ARV_1"] == 100308)
    }

    @Test("A role text or a join that does not fit is refused")
    func roleAndJoinMisfits() {
        let names = allenRegistry().authority
        func misfit(_ correction: PersonsCompleteCorrections.HeldApart) -> PersonsCompleteCorrections.Problem? {
            PersonsCompleteCorrections.misfit(of: [correction], entries: [allenEntry()],
                                              registryName: { names[$0]?.n })
        }
        #expect(misfit(allen) == nil)
        let wrongRole = PersonsCompleteCorrections.HeldApart(
            peopleId: "100307", registryName: "Allen, Richard F.", otherPerson: "x", anchors: [],
            wikidata: nil, viaf: nil, role: "Chief, ECA Mission in Yugoslavia", reason: "x")
        #expect(misfit(wrongRole) == .roleNotInEntry(peopleId: "100307", role: "Chief, ECA Mission in Yugoslavia"),
                "the entry's role text is its first occupation, not its second")
        let wrongJoin = PersonsCompleteCorrections.HeldApart(
            peopleId: "100307", registryName: "Allen, Richard F.", otherPerson: "x",
            anchors: ["frus1981-88v04/persons#p_ARV_1"],
            joins: .init(peopleId: "100308", registryName: "Allen, Richard"), wikidata: nil, viaf: nil,
            reason: "x")
        #expect(misfit(wrongJoin) == .joinNameDiffers(peopleId: "100307", joins: "100308",
                                                      expected: "Allen, Richard", found: "Allen, Richard V."))
        let unknownJoin = PersonsCompleteCorrections.HeldApart(
            peopleId: "100307", registryName: "Allen, Richard F.", otherPerson: "x",
            anchors: ["frus1981-88v04/persons#p_ARV_1"],
            joins: .init(peopleId: "199999", registryName: "Allen, Richard V."), wikidata: nil, viaf: nil,
            reason: "x")
        #expect(misfit(unknownJoin) == .joinNameDiffers(peopleId: "100307", joins: "199999",
                                                        expected: "Allen, Richard V.", found: nil))
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

    // MARK: - A record with no anchor of its own, assignments, and what stands apart (#1767)

    /// The registry's records for the John Hughes case: John Chambers Hughes with an anchor, and
    /// (Robert) John Hughes, known from his POCOM page alone, so in the full registry and not the bundle.
    private func hughesRegistry() -> (crosswalk: [String: [String: Int]], authority: [String: AuthorityEntry],
                                      registry: [String: AuthorityEntry]) {
        let chambers = AuthorityEntry(n: "Hughes, John Chambers", b: 1891, d: 1971, v: nil)
        let robert = AuthorityEntry(n: "Hughes, (Robert) John", b: 1930, d: nil, v: nil, s: "hughes-robert-john")
        return (["frus1952-54v05p1": ["p_HJC1": 106247]], ["106247": chambers],
                ["106247": chambers, "106238": robert])
    }

    /// `FRUS-12709`, cut down: three people-ids, and 1981–1988 vol. X's "Hughes, John".
    private func hughesEntry() -> PersonsCompleteOverlay.Entry {
        PersonsCompleteOverlay.parseEntry("""
            <person xml:id="FRUS-12709"><persName type="main">Hughes, John Chambers</persName>
            <idno type="people-id">106247</idno><idno type="people-id">106248</idno><idno type="people-id">106238</idno>
            <idno type="frus-ref">frus1952-54v05p1/persons#p_HJC1</idno>
            <idno type="frus-ref">frus1981-88v10/persons#p_HJ_3</idno></person>
            """)
    }

    @Test("A join may name a record with no anchor of its own, and the bundle keeps it")
    func joinKeepsAnAnchorlessRecord() throws {
        var (crosswalk, authority, registry) = hughesRegistry()
        var stats = BuildStats()
        let hughes = PersonsCompleteCorrections.HeldApart(
            peopleId: "106247", registryName: "Hughes, John Chambers", otherPerson: "Hughes, (Robert) John",
            anchors: ["frus1981-88v10/persons#p_HJ_3"],
            joins: .init(peopleId: "106238", registryName: "Hughes, (Robert) John"),
            wikidata: nil, viaf: nil, reason: "#1767")
        #expect(PersonsCompleteCorrections.misfit(of: [hughes], entries: [hughesEntry()],
                                                  registryName: { registry[$0]?.n }) == nil,
                "the join is checked against the whole registry")
        PersonAuthorityIndexBuilder.applyOverlay(
            .init(entries: [hughesEntry()], flaggedPeopleIds: [], corrections: [hughes]),
            crosswalk: &crosswalk, authority: &authority, keepVolume: nil, stats: &stats, registry: registry)
        #expect(crosswalk["frus1981-88v10"]?["p_HJ_3"] == 106238)
        let kept = try #require(authority["106238"])
        #expect(kept.n == "Hughes, (Robert) John" && kept.s == "hughes-robert-john")
        #expect(stats.recordsKeptForAJoin == 1)
        // The other half: checked against the bundle's records alone, as before #1767, the join does
        // not fit, so the correction could only hold the anchor apart.
        let bundled = hughesRegistry().authority
        #expect(PersonsCompleteCorrections.misfit(of: [hughes], entries: [hughesEntry()],
                                                  registryName: { bundled[$0]?.n })
                == .joinNameDiffers(peopleId: "106247", joins: "106238", expected: "Hughes, (Robert) John", found: nil))
    }

    /// The two Wrights of #1658's tie: Sir Oliver with his vol. XIII entry, and Admiral Jerauld.
    private func wrightRegistry() -> (crosswalk: [String: [String: Int]], authority: [String: AuthorityEntry]) {
        (["frus1981-88v13": ["p_WSJO_1": 114825], "frus1951v05": ["p_WJ1": 114817]],
         ["114825": AuthorityEntry(n: "Wright, Oliver", b: nil, d: nil, v: nil),
          "114817": AuthorityEntry(n: "Wright, Jerauld", b: nil, d: nil, v: nil)])
    }

    private let sirOliver = PersonsCompleteCorrections.Assigned(
        anchor: "frus1981-88v44p1/persons#p_WSJO_1", peopleId: "114825", registryName: "Wright, Oliver",
        reason: "#1767")

    private func assign(_ assigned: [PersonsCompleteCorrections.Assigned],
                        registryCrosswalk: [String: [String: Int]]? = nil,
                        overlayCrosswalk: [String: [String: Int]]? = nil,
                        registry extra: [String: AuthorityEntry] = [:],
                        keepVolume: ((String) -> Bool)? = nil) throws
        -> (crosswalk: [String: [String: Int]], authority: [String: AuthorityEntry], stats: BuildStats) {
        var (crosswalk, authority) = wrightRegistry()
        let registryCrosswalk = registryCrosswalk ?? crosswalk
        if let overlayCrosswalk { crosswalk = overlayCrosswalk }
        var stats = BuildStats()
        try PersonAuthorityIndexBuilder.applyAssignments(
            assigned, registryCrosswalk: registryCrosswalk, crosswalk: &crosswalk, authority: &authority,
            registry: authority.merging(extra) { a, _ in a }, keepVolume: keepVolume, stats: &stats)
        return (crosswalk, authority, stats)
    }

    @Test("An assignment places an anchor no source answers on the record it names")
    func assignmentPlacesTheAnchor() throws {
        let (crosswalk, _, stats) = try assign([sirOliver])
        #expect(crosswalk["frus1981-88v44p1"]?["p_WSJO_1"] == 114825)
        #expect(stats.anchorsAssigned == 1)
        // A volume the run does not keep: nothing written.
        let (dropped, _, droppedStats) = try assign([sirOliver], keepVolume: { $0 != "frus1981-88v44p1" })
        #expect(dropped["frus1981-88v44p1"] == nil && droppedStats.anchorsAssigned == 0)
        // An overlay entry that gives the anchor to the same record: no second write, no refusal.
        var agreeing = wrightRegistry().crosswalk
        agreeing["frus1981-88v44p1"] = ["p_WSJO_1": 114825]
        let (_, _, agreeingStats) = try assign([sirOliver], overlayCrosswalk: agreeing)
        #expect(agreeingStats.anchorsAssigned == 0)
        // A record with no anchor of its own is kept for the anchor, as for a join.
        let miller = PersonsCompleteCorrections.Assigned(
            anchor: "frus1977-80v11p1/persons#p_MWG_1", peopleId: "109170", registryName: "Miller, William Green",
            reason: "#1767")
        let (withMiller, authority, millerStats) = try assign(
            [miller], registry: ["109170": AuthorityEntry(n: "Miller, William Green", b: 1931, d: nil, v: nil,
                                                          s: "miller-william-green")])
        #expect(withMiller["frus1977-80v11p1"]?["p_MWG_1"] == 109170)
        #expect(authority["109170"]?.s == "miller-william-green" && millerStats.recordsKeptForAJoin == 1)
    }

    @Test("An assignment that no longer fits is refused, not left to do nothing")
    func staleAssignmentsAreRefused() throws {
        let typo = PersonsCompleteCorrections.Assigned(
            anchor: sirOliver.anchor, peopleId: "114817", registryName: "Wright, Oliver", reason: "x")
        #expect(throws: PersonsCompleteCorrections.Problem.assignedNameDiffers(
            anchor: sirOliver.anchor, peopleId: "114817", expected: "Wright, Oliver", found: "Wright, Jerauld")) {
            try assign([typo])
        }
        // Upstream took the anchor: the assignment is now the registry's answer, and goes.
        var adopted = wrightRegistry().crosswalk
        adopted["frus1981-88v44p1"] = ["p_WSJO_1": 114825]
        #expect(throws: PersonsCompleteCorrections.Problem.assignmentAnsweredByRegistry(
            anchor: sirOliver.anchor, peopleId: "114825", registry: 114825)) {
            try assign([sirOliver], registryCrosswalk: adopted)
        }
        #expect(PersonsCompleteCorrections.Problem.assignmentAnsweredByRegistry(
            anchor: sirOliver.anchor, peopleId: "114825", registry: 114825).description.contains("remove the assignment"))
        // The registry gives it to someone else.
        var otherwise = wrightRegistry().crosswalk
        otherwise["frus1981-88v44p1"] = ["p_WSJO_1": 114817]
        #expect(throws: PersonsCompleteCorrections.Problem.assignmentAnsweredByRegistry(
            anchor: sirOliver.anchor, peopleId: "114825", registry: 114817)) {
            try assign([sirOliver], registryCrosswalk: otherwise)
        }
        // An overlay entry gives it to someone else.
        #expect(throws: PersonsCompleteCorrections.Problem.assignmentAnsweredByOverlay(
            anchor: sirOliver.anchor, peopleId: "114825", overlay: 114817)) {
            try assign([sirOliver], overlayCrosswalk: otherwise)
        }
    }

    @Test("The anchors that stand apart are the held-apart anchors nothing answered, in kept volumes")
    func apartAnchorsAreTheUnanswered() {
        let corrections = [
            PersonsCompleteCorrections.HeldApart(
                peopleId: "113000", registryName: "Stevenson, Adlai Ewing, II", otherPerson: "Stevenson, Adlai E., III",
                anchors: ["frus1977-80v23/persons#p_SAE_1", "frus1969-76v01/persons#p_SAE2"],
                wikidata: nil, viaf: nil, reason: "x"),
            PersonsCompleteCorrections.HeldApart(
                peopleId: "104298", registryName: "Fish, Hamilton", otherPerson: "Fish, Hamilton, III",
                anchors: ["frus1933-39/persons#p_FH2", "frus1977-80v23/persons#p_FH_1"],
                wikidata: nil, viaf: nil, reason: "x"),
        ]
        let crosswalk = ["frus1969-76v01": ["p_SAE2": 113001]]
        let apart = PersonAuthorityIndexBuilder.apartAnchors(of: corrections, crosswalk: crosswalk,
                                                             keepVolume: { $0 != "frus1933-39" })
        #expect(apart == ["frus1977-80v23": ["p_FH_1", "p_SAE_1"]],
                "answered anchors and volumes the run does not keep are left out, and refs are sorted")
    }

    @Test("A file's assignments that are incomplete, malformed, repeated or also joined are refused")
    func loadAssignmentsRefusesBadFiles() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("paig-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        func load(heldApart: String = "", _ assigned: String?) throws -> [PersonsCompleteCorrections.Assigned] {
            let url = dir.appendingPathComponent("\(UUID().uuidString).json")
            let tail = assigned.map { #","assigned":[\#($0)]"# } ?? ""
            try #"{"heldApart":[\#(heldApart)]\#(tail)}"#.write(to: url, atomically: true, encoding: .utf8)
            return try PersonsCompleteCorrections.loadAssignments(path: url.path)
        }
        func assignment(_ anchor: String = "frus1981-88v44p1/persons#p_WSJO_1", reason: String = "r") -> String {
            #"{"anchor":"\#(anchor)","peopleId":"114825","registryName":"Wright, Oliver","reason":"\#(reason)"}"#
        }
        #expect(try load(nil).isEmpty, "a file written before #1767 has none")
        #expect(try load(assignment()).count == 1)
        #expect(throws: PersonsCompleteCorrections.Problem.assignmentIncomplete(anchor: "frus1981-88v44p1/persons#p_WSJO_1")) {
            try load(assignment(reason: " "))
        }
        #expect(throws: PersonsCompleteCorrections.Problem.badAssignedAnchor(anchor: "frus1981-88v44p1#p_WSJO_1")) {
            try load(assignment("frus1981-88v44p1#p_WSJO_1"))
        }
        #expect(throws: PersonsCompleteCorrections.Problem.duplicateAssignment(anchor: "frus1981-88v44p1/persons#p_WSJO_1")) {
            try load(assignment() + "," + assignment())
        }
        // A held-apart anchor may be assigned when its correction joins none, and not when it joins one.
        let unjoined = #"{"peopleId":"108262","registryName":"n","otherPerson":"o","anchors":["frus1981-88v44p1/persons#p_WSJO_1"],"wikidata":null,"viaf":null,"reason":"r"}"#
        #expect(try load(heldApart: unjoined, assignment()).count == 1)
        let joined = #"{"peopleId":"108262","registryName":"n","otherPerson":"o","anchors":["frus1981-88v44p1/persons#p_WSJO_1"],"joins":{"peopleId":"2","registryName":"m"},"wikidata":null,"viaf":null,"reason":"r"}"#
        #expect(throws: PersonsCompleteCorrections.Problem.assignmentAlsoJoined(anchor: "frus1981-88v44p1/persons#p_WSJO_1")) {
            try load(heldApart: joined, assignment())
        }
    }

    // MARK: - The file

    @Test("A corrections file that is incomplete, has a malformed anchor, repeats an id or misplaces a join is refused")
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
        // A4's entries have no role or joins key: they hold none.
        let plain = try #require(try load(#"{"heldApart":[\#(entry("1"))]}"#).first)
        #expect(plain.role == nil && plain.joins == nil)
        // A role text alone is something to withhold.
        let roleOnly = #"{"peopleId":"1","registryName":"n","otherPerson":"o","anchors":[],"wikidata":null,"viaf":null,"role":"r","reason":"r"}"#
        #expect(try load(#"{"heldApart":[\#(roleOnly)]}"#).first?.role == "r")
        // A join needs anchors, and another person's id.
        let joinsNothing = #"{"peopleId":"1","registryName":"n","otherPerson":"o","anchors":[],"joins":{"peopleId":"2","registryName":"m"},"wikidata":"Q1","viaf":null,"reason":"r"}"#
        #expect(throws: PersonsCompleteCorrections.Problem.joinMisplaced(peopleId: "1")) {
            try load(#"{"heldApart":[\#(joinsNothing)]}"#)
        }
        let joinsItself = #"{"peopleId":"1","registryName":"n","otherPerson":"o","anchors":["frus1981-88v04/persons#p_KJJ_1"],"joins":{"peopleId":"1","registryName":"n"},"wikidata":null,"viaf":null,"reason":"r"}"#
        #expect(throws: PersonsCompleteCorrections.Problem.joinMisplaced(peopleId: "1")) {
            try load(#"{"heldApart":[\#(joinsItself)]}"#)
        }
        #expect(throws: PersonsCompleteCorrections.Problem.self) { try load(#"{"tags":[]}"#) }
        #expect(throws: PersonsCompleteCorrections.Problem.self) {
            try PersonsCompleteCorrections.load(path: dir.appendingPathComponent("absent.json").path)
        }
    }

    @Test("The committed corrections hold apart the two entries #1657 names and A4c's eighty")
    func committedCorrections() throws {
        let corrections = try PersonsCompleteCorrections.load(
            path: Self.repoRoot.appendingPathComponent(PersonsCompleteCorrections.defaultPath).path)
        #expect(Array(corrections.map(\.peopleId).prefix(2)) == ["107235", "107120"])
        #expect(corrections.count == 82, "#1657's two and A4c's eighty")
        #expect(corrections.reduce(0) { $0 + $1.anchors.count } == 156)
        #expect(corrections.count { $0.joins != nil } == 21,
                "A4c's sixteen, and five #1767 found a record for: Jeane Kirkpatrick's, Mueller's, and three with no FRUS anchor")
        let joined = Dictionary(uniqueKeysWithValues: corrections.compactMap { c in c.joins.map { (c.peopleId, $0.peopleId) } })
        #expect(joined["107235"] == "107237", "Jeane J. Kirkpatrick's entries are Jeane Jordan Kirkpatrick's")
        #expect(joined["106247"] == "106238" && joined["108798"] == "108802" && joined["109156"] == "109170",
                "John Hughes, Richard T. McCormack and William G. Miller, known to the registry from POCOM alone")
        #expect(joined["109500"] == "109501")
        #expect(corrections.count { $0.role != nil } == 23)
        #expect(corrections.count { $0.wikidata != nil } == 55)
        #expect(corrections.count { $0.viaf != nil } == 45)
        let allen = try #require(corrections.first { $0.peopleId == "100307" })
        #expect(allen.registryName == "Allen, Richard F.")
        #expect(allen.anchors.count == 13, "Richard V. Allen's thirteen, none of Richard F.'s three")
        #expect(!allen.anchors.contains { $0.contains("p_ARF1") || $0.hasPrefix("frus1952-54v08/") })
        #expect(allen.joins == .init(peopleId: "100308", registryName: "Allen, Richard V."))
        #expect(allen.wikidata == "Q517683" && allen.viaf == "44887512")
        #expect(allen.role?.hasPrefix("planning staff, National Security Council") == true)
        let tabatabai = try #require(corrections.first { $0.peopleId == "113288" })
        #expect(tabatabai.anchors == ["frus1977-80v11p1/persons#p_TS_1"], "Sadegh Tabatabai")
        let helen = try #require(corrections.first)
        #expect(helen.anchors.count == 10, "ten of Jeane J.'s anchors, none of Helen P.'s two")
        #expect(!helen.anchors.contains { $0.contains("p_KHP1") })
        #expect(helen.wikidata == "Q240534" && helen.viaf == "71474039")
        let ruhollah = try #require(corrections.dropFirst().first)
        #expect(ruhollah.anchors == ["frus1977-80v11p1/persons#p_KA_1"])
        #expect(ruhollah.wikidata == "Q400619")
        #expect(ruhollah.viaf == nil, "88036173 is Ruhollah Khomeini's own VIAF id")

        let assigned = try PersonsCompleteCorrections.loadAssignments(
            path: Self.repoRoot.appendingPathComponent(PersonsCompleteCorrections.defaultPath).path)
        #expect(assigned.map(\.anchor) == ["frus1977-80v15/persons#p_MDG_1", "frus1981-88v44p1/persons#p_WSJO_1",
                                           "frus1981-88v01/persons#p_WJO_1", "frus1917-72PubDipv08/persons#p_WJ_1",
                                           "frus1977-80v15/persons#p_WJC_1", "frus1981-88v01/persons#p_WJC_2",
                                           "frus1981-88v44p1/persons#p_WJ_3"])
        #expect(assigned.map(\.peopleId) == ["108264", "114825", "114825", "114818", "114818", "114818", "114818"],
                "Donald G. MacDonald of AID, Sir Oliver Wright twice, and Speaker Jim Wright four times")
    }

    /// The shipped file, read from the repository: regenerated with the corrections, it gives none of
    /// the held-apart anchors, identifiers or role texts to the people-id their entry was keyed to,
    /// and a joined anchor to the record its correction names. Before #1657's regeneration it gave
    /// all of the first two, and before A4c's it gave Richard V. Allen's anchors to Richard F. Allen.
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
            if let role = correction.role {
                #expect(entry.r != AuthorityEntry.truncatedRole(role, limit: 120),
                        "\(correction.peopleId) wears \(correction.otherPerson)'s role text")
            }
            if let joins = correction.joins {
                let joined = try #require(Int(joins.peopleId))
                #expect(index.authority[joins.peopleId]?.n == joins.registryName)
                for anchor in correction.parsedAnchors {
                    #expect(index.crosswalk[anchor.volumeId]?[anchor.ref] == joined,
                            "\(anchor.volumeId)#\(anchor.ref) joins \(joins.registryName)")
                }
            }
        }
        #expect(checked == 156, "every held-apart anchor was looked up")
        // Every held-apart anchor is answered or stands apart, never both (#1767): the 69 that no source,
        // join or assignment answers, people no record could be shown to be.
        var standingApart = 0
        for correction in corrections {
            for anchor in correction.parsedAnchors {
                let listed = index.apart?[anchor.volumeId]?.contains(anchor.ref) ?? false
                #expect(listed == (index.crosswalk[anchor.volumeId]?[anchor.ref] == nil),
                        "\(anchor.volumeId)#\(anchor.ref)")
                if listed {
                    #expect(correction.joins == nil, "a joined anchor never stands apart")
                    standingApart += 1
                }
            }
        }
        #expect(standingApart == 69)
        #expect(index.apart?.values.reduce(0) { $0 + $1.count } == 69, "the list holds nothing a correction does not")
        #expect(index.apart?.values.allSatisfy { $0 == $0.sorted() } == true)
        #expect(index.apart?["frus1977-80v23"]?.contains("p_SAE_1") == true, "Adlai E. Stevenson III")
        #expect(index.apart?["frus1981-88v41"]?.contains("p_MDS_1") == true,
                "Donald S. MacDonald of INR, whom 108265's 1962 entry cannot be shown to be")
        // The assignments, and the records three joins keep though they have no FRUS anchor.
        #expect(index.crosswalk["frus1981-88v44p1"]?["p_WSJO_1"] == 114825, "Sir Oliver Wright")
        #expect(index.crosswalk["frus1981-88v01"]?["p_WJO_1"] == 114825)
        #expect(index.crosswalk["frus1977-80v15"]?["p_MDG_1"] == 108264)
        // Speaker Jim Wright's four entries, which the rollup joined by name to Sir Oliver Wright.
        for (volumeId, ref) in [("frus1917-72PubDipv08", "p_WJ_1"), ("frus1977-80v15", "p_WJC_1"),
                                ("frus1981-88v01", "p_WJC_2"), ("frus1981-88v44p1", "p_WJ_3")] {
            #expect(index.crosswalk[volumeId]?[ref] == 114818, "\(volumeId)#\(ref) is Speaker Jim Wright's")
        }
        #expect(index.authority["114818"]?.n == "Wright, Jim")
        #expect(index.crosswalk["frus1981-88v10"]?["p_HJ_3"] == 106238)
        #expect(index.authority["106238"]?.s == "hughes-robert-john")
        #expect(index.authority["108802"]?.s == "mccormack-richard-t")
        #expect(index.authority["109170"]?.s == "miller-william-green")
        #expect(index.source.contains("assigned, by the same file"), "the provenance names the assignments")
        // Richard V. Allen's 1981-1988 entries are his, and Richard F. Allen keeps his own three.
        #expect(index.crosswalk["frus1981-88v38"]?["p_ARV_1"] == 100308)
        #expect(index.crosswalk["frus1952-54v08"]?["p_AR1"] == 100307)
        #expect(index.authority["100307"]?.q == nil && index.authority["100307"]?.r == nil)
        #expect(index.crosswalk["frus1981-88v05"]?["p_TWHIV_1"] == 113304, "William H. Taft IV")
        #expect(index.crosswalk["frus1977-80v11p1"]?["p_TS_1"] == nil, "Sadegh Tabatabai has no record")
        // Where the sources do name the other person, the index follows them.
        #expect(index.crosswalk["frus1981-88v01"]?["p_KJJ_1"] == 107237, "FRUS-14668, Jeane Kirkpatrick's own entry")
        #expect(index.crosswalk["frus1981-88v03"]?["p_KJJ_1"] == 107237, "the registry")
        // 88036173 is Ruhollah Khomeini's own VIAF id, but only the overlay gives it (his registry
        // record holds none), and since decision 55 the overlay's VIAF ids are not taken.
        #expect(index.authority["107120"]?.v == nil)
        #expect(index.source.contains("held apart"), "the provenance names the corrections")
    }

    /// Decision 55 (2026-10-17), in the shipped file: about 1,600 of the 3,769 Wikidata ids the
    /// overlay gave the bundle named someone else, and so did about 580 of the 2,186 of its VIAF ids
    /// that could be checked (`Planning/Person-Authority-Identifier-Assessment-2026-10-17.md`), so a
    /// run takes none. No record carries a Wikidata id, and the VIAF ids left are the registry's own:
    /// 142 at people `63b537ad`. A regeneration against a newer registry may move that count.
    @Test("The bundled index takes no Wikidata or VIAF id from the overlay")
    func bundledIndexTakesNoOverlayIdentifier() throws {
        let data = try Data(contentsOf: Self.repoRoot
            .appendingPathComponent("FRUSExplorer/Resources/person-authority-index.json"))
        let index = try JSONDecoder().decode(PersonAuthorityIndex.self, from: data)
        #expect(index.authority.count == 12_839, "the registry's 12,836 records, and three a join keeps (#1767)")
        #expect(index.authority.values.allSatisfy { $0.q == nil }, "every Wikidata id came from the overlay")
        #expect(index.authority.values.count { $0.v != nil } == 142, "the registry's own VIAF ids")
        #expect(index.authority.values.count { $0.r != nil } == 12_787, "the overlay's role texts still apply")
        #expect(index.source.contains("the overlay's Wikidata and VIAF ids are not taken"),
                "the provenance says so")
    }
}
