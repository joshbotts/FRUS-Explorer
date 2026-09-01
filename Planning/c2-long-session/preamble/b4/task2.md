# Task 2 — Person coverage in the FRUS corpus

## 1. What the person tables are

Four tables, and it matters which is which.

| Table | Rows | What a row is |
|---|---:|---|
| `persons` | 62,931 | One person **as listed in one volume's editorial "Persons" list** — the back-of-book identification list. Keyed `(volume_id, ref)` where `ref` is the TEI `xml:id`, e.g. `p_KHA1`. |
| `person_mentions` | 611,307 | One **(volume, document, person)** triple. Verified: all 611,307 are distinct triples, so this is a *document count*, not an occurrence count. Ten uses of a name in one memo are one row. |
| `person_rollup` | 17,961 | A canonical person, merging that person's per-volume entries into one identity, with a precomputed `mention_count`. |
| `person_rollup_member` | 62,931 | The crosswalk: every `persons` row maps to exactly one rollup. |
| `person_cluster_candidate` | 164 | Pairs the rollup process **declined to merge** and flagged for review. |

I checked the TEI to see where this comes from. Both layers are **editorial markup, not
name extraction**. `persons` is parsed from a
`<div type="section" subtype="index" xml:id="persons">` at the front of a volume;
`person_mentions` is parsed from inline `<persName corresp="#p_KHA1">` tags the editors
placed in the document text. Nothing here is inferred from the prose.

`person_rollup.mention_count` is exact — for the top five rollups it reproduces the raw
join over `person_mentions` to the row (Kissinger 13,174 = 13,174, Nixon 10,268 =
10,268, etc.), so the stored figure can be used directly.

## 2. The twenty most-mentioned people

Ranked by `mention_count` = number of distinct documents in which the person is
tagged. "Median year" is the median document date of those documents, front matter
excluded.

| # | Person | Documents | Volumes | Median doc year | Range |
|---:|---|---:|---:|---:|---|
| 1 | Kissinger, Henry A. | 13,174 | 99 | 1972 | 1961–1988 |
| 2 | Nixon, Richard M. | 10,268 | 143 | 1971 | 1951–1988 |
| 3 | Rusk, David Dean | 8,855 | 92 | 1964 | 1948–1980 |
| 4 | Dulles, John Foster | 7,400 | 99 | 1955 | 1918–1979 |
| 5 | Eisenhower, Dwight D. | 6,127 | 135 | 1956 | 1943–1988 |
| 6 | Carter, James Earl ("Jimmy"), Jr. | 4,518 | 49 | 1978 | 1971–1988 |
| 7 | Johnson, Lyndon Baines | 4,381 | 101 | 1966 | 1954–1988 |
| 8 | Vance, Cyrus Roberts | 4,203 | 71 | 1978 | 1960–1987 |
| 9 | Kennedy, John F. | 4,144 | 52 | 1962 | 1958–1988 |
| 10 | Bundy, McGeorge | 3,978 | 72 | 1963 | 1952–1982 |
| 11 | Johnson, Ural Alexis | 3,514 | 119 | 1961 | 1951–1988 |
| 12 | Rogers, William Pierce | 3,504 | 68 | 1971 | 1958–1988 |
| 13 | Brzezinski, Zbigniew K. | 3,486 | 32 | 1978 | 1964–1987 |
| 14 | McNamara, Robert S. | 3,388 | 95 | 1964 | 1958–1982 |
| 15 | Gromyko, Andreĭ Andreevich | 3,290 | 134 | 1970 | 1939–1988 |
| 16 | Dobrynin, Anatoly F. | 3,128 | 100 | 1971 | 1951–1988 |
| 17 | Khrushchev, Nikita Sergeyevich | 3,047 | 82 | 1961 | 1938–1988 |
| 18 | Herter, Christian Archibald, Sr. | 3,017 | 64 | 1959 | 1954–1967 |
| 19 | Harriman, William Averell | 2,963 | 106 | 1963 | 1943–1980 |
| 20 | Haig, Alexander Meigs, Jr. | 2,825 | 72 | 1972 | 1968–1983 |

Together they account for 99,210 of 604,315 tagged mentions — **16.4%** of the whole
person layer across 20 of 17,961 identities.

**Not one of the twenty has a median document year before 1955.** The list is
seventeen Americans, three Soviets, no one from the nineteenth century, and no one
whose career centred on either world war.

## 3. What this ranking can support

- **Who dominates the Cold War half of the printed record, in the editors' own
  judgement.** These are the people the compilers thought a reader would need
  identified, and marked accordingly. That is a real and interesting editorial fact.
- **A shape of attention within the modern volumes.** The distribution is extremely
  steep: 76 people (0.4% of identities) hold 193,174 mentions (32%); 988 people (5.5%)
  hold roughly three-quarters. 1,682 rollups have a `mention_count` of zero — listed in
  a volume's Persons index but never tagged in any document.
- **A contrast between concentration and breadth.** Re-ranking by *volumes appeared in*
  produces a different and more revealing list: Nixon (148 volumes), Gromyko (143),
  Eisenhower (137), U. Alexis Johnson (126), and then career officers who never enter
  the mention-count top twenty at all — Charles Bohlen (113 volumes, 1,275 mentions),
  Robert Murphy (100), Paul Nitze (97), Richard Helms (97). Depth in a few volumes and
  presence across many are different things, and this data distinguishes them.
- **A navigational index.** 12,834 rollups carry an authority id and 3,198 a VIAF id,
  so the layer joins to external biographical authorities.

## 4. What this ranking cannot support — four reasons, each measured

**(a) It covers only about half the corpus, and not a random half.**
Person markup exists in **287 of 552 volumes**, touching **115,634 of 316,839
documents (36.5%)**. The gap is systematic. By volume coverage decade:

| Coverage decade | Volumes | With person markup | Mentions |
|---|---:|---:|---:|
| pre-1860 (6 retrospective vols) | 6 | 1 (17%) | 454 |
| 1860s | 23 | 0 (0%) | 0 |
| 1870s–1900s | 52 | 1 (2%) | 494 |
| 1910s | 44 | 14 (31%) | 26,192 |
| 1920s | 17 | 1 (5%) | 864 |
| 1930s | 49 | 6 (12%) | 13,917 |
| 1940s | 88 | 9 (10%) | 25,930 |
| 1950s | 100 | 83 (83%) | 190,653 |
| 1960s | 69 | 69 (100%) | 142,102 |
| 1970s | 91 | 90 (98%) | 179,386 |
| 1980s | 13 | 13 (100%) | 31,315 |

89% of all mentions come from volumes covering 1950 or later. The nineteenth century
contributes essentially nothing.

**(b) The real driver is when the volume was *printed*, not what it is about.**

| Publication decade | Volumes | With person markup |
|---|---:|---:|
| 1860s–1970s | 289 | 32 (11%) |
| 1980s | 54 | 47 (87%) |
| 1990s | 73 | 73 (100%) |
| 2000s | 54 | 54 (100%) |
| 2010s | 68 | 68 (100%) |
| 2020s | 14 | 13 (93%) |

Person-name tagging became standard editorial practice around 1983 and has been
universal since. The exceptions are a scattered set of older volumes retro-encoded to
the modern standard — the 1914–19 supplements (printed 1928–37), the 1932 volumes
(1947–48), Malta/Yalta, Berlin, Cairo–Tehran. So a ranking over this layer is close to
a ranking over *volumes produced after 1983*.

**(c) Even inside a marked-up volume, markup recall varies enormously by person — and
it varies in the direction that makes the ranking self-confirming.** Comparing tagged
documents against documents whose full text contains the surname:

| Person | Documents naming them (FTS) | Tagged | Recall |
|---|---:|---:|---:|
| Kissinger | 13,391 | 13,174 | 98% |
| Khrushchev | 3,507 | 3,047 | 87% |
| Gromyko | 4,158 | 3,290 | 79% |
| Brzezinski | 4,742 | 3,628 | 77% |
| **Acheson** | **9,343** | **2,486** | **27%** |
| **Stimson** | 3,149 | 807 | 26% |
| **Stettinius** | 2,361 | 432 | 18% |

Acheson is named in 9,343 documents — more than Rusk's tagged total — yet ranks 28th
on this list. The people whose careers fall in the under-marked-up decades are
under-counted by a factor of three or four, so the ranking partly *manufactures* the
Cold War skew it appears to discover.

This shows in the absentees. Truman ranks 71st (1,042), Churchill 72nd (1,040),
Stalin 70th (1,045), **Franklin Roosevelt 124th (717)**, George Marshall 138th (649),
Woodrow Wilson 167th (573), **Cordell Hull 278th (361)**. Nobody should conclude from
this that FRUS documents Zbigniew Brzezinski five times as heavily as Franklin
Roosevelt; the 1940s volumes were simply printed before the tagging convention existed.

**(d) Identities are imperfectly consolidated, and the errors are not symmetric.**
`person_cluster_candidate` holds 164 pairs the merge process refused to join — e.g.
`Matthews, H. Freeman, Jr.` (7) against `Harrison Freeman Matthews ("Doc")` (913), and
`Stettinius, Edward R.` (7) against `Stettinius, Edward Reilly, Jr.` (425). Others are
not flagged at all: `Truman, Harry S.` (1,042) and `Truman, Harry` (120) are two
separate rollups. Surnames are widely split — 54 distinct `Johnson` rollups, 86
`Smith`, 19 `Carter`, 12 `Kennedy`. Splitting depresses counts, and it depresses them
most for people who appear across many volumes under varying forms of their name,
which again means older and less-famous figures. The 6,288 mention rows whose
`person_ref` matches no `persons` row are dropped from every rollup total.

## 5. How to use it safely

The honest one-line reading is: **this is a ranking of who the Office of the
Historian's post-1983 editors chose to tag, in the volumes they tagged.** It is
excellent evidence about editorial practice and about the Cold War volumes, and it is
not a measure of who appears most in the Foreign Relations series.

For a corpus-wide question about a person, use full-text search over `frus_documents`
and accept homonym noise, or restrict a person-table query to the 287 marked-up volumes
and state that restriction. Comparing two people is only defensible when both careers
sit inside the same markup regime — Kissinger against Brzezinski is fair; Kissinger
against Hull is not.
