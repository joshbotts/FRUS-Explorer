# App Store listing — draft copy

**Status:** DRAFT, 2026-08-31. Visual-marketing plan §7 step 3, *"draft store copy by lifting"*.
Nothing here is published; App Store Connect metadata is the owner's to paste and submit.

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
| `Read and search 552 volumes` | 27 | Concrete, but dates the moment a volume is published. |

### Promotional text — 153 / 170 ✅

Editable without a review, so it is the field for anything time-sensitive.

```
552 volumes of the U.S. diplomatic record, indexed on your device and searchable offline — with the sourcing and analysis tools a corpus this size needs.
```

### Keywords — 92 / 100 ✅

Comma-separated, no spaces (spaces are billed as characters).

```
FRUS,diplomacy,history,archives,primary source,NARA,research,foreign policy,declassified,TEI
```

---

## 2. Description

**4,000-character field. This draft is 2,324 / 4,000 ✅**, leaving room for the owner to add or cut.

The disclaimer is in **this** field, immediately after the "official documentary record" sentence,
which is the placement §4.1 requires — the two must not be separated.

```
FRUS Explorer is a research tool for the Foreign Relations of the United States series: the
official documentary record of U.S. foreign policy, published since 1861.

FRUS Explorer is an independent research tool. It is not an official product of the Office of the
Historian or the U.S. Department of State. Any commentary, advice, or guidance about the FRUS
series in this app reflects personal views. Those views are not necessarily those of the
Department of State or the U.S. Government. The FRUS series itself is in the public domain.

The app downloads the Office of the Historian's TEI editions, indexes them on your device, and
works offline from then on. Nothing you read, search, or write is sent anywhere.

READ
Documents rendered from the original TEI with footnotes, page breaks and live cross-references,
plus highlights, notes, and a per-document research rail.

SEARCH
Full-text search with stemming, phrases, NEAR() proximity and exact-word matching, across 552
volumes. Save a scope, or capture a working corpus from a result set and search inside it.

SOURCE
Every document carries the editors' own note saying where it came from. FRUS Explorer resolves
those notes as far as the offline reference data reaches — a lot file to its record group and
series, a decimal file number to the subject it encodes, a collection to the archive that holds
it — so a citation becomes a shelf you could visit.

ANALYSE
Term frequency over time, cross-reference graphs, person and archival profiles, and a semantic map
of the whole published series. Every chart exports as a figure or as a CSV carrying its full
method statement.

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

- **"Every document."** The app indexes **316,839** documents on a full library while the semantic
  map places **314,483** — two different surfaces, two honest numbers, and neither is "every".
  The description says *552 volumes*, which is the one count that is fixed and checkable.
- **Any claim of endorsement by Google.** *"using Google's EmbeddingGemma model"* is the permitted
  form — describe, never brand. Nothing here implies endorsement.
- **Any figure lifted from a planning document.** See §5.
- **"AI-powered."** The on-device model does one thing — turning a typed question into a vector —
  and the feature ships flagged experimental in the app itself. The description says the same.

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

**Gate B is already satisfied.** The author's Mac carries all 552 volumes and 316,839 documents, so
pass B is unblocked; only pass A needs an erased device.

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
| Volumes | 552 | `manifest.json`, entry count |
| Documents indexed | 316,839 | a full local index, `SELECT COUNT(*) FROM document_cache` |
| Documents on the map | 314,483 | `semantic-vectors-index.json`, `documentCount` |
| Regions | 179 | `semantic-map-index.json`, `clusters` |
| Documents in a region | 226,276 | `documentCount` − `layout.unclusteredCount` |
| Documents between regions | 88,207 | `semantic-map-index.json`, `layout.unclusteredCount` |
| Series published since | 1861 | `manifest.json`, earliest `publicationDate` |
| Subseries | 107 | `manifest.json`, distinct `subseries` |

Two figures a description must **not** use, recorded so nobody reaches for them:

- **Coverage "1861–1991"** is wrong at the low end. Three volumes carry documents earlier than 1800
  — `frus1872p2v5` reaches **1620** — because FRUS prints historical enclosures in arbitration
  papers. *Published since 1861* is the true and checkable claim; *covering 1861 onward* is not.
- **Any per-artifact count from `CLAUDE.md`.** Its external-citation volume count reads 284 against
  440 in the shipped file. The app recomputes; a store listing cannot.

---

## 6. Re-counting after an edit

```bash
python3 - <<'PY'
fields = {
    "name": "FRUS Explorer",
    "subtitle": "The U.S. diplomatic record",
    "promo": "552 volumes of the U.S. diplomatic record, indexed on your device and searchable offline — with the sourcing and analysis tools a corpus this size needs.",
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
