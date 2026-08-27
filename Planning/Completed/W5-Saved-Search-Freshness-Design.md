# W-5 / #266 — Saved-Search Freshness (O-5 design record)

**Status: SHIPPED 2026-08-26** (with W-4, one PR, one CloudKit deploy block). The one-page
design the plan of record's O-5 row asked for, written as a record of what shipped and why.

## What "new" means — the definition that survives a reindex

There is **no index-side timestamp** (verified: `document_cache` carries none, and rowids are
reusable, so "rows since rowid N" is unsound). The definition that works is a **count
watermark**: a saved search is fresh when `searchCount(now) > matchCountAtLastRun`. Both are
EXACT, uncapped counts — `SearchService.searchCount` runs the same match expressions and
filters as the search itself — which defuses the plan-of-record's landmine ("capped fetches
make naive 'N new' a floor"): nothing in this arithmetic is capped, so the caption can print
an exact number. A reindex that adds nothing changes no count; a removed volume shrinks the
count, which is deliberately NOT news (no badge on a negative delta; the baseline stays until
the search is actually re-run).

## The owner's three decisions

1. **Watermark: Synced** — the freshness blob rides the `SavedSearch` record through
   CloudKit, so the badge means "new since you last ran this search *anywhere*"; running it
   on the Mac clears the phone's badge.
2. **Badge: capsule + count** — the NEW capsule (ProjectHomeView's lead-capsule grammar,
   shared as `SavedSearchNewBadge`) plus an exact "+N since last run" caption, safe because
   the delta derives from the uncapped `searchCount`. The sidebar row shows the capsule only
   (the caption would crowd it) with the count in the accessibility label.
3. **Stamping: `lastModified` added** — `SavedSearch` predated `ModelModificationStamper`
   and carried no merge tiebreaker at all, so a stale device copy could win every CloudKit
   merge. The field exists now and the record joins `LastModifiedStamping`.

## Storage

`SavedSearch.freshnessData: Data?` — one JSON blob (`SavedSearchFreshness`: `lastRunAt`,
`matchCountAtLastRun`, `indexedVolumeCountAtLastRun`), not three columns, for the same reason
as `parametersData` (#756): a future field costs nothing, while every scalar column is its
own CloudKit identifier and deploy. The decoder is hand-written per-field-tolerant (`try?`
around each field), so a partial or future blob degrades to whatever parses. `nil` = never
recorded → **no badge, never a fake zero**. Two new CloudKit identifiers
(`CD_freshnessData`, `CD_lastModified`) board the reserved W-4+W-5+Archive-Visits promotion.

## Stamping sites (three, and their asymmetry)

- **SavedSearchesView `onSelect`** (both platforms — SearchSheet on macOS, SearchView on
  iOS): stamps AFTER the recalled search completes, from the run's `totalMatchCount` — the
  count the user actually saw.
- **SidebarShortcuts.run** is a hand-off (the Search tab runs the query; the row never
  learns the count): stamps `lastRunAt` with a **nil baseline — clearing, not keeping, the
  old one**, because the user just saw the current results and a stale baseline would keep
  claiming "+N" about them. The evaluator backfills a nil baseline with the current count on
  the surface's next appearance (no badge that cycle), without advancing `lastRunAt`.

## Evaluation

`SavedSearchFreshnessEvaluator.newResultCount(for:service:context:)` — never-run → nil;
count failure → nil; nil baseline → backfill + nil; else `verdict(current:baseline:)`
(positive delta or nil). A cold **filtered** count can take seconds, so both surfaces
evaluate **sequentially** from a cancellable `.task(id:)` whose identity includes each
watermark blob — a run's stamp re-triggers evaluation, and the backfill's own write restarts
the task exactly once (the second pass writes nothing).

## Tests

`SavedSearchFreshnessTests.swift`: watermark storage semantics (including the
nil-count-clears-baseline rule and per-field-tolerant decoding), the stamper reaching
`SavedSearch`, the verdict arithmetic, and the evaluator end-to-end over a real fixture
index — growth badges with the exact delta; the backfill fills silently and the next growth
badges against it.
