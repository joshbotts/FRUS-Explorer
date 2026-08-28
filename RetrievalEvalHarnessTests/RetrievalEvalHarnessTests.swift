// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Testing
import Foundation
@testable import RetrievalEvalHarnessCore

/// The harness's deterministic halves: query parsing and report assembly. The funnel's own
/// correctness is pinned where it lives — the kernel's external-query parity in
/// `SemanticVectorsKitTests`, the quantization fixtures in `SemanticVectorsGeneratorTests` —
/// so these tests never re-derive retrieval.
///
/// Version history:
///   1.0 — W-17 session 3: initial implementation
@Suite("Retrieval eval harness")
struct RetrievalEvalHarnessTests {

    @Test("Query parsing keeps quotes, splits tags on the three-space hash, numbers in order")
    func queryParsing() {
        let text = """
        # header comment
        How did it start?
        "trust but verify"
        blood telegram   # known-item by nickname (the documents never call it that)
        Space aliens   # null control
        """
        let queries = EvalRunner.parseQueries(text)
        #expect(queries.count == 4)
        #expect(queries[0] == .init(number: 1, text: "How did it start?", tag: nil))
        #expect(queries[1].text == "\"trust but verify\"",
                "the owner's quotes are part of the query and must reach the parser")
        #expect(queries[2].tag?.hasPrefix("known-item") == true)
        #expect(queries[3] == .init(number: 4, text: "Space aliens", tag: "null control"))
    }

    @Test("The report carries both routes, the executed expression, and a blank verdict column")
    func reportShape() {
        var builder = ReportBuilder(queryCount: 1, model: "m", pinnedSHA: "abc123")
        let lexical = [EvalResult(volumeId: "frus1948v03", documentId: "d1", score: -4.2)]
        let semantic = [EvalResult(volumeId: "frus1950v01", documentId: "d9", score: 0.61)]
        builder.add(
            query: .init(number: 1, text: "test query", tag: nil),
            lexicalExpression: "\"test\" AND \"query\"",
            lexical: lexical,
            semanticByVariant: ["query": semantic, "document": semantic, "bare": []],
            display: { _, _ in ("A header, with a comma", "Washington, May 1", "snippet text") })
        let markdown = builder.markdown
        #expect(markdown.contains("`\"test\" AND \"query\"`"),
                "the report must show what actually executed, not the raw input")
        #expect(markdown.contains("frus1948v03/d1") && markdown.contains("frus1950v01/d9"))
        #expect(markdown.contains("bare: 0/1"), "variant disagreement must be visible")

        let csv = builder.verdictsCSV
        let lines = csv.split(separator: "\n")
        #expect(lines.first == "query,route,rank,volume,document,header,relevant")
        #expect(lines.dropFirst().allSatisfy { $0.hasSuffix(",") },
                "the relevant column is blank on purpose — the owner's eye fills it")
        #expect(csv.contains("\"A header, with a comma\""),
                "a comma inside a header must not break the CSV")
    }

    // MARK: - Prose-first snippets

    /// Both corpus layouts, verbatim shapes from the first report: the modern order
    /// (header → Source: … → prose) and the wartime telegram order (file citation →
    /// header → dateline → serial → prose).
    @Test("The modern layout strips header and source note, leaving prose")
    func modernLayoutStripsToProse() {
        let snippet = EvalSnippet.prose(
            header: "12. Memorandum of Conversation",
            dateline: "Beijing , February 17–18, 1973, 11:30 p.m.–1:20 a.m.",
            sourceNote: "Source: National Archives, Nixon Presidential Materials, NSC Files, Box 98. Top Secret; Sensitive.",
            body: """
            12. Memorandum of Conversation Source: National Archives, Nixon Presidential \
            Materials, NSC Files, Box 98. Top Secret; Sensitive. Chairman Mao: I have heard \
            that your President said the two countries should walk together.
            """)
        #expect(snippet.hasPrefix("Chairman Mao: I have heard"),
                "the judge should read prose, not the row's own header and citation again")
    }

    @Test("The wartime telegram layout strips citation, header, dateline, received bracket and serial")
    func telegramLayoutStripsChrome() {
        let snippet = EvalSnippet.prose(
            header: "The Secretary of State to the Ambassador in China ( Gauss )",
            dateline: "Washington , December 18, 1943 .",
            sourceNote: "151.10/2003a: Telegram",
            body: """
            151.10/2003a: Telegram The Secretary of State to the Ambassador in China ( Gauss ) \
            Washington , December 18, 1943 . [Received December 19—1:57 p.m.] 1819. On December \
            17, 1943 the President approved an Act of Congress repealing the exclusion laws.
            """)
        #expect(snippet.hasPrefix("On December 17, 1943"),
                "citation-first layouts must strip in any order, not just header-first")
    }

    @Test("A document that is all boilerplate falls back to the plain prefix, never empty")
    func allBoilerplateFallsBack() {
        let snippet = EvalSnippet.prose(
            header: "1. Editorial Note",
            dateline: nil,
            sourceNote: nil,
            body: "1. Editorial Note")
        #expect(!snippet.isEmpty)
        #expect(snippet.contains("Editorial Note"))
    }

    @Test("Truncation lands on a word boundary with an ellipsis")
    func wordBoundaryTruncation() {
        let long = Array(repeating: "word", count: 200).joined(separator: " ")
        let snippet = EvalSnippet.truncateAtWord(long, limit: 50)
        #expect(snippet.hasSuffix("…"))
        #expect(!snippet.dropLast().hasSuffix("wor"), "no mid-word cuts")
        #expect(snippet.count <= 52)
    }

    @Test("A long bracketed passage is prose, not chrome, and survives")
    func longBracketGroupSurvives() {
        let bracketed = "[" + Array(repeating: "substantive", count: 12).joined(separator: " ") + " text]"
        let snippet = EvalSnippet.prose(
            header: "h", dateline: nil, sourceNote: nil,
            body: "h " + bracketed + " and more follows")
        #expect(snippet.hasPrefix("["),
                "only short [Received …]-style groups are chrome; bracketed prose must remain")
    }

    // MARK: - The third route and the sitting's protection

    @Test("A filled verdicts file is recognized and protected; a blank one is not")
    func filledVerdictsAreProtected() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("verdicts-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("verdicts.csv")

        #expect(!EvalRunner.hasFilledVerdicts(at: url), "a missing file is not a sitting")
        try "query,route,rank,volume,document,header,relevant\n1,lexical,1,v,d,h,\n"
            .write(to: url, atomically: true, encoding: .utf8)
        #expect(!EvalRunner.hasFilledVerdicts(at: url), "blank rows are not a sitting")
        try "query,route,rank,volume,document,header,relevant\n1,lexical,1,v,d,h,1\n"
            .write(to: url, atomically: true, encoding: .utf8)
        #expect(EvalRunner.hasFilledVerdicts(at: url),
                "one judged row makes it the owner's record — a regeneration must never blank it")
        // The owner's editor saves CRLF. The first guard checked hasSuffix(",1") against
        // lines ending ",1\r", declared the sitting blank, and overwrote it — this case is
        // the regression pin for that live failure.
        try "query,route,rank,volume,document,header,relevant\r\n1,lexical,1,v,d,h,1\r\n"
            .write(to: url, atomically: true, encoding: .utf8)
        #expect(EvalRunner.hasFilledVerdicts(at: url),
                "a CRLF sitting is still a sitting — this exact miss clobbered the real one once")
    }

    @Test("A CSUserQuery output file parses into per-query rows with its provenance line")
    func csUserQueryRouteLoads() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("csq-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("csuserquery.json")
        try """
        {"route":"csuserquery","generated":"2026-08-28T11:33:44Z","osVersion":"26.6.2",
         "spotlightSchemaVersion":2,"topK":10,"queries":[
           {"query":1,"text":"q1","results":[
             {"rank":1,"volume":"frus1895p1","document":"d527","title":"Olney"}]},
           {"query":2,"text":"q2","results":[]}]}
        """.write(to: url, atomically: true, encoding: .utf8)
        let route = try EvalRunner.loadCSUserQueryRoute(url)
        #expect(route.rows[1] == [EvalResult(volumeId: "frus1895p1", documentId: "d527", score: -1)])
        #expect(route.rows[2] == [])
        #expect(route.provenance.contains("26.6.2") && route.provenance.contains("schema v2"),
                "ranking quality is a property of the OS's models; the report must say which")
    }

    @Test("The merged third route renders its own section under the query")
    func thirdRouteRenders() {
        var builder = ReportBuilder(queryCount: 1, model: "m", pinnedSHA: "abc",
                                    csUserQueryProvenance: "26.6.2, donated schema v2")
        builder.add(
            query: .init(number: 1, text: "q", tag: nil),
            lexicalExpression: "\"q\"",
            lexical: [],
            semanticByVariant: [:],
            csUserQuery: [EvalResult(volumeId: "v", documentId: "d", score: -1)],
            display: { _, _ in ("Header", nil, "snippet") })
        #expect(builder.markdown.contains("### CSUserQuery — Apple's local ranked search (26.6.2, donated schema v2)"))
        #expect(builder.verdictsCSV.contains("1,csuserquery,1,v,d,"))
    }

    @Test("An empty route section says so instead of vanishing")
    func emptyRouteIsStated() {
        var builder = ReportBuilder(queryCount: 1, model: "m", pinnedSHA: "abc123")
        builder.add(
            query: .init(number: 1, text: "q", tag: nil),
            lexicalExpression: nil,
            lexical: [],
            semanticByVariant: [:],
            display: { _, _ in nil })
        #expect(builder.markdown.contains("(no searchable expression)"))
        #expect(builder.markdown.contains("*(no results)*"))
    }
}
