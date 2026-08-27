# The lexical axis's addressable market, re-measured after the W-17 route arms

**Date:** 2026-08-27 · **Session:** W-17 session 1 · **Index:** the live dev index
(552 volumes, 264,487 source-noted document rows)

`Lexical-Similarity-Neighbors-Assessment.md` §0.10 instructed: fix the incumbents, *then*
re-measure the zero-candidate population — "*that* number, not any figure in this document,
is the axis's addressable market." The #645 measurement session was faulted for leaving its
numbers in PR prose; this file is where these live.

## What the session changed before measuring

§0.10's incumbent list was stale on contact (the assessment that admitted W-17 carried it
forward unverified):

- **#645 was already fixed and closed** (2026-08-10, PRs #649 → #654 → #806). Nothing to do.
- Of the "four missing route arms," **#808 had already added the CIA arm.** The remaining
  three shipped in this session, each with a measured cohort behind it:
  1. **Dotless file numbers** (`File No. 6775/108b.`, `320/1-857`) — the dot requirement
     that kept OCR junk out also excluded the entire pre-1910 Numerical File and the
     dotless class citations. Same pre-slash location rule as the dotted arm, behind a
     validated shape gate (`ParsedSourceNote.dotlessFileLocation`).
  2. **RG-59 non-central-files series** (`Conference Files, CF 2449`) — the old switch
     excluded RG 59 wholesale; the honest boundary is the series *name*
     (`seriesNamesCentralFiles`), not the record group.
  3. **Central-files-named RG-59 rows** (`RG 59, Central Files, 511.00/9–2861`) — the
     series is not a cohort but the citation's class is; the class location comes from
     the raw note (threaded as `rawCitation`), and `relatedByDecimalClass` gained
     `excluding:`/`ordering:` to serve as the anchored class arm.
  4. **CFPF film segments** (`P820123–1320` → film `P820123`) — the only cohort key the
     1973–79 electronic-era notes carry. P-reels cluster genuinely (`P820123` → 41
     documents); whole-identifier equality almost never repeats (largest: 3).

## The measurement

Computed over `document_sources` with the matchers' own keys (Python replication; the
approximations are listed below). A document counts as **served** when at least one of its
cohort keys has ≥ 2 members — i.e. it would show at least one archival neighbor.

| population | documents |
|---|---|
| source-noted rows | 264,487 |
| served by some arm (cohort ≥ 2) | 231,531 |
| **zero-candidate residual — the lexical axis's addressable market** | **32,956 (12.5%)** |

**Documents whose neighbors exist ONLY because of this session's arms: 10,954**

| arm | newly served |
|---|---|
| dotless → decimal location | 4,484 |
| central-files-named → class | 3,915 |
| CFPF → film segment | 1,622 |
| RG-59 → series | 933 |

Keyed (before the cohort-≥2 cut): dotless 4,738 · cf-named-with-class 4,409 · CFPF
film-shaped 3,283 (of 4,058 CFPF rows; 660 are bare `CFPF` with no identifier) · RG-59
real series 992.

## Approximations, stated

- The presidential-library arm is replicated by series equality; the real matcher is
  keyword + prefix, so its served set is approximate in both directions.
- The class-arm cohorts here count only central-files-named structured rows; the real
  matcher partners them with every row sharing the `decimal_class`, decimal-era rows
  included — so **3,915 is a floor**.
- Series matching is replicated by stripping a `, Box …` tail; the real clause is a
  comma-boundary prefix.
- `aliasNeighbors` (the collection-authority fallback) is not replicated; it can only
  shrink the residual further.

## What the residual is

The 32,956 are dominated by the citation kinds no routing fix can touch — `unrecognized`,
`previouslyPublished` (916, now served *outbound* by W-11 but with no archival cohort),
`foreignGovernmentArchive`, `namedFileSeries` rows whose names never repeat, and
cohort-of-one keys. This is the population W-17's lexical axis exists for, and 12.5% is
the number its value should be argued against — not §0.10's pre-arms figures.
