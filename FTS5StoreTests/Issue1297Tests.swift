// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import Testing
import SQLite3
@testable import FTS5Store

// MARK: - #1297: exclusions FTS5 rejected
//
// An exclusion typed first in its AND-run (`-korea cold`) or right after a typed `AND`/`OR`
// (`cold AND -korea`) used to render a `NOT` with no left operand, which FTS5 rejects: the
// search failed outright. These tests pin the owner's decided semantics for the tree-based
// renderer, and every one of them EXECUTES its render against a real FTS5 table, because a
// string that looks right can still be a syntax error or match the wrong documents.

// MARK: - Truth-table corpus

/// The corpus every #1297 test executes against, built so a wrong exclusion cannot hide.
///
/// Rows 1...16 are every subset of {cold, war, korea, vietnam} after "memo" (rowid = mask + 1:
/// bit 0 cold, bit 1 war, bit 2 korea, bit 3 vietnam), so every boolean combination of the four
/// words selects its own row set. The two-document corpus the older parser tests use cannot
/// tell a correct exclusion from no match at all. Rows 17–19 hold the literal words "and",
/// "or" and "not", so a render that silently requires one of them is visible; row 20 holds the
/// phrase "naval quarantine" and row 21 "blockade" alone.
///
/// Version history:
///   1.0 — #1297: initial implementation — the judged design's tests, plus the owner's
///          attached-dash decision (`-(X)` parses as `NOT (X)`), its invariant, and oracle,
///          validity and permutation runs that exercise `-(`
///   1.1 — #1297 round-1 fixes: `Issue1297DepthTests` pins parser 6.3's refusal of groups nested deeper than
///          32 levels, on a 512 KB thread; `setOracle` checks every nil against the oracle's model (nothing
///          anchors, or 6.1's proof refuses) instead of only counting it; `runPermutationAndGrouping` counts the
///          comparisons that rendered for every unit, so a parser refusing one unit outright fails it; and the
///          two-column truth table no longer claims its constant header makes a column prefix observable
///   1.2 — #1297 round-2 parser tests: `Issue1297DepthTests` nests `-(a OR -b …)` around the exclusion `-korea`, which
///          leaves every level a complement to push inward (P3); refuses each one-level-deeper query beside shallow
///          groups and an unmatched `)`, and each 5,000-level query beside them and after 5,000 unmatched `)`, since a
///          depth scan taking the last group opened, stopping at the first top-level group, or letting an unmatched `)`
///          close a level passed every earlier check (P5, the round-1 attack's D8–D10); and pins `groupDepth` directly.
///          Its doc now gives 6.2's thresholds (277 levels of `-(war …)` in Release, 22 in Debug) where it gave the
///          first sizes seen to overflow, and the stack its nestings cost at parsers 6.3 and 6.4
///   1.3 — #1297 round-3 parser fixes: `Issue1297DepthTests.nodesAreSettledOnce` counts, in a DEBUG build, how often
///          each node of a query nested to the limit has its meaning and anchor settled, because removing parser 6.4's
///          memo changed no render and failed no test (the round-2 attack's M22)
///   1.4 — #1297 round-4 parser fixes: `Issue1297DepthTests.settlementCountsAdd`, the positive control for those counts: a
///          root settled once more past the memo must read 2, because a counter saturating at 1 passed
///          `nodesAreSettledOnce` even with the memo removed (the round-3 attack's P5c)
enum Issue1297Corpus {
    /// The four query words, in bit order.
    static let vocabulary = ["cold", "war", "korea", "vietnam"]

    /// Row bodies; index 0 holds rowid 1.
    static let bodies: [String] = (0..<16).map { mask in
        (["memo"] + vocabulary.enumerated().filter { mask & (1 << $0.offset) != 0 }.map(\.element))
            .joined(separator: " ")
    } + ["memo and", "memo or", "memo not", "memo naval quarantine blockade", "memo blockade"]

    /// Every rowid in the corpus.
    static let all = Set(1...bodies.count)

    /// The rows containing cold.
    static let coldRows = [2, 4, 6, 8, 10, 12, 14, 16]

    /// The rows containing cold but not korea.
    static let coldNotKorea = [2, 4, 10, 12]

    /// The rows matching (cold AND NOT korea) OR war.
    static let coldNotKoreaOrWar = [2, 3, 4, 7, 8, 10, 11, 12, 15, 16]

    /// The rows whose body contains `word` as a whole word.
    static func rows(with word: String) -> Set<Int> {
        Set(bodies.indices.filter { bodies[$0].split(separator: " ").contains(Substring(word)) }.map { $0 + 1 })
    }
}

/// A MATCH expression SQLite refused.
enum Issue1297MatchFailure: Error {
    /// SQLite rejected `expression` with `message`.
    case sqlite(expression: String, message: String)
}

/// An in-memory `porter unicode61` FTS5 table over `Issue1297Corpus`, queried for rowids.
final class Issue1297TruthTable {
    /// The open database handle.
    private var db: OpaquePointer?
    /// The FTS5 table's name: `d` for one column, `d2` for header + body.
    private let name: String

    /// Creates and seeds the table. The two-column form gives a column prefix a column to name, but its header is
    /// the constant 'heading', which holds no query word: a render that lost its prefix matches the same rows here.
    /// `Issue1297StructuredPartsTests.columnPrefixScopesEveryTypedOperand` is the check that a prefix scopes.
    init(twoColumn: Bool = false) {
        sqlite3_open(":memory:", &db)
        name = twoColumn ? "d2" : "d"
        sqlite3_exec(db, twoColumn
            ? "CREATE VIRTUAL TABLE d2 USING fts5(header, body, tokenize='porter unicode61');"
            : "CREATE VIRTUAL TABLE d USING fts5(body, tokenize='porter unicode61');", nil, nil, nil)
        for (index, body) in Issue1297Corpus.bodies.enumerated() {
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, twoColumn
                ? "INSERT INTO d2(rowid, header, body) VALUES (?, 'heading', ?);"
                : "INSERT INTO d(rowid, body) VALUES (?, ?);", -1, &stmt, nil)
            sqlite3_bind_int(stmt, 1, Int32(index + 1))
            sqlite3_bind_text(stmt, 2, body, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
    }

    deinit { sqlite3_close(db) }

    /// The matching rowids in order. Throws when SQLite rejects the expression — FTS5 reports
    /// syntax errors when the statement steps, not when it is prepared.
    func rows(_ expression: String) throws -> [Int] {
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "SELECT rowid FROM \(name) WHERE \(name) MATCH ? ORDER BY rowid;", -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, expression, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        var out: [Int] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_ROW { out.append(Int(sqlite3_column_int64(stmt, 0))); continue }
            if rc == SQLITE_DONE { return out }
            throw Issue1297MatchFailure.sqlite(expression: expression, message: String(cString: sqlite3_errmsg(db)))
        }
    }
}

/// One typed query, the expression it must render, and the rows that expression must match.
struct Issue1297RenderCase: Sendable, CustomTestStringConvertible {
    /// What the researcher typed.
    let query: String
    /// The MATCH expression it must render.
    let rendered: String
    /// The rowids that expression must match.
    let rows: [Int]
    /// The typed query, which is how a failing argument is named.
    var testDescription: String { query }

    /// Creates a case.
    init(_ query: String, _ rendered: String, _ rows: [Int]) {
        self.query = query
        self.rendered = rendered
        self.rows = rows
    }
}

// MARK: - Named cases

/// The decided renders, each executed against the truth table.
@Suite("#1297 exclusion placement")
struct Issue1297ExclusionTests {

    /// Renders `c.query` and asserts both the string and the rows it matches.
    private func check(_ c: Issue1297RenderCase) throws {
        let table = Issue1297TruthTable()
        let expression = try #require(FTS5InlineQueryParser.parse(c.query))
        #expect(expression == c.rendered)
        let got = try table.rows(expression)
        #expect(got == c.rows)
    }

    /// A leading exclusion is placed behind the first positive member of its run.
    @Test("An exclusion with no positive operand before it in its AND-run is placed after the run's first positive operand",
          arguments: [
            Issue1297RenderCase("-korea cold", "\"cold\" NOT \"korea\"", Issue1297Corpus.coldNotKorea),
            Issue1297RenderCase("NOT korea cold", "\"cold\" NOT \"korea\"", Issue1297Corpus.coldNotKorea),
            Issue1297RenderCase("-korea -vietnam cold", "\"cold\" NOT \"korea\" NOT \"vietnam\"", [2, 4]),
            Issue1297RenderCase("-\"naval quarantine\" blockade", "\"blockade\" NOT \"naval quarantine\"", [21]),
            Issue1297RenderCase("(-korea cold) OR war", "(\"cold\" NOT \"korea\") OR \"war\"", Issue1297Corpus.coldNotKoreaOrWar),
            Issue1297RenderCase("-korea cold OR war", "\"cold\" NOT \"korea\" OR \"war\"", Issue1297Corpus.coldNotKoreaOrWar),
            Issue1297RenderCase("-korea AND cold", "\"cold\" NOT \"korea\"", Issue1297Corpus.coldNotKorea),
            Issue1297RenderCase("-korea AND cold AND war", "\"cold\" NOT \"korea\" AND \"war\"", [4, 12]),
            Issue1297RenderCase("NOT (korea OR vietnam) cold", "\"cold\" NOT (\"korea\" OR \"vietnam\")", [2, 4]),
            Issue1297RenderCase("-korea (cold OR war)", "(\"cold\" OR \"war\") NOT \"korea\"", [2, 3, 4, 10, 11, 12]),
            Issue1297RenderCase("NOT NEAR(cold war, 5) vietnam", "\"vietnam\" NOT NEAR(\"cold\" \"war\", 5)", [9, 10, 11, 13, 14, 15]),
            Issue1297RenderCase("-=containment europe", "\"europe\" NOT \"containment\"", []),
            Issue1297RenderCase("-korea cold AND", "\"cold\" NOT \"korea\" AND \"and\"", []),
          ])
    func leadingExclusion(_ c: Issue1297RenderCase) throws {
        try check(c)
    }

    /// A typed `AND` or `NOT` directly before an exclusion is absorbed, never a literal word.
    @Test("A typed AND or NOT directly before an exclusion adds nothing to it",
          arguments: [
            Issue1297RenderCase("cold AND -korea", "\"cold\" NOT \"korea\"", Issue1297Corpus.coldNotKorea),
            Issue1297RenderCase("cold AND NOT korea", "\"cold\" NOT \"korea\"", Issue1297Corpus.coldNotKorea),
            Issue1297RenderCase("war AND NOT (korea OR vietnam)", "\"war\" NOT (\"korea\" OR \"vietnam\")", [3, 4]),
            Issue1297RenderCase("(cold OR war) AND -korea", "(\"cold\" OR \"war\") NOT \"korea\"", [2, 3, 4, 10, 11, 12]),
            Issue1297RenderCase("cold AND (-korea war)", "\"cold\" AND (\"war\" NOT \"korea\")", [4, 12]),
            Issue1297RenderCase("cold NOT -korea", "\"cold\" NOT \"korea\"", Issue1297Corpus.coldNotKorea),
            Issue1297RenderCase("NOT -korea cold", "\"cold\" NOT \"korea\"", Issue1297Corpus.coldNotKorea),
            Issue1297RenderCase("cold NOT NOT korea", "\"cold\" NOT \"korea\"", Issue1297Corpus.coldNotKorea),
          ])
    func operatorBeforeExclusion(_ c: Issue1297RenderCase) throws {
        try check(c)
    }

    /// An exclusion's scope is its AND-run.
    @Test("An exclusion stays inside its own AND-run and never crosses an OR",
          arguments: [
            Issue1297RenderCase("cold OR -korea war", "\"cold\" OR \"war\" NOT \"korea\"", [2, 3, 4, 6, 8, 10, 11, 12, 14, 16]),
            Issue1297RenderCase("-korea cold OR -vietnam war", "\"cold\" NOT \"korea\" OR \"war\" NOT \"vietnam\"", [2, 3, 4, 7, 8, 10, 12]),
          ])
    func exclusionScope(_ c: Issue1297RenderCase) throws {
        try check(c)
    }

    /// An alternative with nothing to search is left out, and says so through `droppedOperands`.
    @Test("An OR alternative made only of exclusions is left out and reported as not applied",
          arguments: [
            Issue1297RenderCase("cold OR -korea", "\"cold\"", Issue1297Corpus.coldRows),
            Issue1297RenderCase("-korea OR cold", "\"cold\"", Issue1297Corpus.coldRows),
            Issue1297RenderCase("cold OR NOT korea", "\"cold\"", Issue1297Corpus.coldRows),
            Issue1297RenderCase("NOT korea OR cold", "\"cold\"", Issue1297Corpus.coldRows),
            Issue1297RenderCase("cold OR (-korea)", "\"cold\"", Issue1297Corpus.coldRows),
            Issue1297RenderCase("cold OR -(korea OR vietnam)", "\"cold\"", Issue1297Corpus.coldRows),
            Issue1297RenderCase("-\"naval quarantine\" OR blockade", "\"blockade\"", [20, 21]),
          ])
    func exclusionOnlyAlternative(_ c: Issue1297RenderCase) throws {
        let table = Issue1297TruthTable()
        let parsed = FTS5InlineQueryParser.parseDetailed(c.query)
        let expression = try #require(parsed.expression)
        #expect(expression == c.rendered)
        let got = try table.rows(expression)
        #expect(got == c.rows)
        #expect(!parsed.droppedOperands.isEmpty)
        #expect(parsed.droppedOperands.allSatisfy { $0.isNegated })
        #expect(parsed.operands.allSatisfy { !$0.isNegated })
    }

    /// A group holding only exclusions behaves as its members would bare.
    @Test("A group of only exclusions excludes from the AND-run around it",
          arguments: [
            Issue1297RenderCase("cold (-korea)", "\"cold\" NOT \"korea\"", Issue1297Corpus.coldNotKorea),
            Issue1297RenderCase("cold (NOT korea)", "\"cold\" NOT \"korea\"", Issue1297Corpus.coldNotKorea),
            Issue1297RenderCase("cold (-korea -vietnam)", "\"cold\" NOT (\"korea\" OR \"vietnam\")", [2, 4]),
            Issue1297RenderCase("cold NOT (-korea)", "\"cold\" NOT \"korea\"", Issue1297Corpus.coldNotKorea),
            Issue1297RenderCase("-korea (-vietnam) cold", "\"cold\" NOT \"korea\" NOT \"vietnam\"", [2, 4]),
          ])
    func negationOnlyGroup(_ c: Issue1297RenderCase) throws {
        try check(c)
    }

    /// The owner's attached-dash decision: `-(X)` is `NOT (X)`.
    @Test("A dash attached to an opening parenthesis negates the group exactly as NOT does",
          arguments: [
            Issue1297RenderCase("cold -(korea OR vietnam)", "\"cold\" NOT (\"korea\" OR \"vietnam\")", [2, 4]),
            Issue1297RenderCase("-(korea OR vietnam) cold", "\"cold\" NOT (\"korea\" OR \"vietnam\")", [2, 4]),
            Issue1297RenderCase("cold AND -(korea OR vietnam)", "\"cold\" NOT (\"korea\" OR \"vietnam\")", [2, 4]),
            Issue1297RenderCase("-(korea OR vietnam) cold OR war", "\"cold\" NOT (\"korea\" OR \"vietnam\") OR \"war\"",
                                [2, 3, 4, 7, 8, 11, 12, 15, 16]),
            Issue1297RenderCase("-(-korea) cold", "\"cold\" NOT \"korea\"", Issue1297Corpus.coldNotKorea),
            Issue1297RenderCase("cold -(-korea)", "\"cold\" NOT \"korea\"", Issue1297Corpus.coldNotKorea),
            Issue1297RenderCase("war -(cold OR -korea)", "\"war\" AND \"korea\" NOT \"cold\"", [7, 15]),
            Issue1297RenderCase("cold -(korea OR (vietnam -(war)))",
                                "\"cold\" NOT (\"korea\" OR (\"vietnam\" NOT (\"war\")))", [2, 4, 12]),
          ])
    func attachedDashNegatesGroup(_ c: Issue1297RenderCase) throws {
        try check(c)
    }

    /// Negations that reach no positive term leave nothing to search.
    @Test("Queries with no positive term still render nil",
          arguments: ["NOT NOT cold", "NOT (-korea)", "NOT NOT NOT cold", "-(cold OR war) -korea"])
    func stillNil(_ query: String) {
        #expect(FTS5InlineQueryParser.parseDetailed(query) == ParsedQuery(expression: nil, exactTerms: []))
    }

    /// Hoisting moves whole column-prefixed operands.
    @Test("A column prefix moves with the operand it belongs to")
    func columnPrefixSurvivesReordering() throws {
        let table = Issue1297TruthTable(twoColumn: true)
        let prefix = "{body}:"
        let cases: [(String, String, [Int])] = [
            ("-korea cold", "{body}:\"cold\" NOT {body}:\"korea\"", Issue1297Corpus.coldNotKorea),
            ("cold AND NOT korea", "{body}:\"cold\" NOT {body}:\"korea\"", Issue1297Corpus.coldNotKorea),
            ("-\"naval quarantine\" blockade", "{body}:\"blockade\" NOT \"naval quarantine\"", [21]),
            ("cold OR war OR -korea", "{body}:\"cold\" OR {body}:\"war\"", [2, 3, 4, 6, 7, 8, 10, 11, 12, 14, 15, 16]),
            ("-(korea OR vietnam) cold", "{body}:\"cold\" NOT ({body}:\"korea\" OR {body}:\"vietnam\")", [2, 4]),
        ]
        for (query, rendered, rows) in cases {
            let expression = try #require(FTS5InlineQueryParser.parse(query, columnPrefix: prefix))
            #expect(expression == rendered, "\(query)")
            let got = try table.rows(expression)
            #expect(got == rows, "\(query)")
        }
    }

    /// `isNegated` is effective polarity, whichever spelling excluded the operand.
    @Test("NOT marks its operand excluded exactly as - does")
    func keywordNotOperandsAreNegated() {
        let notForm = FTS5InlineQueryParser.parseDetailed("cold NOT korea")
        #expect(notForm.operands.map { $0.isNegated } == [false, true])
        #expect(notForm == FTS5InlineQueryParser.parseDetailed("cold -korea"))
        let group = FTS5InlineQueryParser.parseDetailed("NOT (korea OR vietnam) cold")
        #expect(group.operands.filter { $0.isNegated }.map(\.text) == ["korea", "vietnam"])
        let dashGroup = FTS5InlineQueryParser.parseDetailed("cold -(korea OR vietnam)")
        #expect(dashGroup.operands.filter { $0.isNegated }.map(\.text) == ["korea", "vietnam"])
        let near = FTS5InlineQueryParser.parseDetailed("aid NOT NEAR(military europe, 5)")
        #expect(near.operands.last?.isNegated == true)
    }

    /// No post-filter may require a word the MATCH excludes.
    @Test("An exact mark on an excluded term is ignored, whichever way it was excluded")
    func exactTermsArePositiveOnly() {
        #expect(FTS5InlineQueryParser.parseDetailed("europe NOT =containment").exactTerms.isEmpty)
        #expect(FTS5InlineQueryParser.parseDetailed("war NOT (=containment OR rollback)").exactTerms.isEmpty)
        #expect(FTS5InlineQueryParser.parseDetailed("war -(=containment OR rollback)").exactTerms.isEmpty)
        let leading = FTS5InlineQueryParser.parseDetailed("-korea =cold")
        #expect(leading.expression == "\"cold\" NOT \"korea\"")
        #expect(leading.exactTerms == ["cold"])
    }

    /// Guards, meant to pass before and after the fix: what already worked must not move.
    @Test("Renders that were already valid and correct do not move",
          arguments: [
            Issue1297RenderCase("cold -korea", "\"cold\" NOT \"korea\"", Issue1297Corpus.coldNotKorea),
            Issue1297RenderCase("cold -korea war", "\"cold\" NOT \"korea\" AND \"war\"", [4, 12]),
            Issue1297RenderCase("cold -korea OR war", "\"cold\" NOT \"korea\" OR \"war\"", Issue1297Corpus.coldNotKoreaOrWar),
            Issue1297RenderCase("\"cold war\" OR detente -korea negoti*", "\"cold war\" OR \"detente\" NOT \"korea\" AND \"negoti\"*", [4, 8, 12, 16]),
            Issue1297RenderCase("cold - (korea OR vietnam)", "\"cold\" AND (\"korea\" OR \"vietnam\")", [6, 8, 10, 12, 14, 16]),
            Issue1297RenderCase("cold -(korea", "\"cold\" AND \"korea\"", [6, 8, 14, 16]),
            Issue1297RenderCase("cold -()", "\"cold\"", Issue1297Corpus.coldRows),
            Issue1297RenderCase("cold -(   )", "\"cold\"", Issue1297Corpus.coldRows),
            Issue1297RenderCase("cold-(korea)", "\"cold-\" AND (\"korea\")", [6, 8, 14, 16]),
            Issue1297RenderCase("AND -korea cold", "\"and\" NOT \"korea\" AND \"cold\"", []),
            Issue1297RenderCase("OR -korea cold", "\"or\" NOT \"korea\" AND \"cold\"", []),
            Issue1297RenderCase("cold OR OR war", "\"cold\" AND \"or\" OR \"war\"", [3, 4, 7, 8, 11, 12, 15, 16]),
            Issue1297RenderCase("europe -=containment", "\"europe\" NOT \"containment\"", []),
            // Already this render before the attached-dash rule, because the old parser dropped the
            // dash as punctuation and applied the NOT; under the rule the two marks count once.
            Issue1297RenderCase("cold NOT -(korea OR vietnam)", "\"cold\" NOT (\"korea\" OR \"vietnam\")", [2, 4]),
          ])
    func preserved(_ c: Issue1297RenderCase) throws {
        try check(c)
    }

    /// Guards: a query of only exclusions still reaches SQLite as nothing. `-(-korea)` was nil
    /// before the attached-dash rule too: the old parser dropped `(-korea)` as contentless.
    @Test("Queries with only exclusions stay nil",
          arguments: ["-korea", "-korea -vietnam", "NOT korea", "-korea OR -vietnam", "NOT (korea OR vietnam)", "NOT -korea",
                      "-(-korea)"])
    func preservedNil(_ query: String) {
        #expect(FTS5InlineQueryParser.parse(query) == nil)
    }
}

// MARK: - Properties executed against real FTS5

/// SplitMix64: a fixed, platform-independent sequence, so a failure reproduces.
struct Issue1297Random {
    /// The generator state.
    var state: UInt64

    /// The next 64 random bits.
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A value in `0..<n`.
    mutating func below(_ n: Int) -> Int { Int(next() % UInt64(n)) }
}

/// A generated well-formed query and its meaning as a SET, built together from one tree and
/// never from the parser's output.
struct Issue1297Generated {
    /// The query text.
    var text: String
    /// The rows it means.
    var rows: Set<Int>
    /// Whether it contains a positive term.
    var hasPositive: Bool
    /// Whether it contains an excluded term.
    var hasNegative: Bool
    /// The same query as the structured suite's oracle models it, over the leaves in the generator's harvest —
    /// which is what lets a test ask whether anything anchors, or 6.1's proof refuses, without reading a render.
    var model: Issue1297OracleModel
}

/// Generates queries with their set meaning, under the decided negation policy.
enum Issue1297QueryGenerator {
    /// Every rowid.
    static let all = Issue1297Corpus.all

    /// An operator keyword in one of three random casings.
    static func keyword(_ word: String, _ rng: inout Issue1297Random) -> String {
        [word, word.lowercased(), word.prefix(1) + word.dropFirst().lowercased()][rng.below(3)]
    }

    /// A word, an excluded word, the phrase "cold war", or the excluded phrase; its leaf is added to `harvest`.
    static func leaf(_ rng: inout Issue1297Random, _ harvest: inout Issue1297OracleHarvest) -> Issue1297Generated {
        let word = Issue1297Corpus.vocabulary[rng.below(4)]
        let phraseRows = Issue1297Corpus.rows(with: "cold").intersection(Issue1297Corpus.rows(with: "war"))
        switch rng.below(5) {
        case 0, 1:
            let index = harvest.add(word, .word, exact: false, .typed, Issue1297StructuredCorpus.W(word))
            return Issue1297Generated(text: word, rows: Issue1297Corpus.rows(with: word), hasPositive: true, hasNegative: false,
                                      model: .leaf(index))
        case 2:
            let index = harvest.add(word, .word, exact: false, .typed, Issue1297StructuredCorpus.W(word))
            return Issue1297Generated(text: "-" + word, rows: all.subtracting(Issue1297Corpus.rows(with: word)),
                                      hasPositive: false, hasNegative: true, model: .not(.leaf(index)))
        case 3:
            let index = harvest.add("cold war", .phrase, exact: false, .typed, Issue1297StructuredCorpus.P("cold war"))
            return Issue1297Generated(text: "\"cold war\"", rows: phraseRows, hasPositive: true, hasNegative: false,
                                      model: .leaf(index))
        default:
            let index = harvest.add("cold war", .phrase, exact: false, .typed, Issue1297StructuredCorpus.P("cold war"))
            return Issue1297Generated(text: "-\"cold war\"", rows: all.subtracting(phraseRows), hasPositive: false, hasNegative: true,
                                      model: .not(.leaf(index)))
        }
    }

    /// The decided rule: one or more negation marks complement what they reach, unless what they
    /// reach contains no positive term, in which case they change nothing. With `attachDash` the
    /// last mark is spelled as a dash attached to `g`, which must then be a group.
    static func negate(_ g: Issue1297Generated, marks: Int, attachDash: Bool = false,
                       _ rng: inout Issue1297Random) -> Issue1297Generated {
        let keywordMarks = attachDash ? marks - 1 : marks
        let prefix = (0..<keywordMarks).map { _ in keyword("NOT", &rng) + " " }.joined() + (attachDash ? "-" : "")
        guard g.hasPositive else {
            return Issue1297Generated(text: prefix + g.text, rows: g.rows, hasPositive: false, hasNegative: g.hasNegative,
                                      model: g.model)
        }
        return Issue1297Generated(text: prefix + g.text, rows: all.subtracting(g.rows),
                                  hasPositive: g.hasNegative, hasNegative: g.hasPositive, model: .not(g.model))
    }

    /// A group (sometimes negated), a negated leaf, or a bare leaf.
    static func item(depth: Int, attachDash: Bool, _ rng: inout Issue1297Random,
                     _ harvest: inout Issue1297OracleHarvest) -> Issue1297Generated {
        let roll = rng.below(10)
        if depth > 0, roll < 3 {
            let inner = query(depth: depth - 1, attachDash: attachDash, &rng, &harvest)
            let group = Issue1297Generated(text: "(" + inner.text + ")", rows: inner.rows,
                                           hasPositive: inner.hasPositive, hasNegative: inner.hasNegative, model: inner.model)
            return roll == 0 ? negate(group, marks: 1 + rng.below(2), attachDash: attachDash, &rng) : group
        }
        let base = leaf(&rng, &harvest)
        return roll < 6 ? negate(base, marks: 1 + rng.below(2), &rng) : base
    }

    /// One to three items joined by a space or a randomly cased AND.
    static func run(depth: Int, attachDash: Bool, _ rng: inout Issue1297Random,
                    _ harvest: inout Issue1297OracleHarvest) -> Issue1297Generated {
        var g = item(depth: depth, attachDash: attachDash, &rng, &harvest)
        var members = [g.model]
        for _ in 0..<rng.below(3) {
            let next = item(depth: depth, attachDash: attachDash, &rng, &harvest)
            let sep = rng.below(2) == 0 ? " " : " " + keyword("AND", &rng) + " "
            members.append(next.model)
            g = Issue1297Generated(text: g.text + sep + next.text, rows: g.rows.intersection(next.rows),
                                   hasPositive: g.hasPositive || next.hasPositive,
                                   hasNegative: g.hasNegative || next.hasNegative,
                                   model: .and(members))
        }
        return g
    }

    /// One to three runs joined by a randomly cased OR, its leaves added to `harvest` in the order typed.
    static func query(depth: Int, attachDash: Bool = false, _ rng: inout Issue1297Random,
                      _ harvest: inout Issue1297OracleHarvest) -> Issue1297Generated {
        var g = run(depth: depth, attachDash: attachDash, &rng, &harvest)
        var members = [g.model]
        for _ in 0..<rng.below(3) {
            let next = run(depth: depth, attachDash: attachDash, &rng, &harvest)
            members.append(next.model)
            g = Issue1297Generated(text: g.text + " " + keyword("OR", &rng) + " " + next.text, rows: g.rows.union(next.rows),
                                   hasPositive: g.hasPositive || next.hasPositive,
                                   hasNegative: g.hasNegative || next.hasNegative,
                                   model: .or(members))
        }
        return g
    }

    /// One to three runs joined by a randomly cased OR, for a caller that does not need the harvest.
    static func query(depth: Int, attachDash: Bool = false, _ rng: inout Issue1297Random) -> Issue1297Generated {
        var harvest = Issue1297OracleHarvest()
        return query(depth: depth, attachDash: attachDash, &rng, &harvest)
    }
}

/// One set-oracle run: a seed, and whether negated groups are spelled `-(` rather than `NOT (`.
struct Issue1297OracleRun: Sendable, CustomTestStringConvertible {
    /// The generator seed.
    let seed: UInt64
    /// Whether a negated group's last mark is an attached dash.
    let attachDash: Bool
    /// The minimum count each outcome must reach, so a run that never exercises one fails.
    let minimums: (exact: Int, narrowed: Int, nilApproximation: Int)
    /// Names the run in the test report.
    var testDescription: String { "seed \(seed)\(attachDash ? ", -( groups" : "")" }
}

/// Exhaustive, generated and algebraic properties of the renderer.
@Suite("#1297 properties")
struct Issue1297PropertyTests {

    /// The alphabet of the judged 7,380-sequence measurement.
    static let alphabet = ["cold", "war", "-korea", "NOT", "korea", "AND", "OR", "(", ")"]

    /// Every space-joined sequence of 1...`maxLength` tokens over `tokens`.
    static func sequences(maxLength: Int, over tokens: [String] = alphabet) -> [String] {
        var out: [[String]] = [[]]
        var all: [String] = []
        for _ in 0..<maxLength {
            out = out.flatMap { prefix in tokens.map { prefix + [$0] } }
            all += out.map { $0.joined(separator: " ") }
        }
        return all
    }

    /// No render is ever rejected, including sequences that use the attached dash.
    @Test("Every token sequence of length 1-4 renders nil or FTS5 SQLite accepts, with and without a column prefix",
          arguments: [false, true])
    func exhaustiveValidity(withAttachedDash: Bool) {
        let tokens = withAttachedDash ? Self.alphabet + ["-("] : Self.alphabet
        let queries = Self.sequences(maxLength: 4, over: tokens)
        #expect(queries.count == (withAttachedDash ? 11_110 : 7_380))
        for (prefix, table) in [("", Issue1297TruthTable()), ("{body}:", Issue1297TruthTable(twoColumn: true))] {
            var executed = 0
            var rejected: [String] = []
            for query in queries {
                guard let expression = FTS5InlineQueryParser.parse(query, columnPrefix: prefix) else { continue }
                executed += 1
                do { _ = try table.rows(expression) } catch { rejected.append("\(query) -> \(expression)") }
            }
            print("[1297] validity attachedDash=\(withAttachedDash) prefix=\(prefix) executed=\(executed) rejected=\(rejected.count)")
            #expect(executed > (withAttachedDash ? 9_000 : 6_000))
            #expect(rejected.isEmpty, "\(rejected.prefix(5))")
        }
    }

    /// The renderer agrees with an independent set semantics, or narrows and says so.
    @Test("Generated well-formed queries match their set meaning exactly, or a narrower subset that reports what it left out",
          arguments: [
            Issue1297OracleRun(seed: 1297, attachDash: false, minimums: (1_000, 100, 100)),
            Issue1297OracleRun(seed: 1299, attachDash: true, minimums: (1_000, 100, 100)),
          ])
    func setOracle(_ run: Issue1297OracleRun) throws {
        let table = Issue1297TruthTable()
        var rng = Issue1297Random(state: run.seed)
        var exact = 0, narrowed = 0, nilApproximation = 0, dashGroups = 0
        var nilNothingAnchors = 0, nilRefusedByProof = 0
        for _ in 0..<4_000 {
            var harvest = Issue1297OracleHarvest()
            let g = Issue1297QueryGenerator.query(depth: 2, attachDash: run.attachDash, &rng, &harvest)
            if g.text.contains("-(") { dashGroups += 1 }
            let parsed = FTS5InlineQueryParser.parseDetailed(g.text)
            if !g.rows.contains(1) {
                exact += 1
                let expression = try #require(parsed.expression, "\(g.text)")
                let got = Set(try table.rows(expression))
                #expect(got == g.rows, "\(g.text) -> \(expression)")
                #expect(parsed.droppedOperands.isEmpty, "\(g.text)")
            } else if let expression = parsed.expression {
                narrowed += 1
                let got = Set(try table.rows(expression))
                #expect(got.isSubset(of: g.rows), "\(g.text) -> \(expression)")
                #expect(!parsed.droppedOperands.isEmpty, "\(g.text)")
            } else {
                nilApproximation += 1
                // A nil is legitimate only when nothing anchors, or when parser 6.1's proof shows the approximation
                // matches nothing. Both are read from the oracle's model of the query, never from a render.
                let root = Issue1297OracleModel.and([g.model])
                var policyDropped = Set<Int>(), searchedDropped = Set<Int>()
                let policy = Issue1297OracleModel.policy(root, negated: false, pushInward: true, harvest, scoped: false,
                                                         dropped: &policyDropped)
                let searched = Issue1297OracleModel.searched(root, pushInward: true, harvest, scoped: false,
                                                             dropped: &searchedDropped)
                #expect(searched == nil, "\(g.text): nil, although the policy anchors and the proof does not refuse")
                if policy == nil { nilNothingAnchors += 1 } else if searched == nil { nilRefusedByProof += 1 }
            }
        }
        print("[1297] oracle \(run.testDescription) exact=\(exact) narrowed=\(narrowed) nil=\(nilApproximation) nilNothingAnchors=\(nilNothingAnchors) nilRefusedByProof=\(nilRefusedByProof) dashGroups=\(dashGroups)")
        #expect(exact > run.minimums.exact)
        #expect(narrowed > run.minimums.narrowed)
        #expect(nilApproximation > run.minimums.nilApproximation)
        // Each legitimate kind of nil must occur, or its half of the check above is vacuous.
        #expect(nilNothingAnchors > 0)
        #expect(nilRefusedByProof > 0)
        #expect(run.attachDash ? dashGroups > 500 : dashGroups == 0)
    }

    /// Widening never loses rows; excluding never gains any.
    @Test("Adding an OR alternative never removes a row; adding an exclusion never adds one")
    func monotonicity() throws {
        let table = Issue1297TruthTable()
        var rng = Issue1297Random(state: 1298)
        var compared = 0
        for _ in 0..<2_000 {
            let g = Issue1297QueryGenerator.query(depth: 2, &rng)
            guard let base = FTS5InlineQueryParser.parse(g.text) else { continue }
            let baseRows = Set(try table.rows(base))
            let widened = try #require(FTS5InlineQueryParser.parse(g.text + " OR vietnam"))
            let widenedRows = Set(try table.rows(widened))
            #expect(widenedRows.isSuperset(of: baseRows), "\(g.text) OR vietnam")
            var narrowedRows: Set<Int> = []
            if let narrowed = FTS5InlineQueryParser.parse(g.text + " -vietnam") { narrowedRows = Set(try table.rows(narrowed)) }
            #expect(narrowedRows.isSubset(of: baseRows), "\(g.text) -vietnam")
            compared += 1
        }
        print("[1297] monotonicity compared=\(compared)")
        #expect(compared > 1_000)
    }

    /// `-x` and `NOT x` are one spelling.
    @Test("-x and NOT x parse identically in every position")
    func dashEqualsNot() {
        var compared = 0
        for query in Self.sequences(maxLength: 4) where query.split(separator: " ").contains("-korea") {
            let spelled = query.split(separator: " ").map { $0 == "-korea" ? "NOT korea" : String($0) }.joined(separator: " ")
            #expect(FTS5InlineQueryParser.parseDetailed(query) == FTS5InlineQueryParser.parseDetailed(spelled), "\(query) vs \(spelled)")
            compared += 1
        }
        print("[1297] dash=not compared=\(compared)")
        #expect(compared == 2_700)
    }

    /// What a generated group's contents are built from. `⊖(` stands for a negated group and is
    /// spelled the same way as the group under test, so nested negated groups are covered too.
    static let groupContentUnits = ["cold", "war", "-korea", "NOT", "korea", "AND", "OR",
                                    "⊖(cold OR -korea)", "⊖(vietnam)", "(war)"]

    /// Positions a negated group can take, with `◻` marking it.
    static let groupContexts = ["◻", "cold ◻", "◻ cold", "cold AND ◻", "◻ AND cold", "cold OR ◻", "◻ OR cold",
                                "cold NOT ◻", "NOT ◻", "war (◻)", "(cold OR ◻) war", "cold ◻ war", "◻ ◻"]

    /// `-(X)` is `NOT (X)`, everywhere, for every X built from `groupContentUnits`.
    @Test("-(X) and NOT (X) parse identically in every position, for every X of one to three members")
    func attachedDashGroupEqualsNotGroup() throws {
        let table = Issue1297TruthTable()
        var contents: [[String]] = [[]]
        var allContents: [String] = []
        for _ in 0..<3 {
            contents = contents.flatMap { prefix in Self.groupContentUnits.map { prefix + [$0] } }
            allContents += contents.map { $0.joined(separator: " ") }
        }
        #expect(allContents.count == 1_110)

        var compared = 0, rendered = 0, negating = 0, differsFromDetached = 0
        for context in Self.groupContexts {
            for inner in allContents {
                let template = context.replacingOccurrences(of: "◻", with: "⊖(" + inner + ")")
                let dash = template.replacingOccurrences(of: "⊖(", with: "-(")
                let keyword = template.replacingOccurrences(of: "⊖(", with: "NOT (")
                let detached = template.replacingOccurrences(of: "⊖(", with: "- (")
                let dashParsed = FTS5InlineQueryParser.parseDetailed(dash)
                #expect(dashParsed == FTS5InlineQueryParser.parseDetailed(keyword), "\(dash) vs \(keyword)")
                compared += 1
                if dashParsed != FTS5InlineQueryParser.parseDetailed(detached) { differsFromDetached += 1 }
                guard let expression = dashParsed.expression else { continue }
                rendered += 1
                if dashParsed.operands.contains(where: \.isNegated) { negating += 1 }
                #expect(throws: Never.self, "\(dash) -> \(expression)") { _ = try table.rows(expression) }
            }
        }
        print("[1297] -(X)=NOT (X) compared=\(compared) rendered=\(rendered) negating=\(negating) differsFromDetached=\(differsFromDetached)")
        #expect(compared == 14_430)
        #expect(rendered > 10_000)
        #expect(negating > 7_000)
        #expect(differsFromDetached > 10_000)
    }

    /// The members an AND-run is permuted over, one of them a dash-negated group.
    static let runUnits = ["cold", "war", "-korea", "NOT vietnam", "(cold OR war)", "(-korea)", "\"cold war\"",
                           "-\"cold war\"", "NOT (korea OR vietnam)", "NEAR(cold war, 5)", "-(korea OR vietnam)"]

    /// Every ordered arrangement of `count` distinct indices into `runUnits`.
    static func arrangements(of count: Int) -> [[Int]] {
        guard count > 0 else { return [[]] }
        return arrangements(of: count - 1).flatMap { prefix in
            runUnits.indices.filter { !prefix.contains($0) }.map { prefix + [$0] }
        }
    }

    /// Order within a run is not meaning, and neither are parentheses around it.
    @Test("Reordering or explicitly AND-ing the members of one AND-run never changes the match set, and parenthesising the run changes nothing")
    func runPermutationAndGrouping() throws {
        let table = Issue1297TruthTable()
        func rows(_ q: String) throws -> Set<Int>? { try FTS5InlineQueryParser.parse(q).map { Set(try table.rows($0)) } }
        var groups = 0, wraps = 0
        // Comparisons whose sides rendered, per unit taking part. `groups` and `wraps` are combinatorics of `runUnits`
        // and cannot depend on the parser, and nil == nil passes every comparison: without these counts a parser
        // that refused every query holding one unit would pass.
        var renderedByUnit = [Int](repeating: 0, count: Self.runUnits.count)
        for size in 1...3 {
            var seen: [String: Set<Int>?] = [:]
            for arrangement in Self.arrangements(of: size) {
                let key = arrangement.sorted().map(String.init).joined(separator: ",")
                for sep in [" ", " AND "] {
                    let run = arrangement.map { Self.runUnits[$0] }.joined(separator: sep)
                    let result = try rows(run)
                    if let expected = seen[key] { #expect(result == expected, "\(run)") } else { seen[key] = result; groups += 1 }
                    let wrapped = try rows("(" + run + ")")
                    let andWrapped = try rows("war (" + run + ")"), andBare = try rows("war " + run)
                    let orWrapped = try rows("vietnam OR (" + run + ")"), orBare = try rows("vietnam OR " + run)
                    #expect(wrapped == result, "(\(run))")
                    #expect(andWrapped == andBare, "war (\(run))")
                    #expect(orWrapped == orBare, "vietnam OR (\(run))")
                    wraps += 3
                    let rendered = [result != nil && wrapped != nil, andWrapped != nil && andBare != nil,
                                    orWrapped != nil && orBare != nil].filter { $0 }.count
                    for unit in arrangement { renderedByUnit[unit] += rendered }
                }
            }
        }
        print("[1297] permutation groups=\(groups) wraps=\(wraps) renderedByUnit=\(renderedByUnit)")
        #expect(groups == 231)
        #expect(wraps == 6_666)
        for (unit, count) in renderedByUnit.enumerated() {
            #expect(count > 0, "no comparison holding \(Self.runUnits[unit]) rendered")
        }
    }
}

// MARK: - Nesting depth

/// A value handed back from a thread the test started, read only after that thread has signalled.
final class Issue1297ThreadResult<Value>: @unchecked Sendable {
    /// What the thread produced.
    var value: Value?
}

/// Runs work on a thread with a small stack, the size of a Swift concurrency pool thread's.
enum Issue1297SmallStack {
    /// 512 KB: `SearchService` is an actor and the Query Inspector parses from an async method, so the app parses on
    /// cooperative-pool threads, whose stacks are this size.
    static let bytes = 512 * 1_024

    /// `body`'s result, computed on a thread with a `bytes` stack. A stack overflow kills the test process, which
    /// is the failure this exists to surface.
    static func run<Value>(_ body: @escaping @Sendable () -> Value) -> Value? {
        let result = Issue1297ThreadResult<Value>()
        let done = DispatchSemaphore(value: 0)
        let thread = Thread {
            result.value = body()
            done.signal()
        }
        thread.stackSize = bytes
        thread.start()
        done.wait()
        return result.value
    }
}

/// One way of nesting groups, as the text for `levels` levels of balanced parentheses.
struct Issue1297NestingPattern: Sendable, CustomTestStringConvertible {
    /// Names the pattern in the test report.
    let name: String
    /// The text opening one level.
    let open: String
    /// What sits innermost.
    let inner: String
    /// Balanced parenthesis pairs `inner` holds itself, which count as levels.
    let innerLevels: Int

    /// The query nested `levels` levels deep, counting every balanced pair of parentheses.
    func query(levels: Int) -> String {
        let repetitions = levels - innerLevels
        return String(repeating: open, count: repetitions) + inner + String(repeating: ")", count: repetitions)
    }

    /// The pattern's name.
    var testDescription: String { name }
}

/// Parser 6.3 refuses a query whose groups nest deeper than a limit, before any recursive pass.
///
/// Every recursive pass over the tree costs stack per level, and the app parses on 512 KB threads: before the limit,
/// parser 6.2 parsed at most 277 levels of `-(war …)` on such a thread in a Release build and 22 in a Debug build, and
/// one level more killed the process. Every check here therefore runs on a thread with that stack.
@Suite("#1297 nesting depth")
struct Issue1297DepthTests {

    /// The decided limit: 32 levels render, 33 are refused.
    static let limit = 32

    /// The refusal every refused query returns.
    static let refused = ParsedQuery(expression: nil, exactTerms: [])

    /// Nestings chosen for the stack each level costs. Measured as the deepest point a parse reaches on a painted thread
    /// stack at 32 levels in a Debug build, `-(a OR -b …)` around `-korea` was the costliest at parser 6.3 (322 KB), and
    /// `-(war …)` is within 3 KB of the costliest at 6.4 (86 KB, around `=cold`).
    static let patterns: [Issue1297NestingPattern] = [
        Issue1297NestingPattern(name: "-(war …)", open: "-(war ", inner: "cold", innerLevels: 0),
        Issue1297NestingPattern(name: "((…))", open: "(", inner: "cold", innerLevels: 0),
        Issue1297NestingPattern(name: "(a OR …)", open: "(a OR ", inner: "cold", innerLevels: 0),
        Issue1297NestingPattern(name: "war NOT (…)", open: "war NOT (", inner: "cold", innerLevels: 0),
        Issue1297NestingPattern(name: "(…NEAR(…)…)", open: "(", inner: "NEAR(cold war, 5)", innerLevels: 1),
        Issue1297NestingPattern(name: "NEAR(NEAR(…))", open: "NEAR(", inner: "cold war", innerLevels: 0),
        Issue1297NestingPattern(name: "-(a OR -b …)", open: "-(a OR -b ", inner: "cold", innerLevels: 0),
        // The same nesting around an exclusion leaves every level a complement to push inward (round-2 P3).
        Issue1297NestingPattern(name: "-(a OR -b … -korea)", open: "-(a OR -b ", inner: "-korea", innerLevels: 0),
        Issue1297NestingPattern(name: "-(-a OR …)", open: "-(-a OR ", inner: "cold", innerLevels: 0),
        Issue1297NestingPattern(name: "(-a OR …)", open: "(-a OR ", inner: "cold", innerLevels: 0),
    ]

    /// `query` beside shallow groups and an unmatched `)`: the deepest nesting is neither the last group opened, nor
    /// in the first top-level group, and an unmatched `)` is punctuation that closes no level (round-2 P5).
    static func besideShallowGroups(_ query: String) -> String {
        ") (war) " + query + " (war)"
    }

    /// The limit renders in each shape; one level deeper is refused whatever sits beside it.
    ///
    /// The renders are not executed. SQLite's FTS5 grammar has a fixed stack of its own, and several of these renders
    /// nest past it at the limit ("fts5: parser stack overflow") — an error the search reports, which the depth limit
    /// does not claim to prevent.
    @Test("A query nested to the limit renders, and one nested a level deeper is refused, on a 512 KB stack",
          arguments: Issue1297DepthTests.patterns)
    func limitRendersAndOneDeeperIsRefused(_ pattern: Issue1297NestingPattern) throws {
        let atLimit = pattern.query(levels: Self.limit), beyond = pattern.query(levels: Self.limit + 1)
        let results = try #require(Issue1297SmallStack.run {
            [FTS5InlineQueryParser.parseDetailed(atLimit),
             FTS5InlineQueryParser.parseDetailed(atLimit, columnPrefix: "{body}:",
                                                 structured: StructuredQueryParts(phrase: "cold war")),
             FTS5InlineQueryParser.parseDetailed(beyond),
             FTS5InlineQueryParser.parseDetailed(beyond, columnPrefix: "{body}:",
                                                 structured: StructuredQueryParts(phrase: "cold war", excludedTerms: ["korea"])),
             FTS5InlineQueryParser.parseDetailed(Self.besideShallowGroups(beyond)),
             FTS5InlineQueryParser.parseDetailed(Self.besideShallowGroups(atLimit))]
        })
        #expect(results[0].expression != nil, "\(pattern.name) at the limit")
        #expect(results[1].expression != nil, "\(pattern.name) at the limit, scoped beside a phrase")
        #expect(results[2] == Self.refused, "\(pattern.name) one level deeper")
        #expect(results[3] == Self.refused, "\(pattern.name) one level deeper, scoped beside a phrase and an exclusion")
        #expect(results[4] == Self.refused, "\(pattern.name) one level deeper, beside shallow groups and an unmatched )")
        #expect(results[5].expression != nil, "\(pattern.name) at the limit, beside shallow groups and an unmatched )")
    }

    /// A pasted query thousands of levels deep returns instead of overflowing the stack.
    @Test("A query nested 5,000 levels deep is refused without overflowing a 512 KB stack",
          arguments: Issue1297DepthTests.patterns)
    func deepQueriesReturn(_ pattern: Issue1297NestingPattern) throws {
        let query = pattern.query(levels: 5_000)
        // Beside shallow groups, and after as many unmatched `)` as there are levels, so a depth scan that let either
        // lower the count would recurse 5,000 levels here rather than merely render.
        let besideGroups = Self.besideShallowGroups(query)
        let afterClosers = String(repeating: ")", count: 5_000) + " (war) " + query
        let results = try #require(Issue1297SmallStack.run {
            [FTS5InlineQueryParser.parseDetailed(query),
             FTS5InlineQueryParser.parseDetailed(query, columnPrefix: "{body}:", structured: StructuredQueryParts(prefixWildcard: "viet")),
             FTS5InlineQueryParser.parseDetailed(besideGroups),
             FTS5InlineQueryParser.parseDetailed(afterClosers)]
        })
        #expect(results == [Self.refused, Self.refused, Self.refused, Self.refused], "\(pattern.name)")
    }

    /// The depth scan itself: the deepest level wherever it sits, never lowered by a parenthesis that pairs with nothing.
    @Test("Depth is the deepest balanced nesting anywhere in the query, and an unmatched ) lowers nothing")
    func groupDepthTakesTheDeepestLevel() {
        #expect(FTS5InlineQueryParser.groupDepth(of: ["(", "a", ")", "(", "(", "b", ")", ")"]) == 2,
                "the deepest group is not the first top-level group")
        #expect(FTS5InlineQueryParser.groupDepth(of: ["(", "(", "a", ")", ")", "(", "b", ")"]) == 2,
                "the deepest group is not the last one opened")
        #expect(FTS5InlineQueryParser.groupDepth(of: [")", "(", "(", "a", ")", ")"]) == 2,
                "an unmatched ) is punctuation")
        #expect(FTS5InlineQueryParser.groupDepth(of: ["(", "(", "a", ")"]) == 1, "an unmatched ( is punctuation")
    }

    /// Depth counts balanced pairs of parentheses, not parentheses: what never nests is never refused for it.
    @Test("Parentheses that do not nest are not depth: unbalanced runs, quoted parentheses and many shallow groups render")
    func depthCountsOnlyNesting() throws {
        let deepAtLimit = String(repeating: "(", count: Self.limit) + "cold" + String(repeating: ")", count: Self.limit)
        let cases: [(query: String, expression: String)] = [
            (String(repeating: "(", count: 5_000) + " cold", "\"cold\""),
            ("cold " + String(repeating: ")", count: 5_000), "\"cold\""),
            (String(repeating: "-(", count: 5_000) + " cold", "\"cold\""),
            (String(repeating: ")", count: 5_000) + String(repeating: "(", count: 5_000) + " cold", "\"cold\""),
        ]
        // A quoted phrase is one token, whatever it holds: its parentheses are text, and it renders as typed.
        let quoted = "\"" + String(repeating: "(", count: 40) + "cold war" + String(repeating: ")", count: 40) + "\""
        let results = try #require(Issue1297SmallStack.run {
            cases.map { FTS5InlineQueryParser.parseDetailed($0.query).expression }
                + [FTS5InlineQueryParser.parseDetailed(quoted).expression,
                   FTS5InlineQueryParser.parseDetailed(Array(repeating: deepAtLimit, count: 60).joined(separator: " OR ")).expression]
        })
        for (index, testCase) in cases.enumerated() {
            #expect(results[index] == testCase.expression, "\(testCase.query.prefix(40))…")
        }
        #expect(results[cases.count] == quoted)
        let manyGroups = try #require(results[cases.count + 1], "60 groups each nested to the limit")
        #expect(throws: Never.self) { _ = try Issue1297TruthTable().rows(manyGroups) }
    }

    #if DEBUG
    /// The shapes parser 6.4's memo was measured on, at the limit: 32 levels of `-(a OR -b …)` around a run of `=w`
    /// words and `OR -z`, the same around alternating anchors and exclusions, and 32 plain groups around a run.
    static func memoShapes(words: Int) -> [(name: String, query: String)] {
        func run(_ unit: (Int) -> String) -> String { (0..<words).map(unit).joined(separator: " ") }
        let negated = String(repeating: "-(a OR -b ", count: limit), plain = String(repeating: "(", count: limit)
        let closers = String(repeating: ")", count: limit)
        return [("-(a OR -b …) around =w and OR -z", negated + run { "=w\($0)" } + " OR -z" + closers),
                ("-(a OR -b …) around w -k and OR -z", negated + run { "w\($0) -k\($0)" } + " OR -z" + closers),
                ("((…)) around w and OR -z", plain + run { "w\($0)" } + " OR -z" + closers)]
            + patterns.map { ($0.name, $0.query(levels: limit)) }
    }

    /// Parser 6.4 keeps each node's meaning and anchor on the node, and nothing else shows the memo is there: without it
    /// every render is byte-identical, and 32 levels of `-(a OR -b …)` around 4,000 characters of `=w` words took 1,432 ms
    /// in a Debug build against 25 ms with it (the round-2 attack's M22). So this counts settlements rather than time,
    /// on the tree the parse itself built. The anchor half guards a future caller rather than a current path: no parse
    /// reaches one node's anchor twice, so removing `anchor(_:)`'s guard moved no count over round 2's 1,411,430 parses.
    @Test("Every node of a query nested to the limit is evaluated once and anchored at most once, on a 512 KB stack")
    func nodesAreSettledOnce() throws {
        let queries = Self.memoShapes(words: 60)
        let results = try #require(Issue1297SmallStack.run {
            queries.flatMap { shape in
                [FTS5InlineQueryParser.work(parsing: shape.query),
                 FTS5InlineQueryParser.work(parsing: shape.query, columnPrefix: "{body}:",
                                            structured: StructuredQueryParts(phrase: "cold war", excludedTerms: ["korea"]))]
            }
        })
        #expect(results.count == queries.count * 2)
        for (index, result) in results.enumerated() {
            let shape = queries[index / 2], label = "\(queries[index / 2].name)\(index % 2 == 1 ? ", scoped beside a phrase" : "")"
            #expect(result.query.expression != nil, "\(label)")
            #expect(result.query == FTS5InlineQueryParser.parseDetailed(shape.query, columnPrefix: index % 2 == 1 ? "{body}:" : "",
                                                                        structured: index % 2 == 1
                                                                            ? StructuredQueryParts(phrase: "cold war", excludedTerms: ["korea"])
                                                                            : .none),
                    "the counted parse is the parse: \(label)")
            #expect(result.work.nodes > Self.limit, "\(label) builds its tree")
            #expect(result.work.maximumMeaningSettlements == 1, "\(label): \(result.work)")
            #expect(result.work.meaningSettlements == result.work.nodes, "\(label): every node evaluated, each once")
            #expect(result.work.maximumAnchorSettlements == 1, "\(label): \(result.work)")
        }
    }

    /// The counts `nodesAreSettledOnce` reads can exceed one. A counter that stopped adding reads 1 whether the memo holds
    /// or not, so that test alone passed a saturating counter with the memo removed (the round-3 attack's P5c); here the
    /// root of each shape is settled once more past the memo, and must say so.
    @Test("A node settled twice counts two, so the settle-once counts can fail")
    func settlementCountsAdd() throws {
        let queries = Self.memoShapes(words: 4) + [("a leaf", "cold"), ("a complement", "cold OR -(war -korea)")]
        let results = try #require(Issue1297SmallStack.run {
            queries.map { (FTS5InlineQueryParser.work(parsing: $0.query).work,
                           FTS5InlineQueryParser.workSettlingRootTwice(parsing: $0.query)) }
        })
        #expect(results.count == queries.count)
        for (shape, result) in zip(queries, results) {
            let (once, twice) = result
            #expect(once.maximumMeaningSettlements == 1, "\(shape.name): \(once)")
            #expect(twice.nodes == once.nodes, "\(shape.name): the same tree")
            #expect(twice.maximumMeaningSettlements == 2, "\(shape.name): \(twice)")
            #expect(twice.meaningSettlements == once.meaningSettlements + 1, "\(shape.name): only the root again")
            #expect(twice.maximumAnchorSettlements == 2, "\(shape.name): \(twice)")
        }
    }
    #endif

    /// Long queries with no nesting at all.
    static let flatShapes: [(name: String, unit: @Sendable (Int) -> String)] = [
        ("NOT chain", { _ in "NOT " }),
        ("OR alternatives", { "w\($0) OR " }),
        ("OR with exclusion-only alternatives", { "w\($0) OR -k\($0) OR " }),
        ("AND run", { "w\($0) AND " }),
        ("exclusions", { "-k\($0) " }),
        ("anchors and exclusions", { "w\($0) -k\($0) " }),
        ("demoted operators", { _ in "AND OR " }),
        ("negated groups", { "-(w\($0) -k\($0)) " }),
        ("NOT groups beside an anchor", { "NOT (w\($0) OR -k\($0)) " }),
        ("exact alternatives", { "=w\($0) OR " }),
        ("NEAR operators", { "NEAR(w\($0) v\($0), 5) " }),
    ]

    /// A flat query thousands of operators long parses on the small stack.
    ///
    /// Only the parse is checked. SQLite refuses some of these renders for a limit of its own — a chain of more than
    /// 255 `NOT`s is "fts5 expression tree is too large (maximum depth 256)" — which is an error the search reports,
    /// never a crash, and no part of what this suite pins.
    @Test("A flat query of thousands of operators and exclusions parses on a 512 KB stack")
    func flatQueriesParse() throws {
        var queries: [String] = []
        for shape in Self.flatShapes {
            var query = "cold "
            var index = 0
            while query.count < 8_000 {
                query += shape.unit(index)
                index += 1
            }
            queries.append(query + "cold")
        }
        let frozen = queries
        let results = try #require(Issue1297SmallStack.run { frozen.map { FTS5InlineQueryParser.parseDetailed($0).expression } })
        #expect(results.count == Self.flatShapes.count)
        for (shape, expression) in zip(Self.flatShapes, results) {
            #expect(expression != nil, "\(shape.name)")
        }
    }
}
