// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
@testable import FTS5Store

// MARK: - FTS5InlineQueryParserTests

/// Unit tests for `FTS5InlineQueryParser` — verifies that Google-style inline query
/// syntax typed into the main search box is translated into correct, valid, stemmed
/// FTS5 MATCH expressions (and that it never produces syntactically invalid output,
/// regardless of how malformed the input is).
struct FTS5InlineQueryParserTests {

    // MARK: - Plain Keywords (back-compat with the old whitespace-split path)

    @Test("Plain keywords render as implicit AND of stemmed words — matches old behaviour")
    func plainKeywords() {
        #expect(FTS5InlineQueryParser.parse("cold war") == "cold war")
    }

    @Test("Single keyword stems correctly")
    func singleKeyword() {
        #expect(FTS5InlineQueryParser.parse("negotiations") == "negoti")
    }

    @Test("Empty or whitespace-only input returns nil")
    func emptyInput() {
        #expect(FTS5InlineQueryParser.parse("") == nil)
        #expect(FTS5InlineQueryParser.parse("   ") == nil)
    }

    // MARK: - Quoted Phrases

    @Test("Quoted phrase renders as a stemmed FTS5 phrase")
    func quotedPhrase() {
        #expect(FTS5InlineQueryParser.parse("\"cold war\"") == "\"cold war\"")
    }

    @Test("Quoted phrase combines with bare words via implicit AND")
    func phraseWithKeyword() {
        #expect(FTS5InlineQueryParser.parse("\"cold war\" negotiations") == "\"cold war\" negoti")
    }

    @Test("Unterminated quote is treated as a phrase running to end of input")
    func unterminatedQuote() {
        #expect(FTS5InlineQueryParser.parse("\"cold war") == "\"cold war\"")
    }

    @Test("Empty quotes produce no operand")
    func emptyQuotes() {
        #expect(FTS5InlineQueryParser.parse("\"\"") == nil)
        #expect(FTS5InlineQueryParser.parse("\"\" cold") == "cold")
    }

    // MARK: - OR

    @Test("Uppercase OR between two terms renders as FTS5 OR")
    func orOperator() {
        #expect(FTS5InlineQueryParser.parse("Rusk OR Bundy") == "rusk OR bundi")
    }

    @Test("OR combines with phrases on either side")
    func orWithPhrase() {
        #expect(FTS5InlineQueryParser.parse("\"cold war\" OR detente") == "\"cold war\" OR detent")
    }

    @Test("Lowercase 'or' is treated as a literal search word, not an operator")
    func lowercaseOrIsLiteral() {
        // Both "cold" and "or" and "war" are ANDed together as literal stemmed words —
        // matching Google's and FTS5's own convention that only uppercase OR is an operator.
        #expect(FTS5InlineQueryParser.parse("cold or war") == "cold or war")
    }

    @Test("Leading OR with no left operand is searched for as the literal word 'or'")
    func leadingOrIsLiteral() {
        #expect(FTS5InlineQueryParser.parse("OR cold") == "or cold")
    }

    @Test("Trailing OR with no right operand is searched for as the literal word 'or'")
    func trailingOrIsLiteral() {
        #expect(FTS5InlineQueryParser.parse("cold OR") == "cold or")
    }

    @Test("Doubled OR collapses to a single operator with the stray treated as a literal")
    func doubledOr() {
        // First OR: left="cold" (operand), right=second OR (not yet an operand) → demoted to "or".
        // Second OR: left=demoted "or" (now an operand), right="war" (operand) → stays operator.
        #expect(FTS5InlineQueryParser.parse("cold OR OR war") == "cold or OR war")
    }

    // MARK: - Exclusion (leading "-" and NOT)

    @Test("Leading hyphen excludes a term via NOT")
    func leadingHyphenExcludes() {
        #expect(FTS5InlineQueryParser.parse("blockade -quarantine") == "blockad NOT quarantin")
    }

    @Test("Leading hyphen excludes a quoted phrase via NOT")
    func leadingHyphenExcludesPhrase() {
        #expect(FTS5InlineQueryParser.parse("blockade -\"naval quarantine\"") == "blockad NOT \"naval quarantin\"")
    }

    @Test("Uppercase NOT excludes the following term")
    func notOperator() {
        #expect(FTS5InlineQueryParser.parse("cold NOT korea") == "cold NOT korea")
    }

    @Test("A bare hyphen with nothing attached is dropped, not treated as negation")
    func bareHyphenDropped() {
        #expect(FTS5InlineQueryParser.parse("cold - war") == "cold war")
    }

    @Test("A query consisting only of excluded terms returns nil (no positive content)")
    func onlyExcludedTermsIsInvalid() {
        #expect(FTS5InlineQueryParser.parse("-korea") == nil)
        #expect(FTS5InlineQueryParser.parse("-korea -vietnam") == nil)
        #expect(FTS5InlineQueryParser.parse("NOT korea") == nil)
    }

    @Test("A bare NOT with nothing to negate is searched for as the literal word 'not'")
    func bareNotIsLiteral() {
        #expect(FTS5InlineQueryParser.parse("cold NOT") == "cold not")
    }

    // MARK: - Prefix Wildcard

    @Test("Trailing asterisk renders as a prefix wildcard, unstemmed")
    func prefixWildcard() {
        #expect(FTS5InlineQueryParser.parse("negoti*") == "negoti*")
    }

    @Test("Excluded prefix wildcard combines hyphen and asterisk")
    func excludedPrefixWildcard() {
        #expect(FTS5InlineQueryParser.parse("cold -negoti*") == "cold NOT negoti*")
    }

    @Test("A bare asterisk with no prefix is dropped")
    func bareAsteriskDropped() {
        #expect(FTS5InlineQueryParser.parse("cold *") == "cold")
    }

    // MARK: - Combined / Realistic Queries

    @Test("Realistic combined query renders with correct operator structure")
    func combinedQuery() {
        // "cold war" OR detente -korea negoti*
        //   → ("cold war" phrase) OR (detent) [implicit AND with] NOT korea [and] negoti*
        // FTS5 precedence (NOT > AND > OR) groups this as:
        //   "cold war" OR (detent AND NOT korea AND negoti*)
        // which is exactly what the space-joined rendering below expresses.
        let result = FTS5InlineQueryParser.parse("\"cold war\" OR detente -korea negoti*")
        #expect(result == "\"cold war\" OR detent NOT korea negoti*")
    }

    @Test("Mixed-case operator words are not mistaken for operators")
    func mixedCaseOperatorsAreLiteral() {
        #expect(FTS5InlineQueryParser.parse("Or And Not") == "or and not")
    }

    // MARK: - Column Scoping

    @Test("Column prefix is applied to bare words, phrases excluded per FTS5Query convention")
    func columnPrefixApplied() {
        let prefix = "{header body_text}:"
        #expect(FTS5InlineQueryParser.parse("cold war", columnPrefix: prefix)
                == "\(prefix)cold \(prefix)war")
    }

    @Test("Column prefix is not applied inside quoted phrases (matches FTS5Query's documented limitation)")
    func columnPrefixSkipsPhrases() {
        let prefix = "{header body_text}:"
        #expect(FTS5InlineQueryParser.parse("\"cold war\" detente", columnPrefix: prefix)
                == "\"cold war\" \(prefix)detent")
    }

    @Test("Column prefix is applied to wildcard prefixes and to NOT-excluded operands")
    func columnPrefixAppliedToWildcardAndExcluded() {
        let prefix = "{header body_text}:"
        #expect(FTS5InlineQueryParser.parse("negoti* -korea", columnPrefix: prefix)
                == "\(prefix)negoti* NOT \(prefix)korea")
    }

    // MARK: - Sanitization / Stemming Consistency

    @Test("Apostrophes are stripped before stemming, matching FTS5Query's structured path")
    func apostropheConsistency() {
        #expect(FTS5InlineQueryParser.parse("don't") == FTS5InlineQueryParser.parse("dont"))
    }

    @Test("Injected FTS5 structural punctuation is sanitized out of bare words")
    func sanitizesInjection() {
        let result = FTS5InlineQueryParser.parse("cold{war}")
        #expect(result != nil)
        #expect(!(result?.contains("{") ?? true))
        #expect(!(result?.contains("}") ?? true))
    }

    @Test("Pure-punctuation tokens that stem to nothing usable are dropped, not embedded raw")
    func punctuationOnlyTokenDropped() {
        // A lone "-" can't be classified as negation (nothing follows it directly) and
        // sanitizes to a non-alphanumeric residue — it must be dropped rather than
        // embedded as a bare "-" (which is invalid FTS5 syntax).
        #expect(FTS5InlineQueryParser.parse("cold ---") == "cold")
    }
}
