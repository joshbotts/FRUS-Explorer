// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing

@testable import FRUSExplorer

// MARK: - DecimalClassLabelTests

/// The bundled class-label table, and the rule deciding when it is allowed to speak (#828).
@Suite("Archival analytics — decimal class labels")
struct DecimalClassLabelTests {

    /// The shipped artifact.
    private func table() throws -> DecimalClassLabelTable {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Resources/decimal-class-labels.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(DecimalClassLabelTable.self, from: data)
    }

    @Test("The shipped table reads real corpus keys the way the schedule does")
    func realKeys() throws {
        let table = try table()
        let band0 = 1861...1947   // the era band #828 exists for

        // A relations class: two countries, from the same schedule.
        #expect(table.gloss(for: "793.94", coveringYears: band0) == "China and Japan")
        // An internal-affairs class: one country and a subject. The suffix `.51` LOOKS like a
        // country code (France) and must not be read as one — class 8 is not a relations class.
        #expect(table.gloss(for: "893.51", coveringYears: band0)?.hasPrefix("China —") == true)
        #expect(table.gloss(for: "893.51", coveringYears: band0)?.contains("France") == false, """
            Class 8 is Internal Affairs of States. Reading its suffix as a second nation invents \
            a relationship the citation does not claim.
            """)
        // A curated correction, and the inverted index form un-inverted.
        #expect(table.gloss(for: "812.00", coveringYears: band0)?.hasPrefix("Mexico") == true)
        #expect(table.gloss(for: "795.00", coveringYears: band0) == "Korea and The World", """
            NARA's table alphabetises, so it stores "World, The". Left as filed it read \
            "Korea and World, The".
            """)
    }

    @Test("A span crossing the 1950 renumbering is left unlabelled")
    func renumberingBoundary() throws {
        let table = try table()
        // 1948–1960 covers both schedules, where the same digits mean different things: class 7 is
        // Political Relations before 1950 and Internal Political Affairs after. A key from that
        // band could be read either way.
        #expect(table.gloss(for: "793.94", coveringYears: 1948...1960) == nil, """
            Labelling across the renumbering would be a confident guess, and a wrong gloss on an \
            archival citation is worse than a bare number — the reader cannot tell it is wrong.
            """)
        // But a span ending before the boundary is fine, even though it opens long before the
        // decimal file existed: there are no decimal keys in 1861–1909 to mislabel.
        #expect(table.gloss(for: "793.94", coveringYears: 1861...1947) != nil, """
            Requiring containment at BOTH ends silenced the whole first era band — the one era \
            where the class lens IS the named archival record.
            """)
    }

    @Test("Anything the table cannot place stays silent")
    func silence() throws {
        let table = try table()
        let band0 = 1861...1947
        // Class 1 is administration of the US government — `111.11` is not "country 11".
        #expect(table.gloss(for: "111.11", coveringYears: band0) == nil)
        // A country number the schedule does not carry.
        #expect(table.gloss(for: "799.1", coveringYears: band0) == nil)
        // Subject-numeric keys are a different filing system entirely.
        #expect(table.gloss(for: "POL 27 VIET S", coveringYears: band0) == nil)
        #expect(table.gloss(for: "", coveringYears: band0) == nil)
    }

    @Test("The ranking hands every surface the same gloss")
    func rankingCarriesTheGloss() throws {
        // The single injection point: if this works, the chart, the uncapped list, the exports and
        // the guide card are all labelled, because each reaches rows through `ranking`.
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("FRUSExplorer/Analytics/ArchivalCollectionsData.swift"),
            encoding: .utf8)
        #expect(source.contains("gloss: DecimalClassLabelStore.shared?"), """
            The gloss must be attached where class rows are BUILT. Attached in a view instead, \
            every other surface — the CSV especially — would still ship bare numbers.
            """)
        #expect(source.contains("coveringYears: span"), """
            The span comes from the bands being ranked; without it the table cannot tell which \
            schedule may speak.
            """)
        // And the key itself survives: a pull slip needs the number, not the prose.
        #expect(source.contains("ArchivalRankingRow(id: key, label: key, name: key,"))
    }

    @Test("The uncapped list and its CSV both carry the gloss")
    func listAndExport() throws {
        let sheet = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("FRUSExplorer/Analytics/ArchivalAllUnitsSheet.swift"),
            encoding: .utf8)
        #expect(sheet.contains("if let gloss = row.gloss"))
        #expect(sheet.contains("[$0.label, $0.gloss].compactMap { $0 }.joined(separator: \" — \")"), """
            A spreadsheet of bare decimal numbers is the same problem one layer out from the \
            screen.
            """)
    }
}
