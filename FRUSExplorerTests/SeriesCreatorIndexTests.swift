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

// MARK: - SeriesCreatorIndexTests

/// The bundled naId → creating body projection, as the app reads it (#405).
///
/// Version history:
///   1.0 — Session 2026-08-10: #405 (F-6)
@Suite("Series creator index (#405)")
struct SeriesCreatorIndexTests {

    private func index(headings: [String],
                       rows: [String: SeriesCreatorIndex.Entry]) -> SeriesCreatorIndex {
        SeriesCreatorIndex(schemaVersion: 1, generated: "2026-08-10",
                           headings: headings, byNaId: rows)
    }

    @Test("A covered series names its creator")
    func resolvesACreator() {
        let i = index(headings: ["Department of State. Bureau of Far Eastern Affairs.",
                                 "Department of State. Office of the Secretary."],
                      rows: ["12345": .init(creator: 1, predecessors: nil)])
        #expect(i.creator(forNaId: "12345") == "Department of State. Office of the Secretary.")
    }

    @Test("An uncovered NAID is 'not stated', not an error")
    func uncoveredIsNil() {
        // Coverage is a fraction by construction: NARA carries `creators` only on the series
        // layer, so every file unit — every numerical-file roll — resolves to nothing here. A
        // caller must never read nil as "this series had no creator".
        let i = index(headings: ["A."], rows: ["1": .init(creator: 0, predecessors: nil)])
        #expect(i.creator(forNaId: "999") == nil)
        #expect(i.predecessors(forNaId: "999").isEmpty)
    }

    @Test("An out-of-range index yields nil rather than trapping")
    func corruptIndexDoesNotTrap() {
        // The artifact is generated, but it is also hand-editable and ships in the bundle. An
        // index past the end must degrade, not crash a research session.
        let i = index(headings: ["A."], rows: ["1": .init(creator: 7, predecessors: [9])])
        #expect(i.creator(forNaId: "1") == nil)
        #expect(i.predecessors(forNaId: "1").isEmpty)
    }

    @Test("Predecessors are carried but are not the creator")
    func predecessorsAreSeparate() {
        let i = index(headings: ["Now.", "Before."],
                      rows: ["1": .init(creator: 0, predecessors: [1])])
        #expect(i.creator(forNaId: "1") == "Now.")
        #expect(i.predecessors(forNaId: "1") == ["Before."])
    }

    @Test("The shipped artifact decodes and covers the measured population")
    func shippedArtifactDecodes() throws {
        let index = try #require(SeriesCreatorIndexStore.shared, """
            series-creator-index.json failed to load from the app bundle. If this is a fresh \
            resource, it needs `xcodegen generate` + the scheme restore to be enrolled.
            """)
        #expect(index.schemaVersion == 1)
        #expect(index.byNaId.count >= 600, "series with a creator: \(index.byNaId.count)")
        #expect(index.headings.count >= 340)
        // The largest single creator among app-held series, measured 2026-08-10 on 57 of them.
        #expect(index.headings.contains("Department of State. Office of the Secretary. Executive Secretariat."))
        // No heading may still carry NARA's lifespan tail — that is the display contract.
        #expect(!index.headings.contains { $0.hasSuffix(")") && $0.contains("19") },
                "a heading kept its date tail")
    }
}

// MARK: - SeriesCreatorGuardTests

/// The three guards that keep a true fact off the wrong record (#405).
///
/// Version history:
///   1.0 — Session 2026-08-10: #405 (F-6)
@Suite("Series creator guards (#405)")
struct SeriesCreatorGuardTests {

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
        let index = try #require(SeriesCreatorIndexStore.shared)
        let coveredNaId = try #require(index.byNaId.keys.sorted().first)
        // Same NAID, two levels. The series form may resolve; the file-unit form must not,
        // because a file unit borrows its series title from its parent and would borrow the
        // parent's creator the same way — presented as the cited record's own.
        #expect(SeriesCreatorIndex.creatorName(for: entry(naId: coveredNaId, level: "fileUnit")) == nil)
        #expect(SeriesCreatorIndex.creatorName(for: entry(naId: coveredNaId, level: "series")) != nil,
                "the series form of a covered NAID must resolve, or this test proves nothing")
    }

    @Test("An uncovered series simply has no creator line")
    func uncoveredSeries() {
        #expect(SeriesCreatorIndex.creatorName(for: entry(naId: "999999999", level: "series")) == nil)
    }
}
