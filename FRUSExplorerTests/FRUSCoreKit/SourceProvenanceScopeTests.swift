// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import Testing
@testable import FRUSExplorer

// MARK: - SourceProvenanceScopeTests

/// True volume scope on the SA-3 provenance dashboard (#267).
///
/// Session 3 refused to ship a scope control here, because the bundled aggregate was decade ×
/// category and any narrowing would have been an approximation. Schema 2 adds the per-volume
/// table, so a subset of volumes now rolls up to an *exact* decade table. What these tests pin is
/// that exactness — and that the old refusal survives as the fallback when the table is absent,
/// rather than quietly becoming the approximation it was meant to prevent.
///
/// Version history:
///   1.0 — Session 2026-08-08: #267
@Suite("Source provenance — volume scope")
struct SourceProvenanceScopeTests {

    // MARK: - Fixtures

    /// Six volumes over three decades, with categories that differ per volume so a scope that
    /// silently ignored its argument would produce visibly wrong counts rather than the same ones.
    private func fixtureIndex() -> SourceProvenanceIndex {
        let volumes = [
            VolumeProvenance(volumeId: "frus1950v01", decade: 1950, totalNotes: 100,
                             counts: ["centralDecimalFile": 90, "lotFile": 10]),
            VolumeProvenance(volumeId: "frus1950v02", decade: 1950, totalNotes: 60,
                             counts: ["centralDecimalFile": 60]),
            VolumeProvenance(volumeId: "frus1961-63v01", decade: 1960, totalNotes: 40,
                             counts: ["lotFile": 30, "presidentialLibrary": 10]),
            VolumeProvenance(volumeId: "frus1961-63v02", decade: 1960, totalNotes: 20,
                             counts: ["presidentialLibrary": 20]),
            VolumeProvenance(volumeId: "frus1969-76v01", decade: 1970, totalNotes: 30,
                             counts: ["presidentialLibrary": 30]),
            // The pre-1900 floor, which every derivation excludes.
            VolumeProvenance(volumeId: "frus1870v01", decade: 1870, totalNotes: 7,
                             counts: ["unrecognized": 7]),
        ]
        return SourceProvenanceIndex(
            schemaVersion: 2, generated: "2026-08-08",
            totalSourceNotes: volumes.reduce(0) { $0 + $1.totalNotes },
            volumesCovered: volumes.count,
            categories: SourceProvenanceCategory.ordered.map(\.rawValue),
            byDecade: SourceProvenanceData.rollUp(volumes),
            byVolume: volumes)
    }

    private func notes(_ data: SourceProvenanceData, decade: Int) -> Int {
        data.notesByDecade.first { $0.decade == decade }?.totalNotes ?? 0
    }

    private func count(_ data: SourceProvenanceData, decade: Int,
                       _ category: SourceProvenanceCategory) -> Int {
        data.shownDecadeCategoryCounts[decade]?[category] ?? 0
    }

    // MARK: - The roll-up is exact

    @Test("A scope of one volume yields that volume's counts, not a share of the whole")
    func scopingToOneVolume() {
        let data = SourceProvenanceData(index: fixtureIndex(),
                                        scopeVolumeIds: ["frus1950v01"])
        #expect(data.notesByDecade.map(\.decade) == [1950],
                "only the scoped volume's decade should appear")
        #expect(notes(data, decade: 1950) == 100)
        #expect(count(data, decade: 1950, .centralDecimalFile) == 90)
        #expect(count(data, decade: 1950, .lotFile) == 10)
        #expect(data.volumesCovered == 1)
        #expect(data.totalSourceNotes == 100)
    }

    @Test("A scope spanning decades keeps each decade's own volumes")
    func scopingAcrossDecades() {
        let data = SourceProvenanceData(
            index: fixtureIndex(),
            scopeVolumeIds: ["frus1950v02", "frus1961-63v01", "frus1969-76v01"])
        #expect(data.notesByDecade.map(\.decade) == [1950, 1960, 1970])
        #expect(notes(data, decade: 1950) == 60)
        #expect(notes(data, decade: 1960) == 40)
        #expect(notes(data, decade: 1970) == 30)
        // Volume counts are the in-scope volumes, not the whole series' figure for that decade.
        #expect(data.notesByDecade.allSatisfy { $0.volumeCount == 1 }, """
            Each decade has one volume in scope; a volumeCount carried over from the unscoped \
            aggregate would read 2 for the 1950s.
            """)
    }

    @Test("Shares are recomputed within the scope, not rescaled from the whole series")
    func sharesAreRecomputed() {
        let whole = SourceProvenanceData(index: fixtureIndex())
        let scoped = SourceProvenanceData(index: fixtureIndex(),
                                          scopeVolumeIds: ["frus1961-63v02"])
        // Whole series, the 1960s: 30 lot + 30 library of 60. Scoped to v02: 20 library of 20.
        let wholeLibrary = whole.shareByDecade
            .first { $0.decade == 1960 && $0.category == .presidentialLibrary }?.share
        let scopedLibrary = scoped.shareByDecade
            .first { $0.decade == 1960 && $0.category == .presidentialLibrary }?.share
        let scopedDescription = scopedLibrary.map { "\($0)" } ?? "nil"
        #expect(wholeLibrary == 0.5)
        #expect(scopedLibrary == 1.0, """
            The scoped share is \(scopedDescription). Scoping must re-divide within the scope; \
            carrying the whole-series share across would show a volume drawing entirely on \
            presidential libraries as if it were half lot files.
            """)
    }

    @Test("The pre-1900 floor still applies inside a scope")
    func floorAppliesUnderScope() {
        let data = SourceProvenanceData(index: fixtureIndex(),
                                        scopeVolumeIds: ["frus1870v01", "frus1950v01"])
        #expect(data.notesByDecade.map(\.decade) == [1950],
                "the 1870s volume is below the trend floor and must not become a chart row")
        #expect(data.prewarExcludedNoteCount == 7,
                "…and its notes must be disclosed as excluded, not silently dropped")
    }

    @Test("An empty scope produces empty charts rather than the whole series")
    func emptyScopeIsEmpty() {
        let data = SourceProvenanceData(index: fixtureIndex(), scopeVolumeIds: [])
        #expect(data.shareByDecade.isEmpty)
        #expect(data.notesByDecade.isEmpty)
        #expect(data.volumesCovered == 0)
        #expect(data.totalSourceNotes == 0, """
            An empty scope that fell back to the artifact's own totals would print the whole \
            series' note count above empty charts.
            """)
    }

    // MARK: - The unscoped path is untouched

    @Test("No scope reads the artifact's own decade table verbatim")
    func unscopedUsesTheStatedAggregate() {
        let index = fixtureIndex()
        let data = SourceProvenanceData(index: index)
        #expect(data.totalSourceNotes == index.totalSourceNotes)
        #expect(data.volumesCovered == index.volumesCovered)
        #expect(notes(data, decade: 1950) == 160)
        #expect(notes(data, decade: 1960) == 60)
        #expect(data.supportsVolumeScope)
    }

    // MARK: - The refusal survives

    @Test("A schema-1 artifact reports no scope support and ignores a scope argument")
    func schemaOneWithholdsTheControl() {
        let index = SourceProvenanceIndex(
            schemaVersion: 1, generated: "2026-07-04",
            totalSourceNotes: 160, volumesCovered: 2,
            categories: SourceProvenanceCategory.ordered.map(\.rawValue),
            byDecade: [DecadeProvenance(decade: 1950, totalNotes: 160, volumeCount: 2,
                                        counts: ["centralDecimalFile": 160])])
        let data = SourceProvenanceData(index: index, scopeVolumeIds: ["frus1950v01"])
        #expect(!data.supportsVolumeScope, """
            Without the per-volume table the dashboard must report that it cannot scope, so the \
            control is withheld — Session 3's decision, which was that an approximated scope is \
            worse than none.
            """)
        #expect(data.totalSourceNotes == 160, """
            …and the figures stay whole-series rather than being narrowed by guesswork. Silently \
            filtering a decade table by volume id is exactly the approximation this refuses.
            """)
    }

    @Test("A nil index yields no scope support and no data")
    func nilIndexIsInert() {
        let data = SourceProvenanceData(index: nil, scopeVolumeIds: ["frus1950v01"])
        #expect(!data.supportsVolumeScope)
        #expect(data.shareByDecade.isEmpty)
    }

    // MARK: - The shipped artifact

    @Test("The shipped artifact carries the per-volume table, and it sums to the decade table")
    func shippedArtifactIsConsistent() throws {
        let url = try #require(Bundle.main.url(forResource: "source-provenance-index",
                                               withExtension: "json"), """
            source-provenance-index.json must be in the app bundle.
            """)
        let index = try JSONDecoder().decode(SourceProvenanceIndex.self,
                                             from: Data(contentsOf: url))
        #expect(index.schemaVersion == 2, "the artifact must be regenerated at schema 2 (#267)")
        let volumes = try #require(index.byVolume, "schema 2 must carry byVolume")
        #expect(volumes.count > 400)
        #expect(volumes.map(\.volumeId) == volumes.map(\.volumeId).sorted(),
                "byVolume must be sorted, or every regeneration churns the diff")
        #expect(Set(volumes.map(\.volumeId)).count == volumes.count, "duplicate volume rows")

        // The load-bearing invariant: the stated decade table and the per-volume table are two
        // views of one scan. If they disagree, scoping to "everything" would not equal the
        // unscoped dashboard, and no reader could tell which number was right.
        let rolled = SourceProvenanceData.rollUp(volumes)
        #expect(rolled.map(\.decade) == index.byDecade.map(\.decade),
                "the decade axes differ between the two tables")
        for (derived, stated) in zip(rolled, index.byDecade) {
            #expect(derived.totalNotes == stated.totalNotes,
                    "\(stated.decade): \(derived.totalNotes) rolled up vs \(stated.totalNotes) stated")
            #expect(derived.volumeCount == stated.volumeCount,
                    "\(stated.decade): \(derived.volumeCount) volumes rolled up vs \(stated.volumeCount)")
            for category in SourceProvenanceCategory.ordered {
                #expect(derived.count(for: category) == stated.count(for: category),
                        "\(stated.decade)/\(category.rawValue) disagrees between the two tables")
            }
        }
        #expect(volumes.reduce(0) { $0 + $1.totalNotes } == index.totalSourceNotes)
        #expect(volumes.count == index.volumesCovered)
    }

    // MARK: - The dashboard mounts it

    @Test("The dashboard mounts the scope bar, gated on the artifact supporting it")
    func dashboardMountsTheScopeBar() throws {
        // A SwiftUI view cannot be evaluated in this target, and every derivation test above
        // passes over a dashboard that never shows the control — measured, deleting the bar from
        // the body left the whole suite green. Scoped to `body` and to code lines, and the gate is
        // checked by adjacency so a `supportsVolumeScope` mentioned elsewhere cannot stand in.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appending(path: "FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift"),
            encoding: .utf8)
        #expect(source.count > 5_000, "SourceProvenanceDashboard.swift is implausibly small")

        let start = try #require(source.range(of: "var body: some View {"))
        let rest = source[start.upperBound...]
        let end = try #require(rest.range(of: "// MARK: -"))
        let body = String(rest[..<end.lowerBound])
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.hasPrefix("///") }

        let index = try #require(body.firstIndex { $0.contains("SeriesScopeBar(") }, """
            The scope bar is not mounted in the dashboard's body. #267 is the control, not the \
            data — an artifact that supports scoping and a dashboard that never offers it leaves \
            the issue exactly where it started.
            """)
        #expect(index > 0)
        #expect(body[index - 1] == "if data.supportsVolumeScope {", """
            The scope bar is not gated on the artifact carrying the per-volume table. Ungated, a \
            schema-1 artifact would show a control whose selections change nothing — which is \
            worse than the missing control Session 3 chose. The line before it reads: \
            \(body[index - 1])
            """)
        // The data is built in a computed property, not in `body` — so this one is file-scoped.
        let code = source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.hasPrefix("///") }
        #expect(code.contains { $0.contains("scopeVolumeIds: scope.volumeIds") }, """
            The dashboard builds its data without passing the scope, so the bar would move and \
            the charts would not.
            """)
    }

    @Test("Scoping the shipped artifact to a real subseries narrows it")
    func shippedArtifactScopes() throws {
        let url = try #require(Bundle.main.url(forResource: "source-provenance-index",
                                               withExtension: "json"))
        let index = try JSONDecoder().decode(SourceProvenanceIndex.self,
                                             from: Data(contentsOf: url))
        let volumes = try #require(index.byVolume)
        let subset = Set(volumes.filter { $0.volumeId.hasPrefix("frus1969-76") }.map(\.volumeId))
        #expect(subset.count > 10, "fixture is wrong — the 1969-76 subseries should be large")

        let scoped = SourceProvenanceData(index: index, scopeVolumeIds: subset)
        let whole = SourceProvenanceData(index: index)
        #expect(scoped.volumesCovered == subset.count)
        #expect(scoped.totalSourceNotes < whole.totalSourceNotes)
        #expect(scoped.totalSourceNotes > 0)
        #expect(!scoped.shareByDecade.isEmpty)
        for point in scoped.notesByDecade {
            let wholeCount = whole.notesByDecade.first { $0.decade == point.decade }?.totalNotes ?? 0
            #expect(point.totalNotes <= wholeCount,
                    "\(point.decade) has more notes scoped than whole-series")
        }
    }
}
