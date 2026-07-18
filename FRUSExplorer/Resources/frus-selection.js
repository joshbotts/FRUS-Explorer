/**
 * frus-selection.js
 * FRUS Explorer WebKit text-selection → flat-text offset bridge.
 *
 * Injected as a WKUserScript (.atDocumentEnd) after frus-offset-engine.js.
 * The Swift source of truth is the embedded constant kSelectionJS in
 * FRUSWebViewConfiguration.swift — keep the two in sync when editing.
 * `SelectionScriptParityTests` asserts the body below (everything after this
 * JSDoc header) is byte-identical to that constant, so they cannot drift.
 *
 * ## Purpose
 * Listens for the native `selectionchange` DOM event, maps the browser
 * selection to the flat-text offset space via FRUSOffsets.charToNode, and
 * posts the result to the Swift `selectionChanged` message handler.
 *
 * Swift receives one of:
 *   { start, end, text, rect, scale }                    — in-document selection: valid flat-text
 *                                               offsets (start >= 0, end > start) + raw text;
 *                                               create-highlight button enabled.
 *   { start: -1, end: -1, text, blockText, rect, scale } — out-of-document (footnote) selection: the
 *                                               offset engine can't map the nodes, so offsets
 *                                               are sentinel; `text` is the raw selection and
 *                                               `blockText` is the enclosing footnote body,
 *                                               used to characterise the footnote's citations.
 *                                               Highlight creation disabled; NARA lookup enabled.
 *   { start: -1, end: -1 }                     — selection cleared; button disabled.
 * `rect` = { x, y, w, h } is the selection's bounding box in web-view viewport CSS px and
 * `scale` = visualViewport.scale — together they anchor the floating selection bar.
 *
 * A separate `selectionScrolled` message (empty body) fires, throttled to one per frame, while
 * a selection is live and the document scrolls inside the web view (selectionchange does not
 * re-fire on scroll), so the viewport-anchored bar can dismiss before its rect goes stale.
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
 *   1.1 — #269: footnote selections also send `text` and the enclosing `blockText`
 *          (reconciles this file with kSelectionJS, which had already added `text`)
 *   1.2 — Research rail Phase A: selections carry a bounding `rect` + `scale`, and a throttled
 *          `selectionScrolled` hide signal is posted, to anchor/dismiss the floating selection bar
 */

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
window.addEventListener('scroll', () => {
  if (selectionScrollScheduled) return;
  selectionScrollScheduled = true;
  requestAnimationFrame(() => {
    selectionScrollScheduled = false;
    const sel = window.getSelection();
    if (sel && !sel.isCollapsed) {
      try { webkit.messageHandlers.selectionScrolled.postMessage({}); } catch (_) {}
    }
  });
}, { passive: true, capture: true });
