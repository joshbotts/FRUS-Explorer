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
}
