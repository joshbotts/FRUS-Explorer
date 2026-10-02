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
import SwiftUI
import Testing
@testable import FRUSExplorer

// MARK: - StoredProvenanceCategoryTests

/// `SourceProvenanceCategory.from(citationEra:repository:)` — the inverse of what
/// `IndexingPipeline.baseDocumentSourceRow` writes (#765 rider E).
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 1
@Suite("Archival analytics — stored rows map back to provenance categories")
struct StoredProvenanceCategoryTests {

    @Test("Every citation form the indexer writes maps back to the category it came from")
    func everyWrittenFormRoundTrips() {
        // Mirrors every form `baseDocumentSourceRow` writes. If a form is added there and not
        // here, it falls to `unrecognized` and the composition card quietly reports it as
        // unclassified.
        let expected: [(era: String, repository: String?, category: SourceProvenanceCategory)] = [
            ("decimal", "Department of State", .centralDecimalFile),
            // #1543: a central-files form names its category whoever the row says holds the
            // record. A Subject-Numeric citation is stored `subject_numeric` in both wordings,
            // and a decimal number cited through the National Archives is stored `decimal`.
            ("subject_numeric", "Department of State", .subjectNumericFile),
            ("subject_numeric", "National Archives", .subjectNumericFile),
            ("decimal", "National Archives", .centralDecimalFile),
            ("lot_file", "Department of State", .lotFile),
            ("structured", "National Archives", .naraCollection),
            ("structured", "Johnson Library", .presidentialLibrary),
            ("structured", "Central Intelligence Agency", .intelligence),
            ("foreign", nil, .foreignArchive),
            ("published", nil, .previouslyPublished),
            ("cfpf", "Department of State", .centralForeignPolicyFile),
            ("named_series", nil, .namedFileSeries),
            ("unrecognized", nil, .unrecognized),
        ]
        for row in expected {
            #expect(SourceProvenanceCategory.from(citationEra: row.era,
                                                  repository: row.repository) == row.category,
                    "(\(row.era), \(row.repository ?? "nil")) did not map to \(row.category)")
        }
    }

    @Test("`structured` alone is ambiguous — the repository is what splits it three ways")
    func structuredNeedsTheRepository() {
        // The single most load-bearing detail of the mapping: three provenance categories share
        // one citation_era. Grouping the library card by citation_era alone would collapse every
        // presidential library, every NARA record group, and the CIA into one segment.
        let splits = Set([
            SourceProvenanceCategory.from(citationEra: "structured", repository: "National Archives"),
            SourceProvenanceCategory.from(citationEra: "structured", repository: "Ford Library"),
            SourceProvenanceCategory.from(citationEra: "structured",
                                          repository: "Central Intelligence Agency"),
        ])
        #expect(splits.count == 3)
        // An unattributed structured row is a library citation by elimination — that is what the
        // writer's `.presidentialLibrary` case does with a repository it did not canonicalise.
        #expect(SourceProvenanceCategory.from(citationEra: "structured",
                                              repository: nil) == .presidentialLibrary)
    }

    @Test("An unknown form is classified, not dropped")
    func unknownFormsAreClassified() {
        #expect(SourceProvenanceCategory.from(citationEra: "footnote",
                                              repository: nil) == .unrecognized, """
            Every row in document_sources is a real source note. Returning nil for an \
            unrecognised form would let the totals the card presents as complete silently \
            shrink — and `footnote` is precisely the value an index built before #783 still \
            holds until it is re-opened.
            """)
    }
}

// MARK: - ArchivalLibraryProfileTests

/// The Your Library fold (#765 rider E).
///
/// Version history:
///   1.0 — Session 2026-08-09: #765 stage 1
///   1.1 — 2026-10-02 (#1543, landing round 2): the composition chart is drawn at an iPhone's
///          width and a wide one, and its bar measured
@Suite("Archival analytics — your library profile")
struct ArchivalLibraryProfileTests {

    private func group(_ volumeId: String, _ era: String, _ repository: String?,
                       _ count: Int) -> IndexingPipeline.ArchivalLibraryGroup {
        IndexingPipeline.ArchivalLibraryGroup(volumeId: volumeId, citationEra: era,
                                              repository: repository, documentCount: count)
    }

    private func coverage(_ pairs: [(String, Int)]) -> [String: ArchivalVolumeCoverage] {
        var result: [String: ArchivalVolumeCoverage] = [:]
        for (id, year) in pairs {
            result[id] = ArchivalVolumeCoverage(firstYear: year, lastYear: year)
        }
        return result
    }

    @Test("An empty index yields the empty profile, not a zero-filled chart")
    func emptyIndex() {
        let profile = ArchivalLibraryProfile.make(groups: [], collectionGroups: [],
                                                  coverage: [:], authority: nil)
        #expect(profile.isEmpty)
        #expect(profile.composition.isEmpty)
        #expect(profile.bands.isEmpty)
    }

    @Test("Totals count notes and note-carrying volumes, and bands split them by coverage")
    func totalsAndBands() {
        let groups = [
            group("v1", "decimal", "Department of State", 100),
            group("v1", "lot_file", "Department of State", 20),
            group("v2", "structured", "Nixon", 300),
        ]
        let profile = ArchivalLibraryProfile.make(
            groups: groups, collectionGroups: [],
            coverage: coverage([("v1", 1950), ("v2", 1972)]), authority: nil)
        #expect(profile.noteCount == 420)
        #expect(profile.volumeCount == 2)
        #expect(profile.composition.map(\.documentCount) == [300, 100, 20],
                "composition is heaviest-first")
        #expect(profile.bands.count == 2)
        #expect(profile.bands.map(\.band.index) == [1, 3], "bands stay in era order")
        #expect(profile.bands[0].documentCount == 120)
        #expect(profile.bands[0].volumeCount == 1)
        #expect(profile.centralFileNoteCount == 100)
    }

    /// #1543: the collections card says how many notes cite the central files and are therefore
    /// not listed. That count is the three central filing systems together; before the
    /// Subject-Numeric File had a category it was two.
    @Test("The central-file count is the three central filing systems together")
    func centralFileCountCoversThreeSystems() {
        let profile = ArchivalLibraryProfile.make(
            groups: [
                group("v1", "decimal", "Department of State", 1),
                group("v2", "subject_numeric", "National Archives", 1),
                group("v3", "cfpf", "Department of State", 1),
                // Not a central file: a NARA collection, and a lot.
                group("v2", "structured", "National Archives", 1),
                group("v1", "lot_file", "Department of State", 1),
            ],
            collectionGroups: [], coverage: coverage([("v1", 1950), ("v2", 1965), ("v3", 1975)]),
            authority: nil)
        #expect(profile.noteCount == 5)
        #expect(profile.centralFileNoteCount == 3, """
            decimal + Subject-Numeric + Central Foreign Policy File; got \(profile.centralFileNoteCount). \
            Leaving the Subject-Numeric File out would have the caption say fewer notes cite the \
            central files than the composition above it shows.
            """)
        // One fixture per term: each system alone is counted.
        for era in ["decimal", "subject_numeric", "cfpf"] {
            let alone = ArchivalLibraryProfile.make(
                groups: [group("v1", era, "Department of State", 4)],
                collectionGroups: [], coverage: [:], authority: nil)
            #expect(alone.centralFileNoteCount == 4, "\(era) alone counted \(alone.centralFileNoteCount)")
        }
        // The Subject-Numeric segment sits between the other two central segments in a band.
        let band = ArchivalLibraryProfile.make(
            groups: [
                group("v1", "cfpf", "Department of State", 1),
                group("v1", "subject_numeric", "Department of State", 1),
                group("v1", "decimal", "Department of State", 1),
            ],
            collectionGroups: [], coverage: coverage([("v1", 1972)]), authority: nil)
        #expect(band.bands.first?.categories.map(\.category)
                == [.centralDecimalFile, .subjectNumericFile, .centralForeignPolicyFile])
    }

    @Test("A volume whose coverage is unknown still counts in the totals, just not in a band")
    func unknownCoverageStillCounts() {
        let profile = ArchivalLibraryProfile.make(
            groups: [group("mystery", "lot_file", "Department of State", 7)],
            collectionGroups: [], coverage: [:], authority: nil)
        #expect(profile.noteCount == 7, """
            A volume missing from the manifest must not vanish from the library total — the \
            intro line calls that total the reader's whole index.
            """)
        #expect(profile.bands.isEmpty)
    }

    @Test("Band segments keep a fixed category order, so the card can be read across")
    func bandSegmentsAreOrdered() {
        let profile = ArchivalLibraryProfile.make(
            groups: [
                group("v1", "structured", "Ford Library", 500),
                group("v1", "decimal", "Department of State", 3),
            ],
            collectionGroups: [], coverage: coverage([("v1", 1972)]), authority: nil)
        let categories = profile.bands.first?.categories.map(\.category) ?? []
        let described = categories.map(String.init(describing:)).joined(separator: ", ")
        #expect(categories == [.centralDecimalFile, .presidentialLibrary], """
            The segments came back as [\(described)]. Sorting each band's stack by size would \
            reorder the colours band to band, and this card is read as one shape across the bands.
            """)
    }

    // MARK: - Collection resolution

    private func authorityIndex(_ records: [AuthorityCollectionRecord]) throws
        -> CollectionAuthorityIndex {
        let payload: [String: Any] = [
            "schemaVersion": 1,
            "generated": "2026-08-09",
            "collections": records.map { record -> [String: Any] in
                var row: [String: Any] = ["id": record.id, "name": record.name]
                if let repository = record.repository { row["repository"] = repository }
                if let lot = record.lotFileNorm { row["lotFileNorm"] = lot }
                if !record.volumeIds.isEmpty { row["volumeIds"] = record.volumeIds }
                return row
            },
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(CollectionAuthorityIndex.self, from: data)
    }

    @Test("Collections resolve by lot key and by repository plus leading segment, and sum")
    func collectionsResolveAndSum() throws {
        let lot = AuthorityCollectionRecord(id: "lot:63D351", name: "S/S–NSC Files",
                                            repository: "Department of State",
                                            lotFileNorm: "63D351")
        let library = AuthorityCollectionRecord(id: "txt:johnson library|national security file",
                                                name: "National Security File",
                                                repository: "Johnson Library")
        let index = try authorityIndex([lot, library])
        let groups = [
            IndexingPipeline.ArchivalLibraryCollectionGroup(
                lotFileNorm: "63D351", repository: "Department of State",
                seriesName: "S/S–NSC Files", documentCount: 40),
            // A second stored group for the same collection — a different box, same records.
            IndexingPipeline.ArchivalLibraryCollectionGroup(
                lotFileNorm: "63D351", repository: "Department of State",
                seriesName: "S/S–NSC Files, Box 12", documentCount: 5),
            IndexingPipeline.ArchivalLibraryCollectionGroup(
                lotFileNorm: nil, repository: "Johnson Library",
                seriesName: "National Security File, Country File, Vietnam",
                documentCount: 60),
        ]
        let profile = ArchivalLibraryProfile.make(
            groups: [group("v1", "lot_file", "Department of State", 45)],
            collectionGroups: groups, coverage: coverage([("v1", 1965)]), authority: index)
        #expect(profile.collections.map(\.id) == ["txt:johnson library|national security file",
                                                  "lot:63D351"])
        #expect(profile.collections.map(\.documentCount) == [60, 45], """
            The two lot groups must sum onto one record — a citation naming a different box is \
            the same body of records.
            """)
        #expect(profile.unresolvedCollectionNoteCount == 0)
    }

    @Test("A library citation never resolves onto a State lot cluster")
    func libraryCitationsDoNotBridgeToLots() throws {
        // #351: a Carter Library "Presidential Files" note resolved to `lot:66D204` through the
        // shared alias grammar, offering the reader a confidently wrong archive.
        let lot = AuthorityCollectionRecord(id: "lot:66D204", name: "Presidential Files",
                                            repository: "Department of State",
                                            lotFileNorm: "66D204")
        let index = try authorityIndex([lot])
        let profile = ArchivalLibraryProfile.make(
            groups: [group("v1", "structured", "Carter Library", 9)],
            collectionGroups: [IndexingPipeline.ArchivalLibraryCollectionGroup(
                lotFileNorm: nil, repository: "Carter Library",
                seriesName: "Presidential Files", documentCount: 9)],
            coverage: coverage([("v1", 1978)]), authority: index)
        #expect(profile.collections.isEmpty, """
            Resolved to \(profile.collections.map(\.id)). A presidential-library citation must \
            never land on a State Department lot cluster.
            """)
        #expect(profile.unresolvedCollectionNoteCount == 9,
                "the notes are still counted — they are simply not attributed")
    }

    @Test("An unavailable authority reports every collection note as unresolved")
    func missingAuthorityIsDisclosed() {
        let profile = ArchivalLibraryProfile.make(
            groups: [group("v1", "lot_file", "Department of State", 3)],
            collectionGroups: [IndexingPipeline.ArchivalLibraryCollectionGroup(
                lotFileNorm: "63D351", repository: nil, seriesName: nil, documentCount: 3)],
            coverage: coverage([("v1", 1960)]), authority: nil)
        #expect(profile.collections.isEmpty)
        #expect(profile.unresolvedCollectionNoteCount == 3, """
            With no authority the list is empty for a reason the footer states, rather than \
            implying the reader's library cites nothing recognisable.
            """)
    }

    // MARK: The composition chart's height (#1543, landing round 2)

    /// A library with a source note in every one of the eleven categories, the heaviest first as
    /// `make` orders them. The first segment is a quarter of the bar, so a column a tenth of the
    /// way across is inside it at any width.
    private static let everyCategoryProfile = ArchivalLibraryProfile(
        noteCount: 400, volumeCount: 5,
        composition: SourceProvenanceCategory.ordered.enumerated().map { index, category in
            ArchivalLibraryCategoryCount(category: category, documentCount: index == 0 ? 100 : 30)
        },
        bands: [], collections: [], centralFileNoteCount: 0, unresolvedCollectionNoteCount: 0)

    /// The composition chart drawn `width` points wide at its own height: the drawing's height,
    /// and the height of the bar — the longest run of coloured pixels down the column a tenth of
    /// the way across. A legend swatch is a dot some eight points high, so a run of twenty or
    /// more is the bar.
    @MainActor
    private static func drawnComposition(width: CGFloat) throws -> (height: Int, bar: Int) {
        let chart = ArchivalAnalyticsView.libraryCompositionChart(everyCategoryProfile)
        let image = try RenderedText.image(of: chart, width: width, scale: 1)
        let pixels = try RenderedText.pixels(of: image)
        let column = image.width / 10
        var longest = 0, run = 0
        for row in 0..<image.height {
            let at = (row * image.width + column) * 4
            let channels = [Int(pixels[at]), Int(pixels[at + 1]), Int(pixels[at + 2])]
            if channels.max()! - channels.min()! > 60 {
                run += 1
                longest = max(longest, run)
            } else {
                run = 0
            }
        }
        return (image.height, longest)
    }

    /// The chart's height was fixed at 120 points with its legend inside it. At an iPhone's width
    /// the eleven legend entries wrap to six rows and took all of it: the bar was a line one or
    /// two pixels high. 345 points is the card's width on an iPhone 17 (402 points wide).
    @MainActor
    @Test("At an iPhone's width the composition bar keeps its height under the legend")
    func compositionBarKeepsItsHeightUnderTheLegend() throws {
        let narrow = try Self.drawnComposition(width: 345)
        #expect(narrow.bar >= 20, "the bar is \(narrow.bar) points high in a chart of \(narrow.height)")
        #expect(narrow.height > 120, "the chart did not grow for its legend: \(narrow.height) points")
    }

    /// Where the legend leaves the plot its forty points the chart is the 120 points it was, so
    /// the Mac's and a full-width iPad's cards are unmoved.
    @MainActor
    @Test("At a wide width the composition chart rests at the height it had")
    func compositionChartRestsAtItsOldHeightWhenWide() throws {
        let wide = try Self.drawnComposition(width: 1000)
        #expect(wide.height == 120, "the chart is \(wide.height) points high at 1,000 wide")
        #expect(wide.bar >= 20, "the bar is \(wide.bar) points high")
    }

    /// The card draws the chart the two tests above draw, once, and that chart's height is a
    /// floor on its plot and a floor on itself: no fixed height bounds the legend.
    @MainActor
    @Test("The composition card draws the measured chart, and nothing fixes its height")
    func compositionCardDrawsTheMeasuredChart() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appending(path: "FRUSExplorer/Analytics/ArchivalAnalyticsView.swift"),
            encoding: .utf8)
        #expect(source.components(separatedBy: "Self.libraryCompositionChart(profile)").count - 1 == 1,
                "the card draws the chart once")

        let opening = "static func libraryCompositionChart(_ profile: ArchivalLibraryProfile) -> some View {"
        let start = try #require(source.range(of: opening))
        let end = try #require(source.range(of: "\n    }\n", range: start.upperBound..<source.endIndex))
        let body = String(source[start.upperBound..<end.lowerBound]).filter { !$0.isWhitespace }
        #expect(body.contains(".chartPlotStyle{plotin"
                              + "plot.frame(minHeight:libraryCompositionMinimumPlotHeight,"
                              + "idealHeight:libraryCompositionMinimumPlotHeight,"
                              + "maxHeight:.infinity)}"),
                "the plot's floor is gone")
        #expect(body.hasSuffix(".frame(minHeight:libraryCompositionRestingHeight)"),
                "the chart's last modifier is not its resting height")
        #expect(!body.contains(".frame(height:"), "a fixed height bounds the chart and its legend again")
        #expect(ArchivalAnalyticsView.libraryCompositionMinimumPlotHeight == 40)
        #expect(ArchivalAnalyticsView.libraryCompositionRestingHeight == 120)
    }
}
