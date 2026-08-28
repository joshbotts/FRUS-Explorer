// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

#if DEBUG
import Foundation
import CoreSpotlight

/// The W-9 step 1 evaluation seam: runs the owner's query set through `CSUserQuery` —
/// Apple's local, ranked, per-app semantic search over the app's own Spotlight donations —
/// and writes results the retrieval-evaluation harness can merge as a third route.
///
/// ## Why a launch-environment seam inside the app
/// `CSUserQuery` searches the *app's* Spotlight index, which only exists where the app has
/// donated — there is no CLI route to it (a bare SPM process has no Spotlight client
/// identity). So the runner rides the app, the `UITestVolumeSeeder` pattern: DEBUG-only,
/// inert unless `FRUS_CSQUERY_EVAL` names a query file, and it never touches the release
/// build.
///
/// ## The two-launch protocol
/// Donation and querying are separate launches on purpose. Spotlight's semantic indexing of
/// donated `textContent` happens in the SYSTEM's own time after submission returns — so
/// launch once to donate (the v2 schema rebuild runs at boot), give the system time to
/// digest, then launch with this seam armed to query. Results from a same-launch query
/// would measure a half-digested index and call it Apple's answer.
///
/// ## Env
///   FRUS_CSQUERY_EVAL      the query file (owner-eval-queries format; arms the seam)
///   FRUS_CSQUERY_EVAL_OUT  output JSON path (default: Documents/csuserquery-eval.json)
///   FRUS_CSQUERY_TOP       results per query (default 10)
enum CSUserQueryEvalRunner {

    /// Runs when armed. Call after boot; runs detached so app startup is unaffected.
    static func runIfRequested() {
        let env = ProcessInfo.processInfo.environment
        guard let queriesPath = env["FRUS_CSQUERY_EVAL"] else { return }
        let outPath = env["FRUS_CSQUERY_EVAL_OUT"]
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("csuserquery-eval.json").path
        let topK = env["FRUS_CSQUERY_TOP"].flatMap(Int.init) ?? 10

        Task.detached(priority: .utility) {
            do {
                let output = try await run(queriesPath: queriesPath, topK: topK)
                let data = try JSONSerialization.data(
                    withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: URL(fileURLWithPath: outPath))
                print("[CSUserQueryEvalRunner] wrote \(outPath)")
            } catch {
                print("[CSUserQueryEvalRunner] FAILED: \(error)")
            }
        }
    }

    /// Executes the queries and assembles the output object.
    private static func run(queriesPath: String, topK: Int) async throws -> [String: Any] {
        let text = try String(contentsOfFile: queriesPath, encoding: .utf8)
        // The harness's parsing rules: #-led lines skipped, a three-space `   #` splits a tag.
        var queries: [(number: Int, text: String)] = []
        for line in text.split(separator: "\n") {
            let raw = String(line)
            if raw.trimmingCharacters(in: .whitespaces).hasPrefix("#") { continue }
            let body = raw.components(separatedBy: "   #")[0]
                .trimmingCharacters(in: .whitespaces)
            guard !body.isEmpty else { continue }
            queries.append((queries.count + 1, body))
        }

        // Warm the ranking models once, as Apple asks, before the first query.
        CSUserQuery.prepare()

        var perQuery: [[String: Any]] = []
        for query in queries {
            let context = CSUserQueryContext()
            context.fetchAttributes = ["title"]
            context.enableRankedResults = true
            context.maxResultCount = topK
            context.maxRankedResultCount = topK
            let userQuery = CSUserQuery(userQueryString: query.text, userQueryContext: context)

            var rows: [[String: Any]] = []
            do {
                for try await response in userQuery.responses {
                    guard case .item(let found) = response else { continue }
                    let identifier = found.item.uniqueIdentifier
                    // Donated ids are "volumeId/documentId"; anything else is not ours.
                    let parts = identifier.split(separator: "/", maxSplits: 1).map(String.init)
                    guard parts.count == 2 else { continue }
                    rows.append([
                        "rank": rows.count + 1,
                        "volume": parts[0],
                        "document": parts[1],
                        "title": found.item.attributeSet.title ?? "",
                    ])
                    if rows.count >= topK { break }
                }
            } catch {
                rows.append(["error": String(describing: error)])
            }
            perQuery.append(["query": query.number, "text": query.text, "results": rows])
            print("[CSUserQueryEvalRunner] #\(query.number) \(query.text) → \(rows.count) rows")
        }

        return [
            "route": "csuserquery",
            "generated": ISO8601DateFormatter().string(from: Date()),
            // The context of the measurement, without which the numbers mean nothing:
            // which donated shape was live, and on what OS build (ranking quality is a
            // property of the OS's models, not of this app).
            "spotlightSchemaVersion": UserDefaults.standard.integer(
                forKey: IndexingPipeline.spotlightSchemaVersionKey),
            "osVersion": ProcessInfo.processInfo.operatingSystemVersionString,
            "topK": topK,
            "queries": perQuery,
        ]
    }
}
#endif
