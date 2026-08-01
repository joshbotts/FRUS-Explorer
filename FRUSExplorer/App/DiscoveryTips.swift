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
        Entry(typeName: "GraphReferenceListTip",
              anchors: [.shared("FRUSExplorer/CrossReference/CrossReferenceGraphView.swift")]),
        Entry(typeName: "TimelineLayoutTip",
              anchors: [.shared("FRUSExplorer/CrossReference/CrossReferenceGraphView.swift")])
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
