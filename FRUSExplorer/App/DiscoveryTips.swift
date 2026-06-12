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

// MARK: - ExploreCrossReferencesTip

/// Points at the Cross-References button in the document toolbar — the entry
/// point to the graph, and the feature users are least likely to discover from
/// its icon alone.
struct ExploreCrossReferencesTip: Tip {
    /// Tip headline.
    var title: Text {
        Text(String(localized: "tip.crossRef.title",
                    defaultValue: "Explore Cross-References"))
    }

    /// One-sentence pitch for the graph.
    var message: Text? {
        Text(String(localized: "tip.crossRef.message",
                    defaultValue: "See every document this one cites — and every document that cites it — arranged on a timeline."))
    }

    /// Matches the toolbar button's icon.
    var image: Image? {
        Image(systemName: "arrow.triangle.branch")
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
