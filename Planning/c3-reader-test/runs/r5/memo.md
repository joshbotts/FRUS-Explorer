# Scope memo: recognition of governments that came to power by force in Latin America

Run r5, 2026-10-25. For the operator. Every number carries its query or script; the overview and the collection are for the historian.

**Question.** How did the United States decide whether to recognize governments that came to power by force in Latin America, and what did it ask of them before recognizing?

**Surfaces used.** (1) THE DATABASE: the read-only SQLite copy of the FRUS Explorer search index of 2026-10-25 (opened with `sqlite3 -readonly` or Python `mode=ro`; one proof that a write fails is the second line of the log). (2) THE BUNDLED JSON in the app build 1.0 (1776). (3) THE TEI XML: not used. I made no spelling-variant scan, no apparatus/document split and publish no density; every count of a word below is on the index's flattened body_text, which includes editorial footnotes. (4) [HARVEST]: no path was given, so that surface is unavailable and no harvest count appears.

## M0. Coverage, and what every count is conditional on

First command (verbatim, and the output the run required):

```
sqlite3 "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro" "SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;"
553|321749|1103|8481
```

Second command (read-only proof): `sqlite3 -readonly DB "BEGIN; CREATE TABLE zz(x); ROLLBACK;"` failed with: Error in 3rd command line argument: attempt to write a readonly database.

Every count below is conditional on this index: all 553 volumes of the series are present (the full series is 553), 321,749 documents, of which 9,580 are front matter or editorial notes and are excluded unless stated. SQL: `SELECT count(*), sum(is_front_matter=0 AND is_editorial_note=0) FROM document_cache;` gives 321749 | 312169. The non-apparatus total, 312,169, is the denominator of "the whole series" below.

## M1. The scope I chose, and how I found it

**M1.1 Two tiers.** (a) THE FIELD: documents under an editors' section heading that names recognition, its refusal or withholding, or continuance of diplomatic relations with a Latin American or Caribbean government that took power by revolution, coup or other irregular means; 1895-09-06 to 1950-06-01 (document dates). (b) THE ARGUMENT: the 56 documents I read and cite, from 31 volumes, 1877 to 1979; 27 of them lie inside the field, 29 outside it (policy statements, and every case after 1950, where the editors' headings stop naming recognition).

**M1.2 How found.** First the editors' own headings, because the instructions say my modern phrasing is usually absent. The index stores each volume's table of contents as JSON in volume_structures; `build_struct.py` walks it and writes struct.db (document to section path), 314,616 document rows. I searched headings with `frus_documents MATCH 'header:recognition'` (list in queries.log) and by regular expression over section paths (recognition, de facto, coup, junta, revolution, overthrow, and so on, crossed with Latin American country names), which produced scratch_struct_sections.tsv (106 sections). I then curated those by hand to the 62 sections in Appendix A (scope_sections.tsv), dropping false friends (meat-inspection labels, a Japanese consul-general, blockades, naturalization certificates, military-mission agreements, the Panama separation of 1903, non-intervention sections that do not mention recognition).

**M1.3 Size.** `scope_docs.tsv` lists the documents of those 62 sections that are not front matter and not editorial notes: **1,667 documents in 38 volumes** (sum of Appendix A column n). The same 38 volumes hold 40,177 non-apparatus documents, so the field is 1,667 of 40,177 (4.1 percent) of them, and 1,667 of 312,169 (0.53 percent) of the whole series. SQL for the 38-volume denominator: `SELECT count(*) FROM document_cache WHERE volume_id IN (<the 38 ids of Appendix A>) AND is_front_matter=0 AND is_editorial_note=0;` = 40,177.

Existence and exclusion check for every pair (script scopedb.py and the loop in the log): `SELECT is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?`; no pair missing; none front matter or editorial note.

**M1.4 Second editions.** None of the 38 field volumes or 31 argument volumes ends in Ed2, so frus1951-54IranEd2 and frus1969-76ve15p2Ed2 are not involved; nothing needed suppressing.

**M1.5 Period basis.** Decades below use document_dates.date_iso (the index's per-document date). I did not read frus:doc-dateTime-min from the TEI and did not check how the index derives date_iso. I did not use the volume's series year.

## M2. What I measured

### M2.1 Controls and the false-friend test (script analysis.py; its output is analysis_out.txt and is pasted here)

```
SQL1: SELECT count(DISTINCT d.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '"department of state"' AND d.is_front_matter=0 AND d.is_editorial_note=0
positive control: volumes (of 553) with >=1 non-apparatus doc matching "department of state": 552
SQL2: SELECT count(*) FROM frus_documents WHERE frus_documents MATCH '"ZZZ_IMPOSSIBLE_ZZZ"'
negative control rows: 0
SQL: SELECT count(DISTINCT volume_id) FROM document_cache 553
FALSE-FRIEND TEST (regex, case-insensitive, over header+dateline+source_note+body collapsed; 38 scope volumes):
  recogni: scope docs 721 of 1667; other non-apparatus docs of the same 38 volumes 4062 of 38510
  de facto: scope docs 138 of 1667; other non-apparatus docs of the same 38 volumes 535 of 38510
  Department of State (control): scope docs 236 of 1667; other non-apparatus docs of the same 38 volumes 8830 of 38510
  ZZZ_IMPOSSIBLE_ZZZ (neg control): scope docs 0 of 1667; other non-apparatus docs of the same 38 volumes 0 of 38510
CENSUS over all scope docs (regex, case-insensitive): STRICT = single spaces; TOLERANT = any run of space/hyphen/comma/paren/full stop between words
  de facto: STRICT 138 of 1667; TOLERANT 138 of 1667
  free election(s): STRICT 23 of 1667; TOLERANT 23 of 1667
  constitutional government/order: STRICT 66 of 1667; TOLERANT 66 of 1667
  international obligations: STRICT 69 of 1667; TOLERANT 69 of 1667
  recognition (recogni*): STRICT 721 of 1667; TOLERANT 721 of 1667
  civil liberties: STRICT 1 of 1667; TOLERANT 1 of 1667
  consult(ation) with other governments: STRICT 79 of 1667; TOLERANT 137 of 1667
DECADE TABLE (document_dates.date_iso; non-apparatus docs):
  1890s: scope 50 of 9845 dated non-apparatus docs = 5.1 per 1,000; top volume frus1899 holds 46 of 50 (92%)
  1900s: scope 40 of 10261 dated non-apparatus docs = 3.9 per 1,000; top volume frus1900 holds 13 of 40 (32%)
  1910s: scope 534 of 30842 dated non-apparatus docs = 17.3 per 1,000; top volume frus1914 holds 119 of 534 (22%)
  1920s: scope 241 of 20374 dated non-apparatus docs = 11.8 per 1,000; top volume frus1920v03 holds 70 of 241 (29%)
  1930s: scope 314 of 40073 dated non-apparatus docs = 7.8 per 1,000; top volume frus1937v05 holds 111 of 314 (35%)
  1940s: scope 485 of 75872 dated non-apparatus docs = 6.4 per 1,000; top volume frus1944v07 holds 187 of 485 (39%)
  1950s: scope 3 of 43159 dated non-apparatus docs = 0.1 per 1,000; top volume frus1950v02 holds 3 of 3 (100%)
  scope docs without a date_iso: 0
```

Reading: the positive control ("department of state") is found in 552 of 553 volumes; the one volume without it is frus1919Parisv05 (89 documents; not a field volume). The negative control is found in 0 rows, and 0 of the 1667 field documents and 0 of 38,510 others.

False-friend test for the question's own term "recogni": it appears in 721 of 1,667 field documents (43.3 percent) against 4,062 of 38,510 other non-apparatus documents of the same 38 volumes (10.5 percent), about 4.1 times as often; the control phrase "Department of State" runs the other way, 236 of 1,667 (14.2 percent) against 8,830 of 38,510 (22.9 percent). So the term discriminates and is not just measuring the corpus. It is high in the field partly by construction, since the field is chosen by headings that name recognition; the comparison is a check, not a finding.

### M2.2 Phrase counts with their literal shares (script phrase_census.py; output phrase_census_out.txt, pasted)

```
CONTROL SQL (positive): SELECT count(DISTINCT d.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '"department of state"' AND d.is_front_matter=0 AND d.is_editorial_note=0
  volumes (of 553) with >=1 non-apparatus doc matching 'department of state': 552
CONTROL SQL (negative): SELECT count(*) FROM frus_documents WHERE frus_documents MATCH '"ZZZ_IMPOSSIBLE_ZZZ"'
  rows matching ZZZ_IMPOSSIBLE_ZZZ: 0
FAMILY: Estrada Doctrine | SQL: SELECT d.volume_id,d.document_id,d.header,d.dateline,d.source_note,d.body_text FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '"Estrada doctrine"' AND d.is_front_matter=0 AND d.is_editorial_note=0 ORDER BY d.volume_id,d.document_id
   TOLERANT MISS: frus1945v09/d55
  index hits (stem-level, non-apparatus): 28 documents in 18 volumes; literal-regex census of ALL 28: STRICT 27 of 28; TOLERANT 27 of 28
FAMILY: Tobar doctrine | SQL: SELECT d.volume_id,d.document_id,d.header,d.dateline,d.source_note,d.body_text FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '"Tobar doctrine"' AND d.is_front_matter=0 AND d.is_editorial_note=0 ORDER BY d.volume_id,d.document_id
  index hits (stem-level, non-apparatus): 1 documents in 1 volumes; literal-regex census of ALL 1: STRICT 1 of 1; TOLERANT 1 of 1
FAMILY: non-recognition | SQL: SELECT d.volume_id,d.document_id,d.header,d.dateline,d.source_note,d.body_text FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH 'nonrecognition OR "non-recognition"' AND d.is_front_matter=0 AND d.is_editorial_note=0 ORDER BY d.volume_id,d.document_id
  index hits (stem-level, non-apparatus): 701 documents in 219 volumes; literal-regex census of ALL 701: STRICT 698 of 701; TOLERANT 701 of 701
```

Each family is a census of every document the index returned (all under 300), re-tested by regular expression over header, dateline, source note and body collapsed to single spaces, case-insensitive. STRICT = the words with single spaces; TOLERANT = any run of space, hyphen, comma, parenthesis or full stop between the words (and inflections where stated). Published: **"Estrada Doctrine": 28 documents in 18 volumes (index), literal 27 of 28 strict, 27 of 28 tolerant**; the one miss is frus1945v09/d55, a true instance with the name in quotation marks ("Estrada" doctrine), which my tolerant pattern does not allow. **"Tobar doctrine": 1 document, literal 1 of 1 strict and tolerant** (frus1932v05/d546; the editors' note there defines it as Tobar's 1907 call for non-recognition of governments sprung from revolutions against the constitution). A 1.000 share tests the stemmer, not the referent: all 28 and the 1 were read in their context to see that they name the doctrines. The third family in the file (non-recognition, 701 documents in 219 volumes, 698 of 701 strict, 701 of 701 tolerant) is corpus-wide and mostly non-Latin American, and I publish no figure from it. A first run of this script put a defective "recognition of the de facto government" family and a defective tolerant pattern in the log; both were removed and the script was re-run (the log keeps both runs).

### M2.3 Census inside the field (analysis_out.txt)

Of the 1667 field documents, STRICT / TOLERANT: "de facto" 138 / 138; "free election(s)" 23 / 23; "constitutional government/order/methods/procedures/processes" 66 / 66; "international obligation(s)" 69 / 69; "civil liberties" 1 / 1; a form of "consult" 79 / 137 (strict is "consultation"). These are censuses of the field, not samples, so no sampled share is needed; they were used to decide what to read, and none appears as a figure in the overview.

### M2.4 Decade shape of the field (analysis_out.txt, DECADE TABLE)

Raw count, per 1,000 of that decade's dated non-apparatus documents, and the top volume's share of the numerator (periodised on document_dates.date_iso): 1890s 50 (5.1 per 1,000; frus1899 holds 46 of 50, 92 percent); 1900s 40 (3.9; frus1900 13 of 40, 32 percent); 1910s 534 (17.3; frus1914 119 of 534, 22 percent); 1920s 241 (11.8; frus1920v03 70 of 241, 29 percent); 1930s 314 (7.8; frus1937v05 111 of 314, 35 percent); 1940s 485 (6.4; frus1944v07 187 of 485, 39 percent); 1950s 3 (0.1; frus1950v02 3 of 3). The 1890s rate is one volume (Venezuela, 1899); the 1950s figure reflects only that the editors' headings stop naming recognition, not a fall in cases. The overview uses no decade rate.

## M3. The archival scope

### M3.1 CAME-FROM channel, over the field (1667 documents, 38 volumes) [index: document_sources]

SQL (as logged): `select count(*), sum(ds.decimal_class is not null), sum(ds.citation_era='decimal') from scope s join m.document_sources ds on ds.volume_id=s.volume_id and ds.document_id=s.document_id` with scope.db holding the field and the index attached read-only as m.

- Field documents with a source row: **1578 of 1667**; without: 89 (the 79 documents of 1895 to 1904 in the field have no source row, nor do 10 later ones).
- Source is Department of State, Record Group 59: **1570 of 1667** (94.2 percent).
- Of those, decimal-era file numbers on documents dated 1910-08 or later: **1559 of 1667** (93.5 percent, about fifteen in sixteen), dated 1911-01-01 to 1950-06-01; 14 of the 1559 carry no parsed decimal class. Another **10** documents, all frus1907p2 (Honduras, 1907), cite the older numerical file (File No. 3691/485, 6775/52, 7357/2 and so on). One carries a lot-file source (frus1948v09/d115, whose lot_file_norm reads NO, a parse artefact for "Lot No. 64-D-563").
- By country number (class 8, internal affairs of states; gloss from decimal-class-labels.json schedule 1910-1949, applied only because every one of these documents is dated 1910 to 1949 and the gate `coverage.glossableYears` covers it): 38 Haiti 233; 24 Bolivia 197; 16 El Salvador 185; 18 Costa Rica 106; 12 Mexico 83; 35 Argentine Republic/ Argentina 80; 17 Nicaragua 79; 39 Dominican Republic 68. Haiti (233) exceeds Bolivia (197) by 36.
- The country-and-class counts came from `decimal_gloss.py` (first version mis-parsed the country digits and was discarded) and the corrected query logged as `select substr(ds.decimal_class,1,1) cls, substr(ds.decimal_class,2,2) country, count(*) ...`.
- Series naming: collection-authority.json holds `txt:department of state|central decimal file 1910-1929`, record group 59, with no NAID; no bundled table gives the Central Decimal File an identifier, entry number, extent or access status. UNRESOLVED OFFLINE, said so in the overview.

Volume-level, JSON (usage_scope.py; **volume-scoped, all source notes of the 38 volumes, not only field documents**): collection-usage-index.json counts 33,554 notes in the category centralDecimalFile, 174 previouslyPublished, 95 namedFileSeries, 73 unrecognized, 19 lotFile and 8 presidentialLibrary across the 38 volumes, and 16 authority collections (114 notes), the largest 84 for "IO Files". It adds nothing to the field-level picture and is not used in the overview.

### M3.2 POINTED-AT channel, over the field [index: external_citations]

SQL (logged): `select count(distinct e.volume_id||'/'||e.document_id), count(*), min(s.volume_id), max(s.volume_id) from scope s join m.external_citations e on e.volume_id=s.volume_id and e.document_id=s.document_id` gives 56 | 65 | frus1921v01 | frus1950v02. All 65 have anchor `centralFileClass` (query `select e.anchor, count(*) ... group by 1`); none is a lot file or a library anchor. **56 of 1667 field documents** (3.4 percent, about one in thirty) have such a citation. Earliest dated document with one: 1921-01-28. Most cited classes (`select e.decimal_class, count(*) ... group by 1 order by 2 desc`): 817.00 (11 citations, 2 volumes), 824.00 (7, 4 volumes), 816.01 (6, 4 volumes), then 814.00 (3), 816.00 (3), 817.51 (3), 838.01 (3). By the stated limits of this channel: it has no row before 1910-12-06, stores the citation fragment, and holds lot, library and decimal anchors only.

Volume-level, JSON (extcit_scope.py; **volume-scoped, all footnotes of the 38 volumes; 30 of the 38 are in the index's volume list**): 1,079 citations to central-file classes in 465 classes; lot or library targets: 12 citations of 7 targets (lots 53 D 250, 60 D 137, 53 D 26, 53 D 444, 56 D 625, 66 D 95 and Hyde Park). The database query `select ... from m.external_citations e where e.lot_file_norm in ('53D26','53D444','53D250','60D137','66D95','56D625') and e.volume_id in (select distinct volume_id from scope)` places every one of them in frus1950v02 (documents d359, d460, d329, d335, d148, d120, d377, d402, d409, d128), a volume that is in the field only through three Haiti documents; none is a recognition source, so the overview calls them "other subjects". Lot 56 D 625 is the Office of Chinese Affairs: a creator heading that is a decoy for this topic. The two channels are two numbers over different scopes and are never summed.

### M3.3 What the bundled JSON resolves [JSON]

- **Lot 64 D 563.** central-files-index.json lotFiles row: lotNumber 64D563, naId 1136548, "Chronological Files", hmsMlrEntryNumbers A1 558-D, recordGroup 59, matchType control. series-facts-index.json (byNaId, decoded through its legend): creator "Department of State. Policy Planning Council." (a later body: the creator heading is NARA's and I did not verify it), accessStatus Unrestricted, useStatus Unrestricted, extent 5 linear feet 3 inches, 1947 to 1962. lot-claimants-index.json lists **12 claimant series** for the lot (A1 558-A Numbered Staff Studies naId 1151288, 1947-1949; -B Subject Files 1151314; -CA Country Files 1151315; -CB Area Files 7432703; -D Chronological Files 1136548; -E Record Copies Files 1151881; -F Member Chronological Files 1154560; -G Working Papers 1154562; -H Meeting Minutes 1154583; -I Notes of Meetings 7433609; -J Records Relating to Meetings with the Department of Defense and the Joint Chiefs of Staff 7433611; -L Speeches and Articles 7433905). Series 1151288: creator Policy Planning Staff, Unrestricted, 1 linear foot 9 inches, 1947-1949. That the PPS paper sits in 1151288 is **my inference from its being a numbered paper (PPS/47)**; the data does not say which of the twelve holds it.
- **Numerical file (pre-1910).** central-files-index.json numericalFile: microfilm M862, seriesNaId 654171, 1,261 reels; the reels holding the cited cases: 3691/485 in 'Numerical File: 3691/400-End of case' (19503073); 6775/52 in 'Numerical File: 6747-6775/80' (19748403); 7357 items 1 to 215 in 'Numerical File: 7357-7357/215' (19794147 and 19792913). series-facts-index has no row for 654171: extent, dates and access UNRESOLVED.
- **Presidential libraries.** presidential-library-catalog.json: Johnson Library LBJ-NSF naId 567979 "National Security Files"; Nixon RN-NSF naId 572235 "National Security Files (Nixon Administration)" (the footnotes cite "NSC Files"; I take them to be the same, flagged as an inference); Kennedy Library JFK-4 naId 1164 "National Security Files" (not cited by a field or argument document); Eisenhower Library: no title containing "Clean" (the cited "Project Clean Up Records" is UNRESOLVED). Access status is not carried by that catalog.
- **Subject-numeric file.** subject-numeric-labels.json, schedule 1963: subjects POL 16 = "INDEPENDENCE. RECOGNITION." (category POL = Political Affairs & Relations; area DOM REP = Dominican Republic); schedule 1964-1973: POL 16 has no label. So only frus1961-63v12/d363 (dated 1963, "POL 16 DOM REP") is glossed; the 1964 to 1966 files ("POL 16 ARG") are not, by the file's own gate (`keyOutsideGlossableYears: no-gloss`).
- **Central Foreign Policy File (1973 on)** and **the subject-numeric file as a series:** named in collection-authority.json and volume-sources-index.json text entries; no identifier. UNRESOLVED OFFLINE.
- **Reach before 1940.** series-facts-index.json byNaId holds 698 series; 11 have an inclusive start year before 1940; 1 ends before 1940. (The briefing said 11 of 695; I measured 11 of 698.)
- Not used: accession-series-index.json (its Central Foreign Policy and Subject-Numeric entries are Record Group 286, the Agency for International Development), lot-claimants for other lots, curated-lot-resolutions.json (no row for any lot here).

### M3.4 Decimal class gate

decimal-class-labels.json: glossableYears 1910-1949, 1950-1959, 1960-1963; renumbered at 1950; keys outside those years have no gloss. Every field document I glossed (country numbers in M3.1) is dated 1911 to 1949 and is glossed under the 1910-1949 schedule (country 38 = Haiti, 24 = Bolivia, 16 = El Salvador, 18 = Costa Rica, 12 = Mexico, 35 = Argentine Republic/Argentina, 17 = Nicaragua, 39 = Dominican Republic, 23 = Peru, 34 = Paraguay, 22 = Ecuador, 14 = Guatemala, 31 = Venezuela, 37 = Cuba, 15 = Honduras, 32 = Brazil). The three Haiti documents of 1950 (frus1950v02) are outside this schedule and I did not gloss them.

## M4. Things searched for and not found (with controls)

- **Resumption of relations with Peru's junta, August 1962.** `find.py '("resumption" OR "resume" OR "resumed") AND relations AND Peru AND (junta OR Pérez OR Godoy OR Lindley)'` over frus1961-63v12 returned the Peru papers d421, d427, d423 and d424; the same with "recognized" over frus1961-63v10-12mSupp returned d109, d102 and d105 (not about Peru's junta); a further search over v12 for resumption in August returned d421, d424 and two unrelated papers (d148, d29). d421, d423, d424 and d427 were read; none records the act. Positive control: the same query form returns the Peru papers, so it can return rows. Not a research negative: the shelf is the Department's file 723.00 (the cited file numbers are 723.00/7-3062 and 723.00/8-1662).
- **Latin American governments' own reasoning.** M2.2: the doctrines appear only inside Department reports.
- **Unsearched:** 1861 to 1876; 1981 onward (the frus1981-88 volumes are in the index and were not read); the Eastern-hemisphere cases.
- **Post-1950 cases read (eleven):** Guatemala 1954 (frus1952-54v04/d490), Cuba 1959 (frus1958-60v06/d217), Peru 1962 (frus1961-63v12/d421, d423, d427), Honduras 1963 (frus1961-63v10-12mSupp/d160), Dominican Republic 1963 (frus1961-63v12/d363), Brazil 1964 (frus1964-68v31/d206), Argentina 1966 (d135, d141), Peru 1968 (d515), Chile 1973 (frus1969-76v21/d358, d360), Bolivia 1978 (frus1977-80v24/d132), Nicaragua 1979 (frus1977-80v15/d276). Volume patterns searched for them: frus1952-54v04, frus1958-60v06, frus1961-63v12, frus1961-63v10-12mSupp, frus1964-68v3%, frus1969-76ve1%, frus1969-76v21, frus1977-80v%, frus1977-80v15, frus1977-80v24 (find.py lines in queries.log). Panama 1968, Argentina 1962 and 1976, Bolivia 1964, 1971 and 1980, Ecuador 1963, Guatemala 1963 and Uruguay 1973 were NOT searched and are not claimed absent.
- **Thin results.** The post-1950 part of the argument is eleven cases read from a search, not a census; the field (1895 to 1950) is thin in the 1950s by construction (M2.4). The index holds the whole series, so none of this is a partial-library effect, but the series is itself a selection.

## M5. Quotations (each verbatim, each verified against its document)

Verification SELECT for every row: `SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?`, then the test `quote in body_text` (exact, raw) in `quotes.py`. Result: **53 of 53 verified raw** (all 53 also verify after whitespace collapse). The retrieving SELECT for reading is the one in show.py / ctx.py: `SELECT header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?`. Rows marked O are used in the overview and as excerpts in the collection (18); the others are verified and kept on file.

| id | pair | in overview | quotation |
|---|---|---|---|
| Q01 | frus1889/d43 | O | so soon as a majority of the people of Brazil should have signified their assent to the establishment and maintenance of the Republic he was to give it, on behalf of the United States, a formal and cordial recognition. |
| Q02 | frus1895p1/d246 |  | the practice of this Government has been to enter into effective relations with the de facto government when it shall have been fully established with the general consent of the people. |
| Q03 | frus1900/d530 | O | to base the recognition of a foreign government solely on its de facto ability to hold the reins of administrative power |
| Q04 | frus1900/d530 |  | it is in a position to fulfill all the international obligations and responsibilities incumbent upon a sovereign state under treaties and international law |
| Q05 | frus1913/d7 |  | Cooperation is possible only when supported at every turn by the orderly processes of just government based upon law, not upon arbitrary or irregular force. |
| Q06 | frus1913/d1028 |  | The consent of General Huerta to bind himself not to be a candidate for election as President of the Republic at this election |
| Q07 | frus1915/d987 |  | It is a question of fact as to whether they are in power. If they are in power then we can only consider them for recognition. |
| Q08 | frus1916/d258 |  | The withholding of the funds by the United States Government, on account of the fact that recognition has not been granted to Henríquez, has brought an economic crisis in the country |
| Q09 | frus1917/d379 | O | no Government except such as may be elected legally and established according to the Constitution shall be considered entitled to recognition |
| Q10 | frus1920v01/d377 |  | the Government of the United States has not as yet recognized the revolutionary Government as being even a de facto government |
| Q11 | frus1920v01/d391 |  | The two Governments believe it advisable to wait until a government has been formed as a result of the elections in accordance with the Constitution before recognizing it. |
| Q12 | frus1920v01/d399 | O | the President has determined to recognize the Government of Bolivia, as soon as a provisional President is elected, as the de facto Government of Bolivia |
| Q13 | frus1921v02/d344 | O | when it appears that there is a government in Mexico willing to bind itself to the discharge of primary international obligations, concurrently with that act its recognition will take place. |
| Q14 | frus1923v02/d484 |  | It seems to be advisable that we should agree upon a day on which the resumption of diplomatic relations should be formally announced. |
| Q15 | frus1923v02/d345 | O | will not recognize any other Government which may come into power in any of the five Republics through a coup d’état or a revolution against a recognized Government, so long as the freely elected representatives of the people thereof have not constitutionally reorganized the country. |
| Q16 | frus1930v01/d375 | O | the evidence has satisfied me that these provisional governments are de facto in control of their respective countries, and that there is no active resistance to their rule. |
| Q17 | frus1930v01/d375 |  | Each of the present governments has also made it clear that it is its intention to fulfill its respective international obligations and to hold, in due course, elections to regularize its status. |
| Q18 | frus1932v05/d618 |  | Martínez can under no circumstances be recognized. This is not due to any animus against Martínez, but because of the clear provisions of the Treaty. |
| Q19 | frus1932v05/d641 |  | it was obvious that if the British Government should grant recognition to Martínez it would have the effect of encouraging him to stay on in power |
| Q20 | frus1933v05/d508 |  | We have maintained that the criteria of Cuban recognition are: (1) popular support, and (2) ability to maintain law and order and carry on the functions incumbent upon any stable government. |
| Q21 | frus1934v05/d255 |  | the Government of the United States should cooperate with them in that effort |
| Q22 | frus1936v05/d109 | O | Under our new policy, if General Somoza headed a régime which effectively governed the country and fulfilled its international obligations we would extend recognition to him regardless of his eligibility to recognition under the 1923 Treaty. |
| Q23 | frus1943v05/d334 | O | In order that all the American governments may arrive at a common decision and take simultaneous action it is obviously necessary that there be the fullest exchange of information and consultation between the several governments |
| Q24 | frus1943v05/d340 |  | has the hope and belief that Argentina will collaborate in the same spirit and measure as the other American republics for the fulfillment of inter-American solidarity in all its aspects |
| Q25 | frus1943v05/d486 |  | Included in the relevant considerations is the question whether outside influence unfriendly to the Allied cause played any part. |
| Q26 | frus1944v07/d219 |  | In all matters relating to the security and defense of the Hemisphere, we must look to the substance rather than the form. |
| Q27 | frus1944v07/d231 | O | it is almost incredible that any American regime should expect recognition and the advantages of membership in the American family of nations without sincerely contributing to this common effort |
| Q28 | frus1944v07/d429 | O | The present Bolivian Government has shown, by its acts, to be sympathetic to the Allied cause. |
| Q29 | frus1944v07/d437 |  | this Government is also willing to recognize on June 23 if it is the consensus on the part of the Governments of the American nations |
| Q30 | frus1945v09/d70 |  | The Department hopes that the general adoption of the Estrada doctrine will not be pressed in as much as it doubts that the doctrine is a desirable basis for our recognition policy |
| Q31 | frus1948v09/d7 | O | (a) de facto control of the territory and the administrative machinery of State, including the maintenance of public order; (b) the ability and willingness of a government to discharge its international obligations; (c) general acquiescence of the people of a country in the government in power. |
| Q32 | frus1948v09/d89 |  | In the absence of any compelling reason to the contrary, it is desirable for the United States to maintain diplomatic relations with all Latin American governments. |
| Q33 | frus1948v09/d115 | O | Recognition should not be withheld as a political weapon or to express moral censure except in extreme cases when U.S. national interests would be served thereby. |
| Q34 | frus1948v09/d119 |  | non-recognition is not a suitable approach to much broader problem of dictatorships and use of force as a political procedure |
| Q35 | frus1949v02/d457 |  | Delay in resuming relations might affect domestic prestige of the de facto government sufficiently to encourage it to adopt more representative procedures and democratic practices in order to win United States “approval” by recognition and add to its prestige and political strength. |
| Q36 | frus1952-54v04/d490 |  | one of criteria for recognition is that new government be in control of territory of the country |
| Q37 | frus1958-60v06/d217 | O | I believe that the statements of intention of the new government have been made in good faith and that it is in our national interest to recognize the Provisional Government of Cuba without delay. |
| Q38 | frus1961-63v12/d421 |  | It is of great importance to have the junta reaffirm, publicly and with emphasis, its intention to hold free elections so that any temptation to continue to enjoy the fruits of power may be discouraged. |
| Q39 | frus1961-63v12/d423 | O | Guarantee of free and fair elections, preferably before June 9 but at no later date, with full rights to all parties under Constitution, and with guarantee that Armed Forces will respect results those elections. |
| Q40 | frus1961-63v12/d423 |  | our view is not to insist on this as sine qua non of recognition |
| Q41 | frus1961-63v12/d363 |  | In cases both countries our principal objective in withholding recognition has been return at earliest possible date constitutionally elected government. |
| Q42 | frus1964-68v31/d135 | O | we should seek the usual assurances regarding acceptance of international obligations, as well as respect for civil liberties and an early return to constitutional government, before recognizing |
| Q43 | frus1964-68v31/d141 |  | We also indicated informally to the Argentine authorities that public statements on the points contained in Resolution XXVI, plus a commitment on peaceful settlement of disputes, would facilitate recognition by the United States. |
| Q44 | frus1964-68v31/d206 |  | there would be no problem of U.S. recognition of the new government because we would merely continue our relations with the President |
| Q45 | frus1964-68v31/d515 |  | None of the Latin governments, except Venezuela, is disposed to insist on a commitment to hold elections as a pre-condition for recognition. |
| Q46 | frus1969-76v21/d360 |  | I told Huerta that we shall respond affirmatively to the Junta’s note, and expect to do so within the next few days. |
| Q47 | frus1977-80v24/d132 |  | We do not repeat not want to legitimize the interruption of the process of democratic political development. |
| Q49 | frus1961-63v10-12mSupp/d160 |  | Problem of eventual recognition Honduras and restoration of normal relations including military and economic aid tied to earliest possible establishment or restoration of Honduran constitutional government. |
| Q50 | frus1877/d222 | O | In the present case it waits before recognizing General Diaz as the President of Mexico until it shall be assured that his election is approved by the Mexican people, and that his administration is possessed of stability to endure and of disposition to comply with the rules of international comity and the obligations of treaties. |
| Q51 | frus1878/d344 |  | the Government of the United States before recognizing General Diaz as the President of Mexico waited to be assured that his administration was approved by the Mexican people, and was possessed of due stability and animated by a disposition to comply with the rules of international comity and the obligations of treaties |
| Q52 | frus1961-63v12/d427 |  | In taking this public position we hoped to demonstrate to the hemisphere our firm support of democratic, constitutional process and to provide a deterrent to potential military coups against democratic, constitutional regimes elsewhere in the hemisphere. |
| Q53 | frus1913/d1064 |  | justified both Governments in withholding their recognition of the Huerta Government |
| Q48 | frus1977-80v15/d276 | O | recognition as such does not arise in our international practice. U.S. practice now (in a kind of Estrada doctrine) is to recognize nations, not governments. We simply continue relations when a new government comes in. |

Q45 comes from an editors' footnote (the editors quote Rostow's covering memorandum) inside the body_text of frus1964-68v31/d515; body_text includes footnotes. Q48 and Q46 are in the body of the telegrams. Q15 is the text of Article II as Hughes quoted it.

## M6. Reading accounting

Documents retrieved whole (captured text length equals length(body_text) in characters; `ledger.py`, table reading_ledger.tsv): **56 of 56**. Read end to end on screen: **44**; read in part (windows around matches, or the first part, or head and tail): **12** (frus1877/d222, frus1913/d1028, frus1913/d1064, frus1915/d987, frus1923v02/d345, frus1944v07/d388, frus1945v09/d70, frus1948v09/d7, frus1952-54v04/d490, frus1961-63v12/d427, frus1964-68v31/d141, frus1977-80v15/d276). Quoted in the overview: **18** documents (18 quotations); quotations verified in all: 53. The raw text of every document is in the run's texts/ folder, one file per pair; the reading SELECT and the regular expressions used for windows are logged by ctx.py, show.py and sec.py in queries.log.

Characters, not bytes: length(body_text) counts characters; the captured files are compared in characters (Python len on the decoded text), not with wc -c.

## M7. TRACE TABLE (one row per number and per quotation in the overview)

| # | in the overview | value | memo line | source |
|---|---|---|---|---|
| T1 | "fifty-six documents in 31 volumes" | 56 documents; 31 volumes | M1.1, Appendix B | final_docs.py; `final_docs.py` existence check |
| T2 | "about seventeen hundred documents ... in 38 volumes" | 1667 of 312,169 non-apparatus documents; 38 of 553 volumes | M1.3 | scope_docs.tsv; SQL in M1.3 |
| T3 | "1877 to 1950", "up to 1979", "1895 to 1950" | argument dated 1877-05-16 to 1979-07-15; field 1895-09-06 to 1950-06-01 | M1.1, Appendix B | datelines; analysis.py date query |
| T4 | "a field of 62 sections" | 62 | Appendix A | scope_sections.tsv |
| T5 | "553 volumes, 312,169 documents" | 553; 312,169 | M0 | coverage SQL; `SELECT count(*), sum(is_front_matter=0 AND is_editorial_note=0)` |
| T6 | "About fifteen in sixteen" cite the central decimal file | 1559 of 1667 (93.5 percent) | M3.1 | document_sources join |
| T7 | "Haiti, Bolivia, El Salvador, Costa Rica and Mexico" | 233, 197, 185, 106, 83 documents | M3.1 | decimal-class country query |
| T8 | "dates from 1911 into 1950" | 1911-01-01 to 1950-06-01 | M3.1 | document_dates join |
| T9 | "Ten papers of 1907 ... M862 ... 654171 ... case 7357 ... 19794147 and 19792913" | 10; M862; 654171; reels as listed | M3.1, M3.3 | document_sources; central-files-index.numericalFile |
| T10 | "Papers before 1907 in the field carry no file number" | 79 of 79 documents of 1895 to 1904 lack a source row | M3.1 | left join document_sources |
| T11 | "twelve series, 1947 to 1962, A1 558-A through A1 558-L" | 12 | M3.3 | lot-claimants-index.json |
| T12 | "1151288, 1947 to 1949, unrestricted"; "1136548, A1 558-D, 1947 to 1962, unrestricted" | as stated | M3.3 | series-facts-index.json; central-files-index.json |
| T13 | "567979"; "572235" | as stated | M3.3 | presidential-library-catalog.json |
| T14 | "Only 11 of the 698 series ... before 1940" | 11 of 698 | M3.3 | series-facts-index.json byNaId y0 |
| T15 | "about one document in thirty"; "none is earlier than 1921" | 56 of 1667 (3.4 percent); earliest 1921-01-28 | M3.2 | external_citations join |
| T16 | "Nicaragua (817.00), Bolivia (824.00) and El Salvador (816.01)" | 11, 7, 6 citations | M3.2 | external_citations group by decimal_class |
| T17 | "about eleven hundred citations ... some 465 classes ... a dozen citations to lot files and one library" | 1,079 in 465 classes; 12 citations of 7 targets | M3.2 | extcit_scope.py |
| T18 | "read eleven cases" | 11 | M4 | list in M4 |
| T19 | "28 documents in 18 volumes and in 1 document" | 28 / 18; 1 | M2.2 | phrase_census_out.txt |
| T20 | "552 of 553 volumes" | 552 | M2.1 | positive-control SQL |
| T21 | "Haiti alone supplies more papers" | 233 > 197 | M3.1 | country query |
| T22 | "1861 to 1876, and everything after 1980" unsearched | statement of omission | M4 | no query |
| T23 | dates and attributions in the findings paragraphs | datelines of the cited documents | Appendix B | document_cache.dateline |
| TQ50 | quotation, finding 1 | pair frus1877/d222 | M5 row Q50 | verification SELECT in M5 |
| TQ01 | quotation, finding 1 | pair frus1889/d43 | M5 row Q01 | verification SELECT in M5 |
| TQ03 | quotation, finding 1 | pair frus1900/d530 | M5 row Q03 | verification SELECT in M5 |
| TQ09 | quotation, finding 2 | pair frus1917/d379 | M5 row Q09 | verification SELECT in M5 |
| TQ12 | quotation, finding 2 | pair frus1920v01/d399 | M5 row Q12 | verification SELECT in M5 |
| TQ13 | quotation, finding 2 | pair frus1921v02/d344 | M5 row Q13 | verification SELECT in M5 |
| TQ15 | quotation, finding 3 | pair frus1923v02/d345 | M5 row Q15 | verification SELECT in M5 |
| TQ16 | quotation, finding 3 | pair frus1930v01/d375 | M5 row Q16 | verification SELECT in M5 |
| TQ22 | quotation, finding 3 | pair frus1936v05/d109 | M5 row Q22 | verification SELECT in M5 |
| TQ23 | quotation, finding 4 | pair frus1943v05/d334 | M5 row Q23 | verification SELECT in M5 |
| TQ27 | quotation, finding 4 | pair frus1944v07/d231 | M5 row Q27 | verification SELECT in M5 |
| TQ28 | quotation, finding 4 | pair frus1944v07/d429 | M5 row Q28 | verification SELECT in M5 |
| TQ31 | quotation, finding 5 | pair frus1948v09/d7 | M5 row Q31 | verification SELECT in M5 |
| TQ33 | quotation, finding 5 | pair frus1948v09/d115 | M5 row Q33 | verification SELECT in M5 |
| TQ37 | quotation, finding 5 | pair frus1958-60v06/d217 | M5 row Q37 | verification SELECT in M5 |
| TQ39 | quotation, finding 6 | pair frus1961-63v12/d423 | M5 row Q39 | verification SELECT in M5 |
| TQ42 | quotation, finding 6 | pair frus1964-68v31/d135 | M5 row Q42 | verification SELECT in M5 |
| TQ48 | quotation, finding 6 | pair frus1977-80v15/d276 | M5 row Q48 | verification SELECT in M5 |

## M8. Flags, errors, and how to read the thin parts

- The overview's three-paragraph opening, its two lists and the archival counts were written from M3. The two channels (came-from; pointed-at) are never summed.
- **Inferences flagged:** that PPS/47 sits in series 1151288; that the Nixon "NSC Files" are the catalog's National Security Files; that the Honduras 1907 numbered cases map to the reels named. **Creator headings:** series-facts creators for 1136548 ("Policy Planning Council") and for lot 56 D 625 are NARA's; not verified.
- **Errors in my own passes (kept in the log):** analysis.py's first run printed two ERR lines (the controls, tried through an attached database, failed with `no such column`); I re-ran the controls on a plain connection (M2.1). phrase_census.py's first run included a badly framed AND family and a tolerant pattern that was narrower than the strict one; both were fixed (M2.2). decimal_gloss.py's first version took the first two digits as the country and glossed Haiti as Egypt; discarded. chapters.db (a rowid-order chapter map) was abandoned because older volumes list chapter headings after their documents; struct.db from volume_structures replaced it.
- **Date-order and the Peru, Argentina, Honduras and Dominican cases:** the collection puts Honduras (Oct 1963) before the December 1963 reversal; the printed volume prints the Honduran coup documents in a microfiche supplement, cited as the Microfiche Supplement.
- **Not claimed:** I do not claim the field is complete for 1895 to 1950 (it is the set of sections I judged to name recognition of a government that took power irregularly) nor that no other recognition decision exists in the series.

## Appendix A. The 62 sections of the field

| volume | section | documents in section | in field (non-apparatus) | editors' heading path |
|---|---|---|---|---|
| frus1895p1 | ch41 | 4 | 4 | Ecuador > Recognition of de facto government |
| frus1899 | ch123 | 46 | 46 | Venezuela > Revolution in Venezuela and recognition of de facto government |
| frus1900 | ch33 | 9 | 9 | Colombia > Recognition of new Government of Colombia |
| frus1900 | ch36 | 4 | 4 | Dominican Republic > Recognition of new Government |
| frus1903 | ch45 | 4 | 4 | Dominican Republic > Revolution in Santo Domingo, and recognition of new Government |
| frus1903 | ch71 | 5 | 5 | Guatemala and Honduras > Revolution in Honduras, and recognition of new Government |
| frus1904 | ch55 | 7 | 7 | Dominican Republic > Recognition of the provisional government of the Dominican Republic |
| frus1907p2 | ch5 | 11 | 11 | Guatemala and Honduras > Recognition of the provisional Government of Honduras by the United States and Mexico |
| frus1911 | ch69 | 37 | 37 | Haiti: > Revolution in Haiti—Recognition by the United States of the Leconte Government—Temporary refuge offered President Simon |
| frus1911 | ch89 | 41 | 41 | Nicaragua: > Political affairs: Recognition of Provisional President Estrada by the United States; proclamation of a constitution by the constitutiona |
| frus1912 | ch58 | 4 | 4 | Haiti: > Death of President Leconte and recognition by the United States of President Auguste |
| frus1912 | ch97 | 25 | 25 | Paraguay: > Political affairs: insurrection of February–March, 1911; coup d’état of July, 1911; various insurrections November 1911 to May 1912; presi |
| frus1913 | ch47 | 1 | 1 | Ecuador: > Recognition of President Plaza by the United States |
| frus1914 | ch124 | 19 | 19 | Peru: > Political affairs: Revolution; resignation of President Billinghurst; recognition by the United States of the Government Junta and of the Prov |
| frus1914 | ch80 | 100 | 100 | Haiti: > Political and financial affairs:—revolution, with Dominican aid; measures taken by the United States to restore order; resignation of Preside |
| frus1915 | ch62 | 92 | 92 | Haiti: > Political affairs; revolutionary movements; escape of President Theodore; election of President Vilbrun Guillaume Sam. Commission sent to Hai |
| frus1916 | ch34 | 69 | 69 | Dominican Republic: > Political affairs. Revolutionary movements. Resignation of President Jiménez. Election of Provisional President Henríquez; refus |
| frus1917 | ch21 | 66 | 66 | Costa Rica: > Political affairs. Revolution; overthrow of President Alfredo Gonzáles by the Minister of War, Federico Tinoco. Refusal of the United St |
| frus1919v01 | ch37subch2 | 38 | 38 | Costa Rica: > Political affairs > Surrender of power by the Tinocos: assassination of Joaquín; departure of Federico, August 12—Succession of Juan B.  |
| frus1919v02 | ch69subch1 | 39 | 39 | Peru: > Political affairs > Presumptive election of Augusto B. Leguía as President—Overthrow of President Pardo, July 4, 1919; assumption of power by  |
| frus1920v01 | ch21subch1 | 31 | 31 | Bolivia: > Political affairs > Coup d’état by the Republican Party, July 12, 1920—Attitude of the United States; understandings with Argentina and Bra |
| frus1920v01 | ch39 | 4 | 4 | Costa Rica: > Recognition of the Government of Costa Rica by the United States |
| frus1920v03 | ch9subch1 | 67 | 67 | Mexico: > Question of the recognition of the Provisional Government by the United States > Informal conversations in Washington between the Under Secr |
| frus1920v03 | ch23 | 6 | 6 | Peru: > Recognition of the Leguia government by the United States |
| frus1921v01 | ch15 | 16 | 16 | Bolivia: > Recognition of the Saavedra Government by the United States |
| frus1921v02 | ch38 | 14 | 14 | Mexico: > Question of the recognition of the Government of General Obregon by the United States: Proposed Treaty of Amity and Commerce; objection by t |
| frus1921v02 | ch39 | 24 | 24 | Mexico: > Attitude of other governments toward recognition of the Obregon Government |
| frus1922v02 | ch32 | 7 | 7 | Guatemala: > Recognition of the Orellana government by the United States |
| frus1922v02 | ch50 | 12 | 12 | Mexico: > Question of the recognition of the government of General Obregon by the United States |
| frus1922v02 | ch51 | 7 | 7 | Mexico: > Attitude of other governments toward recognition of the Obregon government |
| frus1923v02 | ch37 | 24 | 24 | Mexico: > Recognition of the Government of General Obregón by the United States and the resumption of diplomatic relations |
| frus1924v02 | ch22 | 22 | 22 | Honduras: > Efforts by the United States and the Central American republics to reestablish constitutional government in Honduras |
| frus1925v02 | ch7 | 4 | 4 | Ecuador: > Withholding of recognition by the United States of the revolutionary government in Ecuador |
| frus1925v02 | ch33 | 4 | 4 | Honduras: > Inauguration of the new constitutional government in Honduras and the resumption of formal relations with the United States |
| frus1928v02 | ch53 | 2 | 2 | Ecuador: > Extension by the United States of de jure recognition to the Government of Ecuador |
| frus1931v02 | ch31 | 24 | 24 | Guatemala: > Recognition of constitutional government in Guatemala |
| frus1932v05 | ch14 | 68 | 68 | El Salvador: > Refusal of the United States to recognize the Martínez regime in El Salvador |
| frus1933v05 | ch15 | 10 | 10 | El Salvador: > Refusal of the United States to recognize the Martínez regime in El Salvador |
| frus1934v05 | ch5 | 31 | 31 | Cuba: > Recognition of the Provisional Government of Cuba |
| frus1934v05 | ch13 | 62 | 62 | El Salvador: > Recognition of the Martínez Government of El Salvador by Guatemala, Honduras, and Nicaragua, and by the United States |
| frus1936v05 | ch5 | 8 | 8 | General: > Decision of the Department of State that the United States should no longer be guided by article II of the General Treaty of Peace and Amit |
| frus1937v05 | ch14 | 33 | 33 | Bolivia: > Revolution in Bolivia; recognition of the Busch Government |
| frus1937v05 | ch17 | 8 | 8 | Brazil: > Abrogation of Brazilian constitution and promulgation of a new one continuing President Vargas in office; continuance of diplomatic relation |
| frus1937v05 | ch28 | 20 | 20 | Ecuador: > Forced resignation of President Paez of Ecuador; recognition of the Enriquez Government |
| frus1937v05 | ch43 | 50 | 50 | Paraguay: > Revolution in Paraguay; recognition of the Paiva Government |
| frus1940v05 | ch37 | 7 | 7 | Cuba: > Refusal of the United States to indicate whether it would or would not recognize a future government of Cuba |
| frus1943v05 | ch11 | 17 | 17 | Argentina: > Discussions leading to the recognition of the Government of General Pedro P. Ramirez |
| frus1943v05 | ch18 | 9 | 9 | Bolivia: > Non-recognition by the United States of the revolutionary regime established in Bolivia by the Movimiento Nacionalista Revolucionario |
| frus1944v07 | ch13 | 36 | 36 | Argentina: > Withholding of recognition from the regime of Edelmiro Farrell by the United States |
| frus1944v07 | ch18 | 61 | 61 | Bolivia: > Recognition by the United States and other American Republics of the revolutionary junta in Bolivia |
| frus1944v07 | ch56 | 23 | 23 | Ecuador: > Recognition by the United States and the other American Republics of the new government of Ecuador |
| frus1944v07 | ch60 | 39 | 39 | El Salvador: > Revolutions in El Salvador; policies of the United States and other American Republics regarding the right of asylum and recognition |
| frus1944v07 | ch62 | 28 | 28 | Guatemala: > Revolution in Guatemala and recognition of a new regime by the United States and other American Republics |
| frus1945v09 | ch13 | 65 | 65 | Argentina: > Problems arising in connection with the recognition of the Farrell government followed by the deterioration of relations with that govern |
| frus1945v09 | ch57 | 9 | 9 | El Salvador: > Recognition by the United States and other American Republics of the government of Osmín Aguirre y Salinas |
| frus1945v09 | ch99 | 28 | 28 | Venezuela: > Consultation concerning and recognition of the Venezuelan revolutionary junta |
| frus1946v11 | ch13 | 53 | 53 | Bolivia: > Concern of the United States with respect to the violence accompanying the Bolivian revolution and the problem of recognition |
| frus1946v11 | ch52 | 8 | 8 | Haiti: > United States recognition of the new Haitian Government |
| frus1947v08 | ch43 | 14 | 14 | Ecuador: > The question of recognizing the Mancheno, the Suarez, and the Arosemena regimes in Ecuador |
| frus1947v08 | ch63 | 40 | 39 | Nicaragua: > Political upheaval in Nicaragua: United States policies of nonintervention and nonrecognition |
| frus1948v09 | ch5 | 51 | 49 | Multilateral Relations: > Continuance by the United States of diplomatic relations with new governments on the basis of the Bogota Resolution and cons |
| frus1950v02 | ch21subch1 | 3 | 3 | The American Republics: > Haiti > Recognition by the United States of the military junta government of Haiti |

Total in field: 1667.

## Appendix B. The 56 argument documents

Order is the collection's. 'In field' says whether the pair is in the 62 sections. Read: W = end to end, P = in part.

| finding | pair | edition document number | dateline | length (chars) | in field | read | quoted in overview |
|---|---|---|---|---|---|---|---|
| 1 | frus1877/d222 | 222 | Department of State, Washington, May 16, 1877. | 5435 | no | P | Q50 |
| 1 | frus1878/d344 | 344 | Department of State, Washington, March 23, 1878. | 3442 | no | W |  |
| 1 | frus1889/d43 | 43 | Department of State, Washington, November 30, 1889. | 337 | no | W | Q01 |
| 1 | frus1895p1/d246 | 246 | Department of State, Washington, November 6, 1895. | 2487 | yes | W |  |
| 1 | frus1900/d530 | 530 | Department of State, Washington, September 8, 1900. | 3792 | yes | W | Q03 |
| 2 | frus1913/d7 | 7 | Department of State, Washington, March 12, 1913—1 p.m. | 3106 | no | W |  |
| 2 | frus1913/d1028 | 1028 | Department of State, Washington, August 27, 1913—10 p.m. | 14135 | no | P |  |
| 2 | frus1913/d1064 | 1064 | American Embassy, Rio de Janeiro, October 22, 1913. | 1464 | no | P |  |
| 2 | frus1915/d987 | 987 | September 18, 1915 | 25006 | no | P |  |
| 2 | frus1915/d1004 | 1004 | Department of State, Washington, October 19, 1915. | 815 | no | W |  |
| 2 | frus1916/d258 | 258 | Department of State, Washington, November 22, 1916. | 3947 | yes | W |  |
| 2 | frus1917/d379 | 379 | Department of State, Washington, February 9, 1917, 3 p.m. | 1216 | yes | W | Q09 |
| 2 | frus1919v01/d869 | 869 | Washington, August 19, 1919, 3 p.m. | 672 | yes | W |  |
| 2 | frus1920v01/d377 | 377 | Washington, July 20, 1920—5 p.m. | 809 | yes | W |  |
| 2 | frus1920v01/d391 | 391 | Washington, September 27, 1920—6 p.m. | 1631 | yes | W |  |
| 2 | frus1920v01/d399 | 399 | Washington, December 9, 1920—2 p.m. | 1273 | yes | W | Q12 |
| 2 | frus1921v02/d344 | 344 | Washington, June 8, 1921. | 4351 | yes | W | Q13 |
| 2 | frus1923v02/d484 | 484 | Washington, August 22, 1923—5 p.m. | 2792 | yes | W |  |
| 3 | frus1923v02/d345 | 345 | Washington, June 30, 1923—3 p.m. | 5661 | no | P | Q15 |
| 3 | frus1930v01/d375 | 375 | September 17, 1930 | 6044 | no | W | Q16 |
| 3 | frus1932v05/d618 | 618 | Washington, January 13, 1932—7 p.m. | 1871 | yes | W |  |
| 3 | frus1932v05/d641 | 641 | [Washington,] March 7, 1932. | 4791 | yes | W |  |
| 3 | frus1933v05/d508 | 508 | Washington, November 28, 1933—6 p.m. | 1143 | no | W |  |
| 3 | frus1934v05/d197 | 197 | Washington, January 3, 1934—2 p.m. | 4179 | yes | W |  |
| 3 | frus1934v05/d103 | 103 | Washington, January 23, 1934. | 302 | yes | W |  |
| 3 | frus1934v05/d255 | 255 | Washington, January 25, 1934. | 3206 | yes | W |  |
| 3 | frus1936v05/d109 | 109 | [Washington,] April 21, 1936. | 3602 | yes | W | Q22 |
| 4 | frus1943v05/d334 | 334 | Washington, June 6, 1943—2 p.m. | 1712 | yes | W | Q23 |
| 4 | frus1943v05/d340 | 340 | Washington, June 9, 1943—4 p.m. | 1861 | yes | W |  |
| 4 | frus1943v05/d486 | 486 | Washington, December 22, 1943. | 800 | yes | W |  |
| 4 | frus1944v07/d388 | 388 | Washington, January 10, 1944—10 p.m. | 4887 | yes | P |  |
| 4 | frus1944v07/d219 | 219 | Washington, March 4, 1944. | 2522 | yes | W |  |
| 4 | frus1944v07/d231 | 231 | Washington, May 18, 1944—10 p.m. | 3993 | yes | W | Q27 |
| 4 | frus1944v07/d429 | 429 | [Washington,] May 23, 1944. | 1337 | yes | W | Q28 |
| 4 | frus1944v07/d437 | 437 | Washington, June 17, 1944—noon. | 1090 | yes | W |  |
| 4 | frus1945v09/d70 | 70 | Washington, February 9, 1945—midnight. | 5026 | no | P |  |
| 5 | frus1948v09/d7 | 7 | Washington, March 15, 1948. | 13192 | no | P | Q31 |
| 5 | frus1948v09/d89 | 89 | [Washington,] November 8, 1948. | 3777 | yes | W |  |
| 5 | frus1948v09/d115 | 115 | [Washington,] December 10, 1948. | 6660 | yes | W | Q33 |
| 5 | frus1948v09/d119 | 119 | Washington, December 16, 1948—10 a. m. | 4069 | yes | W |  |
| 5 | frus1949v02/d457 | 457 | [Washington,] February 21, 1949. | 7571 | no | W |  |
| 5 | frus1952-54v04/d490 | 490 | Guatemala City, June 28, 1954—5 p.m. [Received June 29—4:08  | 3924 | no | P |  |
| 5 | frus1958-60v06/d217 | 217 | Washington, January 7, 1959. | 2691 | no | W | Q37 |
| 6 | frus1961-63v12/d421 | 421 | Washington, July 27, 1962. | 9453 | no | W |  |
| 6 | frus1961-63v12/d423 | 423 | Washington, July 30, 1962, 9:17 p.m. | 2829 | no | W | Q39 |
| 6 | frus1961-63v12/d427 | 427 | Washington, October 3, 1962. | 6673 | no | P |  |
| 6 | frus1961-63v10-12mSupp/d160 | 160 | October 4, 1963, 7:45 p.m. | 2554 | no | W |  |
| 6 | frus1961-63v12/d363 | 363 | Washington, December 13, 1963, 8:15 p.m. | 3944 | no | W |  |
| 6 | frus1964-68v31/d206 | 206 | Washington, April 2, 1964, noon. | 4583 | no | W |  |
| 6 | frus1964-68v31/d135 | 135 | Washington, June 29, 1966, 7 p.m. | 2054 | no | W | Q42 |
| 6 | frus1964-68v31/d141 | 141 | Washington, July 12, 1966. | 5110 | no | P |  |
| 6 | frus1964-68v31/d515 | 515 | Washington, October 11, 1968. | 4050 | no | W |  |
| 6 | frus1969-76v21/d358 | 358 | Washington, September 17, 1973. | 4325 | no | W |  |
| 6 | frus1969-76v21/d360 | 360 | Santiago, September 18, 1973, 2120Z. | 2537 | no | W |  |
| 6 | frus1977-80v24/d132 | 132 | Washington, July 22, 1978, 1737Z | 2206 | no | W |  |
| 6 | frus1977-80v15/d276 | 276 | Washington, July 15, 1979, 1714Z | 7072 | no | P | Q48 |

## Appendix C. Files in the run directory

memo.md (this file); overview.md; collection.fruscollection; queries.log; analysis.py, analysis_out.txt; phrase_census.py, phrase_census_out.txt; build_chapters.py (abandoned) and build_struct.py, struct.db; scope_sections.tsv, scope_docs.tsv, scope.db, scopedb.py; core_docs.txt (the first, shorter list of argument documents, superseded by final_docs.py); final_docs.py; quotes.py (the 53 quotations and their verifier); ledger.py, reading_ledger.tsv; usage_scope.py, extcit_scope.py, decimal_gloss.py; find.py, ctx.py, show.py, sec.py (search and reading helpers; each logs its own SQL); q.sh, qa.sh, qc.sh, qs.sh (SQL wrappers that log); content.py, notes.py, build_deliverables.py, build_report.txt (builds and checks the overview and the collection); memo_gen.py (builds this file); scratch_struct_sections.tsv, scratch_headings_latam_events.tsv (candidate lists); texts/ (raw text of every document read).

## Appendix D. Search expressions used (from queries.log, find.py lines)

```
MATCH '"policy of the United States" AND recognition AND ("de facto" OR revolution OR coup) AND ("Latin America" OR "American republics" OR "American Republics")' ; volume LIKE '%'
MATCH 'recognition AND Huerta AND (condition OR conditions OR election OR elections OR constitutional)' ; volume LIKE 'frus1913'
MATCH 'recognition AND "constitutional" AND (Wilson OR President) AND (statement OR declaration OR policy)' ; volume LIKE 'frus1913'
MATCH 'recognition AND Huerta AND candidate AND (election OR elections) AND (armistice OR "cessation" OR Lind OR proposals)' ; volume LIKE 'frus1913'
MATCH '"consent of the governed" OR "just government"' ; volume LIKE 'frus1913'
MATCH 'Lind AND armistice AND elections AND (Huerta AND candidate)' ; volume LIKE 'frus1913'
MATCH '"Lind" AND "Gamboa" AND "elections"' ; volume LIKE 'frus1913'
MATCH 'Tinoco AND recognition AND (election OR constitutional OR Congress OR Wilson)' ; volume LIKE 'frus1917'
MATCH 'Tinoco AND recognition' ; volume LIKE 'frus1919v02'
MATCH 'Tinoco AND recognition' ; volume LIKE 'frus1918%'
MATCH '"Article II" AND recognition AND "coup d’état" AND "Central American"' ; volume LIKE 'frus1923v01'
MATCH 'recognition AND "General Treaty of Peace and Amity" AND (coup OR revolution OR "constitutional reorganization")' ; volume LIKE 'frus1923v01'
MATCH '"coup d’état" AND recognize AND "reorganized the country"' ; volume LIKE '%'
MATCH 'recognize AND "freely elected representatives" AND reorganized' ; volume LIKE '%'
MATCH 'recognition AND (Peru OR Venezuela OR Odría OR "military junta") AND (policy OR "criteria" OR "factors") AND (revolution OR coup OR "de facto")' ; volume LIKE 'frus1948v09'
MATCH 'recognition AND (Peru OR Venezuela OR Odría OR "military junta") AND (policy OR criteria OR factors) AND (revolution OR coup OR "de facto")' ; volume LIKE 'frus1949v02'
MATCH 'recognition AND Peru AND (coup OR junta OR Pérez OR Godoy OR military) AND (elections OR relations OR suspended)' ; volume LIKE 'frus1961-63v12'
MATCH 'recognition AND (Argentina OR Guido OR Frondizi) AND (coup OR military OR junta)' ; volume LIKE 'frus1961-63v12'
MATCH 'recognition AND (Dominican OR Bosch OR triumvirate) AND (coup OR military OR junta)' ; volume LIKE 'frus1961-63v12'
MATCH 'recognition AND (Honduras OR Dominican) AND (Johnson OR Mann) AND ("de facto" OR coup OR military)' ; volume LIKE 'frus1964-68v3%'
MATCH 'recognition AND (Brazil OR Goulart OR Castello) AND (coup OR revolution OR military OR "de facto")' ; volume LIKE 'frus1964-68v31'
MATCH 'recognition AND ("Castillo Armas" OR junta OR Díaz OR Monzón)' ; volume LIKE 'frus1952-54v04'
MATCH 'recognition AND (Castro OR Urrutia OR Manuel) AND (Cuba OR Cuban) AND (government OR regime)' ; volume LIKE 'frus1958-60v06'
MATCH 'recognition AND Carranza AND ("de facto" OR Latin) AND (conference OR Argentina OR Brazil OR Chile OR "Pan American")' ; volume LIKE 'frus1915'
MATCH 'recognition AND (Henríquez OR Henriquez) AND (Convention OR treaty OR "financial" OR condition OR conditions)' ; volume LIKE 'frus1916'
MATCH 'recognition AND Tinoco AND (Peru OR Aguilar OR Quirós OR elections OR constitution)' ; volume LIKE 'frus1919v01'
MATCH '("Estrada" OR "recognition") AND (policy) AND (governments) AND ("regardless" OR "as they are" OR "business as usual" OR "de facto" OR "dealing with")' ; volume LIKE 'frus1969-76ve1%'
MATCH 'recognition AND (Bolivia OR Banzer OR Torres OR Peru OR Velasco OR Ecuador OR Panama OR Torrijos) AND (coup OR junta OR military) AND (policy OR "de facto")' ; volume LIKE 'frus1969-76v21'
MATCH 'recognition AND (coup OR junta OR military) AND ("human rights") AND (Argentina OR Chile OR Bolivia OR Uruguay)' ; volume LIKE 'frus1977-80v%'
MATCH 'recognition AND junta AND Chile AND (relations)' ; volume LIKE 'frus1969-76v21'
MATCH 'recognition AND (Panama OR Peru OR Velasco OR Arias OR Argentina OR Onganía OR Ongania) AND (coup OR junta OR military OR "de facto")' ; volume LIKE 'frus1964-68v3%'
MATCH 'recognition AND (Peru OR Velasco OR junta) AND (coup OR military) AND (1968 OR October)' ; volume LIKE 'frus1964-68v31'
MATCH 'recognition AND Grau AND (obligations OR support OR stability OR Welles) AND (Hull OR Roosevelt OR President)' ; volume LIKE 'frus1933v05'
MATCH 'recognition AND Grau AND (Montevideo OR Hull) AND ("Latin American" OR "Latin America" OR Governments)' ; volume LIKE 'frus1933v05'
MATCH 'recognition AND Brazil AND ("provisional government" OR republic) AND (Blaine OR Valente OR Mendonça OR Mendonca)' ; volume LIKE 'frus1889'
MATCH 'recognition AND Brazil AND ("provisional government" OR republic)' ; volume LIKE 'frus1890'
MATCH '"Estrada doctrine"' ; volume LIKE '%'
MATCH 'recognition AND (junta OR "Government of National Reconstruction" OR GRN) AND Nicaragua' ; volume LIKE 'frus1977-80v15'
MATCH 'recognition AND (Díaz OR Diaz) AND (Mexico OR Mexican) AND (government)' ; volume LIKE 'frus187%'
MATCH 'recognition AND ("de facto") AND (revolution OR revolutionary) AND (Haiti OR Hayti OR Peru OR Venezuela OR Colombia OR Guatemala OR Nicaragua OR Honduras)' ; volume LIKE 'frus18[6-8]%'
MATCH 'recognition AND Honduras AND (López OR Lopez OR coup OR Villeda) AND (elections OR constitutional OR assurances)' ; volume LIKE 'frus1961-63v10-12mSupp'
MATCH 'recognition AND (Peru OR junta) AND (elections OR assurances) AND (resume OR resumption)' ; volume LIKE 'frus1961-63v10-12mSupp'
MATCH '("resumption" OR "resume" OR "resumed") AND relations AND Peru AND (junta OR Pérez OR Godoy OR Lindley)' ; volume LIKE 'frus1961-63v12'
MATCH '("resumption" OR "resume" OR "resumed" OR "recognized") AND (relations OR recognition) AND Peru AND (junta OR Godoy OR Lindley)' ; volume LIKE 'frus1961-63v10-12mSupp'
MATCH 'Peru AND (resumption OR resumed OR resume) AND relations AND (August OR "August 17")' ; volume LIKE 'frus1961-63v12'
MATCH '"Tobar doctrine"' ; volume LIKE '%'
```

## Appendix E. Reproduction of the checks run by build_deliverables.py

```
collection: 56 document entries (all pairs exist in document_cache, none duplicated, none Ed2), 18 excerpts, 18 of 18 excerpts verbatim in body_text
overview: 18 verbatim quotations, each in the verified quote table (unverified long spans: 0)
excerpt set equals overview quotation set: 18
overview cites 48 distinct documents; not in collection: []
overview forbidden strings present: []
distinct documents quoted in the overview: 18
```

## Appendix F. Ledger statement

The overview says (and this memo confirms) that every quotation in the overview and every excerpt in the collection is one of the verified rows of M5, and that every document the overview cites is in the collection: `build_report.txt` lines 1 to 6.

