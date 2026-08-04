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

### An API-only harvest keeps its completeness check

Going API-primary had one gap worth closing before recommending it: `levelOfDescription=series`
necessarily excludes the `recordGroup`-level record, and that record is the only place NARA states
`seriesCount`. An API-only harvest would therefore have had **no self-check** — the single best safety
property the bulk path has.

Every refresh now fetches the group node first: **one extra call per group**, ~22 across the set. It
supplies the authoritative title, NAID and `seriesCount`, so `harvested vs stated` works identically on
either route, and a short API harvest fails the run exactly as a short bulk harvest does.

Three details, each because the alternative fails quietly:

- A node whose `recordGroupNumber` does not match the group being harvested is **rejected**, so a fuzzy
  hit cannot supply another group's `seriesCount`.
- If the node carries no `seriesCount` (or the API returns no node at all), that is stated as a review
  note — the run does not proceed as though it had been checked.
- The node is **never** reported as an added record. It is metadata, and the base pass returns early on
  it without marking it seen, so without an explicit guard it would appear as newly `added` on every
  single refresh.

So the API route is now safe to use for the initial harvest: ~40 calls for the series layer plus ~22 for
the nodes, against streaming 22 GB.

### Step R3 — the API-only harvest

`API_REFRESH=1` harvests the **bulk export** and then layers the API over it — it does not skip the
22 GB. For an API-primary harvest use `API_ONLY=1`, which never lists a shard:

```bash
CATALOG_API_KEY=<key> API_ONLY=1 GENERATED_DATE=$(date -u +%F) \
  swift run -c release RecordGroupCatalogGenerator
```

All 22 groups, ~62 calls (~40 series pages at `limit=1000` plus one record-group node each), a few MB,
a couple of minutes. Differences from the refresh path, all deliberate:

- The api store is the build's **base**, not an overlay, so **no changelog is written**. There is no
  snapshot to diff against, and treating an absent base as one would classify every record as `added`
  and produce tens of thousands of lines of noise.
- The completeness check still applies, from the record-group node — a group that comes up short of its
  stated `seriesCount` fails the run exactly as a bulk harvest would.
- A group that returns **no** records is reported and its existing index shard is left untouched, rather
  than being replaced by an empty one.

| Route | Cost | Self-check | Carries |
|---|---|---|---|
| `API_ONLY=1` | ~62 calls, a few MB | ✓ from the node | everything the index projects |
| bulk (default) | 22 GB streamed | ✓ from the shards | also `referenceUnits[].mailCode`, and the deeper levels without extra paging |

Finish either route with one offline `PROJECT_ONLY=1` pass over all 22 groups to rebuild the run-wide
manifest and censuses.

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

### Later — file units, and what the first attempt taught

The first RG 59 file-unit attempt failed with a bare `HTTP 500`, and diagnosing it turned up five
defects. All are fixed; the numbers below are why.

**Page size has to be level-aware.** Measured on RG 59 from the bulk export: a **series** record
averages 3,100 bytes, so `limit=1000` is a comfortable ~3 MB response. A **fileUnit** record has a
median of 1,889 bytes but a **mean of 20,878 and a maximum of 4.24 MB** — that skew makes `limit=1000`
a ~20 MB response on average and potentially hundreds of MB for an unlucky page. `API_PAGE_SIZE` now
defaults per level: **1000 series / 250 file units / 100 items**, overridable.

**And it has to adapt.** No fixed number is safe against that distribution, so a failing page now
**halves the limit and retries the same cursor** (1000 → 500 → … → 25 floor). A genuinely unservable
page therefore costs 7 calls before it gives up — worth knowing as a quota cost.

**Levels are harvested coarsest-first.** `admittedLevels.sorted()` put `"fileUnit"` before `"series"`
alphabetically, so the file-unit level ran first and its 500 aborted the group having harvested **zero
series** — a level that had worked reliably at `limit=1000` minutes earlier.

**A non-2xx no longer reads as end-of-results.** `decode` hands 4xx back as an empty page so the survey
can inspect a 400, and `harvestGroup` treated zero hits as the end of the stream. A revoked key or an
exhausted quota mid-harvest would have truncated silently.

**A failed harvest no longer destroys the previous good one.** This was the expensive one. The harvest
used to `reset()` the store and *then* fetch into it, so the 500 wiped 4,449 already-harvested RG 59
series before dying. Fetches now stage to a `.partial` file and are swapped in only on success; a
failure leaves the previous store byte-identical. Relatedly, a build that comes in **materially short
no longer overwrites an existing shard** — that is how RG 59's index went to zero records, and
`ALLOW_SHORT=1` is the opt-in if a shortfall is genuinely expected.

Failures are also **isolated per group** now. One bad page used to throw out of the entire run; in a
22-group harvest that is most of the work lost.

#### Revised call budget

`fileUnitCount` on the harvested series gives NARA's own expected total: **731,618 file units** across
the 22 groups.

| fileUnit `limit` | total calls | worst group (RG 59) |
|---|---|---|
| 250 (default) | ~3,485 | 952 |
| 500 | ~2,023 | 479 |

Both fit a 10,000/month quota, but neither is the ~797 an earlier estimate suggested — that assumed
`limit=1000` works at file-unit level, which the 500 disproved. `MAX_API_REQUESTS_PER_GROUP` must be
raised well above its 200 default for RG 59 either way.

Note that 731,618 is a **floor**: only 1,466 of RG 59's 4,449 series state a `fileUnitCount` at all, so
a positive `fileUnitCountDelta` is plausible and is reported rather than failed. A *negative* delta is
the one to act on.

### The file-unit harvest, completed (2026-07-30)

All 22 groups at `seriesAndFileUnits`: **20,188 series + 731,692 file units = 751,880 records**, zero
invariant violations, 4.5 GB of index shards. Control-number types rose from 23 to **28** — file units
surface five the series layer never showed — and distinct creators from 7,318 to **7,438**.

Three things it exposed.

**`PROJECT_ONLY` re-projected at the wrong depth, and 21 groups lost their file units.** The depth came
from the plan, which defaults to `series`, so a bare consolidation over a file-unit store silently
discarded 495,212 file units and reported success. A successful API harvest now records its depth in
`checkpoints-api/`, and `PROJECT_ONLY` reads it. A store harvested before that fix has no checkpoint,
so the run warns and asks for `DEPTH` explicitly rather than guessing:

```bash
PROJECT_ONLY=1 DEPTH=seriesAndFileUnits swift run -c release RecordGroupCatalogGenerator
```

**`series-sample.json` reached 250 MB.** A fixed 1-in-25 interval does not bound a committed artifact:
at series depth it selected ~800 records (~1 MB), at file-unit depth 30,075 much larger ones. Now capped
at 500 records, sub-sampled evenly so it stays a cross-section rather than a prefix — 5.4 MB.

**Peak memory was 18.5 GB.** An earlier estimate in this runbook said ~1 GB for RG 59; that was wrong by
roughly 18×, and the build only survived because the machine had the RAM. The causes are structural:
`CatalogIndexBuilder` accumulates a group's entire projection in an array, and `writeShard` then encodes
that whole array to a single `Data` before writing — for RG 59 that is 236,480 records twice over. It
completed in 8 minutes here, but it would swap or be killed on a 16 GB machine, and `DEPTH=all` would
not finish at all. **Streaming the shard write is the fix and has not been done.**

#### One real gap: 37 file units, all in one series

RG 59 reports `fileUnitCountDelta = −37`. It is not spread thin — **1,467 of its 1,468 counted series
match NARA exactly**, and the entire shortfall sits in series **654171, "Numerical Files"** (the
1906–1910 Numerical File). Three query shapes give three counts for it:

| Source | Query | Count |
|---|---|---|
| NARA's `fileUnitCount` | cached field | 1,282 |
| this harvest | `recordGroupNumber=59` + `levelOfDescription=fileUnit` | 1,245 |
| `central-files-index.json` (June) | `ancestorNaId=654171` + `availableOnline=true` | 1,261 |

The *narrower* digitized-only query found 20 more than the record-group filter did, so the filter appears
to under-return for this series — not restricted records, and not a page boundary (37 is no multiple of
the page size, and the final page was full-ish at 230). Unresolved, 0.016% of the corpus, and confined to
a series that already has independent coverage in this repo.

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

## 2b. The completed harvest (2026-07-30)

`API_ONLY=1` over all 22 groups: **20,188 series in ~56 calls**, a few MB, a couple of minutes.

| Check | Result |
|---|---|
| Completeness | Every group's delta **0**, except RG 84 at **+1** |
| `creators` | 20,180 of 20,188 records (100%), **7,318 distinct creators** |
| `variantControlNumbers` | 19,881 records (98.5%), **23 distinct types** |
| `contributors` | 462 records, concentrated in the audiovisual groups |
| `localIdentifier` | 725 records |
| Invariant violations / malformed lines | **none, in any group** |

RG 84's `+1` is NARA's own count being stale, not a duplicate — the NAID de-duplication reported nothing,
and the report says as much rather than passing it over.

### The control-number census vindicates not filtering — with numbers

State Department lot file numbers do **not** live under one type. Measured across the 22 groups:

| Where | Occurrences | Record groups |
|---|---|---|
| `type = "State Department Lot File Number"` | 5,179 | 10 |
| `type = "Agency-Assigned Identifier"`, across **7 distinct note spellings** | ~5,096 | up to 6 each |

So roughly **half of all lot numbers hide under the generic type**, discriminated only by free-text notes
reading "this is a department of state lot file number", "this is the department of state lot file
number", "this is a state department lot file number", "this is a department of state assigned lot file
number", "this is a usaid lot file number", and more. Any filter on `type` alone loses about 5,000 of
them. This is precisely the failure the cross-tab design exists to prevent, now quantified rather than
asserted.

Second finding worth having: lot numbers appear in **10 record groups**, not just State's own two.

### The creator authority pass, run

`PROJECT_ONLY=1 CREATOR_AUTHORITY=1` over the 22-group harvest: **7,314 of 7,318** creator NAIDs
resolved, into **6,167 authority records** (one record commonly answers several creator references —
the successive names of one office). Four NAIDs have no authority record anywhere in the export:
`10461861`, `10535547`, `652475212`, `659944288`.

**The nested-name join is what made this work, and the numbers are not close:**

| Joined via | Records |
|---|---|
| `organizationNames` (nested name variants) | **5,841** |
| `self` (the naive `naId == naId` join) | 326 |

So the obvious join would have resolved **326 of 7,314 — under 5%** — and reported the other 95% as
"no authority record in the export". That is the bug the RG 486 run surfaced when it reported
`0 resolved, 3 unresolved`, and this is its full cost had it gone unnoticed.

What the pass adds, stated honestly — the enrichment is partial:

| | |
|---|---|
| `administrativeHistoryNote` | **1,842 of 6,167 (29%)**, ~2.2 MB of prose |
| `organizationNames` succession chains | 5,841 |
| `jurisdictions` / `programAreas` | 1,819 / 1,775 |
| `biographicalNote` (persons) | 92 |
| organizations / persons | 5,841 / 326 |

Cost: a few hundred MB of S3 streaming, **no API key** — the authority records are in the same public
bucket. `CREATOR_AUTHORITY=1` is therefore allowed under `PROJECT_ONLY`, which the code used to refuse:
the full creator census only exists once the stored descriptions have been re-projected, so blocking it
there made the authority data unreachable without re-spending API calls for nothing. A `PROJECT_ONLY`
run that performs the pass now says plainly that it touched the network.

> **Artifact size:** `creators/creator-authority.json` is **15.4 MB**, not the "a few MB" this runbook
> originally estimated. It is committed, because the administrative-history prose is the point and it
> took a multi-hundred-MB stream to assemble. Gitignore it and keep a sample instead if repo weight
> matters more than having it to hand.

### Two follow-ups from the harvest, applied

**`numberingNote` promoted into the index** (385 records, 15 groups). Despite the name it is not a note
about numbering, it is the **ordering instruction** — RG 229: *"Requests for items in the series must
include the record group number, series designator, box number, and item number.
(Example=229-IIA-1-1)."* Directly useful to anyone assembling a citation or a pull request.

**`specificRecordsTypes` is now DERIVED, and the dead lookup removed.** The alias for it matched nothing
in all 20,188 records — because there is no such key. NARA folds every authority kind into the single
`subjects` array discriminated by `authorityType`, and the values were sitting there all along: 9,312
`specificRecordsType` entries across 16 groups. The field is filled from where the data lives rather
than left permanently empty beside it, and now covers **2,155 records / 303 distinct types**:

| Type | Records |
|---|---|
| Reports | 1,301 |
| Correspondence | 1,299 |
| Memorandums | 1,185 |
| Telegrams | 709 |
| Notes | 583 |
| Speeches, addresses, etc. | 310 |

That is a document-genre index across the whole foreign-affairs cluster, which is worth more than the
empty array it replaced.

`specificRecordsTypes` was also dropped from `consumedKeys`, so if NARA ever does start emitting a real
key by that name the unprojected-key tripwire will report it rather than masking it behind a stale
entry.

Still unprojected, and deliberately: `dataControlGroup` (internal reference-unit code — the incidental-drift
culprit), `internalTransferNumbers` (17), `transferNote` (13), `editStatus` (12), `scaleNote` (6),
`beginCongress`/`endCongress` (1 each).

### Genuinely agency-specific control-number types

Types confined to three or fewer record groups — the answer to the original question:

| Type | Occurrences | Record groups |
|---|---|---|
| Agency Disposition Number | 280 | 59, 84, 286 |
| PRESNET Number | 3 | 59 |
| Kennedy Assassination Document ID | 1 | 59 |
| Select List Identifier | 1 | 59 |
| Off-Site Storage Transaction Number | 1 | 268 |
| Download Display Identifier | 3 | 306 |

### Two bugs this harvest exposed

Both were mine, both are fixed, and the second one did real damage before it was caught:

1. **The manifest misattributed provenance.** `source.kind` was hard-coded `s3-bulk-export`, so an
   API-only harvest of 20,188 records recorded its source as the bulk export with an empty snapshot
   date. The manifest now reports the sources actually read.
2. **`PROJECT_ONLY` could not see an API-harvested store.** `API_ONLY` writes to `raw-api/`;
   `PROJECT_ONLY` read only `raw/`. So the consolidation step this runbook recommends found nothing for
   21 of 22 groups and rewrote the manifest and all five censuses from the one group that *did* have a
   bulk store — replacing a complete 22-group description with an 11-record one. It now reads both
   stores, and re-running consolidation restored everything with **zero API calls**, because the raw
   stores are the recovery path the design promises they are.

### 2b-1. Where the extract lives (2026-08-04)

The harvest is unpacked at **`/Users/jbotts/Development/nara-record-group-catalog/`** —
22 shards, 4.5 GB, `generated: 2026-07-30`, 20,188 series + 731,692 file units, matching
`manifest.json` exactly. The two shards downstream work needs are
`series/rg_256.json` (170 MB, Paris Peace — N-2c/#354) and `series/rg_59.json` (3.3 GB,
the decimal-file digitisation — N-7/#663).

`series/*.json` is **gitignored** and always will be: 4.5 GB cannot live in the repo. So
this path is the contract. A generator that reads it should take it from an env var
defaulting here, and anything derived from it must be committed as a small artifact — the
index the app ships, never the shard. The source tarball
(`nara-record-group-catalog-full-2026-07-30.tar.gz`) remains alongside it; re-extracting
`rg_59.json` alone streams the whole archive and takes several minutes, which is the cost
this note exists to avoid paying twice.

### 2c. What the harvest was used for, and what it proved (2026-08-02)

The full `seriesAndFileUnits` harvest (**751,880 records** = 20,188 series + 731,692 file
units, 4.5 GB) was measured against every open NARA-workstream issue and against the
owner's live index. Recorded here because the negative results are the durable part —
they close routes that would otherwise be re-attempted.

**The three things the Catalog API itself demonstrated:**

1. **The v2 API is field-complete against the bulk export, and cheap.** The whole 22-group
   series layer is ~62 calls, a few minutes, a few MB — versus streaming 22 GB. Either
   source yields a field-complete series index. Bulk remains the only keyless route and the
   only one carrying `mailCode` and the deeper levels without further paging.
2. **`variantControlNumber_is` was never the limitation.** Only **5,466 of 20,188 series
   (27.1%)** carry a lot-type control number *at all*; within RG 59 it is **2,900 of 4,449
   (65.2%)**. Roughly a third of RG 59's series have no State Department lot number
   recorded in the catalog under any type. The gap is NARA's cataloguing, not our querying
   — no re-harvest, no key, and no additional record groups change it.
3. **Resolution collapses upward.** 199,108 records resolve to NAID 388, the RG 59 node
   itself. That is why a naive catalog search so often returns the record group rather than
   the series a citation names.

**The unexpected find: 10.1 million digitised objects.** 17,985 records carry
`digitalObjects` arrays totalling **10,115,572 individual objects**, each with a live
`catalog.archives.gov` `objectUrl`. This is a categorically better research outcome than a
NAID — a PDF of the microfilm roll rather than a note about which box to visit. The
concentrations that matter to FRUS:

| series | naId | digitised file units | objects |
|---|---|---|---|
| Paris Peace Conference (RG 256) | 638859 | 537 of 538 | 450,105 |
| Numerical Files | 654171 | 1,238 | 1,556,955 |
| Central Decimal Files | 302021 | 2,778 | 1,530,130 |
| Name Index to the Central Decimal Files | 581008 | 780 | 1,491,530 |
| Purport Lists and Cards | 580701 | 653 | 815,808 |
| Decimal Files | 2555709 | 1,469 | 147,295 |

The decimal-series file-unit titles are ranges in exactly the form FRUS cites
(`763.72/1476-1635`), so an interval lookup resolves a citation to a roll. Coverage is
**front-loaded onto the early twentieth century** — NARA digitised along the microfilm
publications — so the classes FRUS cites most (893, 611, 793, 711) have *zero* digitised
units while Visa Division classes 131 and 133 are the most heavily digitised in the
harvest. Measured reach: **9,006 of 122,033 decimal-cited documents (7.4%)** have a class
with any digitised unit; **7,129 (5.8%)** land inside a digitised range. Tracked as #663.

**Confirmed absent:** the Central Foreign Policy Files subtree (naId 654098 — 1 series +
69 file units, 1973–79) has **zero** digital objects on every unit. The Electronic
Telegrams, D/P/N-Reel, Top Secret and Bulkies units are catalog stubs, which is why a
D-reel deep-link route returns nothing the app does not already ship.

**Four other fields worth knowing are present and unused:** `accessRestriction` on 100% of
all 751,880 records (series-level: Unrestricted 14,544 / Restricted-Fully 2,773 /
Restricted-Partly 1,904 / Restricted-Possibly 953); `inclusiveStartDate` and
`inclusiveEndDate` on 100% of the 20,188 series; `findingAids` on 3,247 series (16.1%);
and `numberingNote` on 385 — NARA's own ordering instruction, the difference between a
researcher's request being fillable and being bounced.

**A trap to record.** Building a gazetteer from the harvest's 6,367 creator-name parts and
matching it against unresolved FRUS lead entities scores 562 documents on 8 exact hits,
492 of them "National Security Council" — and every one is wrong. The 22 groups are the
*foreign-affairs* groups, so an agency's own records usually live outside them: the four
"National Security Council" series are State and USIA records (RG 59/306), not NSC's own
RG 273; "Department of Defense" resolves to Office of Military Government for Germany
occupation files; "Department of the Treasury" to the Coast and Geodetic Survey
(1878–1903). A creator-name match *inside* this harvest is usually a correspondent or a
custodial accident, not the record creator. Do not build a creator gazetteer from it.

**Validation the harvest did deliver:** 968 of the 971 bundled lots in
`central-files-index.json` reproduce from the harvest's own control numbers (99.7%) with
**0 NAID disagreements** — the shipped bundle is correct. It also proves **113 bundled lots
are control-number-ambiguous** in the catalog (RG filtering fixes only 4, leaving 1,710
documents ambiguous; 64D563 alone rides 245 documents across 12 candidate series), which
correctly rules out ever *regenerating* that bundle from the harvest.


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
| `API_REFRESH` | off | Re-page the live API and overlay it on the **bulk snapshot**, emitting a changelog. Harvests the bulk export too. Needs `CATALOG_API_KEY`. |
| `API_ONLY` | off | Harvest from the API **instead of** the bulk export — no shard listing, no 22 GB, no changelog. Needs `CATALOG_API_KEY`. |
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
