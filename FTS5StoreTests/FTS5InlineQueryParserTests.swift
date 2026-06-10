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
/// syntax typed into the main search box is translated into correct, valid FTS5
/// MATCH expressions (and that it never produces syntactically invalid output,
/// regardless of how malformed the input is).
///
/// Terms render as double-quoted FTS5 strings carrying the user's original
/// (sanitised, lowercased) words — the `porter unicode61` tokenizer stems them
/// inside SQLite, so no Porter stems appear in the rendered expressions.
struct FTS5InlineQueryParserTests {

    // MARK: - Plain Keywords (back-compat with the old whitespace-split path)

    @Test("Plain keywords render as implicit AND of quoted words")
    func plainKeywords() {
        #expect(FTS5InlineQueryParser.parse("cold war") == "\"cold\" \"war\"")
    }

    @Test("Single keyword keeps its original word form — the tokenizer stems, not the app")
    func singleKeyword() {
        #expect(FTS5InlineQueryParser.parse("negotiations") == "\"negotiations\"")
    }

    @Test("Empty or whitespace-only input returns nil")
    func emptyInput() {
        #expect(FTS5InlineQueryParser.parse("") == nil)
        #expect(FTS5InlineQueryParser.parse("   ") == nil)
    }

    // MARK: - Quoted Phrases

    @Test("Quoted phrase renders as an FTS5 phrase")
    func quotedPhrase() {
        #expect(FTS5InlineQueryParser.parse("\"cold war\"") == "\"cold war\"")
    }

    @Test("Quoted phrase combines with bare words via implicit AND")
    func phraseWithKeyword() {
        #expect(FTS5InlineQueryParser.parse("\"cold war\" negotiations") == "\"cold war\" \"negotiations\"")
    }

    @Test("Unterminated quote is treated as a phrase running to end of input")
    func unterminatedQuote() {
        #expect(FTS5InlineQueryParser.parse("\"cold war") == "\"cold war\"")
    }

    @Test("Empty quotes produce no operand")
    func emptyQuotes() {
        #expect(FTS5InlineQueryParser.parse("\"\"") == nil)
        #expect(FTS5InlineQueryParser.parse("\"\" cold") == "\"cold\"")
    }

    // MARK: - OR

    @Test("Uppercase OR between two terms renders as FTS5 OR")
    func orOperator() {
        #expect(FTS5InlineQueryParser.parse("Rusk OR Bundy") == "\"rusk\" OR \"bundy\"")
    }

    @Test("OR combines with phrases on either side")
    func orWithPhrase() {
        #expect(FTS5InlineQueryParser.parse("\"cold war\" OR detente") == "\"cold war\" OR \"detente\"")
    }

    @Test("Lowercase 'or' is treated as a literal search word, not an operator")
    func lowercaseOrIsLiteral() {
        // "cold", "or", and "war" are ANDed together as literal quoted words —
        // matching Google's and FTS5's own convention that only uppercase OR is an operator.
        #expect(FTS5InlineQueryParser.parse("cold or war") == "\"cold\" \"or\" \"war\"")
    }

    @Test("Leading OR with no left operand is searched for as the literal word 'or'")
    func leadingOrIsLiteral() {
        #expect(FTS5InlineQueryParser.parse("OR cold") == "\"or\" \"cold\"")
    }

    @Test("Trailing OR with no right operand is searched for as the literal word 'or'")
    func trailingOrIsLiteral() {
        #expect(FTS5InlineQueryParser.parse("cold OR") == "\"cold\" \"or\"")
    }

    @Test("Doubled OR collapses to a single operator with the stray treated as a literal")
    func doubledOr() {
        // First OR: left="cold" (operand), right=second OR (not yet an operand) → demoted to "or".
        // Second OR: left=demoted "or" (now an operand), right="war" (operand) → stays operator.
        #expect(FTS5InlineQueryParser.parse("cold OR OR war") == "\"cold\" \"or\" OR \"war\"")
    }

    // MARK: - Exclusion (leading "-" and NOT)

    @Test("Leading hyphen excludes a term via NOT")
    func leadingHyphenExcludes() {
        #expect(FTS5InlineQueryParser.parse("blockade -quarantine") == "\"blockade\" NOT \"quarantine\"")
    }

    @Test("Leading hyphen excludes a quoted phrase via NOT")
    func leadingHyphenExcludesPhrase() {
        #expect(FTS5InlineQueryParser.parse("blockade -\"naval quarantine\"") == "\"blockade\" NOT \"naval quarantine\"")
    }

    @Test("Uppercase NOT excludes the following term")
    func notOperator() {
        #expect(FTS5InlineQueryParser.parse("cold NOT korea") == "\"cold\" NOT \"korea\"")
    }

    @Test("A bare hyphen with nothing attached is dropped, not treated as negation")
    func bareHyphenDropped() {
        #expect(FTS5InlineQueryParser.parse("cold - war") == "\"cold\" \"war\"")
    }

    @Test("A query consisting only of excluded terms returns nil (no positive content)")
    func onlyExcludedTermsIsInvalid() {
        #expect(FTS5InlineQueryParser.parse("-korea") == nil)
        #expect(FTS5InlineQueryParser.parse("-korea -vietnam") == nil)
        #expect(FTS5InlineQueryParser.parse("NOT korea") == nil)
    }

    @Test("A bare NOT with nothing to negate is searched for as the literal word 'not'")
    func bareNotIsLiteral() {
        #expect(FTS5InlineQueryParser.parse("cold NOT") == "\"cold\" \"not\"")
    }

    // MARK: - Prefix Wildcard

    @Test("Trailing asterisk renders as a quoted prefix wildcard")
    func prefixWildcard() {
        #expect(FTS5InlineQueryParser.parse("negoti*") == "\"negoti\"*")
    }

    @Test("Excluded prefix wildcard combines hyphen and asterisk")
    func excludedPrefixWildcard() {
        #expect(FTS5InlineQueryParser.parse("cold -negoti*") == "\"cold\" NOT \"negoti\"*")
    }

    @Test("A bare asterisk with no prefix is dropped")
    func bareAsteriskDropped() {
        #expect(FTS5InlineQueryParser.parse("cold *") == "\"cold\"")
    }

    // MARK: - Combined / Realistic Queries

    @Test("Realistic combined query renders with correct operator structure")
    func combinedQuery() {
        // "cold war" OR detente -korea negoti*
        //   → ("cold war" phrase) OR (detente) [implicit AND with] NOT korea [and] negoti*
        // FTS5 precedence (NOT > AND > OR) groups this as:
        //   "cold war" OR (detente AND NOT korea AND negoti*)
        // which is exactly what the space-joined rendering below expresses.
        let result = FTS5InlineQueryParser.parse("\"cold war\" OR detente -korea negoti*")
        #expect(result == "\"cold war\" OR \"detente\" NOT \"korea\" \"negoti\"*")
    }

    @Test("Mixed-case operator words are not mistaken for operators")
    func mixedCaseOperatorsAreLiteral() {
        #expect(FTS5InlineQueryParser.parse("Or And Not") == "\"or\" \"and\" \"not\"")
    }

    // MARK: - Column Scoping

    @Test("Column prefix is applied to bare words, phrases excluded per FTS5Query convention")
    func columnPrefixApplied() {
        let prefix = "{header body_text}:"
        #expect(FTS5InlineQueryParser.parse("cold war", columnPrefix: prefix)
                == "\(prefix)\"cold\" \(prefix)\"war\"")
    }

    @Test("Column prefix is not applied inside quoted phrases (matches FTS5Query's documented limitation)")
    func columnPrefixSkipsPhrases() {
        let prefix = "{header body_text}:"
        #expect(FTS5InlineQueryParser.parse("\"cold war\" detente", columnPrefix: prefix)
                == "\"cold war\" \(prefix)\"detente\"")
    }

    @Test("Column prefix is applied to wildcard prefixes and to NOT-excluded operands")
    func columnPrefixAppliedToWildcardAndExcluded() {
        let prefix = "{header body_text}:"
        #expect(FTS5InlineQueryParser.parse("negoti* -korea", columnPrefix: prefix)
                == "\(prefix)\"negoti\"* NOT \(prefix)\"korea\"")
    }

    // MARK: - Sanitization Consistency

    @Test("Apostrophes survive inside the quoted term — SQLite tokenizes them like indexed text")
    func apostropheQuoted() {
        // "don't" is not a valid FTS5 bareword unquoted, but inside a quoted string
        // unicode61 splits it exactly as it split the indexed text.
        #expect(FTS5InlineQueryParser.parse("don't") == "\"don't\"")
    }

    @Test("Injected FTS5 structural punctuation is sanitized out of bare words")
    func sanitizesInjection() {
        // Braces are structural FTS5 syntax; the sanitizer maps them to spaces, so
        // "cold{war}" survives as the two-word quoted string (an FTS5 phrase).
        let result = FTS5InlineQueryParser.parse("cold{war}")
        #expect(result == "\"cold war\"")
    }

    @Test("Pure-punctuation tokens that sanitise to nothing usable are dropped, not embedded raw")
    func punctuationOnlyTokenDropped() {
        // A lone "-" can't be classified as negation (nothing follows it directly) and
        // sanitizes to a non-alphanumeric residue — it must be dropped rather than
        // embedded as a bare "-" (which is invalid FTS5 syntax).
        #expect(FTS5InlineQueryParser.parse("cold ---") == "\"cold\"")
    }

    // MARK: - Parenthetical Grouping

    @Test("Parenthesised groups of OR-terms combine via implicit AND, preserving the user's intended grouping")
    func basicGrouping() {
        // The motivating example: "(aqaba OR tiran) AND (navigation OR passage OR transit)"
        // — without grouping support this collapsed to a single flat OR-chain whose
        // FTS5 NOT > AND > OR precedence read completely differently than intended.
        #expect(FTS5InlineQueryParser.parse("(aqaba OR tiran) AND (navigation OR passage OR transit)")
                == "(\"aqaba\" OR \"tiran\") (\"navigation\" OR \"passage\" OR \"transit\")")
    }

    @Test("Adjacent groups combine via implicit AND with no explicit AND keyword")
    func implicitAndBetweenGroups() {
        #expect(FTS5InlineQueryParser.parse("(aqaba OR tiran) (navigation OR passage OR transit)")
                == "(\"aqaba\" OR \"tiran\") (\"navigation\" OR \"passage\" OR \"transit\")")
    }

    @Test("Lowercase 'or'/'and' inside parens are still literal words — grouping doesn't change operator casing rules")
    func groupingDoesNotRelaxCasingRules() {
        #expect(FTS5InlineQueryParser.parse("(aqaba or tiran) and (navigation or passage or transit)")
                == "(\"aqaba\" \"or\" \"tiran\") \"and\" (\"navigation\" \"or\" \"passage\" \"or\" \"transit\")")
    }

    @Test("NOT can exclude an entire parenthesised group")
    func notExcludesGroup() {
        #expect(FTS5InlineQueryParser.parse("cold NOT (korea OR vietnam)")
                == "\"cold\" NOT (\"korea\" OR \"vietnam\")")
    }

    @Test("A query consisting only of a NOT-excluded group returns nil (no positive content)")
    func onlyNotGroupIsInvalid() {
        #expect(FTS5InlineQueryParser.parse("NOT (korea OR vietnam)") == nil)
    }

    @Test("Groups nest to arbitrary depth and each level renders its own parentheses")
    func nestedGroups() {
        // "navig*" renders as a quoted prefix wildcard — sanitised but never stemmed.
        #expect(FTS5InlineQueryParser.parse("((aqaba OR tiran) AND navig*) OR (suez NOT canal)")
                == "((\"aqaba\" OR \"tiran\") \"navig\"*) OR (\"suez\" NOT \"canal\")")
    }

    @Test("Phrases and column-prefix scoping work the same inside groups as at the top level")
    func phraseAndColumnPrefixInsideGroup() {
        #expect(FTS5InlineQueryParser.parse("(\"cold war\" OR detente)") == "(\"cold war\" OR \"detente\")")

        let prefix = "{header body_text}:"
        #expect(FTS5InlineQueryParser.parse("(aqaba OR tiran)", columnPrefix: prefix)
                == "(\(prefix)\"aqaba\" OR \(prefix)\"tiran\")")
    }

    @Test("Orphaned operators inside a group are demoted to literals, just like at the top level")
    func orphanDemotionInsideGroup() {
        #expect(FTS5InlineQueryParser.parse("(cold OR)") == "(\"cold\" \"or\")")
    }

    @Test("A group with no positive content is dropped entirely rather than rendered empty")
    func contentlessGroupDropped() {
        #expect(FTS5InlineQueryParser.parse("cold ()") == "\"cold\"")
        #expect(FTS5InlineQueryParser.parse("cold (   )") == "\"cold\"")
        #expect(FTS5InlineQueryParser.parse("cold (-korea)") == "\"cold\"")
        #expect(FTS5InlineQueryParser.parse("cold (NOT korea)") == "\"cold\"")
    }

    @Test("Unmatched parentheses degrade gracefully to dropped punctuation rather than malformed output")
    func unmatchedParenDegradesGracefully() {
        #expect(FTS5InlineQueryParser.parse("cold (war") == "\"cold\" \"war\"")
        #expect(FTS5InlineQueryParser.parse("cold war)") == "\"cold\" \"war\"")
        #expect(FTS5InlineQueryParser.parse("cold )(") == "\"cold\"")
    }

    @Test("Leading hyphen does not negate a group — only the keyword NOT does")
    func leadingHyphenDoesNotNegateGroup() {
        // Documented asymmetry: "-(...)" tokenises as a standalone "-" (dropped) plus
        // an ordinary, positive group — not as "exclude this group". Users must spell
        // out "NOT (...)" to negate a group.
        #expect(FTS5InlineQueryParser.parse("cold -(korea OR vietnam)")
                == "\"cold\" (\"korea\" OR \"vietnam\")")
    }

    @Test("A balanced group containing further unbalanced inner parens still extracts correctly")
    func innerUnbalancedParensWithinBalancedOuterGroup() {
        // "(a (b) c)" is one balanced outer group containing "a (b) c"; the inner
        // "(b)" nests as its own group, so the whole thing renders as nested groups.
        #expect(FTS5InlineQueryParser.parse("(cold (war) korea)")
                == "(\"cold\" (\"war\") \"korea\")")
    }
}
