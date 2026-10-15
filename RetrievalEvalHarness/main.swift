// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import RetrievalEvalHarnessCore

/// Thin entry point — resolves the environment and calls `EvalRunner.run`.
///
/// Env:
///   QUERIES     the owner query file (default Planning/semantic-vectors/owner-eval-queries-2026-08-27.txt)
///   DB          the live index, opened READ-ONLY immutable (default the app container's frus.db)
///   INDEX_DIR   the bundled semantic artifacts (default FRUSExplorer/Resources)
///   SHARDS_DIR  the per-volume .vec shards (default Planning/semantic-vectors/shards)
///   LMS_URL     the embedding server's base, LM Studio or `llama-server` (default
///               http://localhost:1234; B2 ran `llama-server` at a0e6dc73 on 8089, since the
///               bundled artifacts are EmbeddingGemma 2's from B4)
///   MODEL       the served embedding model id (default embeddinggemma-2-Q8_0, `llama-server`'s
///               alias for the bundled artifacts' model; frus-eval/embeddinggemma-300m-qat until B4)
///   MODEL_FILE  the GGUF on disk, SHA-verified against the artifact's pin (default the Air's
///               copy of EmbeddingGemma 2; set empty to skip the file check — the id check remains)
///   OUT         report directory (default Planning/semantic-vectors/eval-2026-08-27)
let env = ProcessInfo.processInfo.environment
let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func url(_ key: String, default defaultPath: String) -> URL {
    URL(fileURLWithPath: env[key] ?? defaultPath, relativeTo: cwd).standardizedFileURL
}

let defaultDB = NSString(
    string: "~/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/frus.db"
).expandingTildeInPath
let defaultModelFile = NSString(
    string: "~/Development/models/embeddinggemma-2/embeddinggemma-2-Q8_0.gguf"
).expandingTildeInPath

let modelFileEnv = env["MODEL_FILE"] ?? defaultModelFile
do {
    try await EvalRunner.run(
        queriesURL: url("QUERIES", default: "Planning/semantic-vectors/owner-eval-queries-2026-08-27.txt"),
        databasePath: env["DB"] ?? defaultDB,
        indexDirectory: url("INDEX_DIR", default: "FRUSExplorer/Resources"),
        shardsDirectory: url("SHARDS_DIR", default: "Planning/semantic-vectors/shards"),
        client: LMStudioEmbeddingClient(
            baseURL: URL(string: env["LMS_URL"] ?? "http://localhost:1234")!,
            model: env["MODEL"] ?? "embeddinggemma-2-Q8_0"),
        modelFile: modelFileEnv.isEmpty ? nil : URL(fileURLWithPath: modelFileEnv),
        outDirectory: url("OUT", default: "Planning/semantic-vectors/eval-2026-08-27"),
        // CSQUERY_JSON: a CSUserQueryEvalRunner output to merge as the third route.
        csUserQueryJSON: env["CSQUERY_JSON"].map { URL(fileURLWithPath: $0, relativeTo: cwd) }
    )
} catch {
    FileHandle.standardError.write(Data("RetrievalEvalHarness failed: \(error)\n".utf8))
    exit(1)
}
