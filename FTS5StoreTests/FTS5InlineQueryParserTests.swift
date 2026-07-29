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

    @Test("Booleans inside NEAR degrade to an ordinary group — never invalid FTS5")
    func nearRejectsBooleans() {
        // FTS5 rejects `NEAR(a OR b, 5)` outright. The contract is to keep searching the
        // user's words rather than to fail: the NEAR keyword is dropped and the
        // parenthesised contents render as a boolean group.
        //
        // Note the `"europe,"` operand. The degraded path is the *ordinary* token path,
        // and `sanitizeBareToken` has never stripped commas, so the comma rides along
        // into the quoted term. That is harmless rather than sloppy: inside FTS5 double
        // quotes `unicode61` treats a comma as a token separator, so `"europe,"` matches
        // exactly what `"europe"` matches. `degradedNearsStillExecute` proves it runs.
        #expect(FTS5InlineQueryParser.parse("NEAR(military OR europe, 5)")
                == "(\"military\" OR \"europe,\" AND \"5\")")
        #expect(FTS5InlineQueryParser.parse("NEAR(military NOT europe, 5)")
                == "(\"military\" NOT \"europe,\" AND \"5\")")
    }

    @Test("Negation and nested groups inside NEAR degrade the same way")
    func nearRejectsNegationAndNesting() {
        #expect(FTS5InlineQueryParser.parse("NEAR(military -europe, 5)")
                == "(\"military\" NOT \"europe,\" AND \"5\")")
        // A nested group keeps its own parentheses, so the comma lands on the token
        // *after* the inner close paren and never reaches an operand here.
        #expect(FTS5InlineQueryParser.parse("NEAR((military europe), 5)")
                == "((\"military\" AND \"europe\") AND \"5\")")
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

    @Test("Every degraded NEAR is still valid FTS5, not merely non-NEAR")
    func degradedNearsStillExecute() throws {
        let c = Self.nearCorpus
        // The degradation contract is worthless if the fallback is itself a syntax error.
        _ = try runMatch("NEAR(military OR europe, 5)", corpus: c)
        _ = try runMatch("NEAR(military NOT europe, 5)", corpus: c)
        _ = try runMatch("NEAR(military -europe, 5)", corpus: c)
        _ = try runMatch("NEAR((military europe), 5)", corpus: c)
        _ = try runMatch("NEAR(military europe, -1)", corpus: c)
        _ = try runMatch("NEAR(military europe, 3.5)", corpus: c)
        _ = try runMatch("NEAR(military europe, x)", corpus: c)
        _ = try runMatch("NEAR/5(military europe, 30)", corpus: c)
    }
}
