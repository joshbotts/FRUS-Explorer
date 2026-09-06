// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation

// MARK: - AccessionSeriesIndexTests

/// The shipped `accession-series-index.json` (#1203).
///
/// **Read raw, on purpose.** This artifact has no app decoder: the owner's decision was to ship
/// the data and document it for analysts, not to render it, because the join answers 150 of 995
/// accession citations (15%) and its most-cited key returns 59 series. So the consumer these
/// tests stand in for is someone holding only the JSON — the same stance
/// `DecimalClassLabelTests` takes for #1204's era contract.
@Suite("Accession → series map (#1203)")
struct AccessionSeriesIndexTests {

    /// The shipped artifact, read the way a consumer reads it.
    private func artifact() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "FRUSExplorer/Resources/accession-series-index.json")
        return try #require(try JSONSerialization.jsonObject(with: try Data(contentsOf: url))
                            as? [String: Any])
    }

    private func rows() throws -> [String: [[String: Any]]] {
        try #require(try artifact()["byAccession"] as? [String: [[String: Any]]])
    }

    @Test("The artifact ships, at the measured scale")
    func shipsAtScale() throws {
        let index = try artifact()
        #expect(index["schemaVersion"] as? Int == 1)
        let byAccession = try rows()
        #expect(byAccession.count >= 4_500, "accession keys: \(byAccession.count)")
        // A collapse to a handful means the harvest field stopped decoding — the generator throws
        // on empty, but it cannot detect "wrote a tenth of what it should".
        let claimants = byAccession.values.map(\.count).reduce(0, +)
        #expect(claimants >= 7_000, "claimants: \(claimants)")
    }

    /// **The record group is part of the key, and this is the case that proves it must be.**
    ///
    /// An accession number is unique only within its record group. `68A5612` names ONE series in
    /// RG 59 and EIGHTEEN in RG 84 — different records entirely. A map keyed on the bare accession
    /// would answer a State citation with Foreign Service Post records, and would report higher
    /// "coverage" for doing so: unscoped, the join reaches 15% of citations against 7% scoped to
    /// RG 59. That difference is wrong answers, not coverage.
    @Test("The same accession number means different records in different record groups")
    func recordGroupIsPartOfTheKey() throws {
        let byAccession = try rows()
        let inState = try #require(byAccession["59/68A5612"], "59/68A5612 must be present")
        let inPosts = try #require(byAccession["84/68A5612"], "84/68A5612 must be present")
        #expect(inState.count == 1)
        #expect(inPosts.count >= 15, "RG 84 claimants: \(inPosts.count)")
        let stateNaIds = Set(inState.compactMap { $0["n"] as? String })
        let postNaIds = Set(inPosts.compactMap { $0["n"] as? String })
        #expect(stateNaIds.isDisjoint(with: postNaIds), """
            The two record groups' claimants must be disjoint — if they overlap, the prefix split \
            is merging what it exists to keep apart.
            """)
        // And no key is stored bare, which is how the scoping is actually enforced.
        #expect(byAccession.keys.allSatisfy { $0.contains("/") },
                "every key must carry its record group")
    }

    /// #1203's stated acceptance case.
    @Test("71 A 6682 reaches the series carrying its item numbers")
    func issueAcceptanceCase() throws {
        let claimants = try #require(try rows()["59/71A6682"])
        let naIds = Set(claimants.compactMap { $0["n"] as? String })
        #expect(naIds.contains("26309419"), """
            NAID 26309419 carries items 059-71A6682-9/-29/-33. It is reachable only because an \
            item suffix folds to its base accession.
            """)
        #expect(naIds.contains("27022878"), "NAID 27022878 carries item 059-71A6682-31")
        // The issue asks that this render as a list, never as a single card. There is no render
        // surface, so what the artifact owes is the honest count.
        #expect(claimants.count >= 50, """
            This is the worst case the artifact holds — \(claimants.count) series under one \
            accession — and it is why the map states the division instead of choosing.
            """)
    }

    /// The legend covers every key a row actually uses (#1202's rule, applied to a second file).
    @Test("The legend accounts for every wire key in use")
    func legendIsComplete() throws {
        let legend = try #require(try artifact()["legend"] as? [String: String])
        let used = Set(try rows().values.flatMap { $0.flatMap(\.keys) })
        #expect(used.subtracting(legend.keys).isEmpty, """
            unlegended keys: \(used.subtracting(legend.keys).sorted()). One-letter keys are only \
            defensible because the file says what they mean.
            """)
        #expect(legend["i"]?.contains("ABSENT") == true, """
            `i` is omitted when false — 230 of 7,349 rows carry it — so the legend must say that \
            absence means false rather than unknown.
            """)
    }
}
