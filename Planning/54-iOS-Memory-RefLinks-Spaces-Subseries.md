# Session 54 — iOS Memory, Ref Link Navigation, Inline Spaces, Subseries Parsing

**Version**: 1.0  
**Date**: 2026-05-17  
**Depends on**: Sessions 09, 33, 51

---

## Issue 1 — iOS memory still exceeded during full-corpus indexing

### Root cause

`parseAndExtract` accumulates every document's full content into a `VolumeIndexData`
struct before any data is written to SQLite. A large volume (up to 13 MB XML) produces
`fts5Docs` + `documentCache` arrays that each hold every document's `bodyText` — so
`bodyText` is in memory twice simultaneously. With `concurrencyLimit = 4` in
`indexAllVolumes`, up to four `VolumeIndexData` objects can be in memory concurrently
before `storeIndexData` gets to process them. The Session 51 batch-size throttle only
affects the SQLite write transaction size — it does nothing to reduce the in-memory
accumulation during parsing.

Additionally, `parseAndExtract` reads the XML file three times sequentially (via
`parser.parse`, `parser.parsePersons`, `parser.parseTerms`), and the `astDocs` AST is
held in memory for the entire first pass while all document arrays are being built.

### Fix — streaming document writes within a single volume

Refactor `indexVolume` so it processes and writes documents in configurable batches
(default 50 on iOS, unlimited on macOS — matching the existing `effectiveBatchSize`
logic) rather than accumulating the full `VolumeIndexData` before writing:

1. Keep `parseAndExtract` as-is for cross-refs, page ranges, dates, persons, terms
   (these are small), but change `fts5Docs` and `documentCache` accumulation to flush
   in chunks of `effectiveBatchSize`.
2. Since `parseAndExtract` is `nonisolated`, add a new actor-isolated `writeBatch(_:)`
   method the nonisolated closure can call, or restructure so document iteration happens
   inside the actor and calls storage directly.
3. The cleanest approach: move the document-level loop (`for astDoc in astDocs`) inside
   an actor-isolated helper, calling FTS5 and aux inserts after each batch of
   `effectiveBatchSize` documents. The `nonisolated parseAndExtract` continues to handle
   only the XML parse step and returns `astDocs`.
4. On iOS: also reduce `indexAllVolumes` concurrencyLimit to 1 (add a private
   `effectiveConcurrencyLimit` that returns `min(concurrencyLimit, 1)` on iOS). Parallel
   volume indexing is the secondary source of memory spikes during `indexAllVolumes`.

### Files

`FRUSExplorer/Search/IndexingPipeline.swift`

### Tests (`IndexingPipelineTests`)

- `batchWriteFlushesPerBatchSize` — verify that a volume with N > batchSize documents
  results in multiple write calls rather than one
- `indexingConcurrencyLimitIsOneOniOS` — verify `effectiveConcurrencyLimit` returns 1
  on iOS

---

## Issue 2 — `<ref>` links do not navigate

### Root cause

`FRUSDocumentRenderer.inlineTextNode` renders `crossRefLink` as:

```swift
case .crossRefLink(_, _, let children):
    return inlineText(children).foregroundColor(.accentColor)
```

The `onCrossRefTap` callback is declared and wired all the way from
`DocumentView.handleCrossRefTap` into the renderer, but it is never called — there is
no gesture attached to the colored text run. This is because SwiftUI `Text` does not
support per-run tap gestures; the entire concatenated `Text` view only supports a single
`.onTapGesture` at the view level.

`handleCrossRefTap` in `DocumentView` is correctly implemented (strips `#`, resolves
volumeId, sets `appState.pendingBrowseDocument`). The callback plumbing exists — the
renderer just never fires it.

### Fix — `AttributedString` with a custom URL scheme for cross-ref taps

1. Add a `DocumentLinkScheme` enum with `static let crossRefScheme = "frusexplorer"`.
2. Encode each cross-ref target as `frusexplorer://doc/{volumeId}/{documentId}` (or
   `frusexplorer://doc/_/{documentId}` when no volumeId is available — resolved at tap
   time using the current document's volume).
3. Add `private func inlineAttributedString(_ nodes: [FRUSRenderNode]) -> AttributedString`
   to `FRUSDocumentRenderer`. For most nodes it produces styled `AttributedString` runs.
   For `crossRefLink`, it sets `attributedString.link = url` on the run.
4. Paragraphs and footnote bodies that contain any `crossRefLink` descendant use
   `Text(inlineAttributedString(children))` instead of `Text(inlineText(children))`.
   All other paragraphs continue to use the existing `inlineText` path (no regression).
5. In `DocumentView`, add:
   ```swift
   .environment(\.openURL, OpenURLAction { url in
       guard url.scheme == DocumentLinkScheme.crossRefScheme else { return .systemAction }
       // parse volumeId and documentId from url.pathComponents, call handleCrossRefTap
       return .handled
   })
   ```

A `crossRefLink` that has no `volumeId` stored in the render node uses the current
document's `entry.volumeId` as the fallback (same logic as the existing
`handleCrossRefTap`).

### Files

`FRUSExplorer/TEI/FRUSDocumentRenderer.swift`,
`FRUSExplorer/DocumentView/DocumentView.swift`

### Tests (`FRUSDocumentRendererTests`)

- `crossRefLinkAttributedStringContainsLink` — render a node with a `crossRefLink`,
  verify `AttributedString` run has `.link` set to the expected URL
- `crossRefLinkURLSchemeIsHandled` — verify the `OpenURLAction` in DocumentView fires
  `handleCrossRefTap` for a `frusexplorer://doc/...` URL

---

## Issue 3 — Styled inline text loses leading and trailing spaces

### Root cause

`FRUSDocumentParser.normalizedText` (line ~525) trims all leading and trailing whitespace
from every text node:

```swift
let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
guard !trimmed.isEmpty else { return "" }
```

This is documented (lines 29–32) as applying "uniformly to both block and inline contexts"
— a known simplification from Session 06. When a styled element (`<hi rend="italic">`)
is surrounded by text, the adjacent text nodes lose their boundary spaces:

```xml
<p>Secretary <hi rend="italic">Kissinger</hi> said</p>
```

SAX flush produces `"Secretary "` → trimmed to `"Secretary"`, then `" said"` → trimmed
to `"said"`. Rendered: `"SecretaryKissingersaid"` (italic Kissinger, no spaces).

### Fix — preserve single boundary spaces

Replace the trim-and-discard logic in `normalizedText` with trim-and-restore:

```swift
static func normalizedText(_ raw: String) -> String {
    // Whitespace-only nodes are still discarded (e.g. inter-element newlines in markup).
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }
    // Restore a single space at each boundary where the original had whitespace.
    let lead  = raw.first?.isWhitespace == true ? " " : ""
    let trail = raw.last?.isWhitespace  == true ? " " : ""
    // Collapse internal whitespace runs.
    var collapsed = ""
    var prevWasSpace = false
    for ch in trimmed {
        if ch.isWhitespace { if !prevWasSpace { collapsed += " " }; prevWasSpace = true }
        else               { collapsed.append(ch);                   prevWasSpace = false }
    }
    return lead + collapsed + trail
}
```

Also update the doc comment (lines 29–32) to replace "Leading and trailing whitespace is
trimmed" with "Leading and trailing whitespace is collapsed to a single space when present;
whitespace-only nodes are discarded."

### Files

`FRUSExplorer/TEI/FRUSDocumentParser.swift`

### Tests (`FRUSDocumentParserTests`)

- `normalizedTextPreservesLeadingSpace` — `normalizedText(" word")` → `" word"`
- `normalizedTextPreservesTrailingSpace` — `normalizedText("word ")` → `"word "`
- `normalizedTextDiscardsWhitespaceOnlyNode` — `normalizedText("  \n ")` → `""`
- `normalizedTextCollapsesInternalSpaces` — `normalizedText("a  b")` → `"a b"`
- Integration: render a paragraph with adjacent styled text, verify spaces are preserved

---

## Issue 4 — Subseries parsing produces extraneous entries

### Root cause

`VolumeIDParser.subseries(from:)` (ManifestGeneratorCore) uses `v\d+` as the sole
volume-marker delimiter. Three categories of volumes fall through to the "no marker
found → return entire suffix" branch, producing overly specific subseries values that
appear as standalone groups in the Browser:

| Volume ID | Current subseries | Correct subseries |
|---|---|---|
| `frus1863p1`, `frus1863p2` | `1863p1`, `1863p2` | `1863` |
| `frus1943CairoTehran`, `frus1943China` | `1943CairoTehran`, `1943China` | `1943` |
| `frus1969-76ve01`…`frus1969-76ve09p2` | `1969-76ve01`… | `1969-76` |

### Fix — expand volume-marker recognition in VolumeIDParser

```swift
private static func subseries(from afterFrus: String) -> String {
    var s = afterFrus

    // 1. v[a-z]?\d+ covers standard volumes (v01) and Vietnam-extras (ve01, ve05p2).
    //    Everything from this marker to end-of-string is discarded.
    if let range = s.range(of: #"v[a-z]?\d+.*$"#, options: [.regularExpression]) {
        return String(s[..<range.lowerBound])
    }

    // 2. Trailing p\d+ (part number with no volume marker, e.g. 1863p2).
    if let range = s.range(of: #"p\d+$"#, options: [.regularExpression]) {
        s = String(s[..<range.lowerBound])
    }

    // 3. Known non-subseries suffixes (longest first).
    for suffix in ["sups", "app", "mf"] where s.hasSuffix(suffix) {
        s = String(s.dropLast(suffix.count)); break
    }

    // 4. Trailing conference/topic names: [A-Z][a-z]+ (e.g. Cairo, Tehran, China).
    //    Applied iteratively so CairoTehran → Cairo → stripped.
    //    A trailing single uppercase letter (e.g. "G" in 1952-54G) is NOT stripped.
    var changed = true
    while changed {
        changed = false
        if let r = s.range(of: #"[A-Z][a-z]+"#, options: .regularExpression),
           r.upperBound == s.endIndex {
            s = String(s[..<r.lowerBound]); changed = true
        }
    }

    return s
}
```

After updating `VolumeIDParser`, regenerate `manifest.json` by running the
`ManifestGenerator` tool and bundle the updated file.

The `frusSubseries(from:)` function in `ManifestStore.swift` (used only for live/new
volumes not yet in the manifest) already returns correct values for these patterns via
its `^[\d-]+` regex — no code change needed there.

### Files

`ManifestGeneratorCore/VolumeIDParser.swift`,
`FRUSExplorer/Resources/manifest.json` (regenerated)

### Tests (`VolumeIDParserTests`)

Extend the existing parametric table to cover:

| Input | Expected subseries |
|---|---|
| `frus1863p2.xml` | `1863` |
| `frus1943CairoTehran.xml` | `1943` |
| `frus1943China.xml` | `1943` |
| `frus1969-76ve01.xml` | `1969-76` |
| `frus1969-76ve05p1.xml` | `1969-76` |
| `frus1952-54Gv01.xml` | `1952-54G` (no regression) |
| `frus1861app.xml` | `1861` (no regression) |

---

## Files Changed Summary

| File | Change |
|---|---|
| `FRUSExplorer/Search/IndexingPipeline.swift` | Streaming batch writes; iOS `effectiveConcurrencyLimit = 1` |
| `FRUSExplorer/TEI/FRUSDocumentRenderer.swift` | `inlineAttributedString` path for paragraphs with cross-ref nodes |
| `FRUSExplorer/DocumentView/DocumentView.swift` | `OpenURLAction` handler for `frusexplorer://doc/...` URLs |
| `FRUSExplorer/TEI/FRUSDocumentParser.swift` | `normalizedText` space-preservation fix + doc comment update |
| `ManifestGeneratorCore/VolumeIDParser.swift` | Expanded volume-marker recognition |
| `FRUSExplorer/Resources/manifest.json` | Regenerated with corrected subseries values |
| `FRUSExplorerTests/IndexingPipelineTests.swift` | 2 new tests |
| `FRUSExplorerTests/FRUSDocumentRendererTests.swift` | 2 new tests |
| `FRUSExplorerTests/FRUSDocumentParserTests.swift` | 5 new tests |
| `ManifestGeneratorCoreTests/VolumeIDParserTests.swift` | Extended parametric table |
