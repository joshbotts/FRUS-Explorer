import json,re
Q=json.load(open('quotes.json')); D=json.load(open('final_docs.json'))
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
out=[]
w=out.append
w("""# Scope memo: U.S. soft power in East Asia and the Pacific (operator's record)

Run directory: /Users/jbotts/frus-analysis/c3f/runs/f4. Date of run: 2026-10-31. Index: frus-copy-2026-10-25.db opened read-only.
The overview and collection are for the historian; this memo keeps every SQL string, table name, id, path and count. Section tags (M01 and so on) are the lines the trace table points to.

## 0. Coverage and exclusions

M01. Coverage query, first tool call, output `553|321749|1103|8481`:
`SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;`
The read-only proof (second call) failed with "attempt to write a readonly database", as required. Every count below is conditional on this library: 553 volumes, the full series, so the library is not a partial one. Thinness below is therefore a property of the corpus or of my vocabulary, not of the download.

Exclusions: every document-level count adds `d.is_front_matter=0 AND d.is_editorial_note=0` (stated in each SQL below). I never selected or read summary_text or note_text (the reading SELECT names body_text, header, dateline, source_note only; the full-text MATCH runs on `frus_documents`, which has no summary or note column). cross_references was not used, so the is_broken rule did not arise. The join `frus_documents f JOIN document_cache d ON d.rowid=f.rowid` uses the internal row pairing only to reach the FTS table; no rowid is reported or cited; identity is always (volume_id, document_id). Second editions: no volume in the scope sets ends in Ed2 (checked, `scope_sets.json`), so no Ed2/first-edition overlap arises. Counting surface: the index (porter-stemmed full text of header, dateline, source note and body, footnotes included); I did not use the TEI, so no spelling-variant, tag-stripped or density claim is made anywhere.

## 1. The scope I chose, and how I found it

Question terms. "Soft power" is a 1990 coinage and the corpus does not contain it (M07), so the question had to be re-expressed in the officials' own vocabulary: information program, Information Service/Agency (USIS/USIA), psychological warfare/operations/strategy, Voice of America, educational/cultural exchange, exchange of persons, Fulbright, hearts and minds, public diplomacy, leader grant, Asia Foundation, information officer, cultural affairs/relations, JUSPAO. I read the editors' own chapter and series structure first: the manifest titles (scope1.py/mkscope.py) show that the series files East Asia under Far East, China, Japan, Korea, Southeast Asia, Indochina, Vietnam, East Asia and the Pacific, and puts the Agency's own papers in the Public Diplomacy, Information Policy and Organization-of-Foreign-Policy volumes.

Inclusion rule (used as the meanwhile rule in the overview's Decisions section):
- Region set R: volumes whose manifest title names Far East, China, Japan, Korea, Vietnam, Indochina, Southeast Asia, East Asia, Pacific, Indonesia, Laos, Northeast Asia, Cambodia, Philippines, Australasia or Asia, from 1945 on, excluding South Asia and Near East titles (`mkscope.py`; list in `scope_sets.json`). Period: titles dated 1945 to 1980 (volume series year; I did NOT periodise on doc-dateTime-min, and make no decade-shape claim, so that rule does not bite).
- Global set G: Public Diplomacy (1961-63, 1964-68, 1969-72), Foreign Information Program (1955-57 v09), Information Policy (1961-63 v25), Organization and Management of Foreign Policy (1964-68 v33, 1969-76 v38p2, 1977-80 v28), Public Diplomacy 1977-80 v30, and Public Diplomacy, World War I (frus1917-72PubDip; in G, it contributed no Asia-headed document).
- Documents: non-apparatus only.

M02. R: 76 volumes, 39,222 documents of which 188 front matter and 1,493 editorial notes; 37,543 non-apparatus documents in 76 volumes.
`SELECT COUNT(DISTINCT d.volume_id), COUNT(*), SUM(d.is_front_matter), SUM(d.is_editorial_note) FROM document_cache d JOIN R USING(volume_id)` -> (76, 39222, 188, 1493); with `WHERE d.is_front_matter=0 AND d.is_editorial_note=0` -> (76, 37543). Output: `cnt.out`. (R and G are TEMP tables loaded from scope_sets.json by `h.py`.)
M03. G: 10 volumes, 2,281 non-apparatus documents (`cnt.out`).

M04. The information-vocabulary union S2 inside R: 1,984 non-apparatus documents.
SQL: `SELECT f.volume_id, COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN R ON R.volume_id=d.volume_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND frus_documents MATCH ? GROUP BY 1 ORDER BY 2 DESC`, with ? = `(USIS OR USIA OR JUSPAO OR "Information Agency" OR "Information Service" OR "psychological warfare" OR "psychological operations" OR "psychological strategy" OR "information program" OR "cultural exchange" OR "educational exchange" OR Fulbright OR "Voice of America" OR "exchange of persons" OR "hearts and minds" OR "cultural program" OR "Asia Foundation" OR "leader grant" OR "information officer" OR "cultural affairs" OR "cultural relations" OR "public diplomacy" OR "information activities")`. Per-volume counts and the total (1984) are in `union2.out`; 1,984 documents lie in 76 volumes (every R volume has at least 4). Denominator: 37,543 non-apparatus documents in R (M02). Counting surface: index (stemmed), so this is an upper bound on literal use (M05).
Ranking pass: the same union plus "propaganda", ordered by bm25 (ascending, best first), top 200: `union1.out`; used only to choose documents to read. (It over-weights the China civil-war volumes, where "propaganda" is Communist propaganda; I did not rely on it for the argument.)

M05. LITERAL SHARE of the M04 hit list (obligation (a)). Sorted (volume_id, document_id) hit list of 1,984; evenly spaced 40 (indices floor(i*1984/40)); regex over `header||' '||dateline||' '||source_note||' '||body_text`, whitespace-collapsed, Python `re` with re.I (case-insensitive; SQL MATCH is also case-insensitive, so one convention for the family). STRICT (single spaces between the words, the phrases exactly as queried, word-bounded; acronyms word-bounded): 33 of 40 (0.825). TOLERANT (each word allowed -s/-es/-ed/-ing, 'activities'; any run of space, hyphen, comma, parenthesis or full stop between words): 35 of 40 (0.875). Above the 0.80 floor, so the family is usable in its published form. Five tolerant misses, all read: the misses are frus1948v06/d216, frus1948v06/d84, frus1949v07p1/d305, frus1949v07p2/d95, frus1949v09/d292; four contain no information, psychological, cultural or exchange word at all and one contains only "propaganda"; I do not know why the index matched them (not resolved). Script `share.py`, output `share.out`. A 1.000 share would test only the stemmer; the share here is below that and I did not test the referent separately beyond reading the documents I cite. The overview publishes only "about two thousand" (M04), never a phrase count.

M06. G Asia-headed documents S1: 61 documents in G whose body matches an East Asian place or "Asia/Asian/Pacific" word and whose header names Asia, Viet, Japan, China, Chinese, Korea, Indonesia, Philippines, Thai, Pacific, Taiwan or Far East. SQL in `gq.py`/`gq.out`. They are almost all Agency area-director memoranda, which is why the public diplomacy volumes are indispensable. Overview says "about sixty".

M07. Controls (same pass, `vocab1.py`/`pre.py`; outputs `vocab1.out`, `pre.out`):
- Positive: `"Department of State"` in R: 14,670 non-apparatus documents in 76 of 76 volumes (SQL: `SELECT COUNT(*), COUNT(DISTINCT f.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN R ON R.volume_id=d.volume_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND f.frus_documents MATCH ?`). Whole corpus: 94,049 documents in 552 volumes (pre.out).
- Negative: `ZZZ_IMPOSSIBLE_ZZZ` -> 0 documents in R and 0 in the whole corpus.
- `"soft power"` -> 0 in R and 0 in the whole corpus (SQL as in pre.out line 1). The scan works (controls pass), so the absence is a finding. FALSE-FRIEND TEST: the question supplied "soft power", "messaging", "strategies", "effective". "Soft power" has zero share everywhere, below any control phrase; I stopped using it. "Public diplomacy" (211 documents in 38 volumes across the corpus) was NOT a clean control: it is the name of the volumes. Scoping counts in vocab1.out (psychological warfare 260 in 58 volumes, USIS 592 in 54, propaganda 2,769 in 76, and so on) are PHRASE COUNTS WITHOUT LITERAL SHARE and are used only for scoping; none appears in the overview.
- Pre-1945 vocabulary (contemporaries' words, counterpart vocabulary): `"Boxer indemnity"` 202 documents in 42 volumes; `"cultural relations"` 469 in 185; `"Division of Cultural Relations"` 26 in 11 (pre.out; scoping only, no literal share, not in the overview). Remission-for-education probe `("Boxer indemnity" OR "indemnity") AND (students OR education OR educational OR university OR scholarships) AND China`, top 12 listed in pre.out; I read frus1924v01/d540 (Secretary of State to President Coolidge, 15 Dec 1924), which is the document I cite as the precedent. frus1938v04/d778 and frus1943China/d667 were read for the same thread and not cited.

## 2. Reading accounting

M08. 89 documents retrieved whole (captured length = length(body_text) for 89 of 89 files in `docs/`, checked in session by comparing Python len() of the dump with `SELECT length(body_text) ...`). Of these, 22 are in the collection and carry the 39 verified quotations (M09); the rest were read in part through windows or the opening 2,500-7,500 characters, then not cited. The reading SELECT (`dump.py`): `SELECT volume_id, document_id, header, dateline, source_note, body_text, length(body_text), is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?`; raw text is on disk as docs/<volume_id>__<document_id>.txt. Edited-down reading of long documents was by `kwic.py` windows (regex, ±300-400 characters); I did not read most of the 89 end to end, so "retrieved whole" means captured whole, not read whole.

## 3. Quotations (each verified by exact whitespace-collapsed substring match, `quotes.py`, result `quotes_verify.out`: 39 of 39 OK)

Each quotation was retrieved by the reading SELECT above for its (volume_id, document_id); the overview uses those marked with an asterisk.
""")
used={"Q13","Q01","Q03","Q05","Q10","Q21","Q35","Q38","Q18","Q19","Q25","Q12","Q22","Q07","Q28","Q30","Q27","Q31"}
w("| id | volume_id/document_id | used in overview | text |\n|---|---|---|---|")
for q in Q:
    w(f"| {q['id']} | {q['v']}/{q['d']} | {'*' if q['id'] in used else ''} | {q['text']} |")
w("""
Overview quotation "will, needless to say, be effective primarily through what Americans, both here and there, do rather than through what JUSPAO says or prints" is the tail of Q18; "has dropped from 52 percent to 38 percent since last December" is the tail of Q19; "not worth the effort" was corrected to "has not been worth the effort" (tail of Q25); "real and necessary" is the tail of Q30; "has, from the beginning, considered ..." is the tail of Q21. The Q-numbering above includes a few quotations used only as collection excerpts or notes. A check script (`checkov.py`) confirms each double-quoted string in the overview that is a document quotation is a substring of a verified document text.

## 4. Archival scoping [JSON] and the two channels (never summed)

Channel A, CAME-FROM (document_sources, one row per document):
- For the 22 documents in the collection, the series per `document_sources` (SELECT repository, record_group, lot_file, series_name, citation_era FROM document_sources WHERE volume_id=? AND document_id=?): Record Group 306 for eight (Director's Subject Files, Office of Policy and Plans, Office of the Director), Record Group 59 for eight (decimal and lot files, central policy file D780405-0724, 'Central Files 1964-66'), the Johnson Library for four (National Security File, Confidential File), Record Group 305 for one (as printed), and the Executive Secretariat Files for one (named series). 8+8+4+1+1 = 22.
- For S1 (61 Agency/State area memoranda in G): `arch1.out` lists RG 306 'DIRCTR Sub Files' 7, 'Director's Subject Files' 4+4+2, 'DIRCTR Files Bx 33-36' 3, 'Office of Policy and Plans' 2+2, and RG 59 lot files; SQL at the top of arch1.out.
- For S2 (1,984 documents in R): top series are RG 59 lot files (181 documents), Nixon Presidential Materials NSC Files (126), Johnson Library National Security File (114), Kennedy Library National Security Files (50), Eisenhower Library Whitman File (31), CIA (23); and the top lots are 63 D 351 (26), 72D415 (17), 62 D 430 (12), 67 D 54 (9).
Channel B, POINTED-AT (external_citations; no row before 1910-12-06; stores the citation fragment not the sentence; lot, library and decimal anchors only): over S2, Department of State lot anchors 66D95 (67 citations in 53 documents) and 63D351 (24 in 19), both resolving to NARA 2839192; Johnson Library National Security File (72 in 55); Nixon NSC Files (69 in 49); Kennedy NSF (20 in 18); 62D430 (15 in 12); 62D1 (14 in 13); Carter Library National Security Affairs (14 in 9); 427 State Department citations in 243 documents name no lot and resolve to nothing. The two channels were not combined. S2 is the 1,984-document set, not the 22 cited documents, which carry only five external citations between them.

Resolution against the bundled JSON (container shapes read first: `central-files-index.json` lotFiles list keyed `lotNumber` with spaces folded; `series-facts-index.json` byNaId one-letter keys through `legend`; `accession-series-index.json` keyed `<record group>/<accession>`; `collection-authority.json` list of collections; `presidential-library-catalog.json` libraries list). Results quoted in the overview:
- 306/72A5121 (record group is part of the key): 18 series claimed, including 1257679 "Subject Files" (series-facts: creator USIA Office of Policy and Plans; inclusive 1953-1971; coverage 1949-1971; 47 linear feet; access "Restricted - Partly", FOIA (b)(1) National Security; National Archives at College Park). The same NAID 1257679 is also the State Department's "Lot 59 D 260" (USIA/IOP files) in collection-authority. The index cannot say which claimed series holds "Entry UD WW 257". 306/69A3445 claims 9 series; 306/68A4933 claims 15 (including 1102141 "Subject Files of the Director", 42125423 "Vietnam Working Group Subject Files", 51089294 "Country Files for Indonesia", no facts rows) but the 68 A 4933 accession was cited only in documents I read and did not cite (frus1961-63v02/d5, d16), so it is not in the overview. Entries A1-42, P-104, P-207 and UD WW 193 are not resolved by any bundled file (grep of all JSON for "UD WW 257" found nothing).
- 63D351 and 66D95 -> NAID 2839192, "Records Relating to National Security Council Policy Papers", RG 59, entry A1 1586E, Executive Secretariat, inclusive 1947-1979, Restricted - Partly. 62D430 -> NAID 2839191 "Subject and Special Files", entry A1 1586C, Executive Secretariat, 1953-1961, Restricted - Partly. 62D1 -> NAID 2838992, Policy Planning Council, 1948-1961, Restricted - Partly. 61 D 385 (S/S OCB Files) is in collection-authority but has no resolved series.
- presidential-library-catalog.json: Johnson Library National Security Files LBJ-NSF NAID 567979; Kennedy Library JFK-4 National Security Files NAID 1164; Carter Library Zbigniew Brzezinski Collection NAID 1104. Nixon Presidential Materials: not located in the library catalog; the overview says so.
- The offline stack barely reaches before 1940 (house rule: 11 of 695 bundled series); I did not measure that figure; it is quoted from the house rules and used only to explain why no pre-1945 shelf is named.
- decimal-class-labels.json was not used: I did not gloss any decimal file number (511.90, 790.5, 611.95, 611.98, 793.11 appear only as printed).

## 5. VECTORS

Files: `/Applications/FRUS Explorer.app/Contents/Resources/semantic-vectors-index.json`, `semantic-vectors-binary.bin`, `semantic-map.bin`; shard `/Users/jbotts/frus-analysis/c3/SemanticVectors/frus1964-68v01.vec` and its `.generation`. Script `vec.py`, `vecnn.py`; outputs `vec_setup.out`, `vec_nn.out`, `vec_baselines.json`.
- Digest check: provenance digest 89481b18...e6101 is identical in the index, the binary header, the map header, the shard header and `.generation`: equal. Generated 2026-10-15, EmbeddingGemma 2. No generations mixed.
- Id decode: segment decode round trip, decoded length = n for 553 of 553 volumes and 314,616 rows; identity only from the index's segments.
- Baselines at this digest: random pairs (20,000 pairs, random.Random(1877)): mean 167.1, sd 14.8, 1st percentile 132, minimum 95 of 512. k-th neighbour over 200 sampled documents (random.Random(2026)): median 1st neighbour 83, 10th 100, 25th 106 (quartiles 100 and 113). Funnel recall@10 = 0.9021 (index retrieval.measuredRecallAt10), so absence of a neighbour proves nothing.
- Operation 1, NEAREST NEIGHBOURS OF A DOCUMENT (sign-bit XOR-popcount, full scan of 314,616 rows via numpy): anchors frus1917-72PubDipv08/d31 (Oleksiw PAO conference summary, 1969), frus1961-63v23/d289 (Murrow on Indonesia, 1962), frus1969-76v38p2/d105 (Payeff reassessment, 1975). Top 15 each, Hamming distances raw (no cosine computed or shown), read against both baselines (random pairs and the k-th-neighbour distribution): d31's nearest at 81, 86, 88 are below the 1st-neighbour median 83 only for the first, and within the 10th-neighbour median (100) for all 15 (largest 95); d289's nearest is 89 and the 15th 106 (at the 25th-neighbour median), so d289's neighbours are weak; d105's nearest at 76 and 15th at 86. Output in vec_nn.out. All neighbours are in document_cache (none flagged NOT-IN-DB); apparatus rows (an Editorial Note frus1950v06/d9) were flagged and dropped.
- Neighbours read and used: frus1917-72PubDipv08/d99 (USIA Agency Program Memorandum, 30 July 1970), Hamming 90 from d31 (inside d31's 10th-neighbour median of 100, far inside random pairs' mean 167). It lies in a Public Diplomacy volume (G), outside R, and its header names no Asian place, so neither my R-restricted full-text union (M04) nor the Asia-header filter (M06) selected it; it is the one document in the overview reached through a vector operation and through no full-text query run in this session. I read it whole before citing it (Q35-Q37). Other neighbours seen (frus1977-80v30/d68, frus1917-72PubDipv06/d5, frus1958-60v17/d138, frus1969-76ve12/d10) were opened in part and not cited. The similarity is a suggestion; the claim comes from the text.
- Operation 2, SEMANTIC JOIN into the database: none.
- Operation 3, CENTROID/VOLUME SIMILARITY: none.
- Operation 4, THE MAP (semantic-map.bin clusters): none.
- Operation 5, NEAR-DUPLICATE DETECTION: none run as such (the minimum neighbour distance in the three lists is 76, well above a reprint-level distance; I did not use §14.9's recipe).
- Operation 6, TIER-2 RERANK: none; the shard was opened only to compare its digest.
Documents in the overview reached through a vector operation and through no full-text query: frus1917-72PubDipv08/d99 only.

## 6. Findings not made

No density, decade-shape or per-1,000 claim is made. No claim about "the audience" is made from audience evidence: the beliefs in Finding 4 are officials' statements; the exceptions are the Japan poll quoted in frus1964-68v29p2/d46 and the post survey in frus1917-72PubDipv08/d149, both reports by officials of what they saw.

## 7. Documents in the collection (22; each verified present in document_cache, non-apparatus, no duplicates, no Ed2)

`final_docs.py` asserts it: `SELECT volume_id,document_id,document_number,header,dateline,is_front_matter,is_editorial_note,length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?`.

| volume_id/document_id | dateline | edition |
|---|---|---|""")
for x in D:
    w(f"| {x['v']}/{x['d']} | {x['dateline']} | {x['title']}, Document {x['num']} |")
w("""
## 8. TRACE TABLE (every number and quotation in the overview, its memo line)

Numbers in running text (the overview's own heading numbers 1 to 5, and the numbers inside the citations, which come from section 7 and quotation table 3, are not repeated).

| overview text | memo line |
|---|---|
| "seventy-six" East Asia and Pacific volumes (Scope; How this was done; control sentence) | M02 (76 volumes) |
| "about thirty-seven thousand documents" | M02 (37,543 non-apparatus documents) |
| "about two thousand documents" | M04 (1,984), M05 (literal share 35 of 40 tolerant, 33 of 40 strict) |
| "about sixty" area memoranda | M06 (61) |
| "553 volumes indexed" | M01 |
| "a sample of forty documents" | M05 (40) |
| "from 1945 to 1980" | section 1, inclusion rule (volume series years of R) |
| "for 1949 to 1978" | section 7: earliest cited 19 August 1949 (frus1949v09/d558), latest 4 October 1978 (frus1977-80v30/d152) |
| "Department of State" appeared in "every one of the seventy-six" regional volumes; impossible string in none | M07 (76 of 76; 0) |
| "soft power" appears in no document | M07 (0 in R, 0 in the whole corpus) |
| years in running text: 1924, 1949, 1950, 1953, 1955, 1962, 1964, 1965, 1966, 1968, 1969, 1970, 1971, 1975, 1977, 1978 | section 7 datelines (1924 d540; 1949 d558; 1950 d50; 1953 d403; 1955 frus1955-57v22/d447 and v23p2/d50; 1962 frus1961-63v23/d289; 1964 frus1964-68v01/d122 and PubDipv07/d32; 1965 v02/d160, v26/d106, v29p2/d46; 1966 PubDipv07/d85; 1968 v27/d386; 1969 PubDipv08/d31 and d58; 1970 d99; 1971 d146 and d149; 1975 v38p2/d105; 1977 v30/d79; 1978 v30/d152) |
| "before 1945", "before 1940" | section 1/M07 (pre-war probe); 1940 from the house rule quoted in section 4 (not measured) |
| "52 percent to 38 percent" | Q19 |
| "April 1964" | frus1964-68v01/d122 dateline, section 7 |
| archival numbers: Record Group 306 (eight of the cited documents), accession 72 A 5121, entry UD WW 257, NARA 1257679, 1953-1971, 47 linear feet | section 4 (306/72A5121 and series-facts 1257679) |
| entries A1-42, P-104, P-207, accession 69 A 3445, entry UD WW 193 | section 4 (document_sources raw text of d58/d99/d146/d149, d79, d31, d85; unresolved) |
| Record Group 59, decimal files 511.90, 790.5, 611.95, 611.98, 1964-1966, D780405-0724 | section 4 (document_sources for frus1950v06/d50, v12p2/d403, v23p2/d50, v23/d289, v29p2/d46, v30/d152) |
| Lots 61 D 385, 62 D 430, NARA 2839191, 1953-1961 | section 4 |
| Johnson Library National Security File, NARA 567979 | section 4 (presidential-library-catalog LBJ-NSF) |
| NARA 2839192, Lots 63 D 351 and 66 D 95, entry A1 1586E, 1947-1979 | section 4, S2 pointed-at |
| Kennedy Library NARA 1164; Carter Library NARA 1104 | section 4 |
| Lot 62 D 1, NARA 2838992, 1948-1961 | section 4 |
| "1924-1978" collection name | section 7 (earliest and latest cited) |
| "both" / "one of them" / "second" / "a number of series" | not counts of anything measured; "a number of" = 18 series claimed under 306/72A5121 (section 4) |
""")
for qid in ["Q01","Q03","Q05","Q10","Q21","Q35","Q38","Q13","Q18","Q19","Q25","Q12","Q22","Q07","Q28","Q30","Q27","Q31"]:
    q=next(x for x in Q if x['id']==qid)
    w(f"| quotation {qid} ({q['v']}/{q['d']}) | quotation table, section 3 |")
w("""
## 9. Checks run before finishing

- Every quotation in the overview is one the memo verified against its document (section 3; `checkov.py`: all document quotations OK; the unmatched strings are the phrase "soft power", series titles, control phrases and the collection name, none a document quotation).
- Every document the overview cites (22) is in the collection and no collection document is uncited (`checkov.py`: "all cited docs in collection: True; collection docs not cited: []"), and the Documents cited list follows first-citation order.
- Collection: formatVersion 2, minimumReaderVersion 1, six composition keys, every document and excerpt entry carries volumeId and documentId, no duplicate pair, each pair verified in document_cache, no Ed2 beside a first edition, each excerpt a substring of its document (`mkcoll.py`).

## 10. Not done / limits

The educational-exchange record for Japan, Korea and the Philippines was not read systematically; Voice of America content is not in the corpus; the USIA research reports are not located by the bundle; the 1950s Indonesian and Philippine assessments were skimmed. Phrase counts in vocab1.out and pre.out carry no literal share. A stemmed index cannot split "Asian"/"Asians" or "face"/"faces"; I used those only to find documents, never to count. The audience-belief searches (`beliefs1.py`) are NEAR queries on stemmed words and returned candidates only.

ELIDED: The long Python bodies are kept in files rather than pasted: h.py, mkscope.py, scope1.py, scope2.py, cnt.py, vocab1.py, union1.py, union2.py, beliefs1.py, gq.py, jk.py, arch1.py, pre.py, share.py, vec.py, vecnn.py, dump.py, kwic.py, quotes.py, final_docs.py, mkcoll.py, mkmemo.py, checkov.py. The list of 76 region volume ids and 10 global volume ids is in scope_sets.json and is not reproduced here. The 1,984-pair hit list is not saved as a file; it is regenerated by the M04 SQL (share.py prints its 40 sampled pairs). The 89 retrieved documents are on disk in docs/ and not listed one by one. Ad hoc reading commands (cat/python windows over docs/ files and bundled JSON key inspections) are logged in queries.log as descriptions, with their bodies elided. Printed outputs of the JSON lookups (section 4) were not saved to files.
""")
open('memo.md','w').write("\n".join(out))
print(len("\n".join(out).split()))
