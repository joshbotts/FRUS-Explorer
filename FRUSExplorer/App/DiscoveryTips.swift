// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import SwiftUI
import TipKit

// MARK: - Discovery Tips

// Curated TipKit tips that teach the app's least discoverable, highest-value
// controls. Deliberately a *small* set — tips are for features users genuinely
// don't find on their own, not a tour of every button. Day-to-day labelling of
// icon-only controls is handled by `controlHelp` (tooltips on macOS, VoiceOver
// hints + Large Content Viewer on iOS); TipKit covers the proactive,
// first-contact moment those mechanisms can't.
//
// Each tip is invalidated with `.actionPerformed` the first time the user uses
// the control it points at, and otherwise gives up after three displays.
// `Tips.configure` runs once at app launch in `FRUSExplorerApp`.
//
// ## A tip can lose its anchor silently — #597 Phase 0
// `ExploreCrossReferencesTip` lived here for months with **no display site**. It pointed at a
// Cross-References button in the document toolbar; the Research Rail redesign deleted that button,
// and the `.popoverTip` went with it. The declaration still compiled, `import TipKit` was still
// required (the orphaned `.invalidate` call kept it alive), and the diff showed only a removed
// modifier. Nothing was red, and the tip could never appear again.
//
// It was **deleted rather than re-anchored**, because its id was already burned: the orphaned
// `.invalidate` had been running on every document open, so for every existing user that id is
// recorded as invalidated and TipKit would never display it again. Re-anchoring would have shipped
// something dead on arrival for exactly the people who already have the app. Its replacement
// arrives in Phase 1 under a new type and a new id — **never reuse the old name.**
//
// ``DiscoveryTipRegistry`` below is the mechanical guard: every tip declares where it is anchored
// and for which platforms, and `DiscoveryTipWiringAuditTests` fails the suite when a declaration
// and its display site drift apart.

// MARK: - ResearchRailTip

/// Points at the Research-rail toggle in the document toolbar — the single unlabelled glyph that
/// gates every document-scoped research tool on iOS (#597 Phase 1).
///
/// **This is the replacement for the retired `ExploreCrossReferencesTip`, under a new name.** That
/// tip's id is burned: an orphaned `.invalidate` ran on every document open for months, so TipKit
/// has it recorded as invalidated for every existing user and would never display it again. Do not
/// reuse the old name to "restore" it.
///
/// Carries `IgnoresDisplayFrequency` — alone among the tips — because it gates roughly ten
/// capabilities the others assume the user has already met. Waiting an hour to reveal the door
/// would put the rest of the set behind it.
struct ResearchRailTip: Tip {
    /// Tip headline.
    var title: Text {
        Text(String(localized: "tip.researchRail.title",
                    defaultValue: "Your Research Tools Live Here"))
    }

    /// What is behind the toggle. Named concretely — the point is to reveal a door, so the copy
    /// has to say what is on the other side of it.
    var message: Text? {
        Text(String(localized: "tip.researchRail.message",
                    defaultValue: "Citations, the word cloud, archival sources, the cross-reference graph, related documents, and your notes, tags and collections for this document."))
    }

    /// Matches the toolbar button's icon.
    var image: Image? {
        Image(systemName: "doc.text.magnifyingglass")
    }

    /// Shown regardless of how recently another tip appeared, and retired the first time the rail
    /// is opened.
    var options: [any TipOption] {
        [Tips.MaxDisplayCount(3), Tips.IgnoresDisplayFrequency(true)]
    }
}

// MARK: - EdgeTapNavigationTip

/// Points at the invisible edge zones that turn the page (#597 Phase 1).
///
/// The most literally undiscoverable control in the app: two `Color.clear` strips with no glyph,
/// no border and no hover state — a `#if DEBUG` flag exists purely so developers can see them —
/// and on iOS they are the *only* way to reach the previous or next document in a volume.
///
/// It needs no `Tip.Rule`. Its anchor renders only when the capability is live (Read mode, the
/// setting on, no sheet up) and the zone itself is empty at a volume boundary, so **the anchor is
/// the rule**.
struct EdgeTapNavigationTip: Tip {
    /// Tip headline.
    var title: Text {
        Text(String(localized: "tip.edgeTap.title", defaultValue: "Tap the Edges to Turn the Page"))
    }

    /// What the zones do, and where the sequence comes from.
    var message: Text? {
        Text(String(localized: "tip.edgeTap.message",
                    defaultValue: "In Read mode, tapping the left or right edge moves to the previous or next document in this volume — the order the editors arranged them in."))
    }

    /// The direction the gesture implies.
    var image: Image? {
        Image(systemName: "chevron.left.chevron.right")
    }

    /// Stop showing after three impressions even if never acted on.
    var options: [any TipOption] {
        [Tips.MaxDisplayCount(3)]
    }
}

// MARK: - ExamineResultsTip

/// Points at the binoculars menu above search results (#597 Phase 1).
///
/// Four readings of one result set behind a single glyph that is deliberately *not* the glyph of
/// any of them — the icon was renamed off `chart.bar` precisely because no symbol depicts the set,
/// which also means it cannot be reverse-engineered by looking at it.
///
/// Anchored on the menu's label rather than its items: `.popoverTip` cannot attach to a `Button`
/// inside a `Menu`'s content, because a menu row is not a popover host.
struct ExamineResultsTip: Tip {
    /// Tip headline.
    var title: Text {
        Text(String(localized: "tip.examine.title", defaultValue: "Four Ways to Read These Results"))
    }

    /// Names all four, since the anchor is the menu label and the items are not visible yet.
    var message: Text? {
        // .v2: the fourth clause named three of the panel's SIX sections. The panel renders
        // Years, Volumes, People, Document type, Archival provenance and Subjects
        // unconditionally, on both platforms — Subjects arrived with #308 and no string was
        // updated for it. The count is stated so the reader can tell a list from a sample.
        Text(String(localized: "tip.examine.message.v2",
                    defaultValue: "Place them on a timeline, line every occurrence up on your search term, rank the words that keep company with it, or break the whole match down six ways — by year, volume, person, document type, archival provenance and subject."))
    }

    /// Matches the menu's glyph.
    var image: Image? {
        Image(systemName: "binoculars")
    }

    /// Stop showing after three impressions even if never acted on.
    var options: [any TipOption] {
        [Tips.MaxDisplayCount(3)]
    }
}

// MARK: - FacetNarrowTip

/// Points at the facet panel's preamble — the one shared anchor in Phase 1 (#597).
///
/// A narrowable facet row renders identically to a descriptive one: label, count, no chevron, no
/// accent, no trailing affordance. The only existing signal is a `.help` tooltip, which is
/// macOS-hover-only. And the archival-provenance section deliberately has *no* button, so a user
/// who probes that section first learns the wrong lesson about the whole panel.
///
/// Anchored on the preamble, not the rows — attaching to the row `Button` would mint one popover
/// per facet row, dozens per section.
struct FacetNarrowTip: Tip {
    /// Tip headline.
    var title: Text {
        Text(String(localized: "tip.facetNarrow.title", defaultValue: "Facet Rows Are Filters"))
    }

    /// What a tap does, and the denominator caveat that makes the panel readable.
    var message: Text? {
        Text(String(localized: "tip.facetNarrow.message",
                    defaultValue: "Tap any year, volume or person to narrow your search to it — it becomes a chip you can clear. The counts themselves always describe the whole match, before any narrowing."))
    }

    /// Matches the facet panel's own glyph.
    var image: Image? {
        Image(systemName: "square.grid.3x3")
    }

    /// Stop showing after three impressions even if never acted on.
    var options: [any TipOption] {
        [Tips.MaxDisplayCount(3)]
    }
}

// MARK: - GraphReferenceListTip

/// Points at the reference-list toggle in the cross-reference graph toolbar
/// (regular widths) — the list shows headers, dates, and footnote context the
/// canvas can only hint at.
struct GraphReferenceListTip: Tip {
    /// Tip headline.
    var title: Text {
        Text(String(localized: "tip.graphList.title",
                    defaultValue: "Browse References as a List"))
    }

    /// One-sentence pitch for the side panel.
    var message: Text? {
        Text(String(localized: "tip.graphList.message",
                    defaultValue: "Open a side panel listing every reference with its date, volume, and the footnote that linked it."))
    }

    /// Matches the toolbar button's icon.
    var image: Image? {
        Image(systemName: "sidebar.trailing")
    }

    /// Stop showing after three impressions even if never acted on.
    var options: [any TipOption] {
        [Tips.MaxDisplayCount(3)]
    }
}

// MARK: - TimelineLayoutTip

/// Points at the Timeline/Network layout picker in the cross-reference graph —
/// chronology is the graph's most meaningful arrangement, and the picker is the
/// only place to switch.
struct TimelineLayoutTip: Tip {
    /// Tip headline.
    var title: Text {
        Text(String(localized: "tip.timeline.title",
                    defaultValue: "Timeline or Network"))
    }

    /// One-sentence explanation of the two layouts.
    var message: Text? {
        Text(String(localized: "tip.timeline.message",
                    defaultValue: "Timeline places each document at its date — earlier sources left, later responses right. Network shows the citation web instead."))
    }

    /// Matches the timeline layout concept.
    var image: Image? {
        Image(systemName: "calendar.day.timeline.left")
    }

    /// Stop showing after three impressions even if never acted on.
    var options: [any TipOption] {
        [Tips.MaxDisplayCount(3)]
    }
}

// MARK: - DiscoveryTipRegistry

/// Every discovery tip, with the display site it is anchored to.
///
/// ## Why a registry exists at all
/// A `.popoverTip` modifier registers nothing queryable, and a tip's declaration has no
/// compile-time relationship to its display site. That is how `ExploreCrossReferencesTip` shipped
/// dead (see this file's overview). This table restores the relationship as *data*, so
/// `DiscoveryTipWiringAuditTests` can check it — and so the Settings "Show Tips Again" control
/// (Phase 1) has one list to iterate rather than a hand-maintained duplicate.
///
/// **Adding a tip means adding a row here.** The audit fails on a declared `Tip` that is missing.
///
/// Version history:
///   1.0 — #597 Phase 0: initial implementation
///   1.1 — #597 recall: `resetAll()` + `allTips`, behind Settings ▸ Display ▸ Show Tips Again
enum DiscoveryTipRegistry {

    /// The platforms a given anchor actually compiles for.
    ///
    /// Declared per anchor rather than per tip, because a tip may reach one platform through a
    /// shared file and another through a platform-private one. Asserting coverage as
    /// `(file, platform)` pairs is what stops the #617-shaped defect where a control exists in a
    /// `#if os(macOS)` block and is reported as covered for iOS.
    struct Anchor: Sendable {
        /// Repo-relative path of the file holding the `.popoverTip` modifier.
        let file: String
        /// The platforms this anchor is compiled for.
        let platforms: Set<Platform>

        /// A platform a tip can be shown on.
        enum Platform: String, Sendable, CaseIterable {
            case iOS, macOS
        }

        /// An anchor in a file with no `#if os` gate at all.
        static func shared(_ file: String) -> Anchor {
            Anchor(file: file, platforms: Set(Platform.allCases))
        }
    }

    /// One registered tip.
    struct Entry: Sendable {
        /// The Swift type name, exactly as declared.
        let typeName: String
        /// Every place this tip is displayed from.
        let anchors: [Anchor]
    }

    /// The registered tips.
    ///
    /// Both current entries are anchored in `CrossReferenceGraphView`, which carries no `#if os`
    /// gate — so one anchor each covers both platforms.
    static let entries: [Entry] = [
        // Phase 1 — first contact. Three iOS-only, one shared.
        //
        // Only the iPhone rail toggle needs a tip: iPad and macOS default the rail VISIBLE
        // (`panelVisible = true`), so their near-identical toggles in `MainWindowView` and
        // `MacDocumentView` are deliberately left unanchored. Anchoring all three would ship a
        // "your tools are here" popover to platforms already showing the tools.
        Entry(typeName: "ResearchRailTip",
              anchors: [Anchor(file: "FRUSExplorer/DocumentView/DocumentView.swift",
                               platforms: [.iOS])]),
        Entry(typeName: "EdgeTapNavigationTip",
              anchors: [Anchor(file: "FRUSExplorer/DocumentView/DocumentView.swift",
                               platforms: [.iOS])]),
        // No macOS twin is owed: the binoculars menu has no macOS counterpart at all —
        // `SearchSheet` offers the readings differently.
        Entry(typeName: "ExamineResultsTip",
              anchors: [Anchor(file: "FRUSExplorer/Search/SearchView.swift", platforms: [.iOS])]),
        // The one shared anchor: `FacetPanelView` carries no `#if os` gate and is hosted by both
        // `SearchView` and `SearchSheet`, so one modifier reaches iPhone, iPad and macOS.
        Entry(typeName: "FacetNarrowTip",
              anchors: [.shared("FRUSExplorer/Search/FacetPanelView.swift")]),

        Entry(typeName: "GraphReferenceListTip",
              anchors: [.shared("FRUSExplorer/CrossReference/CrossReferenceGraphView.swift")]),
        Entry(typeName: "TimelineLayoutTip",
              anchors: [.shared("FRUSExplorer/CrossReference/CrossReferenceGraphView.swift")])
    ]

    /// Re-arms every registered tip, so a user who dismissed them can meet them again.
    ///
    /// Iterates the registry rather than a second hand-written list — a "show tips again" that
    /// silently missed a tip would be its own quiet bug, and the registry is already the one place
    /// that has to be complete (`DiscoveryTipWiringAuditTests` enforces that).
    ///
    /// `resetEligibility()` per tip, **not** `Tips.resetDatastore()`: that throws once the
    /// datastore is configured — which it always is by the time Settings can be reached — so it
    /// would at best become a next-launch reset, and at worst do nothing while appearing to work.
    /// This takes effect immediately, mid-session.
    ///
    /// A tip re-armed here still obeys its display frequency and its `MaxDisplayCount`, so this
    /// restores eligibility rather than forcing a burst of popovers.
    @MainActor
    static func resetAll() async {
        for tip in allTips {
            await tip.resetEligibility()
        }
        #if DEBUG
        print("[DiscoveryTipRegistry] Re-armed \(allTips.count) discovery tip(s)")
        #endif
    }

    /// Live instances of every registered tip.
    ///
    /// The registry stores type *names* because its other consumer is a source audit that has only
    /// strings to work with. Resetting needs real values, so the two are kept side by side here and
    /// `registryAndInstancesAgree` pins that neither can grow without the other.
    static let allTips: [any Tip] = [
        ResearchRailTip(),
        EdgeTapNavigationTip(),
        ExamineResultsTip(),
        FacetNarrowTip(),
        GraphReferenceListTip(),
        TimelineLayoutTip()
    ]

    /// Files a tip may **never** be anchored in, with the reason.
    ///
    /// Each of these renders in no shipping build, so a `.popoverTip` placed there would satisfy a
    /// naive "does the file contain the modifier?" check while displaying to nobody — reproducing
    /// exactly how `ExploreCrossReferencesTip` died. The audit refuses them by name.
    static let forbiddenAnchors: [String: String] = [
        "FRUSExplorer/ProjectContext/GlobalContextView.swift":
            "unpresented dead code — the view constructs a collection editor but is never shown "
            + "(see its own doc comment)",
        "FRUSExplorer/Browser/BrowserView.swift":
            "contains `splitLayout`, unreferenced since #238 Fix B routed every size class through "
            + "`stackLayout`; its ProjectPickerMenu sits ~52 lines above the live copy and looks "
            + "identical. If a tip ever belongs in this file, anchor it in `stackLayout` and "
            + "narrow this entry rather than deleting it"
    ]
}
