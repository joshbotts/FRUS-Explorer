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

// MARK: - AnalyticsProvenanceOverrideTests

/// The two overrides #790 added to the shared provenance, and the one field it decoupled.
///
/// Every test here also pins that the four surfaces already using `AnalyticsProvenance` are
/// unaffected — the change is additive or it is a regression in four shipped exports.
///
/// Version history:
///   1.0 — Session 2026-08-09: #790
@Suite("Analytics provenance — surface overrides")
struct AnalyticsProvenanceOverrideTests {

    private func base(dating: Bool = true, yearRange: ClosedRange<Int>? = 1900...2000)
        -> AnalyticsProvenance {
        AnalyticsProvenance(figureTitle: "T", axisLabel: "A", indexedVolumeCount: 12,
                            yearRange: yearRange, appliesDocumentDating: dating)
    }

    @Test("A surface can state its own dating rule instead of the corpus-analytics one")
    func datingRuleOverrides() {
        let standard = base().csvPreambleLines.joined(separator: "\n")
        #expect(standard.contains("TEI <date>"), "the default rule still ships for its own views")

        var custom = base(dating: false)
        custom.datingRule = "Dating: no document date is read."
        let text = custom.csvPreambleLines.joined(separator: "\n")
        #expect(text.contains("no document date is read"))
        #expect(!text.contains("TEI <date>"), """
            The corpus-analytics dating sentence reached a surface that never reads a document \
            date. That sentence names a volume-start-year fallback and By Month / By Day charts, \
            none of which exist on the About-the-Series dashboards.
            """)
    }

    @Test("A surface can state what corpus it covers instead of the indexed-here caveat")
    func corpusStatementOverrides() {
        let standard = base().csvPreambleLines.joined(separator: "\n")
        #expect(standard.contains("indexed on this device"),
                "the default still ships for the surfaces that really are index-scoped")

        var custom = base()
        custom.corpusStatement = "Corpus: a bundled aggregate covering all 552 volumes."
        let text = custom.csvPreambleLines.joined(separator: "\n")
        #expect(text.contains("all 552 volumes"))
        #expect(!text.contains("indexed on this device"), """
            An export from a bundled corpus-wide aggregate claimed to cover only the volumes on \
            this device. That is not a conservative caveat, it understates every figure — these \
            dashboards render with no index at all.
            """)
    }

    @Test("The year-range line follows the range, not the dating flag")
    func yearRangeIsDecoupled() {
        // Before #790 the line was gated on `appliesDocumentDating`, which conflated two
        // independent facts: a surface can filter by year without placing documents on a
        // timeline, and three of the four Series dashboards do exactly that.
        var ranged = base(dating: false, yearRange: 1945...1976)
        ranged.datingRule = "Dating: volumes, not documents."
        let text = ranged.csvPreambleLines.joined(separator: "\n")
        #expect(text.contains("1945–1976"), "the range the reader set must reach the file")

        // Strictly additive: no range and no dating still prints nothing, as for the word cloud.
        let neither = base(dating: false, yearRange: nil)
        let quiet = neither.csvPreambleLines.joined(separator: "\n")
        #expect(!quiet.contains("Year range"))
    }
}

// MARK: - SeriesAnalyticsExportTests

/// The four About-the-Series methods statements (#790).
///
/// Version history:
///   1.0 — Session 2026-08-09: #790
@Suite("Series analytics — export provenance")
struct SeriesAnalyticsExportTests {

    // MARK: - Plate A's four conditions (visual-marketing §4.2)

    private func plateA(hidden: [String] = [], generated: String = "2026-08-19")
        -> AnalyticsProvenance {
        SeriesAnalyticsExport.provenance(
            figureTitle: "Where the editors found the documents",
            axisLabel: "Coverage decade", scopeLabel: nil, yearRange: nil,
            volumeCount: 522, noteCount: 268_757,
            hiddenCategories: hidden, generated: generated)
    }

    /// **Condition 4.** Every number on this dashboard comes from one bundled aggregate, so two
    /// plates drawn from different generations are different figures. Without the stamp they carry
    /// identical captions and nothing distinguishes them.
    @Test("The plate names the artifact generation it was drawn from")
    func plateNamesItsArtifact() {
        let text = plateA().plateLines.map(\.text).joined(separator: " ")
        #expect(text.contains("2026-08-19"))
        #expect(text.contains("Artifact:"))
        // Empty is tolerated and omits the line: an absent stamp beats a fabricated one.
        #expect(!plateA(generated: "").plateLines.map(\.text)
            .joined(separator: " ").contains("Artifact:"))
    }

    /// **Condition 2.** Hiding a category re-bases every share, and the natural aesthetic choice —
    /// the one-tap "Hide Other / Unclassified" — is exactly the one that silently changes every
    /// number. The disclosure must reach the IMAGE, not only the CSV.
    @Test("A hidden category is disclosed on the plate, not only in the CSV")
    func hiddenCategoryReachesThePlate() {
        let plain = plateA()
        let filtered = plateA(hidden: ["Other / Unclassified"])
        let onPlate = filtered.plateLines.filter { $0.role == .caveat }.map(\.text)
        #expect(onPlate.contains { $0.contains("Re-based") && $0.contains("Other / Unclassified") })
        #expect(!plain.plateLines.map(\.text).joined().contains("Re-based"),
                "an unfiltered plate must not claim a re-basing that did not happen")
    }

    /// **Condition 3.** Under 1900 the plate is a solid "Other / Unclassified" wall, which reads as
    /// *the editors did not say where these came from* when it means *the parser did not classify
    /// these*. That sentence was CSV-only until the figure canvas began printing every caveat.
    @Test("The parser-not-editors sentence reaches the plate")
    func unclassifiedMeaningReachesThePlate() {
        let onPlate = plateA().plateLines.filter { $0.role == .caveat }.map(\.text)
        #expect(onPlate.contains { $0.contains("could not classify") })
        #expect(onPlate.contains { $0.contains("not a missing note") })
    }

    private var all: [AnalyticsProvenance] {
        [
            SeriesAnalyticsExport.production(
                figureTitle: "Publication lag over time", axisLabel: "A", scopeLabel: nil,
                yearRange: 1861...2026, volumeCount: 552),
            SeriesAnalyticsExport.geography(
                figureTitle: "Volumes by region", axisLabel: "A", scopeLabel: nil,
                yearRange: nil, volumeCount: 552),
            SeriesAnalyticsExport.provenance(
                figureTitle: "Archival provenance over time", axisLabel: "A", scopeLabel: nil,
                yearRange: 1900...1993, volumeCount: 522, noteCount: 268_757,
                hiddenCategories: []),
            SeriesAnalyticsExport.administration(
                figureTitle: "Documents per administration", axisLabel: "A", scopeLabel: nil,
                yearRange: 1861...2026, volumeCount: 552, includesEditorialNotes: false),
        ]
    }

    /// The same statement with its overrides removed — i.e. exactly what the shared default
    /// would have printed here.
    ///
    /// Matched against, rather than a quoted phrase from the default. A quoted phrase decays
    /// into a test that passes for the wrong reason the first time anyone rewords the default:
    /// the negative assertion goes on succeeding while no longer guarding anything.
    private func withoutOverrides(_ statement: AnalyticsProvenance) -> AnalyticsProvenance {
        var bare = statement
        bare.datingRule = nil
        bare.corpusStatement = nil
        return bare
    }

    @Test("Not one of the four inherits the corpus-analytics dating sentence")
    func noneInheritsTheDefaultDatingRule() {
        for statement in all {
            let text = statement.csvPreambleLines.joined(separator: "\n")
            #expect(!text.contains(withoutOverrides(statement).datingCaveat), """
                \(statement.figureTitle) inherited the default dating rule. No dashboard here has \
                a volume-start-year fallback, and three of the four never read a document date.
                """)
            #expect(statement.datingRule != nil,
                    "\(statement.figureTitle) states no dating rule at all")
            #expect(text.contains(statement.datingCaveat),
                    "\(statement.figureTitle) states a rule that never reaches the file")
        }
        #expect(all.count == 4, "every builder must be in this sweep")
    }

    @Test("Not one of the four claims to be limited to what this device indexed")
    func noneClaimsTheDeviceCorpus() {
        for statement in all {
            let text = statement.csvPreambleLines.joined(separator: "\n")
            #expect(!text.contains(withoutOverrides(statement).corpusCaveat), """
                \(statement.figureTitle) understates its own coverage with the default corpus \
                caveat. These dashboards read bundled aggregates and render before anything is \
                downloaded, and their own statement has to say so instead.
                """)
            #expect(text.contains(
                SeriesAnalyticsExport.corpusStatement(volumeCount: statement.indexedVolumeCount)),
                    "\(statement.figureTitle) does not carry the Series corpus statement")
        }
    }

    @Test("Only the administration dashboard reads a document's own date")
    func onlyAdministrationIsDocumentDated() {
        let flags = all.map(\.appliesDocumentDating)
        #expect(flags == [false, false, false, true], """
            Dating flags are \(flags). Production charts volumes by print year, Geography counts \
            volumes per region, Provenance buckets by the volume's coverage decade; only the \
            administration profiles attribute a document by its own date bounds.
            """)
    }

    @Test("A scoped export says it is a subset, and an unscoped one does not")
    func scopeIsDisclosed() {
        let scoped = SeriesAnalyticsExport.production(
            figureTitle: "T", axisLabel: "A", scopeLabel: "1969–1976",
            yearRange: 1861...2026, volumeCount: 66)
        #expect(scoped.extraCaveats.contains { $0.contains("not comparable") }, """
            A subseries-scoped export did not say so. Its numbers are recomputed from that \
            subset alone and read as whole-series figures otherwise.
            """)
        let whole = SeriesAnalyticsExport.production(
            figureTitle: "T", axisLabel: "A", scopeLabel: nil,
            yearRange: 1861...2026, volumeCount: 552)
        #expect(!whole.extraCaveats.contains { $0.contains("Scoped to") })
    }

    @Test("A filtered provenance export says its shares are re-based")
    func hiddenCategoriesAreDisclosed() {
        let filtered = SeriesAnalyticsExport.provenance(
            figureTitle: "T", axisLabel: "A", scopeLabel: nil, yearRange: nil,
            volumeCount: 522, noteCount: 268_757,
            hiddenCategories: ["Other / Unclassified", "Foreign Archives"])
        let text = filtered.extraCaveats.joined(separator: " ")
        #expect(text.contains("Re-based"), """
            Hiding a category re-bases every share over what is left (#236). A table exported \
            under a filter is not a table of shares of all source notes, and only the preamble \
            can say so.
            """)
        #expect(text.contains("Other / Unclassified"), "the hidden categories must be named")

        let unfiltered = SeriesAnalyticsExport.provenance(
            figureTitle: "T", axisLabel: "A", scopeLabel: nil, yearRange: nil,
            volumeCount: 522, noteCount: 268_757, hiddenCategories: [])
        #expect(!unfiltered.extraCaveats.contains { $0.contains("Re-based") })
    }

    @Test("The administration export corrects the two things its own controls imply wrongly")
    func administrationCorrectsItsControls() {
        let statement = SeriesAnalyticsExport.administration(
            figureTitle: "T", axisLabel: "A", scopeLabel: nil, yearRange: 1945...1976,
            volumeCount: 552, includesEditorialNotes: false)
        // The year control filters which presidents appear; it never re-counts documents. A
        // preamble printing "1945–1976" without this reads as "documents in those years".
        #expect(statement.extraCaveats.contains(SeriesAnalyticsExport.adminYearsCaveat))
        // Any-overlap attribution means the counts are not exclusive and sum past the corpus.
        #expect(statement.extraCaveats.contains(SeriesAnalyticsExport.adminOverlapCaveat))
    }

    @Test("The editorial-notes setting is stated, in whichever state it is in")
    func toggleStateIsStated() {
        // Until #791 this builder took a second parameter, because the volumes-per-year chart
        // ignored the toggle its own subtitle promised to obey and the export had to say so.
        // With the chart fixed, one sentence is true of both figures — and it now also names the
        // consequence for the volume count, which is the part that had been silently wrong.
        let excluded = SeriesAnalyticsExport.administration(
            figureTitle: "T", axisLabel: "A", scopeLabel: nil, yearRange: 1861...2026,
            volumeCount: 552, includesEditorialNotes: false)
        #expect(excluded.extraCaveats.contains { $0.contains("Editorial notes: excluded") })
        #expect(excluded.extraCaveats.contains { $0.contains("only tie to an administration") },
                "the export must say that excluding notes also withholds volumes")

        let included = SeriesAnalyticsExport.administration(
            figureTitle: "T", axisLabel: "A", scopeLabel: nil, yearRange: 1861...2026,
            volumeCount: 552, includesEditorialNotes: true)
        #expect(included.extraCaveats.contains { $0.contains("Editorial notes: included") })
        #expect(!included.extraCaveats.contains { $0.contains("unaffected by the editorial-notes") },
                "that sentence described a defect #791 fixed and must not survive it")
    }

    @Test("The delivered CSV carries the preamble above the table")
    func endToEnd() {
        let table = ChartInspectorData(
            id: "sa3.mix", title: "Archival provenance over time",
            columns: ["Coverage decade", "Provenance", "Share"],
            rowCells: [["1950", "Central Decimal File", "62%"]])
        let statement = SeriesAnalyticsExport.provenance(
            figureTitle: "Archival provenance over time", axisLabel: "By coverage decade",
            scopeLabel: nil, yearRange: 1900...1993, volumeCount: 522, noteCount: 268_757,
            hiddenCategories: [])
        let csv = table.provenancedCSV(statement)
        #expect(csv.hasPrefix("#"))
        #expect(csv.contains("Central Decimal File"))
        #expect(csv.contains("Year range"), "the range applies here and must be stated")
        #expect(!csv.contains(withoutOverrides(statement).corpusCaveat))
        #expect(!csv.contains(withoutOverrides(statement).datingCaveat))
    }
}

// MARK: - SeriesExportWiringTests

/// Every Series chart mounts its export (#790).
///
/// Version history:
///   1.0 — Session 2026-08-09: #790
@Suite("Series analytics — export wiring")
struct SeriesExportWiringTests {

    private static let dashboards = [
        "SeriesProductionDashboard", "SeriesGeographyDashboard",
        "SourceProvenanceDashboard", "AdministrationProfilesDashboard",
    ]

    private static func source(_ name: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/SeriesAnalytics/\(name).swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test("All eleven charts pass a provenance to their card")
    func everyChartHasProvenance() throws {
        var total = 0
        for name in Self.dashboards {
            let source = try Self.source(name)
            let cards = source.components(separatedBy: "return chartCard(").count - 1
            let provenances = source.components(separatedBy: "\n            provenance:").count - 1
            #expect(cards == provenances, """
                \(name) has \(cards) chart cards and \(provenances) provenance arguments. A card \
                without one would not compile, so a mismatch here means the helper's own default \
                was reintroduced.
                """)
            total += cards
        }
        #expect(total == 11, "the four dashboards carry eleven charts between them, not \(total)")
    }

    @Test("Every dashboard mounts the export presentation exactly once, on its root")
    func presentationIsMountedOnce() throws {
        for name in Self.dashboards {
            let source = try Self.source(name)
            let mounts = source.components(separatedBy: ".seriesExportPresentation(").count - 1
            #expect(mounts == 1, "\(name) mounts the export presentation \(mounts) times")
            // Beside the inspector sheet, which already hangs off the body's root VStack — not
            // on a `Group`, where a presentation modifier is applied once per child.
            let inspector = try #require(source.range(of: ".sheet(item: $inspectorData)"))
            let export = try #require(source.range(of: ".seriesExportPresentation("))
            #expect(export.lowerBound > inspector.lowerBound,
                    "\(name) should mount the export beside the inspector sheet")
        }
    }

    @Test("The shared chartCard helper is the only mount point, in all four copies")
    func helpersAgree() throws {
        for name in Self.dashboards {
            let source = try Self.source(name)
            #expect(source.contains("SeriesChartExportControl("),
                    "\(name) does not mount the export control")
            #expect(source.contains("chart: content"), """
                \(name)'s figure is not built from the card's own content closure. Rendering the \
                chart twice is how an exported figure drifts from the one on screen.
                """)
        }
    }
}
