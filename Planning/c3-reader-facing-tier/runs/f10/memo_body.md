# Scope memo, run f10 (for the operator)

Question: how policymakers assessed American soft power in East Asia and the Pacific, what messaging strategies they used, how effective they thought them, and what beliefs about the audience shaped them. Run date 2026-10-31. Every SQL is run read-only against the 2026-10-25 copy. Script names below refer to files in this run directory; each script and its output stay on disk.

## 0. Coverage and controls (M1, M2)

**M1. Coverage (the canary, the first tool call).** Index copy holds 553 volumes. All counts below are conditional on this copy; it holds the whole series, so nothing here is a partial-library artefact, but the scope (105 volumes) is my choice.

```
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;
-> 553|321749|1103|8481
```
Read-only proof: `sqlite3 -readonly DB "BEGIN; CREATE TABLE zz(x); ROLLBACK;"` returned "attempt to write a readonly database".

**M2. Controls (same pass, scan1.py).** Predicate, run per volume with apparatus excluded:
`SELECT f.volume_id,count(*) FROM frus_documents f JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 GROUP BY 1`
with ? = `"Department of State"` (positive) and `ZZZ_IMPOSSIBLE_ZZZ` (negative).
- Positive control: hits in 552 of 553 volumes (94,049 documents); the one volume with none is frus1919Parisv05, outside the scope. In all 105 scope volumes the positive control is non-zero.
- Negative control: 0 documents in all 553 volumes.
- `"soft power"` (same predicate form, whole index): 0 documents. A negative built on a later vocabulary is circular, so it is reported but not used; I searched the contemporaries' terms instead (M4, M6). The counterpart's vocabulary (the audience's own terms) is not searchable in this English index; flagged in the overview (3b).

## 1. Scope chosen and how found (M3)

**Rule.** All non-apparatus documents (is_front_matter = 0 and is_editorial_note = 0) in 105 volumes: (a) 99 volumes on East Asia and the Pacific, chosen from the manifest's volume titles by regex (China, Japan, Korea, Vietnam, Indochina, Philippines, Indonesia, Southeast Asia, Laos, Cambodia, Burma, Taiwan, Far East, East Asia, Pacific) and then edited by hand (file `eap_vols.txt`; list printed in `vols_eap.txt` for the first pass; South Asia, Near East and Europe volumes removed; 23 Far East volumes 1901-1949 added in a second pass); (b) the six volumes whose titles name public diplomacy or the foreign information program (`frus1917-72PubDipv06`, `v07`, `v08`, `frus1977-80v30`, `frus1955-57v09`, `frus1961-63v25`). The combined list is `scope105.txt`. No volume ending in Ed2 is in scope, so no second-edition suppression was needed.

**Inclusion rule for the argument** (as distinct from the search scope): a document goes in the collection only if it (i) assesses the effect, reception or audience of an information, cultural, educational or psychological program aimed at East Asia or the Pacific, or (ii) states a belief about the regional audience that shaped such a program, or (iii) records the program's end. Economic aid and military presence were excluded as instruments.

**How found.** Chapter headings (volume_structures) in the information-policy volumes are years or appendices, not themes (`vol_chapters.txt`), so there was no editors' formula to exploit; I used the Agency's own names (USIA, USIS, Information Agency, public affairs, psychological) and the offices' names ("East Asia and the Pacific", "Far East") as the search handles, then regional and audience words. Document headings (`header`) name the sending office, which is how the Assistant Director for East Asia and the Pacific's memoranda were found.

**M3. Size of the scope.** 105 volumes; non-apparatus documents in them: 58,244 (scan1.py `dS`: sum of per-volume non-apparatus counts, `SELECT volume_id,count(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0 GROUP BY volume_id`). The six information volumes alone: 1,373 non-apparatus documents (`SELECT count(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0 AND volume_id IN (...six ids...)`).

**Periodisation.** By `document_dates.date_iso`, not by the volume's series year. Spot check against the TEI: for frus1917-72PubDipv07/d73 the TEI attribute `frus:doc-dateTime-min` is 1966-01-25T00:00:00-05:00 and `date_iso` is 1966-01-25 (one document checked; the other dates are the index's). Counting surface: FTS5 index (porter stems; flattened text; apparatus excluded by column), then, where stated, a Python regex over header + dateline + source_note + body_text, whitespace-collapsed. Raw-TEI and tag-stripped counts were not made. Footnotes are part of body_text, so rates blend document and editor language.

## 2. What was measured

**M4. The Agency family and the stem trap.** Family A = `"United States Information Agency" OR "United States Information Service" OR USIA OR USIS` (FTS5 MATCH, scope105, apparatus excluded).
- FTS candidates: 1,538 documents (scan1.py FAMILY_A).
- Literal share, sample of 40 evenly spaced from the (volume_id, document_id)-sorted hit list (share.py, `shares.jsonl`): STRICT regex `United States Information (Agency|Service)|USIA|USIS` (case-sensitive): 34 of 40; TOLERANT regex `(U\.?\s?S\.?|United\s+States)[\s-]+Information[\s,.-]+(Agenc|Servic)\w*|USIA|USIS|U\.S\.I\.[AS]\.` (case-insensitive): 34 of 40. Tolerant 0.85, above the 0.80 floor but the misses are a stem collision, not inflections: porter folds USIS to "usi", so the match returned "USI" (United States of Indonesia) and "USIE". For the 99-volume East Asia scope alone the sample was 32 of 40 strict and 32 of 40 tolerant (0.80, N_hits 898).
- Because of the collision I did not publish the FTS count. `famA_literal.py` re-ran the tolerant regex over all 1,538 candidates: **1,329 of 1,538** confirmed (86.4%); the confirmed list is `famA_literal.tsv`. This is a census, not a sample.
- The referent was not tested separately beyond reading: the 30 documents read all concern the Agency's work, but the 1,329 include any passing mention of USIS (e.g. 1949 China closure notices).

**M5. Rate by decade (Family A, literal-confirmed; famA_literal.py).** Denominator: dated non-apparatus documents of the scope105 volumes in that decade (join of document_cache and document_dates on both keys).

| Decade | Documents naming the Agency or its posts | Dated non-apparatus documents in scope105 | Per 1,000 | Top volume's share of the numerator |
|---|---|---|---|---|
| 1940s | 153 | 19,556 | 7.8 | frus1949v08: 65 of 153 (42%) |
| 1950s | 249 | 13,171 | 18.9 | frus1955-57v03mSupp: 25 of 249 (10%) |
| 1960s | 684 | 8,725 | 78.4 | frus1917-72PubDipv07: 147 of 684 (21%) |
| 1970s | 240 | 3,685 | 65.1 | frus1977-80v30: 121 of 240 (50%) |
| 1980s | 3 | 122 | 24.6 | frus1977-80v30: 3 of 3 |

Flags: the six information volumes are included in the denominator and are dense in the Agency by construction; the 1970s rate is half one volume and is not a trend; 1980s is three documents. No Agency existed before 1953: the 1940s numerator is the State Department's earlier United States Information Service posts (the literal 'USIS'), mostly in China (one volume, frus1949v08, supplies 42%).

**M6. False-friend / baseline test (scan1.py + inline era-matched script).** Per 1,000 non-apparatus documents, scope105 versus all other volumes, and versus an era-matched control (volumes outside scope whose manifest dateRange.earliest is 1953 or later; 169 volumes, 55,876 documents; scope volumes with earliest 1953 or later: 18,483 documents).

| Term (FTS, single words) | Scope105, all eras | Rest of corpus | Scope, volumes from 1953 | Control volumes from 1953 |
|---|---|---|---|---|
| Family A (FTS count, not literal) | 1,538 of 58,244 = 26.4 | 1,615 of 253,925 = 6.4 | 1,103 of 18,483 = 59.7 | 1,292 of 55,876 = 23.1 |
| propaganda | 3,407 of 58,244 = 58.5 | 8,700 of 253,925 = 34.3 | 1,654 of 18,483 = 89.5 | 3,439 of 55,876 = 61.5 |
| prestige | 2,108 of 58,244 = 36.2 | 5,827 of 253,925 = 22.9 | 977 of 18,483 = 52.9 | 2,297 of 55,876 = 41.1 |

Reading: the Agency family is 2.6 times the era-matched baseline, so it measures the topic. "propaganda" is 1.5 times and "prestige" 1.3 times, i.e. close to the corpus baseline; "prestige" is therefore a corpus word and I used it only as a search handle, not as evidence (the overview names it as one of the officials' terms, nothing more). Literal shares for these two single-word counts (share.py, scope105, sample of 40): propaganda 40 of 40 strict and 40 of 40 tolerant (N_hits 3,407); prestige 40 of 40 and 40 of 40 (N_hits 2,108).

**M7. Regional mention census in the six information volumes (region_census.py).** Python regex (case-sensitive, word-bounded) for East Asian and Pacific place names and "Far East"/"Asia" over header + dateline + source_note + body_text of every non-apparatus document: frus1917-72PubDipv06 69 of 152; PubDipv07 98 of 178; PubDipv08 92 of 179; frus1977-80v30 71 of 212; frus1955-57v09 75 of 199; frus1961-63v25 174 of 453; total **579 of 1,373** (about two in five). A mention is not a subject; this is a screen. List in `region_docs.tsv`.

**M8. Thin pre-war result.** `"Boxer indemnity"` (FTS phrase, EAP 99 volumes): 99 documents (1930s 81, 1940s 17, 1950s 1 by document_dates); literal share on the 40-document sample: STRICT `Boxer [Ii]ndemnity` 38 of 40, TOLERANT `Boxer[\s,.\-]+indemnit\w*` 40 of 40. The 1931 document used (frus1931v03/d939) is one of the 81. The bundled archival indexes reach few series before the war (the guide states 11 of 695); that is a limit of the tools. I published no other phrase count; counts for "Office of War Information" (41 in the 1940s) and "American prestige" were run but are left out of the overview because I did not run their literal shares.

**M9. Where the 30 documents came from (the came-from channel).** From the source-note rows, per document: `SELECT d.volume_id,d.document_id,dd.date_iso,s.repository,s.record_group,s.lot_file,s.series_name,s.citation_era FROM document_cache d LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id LEFT JOIN document_sources s ON s.volume_id=d.volume_id AND s.document_id=d.document_id WHERE d.volume_id=? AND d.document_id=?` for each of the 30 pairs (`coll_docs.txt`; output `coll_sources.tsv`). Tally (repository, record group): State Department 59 = 9; National Archives 59 = 4 (together **13 of 30**, RG 59); National Archives 306 = **10 of 30**; presidential libraries **7 of 30** (Johnson 5, Kennedy 1, Nixon 1). Johnson: National Security File 3 (frus1964-68v01/d122, v02/d172, v26/d106), Confidential File 1 (v02/d160), Marks Papers 1 (PubDipv07/d147). This is a channel over 30 selected documents, not over a volume set; it is not summed with M10.

**M10. What footnotes cite without printing (the pointed-at channel).** `SELECT repository,collection,lot_file,count(*) n_rows,count(DISTINCT volume_id||'/'||document_id) n_docs FROM external_citations WHERE volume_id IN (...) GROUP BY 1,2,3 ORDER BY n_rows DESC LIMIT 12`.
- 99 East Asia volumes (13,473 rows in 8,471 documents): Department of State, no lot or collection (central decimal files) 8,779 rows in 5,636 documents; Nixon Presidential Materials NSC Files 782/539; Johnson Library National Security File 671/509; Department of State lot 66 D 95 206/169; Kennedy Library National Security Files 181/146; lot 63 D 351 120/88; Carter Library National Security Affairs 117/81; Johnson President's Daily Diary 101/88; lot 93 D 82 79/52; lot 53 D 413 73/57; Eisenhower Whitman File 71/65; lot 60 D 627 65/55 (rows/documents).
- Four public-diplomacy volumes (PubDip v06 to v08, 1977-80 v30): 116 rows in 85 documents; largest: Carter National Security Affairs 21/17, Nixon NSC Files 14/8, Carter White House Central Files 11/9, Kennedy National Security Files 8/6.
- The 30 documents themselves: 7 rows: decimal class 511.00 (frus1952-54v13p1/d116 once; frus1955-57v09/d190 three times), State S/P lot 71 D 273 (frus1964-68v02/d172), Johnson President's Daily Diary (v02/d160), Johnson National Security File Indonesia country file (v26/d106).
- Limits stated by the guide: the channel stores the citation fragment, holds lot, library and decimal anchors only, and has no row before 1910-12-06. It cannot see citations to Record Group 306 files, so it is silent on the Agency's own files. The 99-volume list is about the volumes, not about information programs.
- Decimal gloss: the 511.00 file number in a 1955 document falls inside the 1950-1959 schedule of decimal-class-labels.json, whose class 5 is "International Informational and Educational Relations, Cultural Affairs and Programs"; I glossed the class only, not the full number.

**M11. Resolution against the bundled JSON (archival.py; archival_lots.txt; archival_usia_series.txt).**
- central-files-index.json `lotFiles` (list keyed on `lotNumber`, spaces folded): 63D351 -> NAID 2839192 "Records Relating to National Security Council Policy Papers", RG 59, entry A1 1586E; series-facts-index.json byNaId 2839192: creator Department of State, Office of the Secretary, Executive Secretariat; 26 linear feet 3 inches; 1947-1979; Restricted - Partly (FOIA (b)(1)). 69D260 -> NAID 27022536 "Subject Files", RG 59, entries UD-UP 174 to 177; creator Bureau of Educational and Cultural Affairs, Office of the Assistant Secretary; 11 linear feet 3 inches; 1961-1969; Unrestricted. 93D82 -> NAID 2225592 "Vietnam Special Caption Messages", RG 59, entry P 38; 9 linear feet; 1962-1972; Restricted - Fully. 53D413 -> NAID 2127212 "Military Telegrams Relating to Korea", RG 59, entry A1 1248; 1951-1954; Restricted - Partly. 66D95 resolves to the same NAID 2839192 as 63D351; lot-claimants-index.json lists two claimant series for 66D95 (2839192, and 2839193 "Subject Files", 1947-1965). 60D627 and 54D270 are curated rather than resolved (60D627 a "possible" conference-files series; 54D270 the Marshall Mission files, ten candidate series).
- presidential-library-catalog.json: Johnson Library "National Security Files" NAID 567979 (48 series listed); Kennedy Library JFK-4 National Security Files NAID 1164; Johnson "Papers of Leonard H. Marks" NAID 50809179 (name match only; not checked that it is the USIA director's; there is also a "Leonard M. Marks, Jr." collection); Carter Library "Zbigniew Brzezinski Collection" NAID 1104. Access for the libraries' files is not in the bundled index.
- Record Group 306 (Agency): the FRUS source notes cite entries UD WW 257, UD WW 193, UD WW 101, A1-42, P-104, P-142, P-207 and UD-264. No bundled file resolves an RG 306 entry to a NAID (volume-sources-index.json names RG 306 only as text, with eight occurrences in seven volumes). series-facts-index.json has 14 NAIDs whose creator heading is a USIA or International Information Administration office, none for the Far East or East Asia and Pacific area office; the plausible neighbours are the Office of Policy and Plans (NAID 1257679; 47 linear feet; 1953-1971; Restricted - Partly) and Executive Secretariat series (5634081, 1953-1965, Unrestricted; 40967113, 1961-1966, Restricted - Partly; 40967285, 1956-1972, Restricted - Partly). The series-facts rows carry no title, so I did not verify that any of them is a cited series; NARA's creator attribution can be wrong (the guide measures 56% precision on one route); they are leads only.
- collection-usage-index.json (came-from over the four public-diplomacy volumes, 622 notes that fall in a collection): Director's Subject Files (National Archives) 112; Carter Library National Security Affairs 68; USIA Historical Collection 43; Nixon NSC Files 40; Office of the Director 34; Johnson White House Central Files 30; Office of Plans 27; Office of Policy and Plans 23. Over the 99 East Asia volumes (17,964 notes in a collection): Department of State central files 6,226; Nixon NSC Files 1,775; Johnson National Security File 1,276; Lot 54-D270 1,063. These are note counts for a volume scope; they are not summed with M9 or M10.
- decimal-class-labels.json: glossable years 1910-1949, 1950-1959, 1960-1963 only.

**M12. Pre-1940 archival reach.** Not resolved; reported as a limit of the offline stack (the guide: 11 of 695 bundled series).

## 3. Phrase and word shares in one place

| Label | Predicate | N hits | Sample | STRICT | TOLERANT |
|---|---|---|---|---|---|
| FAMILY_A_EAP | Agency names, 99 EAP volumes | 898 | 40 | 32 of 40 | 32 of 40 (0.80; misses are the USI collision) |
| famA_scope105 | Agency names, 105 volumes | 1,538 | 40 | 34 of 40 | 34 of 40; census 1,329 of 1,538 |
| propaganda_scope105 | propaganda | 3,407 | 40 | 40 of 40 | 40 of 40 |
| prestige_scope105 | prestige | 2,108 | 40 | 40 of 40 | 40 of 40 |
| boxer_indemnity_EAP | "Boxer indemnity" | 99 | 40 | 38 of 40 | 40 of 40 |

Regexes and sampling are in `shares.jsonl`. STRICT = single spaces, exact words; TOLERANT = inflections and any run of space, hyphen, comma or full stop between words. A sample of 40 evenly spaced from the sorted hit list (never fewer than 30); the sets over 300 are therefore sampled, not censused, except Family A, which I censused after the sample showed the collision. All regexes were Python `re`; the FTS stage is SQLite and case-insensitive; I used the Python regex for the whole of each family (STRICT case-sensitive, TOLERANT case-insensitive, as labelled).

## 4. Reading accounting

Retrieved whole to disk (captured length equal to length(body_text), checked for all): 62 documents (`readings/`; the SELECT is logged for each in `queries.log`). Of the 30 documents in the collection, I displayed (by my count) the complete text of 19 and part of 11. Displayed in part: frus1917-72PubDipv07/d32, d102, d147; PubDipv08/d31, d94; frus1949v08/d1576; frus1950v06/d32; frus1955-57v09/d190; frus1964-68v26/d106, d109; frus1964-68v29p2/d46 (the first several thousand characters and keyword windows; the quotations come from the displayed parts). The other 32 retrieved documents were read in part or not used. Quoted: 38 excerpts from the 30 documents (section 6); the overview quotes 44 passages from documents, each inside one of those 38 excerpts (checked by script: every quoted fragment is a substring of an excerpt, and every excerpt a substring of its document's collapsed body_text).

Not read: the underlying USIA reports and surveys the documents cite (not printed), and any document in the 1,329 not among the 62.

## 5. Findings and their support

1. Before the Agency: frus1931v03/d939, frus1948v07/d55, frus1949v08/d1576. Thin: three documents; M8.
2. 1950-55 beliefs and self-assessment: (frus1950v06/d32, frus1952-54v13p1/d116, frus1952-54v12p2/d403, frus1955-57v09/d190). frus1952-54v13p1/d116 was reached through a vector neighbour (section 8).
3. Vietnam: (frus1964-68v01/d122, frus1917-72PubDipv07/d32, frus1964-68v02/d160, v02/d172, frus1917-72PubDipv07/d147). d32 reached through a vector neighbour.
4. Audience answered back: frus1917-72PubDipv06/d107, d126, d133; frus1964-68v26/d106, d109; frus1964-68v29p2/d46; frus1917-72PubDipv07/d72, d102; frus1917-72PubDipv08/d94.
5. What worked / reassurance: frus1917-72PubDipv06/d127, frus1917-72PubDipv07/d73, frus1917-72PubDipv08/d30, d31, d34, d149, frus1977-80v30/d79, d81, d83. frus1917-72PubDipv08/d34 was reached through the map.

Weakest points: the evidence for "effectiveness" is the officials' own assessments plus three USIA surveys (the Long An study of 1964, the 1969 Apollo survey, the 1970 Cambodia survey) and one Japanese poll quoted by the ambassador; no outcome measure. The Vietnam finding rests on four authors' memoranda. The 1950s finding is four documents from an 1,100-plus-volume-document decade of Agency mentions (M5). All findings reflect which documents the editors chose to print; the selection rule is not tested.

## 6. Quotations (every one retrieved by this SELECT, stored in quote_checks.tsv)

The SELECT for each pair: `SELECT header,dateline,source_note,body_text FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0;` The check (build_coll.py) tests that each string is a substring of the whitespace-collapsed body_text. All 38 passed; output `quote_checks.tsv` (column 4 True). The collection's excerpts are these strings; they are written as retrieved, with the typographic apostrophes and quotation marks of the source text.

| Q | volume_id/document_id | Passage |
|---|---|---|
{{QUOTE_TABLE}}

Words in quotation marks in the overview that are not quotations from a document: the search terms "information program", "psychological", "prestige", "image" and "soft power", the control "Department of State", the two series titles in lot descriptions, and the collection's name. Figures taken from the documents but not quoted: for frus1952-54v13p1/d116, "audience total 75 to 100,000 weekly" for films and library attendance "approximately 200,000 annually" (readings/frus1952-54v13p1__d116.txt).

## 7. Searches that returned nothing, or little (with controls)

- "soft power": 0 of 321,749 documents; controls in M2.
- East Asia and Pacific area office files of the Agency: no catalogued series in the bundled JSON (M11); the controls are that the same JSON does resolve RG 59 lots (63D351, 69D260, 93D82, 53D413).
- Pre-1940 instruments: thin (M8). The pre-war empty roadmap is a limit of the tools.
- The audience's own sources: none in this corpus; I did not search for foreign-language enclosures.
- Partial-library flag: not applicable to the index (553 volumes), but the findings rest on thirty documents of 58,244 and should be treated as a guided reading, not an estimate of the corpus.

## 8. VECTORS

Digest check before scoring: the 32-byte provenance digest in semantic-vectors-index.json, the header of semantic-vectors-binary.bin (offset 20), the header of semantic-map.bin, the header of each of the 553 `.vec` shards in the SemanticVectors folder and its `.generation` file are all `89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101`; 0 mismatches. Index: generated 2026-10-15, harvestGenerated 2026-10-15T06:55:14, model embeddinggemma-2-Q8_0, retrieval.measuredRecallAt10 = 0.9021, so about one of ten true neighbours is absent from the funnel's answer. The id decode (Appendix A.3 algorithm) round-trips for 553 of 553 volumes (314,616 rows, none without an id). Identity everywhere below is from the segments; numpy was used (`np.bitwise_count`). Code: `vec_common.py`, `vec_ops.py`, `vec_ops2.py`. Not run: free-text query (no embedder).

**Baselines at this digest (vec_ops.py baseline).** Random pairs (20,000, `random.Random(1877)`): mean 167.1, sd 14.8, 1st percentile 132, minimum 95. 200 random documents (`random.Random(2026)`): the 25th-nearest neighbour sits at a median of 106 (quartiles 100 and 113) and the nearest at a median of 83 (quartiles 75 and 91). Random-pair int8 cosine (300 pairs, `random.Random(7)`): mean 0.704, sd 0.043, which is 0.51 once calibrated. Cosines below are raw int8 cosines from the shards and the calibrated value (cosine minus 0.40, over 0.60, the document-to-document offsets in retrieval.scoreCalibration); never read the raw ones as the app's percentages.

**V1. Nearest neighbours of a document (funnel: Hamming-800 over sign bits, int8 cosine rerank; vec_nn_run1.txt).**
- Anchor frus1917-72PubDipv07/d73 (1966 Far East PAO summary). Nearest by Hamming: 87, 103, 104, 105, 108 (the nearest, 87, lies inside the quartile range 75 to 91 of first-neighbour distances, so it is an ordinary first neighbour, not an outlier). Funnel top ten, with raw/calibrated cosine and Hamming: PubDipv07/d69 0.927/0.878/87; PubDipv08/d31 0.893/0.822/108; frus1952-54v13p1/d116 0.889/0.810/104; PubDipv07/d159 0.886/0.810/103; frus1977-80v30/d68 0.882/0.803/124; PubDipv07/d106; d74; d94; PubDipv08/d99; PubDipv07/d32 0.874/0.791/113.
- Anchor frus1964-68v26/d106: all ten neighbours are Indonesia documents of the same volume (d109, d113, d111, d124, d139, d129, d108, d115, d203) plus d102 (a telegram to London); Hamming 87 to 113. The neighbours are the same crisis, which is a topical neighbourhood, not a finding.
- Anchor frus1950v06/d32: neighbours are other 1950 Far East records (Jessup conversations, ANZUS minutes), Hamming 68 to 90.
- What it found for the argument: frus1952-54v13p1/d116 (Hamming 104, raw cosine 0.889, calibrated 0.810) and frus1917-72PubDipv07/d32 (113; 0.874; 0.791). The baseline for the first: a Hamming of 104 is at the 25th-neighbour median (106), i.e. ordinary for a neighbour of rank 25, not for rank 3, so the distance alone is weak; the cosine of 0.889 is 4.3 standard deviations above the random-pair mean (0.704). Both were read in full or in part and are the substance of Finding 2 and Finding 3; the relationship is the reader's reading, not the vector's.

**V2. Semantic join into the database.** The 30 nearest to frus1917-72PubDipv07/d73 by sign-bit Hamming (87 to 114; none outside the local index) joined to document_dates and document_sources (inline script, `vec_join_dup.txt`): decades 1960s 14, 1950s 15, 1940s 1; sources: State Department RG 59 13, National Archives RG 306 7, Johnson Library 2, Eisenhower Library 3, Kennedy Library 1, National Archives RG 286 1, CIA 1, none stored 2. So a 1966 Far East memo's neighbours are as likely to be 1950s State Department papers as other Agency papers: the 1950s documents on Indochina and Korea (e.g. frus1952-54v13p1/d116, frus1955-57v01/d2) are the cross-decade leads.

**V3. Centroid similarity (vec_ops2.py centroid; vec_centroid.txt).** Volume centroids (first 553 of 660). Nearest to frus1917-72PubDipv07: PubDipv06 0.987, PubDipv08 0.981, frus1977-80v30 0.973, frus1964-68v33 0.965, frus1961-63v25 0.965 (raw centroid cosines; no calibration applies to volume centroids; baseline: its cosine to the other 552 volumes has mean 0.906, sd 0.023, minimum 0.802). Nearest to frus1977-80v30: PubDipv08 0.976, PubDipv07 0.973, PubDipv06 0.970, frus1977-80v28 0.962. Nearest to frus1955-57v09: frus1958-60v04 0.985, frus1952-54v01p1 0.983, frus1964-68v09 0.983 (foreign economic policy volumes: the information program in that volume is a small part of its content). Result: the public-diplomacy volumes are each other's nearest volumes, which confirms the six-volume set is coherent but adds nothing about the region. A float64 spot check of the PubDipv07/PubDipv06 cosine gave 0.9867; numpy emitted matmul warnings in the float32 run, so I treat the first three decimals as reliable.

**V4. The map (vec_ops2.py map; vec_map.txt, vec_map2.txt, vec_cluster138*.txt).** Clusters of anchors: frus1917-72PubDipv07/d73 cluster 29 (terms lao, vietnamese, vietnam, thieu; 8,631 documents); frus1964-68v26/d106 cluster 32 (sukarno, indonesian, indonesia, nasution; 1,125); frus1950v06/d32 cluster 31 (indochina, minh, bao, dai; 2,775); frus1952-54v13p1/d116 and PubDipv07/d32 cluster 29; frus1917-72PubDipv08/d31 and frus1977-80v30/d79 unclustered; PubDipv06/d107 cluster 138 (cia, nsc, usia, inglis; 2,189 documents). Of the 30 collection documents, 6 are unclustered; the rest fall in clusters 29 (10), 138 (5), 32 (4), 3 (3; nanking, shanghai, chinese, tientsin), 31 (1), 7 (1; japanese, sato, japan, kishi). Unclustered share: 88,059 of 314,616 over the whole map (28.0%); era-matched baseline (volumes whose manifest mid-year is 1961 to 1977): 12,952 of 44,225 (29.3%); the four public-diplomacy volumes: 230 of 743 (31.0%, apparatus included in this count). The 30 documents' 6 of 30 (20%) is below baseline; sample too small to read. Cluster 138 is the Agency/NSC organisation cluster; only 33 of the 57,935 documents in the 99 East Asia volumes (apparatus included) are in it, so the Agency's field documents sit in country clusters (29, 31, 32, 3). Using cluster 138 membership within the six information volumes, intersected with M7's regional list, ranked by regional-term density (vec_cluster138_region.txt, 148 members), I read frus1917-72PubDipv08/d34 (the Apollo survey) and frus1917-72PubDipv06/d127 (the astronaut visit; this one had also surfaced in a header search).

**V5. Near-duplicates (vec_join_dup.txt).** Known-reprint calibration: frus1917-72PubDipv06/d141 (whose source note says it is also printed as 1961-63 v04 document 108) against frus1961-63v04/d108: Hamming 56, raw cosine 0.976; PubDipv06/d140 against 1961-63v04/d81: Hamming 53, 0.985. So reprints sit near 53 to 56 bits at this digest. In the collection: the closest pair of the 30 is 76 bits (PubDipv06/d126 and d133, a memo and its reply), so no collection document is a reprint of another; the closest corpus neighbour of any collection document at 40 bits or fewer is frus1955-57v09/d190 against frus1955-57v09/d185 (32 bits), which is the preceding half-yearly USIA report cited by d190 as Document 185, a successor in the same series and not a reprint. I did not scan the whole scope for duplicates.

**Which documents in the overview were reached through a vector operation and no full-text query.** frus1952-54v13p1/d116 and frus1917-72PubDipv07/d32 (neighbours of d73, V1); frus1917-72PubDipv08/d34 (map cluster, V4). None of the three appeared in any full-text result list that I displayed before the vector step (the Family A census files did contain them, but I did not read those lists first). Every other document in the overview was reached by full-text queries, headers or the Agency's office names.

All vector neighbours and map placements are suggestions; each one used was read before being used. Recall below 1 means this does not show that no further relevant neighbour exists.

## 9. TRACE TABLE (overview -> memo)

| Item in the overview | Memo line |
|---|---|
| "105 volumes"; "ninety-nine East Asia and Pacific volumes"; six information volumes | M3 (scope105.txt, eap_vols.txt) |
| "roughly 58,000 documents" | M3 (58,244) |
| "about thirty documents" | Section 5; collection (30 documents; build_coll.py) |
| "about one document in forty-four" | M4 (1,329 of 58,244 = 1 in 43.8) |
| "about one in thirteen for documents of the 1960s" | M5 (684 of 8,725 = 1 in 12.8) |
| "roughly fifteen hundred candidate documents, about thirteen hundred passed" | M4 (1,538; 1,329) |
| "thirteen ... ten ... seven"; "five from the Johnson Library (three ... National Security File)"; "one from ... Kennedy"; "one from ... Nixon" | M9 |
| Lot 63 D 351 (entry A1 1586E; NAID 2839192; 1947 to 1979; 26 linear feet; restricted in part) | M11 |
| Lot 69 D 260 (UD-UP 174 to 177; NAID 27022536; 1961 to 1969; 11 linear feet; unrestricted) | M11 |
| Johnson National Security File NAID 567979 | M11 |
| Record Group 306 entry numbers UD WW 257, UD WW 193, A1-42, P-104, P-142; Office of Policy and Plans NAID 1257679; Executive Secretariat series as leads | M11 |
| "several hundred times" (Nixon NSC files 782; Johnson National Security Files 671) | M10 |
| Lot 93 D 82 (NAID 2225592; 1962 to 1972; closed in full); lot 53 D 413 (NAID 2127212; 1951 to 1954; restricted in part) | M11, M10 |
| Footnotes of the thirty point at decimal class (1955), lot 71 D 273, two Johnson files | M10 (7 rows) |
| "553 volumes"; "552 of 553"; "a nonsense string appears in none"; no document for "soft power" | M1, M2 |
| polls: "one Japanese poll in 1965; USIA surveys of one province in 1964, six countries in 1969, eight in 1970" | Q-lines for frus1964-68v29p2/d46, frus1917-72PubDipv08/d34 and d94 (the documents state the counts of countries) |
| "fifty-two to thirty-eight percent in five months" | the Q line for frus1964-68v29p2/d46 ("since last December", dated May 1965) |
| films audience and library attendance in Finding 2 | Section 6, non-quoted figures |
| "from 1901 to 1980" (99 volumes) | eap_vols.txt, manifest titles |
| "three of the thirty reached first through vectors" | Section 8 (two neighbours, one map) |
{{TRACE_QUOTES}}

## 10. Flags

- Thin: pre-war (three documents; M8); Korea, the Philippines, Australia (passing only); decade 1970s (one volume carries half of the numerator).
- The index is the whole series, so none of the thinness reflects a partial library.
- The overview's figures about audiences (three USIA surveys and one poll quoted by the ambassador) come from documents the editors chose to print.
- Nothing in the summaries or notes columns (summary_text, note_text) was read or quoted.
- No claim in the overview says an earlier pass was wrong or silent, so no before-and-after table is owed.

ELIDED: see the last line of queries.log.
