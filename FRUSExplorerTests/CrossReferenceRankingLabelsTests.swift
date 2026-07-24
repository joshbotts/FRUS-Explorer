// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
@testable import FRUSExplorer

// MARK: - CrossReferenceRankingLabelsTests

/// Tests `disambiguatedRankingLabels`, the shared helper behind the #275 ranking-chart fix: bars
/// are keyed on each row's unique id (so distinct documents/people sharing a display name no longer
/// merge into one summed bar), and this helper maps each id back to a human y-axis label,
/// appending a short suffix only when a name is shared — and guaranteeing no two labels collide.
struct CrossReferenceRankingLabelsTests {

    /// Unique names are rendered verbatim — no suffix clutters the common case.
    @Test("Unique names are left untouched")
    func uniqueNamesUnchanged() {
        let rows = [
            (id: "frus1945Berlinv02/d1383", name: "Protocol of the Proceedings of the Berlin Conference", shortSuffix: "d1383"),
            (id: "frus1890/d266", name: "Sir Julian Pauncefote to Mr. Blaine", shortSuffix: "d266"),
            (id: "frus1946v04/d63", name: "Report of the Economic Commission for Italy", shortSuffix: "d63")
        ]
        let labels = disambiguatedRankingLabels(rows)
        #expect(labels["frus1945Berlinv02/d1383"] == "Protocol of the Proceedings of the Berlin Conference")
        #expect(labels["frus1890/d266"] == "Sir Julian Pauncefote to Mr. Blaine")
        #expect(labels["frus1946v04/d63"] == "Report of the Economic Commission for Italy")
    }

    /// The exact regression: four "Department of State Minutes" documents and two "Mr. Adams to
    /// Mr. Seward" documents each get their document id appended so their bars are distinguishable,
    /// while the unique titles in the same ranking stay clean.
    @Test("Shared names are disambiguated by short suffix; unique ones stay clean")
    func sharedNamesDisambiguated() {
        let rows = [
            (id: "frus1945Berlinv02/d1383", name: "Protocol of the Proceedings of the Berlin Conference", shortSuffix: "d1383"),
            (id: "frus1864p1/d147", name: "Mr. Adams to Mr. Seward", shortSuffix: "d147"),
            (id: "frus1945Berlinv02/d710a-150", name: "Department of State Minutes", shortSuffix: "d710a-150"),
            (id: "frus1945Berlinv02/d710a-138", name: "Department of State Minutes", shortSuffix: "d710a-138"),
            (id: "frus1945Berlinv02/d710a-164", name: "Department of State Minutes", shortSuffix: "d710a-164"),
            (id: "frus1945Berlinv02/d710a-85", name: "Department of State Minutes", shortSuffix: "d710a-85"),
            (id: "frus1864p1/d88", name: "Mr. Adams to Mr. Seward", shortSuffix: "d88")
        ]
        let labels = disambiguatedRankingLabels(rows)

        // Every row is represented — no id is dropped (the pre-fix bug collapsed rows).
        #expect(labels.count == rows.count)

        // The unique title is verbatim.
        #expect(labels["frus1945Berlinv02/d1383"] == "Protocol of the Proceedings of the Berlin Conference")

        // The four Department of State Minutes are each suffixed with their document id and distinct.
        let deptLabels = [
            labels["frus1945Berlinv02/d710a-150"],
            labels["frus1945Berlinv02/d710a-138"],
            labels["frus1945Berlinv02/d710a-164"],
            labels["frus1945Berlinv02/d710a-85"]
        ]
        #expect(deptLabels.allSatisfy { $0?.hasPrefix("Department of State Minutes · ") == true })
        #expect(Set(deptLabels.compactMap { $0 }).count == 4)
        #expect(labels["frus1945Berlinv02/d710a-150"] == "Department of State Minutes · d710a-150")

        // Both Adams-to-Seward documents are suffixed and distinct.
        #expect(labels["frus1864p1/d147"] == "Mr. Adams to Mr. Seward · d147")
        #expect(labels["frus1864p1/d88"] == "Mr. Adams to Mr. Seward · d88")
    }

    /// When two rows share BOTH the name AND the short suffix (same title + same document id in
    /// different volumes), the helper falls back to the unique id so no two labels collide.
    @Test("Colliding name+suffix falls back to the unique id")
    func nameAndSuffixCollisionFallsBackToID() {
        let rows = [
            (id: "frus1958v10/d5", name: "Editorial Note", shortSuffix: "d5"),
            (id: "frus1969v01/d5", name: "Editorial Note", shortSuffix: "d5")
        ]
        let labels = disambiguatedRankingLabels(rows)
        #expect(labels.count == 2)
        // Both labels are distinct (no identical axis text), achieved via the unique id fallback.
        #expect(Set(labels.values).count == 2)
        #expect(labels["frus1958v10/d5"] == "Editorial Note · frus1958v10/d5")
        #expect(labels["frus1969v01/d5"] == "Editorial Note · frus1969v01/d5")
    }

    /// An empty ranking yields an empty map (no crash on the no-data path).
    @Test("Empty input yields empty output")
    func emptyInput() {
        let labels = disambiguatedRankingLabels([])
        #expect(labels.isEmpty)
    }
}

// MARK: - MatrixColumnCodeTests

/// Tests `matrixColumnCodes`, the Win-8 helper behind the cross-volume heat matrix's horizontal
/// column axis: each column renders a compact, collision-free code — coverage span + Roman numeral
/// (verbatim from the manifest title), a topic word when there is no numeral, escalating to a
/// guaranteed-unique id suffix when two columns would otherwise collide.
struct MatrixColumnCodeTests {

    /// A modern numbered volume: span + the Roman numeral taken verbatim from the title.
    @Test("Span plus verbatim Roman numeral")
    func spanPlusNumeral() {
        let codes = matrixColumnCodes([
            (id: "frus1955-57v2", subseries: "1955-57",
             title: "Foreign Relations of the United States, 1955–1957, China, Volume II",
             topic: "China")
        ])
        #expect(codes["frus1955-57v2"] == "'55–57 II")
    }

    /// A multi-letter numeral in a title that also carries a topic and trailing dates.
    @Test("Multi-letter numeral, dates ignored")
    func multiLetterNumeral() {
        let codes = matrixColumnCodes([
            (id: "frus1961-63v14", subseries: "1961-63",
             title: "Foreign Relations of the United States, 1961–1963, Volume XIV, Berlin Crisis, 1961–1962",
             topic: "Berlin Crisis")
        ])
        #expect(codes["frus1961-63v14"] == "'61–63 XIV")
    }

    /// A single-year annual volume with no numeral and no topic reduces to just the year.
    @Test("Single year, no numeral, no topic")
    func singleYearBare() {
        let codes = matrixColumnCodes([
            (id: "frus1861", subseries: "1861",
             title: "Papers Relating to Foreign Affairs, 1861", topic: "")
        ])
        #expect(codes["frus1861"] == "'61")
    }

    /// No "Volume N" numeral but a topic → span + the first distinctive word, truncated to ≤6 chars.
    @Test("No numeral falls back to a truncated topic word")
    func noNumeralTopicWord() {
        let codes = matrixColumnCodes([
            (id: "frusX", subseries: "1958-60",
             title: "Some Compilation Without A Volume Numeral", topic: "Western Europe")
        ])
        #expect(codes["frusX"] == "'58–60 Wester")
    }

    /// A leading article/preposition is skipped so the chosen word is distinctive.
    @Test("Leading stopword is dropped for the topic word")
    func leadingStopwordDropped() {
        let codes = matrixColumnCodes([
            (id: "frusY", subseries: "1948",
             title: "An Annual Compilation", topic: "The Far East")
        ])
        #expect(codes["frusY"] == "'48 Far")
    }

    /// Two Part-only annual volumes of the same year (no numeral, no topic) collide on the bare year
    /// and are separated by the guaranteed-unique id suffix.
    @Test("Colliding Part volumes fall back to the id suffix")
    func collidingPartsUseIdSuffix() {
        let codes = matrixColumnCodes([
            (id: "frus1863p1", subseries: "1863",
             title: "Papers Relating to Foreign Affairs, 1863, Part I", topic: ""),
            (id: "frus1863p2", subseries: "1863",
             title: "Papers Relating to Foreign Affairs, 1863, Part II", topic: "")
        ])
        // Distinct, both year-prefixed, disambiguated by the id suffix.
        #expect(codes["frus1863p1"] == "'63 p1")
        #expect(codes["frus1863p2"] == "'63 p2")
        #expect(Set(codes.values).count == 2)
    }

    /// Two no-numeral volumes whose first topic words share the same ≤6-char prefix are separated by
    /// appending the second topic word (each ≤6 chars, so codes stay column-narrow).
    @Test("Colliding topic-word codes expand to the next word")
    func collidingTopicWordsExpand() {
        let codes = matrixColumnCodes([
            (id: "frusA", subseries: "1958-60", title: "Compilation A", topic: "Western Europe"),
            (id: "frusB", subseries: "1958-60", title: "Compilation B", topic: "Western Hemisphere")
        ])
        #expect(codes["frusA"] == "'58–60 Wester Europe")
        #expect(codes["frusB"] == "'58–60 Wester Hemisp")
        #expect(Set(codes.values).count == 2)
    }

    /// Two same-subseries volumes reusing the same Roman numeral (the 1945 conference cluster) collide
    /// on "span + numeral" and are separated by appending the first topic word (≤6 chars).
    @Test("Colliding numerals expand with the first topic word")
    func collidingNumeralsExpand() {
        let codes = matrixColumnCodes([
            (id: "frus1945Berlinv02", subseries: "1945",
             title: "Foreign Relations of the United States, 1945, The Conference of Berlin (Potsdam), Volume II",
             topic: "Conference of Berlin Potsdam"),
            (id: "frus1945v02", subseries: "1945",
             title: "Foreign Relations of the United States, 1945, General: Political and Economic Matters, Volume II",
             topic: "General Political and Economic Matters")
        ])
        #expect(codes["frus1945Berlinv02"] == "'45 II Confer")
        #expect(codes["frus1945v02"] == "'45 II Genera")
        #expect(Set(codes.values).count == 2)
    }

    /// A combined-volume title captures the first Roman run only.
    @Test("Combined volume takes the first Roman run")
    func combinedVolumeFirstRun() {
        let codes = matrixColumnCodes([
            (id: "frus1952-54v2", subseries: "1952-54",
             title: "Foreign Relations of the United States, 1952–1954, National Security Affairs, Volume II, Part 1",
             topic: "National Security Affairs")
        ])
        #expect(codes["frus1952-54v2"] == "'52–54 II")
    }

    /// An empty column set yields an empty map (no crash on the no-data path).
    @Test("Empty input yields empty output")
    func emptyInput() {
        #expect(matrixColumnCodes([]).isEmpty)
    }
}
