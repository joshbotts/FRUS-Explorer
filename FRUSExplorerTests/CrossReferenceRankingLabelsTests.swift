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
        #expect(codes["frus1955-57v2"] == "’55–57 II")
    }

    /// A multi-letter numeral in a title that also carries a topic and trailing dates.
    @Test("Multi-letter numeral, dates ignored")
    func multiLetterNumeral() {
        let codes = matrixColumnCodes([
            (id: "frus1961-63v14", subseries: "1961-63",
             title: "Foreign Relations of the United States, 1961–1963, Volume XIV, Berlin Crisis, 1961–1962",
             topic: "Berlin Crisis")
        ])
        #expect(codes["frus1961-63v14"] == "’61–63 XIV")
    }

    /// A single-year annual volume with no numeral and no topic reduces to just the year.
    @Test("Single year, no numeral, no topic")
    func singleYearBare() {
        let codes = matrixColumnCodes([
            (id: "frus1861", subseries: "1861",
             title: "Papers Relating to Foreign Affairs, 1861", topic: "")
        ])
        #expect(codes["frus1861"] == "’61")
    }

    /// No "Volume N" numeral but a topic → span + the first distinctive word, truncated to ≤6 chars.
    @Test("No numeral falls back to a truncated topic word")
    func noNumeralTopicWord() {
        let codes = matrixColumnCodes([
            (id: "frusX", subseries: "1958-60",
             title: "Some Compilation Without A Volume Numeral", topic: "Western Europe")
        ])
        #expect(codes["frusX"] == "’58–60 Wester")
    }

    /// A leading article/preposition is skipped so the chosen word is distinctive.
    @Test("Leading stopword is dropped for the topic word")
    func leadingStopwordDropped() {
        let codes = matrixColumnCodes([
            (id: "frusY", subseries: "1948",
             title: "An Annual Compilation", topic: "The Far East")
        ])
        #expect(codes["frusY"] == "’48 Far")
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
        #expect(codes["frus1863p1"] == "’63 p1")
        #expect(codes["frus1863p2"] == "’63 p2")
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
        #expect(codes["frusA"] == "’58–60 Wester Europe")
        #expect(codes["frusB"] == "’58–60 Wester Hemisp")
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
        #expect(codes["frus1945Berlinv02"] == "’45 II Confer")
        #expect(codes["frus1945v02"] == "’45 II Genera")
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
        #expect(codes["frus1952-54v2"] == "’52–54 II")
    }

    /// An empty column set yields an empty map (no crash on the no-data path).
    @Test("Empty input yields empty output")
    func emptyInput() {
        #expect(matrixColumnCodes([]).isEmpty)
    }
}

// MARK: - HeatMatrixRowAxisTests

/// The heat matrix's row axis (#1379): what a row label reads, and how wide the label column is.
///
/// ## What was wrong
/// A row label was the joined `distilledVolumeLabel` — its topic already cut to 40 characters —
/// in a fixed 150 pt column, truncated at the head to keep the tag. So the two Potsdam volumes,
/// whose shared topic is 49 characters, read "…rlin (The Potsdam… · 1945 v1" and "…rlin (The
/// Potsdam… · 1945 v2": cut at both ends, and alike but for the tag. The label is now the two
/// halves apart, the topic whole, and the view cuts the topic at its tail beside a tag it never
/// cuts; the column takes the width the window leaves, up to the exported figure's 320 pt.
///
/// The label and the width are pinned here against the functions the view calls. The layout —
/// no vertical scroll box, the labels outside the sideways scroll, the topic cut at its tail —
/// is pinned by reading the view's source, below, because this target cannot lay a view out. The
/// UI suite `CrossReferenceMatrixScrollTests` measures it on screen: the column's width against the
/// window, each label against its row of cells, and, on an iPhone, the cells scrolling sideways
/// beside labels that stay put.
///
/// Version history:
///   1.0 — #1379: initial implementation
///   1.1 — #1379 review round 1: the identifier pin reads the UI suite's own spelling
@Suite("Heat matrix row axis")
struct HeatMatrixRowAxisTests {

    /// The bundled manifest's entry for `volumeId`, or a recorded failure.
    @MainActor
    private func entry(_ volumeId: String) throws -> VolumeManifestEntry {
        let entries = ManifestStore().bundledEntries
        try #require(entries.count > 500, "the bundled manifest must load — an empty one makes this vacuous")
        return try #require(entries.first { $0.volumeId == volumeId }, "\(volumeId) is not in the bundled manifest")
    }

    @Test("The Potsdam volumes' rows keep their whole topic, cut at neither end, and differ in their tags")
    @MainActor
    func potsdamVolumesKeepTheirWholeTopic() throws {
        let first = HeatMatrixRowAxis.label(volumeId: "frus1945Berlinv01", entry: try entry("frus1945Berlinv01"))
        let second = HeatMatrixRowAxis.label(volumeId: "frus1945Berlinv02", entry: try entry("frus1945Berlinv02"))
        for (volumeId, label) in [("frus1945Berlinv01", first), ("frus1945Berlinv02", second)] {
            #expect(label.topic.hasPrefix("The Conference of Berlin"),
                    "\(volumeId)'s topic lost its first words: '\(label.topic)'")
            #expect(!label.topic.hasPrefix("…") && !label.topic.hasSuffix("…"),
                    "\(volumeId)'s topic arrives already cut — the view would cut it a second time: '\(label.topic)'")
            // Whole: the 49-character topic, not the 40-character cut the joined label makes.
            #expect(label.topic == "The Conference of Berlin (The Potsdam Conference)")
        }
        #expect(first.tag == "1945 Berlin v1")
        #expect(second.tag == "1945 Berlin v2")
        #expect(first.tag != second.tag, "the two rows would read alike wherever the topic is cut")
    }

    @Test("A volume whose title carries no topic is its tag alone")
    @MainActor
    func aTopicLessVolumeIsItsTag() throws {
        #expect(HeatMatrixRowAxis.label(volumeId: "frus1864p1", entry: try entry("frus1864p1"))
                == VolumeLabelParts(topic: "", tag: "1864 pt.1"))
    }

    /// The fallback branch: a volume in the index that the manifest does not describe. It has no
    /// title, and the joined label, handed the id as one, took the id for a topic too.
    @Test("A volume the manifest lacks is its tag alone, not its id twice")
    func aVolumeTheManifestLacksIsItsTag() {
        #expect(HeatMatrixRowAxis.label(volumeId: "frus1969-76v20", entry: nil)
                == VolumeLabelParts(topic: "", tag: "1969-76v20"))
    }

    @Test("The label column takes the width the cells leave, from 150 pt to the figure's 320 pt")
    func labelColumnFollowsTheWindow() {
        // Fifteen 34 pt columns need 15 × 35 = 525 pt, each with its 1 pt spacing.
        func width(_ available: CGFloat, columns: Int = 15) -> CGFloat {
            HeatMatrixRowAxis.labelWidth(availableWidth: available, columnCount: columns, cellSize: 34)
        }
        // iPhone 17, 402 pt less 32 pt of padding: the cells already need more, so the minimum,
        // and the cells scroll sideways beside it.
        #expect(width(370) == 150)
        // Before the first measurement the view has no width yet.
        #expect(width(0) == 150)
        // The Mac window's minimum, 720 pt, less the page's padding — with overlay scroll bars. A
        // legacy, always-shown vertical scroller (a mouse attached, or "Show scroll bars: Always")
        // would take about 15 pt more, leave about 673 pt, and clamp the column to 150 pt; that is
        // reasoned from AppKit's scroller width, not measured.
        #expect(width(688) == 163)
        // iPad Pro 11-inch in portrait, 834 pt: the cells and the labels fill it exactly.
        #expect(width(802) == 277)
        // iPad Pro 13-inch in landscape, 1,376 pt: capped at the figure's width.
        #expect(width(1344) == HeatMatrixRowAxis.figureLabelWidth)
        // A three-volume matrix leaves the labels the most room.
        #expect(width(802, columns: 3) == 320)
        // The two edges of the range.
        #expect(width(675) == 150)
        #expect(width(845) == 320)
        // Wherever the minimum leaves room for the cells, labels and cells fit the window whole.
        for available in stride(from: CGFloat(675), through: 1400, by: 25) {
            #expect(width(available) + 525 <= available, "at \(available) pt the grid is wider than the window")
        }
    }

    /// The UI suite finds rows and column codes by these, and it cannot import the app, so it
    /// spells them; a change here that is not made there leaves it finding nothing, and failing
    /// with a message that blames the fixture. So this reads the UI suite's own spelling of each
    /// from its source, rather than holding a third copy of its own.
    @Test("The row and column identifiers carry the prefixes the UI suite spells")
    func identifierPrefixesArePinned() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let suite = try String(contentsOf: root.appending(path: "FRUSExplorerUITests/AnalyticsRotationTests.swift"),
                               encoding: .utf8)
        // The string literal the UI suite declares `name` as.
        func spelled(_ name: String) throws -> String {
            let declaration = "private static let \(name) = \""
            let start = try #require(suite.range(of: declaration),
                                     "the UI suite no longer declares '\(name)' — did it move?")
            let end = try #require(suite[start.upperBound...].firstIndex(of: "\""))
            return String(suite[start.upperBound..<end])
        }
        let rowPrefix = try spelled("rowPrefix")
        let columnPrefix = try spelled("columnPrefix")
        #expect(HeatMatrixRowAxis.rowLabelIdentifierPrefix == rowPrefix)
        #expect(HeatMatrixRowAxis.columnCodeIdentifierPrefix == columnPrefix)
    }

    // MARK: The layout, read from the view's source

    /// `CrossReferenceAnalyticsView.swift`, with every whole-line comment blanked so a comment can
    /// neither satisfy a scan nor break it.
    private static func viewCode() throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: "FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift"),
                              encoding: .utf8)
        try #require(text.count > 20_000, "CrossReferenceAnalyticsView.swift is implausibly small — did it move?")
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") ? "" : String($0) }
            .joined(separator: "\n")
    }

    /// What lies between the first `{` at or after `anchor` and its matching `}`.
    private static func braces(after anchor: String, in text: String) throws -> String {
        let start = try #require(text.range(of: anchor), "'\(anchor)' not found — the scan would read nothing")
        let open = try #require(text[start.lowerBound...].firstIndex(of: "{"), "no body after '\(anchor)'")
        var depth = 0
        var index = open
        repeat {
            if text[index] == "{" { depth += 1 }
            if text[index] == "}" { depth -= 1 }
            index = text.index(after: index)
        } while depth > 0 && index < text.endIndex
        try #require(depth == 0, "'\(anchor)''s braces never close")
        return String(text[text.index(after: open)..<text.index(before: index)])
    }

    /// How many times `needle` occurs in `text`.
    private static func count(_ needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    @Test("The on-screen matrix scrolls sideways only, with its row labels outside that scroll")
    func matrixScrollsSidewaysOnly() throws {
        let code = try Self.viewCode()
        let matrix = try Self.braces(after: "private var heatMatrix: some View", in: code)
        // The page is the only vertical scroll: a box of its own took a swipe that started on the
        // matrix, and at 480 pt it stopped above the grid's last two rows.
        #expect(Self.count("ScrollView(", in: matrix) == 1, "heatMatrix should hold exactly one ScrollView:\n\(matrix)")
        #expect(Self.count("ScrollView(.horizontal)", in: matrix) == 1,
                "heatMatrix's ScrollView must scroll sideways only:\n\(matrix)")
        #expect(Self.count(".vertical", in: matrix) == 0, "heatMatrix scrolls vertically:\n\(matrix)")
        #expect(Self.count("maxHeight", in: matrix) == 0, "heatMatrix caps its own height:\n\(matrix)")
        // The labels stand beside the sideways scroll, not in it; the cells are in it.
        let scrolled = try Self.braces(after: "ScrollView(.horizontal)", in: matrix)
        #expect(Self.count("heatMatrixCells(", in: scrolled) == 1, "the cells are not in the sideways scroll:\n\(scrolled)")
        #expect(Self.count("heatMatrixRowLabels(", in: scrolled) == 0, "the row labels scroll away sideways:\n\(scrolled)")
        #expect(Self.count("heatMatrixRowLabels(", in: matrix) == 1, "heatMatrix draws no row labels:\n\(matrix)")
        // The label column's width is the window's, through the tested function.
        #expect(Self.count("HeatMatrixRowAxis.labelWidth(", in: matrix) == 1,
                "the label column does not follow the window:\n\(matrix)")
    }

    @Test("A row label cuts its topic at the tail and never its tag, on screen and in the figure")
    func rowLabelCutsTheTopicNotTheTag() throws {
        let code = try Self.viewCode()
        #expect(Self.count(".truncationMode(.head)", in: code) == 0,
                "a matrix label is still cut at its head, which drops a topic's first words")
        let label = try Self.braces(after: "private func matrixRowLabel(", in: code)
        #expect(Self.count(".truncationMode(.tail)", in: label) == 1, "the topic is not cut at its tail:\n\(label)")
        #expect(Self.count(".lineLimit(HeatMatrixRowAxis.labelLines)", in: label) == 1,
                "the topic does not take the axis's two lines:\n\(label)")
        // The tag, beside a topic and alone, takes the width it needs.
        #expect(Self.count(".fixedSize(horizontal: true, vertical: false)", in: label) == 2,
                "a tag can be cut:\n\(label)")
        // Both columns draw it: the screen's and the figure's.
        let column = try Self.braces(after: "private func heatMatrixRowLabels(", in: code)
        #expect(Self.count("matrixRowLabel(", in: column) == 1, "the label column does not draw matrixRowLabel:\n\(column)")
        let figure = try Self.braces(after: "private func exportMatrixFigure(", in: code)
        #expect(Self.count("heatMatrixRowLabels(", in: figure) == 1, "the figure draws labels of its own:\n\(figure)")
        #expect(Self.count("HeatMatrixRowAxis.figureLabelWidth", in: figure) == 1,
                "the figure's label column is not the figure's width:\n\(figure)")
    }
}

// MARK: - Matrix table (UI review P-2)

/// Pins the table that is now both the CSV and the on-screen inspector.
///
/// It was built inline inside `exportMatrixCSV`, so nothing could read it but a file. Now one
/// value feeds both, and these are the properties a reader relies on when the numbers they see
/// are the ones they cite.
@Suite("Cross-reference matrix table")
@MainActor
struct CrossReferenceMatrixTableTests {

    private func rows() -> [(sourceId: String, sourceTitle: String,
                             targetId: String, targetTitle: String, count: Int)] {
        [(sourceId: "frusA", sourceTitle: "Volume A", targetId: "frusB",
          targetTitle: "Volume B", count: 9),
         (sourceId: "frusB", sourceTitle: "Volume B", targetId: "frusC",
          targetTitle: "Volume C", count: 4),
         (sourceId: "frusC", sourceTitle: "Volume C", targetId: "frusA",
          targetTitle: "Volume A", count: 0)]
    }

    @Test("Pairs with no references are dropped, not printed as zeroes")
    func zeroPairsAreDropped() {
        let table = AnalyticsChartTables.crossRefMatrixTable(title: "T", rows: rows())
        // A 15×15 grid is 210 cells and most are empty; a table that printed them would bury the
        // ~dozen real edges the reader came for.
        #expect(table.rows.count == 2)
        #expect(!table.rows.contains { $0.cells.contains("0") })
    }

    @Test("The store's ranking is preserved, not re-sorted")
    func rankingIsPreserved() throws {
        let table = AnalyticsChartTables.crossRefMatrixTable(title: "T", rows: rows())
        let counts = table.rows.map { $0.cells.last }
        #expect(counts == ["9", "4"])
    }

    @Test("Both volumes are named and identified, so a row can be cited")
    func rowsCarryTitlesAndIds() throws {
        let table = AnalyticsChartTables.crossRefMatrixTable(title: "T", rows: rows())
        let first = try #require(table.rows.first)
        #expect(first.cells.contains("Volume A"))
        #expect(first.cells.contains("frusA"))
        #expect(first.cells.contains("Volume B"))
        #expect(first.cells.contains("frusB"))
    }
}

// MARK: - Chronology inflection (UI review P-4)

@Suite("Chronology aggregate line")
@MainActor
struct ChronologyAggregateLineTests {

    /// A day drawing on one volume is the common case in a day-grouped chronology, not an edge
    /// one, so "1 volumes" was on screen most of the time.
    @Test("A single volume reads as one volume")
    func singularInflects() {
        #expect(ChronologyAggregateText.line(volumes: 1, subseries: 1, editorialNotes: 0)
                == "1 volume · 1 subseries")
    }

    @Test("Plurals still pluralise")
    func pluralsInflect() {
        #expect(ChronologyAggregateText.line(volumes: 3, subseries: 2, editorialNotes: 4)
                == "3 volumes · 2 subseries · 4 editorial notes")
    }

    @Test("A single editorial note is not '1 editorial notes'")
    func singleEditorialNoteInflects() {
        #expect(ChronologyAggregateText.line(volumes: 2, subseries: 1, editorialNotes: 1)
                == "2 volumes · 1 subseries · 1 editorial note")
    }

    @Test("Editorial notes are omitted when there are none")
    func zeroEditorialNotesAreOmitted() {
        #expect(ChronologyAggregateText.line(volumes: 2, subseries: 1, editorialNotes: 0)
                == "2 volumes · 1 subseries")
    }
}
