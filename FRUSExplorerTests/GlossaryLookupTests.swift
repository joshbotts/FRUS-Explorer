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

// MARK: - GlossaryAssemblyTests

/// Grouping and ranking corpus-wide glossary results (#265).
///
/// The SQL is a `GROUP BY`; the part worth pinning is what happens to the rows afterwards, so
/// `assemble` is pure and this suite drives it with no database.
///
/// Version history:
///   1.0 — Session 2026-08-10: #265 (F-11)
@Suite("Glossary assembly (#265)")
struct GlossaryAssemblyTests {

    private typealias Row = (term: String, definition: String, count: Int, volume: String)

    private func assemble(_ rows: [Row], query: String = "", limit: Int = 60) -> [GlossaryEntry] {
        IndexingPipeline.assemble(rows: rows, query: query, limit: limit)
    }

    @Test("A term's competing definitions are all carried, most used first")
    func variantsAreCarried() {
        // The measured shape of the real data: `EUR` has 30 distinct definitions across 231
        // volumes. Showing one would pick an editor's wording and hide the rest.
        let entries = assemble([
            ("EUR", "Bureau of European Affairs", 180, "frus1969-76v01"),
            ("EUR", "European Affairs", 40, "frus1958-60v03"),
            ("EUR", "Office of European Regional Affairs", 11, "frus1952-54v05"),
        ])
        #expect(entries.count == 1)
        let eur = entries[0]
        #expect(eur.variants.count == 3)
        #expect(eur.variants.map(\.volumeCount) == [180, 40, 11])
        #expect(eur.primaryDefinition == "Bureau of European Affairs")
        #expect(eur.isContested, "three wordings is exactly the case a single answer would hide")
    }

    @Test("A term defined one way is not contested")
    func singleDefinition() {
        let entries = assemble([("NATO", "North Atlantic Treaty Organization", 221, "v1")])
        #expect(entries[0].isContested == false)
        #expect(entries[0].volumeCount == 221)
    }

    @Test("An exact match outranks a longer term that merely starts the same")
    func exactBeatsPrefix() {
        // Someone typing "NSC" wants NSC, not "NSC Action No." above it — even though the latter
        // may be defined in more volumes.
        let entries = assemble([
            ("NSC Action No.", "Numbered NSC decision", 200, "v1"),
            ("NSC", "National Security Council", 120, "v2"),
        ], query: "NSC")
        #expect(entries.map(\.term) == ["NSC", "NSC Action No."], "got \(entries.map(\.term))")
    }

    @Test("A prefix match outranks a mid-word match")
    func prefixBeatsContains() {
        let entries = assemble([
            ("USNSC", "contains it mid-word", 500, "v1"),
            ("NSCX", "starts with it", 3, "v2"),
        ], query: "NSC")
        #expect(entries.map(\.term) == ["NSCX", "USNSC"])
    }

    @Test("Within a rank, breadth wins")
    func breadthBreaksTies() {
        // No frequency data exists in a glossary, so the number of volumes defining a term is the
        // best available proxy for "this is the one you meant".
        let entries = assemble([
            ("AID", "Agency for International Development", 150, "v1"),
            ("AIDE", "aide-mémoire", 4, "v2"),
        ], query: "AID")
        #expect(entries.first?.term == "AID")
    }

    @Test("An empty query returns the most widely defined terms")
    func emptyQueryRanksByBreadth() {
        // This is what makes the surface useful before the user has typed anything.
        let entries = assemble([
            ("JCS", "Joint Chiefs of Staff", 287, "v1"),
            ("rare", "seldom defined", 1, "v2"),
        ], query: "")
        #expect(entries.map(\.term) == ["JCS", "rare"])
    }

    @Test("Volume count is not the sum of the variants")
    func volumeCountDoesNotDoubleCount() {
        // A volume whose glossary gives two wordings of one abbreviation would be counted twice
        // by a naive sum — 180 + 40 = 220 volumes for a corpus that has 231 in total.
        let entries = assemble([
            ("EUR", "A", 180, "v1"),
            ("EUR", "B", 40, "v2"),
        ])
        #expect(entries[0].volumeCount == 180, "got \(entries[0].volumeCount)")
    }

    @Test("Rows with no term or no definition are dropped, not shown blank")
    func emptyRowsDropped() {
        let entries = assemble([
            ("", "orphan definition", 3, "v1"),
            ("TERM", "", 3, "v2"),
            ("REAL", "a real definition", 3, "v3"),
        ])
        #expect(entries.map(\.term) == ["REAL"])
    }

    @Test("The limit is honoured")
    func limitApplies() {
        let rows: [Row] = (1...100).map { ("T\($0)", "d", $0, "v") }
        #expect(assemble(rows, limit: 10).count == 10)
    }
}

// MARK: - GlossaryEscapeTests

/// LIKE-wildcard handling (#265).
///
/// Version history:
///   1.0 — Session 2026-08-10: #265 (F-11)
@Suite("Glossary LIKE escaping (#265)")
struct GlossaryEscapeTests {

    @Test("Wildcards a user types are searched for, not interpreted")
    func escapesWildcards() {
        // `S/S_` and `100%` are plausible things to type into a glossary box. Unescaped, `_`
        // matches any character and `%` matches everything, so the search silently returns the
        // wrong set rather than nothing — the worse failure, because it looks like an answer.
        #expect(IndexingPipeline.escapeLike("100%") == #"100\%"#)
        #expect(IndexingPipeline.escapeLike("S_S") == #"S\_S"#)
        #expect(IndexingPipeline.escapeLike(#"a\b"#) == #"a\\b"#)
        #expect(IndexingPipeline.escapeLike("NSC") == "NSC", "ordinary text is untouched")
    }
}
