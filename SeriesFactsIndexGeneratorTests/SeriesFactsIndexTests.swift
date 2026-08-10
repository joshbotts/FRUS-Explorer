// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import SeriesFactsIndexGeneratorCore
import LotClaimantsIndexGeneratorCore

// MARK: - DisplayHeadingTests

/// Stripping NARA's trailing lifespan from a creator heading (#405).
///
/// Version history:
///   1.0 — Session 2026-08-10: #405 (F-6)
@Suite("Creator heading display form (#405)")
struct DisplayHeadingTests {

    @Test("The body's own lifespan is removed")
    func stripsTheDateTail() {
        // The dates describe the creating BODY, not the records. Left in place they sit beside
        // the series' own date range and read as a contradiction.
        let cases: [(String, String)] = [
            ("War Trade Board. (10/12/1917 - 06/30/1919)", "War Trade Board."),
            ("Department of State. Office of the Secretary. Executive Secretariat. (1789 - )",
             "Department of State. Office of the Secretary. Executive Secretariat."),
            ("Department of State. Bureau of European Affairs. (09/1949 - 10/03/1983)",
             "Department of State. Bureau of European Affairs."),
        ]
        for (raw, expected) in cases {
            #expect(SeriesFactsIndexRunner.displayHeading(raw) == expected,
                    "\(raw) → \(SeriesFactsIndexRunner.displayHeading(raw))")
        }
    }

    @Test("NARA's ca./? forms are still lifespans and are stripped")
    func stripsApproximateDates() {
        // A digits-and-dashes-only rule looked tidier and left 106 of the 369 real headings with
        // their tail attached, because NARA hedges its dates.
        for (raw, expected) in [
            ("Department of State. Bureau of Administration. Management Staff. (1958 - ca. 1961)",
             "Department of State. Bureau of Administration. Management Staff."),
            ("Department of State. Office of the Staff Director. (1969 - 1974 ?)",
             "Department of State. Office of the Staff Director."),
        ] {
            #expect(SeriesFactsIndexRunner.displayHeading(raw) == expected,
                    "\(raw) → \(SeriesFactsIndexRunner.displayHeading(raw))")
        }
    }

    @Test("An identity parenthetical is kept, even though it carries years")
    func keepsIdentityParentheticals() {
        // NARA's ` : ` form names WHICH body, not when it existed. It does not occur at the end of
        // a heading in today's corpus — the presidential form sits mid-heading, out of an
        // end-anchored pattern's reach — so this is a guard against a future harvest, and it is
        // the reason the rule is not simply "a parenthetical containing a year".
        let raw = "President (1945-1953 : Truman)"
        #expect(SeriesFactsIndexRunner.displayHeading(raw) == raw, """
            Stripping this collapses four presidencies into a bare "President". Got \
            \(SeriesFactsIndexRunner.displayHeading(raw)).
            """)
        #expect(SeriesFactsIndexRunner.isIdentityParenthetical("1945-1953 : Truman"))
        #expect(!SeriesFactsIndexRunner.isIdentityParenthetical("10/12/1917 - 06/30/1919"))
    }

    @Test("A mid-heading parenthetical is untouched — only the tail is a lifespan")
    func onlyTheTailIsStripped() {
        let raw = "President (1945-1953 : Truman). White House Office. (1945 - 1953)"
        #expect(SeriesFactsIndexRunner.displayHeading(raw)
                == "President (1945-1953 : Truman). White House Office.")
    }

    @Test("Whitespace is normalised, and a heading without a tail is untouched")
    func idempotentOnCleanInput() {
        #expect(SeriesFactsIndexRunner.displayHeading("  Department of State.  ")
                == "Department of State.")
        let clean = "Department of State. Bureau of Far Eastern Affairs."
        #expect(SeriesFactsIndexRunner.displayHeading(clean) == clean)
        // Applying it twice must not strip more.
        #expect(SeriesFactsIndexRunner.displayHeading(
            SeriesFactsIndexRunner.displayHeading("War Trade Board. (1917 - 1919)"))
                == "War Trade Board.")
    }
}

// MARK: - NAIDHarvestTests

/// Finding the NAIDs the app already holds (#405).
///
/// Version history:
///   1.0 — Session 2026-08-10: #405 (F-6)
@Suite("NAID discovery (#405)")
struct NAIDHarvestTests {

    private func writeJSON(_ json: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("f6-\(UUID().uuidString).json")
        try json.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test("NAIDs are found at any nesting depth, as string or int")
    func findsNestedAndLooselyTypedNAIDs() throws {
        // A structural walk, not a list of key paths: both source indexes are rebuilt by other
        // generators whose shapes move, and a hard-coded path that stopped matching would shrink
        // this artifact without failing anything.
        let url = try writeJSON("""
        {
          "lotFiles": [ {"lot": "64D199", "naId": "12345"} ],
          "rolls": { "a": { "deep": [ {"naId": 6789} ] } },
          "recordGroups": { "59": {"naId": "388"} }
        }
        """)
        defer { try? FileManager.default.removeItem(at: url) }
        let found = try SeriesFactsIndexRunner.naIds(inJSONAt: url)
        #expect(found == ["12345", "6789", "388"], "got \(found.sorted())")
    }

    @Test("An empty or naId-free document yields nothing rather than throwing")
    func emptyDocument() throws {
        let url = try writeJSON(#"{"lots": [], "note": "no ids here"}"#)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(try SeriesFactsIndexRunner.naIds(inJSONAt: url).isEmpty)
    }
}

// MARK: - ShippedArtifactTests

/// The artifact this PR ships (#405).
///
/// Pins the measured shape so a regeneration that silently collapses is caught. The generator
/// throws rather than writing zeroes, but it cannot detect "wrote a tenth of what it should".
///
/// Version history:
///   1.0 — Session 2026-08-10: #405 (F-6)
@Suite("Shipped series-creator index (#405)")
struct ShippedArtifactTests {

    private func loadShipped() throws -> SeriesFactsIndexRunner.Index {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appending(path: "FRUSExplorer/Resources/series-facts-index.json")
        return try JSONDecoder().decode(SeriesFactsIndexRunner.Index.self,
                                        from: Data(contentsOf: url))
    }

    @Test("It carries the measured population")
    func measuredShape() throws {
        let index = try loadShipped()
        #expect(index.schemaVersion == 2, "schema 2 adds the #663 catalog facts")
        // Measured 2026-08-10 over the full harvest: 622 of 2,121 app-held series NAIDs carry a
        // creator. A floor, not equality — a re-harvest may add series — but a collapse is caught.
        #expect(index.byNaId.count >= 600, "series with a creator: \(index.byNaId.count)")
        #expect(index.headings.count >= 340, "distinct headings: \(index.headings.count)")
    }

    @Test("Every entry indexes a real heading")
    func indicesAreInBounds() throws {
        let index = try loadShipped()
        for (naId, entry) in index.byNaId {
            #expect(index.headings.indices.contains(entry.creator),
                    "\(naId): creator index \(entry.creator) out of bounds")
            for p in entry.predecessors ?? [] {
                #expect(index.headings.indices.contains(p), "\(naId): predecessor \(p) out of bounds")
                #expect(p != entry.creator,
                        "\(naId): a predecessor equal to the primary would render the body twice")
            }
        }
    }

    @Test("The vocabulary is sorted, deduplicated, and carries no date tails")
    func vocabularyIsCanonical() throws {
        let index = try loadShipped()
        #expect(index.headings == index.headings.sorted(),
                "unsorted vocabulary makes the artifact churn between runs")
        #expect(Set(index.headings).count == index.headings.count, "duplicate headings")
        let withTail = index.headings.filter {
            $0.range(of: #"\(\D*\d{4}"#, options: .regularExpression) != nil
                && !$0.contains(" : ")
        }
        #expect(withTail.isEmpty, "headings still carrying a lifespan: \(withTail.prefix(3))")
    }

    @Test("The catalog facts are present at the measured rates")
    func catalogFactsPopulated() throws {
        let index = try loadShipped()
        let rows = index.byNaId.values
        // Measured 2026-08-10 over the 622 app-reachable series. Floors, since a re-harvest may
        // move them — but each is near-universal, and a collapse would mean the shard reader
        // stopped finding the field rather than NARA having stopped stating it.
        #expect(rows.filter { $0.accessStatus != nil }.count >= 600, "accessStatus")
        #expect(rows.filter { $0.useStatus != nil }.count >= 600, "useStatus")
        #expect(rows.filter { $0.extent != nil }.count >= 600, "extent")
        #expect(rows.filter { $0.referenceUnit != nil }.count >= 600, "referenceUnit")
        #expect(rows.filter { $0.startYear != nil }.count >= 600, "startYear")
        // Partial by nature — NARA lists a finding aid for a minority.
        let aids = rows.filter { !($0.findingAids ?? []).isEmpty }.count
        #expect(aids > 80 && aids < 300, "findingAids: \(aids)")
        // numberingNote is NOT here on purpose: 1 of 622.
    }

    @Test("Every vocabulary index in the artifact is in bounds")
    func vocabularyIndicesInBounds() throws {
        let index = try loadShipped()
        for (naId, row) in index.byNaId {
            if let i = row.accessStatus {
                #expect(index.statuses.indices.contains(i), "\(naId) accessStatus \(i)")
            }
            if let i = row.useStatus {
                #expect(index.statuses.indices.contains(i), "\(naId) useStatus \(i)")
            }
            for i in row.accessRestrictions ?? [] {
                #expect(index.restrictions.indices.contains(i), "\(naId) accessRestriction \(i)")
            }
            for i in row.useRestrictions ?? [] {
                #expect(index.useRestrictions.indices.contains(i), "\(naId) useRestriction \(i)")
            }
            if let i = row.referenceUnit {
                #expect(index.referenceUnits.indices.contains(i), "\(naId) referenceUnit \(i)")
            }
            for i in row.findingAids ?? [] {
                #expect(index.findingAidTypes.indices.contains(i), "\(naId) findingAid \(i)")
            }
        }
    }

    @Test("It stays small enough to load eagerly")
    func staysKilobytes() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appending(path: "FRUSExplorer/Resources/series-facts-index.json")
        let bytes = try Data(contentsOf: url).count
        #expect(bytes < 250_000, """
            \(bytes) bytes. The whole argument for a separate projection is that it is kilobytes \
            rather than the 16 MB creator authority. If it grows past this, intern harder or load \
            it lazily — do not just raise the number.
            """)
    }

    @Test("The department root dominates, which is why the axis was refused")
    func rootConcentrationIsRecorded() throws {
        let index = try loadShipped()
        let roots = index.headings.map { $0.split(separator: ".").first.map(String.init) ?? $0 }
        let stateRoots = roots.filter { $0.hasPrefix("Department of State") }.count
        // 357 of 364 measured. This is the number that killed the similarity axis: a root-level
        // match is worthless, and the useful grain is bureau/office. Pinned so that if a future
        // harvest changes it, whoever reads this knows the axis question was decided on it.
        #expect(Double(stateRoots) / Double(roots.count) > 0.9,
                "\(stateRoots)/\(roots.count) headings root at Department of State")
    }
}

// MARK: - PrimaryCreatorTests

/// Which of a series' creators is *the* creator (#405).
///
/// A mutation sweep replaced this selection with `creators[0]` and nothing caught it — the rule
/// lived inside `run()`, where no test could call it.
///
/// Version history:
///   1.0 — Session 2026-08-10: #405 (F-6)
@Suite("Primary creator selection (#405)")
struct PrimaryCreatorTests {

    private func creator(_ heading: String, _ type: String?) throws
        -> HarvestShardReader.Record.Creator {
        let json = """
        {"heading":"\(heading)","naId":"1","creatorType":\(type.map { "\"\($0)\"" } ?? "null")}
        """
        return try JSONDecoder().decode(HarvestShardReader.Record.Creator.self,
                                        from: Data(json.utf8))
    }

    @Test("Most Recent wins even when a Predecessor is listed first")
    func mostRecentWinsRegardlessOfOrder() throws {
        let creators = [try creator("Before.", "Predecessor"),
                        try creator("Now.", "Most Recent")]
        #expect(SeriesFactsIndexRunner.primaryCreator(from: creators)?.heading == "Now.", """
            Taking the first listed names a body that no longer held the records — the office \
            the reader would go looking for does not have them.
            """)
    }

    @Test("A creator with no type is still a creator")
    func untypedCreatorIsUsed() throws {
        // Measured: 1 of the 622 series carries a creator NARA gives no type (naId 2521222).
        let creators = [try creator("Unlabelled.", nil)]
        #expect(SeriesFactsIndexRunner.primaryCreator(from: creators)?.heading == "Unlabelled.")
    }

    @Test("No creators means no creator, not a crash")
    func emptyIsNil() {
        #expect(SeriesFactsIndexRunner.primaryCreator(from: []) == nil)
    }
}
