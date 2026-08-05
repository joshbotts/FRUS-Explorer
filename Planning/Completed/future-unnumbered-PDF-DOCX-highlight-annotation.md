# Future (Unnumbered): PDF and DOCX Inline Highlight Annotation

**Status:** Implemented (PDF + DOCX) — see "Implementation notes" below for deviations from the original plan; manual verification items in the testing checklist remain outstanding  
**Label:** future unnumbered  
**Priority:** Medium (completes the highlight annotation feature for all three export formats)

---

## Background

Session 153 added inline highlight annotation to the HTML collection exporter. When a user exports a collection with `options.applyHighlights = true`, the `FRUSRenderNodeHTMLSerializer` post-processes the rendered HTML to inject `<mark class="hl-{color}">` elements at the flat-text character offsets stored in `DocumentHighlight` records. Five CSS colours are defined (`hl-yellow`, `hl-green`, `hl-blue`, `hl-pink`, `hl-orange`).

PDF and DOCX were deferred from Session 153. This session implements the remaining two formats.

---

## What already exists

- `CollectionExportDocument.highlights: [ExportHighlight]` — populated when `options.applyHighlights == true`; carries `startOffset`, `endOffset`, and `color` for every `DocumentHighlight` on each document
- `DocumentHighlight.Color` enum with five cases: `.yellow`, `.green`, `.blue`, `.pink`, `.orange`
- `ExportHighlight` struct (defined in `CollectionExporter.swift`)
- The flat-text coordinate system: offsets index into the same character space as `FRUSRenderNode.buildFlatText`

---

## PDF implementation

**File:** `PDFCollectionExporter.swift`

The PDF renderer uses `NSAttributedString` and `CoreText` (`CTFramesetter`). The approach:

1. After building the `NSAttributedString` body (via `renderModelToAttributedString(_:)` or the flat-text fallback), apply background-color attributes over the highlight ranges.
2. Map flat-text character offsets → `NSAttributedString` character indices. The flat-text and attributed string share the same character sequence (the attributed string is derived from the same render nodes), so the mapping is 1-to-1 for non-entity text. If the exporter uses the flat-text fallback (`doc.bodyText`), the same offsets apply directly.
3. For each `ExportHighlight`:
   ```swift
   let nsRange = NSRange(location: hl.startOffset,
                         length: hl.endOffset - hl.startOffset)
   attrStr.addAttribute(.backgroundColor,
                         value: hl.color.cgColor,
                         range: nsRange)
   ```
4. Use a safe clamp: `min(nsRange.upperBound, attrStr.length)` to guard against stale offsets.

**Colour mapping** (`DocumentHighlight.Color` → `CGColor`):
```
.yellow → CGColor(red: 1.00, green: 0.90, blue: 0.20, alpha: 0.45)
.green  → CGColor(red: 0.31, green: 0.78, blue: 0.31, alpha: 0.35)
.blue   → CGColor(red: 0.31, green: 0.59, blue: 0.94, alpha: 0.35)
.pink   → CGColor(red: 0.94, green: 0.31, blue: 0.63, alpha: 0.30)
.orange → CGColor(red: 1.00, green: 0.63, blue: 0.12, alpha: 0.40)
```

**Where to add:** in `drawDocumentSection(ctx:doc:options:pageNumber:)`, after building `bodyAttrStr` from the render model and before passing it to the `CTFramesetter`. Convert to `NSMutableAttributedString`, apply highlights, then pass to `CTFramesetterCreateWithAttributedString`.

**Rich render path note:** `renderModelToAttributedString(_:)` returns an attributed string derived from the render model. The character offsets from `ExportHighlight` are flat-text positions that correspond to the attributed string's character indices, provided the attributed string uses the same traversal order as `buildFlatText`. Verify this assumption holds (it should, since both walk the same render-node tree in the same order).

---

## DOCX implementation

**File:** `DocxCollectionExporter.swift`

DOCX uses the OOXML `<w:highlight>` element on `<w:run>` elements. The highlight element accepts a named colour from a fixed OOXML palette.

**Colour mapping** (`DocumentHighlight.Color` → OOXML `<w:highlight w:val="..."/>`):
```
.yellow → "yellow"
.green  → "green"
.blue   → "cyan"   (closest OOXML named colour)
.pink   → "magenta"
.orange → "yellow" (OOXML has no orange; yellow is the closest)
```
Full OOXML palette: `black`, `blue`, `cyan`, `darkBlue`, `darkCyan`, `darkGray`, `darkGreen`, `darkMagenta`, `darkRed`, `darkYellow`, `green`, `lightGray`, `magenta`, `none`, `red`, `white`, `yellow`.

**Where to add:** in `renderModelToDocxParagraphs(_:ctx:)`, when emitting `<w:run>` elements for text nodes. The DOCX renderer needs to know which character ranges are highlighted so it can split text runs at highlight boundaries and add `<w:highlight>` to the highlighted runs.

**Approach:**
1. Collect all highlights sorted by `startOffset`.
2. When visiting a text node at flat-text position `[pos, pos+len)`, check if any highlight overlaps.
3. If so, split the text into up to three segments: pre-highlight, highlighted, post-highlight — each emitted as its own `<w:run>`. The highlighted run includes `<w:rPr><w:highlight w:val="{colour}"/></w:rPr>`.
4. Track `currentFlatPos` as a counter through the node traversal (same approach as the HTML serializer's `injectHighlights`).

The DOCX renderer currently builds paragraphs by walking render nodes. A `currentFlatPos: Int` counter needs to thread through the walk. This is the main structural change.

---

## Implementation notes (deviations from the original plan)

- **The "1-to-1 offset mapping" assumption above is incorrect.** Both
  `renderModelToAttributedString` (PDF) and `renderModelToDocxParagraphs` (DOCX)
  insert separator characters that `appendFlatText` does not count (list bullets,
  table-cell `" | "` joins, footnote labels, supplied-text brackets, figure
  captions, paragraph spacing). Naive character-index translation would misalign
  highlights. Instead, a shared `HighlightPaintTracker` (in `CollectionExporter.swift`)
  walks exported text in the same traversal order and at the same leaf points as
  `appendFlatText` (`.plainText`, `.formulaText`, `.lineBreak`), partitioning each
  chunk into highlighted/unhighlighted sub-spans as it goes.
- **`DocumentHighlight.Color` has 4 cases, not 5** — there is no `.orange`. The
  testing checklist below has been corrected accordingly; `mark.hl-orange` in
  `FRUSRenderNodeHTMLSerializer.highlightCSS` is dead CSS referencing a
  nonexistent case.
- **PDF**: `CTFrameDraw` ignores `NSAttributedString.Key.backgroundColor` — it's a
  Cocoa text-system attribute that bare CoreText doesn't render. Highlight
  backgrounds are painted manually as filled rectangles (`drawFrameWithHighlights`)
  using `CTFrameGetLines`/`CTLineGetStringRange`/`CTLineGetTypographicBounds`/
  `CTLineGetOffsetForStringIndex`, drawn before `CTFrameDraw`. A custom attribute
  key (`FRUSHighlightBackgroundColor`) carries a `HighlightColorBox` wrapper
  struct around `CGColor` (a bare `as? CGColor` conditional cast is a compiler
  error under this project's strict settings — "conditional downcast … will
  always succeed").
- **DOCX**: highlighted leaf text is split into separate `<w:r>` runs at
  highlight boundaries, each carrying `<w:rPr><w:highlight w:val="…"/></w:rPr>`.
  OOXML's named-highlight palette has no close blue/pink equivalents, so `.blue`
  maps to `cyan` and `.pink` to `magenta` (see `DocumentHighlight.ooxmlHighlightName`).
- **Footnote bodies are excluded from painting/tracking in both formats** —
  `model.footnotes` falls outside the flat-text coordinate space that highlight
  offsets are defined over (only `model.bodyNodes` is walked by `appendFlatText`),
  so threading the tracker into footnote rendering would both misalign positions
  and paint the wrong spans. PDF clears `highlightPaint = nil` before rendering
  footnotes; DOCX always passes `tracker: nil` down the `inlineOrBlockRuns` path.

---

## Testing checklist

- [ ] Export a collection with yellow, green, blue, and pink highlights to PDF — verify all four colours appear as background shading on the correct text spans
- [ ] Export same collection to DOCX — open in Word/Pages and verify highlight colours are visible on the correct words (note: `.blue` renders as cyan and `.pink` as magenta — OOXML has no closer named equivalents)
- [ ] Export a document with no highlights — verify `applyHighlights = true` produces no unexpected markup
- [ ] Export with highlights that span element boundaries (e.g., across `<em>` or a footnote marker) — verify the export doesn't crash and the highlighted region is still visible
- [ ] Verify stale highlights (where `startOffset` or `endOffset` exceeds the document length) are silently clamped without crashing

---

## Files modified

- `PDFCollectionExporter.swift` — `drawDocumentSection`, `renderModelToAttributedString`,
  `inlineNodeToAttributedString`, `blockNodeToAttributedString` (`.tableBlock` rewritten
  to preserve attributed strings instead of flattening to plain text); new
  `highlightPaint: HighlightPaintTracker?` instance property, `HighlightColorBox`,
  `paintedString(_:attrs:)`, `drawFrameWithHighlights(_:attrStr:in:)`
- `DocxCollectionExporter.swift` — `documentBodyXML`, `renderModelToDocxParagraphs`,
  `blockNodeToDocxXML`, `inlineRunsXML`, `inlineNodeRunXML`, `tableToDocxXML` all gained
  a threaded `tracker: HighlightPaintTracker?` parameter; new `runsXML(for:props:tracker:)`
  and `highlightedRPrXML(props:color:)` helpers; `inlineOrBlockRuns` (footnote path)
  always passes `tracker: nil`
- `CollectionExporter.swift` — added `HighlightPaintTracker` (shared by both exporters)
- `DocumentHighlight.swift` — added `cgColor: CGColor` (PDF) and
  `ooxmlHighlightName: String` (DOCX) color-mapping helpers

---

## Related

- Session 153: HTML highlight annotation implemented (`FRUSRenderNodeHTMLSerializer.injectHighlights`)
- `DocumentHighlight.swift`: model definition, Color enum
- `CollectionExporter.swift`: `ExportHighlight` struct, `HighlightPaintTracker`
