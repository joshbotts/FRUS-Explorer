# Volume updates and annotation integrity — a design

**Status:** design, written 2026-09-02 against the tree at `b142381`. Answers the question left
open at `New-Volume-Release-Plan.md` §13: when the Office of the Historian corrects a published
volume, can the app tell the reader *which of their annotations* are in doubt?

**The question, restated as the owner put it.** Users should be notified when an OH update could
invalidate their annotations. Can the app detect the *specific documents* that were modified? If
so, confine the notification to those. If not, notify at volume level. Either way, identify the
potentially affected annotations so the user can confirm, modify, or delete them.

---

## 1. The answer

**Yes — document-level detection is achievable, and it is cheap.** The app does not need to keep
the old XML, does not need to diff two files, and does not need a new parse. The re-index of an
updated volume already parses the new TEI into per-document rows and **upserts** them over the old
ones (`IndexingPipeline.documentCacheUpsertSQL`, `:5995`), preserving each row's identity and its
user columns. At that instant both versions of every document are in hand: the old row in
`document_cache` and the new `DocumentCacheRow` about to overwrite it. Comparing them yields an
exact changed-document set.

**Three things stand between that and a shipped feature**, and none is large:

1. **Nothing captures the comparison.** The upsert overwrites unconditionally; a moment later the
   old text is gone. The change set has to be recorded *during* the store pass or not at all.
2. **The one per-document hash the app already has is the wrong hash for this job** — it is blind
   to footnotes, and footnote corrections are a large share of what OH actually changes. §3.
3. **Only two annotation types carry a version at all**, and one of those never reads it. §5.

So: volume-level notification is the fallback this design does **not** need to fall back to.

---

## 2. What the app can see today

Four mechanisms exist. None of them, alone or together, answers the owner's question.

**A volume-level change signal, already shipped.** `VolumeUpdateChecker.hasUpdate(local:live:)`
compares the local file's git blob SHA-1 against the live listing's, and
`updatableVolumes(known:liveInfoByVolumeId:downloadManager:)` surfaces the result in both storage
hubs behind a "Check for Updates" action. This tells the reader *that* a volume changed. It says
nothing about what, or where, and it is opt-in: nothing runs it unless the user opens the hub.

**A per-document version, computed only at render time.**
`ASTToRenderNodeConverter.renderingVersion(for:)` is
`SHA-256(flatText(model.bodyNodes) ++ kVersion)` truncated to 16 hex characters — genuinely
per-document, and genuinely a content hash. It is stored on `DocumentHighlight.renderingVersion`
and on `CollectionEntry.excerptRenderingVersion`. It is **never persisted per document**: it is
recomputed each time a document is opened, compared against that document's stored highlights, and
thrown away.

**A staleness signal, reactive and narrow.** `DocumentView` recomputes the version on render and,
if any stored highlight disagrees, shows `staleHighlightBanner` — *"Some highlights may be
misaligned — the document has been updated since they were created."* — while
`HighlightDTO.isStale` paints those ranges amber through `::highlight(frus-stale)`. This is a good
mechanism and this design keeps it. Its limit is that it fires **only when the reader happens to
open that document**. A researcher with 400 highlights across 60 volumes learns nothing until they
revisit each one.

**The old text itself, until the upsert.** `document_cache` holds `header`, `dateline`,
`source_note` and `body_text` per `(volume_id, document_id)`. On an update the corpus columns are
overwritten in place; the user columns (`user_tag_ids`, `summary_text`, `note_text`) are
deliberately left alone. `auxDeleteVanishedCacheRows` (`:6075`) removes rows for documents the new
TEI no longer contains — its own comment notes that "upstream revisions occasionally renumber or
drop documents".

---

## 3. The two hashes measure different things, and the difference matters

This is the finding that shapes the design.

| | `renderingVersion` | `document_cache` columns |
|---|---|---|
| Source | `flatText(model.bodyNodes)` | `extractBodyText` = `FRUSASTNode.plainText`, plus `header` / `dateline` / `source_note` |
| Footnote **bodies** | **excluded** — `flatText` has `case .pageBreak, .footnoteMarker, .figureBlock, .footnoteBody: break` (`ASTToRenderNodeConverter.swift:144`) | **included** — `case .footnote(_, _, _, let c): return c.map(\.plainText)…` (`IndexingPipeline.swift:10192`) |
| Source note | excluded from the body-node space | its own column |
| Whitespace | preserved as rendered | `normalizedWhitespace` |
| Answers | *"do the highlight offsets still align?"* | *"did this document change at all?"* |

Both are correct for their own question, and the exclusion in `flatText` is deliberate and right:
footnote bodies are not in the highlight coordinate space, so including them would move the hash
for a change that cannot move a single offset. The version history at
`ASTToRenderNodeConverter.swift:48–62` records two occasions where `kVersion` was deliberately
**not** bumped for exactly that reason — a reflexive bump "would mark every highlight in every
indexed volume stale for a change that moved no characters."

But it means **a detector built on `renderingVersion` alone is blind to footnote and source-note
corrections** — and in FRUS those are not an edge case. A corrected citation, a revised source
note, an added cross-reference in a footnote: these are among the commonest things an OH erratum
touches, they are exactly what a researcher's note may have been *about*, and the body hash does
not move for any of them.

**So the design stores both.** One says *this document changed*; the other says *and your offsets
moved*. Reporting only the first would over-warn; only the second would under-warn about the
changes most likely to matter to a citation.

---

## 4. The change classes

| Class | Detectable? | What it costs the reader |
|---|---|---|
| **Body text changed** | yes — both hashes move | Highlight offsets may be misaligned; a quoted excerpt may no longer be verbatim |
| **Footnote / source note / header changed** | yes — `document_cache` moves, `renderingVersion` does not | Offsets are fine. A note, a citation, or a summary written about that apparatus may now be wrong |
| **Document vanished or renumbered** | yes — `auxDeleteVanishedCacheRows` already knows exactly which ids went | Every annotation on it is orphaned: the id resolves to nothing |
| **Document added** | yes, trivially | Nothing to warn about |
| **Whitespace-only / re-serialisation** | **deliberately not flagged** — `body_text` is whitespace-normalised, and `kVersion` is not bumped for changes that move no characters | Nothing. This is the false-positive class the design must not produce |

That last row is a feature. A researcher who is warned about a document where nothing they can see
has changed learns to dismiss the warning, and the next one.

---

## 5. The design

### 5.1 Capture the change set at re-index time

A new device-local table, written inside the existing store transaction:

```sql
CREATE TABLE IF NOT EXISTS document_revisions (
    volume_id     TEXT NOT NULL,
    document_id   TEXT NOT NULL,
    content_hash  TEXT NOT NULL,   -- over header + dateline + source_note + body_text
    body_hash     TEXT NOT NULL,   -- the renderingVersion coordinate space
    changed_at    TEXT,            -- ISO-8601, set only when a hash actually moved
    change_kind   TEXT,            -- 'body' | 'apparatus' | 'vanished'
    reviewed_at   TEXT,            -- NULL until the reader dispositions it
    PRIMARY KEY (volume_id, document_id)
)
```

The store pass reads the prior row, compares, writes the new hashes, and stamps `changed_at` and
`change_kind` when either hash moved. First index of a volume writes hashes with a null
`changed_at` — a document cannot have changed before the reader had it.

**Two details that are not optional.**

- **`body_hash` must be computed in the render-node space, not the AST space**, or it will not
  agree with the `renderingVersion` that highlights carry, and the "your offsets moved" claim will
  be wrong in both directions. The indexer builds the AST but not the render model, so this needs
  the AST→render conversion at index time for each document. **Cost is unmeasured and must be
  measured before committing** — indexing is already the app's heaviest operation and this design
  will not hand it an unpriced regression. If it proves expensive, the fallback is to store only
  `content_hash` and compute `body_hash` lazily on first open, which degrades the offsets claim to
  the existing render-time check without losing the *which documents changed* answer.
- **`auxDeleteVanishedCacheRows` must stop being silent.** It already computes exactly the
  vanished set; today it deletes and says nothing. It should write a `'vanished'` revision row
  before deleting. This is the smallest change in the design and it covers the worst case — an
  annotation whose anchor no longer exists at all.

### 5.2 Device-local, not CloudKit — and why that is the right answer anyway

> **SUPERSEDED IN PART, 2026-09-03 (R-5 P3b-2, PR pending).** The owner answered Q-3: review state
> syncs. This section's reasoning about the *table* still stands — `document_revisions` remains
> device-local derived data in `frus.db`, because "this device re-downloaded and re-indexed this
> volume" is a device-local fact. What changed is the *disposition*: a reader's review now also
> writes an `AnnotationReview` row, a mirrored `@Model`, and a reconcile pass stamps the local
> column wherever a synced row's `content_hash` still matches. So the cost this section states
> plainly — "dispositioning an annotation on the iPad does not clear the flag on the Mac" — is no
> longer paid, and the escape it names (a mirrored field on each annotation) was weighed against
> one ledger record type and lost on promotion cost. Read the rest of this section as the argument
> that was made, not as current behaviour.

The revision table is derived data in `frus.db`, not a `@Model`. That is deliberate:

- Adding a stored property to a mirrored `@Model` engages the #488 Production-deploy gate
  (`CloudKitSchemaInventoryTests` fails the moment the mirrored set changes, and the deploy is an
  owner step outside the repo). A staleness-review feature should not be gated on a schema deploy.
- More to the point, **the fact being recorded is device-local by nature**: "this device
  re-downloaded and re-indexed this volume, and these documents changed in the process". Another
  device that has not updated the volume has not experienced the change yet.
- The pleasant consequence: each device detects the same change set independently when it updates,
  because the comparison is against that device's own previous copy. The annotations themselves
  are CloudKit-synced and identical everywhere; the *review state* is per device.
- The cost, stated plainly: dispositioning an annotation on the iPad does not clear the flag on
  the Mac. If that proves annoying, the escape is a small mirrored `reviewedRevision` string on
  the annotation itself — which is a schema change, and therefore a later, deliberate decision.

### 5.3 What "affected" means, per annotation type

Every one of these anchors on `(volumeId, documentId)`.

| Type | Anchor strength | Affected by | Can the app help? |
|---|---|---|---|
| `DocumentHighlight` | **offsets** + `selectedText` + `renderingVersion` | body change; vanished | **Yes, most of all** — see 5.4 |
| `CollectionEntry` (excerpt) | frozen `text` + optional offsets + `excerptRenderingVersion` (**stored, never read**) | body change; vanished | Yes — the stored version finally gets a reader |
| `ResearchNote` | document grain, free prose | any change; vanished | Show it beside the diff; the researcher decides |
| `GeneratedSummary` | document grain, **derived from the text** | any change; vanished | Flag as describing a superseded text; offer re-generation |
| `DocumentTagAssignment` | document grain | vanished only | A tag survives a text change |
| `DocumentClassificationOverride` | document grain, overrides parsed `isEditorialNote` | vanished; a change that flips the parse | Re-check the parse against the override |
| `ArchiveVisitDocument` | `documentKey` + `includeSource` | vanished; source-note change | The source note is what a visit plan is built on |
| `ProjectLeadEntry`, `ProjectEngagedDocuments`, `ReadingHistoryEntry` | document grain | vanished only | Repair or drop the reference |

`CollectionEntry.excerptRenderingVersion` is worth calling out: its own doc comment says it is
"stored, never read at render time", captured against a future decision. That decision is this
one — the field is already in CloudKit, already populated, and needs no schema change to start
being useful.

### 5.4 What the app can offer, per annotation

Three actions, matching the owner's three: **confirm**, **modify**, **delete**.

- **Confirm** — stamp the annotation as reviewed against the new revision and stop warning. For a
  highlight this means rewriting `renderingVersion` to the current value; for everything else it
  is a row in the revision table.
- **Modify — and for highlights the app can do most of the work.** `DocumentHighlight` stores
  `selectedText`, the verbatim passage the reader selected. When the new flat text contains that
  string **exactly once**, the offsets can be re-derived with certainty and offered as a one-tap
  repair. When it appears zero times, the passage was edited or removed and only the reader can
  decide. When it appears more than once, the app must not guess. Caveat, from the model's own doc
  comment: `selectedText` is an empty string for highlights created before Session 131, and those
  can only be reviewed by eye.
- **Delete** — with the same confirmation weight as deleting an annotation anywhere else.

**And one thing the app must never do: silently re-anchor.** An offset quietly moved to a
plausible new position produces a highlight over text the researcher never selected, in a citation
they may already have published. The unique-match repair above is offered, shown, and confirmed —
never applied on the reader's behalf.

### 5.5 The notification

**Volume-level entry point, document-level content.** The two are not alternatives.

- The **entry point** is the existing updatable-volumes surface in both storage hubs, plus a
  post-update summary: *"frus1969-76v12 was updated. 3 documents you have annotated changed."*
  Volume-level, because that is the grain at which the reader acted.
- The **content** is per document, per annotation: which documents, which of the reader's
  annotations sit on them, and which of those have actually shifted rather than merely been
  nearby.
- **Nothing modal, nothing at launch.** A researcher opening the app to read is not asking to be
  audited. The count belongs in the Research surface and in Settings, as a badge that waits.
- **The existing in-document banner stays** and gains precision: it can now distinguish *the
  passage you highlighted moved* from *this document changed elsewhere*.

### 5.6 The review surface already exists

`ResearchView` aggregates researcher engagement per `(volumeId, documentId)` from exactly the four
sources that matter — `ResearchNote`, `DocumentTagAssignment`, `CollectionEntry`,
`DocumentHighlight` (`ResearchView.swift:39–48`). A review flow is a **filter over that existing
aggregation** — the documents with an unreviewed revision row — plus a per-annotation action set.
This is the single biggest reason the feature is affordable: no new aggregation layer, no second
model of what a researcher has done to a document.

---

## 6. Phasing

Each phase ships on its own and is useful without the next.

| Phase | Scope | Depends on |
|---|---|---|
| **P1 — see it** | **SHIPPED 2026-09-03 (PR #1179).** The `document_revisions` table; both hashes written in `parseAndExtract`, the only pass that holds the AST; the change set stamped by one SQL `CASE` upsert with no prior read; `'vanished'` stamped on the revision row before `auxDeleteVanishedCacheRows` runs. No UI, no `@Model`, no index bump (`CREATE TABLE IF NOT EXISTS` is additive). Read back through `documentRevisions(forVolumeId:)`. | Q-1 answered — see §8 |
| **P2 — say it** | **SHIPPED 2026-09-03 (PR #1180).** `VolumeUpdateReviewSection`, one shared view mounted by both storage hubs, states per volume how many changed documents carry the reader's research and splits them text / apparatus / gone, with an Open Research control; `ResearchView` gained a *Changed by an update* sidebar row (shown only when non-zero — the tab carries no badge by the `MainTabView` decision) filtering the existing aggregation by the unreviewed rows, and each row states its change kind; the twins' byte-identical `staleHighlightBanner` became one `DocumentChangeBanner` whose sentence is a function of (recorded change, highlight staleness) — seven cells, all pinned. The aggregation also widened from four sources to six: `GeneratedSummary` and `ArchiveVisitDocument`, the two a correction most directly supersedes, so a document carrying only a summary or only a visit plan now appears at all. One latent defect fixed on the way: `onVolumeDownloaded` never dropped the volume's cached ASTs, so a document opened before an update kept rendering the superseded text while the index described the new one. No `@Model`, no index bump. | P1 |
| **P3 — fix it** | **SPLIT AFTER THE 2026-09-03 RECONNAISSANCE (15 agents, every load-bearing claim adversarially verified).** **P3a — SHIPPED 2026-09-03 (PR #1181):** the `reviewed_at` writers (`markDocumentRevisionReviewed`, `markVolumeRevisionsReviewed` — the column had readers on three surfaces and no writer); one shared `DocumentChangeReviewSheet` reached from the banner's *Review…* control in both twins and from a *Review Changes…* action on any Research row with an unreviewed change, listing every highlight with its standing (aligned / stale with passage / stale without passage / unverifiable) and the two verbs the code can keep honest — **Confirm** (rewrites `renderingVersion` to the current value; a CloudKit-mirrored field, so it clears the amber on every device while the document-level stamp stays on this one, and the copy says so) and **Remove** (the twins' own `highlight.delete.*` confirmation) — plus the other annotations counted and never judged, and the document-level *Mark Reviewed*; a per-volume *Mark Reviewed* in the hub section behind a dialog that states the count; the `'body'` arm of the upsert now escalates as Q-5 claimed and the code did not (see Q-5); a `.rebaseline` mode so `indexAllVolumes` — a version bump or the hub's re-index, never a file change — writes hashes and stamps nothing; the upsert loop in one transaction per chunk; the web view's repaint signature widened from ids to (id, offsets, version) so a confirm repaints; and the offset-unit doc comments corrected (the unit is UTF-16, not the Unicode scalar the model and `102-DocumentHighlight-Architecture.md` said). A vanished document's only route is the Research row, since no document view can open one, and the sheet needs no render model. **P3b — decided 2026-09-03, see §8.2 for the sequence; was:** the unique-match re-anchor (three unsettled inputs: the UTF-16 unit with a non-BMP fixture, the `"\n\n"` block seams `selectedText` carries, and an untested preview/repaint path), summary re-generation semantics, excerpts in the review filter, per-annotation review state for the non-highlight types, the never-deleted rows of a removed volume, and the note / tag / override / lead / history *modify* surfaces. | P2 |

A useful property of P1: it is worth shipping in the **same release as the next volume batch**,
because a revision table that starts recording before the first correction lands is a table that
can answer the question the first time it is asked. Shipped later, it is blind to every correction
that came before it.

---

## 7. What this design refuses

- **No silent re-anchoring.** 5.4.
- **No auto-deletion of anything**, including annotations on vanished documents. An orphan is
  shown as an orphan; the reader decides. The alternative destroys research on the app's own
  initiative.
- **No warning for changes that move no characters.** §4's last row. Whitespace normalisation and
  the `kVersion`-not-bumped precedent are the guard.
- **No claim the app cannot support.** "This document changed" is provable from two hashes.
  "Your note is now wrong" is not, and the copy must not imply it — the reader is being asked to
  look, not told they are mistaken.
- **No CloudKit schema change in P1 or P2.** 5.2. *(P3b-2 makes one, deliberately and with the
  owner's decision on Q-3 behind it — the ninth Production promotion. The refusal was always
  scoped to P1 and P2.)*

---

## 8. Open questions

| # | Question | Why it needs an answer |
|---|---|---|
| **Q-1** | Is the render-node conversion affordable at index time? | **Measured 2026-09-03, and yes — eager.** Over the largest post-1960 volume (`frus1961-63v10-12mSupp`, 11 MB, 751 documents): parse 0.50 s; converting and versioning **every** document 0.05 s (**9.7%** of the parse); the content SHA-256 over 4.3 MB of stored text 0.03 s. The converter is a dependency-free struct constructed fresh per document (it carries footnote state). One caveat: simulator, warm page cache — but the ratio is an order of magnitude below the parse, and it is the ratio that decides. The lazy fallback in 5.1 is not needed. |
| **Q-2** | Should the reader be able to keep the **old** text of a changed document? | The strongest possible answer to "was my note right?" is the diff. Storing the superseded `body_text` for annotated documents only is bounded and cheap; storing it for all is not. |
| **Q-3** | Does review state need to sync across devices? | 5.2's stated cost. Deferring it is safe; reversing it later is a schema change. **DECIDED 2026-09-03: yes, review state syncs.** Delivered by Q-6's ledger (below), which carries document-grain rows beside annotation rows; a reconcile pass stamps the local `reviewed_at` when a synced record matches the local `content_hash`, so the three P2 readers keep reading one column. |
| **Q-4** | What happens to an annotation whose volume is *removed* rather than updated? | Out of scope here, and today the annotation simply persists unreferenced. Worth confirming that is intended. |
| **Q-5** | Should an update be offered at all while unreviewed changes are pending from the last one? | A reader who updates twice before looking gets two change sets over one baseline. The revision table handles it; the copy has to. **P2 note:** the `CASE` upsert re-stamps `change_kind` on every change, so a `'body'` change followed by an `'apparatus'` one reads as *apparatus* although the highlight space moved since the reader last looked. This is why `DocumentChangeBanner` keeps BOTH inputs — the recorded kind and each highlight's own `renderingVersion` against the document's — and says "some highlights may be misaligned" whenever the second disagrees, whatever the first says. P3's review action should stamp `reviewed_at` and leave the kind's escalation (body wins over apparatus until reviewed) to the upsert. **P3 correction:** the escalation this note attributed to the upsert did not exist — the `CASE` stamped `'apparatus'` for any content change that was not a body change, whatever the row held. P3a added the arm (`excluded.content_hash != content_hash AND change_kind = 'body' AND reviewed_at IS NULL → 'body'`), tested body→apparatus→still body, then reviewed→apparatus→apparatus. The banner keeps its second input regardless. |

---

### 8.1 Decisions P3b waits on (from the 2026-09-03 reconnaissance)

| # | Question | What the code says |
|---|---|---|
| **Q-6** | Is review state **per document** (the table's grain: `PRIMARY KEY (volume_id, document_id)`) or **per annotation**, as §5.4's "a row in the revision table" implies for notes, tags, entries, summaries, and visit seeds? | Only highlights carry per-annotation state (`renderingVersion`). A device-local side table keyed by annotation id is fragile: `UserTagPickerSheet` re-mints every `DocumentTagAssignment` id on save, and boot-time dedupe deletes `CollectionEntry` / `ArchiveVisitDocument` rows by id collision. `ArchiveVisitDocument.stateData` is the one deploy-free per-row slot. P3a ships per-document. |
| **Q-7** | Should **excerpt** collection entries join the review filter? §5.3 lists them; the aggregation admits only `.document` entries, and widening it desynchronises Research from `ProjectEngagedDocuments`, `ProjectLeadsService`, and `DocumentEngagementService`, which keep the `.document` rule. Nothing renders from `excerptRenderingVersion`; the frozen `text` is authoritative, so a body change cannot break an excerpt on screen — `ExcerptVerifier` (export-time) is the existing reader. | Decision, not code. |
| **Q-8** | **Summary re-generation**: `summarize` always ADDS a row; iOS has no regenerate control at all (the rail offers *Summarize* only when no summary exists); macOS's `SummaryBlockView` regenerates with the OLDEST prompt behind raw-literal buttons; `GeneratedSummary` stores no hash of the text it described, so "predates the change" can only be `createdAt < changed_at`, and `changed_at` is this device's re-index time. Headnote drafts (`isHeadnoteDraft`, the only user-authored summaries) are counted by the P2 aggregation but excluded from every carousel. Keep or replace the superseded row? Exclude drafts? A stored source hash is a #488 deploy. | P3a counts non-draft summaries in the sheet and offers nothing. |
| **Q-9** | **Q-4 widened by code**: `document_revisions` is never deleted — not by `removeVolume`, `removeAllVolumesFromIndex`, or Erase Everything — so a removed volume's unreviewed rows keep counting in the hub and Research, and a re-download after removal is stamped against pre-removal hashes. Clear on remove (losing the "changed while it was gone" answer) or keep and disclose? | P3a's per-volume *Mark Reviewed* is the manual escape. |
| **Q-10** | The **unique-match re-anchor** (§5.4): compute in UTF-16 with a non-BMP fixture; search per block over `buildFlatTextBlocks` because `selectedText` joins blocks with `"\n\n"` the flat text lacks and drops whitespace-only slices; a `::highlight(frus-preview)` + scroll-to-offset path for "show before confirm" that no test harness can drive today (`FRUSOffsetEngineTests` mirrors the DFS, not the production script). Also: after a re-anchor, re-freeze `selectedText` or keep the reader's original? | Its own PR. |
| **Q-11** | The *modify* surfaces for `ResearchNote` (the Research row cannot open a note editor), `DocumentTagAssignment`, `DocumentClassificationOverride` (its `parsedIsEditorialNote` is never refreshed after init, so "re-check the parse against the override" has no fact to check), `ProjectLeadEntry`, `ReadingHistoryEntry`. | No reader located a mount; each is a small design of its own. |

### 8.2 Decisions taken 2026-09-03 (owner), and the P3b sequence they fix

| # | Decision | Consequence |
|---|---|---|
| **Q-3** | Review state syncs. | Settles Q-6 toward the mirrored ledger; the document-grain stamp joins it through a reconcile pass. |
| **Q-6** | **G** — one new mirrored `@Model` ledger (`AnnotationReview`: annotation type, annotation id, volume, document, content hash, reviewed at), rather than a field on four to seven annotation types. Tags key on **tag id**, since the picker re-mints assignment rows. | One CloudKit record type in the ninth Production promotion (#488 gate: `identifiersAwaitingDeploy`, owner exercises on a Development build, Dashboard deploy, baseline restated). |
| **Q-7** | **(b) with (f)**: excerpt entries join the review filter; the sheet runs `ExcerptVerifier` per quotation and reads `excerptRenderingVersion` as a highlight's version is read. Plus the export sheet stops reporting a vanished document as "volume not downloaded". The three engagement consumers keep the `.document` rule. | **SHIPPED P3b-4**, no deploy — the rows are reads, and a ledger row for a collection entry would have cost a tenth promotion. The iOS manual gained the whole review paragraph it lacked, and both manuals' excerpt sections were corrected: the frozen text stays as the source *printed* it, not as it *prints* it. |
| **Q-8** | Drafts excluded from the counts; **(e)** the two per-platform generate surfaces fixed (Mac regenerates with the summary's own prompt, four literals localised; iOS rail offers Regenerate when a summary exists); **(g)** search hygiene (newest non-draft summary wins the FTS column); **(b)** regenerate-and-keep from the sheet as a later step; **(d-cloud)** `GeneratedSummary.sourceContentHash` **rides Q-6's deploy** — the stored value is the revision row's `content_hash` at generation, never a hash of the summariser's input; existing summaries stay null and keep the date rule. (c) refused; (f) only if a correction batch is large. | One more identifier in the same promotion. |
| **Q-9** | **(c)** un-indexed volumes excluded from the unreviewed read at VOLUME grain (rows return intact on re-download); **(d)** rider: the table is cleared at the Erase-Everything site only — never in `resetLocalData`, which "Reset This Device" also calls while promising annotations return. | No deploy. Known residue: a removed volume misses the rebaseline; an additive `index_version` column fixes that later. |
| **Q-10** | **(b)** the exact, unique, seam-aware search in the shared sheet with Move after an explicit tap and the found words plus context shown; **(e)**'s three sentences ship inside it; **(f)** a Find-passage complement through the twins' existing find machinery — **subsequently REFUSED in P3b-4** on a six-axis measurement of what the find bar searches against what the sheet searches; see the P3b-4 paragraph below. UTF-16 pinned by fixture (the corpus holds no non-BMP or combining character). (c) only if matching ever becomes normalised. | No deploy. |
| **Q-11** | **(h)** a vanished row's Open Document routes to the sheet; **(f)** the vanished-row delete also removes the `document_sources` row (a live visit plan was deriving targets from a document that no longer exists); **(b)** Open Note and Edit Tags from the sheet, the plan editor where a route exists; **(i)** the override's "FRUS tags this as" sentence refreshed from the live parse on open. (c) the purge refused. | **(b) and (i) SHIPPED P3b-5**, no deploy. (i) turned out to be THREE sites — the sentence and both Undo paths — plus a fresh override minting a corrupt snapshot after a stale restore. (b) reaches notes, tags and archive-visit plans; macOS routes a note to its composer WINDOW, whose request type is pure identity, rather than nesting a sheet. |

**Sequence.** *P3b-1* (deploy-free hygiene, **PR #1182**, SHIPPED): Q-9 (c)+(d), Q-11 (h)+(f), Q-8 drafts + (g), Q-7's export-sheet cause fix. *P3b-2* (the deploy PR, **PR #1183**) — **SHIPPED; the NINTH promotion ran 2026-09-03 (build 44)**, nine of ten identifiers attested (`CD_AnnotationReview.CD_annotationId` still awaits a build that writes one):
`AnnotationReview`, one mirrored ledger with a **derived id over `kind|annotationId|document|contentHash|changeKind`**, which makes it
append-only — two devices reviewing the same change at the same text mint a byte-identical row that
`DuplicateRecordCleanup` collapses losslessly, so no CloudKit merge can destroy a review (keyed on the
annotation alone the row would be mutable and last-writer-wins would silently drop one device's). No
`lastModified`; `createdAt` computed, so it costs no identifier. The kind vocabulary ships whole and only
`document` has a writer, because minting `note`/`tag`/`collectionEntry`/`summary`/`visitDocument` in P3b-4
or P3b-5 would cost a TENTH promotion for two columns that already exist. **`highlight` is absent**:
`renderingVersion` already syncs and keys on `body_hash`, the ledger on `content_hash`, and an
apparatus-only correction moves one and not the other — two sources of truth with no non-arbitrary
tie-break. `applyAnnotationReviews` matches the text AND the change (`AND content_hash = ? AND change_kind IS ?`).
The hash carries most of it — a correction moves it in the same statement that NULLs `reviewed_at` —
but **not all of it, which the P3b-2 review established**: the upsert's second arm (`OR change_kind =
'vanished'`) clears the stamp at an UNCHANGED hash, because the vanished mark keeps the hash, so a
document that vanishes and is restored unchanged is re-opened at a hash the reader already reviewed
and a hash-only match would have stamped the restoration as seen. The kind term refuses that, and
subsumes the blanket vanished refusal it replaced — a vanished document's own disposition now crosses
devices, while a review of the change before it cannot be mistaken for one. The
reconcile runs at three mounts — boot, the CloudKit import-settle debounce, and after a volume
re-indexes — and backfills every stamp made since P3a, which would otherwise never leave its device.
Q-8 (d-cloud) rides along. **10 identifiers** in `identifiersAwaitingDeploy`; the baseline is deliberately
not restated. *P3b-3* — **SHIPPED 2026-09-03 (PR #1185)**: Q-10 option (b), the exact unique seam-aware search with **Move Here** behind an explicit tap and the found passage shown in its surroundings. `HighlightReview.locate` generates candidate positions loosely and accepts one only if RE-EXTRACTING at that span reproduces the stored passage — the shipped extractor is the oracle, so the corpus's real shapes are filtered rather than re-derived: a literal `"\n\n"` inside one block (35 across 23 volumes, from two adjacent `<lb/>`), a whitespace-only block dropped between two kept ones (51 across 29), and **two historical `selectedText` formats** (a raw flat-text slice before 2026-07-03 and `flatTextExcerpt` output after — five of the owner's own eight highlights are the older shape, so a matcher accepting only the modern one would report "not found" for the oldest annotations). Guards: a 40-unit floor (13–15% of ten-character fragments repeat within their own document), and a 200-unit distance band above which a unique match is REPORTED but never offered, because a distant unique match is the signature of a **renumbered** document where the id now names a different document. `move` writes offsets and `renderingVersion`, never re-freezing the reader's words. Option (f), the find-bar complement, is deferred: the two platforms search rendered text with different options and report counts differently, so it would contradict the sheet. *P3b-4* — **SHIPPED 2026-09-03 (PR #1186)**: Q-7 option (b) with (f). `ResearchDocumentAggregation.countsAsAnnotation`
admits `.excerpt` beside `.document`, so a document whose only annotation is a frozen quotation joins
"Changed by an update" and the hub's per-volume count — which makes the hub footer's promise that a
"collection entry" counts TRUE for the first time, and settles a disagreement inside one view, since the
same sidebar's By-Collection grouping has always counted an excerpt as membership. The three engagement
consumers keep the `.document` rule and are byte-identical; they are three independent copies, so there
was nothing shared to guard. The sheet gains a **Quotations** section running the export check per
quotation — the shipped `ExcerptVerifier.verify` and `upgradingVanished`, never a second copy, without
which every quotation on a vanished document would read "this volume is not on this device", the exact
Q-7 (g) misreport P3b-1 had just fixed on the export path and this sheet is the only route a vanished
document has. Rows are READ-ONLY by decision: an `AnnotationReview` of kind `collectionEntry` would be
the first writer of `CD_AnnotationReview.CD_annotationId` and force a TENTH promotion against this row's
own "No deploy"; a Move would be an invisible write, since nothing renders from the anchors; and a
delete belongs to the collection editor. **The two answers read different strings and the copy is built
around that**: the verifier searches the index's `body_text`, which includes footnote prose, while
`excerptRenderingVersion` hashes `flatText(model.bodyNodes)`, which excludes it — so a footnote
quotation routinely verifies while carrying NO version, which is why `.unversioned` is its own state
with its own sentence and never collapses into staleness. Two facts found in review, and the first runs the opposite way to intuition: **`change_kind` is decided by `body_hash`, the render flat text with footnotes EXCLUDED — the very string `excerptRenderingVersion` belongs to — while the verifier reads the index's `body_text`, footnotes INCLUDED**, so an *apparatus* correction leaves the version equal and changes the haystack, and a quoted footnote can begin failing under a correction the banner calls notes-only. A draft footer and a draft special-cased sentence both asserted the reverse (that an unchanged version proved the words never matched) and both were withdrawn; the general hedged sentence is the one that survives the asymmetry, and the footer now states it in those terms. Second: a pre-2026-07-03 raw-slice quotation spanning a block seam reports `notFound` for a formatting reason, which is a property of the shipped export check and another reason the sentence hedges. Rider fixes: the Research sidebar's per-collection
count was `documentEntries.count` — every entry of every kind — so a collection of three documents under
two headings showed "5" and opened a list of three; it now counts distinct documents under the same rule.
**Q-10 (f) is REFUSED, not deferred again.** The seeded find bar was measured against the sheet's own
search and they disagree on SIX axes, not the two P3b-3 recorded: block seams, `<br>`, `data-skip`
footnote-marker digits and figure captions present in the DOM and absent from flat text, the visible
endnote section outside `.frus-document` that find matches and the sheet cannot see, case (the find bar
is case-insensitive and wrapping; the sheet is exact equality), and counting — macOS's WebKit find API
reports only whether the current search matched, so that platform cannot state a count at all while the
sheet says "Found N times". A control that contradicted the sentence beside it would be worse than no
control. If the complement is wanted later, the shape to build is scroll-and-reveal from the match's own
offsets (`buildRanges` already turns them into a DOM Range, and `revealFootnote` is the working
precedent), which needs no third text. *P3b-5* — **SHIPPED 2026-09-03 (PR #NNNN)**: Q-11 options (b) and (i). **Q-8 (e) and (b) move to
P3b-6**, because (e) turned out to be five defects rather than the "four literals" the row records —
the oldest-prompt regenerate, SIX unlocalised literals, a `· custom prompt` label that renders for
every summary including standard-prompt ones, three silent failure paths, and a `fetchLimit = 20` on
a descriptor with no `sortBy`, which under SQLite pages the OLDEST twenty and would hide a
regenerated summary outright — and because the summary surfaces are the genuine twin in this
workstream while everything in (b)/(i) is a single shared view.
**(b)**: the sheet now OPENS what it names. A row per research note presents `ResearchNoteEditorView`;
*Edit Tags…* presents the shared `UserTagPickerSheet`; and a row per archive-visit PLAN opens
`ArchiveVisitEditorView` in the shape Project Home already presents it. Until now the sheet told a
reader that a document they had written on had changed and offered no route to what they wrote. Every
editor takes only scalars the sheet already held, and all three are declared INSIDE the sheet, because
SwiftUI will not present an ancestor's sheet over a descendant's. Three decisions worth keeping: macOS
opens a note in the `frus.noteComposer` WINDOW rather than a nested sheet, since `NoteComposerRequest`
is pure identity and opening the same note twice must focus the open window instead of stacking a
second editor over one row; *Edit Tags…* is NOT gated on the document already having tags, because the
picker replaces the whole assignment set and a gated control would delete itself when the last tag was
cleared; and the plan row promises only to OPEN the plan — the editor takes a whole plan, opens on its
Targets tab and cannot focus a seed, so a label saying it would show this document there is a promise
the app cannot keep. The plan route was first refused on "it cannot be aimed" and the refusal was
overturned in recon: a label that claims no aiming needs none.
**(i)** is three sites, not the one the row names. `parsedIsEditorialNote` is written once at override
creation and NOTHING refreshes it — not `setOverride`'s update branch (unreachable from the app), and
not a re-index: `applyClassificationOverrides` writes only `document_cache.is_editorial_note`, and the
model's own doc comment claiming a re-index corrected the drift was FALSE and is corrected. So after
the Office of the Historian fixes the same mistag a reader corrected, the rail's "FRUS tags this as…"
quoted the superseded reading, and BOTH controls labelled *Restore FRUS's Classification* — the rail's
and Settings' per-row Undo — wrote it back into the index, leaving the column disagreeing with the TEI
and no override row to explain it. A verifier found the third site: after such a restore the column is
corrupt, so a FRESH override mints a corrupt snapshot. All three now prefer the live parse. The rail
reads `DocumentViewModel.parsedIsEditorialNote`, which records `ast.isShapedAsEditorialNote` BEFORE the
override reshapes the AST and had ZERO readers until now; Settings, which has no open document,
re-parses the TEI through a new shared rule and falls back to the stored snapshot when the volume is
absent — the ordinary case there, which is why that field is not a load-time placeholder and stays the
value of record. **It cannot come from the index**: once an override exists the replay has written the
reader's own assertion into that column, so a "refresh from the index" would quote the reader back at
themselves as FRUS. Read REACTIVELY, because `.task(id: entry.id)` fires when the entry changes and not
when the document finishes loading. Display-only: no model write, so nothing syncs on a read gesture.
**Reading it live made AGREEMENT reachable for the first time** — the frozen snapshot recorded a
disagreement and could never stop reporting one — so a new sentence says when FRUS has adopted the
reader's correction and that it no longer changes anything. *P3b-6*: Q-8 (e) then (b).

## 9. What this design does not cover

- **The reverse case**: an annotation made against a *side-loaded* pre-release volume that OH later
  publishes officially. The file changes wholesale and the document ids may not correspond at all.
- **Cross-document annotations** — collection-level prose, saved searches, project leads that name
  a document by citation rather than by key.
- **Published exports.** A collection exported to PDF or DOCX before a correction carries the old
  text forever, and nothing in the app can reach it. `ExportHistoryEntry` records what was exported
  and when; whether it should be cross-referenced against later corrections is a real question and
  a separate one.

---

*Document history*
*1.0 — 2026-09-02: written against `b142381`, answering `New-Volume-Release-Plan.md` §13.*
*1.1 — 2026-09-03: P1 shipped (#1179); Q-1 measured and answered. One design premise corrected in the shipping: the vanished stamp does not need to run *before* the cache delete, because the revision row lives in its own table and survives it — the ordering is kept for legibility, not correctness.*
