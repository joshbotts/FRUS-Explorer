// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import CoreGraphics

// MARK: - BrowseTwoPaneMetrics

/// When Browse's two-pane keeps its list pane — and when the document takes the width back.
///
/// ## The interaction, measured
/// F-2 (#914) gated a second pane at 820 pt: a 340 pt corpus list beside at least 480 pt of
/// detail. The document level was never driven through it, and the document level is the one that
/// brings a **second pane of its own** — `DocumentView` presents the Research rail as a trailing
/// `.inspector` on every non-phone idiom, defaulting open (`panelVisible = true`, which
/// `.rememberLast` leaves alone). So a document in the detail pane asks for three columns in a
/// container gated for two.
///
/// Driven on two booted iPads (iPadOS 26.5, `TwoPaneDocumentTests`):
///
/// | device | window | what the reader got |
/// |---|---|---|
/// | iPad Pro 13-inch | 1032 | list 340 + **reader 451.5** + rail 240 — three columns |
/// | iPad Pro 11-inch | 834 | list 340 + reader 493.5, with the rail **overlaying** ~280 of it |
///
/// With the rule in place the same devices give the reader **752 pt** and **554 pt**, each beside
/// a 280 pt rail that now pushes rather than overlays.
///
/// Both are the same defect wearing different clothes: at 1032 the rail takes a column and the
/// reader keeps 451.5 pt; at 834 there is no room for a third column, so iPadOS overlays the rail
/// on top of the document and the reader keeps roughly 213 pt of *visible* prose.
///
/// ## Why 451.5 pt is too narrow, by this app's own standards rather than by taste
/// Two numbers already in the codebase say so.
///
/// 1. **`MacDocumentView.railOverlayBreakpoint`** (`:349`) exists so the Mac's reading column
///    "never reflows below its ~340 pt floor". The 11-inch's ~213 pt of visible prose is below the
///    floor the Mac refuses to cross.
/// 2. **`HTMLTemplate`'s 70 ch measure** (`:122`) was added by this same review package's one
///    CRITICAL (X-1), because ~190 characters per line on a 13-inch iPad was "two to four times
///    the ~66-char typographic measure". The wrapper's padding is a fixed 48 px a side, so a
///    451.5 pt web view leaves a **355.5 px content box** — narrower than 70 ch at any plausible
///    character width, which means the cap no longer binds and the column sits *below* its
///    designed measure instead of at it (roughly 45–50 characters at the default 14 px body).
///    X-1 fixed lines that were too long; this would ship the same error inverted, and the reader
///    cannot resize their way out of it because both flanking panes are the app's own.
///
/// ## The rule
/// **The list pane survives at the document level only when the container can still honour F-2's
/// own promise with the rail present** — that is, `minimumWidth` plus the rail's width. The
/// arithmetic is F-2's, unchanged; the rail is simply a third column, and a third column costs
/// its width.
///
/// Two properties of the rule are deliberate:
///
/// - **It reads the level, not `panelVisible`.** Keying on whether the rail is *currently* open
///   would mean closing a panel makes the reader's content narrower (the list pane would slide
///   back in and take 340 pt), which is a worse interaction than the one being fixed. The rail is
///   open by default and one tap away otherwise, so the budget is reserved for it either way.
/// - **It is a width rule, not a "documents are always full width" rule.** At 1366 pt — a 13-inch
///   iPad in landscape, or a wide Stage Manager window — three columns still leave the reader
///   746 pt, within a few points of the 752 pt the same device measured as a single column in
///   portrait. The list pane is worth keeping exactly when it is affordable, and this says when.
///
/// ## What the list pane is, which is why giving it up costs little
/// The list pane is `CorpusView` — the **corpus root**, always, not the document's parent level.
/// So while reading a document three levels down, it lists subseries. Its value at the terminal
/// level is a jump to somewhere else entirely, and it is charging half the reader's width for it.
///
/// Version history:
///   1.0 — F-2 follow-up: the document-into-the-detail-pane interaction
enum BrowseTwoPaneMetrics {

    /// Width of the persistent corpus-list pane.
    static let listPaneWidth: CGFloat = 340

    /// The narrowest detail pane F-2 considered worth having.
    ///
    /// From the design's gate note: "820 leaves at least 480 pt of detail beside a 340 pt list."
    /// The two constants compose into the shipped gate exactly, which is why they are spelled
    /// separately here rather than as one 820.
    static let detailFloor: CGFloat = 480

    /// Width the Research rail's `.inspector` column takes on iPadOS.
    ///
    /// **Measured, not chosen**, and measured in both states because they differ. On a booted iPad
    /// Pro 13-inch (iPadOS 26.5) the rail takes **280 pt** when it has room — 1032 − 752 with the
    /// list pane gone, and the same 280 it overlays at on an 11-inch. Squeezed into three columns
    /// it compressed to 240 (1032 − 340 − 451.5), which is a symptom of the arrangement this rule
    /// exists to prevent rather than the rail's width. Budgeting the compressed figure would let a
    /// container keep three columns and then discover it could not afford them.
    ///
    /// The app does not set `inspectorColumnWidth`, so this is the platform's default and may move
    /// in a future release. It is a budget: being a few points out only shifts where the list pane
    /// is given up.
    static let researchRailWidth: CGFloat = 280

    /// The container width at which Browse shows a detail pane at all (F-2's shipped gate).
    static var minimumWidth: CGFloat { listPaneWidth + detailFloor }

    /// The container width at which the list pane survives a document.
    static var documentMinimumWidth: CGFloat { minimumWidth + researchRailWidth }

    /// Whether this container is wide enough for the two-pane layout at all.
    ///
    /// - Parameter containerWidth: The measured width of Browse's content area.
    static func showsDetailPane(containerWidth: CGFloat) -> Bool {
        containerWidth >= minimumWidth
    }

    /// Whether the corpus list pane should be on screen.
    ///
    /// - Parameters:
    ///   - containerWidth: The measured width of Browse's content area.
    ///   - isDocumentLevel: Whether the deepest level on the path is a document — the only level
    ///     that brings the Research rail with it.
    /// - Returns: `true` when the list pane fits without pushing the reader below F-2's own floor.
    static func showsListPane(containerWidth: CGFloat, isDocumentLevel: Bool) -> Bool {
        containerWidth >= (isDocumentLevel ? documentMinimumWidth : minimumWidth)
    }

    /// Whether the detail pane must offer its own Back control.
    ///
    /// **Coupled to ``showsListPane(containerWidth:isDocumentLevel:)`` on purpose.** The two-pane's
    /// Back was `depth > 1`, because at depth 1 the parent is the corpus list sitting beside it. A
    /// document handed off from Research, Search or a citation arrives by `append` on a possibly
    /// empty path, so it can *be* depth 1 — and the pane that made a Back unnecessary there is
    /// exactly the one this rule gives up. Without the second clause that document has no Back and
    /// no list: a dead end reachable from three surfaces.
    ///
    /// The `depth > 0` guard on that clause is not decoration. Back pops with `removeLast()`, which
    /// traps on an empty array; today a hidden list pane implies a document on the path, but that
    /// implication lives in two other functions and this one should not depend on it.
    ///
    /// - Parameters:
    ///   - pathDepth: `navigationPath.count`.
    ///   - listPaneShown: Whether the corpus list is on screen beside the detail.
    static func showsBackControl(pathDepth: Int, listPaneShown: Bool) -> Bool {
        pathDepth > 1 || (!listPaneShown && pathDepth > 0)
    }
}
