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
/// Wording is pinned only where it states something checkable: a number (NEAR's distances), a piece of syntax (the
/// prefixes, `NOT NEAR(`), a word form the row says matches or does not, or the Query Inspector's tag. The rest of the
/// prose is the owner's to edit through `Docs/EditableContent.md`.
///
/// Version history:
///   1.0 — #1299: initial implementation
@Suite("Search Tips say what the query actually does")
struct SearchTipsTests {

    private func p(_ query: String) -> ParsedQuery { FTS5InlineQueryParser.parseDetailed(query) }

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
            #expect(tip.example.allSatisfy(\.isASCII), "\(tip.id)'s example is not typeable as shown: \(tip.example)")
            #expect(tip.example == tip.example.trimmingCharacters(in: .whitespacesAndNewlines), "\(tip.id)")
            #expect(!tip.spokenExample.isEmpty, "\(tip.id)")
            #expect(!tip.detail.isEmpty, "\(tip.id)")
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
        #expect(words.count == 2)
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
        #expect(try count(tip.example, over: ["the \(inner) began"]) == 1, "in order")
        #expect(try count(tip.example, over: ["\(words[1]) turned \(words[0])"]) == 0, "not out of order")
    }

    /// `rusk OR bundy`: either word, OR in any case, and OR divides everything before it from everything after it.
    private func checkEither(_ tip: SearchTip) throws {
        let parts = tip.example.components(separatedBy: " OR ")
        #expect(parts.count == 2)
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

    /// `negoti*`: a prefix is matched against stems, so the short prefix the detail names finds the forms and the
    /// longer one it names finds nothing — although the rows contain words spelled with its letters.
    private func checkPrefix(_ tip: SearchTip) throws {
        let stem = String(tip.example.dropLast())
        #expect(tip.example.hasSuffix("*"))
        #expect(p(tip.example).expression == "\"\(stem)\"*")
        #expect(p(tip.example).operands.map(\.kind) == [.prefix])

        let prefixes = tip.detail.split(separator: " ")
            .map { $0.trimmingCharacters(in: CharacterSet.punctuationCharacters.subtracting(CharacterSet(charactersIn: "*"))) }
            .filter { $0.hasSuffix("*") }
        #expect(prefixes.count == 2, "the detail should name the example and a prefix too long to match: \(prefixes)")
        #expect(prefixes.first == tip.example, "the detail's working prefix is not the example")
        let rows = ["Negotiations with the Soviets resumed", "A negotiated settlement was reached"]
        #expect(try count(tip.example, over: rows) == rows.count)
        guard prefixes.count == 2 else { return }
        let tooLong = prefixes[1]
        let letters = String(tooLong.dropLast()).lowercased()
        #expect(letters.count > stem.count && letters.hasPrefix(stem), "\(tooLong) is not a longer form of \(tip.example)")
        #expect(rows.contains { $0.lowercased().split(separator: " ").contains { $0.hasPrefix(letters) } },
                "precondition: the rows contain words spelled with \(tooLong)'s letters")
        #expect(try count(tooLong, over: rows) == 0, "\(tooLong) should find nothing, because it is longer than the stem")
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
        #expect(tip.detail.contains(distance), "the detail does not state the example's distance, \(distance)")
        #expect(tip.detail.contains(defaultDistance), "the detail does not state the default distance, \(defaultDistance)")

        #expect(p(tip.example.replacingOccurrences(of: "NEAR", with: "near")).expression == explicit.expression)
        #expect(p("NEAR(\u{201C}military guarantee\u{201D} europe, 30)").expression
                == "NEAR(\"military guarantee\" \"europe\", 30)", "a phrase may go inside")
        #expect(p("NEAR(milit* europ*, 20)").operands.map(\.kind) == [.proximity], "a prefix may go inside")
        for inside in ["NEAR(military OR europe, 5)", "NEAR(military NOT europe, 5)", "NEAR((military europe), 5)"] {
            #expect(p(inside).operands.allSatisfy { $0.kind != .proximity }, "\(inside) is not a proximity search")
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

    /// `=containment`: the literal word only, and the `=` ignored where a match need not contain it and on a prefix.
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
        for form in forms { #expect(tip.detail.contains(form), "the detail no longer names \(form), which this checks") }
        let rows = ["the \(word) policy of Kennan", "we \(forms[0]) the threat", "\(forms[1]) Soviet expansion"]
        #expect(try count(word, over: rows) == 3, "stemmed, the word finds its other forms")
        #expect(try count(tip.example, over: rows) == 1, "marked, it finds only itself")
    }

    /// `-korea`: a query of exclusions alone is refused; an exclusion-only alternative is left out, and the detail
    /// names the tag the Query Inspector marks it with.
    private func checkNeedsAWord(_ tip: SearchTip) throws {
        for query in [tip.example, "NOT korea", "-korea -vietnam", "-(korea OR vietnam)", "-korea OR -vietnam"] {
            #expect(p(query) == ParsedQuery(expression: nil, exactTerms: []), "\(query) should not run")
        }
        let partial = p("cold OR " + tip.example)
        #expect(partial.expression == "\"cold\"")
        #expect(partial.droppedOperands.map(\.text) == ["korea"])
        #expect(partial.droppedOperands.first?.isNegated == true)
        #expect(partial.isApproximate)

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
        }
        #expect(Set(SearchTipNote.allCases.map(\.text)).count == SearchTipNote.allCases.count)
        #expect(SearchTipNote.scopeIOS.text != SearchTipNote.scopeMac.text)
        #expect(SearchTipNote.filterNotesIOS == [.dates, .scopeIOS])
        #expect(SearchTipNote.filterNotesMac == [.dates, .scopeMac])
    }
}

// MARK: - SearchQueryRefusalTests

/// The mapping both view models apply to a search failure (#1299): `FTS5Error.emptyQuery` becomes the refusal
/// message only when the query's own parse refused it.
///
/// Version history:
///   1.0 — #1299: initial implementation
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

    @Test("Every other failure passes through unchanged")
    func otherFailuresPassThrough() {
        // Text that parses, with every content scope off: the other cause of emptyQuery.
        let scopeOff = SearchParameters(keywords: "cold", includeDocumentText: false,
                                        includeSummaries: false, includeNotes: false)
        let passed = SearchQueryRefusal.readable(FTS5Error.emptyQuery, for: scopeOff)
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
