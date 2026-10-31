# Memo: soft power in East Asia and the Pacific (operator's scope memo)

Run directory: /Users/jbotts/frus-analysis/c3f/runs/f6. Index copy: /Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db, opened read-only (the read-only proof returned "attempt to write a readonly database"). Run date 2026-10-31. Question: how policymakers assessed American soft power in East Asia and the Pacific, what messaging strategies they used and thought effective, and what beliefs about the regional audience shaped them.

**Condition on every count below: this index holds 553 volumes (the whole series), so the counts are conditional on the series as indexed, not on a partial library.** Counting surface for all SQL counts: the index's stemmed full-text table (`frus_documents`, porter stemming), with front matter and editorial notes excluded, unless a line says otherwise. Periodised on `document_dates.date_iso` (the document's own date), not on the volume's series year.

## 1. Coverage and canary

M1. Canary, first command, output exactly as required:

    sqlite3 "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro" "SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;"
    -> 553|321749|1103|8481

Read-only proof, second command: `sqlite3 -readonly <db> "BEGIN; CREATE TABLE zz(x); ROLLBACK;"` -> "attempt to write a readonly database".

## 2. The scope I chose, and how I found it

**Scope.** Two volume sets, 1945 to 1980, front matter and editorial notes excluded.

- EAP set (76 volumes): every volume whose manifest title names China, Japan, Korea, Vietnam, Indochina, Southeast Asia, East Asia, Far East, Philippines, Indonesia, Laos, Cambodia, Pacific or Australasia, whose earliest document year is 1944 or later, excluding titles that name South Asia (without Southeast). Selected by title regex over `manifest.json` (script inline in queries.log, output `eap_volumes.txt`, 75 ids) plus `frus1961-63v22` (Northeast Asia, added by hand because "Northeast Asia" misses the capital-E regex). `frus1944v06` (range begins 1943) and the 1944 Far East volume are therefore outside; `frus1958-60v15` (titled South and Southeast Asia) and `frus1951v06p1`/`p2` (Asia and the Pacific) are in the set although they mix in South Asia; their India and Pakistan documents are in the counts, none is cited, and the overview flags this as a decision. The 76 ids are:
  `frus1945v07 frus1946v08 frus1946v09 frus1946v10 frus1947v06 frus1947v07 frus1948v06 frus1948v07 frus1948v08 frus1949v07p1 frus1949v07p2 frus1949v08 frus1949v09 frus1950v06 frus1950v07 frus1951v06p1 frus1951v06p2 frus1951v07p1 frus1951v07p2 frus1952-54v12p1 frus1952-54v12p2 frus1952-54v13p1 frus1952-54v13p2 frus1952-54v14p1 frus1952-54v14p2 frus1952-54v15p1 frus1952-54v15p2 frus1955-57v01 frus1955-57v02 frus1955-57v03 frus1955-57v03mSupp frus1955-57v21 frus1955-57v22 frus1955-57v23p1 frus1955-57v23p2 frus1958-60v01 frus1958-60v15 frus1958-60v16 frus1958-60v17 frus1958-60v18 frus1958-60v19 frus1961-63v01 frus1961-63v02 frus1961-63v03 frus1961-63v04 frus1961-63v23 frus1961-63v24 frus1964-68v01 frus1964-68v02 frus1964-68v03 frus1964-68v04 frus1964-68v05 frus1964-68v06 frus1964-68v07 frus1964-68v26 frus1964-68v27 frus1964-68v28 frus1964-68v29p1 frus1964-68v29p2 frus1964-68v30 frus1969-76v06 frus1969-76v07 frus1969-76v08 frus1969-76v09 frus1969-76v10 frus1969-76v17 frus1969-76v18 frus1969-76v19p1 frus1969-76v19p2 frus1969-76v20 frus1969-76v42 frus1969-76ve12 frus1969-76ve13 frus1977-80v13 frus1977-80v22 frus1961-63v22`
- Information set (14 volumes), chosen from the manifest titles (Public Diplomacy, Foreign Information Program, Organization of Foreign Policy; Information Policy, National Security): `frus1917-72PubDipv06 frus1917-72PubDipv07 frus1917-72PubDipv08 frus1955-57v09 frus1961-63v25 frus1969-76v38p2 frus1977-80v30 frus1952-54v02p1 frus1952-54v02p2 frus1950v01 frus1951v01 frus1949v01 frus1955-57v19 frus1958-60v03`. Within it I took only documents about Asia (ranked by an Asia-terms query and selected by reading).
- Second editions: neither `frus1951-54IranEd2` nor `frus1969-76ve15p2Ed2` is in either set; no Ed2 volume is in the collection.

**Inclusion rule for the argument set** ("every document the argument rests on, and nothing else"): a document is in if it is a Washington or field judgment of (a) the American image or soft-power-type programs (information, psychological, cultural, exchange) in the region, (b) the effect of a message, or (c) a belief about the Asian audience that shaped a message. Twenty-seven documents (the collection) passed after reading.

**How I found it.** I read the editors' headings first (hdr_hits.txt: headers with Information, USIA, USIS, Voice of America, psychological, propaganda, prestige, cultural, educational; the chapter formula is "Information program", "Psychological Strategy Board", and USIA office titles - "public diplomacy" is a late term: 2 documents in the EAP set). Then I ranked the EAP set and the information set with BM25 (rank.sh) on pairings of programme words with assessment words, and on audience-belief phrases. Then I took the top documents whole (getdoc.sh) and read them. Then I added three documents by nearest-neighbour search on the vectors (section VECTORS).

M2. EAP set size.

    SELECT COUNT(DISTINCT volume_id), SUM(is_front_matter=0 AND is_editorial_note=0) FROM document_cache WHERE volume_id IN (<the 76 ids above>);
    -> 76 | 36972

M3. Information set size.

    SELECT COUNT(DISTINCT volume_id), SUM(is_front_matter=0 AND is_editorial_note=0) FROM document_cache WHERE volume_id IN (<the 14 ids above>);
    -> 14 | 3743

## 3. Controls (same pass), false-friend test, and what the vocabulary is

M7. Positive and negative controls over the EAP set (absence.sh, results in absence_results.txt):

    SELECT COUNT(*), COUNT(DISTINCT d.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '"Department of State"' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN (<76>);   -> 14916 documents, 76 volumes   (positive: every volume)
    ... MATCH '"ZZZ_IMPOSSIBLE_ZZZ"' ...   -> 0, 0   (negative)

M8. "Soft power", the question's own term:

    SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH '"soft power"';    -> 0   (whole index, nothing excluded; EAP set: 0 of 36,972)

The phrase is anachronistic to the record; I stopped using it. False-friend test on other question terms (falsefriend.txt; 36,972 EAP documents vs 275,197 documents outside the set, apparatus excluded):

| term (stemmed match) | EAP hits of 36,972 | other hits of 275,197 | reading |
|---|---|---|---|
| "public diplomacy" | 2 | 209 | late term; not used as a search key in EAP |
| messaging | 6,688 | 26,066 | STEM TRAP: porter folds "messaging" to "message"; 18.1% vs 9.5%; useless, dropped |
| audience | 255 | 2,579 | 0.69% vs 0.94%; at or below the corpus baseline; not on-topic marker |
| "Department of State" (control) | 14,916 | 79,133 | 40.3% vs 28.8% |

## 4. Measurements (audit form)

M4. Family count: documents in the EAP set that mention the Information Agency or its posts, the Voice of America, or information, psychological or exchange programmes.

    -- QA = (USIA OR USIS OR "Information Agency" OR "Information Service" OR "Voice of America" OR "information program" OR "psychological program" OR "psychological strategy" OR "cultural exchange" OR "educational exchange")
    SELECT COUNT(*), COUNT(DISTINCT d.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '<QA>' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN (<76>);
    -> 1296 documents in 76 volumes   (overview: "about 1,300")

M5. Literal share for the M4 family (share.py; sample of 40 evenly spaced from the (volume_id, document_id)-sorted hit list of 1,296; regex run over header+dateline+source_note+body_text, whitespace-collapsed; Python `re`, case-insensitive; STRICT = exact single-spaced phrases; TOLERANT = each phrase with inflections and any run of non-word characters between its words):

- STRICT: 33 of 40. TOLERANT: 33 of 40 (0.825, above the 0.80 floor; the two forms agree because the family is mostly acronyms).
- Strict regex: `\bUSIA\b|\bUSIS\b|Information Agency|Information Service|Voice of America|information program|psychological program|psychological strategy|cultural exchange|educational exchange`
- Tolerant regex: `\bUSIA\b|\bUSIS\b|Information\W+Agenc|Information\W+Servic|Voice\W+of\W+America|information\W+programm?e?s?\b|psychological\W+(programm?e?s?|strateg\w+)|cultural\W+exchang\w+|educational\W+exchang\w+`
- Misses (7): frus1948v06/d131, frus1948v06/d219, frus1948v06/d76, frus1949v07p1/d180, frus1949v07p1/d348, frus1949v08/d1108, frus1950v06/d15. M6: I searched these seven for the intended words and found none (they match the stemmed search through related forms; I did not read them). The family is therefore usable, with the known limit that its 1940s documents include non-American "Information Service" bodies (the Chinese Government's) and that the share tests the stemmer, not the referent: the referent (an American effort at messaging) I tested by reading the 27.

M9. Retrieved whole (see section 6): 61.

M10. Periodisation of the M4 family (decade.sql; per-1,000 of the decade's dated, non-apparatus EAP documents; top volume share is the numerator's):

| decade | hits | dated docs | per 1,000 | top volume (hits of decade's hits) |
|---|---|---|---|---|
| 1940s | 387 | 12,620 | 30.7 | frus1948v06: 94 of 387 |
| 1950s | 437 | 12,972 | 33.7 | frus1955-57v03mSupp: 54 of 437 |
| 1960s | 385 | 7,884 | 48.8 | frus1961-63v02: 45 of 385 |
| 1970s | 86 | 3,370 | 25.5 | frus1977-80v13: 18 of 86 |
| 1980s | 1 | 106 | 9.4 | frus1977-80v13: 1 of 1 (106 documents is too small to read) |

    SQL: sqlite3 -readonly $DB < decade.sql   (decade.sql in the run directory: hits CTE = the M4 predicate; base CTE = document_cache JOIN document_dates on both keys, date_iso not null, same exclusions; per-decade counts by substr(date_iso,1,3)). The overview does not use these rates.

M11. Accession reach (archival_facts.txt, computed by archival_facts.py over accession-series-index.json; the record group is part of the key): 306/67A222 reaches 3 series; 306/68A4933 reaches 15; 306/72A5121 reaches 18; 306/840003 reaches 2. I state the counts and do not choose a series.

M12. Lots and NAIDs (archival_facts.txt): lot 63 D 351 -> NAID 2839192 (control match); lot 66 D 95 -> two claimants (2839192 and 2839193); lot 62 D 430 -> four claimants (2386675, 2839190, 2839191, 2842737); lot 62 D 1 -> three claimants (2198167, 2838991, 2838992). Series dates, extent and access status come from series-facts-index.json via the same script (rows for 2839192, 2839193, 2839191, 2838992, 1257679, 40967285, 1254251; no row for 42125423, 48349732, 5552237, 5585931, 2386675, 2839190, 2842737).

M13. Pointed-at channel over the M4 family (src: pointed_at_qa.txt; SQL):

    WITH hits AS (SELECT d.volume_id v, d.document_id id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '<QA>' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN (<76>))
    SELECT e.anchor, ifnull(e.repository,''), ifnull(e.collection,''), ifnull(e.lot_file_norm,''), count(*) c, count(distinct e.volume_id||e.document_id) docs FROM external_citations e JOIN hits h ON h.v=e.volume_id AND h.id=e.document_id GROUP BY 1,2,3,4 ORDER BY c DESC LIMIT 22;

Results used: central file decimal anchors 312 citations in 178 documents; lot 66 D 95: 51 in 41; lot 62 D 430: 19 in 16; lot 63 D 351: 17 in 13; lot 62 D 1: 10 in 9; Nixon NSC Files 36 in 19; Johnson National Security File 32 in 25; Kennedy National Security Files 16 in 14; Carter National Security Affairs 12 in 7. Total over the family: 638 citations in 342 documents. Limits stated to the reader: the pointed-at channel has no row before 1910-12-06, stores the fragment and not the sentence, and holds lot, library and decimal anchors only, so USIA accession citations (FRC numbers) are not in it. These 638 citations are over the whole 1,296-document family (not only the 27 cited), and are never added to the came-from channel.

M13b. Came-from channel, over the same family (src_channel_qa.txt): Department of State record group 59: 919; Johnson Library 76; Nixon Presidential Materials 51; Eisenhower Library 48; Kennedy Library 47; National Archives RG 59: 32; no repository: 20; RG 330: 18; RG 306: 15; Carter Library 15 ... (1,296 of 1,296 have a document_sources row). This is the "union over the family"; the overview reports the channels for the 27 cited documents instead (cite table below), and does not sum the two.

M14. Absence scans, EAP set, positive and negative controls in the same pass (M7), absence_results.txt:

| scan | documents | volumes |
|---|---|---|
| (USIA OR USIS) AND (poll OR survey OR "opinion research" OR "research report" OR "audience research") | 64 | 28 |
| ("public opinion" OR poll OR survey) AND (Asian OR Asians) AND (USIA OR USIS OR propaganda) | 148 | 58 |
| (leaflet OR leaflets OR "radio script" OR "film script" OR "VOA script") AND (USIA OR USIS OR "Voice of America") | 33 | 17 |
| "Peace Corps" | 60 | 18 |
| Fulbright AND (grant OR scholar OR exchange OR educational) | 126 | 41 |
| binational centre variants ("binational center" OR "bi-national center" OR "Binational Centers") | 3 | 3 |

All run as `SELECT COUNT(*), COUNT(DISTINCT d.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '<expr>' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN (<76>)`. These are stemmed counts without literal-share checks; the overview uses only the first, third and sixth (and Peace Corps in a decision), as counts of documents the search matched, not as phrase counts. The measured-effect absence is not a FRUS absence: FRUS prints the Long An study's findings (frus1964-68v02/d172 summarises it; the report R-10-65 is "attached but not printed").

