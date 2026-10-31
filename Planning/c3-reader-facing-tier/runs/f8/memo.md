# Scope memo: American "soft power" in East Asia and the Pacific, as FRUS records it

Run directory: /Users/jbotts/frus-analysis/c3f/runs/f8. Date of run: 2026-10-31. Operator memo; the historian's text is overview.md.

Question as asked: How did policymakers assess American soft power in the East Asia and Pacific region? What messaging strategies did they use and how effective did they think they were? What beliefs about the regional audience contributed to those strategies?

## 1. Coverage and read-only proof

Canary (first call), exact output `553|321749|1103|8481`:

    sqlite3 "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro" "SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;"

M1. 553 volumes, 321,749 document rows, 1,103 front-matter rows, 8,481 editorial notes. The library holds all 553 volumes of the series, so in this copy "what I downloaded" equals the full series; every count below is conditional on this 553-volume index taken 2026-10-25.

Read-only proof (second call) failed as required: `Error in 3rd command line argument: attempt to write a readonly database` (rc=1).

## 2. Scope chosen, and how I found it

Inclusion rule: (a) every volume whose manifest title names East Asia, the Pacific, the Far East, or a country of the region, 1945 onward (75 volumes: `ea_vols.txt`); plus (b) eleven thematic volumes on information, psychological warfare and public diplomacy (`thematic_vols.txt`), searched only with region words. Apparatus excluded (is_front_matter=0 AND is_editorial_note=0). No Ed2 volume falls in either list. Date span of the read set: 1949-08-19 to 1980-11-20 (document dates, document_dates.date_iso = frus:doc-dateTime-min).

How found:
- `vol_candidates.txt`: manifest titles matching region and information words, volumeId >= 'frus1945'. **Error and correction:** that string filter silently dropped the three volumes `frus1917-72PubDipv06/v07/v08` (Public Diplomacy 1961–1963, 1964–1968, 1969–1972), because '1917' sorts before '1945'. I found them later through collection-authority.json, confirmed them in the index (`SELECT volume_id, COUNT(*) FROM document_cache WHERE volume_id LIKE 'frus1917-72PubDip%' AND is_front_matter=0 AND is_editorial_note=0 GROUP BY volume_id;` -> PubDipv06 152, v07 178, v08 179, PubDip (WWI) 38) and added v06–v08 to the thematic list. Four of the 22 cited documents come from them.
- Chapter headings (`headings_all.txt`, SQL `SELECT volume_id, structure_json FROM volume_structures WHERE volume_id>='frus1945'`): the regional volumes have **no** chapter on information or psychological programs; the subject is scattered. The editors' own headings for it sit in thematic volumes: "The United States Foreign Information Program" (frus1952-54v02p2), "United States Foreign Information Program" (frus1955-57v09), "Information Policy" (frus1961-63v25), "International Information Policy, Public Diplomacy, and Cultural Affairs" (frus1969-76v38p2), "Public Diplomacy" (frus1977-80v30), "Psychological and Political Warfare" (frus1945-50Intel). Contemporary formula: "information program", "psychological strategy/warfare", "USIS/USIA", "public diplomacy" (from the 1960s).

M2. Regional scope size: `SELECT COUNT(*) FROM document_cache WHERE volume_id IN (<ea_vols.txt, 75 volumes>) AND is_front_matter=0 AND is_editorial_note=0` -> **37,203**.
M3. Thematic scope size: `SELECT COUNT(*), COUNT(DISTINCT volume_id) FROM document_cache WHERE volume_id IN (<thematic_vols.txt, 11 volumes>) AND is_front_matter=0 AND is_editorial_note=0;` -> **3,326 | 11**.
M4. Combined: 86 volumes, 37,203 + 3,326 = **40,529** documents (arithmetic on M2 and M3; the two lists do not overlap).

## 3. What I measured

### 3.1 Term scan with controls (regional scope, 75 volumes)

Script `fts_scan.py`; per term: `SELECT COUNT(*), COUNT(DISTINCT dc.volume_id) FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid WHERE frus_documents MATCH ? AND dc.volume_id IN (<ea_vols>) AND dc.is_front_matter=0 AND dc.is_editorial_note=0`. Output `fts_scan_ea.tsv`. Counting surface: the index (stemmed, flattened, footnotes included). These are search-match counts, not literal counts; only the families in 3.2 carry a literal share.

| term (MATCH) | docs | volumes |
|---|---|---|
| "Department of State" (positive control) | 14,549 | 75 of 75 |
| "ZZZ_IMPOSSIBLE_ZZZ" (negative control) | 0 | 0 |
| "psychological warfare" | 253 | 57 |
| "psychological strategy" | 15 | 7 |
| "information program" | 139 | 42 |
| "information programs" | 139 | 42 (identical: stemming folds the plural) |
| USIS | 604 | 54 (unusable, see 3.2) |
| USIA | 305 | 47 |
| "Voice of America" | 75 | 31 |
| "American prestige" / "U.S. prestige" | 45 / 60 | 31 / 35 |
| "image of the United States" | 4 | 3 |
| "Asian opinion" | 38 | 21 |
| "exchange of persons" | 44 | 20 |

M5. **"soft power"** (the question's own term; false-friend / anachronism test): `SELECT COUNT(*), COUNT(DISTINCT dc.volume_id) FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid WHERE frus_documents MATCH '"soft power"' AND dc.is_front_matter=0 AND dc.is_editorial_note=0;` -> **0 | 0** over all 553 volumes. The same query form returns rows for the positive control above, so the zero is real: the term postdates the record. I used the contemporaries' vocabulary instead (3.1, 3.3).

### 3.2 Literal shares (house rule (a)); script `literal_share.py`, output `literal_share.json`

Hit list per family: `SELECT dc.volume_id, dc.document_id FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid WHERE frus_documents MATCH ? AND dc.volume_id IN (<ea_vols>) AND dc.is_front_matter=0 AND dc.is_editorial_note=0 ORDER BY dc.volume_id, dc.document_id`. Text tested: header+dateline+source_note+body_text, whitespace-collapsed, Python `re` with IGNORECASE (used for every family). Census when the set is under 300, else evenly spaced sample of 40.

| family | set | checked | STRICT | TOLERANT (published) |
|---|---|---|---|---|
| "information program" | 139 | census | 123 of 139 | 123 of 139 |
| "psychological warfare" | 253 | census | 253 of 253 | 253 of 253 |
| "Voice of America" | 75 | census | 75 of 75 | 75 of 75 |
| "psychological strategy" | 15 | census | 15 of 15 | 15 of 15 |
| USIA | 305 | sample 40 | 40 of 40 | 40 of 40 |
| USIS | 604 | sample 40 | 25 of 40 | 25 of 40 -> **unusable** |

Misses read: "information program" misses are "informational program(s)" (e.g. frus1949v09/d558 "cultural and informational program"), the same referent, so the family is usable at 123 of 139. USIS misses are "USI" = United States of Indonesia (frus1948v06/d103, frus1949v07p1/d192, frus1947v06/d828: the stemmer folds USIS to the stem of USI). A different referent; USIS is therefore excluded from every counted set. The 1.000 shares test the stemmer only; the referent of the topic set was tested by reading (section 4).

### 3.3 Topic set and its decade shape; script `topic_decades.py`, output `topic_decades.txt`, ids `topic_set.tsv`

    SELECT dc.volume_id, dc.document_id, substr(dd.date_iso,1,4) FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid
    LEFT JOIN document_dates dd ON dd.volume_id=dc.volume_id AND dd.document_id=dc.document_id
    WHERE frus_documents MATCH '"psychological warfare" OR "psychological strategy" OR "information program" OR USIA OR "Voice of America"'
    AND dc.volume_id IN (<ea_vols>) AND dc.is_front_matter=0 AND dc.is_editorial_note=0 AND dc.volume_id NOT LIKE '%Ed2'

M6. **701** documents in **69 of 75** regional volumes. (Thematic volumes not included in this set.)
Denominator per decade: `SELECT substr(dd.date_iso,1,3)||'0s', COUNT(*) FROM document_cache dc JOIN document_dates dd ON dd.volume_id=dc.volume_id AND dd.document_id=dc.document_id WHERE dc.volume_id IN (<ea_vols>) AND is_front_matter=0 AND is_editorial_note=0 AND dd.date_iso IS NOT NULL GROUP BY 1`. Periodised on frus:doc-dateTime-min (date_iso).

| decade | topic docs | dated docs in scope | per 1,000 | top volume (share of numerator) |
|---|---|---|---|---|
| 1940s | 57 | 13,688 | 4.2 | frus1949v09, 17 of 57 |
| 1950s | 275 | 12,972 | 21.2 (M7) | frus1955-57v22, 27 of 275 |
| 1960s | 311 | 7,028 | 44.3 (M8) | frus1961-63v02, 35 of 311 |
| 1970s | 58 | 3,370 | 17.2 | frus1969-76v08, 20 of 58 |
| 1980s | 0 | 106 | 0.0 | — |

Undated: 0. Density caveat: body_text includes editors' footnotes; I have not separated document text from apparatus for these rates (the index cannot).

### 3.4 Audience research (polling) scan, both scopes (86 volumes); output `survey_scan.txt`, `survey_literal.txt`

Same SELECT form over `all_scope_vols.txt`:
- "Department of State": 15,961 docs, 86 of 86 volumes (positive control). "ZZZ_IMPOSSIBLE_ZZZ": 0 (negative control).
- M9. ("opinion poll" OR "opinion survey" OR "attitude survey" OR "public opinion survey") AND (USIA OR USIS OR "Office of Research"): **27** docs in 11 volumes; literal census STRICT 27 of 27, TOLERANT 27 of 27. Of these, **one** is in a regional volume (frus1964-68v29p2/d46); the other 26 are in thematic volumes and mostly global in subject (listing in survey_scan.txt).
- Without the agency clause: 58 docs in 29 volumes; census STRICT 58 of 58, TOLERANT 58 of 58.

## 4. Reading

Retrieval SELECT (`dump.py`): `SELECT header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?`, written to `raw/<volume>_<doc>.txt`; lengths in `reading_lengths.txt`.
M10. Retrieved whole: **51 of 51** (captured body length equals length(body_text) for every file). I read about 40 of them in full or in their relevant sections (the long NSC reports frus1955-57v09/d190 and d207, and frus1917-72PubDipv08/d31, by section). Quoted: **22 documents** (`final_cited.txt`: `cited.txt`'s 21 minus frus1952-54v12p2/d401, d405 and frus1961-63v02/d16, plus four Public Diplomacy volume documents), 34 quotations.

Candidates were ranked with `rank.py` (bm25, ORDER BY score ASC) over the regional list, the thematic list, the Japan/regional list and the Public Diplomacy list (queries in queries.log). Read but not cited: frus1952-54v12p2/d401, d405 (Thailand), frus1961-63v02/d16, frus1961-63v04/d81 (Mecklin: a coup memo, off-topic), frus1964-68v27/d386, frus1964-68v01/d177, frus1950-55Intel/d226 (USIA research organisation; addressed to South Africa), frus1952-54v14p2/d715, d818, frus1958-60v18/d99, frus1955-57v22/d448, frus1955-57v21/d8, d48, frus1961-63v22/d191, frus1955-57v09/d185, d189, frus1961-63v25/d133, frus1952-54v12p2/d398, frus1977-80v30/d175, d183, frus1917-72PubDipv07/d171, PubDipv06/d133, PubDipv08/d88, d92, d121, d143, d146, frus1955-57v22/d275, frus1969-76ve12/d10.

M11. The cited set: **22** documents (list in section 9). Every pair verified present, non-apparatus: `SELECT 1 FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0` (archival_cited.txt / archival_cited2.txt show EXISTS for each; PubDip pairs also confirmed in quote_verification.txt with fm=0 en=0).

## 5. Quotations (all verified)

Verification script (heredoc in queries.log), output `quote_verification.txt`: `SELECT body_text, length(body_text), is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?` then Python `q in body_text` (exact substring, case-sensitive). Result: **34 of 34 verified**. Quotations file: `quotes.json`.

| Q | pair | quotation (exact) |
|---|---|---|
| Q1 | frus1949v09/d558 | to foster possible rifts between Chinese Communists and the USSR |
| Q2 | frus1952-54v12p2/d403 | In projecting U.S. leadership, however, we must work with and through indigenous leadership wherever possible. |
| Q3 | frus1952-54v12p2/d403 | prepare the minds and emotions of the people |
| Q4 | frus1952-54v12p2/d396 | the dangers of Communism have been brought home to the Thai people |
| Q5 | frus1952-54v12p2/d396 | preferably personnel having at least a basic knowledge of the Thai language |
| Q6 | frus1955-57v21/d23 | While wishing avoid show undue interest which could be interpreted as U.S. effort use Conference advance own ends |
| Q7 | frus1917-72PubDipv08/d58 | functions in this field properly belong to and must ultimately be performed by the Government of Viet-Nam (GVN) |
| Q8 | frus1952-54v13p1/d116 | counterpersuasive Commie propaganda which exploits nationalist and racial feeling |
| Q9 | frus1952-54v13p1/d116 | All factors recited must be viewed as effective though degree cannot be accurately measured. |
| Q10 | frus1955-57v09/d190 | In the Far East USIA was forced to deal with mixed emotions regarding the use of atomic weapons against Asiatic peoples, and to counter communist propaganda designed to stir up race hatred. |
| Q11 | frus1955-57v22/d58 | emotional nationalism which is suspicious of any larger power, especially one associated with memories of white man’s past colonial domination |
| Q12 | frus1955-57v22/d58 | Patronizing attitudes or demands for approbation would tend to minimize our limited potential for effectiveness. |
| Q13 | frus1952-54v14p2/d762 | curious ambivalence in Japanese character asserted itself |
| Q14 | frus1964-68v29p2/d46 | Intellectually we have met with some success, … but the basic emotional response remains unchanged and is probably unchangeable over the short run. (full text in quotes.json) |
| Q15 | frus1964-68v29p2/d46 | since they are racially, culturally and geographically closer to the Japanese than are the caucasians who come from afar |
| Q16 | frus1917-72PubDipv08/d149 | The predominant mood is apolitical, seeking to be neutral, and concerned with economic and trade problems rather than strong ideological convictions. |
| Q17 | frus1955-57v09/d207 | Despite all efforts, the trend toward accommodation to Communist pressures in the area continued. |
| Q18 | frus1917-72PubDipv06/d126 | much of our audience would tend to regard it as mere words without deeds |
| Q19 | frus1964-68v01/d197 | there is no conceivable information program that will make defeats look like victories, or GVN lassitude appear to be fiery enthusiasm |
| Q20 | frus1964-68v02/d160 | efforts to develop among the South Vietnamese people a sense of national unity and a determination to fight off Communist aggression, have not progressed to my satisfaction |
| Q21 | frus1917-72PubDipv08/d31 | Asians are, to varying degrees, America watchers. |
| Q22 | frus1917-72PubDipv08/d31 | PAOs emphasized that the image of the US usually depended more on the state of bi-lateral relations |
| Q23 | frus1917-72PubDipv08/d31 | Exposures as a main pillar of PPBS should be dropped. |
| Q24 | frus1917-72PubDipv08/d31 | One caveat: US visibility should be low. |
| Q25 | frus1969-76v38p2/d105 | Thais still see us as friends and admire much in the American system. |
| Q26 | frus1969-76v38p2/d105 | There is belief that the US no longer has the ability or the desire to control events in Asia. |
| Q27 | frus1969-76v38p2/d105 | hoping that we have all learned the lesson that America is not omnipotent |
| Q28 | frus1977-80v30/d81 | the future role of public diplomacy in support of our policies in Asia |
| Q29 | frus1977-80v30/d83 | I confess I am baffled by phenomenon. |
| Q30 | frus1977-80v30/d83 | seeks to implant American models on other societies |
| Q31 | frus1961-63v23/d289 | a real understanding of and a demonstrated respect for Indonesia’s neutral stance |
| Q32 | frus1961-63v23/d289 | we should refrain from glamorous, immediate-impact actions |
| Q33 | frus1977-80v30/d2 | We are dealing here with gut issues rather than some of the frothier aspects of cultural exchange. |
| Q34 | frus1977-80v30/d215 | Since the cessation of jamming in 1977, VOA’s Chinese audiences have grown rapidly and are now estimated to number over 100 million listeners. |

(Q14 is shown shortened here for the table only; quotes.json and the collection carry the full verified string. Listed in ELIDED in queries.log.)

## 6. Archival scope (channels never summed)

### 6.1 CAME-FROM (document_sources), cited set of 22 — `archival_cited.txt`, `archival_cited2.txt`
SQL: `SELECT repository, record_group, lot_file, series_name, citation_era, substr(raw_text,1,160) FROM document_sources WHERE volume_id=? AND document_id=?`
- RG 59 decimal central files: frus1952-54v12p2/d403 (790.5), d401 not cited, d405 not cited, frus1952-54v13p1/d116 (511.51G), frus1952-54v14p2/d762 (711.5611), frus1955-57v21/d23 (670.901), frus1961-63v23/d289 (611.98). Bundled JSON resolves no NAID for the 1950–1963 decimal file (central-files-index.json's numericalFile/countrySeries cover the pre-1910 files only; collection-authority carries "Indexed Central Files" as text-only records).
- RG 59 Central Files 1964–66 (subject-numeric, POL 27 VIET S): frus1964-68v29p2/d46. No NAID in bundle.
- Lot 63 D 351 (S/S–NSC files): frus1952-54v12p2/d396, frus1955-57v09/d190, d207 -> central-files-index.json: "Records Relating to National Security Council Policy Papers", RG 59, entry A1 1586E, NAID 2839192; series-facts: creator Department of State, Office of the Secretary, Executive Secretariat; 1947–1979; 26 linear feet 3 inches; Restricted – Partly; College Park textual.
- Lot 62 D 430 (OCB files): frus1955-57v22/d58 -> "Subject and Special Files", RG 59, entry A1 1586C, NAID 2839191; creator Department of State, Executive Secretariat; 1953–1961; Restricted – Partly.
- Executive Secretariat Files (named series, no lot): frus1949v09/d558. Unresolved.
- Johnson Library, NSF, Vietnam Country File: frus1964-68v01/d197 -> presidential-library-catalog.json: National Security Files (NAID 567979), series Vietnam Country Files NAID 591194, 1963–1969.
- Johnson Library, Confidential File CO 312: frus1964-68v02/d160 -> White House Central Files (Johnson Administration) NAID 566962, series Confidential Files NAID 12005682, 1963–1969.
- RG 306, Director's Subject Files 1968–1972, Entry A1–42: PubDipv08/d58, d149. No NAID in bundle.
- RG 306, Office of Policy and Plans, Entry P–207: PubDipv08/d31. No NAID in bundle.
- RG 306, DIRCTR Sub Files, acc. 72A5121, Entry UD WW 257: PubDipv06/d126. accession-series-index.json key `306/72A5121` divides across several series (Subject Files 1257679, Policy Guidance 40943515, Background Files 4667751, Regional Subject Files 48349732, …): not resolvable to one shelf.
- "RG 305", Records of the USIA, Office of the Director, Entry UD–UP 7, FRC 306–84–0003: frus1969-76v38p2/d105. The accession number is RG 306's; `306/840003` in accession-series-index.json -> Correspondence Files (NAID 5552237) and Memorandums Pertaining to the Executive Committee (NAID 5585931). Neither NAID is in series-facts-index.json.
- RG 306, Office of the Director, Executive Secretariat, Correspondence Files 1973–1980, Entry P–104: frus1977-80v30/d2. No NAID in bundle (probably the same Correspondence Files series; not verified).
- RG 59 Central Foreign Policy File (electronic telegrams, 1977): frus1977-80v30/d81, d83. No NAID in bundle.
- Carter Library, Plains File, Box 16: frus1977-80v30/d215 -> Plains Files NAID 591256; series Subject Files NAID 591289 (1973–1982) is the probable series (match by title only, not verified).

### 6.2 POINTED-AT (external_citations), cited set — same files
SQL: `SELECT repository, collection, lot_file, file_id, substr(raw_text,1,140) FROM external_citations WHERE volume_id=? AND document_id=?`. Caveat: this channel has no rows before 1910-12-06, stores the citation fragment, and holds lot, library and decimal anchors only.
- PSB files, lot 62 D 333, file PSB D–23 (from frus1952-54v12p2/d396) -> "Psychological Strategy Board Working Files", RG 59, entry A1 1462, NAID 2124692; 1951–1953; 3 linear feet 6 inches; access "Restricted – Possibly".
- USIA/IOP Files lot 59 D 260 and lot 63 D 224 (frus1955-57v09/d207) -> lot 59 D 260 "Subject Files", RG 306 (central-files-index; collection-authority says 59), entries UD-WW 151 … UD-WW 382, NAID 1257679; creator U.S. Information Agency, Office of Policy and Plans; 1953–1971; Restricted – Partly. Collection-authority lists 63 D 224 among the aliases of the same record.
- USIA/I Files lot 60 D 322 (frus1955-57v09/d207): in collection-authority (RG 59, no NAID). USIA/I/R Files lot 62 D 255: unresolved. Lot 62 D 430 also cited from d207 (see 6.1).
- Decimal anchors: 511.00/8–2352 (frus1952-54v13p1/d116: the circular asking chiefs of mission to assess information programs; its other replies are not printed — `MATCH '"511.00/8-2352" OR ("circular telegram 208") OR "Depcirtel 208"'` returned only d116), 511.00/6–3055, 511.00/5–2755, 511.00/6–655, 511.00/4–2455 (frus1955-57v09/d190), 670.901/2–2555, 711.5611/5–2054.
- Johnson Library, President's Daily Diary (frus1964-68v02/d160). Not looked up.

### 6.3 Channels over the topic set (701 regional documents) — `archival_topicset.txt`
- CAME-FROM rows 701 of 701. Citation forms: decimal 249, structured 244, lot_file 116, subject_numeric 61, named_series 25, published 2, foreign 2, cfpf 2. Top: Johnson Library NSF 58; Nixon NSC Files 33; Kennedy NSF 26; lot 63D351 16; lot 62D430 12; Eisenhower papers 11; lot 72D415 10 ("Records Relating to the United States-China Ambassadorial Talks", NAID 16839115 — not an information series); CIA 10.
- POINTED-AT 398 rows in 232 documents. Top: Johnson NSF 31; Nixon NSC Files 20; lot 66D95 17 (same series as 63D351, NAID 2839192); lot 62D430 13; Kennedy NSF 11; lot 63D351 10.
Label: channel as stated; volume set = 75 regional volumes; never summed.

Pre-1940 note: the offline archival stack barely reaches before 1940 (11 of 695 bundled series); this scope begins in 1945, so the limit does not bite here. No [HARVEST] path was given: that surface is unavailable.

## 7. VECTORS

Files: semantic-vectors-index.json, semantic-vectors-binary.bin, semantic-map.bin (digest read only), Tier-2 shards frus1917-72PubDipv08.vec, frus1952-54v13p1.vec, frus1955-57v22.vec, frus1969-76v38p2.vec, frus1969-76ve12.vec in /Users/jbotts/frus-analysis/c3/SemanticVectors/. Scripts `vectors.py`, `cosine.py`; outputs `vectors_out.txt`, `cosine_out.txt`.
- Digest check: index, binary, map, .generation and every shard touched = `89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101`. Index generated 2026-10-15, harvestGenerated 2026-10-15T06:55:14. Header: version 1, 512 dims, 314,616 documents, 660 centroids. Segment decode round trip: 553 of 553 volumes.
- Baselines at this digest: random pairs (random.Random(1877), 20,000 pairs) mean 167.1, sd 14.8, 1st percentile 132, minimum 95; 25th-nearest-neighbour distance over 200 random documents median 108 (quartiles 101, 114). measuredRecallAt10 = 0.9021.
- **Nearest neighbours of a document** (Tier 1, Hamming over sign bits), anchor frus1917-72PubDipv08/d31 (1969 Manila PAO conference): 81 PubDipv07/d106; 86 PubDipv06/d3; 88 PubDipv06/d5; 88 frus1952-54v13p1/d116; 89 frus1955-57v22/d275; 90 PubDipv08/d99; 90 frus1950v06/d9 (editorial note); … All far below the random mean and inside the 25th-neighbour quartiles, i.e. ordinary near neighbours, not exceptional. frus1952-54v13p1/d116 (already found by full text) reappearing is a consistency check only.
- Anchor frus1969-76v38p2/d105 (1975 reassessment): 76 frus1969-76ve12/d10; 77 frus1958-60v16/d65; 78 frus1969-76v01/d54; 80 ve12/d16; 82 ve12/d15; 82 frus1977-80v22/d104; … All neighbours' volumes are present in document_cache (553 of 553 indexed), so none needed a canonical-URL flag.
- Tier-2 rerank cosines (int8 codes × scales), calibrated `(cos − 0.40)/0.60` per retrieval.scoreCalibration.documentOffset: d31↔frus1952-54v13p1/d116 raw 0.906, calibrated 0.843; d31↔frus1955-57v22/d275 raw 0.850, calibrated 0.750; d105↔frus1969-76ve12/d10 raw 0.910, calibrated 0.851.
- I read frus1955-57v22/d275 (1957 Djakarta telegram on military aid, West Point textbooks for the Indonesian academy) and frus1969-76ve12/d10 (dumped, read partly). Neither is cited: d275 bears on influence through training, a thread outside the messaging question as scoped (named in the collection's closing prose as unfollowed).
- Semantic join, centroid similarity, the map, near-duplicates: **none**.
- Documents in the overview reached through a vector operation and through no full-text query: **none**.

## 8. Decisions taken meanwhile
- "Soft power" read as the contemporaries' "information program", "psychological strategy/warfare", "prestige" and "public diplomacy" plus exchanges; military aid and economic aid as influence excluded unless a document frames them as messaging.
- "East Asia and Pacific" read as the Department's Far Eastern / East Asian and Pacific bureau area, Burma and Indonesia included, South Asia excluded (frus1958-60v15 "South and Southeast Asia" is in the regional list for its Southeast Asia chapters).
- Period 1945–1980 (what the index holds for the region's information programs); Vietnam-specific psychological operations kept only where they speak to the regional audience or to effectiveness.

## 9. TRACE TABLE (every number and quotation in overview.md)

| overview item | memo line |
|---|---|
| "all 553 volumes" (coverage) | M1 |
| "seventy-five regional volumes" | Section 2 inclusion rule; M2 |
| "eleven thematic volumes" | M3 |
| "eighty-six volumes", "about 40,500 documents" | M4 (40,529) |
| "about 700 documents" in "sixty-nine of the seventy-five" volumes | M6 (701; 69 of 75) |
| "about one in fifty" (1950s) | M7 (21.2 per 1,000 = 275 of 12,972) |
| "about one in twenty-three" (1960s) | M8 (44.3 per 1,000 = 311 of 7,028) |
| "soft power" in none of the 553 volumes | M5 |
| "fewer than thirty documents", "one of them" in a regional volume | M9 (27; 1) |
| "twenty-two documents" | M11 |
| "of which FRUS prints one" (replies to the 1952 circular) | Section 6.2 (MATCH on 511.00/8-2352 / circular telegram 208 returned only frus1952-54v13p1/d116) |
| "the information-program file of 1952–1955" | Section 6.2 decimal anchors 511.00/8–2352 … 511.00/6–3055 |
| "the 1960s carry the densest coverage" | M8 against M7 and the 1940s/1970s rows of 3.3 |
| "about 37,200 documents" (regional) | M2 (37,203) |
| "about 3,300 documents" (thematic) | M3 (3,326) |
| "the same two controls" / "a phrase found in every volume and a nonsense control found in none" | Section 3.4 (positive 86 of 86 volumes; negative 0) and M5 |
| "two key memoranda" (similarity anchors) | Section 7 (anchors frus1917-72PubDipv08/d31, frus1969-76v38p2/d105) |
| "one document I had already found" | Section 7 (frus1952-54v13p1/d116 at 88 from d31) |
| "the dangers of Communism" (part of Q4); "emotional nationalism", "memories of white man’s past colonial domination" (parts of Q11); "degree cannot be accurately measured" (part of Q9); "more on the state of bi-lateral relations" (part of Q22) | Section 5 |
| "100 million" (inside Q34) | Q34 |
| "1977" (inside Q34) | Q34 |
| Quotations Q1–Q3, Q6–Q34 as used | Section 5 rows of the same number |
| "fifty-one documents" read whole | M10 |
| "thirty-four quotations" checked | Section 5 (34 of 34) |

Numbers that are identifiers (edition years, volume and document numbers, record-group, entry and NAID numbers in the overview's lists) trace to sections 6.1–6.2 and to section 9's Documents cited list in overview.md.

Check performed before finishing: every quotation in overview.md is one of Q1–Q34 (verified 34 of 34), and every document cited in overview.md is in collection.fruscollection (22 of 22; script check recorded in queries.log as the final collection check).
