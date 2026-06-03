/**
 * frus-offset-engine.js
 * FRUS Explorer flat-text offset engine for document highlighting.
 *
 * Injected as a WKUserScript (.atDocumentEnd) by
 * WKWebViewConfiguration.frusExplorerConfiguration(schemeHandler:).
 * The Swift source of truth is the embedded constant kOffsetEngineJS in
 * FRUSWebViewConfiguration.swift — keep the two in sync when editing.
 *
 * ## Purpose
 * Traverses the .frus-document DOM tree using the same DFS rules as the
 * Swift appendFlatText() function in DocumentHighlightTextView.swift so that
 * character offsets stored in DocumentHighlight.startOffset / endOffset map
 * correctly onto DOM text node positions.
 *
 * ## Traversal rules (mirror of Swift DFS)
 *
 *   Text node         → append nodeValue to flatText; add one entry per
 *                       character to charToNode[]
 *   data-skip="1"     → skip entire subtree (pageBreak, footnoteMarker,
 *                       figureBlock, footnoteBody <aside>)
 *   <br>              → append "\n" to flatText; one charToNode entry
 *   Element otherwise → recurse into childNodes
 *
 * ## Output
 * Sets window.FRUSOffsets = { flatText: string, charToNode: Array } or null
 * if .frus-document is not found.
 *
 *   flatText    — plain string matching Swift buildFlatText(from:)
 *   charToNode  — array of { node: Text, localOffset: number }, indexed by
 *                 character position in flatText; used by Sessions 144 and 145
 *
 * Session history:
 *   1.0 — Session 143: initial implementation
 *   1.1 — Session 145: used by frus-selection.js for selection → offset mapping
 */

window.FRUSOffsets = (() => {
  'use strict';

  const root = document.querySelector('.frus-document');
  if (!root) return null;

  /** @type {Array<{node: Text, localOffset: number}>} */
  const charToNode = [];
  let flatText = '';

  /**
   * Recursive DFS walk.
   * @param {Node} node
   */
  function walk(node) {
    // Text nodes: each character gets its own charToNode entry.
    if (node.nodeType === Node.TEXT_NODE) {
      const val = node.nodeValue;
      for (let i = 0; i < val.length; i++) {
        charToNode.push({ node: node, localOffset: i });
      }
      flatText += val;
      return;
    }

    if (node.nodeType !== Node.ELEMENT_NODE) return;

    // Skip offset-invisible elements — matches data-skip="1" in the HTML
    // emitted by FRUSRenderNodeHTMLSerializer for pageBreak, footnoteMarker,
    // figureBlock, and footnoteBody.
    if (node.dataset && node.dataset.skip === '1') return;

    // <br> contributes "\n" — same as FRUSRenderNode.lineBreak in Swift.
    if (node.tagName === 'BR') {
      charToNode.push({ node: node, localOffset: 0 });
      flatText += '\n';
      return;
    }

    for (const child of node.childNodes) {
      walk(child);
    }
  }

  walk(root);

  return Object.freeze({ flatText, charToNode });
})();
