// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

// MARK: - QueryMethodAppendixFixtureTests

/// A fixture trail's method appendix, held to the byte in each of its three formats (S17b).
///
/// The appendix is rendered for a host that fixes the locale (`en_US`), the calendar (Gregorian) and
/// the time zone (UTC), with the app's version passed in and no data files. With those fixed it is the
/// same file on every platform the kit compiles for, which is what lets FRUS Explorer Light write a
/// researcher's appendix as the app does: this suite runs in Xcode on iOS, in `swift test` on macOS and
/// in the web edition's Linux CI, against the one set of literals below.
///
/// The trail holds one row of each kind the appendix reads differently: an exact count, a floor inside
/// a working corpus of 1,200 documents (whose counts must be grouped as Foundation groups `%lld`), a
/// keyword zero, two Meaning rows (one a zero, which is no term's absence, one ranked inside a held
/// keyword list), a count complete without a total, and a row written before M-2 with no time, which
/// sorts last. Its one searched corpus was captured short of its matches, and research logging is off.
///
/// Version history:
///   1.0 — Session 2026-10-25 (FRUS Explorer Light, S17b): initial implementation, with the appendix's
///          move into the kit
@Suite("The method appendix of a fixture trail, the same file on every platform")
struct QueryMethodAppendixFixtureTests {

    // MARK: - The trail

    static let projectOne = UUID(uuidString: "00000000-0000-0000-0000-00000000F001")!
    static let projectTwo = UUID(uuidString: "00000000-0000-0000-0000-00000000F002")!
    static let grainCorpus = UUID(uuidString: "00000000-0000-0000-0000-00000000C001")!
    static let otherCorpus = UUID(uuidString: "00000000-0000-0000-0000-00000000C002")!

    /// The corpus's 1,200 documents, in the order they were captured.
    static let corpusKeys = (1...1_200).map { "frus1948v04/d\($0)" }

    static func row(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012lld", Int64(number)))!
    }

    static func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    /// The host every rendering here uses: an app version, no data files, and a fixed locale,
    /// calendar and time zone.
    static let host = QueryMethodAppendix.Host(
        appVersion: "1.0", resources: .none, locale: Locale(identifier: "en_US"),
        calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(identifier: "UTC")!)

    /// The trail, in an order that is not the appendix's: the kit sorts it oldest first.
    static func searches() -> [RecordedSearch] {
        [
            RecordedSearch(
                id: row(5), queryText: "Kennan", resultCount: 41),
            RecordedSearch(
                id: row(3), queryText: "\"offset agreement\"", resultCount: 0, projectId: projectOne,
                executedAt: date("2026-10-22T11:05:00Z"), loadedCount: 0, matchCount: 0, fetchLimit: 7_500,
                indexedVolumeCount: 553,
                scopeSignature: SearchScopeSignature.signature(for: SearchParameters(
                    phrase: "offset agreement", yearKeys: ["1953", "1951"], userTagIds: ["t1", "t2"],
                    volumeIds: ["frus1952-54v05p2", "frus1952-54v05p1"], projectId: projectOne,
                    documentTypeFilter: .documentsOnly, personRef: "p_ACH_1"))),
            RecordedSearch(
                id: row(1), queryText: "Berlin airlift", resultCount: 212, projectId: projectOne,
                executedAt: date("2026-10-20T09:15:00Z"), loadedCount: 212, matchCount: 212, fetchLimit: 7_500,
                indexedVolumeCount: 553,
                scopeSignature: SearchScopeSignature.signature(for: SearchParameters(
                    keywords: "Berlin airlift", dateRange: DateRange(earliest: "1948-06-01", latest: "1949-05-31"))),
                renderedExpression: "\"berlin\" AND \"airlift\""),
            RecordedSearch(
                id: row(7), queryText: "a question nobody asked", resultCount: 0, projectId: projectOne,
                executedAt: date("2026-10-23T08:30:00Z"), loadedCount: 0, matchCount: 0, fetchLimit: 100,
                indexedVolumeCount: 553, scopeSignature: SearchScopeSignature.semanticRouteSignature),
            RecordedSearch(
                id: row(2), queryText: "wheat | embargo", resultCount: 7_500, projectId: projectOne,
                executedAt: date("2026-10-21T16:40:00Z"), loadedCount: 7_500, matchCount: nil, fetchLimit: 7_500,
                indexedVolumeCount: 553,
                scopeSignature: SearchScopeSignature.signature(for: SearchParameters(
                    keywords: "wheat | embargo", booleanMode: .or, documentIds: corpusKeys,
                    includeSummaries: false, includeNotes: false, includeFrontMatter: false)),
                appliedCorpusId: grainCorpus),
            RecordedSearch(
                id: row(6), queryText: "Bevin", resultCount: 37, projectId: projectTwo,
                executedAt: date("2026-10-24T13:20:00Z"), loadedCount: 37, matchCount: nil, fetchLimit: 1_000,
                indexedVolumeCount: 12,
                scopeSignature: SearchScopeSignature.signature(for: SearchParameters(
                    keywords: "Bevin", excludedTerms: ["Attlee"], prefixWildcard: "negoti",
                    includeSummaries: false, includeNotes: false)),
                renderedExpression: "\"bevin\" negoti* NOT \"attlee\""),
            RecordedSearch(
                id: row(4), queryText: "how did the embassy respond to the embargo", resultCount: 100,
                projectId: projectOne, executedAt: date("2026-10-23T08:00:00Z"), loadedCount: 100, matchCount: nil,
                fetchLimit: 100, indexedVolumeCount: 553,
                scopeSignature: SearchScopeSignature.layered(
                    SearchScopeSignature.semanticRouteSignature, parameters: SearchParameters(),
                    basePart: "base=keywords:212:%22wheat%20shipments%22")),
        ]
    }

    /// The searched corpus's coverage, gathered and partitioned by the kit's rules: 43 opened, 12
    /// annotated and 5 collected of its 1,200, 45 in all, with logging off; and a corpus no row
    /// searched, which the appendix must leave out.
    static func coverage() -> [QueryMethodAppendix.CorpusCoverage] {
        let keys = DocumentEngagementService.GatheredKeys(
            opened: Set(corpusKeys[0..<43]), annotated: Set(corpusKeys[29..<41]),
            collected: Set(corpusKeys[40..<45]))
        return [
            QueryMethodAppendix.CorpusCoverage(
                corpusId: otherCorpus, corpusName: "Unsearched corpus",
                coverage: DocumentEngagementService.partition(corpusKeys: ["v1/d1"], keys: keys,
                                                              isOpenedComplete: false)),
            QueryMethodAppendix.CorpusCoverage(
                corpusId: grainCorpus, corpusName: "Grain diplomacy",
                coverage: DocumentEngagementService.partition(corpusKeys: corpusKeys, keys: keys,
                                                              isOpenedComplete: false),
                truncation: CorpusCaptureTruncation(wasTruncated: true, totalMatchCount: 40_000)),
        ]
    }

    static func appendix() -> QueryMethodAppendix {
        QueryMethodAppendix.make(
            recordedSearches: searches(),
            corpusNames: [grainCorpus: "Grain diplomacy", otherCorpus: "Unsearched corpus"],
            projectName: "Grain and the Cold War",
            researchQuestion: "How did grain shipments shape alliance politics, 1948–1955?",
            generatedAt: date("2026-10-25T14:30:00Z"),
            corpusCoverage: coverage())
    }

    // MARK: - The files

    /// `frus-query-log.md`, as the app's Settings ▸ Data & Recovery writes it.
    static let markdown = #"""
        # Query log — method appendix

        **Project:** Grain and the Cold War
        **Research question:** How did grain shipments shape alliance politics, 1948–1955?
        **Generated:** FRUS Explorer 1.0, October 25, 2026 at 2:30\#u{202F}PM
        **Searches:** 7

        | Executed | Query | Results | Volumes indexed | Scope |
        | --- | --- | ---: | ---: | --- |
        | 10/20/2026, 9:15\#u{202F}AM | Berlin airlift | 212 | 553 | searched document text, summaries, notes, and front matter; dated 1948-06-01..1949-05-31 |
        | 10/21/2026, 4:40\#u{202F}PM | wheat \| embargo | at least 7,500 | 553 | inside “Grain diplomacy”; searched document text; any term matches; 1,200 documents |
        | 10/22/2026, 11:05\#u{202F}AM | "offset agreement" | 0 | 553 | searched document text, summaries, notes, and front matter; years 1951, 1953; 2 volumes; 2 of your tags; documents only; filtered to one person, by a single volume’s spelling; phrase search; gated to a project |
        | 10/23/2026, 8:00\#u{202F}AM | how did the embassy respond to the embargo | 100 | 553 | ranked by meaning (on-device model), not by keywords — the query’s words were not required to appear; inside the results of a keyword search for “wheat shipments” (212 documents) |
        | 10/23/2026, 8:30\#u{202F}AM | a question nobody asked | 0 | 553 | ranked by meaning (on-device model), not by keywords — the query’s words were not required to appear |
        | 10/24/2026, 1:20\#u{202F}PM | Bevin | 37 | 12 | searched document text and front matter; prefix wildcard; with excluded terms |
        | — | Kennan | 41 (as reported) | — | not recorded |

        ## How much of each searched corpus was examined
        - Coverage counts what this project has done with the documents each corpus holds — opened, annotated, or placed in a collection. It is not what the searches returned.
        - Grain diplomacy: 45 of 1,200 documents worked on · 43 opened · 12 annotated · 5 collected · 1,155 untouched
        - Grain diplomacy: Saved 1,200 of 40,000 matches
        - Opened is a floor, not a total — research logging is off.

        ## How to read this table
        - Each count is what the search returned when it ran, over the volumes downloaded to that device at that moment. It is not re-run, and it will not match a search run today against a larger index.
        - One of these searches returned nothing. A zero is a finding: it means the term is absent from the volumes indexed at the time, not that it is absent from the FRUS series.
        - 2 searches ran by meaning (on-device model) rather than by keywords. Their counts are sizes of ranked lists, not match totals, and zeros there do not mean any term is absent.
        - One search hit the app’s row ceiling. Its count is shown as “at least N” and is a floor, not a total — do not sum it with the others.
        - One search predates this app version. It saved only a result count — not the scope, the row ceiling, or how many volumes were indexed. It is marked “as reported” and cannot be checked against the others.

        ## Where this came from
        - Read from the text and editorial apparatus of the FRUS volumes, and from no other source. Where a value was parsed out of printed prose, this app did the reading.
        - Computed by this app rather than read from a source — a model or a scoring rule stands between the volumes and this figure. Cite it as the app's output, not the record's.

        Text from Foreign Relations of the United States, Office of the Historian, U.S. Department of State (public domain).

        """#

    /// `frus-query-log.csv`, with `count_basis`, as the app's Settings ▸ Data & Recovery writes it.
    static let csv = #"""
        # Query log — method appendix
        #
        # Project: Grain and the Cold War
        # Research question: How did grain shipments shape alliance politics, 1948–1955?
        # Generated: FRUS Explorer 1.0, October 25, 2026 at 2:30\#u{202F}PM
        # Searches: 7
        #
        # How much of each searched corpus was examined
        # Coverage counts what this project has done with the documents each corpus holds — opened, annotated, or placed in a collection. It is not what the searches returned.
        # Grain diplomacy: 45 of 1,200 documents worked on · 43 opened · 12 annotated · 5 collected · 1,155 untouched
        # Grain diplomacy: Saved 1,200 of 40,000 matches
        # Opened is a floor, not a total — research logging is off.
        #
        # How to read this table
        # Each count is what the search returned when it ran, over the volumes downloaded to that device at that moment. It is not re-run, and it will not match a search run today against a larger index.
        # One of these searches returned nothing. A zero is a finding: it means the term is absent from the volumes indexed at the time, not that it is absent from the FRUS series.
        # 2 searches ran by meaning (on-device model) rather than by keywords. Their counts are sizes of ranked lists, not match totals, and zeros there do not mean any term is absent.
        # One search hit the app’s row ceiling. Its count is shown as “at least N” and is a floor, not a total — do not sum it with the others.
        # One search predates this app version. It saved only a result count — not the scope, the row ceiling, or how many volumes were indexed. It is marked “as reported” and cannot be checked against the others.
        #
        # Where this came from
        # Read from the text and editorial apparatus of the FRUS volumes, and from no other source. Where a value was parsed out of printed prose, this app did the reading.
        # Computed by this app rather than read from a source — a model or a scoring rule stands between the volumes and this figure. Cite it as the app's output, not the record's.
        #
        # Text from Foreign Relations of the United States, Office of the Historian, U.S. Department of State (public domain).
        executed_at,query,count_basis,match_count,loaded_count,fetch_limit,reported_count,indexed_volume_count,working_corpus,project_id,scope_signature,rendered_expression
        2026-10-20T09:15:00Z,"Berlin airlift",exact,212,212,,,553,"",00000000-0000-0000-0000-00000000F001,"mode=and;dates=1948-06-01..1949-05-31;years=any;vols=none;docs=none;exdocs=none;subj=any;stags=empty;utags=empty;type=all;person=none;phrase=0;prefix=0;excl=0;text=1;summ=1;notes=1;front=1;proj=none","""berlin"" AND ""airlift"""
        2026-10-21T16:40:00Z,"wheat | embargo",floor,,7500,7500,,553,"Grain diplomacy",00000000-0000-0000-0000-00000000F001,"mode=or;dates=none;years=any;vols=none;docs=1200/fa817d16ee49;exdocs=none;subj=any;stags=empty;utags=empty;type=all;person=none;phrase=0;prefix=0;excl=0;text=1;summ=0;notes=0;front=0;proj=none",""
        2026-10-22T11:05:00Z,"""offset agreement""",exact,0,0,,,553,"",00000000-0000-0000-0000-00000000F001,"mode=and;dates=none;years=1951,1953;vols=2/3b84192e2ca1;docs=none;exdocs=none;subj=any;stags=empty;utags=2/56b91a1c7d24;type=documents;person=ref:c3d6e9883529;phrase=1;prefix=0;excl=0;text=1;summ=1;notes=1;front=1;proj=00000000-0000-0000-0000-00000000F001",""
        2026-10-23T08:00:00Z,"how did the embassy respond to the embargo",exact,100,100,,,553,"",00000000-0000-0000-0000-00000000F001,"route=semantic;engine=on-device;base=keywords:212:%22wheat%20shipments%22",""
        2026-10-23T08:30:00Z,"a question nobody asked",exact,0,0,,,553,"",00000000-0000-0000-0000-00000000F001,"route=semantic;engine=on-device",""
        2026-10-24T13:20:00Z,"Bevin",complete,37,37,,,12,"",00000000-0000-0000-0000-00000000F002,"mode=and;dates=none;years=any;vols=none;docs=none;exdocs=none;subj=any;stags=empty;utags=empty;type=all;person=none;phrase=0;prefix=1;excl=1;text=1;summ=0;notes=0;front=1;proj=none","""bevin"" negoti* NOT ""attlee"""
        ,"Kennan",unrecorded,,,,41,,"",,"",""

        """#

    /// The lines a collection's PDF, HTML and Word exports print.
    static let plainTextLines = [
        "Query log — method appendix",
        "— Each count is what the search returned when it ran, over the volumes downloaded to that device at that moment. It is not re-run, and it will not match a search run today against a larger index.",
        "— One of these searches returned nothing. A zero is a finding: it means the term is absent from the volumes indexed at the time, not that it is absent from the FRUS series.",
        "— 2 searches ran by meaning (on-device model) rather than by keywords. Their counts are sizes of ranked lists, not match totals, and zeros there do not mean any term is absent.",
        "— One search hit the app’s row ceiling. Its count is shown as “at least N” and is a floor, not a total — do not sum it with the others.",
        "— One search predates this app version. It saved only a result count — not the scope, the row ceiling, or how many volumes were indexed. It is marked “as reported” and cannot be checked against the others.",
        "",
        "How much of each searched corpus was examined",
        "Coverage counts what this project has done with the documents each corpus holds — opened, annotated, or placed in a collection. It is not what the searches returned.",
        "Grain diplomacy: 45 of 1,200 documents worked on · 43 opened · 12 annotated · 5 collected · 1,155 untouched",
        "Grain diplomacy: Saved 1,200 of 40,000 matches",
        "Opened is a floor, not a total — research logging is off.",
        "",
        "Where this came from",
        "Read from the text and editorial apparatus of the FRUS volumes, and from no other source. Where a value was parsed out of printed prose, this app did the reading.",
        "Computed by this app rather than read from a source — a model or a scoring rule stands between the volumes and this figure. Cite it as the app's output, not the record's.",
        "",
        "10/20/2026, 9:15\u{202F}AM · “Berlin airlift” · 212 results · 553 volumes indexed · searched document text, summaries, notes, and front matter; dated 1948-06-01..1949-05-31",
        "10/21/2026, 4:40\u{202F}PM · “wheat | embargo” · at least 7,500 results · 553 volumes indexed · inside “Grain diplomacy”; searched document text; any term matches; 1,200 documents",
        "10/22/2026, 11:05\u{202F}AM · “\"offset agreement\"” · 0 results · 553 volumes indexed · searched document text, summaries, notes, and front matter; years 1951, 1953; 2 volumes; 2 of your tags; documents only; filtered to one person, by a single volume’s spelling; phrase search; gated to a project",
        "10/23/2026, 8:00\u{202F}AM · “how did the embassy respond to the embargo” · 100 results · 553 volumes indexed · ranked by meaning (on-device model), not by keywords — the query’s words were not required to appear; inside the results of a keyword search for “wheat shipments” (212 documents)",
        "10/23/2026, 8:30\u{202F}AM · “a question nobody asked” · 0 results · 553 volumes indexed · ranked by meaning (on-device model), not by keywords — the query’s words were not required to appear",
        "10/24/2026, 1:20\u{202F}PM · “Bevin” · 37 results · 12 volumes indexed · searched document text and front matter; prefix wildcard; with excluded terms",
        "— · “Kennan” · 41 (as reported) results · not recorded",
    ]

    // MARK: - Tests

    /// The first line on which two texts differ, for a failure message that shows it.
    static func firstDifference(_ actual: String, _ expected: String) -> String {
        let a = actual.components(separatedBy: "\n"), e = expected.components(separatedBy: "\n")
        for index in 0..<max(a.count, e.count) {
            let left = index < a.count ? a[index] : "<none>"
            let right = index < e.count ? e[index] : "<none>"
            if left != right {
                return "line \(index + 1)\n  actual:   \(left.debugDescription)\n  expected: \(right.debugDescription)"
            }
        }
        return "none"
    }

    @Test("The Markdown is the fixture's, byte for byte")
    func markdownIsTheFixtures() {
        let markdown = Self.appendix().markdown(for: Self.host)
        #expect(markdown == Self.markdown, "first difference: \(Self.firstDifference(markdown, Self.markdown))")
    }

    @Test("The CSV, with count_basis, is the fixture's, byte for byte")
    func csvIsTheFixtures() {
        let csv = Self.appendix().csv(for: Self.host)
        #expect(csv == Self.csv, "first difference: \(Self.firstDifference(csv, Self.csv))")
    }

    @Test("The plain-text lines a collection export prints are the fixture's")
    func plainTextLinesAreTheFixtures() {
        let lines = Self.appendix().plainTextLines(for: Self.host)
        #expect(lines == Self.plainTextLines, """
            first difference: \(Self.firstDifference(lines.joined(separator: "\n"),
                                                     Self.plainTextLines.joined(separator: "\n")))
            """)
    }

    @Test("The trail is read as the appendix states it: oldest first, undated last, each count by its kind")
    func theTrailIsReadByItsRules() {
        let appendix = Self.appendix()
        #expect(appendix.rows.map(\.queryText) == [
            "Berlin airlift", "wheat | embargo", "\"offset agreement\"", "how did the embassy respond to the embargo",
            "a question nobody asked", "Bevin", "Kennan",
        ])
        #expect(appendix.rows.map(\.count.basisToken)
                == ["exact", "floor", "exact", "exact", "exact", "complete", "unrecorded"])
        #expect(appendix.floorRowCount == 1 && appendix.unrecordedRowCount == 1)
        #expect(appendix.zeroResultRowCount == 2 && appendix.keywordZeroResultRowCount == 1)
        #expect(appendix.semanticRowCount == 2)
        #expect(appendix.applicableCoverage.map(\.corpusName) == ["Grain diplomacy"])
        #expect(appendix.corpusCoverage.map(\.corpusName) == ["Grain diplomacy", "Unsearched corpus"])
    }

    @Test("Scoped to a project, the appendix keeps that project's rows and the corpora they searched")
    func scopedToAProject() {
        let scoped = Self.appendix().scoped(toProject: Self.projectTwo)
        #expect(scoped.rows.map(\.queryText) == ["Bevin"])
        #expect(scoped.corpusCoverage.isEmpty && scoped.coverageLines(locale: Locale(identifier: "en_US")).isEmpty)
        #expect(Self.appendix().scoped(toProject: nil).rows.isEmpty)
    }

    @Test("A host's locale and time zone are the ones its dates and numbers are written in")
    func aHostsLocaleIsTheFiles() {
        let german = QueryMethodAppendix.Host(
            appVersion: nil, locale: Locale(identifier: "de_DE"), calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(identifier: "Europe/Berlin")!)
        let markdown = Self.appendix().markdown(for: german)
        #expect(markdown.contains("**Generated:** FRUS Explorer, "), "no version, the name alone")
        #expect(markdown.contains("| at least 7.500 | 553 |"), "a German grouping")
        #expect(markdown.contains("Saved 1.200 of 40.000 matches"), "Foundation's %lld, grouped in German")
        #expect(markdown.contains("11:15") && !markdown.contains("9:15"), "the time in Berlin")
    }
}
