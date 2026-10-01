// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - NamedFileSeriesRoutingTests

/// Where a file series cited by name alone is held (#354 item 1).
///
/// ## What the suite guards
/// **That the routing is reachable.** `Roosevelt Papers` is the entire source note. Between it
/// and a destination sit the parser's `.namedFileSeries` extraction and
/// `CuratedLotResolutions.normalizeSeriesName`, neither connected to this table by the type
/// system. So every reachability fixture is a **verbatim corpus note** driven through the real
/// parser — a synthetic `"Roosevelt Papers"` string would test neither link.
///
/// **That the refusals hold.** This matters more than the routings. #354 proposed
/// `Defense→330` and `Army→319`; the volumes' own Sources sections show both are wrong, and
/// 262 documents would have been sent to record groups that do not hold them. A test that only
/// checked what the table *does* answer would have passed with those entries present.
///
/// Version history:
///   1.0 — Session 2026-08-07: #354 item 1
///   1.1 — 2026-10-01: #1514, review round 1 — the panel's explainer, the Mac note and the State
///          records link, driven through the real parser and read in both views
@Suite("Named file series routing")
struct NamedFileSeriesRoutingTests {

    private let parser = SourceNoteParser()

    /// The routing a real source note reaches through the real parser, or `nil`.
    private func routing(_ note: String) -> NamedFileSeriesRouting.Entry? {
        guard case .namedFileSeries(let series, _) = parser.parse(note) else { return nil }
        return NamedFileSeriesRouting.routing(forSeriesName: series)
    }

    /// The series name the parser extracts, for failure messages.
    private func seriesName(_ note: String) -> String? {
        if case .namedFileSeries(let series, _) = parser.parse(note) { return series }
        return nil
    }

    private func destinationTitle(_ note: String) -> String? {
        routing(note).map(NamedFileSeriesRouting.title)
    }

    // MARK: - Reachability through the real parser

    /// One verbatim corpus note per table entry.
    @Test("Every routed series is reachable from a real corpus note")
    func corpusNotesReachRouting() {
        for (note, expected) in [
            ("Roosevelt Papers", "Franklin D. Roosevelt Presidential Library"),
            ("Hopkins Papers: Telegram", "Franklin D. Roosevelt Presidential Library"),
            // `Leahy Papers` and not the corpus's `Leahy Papers Telegram`: the latter parses
            // `.unrecognized`, because the trailing document type has no colon before it. The
            // colon form (`Hopkins Papers: Telegram`, above) reaches the series name fine.
            // A parser gap, not a routing one — recorded here so it is not rediscovered.
            ("Leahy Papers", "Library of Congress, Manuscript Division"),
            ("Hull Papers", "Library of Congress, Manuscript Division"),
            ("Stimson Papers", "Manuscripts and Archives, Yale University Library"),
            ("J.C.S. Files", "RG 218 — Records of the U.S. Joint Chiefs of Staff"),
            ("J. C. S. Files", "RG 218 — Records of the U.S. Joint Chiefs of Staff"),
            ("JCS Records", "RG 218 — Records of the U.S. Joint Chiefs of Staff"),
        ] {
            #expect(destinationTitle(note) == expected,
                    Comment(rawValue: """
                            got \(destinationTitle(note) ?? "nil") (series "\(seriesName(note) ?? "no named-series parse")") \
                            for: \(note)
                            """))
        }
    }

    /// The corpus writes the Joint Chiefs three ways across 503 documents. They fold through
    /// `CuratedLotResolutions.normalizeSeriesName` — the same normalizer the rest of Source
    /// Explorer applies to this field — except `JCS Records`, which is listed separately
    /// because the normalizer keeps the differing noun.
    @Test("All three Joint Chiefs spellings reach RG 218")
    func jointChiefsSpellingsFold() {
        for name in ["J.C.S. Files", "J. C. S. Files", "JCS Files", "JCS Records"] {
            let hit = NamedFileSeriesRouting.routing(forSeriesName: name)
            #expect(hit?.destination == .recordGroup(
                number: "218", naId: "545",
                title: "Records of the U.S. Joint Chiefs of Staff"),
                    Comment(rawValue: "\(name) did not reach RG 218"))
        }
    }

    /// The Foreign Service post pattern, on the corpus's own names. 33 of these across 149
    /// documents, from `Moscow Embassy Files` at 36 down to `Wellington Legation Files` at 1 —
    /// a pattern rather than a table because the name states the post and the tail is open.
    @Test("Foreign Service post names reach RG 84")
    func foreignServicePostsReachRG84() {
        for name in [
            "Moscow Embassy Files", "Tokyo Post Files", "Vienna Legation Files",
            "London Embassy Files", "Algiers Consulate Files", "Wellington Legation Files",
            "Paris Embassy files", "Tokyo Post files",           // the corpus's lower-case variants
            "National Archives, RG 84, London Embassy Files",     // already names its own RG
        ] {
            #expect(NamedFileSeriesRouting.routing(forSeriesName: name)?.destination
                    == .recordGroup(number: "84", naId: "413",
                                    title: "Records of the Foreign Service Posts of the Department of State"),
                    Comment(rawValue: "\(name) did not reach RG 84"))
        }
    }

    // MARK: - The refusals

    /// `Mission` is not one of the pattern's nouns, and this is why.
    ///
    /// The Marshall Mission to China was not a diplomatic post, so its files are not Foreign
    /// Service post records. Adding one plausible-looking word to the pattern would send two
    /// documents to a record group that does not hold them.
    @Test("A mission is not a Foreign Service post")
    func missionFilesAreNotRoutedToRG84() {
        #expect(NamedFileSeriesRouting.routing(forSeriesName: "Marshall Mission Files") == nil,
                "Marshall Mission Files was routed to the Foreign Service posts")
    }

    /// The two mappings #354 proposed that its own corpus disproves.
    ///
    /// - `Defense Files` — `frus1941-43` defines it as "the files of the Secretaries of War and
    ///   Navy and other relevant top-level files of the military departments for 1941–1943".
    ///   The Department of Defense did not exist until 1947.
    /// - `Department of Defense Files` — `frus1949v03` defines it as the exchanges between the
    ///   U.S. Military Governor for Germany and the **Department of the Army**.
    /// - `Department of the Army Files` — `frus1943` defines it as "files for 1943 of the **War
    ///   Department**, now under the jurisdiction of the Department of the Army". Custody in
    ///   1943 is not provenance.
    ///
    /// 262 documents. No answer is the right answer for all three.
    @Test("The record groups #354 proposed for Defense and Army are refused")
    func proposedDefenceAndArmyMappingsAreRefused() {
        for name in ["Defense Files", "Department of Defense Files",
                     "Department of the Army Files"] {
            #expect(NamedFileSeriesRouting.routing(forSeriesName: name) == nil,
                    Comment(rawValue: """
                            \(name) was routed to a record group. The volumes define this series \
                            differently in different years; a single record group is wrong for it.
                            """))
        }
    }

    /// A name this table has never seen gets no answer, and an empty one is not a lookup.
    @Test("Unlisted and empty series names get no routing")
    func unlistedNamesGetNothing() {
        for name in ["IO Files", "Executive Secretariat Files", "Pauley Files",
                     "Bohlen Collection", "", "   "] {
            #expect(NamedFileSeriesRouting.routing(forSeriesName: name) == nil,
                    Comment(rawValue: "\(name) was routed, and this table has no evidence for it"))
        }
    }

    // MARK: - The table's own contract

    /// Hand-verified against the live NARA Catalog on 2026-08-07; RG 84 and RG 353 additionally
    /// agree with the committed bulk-export harvest manifest, built from a different source.
    /// Pinned as literals because a wrong digit is a working link to the wrong records.
    @Test("The record-group identifiers are the verified ones")
    func recordGroupIdentifiersAreVerified() {
        let byNumber = Dictionary(
            uniqueKeysWithValues: (NamedFileSeriesRouting.entries + [NamedFileSeriesRouting.foreignServicePosts])
                .compactMap { entry -> (String, (String, String))? in
                    guard case .recordGroup(let number, let naId, let title) = entry.destination
                    else { return nil }
                    return (number, (naId, title))
                })
        #expect(byNumber["218"]?.0 == "545")
        #expect(byNumber["218"]?.1 == "Records of the U.S. Joint Chiefs of Staff")
        #expect(byNumber["353"]?.0 == "661")
        #expect(byNumber["84"]?.0 == "413")
        #expect(byNumber["84"]?.1 == "Records of the Foreign Service Posts of the Department of State")
    }

    /// Every destination links somewhere, and record-group links are canonical catalog records.
    @Test("Every destination builds a usable link")
    func destinationsLink() throws {
        for entry in NamedFileSeriesRouting.entries + [NamedFileSeriesRouting.foreignServicePosts] {
            let url = try #require(NamedFileSeriesRouting.url(entry),
                                   Comment(rawValue: "\(NamedFileSeriesRouting.title(entry)) has no link"))
            #expect(url.scheme == "https",
                    Comment(rawValue: "\(NamedFileSeriesRouting.title(entry)): \(url.absoluteString)"))
            if case .recordGroup(_, let naId, _) = entry.destination {
                #expect(url.absoluteString == "https://catalog.archives.gov/id/\(naId)")
            }
        }
    }

    /// The evidence line is the feature, not decoration — it is what lets a researcher judge
    /// the destination instead of trusting it. An entry without one is a bare assertion.
    @Test("Every entry carries its evidence")
    func everyEntryCarriesEvidence() {
        for entry in NamedFileSeriesRouting.entries + [NamedFileSeriesRouting.foreignServicePosts] {
            #expect(entry.evidence.count > 40,
                    Comment(rawValue: "\(NamedFileSeriesRouting.title(entry)) has no usable evidence line"))
        }
    }

    /// Every entry is reachable from each of its own declared spellings, and no two entries
    /// claim the same key.
    @Test("Every spelling reaches its own entry, and only its own")
    func spellingsAreReachableAndUnambiguous() {
        var seen: [String: String] = [:]
        for entry in NamedFileSeriesRouting.entries {
            for spelling in entry.spellings {
                let key = CuratedLotResolutions.normalizeSeriesName(spelling)
                #expect(!key.isEmpty, Comment(rawValue: "\"\(spelling)\" normalises to nothing"))
                let previous = seen[key]
                #expect(previous == nil || previous == NamedFileSeriesRouting.title(entry),
                        Comment(rawValue: "key \"\(key)\" claimed by \(previous ?? "") and \(NamedFileSeriesRouting.title(entry))"))
                seen[key] = NamedFileSeriesRouting.title(entry)
                #expect(NamedFileSeriesRouting.routing(forSeriesName: spelling).map(NamedFileSeriesRouting.title)
                        == NamedFileSeriesRouting.title(entry),
                        Comment(rawValue: "\(NamedFileSeriesRouting.title(entry)) unreachable from \"\(spelling)\""))
            }
        }
    }

    // MARK: - The panel's explainer and link (#1514, review round 1)

    /// A series whose stored name opens with the agency holding it is told so, on both platforms,
    /// and is not offered NARA's Department of State records page; one naming no holder is told the
    /// repository is unstated, and is. Each note is a verbatim corpus note driven through the real
    /// parser — frus1969-76v21/d43 (the Department's INR/IL series since #1514), frus1977-80v11p1/d54
    /// (a National Security Council series, #353), and frus1945v01/d138 (`IO Files`, no holder).
    @Test("The explainer names the holder, and only a holder-less series gets the State records link",
          arguments: [
        ("Source: Department of State, Bureau of Intelligence and Research, INR/IL Historical Files, Chile Chronology 1970. Secret; Immediate; Roger Channel. A stamped notation on the first page reads: “Special Handling.”",
         "Department of State"),
        ("Source: National Security Council, Carter Intelligence Files, Box I020, SCC Meetings, Minutes— SCC 1979. Top Secret. The meeting took place in the White House Situation Room.",
         "National Security Council"),
        ("IO Files: US Cr Min 6", nil),
    ] as [(String, String?)])
    func explainerNamesTheHolder(_ note: String, _ holder: String?) {
        guard case .namedFileSeries(let series, _) = parser.parse(note) else {
            Issue.record("parsed as \(parser.parse(note)), not a named series")
            return
        }
        let explainer = NamedFileSeriesRouting.explainer(seriesName: series)
        let macNote = NamedFileSeriesRouting.macNote(seriesName: series)
        if let holder {
            #expect(explainer == "A file series the citation places with the \(holder), cited without a lot number.")
            #expect(macNote == "A file series the citation places with the \(holder), cited without a lot number, so no automated NARA Catalog query is available.")
            #expect(!NamedFileSeriesRouting.offersStateRecordsLink(seriesName: series),
                    "\(series) is offered NARA's State records page, though its citation places it with the \(holder)")
        } else {
            #expect(explainer == "A named file series cited without a lot number. The repository is not stated in the citation.")
            #expect(macNote == "A named file series cited without a lot number. The citation does not state the holding repository, so no automated NARA Catalog query is available.")
            #expect(NamedFileSeriesRouting.offersStateRecordsLink(seriesName: series))
        }
    }

    // MARK: - Wiring

    private static let views = [
        "FRUSExplorer/SourceExplorer/SourceExplorerView.swift",
        "FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift",
    ]

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        #expect(text.count > 1_000, Comment(rawValue: "\(path) is implausibly small — did it move?"))
        return text
    }

    /// Both views must reach the table.
    ///
    /// A source audit, with the limits that implies: it detects the call being removed or
    /// renamed — the realistic regression, and one every test above stays green through — and
    /// it does not detect the surrounding condition being changed to something wrong.
    @Test("Both views reach the named-series routing")
    func bothViewsReachTheRouting() throws {
        for path in Self.views {
            let text = try Self.source(path)
            #expect(text.contains("NamedFileSeriesRouting.routing(forSeriesName:"),
                    Comment(rawValue: """
                            \(path) never looks up the named-series routing — a series cited by \
                            name alone is told only that its repository is unstated.
                            """))
            #expect(text.contains("routing.evidence"),
                    Comment(rawValue: """
                            \(path) renders the destination without its evidence, which turns \
                            the editors' own statement into an unsourced assertion.
                            """))
        }
    }

    /// Both views say what the shared functions say (#1514, review round 1): the iOS panel's
    /// explainer and the Mac box's note come from `NamedFileSeriesRouting`, neither view keeps the
    /// old "repository is not stated" sentence as a literal of its own, and each gates NARA's
    /// State records link on `offersStateRecordsLink`. A source audit with the limits the test
    /// above states: it sees a call removed or a literal restored, not a condition changed.
    @Test("Both views read the named-series explainer and gate the State records link")
    func bothViewsReadTheExplainerAndGateTheLink() throws {
        let calls = [
            "FRUSExplorer/SourceExplorer/SourceExplorerView.swift":
                ["NamedFileSeriesRouting.explainer(seriesName: seriesName)",
                 "NamedFileSeriesRouting.offersStateRecordsLink(seriesName: seriesName)"],
            "FRUSExplorer/SourceExplorer/MacSourceExplorerView.swift":
                ["NamedFileSeriesRouting.macNote(seriesName: series)",
                 "NamedFileSeriesRouting.offersStateRecordsLink(seriesName: series)"],
        ]
        for path in Self.views {
            let text = try Self.source(path)
            for call in calls[path] ?? [] {
                #expect(text.contains(call), Comment(rawValue: "\(path) never calls \(call)"))
            }
            for literal in ["The repository is not stated in the citation",
                            "The citation does not state the holding repository"] {
                #expect(!text.contains(literal),
                        Comment(rawValue: "\(path) keeps its own \"\(literal)\" instead of the shared explainer"))
            }
            #expect(text.components(separatedBy: "NARACatalogClient.stateDepartmentRecordsURL").count == 2,
                    Comment(rawValue: "\(path) opens the State records page from more than the one gated place"))
        }
    }
}
