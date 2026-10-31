# memo.md - scope memo for the operator (run of 2026-10-31)

Question: how did policymakers assess American soft power in the east Asia and Pacific region; what messaging strategies; how effective did they think they were; what beliefs about the regional audience shaped the strategies.

Files in this run directory: memo.md (this), overview.md, collection.fruscollection, queries.log. Scripts and outputs kept on disk beside them: h.py (db helper that logs every SQL), scan.py, scan_docs.tsv, beliefs.py, beliefs_hits.tsv, census.py, census.tsv, census_agg.py, census_out.txt, fetch.py, fetched.tsv, docs/ (95 whole-document dumps), quotes.py, kwic.py, asia_sent.py, vec.py, nn.py, vecops.py, vecjoin.py, vec_baselines.txt, nn_run1.txt, nn_run2.txt, vecops_out.txt, vecjoin_out.txt, dupcheck.txt, archival_*.txt, zero_and_relaxed.txt, build_collection.py, verify_overview.py, pubdip_scan.tsv, ranked.txt.

## 0. Coverage and read-only proof

M0.1 Canary (first command, exact): `SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;` returned `553|321749|1103|8481`. All counts below are conditional on this copy of the index, which holds all 553 volumes of the series (so the library-completeness caveat does not bite; FRUS's own selection does).

M0.2 Read-only proof (second command): `sqlite3 -readonly <db> "BEGIN; CREATE TABLE zz(x); ROLLBACK;"` failed with `attempt to write a readonly database`, as required.

## 1. Scope chosen, and how it was found

Scope (main): the 77 East Asia and Pacific volumes listed by title from manifest.json (1945-1980: Far East, China, Japan, Korea, Indochina/Vietnam, Southeast Asia, Indonesia, Philippines, Laos/Cambodia, Australasia; South Asia and Near East excluded; frus1958-60v15 'South and Southeast Asia' kept because it carries the Thailand OCB report; the microfiche supplement frus1955-57v03mSupp kept). The list is `SCOPE` in h.py. Query: `SELECT volume_id,COUNT(*),SUM(is_front_matter),SUM(is_editorial_note) FROM document_cache WHERE volume_id IN (<77 ids>) GROUP BY volume_id` returned 77 rows, 39,808 documents; `SELECT COUNT(*) FROM document_cache WHERE volume_id IN (<77>) AND is_front_matter=0 AND is_editorial_note=0` returned 38,059 (the denominator used below). No second edition (Ed2) volume is in the scope.

Scope (functional): 20 further volumes scanned for East Asian content (FUNC in scan.py: foreign information program, NSC and national-security volumes, organization of foreign policy, public diplomacy 1977-80); and, added after a vector-neighbour result, the three Public Diplomacy volumes frus1917-72PubDipv06, v07, v08 (509 non-apparatus documents of 547; scan in pubdip_scan.tsv).

Date span: documents of 1948-1977 are in the argument set; periodised on the document's own date (document_dates.date_iso), not on volume year. Inclusion rule for the collection: a document that (a) states an intended message, channel or audience belief for East Asia/Pacific, or (b) assesses the effect of such messaging, and which is not front matter or an editorial note; each reprint counted once (see section 6).

How found: (1) manifest titles gave the 77; (2) exploratory FTS counts (stemmed; used only to choose volumes; NOT published as findings, because no strict/tolerant share was taken for them) showed the information vocabulary clusters in the 1948-49 China volumes and the 1961-65 Vietnam volumes; (3) a whole-text regex scan (scan.py) over the 77 plus 20 functional volumes flagged candidate documents; (4) sentence scans (beliefs.py, asia_sent.py) for audience beliefs and effectiveness language; (5) vector nearest neighbours (section 6) revealed that I had missed the Public Diplomacy volumes, whose titles do not name the region; (6) they were scanned and six documents selected from them.

## 2. What was measured (audit form)

Counting surface for every regex number: `document_cache` header + dateline + body_text, whitespace-collapsed (the index's flattened text: editors' footnotes included, TEI tags not present; not the raw TEI and not word-bounded beyond the regex's own \b). Front matter and editorial notes excluded: `is_front_matter=0 AND is_editorial_note=0`. The TEI XML was not opened; any claim that depends on a footnote/body split or on spelling variants over TEI is not made.

### M3 Census of term families, 77 volumes (census.py; aggregated by census_agg.py; output census_out.txt)

SQL, run once per volume: `SELECT d.volume_id,d.document_id,d.header,d.dateline,d.body_text,dd.date_iso FROM document_cache d LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE d.volume_id=? AND d.is_front_matter=0 AND d.is_editorial_note=0 ORDER BY d.rowid`. Regexes (case-sensitive for acronyms): USIA = `\b(USIA|U\.S\.I\.A\.|United States Information Agency|U\.S\. Information Agency)\b`; USIS = `\b(USIS|United States Information Service|U\.S\. Information Service)\b`; VOA = `\b(Voice of America|VOA)\b`; psywar, exchange, info-program, public diplomacy, soft power, hearts and minds, positive and negative controls as in census.py (kept on disk). Because these are literal regexes over the text, there is no stem inflation; the family is a defined set of spellings, and variant counts are reported below, not merged away.

Results (documents with at least one match, of 38,059): USIA 375; USIS 402; VOA 179; psychological warfare/operations/strategy 320; cultural/educational exchange family 329; information program/activities family 187; public diplomacy 2; soft power 0; hearts and minds 15. CORE (USIA or USIS or VOA): 864 of 38,059. POSITIVE control `Department of State`: 14,998 documents, and zero of the 77 volumes lack a match. NEGATIVE control `ZZZ_IMPOSSIBLE_ZZZ`: 0 documents. Both controls ran in the same pass.

By decade (document's own date; core documents of dated documents in the 77 volumes; rate per 1,000; numerator's top-volume share): 1940s 196 of 13,688 = 14.3 per 1,000 (top volume frus1949v08, 88 of 196); 1950s 293 of 12,972 = 22.6 (frus1955-57v03mSupp, 30 of 293); 1960s 330 of 7,884 = 41.9 (frus1961-63v03, 41 of 330); 1970s 45 of 3,370 = 13.4 (frus1969-76v08, 12 of 45); 1980s 0 of 106. The 1940s numerator is 45% one volume (the 1949 China volume, USIS in Nationalist China), so the 1940s rate is not a regional rate; the 1950s top volume (the microfiche supplement on China, frus1955-57v03mSupp) holds 30 of 293, about one in ten. Quoted in the overview as 'about one in seventy / forty-four / twenty-four / seventy-five'.

False-friend test: the question's own term 'soft power' has 0 documents (below), so it measures nothing in this corpus; the editors' vocabulary used instead is the census families above.

### M4 'soft power', 'public diplomacy': zero and relaxed forms (zero_and_relaxed.txt)

`SELECT COUNT(*) FROM frus_documents f JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id WHERE frus_documents MATCH '"soft power"' AND d.is_front_matter=0 AND d.is_editorial_note=0` = 0 (all 553 volumes). Relaxed form on the same surface: MATCH `soft AND power` = 785 documents, of which the literal phrase `soft[\s-]+power` (case-insensitive regex over header+dateline+source_note+body, whole set) occurs in 0 of 785. `"public diplomacy"` = 211 FTS hits, STRICT regex share 210 of 211, TOLERANT 211 of 211 (whole set, under 300); 175 of 211 are in volumes of 1977-80 or 1981-88 (`volume_id LIKE 'frus1977%' OR 'frus1981%'`), eight in frus1917-72PubDipv08, seven in frus1969-76v38p2. In the 77 regional volumes: 2 of 38,059 (M3).

### M5 Candidate scan and topic slice (scan.py, scan_docs.tsv)

Regex families A (information agencies and programs, including 'propaganda'), B (prestige/image), C (audience terms), D (effect words), R (region words): definitions in scan.py. Over the 77 volumes, 38,059 documents: A>=1 in 4,085; A>=2 in 1,482; two or more distinct A terms in 622. Over the 20 functional volumes (5,117 documents): A>=1 in 913. Family A includes the word 'propaganda', which dominates its counts (A>=1 in 4,085 documents against 864 for the agency-name family in M3), so the census and the overview use agency names, not 'propaganda'. 'Topic slice' used for the pointed-at channel (M9): documents of the 77 volumes with >=2 distinct A terms and >=2 R words, plus PubDip documents with R>=8 or a region word in the header = 711 documents (pubdip_scan.tsv: `R>=8 or hR>=1` selected 114 of 509 PubDip documents).

### M6 Audience-belief and effectiveness sentences (beliefs.py, beliefs_hits.tsv)

Over 1,608 documents (scan_docs.tsv rows with A>=2 and R>=2), sentence splitter and regexes in beliefs.py: 381 sentences with a belief term and an information term; 145 of them name 'Asian(s)', 'Oriental(s)' or 'face'; 33 also carry an effect word. These were read as leads; the overview's belief claims rest only on the quotations in section 4.

### M7 Came-from channel, the 31 documents (archival_cameFrom.txt)

`SELECT repository,record_group,lot_file,series_name,citation_era,substr(raw_text,1,150) FROM document_sources WHERE volume_id=? AND document_id=?` for each of the 31. Result: State Department central files (record group 59; decimal 7, central foreign policy file 1) = 8; State lot files = 6 (lot 61 D 167 x2: 1952-54v12p2/d251 and d359; lot 63 D 351 x1: 1955-57v09/d190; lot 62 D 430 x2: 1955-57v22/d484 and 1958-60v15/d548; lot 61 D 385 x1: 1955-57v22/d447); record group 306 (USIA) = 8 (1961-63v02/d16, 1961-63v04/d81, PubDipv07/d32, v07/d85, v08/d31, v08/d99, v08/d149, 1977-80v30/d79); record group 305 as printed = 1 (1969-76v38p2/d105); Johnson Library = 5 (1964-68v01/d122, d177, v02/d160, v26/d106, v27/d386); Nixon Presidential Materials = 1 (1969-76v19p2/d67); record group 84 Saigon embassy = 1 (1961-63v02/d197); record group 34 as printed = 1 (1961-63v01/d49). 8+6+8+1+5+1+1+1 = 31. Channel: came-from. Volume set: the 31 documents' volumes.

### M8 Series resolution from the bundled JSON (archival_json.txt, archival_final.txt)

Scripts inline (logged): central-files-index.json `lotFiles` (list, key `lotNumber` with spaces folded) and series-facts-index.json `byNaId` (one-letter keys dereferenced through `legend`). Lot 61D167 -> record group 59 'Alphabetical Files', NAID 2198167, entries A1 1583A/A1 1583B, creator Policy Planning Council, 1948-1961, 'Restricted - Partly'. Lot 63D351 and lot 66D95 -> 'Records Relating to National Security Council Policy Papers', NAID 2839192, entry A1 1586E, Executive Secretariat, 1947-1979, 'Restricted - Partly', 26 linear feet 3 inches. Lot 62D430 -> 'Subject and Special Files', NAID 2839191, entry A1 1586C, 1953-1961 (coverage 1952-1961), 'Restricted - Partly', 4 linear feet 5 inches. Lot 62D1 -> 'Records Relating to Activities with the National Security Council', NAID 2838992, entries A1 1583E/A1 1583F, 1948-1961, 'Restricted - Partly'. Lot 61D385: 0 rows in the central-files index (unresolved). Lot 58D726 -> 'Subject Files' NAID 2544398 (Office of the Officer in Charge for Malaya Affairs, 1955-1956, 'Restricted - Possibly'), cited unprinted by 1955-57v22/d447.

USIA record group 306: the printed entries (UD WW 257, UD WW 193, A1 42, P 104, P 207; accession 72 A 5121, 68 A 4933, 67 A 222, 69 A 3445) are NOT resolved by the bundle. accession-series-index.json (key `<record group>/<accession>`, group matched) names 18 series for 306/72A5121, 15 for 306/68A4933 (including Subject Files of the Director NAID 1102141 and Vietnam Working Group Subject Files NAID 42125423, neither in series-facts), 3 for 306/67A222 and 9 for 306/69A3445, so an accession does not identify one series. central-files-index lot rows in record group 306 (17) include the nearest bundled series: Subject Files of the Director NAID 40967285 (lots 67D317, 67D333, 70D449; 1956-1972; 103 linear feet 1 inch; 'Restricted - Partly'); Subject Files NAID 1257679 (Office of Policy and Plans; lots 59D260, 61D445, HMS entries UD-WW 151, 197, 234, 264, 287, 288, 365, 366, 372, 379, 382; 1953-1971; 47 linear feet; 'Restricted - Partly'); Chronological Files NAID 40967113 (lot 64D171; 1961-1966; 10 linear feet 6 inches; 'Restricted - Partly'); Program Files NAID 1254251 (Office of Research and Intelligence, Intelligence Production Division; lot 60D147; 1954-1958; 9 linear feet 2 inches; 'Restricted - Partly'); Records Relating to the Voice of America NAID 7542975 (lot 59D242; 1948-1959; 6 linear feet 6 inches; 'Restricted - Partly'). None of the entry numbers UD WW 257, UD WW 193, A1 42, P 104, P 207 appears in any bundled JSON file (regex search with space and hyphen variants across all of them; archival_json.txt). The overview says so.

### M9 Pointed-at channel, topic slice (archival_pointed_at.txt)

`SELECT volume_id,document_id,repository,collection,lot_file_norm FROM external_citations WHERE volume_id IN (<volumes of the 711>)`, filtered in Python to the 711 slice documents: 392 rows (anchors) on 200 documents. By anchors / distinct documents: State Department, no lot, 181 / 95; lot 66D95, 24 / 19; Nixon Presidential Materials NSC Files, 33 / 17; Johnson Library National Security File, 19 / 13; lot 63D351, 12 / 8; Kennedy Library National Security Files, 9 / 7; lot 62D430, 9 / 8; lot 62D1, 8 / 7; lot 62D181 8 / 3; lot 74D417 5 (Files of Ambassador Ellsworth Bunker, RG 84, NAID 588795, unrestricted); Nixon White House Central Files 3 / 3. Channel: pointed-at. Limits stated in the brief hold: no rows before 1910-12-06; stores the citation fragment; lot, library and decimal anchors only. It is not summed with M7.

M10 Pre-1940 reach: series-facts-index.json `byNaId` rows with `y0` < 1940: 11 of 698 (about one in sixty-three). Re-derived here; the guide's 'one in sixty' is not repeated.

M11 USIA in the pointed-at channel: `SELECT COUNT(*) FROM external_citations WHERE raw_text LIKE '%RG 306%' OR raw_text LIKE '%Information Agency%' OR collection LIKE '%Information Agency%' OR repository LIKE '%Information Agency%'` = 11 (whole index). Came-from, whole index: `SELECT COUNT(*), COUNT(DISTINCT volume_id||'/'||document_id) FROM document_sources WHERE record_group='306'` = 427 rows, 427 documents.

## 3. Reading accounting

Retrieved whole (captured length = length(body_text)): 95 of 95 documents (fetched.tsv, one line each: volume, document, length(body_text), captured length, OK). Quoted from: 31 documents (the collection). Quotations: 39. The 64 other whole documents were retrieved to read and not used. Reading was by keyword-in-context windows (kwic.py) and full-text prints of the first several thousand characters for the documents in the set, so 'read' means passages, and the Doc-level claims in the overview use only the verified quotations and the facts stated in their notes.

Retrieval SELECT, for every whole-document fetch (parameters volume_id, document_id): `SELECT volume_id,document_id,header,dateline,source_note,body_text,length(body_text),is_front_matter,is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?`. Existence and exclusion check for the 31 (set_meta.txt): `SELECT d.document_number,substr(replace(d.header,char(10),' '),1,200),d.dateline,dd.date_iso,d.is_front_matter,d.is_editorial_note,length(d.body_text) FROM document_cache d LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE d.volume_id=? AND d.document_id=?` -> all 31 exist, is_front_matter=0, is_editorial_note=0. No Ed2 volume pairs with a first edition in the set.

## 4. Quotations (each verified by quotes.py as an exact substring of its whole document, whitespace collapsed)

| # | volume_id/document_id | retrieved by | quotation |
|---|---|---|---|
| Q1 | frus1948v07/d567 | SELECT in section 3 with (frus1948v07, d567); length 10877 = captured 10877 | If the United States is to win and retain moral leadership it must continue to discuss domestic conditions in the United States. |
| Q2 | frus1948v07/d567 | SELECT in section 3 with (frus1948v07, d567); length 10877 = captured 10877 | The Department considers the USIS newsletter to be the most effective method for reaching the influential middle group of educated Chinese |
| Q3 | frus1949v08/d499 | SELECT in section 3 with (frus1949v08, d499); length 15543 = captured 15543 | we should immediately and substantially expand USIS activities in all Southeast Asian countries. |
| Q4 | frus1949v07p2/d386 | SELECT in section 3 with (frus1949v07p2, d386); length 13086 = captured 13086 | A considerably expanded information program both in Communist and non-Communist areas of Asia is called for, both to demonstrate our understanding and sympathy for the nationalist aspirations of the Asian peoples and to expose the menace to these aspirations created by Soviet imperialism. |
| Q5 | frus1950v06/d50 | SELECT in section 3 with (frus1950v06, d50); length 6446 = captured 6446 | Comparatively few nationals understand the current policies of the United States or the history and tradition of this country. |
| Q6 | frus1952-54v13p1/d116 | SELECT in section 3 with (frus1952-54v13p1, d116); length 8958 = captured 8958 | All factors recited must be viewed as effective though degree cannot be accurately measured. |
| Q7 | frus1952-54v12p2/d251 | SELECT in section 3 with (frus1952-54v12p2, d251); length 29626 = captured 29626 | which is more affected by our actions than our words and which is hostile to propaganda from any source, especially non-Asian. |
| Q8 | frus1952-54v12p2/d251 | SELECT in section 3 with (frus1952-54v12p2, d251); length 29626 = captured 29626 | 2.5 percent may be opposed to United States aims, 1.5 percent favorable, and 96 percent “unsure” |
| Q9 | frus1952-54v12p2/d352 | SELECT in section 3 with (frus1952-54v12p2, d352); length 1756 = captured 1756 | widespread use in Philippines and elsewhere of slogan “Asia for Asians” would be most unfortunate. |
| Q10 | frus1952-54v12p2/d359 | SELECT in section 3 with (frus1952-54v12p2, d359); length 22856 = captured 22856 | During FY 1954 these services were reduced by approximately 65% because of lack of funds. |
| Q11 | frus1955-57v09/d190 | SELECT in section 3 with (frus1955-57v09, d190); length 51295 = captured 51295 | USIA concentrated on activities to strengthen the resolution of U.S. allies, orient Asian neutralists toward the U.S., and counter Communist attempts to soften Asian resistance to varied forms of penetration. |
| Q12 | frus1955-57v22/d447 | SELECT in section 3 with (frus1955-57v22, d447); length 3751 = captured 3751 | a fear of placing the U.S. in the position of appearing to support colonialism. |
| Q13 | frus1955-57v22/d484 | SELECT in section 3 with (frus1955-57v22, d484); length 23358 = captured 23358 | The USIA program emphasizes comprehensive anti-Communist indoctrination throughout Thailand. |
| Q14 | frus1958-60v15/d548 | SELECT in section 3 with (frus1958-60v15, d548); length 28532 = captured 28532 | U.S. informational, cultural and educational activities in Thailand are conducted against the background of difficulties of communication and lack of adequate media of expression common to most underdeveloped Asian countries. |
| Q15 | frus1961-63v01/d49 | SELECT in section 3 with (frus1961-63v01, d49); length 1711 = captured 1711 | We are in the process of cranking up a major propaganda campaign on Viet Cong insurgency in VietNam. |
| Q16 | frus1961-63v02/d16 | SELECT in section 3 with (frus1961-63v02, d16); length 5995 = captured 5995 | the image of the GVN in the world press can be no better than the face the GVN presents to the public |
| Q17 | frus1961-63v02/d197 | SELECT in section 3 with (frus1961-63v02, d197); length 5869 = captured 5869 | Replies to my superficial enquiries have been unanimous that the content of GVN propaganda is poor. |
| Q18 | frus1961-63v02/d197 | SELECT in section 3 with (frus1961-63v02, d197); length 5869 = captured 5869 | Does anyone have a really hard reading on how well GVN propaganda is working in the rural areas? |
| Q19 | frus1961-63v04/d81 | SELECT in section 3 with (frus1961-63v04, d81); length 10866 = captured 10866 | With Orientals in general and notably with the Ngo Dinhs, capitulation is virtually impossible |
| Q20 | frus1964-68v01/d122 | SELECT in section 3 with (frus1964-68v01, d122); length 4492 = captured 4492 | the weakest part of the war operation, both on our part and that of the Government of South Viet-Nam, is in the field of information and psychological warfare. |
| Q21 | frus1964-68v01/d122 | SELECT in section 3 with (frus1964-68v01, d122); length 4492 = captured 4492 | I was informed that the program is a failure in several provinces because of the lack of small bits of money to pay for such things as the running of a projector, or paper on which to print leaflets. |
| Q22 | frus1964-68v02/d160 | SELECT in section 3 with (frus1964-68v02, d160); length 6213 = captured 6213 | efforts to develop among the South Vietnamese people a sense of national unity and a determination to fight off Communist aggression, have not progressed to my satisfaction. |
| Q23 | frus1917-72PubDipv07/d32 | SELECT in section 3 with (frus1917-72PubDipv07, d32); length 27974 = captured 27974 | Vietnamese peasants are, in the main, going to be persuaded by other Vietnamese. |
| Q24 | frus1917-72PubDipv07/d32 | SELECT in section 3 with (frus1917-72PubDipv07, d32); length 27974 = captured 27974 | The number one problem in Vietnam is motivation. |
| Q25 | frus1917-72PubDipv07/d85 | SELECT in section 3 with (frus1917-72PubDipv07, d85); length 19705 = captured 19705 | I think it came as a surprise to most Americans that there is an unfortunately large amount of anti-Americanism under the surface in Viet-Nam. |
| Q26 | frus1964-68v26/d106 | SELECT in section 3 with (frus1964-68v26, d106); length 8250 = captured 8250 | We shall soon have nothing worthwhile left in the way of an information operation. |
| Q27 | frus1964-68v27/d386 | SELECT in section 3 with (frus1964-68v27, d386); length 1589 = captured 1589 | The Thai Government has not given proper attention to the need for a national information program designed to gain popular support. |
| Q28 | frus1917-72PubDipv08/d31 | SELECT in section 3 with (frus1917-72PubDipv08, d31); length 20792 = captured 20792 | Asians are, to varying degrees, America watchers. |
| Q29 | frus1917-72PubDipv08/d31 | SELECT in section 3 with (frus1917-72PubDipv08, d31); length 20792 = captured 20792 | PAOs emphasized that the image of the US usually depended more on the state of bi-lateral relations (security treaty, Okinawa, Korean military modernization, trade restrictions) than on developments within the US. |
| Q30 | frus1917-72PubDipv08/d31 | SELECT in section 3 with (frus1917-72PubDipv08, d31); length 20792 = captured 20792 | Many PAOs reported uncertainty as to the direction of US foreign policy and especially the strength of US commitments in Asia. |
| Q31 | frus1917-72PubDipv08/d99 | SELECT in section 3 with (frus1917-72PubDipv08, d99); length 25695 = captured 25695 | The President’s concept of partnership suggests that the U.S. will have to lower its voice. |
| Q32 | frus1917-72PubDipv08/d149 | SELECT in section 3 with (frus1917-72PubDipv08, d149); length 10253 = captured 10253 | The predominant mood is apolitical, seeking to be neutral, and concerned with economic and trade problems rather than strong ideological convictions. |
| Q33 | frus1969-76v19p2/d67 | SELECT in section 3 with (frus1969-76v19p2, d67); length 3697 = captured 3697 | public opinion surveys and other assessments of Japanese attitudes have tended to confirm the seriousness of these strains. |
| Q34 | frus1969-76v38p2/d105 | SELECT in section 3 with (frus1969-76v38p2, d105); length 11622 = captured 11622 | During this waiting period, programs on U.S. security relations in Asia lack credibility and may in fact do damage to our relations. |
| Q35 | frus1969-76v38p2/d105 | SELECT in section 3 with (frus1969-76v38p2, d105); length 11622 = captured 11622 | contrast between USG words and deeds re Indochina are not lost on the Burmese. |
| Q36 | frus1977-80v22/d104 | SELECT in section 3 with (frus1977-80v22, d104); length 13536 = captured 13536 | Rather than being reassured, the ASEAN countries and Japan interpreted our apparent unwillingness to come to grips with the “new realities” as another indication that the United States, after twenty years of exaggerating the extent of its interests in Southeast Asia, might now decide it had no interest there at all. |
| Q37 | frus1977-80v30/d79 | SELECT in section 3 with (frus1977-80v30, d79); length 2409 = captured 2409 | shoring up the confidence of East Asians in America’s long-term staying power and positive involvement in the area is real and necessary. |
| Q38 | frus1949v07p2/d127 | SELECT in section 3 with (frus1949v07p2, d127); length 28479 = captured 28479 | Our insistence that our way is right and the Japanese way is wrong does not make sense to many Japanese who detect a latent ignorance and lack of understanding of the Oriental in our endeavors to impose American methods and way of life |
| Q39 | frus1964-68v01/d177 | SELECT in section 3 with (frus1964-68v01, d177); length 8229 = captured 8229 | Increased Voice of America broadcasting into North Viet-Nam and made arrangements for a broad expansion of VOA broadcasts in Vietnamese in early July. |

The overview quotes 34 straight-quoted strings; verify_overview.py checks each of length >= 10 against the 31 documents and finds all but the five that are not quotations (the terms soft power, public diplomacy, policymakers). The overview's one apostrophe-sensitive quotation uses the document's own curly apostrophe.

## 5. The collection

collection.fruscollection: 31 document entries, 39 excerpt entries, five headings with prose entries, a closing prose entry naming the threads not followed, and a closing generated archivalSources block; format 'fruscollection', formatVersion 2, minimumReaderVersion 1; all seven keys of the example's composition block present (defaultBodyDepth, footnoteStyle, includeSourceNote, tocStyle, applyHighlights, includeNotes, includeWordCloud). build_collection.py checks that every document and excerpt entry has both ids, that each pair exists in document_cache with is_front_matter=0 and is_editorial_note=0 (`SELECT is_front_matter,is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?`), that no document pair repeats, that no volume id ends in Ed2, and that every excerpt is an exact substring of its document. Result: documents 31, excerpts 39, bad 0, set equals the 31 listed in collection_set.txt. Not tested: opening the file in the app (not available in this session).

The 31 documents (volume/document, date, header):

- frus1948v07/d567, 1948-12-24, The Secretary of State to the Ambassador in China (Stuart)
- frus1949v08/d499, 1949-07-14, Memorandum by the Ambassador in China (Stuart)
- frus1949v07p2/d386, 1949-11-16, Memorandum by the Ambassador at Large (Jessup) to the Secretary of State
- frus1949v07p2/d127, 1949-08-20, The Acting Political Adviser in Japan (Sebald) to the Secretary of State
- frus1950v06/d50, 1950-06-21, Memorandum by the Under Secretary of State (Webb) to the President
- frus1952-54v13p1/d116, 1952-09-20, The Ambassador at Saigon (Heath) to the Department of State
- frus1952-54v12p2/d251, 1953-08-27, 251 Memorandum by the Secretary of State and the Acting Secretary of Defense (Anderson) to
- frus1952-54v12p2/d352, 1954-02-13, 352 The Acting Secretary of State to the Embassy in the Philippines
- frus1952-54v12p2/d359, 1954-04-05, 359 Memorandum by the Executive Secretary (Lay) to the National Security Council
- frus1955-57v09/d190, 1955-08-31, 190. Report Prepared by the National Security Council
- frus1955-57v22/d447, 1955-12-05, 447. Memorandum From the Assistant Secretary of State for Far Eastern Affairs (Robertson) 
- frus1955-57v22/d484, 1956-01-04, 484. Staff Study Prepared by an Interdepartmental Working Group for the Operations Coordin
- frus1958-60v15/d548, 1960-05-01, 548. Report Prepared by the Operations Coordinating Board
- frus1961-63v01/d49, 1961-05-09, 49. Letter From the Deputy Assistant Director, Far East, of the United States Information 
- frus1961-63v02/d16, 1962-01-12, 16. Memorandum From the Assistant Director for East Asian and Pacific Affairs, United Stat
- frus1961-63v02/d197, 1962-05-17, 197. Memorandum From the Public Affairs Officer at the Embassy in Vietnam (Mecklin) to the
- frus1961-63v04/d81, 1963-09-10, 81. Memorandum From the Counselor for Public Affairs of the Embassy in Vietnam (Mecklin) t
- frus1964-68v01/d122, 1964-04-21, 122. Memorandum From the Director of the United States Information Agency (Rowan) to the P
- frus1964-68v01/d177, 1964-05-26, 177. Memorandum From the Director of the United States Information Agency (Rowan) to the P
- frus1964-68v02/d160, 1965-02-24, 160. Memorandum From the Director of the United States Information Agency (Rowan) to Presi
- frus1917-72PubDipv07/d32, 1964-10-30, 32. Memorandum From James N. Tull of the Office of the Assistant Director for Far East, Un
- frus1917-72PubDipv07/d85, 1966-04-15, 85. Memorandum From the Deputy Assistant Director, Viet-Nam Affairs, Office of the Assista
- frus1964-68v26/d106, 1965-02-18, 106. Memorandum From Director of the United States Information Agency Rowan to Secretary o
- frus1964-68v27/d386, 1968-05-06, 386. Memorandum From the Director of the United States Information Agency (Marks) to Presi
- frus1917-72PubDipv08/d31, 1969-08-05, 31. Letter From the Assistant Director, East Asia and the Pacific, United States Informati
- frus1917-72PubDipv08/d99, 1970-07-30, 99. Paper Prepared in the United States Information Agency
- frus1917-72PubDipv08/d149, 1971-11-23, 149. Memorandum From the Deputy Assistant Director, Office of the Assistant Director, East
- frus1969-76v19p2/d67, 1971-02-16, 67. Memorandum From the Director of the U.S. Information Agency (Shakespeare) to the Presi
- frus1969-76v38p2/d105, 1975-05-09, 105. Memorandum From the Assistant Director for East Asia and the Pacific, United States I
- frus1977-80v22/d104, 1977-02-07, 104. Telegram From the Consulate in Hong Kong to the Department of State
- frus1977-80v30/d79, 1977-07-19, 79. Information Memorandum From the Assistant Director, East Asia and the Pacific, United 
## 6. VECTORS

Provenance check before any scoring (vec.py): the 32-byte provenance digest is 89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101 in semantic-vectors-index.json (`provenanceDigest`), at offset 20 of semantic-vectors-binary.bin, at offset 20 of semantic-map.bin, and in the header of all 553 shards under SemanticVectors/ (553 of 553 match; no mismatch; no generation mixed). Index `generated` 2026-10-15, `harvestGenerated` 2026-10-15T06:55:14, model embeddinggemma-2-Q8_0, 314,616 documents, 512 dimensions, `retrieval.measuredRecallAt10` 0.9021 (so about one of any document's ten true neighbours is absent from the funnel; no 'no similar document' claim is made anywhere). Ids come only from the index segments (decode round trip asserted for all 553 volumes in vec.py).

Baselines at this digest (vec_baselines.txt): random pairs, 20,000 drawn with `random.Random(1877)`: mean Hamming 167.1, sd 14.8, 1st percentile 132, minimum 95 of 512. k-th nearest neighbour over a 200-document sample (`random.Random(2026)`): 1st neighbour median 83 (quartiles 75, 91); 10th neighbour median 100 (94, 108); 25th neighbour median 106 (100, 113). Calibration for cosines shown to a reader: documents-to-documents `(cosine - 0.40) / 0.60`, from `retrieval.scoreCalibration` (documentOffset 0.40); labelled 'calibrated' below; a raw cosine is labelled raw.

**Operation 1: nearest neighbours of a document.** File: semantic-vectors-binary.bin (sign bits, Hamming) with the top 800 reranked by int8 cosine from the SemanticVectors shards (nn.py, the funnel of Appendix A.6). Anchors and findings (full lists in nn_run1.txt, nn_run2.txt): frus1964-68v01/d122 (Rowan, April 1964): nearest is frus1917-72PubDipv07/d13 at Hamming 45 (calibrated 0.962), a reprint of the same memorandum; then Rowan memoranda PubDipv07/d37 (73), v07/d16 (82), frus1964-68v01/d177 (83), frus1964-68v02/d160 (100): the first four are inside the 1st-neighbour median (83) or better, the fifth is typical of a 10th neighbour. frus1952-54v13p1/d116 (Heath 1952): neighbours at Hamming 85 to 106 (calibrated 0.823 to 0.843), i.e. at the 1st-to-10th-neighbour medians and not unusual: it led to frus1917-72PubDipv08/d31, PubDipv06/d142 and PubDipv07/d32 (a first signal that the Public Diplomacy volumes were missing from my scope). frus1969-76v38p2/d105 (1975 East Asia reassessment): neighbours at Hamming 76 to 96, including frus1977-80v22/d104 (82, calibrated 0.858; the Sullivan telegram from Hong Kong, used) and frus1917-72PubDipv08/d31 (96). frus1917-72PubDipv08/d31 (Manila conference 1969): neighbours at 81 to 104, including frus1917-72PubDipv08/d99 (90, calibrated 0.858; the 1970 Agency Program Memorandum, used). frus1961-63v02/d197 (Mecklin 1962): neighbours at 92 to 111 (8 of 10 above the 10th-neighbour median of 100), a weak neighbourhood; none used. frus1952-54v12p2/d251 and frus1955-57v22/d447: neighbours are the same-series Indonesia and Malaya documents (Hamming 65 to 114), used only to confirm that no further East Asia information document was missed in those series. These are suggestions with distances, not evidence of a relationship; each used document was read whole before use. Every neighbour's volume is present in the index (nn.py flags absences; none flagged).

**Operation 2: semantic join into the database.** Files: the same funnel; join into `document_dates` and `document_sources`. For the top 25 neighbours of each of four anchors (d122, d116, PubDipv08/d31, v38p2/d105) there are 82 distinct documents (vecjoin_out.txt). `SELECT date_iso FROM document_dates WHERE volume_id=? AND document_id=?` and `SELECT repository, record_group, series_name FROM document_sources WHERE volume_id=? AND document_id=?` per neighbour. By decade: 1950s 20, 1960s 41, 1970s 20, 1980s 1. By source: record group 59 (Department of State) 25, record group 306 (USIA) 23, Johnson Library 9, no source row 7, Ford Library 4, Kennedy Library 3, Nixon Presidential Materials 2. 32 of the 82 are inside the 77-volume scope and 50 outside it (public diplomacy and functional volumes). Baseline: none is like-for-like, so this is read as a pointer to USIA's own files (record group 306) as the dominant archive of semantically close material, not as a measure.

**Operation 3: centroid similarity.** File: the 660 centroids after the sign block of semantic-vectors-binary.bin (volume centroids in index order), raw cosine (not calibrated; no baseline computed beyond the ranking). Nearest volumes: frus1917-72PubDipv07 -> PubDipv06 0.987, PubDipv08 0.981, frus1977-80v30 0.973, frus1964-68v33 0.965, frus1961-63v25 0.965; frus1977-80v30 -> PubDipv08 0.976, v07 0.973, v06 0.970, frus1977-80v28 0.962, frus1969-76v38p2 0.961; frus1955-57v09 -> frus1958-60v04 0.985, frus1952-54v01p1 0.983, frus1964-68v09 0.983. Finding: the three Public Diplomacy volumes and the 1977-80 Public Diplomacy volume form one neighbourhood, consistent with the 1917-72 series being a missed block; the Eisenhower foreign information volume sits with foreign economic policy volumes, so its centroid does not mark it as information-specific.

**Operation 4: the map.** Files: semantic-map.bin (placements; 6 bytes per document) and semantic-map-index.json (140 clusters; labels are c-TF-IDF terms over a sample). The 31 collection documents: 7 of 31 unclustered (22.6%); baseline on this layout, era-matched: volumes dated 1945-1980 by the mean of first and last year, 40,679 of 141,003 placements unclustered (28.8%); corpus-wide 88,059 of 314,616 (28.0%). Clusters of the 31: cluster 29 (lao, vietnamese, vietnam, thieu) 13; cluster 32 (sukarno, indonesian, indonesia, nasution) 3; cluster 3 (nanking, shanghai, chinese, tientsin) 2; cluster 7 (japanese, sato, japan, kishi) 2; cluster 138 (cia, nsc, usia, inglis) 2; cluster 20 and cluster 5 one each. The map is a 2-D projection used only to explore; nothing in the overview depends on it.

**Operation 5: near-duplicates.** File: the sign bits; Hamming over the 31 and each one's three nearest corpus neighbours (vecops_out.txt, dupcheck.txt). Inside the set, one pair is below 70: frus1955-57v22/d484 and frus1958-60v15/d548 at 63 (two OCB Thailand documents of 1956 and 1960; not reprints, both kept). Against the corpus: frus1964-68v01/d122 with frus1917-72PubDipv07/d13 at 45; frus1964-68v01/d177 with PubDipv07/d16 at 37; frus1961-63v04/d81 with PubDipv06/d140 at 53; frus1949v07p2/d386 with frus1951v06p1/d12 at 49 (different documents; not a reprint, checked by header); frus1955-57v09/d190 with d185 at 32 (successive reports of one series, different periods). Text check by difflib over the first 3,000 characters: 0.786 (d122 v. PubDipv07/d13), 0.884 (d177 v. PubDipv07/d16), 0.747 (v04/d81 v. PubDipv06/d140): same author and date with different annotation, so I treat them as reprints and count each memorandum once, citing the regional volume's copy. All three are below the 1st-neighbour median of 83.

**Documents in the overview reached through a vector operation and through no full-text query:** frus1917-72PubDipv08/d99 and frus1977-80v22/d104 only. frus1917-72PubDipv07/d32, frus1917-72PubDipv07/d85, frus1917-72PubDipv08/d31 and frus1917-72PubDipv08/d149 were found by a regex scan of the three Public Diplomacy volumes (pubdip_scan.tsv), a full-text pass, but I would not have run that pass on those volumes without the Operation 1 result that put them in view. The remaining 25 documents were found by the title list, the regex scans and the sentence scans, before or without vectors.

## 7. TRACE TABLE (overview item -> memo line)

| overview item | memo line |
|---|---|
| 'Thirty-one documents', 'drawn from volumes between 1948 and 1977', 'the collection orders the 31 documents' | section 5; section 2 M-date span |
| 'no document' for 'soft power' in all 553 volumes; '785 documents' with both words, none using the phrase | M4 |
| 'Department of State' occurs in documents of every one of the 77 volumes; a nonsense string finds nothing | M3 (controls) |
| '211 documents' with public diplomacy; '175 of them' from 1977 on; 'only two among the 38,059 documents' | M4; M3 |
| '77 East Asia and Pacific volumes'; '38,059 documents'; 'all 553 volumes' | section 1; M0.1 |
| 'about one in seventy / forty-four / twenty-four / seventy-five' (1940s/50s/60s/70s) | M3 decade table |
| 'eight ... central files; six ... lot files; eight ... USIA (record group 306); five ... Johnson Library; the other four (two embassy, one Nixon, one record group 305)' | M7 |
| lot 61 D 167 (A1 1583A/B, 2198167, 1948-1961); lot 63 D 351 (A1 1586E, 2839192, 1947-1979); lot 62 D 430 (A1 1586C, 2839191, 1953-1961); lot 61 D 385 unidentified | M8 |
| USIA entries UD WW 257, UD WW 193, A1 42, P 104, P 207; accessions 72 A 5121, 68 A 4933 | M7; M8 |
| nearest USIA series 40967285, 1257679, 40967113 with dates, extents and access | M8 |
| '711 documents', '392 pointers on 200 documents', 181, 33, 19, 9, 9; lots 66 D 95, 63 D 351, 62 D 1 (2838992, 1948-1961) | M9; M8 |
| '11 footnote pointers' naming USIA files in the whole index | M11 |
| research shelf: 1254251 (1954-1958), 1257679, 7542975 (1948-1959) | M8 |
| '11 of the 698 series' before 1940 | M10 |
| 'I retrieved 95 documents whole ... quoted from 31' | section 3 |
| 'three volumes of public diplomacy ... held the Vietnam, Manila and 1970 papers' | section 6, Operation 1 and final paragraph |
| 'fourteen steps' (Rowan, May 1964) | Q of frus1964-68v01/d177 (item list 1 to 14 in the source; counted in the session, section 4 row for d177) |
| 'about two-thirds' cut to press services (Philippines, FY 1954) | Q (frus1952-54v12p2/d359): 'reduced by approximately 65%' |
| '28 top leaders' paraphrased as 'a small group of leaders' (Thailand) | document frus1955-57v22/d484 (read whole; fetched.tsv) |
| '2.5 percent of 80 million ... 1.5 percent ... 96 percent' | Q (frus1952-54v12p2/d251) second quotation; '80 million' is in the same sentence of the document |
| quotation "middle group" | section 4, Q2 (frus1948v07/d567) |
| quotation "If the United States is to win and retain moral leadership it must continue to discuss dom" | section 4, Q1 (frus1948v07/d567) |
| quotation "A considerably expanded information program both in Communist and non-Communist areas of A" | section 4, Q4 (frus1949v07p2/d386) |
| quotation "The USIA program emphasizes comprehensive anti-Communist indoctrination throughout Thailan" | section 4, Q13 (frus1955-57v22/d484) |
| quotation "more affected by our actions than our words" | section 4, Q7 (frus1952-54v12p2/d251) |
| quotation "Asia for Asians" | section 4, Q9 (frus1952-54v12p2/d352) |
| quotation "which is more affected by our actions than our words and which is hostile to propaganda fr" | section 4, Q7 (frus1952-54v12p2/d251) |
| quotation "a fear of placing the U.S. in the position of appearing to support colonialism" | section 4, Q12 (frus1955-57v22/d447) |
| quotation "The predominant mood is apolitical, seeking to be neutral, and concerned with economic and" | section 4, Q32 (frus1917-72PubDipv08/d149) |
| quotation "degree cannot be accurately measured" | section 4, Q6 (frus1952-54v13p1/d116) |
| quotation "a really hard reading" | section 4, Q18 (frus1961-63v02/d197) |
| quotation "the weakest part of the war operation" | section 4, Q20 (frus1964-68v01/d122) |
| quotation "not progressed to my satisfaction" | section 4, Q22 (frus1964-68v02/d160) |
| quotation "nothing worthwhile left" | section 4, Q26 (frus1964-68v26/d106) |
| quotation "All factors recited must be viewed as effective though degree cannot be accurately measure" | section 4, Q6 (frus1952-54v13p1/d116) |
| quotation "the weakest part of the war operation, both on our part and that of the Government of Sout" | section 4, Q20 (frus1964-68v01/d122) |
| quotation "Does anyone have a really hard reading on how well GVN propaganda is working in the rural " | section 4, Q18 (frus1961-63v02/d197) |
| quotation "persuaded by other Vietnamese" | section 4, Q23 (frus1917-72PubDipv07/d32) |
| quotation "Vietnamese peasants are, in the main, going to be persuaded by other Vietnamese" | section 4, Q23 (frus1917-72PubDipv07/d32) |
| quotation "The Thai Government has not given proper attention to the need for a national information " | section 4, Q27 (frus1964-68v27/d386) |
| quotation "an unfortunately large amount of anti-Americanism under the surface in Viet-Nam" | section 4, Q25 (frus1917-72PubDipv07/d85) |
| quotation "lower its voice" | section 4, Q31 (frus1917-72PubDipv08/d99) |
| quotation "lack credibility" | section 4, Q34 (frus1969-76v38p2/d105) |
| quotation "the confidence of East Asians in America’s long-term staying power" | section 4, Q37 (frus1977-80v30/d79) |
| quotation "PAOs emphasized that the image of the US usually depended more on the state of bi-lateral " | section 4, Q29 (frus1917-72PubDipv08/d31) |
| quotation "During this waiting period, programs on U.S. security relations in Asia lack credibility a" | section 4, Q34 (frus1969-76v38p2/d105) |
| quotation "Rather than being reassured, the ASEAN countries and Japan interpreted our apparent unwill" | section 4, Q36 (frus1977-80v22/d104) |

## 8. Flags and limits

- Thin or partial: Japan, Korea and Australasia contribute few documents to the argument (three to four each); the argument rests mostly on Vietnam, Thailand and Indonesia plus USIA's own regional office. 'Soft power' as attraction (exchanges, libraries) has one passage on exchange policy in the set; the exchange documents found were descriptive. This is a property of what FRUS prints and of my selection, not of the library.
- Every effectiveness judgment is by the programme's own officer; no independent measure appears. The overview says so.
- The belief claims report officials' words in the period's vocabulary ('Orientals', 'face'); they are beliefs, not findings about audiences.
- Reprints: three pairs counted once (section 6, Operation 5).
- The Tier-2 shard and Tier-1 results are leads; recall 0.9021.
- The first-pass miss of the Public Diplomacy volumes is the main scoping risk: other volumes whose titles do not name the region may hold East Asia items; the 20 functional volumes and the three Public Diplomacy volumes were scanned, others were not.
- 'Hearts and minds' (15 documents) and 'psychological warfare' (320) were counted but are not used as findings; the PsyOps material is in the collection only through the Vietnam documents.
- Not done: the app was not opened on the collection file; the TEI XML was not read; the NARA harvest was not available.
