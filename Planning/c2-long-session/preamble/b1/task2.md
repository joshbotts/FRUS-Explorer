# Task 2 — Person coverage in the FRUS corpus

Source: `frus-copy.db` tables `persons`, `person_mentions`, `person_rollup`,
`person_rollup_member`, `person_cluster_candidate`, joined to `document_dates` and
`document_cache`; verified against the TEI at `/Users/jbotts/Development/frus/volumes/`.

## 1. How the person data is built

| table | rows | what it is |
|---|---|---|
| `persons` | 62,931 | one row per person **per volume**, from that volume's TEI names index |
| `person_mentions` | 611,307 | links between a document and a person ref |
| `person_rollup` | 17,961 | volume-local persons reconciled into one identity across volumes |
| `person_rollup_member` | 62,931 | which volume-local person belongs to which rollup |
| `person_cluster_candidate` | 164 | pairs the reconciler suspected were the same person and did **not** merge |

**A "mention" is a document, not an occurrence.** `(volume_id, document_id, person_ref)` is unique
across all 611,307 rows — I checked. Spot-checking `frus1969-76v01` against its TEI: the XML holds
1,454 `persName corresp="#…"` occurrences, which collapse to 364 mention rows. So a count of 13,174
for Kissinger means *13,174 documents name him*, and the number of times his name appears in the
corpus is several times larger.

## 2. The twenty most-mentioned people

Ranked by documents mentioning them. `volumes` is the number of volumes whose names index lists
them; `span` is the first and last **document date** on which they are mentioned, front matter
excluded.

| # | person | documents | volumes | span |
|---|---|---|---|---|
| 1 | Kissinger, Henry A. | 13,174 | 100 | 1961–1988 |
| 2 | Nixon, Richard M. | 10,268 | 148 | 1951–1988 |
| 3 | Rusk, David Dean | 8,855 | 92 | 1948–1980 |
| 4 | Dulles, John Foster | 7,400 | 102 | 1918–1979 |
| 5 | Eisenhower, Dwight D. | 6,127 | 137 | 1943–1988 |
| 6 | Carter, James Earl ("Jimmy"), Jr. | 4,518 | 50 | 1971–1988 |
| 7 | Johnson, Lyndon Baines | 4,381 | 110 | 1954–1988 |
| 8 | Vance, Cyrus Roberts | 4,203 | 72 | 1960–1987 |
| 9 | Kennedy, John F. | 4,144 | 58 | 1958–1988 |
| 10 | Bundy, McGeorge | 3,978 | 73 | 1952–1982 |
| 11 | Johnson, Ural Alexis | 3,514 | 126 | 1951–1980 |
| 12 | Rogers, William Pierce | 3,504 | 71 | 1958–1984 |
| 13 | Brzezinski, Zbigniew K. | 3,486 | 34 | 1964–1987 |
| 14 | McNamara, Robert S. | 3,388 | 98 | 1958–1982 |
| 15 | Gromyko, Andreĭ Andreevich | 3,290 | 143 | 1939–1988 |
| 16 | Dobrynin, Anatoly F. | 3,128 | 102 | 1951–1988 |
| 17 | Khrushchev, Nikita Sergeyevich | 3,047 | 87 | 1938–1988 |
| 18 | Herter, Christian Archibald, Sr. | 3,017 | 66 | 1954–1967 |
| 19 | Harriman, William Averell | 2,963 | 111 | 1943–1980 |
| 20 | Haig, Alexander Meigs, Jr. | 2,825 | 74 | 1968–1983 |

One correction the table needs: **Brzezinski is split**. A second rollup, `Brzezinski, Zbignew K.`
(a misspelling carried through one volume's names list), holds a further 141 documents. Merged, he
has 3,627 and moves from 13th to 11th. Merging it does not change *which* twenty people are on the
list — the twentieth and twenty-first places are Haig (2,825) and Dillon (2,777).

## 3. What this ranking can support

- **It is an accurate ranking of the corpus's person *index*.** The stored `mention_count` matches
  a live recount from `person_mentions` for every one of the top twenty (one off-by-one, U. Alexis
  Johnson, 3,514 stored vs 3,515 counted).
- **It identifies who the modern volumes are about.** Every name is a principal of US foreign
  policy or a Soviet counterpart between roughly 1950 and 1988, and the concentration is real
  within that window: the top 20 hold 99,210 of 604,315 attributed mentions (16.4%), the top 100
  hold 35.6%. The median person in the index is mentioned in 4 documents; 4,105 people are
  mentioned exactly once.
- **It supports "who is co-present with whom" and "in which volumes"** — the mention table is
  document-keyed, so it can be joined to dates, volumes, subjects and sources.

## 4. What this ranking cannot support

**a) It is not a ranking over the corpus. Person indexing exists for barely half the volumes.**

Only **287 of 552 volumes** contribute any person mention, and coverage is a function of *when the
volume was edited*, not of the period it covers:

| coverage decade | volumes | with person links | |
|---|---|---|---|
| 1860s | 23 | 0 | 0% |
| 1870s | 14 | 1 | 7% |
| 1880s–1900s | 38 | 0 | 0% |
| 1910s | 44 | 14 | 32% |
| 1920s | 17 | 1 | 6% |
| 1930s | 49 | 6 | 12% |
| 1940s | 88 | 9 | 10% |
| 1950s | 100 | 83 | 83% |
| 1960s | 69 | 69 | 100% |
| 1970s | 91 | 90 | 99% |
| 1980s | 13 | 13 | 100% |

Measured at document grain the discontinuity is the same. The share of documents carrying at least
one person link runs 0.1% (1860s), 0% (1880s–1900s), 40.3% (1910s), 11.3% (1930s), **7.4% (1940s)**,
then 74.0%, 97.6%, 97.9%, 97.2% for the 1950s–1980s. In total only **115,634 of 316,839 documents
(36.5%)** carry any person link at all, and 87% of all mentions sit in documents dated 1950–1989.

The consequence is blunt: the ranking is a ranking of FRUS *1950–1988*, presented as if it were a
ranking of a corpus that begins in 1861. **William Henry Seward — Secretary of State for the whole
of the corpus's first decade, 11,250 documents — has one mention.** Cordell Hull, Secretary of
State 1933–1944, has 361 across 10 volumes. Franklin Roosevelt has 717. These are not findings
about their importance; they are findings about which volumes carry a names index.

That the ranking is period-bound is easy to demonstrate. Restrict to documents dated in a single
window and a different cast appears:

- **1910–1919:** Lansing 2,316 · Page 1,417 · Francis 815 · Polk 752 · Gerard 613 · Wilson 562 ·
  Bryan 453 · Grey 407.
- **1930–1949:** Stalin 839 · Molotov 750 · Stimson 718 · F. D. Roosevelt 658 · Clay 568 ·
  Bevin 539 · Murphy 508 · Marshall 507.

Robert Lansing, the leading figure of the only well-indexed pre-war decade, does not appear
anywhere in the corpus-wide top twenty.

**b) It is a count of *editorial indexing*, not of appearance in the record.** A person is counted
when a FRUS editor tagged a `persName` with a `corresp` link. Undertagging is measurable: 9,219 of
62,931 volume-level person entries (14.6%) are listed in a volume's names index and never linked to
a single document in it.

**c) Identity reconciliation is imperfect in both directions.** Beyond the Brzezinski split, the
reconciler itself flagged 164 pairs it declined to merge and left in place — including
`Hull, Cordell` / `Hull, Cordell, Secretary of State`, `Stimson, Henry Louis` /
`Stimson, Henry L., Secretary of War`, and `Stettinius, Edward R.` (7) / `Stettinius, Edward
Reilly, Jr.` (425). Conversely, 1,682 rollups have zero mentions, and merges span up to 148
volume-local records for a single person, so any error propagates widely. Two rollups are
distinguished only by a middle initial in several places (`Dulles, Alan W.` 4 vs `Dulles,
Allen W.` 2,513) — a form the ranking would silently get wrong if the split had been larger.

**d) 6,288 mentions (1.0%) are attributable to nobody.** They point to `corresp` refs that appear
in no volume's names index. Four volumes account for 5,984 of them because they carry in-text
person links but *no names list at all*: `frus1932v04` (2,552), `frus1918Supp01v02` (2,114),
`frus1917Supp02v02` (864), `frus1873p1v2` (454). In `frus1918Supp01v02` the busiest orphan ref,
`p_LR1`, has 291 documents — almost certainly Robert Lansing, invisible to every rollup query.

**e) "Mentions" says nothing about role.** The table cannot distinguish the author of a telegram
from a person named once in its text, and it does not weight by document length. Kissinger's 13,174
documents include those he wrote, those addressed to him, and those that mention him in passing.

## 5. The honest one-line statement

*Across the 287 of 552 FRUS volumes that carry an editorial names index — in practice the volumes
covering 1950 onward — Henry Kissinger is named in more documents (13,174) than anyone else, ahead
of Nixon (10,268) and Dean Rusk (8,855). The ranking describes the indexed half of the corpus and
should not be read as a statement about the series as a whole, in which the entire nineteenth
century and most of the Second World War are unindexed.*
