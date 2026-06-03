/**
 * frus-selection.js
 * FRUS Explorer WebKit text-selection → flat-text offset bridge.
 *
 * Injected as a WKUserScript (.atDocumentEnd) after frus-offset-engine.js.
 * The Swift source of truth is the embedded constant kSelectionJS in
 * FRUSWebViewConfiguration.swift — keep the two in sync when editing.
 *
 * ## Purpose
 * Listens for the native `selectionchange` DOM event, maps the browser
 * selection to the flat-text offset space via FRUSOffsets.charToNode, and
 * posts the result to the Swift `selectionChanged` message handler.
 *
 * Swift receives { start: number, end: number } where:
 *   start >= 0, end > start  → valid selection; create-highlight button enabled
 *   start = -1               → selection cleared; button disabled
 *
 * ## Reverse mapping
 * rangeEndpointToOffset() is the inverse of the forward-mapping used by
 * frus-highlights.js buildRanges(). It performs a linear scan of
 * FRUSOffsets.charToNode to find the character index for a given
 * {textNode, localOffset} pair. O(n) in document length; imperceptible for
 * typical FRUS documents (< 50,000 chars) and typical selections.
 *
 * Session history:
 *   1.0 — Session 145: initial implementation
 */

/**
 * Maps a DOM {node, localOffset} pair to a flat-text character index.
 * Returns -1 if not found (e.g. the endpoint is in a data-skip subtree).
 *
 * @param {Node}   node        — The DOM node (Text or BR element).
 * @param {number} localOffset — Offset within `node.nodeValue`.
 * @returns {number}
 */
function rangeEndpointToOffset(node, localOffset) {
  if (!window.FRUSOffsets) return -1;
  const map = window.FRUSOffsets.charToNode;
  for (let i = 0; i < map.length; i++) {
    if (map[i].node === node && map[i].localOffset === localOffset) return i;
  }
  return -1;
}

/**
 * Posts a selection-cleared message to Swift.
 */
function postCleared() {
  try {
    webkit.messageHandlers.selectionChanged.postMessage({ start: -1, end: -1 });
  } catch (_) { /* handler not registered in non-app contexts */ }
}

document.addEventListener('selectionchange', () => {
  const sel = window.getSelection();

  if (!sel || sel.isCollapsed || !window.FRUSOffsets) {
    postCleared();
    return;
  }

  const range = sel.getRangeAt(0);
  const start = rangeEndpointToOffset(range.startContainer, range.startOffset);
  const end   = rangeEndpointToOffset(range.endContainer,   range.endOffset);

  if (start >= 0 && end > start) {
    try {
      webkit.messageHandlers.selectionChanged.postMessage({ start, end });
    } catch (_) { /* non-app context */ }
  } else {
    // Selection exists but endpoints aren't in the offset map
    // (e.g. selected text inside a data-skip element). Clear the state.
    postCleared();
  }
});
