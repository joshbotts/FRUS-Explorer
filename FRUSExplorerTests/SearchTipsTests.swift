// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
import SQLite3
@testable import FRUSExplorer

// MARK: - SearchTipsTests

/// Pins the search-syntax reference both Search surfaces render (#1299) against what the query actually does.
///
/// The macOS Tips panel was a column of literals typed beside the parser, and it drifted: its NEAR row gave neither the
/// default distance nor what cannot go inside, its date row named an attribute the index no longer prefers, and its
/// scope row said a change persisted when nothing writes it back. So this suite drives the ONE array the views read,
/// `SearchTip.syntaxRows`, and parses each row's own `example` — never a copy of it — through
/// `FTS5InlineQueryParser.parseDetailed`, the parse `SearchService` runs.
///
/// The sweep switches exhaustively over `tip.id`, so a row added to the model without an assertion here does not
/// compile, and it counts the rows it checked, so an empty array cannot pass.
///
/// Claims that belong to SQLite rather than the parser — stemming, a prefix matched against stems, NEAR's distance
/// and order, a phrase's order, the exact-word post-filter — are executed against an in-memory
/// `fts5(body_text, tokenize='porter unicode61')` table, with every exact term applied through `ExactWordMatcher` as
/// the SQL layer applies it. Every absence is asserted only after a positive count over the same kind of row, so a
/// table that matched nothing could not pass. These run on the simulator's SQLite, not the macOS build the design
/// brief probed.
///
/// Wording is pinned only where it states something checkable: a number (NEAR's distances, as whole numbers), a piece
/// of syntax (the prefixes, `NOT NEAR(`), a word form the row says matches or does not (as whole words), a fold the
/// exact-word filter applies, the one place an exclusion-only alternative is kept, or the Query Inspector's tag. The
/// rest of the prose is the owner's to edit through `Docs/EditableContent.md`.
///
/// Version history:
///   1.0 — #1299: initial implementation
///   1.1 — #1299 follow-up: four details corrected against the parser and SQLite, each now pinned — the exact-word row
///         said `=` matches a word "only as you typed it" (it folds capitalization, a single accent and edge
///         punctuation, and is ignored inside `NEAR(…)`); the prefix row said `negotiat*` "finds nothing" (it finds
///         `negotiatory`, 21 times in the shipped corpus); the last row said every exclusion-only OR alternative is left
///         out (beside a word it is searched exactly). NEAR's distances and the word forms are read as whole tokens,
///         since "15" contains "5"; no string may be its own localization key, which is what an emptied default
///         renders; a spoken label must say every word and number of its example; and the index reads that follow a
///         count are `try #require`, so a short split fails the test instead of trapping the host.
///   1.2 — #1299 round 2: the exact-word row must name a word the index splits into several terms among the places the
///         mark is always ignored, and `=anti-communist` is executed over "anti-communists" to show it is; the prefix
///         check's doc gives `negotiatory` as 21 occurrences in 8 volume files, where it said "in 26 volumes".
@Suite("Search Tips say what the query actually does")
struct SearchTipsTests {

    private func p(_ query: String) -> ParsedQuery { FTS5InlineQueryParser.parseDetailed(query) }

    /// The letters-or-digits runs of `text`, lowercased — the words and numbers a sentence states, so `15` is not `5`
    /// and `containing` is not `contain`.
    private static func tokens(_ text: String) -> [String] {
        text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }

    // MARK: - SQLite execution

    /// How many of `rows` the query matches in an in-memory `porter unicode61` table, with its exact terms applied as
    /// `ExactWordMatcher` applies them. Fails the test when the query renders nothing or SQLite rejects the expression.
    private func count(_ query: String, over rows: [String]) throws -> Int {
        let parsed = p(query)
        let expression = try #require(parsed.expression, "\(query) rendered no expression")
        var db: OpaquePointer?
        try #require(sqlite3_open(":memory:", &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        try #require(sqlite3_exec(db, "CREATE VIRTUAL TABLE t USING fts5(body_text, tokenize='porter unicode61');",
                                  nil, nil, nil) == SQLITE_OK)
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for row in rows {
            var insert: OpaquePointer?
            try #require(sqlite3_prepare_v2(db, "INSERT INTO t(body_text) VALUES (?);", -1, &insert, nil) == SQLITE_OK)
            sqlite3_bind_text(insert, 1, row, -1, transient)
            let stepped = sqlite3_step(insert)
            sqlite3_finalize(insert)
            try #require(stepped == SQLITE_DONE)
        }
        var select: OpaquePointer?
        try #require(sqlite3_prepare_v2(db, "SELECT body_text FROM t WHERE t MATCH ?;", -1, &select, nil) == SQLITE_OK)
        defer { sqlite3_finalize(select) }
        sqlite3_bind_text(select, 1, expression, -1, transient)
        var matched = 0
        while true {
            let rc = sqlite3_step(select)
            if rc == SQLITE_DONE { break }
            try #require(rc == SQLITE_ROW, "SQLite rejected \(expression): \(String(cString: sqlite3_errmsg(db)))")
            let text = String(cString: sqlite3_column_text(select, 0))
            if parsed.exactTerms.allSatisfy({ ExactWordMatcher.contains(word: $0, in: text) }) { matched += 1 }
        }
        return matched
    }

    @Test("The execution helper counts matches, and applies an exact term")
    func executionHelperIsSound() throws {
        #expect(try count("cold", over: ["cold war", "colds", "warm peace"]) == 2)
        #expect(try count("=cold", over: ["cold war", "colds", "warm peace"]) == 1)
    }

    // MARK: - The set

    @Test("Thirteen rows, one per rule, in the order shown")
    func rowSetIsPinned() {
        let rows = SearchTip.syntaxRows
        #expect(rows.map(\.id) == [.allWords, .stemming, .phrase, .either, .operatorWords, .exclude,
                                   .excludeAcrossOr, .group, .excludeGroup, .prefix, .near, .exactWord, .needsAWord])
        #expect(Set(rows.map(\.id)) == Set(SearchTip.ID.allCases))
        #expect(rows.count == SearchTip.ID.allCases.count, "a rule appears twice")
    }

    @Test("Every example is verbatim ASCII, and every spoken label and detail says something")
    func examplesAreASCIIAndLabelsArePresent() {
        let rows = SearchTip.syntaxRows
        #expect(!rows.isEmpty)
        for tip in rows {
            #expect(!tip.example.isEmpty, "\(tip.id)")
            let isASCII = tip.example.unicodeScalars.allSatisfy { $0.isASCII }
            #expect(isASCII, "\(tip.id)'s example is not typeable as shown: \(tip.example)")
            #expect(tip.example == tip.example.trimmingCharacters(in: .whitespacesAndNewlines), "\(tip.id)")
            #expect(!tip.spokenExample.isEmpty, "\(tip.id)")
            #expect(!tip.detail.isEmpty, "\(tip.id)")
            // A literal key whose default value is emptied renders the KEY, not nothing (measured with swiftc), so a
            // row reading "search.tips.near.detail" passes every emptiness check above.
            #expect(!tip.detail.hasPrefix("search.tips."), "\(tip.id)'s detail renders its key: \(tip.detail)")
            #expect(!tip.spokenExample.hasPrefix("search.tips."), "\(tip.id)'s spoken label renders its key")
            // VoiceOver reads the spoken label INSTEAD of the chip, so it must say every word and number the chip shows:
            // a label reading "comma, 50," over `NEAR(military europe, 5)` describes a different query.
            let spoken = Set(Self.tokens(tip.spokenExample))
            let unspoken = Self.tokens(tip.example).filter { !spoken.contains($0) }
            #expect(unspoken.isEmpty, "\(tip.id)'s spoken label drops \(unspoken) from \(tip.example): \(tip.spokenExample)")
            #expect(tip.accessibilityLabel.contains(tip.spokenExample) && tip.accessibilityLabel.contains(tip.detail),
                    "\(tip.id)'s VoiceOver label drops part of the row")
        }
        #expect(Set(rows.map(\.example)).count == rows.count, "two rows show the same example")
    }

    // MARK: - The sweep

    @Test("Every row's claims hold for its own example")
    func everyRowsClaimsHold() throws {
        var checked: Set<SearchTip.ID> = []
        for tip in SearchTip.syntaxRows {
            switch tip.id {
            case .allWords: try checkAllWords(tip)
            case .stemming: try checkStemming(tip)
            case .phrase: try checkPhrase(tip)
            case .either: try checkEither(tip)
            case .operatorWords: try checkOperatorWords(tip)
            case .exclude: try checkExclude(tip)
            case .excludeAcrossOr: try checkExcludeAcrossOr(tip)
            case .group: try checkGroup(tip)
            case .excludeGroup: try checkExcludeGroup(tip)
            case .prefix: try checkPrefix(tip)
            case .near: try checkNear(tip)
            case .exactWord: try checkExactWord(tip)
            case .needsAWord: try checkNeedsAWord(tip)
            }
            checked.insert(tip.id)
        }
        #expect(checked == Set(SearchTip.ID.allCases), "rows not checked: \(Set(SearchTip.ID.allCases).subtracting(checked))")
    }

    /// `berlin crisis`: every word, in any order; an explicit AND, in any case, is the same search.
    private func checkAllWords(_ tip: SearchTip) throws {
        let words = tip.example.split(separator: " ").map(String.init)
        try #require(words.count == 2, "the checks below read two words of \(tip.example)")
        #expect(p(tip.example).expression == words.map { "\"\($0)\"" }.joined(separator: " AND "))
        #expect(p(words.joined(separator: " AND ")).expression == p(tip.example).expression)
        #expect(p(words.joined(separator: " and ")).expression == p(tip.example).expression)
        #expect(p(tip.example).operands.map(\.kind) == [.word, .word])
        let forwards = words.joined(separator: " ")
        let backwards = "\(words[1]) in \(words[0])"
        #expect(try count(tip.example, over: ["the \(forwards) deepened", backwards]) == 2, "in any order")
        #expect(try count(tip.example, over: ["\(words[0]) only", "\(words[1]) only"]) == 0, "every word")
    }

    /// `negotiate`: the parser does not stem; SQLite matches the word forms the detail names.
    private func checkStemming(_ tip: SearchTip) throws {
        #expect(p(tip.example).expression == "\"\(tip.example)\"", "the parser passes the word through unstemmed")
        let forms = ["negotiated", "negotiations"]
        for form in forms {
            #expect(tip.detail.contains(form), "the detail no longer names \(form), which this checks")
            #expect(try count(tip.example, over: ["The \(form) went on"]) == 1, "\(tip.example) does not find \(form)")
        }
        #expect(try count(tip.example, over: ["The treaty was signed"]) == 0)
    }

    /// `"cold war"`: a phrase in straight or typographic marks, in order, which cannot hold marks of its own.
    private func checkPhrase(_ tip: SearchTip) throws {
        #expect(tip.example.hasPrefix("\"") && tip.example.hasSuffix("\""))
        let inner = String(tip.example.dropFirst().dropLast())
        #expect(p(tip.example).expression == "\"\(inner)\"")
        #expect(p(tip.example).operands.map(\.kind) == [.phrase])
        for (open, close) in [("\u{201C}", "\u{201D}"), ("\u{201E}", "\u{201C}"), ("\u{00AB}", "\u{00BB}")] {
            #expect(p(open + inner + close) == p(tip.example), "\(open)…\(close) is not the same phrase")
        }
        let nested = p("\"the \u{201C}\(inner)\u{201D} speech\"")
        #expect(nested.operands.count == 4, "a phrase holding marks of its own is split into words")
        #expect(nested.expression != "\"the \(inner) speech\"")

        let words = inner.split(separator: " ").map(String.init)
        try #require(words.count == 2, "the order check below reads two words of \(tip.example)")
        #expect(try count(tip.example, over: ["the \(inner) began"]) == 1, "in order")
        #expect(try count(tip.example, over: ["\(words[1]) turned \(words[0])"]) == 0, "not out of order")
    }

    /// `rusk OR bundy`: either word, OR in any case, and OR divides everything before it from everything after it.
    private func checkEither(_ tip: SearchTip) throws {
        let parts = tip.example.components(separatedBy: " OR ")
        try #require(parts.count == 2, "the checks below read both sides of \(tip.example)")
        let rendered = "\"\(parts[0])\" OR \"\(parts[1])\""
        #expect(p(tip.example).expression == rendered)
        #expect(p(parts.joined(separator: " or ")).expression == rendered)
        #expect(p(parts.joined(separator: " Or ")).expression == rendered)
        #expect(p("cold war OR peace").expression == "\"cold\" AND \"war\" OR \"peace\"")
        #expect(try count(tip.example, over: ["\(parts[0]) memo", "\(parts[1]) memo", "mcnamara memo"]) == 2)
    }

    /// `"will not intervene"`: unquoted, the operator word is an operator; quoted, the words are a phrase.
    private func checkOperatorWords(_ tip: SearchTip) throws {
        let inner = String(tip.example.dropFirst().dropLast())
        #expect(p(tip.example).expression == "\"\(inner)\"")
        #expect(p(inner).expression == "\"will\" NOT \"intervene\"", "unquoted, not is an operator")
        #expect(p("\"and\"").expression == "\"and\"")
        #expect(p("\"or\"").expression == "\"or\"")
        #expect(try count(tip.example, over: ["we \(inner)"]) == 1, "quoted, the sentence is found")
        #expect(try count(inner, over: ["we will decide"]) == 1, "unquoted, a different search runs")
        #expect(try count(inner, over: ["we \(inner)"]) == 0, "unquoted, the sentence is left out")
    }

    /// `vietnam -laos`: a touching minus sign or NOT excludes, wherever it sits.
    private func checkExclude(_ tip: SearchTip) throws {
        let expected = "\"vietnam\" NOT \"laos\""
        #expect(p(tip.example).expression == expected)
        #expect(p(tip.example).operands.last?.isNegated == true)
        for spelling in ["-laos vietnam", "vietnam NOT laos", "vietnam not laos", "NOT laos vietnam",
                         "vietnam AND NOT laos", "vietnam AND -laos"] {
            #expect(p(spelling).expression == expected, "\(spelling)")
        }
        #expect(try count(tip.example, over: ["vietnam only"]) == 1)
        #expect(try count(tip.example, over: ["vietnam laos"]) == 0)
    }

    /// `(cold OR war) -korea`: without the parentheses the exclusion stops at OR.
    private func checkExcludeAcrossOr(_ tip: SearchTip) throws {
        #expect(p(tip.example).expression == "(\"cold\" OR \"war\") NOT \"korea\"")
        let ungrouped = tip.example.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
        #expect(p(ungrouped).expression == "\"cold\" OR \"war\" NOT \"korea\"")
        #expect(try count(ungrouped, over: ["cold korea"]) == 1, "ungrouped, cold korea is still returned")
        #expect(try count(tip.example, over: ["war only", "cold only"]) == 2)
        #expect(try count(tip.example, over: ["cold korea"]) == 0, "grouped, it is excluded")
    }

    /// `(aqaba OR tiran) navig*`: the group and the words beside it must all match.
    private func checkGroup(_ tip: SearchTip) throws {
        #expect(p(tip.example).expression == "(\"aqaba\" OR \"tiran\") AND \"navig\"*")
        #expect(try count(tip.example, over: ["navigation through tiran", "aqaba navigable"]) == 2)
        #expect(try count(tip.example, over: ["aqaba only", "navigation only"]) == 0)
    }

    /// `vietnam -(laos OR cambodia)`: NOT or a touching minus sign excludes the group; a detached one searches for it.
    private func checkExcludeGroup(_ tip: SearchTip) throws {
        let expected = "\"vietnam\" NOT (\"laos\" OR \"cambodia\")"
        #expect(p(tip.example).expression == expected)
        #expect(p("vietnam NOT (laos OR cambodia)").expression == expected)
        #expect(p("-(laos OR cambodia) vietnam").expression == expected)
        let detached = tip.example.replacingOccurrences(of: "-(", with: "- (")
        #expect(detached != tip.example)
        #expect(p(detached).expression == "\"vietnam\" AND (\"laos\" OR \"cambodia\")", "a detached minus sign is ignored")
        #expect(try count(tip.example, over: ["vietnam only"]) == 1)
        #expect(try count(tip.example, over: ["vietnam laos", "vietnam cambodia"]) == 0)
    }

    /// `negoti*`: a prefix is matched against stems, so the short prefix the detail names finds a form the longer one it
    /// names misses. The longer one is not a prefix that finds NOTHING, though — a word whose own stem keeps its letters
    /// still matches, and the shipped corpus has one: `negotiatory`, 21 times in 8 volume files, and misspellings such as
    /// `negotiatons` in more (#1299 review). So the detail may say the long prefix misses a form, and may not say it finds
    /// nothing.
    private func checkPrefix(_ tip: SearchTip) throws {
        let stem = String(tip.example.dropLast())
        #expect(tip.example.hasSuffix("*"))
        #expect(p(tip.example).expression == "\"\(stem)\"*")
        #expect(p(tip.example).operands.map(\.kind) == [.prefix])

        let prefixes = tip.detail.split(separator: " ")
            .map { $0.trimmingCharacters(in: CharacterSet.punctuationCharacters.subtracting(CharacterSet(charactersIn: "*"))) }
            .filter { $0.hasSuffix("*") }
        #expect(prefixes.count == 2, "the detail should name the example and a prefix too long to match: \(prefixes)")
        #expect(prefixes.contains(tip.example), "the detail's working prefix is not the example: \(prefixes)")
        let tooLong = try #require(prefixes.first { $0 != tip.example }, "the detail names no longer prefix: \(prefixes)")
        let letters = String(tooLong.dropLast()).lowercased()
        #expect(letters.count > stem.count && letters.hasPrefix(stem), "\(tooLong) is not a longer form of \(tip.example)")

        // The form the detail says the long prefix misses and the example finds.
        let form = "negotiations"
        #expect(Self.tokens(tip.detail).contains(form), "the detail no longer names \(form), which this checks")
        let formRow = "Negotiations with the Soviets resumed"
        #expect(formRow.lowercased().contains(letters), "precondition: \(form) is spelled with \(tooLong)'s letters")
        #expect(try count(tip.example, over: [formRow, "A negotiated settlement was reached"]) == 2)
        #expect(try count(tooLong, over: [formRow]) == 0, "\(tooLong) should miss \(form), whose stem is shorter than it")

        // Not nothing: a word whose stem keeps the letters is found.
        #expect(try count(tooLong, over: ["the negotiatory process"]) == 1,
                "precondition: \(tooLong) finds negotiatory, whose stem keeps its letters")
        #expect(!tip.detail.contains("nothing"),
                "the detail says \(tooLong) finds nothing, but it finds negotiatory, which the corpus prints")
    }

    /// `NEAR(military europe, 5)`: within the distance the detail states, in either order; the default the detail
    /// states when the number is left out; no booleans inside; only NOT NEAR(…) excludes.
    private func checkNear(_ tip: SearchTip) throws {
        let explicit = p(tip.example)
        #expect(explicit.operands.map(\.kind) == [.proximity])
        let distance = try #require(Self.trailingDistance(explicit.expression), "no distance in \(explicit.expression ?? "nil")")
        let withoutNumber = tip.example.replacingOccurrences(of: ", \(distance)", with: "")
        #expect(withoutNumber != tip.example)
        let defaultDistance = try #require(Self.trailingDistance(p(withoutNumber).expression),
                                           "no default distance for \(withoutNumber)")
        // Whole numbers, and exactly these two: "within 15 words" contains the characters "5".
        let stated = Set(Self.tokens(tip.detail).filter { Int($0) != nil })
        #expect(stated == [distance, defaultDistance],
                "the detail states the distances \(stated); the example's is \(distance) and the default \(defaultDistance)")

        #expect(p(tip.example.replacingOccurrences(of: "NEAR", with: "near")).expression == explicit.expression)
        #expect(p("NEAR(\u{201C}military guarantee\u{201D} europe, 30)").expression
                == "NEAR(\"military guarantee\" \"europe\", 30)", "a phrase may go inside")
        #expect(p("NEAR(milit* europ*, 20)").operands.map(\.kind) == [.proximity], "a prefix may go inside")
        for inside in ["NEAR(military OR europe, 5)", "NEAR(military NOT europe, 5)", "NEAR((military europe), 5)"] {
            let hasProximity = p(inside).operands.contains { $0.kind == .proximity }
            #expect(!hasProximity, "\(inside) is not a proximity search")
        }

        #expect(tip.detail.contains("NOT NEAR("))
        let notNear = p("aid NOT " + tip.example).expression
        #expect(notNear == "\"aid\" NOT NEAR(\"military\" \"europe\", \(distance))")
        let dashNear = p("aid -" + tip.example).expression
        #expect(dashNear != notNear)
        #expect(!(dashNear ?? "").contains("NOT NEAR("), "a minus sign does not exclude a NEAR")

        for (query, limit) in [(tip.example, distance), (withoutNumber, defaultDistance)] {
            let words = try #require(Int(limit))
            let filler = (0...words).map { "w\($0)" }
            let atLimit = filler.prefix(words).joined(separator: " ")
            #expect(try count(query, over: ["military \(atLimit) europe"]) == 1, "\(words) words between")
            #expect(try count(query, over: ["europe \(atLimit) military"]) == 1, "in either order")
            #expect(try count(query, over: ["military \(filler.joined(separator: " ")) europe"]) == 0,
                    "\(words + 1) words between")
        }
    }

    /// The number after the last comma of a rendered `NEAR(…, n)`.
    private static func trailingDistance(_ expression: String?) -> String? {
        guard let expression, expression.hasSuffix(")"), let comma = expression.lastIndex(of: ",") else { return nil }
        let number = expression[expression.index(after: comma)..<expression.index(before: expression.endIndex)]
            .trimmingCharacters(in: .whitespaces)
        return Int(number) == nil ? nil : number
    }

    /// `=containment`: stemming off for that word — and nothing else. The mark folds capitalization, a single accent and
    /// punctuation at either end, as `ExactWordMatcher` reads a word, so a detail saying it matches the word "only as
    /// you typed it" is false (`=Hull` counts every ship's hull). It is ignored where a match need not contain the
    /// word, on a prefix, inside `NEAR(…)`, whose operands carry no exact term, and on a word the index splits into
    /// several terms, which has no single word to filter on.
    private func checkExactWord(_ tip: SearchTip) throws {
        let word = String(tip.example.dropFirst())
        #expect(p(tip.example).exactTerms == [word])
        #expect(p(tip.example).operands.first?.isExactApplied == true)
        #expect(p("=cold war").exactTerms == ["cold"])
        #expect(p("=cold OR war").exactTerms == [], "ignored on one side of an OR")
        #expect(p("=cold war OR =cold peace").exactTerms == ["cold"])
        #expect(p("=negoti*").exactTerms == [], "ignored on a prefix")
        #expect(p("=U.S.S.R.").exactTerms == [])

        let forms = ["contain", "containing"]
        let stated = Set(Self.tokens(tip.detail))
        for form in forms { #expect(stated.contains(form), "the detail no longer names \(form), which this checks") }
        let rows = ["the \(word) policy of Kennan", "we \(forms[0]) the threat", "\(forms[1]) Soviet expansion"]
        #expect(try count(word, over: rows) == 3, "stemmed, the word finds its other forms")
        #expect(try count(tip.example, over: rows) == 1, "marked, it finds only itself")

        // What the mark folds: every capitalization and edge punctuation of the word, a single accent — and no other form.
        #expect(tip.detail.lowercased().contains("stemming"), "the detail no longer says the mark turns stemming off")
        #expect(!tip.detail.contains("as you typed"), "the detail says the word matches only as typed; the mark folds case")
        for fold in ["capitaliz", "accent", "punctuation"] {
            #expect(tip.detail.lowercased().contains(fold), "the detail no longer says the mark ignores \(fold)…")
        }
        let folded = ["the \(word.capitalized) policy", word.uppercased(), "\(word).", "\(word)s", forms[0], forms[1]]
        #expect(try count(tip.example, over: folded) == 3, "every capitalization and edge punctuation, and no other form")
        #expect(try count("=" + word.uppercased(), over: folded) == 3, "however the mark itself is capitalized")
        #expect(try count("=cafe", over: ["the Caf\u{00E9}", "cafes"]) == 1, "a single accent is folded; the plural is not")

        // Inside NEAR(…) the mark is dropped, so the detail names NEAR among the places it is ignored.
        let nearQuery = "NEAR(\(tip.example) policy, 5)"
        #expect(p(nearQuery).operands.map(\.kind) == [.proximity])
        #expect(p(nearQuery).exactTerms == [], "the mark reached inside NEAR")
        let nearRows = ["containers policy", "\(word) policy"]
        #expect(try count("\(tip.example) policy", over: nearRows) == 1, "precondition: outside NEAR the mark applies")
        #expect(try count(nearQuery, over: nearRows) == 2, "inside NEAR the mark is ignored")
        #expect(tip.detail.contains("NEAR("), "the detail does not say the = is ignored inside NEAR(…)")

        // On a word the index splits into several terms the mark is dropped too, and the word is searched by its stems:
        // `=anti-Communist` still counts anti-Communists, a form the corpus prints 185 times beside 4,578 anti-Communist.
        // So the detail names that case among the places the mark is always ignored (both manuals and the Corpus
        // Analytics Multiple words row already do).
        let split = "anti-Communist"
        #expect(p("=" + split).exactTerms == [], "the mark reached a word the index splits")
        let splitRows = ["the \(split.lowercased())s met"]
        #expect(try count("=communist", over: splitRows) == 0,
                "precondition: where the mark applies, the plural of a hyphenated word is refused")
        #expect(try count("=" + split.lowercased(), over: splitRows) == 1, "on a split word the mark is ignored")
        #expect(tip.detail.contains(split) && tip.detail.contains("splits"),
                "the detail does not say the = is ignored on a word the index splits, such as \(split)")
    }

    /// `-korea`: a query of exclusions alone is refused; an exclusion-only alternative is left out, and the detail
    /// names the tag the Query Inspector marks it with — except in parentheses beside a word to search for, where the
    /// same alternative is searched exactly and nothing is left out (the parser's Exclusions rule, and both manuals).
    private func checkNeedsAWord(_ tip: SearchTip) throws {
        for query in [tip.example, "NOT korea", "-korea -vietnam", "-(korea OR vietnam)", "-korea OR -vietnam"] {
            #expect(p(query) == ParsedQuery(expression: nil, exactTerms: []), "\(query) should not run")
        }
        let partial = p("cold OR " + tip.example)
        #expect(partial.expression == "\"cold\"")
        #expect(partial.droppedOperands.map(\.text) == ["korea"])
        #expect(partial.droppedOperands.first?.isNegated == true)
        #expect(partial.isApproximate)

        // Beside a word to search for, nothing is left out: `war (cold OR -korea)` renders `"war" NOT ("korea" NOT
        // "cold")`. Joined to the word by OR instead, the group is beside nothing, and the alternative is left out.
        let besideQuery = "war (cold OR \(tip.example))"
        let beside = p(besideQuery)
        #expect(beside.expression != nil)
        #expect(beside.droppedOperands.isEmpty, "\(besideQuery) left out \(beside.droppedOperands.map(\.text))")
        #expect(!beside.isApproximate)
        #expect(p("(cold OR \(tip.example)) war").droppedOperands.isEmpty)
        #expect(try count(besideQuery, over: ["war only", "war cold korea"]) == 2)
        #expect(try count(besideQuery, over: ["war korea"]) == 0, "the exclusion is applied, not left out")
        #expect(p("war OR (cold OR \(tip.example))").droppedOperands.map(\.text) == ["korea"])
        #expect(tip.detail.contains("beside a word"),
                "the detail says every exclusion-only alternative is left out; beside a word it is searched exactly")

        let tag = try Self.inspectorNotAppliedTag()
        #expect(tip.detail.contains(tag), "the detail does not name the Query Inspector's tag, \(tag)")
    }

    /// The Query Inspector's NOT APPLIED tag, read from `QueryInspectorView.swift` rather than copied here.
    private static func inspectorNotAppliedTag() throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appending(path: "FRUSExplorer/Search/QueryInspectorView.swift"),
                                encoding: .utf8)
        let key = try #require(source.range(of: "\"search.inspector.notAppliedTag\""))
        let rest = source[key.upperBound...]
        let open = try #require(rest.range(of: "defaultValue: \""))
        let close = try #require(rest[open.upperBound...].firstIndex(of: "\""))
        return String(rest[open.upperBound..<close])
    }

    // MARK: - Notes

    @Test("The notes: dates, a scope note per platform, and the Meaning-mode note, with no person note")
    func notesArePresentAndDistinct() {
        #expect(SearchTipNote.allCases == [.dates, .scopeIOS, .scopeMac, .meaningMode])
        for note in SearchTipNote.allCases {
            #expect(!note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(note)")
            #expect(!note.text.hasPrefix("search.tips."), "\(note) renders its key: \(note.text)")
        }
        #expect(Set(SearchTipNote.allCases.map(\.text)).count == SearchTipNote.allCases.count)
        #expect(SearchTipNote.scopeIOS.text != SearchTipNote.scopeMac.text)
        #expect(SearchTipNote.filterNotesIOS == [.dates, .scopeIOS])
        #expect(SearchTipNote.filterNotesMac == [.dates, .scopeMac])
    }
}

// MARK: - SearchQueryRefusalTests

/// The mapping both view models apply to a search failure (#1299): `FTS5Error.emptyQuery` becomes the refusal
/// message only when the query's own parse refused it, and a message naming Search Scope when the parse renders but
/// every content scope is off.
///
/// Version history:
///   1.0 — #1299: initial implementation
///   1.1 — #1299 follow-up: every scope off no longer passes through as "FTS5Error error 5" — it maps to a readable
///         message naming Filters ▸ Search Scope, and a refused parse stays a refusal whatever the scope
@Suite("A refused query maps to the refusal message, and nothing else does")
struct SearchQueryRefusalTests {

    @Test("A refused parse maps to the refusal")
    func refusedParseMaps() {
        for keywords in [SearchTip(id: .needsAWord).example, "NOT korea",
                         String(repeating: "(", count: 33) + "cold" + String(repeating: ")", count: 33)] {
            let mapped = SearchQueryRefusal.readable(FTS5Error.emptyQuery, for: SearchParameters(keywords: keywords))
            #expect((mapped as? SearchQueryRefusal) == .nothingToSearch, "\(keywords.prefix(40))")
        }
    }

    @Test("Every scope off maps to a message naming Search Scope, never to the refusal")
    func everyScopeOffNamesTheScope() {
        // Text that parses, with every content scope off: the other cause of emptyQuery.
        let scopeOff = SearchParameters(keywords: "cold", includeDocumentText: false,
                                        includeSummaries: false, includeNotes: false)
        let mapped = SearchQueryRefusal.readable(FTS5Error.emptyQuery, for: scopeOff)
        #expect((mapped as? SearchQueryRefusal) != .nothingToSearch, "a scope error was explained as a refused query")
        #expect(!(mapped is FTS5Error), "every scope off still reads \(mapped.localizedDescription)")
        #expect(mapped.localizedDescription.contains("Search Scope"),
                "every scope off does not name Search Scope: \(mapped.localizedDescription)")
        #expect(!mapped.localizedDescription.hasPrefix("search.error."), "the message renders its key")

        // A query the parse refuses is a refusal whatever the scope, because turning a scope on would not run it.
        let refusedScopeOff = SearchParameters(keywords: "-korea", includeDocumentText: false,
                                               includeSummaries: false, includeNotes: false)
        let refusal = SearchQueryRefusal.readable(FTS5Error.emptyQuery, for: refusedScopeOff)
        #expect((refusal as? SearchQueryRefusal) == .nothingToSearch)
    }

    @Test("Every other failure passes through unchanged")
    func otherFailuresPassThrough() {
        // emptyQuery for text that parses with a scope ON is no cause the service has; the mapping must not invent one.
        let scopeOn = SearchParameters(keywords: "cold")
        let passed = SearchQueryRefusal.readable(FTS5Error.emptyQuery, for: scopeOn)
        #expect((passed as? SearchQueryRefusal) == nil)
        if case FTS5Error.emptyQuery = passed {} else { Issue.record("emptyQuery was replaced by \(passed)") }

        let refused = SearchParameters(keywords: "-korea")
        let sqlite = SearchQueryRefusal.readable(FTS5Error.sqliteError(code: 1, message: "boom"), for: refused)
        if case FTS5Error.sqliteError(code: 1, message: "boom") = sqlite {} else { Issue.record("replaced \(sqlite)") }
        #expect(SearchQueryRefusal.readable(CancellationError(), for: refused) is CancellationError)
    }

    @Test("The message is readable and points at Search Tips")
    func messageIsReadable() throws {
        let message = try #require(SearchQueryRefusal.nothingToSearch.errorDescription)
        #expect(SearchQueryRefusal.nothingToSearch.localizedDescription == message)
        #expect(message.contains("Search Tips"))
        #expect(!message.contains("FTS5Error"))
        #expect(!message.hasPrefix("search.error."), "the message renders its key: \(message)")
    }

    @Test("iOS shows exactly the refusal message for the Search Tips row's own example")
    @MainActor
    func iOSShowsTheMessageForTheTipsExample() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FRUSRefusalTip-\(UUID().uuidString)", isDirectory: true)
        let volumes = dir.appendingPathComponent("volumes", isDirectory: true)
        try FileManager.default.createDirectory(at: volumes, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let dbURL = dir.appendingPathComponent("refusal.sqlite")
        let store = try FTS5Store(databaseURL: dbURL)
        let pipeline = try IndexingPipeline(fts5Store: store, databaseURL: dbURL,
                                            volumesDirectory: volumes, concurrencyLimit: 1)
        let vm = SearchViewModel(searchService: SearchService(fts5Store: store, pipeline: pipeline))

        vm.keywords = SearchTip(id: .needsAWord).example
        await vm.search()
        #expect(vm.searchError == SearchQueryRefusal.nothingToSearch.localizedDescription)
    }
}

// MARK: - CorpusAnalyticsSyntaxRowsTests

/// The three Corpus Analytics info rows #1299 re-keyed, pinned on the claims they were re-keyed to make (#1299
/// follow-up).
///
/// `EditableContentKeyTests` checks only that each row's KEY is live, and a mutation that kept `.v2` on the Phrases row
/// while restoring its pre-#1299 text passed every suite. So each row's detail is read from
/// `FeatureInfoButton.corpusAnalytics` itself, and each claim is checked against the parser beside the wording that
/// states it.
///
/// Version history:
///   1.0 — #1299 follow-up: initial implementation
@Suite("Corpus Analytics' syntax rows say what #1299 re-keyed them to say")
@MainActor
struct CorpusAnalyticsSyntaxRowsTests {

    /// The detail of the Corpus Analytics row titled `title` (its English default).
    private func detail(titled title: String) throws -> String {
        let items = FeatureInfoButton.corpusAnalytics.items
        return try #require(items.first { $0.title == title }?.detail,
                            "no Corpus Analytics row titled \(title): \(items.map(\.title))")
    }

    @Test("Phrases: straight or curly marks both make a phrase, which holds no marks of its own")
    func phraseRow() throws {
        let text = try detail(titled: "Phrases")
        #expect(text.contains("straight") && text.contains("curly"), "the row no longer names both kinds of mark")
        #expect(text.contains("cannot contain quotation marks of its own"), "the row no longer says a phrase holds none")
        #expect(FTS5InlineQueryParser.parseDetailed("\u{201C}missile crisis\u{201D}")
                == FTS5InlineQueryParser.parseDetailed("\"missile crisis\""))
        #expect(FTS5InlineQueryParser.parseDetailed("\"the \u{201C}missile crisis\u{201D} began\"").operands.count == 4)
    }

    @Test("Multiple words: only NOT excludes a NEAR(…), not a leading minus sign")
    func multiwordRow() throws {
        let text = try detail(titled: "Multiple words")
        #expect(text.contains("NEAR("), "the row no longer says a - does not exclude a NEAR(…)")
        let dash = FTS5InlineQueryParser.parseDetailed("cold -NEAR(war korea, 5)").expression ?? ""
        let not = FTS5InlineQueryParser.parseDetailed("cold NOT NEAR(war korea, 5)").expression ?? ""
        #expect(not.contains("NOT NEAR("), "precondition: NOT excludes a NEAR")
        #expect(!dash.contains("NOT NEAR("), "a leading - now excludes a NEAR, which the row says it does not")
    }

    @Test("How dates are determined: not the TEI <date> attribute the index no longer prefers")
    func datingRow() throws {
        let text = try detail(titled: "How dates are determined")
        #expect(!text.contains("TEI <date>"), "the row names the attribute #1299 removed: \(text)")
    }
}
