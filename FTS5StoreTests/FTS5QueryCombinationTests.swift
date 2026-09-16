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

// MARK: - FTS5QueryCombinationTests

/// `FTS5Query.toFTS5MatchExpression()` combining a keyword expression with a structured phrase,
/// prefix wildcard and excluded terms, every combination executed against a real FTS5 table.
///
/// Restored saved searches still carry those fields beside typed keywords, as the legacy Advanced
/// fields they were once set from; the macOS Advanced popover has not set them since 2026-06-08.
/// The builder used to join the parts with a bare space and append ` NOT "x"`, and
/// FTS5's precedence then regrouped them: juxtaposition binds tighter than `NOT`, a group
/// juxtaposed with a phrase is a syntax error, and `NOT` binds tighter than `OR`. #1297 made
/// more keyword expressions end in `NOT x` or a group, so the join is fixed alongside it.
///
/// ## What this suite does NOT cover
/// `FTS5Query` is a CARRIER: it receives a keyword expression as text, so it cannot see a typed
/// complement the typed parse left out, and every expectation here is built from that typed-alone
/// render. That is why the carrier sweep passed while the app discarded `-korea` beside a structured
/// phrase. The app combines typed and structured parts through
/// `FTS5InlineQueryParser.parseDetailed(_:columnPrefix:structured:)`, which
/// `Issue1297StructuredPartsTests` checks against a set oracle; read this suite as pinning the carrier's
/// bytes, never as app-path coverage.
///
/// Version history:
///   1.0 — #1297: initial implementation
///   1.1 — #1297 join: the sweep is renamed and documented as the carrier sweep it always was, and
///          `carrierIdentity` pins that a parsed expression passes through the carrier unchanged
///   1.2 — #1297 round-1 fixes: documentation only — no popover sets the structured fields; only restored saved
///          searches carry them
@Suite("FTS5Query part combination")
struct FTS5QueryCombinationTests {

    /// An in-memory `porter unicode61` table over `Issue1297Corpus`, with the app's own column
    /// name so a column-scoped query renders exactly the prefix the app renders.
    final class Table {
        /// The open database handle.
        private var db: OpaquePointer?

        /// Creates and seeds the table; `scoped` adds a header column beside the body, holding the constant
        /// 'heading' and no query word, so it names a column without making a lost column prefix visible.
        init(scoped: Bool) {
            sqlite3_open(":memory:", &db)
            sqlite3_exec(db, scoped
                ? "CREATE VIRTUAL TABLE d USING fts5(header, body_text, tokenize='porter unicode61');"
                : "CREATE VIRTUAL TABLE d USING fts5(body_text, tokenize='porter unicode61');", nil, nil, nil)
            for (index, body) in Issue1297Corpus.bodies.enumerated() {
                var stmt: OpaquePointer?
                sqlite3_prepare_v2(db, scoped
                    ? "INSERT INTO d(rowid, header, body_text) VALUES (?, 'heading', ?);"
                    : "INSERT INTO d(rowid, body_text) VALUES (?, ?);", -1, &stmt, nil)
                sqlite3_bind_int(stmt, 1, Int32(index + 1))
                sqlite3_bind_text(stmt, 2, body, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
        }

        deinit { sqlite3_close(db) }

        /// The matching rowids in order; throws when SQLite rejects the expression.
        func rows(_ expression: String) throws -> [Int] {
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, "SELECT rowid FROM d WHERE d MATCH ? ORDER BY rowid;", -1, &stmt, nil)
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

    /// A combination of typed keywords and structured fields, the expression it must render,
    /// and the rows that expression must match.
    struct Case: Sendable, CustomTestStringConvertible {
        /// What the researcher typed, parsed by `FTS5InlineQueryParser`; `nil` for the structured
        /// `keywords` path.
        let typed: String?
        /// Structured keywords, used when `typed` is `nil`.
        var keywords: [String] = []
        /// How structured keywords combine.
        var booleanMode: FTS5Query.BooleanMode = .and
        /// The structured phrase.
        var phrase: String?
        /// The structured prefix wildcard.
        var prefix: String?
        /// The structured excluded terms.
        var excluded: [String] = []
        /// Whether the query is scoped to `body_text`.
        var scoped = false
        /// The expression it must render.
        let rendered: String
        /// The rowids that expression must match.
        let rows: [Int]

        /// Names the case in the test report.
        var testDescription: String {
            let fields = [typed.map { "typed \($0)" }, keywords.isEmpty ? nil : "keywords \(keywords) \(booleanMode)",
                          phrase.map { "phrase \($0)" }, prefix.map { "prefix \($0)*" },
                          excluded.isEmpty ? nil : "excluded \(excluded)", scoped ? "scoped" : nil]
            return fields.compactMap { $0 }.joined(separator: ", ")
        }

        /// The query this case describes.
        var query: FTS5Query {
            let columns: [FTS5Column]? = scoped ? [.bodyText] : nil
            let keywordExpression = typed.flatMap {
                FTS5InlineQueryParser.parse($0, columnPrefix: scoped ? "{body_text}:" : "")
            }
            return FTS5Query(keywords: keywords, keywordExpression: keywordExpression, phrase: phrase,
                             booleanMode: booleanMode, excludedTerms: excluded, prefixWildcard: prefix,
                             columns: columns)
        }
    }

    /// Each part keeps its meaning beside the others.
    @Test("Keywords, phrase, prefix and exclusions combine as (keywords) AND phrase AND prefix AND NOT each exclusion",
          arguments: [
            // Was `"cold" NOT ("korea" OR "vietnam") "cold war"`: a syntax error.
            Case(typed: "cold -(korea OR vietnam)", phrase: "cold war",
                 rendered: "(\"cold\" NOT (\"korea\" OR \"vietnam\")) AND \"cold war\"", rows: [4]),
            // Was `"cold" AND ("korea" OR "vietnam") "cold war"`: a syntax error.
            Case(typed: "cold - (korea OR vietnam)", phrase: "cold war",
                 rendered: "(\"cold\" AND (\"korea\" OR \"vietnam\")) AND \"cold war\"", rows: [8, 12, 16]),
            // Was `"cold" NOT "korea" "viet"*`, which meant cold NOT (korea viet*).
            Case(typed: "cold -korea", prefix: "viet",
                 rendered: "(\"cold\" NOT \"korea\") AND \"viet\"*", rows: [10, 12]),
            // Was `"cold" OR "war" NOT "korea"`, excluding korea from the war documents only.
            Case(typed: "cold OR war", excluded: ["korea"],
                 rendered: "(\"cold\" OR \"war\") NOT \"korea\"", rows: [2, 3, 4, 10, 11, 12]),
            Case(typed: nil, keywords: ["cold", "war"], booleanMode: .or, excluded: ["korea"],
                 rendered: "(\"cold\" OR \"war\") NOT \"korea\"", rows: [2, 3, 4, 10, 11, 12]),
            Case(typed: "cold OR war", phrase: "cold war", prefix: "viet", excluded: ["korea"],
                 rendered: "((\"cold\" OR \"war\") AND \"cold war\" AND \"viet\"*) NOT \"korea\"", rows: [12]),
            Case(typed: "war (cold OR -korea)", prefix: "viet",
                 rendered: "(\"war\" NOT (\"korea\" NOT \"cold\")) AND \"viet\"*", rows: [11, 12, 16]),
            Case(typed: "NEAR(cold war, 5)", excluded: ["korea"],
                 rendered: "(NEAR(\"cold\" \"war\", 5)) NOT \"korea\"", rows: [4, 12]),
            Case(typed: "-korea cold", phrase: "cold war", scoped: true,
                 rendered: "({body_text}:\"cold\" NOT {body_text}:\"korea\") AND \"cold war\"", rows: [4, 12]),
            Case(typed: nil, keywords: ["cold", "war"], prefix: "viet", excluded: ["korea"], scoped: true,
                 rendered: "(({body_text}:\"cold\" {body_text}:\"war\") AND {body_text}:\"viet\"*) NOT \"korea\"", rows: [12]),
          ])
    func combinesParts(_ c: Case) throws {
        let table = Table(scoped: c.scoped)
        let expression = try #require(c.query.toFTS5MatchExpression())
        #expect(expression == c.rendered)
        let got = try table.rows(expression)
        #expect(got == c.rows)
    }

    /// Guards: a single part is emitted exactly as built, as it always was.
    @Test("A single part keeps the bytes it always had",
          arguments: [
            Case(typed: "cold -(korea OR vietnam)", rendered: "\"cold\" NOT (\"korea\" OR \"vietnam\")", rows: [2, 4]),
            Case(typed: "cold OR war", rendered: "\"cold\" OR \"war\"", rows: [2, 3, 4, 6, 7, 8, 10, 11, 12, 14, 15, 16]),
            Case(typed: nil, keywords: ["cold", "war"], rendered: "\"cold\" \"war\"", rows: [4, 8, 12, 16]),
            Case(typed: nil, keywords: ["cold"], excluded: ["korea"], rendered: "\"cold\" NOT \"korea\"", rows: [2, 4, 10, 12]),
            Case(typed: nil, phrase: "cold war", excluded: ["vietnam"], rendered: "\"cold war\" NOT \"vietnam\"", rows: [4, 8]),
            Case(typed: nil, prefix: "viet", scoped: true, rendered: "{body_text}:\"viet\"*",
                 rows: [9, 10, 11, 12, 13, 14, 15, 16]),
          ])
    func singlePartUnchanged(_ c: Case) throws {
        try combinesParts(c)
    }

    /// FTS5 has no unary NOT.
    @Test("Exclusions with no positive part still render nil")
    func exclusionsAloneAreNil() {
        #expect(FTS5Query(excludedTerms: ["korea"]).toFTS5MatchExpression() == nil)
        #expect(FTS5Query(keywordExpression: nil, excludedTerms: ["korea", "vietnam"]).toFTS5MatchExpression() == nil)
    }

    /// The atomicity rule the parenthesising relies on.
    @Test("Only a lone quoted operand or one whole parenthesised group counts as a single operand")
    func singleOperandRecognition() {
        for single in ["\"cold\"", "\"cold war\"", "\"negoti\"*", "{body_text}:\"cold\"", "{header body_text}:\"negoti\"*",
                       "(\"cold\" OR \"war\")", "(\"a ) b\" OR \"c\")", "\"say \"\"no\"\"\""] {
            #expect(FTS5Query.isSingleOperand(single), "\(single)")
        }
        for compound in ["\"cold\" \"war\"", "\"cold\" OR \"war\"", "\"cold\" NOT \"korea\"", "(\"cold\") NOT \"vietnam\"",
                         "NEAR(\"cold\" \"war\", 5)", "{body_text}:\"cold\" NOT {body_text}:\"korea\"", "\"unterminated",
                         "", "(\"a\" OR \"b\"", "\"a\" \"\"", "{body_text}:(\"a\" OR \"b\")"] {
            #expect(!FTS5Query.isSingleOperand(compound), "\(compound)")
        }
    }

    /// The FTS5Query carrier sweep: every typed shape of the #1297 sweep, rendered ALONE by the inline
    /// parser and handed to `FTS5Query` beside every structured field, joins into what the two halves mean.
    ///
    /// The expected rows start from the typed-alone render, so a typed complement that render left out is
    /// left out of the expectation too. This certifies the join, not the app's answer — a typed `-korea`
    /// beside a phrase passes here as `"cold war"`. The app path is `Issue1297StructuredPartsTests`.
    @Test("FTS5Query carrier combination sweep: every typed-alone render joined with a phrase, prefix and exclusions is valid and matches what the parts mean",
          arguments: [false, true])
    func carrierCombinationSweep(scoped: Bool) throws {
        let table = Table(scoped: scoped)
        let columnPrefix = scoped ? "{body_text}:" : ""
        let phraseRows = Set(try table.rows("\"cold war\""))
        let prefixRows = Set(try table.rows(columnPrefix + "\"viet\"*"))
        let combinations: [(phrase: String?, prefix: String?, excluded: [String])] = [
            (nil, nil, []), ("cold war", nil, []), (nil, "viet", []), (nil, nil, ["korea"]), (nil, nil, ["korea", "vietnam"]),
            ("cold war", nil, ["vietnam"]), (nil, "viet", ["korea"]), ("cold war", "viet", []), ("cold war", "viet", ["korea"]),
        ]
        var compared = 0, executed = 0
        var failures: [String] = []
        for typed in Issue1297PropertyTests.sequences(maxLength: 4) {
            let keyword = FTS5InlineQueryParser.parse(typed, columnPrefix: columnPrefix)
            let keywordRows = try keyword.map { Set(try table.rows($0)) }
            for combination in combinations {
                compared += 1
                var positives: [Set<Int>] = keywordRows.map { [$0] } ?? []
                if combination.phrase != nil { positives.append(phraseRows) }
                if combination.prefix != nil { positives.append(prefixRows) }
                let expected: Set<Int>? = positives.first.map { first in
                    combination.excluded.reduce(positives.dropFirst().reduce(first) { $0.intersection($1) }) {
                        $0.subtracting(Issue1297Corpus.rows(with: $1))
                    }
                }
                let query = FTS5Query(keywordExpression: keyword, phrase: combination.phrase,
                                      excludedTerms: combination.excluded, prefixWildcard: combination.prefix,
                                      columns: scoped ? [.bodyText] : nil)
                guard let expression = query.toFTS5MatchExpression() else {
                    if expected != nil { failures.append("\(typed) \(combination) -> nil") }
                    continue
                }
                executed += 1
                do {
                    let got = Set(try table.rows(expression))
                    if got != expected { failures.append("\(typed) \(combination) -> \(expression) matched \(got.sorted())") }
                } catch {
                    failures.append("\(typed) \(combination) -> \(expression) rejected")
                }
            }
        }
        print("[1297] join scoped=\(scoped) compared=\(compared) executed=\(executed) failures=\(failures.count)")
        #expect(compared == 66_420)
        #expect(executed > 60_000)
        #expect(failures.isEmpty, "\(failures.prefix(5))")
    }

    /// `CorpusAnalyticsService` hands a parsed expression to `FTS5Query(keywordExpression:)` with nothing
    /// beside it, so the carrier must give that expression back byte for byte.
    @Test("A parsed expression carried through FTS5Query alone comes back unchanged, with and without a column scope")
    func carrierIdentity() {
        let sequences = Issue1297PropertyTests.sequences(maxLength: 4, over: Issue1297PropertyTests.alphabet + ["-("])
        #expect(sequences.count == 11_110)
        var carried = 0
        var mismatches: [String] = []
        for (prefix, columns) in [("", nil), ("{body_text}:", [FTS5Column.bodyText])] as [(String, [FTS5Column]?)] {
            for typed in sequences {
                guard let expression = FTS5InlineQueryParser.parse(typed, columnPrefix: prefix) else { continue }
                carried += 1
                let back = FTS5Query(keywordExpression: expression, columns: columns).toFTS5MatchExpression()
                if back != expression { mismatches.append("\(typed) [\(prefix)] \(expression) -> \(back ?? "nil")") }
            }
        }
        print("[1297] carrier identity carried=\(carried) mismatches=\(mismatches.count)")
        #expect(carried >= 20_000)
        #expect(mismatches.isEmpty, "\(mismatches.prefix(5))")
    }
}
