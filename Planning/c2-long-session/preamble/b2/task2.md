# Task 2 — Person coverage of the corpus

## 0. Coverage statement

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note)
FROM document_cache;
```
**552 volumes, 316,839 documents, 1,012 front matter, 8,468 editorial notes.** The local
library holds the complete 552-volume series.

Analysis scope as in Task 1 — apparatus excluded, `frus1951-54IranEd2` and
`frus1969-76ve15p2Ed2` suppressed → **550 volumes, 306,619 documents.**

---

## 1. What the four person tables actually are

| table | rows | grain |
|---|---:|---|
| `persons` | 62,931 | one row per (volume, ref): an entry in a **volume's own printed person-list**, with that volume's role gloss |
| `person_mentions` | 611,307 | one row per (volume, document, person_ref): a TEI `<persName>` link |
| `person_rollup` | 17,961 | one clustered identity, with precomputed `mention_count` / `volume_count` |
| `person_rollup_member` | 62,931 | maps every `persons` row into exactly one rollup |
| `person_cluster_candidate` | 164 | pairs the clusterer **suspected but refused to merge** |

**Two structural facts had to be measured before any ranking could be read.**

**(a) `person_mentions` is document-level, not token-level.**
```sql
SELECT COUNT(*) AS rows_total,
       COUNT(DISTINCT volume_id||'|'||document_id||'|'||person_ref) AS distinct_triples
FROM person_mentions;                                    -- 611,307 / 611,307
SELECT MAX(c) FROM (SELECT COUNT(*) c FROM person_mentions
                    GROUP BY volume_id,document_id,person_ref);   -- 1
```
Every triple is unique and no triple repeats. So the column named `mention_count` is a
**document count**: a person named forty times in one memorandum of conversation
contributes 1, exactly as a person named once does. The ranking below is therefore a
ranking by *document presence*, and I have relabelled the column `docs` throughout to stop
it being read as a frequency.

**(b) The tagging covers 287 of 552 volumes.**
```sql
SELECT (SELECT COUNT(DISTINCT volume_id) FROM person_mentions) AS vols_with_mentions,
       (SELECT COUNT(DISTINCT volume_id) FROM persons)         AS vols_with_person_list,
       (SELECT COUNT(DISTINCT volume_id) FROM document_cache)  AS vols_total;
```
→ **287 / 285 / 552.** And at document grain:
```sql
SELECT COUNT(*) AS in_scope_docs,
  SUM(CASE WHEN EXISTS(SELECT 1 FROM person_mentions pm
       WHERE pm.volume_id=dc.volume_id AND pm.document_id=dc.document_id) THEN 1 ELSE 0 END) AS docs_with_a_tag
FROM document_cache dc WHERE dc.is_front_matter=0 AND dc.is_editorial_note=0
  AND dc.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2');
```
→ **108,581 of 306,619 documents carry any person tag (35.4%).**

---

## 2. The twenty people who appear most often

Recomputed from `person_mentions` with the house-rule exclusions applied — *not* read off
the stored `mention_count`, which includes apparatus and the suppressed second editions.

```sql
SELECT pr.rollup_id, pr.canonical_name,
       COUNT(DISTINCT pm.volume_id||'/'||pm.document_id) AS docs,
       COUNT(DISTINCT pm.volume_id) AS vols
FROM person_mentions pm
JOIN document_cache dc ON dc.volume_id=pm.volume_id AND dc.document_id=pm.document_id
JOIN person_rollup_member prm ON prm.volume_id=pm.volume_id AND prm.ref=pm.person_ref
JOIN person_rollup pr ON pr.rollup_id=prm.rollup_id
WHERE dc.is_front_matter=0 AND dc.is_editorial_note=0
  AND dc.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
GROUP BY 1,2 ORDER BY docs DESC LIMIT 20;
```

| # | canonical name (rollup_id) | documents | share of the 108,581 tagged docs | volumes |
|---:|---|---:|---:|---:|
| 1 | Kissinger, Henry A. (557) | 12,044 | 12,044 of 108,581 | 98 |
| 2 | Nixon, Richard M. (253) | 9,264 | 9,264 of 108,581 | 136 |
| 3 | Rusk, David Dean (282) | 8,357 | 8,357 of 108,581 | 92 |
| 4 | Dulles, John Foster (1011) | 6,735 | 6,735 of 108,581 | 98 |
| 5 | Eisenhower, Dwight D. (103) | 5,219 | 5,219 of 108,581 | 133 |
| 6 | Carter, James Earl ("Jimmy"), Jr. (1540) | 4,251 | 4,251 of 108,581 | 48 |
| 7 | Vance, Cyrus Roberts (955) | 4,059 | 4,059 of 108,581 | 71 |
| 8 | Johnson, Lyndon Baines (165) | 3,920 | 3,920 of 108,581 | 99 |
| 9 | Kennedy, John F. (177) | 3,720 | 3,720 of 108,581 | 52 |
| 10 | Bundy, McGeorge (52) | 3,706 | 3,706 of 108,581 | 72 |
| 11 | Johnson, Ural Alexis (166) | 3,389 | 3,389 of 108,581 | 118 |
| 12 | Brzezinski, Zbigniew K. (412) | 3,367 | 3,367 of 108,581 | 32 |
| 13 | Rogers, William Pierce (662) | 3,200 | 3,200 of 108,581 | 66 |
| 14 | McNamara, Robert S. (227) | 3,151 | 3,151 of 108,581 | 94 |
| 15 | Gromyko, Andreĭ Andreevich (830) | 3,100 | 3,100 of 108,581 | 133 |
| 16 | Dobrynin, Anatoly F. (89) | 2,871 | 2,871 of 108,581 | 99 |
| 17 | Harriman, William Averell (149) | 2,817 | 2,817 of 108,581 | 104 |
| 18 | Khrushchev, Nikita Sergeyevich (179) | 2,792 | 2,792 of 108,581 | 82 |
| 19 | Herter, Christian Archibald, Sr. (1072) | 2,745 | 2,745 of 108,581 | 64 |
| 20 | Haig, Alexander Meigs, Jr. (507) | 2,642 | 2,642 of 108,581 | 71 |

Every one of the twenty is a **United States official of 1953–1980**, plus three Soviet
counterparts (Gromyko, Dobrynin, Khrushchev). No nineteenth-century figure, no Second
World War figure, no non-Soviet foreign statesman appears.

### A second ranking, by breadth rather than depth

Ordering the same join by *volumes appeared in* rather than documents reorders the list —
and it is arguably the more informative axis, since it measures a person's reach across
the series rather than their density inside one subseries:

| # | name | volumes | documents |
|---:|---|---:|---:|
| 1 | Nixon, Richard M. | 136 | 9,264 |
| 2 | Eisenhower, Dwight D. | 133 | 5,219 |
| 3 | Gromyko, Andreĭ Andreevich | 133 | 3,100 |
| 4 | Johnson, Ural Alexis | 118 | 3,389 |
| 5 | Bohlen, Charles Eustis ("Chip") | 106 | 1,193 |
| 6 | Harriman, William Averell | 104 | 2,817 |
| 7 | Johnson, Lyndon Baines | 99 | 3,920 |
| 8 | Dobrynin, Anatoly F. | 99 | 2,871 |
| 9 | Kissinger, Henry A. | 98 | 12,044 |
| 10 | Dulles, John Foster | 98 | 6,735 |

Kissinger falls from 1st to 9th. Bohlen, Nitze, Helms, Mansfield and de Gaulle enter the
top twenty on breadth and are absent from the depth list — career diplomats and
long-serving figures whose names recur across many volumes without dominating any.

---

## 3. What this ranking CAN support

1. **A statement about the tagged third of the corpus.** Within the 108,581 documents that
   carry any `<persName>` markup, these twenty are the most frequently present, and the
   margins at the top are large enough to be robust: Kissinger's 12,044 is 30% clear of
   Nixon's 9,264, and the top five are separated by thousands of documents.
2. **Navigational value.** These counts are exactly right for the question *"which people
   will I keep running into if I read the post-war volumes?"* — which is what a reader
   opening the corpus wants to know.
3. **A breadth/depth contrast that is genuinely informative.** The two orderings above
   diverge sharply, and the divergence is a real property of the record: Kissinger is
   concentrated (98 volumes, 12,044 docs), Bohlen is diffuse (106 volumes, 1,193 docs).
4. **Comparison *within* a fixed era.** Restricted to one date band the ranking is
   internally consistent, because tagging density is roughly uniform inside a subseries.
   The 1940–1959 top five, for instance:
   ```sql
   ... WHERE dd.date_iso<>'' AND CAST(substr(dd.date_iso,1,4) AS INTEGER) BETWEEN 1940 AND 1959
   ```
   John Foster Dulles 6,641 · Eisenhower 4,299 · Anthony Eden 2,534 · Robert Murphy 2,363 ·
   Dean Acheson 2,025.

## 4. What this ranking CANNOT support — five hard limits

### (a) It is not a ranking over the corpus. It is a ranking over post-1950 volumes.

Person tagging is not merely "uneven"; for most of the series it is **absent**.

```sql
SELECT (CAST(substr(dd.date_iso,1,4) AS INTEGER)/10)*10 AS decade,
  COUNT(DISTINCT dc.volume_id||'/'||dc.document_id) AS docs,
  COUNT(DISTINCT CASE WHEN pm.volume_id IS NOT NULL
        THEN dc.volume_id||'/'||dc.document_id END) AS docs_with_a_mention
FROM document_cache dc JOIN document_dates dd USING(volume_id,document_id)
LEFT JOIN person_mentions pm ON pm.volume_id=dc.volume_id AND pm.document_id=dc.document_id
WHERE dc.is_front_matter=0 AND dc.is_editorial_note=0
  AND dc.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
  AND dd.date_iso<>'' AND CAST(substr(dd.date_iso,1,4) AS INTEGER)>=1860
GROUP BY 1 ORDER BY 1;
```

| decade | documents | tagged | tagged share |
|---|---:|---:|---|
| 1860s | 11,250 | 14 | 14 of 11,250 |
| 1870s | 5,798 | 524 | 524 of 5,798 |
| **1880s** | 6,472 | **0** | 0 of 6,472 |
| **1890s** | 9,712 | **0** | 0 of 9,712 |
| **1900s** | 9,924 | **0** | 0 of 9,924 |
| 1910s | 30,359 | 12,217 | 12,217 of 30,359 |
| 1920s | 19,733 | 12 | 12 of 19,733 |
| 1930s | 39,196 | 4,441 | 4,441 of 39,196 |
| 1940s | 74,043 | 5,370 | 5,370 of 74,043 |
| 1950s | 42,296 | 31,188 | 31,188 of 42,296 |
| 1960s | 27,650 | 27,063 | 27,063 of 27,650 |
| 1970s | 22,259 | 21,785 | 21,785 of 22,259 |
| 1980s | 5,949 | 5,780 | 5,780 of 5,949 |

Three consecutive decades have **exactly zero** tagged documents. The 1940s — the largest
decade in the corpus at 74,043 documents — is tagged at 7.3%. The 1960s–1980s are tagged
at 97–98%.

The consequence is blunt: **William Seward cannot appear in this ranking**, and his absence
is not evidence about Seward. Restricting to documents dated before 1940 produces a top ten
made entirely of Great War figures — Robert Lansing 2,316, Walter Hines Page 1,417, David
Rowland Francis 814, Frank Lyon Polk 753, Henry Stimson 626 — because the 1910s volumes are
the *only* substantially tagged pre-1940 group. Woodrow Wilson manages 560 documents. That
is not a finding about Wilson's importance; it is a finding about which volumes the Office
of the Historian retro-tagged.

### (b) The #1 result is a compound of centrality and subseries size.

```sql
SELECT CASE WHEN pm.volume_id LIKE 'frus1969-76%' THEN '1969-76' ... END AS block, COUNT(*)
FROM person_mentions pm ... WHERE prm.rollup_id=557 ... GROUP BY 1;
```
**11,613 of Kissinger's 12,044 documents (96%) sit in the `1969-76` subseries** — the
largest block in the series at 66 volumes, and one where 17,741 of 18,114 documents (98%)
are tagged. Kissinger is genuinely central to that record; but his margin over Nixon is
produced as much by the editorial decision to devote 66 heavily-tagged volumes to
1969–1976 as by anything about him.

### (c) The clustering under-merges, and the database says so in two places.

`person_cluster_candidate` holds **164** pairs the clusterer suspected and declined to
merge. Reading them is the cheapest possible audit:

| reason | count |
|---|---:|
| name variant; era unknown | 64 |
| generational suffix differs; possibly the same person | 58 |
| name variant; era overlaps; role differs | 34 |
| possible match; would bridge two reconciled identities | 6 |
| generational suffix differs; era unknown | 2 |

Concrete unmerged pairs include `Stimson, Henry Louis` (721) vs
`Stimson, Henry L., Secretary of War` (0); `Hull, Cordell` (361) vs
`Hull, Cordell, Secretary of State` (0); `Stettinius, Edward R.` (7) vs
`Stettinius, Edward Reilly, Jr.` (425); `Matthews, H. Freeman, Jr.` (7) vs
`Matthews, Harrison Freeman ("Doc")` (913).

And the table misses some. A direct surname scan turns up
**`Dulles, Alan W.` (rollup 97, 4 documents, 1 volume)** sitting beside
**`Dulles, Allen W.` (rollup 812, 2,513 documents, 96 volumes)** — a one-letter misspelling
that produced two identities and is *not* in the candidate list. **Every count in §2 is a
lower bound**, and the deficit is unknown rather than bounded.

### (d) The metadata attached to a rollup is one arbitrary volume's, not a career.

The stored `role` for Dean Rusk (rollup 282) reads *"Assistant Secretary of State for Far
Eastern Affairs"* — his 1950–51 post, not the office he held for eight years. Across his 92
member rows there are **23 distinct role strings**, and the rollup keeps one:

```sql
SELECT COUNT(*) AS member_rows, COUNT(DISTINCT role) AS distinct_roles FROM persons
WHERE volume_id||'|'||ref IN (SELECT volume_id||'|'||ref FROM person_rollup_member WHERE rollup_id=282);
```
→ 92 / 23. Several of those strings are also mechanically damaged — *"Secretary of State
from January 21"* and *"from January 21, , until January 20, 1969"* have lost their years
in parsing.

`start_year`/`end_year` are worse: they are **not consistently life dates**. Nixon reads
1913–1994 (birth–death) but McGeorge Bundy reads 1952–1982 and Robert McNamara 1960–1999,
which are service spans. The two meanings are not distinguished by any column, so the
field cannot be filtered on.

### (e) External authority linkage is partial.

```sql
SELECT COUNT(*) AS rollups,
 SUM(CASE WHEN authority_id IS NOT NULL THEN 1 ELSE 0 END) AS with_authority_id,
 SUM(CASE WHEN viaf_id IS NOT NULL AND viaf_id<>'' THEN 1 ELSE 0 END) AS with_viaf
FROM person_rollup;
```
→ 17,961 rollups; **12,834 with an authority id**; only **3,198 with a VIAF**. Four of the
top twenty (Rusk, Kennedy, Bundy, Rogers) carry no VIAF, so even at the very top the
identities cannot all be resolved against an external register.

Shape of the rollup table generally: **9,964 of 17,961 rollups appear in a single volume**,
and **1,682 have zero documents** — person-list entries the editors indexed but never
tagged in a document.

---

## 5. The one-sentence version

Ranked over the 108,581 of 306,619 in-scope documents that carry any TEI person markup,
the corpus's twenty most-present people are Kissinger, Nixon, Rusk, John Foster Dulles and
Eisenhower at the head of a list that is entirely American Cold War officialdom plus
Gromyko, Dobrynin and Khrushchev — and that list is a **description of which volumes were
tagged**, not of who mattered in American diplomacy, because the 1880s, 1890s and 1900s
contain zero tagged documents while the 1960s and 1970s are tagged at 98%.

## 6. What would answer the question properly

The index cannot fix this; a different surface can.

- **The TEI XML** (`/Users/jbotts/Development/frus/volumes/*.xml`) holds the untagged
  nineteenth-century prose. A full-name scan there — never a bare surname, and counting
  every spelling and inverted-index form, with the counting surface stated — would give a
  measure that is not conditioned on markup. It would be a different and harder
  measurement, not this one at greater length.
- **The archival channel is untouched by any of the above.** Which record groups and lot
  files these people's papers were drawn out of, and which collections the footnotes point
  at, are questions for the bundled indexes (`collection-usage-index.json`,
  `external-citation-index.json`, `series-facts-index.json`), and must be reported as two
  separate channels — came-from and pointed-at — never summed.
