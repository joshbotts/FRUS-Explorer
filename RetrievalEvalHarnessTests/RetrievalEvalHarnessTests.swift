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
///   1.1 — A10b: the prose-first snippet's tests moved with `ProseSnippet` into FRUSCoreKit
///         (`ProseSnippetTests`), whose strip the harness now takes
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

    @Test("The PRF section states the seed count, and zero seeds states the structural reason")
    func prfSectionShape() {
        var builder = ReportBuilder(queryCount: 2, model: "m", pinnedSHA: "abc")
        builder.add(
            query: .init(number: 1, text: "seeded", tag: nil),
            lexicalExpression: "\"seeded\"",
            lexical: [EvalResult(volumeId: "v", documentId: "d1", score: -4)],
            semanticByVariant: [:],
            prf: [EvalResult(volumeId: "v", documentId: "d2", score: 0.7)],
            prfSeedCount: 1,
            display: { _, _ in ("H", nil, "s") })
        builder.add(
            query: .init(number: 2, text: "unseeded", tag: nil),
            lexicalExpression: nil,
            lexical: [],
            semanticByVariant: [:],
            prf: [], prfSeedCount: 0,
            display: { _, _ in nil })
        let markdown = builder.markdown
        #expect(markdown.contains("### PRF — centroid of the lexical top-5, no encoder (1 seed)"))
        #expect(markdown.contains("no seeds — PRF amplifies lexical search"),
                "the zero-seed case is §4's structural limit and the report must say so, not show an unexplained blank")
        #expect(builder.verdictsCSV.contains("1,prf,1,v,d2,"))
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
