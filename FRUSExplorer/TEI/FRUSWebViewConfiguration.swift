// Copyright 2026 The FRUS Explorer Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0

import Foundation
import WebKit

// MARK: - WKWebViewConfiguration factory

extension WKWebViewConfiguration {

    /// Returns a `WKWebViewConfiguration` with the given `FRUSURLSchemeHandler`
    /// registered for the `frusexplorer://` custom URL scheme.
    ///
    /// Each `FRUSDocumentWebView` instance creates its own `FRUSURLSchemeHandler`
    /// and calls this factory so the handler's per-document person/gloss lookup
    /// tables are correctly scoped to that view.
    ///
    /// ## Session history
    /// - **Session 141**: Used `StubFRUSURLSchemeHandler`; handler not yet parameterised.
    /// - **Session 142**: Handler is passed in; dispatches person/gloss/cross-ref taps.
    /// - **Session 143**: `WKUserScript` injections for `frus-offset-engine.js` added.
    /// - **Session 144**: `frus-highlights.js` injected.
    /// - **Session 145**: `frus-selection.js` injected; `selectionChanged` message
    ///   handler registered.
    /// - Parameters:
    ///   - schemeHandler:   Per-view `FRUSURLSchemeHandler` for `frusexplorer://` dispatch.
    ///   - messageHandler:  Receives `selectionChanged` messages from the selection JS.
    ///                      Typically `_FRUSWebViewCoordinator` which conforms to
    ///                      `WKScriptMessageHandler`.
    static func frusExplorerConfiguration(
        schemeHandler:  FRUSURLSchemeHandler,
        messageHandler: any WKScriptMessageHandler
    ) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "frusexplorer")

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let ucc = config.userContentController

        // 1. Offset engine — sets window.FRUSOffsets.{flatText, charToNode}
        ucc.addUserScript(WKUserScript(
            source: kOffsetEngineJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))

        // 2. Highlights renderer — defines window.FRUSHighlights.render(highlights)
        ucc.addUserScript(WKUserScript(
            source: kHighlightsJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))

        // 3. Selection listener — posts selectionChanged messages to Swift
        ucc.addUserScript(WKUserScript(
            source: kSelectionJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        ucc.add(messageHandler, name: "selectionChanged")
        ucc.add(messageHandler, name: "selectionScrolled")
        ucc.add(messageHandler, name: "highlightTapped")

        return config
    }
}

// MARK: - Embedded JS source

/// Flat-text offset engine, embedded as a Swift string constant so the script
/// is available in both the app bundle and the unit-test host without any
/// `Bundle.main` lookup.
///
/// Canonical source: `FRUSExplorer/Resources/frus-offset-engine.js`
/// Keep this constant in sync with that file when making edits.
private let kOffsetEngineJS = """
window.FRUSOffsets = (() => {
  'use strict';
  const root = document.querySelector('.frus-document');
  if (!root) return null;
  const charToNode = [];
  let flatText = '';
  function walk(node) {
    if (node.nodeType === Node.TEXT_NODE) {
      const val = node.nodeValue;
      for (let i = 0; i < val.length; i++) {
        charToNode.push({ node: node, localOffset: i });
      }
      flatText += val;
      return;
    }
    if (node.nodeType !== Node.ELEMENT_NODE) return;
    if (node.dataset && node.dataset.skip === '1') return;
    if (node.tagName === 'BR') {
      charToNode.push({ node: node, localOffset: 0 });
      flatText += '\\n';
      return;
    }
    for (const child of node.childNodes) { walk(child); }
  }
  walk(root);
  return Object.freeze({ flatText, charToNode });
})();
"""

/// CSS Custom Highlight API renderer, embedded as a Swift string constant.
/// Canonical source: `FRUSExplorer/Resources/frus-highlights.js`
/// Keep this constant in sync with that file when making edits.
/// Must be injected AFTER `kOffsetEngineJS` because `buildRanges()` reads
/// `window.FRUSOffsets.charToNode`.
private let kHighlightsJS = """
function buildRanges(start, end) {
  if (!window.FRUSOffsets) return [];
  const map = window.FRUSOffsets.charToNode;
  if (start >= map.length || end > map.length || start >= end) return [];
  const range = new Range();
  range.setStart(map[start].node, map[start].localOffset);
  const endEntry = map[end - 1];
  range.setEnd(endEntry.node, endEntry.localOffset + 1);
  return [range];
}

window.FRUSHighlights = {
  // All currently rendered highlights, stored so the click handler can
  // identify which highlight (if any) a tap falls within.
  currentHighlights: [],

  render(highlights) {
    if (typeof CSS === 'undefined' || !CSS.highlights) return;
    CSS.highlights.clear();
    window.FRUSHighlights.currentHighlights = highlights || [];
    if (!highlights || !highlights.length) return;
    const groups = {};
    for (const h of highlights) {
      const ranges = buildRanges(h.startOffset, h.endOffset);
      if (!ranges.length) continue;
      const key = h.isStale ? 'frus-stale' : ('frus-' + h.color);
      if (!groups[key]) groups[key] = [];
      groups[key].push(...ranges);
    }
    for (const [name, ranges] of Object.entries(groups)) {
      CSS.highlights.set(name, new Highlight(...ranges));
    }
  }
};

// Click listener: detect taps within a rendered highlight range and notify Swift.
// Uses document.caretRangeFromPoint (WebKit) to map the tap point to a character
// offset, then checks whether that offset falls inside any current highlight.
// Posts { startOffset, endOffset, color } to the highlightTapped handler.
document.addEventListener('click', (e) => {
  // Skip if user is making a text selection (mousedown dragged)
  const sel = window.getSelection();
  if (sel && !sel.isCollapsed) return;

  if (!window.FRUSOffsets || !window.FRUSHighlights.currentHighlights.length) return;

  // Resolve the tap point to a DOM caret position
  const caretRange = document.caretRangeFromPoint(e.clientX, e.clientY);
  if (!caretRange) return;

  // Convert caret position to flat-text offset using the existing reverse-map
  const map = window.FRUSOffsets.charToNode;
  const node = caretRange.startContainer;
  const localOff = caretRange.startOffset;
  let tapOffset = -1;
  for (let i = 0; i < map.length; i++) {
    if (map[i].node === node && map[i].localOffset === localOff) { tapOffset = i; break; }
  }
  // Fallback: if exact localOffset not found, search for the node at any offset
  if (tapOffset < 0) {
    for (let i = 0; i < map.length; i++) {
      if (map[i].node === node) { tapOffset = i; break; }
    }
  }
  if (tapOffset < 0) return;

  // Find the first non-stale highlight whose range contains the tap offset
  const hl = window.FRUSHighlights.currentHighlights.find(
    h => !h.isStale && tapOffset >= h.startOffset && tapOffset < h.endOffset
  );
  if (!hl) return;

  try {
    webkit.messageHandlers.highlightTapped.postMessage({
      startOffset: hl.startOffset,
      endOffset:   hl.endOffset,
      color:       hl.color
    });
    e.stopPropagation();
  } catch (_) {}
});
"""

/// Text-selection → flat-text offset bridge, embedded as a Swift string constant.
/// Canonical source: `FRUSExplorer/Resources/frus-selection.js`
/// Keep this constant in sync with that file when making edits.
/// The JS body is byte-identical to the body of `Resources/frus-selection.js` (below its
/// JSDoc header); `SelectionScriptParityTests` pins them together. `internal` (not
/// `private`) so that test can read it.
let kSelectionJS = """
function rangeEndpointToOffset(node, localOffset) {
  if (!window.FRUSOffsets) return -1;
  const map = window.FRUSOffsets.charToNode;
  for (let i = 0; i < map.length; i++) {
    if (map[i].node === node && map[i].localOffset === localOffset) return i;
  }
  return -1;
}
function postCleared() {
  try { webkit.messageHandlers.selectionChanged.postMessage({ start: -1, end: -1 }); }
  catch (_) {}
}
// The text of the block enclosing the selection, for footnote selections whose nodes the
// offset engine can't map (so Swift's offset-based block look-around is unavailable). Prefers
// the whole footnote body — the popover `aside.footnote` or the endnote `li.fn-list-item` —
// else the nearest bounded block-level ancestor. `div`/`section` are deliberately excluded so
// this can never climb to the `.frus-document` root or the footnotes section and return the
// entire document. Falls back to the raw selected text; capped to bound the bridge payload.
function enclosingBlockText(range, fallback) {
  const node = range.commonAncestorContainer;
  const el = node.nodeType === Node.ELEMENT_NODE ? node : node.parentElement;
  if (!el) return fallback;
  const block = el.closest('aside.footnote, li.fn-list-item')
             || el.closest('figcaption, p, li, td, blockquote');
  const text = block ? block.textContent : fallback;
  return text ? text.slice(0, 5000) : fallback;
}
// The selection's bounding box in web-view viewport coordinates (CSS px) plus the visual
// viewport scale, for anchoring the floating selection bar. getBoundingClientRect is
// viewport-relative (already accounts for internal scroll); at scale 1 it maps 1:1 onto the
// web view's own point space. `scale` (visualViewport.scale) lets a pinch-zoomed iOS reader
// correct or hide the bar.
function selectionGeometry(range) {
  const r = range.getBoundingClientRect();
  return {
    rect: { x: r.x, y: r.y, w: r.width, h: r.height },
    scale: (window.visualViewport && window.visualViewport.scale) || 1
  };
}
document.addEventListener('selectionchange', () => {
  const sel = window.getSelection();
  if (!sel || sel.isCollapsed || !window.FRUSOffsets) { postCleared(); return; }
  const range = sel.getRangeAt(0);
  const start = rangeEndpointToOffset(range.startContainer, range.startOffset);
  const end   = rangeEndpointToOffset(range.endContainer,   range.endOffset);
  const geom = selectionGeometry(range);
  if (start >= 0 && end > start) {
    // In-document selection: valid flat-text offsets + raw text. Swift derives block
    // context from the offsets (flatTextExcerpt), so no blockText is sent here.
    const text = sel.toString();
    try { webkit.messageHandlers.selectionChanged.postMessage({ start, end, text, rect: geom.rect, scale: geom.scale }); }
    catch (_) {}
  } else {
    // At least one endpoint is outside the offset map — footnote popover or footnote
    // section. The offset engine can't map these nodes, so we send sentinel offsets (-1)
    // plus the selected text AND the enclosing block text (blockText) so Swift can
    // characterise the footnote's citations. This is a text-only selection: NARA lookup is
    // available but highlight creation is not (which requires valid offsets).
    const text = sel.toString();
    if (text) {
      const blockText = enclosingBlockText(range, text);
      try { webkit.messageHandlers.selectionChanged.postMessage({ start: -1, end: -1, text, blockText, rect: geom.rect, scale: geom.scale }); }
      catch (_) {}
    } else {
      postCleared();
    }
  }
});
// A viewport-anchored floating bar goes stale when the document scrolls inside the web view,
// and `selectionchange` does NOT re-fire on scroll. Post a throttled (one-per-frame) hide
// signal while a selection is live so the bar can dismiss; capture-phase + passive so it sees
// scrolls on any inner scroller without blocking them.
let selectionScrollScheduled = false;
function scheduleSelectionScrolled() {
  if (selectionScrollScheduled) return;
  selectionScrollScheduled = true;
  requestAnimationFrame(() => {
    selectionScrollScheduled = false;
    const sel = window.getSelection();
    if (sel && !sel.isCollapsed) {
      try { webkit.messageHandlers.selectionScrolled.postMessage({}); } catch (_) {}
    }
  });
}
window.addEventListener('scroll', scheduleSelectionScrolled, { passive: true, capture: true });
// Pinch zoom, visual-viewport pan, and rotation move the selection on screen WITHOUT firing
// `scroll` or `selectionchange`; route them through the same throttled hide-signal so the
// viewport-anchored bar dismisses instead of floating over stale text (D4 zoom + rotation).
if (window.visualViewport) {
  window.visualViewport.addEventListener('resize', scheduleSelectionScrolled, { passive: true });
  window.visualViewport.addEventListener('scroll', scheduleSelectionScrolled, { passive: true });
}
"""
