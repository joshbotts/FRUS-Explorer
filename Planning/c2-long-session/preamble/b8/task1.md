# Task 1 — Chronological coverage of the corpus

**Surface used:** the SQLite index only (`/Users/jbotts/frus-analysis/frus-copy.db`, read-only).
No TEI and no bundled JSON were needed or consulted for this task.

**Periodisation basis:** `document_dates.date_iso`, the editorial per-document minimum date
(`frus:doc-dateTime-min`), **not** the volume's series year. Where a volume's series year and its
documents' dates disagree — and they routinely do — this profile follows the documents.

---

## 0. Coverage (mandated first query)

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note)
FROM document_cache;
```

| volumes | documents | front matter | editorial notes |
|---|---|---|---|
| 552 | 316,839 | 1,012 | 8,468 |

This library is **complete against the published series as the app defines it: 552 of 552 volumes.**
Nothing below is limited by a partial download. It *is* limited by what FRUS has published — see §6.

### Working scope for every number in this document

```sql
SELECT COUNT(*) AS scoped_docs, COUNT(DISTINCT volume_id) AS scoped_vols FROM document_cache
WHERE is_front_matter=0 AND is_editorial_note=0
  AND volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2');
```
→ **306,619 documents across 550 volumes.**

Three reductions, each stated so it can be undone:
1. Front matter dropped (1,012 rows). Its dates are *publication* dates — the latest `date_iso` in
   the whole database is `2024-03-01`, on `frus1977-80v04/about-the-series`. Leaving it in would
   have put documents in the 2020s.
2. Editorial notes dropped (8,468). They are editor prose, not documents. They are profiled
   separately in §5, because *where the editors write* is itself an editorial-priority signal.
3. Second editions suppressed per house rule: `frus1951-54IranEd2` and `frus1969-76ve15p2Ed2`
   dropped, `frus1977-80v09Ed2` kept (it has no first edition to duplicate).
   ```sql
   SELECT COUNT(*) FROM document_cache
   WHERE volume_id IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
     AND is_front_matter=0 AND is_editorial_note=0;   -- 740
   ```
   That removes **740** documents from this index. Note this is not the 701 the house rule cites as
   the measured *overlap* with the first editions; 740 is the raw size of the two Ed2 volumes' text,
   701 is how many of those duplicate a first-edition document. Both numbers are right about
   different things; the suppression removes 740 rows.

**Dated fraction:** 305,280 of the 306,619 scoped documents carry a date (99.6%). The 1,339 undated
ones are spread over 154 volumes and concentrate in `frus1919Parisv13` (167) — the Paris Peace
Conference volume — then `frus1946v05` (58) and `frus1942v01` (37). They are excluded from the
decade table by construction and are too few to move any figure in it.

### Scan controls (run in one pass, as required)

```sql
SELECT 'POSITIVE', COUNT(*), COUNT(DISTINCT volume_id) FROM frus_documents
  WHERE frus_documents MATCH '"Department of State"'
UNION ALL SELECT 'NEGATIVE', COUNT(*), COUNT(DISTINCT volume_id) FROM frus_documents
  WHERE frus_documents MATCH 'ZZZ_IMPOSSIBLE_ZZZ';
```
Positive: **98,499 rows in 551 of 552 volumes.** Negative: **0 rows, 0 volumes.** The index is live
and an absence in it means something. (The one volume with no match is `frus1919Parisv05`, a volume
of Council of Ten minutes; I checked which it was rather than leaving a bare 551.)

---

## 1. Documents per decade of document date

```sql
WITH s AS (
  SELECT c.volume_id, d.date_iso
  FROM document_cache c JOIN document_dates d USING (volume_id, document_id)
  WHERE c.is_front_matter=0 AND c.is_editorial_note=0
    AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
    AND d.date_iso <> '')
SELECT (CAST(substr(date_iso,1,4) AS INTEGER)/10)*10 AS decade,
       COUNT(*) AS docs,
       ROUND(100.0*COUNT(*)/(SELECT COUNT(*) FROM s),2) AS pct,
       COUNT(DISTINCT volume_id) AS vols_touching,
       ROUND(1.0*COUNT(*)/COUNT(DISTINCT volume_id),1) AS docs_per_vol
FROM s WHERE CAST(substr(date_iso,1,4) AS INTEGER) >= 1860
GROUP BY 1 ORDER BY 1;
```

| decade | documents | of 305,280 | volumes touching | docs per touching volume |
|---|---:|---:|---:|---:|
| 1860s | 11,250 | 3.69% | 29 | 388 |
| 1870s | 5,798 | 1.90% | 25 | 232 |
| 1880s | 6,472 | 2.12% | 21 | 308 |
| 1890s | 9,712 | 3.18% | 22 | 442 |
| 1900s | 9,924 | 3.25% | 25 | 397 |
| 1910s | 30,359 | 9.94% | 52 | 584 |
| 1920s | 19,733 | 6.46% | 41 | 481 |
| 1930s | 39,196 | 12.84% | 57 | 688 |
| **1940s** | **74,043** | **24.25%** | 103 | 719 |
| 1950s | 42,296 | 13.85% | 107 | 395 |
| 1960s | 27,650 | 9.06% | 121 | 229 |
| 1970s | 22,259 | 7.29% | 95 | 234 |
| 1980s | 5,949 | 1.95% | 41 | 145 |
| 1990s | 177 | 0.06% | 1 | 177 |

"Volumes touching" does not sum to 550: a volume that prints a 1944 enclosure in a 1946 compilation
is counted in both decades.

**Pre-1860 tail:** 462 documents, from 1620-11-03 to 1859. These are not coverage — they are
retrospective exhibits printed inside later volumes. `frus1872p2v5` (the Hudson's Bay/Puget Sound
claims arbitration) supplies the 17th-century material; `frus1902app2` (the Pious Fund of the
Californias arbitration) supplies most of the 18th. Two arbitration case files account for nearly
the whole tail, and they say nothing about FRUS's chronological reach.

**Distribution shape, in three numbers:**
```sql
-- quartiles over the same scoped, dated set, ordered by date_iso
q1 = 1920-12-03   median = 1943-05-01   q3 = 1954-05-12
```
Half of everything FRUS prints falls in the 34 years between December 1920 and May 1954. The median
document is dated **1 May 1943**.

**Single peak year:** 1945, with **11,410** documents — more than the whole 1870s and 1880s combined
(12,270 over twenty years). The war years in order: 1943 = 7,664, 1944 = 8,672, **1945 = 11,410**,
1946 = 7,951. The First World War has the same shape at a third the amplitude: 1917 = 4,564,
1918 = 5,903, 1919 = 4,185, falling to 1,848 by 1921.

---

## 2. The shape is not one curve but two, and they run opposite

Document *count* peaks in the 1940s. Document *length* bottoms out just before it.

```sql
-- same scope; length(body_text) in characters
SELECT decade, COUNT(*) docs, ROUND(AVG(length(body_text))) mean_chars,
       ROUND(SUM(length(body_text))/1e6,1) total_Mchars ...
```

| decade | documents | mean chars/doc | total text (M chars) |
|---|---:|---:|---:|
| 1860s | 11,250 | 4,562 | 51.3 |
| 1870s | 5,798 | 8,037 | 46.6 |
| 1880s | 6,472 | 5,437 | 35.2 |
| 1890s | 9,712 | 3,719 | 36.1 |
| 1900s | 9,924 | 3,494 | 34.7 |
| 1910s | 30,359 | 2,806 | 85.2 |
| 1920s | 19,733 | 2,750 | 54.3 |
| 1930s | 39,196 | **2,576** | 101.0 |
| 1940s | 74,043 | 3,298 | **244.2** |
| 1950s | 42,296 | 5,429 | 229.6 |
| 1960s | 27,650 | 5,830 | 161.2 |
| 1970s | 22,259 | 7,893 | 175.7 |
| 1980s | 5,949 | 8,125 | 48.3 |

Mean length is U-shaped: ~8,000 characters in the 1870s, down to 2,576 in the 1930s, back to 8,125
in the 1980s — a threefold swing in both directions. **Caveat, and it is not a small one:**
`body_text` includes editorial footnotes, so this column measures document plus apparatus and cannot
be split here. The rising modern mean is therefore partly the editors annotating more heavily, not
only the documents getting longer. Separating the two needs the TEI, which this task did not use.

By total text the 1940s and 1950s are near-equals (244M vs 230M characters) even though the 1940s
have 75% more documents. The 1970s hold 175.7M characters in 22,259 documents — more text than the
1910s' 30,359 documents.

---

## 3. Density, not shelf space, drives the bulge

The 1960s are touched by **121** volumes and the 1940s by **103**, yet the 1940s hold 74,043
documents to the 1960s' 27,650. Documents per touching volume runs 719 (1940s) → 395 (1950s) →
229 (1960s) → 145 (1980s). The modern series has not shrunk; it has stopped printing short papers.
A 1940s volume is a compilation of telegrams; a 1970s volume is a selection of memoranda.

---

## 4. Dating confidence degrades toward the present

```sql
SELECT decade, COUNT(*), SUM(date_certainty='exact'), SUM(date_certainty='range'),
       SUM(date_certainty='approximate') ... GROUP BY decade;
```

| decade | documents | exact | range | approximate |
|---|---:|---:|---:|---:|
| 1910s | 30,359 | 30,017 | 8 | 334 |
| 1930s | 39,196 | 39,125 | 7 | 64 |
| 1940s | 74,043 | 73,348 | 57 | 638 |
| 1950s | 42,296 | 41,805 | 300 | 191 |
| 1960s | 27,650 | 26,734 | 701 | 215 |
| 1970s | 22,259 | 19,551 | **2,325** | 383 |
| 1980s | 5,949 | 5,230 | 605 | 114 |

Range-dating is 2,325 of 22,259 documents in the 1970s (10.4%) against 7 of 39,196 in the 1930s
(0.02%) — a 500-fold difference in rate. A 19th-century despatch carries a dateline; a modern
undated intelligence memorandum or draft paper does not, and the editors bracket it. Anyone drawing
a fine-grained modern timeline off `date_iso` is placing 10% of the 1970s at the earliest date it
could bear.

---

## 5. Where the editors intervene (apparatus channel — never sum with §1)

Editorial notes are excluded from every count above. Profiled on their own, dated the same way:

| decade | editorial notes |
|---|---:|
| pre-1930 (all) | 13 |
| 1930s | 1 |
| 1940s | 1,637 |
| 1950s | 3,835 |
| 1960s | 2,167 |
| 1970s | 623 |
| 1980s | 174 |

**8,436 of the 8,450 dated editorial notes fall after 1939 (99.8%).** The editorial note is
essentially a post-war invention. It is the device by which modern FRUS describes material it has
not printed — the covert operation, the still-classified paper, the meeting held without a record.
Its distribution is the negative image of §1: the notes cluster exactly where the archival record
became too large and too classified to print whole.

---

## 6. What the distribution says about editorial priorities

1. **FRUS is a Second-World-War-and-after publication with a 19th-century prologue.** A quarter of
   everything it prints is dated in the 1940s, and half of it in 1920–1954. The 1860s–1900s together
   are 43,156 documents, 14.1% of 305,280 — less than the 1940s alone.

2. **The two world wars are the series' organising events, and 1945 is its centre of gravity.** Both
   wars produce a step change, not a bump; neither returns to baseline afterwards. The 1920s dip
   (19,733, down from 30,359 in the 1910s) is the interwar retrenchment, and the 1930s recovery is
   already the approach to the next war.

3. **The editorial unit changed around 1950.** Before it, FRUS printed many short items and let the
   file speak. After it, FRUS prints fewer, longer, more analytic papers and annotates them heavily.
   Count and length move in opposite directions across that hinge, and the editorial note appears
   in volume at the same moment. These are three symptoms of one decision: from *compilation* to
   *documentary edition*.

4. **The thin ends are two different kinds of thin, and must not be read alike.** The 1980s (5,949)
   and 1990s (177, all from `frus1989-92v31`) are thin because **the series has not been published
   that far yet** — this database holds 12 Reagan-era volumes and exactly one Bush-era volume. That
   is a publication frontier, not an editorial judgement, and it will fill in. The 1870s–1880s
   (5,798 and 6,472) are thin because the editors of the day compiled thinly. Reading either as
   evidence about the archives would be wrong, and reading them as the same phenomenon would be
   worse.

5. **The pre-1860 material is not coverage.** 462 documents back to 1620 are exhibits in two
   arbitration case files. FRUS begins in 1861 and the data agrees.

### Limits of this profile
- Every count depends on `date_iso` being the *document's* date. Front matter proved that
  assumption needs enforcing (its dates are publication dates), which is why §0 drops it.
- Mean length blends document and footnote (§2) and cannot be split in this database.
- Volumes touching a decade overlap; the column does not sum.
- 1,339 scoped documents (0.4%) carry no date and appear nowhere in §1.
- This is a count of documents, not of pages, words, or importance. A one-line telegram and a
  fifty-page conference record are each one row.
