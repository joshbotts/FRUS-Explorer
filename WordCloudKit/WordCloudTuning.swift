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
///   2.1 — 2026-11-12 (FRUS Explorer Light, S24d): the reading of a reader's settings, which was the
///          app's `WordCloudSettings`', so a host maps the synced preferences as the app maps them
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

// MARK: - From a reader's settings

extension WordCloudTuning {

    /// A stored minimum length as the settings read it: the shipped default where nothing is
    /// stored, and never below 2.
    ///
    /// The app's `WordCloudSettings.minimumLength` reads its stored value through this, and so does
    /// ``init(settingsMinimumLength:minimumCount:foldPlurals:filterMarkings:)``.
    /// - Parameter stored: The stored value, or `nil` when none is stored.
    public static func minimumLength(fromSetting stored: Int?) -> Int {
        max(2, stored ?? standard.minimumLength)
    }

    /// A stored minimum count as the settings read it: the shipped default where nothing is stored,
    /// and never below 1.
    /// - Parameter stored: The stored value, or `nil` when none is stored.
    public static func minimumCount(fromSetting stored: Int?) -> Int {
        max(1, stored ?? standard.minimumCount)
    }

    /// A stored plural-folding switch as the settings read it: on where nothing is stored.
    /// - Parameter stored: The stored value, or `nil` when none is stored.
    public static func foldPlurals(fromSetting stored: Bool?) -> Bool {
        stored ?? standard.foldPlurals
    }

    /// A stored markings-filter switch as the settings read it: on where nothing is stored.
    /// - Parameter stored: The stored value, or `nil` when none is stored.
    public static func filterMarkings(fromSetting stored: Bool?) -> Bool {
        stored ?? standard.filterMarkings
    }

    /// The tuning a reader's Word Cloud settings give, read as the app reads them: the minimum
    /// length at least 2, the minimum count at least 1, and the shipped value of each setting that
    /// holds nothing.
    ///
    /// A host passes the synced preferences' `wcMinLength`, `wcMinCount`, `wcFoldPlurals` and
    /// `wcFilterMarkings`, the values the app copies into its settings when they sync. The
    /// boilerplate setting, `wcExcludeBoilerplate`, is not a tuning: it is the diplomatic stopword
    /// layer, passed as it is stored (`includeDiplomatic`, never inverted), and the custom stop
    /// lists are the app's `WordCloudSettings.extraStopwords(for:)`.
    /// - Parameters:
    ///   - minimumLength: The stored minimum length, or `nil`.
    ///   - minimumCount: The stored minimum count, or `nil`.
    ///   - foldPlurals: The stored plural-folding switch, or `nil`.
    ///   - filterMarkings: The stored markings-filter switch, or `nil`.
    public init(settingsMinimumLength minimumLength: Int?, minimumCount: Int?,
                foldPlurals: Bool?, filterMarkings: Bool?) {
        self.init(minimumLength: Self.minimumLength(fromSetting: minimumLength),
                  minimumCount: Self.minimumCount(fromSetting: minimumCount),
                  foldPlurals: Self.foldPlurals(fromSetting: foldPlurals),
                  filterMarkings: Self.filterMarkings(fromSetting: filterMarkings))
    }
}
