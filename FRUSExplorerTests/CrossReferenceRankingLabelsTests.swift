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
