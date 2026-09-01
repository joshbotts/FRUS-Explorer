# W-15: geographic analytics and historical toponymy — assessment

**Status:** ASSESSED, 2026-09-01. Session C-2 of `Plan-Of-Record-2026-08-28.md` §4, covering
`BigPicture-Analytics-CorpusVsSeries.md`'s postponed priorities **8, 10, 11 and 12** together, with
era-correct place names reconciling to stable places as the owner's stated first-class requirement.

## The verdicts

| Priority | Verdict |
|---|---|
| **P10** — `place_mentions` + country attention | **BUILD, renamed.** It is a *dateline-origin* table — where documents were written — and shipping it under the name "country attention" would be shipping a different claim than the data supports. ~2–3 sessions plus owner curation. |
| **P8** — geographic/topic content charts | **DO NOT BUILD from place mentions.** Half the corpus's dateline geography is Washington. A regional-attention chart from this source is a chart of where the Department sat. |
| **P11** — document similarity / "more like this" | **CLOSE as delivered.** Shipped and on by default: `sharedPersons` 0.7, `sharedSubjects` 0.5, with two further axes available at 0. |
| **P12** — VIAF/Wikidata enrichment | **CLOSE as delivered offline**, not "defer". The links already render from the bundled authority index; the only unshipped part is the live fetch, which the offline-first posture refuses anyway. |

---

## 1. The census, re-run

The Tier-E recon ran a census; this re-ran it rather than inheriting it, over 694 files in the
local corpus. **The load-bearing claims hold exactly**, and one design premise does not.

| | Recon | Re-measured | |
|---|---|---|---|
| `<placeName>` elements | 331,639 | **331,300** | 0.1% apart |
| …inside `<dateline>` | 99.91% | **99.91%** | exact |
| Volumes carrying any | 551 | **551** | exact |
| Carrying an identifying attribute | none | **none** | confirmed — 546 have any attribute at all, and they are `type`, `rendition`, `rend`, `ana`. Not one `ref` or `key`. |
| Distinct surface strings | 10,417 | **10,970** | see §2 |
| Top 500 coverage | 93.2% | **92.4%** | see §2 |

**The most consequential sentence in the recon survives**: 99.91% of place names sit inside
datelines, so what is harvestable is *where a document was written*, not what it is about.

---

## 2. The premise that did not survive, and the fix

The recon proposed "a hand-curated toponym reconciliation table … covers the corpus at a few
hundred rows", citing Constantinople 2,123 / Peking 5,932 / St. Petersburg 1,132.

**Those are substring counts. The surface form is frequently composite, and the exact-surface
counts are several times smaller:**

| Surface | Exact | Distinct surfaces containing it |
|---|---|---|
| `Constantinople` | **620** | **64** — e.g. `Legation of the United States,Constantinople` (921) |
| `Peking` | **3,294** | **87** — e.g. `Legation of the United States,Peking` (933) |
| `St. Petersburg` | **146** | **65** — e.g. `Legation of the United States,St. Petersburg` (408) |

**19.6% of occurrences carry a comma**, and the composite bundles an *institution* with the place:
`American Embassy`, `Legation of the United States`, `Department of State`. A table keyed on exact
surface would need thousands of rows and would still miss the tail.

### Normalisation rescues the conclusion — and it is one rule

Take the segment after the last comma, collapse whitespace, strip trailing punctuation:

| Keyed on | Distinct | top 100 | top 300 | top 500 |
|---|---|---|---|---|
| Raw surface | 10,970 | 81.9% | 90.0% | 92.4% |
| **Last-segment head** | **4,274** | **90.6%** | **96.4%** | **97.6%** |

**A 300-row curated table reaches 96.4%** — so the recon's "a few hundred rows" is right, but only
with a normalisation step it did not identify. Without it the same table reaches 90.0%, and the
misses are concentrated in exactly the renamed cities the requirement is about.

The normalisation also reconciles the two censuses: Constantinople 620 → **2,106** normalised
against the recon's 2,123; Peking 3,294 → **5,681** against 5,932. The recon's figures were
substring counts that happened to approximate the post-normalisation truth — right in magnitude,
obtained by a method that would have mis-designed the table.

**Three spellings of one dateline are live in the data** and must be folded before curation:
`Department of State,Washington` (10,490), `Department of State, Washington` (4,262),
`Department of State, Washington,` (3,312) — differing only in a space and a trailing comma.

---

## 3. P8 — do not build it from place mentions

`Washington` is **155,329 of 331,300 normalised occurrences — 46.9%.**

Nearly half the corpus's dateline geography is one city, because FRUS prints the Department's own
outgoing instructions beside incoming despatches. A "regional attention" chart drawn from this
source would show, correctly and uselessly, that the State Department is in Washington.

That is not a presentation problem a caveat fixes. P8 asks for *content* attention — what the
record is **about** — and the 0.09% of place names outside datelines is the only part of this
source that speaks to it. **P8 needs a different source**, and the honest candidates already ship:
`volume-subject-profiles-index.json`'s subject vocabulary, and the volume tag taxonomy. Neither is
geography, which is the point: the app should not offer a geography chart it cannot honestly draw.

*If* a geographic surface is wanted before P10, the interim form is **volume-tag based** — coarse,
already bundled, and about subject rather than origin.

---

## 4. P10 — build it, under an honest name

**Ship it as document origin, not country attention.** "Where the record was written" is a real and
publishable question: it traces the shift from legations reporting to Washington instructing, and
the Peking → Peiping → Beijing sequence is visible in it. "Country attention" is a claim about
subject matter that this table cannot support.

### What it costs

Extraction is nearly free. `placeName` appears **nowhere in the Swift source today**; the parser
needs one `case "placeName"`, the AST one case, and an extractor beside `extractDateline` — which
currently flattens the dateline into a string, discarding the structure this needs.

**The name-at-date pairing is free**: the authoritative `<date @when>` sits in the same dateline as
the place, so `(surface, date_iso, resolved_place_id?)` needs no inference.

### The schema, sketched

```
place_mentions(
    volume_id     TEXT NOT NULL,
    document_id   TEXT NOT NULL,
    surface       TEXT NOT NULL,   -- as printed, era-correct: "Peiping"
    head          TEXT NOT NULL,   -- normalised per §2: the curation key
    place_id      TEXT,            -- resolved stable identity, NULL when uncurated
    date_iso      TEXT,            -- the dateline's own @when
    PRIMARY KEY (volume_id, document_id, surface)
)
```

**`surface` and `place_id` are separate columns and neither may be dropped.** The surface is what
the editors printed and what a citation must quote; the identity is what a chart must group by. A
`person_mentions` mirror is impossible here — that table keys on TEI-supplied refs, and no
`placeName` in this corpus carries one.

**`place_id` is nullable, and that is the honest design.** 4,274 heads against a ~300-row curated
table leaves a long tail unresolved. A NULL says *this place was named and not reconciled*; a
guessed identity says something false. Every surface reading this table must show the unresolved
count, the way the map's coverage caveat shows its 88,207 unclustered documents.

### The toponym table

Its own bundled artifact, per the curated-resolutions rule — `curated-lot-resolutions.json` is the
precedent, and so is its posture: **curated against measured surface forms, never derived from a
harvest.** That is the direct answer to the house gazetteer anti-precedent (the NARA
creator-gazetteer trap, measured at 56% precision): this table is a few hundred rows a historian
wrote, checkable by eye, not thousands a matcher guessed.

Shape: `head → { place_id, display_name, names: [{ name, from?, to? }] }`. The era bounds are what
make it a *toponymy* table rather than a synonym list — `Peiping` is not merely another word for
Beijing, it is the name used 1928–1949, and a chart that renders it as "Beijing" erases the
Nationalist capital move that makes the rename meaningful. **2,961 occurrences of `Peiping` are in
this corpus**, and the recon did not mention it.

### The bump

`currentDateIndexVersion` is **47**; W-1b spent 46 → 47. P10 needs **48**, and it is a full
re-index for every user, so it should carry any other pending parse-output change with it.

---

## 5. P11 and P12 — both already delivered, and the plan says otherwise

**P11 is closed, not postponed.** The recon said "largely delivered"; measured, it is delivered and
*on*: `SimilarityModel` default weights are `sharedPersons` **0.7** and `sharedSubjects` **0.5**,
with `semanticSimilarity` and `lexicalSimilarity` shipped at 0.0 as opt-in experiments. The
per-document "more like this" affordance P11 describes exists. Nothing is owed but the row's
closure.

**P12 is delivered offline, and "defer" mis-describes it.** `PersonAuthorityIndex` already exposes
`viafURL` and `wikidataURL` from the bundled index, and they render today. P12's residue is the
**live fetch** — and the plan's own reason for postponing it ("to keep the scheduled work fully
on-device/offline-first") is a reason never to build it, not a reason to build it later. Close it as
*delivered offline; live enrichment refused*, or narrow it explicitly to an on-demand tap.

---

## 6. Recommended sequence, if P10 proceeds

1. **Owner curates the top 300 normalised heads** → `place_id` + era-bounded names. The measurement
   in §2 is the input; nothing is blocked on code.
2. **Parser + AST + extractor** — one case each, and `extractDateline` gains a structured sibling
   rather than being replaced.
3. **`place_mentions` + the v48 bump**, carrying any other pending parse change.
4. **One surface**, and the honest one is *document origin over time*, not a map.

**What would change this verdict.** If a future TEI drop carried `@ref` on `placeName`, the
identity problem dissolves and the curated table becomes a fallback rather than the mechanism —
worth re-checking at each corpus refresh, since it is one grep. And if the 0.09% of body-text place
names ever grows materially, P8's content question reopens on this source; today 305 occurrences
corpus-wide cannot carry a chart.
