# Scope memo — run r12 (operator copy)

Question: *How did the United States decide whether to recognize governments that came to power by force in Latin America, and what did it ask of them before recognizing?*
Run date 2026-10-26. Library: the SQLite copy taken 2026-10-25, opened read-only. Surfaces used: the index (document_cache, frus_documents FTS5 with porter stems, document_dates, document_sources, external_citations, volume_structures) and the bundled JSON of the installed app (build 1.0 (1776)). The TEI XML corpus was **not** read: no spelling-variant scan, acronym scan or footnote/body split was run, so every phrase figure below is an index-surface figure (porter-stem FTS hit list, literal share computed over the index text), and none is a TEI count. No [HARVEST] path was given; no harvest count appears here. Every count is conditional on the library of 553 volumes; the full series is 553 volumes.

Files in this directory: `memo.md` (this), `overview.md`, `collection.fruscollection`, `queries.log`; supporting: `scope.db` (the chapter scope, built by `build_scope.py`), `chapters_selected.txt`, `chap_recog.txt` and `chap_rev.txt` (chapter-title listings from `chapters.py`), `phrase_shares*.txt`, `decade.sql`, `archival_json.py`/`archival_json_out.json`, `decimal_gloss.py`/`decimal_gloss.txt`, `resolve_lots.py`, `pre1906.py`/`pre1906_out.txt`, `raw/` (whole `body_text` of every document read) and `reading_ledger.csv`, `display_ledger.csv`, `build/` (the scripts that wrote the deliverables).

## 1. Coverage and identity

[N01] Coverage query (first tool call of the run): `SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;` returned **553 | 321,749 | 1,103 | 8,481**, exactly the expected `553|321749|1103|8481`. The read-only proof (`BEGIN; CREATE TABLE zz(x); ROLLBACK;` with `sqlite3 -readonly`) failed with “attempt to write a readonly database”, as required.
[N02] Identity: every join in this run is on (volume_id, document_id); the rowid is used only inside FTS5 joins to reach `frus_documents` and is never reported. Every claim is cited volume_id/document_id. `summary_text` and `note_text` were never selected. Front matter (`is_front_matter = 1`) and editorial notes (`is_editorial_note = 1`) are excluded from every count unless said otherwise. No `cross_references` were used. No second-edition volume (ids ending Ed2) is in the chapter scope, the later pool or the collection, so no second-edition suppression was needed; counted surface: this index, apparatus excluded.

## 2. Scope chosen, and how it was found

Rule: the editors' headings, not my phrasing. `chapters.py` walks `volume_structures.structure_json` and prints every section title that matches a pattern (`chap_recog.txt`: pattern `recogni`, 253 titles; `chap_rev.txt`: `coup|junta|de facto|overthrow|military (govern|regime|take)|nonrecogni|non-recogni|new (regime|government)|provisional govern|change of govern|revolution`, 236 titles); `chapters2.py` re-ran the same walk with a Latin American country filter for 1889–1912, 1913–1929 and 1930–1949. From these listings I hand-picked chapters (list in `build_scope.py`; 60 chapter groups as tier A and 15 as tier B, counted from `scope.db`) and `build_scope.py` stored every document id under each chosen chapter in `scope.db`. The inclusion rule: *a document belongs to the scope if it sits under a chapter whose editor-written title names recognition, non-recognition, a revolution/coup/overthrow, or a recognition decision for a Latin American government* (Mexico, Central America, the Caribbean republics including Cuba, Haiti, Panama and the Dominican Republic, and South America). Chapters not about the recognition decision (claims, loans, commercial agreements, asylum) were not taken even where their titles contain the word “provisional” or “recognized”.

[N03] Chapter scope size: tier A 1,886 documents in 36 volumes; tier B (documents not already in A) 843 documents in 9 volumes; union **2,729 documents in 41 volumes**. SQL: `SELECT s.tier, count(*), count(distinct s.volume_id) FROM s.scope s JOIN document_cache c ON c.volume_id=s.volume_id AND c.document_id=s.document_id AND c.is_front_matter=0 AND c.is_editorial_note=0 GROUP BY s.tier;` (scope.db attached as s). Counting surface: document_cache rows after apparatus exclusion; 3 scope rows were apparatus and are excluded. `chapters_selected.txt` lists tier, volume, chapter (last 120 characters of its title path) and document count.
[N04] Date span of the chapter scope by the index's own date (`document_dates.date_iso`, which I did not re-derive from the TEI attribute `frus:doc-dateTime-min`; I did **not** use the volume's series year): earliest 1895-09-06, latest 1950-06-01, undated 0. SQL: `SELECT min(dd.date_iso), max(dd.date_iso), sum(dd.date_iso IS NULL) FROM s.scope s JOIN document_cache c ON ... LEFT JOIN document_dates dd ON dd.volume_id=s.volume_id AND dd.document_id=s.document_id`.

[N05] Decade shape of the chapter scope (the shape is a product of which chapters the editors wrote, not a prevalence of a term). Numerator = scope documents dated in the decade; denominator = all dated non-apparatus documents in the library in that decade; rate per 1,000; top-volume share of the numerator. SQL in `decade.sql` (run through `q2.sh`).

| decade | scope documents | dated non-apparatus documents in the library | per 1,000 | top volume (documents) | top-volume share |
|---|---|---|---|---|---|
| 1890s | 50 | 9,845 | 5.1 | frus1899 (46) | 0.92 |
| 1900s | 40 | 10,261 | 3.9 | frus1900 (13) | 0.33 |
| 1910s | 881 | 30,842 | 28.6 | frus1913 (357) | 0.41 |
| 1920s | 196 | 20,374 | 9.6 | frus1920v03 (70) | 0.36 |
| 1930s | 1061 | 40,073 | 26.5 | frus1933v05 (316) | 0.3 |
| 1940s | 498 | 75,872 | 6.6 | frus1944v07 (187) | 0.38 |
| 1950s | 3 | 43,159 | 0.1 | frus1950v02 (3) | 1.0 |

Thin cells: the 1890s (one volume, frus1899, holds 92% of the numerator), the 1900s (40 documents) and the 1950s (3 documents; the scope ends with frus1950v02). The 1950s–1970s are reached only through the full-text pool below, which is not a chapter scope.

[N06] Controls for the scoping pass, run in the same pass over the 41 scope volumes. Positive control, phrase “Department of State”: `WITH sv AS (SELECT DISTINCT volume_id FROM s.scope), pos AS (SELECT c.volume_id v, count(*) n FROM frus_documents d JOIN document_cache c ON c.rowid=d.rowid WHERE frus_documents MATCH '"department of state"' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id IN (SELECT volume_id FROM sv) GROUP BY 1) SELECT (SELECT count(*) FROM sv), count(*), min(n), sum(n) FROM pos;` returned 41 volumes, 41 with a hit, minimum 35 documents per volume, 8,527 documents in all (expected: non-zero in every volume — met). Negative control, string ZZZ_IMPOSSIBLE_ZZZ: `SELECT count(*) FROM frus_documents d JOIN document_cache c ON c.rowid=d.rowid WHERE frus_documents MATCH '"ZZZ_IMPOSSIBLE_ZZZ"' AND c.volume_id IN (SELECT volume_id FROM s.scope);` returned **0** (expected 0 — met).

Second component, the full-text pool for the volumes that have no recognition chapters (1949 onward):
[N09] Pool: **448 documents in 20 volumes**. SQL: `SELECT count(*), count(distinct c.volume_id) FROM frus_documents d JOIN document_cache c ON c.rowid=d.rowid WHERE frus_documents MATCH 'body_text:(recognition OR recognize) AND body_text:(junta OR coup OR ("de facto") OR revolutionary)' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id IN ('frus1949v02','frus1950v02','frus1951v02','frus1952-54v04','frus1955-57v06','frus1955-57v07','frus1958-60v05','frus1961-63v12','frus1964-68v31','frus1964-68v32','frus1969-76ve10','frus1969-76ve11p1','frus1969-76ve11p2','frus1977-80v15','frus1977-80v23','frus1977-80v24','frus1977-80v29','frus1981-88v16','frus1952-54Guat','frus1969-76v21');` (20 Western Hemisphere volumes: frus1949v02, 1950v02, 1951v02, 1952-54v04, 1952-54Guat, 1955-57v06, 1955-57v07, 1958-60v05, 1961-63v12, 1964-68v31, 1964-68v32, 1969-76ve10, ve11p1, ve11p2, v21, 1977-80v15, v23, v24, v29, 1981-88v16). Counting surface: FTS5 porter stems over `body_text` (footnotes included); stems fold “recognition” with “recognized” only if the stem agrees, so this is a candidate list, not a count of recognition decisions. I read the decision documents in it (see §6); the pool is not a scope of record.
[N10] Pre-1895 loose search: **445 documents in 55 of the 57 volumes** dated before frus1895 (57 volumes, 1861–1894). SQL: `SELECT count(*), count(distinct c.volume_id) FROM frus_documents d JOIN document_cache c ON c.rowid=d.rowid WHERE frus_documents MATCH 'body_text:(recognition OR recognize) AND body_text:(revolution OR "provisional government" OR "de facto") AND body_text:(venezuela OR mexico OR peru OR chile OR colombia OR bolivia OR ecuador OR haiti OR nicaragua OR honduras OR guatemala OR salvador OR paraguay OR uruguay OR argentine OR brazil OR cuba OR dominican OR panama OR "costa rica")' AND c.volume_id < 'frus1895' AND c.is_front_matter=0 AND c.is_editorial_note=0;`. Not followed beyond two documents (frus1877/d222, frus1878/d344).

## 3. False-friend test and phrase shares

[N07] False-friend test for the term the question supplied (“recognize”). Inside the same 41 volumes, share of chapter-scope documents with a word starting `recogn` against share of the other non-apparatus documents of those volumes, beside a control phrase. SQL (per query string Q): `WITH hit AS (SELECT c.volume_id v, c.document_id d FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH Q AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id IN (SELECT volume_id FROM s.scope)), allv AS (SELECT c.volume_id v, c.document_id d, (s.volume_id IS NOT NULL) insc FROM document_cache c LEFT JOIN s.scope s ON s.volume_id=c.volume_id AND s.document_id=c.document_id WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id IN (SELECT volume_id FROM s.scope)) SELECT allv.insc, count(*) total, sum(hit.v IS NOT NULL) hits FROM allv LEFT JOIN hit ON hit.v=allv.v AND hit.d=allv.d GROUP BY 1;`

| query Q | chapter-scope documents | other documents in the same 41 volumes |
|---|---|---|
| recogn* (prefix) | 1,014 of 2,729 (0.372) | 3,928 of 38,789 (0.101) |
| “department of state” (control) | 333 of 2,729 (0.122) | 8,194 of 38,789 (0.211) |
| “international obligations” | 95 of 2,729 (0.035) | 184 of 38,789 (0.005) |

Reading: `recogn*` is 3.7 times more common in the chapter documents than elsewhere in the same volumes, while the control phrase is *less* common in them (0.122 against 0.211); so the term separates the topic from the corpus and is usable, but 10% of the other documents also contain it (the word has other senses in treaty, claims and consular matters; I did not classify them), so it is not a clean marker of the referent. Literal shares of these hit lists (rule (a): sorted by volume_id, document_id; whole set if under 300, otherwise 40 evenly spaced; Python `re`, IGNORECASE, over header+dateline+source_note+body_text, whitespace-collapsed; one regime for the family; script `phrase_shares2.py`):

- recogn* (prefix) | scope documents | FTS recogn* | M=1014 | evenly spaced 40 n=40 | STRICT 40 of 40 | TOLERANT 40 of 40
- department of state | scope documents | FTS "department of state" | M=333 | evenly spaced 40 n=40 | STRICT 40 of 40 | TOLERANT 40 of 40
- international obligations | scope documents | FTS "international obligations" | M=95 | census n=95 | STRICT 94 of 95 | TOLERANT 95 of 95
- recogn* (prefix) | non-scope documents | FTS recogn* | M=3928 | evenly spaced 40 n=40 | STRICT 40 of 40 | TOLERANT 40 of 40
- department of state | non-scope documents | FTS "department of state" | M=8194 | evenly spaced 40 n=40 | STRICT 40 of 40 | TOLERANT 40 of 40
- international obligations | non-scope documents | FTS "international obligations" | M=184 | census n=184 | STRICT 159 of 184 | TOLERANT 178 of 184

Strict = the whole words recognize/recognized/recognizes/recognizing/recognition (for `recogn*`) or the exact words with single spaces (for phrases); tolerant = any word beginning `recogn`, or inflections with any run of space, hyphen, comma, parenthesis or full stop between the words. For the 184 non-scope “international obligations” hits tolerant is 178 of 184, i.e. six hits the stemmer matched are not that phrase; I did not read them.

[N08] Phrase counts inside the chapter scope (tiers A+B), each with its literal share (script `phrase_shares.py`, same regime; all four lists are under 300 so each is a census). Output file `phrase_shares.txt`:

- international obligations | FTS phrase "international obligations" | hits in scope (A+B) M=95 | census (whole set, M<300) n=95 | STRICT 94 of 95 | TOLERANT 95 of 95 | referent[within 300 characters of a form of 'recogn'] 50 of 95
- de facto | FTS phrase "de facto" | hits in scope (A+B) M=178 | census (whole set, M<300) n=178 | STRICT 178 of 178 | TOLERANT 178 of 178 | referent[followed within a separator run by government/regime/authority/administration/president/junta/power/control/status/recognition] 137 of 178
- popular support | FTS phrase "popular support" | hits in scope (A+B) M=40 | census (whole set, M<300) n=40 | STRICT 40 of 40 | TOLERANT 40 of 40 | referent[within 300 characters of government/regime/junta/administration/president] 38 of 40
- not recognize | FTS phrase "not recognize" | hits in scope (A+B) M=66 | census (whole set, M<300) n=66 | STRICT 61 of 66 | TOLERANT 66 of 66 | referent[within 300 characters of government/regime/junta/administration/president] 56 of 66

SQL for each: `SELECT c.volume_id,c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid JOIN s.scope s ON s.volume_id=c.volume_id AND s.document_id=c.document_id WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 ORDER BY c.volume_id,c.document_id` with the MATCH argument the quoted phrase shown. Tolerant reading: all four are ≥ 0.80 tolerant (1.000, 1.000, 1.000, 1.000), so each is usable in published form. A 1.000 share tests the stemmer, not the referent, so the referent test is separate: for “de facto” 137 of 178 are followed by government/regime/authority/administration/president/junta/power/control/status/recognition; for “not recognize” 56 of 66 sit within 300 characters of government/regime/junta/administration/president; for “international obligations” 50 of 95 sit within 300 characters of a form of “recogn” (the phrase also occurs in claims, treaty and loan contexts). The overview uses only the first count (“de facto”, about one in fifteen: 178 of 2,729) and the international-obligations count (about a hundred: 95 of 2,729; 94 strict).

## 4. Archival scope (channels never summed)

[N11a] Channel one, came-from, chapter documents (document_sources, one row per document). SQL: `SELECT ds.citation_era, count(*) FROM s.scope s JOIN document_cache c ON c.volume_id=s.volume_id AND c.document_id=s.document_id AND c.is_front_matter=0 AND c.is_editorial_note=0 LEFT JOIN document_sources ds ON ds.volume_id=s.volume_id AND ds.document_id=s.document_id GROUP BY 1;` gave decimal 2,626 of 2,729 (record_group 59, repository Department of State), no source row 91, unrecognized 8, published 3, lot_file 1. “More than nine in ten” = 2,626 of 2,729 = 0.962. In all, 2,582 chapter documents carry a non-null `decimal_class` (a few of them have a `citation_era` other than decimal); `decimal_gloss.py` glossed them only inside `glossableYears` (1910–1949, 1950–1959, 1960–1963), per `decimal-class-labels.json`; output `decimal_gloss.txt` (e.g. 812.00 Mexico, political affairs, 356; 837.00 Cuba, 305; 818.00 Costa Rica, 173; 816.01 El Salvador, government, 170; 824.00 Bolivia, 164; 823.00 Peru, 131; 838.00 Haiti, 107). The gloss is by file-number class and country, i.e. the file’s subject, not the Archives series. The bundled data has **no** NAID, entry number, extent or access status for the Central Decimal File itself (`central-files-index.json` holds lot files, the Numerical File M862 and pre-1906 country series; `collection-authority.json` names “Central Decimal File 1910–1929” etc. only as text aliases without identifiers), so none is given in the overview.
[N11b] The 91 chapter documents with no `document_sources` row, by volume: frus1899 46, frus1900 13, frus1903 9, frus1904 7, frus1911 6, frus1895p1 4, frus1913 2, frus1948v09 1, frus1914 1, frus1912 1, frus1907p2 1 (79 in the 1895–1904 volumes). `pre1906.py` (reads `central-files-index.json` `countrySeries`) matched the date of three of them to rolls: despatches Venezuela 1835–1906 roll 188967467 (file unit 177380736), Colombia 1820–1906 roll 189300896 (177380752), Ecuador 1848–1906 roll 189312130 (177380753); instructions Colombia vol. 19 roll 149302787, Ecuador vols 1–2 roll 149303924; no Venezuela instructions roll. `series-facts-index.json` has no row for these file units (access status not in the bundle). The one lot-file source in the chapter scope is frus1948v09/d115 (“Policy Planning Staff Files: Lot No. 64–D–563”). `resolve_lots.py 64D563`: `central-files-index.json` lotFiles gives NAID 1136548, “Chronological Files”, entry A1 558-D, RG 59; `series-facts-index.json`: Department of State, Policy Planning Council, 5 linear feet 3 inches, 1947–1962, accessStatus Unrestricted; `lot-claimants-index.json` lists **12** series claiming the lot (twelve rows, evidence controlNumber), so the Chronological Files is one candidate, not the series.
[N11c] Channel two, pointed-at, chapter documents (external_citations; the index has no row before 1910-12-06 and stores the fragment, not the sentence; it holds lot, library and decimal anchors only). SQL: `SELECT count(*), count(distinct e.volume_id||'/'||e.document_id) FROM s.scope s JOIN document_cache c ON ... JOIN external_citations e ON e.volume_id=s.volume_id AND e.document_id=s.document_id;` gave **70 citations in 60 documents**; anchors: centralFileClass 70. All are file numbers of the Central Decimal File (e.g. “file no. 824.00/217”); none is a lot, library or collection anchor.
[N11d] Channel two, bundled indexes, volume scope = the 41 scope volumes, `archival_json.py` (output `archival_json_out.json`): `external-citation-index.json` has references for 33 of the 41 volumes and, summed over them, 12 references to 7 collections: lot:53D250 (3), lot:60D137 (3), lot:53D26 (2), lot:53D444 (1), lot:56D625 (1), lot:66D95 (1), txt:roosevelt library|hyde park (1). These are references anywhere in those volumes’ notes, not in the chapter documents only. Resolved via `resolve_lots.py`: 53D26 NAID 2108774, A1 1130, “Subject Files”, Bureau of Inter-American Affairs, 1949–1953, Unrestricted; 53D444 NAID 2168520, A1 1197, 1949–1952, access Restricted - Possibly; 56D625 NAID 2092759, A1 1207, “Political (P) Files”, Far Eastern Affairs, 1948–1955, Unrestricted; 66D95 NAID 2839192, A1 1586E, 1947–1979, Restricted - Partly; 53D250 and 60D137 are not in `central-files-index.json` lotFiles. `collection-usage-index.json`, summed over the same 41 volumes, resolves only 114 note citations to 16 collections (84 of them “IO Files”), which says nothing about the recognition chapters; it is not used in the overview. The offline stack barely reaches before 1940 and I report the empty pre-war roadmap as a data limit.

## 5. Absence claims, with controls

[N12] “Estrada Doctrine” (phrase): `SELECT count(*), count(distinct c.volume_id), min(substr(c.volume_id,5,4)), max(substr(c.volume_id,5,4)) FROM frus_documents d JOIN document_cache c ON c.rowid=d.rowid WHERE frus_documents MATCH '"estrada doctrine"' AND c.is_front_matter=0 AND c.is_editorial_note=0;` returned **28 documents in 18 volumes, 1931–1977**. Literal share (census, `phrase_shares3.py`): estrada doctrine | M=28 in 18 volumes | census | STRICT 27 of 28 | TOLERANT 27 of 28. Positive control “department of state” over the whole library: **94,049 documents in 552 volumes** (of 553); negative control ZZZ_IMPOSSIBLE_ZZZ: 0. I read the mention in frus1943v05/d334 (editors’ footnote) and in frus1948v09/d7; I did not read the other mentions. The count says the doctrine is discussed, not that its text is printed. Counterpart vocabulary: I did not run a counterpart-vocabulary scan (foreign ministry, chancery) and I make no pre-war absence claim from this search.
[N13] Post-1980 coverage: `SELECT DISTINCT volume_id FROM document_cache WHERE volume_id >= 'frus1981' ORDER BY 1;` returned **14 volumes** (frus1981-88v01, frus1981-88v03, frus1981-88v04, frus1981-88v05, frus1981-88v06, frus1981-88v10, frus1981-88v11, frus1981-88v13, frus1981-88v16, frus1981-88v24, frus1981-88v38, frus1981-88v41, frus1981-88v44p1, frus1989-92v31). From `manifest.json` titles only frus1981-88v16 (South America) concerns Latin America; the others are Soviet Union, Eastern Europe, START, South Atlantic conflict, North Africa, economic and global issues, national security policy. Full-name probes (the bare-surname probes I ran first are withdrawn): `frus_documents MATCH '"raoul cedras"'`, `'"jean bertrand aristide"'`, `'"cedras raoul"'` each returned 0 documents. These zeros describe the library, not the world; the positive control is the one in [N12].

## 6. Reading accounting

[N14] Documents retrieved whole: **124** distinct (volume_id, document_id) pairs written by `read.py` (`SELECT header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?`) to `raw/<volume_id>__<document_id>.txt`, with captured length equal to `length(body_text)` for all 124 (`reading_ledger.csv` columns volume, document, length(body_text), len(captured body_text) — the two are equal in every row; lengths are in characters). Of these, 84 lie in the chapter scope (84 of 2,729 chapter documents retrieved). The collection holds **56** documents, all retrieved whole; I displayed 55 of them in full and one in part (frus1936v05/d112: first 4,500 of 38,701 characters, enough for its covering letter; I quote only that letter). `display_ledger.csv` records the spans I re-displayed after the first view. For the other 68 retrieved documents I did not keep a record of what part was displayed; no claim in the deliverables depends on them except the ones named in this memo (the chapter-title identifications and §2). Quoted: **22 passages from 21 documents** (§8). Documents read in the 1877–1878 sample: 2.

Dates behind the intervals in the overview (all from the cited documents’ datelines, index `document_dates.date_iso`):

- [N15a] “ten months”: frus1877/d222 (1877-05-16, the instruction to wait) to frus1878/d344 (1878-03-23, the authorization to recognize): 311 days = 10.2 months.
- [N15b] “nine days”: frus1934v05/d85 (1934-01-14, President’s decision) to frus1934v05/d103 (1934-01-23, instruction to recognize): 9 days.
- [N15c] “just over two years”: frus1931v02/d232 (1931-12-20) to frus1934v05/d257 (1934-01-26): 768 days = 2.10 years.
- [N15d] “three years”: frus1925v02/d54 (1925-07-29) to frus1928v02/d741 (1928-08-13), 1111 days = 3.04 years; d741 itself says “three years and more” since the coup of 9 July 1925.
- [N15e] “ten weeks” (Honduras): frus1964-68v31/d72 editors’ footnote gives non-recognition “October 3 to December 14, 1963”: 72 days = 10.3 weeks. This is an editors’ footnote inside the body_text of a 1964 Mann memorandum.
- [N16] “1877 to 1973”: earliest and latest dates among the collection documents (frus1877/d222 1877-05-16; frus1969-76v21/d348 1973-09-12).
- [N17] “56 documents”: documents in `collection.fruscollection` (`verify.py`: all pairs exist in document_cache, none is front matter or an editorial note, no duplicate pair, no Ed2 volume).

## 7. Corrections to my own working notes, and things in the sources to know

- frus1917/d424 carries the dateline “September 21, 1911” in the printed text, although it sits among the 1917 Tinoco papers and cites a February 1917 telegram; I read it but do not use it.
- The Bogotá resolution is called “Resolution XXXV” in frus1948v09/d89 and d119 and “Article XXXIII of the Final Act” in the editors’ note to d7. The overview does not number it.
- frus1930v01/d375 does not name the Secretary of State; the overview says “the Secretary of State”. The text reads “regular rules of international Jaw” (an OCR error in the index text), so that phrase is paraphrased in the overview, not quoted.
- frus1944v07/d226 is Hull relaying a British Embassy suggestion for the ambassador’s comment; the overview says “floated” and “relayed”, not “imposed”.
- frus1913/d1028 reports that the proposals were rejected (the overview says “put to Huerta’s Mexico … and refused”).
- frus1936v05/d112 is a 38,701-character instruction with an enclosed memorandum; I read the covering letter only.
- Two collection documents are cited for editors’ footnotes inside their body_text, not for the document’s own text: frus1964-68v31/d72 (the Honduras non-recognition dates) and frus1964-68v31/d132 (the description of the 1965 Rio resolution). None of the quotations in section 8 is taken from an editors’ footnote.
- Chapter titles quoted in the overview (“Revolution in…”, “Recognition of…”, “Refusal of the United States to recognize…”) are editors’ titles verified by `grep` in `chap_recog.txt`/`chap_rev.txt` (e.g. 1930v01 “Revolution in Argentina”; 1922v02 “Recognition of the Orellana government by the United States”; 1932v05 “Refusal of the United States to recognize the Martínez regime in El Salvador”), not document quotations; `grep -c` counts: "Revolution in " 33 titles in chap_rev.txt, "Recognition of" 44 titles in chap_recog.txt, "Refusal of the United States to recognize" 5 titles in chap_recog.txt. The phrases “Department of State” and “international obligations” in quotation marks in the overview are search phrases, not quotations.
- Thin results: channel two (12 bundled references; 70 file numbers); the 1890s and 1900s decades; the 1950s (3 documents); the post-1950 pool (448 documents, about two dozen read); everything before 1895 (two documents read). These may reflect what I read, not the corpus.

## 8. Quotations: SELECT, pair, verification

Every quotation in `overview.md` and every excerpt in `collection.fruscollection` is listed here. Retrieval for each: `SELECT body_text FROM document_cache WHERE volume_id = '<volume_id>' AND document_id = '<document_id>';` then the text is cut between the two anchor strings (inclusive) in `build/data.py` by `build/verify.py`, and checked to be an exact character-for-character substring of `body_text`. Offsets are character offsets into `body_text`.

- [Q01] frus1900/d530, offset 1439, 447 characters, exact substring of body_text: yes. SELECT: `SELECT body_text FROM document_cache WHERE volume_id = 'frus1900' AND document_id = 'd530';`. Text: “the rule of the United States is to defer recognition of another executive in its place until it shall appear that it is in possession of the machinery of the state, administering government with the assent of the people thereof and without substantial resistance to its authority, and that it is in a position to fulfill all the international obligations and responsibilities incumbent upon a sovereign state under treaties and international law.”
- [Q02] frus1878/d344, offset 171, 322 characters, exact substring of body_text: yes. SELECT: `SELECT body_text FROM document_cache WHERE volume_id = 'frus1878' AND document_id = 'd344';`. Text: “the Government of the United States before recognizing General Diaz as the President of Mexico waited to be assured that his administration was approved by the Mexican people, and was possessed of due stability and animated by a disposition to comply with the rules of international comity and the obligations of treaties.”
- [Q03] frus1911/d933, offset 9449, 460 characters, exact substring of body_text: yes. SELECT: `SELECT body_text FROM document_cache WHERE volume_id = 'frus1911' AND document_id = 'd933';`. Text: “The Government of Nicaragua is to proceed at the earliest possible date to the signature of a convention with the United States which shall authorize the contemplated bankers’ loan contract, the terms of the latter to be approved thereafter by both Governments, and to make provision, among other things, for the service of the loan secured by a certain percentage of the customs receipts of the Republic collected in a manner satisfactory to both Governments.”
- [Q04] frus1917/d379, offset 701, 295 characters, exact substring of body_text: yes. SELECT: `SELECT body_text FROM document_cache WHERE volume_id = 'frus1917' AND document_id = 'd379';`. Text: “the desire which this Government has of seeing the will of the people prevail in governmental matters in Costa Rica has forced it to the conclusion that no Government except such as may be elected legally and established according to the Constitution shall be considered entitled to recognition.”
- [Q05] frus1921v01/d238, offset 706, 166 characters, exact substring of body_text: yes. SELECT: `SELECT body_text FROM document_cache WHERE volume_id = 'frus1921v01' AND document_id = 'd238';`. Text: “has now determined to extend recognition to the existing Government of Bolivia, not as the de facto Government, but as the Constitutional Government of that Republic.”
- [Q06] frus1921v02/d344, offset 3552, 200 characters, exact substring of body_text: yes. SELECT: `SELECT body_text FROM document_cache WHERE volume_id = 'frus1921v02' AND document_id = 'd344';`. Text: “In short, when it appears that there is a government in Mexico willing to bind itself to the discharge of primary international obligations, concurrently with that act its recognition will take place.”
- [Q07] frus1930v01/d375, offset 3893, 284 characters, exact substring of body_text: yes. SELECT: `SELECT body_text FROM document_cache WHERE volume_id = 'frus1930v01' AND document_id = 'd375';`. Text: “will not recognize any other Government which may come into power in any of the five Republics through a coup d’état or a revolution against a recognized Government, so long as the freely elected representatives of the people thereof have not constitutionally reorganized the country.”
- [Q08] frus1931v02/d232, offset 1114, 102 characters, exact substring of body_text: yes. SELECT: `SELECT body_text FROM document_cache WHERE volume_id = 'frus1931v02' AND document_id = 'd232';`. Text: “The United States Government, therefore, will not recognize General Martínez as President of Salvador.”
- [Q09] frus1936v05/d112, offset 658, 290 characters, exact substring of body_text: yes. SELECT: `SELECT body_text FROM document_cache WHERE volume_id = 'frus1936v05' AND document_id = 'd112';`. Text: “the United States should no longer be guided by Article II of the General Treaty of Peace and Amity of 1923 in extending or denying recognition to Governments in Central America, nor should it endeavor to utilize that Treaty as justification for any other action it may take or fail to take”
- [Q10] frus1934v05/d85, offset 485, 189 characters, exact substring of body_text: yes. SELECT: `SELECT body_text FROM document_cache WHERE volume_id = 'frus1934v05' AND document_id = 'd85';`. Text: “This Government will recognize a Cuban provisional Government which is substantially supported by the Cuban people and is able to maintain law, order and the normal functions of Government.”
- [Q11] frus1944v07/d226, offset 844, 441 characters, exact substring of body_text: yes. SELECT: `SELECT body_text FROM document_cache WHERE volume_id = 'frus1944v07' AND document_id = 'd226';`. Text: “the road would be open for reconsideration of our attitude on recognition: 1. Thorough and effective collaboration to foil Axis activities in the Argentine, particularly those relating to espionage, smuggling, and telecommunications; 2. Appointment of new Cabinet Ministers, particularly in Foreign Relations and Interior, that would inspire confidence of collaboration for hemisphere security; and 3. Fixing of a date for general elections.”
- [Q12] frus1945v09/d883, offset 1513, 537 characters, exact substring of body_text: yes. SELECT: `SELECT body_text FROM document_cache WHERE volume_id = 'frus1945v09' AND document_id = 'd883';`. Text: “There are certain well established requirements of international law for recognition: (a) Control of the machinery of Government; (b) General popular support without active opposition; and (c) willingness and ability to observe international obligations. Due to the war, the Committee for Political Defense of Montevideo established a fourth—whereby when a Government came into power through force, the countries of the hemisphere would consult to determine whether its assumption to power demonstrated direct or indirect Axis influence.”
- [Q13] frus1948v09/d7, offset 11422, 477 characters, exact substring of body_text: yes. SELECT: `SELECT body_text FROM document_cache WHERE volume_id = 'frus1948v09' AND document_id = 'd7';`. Text: “The recognition policy of the Department should be based upon the three following factors, any or all of which would be applied in a given case according to U.S. national interests: (a) de facto control of the territory and the administrative machinery of State, including the maintenance of public order; (b) the ability and willingness of a government to discharge its international obligations; (c) general acquiescence of the people of a country in the government in power.”
- [Q14] frus1948v09/d115, offset 4615, 113 characters, exact substring of body_text: yes. SELECT: `SELECT body_text FROM document_cache WHERE volume_id = 'frus1948v09' AND document_id = 'd115';`. Text: “non-recognition is not a suitable weapon for influencing the course of internal events in Venezuela at this time.”
- [Q15] frus1951v02/d688, offset 1817, 477 characters, exact substring of body_text: yes. SELECT: `SELECT body_text FROM document_cache WHERE volume_id = 'frus1951v02' AND document_id = 'd688';`. Text: “From appearances to date the Junta has met the criteria which the United States has applied in other recent cases involving the recognition of Latin American governments which have come to power through irregular procedures. It has established its authority over Bolivian territory, with the substantial acquiescence of the people, it has declared its intent to honor Bolivia’s international obligations, and its assumption of power has not been due to any external influences.”
- [Q16] frus1961-63v12/d423, offset 1641, 495 characters, exact substring of body_text: yes. SELECT: `SELECT body_text FROM document_cache WHERE volume_id = 'frus1961-63v12' AND document_id = 'd423';`. Text: “1. Guarantee of continued civil liberties. 2. Guarantee of free and fair elections, preferably before June 9 but at no later date, with full rights to all parties under Constitution, and with guarantee that Armed Forces will respect results those elections. 3. Offer by Junta, as indication of good faith, to invite OAS observers during electoral processes. This concession would particularly strengthen Junta’s position with respect continental opinion and would also facilitate US recognition.”
- [Q17] frus1964-68v31/d139, offset 679, 309 characters, exact substring of body_text: yes. SELECT: `SELECT body_text FROM document_cache WHERE volume_id = 'frus1964-68v31' AND document_id = 'd139';`. Text: “The classical criteria for recognition (i.e., general control of the country and pledge to honor international obligations) have been met. We are still awaiting public affirmation of the OAS criteria: respect for human rights, peaceful settlement of disputes, and eventual return to constitutional government.”
- [Q18] frus1969-76v21/d348, offset 1598, 138 characters, exact substring of body_text: yes. SELECT: `SELECT body_text FROM document_cache WHERE volume_id = 'frus1969-76v21' AND document_id = 'd348';`. Text: “we should take the public position that we recognize governments, not heads of government, and that question of recognition has not arisen”
- [Q19] frus1913/d7, offset 875, 53 characters, exact substring of body_text: yes. SELECT: `SELECT body_text FROM document_cache WHERE volume_id = 'frus1913' AND document_id = 'd7';`. Text: “based upon law, not upon arbitrary or irregular force”
- [Q20] frus1923v02/d345, offset 4429, 25 characters, exact substring of body_text: yes. SELECT: `SELECT body_text FROM document_cache WHERE volume_id = 'frus1923v02' AND document_id = 'd345';`. Text: “in the most hearty accord”
- [Q21] frus1951v02/d688, offset 1901, 29 characters, exact substring of body_text: yes. SELECT: `SELECT body_text FROM document_cache WHERE volume_id = 'frus1951v02' AND document_id = 'd688';`. Text: “applied in other recent cases”
- [Q22] frus1961-63v12/d363, offset 1224, 13 characters, exact substring of body_text: yes. SELECT: `SELECT body_text FROM document_cache WHERE volume_id = 'frus1961-63v12' AND document_id = 'd363';`. Text: “virtually nil”

## 8b. Paraphrased document facts in the overview, with the supporting passage

Each fact below is paraphrased (not quoted) in the overview or the collection notes. The passage is cut from `body_text` by the same SELECT as in section 8; the anchor must occur in the document (asserted when this memo was written).

- frus1948v09/d7 | the 1947 internal study, 'not printed' (overview 3e) | offset 1270 | ... United States policy in the recognition of new governments prepared in the Department last year by RE Not printed. states that what is referred to as our traditi...
- frus1913/d1028 | Lind proposals rejected | offset 8527 | ... visit but also the spirit in which it had been undertaken. But the proposals he submitted were rejected, in a note the full text of which I take the liberty of lay...
- frus1913/d1028 | Huerta not to be a candidate | offset 7078 | ...nd free election in which all will agree to take part; “(c) The consent of General Huerta to bind himself not to be a candidate for election as President of the Republic at this election;...
- frus1944v07/d388 | Bolivia 1944: recognition unlikely | offset 4635 | ...livian revolt is considered here to be very strong and that it is unlikely that this government will recognize the new regime. You should therefore request that any pertinent informatio...
- frus1934v05/d103 | Cuba 23 Jan 1934 | offset 266 | ... to the Government of Cuba on behalf of the United States a formal and cordial recognition. Hull...
- frus1945v09/d254 | Argentina announcement 9 April 1945 | offset 302 | ...hould be resumed immediately with the Argentine Government. We intend to announce at noon, Monday, April 9, that we are taking the action contemplated in my message w...
- frus1945v09/d251 | Argentina proposal 9 April 1945 | offset 3118 | ...rding this matter. You should indicate that this Government contemplates individual, rather than collective, action on April 9 but you should emphasize its strong belief that recognition...
- frus1964-68v31/d72 | Honduras non-recognition dates (editors' footnote) | offset 3012 | ...U.S. voices during the period of non-recognition last fall (October 3 to December 14, 1963). Villeda Morales on October 3, 1963. The Kennedy administr...
- frus1964-68v31/d152 | Bolivia 1964 private pledges | offset 1646 | ...fluence will be reduced and eventually eliminated, and that they will not reestablish relations with Cuba or Czechoslovakia. While the new government may not be able to fulfill comple...
- frus1969-76v21/d348 | Kubisch on hasty recognition | offset 4694 | ...ould go back up north. Mr. Kissinger: I agree. Mr. Kubisch: The biggest errors we have made in Latin America in recent years have involved too hasty recognition of military regimes—in Brazil, for example. Also, this has created the biggest ...
- frus1934v05/d257 | El Salvador recognized 26 Jan 1934 (editors' note) | offset 274 | ...l and cordial recognition to the Government of El Salvador. The Chargé extended recognition late in the afternoon of January 26, in a note which he delivered personally to the Minister of...
- frus1934v05/d255 | three neighbors recognize 25 Jan 1934 | offset 729 | ...t of the initiative taken by President Sacasa of Nicaragua, have today accorded formal recognition to the Government of El Salvador. The foreign ministers of the three Governments mentioned h...
- frus1948v09/d89 | Bogota resolution avoids the word recognition | offset 1844 | ...stablishing relations with new governments, and to this end avoids use of the formal term “recognition”. On the basis of the general policy set forth...
- frus1948v09/d118 | Army view: oil and military mission | offset 2300 | ...or non-recognition of the new Venezuelan Government: first, the need for an uninterrupted supply of Venezuelan oil for the United States and second, the desirability of maint...
- frus1949v02/d450 | Panama 1949 assurances | offset 623 | ...anamanian administrations. Your Excellency states also that the Government has the support of the great majority of the Panamanian people, that it controls all the national territory, which is enti...
- frus1920v01/d387 | Bolivia 1920: wait for elections | offset 560 | ...er that satisfactory evidence on this point can be obtained until after the general elections to be held next December. You are instructed therefore to make no intimation to the ...
- frus1928v02/d741 | Ecuador 1925-28 | offset 389 | ... the progress which the Republic of Ecuador has made during the three years and more which have elapsed since the coup d’état of July 9, 1925, and the tranquillity which has prev...
- frus1961-63v12/d423 | US waited three weeks in the Argentine case (1962) | offset 1329 | ...eek. With view US resumption relations at appropriate time (we waited three weeks in Argentine case) we anxious you intensify negotiations with Junta through a...
- frus1961-63v12/d359 | Dominican Republic 4 Oct 1963 | offset 3043 | ...discussions, you should state clearly and emphatically that USG will not recognize or deal with this regime as it stands. This regime and the politicians who named the cabinet repr...
- frus1961-63v12/d416 | Peru May 1962: approach to third countries | offset 2974 | ... align selves with US, should coup take place, on policy of at least temporary nonrecognition. (We will discuss with you separately possible courses of a...
- frus1964-68v31/d132 | Argentina June 1966 relations suspended | offset 1861 | ...tion. In keeping with international practice in such cases, diplomatic relations are suspended. We will be consulting with other OAS members in accordance...
- frus1964-68v31/d139 | Argentina July 1966 | offset 818 | ...d pledge to honor international obligations) have been met. We are still awaiting public affirmation of the OAS criteria: respect for human rights, peaceful settlement of disputes,...
- frus1955-57v07/d465 | Colombia 1957 | offset 922 | ...ommend that you authorize me to take the necessary steps to extend prompt recognition to the Military Junta as the provisional Government of Colombia. A handwritten no...
- frus1958-60v06/d217 | Cuba 7 Jan 1959 (editors' note) | offset 2519 | ...lics except Havana, January 7, the Department reported that recognition had been accorded at 5 p.m. that day. (Department of State, Central Files, 737.00/1–759) John Fo...
- frus1877/d222 | Seward 1877: guarantee as condition precedent | offset 4885 | ...e that some guarantee of such an arrangement should be made the condition precedent to any recognition, rather than to trust to the possibility that it may ultima...
- frus1878/d344 | Evarts authorizes recognition, March 1878 | offset 2339 | ...fore, authorize you to inform Mr. Vallarta that he deems it no longer necessary or desirable to defer the resumption of diplomatic relations, and the official recognition of the authorities with whom ...
- frus1930v01/d375 | Sept 1930: rules (the index text spells the last word with an OCR error) | offset 2190 | ...ts, which we are recognizing tomorrow, we are following the regular rules of international Jaw, and the regular policy which has characterized this co...

## 9. The collection’s documents and datelines

| volume_id/document_id | date_iso | dateline | in heading |
|---|---|---|---|
| frus1877/d222 | 1877-05-16 | Department of State, Washington, May 16, 1877. | 1 |
| frus1878/d344 | 1878-03-23 | Department of State, Washington, March 23, 1878. | 1 |
| frus1895p1/d246 | 1895-11-06 | Department of State, Washington, November 6, 1895. | 1 |
| frus1899/d792 | 1899-10-23 | Department of State, Washington, October 23, 1899. | 1 |
| frus1900/d530 | 1900-09-08 | Department of State, Washington, September 8, 1900. | 1 |
| frus1911/d933 | 1911-01-20 | Department of State, Washington, January 20, 1911. | 1 |
| frus1913/d89 | 1913-03-28 |  | 1 |
| frus1913/d7 | 1913-03-12 | Department of State, Washington, March 12, 1913—1 p.m. | 2 |
| frus1913/d1028 | 1913-08-27 | Department of State, Washington, August 27, 1913—10 p.m. | 2 |
| frus1917/d379 | 1917-02-09 | Department of State, Washington, February 9, 1917, 3 p.m. | 2 |
| frus1917/d407 | 1917-06-09 | Department of State, Washington, June 9, 1917—3 p.m. | 2 |
| frus1920v01/d387 | 1920-08-24 | Washington, August 24, 1920—6 p.m. | 2 |
| frus1920v01/d391 | 1920-09-27 | Washington, September 27, 1920—6 p.m. | 2 |
| frus1921v01/d238 | 1921-01-31 | Washington, January 31, 1921—5 p.m. | 2 |
| frus1921v02/d344 | 1921-06-08 | Washington, June 8, 1921. | 2 |
| frus1921v02/d349 | 1921-07-21 | Washington, July 21, 1921. | 2 |
| frus1925v02/d54 | 1925-07-29 | Washington, July 29, 1925. | 2 |
| frus1928v02/d741 | 1928-08-13 | Washington, August 13, 1928—7 p.m. | 2 |
| frus1923v02/d345 | 1923-06-30 | Washington, June 30, 1923—3 p.m. | 3 |
| frus1930v01/d375 | 1930-09-17 | September 17, 1930 | 3 |
| frus1931v02/d232 | 1931-12-20 | Washington, December 20, 1931—1 p.m. | 3 |
| frus1934v05/d199 | 1934-01-08 | Washington, January 8, 1934. | 3 |
| frus1934v05/d255 | 1934-01-25 | Washington, January 25, 1934. | 3 |
| frus1934v05/d257 | 1934-01-26 | Washington, January 26, 1934—1 p.m. | 3 |
| frus1936v05/d109 | 1936-04-21 | [Washington,] April 21, 1936. | 3 |
| frus1936v05/d112 | 1936-04-30 | Washington, April 30, 1936. | 3 |
| frus1933v05/d508 | 1933-11-28 | Washington, November 28, 1933—6 p.m. | 4 |
| frus1934v05/d85 | 1934-01-14 | Washington, January 14, 1934—4 p.m. | 4 |
| frus1934v05/d103 | 1934-01-23 | Washington, January 23, 1934. | 4 |
| frus1943v05/d334 | 1943-06-06 | Washington, June 6, 1943—2 p.m. | 4 |
| frus1943v05/d486 | 1943-12-22 | Washington, December 22, 1943. | 4 |
| frus1944v07/d388 | 1944-01-10 | Washington, January 10, 1944—10 p.m. | 4 |
| frus1944v07/d226 | 1944-04-03 | Washington, April 3, 1944—7 p.m. | 4 |
| frus1945v09/d883 | 1945-02-26 | Washington, February 26, 1945. | 4 |
| frus1945v09/d251 | 1945-04-04 | Washington, April 4, 1945—9 a.m. | 4 |
| frus1945v09/d254 | 1945-04-08 | [Washington,] April 8, 1945. | 4 |
| frus1946v11/d322 | 1946-08-16 | Washington, August 16, 1946—8 p.m. | 4 |
| frus1948v09/d7 | 1948-03-15 | Washington, March 15, 1948. | 5 |
| frus1948v09/d89 | 1948-11-08 | [Washington,] November 8, 1948. | 5 |
| frus1948v09/d115 | 1948-12-10 | [Washington,] December 10, 1948. | 5 |
| frus1948v09/d118 | 1948-12-15 | Washington, December 15, 1948. | 5 |
| frus1948v09/d119 | 1948-12-16 | Washington, December 16, 1948—10 a. m. | 5 |
| frus1949v02/d450 | 1949-12-12 | Washington, December 12, 1949—7 p. m. | 5 |
| frus1951v02/d688 | 1951-05-30 | Washington, May 30, 1951. | 5 |
| frus1955-57v07/d193 | 1955-09-20 | Buenos Aires, September 20, 1955—4 p.m. | 6 |
| frus1955-57v07/d465 | 1957-05-15 | Washington, May 15, 1957. | 6 |
| frus1958-60v06/d217 | 1959-01-07 | Washington, January 7, 1959. | 6 |
| frus1961-63v12/d416 | 1962-05-29 | Washington, May 29, 1962, 9:14 p.m. | 6 |
| frus1961-63v12/d423 | 1962-07-30 | Washington, July 30, 1962, 9:17 p.m. | 6 |
| frus1961-63v12/d359 | 1963-10-04 | Washington, October 4, 1963, 10:06 p.m. | 6 |
| frus1961-63v12/d363 | 1963-12-13 | Washington, December 13, 1963, 8:15 p.m. | 6 |
| frus1964-68v31/d72 | 1964-02-06 | Washington, February 6, 1964. | 6 |
| frus1964-68v31/d152 | 1964-12-03 | Washington, December 3, 1964. | 6 |
| frus1964-68v31/d132 | 1966-06-28 | Washington, June 28, 1966, 9:44 a.m. | 6 |
| frus1964-68v31/d139 | 1966-07-07 | Washington, July 7, 1966, 5:48 p.m. | 6 |
| frus1969-76v21/d348 | 1973-09-12 | Washington, September 12, 1973, 10:10–10:45 a.m. | 6 |

## 10. Trace table

One row per number and per quotation in `overview.md`. Line numbers are lines of this file (`memo.md`) at which the audit form begins.

| overview item | memo tag | memo.md line |
|---|---|---|
| Opening note and Scope: “the library of 553 volumes”; Scope: “full library of 553 volumes”; How: “across the 553 volumes” | [N01] | 10 |
| Bottom line 1: “from 1877 to 1973” (also Decisions: “I covered 1877 to 1973”) | [N16] | 93 |
| Bottom line 1 and Scope and How: “about 2,700 documents in 41 volumes”, “1895 to 1950” | [N03] | 17 |
| Same, date span “1895 to 1950” | [N04] | 18 |
| Bottom line 1, Scope, How: “about 450 later documents from 20 Western Hemisphere volumes” | [N09] | 37 |
| Bottom line 1 and Read next: “the 56 documents” the collection holds | [N17] | 94 |
| Bottom line 2 channel one: “more than nine in ten of the chapter documents cite a file number”; “824.00 is Bolivia’s political affairs and 812.00 is Mexico’s”; “1910 to 1950” | [N11a] | 72 |
| Bottom line 2: “about ninety chapter documents have no source citation … most in the 1895 to 1904 volumes”; roll identifiers 188967467, 189300896, 189312130, 149302787, 149303924; lot 64 D 563 (one document, twelve series, identifier 1136548, entry A1 558-D, 1947–1962, unrestricted, five feet three inches) | [N11b] | 73 |
| Bottom line 2 channel two: “about sixty chapter documents cite about seventy file numbers … no lot-file or presidential-library citations” | [N11c] | 74 |
| Bottom line 2 channel two: “33 of the 41 volumes”, “seven collections … twelve citations”, lots 53 D 26, 53 D 444, 66 D 95, 56 D 625 with identifiers, entries, dates and access; 53 D 250 and 60 D 137 unresolved | [N11d] | 75 |
| Bottom line 3(a): “about thirty documents in eighteen volumes, 1931 to 1977”; “nearly 94,000 documents in 552 of the 553 volumes”; negative control “none” | [N12] | 79 |
| Bottom line 3(b): “fourteen volumes dated 1981 or later”, “one of them on Latin America”; full-name searches returned nothing | [N13] | 80 |
| Bottom line 3(c): “57 volumes for 1861 to 1894 … about 450 documents in 55 of them; I read only two” | [N10] | 38 |
| Finding 1: “ten months later” | [N15a] | 88 |
| Finding 4: “nine days later” | [N15b] | 89 |
| Finding 3: “just over two years later” | [N15c] | 90 |
| Finding 2: “three years later” | [N15d] | 91 |
| Finding 6: “3 October to 14 December 1963, ten weeks” | [N15e] | 92 |
| Finding 1: “‘de facto’ appear in about one chapter document in fifteen” | [N08] | 61 |
| How: “international obligations turn up in about a hundred chapter documents, nearly all in exactly that form” | [N08] | 61 |
| How: “about three of every eight chapter documents against about one in ten of the other documents in the same volumes” | [N07] | 42 |
| How: “I read in full 55 of the 56 documents in the collection and part of the other” | [N14] | 84 |
| Bottom line 3(e) and Findings 1–6: every document cited, dates and years given in the findings (e.g. “June 1943”, “9 April”): the cited document’s dateline, listed in section 9; paraphrased facts in section 8b | [N17] | 94 |
| Quotation Q01, Finding 1 (exact text in the memo) | [Q01] | 112 |
| Quotation Q02, Finding 1 (exact text in the memo) | [Q02] | 113 |
| Quotation Q03, Finding 1 (exact text in the memo) | [Q03] | 114 |
| Quotation Q04, Finding 2 (exact text in the memo) | [Q04] | 115 |
| Quotation Q05, Finding 2 (exact text in the memo) | [Q05] | 116 |
| Quotation Q06, Finding 2 (exact text in the memo) | [Q06] | 117 |
| Quotation Q07, Finding 3 (exact text in the memo) | [Q07] | 118 |
| Quotation Q08, Finding 3 (exact text in the memo) | [Q08] | 119 |
| Quotation Q09, Finding 3 (exact text in the memo) | [Q09] | 120 |
| Quotation Q10, Finding 4 (exact text in the memo) | [Q10] | 121 |
| Quotation Q11, Finding 4 (exact text in the memo) | [Q11] | 122 |
| Quotation Q12, Finding 4 (exact text in the memo) | [Q12] | 123 |
| Quotation Q13, Finding 5 (exact text in the memo) | [Q13] | 124 |
| Quotation Q14, Finding 5 (exact text in the memo) | [Q14] | 125 |
| Quotation Q15, Finding 5 (exact text in the memo) | [Q15] | 126 |
| Quotation Q16, Finding 6 (exact text in the memo) | [Q16] | 127 |
| Quotation Q17, Finding 6 (exact text in the memo) | [Q17] | 128 |
| Quotation Q18, Finding 6 (exact text in the memo) | [Q18] | 129 |
| Quotation Q19, Finding 2 (inline) (exact text in the memo) | [Q19] | 130 |
| Quotation Q20, Finding 3 (inline) (exact text in the memo) | [Q20] | 131 |
| Quotation Q21, Finding 5 (inline) (exact text in the memo) | [Q21] | 132 |
| Quotation Q22, Finding 6 (inline) (exact text in the memo) | [Q22] | 133 |

Line numbers refer to the section before this table; the table itself is appended after them and does not shift them.

## 11. What I did not do

No TEI scan (no spelling-variant, acronym or apparatus/document split); no counterpart-vocabulary scan; no read of `summary_text`/`note_text`; no use of `cross_references`; no [HARVEST] count; no NARA call (no network). The pre-1895 volumes, the 1950s–1970s pool beyond the decision documents, and the Mexican cases of 1913–1923 beyond the policy statements are unread. The overview’s “There is no X” statements are restricted to what the controls support (section 5).

