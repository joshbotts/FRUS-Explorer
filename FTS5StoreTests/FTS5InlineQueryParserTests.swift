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

    @Test("Groups nest and each level renders its own parentheses")
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

    @Test("A content-free group is dropped; a group of only exclusions excludes from its run")
    func contentlessGroupDropped() {
        #expect(FTS5InlineQueryParser.parse("cold ()") == "\"cold\"")
        #expect(FTS5InlineQueryParser.parse("cold (   )") == "\"cold\"")
        // #1297: dropping these returned the korea documents the group asked to exclude.
        #expect(FTS5InlineQueryParser.parse("cold (-korea)") == "\"cold\" NOT \"korea\"")
        #expect(FTS5InlineQueryParser.parse("cold (NOT korea)") == "\"cold\" NOT \"korea\"")
    }

    @Test("Unmatched parentheses degrade gracefully to dropped punctuation rather than malformed output")
    func unmatchedParenDegradesGracefully() {
        #expect(FTS5InlineQueryParser.parse("cold (war") == "\"cold\" AND \"war\"")
        #expect(FTS5InlineQueryParser.parse("cold war)") == "\"cold\" AND \"war\"")
        #expect(FTS5InlineQueryParser.parse("cold )(") == "\"cold\"")
    }

    @Test("A hyphen attached to a group negates it as NOT does; a detached hyphen is punctuation")
    func attachedHyphenNegatesGroup() {
        // #1297 retired the asymmetry this test used to pin, where "-(...)" searched FOR the
        // group. An attached "-(" now reads as "NOT (". A hyphen with whitespace after it is a
        // lone "-", which is dropped as punctuation everywhere, so that group stays positive.
        #expect(FTS5InlineQueryParser.parse("cold -(korea OR vietnam)")
                == "\"cold\" NOT (\"korea\" OR \"vietnam\")")
        #expect(FTS5InlineQueryParser.parse("cold - (korea OR vietnam)")
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
    private func runMatch(_ rawQuery: String, corpus: [String] = FTS5InlineQueryParserTests.corpus) throws -> Int {
        let expr = try #require(FTS5InlineQueryParser.parse(rawQuery),
                                "parser returned nil for: \(rawQuery)")
        return try execute(expr, corpus: corpus)
    }

    /// Runs an already-rendered expression, so a test can assert that a *specific* string
    /// is valid FTS5 without going through the parser.
    private func execute(_ expr: String, corpus: [String]) throws -> Int {
        var db: OpaquePointer?
        #expect(sqlite3_open(":memory:", &db) == SQLITE_OK)
        defer { sqlite3_close(db) }

        #expect(sqlite3_exec(db,
            "CREATE VIRTUAL TABLE d USING fts5(body, tokenize='porter unicode61');",
            nil, nil, nil) == SQLITE_OK)
        for body in corpus {
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

    // MARK: - NEAR (Q-1)

    // Distance semantics are the whole point of this operator, so the corpus below places
    // the same two words at *known* token distances. Every test that claims a distance
    // matters proves it by bracketing: one distance that matches and one that does not.
    // A NEAR test that only ever asserts "> 0" would pass against a parser that dropped
    // the distance entirely.

    /// n0 places "military" and "europe" 2 tokens apart; n1 places them 8 apart; n2
    /// contains "military guarantee" as a phrase 3 tokens before "europe"; n3 contains
    /// both words but very far apart.
    private static let nearCorpus: [String] = [
        // n0 — distance 2 ("military" → "aid" "to" → "europe" is 3 apart; keep it tight)
        "military aid europe",
        // n1 — the same two words, eight tokens apart
        "military assistance was debated at length before any commitment to europe",
        // n2 — the phrase form the alliance report uses
        "the military guarantee finally extended to europe in 1948",
        // n3 — both words, but far beyond any distance these tests use
        "military planning occupied the joint chiefs through a long sequence of "
        + "internal reviews memoranda position papers and staff studies before the "
        + "question of a formal commitment to europe was ever placed on the agenda",
    ]

    @Test("Canonical NEAR renders uppercase with quoted operands and an explicit distance")
    func nearRendersCanonically() {
        #expect(FTS5InlineQueryParser.parse("NEAR(military europe, 30)")
                == "NEAR(\"military\" \"europe\", 30)")
    }

    @Test("A phrase operand survives intact inside NEAR")
    func nearWithPhraseOperand() {
        #expect(FTS5InlineQueryParser.parse("NEAR(\"military guarantee\" europe, 30)")
                == "NEAR(\"military guarantee\" \"europe\", 30)")
    }

    @Test("A prefix operand renders in the parser's own quoted-prefix form")
    func nearWithPrefixOperand() {
        #expect(FTS5InlineQueryParser.parse("NEAR(militar* europ*, 5)")
                == "NEAR(\"militar\"* \"europ\"*, 5)")
    }

    @Test("Lowercase near is accepted on input and emitted uppercase — FTS5 rejects near(")
    func nearIsCaseInsensitiveOnInputOnly() {
        // The engine is not case-insensitive here: `near(a b, 5)` is a hard FTS5 syntax
        // error. Accepting the user's lowercase and emitting uppercase is the whole job.
        #expect(FTS5InlineQueryParser.parse("near(military europe, 5)")
                == "NEAR(\"military\" \"europe\", 5)")
        #expect(FTS5InlineQueryParser.parse("Near(military europe, 5)")
                == "NEAR(\"military\" \"europe\", 5)")
    }

    @Test("An omitted distance renders explicitly as FTS5's default of 10")
    func nearDefaultDistanceIsExplicit() {
        // Rendered rather than left implicit so the Query Inspector — and a method
        // appendix copied out of it — shows the distance that actually applied.
        #expect(FTS5InlineQueryParser.parse("NEAR(military europe)")
                == "NEAR(\"military\" \"europe\", 10)")
    }

    @Test("The NEAR/N alias is translated to the canonical comma form")
    func nearSlashAliasIsTranslated() {
        // `NEAR/5(a b)` is FTS3/4 syntax and is NOT valid FTS5 in any spelling, so this
        // is a real translation. The execution test below is what proves it.
        #expect(FTS5InlineQueryParser.parse("NEAR/5(military europe)")
                == "NEAR(\"military\" \"europe\", 5)")
        #expect(FTS5InlineQueryParser.parse("near/5(military europe)")
                == "NEAR(\"military\" \"europe\", 5)")
    }

    @Test("NEAR composes with AND, OR, NOT and nests inside groups")
    func nearComposes() {
        #expect(FTS5InlineQueryParser.parse("NEAR(military europe, 5) AND aid")
                == "NEAR(\"military\" \"europe\", 5) AND \"aid\"")
        #expect(FTS5InlineQueryParser.parse("NEAR(military europe, 5) OR aid")
                == "NEAR(\"military\" \"europe\", 5) OR \"aid\"")
        #expect(FTS5InlineQueryParser.parse("aid NOT NEAR(military europe, 5)")
                == "\"aid\" NOT NEAR(\"military\" \"europe\", 5)")
        #expect(FTS5InlineQueryParser.parse("(NEAR(military europe, 5) OR aid) AND treaty")
                == "(NEAR(\"military\" \"europe\", 5) OR \"aid\") AND \"treaty\"")
    }

    @Test("Two juxtaposed NEARs are joined by an explicit AND, not bare juxtaposition")
    func adjacentNearsGetExplicitAnd() {
        // The Session-159 bug class: bare juxtaposition between non-phrase operands is an
        // FTS5 syntax error. A NEAR is one of those operands.
        #expect(FTS5InlineQueryParser.parse("NEAR(military europe, 5) NEAR(aid treaty, 5)")
                == "NEAR(\"military\" \"europe\", 5) AND NEAR(\"aid\" \"treaty\", 5)")
    }

    @Test("The column prefix wraps the whole NEAR, never its inner operands")
    func nearColumnScoping() {
        // `NEAR({body_text}: a b, 5)` is an FTS5 syntax error; the prefix must lead.
        #expect(FTS5InlineQueryParser.parse("NEAR(military europe, 5)",
                                            columnPrefix: "{summary_text}:")
                == "{summary_text}:NEAR(\"military\" \"europe\", 5)")
    }

    @Test("A phrase inside NEAR is column-scoped, unlike a bare phrase")
    func nearPhraseIsColumnScopedUnlikeABarePhrase() {
        // A documented, deliberate asymmetry: a bare phrase spans all columns because
        // FTS5Query says so, but FTS5 gives no way to exempt one operand from a NEAR's
        // prefix. Pinned so the difference is a decision rather than a surprise.
        #expect(FTS5InlineQueryParser.parse("\"military guarantee\"",
                                            columnPrefix: "{summary_text}:")
                == "\"military guarantee\"")
        #expect(FTS5InlineQueryParser.parse("NEAR(\"military guarantee\" europe, 5)",
                                            columnPrefix: "{summary_text}:")
                == "{summary_text}:NEAR(\"military guarantee\" \"europe\", 5)")
    }

    // MARK: - NEAR degradation

    @Test("A boolean inside NEAR refuses the query rather than becoming one (#1304)")
    func nearRefusesBooleans() {
        // THIS TEST REPLACES THE DEGRADATION CONTRACT IT USED TO PIN. Until #1304 the NEAR
        // keyword was dropped and the parentheses rendered as an ordinary boolean group, so
        // `NEAR(military OR europe, 5)` searched `("military" OR "europe," AND "5")` — an OR
        // where a proximity search was asked for, AND the DISTANCE searched as a word. The
        // reader got a plausible count for a query nobody wrote and no way to tell.
        #expect(FTS5InlineQueryParser.parse("NEAR(military OR europe, 5)") == nil)
        #expect(FTS5InlineQueryParser.parse("NEAR(military NOT europe, 5)") == nil)
        #expect(FTS5InlineQueryParser.parse("NEAR(military AND europe, 5)") == nil)
        // The reason travels with the refusal, so a surface can say which NEAR and why.
        let parsed = FTS5InlineQueryParser.parseDetailed("NEAR(military OR europe, 5)")
        #expect(parsed.malformedProximity == .operatorInside(text: "NEAR( military OR europe, 5 )"),
                "got \(String(describing: parsed.malformedProximity))")
    }

    @Test("A negation or a nested group inside NEAR refuses the same way (#1304)")
    func nearRefusesNegationAndNesting() {
        // The negation case was the worst of them: `"military" NOT "europe,"` excluded every
        // document holding europe ANYWHERE, which is the opposite of proximity.
        #expect(FTS5InlineQueryParser.parse("NEAR(military -europe, 5)") == nil)
        #expect(FTS5InlineQueryParser.parse("NEAR((military europe), 5)") == nil)
        #expect(FTS5InlineQueryParser.parse("NEAR(NEAR(cold war, 5) europe, 5)") == nil)
        for query in ["NEAR(military -europe, 5)", "NEAR((military europe), 5)"] {
            #expect(FTS5InlineQueryParser.parseDetailed(query).malformedProximity != nil, "\(query)")
        }
    }

    @Test("A NEAR the parser accepts is unaffected by the refusal (#1304)")
    func wellFormedNearStillRenders() {
        // The guard against over-refusing: these are the forms the refusal must not touch.
        #expect(FTS5InlineQueryParser.parse("NEAR(military europe, 5)")
                == "NEAR(\"military\" \"europe\", 5)")
        #expect(FTS5InlineQueryParser.parse("NEAR(military europe)")
                == "NEAR(\"military\" \"europe\", 10)")
        #expect(FTS5InlineQueryParser.parse("NEAR/5(military europe)")
                == "NEAR(\"military\" \"europe\", 5)")
        #expect(FTS5InlineQueryParser.parseDetailed("NEAR(military europe, 5)")
                .malformedProximity == nil)
    }

    @Test("A degraded NEAR's comma-bearing operand matches the same documents as the bare word")
    func degradedCommaOperandMatchesTheSameDocuments() throws {
        // The claim the comment above rests on, measured rather than asserted: if FTS5
        // ever stopped treating the comma as a separator, the degradation contract would
        // quietly start returning the wrong documents instead of failing loudly.
        let withComma = try execute("\"europe,\"", corpus: Self.nearCorpus)
        let without = try execute("\"europe\"", corpus: Self.nearCorpus)
        #expect(withComma == without)
        #expect(without == 4, "every document in nearCorpus mentions europe")
    }

    @Test("Every distance FTS5 refuses degrades rather than reaching SQLite")
    func nearRejectsMalformedDistances() {
        // Each of these is a verified FTS5 syntax error: negative, decimal, signed,
        // non-numeric, and empty.
        for bad in ["-1", "3.5", "+5", "x", ""] {
            let rendered = FTS5InlineQueryParser.parse("NEAR(military europe, \(bad))")
            #expect(rendered?.contains("NEAR(") != true,
                    "distance '\(bad)' must not render a NEAR — got \(rendered ?? "nil")")
        }
    }

    @Test("A NEAR keyword with no argument list is just the word 'near'")
    func bareNearIsAWord() {
        #expect(FTS5InlineQueryParser.parse("near") == "\"near\"")
        #expect(FTS5InlineQueryParser.parse("near europe") == "\"near\" AND \"europe\"")
    }

    @Test("An empty NEAR carries no search content")
    func emptyNearIsDropped() {
        #expect(FTS5InlineQueryParser.parse("NEAR()") == nil)
        #expect(FTS5InlineQueryParser.parse("NEAR(   )") == nil)
    }

    @Test("A comma inside a phrase is not mistaken for the distance separator")
    func commaInsidePhraseIsNotTheDistance() {
        // The naive "split on the last comma" reading finds the one inside the quotes,
        // reads `war" europe` as the distance, and rejects a perfectly good query.
        #expect(FTS5InlineQueryParser.parse("NEAR(\"cold, war\" europe)")
                == "NEAR(\"cold, war\" \"europe\", 10)")
        #expect(FTS5InlineQueryParser.parse("NEAR(\"cold, war\" europe, 5)")
                == "NEAR(\"cold, war\" \"europe\", 5)")
    }

    @Test("A conflicting distance in both alias and comma position is refused")
    func nearAliasWithCommaIsRefused() {
        let rendered = FTS5InlineQueryParser.parse("NEAR/5(military europe, 30)")
        #expect(rendered?.contains("NEAR(") != true,
                "two distances must not silently pick one — got \(rendered ?? "nil")")
    }

    // MARK: - NEAR execution against real FTS5

    @Test("NEAR executes and the distance actually narrows the match")
    func nearDistanceNarrows() throws {
        let c = Self.nearCorpus
        // n0 has the words 2 apart, n1 eight apart, n2 has "military guarantee"…"europe",
        // n3 has them far apart. A tight distance must exclude what a loose one includes —
        // this bracketing is what proves the distance is not being dropped.
        let tight = try runMatch("NEAR(military europe, 2)", corpus: c)
        let loose = try runMatch("NEAR(military europe, 40)", corpus: c)
        #expect(tight < loose, "distance 2 must match strictly fewer docs than 40")
        #expect(tight >= 1, "the 2-apart document must still match at distance 2")
        #expect(loose == 4, "at distance 40 every document in this corpus qualifies")
    }

    @Test("The alliance report's published query shape executes as valid FTS5")
    func reportQueryShapeExecutes() throws {
        // The exact shape from the source report — a phrase operand, a bare operand, and
        // the comma distance form. Before Q-1 this rendered as
        // `"near" AND ("military guarantee" AND "europe," AND "30")`, which is a
        // completely different query that happened to be valid.
        let count = try runMatch("NEAR(\"military guarantee\" europe, 30)", corpus: Self.nearCorpus)
        #expect(count == 1, "only n2 carries the phrase near europe")
    }

    @Test("Every NEAR spelling and composition the parser emits is accepted by SQLite")
    func nearVariantsAreValidFTS5() throws {
        let c = Self.nearCorpus
        // Each of these throws if SQLite rejects the rendered expression.
        _ = try runMatch("NEAR(military europe)", corpus: c)
        _ = try runMatch("NEAR/5(military europe)", corpus: c)
        _ = try runMatch("NEAR(militar* europ*, 5)", corpus: c)
        _ = try runMatch("NEAR(military, 5)", corpus: c)                 // degenerate, valid
        _ = try runMatch("NEAR(military europe aid, 5)", corpus: c)      // three operands
        _ = try runMatch("NEAR(military europe, 5) AND aid", corpus: c)
        _ = try runMatch("aid NOT NEAR(military europe, 5)", corpus: c)
        _ = try runMatch("(NEAR(military europe, 5) OR aid) AND treaty", corpus: c)
        _ = try runMatch("NEAR(military europe, 5) NEAR(aid treaty, 5)", corpus: c)
        _ = try runMatch("NEAR(\"cold, war\" europe)", corpus: c)
    }

    @Test("A column-scoped NEAR is valid FTS5 against a real multi-column table")
    func columnScopedNearIsValid() throws {
        // The single-column corpus table cannot exercise a column prefix, so this builds
        // its own two-column table and runs the rendered expression directly.
        let expr = try #require(FTS5InlineQueryParser.parse("NEAR(military europe, 30)",
                                                            columnPrefix: "{body}:"))
        #expect(expr == "{body}:NEAR(\"military\" \"europe\", 30)")
        #expect(try execute(expr, corpus: Self.nearCorpus) == 4)
    }

    @Test("A malformed NEAR renders nothing at all — never invalid FTS5, never a different search")
    func malformedNearsRefuseRatherThanRender() throws {
        // The old contract was "always render something executable", and these eight queries
        // proved the fallback was not itself a syntax error. #1304 replaces the contract: the
        // right answer is to render NOTHING and say why. The property that survives is the one
        // that mattered — the parser never emits invalid FTS5 — so each is checked to be nil,
        // and the `= nil` is what makes that unambiguous rather than untested.
        for query in ["NEAR(military OR europe, 5)", "NEAR(military NOT europe, 5)",
                      "NEAR(military -europe, 5)", "NEAR((military europe), 5)",
                      "NEAR(military europe, -1)", "NEAR(military europe, 3.5)",
                      "NEAR(military europe, x)", "NEAR/5(military europe, 30)"] {
            #expect(FTS5InlineQueryParser.parse(query) == nil, "\(query) should be refused")
            #expect(FTS5InlineQueryParser.parseDetailed(query).malformedProximity != nil, "\(query)")
        }
        // And the well-formed neighbour still executes against a real FTS5 table.
        #expect(try runMatch("NEAR(military europe, 30)", corpus: Self.nearCorpus) == 4)
    }
}

// MARK: - Exact-word sigil (Q-3b)

/// The `=` sigil: parsing, and what it reports to the SQL layer.
///
/// The sigil is per-term rather than a global mode because real queries mix — you want
/// `containment` exact but `polic*` stemmed in the same expression, and a global toggle
/// forces an all-or-nothing choice the research does not have.
///
/// Version history:
///   1.0 — Q-3b: initial implementation
///   1.1 — #1297 round-1 fixes: parser 6.3 reports an `=` term only when every match must contain it (its operand is in
///          the root expression's proof "required" set), because the SQL layer ANDs one exact-word filter per term. So
///          `=containment OR =rollback` and `(=containment OR rollback) AND europe` report nothing, where 1.0 pinned
///          both terms and `containment`; the several-terms and inside-a-group tests now pin a conjunction beside them
///   1.2 — #1297 round-2 parser fixes: parser 6.4 decides per operand (`ParsedOperand.isExactApplied`), so
///          `(=containment OR rollback) containment` reports nothing, and in `(=containment OR rollback) =containment`
///          only the second operand's mark applies
///   1.3 — #1297 round-3 parser tests: D4 — a word marked in every alternative is one every match holds literally, so
///          `(=containment doctrine) OR (=containment policy)`, `=containment OR =containment rollback` and
///          `=containment OR =containment` report it, while an unmarked, quoted or excluded occurrence in one alternative
///          still makes no mark apply; once a word's mark applies it applies to every positive `=` operand on the word, so
///          `(=containment OR rollback) =containment` tags both; and the order of several terms is pinned (round-2 M20)
///   1.4 — #1297 round-4 parser tests: marks are compared by index word, not spelling (Q1) —
///          `=cold. war OR =cold peace` and `(=café OR war) =cafe` apply every mark, and `=Soviet =soviet` and
///          `=Cold war OR =cold peace` report the first spelling once; a demoted operator word never makes a mark
///          apply, in either scope (the round-3 attack's D01); the order of a word whose first mark is excluded (D10);
///          and the order test no longer claims to pin round-2 M20, which D4 made an equivalent mutant
@Suite("Exact-word sigil")
struct FTS5ExactSigilTests {

    @Test("An exact term still renders as an ordinary stemmed operand")
    func exactStillRendersStemmed() {
        // FTS5 cannot express "this literal word" over a stemmed index. The expression
        // narrows to the superset; the reported term narrows the rest of the way in SQL.
        // If this rendered anything else, the post-filter would have nothing to filter.
        let parsed = FTS5InlineQueryParser.parseDetailed("=\"containment\"")
        #expect(parsed.expression == "\"containment\"")
        #expect(parsed.exactTerms == ["containment"])
    }

    @Test("The bare and quoted spellings agree")
    func bareAndQuotedAgree() {
        #expect(FTS5InlineQueryParser.parseDetailed("=containment")
                == FTS5InlineQueryParser.parseDetailed("=\"containment\""))
    }

    @Test("Exact and stemmed terms mix in one query")
    func exactMixesWithStemmed() {
        let parsed = FTS5InlineQueryParser.parseDetailed("=containment polic* europe")
        #expect(parsed.expression == "\"containment\" AND \"polic\"* AND \"europe\"")
        #expect(parsed.exactTerms == ["containment"], "only the marked term is exact")
    }

    @Test("Several exact terms every match requires are all reported, in order, de-duplicated")
    func severalExactTerms() {
        let parsed = FTS5InlineQueryParser.parseDetailed("=containment =rollback")
        #expect(parsed.exactTerms == ["containment", "rollback"])
        #expect(FTS5InlineQueryParser.parseDetailed("=containment =containment").exactTerms
                == ["containment"])
        // Alternatives: a rollback document without containment matches, and one filter per term would remove it.
        #expect(FTS5InlineQueryParser.parseDetailed("=containment OR =rollback").exactTerms.isEmpty)
    }

    /// The order is the order of each word's first applied operand, never of its last, never a set's, and never of a
    /// mark the expression excludes. Round-2 M20 — the order of each word's first POSITIVE mark — is no longer a mutant
    /// this can catch: under D4 every positive mark on an applied word applies, so the two orders are the same.
    @Test("Several exact terms are reported in the order their words' first applied operands were typed")
    func exactTermsFollowTheFirstAppliedOperand() {
        // containment's first operand is one alternative, yet its mark applies (D4), so containment comes first.
        let first = FTS5InlineQueryParser.parseDetailed("(=containment OR europe) =rollback =containment")
        #expect(first.exactTerms == ["containment", "rollback"])
        #expect(first.operands.map(\.isExactApplied) == [true, false, true, true])
        let second = FTS5InlineQueryParser.parseDetailed("=rollback (=containment OR europe) =containment")
        #expect(second.exactTerms == ["rollback", "containment"])
        #expect(second.operands.map(\.isExactApplied) == [true, true, false, true])
        // rollback is marked first inside the excluded group, which is never applied, so containment still comes first
        // (the round-3 attack's D10: ordering by each word's first mark of either polarity reversed these).
        let excludedFirst = FTS5InlineQueryParser.parseDetailed("-(=rollback europe) =containment =rollback")
        #expect(excludedFirst.exactTerms == ["containment", "rollback"])
        #expect(excludedFirst.operands.map(\.isExactApplied) == [false, false, true, true])
    }

    /// Once a word's mark applies it applies to every positive `=` operand on that word, and an unmarked operand with the
    /// same word never makes a mark apply (D4).
    @Test("A mark applies to every marked operand of a word every match holds literally, never through an unmarked operand with its word")
    func exactAppliesPerOperand() {
        let parsed = FTS5InlineQueryParser.parseDetailed("(=containment OR rollback) =containment")
        #expect(parsed.exactTerms == ["containment"])
        #expect(parsed.operands.map(\.isExactApplied) == [true, false, true],
                "every match holds the literal word through the second =containment, so the first reads the same filtered")
        // Every match holds containment by stem, through the unmarked word, and none need hold it literally.
        let unmarked = FTS5InlineQueryParser.parseDetailed("(=containment OR rollback) containment")
        #expect(unmarked.exactTerms.isEmpty)
        #expect(unmarked.operands.map(\.isExact) == [true, false, false])
        #expect(unmarked.operands.allSatisfy { !$0.isExactApplied })
    }

    /// D4: a word marked in every alternative is a word every match holds literally, whichever alternative matched.
    @Test("A word marked with = in every alternative is reported, and one alternative without its mark reports nothing")
    func exactMarkedInEveryAlternative() {
        let grouped = FTS5InlineQueryParser.parseDetailed("(=containment doctrine) OR (=containment policy)")
        #expect(grouped.expression == "(\"containment\" AND \"doctrine\") OR (\"containment\" AND \"policy\")")
        #expect(grouped.exactTerms == ["containment"])
        #expect(grouped.operands.map(\.isExactApplied) == [true, false, true, false])
        #expect(FTS5InlineQueryParser.parseDetailed("=containment OR =containment rollback").exactTerms == ["containment"])
        #expect(FTS5InlineQueryParser.parseDetailed("=containment OR =containment").exactTerms == ["containment"])
        // An alternative holding the word unmarked, quoted, or excluded admits a document without the literal word, and
        // so does one holding it as a demoted operator word: `=not OR cold NOT` renders `"not" OR "cold" AND "not"`,
        // which matches `memo cold nots` through the stem (the round-3 attack's D01).
        for query in ["=containment rollback OR containment policy", "=containment OR \"containment\"",
                      "=containment rollback OR policy -=containment", "=containment OR containment*",
                      "=not OR cold NOT", "=and OR cold AND"] {
            for prefix in ["", "{body_text}:"] {
                let parsed = FTS5InlineQueryParser.parseDetailed(query, columnPrefix: prefix)
                #expect(parsed.expression != nil, "\(query) \(prefix)")
                #expect(parsed.exactTerms.isEmpty, "\(query) \(prefix)")
                #expect(parsed.operands.allSatisfy { !$0.isExactApplied }, "\(query) \(prefix)")
            }
        }
        // The demoted word is really there, beside the marked one: the mark is ignored, not the query.
        #expect(FTS5InlineQueryParser.parseDetailed("=not OR cold NOT").expression == "\"not\" OR \"cold\" AND \"not\"")
        #expect(FTS5InlineQueryParser.parseDetailed("=not OR cold NOT").operands.map(\.isExact) == [true, false])
    }

    /// The filter compares index words — case, diacritics and punctuation beside the word folded, as `unicode61` and
    /// `ExactWordMatcher` fold them — so marks on one word are one word however each was spelled (Q1).
    @Test("Marks on one index word are one word whatever their spelling, and the first spelling is the term reported")
    func exactMarksCompareIndexWords() {
        for prefix in ["", "{body_text}:"] {
            // Punctuation beside the word: `"cold."` is the index word cold, so cold is marked in every alternative.
            let punctuated = FTS5InlineQueryParser.parseDetailed("=cold. war OR =cold peace", columnPrefix: prefix)
            #expect(punctuated.exactTerms == ["cold."], "\(prefix)")
            #expect(punctuated.operands.map(\.isExactApplied) == [true, false, true, false], "\(prefix)")
            // A diacritic: café and cafe are one index word, so the first mark applies with the second.
            let accented = FTS5InlineQueryParser.parseDetailed("(=café OR war) =cafe", columnPrefix: prefix)
            #expect(accented.exactTerms == ["café"], "\(prefix)")
            #expect(accented.operands.map(\.isExactApplied) == [true, false, true], "\(prefix)")
            // Case: one word, reported once, in the spelling first applied.
            let capitalised = FTS5InlineQueryParser.parseDetailed("=Cold war OR =cold peace", columnPrefix: prefix)
            #expect(capitalised.exactTerms == ["Cold"], "\(prefix)")
            #expect(capitalised.operands.map(\.isExactApplied) == [true, false, true, false], "\(prefix)")
            #expect(FTS5InlineQueryParser.parseDetailed("=Soviet =soviet", columnPrefix: prefix).exactTerms == ["Soviet"])
            #expect(FTS5InlineQueryParser.parseDetailed("=Containment", columnPrefix: prefix).exactTerms == ["Containment"])
            let alternatives = FTS5InlineQueryParser.parseDetailed("=Containment doctrine OR =containment policy", columnPrefix: prefix)
            #expect(alternatives.exactTerms == ["Containment"], "\(prefix)")
            #expect(alternatives.operands.map(\.isExactApplied) == [true, false, true, false], "\(prefix)")
            // An unmarked spelling still never makes a mark apply.
            for query in ["=cold. war OR cold peace", "(=café OR war) cafe", "=Cold war OR cold. peace"] {
                let parsed = FTS5InlineQueryParser.parseDetailed(query, columnPrefix: prefix)
                #expect(parsed.exactTerms.isEmpty, "\(query) \(prefix)")
                #expect(parsed.operands.allSatisfy { !$0.isExactApplied }, "\(query) \(prefix)")
            }
        }
    }

    @Test("An exact term inside a group is reported when every match requires it, and ignored as an alternative")
    func exactInsideAGroup() {
        let required = FTS5InlineQueryParser.parseDetailed("(=containment rollback) AND europe")
        #expect(required.exactTerms == ["containment"])
        #expect(required.expression?.contains("\"containment\"") == true)
        let alternative = FTS5InlineQueryParser.parseDetailed("(=containment OR rollback) AND europe")
        #expect(alternative.exactTerms.isEmpty)
        #expect(alternative.expression == "(\"containment\" OR \"rollback\") AND \"europe\"")
    }

    @Test("A query with no sigil reports no exact terms")
    func noSigilNoTerms() {
        #expect(FTS5InlineQueryParser.parseDetailed("containment policy").exactTerms.isEmpty)
    }

    @Test("No expression means no exact terms — there is nothing to post-filter")
    func nilExpressionCarriesNoTerms() {
        // Otherwise the SQL layer would receive a filter with no MATCH to refine, and
        // would narrow the *unfiltered* corpus instead.
        let parsed = FTS5InlineQueryParser.parseDetailed("-=containment")
        #expect(parsed.expression == nil)
        #expect(parsed.exactTerms.isEmpty)
    }

    // MARK: - Where the sigil does not apply

    @Test("The sigil is ignored on a negated term rather than inverting the filter")
    func negatedExactIsIgnored() {
        // `-="word"` would need an inverted post-filter; getting that subtly wrong
        // silently over-excludes. Dropping the sigil leaves ordinary negation.
        let parsed = FTS5InlineQueryParser.parseDetailed("europe -=containment")
        #expect(parsed.expression == "\"europe\" NOT \"containment\"")
        #expect(parsed.exactTerms.isEmpty)
    }

    @Test("The sigil is ignored on a prefix wildcard, which asks for many words")
    func exactPrefixIsAContradiction() {
        let parsed = FTS5InlineQueryParser.parseDetailed("=negoti*")
        #expect(parsed.expression == "\"negoti\"*")
        #expect(parsed.exactTerms.isEmpty)
    }

    @Test("A multi-token term drops the sigil rather than filtering on a fragment")
    func multiTokenTermDropsTheSigil() {
        for raw in ["=\"co-operate\"", "=\"U.S.S.R.\"", "=co-operate"] {
            let parsed = FTS5InlineQueryParser.parseDetailed(raw)
            #expect(parsed.exactTerms.isEmpty, "\(raw) should not produce an exact filter")
            #expect(parsed.expression != nil, "\(raw) must still run as an ordinary search")
        }
    }

    @Test("A bare = is punctuation, not an operand")
    func bareSigilIsDropped() {
        #expect(FTS5InlineQueryParser.parseDetailed("= containment").exactTerms.isEmpty)
        #expect(FTS5InlineQueryParser.parse("= containment") == "\"containment\"")
    }

    @Test("parse and parseDetailed never disagree about the expression")
    func parseAgreesWithParseDetailed() {
        for raw in ["=containment", "containment", "=containment polic*", "-=containment",
                    "(=a OR b) AND c", "NEAR(=a b, 5)", "", "=\"\""] {
            #expect(FTS5InlineQueryParser.parse(raw)
                    == FTS5InlineQueryParser.parseDetailed(raw).expression,
                    "disagreement on: \(raw)")
        }
    }
}

// MARK: - Typographic Quotation Marks (#1298)

/// Curly, low-9, reversed, fullwidth and angle double quotation marks make a phrase exactly as U+0022 does (#1298).
///
/// iPadOS Smart Punctuation and macOS smart quotes type `“ ”`, and text pasted from a FRUS volume carries them, so a
/// phrase the parser read only by U+0022 silently became separate words: `“cold war”` searched both words anywhere and
/// `blockade -“naval quarantine”` excluded *naval* and required *quarantine*. The marks are spelled out here rather
/// than read from the parser, so a mark dropped from the parser's set fails these tests instead of moving with them,
/// and `foldIsExactlyTheDecidedMarksOverEveryScalar` walks every Unicode scalar, so a mark added to it fails too —
/// the fifteen listed marks alone could not see an addition from outside the list (U+301D passed every other test).
extension FTS5InlineQueryParserTests {

    /// The marks #1298 folds to U+0022, one character for one — the owner's decision of 2026-09-17.
    static let foldedQuotationMarks: [Character] = [
        "\u{201C}", // LEFT DOUBLE QUOTATION MARK
        "\u{201D}", // RIGHT DOUBLE QUOTATION MARK
        "\u{201E}", // DOUBLE LOW-9 QUOTATION MARK
        "\u{201F}", // DOUBLE HIGH-REVERSED-9 QUOTATION MARK
        "\u{FF02}", // FULLWIDTH QUOTATION MARK
        "\u{00AB}", // LEFT-POINTING DOUBLE ANGLE QUOTATION MARK
        "\u{00BB}", // RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK
    ]

    /// Marks that look like quotation marks and are NOT folded: a double prime is a unit mark (`12″ guns`), and a
    /// single mark is an apostrophe as often as a quote, which the tokenizer already splits alike.
    static let unfoldedQuotationMarks: [Character] = [
        "\u{2033}", // DOUBLE PRIME
        "\u{2018}", // LEFT SINGLE QUOTATION MARK
        "\u{2019}", // RIGHT SINGLE QUOTATION MARK
        "\u{201A}", // SINGLE LOW-9 QUOTATION MARK
        "\u{201B}", // SINGLE HIGH-REVERSED-9 QUOTATION MARK
        "\u{0027}", // APOSTROPHE
        "\u{2039}", // SINGLE LEFT-POINTING ANGLE QUOTATION MARK
        "\u{203A}", // SINGLE RIGHT-POINTING ANGLE QUOTATION MARK
    ]

    /// Rows the #1298 renders are counted on: the issue's four blockade rows, and rows telling a phrase from its words.
    static let quotationCorpus: [String] = [
        "blockade only",
        "blockade and a naval patrol",
        "blockade and quarantine",
        "blockade naval quarantine",
        "the cold war began",
        "war turned cold",
        "war and peace",
        "peace after war",
        "the military guarantee finally extended to europe in 1948",
        "guarantee military europe",
        "twelve 12 guns were mounted",
        "don't go",
        "Kennedy's policy",
        "cold snap",
        "detente",
    ]

    /// `text` with its U+0022 marks replaced alternately by `open` and `close`, as a typed or pasted pair arrives.
    private func respelling(_ text: String, open: String, close: String) -> String {
        var isOpen = true
        var out = ""
        for character in text {
            if character == "\"" {
                out += isOpen ? open : close
                isOpen.toggle()
            } else {
                out.append(character)
            }
        }
        return out
    }

    @Test("The shared fold maps exactly the decided marks to U+0022, one character for one, and its predicate agrees")
    func sharedFoldCoversExactlyTheDecidedMarks() {
        #expect(FTS5InlineQueryParser.isDoubleQuotationMark("\""))
        #expect(FTS5InlineQueryParser.normalizingQuotationMarks("\"") == "\"")
        for mark in Self.foldedQuotationMarks {
            #expect(FTS5InlineQueryParser.isDoubleQuotationMark(mark), "\(mark)")
            #expect(FTS5InlineQueryParser.normalizingQuotationMarks("a\(mark)b \(mark)") == "a\"b \"", "\(mark)")
        }
        for mark in Self.unfoldedQuotationMarks {
            #expect(!FTS5InlineQueryParser.isDoubleQuotationMark(mark), "\(mark)")
            #expect(FTS5InlineQueryParser.normalizingQuotationMarks("a\(mark)b \(mark)") == "a\(mark)b \(mark)", "\(mark)")
        }
        // Every other character is left alone, the count of characters never changes, and a mark carrying a combining
        // character is not a mark — as U+0022 carrying one is not.
        let text = "\u{201C}Diệm\u{201D} — 12\u{2033}, don\u{2019}t, \u{2039}x\u{203A} \u{201C}\u{0301}"
        let folded = FTS5InlineQueryParser.normalizingQuotationMarks(text)
        #expect(folded == "\"Diệm\" — 12\u{2033}, don\u{2019}t, \u{2039}x\u{203A} \u{201C}\u{0301}")
        #expect(folded.count == text.count)
        // Bound first: `#expect` cannot expand a literal holding a quote followed by a combining character.
        let markedCurly: Character = "\u{201C}\u{0301}", markedStraight: Character = "\"\u{0301}"
        #expect(!FTS5InlineQueryParser.isDoubleQuotationMark(markedCurly))
        #expect(!FTS5InlineQueryParser.isDoubleQuotationMark(markedStraight))
        #expect(FTS5InlineQueryParser.normalizingQuotationMarks("cold war") == "cold war")
    }

    /// The "exactly" half of the decided set, over the whole code space rather than a list: every scalar from U+0000
    /// to U+10FFFF (the 2,048 surrogates are not scalars) is taken as a one-scalar character, and the predicate must be
    /// true for U+0022 and the seven folded marks and for nothing else, while the fold must change those seven and
    /// nothing else. The listed-mark test above cannot fail when a mark outside its fifteen is added — U+301D `〝`,
    /// U+2036 `‶` or U+275D `❝` added to the parser's set passed it, and parsed `〝cold war〝` as a phrase.
    @Test("Over every Unicode scalar, the predicate holds for U+0022 and the seven folded marks and the fold changes only the seven")
    func foldIsExactlyTheDecidedMarksOverEveryScalar() {
        var predicateHolds: [UInt32] = []
        var foldChanges: [UInt32] = []
        var foldsToStraight: [UInt32] = []
        var walked = 0
        for value in UInt32(0)...0x10FFFF {
            guard let scalar = Unicode.Scalar(value) else { continue }
            walked += 1
            let character = Character(scalar)
            if FTS5InlineQueryParser.isDoubleQuotationMark(character) { predicateHolds.append(value) }
            let text = String(character)
            let folded = FTS5InlineQueryParser.normalizingQuotationMarks(text)
            if folded != text {
                foldChanges.append(value)
                if folded == "\"" { foldsToStraight.append(value) }
            }
        }
        // 0x110000 code points less the 0x800 surrogates: the walk reached every scalar there is.
        #expect(walked == 1_112_064)
        let folded = Self.foldedQuotationMarks.map { $0.unicodeScalars.first!.value }.sorted()
        #expect(folded == [0x00AB, 0x00BB, 0x201C, 0x201D, 0x201E, 0x201F, 0xFF02], "the list is the owner's seven")
        #expect(predicateHolds == ([0x0022] + folded).sorted())
        #expect(foldChanges == folded)
        #expect(foldsToStraight == folded, "each folded mark becomes U+0022 and nothing else")
    }

    @Test("Every typographic spelling of a quoted query parses, renders and matches as its straight form")
    func typographicQuotesParseAsStraight() throws {
        // Each straight query with its render and row count at 55464a46, which #1298 must not move.
        let cases: [(straight: String, rendered: String, rows: Int)] = [
            ("\"cold war\"", "\"cold war\"", 1),
            ("\"war and peace\"", "\"war and peace\"", 1),
            ("blockade -\"naval quarantine\"", "\"blockade\" NOT \"naval quarantine\"", 3),
            ("NEAR(\"military guarantee\" Europe, 30)", "NEAR(\"military guarantee\" \"europe\", 30)", 1),
            ("\"cold war\" OR detente", "\"cold war\" OR \"detente\"", 2),
            ("cold -(korea OR \"naval quarantine\")", "\"cold\" NOT (\"korea\" OR \"naval quarantine\")", 3),
        ]
        // Opening and closing marks as they arrive: English, German twice, French both ways, the reversed high mark,
        // fullwidth, and both mixed spellings.
        let pairs: [(open: String, close: String)] = [
            ("\u{201C}", "\u{201D}"), ("\u{201E}", "\u{201C}"), ("\u{201E}", "\u{201D}"),
            ("\u{00AB}", "\u{00BB}"), ("\u{00BB}", "\u{00AB}"), ("\u{201F}", "\u{201D}"),
            ("\u{FF02}", "\u{FF02}"), ("\u{201C}", "\""), ("\"", "\u{201D}"),
        ]
        var compared = 0
        for c in cases {
            let straight = FTS5InlineQueryParser.parseDetailed(c.straight)
            #expect(straight.expression == c.rendered, "the straight render moved: \(c.straight)")
            #expect(try runMatch(c.straight, corpus: Self.quotationCorpus) == c.rows)
            for pair in pairs {
                let typed = respelling(c.straight, open: pair.open, close: pair.close)
                #expect(typed != c.straight)
                let parsed = FTS5InlineQueryParser.parseDetailed(typed)
                #expect(parsed == straight, "\(typed) parsed differently from \(c.straight)")
                #expect(parsed.expression == c.rendered, "\(typed)")
                #expect(try runMatch(typed, corpus: Self.quotationCorpus) == c.rows, "\(typed)")
                compared += 1
            }
        }
        #expect(compared == 54)
    }

    @Test("A typographic phrase is one phrase operand, negated where its dash says so")
    func typographicPhraseIsOnePhraseOperand() {
        let parsed = FTS5InlineQueryParser.parseDetailed(
            "blockade -\u{201C}naval quarantine\u{201D} \u{201C}cold war\u{201D}")
        #expect(parsed.operands.map(\.kind) == [.word, .phrase, .phrase])
        #expect(parsed.operands.map(\.text) == ["blockade", "naval quarantine", "cold war"])
        #expect(parsed.operands.map(\.isNegated) == [false, true, false])
        #expect(parsed.expression == "\"blockade\" NOT \"naval quarantine\" AND \"cold war\"")

        for typed in ["\u{00AB}cold war\u{00BB}", "\u{201E}cold war\u{201C}", "\u{FF02}cold war\u{FF02}",
                      "\u{201F}cold war\u{201D}", "\u{00BB}cold war\u{00AB}"] {
            let operands = FTS5InlineQueryParser.parseDetailed(typed).operands
            #expect(operands.map(\.kind) == [.phrase], "\(typed)")
            #expect(operands.map(\.text) == ["cold war"], "\(typed)")
        }
    }

    @Test("A typographic negated phrase on its own is refused, as its straight form is")
    func typographicNegatedPhraseAloneIsRefused() {
        let straight = FTS5InlineQueryParser.parseDetailed("-\"naval quarantine\"")
        #expect(straight == ParsedQuery(expression: nil, exactTerms: []))
        for (open, close) in [("\u{201C}", "\u{201D}"), ("\u{00AB}", "\u{00BB}"), ("\u{201E}", "\u{201C}"),
                              ("\u{FF02}", "\u{FF02}")] {
            // At 55464a46 the curly form ran `"quarantine”" NOT "“naval"`: the exclusion anchored on its own last word.
            #expect(FTS5InlineQueryParser.parseDetailed("-\(open)naval quarantine\(close)") == straight)
        }
    }

    @Test("An = before typographic quotes unwraps them as it unwraps straight ones")
    func exactSigilUnwrapsTypographicQuotes() {
        let straight = FTS5InlineQueryParser.parseDetailed("=\"containment\" europe")
        #expect(straight.exactTerms == ["containment"])
        #expect(FTS5InlineQueryParser.parseDetailed("=\u{201C}containment\u{201D} europe") == straight)
        #expect(FTS5InlineQueryParser.parseDetailed("=\u{00AB}containment\u{00BB} europe") == straight)
    }

    @Test("NEAR keeps its distance beside a typographic phrase, and a comma inside the marks is not the separator")
    func nearWithTypographicPhrase() throws {
        let (open, close) = ("\u{201C}", "\u{201D}")
        // The corpus row puts three tokens between the phrase and europe, so 3 matches and 2 does not.
        #expect(FTS5InlineQueryParser.parse("NEAR(\(open)military guarantee\(close) europe, 3)")
                == "NEAR(\"military guarantee\" \"europe\", 3)")
        #expect(try runMatch("NEAR(\(open)military guarantee\(close) europe, 3)", corpus: Self.quotationCorpus) == 1)
        #expect(try runMatch("NEAR(\(open)military guarantee\(close) europe, 2)", corpus: Self.quotationCorpus) == 0)

        #expect(FTS5InlineQueryParser.parse("NEAR(\(open)cold, war\(close) europe, 5)")
                == "NEAR(\"cold, war\" \"europe\", 5)")
        // With no distance the comma inside the marks must not be taken for one: at 55464a46 it was, the distance
        // `war” europe` failed to parse, and the NEAR degraded to a boolean group.
        #expect(FTS5InlineQueryParser.parse("NEAR(\"cold, war\" europe)") == "NEAR(\"cold, war\" \"europe\", 10)")
        #expect(FTS5InlineQueryParser.parse("NEAR(\(open)cold, war\(close) europe)")
                == "NEAR(\"cold, war\" \"europe\", 10)")
        #expect(FTS5InlineQueryParser.parse("NEAR(\u{00AB}cold, war\u{00BB} europe)")
                == "NEAR(\"cold, war\" \"europe\", 10)")
    }

    @Test("Double primes and single marks are not quotation marks: 12″, don’t, Kennedy’s, ‹cold› and ‘cold’ are unchanged")
    func primesAndSingleMarksAreNotFolded() throws {
        // A double prime is a unit mark. `12″` sanitises to nothing, where `12"` keeps the number, and inside a NEAR it
        // opens no phrase, so the distance survives.
        #expect(FTS5InlineQueryParser.parse("12\u{2033} guns") == "\"guns\"")
        #expect(FTS5InlineQueryParser.parse("12\" guns") == "\"12\" AND \"guns\"")
        #expect(FTS5InlineQueryParser.parse("NEAR(12\u{2033} guns, 5)") == "NEAR(\"guns\", 5)")
        #expect(FTS5InlineQueryParser.parse("\u{2033}cold war\u{2033}") == "\"\u{2033}cold\" AND \"war\u{2033}\"")

        // An apostrophe in either spelling is one word the tokenizer splits alike.
        #expect(FTS5InlineQueryParser.parse("don\u{2019}t") == "\"don\u{2019}t\"")
        #expect(try runMatch("don\u{2019}t", corpus: Self.quotationCorpus) == runMatch("don't", corpus: Self.quotationCorpus))
        #expect(FTS5InlineQueryParser.parse("Kennedy\u{2019}s policy") == "\"kennedy\u{2019}s\" AND \"policy\"")
        #expect(try runMatch("Kennedy\u{2019}s policy", corpus: Self.quotationCorpus) == 1)

        for typed in ["\u{2039}cold\u{203A}", "\u{2018}cold\u{2019}", "\u{201A}cold\u{201B}", "'cold'"] {
            let parsed = FTS5InlineQueryParser.parseDetailed(typed)
            #expect(parsed.operands.map(\.kind) == [.word], "\(typed)")
            #expect(parsed.expression == "\"\(typed)\"", "\(typed)")
        }
    }

    @Test("A restored phrase, prefix or excluded term spelled with typographic marks parses as its straight spelling")
    func typographicStructuredPartsParseAsStraight() {
        let (open, close) = ("\u{201C}", "\u{201D}")
        let pairs: [(typographic: StructuredQueryParts, straight: StructuredQueryParts)] = [
            (StructuredQueryParts(phrase: "\(open)cold war\(close)"), StructuredQueryParts(phrase: "\"cold war\"")),
            (StructuredQueryParts(prefixWildcard: "\u{00AB}negoti\u{00BB}"), StructuredQueryParts(prefixWildcard: "\"negoti\"")),
            (StructuredQueryParts(excludedTerms: ["\u{201E}korea\u{201C}"]), StructuredQueryParts(excludedTerms: ["\"korea\""])),
        ]
        var compared = 0
        for pair in pairs {
            for typed in ["", "cold", "-(war -korea)", "cold OR -korea"] {
                for prefix in ["", "{body_text}:"] {
                    #expect(FTS5InlineQueryParser.parseDetailed(typed, columnPrefix: prefix, structured: pair.typographic)
                            == FTS5InlineQueryParser.parseDetailed(typed, columnPrefix: prefix, structured: pair.straight),
                            "\(typed) beside \(pair.typographic)")
                    compared += 1
                }
            }
        }
        #expect(compared == 24)
        // The refusal compares rendered operands, so a curly excluded term that rendered `"„korea“"` was not the korea
        // the approximation anchors on, and a search that can match nothing ran.
        #expect(FTS5InlineQueryParser.parse("-(war -korea)", structured: StructuredQueryParts(excludedTerms: ["\"korea\""])) == nil)
        #expect(FTS5InlineQueryParser.parse("-(war -korea)", structured: pairs[2].typographic) == nil)
        #expect(FTS5InlineQueryParser.parseDetailed("", structured: pairs[0].typographic).operands.map(\.text) == ["cold war"])
    }

    @Test("FTS5Query sanitises a typographic mark in a keyword or a field as it sanitises a straight one")
    func ftsQueryFoldsTypographicMarks() {
        let keywordsOnly = FTS5Query(keywords: ["\u{201C}cold", "war\u{201D}"])
        let straightKeywords = FTS5Query(keywords: ["\"cold", "war\""])
        #expect(straightKeywords.toFTS5MatchExpression() == "\"cold\" \"war\"")
        #expect(keywordsOnly.toFTS5MatchExpression() == straightKeywords.toFTS5MatchExpression())

        let fields = FTS5Query(keywords: ["containment"], phrase: "\u{201E}iron curtain\u{201C}",
                               excludedTerms: ["\u{00AB}korea\u{00BB}"], prefixWildcard: "\u{FF02}negoti\u{FF02}")
        let straightFields = FTS5Query(keywords: ["containment"], phrase: "\"iron curtain\"",
                                       excludedTerms: ["\"korea\""], prefixWildcard: "\"negoti\"")
        #expect(straightFields.toFTS5MatchExpression()
                == "(\"containment\" AND \"iron curtain\" AND \"negoti\"*) NOT \"korea\"")
        #expect(fields.toFTS5MatchExpression() == straightFields.toFTS5MatchExpression())
    }

    /// The equivalence #1298 promises, swept rather than sampled: over every sequence of one to four units from an
    /// alphabet holding a quote slot `Q`, a phrase, an attached dash, an `=`, groups, `OR`, a comma and a `NEAR` whose
    /// phrase holds its own comma, the text with `Q` spelled as any folded mark — or with folded marks and U+0022 mixed —
    /// parses to exactly the `ParsedQuery` of the text spelled with U+0022. And every unfolded mark parses differently
    /// from U+0022 somewhere in the sequences of up to three units, so none of them is folded; that half stops at three
    /// only to keep the sweep's time down, since one differing sequence is all it needs.
    @Test("Over every short sequence, each folded mark parses as U+0022, mixed or not, and no unfolded mark does")
    func quotationMarkSweep() {
        let units = ["cold", " ", "-", "=", "(", ")", ",", "OR", "Q", "Qcold warQ",
                     "NEAR(Qmilitary, guaranteeQ europe, 30)"]
        func spelled(_ text: String, _ slots: (Int) -> String) -> String {
            var out = ""
            var slot = 0
            for character in text {
                if character == "Q" { out += slots(slot); slot += 1 } else { out.append(character) }
            }
            return out
        }

        var sequences = 0, withSlot = 0, shortWithSlot = 0, foldedCompared = 0, mixedCompared = 0
        var failures: [String] = []
        var differsFromStraight = [Int](repeating: 0, count: Self.unfoldedQuotationMarks.count)
        var phrases = 0, negatedPhrases = 0, exactUnwrapped = 0, nearPhrases = 0, unterminated = 0, refused = 0

        var indices: [Int] = []
        func visit() {
            if !indices.isEmpty {
                sequences += 1
                let text = indices.map { units[$0] }.joined()
                let slotCount = text.filter { $0 == "Q" }.count
                if slotCount > 0 {
                    withSlot += 1
                    let straightText = spelled(text) { _ in "\"" }
                    let straight = FTS5InlineQueryParser.parseDetailed(straightText)

                    for mark in Self.foldedQuotationMarks {
                        let typed = spelled(text) { _ in String(mark) }
                        if FTS5InlineQueryParser.parseDetailed(typed) != straight, failures.count < 20 {
                            failures.append(typed)
                        }
                        foldedCompared += 1
                        if slotCount > 1 {
                            for parity in 0...1 {
                                let mixed = spelled(text) { $0 % 2 == parity ? String(mark) : "\"" }
                                if FTS5InlineQueryParser.parseDetailed(mixed) != straight, failures.count < 20 {
                                    failures.append(mixed)
                                }
                                mixedCompared += 1
                            }
                        }
                    }
                    if indices.count < 4 { shortWithSlot += 1 }
                    for (index, mark) in Self.unfoldedQuotationMarks.enumerated() where indices.count < 4
                    && FTS5InlineQueryParser.parseDetailed(spelled(text) { _ in String(mark) }) != straight {
                        differsFromStraight[index] += 1
                    }

                    // What the straight spelling exercised, so a branch the alphabet stopped reaching fails here.
                    if straight.operands.contains(where: { $0.kind == .phrase && !$0.isNegated }) { phrases += 1 }
                    if straight.operands.contains(where: { $0.kind == .phrase && $0.isNegated }) { negatedPhrases += 1 }
                    if straightText.contains("=\""), straight.operands.contains(where: { $0.isExact && $0.kind == .word }) {
                        exactUnwrapped += 1
                    }
                    if straight.operands.contains(where: {
                        $0.kind == .proximity && $0.rendered.contains("\"military, guarantee\"") && $0.rendered.hasSuffix(", 30)")
                    }) { nearPhrases += 1 }
                    if slotCount % 2 == 1, straight.operands.contains(where: { $0.kind == .phrase }) { unterminated += 1 }
                    if straight.expression == nil { refused += 1 }
                }
            }
            guard indices.count < 4 else { return }
            for unit in units.indices {
                indices.append(unit)
                visit()
                indices.removeLast()
            }
        }
        visit()

        print("[#1298 sweep] sequences \(sequences), with a quote slot \(withSlot), folded compared \(foldedCompared), "
              + "mixed compared \(mixedCompared); straight spelling: phrase \(phrases), negated phrase \(negatedPhrases), "
              + "= unwrapped \(exactUnwrapped), NEAR phrase with comma \(nearPhrases), unterminated \(unterminated), "
              + "refused \(refused); unfolded marks differing from U+0022 \(differsFromStraight) of \(shortWithSlot)")
        #expect(sequences == 16_104)
        #expect(failures.isEmpty, "folded spellings that parsed differently from U+0022: \(failures)")
        #expect(foldedCompared == withSlot * Self.foldedQuotationMarks.count)
        #expect(mixedCompared > 0)
        #expect(phrases > 0 && negatedPhrases > 0 && exactUnwrapped > 0 && nearPhrases > 0 && unterminated > 0
                && refused > 0)
        for (index, count) in differsFromStraight.enumerated() {
            let scalars = Self.unfoldedQuotationMarks[index].unicodeScalars.map { String($0.value, radix: 16, uppercase: true) }
            #expect(count > 0, "U+\(scalars.joined()) parsed as U+0022 in every sequence, as a folded mark would")
        }
    }
}
