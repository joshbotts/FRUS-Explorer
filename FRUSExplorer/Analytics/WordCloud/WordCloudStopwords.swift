// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

/// Loads and provides the bundled word-cloud stopword lists.
///
/// Two layers are maintained, mirroring `word-cloud-stopwords.json`:
/// - **English** — standard high-frequency function words, always excluded.
/// - **Diplomatic** — FRUS-domain boilerplate ("telegram", "department",
///   "washington", …) that otherwise dominates every cloud. Editorially
///   opinionated, so it is applied only when the caller opts in (the UI defaults
///   it on but lets the researcher disable it).
///
/// The lists are decoded once and cached for the process lifetime.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
enum WordCloudStopwords {

    /// On-disk shape of `word-cloud-stopwords.json`.
    private struct Payload: Decodable {
        let english: [String]
        let diplomatic: [String]
    }

    /// Decoded payload, loaded lazily from the app bundle on first access.
    private static let payload: Payload = {
        guard
            let url = Bundle.main.url(forResource: "word-cloud-stopwords", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(Payload.self, from: data)
        else {
            #if DEBUG
            print("[WordCloudStopwords] Failed to load word-cloud-stopwords.json; using empty lists.")
            #endif
            return Payload(english: [], diplomatic: [])
        }
        return decoded
    }()

    /// The English function-word stopword set (lowercased).
    static let english: Set<String> = Set(payload.english.map { $0.lowercased() })

    /// The diplomatic-boilerplate stopword set (lowercased).
    static let diplomatic: Set<String> = Set(payload.diplomatic.map { $0.lowercased() })

    /// The active stopword set for a request.
    ///
    /// - Parameter includeDiplomatic: When `true`, the diplomatic-boilerplate
    ///   layer is unioned with the always-on English layer.
    /// - Returns: The combined set of terms to exclude.
    static func active(includeDiplomatic: Bool) -> Set<String> {
        includeDiplomatic ? english.union(diplomatic) : english
    }
}
