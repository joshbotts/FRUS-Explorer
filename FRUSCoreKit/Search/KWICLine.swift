// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - KWICLine

/// One occurrence of a search term, with the text either side of it — a keyword-in-context line.
///
/// ## One row per occurrence, not per document
/// Decision R-3-1. The list view shows a document once with its first match; a concordance shows
/// every match. A document that uses a phrase nine times *is* the finding, and collapsing it to one
/// row hides exactly what a concordance is for. `SearchService.makeContextSnippet` returns only the
/// first match, so this scans for all of them.
///
/// ## Alignment is the whole point
/// Concordance reading works because the term sits in a fixed column and the eye runs down the
/// margins. Repeated formulae appear as repeated left contexts — the way you notice that a phrase is
/// boilerplate in one bureau and argument in another. That is why ``leftSortKey`` reverses the left
/// context: sorting on it groups lines by the word immediately *before* the match, which is where a
/// formula announces itself.
///
/// Version history:
///   1.0 — R-3b: initial implementation
struct KWICLine: Identifiable, Equatable, Sendable {

    /// The document this occurrence is in.
    let volumeId: String
    let documentId: String
    /// Display header for the source document.
    let header: String
    /// ISO date, for the date sort and for display.
    let dateISO: String?

    /// Text before the match, already trimmed to the context window.
    let left: String
    /// The matched text, exactly as it appears in the document — not the stem, and not the query.
    let match: String
    /// Text after the match.
    let right: String

    /// Character offset of the match in the source body, which makes each line unique within a
    /// document and gives the concordance a stable identity across re-sorts.
    let offset: Int

    var id: String { "\(volumeId)/\(documentId)#\(offset)" }

    /// Sort key for "group by what comes before the match".
    ///
    /// The left context **reversed by character**, so that ordering ascending puts lines with the
    /// same immediately-preceding word together. Sorting on the un-reversed left context would order
    /// by the *start* of the window — which is an arbitrary point ~40 characters back, and groups
    /// nothing.
    var leftSortKey: String { String(left.lowercased().reversed()) }

    /// Sort key for "group by what follows the match" — the right context as it reads.
    var rightSortKey: String { right.lowercased() }
}

// MARK: - KWICBuilder

/// Turns a document body into one ``KWICLine`` per occurrence of the query's terms.
///
/// Version history:
///   1.0 — R-3b: initial implementation
enum KWICBuilder {

    /// Maximum lines built from one document, so a pathological document cannot dominate the view.
    ///
    /// A bound has to exist — a single FRUS document can mention a common word hundreds of times —
    /// but a silent one would misrepresent the corpus, so ``build(...)`` reports the truncation and
    /// the UI states it. 200 is generous enough that no ordinary document reaches it.
    static let maxLinesPerDocument = 200

    /// Result of scanning one document: its lines, and whether the bound cut any off.
    struct DocumentScan: Equatable {
        var lines: [KWICLine]
        /// Occurrences beyond ``maxLinesPerDocument`` that were not built.
        var omittedCount: Int
    }

    /// Builds concordance lines for every occurrence of `stems` in `body`.
    ///
    /// ## Matching mirrors the highlighter, deliberately
    /// A word matches when its Porter stem is in `stems`, which is exactly what
    /// `SearchService.makeContextSnippet` does for highlighting. Two consequences worth stating,
    /// because both are visible to a researcher:
    ///
    /// 1. The stems come from the app's **Swift** `PorterStemmer`, while the index that decided
    ///    *which documents matched* used SQLite's `porter unicode61`. The two disagree on some words
    ///    (`alliance` → `alli` vs `allianc`). So a document can be in the result set and produce no
    ///    concordance line. That is a pre-existing property of the highlighter, not something this
    ///    introduces — but a concordance makes it visible, because an empty line list is more
    ///    conspicuous than an unhighlighted snippet. Callers must render "no aligned occurrences"
    ///    rather than dropping the document silently.
    /// 2. Matching is per **word**, so a phrase query yields a line per matching word rather than one
    ///    per phrase. Aligning on the phrase would need the engine's own positions.
    ///
    /// - Parameters:
    ///   - body: the document's text.
    ///   - stems: Porter stems of the query's positive terms.
    ///   - radius: characters of context either side, extended outward to a word boundary.
    static func build(
        body: String,
        stems: [String],
        radius: Int,
        volumeId: String,
        documentId: String,
        header: String,
        dateISO: String?
    ) -> DocumentScan {
        guard !body.isEmpty, !stems.isEmpty else { return DocumentScan(lines: [], omittedCount: 0) }
        let stemSet = Set(stems)
        // The same near-free rejection the highlighter uses: Porter only rewrites suffixes, so a word
        // whose first character is not among the stems' first characters cannot stem to one.
        let firstLetters = Set(stemSet.compactMap { $0.first })

        let characters = Array(body)
        var lines: [KWICLine] = []
        var omitted = 0
        var index = 0

        while index < characters.count {
            // Walk to the start of the next word.
            guard characters[index].isLetter || characters[index].isNumber else {
                index += 1
                continue
            }
            let wordStart = index
            while index < characters.count, characters[index].isLetter || characters[index].isNumber {
                index += 1
            }
            let word = String(characters[wordStart..<index])
            guard let first = word.lowercased().first, firstLetters.contains(first) else { continue }
            guard stemSet.contains(PorterStemmer.stem(word.lowercased())) else { continue }

            if lines.count >= maxLinesPerDocument {
                omitted += 1
                continue
            }
            let leftStart = Self.wordBoundary(characters, from: max(0, wordStart - radius),
                                              isLeftEdge: true)
            let rightEnd = Self.wordBoundary(characters, from: min(characters.count, index + radius),
                                             isLeftEdge: false)
            lines.append(KWICLine(
                volumeId: volumeId,
                documentId: documentId,
                header: header,
                dateISO: dateISO,
                left: String(characters[leftStart..<wordStart])
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                match: word,
                right: String(characters[index..<rightEnd])
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                offset: wordStart
            ))
        }
        return DocumentScan(lines: lines, omittedCount: omitted)
    }

    /// Moves `position` outward to the nearest word boundary, so a context window never begins or
    /// ends mid-word.
    ///
    /// Outward rather than inward: a window cut to `…he Departmen` is harder to read than one
    /// slightly longer than the radius, and the radius is a comfort setting, not a contract. The
    /// left edge walks LEFT to the start of the word it landed in; the right edge walks RIGHT to the
    /// end of its word. Both are clamped to the document, so an edge match simply yields an empty
    /// side.
    private static func wordBoundary(
        _ characters: [Character], from position: Int, isLeftEdge: Bool
    ) -> Int {
        var position = position
        if isLeftEdge {
            guard position > 0 else { return 0 }
            while position > 0, characters[position - 1].isLetter || characters[position - 1].isNumber {
                position -= 1
            }
            return position
        } else {
            guard position < characters.count else { return characters.count }
            while position < characters.count,
                  characters[position].isLetter || characters[position].isNumber {
                position += 1
            }
            return position
        }
    }
}

// MARK: - KWICSort

/// How a concordance is ordered.
///
/// Version history:
///   1.0 — R-3b: initial implementation
enum KWICSort: String, CaseIterable, Sendable {
    /// By the word immediately before the match — how repeated formulae surface.
    case leftContext
    /// By what follows the match.
    case rightContext
    /// Chronological. Undated documents sort last rather than as the empty string, which would put
    /// them first and read as "earliest".
    case date
    /// By volume, then position within the document — the order the corpus itself is in.
    case volume

    var pickerLabel: String {
        switch self {
        case .leftContext:
            return String(localized: "search.kwic.sort.left", defaultValue: "Left context")
        case .rightContext:
            return String(localized: "search.kwic.sort.right", defaultValue: "Right context")
        case .date:
            return String(localized: "search.kwic.sort.date", defaultValue: "Date")
        case .volume:
            return String(localized: "search.kwic.sort.volume", defaultValue: "Volume")
        }
    }

    /// Orders `lines` by this criterion.
    ///
    /// Every comparison falls through to `id` so the order is total: two lines with identical
    /// context would otherwise be free to swap between renders, and a concordance that reshuffles
    /// under the reader is worse than one sorted oddly.
    func apply(to lines: [KWICLine]) -> [KWICLine] {
        switch self {
        case .leftContext:
            return lines.sorted { $0.leftSortKey == $1.leftSortKey ? $0.id < $1.id : $0.leftSortKey < $1.leftSortKey }
        case .rightContext:
            return lines.sorted { $0.rightSortKey == $1.rightSortKey ? $0.id < $1.id : $0.rightSortKey < $1.rightSortKey }
        case .date:
            return lines.sorted { a, b in
                switch (a.dateISO, b.dateISO) {
                case let (x?, y?): return x == y ? a.id < b.id : x < y
                case (nil, nil):   return a.id < b.id
                case (nil, _):     return false   // undated last
                case (_, nil):     return true
                }
            }
        case .volume:
            return lines.sorted { a, b in
                if a.volumeId != b.volumeId { return a.volumeId < b.volumeId }
                if a.documentId != b.documentId { return a.documentId < b.documentId }
                return a.offset < b.offset
            }
        }
    }
}

// MARK: - ConcordanceResult

/// A page's worth of concordance lines, with what the build could not show.
///
/// The two counts are not decoration. A concordance is read as evidence, so the reader has to be
/// able to tell "this is everything" from "this is everything that fitted" — and from "some of these
/// documents matched in a way this view cannot align".
///
/// Version history:
///   1.0 — R-3b: initial implementation
struct ConcordanceResult: Equatable, Sendable {
    /// Lines, in the order the results were supplied. Callers apply a ``KWICSort``.
    let lines: [KWICLine]
    /// Occurrences dropped by ``KWICBuilder/maxLinesPerDocument``.
    let omittedCount: Int
    /// Documents in the page that produced no line at all — either absent from the cache, or
    /// matched by SQLite's stemmer in a way the Swift stemmer does not reproduce.
    let documentsWithoutLines: Int
}
