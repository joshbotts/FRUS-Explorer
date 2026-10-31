import json, sqlite3, re
from quotes import Q
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
coll=json.load(open("collection.fruscollection"))
docs=[(e["volumeId"],e["documentId"]) for e in coll["entries"] if e["kind"]=="document"]
rows=[]
for v,d in docs:
    r=con.execute("SELECT t.date_iso,length(c.body_text),substr(c.header,1,70) FROM document_cache c LEFT JOIN document_dates t ON t.volume_id=c.volume_id AND t.document_id=c.document_id WHERE c.volume_id=? AND c.document_id=?",(v,d)).fetchone()
    rows.append(f"| {v}/{d} | {r[0]} | {r[1]} | {r[2].replace('|','/')} |")
doclist="\n".join(rows)
USED=["Q01","Q03","Q04","Q06","Q07","Q08","Q10","Q13","Q14","Q15","Q17","Q18","Q19","Q20","Q24","Q25","Q26"]
qrows=[]
for qid,v,d,t in Q:
    qrows.append(f"| {qid} | {v}/{d} | {'used in overview and collection' if qid in USED else 'verified, not relied on'} | {t[:110].replace('|','/')}{'...' if len(t)>110 else ''} |")
qlist="\n".join(qrows)
decade=open("stat2.out").read()
tei=open("teiscan_summary.txt").read()
stat1=open("stat1.out").read()
stat3=open("stat3.out").read()
stat4=open("stat4.out").read()
v1=open("vec1.out").read()
m1=open("map1.out").read()
nd=open("nd_read.out").read().strip().splitlines()[-1]
memo=f"""# Memo (operator): Corruption and U.S. foreign policy, run s1, 2026-10-30

Question: How has corruption, or allegations of corruption, affected U.S. foreign policy decisions or the conduct of diplomacy?
Run directory: /Users/jbotts/frus-analysis/c3s/runs/s1. Every number below is on disk in the file named beside it. Line ids [Mx.y] are what the TRACE TABLE at the end points to.

## 1. Coverage (run first)

[M1.1] Canary, first tool call, exact SQL: `SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;` returned `553|321749|1103|8481`, as required. Read-only proof, second call: `sqlite3 -readonly ... "BEGIN; CREATE TABLE zz(x); ROLLBACK;"` failed with "attempt to write a readonly database", as required.
[M1.2] Every count below is conditional on this index: 553 volumes, 321,749 documents (1,103 front matter, 8,481 editorial notes). The full series is 553 volumes, so the index holds the whole series as of the copy of 2026-10-25; a thin result below is therefore thin in the series, not only in a partial library, except where stated.
[M1.3] Exclusions used throughout unless stated: is_front_matter = 1 and is_editorial_note = 1 are excluded; frus1951-54IranEd2 and frus1969-76ve15p2Ed2 are suppressed in favour of their first editions (the counting surface is this index, with apparatus excluded). Documents are keyed (volume_id, document_id) and every join is on both. summary_text and note_text were never selected. cross_references was not used (no is_broken filter needed). document_cache.rowid is used only as the FTS join key, never reported.
[M1.4] Non-apparatus denominator with Ed2 suppressed: `SELECT COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0 AND volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2');` = 311,429 documents in 551 volumes (logged in queries.log).

## 2. Scope chosen and how it was found

[M2.1] Brief: the question is broad and its key term is the question's own ("corruption"). Inclusion rule used: a document is in the final set (collection) when I read it whole and it ties a charge or fact of corruption (in a foreign government or in American business dealing abroad) to something a U.S. official did, considered, refused or said. Allegations are counted as allegations. Domestic-US corruption, "corrupt" in the sense of garbled text, corruption of minors, and extradition lists are excluded as other senses.
[M2.2] How found. (1) Vocabulary check: `frus_documents_vocab` rows for the family showed the stems: corrupt (2,253 documents including apparatus before exclusions), bribe, briberi, graft, embezzl, venal, kickback, malfeas, nepot, cronyism, misappropri (queries.log; the vocab query is the one beginning `SELECT term, doc, cnt FROM frus_documents_vocab`). Note the index stores porter stems; `corrupt` covers corrupt, corrupted, corruption, corruptly. `grafton` is a separate stem (a surname) and was not counted. (2) Lexical scope: FTS MATCH `corrupt OR bribe OR briberi OR graft OR embezzl* OR venal OR kickback OR malfeas* OR nepot* OR cronyism OR misappropri*` over `frus_documents` joined to `document_cache` on rowid, apparatus excluded (scan1.py; full SQL in the file), 3,283 documents including the Ed2 volumes, 3,242 without them; each document was scored by a regex count of the family in header plus body_text (scan1.csv). (3) Ranking by that count and by volume, then reading: the 70 densest documents, the 280 documents with a count of four or more by date, and specific volumes. (4) Editors' headings were not queried as such; the pattern in the headings is the volume's country and period, so cases were found by document density. (5) Extra census because Lockheed documents use "bribe" without the stem: `frus_documents MATCH 'lockheed AND (brib* OR bribe OR briberi OR payoff OR commission*)'` returned 44 documents (including both editions of two E-15 documents); the Japanese and German ones were read.
[M2.3] Second edition suppression: frus1951-54IranEd2 and frus1969-76ve15p2Ed2 are excluded; the overlap is measured by the vectors' near-duplicate check, not by id (see section 7).
[M2.4] Periodised on document_dates.date_iso (the document's own date), not on the volume's series year; documents without a date_iso are left out of the decade table (1,178 undated in the first run of the table).
[M2.5] False friends found while reading, excluded from the set: (a) frus1951v06p2/d5 uses "bribe" for aid as an inducement ("a type of bribe to produce better performance"), not corruption; (b) the pre-1940 treaties and extradition lists that name bribery as an extraditable crime (for example frus1923v02/d467, frus1924v02/d327, near-duplicates of each other), proclamations, and the Texas/Mexico extradition cases (frus1888p2/d167, frus1903/d648); (c) frus1964-68v05/d301 mentions corruption only in an editors' footnote summarising a priority list (the telegram body is about "leverage" in general); retrieved whole and not cited; (d) frus1981-88v03/d203 (1982 intelligence report on corruption in the Soviet elite) is about an adversary's weakness, not a U.S. decision; read, noted, not cited; (e) frus1977-80v22/d46 (Thailand 1979) mentions corruption in Vietnam.

## 3. What was measured (audit form)

[M3.1] Denominator: see M1.4 (311,429).
[M3.2] Headline count. SQL: `SELECT c.volume_id,c.document_id,... FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'corrupt' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') ORDER BY c.volume_id,c.document_id` (stat1.py). Result: 2,175 documents in 399 volumes (2,200 in 401 volumes before suppressing Ed2: the same predicate without the Ed2 clause). Rate: 2,175 of 311,429 = 0.70%, about one in 143 non-apparatus documents. After the reprint check (M7) four of the twelve text-agreeing pairs fall inside this set, so about 2,171 distinct documents. Counting surface: the index (porter stems, body_text including editors' footnotes).
[M3.3] Decade table (stat2.out), document_cache joined to document_dates on both keys, date_iso; per 1,000 is documents with the stem per 1,000 dated non-apparatus documents of that decade; the last column is the numerator's top-volume share, N of M:
```
{decade}```
Reading: the rate was 1.5 per 1,000 in the 1930s and 16.5 per 1,000 in the 1960s (456 of 27,654), so about one document in 670 against one in 60. The 1890s figure (7.2) is carried by one inquiry, the Hawaii papers in frus1894app2 (37 of 71); the 1940s peak volume is frus1947v07 (59 of 353). 1840s and 1850s rest on one document each and are not a rate.
[M3.4] Variant scan on the TEI [TEI] (teiscan.py, teiscan.csv; summary in teiscan_summary.txt). Positive control "Department of State": found in 553 of 553 volumes (178,538 occurrences). Negative control "ZZZ_IMPOSSIBLE_ZZZ": 0 occurrences in 0 of 553 volumes. Both ran in the same pass as the variants.
```
{tei}```
Split of the root word: "corruption" 2,427 against "corrupt" 977, "corrupted" 95, "corrupting/corrupts" 63, "corruptly" 13, "corruptionist" 9: the noun outnumbers the adjective 2.5 to 1. Bribe forms: bribe(s) 410, bribed/bribing 142, bribery 436. "squeeze" (653) is mostly the verb and was not used as a corruption count. FCPA: 11 occurrences, all in one volume; "Foreign Corrupt Practices" 9 in 2 volumes. TEI totals include front matter and footnotes, so they exceed the index counts; they are not comparable to M3.2.
[M3.5] Literal share of the stem count (rule (a)). Hit list of M3.2, sorted by (volume_id, document_id), 2,175 documents; evenly spaced sample of 40 (index int(i*2175/40)); text = header + dateline + source_note + body_text, whitespace-collapsed (stat1.py, output stat1.out, snippets in stat1_sample.txt). STRICT (whole words "corrupt" or "corruption", case-sensitive lower case, so a capitalised "Corruption" at the start of a sentence misses): 34 of 40. TOLERANT (`\\bcorrupt\\w*`, case-insensitive; inflections allowed): 40 of 40. Python `re`, case-insensitive for TOLERANT; the SQL side is porter-stemmed MATCH, which is case-insensitive. REFERENT test, separate (read each snippet): 34 of 40 are about official or public-life corruption (counting passing mentions); 6 of 40 are not (sample items 1 corrupting the administration of justice in an 1862 slave-trade passage, 2 corruption of minors in an extradition list, 7 corrupting the press with wartime propaganda, 8 corrupting consciences in a Balkan atrocity account, 22 Lord Acton's dictum on power, 40 "abuses more grave than corruption"). So the published stem count is usable (tolerant 40 of 40) but about one in seven of its hits is another sense.
[M3.6] False-friend test for the term the question supplied (stat3.py, stat3.out), documents dated 1950-1980, non-apparatus, Ed2 suppressed. On-topic set = the 15 post-1950 volumes that hold the cited documents (the E-12 and E-15 volumes added later are not in it); baseline = all other volumes in the same dates. Corrupt: 252 of 5,346 (47.1 per 1,000) in the on-topic volumes against 994 of 89,167 (11.1 per 1,000) elsewhere, a ratio of 4.2. Control phrase "economic assistance": 248 of 5,346 (46.4 per 1,000) against 3,198 of 89,167 (35.9 per 1,000), a ratio of 1.3. Positive control "department of state": 2,496 of 5,346 against 50,813 of 89,167. Negative control ZZZ_IMPOSSIBLE_ZZZ: 0 of 5,346 and 0 of 89,167. Caveat: the on-topic volumes were chosen because corruption turned up in them, so the ratio is inflated by selection; it shows the word is not just measuring the corpus (a ratio well above the control's), not how strongly the topic holds.
```
{stat3}```
[M3.7] Whole-corpus phrase counts. Phrase `"foreign corrupt practices"`: 4 documents (frus1977-80v03/d152, d230, d248; frus1977-80v18/d57); STRICT literal 4 of 4, TOLERANT 4 of 4 (census of all four). Phrase `"questionable payments"`: 9 documents, STRICT 1 of 9, TOLERANT 1 of 9 (the other eight are the stem match of unrelated sentences): this phrase is unusable and nothing in the overview rests on it (stat4.py, stat4.out).
```
{stat4}```
[M3.8] The thin results. The Honduras/United Brands case rests on one document (frus1969-76ve11p1/d159); the foreign-bribery rule on four; the Moroccan case on one; the Shah's campaign on one. These may reflect what the editors chose to print as much as the underlying record.
[M3.9] Pre-1940 reading. Of 189 volumes with ids matching pre-1940 patterns (TEI scan), "corruption" appears in 112, "bribery" in 71, "graft" in 37, "embezzle*" in 71, with zero for the negative control. The documents I read there (frus1894app2/d306 and d284 Hawaii 1893; frus1893/d652 and frus1894/d703 Ottoman bribery and the Melton case; frus1867p1/d568 Sanford on electoral corruption in the US; frus1881/d422 Japanese penal code; frus1919Parisv02/d441 Reinsch on China, 1919) are not decisions about corruption. I did NOT scan counterpart vocabulary (merchants, chambers, foreign ministry) for the pre-1940 period beyond the TEI variants above, so no pre-1940 absence is claimed: the overview says only that I did not run a full search there.

## 4. Reading accounting and quotations

[M4.1] Retrieved whole: 63 distinct documents (68 dumps in reading.log; for every dump the captured length equals length(body_text), 68 of 68). Cited in the overview and collection: 29, from 20 volumes. Documents holding verified quotations: 23 (26 passages, section 4.2); quotations relied on in the overview: 17 passages from 15 documents. The texts are on disk in docs/<volume_id>__<document_id>.txt; the reading SELECT is `SELECT c.volume_id,c.document_id,c.header,c.dateline,c.source_note,c.body_text,length(c.body_text),t.date_iso FROM document_cache c LEFT JOIN document_dates t ON t.volume_id=c.volume_id AND t.document_id=c.document_id WHERE c.volume_id=? AND c.document_id=? AND c.is_front_matter=0 AND c.is_editorial_note=0` (dump.py).
[M4.2] Quotations. Each was tested as a substring of body_text for its (volume_id, document_id), exact and whitespace-collapsed, by `SELECT body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0` (verify_quotes.py, quotes_verified.json); 26 of 26 pass both tests. The 17 used passages are also asserted when the collection is built (build_collection.py).
| id | pair | status | text (start) |
|---|---|---|---|
{qlist}
[M4.3] The 29 documents (pair, date_iso, length(body_text) in characters, header start):
| pair | date | chars | header |
|---|---|---|---|
{doclist}
[M4.4] Caveats on what the documents are. body_text includes editors' footnotes. The overview does not rest on the editors' headnote to frus1969-76v06/d175 that Nixon asked for "quiet work" on corruption; the collection note for that document mentions it and attributes it to the editors. frus1964-68v05/d301's priority list is an editors' footnote and is not cited. Document 135 (1958-60v01) quotes a memorandum of conversation inside an editors' footnote; the overview uses only the cable's own text (Parsons raised corruption with Thuan). Document 159 (E-11 pt 1): "probably the Chief of State" is the paper's own hedge; the editors' note that the Honduran military later removed the chief of state is not used causally. Document 292 reports a Senate staffer's claims, relayed secondhand.
[M4.5] Reading-shortcut disclosure: the 29 cited documents were read in the passages around the corruption vocabulary and their openings (KWIC windows of 250-450 characters, then longer stretches where a decision was at issue), not necessarily every paragraph. The captured length equals the stored length for all of them.

## 5. Archival scope [JSON]

[M5.1] CAME-FROM channel (document_sources, one row per document), volume set = the 29 cited documents: `SELECT repository,record_group,lot_file,series_name,citation_era,substr(raw_text,1,150) FROM document_sources WHERE volume_id=? AND document_id=?` (inline script, logged). Result by file: RG 59 Central Decimal File, citation_era decimal: frus1950v06/d832 (896.00), frus1961-63v23/d356 and d358 (796.00), frus1958-60v01/d111 (751K.00), frus1961-63v22/d244 (795B.5-MSP) and d249 (795B.00), frus1943China/d202 (711.93) and frus1944v06/d269 (893.00); RG 59 Subject-Numeric File: frus1964-68v07/d91 (1967-69), frus1969-76v06/d175 and frus1969-76ve05p2/d119 (1970-73); RG 59 Central Foreign Policy File: frus1977-80v23/d252 and frus1969-76ve11p1/d159; RG 84 Jidda Embassy Files lot 79F80: frus1969-76ve09p2/d122 (document_sources says lot_file; the source note of d161 is Ford Library with a Jidda lot footnote); Johnson Library National Security File (structured): d197, d395, 1917-72PubDipv07/d177; Nixon Presidential Materials NSC Files: v27/d45; Carter Library: 1977-80v18/d206, v03/d248; Ford Library: v31/d149; Center for Military History Dep CORDS/MACV Files: v05/d258 (its document_sources row has citation_era `unrecognized`; the source note names the collection).
[M5.2] Gloss of decimal keys, gated by the document's own date (decimal-class-labels.json, coverage.glossableYears 1910-1949, 1950-1959, 1960-1963): 796.00 and 795B.00 fall in the 1960-1963 schedule (96 Philippines, 95b South Korea; class 7 "Internal Political and National Defense Affairs"); 751K.00 for a document dated 1960-03-02 falls in the 1960-1963 schedule (51k Vietnam; in the 1950-1959 schedule 51k reads Australasia, so the date matters); 896.00 dated 1950-08-21 falls in the 1950-1959 schedule; 711.93 and 893.00 (1943, 1944) fall in 1910-1949 and are not glossed here.
[M5.3] Resolution: the bundled indexes name these file classes but carry no NARA series identifier, entry or access status for the Central Decimal File 1950-63, the Subject-Numeric File 1967-73 or the Central Foreign Policy File 1973-79 as series. Relaxed form that returned rows: `collection-authority.json` has a text entry `Central Decimal File 1910-1929` (volume frus1917-72PubDip) and lot entries, but none for those series. Lot 79F80: not in `central-files-index.json` lotFiles; `collection-authority.json` has `lot:79F80`, RG 84, repository Department of State, volume frus1969-76ve09p2, aliases including "Jidda Embassy Files", "POL Northrop & Lockheed", "DEF 12-5 Agent's Fees"; no NAID. Presidential libraries (`presidential-library-catalog.json`, generated 2026-08-06): Johnson Library collection LBJ-NSF, National Security Files, NAID 567979; Carter White House Central Files, Subject File series NAID 165203 (1977-1981); the Nixon NSC Files, the Ford National Security Adviser files and the Carter Brzezinski Material rows were not matched; `series-facts-index.json` has no rows for 165203 or 567979 (it holds 698 rows, RG 59 only as far as I could tell), so access status is not stated.
[M5.4] POINTED-AT channel (external_citations, anchors lot, library, decimal), volume set = the 18 volumes holding the cited documents plus E-12/E-15 pt 2: 2,433 citation rows on 1,472 documents over the 18 volumes (whole volumes: not the finding); restricted to the 366 documents of those volumes that carry corruption-family vocabulary (scan1.csv, arch1.py, arch1.out) there are 158 rows. The channel has no row before 1910-12-06, stores the citation fragment, and holds lot, library and decimal anchors only. Top targets on those 366 documents: decimal 795B.00 (20 rows, 12 documents), Johnson Library National Security File (14, 10), 751K.00 (10, 7), 896.00 (6, 5), Carter Library National Security Affairs (6, 4). Lots on those documents: 65F115, 62D26, 62D430, 65F98, 62D1, 64D199, 66D95, 66D500, 66D483, 85D240, 68D453, 69D277, 71D461, 76D169 (arch2.py, arch2.out). Resolved through `central-files-index.json` lotFiles and `series-facts-index.json` byNaId (one-letter keys, `as` -> statuses, `c` -> headings, `y0`/`y1` literal): 62D26 = NAID 1965953, RG 59, "Subject, Personal Name, and Country Files", entry A1 3113, FE Office of the Assistant Secretary, 1960-1963, Restricted - Partly, 10 linear feet 1 linear inch (cited at frus1958-60v01/d135, a cited document); 71D461 = NAID 603208, "Subject Files of Ambassador at Large W. Averell Harriman", A1 5005, 1967-1968, Unrestricted (cited at frus1964-68v05/d419); 76D169 = NAID 2602428, "Records Relating to Iran", A1 5644, 1965-1975, Restricted - Partly (cited at frus1969-76v27/d47); 65F115 (Saigon Embassy Files, cited at frus1958-60v01/d131 and d63): no row in central-files-index (it is an RG 84 post file; not NARA-resolved by the bundle). Not summed with M5.1: the two channels are different sets.
[M5.5] Reach before 1940: `series-facts-index.json` byNaId has 698 rows; 20 have min(y0, cy0) before 1940: 20 of 698, about 1 in 35 (the guide's figure is about 1 in 60; this is my own count over this file, which is not the guide's).
[M5.6] No harvest path was given in the brief ([HARVEST]: surface unavailable; no harvest count appears anywhere).

## 6. VECTORS

All cosines below are raw. (The artifacts are scored in Hamming distance over 512 sign bits; no cosine was computed and no percentage compared, so the index's retrieval.scoreCalibration offsets (document 0.4, query 0.47) were not applied.)

[M6.1] Provenance digest (printed from every artifact touched, vec1.py, vec1.out): index `provenanceDigest`, binary bytes 20-51, map bytes 20-51, shards manifest `provenanceDigest` and the shard folder's `.generation` file all read `89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101`; they agree (ALL AGREE: True). All 553 shard headers (bytes 16-47) match the digest (0 mismatches). Index `generated`: 2026-10-15 (harvestGenerated 2026-10-15T06:55:14); model embeddinggemma-2-Q8_0; retrieval measuredRecallAt10 0.9021, rerankPool 800 (recall as stated by the index, not measured here). Binary header: version 1, dims 512, documents 314,616, centroids 660.
[M6.2] Identity round trip: ids decoded from the index's `seg` run-length segments only; decoded length equals `n` for every one of the 553 volumes, with `seg.s` equal to the running length; 314,616 rows mapped = documentCount. Five lexical-scope documents have non-numeric ids (frus1911/ch81, frus1919Parisv13/ch12subch8 and ch19subch4, frus1936v05/ch50, frus1958-60v01/ch1) and are not in the vector index; they were dropped from the vector steps only.
[M6.3] Baselines at this digest (vec1.out): random pairs, n = 20,000 (seed 1877): mean 167.14, sd 14.77, 1st percentile 132, minimum 95; mean minus 8 sd = 48.99 bits. 25th-neighbour distance over 200 random documents (seed 1878): minimum 73, median 107, 90th percentile 119, maximum 136; nearest-neighbour (1st) distance over the same 200: minimum 0, median 83, 90th percentile 101, maximum 112. A neighbour is read against the 1st-neighbour distribution (median 83) and a set's cohesion against the random-pair mean.
[M6.4] REQUIRED operation 1, nearest neighbours of an anchor, joined and flagged: run (vec2.py, output vec2.out) for 8 anchors, one per finding or era: frus1969-76ve09p2/d122 (Saudi, 1974), frus1950v06/d832 (Philippines, 1950), frus1964-68v05/d258 (Vietnam, 1967), frus1977-80v23/d252 (Haiti, 1978), frus1969-76ve11p1/d159 (Honduras, 1975), frus1961-63v22/d249 (Korea, 1961), frus1969-76v27/d45 (Iran, 1973), frus1943China/d202 (China, 1943). For each, the nearest 25 by Hamming over the corpus binary (Ed2 volumes masked), each joined on both keys to document_cache and document_dates and flagged IN-SCOPE or OUTSIDE (scope = the 3,242-document lexical set of M2.2), SAME-DECADE or OTHER-DECADE, LITERAL or ABSENT (the family regex over header + body_text). Baseline: M6.3. Findings: (a) the Haiti anchor's nearest neighbour was 72 bits away (frus1977-80v23/d253, in scope) and the Honduras anchor's nearest was 119 bits, beyond the median 25th-neighbour distance (107): its subject (a firm's payment to a head of state) has no near neighbour in the corpus, which says the document is unusual, nothing more; (b) IN-SCOPE counts among the 25 neighbours, by anchor: Saudi 7, Philippines 7, Vietnam 7, Haiti 9, Honduras 0, Korea 9, Iran 7, China 9 (OUTSIDE and ABSENT: 18, 18, 18, 16, 25, 16, 18, 14); the Philippines anchor's neighbours are mostly the 1950-51 Philippine documents; (c) the Vietnam anchor surfaced frus1964-68v05/d301 (the leverage telegram, in scope), d395 (cited), frus1969-76v06/d175 (cited) and frus1917-72PubDipv07/d177 (cited); (d) the China anchor's nearest was frus1947v07/d591 (Sprouse, at 59 bits, in scope); (e) OUTSIDE and ABSENT neighbours, the candidates the vectors exist to find, were retrieved whole and read for the corruption sense: frus1977-80v18/d154 and d176 (West's reports on Saudi stability, no corruption language: not added), frus1969-76ve09p2/d155 (Kissinger briefing, not added), frus1950v06/d839 (Melby on the Philippine budget, not added) and frus1969-76ve11p1/d418 (Haiti strategy paper, not added); none bore on the question; (f) frus1950v06/d841 (the mission's report to the President, in scope with one family hit) was read after the Philippines anchor's list surfaced it and was added to the scope and collection.
[M6.5] REQUIRED operation 2, near-duplicates before any count (vec3.py, vec3.out, nd_read.py, nd_read.out). Line = mean - 8 sd = 48.99 bits. Over the 3,242-document lexical scope: 69 pairs closer than the line (the 5 documents without vector rows were skipped). Both documents of each pair were compared by normalised text equality and by a difflib ratio over the first 6,000 characters (a text comparison by script; I did not read all 69 pairs by eye): {nd}; a pair is counted as one document printed twice only when the ratio is 0.95 or higher. The 12 that agree: frus1933-39/d31 = frus1933v02/d593 (identical); frus1894Nicaragua/d12 = frus1894app1/d263; frus1894app2/d70 = d186; frus1950v03/d732 = frus1950v07/d1002; frus1894Nicaragua/d23 = frus1894app1/d274; frus1894app2/d73 = d192; frus1981-88v06/d32 = frus1981-88v41/d93; frus1867p1/d226 = frus1868p1/d83; frus1894/d464 = frus1894Nicaragua/d45; frus1894/d471 = frus1894Nicaragua/d62; frus1903/d565 = frus1907p2/d289; frus1923v02/d467 = frus1924v02/d327. Where both sit in the stem hit set (4 pairs) the first is cited and counted once; the headline 2,175 therefore reads as about 2,171 distinct documents. The other 57 pairs below the line are different documents of the same form (proclamations, treaties, minutes) at ratios of 0.08 to 0.94, not duplicates. Over the final set of 29: no pair under the line; the nearest in-set distance is 75 bits (frus1961-63v22/d244 and d249), above the line. No cited document is a reprint.
[M6.6] CONDITIONAL operation, the map: run for the one label test (map1.py, map1.out). The 29 cited documents fall in 10 distinct clusters among the 24 that are clustered; 5 of 29 are unclustered (corpus-wide unclustered share 88,059 of 314,616 = 28.0%, so 5 of 29 = 17% is not above it; no era-matched baseline was computed, so no cluster figure beyond this is published). The cluster labels are countries (Vietnam, Philippines, Japan, Korea, China, Cuba, Iran, Morocco/Libya); none of the 140 labels contains corruption, bribery, graft, scandal, fraud, embezzle or payoff. Corruption does not form a region of the map: it runs across country regions.
[M6.7] Which cited documents were vector-reached. STRICT reading (returned by no query I logged): none. All 29 cited documents were returned by the logged lexical query of M2.2 (scan1.csv; checked in code) and 4 of them (frus1969-76ve12/d218, d219, d224 and frus1969-76ve15p2/d292) also by the logged Lockheed census. PRACTICAL reading (in no result set I had read when the neighbour list surfaced it): one, frus1950v06/d841, which had one family hit (fam = 1) and did not appear in either list I had printed. A document inside my own heading scope is practical at most, as the brief says. Re-run for the strict check: vec3.py's lexical scope contains all 29 pairs.
[M6.8] Strict re-run for d841: it is in scan1.csv with fam = 1, so the logged FTS query returned it; STRICT status: not vector-reached.

## 7. Method notes and limits

[M7.1] Phrase counts published: only `"foreign corrupt practices"` (4, census) and `"questionable payments"` (9; unusable). The stem count is a word count and carries its strict and tolerant shares (M3.5).
[M7.2] The decade shape (M3.3) is given per 1,000 dated non-apparatus documents with the numerator's top-volume share, as the rules require. The 1980s (14.1 per 1,000 of 6,038) rest on the editions published so far.
[M7.3] No person count, no bare-surname scan, no summary_text or note_text read. citation_era is used only as a citation form.
[M7.4] What the overview says that is not a count: qualitative readings of the 29 documents; every dated claim is in the table M4.3 (dates from document_dates).
[M7.5] Elisions are declared at the end of queries.log (ELIDED line). The memo itself shortens only long quotations in the table (start shown; full text in quotes.py and quotes_verified.json).

## TRACE TABLE (overview -> memo)

| overview item | memo line |
|---|---|
| 553 volumes | M1.1, M1.2 |
| about 2,200 documents; about 400 volumes | M3.2 (2,175 in 399; 2,200 in 401 before Ed2) |
| roughly 311,000 ordinary documents; one in 140 | M1.4, M3.2 (311,429; one in 143) |
| a sample of forty, six not about official corruption | M3.5 (34 of 40 referent; 6 of 40 not) |
| 29 documents from 20 volumes | M4.1, M4.3 |
| 63 documents read whole; kept 29; quoted 17 passages | M4.1, M4.2 |
| only four documents use the phrase Foreign Corrupt Practices Act, all 1977-1980 | M3.7 |
| one series in thirty-five among 698 | M5.5 |
| National Archives identifiers 567979; 165203 (1977-1981); 1965953, A1 3113, 1960-1963, open in part; 603208, A1 5005, 1967-68, open; 2602428, A1 5644, 1965-1975, open in part | M5.3, M5.4 |
| lot 62 D 26 cited under Document 135; lot 65 F 115 unresolved; lot 71 D 461; lot 76 D 169 | M5.4 |
| jidda lot 79F80, RG 84, not tied to a NARA series | M5.3 |
| decimal files / Subject-Numeric / CFPF with no series identifier | M5.1, M5.3 |
| Center for Military History CORDS folder | M5.1 |
| control word returned zero; common phrase in every volume | M3.4 |
| decade comparison (1940s vs 1870s) and per-decade rates | M3.3 |
| root word and family searched; variants in the volumes' text | M2.2, M3.4 |
| 1893 Hawaii inquiry, Ottoman bribery case, extradition clauses | M3.9, M2.5 |
| the similarity index was used; none of the cited documents depended on it; the 1950 report came up this way | M6.7, M6.4(f) |
| no reprint among the cited documents | M6.5 |
| dates in the findings (1943, 1944, 1950, 1960, 1961, 1967 June/July/November, 1968, 1970, 1971, 1973, 1974, 1975, 1976, 1978, 1980) | M4.3 |
| every quotation Q01 (Doc 832, VI) | M4.2 row Q01 |
| Q03 (Doc 358) | M4.2 row Q03 |
| Q04 (Doc 252) | M4.2 row Q04 |
| Q06 and Q07 (Doc 258) | M4.2 rows Q06, Q07 |
| Q08 (Doc 197) | M4.2 row Q08 |
| Q10 (Doc 175) | M4.2 row Q10 |
| Q13 and Q14 (Doc 122) | M4.2 rows Q13, Q14 |
| Q15 (Doc 45) | M4.2 row Q15 |
| Q17 (Doc 206) | M4.2 row Q17 |
| Q18 (Doc 159) | M4.2 row Q18 |
| Q19 (Doc 161) | M4.2 row Q19 |
| Q20 (Doc 219) | M4.2 row Q20 |
| Q24 (Doc 244) | M4.2 row Q24 |
| Q25 (Doc 249) | M4.2 row Q25 |
| Q26 (Doc 202) | M4.2 row Q26 |
| the phrase "as a means of guarding U.S. interests" (finding 3 text) | M4.2 row Q13 |
| "corrupt" in quotation marks (the word searched) | M3.2 |

VECTORS provenance digest: 89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101; index generated stamp 2026-10-15.
"""
open("memo.md","w").write(memo)
print(len(memo))
