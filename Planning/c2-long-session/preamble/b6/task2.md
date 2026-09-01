# Task 2 — Person coverage in the FRUS corpus

Source: `persons`, `person_mentions`, `person_rollup`, `person_rollup_member`,
`person_cluster_candidate` in `/Users/jbotts/frus-analysis/frus-copy.db` (read-only), with
spot checks against the TEI in `/Users/jbotts/Development/frus/volumes/`.

## 1. What the person tables actually are

| table | rows | what it holds |
|---|---|---|
| `persons` | 62,931 | one row per person *per volume* — the volume's own index of names, with the biographical gloss the editors printed |
| `person_mentions` | 611,307 | one row per (volume, document, person\_ref) |
| `person_rollup` | 17,961 | cross-volume identities, reconciled from the 62,931 volume-local rows |
| `person_rollup_member` | 62,931 | the crosswalk (every volume-local person belongs to exactly one rollup) |
| `person_cluster_candidate` | 164 | pairs the reconciler flagged as *possibly* the same person and did not merge |

Two structural facts govern everything below.

**(a) `person_mentions` is a document-level flag, not an occurrence count.** All 611,307 rows
are distinct (volume, document, person) triples; no person appears twice for the same
document. So `person_rollup.mention_count` means *"number of documents in which this person
is tagged"*, not *"number of times this person is named"*. A memorandum that says
"Kissinger" forty times counts once. I verified `mention_count` is exactly reproducible by
recounting through `person_rollup_member` for the top rollups.

**(b) The layer exists only where the editors printed a names index.** `persons` covers
**285 of 552 volumes** and `person_mentions` **287 of 552**. This is not an indexing gap in
the app — it is a property of the TEI. Older volumes do use `<persName>`, but only unkeyed
in the dateline (`<persName type="from">`); modern volumes use `<persName corresp="#p_...">`
pointing into a `Names`/`Persons` list. `frus1861.xml` has 696 `persName` elements and
**zero** with a `ref`/`corresp`; `frus1958-60v07p1.xml` has 7,516, of which 4,635 are keyed.

The coverage is therefore sharply time-shaped:

| coverage decade | volumes | with person data | % |
|---|---|---|---|
| 1860s | 23 | 0 | 0% |
| 1870s | 14 | 1 | 7% |
| 1880s–1900s | 38 | 0 | 0% |
| 1910s | 44 | 14 | 31% |
| 1920s | 17 | 1 | 5% |
| 1930s | 49 | 6 | 12% |
| 1940s | 88 | 9 | 10% |
| **1950s** | 100 | 83 | **83%** |
| **1960s** | 69 | 69 | **100%** |
| **1970s** | 91 | 90 | **98%** |
| **1980s** | 13 | 13 | **100%** |

Where the layer exists it is dense: 115,634 of the 119,833 documents in those 287 volumes
(96.5%) carry at least one tagged person. Across the whole corpus that is 36.5% of documents.

## 2. The twenty most-tagged people

Ranked by `person_rollup.mention_count` (= documents tagged). `vols` is the number of
volumes the person is tagged in; the year columns are the first / median / last *document
date* of the documents they are tagged in.

| # | canonical name | docs | vols | first | median | last |
|---|---|---|---|---|---|---|
| 1 | Kissinger, Henry A. | 13,174 | 100 | 1961 | 1972 | 2015\* |
| 2 | Nixon, Richard M. | 10,268 | 148 | 1951 | 1971 | 2015\* |
| 3 | Rusk, David Dean | 8,855 | 92 | 1948 | 1964 | 1999 |
| 4 | Dulles, John Foster | 7,400 | 102 | 1918 | 1955 | 1979 |
| 5 | Eisenhower, Dwight D. | 6,127 | 137 | 1943 | 1956 | 1988 |
| 6 | Carter, James Earl ("Jimmy"), Jr. | 4,518 | 50 | 1971 | 1978 | 2024\* |
| 7 | Johnson, Lyndon Baines | 4,381 | 110 | 1954 | 1966 | 2015\* |
| 8 | Vance, Cyrus Roberts | 4,203 | 72 | 1960 | 1978 | 1987 |
| 9 | Kennedy, John F. | 4,144 | 58 | 1958 | 1962 | 2017\* |
| 10 | Bundy, McGeorge | 3,978 | 73 | 1952 | 1963 | 1982 |
| 11 | Johnson, Ural Alexis | 3,514 | 126 | 1951 | 1961 | 2015\* |
| 12 | Rogers, William Pierce | 3,504 | 71 | 1958 | 1971 | 2015\* |
| 13 | Brzezinski, Zbigniew K. | 3,486 | 34 | 1964 | 1978 | 2013\* |
| 14 | McNamara, Robert S. | 3,388 | 98 | 1958 | 1964 | 1999 |
| 15 | Gromyko, Andreĭ Andreevich | 3,290 | 143 | 1939 | 1970 | 2013\* |
| 16 | Dobrynin, Anatoly F. | 3,128 | 102 | 1951 | 1971 | 2015\* |
| 17 | Khrushchev, Nikita Sergeyevich | 3,047 | 87 | 1938 | 1961 | 1988 |
| 18 | Herter, Christian Archibald, Sr. | 3,017 | 66 | 1954 | 1959 | 1967 |
| 19 | Harriman, William Averell | 2,963 | 111 | 1943 | 1963 | 1980 |
| 20 | Haig, Alexander Meigs, Jr. | 2,825 | 74 | 1968 | 1972 | 1983 |

\* The 21st-century "last" dates are an artefact: those tags land on volume **prefaces**,
which are front matter dated at publication (Kissinger's five latest "documents" are all
`preface` pages from 2015). Read the median, not the last.

Concentration: the top 20 hold 99,210 of 604,315 rollup-attributed mentions (**16.4%**); the
top 100 hold 35.6%. The long tail is very long — 5,787 rollups have one mention or none, and
1,682 have none at all (indexed by an editor but never tagged in a document).

## 3. What this ranking supports

- **It is a reliable ranking of who the editors of the modern volumes indexed most often.**
  The counts are internally consistent, reproducible from the member crosswalk, and dense
  within the volumes that have the layer.
- **It supports document-level questions inside the covered volumes**: "in how many printed
  documents of 1969–76 is Dobrynin an indexed participant", "which volumes carry Harriman"
  (111 of them), "how wide is a figure's reach across compilations". Nixon's 148 volumes
  against Brzezinski's 34 is a real difference in breadth.
- **The identities are largely well reconciled.** Kissinger's two volume-local refs
  (`p_KHA1`, `p_KHA_1`) merge correctly; 12,834 of 17,961 rollups carry an external
  authority id and 3,198 a VIAF id.
- **It distinguishes people the surname alone cannot**: Lyndon B. Johnson (4,381) and
  U. Alexis Johnson (3,514) are separate rollups, which no string search would give you.

## 4. What this ranking does *not* support

**(a) It is not "who appears most in FRUS". It is "who appears most in the half of FRUS that
came with an index."** The single sharpest demonstration:

> **William Henry Seward** — Lincoln's Secretary of State and the author or recipient of a
> large share of the 11,250 documents dated in the 1860s — has **1 tagged mention**, in
> 1 volume. His name appears in the body text of **9,824 documents**. Theodore Roosevelt has
> **0**. John Hay has **11**. Charles Evans Hughes has **7**. Cordell Hull, the
> longest-serving Secretary of State in American history, has **361**.

By contrast Kissinger's 13,174 tagged documents sit against 13,391 documents whose text
contains "Kissinger" — near-complete. The layer is essentially complete for the Cold War and
essentially absent before it. Any cross-era comparison drawn from this table is measuring
editorial indexing practice, not historical prominence.

Ranking within era bands makes the same point from the other side:

| band | top tagged names |
|---|---|
| 1861–1899 | Fish 289, "Frederick F. Low" 37, "Sir Edward Thornton" 29 — essentially the two `frus1873p1` volumes alone, and note the different name format |
| 1900–1939 | Lansing 2,319, Page 1,417, Francis 815 — driven by the WWI supplements, which happen to be indexed |
| 1940–1959 | J. F. Dulles 7,218, Eisenhower 5,097, Eden 2,690 |
| 1960–1988 | Kissinger 13,091, Nixon 9,763, Rusk 8,688 |

Lansing at #2 for 1900–39 is not evidence that Lansing mattered more than Hughes or Kellogg;
it is evidence that the 1914–20 supplements were indexed and the 1920s volumes were not.

**(b) It is not a count of how often a person is named.** One row per document. A person
mentioned once in passing and a person who is the subject of a 40-page memorandum score the
same. Comparing two people's counts compares their spread across documents, not their
weight in the record.

**(c) ~4.6% of the mentions are not in printed documents at all.** 25,929 mentions fall on
editor-written editorial notes and 2,228 on front matter (prefaces, "About the Series"). The
editorial-note share is itself era-skewed — editorial notes are almost entirely a 1940–79
phenomenon — so it inflates exactly the people already inflated.

**(d) The identity reconciliation is good but not perfect, and it says so.** 164 pairs are
flagged as unresolved candidates, including `Carter, James Earl ("Jimmy"), Jr.` vs
`Carter, James "Chip,"`, `Stettinius, Edward R.` vs `Stettinius, Edward Reilly, Jr.`, and
`Hull, Cordell` vs `Hull, Cordell, Secretary of State`. Unflagged failures exist too:
`Dulles, Allen W.` (2,513) and `Dulles, Alan W.` (4) are one man. The top 20 are not
materially affected, but a count taken from further down the list may be split across two
rollups. There are 62,931 volume-local person rows but only 25,712 distinct lower-cased
names, so the reconciliation is doing a great deal of work.

**(e) Small integrity residue.** 6,288 of 611,307 mentions (1.0%) point at a `person_ref`
with no matching row in that volume's `persons` list, so they carry no name and fall out of
the rollup totals (611,307 mentions vs 604,315 rollup-attributed).

**(f) The gloss is the editors', and it is a snapshot.** `person_rollup.description` carries
one role string per identity — Rusk's reads "Assistant Secretary of State for Far Eastern
Affairs", not "Secretary of State"; J. F. Dulles's reads "Adviser, United States Delegation".
These are whatever the reconciler picked from among the volume-local glosses, and they
should not be read as the person's principal office. Some `role` strings are visibly damaged
by year extraction ("Secretary of State from January 21, , until January 20, 1953").

## 5. The one-sentence version

The person tables give a dense, trustworthy, document-level map of who the State Department
Historian's Office indexed in the volumes covering roughly 1950–1988, and they give almost
nothing at all for the ninety years before that — so the top-twenty list is a portrait of
Cold War compilation practice that happens to be shaped like a list of important people.
