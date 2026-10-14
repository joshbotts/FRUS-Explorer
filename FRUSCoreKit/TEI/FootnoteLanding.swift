// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation

// MARK: - FootnoteLanding

/// The script that brings the reader to the footnote a cross-reference named (#988): it scrolls the
/// note's endnote entry into view and washes it for 2.4 seconds.
///
/// **The endnote `<li>` is the target, not the popover `<aside>`.** The aside carries a bare
/// `popover` attribute, so the UA stylesheet gives it `display: none` until it is shown; an element
/// generating no boxes cannot be scrolled to, and once shown a popover is in the top layer and
/// already on screen. The `<li>` is ordinary in-flow content carrying the same note text, and it
/// lives in the footnotes section, which is emitted outside `.frus-document` — the offset engine's
/// DFS root — so nothing here can perturb a highlight coordinate. The reveal is a scroll and a class
/// toggle: no DOM node is created, split, or removed.
///
/// The app's reader runs it once a page has loaded (`_FRUSWebViewCoordinator.revealFootnote(on:)`),
/// and FRUS Explorer Light's reader host runs the same script, so a reference lands on its note
/// alike in both.
///
/// Version history:
///   1.0 — FRUS Explorer Light: moved out of `_FRUSWebViewCoordinator.revealFootnote(on:)`, with
///          `FRUSURLSchemeHandler.revealedFootnoteGlobal`, for the web edition's reader
public enum FootnoteLanding {

    /// The page's global holding the `id` of the footnote entry the reader was last brought to, or
    /// `null` once the reader has scrolled, tapped or typed for themselves. The app's figure retry
    /// (`FRUSURLSchemeHandler.figureRetryScript(for:)`) reads it.
    public static let revealedGlobal = "FRUSRevealedFootnote"

    /// The script for the footnote whose anchor is `anchor`, as the app's reader runs it: `true`
    /// when the page holds the note's entry, `false` when it does not.
    ///
    /// The DOM key is the `x-` branch of `FRUSRenderNode.footnoteDOMKey`; the reading view builds its
    /// serializer with no `idScope`, so there is no prefix to compose here. It is JSON-encoded rather
    /// than interpolated — the same discipline the app's `renderHighlights` uses, and the corpus
    /// contains at least one non-ASCII note id (`d89fnǁ`).
    ///
    /// - Parameter anchor: The footnote's anchor, as a cross-reference names it.
    /// - Returns: The script, or `nil` when the key cannot be encoded.
    public static func script(anchor: String) -> String? {
        guard let keyData = try? JSONEncoder().encode("x-" + anchor),
              let keyLiteral = String(data: keyData, encoding: .utf8) else { return nil }
        return script(keyExpression: keyLiteral)
    }

    /// The script, with `keyExpression` where the note's DOM key goes: a JavaScript expression that
    /// evaluates to the key, such as a string literal or, for a host that has the key only when it
    /// runs, the name of a parameter of a function of its own around the script.
    ///
    /// - Parameter keyExpression: JavaScript evaluating to the note's DOM key (`"x-" + anchor`).
    /// - Returns: An expression whose value is `true` when the page holds the note's entry.
    public static func script(keyExpression: String) -> String {
        // TWO THINGS HERE ARE LOAD-BEARING, and both were found by running this script against the
        // emitted markup in a hidden page rather than by reasoning about it.
        //
        // The scroll is SYNCHRONOUS. Deferring it inside a double `requestAnimationFrame` — the
        // obvious way to wait for layout to settle — does nothing at all while `document.hidden`
        // is true, because rAF callbacks do not fire then: a background macOS window, an unfronted
        // iPad scene, a reveal arriving before the view is on screen. Measured, the rAF form left
        // `scrollY` at 0.
        //
        // And the scroll falls back to `auto` when the document is hidden, because a `smooth`
        // scroll is ANIMATED and its animation does not progress either — measured, the sync-but-
        // smooth form also left `scrollY` at 0, which is the same failure wearing a different hat.
        //
        // Both would have been invisible and permanent: `lastRevealedFootnoteAnchor` is recorded
        // whatever happens, so the reveal is never retried.
        //
        // Nothing here needs to wait for layout: the page is a `loadHTMLString` document with no
        // `@font-face`, and `didFinish` runs after it is parsed and laid out. A figure's image
        // (#1516) that is on the device is answered by the scheme handler before `didFinish`, so
        // it is laid out too, and the `scroll-margin-block` on `.fn-list-item` absorbs a small
        // late reflow.
        //
        // An image that is NOT on the device is the exception. The handler fails its request at
        // once, fetches it, and has the page ask again (`FRUSURLSchemeHandler.figureRetryScript`):
        // that image is laid out after this scroll, and a map pushes the footnotes down by far
        // more than the margin. So the entry revealed is remembered in a global the retry script
        // reads, and the retry brings it back into view once its image has loaded — unless the
        // reader has since scrolled, tapped or typed, which clears the global, because by then
        // where they are is their own choice.
        let revealed = revealedGlobal
        return """
        (() => {
          const li = document.getElementById("fnote-" + \(keyExpression));
          if (!li) { return false; }
          const instant = document.hidden
            || window.matchMedia("(prefers-reduced-motion: reduce)").matches;
          li.scrollIntoView({ block: "center", behavior: instant ? "auto" : "smooth" });
          window.\(revealed) = li.id;
          if (!window.\(revealed)Watched) {
            window.\(revealed)Watched = true;
            const forget = () => { window.\(revealed) = null; };
            for (const type of ["wheel", "touchstart", "mousedown", "keydown"]) {
              window.addEventListener(type, forget, { capture: true, passive: true });
            }
          }
          li.classList.remove("fn-arrived");
          void li.offsetWidth;
          li.classList.add("fn-arrived");
          setTimeout(() => li.classList.remove("fn-arrived"), 2400);
          return true;
        })()
        """
    }
}
