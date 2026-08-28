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
///   LMS_URL     LM Studio base (default http://localhost:1234)
///   MODEL       the served embedding model id (default frus-eval/embeddinggemma-300m-qat)
///   MODEL_FILE  the GGUF on disk, SHA-verified against the artifact's pin (default the
///               LM Studio import path; set empty to skip the file check — the id check remains)
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
    string: "~/.lmstudio/models/frus-eval/embeddinggemma-300m-qat/embeddinggemma-300m-qat-Q4_0.gguf"
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
            model: env["MODEL"] ?? "frus-eval/embeddinggemma-300m-qat"),
        modelFile: modelFileEnv.isEmpty ? nil : URL(fileURLWithPath: modelFileEnv),
        outDirectory: url("OUT", default: "Planning/semantic-vectors/eval-2026-08-27"),
        // CSQUERY_JSON: a CSUserQueryEvalRunner output to merge as the third route.
        csUserQueryJSON: env["CSQUERY_JSON"].map { URL(fileURLWithPath: $0, relativeTo: cwd) }
    )
} catch {
    FileHandle.standardError.write(Data("RetrievalEvalHarness failed: \(error)\n".utf8))
    exit(1)
}
