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
        #expect(source.contains("case .sharedTerms(let terms):"),
                "the chip case must have a render arm or it is dead again")
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
        // The era must be captured, or the log cannot answer the question it replaced.
        #expect(source.contains("CoverageEra.bucket(year:"))
    }
}
