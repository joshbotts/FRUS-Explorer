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

// MARK: - SeriesFactsIndexTests

/// The bundled naId → creating body projection, as the app reads it (#405).
///
/// Version history:
///   1.0 — Session 2026-08-10: #405 (F-6)
@Suite("Series creator index (#405)")
struct SeriesFactsIndexTests {

    /// Builds an index from JSON, the way the app loads it — so a fixture cannot drift from the
    /// wire shape the generator writes.
    private func index(headings: [String], rows: String,
                       statuses: [String] = [], restrictions: [String] = [],
                       useRestrictions: [String] = [], referenceUnits: [String] = [],
                       findingAidTypes: [String] = []) -> SeriesFactsIndex {
        func arr(_ xs: [String]) -> String {
            "[" + xs.map { "\"\($0)\"" }.joined(separator: ",") + "]"
        }
        let json = """
        {"schemaVersion":2,"generated":"2026-08-10","headings":\(arr(headings)),
         "byNaId":\(rows),"statuses":\(arr(statuses)),"restrictions":\(arr(restrictions)),
         "useRestrictions":\(arr(useRestrictions)),"referenceUnits":\(arr(referenceUnits)),
         "findingAidTypes":\(arr(findingAidTypes))}
        """
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(SeriesFactsIndex.self, from: Data(json.utf8))
    }

    @Test("A covered series names its creator")
    func resolvesACreator() {
        let i = index(headings: ["Department of State. Bureau of Far Eastern Affairs.",
                                 "Department of State. Office of the Secretary."],
                      rows: #"{"12345":{"c":1}}"#)
        #expect(i.creator(forNaId: "12345") == "Department of State. Office of the Secretary.")
    }

    @Test("An uncovered NAID is 'not stated', not an error")
    func uncoveredIsNil() {
        // Coverage is a fraction by construction: NARA carries `creators` only on the series
        // layer, so every file unit — every numerical-file roll — resolves to nothing here. A
        // caller must never read nil as "this series had no creator".
        let i = index(headings: ["A."], rows: #"{"1":{"c":0}}"#)
        #expect(i.creator(forNaId: "999") == nil)
        #expect(i.predecessors(forNaId: "999").isEmpty)
    }

    @Test("An out-of-range index yields nil rather than trapping")
    func corruptIndexDoesNotTrap() {
        // The artifact is generated, but it is also hand-editable and ships in the bundle. An
        // index past the end must degrade, not crash a research session.
        let i = index(headings: ["A."], rows: #"{"1":{"c":7,"p":[9]}}"#)
        #expect(i.creator(forNaId: "1") == nil)
        #expect(i.predecessors(forNaId: "1").isEmpty)
    }

    @Test("Predecessors are carried but are not the creator")
    func predecessorsAreSeparate() {
        let i = index(headings: ["Now.", "Before."], rows: #"{"1":{"c":0,"p":[1]}}"#)
        #expect(i.creator(forNaId: "1") == "Now.")
        #expect(i.predecessors(forNaId: "1") == ["Before."])
    }

    @Test("The shipped artifact decodes and covers the measured population")
    func shippedArtifactDecodes() throws {
        let index = try #require(SeriesFactsIndexStore.shared, """
            series-facts-index.json failed to load from the app bundle. If this is a fresh \
            resource, it needs `xcodegen generate` + the scheme restore to be enrolled.
            """)
        #expect(index.schemaVersion == 3, "schema 3 adds the #1202 coverage pair and legend")
        #expect(index.byNaId.count >= 600, "series with a creator: \(index.byNaId.count)")
        #expect(index.headings.count >= 340)
        // The largest single creator among app-held series, measured 2026-08-10 on 57 of them.
        #expect(index.headings.contains("Department of State. Office of the Secretary. Executive Secretariat."))
        // No heading may still carry NARA's lifespan tail — that is the display contract.
        #expect(!index.headings.contains { $0.hasSuffix(")") && $0.contains("19") },
                "a heading kept its date tail")
    }
}

// MARK: - SeriesFactsGuardTests

/// The three guards that keep a true fact off the wrong record (#405).
///
/// Version history:
///   1.0 — Session 2026-08-10: #405 (F-6)
@Suite("Series creator guards (#405)")
struct SeriesFactsGuardTests {

    /// `LotFileEntry` is decode-only (it mirrors the bundled JSON), so a fixture is built the
    /// way the app builds one: from JSON.
    private func entry(naId: String, level: String) -> LotFileEntry {
        let json = """
        {"lotNumber":"64D199","recordGroup":"59","naId":"\(naId)",
         "title":"Central Files","catalogURL":"https://catalog.archives.gov/id/\(naId)",
         "matchType":"controlNumber","levelOfDescription":"\(level)"}
        """
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(LotFileEntry.self, from: Data(json.utf8))
    }

    @Test("A file-unit entry is refused even when the NAID is covered")
    func fileUnitIsRefused() throws {
        let index = try #require(SeriesFactsIndexStore.shared)
        let coveredNaId = try #require(index.byNaId.keys.sorted().first)
        // Same NAID, two levels. The series form may resolve; the file-unit form must not,
        // because a file unit borrows its series title from its parent and would borrow the
        // parent's creator the same way — presented as the cited record's own.
        #expect(SeriesFactsIndex.creatorName(for: entry(naId: coveredNaId, level: "fileUnit")) == nil)
        #expect(SeriesFactsIndex.creatorName(for: entry(naId: coveredNaId, level: "series")) != nil,
                "the series form of a covered NAID must resolve, or this test proves nothing")
    }

    @Test("An uncovered series simply has no creator line")
    func uncoveredSeries() {
        #expect(SeriesFactsIndex.creatorName(for: entry(naId: "999999999", level: "series")) == nil)
    }
}

// MARK: - SeriesFactsDecisionTests

/// The two decisions the guards and the divided-lot row turn on (#405).
///
/// Both were mutation survivors, and both for the same reason: the rule was inline in a function
/// that needs a bundled singleton, so no test could reach it. Extracted and driven here.
///
/// Version history:
///   1.0 — Session 2026-08-10: #405 (F-6)
@Suite("Series creator decisions (#405)")
struct SeriesFactsDecisionTests {

    @Test("An unavailable central-files index is unknown, not clean")
    func untrustworthyFlagNilIsUnknown() {
        // `nil` means the flag list failed to load. Reading that as "this NAID is fine" would show
        // a creator on exactly the records #351 established point at the wrong collection —
        // precisely when the app has lost its ability to tell.
        #expect(!SeriesFactsIndex.shouldShow(isSeriesLevel: true, untrustworthyFlag: nil) == false,
                "nil must not block a series outright…")
        #expect(SeriesFactsIndex.shouldShow(isSeriesLevel: true, untrustworthyFlag: nil),
                "…an unavailable list is not evidence against this NAID")
        #expect(!SeriesFactsIndex.shouldShow(isSeriesLevel: true, untrustworthyFlag: true),
                "a flagged NAID is refused")
        #expect(SeriesFactsIndex.shouldShow(isSeriesLevel: true, untrustworthyFlag: false))
    }

    @Test("A file unit is refused whatever the flag says")
    func fileUnitAlwaysRefused() {
        for flag in [nil, true, false] as [Bool?] {
            #expect(!SeriesFactsIndex.shouldShow(isSeriesLevel: false, untrustworthyFlag: flag),
                    "file unit accepted with flag \(String(describing: flag))")
        }
    }

    @Test("A divided lot names a creator only when every claimant agrees")
    func unanimityRule() {
        #expect(LotClaimantsIndex.unanimousCreator(["A.", "A.", "A."]) == "A.")
        #expect(LotClaimantsIndex.unanimousCreator(["A.", "B."]) == nil,
                "two offices made these series; naming one is false for the other")
        #expect(LotClaimantsIndex.unanimousCreator(["A.", nil]) == nil, """
            Partial coverage must stay silent too. Naming the creator of the covered subset is \
            worse than saying nothing, because the reader cannot see which claimants it came from.
            """)
        #expect(LotClaimantsIndex.unanimousCreator([nil, nil]) == nil)
        #expect(LotClaimantsIndex.unanimousCreator([]) == nil)
        #expect(LotClaimantsIndex.unanimousCreator(["A."]) == "A.")
    }
}

// MARK: - SeriesCatalogFactsTests

/// NARA's trip-planning facts (#663 / F-7).
///
/// Version history:
///   1.0 — Session 2026-08-10: #663 (F-7)
@Suite("Series catalog facts (#663)")
struct SeriesCatalogFactsTests {

    private func shipped() throws -> SeriesFactsIndex {
        try #require(SeriesFactsIndexStore.shared)
    }

    /// Local fixture builder — same JSON route as the sibling suite's.
    private func fixture(headings: [String], rows: String,
                         statuses: [String] = [], restrictions: [String] = [],
                         useRestrictions: [String] = [], referenceUnits: [String] = [],
                         findingAidTypes: [String] = []) -> SeriesFactsIndex {
        func arr(_ xs: [String]) -> String {
            "[" + xs.map { "\"\($0)\"" }.joined(separator: ",") + "]"
        }
        let json = """
        {"schemaVersion":2,"generated":"2026-08-10","headings":\(arr(headings)),
         "byNaId":\(rows),"statuses":\(arr(statuses)),"restrictions":\(arr(restrictions)),
         "useRestrictions":\(arr(useRestrictions)),"referenceUnits":\(arr(referenceUnits)),
         "findingAidTypes":\(arr(findingAidTypes))}
        """
        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(SeriesFactsIndex.self, from: Data(json.utf8))
    }

    @Test("Access status resolves, and restriction is not the same as unrestricted")
    func accessStatusResolves() throws {
        let index = try shipped()
        var restricted = 0, unrestricted = 0
        for naId in index.byNaId.keys {
            guard let f = index.facts(forNaId: naId), let status = f.accessStatus else { continue }
            if f.isAccessRestricted { restricted += 1 } else { unrestricted += 1 }
            #expect(status.hasPrefix("Restricted") == f.isAccessRestricted)
        }
        // Measured 2026-08-10: 414 restricted (245 Partly, 97 Fully, 72 Possibly), 208 not.
        // Floors, not equalities — a re-harvest may move them — but the point is that BOTH
        // populations are large, so a surface must render the distinction rather than assume one.
        #expect(restricted > 300, "restricted: \(restricted)")
        #expect(unrestricted > 100, "unrestricted: \(unrestricted)")
    }

    @Test("Use restriction is tracked separately from access")
    func useIsSeparateFromAccess() throws {
        let index = try shipped()
        let all = index.byNaId.keys.compactMap { index.facts(forNaId: $0) }
        // Measured cross-tab, 2026-08-10: access-restricted × use-restricted =
        // (yes,yes) 175 · (yes,no) 239 · (no,yes) 43 · (no,no) 165. All four cells are populated,
        // which is the whole argument for two rows instead of one: 43 series may be READ but not
        // freely PUBLISHED, and 239 are the other way round. Folding them would mislead in both
        // directions.
        let readableNotPublishable = all.filter { !$0.isAccessRestricted && $0.isUseRestricted }
        let restrictedButFreeToPublish = all.filter { $0.isAccessRestricted && !$0.isUseRestricted }
        #expect(readableNotPublishable.count > 20,
                "readable-but-copyright: \(readableNotPublishable.count)")
        #expect(restrictedButFreeToPublish.count > 100,
                "restricted-but-publishable: \(restrictedButFreeToPublish.count)")

        // …and a status can arrive WITHOUT categories: 5 of the 43 carry `Restricted - Possibly`
        // and no `specificRestrictions`. The surface must render the status alone rather than
        // waiting for a category list that never comes.
        #expect(readableNotPublishable.contains { $0.useRestrictions.isEmpty }, """
            Expected at least one use-restricted series with no category. If this stops being \
            true the render path's empty-list branch is untested, not unnecessary.
            """)
    }

    @Test("Extent, holding facility and years are present for every covered series")
    func universalFieldsArePresent() throws {
        let index = try shipped()
        let all = index.byNaId.keys.compactMap { index.facts(forNaId: $0) }
        #expect(all.count >= 600)
        #expect(all.allSatisfy { $0.extent != nil }, "extent is 100% in the harvest")
        #expect(all.allSatisfy { $0.referenceUnit != nil }, "holding facility is 100%")
        #expect(all.allSatisfy { $0.years != nil }, "inclusive dates are 100%")
    }

    @Test("Finding aids are present on a minority, and that is honest")
    func findingAidsArePartial() throws {
        let index = try shipped()
        let withAids = index.byNaId.keys.compactMap { index.facts(forNaId: $0) }
            .filter { !$0.findingAids.isEmpty }
        // 122 of 622 — 19.6%. The row is absent for the rest, which is "NARA lists none", not a
        // gap in this artifact.
        #expect(withAids.count > 80 && withAids.count < 300, "finding aids: \(withAids.count)")
    }

    @Test("An out-of-range vocabulary index degrades rather than trapping")
    func corruptVocabularyIndex() {
        let i = fixture(headings: ["A."],
                      rows: #"{"1":{"c":0,"as":9,"ar":[4],"ru":7,"fa":[3],"y0":1953,"y1":1965}}"#,
                      statuses: ["Unrestricted"], restrictions: ["FOIA (b)(1)"],
                      referenceUnits: ["College Park"], findingAidTypes: ["Folder List"])
        let f = i.facts(forNaId: "1")
        #expect(f?.accessStatus == nil)
        #expect(f?.accessRestrictions.isEmpty == true)
        #expect(f?.referenceUnit == nil)
        #expect(f?.findingAids.isEmpty == true)
        #expect(f?.years == "1953–1965", "the years survive — they are not vocabulary-indexed")
    }

    @Test("A series with no facts at all yields nil, not an empty row")
    func emptyFactsAreNil() {
        let i = fixture(headings: ["A."], rows: #"{"1":{"c":0}}"#)
        #expect(i.facts(forNaId: "1") == nil,
                "an all-nil Facts would render a heading with nothing under it")
    }

    // MARK: - The legend, and the coverage pair (#1202, schema 3)

    /// The shipped artifact's raw JSON — the legend is a contract for consumers who hold only the
    /// file, so it is read the way they read it rather than through the app's decoder, which does
    /// not carry it.
    private func rawArtifact() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "FRUSExplorer/Resources/series-facts-index.json")
        return try #require(try JSONSerialization.jsonObject(with: try Data(contentsOf: url))
                            as? [String: Any])
    }

    /// Every key a row actually uses is in the legend, and every vocabulary it names exists.
    @Test("The legend accounts for every wire key in use, and names only real vocabularies")
    func legendIsComplete() throws {
        let artifact = try rawArtifact()
        #expect(artifact["schemaVersion"] as? Int == 3)
        let legend = try #require(artifact["legend"] as? [String: Any])
        let keys = try #require(legend["keys"] as? [String: [String: Any]])
        let rows = try #require(artifact["byNaId"] as? [String: [String: Any]])

        let used = Set(rows.values.flatMap(\.keys))
        let missing = used.subtracting(keys.keys).sorted()
        #expect(missing.isEmpty, """
            \(missing) appear in rows with no legend entry. An unlegended key is exactly the state \
            #1202 exists to end — a reader has to guess, and the run's own plan document guessed \
            wrong.
            """)
        // Not the converse as an equality: a legend entry for a key no row happens to carry is
        // documentation, not rot. But it must still name a vocabulary that exists.
        for (key, entry) in keys {
            guard let into = entry["into"] as? String else { continue }
            #expect(artifact[into] is [String], """
                legend key \(key) dereferences through `\(into)`, which is not a top-level array \
                in this artifact.
                """)
        }
    }

    /// **The legend's `into` claims are checked against where the app actually looks.**
    ///
    /// This is the assertion that makes the legend worth shipping. The failure #1202 reports was
    /// not "I could not guess what `as` means" — it was taking `as` through `restrictions` and
    /// getting a plausible wrong value on every row. The pairing is asymmetric: `as` and `us`
    /// BOTH resolve through `statuses`, while `ar` uses `restrictions` and `ur` uses
    /// `useRestrictions`, and nothing in the names says so.
    ///
    /// Every vocabulary here holds distinct sentinel strings, so a wrong dereference cannot
    /// coincide with a right one.
    @Test("Each legend entry names the vocabulary the app really resolves that key through")
    func legendMatchesTheAppsDereference() throws {
        let index = fixture(
            headings: ["H0"],
            rows: #"{"1":{"c":0,"as":0,"us":1,"ar":[0],"ur":[0],"ru":0,"fa":[0],"x":"E0","#
                + #""y0":1900,"y1":1910,"cy0":1890,"cy1":1920}}"#,
            statuses: ["S0", "S1"], restrictions: ["R0"], useRestrictions: ["U0"],
            referenceUnits: ["F0"], findingAidTypes: ["A0"])
        let facts = try #require(index.facts(forNaId: "1"))

        // `as` and `us` through `statuses` — and `us` is the trap, because its name pairs it with
        // `useRestrictions`. Distinct indices, so resolving `us` through the wrong array would
        // read out of range and yield nil.
        #expect(facts.accessStatus == "S0")
        #expect(facts.useStatus == "S1", """
            `us` must resolve through `statuses`, not `useRestrictions`. This is the exact \
            misreading #1202 reports.
            """)
        #expect(facts.accessRestrictions == ["R0"])
        #expect(facts.useRestrictions == ["U0"])
        #expect(facts.referenceUnit == "F0")
        #expect(facts.findingAids == ["A0"])
        #expect(facts.extent == "E0")
        #expect(index.creator(forNaId: "1") == "H0")

        // Now assert the legend SAYS all of that. Driving the decoder alone would prove the app
        // correct and leave the legend free to lie.
        let keys = try #require((try rawArtifact()["legend"] as? [String: Any])?["keys"]
                                as? [String: [String: Any]])
        let expected: [String: (field: String, into: String?)] = [
            "c": ("creator", "headings"), "p": ("predecessors", "headings"),
            "as": ("accessStatus", "statuses"), "us": ("useStatus", "statuses"),
            "ar": ("accessRestrictions", "restrictions"),
            "ur": ("useRestrictions", "useRestrictions"),
            "ru": ("referenceUnit", "referenceUnits"),
            "fa": ("findingAids", "findingAidTypes"),
            "x": ("extent", nil), "y0": ("inclusiveStartYear", nil),
            "y1": ("inclusiveEndYear", nil), "cy0": ("coverageStartYear", nil),
            "cy1": ("coverageEndYear", nil),
        ]
        for (key, want) in expected {
            let got = try #require(keys[key], "legend has no entry for `\(key)`")
            #expect(got["field"] as? String == want.field, "legend field for `\(key)`")
            #expect(got["into"] as? String == want.into, "legend vocabulary for `\(key)`")
        }
        #expect(Set(keys.keys) == Set(expected.keys), "legend keys drifted from the schema")
    }

    /// The coverage pair ships, is additive, and does NOT contain the inclusive pair.
    ///
    /// The containment point is the one a consumer gets wrong. `naId 604801` is inclusive
    /// 1963–1973 and coverage 1947–1964 — neither contains the other — so a date screen must take
    /// the UNION. Measured over the commercial-diplomacy run's 93 lot resolutions, the union
    /// fails 3 (the figure the guide's §14.11 rule 3 states), preferring coverage fails 4 by
    /// inventing a failure on exactly this series, and the inclusive pair alone fails 6.
    @Test("The coverage pair ships beside the inclusive one, and neither contains the other")
    func coveragePairShipsAndDoesNotContain() throws {
        let index = try shipped()
        let withCoverage = index.byNaId.values.filter { $0.coverageStartYear != nil }
        #expect(withCoverage.count >= 150, """
            NARA publishes a coverage pair for a minority of series — 173 of 695 when this \
            shipped. A collapse to near zero means the harvest field stopped decoding.
            """)
        #expect(index.byNaId.count == 695, "row count must not move: this change is additive")

        let counterexample = try #require(index.byNaId["604801"], """
            naId 604801 is the case that disproves containment; if it left the artifact, find \
            another before weakening this test.
            """)
        #expect(counterexample.startYear == 1963 && counterexample.endYear == 1973)
        #expect(counterexample.coverageStartYear == 1947 && counterexample.coverageEndYear == 1964)
        let coverageContainsInclusive =
            counterexample.coverageStartYear! <= counterexample.startYear!
            && counterexample.coverageEndYear! >= counterexample.endYear!
        #expect(!coverageContainsInclusive, """
            Coverage is USUALLY the wider span, which is what makes "prefer coverage" tempting \
            and wrong. Take the union.
            """)
    }
}
