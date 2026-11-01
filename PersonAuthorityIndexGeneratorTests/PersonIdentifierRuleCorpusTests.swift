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

/// The identifier rule and the multi-person role rule (#1767) on the corpus's own cases, the ones the
/// identifier assessment named (`Planning/Person-Authority-Identifier-Assessment-2026-10-17.md` §3, §5,
/// §7.2): the items are the committed Wikidata snapshot's, and the records are the registry's
/// (`HistoryAtState/people` at `63b537ad`), copied here with the remarks that matter.
///
/// A refreshed snapshot can move one of these: when an item's facts change on Wikidata, read the item
/// before changing the expectation.
@Suite("person identifier rule, the corpus's cases")
struct PersonIdentifierRuleCorpusTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func committedRule() throws -> PersonIdentifierRule {
        PersonIdentifierRule(snapshot: try WikidataSnapshot.load(
            path: repoRoot.appendingPathComponent(WikidataSnapshot.defaultPath).path))
    }

    // MARK: - Item 1: the identifiers

    /// 107025's entry carries John N. Kennedy, the senator from Louisiana born in 1951 (A4c's find).
    @Test("John F. Kennedy's record does not take John N. Kennedy's item")
    func theKennedys() throws {
        let rule = try Self.committedRule()
        let jfk = PersonIdentifierRule.Record(
            name: "Kennedy, John F.", birthYear: 1917, deathYear: 1963,
            remarks: ["Democratic Senator from Massachusetts", "President of the United States from January 20, 1961"],
            firstVolumeYear: 1958)
        #expect(rule.decideWikidata("Q6250211", for: jfk, recordVIAF: nil)
                == .init(accepted: false, reason: "birth-year,too-young"))
    }

    /// 108893's entry carries Jeremiah Denton's item, with Kinnaird R. McKee's own VIAF id, which the
    /// item for McKee holds.
    @Test("Kinnaird R. McKee does not take Jeremiah Denton's item, and keeps his own VIAF id through its holder")
    func mckeeAndDenton() throws {
        let rule = try Self.committedRule()
        let mckee = PersonIdentifierRule.Record(
            name: "McKee, Kinnaird R.", birthYear: nil, deathYear: nil,
            remarks: ["Rear Admiral, USN, Director, Executive Panel, Office of the Chief of Naval Operations"],
            firstVolumeYear: 1969)
        #expect(rule.decideWikidata("Q731680", for: mckee, recordVIAF: "48112119")
                == .init(accepted: false, reason: "surname,given-name,viaf-held-by-other-item"))
        #expect(rule.decideVIAF("48112119", for: mckee, acceptedItem: nil)
                == .init(accepted: true, reason: "held by Q6414023: role words admiral"))
    }

    /// 101726's entry carries the aircraft carrier *Admiral Kuznetsov*, launched as *Leonid Brezhnev*,
    /// and a VIAF id no item holds.
    @Test("Leonid Brezhnev does not take the aircraft carrier, or a VIAF id nothing corroborates")
    func brezhnevAndTheCarrier() throws {
        let rule = try Self.committedRule()
        let brezhnev = PersonIdentifierRule.Record(
            name: "Brezhnev, Leonid I.", birthYear: nil, deathYear: nil,
            remarks: ["General Secretary of the Communist Party of the Soviet Union"], firstVolumeYear: 1952)
        #expect(rule.snapshot.items["Q274924"]?.names.contains("Leonid Brezhnev") == true,
                "the ship's former name is why the overlay matched it")
        #expect(rule.decideWikidata("Q274924", for: brezhnev, recordVIAF: "5999160486121405180008")
                == .init(accepted: false, reason: "not-a-person"))
        #expect(rule.decideVIAF("5999160486121405180008", for: brezhnev, acceptedItem: nil)
                == .init(accepted: false, reason: "held by no item"))
    }

    /// `FRUS-04734` carries Raúl Castro of Cuba (102311) and Raul H. Castro, U.S. Ambassador (102312),
    /// with Raúl Castro's item and VIAF id. The rule tests each id against each record.
    @Test("The Castros: Raúl Castro keeps his item and VIAF id, and Raul H. Castro takes neither")
    func theCastros() throws {
        let rule = try Self.committedRule()
        let raul = PersonIdentifierRule.Record(
            name: "Castro, Raúl", birthYear: nil, deathYear: nil,
            remarks: ["Commander in Chief of the Cuban Armed Forces from February 1959; also Minister of the Revolutionary Armed Forces from October 1959",
                      "Cuban Minister of the Armed Forces", "Minister of the Armed Forces of Cuba"],
            firstVolumeYear: 1958)
        let ambassador = PersonIdentifierRule.Record(
            name: "Castro, Raul Hector", birthYear: 1916, deathYear: 2015,
            remarks: ["Ambassador to El Salvador October 3, 1964–July 17, 1968; Ambassador to Bolivia from August 1, 1968"],
            firstVolumeYear: 1964)
        #expect(rule.decideWikidata("Q46809", for: raul, recordVIAF: "97724278")
                == .init(accepted: true, reason: "item-holds-record-viaf"))
        #expect(rule.decideVIAF("97724278", for: raul, acceptedItem: "Q46809") == .init(accepted: true, reason: "held by Q46809"))
        #expect(rule.decideWikidata("Q46809", for: ambassador, recordVIAF: "97724278")
                == .init(accepted: false, reason: "birth-year"))
        #expect(rule.decideVIAF("97724278", for: ambassador, acceptedItem: nil)
                == .init(accepted: false, reason: "held by Q46809 birth-year"))
    }

    /// `FRUS-07952` carries the President of Italy (103878) and his grandson Luigi R. Einaudi (103879),
    /// with the grandson's item and the President's VIAF id. The President keeps his VIAF id through its
    /// holder. Held against that VIAF id, the grandson's own item fails (`viaf-held-by-other-item`): the
    /// rule alone cannot tell which of the entry's two ids is the wrong one. The builder can, since the
    /// rule gives the VIAF id to the President (``einaudiThroughTheBuilder()``).
    @Test("The Einaudis: the President keeps his VIAF id, and the grandson's item fails against it")
    func theEinaudis() throws {
        let rule = try Self.committedRule()
        let president = PersonIdentifierRule.Record(
            name: "Einaudi, Luigi", birthYear: nil, deathYear: nil,
            remarks: ["Governor of the Bank of Italy", "President of the Italian Republic, May 1948–April 1955.",
                      "President of Italy until April 1955"],
            firstVolumeYear: 1946)
        let grandson = PersonIdentifierRule.Record(
            name: "Einaudi, Luigi R.", birthYear: 1936, deathYear: nil,
            remarks: ["Non-career appointee. Permanent Representative of the U.S.A. to the Organization of American States (Washington).",
                      "Policy Planning Staff, Department of State"],
            firstVolumeYear: 1969)
        #expect(rule.decideWikidata("Q6700117", for: president, recordVIAF: "56623995")
                == .init(accepted: false, reason: "too-young,viaf-held-by-other-item"))
        let presidentsVIAF = rule.decideVIAF("56623995", for: president, acceptedItem: nil)
        #expect(presidentsVIAF.accepted && presidentsVIAF.reason.hasPrefix("held by Q1242: role words"))
        #expect(rule.decideWikidata("Q6700117", for: grandson, recordVIAF: "56623995")
                == .init(accepted: false, reason: "viaf-held-by-other-item"))
        #expect(rule.decideVIAF("56623995", for: grandson, acceptedItem: nil)
                == .init(accepted: false, reason: "held by Q1242 birth-year"))
    }

    /// The same entry through the builder (#1767's follow-up): the entry's VIAF id is the President's, whom
    /// the rule gives it on its holder's facts, and it is no longer held against the item the entry offers
    /// his grandson, who takes his own on the registry's year of birth.
    @Test("The Einaudis through the builder: the grandson takes his own item, the President his VIAF id")
    func einaudiThroughTheBuilder() throws {
        let entry = PersonsCompleteOverlay.parseEntry("""
            <person xml:id="FRUS-07952"><persName type="main">Einaudi, Luigi R.</persName>
            <occupation>Non-career appointee. Permanent Representative of the U.S.A. to the Organization of
                American States (Washington).</occupation>
            <idno type="people-id">103878</idno><idno type="VIAF">56623995</idno>
            <idno type="Wikidata">Q6700117</idno><idno type="people-id">103879</idno></person>
            """)
        var crosswalk: [String: [String: Int]] = [:]
        var authority = ["103878": AuthorityEntry(n: "Einaudi, Luigi", b: nil, d: nil, v: nil),
                         "103879": AuthorityEntry(n: "Einaudi, Luigi R.", b: 1936, d: nil, v: nil)]
        let facts = ["103878": RegistryFacts(remarks: ["Governor of the Bank of Italy",
                                                       "President of the Italian Republic, May 1948–April 1955.",
                                                       "President of Italy until April 1955"], firstVolumeYear: 1946),
                     "103879": RegistryFacts(remarks: ["Non-career appointee. Permanent Representative of the U.S.A. to the Organization of American States (Washington).",
                                                       "Policy Planning Staff, Department of State"], firstVolumeYear: 1969)]
        var stats = BuildStats()
        PersonAuthorityIndexBuilder.applyOverlay(
            .init(entries: [entry], flaggedPeopleIds: [], takesIdentifiers: true, identifierRule: try Self.committedRule()),
            crosswalk: &crosswalk, authority: &authority, keepVolume: nil, stats: &stats, registryFacts: facts)
        #expect(authority["103878"]?.v == "56623995" && authority["103878"]?.q == nil, "the President")
        #expect(authority["103879"]?.q == "Q6700117" && authority["103879"]?.v == nil, "Luigi R. Einaudi")
        #expect(stats.identifiersWithheldByRule.map { "\($0.peopleId) \($0.identifier)" }.sorted()
                == ["103878 Q6700117", "103879 56623995"])
    }

    /// `FRUS-16841` carries the General (108250) with his own item, `Q127417`, and his nephew Douglas
    /// MacArthur II's VIAF id, which `Q269483` holds. *Japan*, in both, lets the VIAF id in through its
    /// holder, and held against it the General's own item fails: what the rule cannot see. The correction
    /// that withholds the VIAF id (#1767's follow-up) leaves the item tested alone, and it passes.
    @Test("General MacArthur takes his nephew's VIAF id on Japan, and his own item only with it withheld")
    func generalMacArthur() throws {
        let rule = try Self.committedRule()
        let general = PersonIdentifierRule.Record(
            name: "MacArthur, Douglas", birthYear: nil, deathYear: nil,
            remarks: ["U. S. A., Commanding General, United States Army Forces, Pacific; Supreme Commander, Southwest Pacific Area.",
                      "Commanding General, United States Armed Forces in the Pacific; Supreme Commander, Allied Powers in Japan"],
            firstVolumeYear: 1945)
        #expect(rule.decideVIAF("7088488", for: general, acceptedItem: nil)
                == .init(accepted: true, reason: "held by Q269483: role words japan"))
        #expect(rule.decideWikidata("Q127417", for: general, recordVIAF: "7088488")
                == .init(accepted: false, reason: "viaf-held-by-other-item"))
        #expect(rule.decideWikidata("Q127417", for: general, recordVIAF: nil)
                == .init(accepted: true, reason: "role words army"))
    }

    /// 103111's entry carries his son Ralf's item, which meets his remark on the word *Germany* alone, and
    /// "Ralf G." fits his given name by its initial. Countries stay role words (left out, they took 17 right
    /// ids to take 2 wrong), so a correction withholds it (#1767's follow-up).
    @Test("Gustav Dahrendorf's entry offers his son's item, which the rule takes on Germany")
    func dahrendorf() throws {
        let rule = try Self.committedRule()
        let gustav = PersonIdentifierRule.Record(
            name: "Dahrendorf, Gustav", birthYear: nil, deathYear: nil,
            remarks: ["Vice President of the Economic Council in the U.S.–U.K. zones of occupation of Germany"],
            firstVolumeYear: 1948)
        #expect(rule.decideWikidata("Q76959", for: gustav, recordVIAF: nil)
                == .init(accepted: true, reason: "role words germany"))
    }

    /// `FRUS-28039` carries the President (113770) and his nephew (116214), with the President's item.
    /// What the rule cannot see: the nephew's own remark names the President, and nothing of the
    /// registry's contradicts the item, so he takes it as well. A correction would take it from both, so
    /// the corrections file keeps it off the nephew alone (`withheld`, #1767's follow-up).
    @Test("Truman's nephew takes the President's item: two relatives of one name and era")
    func trumansNephew() throws {
        let rule = try Self.committedRule()
        let president = PersonIdentifierRule.Record(
            name: "Truman, Harry S.", birthYear: 1884, deathYear: 1972,
            remarks: ["President of the United States, 1945–53."], firstVolumeYear: 1943)
        let nephew = PersonIdentifierRule.Record(
            name: "Truman, Harry", birthYear: nil, deathYear: nil,
            remarks: ["U. S. A., nephew of the President."], firstVolumeYear: 1945)
        #expect(rule.decideWikidata("Q11613", for: president, recordVIAF: nil)
                == .init(accepted: true, reason: "registry-years-agree"))
        #expect(rule.decideWikidata("Q11613", for: nephew, recordVIAF: nil)
                == .init(accepted: true, reason: "role words president"))
    }

    // MARK: - Item 2: a multi-person entry's role text

    /// The ten records the assessment's §7.2 found losing their copy of a role text: each is one person
    /// the registry holds twice, and the other record, whose remarks hold the text, keeps it.
    private static let duplicates: [(lost: String, lostRemarks: [String], kept: String, keptRemarks: [String], role: String)] = [
        ("102950", ["Lieutenant General, Chairman of the Inter-American Defense Board from February 28, 1953 until March 15, 1955."],
         "115343", ["U. S. A., Chief, Theater Group, Operations Division, War Department General Staff."],
         "U. S. A., Chief, Theater Group, Operations Division, War Department General Staff"),
        ("103955", ["French Army; Representative to the NATO Standing Group until August 1953; Chief of the General Staff, August 1953–June 1954; Commander in Chief and General Commander in Indochina from June 3, 1954."],
         "103956", ["Chief, French Military Mission in the United States; French Permanent Representative, NATO Standing Group."],
         "Chief, French Military Mission in the United States; French Permanent Representative, NATO Standing Group"),
        ("104525", ["Chairman, Anglo–Iranian Oil Company, Limited, and its subsidiary companies; Director of the Burmah Oil Company, Limited; Petroleum Adviser to the British War Office.",
                    "Chairman of the Board, Anglo-Iranian Oil Company."],
         "115484", ["Chairman of the Anglo-Iranian Oil Company."],
         "Chairman of the Anglo-Iranian Oil Company"),
        ("109533", ["Argentine Foreign Minister, October 1962-October 1963"],
         "115902", ["Argentine Permanent Representative to the United Nations from August 1982"],
         "Argentine Permanent Representative to the United Nations from August 1982"),
        ("111818", ["Vice Admiral, Greek Minister of National Defense."],
         "116069", ["Royal Hellenic Navy (Ret.), member of the Greek Parliament as co-leader of the National Re-Creation Front until 1951; Greek Minister of National Defense, from October 1951."],
         "Royal Hellenic Navy (Ret.), member of the Greek Parliament as co-leader of the National Re-Creation Front until 1951; Greek Minister of National Defense, from October 1951"),
        ("115687", ["Director, Federal Bureau of Investigation, from July 9, 1973"],
         "115688", ["Director of the Federal Bureau of Investigation until February 1978"],
         "Director of the Federal Bureau of Investigation until February 1978"),
        // An em dash in the registry's remark, a hyphen in the overlay's text: folded alike.
        ("115858", ["member, U.S. House of Representatives (D-New Jersey) until January 3, 1979"],
         "115857", ["member, U.S. House of Representatives (D—New Jersey) until January 1979"],
         "member, U.S. House of Representatives (D-New Jersey) until January 1979"),
        ("115861", ["Deputy Prime Minister and Minister of Agriculture and Agrarian Reform in the Polish Provisional Government of National Unity."],
         "109135", ["Prime Minister, Poland (government-in-exile). Visited U.S. once, 1944",
                    "Prime Minister in the Polish Government-in-Exile at London, 1943–44."],
         "Prime Minister in the Polish Government-in-Exile at London, 1943–44"),
        ("116018", ["Consul General at Johannesburg."],
         "116019", ["Political Division, United States Group, Control Council (Germany)."],
         "Political Division, United States Group, Control Council (Germany)"),
        ("116022", ["Secretary of Treasury from January 1981"],
         "116023", ["Secretary of the Treasury from January 22, 1981"],
         "Secretary of the Treasury from January 22, 1981"),
    ]

    @Test("The ten duplicates: the record whose remarks hold the role text keeps it, its twin does not")
    func theTenDuplicates() {
        for d in Self.duplicates {
            #expect(RegistryFacts(remarks: d.keptRemarks).remarksHold(d.role), "\(d.kept) holds its role text")
            #expect(!RegistryFacts(remarks: d.lostRemarks).remarksHold(d.role), "\(d.lost) does not")
        }
    }

    @Test("Remarks hold a role text with case, accents, dashes and spaces folded, and its end's punctuation aside")
    func remarksHold() {
        let facts = RegistryFacts(remarks: ["Président of the  Council—of Ministers, 1953–1955."])
        #expect(facts.remarksHold("president of the council-of ministers, 1953-1955"))
        #expect(facts.remarksHold("Council of Ministers"), "a part of a remark holds it")
        #expect(!facts.remarksHold("Council of State"))
        #expect(!facts.remarksHold(" .;, "), "a text that folds to nothing is held by nothing")
        #expect(!RegistryFacts(remarks: []).remarksHold("President"))
    }

    @Test("An entry carrying several people gives its role text only to those whose remarks hold it")
    func multiPersonRole() {
        let entry = PersonsCompleteOverlay.parseEntry("""
            <person xml:id="FRUS-04734"><persName type="main">Castro, Raúl</persName>
            <occupation>Commander in Chief of the Cuban Armed Forces from February 1959; also Minister of the
                Revolutionary Armed Forces from October 1959</occupation>
            <idno type="people-id">102311</idno><idno type="people-id">102312</idno></person>
            """)
        let single = PersonsCompleteOverlay.parseEntry("""
            <person xml:id="FRUS-2"><occupation>Ambassador to Bolivia</occupation>
            <idno type="people-id">102312</idno></person>
            """)
        var crosswalk: [String: [String: Int]] = [:]
        var authority = ["102311": AuthorityEntry(n: "Castro, Raúl", b: nil, d: nil, v: nil),
                         "102312": AuthorityEntry(n: "Castro, Raul Hector", b: 1916, d: 2015, v: nil)]
        let facts = ["102311": RegistryFacts(remarks: ["Commander in Chief of the Cuban Armed Forces from February 1959; also Minister of the Revolutionary Armed Forces from October 1959"]),
                     "102312": RegistryFacts(remarks: ["Ambassador to El Salvador October 3, 1964–July 17, 1968"])]
        var stats = BuildStats()
        PersonAuthorityIndexBuilder.applyOverlay(
            .init(entries: [entry, single], flaggedPeopleIds: []), crosswalk: &crosswalk, authority: &authority,
            keepVolume: nil, stats: &stats, registryFacts: facts)
        #expect(authority["102311"]?.r?.hasPrefix("Commander in Chief of the Cuban Armed Forces") == true)
        #expect(authority["102312"]?.r == "Ambassador to Bolivia",
                "the ambassador takes no Cuban role, and his own entry's text, whose remarks need not hold it")
        #expect(stats.multiPersonRolesKeptOff == 1)
    }

    // MARK: - The assessment's reads

    /// One row of `identifier-assessment-reads.tsv`.
    private struct Read {
        let sample: String
        let peopleId: String
        let identifier: String
        let verdict: String
    }

    private static func reads() throws -> [Read] {
        let text = try String(contentsOf: repoRoot.appendingPathComponent(
            "PersonAuthorityIndexGenerator/identifier-assessment-reads.tsv"), encoding: .utf8)
        let lines = text.split(separator: "\n").filter { !$0.hasPrefix("#") }.dropFirst()
        return lines.map { line in
            let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            return Read(sample: f[0], peopleId: f[1], identifier: f[5], verdict: f[6])
        }
    }

    /// The 300 verdicts the assessment read on 2026-10-17 (rebuilt from that session's transcript, as the
    /// file's header says), held against the shipped file: a re-score of the rule on the links read by
    /// hand. The rule alone kept about 96% right over the three strata, weighted as the assessment
    /// weighted them (its (b4)), and none of the strata a test fails reaches the bundle. It also kept
    /// five reads that name someone else, and #1767's follow-up takes all five off by data: Truman's
    /// nephew (the President's item, on *President*; the file's `withheld`), Sir William Luce (a
    /// librettist's item, whose VIAF id the overlay took too), Gustav Dahrendorf (his son Ralf's, on
    /// *Germany*), Warren E. Thompson (both ids from one historian) and General MacArthur (his nephew's
    /// VIAF id, on *Japan*), each by a correction. So the weighted share is now 100%, which is no longer
    /// an estimate of the bundle: the corrections were chosen from these reads, and the links the reads
    /// never sampled (the assessment's about 75 wrong, less these) are as they were. A refreshed snapshot
    /// or a changed word list moves these; read the rows that move before bringing the expectations along.
    @Test("The rule, re-scored on the assessment's 300 reads")
    func reScoredOnTheReads() throws {
        let reads = try Self.reads()
        #expect(reads.count == 300)
        #expect(Set(reads.map(\.verdict)) == ["R", "W", "?"])
        let data = try Data(contentsOf: Self.repoRoot
            .appendingPathComponent("FRUSExplorer/Resources/person-authority-index.json"))
        let authority = try JSONDecoder().decode(PersonAuthorityIndex.self, from: data).authority
        func kept(_ read: Read) -> Bool {
            let entry = authority[read.peopleId]
            return (read.sample.hasPrefix("viaf") ? entry?.v : entry?.q) == read.identifier
        }
        let weights = ["wikidata-stratified:pass": 2461.0 / 100, "wikidata-stratified:soft": 502.0 / 50,
                       "wikidata-stratified:hard": 806.0 / 40]
        var right = 0.0, wrong = 0.0
        for read in reads where kept(read) {
            guard let weight = weights[read.sample] else { continue }
            if read.verdict == "R" { right += weight } else if read.verdict == "W" { wrong += weight }
        }
        #expect(right / (right + wrong) > 0.95, "the assessment's (b4): about 96% right")
        #expect(!reads.contains { kept($0) && ($0.sample.hasSuffix(":soft") || $0.sample.hasSuffix(":hard")) },
                "a link failing a test never reaches the bundle")
        let keptWrong = reads.filter { kept($0) && $0.verdict == "W" }.map { "\($0.peopleId) \($0.identifier)" }
        #expect(keptWrong.isEmpty, "the five the rule kept, taken off by #1767's follow-up: \(keptWrong)")
    }

    // MARK: - The shipped file

    /// The shipped file, read from the repository: regenerated with the rule (#1767) over the committed
    /// snapshot, it carries the identifiers the rule takes, and the multi-person role texts only where
    /// a record's remarks hold them.
    @Test("The bundled index takes the overlay's identifiers through the rule, and gives no record another's role")
    func bundledIndex() throws {
        let data = try Data(contentsOf: Self.repoRoot
            .appendingPathComponent("FRUSExplorer/Resources/person-authority-index.json"))
        let authority = try JSONDecoder().decode(PersonAuthorityIndex.self, from: data).authority
        #expect(authority["107025"]?.q == nil, "John F. Kennedy")
        #expect(authority["108893"]?.q == nil && authority["108893"]?.v == "48112119", "Kinnaird R. McKee")
        #expect(authority["101726"]?.q == nil && authority["101726"]?.v == nil, "Leonid Brezhnev")
        #expect(authority["102311"]?.q == "Q46809" && authority["102311"]?.v == "97724278", "Raúl Castro")
        #expect(authority["102312"]?.q == nil && authority["102312"]?.v == nil && authority["102312"]?.r == nil,
                "Raul H. Castro: none of Raúl Castro's ids, nor his role")
        #expect(authority["103878"]?.v == "56623995" && authority["103878"]?.q == nil && authority["103878"]?.r == nil,
                "the President of Italy: his VIAF id, and not his grandson's item or post")
        #expect(authority["103879"]?.q == "Q6700117" && authority["103879"]?.v == nil,
                "Luigi R. Einaudi: his own item, since the entry's VIAF id is his grandfather's (#1767's follow-up)")
        #expect(authority["108250"]?.q == "Q127417" && authority["108250"]?.v == nil,
                "General MacArthur: his own item, and not his nephew's VIAF id (#1767's follow-up)")
        #expect(authority["113770"]?.q == "Q11613" && authority["113770"]?.r == "President of the United States, 1945-53.")
        #expect(authority["116214"]?.q == nil && authority["116214"]?.r == nil,
                "Truman's nephew: neither the President's item, kept off him alone, nor his role")
        for id in ["103111", "105525", "108175", "113545"] {
            #expect(authority[id]?.q == nil, "\(id): a namesake's or a relative's item, withheld by correction")
        }
        for d in Self.duplicates {
            #expect(authority[d.lost]?.r == nil, "\(d.lost) loses its copy of the role")
            #expect(authority[d.kept]?.r == AuthorityEntry.truncatedRole(d.role, limit: 120), "\(d.kept) keeps it")
        }
    }
}
