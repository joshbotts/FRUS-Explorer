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

/// Every combination of the words a length-1–4 sweep can put in an approximation, so a render that matches nothing
/// here matches nothing by construction, not because the truth table lacks a row.
///
/// The truth table holds "and", "or" and "not" only beside "memo", so `"cold" AND "not"` matches none of its rows
/// while matching plenty of real documents. Here every subset of cold, war, korea, vietnam, and, or and not follows
/// "memo", and a subset holding both cold and war appears twice — once as the phrase "cold war", once not.
///
/// Version history:
///   1.0 — #1297 fixes: initial implementation
enum Issue1297UniversalCorpus {
    /// The words a swept approximation or structured exclusion can hold.
    static let words = ["cold", "war", "korea", "vietnam", "and", "or", "not"]

    /// Row bodies; index 0 holds rowid 1.
    static let bodies: [String] = (0..<(1 << words.count)).flatMap { mask -> [String] in
        let subset = words.enumerated().filter { mask & (1 << $0.offset) != 0 }.map(\.element)
        let adjacent = (["memo"] + subset).joined(separator: " ")
        guard subset.contains("cold"), subset.contains("war") else { return [adjacent] }
        return [adjacent, (["memo", "war"] + subset.filter { $0 != "cold" && $0 != "war" } + ["cold"]).joined(separator: " ")]
    }
}

/// `Issue1297UniversalCorpus` with cold in two spellings, so a filter on the literal word cold is observable.
///
/// The universal corpus holds only uninflected words, so there every row a stemmed `"cold"` matches holds the literal
/// word, and an exact-word filter removes nothing whatever it is applied to. Here each universal row holding cold is kept
/// with a marker word beside it, `xcoldexact`, and also appears once more with cold spelled `colds`, which the Porter
/// stemmer folds into cold and `ExactWordMatcher` does not. The marker is how the sweep searches for the literal word
/// through FTS5: a query with `=cold` spelled `xcoldexact` renders in the same shape, and matches exactly the rows a
/// cold filter keeps.
///
/// Version history:
///   1.0 — #1297 round-2 parser tests: initial implementation
///   1.1 — #1297 round-4 parser tests: `literal(_:)` respells every mark on the index word cold, whatever its spelling
///          (`=Cold`, `=cold.`), and `indexWord(_:)`
enum Issue1297InflectedCorpus {
    /// The word standing for "the literal word cold" in a respelled query.
    static let literalMarker = "xcoldexact"

    /// Row bodies; index 0 holds rowid 1.
    static let bodies: [String] = Issue1297UniversalCorpus.bodies.flatMap { body -> [String] in
        let tokens = body.split(separator: " ").map(String.init)
        guard tokens.contains("cold") else { return [body] }
        return [body + " " + literalMarker, tokens.map { $0 == "cold" ? "colds" : $0 }.joined(separator: " ")]
    }

    /// `typed` with every `=` mark on the index word cold — `=cold`, `=Cold`, `=cold.` — spelled as the marker, the
    /// same exclusion mark kept: the query whose marks on cold match only the literal word.
    static func literal(_ typed: String) -> String {
        typed.split(separator: " ").map { token in
            if token.hasPrefix("="), indexWord(String(token.dropFirst())) == "cold" { return literalMarker }
            if token.hasPrefix("-="), indexWord(String(token.dropFirst(2))) == "cold" { return "-" + literalMarker }
            return String(token)
        }.joined(separator: " ")
    }

    /// The index words of `text`, as the exact-word filter reads them: what makes two spellings one word.
    static func indexWord(_ text: String) -> String {
        ExactWordMatcher.tokens(in: text).joined(separator: " ")
    }
}

/// An in-memory `porter unicode61` FTS5 table, queried for rowids.
final class Issue1297StructuredTable {
    /// The open database handle.
    private var db: OpaquePointer?
    /// The FTS5 table's name.
    private let name: String

    /// The corpus as `d(body_text)`, or with `twoColumn` as `d2(header, body_text)` under the constant header
    /// 'heading'. That gives a `{body_text}:` prefix a column to name, but the header holds no query word, so a render
    /// that lost its prefix matches the same rows: `init(headed:)` is the table that tells the two apart.
    convenience init(twoColumn: Bool = false) {
        self.init(bodies: Issue1297StructuredCorpus.bodies, twoColumn: twoColumn)
    }

    /// `bodies` in order from rowid 1, in the same one- or two-column shape.
    init(bodies: [String], twoColumn: Bool = false) {
        name = twoColumn ? "d2" : "d"
        sqlite3_open(":memory:", &db)
        sqlite3_exec(db, twoColumn
            ? "CREATE VIRTUAL TABLE d2 USING fts5(header, body_text, tokenize='porter unicode61');"
            : "CREATE VIRTUAL TABLE d USING fts5(body_text, tokenize='porter unicode61');", nil, nil, nil)
        for (index, body) in bodies.enumerated() {
            insert(twoColumn ? "INSERT INTO d2(rowid, header, body_text) VALUES (?, 'heading', ?);"
                             : "INSERT INTO d(rowid, body_text) VALUES (?, ?);",
                   rowid: index + 1, values: [body])
        }
    }

    /// `d2(header, body_text)` holding `rows` in order from rowid 1, each row with a header of its own.
    init(headed rows: [(header: String, body: String)]) {
        name = "d2"
        sqlite3_open(":memory:", &db)
        sqlite3_exec(db, "CREATE VIRTUAL TABLE d2 USING fts5(header, body_text, tokenize='porter unicode61');",
                     nil, nil, nil)
        for (index, row) in rows.enumerated() {
            insert("INSERT INTO d2(rowid, header, body_text) VALUES (?, ?, ?);", rowid: index + 1, values: [row.header, row.body])
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

/// A typed operand, every field spelled out: `applied` when the search post-filters on its literal word.
private func typedOperand(_ text: String, _ rendered: String, _ kind: ParsedOperand.Kind,
                          negated: Bool, exact: Bool = false, applied: Bool = false) -> ParsedOperand {
    ParsedOperand(text: text, rendered: rendered, kind: kind, isNegated: negated, isExact: exact, source: .typed,
                  isExactApplied: applied)
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
///   1.1 — #1297 fixes: parser 6.1's refusal of an approximation that provably matches nothing — eleven named
///          cases, the oracle's proof mirror, and combinedSweep's count against a universal corpus; the exact-term
///          sweep over `=cold` and `-=cold`, because combinedSweep's alphabet carries no `=`
///   1.2 — #1297 fixes review: parser 6.2 scopes a demoted operator word, so `(NOT OR -korea) -not` is refused in both
///          scopes and the scope guard is now the typed phrase "korea", which still spans every column;
///          `refusalAcrossScopesSweep`; and `combinedSweep` fails a refusal that depends on the column prefix
///   1.3 — #1297 round-1 fixes: parser 6.3's exact-term rule (D1) — the oracle expects an `=` term only when the root
///          proof requires it, `exactTermsSweep` checks soundness and completeness on the universal corpus instead of
///          equality with the positive applied operands, and eight named cases pin it (F26); named cases for the
///          `conjoin` and `disjoin` proof combinators and the approximate AND-run's bytes; and
///          `columnPrefixScopesEveryTypedOperand` with `columnPrefixNamedRows`, over headers holding query words,
///          because every scoped sweep ran under a constant header that made a lost column prefix invisible (F5).
///          Measured at parser 6.3: the exact-term sweep reports 31,082 lists per scope, 1,198 applied `=cold` operands
///          unreported because a match need not hold cold and 1,492 unreported although every match does; the oracle
///          sees 1,952 and 1,692 required exact operands against 10,996 and 10,743 ignored; the column-prefix sweep
///          compares 10,183 and 11,110 renders, 8,601 and 9,139 of them over a header that changes the unscoped rows
///   1.4 — #1297 round-2 parser tests: D1 by occurrence (P1) — eleven named cases where an unmarked word, a one-word
///          phrase or a second marked word shares an `=` operand's stem, in both scopes where the phrase decides it;
///          `exactTermsSweep` adds the unmarked cold and the phrase "cold" to its alphabet and checks soundness by
///          `ExactWordMatcher` on `Issue1297InflectedCorpus`, whose `colds` rows a stemmed cold matches and a literal
///          filter removes; the oracle's key carries the mark and its proof follows marked leaves by occurrence; and
///          the mirror of the `conjoin` named case (P4). With parser 6.4 the named cases, the oracle and the sweep also
///          check `ParsedOperand.isExactApplied` operand by operand. Measured at 6.4: the exact-term sweep reports 55,078
///          lists per scope, 4,286 applied `=cold` operands unreported because filtering on them would remove a row the
///          query admits and 868 unreported although it would not; the oracle sees 1,190 and 1,034 required exact
///          operands against 11,758 and 11,401 ignored
///   1.5 — #1297 round-3 parser tests: D4 — requiredness is proved over the identities of MARKED operands, so a word
///          marked in every alternative is reported (`=cold war OR =cold peace`, `=cold OR =cold war`, `=cold OR =cold`)
///          and every positive `=` operand on it applies (`(=cold OR war) =cold` is now applied twice), while an unmarked
///          word, a phrase or an excluded mark in one alternative still reports nothing (`=cold war OR peace -=cold`);
///          the oracle's proof mirror follows marked stems instead of occurrences, and `exactTermsSweep`'s completeness
///          pin moves with it. Named cases also pin the 6.1 refusal of an empty `OR` inside a kept alternative, which
///          only the oracle caught (round-2 M13), and a typed `=cold` beside a structured phrase and prefix, which only
///          the sweep and the oracle caught (round-2 M05). Measured at parser 6.5: the exact-term sweep reports 55,518
///          lists per scope, 4,286 applied `=cold` operands unreported because filtering on them would remove a row the
///          query admits and 428 unreported although it would not; the oracle sees 1,256 and 1,151 required exact
///          operands against 11,692 and 11,284 ignored
///   1.6 — #1297 round-4 parser tests: marks are compared by index word, never spelling (Q1). `exactTermsSweep` runs a
///          second alphabet, `=cold`, `=Cold`, `=cold.` and `-=Cold` beside cold, war and the operators, in both
///          scopes, and checks that positive marks on one word apply together and that the terms are one per word in
///          its first spelling; `exactFilterReadsIndexWords` executes `cold.`, `Cold`, `café` and `cafe` marks against
///          rows holding `colds` and `cafés`; three named cases pin the spellings, and four pin the round-3 attack's
///          survivors and oracle-only kills (D02 a one-word structured phrase, D07 a pushed-inward unmarked word, D11
///          three alternatives, M05b a structured exclusion). Measured at parser 6.5 (28557157), the spelling alphabet
///          reports 75,924 lists per scope with 1,304 applied marks on cold unreported although filtering on them would
///          remove no row the query admits, and 49,776 failures: 24,788 terms that are not a word's first spelling,
///          24,748 lists that are not one term per word, and 240 parses whose marks on one word disagree
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
        let coldExact = typedOperand("cold", "\"cold\"", .word, negated: false, exact: true)
        let coldApplied = typedOperand("cold", "\"cold\"", .word, negated: false, exact: true, applied: true)
        let scopedCold = typedOperand("cold", "{body_text}:\"cold\"", .word, negated: false)
        let scopedNotWar = typedOperand("war", "NOT {body_text}:\"war\"", .word, negated: true)
        let scopedColdExact = typedOperand("cold", "{body_text}:\"cold\"", .word, negated: false, exact: true)
        let scopedColdApplied = typedOperand("cold", "{body_text}:\"cold\"", .word, negated: false, exact: true, applied: true)
        let notCold = typedOperand("cold", "NOT \"cold\"", .word, negated: true)
        let koreaExact = typedOperand("korea", "\"korea\"", .word, negated: false, exact: true)
        let koreaApplied = typedOperand("korea", "\"korea\"", .word, negated: false, exact: true, applied: true)
        let coldPhrase = typedOperand("cold", "\"cold\"", .phrase, negated: false)
        let coldPhraseRows = Issue1297StructuredCorpus.P("cold"), peace = Issue1297StructuredCorpus.W("peace")
        let peaceOperand = typedOperand("peace", "\"peace\"", .word, negated: false)
        let coldPeriodApplied = typedOperand("cold.", "\"cold.\"", .word, negated: false, exact: true, applied: true)

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
            // Parser 6.3 (D1): `=` filters only on a word every match must contain — an operand in the root expression's
            // proof "required" set. Beside the prefix, cold is one alternative of a complement the prefix anchors, so a
            // cold filter would remove every viet document lacking korea and cold, which the query asks for; 6.0 filtered.
            Issue1297StructuredCase(typed: "=cold OR -korea", structured: prefix,
                                    expression: "\"viet\"* NOT (\"korea\" NOT \"cold\")",
                                    meaning: vi.intersection(c.union(N(k))),
                                    operands: [coldExact, notKorea, viet]),
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
            // Parser 6.1: an approximation that matches nothing by construction is refused, not run. The anchor
            // pushing inward exposes is removed in full by an exclusion beside it, so the query stays nil — refused
            // with "nothing to search", as before the join — instead of a MATCH no document can satisfy.
            Issue1297StructuredCase(typed: "-(war -korea) -korea", expression: nil, meaning: N(w).intersection(N(k))),
            Issue1297StructuredCase(typed: "-(war -korea)", structured: StructuredQueryParts(excludedTerms: ["korea"]),
                                    expression: nil, meaning: N(w).intersection(N(k))),
            Issue1297StructuredCase(typed: "-( cold -korea )", structured: StructuredQueryParts(excludedTerms: ["korea"]),
                                    expression: nil, meaning: N(c).intersection(N(k))),
            // A structured exclusion carries no column prefix, so it removes a scoped anchor with the same core...
            Issue1297StructuredCase(typed: "-(war -korea)", structured: StructuredQueryParts(excludedTerms: ["korea"]),
                                    scoped: true, expression: nil, meaning: N(w).intersection(N(k))),
            // ...and a typed exclusion removes an anchor in its own scope.
            Issue1297StructuredCase(typed: "-(war -korea) -korea", scoped: true, expression: nil,
                                    meaning: N(w).intersection(N(k))),
            // The removed anchor need not be the whole approximation: every document `cold korea` matches holds korea.
            Issue1297StructuredCase(typed: "cold korea OR -korea", structured: StructuredQueryParts(excludedTerms: ["korea"]),
                                    expression: nil, meaning: N(k)),
            // Nor need it be approximated itself: the alternative kept here is an exact render, and matches nothing.
            Issue1297StructuredCase(typed: "korea -korea OR -korea", expression: nil, meaning: N(k)),
            // The demoted word "not" is removed by `-not` in either scope. Since parser 6.2 a demoted operator word
            // carries the column prefix like any other typed word; before, it spanned every column, and the scoped
            // query ran `("not") NOT {body_text}:"not"` beside this refusal.
            Issue1297StructuredCase(typed: "(NOT OR -korea) -not", expression: nil, meaning: N(k).subtracting(notWord)),
            Issue1297StructuredCase(typed: "(NOT OR -korea) -not", scoped: true, expression: nil,
                                    meaning: N(k).subtracting(notWord)),
            // Guards. An exact render is never refused, even one that matches nothing, because it is what was typed...
            Issue1297StructuredCase(typed: "korea -korea", expression: "\"korea\" NOT \"korea\"", meaning: [],
                                    operands: [korea, notKorea]),
            // ...nor an approximation that still matches something beside the part that cannot...
            Issue1297StructuredCase(typed: "cold OR -(war -korea) -korea", expression: "\"cold\" OR \"korea\" NOT \"korea\"",
                                    meaning: c.union(N(w).intersection(N(k))), approximation: c,
                                    operands: [cold, korea, notKorea], dropped: [notWar], isApproximate: true),
            // ...nor one whose anchor the exclusion's scope does not cover. A phrase carries no column prefix, so a
            // scoped `-korea` cannot be shown to remove the phrase "korea" — a document can hold korea outside the body,
            // though this table's constant header never does, which is why the render matches nothing here. Unscoped,
            // the same query is refused, and `SearchService` refuses it in every scope, because its exact terms and
            // Query Inspector read that parse.
            Issue1297StructuredCase(typed: "\"korea\" -korea OR -korea", expression: nil, meaning: N(k)),
            Issue1297StructuredCase(typed: "\"korea\" -korea OR -korea", scoped: true,
                                    expression: "\"korea\" NOT {body_text}:\"korea\"",
                                    meaning: N(k), approximation: [],
                                    operands: [typedOperand("korea", "\"korea\"", .phrase, negated: false),
                                               typedOperand("korea", "NOT {body_text}:\"korea\"", .word, negated: true)],
                                    dropped: [typedOperand("korea", "NOT {body_text}:\"korea\"", .word, negated: true)],
                                    isApproximate: true),
            // Parser 6.3 (D1): an `=` term is a post-filter only when its operand is in the root expression's proof
            // "required" set; everywhere else the sigil is ignored and the term runs stemmed. The app ANDs one
            // exact-word filter per term, so a term a match need not contain would remove documents the MATCH admits.
            // Inside a negated group (F26): korea is doubly negated, so positive, but a document with cold and neither
            // war nor korea matches, and a korea filter removed it.
            Issue1297StructuredCase(typed: "cold -(war -=korea)", expression: "\"cold\" NOT (\"war\" NOT \"korea\")",
                                    meaning: c.intersection(N(w).union(k)),
                                    operands: [cold, notWar, typedOperand("korea", "\"korea\"", .word, negated: false, exact: true)]),
            Issue1297StructuredCase(typed: "cold -(war -=korea)", scoped: true,
                                    expression: "{body_text}:\"cold\" NOT ({body_text}:\"war\" NOT {body_text}:\"korea\")",
                                    meaning: c.intersection(N(w).union(k)),
                                    operands: [scopedCold, scopedNotWar,
                                               typedOperand("korea", "{body_text}:\"korea\"", .word, negated: false, exact: true)]),
            // An OR alternative: a war document without cold matches.
            Issue1297StructuredCase(typed: "=cold OR war", expression: "\"cold\" OR \"war\"", meaning: c.union(w),
                                    operands: [coldExact, war]),
            // Every match holds cold, in either scope.
            Issue1297StructuredCase(typed: "=cold war", expression: "\"cold\" AND \"war\"", meaning: c.intersection(w),
                                    operands: [coldApplied, war], exactTerms: ["cold"]),
            Issue1297StructuredCase(typed: "=cold war", scoped: true, expression: "{body_text}:\"cold\" AND {body_text}:\"war\"",
                                    meaning: c.intersection(w),
                                    operands: [typedOperand("cold", "{body_text}:\"cold\"", .word, negated: false, exact: true,
                                                            applied: true),
                                               typedOperand("war", "{body_text}:\"war\"", .word, negated: false)],
                                    exactTerms: ["cold"]),
            Issue1297StructuredCase(typed: "=cold -(war -korea)", expression: "\"cold\" NOT (\"war\" NOT \"korea\")",
                                    meaning: c.intersection(N(w).union(k)),
                                    operands: [coldApplied, notWar, korea], exactTerms: ["cold"]),
            // The proof is the expression that RUNS: approximated to `"cold"`, every match holds cold.
            Issue1297StructuredCase(typed: "=cold OR -korea", expression: "\"cold\"", meaning: c.union(N(k)), approximation: c,
                                    operands: [coldApplied], dropped: [notKorea], exactTerms: ["cold"], isApproximate: true),
            // An excluded `=` term stays ignored even where another operand makes its word required: the positive
            // korea here was typed without the sigil, and a filter would narrow it to the literal word.
            Issue1297StructuredCase(typed: "korea (war OR -=korea)", expression: "\"korea\" NOT (\"korea\" NOT \"war\")",
                                    meaning: k.intersection(w.union(N(k))),
                                    operands: [korea, war, typedOperand("korea", "NOT \"korea\"", .word, negated: true, exact: true)]),
            // Proof combinators, each pinned by name (round-1 Q5/Q5b). `conjoin` forbids what EITHER conjunct forbids:
            // the right conjunct's approximation `"cold" NOT "korea"` removes the left's anchor korea, so nothing can
            // match. (`-(war -korea) (cold -korea)` is no such case: its AND-run holds a positive, so it renders exactly.)
            Issue1297StructuredCase(typed: "-(war -korea) (cold -korea OR -vietnam)", expression: nil,
                                    meaning: N(w).union(k).intersection(c.subtracting(k).union(N(v)))),
            // `disjoin` requires only what EVERY alternative requires: a match of `"cold" OR "korea"` need not hold korea,
            // so excluding korea leaves the cold documents, and the query runs.
            Issue1297StructuredCase(typed: "(cold OR korea OR -vietnam) -korea", expression: "(\"cold\" OR \"korea\") NOT \"korea\"",
                                    meaning: c.union(k).union(N(v)).subtracting(k), approximation: c.subtracting(k),
                                    operands: [cold, korea, notKorea], dropped: [notVietnam], isApproximate: true),
            // The approximate AND-run's bytes (round-1 P8): every anchored member is conjoined before any exclusion is
            // applied. Excluding in typed order matches the same rows, but saved-search freshness compares renders.
            Issue1297StructuredCase(typed: "(cold OR -korea) -vietnam (war OR -x)", expression: "(\"cold\") AND (\"war\") NOT \"vietnam\"",
                                    meaning: c.union(N(k)).subtracting(v).intersection(w.union(N(Issue1297StructuredCorpus.W("x")))),
                                    approximation: c.intersection(w).subtracting(v),
                                    operands: [cold, notVietnam, war],
                                    dropped: [notKorea, typedOperand("x", "NOT \"x\"", .word, negated: true)], isApproximate: true),
            // The mirror of the `conjoin` case above (round-2 P4): the LEFT conjunct's approximation `"cold" NOT "korea"`
            // removes the right's anchor korea, so a `conjoin` keeping only the right conjunct's forbidden set would run it.
            Issue1297StructuredCase(typed: "(cold -korea OR -vietnam) -(war -korea)", expression: nil,
                                    meaning: c.subtracting(k).union(N(v)).intersection(N(w).union(k))),
            // D1 with D4: an `=` mark is a post-filter only when every match must hold the literal word, which the proof
            // shows over MARKED operands alone. An unmarked word or a one-word phrase with the same stem says nothing
            // about the literal word: `colds war` matches `(=cold OR war) cold` through war and the stemmed cold, and a
            // cold filter would remove it.
            Issue1297StructuredCase(typed: "(=cold OR war) cold", expression: "(\"cold\" OR \"war\") AND \"cold\"",
                                    meaning: c.union(w).intersection(c), operands: [coldExact, war, cold]),
            Issue1297StructuredCase(typed: "=cold OR \"cold\"", expression: "\"cold\" OR \"cold\"",
                                    meaning: c.union(coldPhraseRows), operands: [coldExact, coldPhrase]),
            Issue1297StructuredCase(typed: "korea (war OR =korea)", expression: "\"korea\" AND (\"war\" OR \"korea\")",
                                    meaning: k.intersection(w.union(k)), operands: [korea, war, koreaExact]),
            Issue1297StructuredCase(typed: "=cold war OR cold peace",
                                    expression: "\"cold\" AND \"war\" OR \"cold\" AND \"peace\"",
                                    meaning: c.intersection(w).union(c.intersection(peace)),
                                    operands: [coldExact, war, cold, typedOperand("peace", "\"peace\"", .word, negated: false)]),
            Issue1297StructuredCase(typed: "=cold war OR cold peace", scoped: true,
                                    expression: "{body_text}:\"cold\" AND {body_text}:\"war\" OR {body_text}:\"cold\" AND {body_text}:\"peace\"",
                                    meaning: c.intersection(w).union(c.intersection(peace)),
                                    operands: [scopedColdExact, typedOperand("war", "{body_text}:\"war\"", .word, negated: false),
                                               scopedCold, typedOperand("peace", "{body_text}:\"peace\"", .word, negated: false)]),
            // A required mark applies however many unmarked operands share its stem, and once it applies, it applies to
            // every positive `=` operand on the word (D4): filtered on the literal word, the alternative reads the same.
            Issue1297StructuredCase(typed: "cold =cold", expression: "\"cold\" AND \"cold\"", meaning: c,
                                    operands: [cold, coldApplied], exactTerms: ["cold"]),
            Issue1297StructuredCase(typed: "(=cold OR war) =cold", expression: "(\"cold\" OR \"war\") AND \"cold\"",
                                    meaning: c.union(w).intersection(c), operands: [coldApplied, war, coldApplied],
                                    exactTerms: ["cold"]),
            // D4: a word marked in every alternative is one every match holds literally, whichever alternative matched,
            // so no one occurrence need be required. 6.4 required one, and ran these unfiltered.
            Issue1297StructuredCase(typed: "=cold war OR =cold peace",
                                    expression: "\"cold\" AND \"war\" OR \"cold\" AND \"peace\"",
                                    meaning: c.intersection(w).union(c.intersection(peace)),
                                    operands: [coldApplied, war, coldApplied, typedOperand("peace", "\"peace\"", .word, negated: false)],
                                    exactTerms: ["cold"]),
            Issue1297StructuredCase(typed: "=cold war OR =cold peace", scoped: true,
                                    expression: "{body_text}:\"cold\" AND {body_text}:\"war\" OR {body_text}:\"cold\" AND {body_text}:\"peace\"",
                                    meaning: c.intersection(w).union(c.intersection(peace)),
                                    operands: [scopedColdApplied, typedOperand("war", "{body_text}:\"war\"", .word, negated: false),
                                               scopedColdApplied, typedOperand("peace", "{body_text}:\"peace\"", .word, negated: false)],
                                    exactTerms: ["cold"]),
            Issue1297StructuredCase(typed: "=cold OR =cold war", expression: "\"cold\" OR \"cold\" AND \"war\"",
                                    meaning: c.union(c.intersection(w)), operands: [coldApplied, coldApplied, war],
                                    exactTerms: ["cold"]),
            Issue1297StructuredCase(typed: "=cold OR =cold", expression: "\"cold\" OR \"cold\"", meaning: c,
                                    operands: [coldApplied, coldApplied], exactTerms: ["cold"]),
            // ...but not where one alternative only excludes the marked word: a peace document without cold matches.
            Issue1297StructuredCase(typed: "=cold war OR peace -=cold",
                                    expression: "\"cold\" AND \"war\" OR \"peace\" NOT \"cold\"",
                                    meaning: c.intersection(w).union(peace.subtracting(c)),
                                    operands: [coldExact, war, typedOperand("peace", "\"peace\"", .word, negated: false),
                                               typedOperand("cold", "NOT \"cold\"", .word, negated: true, exact: true)]),
            // Doubly negated, the mark is positive and required by the approximation that runs: without the filter
            // `"cold"` would match `colds war`, which the query as typed — NOT war, OR the literal word cold — excludes.
            Issue1297StructuredCase(typed: "-(war -=cold)", expression: "\"cold\"", meaning: N(w).union(c), approximation: c,
                                    operands: [coldApplied], dropped: [notWar], exactTerms: ["cold"], isApproximate: true),
            Issue1297StructuredCase(typed: "NOT (cold OR -=korea)", expression: "\"korea\" NOT \"cold\"",
                                    meaning: N(c.union(N(k))), operands: [notCold, koreaApplied], exactTerms: ["korea"]),
            // A typed phrase spans every column, so beside it a scoped `=cold` is a different operand again: in neither
            // scope does a phrase every match holds make the marked alternative required (the round-1 attack's E4).
            Issue1297StructuredCase(typed: "\"cold\" (=cold OR war)", expression: "\"cold\" AND (\"cold\" OR \"war\")",
                                    meaning: coldPhraseRows.intersection(c.union(w)), operands: [coldPhrase, coldExact, war]),
            Issue1297StructuredCase(typed: "\"cold\" (=cold OR war)", scoped: true,
                                    expression: "\"cold\" AND ({body_text}:\"cold\" OR {body_text}:\"war\")",
                                    meaning: coldPhraseRows.intersection(c.union(w)),
                                    operands: [coldPhrase, scopedColdExact, typedOperand("war", "{body_text}:\"war\"", .word, negated: false)]),
            // A typed `=cold` beside a structured phrase or prefix is required by the root conjunction the parts join
            // (round-2 M05: a `combineParts` intersecting what its parts require passed every named case).
            Issue1297StructuredCase(typed: "=cold", structured: phrase, expression: "\"cold\" AND \"cold war\"",
                                    meaning: c.intersection(cw), operands: [coldApplied, coldWar], exactTerms: ["cold"]),
            Issue1297StructuredCase(typed: "=cold", structured: prefix, expression: "\"cold\" AND \"viet\"*",
                                    meaning: c.intersection(vi), operands: [coldApplied, viet], exactTerms: ["cold"]),
            // Parser 6.1 inside a kept alternative (round-2 M13): each alternative of the group matches nothing, so the
            // group does, and so does the approximation left once `-vietnam` is left out. A `settled()` that recomputed
            // emptiness over the group's required set, which an `OR` empties, ran it; only the oracle caught that.
            Issue1297StructuredCase(typed: "(cold -cold OR war -war) -korea OR -vietnam", expression: nil,
                                    meaning: c.subtracting(c).union(w.subtracting(w)).subtracting(k).union(N(v))),
            // Round 4 (Q1): marks are compared by the index word the filter reads, never by spelling, so `"cold."` and
            // `Cold` are marks on cold — in every alternative, and beside a required mark — and the term is the first
            // spelling applied. By spelling, the first reported nothing and the third applied only its second mark.
            Issue1297StructuredCase(typed: "=cold. war OR =cold peace",
                                    expression: "\"cold.\" AND \"war\" OR \"cold\" AND \"peace\"",
                                    meaning: c.intersection(w).union(c.intersection(peace)),
                                    operands: [coldPeriodApplied, war, coldApplied, peaceOperand], exactTerms: ["cold."]),
            Issue1297StructuredCase(typed: "=Cold war OR =cold peace", scoped: true,
                                    expression: "{body_text}:\"cold\" AND {body_text}:\"war\" OR {body_text}:\"cold\" AND {body_text}:\"peace\"",
                                    meaning: c.intersection(w).union(c.intersection(peace)),
                                    operands: [typedOperand("Cold", "{body_text}:\"cold\"", .word, negated: false, exact: true, applied: true),
                                               typedOperand("war", "{body_text}:\"war\"", .word, negated: false),
                                               scopedColdApplied, typedOperand("peace", "{body_text}:\"peace\"", .word, negated: false)],
                                    exactTerms: ["Cold"]),
            Issue1297StructuredCase(typed: "(=cold. OR war) =Cold", expression: "(\"cold.\" OR \"war\") AND \"cold\"",
                                    meaning: c.union(w).intersection(c),
                                    operands: [coldPeriodApplied, war,
                                               typedOperand("Cold", "\"cold\"", .word, negated: false, exact: true, applied: true)],
                                    exactTerms: ["cold."]),
            // Round-3 attack pins (D4), each once caught only by the oracle or the sweep, or by nothing. A structured
            // phrase is never a mark (D02): `memo colds war` matches through the stem.
            Issue1297StructuredCase(typed: "=cold OR war", structured: StructuredQueryParts(phrase: "cold"),
                                    expression: "(\"cold\" OR \"war\") AND \"cold\"",
                                    meaning: c.union(w).intersection(coldPhraseRows),
                                    operands: [coldExact, war, structuredOperand("cold", "\"cold\"", .phrase, negated: false)]),
            // A doubly negated unmarked word gains no mark when its negation is pushed inward (D07).
            Issue1297StructuredCase(typed: "-(war -cold) OR =cold", expression: "\"cold\" OR \"cold\"",
                                    meaning: N(w).union(c), approximation: c,
                                    operands: [cold, coldExact], dropped: [notWar], isApproximate: true),
            // Three alternatives, the middle one unmarked: required is what ALL of them require (D11).
            Issue1297StructuredCase(typed: "=cold OR war OR =cold", expression: "\"cold\" OR \"war\" OR \"cold\"",
                                    meaning: c.union(w), operands: [coldExact, war, coldExact]),
            // A structured exclusion keeps the typed mark it is applied to (round-3 M05b; the M05 pins above cover only
            // a structured phrase and prefix).
            Issue1297StructuredCase(typed: "=cold", structured: StructuredQueryParts(excludedTerms: ["korea"]),
                                    expression: "\"cold\" NOT \"korea\"", meaning: c.subtracting(k),
                                    operands: [coldApplied, structuredOperand("korea", "NOT \"korea\"", .word, negated: true)],
                                    exactTerms: ["cold"]),
        ]
    }()

    /// Each named case renders its bytes, matches its set, and reports every operand where it belongs.
    @Test("A typed query beside structured fields renders, matches and reports what the judged table says",
          arguments: Issue1297StructuredPartsTests.namedCases)
    func namedCombinations(_ c: Issue1297StructuredCase) throws {
        #expect(Self.namedCases.count == 90)
        let table = Issue1297StructuredTable(twoColumn: c.scoped)
        let parsed = FTS5InlineQueryParser.parseDetailed(c.typed, columnPrefix: c.scoped ? "{body_text}:" : "",
                                                         structured: c.structured)
        let isExact = !c.meaning.contains(1)
        let expectedRows = isExact ? c.meaning : c.approximation
        // The case must agree with itself before the parser is asked anything.
        #expect((c.expression == nil) == (expectedRows == nil), "fixture: an expression exactly when rows are expected")
        #expect(c.isApproximate == (c.expression != nil && !isExact), "fixture: approximate exactly when narrower")
        var appliedWords = Set<String>()
        #expect(c.exactTerms == c.operands.filter(\.isExactApplied).map(\.text)
                    .filter { appliedWords.insert(Issue1297InflectedCorpus.indexWord($0)).inserted },
                "fixture: a term exactly for each index word with an applied mark, in order, once, as first spelled")

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
    /// anchoring policy and never sees an FTS5 string. It mirrors parser 6.1's refusal from operand identities
    /// alone (`Issue1297OracleProof`), never from the rows a render matched, so a render left empty only by this
    /// corpus is still expected to run.
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
            let typedAlonePolicy = Issue1297OracleModel.searched(typedModel, pushInward: true, typedHarvest,
                                                                 scoped: false, dropped: &droppedAlone)

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
                var dropped = Set<Int>(), droppedWithoutPush = Set<Int>(), droppedUnrefused = Set<Int>()
                let searchedAnchor = Issue1297OracleModel.searchedAnchor(root, pushInward: true, harvest, scoped: scoped,
                                                                         dropped: &dropped)
                let policy = searchedAnchor?.rows
                let policyWithoutPush = Issue1297OracleModel.searched(root, pushInward: false, harvest, scoped: scoped,
                                                                      dropped: &droppedWithoutPush)
                let unrefused = Issue1297OracleModel.policy(root, negated: false, pushInward: true, harvest, scoped: scoped,
                                                            dropped: &droppedUnrefused)
                var parity: [Int: Bool] = [:]
                Issue1297OracleModel.parity(root, negated: false, into: &parity)
                // D1 with D4: a typed, applied, positive `=` operand whose stem every match of the expression that runs holds
                // through a MARKED leaf — never through an unmarked one — as the oracle's proof computes it from leaves alone.
                let applied = Set((0..<typedCount).filter {
                    harvest.exact[$0] && parity[$0] == false && !dropped.contains($0)
                        && searchedAnchor?.proof.requiredMarked.contains(Issue1297OracleModel.key($0, harvest, scoped: scoped).stem) == true
                })
                let everyOperand = harvest.texts.indices.map {
                    Issue1297ModelOperand(text: harvest.texts[$0], isNegated: parity[$0] ?? false,
                                          kind: harvest.kinds[$0], source: harvest.sources[$0], isExactApplied: applied.contains($0))
                }
                let expectedOperands = policy == nil ? [] : harvest.texts.indices.filter { !dropped.contains($0) }.map { everyOperand[$0] }
                let expectedDropped = policy == nil ? [] : harvest.texts.indices.filter { dropped.contains($0) }.map { everyOperand[$0] }
                let expectedExact = applied.isEmpty ? [] : ["cold"]
                if policy != nil, (0..<typedCount).contains(where: { harvest.exact[$0] && parity[$0] == false && !dropped.contains($0) }) {
                    events[expectedExact.isEmpty ? "exactIgnoredNotRequired" : "exactRequired", default: 0] += 1
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
                // Refused by 6.1: the policy anchors, and the proof shows the approximation matches nothing.
                if policy == nil, unrefused != nil { events["refused", default: 0] += 1 }
                // Run although it matches nothing here: empty only on this corpus, or beyond what operands can prove.
                if let policy, meaning.contains(1), policy.isEmpty { events["approximationEmptyUnproved", default: 0] += 1 }
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
        // 5,000 and 4,968 before parser 6.1, whose refusals take 576 and 515 of these queries to nil (4,424 and 4,453).
        #expect(events["keptNegatedBesideDrops", default: 0] > 4_000)
        // Measured 699 and 623: the oracle reaches the refusal on its own, not only through the named cases.
        #expect(events["refused", default: 0] > 600)
        // Both sides of the exact-term rule must be exercised, or the comparison above cannot tell them apart.
        #expect(events["exactRequired", default: 0] > 0)
        #expect(events["exactIgnoredNotRequired", default: 0] > 0)
        #expect(failures.isEmpty, "\(samples)")
    }

    // MARK: - The combined sweep

    /// Every short token sequence beside every structured combination, checked by invariants and a
    /// metamorphic identity rather than by expected strings.
    ///
    /// A render that matches nothing on the truth table while the query means something is re-run on
    /// `Issue1297UniversalCorpus`: empty there too, it matches nothing by construction, which parser 6.1 refuses,
    /// so the count must be zero; the rest are empty only because the truth table lacks a row, and are counted.
    /// Exact terms are swept by `exactTermsSweep`: this alphabet carries no `=`.
    @Test("Every token sequence of length 1-4 beside every structured combination is valid, reports consistently, and applies every typed operand beside a structured phrase or prefix",
          arguments: [false, true])
    func combinedSweep(scoped: Bool) throws {
        let table = Issue1297StructuredTable(twoColumn: scoped)
        let universalTable = Issue1297StructuredTable(bodies: Issue1297UniversalCorpus.bodies, twoColumn: scoped)
        let prefix = scoped ? "{body_text}:" : "", otherPrefix = scoped ? "" : "{body_text}:"
        let sequences = Issue1297PropertyTests.sequences(maxLength: 4, over: Issue1297PropertyTests.alphabet + ["-("])
        #expect(sequences.count == 11_110)
        let phraseRows = Issue1297StructuredCorpus.P("cold war"), prefixRows = Issue1297StructuredCorpus.X("viet")
        var compared = 0, executed = 0, metamorphic = 0, approximateWithoutDrops = 0
        var emptyByConstruction = 0, emptyByCoincidence = 0
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
            // The typed query's meaning on the universal corpus, read only when a render comes back empty.
            var universalTypedRows: Set<Int>?

            for combination in Self.combinations {
                compared += 1
                let hasStructuredPositive = combination.phrase != nil || combination.prefixWildcard != nil
                let parsed = FTS5InlineQueryParser.parseDetailed(typed, columnPrefix: prefix, structured: combination)
                let other = FTS5InlineQueryParser.parseDetailed(typed, columnPrefix: otherPrefix, structured: combination)
                let label = "\(typed) \(combination) -> \(parsed.expression ?? "nil")"
                if (parsed.expression == nil) != (other.expression == nil) {
                    fail("refusal depends on the column prefix", label)
                }
                if reporting(parsed.operands) != reporting(other.operands)
                    || reporting(parsed.droppedOperands) != reporting(other.droppedOperands)
                    || parsed.exactTerms != other.exactTerms || parsed.isApproximate != other.isApproximate {
                    fail("reporting depends on the column prefix", label)
                }
                if parsed.droppedOperands.contains(where: { !$0.isNegated }) { fail("positive operand dropped", label) }

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
                } else {
                    if !got.isSubset(of: expected) { fail("superset without a structured positive", "\(label) got \(got.sorted())") }
                    if got.isEmpty, !expected.isEmpty {
                        if universalTypedRows == nil { universalTypedRows = try universalTable.rows(anchoredExpression) }
                        var universalMeaning = universalTypedRows ?? []
                        for term in combination.excludedTerms { universalMeaning.subtract(try universalTable.rows("\"\(term)\"")) }
                        if try universalTable.rows(expression).isEmpty, !universalMeaning.isEmpty {
                            emptyByConstruction += 1
                            fail("approximation matches nothing by construction", label)
                        } else {
                            emptyByCoincidence += 1
                        }
                    }
                }
                if parsed.isApproximate && parsed.droppedOperands.isEmpty {
                    approximateWithoutDrops += 1
                    approximateWithoutDropsSequences.insert(typed)
                }
            }
        }

        print("[1297] combined sweep scoped=\(scoped) compared=\(compared) executed=\(executed) metamorphic=\(metamorphic) approximateWithoutDrops=\(approximateWithoutDrops) emptyByConstruction=\(emptyByConstruction) emptyByCoincidence=\(emptyByCoincidence) failures=\(failures.values.reduce(0, +)) \(failures.keys.sorted().map { "\($0)=\(failures[$0]!)" }.joined(separator: " "))")
        #expect(compared == 111_100)
        // 107,408 before parser 6.1, which refuses 146 renders per scope that matched nothing by construction.
        #expect(executed == 107_262)
        #expect(metamorphic == 66_660)
        // Pushing negation inward can leave out nothing but a demoted operator word, which has no operand
        // to report. These five sequences, beside the two combinations with no positive and no korea exclusion,
        // are all of them: beside `[korea]` and `[korea, vietnam]` all five expose korea only to have it excluded,
        // so 6.1 refuses them (20 before it).
        #expect(approximateWithoutDrops == 10)
        #expect(approximateWithoutDropsSequences == ["-( -korea NOT )", "-( -korea AND )", "-( -korea OR )",
                                                     "-( AND -korea )", "-( OR -korea )"])
        // Measured over this sweep before 6.1: 500 renders over both scopes matched no truth-table row while the query
        // meant something — 292 by construction, and 208 only because the truth table holds "and", "or" and "not"
        // beside nothing but "memo" (`"cold" AND "not"`). The first class is refused; the second is not provable from
        // operands and runs.
        #expect(emptyByConstruction == 0)
        #expect(emptyByCoincidence == 104)
        #expect(failures.isEmpty, "\(samples)")
    }

    // MARK: - The exact-term sweep

    /// `combinedSweep`'s alphabet with `=cold` and `-=cold` in place of the words cold and AND, since that alphabet
    /// carries no `=` and every exact-term list it parses is empty — and, after them, the unmarked word cold and the
    /// one-word phrase "cold", the two other operands that share `=cold`'s stem.
    static let exactAlphabet = ["=cold", "-=cold", "war", "-korea", "NOT", "korea", "OR", "(", ")", "-(", "cold", "\"cold\""]

    /// Marks on the index word cold in three spellings — `=cold`, `=Cold` and `=cold.`, and the excluded `-=Cold` —
    /// beside the unmarked cold, war and the operators that put them in alternatives, conjunctions and negated groups:
    /// a spelling must never decide whether a mark applies, nor which term is reported (round 4, Q1).
    static let spellingAlphabet = ["=cold", "=Cold", "=cold.", "-=Cold", "cold", "war", "OR", "(", ")", "-("]

    /// The runs of the exact-term sweep: each alphabet in each scope, with the counts measured on it at parser 6.6.
    static let exactSweeps: [Issue1297ExactSweep] = [
        Issue1297ExactSweep(name: "=cold, -=cold, cold and \"cold\"", alphabet: exactAlphabet, scoped: false,
                            sequences: 22_620, unprovedRequired: 428),
        Issue1297ExactSweep(name: "=cold, -=cold, cold and \"cold\"", alphabet: exactAlphabet, scoped: true,
                            sequences: 22_620, unprovedRequired: 428),
        Issue1297ExactSweep(name: "=cold, =Cold, =cold. and -=Cold", alphabet: spellingAlphabet, scoped: false,
                            sequences: 11_110, unprovedRequired: 64, refusedOnlyRespelled: 16),
        Issue1297ExactSweep(name: "=cold, =Cold, =cold. and -=Cold", alphabet: spellingAlphabet, scoped: true,
                            sequences: 11_110, unprovedRequired: 64, refusedOnlyRespelled: 16),
    ]

    /// The exact-word post-filter `SearchService` reads from the combined parse, over sequences that can mark a word.
    ///
    /// D1 with D4 reports a typed `=` operand only when it is applied and positive and every match of the expression that
    /// runs holds its word through a MARKED operand — one required mark, or a mark in every alternative — never merely
    /// through an unmarked operand with its stem. A word is the index word the filter compares, so every spelling of it
    /// is one word. The sweep cannot read the proof, so it checks what the rule implies, each from outside the parser,
    /// on `Issue1297InflectedCorpus`, where the stemmed and the literal word cold select different rows:
    /// - only a typed, applied, positive `=` operand is ever reported, the terms are exactly those of the operands
    ///   `ParsedOperand.isExactApplied` marks, one per index word in the spelling of its first, and the column prefix
    ///   changes nothing;
    /// - every positive typed mark on one index word is applied, or none is, whatever its spelling;
    /// - SOUNDNESS by the app's literal-word rule, `ExactWordMatcher`: of the rows the render matches, every row the
    ///   query's literal meaning admits holds the literal word, so the filter the SQL layer ANDs over the results removes
    ///   none of them. The literal meaning is the render of the same text with every mark on cold spelled
    ///   `Issue1297InflectedCorpus.literalMarker`, which has the same shape and matches what the query means with those
    ///   operands read as the literal word — for an approximation, what the approximation means, since that is what
    ///   runs. A term failing this removes documents the MATCH and the query admit: `=cold OR war`, F26's
    ///   `cold -(war -=korea)`, and `(=cold OR war) cold`, where the unmarked cold is what every match requires. A
    ///   reported term must also be a word every row the render matches holds by stem;
    /// - COMPLETENESS, as far as operands can prove it: an applied mark on cold left unreported although filtering on
    ///   it would remove none of those rows is counted and pinned. The proof is sound but not complete — every match of
    ///   `=cold OR korea` beside the excluded term korea holds the literal word, because the exclusion empties the
    ///   korea alternative, which operands alone cannot show — so the count is not zero. Parser 6.4 followed marked
    ///   leaves by occurrence and left `=cold OR =cold war` here too, and 6.5 compared spellings and left
    ///   `=cold OR =cold.`: both were sound filters lost, not limits of what operands can prove;
    /// - against the typed-alone parse: beside no structured phrase or prefix the combined parse reports the same terms
    ///   wherever both render; beside one it reports the same terms when the typed text renders exactly alone, and none
    ///   when the typed text is approximated or refused alone, because a complement the phrase or prefix anchors
    ///   requires nothing of its own.
    @Test("Every token sequence of length 1-4 marking cold reports, beside every structured combination, exactly the exact terms whose filter removes no row the query admits",
          arguments: Issue1297StructuredPartsTests.exactSweeps)
    func exactTermsSweep(_ sweep: Issue1297ExactSweep) throws {
        let scoped = sweep.scoped
        let prefix = scoped ? "{body_text}:" : "", otherPrefix = scoped ? "" : "{body_text}:"
        let table = Issue1297StructuredTable(bodies: Issue1297InflectedCorpus.bodies, twoColumn: scoped)
        let stemmedColdRows = try table.rows("\"cold\"")
        let sequences = Issue1297PropertyTests.sequences(maxLength: 4, over: sweep.alphabet)
        #expect(sequences.count == sweep.sequences)
        func word(_ text: String) -> String { Issue1297InflectedCorpus.indexWord(text) }
        var compared = 0, reported = 0, soundnessChecked = 0, ignoredNotRequired = 0, unprovedRequired = 0
        var besideNothing = 0, besidePositiveExactAlone = 0, besidePositiveApproximatedAlone = 0, approximate = 0
        var respelled = 0, refusedOnlyRespelled = 0
        var unprovedSamples: [String] = []
        var failures: [String: Int] = [:]
        var samples: [String] = []
        func fail(_ category: String, _ detail: String) {
            failures[category, default: 0] += 1
            if samples.count < 8 { samples.append("[\(category)] \(detail)") }
        }

        for typed in sequences {
            let alone = FTS5InlineQueryParser.parseDetailed(typed, columnPrefix: prefix)
            let literalTyped = Issue1297InflectedCorpus.literal(typed)
            for combination in Self.combinations {
                compared += 1
                let hasStructuredPositive = combination.phrase != nil || combination.prefixWildcard != nil
                let parsed = FTS5InlineQueryParser.parseDetailed(typed, columnPrefix: prefix, structured: combination)
                let other = FTS5InlineQueryParser.parseDetailed(typed, columnPrefix: otherPrefix, structured: combination)
                let label = "\(typed) \(combination) -> \(parsed.expression ?? "nil") \(parsed.exactTerms)"
                let marks = parsed.operands.filter { $0.isExact && !$0.isNegated && $0.source == .typed }
                var seen = Set<String>(), seenApplied = Set<String>()
                let applied = marks.map(\.text).filter { seen.insert(word($0)).inserted }
                if parsed.exactTerms != applied.filter(parsed.exactTerms.contains) {
                    fail("an exact term that is not the first spelling of a typed, applied, positive = operand's word", label)
                }
                // The per-operand flag is the list, operand by operand: in this alphabet a term is its operand's text.
                if parsed.exactTerms != parsed.operands.filter(\.isExactApplied).map(\.text).filter({ seenApplied.insert(word($0)).inserted }) {
                    fail("exact terms are not the terms of the operands whose mark applies, one per index word", label)
                }
                if Dictionary(grouping: marks, by: { word($0.text) }).values.contains(where: { Set($0.map(\.isExactApplied)).count > 1 }) {
                    fail("positive marks on one index word disagree about whether they apply", label)
                }
                if parsed.operands.contains(where: { $0.isExactApplied && (!$0.isExact || $0.isNegated || $0.source != .typed) })
                    || parsed.droppedOperands.contains(where: \.isExactApplied) {
                    fail("a mark applied to an operand that is not a typed, applied, positive = operand", label)
                }
                if parsed.exactTerms != other.exactTerms { fail("exact terms depend on the column prefix", label) }
                guard let expression = parsed.expression else {
                    if !parsed.exactTerms.isEmpty { fail("exact terms without an expression", label) }
                    continue
                }

                if applied.contains(where: { word($0) == "cold" }) {
                    let matched = try table.rows(expression)
                    let literalRows: Set<Int>
                    if let literalExpression = FTS5InlineQueryParser.parseDetailed(
                        literalTyped, columnPrefix: prefix, structured: combination).expression {
                        literalRows = try table.rows(literalExpression)
                    } else if parsed.isApproximate, matched.isEmpty {
                        // One marker for every spelling makes one identity of what 6.1's refusal compares as two
                        // spellings: `=cold. -=Cold OR -=Cold` runs the approximation `"cold." NOT "cold"`, and its
                        // respelling is refused as `"xcoldexact" NOT "xcoldexact"`. That is the refusal's known
                        // incompleteness, not the filter's, and it admits nothing only because the render matches
                        // nothing.
                        refusedOnlyRespelled += 1
                        literalRows = []
                    } else {
                        fail("the literal spelling is refused where the query renders", label)
                        continue
                    }
                    // The rows a cold filter would remove although the render matches them and the literal meaning admits them.
                    let lost = matched.intersection(literalRows).filter {
                        !ExactWordMatcher.contains(word: "cold", in: Issue1297InflectedCorpus.bodies[$0 - 1])
                    }
                    if parsed.exactTerms.contains(where: { word($0) == "cold" }) {
                        soundnessChecked += 1
                        if Set(marks.map(\.text)).count > 1 { respelled += 1 }
                        if let row = lost.min() {
                            fail("an exact term removes a row the render and the literal meaning admit",
                                 "\(label) removes \(lost.count) rows such as '\(Issue1297InflectedCorpus.bodies[row - 1])'")
                        }
                        if !matched.isSubset(of: stemmedColdRows) {
                            fail("an exact term a match need not contain", "\(label) matched \(matched.subtracting(stemmedColdRows).count) rows without cold")
                        }
                    } else if lost.isEmpty {
                        unprovedRequired += 1
                        if unprovedSamples.count < 4 { unprovedSamples.append(label) }
                    } else {
                        ignoredNotRequired += 1
                    }
                }

                if !hasStructuredPositive {
                    if alone.expression != nil, parsed.exactTerms != alone.exactTerms {
                        fail("exact terms beside no structured positive differ from the typed-alone parse", label)
                    }
                    if !parsed.exactTerms.isEmpty { besideNothing += 1 }
                } else if alone.expression != nil, !alone.isApproximate {
                    if parsed.exactTerms != alone.exactTerms {
                        fail("exact terms beside a structured positive differ from the exact typed-alone parse", label)
                    }
                    if !parsed.exactTerms.isEmpty { besidePositiveExactAlone += 1 }
                } else {
                    if !parsed.exactTerms.isEmpty {
                        fail("an exact term from typed text the structured positive anchors as a complement", label)
                    }
                    if !alone.exactTerms.isEmpty { besidePositiveApproximatedAlone += 1 }
                }
                if !parsed.exactTerms.isEmpty {
                    reported += 1
                    if parsed.isApproximate { approximate += 1 }
                }
            }
        }

        print("[1297] exact-term sweep \(sweep.testDescription) compared=\(compared) reported=\(reported) soundnessChecked=\(soundnessChecked) respelled=\(respelled) refusedOnlyRespelled=\(refusedOnlyRespelled) ignoredNotRequired=\(ignoredNotRequired) unprovedRequired=\(unprovedRequired) besideNothing=\(besideNothing) besidePositiveExactAlone=\(besidePositiveExactAlone) besidePositiveApproximatedAlone=\(besidePositiveApproximatedAlone) approximate=\(approximate) failures=\(failures.values.reduce(0, +)) \(failures.keys.sorted().map { "\($0)=\(failures[$0]!)" }.joined(separator: " ")) unproved: \(unprovedSamples)")
        #expect(compared == sweep.sequences * Self.combinations.count)
        // Measured per scope at parser 6.6: applied marks on cold that go unreported although filtering on them would
        // remove no row the query admits. Pinned, since a parser dropping terms it can prove would only raise it: over
        // the first alphabet 6.4, which required one marked occurrence, left 868 (`=cold OR =cold` among them); over
        // the second, 6.5, which compared spellings, left 1,304 (`=cold OR =cold.` among them).
        #expect(unprovedRequired == sweep.unprovedRequired)
        #expect(refusedOnlyRespelled == sweep.refusedOnlyRespelled)
        // The corpus must tell the two readings of cold apart, or the soundness check above cannot fail.
        #expect(try table.rows("\"cold\"").count > table.rows(Issue1297InflectedCorpus.literalMarker).count)
        // Each branch must actually carry exact terms, or its comparison is as vacuous as the one this sweep replaced.
        #expect(reported > 0)
        #expect(soundnessChecked == reported)
        #expect(ignoredNotRequired > 0)
        #expect(besideNothing > 0)
        #expect(besidePositiveExactAlone > 0)
        #expect(besidePositiveApproximatedAlone > 0)
        #expect(approximate > 0)
        // Over the spelling alphabet, reported lists must include ones whose marks were typed in several spellings.
        if sweep.alphabet == Self.spellingAlphabet { #expect(respelled > 0) }
        #expect(failures.isEmpty, "\(samples)")
    }

    /// Rows spelling cold and café every way the index folds together: rowid 1 is `memo cold war`.
    static let spellingBodies = ["memo cold war", "memo colds war", "memo cold peace", "memo colds peace",
                                 "memo café war", "memo cafés war", "memo cafe peace", "memo cafes peace", "memo Cold. war"]

    /// Marks spelled differently on one index word, executed: the render's rows filtered on the reported terms, as the
    /// SQL layer filters them, are exactly the rows the query means with every mark read as the literal word — written
    /// here as sets over `spellingBodies`, never read from a render. `unicode61` and `ExactWordMatcher` both fold case,
    /// diacritics and the punctuation beside a word, and Porter folds `colds` into cold and `cafés` into cafe, so a
    /// mark the parser ignores lets those inflections through (round 4, Q1). The exact-term sweep's corpus has no
    /// diacritic to spell, so this is where one is.
    @Test("Marks spelled differently on one index word filter the render to exactly what the query means, in both scopes",
          arguments: [false, true])
    func exactFilterReadsIndexWords(scoped: Bool) throws {
        let table = Issue1297StructuredTable(bodies: Self.spellingBodies, twoColumn: scoped)
        let prefix = scoped ? "{body_text}:" : ""
        let literalCold: Set<Int> = [1, 3, 9], stemmedCold: Set<Int> = [1, 2, 3, 4, 9]
        let literalCafe: Set<Int> = [5, 7], stemmedCafe: Set<Int> = [5, 6, 7, 8]
        let war: Set<Int> = [1, 2, 5, 6, 9], peace: Set<Int> = [3, 4, 7, 8]
        // The corpus must tell the literal words from their inflections, or no filter here could fail.
        #expect(try table.rows("\"cold.\"") == stemmedCold)
        #expect(try table.rows("\"café\"") == stemmedCafe)
        let cases: [(typed: String, terms: [String], rows: Set<Int>)] = [
            ("=cold. war OR =cold peace", ["cold."], literalCold.intersection(war).union(literalCold.intersection(peace))),
            ("=Cold war OR =cold. peace", ["Cold"], literalCold.intersection(war).union(literalCold.intersection(peace))),
            ("(=cold. OR peace) =Cold", ["cold."], literalCold.union(peace).intersection(literalCold)),
            ("=café war OR =cafe peace", ["café"], literalCafe.intersection(war).union(literalCafe.intersection(peace))),
            ("(=café OR war) =cafe", ["café"], literalCafe.union(war).intersection(literalCafe)),
            // Ignored marks run stemmed: an alternative, and a word marked in one alternative only.
            ("=cold. OR war", [], stemmedCold.union(war)),
            ("=café war OR cafe peace", [], stemmedCafe.intersection(war).union(stemmedCafe.intersection(peace))),
        ]
        for testCase in cases {
            let parsed = FTS5InlineQueryParser.parseDetailed(testCase.typed, columnPrefix: prefix)
            let expression = try #require(parsed.expression, "\(testCase.typed)")
            #expect(parsed.exactTerms == testCase.terms, "\(testCase.typed)")
            let marks = parsed.operands.filter { $0.isExact && !$0.isNegated }
            #expect(marks.allSatisfy { $0.isExactApplied == !testCase.terms.isEmpty }, "\(testCase.typed): every mark on the word, or none")
            let filtered = try table.rows(expression).filter { row in
                parsed.exactTerms.allSatisfy { ExactWordMatcher.contains(word: $0, in: Self.spellingBodies[row - 1]) }
            }
            #expect(filtered == testCase.rows, "\(testCase.typed) -> \(expression) \(parsed.exactTerms) kept \(filtered.sorted())")
        }
    }

    // MARK: - Refusal across scopes

    /// Tokens that demote an operator into a word and exclude that word, beside `=cold`.
    static let demotedAlphabet = ["=cold", "-not", "-and", "-or", "NOT", "AND", "OR", "-korea", "(", ")", "-("]

    /// Tokens that anchor on the quoted phrase "korea" and exclude the word korea, beside `=cold`.
    static let phraseAlphabet = ["=cold", "\"korea\"", "-\"korea\"", "-korea", "korea", "NOT", "OR", "war", "(", ")", "-("]

    /// The sequences a typed phrase lets render in a scope while the unscoped parse refuses them.
    static let phraseAnchoredOnlyUnscopedRefusals: Set<String> = [
        "\"korea\" -korea OR -\"korea\"", "\"korea\" -korea OR -korea", "-\"korea\" OR \"korea\" -korea",
        "-\"korea\" OR -korea \"korea\"", "-korea \"korea\" OR -\"korea\"", "-korea \"korea\" OR -korea",
        "-korea OR \"korea\" -korea", "-korea OR -korea \"korea\"",
    ]

    /// Whether a query is refused does not depend on the column prefix, except where a typed phrase — which spans
    /// every column in either scope — is the anchor a scoped exclusion cannot be shown to remove.
    ///
    /// `SearchService` reads its exact-word post-filter and the Query Inspector's rows from the unscoped parse, so a
    /// scoped parse that renders beside an unscoped refusal ran a search neither could describe. Parser 6.2 scopes a
    /// demoted operator word, which closes that for `-not`, `-and` and `-or`: over the demoted alphabet 128 pairs
    /// disagreed before it, from 32 sequences. The phrase class remains in the parser, is pinned here, and never runs
    /// in the app. A scoped refusal always implies the unscoped one, since a scoped exclusion covers no more than an
    /// unscoped one, so the disagreement never runs the other way.
    @Test("Every token sequence of length 1-4 is refused in both scopes or neither, beside every structured combination, unless a typed phrase anchors it",
          arguments: ["demoted", "phrase"])
    func refusalAcrossScopesSweep(alphabet: String) {
        let sequences = Issue1297PropertyTests.sequences(maxLength: 4,
                                                         over: alphabet == "demoted" ? Self.demotedAlphabet : Self.phraseAlphabet)
        #expect(sequences.count == 16_104)
        var compared = 0, bothRender = 0, neitherRenders = 0, onlyUnscopedRefused = 0, onlyScopedRefused = 0
        var onlyUnscopedSequences = Set<String>()
        var failures: [String: Int] = [:]
        var samples: [String] = []
        func fail(_ category: String, _ detail: String) {
            failures[category, default: 0] += 1
            if samples.count < 8 { samples.append("[\(category)] \(detail)") }
        }

        for typed in sequences {
            for combination in Self.combinations {
                compared += 1
                let unscoped = FTS5InlineQueryParser.parseDetailed(typed, columnPrefix: "", structured: combination)
                let scoped = FTS5InlineQueryParser.parseDetailed(typed, columnPrefix: "{body_text}:", structured: combination)
                let label = "\(typed) \(combination) -> \(unscoped.expression ?? "nil") / \(scoped.expression ?? "nil")"
                switch (unscoped.expression, scoped.expression) {
                case (.some, .some): bothRender += 1
                case (nil, nil): neitherRenders += 1
                case (.some, nil):
                    onlyScopedRefused += 1
                    fail("refused only in the scope", label)
                case (nil, .some):
                    onlyUnscopedRefused += 1
                    onlyUnscopedSequences.insert(typed)
                    if !scoped.operands.contains(where: { $0.kind == .phrase && $0.source == .typed && !$0.isNegated }) {
                        fail("refused only unscoped without a typed phrase anchor", label)
                    }
                }
            }
        }

        print("[1297] refusal across scopes alphabet=\(alphabet) compared=\(compared) bothRender=\(bothRender) neitherRenders=\(neitherRenders) onlyUnscopedRefused=\(onlyUnscopedRefused) onlyScopedRefused=\(onlyScopedRefused) failures=\(failures.values.reduce(0, +)) \(failures.keys.sorted().map { "\($0)=\(failures[$0]!)" }.joined(separator: " "))")
        #expect(compared == 161_040)
        #expect(bothRender > 0)
        #expect(neitherRenders > 0)
        #expect(onlyScopedRefused == 0)
        if alphabet == "demoted" {
            // 128 before parser 6.2, from 32 sequences such as `-korea OR -not NOT`.
            #expect(onlyUnscopedRefused == 0)
            #expect(FTS5InlineQueryParser.parseDetailed("-korea OR -not NOT", columnPrefix: "{body_text}:").expression == nil)
        } else {
            // Each beside no structured field and beside the excluded phrase "cold war", the two combinations that
            // neither anchor the query nor exclude korea.
            #expect(onlyUnscopedRefused == 16)
            #expect(onlyUnscopedSequences == Self.phraseAnchoredOnlyUnscopedRefusals)
        }
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

    // MARK: - The column prefix, observed

    /// The truth table's bodies under headers holding query words the body lacks, so a scoped operand that lost its
    /// column prefix matches a different row set.
    ///
    /// Each row's header holds every other word of `Issue1297UniversalCorpus.words` absent from its body, by row
    /// parity, and — in two rows of three whose body holds no viet-prefixed token — "vietminh". No header is empty: every
    /// body lacks at least three of those seven words, and the parity pick keeps at least one of any three.
    static let headerWordRows: [(header: String, body: String)] = Issue1297StructuredCorpus.bodies.enumerated().map { index, body in
        let row = index + 1
        let bodyTokens = Set(body.split(separator: " ").map(String.init))
        let absent = Issue1297UniversalCorpus.words.filter { !bodyTokens.contains($0) }
        var header = absent.enumerated().filter { (row + $0.offset) % 2 == 0 }.map(\.element)
        if row % 3 != 0, !bodyTokens.contains(where: { $0.hasPrefix("viet") }) { header.append("vietminh") }
        return (header.joined(separator: " "), body)
    }

    /// A scoped render over header words matches what the unscoped render matches over the same bodies with no header.
    ///
    /// Typed text in this alphabet holds no phrase, and the only structured part beside it is none or the prefix, so
    /// every operand of the scoped render carries the column prefix: the typed words and wildcards, a demoted operator
    /// word (6.2) and the structured prefix. A render that dropped the prefix anywhere matches a header word.
    @Test("A scoped render ignores query words in another column: its rows over headed documents equal the unscoped render's over the same bodies alone",
          arguments: [StructuredQueryParts(), StructuredQueryParts(prefixWildcard: "viet")])
    func columnPrefixScopesEveryTypedOperand(_ structured: StructuredQueryParts) throws {
        let headed = Issue1297StructuredTable(headed: Self.headerWordRows)
        let bare = Issue1297StructuredTable(headed: Self.headerWordRows.map { (header: "", body: $0.body) })
        let sequences = Issue1297PropertyTests.sequences(maxLength: 4, over: Issue1297PropertyTests.alphabet + ["-("])
        #expect(sequences.count == 11_110)
        var compared = 0, headerObservable = 0
        var failures: [String: Int] = [:]
        var samples: [String] = []
        func fail(_ category: String, _ detail: String) {
            failures[category, default: 0] += 1
            if samples.count < 8 { samples.append("[\(category)] \(detail)") }
        }
        for typed in sequences {
            let scoped = FTS5InlineQueryParser.parseDetailed(typed, columnPrefix: "{body_text}:", structured: structured)
            let unscoped = FTS5InlineQueryParser.parseDetailed(typed, columnPrefix: "", structured: structured)
            guard let scopedExpression = scoped.expression, let unscopedExpression = unscoped.expression else {
                if (scoped.expression == nil) != (unscoped.expression == nil) {
                    fail("refused in one scope", "\(typed) -> \(scoped.expression ?? "nil") / \(unscoped.expression ?? "nil")")
                }
                continue
            }
            compared += 1
            let got = try headed.rows(scopedExpression), want = try bare.rows(unscopedExpression)
            if got != want {
                fail("a scoped render matched a header word", "\(typed) -> \(scopedExpression) got \(got.sorted()) want \(want.sorted())")
            }
            // The positive signal: the same unscoped render over the headed table matches differently, so a lost prefix is
            // visible here.
            if try headed.rows(unscopedExpression) != want { headerObservable += 1 }
        }
        print("[1297] column prefix \(structured) compared=\(compared) headerObservable=\(headerObservable) failures=\(failures.values.reduce(0, +)) \(failures.keys.sorted().map { "\($0)=\(failures[$0]!)" }.joined(separator: " "))")
        #expect(compared > 7_000)
        #expect(headerObservable > compared / 2)
        #expect(failures.isEmpty, "\(samples)")
    }

    /// Row by row: a scoped word and the structured prefix reach only the body, and a structured excluded term every column.
    @Test("A scoped prefix wildcard does not match a header, and a structured excluded term in a header removes the row")
    func columnPrefixNamedRows() throws {
        let table = Issue1297StructuredTable(headed: [(header: "vietminh", body: "memo cold"),
                                                      (header: "", body: "memo cold vietcong"),
                                                      (header: "korea", body: "memo cold"),
                                                      (header: "cold", body: "memo war")])
        let prefix = StructuredQueryParts(prefixWildcard: "viet")
        let scopedPrefix = try #require(FTS5InlineQueryParser.parse("cold", columnPrefix: "{body_text}:", structured: prefix))
        #expect(scopedPrefix == "{body_text}:\"cold\" AND {body_text}:\"viet\"*")
        #expect(try table.rows(scopedPrefix) == [2], "the header vietminh is outside the scope")
        #expect(try table.rows(try #require(FTS5InlineQueryParser.parse("cold", structured: prefix))) == [1, 2])

        let scopedWord = try #require(FTS5InlineQueryParser.parse("cold", columnPrefix: "{body_text}:"))
        #expect(try table.rows(scopedWord) == [1, 2, 3], "the header cold is outside the scope")

        let excluded = try #require(FTS5InlineQueryParser.parse("cold", columnPrefix: "{body_text}:",
                                                                structured: StructuredQueryParts(excludedTerms: ["korea"])))
        #expect(excluded == "{body_text}:\"cold\" NOT \"korea\"")
        #expect(try table.rows(excluded) == [1, 2], "a structured excluded term found only in the header removes the row")
        let typedExclusion = try #require(FTS5InlineQueryParser.parse("cold -korea", columnPrefix: "{body_text}:"))
        #expect(try table.rows(typedExclusion) == [1, 2, 3], "a typed exclusion reaches only its own scope")
    }
}

// MARK: - The exact-term sweep's runs

/// One run of the exact-term sweep: an alphabet, a scope, and the counts measured on them.
struct Issue1297ExactSweep: Sendable, CustomTestStringConvertible {
    /// Names the alphabet in the test report.
    let name: String
    /// The tokens every sequence of length 1-4 is drawn from.
    let alphabet: [String]
    /// Whether every parse carries the `{body_text}:` prefix, over the two-column table.
    let scoped: Bool
    /// How many sequences the alphabet yields.
    let sequences: Int
    /// The applied marks on cold left unreported although filtering on them removes no row the query admits.
    let unprovedRequired: Int
    /// The approximations that match nothing and run, while the same text with every mark on cold respelled as one
    /// marker is refused: 6.1's refusal compares spellings, so only an alphabet of several spellings has any.
    var refusedOnlyRespelled = 0
    /// Names the run in the test report.
    var testDescription: String { "\(name)\(scoped ? ", scoped" : "")" }
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
    /// Whether its `=` mark is an exact-word post-filter.
    let isExactApplied: Bool

    /// Creates a model operand.
    init(text: String, isNegated: Bool, kind: ParsedOperand.Kind, source: ParsedOperand.Source, isExactApplied: Bool = false) {
        self.text = text
        self.isNegated = isNegated
        self.kind = kind
        self.source = source
        self.isExactApplied = isExactApplied
    }

    /// Projects a parsed operand onto what the model knows.
    init(_ operand: ParsedOperand) {
        self.init(text: operand.text, isNegated: operand.isNegated, kind: operand.kind, source: operand.source,
                  isExactApplied: operand.isExactApplied)
    }

    /// A compact form for failure messages.
    var description: String {
        "\(source == .structured ? "S:" : "")\(text)\(isNegated ? "(-)" : "")\(isExactApplied ? "(=)" : "")"
    }
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

    /// The rows the owner's policy searches for `model` under `negated`, with what the renderer can prove about
    /// them, or `nil` when nothing anchors; the leaves it leaves out are added to `dropped`.
    ///
    /// Row 1 holds no query term, so a set containing it is a complement FTS5 cannot search on its own.
    /// A conjunction (or a negated disjunction) approximates what anchors and excludes the rest exactly;
    /// a disjunction (or a negated conjunction) keeps what anchors and leaves out every leaf of the rest.
    /// `pushInward: false` is the rule before negation was pushed into a complement, kept to count how
    /// often pushing changes the answer. The root refusal is `searched`'s, not this function's.
    static func policy(_ model: Issue1297OracleModel, negated: Bool, pushInward: Bool,
                       _ harvest: Issue1297OracleHarvest, scoped: Bool, dropped: inout Set<Int>) -> Issue1297OracleAnchor? {
        let rows = effective(model, negated: negated, harvest)
        if !rows.contains(1) {
            return Issue1297OracleAnchor(rows: rows, proof: exactProof(model, negated: negated, harvest, scoped: scoped))
        }
        switch model {
        case .leaf:
            return nil
        case .not(let inner):
            return pushInward
                ? policy(inner, negated: !negated, pushInward: pushInward, harvest, scoped: scoped, dropped: &dropped)
                : nil
        case .and(let members) where !negated, .or(let members) where negated:
            var approximations: [Issue1297OracleAnchor] = []
            var exclusions: [Issue1297OracleProof] = []
            var excluded = Issue1297StructuredCorpus.all
            var local = Set<Int>()
            for member in members {
                var memberDropped = Set<Int>()
                if let anchored = policy(member, negated: negated, pushInward: pushInward, harvest, scoped: scoped,
                                         dropped: &memberDropped) {
                    approximations.append(anchored)
                    local.formUnion(memberDropped)
                } else {
                    excluded.formIntersection(effective(member, negated: negated, harvest))
                    exclusions.append(exactProof(member, negated: negated, harvest, scoped: scoped))
                }
            }
            guard let first = approximations.first else { return nil }
            dropped.formUnion(local)
            let approximation = approximations.dropFirst().reduce(first.rows) { $0.intersection($1.rows) }
            return Issue1297OracleAnchor(rows: approximation.intersection(excluded),
                                         proof: .conjunction(approximations.map(\.proof), exclusions))
        case .and(let members), .or(let members):
            var kept: [Issue1297OracleAnchor] = []
            for member in members {
                var memberDropped = Set<Int>()
                if let anchored = policy(member, negated: negated, pushInward: pushInward, harvest, scoped: scoped,
                                         dropped: &memberDropped) {
                    kept.append(anchored)
                    dropped.formUnion(memberDropped)
                } else {
                    dropped.formUnion(leaves(member))
                }
            }
            guard !kept.isEmpty else { return nil }
            return Issue1297OracleAnchor(rows: kept.reduce(Set<Int>()) { $0.union($1.rows) },
                                         proof: .disjunction(kept.map(\.proof)))
        }
    }

    /// The rows the query that runs searches: `policy` at the root, refused — `nil`, nothing dropped — when the query
    /// is approximated and the proof shows the approximation matches no document (parser 6.1).
    static func searched(_ root: Issue1297OracleModel, pushInward: Bool, _ harvest: Issue1297OracleHarvest,
                         scoped: Bool, dropped: inout Set<Int>) -> Set<Int>? {
        searchedAnchor(root, pushInward: pushInward, harvest, scoped: scoped, dropped: &dropped)?.rows
    }

    /// `searched`'s rows together with the proof of the expression that runs, whose required marked stems decide which
    /// `=` operands are exact-word post-filters (D1, D4).
    static func searchedAnchor(_ root: Issue1297OracleModel, pushInward: Bool, _ harvest: Issue1297OracleHarvest,
                               scoped: Bool, dropped: inout Set<Int>) -> Issue1297OracleAnchor? {
        var local = Set<Int>()
        guard let anchor = policy(root, negated: false, pushInward: pushInward, harvest, scoped: scoped, dropped: &local)
        else { return nil }
        if meaning(root, harvest).contains(1), anchor.proof.isEmpty { return nil }
        dropped.formUnion(local)
        return anchor
    }

    /// What the renderer can prove about `model`'s exact render under `negated`: about the documents it matches, or,
    /// for a complement, about the documents it lacks.
    ///
    /// Built the way the parser builds an exact render, member by member: a conjunction with a matching member is
    /// those members less the complements' exclusions, one without is the union of what they exclude, and a
    /// disjunction with a complement lacks the complements' conjunction less the matching alternatives.
    static func exactProof(_ model: Issue1297OracleModel, negated: Bool, _ harvest: Issue1297OracleHarvest,
                           scoped: Bool) -> Issue1297OracleProof {
        func signed(_ members: [Issue1297OracleModel]) -> (matching: [Issue1297OracleProof], lacking: [Issue1297OracleProof]) {
            var matching: [Issue1297OracleProof] = [], lacking: [Issue1297OracleProof] = []
            for member in members {
                let proof = exactProof(member, negated: negated, harvest, scoped: scoped)
                if effective(member, negated: negated, harvest).contains(1) {
                    lacking.append(proof)
                } else {
                    matching.append(proof)
                }
            }
            return (matching, lacking)
        }
        switch model {
        case .leaf(let index):
            return .leaf(key(index, harvest, scoped: scoped), index: index)
        case .not(let inner):
            return exactProof(inner, negated: !negated, harvest, scoped: scoped)
        case .and(let members) where !negated, .or(let members) where negated:
            let (matching, lacking) = signed(members)
            return matching.isEmpty ? .disjunction(lacking) : .conjunction(matching, lacking)
        case .and(let members), .or(let members):
            let (matching, lacking) = signed(members)
            guard !lacking.isEmpty else { return .disjunction(matching) }
            let excluded = Issue1297OracleProof.conjunction(lacking, [])
            return matching.isEmpty ? excluded : .conjunction([excluded], matching)
        }
    }

    /// The identity the proof compares a leaf by: its core without the column prefix, whether it carries one, and whether
    /// it carried `=`.
    ///
    /// A phrase never carries the prefix, nor does a structured excluded term; every other typed operand does, and
    /// so does the structured prefix wildcard. The mark is part of the key so that nothing here can take an unmarked
    /// leaf for a marked one: the refusal proof, which compares what a stemmed MATCH compares, drops it (`stem`), and the
    /// exact-term rule collects the stems of marked leaves only (D4).
    static func key(_ index: Int, _ harvest: Issue1297OracleHarvest, scoped: Bool) -> Issue1297OracleKey {
        let kind = harvest.kinds[index]
        let carriesPrefix = scoped && kind != .phrase && !(harvest.sources[index] == .structured && kind == .word)
        let text = harvest.texts[index]
        return Issue1297OracleKey(core: kind == .word || kind == .phrase ? "\"\(text)\"" : text, scoped: carriesPrefix,
                                  exact: harvest.exact[index])
    }
}

/// A leaf as the oracle's proof identifies it.
struct Issue1297OracleKey: Hashable {
    /// The leaf's core, without a column prefix.
    let core: String
    /// Whether it carries the column prefix.
    let scoped: Bool
    /// Whether it carried the `=` mark.
    let exact: Bool

    /// This key without the mark: what a stemmed MATCH compares, so `=cold` and `cold` are the same stem.
    var stem: Issue1297OracleKey { Issue1297OracleKey(core: core, scoped: scoped, exact: false) }

    /// Whether every document matching `anchor` matches `self`: the same core, in a scope spanning the anchor's. An
    /// unscoped leaf spans either; a scoped one only a scoped anchor.
    func covers(_ anchor: Issue1297OracleKey) -> Bool {
        core == anchor.core && (!scoped || anchor.scoped)
    }
}

/// What can be proved about an expression from its leaves alone, mirroring the parser's proof (6.1) over the
/// model — computed from operand identities, never from the rows anything matched.
struct Issue1297OracleProof {
    /// Stems every matching document matches.
    var required: Set<Issue1297OracleKey> = []
    /// Stems any one of which makes a document match.
    var sufficient: Set<Issue1297OracleKey> = []
    /// Stems no matching document matches.
    var forbidden: Set<Issue1297OracleKey> = []
    /// The stems of marked leaves every matching document matches through a marked leaf: the words whose `=` is a filter.
    var requiredMarked: Set<Issue1297OracleKey> = []
    /// Whether no document can match: a required leaf is covered by a forbidden one.
    var isEmpty = false

    /// The leaf harvested at `index`, identified by `key`.
    static func leaf(_ key: Issue1297OracleKey, index: Int) -> Issue1297OracleProof {
        Issue1297OracleProof(required: [key.stem], sufficient: [key.stem], requiredMarked: key.exact ? [key.stem] : [])
    }

    /// Every one of `positives` (at least one), less whatever any of `exclusions` matches.
    static func conjunction(_ positives: [Issue1297OracleProof], _ exclusions: [Issue1297OracleProof]) -> Issue1297OracleProof {
        var proof = Issue1297OracleProof()
        for positive in positives {
            proof.required.formUnion(positive.required)
            proof.forbidden.formUnion(positive.forbidden)
            proof.requiredMarked.formUnion(positive.requiredMarked)
        }
        for exclusion in exclusions { proof.forbidden.formUnion(exclusion.sufficient) }
        proof.sufficient = exclusions.isEmpty
            ? positives.dropFirst().reduce(positives[0].sufficient) { $0.intersection($1.sufficient) } : []
        proof.isEmpty = positives.contains { $0.isEmpty }
            || proof.required.contains { anchor in proof.forbidden.contains { $0.covers(anchor) } }
        return proof
    }

    /// Any one of `parts` (at least one).
    static func disjunction(_ parts: [Issue1297OracleProof]) -> Issue1297OracleProof {
        var proof = parts[0]
        for part in parts.dropFirst() {
            proof.required.formIntersection(part.required)
            proof.requiredMarked.formIntersection(part.requiredMarked)
            proof.sufficient.formUnion(part.sufficient)
            proof.forbidden.formIntersection(part.forbidden)
            proof.isEmpty = proof.isEmpty && part.isEmpty
        }
        return proof
    }
}

/// An anchored policy result: the rows it searches, and what the renderer can prove about them.
struct Issue1297OracleAnchor {
    /// The rows searched.
    let rows: Set<Int>
    /// What the operands alone prove about them.
    let proof: Issue1297OracleProof
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
