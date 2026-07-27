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

/// User-tunable criteria that shape how text is reduced to word-cloud terms.
///
/// Bundled into one value so it threads cleanly through the service and folds into
/// the result cache key. `.standard` is the default behaviour applied when the user
/// hasn't changed anything in Settings — **and is the tuning the bundled cloud
/// vectors are generated under**, since a build-time artifact cannot know a user's
/// settings. A user who changes any of these sees a live cloud that differs from the
/// bundled preview; that divergence is a documented property, not a defect.
///
/// Version history:
///   1.0 — Word Cloud: tunable criteria + stop-list management
///   2.0 — O-1: moved into `WordCloudKit` so the generator shares the type
public struct WordCloudTuning: Sendable, Equatable, Codable {
    /// Shortest surviving token length (in characters).
    public var minimumLength: Int = 3
    /// Smallest total occurrence count a term must reach to appear.
    public var minimumCount: Int = 1
    /// Whether to fold likely plurals onto their singular form.
    public var foldPlurals: Bool = true
    /// Whether to drop classification markings and document chrome
    /// ("Top Secret", "Confidential", precedence words, month names).
    public var filterMarkings: Bool = true

    /// Creates a tuning. All parameters default to the shipped behaviour.
    public init(minimumLength: Int = 3, minimumCount: Int = 1,
                foldPlurals: Bool = true, filterMarkings: Bool = true) {
        self.minimumLength = minimumLength
        self.minimumCount = minimumCount
        self.foldPlurals = foldPlurals
        self.filterMarkings = filterMarkings
    }

    /// The default tuning (the historical behaviour, plus markings filtering on).
    public static let standard = WordCloudTuning()

    /// A short, stable token capturing this tuning for cache keys.
    public var cacheToken: String {
        "l\(minimumLength)c\(minimumCount)f\(foldPlurals ? 1 : 0)m\(filterMarkings ? 1 : 0)"
    }
}
