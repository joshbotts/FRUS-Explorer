# Task 1 — Chronological coverage of the FRUS corpus

Source: `document_dates` joined to `document_cache` in the local search-index copy
(`/Users/jbotts/frus-analysis/frus-copy.db`, read-only). 316,839 document records across
552 volumes; ~1.35 billion characters of body text.

## 1. What is being counted

`document_dates` carries one row per indexed document, with `date_iso` (earliest),
`date_iso_max` (latest), a precision and a certainty. Coverage of the date field is very
high: **314,676 of 316,839 rows (99.3%) carry a date**, and 299,568 of those (95.2%) are
`day`/`exact` — a single calendar day, `date_iso == date_iso_max`. The remainder:

| precision / certainty | rows | mean span |
|---|---|---|
| day / exact | 299,568 | 0 days |
| day / range | 12,385 | 770 days |
| day / approximate | 2,420 | 136 days |
| month / exact | 251 | 23 days |
| year / exact | 52 | 270 days |
| (no date) | 2,163 | — |

I bucketed on `date_iso` (the earliest bound), which is the honest choice for the 95% that
are single-day and a defensible one for the rest, but it does push multi-year documents
into their opening decade.

Two contaminants had to be identified before the table means anything:

- **Front matter is dated at publication, not at coverage.** All 40 documents dated 2000 or
  later are `is_front_matter = 1` — "About the Series" and "Preface" pages carrying the
  month the volume was released (e.g. `frus1977-80v04/about-the-series`, 2024-03). They are
  editorial apparatus with a 21st-century date sitting in a 20th-century volume.
- **The pre-1840 tail is documentary annex, not coverage.** The 27 documents dated before
  1840 come from two volumes only: `frus1872p2v*` (the Geneva Arbitration / Alabama Claims
  case papers) and `frus1902app2` (the Pious Fund arbitration). The oldest, 1620-11-03, is
  an exhibit in a 19th-century international-law brief. The series does not "cover" the 17th
  century; it reprints 17th-century evidence inside a 19th-century case file.

Undated rows (2,163, 0.7%) are concentrated in `frus1919Parisv13` (168 — the Paris Peace
Conference index/appendix volume) and in wartime volumes; 823 of the 2,163 are front matter.

## 2. Documents per decade of document date

Excluding front matter, splitting out editor-written notes:

| decade | body docs | editorial notes | contributing volumes | docs/volume | mean chars/doc | M chars | % of corpus text |
|---|---|---|---|---|---|---|---|
| pre-1860 | 462 | 1 | 12 | — | — | ~2 | <1% |
| 1860s | 11,250 | 0 | 29 | 388 | 4,562 | 51 | 3% |
| 1870s | 5,798 | 0 | 25 | 232 | 8,037 | 47 | 3% |
| 1880s | 6,472 | 0 | 21 | 308 | 5,436 | 35 | 2% |
| 1890s | 9,712 | 0 | 22 | 441 | 3,719 | 36 | 2% |
| 1900s | 9,924 | 1 | 25 | 397 | 3,493 | 35 | 2% |
| 1910s | 30,359 | 11 | 52 | 584 | 2,805 | 85 | 6% |
| 1920s | 19,733 | 0 | 41 | 481 | 2,749 | 54 | 4% |
| 1930s | 39,196 | 1 | 58 | 675 | 2,575 | 101 | 7% |
| **1940s** | **74,043** | **1,637** | **104** | **727** | 3,261 | **246** | **18%** |
| 1950s | 42,654 | 3,852 | 123 | 378 | 5,148 | 239 | 17% |
| 1960s | 27,650 | 2,167 | 156 | 191 | 5,611 | 167 | 12% |
| 1970s | 22,641 | 623 | 108 | 215 | 7,794 | 181 | 13% |
| 1980s | 5,949 | 174 | 41 | 149 | 8,055 | 49 | 3% |
| 1990s | 177 | 0 | 2 | 89 | 10,133 | 1 | <1% |

Cumulative, over the 314,211 documents dated 1860 or later: 25% of the corpus falls by
**1922**, 50% by **1943**, 75% by **1954**, 90% by **1969**.

Per-year peak is **1945 (11,540 documents)**. The ten heaviest years are 1945, 1944, 1946,
1949, 1943, 1948, 1951, 1941, 1947, 1954 — every one of them between 1941 and 1954. The
eleven years 1939–1949 alone hold **25.7%** of the whole corpus; the fifty-three years
1861–1913 hold **15.5%**.

## 3. Shape of the distribution

A per-year histogram shows four features:

1. **A Civil War spike (1861–68, peaking 1865 at 2,767).** The earliest volumes are annual
   congressional submissions that printed the diplomatic correspondence more or less
   entire; the spike is wartime despatch traffic, not later editorial attention.
2. **A long, flat, low 1869–1913 plateau** (typically 400–1,400 documents a year, no trend).
3. **A World War I ridge (1914–1919, 3,300–5,900/yr)** and then a **1930s–40s ramp that runs
   almost monotonically from 2,256 in 1930 to 11,540 in 1945**, followed by a slow decline
   with a secondary shelf in 1948–54.
4. **A collapse after 1980** — 1,822 documents in 1980, then 407–842 a year through 1988,
   then effectively nothing.

## 4. What the shape does and does not tell you about editorial priorities

**It does show a real, large twentieth-century bias.** Half the corpus post-dates 1943. The
1940s alone carry 18% of the corpus's text in 10 of its ~130 covered years — roughly seven
times a proportional share. Even allowing for the fact that the volume of American
diplomatic traffic itself grew enormously, the series' documentary weight is concentrated
on the crisis decades: the Civil War, the two World Wars, and the early Cold War.

**But two of the most eye-catching features are artefacts of publication, not of judgement.**

- *The post-1980 collapse is publication lag, not de-prioritisation.* FRUS is still being
  published for those years. The manifest shows 66 volumes for the 1969–76 subseries and 35
  for 1964–68, but only **12 for 1981–88 and 1 for 1989–92**. Volume publication dates in
  this snapshot run from 1861 to **2025**, with 68 volumes printed in the 2010s and 14
  already in the 2020s. The 1980s bar is thin because the volumes do not exist yet.
- *The 1860s spike is partly a counting effect.* Those volumes average 388 documents each
  at 4,562 characters, and the "documents" are short despatches and their enclosures. The
  editorial unit is not constant across the series.

**The clearest genuine editorial finding is a change in the unit of publication, not in the
amount of attention.** Read the docs/volume and chars/doc columns together:

- 1930s–40s: ~700 documents per volume, ~2,600–3,300 characters each.
- 1960s–80s: ~150–215 documents per volume, ~5,600–8,100 characters each.

Between the 1930s and the 1970s the mean printed document roughly **triples in length**
while the number printed per volume **falls by two-thirds**. The interwar and wartime
volumes print large runs of short telegrams and despatches; the Cold War volumes print
fewer, much longer items — memoranda of conversation, NSC papers, intelligence estimates —
and select far more aggressively from a vastly larger records base. Total *text* per decade
is much flatter than total *documents*: the 1940s and 1950s carry 18% and 17% of the
corpus's characters despite the 1950s having 40% fewer documents.

**A second genuine finding: editor-written notes are a Cold War instrument.** Of 8,468
editorial notes, **8,279 (97.8%) are dated 1940–1979**, with the peak in the 1950s (3,852)
and 1960s (2,167). There is essentially none before 1940 — one in the 1900s, eleven in the
1910s, one in the 1930s. The modern compilers narrate; the nineteenth-century compilers
transcribed.

**A third: dating gets less certain as the record modernises.** The proportion of documents
whose date spans more than one day is under 2% for every decade from the 1880s to the 1930s,
then jumps to 3% (1940s), **8% (1950s), 8% (1960s)** and 5% (1970s). Cold War compilations
print more undated drafts, undated papers and multi-day meeting records — again a
consequence of what kind of document is being printed.

## 5. Caveats on this table

- The bucket is the document's *earliest* date; 12,385 range-dated documents (mostly 1945–75)
  are attributed to the start of their span.
- 2,163 documents (0.7%) have no date at all and appear nowhere in the table.
- Coverage decade is not volume decade: a volume nominally about 1952–54 contains documents
  dated earlier and later, and the arbitration volumes contain documents centuries older.
- All counts are of *indexed* documents in this local snapshot; the "1990s" row is one
  volume (`frus1989-92v31`, 235 documents) plus stray items.
