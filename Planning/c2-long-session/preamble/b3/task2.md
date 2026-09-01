# Task 2 — Person coverage of the corpus

## 0. Coverage statement

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note)
FROM document_cache;
-- 552 volumes | 316,839 documents | 1,012 front matter | 8,468 editorial notes
```
All 552 volumes are present. Every number below is nevertheless conditional on this local index.

## 1. What the four person tables are

```sql
SELECT 'persons', COUNT(*), COUNT(DISTINCT volume_id) FROM persons
UNION ALL SELECT 'person_mentions', COUNT(*), COUNT(DISTINCT volume_id) FROM person_mentions
UNION ALL SELECT 'person_rollup', COUNT(*), NULL FROM person_rollup
UNION ALL SELECT 'person_rollup_member', COUNT(*), COUNT(DISTINCT volume_id) FROM person_rollup_member
UNION ALL SELECT 'person_cluster_candidate', COUNT(*), NULL FROM person_cluster_candidate;
```

| table | rows | volumes |
|---|---|---|
| `persons` (per-volume list entries) | 62,931 | **285** |
| `person_mentions` (document ↔ person) | 611,307 | **287** |
| `person_rollup` (name clusters) | 17,961 | — |
| `person_rollup_member` | 62,931 | 285 |
| `person_cluster_candidate` (proposed, unmerged) | 164 | — |

**`person_mentions` is a document-presence table, not an occurrence count.**

```sql
SELECT COUNT(*), COUNT(DISTINCT volume_id||'|'||document_id||'|'||person_ref) FROM person_mentions;
-- 611,307 | 611,307
```
Every row is a distinct (volume, document, person) triple. A person named forty times in one
memorandum of conversation contributes one row. Measured against the TEI for `frus1969-76v17`:

```
persName tags in the XML:              13,825
of those carrying a corresp pointer:   12,352  (to 234 distinct person ids)
rows in person_mentions for that volume: 2,491 (228 persons over 281 documents)
```
So the index compresses roughly **12,352 tagged occurrences into 2,491 rows — about 5:1**. Any
sentence of the form "X is mentioned N times" is wrong; the correct sentence is "X is tagged in N
documents."

## 2. The coverage that governs everything else

**Only 287 of 552 volumes carry any tagged person at all**, and 285 carry a person list.

```sql
SELECT (SELECT COUNT(DISTINCT volume_id) FROM persons),
       (SELECT COUNT(DISTINCT volume_id) FROM person_mentions),
       (SELECT COUNT(*) FROM (SELECT volume_id FROM person_mentions EXCEPT SELECT volume_id FROM persons)),
       (SELECT COUNT(*) FROM (SELECT volume_id FROM persons EXCEPT SELECT volume_id FROM person_mentions));
-- 285 | 287 | 4 with mentions but no list | 2 with a list but no mentions
```

And the tagged volumes are almost all modern. Assigning each volume to the modal decade of its
documents' `frus:doc-dateTime-min`:

```sql
-- modal decade per volume, left-joined to per-volume mention counts
```
| modal decade | volumes | volumes with mentions | mention rows |
|---|---|---|---|
| 1840 | 1 | 0 | 0 |
| 1860 | 20 | 0 | 0 |
| 1870 | 17 | 2 | 948 |
| 1880 | 11 | 0 | 0 |
| 1890 | 15 | 0 | 0 |
| 1900 | 14 | 0 | 0 |
| 1910 | 40 | 15 | 27,056 |
| 1920 | 24 | 0 | 0 |
| 1930 | 47 | 6 | 13,917 |
| 1940 | 91 | 10 | 30,100 |
| 1950 | 98 | 81 | 184,256 |
| 1960 | 67 | 67 | 139,779 |
| 1970 | 92 | 91 | 178,414 |
| 1980 | 14 | 14 | 35,023 |
| 1990 | 1 | 1 | 1,814 |

**Before 1950: 33 of 280 volumes tagged. From 1950 on: 254 of 272.** 539,286 of 611,307 mention
rows (88.2%) sit in volumes whose modal decade is 1950 or later. There is no person data at all for
the 1860s, 1880s, 1890s, 1900s or 1920s.

At document grain:

```sql
SELECT (SELECT COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0
          AND volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')),
       (SELECT COUNT(DISTINCT pm.volume_id||'/'||pm.document_id) FROM person_mentions pm
         JOIN document_cache c ON c.volume_id=pm.volume_id AND c.document_id=pm.document_id
         WHERE c.is_front_matter=0 AND c.is_editorial_note=0
           AND pm.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2'));
-- 306,619 in-scope documents | 108,581 carry at least one person tag
```
**108,581 of 306,619 documents (35.4%).** Two documents in three carry no person tag whatever.

## 3. Cleaning applied before ranking

Three corrections to the stored counts, each of which moves the answer:

1. **The duplicate second editions are counted twice by the stored figures.**
   ```sql
   SELECT volume_id, COUNT(*) FROM person_mentions
   WHERE volume_id LIKE '%Ed2%' OR volume_id IN ('frus1951-54Iran','frus1969-76ve15p2','frus1977-80v09')
   GROUP BY 1;
   -- frus1951-54Iran 1,962 | frus1951-54IranEd2 1,974
   -- frus1969-76ve15p2 2,198 | frus1969-76ve15p2Ed2 2,415 | frus1977-80v09Ed2 4,011
   ```
   4,389 duplicate rows. `frus1977-80v09Ed2` is retained (no first edition present).
2. **28,157 of 611,307 mention rows land on front matter or editorial notes** and are excluded.
3. **6,288 mention rows in 20 volumes point at a `person_ref` with no entry in that volume's list**,
   so they join to no rollup and are invisible to any rollup ranking.
   ```sql
   SELECT COUNT(*), COUNT(DISTINCT pm.volume_id) FROM person_mentions pm
   LEFT JOIN person_rollup_member m ON m.volume_id=pm.volume_id AND m.ref=pm.person_ref
   WHERE m.rollup_id IS NULL;   -- 6,288 | 20
   ```

Reconciliation: 611,307 rows → 605,019 join to a rollup → **572,593 after excluding apparatus and
the two duplicate editions**. (`SUM(person_rollup.mention_count)` is 604,315, i.e. 704 short of the
live join — the stored counts are marginally stale. I used the live join.)

## 4. The twenty most-tagged people

```sql
WITH live AS (
  SELECT m.rollup_id, COUNT(*) AS mentions, COUNT(DISTINCT pm.volume_id) AS vols
  FROM person_mentions pm
  JOIN person_rollup_member m ON m.volume_id=pm.volume_id AND m.ref=pm.person_ref
  JOIN document_cache c ON c.volume_id=pm.volume_id AND c.document_id=pm.document_id
  WHERE pm.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
    AND c.is_front_matter=0 AND c.is_editorial_note=0
  GROUP BY 1)
SELECT ROW_NUMBER() OVER (ORDER BY live.mentions DESC), r.canonical_name,
       live.mentions, ROUND(100.0*live.mentions/572593,2), live.vols,
       r.mention_count AS stored, r.volume_count AS stored_vols
FROM live JOIN person_rollup r USING (rollup_id)
ORDER BY live.mentions DESC LIMIT 20;
```

| # | person | documents tagged | of 572,593 | volumes | stored count (uncleaned) |
|---|---|---|---|---|---|
| 1 | Kissinger, Henry A. | 12,044 | 2.10% | 98 | 13,174 |
| 2 | Nixon, Richard M. | 9,264 | 1.62% | 136 | 10,268 |
| 3 | Rusk, David Dean | 8,357 | 1.46% | 92 | 8,855 |
| 4 | Dulles, John Foster | 6,735 | 1.18% | 98 | 7,400 |
| 5 | Eisenhower, Dwight D. | 5,219 | 0.91% | 133 | 6,127 |
| 6 | Carter, James Earl ("Jimmy"), Jr. | 4,251 | 0.74% | 48 | 4,518 |
| 7 | Vance, Cyrus Roberts | 4,059 | 0.71% | 71 | 4,203 |
| 8 | Johnson, Lyndon Baines | 3,920 | 0.68% | 99 | 4,381 |
| 9 | Kennedy, John F. | 3,720 | 0.65% | 52 | 4,144 |
| 10 | Bundy, McGeorge | 3,706 | 0.65% | 72 | 3,978 |
| 11 | Johnson, Ural Alexis | 3,390 | 0.59% | 118 | 3,514 |
| 12 | Brzezinski, Zbigniew K. | 3,367 | 0.59% | 32 | 3,486 |
| 13 | Rogers, William Pierce | 3,200 | 0.56% | 66 | 3,504 |
| 14 | McNamara, Robert S. | 3,151 | 0.55% | 94 | 3,388 |
| 15 | Gromyko, Andreĭ Andreevich | 3,100 | 0.54% | 133 | 3,290 |
| 16 | Dobrynin, Anatoly F. | 2,871 | 0.50% | 99 | 3,128 |
| 17 | Harriman, William Averell | 2,817 | 0.49% | 104 | 2,963 |
| 18 | Khrushchev, Nikita Sergeyevich | 2,792 | 0.49% | 82 | 3,047 |
| 19 | Herter, Christian Archibald, Sr. | 2,745 | 0.48% | 64 | 3,017 |
| 20 | Haig, Alexander Meigs, Jr. | 2,642 | 0.46% | 71 | 2,825 |

**The cleaning changes the order.** On the stored counts Vance (4,203) sits below Johnson (4,381)
and Kennedy (4,144); on the cleaned counts Vance rises above both. Anyone quoting
`person_rollup.mention_count` directly gets a different table from this one.

## 5. Depth is not breadth — a second, different ranking

```sql
SELECT canonical_name, volume_count, mention_count FROM person_rollup
ORDER BY volume_count DESC, mention_count DESC LIMIT 12;
```
| person | volumes listed in | tagged documents (stored) |
|---|---|---|
| Nixon, Richard M. | 148 | 10,268 |
| Gromyko, Andreĭ Andreevich | 143 | 3,290 |
| Eisenhower, Dwight D. | 137 | 6,127 |
| Johnson, Ural Alexis | 126 | 3,514 |
| Bohlen, Charles Eustis ("Chip") | 113 | 1,275 |
| Harriman, William Averell | 111 | 2,963 |
| Johnson, Lyndon Baines | 110 | 4,381 |
| Dulles, John Foster | 102 | 7,400 |
| Dobrynin, Anatoly F. | 102 | 3,128 |
| Kissinger, Henry A. | 100 | 13,174 |
| Murphy, Robert Daniel | 100 | 2,536 |
| McNamara, Robert S. | 98 | 3,388 |

Kissinger is first by depth and tenth by breadth; Gromyko is second by breadth and fifteenth by
depth; Bohlen and Murphy enter on breadth and are nowhere near the depth top twenty. Note
`volume_count` counts volumes whose *person list* names the individual, which is systematically
larger than the number of volumes where they are actually tagged in a document (Kissinger: 100 vs
98; Nixon: 148 vs 136).

## 6. Cluster quality: under-merge, demonstrated

`person_rollup` is name-based. Grouping rollups by surname plus first given name finds pairs that
should be one person:

```sql
-- rollups sharing surname + first given-name token, total mentions > 700
```
| key | clusters | rollups |
|---|---|---|
| truman, harry | 2 | **Truman, Harry [120] · Truman, Harry S. [1042]** |
| carter, james | 3 | Carter, James Earl ("Jimmy"), Jr. [4518] · James Earl (Chip), III [32] · James "Chip," [0] |
| stimson, henry | 2 | Stimson, Henry Louis [721] · Stimson, Henry L., Secretary of War [0] |
| smith, walter | 2 | Smith, Walter Bedell [1726] · Smith, Walter B., II [3] |
| allen, george | 2 | Allen, George Venable [713] · Allen, George E. [3] |
| hoover, herbert | 2 | Hoover, Herbert Charles, Jr. [1793] · Hoover, Herbert Clark [192] |

**Truman is the clean case.** Both rollups are described "President of the United States":

```sql
SELECT rollup_id, canonical_name, description, mention_count, volume_count
FROM person_rollup WHERE canonical_name LIKE 'Truman, Harry%';
-- 333 | Truman, Harry    | President of the United States from 1945 to 1953 | 120  | 7
-- 3587 | Truman, Harry S.| President of the United States                   | 1042 | 41
```
One man, two clusters, 1,162 documents between them. (Not every split is an error: Hoover Jr. and
Hoover Clark are father and son, as are the two Herters.)

The database ships 164 proposed-but-unmerged pairs of its own:

```sql
SELECT a.canonical_name, a.mention_count, b.canonical_name, b.mention_count, c.reason
FROM person_cluster_candidate c
JOIN person_rollup a ON a.rollup_id=c.rollup_id_a JOIN person_rollup b ON b.rollup_id=c.rollup_id_b
ORDER BY a.mention_count+b.mention_count DESC LIMIT 15;
```
including `Matthews, H. Freeman, Jr. [7]` ↔ `Matthews, Harrison Freeman ("Doc") [913]` and
`Stettinius, Edward R. [7]` ↔ `Stettinius, Edward Reilly, Jr. [425]`. The same list also proposes
`Hassan bin al Talal [6]` ↔ `Hussein bin Talal [899]`, who are two different men (brothers) — so
the candidate list is a queue of hypotheses, not a queue of corrections.

**Direction of the error is one-way: every count above is a lower bound.** Under-merge splits a
person's documents across clusters and can only depress a figure.

## 7. The rollup's `description` is not a biography

The description is inherited from one volume's list entry, whichever the cluster happened to take.
Rusk is labelled "Assistant Secretary of State for Far Eastern Affairs", McNamara "Director of the
World Bank from 1968", Kennedy "Democratic Senator from Massachusetts", John Foster Dulles
"Adviser, United States Delegation". These are true of a moment, not of the person, and they must
not be used as role attributions.

## 8. What this ranking can support

- **It ranks who the FRUS editors tagged, in the volumes where they tagged anyone.** As a profile of
  the tagged stratum it is solid: the counts reconcile against the underlying rows, and the top of
  the list is stable under the cleaning in §3 (the top five do not move).
- **Relative comparisons inside one era and one tagging regime.** Kissinger against Rogers, or Rusk
  against Bundy, are comparisons between people documented under the same conventions.
- **A breadth-versus-depth contrast** (§5): who is everywhere in small amounts (Gromyko, Bohlen,
  U. Alexis Johnson) versus who dominates a few volumes (Brzezinski: 3,367 documents in 32 volumes;
  Carter: 4,251 in 48).
- **A floor.** Because the errors run one way, "Kissinger is tagged in at least 12,044 documents" is
  safe.

## 9. What it cannot support

- **It is not a ranking of importance in the FRUS corpus, and still less in US foreign relations.**
  It is a ranking of importance *within 287 of 552 volumes*, 88% of whose tags sit in 1950-and-later
  books.
- **No pre-1950 comparison is possible.** The leaders among volumes with a pre-1950 modal decade
  are Lansing 2,316 (13 volumes), Page 1,417, Stalin 816, Francis 814, Polk 753, Molotov 742,
  Stimson 710, **Franklin D. Roosevelt 631 (10 volumes)**, Woodrow Wilson 563. FDR's 631 would rank
  him around 80th corpus-wide. That is a fact about tagging coverage — 10 of 91 volumes with a 1940s
  modal decade are tagged — and nothing at all about Roosevelt.
- **No claim about *how much* a person is discussed.** §1 shows the table stores presence, not
  occurrences; the compression is roughly 5:1 and is not uniform across documents.
- **No absence claim.** A person with no rows may simply appear only in the 265 untagged volumes.
  "X does not appear in FRUS" cannot be said from this table under any circumstances.
- **No exact totals.** Under-merge (§6) means each figure is a lower bound of unknown size, and
  6,288 mention rows join to nothing at all.
- **No roles, titles or tenures** (§7).
- **No nationality balance claim.** Three of the twenty (Gromyko, Dobrynin, Khrushchev) are not
  American, but the person list is compiled by American editors for American readers, so the
  composition measures the editorial apparatus, not the diplomacy.

## 10. If the question really is "who matters in this corpus"

The honest route is not this table. It is a full-name scan of the **TEI** — the counting surface
this index cannot provide, because `body_text` is porter-stemmed in the FTS index, blends document
prose with editorial footnotes, and cannot separate a name in a document from a name in a footnote.
Such a scan would need every spelling variant of each name, positive and negative controls, and a
statement of whether it counted raw, tag-stripped or word-bounded text. **I have not run it, and no
number in this file should be read as if I had.**

## Caveats carried forward

- 552 volumes present; person data exists in 287 of them, person lists in 285.
- 572,593 cleaned mention rows (apparatus and the two duplicate second editions removed); the raw
  table holds 611,307.
- 108,581 of 306,619 in-scope documents carry any person tag.
- All person counts are lower bounds. `person_rollup.mention_count` is additionally uncleaned and
  704 rows stale.
- The pre-1950 figures in §9 are thin enough that they describe the tagging regime, not the corpus.
