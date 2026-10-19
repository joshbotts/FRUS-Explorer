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

import Testing
import Foundation
@testable import FRUSExplorer

// MARK: - The "why related" chip

/// The shared-distinctive-terms chip: what it ranks, and what it refuses to print.
///
/// Version history:
///   1.0 — V-3 follow-up: initial implementation
@Suite("Semantic shared-terms chip")
struct SemanticSharedTermsTests {

    @Test("Ranking prefers the corpus-rare term over the common one")
    func rankingPrefersRareTerms() {
        let shared: Set<String> = ["government", "kearsarge", "department", "raider"]
        let corpus = ["government": 900_000, "department": 750_000,
                      "kearsarge": 41, "raider": 260]
        #expect(SemanticSharedTerms.rank(shared: shared, corpusCounts: corpus, limit: 2)
                == ["kearsarge", "raider"])
    }

    /// An unpriced term is not "infinitely rare": the baseline retains a 20,000-term head, so an
    /// absent term may equally be tokenisation debris — which would otherwise win every chip.
    @Test("A term the baseline does not price is skipped, not treated as rarest")
    func unpricedTermsAreSkipped() {
        let shared: Set<String> = ["qxzzy", "kearsarge"]
        let corpus = ["kearsarge": 41]
        #expect(SemanticSharedTerms.rank(shared: shared, corpusCounts: corpus, limit: 3)
                == ["kearsarge"])
        #expect(SemanticSharedTerms.rank(
            shared: ["qxzzy"], corpusCounts: corpus, limit: 3).isEmpty)
    }

    @Test("Ties break alphabetically so a chip is stable across runs")
    func tiesAreDeterministic() {
        let corpus = ["alpha": 10, "beta": 10, "gamma": 10]
        let first = SemanticSharedTerms.rank(
            shared: ["gamma", "beta", "alpha"], corpusCounts: corpus, limit: 2)
        let second = SemanticSharedTerms.rank(
            shared: ["alpha", "gamma", "beta"], corpusCounts: corpus, limit: 2)
        #expect(first == ["alpha", "beta"])
        #expect(first == second)
    }

    /// The tokenizer emits lowercased lemmas. A chip that printed them would render the ship
    /// *Kearsarge* as `kearsarge` and look like a bug.
    @Test("The display form comes from the anchor's own text, with its own casing")
    func displayFormUsesAnchorCasing() {
        let text = "The Kearsarge engaged the raider Alabama off Cherbourg."
        #expect(SemanticSharedTerms.displayForm(for: "kearsarge", in: text) == "Kearsarge")
        #expect(SemanticSharedTerms.displayForm(for: "raider", in: text) == "raider")
        #expect(SemanticSharedTerms.displayForm(for: "cherbourg", in: text) == "Cherbourg")
    }

    @Test("A lemma matched inside a longer surface form is shown as the reader will find it")
    func displayFormExtendsToWholeWord() {
        #expect(SemanticSharedTerms.displayForm(for: "alliance", in: "Two alliances were signed.")
                == "alliances")
    }

    /// The guard against the opposite failure: a short lemma living inside an unrelated long word.
    @Test("A surface form far longer than its lemma is rejected as a different word")
    func displayFormRejectsFalseContainment() {
        // "ration" inside "corporations" is not the word the chip means.
        #expect(SemanticSharedTerms.displayForm(for: "ration", in: "The corporations replied.")
                == "ration")
    }

    @Test("A lemma with no surface match falls back to the lemma itself")
    func displayFormFallsBack() {
        #expect(SemanticSharedTerms.displayForm(for: "be", in: "Nothing matches here.") == "be")
    }
}

// MARK: - The chip's route to the screen

/// The V-3 defect this follow-up fixes: the semantic axis computed an evidence label that
/// `whyRelatedChips` had no arm for, so it never reached the screen and its only consumer was a test.
///
/// Version history:
///   1.0 — V-3 follow-up: initial implementation
@Suite("Semantic why-related chip wiring")
struct SemanticChipWiringTests {

    /// Builds a row carrying a semantic score and optional shared-term evidence.
    static func row(terms: [String]?) -> RelatedDocumentRow {
        var row = RelatedDocumentRow(
            key: DocumentKey(volumeId: "frus1864p1", documentId: "d147"),
            record: CandidateRecord(
                header: "H", dateline: nil, documentNumber: nil, isEditorialNote: false),
            totalScore: 0.82,
            axisScores: [.semanticSimilarity: 0.82])
        if let terms { row.axisEvidenceLabel[.semanticSimilarity] = terms.joined(separator: "\u{1F}") }
        return row
    }

    @Test("With shared terms, the chip names them rather than stating a percentage")
    func chipNamesSharedTerms() throws {
        let chips = Self.row(terms: ["Kearsarge", "raider"]).whyRelatedChips
        let semantic = try #require(chips.first { $0.axis == .semanticSimilarity })
        #expect(semantic.chip == .sharedTerms(["Kearsarge", "raider"]))
    }

    /// The interim and permanent fallback: on first paint the render-time pass has not run, and some
    /// pairs genuinely share no distinctive vocabulary.
    @Test("Without shared terms, the chip falls back to the percentage")
    func chipFallsBackToPercent() throws {
        let chips = Self.row(terms: nil).whyRelatedChips
        let semantic = try #require(chips.first { $0.axis == .semanticSimilarity })
        #expect(semantic.chip == .percent(82))
    }

    @Test("An empty evidence string does not produce an empty chip")
    func emptyEvidenceFallsBack() throws {
        var row = Self.row(terms: nil)
        row.axisEvidenceLabel[.semanticSimilarity] = ""
        let semantic = try #require(row.whyRelatedChips.first { $0.axis == .semanticSimilarity })
        #expect(semantic.chip == .percent(82))
    }

    /// Source-scanned, because the defect being fixed was precisely a value that existed and was
    /// never rendered: a unit test on the producing function passed throughout.
    @Test("The view renders the shared-terms chip and computes it after ranking")
    func viewRendersAndComputesTheChip() throws {
        let view = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FRUSExplorer/RelatedDocuments/RelatedDocumentsView.swift")
        let source = try String(contentsOf: view, encoding: .utf8)
        // #1586 moved every chip's words out of the view into `WhyRelatedChip.displayText`, so
        // the render arm is asked for directly, and the view is held to drawing what it returns.
        #expect(WhyRelatedChip.sharedTerms(["Kearsarge", "raider"]).displayText() == "shares: Kearsarge, raider",
                "the chip case must have a render arm or it is dead again")
        #expect(source.contains("let display = chip.displayText()"),
                "the view no longer draws the chip's own words")
        #expect(source.contains("attachSemanticEvidence"))
        #expect(source.contains("SemanticSharedTerms.sharedTerms"))
    }
}

// MARK: - Tester feedback

/// The feedback path the retired blind panel was traded for.
///
/// Version history:
///   1.0 — V-3 follow-up: initial implementation
@Suite("Semantic feedback log", .serialized)
struct SemanticFeedbackLogTests {

    /// Makes an entry.
    static func entry(
        anchor: String = "frus1864p1/d147",
        neighbour: String = "frus1864p1/d148",
        verdict: SemanticFeedbackEntry.Verdict = .helpful,
        era: String? = "0"
    ) -> SemanticFeedbackEntry {
        SemanticFeedbackEntry(
            recordedAt: Date(), anchor: anchor, neighbour: neighbour, verdict: verdict,
            cosine: 0.82, era: era, sameVolume: true, provenanceDigest: "abc")
    }

    @Test("A verdict records, reads back, and exports")
    func recordAndExport() async throws {
        await SemanticFeedbackLog.shared.clear()
        await SemanticFeedbackLog.shared.record(Self.entry())

        #expect(await SemanticFeedbackLog.shared.verdict(
            anchor: "frus1864p1/d147", neighbour: "frus1864p1/d148") == .helpful)
        let data = try #require(await SemanticFeedbackLog.shared.exportData())
        #expect(!data.isEmpty)
        // The export encodes ISO-8601 dates, so a decoder must be configured to match — a plain
        // JSONDecoder fails on `recordedAt`, which is the round trip this asserts.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([SemanticFeedbackEntry].self, from: data)
        #expect(decoded.count == 1)
        #expect(decoded.first?.era == "0")
        await SemanticFeedbackLog.shared.clear()
    }

    /// A tester who changes their mind has one opinion, not two — otherwise one indecisive row
    /// outweighs ten rows of agreement.
    @Test("A second verdict on the same pair replaces the first")
    func verdictsAreReplaced() async throws {
        await SemanticFeedbackLog.shared.clear()
        await SemanticFeedbackLog.shared.record(Self.entry(verdict: .helpful))
        await SemanticFeedbackLog.shared.record(Self.entry(verdict: .notHelpful))

        let entries = await SemanticFeedbackLog.shared.entries()
        #expect(entries.count == 1)
        #expect(entries.first?.verdict == .notHelpful)
        await SemanticFeedbackLog.shared.clear()
    }

    /// The summary's era split is the number that says whether this feedback can answer the question
    /// the blind panel would have: zero pre-1900 verdicts means nothing replaced it.
    @Test("The summary splits verdicts by era")
    func summarySplitsByEra() async throws {
        await SemanticFeedbackLog.shared.clear()
        await SemanticFeedbackLog.shared.record(
            Self.entry(neighbour: "a/d1", era: "0"))                       // pre-1900
        await SemanticFeedbackLog.shared.record(
            Self.entry(neighbour: "a/d2", verdict: .notHelpful, era: "2")) // cold war
        await SemanticFeedbackLog.shared.record(Self.entry(neighbour: "a/d3", era: nil))

        let summary = await SemanticFeedbackLog.shared.summary()
        #expect(summary.total == 3)
        #expect(summary.helpful == 2)
        #expect(summary.byEra.first { $0.era == "0" }?.count == 1)
        #expect(summary.byEra.first { $0.era == "unknown" }?.count == 1)
        await SemanticFeedbackLog.shared.clear()
    }

    @Test("Clearing removes every verdict and the file")
    func clearRemovesEverything() async throws {
        await SemanticFeedbackLog.shared.record(Self.entry())
        await SemanticFeedbackLog.shared.clear()
        #expect(await SemanticFeedbackLog.shared.entries().isEmpty)
        #expect(await SemanticFeedbackLog.shared.summary().total == 0)
        if let url = SemanticFeedbackLog.fileURL {
            #expect(!FileManager.default.fileExists(atPath: url.path))
        }
    }

    /// The log must never become a `@Model`: that changes the CloudKit schema and needs a Production
    /// deploy before the build ships (#488). It is also a tester's notes about the app, not their
    /// research, and has no business syncing.
    @Test("The feedback log is local-only and outside SwiftData")
    func logIsLocalOnly() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("FRUSExplorer/Semantic/SemanticFeedbackLog.swift"),
            encoding: .utf8)
        // Scanned for the IMPORT, not for the string "@Model": this file's own doc comment
        // explains at length why it is not a model, and a test that greps prose fails on the
        // documentation of the very decision it is checking.
        #expect(!source.contains("import SwiftData"))
        #expect(source.contains("actor SemanticFeedbackLog"))
        #expect(source.contains("applicationSupportDirectory"))
    }

    /// Era labels come from the app's own banding, so feedback is comparable with every other
    /// era-split surface rather than with a second scheme invented for this screen.
    @Test("Stored era values render through the app's own CoverageEra labels")
    @MainActor
    func eraLabelsUseCoverageEra() {
        #expect(SemanticFeedbackView.eraLabel("0") == CoverageEra.pre1900.label)
        #expect(SemanticFeedbackView.eraLabel("2") == CoverageEra.coldWar.label)
        #expect(SemanticFeedbackView.eraLabel("unknown").isEmpty == false)
        #expect(SemanticFeedbackView.eraLabel("unknown") != CoverageEra.pre1900.label)
    }

    /// Source-scanned: a feedback screen nobody can reach collects nothing, and the macOS Settings
    /// window cannot push a NavigationLink — the `link(...)` helper is what makes the row work on
    /// both platforms.
    @Test("The feedback screen is reachable from Settings on both platforms")
    func screenIsReachable() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("FRUSExplorer/Settings/DataRecoveryView.swift"),
            encoding: .utf8)
        #expect(source.contains("case brokenReferences, syncLog, schemaStatus, semanticFeedback"))
        #expect(source.contains("link(.semanticFeedback,"))
        #expect(source.contains("case .semanticFeedback: SemanticFeedbackView()"))
    }

    /// The row control is where a verdict is actually given; without it the screen is a museum.
    @Test("Related rows offer the verdict control, and only for semantic rows")
    func rowOffersTheControl() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("FRUSExplorer/RelatedDocuments/RelatedDocumentsView.swift"),
            encoding: .utf8)
        #expect(source.contains("semanticFeedbackButtons(for: row)"))
        #expect(source.contains("if row.axisScores[.semanticSimilarity] != nil"))
        #expect(source.contains("SemanticFeedbackLog.shared.record"))
        // The era must be captured, or the log cannot answer the question it replaced. Since §6g
        // the verdict, era included, is built by `RelatedDocumentsRequest.semanticFeedback`, which
        // `SemanticFeedbackAnchorEraTests` runs over a real index; this scan checks only that the
        // row's menu records through it.
        #expect(source.contains("request.semanticFeedback("))
    }
}

// MARK: - The anchor's era (plan of record §6g)

/// Every verdict carries its anchor's era, whichever door opened the anchor.
///
/// Found in A8 (plan of record §6g): a verdict given on `frus1961-63v09/d65` (November 15, 1962),
/// opened from the Mac's Continue reading, was recorded with no `era` and counted under *Undated
/// anchor*. The request took the anchor's year from the reader's `DocumentBrowserEntry.dateline`,
/// and Continue reading, like most doors, builds its entry with none. Each test builds the request
/// as a door builds it, with the platform's own `extractYear`, and runs
/// `RelatedDocumentsRequest.semanticFeedback`, the call the row's menu makes, over a real index.
///
/// Version history:
///   1.0 — 2026-10-19 (plan of record §6g): initial implementation
@Suite("Semantic feedback: the anchor's era (§6g)")
@MainActor
struct SemanticFeedbackAnchorEraTests {

    /// Two documents as the corpus marks them up, cut to their openings, and an undated one.
    ///
    /// `frus1900/d60` (January 25, 1899) is the anchor of the iPhone walk that reproduced the
    /// finding. `frus1929v02/d1030` is a telegram of September 18, 1929 whose printed dateline reads
    /// 1829; the corpus's own `@ana` calls it a typo, and the index keeps the day of its `@when`.
    private static let volumes: [(id: String, body: String)] = [
        ("frus1900", """
            <div frus:doc-dateTime-max="1899-01-25T23:59:59-05:00" \
            frus:doc-dateTime-min="1899-01-25T00:00:00-05:00" n="60" \
            subtype="historical-document" type="document" xml:id="d60">
              <head><hi rend="italic">Mr. <persName type="from">Hay</persName> to Señor \
            <persName type="to">Morla Vicuña</persName>.</hi></head>
              <opener><dateline rendition="#right"><placeName><hi rend="smallcaps">Department of \
            State</hi>,<lb/><hi rend="italic">Washington</hi></placeName>, <date calendar="gregorian" \
            when="1899-01-25"><hi rend="italic">January 25, 1899</hi></date>.</dateline></opener>
              <p>Sir: I have the honor to call your attention to the protocol, signed at this city on \
            May 24, 1897.</p>
            </div>
            """),
        ("frus1929v02", """
            <div frus:doc-dateTime-max="1929-09-18T04:00:00-05:00" \
            frus:doc-dateTime-min="1929-09-18T04:00:00-05:00" n="1030" \
            subtype="historical-document" type="document" xml:id="d1030">
              <note rend="inline" type="source">851.4061 Motion Pictures/138: Telegram</note>
              <head><hi rend="italic">The Chargé in France</hi> (<persName type="from"><hi \
            rend="italic">Armour</hi></persName>) <hi rend="italic">to the <gloss type="to">Secretary \
            of State</gloss></hi></head>
              <opener><dateline rendition="#right"><placeName><hi rend="smallcaps">Paris</hi>\
            </placeName>, <date ana="#date_apparent-typo-based-on-document-content" \
            calendar="gregorian" when="1929-09-18T10:00:00+01:00">September 18, 1829—10 a.m.</date>\
            </dateline></opener>
              <p>The French Government has informed the Embassy of its film quota decree.</p>
            </div>
            """),
        ("fixture-undated", """
            <div n="1" type="document" xml:id="d1">
              <head>Memorandum.</head>
              <p>A document that names no date and carries no dateline.</p>
            </div>
            """),
    ]

    /// When the tester gave the verdict.
    private static let moment = Date(timeIntervalSince1970: 1_792_404_297)

    /// A semantic row on the anchor's neighbour.
    private static func row(_ volumeId: String, _ documentId: String) -> RelatedDocumentRow {
        RelatedDocumentRow(
            key: DocumentKey(volumeId: volumeId, documentId: documentId),
            record: CandidateRecord(
                header: "H", dateline: nil, documentNumber: nil, isEditorialNote: false),
            totalScore: 0.87,
            axisScores: [.semanticSimilarity: 0.869])
    }

    /// The year a door hands the request: what `DocumentView.openRelatedDocuments()` (iOS) and
    /// `ResearchRailView.openRelated()` (macOS) compute from the reader's entry.
    private static func doorYear(_ entry: DocumentBrowserEntry) -> Int? {
        #if os(iOS)
        return DocumentView.extractYear(from: entry.dateline)
        #elseif os(macOS)
        return MacDocumentView.extractYear(from: entry.dateline)
        #else
        return nil
        #endif
    }

    /// The request a door builds from the reader's entry.
    private static func request(from entry: DocumentBrowserEntry) -> RelatedDocumentsRequest {
        RelatedDocumentsRequest(
            anchor: DocumentKey(volumeId: entry.volumeId, documentId: entry.documentId),
            anchorYear: doorYear(entry))
    }

    /// The entry Continue reading opens the reader with (`ResumeReadingRow`): ids and a title.
    private static func continueReadingEntry(_ volumeId: String, _ documentId: String)
        -> DocumentBrowserEntry {
        DocumentBrowserEntry(documentId: documentId, volumeId: volumeId, header: documentId)
    }

    /// The entry a volume's document list opens the reader with, dateline included.
    private static func listEntry(
        _ volumeId: String, _ documentId: String, in pipeline: IndexingPipeline
    ) async throws -> DocumentBrowserEntry {
        let listed = try await pipeline.documents(forVolume: volumeId)
        return try #require(listed.first { $0.documentId == documentId })
    }

    /// Indexes the fixture volumes into a fresh database and runs `body` with its pipeline.
    private func withIndex(_ body: (IndexingPipeline) async throws -> Void) async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SemanticFeedbackAnchorEra-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let (pipeline, _) = try await makeTestPipeline(dir: dir)
        for volume in Self.volumes {
            let xml = """
                <?xml version="1.0" encoding="UTF-8"?>
                <TEI xmlns="http://www.tei-c.org/ns/1.0" \
                xmlns:frus="http://history.state.gov/frus/ns/1.0" xml:id="\(volume.id)">
                  <teiHeader><fileDesc><titleStmt><title>\(volume.id)</title></titleStmt>
                  <sourceDesc><p>fixture</p></sourceDesc></fileDesc></teiHeader>
                  <text><body>
                \(volume.body)
                  </body></text>
                </TEI>
                """
            try Data(xml.utf8).write(
                to: dir.appendingPathComponent("volumes/\(volume.id).xml"))
            try await pipeline.indexVolume(volume.id)
        }
        try await body(pipeline)
    }

    /// The finding itself: Continue reading hands the request no year, and the verdict was banded
    /// by that.
    @Test("A verdict after Continue reading, whose entry has no dateline, carries the anchor's era")
    func continueReadingCarriesTheEra() async throws {
        try await withIndex { pipeline in
            let entry = Self.continueReadingEntry("frus1900", "d60")
            #expect(Self.doorYear(entry) == nil, "the door hands no year, as in the finding")
            let verdict = await Self.request(from: entry).semanticFeedback(
                .helpful, on: Self.row("frus1900", "d59"), pipeline: pipeline,
                provenanceDigest: "abc", recordedAt: Self.moment)
            #expect(verdict.era == String(CoverageEra.pre1900.rawValue))
        }
    }

    /// The iPhone walk's A/B, as a test: one anchor, two doors, one era.
    @Test("The anchor is banded the same whichever door opened it")
    func everyDoorBandsTheSame() async throws {
        try await withIndex { pipeline in
            let listed = try await Self.listEntry("frus1900", "d60", in: pipeline)
            let doors = [Self.continueReadingEntry("frus1900", "d60"), listed]
            #expect(doors.map { Self.doorYear($0) } == [nil, 1899],
                    "the two doors disagree on the year")
            var eras: [String?] = []
            for entry in doors {
                eras.append(await Self.request(from: entry).semanticFeedback(
                    .notHelpful, on: Self.row("frus1900", "d61"), pipeline: pipeline,
                    provenanceDigest: nil, recordedAt: Self.moment).era)
            }
            #expect(eras == ["0", "0"])
        }
    }

    /// A misprinted dateline put a 1929 telegram before 1900 for a door that carries the dateline.
    @Test("The index's date wins over a dateline that misprints its year")
    func indexDateWinsOverAMisprint() async throws {
        try await withIndex { pipeline in
            let entry = try await Self.listEntry("frus1929v02", "d1030", in: pipeline)
            #expect(Self.doorYear(entry) == 1829, "the door reads the misprint")
            let request = Self.request(from: entry)
            #expect(await request.resolvedAnchorYear(pipeline: pipeline) == 1929)
            let verdict = await request.semanticFeedback(
                .helpful, on: Self.row("frus1929v02", "d1031"), pipeline: pipeline,
                provenanceDigest: "abc", recordedAt: Self.moment)
            #expect(verdict.era == String(CoverageEra.earlyTwentieth.rawValue))
        }
    }

    /// Measured over a full index, no document has a dateline year and no date in the index; the
    /// rule still keeps the door's year for one, and an anchor nothing dates stays undated, which
    /// is what *Undated anchor* says.
    @Test("An anchor the index does not date keeps the door's year, and one nothing dates stays undated")
    func undatedInTheIndex() async throws {
        try await withIndex { pipeline in
            let undated = DocumentKey(volumeId: "fixture-undated", documentId: "d1")
            let stored = try await pipeline.documentDates(
                for: [(volumeId: undated.volumeId, documentId: undated.documentId)])
            #expect(stored.isEmpty, "the fixture must be undated in the index")
            let row = Self.row("fixture-undated", "d2")
            let withYear = await RelatedDocumentsRequest(anchor: undated, anchorYear: 1962)
                .semanticFeedback(.helpful, on: row, pipeline: pipeline,
                                  provenanceDigest: nil, recordedAt: Self.moment)
            #expect(withYear.era == String(CoverageEra.coldWar.rawValue))
            let without = await RelatedDocumentsRequest(anchor: undated)
                .semanticFeedback(.helpful, on: row, pipeline: pipeline,
                                  provenanceDigest: nil, recordedAt: Self.moment)
            #expect(without.era == nil)
        }
    }

    @Test("With no index open, the door's year stands")
    func noIndexKeepsTheDoorsYear() async {
        let anchor = DocumentKey(volumeId: "frus1900", documentId: "d60")
        #expect(await RelatedDocumentsRequest(anchor: anchor, anchorYear: 1899)
            .resolvedAnchorYear(pipeline: nil) == 1899)
        #expect(await RelatedDocumentsRequest(anchor: anchor)
            .resolvedAnchorYear(pipeline: nil) == nil)
    }

    /// The verdict's other fields moved out of the view with the era; this holds them to what the
    /// view recorded.
    @Test("A verdict keeps the pair, its score, the vectors judged and the moment")
    func verdictKeepsItsFields() async throws {
        try await withIndex { pipeline in
            let request = Self.request(from: Self.continueReadingEntry("frus1900", "d60"))
            let sameVolume = await request.semanticFeedback(
                .notHelpful, on: Self.row("frus1900", "d59"), pipeline: pipeline,
                provenanceDigest: "89481b18", recordedAt: Self.moment)
            #expect(sameVolume.anchor == "frus1900/d60")
            #expect(sameVolume.neighbour == "frus1900/d59")
            #expect(sameVolume.verdict == .notHelpful)
            #expect(sameVolume.cosine == 0.869)
            #expect(sameVolume.sameVolume == true)
            #expect(sameVolume.provenanceDigest == "89481b18")
            #expect(sameVolume.recordedAt == Self.moment)
            let otherVolume = await request.semanticFeedback(
                .helpful, on: Self.row("frus1901", "d12"), pipeline: pipeline,
                provenanceDigest: nil, recordedAt: Self.moment)
            #expect(otherVolume.sameVolume == false)
            #expect(otherVolume.provenanceDigest == nil)
        }
    }

    /// Source-scanned, because the list's load and its row menu are view code no unit test renders:
    /// the list must rank with the year it bands verdicts by, and must not read the door's year
    /// itself. Comment lines are dropped first, so a comment naming `anchorYear` is not a read.
    @Test("Related Documents ranks with the index's year and builds no verdict of its own")
    func viewReadsOnlyTheResolvedYear() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("FRUSExplorer/RelatedDocuments/RelatedDocumentsView.swift"),
            encoding: .utf8)
        let code = source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        #expect(code.range(of: #"\.anchorYear\b"#, options: .regularExpression) == nil,
                "the view reads the door's year only through resolvedAnchorYear(pipeline:)")
        #expect(code.contains(
            "let anchorYear = await request.resolvedAnchorYear(pipeline: appState.indexingPipeline)"))
        #expect(code.contains("anchorYear: anchorYear,"), "the ranking takes the resolved year")
        #expect(!code.contains("SemanticFeedbackEntry("),
                "a verdict is built by RelatedDocumentsRequest.semanticFeedback, era included")
    }
}

// MARK: - The mail draft (#1545)

/// Semantic Match Feedback's mail draft: one address, named by the owner on 2026-10-18 (plan of
/// record decision 26), written into the draft and into the screen's footer from one constant.
///
/// Version history:
///   1.0 — 2026-10-18 (#1545): initial implementation
@Suite("Semantic Match Feedback mail draft (#1545)")
struct SemanticFeedbackMailTests {

    @Test("The draft is addressed to the one feedback address and to nobody else")
    func draftAddressesTheOneConstant() {
        let draft = SemanticFeedbackMail(version: "1.0 (1861)")
        #expect(SemanticFeedbackMail.address == "feedback@frusexplorer.app")
        #expect(draft.recipients == ["feedback@frusexplorer.app"])
        #expect(!draft.subject.isEmpty)
        #expect(SemanticFeedbackMail.fileName == "frus-semantic-feedback.json")
        #expect(SemanticFeedbackMail.mimeType == "application/json")
    }

    @Test("The body names the build that wrote the file")
    func bodyNamesTheBuild() {
        let draft = SemanticFeedbackMail(version: "1.0 (1861)")
        #expect(draft.body.contains("1.0 (1861)"))
        #expect(SemanticFeedbackMail(version: "2.0 (9)").body != draft.body)
    }

    @Test("The running build's draft names this bundle's version and build")
    func currentNamesTheBundle() {
        let expected = "\(SyncDiagnosticsLog.appVersion) (\(SyncDiagnosticsLog.appBuild))"
        #expect(SemanticFeedbackMail.current.body.contains(expected))
        #expect(SemanticFeedbackMail.current == SemanticFeedbackMail(version: expected))
    }

    /// Source-scanned: the footer and the buttons are view code no unit test renders, and the gap
    /// #1545 recorded was a screen that named no destination.
    @Test("The screen names the address from the constant and offers the draft beside the share sheet")
    func screenOffersTheDraft() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("FRUSExplorer/Settings/SemanticFeedbackView.swift"),
            encoding: .utf8)
        #expect(source.contains("\\(SemanticFeedbackMail.address)"),
                "the footer must name the address from the constant")
        #expect(source.contains("if SemanticFeedbackMail.canCompose(attaching: exportURL) {"))
        #expect(source.contains("composeMail(attaching: exportURL)"))
        #expect(source.contains("ShareLink(item: exportURL)"), "the share sheet stays as the fallback")
        #expect(source.contains(".appendingPathComponent(SemanticFeedbackMail.fileName)"),
                "the draft must attach the file Prepare Feedback File writes")
        #expect(source.components(separatedBy: "feedback@frusexplorer.app").count == 2,
                "the address is one constant, spelt once")
    }
}
