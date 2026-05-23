---
name: Sessions 77–80 — TEI Fidelity Improvements
description: Addresses all confirmed rendering gaps between the FRUS Explorer app
  and history.state.gov, identified by auditing app source against HistoryAtState
  GitHub repos and the live site during Session 77.
type: implementation
originSessionId: session-77
---

# Sessions 77–80: TEI Fidelity Improvements

Prepared after a systematic audit of the three-layer rendering pipeline
(`FRUSDocumentParser` → `ASTToRenderNodeConverter` → `FRUSDocumentRenderer`) against
the HistoryAtState transformation stack (TEI Publisher ODD `frus-web.xql` + CSS in
`hsg-shell/app/scss/_tei.scss`).

The audit confirmed **eleven gaps** across four severity levels.

---

## Confirmed Gap Inventory

### Critical — Content-Distorting

| ID | Element | App Behaviour | Website Behaviour |
|----|---------|--------------|------------------|
| G-01 | `<choice>` | Both `<sic>` (struck-through) and `<corr>` children rendered; text appears doubled | Only `<corr>` (preferred form) rendered; `<sic>` suppressed |
| G-02 | `<frus:attachment>` | Falls to `.unknown` → plain `VStack`; no visual break; attachment head indistinguishable from main document head | `<section class="attachment">` with `margin-top: 4em`; attachment `<head>` rendered as `tei-head6` (sans-serif, smaller) |

### High — Significant Visual Divergence

| ID | Element | App Behaviour | Website Behaviour |
|----|---------|--------------|------------------|
| G-03 | `<note rend="inline">` | `rend` attribute ignored; node → `.footnote`; content shown as a superscript footnote reference | Content rendered inline in text flow (no footnote number, no superscript); used for tab/enclosure labels in attachment heads |
| G-04 | `<hi rend="smallcaps">` | `macAttrString` comment: "no direct small-caps variant; render as normal"; iOS also renders as unstyled text | Uppercase letters at a reduced cap height; visually distinct from regular text |
| G-05 | `<head>` inside `<frus:attachment>` | Rendered with `.font(.system(size: 18, weight: .medium))` — identical to main document heading | Rendered as `tei-head6`: `h2` with `font-family: $font-sans` (sans-serif, secondary weight) |

### Medium — Noticeable but Not Content-Distorting

| ID | Element | App Behaviour | Website Behaviour |
|----|---------|--------------|------------------|
| G-06 | Document → attachment transition | Attachment content follows immediately after main document body at `blockSpacing` (8 pt) | `margin-top: 4em` (~64 pt) before the first `<frus:attachment>` |
| G-07 | Attachment `@n` / tab label | Not surfaced; `<note rend="inline"><hi rend="strong">Tab A</hi></note>` in attachment head not rendered correctly (blocked by G-03) | "Tab A" / "Enclosure" / "Attachment" label appears as bold inline text before the attachment's substantive heading |
| G-08 | Multiple `<frus:attachment>` per document | Sequential `.unknown` nodes share `blockSpacing` (8 pt) between last paragraph of one attachment and first heading of the next | Each additional attachment also receives `margin-top: 4em` separation |

### Low — Edge Case / Data Quality

| ID | Element | App Behaviour | Website Behaviour |
|----|---------|--------------|------------------|
| G-09 | `extractHeader()` title attribution | Iterates top-level AST nodes; safely skips attachment heads in practice, but becomes unreliable if a future `.attachment` AST node exposes its `.head` child at depth ≠ top-level | N/A (server-side, not applicable) |
| G-10 | `<titlePage>` (front-matter volumes) | `buildNode` returns `.unknown(name: "titlePage", ...)`; ASTToRenderNodeConverter also explicitly passes through as `.unknown`; content renders as unstyled block | Distinct layout: title page fields (title, author, publisher) arranged as a centred block with typographic hierarchy |
| G-11 | `<ab>` (anonymous block) | Falls to `buildNode` default → `.unknown` → children treated as inline in `blockOrInlineNodes` | Treated as a `<p>`-equivalent: a distinct paragraph-level block |

---

## Session Breakdown

---

### Session 77 — Inline Editorial Marks: `<choice>` and Small Caps

**Scope:** G-01, G-04  
**Effort:** Low (one session, ~2 hours). No new types; changes confined to
`buildNode` switch, `EmphasisStyle` rendering, and test fixtures.  
**Risk:** Low. Changes are isolated to two independent paths.

#### G-01: `<choice>` — Suppress `<sic>`, Render Only `<corr>`

**Root cause:** `buildNode("choice", ...)` falls to the `default:` case →
`.unknown(name: "choice", attributes: ..., children: [.sic(...), .corr(...)])`.
`ASTToRenderNodeConverter` passes both children through as `.sicText` (strikethrough)
and `.corrText` (normal). The reader sees doubled text.

**Fix — `FRUSDocumentParser.swift`, `buildNode` switch:**

```swift
case "choice":
    // Render only the preferred form. Preferred priority:
    //   1. <corr>  (corrected reading)
    //   2. <reg>   (regularised spelling — surfaces as .unknown("reg") child)
    //   3. first child (fallback)
    //
    // <sic> is suppressed entirely; its strikethrough form is already
    // visible to the user via the note that prompted the correction.
    let preferred: FRUSASTNode? = children.first { if case .corr = $0 { return true }; return false }
        ?? children.first { if case .unknown(let n, _, _) = $0 { return n == "reg" }; return false }
        ?? children.first
    if let preferred {
        // Unwrap the .corr wrapper — its children are the displayable content.
        if case .corr(let c) = preferred { return c.count == 1 ? c[0] : .unknown(name: "choice", attributes: [:], children: c) }
        return preferred
    }
    return nil
```

**No changes required** to `FRUSASTNode`, `ASTToRenderNodeConverter`, or
`FRUSDocumentRenderer` — the fix happens entirely in the parser.

**Test:** Add a fixture XML snippet `<choice><sic>colour</sic><corr>color</corr></choice>`
and assert that:
- Rendered text contains "color" exactly once
- Rendered text does not contain "colour"
- No `.sicText` node appears in the converted render tree

---

#### G-04: Small Caps — Apply Font Feature

**Root cause:** `macAttrString` comment at `FRUSDocumentRenderer.swift:275`:
`// AttributedString has no direct small-caps variant; render as normal.`
iOS `inlineTextNode` at line 794 also returns `inlineText(children)` unchanged.
`Font.smallCaps()` and `Font.lowercaseSmallCaps()` have been available since
macOS 12 / iOS 15 — both minimum deployment targets for this project.

**Fix — `FRUSDocumentRenderer.swift` (macOS `macAttrString` path, line 274):**

```swift
case .smallCapsText(let c):
    var a = macAttrString(c)
    a.font = .system(size: textSize.bodyFontSize).lowercaseSmallCaps()
    return a
```

**Fix — `FRUSDocumentRenderer.swift` (iOS `inlineTextNode`, line 794):**

```swift
case .smallCapsText(let children):
    return inlineText(children)
        .font(.system(size: textSize.bodyFontSize).lowercaseSmallCaps())
```

**`lowercaseSmallCaps()` vs `smallCaps()`:** `lowercaseSmallCaps` renders lowercase
letters as small caps while leaving uppercase letters at full cap height — the
typographically correct behaviour for `rend="smallcaps"` where the source text is
already uppercase (e.g. acronyms) mixed with lowercase prose.

**Test:** Add `<hi rend="smallcaps">NATO</hi>` fixture; assert render node is
`.smallCapsText`; assert the AttributedString (macOS) carries a `Font` with a
lowercase-small-caps feature flag set. (Font introspection is limited; a snapshot
test of the attributed string description is acceptable.)

---

#### Files to Modify — Session 77

| File | Change |
|------|--------|
| `FRUSExplorer/TEI/FRUSDocumentParser.swift` | Add `case "choice":` in `buildNode` |
| `FRUSExplorer/TEI/FRUSDocumentRenderer.swift` | Fix `.smallCapsText` in macOS `macAttrString` and iOS `inlineTextNode` |
| `FRUSExplorerTests/TEIParserTests.swift` | Choice and small-caps fixtures |

---

### Session 78 — Inline Note Rendering and `<frus:attachment>` Pipeline

**Scope:** G-02, G-03, G-05, G-06, G-07, G-08 (and G-09 as a consequence)  
**Effort:** Medium (one session, ~4–5 hours). New AST case, new render node case,
renderer changes on both platforms, converter update.  
**Risk:** Medium. Touches the full pipeline (parser → AST → converter → render node
→ renderer). The `<note>` transparency change is a behaviour change that affects
every `<note rend="inline">` in every document.

This session is best tackled in a clean sequence: parser → AST → converter →
render node → macOS renderer → iOS renderer → tests.

---

#### G-03: `<note rend="inline">` — Inline Rendering

**Root cause:** `buildNode("note", attributes:, children:)` at
`FRUSDocumentParser.swift:725` reads `attributes["type"]` for `FootnoteType` but
never reads `attributes["rend"]`. All `<note>` elements — including those marked
`rend="inline"` — become `.footnote(...)` nodes.

`<note rend="inline">` is used in FRUS TEI for two purposes:
1. Classification/security labels on document heads:
   `<note rend="inline"><hi rend="strong">Secret</hi></note>` (not a footnote)
2. Tab and enclosure labels in attachment heads:
   `<note rend="inline"><hi rend="strong">Tab A</hi></note>` (not a footnote)

**Fix — `FRUSDocumentParser.swift`, `isTransparent`:**

```swift
case "note":
    // Inline notes render in the text flow, not as footnotes.
    // Make them transparent so their children are hoisted to the parent frame
    // and rendered as ordinary inline content.
    return attributes["rend"] == "inline"
```

Adding this to `isTransparent` means `rend="inline"` note children (typically
`<hi rend="strong">` or plain text) flow directly into the surrounding inline context
without a footnote number. `rend="inline"` notes do NOT carry `@n` or `@xml:id`
attributes, so no footnote record is lost.

**No other file changes required** — once the note is transparent, its `<hi>` and
text children are handled by existing `.emphasis` / `.text` code paths.

**Test:** Fixture `<note rend="inline"><hi rend="bold">Secret</hi></note>` inside
a `<head>`. Assert:
- No `.footnote` AST node produced
- No `.footnoteMarker` render node produced
- The `.head` children contain a `.emphasis(.bold, ...)` node with text "Secret"

---

#### G-02, G-05, G-06, G-07, G-08: `<frus:attachment>` — Full Pipeline

**Root cause summary (from research agent confirmation):**

FRUS uses `<frus:attachment>` (namespace `http://history.state.gov/frus/ns/1.0`),
**not** `<div type="attachment">`. Foundation's `XMLParser` in non-namespace mode
delivers this as the literal element name `"frus:attachment"`. The element:
- Appears at the end of `<div type="document">` (member of `model.divBottomPart`)
- Cannot contain child `<tei:div>` (Schematron enforced)
- May have multiple siblings: one document can have several `<frus:attachment>` elements
- Carries no `@xml:id` in production volumes (the `@xml:id` requirement is experimental)
- Continues the parent document's footnote numbering sequence

Current app path: `buildNode("frus:attachment", ...)` → `default:` → `.unknown(name:
"frus:attachment", ...)` → `ASTToRenderNodeConverter` passes through as `.unknown` →
renderer `blockView(for:)` renders children as `VStack(spacing: blockSpacing)` — 8 pt
gap, no separator, attachment heading identical to main document heading.

**Implementation — five files in sequence:**

##### Step 1: `FRUSASTNode.swift` — New case

```swift
/// A sub-document attached to a FRUS document (`<frus:attachment>`).
///
/// Position: appears after all body content of the parent `<div type="document">`.
/// Multiple attachments may follow one another. `n` carries the `@n` attribute if
/// present (used for ordinal labels such as "1", "2"), though production volumes
/// typically omit it.
///
/// The element cannot contain `<tei:div>` children; its content model mirrors a
/// stripped `<div>`: `<head>`, `<opener>`, `<closer>`, `<p>`, `<note>`, `<pb>`, etc.
case attachment(n: String?, children: [FRUSASTNode])
```

##### Step 2: `FRUSDocumentParser.swift` — `buildNode` case

```swift
case "frus:attachment":
    return .attachment(n: attributes["n"], children: children)
```

Place this case **before** the `default:` fallthrough, grouped under a new
`// MARK: Attachments (Session 78)` comment.

##### Step 3: `FRUSRenderNode.swift` — New case

```swift
/// A visual attachment block derived from `<frus:attachment>`.
///
/// Rendered with a prominent top separator (`padding(.top, 32)` + `Divider()`)
/// and a secondary heading style for any `.heading` children, matching the
/// website's `.attachment { margin-top: 4em }` and `tei-head6` CSS rules.
case attachmentBlock(n: String?, children: [FRUSRenderNode])
```

##### Step 4: `ASTToRenderNodeConverter.swift` — Handle `.attachment`

Add a case in `convertNode`:

```swift
case .attachment(let n, let children):
    // Convert <head> children to .attachmentHeading so the renderer can
    // apply secondary heading style without passing context through blockView.
    let convertedChildren: [FRUSRenderNode] = children.flatMap { child -> [FRUSRenderNode] in
        if case .head(let headChildren) = child {
            return [.attachmentHeading(convertNodes(headChildren))]
        }
        return convertNode(child)
    }
    return [.attachmentBlock(n: n, children: convertedChildren)]
```

This produces a new `.attachmentHeading` render node for each `<head>` inside the
attachment. Add `case attachmentHeading([FRUSRenderNode])` to `FRUSRenderNode`.

##### Step 5: `FRUSDocumentRenderer.swift` — Render both platforms

**macOS `blockView(for:)` — add case:**

```swift
case .attachmentBlock(_, let children):
    let normalized = blockOrInlineNodes(children)
    VStack(alignment: .leading, spacing: blockSpacing) {
        // ~4em top margin + visual separator, matching .attachment { margin-top: 4em }
        Divider()
        ForEach(Array(normalized.enumerated()), id: \.offset) { _, child in
            AnyView(blockView(for: child))
        }
    }
    .padding(.top, 32)
```

**macOS `blockView(for:)` — add `.attachmentHeading` case:**

```swift
case .attachmentHeading(let children):
    // Secondary heading: matches website tei-head6 (sans-serif, smaller than
    // the main document heading at 18pt medium).
    inlineText(children)
        .font(.system(size: 14, weight: .semibold, design: .default))
        .padding(.bottom, 2)
```

**`isBlockNode` — add new cases:**

```swift
case .attachmentBlock, .attachmentHeading:
    return true
```

Apply the same pattern in the private `blockView(_:)` used for recursive rendering
and in `extractInlineContent` / `inlineText` exclusion lists.

**iOS renderer:** Apply equivalent changes using the iOS `blockView` and
`inlineTextNode` paths. The visual constants (padding, font sizes) may differ
slightly from macOS to match platform conventions, but the structure is identical.

---

#### G-09 as a Consequence

With `.attachment` as a proper AST case (not `.unknown`), the `.head` inside an
attachment is a grandchild of `.attachment`, not a direct child of the document's
top-level node list. `extractHeader(from nodes: [FRUSASTNode])` iterates only the
top-level nodes and never descends into `.attachment`. G-09 is resolved automatically.

---

#### Files to Modify — Session 78

| File | Change |
|------|--------|
| `FRUSExplorer/TEI/FRUSDocumentParser.swift` | Add `isTransparent` case for `note[@rend="inline"]`; add `buildNode` case for `frus:attachment` |
| `FRUSExplorer/TEI/FRUSASTNode.swift` | Add `case attachment(n: String?, children: [FRUSASTNode])` |
| `FRUSExplorer/TEI/ASTToRenderNodeConverter.swift` | Handle `.attachment`; produce `.attachmentHeading` for head children |
| `FRUSExplorer/TEI/FRUSRenderNode.swift` | Add `case attachmentBlock(n: String?, children: [FRUSRenderNode])` and `case attachmentHeading([FRUSRenderNode])` |
| `FRUSExplorer/TEI/FRUSDocumentRenderer.swift` | Handle `.attachmentBlock` and `.attachmentHeading` in all switch sites (macOS and iOS); update `isBlockNode`, `extractInlineContent`, inline-text exclusion lists |
| `FRUSExplorerTests/TEIParserTests.swift` | Fixture: document with one and two attachments; assert separator, heading style, tab label |
| `FRUSExplorerTests/RendererTests.swift` (if it exists) | Snapshot / structural test for attachment render output |

---

### Session 79 — Remaining TEI Fidelity: `<titlePage>`, `<ab>`, and Audit Sweep

**Scope:** G-10, G-11, plus a final sweep for any gaps surfaced during sessions 77–78  
**Effort:** Low (one session, ~2–3 hours).  
**Risk:** Low. Front-matter volumes containing `<titlePage>` are not browsed the
same way as historical-document volumes; these are refinements, not bug fixes.

---

#### G-10: `<titlePage>` — Structured Front-Matter Rendering

**Root cause:** `buildNode("titlePage", ...)` at line 783 returns
`.unknown(name: "titlePage", ...)`. `ASTToRenderNodeConverter` explicitly also
converts `.titlePage` to `.unknown(name: "titlePage", ...)` (line 196–197). The
comment there reads: `// titlePage rendered as unknown — children still visible`.

Front-matter volumes (prefaces, introductions) contain `<titlePage>` with children:
`<docTitle>`, `<docAuthor>`, `<docImprint>`, etc. The website centres these and
applies typographic hierarchy.

**Fix — `FRUSDocumentParser.swift`:** The existing `case "titlePage"` already returns
`.titlePage(children)`. The issue is in the converter.

**Fix — `ASTToRenderNodeConverter.swift`, `.titlePage` case (lines 196–197):**

```swift
case .titlePage(let children):
    // Render title page as a centered block with distinct spacing between fields.
    // Wrap in an attachmentBlock-style container so the renderer can apply
    // centred alignment. Re-use the existing unknown fallback for now, but
    // override the container alignment in the renderer.
    return [.titlePageBlock(convertNodes(children))]
```

**Fix — `FRUSRenderNode.swift`:** Add `case titlePageBlock([FRUSRenderNode])`.

**Fix — `FRUSDocumentRenderer.swift` (macOS `blockView(for:)`):**

```swift
case .titlePageBlock(let children):
    let normalized = blockOrInlineNodes(children)
    VStack(alignment: .center, spacing: 12) {
        ForEach(Array(normalized.enumerated()), id: \.offset) { _, child in
            AnyView(blockView(for: child))
        }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 24)
```

**Note:** `<titlePage>` children (`<docTitle>`, `<docAuthor>`, etc.) are themselves
unknown elements whose children are text/emphasis nodes — they render as inline text
blocks. This gives readable output without requiring individual cases for each
title-page sub-element. A future session can refine the hierarchy if needed.

---

#### G-11: `<ab>` (Anonymous Block) — Paragraph-Level Treatment

**Root cause:** `<ab>` (anonymous block, used for headings and captions that don't
fit `<head>`, `<label>`, or `<p>`) falls to `buildNode` default → `.unknown`.
Its children are inline text/emphasis nodes. In `blockOrInlineNodes`, `.unknown` with
inline children gets collected into an implicit paragraph — so rendering is actually
reasonable in most cases, just not explicitly intentional.

**Fix — `FRUSDocumentParser.swift`, `buildNode`:** Add an explicit case:

```swift
case "ab":
    return .paragraph(children: children)
```

This maps `<ab>` to `.paragraph`, which is the semantic equivalent: a block of prose
without the structural role of `<p>`. No new types required.

---

#### Session 79 Audit Sweep

Before closing Session 79, re-parse a cross-section of volumes (early Cold War
narrative volumes, 1970s NSC document-heavy volumes, and at least one volume with
known attachment-heavy documents) and verify:

- [ ] No `.unknown` nodes appear for the elements addressed in sessions 77–78
- [ ] Attachment documents render with visible separator and distinct heading style
  on both platforms
- [ ] `rend="inline"` notes in attachment heads produce the tab/enclosure label inline
- [ ] Small-caps passages are visually distinct from body text
- [ ] `<choice>` passages render clean text with no strikethrough duplication
- [ ] `<titlePage>` content in preface/introduction front matter is centred
- [ ] `<ab>` content flows as a paragraph block

**Files to Modify — Session 79**

| File | Change |
|------|--------|
| `FRUSExplorer/TEI/FRUSDocumentParser.swift` | Add `case "ab": return .paragraph(children:)` |
| `FRUSExplorer/TEI/ASTToRenderNodeConverter.swift` | Fix `.titlePage` case |
| `FRUSExplorer/TEI/FRUSRenderNode.swift` | Add `case titlePageBlock([FRUSRenderNode])` |
| `FRUSExplorer/TEI/FRUSDocumentRenderer.swift` | Handle `.titlePageBlock` on both platforms; update `isBlockNode` and exclusion lists |
| `FRUSExplorerTests/TEIParserTests.swift` | Fixtures for `<ab>` and `<titlePage>` |

---

### Session 80 — Documentation and Version History Update

**Scope:** Documentation only — no code changes.  
**Effort:** Low (one session, ~1 hour).  
**Risk:** None.

Update version history comments in all modified files to reference sessions 77–79.
Update `DEVELOPMENT-PLAN.md` to add sessions 77–80 to the session table. Update
`Planning/75-Development-Backlog.md` to reflect completed items if any overlapped.

---

## Session Dependency Summary

```
76 (frus:doc-dateTime) ──► 77 (choice, smallcaps)
                        ──► 78 (inline notes, frus:attachment) ──► 79 (titlePage, ab, sweep)
                                                                 └──► 80 (docs)
```

Sessions 77 and 78 are independent of each other. Either can run first without
affecting the other, though 78 is higher value and should be prioritised if time
is constrained.

---

## Reference: Key File Locations

| Component | File |
|-----------|------|
| TEI parser (Layer 1) | `FRUSExplorer/TEI/FRUSDocumentParser.swift` |
| AST node types | `FRUSExplorer/TEI/FRUSASTNode.swift` |
| AST → render node (Layer 2) | `FRUSExplorer/TEI/ASTToRenderNodeConverter.swift` |
| Render node types | `FRUSExplorer/TEI/FRUSRenderNode.swift` |
| Renderer — macOS + iOS (Layer 3) | `FRUSExplorer/TEI/FRUSDocumentRenderer.swift` |
| Indexing / header extraction | `FRUSExplorer/Search/IndexingPipeline.swift` |
| Parser unit tests | `FRUSExplorerTests/TEIParserTests.swift` |

---

## Website Rendering Reference (for visual verification)

| Website CSS rule | App equivalent |
|----------------|----------------|
| `.attachment { margin-top: 4em; }` | `.padding(.top, 32)` on `.attachmentBlock` container |
| `h2.tei-head6 { font-family: $font-sans; }` | `.font(.system(size: 14, weight: .semibold, design: .default))` on `.attachmentHeading` |
| `<hi rend="smallcaps">` → small-caps CSS | `.font(.system(size:).lowercaseSmallCaps())` |
| `<choice>` → `<corr>` only | `buildNode` returns preferred child, suppresses `<sic>` |
| `<note rend="inline">` → inline text | `isTransparent` returns `true` for `rend == "inline"` |
