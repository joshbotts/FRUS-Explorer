/**
 * frus-highlights.js
 * FRUS Explorer CSS Custom Highlight API renderer.
 *
 * Injected as a WKUserScript (.atDocumentEnd) after frus-offset-engine.js.
 * The Swift source of truth is the embedded constant kHighlightsJS in
 * FRUSWebViewConfiguration.swift — keep the two in sync when editing.
 *
 * ## Purpose
 * Exposes window.FRUSHighlights.render(highlights) which Swift calls after
 * every page load to paint DocumentHighlight ranges using the CSS Custom
 * Highlight API. Depends on window.FRUSOffsets.charToNode built by
 * frus-offset-engine.js.
 *
 * ## Highlight data format
 * `highlights` is a JSON array of objects matching DocumentHighlight.HighlightDTO:
 *   { startOffset: number, endOffset: number, color: string, isStale: boolean }
 *
 * ## CSS Custom Highlight API
 * One Highlight object is created per color group and registered under:
 *   frus-yellow, frus-green, frus-blue, frus-pink  — normal highlights
 *   frus-stale                                     — version-mismatched highlights
 *
 * Corresponding ::highlight() rules are in HTMLTemplate.documentCSS (Session 144).
 *
 * Session history:
 *   1.0 — Session 144: initial implementation
 */

/**
 * Builds a DOM Range array for the character range [start, end) using the
 * charToNode map produced by frus-offset-engine.js.
 *
 * @param {number} start - Inclusive start offset (Unicode scalar position).
 * @param {number} end   - Exclusive end offset.
 * @returns {Range[]} Array with 0 or 1 Range objects.
 */
function buildRanges(start, end) {
  if (!window.FRUSOffsets) return [];
  const map = window.FRUSOffsets.charToNode;
  if (start >= map.length || end > map.length || start >= end) return [];

  const range = new Range();
  // Start: at the beginning of the start character's local offset
  range.setStart(map[start].node, map[start].localOffset);
  // End: after the last character (end-1), so localOffset + 1
  const endEntry = map[end - 1];
  range.setEnd(endEntry.node, endEntry.localOffset + 1);
  return [range];
}

window.FRUSHighlights = {
  /**
   * Clears all existing CSS highlights and renders the supplied array.
   * Called by Swift after every page load and whenever highlights change.
   *
   * @param {Array<{startOffset:number, endOffset:number, color:string, isStale:boolean}>} highlights
   */
  render(highlights) {
    // Clear existing highlights before repainting
    if (typeof CSS !== 'undefined' && CSS.highlights) {
      CSS.highlights.clear();
    } else {
      return; // CSS Custom Highlight API not available — no-op
    }

    if (!highlights || !highlights.length) return;

    /** @type {Object.<string, Range[]>} */
    const groups = {};

    for (const h of highlights) {
      const ranges = buildRanges(h.startOffset, h.endOffset);
      if (!ranges.length) continue;
      const key = h.isStale ? 'frus-stale' : `frus-${h.color}`;
      if (!groups[key]) groups[key] = [];
      groups[key].push(...ranges);
    }

    for (const [name, ranges] of Object.entries(groups)) {
      CSS.highlights.set(name, new Highlight(...ranges));
    }
  }
};
