# AUDIT A — Source Explorer: source-note parsing & shared-collection resolution

*2026-07-03. Data: copy of the user's live frus.db (552 indexed volumes, 316k documents, 6.7 GB); code read from the jovial-bartik worktree (IndexingPipeline.swift, SourceNoteParser.swift, DecimalFileSegment.swift, FRUSDocumentParser.swift SourcesParserDelegate, VolumeSourcesView.swift); TEI mirror ~/Development/frus; ~/Development/frus-sources; ~/Development/citations.csv.*

---

## 1. The trigger, quantified

`volume_sources` (front-matter Sources lists) across the live index:

| | count |
|---|---|
| Volumes with volume_sources rows | 258 of 552 indexed (all 242 modern 1952+ vols + 16 older; pre-1952 volumes mostly lack a Sources section — expected) |
| `kind='item'` rows | **30,388** |
| …carrying a lot-file key | 3,848 (12.7%) |
| …carrying rg+series key (no lot) | 539 (1.8%) |
| …**no usable key → no neighbors button at all** | **26,001 (85.6%)** |

Replaying the app's exact matcher (`archivalNeighbors(forLotFile:recordGroup:series:)` → `relatedByLotFile` 4-variant `IN`, `relatedByCollection` exact rg+series equality) over every keyed item:

| key type | items | >0 neighbors | zero |
|---|---|---|---|
| lot file | 3,848 | 961 (25%) | 2,887 (75%) |
| rg+series | 539 | 81 (15%) | 458 (85%) |

**Net: ~1,042 of 30,388 front-matter source items (3.4%) resolve any archival neighbor today.** Distinct normalized lots: 1,165 in volume_sources vs only 452 on the document side; intersection 63 (5.4%).

### Root-cause buckets — 100 random zero-resolving lot entries

Each sampled entry was traced: (1) compact-normalized against all `document_sources.lot_file` values, (2) against all raw `document_cache.source_note` text, (3) against the text of every `<note type="source">` in the TEI of *indexed* volumes.

| bucket | n | meaning |
|---|---|---|
| **B3 — extraction gap** | **59** | The lot IS cited in `<note type="source">` of an indexed volume, but the note never reached `document_cache.source_note` / `document_sources` (see §2.1) |
| **B2 — doc-note parse gap** | **23** | The raw note IS stored in `document_cache.source_note`, but `SourceNoteParser` failed to extract the lot (see §2.2) |
| C — genuinely uncited | 18 | Collection listed as consulted in front matter but never cited as a document source anywhere in TEI (legitimate empty state) |
| B1 — pure normalization mismatch | 0 | (both sides fail the same ways, so formatting-only mismatches don't survive as a separate class) |
| not-indexed era | 0 | user has effectively the whole corpus indexed |

**82% of zeros are app-side defects; 0% are "user hasn't indexed the era".** Per era: 1952–63 zeros are 33% parse-gap / 56% extraction-gap; 1964+ zeros are almost entirely extraction-gap.

### Post-fix ceiling
Scanning `<note type="source">` text of all indexed TEI for all 1,165 front-matter lots: **781 (67%) are citable; 3,296 of 3,848 lot-keyed items (86%) would resolve >0 neighbors** once extraction + parsing are fixed — vs 25% today.

---

## 2. Where the citation side breaks

### 2.1 THE dominant bug: source notes nested in `<head>` are never extracted
`IndexingPipeline.extractSourceNote(from:)` (IndexingPipeline.swift:2548) scans **top-level AST nodes only** for `.footnote(type: .source)`. Two TEI encodings exist:

- `<div type="document"><note rend="inline" type="source">…</note><head>…` — top-level, **extracted**. Used by 1861–1954 volumes.
- `<div type="document"><head>…<note n="1" type="source">Source: …</note></head>` — nested in `<head>`, **silently dropped**. Used by every volume from **1955 on**.

`document_cache.source_note` coverage proves it:

| era | docs | with source_note |
|---|---|---|
| pre-1906 | 39,619 | 1,082 (3%) — mostly genuine absence ("[Extract.]") |
| 1906–1939 | 94,956 | 90,615 (95%) |
| 1940–1951 | 88,940 | 84,063 (95%) |
| **1952–54 subseries** | 15,249 | 13,714 (90%) |
| **1955–57** | 11,355 | **1** |
| **1958–60** | 9,618 | 73 |
| **1961–63** | 10,543 | 66 |
| **1964–1976** | 33,037 | 222 (0.7%) |
| **1977+** | 12,762 | 59 (0.5%) |

**≈ 77,000 modern documents have no stored source note at all.** Cross-check: the user's own `citations.csv` harvest holds 267,663 source-notes for 520 volumes; the app has ~190k. Knock-on effects: `document_sources.citation_era='structured'` count is **zero** — no `.naraCollection` / `.presidentialLibrary` rows exist anywhere, because the "Source: …" narratives that trigger those parser branches live exactly in the head-nested era. The per-document Archival Neighbors sheet is equally empty for the whole modern corpus, and volume front-matter lots (a 1950s+ phenomenon) have nothing to match against — **this one bug is most of the trigger observation.**

### 2.2 SourceNoteParser gaps on the notes that ARE extracted
57,101 of 191,922 document_sources rows (30%) are `unrecognized`. Sampled by era, the misses cluster into a small grammar:

- **Decimal refs with word/office infixes** (bulk of 1906–51's 50k unrecognized): `893.51 Manchuria/49`, `740.00112 European War 1939/6363`, `500.A15A4 Naval Armaments/153`, `396.1 GE/7–854`, `110.11 DU/5–154`, `123M431/163`, `033.4111MacDonald, Ramsay/141`. `decimalFileRegex` = `^[A-Z0-9]+\.[A-Z0-9]+/[\d–-]+` — dies on any space or word between class and `/`. These are all *valid decimal-file citations* whose location key ("893.51 Manchuria") would segment-match beautifully.
- **Lowercase office-file lot style, comma not colon** (2,349 of 1952–63's 5,515 unrecognized): `OAS files, lot 60 D 665, "Memorandums of meetings"`, `Secretary's Memoranda of Conversation, lot 64 D 199`. `tryInlineLotFile` demands `Files?:\s*Lot\s+` (colon, capital not required but colon is).
- **Lot-leading notes and en-dash lots**: `Lot 71–D 440, Box 19232`, `Marshall Mission Files, Lot 54–D270`. En-dash (–) is never stripped by `lotNumberVariants` (only ASCII hyphen); 185 of 466 distinct stored `document_sources.lot_file` values contain an en/em-dash — a live normalization mismatch *within* the doc side.
- **Presidential library without "Source:" prefix** (652 in 1952–63): `Eisenhower Library, Dulles papers, "Telephone Conversations"` — `parseNarrative` is only entered when the note starts with `Source:`.
- **Named file series**: `IO Files: US(P)/A/351`, `Conference files, CF 292`.
- pre-1906 `[Extract.]` / `No. 18.` — genuinely non-archival; correct to leave unrecognized (pre-1910 story is the Central Files/despatch-numbers program, not this parser).

### 2.3 volume_sources (front-matter) parse gaps — SourcesParserDelegate
- **lot regex is D-designator-only**: `\bLot\s+([\w\s\-]+?D\s*\d+)\b`. Misses all RG-84 embassy-post **F-designator** lots (`Lot 62 F 83`, `Lot 61 F 15`, `Lot 79 F 134`), `Lot W 130`, and run-together text (`Lot 90 D 313Records…` — no `\b` between digit and letter). 507 no-key items literally contain "Lot". The greedy `[\w\s\-]+?` prefix also pollutes captures (`lot="Files 74 D 131"`).
- **No context inheritance down the outline tree.** RG lives on the parent heading (`Record Group 59…`); children (`Central Files 1967–69: POL 27 ARAB–ISR`) get no record_group, no repository, no key. Breakdown of the 26,001 no-key items: 10,212 named collections/series (mostly presidential-library children — for which `makeNeighborsTarget` has **no match path at all**, even though `relatedByPresidentialLibrary` exists for the doc-side), 2,850 decimal/subject-numeric class leaves (`POL 27 ARAB–ISR`, `DEF 6 MLF` — matchable against decimal/CFPF citations if keyed), 2,944 headings, 2,634 bibliography entries (the `listofworks` section shares the table — fine, but they should never look like resolvable "collections"), 6,838 other prose-ish fragments.
- **series_name heuristic is junk-prone** (last comma segment): produces `see National Archives and Records Administration below.`, `1977–1980`, `as maintained by the Executive Secretariat.` — then `relatedByCollection` requires *exact* equality against the doc side. rg+series resolution: 81/539.

### 2.4 Matcher-side weaknesses (real but secondary today)
- Lot matching = literal `IN` over 4 formatting variants; would be a single indexed lookup if both sides stored a normalized compact key (`64D199`) at write time. En/em-dash variants defeat it in both directions.
- `relatedByCollection` exact `series_name` equality is the wrong grain (doc side appends `, Box N`; front-matter side stores heuristic tails).
- No presidential-library path from volume-level entries.
- `relatedByDecimal` is sound (location + `DecimalFileSegment` period) but starves: it only sees `citation_era='decimal'` rows, and the word-infix class in §2.2 never becomes decimal rows.

---

## 3. What ~/Development/frus-sources contributes

The eXist-db app (~10 yrs old, 88 volumes: 63× 1969–76, 21× 1977–80, 4× 1981–88) does two things we should port and one we've outgrown:

1. **The source-note locator recipe** (`import/import.xq`) — priority chain that is exactly the §2.1 fix:
   `head/note/p/seg[@type='source']` → `head/note[@type='source']` (first `<p>` matching `^\[?Source:`) → inline `div/note[matches(.,'^\[?Source:')]`; then strip `[Source: …]` wrapper. It also splits the note by sentence: **sentence 1 = archival citation, sentence 2 = classification markings ("Secret; Nodis"), rest = remarks** — a structure worth storing (classification is a display/search win; remarks pollution is why series_name captures junk).
2. **The reconciliation model** (`import/merge.xq` + `merged/sources.xml`, 34k location nodes): tokenize the citation sentence on `", "` into ordered segments, then **merge cross-volume by leading-segment hierarchy with numeric UCA collation** → a corpus-wide location tree `Johnson Library > National Security File > Country File > …` with per-leaf doc lists. This is the "shared collection reference" authority the zero-neighbor fix ultimately wants: neighbors = other docs under the same subtree, at any chosen depth — strictly more expressive than today's single-key equality.
3. Outgrown: no lot normalization, no NARA NAIDs (our VolumeSourcesIndexGenerator already does that), 88/570 volumes, naive sentence tokenizer. Treat it as a **vocabulary/model quarry, not a dependency**.

**citations.csv / citations2.csv** (1.1M rows, 520 volumes; `source-note` 267,663 / `front-matter-collection` 29,919 / `footnote-archival` 26,512, each with xpath + plain text + TEI) is a ready-made **parser regression corpus**: run SourceNoteParser v2 over all 267k notes offline, diff classification-rate by era per commit.

---

## 4. DRAFT scope skeleton — "Source Explorer: Provenance Rework"

**Goal.** Every archival collection a volume's editors cite — in front matter or in a document's source note — resolves to (a) its NARA identity and (b) the set of indexed documents drawn from it, across volumes. Kill the zero-neighbor lie: an empty result should mean "nothing in your index cites this," not "we failed to parse it."

**Architectural spine.** Store **normalized match keys at parse time** (both sides write the same normal forms: compact lot `64D199`, decimal location, repository authority string); keep **matching dumb at display time** (indexed equality/prefix, no variant fan-out); push **cross-volume authority and NARA identity into bundled generator indexes**. Data-vs-app split:

- *Bundled generators* (SPM, offline): collection authority (alias clusters, lot→NAID via existing VolumeSourcesIndexGenerator cache), era vocabulary (office symbols, subject-numeric classes), parser eval harness over citations.csv.
- *Parse time (IndexingPipeline)*: extraction fix, SourceNoteParser v2, volume_sources keying/inheritance, normalized-key columns. Every phase here **bumps the index version** (house rule).
- *Display time*: matcher reads normalized keys; UI states distinguish "no key" / "key, zero matches" / "matches".

### Phase 1 — Extraction fix (Cheap; the single highest-ROI change in the app)
Port the frus-sources locator chain into `extractSourceNote`: search `<head>`-nested `<note type="source">` (and `p/seg[@type='source']`), strip `[Source: …]`/`Source:` wrappers consistently. Store the full note as today.
- Unlocks ~77k documents (1955–1991). `structured` era rows start existing; per-document Archival Neighbors comes alive for the modern corpus.
- Bump `currentDateIndexVersion` sibling (index schema/parse version) in the same commit.
- *Decision point (cheap now, pays later):* also store classification sentence separately (`classification` column) while touching the row shape.

### Phase 2 — SourceNoteParser v2, era-aware (Moderate)
Grammar upgrades, each backed by the citations.csv eval corpus:
- Decimal refs with word/office infixes (`893.51 Manchuria/49`, `396.1 GE/7–854`) → `.centralFiles` with location = text before `/`.
- Lowercase/comma lot style (`…files, lot 60 D 665`), lot-leading notes (`Lot 71–D 440, Box…`).
- Unicode dash normalization **once, at write time**: store `lot_file_norm` (compact, dash/space-free, uppercase) alongside raw; same normal form written from volume_sources.
- Presidential-library notes without `Source:` prefix.
- Named file series (`IO Files: US(P)/A/351`) → repository + series key.
- **Eval harness in SPM** (`SourceNoteEvalGenerator` or test fixture): classification-rate by era; target unrecognized <10% for 1906–1963, <15% overall; CI-diffable.

### Phase 3 — volume_sources keying & tree inheritance (Moderate)
- Designator-agnostic lot regex (`\d{2,3}\s*[–-]?\s*[A-Z]\s*[–-]?\s*\d+`, F/W/M included) + boundary fix for run-together text.
- Inherit repository / record_group / library down the outline (`depth` tree already exists in the table and in `buildTree`).
- New match paths in `makeNeighborsTarget` + `archivalNeighbors(forLotFile:…)`: presidential-library (repo + collection prefix), decimal-class leaves (`POL 27 ARAB–ISR` → decimal-location prefix match against `citation_era IN ('decimal','cfpf')`).
- Exclude bibliography (`listofworks`) rows from "collection" affordances.
- Matcher: replace 4-variant `IN` with `lot_file_norm =` single lookup; `relatedByCollection` → normalized prefix match on series.

### Phase 4 — Cross-volume collection authority (Expensive; the frus-sources idea, done right)
Bundled `collection-authority.json` (generator: extend VolumeSourcesIndexGenerator): cluster front-matter + citation collections corpus-wide by normalized key and leading-segment hierarchy (merge.xq model); attach NAIDs and alias forms. App gains: "this collection, across N volumes and M documents" from any surface; Source Explorer browse-by-collection tree.
- *Decision point:* segment tree depth — full hierarchical location tree (expensive, frus-sources-style) vs two levels (collection + sub-series) (cheap, probably 90% of the value).
- *Decision point:* whether per-user indexed-doc counts stay purely local (recomputed) vs shipped estimates (probably local — the user's index defines them).

### Phase 5 — UI truth & polish (Cheap)
Three-state neighbor affordance (no key / zero / n); classification chips; wire cross-volume authority into VolumeSourcesView + document Source sheet; docs pass (Docs/ manuals, TestFlight notes, ResearchGuideView, IndexingEducationView — house rule).

### Verification (result-oriented, each phase)
Re-run this audit's queries on a reindexed DB: (a) source_note coverage by era ≥90% for 1955+; (b) unrecognized rate by era; (c) keyed-item resolution rate — Phase 1+2+3 target: lot-keyed items ≥80% resolving (ceiling measured: 86%); (d) the 100-sample bucket re-run should show buckets B2/B3 ≈ 0.

### Explicit non-goals
Pre-1906 despatch-number provenance (separate program: BigPicture-Pre1910-CentralFiles), NARA API live lookups beyond current behavior, retroactive migration of existing DBs without reindex (index-version bump forces reindex; that's the mechanism).

---

## Appendix — reproduction assets (scratchpad)
- `simulate.py` — replays the app's matcher over all keyed volume_sources items.
- `buckets3.py` — the 100-sample root-cause bucketing (incl. TEI `<note type="source">` scan).
- `ceiling.py` — post-fix resolution ceiling.
- `db/frus.db` — the analyzed copy.
