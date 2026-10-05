// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CollectionCitationLineResolver

/// The pure per-line citation resolution pipeline behind the sheet's Citations tab.
///
/// Splits pasted text into non-empty lines and classifies each line into exactly one
/// bucket — resolved, ambiguous, or unresolved — so no input line is ever silently
/// dropped. Parsing and matching are injected as closures, so the pipeline is unit
/// testable without a `CitationMatchingEngine` (or any database).
///
/// ## Line classification
/// 1. The line is parsed (`CitationParser` in production); a non-actionable parse is
///    unresolved. A `history.state.gov/historicaldocuments/{volumeId}/{segment}` link
///    parses to its exact reference (`CitationParser.exactReference(in:)`), the ids kept
///    as written.
/// 2. The matcher's ranked results are inspected: a lone document-level match with an
///    exact strategy resolves; document-level matches behind a best-guess
///    strategy or with competing candidates are ambiguous (the top match is surfaced
///    with its rank note); volume-only matches (empty `documentId`, e.g. an
///    un-downloaded volume) and empty result sets are unresolved with the engine's
///    own explanation. Two guards keep "resolved" honest: a document-level hit that
///    the engine itself outranked with a volume-only candidate (e.g. the better-fit
///    volume isn't downloaded) is at most ambiguous, and a parse that identifies no
///    volume at all (no subseries, no volume number — the engine then matched
///    against an arbitrary manifest slice) is at most ambiguous.
/// 3. A link goes through the matcher like any other line (#1502), which finds its volume in
///    the manifest as the manifest spells it — a pasted link keeps the site's capitals, and a
///    retyped one may not — and, in a downloaded volume, its document in the index, as written
///    and then ignoring case. A volume the manifest does not have yields nothing, so no entry is
///    ever added for it. One addition to step 2: a link to a numbered document (`d12`, `d373a`)
///    in a volume that is not downloaded resolves to that document under the manifest's volume
///    id, as links always have — the volume cannot be searched yet, and the link names the
///    document exactly. So does one in a volume that is downloaded and not yet indexed (#1522),
///    which cannot be searched yet either: the entry resolves once the volume is indexed.
///
/// Version history:
///   1.0 — Authoring Phase 3: initial implementation
///   1.1 — Authoring Phase 3 review: never bucket a line "resolved" when the engine's
///          own top-ranked candidate was volume-only, or when the parse carried no
///          volume identity; URL matcher lowercases the volume id (canonical form)
///   1.2 — #1503: a page several documents share (`MatchStrategy.sharedPage`) is not an
///          exact strategy, so a page-only line naming one is ambiguous — before #1503 the
///          engine answered it with one document, the wrong one, and the line resolved
///   1.3 — #1503 review round 1: an ambiguous line's note gives one count for a shared page,
///          every document on it (`CitationMatch.sharedPageTotal`), not the listed ten beside it
///   1.4 — #1502: a link is resolved through the parser and the matcher, not by lower-casing
///          its ids — 51 of the 553 volume ids are mixed-case (`frus1919Parisv01`), so a pasted
///          link to any of their 26,029 documents was added under a volume id no volume has, and
///          a link to a volume the manifest lacks was added all the same; a link to a volume not
///          yet downloaded keeps its document id's suffix as written and its `d` in lower case
///   1.5 — #1522: a link to a numbered document in a volume downloaded and not yet indexed is
///          added by its id too (`unsearchableLinkDocument`, was `undownloadedLinkDocument`); it
///          stayed unresolved under "no document the citation names was found in it"
struct CollectionCitationLineResolver: Sendable {

    // MARK: - Outcome

    /// The bucket a single pasted line landed in.
    enum Outcome: Equatable, Sendable {
        /// Confident match: the line maps to exactly this document.
        case resolved(volumeId: String, documentId: String, note: String?)
        /// A plausible top match with competition or a correction applied; `note`
        /// explains the ranking so the user can review before adding.
        case ambiguous(volumeId: String, documentId: String, note: String)
        /// No document-level match; `reason` is always shown, never silently dropped.
        case unresolved(reason: String)
    }

    // MARK: - LineResult

    /// One pasted line together with its classification.
    struct LineResult: Identifiable, Sendable {
        /// Stable row identity for SwiftUI lists.
        let id = UUID()
        /// The original (trimmed) input line.
        let line: String
        /// The bucket the line resolved into.
        let outcome: Outcome
    }

    // MARK: - Injected stages

    /// Parses a raw citation line into structured fields (`CitationParser.parse` in
    /// production; a stub in tests).
    let parse: @Sendable (String) -> CitationInput

    /// Resolves parsed fields to ranked matches (`CitationMatchingEngine.match` in
    /// production; a stub in tests).
    let match: @Sendable (CitationInput) async throws -> [CitationMatch]

    // MARK: - Line splitting

    /// Splits pasted text into trimmed, non-empty lines.
    static func lines(from text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - history.state.gov links

    /// The document a history.state.gov link on `line` names in a volume that cannot be searched
    /// yet: the manifest's spelling of the volume the matcher answered with (`volumeOnly`) and the
    /// link's segment with its `d` in lower case and its suffix as written, when the matcher's row
    /// offers the volume for download or says it is not yet indexed (`awaitingIndex`, #1522), the
    /// link names that volume, and its segment is a numbered document (`d12`, `d373a`, `d550A`);
    /// `nil` otherwise (#1502).
    ///
    /// A volume that is not downloaded, or downloaded and not yet indexed, cannot be searched, so
    /// the segment is taken on the link's word — as every link was before #1502 — but only in the
    /// shape that is always a document. Any other segment may be a chapter (`ch3`) or a document
    /// (`appA`, `eta_d1`), and which one only the volume's index can say, so the line stays
    /// unresolved with the matcher's explanation: "download", or "not yet indexed". The volume is
    /// the manifest's, never the link's spelling: that is #1502's fix. A downloaded volume whose
    /// index holds nothing the link names is not taken on its word: that row is neither
    /// (`ConfidenceLabels.linkVolumeOnly`), and the document is not there.
    ///
    /// The `d` is folded because no document id in the corpus begins with a capital `D` (the one
    /// `xml:id="D1"` in the 744 files is a glossary term), so a retyped all-caps link's `D42` is
    /// `d42`, as it was before #1502; kept as written, it named no document, and the entry opened
    /// and exported as a missing one once its volume came down (#1502 review round 1). The suffix
    /// stays as written: `d550A` is a document of `frus1955-57v03mSupp`, and which case a retyped
    /// suffix had only the volume's index can say.
    static func unsearchableLinkDocument(
        _ reference: CitationExactReference?, volumeOnly: CitationMatch?
    ) -> (volumeId: String, documentId: String)? {
        guard let reference, let segment = reference.documentId,
              let volumeOnly, volumeOnly.requiresDownload || volumeOnly.awaitingIndex,
              volumeOnly.documentId.isEmpty,
              volumeOnly.volumeId.caseInsensitiveCompare(reference.volumeId) == .orderedSame,
              segment.range(of: #"^[dD]\d+[A-Za-z]*$"#, options: .regularExpression) != nil
        else { return nil }
        return (volumeId: volumeOnly.volumeId, documentId: "d" + segment.dropFirst())
    }

    // MARK: - Resolution

    /// Resolves every non-empty line of `text`, preserving input order.
    func resolve(text: String) async -> [LineResult] {
        var results: [LineResult] = []
        for line in Self.lines(from: text) {
            results.append(LineResult(line: line, outcome: await resolve(line: line)))
        }
        return results
    }

    /// Classifies a single line (see the type doc comment for the bucketing rules).
    func resolve(line: String) async -> Outcome {
        // 1. Parse; a line with no usable fields can't be matched. A history.state.gov link
        //    parses to its exact reference, and the matcher resolves it (#1502).
        let input = parse(line)
        guard input.isActionable else {
            return .unresolved(reason: String(
                localized: "collection.addDocs.citations.unparseable",
                defaultValue: "Couldn’t read this line as a FRUS citation or document link"))
        }

        // 2. Match and bucket the ranked results.
        let matches: [CitationMatch]
        do {
            matches = try await match(input)
        } catch {
            return .unresolved(reason: error.localizedDescription)
        }

        let documentLevel = matches.filter { !$0.documentId.isEmpty }
        if let top = documentLevel.first {
            // The engine's own top-ranked candidate may be volume-only (e.g. the
            // better-fit volume isn't downloaded, so the engine stopped at a
            // manifest match and moved on). Presenting a lower-ranked document hit
            // as confident would silently discard that competitor — surface it.
            if let overallTop = matches.first, overallTop.rank != top.rank {
                return .ambiguous(
                    volumeId: top.volumeId, documentId: top.documentId,
                    note: String(
                        localized: "collection.addDocs.citations.outranked",
                        defaultValue: "\(top.confidenceLabel) — but the engine ranked \(overallTop.volumeId) higher: \(overallTop.confidenceLabel)"))
            }
            // A parse with no volume identity at all matched against an arbitrary
            // slice of the manifest — never confident, whatever the strategy says.
            if input.subseries == nil && input.volumeNumber == nil {
                return .ambiguous(
                    volumeId: top.volumeId, documentId: top.documentId,
                    note: String(
                        localized: "collection.addDocs.citations.noVolumeIdentity",
                        defaultValue: "\(top.confidenceLabel) — the citation doesn’t identify a volume, so this match is a guess"))
            }
            if Self.isExactStrategy(top.matchStrategy),
               top.matchStrategy == .exactDocumentNumber || documentLevel.count == 1 {
                return .resolved(volumeId: top.volumeId, documentId: top.documentId,
                                 note: top.correctionNote)
            }
            return .ambiguous(volumeId: top.volumeId, documentId: top.documentId,
                              note: rankNote(for: top, of: documentLevel.count))
        }

        // 3. A link to a numbered document in a volume that cannot be searched yet — not
        //    downloaded, or downloaded and not yet indexed (#1522): the document the link names, in
        //    the volume the manifest has (#1502).
        if let linked = Self.unsearchableLinkDocument(input.exactReference, volumeOnly: matches.first) {
            return .resolved(volumeId: linked.volumeId, documentId: linked.documentId, note: nil)
        }

        // Volume-only results (e.g. an un-downloaded volume, or one not yet indexed) carry an
        // explanation.
        if let top = matches.first {
            return .unresolved(reason: top.confidenceLabel)
        }
        return .unresolved(reason: String(
            localized: "collection.addDocs.citations.noMatch",
            defaultValue: "No match found in the local manifest or index"))
    }

    /// Whether a match strategy identifies its document with confidence (as opposed
    /// to a best-guess correction, or one of the documents a cited
    /// page names when it cannot choose — several, or in a volume that numbers its pages
    /// per document any, #1503).
    private static func isExactStrategy(_ strategy: MatchStrategy) -> Bool {
        switch strategy {
        case .exactDocumentNumber, .superimposedDocumentNumber, .pageRange:
            return true
        case .titleFragmentMatch, .manifestOnly, .bestGuess, .sharedPage:
            return false
        }
    }

    /// Builds the user-facing rank note for an ambiguous top match: the engine's own
    /// confidence label, plus the candidate count when there was competition.
    ///
    /// A page that cannot choose between its documents (#1503) is counted once, by every
    /// document on it: a `.sharedPage` label already says "one of 12 documents …", so it
    /// stands alone, and a best guess over such a page counts the page's documents rather
    /// than the ten listed (#1503 review round 1: the note read "one of 12 documents … —
    /// top of 10 candidates"). The engine's `sharedPageNote` is not repeated here: the row
    /// shows two lines, which the label fills.
    private func rankNote(for top: CitationMatch, of candidateCount: Int) -> String {
        if case .sharedPage = top.matchStrategy { return top.confidenceLabel }
        let candidateCount = max(candidateCount, top.sharedPageTotal ?? 0)
        guard candidateCount > 1 else { return top.confidenceLabel }
        return String(
            localized: "collection.addDocs.citations.topOf",
            defaultValue: "\(top.confidenceLabel) — top of \(candidateCount) candidates")
    }
}
