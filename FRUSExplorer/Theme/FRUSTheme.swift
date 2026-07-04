// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI

// MARK: - AttributedString + Markdown body text

extension AttributedString {
    /// Builds an attributed string from `raw`, interpreting inline Markdown
    /// formatting — `**bold**`, `*italic*`, and `[text](url)` links — while
    /// gracefully falling back to verbatim plain text if parsing fails.
    ///
    /// FRUS Explorer's About, Onboarding, and Education content occasionally
    /// embeds inline hyperlinks and emphasis directly in localized prose, e.g.
    /// `[1991 federal statute](https://...)` or `**Foreign Relations of the
    /// United States**`. Centralizing the parsing here ensures all three
    /// contexts (About, Onboarding intro, Education pages) render such spans
    /// identically, with tappable links and styled emphasis, without requiring
    /// each call site to hand-build ranges.
    ///
    /// Version history:
    ///   1.0 — Session 2026-06-06: introduced for revised static content
    init(markdownBody raw: String) {
        if let parsed = try? AttributedString(
            markdown: raw,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            self = parsed
        } else {
            self = AttributedString(raw)
        }
    }
}

// MARK: - ChartSeriesPalette

/// Shared color palette and configuration for the color-coded series (volumes) in the
/// Chronology distribution chart and the Corpus Analytics source-colored charts.
///
/// Both surfaces previously held their own 7-color palette while capping the colored
/// series at 8 — so the 8th series wrapped back to the first color. This unifies the
/// palette (12 perceptually-distinct system colors) and exposes a user-configurable
/// series count, defaulting to 8, persisted globally and overridable per view.
///
/// Version history:
///   1.0 — Session 168: unified palette + configurable series count
enum ChartSeriesPalette {

    /// Twelve distinct system colors. System colors so light/dark mode and accessibility
    /// contrast are handled by the OS. The folded "Other" series always uses gray
    /// (assigned by the call sites, not from this list).
    static let colors: [Color] = [
        .blue, .orange, .green, .purple, .pink, .teal,
        .indigo, .red, .mint, .cyan, .brown, .yellow,
    ]

    /// Allowed range for the user-configurable colored-series count.
    static let range: ClosedRange<Int> = 6...12

    /// Default colored-series count (the historical cap).
    static let defaultCount = 8

    /// `AppStorage`/`UserDefaults` key for the global default colored-series count.
    static let storageKey = "frus.display.chartSeriesCount"

    /// Color for the series at rank `index` (wraps if `index` exceeds the palette,
    /// though the configurable max keeps it within range in practice).
    static func color(at index: Int) -> Color {
        colors[index % colors.count]
    }
}

// MARK: - FeatureInfoButton

/// One titled explanation row shown inside a `FeatureInfoButton` popover.
struct FeatureInfoItem: Identifiable {
    let title: String
    let detail: String
    var id: String { title }
}

/// A toolbar "info" button that presents a popover explaining a feature's semantics —
/// the shared version of the info affordance already used in Corpus Analytics and the
/// Cross-Reference Graph, so Source Explorer, the Word Cloud, and Chronology can offer
/// the same help. Place inside a `ToolbarItem`.
///
/// Version history:
///   1.0 — Session 169: shared feature info popover
struct FeatureInfoButton: View {
    /// Popover heading and the button's accessibility label / tooltip.
    let heading: String
    /// The titled explanation rows.
    let items: [FeatureInfoItem]

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "info.circle")
                .accessibilityLabel(heading)
        }
        .help(heading)
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 12) {
                Text(heading).font(.headline)
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(16)
            .frame(width: 360)
        }
    }

    /// The shared Source Explorer info button, identical on iOS and macOS so the
    /// dual-platform views stay in lockstep without duplicating the copy.
    static var sourceExplorer: FeatureInfoButton {
        FeatureInfoButton(
            heading: String(localized: "source.explorer.info.heading", defaultValue: "About Source Explorer"),
            items: [
                FeatureInfoItem(
                    title: String(localized: "source.explorer.info.shows.title", defaultValue: "What you're seeing"),
                    detail: String(localized: "source.explorer.info.shows.detail",
                                   defaultValue: "A structured breakdown of one document's source note — the State Department editors' record of where the document came from (archive, file, lot, telegram or despatch number) and how it was handled.")),
                FeatureInfoItem(
                    title: String(localized: "source.explorer.info.why.title", defaultValue: "Why it matters"),
                    detail: String(localized: "source.explorer.info.why.detail",
                                   defaultValue: "Source notes are your trail back to the original record. The parsed fields let you cite the document precisely and judge its provenance at a glance.")),
                FeatureInfoItem(
                    title: String(localized: "source.explorer.info.catalog.title", defaultValue: "Links to the National Archives"),
                    detail: String(localized: "source.explorer.info.catalog.detail",
                                   defaultValue: "Where a note resolves to a NARA series or file unit, the explorer links straight to the National Archives Catalog so you can locate the original record.")),
            ]
        )
    }
}

// MARK: - FRUSTheme

/// Cross-platform design token namespace for FRUS Explorer.
///
/// `FRUSTheme` is an uninhabited enum so it cannot be instantiated — all members
/// are static constants. Platform-conditional values (e.g. document padding) use
/// `#if os(macOS)` / `#else` so the correct value is baked in at compile time.
///
/// ## Usage
/// Reference tokens directly: `FRUSTheme.captionSize`, `FRUSTheme.tagCornerRadius`.
/// Shared UI components (`EditorialNoteBadge`, `FRUSTagChip`) are defined below
/// and use these tokens so visual updates propagate everywhere automatically.
///
/// Version history:
///   1.0 — Session 91: initial design token system + shared components
///   1.1 — Dynamic Type pass 2026-07-04: added scalable `captionFont` /
///         `captionSmallFont` text tokens + the size→text-style convention;
///         `EditorialNoteBadge` and `FRUSTagChip` now use scalable caption text.
enum FRUSTheme {

    // MARK: Typography

    static let captionSize: CGFloat = 11
    static let captionSmallSize: CGFloat = 10
    static let sectionLabelSize: CGFloat = 10
    static let sectionLabelWeight: Font.Weight = .medium
    static let sectionLabelKerning: CGFloat = 0.8

    // MARK: Dynamic Type — scalable text tokens
    //
    // ## Convention (Dynamic Type pass, 2026-07-04)
    //
    // Fixed `.font(.system(size: N))` does NOT respond to the user's Dynamic Type
    // setting, so any *text* using it is frozen at one size — a Severity-1 a11y gap
    // (UI-Audit §3 A1). The idiomatic fix is to map each fixed size to the nearest
    // built-in **text style**, which scales automatically. Use this table when
    // converting a `.system(size: N)` text site:
    //
    // | Fixed pt | Text style   | Typical use                                  |
    // |----------|--------------|----------------------------------------------|
    // | 10       | `.caption2`  | smallest captions, section-label glyphs      |
    // | 11–12    | `.caption`   | caption / metadata / badge text              |
    // | 13       | `.footnote`  | dense secondary text                         |
    // | 15       | `.subheadline` | secondary body                             |
    // | 17       | `.body`      | primary body text                            |
    // | 20       | `.title3`    | small headings                               |
    // | 28+      | `.largeTitle`| hero / empty-state glyphs (see below)        |
    //
    // For a *non-standard* size that must stay proportional to a specific style
    // (e.g. a hero glyph that should track the largest text but at a bespoke point
    // size), declare `@ScaledMetric(relativeTo: .largeTitle) private var glyph: CGFloat = N`
    // in the view and feed it to `.font(.system(size: glyph))`. Cap runaway growth
    // on decorative hero glyphs with `.dynamicTypeSize(...DynamicTypeSize.accessibility3)`.
    //
    // Do NOT convert: graph-canvas node/edge labels (they scale with graph zoom,
    // not Dynamic Type), the word cloud's bespoke `word.fontSize` system, and
    // monospaced count/tally badges that align in a grid.
    //
    // The two tokens below are the scalable equivalents of `captionSize` /
    // `captionSmallSize` for the caption text that used them. The CGFloat
    // constants above are retained for layout metrics and macOS chrome not yet
    // migrated; new *text* sites should prefer these `Font` tokens or a text style.

    /// Scalable equivalent of `captionSize` (11 pt) — maps to the `.caption`
    /// text style so caption text tracks the user's Dynamic Type setting.
    static let captionFont: Font = .caption

    /// Scalable equivalent of `captionSmallSize` / `sectionLabelSize` (10 pt) —
    /// maps to the `.caption2` text style for the smallest scalable caption text.
    static let captionSmallFont: Font = .caption2

    // MARK: Document Layout

    #if os(macOS)
    static let documentHorizontalPadding: CGFloat = 48
    static let documentTopPadding: CGFloat = 28
    #else
    static let documentHorizontalPadding: CGFloat = 16
    static let documentTopPadding: CGFloat = 16
    #endif
    static let sectionSpacing: CGFloat = 20

    /// Width of the invisible edge-tap zones used for ebook-reader-style
    /// previous/next document navigation in `DocumentView`'s Read mode.
    /// Narrow enough to sit outside the primary reading column — which begins
    /// at `documentHorizontalPadding` from each edge — so it rarely overlaps
    /// inline `<persName>`/`<gloss>`/cross-reference links in the document body.
    static let documentEdgeTapZoneWidth: CGFloat = 56

    // MARK: Tag Chips

    static let tagCornerRadius: CGFloat = 4
    static let tagPaddingH: CGFloat = 8
    static let tagPaddingV: CGFloat = 3
    static let tagChipSpacing: CGFloat = 6

    static let systemTagBackground  = Color.secondary.opacity(0.10)
    static let systemTagForeground  = Color.secondary
    static let systemTagBorderColor = Color.secondary.opacity(0.2)
    static let userTagBackground    = Color.accentColor.opacity(0.12)
    static let userTagForeground    = Color.accentColor
    static let userTagBorderColor   = Color.accentColor.opacity(0.3)

    // MARK: Semantic Colors

    static let editorialNoteBackground = Color.purple.opacity(0.12)
    static let editorialNoteForeground = Color.purple

    // MARK: Chrome

    static let stripHeight: CGFloat = 32
    static let statusBarHeight: CGFloat = 24

    // MARK: WebKit CSS bridge

    /// Returns a CSS `:root { }` block containing all custom properties consumed by
    /// `HTMLTemplate.documentCSS`.
    ///
    /// Called by `HTMLTemplate.build(model:colorScheme:textSize:)` whenever the model,
    /// system appearance, or user text-size preference changes. Because `WKWebView` is
    /// reloaded on each signature change, no JavaScript injection is required to update
    /// the theme at runtime — the full HTML string is rebuilt with the new variables.
    ///
    /// ## Color palette
    /// Colors are hardcoded RGBA values that match the iOS/macOS system appearance
    /// semantics for the given `colorScheme`. This avoids the complexity of resolving
    /// SwiftUI `Color` or `NSColor`/`UIColor` semantic colors through the platform
    /// appearance APIs, while producing visually identical results.
    ///
    /// ## Variable inventory
    /// | Variable                    | Usage                                      |
    /// |-----------------------------|--------------------------------------------|
    /// | `--color-primary`           | Body text                                  |
    /// | `--color-secondary`         | Dateline, secondary text, table borders    |
    /// | `--color-footnote-text`     | Visible footnote-list body text            |
    /// | `--color-accent`            | Links, footnote markers                    |
    /// | `--color-background`        | Page background, footnote popover bg       |
    /// | `--color-editorial-border`  | Left border of editorial note blocks       |
    /// | `--color-editorial-bg`      | Background tint of editorial note blocks   |
    /// | `--color-pers-name`         | Person name link color (teal)              |
    /// | `--color-table-border`      | Table cell borders and footnote outlines   |
    /// | `--font-size-body`          | Paragraph text; derived from `textSize`    |
    /// | `--font-size-heading`       | h2.doc-heading (≈ 1.28× body)             |
    /// | `--font-size-dateline`      | p.dateline (≈ 0.86× body)                 |
    /// | `--font-size-footnote`      | aside.footnote content (≈ 0.78× body)     |
    /// | `--font-family`             | System font stack                          |
    ///
    /// - Parameters:
    ///   - colorScheme: `.light` or `.dark` from the SwiftUI environment.
    ///   - textSize:    The user's body-text size preference. Defaults to `.medium`.
    static func cssVariables(
        colorScheme: ColorScheme,
        textSize: TextSizePreference = .medium
    ) -> String {
        let dark = colorScheme == .dark

        // ── Colors ────────────────────────────────────────────────────────────
        let primary            = dark ? "rgba(255,255,255,0.88)" : "rgba(0,0,0,0.85)"
        let secondary          = dark ? "rgba(255,255,255,0.52)" : "rgba(0,0,0,0.50)"
        // Footnote body text is small (≈0.785× body), so it needs more contrast
        // than ordinary secondary text to stay legible — most noticeably in dark
        // mode, where 52% white at footnote size is hard to read.
        let footnoteText       = dark ? "rgba(255,255,255,0.78)"  : "rgba(0,0,0,0.68)"
        // System blue, brightened in dark mode to Apple's dark-appearance
        // systemBlue. The light value sits at ~4.2:1 on the dark page background —
        // under WCAG AA — which is most noticeable on the tiny footnote markers
        // and gloss/cross-ref links that all draw in this color.
        let accent             = dark ? "rgb(10,132,255)" : "rgb(0,122,255)"
        let background         = dark ? "rgb(28,28,30)"           : "rgb(255,255,255)"
        let editorialBorder    = dark ? "rgba(160,120,230,0.60)"  : "rgba(140,0,140,0.50)"
        let editorialBg        = dark ? "rgba(160,120,230,0.12)"  : "rgba(128,0,128,0.07)"
        let persName           = "rgb(0,150,136)"                  // teal (both modes)
        let tableBorder        = dark ? "rgba(255,255,255,0.20)"  : "rgba(0,0,0,0.18)"

        // ── Typography ────────────────────────────────────────────────────────
        let bodyPt    = textSize.bodyFontSize          // e.g. 14.0
        let headingPt = (bodyPt * 1.28).rounded()      // e.g. 18.0
        let datePt    = (bodyPt * 0.857).rounded()     // e.g. 12.0
        let footPt    = (bodyPt * 0.785).rounded()     // e.g. 11.0
        let fontStack = "-apple-system, 'Helvetica Neue', Helvetica, Arial, sans-serif"

        func px(_ v: Double) -> String { "\(Int(v))px" }

        return """
        :root {
          --color-primary:           \(primary);
          --color-secondary:         \(secondary);
          --color-footnote-text:     \(footnoteText);
          --color-accent:            \(accent);
          --color-background:        \(background);
          --color-editorial-border:  \(editorialBorder);
          --color-editorial-bg:      \(editorialBg);
          --color-pers-name:         \(persName);
          --color-table-border:      \(tableBorder);
          --font-size-body:          \(px(bodyPt));
          --font-size-heading:       \(px(headingPt));
          --font-size-dateline:      \(px(datePt));
          --font-size-footnote:      \(px(footPt));
          --font-family:             \(fontStack);
        }
        """
    }
}

// MARK: - EditorialNoteBadge

/// Inline badge marking editorial notes in the document identity line.
///
/// Shared across macOS and iOS. Previously a `private struct` inside
/// `MacDocumentView` (macOS-only); extracted here so iOS document views
/// can render it without duplicating the style.
struct EditorialNoteBadge: View {
    var body: some View {
        Text(String(localized: "badge.editorialNote", defaultValue: "Editorial note"))
            .font(FRUSTheme.captionSmallFont.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(FRUSTheme.editorialNoteBackground)
            .foregroundStyle(FRUSTheme.editorialNoteForeground)
            .clipShape(RoundedRectangle(cornerRadius: FRUSTheme.tagCornerRadius))
    }
}

// MARK: - FRUSTagChip

/// System and user tag chip for document tag rows.
///
/// Two visual styles:
/// - `.system`: secondary tint — subject taxonomy tags assigned by the search index
/// - `.user`: accent tint   — tags created by the researcher
///
/// Note: iOS `DocumentTagChip` (in `DocumentView.swift`) uses a Capsule shape and
/// category-based colors — intentionally different from this chip, which targets the
/// compact tag row on macOS and iPad.
struct FRUSTagChip: View {
    enum Style { case system, user }
    let label: String
    let style: Style
    /// When non-nil, an × button appears inside the chip that calls this closure.
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(FRUSTheme.captionFont)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(FRUSTheme.captionSmallFont.weight(.semibold))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, FRUSTheme.tagPaddingH)
        .padding(.vertical, FRUSTheme.tagPaddingV)
        .background(style == .user ? FRUSTheme.userTagBackground : FRUSTheme.systemTagBackground)
        .foregroundStyle(style == .user ? FRUSTheme.userTagForeground : FRUSTheme.systemTagForeground)
        .clipShape(RoundedRectangle(cornerRadius: FRUSTheme.tagCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FRUSTheme.tagCornerRadius)
                .strokeBorder(
                    style == .user ? FRUSTheme.userTagBorderColor : FRUSTheme.systemTagBorderColor,
                    lineWidth: 0.5
                )
        )
    }
}
