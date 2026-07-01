<!-- Generated 2026-06-30 from a multi-agent investigation of the corpus browser
     (macOS hierarchy, in-volume nesting model, Sources rendering, iOS layout) plus
     history.state.gov structure research. Reviewed and endorsed for implementation. -->

# FRUS Explorer — Corpus Browser Rework: Implementation Plan

Audience: implementing developer. All paths under `/Users/jbotts/Development/FRUS-Explorer/`. Line numbers are from the investigations and will drift as you edit — re-grep before each change.

Reference URLs (history.state.gov, mirror targets):
- Year-volume TOC: `https://history.state.gov/historicaldocuments/frus1925v01` · compilation `/frus1925v01/comp1` · document `/frus1925v01/d1`
- Conference volume: `https://history.state.gov/historicaldocuments/frus1945Malta`
- Sub-series year-span: `https://history.state.gov/historicaldocuments/frus1952-54v08`
- Sources page: `https://history.state.gov/historicaldocuments/frus1969-76v02/sources`

---

## Item 1 — macOS resizable progressive disclosure

### Recommended rearchitecture: Option A — `NavigationStack` in the detail column

Replace the sheet spine (volume-detail sheet → nested section sheet) with a single `NavigationStack` living in the `NavigationSplitView` detail column of `CorpusBrowserWindowView`. Every pushed level fills the detail column, inherits window resizability, and gets the system `⌘[` back button. This mirrors both the iOS browser (`BrowserView` single `NavigationStack`) and the app's own macOS document reader (`MainWindowView.swift:103–112`, `NavigationStack(path:) + .navigationDestination`).

Options B (three-column split) and C (outline group as the spine) are rejected: FRUS has variable-depth hierarchy plus non-list front-matter destinations (persons/sources/prose) and a final "open in main window" hand-off that neither can express cleanly. (`OutlineGroup` is still the right tool *inside* a pushed volume view — see Item 2.)

### Deep-link safety (why Option A is low-risk)

The volume-detail and section sheets are presented **only** from within `SupportingViews.swift` (tap at `:2985`; `openSection` at `:3389`). No other surface opens an intermediate sheet — every "navigate to a document" path across Search/CrossReference/Citation/History/Research goes through `AppState.pendingBrowseDocument`, consumed by `MainWindowView.swift:119–123`. The only external entry to the window is `openWindow(id: "frus.corpusBrowser")` (`MainWindowView.swift:275`), which lands on the split-view root and is unaffected. There is **no deep-link targeting an intermediate sheet**, so no cross-surface migration is needed. The final document hand-off stays identical (`onDocumentSelected` → `pendingBrowseDocument`).

### Files to change

All in `FRUSExplorer/App/SupportingViews.swift` (the `#if os(macOS)` range, 2694–3762):
- `CorpusBrowserWindowView` (`:2694`, body detail column `:2762–2772`)
- `SubseriesVolumeListView` (tap site `:2985`)
- `CorpusVolumeDetailSheet` → rename to `CorpusVolumeDetailView` (`:3020`; header `:3040–3050`; frame `:3056`; `openSection` `:3380–3391`; nested sheet `:3440–3445`)
- `CorpusSectionDocumentListView` → rename to `CorpusSectionDocumentView` (`:3577`; title row `:3608–3612`; Done bar `:3701–3709`; frame `:3711`)

Reference to copy: `MainWindowView.swift:103–112`.

### Step-by-step change list

1. **Add a nav value type** near `CorpusBrowserWindowView`:
   ```swift
   enum CorpusNavValue: Hashable {
       case volume(VolumeManifestEntry)
       case section(volumeId: String, section: VolumeSection)
   }
   ```
   Confirm `VolumeManifestEntry` and `VolumeSection` synthesize `Hashable`. `VolumeSection` (`VolumeStructure.swift:34`) is recursive via `subsections` (`:60`) but synthesizes cleanly. If `VolumeManifestEntry` has a non-Hashable field, key the case on `volumeId: String` and re-look-up.

2. **Add path state** on `CorpusBrowserWindowView`: `@State private var detailPath: [CorpusNavValue] = []`. Pass `$detailPath` down to `SubseriesVolumeListView` and the pushed volume view as a `@Binding` (the path currently owned as `@State sheetContent` at `:2882` moves up here).

3. **Wrap the detail column** (`:2762–2772`) in a `NavigationStack(path: $detailPath)` with the volume list as root and destinations:
   ```swift
   } detail: {
       NavigationStack(path: $detailPath) {
           detailRoot   // volumeList(for:) or the "Select a Subseries" prompt
               .navigationDestination(for: CorpusNavValue.self) { value in
                   switch value {
                   case .volume(let v):           CorpusVolumeDetailView(volume: v, path: $detailPath)
                   case .section(let vid, let s): CorpusSectionDocumentView(volumeId: vid, section: s, path: $detailPath)
                   }
               }
       }
   }
   ```

4. **Reset the path on subseries change**: `.onChange(of: selectedSubseries) { detailPath = [] }` so switching subseries returns to the volume-list root (avoids a stale pushed volume).

5. **`SubseriesVolumeListView`**: change `.onTapGesture { sheetContent = .detail(vol) }` (`:2985`) to `path.append(.volume(vol))`. **Keep the graph button as a `.sheet`** (`:2899`) — a graph is a genuine self-contained modal task; HIG-appropriate. Same for the People sheet (`:2774`).

6. **`CorpusVolumeDetailSheet` → `CorpusVolumeDetailView`**: delete the manual header row (`:3040–3050`) and `.frame(minWidth: 500, minHeight: 440)` (`:3056`); add `.navigationTitle(volume.title)`. In `openSection` (`:3380–3391`) replace `selectedSection = section` (`:3389`) with `path.append(.section(volumeId: volume.volumeId, section: section))`; delete the nested `.sheet(item: $selectedSection)` (`:3440–3445`). All phase logic (download/index/loadStructure, `:3122–3160`) is unchanged — it just runs in a pushed view.

7. **`CorpusSectionDocumentListView` → `CorpusSectionDocumentView`**: delete the manual title row (`:3608–3612`), the bottom Done bar (`:3701–3709`), and `.frame(minWidth: 460, minHeight: 400)` (`:3711`); add `.navigationTitle(section.title)`. Preserve the prose/persons/sources/document-list branch (`:3616–3699`) verbatim — but see Item 2 for the subsection branch it must gain. Accept `path` binding so it can push deeper sections.

8. **Document hand-off unchanged**: `onDocumentSelected` still sets `appState.pendingBrowseDocument` (`:3441–3444` / `:3681–3683`); drop the now-redundant `dismiss()` calls (harmless no-ops in a push context, but cleaner to remove).

9. Rename symbols and update all call sites; rebuild the macOS scheme (`FRUSExplorerMac`).

**Risks**: path state ownership (must live on the window, not the list); the `.onChange` reset is required; `Hashable` conformance (see step 1).

---

## Item 2 — Hierarchical nesting consistent with history.state.gov

### Target nesting model (from D)

history.state.gov is **one recursive, arbitrarily-deep outline tree** — every node is a title (+ optional "Documents N–M" range), rendered identically at every depth. Depth is data-driven per volume: 2 levels (simple) to 5+ (`frus1952-54v08` Trieste: country→topic→5 phases→docs; `frus1945Malta`: Part→Chapter→16 sub-chapters→day→meeting→doc). Three axes must all work: **topical** (`frus1925v01`), **chronological/conference** (`frus1945Malta`, with "Part I/II/III" and "Chapter N:" labels), and **country** (`frus1952-54v08`). Interior grouping nodes ("General", "Part I", "Trieste", "NARA") have no documents of their own — they only contain child groups. Documents are numbered **volume-wide** (1…512 across parts), labeled number + descriptive title + date, no abstract in the canonical view.

### What the app does wrong (from B)

- **The model is fine (M1)**: `VolumeSection.subsections` (`VolumeStructure.swift:60`) is unbounded; the stack-based parser (`FRUSDocumentParser.swift:307`) has no depth cap.
- **macOS renders only 2 structural levels (M2)**: `CorpusSectionDocumentListView` has no subsection branch; `loadDocuments()` filters by `section.allDocumentIds` (`SupportingViews.swift:3722–3727`, using `VolumeStructure.swift:65`), **flattening every descendant document into one list** and discarding chapter boundaries. This is the headline defect.
- **iOS double-counts (M3)**: `CompilationView` shows a subsection list *and* a document list built from `allDocumentIds` (`CompilationView.swift:78–83`; `BrowserViewModel.swift:310`), so documents appear both directly and inside each child.
- **Unknown body wrappers dissolve (M4)**: only `{compilation, chapter, subchapter, appendix, …}` are recognized (`FRUSDocumentParser.swift:344`); any grouping `divType` outside that set is transparently flattened, losing its `<head>` (`:425–435`, `:495–519`). A `type="part"` above compilations (as in conference volumes) would vanish.
- **Front/Contents/Back re-partitions by kind, not document order (M8)**: `extractFrontMatter`/`extractBackMatter` + `isFrontMatterKind` (`VolumeView.swift:200–204`; `SupportingViews.swift:3402–3406`).

### Changes (keep macOS and iOS consistent)

**Parser / model (`FRUSDocumentParser.swift`, `VolumeStructure.swift`):**
1. Extend the recognized body vocabulary. Add whatever grouping kinds the real corpus uses above compilations to `structuralTypes` (`:344`) and give them a real branch in `structuralKind` (`:362`) so `part`, sub-compilation, and conference "chapter" wrappers **emit a `VolumeSection` (preserving `<head>`)** instead of a transparent frame (M4/M6). Verify against a conference volume (`frus1945Malta`) and a country volume (`frus1952-54v08`) locally before finalizing the set — do not guess kinds.
2. Preserve document order for Front/Contents/Back (M8): treat the partition as annotation over document-order sections rather than reordering buckets, so a mis-typed section doesn't jump groups. (Lower priority; verify against h.state.gov ordering first.)
3. No schema change needed for depth — the `volume_structures` Codable cache already round-trips arbitrary nesting.

**Rendering — the shared contract (both platforms):**
A node with `!subsections.isEmpty` lists **only `documentIds`** (direct children) for its own document rows, and lists `subsections` as drill-down rows. A leaf node (`subsections.isEmpty`) lists its documents. This single rule fixes both M2 (macOS gains the subsection branch) and M3 (iOS stops double-counting via `allDocumentIds`).

4. **macOS `CorpusSectionDocumentView`** (formerly `CorpusSectionDocumentListView`): add a subsections branch mirroring iOS `CompilationView.subsectionsList` (`CompilationView.swift:126–142`). Each subsection row does `path.append(.section(volumeId:section:))` (the Item 1 push). Change its document list from `allDocumentIds` to `documentIds` when subsections exist. Since Item 1 makes this a pushed view, arbitrary depth now works with no new screens.
5. **iOS `CompilationView` / `BrowserViewModel.loadDocuments`** (`BrowserViewModel.swift:303–318`): when `!section.subsections.isEmpty`, load `section.documentIds` (direct) rather than `section.allDocumentIds`. The recursion already exists via `.compilation(...)` push (`CompilationView.swift:132`).
6. **Labels**: prefer the node `<head>` (already `title`) as the primary row label and use `divType` as a subtitle; add cases to `SectionRowLabel.sectionTypeLabel` (`VolumeView.swift:412–457`) for any new kinds so they don't render a raw `divType` string. Support the "Part"/"Chapter N:" and "(Documents N–M)" annotations from D.

**Consistency check**: both platforms now use the identical "direct docs + child sections" render rule and the identical push-to-recurse navigation. Optional follow-up (M7): persist each document's enclosing `sectionId` chain at index time to enable full breadcrumbs on macOS (the `page_ranges` builder already records containing section IDs — `Planning/09-16-Search-Views.md:82`).

---

## Item 3 — Sources section

### (a) Presentation fix

**Root cause (from C)** — all three defects originate in `SourcesParserDelegate` (`FRUSDocumentParser.swift:1652–1796`), not the view. The view (`VolumeSourcesView.swift:171`, `Text(entry.rawText)`) faithfully renders bad data:
- **Defect A**: `<p>` is treated identically to `<item>` (`:1699`, `:1717`), so all ~17 narrative "Note on Sources" paragraphs become source rows.
- **Defect B**: a single shared `textBuffer` is reset on every `<item>` open (`:1701`, `:1705–1708`, `:1724`), destroying parent `<hi rend="strong">` collection headings (`Department of State`, `Record Group 59…`, `Nixon Presidential Materials`, etc.) when the item has a child `<list>`. The 4-level hierarchy collapses to a flat list; `PRIMARY KEY (volume_id, entry_text)` (`IndexingPipeline.swift:3304`) silently dedupes.
- **Defect C**: interior newlines/indent runs are never collapsed (`:1718` only end-trims), so hard-wraps render verbatim.

**Concrete rendering fix** — mirror `frus1969-76v02/sources`: essay first (flowing prose), then an indented nested outline of collections under bold repository/record-group headings.

*Phase 1 (presentation-only, no re-index — ship the visible win now):* In `VolumeSourceRow` (`VolumeSourcesView.swift:171`) collapse interior whitespace before display — `entry.rawText.split(whereSeparator: \.isWhitespace).joined(separator: " ")` — and add `.textSelection(.enabled)`. This kills the hard-line-break/ragged-indent symptom against today's data.

*Phase 2 (parser + schema + re-index — the real fix):*
1. Rewrite `SourcesParserDelegate` to emit a typed model, not a flat `[VolumeSourceEntry]`:
   - Stop treating `"p"` as `"item"` (remove `|| elementName == "p"` at `:1699` and `:1717`); collect `<p>` runs into an ordered `prose: [String]` block.
   - Use a **depth-tracked stack** of in-progress items keyed by `<list>` depth; capture each item's own text (characters before its first nested `<list>`) separately from children. New node:
     ```swift
     struct VolumeSourceNode: Sendable, Identifiable {
         let id = UUID()
         let text: String            // own heading/description, whitespace-collapsed
         let isHeading: Bool         // wrapped a <hi rend="strong">
         let recordGroup: String?    // existing rgPat
         let lotFile: String?        // existing lotPat
         let depth: Int
         let children: [VolumeSourceNode]
     }
     ```
   - Set `isHeading` when an `<hi rend="strong">` opens inside an item.
   - Collapse whitespace at capture: `text.split(whereSeparator: \.isWhitespace).joined(separator: " ")` — apply to prose too.
2. **Schema** (`volume_sources`, `IndexingPipeline.swift:3304`): add `depth INTEGER`, `is_heading INTEGER`, `kind TEXT` (`prose`|`item`); keep `sort_order`; change PK to `(volume_id, sort_order)` so nothing dedupes. Update insert (`:3628`) and read-back (`volumeSources`, `:1536`).
3. **View** (`VolumeSourcesView.swift`): two regions —
   - "About These Sources": render `prose` paragraphs as flowing body text (`.font(.callout)`, `.textSelection(.enabled)`, full width, no bullets); optionally behind a disclosure.
   - "Archival Collections": `OutlineGroup(nodes, children: \.children)`, **bold** `isHeading` nodes (the major collections — the single most important change), indent by `depth`, keep the `archivebox` Archival Neighbors affordance (`:188–198`; gating `makeNeighborsTarget` `:116–126` unchanged), `.textSelection(.enabled)` throughout. Filter (`:44–48`) on node text, surfacing heading ancestors for context.

**Why this matters for Archival Neighbors**: the bold `<hi rend="strong">` headers are exactly the major collections a researcher must see (`Department of State`, `RG 59`, `Nixon Presidential Materials`, `CIA`, `RG 330`, …). Today they're lost. Preserving the tree isn't cosmetic — the parent/child relationship *is* the structured provenance (`DEF 1 US` means nothing except as *RG 59 → Subject–Numeric Central Files → DEF 1 US*), and those same keys (`lotFile`, `(recordGroup, series)`) are what `IndexingPipeline.archivalNeighbors` (`:4092`, lot query `:4123`, collection query `:4157`) joins against per-document provenance.

On macOS, this outline lives in the resizable detail column (Item 1), not a `.frame`-constrained sheet, so long lists scroll naturally.

### (b) Harvesting plan (next session; all volumes local)

**Goal**: parse every front-matter Sources section across all volumes, extract each named archival collection / lot file / record group / repository, resolve each to a NARA Catalog NAID, dedupe, and bundle a cross-volume authority into the pre-shipped NARA index.

**Prerequisite**: the corrected `SourcesParserDelegate` from 3(a) Phase 2 — it *is* the harvest extractor (hierarchical nodes + prose, with `<hi rend="strong">` headers, `recordGroup`, `lotFile`, series names retained).

**Data flow:**
1. **Extract** — run the corrected delegate over all locally-downloaded volumes (`/Users/jbotts/Development/frus/volumes/*.xml`). Emit per volume: prose block (discard for harvest) + the node tree. Per node capture: text, `isHeading`, `depth`, `recordGroup` (`rgPat`, `:1667`), `lotFile` (`lotPat`, `:1669`), series/sub-collection names (2nd/3rd-level items), leaf file-designators (`DEF 1 US`, `POL 2`, …), repository name (repo keyword list `:1759–1766`; fuller list in `SourceNoteParser.tryPresidentialLibrary` `:600`).
2. **Resolve each node to a NAID** by joining to the **existing bundled index** first (no network, no key):
   - Lot-file nodes → `CentralFilesIndexStore.lotFile(forRawLot:)` (`SourceExplorer/CentralFilesIndex.swift:63`; 979 `lotFiles` entries with `naId`/`catalogURL`).
   - Numerical-file / country-series references → `numericalFile.rolls(forFileNumber:)` / `countrySeries` `rolls(...)` (`CentralFilesIndex.swift:146,237,246`).
   - RG-only / repository headers with no bundled hit → **NARA Catalog API**, reusing `CentralFilesIndexGenerator` patterns (the `SURVEY_SERIES` / `CITATIONS_CSV` pre-resolve paths already exist per CLAUDE.md). D→RG 59, F→RG 84 lot mapping via `SourceNoteParser.lotFileRecordGroup` (`SourceNoteParser.swift:450`).
3. **Dedupe** — a bold-header collection recurs across many volumes. Aggregate into a deduplicated authority keyed by `(repository, recordGroup, series, lotFile)`, tracking the set of `volumeId`s each collection appears in.
4. **Bundle** — write the cross-volume authority as a new artifact and/or extend `central-files-index.json`.

**New/changed SPM generator**: add a target (e.g. `VolumeSourcesIndexGenerator`) or a mode on `CentralFilesIndexGenerator`, mirroring the existing generators in `Package.swift`. It should: (i) reuse the TEI `SourcesParserDelegate` (factor it into a shared, testable component if it currently lives only in the app target); (ii) load and query the existing bundled index for pre-resolution; (iii) only hit the NARA Catalog API for unresolved RG/series headers.

**Rate-limit / key considerations**: `CATALOG_API_KEY` env var (per CLAUDE.md invocation examples). Resolve against the bundled index first to minimize API calls; batch and cache unresolved headers; respect the granted NARA rate limit (memory: rate limit granted 2026-06-12, harvest unblocked). Persist a resolution cache so re-runs don't re-query.

**Validation**: cross-check resolved NAIDs against the user's forthcoming 10-doc reference data (memory: pre-1910 reference data validates the classifier). Spot-check that the 16 bold headers in `frus1969-76v02` all resolve or are flagged unresolved with a reason. Assert node counts against known fixtures (17 `<p>`, 167 `<item>`, depth 4, 16 strong headers for v02).

**Output artifact**: a bundled JSON (e.g. `volume-sources-index.json` in `FRUSExplorer/Resources/`) mapping `volumeId` → ordered collection tree with resolved `{naId, catalogURL}` per node, plus a deduplicated `majorCollections` authority (repository → RG → series → NAID, with the `volumeIds` each appears in). This both fixes the display (bold, linkable headers) and feeds Archival Neighbors with **volume-level provenance** for eras where per-document source notes are terse.

---

## Item 4 — iOS top-space fix

**Root cause (from E)**: two stacked large top elements at the subseries/volume levels.
- *Primary*: `.navigationBarTitleDisplayMode(.large)` reserves ~52 pt for a big title that, at these levels, merely restates the last breadcrumb crumb — `SubseriesView.swift:79–81` and `VolumeView.swift:71–73` (the breadcrumb already shows `group.subseries` / `entry.title` via `BrowserLevel.breadcrumbLabel`, `CorpusView.swift:229–252`).
- *Secondary*: the breadcrumb bar itself is a second ~48 pt band, injected via `.safeAreaInset(edge: .top)` (`BrowserView.swift:310–323`) with generous padding (`BrowserBreadcrumbBar.swift:68,92,101`).

**Concrete fix**: switch the two deep levels to inline titles, keeping the breadcrumb as the single location label. Reclaims ~52 pt at both levels; doesn't touch the breadcrumb or scroll insets.

In `SubseriesView.swift:79–81` and identically in `VolumeView.swift:71–73`:
```swift
#if os(iOS)
.navigationBarTitleDisplayMode(.inline)
#endif
```
**Leave `CorpusView.swift:79–81` as `.large`** — the root has no redundant crumb; "FRUS Corpus" is the intended landing header. Do not change the `.safeAreaInset` (`BrowserView.swift:310–323`); it keeps scroll insets correct on both `NavigationStack` and `NavigationSplitView`.

*Optional secondary trim* (only if more space wanted): reduce per-crumb `.padding(.vertical, 12)` (`BrowserBreadcrumbBar.swift:92,101`) and preserve the touch target with `.frame(minHeight: 44).contentShape(Rectangle())`. Changes breadcrumb appearance, so the title-mode change is the clean, low-risk primary.

Ruled out: no `Spacer()`, fixed-height header, or empty `Section` — the `.frame(minHeight: 120)` at `VolumeView.swift:185` is only the loading placeholder.

---

## Sequencing & risk

### Suggested order

1. **Item 4 (iOS top-space)** — first. Two-line change, zero dependencies, immediate visible win, no re-index. Build/verify on iPhone 17 simulator; confirm the top band shrinks at subseries and volume levels and the corpus root still shows the large title.
2. **Item 3(a) Phase 1 (Sources whitespace collapse + textSelection)** — second. One-line render change, no schema/re-index, immediate visible win. Verify on both platforms.
3. **Item 1 (macOS NavigationStack spine)** — third. Self-contained refactor of `SupportingViews.swift`, no model/parser changes. Verify: resizable drill-down volume→section→document, back button, subseries-switch resets path, graph/People sheets still open, document hand-off to main window still lands. This unblocks Item 2's macOS subsection branch (needs the push).
4. **Item 2 (hierarchical nesting)** — fourth, in two parts: (a) the shared "direct docs + child sections" render rule on both platforms (fixes macOS M2 + iOS M3 double-count); (b) parser vocabulary extension (M4) *after* verifying the real body-division kinds against local conference (`frus1945Malta`) and country (`frus1952-54v08`) volumes. Part (b) requires a re-index to take effect.
5. **Item 3(a) Phase 2 (Sources parser rewrite + schema + re-index)** — fifth. Requires re-index; produces the hierarchical node model.
6. **Item 3(b) (harvesting)** — last, separate session; depends on 3(a) Phase 2's corrected delegate as the extractor.

Rationale: cheap visible wins first (4, 3a-P1); then the macOS navigation refactor (1) that Item 2 depends on; then model/parser work that requires re-indexing (2b, 3a-P2); harvesting (3b) built on the finished extractor.

### Cross-cutting risks

- **Shared views iOS/macOS**: Item 2's render rule must land identically on `CompilationView`/`BrowserViewModel` (iOS) and `CorpusSectionDocumentView` (macOS). Keep the "direct `documentIds` when subsections exist, else documents" logic in one place (ideally on the view model / `VolumeSection`) so both call it. Remember: iOS `SettingsView` vs macOS `FRUSSettingsView` are parallel — any settings surfaced here must be edited in both (memory: Dual Settings Views).
- **Deep-links**: verified none target intermediate sheets (Item 1). Re-grep `sheetContent = .detail`, `selectedSection =`, `openWindow(id:"frus.corpusBrowser")` before removing the sheets to confirm nothing new was added.
- **Re-index dependency**: Items 2(b) and 3(a)-P2 change indexed data; nothing appears until volumes re-index. User has all volumes locally. Sequence so re-index-dependent changes land together to avoid multiple full re-indexes.
- **Schema migration** (3a-P2): changing `volume_sources` PK from `(volume_id, entry_text)` to `(volume_id, sort_order)` plus new columns needs a migration or table rebuild; guard for existing DBs.
- **`Hashable` conformance** (Item 1): verify `VolumeManifestEntry`/`VolumeSection` synthesize; fall back to `volumeId: String` keying if not.
- **Tests / coding standards** (`CodingStandardsAuditTests`): doc comments on new public/internal types (`CorpusNavValue`, `VolumeSourceNode`), Apache header, `String(localized:)` for any new user-facing strings, zero strict-concurrency warnings. Update `IndexingPipelineTests` fixtures (`:2108–2235`) for the new Sources model and any parser-vocabulary changes; add a regression test that a compilation-with-chapters no longer double-counts (iOS) and no longer flattens (macOS). Update `FRUS-API.openapi.yaml` only if the API surface changes.
- **Build/version**: do NOT run `xcodegen generate` for build bumps; if you do run xcodegen for other reasons, restore schemes with `git checkout -- FRUSExplorer.xcodeproj/xcshareddata/xcschemes/`.

---

## Appendix — Complex-structure volume test matrix


552 volumes total. Structural categories that stress the browser's nesting model,
beyond the user's two examples (frus1925v01, frus1945Malta):

| Category | Exemplars | Structural challenge |
|---|---|---|
| Conference volumes (named) | frus1943CairoTehran, frus1945Malta, frus1945Berlinv01/v02 (Potsdam), frus1944Quebec | Organized by conference sessions/meetings, not chapters; nesting by meeting → document |
| Part + sub-volume (deepest) | frus1872p2v1–v5, frus1873p1v1–v2 | year → PART → sub-VOLUME → content: three structural axes at once |
| Electronic + part + edition | frus1969-76ve15p2, frus1969-76ve15p2Ed2 (also ve05p1/p2, ve09p1/p2, ve11/14/15p1/p2) | "ve" electronic vols, split into parts, some with 2nd editions |
| Topical retrospective | frus1925v01, frus1919Russia, frus1942China, frus1945-50Intel, frus1950-55Intel, frus1951-54Iran(+Ed2), frus1952-54Guat, frus1917-72PubDip, frus1894Nicaragua, frus1901China | Deep topical nesting; some cross unusual date spans; metadata quirks (e.g. frus1951-54Iran subseries 1951-54 but title "1952–1954") |
| Supplements | frus1914Supp, frus1915Supp, frus1916Supp, frus1918Supp02 | Supplement to a base annual volume |
| Appendices | frus1877app, frus1894app1/app2, frus1902app1/app2 | Appendix volumes attached to a year |
| Early country-arranged annuals | frus1861 ("Message of the President… to the Two Houses"), frus1862–1899, many split pN | Country-arranged despatches/instructions/notes; inconsistent early editorial structure |

Counts: 118 volumes lack a numeric vNN token (named/conference/topical/part-only);
108 have a `pN` part token; 63 are pre-1900 annuals.

Recommended browser test set (covers every axis): frus1925v01, frus1945Malta,
frus1943CairoTehran, frus1872p2v3, frus1969-76ve15p2Ed2, frus1861, frus1914Supp,
frus1877app, frus1969-76v02 (standard, for baseline + its Sources page).
