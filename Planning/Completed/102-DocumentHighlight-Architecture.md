# Session 102 — DocumentHighlight Architecture

## 1. Offset Model

### 1.1 Flat-Text Extraction Rules

Character offsets are defined over a **flat text string** produced by a deterministic
depth-first traversal of `FRUSDocumentRenderModel.bodyNodes`. Footnote bodies
(`FRUSDocumentRenderModel.footnotes`) are **excluded** from the body offset space;
footnote markers that appear inline in the body are also skipped.

The traversal algorithm:

```
func flatText(_ nodes: [FRUSRenderNode]) -> String:
    var result = ""
    for node in nodes:
        switch node:
        case .plainText(let s):         result += s
        case .formulaText(let s):       result += s
        case .lineBreak:                result += "\n"
        case .pageBreak:                skip
        case .footnoteMarker:           skip
        case .figureBlock:              skip
        case .tableBlock(rows):
            for row in rows:
                for cell in row:
                    result += flatText(cell.children)
        case .listBlock(_, items):
            for item in items:
                result += flatText(item)
        case _ (all container nodes):   result += flatText(node.children)
    return result
```

Container nodes that recurse into children (via `node.children`):
`.heading`, `.dateline`, `.letterOpener`, `.letterCloser`, `.salutation`,
`.paragraph`, `.boldText`, `.italicText`, `.smallCapsText`, `.underlineText`,
`.termText`, `.suppliedText`, `.sicText`, `.corrText`, `.persNameLink`,
`.glossLink`, `.crossRefLink`, `.editorialNoteBlock`, `.attachmentBlock`,
`.attachmentHeading`, `.titlePageBlock`, `.unknown`.

No block-separator characters (newlines, spaces) are inserted between adjacent
block nodes. This keeps offsets stable across renderer changes that affect
inter-block spacing.

### 1.2 Offset Units

Offsets are **Unicode scalar positions** (Swift `String.UnicodeScalarView` indices),
counted from the start of the flat text string (0-based). `startOffset` is the
position of the first selected scalar; `endOffset` is one past the last selected
scalar (half-open range `[start, end)`).

Using Unicode scalars rather than UTF-16 code units or grapheme clusters avoids
platform differences and keeps arithmetic simple. The flat text contains only
characters from the TEI source, which is well-formed XML; surrogate pairs are
not expected in practice.

### 1.3 Determinism Guarantee

The flat text is deterministic because:
- `FRUSRenderNode` is `Sendable` with value semantics.
- `ASTToRenderNodeConverter` processes AST nodes in document order (array index
  order) and assigns footnote numbers sequentially; there is no randomness.
- The only non-determinism source is `personLookup`/`glossLookup` closures, which
  return `PersonEntry?`/`GlossEntry?` objects that do **not** contribute to flat
  text (they affect popover content, not rendered characters).

Therefore the same TEI source + same converter version always produces the same
flat text, and the same character offsets.

---

## 2. renderingVersion Field

### 2.1 Purpose

`DocumentHighlight.renderingVersion` records the "version" of the render model
that was active when the highlight was created. When the version stored on a
highlight does not match the version computed for the current render model, the
highlight is **stale** — its offsets may no longer correspond to the correct
text ranges due to source changes or converter algorithm changes.

### 2.2 Computation

```
renderingVersion = hex(SHA-256(rawXMLBytes ++ converterVersionBytes)).prefix(16)
```

- `rawXMLBytes`: the raw UTF-8 bytes of the document's TEI XML as stored in
  the FTS5 SQLite database (retrieved via `FTS5Store`).
- `converterVersionBytes`: UTF-8 encoding of `ASTToRenderNodeConverter.version`,
  a static string constant manually bumped whenever the conversion algorithm
  changes in a way that affects flat-text output (e.g. new node types that
  contribute characters, changed traversal order).
- The two byte sequences are concatenated before hashing so that either change
  produces a different version string.
- The 16-hex-character prefix provides 64 bits of collision resistance — more
  than sufficient for a per-document version identifier.

### 2.3 Stale Highlight Display

A highlight is stale when `highlight.renderingVersion != currentVersion`. Stale
highlights are:
- **Not painted** — no background color applied to the text range.
- **Shown with a warning indicator** — a yellow `⚠` badge in the highlight
  margin or annotation popover.
- **Not silently dropped** — the record is retained in SwiftData so the user
  can review and manually delete or re-create the highlight after verifying the
  source change.

The warning indicator is implemented in Session 103 (text selection layer).

### 2.4 Version Bumping Protocol

Whenever `ASTToRenderNodeConverter` is modified in a way that changes the flat
text output (new text-bearing node type, traversal order change, character
normalisation change), the developer must:

1. Increment `ASTToRenderNodeConverter.version` (e.g. `"1.2"` → `"1.3"`).
2. Document the change in the version history comment.
3. Existing highlights will be automatically marked stale on next load.

Changes that do **not** require a version bump: visual-only changes (font size,
colour, spacing), new non-text node types (e.g. `.figureBlock`), changes to
popover content, changes to interactive link encoding.

---

## 3. CloudKit Conflict Resolution

### 3.1 Insert Conflicts (Non-Issue)

Each `DocumentHighlight` has a unique `id: UUID` generated at creation time on
the originating device. CloudKit treats each record independently — highlights
created on separate devices are additive merges with no conflicts. A user
annotating the same document on two devices simultaneously results in two
distinct `DocumentHighlight` records, both retained.

### 3.2 Edit Conflicts (Last Write Wins)

If the same `DocumentHighlight.id` is modified on two devices before sync
completes (e.g., changing `colorTag` from "yellow" to "green" on device A
while changing it to "blue" on device B), CloudKit applies **last write wins**
based on record modification timestamp. This is acceptable for colorTag and
noteId changes — a missed color change is a minor inconvenience, not data loss.

The `createdAt` field is set once at insertion and never modified, so it is
immune to edit conflicts.

### 3.3 Overlapping Highlight Ranges

The SwiftData model imposes no uniqueness constraint on `(volumeId, documentId,
startOffset, endOffset)`. Overlapping highlights from multiple devices are
explicitly permitted. The rendering layer (Session 103) draws all non-stale
highlights in the document, stacking colors where ranges overlap. The user
resolves visual ambiguity by deleting unwanted highlights via the annotation
panel.

### 3.4 renderingVersion Across Devices

`renderingVersion` is computed locally at highlight-creation time and stored
as a plain string. Because it is derived from the TEI XML bytes (which are
identical across devices for the same volume) and the converter version constant
(identical across app builds), the version string is consistent across devices.
No cross-device coordination is required.

---

## 4. DocumentHighlight SwiftData Model (Implementation Plan)

File: `FRUSExplorer/Models/DocumentHighlight.swift`

```swift
@Model final class DocumentHighlight {
    var id: UUID = UUID()
    var volumeId: String = ""
    var documentId: String = ""
    var startOffset: Int = 0
    var endOffset: Int = 0
    var colorTag: String = "yellow"   // "yellow" | "green" | "blue" | "pink"
    var noteId: UUID? = nil
    var createdAt: Date? = nil
    var renderingVersion: String = ""
}
```

All properties have defaults for CloudKit schema compatibility (same pattern as
`ResearchSession`, `SessionEvent`). `createdAt` is optional to satisfy the
CloudKit "no required non-optional fields" constraint even though it is always
set to `Date.now` at init.

No `@Relationship` links to `ResearchNote` — the `noteId` UUID is stored as a
plain value to avoid cascading delete surprises across the CloudKit graph. The
note lookup is performed at display time with a fetch predicate.

Added to `frusModelTypes` in `ModelContainer+FRUS.swift`.

### 4.1 pbxproj Registration

| Purpose         | UUID                       |
|-----------------|----------------------------|
| File reference  | `AA22BB01CC03DD04EE2252`   |
| macOS build     | `AA22BB01CC03DD04EE2253`   |
| iOS build       | `AA22BB01CC03DD04EE2254`   |
| Group           | `EB3D26757D1E60EB072F06EC` (Models) |
