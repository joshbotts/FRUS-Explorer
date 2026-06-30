// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import SwiftUI

// MARK: - WordCloudGlyph

/// The app's Word Cloud mark: a single SF Symbol name, reused everywhere so the icon
/// is identical across iOS, iPadOS, and macOS.
///
/// `textformat.abc` reads as "words" without the cloud iconography that users mistook
/// for iCloud / cloud sync. Exposed as a plain symbol-name string (rather than a
/// composed `View`) so every call site — `Image(systemName:)`, a `Label`'s
/// `systemImage:`, a toolbar button, or `ContentUnavailableView` — renders the same
/// stock glyph and inherits the ambient size and tint.
///
/// Version history:
///   1.0 — Session 167: composite `cloud.fill` + `textformat` mark
///   2.0 — Session 170: reverted the composite view to the stock `textformat.abc`
///         symbol (the cloud read as iCloud/sync; the composite rendered inconsistently
///         across platforms)
enum WordCloudGlyph {
    /// The SF Symbol name for the Word Cloud feature.
    static let symbol = "textformat.abc"
}

// MARK: - Appearance

/// The typeface family a word cloud is drawn in. A device-local appearance
/// preference (not synced via iCloud), surfaced in the Word Cloud settings pane.
///
/// `widthFactor` is the average glyph-advance ratio used by ``WordCloudLayout`` to
/// estimate text extents for collision packing, so changing the font also re-tunes
/// the layout's spacing rather than just restyling the glyphs.
///
/// Version history:
///   1.0 — Word Cloud: font + density appearance controls
enum WordCloudFontDesign: String, CaseIterable, Sendable, Identifiable {
    /// SwiftUI's rounded system design (the original word-cloud look).
    case rounded
    /// The default system sans-serif.
    case standard
    /// A serif design.
    case serif
    /// A fixed-width monospaced design.
    case monospaced

    /// Stable identity for `Picker`/`ForEach`.
    var id: String { rawValue }

    /// The matching SwiftUI font design.
    var swiftUIDesign: Font.Design {
        switch self {
        case .rounded: return .rounded
        case .standard: return .default
        case .serif: return .serif
        case .monospaced: return .monospaced
        }
    }

    /// Average glyph-advance ratio (× point size) for layout extent estimation.
    /// Monospaced glyphs are widest; serif and rounded run slightly narrower.
    var widthFactor: CGFloat {
        switch self {
        case .rounded: return 0.54
        case .standard: return 0.54
        case .serif: return 0.52
        case .monospaced: return 0.62
        }
    }

    /// Localized display name for the settings picker.
    var label: String {
        switch self {
        case .rounded:
            return String(localized: "wordcloud.font.rounded", defaultValue: "Rounded")
        case .standard:
            return String(localized: "wordcloud.font.standard", defaultValue: "Default")
        case .serif:
            return String(localized: "wordcloud.font.serif", defaultValue: "Serif")
        case .monospaced:
            return String(localized: "wordcloud.font.monospaced", defaultValue: "Monospaced")
        }
    }
}

/// How tightly a word cloud packs its terms. A device-local appearance preference
/// (not synced via iCloud), surfaced in the Word Cloud settings pane.
///
/// `spacingScale` multiplies both the spiral step tightness and the inter-word gap
/// in ``WordCloudLayout``: below 1 packs words closer (denser), above 1 spreads them.
///
/// Version history:
///   1.0 — Word Cloud: font + density appearance controls
enum WordCloudDensity: String, CaseIterable, Sendable, Identifiable {
    /// Tightly packed, maximising the number of visible terms.
    case compact
    /// The original balanced spacing.
    case balanced
    /// Generous spacing for a more legible, less crowded cloud.
    case airy

    /// Stable identity for `Picker`/`ForEach`.
    var id: String { rawValue }

    /// Spacing multiplier applied to the spiral packing (1 = original spacing).
    var spacingScale: CGFloat {
        switch self {
        case .compact: return 0.72
        case .balanced: return 1.0
        case .airy: return 1.45
        }
    }

    /// Localized display name for the settings picker.
    var label: String {
        switch self {
        case .compact:
            return String(localized: "wordcloud.density.compact", defaultValue: "Compact")
        case .balanced:
            return String(localized: "wordcloud.density.balanced", defaultValue: "Balanced")
        case .airy:
            return String(localized: "wordcloud.density.airy", defaultValue: "Airy")
        }
    }
}

// MARK: - WordCloudLens

/// A semantic filter applied while tokenising, so a word cloud can foreground a
/// particular kind of term instead of all frequent words.
///
/// `allTerms` is the default (lemmatised content words). The entity lenses use
/// Apple's `NaturalLanguage` named-entity recogniser; the part-of-speech lenses
/// use its lexical-class tagger. All run on-device.
///
/// Version history:
///   1.0 — Word Cloud v2: semantic lenses
enum WordCloudLens: String, CaseIterable, Sendable, Codable, Identifiable {
    /// All frequent content words (the original behaviour).
    case allTerms
    /// Named people.
    case people
    /// Named places.
    case places
    /// Named organizations.
    case organizations
    /// Common nouns — the subjects/topics of the text.
    case topics
    /// Verbs — the actions.
    case actions
    /// Adjectives — descriptive language.
    case descriptors
    /// Abstract IR/diplomacy concepts (sovereignty, legitimacy, deterrence…).
    case concepts
    /// Sentiment-bearing words, coloured by polarity.
    case sentiment

    var id: String { rawValue }

    /// `true` for the named-entity lenses (people / places / organizations).
    var isEntity: Bool {
        switch self {
        case .people, .places, .organizations: return true
        default: return false
        }
    }

    /// Lenses whose output depends on how much matching signal a scope contains —
    /// a tiny document may have few or no entities, concepts, or sentiment words, so
    /// the UI shows an "insufficient signal" state rather than a near-empty cloud.
    var isSignalDependent: Bool {
        switch self {
        case .allTerms, .topics, .actions, .descriptors: return false
        case .people, .places, .organizations, .concepts, .sentiment: return true
        }
    }

    /// The minimum number of terms below which this lens is treated as having
    /// insufficient signal to display for a scope.
    var minimumSignalTerms: Int { isSignalDependent ? 4 : 0 }

    /// `true` when the cloud should colour words by sentiment polarity instead of
    /// the rank palette.
    var colorsBySentiment: Bool { self == .sentiment }

    /// Localised menu label.
    var label: String {
        switch self {
        case .allTerms:      return String(localized: "wordcloud.lens.all", defaultValue: "All terms")
        case .people:        return String(localized: "wordcloud.lens.people", defaultValue: "People")
        case .places:        return String(localized: "wordcloud.lens.places", defaultValue: "Places")
        case .organizations: return String(localized: "wordcloud.lens.orgs", defaultValue: "Organizations")
        case .topics:        return String(localized: "wordcloud.lens.topics", defaultValue: "Topics (nouns)")
        case .actions:       return String(localized: "wordcloud.lens.actions", defaultValue: "Actions (verbs)")
        case .descriptors:   return String(localized: "wordcloud.lens.descriptors", defaultValue: "Descriptors (adjectives)")
        case .concepts:      return String(localized: "wordcloud.lens.concepts", defaultValue: "Concepts")
        case .sentiment:     return String(localized: "wordcloud.lens.sentiment", defaultValue: "Sentiment")
        }
    }

    /// SF Symbol for the lens menu.
    var systemImage: String {
        switch self {
        case .allTerms:      return "text.word.spacing"
        case .people:        return "person.2"
        case .places:        return "mappin.and.ellipse"
        case .organizations: return "building.2"
        case .topics:        return "tag"
        case .actions:       return "bolt"
        case .descriptors:   return "paintpalette"
        case .concepts:      return "lightbulb"
        case .sentiment:     return "face.smiling"
        }
    }
}

// MARK: - WordCloudTuning

/// User-tunable criteria that shape how text is reduced to word-cloud terms.
///
/// Bundled into one value so it threads cleanly through the service and folds into
/// the result cache key. `.standard` is the default behaviour applied when the user
/// hasn't changed anything in Settings.
///
/// Version history:
///   1.0 — Word Cloud: tunable criteria + stop-list management
struct WordCloudTuning: Sendable, Equatable, Codable {
    /// Shortest surviving token length (in characters).
    var minimumLength: Int = 3
    /// Smallest total occurrence count a term must reach to appear.
    var minimumCount: Int = 1
    /// Whether to fold likely plurals onto their singular form.
    var foldPlurals: Bool = true
    /// Whether to drop classification markings and document chrome
    /// ("Top Secret", "Confidential", precedence words, month names).
    var filterMarkings: Bool = true

    /// The default tuning (the historical behaviour, plus markings filtering on).
    static let standard = WordCloudTuning()

    /// A short, stable token capturing this tuning for cache keys.
    var cacheToken: String {
        "l\(minimumLength)c\(minimumCount)f\(foldPlurals ? 1 : 0)m\(filterMarkings ? 1 : 0)"
    }
}

// MARK: - WordCloudDocumentKey

/// A composite document identity (`volumeId` + `documentId`) used to address a
/// single FRUS document when resolving a `WordCloudScope` into the set of
/// documents whose text feeds a word cloud.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
struct WordCloudDocumentKey: Hashable, Sendable {
    /// FRUS volume identifier (e.g. `"frus1969-76v01"`).
    let volumeId: String
    /// Document identifier within the volume (e.g. `"d42"`).
    let documentId: String

    /// Creates a document key.
    /// - Parameters:
    ///   - volumeId: The FRUS volume identifier.
    ///   - documentId: The document identifier within the volume.
    init(volumeId: String, documentId: String) {
        self.volumeId = volumeId
        self.documentId = documentId
    }
}

// MARK: - WordCloudScope

/// Identifies a body of FRUS material to compute a word cloud over.
///
/// Every case ultimately resolves to a set of `WordCloudDocumentKey` values (or,
/// for `.corpus`, the entire index), which `WordFrequencyService` turns into a
/// ranked list of the most frequent meaningful terms. Resolution of the
/// SwiftData-backed cases (`.collection`, `.userTag`, `.savedSearch`) happens on
/// the main actor in `WordCloudScopeResolver`, which has access to the model
/// context; the FTS-backed cases are resolved inside the service.
///
/// Version history:
///   1.0 — Word Cloud feature: initial implementation
enum WordCloudScope: Hashable, Sendable, Identifiable {
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
    /// Every document whose date falls within an inclusive `yyyy-MM-dd` range —
    /// the bridge between the Chronology browser and the word cloud.
    case dateRange(startISO: String, endISO: String)

    /// Identity for SwiftUI presentation (`.sheet(item:)`); equals `signature`.
    var id: String { signature }

    /// Reconstructs a scope from its `signature` (the inverse of `signature`).
    ///
    /// Used to drain the background precompute queue, which persists scopes as
    /// their signature strings. Returns `nil` for an unrecognised or malformed
    /// signature.
    init?(signature: String) {
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
    var signature: String {
        switch self {
        case let .document(volumeId, documentId): return "doc:\(volumeId)/\(documentId)"
        case let .volume(volumeId):               return "vol:\(volumeId)"
        case let .subseries(subseriesId):         return "sub:\(subseriesId)"
        case .corpus:                             return "corpus"
        case let .collection(id):                 return "col:\(id.uuidString)"
        case let .userTag(id):                    return "tag:\(id.uuidString)"
        case let .savedSearch(id):                return "search:\(id.uuidString)"
        case let .dateRange(startISO, endISO):    return "daterange:\(startISO)..\(endISO)"
        }
    }

    // MARK: - Date-range helpers

    /// Shared `yyyy-MM-dd` formatter (UTC, POSIX locale) for date-range signatures —
    /// matching the ISO day keys the Chronology date index is queried with.
    private static func isoFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }

    /// The `yyyy-MM-dd` (UTC) day string for a date, for building a `.dateRange` scope.
    static func isoDay(from date: Date) -> String {
        isoFormatter().string(from: date)
    }

    /// Parses a `yyyy-MM-dd` (UTC) day string back to a `Date` (start of that day).
    static func day(fromISO iso: String) -> Date? {
        isoFormatter().date(from: iso)
    }

    /// A readable title for a date-range scope, e.g. "Feb 1969 – Dec 1969".
    static func dateRangeTitle(startISO: String, endISO: String) -> String {
        let display = DateFormatter()
        display.locale = .autoupdatingCurrent
        display.setLocalizedDateFormatFromTemplate("MMM d, yyyy")
        let start = day(fromISO: startISO).map(display.string(from:)) ?? startISO
        let end = day(fromISO: endISO).map(display.string(from:)) ?? endISO
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
struct WordCloudResult: Sendable, Codable {
    /// The most frequent terms, sorted by descending count (ties broken
    /// alphabetically). Length is bounded by the requested limit.
    let terms: [TermCount]
    /// Number of documents whose text contributed to the counts.
    let documentCount: Int
    /// Total number of non-stopword tokens scanned across all documents.
    let totalTokenCount: Int

    /// An empty result (no documents in scope, or no surviving tokens).
    static let empty = WordCloudResult(terms: [], documentCount: 0, totalTokenCount: 0)
}
