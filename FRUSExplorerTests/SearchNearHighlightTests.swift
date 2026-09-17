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

import Testing
import Foundation
@testable import FRUSExplorer

/// `NEAR`'s effect on the snippet highlighter (Q-1).
///
/// ## Why this is its own suite
/// `positiveTerms` deliberately does not run `FTS5InlineQueryParser` — it is a surface
/// cleanup that strips the inline syntax it recognises. `NEAR` adds syntax it did not
/// recognise, and the failure is silent and cosmetic in exactly the way nothing else
/// catches: the search returns the right documents while the snippet bolds the literal
/// text `NEAR("military` and the distance `30`. No parser test can see it, because the
/// parser is not involved.
///
/// Version history:
///   1.0 — Q-1: initial implementation
///   1.1 — #1298: typographic double quotation marks (`“ ”`, `„ “`, `« »`, fullwidth) hide a paren and a comma from
///          the scaffolding rewrite as U+0022 does, and a typographic phrase highlights and concords the words its
///          straight spelling does; a double prime and the single marks stay ordinary characters
///   1.2 — #1298 follow-up: the typographic concordance test takes its anchor oracle only from queries that negate
///          nothing. For `blockade -"naval quarantine"` it asserts only that the two spellings concord alike, because
///          the straight spelling's anchor on `quarantine` — a word of the excluded phrase — is a highlighter quirk the
///          1.1 test had pinned as correct
@Suite("NEAR and the snippet highlighter")
struct SearchNearHighlightTests {

    // MARK: - The scaffolding rewrite

    @Test("The keyword, its parentheses and the distance are all removed")
    func scaffoldingIsRemoved() {
        let out = SearchService.strippingNearScaffolding("NEAR(\"military guarantee\" europe, 30)")
        #expect(!out.lowercased().contains("near"))
        #expect(!out.contains("("))
        #expect(!out.contains(")"))
        #expect(!out.contains("30"))
        #expect(out.contains("\"military guarantee\""))
        #expect(out.contains("europe"))
    }

    @Test("Operands survive so the existing quote handling can still bold the phrase")
    func operandsSurviveForTheExistingLoop() {
        // The phrase must arrive at the caller still quoted: the loop downstream strips a
        // leading quote from one token and a trailing quote from another, which is how a
        // bare phrase already highlights. Removing the quotes here would break that.
        let out = SearchService.strippingNearScaffolding("NEAR(\"cold war\" detente, 5)")
        #expect(out.contains("\"cold war\""))
        #expect(out.contains("detente"))
    }

    @Test("The NEAR/N alias spelling is stripped too")
    func aliasSpellingIsStripped() {
        let out = SearchService.strippingNearScaffolding("NEAR/5(military europe)")
        #expect(!out.lowercased().contains("near"))
        #expect(!out.contains("5"))
        #expect(out.contains("military"))
        #expect(out.contains("europe"))
    }

    @Test("Lowercase and spaced spellings are stripped")
    func caseAndSpacingVariants() {
        for raw in ["near(military europe, 5)",
                    "Near (military europe, 5)",
                    "NEAR  (military europe, 5)"] {
            let out = SearchService.strippingNearScaffolding(raw)
            #expect(!out.lowercased().contains("near"), "not stripped: \(raw) → \(out)")
            #expect(out.contains("military") && out.contains("europe"))
        }
    }

    // MARK: - What must NOT be stripped

    @Test("A year in operand position is a real search term and survives")
    func operandDigitsSurvive() {
        // Only the distance position is a distance. `1948` typed as a word is content.
        let out = SearchService.strippingNearScaffolding("NEAR(guarantee 1948, 30)")
        #expect(out.contains("1948"), "an operand year must not be mistaken for the distance")
        #expect(!out.contains("30"))
    }

    @Test("A query with no NEAR is returned completely untouched")
    func nonNearQueriesAreUntouched() {
        for raw in ["cold war",
                    "\"cold war\" OR detente -korea negoti*",
                    "(aqaba OR tiran) AND navig*"] {
            #expect(SearchService.strippingNearScaffolding(raw) == raw)
        }
    }

    /// The cheap bail-out keys on the substring "near", so a word merely containing it
    /// enters the rewrite path. It must come out the other side unchanged.
    @Test("A word that merely contains 'near' is not treated as the operator")
    func nearAsASubstringIsNotTheOperator() {
        for raw in ["nearest neighbour", "linear programming", "near east"] {
            #expect(SearchService.strippingNearScaffolding(raw) == raw,
                    "false positive on: \(raw)")
        }
    }

    @Test("A comma inside a phrase is not read as the distance separator")
    func commaInsideAPhraseSurvives() {
        let out = SearchService.strippingNearScaffolding("NEAR(\"cold, war\" europe)")
        #expect(out.contains("\"cold, war\""), "the phrase lost its comma: \(out)")
        #expect(out.contains("europe"))
    }

    @Test("An unbalanced NEAR emits the remainder rather than guessing")
    func unbalancedNearDegrades() {
        // Guessing a close paren here would silently drop the tail of the user's query
        // from the highlight set.
        let out = SearchService.strippingNearScaffolding("NEAR(military europe")
        #expect(out.contains("military") && out.contains("europe"))
    }

    @Test("Two NEARs in one query are both stripped")
    func multipleNearsAreStripped() {
        let out = SearchService.strippingNearScaffolding(
            "NEAR(military europe, 5) AND NEAR(aid treaty, 8)")
        #expect(!out.lowercased().contains("near"))
        #expect(!out.contains("5") && !out.contains("8"))
        for word in ["military", "europe", "aid", "treaty"] {
            #expect(out.contains(word), "lost operand \(word) → \(out)")
        }
    }

    @Test("Text outside the NEAR is preserved on both sides")
    func surroundingTextSurvives() {
        let out = SearchService.strippingNearScaffolding("treaty NEAR(military europe, 5) berlin")
        #expect(out.contains("treaty"))
        #expect(out.contains("berlin"))
        #expect(!out.lowercased().contains("near"))
    }

    // MARK: - The comma scanner

    @Test("lastUnquotedComma ignores commas inside phrases")
    func lastUnquotedCommaIgnoresQuoted() {
        #expect(SearchService.lastUnquotedComma(in: "\"cold, war\" europe") == nil)
        let text = "\"cold, war\" europe, 30"
        let found = SearchService.lastUnquotedComma(in: text)
        #expect(found != nil)
        if let found {
            #expect(text[text.index(after: found)...].trimmingCharacters(in: .whitespaces) == "30")
        }
    }

    // MARK: - Typographic quotation marks (#1298)

    /// Opening and closing marks as a keyboard or a paste delivers them: English, German twice, French, the reversed
    /// high mark, fullwidth, and both mixed spellings with U+0022.
    private static let typographicPairs: [(open: String, close: String)] = [
        ("\u{201C}", "\u{201D}"), ("\u{201E}", "\u{201C}"), ("\u{201E}", "\u{201D}"), ("\u{00AB}", "\u{00BB}"),
        ("\u{201F}", "\u{201D}"), ("\u{FF02}", "\u{FF02}"), ("\u{201C}", "\""), ("\"", "\u{201D}"),
    ]

    @Test("A paren inside typographic quotation marks does not close the NEAR span")
    func typographicQuotesHideAParen() {
        // The straight spelling, as a control: the `)` inside the phrase is text, so the span runs to the real close
        // and its distance is dropped.
        let straight = SearchService.strippingNearScaffolding("NEAR(\"cold )\" europe, 5)")
        #expect(!straight.contains("5") && straight.contains("europe"))
        for pair in Self.typographicPairs {
            let phrase = "\(pair.open)cold )\(pair.close)"
            let out = SearchService.strippingNearScaffolding("NEAR(\(phrase) europe, 5)")
            #expect(!out.lowercased().contains("near"), "\(phrase) → \(out)")
            #expect(!out.contains("5"), "the paren inside \(phrase) closed the span early → \(out)")
            #expect(out.contains(phrase) && out.contains("europe"), "\(phrase) → \(out)")
        }
    }

    @Test("A double prime inside NEAR is a unit mark, so the distance is still dropped")
    func doublePrimeInsideNearIsNotAQuote() {
        // Read as a quotation mark, `″` would open a phrase running past the close paren, and the whole span would be
        // emitted untouched — keyword, distance and all.
        let out = SearchService.strippingNearScaffolding("NEAR(12\u{2033} guns, 5)")
        #expect(!out.lowercased().contains("near"), "\(out)")
        #expect(!out.contains("5"), "\(out)")
        #expect(out.contains("guns"))
    }

    @Test("lastUnquotedComma reads typographic quotation marks as quotes, and a double prime or single mark as text")
    func lastUnquotedCommaTypographic() {
        for pair in Self.typographicPairs {
            #expect(SearchService.lastUnquotedComma(in: "\(pair.open)cold, war\(pair.close) europe") == nil,
                    "\(pair.open)cold, war\(pair.close)")
            let text = "\(pair.open)cold, war\(pair.close) europe, 30"
            let found = SearchService.lastUnquotedComma(in: text)
            #expect(found.map { text[text.index(after: $0)...].trimmingCharacters(in: .whitespaces) } == "30")
        }
        for text in ["12\u{2033} guns, 5", "\u{2018}cold, war\u{2019} 5", "\u{2039}cold, war\u{203A} 5"] {
            #expect(SearchService.lastUnquotedComma(in: text) != nil, "\(text)")
        }
    }

    /// An index holding the phrases the typographic cases search for, and a service over it.
    private func makeService() async throws -> (dir: URL, service: SearchService) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSQuoteHighlight-\(UUID().uuidString)", isDirectory: true)
        let volumes = dir.appendingPathComponent("volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        let xml = """
        <?xml version="1.0"?>
        <TEI><text><body>
        <div type="document" xml:id="d1">
          <head>1. Memorandum</head>
          <p>The cold war began in earnest, and war and peace were debated at length.</p>
        </div>
        <div type="document" xml:id="d2">
          <head>2. Telegram</head>
          <p>The blockade and quarantine held while a naval patrol followed.</p>
        </div>
        <div type="document" xml:id="d3">
          <head>3. Report</head>
          <p>The military guarantee finally extended to europe was debated.</p>
        </div>
        </body></text></TEI>
        """
        try Data(xml.utf8).write(to: volumes.appendingPathComponent("vol1.xml"))
        let databaseURL = dir.appendingPathComponent("test.sqlite")
        let fts5 = try FTS5Store(databaseURL: databaseURL)
        let pipeline = try IndexingPipeline(
            fts5Store: fts5, databaseURL: databaseURL, volumesDirectory: volumes, concurrencyLimit: 1)
        try await pipeline.indexVolume("vol1")
        return (dir, SearchService(fts5Store: fts5, pipeline: pipeline))
    }

    /// `positiveTerms` is private, so its answer is read where it lands: the bolded snippet and the concordance lines.
    @Test("A typographic phrase highlights and concords the words its straight spelling does")
    func typographicPhraseAnchorsLikeStraight() async throws {
        let (dir, service) = try await makeService()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Each straight query, a typographic respelling, and — where the query negates nothing — the words the straight
        // query's concordance anchors on, as an oracle that the straight spelling itself is concorded.
        //
        // `war and peace` anchors on `war` and `peace` and not `and`: `positiveTerms` splits the text on whitespace
        // before it looks at quotes, so the phrase's middle word reaches the operator check as a bare `and` and is
        // skipped like the operator. That is the straight spelling's existing answer, recorded here rather than
        // endorsed; what #1298 pins is only that the typographic spelling gives the same one.
        //
        // The negated case carries NO anchor set. The straight `blockade -"naval quarantine"` anchors on `quarantine`,
        // a word of the excluded phrase, because the same split skips only the dashed first token `-"naval` — a
        // highlighter quirk against `positiveTerms`' own "excluded terms are not included" that has nothing to do with
        // quotation marks, so pinning it here would fail this test when the quirk is fixed. For that case only the
        // equality of the two spellings' lines is asserted, over a straight concordance that is not empty.
        let cases: [(straight: String, typographic: String, anchors: Set<String>?)] = [
            ("\"cold war\"", "\u{201C}cold war\u{201D}", ["cold", "war"]),
            ("\"war and peace\"", "\u{00AB}war and peace\u{00BB}", ["war", "peace"]),
            ("blockade -\"naval quarantine\"", "blockade -\u{201E}naval quarantine\u{201C}", nil),
            ("NEAR(\"military guarantee\" europe, 5)", "NEAR(\u{FF02}military guarantee\u{FF02} europe, 5)",
             ["military", "guarantee", "europe"]),
        ]
        var concorded = 0
        for c in cases {
            let straightParameters = SearchParameters(keywords: c.straight)
            let typographicParameters = SearchParameters(keywords: c.typographic)
            let straightResults = try await service.search(parameters: straightParameters)
            let typographicResults = try await service.search(parameters: typographicParameters)
            #expect(straightResults.count == 1, "\(c.straight)")
            #expect(straightResults.allSatisfy { $0.snippet.contains("<b>") }, "\(c.straight) bolds nothing")
            #expect(typographicResults.map(\.documentId) == straightResults.map(\.documentId), "\(c.typographic)")
            #expect(typographicResults.map(\.snippet) == straightResults.map(\.snippet), "\(c.typographic)")

            let straightLines = try await service.concordance(for: straightResults, parameters: straightParameters)
            let typographicLines = try await service.concordance(for: straightResults, parameters: typographicParameters)
            if let anchors = c.anchors {
                #expect(Set(straightLines.lines.map { $0.match.lowercased() }) == anchors, "\(c.straight)")
            } else {
                #expect(!straightLines.lines.isEmpty, "\(c.straight): an empty concordance would make the equality vacuous")
            }
            #expect(typographicLines.lines == straightLines.lines, "\(c.typographic)")
            concorded += straightLines.lines.count
        }
        #expect(concorded > 0)
    }
}
