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
