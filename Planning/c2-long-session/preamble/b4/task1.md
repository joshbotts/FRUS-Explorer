# Task 1 — Chronological coverage of the FRUS corpus

Source: `frus-copy.db`, tables `document_dates` (one row per indexed document, keyed
`volume_id + document_id`) joined to `document_cache` (which carries the
`is_front_matter` / `is_editorial_note` flags). 552 volumes indexed.

## 1. What is being counted

The index holds **316,839 document rows**. They reconcile exactly as:

| Class | Rows |
|---|---:|
| Front matter (prefaces, "About the Series", editorial-method notes) | 1,012 |
| Body documents with no resolvable date | 1,340 |
| Body documents dated before 1861 | 475 |
| Body documents dated 1861–1992 | 314,012 |
| **Total** | **316,839** |

Two exclusions matter and both are made below unless stated otherwise.

**Front matter is excluded.** It is dated at *publication*, not at coverage. This is
the entire explanation for the corpus appearing to hold documents from 2016, 2019 and
2024: those are prefaces of recent volumes, e.g. `frus1969-76v35/preface` stamped
2014-03-01. Counting raw `date_iso` without the flag produces a spurious modern tail.

**Pre-1861 documents are a retrospective artefact, not coverage.** All 475 sit in a
handful of volumes — overwhelmingly `frus1872p2v1`, `frus1872p2v5` and `frus1894app2`,
the arbitration and claims-commission volumes, which reprint older correspondence as
evidence. The three "1620s" documents are of this kind. The series itself begins in
1861; nothing before that should be read as chronological coverage.

Date quality over the whole table: 299,568 rows (94.6%) are day-precision and exact;
12,385 are day-precision but recorded as a range; 2,420 are approximate; 303 are
month- or year-precision only; 2,163 carry no date. Where a document spans days
(11,265 rows have `date_iso <> date_iso_max`) it is bucketed by its **start** date.

## 2. Documents per decade of document date

Body documents only (front matter excluded), 1861–1992.

| Decade | Documents | Volumes | Docs/volume | Docs/year | Mean chars/doc | Editorial notes |
|---|---:|---:|---:|---:|---:|---:|
| 1860s | 11,238 | 29 | 388 | 1,124 | 4,559 | 0 |
| 1870s | 5,798 | 25 | 232 | 580 | 8,037 | 0 |
| 1880s | 6,472 | 21 | 308 | 647 | 5,437 | 0 |
| 1890s | 9,712 | 22 | 442 | 971 | 3,719 | 0 |
| 1900s | 9,925 | 25 | 397 | 993 | 3,494 | 1 |
| 1910s | 30,370 | 52 | 584 | 3,037 | 2,806 | 11 |
| 1920s | 19,733 | 41 | 481 | 1,973 | 2,750 | 0 |
| 1930s | 39,197 | 58 | 676 | 3,920 | 2,576 | 1 |
| **1940s** | **75,680** | 104 | 728 | 7,568 | 3,298 | 1,637 (2.2%) |
| 1950s | 46,506 | 108 | 431 | 4,651 | 5,437 | 3,852 (8.3%) |
| 1960s | 29,817 | 121 | 246 | 2,982 | 5,830 | 2,167 (7.3%) |
| 1970s | 23,264 | 97 | 240 | 2,326 | 7,882 | 623 (2.7%) |
| 1980s | 6,123 | 41 | 149 | 612 | 8,125 | 174 (2.8%) |
| 1990s | 177 | 1 | 177 | 18 | 10,134 | 0 |

Every year from 1861 to 1991 is represented; only 1992 is empty. The distribution is
single-peaked and strongly skewed: **the median document date is 1943**, and the seven
years 1939–1945 alone hold 16.1% of the corpus (7,232 documents per year against a
132-year mean of 2,379).

Era shares:

| Era | Documents | Share | Per year |
|---|---:|---:|---:|
| 1861–1899 (annual congressional volumes) | 33,220 | 10.6% | 852 |
| 1900–1918 (annual volumes, into WWI) | 36,110 | 11.5% | 1,901 |
| 1919–1938 (interwar) | 58,185 | 18.5% | 2,909 |
| 1939–1945 (WWII) | 50,624 | 16.1% | 7,232 |
| 1946–1968 (Cold War, triennial/quadrennial) | 103,615 | 33.0% | 4,505 |
| 1969–1992 (Nixon onward) | 32,258 | 10.3% | 1,344 |

Peak years: 1945 (11,540), 1944 (8,731), 1946 (8,171), 1949 (7,858), 1943 (7,832),
1948 (7,392), 1951 (7,268), 1941 (6,577), 1947 (6,565), 1954 (6,521). The one
pre-1939 year in the top dozen is 1918 (5,903).

## 3. What the shape suggests about editorial priorities

**The series is a war-and-Cold-War archive with a nineteenth-century prologue.**
Roughly half of everything the corpus holds (49.1%) falls in the 1939–1968 window —
thirty years out of a hundred and thirty. Two-thirds of the corpus post-dates 1919.
An interest in mid-nineteenth-century US diplomacy is served thinly here even though
the series formally begins in 1861: the whole Civil War-through-McKinley span is 10.6%.

**Density tracks crisis, not calendar.** The 1910s (3,037 docs/yr) and 1930s–40s are
where the editors concentrated, and within them the sub-peaks are 1914–1919 and
1941–1946. The interwar 1920s are a genuine trough (1,973/yr, below both flanking
decades) — the same editorial machinery producing much less because the diplomacy
being documented was less consequential to the editors. This is a priority signal, not
a records-availability signal: the 1920s were published on the same annual schedule as
the 1910s and 1930s.

**Editorial method changes visibly after 1945, in three linked measurements.**

1. *Documents per volume falls by four-fifths* — 728 (1940s) → 431 → 246 → 240 → 149
   (1980s) — while the number of volumes per decade keeps rising to a peak of 121 in
   the 1960s. The series stops trying to print the correspondence and starts printing
   a selection from it.
2. *Mean document length triples* — 2,576 characters in the 1930s to 7,882 in the
   1970s and 8,125 in the 1980s. The unit of publication shifts from the short
   telegram and despatch to the memorandum of conversation, the NSC paper and the
   analytical minute.
3. *Editorial notes appear from nothing.* There are **twelve** across the entire
   1861–1939 corpus and 8,453 after it, peaking at 8.3% of the 1950s. These are the
   editors writing prose where a document could not be printed. Their arrival is a
   direct index of the classification regime the series began operating under.

Net of (1) and (2), total *text* volume peaks in the 1940s (244 M characters) with the
1950s nearly level (232 M) and only then declines — so the fall in document counts
after 1950 overstates the fall in editorial effort.

**The recent tail is publication lag, not editorial neglect, and it is the one part of
this profile that will move.** Coverage runs at 1,300–3,000 documents a year through
1980 and then collapses: 1981–1988 averages 530 documents a year across just 9 volumes
per year of coverage, and 1989–1992 is a single volume (`frus1989-92v31`, 177
documents in 1990–91). The manifest explains it — the 1969-76 subseries has 66
volumes and 1977-80 has 27, but 1981-88 has only 12 and 1989-92 has 1, with volumes
still being printed in 2024 and 2025. Any per-decade comparison that includes the
1980s is comparing a finished subseries against one in progress.

## 4. Cautions for anyone reusing these counts

- A "document" here is an indexed TEI `div`, which mixes printed documents,
  attachments and editorial notes. The editorial-note column above lets you net them
  out; below 1940 the distinction is immaterial, above it it is not.
- Bucketing is by start date. The 11,265 span-dated rows (peaking at 8.7% of the
  1950s) are assigned to their first day, so decade boundaries are slightly soft.
- 1,340 body documents carry no date at all, spread over 154 volumes; they are absent
  from every figure above.
- Document counts are not page counts and not words. The mean-length column shows
  they diverge by a factor of three across the series.
