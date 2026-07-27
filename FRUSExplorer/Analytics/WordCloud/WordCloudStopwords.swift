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

/// The app's bundle-backed `WordCloudStopwordSet`.
///
/// The lists and all set-building live in `WordCloudKit`; this is only the
/// `Bundle.main` lookup, so the app and the offline generator decode the same JSON
/// through the same code rather than keeping two copies that can drift.
///
/// A missing or malformed file degrades to empty lists rather than trapping: an
/// unfiltered cloud is poor, but it is better than no Analytics tab at all. The
/// generator makes the opposite choice and throws — see `WordCloudStopwordSet`.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
///   2.0 — O-1: reduced to a bundle loader; the payload shape, lowercasing, and
///         `active(includeDiplomatic:)` moved to `WordCloudKit`
enum WordCloudStopwords {

    /// The decoded set, loaded once from the app bundle on first access.
    static let shared: WordCloudStopwordSet = {
        guard let url = Bundle.main.url(forResource: "word-cloud-stopwords", withExtension: "json") else {
            #if DEBUG
            print("[WordCloudStopwords] word-cloud-stopwords.json not found in bundle; using empty lists.")
            #endif
            return .empty
        }
        do {
            return try WordCloudStopwordSet(contentsOf: url)
        } catch {
            #if DEBUG
            print("[WordCloudStopwords] Failed to load word-cloud-stopwords.json — \(error); using empty lists.")
            #endif
            return .empty
        }
    }()

    /// The English function-word stopword set (lowercased).
    static var english: Set<String> { shared.english }

    /// The diplomatic-boilerplate stopword set (lowercased).
    static var diplomatic: Set<String> { shared.diplomatic }

    /// Classification markings, handling caveats, precedence words, and calendar terms.
    static var markings: Set<String> { shared.markings }

    /// The active stopword set for a request.
    ///
    /// - Parameter includeDiplomatic: When `true`, the diplomatic-boilerplate layer is
    ///   unioned with the always-on English layer.
    static func active(includeDiplomatic: Bool) -> Set<String> {
        shared.active(includeDiplomatic: includeDiplomatic)
    }
}
