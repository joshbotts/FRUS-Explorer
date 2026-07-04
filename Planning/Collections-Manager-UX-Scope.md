# Collections Manager UX — Discoverability & Control-Surface Proposal

**The ask (owner):** the Collections-Authoring program (Phases 1–6, per `Planning/Collections-Authoring-Scope.md`) added a lot of authoring power — outline editing, excerpts, apparatus, front matter, an inspector, and per-entry overrides — but the *manager UI itself* has not kept up. Controls are hard to find, inconsistently rendered, mislabeled, and jammed into the entry rows. This document is a critical read of the current manager plus a concrete redesign, addressing the owner's six points as recommendations, not options.

**Convention.** Follows `Collections-Authoring-Scope.md` / `Collections-Rework-Scope.md`: file-anchored findings, decision points framed cheap/expensive (**D1–D5**) with a recommended lean, cross-platform manifestation, and a phased sequence honoring the CloudKit / `.fruscollection`-v2 / dual-manager (`CollectionEditorView` + `MacCollectionManagerView`) constraints. Line anchors are from the current branch; treat them as the "where," not a promise they won't drift.

---

## 1. Critical evaluation — where the manager fails to be discovered or understood

The manager grew feature-by-feature (Phases 4–6 each added a knob), and each knob landed *at the nearest available surface* rather than at a designed one. The result is three visual registers for sibling actions, a mislabeled region, and entry rows that are simultaneously reports and control panels. Ranked by severity (how many users hit it × how badly it blocks the authoring goal):

### F1 — The structural "+" is a context-less glyph (owner point 3). **Severity: high.**
`MacCollectionManagerView.swift:717` — the add-structural menu is a bare `Image(systemName:"plus")`, `.caption`, secondary, in the `documentsSection` header. Its `.help` describes the contents, but the glyph alone reads as "add a document/row" — which is exactly what it does **not** do. It adds Section Heading, Note Block, Highlighted Passages, and an Apparatus submenu (the 5 `CollectionGeneratedBlockType`s). A user who wants a section heading has no visible reason to open a plus menu; a user who opens it expecting to add a document is surprised. This is the single biggest "power exists but is invisible" failure: **the entire Phase 4/6 structural + apparatus surface hides behind one ambiguous glyph.** iOS has the identical shortfall — `CollectionEditorView.swift:1017-1050` folds Add Documents *and* the structural menu into one glyph-only `plus`.

### F2 — Sibling list actions live in three registers, split across two chrome zones (owner point 1). **Severity: high.**
The three list-level authoring verbs are rendered three different ways and placed in two different regions:
- **Sort by Date** — text+glyph `Label`, in the section header (`:703`).
- **Add-structural "+"** — glyph-only, in the section header (`:717`).
- **Add Documents…** — text+glyph `Label`, but on the *titlebar toolbar* (`:1096`), a completely different zone.

So the real "toolbar" for authoring is scattered: the titlebar carries Add Documents / Preview / Export (`toolbarContent` :1096-1138), while Sort and Add-structural are exiled into a caption-sized header row. There is no single place a user looks to find "the things I can do to this collection." The app *already has the answer shape* — `ResearchStripView` (`SupportingViews.swift:108`, hosted `MainWindowView.swift:85`): a labeled glyph+text ribbon, `.background(.bar)` + bottom `Divider()`, uppercased group label, horizontal-scroll degradation, and contextual buttons that appear/disable on state. The manager has no equivalent; it should.

### F3 — "Documents" mislabels the region (owner point 2). **Severity: medium-high.**
`MacCollectionManagerView.swift:695` / `CollectionEditorView.swift:1017` — the section is captioned "Documents," but per the row-type map (`CollectionEntryRows.swift`: `CollectionHeadingRow` :50, `CollectionProseRow` :386, `CollectionExcerptRow` :428, `CollectionGeneratedEntryRow` :504) it holds documents **plus** headings, prose, excerpts, and apparatus — and via disclosure sections, Composition and Front Matter too. The label actively *teaches the wrong model*: it tells the user this is a document list, so they never look here for structure. The mislabel and F1 compound — the region says "documents" and the only add-affordance is a "+" that reads "add document," so the structural/apparatus features are doubly hidden.

### F4 — Entry rows are control panels masquerading as reports (owner point 4). **Severity: medium-high.**
`MacEntryRow` (`:1284`) and `EntryRow` (`CollectionEntryRows.swift:593`) interleave **editing controls** into what should be a scannable list:
- a body-depth `Picker` sits *inside the reporting column* (`MacEntryRow:1353`, `EntryRow:679`),
- note selection is a `noteMenu` dropdown on macOS (`:1454`) but an inline per-note `Toggle` list on iOS (`:690-733`) — **the two platforms diverge in mental model**,
- plus ⓘ, external-open, and trash icon buttons (`:1393`).
Every row is dense, every row edits, and the depth/notes controls it exposes are *also* editable in the inspector (`CollectionEntryInspector`, the B8 column) — so the row **duplicates** inspector functionality inline while making the list un-scannable. A user cannot glance down the list and read "what's in this collection" because each row is shouting five controls.

### F5 — The inspector exists but is not the obvious home for editing (owner point 4, structural). **Severity: medium.**
The B8 inspector (`CollectionEntryInspector.swift`, macOS `.inspector` column at `MacCollectionManagerView.swift:540`) already owns *most* per-entry editing — all the Phase-5 overrides (`overridesSection` :392), headnote (`:489`), per-highlight include toggles (`:243-259`). But it does **not** own the two controls still stranded in the row (body depth, note selection), and its notes list is **read-only** (`:217-228`, `ForEach(noteTexts)` with no toggles) while highlights right below it have per-item checkboxes. So the inspector is *almost* the single edit surface but has two conspicuous gaps, and because the row still carries those same controls, there's no signal that the inspector is *the* place to edit. On iOS/iPad the inspector is only a `.sheet` off the row (`EntryRow:737`), never a column — so it feels secondary.

### F6 — No per-entry title control exists at all (owner point 5). **Severity: medium (a gap, not a confusion).**
There is no title/ToC/heading override anywhere. The exported title is hard-derived (`CollectionContentResolver.swift:1107`, `"\(volumeTitle) — \(ref.documentId)"`); the ToC label comes from `tocLabel(style:)` (`CollectionExporter.swift:450`); the printed document heading is *always the citation* (`CollectionItemHTMLRenderer.swift:237`, PDF :589, DOCX :517). A user assembling "a small edited documentary volume" (the §0 target artifact) cannot rename a document in their own table of contents. This is a genuine unbuilt feature surfacing as a discoverability question only because point 5 asks *where* the control should live.

### F7 — The notes default is an inverted, undocumented trap (owner point 6). **Severity: medium.**
For a static entry the export default when the user never touched notes is: `selectedNoteIds` empty ∧ `researchNoteId` nil ⇒ **no notes exported** (`CollectionContentResolver.swift:995-996`). This is the **opposite** of the highlights convention, where empty = *all* (`Collection.swift:490`). A user who set collection `includeNotes = true` reasonably expects "my notes appear" and gets nothing until they discover the row control — and the control that *would* fix it is the divergent row menu/checkbox-list from F4. Two separate flags (`selectedNoteIds` = *which*, `includeNotesOverride`/`includeNotes` = *whether*) live in different places with no cross-reference, so a user can check notes and still see nothing.

**Through-line.** F1–F3 are *discoverability* failures (power exists, users can't find it); F4–F5 are *comprehension* failures (the row/inspector split doesn't tell users where to edit); F6–F7 are *capability/semantics* gaps. The fixes rhyme: **one labeled ribbon** for list actions, **one honest region label**, **the inspector as the single per-entry edit surface**, **the row as pure report**. Every per-entry fix routes through the shared `CollectionEntryInspector`, which is the highest-leverage surface in the whole manager because it is already cross-platform and already macOS-column-aware (`isInspectorColumn`).

---

## 2. The proposal — per owner point

### Point 1 & 3 — A labeled Collections ribbon, mirroring `ResearchStripView`

**Design.** Introduce `CollectionRibbonView` as the **second row of `CollectionDetailPane.editorColumn`** (between the fixed header at `:600` and `documentsSection` at :690), copying the strip chrome verbatim: `HStack` → horizontal `ScrollView` of glyph+text buttons + a trailing pinned control, `.frame(minHeight:32)`, `.background(.bar)`, `.overlay(alignment:.bottom){ Divider() }`. Reuse (or extract-and-share) `ResearchStripButton` (`SupportingViews.swift:833`) so **every** control is a labeled button — killing F1's context-less glyph and F2's three-register split in one move. Because the pane is per-collection (`.id(c.id)`), the ribbon binds directly to the pane's `@State`/methods; no focused-value round-trip.

**Groups** (each led by an uppercased `.system(size:10)`/`.tertiary` label, the strip's "RESEARCH" pattern at `:248`; thin `Divider().frame(height:20)` between clusters as the main window toolbar does):
1. **CONTENT** — Add Documents… (`plus.rectangle.on.folder`), Add Section Heading (`number`), Add Note Block (`text.alignleft`), Add Passages… (`text.quote`, disabled when no documents), Apparatus ▾ (`list.bullet.rectangle`, a `Menu` of the 5 block types). Absorbs the section-header "+" *and* pulls Add Documents off the titlebar into a labeled home.
2. **ARRANGE** — Sort by Date (`arrow.up.arrow.down`, disabled when empty). Lifts the header control, text+glyph intact.
3. **VIEW** — Composition (`slider.horizontal.3`, toggles `showComposition`), Front Matter (`text.book.closed`, toggles `showFrontMatter`), Preview (`eye`/`eye.fill`). Composition/Front Matter are today buried as in-list disclosures (`:775`/`:788`); a ribbon toggle makes them discoverable.
4. **SHARE** (pinned trailing, outside the scroll region, mirroring the strip's Read/Research picker) — Export… (`square.and.arrow.up`, disabled per `canExport`).

**Command-menu lockstep.** Extend `CollectionDetailCommandActions` (`FRUSExplorerApp.swift:1758`, published from `detailCommands` :569) with `sortByDate`, `addHighlights`, `addApparatus(CollectionGeneratedBlockType)`, and the two VIEW toggles, so the `Collection` menu and the ribbon surface **one** action set. The menu currently publishes only addDocuments/addHeading/addProse/togglePreview/exportCollection — bring it up to the ribbon.

**After the ribbon lands,** the `documentsSection` header row (`:694-761`) reduces to just its (renamed) label; the titlebar toolbar can empty out or keep Export as a redundant, familiar titlebar affordance.

> **DECISION POINT D2 — ribbon scope/placement.**
> **(A / cheaper) Faithful `ResearchStripView` clone:** always-full-height `.bar` strip, horizontal `ScrollView` for CONTENT/ARRANGE/VIEW, Export pinned trailing, **no collapse**. This matches the live precedent exactly — the strip's own collapse was *removed* in v1.1 (`MainWindowView.swift:84`), so "no collapse" is the honest house pattern. Least code, maximal consistency, and horizontal-scroll degradation means labels never truncate.
> **(B / more) Collapsible second row:** add an `@AppStorage("frus.collections.ribbon.expanded")` chevron that hides the button rows and keeps only Export. More chrome, a persisted UI-state key, and it diverges from the current (non-collapsing) strip.
> **Lean: A.** Mirror the strip — no collapse — unless the owner specifically wants vertical space back on small macOS windows. The horizontal `ScrollView` already handles narrow widths without a collapse.
>
> **iPad form (part of D2).** iPad has a real toolbar already (eye/inspector toggles, `CollectionEditorView.swift:654-676`) but the structural controls are in the Documents header (`:1017-1050`) — same shortfall. **Do not build a custom strip on iPad; promote those verbs into the native toolbar** as labeled `ToolbarItem`s (`Label(text, systemImage:)`). iPad inherits the labeled-ribbon benefit through its toolbar; only macOS gets the literal `.bar` strip. **iPhone** has no persistent toolbar room: keep the Outline\|Preview segmented control (`:538-560`) and put Add/Sort/Apparatus into a labeled `primaryAction` menu in the nav bar (`Label`s, not bare glyphs), or a compact labeled button row under the segmented control. The parity win everywhere is **text+glyph labels**, not a desktop strip.

### Point 2 — Rename "Documents" to a generic region label

**Design.** Rename both platform keys in one change: `collection.section.documents` (`MacCollectionManagerView.swift:695`) and `collection.editor.docs.header` (`CollectionEditorView.swift:1017`). Genericize the iPhone empty-state string in tandem (`CollectionEditorView.swift:994` "No documents yet…" → "No content yet…").

> **DECISION POINT D1 — the label wording.**
> **(A) "Contents"** — plainest reader-facing term for "everything in this collection"; matches the outline-of-a-publication model; does **not** overload the existing "Body depth" vocabulary.
> **(B) "Body" / "Body Contents"** — most precise (this is the exportable body between front and back matter) and maps to the codebase's `CollectionBodyDepth` / front-matter terms — but "Body" reads oddly as a section header and risks colliding with the "Body depth" control label in the same view.
> **(C) "Outline"** — foregrounds the nested/reorderable structure (matches `CollectionOutline`, the collapse chevrons); slightly implies "structure only," undersells the documents.
> **Lean: A ("Contents").** Plain, correct, non-colliding. "Outline" is the strong second if the owner wants to advertise the nesting.

### Point 4 — Row → reporting surface; inspector → single edit surface

**Design.** Split editing out of the row and into the inspector, so tapping a row's ⓘ becomes the **one** path to edit an entry.

**Row AFTER (both platforms, reporting only):**
- **Keep:** `documentLabel`/header, volume title, date, duplicate "Also in collection" badge.
- **Add read-only status chips** (projections of inspector state, so the row still *communicates* config at a glance): body depth when non-Default ("Summary only" / "Citation only"), note count ("2 notes"), override state ("Highlights off"), "Headnote", "See also".
- **Keep navigational:** ⓘ inspector button (primary affordance — macOS toggles the `.inspector` column, iOS opens the sheet), Open-external, `.entryMoveControls` a11y actions.
- **Move OUT to the inspector:** body-depth `Picker` (both platforms), the macOS `noteMenu` / iOS inline per-note toggle list. This **also erases the F4 platform divergence** — both platforms edit notes in the one shared inspector.

**Inspector AFTER** (`CollectionEntryInspector.swift`): add the two missing controls next to the overrides it already owns —
1. **Body depth `Picker`** at the top of `overridesSection` (:392) — it is the parent gate the other overrides refine (highlights only apply at `.full`, resolver :1028). Move `bodyDepthOverride` + `entryDepthOptions` verbatim from the row.
2. **Editable research-note selection** replacing the read-only `ForEach(noteTexts)` (:217-228) — see Point 6.

> **DECISION POINT D3 — does the row keep any quick-actions, or become pure reporting?**
> **(A / pure reporting) Row shows identity + status chips + ⓘ + external-open + move only; everything editable is inspector-only.** Cleanest, most scannable, fully collapses the platform divergence. Delete = keep the row `trash` (macOS `List` has no swipe) / iOS swipe; delete is *structural*, not per-document editing, so it legitimately stays on the row.
> **(B / row keeps quick-actions) Row keeps the body-depth picker and/or a compact note toggle inline for one-click common edits, and the inspector is the "full" surface.** More convenient for power users, but re-introduces the duplication F4 flags and keeps the macOS-menu/iOS-list divergence alive.
> **Lean: A (pure reporting), with delete + external-open + ⓘ + move as the only row affordances.** The whole point of point 4 is to make the list scannable and route editing to the one inspector; a "quick" inline picker undoes that and forces you to maintain two note surfaces forever. Optionally add a "Remove from collection" action *inside* the inspector too, for parity.

### Point 5 — Per-entry title override

**Design.** Add one model field and thread it through the resolver → payload → ToC + heading, with the inspector control showing the derived default as placeholder.

- **Model** (`Collection.swift`, alongside the Phase-5 override block ~:509): `var titleOverride: String? { didSet { lastModified = .now } }` — additive optional scalar, CloudKit-safe (absent = derived default), same pattern as `bodyDepthOverride`. Document-entries only.
- **Resolver** (`CollectionContentResolver.swift`): `EntryRef` (:622) gains `titleOverride` (from `entry.titleOverride` in `init(_ entry:)` :669, `nil` in the smart `init(_ ref:)` :696); `resolveEntry` (:955) computes `resolvedTitle = ref.titleOverride?.nonEmpty` and passes it on the payload.
- **Payload** (`CollectionExporter.swift`): `CollectionExportDocument` (:370) gains `titleOverride` (defaulted `nil` so all constructions stay byte-identical); add one computed `exportHeading = titleOverride?.nonEmpty ?? (citation.isEmpty ? title : citation)`.
- **ToC** (`tocLabel(style:)` :450): `if let t = titleOverride, !t.isEmpty { return t }` first — override wins for *both* styles.
- **Heading**: the three `doc.citation.isEmpty ? doc.title : doc.citation` sites (HTML :237, PDF :589, DOCX :517) → `doc.exportHeading`, centralizing so the three exporters stay in lockstep.
- **Serialization** (`NativeCollectionFormat.swift`): `Entry` (:153) gains optional `titleOverride` (absent for untouched entries → write-minimum byte-identical → **no v2 reader-floor bump**; a v1 reader ignoring it degrades to the derived title, never corrupts). It **is** portable content (plain text, no device-local UUIDs), so unlike `selectedHighlightIds` it travels with the file. Import (:585) reads it in the `.document` block.
- **Inspector control** (`identitySection` :193): a `TextField` bound to `entry.titleOverride` with the **derived default as placeholder** (`header.nonEmpty ?? citation ?? "{volumeTitle} — {documentId}"`), empty string clears to `nil`. Caption: "Overrides the document's title in the table of contents and the export heading. Leave blank to use the derived title." **Document-only** — the heading variant (`headingIdentitySection` :206) does not get it; a section already edits its own title inline via `CollectionHeadingRow` (`CollectionEntryRows.swift:144`).

> **DECISION POINT D4 — one shared override, or two separable (ToC vs document heading)?**
> **(A / cheaper) ONE `titleOverride`** used for both the ToC label and the top-of-document export heading. Matches the user's mental model ("what do we call this document here"), one inspector field, one resolver-computed `resolvedTitle`.
> **(B / more) TWO fields** — `tocTitleOverride` + `headingTitleOverride` — because the `.headerAndDateline` ToC style deliberately differs from the citation heading today. Two model fields, two serialization keys, two inspector fields, and it exposes an edge case (ToC says X, page says Y) most users will find confusing.
> **Lean: A (one field), with a designed escape hatch.** Name the field/key generically (`titleOverride`), thread through the single `exportHeading`/`resolvedTitle` computed property; a later `tocLabelOverride` is then a **pure additive** field, not a migration. The `.headerAndDateline` vs citation distinction is a *style* choice already exposed at collection level; a per-entry *content* override should win uniformly. Document the shared decision so a future split is additive.

### Point 6 — Multiple notes: zero / one / more, mirroring highlights

**Current trap (F7).** Static entry, untouched notes → **zero** notes exported (`CollectionContentResolver.swift:995-996`). Highlights do the opposite (empty = all, `Collection.swift:490`). The control is the divergent row menu (macOS `:1454`) / inline checkbox list (iOS `:690-733`); the inspector's note list is read-only (`:217-228`).

**Design (parallel to the A8 highlights precedent):**
1. **Redefine `selectedNoteIds` semantics to "empty = all,"** matching `selectedHighlightIds`. Move the control **into the inspector's annotations section**, replacing the read-only `ForEach(noteTexts)` (:224-228) with per-note include toggles identical in shape to the highlight rows (:243-259): a `.checkbox`(macOS)/`.switch`(iOS) toggle + note-preview text.
2. **Canonical logic** mirrors `setHighlightIncluded` (:429-445) exactly:
   - `noteIncluded(id) = selectedNoteIds.isEmpty || selectedNoteIds.contains(id)`.
   - check-all collapses back to `[]` (future notes auto-flow in); **uncheck-last** sets `selectedNoteIds = []` **and** `includeNotesOverride = false` (because empty can't mean "none," "none" is the override-off flag).
   - "New Note…" affordance threaded from the macOS `noteMenu`'s existing `onNewNote` (:1298).
3. **Two orthogonal controls, now co-located:** `includeNotes`/`includeNotesOverride` stays the **whether** gate (unchanged in renderers, `includeNotesOverride ?? options.includeNotes`); `selectedNoteIds` is the **which** filter, applied only when the gate is on — and both sit in the same inspector panel (gate = the "Research notes: Default/On/Off" picker at :355, filter = the checkboxes right above), so the relationship is visible at last.
4. **Resolver change:** in `.entrySelection`, when `selectedNoteIds.isEmpty` and no legacy link, resolve to **all document notes** (the same doc-match filter `.allDocumentNotes` uses at :998-1004) instead of `[]`. The legacy-`researchNoteId` branch (:991-994) is preserved for un-migrated entries.
5. **Serialization:** mirror highlights — **do not** serialize `selectedNoteIds` into `.fruscollection` (a recipient lacks the referenced notes; falls back to all-their-notes/none per gate). Confirm `NativeCollectionFormat.swift` excludes it as it does `selectedHighlightIds`.

> **DECISION POINT D5 — empty-selection default semantics + control placement.**
> **(A / recommended) Empty = ALL** (mirror highlights). New default: notes appear when the gate is on. Uniform with the smart path and with user expectation. **The sharp edge:** flipping empty from "none" to "all" changes the export of *every* existing static entry that never touched notes — they silently gain notes. Preferred handling: treat the *display* default as all-checked and only ever *write* `selectedNoteIds` on the first uncheck (exactly how `setHighlightIncluded` never writes until interaction) — no data-model sweep, but it **is** an intentional export-default change to flag to the owner.
> **(B / conservative) Keep empty = NONE for legacy, seed all-note-ids at entry creation going forward.** No silent change to existing collections, but you get two cohorts with different defaults and the highlights-mirroring breaks (empty means opposite things for notes vs highlights forever).
> **(C / legacy-single) Keep the `researchNoteId` single-note fallback prominent.** Rejected — it's the pre-multi-note model; every write path already migrates legacy→array on first edit (`EntryRow:709-712`, `MacEntryRow:1518-1530`).
> **Lean: A (empty = all), control in the inspector annotations section as highlight-style checkboxes.** It is the only option that truly mirrors highlights, co-locates which/whether, and erases the macOS-menu/iOS-list divergence — but the owner must explicitly accept the one-time export-default change (existing untouched-note entries gain their notes on next export). Flag it in release notes.

---

## 3. Cross-platform manifestation

| Change | macOS | iPad | iPhone |
|---|---|---|---|
| **Ribbon (pts 1,3)** | New `CollectionRibbonView` `.bar` strip, 2nd row of `editorColumn`; `ResearchStripButton` reused; groups CONTENT/ARRANGE/VIEW + pinned Export. | **No custom strip.** Promote Sort/Add-structural/Apparatus from the Documents header into the native **toolbar** as labeled `ToolbarItem`s; existing eye/inspector toggles stay. | Add/Sort/Apparatus into a labeled `primaryAction` nav-bar menu (or compact labeled row under the Outline\|Preview segmented control). Keep the segmented control. |
| **Rename "Documents" (pt 2)** | `collection.section.documents` default → "Contents". | Same key (`collection.editor.docs.header`) — inherits. | Same, **plus** genericize empty-state (`:994` "No content yet…"). |
| **Row → report / inspector edits (pt 4)** | Row sheds body-depth picker + `noteMenu`; keeps ⓘ (toggles `.inspector` column), external-open, trash, move; gains status chips. | `EntryRow` shared with iPhone: sheds body-depth picker + inline note list. **Promote the per-entry inspector from `.sheet` to a system `.inspector`** (iPad already runs one for metadata `:638-648` — reuse the pattern) to match the macOS B8 column. | Row sheds controls into the **`.sheet`** inspector (`EntryRow:737`; ⓘ already present :648-655). Row becomes identity + "N notes · M highlights" chips. |
| **Title override (pt 5)** | `TextField` in inspector `identitySection`. | Shared inspector → inherits (in the promoted `.inspector` or sheet). | Shared inspector → inherits (sheet). |
| **Notes zero/one/more (pt 6)** | Delete `noteMenu`; add highlight-style checkboxes in inspector annotations. | Delete inline note checkbox list; **same shared inspector control** → inherits (divergence erased). | Same shared inspector control (sheet) → inherits. Row shows read-only "N notes" count. |

**Parity through-line:** every per-entry change (pts 4, 5, 6) is delivered by the **shared `CollectionEntryInspector`**, which is already cross-platform and macOS-column-aware (`isInspectorColumn`). iPad's one structural lift is promoting its `.inspector` usage from metadata-only to also hosting the per-entry inspector (matching macOS B8); iPhone keeps the sheet but still empties its rows into it. The list-level changes (pts 1, 2, 3) are a macOS strip + iPad toolbar promotion + iPhone menu — same labels, three chromes.

---

## 4. Phasing

Cheap / high-discoverability-ROI first (no schema, no format touch), then the model-and-inspector work. Each phase 1–2 PRs. Standing gates from `Collections-Authoring-Scope.md` apply to every PR: `String(localized:)`, doc comments, Apache headers, `Version history` bumps, `CodingStandardsAuditTests` green, **dual-manager parity per item**, byte-identical-fixture regression, docs rider.

### Phase M1 — Label + parallel controls + ribbon *(1–2 PRs; zero schema/format change)*
The entire discoverability transformation, no data risk.
1. **Rename "Documents" → "Contents"** (D1) — both keys + iPhone empty-state. One-line-ish, highest comprehension-per-effort.
2. **`CollectionRibbonView`** (D2, lean A) — extract/share `ResearchStripButton`, host as `editorColumn` 2nd row, CONTENT/ARRANGE/VIEW + pinned Export; absorb the section-header "+" and Sort; pull Add Documents off the titlebar.
3. **Command-menu lockstep** — extend `CollectionDetailCommandActions` with `sortByDate`/`addHighlights`/`addApparatus`/view toggles.
4. **iPad toolbar promotion + iPhone labeled menu** — same verbs, native chrome.
*Reused:* `ResearchStripView`/`ResearchStripButton`, existing menu/toolbar seams. *Built:* the ribbon view, the toolbar/menu promotions. *Risk:* purely cosmetic/interaction; no sync or file risk. This is the phase to ship first and fast.

### Phase M2 — Row → report + inspector absorbs body-depth & notes *(1–2 PRs; zero schema/format change for depth; notes needs the D5 decision)*
5. **Row becomes reporting** (D3, lean A) — strip body-depth picker + note menu/list from both rows; add status chips; keep ⓘ/external/trash/move.
6. **Inspector absorbs body depth** — move `bodyDepthOverride` into `overridesSection`.
7. **Inspector notes selection** (D5, lean A) — highlight-style checkboxes replace read-only note list; redefine empty = all; resolver empty-branch → all-doc-notes; write-on-first-uncheck. **Flag the one-time export-default change in release notes.**
8. **iPad: promote per-entry inspector `.sheet` → `.inspector`** to match macOS B8.
*Reused:* `CollectionEntryInspector` shell, `setHighlightIncluded` canonical logic as the notes template, iPad's existing `.inspector` pattern. *Built:* status chips, inspector note checkboxes, resolver empty-branch change. *Risk:* the notes empty=all flip is a **behavior change to existing collections** — the write-on-first-interaction approach avoids a data sweep, but it is the one place this program alters existing exports; gate it behind an explicit owner OK on D5 and a release note. `selectedNoteIds` stays out of `.fruscollection` (like `selectedHighlightIds`), so **no format touch.**

### Phase M3 — Title override *(1–2 PRs; additive field, rides `.fruscollection` v2)*
9. **`titleOverride`** (D4, lean A) — model field, resolver `EntryRef`/`resolveEntry` threading, `CollectionExportDocument.exportHeading`, three exporter heading sites → `exportHeading`, `tocLabel` override branch, inspector `TextField` with derived-default placeholder.
10. **Serialization** — optional `Entry.titleOverride` key in `NativeCollectionFormat`; **write-minimum keeps files byte-identical** for untouched entries and **needs no reader-floor bump** (a v1 reader degrades to the derived title). It is portable content, so it travels with the file (unlike `selectedHighlightIds`/`selectedNoteIds`).
*Reused:* the additive-optional-scalar pattern (`bodyDepthOverride`), `tocLabel`, the three exporters. *Built:* the field + resolver/payload/exporter threading + one inspector field. *Constraints:* additive CloudKit field (absent = default, no schema break); rides the existing v2 optional-key / tolerant-reader rule from the authoring program — **no new format version.**

**Sequencing rationale.** M1 is the pure discoverability win — no schema, no format, all upside, ship it first. M2 makes the row scannable and the inspector authoritative, and carries the only behavior change (notes default) that needs an owner sign-off and a release note. M3 adds the one genuinely new capability (title override) as a clean additive field on the already-bumped v2 format. Every phase leaves existing collections and existing `.fruscollection` files working unmodified; the one exception (M2 notes default) is intentional, flagged, and requires no data migration.

**CloudKit / v2 / dual-manager constraints honored:** M1/M2 add no fields and (M2) serialize nothing new — no format touch. M3's `titleOverride` is additive-optional (CloudKit-safe, absent = derived) and rides the existing v2 optional-key rule (no new `minimumReaderVersion`). Every work item is verified across `CollectionEditorView` + `MacCollectionManagerView` (build shared inspector logic, style per-platform), and the notes/row changes specifically *collapse* the current macOS-menu / iOS-list divergence rather than deepening it.

**Status:** scoped 2026-07-04; no implementation started. Sits atop the Collections-Authoring program (Phases 1–6) and assumes its inspector (B8), resolver, and `.fruscollection` v2 are in place.
