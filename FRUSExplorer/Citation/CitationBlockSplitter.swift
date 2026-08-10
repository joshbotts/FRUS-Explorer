// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - CitationBlockSplitter

/// Splits a pasted block of footnotes into individual citations (#263).
///
/// The plan for this feature says "the citation engine needs zero changes", which is true of
/// `CitationMatchingEngine` and `CitationParser` — and hides where the work actually is.
/// `CitationParser.parse` takes **one** citation; nothing in the app turned a chapter's worth of
/// footnotes into the list of citations to hand it. That is this type.
///
/// ## Why not simply split on newlines
/// Real footnote blocks — the shape a historian pastes out of a manuscript or a PDF — break the
/// naive rule in both directions:
///
/// - **A footnote wraps.** Copied from a two-column PDF or a word processor at a narrow measure,
///   one citation arrives as three lines. Splitting per line yields three unparseable fragments
///   instead of one good citation.
/// - **Several footnotes share a line.** Pasted from a running notes paragraph, `1. … 2. … 3. …`
///   arrives unbroken.
///
/// So the numbered marker is the primary signal and the newline is the fallback, in that order.
///
/// Version history:
///   1.0 — Session 2026-08-10: #263 (F-10)
enum CitationBlockSplitter {

    /// A citation lifted out of a pasted block.
    struct Entry: Identifiable, Sendable, Equatable {
        /// 1-based position in the paste, so the table's order matches what the user pasted even
        /// after rows resolve out of order.
        let index: Int
        /// The footnote number as printed, when the block carried one. Display only — a footnote
        /// number is not a document number, and conflating them is the mistake this feature is
        /// most likely to invite.
        let marker: String?
        /// The citation text, with any leading marker removed, ready for `CitationParser`.
        let text: String

        var id: Int { index }
    }

    /// A leading footnote marker: `1.` / `12)` / `[3]` / `3 ` at the start of a citation.
    ///
    /// Deliberately bounded to 1–3 digits. FRUS chapters do not run to four-digit footnotes, and
    /// an unbounded match would eat the leading year of a citation that opens with one.
    private static let markerPattern = #"^\s*(?:\[(\d{1,3})\]|(\d{1,3})\s*[.)])\s+"#

    private static let markerRegex = try? NSRegularExpression(pattern: markerPattern)

    /// Whether `line` opens a new footnote.
    static func leadingMarker(_ line: String) -> String? {
        guard let markerRegex else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = markerRegex.firstMatch(in: line, range: range) else { return nil }
        for group in 1...2 where match.range(at: group).location != NSNotFound {
            if let r = Range(match.range(at: group), in: line) { return String(line[r]) }
        }
        return nil
    }

    /// Removes a leading footnote marker from `line`, if it has one.
    static func stripMarker(_ line: String) -> String {
        guard let markerRegex else { return line }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = markerRegex.firstMatch(in: line, range: range),
              let full = Range(match.range, in: line) else { return line }
        return String(line[full.upperBound...])
    }

    /// Splits `block` into citations.
    ///
    /// - Parameter block: Pasted text — one citation, a numbered footnote list, or a run of lines.
    /// - Returns: One entry per citation, in paste order. Empty when nothing usable was found.
    ///
    /// The rule, in order:
    /// 1. **A line opening with a footnote marker starts a new citation**, and subsequent
    ///    marker-less lines are appended to it — that is what un-wraps a citation broken across
    ///    lines by a narrow column.
    /// 2. **If the block carries no markers at all**, each non-empty line is one citation. This is
    ///    the plain list case, and treating a wrapped citation as two rows here is accepted: with
    ///    no marker there is no signal to tell a wrap from a new entry, and two rows that each
    ///    fail is more legible than one silently glued pair.
    /// 3. **Blank lines always end a citation**, under either rule.
    static func split(_ block: String) -> [Entry] {
        let lines = block.components(separatedBy: .newlines)
        let hasMarkers = lines.contains { leadingMarker($0) != nil }

        var entries: [Entry] = []
        var currentText = ""
        var currentMarker: String?

        func flush() {
            let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                entries.append(Entry(index: entries.count + 1, marker: currentMarker, text: trimmed))
            }
            currentText = ""
            currentMarker = nil
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { flush(); continue }
            if let marker = leadingMarker(line) {
                flush()
                currentMarker = marker
                currentText = stripMarker(line)
            } else if hasMarkers {
                // A continuation of the footnote above — join with a space, not a newline, so the
                // parser sees the citation as it was printed rather than as it was wrapped.
                currentText += currentText.isEmpty ? trimmed : " " + trimmed
            } else {
                flush()
                currentText = trimmed
            }
        }
        flush()
        return entries
    }
}

// MARK: - BatchCitationOutcome

/// What a batch row resolved to (#263).
///
/// Version history:
///   1.0 — Session 2026-08-10: #263 (F-10)
enum BatchCitationOutcome: Sendable, Equatable {
    /// Exactly one candidate — the row a reader can act on without thinking.
    case resolved
    /// More than one candidate. The count is carried because "3 possibilities" and "12" are
    /// different problems for someone triaging a chapter.
    case ambiguous(count: Int)
    /// The engine returned nothing.
    case missing
    /// The engine threw, or the text did not parse into anything to look up. Distinct from
    /// `missing` on purpose: "we looked and found nothing" and "we could not look" send a
    /// researcher to different next steps.
    case failed(reason: String)

    /// Classifies a completed lookup.
    ///
    /// - Parameter matches: The engine's ranked candidates.
    static func classify(matches: [CitationMatch]) -> BatchCitationOutcome {
        switch matches.count {
        case 0: return .missing
        case 1: return .resolved
        default: return .ambiguous(count: matches.count)
        }
    }

    /// Sort weight for "worst first" triage — the point of the table is to find what needs work.
    var triageOrder: Int {
        switch self {
        case .failed: return 0
        case .missing: return 1
        case .ambiguous: return 2
        case .resolved: return 3
        }
    }
}

// MARK: - BatchCitationRow

/// One row of the footnote triage table (#263).
///
/// Version history:
///   1.0 — Session 2026-08-10: #263 (F-10)
struct BatchCitationRow: Identifiable, Sendable {
    let entry: CitationBlockSplitter.Entry
    var outcome: BatchCitationOutcome
    /// The engine's candidates, kept so a resolved row opens directly and an ambiguous one can
    /// list its options without a second lookup.
    var matches: [CitationMatch]

    var id: Int { entry.index }

    /// The best candidate, for the one-tap open on a resolved row.
    var primaryMatch: CitationMatch? { matches.first }
}

// MARK: - BatchCitationRunner

/// Runs a pasted block through the citation engine, row by row (#263).
///
/// Sequential rather than concurrent, deliberately. `CitationMatchingEngine` is an actor over the
/// same index the rest of the app reads, and a chapter's footnotes are tens of rows, not
/// thousands — fanning them out would contend for the index to shave a second off a paste the
/// user is about to read line by line anyway. It also keeps rows arriving in paste order, which
/// is what makes partial progress legible.
///
/// Version history:
///   1.0 — Session 2026-08-10: #263 (F-10)
enum BatchCitationRunner {

    /// Looks up every citation in `entries`.
    ///
    /// - Parameters:
    ///   - entries: The split citations.
    ///   - engine: The shared matching engine.
    ///   - parser: The shared parser.
    ///   - onRow: Called as each row completes, so the table can fill in progressively.
    ///
    /// A row that throws becomes `.failed` rather than aborting the batch: one malformed footnote
    /// in a chapter must not cost the reader the other forty.
    static func run(
        entries: [CitationBlockSplitter.Entry],
        engine: CitationMatchingEngine,
        parser: CitationParser,
        onRow: @MainActor (BatchCitationRow) -> Void
    ) async {
        for entry in entries {
            let parsed = parser.parse(entry.text)
            let input = CitationInput(
                rawText: entry.text,
                subseries: parsed.subseries,
                volumeNumber: parsed.volumeNumber,
                documentNumber: parsed.documentNumber,
                pageNumber: parsed.pageNumber,
                titleFragment: parsed.titleFragment,
                parserConfidence: parsed.parserConfidence
            )
            var row: BatchCitationRow
            do {
                let matches = try await engine.match(input: input)
                row = BatchCitationRow(entry: entry,
                                       outcome: .classify(matches: matches),
                                       matches: matches)
            } catch {
                row = BatchCitationRow(entry: entry,
                                       outcome: .failed(reason: error.localizedDescription),
                                       matches: [])
            }
            let completed = row
            await MainActor.run { onRow(completed) }
        }
    }
}
