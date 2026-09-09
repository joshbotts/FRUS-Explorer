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

    @Test("With a second schedule in the table, a span straddling 1950 still says nothing")
    func straddlingSpansAcrossTwoSchedules() throws {
        // The shipped table carries ONE schedule, which hides this: an upper-bound-only test
        // labels a span whose end lands inside a schedule, however far back its evidence runs.
        // Harmless while nothing follows 1949 and a mislabel the moment something does — 1945–1955
        // would read against the 1951–59 table, naming countries by numbers half its documents
        // predate. Decoded here rather than waited for, because the defect arrives with data, not
        // with code, and nothing else in the suite would catch it.
        let json = """
        {"schemaVersion":1,"generated":"2026-08-11","provenance":"test","schedules":[
          {"id":"1910-1949","startYear":1910,"endYear":1949,"source":"test",
           "classes":{"8":"Internal Affairs of States"},"relationsClasses":["7"],
           "countryArrangedClasses":["6","7","8"],"countries":{"91":"Iran"},"subjects":{}},
          {"id":"1951-1959","startYear":1951,"endYear":1959,"source":"test",
           "classes":{"7":"Internal Political and National Defense Affairs"},
           "relationsClasses":["6"],"countryArrangedClasses":["3","4","5","6","7","8","9"],
           "countries":{"88":"Iran"},"subjects":{}}]}
        """
        let table = try JSONDecoder().decode(DecimalClassLabelTable.self, from: Data(json.utf8))

        // Wholly inside one schedule or the other: both resolve, and to different countries,
        // which is the renumbering this table exists to keep apart.
        #expect(table.gloss(for: "891.00", coveringYears: 1930...1940) == "Iran")
        #expect(table.gloss(for: "888.00", coveringYears: 1955...1958) == "Iran")
        #expect(table.gloss(for: "891.00", coveringYears: 1955...1958) == nil)

        // Straddling. The upper bound sits squarely inside the later schedule.
        #expect(table.gloss(for: "888.00", coveringYears: 1945...1955) == nil, """
            Half this key's documents were filed before the renumbering. Reading it against the \
            schedule its last year falls in is exactly the confident guess era-scoping exists to \
            prevent, and only the span's LOWER bound can see it.
            """)

        // And the clamp still holds at the bottom: 1861 is where the series opens, not the file.
        #expect(table.gloss(for: "891.00", coveringYears: 1861...1940) == "Iran", """
            The decimal file begins in 1910, so a span opening earlier carries no keys in those \
            years to mislabel. Literal containment here silenced the whole first era band.
            """)
        #expect(table.gloss(for: "891.00", coveringYears: 1861...1900) == nil, """
            A span that ends before the file opens holds no decimal keys at all, and the clamp \
            must not lift it into the first schedule.
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

    /// The seven codes #1201 reported, and what became of each.
    ///
    /// **Five were one bug wearing three faces.** Rows were being lost, and whatever survived took
    /// the code by default: `Cook Islands` held 47h only because `New Zealand` never parsed, and
    /// `Ruthenia` held 60f because `Czechoslovakia` lost a shortest-name tie-break. The losses had
    /// three causes — a merged header line (`Country Country`), a note ending inside quotation
    /// marks (`"Australia."`), and single-column rows dropped as unplaceable when the note names
    /// the year that places them.
    @Test("The country codes #1201 reported resolve, or stay honestly silent")
    func reportedCountryCodes() throws {
        let schedule = try #require(try table().schedules.first)

        // Recovered by parsing, each from a complete row the scan had been throwing away.
        #expect(schedule.countries["54"] == "Switzerland")
        #expect(schedule.countries["43"] == "Newfoundland")
        #expect(schedule.countries["11b"] == "Philippines")

        // Recovered by parsing the row that had been losing to a survivor.
        #expect(schedule.countries["47h"] == "New Zealand", """
            47h glossed as "Cook Islands" because New Zealand's row was consumed by the preceding             note's closing quotation mark. Both are in the table; only one is the sovereign state.
            """)

        // Settled by curation, because the table names three claimants and no rule picks between
        // them — see `corrections["1910-1949"]["60f"]`.
        #expect(schedule.countries["60f"] == "Czechoslovakia", """
            60f carries `Czechoslovakia`, `Czecho-Slovak Republic` and `Ruthenia` in the table.             The shortest-name tie-break took the province over the state, and 82 documents on             `611.60F31` are US–Czechoslovak commerce.
            """)

        // **ANSWERED SINCE #1256, and how they were answered is the point.** Canada (42) and
        // Bulgaria (74) were the two codes #1201 recorded as structurally unanswerable: their
        // pages emit names and codes as separate blocks, so the TEXT LAYER settles no pairing and
        // the table stayed silent rather than guessing. The pairing was never missing from the
        // document — only from the projection of it the parser was reading. Reading the columns
        // by their own geometry supplies it, which is the clearest evidence the change is
        // recovering the source rather than inferring harder.
        #expect(schedule.countries["42"] == "Canada")
        #expect(schedule.countries["74"] == "Bulgaria")
    }

    /// The entries the column inference got wrong, now read off the page (#1256).
    ///
    /// Each of these was a plausible name in a wrong column, which is the failure mode that does
    /// not announce itself: a code in the wrong era still glosses, it just names another era's
    /// country.
    @Test("The codes the alignment rules misplaced now read out of their own column")
    func geometryFixesTheMisplacedCodes() throws {
        let table = try table()
        func schedule(_ id: String) throws -> DecimalClassLabelTable.Schedule {
            try #require(table.schedules.first { $0.id == id })
        }
        let fifties = try schedule("1950-1959")
        let sixties = try schedule("1960-1963")

        // FABRICATED CELLS. The document leaves Amhara's 1960–63 cell empty and gives 77 to the
        // Somali Republic, established July 1960; the right-alignment rule invented the entry.
        #expect(sixties.countries["77"] == "Somali Republic")
        // Trieste is printed in the 1910–49 column and was right-aligned into 1960–63, a column
        // whose span excludes its own stated year.
        #expect(sixties.countries["60s"] == nil)
        // 65d is a 1910–49 code that reached the 1950–59 table the same way.
        #expect(fifties.countries["65d"] == nil)

        // WELDED ROWS. `selectionsByLine()` returns some printed rows as one line beginning at the
        // name column, which minted names of no country at all.
        for schedule in table.schedules {
            for name in schedule.countries.values {
                #expect(name != "Niger, Republic of Nigeria")
                #expect(!name.contains("Bijagoz"))
            }
        }

        // THE TIE-BREAK reads the column span before the name length, so a head entry beats a
        // redirect row that merely has a shorter name.
        #expect(sixties.countries["75"] == "Ethiopia", "not Galla, which takes 75 only from 1960")
        #expect(fifties.countries["51f"] == "French India", "not Mahe, one of six claimants")
    }

    /// One code, several places — vended honestly (#1257).
    ///
    /// The Department filed a territory under the number of the power holding it, so a code
    /// carries a parent and its dependencies. Measured over the shipped corpus, a QUARTER of the
    /// documents a schedule can gloss sit on such a code, so the single name the table vends is an
    /// assertion it cannot support on its own.
    @Test("A shared code names its other places, and never itself")
    func sharedCodesCarryTheirOtherClaimants() throws {
        let table = try table()
        func schedule(_ id: String) throws -> DecimalClassLabelTable.Schedule {
            try #require(table.schedules.first { $0.id == id })
        }

        // THE CURATED HEAD TERMS. The tie-break takes the shortest name, which for these is a
        // constituent of one of its own co-claimants — a part standing for the whole.
        let early = try schedule("1910-1949")
        #expect(early.countries["11f"] == "Panama Canal Zone", "not Naos Island, which is in it")
        #expect(early.countries["51g"] == "Indo China", "not Annam, which is a region of it")
        #expect(early.countries["90f"] == "Saudi Arabia", "not Nejd, which is a region of it")
        #expect(try schedule("1960-1963").countries["91"] == "India",
                "not Mahe, a French enclave in it — 1,721 documents")

        // AND THE DISCLOSURE. The name the tie-break displaced is still reachable.
        let alternates = try #require(early.countryAlternates?["11f"])
        #expect(alternates.contains("Naos Island"))
        #expect(alternates.contains("Culebra Island"))

        // A LIST NEVER CONTAINS THE NAME BESIDE IT. `displaced` is built during the tie-break,
        // before a curated correction can override the winner, so using it directly shipped
        // `11f = Panama Canal Zone (also: … Panama Canal Zone)`.
        for schedule in table.schedules {
            for (code, others) in schedule.countryAlternates ?? [:] {
                let vended = try #require(schedule.countries[code],
                                          "\(code) has alternates but no name of its own")
                #expect(!others.contains(vended), "\(code) lists its own vended name")
                #expect(!others.isEmpty)
                #expect(others == others.sorted(), "\(code) is unsorted, so a rebuild would differ")
            }
        }
    }

    @Test("The alternates come from the schedule the gloss came from")
    func alternatesFollowTheEra() throws {
        let table = try table()
        // `91` is Iran before the renumbering and India after it, and the claimant sets differ
        // with them. Asking with the wrong span would show one era's places beside another
        // era's name.
        #expect(table.alternates(for: "891.00", coveringYears: 1920...1930).contains("Persia"))
        #expect(table.alternates(for: "891.00", coveringYears: 1961...1963).contains("Mahe"))

        // A class that is not country-arranged never resolves a country at all — and the
        // fixture has to collide, or the guard is untested. Class 5 is NOT country-arranged
        // before 1950 but IS after it, and `11f` carries four claimants in every schedule, so
        // `511f.00` is refused here and answered on the other side of the renumbering. A key
        // like `501.BB`, whose digits name no shared code, would pass with the guard deleted.
        #expect(table.alternates(for: "511f.00", coveringYears: 1920...1930).isEmpty, """
            Class 5 is Protection of Interests before 1950, so `11f` is not a country number \
            here and must not be dressed as one.
            """)
        #expect(table.alternates(for: "511f.00", coveringYears: 1955...1958).contains("Naos Island"),
                "the control: the same digits ARE a country number once class 5 is country-arranged")
        // Outside every schedule there is nothing to say.
        #expect(table.alternates(for: "891.00", coveringYears: 1850...1860).isEmpty)
    }

    /// The rows recovered alongside them, so the fix is measured rather than asserted.
    @Test("The recovered rows are in, and nothing that was right was lost")
    func recoveredRows() throws {
        let schedule = try #require(try table().schedules.first)
        var found = 0
        for (code, name) in [("60i", "Estonia"), ("90i", "Jordan"), ("53k", "Principe"),
                             ("67k", "Crete"), ("50d", "Spitzbergen"), ("59d", "St. John Island")] {
            #expect(schedule.countries[code] == name, "\(code) should be \(name)")
            found += 1
        }
        #expect(found == 6, "the recovery sweep ran over \(found) codes")

        // Crete, Spitzbergen and St. John Island each carry TWO 1910–49 codes because the file
        // renumbered mid-period. Both must resolve: the artifact maps code to name, so neither
        // pairing contradicts the other.
        #expect(schedule.countries["68c"] == "Crete")
        #expect(schedule.countries["57h"] == "Spitzbergen")
        // St. John's other code, `11g`, is now CURATED to the whole it is a part of (#1257) —
        // the recovered row is still there, as one of the three islands `11g` covers, and this
        // asserts the recovery rather than the tie-break's choice among them.
        #expect(schedule.countries["11g"] == "Virgin Islands (U.S.)")
        #expect(schedule.countryAlternates?["11g"]?.contains("St. John Island") == true)
        #expect(schedule.countries["59d"] == "St. John Island")
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


    @Test("Over the shipped corpus, a whole era of keys stops rendering bare")
    func perKeyAttributionOverTheRealCorpus() throws {
        // The artifact tests above pin what the table SAYS; this one pins what the app does with
        // it, over the real usage index and the real manifest, through the same derivation the
        // chart draws. It exists because the rule it checks is invisible to every synthetic
        // fixture: the numbers only mean something against the corpus's actual coverage.
        let usage = try #require(CollectionUsageIndexStore.shared)
        let url = try #require(Bundle.main.url(forResource: "manifest", withExtension: "json"))
        let entries = try JSONDecoder().decode([VolumeManifestEntry].self,
                                               from: Data(contentsOf: url))
        let data = ArchivalCollectionsData.make(
            authority: [], usage: usage,
            coverage: ArchivalVolumeCoverage.map(from: entries))

        func glossed(_ band: ArchivalEraBand) -> [ArchivalRankingRow] {
            data.ranking(band: band, lens: .centralFileClasses, weight: .documents,
                         hidingUmbrella: false, limit: .max).rows.filter { $0.gloss != nil }
        }

        // Band 0 is the era the schedule covers outright, and it was already labelled.
        let band0 = glossed(ArchivalEraBand.all[0])
        #expect(band0.count > 3_000)
        #expect(band0.contains { $0.id == "812.6363" && $0.gloss == "Mexico — Petroleum" })

        // Band 1 spans 1948–1960 and is covered by NO schedule — 1948 sits in the 1910–49 table
        // and 1960 in the 1960–63 one, so the straddle rule refuses the band's own years exactly
        // as it did before those tables existed. Its keys are another matter: 310 of them are
        // cited only by volumes inside the 1910–49 file.
        let band1 = glossed(ArchivalEraBand.all[1])
        #expect(band1.count > 250, """
            The band-span rule labels zero rows here and always will; every row in this list is \
            one the per-key span rescued.
            """)
        #expect(band1.contains { $0.id == "862.00" && $0.gloss == "Germany — Political affairs" })

        // Bands 2–4 open in 1961. All three labelled nothing while the file carried one decimal
        // schedule; band 2 labelled 448 once the 1950s and 1960s decimal schedules were parsed;
        // and #1211's two subject-numeric schedules take the three to 549 / 65 / 0. Every one of
        // those rows is labelled out of the schedule governing its own citing volumes, never the
        // band's — no schedule of either filing system covers 1961–1968 or 1969–1976 outright.
        //
        // BAND 4'S ZERO IS THE GUARD AND IT HAS TO SURVIVE EVERY TABLE ADDED. It opens in 1977,
        // after the decimal file closed in 1963 and after the subject-numeric schedules end in
        // 1973, so a label there could only come from a rule reading a key against a nearby
        // schedule rather than against its own evidence.
        let laterCounts = (2...4).map { glossed(ArchivalEraBand.all[$0]).count }
        #expect(laterCounts[0] > 500, """
            Band 2 draws on both filing systems — the 1960–63 decimal schedule and the 1963 \
            subject-numeric one. Got \(laterCounts[0]).
            """)
        #expect(laterCounts[1] > 50, """
            Band 3 opens in 1969 and labelled nothing at all until the subject-numeric schedules \
            shipped; its rows are keys cited by volumes sitting inside 1964–1973. Got \
            \(laterCounts[1]).
            """)
        #expect(laterCounts[2] == 0, """
            Nothing after 1973 has a schedule in either filing system, so a gloss in band 4 could \
            only be a guess. Got \(laterCounts[2]).
            """)

        // Two keys in band 2 show the schedule is CHOSEN and not merely reached for, and neither
        // is reachable from the 1910–49 table this file used to hold alone. `51J` is a country
        // number that only the 1960–63 table has; and `611.61` reads as a PAIR only where class 6
        // is the relations class, which it is after the renumbering and is not before it — the
        // pre-1950 table answers "United States" and stops.
        let band2 = glossed(ArchivalEraBand.all[2])
        #expect(band2.contains { $0.id == "751J.00" && $0.gloss == "Laos" }, """
            Country 51J exists in the 1960–63 table and in neither earlier one, so this label \
            cannot be produced by reading the key against the wrong schedule.
            """)
        #expect(band2.contains {
            $0.id == "611.61"
                && $0.gloss == "United States and Union of Soviet Socialist Republics"
        }, """
            Class 6 is Commerce before 1950 and International Political Relations after, and only \
            the later reading takes the suffix as a second country.
            """)
    }

    /// Source with comment LINES removed, so prose about a call is never counted as the call.
    ///
    /// Line-granular on purpose: a full comment parser would need to handle block comments and
    /// string literals containing `//`, and all this scan needs is that a `///` or `//` line
    /// explaining why something is NOT called does not register as calling it.
    private static func codeOnly(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { line in
                let t = line.trimmingCharacters(in: .whitespaces)
                return !t.hasPrefix("//") && !t.hasPrefix("*")
            }
            .joined(separator: "\n")
    }

    @Test("The ranking hands every surface the same gloss, and nothing else looks the table up")
    func rankingCarriesTheGloss() throws {
        // The single injection point. Every surface that draws a class row — chart, uncapped
        // list, CSV, guide card — reaches it through `ranking`, so a row built here carrying both
        // the key and its reading is the whole guarantee.
        let usage = try #require(CollectionUsageIndexStore.shared)
        let url = try #require(Bundle.main.url(forResource: "manifest", withExtension: "json"))
        let entries = try JSONDecoder().decode([VolumeManifestEntry].self,
                                               from: Data(contentsOf: url))
        let rows = ArchivalCollectionsData
            .make(authority: [], usage: usage,
                  coverage: ArchivalVolumeCoverage.map(from: entries))
            .ranking(band: ArchivalEraBand.all[0], lens: .centralFileClasses,
                     weight: .documents, hidingUmbrella: false, limit: .max).rows
        let row = try #require(rows.first { $0.id == "812.6363" })
        #expect(row.gloss == "Mexico — Petroleum")
        #expect(row.label == "812.6363", """
            The key survives beside the reading. A pull slip needs the number, and the gloss is \
            not unique — `.711` and `.731` are both "Laws and regulations".
            """)

        // The other half of "one label source" is a fact about the codebase rather than about a
        // row: nothing outside the derivation may reach the table, or a surface could quietly
        // grow a second, differently-scoped answer.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("FRUSExplorer")
        var callers: [String] = []
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        while let url = files?.nextObject() as? URL {
            guard url.pathExtension == "swift",
                  let text = try? String(contentsOf: url, encoding: .utf8),
                  // The GLOSS specifically, not the store. #834 gave `IndexingPipeline` a second,
                  // unrelated use — `composes(_:)`, the indexing-time schedule check — and this
                  // test is about where the human-readable label is attached, not about who may
                  // touch the table. Widening it to any mention would have let a view attach its
                  // own gloss, which is the thing being prevented.
                  // CODE ONLY, comments stripped. #834's graph node carries a doc comment
                  // explaining why it deliberately does NOT gloss — naming
                  // `gloss(for:coveringYears:)` to say so — which a raw scan counted as a call.
                  // A guard that reads an explanation of an absence as the thing being absent is
                  // the defect this repo keeps re-finding; the sibling scan in
                  // `HandoffVisibilityTests` strips comments for the same reason.
                  Self.codeOnly(text).contains(".gloss(for:")
                      // #1254 gave the subject-numeric table its own composed reading; scanning
                      // for the decimal call alone would have left that one unguarded.
                      || Self.codeOnly(text).contains(".leafGloss(for:"),
                  url.lastPathComponent != "DecimalClassLabelStore.swift",
                  url.lastPathComponent != "SubjectNumericLabelStore.swift"
            else { continue }
            callers.append(url.lastPathComponent)
        }
        // TWO CALL SITES, AND THE SECOND IS THE EXCEPTION THIS GUARD EXISTS TO MAKE VISIBLE.
        //
        // `ArchivalCollectionsData` glosses a key by the coverage of the volumes CITING it, which
        // is right everywhere a row stands for its own evidence. `ArchivesClassAxis` (#1255)
        // deliberately scopes differently: it asks each era's schedule what the key means under
        // THAT schedule, because its whole purpose is to show `POL 24` as SUBVERSION in one
        // section and SANCTIONS in the next. The citing-volume scoping structurally cannot answer
        // that question — it returns one reading per key.
        //
        // So the warning this assertion carried is now realised on purpose rather than avoided,
        // and the mitigation is that the class lens says which scoping it used in its own caption.
        // A THIRD caller still fails here, which is the point: the exception is named, not opened.
        #expect(callers.sorted() == ["ArchivalCollectionsData.swift", "ArchivesClassAxis.swift"], """
            The table is looked up in \(callers.sorted()). Attached in a view instead, every other \
            surface — the CSV especially — would still ship bare numbers, and an unnamed second \
            call site could scope the lookup differently from the first without saying so.
            """)
    }

    @Test("Every surface that shows a gloss also says when it is one of several")
    func disclosureFollowsTheGloss() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("FRUSExplorer")
        var linked: [String] = []
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        while let url = files?.nextObject() as? URL {
            guard url.pathExtension == "swift",
                  let text = try? String(contentsOf: url, encoding: .utf8),
                  Self.codeOnly(text).contains("GlossAlternatesLink(")
            else { continue }
            linked.append(url.lastPathComponent)
        }
        // The two surfaces that print a gloss where a reader can point at it. A third that grew
        // a gloss without the link would ship the tie-break's choice as the answer — which is
        // the whole thing #1257 exists to stop — so this fails rather than widens.
        #expect(linked.sorted() == ["ArchivalAllUnitsSheet.swift", "ArchivesBrowseView.swift"], """
            The link appears in \(linked.sorted()). Adding a gloss to a view without it asserts \
            `11g` is one island.
            """)

        // The chart is the named exception, and it is not an omission: its Y axis carries the
        // bare key, the gloss reaches the reader only through VoiceOver, and a popover cannot
        // hang off a chart mark. So the count goes into the spoken label instead.
        let chart = try String(
            contentsOf: root.appendingPathComponent("Analytics/ArchivalAnalyticsView.swift"),
            encoding: .utf8)
        #expect(chart.contains("archival.gloss.andOthers"))
        #expect(chart.contains("Int64(row.glossAlternates.count)"))
    }

    @Test("The uncapped list and its CSV both carry the gloss")
    func listAndExport() throws {
        let sheet = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("FRUSExplorer/Analytics/ArchivalAllUnitsSheet.swift"),
            encoding: .utf8)
        #expect(sheet.contains("if let gloss = row.gloss"))
        #expect(sheet.contains("[row.label, reading].compactMap { $0 }.joined(separator: \" — \")"), """
            A spreadsheet of bare decimal numbers is the same problem one layer out from the \
            screen.
            """)
        // And the CSV says when a name is one of several claimants. On screen that disclosure is
        // a popover, which an export cannot carry — so it is written out as a count, and a reader
        // who has only the spreadsheet still knows the name is not the whole answer.
        #expect(sheet.contains("archival.export.andOthers"), """
            The `and N others` link is the ONLY thing telling a reader that `11g` covers three \
            islands. Dropped from the export, the CSV asserts a single name the screen refuses to.
            """)
        #expect(sheet.contains("Int64(row.glossAlternates.count)"), """
            The count must come from the row's OWN alternates. Formatting a constant, or the \
            popover's list length, would put a number in the cell that no longer describes it.
            """)
    }

    // MARK: - The era contract as an OUTSIDE consumer sees it (#1204)

    /// The artifact's raw JSON, decoded the way a non-Swift consumer reads it.
    ///
    /// Deliberately NOT `DecimalClassLabelTable`: the app's decoder does not carry `coverage`, and
    /// the whole point of #1204 is what a consumer holding only the file can know. Reading it
    /// through the app's model would test the app, which was never the defect.
    private func rawArtifact() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/Resources/decimal-class-labels.json")
        let object = try JSONSerialization.jsonObject(with: try Data(contentsOf: url))
        return try #require(object as? [String: Any])
    }

    /// A hand composer that reads ONLY the JSON — the failing behaviour #1204 reports.
    ///
    /// This is the commercial-diplomacy run's move reproduced exactly: take `schedules[0]`, split
    /// the key, look the class digit up in `classes` and the rest in `countries`, and join them.
    /// It applies no era rule, because the artifact used to state none it could apply.
    private func composeIgnoringEra(_ key: String, _ artifact: [String: Any],
                                    scheduleId: String? = nil) -> String? {
        guard let schedules = artifact["schedules"] as? [[String: Any]] else { return nil }
        let match = schedules.first { schedule in
            guard let scheduleId else { return true }
            return schedule["id"] as? String == scheduleId
        }
        guard let table = match,
              let classes = table["classes"] as? [String: String],
              let countries = table["countries"] as? [String: String] else { return nil }
        let parts = key.split(separator: ".")
        let stem = parts.first.map(String.init) ?? key
        guard let digit = stem.first, let className = classes[String(digit)] else { return nil }
        let rest = stem.dropFirst().lowercased()
        var country: String?
        for length in [3, 2] where rest.count >= length && country == nil {
            country = countries[String(rest.prefix(length))]
        }
        guard let country else { return nil }
        // The suffix read as a SECOND country — the relations idiom the guide demonstrates with
        // `611.41: U.S.-U.K. relations`. A naive composer applies it wherever the suffix happens
        // to match a country number, which is how `.48` becomes "British Africa"; the schedule
        // itself reserves that reading for `relationsClasses` (class 7 alone), but nothing in the
        // file stops a consumer from taking it, and #1204's report is that one did.
        if parts.count > 1, let second = countries[parts[1].lowercased()] {
            return "\(className) — \(country) and \(second)"
        }
        return "\(className) — \(country)"
    }

    /// The same composer, now applying what `coverage` states. This is the fix, exercised.
    private func composeUnderContract(_ key: String, year: Int,
                                      _ artifact: [String: Any]) -> String? {
        guard let coverage = artifact["coverage"] as? [String: Any],
              let spans = coverage["glossableYears"] as? [[String: Any]] else { return nil }
        // The contract is a date-to-table LOOKUP, not a date filter, which is why every span
        // carries a `scheduleId`. While the file held one schedule the two were the same thing.
        // They are not now: a consumer that gates on the year and then reads `schedules.first`
        // satisfies every in-span/out-of-span assertion and still answers a 1958 document out
        // of the pre-1950 country table, where 48 is British Africa rather than Poland.
        let governing = spans.first { span in
            guard let lo = span["startYear"] as? Int, let hi = span["endYear"] as? Int
            else { return false }
            return year >= lo && year <= hi
        }
        guard let scheduleId = governing?["scheduleId"] as? String else { return nil }
        return composeIgnoringEra(key, artifact, scheduleId: scheduleId)
    }

    /// The defect is real and reachable from the file alone — then the contract stops it.
    ///
    /// The FIRST expectation is the one that makes this test mean anything. #1204's own wording
    /// ("composing 411.48 with a 1958 date returns no gloss") is satisfied by the app **today**,
    /// with no fix: `gloss(for:coveringYears:)` refuses class 4 outright because it is not
    /// country-arranged under the 1910–49 schedule. A test written that way passes against the
    /// unfixed artifact and proves nothing. So this drives a hand composer instead — the actual
    /// failing consumer — and shows the wrong answer exists before showing it gone.
    ///
    /// ## What the contract means now that three schedules ship
    /// #1204 was written against a one-schedule file, where the contract could only be a date
    /// FILTER: in span, or no gloss. With 1950–59 and 1960–63 beside the original it is a
    /// date-to-table LOOKUP, and `411.48` is the key that shows the difference — country 48 is
    /// **British Africa** before the 1950 renumbering and **Poland** after it. A consumer that
    /// kept the filter reading passes #1204's own assertion for 1935, and hands a 1958 document
    /// a wrong country. The out-of-span case did not disappear; it moved to 1968, where the
    /// decimal file itself had been replaced by the subject-numeric system.
    @Test("A consumer composing straight from the file gets a wrong reading; the era contract withholds it")
    func eraContractStopsTheWrongGloss() throws {
        let artifact = try rawArtifact()

        // The hazard, demonstrated. If this ever returns nil the rest of the test is vacuous.
        let ungated = composeIgnoringEra("411.48", artifact)
        #expect(ungated == "Claims — United States and British Africa", """
            The wrong reading must still be reachable by ignoring the era, or this test would \
            pass against an artifact that had simply lost its class or country table. Got: \
            \(ungated ?? "nil")
            """)

        // Inside the first schedule's span the same key still composes, unchanged.
        #expect(composeUnderContract("411.48", year: 1935, artifact)
                    == "Claims — United States and British Africa",
                "the contract must gate on the year, not suppress the vocabulary")

        // 1958 is glossable and disagrees. This is the assertion the old filter reading could
        // not make: it is not that the key is withheld, but that it reads out of a different
        // table, and the difference is a country name a reader would take at face value.
        let inFiftyEight = composeUnderContract("411.48", year: 1958, artifact)
        #expect(inFiftyEight?.hasSuffix("United States and Poland") == true, """
            Country 48 is Poland from 1950. A consumer gating on the year and then reading \
            `schedules.first` answers "British Africa" here and looks correct. Got: \
            \(inFiftyEight ?? "nil")
            """)
        #expect(inFiftyEight != ungated, """
            The whole point of publishing `scheduleId` beside each span is that the two readings \
            differ. If they ever coincide this test has stopped exercising the lookup.
            """)

        // And outside every schedule there is still no gloss at all, at both ends.
        #expect(composeUnderContract("411.48", year: 1968, artifact) == nil, """
            The decimal file closes in 1963 — a 1968 document was filed under the \
            subject-numeric system, and no table here speaks for it.
            """)
        #expect(composeUnderContract("411.48", year: 1905, artifact) == nil,
                "the decimal file opens in 1910; nothing before it can be composed")
    }

    /// `coverage` must describe the schedules actually shipped, not a remembered list.
    @Test("The stated glossable years are exactly the shipped schedules' spans")
    func coverageMatchesTheShippedSchedules() throws {
        let artifact = try rawArtifact()
        let coverage = try #require(artifact["coverage"] as? [String: Any])
        let schedules = try #require(artifact["schedules"] as? [[String: Any]])
        let spans = try #require(coverage["glossableYears"] as? [[String: Any]])

        #expect(artifact["schemaVersion"] as? Int == 2, "the coverage block is schema 2")
        #expect(coverage["keyOutsideGlossableYears"] as? String == "no-gloss", """
            The verdict is stated in a word so a consumer need not infer it. Changing the \
            spelling silently breaks every consumer branching on it.
            """)
        #expect(coverage["renumberedAt"] as? Int == 1950)

        // The clamp, published so a SPAN-gating consumer reproduces the app instead of
        // undercounting it. `gloss(for:coveringYears:)` takes `floor` as the earliest schedule's
        // start and tests `max(span.lowerBound, floor) >= startYear`, so the app DOES gloss a
        // volume covering 1861–1947; a consumer applying literal containment to `glossableYears`
        // refuses that volume, and the two then disagree about the era #828 exists for.
        let opensIn = try #require(coverage["decimalFileOpensIn"] as? Int)
        let earliest = try #require(schedules.compactMap { $0["startYear"] as? Int }.min())
        #expect(opensIn == earliest, """
            The published clamp must BE the app's floor, which is the earliest schedule's start \
            year — a constant that drifted from it would send a consumer somewhere the app does \
            not go.
            """)

        #expect(spans.count == schedules.count, """
            A schedule that shipped without a matching span would be glossable in fact and \
            ungovernable by the contract — the exact drift this block exists to prevent.
            """)
        for (span, schedule) in zip(spans, schedules) {
            #expect(span["scheduleId"] as? String == schedule["id"] as? String)
            #expect(span["startYear"] as? Int == schedule["startYear"] as? Int)
            #expect(span["endYear"] as? Int == schedule["endYear"] as? Int)
        }
    }

    /// The subject-numeric keys reach a label through the same single injection point, and read
    /// out of the edition that governs them.
    ///
    /// These keys are not a fringe of the class lens — measured, they are 1,362 leaves folding to
    /// 323 groups over 6,882 documents, and they dominate its later era bands — and every one of
    /// them rendered bare before #1211, because `DecimalClassLabelStore.gloss` refuses a key that
    /// opens with letters at two separate guards.
    @Test("A subject-numeric key reads out of the edition that governs it")
    func subjectNumericKeysReadFromTheirOwnEdition() throws {
        let table = try #require(SubjectNumericLabelStore.shared)

        // THE CASE THAT FORCES TWO SCHEDULES. The 1965 arrangement reused this designator for a
        // different subject and moved subversion to POL 23-7. POL carries about two thirds of the
        // corpus's subject-numeric documents, so a single merged table would mislabel the
        // most-cited category in the vocabulary.
        #expect(table.gloss(for: "POL 24", coveringYears: 1963...1963)
                    == "SUBVERSION. ESPIONAGE. SABOTAGE.")
        #expect(table.gloss(for: "POL 24", coveringYears: 1965...1968) == "SANCTIONS")

        // A span crossing the renumbering says nothing, exactly as the decimal table does across
        // 1950 — and this is the assertion that would fail first if the two schedules were ever
        // merged for coverage.
        #expect(table.gloss(for: "POL 24", coveringYears: 1963...1966) == nil, """
            1963 and 1964–1973 disagree about this designator, so a span holding both can only be \
            guessed at.
            """)

        // Outside the system entirely: the subject-numeric file opens in 1963 and these schedules
        // end in 1973.
        #expect(table.gloss(for: "POL 24", coveringYears: 1950...1955) == nil)
        #expect(table.gloss(for: "POL 24", coveringYears: 1975...1980) == nil)

        // The tail is NOT read, and a key carrying one still resolves to its group's subject —
        // the surface is what must print the rest, and the coverage note says so.
        #expect(table.gloss(for: "POL 27 VIET S", coveringYears: 1963...1963)
                    == "MILITARY OPERATIONS")
        #expect(table.coverage.note.contains("VIET S"), """
            The 90.4% of keys carrying a country tail is the caveat every surface owes a reader; \
            dropping it from the note would let a screen look complete while naming half the key.
            """)

        // AN ORGANIZATION FILE IS NOT A PRIMARY SUBJECT. `UN` has no outline in either handbook;
        // its file is arranged by the international-organizations instruction's list, under the
        // name the abbreviations appendix gives the prefix. Measured, reading that list lifted the
        // 1963 schedule from 5,727 to 6,091 of the corpus's 6,882 subject-numeric documents.
        #expect(table.gloss(for: "UN 6 CHICOM", coveringYears: 1963...1963)
                    == "United Nations — MEMBERSHIP. ASSOCIATION.")

        // AND THE GUARD ON IT. The list would fit these too, and both are real keys in the corpus:
        // `PSL 27 VIET S` is a one-character corruption of POL, and `NSSD 05-82` is a National
        // Security Study Directive, not a central-file class at all. Neither prefix is in the
        // handbook's abbreviations appendix, which is what refuses them.
        #expect(table.gloss(for: "PSL 27 VIET S", coveringYears: 1963...1963) == nil, """
            Without the appendix check this reads as whatever the administrative-subject list has \
            at 27, and looks like a finding rather than a corrupted key.
            """)
        #expect(table.gloss(for: "NSSD 05-82", coveringYears: 1963...1963) == nil)

        // A designator the outline carries and the list also carries must come from the OUTLINE.
        // `POL 6` is People. Biographic Data.; the list's 6 is Membership. Association.
        #expect(table.gloss(for: "POL 6", coveringYears: 1963...1963)?
                    .contains("Membership") == false)

        // THE COUNTRY ELEMENT, COMPOSED IN NARA'S FILING ORDER. A citation writes class, number,
        // country — `POL 27 VIET S` — while NARA files the records class, then country, then
        // number. The label follows the FILING, which is also the shape the decimal table's own
        // glosses take (`Mexico — Petroleum`), because there the two orders coincide.
        #expect(table.leafGloss(for: "POL 27 VIET S", coveringYears: 1963...1963)
                    == "Vietnam, South — MILITARY OPERATIONS")
        // The two spellings of one country read the same: the handbook prints `S VIET` and the
        // corpus writes `VIET S`, and 830 documents ride on them agreeing.
        #expect(table.leafGloss(for: "POL 27 S VIET", coveringYears: 1963...1963)
                    == table.leafGloss(for: "POL 27 VIET S", coveringYears: 1963...1963))
        // A key with no country element is not an omission — the handbooks keep general files for
        // each primary subject — so it reads as its subject alone.
        #expect(table.leafGloss(for: "POL 27", coveringYears: 1963...1963) == "MILITARY OPERATIONS")
        // And an organization file names the organization first, which is its filing level.
        #expect(table.leafGloss(for: "UN 6", coveringYears: 1963...1963)
                    == "United Nations — MEMBERSHIP. ASSOCIATION.")

        // And the injection point: the ranking hands the same reading to every surface that draws
        // a class row, which is what keeps one label source honest across two filing systems.
        let usage = try #require(CollectionUsageIndexStore.shared)
        let url = try #require(Bundle.main.url(forResource: "manifest", withExtension: "json"))
        let entries = try JSONDecoder().decode([VolumeManifestEntry].self,
                                               from: Data(contentsOf: url))
        let data = ArchivalCollectionsData.make(
            authority: [], usage: usage,
            coverage: ArchivalVolumeCoverage.map(from: entries))
        let rows = data.ranking(band: ArchivalEraBand.all[3], lens: .centralFileClasses,
                                weight: .documents, hidingUmbrella: false, limit: .max).rows
        #expect(rows.contains { CollectionKeying.isSubjectNumericClass($0.id) && $0.gloss != nil },
                "band 3's labelled rows are subject-numeric and must arrive through the ranking")
    }


    /// Each schedule ships the layers its manual was read well enough to state — and no others.
    ///
    /// The three schedules do NOT carry the same fields, and that asymmetry is deliberate. Both
    /// post-1950 handbooks also print an alphabetical INDEX pairing a subject name with a class
    /// reference (`Silk 8**.355`), which the subdivision-tree parser reads backwards: measured,
    /// 399 of 507 entries for 1950–59 and 205 of 311 for 1960–63 came out carrying a stray class
    /// reference, and `795.00` glossed as *Korea — Amusements 8\*\*.45*. The layer is refused
    /// wholesale rather than shipped mislabelling.
    ///
    /// This is worth a test of its own because the refusal is INVISIBLE at every other surface: a
    /// key with no subject reading falls back to its country, which is a correct answer, so a
    /// regression that started shipping the index would show up as *better* coverage.
    @Test("The post-1950 schedules ship a class and country table and no subject table")
    func postWarSchedulesWithholdTheirSubjectLayer() throws {
        let artifact = try rawArtifact()
        let schedules = try #require(artifact["schedules"] as? [[String: Any]])
        #expect(schedules.count == 3, "1910–49, 1950–59, 1960–63")

        for schedule in schedules {
            let id = schedule["id"] as? String
            let subjects = try #require(schedule["subjects"] as? [String: [String: String]])
            let classes = try #require(schedule["classes"] as? [String: String])
            let countries = try #require(schedule["countries"] as? [String: String])
            let suffixes = subjects.values.reduce(0) { $0 + $1.count }

            // Every schedule states its classes and its countries, or it would not have shipped.
            #expect(classes.count >= 9, "\(id ?? "?") classes: \(classes.count)")
            #expect(countries.count >= 100, "\(id ?? "?") countries: \(countries.count)")

            if id == "1910-1949" {
                #expect(suffixes == 693, """
                    The subdivision tree the 1910–49 manual prints, unchanged by #1210. A drop \
                    here means the shared parse regressed while adding the later manuals.
                    """)
            } else {
                #expect(suffixes == 0, """
                    \(id ?? "?") must ship no subject suffixes. Non-zero means the alphabetical \
                    index is being read as a subdivision table again, and the damage reads as a \
                    plausible gloss: Korea — Amusements 8**.45.
                    """)
            }
        }
    }

    /// Every year of the decimal file is either glossable or a recorded gap, and a gap carries
    /// the measurement that refused it.
    ///
    /// An omission that met every floor would be a schedule wrongly withheld, so the assertion is
    /// on the shortfall rather than on the presence of the row: recording the numbers is only
    /// worth anything if they actually explain the refusal.
    ///
    /// ## `notShipped` is empty today, and that is the claim being made
    /// It carried two rows while the 1950–59 and 1960–63 class tables were parsed short. Both are
    /// now read — the 1950–59 one off page geometry, because its `CLASSES OF RECORDS` block
    /// flattens two columns into unreadable text — so the refusal has nothing left to record. The
    /// test asserts the STRONGER thing an empty list has to earn: the shipped spans, on their
    /// own, tile 1910 through 1963 with no gap. An empty list beside an untiled span would be the
    /// silence #1204 is about, and only the tiling check can tell the two apart.
    @Test("Every year of the decimal file is glossable or a recorded gap, and a gap states its shortfall")
    func notShippedIsMeasuredAndComplete() throws {
        let artifact = try rawArtifact()
        let coverage = try #require(artifact["coverage"] as? [String: Any])
        let omissions = try #require(coverage["notShipped"] as? [[String: Any]])

        for omission in omissions {
            let parsed = try #require(omission["parsed"] as? [String: Int])
            let floors = try #require(omission["floors"] as? [String: Int])
            let short = ["classes", "subjects", "countries"].filter { axis in
                (parsed[axis] ?? 0) < (floors[axis] ?? 0)
            }
            // The shortfall is on CLASSES ALONE, and saying so is what makes the two numbers
            // legible. A mutation sweep transposed `parsed` and `floors` and a bare
            // "some axis falls short" assertion passed on the transposed data — countries read
            // 100 against 200 and subjects 20 against 507, so the row still looked refused while
            // every figure in it was the wrong way round.
            #expect(short == ["classes"], """
                \(omission["scheduleId"] ?? "?") must be refused on its class table and nothing \
                else — the country and subject tables clear their floors. Short on: \(short)
                """)
            // The floors are declared constants, identical for both refused schedules; the parsed
            // counts are this build's measurement and differ. Pinning both ways round is what
            // distinguishes them, because a transposition preserves neither.
            #expect(floors == ["classes": 10, "subjects": 20, "countries": 100],
                    "the declared floors moved — update the measurement, not just the assertion")
            #expect((parsed["classes"] ?? 0) < 10)
            #expect((parsed["subjects"] ?? 0) >= 20 && (parsed["countries"] ?? 0) >= 100,
                    "the non-class tables must still be the ones that pass, or the reason is stale")
            #expect((omission["reason"] as? String)?.isEmpty == false)
        }

        // Nothing between 1910 and 1963 is silently unaccounted for: every year is either
        // glossable or named as a gap. A year in neither list is the case a consumer cannot
        // reason about at all.
        let spans = try #require(coverage["glossableYears"] as? [[String: Any]])
        func span(_ row: [String: Any]) -> ClosedRange<Int>? {
            guard let lo = row["startYear"] as? Int, let hi = row["endYear"] as? Int, lo <= hi
            else { return nil }
            return lo...hi
        }
        func covered(_ year: Int) -> Bool {
            (spans + omissions).contains { span($0)?.contains(year) == true }
        }
        let uncovered = (1910...1963).filter { !covered($0) }
        #expect(uncovered.isEmpty, "years accounted for by neither a schedule nor a gap: \(uncovered)")

        // The stronger claim an empty `notShipped` has to earn. Without this the two states an
        // empty list can describe — nothing left to refuse, and the refusal stopped being
        // recorded — are indistinguishable from the file.
        if omissions.isEmpty {
            let glossable = (1910...1963).filter { year in
                spans.contains { span($0)?.contains(year) == true }
            }
            #expect(glossable.count == 54, """
                Nothing is refused, so the shipped schedules must themselves cover 1910–1963 \
                end to end. Covered years: \(glossable.count) of 54.
                """)
        }
    }
}
