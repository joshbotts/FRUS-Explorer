// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
@testable import SourceNoteKit

// MARK: - FirstSentenceTests

/// Pins `SourceNoteParser.firstSentence(of:)` against `citationSentence(of:)`.
///
/// The two look interchangeable and are not. `citationSentence` returns the first sentence
/// **naming the central files**, falling back to sentence 1 — right for the decimal-class scan
/// and for the collection-authority keying it bounds. `firstSentence` returns sentence 1
/// unconditionally, which is what the frus-sources sentence model calls the archival citation.
///
/// The difference only shows on a note whose *remarks* mention a central file, and that shape is
/// everywhere in the Nixon volumes: measured, 4,605 documents were having their sub-collection
/// read out of an editor's cross-reference instead of out of the citation.
///
/// These must stay separate functions. `citationSentence` is what keys
/// `collection-authority.json`, so "fixing" it into `firstSentence` would invalidate every
/// stored key in a shipped artifact.
///
/// Version history:
///   1.0 — Session 2026-08-06: #355 / N-4, Nixon
@Suite("SourceNoteParser — first sentence vs citation sentence")
struct FirstSentenceTests {

    /// The verbatim corpus shape that exposed the difference.
    private let remarksNameACentralFile =
        "Source: National Archives, Nixon Presidential Materials, NSC Files, Agency Files, "
        + "Box 193, AID, Volume I 1969. Confidential. On May 23 Haig sent Kissinger a memorandum "
        + "in which this was the first item for Kissinger to discuss with the President that day. "
        + "(Ibid., Subject Files, Items to Discuss with the President) Kissinger met with the "
        + "President at 9:30 a.m. (Ibid., White House Central Files, President\u{2019}s Daily Diary)"

    @Test("First sentence is the citation, even when the remarks name a central file")
    func firstSentenceIsTheCitation() {
        let first = SourceNoteParser.firstSentence(of: remarksNameACentralFile)
        #expect(first.hasPrefix("Source: National Archives, Nixon Presidential Materials"))
        #expect(first.contains("Agency Files"))
        #expect(!first.contains("Haig sent Kissinger"), "the remarks are not the citation")
    }

    /// The contrast that motivates keeping both. This is not a defect in `citationSentence` —
    /// it is doing exactly what the class scan needs — so the fixture is a guard against
    /// someone "unifying" the two.
    @Test("Citation sentence still anchors on the central files, and so lands on the remarks")
    func citationSentenceStillAnchors() {
        let anchored = SourceNoteParser.citationSentence(of: remarksNameACentralFile)
        #expect(anchored != SourceNoteParser.firstSentence(of: remarksNameACentralFile),
                "if these ever agree here, one of them has changed behaviour")
        #expect(anchored.contains("Central Files"))
    }

    /// With no central file anywhere, both return sentence 1 and agree.
    @Test("The two agree when nothing anchors")
    func theyAgreeWithoutAnAnchor() {
        let note = "Source: Ford Library, National Security Adviser, Presidential Agency File, "
            + "Box 5, Central Intelligence Agency. Secret. Drafted by Colby."
        #expect(SourceNoteParser.firstSentence(of: note)
                == SourceNoteParser.citationSentence(of: note))
    }

    /// A single-sentence note is its own first sentence.
    @Test("A note with one sentence is returned whole")
    func singleSentence() {
        let note = "Source: Carter Library, Plains File, Box 17"
        #expect(SourceNoteParser.firstSentence(of: note) == note)
        #expect(SourceNoteParser.firstSentence(of: "") == "")
    }
}
