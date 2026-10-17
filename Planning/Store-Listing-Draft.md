# App Store listing — draft copy

**Status:** DRAFT, 2026-08-31. Visual-marketing plan §7 step 3, *"draft store copy by lifting"*.
Nothing here is published; App Store Connect metadata is the owner's to paste and submit.

**Figures re-measured 2026-10-01** against the bundle at `v2` `dc17d945` (build 48's bundle plus
the build-49 wave's regenerations): the volume count and every map figure had moved since the
draft was written, when the manifest held 552 volumes. §5 gives each figure's source. The field
lengths did not move (552 → 553 is the same length), and §6's counter was re-run. **Three
sentences of the description that shipped features contradicted were reworded by the owner on
2026-10-15 — see "Settled before paste" under §2.** The price (free) and the territories (every
storefront, English only) were confirmed the same day.

**Every field below is counted, not estimated.** The plan's headline correction for this step is a
length failure — a candidate subtitle 83 characters over a 30-character field — so the counts are
the first thing in each block. Re-count after any edit with the script in §6.

**Every number below was measured against a shipped artifact**, per §5's rule that no marketing
number may come from `CLAUDE.md` or a generator doc comment, several of which are measurably stale.
The app is safe because it recomputes at render time; **a store description has no recompute step.**
Provenance for each figure is in §5.

---

## 1. The short fields

### App name — 13 / 30

```
FRUS Explorer
```

### Subtitle — 26 / 30 ✅

```
The U.S. diplomatic record
```

**The candidate line must not go here.** *"The official documentary record of U.S. foreign policy
since 1861…"* — the plan measures the full line at **113 characters** — is proposed for a
30-character field, and it leads with *official* while the mandatory disclaimer sits in About, out
of view. It belongs in the description, in the same
field as the disclaimer — see §2.

Alternates, all counted:

| Option | Chars | Note |
|---|---|---|
| `The U.S. diplomatic record` | 26 | **Recommended.** Says what the corpus is without the acronym. |
| `Research the FRUS series` | 24 | Clearer to someone who already knows the acronym; opaque otherwise. |
| `US foreign relations research` | 29 | Keyword-dense, reads like a search query rather than a subtitle. |
| `Read and search 553 volumes` | 27 | Concrete, but dates the moment a volume is published. |

### Promotional text — 153 / 170 ✅

Editable without a review, so it is the field for anything time-sensitive.

```
553 volumes of the U.S. diplomatic record, indexed on your device and searchable offline — with the sourcing and analysis tools a corpus this size needs.
```

### Keywords — 92 / 100 ✅

Comma-separated, no spaces (spaces are billed as characters).

```
FRUS,diplomacy,history,archives,primary source,NARA,research,foreign policy,declassified,TEI
```

---

## 2. Description

**4,000-character field. This draft is 3,038 / 4,000 ✅** (counted with Python's `len()` over the
block on 2026-10-17, after the BUILT ON THE EDITORS' WORK section and the READ line's credit to the
editors; 2,525 on 2026-10-15 after the owner's three sentences, 2,324 before them), leaving room for
the owner to add or cut.

The disclaimer is in **this** field, immediately after the "official documentary record" sentence,
which is the placement §4.1 requires — the two must not be separated.

```
FRUS Explorer is a research tool for the Foreign Relations of the United States series: the
official documentary record of U.S. foreign policy, published since 1861.

FRUS Explorer is an independent research tool. It is not an official product of the Office of the
Historian or the U.S. Department of State. Any commentary, advice, or guidance about the FRUS
series in this app reflects personal views. Those views are not necessarily those of the
Department of State or the U.S. Government. The FRUS series itself is in the public domain.

BUILT ON THE EDITORS' WORK
FRUS is an edited series. Its editors, today the historians of the
Department of State's Office of the Historian, choose each document from the
government's files, write its heading, record where the original is kept,
annotate what it refers to, and summarize what they could not print. FRUS
Explorer reads that apparatus: source notes become archival leads,
cross-references become a graph, and the people the editors identified become
an index you can search.

The app downloads the Office of the Historian's TEI editions, indexes them on your device, and
works offline from then on. What you read, search and write stays with you: notes and collections
sync only through your own iCloud account, and the app reaches the National Archives' catalog or
your Zotero library only when you ask it to.

READ
Documents rendered from the original TEI with the editors' headings, footnotes, page breaks and
live cross-references, plus highlights, notes, and a per-document research rail.

SEARCH
Full-text search with stemming, phrases, NEAR() proximity and exact-word matching, across 553
volumes. Save a scope, or capture a working corpus from a result set and search inside it.

SOURCE
Most documents carry the editors' own note saying where the original came from. FRUS Explorer
resolves those notes as far as the offline reference data reaches — a lot file to its record group and
series, a decimal file number to the subject it encodes, a collection to the archive that holds
it — so a citation becomes a shelf you could visit.

ANALYSE
Term frequency over time, cross-reference graphs, person and archival profiles, and a semantic map
of the whole published series. Nearly every chart exports its data as a CSV carrying its full
method statement, and most export as a figure too.

COLLECT
Group documents into collections and projects, annotate them, and export to PDF, DOCX, HTML,
BibTeX or RIS with citations formatted for you.

ON YOUR DEVICE
Volumes, notes and highlights live on your device; notes and collections sync privately through
your own iCloud account. Optional natural-language search runs entirely on-device using Google's
EmbeddingGemma model — an experimental feature, and nothing you type leaves the device.

FRUS Explorer is not affiliated with, endorsed by, or sponsored by the National Archives and
Records Administration (NARA). NARA Catalog data accessed through this app is provided by the
National Archives and is subject to their terms of use.
```

### What is deliberately not in it

- **"Every document."** A full library indexes **316,814** documents (the 314,616 printed
  documents plus 2,198 prose sections the parser promotes; counted by the parser's replica, not
  yet on a device — §5) while the semantic map places
  **314,616** — two different surfaces, two honest numbers, and neither is "every".
  The description says *553 volumes*, which is the one count that is fixed and checkable.
- **Any claim of endorsement by Google.** *"using Google's EmbeddingGemma model"* is the permitted
  form — describe, never brand. Nothing here implies endorsement.
- **Any figure lifted from a planning document.** See §5.
- **"AI-powered."** The on-device model does one thing — turning a typed question into a vector —
  and the feature ships flagged experimental in the app itself. The description says the same.

### Settled before paste (owner, 2026-10-15)

Three sentences of the block said more than the app does. Each was checked against the tree at
`dc17d945`, and the owner chose the wording that replaced each on 2026-10-15 (`Plan-Of-Record-2026-10-14.md`
§0, decisions 28 to 30). The block above carries the new sentences; what each replaced, and why:

- ***"Nothing you read, search, or write is sent anywhere."*** Now: *"What you read, search and
  write stays with you: notes and collections sync only through your own iCloud account, and the
  app reaches the National Archives' catalog or your Zotero library only when you ask it to."* The app queries the NARA Catalog
  when a reader asks it to (`FRUSExplorer/SourceExplorer/NARACatalogClient.swift`,
  `catalog.archives.gov/api/v2`) and sends a collection to the reader's own Zotero library on
  request (`FRUSExplorer/Zotero/ZoteroAPIClient.swift`, `api.zotero.org`), and the *ON YOUR DEVICE*
  paragraph of the same description says notes and collections sync through iCloud. Accurate
  wording already exists in `Completed/App-Store-Custom-EULA.md`, clause 9 (*Data*), the custom EULA build 51 does not need (it moved there on 2026-10-15, never entered).
- ***"Every chart exports as a figure or as a CSV."*** Now: *"Nearly every chart exports its data
  as a CSV carrying its full method statement, and most export as a figure too."* Both manuals say
  "Not every chart offers a figure", and two do not export at all, the Person Network graph and
  Chronology's distribution chart (`Docs/macOS-User-Manual.md` §15.8, `Docs/iOS-User-Manual.md` §15.8).
- ***"Every document carries the editors' own note saying where it came from."*** Now: *"Most
  documents carry the editors' own note saying where the original came from."*
  `collection-usage-index.json` counts 264,598 source notes paired with a document, in 502 of the
  553 volumes, against 314,616 printed documents: 51 volumes carry none.

### Added 2026-10-17: the editors' theme

`Launch-Marketing-Kit-2026-10-13.md` §1a adds a second theme, *built on the editors' work*, and this
field carries it in two places: a BUILT ON THE EDITORS' WORK section after the disclaimer, which must
stay below it so the "official documentary record" sentence and the disclaimer remain together, and
the READ line's "the editors' headings". The section names the Office of the Historian, which the
disclaimer above it already covers. It says what the editors do in the terms of the series' own
prefaces and claims no figure, so §5 owes it nothing. The owner may cut the section whole; nothing
else in the field depends on it.

The promotional text has an alternate for the theme, 152 / 170, counted the same way:

```
The edited record of U.S. diplomacy, 553 volumes indexed on your device, with tools built on its editors' source notes, cross-references and annotation.
```

---

## 3. What's New (first release)

```
First release.

FRUS Explorer reads, searches and sources the Foreign Relations of the United States series
offline, from the Office of the Historian's own TEI editions.
```

---

## 4. Screenshots and the App Preview

Per §4.1: two capture passes, **the same simulator and resolution in both**.

| Pass | Device state | Shots |
|---|---|---|
| A | Erased | splash → onboarding scope sweep |
| B | Full corpus (already indexed — see below) | search → document → map → Source Explorer |

**Gate B was satisfied when this was written** (2026-08-31: the author's Mac carried all 552
volumes and 316,839 documents), so pass B is unblocked; only pass A needs an erased device. The
library has since gained vol. XVI and been re-indexed twice; confirm 553 volumes in Volumes &
Storage before capturing.

**The `prepareVolumes` trap, which is the most valuable operational line in §4.1.** Switching to
Volume scope fires `BundledCloudVectors.prepareVolumes()`, and until it resolves a volume scope
falls back to the **subseries** list. An early frame therefore shows the *era's* vocabulary and
looks entirely plausible. **Hold for the LensChip before recording.**

**Hero: a live screenshot of the map, not the figure export.** The live view prints its own
disclosure beneath it; the figure export is a research plate with a methods band, which is right for
a journal and wrong for a store.

Any shot showing the map or naming a region carries §5's obligations in the pixels — the app draws
them itself, which is why a live screenshot is safer than a composed one.

---

## 5. Every number in this document, and where it was measured

Not one is quoted from prose.

| Figure | Value | Measured from |
|---|---|---|
| Volumes | 553 | `manifest.json`, entry count |
| Documents indexed | 316,814 | the index v63 parser's emission over the 553 volumes, reproduced 2026-10-10 with `tools/page-citations/replica.py` at corpus `99d851c79` (316,768 at `8e5da08c1` on 2026-10-01: one fewer since `frus1902app1`'s two re-typed divisions, 47 more since `frus1952-54v09p1`'s restored documents); index v64 and v65 changed no document count. **A device's own `SELECT COUNT(*) FROM document_cache` is owed to the release's re-index census** — the draft's 316,839 was that query at 552 volumes |
| Documents on the map | 314,616 | `semantic-vectors-index.json`, `documentCount` |
| Regions | 140 | `semantic-map-index.json`, `clusters`, re-read 2026-10-15 after B4 (EmbeddingGemma 2's layout; the 300m's held 172) |
| Documents in a region | 226,557 | `documentCount` − `layout.unclusteredCount`, re-read 2026-10-15 (222,348 under the 300m) |
| Documents between regions | 88,059 | `semantic-map-index.json`, `layout.unclusteredCount`, re-read 2026-10-15 (92,268 under the 300m) |
| Series published since | 1861 | `manifest.json`, earliest `publicationDate` |
| Subseries | 107 | `manifest.json`, distinct `subseries` |

Two figures a description must **not** use, recorded so nobody reaches for them:

- **Coverage "1861–1991"** is wrong at the low end. Three volumes carry documents earlier than 1800
  — `frus1872p2v5` reaches **1620** — because FRUS prints historical enclosures in arbitration
  papers. *Published since 1861* is the true and checkable claim; *covering 1861 onward* is not.
- **Any per-artifact count from `CLAUDE.md`.** When this was written its external-citation volume
  count read 284 against 440 in the shipped file (both have since been brought to 441). The app
  recomputes; a store listing cannot.

---

## 6. Re-counting after an edit

```bash
python3 - <<'PY'
fields = {
    "name": "FRUS Explorer",
    "subtitle": "The U.S. diplomatic record",
    "promo": "553 volumes of the U.S. diplomatic record, indexed on your device and searchable offline — with the sourcing and analysis tools a corpus this size needs.",
    "keywords": "FRUS,diplomacy,history,archives,primary source,NARA,research,foreign policy,declassified,TEI",
}
limits = {"name": 30, "subtitle": 30, "promo": 170, "keywords": 100}
for key, text in fields.items():
    n, cap = len(text), limits[key]
    print(f"{key:9} {n:4}/{cap}  {'OK' if n <= cap else 'OVER BY ' + str(n - cap)}")
PY
```

**Count characters, never words, and count the em dash as one.** The failure this step exists to
avoid was a 113-character line proposed for a 30-character field.

**And run it rather than trusting a draft, including this one.** Three of the counts first written
into this document were wrong — the promotional text by 4, the keywords by 5, the description by
523 — every one of them estimated rather than measured, in the document whose subject is not
estimating. All were inside their limits, so nothing would have been caught by the field rejecting
it; they were caught by running the script above. That is the whole argument for having it.
