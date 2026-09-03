// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SwiftData
@testable import FRUSExplorer

// MARK: - HighlightReanchorTests

/// The unique-match search behind the re-anchor offer (R-5 P3b-3, design §8.2 Q-10 b).
///
/// Every case is a pure function over a block partition, which is the point of the `[String]`
/// signature: no render model, no web view, no main actor. The cases are drawn from shapes the
/// CORPUS actually contains, measured rather than imagined — a literal `"\n\n"` inside one block
/// (35 occurrences across 23 of 552 volumes, from two adjacent `<lb/>`), a whitespace-only block
/// dropped between two kept ones (51 across 29), and the pre-July-2026 raw-slice passage shape
/// that five of the owner's own eight highlights still carry.
///
/// Version history:
///   1.0 — R-5 P3b-3: initial implementation
@Suite("Highlight re-anchor — the exact, seam-aware search")
struct HighlightReanchorTests {

    /// Long enough to clear the uniqueness floor, so a case tests what it means to test.
    private let long = "The Ambassador called at noon and left a memorandum of the conversation."
    private let other = "A wholly different paragraph of text, long enough to clear the floor here."

    // MARK: - Refusals

    @Test("An empty passage is never searched")
    func emptyPassage() {
        #expect(HighlightReview.locate(passage: "", storedStart: 0, storedEnd: 0,
                                       in: [long]) == .noPassage)
    }

    @Test("A passage below the uniqueness floor is refused, not guessed at")
    func tooShort() {
        let short = String(long.prefix(20))
        #expect(HighlightReview.locate(passage: short, storedStart: 0, storedEnd: 20,
                                       in: [long]) == .refused(.tooShort))
        #expect(long.utf16.count >= HighlightReview.minimumPassageLength)
    }

    /// The extractor drops whitespace-only pieces before joining, so a whitespace-only fragment
    /// means the string did not come from it.
    @Test("A shape the extractor never emits is refused")
    func malformed() {
        let passage = long + "\n\n   \n\n" + other
        #expect(HighlightReview.locate(passage: passage, storedStart: 0, storedEnd: 10,
                                       in: [long, other]) == .refused(.malformed))
    }

    // MARK: - The ordinary cases

    @Test("A single-block passage still at its offsets reports here, not moved")
    func stillHere() {
        let blocks = ["Opening. " + long + " Closing."]
        let start = ("Opening. " as NSString).length
        let result = HighlightReview.locate(passage: long, storedStart: start,
                                            storedEnd: start + long.utf16.count, in: blocks)
        guard case .here(let m) = result else { Issue.record("expected .here, got \(result)"); return }
        #expect(m.start == start && m.shift == 0)
    }

    @Test("A passage that relocated reports moved, with the distance")
    func moved() {
        let blocks = ["Some inserted words. Opening. " + long + " Closing."]
        let result = HighlightReview.locate(passage: long, storedStart: 9, storedEnd: 9 + long.utf16.count,
                                            in: blocks)
        guard case .moved(let m) = result else { Issue.record("expected .moved, got \(result)"); return }
        #expect(m.start == ("Some inserted words. Opening. " as NSString).length)
        #expect(HighlightReview.flatTextExcerptForTesting(blocks: blocks, start: m.start, end: m.end) == long)
    }

    @Test("A passage that is gone reports notFound")
    func notFound() {
        #expect(HighlightReview.locate(passage: long, storedStart: 0, storedEnd: long.utf16.count,
                                       in: [other]) == .notFound)
    }

    @Test("Two occurrences are ambiguous, and the app does not choose")
    func ambiguous() {
        let blocks = [long + " Filler between them. " + long]
        let result = HighlightReview.locate(passage: long, storedStart: 0,
                                            storedEnd: long.utf16.count, in: blocks)
        #expect(result == .ambiguous(count: 2))
    }

    /// A unique match a long way from the stored offsets is what a RENUMBERED document looks like:
    /// the id now names a different document and the passage found belongs to someone else's text.
    /// Measured over real corrections, no genuine relocation moved more than ten characters.
    @Test("A unique match implausibly far away is foundFar, not moved")
    func foundFar() {
        let filler = String(repeating: "x", count: HighlightReview.plausibleShift + 100)
        let blocks = [filler + long]
        let result = HighlightReview.locate(passage: long, storedStart: 0,
                                            storedEnd: long.utf16.count, in: blocks)
        guard case .foundFar(let m) = result else { Issue.record("expected .foundFar, got \(result)"); return }
        #expect(m.shift > HighlightReview.plausibleShift)
    }

    // MARK: - The shapes the corpus actually contains

    /// Two adjacent `<lb/>` put a literal `"\n\n"` INSIDE one block. A matcher that treats every
    /// separator as a block seam cannot find this passage at all.
    @Test("A literal paragraph separator inside one block is found")
    func literalSeparatorInsideOneBlock() {
        let passage = "CHAPMAN COLEMAN,\n\nSecond Secretary of Legation, at the Legation."
        let blocks = ["Preamble text here. " + passage, other]
        let start = ("Preamble text here. " as NSString).length
        let result = HighlightReview.locate(passage: passage, storedStart: start,
                                            storedEnd: start + passage.utf16.count, in: blocks)
        guard case .here(let m) = result else { Issue.record("expected .here, got \(result)"); return }
        #expect(m.start == start)
    }

    /// A genuine seam: the passage spans two blocks and the extractor joined them.
    @Test("A passage spanning a real block seam is found at the span that re-extracts it")
    func acrossASeam() {
        let blocks = ["Ends with this sentence of adequate length here.", "Starts the next block of text."]
        let passage = "with this sentence of adequate length here.\n\nStarts the next block"
        let result = HighlightReview.locate(passage: passage, storedStart: 0, storedEnd: 5, in: blocks)
        guard case .moved(let m) = result else { Issue.record("expected .moved, got \(result)"); return }
        #expect(HighlightReview.flatTextExcerptForTesting(blocks: blocks, start: m.start, end: m.end) == passage)
    }

    /// A whitespace-only block between two kept ones is dropped, so the surviving fragments are
    /// NOT from adjacent blocks and the span covers the dropped block's characters.
    @Test("A dropped whitespace-only block between two kept ones is spanned")
    func droppedInteriorBlock() {
        let blocks = ["First block with enough words to clear the floor.", "\n",
                      "Second block with enough words to clear the floor."]
        let passage = "First block with enough words to clear the floor.\n\nSecond block with enough words to clear the floor."
        let result = HighlightReview.locate(passage: passage, storedStart: 0, storedEnd: 5, in: blocks)
        guard case .moved(let m) = result else { Issue.record("expected .moved, got \(result)"); return }
        #expect(m.start == 0)
        #expect(HighlightReview.flatTextExcerptForTesting(blocks: blocks, start: m.start, end: m.end) == passage)
    }

    /// Highlights created before 2026-07-03 froze a RAW flat-text slice: no seams, whitespace-only
    /// slices retained. Five of the owner's eight are this shape. A matcher that accepts only the
    /// modern form reports "not found" for every one of them that crossed a block and relocated.
    @Test("A pre-July-2026 raw-slice passage across a block boundary is still found")
    func rawSliceShape() {
        let blocks = ["Ends with this sentence of adequate length here.", "Starts the next block of text."]
        // The raw slice fuses the blocks with no separator, which is what the old code froze.
        let passage = "with this sentence of adequate length here.Starts the next block"
        let result = HighlightReview.locate(passage: passage, storedStart: 0, storedEnd: 5, in: blocks)
        guard case .moved(let m) = result else { Issue.record("expected .moved, got \(result)"); return }
        #expect(m.end - m.start == passage.utf16.count, "a raw slice is contiguous in the flat text")
    }

    /// Spans differing only by a leading or trailing whitespace-only block slice extract
    /// identically, so counting raw spans reports ambiguity where there is one position.
    /// The contraction is load-bearing, and the fixture must make it run: a trailing whitespace-only
    /// block means several raw spans extract identically, so counting them raw reports ambiguity
    /// where there is one position. Measured on the first version of this suite, the contraction
    /// loops executed ZERO times across every case — the test named for the behaviour did not
    /// exercise it.
    @Test("Spans that extract identically are counted once, not as ambiguity")
    func canonicalisation() {
        let a = "Block one has plenty of words to clear the floor."
        let b = "Block two also has plenty of words in it here."
        let blocks = [a, "\n", b, "   "]
        let passage = a + "\n\n" + b
        let result = HighlightReview.locate(passage: passage, storedStart: 0, storedEnd: 5, in: blocks)
        guard case .moved(let m) = result else { Issue.record("expected .moved, got \(result)"); return }
        #expect(m.start == 0)
        #expect(m.end == a.utf16.count + 1 + b.utf16.count,
                "contracted to the shortest span that still extracts the passage")
        #expect(HighlightReview.flatTextExcerptForTesting(blocks: blocks, start: m.start, end: m.end) == passage)
    }

    /// A stored span that began or ended inside a slice the extractor drops is WIDER than canonical.
    /// Comparing raw would announce "at a new position" about a highlight that has not moved, with
    /// a shift of zero printed beside it.
    @Test("A stored span wider than canonical still reports here, not moved")
    func storedSpanIsCanonicalisedBeforeComparing() {
        let a = "Block one has plenty of words to clear the floor."
        let blocks = [a, "   "]
        let result = HighlightReview.locate(passage: a, storedStart: 0,
                                            storedEnd: a.utf16.count + 3, in: blocks)
        guard case .here(let m) = result else { Issue.record("expected .here, got \(result)"); return }
        #expect(m.shift == 0)
    }

    // MARK: - The unit nothing in the corpus can catch

    /// No shippable volume contains a non-BMP or combining character, measured across all 552 — so
    /// a UTF-16-versus-Character bug is invisible against real data and needs a synthetic fixture.
    /// The assertion is on the extracted STRING, never on non-nil: the extractor cannot return nil
    /// for an in-bounds range, it returns a slice of the wrong length.
    @Test("Offsets are UTF-16 units, pinned by a synthetic astral fixture")
    func utf16Arithmetic() {
        // The astral pair sits INSIDE the passage on purpose: with it merely before, the passage's
        // own Character and UTF-16 counts are equal and every arithmetic mutation is invisible.
        let astral = "\u{1D400}\u{1D401}"          // two astral letters: 2 characters, 4 UTF-16 units
        let passage = "Passage \(astral) with astral letters inside it, long enough to clear the floor."
        let blocks = ["Lead-in text. " + passage + " Trailing text."]
        #expect(passage.count != passage.utf16.count, "the fixture must distinguish the two units")
        let start = ("Lead-in text. " as NSString).length
        let result = HighlightReview.locate(passage: passage, storedStart: start,
                                            storedEnd: start + passage.utf16.count, in: blocks)
        guard case .here(let m) = result else { Issue.record("expected .here, got \(result)"); return }
        #expect(m.end - m.start == passage.utf16.count, "a Character count would be two short")
        #expect(HighlightReview.flatTextExcerptForTesting(blocks: blocks, start: m.start, end: m.end) == passage)
    }

    // MARK: - The move

    @Test("Move writes the offsets and the version, and leaves the passage alone")
    @MainActor
    func moveWrites() throws {
        let container = try ModelContainer(
            for: DocumentHighlight.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let highlight = DocumentHighlight(volumeId: "v1", documentId: "d1", startOffset: 10,
                                          endOffset: 20, noteId: nil, renderingVersion: "old")
        highlight.selectedText = long
        highlight.colorTag = "green"
        container.mainContext.insert(highlight)
        let before = HighlightSignature.signature(of: [highlight])

        HighlightReview.move(highlight, to: .init(start: 30, end: 45, shift: 20), currentVersion: "new")
        #expect(highlight.startOffset == 30 && highlight.endOffset == 45)
        #expect(highlight.renderingVersion == "new")
        #expect(highlight.selectedText == long, "the reader's words are not rewritten")
        #expect(highlight.colorTag == "green")
        #expect(HighlightReview.status(of: highlight, currentVersion: "new") == .aligned)
        #expect(HighlightSignature.signature(of: [highlight]) != before, "it must repaint")

        // Refusals: no version, or an inverted span.
        HighlightReview.move(highlight, to: .init(start: 1, end: 2, shift: 0), currentVersion: "")
        #expect(highlight.startOffset == 30)
        HighlightReview.move(highlight, to: .init(start: 5, end: 5, shift: 0), currentVersion: "newer")
        #expect(highlight.startOffset == 30)
    }

    /// **The regression that cost the most.** An earlier matcher enumerated every reading of the
    /// separators, so it capped the fragment count at five — and a highlight spanning six blocks
    /// then reported "Not found" about a passage present character for character, next to a Remove
    /// button. Six paragraphs is not exotic: every table cell and list item is its own block.
    @Test("A passage spanning many blocks is found, not reported missing")
    func manyBlocks() {
        for count in [3, 6, 9] {
            let blocks = (0..<count).map { "Paragraph number \($0) of this despatch, long enough to clear the floor." }
            let passage = blocks.joined(separator: "\n\n")
            let result = HighlightReview.locate(passage: passage, storedStart: 0, storedEnd: 5, in: blocks)
            guard case .moved(let m) = result else {
                Issue.record("\(count) blocks: expected .moved, got \(result)"); continue
            }
            #expect(m.start == 0)
            #expect(HighlightReview.flatTextExcerptForTesting(blocks: blocks, start: m.start, end: m.end) == passage)
        }
    }

    /// The distance band must be symmetric. Dropping `abs` would put a one-tap Move on a passage
    /// found thousands of characters EARLIER, which is what a renumbered document looks like.
    @Test("The distance band is symmetric: a large negative shift is foundFar too")
    func negativeShift() {
        let passage = "The Ambassador called at noon and left a memorandum here."
        let far = String(repeating: "y", count: 5_000)
        let blocks = [passage + far]
        // Stored well after the match, so the shift is large and NEGATIVE.
        let result = HighlightReview.locate(passage: passage, storedStart: 5_000,
                                            storedEnd: 5_000 + passage.utf16.count, in: blocks)
        guard case .foundFar(let m) = result else { Issue.record("expected .foundFar, got \(result)"); return }
        #expect(m.shift < 0 && abs(m.shift) > HighlightReview.plausibleShift)

        // And a small negative shift is an ordinary relocation.
        let near = String(repeating: "z", count: 20)
        let nearBlocks = [near + passage]
        let nearResult = HighlightReview.locate(passage: passage, storedStart: 40,
                                                storedEnd: 40 + passage.utf16.count, in: nearBlocks)
        guard case .moved(let n) = nearResult else { Issue.record("expected .moved, got \(nearResult)"); return }
        #expect(n.shift < 0 && abs(n.shift) <= HighlightReview.plausibleShift)
        #expect(HighlightReview.plausibleShift == 200, "the band is a measured constant, not a guess")
    }

    /// The gate that decides which outcomes earn a one-tap repair — the single safety-critical
    /// decision in this feature.
    @Test("Only a nearby unique match earns a Move; foundFar never does")
    func moveOffer() {
        let m = HighlightReview.Match(start: 10, end: 20, shift: 5)
        #expect(DocumentChangeReviewSheet.offeredMove(.moved(m)) == m)
        #expect(DocumentChangeReviewSheet.offeredMove(.foundFar(m)) == nil,
                "a renumbered document must not get a one-tap move")
        #expect(DocumentChangeReviewSheet.offeredMove(.here(m)) == nil)
        #expect(DocumentChangeReviewSheet.offeredMove(.notFound) == nil)
        #expect(DocumentChangeReviewSheet.offeredMove(.ambiguous(count: 2)) == nil)
        #expect(DocumentChangeReviewSheet.offeredMove(.noPassage) == nil)
        #expect(DocumentChangeReviewSheet.offeredMove(.refused(.tooShort)) == nil)
        #expect(DocumentChangeReviewSheet.offeredMove(nil) == nil)
    }

    /// Each outcome says one thing, and the two that must not overclaim are pinned by wording:
    /// "not found" never asserts deletion, because about half of what a real correction changes is
    /// renumbering; and the far case names that possibility explicitly.
    @Test("Every outcome has its own sentence, and none claims more than a search can show")
    @MainActor
    func searchLines() throws {
        let m = HighlightReview.Match(start: 1, end: 2, shift: 1)
        let here = try #require(DocumentChangeReviewSheet.searchLine(.here(m)))
        let moved = try #require(DocumentChangeReviewSheet.searchLine(.moved(m)))
        let far = try #require(DocumentChangeReviewSheet.searchLine(.foundFar(m)))
        let none = try #require(DocumentChangeReviewSheet.searchLine(.notFound))
        let many = try #require(DocumentChangeReviewSheet.searchLine(.ambiguous(count: 3)))
        let short = try #require(DocumentChangeReviewSheet.searchLine(.refused(.tooShort)))
        #expect(Set([here, moved, far, none, many, short]).count == 6, "one sentence each")
        #expect(here.contains("still in this position"))
        #expect(moved.contains("new position"))
        #expect(far.contains("renumbered"))
        #expect(none.contains("renumbered"), "never assert the editors deleted it")
        #expect(!none.contains("deleted"))
        #expect(many.contains("3"))
        #expect(DocumentChangeReviewSheet.searchLine(.noPassage) == nil)
        #expect(DocumentChangeReviewSheet.searchLine(.refused(.malformed)) == nil)
    }

    /// The LEADING contraction: a span that starts inside a droppable slice extracts identically to
    /// one that starts after it, so without contracting the start the two count as ambiguity.
    @Test("A span starting inside a dropped slice contracts at the front too")
    func leadingContraction() {
        let a = "Block one has plenty of words to clear the floor here."
        let blocks = ["   ", a, "   "]
        // The STORED span begins inside the leading whitespace-only block — a selection dragged
        // from just above the paragraph. Only contracting the start of the stored span makes this
        // read as "still here" rather than "moved" with a shift printed beside it.
        let result = HighlightReview.locate(passage: a, storedStart: 0, storedEnd: 3 + a.utf16.count,
                                            in: blocks)
        guard case .here(let m) = result else { Issue.record("expected .here, got \(result)"); return }
        #expect(m.start == 3, "contracted past the leading whitespace-only block")
        #expect(m.end == 3 + a.utf16.count)
    }

    /// One walk covers both readings of a separator. This passage mixes a LITERAL `"\n\n"` (two
    /// adjacent `<lb/>` inside block 0) with a real block seam, and the raw contiguous form cannot
    /// match it, so only the walk can — via its whitespace skip, which is why no separate literal
    /// branch is needed.
    @Test("A passage mixing a literal separator with a real seam is found")
    func literalAndSeamTogether() {
        // Block 0 contains a literal "\n\n" from two adjacent <lb/>; block 1 is a separate block.
        let first = "CHAPMAN COLEMAN,\n\nSecond Secretary of Legation at the Legation."
        let second = "The next block of the despatch, long enough to matter."
        let blocks = [first, second]
        let passage = first + "\n\n" + second        // one literal, one seam
        let result = HighlightReview.locate(passage: passage, storedStart: 0, storedEnd: 5, in: blocks)
        guard case .moved(let m) = result else { Issue.record("expected .moved, got \(result)"); return }
        #expect(m.start == 0)
        #expect(m.end == first.utf16.count + second.utf16.count, "no separator exists in the flat text")
        #expect(HighlightReview.flatTextExcerptForTesting(blocks: blocks, start: m.start, end: m.end) == passage)
    }
}
