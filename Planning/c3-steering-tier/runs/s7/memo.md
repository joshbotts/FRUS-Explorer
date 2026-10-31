# Scope memo: corruption and U.S. foreign policy (run s7, 2026-10-30)

M1. COVERAGE. `SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;` -> `553|321749|1103|8481`. All 553 volumes of the series are in this copy (taken 2026-10-25), so every count is over 553 volumes; non-apparatus documents: `SELECT COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0;` -> 312,169 (this denominator includes the two Ed2 volumes). Read-only proof: `BEGIN; CREATE TABLE zz(x); ROLLBACK;` under `-readonly` -> "attempt to write a readonly database".

## Scope chosen
M2. Inclusion rule: non-apparatus documents (is_front_matter=0, is_editorial_note=0) matching the FTS expression `corrupt* OR briberi OR bribe*`, with frus1951-54IranEd2 and frus1969-76ve15p2Ed2 dropped. Set "h":
```
WITH h AS (SELECT DISTINCT c.volume_id v, c.document_id d FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid
 WHERE frus_documents MATCH 'corrupt* OR briberi OR bribe*' AND c.is_front_matter=0 AND c.is_editorial_note=0
 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2'))  SELECT COUNT(*), COUNT(DISTINCT v) FROM h;
```
-> 2,699 documents in 435 volumes. Date span by document_dates.date_iso (the index's per-document date; periodised on that, not on series year): 1840s–1980s. The argument set (collection) is 11 documents in 10 volumes, chosen by bm25 rank within the top volumes (M6) and read whole.

M3. How found: per-family counts (M4), decade shape (M5), top volumes by count (M6, `topvol_corrupt.txt`), then bm25 ranking within volumes, then reading.

## Measurements
M4. Family counts, each `SELECT COUNT(*), COUNT(DISTINCT c.volume_id) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH '<t>' AND c.is_front_matter=0 AND c.is_editorial_note=0;` (Ed2 not dropped here):

| MATCH | docs | vols | literal share (sample of hit list, evenly spaced, (vol,doc)-sorted; regex over header+dateline+source_note+body_text whitespace-collapsed, Python re with re.I) |
|---|---|---|---|
| `corrupt*` | 2,211 | 401 | TOLERANT 40 of 40; STRICT (`\bcorrupt(ion)?\b`) 39 of 40. Referent test: 40 of 40 sampled contexts are political/moral corruption, none a garbled-telegram "corrupt group" (`ctx_corrupt.txt`) |
| `briberi OR bribe*` | 670 | 282 | TOLERANT 40 of 40; STRICT (`\bbriber(y)?\b|\bbribe\b`) 27 of 40 (misses are "bribed", "bribes") |
| `graft` | 367 | 163 | TOLERANT 40 of 40; STRICT 37 of 40 (referent not tested; not used in the overview) |
| `embezzl*` | 169 | 84 | TOLERANT 40 of 40; STRICT 35 of 40 |
| `kickback*` | 18 | 17 | not sampled; not used |
| `"questionable payments"` | 9 | 9 | census: TOLERANT 1 of 9, STRICT 1 of 9 -> UNUSABLE (the stemmer folds "questionable" to "question"; misses e.g. frus1941v01/d479, frus1955-57v16/d386) |
| `"foreign corrupt practices"` | 4 | 2 | census: TOLERANT 4 of 4, STRICT 4 of 4 (a 1.000 tests the stemmer; referent checked by reading frus1977-80v03/d152, frus1977-80v18/d57) |
| `"illicit payments"` | 16 | 4 | census: TOLERANT 16 of 16, STRICT 16 of 16; volumes frus1977-80v03 (10), frus1977-80v24 (4), frus1969-76ve09p2 (1), frus1977-80v17p3 (1) |
| `anticorrupt* OR "anti corruption"` | 56 | 30 | TOLERANT 38 of 40, STRICT 35 of 40; misses frus1955-57v12/d304, d305 not read |
| `kleptocra*` | 0 | 0 | controls in same pass (below) |
| CONTROL `"department of state"` | 94,049 | 552 | absent only in frus1919Parisv05 (query: `SELECT volume_id FROM document_cache GROUP BY volume_id EXCEPT SELECT DISTINCT c.volume_id ... MATCH '"department of state"' ...`) |
| CONTROL `ZZZ_IMPOSSIBLE_ZZZ` | 0 | 0 | |
Shares written by `share.py` to `shares.jsonl`. Counting surface: the database's flattened text; no TEI pass was run, so no spelling-variant split and no document/footnote split exists (body_text includes editorial footnotes).

M5. Decade shape (`decade.py`, output `decade_corrupt.txt`, `decade_bribe.txt`). Denominator: `SELECT substr(d.date_iso,1,3)||'0s', COUNT(*) FROM document_dates d JOIN document_cache c ON c.volume_id=d.volume_id AND c.document_id=d.document_id WHERE d.date_iso IS NOT NULL AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') GROUP BY 1`; numerator the same joined to `frus_documents MATCH ?`. corrupt* per 1,000 dated non-apparatus documents (raw N of M; top volume's share of N):
1860s 74 of 11,268 = 6.57 (frus1865p4 10 of 74); 1870s 64 of 5,821 = 10.99 (frus1875v01 8 of 64); 1890s 72 of 9,845 = 7.31 (frus1894app2 38 of 72 — one volume, Hawaii); 1910s 131 of 30,842 = 4.25; 1920s 40 of 20,374 = 1.96; 1930s 61 of 40,073 = 1.52; 1940s 354 of 75,872 = 4.67 (frus1947v07 59 of 354); 1950s 407 of 42,801 = 9.51 (frus1952-54v13p2 22 of 407); 1960s 457 of 27,654 = 16.53 (frus1964-68v05 40 of 457); 1970s 354 of 22,258 = 15.90 (frus1969-76ve11p1 32 of 354); 1980s 85 of 6,038 = 14.08 (frus1981-88v01 10 of 85). bribe family: 1920s 0.98, 1930s 1.02, 1940s 0.86, 1950s 2.62, 1960s 2.75, 1970s 3.82 per 1,000 (1970s 85 of 22,258; top frus1969-76ve09p2 12 of 85). Overview's "about two per thousand in the 1920s–30s, about sixteen in the 1960s–70s" = these rows.

M5b. Whole-set rate: 2,699 of about 312,169 non-apparatus documents ≈ one in 116 ("about one in a hundred and fifteen" in overview).

M5c. FALSE-FRIEND TEST (question's term "corruption"). Six on-topic volumes V=(frus1947v07, frus1948v07, frus1964-68v04, frus1964-68v05, frus1964-68v06, frus1961-63v22), 3,367 non-apparatus docs. `SELECT SUM(c.volume_id IN V), (SELECT COUNT(*) FROM document_cache WHERE volume_id IN V AND is_front_matter=0 AND is_editorial_note=0), COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH '<t>' AND <nonapp>`: corrupt* 211 of 3,367 in V vs 2,211 of 312,169 corpus (ratio ≈ 8.8); control "department of state" 854 of 3,367 vs 94,049 of 312,169 (ratio ≈ 0.84); control "telegram" 2,247 of 3,367 vs 173,648 of 312,169 (ratio ≈ 1.2). The term is not measuring the corpus. Caveat: V was picked partly from the term's own top-volume list, which flatters the ratio.

M6. Top volumes (`topvol_corrupt.txt`): `SELECT c.volume_id, COUNT(*) n, (SELECT COUNT(*) FROM document_cache x WHERE x.volume_id=c.volume_id AND x.is_front_matter=0 AND x.is_editorial_note=0) tot FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'corrupt*' AND <nonapp> GROUP BY c.volume_id ORDER BY n DESC LIMIT 25;` -> frus1947v07 59 of 1,176; frus1964-68v05 40 of 412; frus1894app2 40 of 535; frus1958-60v01 37 of 264; frus1961-63v22 33 of 347; frus1969-76ve11p1 32 of 473; frus1948v07 32 of 797; ...

M7. Lockheed bribery set: `MATCH 'lockheed AND (briberi OR bribe* OR payment* OR scandal*)'` ordered by bm25 -> frus1969-76ve15p2/d292, ve12/d227, ve12/d218, ve09p1/d49, ve09p2/d135 ... (Ed2 twins appear and were dropped). FCPA set: `MATCH '"foreign corrupt practices"'` -> frus1977-80v03/d152, d230, d248; frus1977-80v18/d57 (4 docs, 2 vols).

M8. Absence searches (same pass, controls M4): `kleptocra*` 0; `"illicit payments"` 16 docs, 4 vols, 1975-08-19..1981-01-02; `OECD AND (briberi OR bribe*)` 12 docs, 4 vols, 1976-05-11..1980-05-27. `SELECT MAX(date_iso) FROM document_dates` -> 2024-03-01 (a publication-type outlier; the 1990s hold 177 dated non-apparatus docs, the 1980s 6,038).

## Archival scope (two channels, never summed; volume set = set h, 435 volumes)
M9. CAME-FROM (document_sources, one row per document). By citation_era: `... SELECT s.citation_era, COUNT(*) FROM h JOIN document_sources s ON s.volume_id=h.v AND s.document_id=h.d GROUP BY 1` -> decimal 1,118; structured 600; lot_file 185; subject_numeric 175; cfpf 116; named_series 51; published 20; unrecognized 15; foreign 2. No document_sources row: 417 of 2,699 (`LEFT JOIN ... WHERE s.volume_id IS NULL`), mostly nineteenth century. Decimal by repository: Department of State/RG 59 1,078; Department of State/RG 256 29; National Archives/RG 59 11. Top decimal classes (`GROUP BY s.decimal_class`): 893.00 152 (dates 1911-10-23..1949-09-03; 1910–1949 schedule: Internal Affairs of States / China / Political affairs); 751G.00 33 (1951–59; 1950–59: Internal Political and National Defense Affairs / Indo China); 788.00 24 (Iran); 861.00 22 (USSR political affairs, 1917–46); 795B.00 22 (1957-03-30..1962-12-07; South Korea, glossed under 1950–59 and 1960–63 schedules, which agree). Glosses: `gloss.py`, inline lookups, `gloss.txt`; coverage.glossableYears 1910–1963 checked for each.
Top series (`camefrom.txt`): CIA 110; Nixon Presidential Materials, NSC Files 93; Johnson Library, National Security File 71; Carter Library, National Security Affairs 55; RG 59 Central Files 1970–73 41, 1967–69 39, 1964–66 23; Ford Library, National Security Adviser 26; Kennedy Library, National Security Files 25; Eisenhower Library, Whitman File 24; Lot 54D270 17; Lot 63D351 16; Lot 59D95 5; Lot 62D430 5.
M10. POINTED-AT (external_citations; no row before 1910-12-06; stores the citation fragment; lot, library and decimal anchors only). `... SELECT e.anchor, COUNT(*), COUNT(DISTINCT e.volume_id||'/'||e.document_id) FROM h JOIN external_citations e ON e.volume_id=h.v AND e.document_id=h.d GROUP BY 1` -> centralFileClass 383 rows / 225 docs; presidentialLibrary 160 / 118; lotFile 121 / 83. Top (`pointedat.txt`): Carter NSA 27 docs; Johnson NSF 22; Nixon NSC Files 21; Lot 66D95 13; Lot 63D351 8; Lot 62D1 4; Lot 62D430 4. Decimal classes: 795B.00 18 docs (1952-06-13..1962-06-15), 751G.00 16 (1952-05-10..1954-10-27), 751J.00 12, 751K.00 9.
M11. JSON resolution (`resolve_lots.py` -> `lots_resolved.txt`; `preslib.txt`):
- Lot 63D351 and Lot 66D95 -> both RG 59 "Records Relating to National Security Council Policy Papers", Entry A1 1586E, NAID 2839192; creator Dept. of State, Office of the Secretary, Executive Secretariat; 1947–1979; 26 lin. ft. 3 in.; Restricted – Partly, FOIA (b)(1). 66D95 has a second claimant: A1 1586F "Subject Files", NAID 2839193, 1947–1965.
- Lot 62D430 -> RG 59 "Subject and Special Files", A1 1586C, NAID 2839191, 1953–1961, Restricted – Partly; several claimants (A1 1586A NAID 2386675; A1 1586B NAID 2839190; ...).
- Lot 62D1 -> RG 59 "Records Relating to Activities with the National Security Council", A1 1583E/F, NAID 2838992, 1948–1961, creator Policy Planning Council, Restricted – Partly.
- Lot 67D548 -> RG 59 "Chronological Files", A1 558-D, NAID 1136548, 1947–1962, Unrestricted.
- Lots 54D270, 59D95, 62D181, 6D379/06D379: ABSENT from central-files-index.json lotFiles.
- Johnson Library National Security Files LBJ-NSF NAID 567979 (Asia and the Pacific Country Files 1963–1969, NAID 587358); Kennedy Library President's Office Files JFK-3 NAID 1166 (Country Files 1961–1963, NAID 193654); Ford Library Presidential Correspondence with Foreign Leaders GRF-0351 NAID 572571 (series NAID 572583, 1974–1977). The bundled presidential catalogue carries no access status.
- Not resolved: the Central Decimal File itself (no entry/NAID in the bundle for it), Center of Military History "Dep CORDS / MACV Files, GVN Corruption 1967" (source of frus1964-68v05/d258), RG 59 Records of Secretary of State Henry Kissinger, Entry 5403 (source of ve15p2/d292; not looked up), Carter Library White House Central Files (source of 1977-80v03/d152).
- Pre-1940: the offline stack barely reaches before 1940 (11 of 695 bundled series); the 1875 Venezuelan documents have no source row at all, so no archival roadmap for Finding 1 is an empty stack, not an archival absence.

## Reading
M12. Reading SELECT (`dump.py`): `SELECT header,dateline,source_note,body_text,length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?`, raw text in `raw/`. Retrieved whole: 18 documents, 147,438 characters (`reads_unique.txt`): frus1947v07/d582 3,521; frus1948v07/d43 1,711; frus1964-68v04/d215 4,047; frus1964-68v05/d258 5,862; frus1961-63v22/d202 4,694; frus1969-76ve12/d218 3,216; frus1969-76ve15p2/d292 3,590; frus1969-76ve09p2/d135 2,512; frus1977-80v03/d152 15,423; frus1977-80v15/d75 2,551; frus1875v01/d199 1,254; frus1977-80v18/d57 13,056; frus1874/d807 15,117; frus1875v02/d393 7,586; frus1876/d345 14,217; frus1961-63v22/d204 2,621; frus1958-60v18/d266 17,356; frus1961-63v04/d347 29,104. Captured length = length(body_text) for all 18. Quoted: 11 documents, 14 quotations.
Date note: document_dates gives frus1875v02/d393 as 1874-06-04; its dateline reads "Department of State, Washington, June 4, 1875." The collection orders by the dateline.

M13. QUOTATIONS, verified by `verify.py` (`SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0`; exact, case-sensitive substring after whitespace collapse) -> 14 of 14 OK (`verify.txt`, `quotes.json`):
- Q1 frus1875v02/d393: "and have been met by vague promises, and still more vague allegations of corruption on the part of individuals"
- Q2 frus1875v01/d199: "The alleged corruption of the arbitral commission which awarded those claims is Blanco’s pretext for the proposed bad faith of his government."
- Q3 frus1947v07/d582: "The information received in Shanghai serves to reaffirm earlier certainty of corrupt and inept practices, both political and economic."
- Q4 frus1947v07/d582: "They fear that the Central Government contemplates bleeding their island to support the tottering and corrupt Nanking machine and I think their fears well founded."
- Q5 frus1948v07/d43: "many US reporters, when they come across any corruption or graft, play up the cases, making the US public believe that the entire Chinese Government is corrupt."
- Q6 frus1961-63v22/d202: "seriously endanger the whole U.S. position in Korea, and threaten to discredit, not only the aid program in Korea, but the Mutual Security program as a whole."
- Q7 frus1961-63v22/d204: "The underlying fact is that all hands agree the situation in Korea is not good"
- Q8 frus1964-68v04/d215: "Earlier in the day he had decided not to raise this subject with General Ky because he did not want to urge on Ky a step which might precipitate a coup."
- Q9 frus1964-68v04/d215: "There is no doubt in his mind that there is widespread disgust with corruption and that it shakes confidence in the government and in the integrity of the elections."
- Q10 frus1964-68v05/d258: "I agree that the level of corruption in Viet-Nam has reached a point where, as you point out, it has become a key obstacle to pacification."
- Q11 frus1964-68v05/d258: "I do not think it would be wise for us to seek such control."
- Q12 frus1969-76ve12/d218: "if the whole issue is kept unsolved with the names of the officials involved remaining in doubt, democracy in Japan may suffer a fatal blow."
- Q13 frus1969-76ve15p2/d292: "Such payments coming when Strauss was Defense Minister paved the way for the sale of the Starfighter to the FRG." (An allegation relayed from a Senate subcommittee staff member, as the memo itself says.)
- Q14 frus1977-80v03/d152: "terminate or severely curtail our arms sales and human rights efforts and repeal the foreign bribery and Arab boycott laws"

## VECTORS
M14. Provenance (`vec_setup.py`, `vec_setup.txt`): provenanceDigest 89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101 in semantic-vectors-index.json, semantic-vectors-binary.bin (offset 20), semantic-map.bin (offset 20), semantic-map-index.json, semantic-shards-manifest.json key present, SemanticVectors/.generation, and every shard opened (offset 16, checked in `vec_nn.py`, which aborts on mismatch): all equal. Index generated 2026-10-15, harvestGenerated 2026-10-15T06:55:14. retrieval.measuredRecallAt10 = 0.9021; rerankPool 800; scoreCalibration documentOffset 0.40, queryOffset 0.47. Segment decode round trip: 553 of 553 volumes; 314,616 rows.
M15. Baselines at this digest: random pairs (20,000, random.Random(1877)): mean 167.1, sd 14.8, 1st percentile 132, min 95 of 512 bits. k-th neighbour over 200 documents (random.Random(1877).sample): 25th-neighbour median 108 (quartiles 101, 114); 1st-neighbour median 82.
M16. Operations run:
- NEAREST NEIGHBOURS (Hamming top-800 over Tier-1 sign bits, reranked by Tier-2 int8 cosine; `vec_nn.py`, `vec_nn.txt`). Cosines shown calibrated = (raw − 0.40)/0.60 and raw beside.
  - Anchor frus1964-68v05/d258: top 10 at Hamming 97–109 (within the 25th-neighbour quartiles: ordinary close neighbours, not exceptional), calibrated 0.80–0.83; all Vietnam 1961–69 plus frus1917-72PubDipv07/d177. 7 of 10 match the corruption family in FTS.
  - Anchor frus1961-63v22/d202: top frus1961-63v22/d204 (Hamming 97, calibrated 0.846, raw 0.908), d203 (105), frus1958-60v18/d266 (112), d265 (119), d283 (122) ... 5 of 10 do not match the corruption family.
  - Anchor frus1969-76ve15p2/d292: Ed2 twin at Hamming 0; frus1969-76ve15p2/d293 at 81; then 130+ (beyond the 25th-neighbour third quartile of 114: this memo is near-isolated apart from its companion).
- SEMANTIC JOIN: neighbours × FTS membership (`fts_hit` in `vec_nn.py`: `SELECT 1 FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'corrupt* OR briberi OR bribe* OR graft OR embezzl*' AND c.volume_id=? AND c.document_id=?`). Neighbours of the Farley report outside the word family: frus1961-63v22/d204, frus1958-60v18/d266, d265, d283, frus1961-63v22/d208. Read d204 and frus1958-60v18/d266 (and frus1961-63v04/d347 from the Vietnam anchor). d204 is Rostow to Kennedy about the Farley report — on-topic by reading; used in Finding 3. d266 concerns election irregularities and press coverage in Korea, 1959 — on the edge; not used.
- NEAR-DUPLICATES (`neardup.py`, `neardup.txt`): minimum Hamming from each cited document to every other row. frus1969-76ve15p2/d292 -> 0 to its Ed2 twin (dropped by rule); frus1969-76ve12/d218 -> 54 to ve12/d219 (Ford's reply, read by header only: a reply, not a reprint); all others 80–101 (not reprints).
- CENTROID SIMILARITY: none. MAP: none.
- All neighbour volumes are present in document_cache (all 553 are). Recall 0.902 < 1: the lists may miss true neighbours; no absence is claimed from them.
M17. Overview documents reached through a vector operation and through no full-text query: frus1961-63v22/d204 (Finding 3). All other overview documents were reached by full-text queries.

## TRACE TABLE (overview item -> memo line)
| Overview item | Memo |
|---|---|
| "about 2,700 documents in about 435 of the 553 volumes" | M2 |
| "about one in a hundred and fifteen" | M5b |
| "about two per thousand in the 1920s and 1930s ... about sixteen in the 1960s and 1970s" | M5 |
| "1940s ... the 1947 China volume alone supplies about one in six" | M5 (59 of 354) |
| bribery words rising to about four per thousand in the 1970s | M5 (3.82) |
| "about forty per cent come from the State Department's decimal file" | M9 (1,089 of 2,699) |
| "about one in six has no source note" | M9 (417 of 2,699) |
| decimal class counts (China ~150, Indochina ~30, South Korea ~20) | M9 |
| pointed-at counts (about 225 / 120 / 80 documents) | M10 |
| lot resolutions, NAIDs, entries, dates, access | M11 |
| "four documents in two volumes" (FCPA) | M4, M7 |
| "sixteen documents in four volumes" (illicit payments) | M4, M8 |
| "questionable payments" unusable, 1 of 9 | M4 |
| kleptocracy 0 with controls | M4, M8 |
| 1980s about 6,000 vs 1940s about 76,000 dated docs | M5 |
| Quotations Q1–Q14 | M13 |
| Rostow memo found by semantic neighbour | M16, M17 |
| eighteen documents read whole, fourteen quotations from eleven | M12 |

ELIDED (memo): the full 25-row top-volume and top-series lists are in `topvol_corrupt.txt`, `camefrom.txt`, `pointedat.txt`; claimant lists in `lots_resolved.txt` are truncated at 600 characters there and here.
