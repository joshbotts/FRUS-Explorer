# Task 1 — Chronological coverage of the FRUS corpus

Source: the FRUS Explorer search index (`frus-copy.db`), tables `document_cache` and
`document_dates`, cross-checked against the bundled `manifest.json` (552 volumes).
All figures below are counts of *documents as the index defines them*, not pages.

## 1. What is being counted

| population | count |
|---|---|
| rows in `document_cache` (552 volumes) | 316,839 |
| front-matter items (prefaces, "About the Series", etc.) | 1,012 |
| editorial notes (`is_editorial_note = 1`) | 8,468 |
| rows with no usable date | 2,163 (0.7%) |
| **dated, non-front-matter documents — the working population** | **314,487** |

Every row in `document_cache` has a matching row in `document_dates`, so nothing is lost to a
failed join; the 2,163 undated items are genuinely undated in the TEI (823 of them front matter).
Dating is unusually clean: 314,373 of 316,839 rows carry **day** precision, and only 12,385 are
recorded as a range rather than an exact date — and those ranges are heavily post-1945 (11,882
of them), which is what one would expect, since ranges are mostly editorial notes summarising a
span of weeks.

Two boundary cases must be removed before the distribution means anything:

* **Front matter is dated by publication, not by content.** Forty rows carry dates from 2000–2024;
  all forty are prefaces or "About the Series" pages, e.g. `frus1969-76v33/preface` dated
  2013-08-01. They are not twenty-first-century documents.
* **The earliest 475 documents are retrospective exhibits, not early coverage.** They sit almost
  entirely in arbitration compilations — `frus1872p2v1` and `frus1872p2v5` (the Geneva/*Alabama*
  claims papers, 344 documents reaching back to a 1620-11-03 item), `frus1894app2`, and
  `frus1902app2` (the *United States vs. Mexico* case, reaching back to 1697). These are
  eighteenth- and early-nineteenth-century papers *printed as evidence inside* volumes published
  in the 1870s–1900s. The series' real coverage begins in 1861.

## 2. Documents per decade of document date

Excludes front matter. `vols` = number of the 552 volumes that contribute at least one document
to the decade.

| decade | documents | of which editorial notes | mean length (chars) | volumes |
|---|---|---|---|---|
| pre-1860 | 475 | 1 | — | 9 (retrospective exhibits) |
| 1860s | 11,250 | 0 | 4,562 | 29 |
| 1870s | 5,798 | 0 | 8,037 | 25 |
| 1880s | 6,472 | 0 | 5,437 | 21 |
| 1890s | 9,712 | 0 | 3,719 | 22 |
| 1900s | 9,925 | 1 | 3,494 | 25 |
| 1910s | 30,370 | 11 | 2,806 | 52 |
| 1920s | 19,733 | 0 | 2,750 | 41 |
| 1930s | 39,197 | 1 | 2,576 | 58 |
| **1940s** | **75,680** | 1,637 | 3,262 | 104 |
| 1950s | 46,506 | 3,852 | 5,149 | 108 |
| 1960s | 29,817 | 2,167 | 5,612 | 121 |
| 1970s | 23,264 | 623 | 7,795 | 97 |
| 1980s | 6,123 | 174 | 8,055 | 41 |
| 1990s | 177 | 0 | 10,134 | 1 |

Rolled into editorially meaningful eras (denominator 314,012, i.e. 1861–1991):

| era | documents | share | documents/year |
|---|---|---|---|
| 1861–1899 (annual-volume era) | 33,220 | 10.6% | 852 |
| 1900–1917 | 30,207 | 9.6% | 1,678 |
| 1918–1938 (interwar) | 64,088 | 20.4% | 3,052 |
| 1939–1945 (Second World War) | 50,624 | 16.1% | 7,232 |
| 1946–1968 (early Cold War) | 103,615 | 33.0% | 4,505 |
| 1969–1980 | 27,780 | 8.8% | 2,315 |
| 1981–1991 | 4,478 | 1.4% | 407 |

The single densest year is **1945 (11,540 documents, 3.7% of the whole corpus)**. The 1940s
decade alone is 24% of the corpus. Consecutive annual peaks: 1943 (7,832), 1944 (8,731),
1945 (11,540), 1946 (8,171), 1949 (7,858), 1948 (7,392), 1951 (7,268), 1954 (6,521).

## 3. What the shape suggests about editorial priorities

**(a) The distribution is single-peaked at 1945 and asymmetric.** Coverage rises slowly from 1861,
inflects sharply at the First World War, doubles again through the 1930s, peaks in 1945, and
declines steadily thereafter. This is not a proxy for the volume of American diplomacy: it is a
statement about which decades the series' editors judged worth documenting exhaustively. The
twentieth-century crisis years — 1914–1919, 1939–1951 — are the series' centre of gravity.

**(b) The nineteenth-century volumes are a different publication with a different purpose.**
1861–1899 averages 852 documents a year across 39 years. In that period FRUS was a
*contemporaneous* annual transmittal to Congress: the papers were selected, printed and laid
before Congress within a year or two of being written. It was an instrument of executive
accountability rather than a historical edition. The per-year counts move with events but stay
in one band (387 in 1861, 2,766 in 1865, back to 238 in 1869, 1,409 in 1894) — the size of the
annual volume was set by the calendar and the printing budget, not by retrospective judgement of
which years mattered.

**(c) The twentieth-century growth is compilation, not correspondence.** From the 1910s onward the
series is edited retrospectively from the Department's central files, and volumes multiply per
year: 8–13 volumes contribute to a typical year before 1914, but 31 contribute to 1945, 36 to
1952, and 40 to 1969 and 1972. The 1910s spike (30,370 documents) is the war and the Paris Peace
Conference; the 1940s peak is the war, the wartime conferences, and the founding of the postwar
order. Editorial priority here means *subject* priority — the years in which American foreign
policy was being invented get near-exhaustive treatment.

**(d) The post-1960 decline is partly a change of editorial method and partly an artefact.** Two
distinct things are happening and they must not be conflated:

* *Method.* Mean document length rises monotonically after 1930: 2,576 characters in the 1930s,
  5,149 in the 1950s, 7,795 in the 1970s, 8,055 in the 1980s — a threefold increase. The modern
  volumes print fewer, longer items (memoranda of conversation, NSC papers, policy studies,
  editorial notes) rather than the dense telegraphic traffic of the 1930s–40s. A count of
  documents therefore *understates* modern coverage relative to earlier decades. The 1970s hold
  23,264 documents but 181 million characters — comparable to the 1950s' 239 million from twice
  as many documents. Editorial notes, effectively absent before 1940, become a real fraction of
  the modern volumes (3,852 in the 1950s, 2,167 in the 1960s): the editors summarise where they
  cannot print.
* *Artefact.* The collapse after 1980 is **not** an editorial judgement at all. It is the
  declassification and publication frontier. The 1977–80 subseries has 27 published volumes and
  yields 1,660–2,433 documents a year; the 1981–88 subseries has only **12** volumes published so
  far and yields 407–842 a year; the 1989–92 subseries has exactly **one** published volume
  (`frus1989-92v31`, START I, printed 2025), which supplies every one of the 177 documents dated
  in the 1990s. Any statement of the form "the series covers the 1980s thinly" is a statement
  about the state of the series in 2025, not about its priorities.

**(e) Caveats on the counting unit.** A "document" here is whatever the TEI marks as a document
division: a two-line telegram and a forty-page conference record count alike, and editorial notes
count as documents. Enclosures are generally folded into their parent. Nothing in this table
measures pages, words of *printed* text, or archival volume. The mean-length column is the only
correction offered for that, and it is a crude one.
