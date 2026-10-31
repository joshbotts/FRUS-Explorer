# Scope memo: corruption and U.S. foreign policy (run s9, 2026-10-30)

Operator-facing. Every number below gives its query or script; the scripts and their outputs are in this run directory. Every count is conditional on this library. The library holds **553 of the 553 volumes** of the series: the index copy of 2026-10-25, with 321,749 documents, 1,103 of them front matter and 8,481 editorial notes.

## 0. Canary, read-only proof, coverage

```
sqlite3 "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro" "SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;"
-> 553|321749|1103|8481
sqlite3 -readonly ... "BEGIN; CREATE TABLE zz(x); ROLLBACK;"  -> Error: attempt to write a readonly database
```

The denominator used throughout is non-apparatus documents, with the second editions suppressed:
`SELECT COUNT(*), COUNT(DISTINCT volume_id) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0 AND volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2');` gives **311,429 documents in 551 volumes**. frus1977-80v09Ed2 is kept.

Late-era coverage: `SELECT substr(volume_id,1,11), COUNT(DISTINCT volume_id), COUNT(*) FROM document_cache WHERE volume_id LIKE 'frus1977-80%' OR volume_id LIKE 'frus1981-88%' OR volume_id LIKE 'frus1989%' GROUP BY 1;` gives frus1977-80 27 volumes and 8,395 documents; frus1981-88 13 and 4,367; frus1989-92 1 and 250.

## 1. Scope chosen and how

**Vocabulary.** The FTS vocabulary was read first:
`SELECT term, doc, cnt FROM frus_documents_vocab WHERE term LIKE 'corrupt%' OR term LIKE 'brib%' OR ...`
It gave corrupt 2253 docs, bribe 431, briberi 309, graft 372, embezzl 174, venal 161, payoff 155, misappropri 94, nepot 50, kickback 18. These doc figures include apparatus. `lockhe` exists as a stem, but MATCH 'lockhe' returned 0 because the query term is stemmed again. The relaxed form MATCH 'lockheed' returns 196 documents in 79 volumes; most are aircraft, not the scandal.

**Scope set S (inclusion rule for counting).** S is every non-apparatus document whose text matches the expression below, with the Ed2 volumes dropped:
`frus_documents MATCH 'corrupt* OR brib* OR graft OR embezzl* OR kickback* OR "illicit payment"' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')`
It holds **3,060 documents in 447 volumes**: 3,060 of 311,429, about 1 in 102. The scope is not restricted by date.

**Inclusion rule for the collection.** A document is collected when its text shows U.S. officials weighing corruption, or a corruption allegation, in a choice about aid, leverage, disclosure, negotiation or troop deployment. Candidates came from bm25-ranked queries within the top volumes (§3), from document headers, and from scandal-specific searches. The collection holds 21 documents in 14 volumes.

**Top volumes in S** (Ed2 not yet dropped in this query):
`SELECT c.volume_id, COUNT(*) n FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'corrupt* OR brib* OR graft OR embezzl* OR kickback*' AND c.is_front_matter=0 AND c.is_editorial_note=0 GROUP BY 1 ORDER BY n DESC LIMIT 30;`
The first rows: frus1947v07 71, frus1894app2 49, frus1964-68v05 42, frus1958-60v01 39, frus1948v07 37, frus1969-76ve11p1 35, frus1961-63v22 34, frus1944v06 33, frus1958-60v15 31, frus1951-54Iran 31 (and Ed2 31, a duplicate), frus1943China 27, and so on. Titles come from manifest.json (`manifest_titles.tsv`).

**Headers.** `MATCH 'header:(corrupt* OR brib* OR graft OR embezzl* OR "illicit payment" OR "question payment" OR lockheed OR kickback*)'` (front matter excluded) returned 3 rows: frus1936v05/ch50, frus1958-60v01/ch1 and frus1958-60v03mSupp/d101, the last only through the surname "Briber". The editors carry no corruption chapter formula, so the subject lives in the document text, not in the headings.

## 2. Controls, and counts of the phrase families

All of the following use `COUNT(*), COUNT(DISTINCT c.volume_id) ... WHERE frus_documents MATCH '<m>' AND c.is_front_matter=0 AND c.is_editorial_note=0`. The first run did not drop Ed2.

| MATCH | docs | vols |
|---|---|---|
| "Department of State" (positive control) | 94,049 | 552 |
| ZZZ_IMPOSSIBLE_ZZZ (negative control) | 0 | 0 |
| "illicit payment" | 16 | 4 |
| "question payment" | 9 | 9 |
| "corrupt practic" | 83 | 60 |
| "foreign corrupt practic" | 4 | 2 |
| "tongsun park" | 4 | 2 |
| brib* | 673 | 282 |
| graft | 367 | 163 |
| embezzl* | 169 | 84 |
| kickback* | 18 | 17 |

The volume missing the positive control is frus1919Parisv05: `SELECT DISTINCT volume_id FROM document_cache EXCEPT SELECT DISTINCT c.volume_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH '"Department of State"';`. It holds Paris Peace Conference minutes, so the miss is genuine and does not break the scan.

Scandal searches, with Ed2 dropped:
`SELECT COUNT(*), COUNT(DISTINCT c.volume_id), MIN(date), MAX(date) ... MATCH '<m>' ... AND c.volume_id NOT IN (Ed2 pair)`

| MATCH | docs | vols | dates |
|---|---|---|---|
| koreagate | 3 | 2 | 1978-01-20 to 1978-04-18 |
| abscam | **0** | 0 | (relaxed form beside it: koreagate, 3) |
| "prince bernhard" AND lockheed | 1 | 1 | 1975-10-07 |
| tanaka AND lockheed | 5 | 3 | 1976-05-06 to 1983-04-19 |
| lockheed AND (brib* OR payoff* OR scandal OR "illicit payment") | 27 | 7 | 1974-12-16 to 1983-04-19 |
| northrop AND (brib* OR payment*) | 28 | 9 | 1964-09-22 to 1982-11-17 |
| "foreign corrupt practices act" | 4 | 2 | 1978-07-28 to 1980-07-29 |

Older vocabulary outside S:
`MATCH '(venal* OR peculat* OR nepot*) NOT (corrupt* OR brib* OR graft OR embezzl* OR kickback* OR "illicit payment")'` (non-apparatus, Ed2 dropped) returns **111 documents in 78 volumes, 15 of them dated before 1910**. S therefore under-reaches the contemporaries' vocabulary by about 111 documents. This was not folded into S.

## 3. Literal shares (two obligations per phrase count)

Script: `share.py LABEL MATCH STRICT TOLERANT`. It uses Python `re` with `re.I` (case-insensitive) for the whole family, over header + dateline + source_note + body_text concatenated and whitespace-collapsed, non-apparatus, Ed2 dropped, with hit lists sorted by (volume_id, document_id). A family under 300 hits is taken as a census; a larger one as an evenly spaced sample of 40. Outputs are in `share_<label>.json`. TOLERANT is published, STRICT beside it.

| family (MATCH) | M | mode | TOLERANT | STRICT |
|---|---|---|---|---|
| "illicit payment" | 16 | census | 16 of 16 | 0 of 16 (every hit is the plural "payments") |
| "corrupt practic" | 81 | census | 81 of 81 | 6 of 81 (strict `corrupt practice` misses "practices") |
| "foreign corrupt practic" | 4 | census | 4 of 4 | 4 of 4 |
| "tongsun park" | 4 | census | 4 of 4 | 4 of 4 |
| "question payment" | 9 | census | **1 of 9: unusable**; the misses are other words with the same stems ("question of payment" etc.) | 0 of 9 |
| corrupt* | 2,186 | sample 40 | 40 of 40 | 40 of 40 |
| brib* | 658 | sample 40 | 40 of 40 | 40 of 40 |
| graft | 363 | sample 40 | 40 of 40 | 35 of 40 |
| embezzl* | 169 | census | 169 of 169 | 169 of 169 |
| kickback* | 18 | census | 18 of 18 | 18 of 18 |

The regexes. TOLERANT: `\billicit[\s\-,().]+payments?\b`, `\bcorrupt\w*[\s\-,().]+practic\w*\b`, `\bforeign[\s\-,().]+corrupt\w*[\s\-,().]+practic\w*\b`, `\btong[\s\-]?sun[\s\-,().]+park\b`, `\bquestionabl\w*[\s\-,().]+payments?\b`, `\b(in)?corrupt\w*`, `\bbrib\w*`, `\bgraft(s|ed|ing)?\b`, `\bembezzl\w*`, `\bkick[\s\-]?backs?\b`. STRICT: the words separated by single spaces, with no inflection, e.g. `\billicit payment\b`.

The single-word 1.000 shares test the stemmer, not the referent, so the referent was tested separately (`coding_corrupt_referent.txt`). For **corrupt\***: 40 evenly spaced hits (`sample_ctx.py`, `s_corrupt.json`; this sample was drawn with Ed2 still in, M = 2,211) refer to official or political corruption or bribery in 38 of 40. The misses are frus1969-76v13/d147 (metaphorical) and frus1961-63v14/d10 (a loose epithet). The garbled-telegram sense appears in 0 of 40. For **graft**: 36 of 40 (`s_graft.json`, M = 367 with Ed2). The 4 horticultural misses are frus1863p2/d4, frus1887/d383, frus1919Parisv03/d5 and frus1950v04/d667.

**False-friend test** for the question's own term, corrupt*. The on-topic set is the 14 collection volumes (frus1943China, frus1947v07, frus1948v07, frus1950v06, frus1958-60v01, frus1964-68v05, frus1964-68v06, frus1969-76ve15p2, frus1969-76ve09p2, frus1969-76ve12, frus1969-76v31, frus1977-80v03, frus1977-80v13, frus1875v01).
`SELECT SUM(c.volume_id IN V), (SELECT COUNT(*) FROM document_cache WHERE volume_id IN V AND is_front_matter=0 AND is_editorial_note=0), COUNT(*), 311429 ... MATCH '<m>' ... Ed2 dropped`

- corrupt*: **273 of 6,830** in the on-topic volumes (4.0 per 100), against **2,186 of 311,429** corpus-wide (0.70 per 100). Ratio 5.7.
- Control "Department of State": **1,524 of 6,830** on-topic (22.3 per 100), against **93,824 of 311,429** corpus-wide (30.1 per 100). Ratio 0.74.

The term is concentrated far above baseline where the control is not, so it measures the question rather than the corpus. Caveat: the on-topic volumes were chosen partly by this term, so the test is weak by construction.

## 4. Decade shape (periodised on document_dates.date_iso, the index's form of frus:doc-dateTime-min; NOT the volume's series year)

```
WITH s AS (<scope set S>), base AS (SELECT substr(dd.date_iso,1,3)||'0s' dec, COUNT(*) n FROM document_cache c JOIN document_dates dd ON dd.volume_id=c.volume_id AND dd.document_id=c.document_id WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN (Ed2 pair) AND dd.date_iso IS NOT NULL GROUP BY 1),
hv AS (SELECT dec, s.v, COUNT(*) n FROM s JOIN document_dates dd ON both keys ... GROUP BY 1,2), h AS (SELECT dec, SUM(n) n, MAX(n) top FROM hv GROUP BY dec)
SELECT base.dec, base.n, h.n, round(1000.0*h.n/base.n,2), h.top, top volume ...
```

| decade | dated docs | S hits | per 1,000 | top volume (its hits; share of the decade's hits) |
|---|---|---|---|---|
| 1840s | 143 | 1 | 6.99 | frus1902app2 (1; 1 of 1) |
| 1850s | 158 | 1 | 6.33 | frus1894app2 (1; 1 of 1) |
| 1860s | 11,268 | 111 | 9.85 | frus1868p2 (18 of 111) |
| 1870s | 5,821 | 103 | 17.69 | frus1874 (11 of 103) |
| 1880s | 6,484 | 82 | 12.65 | frus1888p2 (14 of 82) |
| 1890s | 9,845 | 124 | 12.60 | frus1894app2 (46 of 124) |
| 1900s | 10,261 | 110 | 10.72 | frus1903 (16 of 110) |
| 1910s | 30,842 | 190 | 6.16 | frus1917 (17 of 190) |
| 1920s | 20,374 | 80 | 3.93 | frus1922v01 (8 of 80) |
| 1930s | 40,073 | 119 | 2.97 | frus1933v02 (11 of 119) |
| 1940s | 75,872 | 476 | 6.27 | frus1947v07 (71 of 476) |
| 1950s | 42,801 | 555 | 12.97 | frus1951-54Iran (31 of 555) |
| 1960s | 27,654 | 556 | 20.11 | frus1964-68v05 (42 of 556) |
| 1970s | 22,258 | 443 | 19.90 | frus1969-76ve11p1 (35 of 443) |
| 1980s | 6,038 | 106 | 17.56 | frus1981-88v05 (11 of 106) |
| 1990s | 177 | 0 | 0.00 | relaxed form beside it: the 1980s, 106 |

No decade before the 1840s has a hit, but each of those decades holds 1 to 102 dated documents, which is too thin to conclude anything. The rules' figure of 74,043 dated 1940s documents is the guide's measurement at its date. This session's base for the 1940s is 75,872, because the predicates differ (the guide's are unknown). The earlier corrupt*-only decade query (Ed2 not dropped) is in queries.log: 1960s 457 of 27,654 = 16.53 per 1,000; 1970s 358 of 22,640 = 15.81.

The 1890s rate is one volume's: frus1894app2 (the Hawaii papers) holds 46 of 124. The 1940s are dominated by China (frus1947v07, 71 of 476).

## 5. [TEI] spelling variants and the apparatus split

Script `tei_scan.py`, output `tei_scan.jsonl`, totals in `tei_summary.txt` (`tei_summary.py`). The **counting surface is tag-stripped, entity-unescaped and whitespace-collapsed TEI**, word-bounded case-insensitive regex, after removing `<teiHeader>`. The surfaces are DOC = `<body>` outside `<note>`, NOTE = `<note>` inside `<body>`, FRONT = `<front>`, BACK = `<back>`. All 553 files were scanned and the 2 Ed2 volumes dropped from the totals (551). Controls ran in the same pass: "department of state" was found in 551 of 551 volumes (DOC 86,240, NOTE 67,993, FRONT 23,322, BACK 626); zzz_impossible_zzz in 0.

| variant | DOC | NOTE | FRONT | BACK | lower / Capitalised / UPPER | volumes |
|---|---|---|---|---|---|---|
| corruption | 2,167 | 97 | 43 | 77 | 2,247 / 132 / 5 | 329 |
| corrupt | 918 | 23 | 18 | 5 | 941 / 21 / 2 | 293 |
| corrupted | 89 | 5 | 1 | 0 | 94 / 1 / 0 | 76 |
| corrupting | 47 | 1 | 3 | 0 | | 42 |
| corruptible (incl. in-) | 44 | 0 | 0 | 0 | | 36 |
| corruptions | 21 | 0 | 1 | 0 | | 12 |
| corruptly / corruptness / corruptionist(s) | 11 / 5 / 6 | 0 / 0 / 0 | 2 / 0 / 3 | 0 | | 12 / 5 / 7 |
| bribery | 376 | 19 | 14 | 20 | 389 / 39 / 1 | 165 |
| bribe | 199 | 8 | 7 | 1 | | 132 |
| bribes | 171 | 10 | 4 | 1 | | 101 |
| bribed | 86 | 6 | 1 | 0 | | 62 |
| bribing / briberies / briber(s) | 42 / 2 / 4 | 3 / 0 / 0 | 1 / 1 / 1 | 0 | | 34 / 3 / 2 |
| graft | 376 | 3 | 7 | 3 | | 139 |
| grafter(s) | 20 | 0 | 0 | 0 | | 16 |
| embezzl\* | 354 | 6 | 17 | 4 | | 88 |
| kickback(s), kick-back(s) | 27 | 0 | 0 | 0 | | 22 |
| payoff(s), pay-off(s) | 234 | 4 | 2 | 0 | | 105 (includes non-bribery senses; not used) |
| illicit payment(s) | 25 | 3 | 0 | 4 | 23 / 9 / 0 | 4 |
| questionable payment(s) | 1 | 0 | 0 | 0 | | 1 |
| improper payment(s) | 3 | 0 | 1 | 0 | | 3 |
| venal / venality | 176 | 3 | 0 | 0 | | 103 |
| peculation(s) | 34 | 0 | 1 | 0 | | 25 |
| nepotism | 51 | 1 | 0 | 0 | | 36 |
| squeeze | 623 | 22 | 0 | 4 | | 246 (mostly the economic sense; not used) |
| Koreagate | 5 | 1 | 0 | 3 | 0 / 9 / 0 | 2 |
| Foreign Corrupt Practices | 7 | 1 | 0 | 1 | 0 / 8 / 1 | 2 |

Reading: the corruption vocabulary sits almost wholly in document text, not in the editors' footnotes. Corruption has DOC 2,167 against NOTE 97, while for the positive control NOTE is 67,993 against DOC 86,240. So, unlike most term families, these densities are not inflated by editorial language. The UPPER split is small because the regex's case test classifies whole tokens; all-caps telegrams contribute little. Caveat: nested `<note>` and any notes outside `<body>` are not separated. "Department of State" appears in all 551 volumes here but in 552 of 553 in the index's MATCH; the TEI count includes FRONT, and frus1919Parisv05's hits are in apparatus.

## 6. Archival scope (labelled by channel; never summed)

**Came-from channel (document_sources) over S** (3,060 documents; 2,549 have a source row):
`WITH s AS (<S>) SELECT ds.citation_era, COUNT(*) FROM s JOIN document_sources ds ON ds.volume_id=s.v AND ds.document_id=s.d GROUP BY 1 ORDER BY 2 DESC;`
gives decimal 1,291; structured 645; lot_file 202; subject_numeric 181; cfpf 120; named_series 59; published 34; unrecognized 15; foreign 2. citation_era is a citation form, not a date.

Top non-decimal units: `... WHERE ds.citation_era<>'decimal' GROUP BY repository, record_group, lot_file_norm, series_name ORDER BY n DESC LIMIT 25`. The leading rows: CIA 117; Nixon Presidential Materials, NSC Files 95; Johnson Library NSF 77; Carter Library National Security Affairs 63; RG 59 Central Files 1970–73 43, 1967–69 40, 1964–66 23; Kennedy NSF 28; Eisenhower Whitman File 26; Ford National Security Adviser 26; Lot 54D270 17; CFPF 16; Lot 63D351 16; Lot 62D430 6; Lot 59D95 5.

**Came-from for the 21 collection documents:**
`SELECT ... FROM document_sources ds WHERE (ds.volume_id, ds.document_id) IN (VALUES <21 pairs>);`
- decimal RG 59: frus1943China/d202 (711.93), frus1947v07/d292 (893.00), frus1948v07/d506 (711.00), frus1950v06/d831 (896.00)
- lot_file 66D193: frus1958-60v01/d179
- CFPF: frus1969-76ve12/d222, d224, d227
- Records of Secretary of State Henry Kissinger, Box 24 (Entry 5403): frus1969-76ve15p2/d292, d293
- Lot 81D134: frus1977-80v03/d266
- Ford Library, National Security Adviser: frus1969-76ve12/d218, frus1969-76v31/d140
- Carter Library, National Security Affairs: frus1977-80v03/d310, frus1977-80v13/d84, d92, d94
- Library of Congress, Manuscript Division (Kissinger Papers): frus1969-76ve09p2/d155
- RG 330 (OSD files, FRC 330 73 A 1304): frus1964-68v06/d16
- unrecognized (Center for Military History, CORDS files): frus1964-68v05/d258
- no source row: frus1875v01/d199

**Pointed-at channel (external_citations) over S.** This channel has no row before 1910-12-06 (`SELECT MIN(dd.date_iso) FROM external_citations ec JOIN document_dates dd ON both keys;` returns 1910-12-06), stores only the citation fragment, and holds lot, library and decimal anchors only.
`WITH s AS (<S>) SELECT ec.anchor, COUNT(*), COUNT(DISTINCT ec.volume_id||'/'||ec.document_id) FROM s JOIN external_citations ec ON both keys GROUP BY 1;`
gives centralFileClass 448 rows from 257 documents; presidentialLibrary 176 from 124; lotFile 138 from 93.
Top non-decimal targets: Carter National Security Affairs 53 rows from 32 documents; Johnson NSF 28/22; Nixon NSC Files 27/21; Lot 66D95 17/15; Lot 63D351 12/9; Eisenhower Whitman 7/7; Lot 62D1 6/5; Lot 62D430 6/6; Lot 89D149 6/2.

**[JSON] resolution.** Script `resolve_lots.py`, reading central-files-index.json (generated 2026-09-10; `lotFiles` rows keyed `lotNumber`), series-facts-index.json (generated 2026-09-10; `byNaId` decoded through `legend`) and lot-claimants-index.json:

| lot | channel | RG / entry | NAID | title (creator) | dates | access |
|---|---|---|---|---|---|---|
| 66D193 | came-from | RG 59, A1 5155 | 2658382 | Subject Files Relating to Political, Military, Economic Aid, and Administrative Affairs (Bureau of Far Eastern Affairs) | 1955–1962 | Restricted, possibly |
| 81D134 | came-from | RG 59, UD-04D 21 & 22 | 26309177 | Subject Files of Richard N. Cooper (Office of the Under Secretary for Economic Affairs) | 1977–1980 | Restricted, fully; FOIA (b)(1), (b)(3). Lot-claimants: a second claimant, NAID 594320960 (Cooper chronological files, 1977) |
| 91D414 (Entry 5403) | came-from | RG 59, A1 5403 | 2131131 | Records of Henry Kissinger (Office of the Secretary) | 1973–1977 | Restricted, partly; FOIA (b)(1). FRUS cites "Entry 5403"; the lot comes from collection-authority aliases ("Records of Henry A. Kissinger, Entry 5403, Lot 91D414"). This is an inference |
| 63D351 | came-from (16) and pointed-at (12) | RG 59, A1 1586E | 2839192 | Records Relating to NSC Policy Papers (Executive Secretariat) | 1947–1979 | Restricted, partly |
| 66D95 | pointed-at | RG 59, A1 1586E | 2839192 (the same NAID as 63D351: the lots converge) | as above. Lot-claimants also lists NAID 2839193, Subject Files, 1947–1965 | | |
| 62D430 | came-from (6) and pointed-at (6) | RG 59, A1 1586C | 2839191 | Subject and Special Files (Executive Secretariat) | 1953–1961 | Restricted, partly. Lot-claimants: divided, including NAIDs 2386675 and 2839190 |
| 62D1 | pointed-at | RG 59, A1 1583E–F | 2838992 | Records Relating to Activities with the NSC (Policy Planning Council) | 1948–1961 | Restricted, partly. Lot-claimants: divided, including NAIDs 2198167 and 2838991 |
| 54D270, 59D95 | came-from | n/a | n/a | **not resolved**: no row in central-files-index.json | | |

Presidential library series, from presidential-library-catalog.json (generated 2026-08-06):
- Johnson Library NSF, NAID 567979; Asia and the Pacific Country Files 587358, 1963–1969.
- Ford Library NSC Europe, Canada, and Ocean Affairs Staff Files, 645650.
- Ford Library NSC International Economic Affairs Staff Files, 646663; Presidential Subject Files 646664, 1974–1976.
- Ford Library NSC East Asian and Pacific Affairs Staff Files, 593840.
- Carter Library: only the Brzezinski Collection, 1104, and the NSC Institutional Files, 623746, are catalogued. The cited "National Security Affairs, Staff Material, Far East, Oksenberg Subject File" has no catalogue row.

Central Decimal File and CFPF: collection-authority.json names them but carries no NAID, so none is reported.

**Decimal glosses (decimal-class-labels.json, gated by `coverage.glossableYears`).** The 1910–1949 schedule glosses: 711.93 as class 7 "Political Relations of States", United States with China (country 93 = China); 893.00 as "Internal Affairs of States", China, "Political affairs"; 711.00 as political relations, United States. The 1950–1959 schedule glosses 896.00 as class 8 "Internal Economic, Industrial and Social Affairs", Philippines. **751H.11 is not glossed.** The 1960–1963 schedule reads country 51h as Cambodia, which contradicts its document's subject (Diem). This is either a FRUS footnote typo or a schedule mismatch, and it is left unglossed.

**Pre-1940 archival reach.** In series-facts-index.json, **11 of 698** series rows have an inclusive start year before 1940 (a python count over `byNaId[*].y0`). This session re-derived the figure rather than relying on the guide's ratio. The 1875 document has no archival row in either channel; that is the offline stack's limit, not an archival absence.

**Shelves named without the bundle:** the Center for Legislative Archives (congressional investigations) and AAD for the CFPF are general knowledge and are not in the bundled JSON.

## 7. Reading accounting and quotations

**Reading.** `readdocs.py` ran:
`SELECT c.header, IFNULL(c.dateline,''), IFNULL(c.source_note,''), c.body_text, length(c.body_text), dd.date_iso FROM document_cache c LEFT JOIN document_dates dd ON dd.volume_id=c.volume_id AND dd.document_id=c.document_id WHERE c.volume_id=? AND c.document_id=?`
It wrote **30 documents whole** to `raw/`. For every one, the captured length equals length(body_text) in characters: 30 of 30 (check in queries.log). Most were read through keyword-context windows of ±200–300 characters around up to 4 matches. One, frus1964-68v05/d258 (5,862 characters), was printed and read in full. **Quoted: 20 quotations from 19 documents.**

**Verification.** `verify_quotes.py` runs `SELECT body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?` and tests each quotation as an exact substring. All 20 of 20 matched, exactly and whitespace-collapsed (`quote_verification.json`). `check_overview_quotes.py` then paired every straight-quoted span of 20 or more characters in overview.md against the 21 collection documents' body_text: 21 spans verified and 1 non-quote (the collection's title). It also tested all 20 collection excerpts against their own document (20 of 20 found), and the URL-cited pairs in the overview against the collection (21 cited, 0 missing).

| Q | pair | quotation (verbatim, source text) | note |
|---|---|---|---|
| Q1 | frus1943China/d202 | "Graft and bribery are commonplace." | |
| Q2 | frus1948v07/d506 | "the administrative inefficiency of the National Government and the extent to which incompetent and corrupt officials occupy high positions make extremely questionable its capacity to utilize effectively American aid in anything approaching all-out proportions" | |
| Q3 | frus1947v07/d292 | "would give us the strongest leverage in furnishing the desperately needed aid as at each stage there is evidence of progress or in stopping it whenever the forces of reaction or of corruption assert themselves" | |
| Q4 | frus1950v06/d831 | "the Philippine Government should institute a sweeping cleanup of the large number of corrupt and inefficient tax administrators and collectors" | the editors' parenthetical summary of 896.00/8–1050, not the telegram's text |
| Q5 | frus1958-60v01/d179 | "Diem knowingly tolerated corruption in his family and in high governmental circles though remaining personally free of such taint." | |
| Q6 | frus1964-68v05/d258 | "I agree that the level of corruption in Viet-Nam has reached a point where, as you point out, it has become a key obstacle to pacification." | |
| Q7 | frus1964-68v05/d258 | "The assumption of such sweeping prerogatives entails an invasion of the sovereignty …" (full text in quotes.json) | |
| Q8 | frus1964-68v06/d16 | "The Junior Officers of the Army are increasingly restive in that nothing has been done about corruption in the Armed Forces." | |
| Q9 | frus1969-76ve15p2/d292 | "Such payments coming when Strauss was Defense Minister paved the way for the sale of the Starfighter to the FRG." | |
| Q10 | frus1969-76ve15p2/d293 | "We must do everything possible to keep this quiet. If the CSU is destroyed in Germany it will really shake Germany and strengthen the left." | in the editors' source note, quoting an 8 October 1975 Ford–Kissinger conversation |
| Q11 | frus1969-76ve09p2/d155 | "full disclosure of Lockheed’s payments may prove far more damaging to Saudi-US relations" | |
| Q12 | frus1969-76ve12/d222 | "As you know, I have kept myself out of the Lockheed matter. … it is not a foreign policy matter." | |
| Q13 | frus1969-76ve12/d227 | "WE EXPECT THAT THE ARREST WILL ALSO SHARPLY REDUCE ANY LINGERING SUSPICION …" | |
| Q14 | frus1969-76v31/d140 | "Two governments are in political difficulty on this issue. It could help, but we shouldn’t browbeat." | |
| Q15 | frus1977-80v03/d310 | "Illicit payments is one area where we have done so." | |
| Q16 | frus1977-80v13/d84 | "Postponement of the first withdrawals—on grounds that … the Tongsun Park affair hangs over them—would remove a contentious issue from the Executive-Legislative agenda." | |
| Q17 | frus1977-80v13/d94 | "The issue is not the withdrawal but the Tongsun Park affair. Because of “Koreagate,” Congressmen fear …" | an adjacent sentence in the same document defining Koreagate is the editors' footnote and is not quoted |
| Q18 | frus1875v01/d199 | "The alleged corruption of the arbitral commission which awarded those claims is Blanco’s pretext for the proposed bad faith of his government." | |
| Q19 | frus1969-76ve12/d224 | "My mission is under no circumstances to ask for any renegotiation of the agreement on exchange of Lockheed information." | collection only |
| Q20 | frus1977-80v03/d266 | "Our proposal on illicit payments is another example." | the overview quotes the substring "proposal on illicit payments" |

The full texts of Q7, Q12, Q13, Q16 and Q17 are in `quotes.json`. The ellipses in this table shorten only this memo; the overview and the collection use the full, verified strings.

Collection: 21 documents and 20 excerpts. Every pair was checked against document_cache before the file was written: the `VALUES` query returned 21 of 21, all with is_front_matter=0 and is_editorial_note=0. No duplicate pair, and no Ed2 volume (frus1969-76ve15p2 is the first edition).

## VECTORS

VECTORS: none. The brief did not hand over the Appendix A artifacts, so no neighbour, near-duplicate or map operation was run, and no cited document was vector-reached in either the strict or the practical reading. The Ed2 duplicates were suppressed by id only.

## 8. Limits

- S misses the older vocabulary (venal, peculation, nepotism): 111 documents.
- "squeeze" and "payoff" are polysemous and were not used.
- The decade rates of the small 19th-century decades rest on single negotiations (frus1894app2).
- The collection is a reading of the top-ranked documents in five threads, not a census of the 3,060.
- Country reporting that calls a government corrupt (Latin America 1969–80, Iran, Korea 1961, Indochina 1952–54) was not read beyond samples.
- frus1977-80v18/d31 (Iran MAAG corruption, 1979) was read but not collected.

## TRACE TABLE (overview item, then memo line)

| overview item | memo source |
|---|---|
| "about 3,000 documents, roughly one in a hundred" | §1, S = 3,060 of 311,429 |
| 447 volumes; 553 volumes; Ed2 counted once | §0, §1 |
| 21 documents in the collection | §7, collection check |
| decimal file classes 711.93, 893.00, 711.00, 896.00 | §6, came-from for collection |
| Records of Henry Kissinger A1 5403, Lot 91D414, NAID 2131131, 1973–77, partly restricted (b)(1) | §6 table, row 91D414 |
| Cooper files UD-04D 21/22, Lot 81D134, NAID 26309177, 1977–80, fully restricted | §6 table |
| Lot 66D193, A1 5155, NAID 2658382, 1955–62 | §6 table |
| Ford NSC International Economic Affairs 646663, 1974–76 | §6 presidential list |
| Carter Oksenberg file not catalogued | §6 presidential list |
| decimal cited 448 times | §6 pointed-at, centralFileClass 448 |
| Lots 66D95/63D351, NAID 2839192, A1 1586E, 1947–79 | §6 table |
| Lot 62D430, NAID 2839191, A1 1586C, 1953–61 | §6 table |
| Lot 62D1, NAID 2838992, A1 1583E–F, 1948–61 | §6 table |
| Koreagate 3, Tongsun Park 4, Abscam 0 | §2 scandal table; §2 families |
| Lockheed with bribe/payoff/scandal/illicit payment: 27 documents in 7 volumes | §2 scandal table |
| Foreign Corrupt Practices Act 4 in 2 volumes, 1978–80; "corrupt practices" 81 | §2; §3 (81 with Ed2 dropped) |
| 13 volumes 1981–88, 1 for 1989–92; 177 documents dated in the 1990s, none hit | §0 late-era coverage; §4 |
| none before the 1840s; fewer than two hundred dated documents in those decades | §4 (sum of the pre-1840s base column, 182, from the corrupt*-only decade query in queries.log) |
| pointed-at begins December 1910 | §6 |
| controls: "Department of State" 552 of 553, exception Paris minutes; nonsense 0 | §2 controls |
| samples of 40: 38 for corrupt, 36 for graft | §3 referent |
| "about twenty in a thousand" in the 1960s/70s, "three in a thousand" in the 1930s | §4 (20.11, 19.90; 2.97) |
| "venal/peculation" etc. not in the overview's counts | §2, §8 |
| Q1 to Q18, Q20 in the overview | §7 table (Q19 is in the collection only) |
| Finding 1 quotations | Q1, Q3, Q2, Q4 |
| Finding 2 quotations | Q5, Q6 (substring), Q7, Q8 |
| Finding 3 quotations | Q9, Q10, Q11, Q12 (substring), Q13 (substring) |
| Finding 4 quotations | Q14, Q20 (substring), Q15 |
| Finding 5 quotations | Q16 (substring), Q17 |
| Finding 6 quotation | Q18 |
| P1's "incompetent and corrupt officials" and "whenever the forces of reaction or of corruption assert themselves" | substrings of Q2 and Q3 |
| P1's "illicit payment" | §1 S definition |
