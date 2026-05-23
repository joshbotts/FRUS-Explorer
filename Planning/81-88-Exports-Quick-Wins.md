---
name: Sessions 81–88 — Exports & Quick Wins
description: Extends the export pipeline with structured rich-text output (PDF, HTML,
  DOCX), fixes several isolated UI bugs, and adds high-value additive features
  (Handoff, Spotlight, citation export, Person Index, Timeline view) — all achievable
  in short focused sessions without architectural risk.
type: implementation
originSessionId: session-80
---

# Sessions 81–88: Exports & Quick Wins

These sessions address the highest-priority items from the Development Backlog
(`Planning/75-Development-Backlog.md`) that can be completed without large
architectural changes. Sessions 81–83 form a tightly coupled export upgrade track;
sessions 84–88 are largely independent and can be scheduled in any order after 81.

---

## Work Item Summary

| Session | Backlog Ref | Title | Effort | Risk | Depends On |
|---------|-------------|-------|--------|------|------------|
| 81 | #1 (HIGH) | Rich Document Rendering in Exports | Medium | Medium | Sessions 77–80 |
| 82 | #15 | DOCX Export Part 1 — Infrastructure | Medium | Medium | Session 81 |
| 83 | #15 + #2 | DOCX Export Part 2 — Rich Content + Italic Fix | Medium | Low–Medium | Session 82 |
| 84 | #12 + #13 | Small UI Fixes (Research Strip + iOS Storage) | Low | Low | None |
| 85 | #4 + #8 | Handoff + Spotlight Integration | Low | Low | None |
| 86 | #6 | Zotero / RIS / BibTeX Citation Export | Low | Low | None |
| 87 | #5 | Person / Entity Index View | Low | Low | None |
| 88 | #7 | Document Timeline View | Low | Low | None |

---

## Session Breakdown

---

### Session 81 — Rich Document Rendering in Exports

**Scope:** Backlog #1 (HIGH PRIORITY). Extend the PDF and HTML export paths from
flat `bodyText` strings to structured render-model output.  
**Effort:** Medium (one session, ~4–5 hours). Touches the critical-path export
pipeline; requires careful fallback preservation.  
**Risk:** Medium. Regression risk to existing flat-text export if the fallback path
(no render model) is not preserved. Recommend keeping the flat-text path and only
activating the rich path when a render model is successfully produced.

#### Problem

`PDFCollectionExporter` and `HTMLCollectionExporter` emit `doc.bodyText` as a flat
string. `CollectionExportDocument` carries only `bodyText: String`. The resulting
PDFs and HTML files lose all structural formatting: headings, datelines, footnotes,
italic/bold emphasis, and attachment separators are all discarded.

#### Fix

**Step 1 — Extend `CollectionExportDocument`:**

Add an optional render model field alongside the existing `bodyText`:

```swift
struct CollectionExportDocument {
    let volumeId: String
    let documentId: String
    let title: String
    let bodyText: String          // Preserved as fallback
    let renderModel: FRUSDocumentRenderModel?   // New
}
```

**Step 2 — Create `DocumentRenderService`:**

A new lightweight service (or actor) that accepts raw XML and returns a
`FRUSDocumentRenderModel` on demand. This avoids duplicating the parser invocation
logic at every call site:

```swift
actor DocumentRenderService {
    func renderModel(for xmlString: String) -> FRUSDocumentRenderModel? {
        guard let ast = FRUSDocumentParser().parse(xmlString) else { return nil }
        return ASTToRenderNodeConverter().convert(ast)
    }
}
```

**Step 3 — Populate render model during collection assembly:**

In the document-collection loop (wherever `CollectionExportDocument` instances are
created), call `DocumentRenderService.renderModel(for:)` and populate the new field.
If parsing fails, `renderModel` remains `nil` and the flat-text fallback applies.

**Step 4 — Update `PDFCollectionExporter`:**

Add `renderNodeToNSAttributedString` that maps render nodes to `NSAttributedString`
with appropriate attributes:

- `.heading` → large bold font (e.g. `.systemFont(ofSize: 16, weight: .bold)`)
- `.dateline` → secondary italic font (e.g. `.italicSystemFont(ofSize: 12)`)
- `.paragraph` → body font (e.g. `.systemFont(ofSize: 12)`)
- `.footnoteMarker` → superscript (`NSAttributedString.Key.superscript: 1`,
  small point size)
- `.footnoteBody` → small font at document end (e.g. `.systemFont(ofSize: 9)`)
- `.attachmentHeading` → sans-serif medium font with top spacing
- `.emphasis(.italic, ...)` → italic attribute
- `.emphasis(.bold, ...)` → bold attribute
- `.emphasis(.smallCaps, ...)` → small-caps font feature

Concatenate the resulting attributed strings and pass to the existing
`PDFDocument`/`NSPrintOperation` rendering path. If `renderModel` is `nil`, fall
back to the existing plain-text path unchanged.

**Step 5 — Update `HTMLCollectionExporter`:**

Add `renderNodeToHTML` that walks render nodes emitting semantic HTML elements:

- `.heading` → `<h2>`
- `.dateline` → `<p class="dateline"><em>...</em></p>`
- `.paragraph` → `<p>`
- `.emphasis(.italic, ...)` → `<em>`
- `.emphasis(.bold, ...)` → `<strong>`
- `.footnoteMarker` → `<sup><a href="#fn-N" id="fnref-N">N</a></sup>`
- `.footnoteBody` → collected and emitted at end as `<ol class="footnotes"><li id="fn-N">...</li></ol>`
- `.attachmentBlock` → `<section class="attachment">` with `<hr>` separator
- `.attachmentHeading` → `<h3 class="attachment-heading">`

Add minimal CSS in the HTML `<style>` block for `.dateline`, `.attachment`, and
`.footnotes`. If `renderModel` is `nil`, fall back to existing plain-text HTML path.

#### Files to Modify — Session 81

| File | Change |
|------|--------|
| `FRUSExplorer/Collections/CollectionExporter.swift` | Add `renderModel: FRUSDocumentRenderModel?` to `CollectionExportDocument`; populate during collection assembly |
| `FRUSExplorer/Collections/PDFCollectionExporter.swift` | Add `renderNodeToNSAttributedString`; use render model when available; preserve flat-text fallback |
| `FRUSExplorer/Collections/HTMLCollectionExporter.swift` | Add `renderNodeToHTML`; use render model when available; add CSS; preserve flat-text fallback |
| `FRUSExplorer/Services/DocumentRenderService.swift` (new) | Lightweight actor wrapping parser + converter for on-demand render model production |

---

### Session 82 — DOCX Export Part 1: Infrastructure

**Scope:** Backlog #15. Introduce DOCX export with a working ZIP/Open XML pipeline
producing a well-formed document that opens in Word, Pages, and LibreOffice.  
**Effort:** Medium (one session, ~4–5 hours). Open XML is verbose; ZIP assembly is
mechanical but tedious. Allow extra time for debugging malformed XML that Word rejects
silently.  
**Risk:** Medium. New dependency (ZipFoundation); new export format wired into the
existing `CollectionExporter` protocol; multiple XML generation helpers required.  
**Prerequisite:** Session 81 must be complete (structured rendering must be in place
for Part 2 to layer rich content on top).

#### DOCX Structure

A `.docx` file is a ZIP archive with the following minimum structure:

```
[Content_Types].xml
_rels/
  .rels
word/
  document.xml
  styles.xml
  _rels/
    document.xml.rels
```

#### Implementation Steps

**Step 1 — Add ZipFoundation dependency:**

In `Package.swift` (or via Xcode package manager), add:

```swift
.package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19")
```

ZipFoundation is cross-platform, Swift-native, and requires no subprocess — the
correct choice over `zip` command-line invocations or custom ZIP writers.

**Step 2 — Create `DocxCollectionExporter`:**

New file conforming to `CollectionExporter`:

```swift
final class DocxCollectionExporter: CollectionExporter {
    func export(_ documents: [CollectionExportDocument],
                collection: CollectionMetadata,
                to url: URL) throws
}
```

**Step 3 — Add `.docx` case to `ExportFormat` enum** in `CollectionExporter.swift`.

**Step 4 — XML generation helpers (private methods on `DocxCollectionExporter`):**

- `makeContentTypesXML() -> String` — registers `word/document.xml` and
  `word/styles.xml` content types
- `makeRelsXML() -> String` — `_rels/.rels` pointing to `word/document.xml`
- `makeDocumentRelsXML() -> String` — `word/_rels/document.xml.rels` (no external
  relationships at this stage)
- `makeStylesXML() -> String` — defines Normal, Heading1, Heading2, Dateline, Footnote
  Text, and Footnote Reference styles
- `makeDocumentXML(documents:, collection:) -> String` — cover page `<w:p>` block +
  one `<w:p>` per line of each document's `bodyText`

**Step 5 — ZIP assembly:**

```swift
let archive = Archive(url: outputURL, accessMode: .create)
try archive.addEntry(with: "[Content_Types].xml", type: .file, uncompressedSize: ..., provider: { ... })
// ... repeat for all parts
```

**Step 6 — Wire into UI:**

- `MacCollectionManagerView.swift` — add `.docx` to the export format picker
- `CollectionEditorView.swift` — add `.docx` to the iOS export format picker (if
  present)

**Session 82 goal:** A `.docx` that opens in Word with a cover page and readable
plain-text document bodies. Rich formatting is deferred to Session 83.

#### Files to Modify — Session 82

| File | Change |
|------|--------|
| `FRUSExplorer/Collections/DocxCollectionExporter.swift` (new) | Full DOCX exporter implementation |
| `FRUSExplorer/Collections/CollectionExporter.swift` | Add `.docx` to `ExportFormat`; register `DocxCollectionExporter` |
| `FRUSExplorer/UI/macOS/MacCollectionManagerView.swift` | Add DOCX to export format picker |
| `FRUSExplorer/UI/iOS/CollectionEditorView.swift` | Add DOCX to export format picker (iOS) |
| `Package.swift` | Add ZipFoundation dependency |

---

### Session 83 — DOCX Export Part 2: Rich Content + Italic Fix

**Scope:** Backlog #15 (complete DOCX rich content) + Backlog #2 (italic formatting
bug in collection notes).  
**Effort:** Medium (one session, ~3–4 hours). Mostly mechanical Open XML generation;
italic fix is small but touches three files.  
**Risk:** Low–Medium. DOCX rich content layers on top of the working infrastructure
from Session 82. Italic fix is isolated.  
**Prerequisite:** Session 82 must be complete.

#### DOCX Rich Content

**Paragraph formatting via `<w:rPr>` run properties:**

Map render nodes to Word XML run properties:

- `.emphasis(.bold, ...)` → `<w:b/>`
- `.emphasis(.italic, ...)` → `<w:i/>`
- `.emphasis(.smallCaps, ...)` → `<w:smallCaps/>`
- `.emphasis(.underline, ...)` → `<w:u w:val="single"/>`
- `.footnoteMarker` → `<w:vertAlign w:val="superscript"/>` with reference number

**Footnotes via Word footnote mechanism:**

Use `word/footnotes.xml` and `<w:footnoteReference>` in the main document body.
Add `word/footnotes.xml` to the ZIP, register in `[Content_Types].xml`, and link
via `word/_rels/document.xml.rels`.

```xml
<w:footnotes>
  <w:footnote w:id="1">
    <w:p><w:r><w:t>Footnote text here.</w:t></w:r></w:p>
  </w:footnote>
</w:footnotes>
```

**Cover page:**

First page of `word/document.xml`: collection title as Heading1, export date, volume
count, document count — all as styled `<w:p>` blocks with appropriate `<w:pStyle>`.

**Table of Contents:**

Use Word's field-code approach for an updateable TOC:

```xml
<w:p>
  <w:fldChar w:fldCharType="begin"/>
  <w:instrText> TOC \o "1-2" \h </w:instrText>
  <w:fldChar w:fldCharType="end"/>
</w:p>
```

Word will prompt the user to update the TOC on first open — this is the standard
behaviour for field-code TOCs and requires no server-side generation.

#### Italic Fix (Backlog #2)

**Problem:** The collection note field passes through `escaped()` in
`HTMLCollectionExporter`, which preserves Markdown underscores literally.
`PDFCollectionExporter` similarly emits the note as plain text, losing `_text_`
italic intent.

**Fix — `HTMLCollectionExporter.swift`:**

Add a lightweight Markdown-to-HTML pass for the collection note field before HTML
insertion:

```swift
private func markdownItalics(_ input: String) -> String {
    // Replace _text_ with <em>text</em> (non-greedy).
    // Does not attempt full Markdown parsing — note field only.
    input.replacingOccurrences(of: #"_([^_]+)_"#,
                               with: "<em>$1</em>",
                               options: .regularExpression)
}
```

Apply `markdownItalics` to the note string before embedding in HTML output.

**Fix — `PDFCollectionExporter.swift`:**

Parse `_text_` spans in the collection note `String` and apply
`NSAttributedString.Key.obliqueness` (or italic font attribute) to matched ranges.
A simple regex scan over the note string with `NSRegularExpression` is sufficient —
no full Markdown parser needed.

#### Files to Modify — Session 83

| File | Change |
|------|--------|
| `FRUSExplorer/Collections/DocxCollectionExporter.swift` | Add rich paragraph formatting, footnote XML, cover page, TOC field code |
| `FRUSExplorer/Collections/HTMLCollectionExporter.swift` | Add `markdownItalics(_:)` helper; apply to collection note field |
| `FRUSExplorer/Collections/PDFCollectionExporter.swift` | Add italic-span detection for collection note `AttributedString` |

---

### Session 84 — Small UI Fixes

**Scope:** Backlog #12 (macOS Research Strip collapse behaviour) + Backlog #13
(iOS Settings storage index size not reporting).  
**Effort:** Low (one session, ~2 hours total — approximately 1 hour per fix).  
**Risk:** Low. Both changes are isolated with no cross-feature impact.

#### Fix A — Backlog #12: Remove Research Strip Collapse Behaviour (macOS)

**Problem:** `MacDocumentView.swift` has a `@State var researchStripCollapsed: Bool`
and a collapse/expand toggle button. The collapsed state hides the research strip,
making it difficult to rediscover. Per design intent, the strip should always be
visible.

**Fix:**

1. Remove `@State var researchStripCollapsed` declaration from `MacDocumentView`.
2. Remove the collapse button (the button that sets `researchStripCollapsed = true`).
3. Remove the re-expand "+" button (the button shown when `researchStripCollapsed`
   is `true`).
4. Remove all `if researchStripCollapsed { ... } else { ... }` conditional layout
   branches. The strip `ResearchStripView(...)` should be unconditionally present in
   the `HSplitView` or `HStack` layout.
5. Verify the strip width is still constrainable by the `NavigationSplitView` or
   split-view drag handle.

#### Fix B — Backlog #13: iOS Settings — Storage Index Size Not Reporting

**Problem:** In `SettingsView.swift` (or `StorageManagementView`), the SQLite index
size reads as zero or `nil` on iOS. The root cause is likely a wrong URL being
passed to `FileManager.attributesOfItem(atPath:)`.

**Fix:**

1. Locate the size-reporting code in `SettingsView.swift` /
   `StorageManagementView`.
2. Compare the URL it constructs against the canonical URL from
   `FRUSExplorerApp.makeDatabaseURL()`. The database lives at:
   `{Application Support}/FRUSExplorer/frus.db` in the iOS sandbox.
3. Replace the ad-hoc URL construction with a call to `FRUSExplorerApp.makeDatabaseURL()`
   (or extract `makeDatabaseURL()` into a shared `AppConstants` location if it is not
   already accessible from the Settings module).
4. Use `FileManager.default.attributesOfItem(atPath: dbURL.path)[.size] as? Int` and
   format with `ByteCountFormatter`.

#### Files to Modify — Session 84

| File | Change |
|------|--------|
| `FRUSExplorer/UI/macOS/MacDocumentView.swift` | Remove `researchStripCollapsed` state, collapse button, expand button, and conditional layout |
| `FRUSExplorer/UI/iOS/SettingsView.swift` | Fix DB URL lookup for storage index size reporting |

---

### Session 85 — Handoff / Continuity + Spotlight Integration

**Scope:** Backlog #4 (NSUserActivity for cross-device document continuity) +
Backlog #8 (CoreSpotlight indexing).  
**Effort:** Low (one session, ~3 hours). Both features are purely additive with no
model changes and no network calls.  
**Risk:** Low. No regression surface; both features degrade gracefully if the
system does not support them.

#### Handoff (Backlog #4)

**Activity type constant:**

Define a shared constant (e.g. in a `AppActivityTypes.swift` constants file):

```swift
enum AppActivityTypes {
    static let document = "com.joshbotts.frus-explorer.document"
}
```

Register under `NSUserActivityTypes` in `Info.plist` for both macOS and iOS targets.

**In `MacDocumentView` and `DocumentView` (iOS):**

When a document is opened, create and activate the activity:

```swift
let activity = NSUserActivity(activityType: AppActivityTypes.document)
activity.title = document.title
activity.userInfo = ["volumeId": volumeId, "documentId": documentId]
activity.isEligibleForHandoff = true
activity.becomeCurrent()
self.userActivity = activity
```

Update `userActivity` whenever the viewed document changes. Resign the activity
in `onDisappear`.

**In app entry point / `ContentView`:**

```swift
.onContinueUserActivity(AppActivityTypes.document) { activity in
    guard let volumeId = activity.userInfo?["volumeId"] as? String,
          let documentId = activity.userInfo?["documentId"] as? String else { return }
    navigationModel.navigateTo(volumeId: volumeId, documentId: documentId)
}
```

No model changes, no new SwiftData entities.

#### Spotlight Integration (Backlog #8)

**After `IndexingPipeline.indexVolume()` completes for a volume:**

```swift
import CoreSpotlight

let items: [CSSearchableItem] = indexedDocuments.map { doc in
    let attrs = CSSearchableItemAttributeSet(contentType: .text)
    attrs.title = doc.title
    attrs.contentDescription = String(doc.bodyText.prefix(200))
    attrs.keywords = [doc.volumeId, doc.documentId]
    return CSSearchableItem(
        uniqueIdentifier: "\(doc.volumeId)/\(doc.documentId)",
        domainIdentifier: doc.volumeId,
        attributeSet: attrs
    )
}
CSSearchableIndex.default().indexSearchableItems(items) { _ in }
```

**On volume removal / unindex:**

```swift
CSSearchableIndex.default().deleteSearchableItems(
    withDomainIdentifiers: [volumeId]
) { _ in }
```

**Spotlight tap continuation** in the app entry point:

```swift
.onContinueUserActivity(CSSearchableItemActionType) { activity in
    guard let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }
    let parts = id.split(separator: "/", maxSplits: 1).map(String.init)
    guard parts.count == 2 else { return }
    navigationModel.navigateTo(volumeId: parts[0], documentId: parts[1])
}
```

#### Files to Modify — Session 85

| File | Change |
|------|--------|
| `FRUSExplorer/AppActivityTypes.swift` (new) | Define `AppActivityTypes.document` constant |
| `FRUSExplorer/UI/macOS/MacDocumentView.swift` | Set and update `userActivity` on document open |
| `FRUSExplorer/UI/iOS/DocumentView.swift` | Set and update `userActivity` on document open |
| `FRUSExplorer/App/FRUSExplorerApp.swift` (or `ContentView.swift`) | Handle `onContinueUserActivity` for Handoff and Spotlight tap |
| `FRUSExplorer/Search/IndexingPipeline.swift` | Submit `CSSearchableItem` records after `indexVolume()`; delete on unindex |
| `FRUSExplorer-iOS/Info.plist` + `FRUSExplorer-macOS/Info.plist` | Add `NSUserActivityTypes` entry for `com.joshbotts.frus-explorer.document` |

---

### Session 86 — Zotero / RIS / BibTeX Citation Export

**Scope:** Backlog #6. Add BibTeX, RIS, and plain-text clipboard export to the
citation popover on macOS and iOS.  
**Effort:** Low (one session, ~2–3 hours). Pure string interpolation; no new
dependencies.  
**Risk:** Low. Purely additive; no changes to existing citation formatting logic.

#### Implementation

`HistoryAtStateCitationFormatter` already computes all required fields: authors,
title, series, year, document number, and URL. Both exporters are pure functions:

**`BibtexExporter.swift`:**

```swift
struct BibtexExporter {
    func format(_ citation: FormattedCitation) -> String {
        let key = citation.documentId.replacingOccurrences(of: ":", with: "-")
        return """
        @misc{\(key),
          author    = {\(citation.authors.joined(separator: " and "))},
          title     = {\(citation.title)},
          howpublished = {\\url{\(citation.url)}},
          year      = {\(citation.year)},
          note      = {\(citation.seriesTitle), \(citation.volumeTitle)}
        }
        """
    }
}
```

**`RISExporter.swift`:**

```swift
struct RISExporter {
    func format(_ citation: FormattedCitation) -> String {
        var lines = ["TY  - GEN"]
        for author in citation.authors { lines.append("AU  - \(author)") }
        lines += [
            "TI  - \(citation.title)",
            "PY  - \(citation.year)",
            "UR  - \(citation.url)",
            "N1  - \(citation.seriesTitle), \(citation.volumeTitle)",
            "ER  - "
        ]
        return lines.joined(separator: "\n")
    }
}
```

**Export buttons in citation popovers:**

Add an "Export Citation" menu or toolbar group with three actions:
- Copy BibTeX to clipboard
- Copy RIS to clipboard
- Share `.bib` file (write to `NSTemporaryDirectory()` and present system share
  sheet / `NSSharingServicePicker` on macOS)

Apply to both `MacDocumentView` citation sheet and `DocumentView` (iOS) citation
sheet.

#### Files to Modify — Session 86

| File | Change |
|------|--------|
| `FRUSExplorer/Citations/BibtexExporter.swift` (new) | `BibtexExporter.format(_:)` |
| `FRUSExplorer/Citations/RISExporter.swift` (new) | `RISExporter.format(_:)` |
| `FRUSExplorer/UI/macOS/MacDocumentView.swift` | Add export citation actions to citation sheet |
| `FRUSExplorer/UI/iOS/DocumentView.swift` | Add export citation actions to citation sheet |

---

### Session 87 — Person / Entity Index View

**Scope:** Backlog #5. New `PersonIndexView` — a grouped alphabetical list of all
persons mentioned in the indexed corpus (or scoped to a volume/project), with mention
count per person.  
**Effort:** Low (one session, ~3 hours). Read-only queries; no writes; no model
changes.  
**Risk:** Low. `PersonMentionStore` already exposes the required data.

#### Implementation

`PersonMentionStore` already exposes person ref → name + count queries. No new
model entities are needed.

**`PersonIndexView` body:**

```swift
struct PersonIndexView: View {
    @State private var sections: [PersonIndexSection] = []

    var body: some View {
        List {
            ForEach(sections) { section in
                Section(header: Text(section.letter).font(.headline)) {
                    ForEach(section.persons) { person in
                        PersonRowView(person: person)
                            .onTapGesture {
                                navigateToSearch(personRef: person.ref)
                            }
                    }
                }
            }
        }
        .task { sections = await PersonMentionStore.shared.allPersonsSortedByName() }
        .navigationTitle("People")
    }
}
```

`PersonIndexSection` groups `PersonMentionRecord` instances by first letter of name.

**Navigation:** On tap, set `SearchParameters.personRef` to the selected person's
ref value and push to `SearchView` with the filter active. This reuses the existing
`personRef` search parameter without any new query logic.

**Platform placement:**

- macOS: new pane accessible from the Corpus Browser toolbar ("People" button or
  tab icon), or a "People" tab in the sidebar.
- iOS: new "People" section in the Browse tab, or a dedicated "People" tab in the
  main tab bar.

#### Files to Modify — Session 87

| File | Change |
|------|--------|
| `FRUSExplorer/UI/PersonIndexView.swift` (new) | Full `PersonIndexView` implementation with grouped list and navigation |
| `FRUSExplorer/UI/macOS/MacCorpusBrowserView.swift` (or sidebar) | Add entry point for People pane |
| `FRUSExplorer/UI/iOS/BrowseTabView.swift` (or `MainTabView.swift`) | Add People section or tab |

---

### Session 88 — Document Timeline View

**Scope:** Backlog #7. New `TimelineView` visualising a search result set or
collection's documents in chronological order using Swift Charts.  
**Effort:** Low (one session, ~3–4 hours). New view; no writes; no model changes.
Only dependency is Swift Charts (in the SDK since macOS 13 / iOS 16).  
**Risk:** Low. `document_cache` already carries `date_iso` and `date_iso_max` columns
from Session 76.

#### Implementation

**`TimelineView` accepts either `[SearchResult]` or `[DocumentBrowserEntry]`.**

Two display modes toggled by a toolbar button (chart icon vs list icon):

**Mode A — Bar Chart:**

```swift
import Charts

Chart {
    ForEach(yearGroups) { group in
        BarMark(
            x: .value("Year", group.year),
            y: .value("Documents", group.count)
        )
        .foregroundStyle(by: .value("Subseries", group.subseries))
    }
}
.chartXAxis { AxisMarks(values: .automatic(desiredCount: 10)) }
.chartYAxis { AxisMarks() }
.onTapGesture(coordinateSpace: .local) { point in
    // Determine tapped year; push to filtered search for that year
}
```

Group documents by year using `Calendar.current.component(.year, from: dateISO)`.

**Mode B — List Mode:**

Scrollable list with year/month section headers and document cards. Uses the
same `yearGroups` data structure, expanded to month groups within each year if the
visible date range spans fewer than 3 years.

**Documents without reliable dates** (nil `date_iso`) are excluded from both modes.
A disclosure note appears below the chart/list:

> "N documents have no reliable date and are excluded from the timeline."

**Surface:**

- View-mode toggle (chart icon) in the Search results toolbar: when active, replaces
  the results list with `TimelineView(documents: searchResults)`.
- In the Collection detail pane: a "Timeline" tab or toolbar button showing
  `TimelineView(documents: collection.documents)`.

#### Files to Modify — Session 88

| File | Change |
|------|--------|
| `FRUSExplorer/UI/TimelineView.swift` (new) | Full `TimelineView` with bar chart + list mode, year grouping, exclusion note |
| `FRUSExplorer/UI/macOS/MacSearchView.swift` | Add timeline toggle to search results toolbar |
| `FRUSExplorer/UI/iOS/SearchView.swift` | Add timeline toggle to search results toolbar |
| `FRUSExplorer/UI/macOS/MacCollectionDetailView.swift` | Add timeline tab/button to collection detail |

---

## Session Dependency Summary

```
Sessions 77–80 (TEI Fidelity)
        │
        ▼
Session 81 (Rich Rendering in Exports)   ◄── CRITICAL PATH
        │
        ├──► Session 82 (DOCX Part 1: Infrastructure)
        │           │
        │           ▼
        │    Session 83 (DOCX Part 2: Rich Content + Italic Fix)
        │
        │    [Independent — can run in any order after Session 80]
        │
        ├──► Session 84 (Small UI Fixes)
        ├──► Session 85 (Handoff + Spotlight)
        ├──► Session 86 (Citation Export)
        ├──► Session 87 (Person Index View)
        └──► Session 88 (Timeline View)
```

Sessions 84–88 have no dependency on Session 81 and can be scheduled in parallel
with the 81–83 export track if multiple development streams are available, or
interleaved in any order as time allows.

Sessions 82 and 83 form a strict sequence: 82 must be complete before 83 begins.
Session 81 must be complete before 82 begins (DOCX Part 2 rich content requires the
render model infrastructure introduced in 81).

---

## Reference: Key Export File Locations

| Component | File |
|-----------|------|
| Export document model + protocol | `FRUSExplorer/Collections/CollectionExporter.swift` |
| PDF exporter | `FRUSExplorer/Collections/PDFCollectionExporter.swift` |
| HTML exporter | `FRUSExplorer/Collections/HTMLCollectionExporter.swift` |
| DOCX exporter (new in Session 82) | `FRUSExplorer/Collections/DocxCollectionExporter.swift` |
| Render service (new in Session 81) | `FRUSExplorer/Services/DocumentRenderService.swift` |
| Collection manager UI (macOS) | `FRUSExplorer/UI/macOS/MacCollectionManagerView.swift` |
| Collection editor UI (iOS) | `FRUSExplorer/UI/iOS/CollectionEditorView.swift` |
