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
| **P1 — see it** | The `document_revisions` table; hashes written at index time; `auxDeleteVanishedCacheRows` records before deleting. No UI. Ships silently and starts accumulating truth. | measure the `body_hash` cost first (5.1) |
| **P2 — say it** | Post-update summary in the storage hubs; the affected-documents filter in `ResearchView`; the in-document banner distinguishes body from apparatus change. | P1 |
| **P3 — fix it** | Per-annotation confirm / re-anchor / delete, including the unique-match repair; `GeneratedSummary` re-generation offer; orphan repair for vanished documents. | P2 |

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
- **No CloudKit schema change in P1 or P2.** 5.2.

---

## 8. Open questions

| # | Question | Why it needs an answer |
|---|---|---|
| **Q-1** | Is the render-node conversion affordable at index time? | Decides whether `body_hash` is eager (5.1) or lazy. Must be measured, not assumed. |
| **Q-2** | Should the reader be able to keep the **old** text of a changed document? | The strongest possible answer to "was my note right?" is the diff. Storing the superseded `body_text` for annotated documents only is bounded and cheap; storing it for all is not. |
| **Q-3** | Does review state need to sync across devices? | 5.2's stated cost. Deferring it is safe; reversing it later is a schema change. |
| **Q-4** | What happens to an annotation whose volume is *removed* rather than updated? | Out of scope here, and today the annotation simply persists unreferenced. Worth confirming that is intended. |
| **Q-5** | Should an update be offered at all while unreviewed changes are pending from the last one? | A reader who updates twice before looking gets two change sets over one baseline. The revision table handles it; the copy has to. |

---

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
