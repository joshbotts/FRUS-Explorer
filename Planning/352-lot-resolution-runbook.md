# #352 — Keyed lot-resolution run-book (owner run)

**Goal:** resolve the 573 missed lot files (`lotFile | liveRouteOnly`, 5,776 records — top-50 = 78%
of the gap) and re-resolve the 16 wrong `fileUnit` lots, then regenerate the downstream bundles so
the corrected NAIDs propagate everywhere. From the #335 audit §5.3 / §7 step 2.

> **[2026-07-29] The 573 / 5,776 above are the figures this run-book was *written against*, and
> they are kept for that reason. The gap after the keyed runs is **581 lots / 6,230 records** —
> it grew, because dropping wrong `fileUnit` resolutions moves lots *into* the missed set. Use
> the [Priority reference](#priority-reference--top-10-missed-lots-558-of-the-gap-3475--6230)
> table near the end of this file for any live figure.

**Owner-keyed.** `CATALOG_API_KEY` stays owner-held; every keyed step below is run by the owner in
their terminal. The offline steps need no key.

---

## Actual run — 2026-07-17 (outcome + the cold-cache `RESOLVE_LOTS_ONLY` path)

The first real run was on a machine with a **cold page cache**, where a full `CITATIONS_CSV` run
would re-enumerate Phase 1/2 (thousands of requests) just to touch lots. So it used the new
**`RESOLVE_LOTS_ONLY`** mode (preserves the Numerical File + country series, re-harvests only lots)
plus `ENRICH_LOTS`:

```bash
export CATALOG_API_KEY=<key>
RESOLVE_LOTS_ONLY=1 CITATIONS_CSV=/Users/jbotts/Development/citations2.csv swift run CentralFilesIndexGenerator
ENRICH_LOTS=1 swift run CentralFilesIndexGenerator
# then, offline: collection-authority regen (fileUnit-guarded resolver), reviewed and committed.
```

**Outcome — an accuracy win, not the projected coverage jackpot:**
- **971 lots, 100% series-level, 0 fileUnit.** The 16 fileUnit mis-resolutions (60 D 627 →
  "Operation Mongoose" + 15) are gone from the *data*; **+24** newly-resolved lots.
- **Every freshly-harvested lot is post-validated** — its NAID provably carries the lot number — a
  stronger guarantee than the pre-#352 bundle. (The 17 `mergeLots`-preserved lots keep their June
  resolution and are *not* re-post-validated this run — the trade for not losing valid NAIDs to
  index drift; `RESOLVE_LOTS_ONLY` prints a spot-check warning for any preserved lot that also had a
  fresh candidate rejected.) 22 lots shifted to a different (also lot-carrying) NARA record vs. the
  June harvest; churn, not error, but worth an owner spot-check.
- **`mergeLots` preserved 17 lots** that NARA's control-number search now misses (index drift since
  June) but whose NAIDs are still valid records — a re-harvest must not lose those.
- **collection-authority regenerated** (offline, fileUnit-guarded resolver): the 14 contaminated lot
  clusters cleaned; 23 clusters gained a NAID (the new lots); 4,431 clusters unchanged in identity.
- **The coverage goal did not pan out: 2 of 573 "missed" lots resolved.** They are not in NARA's
  control-number index (which is why they were missing originally); the audit §5.3 estimate assumed
  otherwise. They keep resolving through the app's live lookup, as before. Bulk-resolving them needs
  manual NAID curation (the top-10 = 54% of the gap **— 55.8% as re-measured 2026-07-29**), not a
  keyed control-number pass.

**Still deferred (needs the key):** `volume-sources-index.json`'s 9 fileUnit lot entries stay in the
data (its self-contained #351 render guard suppresses them, so no wrong links show); a full keyed
`VolumeSourcesIndexGenerator` run (reads the `rgs` cache → preserves the 31 record-groups, resolves
lots against the clean central-files) would clean them too — do this when convenient.

The original full-harvest run-book below stays valid for a machine with a warm cache.

---

Run every command from the repo root: `/Users/jbotts/Development/FRUS-Explorer`. Prefix the Swift
commands with `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` if `swift` picks the
wrong toolchain.

---

## Prerequisite shipped in this PR — the post-validation

The resolver's lot acceptance now closes the two mis-resolution classes the audit found
(`CatalogRecord.isAcceptableLotResolution`, `NARACatalogHarvestClient.resolveLotFile`):

1. **not a file unit** — a State Department lot file is catalogued as a NARA *series*; a `fileUnit`
   match is rejected (the 60 D 627 → "Operation Mongoose" class);
2. **carries the queried lot** — the record's own `variantControlNumbers` must actually contain the
   lot (NARA's `variantControlNumber_is` filter returned NAID 609235170 for `60D627` with an *empty*
   list). Legit records expose the lot as a `State Department Lot File Number` control number, so
   this does **not** over-reject (verified real: NAID 40967113 carries `64D171`, `66D102`, …).

Every dropped candidate is printed in a `⚠︎ #352 POST-VALIDATION` block at the end of the lot survey
so you can eyeball for any false rejection. **This code must be merged before the keyed run** — a run
on the old resolver still accepts the first RG match without verifying the lot.

This PR also **widened the lot extractor and query speller** (`LotFileCitationExtractor.lotRegex`,
`NARACatalogHarvestClient.lotVariants`) to the app's `looseLotRegex` grammar: letter-first lots
(`Lot M–88`, `Lot F 96`, `Lot W-130`), trailing-letter suffixes (`Lot 61 D 282A`), plural leads, and
`Lot File(s)` infixes are now harvested and queried. Before this, the digits-required pattern
silently dropped **21 letter-first lots (881 records, 15% of the gap — including M-88, 697 records,
the #2 priority) and mis-classified letter-first `F` lots as RG 59**, so the keyed run could not have
resolved them. F-designators map to RG 84 wherever the `F` sits (`F96`, `79F80`).

---

## Critical gotchas (read before running)

- **Wholesale lot overwrite.** Supplying `CITATIONS_CSV` replaces the *entire* `lotFiles` section
  with only the lots found in that CSV — it does **not** merge with the currently-bundled lots. Use
  the **full** FRUS citations export (every lot present), never a trimmed missed-lot subset, or all
  previously-resolved lots are dropped.
- **Cache-hit masking.** `RETRY_LOT_MISSES=1` re-queries only cached *misses* (empty naId). A cached
  *hit* — including the 16 wrong `fileUnit` resolutions — is reused as-is and **not** re-validated.
  Delete those cache files first (Step 1) so the post-validation actually re-runs on them.
- **Not a lot-only pass.** The `CITATIONS_CSV` branch re-runs the full Phase 1 (Numerical File) +
  Phase 2 (country series) enumerations before Phase 3 lots. A warm `.cache/central-files` page cache
  makes this free; a cold cache turns it into a large keyed harvest. Confirm the page cache is intact.
- **Enrichment is wiped.** Phase-3 writes bare `LotFileEntry` rows (no #315 entry numbers, no #351
  `levelOfDescription`). You **must** run `ENRICH_LOTS` afterward, and only then can
  `PRUNE_FLAGGED_LOTS` drop any residual fileUnit/null-RG lots.
- **Downstream bundles are stale** until regenerated. `volume-sources-index.json`,
  `collection-authority.json`, and the #335 export all embed the old NAIDs — regenerate them (Step 4)
  or the poisoned NAID keeps propagating. Those are offline steps, but easy to forget.

---

## Steps

### Step 0 (offline) — confirm the prerequisite is merged and caches are present
```bash
git log --oneline -5                        # confirm the #352 post-validation commit is in
ls .cache/central-files/lots | wc -l        # the lot cache (re-runs stay cheap)
ls .cache/central-files | head              # page cache for Phase 1/2 (warm = free enumeration)
```

### Step 1 (offline) — force re-validation of the 16 wrong `fileUnit` hits
These are cached HITS; `RETRY_LOT_MISSES` will NOT re-query them. Delete their cache entries so the
keyed run re-queries them through the new post-validation:
```bash
rm -f \
  .cache/central-files/lots/59_57M44.json  .cache/central-files/lots/59_58D528.json \
  .cache/central-files/lots/59_59A543.json .cache/central-files/lots/59_59D27.json \
  .cache/central-files/lots/59_60D627.json .cache/central-files/lots/59_63A190.json \
  .cache/central-files/lots/59_63D35.json  .cache/central-files/lots/59_64A532.json \
  .cache/central-files/lots/59_64D50.json  .cache/central-files/lots/59_65D285.json \
  .cache/central-files/lots/59_71A2420.json .cache/central-files/lots/59_72D170.json \
  .cache/central-files/lots/59_74D471.json .cache/central-files/lots/59_90D192.json \
  .cache/central-files/lots/59_91D257.json .cache/central-files/lots/59_92D252.json
```
**Accuracy-complete alternative (recommended):** clear the whole lot cache so *every* lot is
re-queried through post-validation (~3,000 queries — ≈963 resolved lots + ≈600 misses × up to 3
spellings — within a ~10k/month key budget) — this purges any unverified match, not just the known 16:
```bash
rm -rf .cache/central-files/lots
```

### Step 1.5 (KEYED canary) — confirm post-validation does not over-reject before the full run
The post-validation assumes the `variantControlNumber_is` search response carries the record's own
`variantControlNumbers` (the repo's live evidence is from the `naId=` fetch route). Before a full
cache wipe, prove a few **known-good** lots still resolve through the new resolver:
```bash
rm -f .cache/central-files/lots/59_63D135.json \
      .cache/central-files/lots/59_64D199.json \
      .cache/central-files/lots/59_72D316.json
CATALOG_API_KEY=<key> CITATIONS_CSV=/path/to/frus-citations.csv RETRY_LOT_MISSES=1 \
  swift run CentralFilesIndexGenerator 2>&1 | grep -E "63D135|64D199|72D316|POST-VALIDATION"
```
Expect all three back as `control` hits and **not** in the `⚠︎ #352 POST-VALIDATION` block. If a
known-good lot is dropped, the search response is thinning `variantControlNumbers` — stop and report
before the full run (the guard would then need to fall back to a per-candidate `naId=` re-fetch).

### Step 2 (KEYED) — the lot-resolution pass
`CITATIONS_CSV` = the **full** 6-column FRUS citations export (`volume_id, citation_type,
ancestor_id, xpath, plain_text, tei_xml`); lots are regex-harvested from `plain_text` only.
```bash
CATALOG_API_KEY=<key> \
  CITATIONS_CSV=/path/to/frus-citations.csv \
  RETRY_LOT_MISSES=1 \
  swift run CentralFilesIndexGenerator
```
Watch the tail for the `⚠︎ #352 POST-VALIDATION` block — each line is a lot whose only RG match was
a fileUnit or lacked the lot in its control numbers. These are the wrong matches the guard dropped;
scan for any that look like a *legit* series that should have resolved (report back if so).

### Step 3 (KEYED, then offline) — enrich, then prune
```bash
CATALOG_API_KEY=<key> ENRICH_LOTS=1 swift run CentralFilesIndexGenerator   # re-attach #315/#351 fields
PRUNE_FLAGGED_LOTS=1 swift run CentralFilesIndexGenerator                   # offline; drops any residual fileUnit/null-RG
```

### Step 4 — regenerate the downstream bundles

**The first command is KEYED, not optional.** [2026-07-29]

```bash
CATALOG_API_KEY=<key> swift run VolumeSourcesIndexGenerator
```

The record-group resolution pass lives *inside* the `CATALOG_API_KEY` branch. Run it without
the key and the generator does not preserve the existing record groups — it writes an **empty
map**, silently taking `recordGroups` from 31 to 0. Those 31 RG headers exist in no other
bundled artifact (central-files carries an RG *number* per lot, but no RG *header records*),
so `VolumeSourcesIndex.resolution()`'s record-group arm then returns nil for every RG-only
node, in both the Source Explorer and the Collections export path. This happened on
2026-07-29 and was caught only by diffing the artifact against `HEAD`.

The keyed run costs **no API calls** when `.cache/volume-sources/rgs` is warm (31 cached
responses, one per record group) — the key enables the pass, it does not spend budget.

**Go/no-go:** the summary must say `record groups: 31`, not 0. The first line of output
(`Distinct keys: … 31 record groups`) is the *harvest* and says nothing about what was
written — do not read it as confirmation.

```bash
swift run -c release CollectionAuthorityGenerator         # offline; NAIDs resolve against central-files
```

**This half is a no-op unless central-files itself was regenerated in the same pass.** On
2026-07-29 it produced a file byte-identical to the committed one apart from its `generated`
stamp, because central-files was already current from the 2026-07-17 run. When that happens,
**revert it** rather than committing: `generated` is provenance for the data, and bumping it
when nothing changed asserts a refresh that did not occur.
Once these land, the app's #351 render guards become no-ops automatically (the corrected NAIDs are
no longer `fileUnit`, so `CentralFilesIndex.untrustworthyNAIDs` empties).

### Step 5 (offline) — re-baseline the audit
```bash
swift run -c release SourceExplorerExportGenerator        # re-run the #335 export
```
Then re-run the conversion check:
```bash
jq -r '.records[] | select(.strategy=="lotFile" and .offlineOutcome=="liveRouteOnly") | .derived.lotFileNorm' \
  Planning/source-explorer-export/source-explorer-export.json | sort -u | wc -l
```

**[2026-07-29] Expect ~581, and read a number ABOVE 573 as correct.** The original
"expect ≪ 573" was written before the keyed lot pass and is wrong: that pass dropped 16
`fileUnit` entries whose records the 2026-07-17 baseline still counted as *resolved*. The
gap therefore grows — not because coverage worsened, but because the export stopped crediting
resolutions that were never real. Measured on 2026-07-29: **581 lots / 6,230 records**, with
`liveRouteOnly` +456 and `resolvedLotBundle` −455 in the summary (60D627 alone is 455).

Regenerate the ranking file at the same time, or N-3 curates from a stale list:
```bash
jq -r '.records[] | select(.strategy=="lotFile" and .offlineOutcome=="liveRouteOnly")
       | [.derived.lotFileNorm, (.derived.recordGroup // .parsed.recordGroup // "")] | @tsv' \
  Planning/source-explorer-export/source-explorer-export.json \
 | awk -F'\t' '{c[$1]++; if($2!="") rg[$1]=$2} END{for(k in c) printf "%s\t%d\tRG-%s\n", k, c[k], (rg[k]==""?"59":rg[k])}' \
 | sort -t$'\t' -k2,2nr -k1,1 > Planning/source-explorer-export/missed-lots-ranked.tsv
```

---

## Priority reference — top-10 missed lots (**55.8%** of the gap, 3,475 / 6,230)

**[2026-07-29] Regenerated.** The table below is current. The previous version was built
against the 2026-07-17 04:34 export — before that day's keyed lot regen — and **omitted
60D627 (455 records), which now ranks #3**. Ten lots are new to the ranking; six of them are
the `fileUnit` entries the regen dropped. Curating "the top ten" from the old file would have
skipped the third-largest item in the gap.

Full ranked list: `Planning/source-explorer-export/missed-lots-ranked.tsv` (lot ⇥ count ⇥ RG).

| # | Lot | Records | RG |
|---|-----|--------:|----|
| 1 | 54D270 (Marshall Mission Files) | 1063 | 59 |
| 2 | M88 (CFM Files) | 697 | 59 |
| 3 | 60D627 — Conference Files ¹ | 455 | 59 |
| 4 | 59D95 | 283 | 59 |
| 5 | 64D560 | 248 | 59 |
| 6 | 62D181 | 197 | 59 |
| 7 | 93D188 | 151 | 59 |
| 8 | 60D137 | 131 | 59 |
| 9 | 64D559 | 131 | 59 |
| 10 | 63D123 | 119 | 59 |

¹ *Why 60D627 is the case for re-baselining.* Its citation is `Conference Files, Lot 60 D
627`. The pre-regen index resolved it to NAID **609235170**, a `fileUnit` inside the series
*Files Pertaining to Operation Mongoose* — a confident, wrong answer that kept it out of the
"missed" list entirely. The keyed regen dropped it, which is what promoted it to #3. Curating
this one replaces a mis-resolution, not just a blank.

All 581 missed lots already carry an identity cluster in `collection-authority.json` (only the NAID
is missing), and every lot maps to a single record group — 466 RG 59 and **107 RG 84** (the
F-designator post records; the top-50's RG-84 members are F96, F73, F79, 79F80, 59F59). So the keyed
pass is pure NAID resolution.

---

## Deferred to a follow-up (item 2 — the volume-sources lot-map fold)

The audit's "fold the volume-sources lot map into central-files" is architectural cleanup worth ~2
records (the runtime "fallback rescued exactly 2 of 15,340" is an offline *export-diagnostic*
measurement — `frus1969-76ve10/d568` lot 74D267 → NAID 1257163, and `d574` lot 78D26 → NAID 824653 —
not an app runtime path). The two bundled lot maps back **disjoint** app surfaces (central-files →
Source Explorer; volume-sources → Browser Sources row + Collections export), and `VolumeSourcesIndex.
resolution()` also serves record-group hits that central-files does not carry, so the maps cannot be
merged wholesale. Tracked separately; not a blocker for the resolution work above.
