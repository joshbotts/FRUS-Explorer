# Task 2 — Person coverage in the corpus

**Surface used:** the SQLite index only. No TEI, no bundled JSON.
**Scope:** the same 550-volume / 306,619-document working set as Task 1 (552 volumes, 316,839 rows
before dropping 1,012 front-matter, 8,468 editorial-note, and the two duplicate second-edition
volumes). Every claim below is conditional on that library, which for this corpus is the complete
published series.

---

## 0. The four person tables, sized

```sql
SELECT 'persons', COUNT(*), COUNT(DISTINCT volume_id) FROM persons
UNION ALL SELECT 'person_mentions', COUNT(*), COUNT(DISTINCT volume_id) FROM person_mentions
UNION ALL SELECT 'person_rollup', COUNT(*), NULL FROM person_rollup
UNION ALL SELECT 'person_rollup_member', COUNT(*), COUNT(DISTINCT volume_id) FROM person_rollup_member
UNION ALL SELECT 'person_cluster_candidate', COUNT(*), NULL FROM person_cluster_candidate;
```

| table | rows | volumes |
|---|---:|---:|
| `persons` (per-volume name entries) | 62,931 | **285** |
| `person_mentions` (document ↔ person) | 611,307 | **287** |
| `person_rollup` (cross-volume clusters) | 17,961 | — |
| `person_rollup_member` (entry → cluster) | 62,931 | 285 |
| `person_cluster_candidate` (flagged, unmerged) | 164 | — |

**The first number that matters is 287 of 552.** Person data exists for barely half the volumes.

---

## 1. What "mention" means here — check this before reading the ranking

```sql
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT volume_id||'|'||document_id||'|'||person_ref) AS distinct_triples
FROM person_mentions;                      -- 611307   611307
SELECT COUNT(*) FROM (SELECT volume_id,document_id,person_ref,COUNT(*) c
                      FROM person_mentions GROUP BY 1,2,3 HAVING c>1);   -- 0
```

`person_mentions` holds **exactly one row per (volume, document, person)** — 611,307 rows,
611,307 distinct triples, zero duplicates. So `person_rollup.mention_count` is a **document count,
not an occurrence count.** A person named forty times in one memorandum contributes 1. Confirmed
independently on the top 20, where a per-person document count and the stored `mention_count` agree
to the row (Kissinger 13,174 = 13,174).

This matters for how the ranking reads: it measures **how many documents a person turns up in**,
which is a measure of institutional ubiquity, not of prominence within any document.

I also verified the stored counts are not stale, by rebuilding them from the join:
```sql
SELECT r.rollup_id, r.mention_count AS stored, COUNT(m.id) AS live_join
FROM person_rollup r JOIN person_rollup_member pm ON pm.rollup_id=r.rollup_id
JOIN person_mentions m ON m.volume_id=pm.volume_id AND m.person_ref=pm.ref
GROUP BY r.rollup_id ORDER BY r.mention_count DESC LIMIT 5;
```
Stored and live agree exactly for all five. `volume_count` does **not** agree (Nixon: stored 148,
live 143) — it counts volumes whose *persons list* names the person, including five where no tagged
document actually mentions him. Use `volume_count` as "listed in", not "appears in".

---

## 2. The twenty most-covered people

```sql
SELECT canonical_name, mention_count, volume_count, viaf_id
FROM person_rollup ORDER BY mention_count DESC LIMIT 20;
```
plus, joined to scoped documents only, the span of dated documents each appears in:

| # | canonical name | documents | volumes listed | first → last scoped doc | VIAF |
|--:|---|---:|---:|---|:--:|
| 1 | Kissinger, Henry A. | 13,174 | 100 | 1961-04-05 → 1988-08-27 | ✓ |
| 2 | Nixon, Richard M. | 10,268 | 148 | 1953-03-25 → 1988-05-16 | ✓ |
| 3 | Rusk, David Dean | 8,855 | 92 | 1948-01-27 → 1980-04-19 | — |
| 4 | Dulles, John Foster | 7,400 | 102 | 1918-12-16 → 1979-05-29 | ✓ |
| 5 | Eisenhower, Dwight D. | 6,127 | 137 | 1943-10-22 → 1988-12-16 | ✓ |
| 6 | Carter, James Earl (“Jimmy”), Jr. | 4,518 | 50 | 1971-05-16 → 1988-02-09 | ✓ |
| 7 | Johnson, Lyndon Baines | 4,381 | 110 | 1954-04-05 → 1988-12-07 | ✓ |
| 8 | Vance, Cyrus Roberts | 4,203 | 72 | 1962-12-29 → 1987-04-13 | ✓ |
| 9 | Kennedy, John F. | 4,144 | 58 | 1960-07-07 → 1988-12-16 | — |
| 10 | Bundy, McGeorge | 3,978 | 73 | 1952-05-06 → 1982-04-06 | — |
| 11 | Johnson, Ural Alexis | 3,514 | 126 | 1951-04-04 → 1980-10-28 | ✓ |
| 12 | Rogers, William Pierce | 3,504 | 71 | 1958-01-10 → 1984-10-19 | — |
| 13 | Brzezinski, Zbigniew K. | 3,486 | 34 | 1964-01-16 → 1987-05-11 | ✓ |
| 14 | McNamara, Robert S. | 3,388 | 98 | 1961-01-12 → 1982-04-06 | ✓ |
| 15 | Gromyko, Andreĭ Andreevich | 3,290 | 143 | 1939-07-06 → 1988-12-16 | ✓ |
| 16 | Dobrynin, Anatoly F. | 3,128 | 102 | 1961-03-10 → 1988-12-07 | ✓ |
| 17 | Khrushchev, Nikita Sergeyevich | 3,047 | 87 | 1938-01-12 → 1988-12-16 | ✓ |
| 18 | Herter, Christian Archibald, Sr. | 3,017 | 66 | 1954-12-17 → 1967-05-16 | ✓ |
| 19 | Harriman, William Averell | 2,963 | 111 | 1943-05-08 → 1980-05-02 | ✓ |
| 20 | Haig, Alexander Meigs, Jr. | 2,825 | 74 | 1969-01-08 → 1983-08-01 | ✓ |

Together the top 20 hold **99,210 of 604,315 rollup-joined mentions (16.4%)**. Sixteen are American
officials, four Soviet or Soviet-bloc (Gromyko, Dobrynin, Khrushchev — and no others in the top 20;
Nasser is 24th at 2,690). Not one of the twenty holds office before 1918, and only three appear in a
document dated before 1943.

---

## 3. What this ranking CAN support

- **A description of the person index itself.** It is an accurate, verified, internally consistent
  census of `person_mentions`, rebuilt from the join and confirmed row-for-row.
- **Relative ubiquity inside the tagged half of the corpus.** Within the post-1950 volumes, where
  tagging is near-universal (§4), Kissinger really does appear in more documents than Rusk, and the
  gap (13,174 to 8,855) is large enough to survive any plausible clustering error.
- **A finding list.** These names are the fastest route into the volumes; `person_rollup_member`
  gives every (volume, ref) pair, `person_mentions` every document.
- **Cross-volume identity for about a sixth of the people.** 3,198 of 17,961 rollups (17.8%) carry
  a VIAF id, which is a real external authority link. The other 14,763 do not.

## 4. What this ranking CANNOT support — and why

### (a) It is not a ranking of FRUS. It is a ranking of the volumes that happen to be tagged.

```sql
WITH s AS (SELECT c.volume_id, c.document_id, d.date_iso FROM document_cache c
  JOIN document_dates d USING (volume_id,document_id)
  WHERE c.is_front_matter=0 AND c.is_editorial_note=0
    AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') AND d.date_iso<>'')
SELECT (CAST(substr(date_iso,1,4) AS INTEGER)/10)*10 AS decade, COUNT(*) AS docs,
  SUM(CASE WHEN EXISTS(SELECT 1 FROM person_mentions m
      WHERE m.volume_id=s.volume_id AND m.document_id=s.document_id) THEN 1 ELSE 0 END) AS tagged
FROM s WHERE CAST(substr(date_iso,1,4) AS INTEGER)>=1860 GROUP BY 1 ORDER BY 1;
```

| decade | documents | with a tagged person | share |
|---|---:|---:|---:|
| 1860s | 11,250 | 14 | 0.1% |
| 1870s | 5,798 | 524 | 9.0% |
| **1880s** | 6,472 | **0** | 0% |
| **1890s** | 9,712 | **0** | 0% |
| **1900s** | 9,924 | **0** | 0% |
| 1910s | 30,359 | 12,217 | 40.2% |
| **1920s** | 19,733 | **12** | 0.06% |
| 1930s | 39,196 | 4,441 | 11.3% |
| **1940s** | **74,043** | **5,370** | **7.3%** |
| 1950s | 42,296 | 31,188 | 73.7% |
| 1960s | 27,650 | 27,063 | 97.9% |
| 1970s | 22,259 | 21,785 | 97.9% |
| 1980s | 5,949 | 5,780 | 97.2% |
| 1990s | 177 | 177 | 100% |

Three decades return **zero**. Per the house rule I verified the emptiness is real rather than a
broken query: the same query returns 12,217 for the 1910s, and a direct count confirms it —
```sql
SELECT COUNT(*) FROM person_mentions m JOIN document_dates d USING (volume_id,document_id)
WHERE d.date_iso >= '1880-01-01' AND d.date_iso < '1910-01-01';   -- 0
```
The 1880s, 1890s and 1900s have **no tagged person mentions at all**, on 26,108 documents.

At volume grain the cliff is even sharper:

| volume's earliest document | volumes | with any person tagging |
|---|---:|---:|
| 1860s–1900s | 87 | 2 |
| 1910s | 43 | 15 |
| 1920s | 20 | 1 |
| 1930s | 44 | 5 |
| 1940s | 92 | 10 |
| 1950s | 96 | 85 |
| 1960s | 96 | 96 |
| 1970s | 62 | 61 |
| 1980s | 12 | 12 |

**254 of 266 volumes beginning in 1950 or later are tagged; 33 of 286 beginning before 1950 are.**
The person index is a modern-volume feature retro-fitted almost nowhere.

**The consequence, stated plainly.** The largest decade in the corpus — the 1940s, 74,043 documents,
a quarter of everything FRUS prints — is 92.7% invisible to these tables. So:

```sql
SELECT canonical_name, mention_count, volume_count FROM person_rollup
WHERE canonical_name LIKE 'Roosevelt, Frank%' OR canonical_name LIKE 'Hull, Cord%'
   OR canonical_name LIKE 'Truman%' OR canonical_name LIKE 'Marshall, G%' ...;
```
| | documents | volumes |
|---|---:|---:|
| Acheson, Dean Gooderham | 2,486 | 71 |
| Lansing, Robert | 2,320 | 13 |
| Molotov, Vyacheslav Mikhailovich | 1,569 | 46 |
| Stalin, Joseph | 1,045 | 23 |
| Truman, Harry S. | 1,042 | 41 |
| Churchill, Winston S. | 1,040 | 48 |
| **Roosevelt, Franklin D.** | **717** | 20 |
| Marshall, George Catlett | 649 | 25 |
| Wilson, Woodrow | 573 | 18 |
| **Hull, Cordell** | **361** | 10 |

Franklin Roosevelt ranks below roughly 150 other people in this table. Cordell Hull, Secretary of
State for eleven years, has 361 documents to Kissinger's 13,174 — a ratio of 36 to 1 against the man
who ran the Department across the corpus's single largest decade. **That ratio is a fact about the
markup, not about the archives.** Any use of this ranking as a claim about FRUS as a whole
reproduces the tagging schedule and calls it history.

### (b) The clusters under-merge, visibly, including in this very table

The house rule says person_rollup is biased to under-merge. It is, and the evidence is in the data:

```sql
SELECT a.canonical_name, a.mention_count, b.canonical_name, b.mention_count, c.reason
FROM person_cluster_candidate c
JOIN person_rollup a ON a.rollup_id=c.rollup_id_a JOIN person_rollup b ON b.rollup_id=c.rollup_id_b
ORDER BY (a.mention_count+b.mention_count) DESC LIMIT 15;
```
- `Matthews, H. Freeman, Jr.` (7) / `Matthews, Harrison Freeman (“Doc”)` (913) — one man, two rows.
- `Stettinius, Edward R.` (7) / `Stettinius, Edward Reilly, Jr.` (425) — one man, two rows.
- `Truman, Harry S.` (1,042) / `Truman, Harry` (120) — one man, two rows, **not even flagged**.
- `Hull, Cordell` (361) / `Hull, Cordell, Secretary of State` (0) — the title made a second person.

And a warning about the candidate table itself: it is a list of *suspicions*, not corrections. It
proposes merging `Hassan bin al Talal` (6) with `Hussein bin Talal` (899). Those are two different
men — brothers. Acting on the candidates unread would create errors as fast as it fixed them.

Scale of the risk: 86 distinct rollups share the surname `Smith`, 53 share `Johnson`, 43 `Brown`.
Some are genuinely distinct people and some are splits, and nothing in this database distinguishes
them. **Every count in §2 is a lower bound.**

### (c) The long tail is mostly empty

```sql
SELECT COUNT(*), SUM(mention_count=0), SUM(mention_count=1), SUM(mention_count>=1000) FROM person_rollup;
```
Of 17,961 rollups: **1,682 have zero mentions** (named in a volume's persons list, never tagged in a
document), 4,105 have exactly one, and only **76 reach 1,000**. The distribution is not a ranking
with a tail; it is twenty famous people, a thousand officials, and sixteen thousand names.

### (d) Two smaller defects worth knowing

- **6,288 orphan mentions** point at a `person_ref` with no `persons` row, in four volumes
  (`frus1932v04` 2,552, `frus1918Supp01v02` 2,114, `frus1917Supp02v02` 864, `frus1873p1v2` 454).
  They belong to no rollup and appear in no ranking.
- **`persons.role` is corrupted prose.** 34,295 of 62,931 rows have a `role` differing from
  `description` because a year was excised into `start_year` in place: Acheson's reads
  *"Secretary of State from January 21, , until January 20, 1953"*. Read `description`; never quote
  `role`.

---

## 5. Bottom line

There are three honest sentences about person coverage in this corpus.

1. `person_mentions` is a **document-level** index of TEI-tagged names covering **287 of 552
   volumes**, and within those volumes it is dense and reliable (611,307 rows, 5.29 people per
   tagged document, 108,581 of 306,619 scoped documents touched).
2. Its coverage is **not a sample of FRUS but a slice of it** — near-total from 1950, near-absent
   before, with three decades at exactly zero. The top-20 ranking is therefore a ranking of the
   Cold War volumes wearing the corpus's name.
3. Within its slice the counts are verified and consistent, but the identities are
   **under-merged lower bounds**, and one of the twenty (Truman, had he ranked) is already split
   across two rows in plain sight.

The ranking is usable as a finding aid for the tagged volumes and as a description of the index.
It is not usable as evidence about who matters in FRUS, and any chart built from it without §4(a)
printed beside it will be read as the second thing.
