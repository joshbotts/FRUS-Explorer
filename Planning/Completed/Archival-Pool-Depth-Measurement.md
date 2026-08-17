# Archival candidate pool — how often the cut binds

**Date:** 2026-08-10 · **Status:** measurement of record for #645 · **Measured against:** the
owner's live index (`frus.db`, 552 volumes, 264,487 documents carrying a source note), read
read-only.

**Why this file exists.** #645's second ask was *"a measurement of how often the cut actually
binds"*, and the issue said plainly what should follow from it: *"If it is rare, this is a
doc-comment correction rather than a code change, and that is a fine outcome."* The measurement was
taken during #649 and #650 and then lived only in PR and commit prose — so the next person to touch
the pool depth would have had to take it again, or take the decision without it. It is written down
here.

---

## The numbers

`RelatedDocumentsEngine.candidatePoolFloor` is **120**. A generator returns at most that many
candidates, and ranking can only surface a document the pool contained.

### Lot-file containers

| | |
|---|---|
| documents carrying a lot key | 14,897 |
| distinct lot containers | 1,248 |
| containers larger than the pool | **23** |
| documents sitting in one of those | **6,678** (44.8% of lot-keyed documents) |
| largest container | **1,063** — `Lot 54 D 270`, spanning 5 volumes |

The five largest: `54D270` (1,063), `M88` (697), `63D351` (624), `60D627` (432), `64D199` (368).

### Central-file class containers — where it actually binds

| | |
|---|---|
| class containers larger than the pool | **260** |
| documents sitting in one of those | **105,681** |

That is **40.0% of every source-noted document in the corpus**, against 2.5% for the lot axis. The
class axis is an order of magnitude more affected, and it is the one nobody had counted.

---

## What follows from it

**Not rare. So not a doc-comment correction.** #645 offered that outcome explicitly and the data
declines it: two in five source-noted documents anchor a container the pool cannot hold. The cut
binds for a large minority of the corpus, not an exotic tail.

**Which is why the ordering had to change, and why it had to be reported.**

1. *Ordering.* A cut that binds on 105,681 documents cannot be taken alphabetically — the survivors
   would be the alphabetical head of the alphabetically-first volumes, and the scorers would never
   see the rest. #649 stratified the fetch; the remainder (this session) stratified the **scoped
   re-cut**, which is the cut that actually binds whenever a scope is active, because the
   100,000-row fetch ceiling means the query-side stratification never fires.
2. *Reporting.* `totalBeforeLimit` is computed inside the pool, so the "N more related" line was a
   truncated total presented as a complete one — the convention (`RecordedCount`, the facet
   `bounds`) that #645 itself cited. `GeneratedPool.availableTotal` now carries the generator's own
   total, and the view says how many documents were never scored.

**What the measurement does *not* license.** It does not say the 120 floor is wrong. Raising it
trades a bigger pool against per-anchor query and scoring cost on every related-documents open, and
nothing here measures that cost. Stratifying the cut and disclosing it are the two changes the data
supports; a different floor needs its own measurement.

---

## Reproducing it

Read-only against the live index — never `immutable=1`, which ignores the WAL and can read a stale
snapshot:

```sql
-- lot containers over the pool floor
WITH lots AS (
  SELECT lot_file_norm AS k, COUNT(*) AS n FROM document_sources
  WHERE lot_file_norm IS NOT NULL AND lot_file_norm <> '' GROUP BY 1)
SELECT COUNT(*), SUM(n) FROM lots WHERE n > 120;

-- class containers over the pool floor
SELECT COUNT(*), SUM(c) FROM (
  SELECT decimal_class, COUNT(*) c FROM document_sources
  WHERE decimal_class IS NOT NULL AND decimal_class <> '' GROUP BY 1 HAVING c > 120);
```

The figures move as volumes are indexed; the *shape* — class containers dominating lot containers
by an order of magnitude — is a property of how FRUS cites, not of one index.

**Version history:**
- 1.0 — Session 2026-08-10: #645 remainder. Written down where the PR prose had left it, and
  extended with the class-axis figures, which had not been measured at all.
