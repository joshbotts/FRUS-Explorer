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
    static func frusExplorerConfiguration(
        schemeHandler: FRUSURLSchemeHandler
    ) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(schemeHandler, forURLScheme: "frusexplorer")

        // JavaScript required for the offset engine (Session 143+).
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        // Inject the flat-text offset engine first so window.FRUSOffsets is
        // available when the highlights renderer is initialised.
        let offsetScript = WKUserScript(
            source: kOffsetEngineJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(offsetScript)

        // Inject the CSS Custom Highlight API renderer (Session 144+).
        // Must come after the offset engine because buildRanges() reads charToNode.
        let highlightsScript = WKUserScript(
            source: kHighlightsJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(highlightsScript)

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
  render(highlights) {
    if (typeof CSS === 'undefined' || !CSS.highlights) return;
    CSS.highlights.clear();
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
"""
