// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

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
/// the shared info affordance used across the analytics views (Corpus, Person,
/// Cross-Reference), Source Explorer, the Word Cloud, and Chronology. Place inside a
/// `ToolbarItem`.
///
/// Version history:
///   1.0 — Session 169: shared feature info popover
///   1.1 — Analytics Wave C (Win 7): added `corpusAnalytics` (replacing Corpus's
///         hand-rolled popover, copy preserved verbatim), `personAnalytics`, and
///         `crossReferenceAnalytics` factories so all three analytics views share one
///         info affordance.
///   1.2 — Owner content revision (build 35): `personAnalytics` notes that the ranking
///         covers editor-tagged people and that pre-WWII volumes carry no person
///         tagging; `crossReferenceAnalytics` notes that scoping to a subseries or an
///         administration carries a more consistent signal than a corpus-wide scope.
///   1.3 — Generic `Footer` slot (owner decision, #279 follow-up): a caller may append a
///         view below the explanation rows — the Research rail puts the classification
///         override control there. Every existing caller keeps its shape through the
///         `Footer == EmptyView` convenience init, where the static factories now live
///         (a static member of the generic type could not name a concrete Self).
struct FeatureInfoButton<Footer: View>: View {
    /// Popover heading and the button's accessibility label.
    let heading: String
    /// Optional richer pointer tooltip (macOS `.help`). Defaults to `heading` when nil, so most
    /// callers need not set it; a caller with a more descriptive one-liner (e.g. Corpus Analytics'
    /// "What do the numbers mean? …") passes it to preserve that hover text.
    var helpText: String?
    /// The titled explanation rows.
    let items: [FeatureInfoItem]
    /// Content appended below the rows — `EmptyView` for the plain info popover.
    let footer: Footer

    @State private var isPresented = false

    init(heading: String, helpText: String? = nil, items: [FeatureInfoItem],
         @ViewBuilder footer: () -> Footer) {
        self.heading = heading
        self.helpText = helpText
        self.items = items
        self.footer = footer()
    }

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "info.circle")
                .accessibilityLabel(heading)
        }
        .help(helpText ?? heading)
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
                footer
            }
            .padding(16)
            .frame(width: 360)
        }
    }

}

extension FeatureInfoButton where Footer == EmptyView {

    /// The footer-less shape every pre-1.3 caller uses.
    init(heading: String, helpText: String? = nil, items: [FeatureInfoItem]) {
        self.init(heading: heading, helpText: helpText, items: items) { EmptyView() }
    }

    /// The shared Source Explorer info button, identical on iOS and macOS so the
    /// dual-platform views stay in lockstep without duplicating the copy.
    static var sourceExplorer: FeatureInfoButton {
        FeatureInfoButton(
            heading: String(localized: "source.explorer.info.heading", defaultValue: "About Source Explorer"),
            items: [
                FeatureInfoItem(
                    title: String(localized: "source.explorer.info.shows.title", defaultValue: "What you’re seeing"),
                    detail: String(localized: "source.explorer.info.shows.detail",
                                   defaultValue: "A structured breakdown of one document’s source note — the State Department editors’ record of where the document came from (archive, file, lot, telegram or despatch number) and how it was handled.")),
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

    /// The Corpus Analytics info button — the shared replacement for that view's former
    /// hand-rolled popover. The heading and the five explanation rows reuse the original
    /// `analytics.info.*` keys and copy verbatim, so the shipped text (and String Catalog
    /// entries) are unchanged.
    static var corpusAnalytics: FeatureInfoButton {
        FeatureInfoButton(
            heading: String(localized: "analytics.info.heading", defaultValue: "About these results"),
            helpText: String(localized: "analytics.info.help",
                             defaultValue: "What do the numbers mean? Multi-word handling, phrases, stemming, and how dates are determined."),
            items: [
                FeatureInfoItem(
                    title: String(localized: "analytics.info.metric.title", defaultValue: "What the numbers mean"),
                    detail: String(localized: "analytics.info.metric.body",
                                   defaultValue: "Each bar shows the number of indexed FRUS documents that contain your search term in that period. A document that mentions the term ten times is counted once.")),
                FeatureInfoItem(
                    title: String(localized: "analytics.info.multiword.title", defaultValue: "Multiple words"),
                    detail: String(localized: "analytics.info.multiword.body",
                                   defaultValue: "Words separated by spaces are combined with AND. So national security matches documents containing both words. OR finds either term. NOT, or a leading -, excludes a term. All of this works exactly as it does in the Search box.")),
                FeatureInfoItem(
                    title: String(localized: "analytics.info.phrase.title", defaultValue: "Phrases"),
                    detail: String(localized: "analytics.info.phrase.body",
                                   defaultValue: "Wrap words in quotes for an ordered phrase. “missile crisis” matches only documents where those two words appear together, in that order. Analytics and Search read a query the same way, so the counts here match what Search returns.")),
                FeatureInfoItem(
                    title: String(localized: "analytics.info.stemming.title", defaultValue: "Stemming"),
                    detail: String(localized: "analytics.info.stemming.body",
                                   defaultValue: "English stemming is applied: searching for “negotiate” also matches “negotiating”, “negotiated”, and “negotiations”.")),
                FeatureInfoItem(
                    title: String(localized: "analytics.info.dating.title", defaultValue: "How dates are determined"),
                    detail: String(localized: "analytics.info.dating.body",
                                   defaultValue: "Each document sits at its TEI <date> attribute, the date it was written, not the volume’s publication date. A document with no stored date falls back to the start year of its volume, in both the counts and the % denominator. A document with no month is left out of the By Month chart. One with no day is left out of By Day.")),
            ]
        )
    }

    /// The Person Analytics info button — explains what the Trends and Network modes show
    /// and how mentions are counted and merged. (Copy drafted in Wave C; pending owner review.)
    static var personAnalytics: FeatureInfoButton {
        FeatureInfoButton(
            heading: String(localized: "personAnalytics.info.heading", defaultValue: "About Person Analytics"),
            items: [
                FeatureInfoItem(
                    title: String(localized: "personAnalytics.info.shows.title", defaultValue: "What you’re seeing"),
                    detail: String(localized: "personAnalytics.info.shows.detail",
                                   defaultValue: "Trends ranks the people most mentioned in an era, as tagged by FRUS editors. It also charts how often one person is mentioned across FRUS documents over time. Network maps who is named alongside whom in the same documents. Volumes covering the years before World War II carry no editorial tagging of people, so they fall outside both tools.")),
                FeatureInfoItem(
                    title: String(localized: "personAnalytics.info.counting.title", defaultValue: "How people are counted"),
                    detail: String(localized: "personAnalytics.info.counting.detail",
                                   defaultValue: "Counts are mentions of a person across the documents you have indexed. The app’s person authority groups them, so spelling variants, honorifics, and different name forms for one individual merge into a single identity instead of splitting into several.")),
                FeatureInfoItem(
                    title: String(localized: "personAnalytics.info.compare.title", defaultValue: "Comparing people"),
                    detail: String(localized: "personAnalytics.info.compare.detail",
                                   defaultValue: "Tap a ranking bar, or use “Add a person to compare”, to plot several people’s mention trajectories on one chart — each colored line is one person. Remove a person with the ✕ on its chip.")),
            ]
        )
    }

    /// The Archival Analytics info button — explains what the modes count, why the three
    /// weights disagree, and why one record is hidden by default.
    ///
    /// Documents and Volumes measure where documents were drawn FROM; Unprinted pointers measures
    /// where readers were SENT, and is never added to the other two.
    static var archivalAnalytics: FeatureInfoButton {
        FeatureInfoButton(
            heading: String(localized: "archival.info.heading", defaultValue: "About These Figures"),
            items: [
                FeatureInfoItem(
                    title: String(localized: "archival.info.shows.title", defaultValue: "What you’re seeing"),
                    detail: String(localized: "archival.info.shows.detail.v2",
                                   defaultValue: "Where the editors of Foreign Relations of the United States found the documents they published. Collections ranks the archival collections and central-file numbers each era’s volumes drew on. Network puts one collection at the center and groups everything cited alongside it by custodian. Flows maps where an editor’s cross-reference led when it pointed from one document to another. Your Library counts the same things in the volumes you have indexed.")),
                FeatureInfoItem(
                    title: String(localized: "archival.info.method.title",
                                  defaultValue: "Where the figures come from"),
                    detail: String(localized: "archival.info.method.detail",
                                   defaultValue: "They are parsed from the source note on each published document, not read from an archive’s catalog. So they say where the editors drew documents from — an editorial and archival signal, not a census of what the archives hold. Coverage is uneven by era, and switching what the chart shows is the way through it: named collections are scarce before 1948, where central-file numbers carry almost the whole record, and those numbers all but disappear after 1976, where the presidential libraries carry it. Collections are grouped across volumes by name, so when two spellings of one name fail to merge, the same body of records can appear twice under nearby names.")),
                FeatureInfoItem(
                    title: String(localized: "archival.info.weights.title.v2", defaultValue: "The three counts measure different things"),
                    detail: String(localized: "archival.info.weights.detail.v2",
                                   defaultValue: "Documents counts how many published documents came out of a collection. Volumes counts how many volumes drew on it at all. Unprinted pointers counts something else entirely: footnotes pointing at material there that FRUS did not print. The first two measure where documents were drawn from; the third measures where readers were sent. They are never added together. Switching the count changes the order and, especially for unprinted pointers, changes which collections appear at all — a thousand collections that supplied documents have no pointers, and a hundred and eighty-one collections appear only under pointers, having supplied no printed document. A collection named only in a volume’s front matter has volumes but no documents.")),
                FeatureInfoItem(
                    title: String(localized: "archival.info.umbrella.title", defaultValue: "Why Central Files is hidden"),
                    detail: String(localized: "archival.info.umbrella.detail",
                                   defaultValue: "The State Department’s Central Files are cited by 157 volumes and supply more than seventeen thousand documents. That is over twice the next-largest collection, and its bar would flatten every other one. So it is hidden by default, and the chart states what it withheld. Turn the chip off to see it. The era-specific Central Files records are never hidden.")),
                FeatureInfoItem(
                    title: String(localized: "archival.info.flows.title", defaultValue: "A flow is an editor’s footnote, not an archive’s"),
                    // R-3: the "N of M volumes" sentence is gone from here. It duplicated, with
                    // hardcoded numbers, the LIVE line the Flows chart prints from
                    // `ArchivalFlowsData.volumesWithEdges` / `volumesScanned` — which is exactly
                    // the split #838 made: a `FeatureInfoItem` is a static string and cannot hold
                    // a live value, so the why stays here and the how-many stays on the chart.
                    detail: String(localized: "archival.info.flows.detail.v2",
                                   defaultValue: "About 95% of the references behind Flows are footnotes. A ribbon means the editors annotated material from one collection and sent you to material from another. It does not mean the two archives cite each other. Coverage is uneven, and that is itself a finding: the cross-reference style these come from postdates 1945, so most volumes carry none, and the chart states how many do.")),
                // #838(1): the STATIC half of the Flows caveats, moved off the page. The
                // sentences that carry live values — the citation counts, the era span, the Ibid.
                // and footnote shares, the coverage counts — stay on the chart as conditional
                // disclosures, because a `FeatureInfoItem` is a static string and cannot hold
                // them. That split is the Collections precedent from this same issue, not a new
                // rule: the intro and footer moved, the computed lines stayed.
                FeatureInfoItem(
                    title: String(localized: "archival.info.flows.scope.title",
                                  defaultValue: "What Flows reads, and what it does not"),
                    detail: String(localized: "archival.info.flows.scope.detail",
                                   defaultValue: "This layer reads three kinds of citation: State Department lot files, collections in the presidential libraries, and central-file numbers such as 763.72/10417. The first two are ways of filing that came in after 1945; the third is how the earlier volumes cite, which is why they were nearly absent here until it was added.\n\nMost central-file citations point at the citing document’s own file rather than somewhere else — about three in five, and closer to three in four before 1946. Those are counted where a class is ranked, because the class was still cited, but they are not drawn as movement between archives. A count of central-file citations is therefore roughly three times the number of pointers that actually lead somewhere new.")),
                FeatureInfoItem(
                    title: String(localized: "archival.info.flows.ibid.title",
                                  defaultValue: "An “Ibid.” is followed, which is a reading"),
                    detail: String(localized: "archival.info.flows.ibid.detail",
                                   defaultValue: "Some of these citations come from an “Ibid.” — the editor wrote the archive out once and then referred back to it. The app follows that back the way a reader would, but it is a reading, not a quotation. The share it accounts for is stated on the chart.")),
                FeatureInfoItem(
                    title: String(localized: "archival.info.flows.mixed.title",
                                  defaultValue: "Citations that cross filing systems are counted in neither diagram"),
                    detail: String(localized: "archival.info.flows.mixed.detail",
                                   defaultValue: "Some footnotes cross between the two filing systems — a document filed in a lot file or a presidential library pointing to a central-file number, or the reverse. There are about 1,900 of these across the series, and they are not spread evenly: a third of them come from two situations, the 1945 Potsdam volumes moving between Truman’s presidential file and the wartime file, and one 1952–54 conference volume moving between its lot file and its conference file. They are counted in neither diagram.")),
                FeatureInfoItem(
                    title: String(localized: "archival.info.flows.browse.title",
                                  defaultValue: "You cannot browse these citations"),
                    detail: String(localized: "archival.info.flows.browse.detail",
                                   defaultValue: "The app can list the references inside the volumes you have indexed. It cannot tell which of those are the footnotes this measure is built on. A list would therefore disagree with the diagram above it, and nothing on screen would explain why.")),
                // #838(2): Your Library's rule, moved off the page. The two counts it used to
                // carry stay on the chart — they are measurements of the reader's own library.
                FeatureInfoItem(
                    title: String(localized: "archival.info.library.title",
                                  defaultValue: "A source note is not a document"),
                    detail: String(localized: "archival.info.library.detail",
                                   defaultValue: "Only documents whose editors recorded where the original was found appear in Your Library. So its total is smaller than your indexed document count, and volumes with no source notes add nothing. The collections list matches each citation to a named body of records; notes citing the central files are a filing system rather than a collection and are counted in the composition instead. Your Library counts only what you have indexed — Collections does not, and does not change with your downloads.")),
                FeatureInfoItem(
                    title: String(localized: "archival.info.units.title", defaultValue: "Collections and classes are different things"),
                    detail: String(localized: "archival.info.units.detail",
                                   defaultValue: "A named collection is a body of records with a custodian. A central-file class is a subject heading inside one filing system — 763.72 for the European War, POL 27 VIET S for the war in South Vietnam. The two are never mixed in one ranking. Classes are ranked at one depth: a decimal file number stands for itself, while subject-numeric designators are grouped to their category and number, and a grouped row opens to the exact designators underneath it. Before 1948 the series cites classes far more than collections. After 1976 it barely cites classes at all.")),
            ]
        )
    }

    /// The Cross-Reference Analytics info button — explains the ranking, the volume citation
    /// heat matrix, and the PageRank influence score. (Copy drafted in Wave C; pending owner review.)
    static var crossReferenceAnalytics: FeatureInfoButton {
        FeatureInfoButton(
            heading: String(localized: "crossRefAnalytics.info.heading", defaultValue: "About Cross-Reference Analytics"),
            items: [
                FeatureInfoItem(
                    title: String(localized: "crossRefAnalytics.info.shows.title", defaultValue: "What you’re seeing"),
                    detail: String(localized: "crossRefAnalytics.info.shows.detail",
                                   defaultValue: "How FRUS documents cite one another. The ranking lists the most-referenced documents. The heat matrix shows citation flow between whole volumes. Landmarks are the documents a reader following citations keeps returning to. FRUS cross-referencing practice has changed over the life of the series. A subseries or a single administration therefore gives a more consistent signal than a broader scope that mixes several editorial practices.")),
                FeatureInfoItem(
                    title: String(localized: "crossRefAnalytics.info.matrix.title", defaultValue: "Reading the heat matrix"),
                    detail: String(localized: "crossRefAnalytics.info.matrix.detail",
                                   defaultValue: "Rows cite columns. A darker cell means the row’s volume cites the column’s volume more often. Column labels are a short code of the volume’s years and number, such as ’55–57 II. Hover over a label, or use VoiceOver, for the full title on either axis.")),
                FeatureInfoItem(
                    title: String(localized: "crossRefAnalytics.info.influence.title", defaultValue: "About the influence score"),
                    detail: String(localized: "crossRefAnalytics.info.influence.detail",
                                   defaultValue: "Landmark documents are ranked by PageRank, computed on this device over the citations the app resolved. It measures how often a document is cited by other much-cited documents. It is not a claim of historical importance.")),
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
///   1.2 — Dynamic Type review 2026-07-04: added `cappedGlyphSize(_:base:)` to
///         cap `@ScaledMetric` hero glyphs in code (the prior `.dynamicTypeSize`
///         cap was inert against a `.system(size:)` font).
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
    // **macOS chrome uses a DIFFERENT column (Mac W-11).** The table above targets iOS text
    // styles (`.body` = 17). macOS resolves the same styles smaller (`.body` = 13,
    // `.callout` = 12, `.subheadline` = 11, `.footnote`/`.caption`/`.caption2` = 10), so
    // applying the iOS column to a Mac window shrinks its chrome by 1–3 pt across the board.
    // For `#if os(macOS)` surfaces convert by the macOS defaults instead — the point is to
    // PRESERVE today's size at the default setting and gain scaling, not to reflow the window:
    //
    // | Fixed pt | macOS style    | resolves to |
    // | 7–10     | `.caption2`    | 10 (a 7–9 pt site gains a point or three — deliberate;
    // |          |                |     the review called 9 pt micro-labels a defect)
    // | 11       | `.subheadline` | 11          |
    // | 12       | `.callout`     | 12          |
    // | 13       | `.body`        | 13          |
    // | 14–15    | `.title3`      | 15          |
    //
    // For a *non-standard* size that must stay proportional to a specific style
    // (e.g. a hero glyph that should track the largest text but at a bespoke point
    // size), declare `@ScaledMetric(relativeTo: .largeTitle) private var glyph: CGFloat = N`
    // in the view and feed it to `.font(.system(size: glyph))`. Cap runaway growth
    // on decorative hero glyphs by clamping the scaled value with
    // `FRUSTheme.cappedGlyphSize(glyph, base: N)`.
    //
    // NOTE — why clamp in code, not `.dynamicTypeSize(...):` A `.dynamicTypeSize`
    // modifier applied to an `Image(systemName:).font(.system(size: scaled))` is
    // *inert* for the glyph size: `@ScaledMetric` resolves its `CGFloat` from the
    // environment where the property wrapper is installed (the parent's ambient,
    // uncapped `dynamicTypeSize`), and `.system(size:)` is a *fixed*-size font that
    // ignores the downstream environment the modifier changes. The clamp below
    // caps the resolved point value directly, so it actually holds at every size.
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

    /// Ceiling multiple applied to a `@ScaledMetric` hero-glyph base size to cap
    /// runaway growth at extreme Dynamic Type sizes. `1.6` keeps decorative glyphs
    /// growing with accessibility sizes (so they still track larger text) while
    /// holding them near the accessibility-large tier instead of the ~1.9× that the
    /// largest accessibility categories would otherwise produce.
    static let heroGlyphMaxScale: CGFloat = 1.6

    /// Clamps a `@ScaledMetric`-resolved hero/empty-state glyph point size to a
    /// proportional ceiling, so decorative glyphs scale with Dynamic Type but do
    /// not grow without bound at the largest accessibility categories.
    ///
    /// Use this instead of a `.dynamicTypeSize(...)` modifier on the glyph: that
    /// modifier is inert for a `.system(size:)` font (see the convention note
    /// above). This caps the resolved value directly.
    ///
    /// - Parameters:
    ///   - scaled: The `@ScaledMetric` point size resolved from the environment.
    ///   - base: The unscaled base point size the `@ScaledMetric` was declared with.
    ///   - maxScale: Ceiling as a multiple of `base`. Defaults to ``heroGlyphMaxScale``.
    /// - Returns: `min(scaled, base * maxScale)`.
    static func cappedGlyphSize(
        _ scaled: CGFloat,
        base: CGFloat,
        maxScale: CGFloat = heroGlyphMaxScale
    ) -> CGFloat {
        min(scaled, base * maxScale)
    }

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
    ///
    /// ## 56pt is a RATIFIED value, and the overlap it does NOT address is named here
    /// The audit finding #751/M-17b observed that the LEADING zone occupies the same region where
    /// the system back-swipe begins, so an imprecise swipe-back could open the previous document
    /// instead of going back. **This width does not address that and was never tuned for it** — the
    /// rationale above is about the reading COLUMN and WKWebView hit-testing, a different overlap
    /// entirely. Anyone reading that paragraph as a mitigation for the back-swipe is misreading it.
    ///
    /// #751 was closed on 2026-08-20 with M-17b **accepted rather than fixed**, by owner decision,
    /// on this evidence: a device check that day found a deliberate back-swipe still returns to the
    /// volume, so the tap zone does not steal a real swipe. That is one trial by someone who knew
    /// where the zones were, and it does NOT cover the imprecise swipe the finding describes —
    /// stated plainly so the decision is not mistaken for a measurement.
    ///
    /// **Do not narrow this on intuition.** Narrowing trades a measured benefit (the zones sit
    /// outside the reading column, which is why in-column links still receive taps) for an
    /// unmeasured one. Two things must exist first: a reproduction, and a reader who did not know
    /// the zone was there. The escape hatch already shipped —
    /// `SettingsKeys.edgeTapNavigationEnabled`, added in Session 154 because a touch zone at the
    /// screen edge was observed to misfire while scrolling.
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

    /// Accent-tinted fill/text for the compact override chips on collection document rows
    /// (Composer redesign 3): a labeled pill (e.g. "Summary", "7 notes", "Headnote") that reports
    /// a document's resolved export configuration at a glance. Replaces the earlier grey capsule.
    static let overrideChipBackground = Color.accentColor.opacity(0.12)
    static let overrideChipForeground = Color.accentColor

    // MARK: Semantic Colors

    static let editorialNoteBackground = Color.purple.opacity(0.12)
    static let editorialNoteForeground = Color.purple

    // MARK: Headnote / editorial accent (Composer v2)

    /// A scheme-adaptive `Color` from explicit light/dark sRGB hex values with optional
    /// per-scheme opacity. SwiftUI has no cross-platform light/dark `Color` initializer, so this
    /// bridges through the platform's dynamic `UIColor`/`NSColor` provider (Composer v2).
    static func adaptiveColor(lightHex: UInt, darkHex: UInt,
                              lightOpacity: Double = 1, darkOpacity: Double = 1) -> Color {
        func rgb(_ hex: UInt) -> (Double, Double, Double) {
            (Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255)
        }
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            let dark = traits.userInterfaceStyle == .dark
            let (r, g, b) = rgb(dark ? darkHex : lightHex)
            return UIColor(red: r, green: g, blue: b, alpha: dark ? darkOpacity : lightOpacity)
        })
        #elseif canImport(AppKit)
        return Color(nsColor: NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let (r, g, b) = rgb(dark ? darkHex : lightHex)
            return NSColor(srgbRed: r, green: g, blue: b, alpha: dark ? darkOpacity : lightOpacity)
        })
        #else
        let (r, g, b) = rgb(lightHex)
        return Color(.sRGB, red: r, green: g, blue: b, opacity: lightOpacity)
        #endif
    }

    /// The bespoke "key takeaway" headnote purple — a scheme-aware pair (light `#8A6FD6` /
    /// dark `#A78BFA`) so the editable headnote card and the exported headnote band read as
    /// their own editorial accent rather than the app's link-blue (Composer v2).
    static let headnotePurple = adaptiveColor(lightHex: 0x8A6FD6, darkHex: 0xA78BFA)
    /// Soft fill behind the headnote card / preview band (`.07` light, `.14` dark).
    static let headnotePurpleFill = adaptiveColor(lightHex: 0x8A6FD6, darkHex: 0xA78BFA,
                                                  lightOpacity: 0.07, darkOpacity: 0.14)
    /// Hairline border for the headnote card / preview band.
    static let headnotePurpleBorder = adaptiveColor(lightHex: 0x8A6FD6, darkHex: 0xA78BFA,
                                                     lightOpacity: 0.30, darkOpacity: 0.42)

    // MARK: - Provenance tiers (wave PV)

    /// Tier 1 — read from the FRUS volumes and nothing else.
    ///
    /// **`#A61C2A` is the app icon's own dominant field**, sampled from `AppIcon-256.png`, which
    /// runs `#A61C2A`–`#AE1E2D` over a paper-white ground: the series' binding red. This does not
    /// introduce a brand colour, it extends inward the one the icon already asserts.
    ///
    /// **The dark twin is a rose, and it has to be.** `#A61C2A` on the dark grouped background
    /// measures **2.29:1** — below even the 3:1 minimum for a UI component, let alone 4.5:1 for
    /// text. `#E8798A` measures 6.10:1. The binding colour cannot cross into dark mode, and
    /// `headnotePurple` already accepts the same trade.
    static let provenanceFRUS = adaptiveColor(lightHex: 0xA61C2A, darkHex: 0xE8798A)
    /// Tier 2 — the volumes joined to another body of data. 7.09:1 light, 6.97:1 dark.
    static let provenanceJoined = adaptiveColor(lightHex: 0x3B4E8C, darkHex: 0x8FA5DE)
    /// Tier 3 — computed here by a model or a scoring rule. 6.74:1 light, 7.54:1 dark.
    static let provenanceComputed = adaptiveColor(lightHex: 0x4A5568, darkHex: 0xA0AEC0)

    /// The tinted fill behind a provenance chip, and the border that makes it legible without it.
    ///
    /// **The fill is a whisper and the border is why that is acceptable.** Measured, a 12% tint of
    /// the ruby sits at 1.23:1 against the page — what a reader perceives is the chip's *text*,
    /// not its wash. The hairline carries the edge, exactly as `headnotePurpleBorder` does for the
    /// headnote card, so the chip reads as an object rather than a faint stain.
    static func provenanceFill(_ tint: Color) -> Color { tint.opacity(0.12) }
    /// Hairline border for a provenance chip.
    static func provenanceBorder(_ tint: Color) -> Color { tint.opacity(0.32) }

    // MARK: - Cloud surfaces — backdrop, splash, indexing strip, pending backdrop, semantic map

    // These constants were written for the onboarding backdrop (O-2) and the header still said so
    // while they served five surfaces across four host features in three directories. The dangling
    // `// MARK: Chrome` above it had no body at all — renaming one and leaving the other would have
    // left a second wrong header behind the corrected one.

    /// How long each lens holds before the backdrop crossfades to the next.
    ///
    /// **A constant, not a setting — owner decision 2026-07-27 (O-2-1).** The design
    /// hand-off calls the cadence "design-tweakable", meaning tweakable by whoever is
    /// designing it, not by the reader; and the Word Cloud settings pane already carries
    /// controls a user could easily confuse this with. Tune it here.
    static let cloudLensCadence: TimeInterval = 4.2

    /// Vertical squash applied to the backdrop's spiral, making the field elliptical rather
    /// than round so it fills a full-bleed screen instead of pooling in the middle.
    static let cloudYCompression: CGFloat = 0.62

    /// Count → point-size curve for the backdrop. Steeper than the Word Cloud's square
    /// root, so a few head terms dominate and the tail recedes into texture.
    static let cloudSizeExponent: CGFloat = 1.45

    /// Word opacity multiplier per surface, from the hand-off. The splash carries the cloud
    /// at full strength; the onboarding steps dim it so docked glass stays legible over it.
    static let cloudDimSplash: Double = 1.0
    /// Dim factor for the Welcome and Ready steps.
    static let cloudDimDocked: Double = 0.68
    /// Dim factor for Add Volumes, whose dock is taller and denser.
    static let cloudDimAddVolumes: Double = 0.62

    /// Dim factor for the indexing banner strip.
    ///
    /// Quieter than every other surface: this one sits directly behind live progress text
    /// in a short band, and a backdrop that makes a progress read harder has failed at
    /// being a backdrop.
    static let cloudDimIndexingStrip: Double = 0.42

    /// Word opacity behind an empty surface that is waiting — the search pending state.
    ///
    /// Between the docked value and the indexing strip's. There is no live progress text to
    /// stay legible under, as on the strip, but a spinner and (on iOS) a navigation bar sit
    /// over it, and the words must not compete with them for attention: the surface is a
    /// wait, not a display.
    static let cloudDimPendingSurface: Double = 0.5

    /// Words above this normalised weight take the lens accent; the rest take ink.
    static let cloudAccentThreshold: Double = 0.66

    /// Crossfade timings, in seconds (hand-off §"Lens cycle").
    static let cloudFadeOutDuration: Double = 0.95
    /// Duration of the incoming words' scale/position settle.
    ///
    /// **The app's one figure for "this surface is changing what it is showing you."** Shared by
    /// both cloud renderers by explicit design, and by the semantic map's lens dip since the
    /// visual-marketing pass — see ``semanticLensDipDuration``, which is an alias and not a second
    /// number. Do not introduce another.
    static let cloudTransformDuration: Double = 1.15

    /// The semantic map's lens dip, in seconds.
    ///
    /// An ALIAS for ``cloudTransformDuration``, so a `Semantic/` file can name it without reading
    /// as a borrow from the onboarding backdrop, and so the two can never drift into two figures
    /// for one idea. A lens swap is exactly what that constant means: the surface is changing what
    /// it is showing you, while showing you the same documents.
    static var semanticLensDipDuration: Double { cloudTransformDuration }
    /// Per-word delay multiplier for outgoing words.
    static let cloudStaggerOut: Double = 0.014
    /// Per-word delay multiplier for incoming words.
    static let cloudStaggerIn: Double = 0.038

    /// The accent colour for a lens, used by the backdrop's chip and its loudest words.
    ///
    /// Hex values are the hand-off's: Concepts `#4F5BD5`, Topics `#0E7C86`,
    /// Actions `#B25A00`, Sentiment `#6B7280` (chip only — sentiment words colour by
    /// polarity instead).
    static func cloudAccent(for lens: WordCloudLens) -> Color {
        switch lens {
        case .concepts:  return Color(red: 0.310, green: 0.357, blue: 0.835)
        case .topics:    return Color(red: 0.055, green: 0.486, blue: 0.525)
        case .actions:   return Color(red: 0.698, green: 0.353, blue: 0.000)
        case .sentiment: return Color(red: 0.420, green: 0.447, blue: 0.502)
        default:         return .accentColor
        }
    }

    /// Positive-polarity sentiment word colour (`#33804B`).
    static let cloudSentimentPositive = Color(red: 0.200, green: 0.502, blue: 0.294)
    /// Negative-polarity sentiment word colour (`#BC4740`).
    static let cloudSentimentNegative = Color(red: 0.737, green: 0.278, blue: 0.251)

    // MARK: - Onboarding docked glass (O-4)

    /// Corner radius of the onboarding dock.
    ///
    /// The hand-off's blur/saturate/ring/shadow values are **not** reproduced: they are CSS
    /// approximations of a material the OS provides, and the deployment target is 26.0, so
    /// the dock uses `.glassEffect` and inherits the real thing — including its behaviour
    /// under Reduce Transparency, which a hand-rolled stack would have to reimplement.
    /// Geometry the OS does not decide still lives here.
    #if os(macOS)
    static let onboardingDockRadius: CGFloat = 18
    /// Corner radius of the transient scope sheet floating above the dock.
    static let onboardingSheetRadius: CGFloat = 16
    /// Margin from the dock to the window edge.
    static let onboardingDockMargin: CGFloat = 16
    #else
    static let onboardingDockRadius: CGFloat = 26
    /// Corner radius of the transient scope sheet floating above the dock.
    static let onboardingSheetRadius: CGFloat = 22
    /// Margin from the dock to the screen edge.
    static let onboardingDockMargin: CGFloat = 16
    #endif

    /// Gap between the transient sheet and the dock it floats above.
    static let onboardingSheetGap: CGFloat = 10

    /// Widest the onboarding dock stack may grow (UI review F-5).
    ///
    /// macOS never needs this — its whole window is pinned at 560×540 — but on iOS the dock had
    /// no cap at any level, so on a 13-inch iPad it ran the full screen. Measured on that
    /// simulator before the cap: the scope picker filled **1294 of 1294 pt**. Two of the three
    /// symptoms the review named were already handled and are worth recording so they are not
    /// "fixed" again — the welcome body carries its own 340pt cap, and the primary button is
    /// 128pt and merely centred.
    ///
    /// 640 rather than macOS's 560: the widest thing in the stack is the scope picker, whose
    /// segments need the room, and the review's own recommendation is a 560–640 band.
    static let onboardingDockMaxWidth: CGFloat = 640

    /// Maximum height of the subseries / volume sheet. The subseries list is 107 rows, so
    /// this is always a scroll view, never a list that happens to fit.
    #if os(macOS)
    static let onboardingSheetMaxHeight: CGFloat = 196
    #else
    static let onboardingSheetMaxHeight: CGFloat = 240
    #endif

    /// Page-dot geometry: idle diameter, and the width the current dot stretches to.
    static let onboardingDotSize: CGFloat = 6
    /// Width of the current step's accent pill.
    static let onboardingCurrentDotWidth: CGFloat = 17

    // MARK: - Settings chrome (S-2)

    /// Corner radius for a settings card. Before S-2 the app hard-coded 6/7/8/10/12/16 at
    /// different sites; the settings surfaces standardise here so the hub reads as one system.
    static let settingsCardCornerRadius: CGFloat = 10

    /// Fill for a settings card. Quaternary rather than a fixed grey so it adapts with the OS.
    static let settingsCardFill: some ShapeStyle = .quaternary

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
