// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import SQLite3
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
///
/// Adjacent operands are joined with an explicit `AND` keyword (Session 159): FTS5
/// rejects bare juxtaposition between parenthesised groups, so `(a OR b) (c OR d)`
/// must render as `(a OR b) AND (c OR d)`. Operators are case-insensitive.
struct FTS5InlineQueryParserTests {

    // MARK: - Plain Keywords

    @Test("Plain keywords render as an explicit AND of quoted words")
    func plainKeywords() {
        #expect(FTS5InlineQueryParser.parse("cold war") == "\"cold\" AND \"war\"")
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

    @Test("Quoted phrase combines with bare words via explicit AND")
    func phraseWithKeyword() {
        #expect(FTS5InlineQueryParser.parse("\"cold war\" negotiations") == "\"cold war\" AND \"negotiations\"")
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

    @Test("OR between two terms renders as FTS5 OR")
    func orOperator() {
        #expect(FTS5InlineQueryParser.parse("Rusk OR Bundy") == "\"rusk\" OR \"bundy\"")
    }

    @Test("OR combines with phrases on either side")
    func orWithPhrase() {
        #expect(FTS5InlineQueryParser.parse("\"cold war\" OR detente") == "\"cold war\" OR \"detente\"")
    }

    @Test("Lowercase 'or' is recognised as the OR operator (case-insensitive)")
    func lowercaseOrIsOperator() {
        // Session 159: operators are case-insensitive, matching history.state.gov.
        #expect(FTS5InlineQueryParser.parse("cold or war") == "\"cold\" OR \"war\"")
    }

    @Test("Mixed-case 'Or' is recognised as the OR operator")
    func mixedCaseOrIsOperator() {
        #expect(FTS5InlineQueryParser.parse("cold Or war") == "\"cold\" OR \"war\"")
    }

    @Test("Leading OR with no left operand is demoted to the literal word 'or'")
    func leadingOrIsLiteral() {
        #expect(FTS5InlineQueryParser.parse("OR cold") == "\"or\" AND \"cold\"")
    }

    @Test("Trailing OR with no right operand is demoted to the literal word 'or'")
    func trailingOrIsLiteral() {
        #expect(FTS5InlineQueryParser.parse("cold OR") == "\"cold\" AND \"or\"")
    }

    @Test("Doubled OR collapses to a single operator with the stray demoted to a literal")
    func doubledOr() {
        // First OR: left="cold" (operand), right=second OR (not yet an operand) → demoted to "or".
        // Second OR: left=demoted "or" (now an operand), right="war" (operand) → stays operator.
        #expect(FTS5InlineQueryParser.parse("cold OR OR war") == "\"cold\" AND \"or\" OR \"war\"")
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

    @Test("NOT (any case) excludes the following term")
    func notOperator() {
        #expect(FTS5InlineQueryParser.parse("cold NOT korea") == "\"cold\" NOT \"korea\"")
        #expect(FTS5InlineQueryParser.parse("cold not korea") == "\"cold\" NOT \"korea\"")
    }

    @Test("A bare hyphen with nothing attached is dropped, not treated as negation")
    func bareHyphenDropped() {
        #expect(FTS5InlineQueryParser.parse("cold - war") == "\"cold\" AND \"war\"")
    }

    @Test("A query consisting only of excluded terms returns nil (no positive content)")
    func onlyExcludedTermsIsInvalid() {
        #expect(FTS5InlineQueryParser.parse("-korea") == nil)
        #expect(FTS5InlineQueryParser.parse("-korea -vietnam") == nil)
        #expect(FTS5InlineQueryParser.parse("NOT korea") == nil)
    }

    @Test("A bare NOT with nothing to negate is demoted to the literal word 'not'")
    func bareNotIsLiteral() {
        #expect(FTS5InlineQueryParser.parse("cold NOT") == "\"cold\" AND \"not\"")
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
        //   → ("cold war") OR ("detente" NOT "korea" AND "negoti"*)
        // FTS5 precedence is NOT > AND > OR, so the space-joined rendering below means
        // `"cold war" OR (("detente" NOT "korea") AND "negoti"*)`.
        let result = FTS5InlineQueryParser.parse("\"cold war\" OR detente -korea negoti*")
        #expect(result == "\"cold war\" OR \"detente\" NOT \"korea\" AND \"negoti\"*")
    }

    @Test("Operators with no operands to bind are demoted to literal words (any case)")
    func orphanedOperatorsDemoteToLiterals() {
        // With case-insensitive operators, `Or And Not` are all recognised as operators,
        // but none has the operands it needs, so each is demoted to its literal word.
        #expect(FTS5InlineQueryParser.parse("Or And Not") == "\"or\" AND \"and\" AND \"not\"")
    }

    // MARK: - Column Scoping

    @Test("Column prefix is applied to bare words, phrases excluded per FTS5Query convention")
    func columnPrefixApplied() {
        let prefix = "{header body_text}:"
        #expect(FTS5InlineQueryParser.parse("cold war", columnPrefix: prefix)
                == "\(prefix)\"cold\" AND \(prefix)\"war\"")
    }

    @Test("Column prefix is not applied inside quoted phrases (matches FTS5Query's documented limitation)")
    func columnPrefixSkipsPhrases() {
        let prefix = "{header body_text}:"
        #expect(FTS5InlineQueryParser.parse("\"cold war\" detente", columnPrefix: prefix)
                == "\"cold war\" AND \(prefix)\"detente\"")
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

    @Test("Parenthesised groups combine via an explicit AND, preserving the user's intended grouping")
    func basicGrouping() {
        // The motivating example. The explicit AND keyword between the two groups is
        // required — FTS5 rejects `(...) (...)` as a syntax error (the Session 159 bug).
        #expect(FTS5InlineQueryParser.parse("(aqaba OR tiran) AND (navigation OR passage OR transit)")
                == "(\"aqaba\" OR \"tiran\") AND (\"navigation\" OR \"passage\" OR \"transit\")")
    }

    @Test("Adjacent groups with no explicit operator still combine via an explicit AND")
    func implicitAndBetweenGroups() {
        #expect(FTS5InlineQueryParser.parse("(aqaba OR tiran) (navigation OR passage OR transit)")
                == "(\"aqaba\" OR \"tiran\") AND (\"navigation\" OR \"passage\" OR \"transit\")")
    }

    @Test("Lowercase operators inside and around parens act as operators (case-insensitive)")
    func lowercaseOperatorsWithGroups() {
        // The user's reported query, verbatim — lowercase `or`/`and` are operators.
        #expect(FTS5InlineQueryParser.parse("(aqaba or tiran) and (navigation or passage or transit)")
                == "(\"aqaba\" OR \"tiran\") AND (\"navigation\" OR \"passage\" OR \"transit\")")
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
                == "((\"aqaba\" OR \"tiran\") AND \"navig\"*) OR (\"suez\" NOT \"canal\")")
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
        #expect(FTS5InlineQueryParser.parse("(cold OR)") == "(\"cold\" AND \"or\")")
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
        #expect(FTS5InlineQueryParser.parse("cold (war") == "\"cold\" AND \"war\"")
        #expect(FTS5InlineQueryParser.parse("cold war)") == "\"cold\" AND \"war\"")
        #expect(FTS5InlineQueryParser.parse("cold )(") == "\"cold\"")
    }

    @Test("Leading hyphen does not negate a group — only the keyword NOT does")
    func leadingHyphenDoesNotNegateGroup() {
        // Documented asymmetry: "-(...)" tokenises as a standalone "-" (dropped) plus
        // an ordinary, positive group — not as "exclude this group". Users must spell
        // out "NOT (...)" to negate a group.
        #expect(FTS5InlineQueryParser.parse("cold -(korea OR vietnam)")
                == "\"cold\" AND (\"korea\" OR \"vietnam\")")
    }

    @Test("A balanced group containing further unbalanced inner parens still extracts correctly")
    func innerUnbalancedParensWithinBalancedOuterGroup() {
        // "(a (b) c)" is one balanced outer group containing "a (b) c"; the inner
        // "(b)" nests as its own group, so the whole thing renders as nested groups.
        #expect(FTS5InlineQueryParser.parse("(cold (war) korea)")
                == "(\"cold\" AND (\"war\") AND \"korea\")")
    }

    // MARK: - Execution Against a Real FTS5 Table
    //
    // The string-match tests above pin the *shape* of the rendered expression; these
    // execute it against an actual `porter unicode61` FTS5 table. This is the safety net
    // that was missing when the "grouped query → bare juxtaposition → FTS5 syntax error →
    // zero results" bug shipped: a rendered string can look right yet be rejected by
    // SQLite. `runMatch` throws on any FTS5 syntax error, so an invalid expression fails
    // the test instead of silently returning nothing.

    /// Two FRUS-flavoured documents used by the execution tests.
    private static let corpus: [String] = [
        // d0 — contains aqaba + navigation; also the literal word "and".
        "Free navigation through the Strait of Tiran and the Gulf of Aqaba was at issue.",
        // d1 — contains aqaba + passage/transit; no standalone word "and".
        "The blockade of Aqaba raised questions of innocent passage, transit rights, Israel.",
    ]

    /// Builds an in-memory `porter unicode61` FTS5 table, seeds `Self.corpus`, runs the
    /// parser's rendered expression as a `MATCH`, and returns the match count. Throws if
    /// SQLite rejects the expression (a syntax error) — turning "invalid FTS5" into a test
    /// failure rather than a silently-empty result.
    private func runMatch(_ rawQuery: String) throws -> Int {
        let expr = try #require(FTS5InlineQueryParser.parse(rawQuery),
                                "parser returned nil for: \(rawQuery)")
        var db: OpaquePointer?
        #expect(sqlite3_open(":memory:", &db) == SQLITE_OK)
        defer { sqlite3_close(db) }

        #expect(sqlite3_exec(db,
            "CREATE VIRTUAL TABLE d USING fts5(body, tokenize='porter unicode61');",
            nil, nil, nil) == SQLITE_OK)
        for body in Self.corpus {
            var ins: OpaquePointer?
            #expect(sqlite3_prepare_v2(db, "INSERT INTO d(body) VALUES (?);", -1, &ins, nil) == SQLITE_OK)
            sqlite3_bind_text(ins, 1, body, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            #expect(sqlite3_step(ins) == SQLITE_DONE)
            sqlite3_finalize(ins)
        }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT count(*) FROM d WHERE d MATCH ?;", -1, &stmt, nil) == SQLITE_OK else {
            throw FTS5ExecError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, expr, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        let rc = sqlite3_step(stmt)
        guard rc == SQLITE_ROW else {
            // FTS5 syntax errors surface here as the step failing.
            throw FTS5ExecError.stepFailed(String(cString: sqlite3_errmsg(db)))
        }
        return Int(sqlite3_column_int(stmt, 0))
    }

    private enum FTS5ExecError: Error { case prepareFailed(String), stepFailed(String) }

    @Test("The user's reported grouped query executes and matches both documents")
    func userGroupedQueryExecutes() throws {
        // The exact reported input (uppercase OR, lowercase and). Before Session 159 this
        // rendered to `(...) (...)` and FTS5 rejected it → zero results.
        let count = try runMatch("(aqaba OR tiran) and (navigation OR passage OR transit)")
        #expect(count == 2)
    }

    @Test("Uppercase grouped AND executes and matches")
    func uppercaseGroupedQueryExecutes() throws {
        let count = try runMatch("(aqaba OR tiran) AND (navigation OR passage OR transit)")
        #expect(count == 2)
    }

    @Test("Grouped AND still narrows correctly — a non-matching right group yields zero")
    func groupedQueryNarrows() throws {
        // Neither document mentions Suez or a canal, so the AND must exclude both.
        let count = try runMatch("(aqaba OR tiran) AND (suez OR canal)")
        #expect(count == 0)
    }

    @Test("Plain multi-word, OR, NOT, wildcards, and nested groups all execute as valid FTS5")
    func assortedQueriesExecute() throws {
        #expect(try runMatch("aqaba navigation") == 1)            // d0 only (both words)
        #expect(try runMatch("passage OR navigation") == 2)       // d0 + d1
        #expect(try runMatch("aqaba NOT passage") == 1)           // d0 only (d1 has passage)
        #expect(try runMatch("navig*") == 1)                      // d0 (navigation)
        #expect(try runMatch("((aqaba OR tiran) AND navig*) OR (suez AND canal)") == 1)
    }
}
