# Task 1 — Chronological coverage of the FRUS corpus

Source: `frus-copy.db` (`document_dates` joined to `document_cache`), cross-checked against the
TEI corpus at `/Users/jbotts/Development/frus/volumes/` and the bundled `manifest.json`.
All figures are documents, not pages.

## 1. What is being counted

The index holds **316,839 rows**, one per document-level `<div>` in the 552 TEI volumes. They are
not all "documents" in the historian's sense:

| category | rows |
|---|---|
| printed documents | 307,359 |
| editorial notes | 8,468 |
| front matter (prefaces, "About the Series", press releases) | 1,012 |

`document_dates` carries a row for every one of them. **2,163 (0.7%) have no date at all**; of the
remainder, 314,373 are dated to the day, 251 to the month, and 52 only to the year. Date certainty
is recorded as `exact` for 299,871, `range` for 12,385 and `approximate` for 2,420.

Two decisions shape every number below, and both matter:

- **Front matter is excluded.** 189 front-matter rows carry a date, and that date is the date of
  *printing*, not of the record. All 40 documents the index places after 1999 are of this kind —
  "About the Series" essays stamped 2013–2024. Left in, they would invent a 21st-century tail for a
  series whose latest real document is a telegram of **1991-11-20** (`frus1989-92v31/d247`).
- **Documents are binned by the *start* of their date range.** 2,878 dated rows (0.9%) span more
  than one decade; each is credited to the earlier one.

Working total after these rules: **314,487 dated documents**.

## 2. Documents per decade of document date

```
1860s  11250  #########
1870s   5798  #####
1880s   6472  #####
1890s   9712  ########
1900s   9925  ########
1910s  30370  ########################
1920s  19733  ################
1930s  39197  ###############################
1940s  75680  ############################################################
1950s  46506  #####################################
1960s  29817  ########################
1970s  23264  ##################
1980s   6123  #####
1990s    177
```

| decade | documents | share | of which editorial notes | volumes contributing | docs/volume | mean chars |
|---|---|---|---|---|---|---|
| 1860s | 11,250 | 3.6% | 0 | 29 | 388 | 4,562 |
| 1870s | 5,798 | 1.8% | 0 | 25 | 232 | 8,037 |
| 1880s | 6,472 | 2.1% | 0 | 21 | 308 | 5,437 |
| 1890s | 9,712 | 3.1% | 0 | 22 | 442 | 3,719 |
| 1900s | 9,925 | 3.2% | 1 | 25 | 397 | 3,494 |
| 1910s | 30,370 | 9.7% | 11 | 52 | 584 | 2,806 |
| 1920s | 19,733 | 6.3% | 0 | 41 | 481 | 2,750 |
| 1930s | 39,197 | 12.5% | 1 | 58 | 676 | 2,576 |
| **1940s** | **75,680** | **24.1%** | 1,637 | 104 | 728 | 3,262 |
| 1950s | 46,506 | 14.8% | 3,852 | 108 | 431 | 5,149 |
| 1960s | 29,817 | 9.5% | 2,167 | 121 | 246 | 5,612 |
| 1970s | 23,264 | 7.4% | 623 | 97 | 240 | 7,795 |
| 1980s | 6,123 | 2.0% | 174 | 41 | 149 | 8,055 |
| 1990s | 177 | 0.1% | 0 | 1 | 177 | 10,134 |

A further **481 documents predate 1860**, scattered from 1620 to 1859. These are not a thin early
run of the series — FRUS begins in 1861. They are historical exhibits reprinted inside later
volumes: the 1872 Treaty of Washington arbitration volumes (`frus1872p2v5` opens with a document of
1620-11-03) and the 1902 Pious Fund appendix (`frus1902app2`, Spanish colonial decrees of the 1690s
to 1790s). They are a property of *what the volumes enclose*, not of what the series covers.

**Peak years:** 1945 (11,540), 1944 (8,731), 1946 (8,171), 1949 (7,858), 1943 (7,832), 1948
(7,392), 1951 (7,268). Every one of the top seven years falls in 1943–1951.

## 3. What the shape suggests

**a) The corpus is a WWII-and-after corpus with a 19th-century preamble.**
The 1940s and 1950s alone hold 38.9% of all dated documents; 1930–1979 holds 68.2%. The entire
period 1861–1909 — half a century of the series' own existence — accounts for 13.8%. Whatever the
series is for, its centre of documentary mass is the two decades either side of 1945.

**b) The 1940s spike is real, not an artefact of volume count.**
The 1960s has *more* volumes contributing (121) than the 1940s (104) and produces 40% as many
documents. The 1940s is dense: 728 documents per contributing volume, the highest of any decade.
The single busiest year, 1945, carries more documents (11,540) than the whole of the 1860s (11,250), and nearly twice the whole of the 1870s.

**c) There is a clear editorial regime change around 1950.**
Three measurements move together and point the same way:

- *Documents per volume* falls from 728 (1940s) to 431, 246, 240, 149 across the following decades.
- *Mean document length* rises in mirror image: 2,576 characters in the 1930s, 3,262 in the 1940s,
  then 5,149 / 5,612 / 7,795 / 8,055 in the 1950s–1980s.
- *Editorial notes*, effectively absent before 1940 (13 in eight decades), become 1,637 in the
  1940s, 3,852 in the 1950s, 2,167 in the 1960s.

The pre-war volumes print a *dossier* — many short telegrams and despatches, published nearly
contemporaneously, with the record left to speak. The post-war volumes print a *selection* — fewer,
longer memoranda and minutes, with an editorial apparatus that summarises what has been left out.
This is a change in what "printing the record" is taken to mean, and it means decade-to-decade
document counts are not a like-for-like measure of coverage.

**d) The total text tells a slightly different story than the document count.**
By characters of body text the peak is flatter: 246.8M (1940s), 239.4M (1950s), 181.3M (1970s),
167.3M (1960s), 101.0M (1930s). The 1970s look sparse counted in documents (7.4%) but are the
third-largest decade counted in prose. Any reading of "editorial priority" from the histogram alone
overstates the modern decline.

**e) The thin recent tail is a release schedule, not a judgement.**
1980s = 2.0% and 1990s = 0.1% because the series is still being published there: the 1989–92
subseries is represented by a single volume in this snapshot, and 1991-11-20 is where the corpus
stops. This is the declassification frontier showing through, and it will move.

**f) Sub-peaks track wars and settlements.** 1918 (5,903) and 1919 (4,185) sit well above their
neighbours; the 1910s decade is carried by the annual volumes plus the WWI supplements
(`frus1915Supp`, `frus1914Supp`, `frus1916Supp`) and the Paris Peace Conference set. The series
expands where a crisis produces both more paper and more political demand to publish it.

## 4. Caveats a user of these numbers should carry

1. **A "document" is an editorial unit of unequal size.** An 1870s document averages 8,037
   characters, a 1930s one 2,576. Counting documents compares the series' packaging, not its
   substance; the character column is the corrective.
2. **The date is the document's own date, not the volume's.** Volumes bleed: `frus1945v09` contains
   material from 1942 to 1946. Decade totals therefore do not decompose cleanly into subseries.
3. **`manifest.json`'s `dateRange` is empirical, not nominal.** It is the observed span of the
   volume's documents (which is why `frus1872p2v5` is listed as beginning in 1620), so it cannot be
   used to test whether a document falls "outside" its volume's coverage — by construction none do.
4. **2,163 documents are undated** and drop out of every decade figure; they cluster in
   `frus1919Parisv13` (168) and in the WWII volumes.
5. **Editorial notes are counted as documents here.** They are not archival records, and in the
   1950s they are 8.3% of that decade's total.
