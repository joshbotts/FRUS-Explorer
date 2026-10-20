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

import Foundation
import Testing
// Compiled twice: into the app's test target by Xcode, and against FRUSCoreKit alone by the
// package's FRUSCoreKitTests, where whatever needs the app sits inside `#if !SWIFT_PACKAGE`.
#if SWIFT_PACKAGE
@testable import FRUSCoreKit
#else
@testable import FRUSExplorer
#endif

/// The strip of a document's own heading, source note and dateline (`ProseSnippet`), which keyword
/// rows, Meaning rows and the evaluation harness share (A10b, plan of record decision 74).
///
/// The fixtures marked as stored are the index's own strings at version 69, read from
/// `document_cache` for `Planning/Keyword-Snippet-Assessment-2026-10-20.md`, cut short after the
/// opening.
///
/// Version history:
///   1.0 — A10b: the evaluation harness's five prose-first tests, moved with the strip from
///         `RetrievalEvalHarnessTests`, and the two corrections' own
@Suite("The prose strip")
struct ProseSnippetTests {

    /// The prose the strip leaves: the body from where it says the prose starts.
    private static func prose(_ body: String, header: String, dateline: String? = nil,
                              sourceNote: String? = nil) -> String? {
        let characters = Array(body)
        return ProseSnippet.proseStart(in: characters, header: header, dateline: dateline, sourceNote: sourceNote)
            .map { String(characters[$0...]) }
    }

    // MARK: - The evaluation harness's layouts

    /// Both corpus layouts, verbatim shapes from the first report: the modern order
    /// (header → Source: … → prose) and the wartime telegram order (file citation →
    /// header → dateline → serial → prose).
    @Test("The modern layout strips header and source note, leaving prose")
    func modernLayoutStripsToProse() {
        let snippet = ProseSnippet.prose(
            header: "12. Memorandum of Conversation",
            dateline: "Beijing , February 17–18, 1973, 11:30 p.m.–1:20 a.m.",
            sourceNote: "Source: National Archives, Nixon Presidential Materials, NSC Files, Box 98. Top Secret; Sensitive.",
            body: """
            12. Memorandum of Conversation Source: National Archives, Nixon Presidential \
            Materials, NSC Files, Box 98. Top Secret; Sensitive. Chairman Mao: I have heard \
            that your President said the two countries should walk together.
            """)
        #expect(snippet.hasPrefix("Chairman Mao: I have heard"),
                "the judge should read prose, not the row's own header and citation again")
    }

    @Test("The wartime telegram layout strips citation, header, dateline, received bracket and serial")
    func telegramLayoutStripsChrome() {
        let snippet = ProseSnippet.prose(
            header: "The Secretary of State to the Ambassador in China ( Gauss )",
            dateline: "Washington , December 18, 1943 .",
            sourceNote: "151.10/2003a: Telegram",
            body: """
            151.10/2003a: Telegram The Secretary of State to the Ambassador in China ( Gauss ) \
            Washington , December 18, 1943 . [Received December 19—1:57 p.m.] 1819. On December \
            17, 1943 the President approved an Act of Congress repealing the exclusion laws.
            """)
        #expect(snippet.hasPrefix("On December 17, 1943"),
                "citation-first layouts must strip in any order, not just header-first")
    }

    @Test("A document that is all boilerplate falls back to the plain prefix, never empty")
    func allBoilerplateFallsBack() {
        let snippet = ProseSnippet.prose(
            header: "1. Editorial Note",
            dateline: nil,
            sourceNote: nil,
            body: "1. Editorial Note")
        #expect(!snippet.isEmpty)
        #expect(snippet.contains("Editorial Note"))
        // The strip itself says there is no prose.
        #expect(ProseSnippet.proseStart(in: Array("1. Editorial Note"), header: "1. Editorial Note",
                                        dateline: nil, sourceNote: nil) == nil)
    }

    @Test("Truncation lands on a word boundary with an ellipsis")
    func wordBoundaryTruncation() {
        let long = Array(repeating: "word", count: 200).joined(separator: " ")
        let snippet = ProseSnippet.truncateAtWord(long, limit: 50)
        #expect(snippet.hasSuffix("…"))
        #expect(!snippet.dropLast().hasSuffix("wor"), "no mid-word cuts")
        #expect(snippet.count <= 52)
    }

    @Test("A long bracketed passage is prose, not chrome, and survives")
    func longBracketGroupSurvives() {
        let bracketed = "[" + Array(repeating: "substantive", count: 12).joined(separator: " ") + " text]"
        let snippet = ProseSnippet.prose(
            header: "h", dateline: nil, sourceNote: nil,
            body: "h " + bracketed + " and more follows")
        #expect(snippet.hasPrefix("["),
                "only short [Received …]-style groups are chrome; bracketed prose must remain")
    }

    @Test("A bracket group of sixty characters, its brackets included, is chrome; one of sixty-one is not")
    func bracketGroupLimit() {
        let sixty = "[" + String(repeating: "r", count: 58) + "]"
        let sixtyOne = "[" + String(repeating: "r", count: 59) + "]"
        #expect(sixty.count == 60 && sixtyOne.count == 61)
        #expect(Self.prose("h \(sixty) Prose.", header: "h") == "Prose.")
        #expect(Self.prose("h \(sixtyOne) Prose.", header: "h") == "\(sixtyOne) Prose.")
    }

    // MARK: - The first correction: the fields before the serial rule

    /// Stored: `frus1952-54v07p2` d567, whose heading opens "No. 567". The source note was taken
    /// first, and the serial rule then took "No. 567 ", so the rest of the heading no longer matched
    /// it and stayed (6,923 documents in 26 volumes).
    @Test("A heading that opens \"No. 567\" is stripped whole, and the dateline after the source text's note with it")
    func numberedHeadingIsStrippedWhole() {
        let header = "No. 567 The Director of the Berlin Element, HICOG (Lyon) to the Office of the United "
            + "States High Commissioner for Germany, at Bonn"
        let body = "762B.00/2–953: Telegram " + header + " Repeated to London, Paris, Moscow, and Washington; "
            + "the source text is the copy in Department of State files. secret Berlin, February 9, 1953—5 p.m. "
            + "1269. Re Bonn’s 3463 to Department repeated Berlin 428, London 690, Paris 942, Moscow 190."
        let prose = Self.prose(body, header: header, dateline: "Berlin, February 9, 1953—5 p.m.",
                               sourceNote: "762B.00/2–953: Telegram")
        #expect(prose == "Re Bonn’s 3463 to Department repeated Berlin 428, London 690, Paris 942, Moscow 190.")
        #expect(ProseSnippet.prose(header: header, dateline: "Berlin, February 9, 1953—5 p.m.",
                                   sourceNote: "762B.00/2–953: Telegram", body: body)
                .hasPrefix("Re Bonn’s 3463"), "a Meaning row's snippet opens there too")
    }

    @Test("The fields are tried again before the serial rule at every pass")
    func fieldsBeforeTheSerialRule() {
        // The first correction alone, with no dateline to go on through.
        #expect(Self.prose("762B.00/2–953: Telegram No. 567 The Director to the Office Text of the telegram.",
                           header: "No. 567 The Director to the Office", sourceNote: "762B.00/2–953: Telegram")
                == "Text of the telegram.")
        // A serial that is no field's is still the serial rule's.
        #expect(Self.prose("Mr. Hay to Mr. Jones No. 804.] I have the honor", header: "Mr. Hay to Mr. Jones")
                == "I have the honor")
    }

    // MARK: - The second correction: on through the dateline

    /// Stored: `frus1951v06p2` d94. The classification marking sits before the dateline, and no
    /// stored field carries it.
    @Test("A 1946–60 telegram's classification marking goes with the dateline and serial after it")
    func classificationLineGoesWithTheDateline() {
        let body = "792.00/11–3051: Telegram The Chargé in Thailand (Turner) to the Secretary of State confidential "
            + "Bangkok, November 30, 1951—3 p. m. 1233. Insufficient info yet offer firm analysis Nov 29 coup. "
            + "Fol based solely on preliminary observations."
        let header = "The Chargé in Thailand (Turner) to the Secretary of State"
        let prose = Self.prose(body, header: header, dateline: "Bangkok, November 30, 1951—3 p. m.",
                               sourceNote: "792.00/11–3051: Telegram")
        #expect(prose == "Insufficient info yet offer firm analysis Nov 29 coup. Fol based solely on preliminary observations.")
        #expect(ProseSnippet.prose(header: header, dateline: "Bangkok, November 30, 1951—3 p. m.",
                                   sourceNote: "792.00/11–3051: Telegram", body: body)
                .hasPrefix("Insufficient info yet offer firm analysis"))
        // A distribution note and a bracket group go the same way.
        #expect(Self.prose("H Repeated to Amman, Baghdad and Beirut. top secret niact Cairo, May 1, 1956—4 p.m. "
                           + "[Received May 2—2:10 a.m.] 2001. The Prime Minister said",
                           header: "H", dateline: "Cairo, May 1, 1956—4 p.m.")
                == "The Prime Minister said")
    }

    /// `length` characters of distribution list, as a long one runs before its dateline.
    private static func distributionList(_ length: Int) -> String {
        let words = String(repeating: "Repeated to Amman Baghdad Beirut Damascus Jidda London Paris ", count: 8)
        return String(words.prefix(length - 1)) + " "
    }

    @Test("The dateline is gone on through only where it starts within 200 characters of where the fields stop")
    func datelineWithinReach() {
        let dateline = "Cairo, May 1, 1956—4 p.m."
        let within = Self.distributionList(200)
        let beyond = Self.distributionList(201)
        #expect(within.count == 200 && beyond.count == 201)
        // After "H " the strip stops at 2, so the dateline starts at 202 and 203.
        #expect(Self.prose("H " + within + dateline + " 2001. The Prime Minister said", header: "H", dateline: dateline)
                == "The Prime Minister said")
        #expect(Self.prose("H " + beyond + dateline + " 2001. The Prime Minister said", header: "H", dateline: dateline)
                == beyond + dateline + " 2001. The Prime Minister said",
                "a dateline further on stays, with the text before it (3.5% of documents)")
    }

    @Test("A dateline the fields took is not looked for again, and one with nothing after it is not gone through")
    func datelineTakenOnce() {
        let dateline = "Washington, May 4, 1962"
        // The prose repeats the dateline: it is the document's own text, and stays.
        #expect(Self.prose("H \(dateline) The letter of \(dateline) was answered.", header: "H", dateline: dateline)
                == "The letter of \(dateline) was answered.")
        // Going on through the dateline would leave nothing, so the strip stops where the fields did.
        #expect(Self.prose("H confidential \(dateline)", header: "H", dateline: dateline) == "confidential \(dateline)")
        // And a dateline that is only white space is no dateline.
        #expect(Self.prose("H confidential Text", header: "H", dateline: "   ") == "confidential Text")
    }

    // MARK: - White space, and the serial rule

    @Test("A run of white space in the body matches a field's one space")
    func whiteSpaceRuns() {
        let body = "12. Memorandum of\nConversation  Source: National Archives,\tBox 98. Chairman Mao: I have heard"
        #expect(Self.prose(body, header: "12. Memorandum of Conversation",
                           sourceNote: "Source: National Archives, Box 98.") == "Chairman Mao: I have heard")
        #expect(ProseSnippet.prose(header: "12. Memorandum of Conversation", dateline: nil,
                                   sourceNote: "Source: National Archives, Box 98.", body: body)
                == "Chairman Mao: I have heard")
    }

    /// The serial rule is written out for speed (`ProseSnippet`'s documentation says why); this holds
    /// it to the expression it replaced, at every serial-shaped opening below and each of the texts
    /// that can follow one. ASCII and one Arabic-Indic numeral only, where a character and a code
    /// point are one: the written rule counts characters and the expression code points.
    @Test("The serial rule ends where ^(?:No\\.\\s*\\S{1,8}\\]?|\\d{1,7}\\s*\\.)\\s+ does")
    func serialRuleMatchesTheExpression() {
        let openings = ["No. 567", "No. 804.]", "No.12", "No.  9", "No.\n9", "No. 12345678", "No. 12345678]",
                        "No. 123456789", "No. 123456789]", "No. ]]]]]]]]]", "No. 1234567]]", "No.", "No", "Nos. 5",
                        "no. 5", "No. 5.", "1819.", "1819 .", "1819  .", "271048.", "1234567.", "12345678.",
                        "12.5", "1.", "1", "1819.On", "A1.", "١٢٣.", ".", "", "[No. 5]"]
        let followers = [" Text", "\nText", "  Text", "", " ", "]", ".x", " ", "\t"]
        let expression = #"^(?:No\.\s*\S{1,8}\]?|\d{1,7}\s*\.)\s+"#
        var compared = 0
        var matched = 0
        for opening in openings {
            for follower in followers {
                let text = opening + follower
                let expected = text.range(of: expression, options: .regularExpression)
                    .map { text.distance(from: text.startIndex, to: $0.upperBound) }
                #expect(ProseSnippet.endOfSerial(in: Array(text), at: 0) == expected, "\(text.debugDescription)")
                compared += 1
                if expected != nil { matched += 1 }
            }
        }
        #expect(compared == openings.count * followers.count)
        #expect(matched > 40, "the sweep must reach the rule's matches as well as its refusals: \(matched)")
        // Read from a position inside the text, as the strip reads it.
        #expect(ProseSnippet.endOfSerial(in: Array("ab 1819. On"), at: 3) == 9)
    }
}
