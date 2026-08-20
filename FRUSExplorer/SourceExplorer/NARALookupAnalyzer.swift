// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

// `SourceNoteKit` is compiled INTO the app target through project.yml's source glob
// (the FTS5Store/WordCloudKit pattern), so its types are already in this module — an
// `import SourceNoteKit` here fails to resolve.
import Foundation

// MARK: - NARALookupCandidate

/// One reading of the reader's selection: what to search for, where to search, and — when the
/// bundled indexes can already answer — the NARA record itself.
struct NARALookupCandidate: Identifiable, Sendable, Equatable {

    /// Where in the reader's text this candidate was found.
    ///
    /// The distinction drives ranking, not display: a citation inside the selected characters is
    /// what the reader pointed at, while one recovered from the surrounding sentences is context
    /// the app volunteered. Both are offered; the first is offered first.
    enum Origin: Sendable, Equatable {
        /// Found in the characters the reader actually selected.
        case selection
        /// Found in the passage around the selection.
        case context
    }

    /// Stable identity for `ForEach` — the query plus the strategy, since the same lot may be
    /// reachable under two strategies and both rows are meaningful.
    var id: String { "\(strategy.rawValue)|\(query)" }

    /// What the reader sees on the row — the citation as printed, not a normalised key.
    let label: String
    /// The text handed to the search field / catalog query.
    let query: String
    /// Where this candidate should be looked up.
    let strategy: LookupStrategy
    /// Whether this came from the selection or its surroundings.
    let origin: Origin
    /// The NARA record the bundled indexes already resolve for this candidate, when they do.
    ///
    /// This is the whole point of #235's "candidate resolutions": a lot the app has shipped an
    /// answer for since #372 should show that answer immediately, with no API key and no network,
    /// rather than sending the reader to a search field to find what the bundle already holds.
    let resolution: ArchivalResolution?
}

// MARK: - NARALookupAnalyzer

/// Turns a text selection into ranked, routed, offline-resolved NARA lookup candidates (#235).
///
/// ## What this replaces
/// The lookup sheet used to open on a hardcoded `.keywordRG59` with an empty candidate list for
/// every ordinary body selection, because detection ran only over a `blockContext` the in-document
/// path never supplied. A reader selecting `Lot 63 D 135` was shown a radio group of six search
/// strategies and a text field — and needed an API key before anything at all appeared, even for
/// lots the app had already resolved into `central-files-index.json`.
///
/// ## Why a type and not more code in the view
/// `NARACatalogLookupView` computed its detection inside `init` from a `let`, which is why none of
/// it could be tested without standing up a SwiftUI view. Ranking and offline resolution are
/// decisions with real failure modes — a wrong rank puts the useless row first, a wrong resolution
/// puts an unrelated series behind a citation — so they live somewhere a test can drive them.
///
/// ## Three deliberate non-goals
/// 1. **The shared grammar is not edited.** `SourceNoteParser`'s extraction patterns are pinned by
///    `eval-baseline.txt` and shared with `SourceExplorerExportGenerator`,
///    `CollectionUsageIndexGenerator` and `ExternalCitationIndexGenerator`; changing what they
///    match would move measured generator output. This composes the existing public entry points —
///    `extractCitations(from:)` and `decimalClassLocation(inCitation:)` — and adds none.
/// 2. **Resolution goes through `ArchivalResolver`**, the same path Source Explorer and the
///    Collections export use, so a lot resolves to the same record on every surface. A second
///    lookup written here is a second thing that can disagree.
/// 3. **Nothing is auto-searched.** Candidates are offered; the live API call stays behind the
///    reader's own tap. Offline resolution is free, a network round trip is not.
///
/// Version history:
///   1.0 — Session 2026-08-20: #235
enum NARALookupAnalyzer {

    /// How far around the selection the caller should widen, in UTF-16 units.
    ///
    /// A source note's archival clause runs to a few hundred characters and the citation usually
    /// precedes the selected phrase (`Department of State, Central Files, 763.72/1476`), so the
    /// window reaches further back than forward. It is a window and not a sentence scan because
    /// the flat text has no reliable sentence bound — `SourceNoteParser`'s own comment records
    /// that footnote prose defeats sentence bounding.
    static let contextBefore = 320
    /// Forward reach, in UTF-16 units.
    static let contextAfter = 160

    /// Ranked candidates for a selection and its surrounding passage.
    ///
    /// - Parameters:
    ///   - selection: The characters the reader selected.
    ///   - context: The surrounding passage, when the caller could supply one.
    ///   - centralFiles: The bundled central-files index; injected so tests need no app bundle.
    ///   - volumeSources: The bundled volume-sources index, for the same reason.
    /// - Returns: Candidates, best first. Empty when nothing in the text is recognisable, which is
    ///   when the sheet falls back to the manual field the issue asks to keep.
    static func candidates(selection: String,
                           context: String?,
                           centralFiles: CentralFilesIndex? = CentralFilesIndexStore.shared,
                           volumeSources: VolumeSourcesIndex? = VolumeSourcesIndexStore.shared)
        -> [NARALookupCandidate] {
        var out: [NARALookupCandidate] = []
        var seen = Set<String>()

        // The selection is read first so its candidates win the stable sort on equal rank.
        for (text, origin) in [(selection, NARALookupCandidate.Origin.selection),
                               (context ?? "", .context)] {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            for candidate in read(trimmed, origin: origin,
                                  centralFiles: centralFiles, volumeSources: volumeSources)
            where !seen.contains(candidate.id) {
                seen.insert(candidate.id)
                out.append(candidate)
            }
        }
        return out.enumerated()
            .sorted { rank($0.element, $0.offset) < rank($1.element, $1.offset) }
            .map(\.element)
    }

    /// Every candidate readable out of one passage.
    ///
    /// Three readers, because no single one covers the text a reader actually selects:
    ///
    /// - `decimalClassLocation` for a decimal file number (`763.72/1476`), which routes to
    ///   `.centralURL` — the only strategy that needs no API key.
    /// - `firstLotReference`, walked to exhaustion, for lot numbers. This and **not**
    ///   `extractCitations` is the lot reader: `extractCitations` is anchored on a repository
    ///   phrase (`National Archives, RG 59, …` or a presidential library), so it returns nothing
    ///   for `Department of State, Conference Files: Lot 60 D 224` — the commonest shape in the
    ///   corpus and the one a reader is most likely to select. Its own doc calls
    ///   `firstLotReference` "the single lot-recognition entry point for both citation sides",
    ///   which is exactly the property this needs: a lot keyed here reduces to the same
    ///   `lotFileNorm` key the bundled indexes are keyed by.
    /// - `extractCitations` for the repository-anchored shapes it *does* cover, which contribute
    ///   series and collection names a lot scan cannot see.
    private static func read(_ text: String,
                             origin: NARALookupCandidate.Origin,
                             centralFiles: CentralFilesIndex?,
                             volumeSources: VolumeSourcesIndex?) -> [NARALookupCandidate] {
        var out: [NARALookupCandidate] = []

        if let decimal = SourceNoteParser.decimalClassLocation(inCitation: text) {
            out.append(NARALookupCandidate(label: decimal, query: decimal,
                                           strategy: .centralURL, origin: origin,
                                           resolution: nil))
        }

        // Every lot in the passage, not just the first: a source note routinely names several
        // ("Lot 60 D 224" and "Lot 63 D 351" in one sentence), and offering only the first would
        // hide the one the reader was reaching for.
        var cursor = text.startIndex
        while cursor < text.endIndex,
              let hit = SourceNoteParser.firstLotReference(in: String(text[cursor...])) {
            let lot = hit.lotNumber
            let bareRG = CollectionKeying.bareRG(SourceNoteParser.lotFileRecordGroup(lot))
            out.append(NARALookupCandidate(
                label: String(format: String(localized: "nara.lookup.candidate.lot %@",
                                             defaultValue: "Lot %@"), lot),
                query: lot,
                strategy: LookupStrategy.lotStrategy(recordGroup: bareRG, lotFile: lot),
                origin: origin,
                // The bundled answer, if there is one. `documentResolution` is the document route
                // — a lot resolves only through its own number, never through the citation's
                // record group, which is the rule #372 preserved.
                resolution: ArchivalResolver.documentResolution(
                    lotFile: lot, centralFiles: centralFiles, volumeSources: volumeSources)))
            // Advance past this match. `firstLotReference` returns a range in the SLICE, so it is
            // mapped back through the slice's own start index; advancing by one character instead
            // would rescan the same lot forever on any text where the match is a single token.
            let sliceStart = cursor
            let consumedEnd = String(text[sliceStart...]).distance(from: String(text[sliceStart...]).startIndex,
                                                                   to: hit.matchRange.upperBound)
            cursor = text.index(sliceStart, offsetBy: max(1, consumedEnd), limitedBy: text.endIndex)
                ?? text.endIndex
        }

        // The repository-anchored shapes: series and collection names, which have no lot to key on.
        for citation in SourceNoteParser().extractCitations(from: text) {
            guard let series = citation.seriesName,
                  !series.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            out.append(NARALookupCandidate(
                label: citation.rawText.trimmingCharacters(in: .whitespacesAndNewlines),
                query: series,
                strategy: LookupStrategy.keywordStrategy(recordGroup: citation.recordGroup),
                origin: origin, resolution: nil))
        }
        return out
    }

    /// Sort key. Lower sorts first.
    ///
    /// Two keys, not three, and the missing one is the point. The order is an argument about a
    /// reader who may have no API key: **an answer already in hand**, then **a route that needs no
    /// key**, then discovery order as a stable tiebreak so two equally-ranked candidates never
    /// swap places between launches.
    ///
    /// ## Why there is no `origin` key
    /// A first version ranked `.selection` above `.context` as a third key. Mutation testing
    /// showed it was **unfalsifiable**: `candidates(selection:context:)` reads the selection first,
    /// so a selection candidate always holds a lower discovery index and wins the tiebreak
    /// anyway. Deleting the key changed no outcome in any test. It is gone rather than kept as
    /// decoration — a rank key that cannot fail is a claim the code does not actually make, and
    /// this file would otherwise read as though the preference were enforced here when it is
    /// really enforced by read order. `NARALookupAnalyzerTests.selectionOutranksContext` still
    /// pins the *behaviour*; it just pins it where it lives.
    ///
    /// The `.centralURL` key, by contrast, IS load-bearing, and only across passages: a decimal
    /// found in the surrounding context must still outrank a lot found in the selection, because
    /// the decimal opens a real catalog page for a reader with no key while the lot can only
    /// pre-fill a search they cannot run. That case is pinned by
    /// `centralURLInContextOutranksLotInSelection`, which is what finally killed the mutant.
    private static func rank(_ candidate: NARALookupCandidate, _ index: Int) -> (Int, Int, Int) {
        (candidate.resolution == nil ? 1 : 0,
         candidate.strategy == .centralURL ? 0 : 1,
         index)
    }
}
