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

// MARK: - WordCloudLens / WordCloudTuning
//
// Both moved to `WordCloudKit` in O-1 so the offline `CloudVectorsGenerator` classifies
// tokens through the same types rather than a second copy. The lens's localised `label`
// and `systemImage` stayed app-side, in `WordCloudLens+UI`.

// MARK: - WordCloudDocumentKey
//
// Moved to FRUSCoreKit in part 2 (`FRUSCoreKit/Analytics/WordCloud/WordCloudDocumentKey.swift`), since
// the indexing pipeline, which moved there too, reads and returns it.

// MARK: - WordCloudScope / WordCloudResult
//
// Moved to FRUSCoreKit (`FRUSCoreKit/Analytics/WordCloud/WordCloudScope.swift`, FRUS Explorer Light, S29b), with
// the count that makes a result (`WordCloudCount`), so that a host names a scope by its signature, as the app does,
// and counts it by the app's rules.
