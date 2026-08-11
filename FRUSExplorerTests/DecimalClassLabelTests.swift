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

    @Test("The four glosses that shipped wrong are gone, and the good ones stayed")
    func retiredMislabels() throws {
        let table = try table()
        let schedule = try #require(table.schedules.first)
        let band0 = 1861...1947

        // `52` shipped as `Africa."` — the tail of the note *Formerly "German Southwest Africa."*
        // — glossing 1,761 documents with a fragment of prose. It is Spain.
        #expect(schedule.countries["52"] == "Spain")
        #expect(table.gloss(for: "852.00", coveringYears: band0)?.hasPrefix("Spain") == true)

        // `01` and `11h` were placed in the 1910–49 column by the `Discontinued ⇒ left-align`
        // rule, which reads an annotation written from the perspective of a column the text never
        // names. `01` glossed 4,513 documents as "Arctic", among them `501.BB` (1,628) — a United
        // Nations key that names no country at all.
        #expect(schedule.countries["01"] == nil, """
            A code the source does not place in this column must not appear in it. This one \
            reached more documents than any correct entry except the largest.
            """)
        #expect(schedule.countries["11h"] == nil)
        #expect(table.gloss(for: "501.BB", coveringYears: band0) == nil, """
            `501.BB` is a Class 5 United Nations key. Glossing it "Arctic" is the exact failure \
            this table is supposed to be incapable of.
            """)

        // `90c` merged two rows' names into "Azerbaijan Azores".
        #expect(schedule.countries["90c"]?.contains("Azores") != true)

        // And the entries that were right stayed right.
        for (code, name) in [("62", "Germany"), ("51", "France"), ("41", "Great Britain"),
                             ("65", "Italy"), ("93", "China")] {
            #expect(schedule.countries[code] == name, "\(code) regressed")
        }
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

    @Test("The class-8 tree reaches the subject, not just the top of its branch")
    func nestedSubjects() throws {
        let table = try table()
        let band0 = 1861...1947

        // The three keys behind the largest gains, each a file a reader would recognise. Before
        // the subdivision tree was parsed all three glossed as the bare country name.
        #expect(table.gloss(for: "812.6363", coveringYears: band0) == "Mexico — Petroleum", """
            419 documents. `.6363` sits under `.636 Carbon. Graphite` under `.63 Mines. Mining`, \
            and the manual states the class once at the top of that branch.
            """)
        #expect(table.gloss(for: "882.5048", coveringYears: band0)
            == "Liberia — Slavery. Compulsory labor. Peonage")
        #expect(table.gloss(for: "891.51A", coveringYears: band0) == "Iran — Financial adviser")

        // The subject keeps the manual's capitalisation. Lower-casing it was fine for 61 common
        // nouns and wrong for a tree full of proper ones.
        #expect(table.gloss(for: "838.00N", coveringYears: band0) == "Haiti — Nazi. Nazi activities")
        #expect(table.gloss(for: "811.142", coveringYears: band0) == "United States — Red Cross")
    }

    @Test("Nothing the scan mangled reached the table")
    func nestedParseDefectsAreAbsent() throws {
        let table = try table()
        let schedule = try #require(table.schedules.first)
        let subjects = try #require(schedule.subjects["8"])

        // Four entries with the facing column's note welded onto them by the text layer. The
        // manual prints `.541 Industrial property.` and a separate right-hand note reading
        // "** Country in which protection is sought. For treaties, conventions, arrangements,
        // ect., add country number ††, using smaller number of country for **."
        for suffix in ["541", "542", "543", "796104"] {
            #expect(subjects[suffix] == nil, """
                \(suffix) would ship the facing column. "Patents is sought" is confident nonsense, \
                and a reader cannot tell it from a label.
                """)
        }
        #expect(subjects["544"] == "Copyrights", "the same bleed, cut where the second column starts")

        // Route termini under `800.88 Foreign carrying trade` — subdivisions of country 00, The
        // World, not of the class.
        #expect(subjects["8810"] == nil)
        #expect(table.gloss(for: "862.8810", coveringYears: 1861...1947) == "Germany", """
            Inherited by the class this would read "Germany — North America". Unglossed suffixes \
            fall back to the country alone, which is what the key meant before #828 and is still \
            true of it.
            """)

        // Class 7's bare children belong to the whole numbers heading them (`701.01`), and class
        // 6's name a second country, so neither contributes a general suffix.
        #expect(schedule.subjects["7"] == nil, """
            `.01 Right of residence` sits under `701 Diplomatic representation`. Filed as a class-7 \
            subject it would gloss `761.01` as the Soviet Union's right of residence.
            """)
        #expect(schedule.subjects["6"]?.count == 1)
        #expect(subjects.keys.contains { $0.contains("†") } == false)
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
