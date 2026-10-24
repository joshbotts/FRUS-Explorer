// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - Locating a stored passage (R-5 P3b-3, design §8.2 Q-10 option b)

extension HighlightReview {

    /// One relocation candidate: FRUSCoreKit's `HighlightReanchor.Match`, under the name the review
    /// sheet calls it by.
    ///
    /// Version history:
    ///   1.0 — R-5 P3b-3: initial implementation
    ///   1.1 — Session 2026-10-24 (FRUS Explorer Light, S15a): the search, its outcomes and its
    ///          limits moved to FRUSCoreKit's `HighlightReanchor`
    ///          (`FRUSCoreKit/DocumentView/HighlightReanchorSearch.swift`), unchanged; these names
    ///          are typealiases and `locate` forwards to it
    typealias Match = HighlightReanchor.Match

    /// What an exact, unique, seam-aware search found: `HighlightReanchor.Search`.
    typealias Search = HighlightReanchor.Search

    /// Why a search was refused before it ran: `HighlightReanchor.Refusal`.
    typealias Refusal = HighlightReanchor.Refusal

    /// Finds every place the stored passage could sit in the current text:
    /// `HighlightReanchor.locate(passage:storedStart:storedEnd:in:)`.
    ///
    /// - Parameters:
    ///   - passage: the highlight's stored `selectedText`.
    ///   - storedStart: the highlight's current start offset, for the distance judgement.
    ///   - storedEnd: its current end offset.
    ///   - blocks: `buildFlatTextBlocks(from:)` for the document as it reads now.
    static func locate(passage: String, storedStart: Int, storedEnd: Int,
                       in blocks: [String]) -> Search {
        HighlightReanchor.locate(passage: passage, storedStart: storedStart, storedEnd: storedEnd,
                                 in: blocks)
    }
}

// MARK: - Moving a highlight

extension HighlightReview {

    /// Moves a highlight to a located span, after the reader has confirmed it.
    ///
    /// **Never called without an explicit tap** (design §7: the repair is offered, shown and
    /// confirmed, never applied on the reader's behalf).
    ///
    /// Writes the offsets and then the version, and the version is not optional: the painter
    /// chooses the amber "stale" class purely from `renderingVersion != currentVersion`, and the
    /// tap handler skips stale highlights — so moving without it leaves a highlight that has
    /// relocated, stayed amber, become untappable, and will be offered for repair for ever.
    ///
    /// **`selectedText` is deliberately NOT re-frozen.** Under the modern shape it would be a
    /// no-op, and under the pre-July-2026 raw-slice shape it would silently rewrite the reader's
    /// stored words into the seam-joined form at the moment the app promised to change only the
    /// position. `CollectionExcerpts.capture(from:)` copies that string verbatim into collection
    /// excerpts, so re-freezing would also change what a later capture quotes. `colorTag` is
    /// untouched for the same reason: it is not what moved.
    ///
    /// This is the first post-creation write to `startOffset`/`endOffset` anywhere in the app.
    /// `HighlightSignature` carries all three fields, so the highlight repaints in place, while
    /// the sheet is still open, with no reload.
    static func move(_ highlight: DocumentHighlight, to match: Match, currentVersion: String) {
        guard !currentVersion.isEmpty, match.end > match.start else { return }
        highlight.startOffset = match.start
        highlight.endOffset = match.end
        highlight.renderingVersion = currentVersion
    }
}
