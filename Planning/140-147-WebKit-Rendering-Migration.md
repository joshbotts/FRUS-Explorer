---
name: Sessions 140–147 — WebKit Document Rendering Migration
description: Replace FRUSDocumentRenderer (SwiftUI VStack/LazyVStack path) and
  DocumentHighlightTextView (NSTextView/UITextView dual-render path) with a single
  WKWebView renderer backed by a new FRUSRenderNodeHTMLSerializer. Adopts the HTML
  popover API for inline footnotes, native colspan/rowspan tables, and the CSS
  Custom Highlight API for passage highlights — eliminating the dual-render problem
  and the 646-line platform-specific text-view wrapper. The FRUSRenderNode pipeline
  and SwiftData highlight schema are preserved unchanged.
type: implementation
originSessionId: session-128
---

# Sessions 140–147: WebKit Document Rendering Migration

## Background and Motivation

The current document rendering system has two structurally separate layers that
both interpret the same `FRUSRenderNode` tree for the same document:

- **Layer A — `FRUSDocumentRenderer`** (1,117 lines): Converts render nodes to
  SwiftUI views. Handles layout, typography, inline formatting, and interactive
  element dispatch via `frusexplorer://` custom-URL attributes in
  `AttributedString`.
- **Layer B — `DocumentHighlightTextView`** (646 lines): A parallel
  `NSTextView` / `UITextView` wrapper that rebuilds the same document as a flat
  `NSMutableAttributedString` to support text selection and highlight overlay.
  Uses a character-offset model (`startOffset: Int`, `endOffset: Int`) anchored
  to a SHA-256 hash of the flat document text (`renderingVersion`).

Problems this causes:
- Any change to document structure must be reflected in both layers independently.
- Text selection (Layer B) and visual rendering (Layer A) are separate views that
  the user perceives as one, producing subtle inconsistencies in font size,
  spacing, and line breaks.
- Tables silently discard `colspan`/`rowspan` because SwiftUI's `HStack` layout
  cannot express merged cells.
- Footnotes appear in a separate section at the bottom of the document; there is
  no inline popover display.

**Decision:** Replace both layers with a single `WKWebView` displaying HTML
generated in-app from the existing `FRUSRenderNode` tree. The WebKit layout engine
handles all text layout, selection, tables, and the CSS Custom Highlight API
renders highlights. The `FRUSRenderNode` pipeline, all SwiftData models, and the
character-offset highlight schema remain unchanged.

This approach was evaluated and approved after confirming that:
1. The CSS Custom Highlight API (Safari 17.2+) is fully available at the iOS 26 /
   macOS 26 deployment target.
2. The character-offset model can be re-implemented faithfully in JavaScript by
   mirroring the Swift DFS traversal rules using `data-skip` attributes on
   offset-invisible elements.
3. The HTML popover attribute (Safari 17+) provides native inline footnotes with
   no JavaScript.
4. `FRUSRenderNodeHTMLSerializer` can share its template with
   `HTMLCollectionExporter`, eliminating the divergent HTML-generation paths.

---

## Work Item Summary

| Session | Title | Effort | Risk | Depends On |
|---------|-------|--------|------|------------|
| 140 | HTML Serializer — Core | Medium | Low | 81, 128 |
| 141 | WKWebView Wrapper & Theming | Medium | Medium | 140 |
| 142 | Interactive Elements & Document View Migration | Medium | Medium | 141 |
| 143 | JS Flat-Text Offset Engine | Medium | High | 142 |
| 144 | CSS Custom Highlight API — Rendering | Medium | Medium | 143 |
| 145 | Highlight Selection & Creation | Medium | Medium | 144 |
| 146 | Collection Export Unification | Low–Medium | Low | 140, 128 |
| 147 | Legacy Renderer Removal, Accessibility & Testing | Medium | Low | 142–146 |

Sessions 140–142 and 135 are the lower-risk track (new code alongside existing
code). Sessions 143–145 are the highlight system rewrite; they carry higher risk
and should be done in sequence. Session 147 is cleanup and cannot begin until all
prior sessions are complete and stable.

---

## Session Breakdown

---

### Session 140 — HTML Serializer: Core

**Scope:** Build `FRUSRenderNodeHTMLSerializer`, a new type that accepts a
`FRUSDocumentRenderModel` and produces a self-contained HTML fragment string
(no `<html>`/`<body>` wrapper). This is the foundation for both the document view
(Sessions 141–142) and the collection export unification (Session 146).  
**Effort:** Medium (one session). Mostly mechanical translation of the existing
render-node → SwiftUI mapping to render-node → HTML string.  
**Risk:** Low. Purely additive new code. Nothing is deleted or changed in this
session.

#### New File

**`FRUSExplorer/TEI/FRUSRenderNodeHTMLSerializer.swift`**

```swift
/// Converts a FRUSDocumentRenderModel into a self-contained HTML fragment.
///
/// The output is a `<div class="frus-document">` containing the document body
/// followed by a footnote section. It is designed to be embedded inside an
/// HTML template that supplies `<html>`, `<head>`, and `<body>` wrappers with
/// the app's CSS.
///
/// Offset-invisible elements (pageBreak, footnoteMarker, figureBlock, and the
/// inline markers within footnoteBody) are emitted with `data-skip="1"` so that
/// the JavaScript flat-text DFS in Session 143 can apply the same skip rules as
/// ASTToRenderNodeConverter.renderingVersion(for:).
struct FRUSRenderNodeHTMLSerializer {
    func serialize(_ model: FRUSDocumentRenderModel) -> String
}
```

#### Node-to-HTML Mapping

| Render Node | HTML Output |
|-------------|-------------|
| `.heading(children)` | `<h2 class="doc-heading">…</h2>` |
| `.dateline(children)` | `<p class="dateline">…</p>` |
| `.paragraph(children)` | `<p class="body">…</p>` |
| `.letterOpener(children)` | `<div class="letter-opener">…</div>` |
| `.letterCloser(children)` | `<div class="letter-closer">…</div>` |
| `.salutation(children)` | `<p class="salutation">…</p>` |
| `.editorialNoteBlock(children)` | `<div class="editorial-note">…</div>` |
| `.titlePageBlock(children)` | `<div class="title-page">…</div>` |
| `.attachmentBlock(n, children)` | `<section class="attachment" data-n="n">…</section>` |
| `.attachmentHeading(children)` | `<h3 class="attachment-heading">…</h3>` |
| `.tableBlock(rows)` | `<table class="frus-table">` + rows below |
| `.tableRow(cells)` | `<tr>` + cells |
| `.tableCell(rSpan, cSpan, children)` | `<td rowspan="rSpan" colspan="cSpan">…</td>` |
| `.listBlock(.ordered, items)` | `<ol class="frus-list">` + `<li>…</li>` per item |
| `.listBlock(.unordered, items)` | `<ul class="frus-list">` + `<li>…</li>` per item |
| `.listBlock(.simple, items)` | `<ul class="frus-list simple">` + `<li>…</li>` per item |
| `.figureBlock(altText)` | `<figure data-skip="1"><figcaption>altText</figcaption></figure>` |
| `.pageBreak(pageNumber)` | `<span class="page-break" data-skip="1" data-page="…"></span>` |
| `.lineBreak` | `<br>` |
| `.plainText(s)` | `s` (HTML-escaped) |
| `.boldText(children)` | `<strong>…</strong>` |
| `.italicText(children)` | `<em>…</em>` |
| `.smallCapsText(children)` | `<span class="small-caps">…</span>` |
| `.underlineText(children)` | `<span class="underline">…</span>` |
| `.termText(children)` | `<span class="term">…</span>` |
| `.suppliedText(children)` | `<span class="supplied">[…]</span>` |
| `.sicText(children)` | `<s class="sic">…</s>` |
| `.corrText(children)` | `<span class="corr">…</span>` |
| `.formulaText(s)` | `<em class="formula">s</em>` |
| `.footnoteMarker(id, label)` | `<button class="fn-marker" data-skip="1" popovertarget="fn-label">label</button>` |
| `.footnoteBody(id, type, pNum, seqNum, label, children)` | `<aside class="footnote fn-type" id="fn-label" popover>…</aside>` |
| `.persNameLink(ref, children, person)` | `<a class="pers-name" href="frusexplorer://person/ref">…</a>` |
| `.glossLink(ref, children, entry)` | `<a class="gloss" href="frusexplorer://gloss/ref">…</a>` |
| `.crossRefLink(target, volumeId, children)` | `<a class="cross-ref" href="frusexplorer://doc/vol/docId">…</a>` |
| `.unknown(name, children)` | `<span class="unknown" data-element-name="name">…</span>` |

**Footnote popover markup** — The HTML popover API requires no JavaScript.
The browser handles show/hide, focus trapping, and light-dismiss natively:

```html
<!-- Inline marker (data-skip="1" so it is invisible to the offset counter) -->
<button class="fn-marker" data-skip="1" popovertarget="fn-1">1</button>

<!-- Footnote body (emitted in the footnotes section at the bottom) -->
<aside class="footnote fn-footnote" id="fn-1" popover>
  <p class="body">Footnote text here.</p>
</aside>
```

**Tables with colspan/rowspan** — The `TableCell` struct in `FRUSRenderNode`
already carries `rowSpan: Int` and `colSpan: Int`; they are just emitted as HTML
attributes. No additional logic required.

#### Offset-Skip Attribute Convention

Elements that `ASTToRenderNodeConverter.flatText()` skips must emit
`data-skip="1"` so the JavaScript offset engine (Session 143) applies the same
rules. The full skip list from `flatText()` (lines 76–108 of the converter):

| Skipped element | What is emitted |
|-----------------|-----------------|
| `.pageBreak` | `<span data-skip="1" …>` |
| `.footnoteMarker` | `<button data-skip="1" …>` |
| `.figureBlock` | `<figure data-skip="1" …>` |
| `.footnoteBody` (entire aside) | `<aside data-skip="1" …>` |

Note: `.lineBreak` contributes `"\n"` in the Swift DFS and must emit `<br>` in
HTML but NOT carry `data-skip`, so the JS engine counts it as a newline character.

#### Tests

Add `FRUSRenderNodeHTMLSerializerTests` in `FRUSExplorerTests`:

- Round-trip: parse a known TEI fixture → convert to render nodes → serialize to
  HTML → assert specific tags are present (heading `<h2>`, footnote `<aside
  popover>`, table with `colspan`/`rowspan`, `data-skip` on pageBreak and
  footnoteMarker).
- Escape test: document body containing `<`, `>`, `&`, `"` renders as
  `&lt;`, `&gt;`, `&amp;`, `&quot;`.
- Table test: a cell with `colSpan: 2` emits `<td colspan="2">`.

#### Files to Create / Modify

| File | Change |
|------|--------|
| `FRUSExplorer/TEI/FRUSRenderNodeHTMLSerializer.swift` | **Create** |
| `FRUSExplorerTests/FRUSRenderNodeHTMLSerializerTests.swift` | **Create** |

---

### Session 141 — WKWebView Wrapper and Theming

**Scope:** Build `FRUSDocumentWebView`, a SwiftUI-representable `WKWebView` that
loads HTML produced by `FRUSRenderNodeHTMLSerializer` inside a full HTML template
with app CSS. Handle dark/light mode and Dynamic Type bridging. This session ends
with a document displaying correctly in both macOS and iOS renderings, with correct
typography and theming, but without interactive elements yet responding.  
**Effort:** Medium. Platform bridge code; requires careful Swift 6 MainActor
handling.  
**Risk:** Medium. The WKWebView configuration (custom scheme, content world) must
be set up before the view is first used; errors here are silent.

#### Architecture

```
FRUSDocumentWebView (SwiftUI View)
  └── #if os(macOS)
        FRUSDocumentWebViewMac : NSViewRepresentable
          └── WKWebView (configured with FRUSWebViewConfiguration)
      #else
        FRUSDocumentWebViewiOS : UIViewRepresentable
          └── WKWebView (same configuration)
  └── Coordinator
        WKNavigationDelegate  — page-load lifecycle
        WKURLSchemeHandler    — frusexplorer:// dispatch (Session 142)
        WKScriptMessageHandler — JS → Swift bridge (Sessions 143–145)
```

The `WKWebViewConfiguration` is built once via a shared factory:

```swift
extension WKWebViewConfiguration {
    /// Returns a configuration with the frusexplorer:// scheme registered
    /// and the user content controller pre-loaded with the app's JS bundle.
    static func frusExplorerConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(FRUSURLSchemeHandler(), forURLScheme: "frusexplorer")
        // JS injection added in Session 143
        return config
    }
}
```

#### HTML Template

The serializer (Session 140) produces an HTML fragment. This session wraps it in
a full document template:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>{{APP_CSS}}</style>
</head>
<body>
  {{DOCUMENT_FRAGMENT}}
</body>
</html>
```

`{{APP_CSS}}` is generated at runtime from the current `FRUSTheme` values and the
user's preferred content size (see Theming below). `{{DOCUMENT_FRAGMENT}}` is the
output of `FRUSRenderNodeHTMLSerializer.serialize(_:)`.

#### Theming: CSS Variables Bridged from FRUSTheme

All color and typography values are expressed as CSS custom properties injected
into `:root`:

```css
:root {
  --color-primary:      {{primary}};
  --color-secondary:    {{secondary}};
  --color-accent:       {{accent}};
  --color-background:   {{background}};
  --color-editorial:    {{editorialNoteBackground}};
  --color-pers-name:    {{persNameColor}};       /* teal */
  --font-size-body:     {{bodyFontSize}}px;
  --font-size-heading:  {{headingFontSize}}px;
  --font-size-dateline: {{datelineFontSize}}px;
  --font-size-footnote: {{footnoteFontSize}}px;
  --font-family:        {{systemFontStack}};
}
```

The CSS for layout (padding, line-height, block spacing, table borders, editorial
note left-border) is static and bundled as a file in the app. Only the variable
values change at runtime.

**Color bridge:** `Color` → `rgba(r, g, b, a)` CSS string. Resolve using
`NSColor.resolved(with: NSApp.effectiveAppearance)` (macOS) or
`UIColor.resolvedColor(with: traitCollection)` (iOS).

**Dynamic Type bridge:** Read `UIFont.preferredFont(forTextStyle: .body).pointSize`
(iOS) or `NSFont.preferredFont(forTextStyle: .body, options: [:]).pointSize`
(macOS) and inject as `--font-size-body`. Listen for
`UIContentSizeCategory.didChangeNotification` (iOS) and re-inject:

```swift
func updateTheme() {
    let css = FRUSTheme.cssVariables(colorScheme: currentColorScheme,
                                     contentSize: UIApplication.shared.preferredContentSizeCategory)
    webView.evaluateJavaScript("document.documentElement.style.cssText = `\(css.escaped)`")
}
```

**Appearance change (macOS):** Override `viewDidChangeEffectiveAppearance()` in
the `NSViewRepresentable` coordinator and call `updateTheme()`.

#### Loading a Document

```swift
func load(model: FRUSDocumentRenderModel) {
    let fragment = FRUSRenderNodeHTMLSerializer().serialize(model)
    let html = HTMLTemplate.wrap(fragment: fragment, css: FRUSTheme.cssVariables(...))
    webView.loadHTMLString(html, baseURL: nil)
}
```

Call `load(model:)` from the SwiftUI view's `.onChange(of: model)` modifier.
`WKWebView.loadHTMLString` is `@MainActor`-safe.

#### Files to Create / Modify

| File | Change |
|------|--------|
| `FRUSExplorer/TEI/FRUSDocumentWebView.swift` | **Create** — SwiftUI wrapper (both platforms) |
| `FRUSExplorer/TEI/FRUSWebViewConfiguration.swift` | **Create** — shared `WKWebViewConfiguration` factory |
| `FRUSExplorer/TEI/HTMLTemplate.swift` | **Create** — template string with CSS injection |
| `FRUSExplorer/Resources/frus-document.css` | **Create** — static CSS bundle (layout, typography, table styles, editorial note, footnote popover styles) |
| `FRUSExplorer/Theme/FRUSTheme.swift` | **Modify** — add `cssVariables(colorScheme:contentSize:) -> String` |

---

### Session 142 — Interactive Elements and Document View Migration

**Scope:** Wire up `frusexplorer://` link dispatch in the WKWebView, confirm
footnote popovers work natively, and replace `FRUSDocumentRenderer` in both
`DocumentView.swift` (iOS) and `MacDocumentView.swift` (macOS) with
`FRUSDocumentWebView`. The legacy renderer is **not yet deleted** — keep it in
place, guarded by a compile-time feature flag, until Session 147 confirms the
migration is stable.  
**Effort:** Medium. Most complexity is in the URL scheme handler and adapting the
existing `activeSheet` / `DocumentSheet` enum machinery to the new dispatch path.  
**Risk:** Medium. All interactive dispatch regressions will be caught at this
session; none of the changes after this point alter the dispatch path.

#### Interactive URL Scheme Handler

`FRUSURLSchemeHandler` implements `WKURLSchemeHandler`. It is registered in
`WKWebViewConfiguration.frusExplorerConfiguration()` (Session 141) and receives
all navigations to `frusexplorer://`:

```swift
final class FRUSURLSchemeHandler: NSObject, WKURLSchemeHandler, @unchecked Sendable {
    var onPersonTap:    ((String) -> Void)?   // ref key
    var onGlossTap:     ((String) -> Void)?   // ref key
    var onCrossRefTap:  ((String, String?) -> Void) // target, volumeId
    var onFootnoteTap:  ((String) -> Void)?   // label (handled in-page by popover API)

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        let url = urlSchemeTask.request.url!
        switch url.host {
        case "person":   onPersonTap?(url.pathComponents.dropFirst().first ?? "")
        case "gloss":    onGlossTap?(url.pathComponents.dropFirst().first ?? "")
        case "doc":
            let parts = url.pathComponents.filter { $0 != "/" }
            onCrossRefTap(parts[0], parts.count >= 2 ? parts[1] : nil)
        default: break
        }
        // All frusexplorer:// navigations are handled; respond with empty data
        // so WebKit does not report a load error.
        urlSchemeTask.didReceive(URLResponse())
        urlSchemeTask.didReceive(Data())
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}
}
```

Note: `.footnoteMarker` links are **not dispatched through this handler** — the
HTML popover API handles them natively in-browser. The `frusexplorer://footnote/`
scheme is not emitted by the serializer.

#### Footnote Popover Verification

Verify that `<button popovertarget="fn-1">` and `<aside id="fn-1" popover>` work
correctly on iOS 26 and macOS 26 without any JavaScript. The browser natively:
- Shows the aside on button tap
- Dismisses on tap outside
- Positions the popover near the anchor button
- Handles VoiceOver focus correctly

If native positioning is inadequate on any platform, a small CSS anchor-positioning
rule (`position-anchor: --fn-1`) can improve placement — this is a CSS-only fix,
no JS.

#### Document View Migration

**iOS — `DocumentView.swift`:**

Locate the `FRUSDocumentRenderer(model: ..., embedInScrollView: false, ...)` call
(currently around line 328). Replace with:

```swift
FRUSDocumentWebView(
    model: model,
    onPersonTap: { person in
        if let person { activeSheet = .personDetail(person) }
    },
    onGlossTap: { entry in
        if let entry { activeSheet = .glossDetail(entry) }
    },
    onCrossRefTap: { target, volumeId in
        handleCrossRefTap(target: target, targetVolumeId: volumeId)
    }
)
```

The `embedInScrollView` parameter disappears; `WKWebView` manages its own
scrolling. Remove the outer `ScrollView` that currently wraps the renderer — the
surrounding `LazyVStack` (summary strip, tags section) should be replaced by a
`VStack` now that the content is not lazy-loaded.

**macOS — `MacDocumentView.swift`:**

Same substitution in the macOS equivalent. The research strip (above the document)
and status bar (below) remain SwiftUI views. Only the document body area becomes
the web view.

#### Feature Flag

Add a compile-time constant in a new `FRUSExplorer/App/FeatureFlags.swift`:

```swift
enum FeatureFlags {
    /// When true, use WKWebView-based document rendering. Set to false
    /// to fall back to FRUSDocumentRenderer for debugging.
    static let useWebKitRenderer = true
}
```

Guard both call sites with this flag. Remove the flag and the legacy renderer
entirely in Session 147 after the highlight rewrite (Sessions 143–145) is stable.

#### Files to Create / Modify

| File | Change |
|------|--------|
| `FRUSExplorer/TEI/FRUSURLSchemeHandler.swift` | **Create** |
| `FRUSExplorer/App/FeatureFlags.swift` | **Create** |
| `FRUSExplorer/DocumentView/DocumentView.swift` | **Modify** — replace `FRUSDocumentRenderer` call |
| `FRUSExplorer/App/MacDocumentView.swift` | **Modify** — replace `FRUSDocumentRenderer` call |

---

### Session 143 — JS Flat-Text Offset Engine

**Scope:** Port `ASTToRenderNodeConverter.flatText()` to JavaScript. The JS
function traverses the live HTML DOM, respecting `data-skip="1"` attributes, and
builds two data structures: (1) a flat `String` whose contents and length exactly
match the Swift-produced `flatText`, and (2) a map from every character offset in
that string to a `{node: Text, localOffset: number}` DOM pair. These structures are
used by Sessions 144 (rendering stored highlights) and 145 (capturing new
selection-based highlights).  
**Effort:** Medium. The traversal logic itself is simple; the risk lies in
correctness.  
**Risk:** High. If the JS offset count diverges from the Swift offset count for any
document, highlights will misalign or be rejected as stale. The session's primary
deliverable is the test harness that proves equivalence, not just the JS code
itself.

#### JS Traversal Rules (Mirror of Swift DFS)

The Swift `flatText` DFS rules (from `ASTToRenderNodeConverter`, lines 76–108):

| Node | Swift action | JS equivalent |
|------|-------------|---------------|
| Text node | Append string | Append `textNode.nodeValue` |
| `[data-skip="1"]` | Skip entire subtree | `if (el.dataset.skip) return;` |
| `<br>` | Append `"\n"` | Append `"\n"` |
| Element with children | Recurse | Recurse into `childNodes` |

The `data-skip` attribute is set on exactly the elements listed in Session 140
(`.pageBreak`, `.footnoteMarker`, `.figureBlock`, `.footnoteBody`). No other
elements are skipped.

```javascript
// frus-offset-engine.js — injected into every document page load

window.FRUSOffsets = (() => {
  const root = document.querySelector('.frus-document');
  if (!root) return null;

  const charToNode = [];   // index i → {node: Text, localOffset: number}
  let flatText = '';

  function walk(node) {
    if (node.nodeType === Node.TEXT_NODE) {
      const val = node.nodeValue;
      for (let i = 0; i < val.length; i++) {
        charToNode.push({ node, localOffset: i });
      }
      flatText += val;
      return;
    }
    if (node.nodeType !== Node.ELEMENT_NODE) return;
    if (node.dataset.skip === '1') return;  // matches data-skip="1"
    if (node.tagName === 'BR') {
      charToNode.push({ node, localOffset: 0 });
      flatText += '\n';
      return;
    }
    for (const child of node.childNodes) walk(child);
  }

  walk(root);
  return { flatText, charToNode };
})();
```

This script is injected as a `WKUserScript` with injection time
`.atDocumentEnd` so it runs after the full DOM is available.

#### Swift–JS Equivalence Test Harness

This is the critical deliverable of Session 143. Without it, Session 144's
highlight rendering cannot be trusted.

**Approach:**

1. In the test target, pick 10 representative test documents covering: plain prose,
   footnotes, tables, person links, page breaks, and attachments.
2. For each document:
   a. Run `ASTToRenderNodeConverter` → get Swift `flatText` and `renderingVersion`.
   b. Serialize to HTML via `FRUSRenderNodeHTMLSerializer`.
   c. Load the HTML into a `WKWebView` in test (using `XCTestExpectation` for the
      async page load).
   d. Evaluate `window.FRUSOffsets.flatText` via `evaluateJavaScript`.
   e. Assert Swift `flatText == JS flatText`.
3. If any assertion fails, the `data-skip` attributes in the serializer are
   incorrect. Fix the serializer; do not patch the JS to paper over a mismatch.

**Test class:** `FRUSOffsetEngineTests` in `FRUSExplorerTests`. These tests load
real WKWebViews and are necessarily async; annotate with `@MainActor`.

#### renderingVersion Stability

The `renderingVersion` hash is `SHA256(flatText + kVersion).prefix(16)`. Because
the JS and Swift produce the same `flatText`, the hash is identical, and existing
`DocumentHighlight` records remain valid across the renderer migration. No
SwiftData migration is needed.

#### Files to Create / Modify

| File | Change |
|------|--------|
| `FRUSExplorer/Resources/frus-offset-engine.js` | **Create** — JS DFS traversal |
| `FRUSExplorer/TEI/FRUSWebViewConfiguration.swift` | **Modify** — inject `frus-offset-engine.js` as `WKUserScript` |
| `FRUSExplorerTests/FRUSOffsetEngineTests.swift` | **Create** — equivalence test harness |

---

### Session 144 — CSS Custom Highlight API: Rendering Stored Highlights

**Scope:** Use the CSS Custom Highlight API (`CSS.highlights.set(...)`) to render
existing `DocumentHighlight` records in the web view. On page load, Swift injects
stored highlights as JSON; a JS function maps offsets to DOM Ranges using the
`FRUSOffsets.charToNode` map from Session 143 and registers them as named CSS
highlights. Stale highlights (version mismatch) appear in the existing amber
warning style. `DocumentHighlightTextView` is **not yet deleted** but is disabled
for documents using the WebKit renderer.  
**Effort:** Medium.  
**Risk:** Medium. The CSS Custom Highlight API is available in Safari 17.2+
(confirmed for the iOS/macOS 26 target). Rendering regression risk is low; the
JS highlight code runs after page load and cannot crash the document view.

#### Highlight Injection Flow

1. After `WKWebView` finishes loading (`webView(_:didFinish:)`), Swift calls:
   ```swift
   func renderHighlights(_ highlights: [DocumentHighlight]) async throws {
       let json = try JSONEncoder().encode(highlights.map(HighlightDTO.init))
       let script = "window.FRUSHighlights.render(\(String(data: json, encoding: .utf8)!))"
       try await webView.evaluateJavaScript(script)
   }
   ```
2. `HighlightDTO` carries: `startOffset: Int`, `endOffset: Int`,
   `color: String` (e.g. `"yellow"`), `isStale: Bool` (computed from
   `renderingVersion` mismatch with the current document version).

#### JS Highlight Renderer

```javascript
// frus-highlights.js

window.FRUSHighlights = {
  render(highlights) {
    // Clear all existing highlights
    CSS.highlights.clear();

    const groups = {};  // color → Range[]
    for (const h of highlights) {
      const ranges = window.FRUSOffsets
                           ? buildRanges(h.startOffset, h.endOffset) : [];
      if (!ranges.length) continue;
      const key = h.isStale ? 'frus-stale' : `frus-${h.color}`;
      (groups[key] ??= []).push(...ranges);
    }
    for (const [name, ranges] of Object.entries(groups)) {
      CSS.highlights.set(name, new Highlight(...ranges));
    }
  }
};

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
```

#### CSS Highlight Styles

Add to `frus-document.css`:

```css
::highlight(frus-yellow) { background-color: rgba(255, 214, 0, 0.4); }
::highlight(frus-green)  { background-color: rgba(0, 200, 83, 0.4); }
::highlight(frus-blue)   { background-color: rgba(0, 122, 255, 0.4); }
::highlight(frus-pink)   { background-color: rgba(255, 45, 85, 0.4); }
::highlight(frus-stale)  { background-color: rgba(255, 149, 0, 0.3); }
```

The color names map 1:1 to the `DocumentHighlight.color` enum cases used today.

#### Stale Highlight Banner

The existing stale-highlight warning banner (currently shown when
`DocumentHighlightTextView` detects a version mismatch) is migrated to be driven
by a SwiftUI `@State` property in `DocumentView`. After calling
`renderHighlights(_:)`, check if any highlight has `isStale == true` and set the
state accordingly. The banner UI code is unchanged.

#### Files to Create / Modify

| File | Change |
|------|--------|
| `FRUSExplorer/Resources/frus-highlights.js` | **Create** — CSS Highlight API renderer |
| `FRUSExplorer/TEI/FRUSWebViewConfiguration.swift` | **Modify** — inject `frus-highlights.js` |
| `FRUSExplorer/DocumentView/DocumentView.swift` | **Modify** — call `renderHighlights` on page load; drive stale banner |
| `FRUSExplorer/App/MacDocumentView.swift` | **Modify** — same |
| `FRUSExplorer/Models/DocumentHighlight.swift` | **Modify** — add `HighlightDTO` struct for JSON encoding |

---

### Session 145 — Highlight Selection and Creation

**Scope:** Replace the selection-to-offset flow in `DocumentHighlightTextView`
with a JS + `WKScriptMessageHandler` implementation. The user selects text in the
web view; a JS `selectionchange` listener computes `(startOffset, endOffset)` from
the active selection using `FRUSOffsets.charToNode`; a Swift handler receives the
offsets and presents the existing highlight color picker. On color selection, a
`DocumentHighlight` is written to SwiftData using the same schema as today.
After this session, `DocumentHighlightTextView.swift` is **disabled** (guarded
behind the inverse of `FeatureFlags.useWebKitRenderer`). Deletion occurs in
Session 147.  
**Effort:** Medium.  
**Risk:** Medium. The selection-to-offset reverse mapping is the mirror of
Session 144's forward mapping and uses the same `charToNode` array.

#### JS Selection Listener

```javascript
// frus-selection.js

document.addEventListener('selectionchange', () => {
  const sel = window.getSelection();
  if (!sel || sel.isCollapsed || !window.FRUSOffsets) {
    webkit.messageHandlers.selectionChanged.postMessage({ start: -1, end: -1 });
    return;
  }

  const range = sel.getRangeAt(0);
  const start = rangeEndpointToOffset(range.startContainer, range.startOffset);
  const end   = rangeEndpointToOffset(range.endContainer, range.endOffset);
  if (start >= 0 && end > start) {
    webkit.messageHandlers.selectionChanged.postMessage({ start, end });
  }
});

function rangeEndpointToOffset(node, localOffset) {
  const map = window.FRUSOffsets.charToNode;
  // Find the first entry in charToNode where node matches and localOffset matches.
  // Because entries are ordered, a linear scan from 0 is sufficient for typical
  // selection sizes. For production, consider a WeakMap<Text, [charIndex]> prebuilt
  // during walk() for O(1) lookup.
  for (let i = 0; i < map.length; i++) {
    if (map[i].node === node && map[i].localOffset === localOffset) return i;
  }
  return -1;
}
```

#### Swift Handler

Register the `selectionChanged` message handler in `WKWebViewConfiguration`:

```swift
config.userContentController.add(coordinator, name: "selectionChanged")
```

In the coordinator's `userContentController(_:didReceive:)`:

```swift
func userContentController(_ ucc: WKUserContentController,
                            didReceive message: WKScriptMessage) {
    guard message.name == "selectionChanged",
          let body = message.body as? [String: Int],
          let start = body["start"], let end = body["end"]
    else { return }

    if start < 0 {
        onSelectionCleared()
    } else {
        onSelectionChanged(start: start, end: end)
    }
}
```

`onSelectionChanged` sets a `@State var pendingHighlightRange: (Int, Int)?` in
the document view. When non-nil, the **Highlight** button in the research strip
becomes active. Tapping it presents the existing `HighlightColorPickerSheet`.

On color selection, create the `DocumentHighlight`:

```swift
let highlight = DocumentHighlight(
    volumeId: document.volumeId,
    documentId: document.documentId,
    startOffset: range.0,
    endOffset: range.1,
    color: selectedColor,
    renderingVersion: renderModel.renderingVersion,
    note: nil
)
modelContext.insert(highlight)
```

Then call `renderHighlights(_:)` to update the CSS highlight registry. The
SwiftData schema is unchanged; only the code that populates it changes.

#### O(1) Lookup Optimisation (Optional, Deferred)

The JS linear scan for `rangeEndpointToOffset` is O(n) in document length. For
typical selections (< 1,000 chars selected in a document of < 50,000 chars) this
is imperceptible. If profiling in Session 147 identifies it as a bottleneck,
replace with a `WeakMap<Text, Map<localOffset, charIndex>>` built during `walk()`.

#### Files to Create / Modify

| File | Change |
|------|--------|
| `FRUSExplorer/Resources/frus-selection.js` | **Create** — selection listener and reverse-map function |
| `FRUSExplorer/TEI/FRUSWebViewConfiguration.swift` | **Modify** — inject `frus-selection.js`; register `selectionChanged` handler |
| `FRUSExplorer/DocumentView/DocumentView.swift` | **Modify** — handle selection messages; present color picker; create `DocumentHighlight` |
| `FRUSExplorer/App/MacDocumentView.swift` | **Modify** — same |
| `FRUSExplorer/TEI/DocumentHighlightTextView.swift` | **Modify** — guard with `!FeatureFlags.useWebKitRenderer` (deletion in Session 147) |

---

### Session 146 — Collection Export Unification

**Scope:** Refactor `HTMLCollectionExporter` to use
`FRUSRenderNodeHTMLSerializer` rather than its own HTML-generation code.
Add print-specific CSS (page breaks, margins, TOC with page numbers). Verify
all existing collection export features (collection notes, per-document notes,
table of contents, citation headers) remain correct. The PDF and DOCX exporters
are unaffected by this session.  
**Effort:** Low–Medium. The HTMLCollectionExporter already generates HTML from
render nodes; refactoring to use the shared serializer is mostly mechanical.  
**Risk:** Low. This is a refactor with identical output behaviour; the test
fixture from Session 140 (round-trip HTML serialization) is directly applicable.

#### Refactor Plan

`HTMLCollectionExporter` currently has its own HTML-generation logic that partly
duplicates `FRUSRenderNodeHTMLSerializer`. After Session 140, the shared serializer
covers all node types. The exporter should:

1. Call `FRUSRenderNodeHTMLSerializer().serialize(doc.renderModel)` for each
   document body instead of its own rendering code.
2. Wrap the body fragment in the existing collection-document template (citation
   header + research note sections remain exporter-specific).
3. Replace the exporter's inline CSS with `frus-document.css` (already created in
   Session 141) plus a `frus-print.css` override for print-specific rules.

**Print CSS additions** (`FRUSExplorer/Resources/frus-print.css`):

```css
@media print {
  .frus-document       { page-break-after: always; }
  .fn-marker           { display: none; }          /* hide popover triggers */
  .footnote            { display: block !important; font-size: 0.85em; margin-top: 1em; }
  .toc-entry           { display: flex; justify-content: space-between; }
}
```

Note: footnote popovers are hidden in print because `<aside popover>` elements
are not rendered by the browser print engine. The print CSS re-shows them inline.

#### Files to Create / Modify

| File | Change |
|------|--------|
| `FRUSExplorer/Collections/HTMLCollectionExporter.swift` | **Modify** — use `FRUSRenderNodeHTMLSerializer` for document bodies |
| `FRUSExplorer/Resources/frus-print.css` | **Create** — print-specific CSS overrides |

---

### Session 147 — Legacy Renderer Removal, Accessibility, and Testing

**Scope:** Remove `FRUSDocumentRenderer.swift` and `DocumentHighlightTextView.swift`
after confirming the WebKit renderer is stable across Sessions 142–145. Audit HTML
output for semantic correctness and VoiceOver compatibility. Profile performance
with large documents and fix any identified issues.  
**Effort:** Medium (testing and profiling take most of the time; code removal is
fast).  
**Risk:** Low. All deletions are mechanical after the feature flag has been
removed.

#### Deletion Checklist

- [ ] Remove `FeatureFlags.useWebKitRenderer` and all guarded branches.
- [ ] Delete `FRUSExplorer/TEI/FRUSDocumentRenderer.swift` (1,117 lines).
- [ ] Delete `FRUSExplorer/TEI/DocumentHighlightTextView.swift` (646 lines).
- [ ] Remove `FRUSDocumentRenderer` and `DocumentHighlightTextView` from
      `project.yml` compile sources.
- [ ] Confirm no remaining import or reference in any other file
      (`grep -r FRUSDocumentRenderer .` and `grep -r DocumentHighlightTextView .`).

#### Accessibility Audit

Review the HTML produced by `FRUSRenderNodeHTMLSerializer` against the following
checklist:

| Element | Requirement |
|---------|-------------|
| `<h2 class="doc-heading">` | Correct heading level (h2 inside article/section context) |
| `<table class="frus-table">` | `<caption>` or `aria-label` if no visible heading |
| `<button class="fn-marker">` | `aria-label="Footnote {label}"` or `aria-describedby` |
| `<aside popover id="fn-N">` | Announced by VoiceOver when opened |
| `<a class="pers-name">` | Describes the link purpose; not just a raw name |
| `<a class="cross-ref">` | `aria-label="Cross-reference: document title"` (inject from render model) |
| `<div class="editorial-note">` | `role="note"` |

Add any missing attributes in `FRUSRenderNodeHTMLSerializer` as needed.

#### VoiceOver Testing Script

On iOS:
1. Enable VoiceOver; navigate to a downloaded document.
2. Swipe through headings — verify heading level announced.
3. Activate a person link — verify sheet opens; person name announced.
4. Activate a footnote marker — verify footnote popover opens and content announced.
5. Swipe through a table — verify cells announced with column context.
6. Select text and create a highlight — verify highlight creation is accessible.

On macOS:
1. Same sequence using VO+Right to navigate elements.
2. Verify all interactive elements are keyboard-reachable (Tab order).

#### Performance Profiling

Profile with the three largest volumes in the corpus (by document count) using
Instruments → Time Profiler + Allocations:

- Measure time from `load(model:)` call to `webView(_:didFinish:)` delegate
  callback (target: < 300 ms on iPhone 15 Pro).
- Measure peak memory during `FRUSOffsets` initialization on the largest document
  in the corpus (target: < 5 MB for the `charToNode` array; at ~50 bytes per entry
  and a typical 40,000-character document, expected < 2 MB).
- Measure `renderHighlights(_:)` with 50 highlights applied (target: < 16 ms).

If the `charToNode` array proves too large for very long documents (> 200,000
characters), replace it with a segment-tree structure that maps offset ranges to
text nodes without materializing every individual character entry.

#### Files to Delete

| File | Lines |
|------|-------|
| `FRUSExplorer/TEI/FRUSDocumentRenderer.swift` | 1,117 |
| `FRUSExplorer/TEI/DocumentHighlightTextView.swift` | 646 |

#### Files to Modify

| File | Change |
|------|--------|
| `FRUSExplorer/App/FeatureFlags.swift` | **Delete** (or remove the one flag and delete the file) |
| `FRUSExplorer/DocumentView/DocumentView.swift` | Remove legacy renderer branches |
| `FRUSExplorer/App/MacDocumentView.swift` | Remove legacy renderer branches |
| `project.yml` | Remove deleted files from compile sources list |

---

## Summary of New Files

| File | Session | Purpose |
|------|---------|---------|
| `FRUSExplorer/TEI/FRUSRenderNodeHTMLSerializer.swift` | 140 | Core HTML serializer |
| `FRUSExplorer/TEI/FRUSDocumentWebView.swift` | 141 | SwiftUI WKWebView wrapper (both platforms) |
| `FRUSExplorer/TEI/FRUSWebViewConfiguration.swift` | 141 | WKWebViewConfiguration factory |
| `FRUSExplorer/TEI/HTMLTemplate.swift` | 141 | HTML template with CSS injection |
| `FRUSExplorer/TEI/FRUSURLSchemeHandler.swift` | 142 | `frusexplorer://` dispatch |
| `FRUSExplorer/App/FeatureFlags.swift` | 142 | Feature flag (removed in 147) |
| `FRUSExplorer/Resources/frus-document.css` | 141 | Static CSS bundle |
| `FRUSExplorer/Resources/frus-print.css` | 146 | Print-specific CSS overrides |
| `FRUSExplorer/Resources/frus-offset-engine.js` | 143 | JS flat-text DFS |
| `FRUSExplorer/Resources/frus-highlights.js` | 144 | CSS Custom Highlight API |
| `FRUSExplorer/Resources/frus-selection.js` | 145 | Selection → offset bridge |
| `FRUSExplorerTests/FRUSRenderNodeHTMLSerializerTests.swift` | 140 | Serializer unit tests |
| `FRUSExplorerTests/FRUSOffsetEngineTests.swift` | 143 | Swift–JS offset equivalence tests |

## Summary of Deleted Files

| File | Session | Lines |
|------|---------|-------|
| `FRUSExplorer/TEI/FRUSDocumentRenderer.swift` | 147 | 1,117 |
| `FRUSExplorer/TEI/DocumentHighlightTextView.swift` | 147 | 646 |

Net new code: ~1,400 lines added (serializer, web view wrappers, JS, tests)  
Net deleted: ~1,763 lines (renderer + highlight text view)  
Net change: approximately −360 lines while adding table spans, footnote popovers, single rendering pass, and improved text selection.
