# Task 2 — Person coverage in the FRUS corpus

Source: `persons`, `person_mentions`, `person_rollup`, `person_rollup_member`,
`person_cluster_candidate` in the FRUS Explorer index, cross-checked against
`document_cache.body_text`.

## 1. What the person tables contain

| table | rows | meaning |
|---|---|---|
| `persons` | 62,931 (285 volumes, 25,712 distinct name strings) | one row per person *as listed in one volume's* index of persons |
| `person_rollup` | 17,961 | volume-local entries clustered into candidate single identities |
| `person_rollup_member` | 62,931 | the crosswalk; every `persons` row belongs to exactly one rollup |
| `person_mentions` | 611,307 | one row per (volume, document, person-ref) |
| `person_cluster_candidate` | 164 | pairs the clusterer suspected were one person but did **not** merge |

A "mention" is **a document in which the person is tagged**, not an occurrence of their name:
all 611,307 rows are distinct (volume, document, person) triples. `person_rollup.mention_count`
is therefore a *document count*. Median document carries 5.3 tagged persons; the maximum is 201.

Of the 611,307 mention rows, 604,315 resolve to a rollup; **6,288 do not**, because the volume
tags `persName` in its text but ships no index of persons to resolve the reference against
(`frus1932v04` alone accounts for 2,552 such orphans, `frus1918Supp01v02` for 2,114). Those
mentions are real but anonymous.

## 2. The twenty most frequently appearing people

Ranked by `mention_count` = number of distinct documents in which the person is tagged.
`vols` = number of volumes whose person index lists them. `viaf` = whether the rollup carries an
external VIAF authority identifier.

| # | canonical name | documents | vols | viaf |
|---|---|---|---|---|
| 1 | Kissinger, Henry A. | 13,174 | 100 | yes |
| 2 | Nixon, Richard M. | 10,268 | 148 | yes |
| 3 | Rusk, David Dean | 8,855 | 92 | no |
| 4 | Dulles, John Foster | 7,400 | 102 | yes |
| 5 | Eisenhower, Dwight D. | 6,127 | 137 | yes |
| 6 | Carter, James Earl ("Jimmy"), Jr. | 4,518 | 50 | yes |
| 7 | Johnson, Lyndon Baines | 4,381 | 110 | yes |
| 8 | Vance, Cyrus Roberts | 4,203 | 72 | yes |
| 9 | Kennedy, John F. | 4,144 | 58 | no |
| 10 | Bundy, McGeorge | 3,978 | 73 | no |
| 11 | Johnson, Ural Alexis (U. Alexis Johnson) | 3,514 | 126 | yes |
| 12 | Rogers, William Pierce | 3,504 | 71 | no |
| 13 | Brzezinski, Zbigniew K. | 3,486 | 34 | yes |
| 14 | McNamara, Robert S. | 3,388 | 98 | yes |
| 15 | Gromyko, Andreĭ Andreevich | 3,290 | 143 | yes |
| 16 | Dobrynin, Anatoly F. | 3,128 | 102 | yes |
| 17 | Khrushchev, Nikita Sergeyevich | 3,047 | 87 | yes |
| 18 | Herter, Christian Archibald, Sr. | 3,017 | 66 | yes |
| 19 | Harriman, William Averell | 2,963 | 111 | yes |
| 20 | Haig, Alexander Meigs, Jr. | 2,825 | 74 | yes |

Concentration: the top 20 hold 99,210 of 604,315 resolved mentions (**16.4%**); the top 100 hold
35.6%; the top 1,000 hold 73.8%. 1,682 rollups are listed in some volume's index but never tagged
in any document.

## 3. What this ranking CAN support

**(a) It is a reliable ranking within the part of the corpus that carries person markup.** Two
independent checks:

* *Precision.* Of the 13,174 documents tagged for Kissinger, 13,148 (99.8%) contain the string
  "Kissinger" in their body text. The tags are not noise.
* *Recall inside covered volumes.* Within the 100 volumes whose person index lists Kissinger,
  13,331 documents contain the string and 13,148 are tagged — **98.6% recall**. Where the
  apparatus exists, it is close to exhaustive.

**(b) Relative standing within a single era is meaningful.** Restricting to documents dated in the
1960s reproduces exactly the cast one would expect of that decade's policy record — Rusk (8,643),
Johnson (4,094), Kennedy (3,972), Bundy (3,934), McNamara (3,252), Rostow (2,686), Ball (2,303),
Harriman (2,183). Restricting to the 1910s produces a completely different and equally plausible
list — Lansing (2,316), Walter Hines Page (1,417), David R. Francis (815), Frank Polk (752),
Gerard (613), Wilson (562), Bryan (453). Within an era the counts behave.

**(c) It supports statements about the *shape* of the modern record**: that Cold War FRUS is
organised around a small number of executive-branch principals; that the National Security
Adviser (Kissinger 13,174; Bundy 3,978; Brzezinski 3,486; Rostow 2,711) is as central to the
edition as the Secretary of State; that the Soviet counterparts who recur most (Gromyko 3,290,
Dobrynin 3,128, Khrushchev 3,047, Brezhnev 2,213) do so at roughly a quarter of the American
principals' rate.

## 4. What this ranking CANNOT support

**(a) It is not a ranking over the corpus. Person markup exists in only 285 of 552 volumes, and
those volumes are almost entirely post-1950.** Share of dated documents that sit in a volume with
any person markup, by decade:

| decade | documents | in volumes with person data | % |
|---|---|---|---|
| 1860s | 11,250 | 51 | 0.5% |
| 1870s | 5,798 | 567 | 9.8% |
| 1880s | 6,472 | 0 | **0%** |
| 1890s | 9,712 | 0 | **0%** |
| 1900s | 9,925 | 0 | **0%** |
| 1910s | 30,370 | 12,708 | 41.8% |
| 1920s | 19,733 | 12 | 0.1% |
| 1930s | 39,197 | 4,658 | 11.9% |
| 1940s | 75,680 | 5,966 | 7.9% |
| 1950s | 46,506 | 35,757 | 76.9% |
| 1960s | 29,817 | 29,817 | **100%** |
| 1970s | 23,264 | 23,202 | 99.7% |
| 1980s | 6,123 | 6,085 | 99.4% |

119,071 of 315,827 non-front-matter documents (**37.7%**) sit in a volume with person markup.
**The ranking is a ranking of that 38%, and the 38% is the second half of the twentieth century.**

**(b) The absences are catastrophic and are not evidence of unimportance.** Three cases, each
checked against the raw text:

* **William H. Seward**, Secretary of State 1861–1869 and the author or addressee of a large
  fraction of the 33,220 documents dated 1861–1899, has **1 tagged mention**. His surname appears
  in 9,824 documents. On the raw text he would rank in the top ten; in this table he ranks
  roughly 14,000th.
* **Cordell Hull**, the longest-serving Secretary of State in American history (1933–1944), has
  **361 tagged mentions across 10 volumes**. 1,028 documents contain both "Cordell" and "Hull".
* **Franklin D. Roosevelt** has 717; **Woodrow Wilson** 573; **Elihu Root** 39; **John Hay** 11.

Any statement of the form "X is among the most-documented figures in FRUS" is, on this evidence,
a statement about post-1950 FRUS only. The correct reading of the table is: *these are the twenty
people most often tagged in the volumes that carry a person apparatus.*

**(c) Identity resolution is approximate, and the tables say so themselves.** The clusterer
records 164 pairs it declined to merge, including `Carter, James Earl ("Jimmy"), Jr.` vs
`Carter, James "Chip,"`, `Stimson, Henry Louis` vs `Stimson, Henry L., Secretary of War`, and
`Hull, Cordell` vs `Hull, Cordell, Secretary of State`. Independently visible splits include
`Dulles, Allen W.` (2,513) vs `Dulles, Alan W.` (4) — a spelling variant — and `Truman, Harry S.`
(1,042) vs `Truman, Harry` (120). Some flagged candidates are *false* (Hassan bin al Talal vs
Hussein bin Talal are different men), so the list cannot simply be applied. The effect on the top
20 is small but nonzero: counts are lower bounds, not exact.

**(d) `volume_count` and `mention_count` measure different things.** `volume_count` counts volumes
whose *index of persons* lists someone; mentions count volumes where they are actually tagged in a
document. Nixon is listed in 148 volumes but tagged in documents in 143. Do not read
`volume_count` as reach.

**(e) The `role` and `description` fields are not biographies.** They are inherited from one
constituent volume's person list and are frequently the person's role in *that* volume, not their
best-known office. Nixon's stored role reads "President from January until August 9, 1974";
Rusk's reads "Assistant Secretary of State for Far Eastern Affairs". Kissinger's 100 member rows
carry 64 distinct role strings, Nixon's 148 carry 42. Use them as evidence of how a volume
described someone, never as a canonical title.

**(f) Only 3,198 of 17,961 rollups (17.8%) carry a VIAF identifier and 12,834 (71.5%) carry any
authority id.** Four of the top twenty — Rusk, Kennedy, Bundy and Rogers — have no VIAF link, so
the table cannot be joined wholesale to an external biographical dataset.

## 5. Summary judgement

The person tables are high-quality *where they exist* — precise, near-exhaustive, and
era-internally consistent — and structurally absent everywhere before roughly 1950. The top-twenty
list is a sound answer to "who dominates the tagged portion of FRUS" and an actively misleading
answer to "who dominates FRUS". Any use of it in an argument needs the coverage table in §4(a)
printed beside it.
