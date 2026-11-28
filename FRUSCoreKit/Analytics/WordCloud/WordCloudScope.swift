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

#if canImport(WordCloudKit)
import WordCloudKit
#endif

// The word cloud's scope and the count's result, out of the app's `WordCloudModels.swift` (FRUS Explorer
// Light, S29b), whose appearance types stay the app's: a host names a scope by its signature, as the
// app's precompute queue and caches do, and the count (`WordCloudCount`) returns a result.

// MARK: - WordCloudScope

/// Identifies a body of FRUS material to compute a word cloud over.
///
/// Every case ultimately resolves to a set of `WordCloudDocumentKey` values (or,
/// for `.corpus`, the entire index), which `WordFrequencyService` turns into a
/// ranked list of the most frequent meaningful terms. Resolution of the
/// SwiftData-backed cases (`.collection`, `.userTag`, `.savedSearch`,
/// `.customScope`) happens on the main actor in `WordCloudScopeResolver`, which has
/// access to the model context; the FTS-backed cases are resolved inside the service.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
///   1.1 — Word Cloud fixes: `isoDay(from:)` / `day(fromISO:)` convert in the user's
///          local timezone (was UTC) so date-range bounds agree with the DatePickers
///          and Chronology's local-calendar normalisation on every hand-off
///   1.2 — #258 Phase 5: `.customScope(id:)` — a user-defined custom volume scope,
///          referenced by record id (the sketch's §8-Q3 reference-not-copy rule) with
///          full `signature` round-trip for the precompute queue and result caches
///   1.3 — #308 Phase 1 (F6): `.subjectCategory(category:subcategory:)` — the word-cloud
///          arm of the detected-topic facets; signature `subject:<category>` or
///          `subject:<category>␟<subcategory>` (U+001F delimiter, absent from taxonomy
///          labels), resolved volume-grain like `.subseries`
///   1.4 — 2026-11-24 (FRUS Explorer Light, S29b): moved into FRUSCoreKit, public, with its signatures,
///          for a host that names a scope as the app does; its title's dates are still the user's calendar's
///   1.5 — 2026-11-27: #2033 (L62) — `isoDay(from:in:)` and `day(fromISO:in:)` convert through `DateRange.day(of:in:)`
///          and `firstMoment(ofDay:in:)`, Search's pair, so a day whose midnight a change of clocks skips reads as that
///          day, where the strict formatter read no date; they and `dateRangeTitle(startISO:endISO:in:)` take a zone,
///          the device's by default
/// #752/M-31: `Codable` so the scope can key a value-based `WindowGroup` on iPad. The word cloud
/// was the only Research-rail tool without a scene of its own, which is why it alone rode a
/// cross-window hand-off and opened in the wrong window from a standalone document window.
public enum WordCloudScope: Hashable, Sendable, Identifiable, Codable {
    /// A single document.
    case document(volumeId: String, documentId: String)
    /// Every document in a single volume.
    case volume(volumeId: String)
    /// Every document across the volumes of a FRUS subseries.
    case subseries(subseriesId: String)
    /// The entire indexed corpus.
    case corpus
    /// Every document in a user-created collection.
    case collection(id: UUID)
    /// Every document tagged with a user tag.
    case userTag(id: UUID)
    /// Every document matching a saved search.
    case savedSearch(id: UUID)
    /// Every indexed document across the volumes of a user-defined custom volume
    /// scope (#258 Phase 5). Referenced by record id — never a copied member list —
    /// so a dangling reference (scope deleted on another device) resolves to an
    /// explicit not-found outcome, the resolver's established dangling-UUID pattern.
    case customScope(id: UUID)
    /// Every indexed document across the volumes whose bundled subject profile carries a
    /// detected-topic **category** (and optionally a **sub-category**) — the word-cloud arm of
    /// #308's two-level facets. Volume-grain by construction (the profiles are volume-grain);
    /// resolves like `.subseries` (category → volumes → keys). `subcategory == nil` is the
    /// whole-category scope.
    case subjectCategory(category: String, subcategory: String?)
    /// Every document whose date falls within an inclusive `yyyy-MM-dd` range —
    /// the bridge between the Chronology browser and the word cloud.
    case dateRange(startISO: String, endISO: String)

    /// Identity for SwiftUI presentation (`.sheet(item:)`); equals `signature`.
    public var id: String { signature }

    /// Reconstructs a scope from its `signature` (the inverse of `signature`).
    ///
    /// Used to drain the background precompute queue, which persists scopes as
    /// their signature strings. Returns `nil` for an unrecognised or malformed
    /// signature.
    public init?(signature: String) {
        if signature == "corpus" { self = .corpus; return }
        guard let colon = signature.firstIndex(of: ":") else { return nil }
        let prefix = String(signature[..<colon])
        let value = String(signature[signature.index(after: colon)...])
        switch prefix {
        case "doc":
            guard let slash = value.firstIndex(of: "/") else { return nil }
            let volumeId = String(value[..<slash])
            let documentId = String(value[value.index(after: slash)...])
            self = .document(volumeId: volumeId, documentId: documentId)
        case "vol":
            self = .volume(volumeId: value)
        case "sub":
            self = .subseries(subseriesId: value)
        case "col":
            guard let uuid = UUID(uuidString: value) else { return nil }
            self = .collection(id: uuid)
        case "tag":
            guard let uuid = UUID(uuidString: value) else { return nil }
            self = .userTag(id: uuid)
        case "search":
            guard let uuid = UUID(uuidString: value) else { return nil }
            self = .savedSearch(id: uuid)
        case "scope":
            guard let uuid = UUID(uuidString: value) else { return nil }
            self = .customScope(id: uuid)
        case "subject":
            // "<category>" or "<category>␟<subcategory>" (␟ = U+001F unit separator, absent
            // from taxonomy labels; the leading ":" already split off the prefix).
            let parts = value.components(separatedBy: "\u{1f}")
            guard let category = parts.first, !category.isEmpty else { return nil }
            let subcategory = parts.count > 1 && !parts[1].isEmpty ? parts[1] : nil
            self = .subjectCategory(category: category, subcategory: subcategory)
        case "daterange":
            let bounds = value.components(separatedBy: "..")
            guard bounds.count == 2, !bounds[0].isEmpty, !bounds[1].isEmpty else { return nil }
            self = .dateRange(startISO: bounds[0], endISO: bounds[1])
        default:
            return nil
        }
    }

    /// A stable string key identifying this scope, used to cache computed results.
    ///
    /// Distinct scopes always produce distinct signatures; the same scope always
    /// produces the same signature, so a cache keyed on it is correct across view
    /// re-creations.
    public var signature: String {
        switch self {
        case let .document(volumeId, documentId): return "doc:\(volumeId)/\(documentId)"
        case let .volume(volumeId):               return "vol:\(volumeId)"
        case let .subseries(subseriesId):         return "sub:\(subseriesId)"
        case .corpus:                             return "corpus"
        case let .collection(id):                 return "col:\(id.uuidString)"
        case let .userTag(id):                    return "tag:\(id.uuidString)"
        case let .savedSearch(id):                return "search:\(id.uuidString)"
        case let .customScope(id):                return "scope:\(id.uuidString)"
        case let .subjectCategory(category, subcategory):
            return subcategory.map { "subject:\(category)\u{1f}\($0)" } ?? "subject:\(category)"
        case let .dateRange(startISO, endISO):    return "daterange:\(startISO)..\(endISO)"
        }
    }

    // MARK: - Date-range helpers

    /// The `yyyy-MM-dd` day string (in the user's local calendar) for a date, for
    /// building a `.dateRange` scope.
    ///
    /// The index's ISO day keys are timezone-less calendar days, so the timezone
    /// here only governs the `Date` ↔ day-string conversion — and it MUST match
    /// the local calendar every consuming surface works in (`DatePicker`s, the
    /// Chronology view model's `Calendar.startOfDay` normalisation, and the
    /// localized display formatters). A UTC formatter here shifted the bounds by
    /// one day for any non-UTC user and walked the range a day earlier on each
    /// Cloud → Chronology round trip. Both directions convert through `DateRange`'s
    /// pair since #2033, as Search's date filter does.
    ///
    /// - Parameters:
    ///   - date: A moment, such as a picker's date.
    ///   - timeZone: The zone the pickers are in: the device's, `.current`, unless a test passes another.
    /// - Returns: The day, as `yyyy-MM-dd`.
    public static func isoDay(from date: Date, in timeZone: TimeZone = .current) -> String {
        DateRange.day(of: date, in: timeZone)
    }

    /// Parses a `yyyy-MM-dd` day string back to a `Date`: the first moment of that
    /// day in `timeZone` (`DateRange.firstMoment(ofDay:in:)`).
    ///
    /// That is the day's midnight, unless a change of clocks skips it: then the
    /// day's first moment, where the strict `DateFormatter` this read with until
    /// #2033 read no date, and the range's pickers fell back to the year 1 and now.
    ///
    /// - Parameters:
    ///   - iso: A day, as `yyyy-MM-dd`.
    ///   - timeZone: The zone the pickers are in: the device's, `.current`, unless a test passes another.
    /// - Returns: The day's first moment, or `nil` for a string that names no day.
    public static func day(fromISO iso: String, in timeZone: TimeZone = .current) -> Date? {
        DateRange.firstMoment(ofDay: iso, in: timeZone)
    }

    /// A readable title for a date-range scope, e.g. "Feb 1969 – Dec 1969".
    ///
    /// Each day is named in words at its first moment in `timeZone`, the device's unless a test passes another; a
    /// string that names no day is printed as it is.
    public static func dateRangeTitle(startISO: String, endISO: String, in timeZone: TimeZone = .current) -> String {
        let display = DateFormatter()
        display.locale = .autoupdatingCurrent
        display.timeZone = timeZone
        display.setLocalizedDateFormatFromTemplate("MMM d, yyyy")
        let start = day(fromISO: startISO, in: timeZone).map(display.string(from:)) ?? startISO
        let end = day(fromISO: endISO, in: timeZone).map(display.string(from:)) ?? endISO
        return String(format: String(localized: "wordcloud.scope.dateRange.title %@ %@",
                                      defaultValue: "%@ – %@"), start, end)
    }
}

// MARK: - WordCloudResult

/// The computed output of a word cloud: the top terms plus the provenance counts
/// that contextualise them (how many documents and tokens were scanned).
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
///   1.1 — S-5b: optional `lens` stamp, written when a result is persisted to disk
///   1.2 — #1373: optional `languageAnalysis` stamp — what the tagger could do when these terms
///          were counted
///   1.3 — #1421 review: optional `indexVersion` stamp — the installed index version whose
///          `body_text` these terms were counted from
///   1.4 — 2026-11-24 (FRUS Explorer Light, S29b): moved into FRUSCoreKit, public, with
///          ``WordCloudCount``, which makes it
public struct WordCloudResult: Sendable, Codable {
    /// The most frequent terms, sorted by descending count (ties broken
    /// alphabetically). Length is bounded by the requested limit.
    public let terms: [TermCount]
    /// Number of documents whose text contributed to the counts.
    public let documentCount: Int
    /// Total number of non-stopword tokens scanned across all documents.
    public let totalTokenCount: Int

    /// The lens these terms were computed under, when known.
    ///
    /// Optional, and absent on every entry written before S-5b: the disk cache names its files
    /// by a SHA-256 of the cache key, so nothing about a stored result was recoverable from it.
    /// The Word Cloud settings bench needs this, because an entity-lens cloud is a list of
    /// multi-word names ("united states", "john f. kennedy") and the word-path criteria reject
    /// anything containing a space — measuring one against the other would report a near-total
    /// drop that says nothing about the user's settings. The bench treats an unknown lens as
    /// unusable rather than guess.
    ///
    /// Decoding is backward-compatible: entries without the field decode with `nil`.
    public var lens: WordCloudLens?

    /// What the on-device language tagger could do in the process that counted these terms
    /// (#1373), or `nil` when unknown.
    ///
    /// A property of the RESULT, not of the process showing it: a cloud read back from the disk
    /// cache was counted by an earlier process, whose tagger may have worked where this one's does
    /// not, or the reverse. So the keyness gate and the "counted as printed" caption read this, and
    /// `WordFrequencyService` neither persists a result whose tagger failed the lens nor reuses a
    /// persisted one that cannot say. `nil` on every entry written before #1373, and on `.empty`.
    public var languageAnalysis: NaturalLanguageHealth?

    /// The installed date-index version (`IndexingPipeline.installedDateIndexVersion`) whose
    /// `body_text` these terms were counted from (#1421 review), or `nil` when unknown.
    ///
    /// The disk cache fingerprints the index by its document COUNT, and a re-index that rewrites
    /// the text keeps the count: v59 re-joined 313,949 bodies and left `document_cache` the same
    /// size, so a corpus or subseries cloud counted from the old text would have been served back
    /// until a volume was added or removed. `WordFrequencyService` reuses a persisted result only
    /// while this equals the installed version. `nil` on every entry written before the stamp, and
    /// on `.empty`.
    public var indexVersion: Int?

    /// A result of `terms`, counted from `documentCount` documents' `totalTokenCount` surviving tokens, with
    /// the stamps a count sets; spelt out so a host can make one (FRUS Explorer Light, S29b).
    public init(terms: [TermCount], documentCount: Int, totalTokenCount: Int, lens: WordCloudLens? = nil,
                languageAnalysis: NaturalLanguageHealth? = nil, indexVersion: Int? = nil) {
        self.terms = terms
        self.documentCount = documentCount
        self.totalTokenCount = totalTokenCount
        self.lens = lens
        self.languageAnalysis = languageAnalysis
        self.indexVersion = indexVersion
    }

    /// An empty result (no documents in scope, or no surviving tokens).
    public static let empty = WordCloudResult(terms: [], documentCount: 0, totalTokenCount: 0)
}

extension WordCloudResult {
    /// The terms with any words hidden **just for the current open cloud** removed
    /// (#233 — a non-persistent, per-view-session hide, distinct from the persistent
    /// per-scope `WordCloudOverrides` and the global/lens stop lists).
    ///
    /// Comparison is case-insensitive against the bare term (hidden words are stored
    /// lowercased). Returns `terms` unchanged when `hidden` is empty. Because this filters
    /// the already-computed list, a hide takes effect instantly and the cloud backfills
    /// from the fetched-but-unplaced surplus without a recompute.
    public func visibleTerms(excluding hidden: Set<String>) -> [TermCount] {
        guard !hidden.isEmpty else { return terms }
        return terms.filter { !hidden.contains($0.term.lowercased()) }
    }

    /// This result without `term` (compared case-insensitively), for a hide that must take effect
    /// without a recompute.
    ///
    /// The counts and all three stamps are kept: they describe how the remaining terms were
    /// counted, which a hide does not change. The view used to rebuild the result from its three
    /// counts alone, which dropped the stamps — harmless while only the settings bench read `lens`,
    /// and not once the keyness gate read `languageAnalysis` (#1373): a hide would have switched it
    /// from the result's verdict to this process's.
    public func removingTerm(_ term: String) -> WordCloudResult {
        let lower = term.lowercased()
        var trimmed = WordCloudResult(
            terms: terms.filter { $0.term.lowercased() != lower },
            documentCount: documentCount,
            totalTokenCount: totalTokenCount
        )
        trimmed.lens = lens
        trimmed.languageAnalysis = languageAnalysis
        trimmed.indexVersion = indexVersion
        return trimmed
    }
}
