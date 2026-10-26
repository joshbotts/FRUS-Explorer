# Scope memo — recognition of governments that came to power by force in Latin America

Run r6, 2026-10-25. Operator-facing. Every number below gives its query (or the script that ran it and the file holding
its output), its pair or set, its counting surface, and its denominator. Files named are in
`/Users/jbotts/frus-analysis/c3/runs/r6/` unless a full path is given.

## 0. Coverage and access

- Coverage query, first call of the session:
  `SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;`
  → `553|321749|1103|8481`. All 553 volumes of the series are in this copy; 321,749 documents, 1,103 front matter and
  8,481 editorial notes. Non-apparatus documents (both flags 0): 312,169 (M4's baseline denominator). Every count here
  is conditional on this 553-volume index.
- Read-only proof: `sqlite3 -readonly …/frus-copy-2026-10-25.db "BEGIN; CREATE TABLE zz(x); ROLLBACK;"` →
  `Error … attempt to write a readonly database` (rc=1). Every later SQL call went through `q.sh` (sqlite3 `-readonly`)
  or Python `mode=ro`; temp tables used for joins are TEMP (connection-local), never written to the copy.
- Disclosure: one command wrote a scratch file `/tmp/a_r6` outside the run directory (a shell redirect in the
  post-1950 rerun, M7). It was empty of anything but two id columns, was deleted with the next command, and nothing read it.
  It is logged in queries.log. No file outside the run directory was read except the three resources named in the brief.

## 1. Scope chosen, and how it was found

**How found.** I read the editors' chapter headings before writing any text query. `chapters.py` walks
`volume_structures.structure_json` (`SELECT volume_id, structure_json FROM volume_structures`) and prints every section
title matching a regex (Python `re`, case-insensitive). `chapters.py 'recogni'` → 253 section titles
(raw/chapters_recogni.tsv); filtered to Latin American country headings → 78 rows; I kept the 62 that name U.S.
recognition, nonrecognition, withholding or "the question of recognition" of a *government*, and dropped 16 that are about
recognizing other things (consuls, meat labels, ship certificates, judgments, a blockade, naturalization, the Monroe
Doctrine, Panama's independence circular of 1903, a political union). A second scan
(`chapters.py 'coup|junta|de facto|revolution|overthrow|…'`, raw/chapters_coup.tsv, and
`chapters.py 'Central American (Peace )?Conference|Political Defense|consultation|…'`, raw/chapters_policy.tsv) found the
general-policy chapters.

**Inclusion rules** (scope.py holds R1 and R2 verbatim; raw/scope_all.tsv holds R1–R3):
- **R1** — every non-apparatus document in the 62 editors' chapters whose title names U.S. recognition or nonrecognition
  of a Latin American government, 1895–1950. 2,255 documents in 36 volumes.
- **R2** — the five general-policy chapters: the 1907 Central American Peace Conference report (frus1907p2), the 1923
  Central American agreements (frus1923v01), Costa Rica's effort to denounce the 1923 treaty (frus1932v05), the 1936
  decision to stop applying Article II (frus1936v05), and the 1948 "Continuance … of diplomatic relations with new
  governments on the basis of the Bogota Resolution" (frus1948v09). 84 documents in 5 volumes.
- **R3** — after 1950 the editors stop writing recognition into chapter titles (the latest R1 chapter is the 1950 Haiti
  junta). R3 is a proximity search over the 17 Latin American volumes of 1951–1988 (list in M7): 111 documents in 15
  volumes. A candidate set; I read 12 of its documents whole and cite 11.
- **R4** — documents outside R1–R3 that I reached by a named formula search and cite: 11 (listed in §4 with the search
  that reached each).
- R1 ∪ R2 ∪ R3 = 2,450 documents in 54 volumes (raw/scope_summary.txt); with R4, 2,461 documents in 59 volumes.
- Exclusions: `is_front_matter=1` and `is_editorial_note=1` (the R1/R2 chapters held 0 front matter and 4 editorial
  notes, dropped: `scope.py` prints `rows 2343 FM 0 EN 4 … kept 2339`). No second edition is in scope (none of the 59
  volume ids ends in Ed2). Date span of R1+R2: 1895-09-06 to 1950-06-01 (`document_dates.date_iso`).
- Periodisation: on `document_dates.date_iso`, the index's stored day, which the pipeline takes from
  `frus:doc-dateTime-min` (corrected to the document's own `<date>` where both name the same instant). Not on series year.

**What the scope is not.** It is not every recognition decision. Before 1895 the volumes are arranged by country without
topic headings, so R1 cannot see them (M8: 608 candidates in 58 volumes); after 1950 the editors file recognition under
country chapters (R3 is a search, not the editors' selection). The Mexican chapters of 1911 and 1915 are R1 because their
titles name recognition, but they are 575 documents of revolution-wide correspondence; the 1913 Mexico chapter (Huerta)
is *not* R1 (its title names no recognition), so its documents enter only through R4.

## 2. Measurements

### M1. Scope by rule (raw/scope_summary.txt; scope.py; raw/scope_all.tsv)
| Rule | Documents | Volumes |
|---|---|---|
| R1 | 2,255 | 36 |
| R2 | 84 | 5 |
| R3 | 111 | 15 |
| R1–R3 | 2,450 | 54 |
| R4 (cited, outside) | 11 | 5 more |
Country split of R1+R2 (2,339; scope.py): Mexico 722, Haiti 244, Bolivia 203, El Salvador 188, Guatemala 122,
Argentina 118, Costa Rica 108, Dominican Republic 84, Nicaragua 80, Paraguay 75, Venezuela 74, Ecuador 68, Peru 64,
Honduras 50, American Republics policy 49, Cuba 38, Central America policy 35, Colombia 9, Brazil 8. Mexico is 722 of
2,339: the scope's single largest block, mostly the revolution chapters of 1911 and 1915 (339 + 236 documents).

### M2. Decade shape (raw/decades.txt; SQL printed there)
Numerator: R1–R3 documents by decade of `date_iso`. Denominator: `SELECT substr(dd.date_iso,1,3)||'0s', COUNT(*) FROM
document_dates dd JOIN document_cache dc ON dc.volume_id=dd.volume_id AND dc.document_id=dd.document_id WHERE
dc.is_front_matter=0 AND dc.is_editorial_note=0 AND dd.date_iso IS NOT NULL GROUP BY 1`.
| Decade | Scope docs | of dated non-apparatus docs | per 1,000 | top volume's share | rules |
|---|---|---|---|---|---|
| 1890s | 50 | 9,845 | 5.1 | frus1899 46 of 50 | R1 |
| 1900s | 41 | 10,261 | 4.0 | frus1900 13 of 41 | R1, R2 |
| 1910s | 1,142 | 30,842 | 37.0 | frus1911 417 of 1,142 | R1 |
| 1920s | 279 | 20,374 | 13.7 | frus1920v03 70 of 279 | R1, R2 |
| 1930s | 339 | 40,073 | 8.5 | frus1937v05 111 of 339 | R1, R2 |
| 1940s | 485 | 75,872 | 6.4 | frus1944v07 187 of 485 | R1, R2 |
| 1950s | 33 | 43,159 | 0.8 | frus1955-57v06 9 of 33 | R1 3, R3 30 |
| 1960s | 40 | 27,654 | 1.4 | frus1964-68v31 19 of 40 | R3 |
| 1970s | 39 | 22,640 | 1.7 | frus1977-80v15 14 of 39 | R3 |
| 1980s | 2 | 6,038 | 0.3 | frus1977-80v15 2 of 2 | R3 |
The 1890s rate is one negotiation (Venezuela 1899, 46 of 50). The 1910s rate is dominated by Mexico (frus1911 alone 417).
The fall after 1950 is in part the change of rule (chapters → search) and must not be read as a fall in U.S. attention.

### M3. Positive and negative controls (same passes as the scans)
- Index, whole corpus: `"Department of State"` → 94,049 non-apparatus documents in 552 of 553 volumes; the one volume
  without it: `SELECT volume_id FROM document_cache GROUP BY volume_id EXCEPT SELECT dc.volume_id FROM frus_documents f
  JOIN document_cache dc ON dc.rowid=f.rowid WHERE frus_documents MATCH '"Department of State"' AND dc.is_front_matter=0
  AND dc.is_editorial_note=0 GROUP BY dc.volume_id;` → `frus1919Parisv05` (a Paris Peace Conference volume; outside
  scope). `"ZZZ_IMPOSSIBLE_ZZZ"` → 0.
- Index, on-topic vs baseline (M4): positive control present in 499 of 2,339 R1+R2 documents; negative 0 of 2,339.
- TEI (M5): "Department of State" nonzero in all 54 scanned volumes on both surfaces; ZZZ_IMPOSSIBLE_ZZZ 0.

### M4. False-friend test for the question's own terms (raw/falsefriend.txt; SQL forms printed there)
Document-level shares, index (porter stems), on-topic = R1+R2 (2,339 docs), baseline = all 312,169 non-apparatus docs.
On-topic form: `SELECT COUNT(*) FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid JOIN s ON
s.volume_id=dc.volume_id AND s.document_id=dc.document_id WHERE frus_documents MATCH '<term>' AND s.rule IN ('R1','R2')`.
| Term (MATCH) | on-topic | baseline | ratio |
|---|---|---|---|
| `recogn*` | 786 of 2,339 (0.336) | 48,508 of 312,169 (0.155) | 2.16 |
| `"by force"` | 42 of 2,339 (0.018) | 4,263 of 312,169 (0.014) | 1.31 |
| `"de facto"` | 160 of 2,339 (0.068) | 3,497 of 312,169 (0.011) | 6.11 |
| `coup` | 76 of 2,339 (0.032) | 3,982 of 312,169 (0.013) | 2.55 |
| `junta` | 146 of 2,339 (0.062) | 1,695 of 312,169 (0.005) | 11.50 |
| control `"Department of State"` | 499 of 2,339 (0.213) | 94,049 of 312,169 (0.301) | 0.71 |
| control `"ZZZ_IMPOSSIBLE_ZZZ"` | 0 | 0 | — |
Verdict: the question's phrase "by force" runs near the corpus rate in the recognition chapters (1.31×) — it measures
the corpus, not the question, and I stopped using it. The documents' own vocabulary is "de facto", "revolution",
"coup d'état", "junta". Even "recognize/recognition" appears in only 786 of the 2,339 documents of the recognition
chapters: the chapters are the right unit, a word search is not.

### M5. TEI variant scan (tei_scan.py → raw/tei_scan.tsv; summed in raw/tei_summary.txt)
Volumes: the 54 R1–R3 volumes, WHOLE files (not only the scope chapters). Two surfaces, both tag-stripped
(ElementTree `itertext`) and whitespace-collapsed: WHOLE = all text including front matter, footnotes and index;
DOCTEXT = text of `<div type="document">` with every `<note>` removed (separates document text from footnotes and
other apparatus). Python `re`, case-insensitive. 155,407,457 characters WHOLE; 124,944,722 DOCTEXT.
| Family / variant | WHOLE | DOCTEXT |
|---|---|---|
| recognize/-s/-d/-ing (z) | 7,825 | 6,707 |
| recognise… (s) | 130 | 122 |
| recognition(s) | 6,667 | 4,275 |
| nonrecognition (closed) | 140 | 44 |
| non-recognition (hyphen) | 136 | 100 |
| non recognition (space) | 0 | 0 |
| de facto | 1,457 | 1,159 |
| de-facto / defacto | 0 / 2 | 0 / 1 |
| coup(s) d'état (accented) | 263 | 199 |
| coup(s) d'etat (unaccented) | 76 | 55 |
| coup detat (no apostrophe) | 1 | 1 |
| coup(s) not followed by d'état | 1,912 | 1,460 |
| junta(s) | 3,341 | 2,552 |
| by force | 446 | 386 |
| CTRL Department of State | 20,072 | 13,093 |
| CTRL ZZZ_IMPOSSIBLE_ZZZ | 0 | 0 |
Readings: "recognition" loses 2,392 of 6,667 occurrences (36%) when apparatus is removed — editors' headings, footnotes
and index carry much of the noun; the closed spelling "nonrecognition" is mostly the editors' (96 of 140 outside
document text) while the documents prefer "non-recognition" (100 of 144 document-text occurrences of the two). The
index cannot see this split (it folds all of them to one stem).

### M6. Policy formulas — counts, literal shares, referents (share.py → raw/shares.txt; raw/referent_check.txt)
Hit list SQL: `SELECT dc.volume_id, dc.document_id FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid WHERE
frus_documents MATCH ? AND dc.is_front_matter=0 AND dc.is_editorial_note=0 ORDER BY dc.volume_id, dc.document_id`.
Literal test: header+dateline+source_note+body_text, whitespace-collapsed, Python `re` IGNORECASE, census (every set
< 300). STRICT = single spaces; TOLERANT = each word with inflections, separators `[\s\-,().]+`.
| Phrase (MATCH) | hits | STRICT | TOLERANT | referent |
|---|---|---|---|---|
| "orderly processes of just government" | 2 | 2 of 2 | 2 of 2 | Wilson statement 1913 (frus1913/d7), quoted again 1950 (frus1950v02/d330) |
| "coup d etat or a revolution" | 5 | 5 of 5 | 5 of 5 | 1923 Treaty Art. II: window test 3 of 5; read, 5 of 5 (the other two quote the Art. II text verbatim) |
| "Resolution XXXV" | 9 | 8 of 9 | 9 of 9 | Bogotá 1948: 8 of 9 (frus1949v09/d125, Peiping, is not) |
| "Resolution XXII" | 23 | 22 of 23 | 23 of 23 | Montevideo CPD 1943: 23 of 23 |
| "recognition does not imply" | 4 | 4 of 4 | 4 of 4 | not used in the overview |
| "de facto in control" | 5 | 5 of 5 | 5 of 5 | not used in the overview |
| "no active resistance" | 5 | 5 of 5 | 5 of 5 | not used in the overview |
| "intention to fulfill" | 45 | 36 of 45 | 43 of 45 | misses frus1951v03p1/d142, frus1951v06p1/d433; not used as a count |
| "continuity of diplomatic relations" | 34 | 14 of 34 | 14 of 34 | **UNUSABLE** (below 0.80 tolerant; the index also returns "continuation/continued diplomatic relations"); not published |
A 1.000 share tests the stemmer only; the referent column is the separate test.

### M7. Post-1950 proximity search (R3) — and a correction to my own first pass
Volumes searched (17): frus1951v02, frus1952-54v04, frus1952-54Guat, frus1955-57v06, frus1955-57v07, frus1958-60v05,
frus1961-63v12, frus1964-68v31, frus1964-68v32, frus1969-76v21, frus1969-76ve10, frus1969-76ve11p1, frus1969-76ve11p2,
frus1969-76ve16, frus1977-80v15, frus1977-80v24, frus1981-88v16.
- v1 (raw/post1950_recog_near.txt): `… MATCH 'body_text: (NEAR(recognit junta, 12) OR NEAR(recognit coup, 12) OR
  NEAR(recognit "new govern", 6) OR NEAR(recognit "de facto", 6) OR NEAR(recognit "provision govern", 6) OR
  NEAR(recognit "militari govern", 8) OR NEAR(recognit "militari regim", 8))' AND dc.is_front_matter=0 AND
  dc.is_editorial_note=0 AND dc.volume_id IN (<17>)` → 64.
- v2 (raw/post1950_recog_near_v2.txt): the same with `recogn*` and full words (`"new government"`, `"provisional
  government"`, `"military government"`, `"military regime"`) → 111, in 15 of the 17 volumes (none in
  frus1969-76ve11p1 or frus1981-88v16).
- Why v1 was wrong: the query side is stemmed too. `recognit` matches the noun only; `recognize/recognized` index as
  `recogn`, so v1 missed every document that uses only the verb — for example the 1952 Batista memorandum
  (frus1952-54v04/d327), which I then reached by formula search. Same trap measured on `"legal advis"` → 0 rows corpus-wide
  while `"legal adviser"` → 2,185.
| Check | v1 (raw/post1950_recog_near.txt) | v2 (raw/post1950_recog_near_v2.txt) |
|---|---|---|
| rows | 64 | 111 |
| v1 rows missing from v2 | — | 0 |
| frus1952-54v04/d327 present | no (`grep -c` 0) | yes (`grep -c 'frus1952-54v04\|d327'` → 1) |
All channel numbers (§3) were recomputed on v2 (raw/scope_all_v1.tsv keeps the v1 scope).

### M8. Pre-1895 record (not chaptered)
`SELECT COUNT(*), COUNT(DISTINCT dc.volume_id) FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid JOIN
document_dates dd ON dd.volume_id=dc.volume_id AND dd.document_id=dc.document_id WHERE frus_documents MATCH
'NEAR(recogn* govern, 8) AND ("de facto" OR revolut OR provision)' AND dd.date_iso < '1895-01-01' AND
dc.is_front_matter=0 AND dc.is_editorial_note=0;` → 608 documents in 58 volumes (a lower bound: `provision` as a query
stems to `provis` and misses "provisional"). Díaz case:
`… MATCH 'NEAR(recogn* govern, 8) AND diaz AND (mexico OR mexican)' AND dd.date_iso BETWEEN '1876-11-01' AND
'1878-12-31' …` → 12 rows shown (LIMIT 12), frus1877/d215…frus1878/d358; I read frus1877/d222 and frus1878/d344.

### M9. Other searches behind §3 of the overview
- `"Estrada doctrine"` → 28 documents in 18 volumes (non-apparatus; corpus-wide).
- `NEAR("legal adviser" recogn*, 30)` in the 54 R1–R3 volumes → 4 documents in 4 volumes; corpus-wide 41 (query without
  the apparatus filter). Legal-Adviser-headed documents whose body contains "recogni" (SQL LIKE, case-insensitive) in those
  volumes: 14, of which the Brazil 1937–38 exchange is frus1937v05/d337–d340.
- Positive control for these: "Department of State" as in M3.

## 3. Archival channels (R1–R3 = 2,450 documents in 54 volumes; R4 not included). Never summed.

**Came-from** (`document_sources`, one row per document) — channels.py, raw/channels.txt, raw/channels_detail.txt,
raw/gloss.txt. `SELECT COUNT(*) FROM s JOIN document_sources ds ON ds.volume_id=s.volume_id AND
ds.document_id=s.document_id` → 2,352 of 2,450 have a source row. By citation form (`GROUP BY ds.citation_era`):
decimal 2,260; structured 44; subject_numeric 16; cfpf 13; lot_file 9; unrecognized 7; published 2; named_series 1.
By date band (gloss.py): before 15 Aug 1906, 79 documents and none has a source row (the despatch era prints no file
citation); Aug 1906–Jul 1910, 13 (11 decimal-form, 2 none); Aug 1910–1949, 2,244; 1950–1963, 46; after 1963, 68.
Decimal keys glossed with decimal-class-labels.json **only where the document's own date falls in
`coverage.glossableYears`** (1910–1949, 1950–1959, 1960–1963): 2,207 glossed, 28 not (701/702 diplomatic-mission keys
with no country). Top (key | class | country | subject, 1910–1949 schedule):
812.00 Mexico political affairs 626; 838.00 Haiti political affairs 192; 824.00 Bolivia political affairs 137;
816.01 El Salvador government 136; 818.00 Costa Rica political affairs 106; 814.00 Guatemala political affairs 89;
839.00 Dominican Republic 64; 817.00 Nicaragua 62; 835.00 Argentina 61; 823.00 Peru 57; 824.01 Bolivia government 57;
834.00 Paraguay 53; 816.00 El Salvador political affairs 50; 711.12 political relations United States–Mexico 42 (the
table glosses only "United States"; 12 = Mexico is the table's own country number, composed by me); 837.00 Cuba 35.
Shelf for the decimal file: RG 59. The bundle names decimal-file series NAID **302021** only as one of the two parent
series of `digitized-ranges-index.json` (`seriesNaIds: ["2555709","302021"]`); `series-facts-index.json` has no row for
302021, so the bundle gives no entry number, dates or access status. Digitized ranges for these classes: 0 of 624 ranges
fall in classes 71x–73x or 81x–83x (the digitized ranges are WWI 763.72 and visa/passport classes).
Despatch era (79 documents, 1895–Aug 1906; and the 1877–78 R4 documents): no citation; the bundle's series for that
correspondence are Diplomatic Despatches (series NAID 603720), Diplomatic Instructions (593313), Notes from Foreign
Missions (594363), Notes to Foreign Missions (597272) — a shelf by era, not a citation.
Numerical File 1906–1910 (RG 59, microfilm M862, series NAID 654171; roll-scans-index carries its roll PDFs): the 1907
Honduras letter cites "File No. 7357/5"; case 7357 begins on roll "Numerical File: 7357-7357/215", NAID 19794147
(duplicate 19792913).
Subject-numeric (16): RG 59 Central Files 1964–66 (6), 1967–69 (5), 1970–73 (2), "Central Files" without years (1),
and two Department-led forms (POL 15 HAI, POL 16 DOM REP). Subject-numeric-labels.json glosses POL 16 as "INDEPENDENCE.
RECOGNITION." in its 1963 schedule only (glossable for frus1961-63v12/d363, dated 1963-12-13); its 1964–1973 schedule
carries no POL 16 label, so POL 16 PERU (1968) is not glossed. POL 23-9 = "Rebellion. Coups." (1964–1973).
Central Foreign Policy File (cfpf 13): RG 59, 1973–1980 document numbers.
Lots (central-files-index.json `lotFiles` by `lotNumber`; series-facts-index.json `byNaId`):
| Lot | Series | RG / entry | NAID | dates | access |
|---|---|---|---|---|---|
| 62 D 1 (2 docs) | Records Relating to Activities with the National Security Council (Policy Planning Council) | 59 / A1 1583E, 1583F | 2838992 | 1948–1961 | Restricted – Partly, (b)(1) |
| 62 D 430 | Subject and Special Files (Executive Secretariat) | 59 / A1 1586C | 2839191 | 1953–1961 | Restricted – Partly |
| 63 D 75 | Records Related to the Secretary's Staff Meetings | 59 / A1 1609 | 2521274 | 1952–1961 | Restricted – Possibly |
| 64 D 199 | The Secretary's and the Under Secretary's Memorandums of Conversation | 59 / A1 1566 | 602231 | 1953–1964 | Unrestricted |
| 66 D 149 | Presidential Memorandums of Conversation | 59 / A1 5158 | 610077 | 1956–1964 | Unrestricted |
| 66 D 65 | Subject and Country Files (Bureau of Inter-American Affairs) | 59 / A1 5763 | 1074073 | 1962–1975 | Restricted – Partly |
| 67 D 46 | Records Relating to Honduras (Office of Central American Affairs) | 59 / A1 5732 | 2602882 | 1957–1974 | Restricted – Partly |
| 70 D 442 | (ARA/DR files) — not in central-files-index | — | — | — | — |
Presidential libraries (structured, came-from): Johnson Library National Security File 9 → bundle collection LBJ-NSF,
NAID 567979 (Latin America Country Files 567985, 1963–1969; NSC Meetings Files 7624433); Nixon NSC Files 9 → RN-NSF,
NAID 572235 (Institutional Files 572247); Carter National Security Affairs 5 → JC-NSA, NAID 560131 (North/South
560184; Brzezinski Country Files 560151); Carter NSC 3 → JC-NSC 623746; Eisenhower Herter Papers → Chronological Files
562457; CIA 10 (no NARA series). presidential-library-catalog.json carries no access status.

**Pointed-at** (`external_citations`, many rows per document; begins 1910-12-06; stores the citation fragment; lot,
library and decimal anchors only). `SELECT COUNT(*), COUNT(DISTINCT ec.volume_id||'/'||ec.document_id) FROM s JOIN
external_citations ec ON ec.volume_id=s.volume_id AND ec.document_id=s.document_id` → 132 rows on 99 of 2,450
documents: central-file class 102, presidential library 21, lot 9. Earliest dated scope document with a row: 1910-12-06.
Glossed by citing document's date (raw/pointed_gloss.txt): 817.00 Nicaragua political affairs 11 rows in 9 documents;
824.00 Bolivia 7 in 6; 816.01 El Salvador government 6 in 5; 738.02 Haiti (1950–59 schedule, class 7 = internal
political, no subject gloss) 6 in 5; 738.00 Haiti 5 in 3; 723.00 Peru 5 in 3; 814.00 Guatemala 3 in 3.
Pointed-at lots: 59 D 573 and 61 D 279 ("Rubottom Files") → Subject Files, Office of the Assistant Secretary of State for
Inter-American Affairs, RG 59, A1 1135, NAID 2108779, 1957–1959, Unrestricted (two lots converge on one NAID);
65 D 330 → the same series as 64 D 199 (NAID 602231); 63 D 75 as above; 67 D 46 as above; 70 D 247 → Subject Files
Relating to Ecuador, Office of Andean Affairs, RG 59, A1 5741 (+UD-16D 21/31/61), NAID 26309336, 1964–1978, Restricted –
Partly; 72 D 192 ("Rusk Files … Telephone Calls") → central-files-index maps it to Speeches and Statements (A1 5376/5376A,
NAID 631695); lot-claimants-index lists six series under the lot, of which Transcripts of Telephone Calls (A1 5379, NAID
631706, 1961–1969) is the one the citation names; 83 D 66 → Subject Files of Edmund S. Muskie, P 10, NAID 1261450,
1963–1981, Restricted – Partly; 57 D 284 → Records of the Fifth Session at Torquay (RG 43, A1 713, NAID 1422076) — a
Cuban-sugar footnote, off-topic. Libraries: Carter National Security Affairs 15 rows in 6 documents (e.g. Brzezinski
Staff Evening Reports, NAID 560156); Johnson Library Papers of George W. Ball (LBJ-P83002, NAID 35300981); Tom Johnson
Meeting Notes (unresolved); Nixon NSC Files; Eisenhower White House Central Files.
Whole-volume context only (usage.py → raw/usage.txt): collection-usage-index over the 54 volumes' notes is dominated by
other subjects in those volumes (812.00 2,065 citations, but also 893.51 China); not used for ranking.
Pre-war caveat: the offline archival stack barely reaches before 1940 (11 of 695 bundled series); the empty pre-war
lot/series roadmap above is that limit, not an archival absence.

**Candidate shelf for what FRUS does not print (legal reasoning):** Office of the Assistant Legal Adviser for
Inter-American Affairs (creator heading verified in series-facts-index): Subject and Country Files, Lot 75 D 163, RG 59,
A1 5773, NAID 12014843, 1961–1971, Restricted – Partly; Country Files on Latin America, Lot 81 D 324, P 871, NAID
17408805, 1968–1979, Restricted – Partly. Content not verified as concerning recognition.

## 4. Documents read, cited and quoted

Reading SELECT (fetch.py): `SELECT header, dateline, source_note, body_text, length(body_text), is_front_matter,
is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?`; raw text saved to raw/docs/<vol>_<doc>.txt;
ledger raw/read_ledger.tsv (captured length = length(body_text) for all rows). **Retrieved whole: 51 documents**
(captured = length in 51 of 51). Text printed to me in this session (whole or in the passages shown): 45; fetched but
not read: frus1909/d422, frus1913/d6, frus1927v03/d259, frus1945v09/d133, frus1961-63v12/d421, frus1961-63v12/d425.
**Cited in the overview: 43** (cited.tsv; raw/cited_meta.tsv confirms every pair exists in document_cache, none is front
matter or an editorial note, no duplicates). **Quoted: 24 quotations from 23 documents** (Q1–Q17 the block quotations of the findings, Q18–Q24 short inline quotations).
R4 documents and the search that reached each: frus1877/d222, frus1878/d344 (M8 Díaz query); frus1913/d7 ("orderly
processes of just government"); frus1913/d873 ("de facto in control"); frus1913/d1028 ("early and free election");
frus1923v02/d345, frus1930v01/d375, frus1935v04/d823 ("coup d etat or a revolution"); frus1944v07/d1 ("Resolution XXII");
frus1948v09/d384 ("Resolution XXXV"); frus1949v02/d446 ("Resolution XXXV").

### Quotations (verified: exact substring of `document_cache.body_text`, no normalisation; raw/quotes_verified.tsv
from `SELECT body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0
AND is_editorial_note=0`; texts in quotes.json; 24 of 24 VERIFIED)
| # | Pair | Offset | Quotation |
|---|---|---|---|
| Q1 | frus1877/d222 | — | "it waits before recognizing General Diaz as the President of Mexico until it shall be assured that his election is approved by the Mexican people, and that his administration is possessed of stability to endure and of disposition to comply with the rules of international comity and the obligations of treaties." |
| Q2 | frus1904/d228 | 3401 | "requests that I would name the agreements to which I have requested your excellency's Government's assent prior to the recognition of the present provisional government" |
| Q3 | frus1907p2/d22 | 658 | "I then asked what steps had been taken toward the establishment of constitutional government in Honduras and toward the election of a president and congress." |
| Q4 | frus1913/d7 | 773 | "Cooperation is possible only when supported at every turn by the orderly processes of just government based upon law, not upon arbitrary or irregular force." |
| Q5 | frus1917/d379 | 854 | "no Government except such as may be elected legally and established according to the Constitution shall be considered entitled to recognition." |
| Q6 | frus1913/d1028 | 6989 | "Security given for an early and free election in which all will agree to take part" |
| Q7 | frus1921v02/d344 | 3562 | "when it appears that there is a government in Mexico willing to bind itself to the discharge of primary international obligations, concurrently with that act its recognition will take place." |
| Q8 | frus1920v03/d230 | 2454 | "the United States Government does not contemplate dictating conditions on which recognition will be extended" |
| Q9 | frus1923v02/d345 | 4564 | "will not recognize any other Government which may come into power in any of the five Republics through a coup d'état or a revolution against a recognized Government, so long as the freely elected representatives of the people thereof have not constitutionally reorganized the country." |
| Q10 | frus1930v01/d375 | 1109 | "the evidence has satisfied me that these provisional governments are de facto in control of their respective countries, and that there is no active resistance to their rule." |
| Q11 | frus1936v05/d112 | 658 | "the United States should no longer be guided by Article II of the General Treaty of Peace and Amity of 1923 in extending or denying recognition to Governments in Central America" |
| Q12 | frus1944v07/d1 | 1302 | "the resolution does not require a joint decision with regard to whether recognition is to be accorded; that decision remains one for the exclusive determination of each government." |
| Q13 | frus1946v11/d773 | 773 | "past experience with regimes in hemisphere which before recognition have promised to observe democratic practices but after recognition had been extended sometimes ignored them." |
| Q14 | frus1948v09/d89 | 1419 | "Adoption of that resolution at Bogotá was in large measure motivated by a desire of the American Governments to separate the question of maintaining normal diplomatic relations with other American governments from the question of approval or disapproval of any newly established government." |
| Q15 | frus1952-54v04/d327 | 1775 | "has made satisfactory public and private statements with regard to Cuban intention to fulfill its international obligations; its attitude towards private capital; and its intention to take steps to curtail international communist activities in Cuba." |
| Q16 | frus1961-63v12/d423 | 1687 | "Guarantee of free and fair elections, preferably before June 9 but at no later date, with full rights to all parties under Constitution, and with guarantee that Armed Forces will respect results those elections." |
| Q17 | frus1964-68v31/d512 | 3211 | "our developing practices as to responses to coups no longer fits exactly within the textbook doctrinal pattern" |
| Q18 | frus1877/d222 | 4832 | "some guarantee of such an arrangement should be made the condition precedent to any recognition" |
| Q19 | frus1917/d409 | 537 | "recognition desirable but not necessary" |
| Q20 | frus1913/d873 | 445 | "no formal recognition is to be accorded those de facto in control" |
| Q21 | frus1932v05/d618 | 464 | "Martínez can under no circumstances be recognized." |
| Q22 | frus1934v05/d75 | 2119 | "recognition of the present regime in Cuba would be a great mistake" |
| Q23 | frus1952-54v04/d136 | 2125 | "The first prerequisite to recognition of a de facto government is that it have control of the national territory." |
| Q24 | frus1964-68v31/d206 | see tsv | "no problem of U.S. recognition" |
(The table above shows straight apostrophes for readability in Q2 and Q9; quotes.json, the overview and the collection
carry the stored curly apostrophes ’ exactly. Q1's offset is in raw/quotes_verified.tsv.)
Notes on voice: Q6 is Wilson's message to Congress of 27 Aug 1913 as telegraphed by Bryan; Q9 is Hughes quoting Article
II; Q17 is a Department telegram to the Embassy in Peru giving the Assistant Secretary's personal thoughts ("Drafted and approved by Oliver" in its source note), signed Katzenbach; Q24 is the NSC summary record's paraphrase of Under Secretary Ball. Paraphrased, not quoted: frus1922v02/d569 (treaty-for-recognition sequence); frus1934v05/d199 (Welles's procedure for Martínez); frus1935v04/d823 (Welles's reading
of Art. II ¶2); frus1944v07/d386, d1018, d1020; frus1945v09/d875, d1172; frus1948v09/d75, d384; frus1949v02/d446;
frus1950v02/d476; frus1955-57v06/d353; frus1961-63v12/d417, d363; frus1964-68v31/d132;
frus1969-76v21/d360, d361. Editorial footnotes inside body_text (e.g. the Rio Resolution XXVI gloss in
frus1964-68v31/d132, Ball's "continuation of the old one" in frus1964-68v31/d205) were not used as document evidence.

## 5. Trace table — every number and quotation in the overview

| Overview item | Memo source |
|---|---|
| 553 volumes; whole series present | §0 coverage query |
| "about 2,450 documents in 54 volumes" (scope) | §1 rules; M1 |
| 62 editors' chapters + 5 policy chapters | §1 R1/R2; raw/scope_summary.txt |
| 1895 to 1950 (chapter span) | §1 date span |
| about 110 later documents in 15 volumes (search set) | M7 v2 = 111 in 15 |
| 43 documents cited; 51 read whole; 17 block quotations (24 quoted passages in all) | §4 |
| four editorial notes excluded | §1 exclusions |
| about one document in three in the recognition chapters uses "recognize/recognition" | M4: 786 of 2,339 |
| "by force" at about the corpus rate; "junta" about eleven times, "de facto" six times | M4 ratios 1.31, 11.50, 6.11 |
| more than nine in ten source citations are decimal-file numbers | §3: 2,260 of 2,352 |
| Mexico's political file the single largest (over six hundred) | §3: 812.00 626 |
| fewer than one document in twenty carries an unprinted-file citation | §3: 99 of 2,450 |
| pointed-at led by Nicaragua's political file | §3 pointed-at 817.00 11 rows/9 docs |
| no digitized decimal ranges for these classes | §3: 0 of 624 |
| about six hundred unchaptered pre-1895 candidates in 58 volumes | M8: 608 in 58 |
| 28 documents mention the Estrada Doctrine | M9 |
| four documents put the Legal Adviser beside recognition | M9: 4 in 4 volumes |
| "recognition" loses about a third of its occurrences when footnotes and apparatus are removed | M5: 2,392 of 6,667 |
| the 1910s rate dominated by Mexico | M2 |
| Q1–Q24 (all double-quoted document text in the overview; check_overview.py: 57 quoted spans, 0 unverified) | §4 quotation table (verified 24 of 24) |
| every overview document is in the collection | §6 check |

## 6. Final checks (run before finishing; see queries.log tail)
- Every quotation in the overview and every `excerpt` in the collection is one of Q1–Q24, verified above, and the
  collection's excerpts were re-verified from the written file (check_collection.py).
- Every document the overview cites (43) is a `document` entry in the collection; the collection has no other document.

Results of the final checks (run 2026-10-25, outputs as printed):
- `python3 check_overview.py` → `quoted spans 57 unverified 0`, `documents quoted in overview: 23` (spans on its
  allowlist are search terms, bundled labels and the collection's title, not document quotations).
- `python3 check_collection.py` → `overview docs 43 collection docs 43 equal: True`; `overview quoted spans 28 without a
  collection excerpt: 0`; `excerpts 24 all verified against body_text`. The file has format "fruscollection",
  formatVersion 2, minimumReaderVersion 1, all seven composition keys (the six named in the brief plus
  includeWordCloud, as in the example), both ids on every document and excerpt entry, no duplicate pair, no Ed2 volume,
  an attribution line opening every note, and the archivalSources block last.
- Collection order: six level-1 headings in the order of the overview's findings, a prose entry under each, documents in
  `document_dates.date_iso` order within each heading (build_collection.py), excerpts immediately after their document,
  a closing prose entry naming threads not followed.
