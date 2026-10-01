// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftUI
import Testing
import Vision
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

    // MARK: E-volumes (#1472)
    //
    // The 1969–76 E-volumes print their number as "Volume E–13", which the Roman-only numeral match
    // missed, so the code fell back to the topic's first word — "Volume", since the topic kept the
    // designator too. These read the bundled manifest through `HeatMatrixColumnAxis.column`, the
    // function the matrix builds its columns with, rather than hand-written titles.

    /// The bundled manifest's entries, or a recorded failure.
    @MainActor
    private func bundledEntries() throws -> [VolumeManifestEntry] {
        let entries = ManifestStore().bundledEntries
        try #require(entries.count > 500, "the bundled manifest must load — an empty one makes this vacuous")
        return entries
    }

    /// The matrix's column for a bundled volume.
    @MainActor
    private func column(_ volumeId: String, in entries: [VolumeManifestEntry]) throws -> HeatMatrixColumnAxis.Column {
        let entry = try #require(entries.first { $0.volumeId == volumeId }, "\(volumeId) is not in the bundled manifest")
        return HeatMatrixColumnAxis.column(volumeId: volumeId, entry: entry)
    }

    /// Whether `title` names a 1969–76 E-volume ("Volume E–13").
    private static func isEVolume(_ title: String) -> Bool {
        title.range(of: "Volume\\s+E[–-][0-9]", options: .regularExpression) != nil
    }

    @Test("An E-volume's code is its E-number, not the first word of its title (#1472)")
    @MainActor
    func eVolumeCodeIsItsENumber() throws {
        let entries = try bundledEntries()
        let codes = matrixColumnCodes([try column("frus1969-76ve13", in: entries)])
        #expect(codes["frus1969-76ve13"] == "’69–76 E–13")
        // A hyphen where the manifest prints an en dash is the same designator, kept as printed.
        let hyphen = matrixColumnCodes([(id: "frusE", subseries: "1969-76",
                                         title: "Foreign Relations of the United States, 1969–1976, Volume E-13, Documents on China, 1969–1972",
                                         topic: "Documents on China")])
        #expect(hyphen["frusE"] == "’69–76 E-13")
    }

    @Test("The two parts of one E-volume are told apart by their topics, past 'Documents on' (#1472)")
    @MainActor
    func eVolumePartsExpandPastDocumentsOn() throws {
        let entries = try bundledEntries()
        let codes = matrixColumnCodes([try column("frus1969-76ve05p1", in: entries),
                                       try column("frus1969-76ve05p2", in: entries)])
        #expect(codes["frus1969-76ve05p1"] == "’69–76 E–5 Sub")
        #expect(codes["frus1969-76ve05p2"] == "’69–76 E–5 North")
    }

    @Test("No bundled volume's column code reads 'Volume', alone or beside the other E-volumes (#1472)")
    @MainActor
    func noBundledCodeReadsVolume() throws {
        let entries = try bundledEntries()
        var eVolumes: [HeatMatrixColumnAxis.Column] = []
        var offenders: [String] = []
        for entry in entries {
            let column = HeatMatrixColumnAxis.column(volumeId: entry.volumeId, entry: entry)
            if Self.isEVolume(entry.title) { eVolumes.append(column) }
            let code = matrixColumnCodes([column])[entry.volumeId] ?? ""
            if code.range(of: "\\bVolumes?\\b", options: .regularExpression) != nil {
                offenders.append("\(entry.volumeId) → \(code)")
            }
        }
        // The sweep met the shape it is about: 22 E-volumes in the manifest of 2026-10.
        #expect(eVolumes.count > 0, "the sweep visited no E-volume, so it says nothing about them")
        #expect(offenders.isEmpty, "\(offenders.count) column codes read 'Volume': \(offenders)")
        // All of them in one matrix: the collision passes must still say no "Volume", and part from
        // part.
        let together = matrixColumnCodes(eVolumes)
        #expect(Set(together.values).count == eVolumes.count, "two E-volume columns read alike: \(together)")
        let wordy = together.filter { $0.value.contains("Volume") }
        #expect(wordy.isEmpty, "E-volume codes read 'Volume' beside one another: \(wordy)")
    }

    // MARK: The topic's distinctive words (#1472)

    @Test("A leading 'Documents on' is dropped, with the articles after it")
    func documentsOnIsDropped() {
        #expect(matrixTopicWords("Documents on China") == ["China"])
        #expect(matrixTopicWords("Documents on the United Nations") == ["United", "Nations"])
        #expect(matrixTopicWords("Documents on Sub-Saharan Africa") == ["Sub", "Saharan", "Africa"])
    }

    @Test("'Documents' not followed by 'on' is kept")
    func documentsWithoutOnIsKept() {
        #expect(matrixTopicWords("Documents Relating to the War") == ["Documents", "Relating", "to", "the", "War"])
    }

    @Test("'on' after another first word is kept")
    func onAfterAnotherWordIsKept() {
        #expect(matrixTopicWords("Survey on China") == ["Survey", "on", "China"])
    }

    @Test("A one-word topic is kept, 'Documents' included")
    func oneWordTopicIsKept() {
        #expect(matrixTopicWords("Documents") == ["Documents"])
        #expect(matrixTopicWords("China") == ["China"])
    }

    @Test("'Documents on' with nothing after it is kept whole")
    func documentsOnAloneIsKept() {
        #expect(matrixTopicWords("Documents on") == ["Documents", "on"])
    }

    @Test("'Documents on' followed only by articles is kept whole, rather than leaving no word")
    func documentsOnThenOnlyArticlesIsKept() {
        #expect(matrixTopicWords("Documents on the") == ["Documents", "on", "the"])
    }

    // MARK: The cut topic (#1472 review round 1)

    /// `HeatMatrixColumnAxis.column` hands the codes the joined label's topic half, which is cut to
    /// 40 characters, and its doc says no code reads as far as the cut. A code reads at most two of
    /// `matrixTopicWords`' words, and six characters of each, so this compares those for every
    /// bundled volume — two words even after a numeral, where a code reads one, so a change that
    /// lets a numeral column read two is covered too — and then the codes themselves, over each
    /// subseries' volumes together and over all of them.
    @Test("A column code reads the same from the cut topic as from the whole one, for every bundled volume")
    @MainActor
    func codesReadTheSameFromTheCutTopic() throws {
        let entries = try bundledEntries()
        let read = { (topic: String) in matrixTopicWords(topic).prefix(2).map { String($0.prefix(6)) } }
        var cutColumns: [HeatMatrixColumnAxis.Column] = []
        var wholeColumns: [HeatMatrixColumnAxis.Column] = []
        var differ: [String] = []
        for entry in entries {
            let cut = HeatMatrixColumnAxis.column(volumeId: entry.volumeId, entry: entry)
            let whole = (id: cut.id, subseries: cut.subseries, title: cut.title,
                         topic: HeatMatrixRowAxis.label(volumeId: entry.volumeId, entry: entry).topic)
            if read(cut.topic) != read(whole.topic) {
                differ.append("\(entry.volumeId): \(read(cut.topic)) from \"\(cut.topic)\", \(read(whole.topic)) whole")
            }
            cutColumns.append(cut)
            wholeColumns.append(whole)
        }
        // The comparison met the cut: 71 of the manifest's topics are longer than 40 characters.
        let cutCount = zip(cutColumns, wholeColumns).filter { $0.0.topic != $0.1.topic }.count
        #expect(cutCount > 0, "no bundled topic is cut, so this compares nothing")
        #expect(differ.isEmpty, "\(differ.count) topics read differently once cut: \(differ)")
        for subseries in Set(entries.map(\.subseries)) {
            let cut = cutColumns.filter { $0.subseries == subseries }
            let whole = wholeColumns.filter { $0.subseries == subseries }
            #expect(matrixColumnCodes(cut) == matrixColumnCodes(whole), "\(subseries)'s column codes change with the cut")
        }
        #expect(matrixColumnCodes(cutColumns) == matrixColumnCodes(wholeColumns),
                "the whole manifest's column codes change with the cut")
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
/// The XREF fold-in added where the tag goes — `tagSitsBesideTopic`, one fixture per conjunct — and
/// a drawing of `HeatMatrixRowLabel` at a phone's 150 pt, read back with Vision, since a label's
/// text is the same string however its lines break.
///
/// Version history:
///   1.0 — #1379: initial implementation
///   1.1 — #1379 review round 1: the identifier pin reads the UI suite's own spelling
///   1.2 — XREF fold-in: the tag-placement rule and the 150 pt drawing; the source scan reads
///          `HeatMatrixRowLabel` and its layout
///   1.3 — XREF review round 1: the drawings count their lines, so a topic that takes two lines
///          above a stacked tag fails; the source-scan helpers are `fileprivate`, for
///          `RankingChartAxisTests`
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

    // MARK: Where the tag goes (XREF fold-in)

    @Test("The tag sits beside the topic when it leaves half the column and the first word")
    func tagSitsBesideWhenItLeavesRoom() {
        // An iPad's 277 pt column and a short tag.
        #expect(HeatMatrixRowAxis.tagSitsBesideTopic(columnWidth: 277, tagWidth: 60, firstWordWidth: 40))
        // Exactly half is enough.
        #expect(HeatMatrixRowAxis.tagSitsBesideTopic(columnWidth: 150, tagWidth: 75, firstWordWidth: 75))
    }

    @Test("The tag drops below the topic when it leaves less than half the column")
    func tagDropsWhenItLeavesLessThanHalf() {
        // The Potsdam case: the first word ("The") fits, but two lines beside the tag hold less
        // than one line across.
        #expect(!HeatMatrixRowAxis.tagSitsBesideTopic(columnWidth: 150, tagWidth: 80, firstWordWidth: 18))
    }

    @Test("The tag drops below the topic when the room it leaves cannot hold the first word")
    func tagDropsWhenTheFirstWordWouldBreak() {
        // Half the column is left, but the first word is wider than that, and would break.
        #expect(!HeatMatrixRowAxis.tagSitsBesideTopic(columnWidth: 200, tagWidth: 90, firstWordWidth: 111))
    }

    @Test("A topic's first word is what precedes its first space")
    func firstWordOfATopic() {
        #expect(HeatMatrixRowAxis.firstWord(of: "The Conference of Berlin") == "The")
        #expect(HeatMatrixRowAxis.firstWord(of: "Microfiche Supplement, American Republics") == "Microfiche")
        #expect(HeatMatrixRowAxis.firstWord(of: "China") == "China")
        #expect(HeatMatrixRowAxis.firstWord(of: "") == "")
    }

    /// The labels as drawn, read back with Vision — a label's text is the same string however it
    /// breaks, so only the drawing shows where a line ends. Drives `HeatMatrixRowLabel`, the view
    /// both label columns draw, in the frame `heatMatrixRowLabels` gives it.
    @Test("At a phone's 150 pt a long tag drops below its topic, and no first word breaks across lines")
    @MainActor
    func narrowColumnNeverBreaksTheFirstWord() throws {
        func lines(_ volumeId: String, width: CGFloat) throws -> [String] {
            let parts = HeatMatrixRowAxis.label(volumeId: volumeId, entry: try entry(volumeId))
            let drawn = try RenderedText.recognizedLines(
                in: HeatMatrixRowLabel(parts: parts).frame(width: width, height: 34, alignment: .trailing),
                width: width)
            print("[HeatMatrixRowAxisTests] \(volumeId) at \(width) pt draws \(drawn)")
            return drawn
        }
        // #1379's recording on an iPhone: "Microfi" over "che S…", and "The" over "Conference o…".
        // Each label is two lines, the topic's one and the tag's: the 34 pt cell holds two lines of
        // its 10 pt type, and a topic on two lines would push the tag onto a third, over the next
        // row. The drawing is not clipped to the frame, so a third line would be read.
        let fiche = try lines("frus1961-63v10-12mSupp", width: 150)
        #expect(fiche.first?.hasPrefix("Microfiche Supplement") == true,
                "the supplement's first line is not its topic's first words: \(fiche)")
        #expect(fiche.contains { $0.contains("1961-63 v10") }, "the supplement's tag is not drawn whole: \(fiche)")
        #expect(fiche.count == 2, "the supplement's label takes \(fiche.count) lines, not the topic's one and the tag's: \(fiche)")
        let potsdam = try lines("frus1945Berlinv01", width: 150)
        #expect(potsdam.first?.hasPrefix("The Conference of Berlin") == true,
                "the Potsdam volume's first line is not its topic's first words: \(potsdam)")
        #expect(potsdam.contains { $0.contains("1945 Berlin v1") }, "the Potsdam tag is not drawn whole: \(potsdam)")
        #expect(potsdam.count == 2, "the Potsdam label takes \(potsdam.count) lines, not the topic's one and the tag's: \(potsdam)")
        // The corpus's longest tag, which leaves its topic the least room.
        let longest = try lines("frus1969-76ve15p2Ed2", width: 150)
        #expect(longest.first?.hasPrefix("Documents on Western") == true,
                "the longest tag's row does not open on its topic's first words: \(longest)")
        #expect(longest.count == 2, "the longest tag's label takes \(longest.count) lines, not two: \(longest)")
        // The control: at an iPad's 277 pt the tag stays beside the Potsdam topic, on its last line,
        // and the topic takes its two lines.
        let wide = try lines("frus1945Berlinv01", width: 277)
        #expect(wide.first?.hasPrefix("The Conference of Berlin") == true, "\(wide)")
        #expect(wide.count == 2, "at 277 pt the Potsdam label takes \(wide.count) lines, not two: \(wide)")
        #expect(wide.last?.hasSuffix("1945 Berlin v1") == true && (wide.last?.count ?? 0) > "1945 Berlin v1".count + 3,
                "at 277 pt the tag no longer sits beside the topic's last line: \(wide)")
    }

    // MARK: The layout, read from the view's source

    /// `CrossReferenceAnalyticsView.swift`, with every whole-line comment blanked so a comment can
    /// neither satisfy a scan nor break it.
    fileprivate static func viewCode() throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: "FRUSExplorer/Analytics/CrossReferenceAnalyticsView.swift"),
                              encoding: .utf8)
        try #require(text.count > 20_000, "CrossReferenceAnalyticsView.swift is implausibly small — did it move?")
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") ? "" : String($0) }
            .joined(separator: "\n")
    }

    /// What lies between the first `{` at or after `anchor` and its matching `}`.
    fileprivate static func braces(after anchor: String, in text: String) throws -> String {
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
    fileprivate static func count(_ needle: String, in text: String) -> Int {
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
        let label = try Self.braces(after: "struct HeatMatrixRowLabel: View", in: code)
        #expect(Self.count(".truncationMode(.tail)", in: label) == 1, "the topic is not cut at its tail:\n\(label)")
        #expect(Self.count(".lineLimit(HeatMatrixRowAxis.labelLines)", in: label) == 1,
                "the topic does not take the axis's two lines:\n\(label)")
        // The tag, beside a topic and alone, takes the width it needs — and so does the topic's
        // first word, which the layout measures to decide where the tag goes.
        #expect(Self.count(".fixedSize(horizontal: true, vertical: false)", in: label) == 3,
                "a tag can be cut:\n\(label)")
        // The tag goes where the tested rule puts it.
        #expect(Self.count("HeatMatrixRowLabelLayout {", in: label) == 1,
                "the topic and tag are not arranged by HeatMatrixRowLabelLayout:\n\(label)")
        let layout = try Self.braces(after: "private struct HeatMatrixRowLabelLayout: Layout", in: code)
        #expect(Self.count("HeatMatrixRowAxis.tagSitsBesideTopic(", in: layout) == 1,
                "the layout does not decide by HeatMatrixRowAxis.tagSitsBesideTopic:\n\(layout)")
        // Both columns draw it: the screen's and the figure's.
        let column = try Self.braces(after: "private func heatMatrixRowLabels(", in: code)
        #expect(Self.count("HeatMatrixRowLabel(", in: column) == 1, "the label column does not draw HeatMatrixRowLabel:\n\(column)")
        let figure = try Self.braces(after: "private func exportMatrixFigure(", in: code)
        #expect(Self.count("heatMatrixRowLabels(", in: figure) == 1, "the figure draws labels of its own:\n\(figure)")
        #expect(Self.count("HeatMatrixRowAxis.figureLabelWidth", in: figure) == 1,
                "the figure's label column is not the figure's width:\n\(figure)")
    }
}

// MARK: - RankingChartAxisTests (#1473)

/// The Most-Referenced Documents chart's label column (#1473).
///
/// ## What was wrong
/// Each bar's y-axis label was its document's whole title, set as a bare `Text` that Swift Charts
/// lays out at its full one-line width. The label column took that, the plot got the rest, and at
/// the Mac window's 720 pt minimum and its default ~820 pt the rest was nothing: titles running off
/// the right edge, and no bars. A label is now at most `RankingChartAxis.labelWidth` wide and wraps
/// to two lines.
///
/// The width function is pinned against its floor, its cap and the plot's minimum. The chart itself
/// is DRAWN at the widths the issue names, and its bars are counted and measured in the pixels,
/// because no property of the view reports how wide Swift Charts made its plot.
///
/// Version history:
///   1.0 — #1473: initial implementation
///   1.1 — #1473 review round 1: the UI suite's floor read from its source, and the chart's height,
///          drawn and given to its exported figure
@Suite("Ranking chart axis")
@MainActor
struct RankingChartAxisTests {

    @Test("A label takes 40% of the chart, raised to 120 pt and capped at 320 pt")
    func labelWidthShareFloorAndCap() {
        // The Mac window's 720 pt minimum, less the chart's 16 pt side padding: the share.
        #expect(abs(RankingChartAxis.labelWidth(chartWidth: 688) - 275.2) < 0.001)
        // A 320 pt Slide Over window less its padding: 115 pt raised to the floor, and the plot
        // still keeps its minimum (288 − 120 = 168).
        #expect(RankingChartAxis.labelWidth(chartWidth: 288) == 120)
        // The exported figure's 1,200 pt plate, 1,144 pt inside its margins, less the padding: capped.
        #expect(RankingChartAxis.labelWidth(chartWidth: 1112) == 320)
    }

    @Test("The plot keeps 160 pt, and the label gives way to it, down to nothing")
    func plotKeepsItsMinimum() {
        // Below 280 pt the floor would leave the plot under its minimum, so the label shrinks.
        #expect(RankingChartAxis.labelWidth(chartWidth: 250) == 90)
        #expect(RankingChartAxis.labelWidth(chartWidth: 160) == 0)
        // Never negative.
        #expect(RankingChartAxis.labelWidth(chartWidth: 100) == 0)
        for width in stride(from: CGFloat(160), through: 1600, by: 8) {
            let label = RankingChartAxis.labelWidth(chartWidth: width)
            #expect(width - label >= RankingChartAxis.minimumPlotWidth, "at \(width) pt the plot keeps \(width - label) pt")
            #expect(label <= RankingChartAxis.maximumLabelWidth)
        }
    }

    /// Fifteen documents of the #1379 fixture's volumes, named as Cross-Reference Analytics names a
    /// document that is not downloaded — "Document 1 — <volume title>" — which is what a reader
    /// whose citations reach volumes they lack sees, and what the UI fixture's ranking shows.
    private func fixtureRanking() throws -> [InDegreeRow] {
        let entries = ManifestStore().bundledEntries
        try #require(entries.count > 500, "the bundled manifest must load — an empty one makes this vacuous")
        return try UITestVolumeSeeder.crossReferenceMatrixVolumeIds.enumerated().map { index, volumeId in
            let entry = try #require(entries.first { $0.volumeId == volumeId }, "\(volumeId) is not bundled")
            return InDegreeRow(volumeId: volumeId, documentId: "d1", inDegree: 50 - index,
                               label: CrossReferenceTargetLabel.text(facts: nil, documentId: "d1",
                                                                     volumeTitle: entry.title),
                               isIndexed: false)
        }
    }

    /// The chart drawn `width` points wide, and the length in points of each bar it draws, top to
    /// bottom. A bar is a band of pixel rows in the accent colour (system blue: the app ships no
    /// accent asset); its length is the longest run of that colour in the band.
    private func bars(width: CGFloat, ranking: [InDegreeRow]) throws -> (lengths: [CGFloat], image: CGImage) {
        let inspector = AnalyticsChartTables.crossRefRankingTable(
            title: "Most-Referenced Documents",
            rows: ranking.map { (volumeId: $0.volumeId, documentId: $0.documentId, label: $0.label, inDegree: $0.inDegree) })
        let scale: CGFloat = 2
        let image = try RenderedText.image(of: CrossReferenceRankingChart(ranking: ranking, inspector: inspector),
                                           width: width, scale: scale)
        let pixels = try RenderedText.pixels(of: image)
        var bands: [CGFloat] = []
        var current: Int? = nil
        for y in 0..<image.height {
            var longest = 0, run = 0
            for x in 0..<image.width {
                let i = (y * image.width + x) * 4
                let (r, g, b) = (pixels[i], pixels[i + 1], pixels[i + 2])
                if r < 40, g > 100, g < 145, b > 235 { run += 1; longest = max(longest, run) } else { run = 0 }
            }
            // A row of a bar: more blue than a glyph's stroke could be.
            if longest >= Int(4 * scale) {
                current = max(current ?? 0, longest)
            } else if let band = current {
                bands.append(CGFloat(band) / scale)
                current = nil
            }
        }
        if let band = current { bands.append(CGFloat(band) / scale) }
        return (bands, image)
    }

    @Test("At the Mac window's 720 pt and 820 pt, and on an iPhone, every bar is drawn with room to read",
          arguments: [CGFloat(720), 820, 402])
    func everyBarIsDrawn(width: CGFloat) throws {
        let ranking = try fixtureRanking()
        let (lengths, image) = try bars(width: width, ranking: ranking)
        print("[RankingChartAxisTests] at \(width) pt the chart draws \(lengths.count) bars of "
              + "\(lengths.map { String(format: "%.1f", $0) }.joined(separator: ", ")) pt")
        #expect(lengths.count == ranking.count, """
            At \(width) pt the chart draws \(lengths.count) bars for \(ranking.count) documents — \
            #1473's titles taking the whole width and leaving the plot none.
            """)
        // The longest bar spans most of a plot that kept at least its minimum.
        #expect((lengths.max() ?? 0) >= RankingChartAxis.minimumPlotWidth / 2, """
            At \(width) pt the longest bar is \(lengths.max() ?? 0) pt: the plot has almost no room.
            """)
        #expect(CGFloat(image.width) / 2 == width, "the chart was drawn \(image.width / 2) pt wide, not \(width)")
    }

    /// The UI suite `CrossReferenceRankingChartTests` requires every bar's row across the plot to be
    /// at least the plot's minimum less 10 pt. It cannot import the app, so it spells that figure;
    /// this reads its spelling, as `HeatMatrixRowAxisTests.identifierPrefixesArePinned` reads its
    /// identifiers, so a change to the plot's minimum cannot leave the UI suite's floor behind.
    @Test("The UI suite's floor for a bar's row is the plot's minimum less 10 pt")
    func uiSuiteFloorIsThePlotMinimum() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let suite = try String(contentsOf: root.appending(path: "FRUSExplorerUITests/AnalyticsRotationTests.swift"),
                               encoding: .utf8)
        let declaration = "private static let minimumBarRowWidth: CGFloat = "
        let start = try #require(suite.range(of: declaration),
                                 "the UI suite no longer declares minimumBarRowWidth — did it move?")
        let end = try #require(suite[start.upperBound...].firstIndex(of: "\n"))
        let floor = try #require(Double(suite[start.upperBound..<end].trimmingCharacters(in: .whitespaces)),
                                 "the UI suite's minimumBarRowWidth is not a number")
        #expect(CGFloat(floor) == RankingChartAxis.minimumPlotWidth - 10,
                "the UI suite requires \(floor) pt, and the plot's minimum is \(RankingChartAxis.minimumPlotWidth) pt")
    }

    /// The chart frames itself at `RankingChartAxis.chartHeight(rows:)`, which is drawn here, and
    /// the exported figure gives it the same, which only its source shows: the export is a method
    /// of the whole view. Until #1473's review the figure gave the chart 26 pt a row, so a 15-row
    /// chart framed itself 490 pt tall in a 430 pt area.
    @Test("The chart is 30 pt a row and 40 pt for its axis, and its exported figure gives it that height")
    func chartHeightIsSharedWithTheFigure() throws {
        let ranking = try fixtureRanking()
        #expect(RankingChartAxis.chartHeight(rows: ranking.count) == 490)
        let inspector = AnalyticsChartTables.crossRefRankingTable(
            title: "Most-Referenced Documents",
            rows: ranking.map { (volumeId: $0.volumeId, documentId: $0.documentId, label: $0.label, inDegree: $0.inDegree) })
        let image = try RenderedText.image(of: CrossReferenceRankingChart(ranking: ranking, inspector: inspector),
                                           width: 720, scale: 1)
        #expect(CGFloat(image.height) == RankingChartAxis.chartHeight(rows: ranking.count),
                "the chart draws itself \(image.height) pt tall for \(ranking.count) rows")
        let figure = try HeatMatrixRowAxisTests.braces(after: "private func exportRankingFigure(",
                                                       in: try HeatMatrixRowAxisTests.viewCode())
        #expect(HeatMatrixRowAxisTests.count("RankingChartAxis.chartHeight(rows: ranking.count)", in: figure) == 1,
                "the exported figure gives the chart a height of its own:\n\(figure)")
    }

    @Test("At 720 pt every row's title is drawn, on up to two lines, with no row left blank")
    func everyTitleIsDrawn() throws {
        let ranking = try fixtureRanking()
        let inspector = AnalyticsChartTables.crossRefRankingTable(
            title: "Most-Referenced Documents",
            rows: ranking.map { (volumeId: $0.volumeId, documentId: $0.documentId, label: $0.label, inDegree: $0.inDegree) })
        let lines = try RenderedText.recognizedLines(
            in: CrossReferenceRankingChart(ranking: ranking, inspector: inspector), width: 720)
        print("[RankingChartAxisTests] at 720 pt Vision reads \(lines)")
        // Each label opens "Document 1 —", so the lines that do are the labels drawn.
        let opened = lines.filter { $0.hasPrefix("Document 1") }
        #expect(opened.count == ranking.count, """
            At 720 pt \(opened.count) of the \(ranking.count) titles are drawn: \(lines)
            """)
        // Two lines each: a title's second line is the other line with words in it. The bars'
        // counts and the axis's ticks are numbers, so they are not counted.
        let wrapped = lines.filter { !$0.hasPrefix("Document 1") && $0.rangeOfCharacter(from: .letters) != nil }
        #expect(wrapped.count == ranking.count, "\(wrapped.count) titles take a second line, not \(ranking.count): \(lines)")
    }
}

// MARK: - Rendering for the tests above

/// Draws a view and reads it back — for tests that need what a layout DRAWS, which no property of
/// the view reports.
@MainActor
enum RenderedText {

    /// `view` drawn `width` points wide on white, in light mode.
    ///
    /// - Parameters:
    ///   - view: The view to draw.
    ///   - width: The width to propose to it, and to frame it at.
    ///   - scale: The raster scale.
    /// - Returns: The drawing.
    static func image(of view: some View, width: CGFloat, scale: CGFloat) throws -> CGImage {
        let renderer = ImageRenderer(content: view
            .frame(width: width)
            .background(Color.white)
            .environment(\.colorScheme, .light))
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        return try #require(renderer.cgImage, "ImageRenderer drew nothing")
    }

    /// The image's pixels as RGBA bytes, row by row from the top.
    static func pixels(of image: CGImage) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = try #require(CGContext(
            data: &pixels, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return pixels
    }

    /// The lines Vision reads in `view` drawn `width` points wide with a 4 pt margin, top to bottom.
    static func recognizedLines(in view: some View, width: CGFloat) throws -> [String] {
        let image = try image(of: view.padding(4), width: width + 8, scale: 4)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? [])
            .sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }
            .compactMap { $0.topCandidates(1).first?.string }
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
