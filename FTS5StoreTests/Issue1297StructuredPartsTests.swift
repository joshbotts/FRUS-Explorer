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

// MARK: - #1297: typed exclusions beside the structured fields
//
// A restored saved search can carry a structured phrase, prefix or excluded terms beside what was
// typed. The app used to render the typed text alone and hand the result to `FTS5Query` as a
// string, so a typed complement (`-korea`, `cold OR -korea`) the typed parse could not anchor was
// discarded or approximated even when the structured phrase or prefix gave it something to exclude
// from — and nothing reported it. These tests pin the combined parse,
// `FTS5InlineQueryParser.parseDetailed(_:columnPrefix:structured:)`, against an oracle that computes
// meanings over SETS and never reads a render.

// MARK: - Corpus

/// The #1297 truth-table corpus, plus three rows that tell a structured field apart from the typed
/// words beside it.
///
/// Rows 1–21 are `Issue1297Corpus.bodies` unchanged, so its literal row lists still hold. Row 22
/// holds cold and war but not the phrase "cold war"; row 23 holds the prefix viet without vietnam;
/// row 24 holds cold, korea and the prefix.
///
/// Version history:
///   1.0 — #1297: initial implementation
enum Issue1297StructuredCorpus {
    /// Row bodies; index 0 holds rowid 1.
    static let bodies = Issue1297Corpus.bodies + ["memo war cold", "memo vietcong", "memo cold vietcong korea"]

    /// Every rowid.
    static let all = Set(1...bodies.count)

    /// The whitespace tokens of a row.
    static func tokens(_ row: Int) -> [String] {
        bodies[row - 1].split(separator: " ").map(String.init)
    }

    /// The rows containing `word` as a whole token.
    static func W(_ word: String) -> Set<Int> {
        all.filter { tokens($0).contains(word) }
    }

    /// The rows containing `phrase`'s words consecutively, in order.
    static func P(_ phrase: String) -> Set<Int> {
        let words = phrase.split(separator: " ").map(String.init)
        return all.filter { row in
            let t = tokens(row)
            guard t.count >= words.count else { return false }
            return (0...(t.count - words.count)).contains { Array(t[$0..<($0 + words.count)]) == words }
        }
    }

    /// The rows holding a token that begins with `prefix`.
    static func X(_ prefix: String) -> Set<Int> {
        all.filter { tokens($0).contains { $0.hasPrefix(prefix) } }
    }

    /// The rows where cold and war occur with at most five tokens between them: `NEAR(cold war, 5)`.
    static let nearRows: Set<Int> = all.filter { row in
        let t = tokens(row)
        guard let cold = t.firstIndex(of: "cold"), let war = t.firstIndex(of: "war") else { return false }
        return abs(cold - war) - 1 <= 5
    }

    /// Every row not in `rows`.
    static func N(_ rows: Set<Int>) -> Set<Int> {
        all.subtracting(rows)
    }
}

/// An in-memory `porter unicode61` FTS5 table, queried for rowids.
final class Issue1297StructuredTable {
    /// The open database handle.
    private var db: OpaquePointer?
    /// The FTS5 table's name.
    private let name: String

    /// The corpus as `d(body_text)`, or with `twoColumn` as `d2(header, body_text)` under a constant
    /// header, so a `{body_text}:` prefix has a column to scope away from.
    init(twoColumn: Bool = false) {
        name = twoColumn ? "d2" : "d"
        sqlite3_open(":memory:", &db)
        sqlite3_exec(db, twoColumn
            ? "CREATE VIRTUAL TABLE d2 USING fts5(header, body_text, tokenize='porter unicode61');"
            : "CREATE VIRTUAL TABLE d USING fts5(body_text, tokenize='porter unicode61');", nil, nil, nil)
        for (index, body) in Issue1297StructuredCorpus.bodies.enumerated() {
            insert(twoColumn ? "INSERT INTO d2(rowid, header, body_text) VALUES (?, 'heading', ?);"
                             : "INSERT INTO d(rowid, body_text) VALUES (?, ?);",
                   rowid: index + 1, values: [body])
        }
    }

    /// The user-content shape, `u(summary_text, note_text)`, holding `rows` in order from rowid 1.
    init(userContent rows: [(summary: String, note: String)]) {
        name = "u"
        sqlite3_open(":memory:", &db)
        sqlite3_exec(db, "CREATE VIRTUAL TABLE u USING fts5(summary_text, note_text, tokenize='porter unicode61');",
                     nil, nil, nil)
        for (index, row) in rows.enumerated() {
            insert("INSERT INTO u(rowid, summary_text, note_text) VALUES (?, ?, ?);",
                   rowid: index + 1, values: [row.summary, row.note])
        }
    }

    deinit { sqlite3_close(db) }

    /// Runs one insert with `rowid` and `values` bound in order.
    private func insert(_ sql: String, rowid: Int, values: [String]) {
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        sqlite3_bind_int(stmt, 1, Int32(rowid))
        for (offset, value) in values.enumerated() {
            sqlite3_bind_text(stmt, Int32(offset + 2), value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }

    /// The matching rowids. Throws when SQLite rejects the expression.
    func rows(_ expression: String) throws -> Set<Int> {
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "SELECT rowid FROM \(name) WHERE \(name) MATCH ?;", -1, &stmt, nil)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, expression, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        var out = Set<Int>()
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_ROW { out.insert(Int(sqlite3_column_int64(stmt, 0))); continue }
            if rc == SQLITE_DONE { return out }
            throw Issue1297MatchFailure.sqlite(expression: expression, message: String(cString: sqlite3_errmsg(db)))
        }
    }
}

// MARK: - Named cases

/// A typed operand, every field spelled out.
private func typedOperand(_ text: String, _ rendered: String, _ kind: ParsedOperand.Kind,
                          negated: Bool, exact: Bool = false) -> ParsedOperand {
    ParsedOperand(text: text, rendered: rendered, kind: kind, isNegated: negated, isExact: exact, source: .typed)
}

/// A structured operand, every field spelled out.
private func structuredOperand(_ text: String, _ rendered: String, _ kind: ParsedOperand.Kind,
                               negated: Bool) -> ParsedOperand {
    ParsedOperand(text: text, rendered: rendered, kind: kind, isNegated: negated, isExact: false, source: .structured)
}

/// One typed query beside structured fields: what it must render, the set it means, and what it
/// must report.
struct Issue1297StructuredCase: Sendable, CustomTestStringConvertible {
    /// What the researcher typed.
    let typed: String
    /// The structured fields beside it.
    var structured: StructuredQueryParts = .none
    /// Whether the query is scoped to `{body_text}:` on the two-column table.
    var scoped = false
    /// The expression it must render, or `nil`.
    let expression: String?
    /// The query's exact meaning, written as a set formula — never read from a render.
    let meaning: Set<Int>
    /// The rows the rendered expression must match when `meaning` holds row 1, which contains no
    /// query term and so marks a complement FTS5 cannot search: `nil` when nothing anchors.
    var approximation: Set<Int>?
    /// The operands the expression applies, in harvest order.
    var operands: [ParsedOperand] = []
    /// The operands it leaves out.
    var dropped: [ParsedOperand] = []
    /// The exact-word post-filter terms.
    var exactTerms: [String] = []
    /// Whether the expression is narrower than the meaning.
    var isApproximate = false

    /// Names the case in the test report.
    var testDescription: String {
        let fields = [structured.phrase.map { "phrase \($0)" }, structured.prefixWildcard.map { "prefix \($0)*" },
                      structured.excludedTerms.isEmpty ? nil : "excluded \(structured.excludedTerms)",
                      scoped ? "scoped" : nil]
        return ([typed.isEmpty ? "(nothing typed)" : typed] + fields.compactMap { $0 }).joined(separator: ", ")
    }
}

/// The combined parse of typed text and structured fields, executed against the truth table.
///
/// Version history:
///   1.0 — #1297: initial implementation — the judged join design's named table, finding-4 pins,
///          set oracle, combined sweep and column-span pin
@Suite("#1297 typed queries beside structured fields")
struct Issue1297StructuredPartsTests {

    /// The judged final table, minus its user-content row (see `structuredExclusionsSpanAllColumns`),
    /// plus the query the Query Inspector's hand-built dropped-operand fixture was once taken from.
    static let namedCases: [Issue1297StructuredCase] = {
        let c = Issue1297StructuredCorpus.W("cold"), w = Issue1297StructuredCorpus.W("war")
        let k = Issue1297StructuredCorpus.W("korea"), v = Issue1297StructuredCorpus.W("vietnam")
        let notWord = Issue1297StructuredCorpus.W("not"), near = Issue1297StructuredCorpus.nearRows
        let cw = Issue1297StructuredCorpus.P("cold war"), vi = Issue1297StructuredCorpus.X("viet")
        let europe = Issue1297StructuredCorpus.W("europe"), formosa = Issue1297StructuredCorpus.W("formosa")
        let nothing = Issue1297StructuredCorpus.W("zzznothing")
        func N(_ rows: Set<Int>) -> Set<Int> { Issue1297StructuredCorpus.N(rows) }

        let phrase = StructuredQueryParts(phrase: "cold war")
        let prefix = StructuredQueryParts(prefixWildcard: "viet")
        let cold = typedOperand("cold", "\"cold\"", .word, negated: false)
        let war = typedOperand("war", "\"war\"", .word, negated: false)
        let korea = typedOperand("korea", "\"korea\"", .word, negated: false)
        let notKorea = typedOperand("korea", "NOT \"korea\"", .word, negated: true)
        let notVietnam = typedOperand("vietnam", "NOT \"vietnam\"", .word, negated: true)
        let notWar = typedOperand("war", "NOT \"war\"", .word, negated: true)
        let coldWar = structuredOperand("cold war", "\"cold war\"", .phrase, negated: false)
        let viet = structuredOperand("viet*", "\"viet\"*", .prefix, negated: false)

        return [
            // Finding 1: a typed complement with no anchor of its own, beside a phrase or prefix.
            Issue1297StructuredCase(typed: "-korea", structured: phrase,
                                    expression: "\"cold war\" NOT \"korea\"", meaning: cw.subtracting(k),
                                    operands: [notKorea, coldWar]),
            Issue1297StructuredCase(typed: "NOT korea", structured: phrase,
                                    expression: "\"cold war\" NOT \"korea\"", meaning: cw.subtracting(k),
                                    operands: [notKorea, coldWar]),
            Issue1297StructuredCase(typed: "-korea -vietnam", structured: phrase,
                                    expression: "\"cold war\" NOT (\"korea\" OR \"vietnam\")",
                                    meaning: cw.subtracting(k).subtracting(v),
                                    operands: [notKorea, notVietnam, coldWar]),
            Issue1297StructuredCase(typed: "-korea", structured: prefix,
                                    expression: "\"viet\"* NOT \"korea\"", meaning: vi.subtracting(k),
                                    operands: [notKorea, viet]),
            Issue1297StructuredCase(typed: "-korea OR -vietnam", structured: phrase,
                                    expression: "\"cold war\" NOT (\"korea\" AND \"vietnam\")",
                                    meaning: cw.intersection(N(k.intersection(v))),
                                    operands: [notKorea, notVietnam, coldWar]),
            // A structured exclusion is no anchor: nothing positive anywhere, so still nothing to run.
            Issue1297StructuredCase(typed: "-korea", structured: StructuredQueryParts(excludedTerms: ["vietnam"]),
                                    expression: nil, meaning: N(k).intersection(N(v))),
            Issue1297StructuredCase(typed: "-korea", structured: StructuredQueryParts(phrase: "cold war", excludedTerms: ["vietnam"]),
                                    expression: "\"cold war\" NOT \"korea\" NOT \"vietnam\"",
                                    meaning: cw.subtracting(k).subtracting(v),
                                    operands: [notKorea, coldWar,
                                               structuredOperand("vietnam", "NOT \"vietnam\"", .word, negated: true)]),
            Issue1297StructuredCase(typed: "-korea", structured: phrase, scoped: true,
                                    expression: "\"cold war\" NOT {body_text}:\"korea\"", meaning: cw.subtracting(k),
                                    operands: [typedOperand("korea", "NOT {body_text}:\"korea\"", .word, negated: true), coldWar]),
            // Finding 2: a typed complement that anchors alone, beside a phrase or prefix, is exact.
            Issue1297StructuredCase(typed: "cold OR -korea", structured: prefix,
                                    expression: "\"viet\"* NOT (\"korea\" NOT \"cold\")",
                                    meaning: vi.intersection(c.union(N(k))),
                                    operands: [cold, notKorea, viet]),
            Issue1297StructuredCase(typed: "cold OR -korea", structured: prefix, scoped: true,
                                    expression: "{body_text}:\"viet\"* NOT ({body_text}:\"korea\" NOT {body_text}:\"cold\")",
                                    meaning: vi.intersection(c.union(N(k))),
                                    operands: [typedOperand("cold", "{body_text}:\"cold\"", .word, negated: false),
                                               typedOperand("korea", "NOT {body_text}:\"korea\"", .word, negated: true),
                                               structuredOperand("viet*", "{body_text}:\"viet\"*", .prefix, negated: false)]),
            Issue1297StructuredCase(typed: "cold OR -korea", structured: phrase,
                                    expression: "\"cold war\" NOT (\"korea\" NOT \"cold\")",
                                    meaning: cw.intersection(c.union(N(k))),
                                    operands: [cold, notKorea, coldWar]),
            Issue1297StructuredCase(typed: "cold OR -korea", structured: StructuredQueryParts(excludedTerms: ["vietnam"]),
                                    expression: "\"cold\" NOT \"vietnam\"",
                                    meaning: c.union(N(k)).subtracting(v), approximation: c.subtracting(v),
                                    operands: [cold, structuredOperand("vietnam", "NOT \"vietnam\"", .word, negated: true)],
                                    dropped: [notKorea], isApproximate: true),
            Issue1297StructuredCase(typed: "cold OR -korea", expression: "\"cold\"",
                                    meaning: c.union(N(k)), approximation: c,
                                    operands: [cold], dropped: [notKorea], isApproximate: true),
            // Finding 3: a complement is pushed inward, so its positive operands are applied.
            Issue1297StructuredCase(typed: "cold OR -(war -korea)", expression: "\"cold\" OR \"korea\"",
                                    meaning: c.union(N(w)).union(k), approximation: c.union(k),
                                    operands: [cold, korea], dropped: [notWar], isApproximate: true),
            Issue1297StructuredCase(typed: "cold OR NOT (war -korea)", expression: "\"cold\" OR \"korea\"",
                                    meaning: c.union(N(w)).union(k), approximation: c.union(k),
                                    operands: [cold, korea], dropped: [notWar], isApproximate: true),
            Issue1297StructuredCase(typed: "-(war -korea)", expression: "\"korea\"",
                                    meaning: N(w).union(k), approximation: k,
                                    operands: [korea], dropped: [notWar], isApproximate: true),
            Issue1297StructuredCase(typed: "-(war -korea) -vietnam", expression: "\"korea\" NOT \"vietnam\"",
                                    meaning: N(w).union(k).subtracting(v), approximation: k.subtracting(v),
                                    operands: [korea, notVietnam], dropped: [notWar], isApproximate: true),
            Issue1297StructuredCase(typed: "cold OR -((war -korea) OR vietnam)",
                                    expression: "\"cold\" OR \"korea\" NOT \"vietnam\"",
                                    meaning: c.union(N(w).union(k).subtracting(v)),
                                    approximation: c.union(k.subtracting(v)),
                                    operands: [cold, korea, notVietnam], dropped: [notWar], isApproximate: true),
            Issue1297StructuredCase(typed: "cold OR -(war -korea)", structured: phrase,
                                    expression: "\"cold war\" NOT ((\"war\" NOT \"korea\") NOT \"cold\")",
                                    meaning: cw.intersection(c.union(N(w)).union(k)),
                                    operands: [cold, notWar, korea, coldWar]),
            Issue1297StructuredCase(typed: "cold OR -(korea OR vietnam)", expression: "\"cold\"",
                                    meaning: c.union(N(k).intersection(N(v))), approximation: c,
                                    operands: [cold], dropped: [notKorea, notVietnam], isApproximate: true),
            Issue1297StructuredCase(typed: "cold OR -(war korea)", expression: "\"cold\"",
                                    meaning: c.union(N(w)).union(N(k)), approximation: c,
                                    operands: [cold], dropped: [notWar, notKorea], isApproximate: true),
            // Finding 4: a kept alternative keeps its own exclusion among the applied operands.
            Issue1297StructuredCase(typed: "cold -korea OR -vietnam", expression: "\"cold\" NOT \"korea\"",
                                    meaning: c.subtracting(k).union(N(v)), approximation: c.subtracting(k),
                                    operands: [cold, notKorea], dropped: [notVietnam], isApproximate: true),
            Issue1297StructuredCase(typed: "war -korea OR -vietnam OR cold", expression: "\"war\" NOT \"korea\" OR \"cold\"",
                                    meaning: w.subtracting(k).union(N(v)).union(c), approximation: w.subtracting(k).union(c),
                                    operands: [war, notKorea, cold], dropped: [notVietnam], isApproximate: true),
            Issue1297StructuredCase(typed: "cold -korea OR -vietnam", structured: prefix,
                                    expression: "\"viet\"* NOT (\"vietnam\" NOT (\"cold\" NOT \"korea\"))",
                                    meaning: vi.intersection(c.subtracting(k).union(N(v))),
                                    operands: [cold, notKorea, notVietnam, viet]),
            // The owner's root rule, unchanged; and the same query made exact by a prefix.
            Issue1297StructuredCase(typed: "(cold OR -korea) (war OR -vietnam)", expression: "(\"cold\") AND (\"war\")",
                                    meaning: c.union(N(k)).intersection(w.union(N(v))), approximation: c.intersection(w),
                                    operands: [cold, war], dropped: [notKorea, notVietnam], isApproximate: true),
            Issue1297StructuredCase(typed: "(cold OR -korea) (war OR -vietnam)", structured: prefix,
                                    expression: "\"viet\"* NOT (\"korea\" NOT \"cold\" OR \"vietnam\" NOT \"war\")",
                                    meaning: vi.intersection(c.union(N(k))).intersection(w.union(N(v))),
                                    operands: [cold, notKorea, war, notVietnam, viet]),
            // Left out with no operand to report: only isApproximate says so.
            Issue1297StructuredCase(typed: "-( -korea NOT )", expression: "\"korea\"",
                                    meaning: N(notWord.subtracting(k)), approximation: k,
                                    operands: [korea], isApproximate: true),
            Issue1297StructuredCase(typed: "cold OR NOT (NOT)", expression: "\"cold\"",
                                    meaning: c.union(N(notWord)), approximation: c,
                                    operands: [cold], isApproximate: true),
            Issue1297StructuredCase(typed: "-(cold OR war) -korea", expression: nil,
                                    meaning: N(c.union(w)).subtracting(k)),
            // Renders FTS5Query 2.2 already produced.
            Issue1297StructuredCase(typed: "cold OR war",
                                    structured: StructuredQueryParts(phrase: "cold war", prefixWildcard: "viet", excludedTerms: ["korea"]),
                                    expression: "((\"cold\" OR \"war\") AND \"cold war\" AND \"viet\"*) NOT \"korea\"",
                                    meaning: c.union(w).intersection(cw).intersection(vi).subtracting(k),
                                    operands: [cold, war, coldWar, viet,
                                               structuredOperand("korea", "NOT \"korea\"", .word, negated: true)]),
            Issue1297StructuredCase(typed: "NEAR(cold war, 5)", structured: StructuredQueryParts(excludedTerms: ["korea"]),
                                    expression: "NEAR(\"cold\" \"war\", 5) NOT \"korea\"", meaning: near.subtracting(k),
                                    operands: [typedOperand("NEAR( cold war, 5 )", "NEAR(\"cold\" \"war\", 5)", .proximity, negated: false),
                                               structuredOperand("korea", "NOT \"korea\"", .word, negated: true)]),
            Issue1297StructuredCase(typed: "NOT NEAR(cold war, 5)", structured: prefix,
                                    expression: "\"viet\"* NOT NEAR(\"cold\" \"war\", 5)", meaning: vi.subtracting(near),
                                    operands: [typedOperand("NEAR( cold war, 5 )", "NOT NEAR(\"cold\" \"war\", 5)", .proximity, negated: true),
                                               viet]),
            Issue1297StructuredCase(typed: "NEAR(cold war, 5)", structured: phrase, scoped: true,
                                    expression: "{body_text}:NEAR(\"cold\" \"war\", 5) AND \"cold war\"",
                                    meaning: near.intersection(cw),
                                    operands: [typedOperand("NEAR( cold war, 5 )", "{body_text}:NEAR(\"cold\" \"war\", 5)",
                                                            .proximity, negated: false),
                                               coldWar]),
            Issue1297StructuredCase(typed: "", structured: StructuredQueryParts(phrase: "cold war", excludedTerms: ["vietnam"]),
                                    expression: "\"cold war\" NOT \"vietnam\"", meaning: cw.subtracting(v),
                                    operands: [coldWar, structuredOperand("vietnam", "NOT \"vietnam\"", .word, negated: true)]),
            Issue1297StructuredCase(typed: "cold", structured: StructuredQueryParts(excludedTerms: ["cold war"]),
                                    expression: "\"cold\" NOT \"cold war\"", meaning: c.subtracting(cw),
                                    operands: [cold, structuredOperand("cold war", "NOT \"cold war\"", .phrase, negated: true)]),
            Issue1297StructuredCase(typed: "=cold OR -korea", structured: prefix,
                                    expression: "\"viet\"* NOT (\"korea\" NOT \"cold\")",
                                    meaning: vi.intersection(c.union(N(k))),
                                    operands: [typedOperand("cold", "\"cold\"", .word, negated: false, exact: true), notKorea, viet],
                                    exactTerms: ["cold"]),
            Issue1297StructuredCase(typed: "war (cold OR -korea)", structured: prefix,
                                    expression: "(\"war\" NOT (\"korea\" NOT \"cold\")) AND \"viet\"*",
                                    meaning: vi.intersection(w).intersection(c.union(N(k))),
                                    operands: [war, cold, notKorea, viet]),
            Issue1297StructuredCase(typed: "-korea cold", structured: phrase, scoped: true,
                                    expression: "({body_text}:\"cold\" NOT {body_text}:\"korea\") AND \"cold war\"",
                                    meaning: cw.intersection(c).subtracting(k),
                                    operands: [typedOperand("korea", "NOT {body_text}:\"korea\"", .word, negated: true),
                                               typedOperand("cold", "{body_text}:\"cold\"", .word, negated: false), coldWar]),
            // The query `QueryInspectionTests.droppedOperandsAreNotApplied` once took its fixture from:
            // pushed inward, it applies the doubly negated zzznothing and leaves out only formosa.
            Issue1297StructuredCase(typed: "europe OR NOT (formosa -zzznothing)", expression: "\"europe\" OR \"zzznothing\"",
                                    meaning: europe.union(N(formosa)).union(nothing), approximation: europe.union(nothing),
                                    operands: [typedOperand("europe", "\"europe\"", .word, negated: false),
                                               typedOperand("zzznothing", "\"zzznothing\"", .word, negated: false)],
                                    dropped: [typedOperand("formosa", "NOT \"formosa\"", .word, negated: true)],
                                    isApproximate: true),
        ]
    }()

    /// Each named case renders its bytes, matches its set, and reports every operand where it belongs.
    @Test("A typed query beside structured fields renders, matches and reports what the judged table says",
          arguments: Issue1297StructuredPartsTests.namedCases)
    func namedCombinations(_ c: Issue1297StructuredCase) throws {
        #expect(Self.namedCases.count == 39)
        let table = Issue1297StructuredTable(twoColumn: c.scoped)
        let parsed = FTS5InlineQueryParser.parseDetailed(c.typed, columnPrefix: c.scoped ? "{body_text}:" : "",
                                                         structured: c.structured)
        let isExact = !c.meaning.contains(1)
        let expectedRows = isExact ? c.meaning : c.approximation
        // The case must agree with itself before the parser is asked anything.
        #expect((c.expression == nil) == (expectedRows == nil), "fixture: an expression exactly when rows are expected")
        #expect(c.isApproximate == (c.expression != nil && !isExact), "fixture: approximate exactly when narrower")

        #expect(parsed.expression == c.expression)
        if let expression = parsed.expression {
            let got = try table.rows(expression)
            #expect(got == expectedRows, "\(expression) matched \(got.sorted())")
            #expect(got.isSubset(of: c.meaning))
        }
        #expect(parsed.operands == c.operands)
        #expect(parsed.droppedOperands == c.dropped)
        #expect(parsed.exactTerms == c.exactTerms)
        #expect(parsed.isApproximate == c.isApproximate)
    }

    /// Finding 4, pinned by whole-value equality so no field of a kept or dropped operand is unchecked.
    @Test("A kept OR alternative keeps its own exclusion as an applied operand; only the left-out alternative is dropped")
    func keptAlternativesKeepTheirExclusions() {
        let cold = typedOperand("cold", "\"cold\"", .word, negated: false)
        let notKorea = typedOperand("korea", "NOT \"korea\"", .word, negated: true)
        let notVietnam = typedOperand("vietnam", "NOT \"vietnam\"", .word, negated: true)
        #expect(FTS5InlineQueryParser.parseDetailed("cold -korea OR -vietnam")
                == ParsedQuery(expression: "\"cold\" NOT \"korea\"", exactTerms: [],
                               operands: [cold, notKorea], droppedOperands: [notVietnam], isApproximate: true))
        #expect(FTS5InlineQueryParser.parseDetailed("(cold -korea) OR -vietnam")
                == ParsedQuery(expression: "(\"cold\" NOT \"korea\")", exactTerms: [],
                               operands: [cold, notKorea], droppedOperands: [notVietnam], isApproximate: true))
        #expect(FTS5InlineQueryParser.parseDetailed("war -korea OR -vietnam OR cold")
                == ParsedQuery(expression: "\"war\" NOT \"korea\" OR \"cold\"", exactTerms: [],
                               operands: [typedOperand("war", "\"war\"", .word, negated: false), notKorea, cold],
                               droppedOperands: [notVietnam], isApproximate: true))
    }

    /// The structured fields every generated and swept query is combined with, in this order.
    static let combinations: [StructuredQueryParts] = [
        StructuredQueryParts(),
        StructuredQueryParts(phrase: "cold war"),
        StructuredQueryParts(prefixWildcard: "viet"),
        StructuredQueryParts(excludedTerms: ["korea"]),
        StructuredQueryParts(excludedTerms: ["korea", "vietnam"]),
        StructuredQueryParts(phrase: "cold war", excludedTerms: ["vietnam"]),
        StructuredQueryParts(prefixWildcard: "viet", excludedTerms: ["korea"]),
        StructuredQueryParts(phrase: "cold war", prefixWildcard: "viet"),
        StructuredQueryParts(phrase: "cold war", prefixWildcard: "viet", excludedTerms: ["korea"]),
        StructuredQueryParts(excludedTerms: ["cold war"]),
    ]

    // MARK: - The set oracle

    /// The generated query that runs with its structured fields beside it, and a failure log.
    ///
    /// Every expectation is built from `Issue1297OracleModel`, which knows sets and the owner's
    /// anchoring policy and never sees an FTS5 string.
    @Test("Generated queries beside every structured combination match the set oracle's rows, operands, drops, exact terms and approximation",
          arguments: [Issue1297StructuredOracleRun(seed: 1297, attachDash: false),
                      Issue1297StructuredOracleRun(seed: 1299, attachDash: true)])
    func structuredSetOracle(_ run: Issue1297StructuredOracleRun) throws {
        let unscopedTable = Issue1297StructuredTable(), scopedTable = Issue1297StructuredTable(twoColumn: true)
        var rng = Issue1297Random(state: run.seed)
        var events: [String: Int] = [:]
        var failures: [String: Int] = [:]
        var samples: [String] = []
        func fail(_ category: String, _ detail: String) {
            failures[category, default: 0] += 1
            if samples.count < 8 { samples.append("[\(category)] \(detail)") }
        }

        for queryIndex in 0..<4_000 {
            var generator = Issue1297OracleGenerator(rng: rng, attachDash: run.attachDash)
            let (text, typedModel) = generator.query(depth: 2)
            rng = generator.rng
            let typedHarvest = generator.harvest
            let typedCount = typedHarvest.texts.count
            var droppedAlone = Set<Int>()
            let typedLacks = Issue1297OracleModel.meaning(typedModel, typedHarvest).contains(1)
            let typedAlonePolicy = Issue1297OracleModel.policy(typedModel, negated: false, pushInward: true,
                                                               typedHarvest, dropped: &droppedAlone)

            for (combinationIndex, combination) in Self.combinations.enumerated() {
                let scoped = (queryIndex + combinationIndex) % 4 == 0
                let hasStructuredPositive = combination.phrase != nil || combination.prefixWildcard != nil
                var harvest = typedHarvest
                var parts: [Issue1297OracleModel] = [typedModel]
                if let phrase = combination.phrase {
                    parts.append(.leaf(harvest.add(phrase, .phrase, exact: false, .structured, Issue1297StructuredCorpus.P(phrase))))
                }
                if let prefix = combination.prefixWildcard {
                    parts.append(.leaf(harvest.add(prefix + "*", .prefix, exact: false, .structured, Issue1297StructuredCorpus.X(prefix))))
                }
                for term in combination.excludedTerms {
                    let isPhrase = term.contains(" ")
                    parts.append(.not(.leaf(harvest.add(term, isPhrase ? .phrase : .word, exact: false, .structured,
                                                        isPhrase ? Issue1297StructuredCorpus.P(term) : Issue1297StructuredCorpus.W(term)))))
                }
                let root = Issue1297OracleModel.and(parts)
                let meaning = Issue1297OracleModel.meaning(root, harvest)
                var dropped = Set<Int>(), droppedWithoutPush = Set<Int>()
                let policy = Issue1297OracleModel.policy(root, negated: false, pushInward: true, harvest, dropped: &dropped)
                let policyWithoutPush = Issue1297OracleModel.policy(root, negated: false, pushInward: false, harvest,
                                                                    dropped: &droppedWithoutPush)
                var parity: [Int: Bool] = [:]
                Issue1297OracleModel.parity(root, negated: false, into: &parity)
                let everyOperand = harvest.texts.indices.map {
                    Issue1297ModelOperand(text: harvest.texts[$0], isNegated: parity[$0] ?? false,
                                          kind: harvest.kinds[$0], source: harvest.sources[$0])
                }
                let expectedOperands = policy == nil ? [] : harvest.texts.indices.filter { !dropped.contains($0) }.map { everyOperand[$0] }
                let expectedDropped = policy == nil ? [] : harvest.texts.indices.filter { dropped.contains($0) }.map { everyOperand[$0] }
                var expectedExact: [String] = []
                if policy != nil, (0..<typedCount).contains(where: { harvest.exact[$0] && parity[$0] == false && !dropped.contains($0) }) {
                    expectedExact = ["cold"]
                }
                let expectedApproximate = policy != nil && meaning.contains(1)

                events["compared", default: 0] += 1
                if scoped { events["scoped", default: 0] += 1 }
                if !meaning.contains(1) {
                    events["exact", default: 0] += 1
                } else if policy != nil {
                    events["approximated", default: 0] += 1
                } else {
                    events["nil", default: 0] += 1
                }
                if typedLacks, hasStructuredPositive {
                    events[typedAlonePolicy == nil ? "finding1" : "finding2", default: 0] += 1
                }
                if policy != policyWithoutPush || dropped != droppedWithoutPush { events["pushInward", default: 0] += 1 }
                if !expectedDropped.isEmpty, expectedOperands.contains(where: { $0.isNegated && $0.source == .typed }) {
                    events["keptNegatedBesideDrops", default: 0] += 1
                }

                let parsed = FTS5InlineQueryParser.parseDetailed(text, columnPrefix: scoped ? "{body_text}:" : "",
                                                                 structured: combination)
                let label = "\(text) \(combination)\(scoped ? " scoped" : "") -> \(parsed.expression ?? "nil")"
                let gotOperands = parsed.operands.map(Issue1297ModelOperand.init)
                let gotDropped = parsed.droppedOperands.map(Issue1297ModelOperand.init)
                if gotOperands != expectedOperands { fail("operands", "\(label) got \(gotOperands) want \(expectedOperands)") }
                if gotDropped != expectedDropped { fail("droppedOperands", "\(label) got \(gotDropped) want \(expectedDropped)") }
                if parsed.exactTerms != expectedExact { fail("exactTerms", "\(label) got \(parsed.exactTerms) want \(expectedExact)") }
                if parsed.isApproximate != expectedApproximate { fail("isApproximate", "\(label) want \(expectedApproximate)") }
                if parsed.droppedOperands.contains(where: { !$0.isNegated }) { fail("positive operand dropped", label) }

                guard let expression = parsed.expression else {
                    if policy != nil { fail("nil where the policy anchors", label) }
                    continue
                }
                guard let wanted = policy else { fail("rendered where the policy has no anchor", label); continue }
                let got: Set<Int>
                do {
                    got = try (scoped ? scopedTable : unscopedTable).rows(expression)
                } catch {
                    fail("rejected", label)
                    continue
                }
                if !got.isSubset(of: meaning) { fail("superset of meaning", "\(label) got \(got.sorted())") }
                if got != wanted {
                    fail(meaning.contains(1) ? "rows != policy" : "rows != exact meaning",
                         "\(label) got \(got.sorted()) want \(wanted.sorted())")
                }
            }
        }

        let eventLine = events.keys.sorted().map { "\($0)=\(events[$0]!)" }.joined(separator: " ")
        let failureLine = failures.keys.sorted().map { "\($0)=\(failures[$0]!)" }.joined(separator: " ")
        print("[1297] structured oracle \(run.testDescription) \(eventLine) failures=\(failures.values.reduce(0, +)) \(failureLine)")
        #expect(events["compared"] == 40_000)
        #expect(events["scoped"] == 10_000)
        #expect(events["exact", default: 0] > 30_000)
        #expect(events["approximated", default: 0] > 5_000)
        #expect(events["nil", default: 0] > 800)
        #expect(events["finding1", default: 0] > 1_200)
        #expect(events["finding2", default: 0] > 8_000)
        #expect(events["pushInward", default: 0] > 1_000)
        #expect(events["keptNegatedBesideDrops", default: 0] > 4_500)
        #expect(failures.isEmpty, "\(samples)")
    }

    // MARK: - The combined sweep

    /// Every short token sequence beside every structured combination, checked by invariants and a
    /// metamorphic identity rather than by expected strings.
    @Test("Every token sequence of length 1-4 beside every structured combination is valid, reports consistently, and applies every typed operand beside a structured phrase or prefix",
          arguments: [false, true])
    func combinedSweep(scoped: Bool) throws {
        let table = Issue1297StructuredTable(twoColumn: scoped)
        let prefix = scoped ? "{body_text}:" : "", otherPrefix = scoped ? "" : "{body_text}:"
        let sequences = Issue1297PropertyTests.sequences(maxLength: 4, over: Issue1297PropertyTests.alphabet + ["-("])
        #expect(sequences.count == 11_110)
        let phraseRows = Issue1297StructuredCorpus.P("cold war"), prefixRows = Issue1297StructuredCorpus.X("viet")
        var compared = 0, executed = 0, metamorphic = 0, approximateWithoutDrops = 0
        var approximateWithoutDropsSequences = Set<String>()
        var failures: [String: Int] = [:]
        var samples: [String] = []
        func fail(_ category: String, _ detail: String) {
            failures[category, default: 0] += 1
            if samples.count < 8 { samples.append("[\(category)] \(detail)") }
        }
        func reporting(_ operands: [ParsedOperand]) -> [Issue1297ModelOperand] { operands.map(Issue1297ModelOperand.init) }

        for typed in sequences {
            // "memo" is in every row, so beside it every typed operand is applied and the rows are the
            // typed query's exact meaning.
            let anchored = FTS5InlineQueryParser.parseDetailed(typed, columnPrefix: prefix,
                                                               structured: StructuredQueryParts(phrase: "memo"))
            guard let anchoredExpression = anchored.expression,
                  let typedRows = try? table.rows(anchoredExpression) else {
                fail("memo anchor did not run", "\(typed) -> \(anchored.expression ?? "nil")")
                continue
            }
            let alone = FTS5InlineQueryParser.parseDetailed(typed, columnPrefix: prefix)

            for combination in Self.combinations {
                compared += 1
                let hasStructuredPositive = combination.phrase != nil || combination.prefixWildcard != nil
                let parsed = FTS5InlineQueryParser.parseDetailed(typed, columnPrefix: prefix, structured: combination)
                let other = FTS5InlineQueryParser.parseDetailed(typed, columnPrefix: otherPrefix, structured: combination)
                let label = "\(typed) \(combination) -> \(parsed.expression ?? "nil")"
                if reporting(parsed.operands) != reporting(other.operands)
                    || reporting(parsed.droppedOperands) != reporting(other.droppedOperands)
                    || parsed.exactTerms != other.exactTerms || parsed.isApproximate != other.isApproximate {
                    fail("reporting depends on the column prefix", label)
                }
                if parsed.droppedOperands.contains(where: { !$0.isNegated }) { fail("positive operand dropped", label) }
                if parsed.exactTerms != alone.exactTerms { fail("exactTerms differ from the typed-alone parse", label) }

                guard let expression = parsed.expression else {
                    if !parsed.operands.isEmpty || !parsed.droppedOperands.isEmpty || !parsed.exactTerms.isEmpty
                        || parsed.isApproximate {
                        fail("nil expression with something reported", label)
                    }
                    if hasStructuredPositive { fail("nil beside a structured positive", label) }
                    continue
                }
                executed += 1
                let got: Set<Int>
                do { got = try table.rows(expression) } catch { fail("rejected", label); continue }

                var expected = typedRows
                if combination.phrase != nil { expected.formIntersection(phraseRows) }
                if combination.prefixWildcard != nil { expected.formIntersection(prefixRows) }
                for term in combination.excludedTerms {
                    expected.subtract(term.contains(" ") ? Issue1297StructuredCorpus.P(term) : Issue1297StructuredCorpus.W(term))
                }
                if hasStructuredPositive {
                    metamorphic += 1
                    if got != expected { fail("rows beside a structured positive", "\(label) got \(got.sorted()) want \(expected.sorted())") }
                    if !parsed.droppedOperands.isEmpty { fail("dropped beside a structured positive", label) }
                    if parsed.isApproximate { fail("approximate beside a structured positive", label) }
                    if parsed.operands.filter({ $0.source == .typed }) != anchored.operands.filter({ $0.source == .typed }) {
                        fail("typed operands beside a structured positive are not the fully applied set", label)
                    }
                } else if !got.isSubset(of: expected) {
                    fail("superset without a structured positive", "\(label) got \(got.sorted())")
                }
                if parsed.isApproximate && parsed.droppedOperands.isEmpty {
                    approximateWithoutDrops += 1
                    approximateWithoutDropsSequences.insert(typed)
                }
            }
        }

        print("[1297] combined sweep scoped=\(scoped) compared=\(compared) executed=\(executed) metamorphic=\(metamorphic) approximateWithoutDrops=\(approximateWithoutDrops) failures=\(failures.values.reduce(0, +)) \(failures.keys.sorted().map { "\($0)=\(failures[$0]!)" }.joined(separator: " "))")
        #expect(compared == 111_100)
        #expect(executed == 107_408)
        #expect(metamorphic == 66_660)
        // Pushing negation inward can leave out nothing but a demoted operator word, which has no operand
        // to report. These five sequences, beside the four combinations with no positive, are all of them.
        #expect(approximateWithoutDrops == 20)
        #expect(approximateWithoutDropsSequences == ["-( -korea NOT )", "-( -korea AND )", "-( -korea OR )",
                                                     "-( AND -korea )", "-( OR -korea )"])
        #expect(failures.isEmpty, "\(samples)")
    }

    // MARK: - Decision (v)

    /// A structured exclusion keeps no column prefix: it removes a document whichever column holds the term.
    @Test("A structured excluded term spans every column, while a typed exclusion carries the scope")
    func structuredExclusionsSpanAllColumns() throws {
        let table = Issue1297StructuredTable(userContent: [(summary: "memo cold", note: "memo korea"),
                                                           (summary: "memo cold korea", note: ""),
                                                           (summary: "memo cold", note: "")])
        let structured = try #require(FTS5InlineQueryParser.parseDetailed(
            "cold", columnPrefix: "{summary_text}:", structured: StructuredQueryParts(excludedTerms: ["korea"])).expression)
        #expect(structured == "{summary_text}:\"cold\" NOT \"korea\"")
        #expect(try table.rows(structured) == [3])

        let typed = try #require(FTS5InlineQueryParser.parse("cold -korea", columnPrefix: "{summary_text}:"))
        #expect(typed == "{summary_text}:\"cold\" NOT {summary_text}:\"korea\"")
        #expect(try table.rows(typed) == [1, 3])
    }
}

// MARK: - The oracle's model

/// A set-oracle run: a seed, and whether negated groups may be spelled `-(`.
struct Issue1297StructuredOracleRun: Sendable, CustomTestStringConvertible {
    /// The generator seed.
    let seed: UInt64
    /// Whether a negated group's last mark may be an attached dash.
    let attachDash: Bool
    /// Names the run in the test report.
    var testDescription: String { "seed \(seed)\(attachDash ? ", -( groups" : "")" }
}

/// An operand as the oracle can know it: no rendered bytes, only what the query says.
struct Issue1297ModelOperand: Equatable, CustomStringConvertible {
    /// The operand's text.
    let text: String
    /// Its effective polarity.
    let isNegated: Bool
    /// Its kind.
    let kind: ParsedOperand.Kind
    /// Where it came from.
    let source: ParsedOperand.Source

    /// Creates a model operand.
    init(text: String, isNegated: Bool, kind: ParsedOperand.Kind, source: ParsedOperand.Source) {
        self.text = text
        self.isNegated = isNegated
        self.kind = kind
        self.source = source
    }

    /// Projects a parsed operand onto what the model knows.
    init(_ operand: ParsedOperand) {
        self.init(text: operand.text, isNegated: operand.isNegated, kind: operand.kind, source: operand.source)
    }

    /// A compact form for failure messages.
    var description: String { "\(source == .structured ? "S:" : "")\(text)\(isNegated ? "(-)" : "")" }
}

/// Every leaf the generator emitted, in textual order, with the rows each one matches.
struct Issue1297OracleHarvest {
    /// Each leaf's operand text.
    var texts: [String] = []
    /// Each leaf's kind.
    var kinds: [ParsedOperand.Kind] = []
    /// Whether each leaf carried `=`.
    var exact: [Bool] = []
    /// Where each leaf came from.
    var sources: [ParsedOperand.Source] = []
    /// The rows each leaf matches.
    var rows: [Set<Int>] = []

    /// Appends a leaf and returns its index.
    mutating func add(_ text: String, _ kind: ParsedOperand.Kind, exact isExact: Bool,
                      _ source: ParsedOperand.Source, _ matches: Set<Int>) -> Int {
        texts.append(text)
        kinds.append(kind)
        exact.append(isExact)
        sources.append(source)
        rows.append(matches)
        return texts.count - 1
    }
}

/// A query as the oracle models it, and the owner's anchoring policy over sets.
indirect enum Issue1297OracleModel {
    /// A harvested leaf.
    case leaf(Int)
    /// A complement.
    case not(Issue1297OracleModel)
    /// A conjunction.
    case and([Issue1297OracleModel])
    /// A disjunction.
    case or([Issue1297OracleModel])

    /// The rows `model` means.
    static func meaning(_ model: Issue1297OracleModel, _ harvest: Issue1297OracleHarvest) -> Set<Int> {
        switch model {
        case .leaf(let index): return harvest.rows[index]
        case .not(let inner): return Issue1297StructuredCorpus.N(meaning(inner, harvest))
        case .and(let members): return members.reduce(Issue1297StructuredCorpus.all) { $0.intersection(meaning($1, harvest)) }
        case .or(let members): return members.reduce(Set<Int>()) { $0.union(meaning($1, harvest)) }
        }
    }

    /// The rows `model` means under `negated` more negations.
    static func effective(_ model: Issue1297OracleModel, negated: Bool, _ harvest: Issue1297OracleHarvest) -> Set<Int> {
        negated ? Issue1297StructuredCorpus.N(meaning(model, harvest)) : meaning(model, harvest)
    }

    /// Whether `model` holds a leaf that is positive after the negations above it.
    static func hasPositiveLeaf(_ model: Issue1297OracleModel, negated: Bool = false) -> Bool {
        switch model {
        case .leaf: return !negated
        case .not(let inner): return hasPositiveLeaf(inner, negated: !negated)
        case .and(let members), .or(let members): return members.contains { hasPositiveLeaf($0, negated: negated) }
        }
    }

    /// Every leaf index under `model`.
    static func leaves(_ model: Issue1297OracleModel) -> [Int] {
        switch model {
        case .leaf(let index): return [index]
        case .not(let inner): return leaves(inner)
        case .and(let members), .or(let members): return members.flatMap(leaves)
        }
    }

    /// Each leaf's polarity: whether an odd number of negations sits above it.
    static func parity(_ model: Issue1297OracleModel, negated: Bool, into map: inout [Int: Bool]) {
        switch model {
        case .leaf(let index): map[index] = negated
        case .not(let inner): parity(inner, negated: !negated, into: &map)
        case .and(let members), .or(let members): for member in members { parity(member, negated: negated, into: &map) }
        }
    }

    /// The rows the owner's policy searches for `model` under `negated`, or `nil` when nothing anchors,
    /// with the leaves it leaves out added to `dropped`.
    ///
    /// Row 1 holds no query term, so a set containing it is a complement FTS5 cannot search on its own.
    /// A conjunction (or a negated disjunction) approximates what anchors and excludes the rest exactly;
    /// a disjunction (or a negated conjunction) keeps what anchors and leaves out every leaf of the rest.
    /// `pushInward: false` is the rule before negation was pushed into a complement, kept to count how
    /// often pushing changes the answer.
    static func policy(_ model: Issue1297OracleModel, negated: Bool, pushInward: Bool,
                       _ harvest: Issue1297OracleHarvest, dropped: inout Set<Int>) -> Set<Int>? {
        let rows = effective(model, negated: negated, harvest)
        if !rows.contains(1) { return rows }
        switch model {
        case .leaf:
            return nil
        case .not(let inner):
            return pushInward ? policy(inner, negated: !negated, pushInward: pushInward, harvest, dropped: &dropped) : nil
        case .and(let members) where !negated, .or(let members) where negated:
            var approximation: Set<Int>?
            var excluded = Issue1297StructuredCorpus.all
            var local = Set<Int>()
            for member in members {
                var memberDropped = Set<Int>()
                if let anchored = policy(member, negated: negated, pushInward: pushInward, harvest, dropped: &memberDropped) {
                    approximation = approximation.map { $0.intersection(anchored) } ?? anchored
                    local.formUnion(memberDropped)
                } else {
                    excluded.formIntersection(effective(member, negated: negated, harvest))
                }
            }
            guard let approximation else { return nil }
            dropped.formUnion(local)
            return approximation.intersection(excluded)
        case .and(let members), .or(let members):
            var kept: Set<Int>?
            for member in members {
                var memberDropped = Set<Int>()
                if let anchored = policy(member, negated: negated, pushInward: pushInward, harvest, dropped: &memberDropped) {
                    kept = (kept ?? []).union(anchored)
                    dropped.formUnion(memberDropped)
                } else {
                    dropped.formUnion(leaves(member))
                }
            }
            return kept
        }
    }
}

/// Generates a query's text and its model together, from one random stream.
///
/// Leaves are a vocabulary word (7 in 14), `=cold` (1), the phrase "cold war" (2), `viet*` (2) or
/// `NEAR(cold war, 5)` (2). A negated leaf carries one or two marks, and a `NEAR` only `NOT`. A
/// negated group is modelled as a complement only when it holds a positive leaf, because marks that
/// reach no positive term change nothing.
struct Issue1297OracleGenerator {
    /// The random stream, handed back to the caller after each query.
    var rng: Issue1297Random
    /// Whether a negated group's last mark may be an attached dash.
    let attachDash: Bool
    /// The leaves emitted so far.
    var harvest = Issue1297OracleHarvest()

    /// Creates a generator.
    init(rng: Issue1297Random, attachDash: Bool) {
        self.rng = rng
        self.attachDash = attachDash
    }

    /// A leaf: its text, its model, and whether it is a `NEAR`.
    mutating func leaf() -> (text: String, model: Issue1297OracleModel, isNear: Bool) {
        switch rng.below(14) {
        case 0...6:
            let word = Issue1297Corpus.vocabulary[rng.below(4)]
            return (word, .leaf(harvest.add(word, .word, exact: false, .typed, Issue1297StructuredCorpus.W(word))), false)
        case 7:
            return ("=cold", .leaf(harvest.add("cold", .word, exact: true, .typed, Issue1297StructuredCorpus.W("cold"))), false)
        case 8, 9:
            return ("\"cold war\"", .leaf(harvest.add("cold war", .phrase, exact: false, .typed, Issue1297StructuredCorpus.P("cold war"))), false)
        case 10, 11:
            return ("viet*", .leaf(harvest.add("viet*", .prefix, exact: false, .typed, Issue1297StructuredCorpus.X("viet"))), false)
        default:
            return ("NEAR(cold war, 5)",
                    .leaf(harvest.add("NEAR( cold war, 5 )", .proximity, exact: false, .typed, Issue1297StructuredCorpus.nearRows)), true)
        }
    }

    /// A group (sometimes negated), a negated leaf, or a bare leaf.
    mutating func item(depth: Int) -> (text: String, model: Issue1297OracleModel) {
        let roll = rng.below(10)
        if depth > 0, roll < 3 {
            let (inner, model) = query(depth: depth - 1)
            guard roll == 0 else { return ("(" + inner + ")", model) }
            let marks = 1 + rng.below(2)
            let dash = attachDash && rng.below(2) == 0
            let keywords = (0..<(dash ? marks - 1 : marks)).map { _ in Issue1297QueryGenerator.keyword("NOT", &rng) + " " }.joined()
            return (keywords + (dash ? "-(" : "(") + inner + ")",
                    Issue1297OracleModel.hasPositiveLeaf(model) ? .not(model) : model)
        }
        let (text, model, isNear) = leaf()
        guard roll < 6 else { return (text, model) }
        var marks = (0..<rng.below(2)).map { _ in Issue1297QueryGenerator.keyword("NOT", &rng) + " " }.joined()
        if !isNear, rng.below(2) == 0 {
            marks += "-"
        } else {
            marks += Issue1297QueryGenerator.keyword("NOT", &rng) + " "
        }
        return (marks + text, .not(model))
    }

    /// One to three items joined by a space or a randomly cased AND.
    mutating func run(depth: Int) -> (text: String, model: Issue1297OracleModel) {
        var (text, model) = item(depth: depth)
        var members = [model]
        for _ in 0..<rng.below(3) {
            let (next, nextModel) = item(depth: depth)
            text += (rng.below(2) == 0 ? " " : " " + Issue1297QueryGenerator.keyword("AND", &rng) + " ") + next
            members.append(nextModel)
        }
        if members.count > 1 { model = .and(members) }
        return (text, model)
    }

    /// One to three runs joined by a randomly cased OR.
    mutating func query(depth: Int) -> (text: String, model: Issue1297OracleModel) {
        var (text, model) = run(depth: depth)
        var members = [model]
        for _ in 0..<rng.below(3) {
            let (next, nextModel) = run(depth: depth)
            text += " " + Issue1297QueryGenerator.keyword("OR", &rng) + " " + next
            members.append(nextModel)
        }
        if members.count > 1 { model = .or(members) }
        return (text, model)
    }
}
