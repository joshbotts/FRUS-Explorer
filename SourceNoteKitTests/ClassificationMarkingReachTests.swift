// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
@testable import SourceNoteKit

// MARK: - ClassificationMarkingReachTests

/// Pins how far `SourceNoteParser.classificationMarking(fromSourceNote:)` reads into a source note
/// (#1856, index version 73), against `secondSentenceClassificationMarking(fromSourceNote:)`, the
/// reading as it was.
///
/// The sentence split has no abbreviation model, so the marking a note prints is not always its
/// sentence 2. Measured over the 553 manifest volumes at corpus `6170e4b32`, 8,865 notes from 218
/// volumes printed a marking that sentence 2 alone missed, for three reasons, one fixture each
/// below, every note verbatim from the index: a stop inside the citation, a citation ending on a
/// volume number, and a remark opening with a digit joined to the marking's sentence. The gates
/// are unchanged, so the refusals below hold for a later sentence as they did for sentence 2.
///
/// The two functions must stay two: the Archives Visit packet cuts a central-file designation at
/// its first boundary when the next sentence is a marking, and a marking found past a stop inside
/// the citation would cut the designation at that stop (`TripPacketBuilderTests`).
///
/// Version history:
///   1.0 — 2026-11-06: #1856
@Suite("SourceNoteParser — how far the classification reading reaches")
struct ClassificationMarkingReachTests {

    /// A note, verbatim from the index, and the marking it prints.
    struct Example: Sendable, CustomTestStringConvertible {
        /// The volume and document the note belongs to, as the issue names them.
        let document: String
        /// The stored source note (`document_cache.source_note`), verbatim.
        let note: String
        /// The marking the note prints, as the reading writes it.
        let marking: String
        /// The document, which names each case in the test report.
        var testDescription: String { document }
    }

    /// The issue's examples, one or more per cause; none reads through sentence 2 alone.
    static let examples: [Example] = [
        // A stop inside the citation: "U.S." splits it, and sentence 2 is "Policy Towards (NSC 5504)."
        Example(
            document: "frus1955-57v12 d365",
            note: "Source: Department of State, S/P – NSC Files: Lot 61 D 167, Iran, U.S. Policy Towards "
                + "(NSC 5504). Top Secret. Drafted by Hannah. Rountree was appointed Assistant Secretary of "
                + "State on July 26 and entered duty on August 30.",
            marking: "Top Secret"),
        // The citation ends on a volume number: sentence 2 is "I."
        Example(
            document: "frus1969-76v17 d1",
            note: "Source: National Archives, Nixon Presidential Materials, NSC Files, Box 518, Country "
                + "Files, Far East, China, Vol. I. Secret. Sent for action.",
            marking: "Secret"),
        // A remark opening with a digit joins sentence 2, and the gate refuses a digit.
        Example(
            document: "frus1969-76v17 d107",
            note: "Source: National Security Council, Nixon Intelligence Files, Subject Files, China. "
                + "Secret; Sensitive; Eyes Only. 1 page of source text not declassified.",
            marking: "Secret; Sensitive; Eyes Only"),
        // The microfiche supplements' abstracts: "Secret. 2 pp." is one sentence to the split.
        Example(
            document: "frus1958-60v03mSupp d507",
            note: "Source: Planning Board meeting with Coolidge. Secret. 2 pp. Eisenhower Library, White "
                + "House Office Files, Project Clean Up, Disarmament, General.",
            marking: "Secret"),
        // Both at once: an initial moves the marking to sentence 3, and a digit-led remark joins it.
        Example(
            document: "frus1961-63v12 d275",
            note: "Source: Kennedy Library, Papers of Arthur M. Schlesinger, Jr., British Guiana. Secret. "
                + "2 pages of source text not declassified.",
            marking: "Secret"),
    ]

    /// Each of the issue's notes reads its marking now, and read none through sentence 2 alone.
    @Test("A marking past sentence 2 is read, through the unchanged gates", arguments: examples)
    func readsTheMarkingTheNotePrints(_ example: Example) {
        #expect(SourceNoteParser.classificationMarking(fromSourceNote: example.note) == example.marking)
        // The reading as it was missed each one: that is the defect, not a new rule's choice.
        #expect(SourceNoteParser.secondSentenceClassificationMarking(fromSourceNote: example.note) == nil)
    }

    /// Sentence 2 is offered first, so a marking read before reads the same.
    @Test("A note whose sentence 2 is its marking reads the same through either function")
    func sentenceTwoReadsAsItDid() {
        let notes: [(note: String, marking: String)] = [
            ("Source: Department of State, Central Files, 396.1 GE/7–854. Secret; Nodis.", "Secret; Nodis"),
            ("Source: Johnson Library, National Security File, Country File, Vietnam, Memos and "
                + "Miscellaneous. No classification marking.", "No classification marking"),
            // Sentence 2 comes first even when a later sentence also passes the gates.
            ("Source: Department of State, Central Files, 751G.00/3–155. Confidential. Drafted by Young. "
                + "Top Secret.", "Confidential"),
        ]
        for (note, marking) in notes {
            #expect(SourceNoteParser.classificationMarking(fromSourceNote: note) == marking)
            #expect(SourceNoteParser.secondSentenceClassificationMarking(fromSourceNote: note) == marking)
        }
    }

    /// Past a citation broken by stops, the earliest sentence that passes is the marking.
    @Test("The first sentence that passes is the marking, not a later one")
    func firstPassingSentenceWins() {
        let note = "Source: Johnson Library, National Security File, Vietnam Country File, Vol. XII, Memos. "
            + "Confidential. Top Secret."
        #expect(SourceNoteParser.classificationMarking(fromSourceNote: note) == "Confidential")
    }

    /// Every gate still refuses, now for any sentence after the first. Each note puts the candidate
    /// past sentence 2, behind "Vol. I." as `frus1969-76v17` d1 does, so a refusal here is the
    /// gate's and not the old reading's reach.
    @Test("Each gate refuses a later sentence as it refused sentence 2")
    func gatesRefuseLaterSentences() {
        let head = "Source: National Archives, Nixon Presidential Materials, NSC Files, Box 518, Country "
            + "Files, Far East, China, Vol. I. "
        let refused: [(why: String, tail: String)] = [
            ("no level first", "Sent for action."),
            // Each case from here to the stop inside a fragment fails one gate and passes the rest.
            ("a digit with no stop before it", "Top Secret; Section 2 Only."),
            ("a lower-case fragment", "Secret; eyes only."),
            ("a remark verb", "Confidential; Priority; Drafted by Seward (FE/CA/RA)."),
            ("a fragment of five words", "Secret; Eyes Only for the Ambassador."),
            // 121 characters, every fragment short and capitalised: the length gate alone refuses it.
            ("over 100 characters", "Secret" + String(repeating: "; Exclusively Eyes Only", count: 5) + "."),
            ("a stop inside a fragment", "Top Secret; SUEDE; Dissemination to U.S. Government agencies only."),
            ("no marking at all", "The source text is not dated."),
        ]
        for (why, tail) in refused {
            #expect(SourceNoteParser.classificationMarking(fromSourceNote: head + tail) == nil, "\(why)")
        }
    }

    /// The cut before a digit-led remark only removes the remark; it makes nothing a marking.
    @Test("A digit-led remark is cut off only after a stop; its head must still pass the gates")
    func digitLedCutNeedsAMarkingHead() {
        // The head before "1 page" is a remark, so nothing is read.
        #expect(SourceNoteParser.classificationMarking(fromSourceNote:
            "Source: National Security Council, Nixon Intelligence Files, Subject Files, China. Drafted by "
            + "Holdridge. 1 page of source text not declassified.") == nil)
        // A digit with no stop before it is part of the sentence, which the no-digit gate refuses.
        #expect(SourceNoteParser.classificationMarking(fromSourceNote:
            "Source: Planning Board meeting with Coolidge. Secret 2 pp.") == nil)
    }

    /// The reading starts after sentence 1, as it always did, and an empty note reads nothing.
    @Test("Sentence 1, the citation, is never read as a marking")
    func citationIsNeverTheMarking() {
        #expect(SourceNoteParser.classificationMarking(fromSourceNote: "Secret.") == nil)
        #expect(SourceNoteParser.classificationMarking(fromSourceNote: "Secret. Drafted by Hannah.") == nil)
        #expect(SourceNoteParser.classificationMarking(fromSourceNote: "Source: Department of State, Central "
            + "Files, 761.00/1-2069.") == nil)
        #expect(SourceNoteParser.classificationMarking(fromSourceNote: "") == nil)
        #expect(SourceNoteParser.classificationMarking(fromSourceNote: "   ") == nil)
        #expect(SourceNoteParser.secondSentenceClassificationMarking(fromSourceNote: "") == nil)
    }
}
