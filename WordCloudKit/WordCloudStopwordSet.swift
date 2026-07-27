// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


import Foundation

/// The three stopword layers, decoded once and passed in rather than read from a bundle.
///
/// ## Why injection
/// Before O-1 these lists were `static let`s reading `Bundle.main` directly, which an
/// SPM command-line tool does not have. Worse than inconvenient: it meant the app and any
/// offline generator would each source their own copy, and nothing would notice if the two
/// diverged. The payload shape and the set-building now live here, so both callers decode
/// **the same JSON through the same code** — the app from its bundle, the generator from a
/// file URL.
///
/// Version history:
///   1.0 — O-1: extracted from the app's `WordCloudStopwords` with payloads injected
public struct WordCloudStopwordSet: Sendable {

    /// On-disk shape of `word-cloud-stopwords.json`.
    ///
    /// `markings` is optional because the file predates that layer; a file without it
    /// decodes to an empty marking set rather than failing.
    public struct Payload: Codable, Sendable {
        public let english: [String]
        public let diplomatic: [String]
        public let markings: [String]?

        /// Creates a payload (used by tests; production decodes it).
        public init(english: [String], diplomatic: [String], markings: [String]? = nil) {
            self.english = english
            self.diplomatic = diplomatic
            self.markings = markings
        }
    }

    /// The English function-word stopword set (lowercased).
    public let english: Set<String>

    /// The diplomatic-boilerplate stopword set (lowercased). Editorially opinionated,
    /// so it is applied only when the caller opts in.
    public let diplomatic: Set<String>

    /// Classification markings, handling caveats, precedence words, and calendar terms
    /// (lowercased). Document chrome rather than content, and a frequent source of
    /// named-entity false positives ("Top Secret" tagged as a place).
    public let markings: Set<String>

    /// Builds a set from a decoded payload, lowercasing every entry.
    public init(payload: Payload) {
        self.english = Set(payload.english.map { $0.lowercased() })
        self.diplomatic = Set(payload.diplomatic.map { $0.lowercased() })
        self.markings = Set((payload.markings ?? []).map { $0.lowercased() })
    }

    /// Decodes `word-cloud-stopwords.json` from `url`.
    ///
    /// - Throws: whatever `Data(contentsOf:)` or `JSONDecoder` throws. Callers that must
    ///   not fail (the app, which prefers a degraded cloud to no cloud) catch and fall
    ///   back to ``empty``; the generator lets it throw, because a generator that
    ///   silently emitted an unfiltered corpus would be worse than one that stopped.
    public init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url)
        self.init(payload: try JSONDecoder().decode(Payload.self, from: data))
    }

    /// An empty set — every layer absent.
    public static let empty = WordCloudStopwordSet(payload: Payload(english: [], diplomatic: [], markings: []))

    /// The active stopword set for a request.
    ///
    /// - Parameter includeDiplomatic: When `true`, the diplomatic-boilerplate layer is
    ///   unioned with the always-on English layer.
    public func active(includeDiplomatic: Bool) -> Set<String> {
        includeDiplomatic ? english.union(diplomatic) : english
    }
}
