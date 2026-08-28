// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import CryptoKit

/// The harness's embedding client: LM Studio's OpenAI-compatible `/v1/embeddings`, with the
/// two guards the harvest tooling learned the hard way.
///
/// 1. **The model id is verified against `/v1/models` before any embedding runs.** LM Studio
///    routes an unknown id to whatever model happens to be loaded (observed 2026-08-10 by the
///    harvest), so a typo would "work" while embedding every query with a fictional model.
/// 2. **The GGUF's SHA-256 is verified against the artifact's pinned `modelFileSHA256`.** The
///    whole evaluation depends on query vectors living in the same space as the 314,483
///    document vectors; a different file — even a different quantization of the same model —
///    breaks that silently. Verified once per run, before the first request.
public struct LMStudioEmbeddingClient: Sendable {

    /// The server base, e.g. `http://localhost:1234`.
    public let baseURL: URL
    /// The served model id.
    public let model: String

    /// Creates a client.
    public init(baseURL: URL, model: String) {
        self.baseURL = baseURL
        self.model = model
    }

    /// Confirms the server lists `model` and, when `modelFile` is given, that its SHA-256
    /// equals `pinnedSHA256`. Throws a legible error otherwise.
    public func verify(modelFile: URL?, pinnedSHA256: String) async throws {
        let (data, _) = try await URLSession.shared.data(
            from: baseURL.appendingPathComponent("v1/models"))
        struct Models: Decodable { struct Row: Decodable { let id: String }; let data: [Row] }
        let listed = try JSONDecoder().decode(Models.self, from: data).data.map(\.id)
        guard listed.contains(model) else {
            throw EvalError("model \(model) is not among the ids the server reports "
                + "(\(listed.joined(separator: ", "))) — LM Studio routes an unknown id to "
                + "whatever is loaded, so refusing rather than embedding with a mystery model")
        }
        if let modelFile {
            let digest = SHA256.hash(data: try Data(contentsOf: modelFile))
                .map { String(format: "%02x", $0) }.joined()
            guard digest == pinnedSHA256 else {
                throw EvalError("MODEL_FILE SHA-256 \(digest) does not match the artifact's "
                    + "pinned \(pinnedSHA256) — a query embedded by a different file lives in "
                    + "a different space than the corpus")
            }
        }
    }

    /// Embeds one string, returning the native-width vector.
    public func embed(_ text: String) async throws -> [Double] {
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/embeddings"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300
        request.httpBody = try JSONSerialization.data(
            withJSONObject: ["model": model, "input": text])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw EvalError("embeddings request failed: "
                + (String(data: data, encoding: .utf8) ?? "<binary>"))
        }
        struct Body: Decodable {
            struct Row: Decodable { let embedding: [Double] }
            let data: [Row]
        }
        guard let vector = try JSONDecoder().decode(Body.self, from: data).data.first?.embedding
        else { throw EvalError("embeddings response carried no vector") }
        return vector
    }
}

/// A legible harness error.
public struct EvalError: Error, CustomStringConvertible, Sendable {
    /// What went wrong.
    public let description: String
    /// Creates an error.
    public init(_ description: String) { self.description = description }
}
