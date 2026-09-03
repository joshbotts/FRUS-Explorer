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

    /// One relocation candidate: a canonical UTF-16 span of the flat text whose re-extraction
    /// reproduces the stored passage exactly.
    struct Match: Equatable, Sendable {
        /// UTF-16 offset into `buildFlatText(from:)` — the highlight coordinate space.
        let start: Int
        /// Exclusive end, same space.
        let end: Int
        /// How far this sits from where the highlight is stored, in UTF-16 units.
        let shift: Int
    }

    /// What an exact, unique, seam-aware search found.
    enum Search: Equatable, Sendable {
        /// The highlight stored no passage, so there is nothing to search for. Never searched.
        case noPassage
        /// A passage this app could not have produced, or one too short for "unique" to mean
        /// anything. Refused rather than guessed at.
        case refused(Refusal)
        /// The passage is not in the current text.
        case notFound
        /// Exactly one occurrence, at the offsets the highlight already carries.
        case here(Match)
        /// Exactly one occurrence, at a new position close to the old one.
        case moved(Match)
        /// Exactly one occurrence, but implausibly far from the old one — **reported, never
        /// offered**, because this is what a renumbered document looks like. There is no
        /// second-confirmation path and none is planned: the sheet says what it found and leaves
        /// the judgement to the reader.
        case foundFar(Match)
        /// More than one occurrence. The app must not guess which is the reader's.
        case ambiguous(count: Int)
    }

    /// Why a search was refused before it ran.
    enum Refusal: Equatable, Sendable {
        /// Shorter than `minimumPassageLength`, where "found once" stops being evidence.
        case tooShort
        /// A shape `flatTextExcerpt` never emits — a fragment that is entirely whitespace.
        case malformed
        /// So many candidate positions that the passage cannot be distinctive, or so many ways of
        /// reading its separators that the search stopped rather than answer from a partial walk.
        case tooManyCandidates
    }

    /// Below this many UTF-16 units, "found exactly once" is not evidence of anything.
    ///
    /// Measured over the corpus: 13–15% of ten-character fragments and about 2% of twenty-character
    /// ones occur more than once inside their own document, against 0.3% at forty and effectively
    /// none at eighty. Forty is where the uniqueness claim starts being true.
    static let minimumPassageLength = 40

    /// A unique match further than this from the stored offsets is reported as `foundFar` rather
    /// than `moved`, and is never offered for a one-tap repair.
    ///
    /// Measured over 6,340 relocations on real Office of the Historian in-place corrections, the
    /// median shift was two characters and the largest was ten; not one moved more than 200. A
    /// match thousands of characters away is not a corrected passage. It is the signature of a
    /// **renumbered** document, where this document id now names a different document entirely and
    /// the passage found belongs to someone else's text. Moving a highlight there is precisely the
    /// harm §7 forbids.
    static let plausibleShift = 200

    /// The most candidate start positions the search will examine before refusing.
    static let candidateLimit = 500

    /// The most partial walks carried forward at once. A passage spanning many blocks is fine —
    /// the walk resolves each separator against the text rather than enumerating every reading —
    /// but a pathological one is refused rather than answered from a truncated frontier, because
    /// a truncated frontier reports "not found" about a passage that is present.
    static let frontierLimit = 256

    /// Finds every place the stored passage could sit in the current text.
    ///
    /// ## Why this takes blocks rather than a render model
    /// `flatTextExcerpt(from:start:end:)` rebuilds the block partition on every call, so verifying
    /// many candidates against a model would re-walk the document each time. The caller builds the
    /// partition once. It also makes the whole search a pure function over `[String]`, testable
    /// with no render model, no web view and no main actor.
    ///
    /// ## Why it verifies rather than computes
    /// The obvious approach — split the passage on `"\n\n"`, walk consecutive blocks — is wrong in
    /// both directions, and the corpus proves it. `"\n\n"` inside the passage is NOT always a block
    /// seam: two adjacent `<lb/>` put a literal one inside a single block, which happens 35 times
    /// across 23 of the 552 volumes. And consecutive kept fragments need NOT come from adjacent
    /// blocks, because a whitespace-only slice between them is dropped. So this generates
    /// candidates loosely and then accepts one only if re-extracting at that span reproduces the
    /// passage exactly. The shipped extractor is the oracle; nothing here re-derives its rules.
    ///
    /// ## Why two accepted forms
    /// `selectedText` has two historical shapes. Highlights created before the Authoring Phase 5
    /// fix (2026-07-03) froze a **raw flat-text slice**: no `"\n\n"` seams, whitespace-only slices
    /// retained. Newer ones freeze `flatTextExcerpt`'s output. Both are accepted, or every
    /// cross-block highlight made before that date reports "not found" after relocating perfectly —
    /// the oldest annotations, which are the ones most likely to have survived a correction.
    ///
    /// Nothing here normalises: every comparison is exact string equality. Fuzzy matching is
    /// deliberately out of scope (design §8.2 Q-10), because a fuzzy "found once" can land on words
    /// the reader never selected.
    ///
    /// - Parameters:
    ///   - passage: the highlight's stored `selectedText`.
    ///   - storedStart: the highlight's current start offset, for the distance judgement.
    ///   - storedEnd: its current end offset.
    ///   - blocks: `buildFlatTextBlocks(from:)` for the document as it reads now.
    static func locate(passage: String, storedStart: Int, storedEnd: Int,
                       in blocks: [String]) -> Search {
        guard !passage.isEmpty else { return .noPassage }
        let fragments = passage.components(separatedBy: "\n\n")
        // A shape the extractor never emits: it drops whitespace-only pieces before joining, so a
        // whitespace-only fragment means this string did not come from it.
        if fragments.count > 1,
           fragments.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return .refused(.malformed)
        }
        guard passage.utf16.count >= minimumPassageLength else { return .refused(.tooShort) }

        let flat = blocks.joined()
        let flatUTF16 = Array(flat.utf16)
        guard let head = fragments.first, !head.isEmpty else { return .refused(.malformed) }

        let starts = occurrences(of: Array(head.utf16), in: flatUTF16, limit: candidateLimit + 1)
        if starts.count > candidateLimit { return .refused(.tooManyCandidates) }

        var accepted = Set<[Int]>()
        var truncated = false
        for start in starts {
            for end in candidateEnds(from: start, passage: passage, fragments: fragments,
                                     flat: flatUTF16, truncated: &truncated) {
                guard let span = canonicalSpan(start: start, end: end, passage: passage,
                                               flat: flatUTF16, blocks: blocks) else { continue }
                accepted.insert(span)
            }
        }
        guard let only = accepted.first, accepted.count == 1 else {
            if accepted.isEmpty && truncated { return .refused(.tooManyCandidates) }
            return accepted.isEmpty ? .notFound : .ambiguous(count: accepted.count)
        }
        let match = Match(start: only[0], end: only[1], shift: only[0] - storedStart)
        // Compare against the CANONICAL form of the stored span, not the raw one. A selection that
        // began or ended inside a slice the extractor drops is stored wider than canonical, and
        // comparing raw would announce "at a new position" about a highlight that has not moved —
        // with a shift of zero printed beside it.
        let storedCanonical = canonicalSpan(start: storedStart, end: storedEnd, passage: passage,
                                            flat: flatUTF16, blocks: blocks)
        if only == storedCanonical || (only[0] == storedStart && only[1] == storedEnd) {
            return .here(match)
        }
        return abs(match.shift) <= plausibleShift ? .moved(match) : .foundFar(match)
    }

    // MARK: - The pieces

    /// Every UTF-16 index where `needle` occurs in `haystack`, stopping at `limit`.
    private static func occurrences(of needle: [UInt16], in haystack: [UInt16], limit: Int) -> [Int] {
        guard !needle.isEmpty, needle.count <= haystack.count else { return [] }
        var found: [Int] = []
        let last = haystack.count - needle.count
        var i = 0
        while i <= last {
            if haystack[i] == needle[0] {
                var j = 1
                while j < needle.count && haystack[i + j] == needle[j] { j += 1 }
                if j == needle.count {
                    found.append(i)
                    if found.count >= limit { return found }
                }
            }
            i += 1
        }
        return found
    }

    /// Plausible end offsets for a candidate start, generated loosely — `canonicalSpan` decides.
    ///
    /// Two derivations. The **raw** one assumes the passage is a contiguous slice of the flat text,
    /// which is the pre-July-2026 shape and every single-block passage. The **walk** consumes the
    /// fragments in order, resolving each `"\n\n"` against the text rather than guessing.
    ///
    /// A separator may be a block seam — the extractor inserted it, and the flat text has either
    /// nothing there or the characters of blocks whose covered slice was dropped — or two literal
    /// newlines inside one block, which two adjacent `<lb/>` produce 35 times across the corpus.
    /// **One walk covers both**, because what a seam may hide is whitespace and so are the two
    /// literal newlines: it skips a whitespace run of any length and takes every offset where the
    /// next fragment resumes.
    ///
    /// **It does not enumerate readings.** An earlier version tried all `2^(n-1)` assignments and
    /// therefore had to cap the fragment count — which silently turned a six-paragraph highlight
    /// into "not found" about a passage present character for character. The frontier resolves
    /// each separator where it stands, so the number of blocks a highlight spans is not a limit;
    /// only a pathological branch count is, and that is REFUSED rather than answered.
    private static func candidateEnds(from start: Int, passage: String, fragments: [String],
                                      flat: [UInt16], truncated: inout Bool) -> [Int] {
        var ends: [Int] = [start + passage.utf16.count]
        guard fragments.count > 1, let head = fragments.first else { return ends }
        guard matches(head, at: start, in: flat) else { return ends }
        var frontier = [start + head.utf16.count]
        for index in 1..<fragments.count {
            let fragment = fragments[index]
            var next: [Int] = []
            for position in frontier {
                // A seam: skip only whitespace — the dropped slices — and take every offset where
                // the fragment resumes.
                var skipped = 0
                while skipped <= maximumDroppedRun, position + skipped <= flat.count {
                    if matches(fragment, at: position + skipped, in: flat) {
                        next.append(position + skipped + fragment.utf16.count)
                    }
                    guard position + skipped < flat.count,
                          let scalar = Unicode.Scalar(flat[position + skipped]),
                          CharacterSet.whitespacesAndNewlines.contains(scalar) else { break }
                    skipped += 1
                }
                // A literal `"\n\n"` inside one block needs no branch of its own: the walk above
                // skips whitespace, and two newlines ARE whitespace, so it already reaches the
                // fragment at the same offset. An explicit literal branch was written here first
                // and the mutation sweep proved it unreachable — every mutation disabling it left
                // every test green, because the walk had already found the same end.
            }
            frontier = Array(Set(next)).sorted()
            if frontier.isEmpty { break }
            if frontier.count > frontierLimit {
                truncated = true
                frontier = Array(frontier.prefix(frontierLimit))
            }
        }
        ends.append(contentsOf: frontier)
        return ends
    }

    /// How far the walk will skip over dropped whitespace before giving up.
    private static let maximumDroppedRun = 512

    /// Whether `text` sits at `index` in the flat UTF-16 array.
    private static func matches(_ text: String, at index: Int, in flat: [UInt16]) -> Bool {
        let units = Array(text.utf16)
        guard index >= 0, index + units.count <= flat.count else { return false }
        for (offset, unit) in units.enumerated() where flat[index + offset] != unit { return false }
        return true
    }

    /// Accepts a span only if re-extracting there reproduces the passage, then contracts it to a
    /// canonical form so two spans that extract identically are counted once.
    ///
    /// The contraction is not cosmetic. A span may extend over a leading or trailing whitespace-only
    /// block slice that the extractor drops, so several raw spans yield byte-identical output and a
    /// naive count reports ambiguity where there is one position.
    private static func canonicalSpan(start: Int, end: Int, passage: String,
                                      flat: [UInt16], blocks: [String]) -> [Int]? {
        guard start >= 0, end > start, end <= flat.count else { return nil }
        guard extracts(passage, start: start, end: end, flat: flat, blocks: blocks) else { return nil }
        var s = start, e = end
        while e - 1 > s, extracts(passage, start: s, end: e - 1, flat: flat, blocks: blocks) { e -= 1 }
        while s + 1 < e, extracts(passage, start: s + 1, end: e, flat: flat, blocks: blocks) { s += 1 }
        return [s, e]
    }

    /// Whether the span reproduces the passage in either accepted form.
    private static func extracts(_ passage: String, start: Int, end: Int,
                                 flat: [UInt16], blocks: [String]) -> Bool {
        if flatTextExcerpt(blocks: blocks, start: start, end: end) == passage { return true }
        guard end <= flat.count, end > start else { return false }
        return String(decoding: flat[start..<end], as: UTF16.self) == passage
    }
}

// MARK: - Test seam

extension HighlightReview {
    /// The extractor the search verifies against, exposed so a test asserts on the STRING a span
    /// yields rather than on offsets it computed itself.
    static func flatTextExcerptForTesting(blocks: [String], start: Int, end: Int) -> String? {
        flatTextExcerpt(blocks: blocks, start: start, end: end)
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
