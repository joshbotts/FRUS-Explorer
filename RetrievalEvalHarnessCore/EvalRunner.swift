// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SemanticVectorsKit

/// The W-17 session 3 / V-5 §6 shared evaluation runner.
///
/// ## What it runs
/// Every owner-written query goes through **two routes over the same corpus**:
/// - the **lexical** route — the app's own search-box path: `FTS5InlineQueryParser`'s
///   rendered MATCH expression, BM25 order, against the live index read-only;
/// - the **semantic** route — the query embedded by the SHA-pinned GGUF (verified against
///   `provenance.modelFileSHA256` before the first request), truncated / quantized / packed by
///   the generator's own `SemanticQuantization`, entering the exact shipped funnel through the
///   kernel's parity-pinned external-query overload, reranked against the shards.
///
/// The semantic route runs each query under **three prompt variants** (the model's retrieval
/// query template, the corpus's document template, bare) because the V-5 assessment's prompt
/// question is unsettled; the report ranks by the query template and discloses the variants'
/// agreement so the sitting doubles as that measurement.
///
/// ## What it deliberately does not do
/// It does not score. The owner-written half of the instrument is judged by eye — that is the
/// half no proxy supplies — so the output is a judging report plus a verdicts CSV whose
/// `relevant` column is blank on purpose. `CSUserQuery` (W-9 step 1) is absent because it is
/// not built; the harness gains a third route when it is.
///
/// Version history:
///   1.0 — W-17 session 3: initial implementation
public enum EvalRunner {

    /// One parsed query.
    public struct Query: Sendable, Equatable {
        /// 1-based position in the owner's list.
        public let number: Int
        /// The query text, verbatim.
        public let text: String
        /// The harness annotation (`known-item`, `null control`, …) when the line carried one.
        public let tag: String?

        /// Creates a query.
        public init(number: Int, text: String, tag: String?) {
            self.number = number
            self.text = text
            self.tag = tag
        }
    }

    /// The three prompt variants, in report order. The first is primary — and since the sitting
    /// settled the question its string is the shared `SemanticQueryPrompt.queryPrefix`, the same
    /// definition the in-app encoder embeds under, so this harness always measures the template
    /// the app ships rather than a copy that could drift.
    public static let promptVariants: [(name: String, prefix: String)] = [
        ("query", SemanticQueryPrompt.queryPrefix),
        ("document", "title: none | text: "),
        ("bare", ""),
    ]

    /// Parses the owner's query file: one query per line, `#`-led lines skipped, a trailing
    /// `   # note` (three-space gap) split off as the tag so a `#` inside a query survives.
    public static func parseQueries(_ text: String) -> [Query] {
        var queries: [Query] = []
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(rawLine)
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("#") { continue }
            let parts = line.components(separatedBy: "   #")
            let body = parts[0].trimmingCharacters(in: .whitespaces)
            guard !body.isEmpty else { continue }
            let tag = parts.count > 1
                ? parts[1].trimmingCharacters(in: .whitespaces)
                : nil
            queries.append(Query(number: queries.count + 1, text: body, tag: tag))
        }
        return queries
    }

    /// Runs the evaluation and writes the report artifacts into `outDirectory`.
    ///
    /// - Parameter csUserQueryJSON: An optional `CSUserQueryEvalRunner` output file, merged
    ///   into the report as a third route. Its rows come from the app's own Spotlight run,
    ///   so this harness only formats them — it never re-executes that route.
    public static func run(
        queriesURL: URL,
        databasePath: String,
        indexDirectory: URL,
        shardsDirectory: URL,
        client: LMStudioEmbeddingClient,
        modelFile: URL?,
        outDirectory: URL,
        csUserQueryJSON: URL? = nil,
        topK: Int = 10
    ) async throws {
        let queries = parseQueries(try String(contentsOf: queriesURL, encoding: .utf8))
        guard !queries.isEmpty else { throw EvalError("no queries parsed from \(queriesURL.path)") }

        let lexical = try LexicalEvalRoute(databasePath: databasePath)
        let semantic = try SemanticEvalRoute(
            indexDirectory: indexDirectory, shardsDirectory: shardsDirectory)
        try await client.verify(modelFile: modelFile, pinnedSHA256: semantic.pinnedModelSHA256)
        let csRoute = try csUserQueryJSON.map(loadCSUserQueryRoute)

        var report = ReportBuilder(queryCount: queries.count, model: client.model,
                                   pinnedSHA: semantic.pinnedModelSHA256,
                                   csUserQueryProvenance: csRoute?.provenance)

        for query in queries {
            FileHandle.standardError.write(Data("[eval] #\(query.number) \(query.text)\n".utf8))
            let (expression, lexicalRows) = try lexical.search(query.text, limit: topK)

            var variantRows: [String: [EvalResult]] = [:]
            for variant in promptVariants {
                let embedding = try await client.embed(variant.prefix + query.text)
                variantRows[variant.name] = try semantic.search(embedding: embedding, limit: topK)
            }

            // PRF (V-5 §4): the centroid of the lexical TOP-5 — the measured-best k — through
            // the same funnel. The seeds are the ranking's own head, so no second query runs.
            let seeds = Array(lexicalRows.prefix(5))
            let prfRows = try semantic.prfSearch(seeds: seeds, limit: topK)

            report.add(query: query,
                       lexicalExpression: expression,
                       lexical: lexicalRows,
                       semanticByVariant: variantRows,
                       csUserQuery: csRoute?.rows[query.number],
                       prf: prfRows, prfSeedCount: seeds.count,
                       display: { lexical.display(volumeId: $0, documentId: $1) })
        }

        try FileManager.default.createDirectory(at: outDirectory, withIntermediateDirectories: true)
        try report.markdown.write(to: outDirectory.appendingPathComponent("report.md"),
                                  atomically: true, encoding: .utf8)
        // The verdicts file is the OWNER'S RECORD once judged: a regeneration (new snippet
        // style, a third route merged) must never blank a filled sitting. Written only when
        // absent or still blank; otherwise the sitting stands and the skip is logged.
        let verdictsURL = outDirectory.appendingPathComponent("verdicts.csv")
        if hasFilledVerdicts(at: verdictsURL) {
            FileHandle.standardError.write(Data(
                "[eval] verdicts.csv carries judged rows — left untouched\n".utf8))
        } else {
            try report.verdictsCSV.write(to: verdictsURL, atomically: true, encoding: .utf8)
        }
        try report.statsJSON.write(to: outDirectory.appendingPathComponent("stats.json"),
                                   atomically: true, encoding: .utf8)
        FileHandle.standardError.write(Data("[eval] wrote \(outDirectory.path)\n".utf8))
    }

    /// Whether an existing verdicts file carries at least one judged row.
    ///
    /// Lines are trimmed before the suffix test because a judged sitting comes back from
    /// the OWNER'S editor, and editors save CRLF: the first version of this guard checked
    /// `hasSuffix(",1")` against lines ending `,1\r`, declared the sitting blank, and
    /// overwrote it — the same bare-`\r` failure the merge-audit CSV reader documented,
    /// striking from the other direction. (The sitting was recoverable from git; the
    /// lesson is permanent.)
    static func hasFilledVerdicts(at url: URL) -> Bool {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return false }
        return text.split(whereSeparator: \.isNewline).dropFirst().contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasSuffix(",1") || trimmed.hasSuffix(",0")
        }
    }

    /// A parsed `CSUserQueryEvalRunner` output: per-query-number rows plus the provenance
    /// line the report prints (OS build and donated schema version — ranking quality is a
    /// property of the OS's models, and the report must say which).
    static func loadCSUserQueryRoute(_ url: URL)
        throws -> (rows: [Int: [EvalResult]], provenance: String) {
        struct File: Decodable {
            struct Query: Decodable {
                struct Row: Decodable {
                    let rank: Int?
                    let volume: String?
                    let document: String?
                }
                let query: Int
                let results: [Row]
            }
            let osVersion: String
            let spotlightSchemaVersion: Int
            let generated: String
            let queries: [Query]
        }
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
        var rows: [Int: [EvalResult]] = [:]
        for query in file.queries {
            rows[query.query] = query.results.compactMap { row in
                guard let volume = row.volume, let document = row.document else { return nil }
                // CSUserQuery exposes no comparable score; rank is the only ordering it
                // states, carried as a negative so "higher is better" never misreads.
                return EvalResult(volumeId: volume, documentId: document,
                                  score: -Double(row.rank ?? 0))
            }
        }
        return (rows, "\(file.osVersion), donated schema v\(file.spotlightSchemaVersion), run \(file.generated)")
    }
}

// MARK: - ReportBuilder

/// Assembles the three artifacts. Kept as plain string building so the report is diffable and
/// the harness has no templating dependency.
public struct ReportBuilder {

    private var sections: [String] = []
    private var csvRows: [String] = ["query,route,rank,volume,document,header,relevant"]
    private var stats: [[String: Any]] = []
    private let header: String
    private let csUserQueryProvenance: String?

    /// Creates a builder.
    public init(queryCount: Int, model: String, pinnedSHA: String,
                csUserQueryProvenance: String? = nil) {
        self.csUserQueryProvenance = csUserQueryProvenance
        header = """
        # Retrieval evaluation — the owner-query sitting (W-17 session 3 / W-9 step 2)

        Two routes over the same corpus, \(queryCount) owner-written queries, top 10 each.
        **Lexical** is the app's own search (the rendered MATCH expression is shown — what
        actually executed). **Semantic** is the shipped funnel (Hamming → int8 rerank) with the
        query embedded by the SHA-pinned GGUF (`\(model)`, `\(pinnedSHA.prefix(12))…`), primary
        prompt = the model's retrieval query template; the two other prompt variants appear as
        id lists with overlap counts, so this sitting also settles the prompt question.
        `CSUserQuery` (W-9 step 1) is not built yet and joins this report when it is.

        **How to judge — one test for every row:** *would you open this document while pursuing
        this question?* Mark `relevant` in `verdicts.csv` as **1** (yes — it advances the
        question, is the item itself, or is proximity you would genuinely follow: an April 1971
        Dacca telegram IS a 1 for "blood telegram"), **0** (you can already tell it would waste
        your time — including the confidently wrong), or **blank** (the row's evidence
        underdetermines it; blank describes the report, not the document, and is excluded from
        the denominator rather than counted against either route). Don't reserve 1 for a
        known item — near-misses score by the same test, and the did-it-find-the-thing hit is
        computed separately from the known documents' identities. The null control
        ("Space aliens") has no 1 to give; what matters there is which route's junk would have
        fooled a rushed reader. Try not to look at the score column while judging.

        Snippets are **prose-first**: the body's opening echo of the header, source note,
        dateline, and despatch serial is stripped, so the quoted text is evidence the row has
        not already shown you.

        """
    }

    /// Adds one query's section.
    public mutating func add(
        query: EvalRunner.Query,
        lexicalExpression: String?,
        lexical: [EvalResult],
        semanticByVariant: [String: [EvalResult]],
        csUserQuery: [EvalResult]? = nil,
        prf: [EvalResult]? = nil,
        prfSeedCount: Int? = nil,
        display: (String, String) -> (header: String, dateline: String?, snippet: String)?
    ) {
        let primary = semanticByVariant["query"] ?? []
        var section = "\n---\n\n## Q\(query.number). \(query.text)\n"
        if let tag = query.tag { section += "*\(tag)*\n" }
        section += "\n### Lexical — `\(lexicalExpression ?? "(no searchable expression)")`\n\n"
        section += rows(lexical, route: "lexical", query: query, display: display)
        section += "\n### Semantic (query prompt)\n\n"
        section += rows(primary, route: "semantic", query: query, display: display)
        if let csUserQuery {
            section += "\n### CSUserQuery — Apple's local ranked search"
            if let csUserQueryProvenance { section += " (\(csUserQueryProvenance))" }
            section += "\n\n"
            section += rows(csUserQuery, route: "csuserquery", query: query, display: display)
        }
        if let prf {
            section += "\n### PRF — centroid of the lexical top-5, no encoder"
            if let prfSeedCount { section += " (\(prfSeedCount) seed\(prfSeedCount == 1 ? "" : "s"))" }
            section += "\n\n"
            if prf.isEmpty, (prfSeedCount ?? 0) == 0 {
                section += "*(no seeds — PRF amplifies lexical search and cannot rescue a query it returned nothing for)*\n"
            } else {
                section += rows(prf, route: "prf", query: query, display: display)
            }
        }

        let lexicalSet = Set(lexical.map(\.key))
        let primarySet = Set(primary.map(\.key))
        let documentVariant = Set((semanticByVariant["document"] ?? []).map(\.key))
        let bareVariant = Set((semanticByVariant["bare"] ?? []).map(\.key))
        section += """

        *Route overlap: \(lexicalSet.intersection(primarySet).count) of \(max(lexicalSet.count, primarySet.count)) shared. \
        Prompt variants vs primary — document: \(primarySet.intersection(documentVariant).count)/\(primarySet.count), \
        bare: \(primarySet.intersection(bareVariant).count)/\(primarySet.count).*

        """
        for name in ["document", "bare"] {
            let ids = (semanticByVariant[name] ?? []).map(\.key).joined(separator: ", ")
            section += "*\(name) variant:* \(ids.isEmpty ? "—" : ids)\n"
        }
        sections.append(section)

        let prfSet = Set((prf ?? []).map(\.key))
        stats.append([
            "query": query.number,
            "text": query.text,
            "tag": query.tag ?? "",
            "lexicalCount": lexical.count,
            "semanticCount": primary.count,
            "routeOverlap": lexicalSet.intersection(primarySet).count,
            "variantOverlapDocument": primarySet.intersection(documentVariant).count,
            "variantOverlapBare": primarySet.intersection(bareVariant).count,
            "prfCount": prfSet.count,
            "prfSeeds": prfSeedCount ?? 0,
            // How much of the encoder-grade list PRF recovers — the real-instrument
            // analogue of §4's "closes X% of the gap".
            "prfOverlapSemantic": prfSet.intersection(primarySet).count,
        ])
    }

    private mutating func rows(
        _ results: [EvalResult], route: String, query: EvalRunner.Query,
        display: (String, String) -> (header: String, dateline: String?, snippet: String)?
    ) -> String {
        guard !results.isEmpty else { return "*(no results)*\n" }
        var out = ""
        for (rank, result) in results.enumerated() {
            let fields = display(result.volumeId, result.documentId)
            let title = fields?.header ?? result.documentId
            let dateline = fields?.dateline.map { " — \($0)" } ?? ""
            let snippet = fields?.snippet ?? ""
            out += "\(rank + 1). **\(title)**\(dateline)  \n"
            out += "   `\(result.key)` · score \(String(format: "%.4f", result.score))  \n"
            // The snippet carries its own ellipsis when it was cut; appending another here
            // produced "……" on every truncated row of the first prose-first run.
            if !snippet.isEmpty { out += "   > \(snippet)\n" }
            csvRows.append([
                String(query.number), route, String(rank + 1),
                result.volumeId, result.documentId,
                "\"" + title.replacingOccurrences(of: "\"", with: "\"\"") + "\"", "",
            ].joined(separator: ","))
        }
        return out
    }

    /// The assembled Markdown report.
    public var markdown: String { header + sections.joined() }
    /// The verdict-recording CSV, `relevant` blank on purpose.
    public var verdictsCSV: String { csvRows.joined(separator: "\n") + "\n" }
    /// Machine-readable per-query stats.
    public var statsJSON: String {
        let object: [String: Any] = ["queries": stats]
        let data = (try? JSONSerialization.data(
            withJSONObject: object, options: [.prettyPrinted, .sortedKeys])) ?? Data()
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
