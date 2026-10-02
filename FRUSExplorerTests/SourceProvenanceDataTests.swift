// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SwiftUI
import Charts
@testable import FRUSExplorer

// MARK: - SourceProvenanceDataTests

/// Pure derivation tests for the "Archival Sourcing Over Time" dashboard (Series
/// Analytics SA-3b): the `SourceProvenanceIndex` decode contract, the
/// `SourceProvenanceData` derivations from a constructed fixture (pre-1900 floor,
/// per-decade shares, overall composition, missing-key = 0, unknown-category
/// tolerance, empty safety), and one integration guard that the *actual* bundled
/// `source-provenance-index.json` decodes with the expected headline figures.
///
/// These assert the model only — no SwiftUI view is instantiated.
///
/// Version history:
///   1.0 — Analytics SA-3b: initial implementation
///   1.1 — Session 3 / #236: category include/exclude filter tests (identity,
///          exact renormalization, composition order)
///   1.2 — Session 3 review: the all-zero-decade test asserts explicit zero rows
///          (no x-gap) instead of the dropped decade it previously locked in
///   1.3 — Regenerated after OH's 2026-09-14 correction to frus1981-88v16: 269,248 → 269,242
///   1.4 — 2026-10-02 (#1543): eleven categories; the bundled index places the Subject-Numeric
///          File in the 1960s and 1970s and nowhere else; the Categories menu's count is derived
///   1.5 — 2026-10-02 (#1543, review round 1): the count test reads the call's two arguments,
///          so a literal total fails it
///   1.6 — 2026-10-02 (#1543, landing round 2): the charts' colour scale — each older category
///          keeps the colour the default cycle drew it in, read from the scale and from drawn
///          charts, and every chart that colours by category takes the one scale
struct SourceProvenanceDataTests {

    // MARK: Fixtures

    /// A small constructed index spanning one pre-1900 floor decade and three
    /// shown decades, exercising a missing category key and an unknown category.
    private func fixture() -> SourceProvenanceIndex {
        SourceProvenanceIndex(
            schemaVersion: 1,
            generated: "2026-07-04",
            totalSourceNotes: 100 + 200 + 80 + 40,
            volumesCovered: 12,
            categories: SourceProvenanceCategory.ordered.map(\.rawValue),
            byDecade: [
                // Pre-1900 floor: excluded from every derivation.
                DecadeProvenance(decade: 1860, totalNotes: 100, volumeCount: 3,
                                 counts: ["unrecognized": 100]),
                // 1910: 100% central decimal file (single category).
                DecadeProvenance(decade: 1910, totalNotes: 200, volumeCount: 4,
                                 counts: ["centralDecimalFile": 200]),
                // 1950: split; note "lotFile" present but "naraCollection" OMITTED
                // (must read as 0). Includes an UNKNOWN future category key.
                DecadeProvenance(decade: 1950, totalNotes: 80, volumeCount: 3,
                                 counts: [
                                    "centralDecimalFile": 40,
                                    "lotFile": 20,
                                    "presidentialLibrary": 20,
                                    "quantumArchive": 999,  // unknown → ignored
                                 ]),
                // 1970: presidential-library dominant.
                DecadeProvenance(decade: 1970, totalNotes: 40, volumeCount: 2,
                                 counts: [
                                    "presidentialLibrary": 30,
                                    "centralForeignPolicyFile": 10,
                                 ]),
            ]
        )
    }

    // MARK: Category enum

    @Test("SourceProvenanceCategory: eleven ordered categories with the expected raw values")
    func categoryOrder() {
        #expect(SourceProvenanceCategory.ordered.count == 11)
        #expect(SourceProvenanceCategory.ordered.map(\.rawValue) == [
            "centralDecimalFile", "subjectNumericFile", "centralForeignPolicyFile", "lotFile",
            "presidentialLibrary", "naraCollection", "intelligence",
            "namedFileSeries", "foreignArchive", "previouslyPublished",
            "unrecognized",
        ])
        #expect(SourceProvenanceCategory.allCases.count == 11)
        // The map's provenance lens colours by position in `allCases`, so the declaration order
        // is the display order (#1543).
        #expect(SourceProvenanceCategory.allCases == SourceProvenanceCategory.ordered)
        #expect(SourceProvenanceCategory.subjectNumericFile.displayName == "Subject-Numeric File")
    }

    @Test("SourceProvenanceCategory: an unknown raw value is nil, not a crash")
    func unknownRawValueTolerated() {
        #expect(SourceProvenanceCategory(rawValue: "quantumArchive") == nil)
        #expect(SourceProvenanceCategory(rawValue: "centralDecimalFile") == .centralDecimalFile)
    }

    // MARK: DecadeProvenance.count(for:)

    @Test("DecadeProvenance: a missing category key reads as zero")
    func missingKeyIsZero() {
        let decade = fixture().byDecade.first { $0.decade == 1950 }!
        // naraCollection omitted from the 1950 counts.
        #expect(decade.count(for: .naraCollection) == 0)
        #expect(decade.count(for: .lotFile) == 20)
        #expect(decade.count(for: .centralDecimalFile) == 40)
    }

    // MARK: Pre-1900 floor + shares

    @Test("SourceProvenanceData: shareByDecade excludes decades below 1900")
    func floorExcludesPre1900() {
        let data = SourceProvenanceData(index: fixture())
        let decades = Set(data.shareByDecade.map(\.decade))
        #expect(!decades.contains(1860))
        #expect(decades == [1910, 1950, 1970])
        #expect(data.decadeRangeShown == 1910...1970)
        // The floored-out 1860 bucket's notes are disclosed.
        #expect(data.prewarExcludedNoteCount == 100)
    }

    @Test("SourceProvenanceData: shares sum to ~1.0 within each shown decade")
    func sharesSumToOne() {
        let data = SourceProvenanceData(index: fixture())
        for decade in [1910, 1950, 1970] {
            let sum = data.shareByDecade
                .filter { $0.decade == decade }
                .reduce(0.0) { $0 + $1.share }
            #expect(abs(sum - 1.0) < 1e-9, "decade \(decade) shares summed to \(sum)")
        }
    }

    @Test("SourceProvenanceData: an omitted-then-present category yields the right share")
    func perCategoryShare() {
        let data = SourceProvenanceData(index: fixture())
        // 1950: centralDecimalFile 40/80 = 0.5 (naraCollection absent → no row).
        let cdf = data.shareByDecade.first { $0.decade == 1950 && $0.category == .centralDecimalFile }
        #expect(cdf != nil)
        #expect(abs((cdf?.share ?? 0) - 0.5) < 1e-9)
        // naraCollection has no row in 1950 (share would be 0).
        let nara = data.shareByDecade.first { $0.decade == 1950 && $0.category == .naraCollection }
        #expect(nara == nil)
    }

    @Test("SourceProvenanceData: an unknown category key is ignored, not counted")
    func unknownCategoryIgnored() {
        let data = SourceProvenanceData(index: fixture())
        // The "quantumArchive" 999-count in 1950 must NOT inflate the decade's
        // shares: only the four known categories contribute, and they sum to 1.0
        // on the real total (80), so the unknown key is fully excluded.
        let sum1950 = data.shareByDecade
            .filter { $0.decade == 1950 }
            .reduce(0.0) { $0 + $1.share }
        // Known counts: 40+20+20 = 80 = totalNotes → shares sum to 1.0.
        #expect(abs(sum1950 - 1.0) < 1e-9)
        // No composition entry exceeds its known contribution.
        let comp = data.overallComposition
        let totalCounted = comp.reduce(0) { $0 + $1.noteCount }
        // 1910: 200, 1950: 80 (known only), 1970: 40 = 320 (excludes the 999 unknown + 100 floor).
        #expect(totalCounted == 320)
    }

    // MARK: Overall composition

    @Test("SourceProvenanceData: overallComposition sums counts across shown decades")
    func compositionSums() {
        let data = SourceProvenanceData(index: fixture())
        func count(_ c: SourceProvenanceCategory) -> Int {
            data.overallComposition.first { $0.category == c }?.noteCount ?? -1
        }
        #expect(count(.centralDecimalFile) == 200 + 40)      // 1910 + 1950
        #expect(count(.lotFile) == 20)                       // 1950
        #expect(count(.presidentialLibrary) == 20 + 30)      // 1950 + 1970
        #expect(count(.centralForeignPolicyFile) == 10)      // 1970
        #expect(count(.naraCollection) == 0)                 // never present
        // Composition covers all eleven categories (stable legend), zeros included.
        #expect(data.overallComposition.count == 11)
        // Shares over the shown total (320).
        #expect(data.shownNoteCount == 320)
        let cdfShare = data.overallComposition.first { $0.category == .centralDecimalFile }?.share ?? 0
        #expect(abs(cdfShare - 240.0 / 320.0) < 1e-9)
    }

    @Test("SourceProvenanceData: notesByDecade carries shown decades only")
    func notesByDecade() {
        let data = SourceProvenanceData(index: fixture())
        #expect(data.notesByDecade.map(\.decade) == [1910, 1950, 1970])
        let d1910 = data.notesByDecade.first { $0.decade == 1910 }
        #expect(d1910?.totalNotes == 200)
        #expect(d1910?.volumeCount == 4)
    }

    // MARK: Stats + empty safety

    @Test("SourceProvenanceData: headline stats echo the index")
    func headlineStats() {
        let data = SourceProvenanceData(index: fixture())
        #expect(data.totalSourceNotes == 420)
        #expect(data.volumesCovered == 12)
    }

    @Test("SourceProvenanceData: a nil index yields empty collections, no crash")
    func nilIndexIsSafe() {
        let data = SourceProvenanceData(index: nil)
        #expect(data.shareByDecade.isEmpty)
        #expect(data.overallComposition.isEmpty)
        #expect(data.notesByDecade.isEmpty)
        #expect(data.totalSourceNotes == 0)
        #expect(data.volumesCovered == 0)
        #expect(data.decadeRangeShown == nil)
        #expect(data.prewarExcludedNoteCount == 0)
        #expect(data.shownNoteCount == 0)
    }

    @Test("SourceProvenanceData: an all-pre-1900 index shows nothing but still safe")
    func allPre1900Safe() {
        let index = SourceProvenanceIndex(
            schemaVersion: 1, generated: "2026-07-04",
            totalSourceNotes: 10, volumesCovered: 1,
            categories: SourceProvenanceCategory.ordered.map(\.rawValue),
            byDecade: [DecadeProvenance(decade: 1840, totalNotes: 10, volumeCount: 1,
                                        counts: ["unrecognized": 10])]
        )
        let data = SourceProvenanceData(index: index)
        #expect(data.shareByDecade.isEmpty)
        #expect(data.decadeRangeShown == nil)
        #expect(data.prewarExcludedNoteCount == 10)
    }

    // MARK: Integration — the bundled artifact

    /// Guards that the real `source-provenance-index.json` is bundled and matches
    /// the schema, with the SA-3a headline figures. This proves the resource is in
    /// the built product and decodes via `SourceProvenanceIndex`.
    @Test("Bundled source-provenance-index.json decodes with the expected headline figures")
    func bundledArtifactDecodes() throws {
        let url = try #require(
            Bundle.main.url(forResource: "source-provenance-index", withExtension: "json"),
            "source-provenance-index.json must be bundled as an app resource"
        )
        let data = try Data(contentsOf: url)
        let index = try JSONDecoder().decode(SourceProvenanceIndex.self, from: data)
        #expect(index.schemaVersion == 2, "schema 2 adds byVolume (#267)")
        // These were unchanged across the schema-2 regeneration, which was the evidence that
        // adding the per-volume table was additive: the same scan, one more view of it. They moved
        // at OH PR #460, when FRUS 1981–1988 vol. XVI added 491 source notes across one volume —
        // 268,757 → 269,248 and 522 → 523, which reconciles exactly to that volume's own count.
        // Then 269,248 → 269,242 at corpus 1995d4485 (2026-09-14), when OH stopped marking six
        // attachment classification lines in that volume as `type="source"` (491 → 485 notes).
        #expect(index.totalSourceNotes == 269242)
        #expect(index.volumesCovered == 523)
        #expect(index.byVolume?.count == 523,
                "schema 2 must carry one row per covered volume; got \(index.byVolume?.count ?? -1)")
        #expect(index.byDecade.count == 16, "SA-3a ships 16 coverage decades; got \(index.byDecade.count)")
        #expect(index.categories.count == 11)
        #expect(index.categories == SourceProvenanceCategory.ordered.map(\.rawValue),
                "the artifact's category order is the enum's; got \(index.categories)")

        // The derivation over the real data floors to >= 1900 and stays sound.
        let derived = SourceProvenanceData(index: index)
        #expect(derived.decadeRangeShown?.lowerBound == 1900)
        #expect(!derived.shareByDecade.isEmpty)
        for decade in Set(derived.shareByDecade.map(\.decade)) {
            let sum = derived.shareByDecade.filter { $0.decade == decade }.reduce(0.0) { $0 + $1.share }
            #expect(abs(sum - 1.0) < 1e-6, "real decade \(decade) shares summed to \(sum)")
        }
    }

    // MARK: The Subject-Numeric File in the bundled index (#1543)

    /// The bundled index, decoded.
    private func bundledIndex() throws -> SourceProvenanceIndex {
        let url = try #require(
            Bundle.main.url(forResource: "source-provenance-index", withExtension: "json"))
        return try JSONDecoder().decode(SourceProvenanceIndex.self, from: Data(contentsOf: url))
    }

    /// The Subject-Numeric File ran February 1963–1973, so its citations fall in the volumes
    /// covering the 1960s and 1970s and in no other decade. Before #1543 the category did not
    /// exist and these notes sat in `centralDecimalFile` and `naraCollection`.
    @Test("The bundled index places the Subject-Numeric File in the 1960s and 1970s only")
    func subjectNumericFileSitsInItsDecades() throws {
        let index = try bundledIndex()
        var entered = 0
        for decade in index.byDecade {
            entered += 1
            let count = decade.count(for: .subjectNumericFile)
            if decade.decade == 1960 || decade.decade == 1970 {
                #expect(count > 0, "the \(decade.decade)s carry no Subject-Numeric notes")
            } else {
                #expect(count == 0, "the \(decade.decade)s carry \(count) Subject-Numeric notes")
            }
        }
        #expect(entered == 16, "read \(entered) decades")
    }

    /// The Central Foreign Policy File began in July 1973. No note is placed in it before the
    /// decade its first volumes cover.
    ///
    /// The first two assertions are a PIN, not a guard for #1543: they held on the artifact
    /// before the change too (it had 2,466 such notes in the 1970s, 712 in the 1980s and none
    /// earlier). Only the last one depends on #1543 — in the 1960s the Subject-Numeric File
    /// holds more notes than Other NARA Collections, which held those citations before.
    @Test("The bundled index places no Central Foreign Policy File note before the 1970s")
    func foreignPolicyFileStartsInTheSeventies() throws {
        let index = try bundledIndex()
        let before = index.byDecade.filter { $0.decade < 1970 }
        #expect(before.count == 14, "read \(before.count) decades before 1970")
        for decade in before {
            #expect(decade.count(for: .centralForeignPolicyFile) == 0,
                    "the \(decade.decade)s carry Central Foreign Policy File notes")
        }
        #expect(index.byDecade.first { $0.decade == 1970 }?.count(for: .centralForeignPolicyFile) ?? 0 > 0)
        // The category that used to hold the 1960s' National-Archives-led Subject-Numeric
        // citations now holds fewer notes there than the Subject-Numeric File does.
        let sixties = try #require(index.byDecade.first { $0.decade == 1960 })
        #expect(sixties.count(for: .subjectNumericFile) > sixties.count(for: .naraCollection))
    }

    /// The Categories menu's VoiceOver value read "%lld of 10 shown" from a literal. It is now
    /// the count of `SourceProvenanceCategory.ordered` (#1543).
    ///
    /// The value is built inside a view body, so this reads the CALL that builds it: the text
    /// between the parentheses of the `String(format:` that carries the key, with its whitespace
    /// removed. Both arguments must be the enum's count — a literal `11` there reads the same on
    /// screen today and is the defect again at the twelfth category, and no runtime check can
    /// tell the two apart.
    @Test("The dashboard's category count is derived, not the literal ten")
    func dashboardCategoryCountIsDerived() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appending(path: "FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift"),
            encoding: .utf8)
        #expect(!source.isEmpty)
        #expect(!source.contains("of 10 shown"), "the literal count is back")
        #expect(!source.contains("ten broad categories"), "the archival link still counts ten")
        #expect(!source.contains("ten provenance"), "a comment still counts ten categories")
        #expect(source.components(separatedBy: "eleven broad categories").count - 1 == 2,
                "both platform arms of the archival link carry the sentence")

        let opening = "String(format: String(localized: \"series.provenance.filter.a11y.count %lld %lld\""
        #expect(source.components(separatedBy: opening).count - 1 == 1, "the count text is built once")
        let call = try #require(Self.call(in: source, opening: opening))
        let wanted = "format:String(localized:\"series.provenance.filter.a11y.count%lld%lld\","
            + "defaultValue:\"%1$lldof%2$lldshown\"),"
            + "Int64(SourceProvenanceCategory.ordered.count-hiddenCategories.count),"
            + "Int64(SourceProvenanceCategory.ordered.count)"
        #expect(call == wanted, "the count text's arguments are \(call)")
    }

    // MARK: The charts' colour scale (#1543, landing round 2)

    /// The ten categories the charts had before the Subject-Numeric File, in the order they had:
    /// `SourceProvenanceCategory.ordered` on the base this lane was cut from.
    private static let categoriesBeforeSubjectNumeric: [SourceProvenanceCategory] = [
        .centralDecimalFile, .centralForeignPolicyFile, .lotFile, .presidentialLibrary,
        .naraCollection, .intelligence, .namedFileSeries, .foreignArchive, .previouslyPublished,
        .unrecognized,
    ]

    /// Swift Charts' default cycle, which a chart with a domain and no range takes by position.
    /// Measured by drawing one: on macOS 27.0 and the iOS 26.4 and 26.5 simulators the sixth
    /// colour is `Color.teal` (0, 195, 208 in light mode), not `.cyan` (0, 192, 232).
    private static let defaultCycle: [Color] = [.blue, .green, .orange, .purple, .red, .teal, .yellow]

    /// Until this scale the charts passed a domain and no range, so an eleventh category in second
    /// place moved every later category one colour along the cycle, and Named File Series took
    /// the Central Decimal File's blue.
    @Test("Each older category keeps the colour its position gave it, and the new one has its own")
    func olderCategoriesKeepTheirColours() {
        let older = Self.categoriesBeforeSubjectNumeric
        #expect(older.count == 10)
        #expect(Set(older).union([.subjectNumericFile]) == Set(SourceProvenanceCategory.allCases),
                "the ten older categories and the Subject-Numeric File are every category")
        for (position, category) in older.enumerated() {
            #expect(category.chartColor == Self.defaultCycle[position % Self.defaultCycle.count],
                    "\(category.rawValue) is no longer the colour of position \(position + 1) of ten")
        }

        let new = SourceProvenanceCategory.subjectNumericFile.chartColor
        #expect(new == .brown)
        for category in older {
            #expect(category.chartColor != new, "\(category.rawValue) shares the new category's colour")
        }
        #expect(!Self.defaultCycle.contains(new), "the new category's colour is one the cycle uses")

        // The scale the charts read: eleven entries, the enum's order, each category's colour.
        let scale = SourceProvenanceCategory.chartColorScale
        #expect(scale.domain.count == 11 && scale.range.count == 11)
        #expect(scale.domain == SourceProvenanceCategory.ordered.map(\.displayName))
        #expect(scale.range == SourceProvenanceCategory.ordered.map(\.chartColor))
        #expect(scale.domain[1] == "Subject-Numeric File", "the legend's second entry")
        #expect(scale.range[1] == .brown)
    }

    /// One bar of `category`, coloured by its display name the way the provenance charts colour
    /// theirs: through the scale they call, or through the ten-name domain with no range that
    /// they passed before the Subject-Numeric File.
    @MainActor @ViewBuilder
    private static func bar(of category: SourceProvenanceCategory, statedScale: Bool) -> some View {
        let chart = Chart {
            BarMark(x: .value("Provenance", category.displayName), y: .value("Source notes", 1))
                .foregroundStyle(by: .value("Provenance", category.displayName))
        }
        .chartLegend(.hidden)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        if statedScale {
            chart.provenanceCategoryColorScale()
        } else {
            chart.chartForegroundStyleScale(domain: categoriesBeforeSubjectNumeric.map(\.displayName))
        }
    }

    /// The colour at the middle of that bar, drawn 60 points square.
    @MainActor
    private static func drawnColour(of category: SourceProvenanceCategory, statedScale: Bool,
                                    scheme: ColorScheme) throws -> [UInt8] {
        let view = bar(of: category, statedScale: statedScale)
            .frame(width: 60, height: 60)
            .environment(\.colorScheme, scheme)
        let image = try RenderedText.image(of: view, width: 60, scale: 1)
        let pixels = try RenderedText.pixels(of: image)
        let middle = ((image.height / 2) * image.width + image.width / 2) * 4
        return Array(pixels[middle..<middle + 3])
    }

    /// The same claim read off drawn charts, so it does not rest on the cycle this file states:
    /// each older category, drawn through the scale, is the colour a ten-category chart with no
    /// range draws it in. That reference chart is what the app shipped.
    @MainActor
    @Test("Drawn, each older category is the colour a ten-category chart with no range gave it",
          arguments: [ColorScheme.light, ColorScheme.dark])
    func drawnColoursAreTheDefaultCycle(scheme: ColorScheme) throws {
        var drawn: [SourceProvenanceCategory: [UInt8]] = [:]
        for category in Self.categoriesBeforeSubjectNumeric {
            let before = try Self.drawnColour(of: category, statedScale: false, scheme: scheme)
            let now = try Self.drawnColour(of: category, statedScale: true, scheme: scheme)
            #expect(now == before, "\(category.rawValue) was \(before) and is \(now)")
            drawn[category] = now
        }
        // The drawing drew: ten bars in the cycle's seven colours, none of them the white the
        // image is laid on.
        #expect(drawn.count == 10)
        #expect(Set(drawn.values).count == 7, "the ten bars are in \(Set(drawn.values).count) colours")
        #expect(!drawn.values.contains([255, 255, 255]))

        let new = try Self.drawnColour(of: .subjectNumericFile, statedScale: true, scheme: scheme)
        #expect(new != [255, 255, 255])
        for (category, colour) in drawn {
            #expect(colour != new, "\(category.rawValue) is drawn in the Subject-Numeric File's colour")
        }
    }

    /// Every chart that colours its marks by provenance category calls the one scale, and none
    /// states a scale of its own.
    ///
    /// The marks are found by the legend key their `.foregroundStyle(by:)` call carries — the
    /// dashboard's and Your Library's — and counted against the calls of
    /// `.provenanceCategoryColorScale()` in the same file. Nothing ties one mark to one call but
    /// the count, so a chart added without the scale, or a scale left on a chart that lost its
    /// marks, moves one count and not the other.
    @Test("Every chart coloured by provenance category takes the one scale")
    func everyProvenanceChartTakesTheScale() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let legendKeys = ["\"series.provenance.category.legend\"", "\"archival.table.provenance\""]
        let expected = [
            "FRUSExplorer/SeriesAnalytics/SourceProvenanceDashboard.swift": 2,
            "FRUSExplorer/Analytics/ArchivalAnalyticsView.swift": 2,
        ]

        var marksByFile: [String: Int] = [:]
        var ownScales: [String] = []
        var filesRead = 0
        let appRoot = root.appending(path: "FRUSExplorer")
        let walker = try #require(FileManager.default.enumerator(at: appRoot, includingPropertiesForKeys: nil))
        for case let url as URL in walker where url.pathExtension == "swift" {
            filesRead += 1
            let source = try String(contentsOf: url, encoding: .utf8)
            let path = "FRUSExplorer/" + url.path.dropFirst(appRoot.path.count + 1)
            let marks = Self.calls(in: source, opening: ".foregroundStyle(by:")
                .filter { call in legendKeys.contains { call.contains($0) } }
            if !marks.isEmpty { marksByFile[path] = marks.count }
            for call in Self.calls(in: source, opening: ".chartForegroundStyleScale(")
            where call.contains("SourceProvenanceCategory") {
                ownScales.append("\(path): \(call)")
            }
        }
        #expect(filesRead > 300, "read \(filesRead) Swift files under FRUSExplorer/")
        #expect(marksByFile == expected, "marks coloured by provenance category are in \(marksByFile)")
        #expect(ownScales.isEmpty, "a chart states its own scale over the categories: \(ownScales)")

        for (path, charts) in expected {
            let source = try String(contentsOf: root.appending(path: path), encoding: .utf8)
            let calls = source.components(separatedBy: ".provenanceCategoryColorScale()").count - 1
            #expect(calls == charts, "\(path) applies the scale \(calls) times to \(charts) charts")
        }
    }

    /// The scan's reader against a mark, a scale of its own, and an unclosed call.
    @Test("The chart scan reads each call's arguments")
    func chartScanReadsEachCall() {
        let source = """
            Chart {
                BarMark(x: .value("x", item.name))
                    .foregroundStyle(by: .value(
                        String(localized: "archival.table.provenance", defaultValue: "Provenance"),
                        item.category.displayName))
            }
            .chartForegroundStyleScale(
                domain: SourceProvenanceCategory.ordered.map(\\.displayName))
            .foregroundStyle(by: .value("Custodian", row.category.displayName))
            """
        let marks = Self.calls(in: source, opening: ".foregroundStyle(by:")
        #expect(marks.count == 2)
        #expect(marks.filter { $0.contains("\"archival.table.provenance\"") }.count == 1)
        let scales = Self.calls(in: source, opening: ".chartForegroundStyleScale(")
        #expect(scales == ["domain:SourceProvenanceCategory.ordered.map(\\.displayName)"])
        #expect(Self.calls(in: ".foregroundStyle(by: .value(\"k\", x)", opening: ".foregroundStyle(by:").isEmpty,
                "an unclosed call is not a call")
    }

    /// The arguments of every call in `source` that begins with `opening`, whitespace removed.
    /// `opening` ends at or after the call's opening parenthesis; an unclosed call is left out.
    private static func calls(in source: String, opening: String) -> [String] {
        var found: [String] = []
        var from = source.startIndex
        while let hit = source.range(of: opening, range: from..<source.endIndex) {
            from = hit.upperBound
            guard let open = source[hit].lastIndex(of: "(") else { continue }
            var depth = 0
            var index = open
            var close: String.Index?
            while index < source.endIndex {
                if source[index] == "(" { depth += 1 }
                if source[index] == ")" {
                    depth -= 1
                    if depth == 0 { close = index; break }
                }
                index = source.index(after: index)
            }
            guard let close else { continue }
            found.append(String(source[source.index(after: open)..<close].filter { !$0.isWhitespace }))
        }
        return found
    }

    /// The scan's own reader, against the two mutants it exists for and a call split another way.
    @Test("The call scan reads the whole call and tells a literal total from the derived one")
    func callScanReadsTheArguments() throws {
        let opening = "String(format: String(localized: \"k %lld %lld\""
        let derived = """
            .accessibilityValue(String(format: String(localized: "k %lld %lld",
                                                      defaultValue: "%1$lld of %2$lld shown"),
                                       Int64(Category.ordered.count - hidden.count),
                                       Int64(Category.ordered.count)))
            """
        #expect(try #require(Self.call(in: derived, opening: opening))
                == "format:String(localized:\"k%lld%lld\",defaultValue:\"%1$lldof%2$lldshown\"),"
                + "Int64(Category.ordered.count-hidden.count),Int64(Category.ordered.count)")
        let literal = derived.replacingOccurrences(of: "Int64(Category.ordered.count)))", with: "Int64(11)))")
        #expect(try #require(Self.call(in: literal, opening: opening)).hasSuffix(",Int64(11)"))
        #expect(Self.call(in: "no such call", opening: opening) == nil)
        #expect(Self.call(in: opening + ", unclosed", opening: opening) == nil)
    }

    /// The arguments of the call that begins with `opening` — everything between the parenthesis
    /// `opening` first opens and the one that closes it — with all whitespace removed, or `nil`
    /// when `source` has no such call or never closes it. Parentheses inside string literals are
    /// not skipped: the texts this reads carry none.
    private static func call(in source: String, opening: String) -> String? {
        guard let hit = source.range(of: opening),
              let open = source[hit].firstIndex(of: "(") else { return nil }
        var depth = 0
        var index = open
        while index < source.endIndex {
            switch source[index] {
            case "(": depth += 1
            case ")":
                depth -= 1
                if depth == 0 {
                    return String(source[source.index(after: open)..<index].filter { !$0.isWhitespace })
                }
            default: break
            }
            index = source.index(after: index)
        }
        return nil
    }

    // MARK: Category filter (#236)

    /// The full coverage-year domain (well past the shown decades) so decade filtering
    /// never confounds the category-exclusion assertions.
    private var allDecades: ClosedRange<Int> { 1900...2000 }

    @Test("category filter: empty exclusion set is identity")
    func categoryFilterEmptyIsIdentity() {
        let data = SourceProvenanceData(index: fixture())
        let filtered = data.shareByDecade(in: allDecades, excluding: [])
        let plain = data.shareByDecade(in: allDecades)
        #expect(filtered.map(\.id) == plain.map(\.id))
        #expect(filtered.map(\.share) == plain.map(\.share))
        #expect(data.overallComposition(excluding: []).map(\.category)
                == data.overallComposition.map(\.category))
    }

    @Test("category filter: hidden category is removed and remaining shares renormalize to 1.0")
    func categoryFilterRenormalizes() {
        let data = SourceProvenanceData(index: fixture())
        // 1950 raw (known) counts: centralDecimalFile 40, lotFile 20, presidentialLibrary 20.
        // Hide presidentialLibrary → shown total 60 → cdf 40/60, lot 20/60.
        let filtered = data.shareByDecade(in: allDecades, excluding: [.presidentialLibrary])
        let d1950 = filtered.filter { $0.decade == 1950 }
        #expect(!d1950.contains { $0.category == .presidentialLibrary })
        let cdf = d1950.first { $0.category == .centralDecimalFile }?.share ?? 0
        let lot = d1950.first { $0.category == .lotFile }?.share ?? 0
        #expect(abs(cdf - 40.0 / 60.0) < 1e-9)
        #expect(abs(lot - 20.0 / 60.0) < 1e-9)
        // Every shown decade still sums to 1.0 across the shown categories.
        for decade in Set(filtered.map(\.decade)) {
            let sum = filtered.filter { $0.decade == decade }.reduce(0.0) { $0 + $1.share }
            #expect(abs(sum - 1.0) < 1e-9, "decade \(decade) filtered shares summed to \(sum)")
        }
    }

    @Test("category filter: an all-zero decade emits explicit zero rows (no x-gap for AreaMark to interpolate)")
    func categoryFilterEmitsZeroRowsForEmptyDecade() {
        let data = SourceProvenanceData(index: fixture())
        // 1910 is 100% centralDecimalFile; hiding it leaves that decade with no shown
        // notes. The decade must still be present with zero shares — dropping it would
        // leave an interior x-gap that the stacked AreaMark linearly interpolates
        // across, fabricating a band between its neighbours (Session 3 review).
        let filtered = data.shareByDecade(in: allDecades, excluding: [.centralDecimalFile])
        let d1910 = filtered.filter { $0.decade == 1910 }
        #expect(!d1910.isEmpty)
        #expect(d1910.allSatisfy { $0.share == 0 })
        #expect(!d1910.contains { $0.category == .centralDecimalFile })
        // 1970 (presidentialLibrary + CFPF) is unaffected and still sums to 1.0.
        let d1970 = filtered.filter { $0.decade == 1970 }
        #expect(abs(d1970.reduce(0.0) { $0 + $1.share } - 1.0) < 1e-9)
    }

    @Test("category filter: overallComposition renormalizes over shown categories, hidden dropped")
    func overallCompositionFilter() {
        let data = SourceProvenanceData(index: fixture())
        let filtered = data.overallComposition(excluding: [.unrecognized])
        #expect(!filtered.contains { $0.category == .unrecognized })
        // Shown categories' shares sum to 1.0 (categories with zero notes contribute 0).
        let sum = filtered.reduce(0.0) { $0 + $1.share }
        #expect(abs(sum - 1.0) < 1e-9)
        // Stable order preserved (subsequence of the canonical order).
        let order = SourceProvenanceCategory.ordered
        let idx = filtered.map { order.firstIndex(of: $0.category)! }
        #expect(idx == idx.sorted())
    }
}
