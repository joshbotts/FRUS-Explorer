# NARA Record Group Catalog Harvester — Runbook

`RecordGroupCatalogGenerator` builds an offline index of **all available description data** for the
file series in 22 foreign-affairs record groups, with **creator information** and the **complete,
unfiltered set of variant control numbers** as its two priority payloads.

Record groups: 43, 59, 63, 76, 84, 169, 182, 208, 229, 239, 256, 268, 278, 286, 306, 353, 383, 420,
466, 469, 486, 490 — State's own two groups (59, 84), the negotiating and claims commissions
(43, 76, 239, 256, 268, 278), the wartime information and economic-warfare agencies
(63, 169, 182, 208, 229), the Cold War information/aid/arms-control apparatus
(286, 306, 353, 383, 466, 469, 490), and two later trade-and-investment finance agencies (420, 486).

---

## 1. It needs no API key

The harvest reads NARA's **public S3 bulk export**, not the v2 search API:

```
https://nara-national-archives-catalog.s3.us-east-2.amazonaws.com/
    descriptions/record-groups/rg_<N>/rg_<N>-<1…400>.jsonl
    authority-records/{organization,person}/<kind>-<1…400>.jsonl
```

Public, unauthenticated, listable. Each line is one JSON object shaped `{"record": { … }}` — the same
object the live API returns at `_source.record`.

Three reasons this beats the API for this job, in order of weight:

1. **No `CATALOG_API_KEY` and no quota.** The v2 API rejects unauthenticated requests and its
   documented allowance is 10,000 queries/month. The bucket has neither constraint, so this tool
   could be built *and verified end-to-end* before hand-off rather than shipped on faith.
2. **Every level of description in one pass.** The shards interleave series, file units and items, so
   "add file units for record group X later" is a filter change — not a second harvest design.
3. **It carries its own completeness check.** Each group's `recordGroup`-level record has a
   `seriesCount` field: NARA's own expected total. A truncated harvest is therefore self-detecting
   without any external table. Verified on RG 486 (`seriesCount: 11`, exactly 11 series in the
   shards) and RG 420 (`seriesCount: 31`, exactly 31).

The cost is **bandwidth**. Series are scattered evenly through every shard rather than gathered at the
front (measured: RG 59 shards 1, 200 and 400 each hold 7–10 series per 3 MB), so a series-only
harvest still streams the whole group. The objects are not gzipped.

| Record group | Shards | Total bytes |
|---|---|---|
| 59 (State) | 400 | **17.2 GB** |
| 84 (Foreign Service Posts) | 400 | 771 MB |
| 306 (USIA) | 400 | 437 MB |
| 208 (OWI) | 400 | 76 MB |
| 420 | 232 | 792 KB |
| 486 | 12 | 37 KB |

All 22 groups total roughly **22 GB**, of which RG 59 is 17.2 GB (item-level records carry OCR
text). Nothing is retained but the matched records, so peak disk is the artifact, not the download.

The snapshot in place as of 2026-07-29 is dated **2026-04-09**; the exact `Last-Modified` per group is
recorded in `manifest.json` under `source.snapshotLastModified`.

---

## 2. Run it

All commands from the repo root. Prefix with
`export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` if `swift` picks the wrong toolchain.

### Step 0 — build and test (offline)

```bash
swift build -c release --target RecordGroupCatalogGenerator
swift test --filter RecordGroupCatalogGeneratorTests
```

### Step 1 — the cheap probe. One shard per record group, censuses only, no index.

```bash
PROBE=1 GENERATED_DATE=$(date -u +%F) swift run -c release RecordGroupCatalogGenerator
```

A few MB total. It answers the only question that could invalidate the whole harvest: are `creators`
and `variantControlNumbers` really present, under those names, in *these* record groups.

Probe output lands under `OUTPUT_DIR/probe/`, deliberately separate: it describes one shard per group,
and writing it beside a real harvest would overwrite that harvest's manifest, censuses and report with
a tiny sample. Each probed group's `state` is `partial`, never `complete`.

**Go / no-go:** the report's `FIELD ALIAS REPORT` block must show `creators=<n>` and
`variantControlNumbers=<n>` with no `*** NO ALIAS MATCHED ***` banner. If a banner appears, stop and
send back `census/field-census.csv` — the key name has moved and `RecordProjector.aliases` needs one
line changed. Nothing else needs re-running: see step 5.

### Step 2 — a small real group, to see the whole pipeline finish

```bash
RECORD_GROUPS=486,420 GENERATED_DATE=$(date -u +%F) swift run -c release RecordGroupCatalogGenerator
```

**Go / no-go:** `delta` is `0` for both groups in the per-record-group table (harvested series ==
NARA's own `seriesCount`).

### Step 3 — everything except RG 59

RG 59 is 17.2 GB on its own; do the other 21 groups first so a bandwidth surprise costs less.

```bash
RECORD_GROUPS=43,63,76,84,169,182,208,229,239,256,268,278,286,306,353,383,420,466,469,486,490 \
  GENERATED_DATE=$(date -u +%F) swift run -c release RecordGroupCatalogGenerator
```

Interruptible: every shard is checkpointed, so re-running the identical command resumes rather than
starting over. To bound a session, add `MAX_BYTES=2000000000` (2 GB) — the run stops cleanly, writes
its checkpoints, and **exits 0**; re-run to continue.

### Step 4 — RG 59

```bash
RECORD_GROUPS=59 GENERATED_DATE=$(date -u +%F) swift run -c release RecordGroupCatalogGenerator
```

### Step 4a — consolidate. **Required after any subset run.**

```bash
PROJECT_ONLY=1 GENERATED_DATE=$(date -u +%F) swift run -c release RecordGroupCatalogGenerator
```

The run-wide artifacts — `manifest.json`, all five census CSVs, `series-sample.json`, the report — are
rewritten from **the groups in the current invocation**. Per-group index shards are not, so steps 3
and 4 leave a manifest describing RG 59 alone while the other 21 shards sit correct but undescribed.
A subset run says so in its own review notes.

This offline pass rebuilds the run-wide artifacts over every group from the raw stores. No network, no
re-download. Do it last, and after any later per-group re-harvest.

### Step 5 — creator authority enrichment (optional, adds ~155 MB)

```bash
CREATOR_AUTHORITY=1 GENERATED_DATE=$(date -u +%F) swift run -c release RecordGroupCatalogGenerator
```

Resolves every `creators[].naId` against NARA's authority records, adding `administrativeHistoryNote`
(the statutory basis, the reorganisations, the successor agency), the full name-succession chain,
jurisdictions and program areas. The pass stops as soon as every wanted creator is found.

### Re-projection after any correction — free, offline

```bash
PROJECT_ONLY=1 GENERATED_DATE=$(date -u +%F) swift run -c release RecordGroupCatalogGenerator
```

No network. Rebuilds the index and every census from the stored raw NDJSON.

---

## 2a. Refreshing from the API (needs your key)

The bulk export is a **snapshot** (2026-04-09 at the time of writing; the AWS open-data registry lists
the bucket as republished roughly twice a year). The API refresh re-pages the live catalog and diffs it
against the snapshot-derived store.

### There is no "changed since" delta, and that is fine

A census of 513 real records found **no `modified`, `updated`, `version` or `created` field anywhere**
in the description payload. So an incremental delta is not expressible — there is nothing to filter on.

The arithmetic makes that a non-problem. The series layer across the 22 groups is ~20,126 records:
roughly **40 calls at `limit=1000`, ~250 at `limit=100`**, against a documented 10,000/month quota. So
the refresh simply re-pages and diffs. That is strictly better than a date filter would have been,
because it also detects **withdrawals** — records that have vanished — which a "changed since" query
structurally cannot report.

### Step R1 — the survey. A handful of calls. Run this first.

```bash
CATALOG_API_KEY=<key> API_SURVEY=1 GENERATED_DATE=$(date -u +%F) \
  swift run -c release RecordGroupCatalogGenerator
```

Nothing about the live query shape has been verified — this tool was built without a key. The survey
prints a `=== PASTE THIS BACK ===` block answering the four open questions:

1. **The envelope path.** The repo's own two clients disagree (`body.hits.hits` vs a v1-style
   `opaResponse.results.result`), so the client *probes* three candidates and reports which matched.
2. **Which `sort` element is the cursor.** NARA's published example is `[83.65058, "417180915"]` — a
   relevance score followed by the identifier. This client takes the **last** element and prints the
   full array plus its arity, with a warning when arity ≥ 2.
3. **Whether `limit` is honoured** or silently clamped — requested vs returned.
4. **Whether `q` is required.** The spec marks it required; NARA's own scripts omit it. The client omits
   it, and on a 400 retries once with `q=*` and says so loudly — a permissive `q` changes relevance
   scoring and therefore the `sort` array, which interacts with (2).

Send that block back and the query shape gets corrected before any real spend.

#### What the 2026-07-30 survey established

Run against RG 486, and it settled all four questions:

| Question | Answer |
|---|---|
| Envelope | `body.hits.hits` → `_source.record`. Top-level keys: `body`, `headers`, `statusCode`. |
| `q` required? | **No.** A q-less request returned HTTP 200. |
| RG + level filter | **Works.** `totalHits: 11` for RG 486 series — matching the bulk export's 11 exactly. |
| `limit` clamped? | Unanswerable from RG 486 (only 11 records). The survey now adds one probe against RG 59. |

It also exposed a **paging bug**, which is the real value of having run it. Page 1 returned all 11 hits
and page 2 returned **3 more** — 14 records from a result set of 11. The sort arity is the tell:

```
page 1  sort [14.285818, 32161988]   arity 2   ← relevance-scored
page 2  sort [22345695]              arity 1   ← naId-ordered
```

The first request was **relevance-sorted** while every later one was **naId-sorted**, so the naId taken
from page 1's last hit was not a valid cursor. Fixed three ways:

1. `searchAfter` is now sent on **every** request, seeded `*` on the first — matching the repo's proven
   `NARACatalogHarvestClient`, which enumerated 1,241 rolls this way. That forces one consistent
   ordering for the whole sequence.
2. Records are **de-duplicated by NAID across pages**, and duplicates are counted and logged. This
   matters beyond tidiness: a duplicate pushes the count *past* NARA's own total, and the completeness
   check only tests for a shortfall, so it would otherwise pass unnoticed.
3. Paging **stops at `totalHits`**. Knowing the total is what makes an overlapping page sequence
   terminable.

The survey now also reports whether the seed actually produced a consistent page-1 ordering, so a
re-run confirms the fix rather than assuming it.

#### The re-run confirmed it, and settled the last question

```
page 1  sort [22345695]  arity=1   ✓ the seed produced a consistent ordering
page 2  0 hits                     ← correct end-of-results
RG 59   limit=1000 → 1000 hits, totalHits 4449   ✓ limit=1000 is honoured
```

So **`API_PAGE_SIZE` now defaults to 1000**, which is a 10× reduction in calls against the quota.

Two of the re-run's warnings were bugs in the *report*, not the data, and are fixed: an empty
terminator page has no hits to locate a record inside (so `recordPath` was reported as
`*** NOT FOUND ***`), and it has no sort array at all (so arity `1 → 0` was flagged as unstable
ordering). Both now read as end-of-results. Arity is compared only across non-empty pages, and
`totalHits` is used to tell genuine clamping from "that is all there is".

#### Measured API costs, now that `limit=1000` is proven

| Layer | Records | Calls at `limit=1000` |
|---|---|---|
| RG 59 series | 4,449 (live) | 5 |
| All 22 groups, series | ~20,100 | **~40** |
| RG 59 file units | ~230,000 (est.) | ~230 |

Against a 10,000/month quota, the entire series layer costs ~40 calls. The live RG 59 series count
of 4,449 is a useful cross-check against the 4,435 derived from NARA's Record Group Explorer — the
catalog has grown slightly since that snapshot, which is precisely the drift the refresh exists to
surface.

#### One thing still unverified: whether search responses are field-complete

The bulk export is known field-complete; whether the *search* API returns every field is not
established. The refresh answers it for free, because it diffs raw trees: if nearly every record
comes back `modified`, that is field-thinning rather than real change. A 2-call experiment settles
it against a group already harvested from bulk:

```bash
CATALOG_API_KEY=<key> API_REFRESH=1 RECORD_GROUPS=486 swift run -c release RecordGroupCatalogGenerator
```

#### It was run, and the answer is: the API is field-complete

RG 486, 2026-07-30 — and the first result looked alarming: **`modified=11, unchanged=0`**. Every record
differed. Per the guidance above that reads as field-thinning, so the two raw stores were diffed
field-by-field (both were already on disk, so this cost nothing):

- Keys only in bulk: **none**. Keys only in the API: **none**. The API is **not** thinning fields.
- Values differing, on all 11 records, in exactly two places:
  - `dataControlGroup.groupCd`/`groupId` — `RRAT` in the April snapshot, `RRAR` from the live API,
    with `groupName` identical. An internal reference-unit code that genuinely changed.
  - `physicalOccurrences[].referenceUnits[].mailCode` — present in bulk (`"RR2"`), omitted by the API.

**Neither is a field this index projects.** So the raw-tree comparison was flagging the entire corpus
over data nobody reads, and would have done so on every refresh forever — burying any real change in
noise. Fixed by classifying on what matters: `RecordChange.unchangedOutsideIndex` now separates
incidental drift from real change, and `hasChanges` ignores it. Re-classified offline against the same
stores, RG 486 now reports:

```
API REFRESH vs BULK SNAPSHOT
  no indexed field changed — the snapshot matches the live catalog for these groups
  11 record(s) differed outside the indexed fields only — incidental
  catalog housekeeping (dataControlGroup's internal code, referenceUnits[].mailCode).
```

Note the asymmetry that remains genuinely useful: a **new** unprojected key still counts as
`modified`, because `unprojectedKeys` is itself an indexed field. Drift in a key we already know about
is noise; a key NARA has just started emitting is news.

**Practical consequence:** either source gives a field-complete series index, so the API route is
available for the initial harvest too — ~40 calls and a few MB instead of streaming 22 GB. The bulk
path remains the only keyless route, and the only one that carries `mailCode` and the file-unit/item
layers without further paging.

`PROJECT_ONLY=1` now also re-classifies against a refresh already in `raw-api/`, so correcting *how*
changes are judged never costs another API call — the same principle the rest of the design rests on.

### Step R2 — the refresh

```bash
CATALOG_API_KEY=<key> API_REFRESH=1 GENERATED_DATE=$(date -u +%F) \
  swift run -c release RecordGroupCatalogGenerator
```

Per record group, this pages the live API into `CACHE_DIR/raw-api/`, overlays it on the snapshot store
(the API wins by `naId`), and writes `census/refresh-changelog.csv` classifying every record:

| Change | Meaning |
|---|---|
| `added` | In the refresh only — new since the snapshot. |
| `modified` | In both, and the **raw** record differs (so a change to a field this tool does not project still counts). |
| `unchanged` | Identical. Counted, not enumerated. |
| `missingFromRefresh` | In the snapshot, absent from the refresh. |

`missingFromRefresh` is deliberately **not** called "withdrawn": a record can be absent because NARA
removed it, or because the refresh query was narrower or hit a request ceiling. The tool cannot tell
those apart and does not pretend to.

Three guards worth knowing about, each of which exists because the failure would otherwise be quiet:

- **An empty refresh is discarded, not merged.** Zero refresh records over a populated snapshot would
  classify *every* record as `missingFromRefresh` and read as the catalog having been emptied — when
  the likeliest cause is a wrong query shape. Such a group keeps its snapshot index and gets a review
  note.
- **A refresh failure leaves the snapshot index intact**, with a note. A bad refresh never costs you
  the 22 GB harvest.
- **The refresh pages each admitted level separately.** An unfiltered refresh of a
  `seriesAndFileUnits` group would page every level including items — hundreds of thousands of records
  for RG 59 — and exhaust the request ceiling before reaching the file units. Per-level paging also
  keeps the refresh's coverage identical to the snapshot's, which is what makes `missingFromRefresh`
  meaningful.

`MAX_API_REQUESTS_PER_GROUP` (default 200) is a hard per-group ceiling, so a paging bug cannot drain
the monthly quota. A non-advancing cursor throws rather than looping.

### Later — file units for chosen record groups

```bash
DEPTH_OVERRIDES=486:seriesAndFileUnits,420:seriesAndFileUnits REFRESH=1 \
  RECORD_GROUPS=486,420 GENERATED_DATE=$(date -u +%F) \
  swift run -c release RecordGroupCatalogGenerator
```

`REFRESH=1` is required and the tool will tell you so: a `series` checkpoint records shards read with
the shallower filter, so resuming a deeper run on top of it would silently omit every file unit in
those shards. Measured on RG 420: series-only gives 31 records, `seriesAndFileUnits` gives 31 + 325.

Only the named groups' shards are re-read; the others keep their existing index files.

---

## 3. Environment contract

| Variable | Default | Effect |
|---|---|---|
| `RECORD_GROUPS` | the 22 groups | Comma-separated group numbers. |
| `DEPTH` | `series` | `series`, `seriesAndFileUnits`, `all`. A typo throws rather than degrading. |
| `DEPTH_OVERRIDES` | — | `<rg>:<depth>` pairs. Naming an unselected group throws. |
| `OUTPUT_DIR` | `Planning/nara-record-group-catalog` | Artifact root. |
| `CACHE_DIR` | `.cache/nara-rg-catalog` | Raw NDJSON store + checkpoints. |
| `PROBE` | off | One shard per group; censuses only, no index. |
| `PROJECT_ONLY` | off | Offline rebuild from the raw store. |
| `CREATOR_AUTHORITY` | off | Resolve creator authority records. |
| `REFRESH` | off | Discard store + checkpoints and re-harvest. |
| `MAX_BYTES` | unlimited | Byte budget; exceeding it checkpoints and exits 0. |
| `SAMPLE_EVERY` | `25` | Sampling interval for the committed record sample. |
| `ALLOW_SHORT` | off | Do not fail on a group short of NARA's `seriesCount`. |
| `API_SURVEY` | off | Spend a handful of API calls answering the open query-shape questions. Needs `CATALOG_API_KEY`. |
| `API_REFRESH` | off | Re-page the live API and overlay it on the snapshot, emitting a changelog. Needs `CATALOG_API_KEY`. |
| `CATALOG_API_KEY` | — | Only used by the two API modes. The bulk harvest never reads it. |
| `API_PAGE_SIZE` | `1000` | `limit` per API request. 1000 is survey-proven honoured (RG 59 returned exactly 1000). |
| `MAX_API_REQUESTS_PER_GROUP` | `200` | Hard per-group request ceiling. |
| `BASE_URL` | NARA's bucket | Origin override (tests). |
| `GENERATED_DATE` | today (UTC) | Reproducible `generated` stamp. |

**Exit code** is non-zero when the harvest cannot be trusted: a priority field matched nothing
anywhere, a checkpoint was refused, or a group came in materially short of NARA's own count without
`ALLOW_SHORT`. A budget stop exits **zero** — that is a successful partial harvest.

---

## 4. Artifacts

Written under `OUTPUT_DIR`:

| File | Committed | What it is |
|---|---|---|
| `manifest.json` | yes | Provenance, per-group summaries, the alias report, review notes. |
| `harvest-report.txt` | yes | The human read: completeness, priority-payload coverage, review blocks. |
| `census/field-census.csv` | yes | **Every** key path observed, with counts, types and examples. |
| `census/value-census.csv` | yes | Value vocabularies, with the record groups each value appears in. |
| `census/control-number-types.csv` | yes | Control-number types ranked, with record-group spread. |
| `census/control-number-census.csv` | yes | The `(type × note × record group)` cross-tab. |
| `census/creator-census.csv` | yes | Every creator, its record count and its record-group spread. |
| `series-sample.json` | yes | Every 25th record — the shape, reviewable in a diff. |
| `creators/creator-authority.json` | yes | Resolved creator authority records with admin history. |
| `census/refresh-changelog.csv` | yes | The bulk-vs-API diff, per record (API refresh only). |
| `series/rg_<N>.json` | **no** | The index proper. ~165 MB across 22 groups; gitignored. |

`.gitignore` excludes `Planning/nara-record-group-catalog/series/`, matching the precedent of
`Planning/source-explorer-export/source-explorer-export.json` (182 MB, regenerated not committed).

### The raw NDJSON is not scratch

`CACHE_DIR` sits under `.cache/`, which `.gitignore` describes as regenerable harvest scratch. True of
the bytes — but regenerating them costs the entire 22 GB download again, and they are:

1. the **resume state** for an interrupted harvest, and
2. the **only** source for `PROJECT_ONLY` re-projection.

Deleting it turns a one-line schema correction from a seconds-long offline rebuild back into a full
re-download. Keep it until the index is settled.

---

## 5. What the first live run established

Recorded here because these are measured facts about NARA's data, not design choices, and the next
person to touch this should not have to rediscover them.

### `creators` — the verified shape

```json
"creators": [
  { "naId": 10514123,
    "heading": "U.S. International Development Cooperation Agency. Trade and Development Program. (07/01/1980 - 10/27/1992)",
    "authorityType": "organization",
    "creatorType": "Predecessor",
    "establishDate": { "day": 1, "logicalDate": "1980-07-01", "month": 7, "year": 1980 },
    "abolishDate":   { "day": 27, "logicalDate": "1992-10-27", "month": 10, "year": 1992 } }
]
```

`authorityType` is `organization` | `person`; `creatorType` is `Most Recent` | `Predecessor`. A person
carries `birthDate`/`deathDate` where an organization carries `establishDate`/`abolishDate`. Present
on 11 of 11 series in RG 486.

None of `creatingOrganization`, `creatingOrganizationArray`, `creatingIndividual`,
`organizationalContributors`, `personalAuthors` is a JSON key — several are titles of components in
NARA's OpenAPI document, which is not the same thing.

### The creator → authority join is **not** `naId == naId`

The important finding, and the one that would have shipped an empty enrichment silently. All three of
RG 486's creator NAIDs — 10514123, 10514124, 475680186 — appear **nowhere** among the 63,535 top-level
records in NARA's organization authority export. Each is instead a nested `organizationNames[].naId`
inside a *different* parent authority record (10566287, 10566288, 475680185 respectively).

NARA's model is that one authority record holds an entity's whole succession of names, each name
carrying its own NAID, and a description record cites **the name in force when the records were
created** — not the entity. The join must therefore consider nested names;
`CreatorAuthorityRecord.resolvedVia` records which way each match was made.

The first run of this tool reported `0 resolved, 3 unresolved`, which is what sent us looking. That
report line existing at all is the reason the bug was found rather than shipped.

### `variantControlNumbers` — and why nothing is filtered

Exactly three keys: `number`, `type`, and an optional free-text `note`. `type` is occasionally absent
entirely.

**`type` is an open vocabulary and cannot be switched on exhaustively.** More importantly, State
Department lot-file numbers are recorded under **both** `"State Department Lot File Number"` **and**
the entirely generic `"Agency-Assigned Identifier"`, distinguishable in the second case only by the
free-text `note`, which itself appears in several spellings. Any filter written against `type` alone
loses a large share of exactly the numbers a researcher wants.

So all three strings are stored verbatim, unfiltered and unnormalised, and
`census/control-number-census.csv` reports the observed cross-tab. `noteClass` is an *additional*
column beside the raw note, never a replacement for it.

Observed in RG 486 alone: `HMS/MLR Entry Number`, `HMS Record Entry ID`,
`Declassification Project Number`. The full corpus inventory is what
`census/control-number-types.csv` is for, and its `recordGroups` column is what makes
"agency-specific" answerable — a type confined to one group is specific to that agency's records; one
spread across twenty is a NARA-wide vocabulary term.

### Three fields were being dropped or mislabelled, and a live check found them

All three were caught by reviewing the projection against real bytes rather than against NARA's
documentation, and all three were silent — the index simply had less in it than it appeared to.

- **`securityClassification` is nested one level deeper than it reads.** It is a member of the
  *elements* of `accessRestriction.specificAccessRestrictions[]`, alongside `restriction` — not a
  member of the `accessRestriction` block. Measured: 27 of 513 sampled records carry one, always
  nested. Reading it at block level returned `nil` for every record ever harvested. The field is now
  `securityClassifications` (plural, because the specifics are an array) and a live run over RG
  486 + 420 recovers `Confidential`, `Secret` and `Top Secret`.
- **The two restriction blocks are shaped differently.** `specificAccessRestrictions[]` holds objects
  keyed `restriction`; `specificUseRestrictions[]` holds **bare strings**. A census path written
  `useRestriction.specificUseRestrictions[].restriction` therefore reported nothing at all.
- **`findingAids` uses `findingAidType`, not `type`.** The generic list flattener was given
  `["note", "type", "source"]`, so the *kind* of finding aid was never captured, and any entry without
  a `note` fell through to `source` and stored the holding institution's name as though it were the
  finding aid. `findingAids` is now a struct; a live run recovers `Folder List`, `Container List` and
  `Item List` on 32 of 32 entries.

### Six more fields were in the data but not in the index

Found by the unprojected-key tripwire during the API-delta investigation, not by design — which is
what that machinery is for, though being visible in a census is not the same as being in the index:

- **`contributors`** — the same shape as `creators` but carrying `contributorType`. Measured
  vocabulary in RG 208/306: `Sponsor`, `Distributor`, `Producer`, `Artist`, `Co-producer`, `Compiler`,
  `Host`, `Speaker`. Near-absent from the textual State groups and common in the audiovisual agencies,
  where the producer is the agent a researcher actually wants. Projected and enriched alongside
  creators; `CatalogCreator.role` reports whichever discriminator applied.
- **`localIdentifier`** (e.g. `"59.83"`) — an agency-assigned identifier that is **not** part of
  `variantControlNumbers`, so no control-number query would ever surface it.
- **`fileUnitCount` / `itemCount`** — NARA's own child counts. The `seriesCount` completeness device one
  level down, so a `seriesAndFileUnits` pass can now check itself; the report prints
  harvested-vs-stated per group.
- **`productionDates`**, **`onlineResources`** (off-site digitisation NARA records but does not host),
  **`soundType`**.
- **`digitalObjects`** — projected for `objectUrl`/`objectType`/filename/size, with a `hasExtractedText`
  flag. The OCR text itself is deliberately excluded: it is what makes RG 59's shards 17.2 GB, and a
  full-text corpus is a different artifact.
- **`formerAncestors` / `formerlyContainedBy`** — one of RG 420's 31 series was formerly filed under
  **RG 286**. That is provenance a researcher tracing records across an agency reorganisation needs.
  Note these are deliberately *not* consulted by the record-group invariant: attribution reads
  `ancestors` only, so a former parent cannot make a record look like it belongs elsewhere.

### Other measured facts

- `recordGroupNumber` appears **only** on the `recordGroup`-level ancestor, never on the record
  itself. Attribution therefore reads the ancestor chain, and a record whose chain has no
  `recordGroup` is **refused** rather than credited to whichever group's shards it turned up in —
  the generalisation of this repo's #321 lesson, where accepting such records scored 0/16.
- `availableOnline` is a query parameter and an aggregation bucket only. It is **never** a field on a
  record, so digitization is inferred from `digitalObjectCount`.
- `audiovisual` is a **quoted string** of varying case: `"false"` in RG 486, `"True"` in NARA's own
  published example. A literal `== "true"` comparison reads one of the two as null.
- `holdingsMeasurements[].count` is written as a float (`1.0`, `13.0`) even for discrete boxes.
- There are no `topicalSubjects` / `geographicReferences` keys; all authority kinds are folded into
  one `subjects` array discriminated by `authorityType`.
- `ancestors` arrives **farthest-first** — a file unit's chain is
  `[(distance 3, recordGroup), (distance 2, series), (distance 1, fileUnit)]`, so the immediate parent
  is last. The array is preserved in NARA's order; read `distance`, not position.
- `dataControlGroup` is present on every series and is deliberately not projected (it names the
  holding reference unit, already captured under `physicalOccurrences[].referenceUnits`). It appears
  in the report's `UNPROJECTED RAW KEYS` block, which is where a *new* NARA field would also appear.

---

## 6. If a priority field ever comes back empty

The whole design funnels this case into one cheap loop:

1. The run **fails** with a message naming the field — it does not write a plausible index with the
   data missing.
2. `census/field-census.csv` reports the key path that actually exists.
3. Add that spelling to `RecordProjector.aliases` (canonical name first).
4. `PROJECT_ONLY=1` rebuilds everything from the raw store. **No re-download.**

A match on a non-canonical spelling is reported in the manifest's alias report, so running on a
fallback is visible rather than silent.
