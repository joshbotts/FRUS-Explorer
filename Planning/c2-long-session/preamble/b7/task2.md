# Task 2 — Person coverage

## Coverage statement

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note)
FROM document_cache;
```
→ **552 volumes**, 316,839 rows, 1,012 front matter, 8,468 editorial notes. The full series is
present; the caveats below are about the person tagging, not about a partial library.

## The four person tables and what each holds

```sql
SELECT 'persons' t, COUNT(*) n, COUNT(DISTINCT volume_id) vols FROM persons
UNION ALL SELECT 'person_mentions', COUNT(*), COUNT(DISTINCT volume_id) FROM person_mentions
UNION ALL SELECT 'person_rollup', COUNT(*), NULL FROM person_rollup
UNION ALL SELECT 'person_rollup_member', COUNT(*), COUNT(DISTINCT volume_id) FROM person_rollup_member
UNION ALL SELECT 'person_cluster_candidate', COUNT(*), NULL FROM person_cluster_candidate;
```

| table | rows | volumes |
|---|---|---|
| `persons` — the editors' per-volume name lists | 62,931 | **285 of 552** |
| `person_mentions` — one row per (volume, document, person) | 611,307 | **287 of 552** |
| `person_rollup` — name-clustered identities | 17,961 | — |
| `person_rollup_member` — volume-ref → rollup | 62,931 | 285 |
| `person_cluster_candidate` — flagged possible merges | 164 | — |

Two structural facts worth stating before any ranking:

**`mention_count` is a document count, not an occurrence count.** `person_mentions` holds 611,307
rows and 611,307 distinct `(volume_id, document_id, person_ref)` triples — the table is deduplicated
at document grain. A person named forty times in one memorandum contributes 1.

```sql
SELECT COUNT(*) AS rows_total,
       COUNT(DISTINCT volume_id||'|'||document_id||'|'||person_ref) AS distinct_triples
FROM person_mentions;  -- 611307 | 611307
```

**`person_rollup.mention_count` is derived and reconciles exactly** with the mentions table joined
through `person_rollup_member` on `(volume_id, ref)` — verified for the top 8 rollups, stored equals
recomputed in every case. It is not an independent number.

## The twenty who appear most often

```sql
SELECT ROW_NUMBER() OVER (ORDER BY mention_count DESC) rk, rollup_id, canonical_name,
       mention_count, volume_count
FROM person_rollup ORDER BY mention_count DESC LIMIT 20;
```

Date spans added from the mentions joined to `document_dates`, apparatus and duplicate second
editions excluded:

```sql
WITH top AS (SELECT rollup_id, canonical_name, mention_count FROM person_rollup
             ORDER BY mention_count DESC LIMIT 20)
SELECT t.canonical_name, t.mention_count AS all_mentions, COUNT(*) AS doc_mentions,
       MIN(CAST(substr(dd.date_iso,1,4) AS INT)) first_yr,
       MAX(CAST(substr(dd.date_iso,1,4) AS INT)) last_yr
FROM top t
JOIN person_rollup_member m ON m.rollup_id=t.rollup_id
JOIN person_mentions pm ON pm.volume_id=m.volume_id AND pm.person_ref=m.ref
JOIN document_cache dc ON dc.volume_id=pm.volume_id AND dc.document_id=pm.document_id
JOIN document_dates dd ON dd.volume_id=pm.volume_id AND dd.document_id=pm.document_id
WHERE dd.date_iso IS NOT NULL AND dc.is_front_matter=0 AND dc.is_editorial_note=0
  AND dc.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
GROUP BY t.rollup_id ORDER BY t.mention_count DESC;
```

| # | canonical name | mentions (all) | in documents only | volumes | first–last doc year |
|---|---|---|---|---|---|
| 1 | Kissinger, Henry A. | 13,174 | 12,044 | 100 | 1961–1988 |
| 2 | Nixon, Richard M. | 10,268 | 9,264 | 148 | 1953–1988 |
| 3 | Rusk, David Dean | 8,855 | 8,357 | 92 | 1948–1980 |
| 4 | Dulles, John Foster | 7,400 | 6,731 | 102 | 1918–1979 |
| 5 | Eisenhower, Dwight D. | 6,127 | 5,218 | 137 | 1943–1988 |
| 6 | Carter, James Earl (“Jimmy”), Jr. | 4,518 | 4,251 | 50 | 1971–1988 |
| 7 | Johnson, Lyndon Baines | 4,381 | 3,920 | 110 | 1954–1988 |
| 8 | Vance, Cyrus Roberts | 4,203 | 4,059 | 72 | 1962–1987 |
| 9 | Kennedy, John F. | 4,144 | 3,720 | 58 | 1960–1988 |
| 10 | Bundy, McGeorge | 3,978 | 3,706 | 73 | 1952–1982 |
| 11 | Johnson, Ural Alexis | 3,514 | 3,387 | 126 | 1951–1980 |
| 12 | Rogers, William Pierce | 3,504 | 3,200 | 71 | 1958–1984 |
| 13 | Brzezinski, Zbigniew K. | 3,486 | 3,367 | 34 | 1964–1987 |
| 14 | McNamara, Robert S. | 3,388 | 3,151 | 98 | 1961–1982 |
| 15 | Gromyko, Andreĭ Andreevich | 3,290 | 3,097 | 143 | 1939–1988 |
| 16 | Dobrynin, Anatoly F. | 3,128 | 2,871 | 102 | 1961–1988 |
| 17 | Khrushchev, Nikita Sergeyevich | 3,047 | 2,792 | 87 | 1938–1988 |
| 18 | Herter, Christian Archibald, Sr. | 3,017 | 2,745 | 66 | 1954–1967 |
| 19 | Harriman, William Averell | 2,963 | 2,817 | 111 | 1943–1980 |
| 20 | Haig, Alexander Meigs, Jr. | 2,825 | 2,642 | 74 | 1969–1983 |

Seventeen of the twenty are American officials. The three exceptions are Soviet: Gromyko, Dobrynin,
Khrushchev. Nobody in the top twenty is a nineteenth-century figure, and only John Foster Dulles
reaches back before 1938.

## What this ranking CAN support

**1. It is robust to the identity-clustering caveat at the top.** The house warning that
`person_rollup` under-merges is correct, and I found unflagged splits — but re-ranking under an
aggressive over-merge (same surname, same first four letters of forename, which wrongly fuses
J.F. Kennedy with John Noble Kennedy and Herter Sr. with Jr.) returns **the same twenty people**:

```sql
WITH x AS (SELECT rollup_id, canonical_name, mention_count,
  substr(namekey,1,instr(namekey,',')-1) AS surname,
  substr(trim(substr(namekey,instr(namekey,',')+1)),1,4) AS fp
 FROM person_rollup WHERE instr(namekey,',')>1)
SELECT surname||', '||fp AS grp, SUM(mention_count) merged, COUNT(*) parts FROM x
GROUP BY surname, fp ORDER BY merged DESC LIMIT 25;
```
Only two positions move: Brzezinski 13 → 11 (3,486 + 141), Johnson U. Alexis 11 → 13. The
membership is identical. Since that merge is a deliberate upper bound on the correction, the top-20
*set* is safe even though individual counts are lower bounds.

**2. It supports a breadth ranking that is genuinely different.** `volume_count` reorders the list
and brings in people the mention count buries:

```sql
SELECT canonical_name, volume_count, mention_count,
       ROUND(mention_count*1.0/volume_count,1) AS per_vol
FROM person_rollup ORDER BY volume_count DESC LIMIT 20;
```
Nixon 148 volumes · Gromyko 143 · Eisenhower 137 · Johnson U. Alexis 126 · **Bohlen, Charles Eustis
113** · Harriman 111 · Johnson L.B. 110 · Dobrynin 102 · Dulles J.F. 102 · Kissinger 100 · **Murphy,
Robert Daniel 100** · McNamara 98 · Dillon 97 · **Nitze, Paul Henry 97** · **Helms, Richard McGarrah
97** · **De Gaulle, Charles 96** · **Dulles, Allen W. 96** · **Lodge, Henry Cabot, II 94** ·
**Mansfield, Michael Joseph 93** · Rusk 92.

Kissinger falls to tenth. His 131.7 mentions per volume against Mansfield's 6.7 is the difference
between a man who runs the policy and a man who recurs across it. Bohlen, Murphy, Nitze, Helms,
Lodge, Allen Dulles and De Gaulle are in the top twenty of the corpus by reach and nowhere near it
by volume — a career-diplomat signature that the depth ranking cannot see.

**3. It supports the observation that the rollup is doing real work.** Behind rollup 557
(Kissinger) sit 100 member rows carrying 2 name spellings and **64 distinct role strings** — the
role text is a per-volume editorial description, not a person attribute:

```sql
SELECT COUNT(DISTINCT p.name), COUNT(DISTINCT p.role), COUNT(*)
FROM person_rollup r JOIN person_rollup_member m USING(rollup_id)
JOIN persons p ON p.volume_id=m.volume_id AND p.ref=m.ref
WHERE r.canonical_name='Kissinger, Henry A.';   -- 2 | 64 | 100
```

## What this ranking CANNOT support

**1. It is not a ranking of the corpus. It is a ranking of the 35% of it that is tagged.**

```sql
SELECT COUNT(*) AS docs_in_scope,
 SUM(CASE WHEN EXISTS(SELECT 1 FROM person_mentions pm
     WHERE pm.volume_id=dc.volume_id AND pm.document_id=dc.document_id) THEN 1 ELSE 0 END)
FROM document_cache dc WHERE dc.is_front_matter=0 AND dc.is_editorial_note=0
  AND dc.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2');
```
→ **108,581 of 306,619 documents** carry at least one person mention. **265 of 552 volumes are
entirely untagged**, and they hold 195,013 documents:

```sql
WITH v AS (SELECT dc.volume_id vid, COUNT(*) docs,
  (SELECT COUNT(*) FROM person_mentions pm WHERE pm.volume_id=dc.volume_id) AS mentions
 FROM document_cache dc WHERE dc.is_front_matter=0 AND dc.is_editorial_note=0 GROUP BY 1)
SELECT CASE WHEN mentions=0 THEN 'untagged (0)'
   WHEN mentions*1.0/docs<0.5 THEN 'thin (<0.5/doc)' WHEN mentions*1.0/docs<2 THEN '0.5-2 per doc'
   WHEN mentions*1.0/docs<5 THEN '2-5 per doc' ELSE '5+ per doc' END AS band,
 COUNT(*) volumes, SUM(docs) docs, SUM(mentions) mentions FROM v GROUP BY 1;
```

| band | volumes | documents | mentions |
|---|---|---|---|
| untagged (0) | 265 | 195,013 | 0 |
| 0.5–2 per doc | 8 | 7,188 | 12,092 |
| 2–5 per doc | 86 | 39,018 | 147,972 |
| 5+ per doc | 193 | 66,140 | 451,243 |

**2. And the untagged 265 are not a random 265 — they are the pre-1930 corpus.** This is the finding
that disqualifies the ranking as a statement about FRUS as a whole:

```sql
WITH d AS (SELECT dc.volume_id v, dc.document_id doc,
  (CAST(substr(t.date_iso,1,4) AS INTEGER)/10)*10 dec
 FROM document_cache dc JOIN document_dates t USING(volume_id,document_id)
 WHERE dc.is_front_matter=0 AND dc.is_editorial_note=0
   AND dc.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') AND t.date_iso IS NOT NULL)
SELECT dec, COUNT(*) docs,
 SUM(CASE WHEN EXISTS(SELECT 1 FROM person_mentions pm
     WHERE pm.volume_id=d.v AND pm.document_id=d.doc) THEN 1 ELSE 0 END) AS docs_with_mentions
FROM d WHERE dec>=1860 GROUP BY dec ORDER BY dec;
```

| decade | documents | with a person mention | share |
|---|---|---|---|
| 1860 | 11,250 | 14 | 14 of 11,250 |
| 1870 | 5,798 | 524 | 524 of 5,798 |
| 1880 | 6,472 | **0** | 0 of 6,472 |
| 1890 | 9,712 | **0** | 0 of 9,712 |
| 1900 | 9,924 | **0** | 0 of 9,924 |
| 1910 | 30,359 | 12,217 | 12,217 of 30,359 |
| 1920 | 19,733 | 12 | 12 of 19,733 |
| 1930 | 39,196 | 4,441 | 4,441 of 39,196 |
| 1940 | 74,043 | 5,370 | 5,370 of 74,043 |
| 1950 | 42,296 | 31,188 | 31,188 of 42,296 |
| 1960 | 27,650 | 27,063 | 27,063 of 27,650 |
| 1970 | 22,259 | 21,785 | 21,785 of 22,259 |
| 1980 | 5,949 | 5,780 | 5,780 of 5,949 |

Three whole decades — the 1880s, 1890s and 1900s, 26,108 documents — have **zero** tagged mentions.
The 1940s, the largest decade in the corpus, is tagged at 5,370 of 74,043. From 1950 the tagging is
near-total (74%, 98%, 98%, 97%). So the top-20 list is, mechanically, a list of people who were
active after 1950. **Seward, Fish, Blaine, Hay, Root, Knox and Bryan cannot appear in this ranking
no matter how often FRUS prints them**, because the volumes they inhabit contain no `<persName>`
markup at all. Anyone reading this table as "the most important people in FRUS" is reading an
artefact of TEI encoding practice.

**3. The counts include apparatus unless you exclude it yourself.** The stored `mention_count`
counts mentions in front matter and editorial notes:

```sql
SELECT COUNT(*) AS all_mentions,
 SUM(CASE WHEN dc.is_front_matter=0 AND dc.is_editorial_note=0 THEN 1 ELSE 0 END) AS in_documents,
 SUM(dc.is_front_matter) AS in_front_matter, SUM(dc.is_editorial_note) AS in_editorial_notes
FROM person_mentions pm JOIN document_cache dc
 ON dc.volume_id=pm.volume_id AND dc.document_id=pm.document_id;
```
→ 611,307 total = 583,150 in documents + 2,228 in front matter + 25,929 in editorial notes. That is
28,157 mentions (4.6%) in editorial apparatus, and it is not evenly spread: Kissinger loses 1,130 of
13,174 (8.6%), Vance only 144 of 4,203 (3.4%). A ranking built on the stored column is a ranking
that partly counts how much the editors wrote *about* someone.

**4. Every count is a lower bound, and the clustering fails in both directions.** 164 pairs are
flagged in `person_cluster_candidate`, but the flagging is incomplete *and* it is not a merge
instruction. Unflagged real splits found by a same-surname/same-forename-prefix scan:

| A | mentions | B | mentions | verdict |
|---|---|---|---|---|
| Brzezinski, Zbigniew K. | 3,486 | Brzezinski, Zbignew K. | 141 | same person, a typo in `frus1977-80v16`; **not flagged** |
| Truman, Harry S. | 1,042 | Truman, Harry | 120 | same person; not flagged |
| Rogers, William Pierce | 3,504 | Rogers, William Dill | 120 | different people |
| Hoover, Herbert Charles, Jr. | 1,793 | Hoover, Herbert Clark | 192 | different people (father and son) |
| Wilson, Charles Erwin | 920 | Wilson, Charles McMoran | 5 | different people |

And the flagged list contains false positives of its own — `Hassan bin al Talal` (6) is paired with
`Hussein bin Talal` (899) as a "name variant", which would fuse two different members of the
Jordanian royal family. **The candidate table is a queue for a human, not a correction to apply.**

**5. 5,787 of 17,961 rollups are noise or near-noise.** 1,682 rollups have zero mentions (named in a
volume's list, never tagged in a document) and 4,105 have exactly one. The 76 rollups above 1,000
mentions carry 193,174 of 611,307 mentions. Any long-tail analysis of this table is analysing
one-off name-list entries.

**6. Do not use `person_rollup.start_year` / `end_year`.** They are inconsistent. Nixon 1913–1994 and
Carter 1924–2024 are birth and death; but Bundy is 1952–1982, Brzezinski 1964–2013, Gromyko
1939–2013, Dobrynin 1952–2015 — service spans or values scraped out of role prose. The `persons`
table shows the mechanism directly: Dean Acheson's row carries `start_year = 1949` beside a role
string reading "Secretary of State from January 21, 1949". The year was parsed out of the sentence.

**7. This is TEI markup, and it is neither exhaustive nor disambiguating within a tagged volume.**
It cannot tell you who *wrote* or *received* a document, only that a name was marked in it. The
`persons` table's own name lists show the raw variation the rollup is smoothing — `Rusk, Dean` /
`Rusk, David Dean`, `Johnson, U. Alexis` / `Johnson, Ural Alexis`, `Harriman, W. Averell` /
`Harriman, William Averell`, `Gromyko, Andrei A.` / `Gromyko, Andreĭ Andreevich`:

```sql
SELECT lower(trim(name)) AS namekey, COUNT(DISTINCT volume_id) AS vols_listing
FROM persons GROUP BY 1 ORDER BY vols_listing DESC LIMIT 20;
```
→ Nixon 141 · Johnson U. Alexis 124 · Eisenhower 109 · Harriman 104 · Dulles J.F. 102 · McNamara 93 ·
Bohlen 92 · Dillon 92 · Kissinger 92 · Murphy 90 · Rusk 90 · Gromyko 89 · Johnson L.B. 86 · Nitze 84 ·
Dulles A.W. 82 · Merchant 79 · De Gaulle 77 · Bundy 73 · Sisco 73 · Fulbright 70.

A third ranking, a third answer. The three tables agree on roughly who, and disagree on order.

## One-line summary

The twenty most-mentioned people in this corpus are seventeen American and three Soviet Cold War
officials, led by Kissinger (13,174 mentions across 100 volumes), and the list is stable under
identity-merging — but it is drawn from 108,581 of 306,619 documents, 265 of 552 volumes carry no
person markup at all, and three entire decades of the corpus (1880s, 1890s, 1900s) contribute zero.
The ranking is trustworthy as a description of post-1950 FRUS and worthless as a description of FRUS.
