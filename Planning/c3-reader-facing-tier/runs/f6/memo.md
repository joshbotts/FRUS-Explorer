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


## 5. Quotations: the SELECT that retrieved each, and where it is used

Every quotation in the overview and every excerpt in the collection is a passage that I retrieved with the SELECT below and tested for exact containment in `body_text` (verify_excerpts.py; excerpt_verification.txt: all 36 of 36 exact). A quotation in the overview is a substring of one of these passages (checked by script). The raw text of each document is in docs/<volume>__<doc>.txt (that SELECT's output, with the header and dateline).

| id | volume_id/document_id | retrieving SELECT and test | in overview | in collection | passage (first 110 characters) |
|---|---|---|---|---|---|
| Q1 | frus1949v07p2/d386 | `SELECT body_text FROM document_cache WHERE volume_id='frus1949v07p2' AND document_id='d386'` then `passage IN body_text` = true | yes | yes | A considerably expanded information program both in Communist and non-Communist areas of Asia is called for, b... |
| Q2 | frus1950v06/d32 | `SELECT body_text FROM document_cache WHERE volume_id='frus1950v06' AND document_id='d32'` then `passage IN body_text` = true | yes | yes | Both Pignon, the French High Commissioner for Indochina, and MacDonald, Commissioner for the United Kingdom in... |
| Q3 | frus1952-54v12p2/d403 | `SELECT body_text FROM document_cache WHERE volume_id='frus1952-54v12p2' AND document_id='d403'` then `passage IN body_text` = true | yes | yes | extend U.S. influence—and local acceptance of it—throughout the whole of Southeast Asia, associating it as clo... |
| Q4 | frus1952-54v14p2/d820 | `SELECT body_text FROM document_cache WHERE volume_id='frus1952-54v14p2' AND document_id='d820'` then `passage IN body_text` = true | yes | yes | The Inter-Agency Committee in Tokyo, which was established to implement the psychological strategy plan has no... |
| Q5 | frus1952-54v14p2/d820 | `SELECT body_text FROM document_cache WHERE volume_id='frus1952-54v14p2' AND document_id='d820'` then `passage IN body_text` = true | no | no | The violence of Japanese reactions to any matter relating to nuclear weapons is an element in all of our relat... |
| Q6 | frus1961-63v01/d49 | `SELECT body_text FROM document_cache WHERE volume_id='frus1961-63v01' AND document_id='d49'` then `passage IN body_text` = true | yes | yes | We are in the process of cranking up a major propaganda campaign on Viet Cong insurgency in VietNam. |
| Q7 | frus1961-63v01/d265 | `SELECT body_text FROM document_cache WHERE volume_id='frus1961-63v01' AND document_id='d265'` then `passage IN body_text` = true | yes | yes | The use of chemical weaponry in an Asian country could create such a storm of criticism that possible short-ra... |
| Q8 | frus1961-63v02/d5 | `SELECT body_text FROM document_cache WHERE volume_id='frus1961-63v02' AND document_id='d5'` then `passage IN body_text` = true | yes | yes | please strike me from your list of publications and information materials. I no longer need to get my American... |
| Q9 | frus1917-72PubDipv06/d126 | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv06' AND document_id='d126'` then `passage IN body_text` = true | yes | yes | I believe, however, that such a campaign would not be as effective, since much of our audience would tend to r... |
| Q10 | frus1917-72PubDipv06/d133 | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv06' AND document_id='d133'` then `passage IN body_text` = true | no | no | It has appeared questionable to us, however, whether it would be desirable for the United States to publicize ... |
| Q11 | frus1961-63v04/d108 | `SELECT body_text FROM document_cache WHERE volume_id='frus1961-63v04' AND document_id='d108'` then `passage IN body_text` = true | yes | yes | There is virtually no sympathy for the Diem regime, except in South Korea and the Philippines where officials ... |
| Q12 | frus1961-63v23/d289 | `SELECT body_text FROM document_cache WHERE volume_id='frus1961-63v23' AND document_id='d289'` then `passage IN body_text` = true | yes | yes | any actions the U.S. undertakes in furtherance of better relations with Indonesia must be pegged to a real und... |
| Q13 | frus1964-68v01/d197 | `SELECT body_text FROM document_cache WHERE volume_id='frus1964-68v01' AND document_id='d197'` then `passage IN body_text` = true | yes | yes | there is no conceivable information program that will make defeats look like victories, or GVN lassitude appea... |
| Q14 | frus1964-68v01/d197 | `SELECT body_text FROM document_cache WHERE volume_id='frus1964-68v01' AND document_id='d197'` then `passage IN body_text` = true | yes | yes | Vietnamese audiences at USIS film showings last year totalled an estimated 28 million. |
| Q15 | frus1964-68v02/d160 | `SELECT body_text FROM document_cache WHERE volume_id='frus1964-68v02' AND document_id='d160'` then `passage IN body_text` = true | yes | yes | efforts to develop among the South Vietnamese people a sense of national unity and a determination to fight of... |
| Q16 | frus1964-68v03/d138 | `SELECT body_text FROM document_cache WHERE volume_id='frus1964-68v03' AND document_id='d138'` then `passage IN body_text` = true | yes | yes | Propaganda and psychological operations in South Vietnam have also expanded and grown more effective with the ... |
| Q17 | frus1917-72PubDipv07/d171 | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv07' AND document_id='d171'` then `passage IN body_text` = true | yes | yes | the effort should not be construed as a propaganda mechanism |
| Q18 | frus1964-68v26/d106 | `SELECT body_text FROM document_cache WHERE volume_id='frus1964-68v26' AND document_id='d106'` then `passage IN body_text` = true | yes | yes | Such an action would be interpreted by both our enemies and friends as a retreat and as knuckling under to com... |
| Q19 | frus1964-68v27/d386 | `SELECT body_text FROM document_cache WHERE volume_id='frus1964-68v27' AND document_id='d386'` then `passage IN body_text` = true | yes | yes | The Thai Government has not given proper attention to the need for a national information program designed to ... |
| Q20 | frus1917-72PubDipv08/d31 | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv08' AND document_id='d31'` then `passage IN body_text` = true | yes | yes | Asians are, to varying degrees, America watchers. |
| Q21 | frus1917-72PubDipv08/d31 | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv08' AND document_id='d31'` then `passage IN body_text` = true | no | no | PAOs emphasized that the image of the US usually depended more on the state of bi-lateral relations (security ... |
| Q22 | frus1969-76v19p2/d67 | `SELECT body_text FROM document_cache WHERE volume_id='frus1969-76v19p2' AND document_id='d67'` then `passage IN body_text` = true | yes | yes | Is there a psychological threshold for economic frictions beyond which it will be difficult to sustain a produ... |
| Q23 | frus1969-76v38p2/d105 | `SELECT body_text FROM document_cache WHERE volume_id='frus1969-76v38p2' AND document_id='d105'` then `passage IN body_text` = true | no | no | we risk allowing the momentum of public opinion in Thailand to fill the vacuum and compel the Thai Government ... |
| Q24 | frus1969-76ve12/d16 | `SELECT body_text FROM document_cache WHERE volume_id='frus1969-76ve12' AND document_id='d16'` then `passage IN body_text` = true | yes | yes | With respect to the U.S., our affirmations of good intentions are welcomed by all. |
| Q25 | frus1969-76ve12/d17 | `SELECT body_text FROM document_cache WHERE volume_id='frus1969-76ve12' AND document_id='d17'` then `passage IN body_text` = true | yes | yes | Most nations in Asia apparently believe that revolutionary warfare of the Vietnamese model, like a car acciden... |
| Q26 | frus1977-80v22/d3 | `SELECT body_text FROM document_cache WHERE volume_id='frus1977-80v22' AND document_id='d3'` then `passage IN body_text` = true | yes | yes | With their long time perspective, Asians have become accustomed to seeing the United States go through periodi... |
| Q27 | frus1977-80v30/d79 | `SELECT body_text FROM document_cache WHERE volume_id='frus1977-80v30' AND document_id='d79'` then `passage IN body_text` = true | yes | yes | shoring up the confidence of East Asians in America’s long-term staying power and positive involvement in the ... |
| Q28 | frus1977-80v30/d81 | `SELECT body_text FROM document_cache WHERE volume_id='frus1977-80v30' AND document_id='d81'` then `passage IN body_text` = true | yes | yes | I consider Mort’s appointment to be a unique opportunity to establish an especially close working relationship... |
| Q29 | frus1961-63v01/d339 | `SELECT body_text FROM document_cache WHERE volume_id='frus1961-63v01' AND document_id='d339'` then `passage IN body_text` = true | yes | yes | We cannot do more with the image of the GVN than is made available by the GVN itself; in other words, unless w... |
| Q30 | frus1964-68v02/d172 | `SELECT body_text FROM document_cache WHERE volume_id='frus1964-68v02' AND document_id='d172'` then `passage IN body_text` = true | yes | yes | The USIA researchers conclude that the population is largely apathetic and is primarily interested in ending t... |
| Q31 | frus1964-68v02/d172 | `SELECT body_text FROM document_cache WHERE volume_id='frus1964-68v02' AND document_id='d172'` then `passage IN body_text` = true | yes | yes | the principal problems facing us in obtaining the support of the Vietnamese population are inadequate security... |
| Q32 | frus1952-54v14p2/d820 | `SELECT body_text FROM document_cache WHERE volume_id='frus1952-54v14p2' AND document_id='d820'` then `passage IN body_text` = true | yes | yes | The complex emotional reactions of the Japanese, particularly as sensationally represented in their press, to ... |
| Q33 | frus1917-72PubDipv08/d31 | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv08' AND document_id='d31'` then `passage IN body_text` = true | no | no | Many PAOs reported uncertainty as to the direction of US foreign policy and especially the strength of US comm... |
| Q34 | frus1969-76v38p2/d105 | `SELECT body_text FROM document_cache WHERE volume_id='frus1969-76v38p2' AND document_id='d105'` then `passage IN body_text` = true | yes | yes | The denouement in Indochina has left Hong Kong viewing USG as “very clearly in default.” |
| Q35 | frus1961-63v23/d289 | `SELECT body_text FROM document_cache WHERE volume_id='frus1961-63v23' AND document_id='d289'` then `passage IN body_text` = true | yes | yes | Fourth, “patient persistence” should be the key attitude of all Americans involved, on the scene and here in W... |
| Q36 | frus1969-76v38p2/d105 | `SELECT body_text FROM document_cache WHERE volume_id='frus1969-76v38p2' AND document_id='d105'` then `passage IN body_text` = true | yes | yes | programs on U.S. security relations in Asia lack credibility and may in fact do damage to our relations. |

## 6. Citation and source table (one row per cited document, in the order of the findings)

Each row is `SELECT d.document_number, dd.date_iso, s.repository, s.record_group, s.series_name, substr(s.raw_text,1,170) FROM document_cache d JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id JOIN document_sources s ON s.volume_id=d.volume_id AND s.document_id=d.document_id WHERE d.volume_id=? AND d.document_id=?` (run by cite_table script; every pair also confirmed `is_front_matter=0 AND is_editorial_note=0`). The year in each overview citation is the first four characters of date_iso.

| id | volume_id/document_id | date_iso | repository / record group / series | source note (first 170 characters) |
|---|---|---|---|---|
| C1 | frus1949v07p2/d386 | 1949-11-16 | Department of State / RG 59 / 711.90/11–1649 | 711.90/11–1649 |
| C2 | frus1950v06/d32 | 1950-04-03 | Department of State / RG 59 / 611.90/4–350 | 611.90/4–350 |
| C3 | frus1952-54v12p2/d403 | 1953-09-14 | Department of State / RG 59 / 790.5/9–1453 | 790.5/9–1453 |
| C4 | frus1952-54v14p2/d820 | 1954-10-28 | Department of State / RG 59 /  | S/S – NSC files, lot 63 D 351 |
| C5 | frus1961-63v01/d49 | 1961-05-09 | National Archives / RG 34 /  | Source: Washington National Records center, RG 34, Saigon Embassy Files: FRC 66 A 335. Program Direction Secret; Official-Informal; For Addressee Only. |
| C6 | frus1961-63v01/d265 | 1961-11-17 | National Archives / RG 306 / USIA /TOP Files: FRC 67 A 222 | Source: Washington National Records Center, RG 306, USIA /TOP Files: FRC 67 A 222, IAF Defoliation 1963. Secret. A note on the source text indicates that copies were sent |
| C7 | frus1961-63v01/d339 | 1961-12-23 | National Archives / RG 84 / Saigon Embassy Files: FRC 66 A 33s | Source: Washington National Records Center, RG 84, Saigon Embassy Files: FRC 66 A 33s, Program Direction. Confidential. |
| C8 | frus1961-63v02/d5 | 1962-01-04 | National Archives / RG 306 / USIA /I/ S Files: FRC 68 A 4933 | Source: Washington National Records Center, RG 306, USIA /I/ S Files: FRC 68 A 4933, Field-Far East (IAF), 1962. Confidential. Initialed by Nielson. Attached to Document  |
| C9 | frus1917-72PubDipv06/d126 | 1963-05-17 | National Archives / RG 306 / DIRCTR Sub Files | Source: National Archives, RG 306, DIRCTR Sub Files, 1963–69, Bx 6–29 63–69: Acc: #72A5121, Entry UD WW 257, Box 8, FIELD—Far East (IAF), 1963. Limited Official Use. Draf |
| C10 | frus1917-72PubDipv06/d133 | 1963-06-24 | National Archives / RG 306 / DIRCTR Sub Files | Source: National Archives, RG 306, DIRCTR Sub Files, 1963–69, Bx 6–29 63–69: Acc: #72A5121, Entry UD WW 257, Box 8, FIELD—Far East (IAF), 1963. Confidential. Drafted by J |
| C11 | frus1961-63v04/d108 | 1963-09-14 | Kennedy Library / RG  / National Security Files | Source: Kennedy Library, National Security Files, Meetings and Memoranda Series, Meetings on Vietnam. Confidential. |
| C12 | frus1964-68v01/d197 | 1964-06-04 | Johnson Library / RG  / National Security File | Source: Johnson Library, National Security File, Vietnam Country File, Southeast Asia, Vol. 11, Memos (A). Secret. Rowan sent this memorandum to the President with a cove |
| C13 | frus1964-68v02/d160 | 1965-02-24 | Johnson Library / RG  / Confidential File | Source: Johnson Library, Confidential File, CO 312. Confidential. Copy sent to McGeorge Bundy. |
| C14 | frus1964-68v02/d172 | 1965-02-27 | Johnson Library / RG  / National Security File | Source: Johnson Library, National Security File, Country File, Vietnam, Vol. XXIX. Confidential. |
| C15 | frus1964-68v03/d138 | 1965-09-10 | Johnson Library / RG  / National Security File | Source: Johnson Library, National Security File, Country File, Vietnam, 41-Pt. Program in Non-Military Sphere in SVN. Secret. |
| C16 | frus1917-72PubDipv07/d171 | 1967-11-24 | Johnson Library / RG  / Marks Papers | Source: Johnson Library, Marks Papers, Box 30, Educational TV —Vietnam. Confidential. A copy was sent to Marks. |
| C17 | frus1961-63v23/d289 | 1962-09-14 | Department of State / RG 59 / 611.98/9–1462 | Source: Department of State, Central Files, 611.98/9–1462. Secret. |
| C18 | frus1964-68v26/d106 | 1965-02-18 | Johnson Library / RG  / National Security File | Source: Johnson Library, National Security File, Country File, Indonesia, Vol. III, Memos 9/64–2/65, [2 of 2]. Confidential. Copies were sent to Ball and William Bundy. |
| C19 | frus1964-68v27/d386 | 1968-05-06 | Johnson Library / RG  / National Security File | Source: Johnson Library, National Security File, Country File, Thailand, Thanom Kittikachorn Visit, 5/8–9/68. Confidential |
| C20 | frus1917-72PubDipv08/d31 | 1969-08-05 | National Archives / RG 306 / Office of Policy and Plans | Source: National Archives, RG 306, Office of Policy and Plans, Plans and Operational Policy Staff, Office of Planning Officer, Subject Files, Entry P–207, Box 2, INF 3 PA |
| C21 | frus1969-76v19p2/d67 | 1971-02-16 | Nixon Presidential Materials / RG  / NSC Files | Source: National Archives, Nixon Presidential Materials, NSC Files, NSC Institutional Files (H-Files), National Security Study Memoranda, Box H–182, NSSM 13, 3 of 3. Top  |
| C22 | frus1969-76v38p2/d105 | 1975-05-09 | National Archives / RG 305 / Records of the USIA | Source: National Archives, RG 305, Records of the USIA, Office of the Director, Subject Files, 1975, Entry UD–UP 7, FRC 306–84–0003, 7501300–7501309. No classification ma |
| C23 | frus1969-76ve12/d16 | 1975-06-13 | Ford Library / RG  / National Security Adviser | Source: Ford Library, National Security Adviser, Presidential Country Files for East Asia and the Pacific, Box 1, Southeast Asia (3). Confidential; Exdis. Attached and pu |
| C24 | frus1969-76ve12/d17 | 1975-07-15 | Ford Library / RG  / National Security Adviser | Source: Ford Library, National Security Adviser, Presidential Country Files for East Asia and the Pacific, Box 1, Southeast Asia (3). Secret; Sensitive; Eyes Only. Sent f |
| C25 | frus1977-80v22/d3 | 1977-02-04 | Carter Library / RG  / National Security Affairs | Source: Carter Library, National Security Affairs, Brzezinski Material, Country File, Box 85, Vietnam, 1/77–12/78. Confidential. Sent for information. Inderfurth and Dene |
| C26 | frus1977-80v30/d79 | 1977-07-19 | National Archives / RG 306 / Office of the Director, Box 130 | Source: National Archives, RG 306, Office of the Director, Executive Secretariat, Secretariat Staff, Correspondence Files, 1973–1980, Entry P–104, Box 130, 7702800–770280 |
| C27 | frus1977-80v30/d81 | 1977-07-23 | Department of State / RG 59 / CFPF D770263–1068 | Source: National Archives, RG 59, Central Foreign Policy File, D770263–1068. Limited Official Use. Drafted by Kenneth Quinn and Morton Smith; approved by Holbrooke. |

All 27 pairs exist in `document_cache` and appear once in the collection (build_collection.py asserts it). The overview cites 27 documents, all in the collection.

## 7. Reading accounting

- Retrieved whole (captured text equal to `length(body_text)` characters, tested by comparing the captured body to `SELECT body_text`): 61 of 61 (retrieval_check.txt). Quoted: 27 documents, 36 passages; every quoted document is cited in the overview and kept in the collection.
- Read in full (all characters printed to me): frus1917-72PubDipv08/d31, PubDipv07/d171, PubDipv06/d126, d133, frus1969-76v38p2/d105, frus1977-80v30/d79, d81, frus1952-54v12p2/d403, frus1961-63v01/d49, d265, frus1961-63v02/d5, d16, frus1961-63v03/d308, frus1961-63v04/d95, d108, frus1961-63v23/d289, frus1964-68v01/d197, frus1964-68v02/d160, d172, frus1964-68v03/d138, frus1964-68v27/d386, frus1969-76v19p2/d67, frus1955-57v09/d54.
- Read in part (windows of 400 to 8,500 characters around the search terms, or the first 2,000 to 7,500 characters): frus1949v07p2/d386, d338, frus1950v06/d32, frus1952-54v14p2/d820, frus1961-63v01/d339, frus1961-63v04/d81, frus1964-68v26/d106, frus1969-76v10/d199, frus1969-76ve12/d10, d16, d17, frus1977-80v22/d3, d102, d107, frus1955-57v09/d185, frus1955-57v22/d448, frus1955-57v21/d72, d79, frus1958-60v18/d180. For the cited documents among these (d386, d32, d820, d339, d106, ve12/d16, ve12/d17, v22/d3) I read the quoted passage and its surrounding paragraphs, and the document's opening.
- Retrieved but not read: frus1917-72PubDipv07/d32, d37, PubDipv08/d143, d149, frus1949v07p1/d409, frus1951v06p2/d480, frus1952-54v12p1/d388, v12p2/d359, frus1955-57v09/d190, frus1955-57v21/d78, frus1955-57v22/d463, frus1961-63v02/d266, d290, frus1961-63v03/d28, d152, frus1964-68v01/d122, frus1964-68v29p2/d46, frus1977-80v22/d104, frus1977-80v30/d68. (They came from ranked lists; I did not use them.)
- Documents seen only as a header line in ranked lists: several hundred; none was cited without being retrieved and read.

## 8. VECTORS

Operations I ran, each with anchor, file, baseline and result. Operations not run are named as such.

**Digest check (before scoring).** `semantic-vectors-index.json` `provenanceDigest` = 89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101; the digest at offset 20 of `semantic-vectors-binary.bin`, at offset 20 of `semantic-map.bin`, and at offset 16 of all 553 shards in /Users/jbotts/frus-analysis/c3/SemanticVectors/ is identical (digest_check.txt; 0 mismatches). Index `generated` 2026-10-15, `harvestGenerated` 2026-10-15T06:55:14. Identity came only from the index's id segments (decode round trip passes for 553 of 553 volumes, assertion in vec.py; no id was derived from an ordinal). `retrieval.measuredRecallAt10` = 0.9021 (so absence of a neighbour is not evidence of absence).

**Baselines at this digest** (vec_baselines.txt): random pairs (20,000 pairs, `random.Random(1877)`): mean 167.1, sd 14.8, 1st percentile 132, minimum 95 of 512 bits. The 25th-nearest-neighbour distance over 200 random documents (`random.Random(2026)`): median 106, quartiles 100 and 113. A neighbour at 72 to 100 is therefore inside the near tail of the k-th-neighbour distribution and far below random pairs, which makes it a reading suggestion and not a relationship.

**1. Nearest neighbours of a document.** Anchors: frus1917-72PubDipv08/d31 (the 1969 Manila conference summary), frus1969-76v38p2/d105 (the 1975 reassessment) and frus1964-68v01/d197 (the 1964 Honolulu committee memorandum). File: `semantic-vectors-binary.bin` sign bits (512 bits), XOR and popcount over all 314,616 rows, top 800 by Hamming reranked by int8 cosine from the Tier-2 shards, top 15 shown; the cosine is shown through `retrieval.scoreCalibration` as (cosine - 0.40) / 0.60 (document to document) beside the raw cosine. Output: vec_neighbours.txt (48 lines: 3 anchors and 45 neighbours). Baseline: the 25th-neighbour distribution above (the 15 neighbours sit at 72 to 104 bits). Every neighbour's volume is present in `document_cache` (all 553 volumes are), so none is flagged as outside the index.
  Found by similarity and by none of the seven ranked or listed full-text queries I ran (their complete ordered result lists were tested, not only the top rows I read: assessment, audience beliefs, exchange, information-set Asia, Japan, header, and the M4 family; membership test in queries.log): **frus1969-76ve12/d16** (distance 80 to the 1975 reassessment anchor, raw cosine 0.913, calibrated 85%), **frus1969-76ve12/d17** (distance 99, raw cosine 0.903, calibrated 84%) and **frus1977-80v22/d3** (distance 88, 84%; all three are neighbours of the 1975 reassessment anchor, frus1969-76v38p2/d105). I read each before citing it (in part, see section 7).
  Other neighbours I noted but did not cite: frus1969-76ve12/d10 (Smyser, 1974), frus1977-80v22/d102 and d107, frus1917-72PubDipv07/d37 and d32.
  Documents in the overview reached through a vector operation and through no full-text query: those three (frus1969-76ve12/d16, ve12/d17, frus1977-80v22/d3). Every other cited document was reached by a full-text query; of the 27 cited, five appear in the neighbour lists (those three, and the Manila summary and the 1975 reassessment, which are each other's neighbours).
**2. A semantic join into the database.** Each neighbour was joined on both keys to `document_cache` (header, flags), `document_dates` (date_iso) and to the full-text family M4 (`inQAfts` flag in vec_neighbours.txt). The joined fields show which neighbours the full-text family does not capture (inQAfts=False): for the 1975 anchor, 10 of 15.
**3. Centroid similarity: not run.**
**4. The map.** `semantic-map.bin` placements and `semantic-map-index.json` cluster terms for all 27 cited documents (map_cited.txt): 5 of the 27 are unclustered (frus1917-72PubDipv08/d31, frus1969-76v38p2/d105, frus1977-80v22/d3, frus1977-80v30/d79, frus1969-76ve12/d16); corpus-wide 88,059 of 314,616 placements are unclustered (28.0%), so 5 of 27 (18.5%) is not unusual for a set that is mostly 1960s and 1970s. Cluster terms are geographic (Vietnam, Indonesia, Japan), not thematic: the map cannot find "messaging" documents, and I used it for no selection.
**5. Near-duplicates.** Pairwise Hamming distance over the sign bits among the 27 cited documents (351 pairs; vec_pairs.txt): minimum 76 (frus1917-72PubDipv06/d126 against d133, which are a request and its reply and not a reprint), next 80, 85, 86, 87. No pair is near enough to be a reprint; I also read the pairs' texts where I had read both, and none duplicated another. (I did not have section 14.9's measured reprint distances in this session; the check rests on the distances being far above the few-bit range I expect of a reprint and on my reading.)

Similarity suggestions are lead-finding only. The neighbour distances in the overview do not appear (the overview says "found by its similarity to ... by no word search I ran, and read before it was cited").

## 9. What is thin, and what I did not do

- The index holds all 553 volumes, so the thinness here is the series' and not a partial library: FRUS prints almost nothing measuring audience effect; the effect assessments are officials' own, mostly from USIA (a self-assessing source).
- The family M4 over 1940s documents includes non-American bodies (the Chinese Government's information service), so the 1940s rate in M10 overstates American messaging; the overview does not use it.
- I did not search the 14 volumes of 1981 to 1992 in the index (the EAP set's last decade holds 106 documents dated 1980 or later, from the 1977 to 1980 volumes) or any volume before 1944.
- The 27 documents are a selection by reading; other documents of the same kinds exist (the M4 family has 1,296), and a different reading could choose others. I did not read the Japan and Korea volumes beyond documents the searches ranked; cultural exchange in Japan and Korea is therefore thin in the collection.
- I did not use the NARA harvest ([HARVEST] path not supplied; that surface is unavailable to this run). Archival resolution stops at what the bundled indexes reach. The offline stack barely reaches before 1940; this scope starts in 1945 so the roadmap is not empty for that reason, but the USIA series are the ones it cannot resolve to a folder.
- The term "soft power" is absent from the series (M8); the question's vocabulary was mapped to the editors' (information program, psychological strategy, American image).
## 10. Trace table: every number and quotation in the overview

Memo lines are the M-numbers above and the sections named. A year inside a citation parenthesis, e.g. (1964, Volume I, Document 197), is taken from the cite table (section 6). 

| number or set of numbers in the overview | memo line it comes from |
|---|---|
| 76 (volumes on East Asia and the Pacific) | M2 (SELECT COUNT(DISTINCT volume_id) ... IN the 76 ids = 76) |
| 553 (volumes of the series in the index) | M1 (canary: COUNT(DISTINCT volume_id) = 553) |
| 14 (volumes on information policy and public diplomacy) | M3 (= 14 volumes; also Lot count 'Kennedy 14' row in M13, same numeral different meaning) |
| 1,300 (documents in the family, rounded from 1,296) | M4 (COUNT(*) = 1296) |
| 61 (documents retrieved whole) | Section 7 reading accounting and retrieval_check.txt (61 of 61 whole) |
| 1945, 1980 (period searched), 1951 (kept volume), 1945-1963 (no decimal-file series bundled) | Section 2 scope (earliest document year 1944 or later; 1945 volume first; document_dates up to 1981); 1951 = frus1951v06p1/p2 in eap_volumes.txt; 1945-1963 = archival_facts.txt decimal line and the check that central-files-index.json has no decimal-file series for those years (jsonscan.py) |
| 1910 (no pointed-at row before 1910) | House rule stated in the brief (external_citations has no row before 1910-12-06); not a measurement of mine |
| 3, 15, 18 (series per USIA accession); two (series of FRC 306-84-0003) | M11 (accession-series-index.json: 306/67A222 = 3, 306/68A4933 = 15, 306/72A5121 = 18, 306/840003 = 2); the isolated '3' in the binational-centre sentence is M14 |
| four (series of lot 62 D 430), three (series of lot 62 D 1) | M12 (lot-claimants-index.json: 4 and 3 claimants) - also 'three' counts the vector-found documents, see below |
| 41, 16, 13, 9 (documents citing Lots 66 D 95, 62 D 430, 63 D 351, 62 D 1); 19, 25, 14, 7 (Nixon, Johnson, Kennedy, Carter library citations); 178 (central file numbers) | M13 (docs column of the pointed-at query; 14 for Kennedy is the same '14' token as M3) |
| 64 (documents), 28 (volumes) - survey/poll scan; 33 (documents), 17 (volumes) - leaflet/script/film scan; 3 (binational centres); 60 (Peace Corps) | M14 table rows 1, 3, 6 and 4 respectively (absence_results.txt); '33' also appears as the sample hits in M5 (33 of 40) |
| 40 (sample), 33 (held the intended words), seven (the other seven) | M5 and M6 (33 of 40 tolerant and strict; seven misses, searched, none held the words) |
| Three (documents found by similarity); Three (days later) | Three vector-found documents: section 8 (frus1969-76ve12/d16, ve12/d17, frus1977-80v22/d3). 'Three days later': document_dates 1965-02-24 (frus1964-68v02/d160) to 1965-02-27 (frus1964-68v02/d172) |
| 28 million (in a quotation) | Q14 (frus1964-68v01/d197 passage 'Vietnamese audiences at USIS film showings last year totalled an estimated 28 million.') |
| Years of documents and series, and dates (1949, 1950, 1953, 1954, 1961, 1962, 1963, 1964, 1965, 1967, 1968, 1969, 1971, 1975, 1977; 1960s, 1963-1969, 1969-1974, 1953-1961, 1947-1979 and similar) | Each year in a document description is the first four characters of date_iso of the cited document (cite table C1-C27, section 6); each series date range is from archival_facts.txt (series-facts-index.json inclusive years y0-y1; library series dates from presidential-library-catalog.json) |
| NAIDs, entry numbers, FRC accession numbers, record groups, file numbers, lot numbers, linear feet (26, 47, 9, 4 etc.) | NAIDs and extents: archival_facts.txt; accession and entry strings (FRC 67 A 222, 68 A 4933, 72 A 5121, UD WW 257, P-207, P-104, 306-84-0003; decimal 711.90, 611.90, 790.5, 611.98; Lot 63 D 351 Entry A1 1586E): the source notes in section 6 and archival_facts.txt; report number R-10-65: footnote text of frus1964-68v02/d172 |
| The structural numerals: '1.', '2.', '3.' headings of the skeleton, 'Document N' inside citations | Not counts. Document numbers: cite table column 'document_number' (SELECT document_number FROM document_cache). |

### Quotations

| quotation in the overview | verified passage |
|---|---|
| "has not thus far been effective" | Q4 (frus1952-54v14p2/d820) |
| "not progressed to my satisfaction" | Q15 (frus1964-68v02/d160) |
| "effective." | Q4 (frus1952-54v14p2/d820), Q9 (frus1917-72PubDipv06/d126) |
| "[a] considerably expanded information program" | Q1 (frus1949v07p2/d386) |
| "are inclined by their psychology to wait and see who is winning" | Q2 (frus1950v06/d32) |
| "thus gradually creating a climate of victory" | Q3 (frus1952-54v12p2/d403) |
| "sensationally represented in their press," | Q32 (frus1952-54v14p2/d820) |
| "has not thus far been effective" | Q4 (frus1952-54v14p2/d820) |
| "a major propaganda campaign on Viet Cong insurgency" | Q6 (frus1961-63v01/d49) |
| "a harvest of ill-will" | Q7 (frus1961-63v01/d265) |
| "We cannot do more with the image of the GVN than is made available by the GVN itself" | Q29 (frus1961-63v01/d339) |
| "to get my American propaganda from a source which restricts its outlets to its own people" | Q8 (frus1961-63v02/d5) |
| "much of our audience would tend to regard it as mere words without deeds" | Q9 (frus1917-72PubDipv06/d126) |
| "questionable" | Q10 (frus1917-72PubDipv06/d133) |
| "virtually no sympathy for the Diem regime, except in South Korea and the Philippines" | Q11 (frus1961-63v04/d108) |
| "there is no conceivable information program that will make defeats look like victories" | Q13 (frus1964-68v01/d197) |
| "Vietnamese audiences at USIS film showings last year totalled an estimated 28 million," | Q14 (frus1964-68v01/d197) |
| "have not progressed to my satisfaction" | Q15 (frus1964-68v02/d160) |
| "largely apathetic" | Q30 (frus1964-68v02/d172) |
| "inadequate security and ineffective Government" | Q31 (frus1964-68v02/d172) |
| "have also expanded and grown more effective" | Q16 (frus1964-68v03/d138) |
| "the effort should not be construed as a propaganda mechanism" | Q17 (frus1917-72PubDipv07/d171) |
| "patient persistence," | Q35 (frus1961-63v23/d289) |
| "a demonstrated respect for Indonesia’s neutral stance" | Q12 (frus1961-63v23/d289) |
| "Such an action would be interpreted by both our enemies and friends as a retreat" | Q18 (frus1964-68v26/d106) |
| "has not given proper attention to the need for a national information program designed to ..." | Q19 (frus1964-68v27/d386) |
| "Asians are, to varying degrees, America watchers," | Q20 (frus1917-72PubDipv08/d31) |
| "a psychological threshold for economic frictions" | Q22 (frus1969-76v19p2/d67) |
| "very clearly in default" | Q34 (frus1969-76v38p2/d105) |
| "lack credibility" | Q36 (frus1969-76v38p2/d105) |
| "our affirmations of good intentions are welcomed by all," | Q24 (frus1969-76ve12/d16) |
| "is something that happens to other people" | Q25 (frus1969-76ve12/d17) |
| "have become accustomed to seeing the United States go through periodic cycles of intense i..." | Q26 (frus1977-80v22/d3) |
| "shoring up the confidence of East Asians in America’s long-term staying power" | Q27 (frus1977-80v30/d79) |
| "an especially close working relationship between State and USIA" | Q28 (frus1977-80v30/d81) |

### Word-numbers that are not counts

'first' ("reading the editors' headings first") and 'one' ("a Thai-initiated one"; "is one I verified") are not counts. 'Channel' labels are names, not numbers.
