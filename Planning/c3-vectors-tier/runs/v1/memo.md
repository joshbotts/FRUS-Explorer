# Scope memo: how have U.S. policymakers' thinking about Cuba's impact on national security and prosperity changed since the 1870s?

Run v1, 2026-10-27. Index copy: frus-copy-2026-10-25.db, opened read-only. Every count below is conditional on this index and on its **553 volumes** (the full series is 553; this copy holds all of them). Bundled data: FRUS Explorer build 1.0 (1776). `DB` below means the index copy. The offline NARA harvest ([HARVEST]) was not given to this run: no count here comes from it and no harvest figure is claimed.

COVERAGE (first command of the run, and again inside stats1.py): `SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;` returned `553|321749|1103|8481`. Read-only proof: `BEGIN; CREATE TABLE zz(x); ROLLBACK;` failed with "attempt to write a readonly database".

Files in the run directory: scripts (`h.py scan.py scan2.py stats1-6.py vec*.py arch*.py quotes.py build_collection.py check_overview.py`), outputs (`scan_*.csv scope.csv stats*.out vec_*.out quotes.json check_overview.out`), `docs/` (the 65 documents retrieved whole). Surfaces used: the index (counting surface = the FTS5 index, which stores porter stems and flattened text, case-insensitive, NOT the TEI); the bundled JSON for every archival and subject-reference step; the vector artifacts. The TEI XML was not opened: spelling-variant, hyphenation and apparatus/footnote splits that need the TEI were not done and every count below is therefore an index count (see section 8).

## 1. Scope

- **S1 Volumes.** All 553 indexed volumes. Excluded by volume: `frus1951-54IranEd2` and `frus1969-76ve15p2Ed2` (second editions whose first editions are indexed; `frus1977-80v09Ed2` has no first edition and is kept, but it has no Cuba hit that I read). The 1961–63 microfiche supplements (`frus1961-63v10-12mSupp`, `frus1958-60v05mSupp`) are kept, so the 1960s counts include them (the supplement holds 560 of the 3,147 hits of the 1960s, N01).
- **S2 Date span.** 1870 to 1988, periodised on `document_dates.date_iso` (the index's per-document date, the day of the document's own date line), NOT on the volume's series year. Question says "since the 1870s": the 1860s are excluded from every table (306 Cuba hits dated 1860–1869 appeared in the first exploratory decade query and were not used).
- **S3 Inclusion rule (two tiers).** Tier 1 "names Cuba": `frus_documents MATCH 'cuba OR cuban'` (porter stems: also matches Cubans), `is_front_matter=0 AND is_editorial_note=0`, volume not an Ed2, dated 1870–1989: **12,256 documents** (N01). Tier 2 "Cuba-substantial": at least 5 case-sensitive mentions of `\bCub(a|an|ans)\b` in `body_text`: **4,107 documents** (`scope.csv`; scan.py writes the counts and mk_scope.py filters them). Tier 3 "the argument rests on": 22 documents, 31 excerpts (collection).
- **S4 How the scope was found.** (1) Controls and per-decade rates (N01, C1). (2) Per-volume counts to see which volumes concentrate the hits (output not kept as a file; the command is in queries.log). (3) `scan.py` over all tier-1 documents, writing for each the number of mentions and the number of mention-centred 500-character windows holding security vocabulary and prosperity vocabulary (the regexes are in scan.py; SEC includes revolution/insurrection/troops, PRO includes claims/property). (4) `top.py` ranked documents per era by windows holding both; I read the top of each era in windows (`kwic.py`) and whole documents when a window looked decisive. (5) Candidate documents were screened against the editors' own framing, e.g. the volume titles of the Cuba volumes (manifest.json), and against known Cuba volumes (`frus1958-60v06`, `frus1961-63v10`, `v11`, `frus1964-68v32`, `frus1977-80v23`). (6) Vector neighbours were used as a second finder (section 5).
- **S5 Reading rule I applied for the question's own terms.** Because the question's words are not the corpus's (C2, N04, N05), I read "national security" before 1947 as defence/strategic position/rival powers/menace/bases, and "prosperity" as commerce, sugar, investment and tariff (plus Cuban economic stability as a US interest). This is a decision the historian is asked to confirm (overview, Decisions).

## 2. Controls (SCOPING)

- **C1 Positive and negative control, same pass** (stats1.py): `SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH 'department AND state'` = 183,557 documents; and `SELECT COUNT(DISTINCT d.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH 'department AND state' AND d.is_front_matter=0 AND d.is_editorial_note=0` = **553 of 553** volumes. Negative: `... MATCH 'zzz_impossible_zzz'` = **0**. The scan therefore works and an absence is meaningful (used for the 1990s statement in N01 and for the "no Cuba after 1988" claim: 177 documents dated 1990–1999, 0 Cuba matches, see N01).
- **C2 False-friend test** for the two terms the question supplied (stats2.py, stats3.py; N04 below): both terms match a control country's rate, so neither measures Cuba; I stopped using them as measures.

## 3. Measurements

Exclusions in every query below: `is_front_matter=0 AND is_editorial_note=0 AND volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')` unless stated.

### N01 Cuba documents per decade (counting surface: index, FTS5 stems)

Denominator M (all dated non-apparatus documents of the decade): `SELECT substr(dd.date_iso,1,3)||'0s', COUNT(*) FROM document_cache d JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN (...) GROUP BY 1;`
Numerator N: `SELECT substr(dd.date_iso,1,3)||'0s', d.volume_id, d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE frus_documents MATCH 'cuba OR cuban' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN (...)` then counted per decade (stats1.py, output stats1.out).

| decade | M dated non-apparatus docs | N Cuba hits | N of M per 1,000 | top volume, its share of N |
|---|---|---|---|---|
| 1870s | 5,821 | 363 | 62.4 | frus1874: 101 of 363 (0.28) |
| 1880s | 6,484 | 294 | 45.3 | frus1885: 58 of 294 (0.20) |
| 1890s | 9,845 | 592 | 60.1 | frus1898: 234 of 592 (0.40) |
| 1900s | 10,261 | 367 | 35.8 | frus1902: 93 of 367 (0.25) |
| 1910s | 30,842 | 875 | 28.4 | frus1917: 147 of 875 (0.17) |
| 1920s | 20,374 | 712 | 34.9 | frus1921v01: 137 of 712 (0.19) |
| 1930s | 40,073 | 1,094 | 27.3 | frus1933v05: 344 of 1,094 (0.31) |
| 1940s | 75,872 | 1,316 | 17.3 | frus1944v07: 171 of 1,316 (0.13) |
| 1950s | 42,801 | 982 | 22.9 | frus1958-60v06: 354 of 982 (0.36) |
| 1960s | 27,654 | 3,147 | 113.8 | frus1961-63v10-12mSupp: 560 of 3,147 (0.18) |
| 1970s | 22,258 | 1,887 | 84.8 | frus1969-76ve11p1: 175 of 1,887 (0.09) |
| 1980s | 6,038 | 627 | 103.8 | frus1981-88v03: 72 of 627 (0.11) |

Total 1870s–1980s: **12,256 of 298,323** dated non-apparatus documents (4.1 per cent; about one in 24). 1990s: 177 dated documents, 0 Cuba hits (decade query without the Ed2 filter in the first exploration; the same 0 in stats1.py's range check). Thin-ness flags: the decade rates are index counts; the 1870s rate rests on small M (5,821) and 28 per cent in one volume; the 1960s rate includes the microfiche supplements; a small decade's rate can be one negotiation (the 1898 volume is 40 per cent of the 1890s).

### N02 Literal share of the Cuba family (obligation (a))

`stats1.py`: the sorted `(volume_id, document_id)` hit list of the tier-1 set 1870s–1980s has 12,256 rows; 40 evenly spaced rows (every 306.4th; list in `sample40_cuba.txt`); regex over `header||dateline||source_note||body_text`, whitespace collapsed, case-insensitive. **STRICT** `\bCub(a|an)\b`: **39 of 40**. **TOLERANT** `\bCub(a|an|ans|as)?\b`: **40 of 40**; misses: none. Tolerant 1.000 tests the stemmer, not the referent; the referent (the island) is tested separately by section 4 reading: all 22 quoted documents were read at the sentence.

### N03 Cuba-substantial documents by era band (scope.csv)

Rows of scan_*.csv with `date>=1870` and `ncuba>=5` (ncuba = case-sensitive `\bCub(a|an|ans)\b` count in body_text; a lower bound, since CUBA in capitals is not counted). Bands: 1870–1899 **309**; 1900–1939 **731**; 1940–1957 **616**; 1958–1989 **2,451**; total **4,107**.

### N04 False-friend tests (stats2.py, stats3.py, stats2.out, stats3.out)

SQL: `SELECT COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN (...) AND dd.date_iso>=? AND dd.date_iso<?` with `?` = `(cuba OR cuban) AND "national security"` etc.

| term | band | Cuba documents containing it | control country (Mexico) | all dated non-apparatus documents |
|---|---|---|---|---|
| "national security" | 1870–1946 | 10 of 5,318 (0.002) | 26 of 10,083 (0.003) | 375 of 178,404 (0.002) |
| "national security" | 1947–1989 | 2,588 of 6,938 (0.373) | 947 of 3,430 (0.276) | 28,961 of 119,919 (0.242) |
| prosper (stem: prosperity, prosperous) | 1870–1946 | 204 of 5,318 (0.038) | 344 of 10,083 (0.034) | 2,598 of 178,404 (0.015) |
| prosper (stem) | 1947–1989 | 194 of 6,938 (0.028) | 124 of 3,430 (0.036) | 1,654 of 119,919 (0.014) |

Literal share (obligation (a)), evenly spaced sample of 40 from the sorted hit list (stats3.py): "national security", Cuba, 1947–1989 (list of 2,588): STRICT 40 of 40, TOLERANT (`national[\s,\-()\.]+securit(y|ies)`) 40 of 40; **NON-INSTITUTIONAL** (not followed by Council, Act, Adviser, Affairs, Action, Study, Decision, Agency, Files, Staff, Archive, Directive, ... ) **10 of 40**; Mexico, 1947–1989 (list of 947): 40 of 40, 40 of 40, non-institutional **14 of 40**. Reading: the phrase is mostly the name of the National Security Council; Cuba's non-institutional use (10 of 40) is not above the control (14 of 40) so it measures the corpus. The pre-1947 list has 10 rows, so the "sample of 40" is the whole list: 9 of 10 literal (the exception is `frus1938v02/d156`); the 60-character contexts (inline command, queries.log) are: a Danish code (1887), an act (1918 twice), the Paris conference (1919 twice), a Cuban declaration (`frus1937v01/d741`), Colombia (1939), a Treasury/ambassador reimbursement (1943) and the Central Intelligence Group (1946); I read the contexts only, not the documents. "prosperity", Cuba 1870–1946 (list of 204): STRICT `prosperity` 30 of 40, TOLERANT `prosper(ity|ous|ing|ed|s)?` 39 of 40; Cuba 1947–1989 (194): 25 of 40, 40 of 40; Mexico 1870–1946 (344): 33 of 40, 39 of 40 (all tolerant shares are above 0.80). Cuba's rate for the stem (0.038) is within a point of the control's (0.034): the word marks the genre of hemisphere correspondence, not a Cuban concern, so I stopped using it as a measure.

### N05 Vocabulary windows by era (my construction; not a measure of thought)

scan.py (wide) and scan2.py (narrow). A window is the 250 characters either side of a case-sensitive Cuba/Cuban/Cubans mention. WIDE security SEC: `secur*|strategic*|naval|coaling|defen[cs]*|menace*|annex*|cession|Monroe|European power*|Gulf of Mexico|Caribbean|Panama|isthmian|canal|missile*|Soviet*|communis*|Marxis*|subver*|guerrill*|military|troops|intervention|invasion|base|bases|filibuster*|insurrection|revolution*`; WIDE prosperity PRO: `sugar*|commerc*|trade|tariff*|reciproc*|duties|export*|import*|investment*|capital|market*|prosper*|embargo*|quota*|tobacco|property|properties|claims|economic*|exchange|loan*|customs`. NARROW (scan2.py): SEC2 `secur*|strategic*|defen[cs]*|menace*|Soviet*|missile*|naval|Monroe|European power*`; PRO2 `sugar*|commerc*|trade|tariff*|reciproc*|export*|import*|investment*|market*|prosper*|quota*|tobacco`. Counting unit: the Cuba-substantial document (N03), "has a window with ...".

| band | M | WIDE security | WIDE prosperity | NARROW security | NARROW prosperity |
|---|---|---|---|---|---|
| 1870–1899 | 309 | 200 of 309 (0.647) | 228 of 309 (0.738) | 94 of 309 (0.304) | 171 of 309 (0.553) |
| 1900–1939 | 731 | 344 of 731 (0.471) | 508 of 731 (0.695) | 160 of 731 (0.219) | 360 of 731 (0.492) |
| 1940–1957 | 616 | 320 of 616 (0.519) | 508 of 616 (0.825) | 203 of 616 (0.330) | 434 of 616 (0.705) |
| 1958–1989 | 2,451 | 2,273 of 2,451 (0.927) | 1,565 of 2,451 (0.639) | 1,918 of 2,451 (0.783) | 1,237 of 2,451 (0.505) |

Wide documents with both in one window: 98 of 309; 189 of 731; 188 of 616; 1,230 of 2,451. Caveats: the 1958–1989 band is dominated by Cuba-focused volumes and National Security Council papers, whose vocabulary is security vocabulary anyway; the 1870–1899 wide security share is inflated by "insurrection" and "revolution" in the wide list (the narrow list drops them); the direction (security share up after 1958, prosperity share down from 1940–57 to 1958–89) holds in both lists.

### N06 Documents the Cuba match misses (stats6.py, stats6.out)

Same join/exclusions as N04. `cuba OR cuban`: 1,249 (1870–1899), 3,048 (1900–1939), 1,833 (1940–1957), 6,126 (1958–1989) [these four sum to 12,256]. `(havana OR habana) NOT (cuba OR cuban)`: **240 of 1,489**; **352 of 3,400**; **455 of 2,288**; **90 of 6,216** (documents matching Cuba/Cuban/Havana/Habana). Total Havana-only: **1,137**. `(antilles OR "isle of pines") NOT (cuba OR cuban)`: 43, 31, 62, 9. These were not read; the Cuba counts are lower bounds by that margin.

### N07 Map (semantic-map.bin) share (vec_map_share.py, vec_map_share.out)

For each era band, among all dated non-apparatus documents that have a vector row (the baseline) and among the tier-1 Cuba documents: unclustered (`0xFFFF`) and in cluster 42 (terms castro, somoza, cuban, cuba).

| band | baseline N | baseline unclustered | baseline in cluster 42 | Cuba documents N | unclustered | in cluster 42 | Cuba documents without a vector row |
|---|---|---|---|---|---|---|---|
| 1870–1899 | 21,977 | 5,281 (24.0%) | 0 | 1,240 | 300 (24.2%) | 0 of 1,240 | 9 |
| 1900–1939 | 99,210 | 26,651 (26.9%) | 15 | 2,996 | 1,200 (40.1%) | 3 of 2,996 | 52 |
| 1940–1957 | 110,581 | 31,378 (28.4%) | 1,499 (1.4%) | 1,803 | 482 (26.7%) | 229 of 1,803 (12.7%) | 30 |
| 1958–1989 | 61,751 | 17,742 (28.7%) | 5,604 (9.1%) | 6,124 | 1,235 (20.2%) | 2,982 of 6,124 (48.7%) | 2 |

Reading: the map's Cuba cluster begins with the Revolution; the interwar Cuba documents are unclustered at 40.1 per cent against a 26.9 per cent era-matched baseline, so the map is not a tool for following the question across 1958 (and "document ids" such as ch83 have no vector row at all).

### N08 Archival channels: see section 6 (counts A01–A12).

### N09 Reading accounting: see section 7.

## 4. Quotations

Every quotation is retrieved by `SELECT body_text FROM document_cache WHERE volume_id = :v AND document_id = :d AND is_front_matter = 0 AND is_editorial_note = 0;` (quotes.py searches the returned text for the start phrase, and the end phrase when a span is given; the exact-substring test passed for all 32; none of the 32 spans contains a newline or a double space). The raw text is kept in `docs/<volume>__<doc>.txt` and the extracted strings in `quotes.json`. The passages are as retrieved, including the index's spellings ("beneficient"). Q27 is held in reserve and not used (its source has a transcription run-together, "flyingfrom").

| id | volume_id/document_id | date | passage |
|---|---|---|---|
| Q01 | frus1874/d552 | 1874-02-06 | It is almost contiguous to the United States. |
| Q02 | frus1874/d552 | 1874-02-06 | it would afford a large and lucrative market for the productions of this country |
| Q03 | frus1874/d552 | 1874-02-06 | In short, the state of Cuba is the one great cause of perpetual solicitude in the foreign relations of the United States. |
| Q04 | frus1898/d498 | 1897-10-05 | our great commerce with Cuba has thus been practically destroyed |
| Q05 | frus1898/ch83 | 1898-04-12 | The present condition of affairs in Cuba is a constant menace to our peace, and entails upon this Government an enormous expense. |
| Q06 | frus1898/ch83 | 1898-04-12 | The right to intervene may be justified by the very serious injury to the commerce, trade, and business of our people, and by the wanton destruction of property and devastation of the island. |
| Q07 | frus1902/d273 | 1902-03-27 | nor in any manner authorize or permit any foreign power or powers to obtain, by colonization or for military or naval purposes or otherwise, lodgment in or control over any portion of said island |
| Q30 | frus1902/d273 | 1902-03-27 | wise and beneficient legislation aiming to stimulate the commerce between the two countries |
| Q08 | frus1918/d333 | 1917-08-29 | Cuba’s greatest aid to the United States in the prosecution of the war would be economic rather than military |
| Q31 | frus1933v05/d241 | 1933-05-01 | must be determined primarily by its rights and obligations as set forth in the first five articles of the treaty |
| Q09 | frus1934v05/d170 | 1934-05-29 | the stipulations of that agreement with regard to the naval station of Guantánamo shall continue in effect |
| Q32 | frus1934v05/d154 | 1934-08-24 | in continuation of the policy adopted in the Convention of Commercial Reciprocity of 1902 |
| Q10 | frus1941v07/d134 | 1941-01-08 | our interest in the Cuban situation for economic and defense reasons is such |
| Q11 | frus1948v09/d420 | 1948-07-29 | we could, by manipulation of tariff or quota affecting sugar, plunge the entire island into poverty |
| Q12 | frus1950v02/d440 | 1951-01-11 | Cuba, lying 90 miles to the south of Key West, Florida, is of great strategic importance to the US both because of its location with respect to the Panama Canal and the sea lanes of the Caribbean and because in two wars it has been the major and most readily-expandible source of sugar |
| Q25 | frus1952-54v04/d331 | 1952-07-15 | It is the policy, and in the best interest, of the United States to assist Cuba to maintain its economic and political stability |
| Q13 | frus1958-60v06/d362 | 1959-09-18 | our retaliatory instruments, such as GATT and the sugar quota, are likely to be used |
| Q15 | frus1958-60v06/d532 | 1960-06-22 | Amendment of the preferential sugar quota act to provide for a reduction from 20 to 25 per cent of Cuba’s quota. |
| Q28 | frus1958-60v06/d535 | 1960-06-27 | it would be impossible to carry on friendly relations with the Castro Government in Cuba and that, as a consequence, we should devise means to help bring about his overthrow |
| Q14 | frus1958-60v06/d567 | 1960-07-26 | Since we have crossed one Rubicon with our sugar and oil actions |
| Q18 | frus1961-63v11/d18 | 1962-10-16 | this kind of a base is intolerable and not acceptable |
| Q16 | frus1961-63v11/d21 | 1962-10-16 | Geography doesn’t mean that much. |
| Q17 | frus1961-63v11/d21 | 1962-10-16 | I don’t think there is a military problem here. |
| Q26 | frus1961-63v11/d21 | 1962-10-16 | this is a domestic, political problem |
| Q27 (reserve) | frus1961-63v11/d21 | 1962-10-16 | it doesn’t make any difference if you get blown up by an ICBM flyingfrom the Soviet Union or one that was ninety miles away. |
| Q19 | frus1969-76ve10/d205 | 1969-07-02 | We have a vital interest: 1. In preventing the introduction into Cuba of strategic weapons. |
| Q20 | frus1969-76ve10/d205 | 1969-07-02 | to promote meanwhile the realization of subsidiary and lesser U.S. interests in improved relations with Cuba |
| Q21 | frus1977-80v23/d18 | 1977-07-06 | to gain access to U.S. markets and technology to stimulate its economy |
| Q29 | frus1977-80v23/d18 | 1977-07-06 | U.S. Objectives are to get Cuba to demonstrate: —restraint in Puerto Rico, Latin America, and Africa |
| Q22 | frus1977-80v01/d129 | 1979-10-01 | It presents no direct threat to us. |
| Q23 | frus1977-80v01/d129 | 1979-10-01 | In contrast to the 1962 crisis, no nuclear threat to the United States is involved. |
| Q24 | frus1981-88v03/d10 | 1981-01-30 | Cuba has been a sore spot in the US-Soviet relationship since the 1962 missile crisis |

Speaker and author attributions used in the overview, each read in the retrieved text: Q01–Q03 are Fish's instruction to Cushing at Madrid (d552, header "No. 550. Mr. Fish to Mr. Cushing", Department of State, Washington, February 6, 1874); Q04 is Woodford's report of 5 October 1897 of a conversation with the German ambassador, Herr von Radowitz (first lines of d498); Q05–Q06 are in the President's message (d ch83); Q07 and Q30 are in the message signed "Theodore Roosevelt", 27 March 1902 (end of d273); Q08 is the Department's side in a memorandum of a conversation with the Cuban Minister (d333); Q13 is Rubottom speaking (d362); Q15 is a measure suggested by Secretary Anderson and Under Secretary Dillon at the NSC meeting (d532); Q14 is the Secretary of Defense to the Secretary of State (d567); Q18 is spoken under the label "Rusk:" (the last speaker label before the passage in d18, 11:50 a.m. meeting); Q16 under "JFK:" and Q17, Q26 under "McNamara:" in d21 (6:30–7:55 p.m.). Q12 is a Department of State Policy Statement of 11 January 1951; Q11 an unsigned Department of State memorandum of 29 July 1948.

**Overview–memo check (check_overview.py, output check_overview.out):** the overview contains 37 quotation-marked strings; the script finds each as a substring (whitespace collapsed) of the `body_text` of a collection document, and each of them except the two search terms ("Department of State", "national security", which are search terms and not quotations) lies inside one of the passages above. All 22 URLs in the overview are collection documents and all 22 collection documents are cited. All 31 excerpts of the collection are exact substrings of their document's `body_text`.

## 5. VECTORS

Files: `semantic-vectors-index.json`, `semantic-vectors-binary.bin`, `semantic-map.bin`, `semantic-map-index.json` from the app bundle, and one Tier-2 shard (`SemanticVectors/frus1898.vec`) plus the folder's `.generation` file. No Tier-2 shard was used for scoring. No embedder was available, so no free-text query was run.

- **V0 Digest and identity check (vec.py).** `provenanceDigest` in the index = digest at byte 20 of the binary = digest at byte 20 of `semantic-map.bin` = digest at byte 16 of `frus1898.vec` = `.generation`: `89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101` (model embeddinggemma-2-Q8_0; index `generated` 2026-10-15; `harvestGenerated` 2026-10-15T06:55:14). One shard of the 553 was compared, not all. Identity came only from the index's id segments (`decode_segments`, round trip: decoded length = `n` for 553 of 553 volumes; 314,616 rows decoded, 0 rows left without an id). Document `frus1898/ch83` (the war message) is not a vector row.
- **V1 Baselines (vec_baseline.py, vec_baseline.out).** Random pairs at this digest, `random.Random(1877)`, 20,000 pairs: mean **167.1**, sd **14.8**, 1st percentile 132, minimum 95 of 512. k-th-neighbour distribution over 100 random documents (`random.Random(2026)`): nearest neighbour median **82** (quartiles 74 and 92); 25th neighbour median **106** (quartiles 100 and 111). A neighbour at 60 to 80 is therefore well inside the tail for a nearest neighbour but ordinary for one of the first ten; the cohesion of a set is read against 167, an individual neighbour against 82 and 106.
- **V2 Nearest neighbours of a document (Hamming over the 512 sign bits; vec_ops.py, vec_ops_nn.out).** Anchors and results (ten nearest each, the anchor excluded):
  - `frus1874/d552` (Fish to Cushing, 1874): nearest `frus1898/d490` at 61, then `frus1898/d503` 68, `d531` 71, `d495` 73, `d526` 77, `frus1902/d313` 77, `frus1898/d544` 78, `d492` 80, `d498` 80, `frus1897/d581` 81. Eight of ten are 1897–98 despatches of the Woodford–Sherman correspondence; all contain Cuba. Found: the 1874 instruction's nearest documents are the despatches of the war's approach, 23 years later.
  - `frus1950v02/d440` (1951 policy statement): `frus1948v09/d420` 62, `frus1969-76ve10/d205` 64, `frus1964-68v32/d300` 69, `frus1969-76ve11p1/d278` 69, `frus1946v11/d658` 73, `frus1952-54v04/d351` 73, `frus1958-60v06/d423` 73, `frus1961-63v10-12mSupp/d729` 74, `frus1958-60v06/d364` 76, `frus1958-60v06/d527` 77. Found: its neighbours are statements of "US policy toward Cuba" across 1946 to 1974.
  - `frus1969-76ve10/d205` (NSSM 32 study): `frus1961-63v10-12mSupp/d729` 52, `d670` 54, `frus1958-60v06/d620` 56, `d616` 57, `frus1961-63v10/d202` 60, `frus1969-76ve11p1/d278` 61, `frus1961-63v10-12mSupp/d543` 63, `frus1950v02/d440` 64, `d665` 64, `frus1958-60v06/d475` 65.
  - `frus1961-63v11/d21`: `frus1961-63v11/d18` 43 (same day's earlier transcript), then `frus1964-68v07/d125` 84 (no Cuba), `frus1961-63v11/d43` 86, `frus1964-68v03/d87` 86 (no Cuba), and others at 87–88.
  - `frus1902/d273`: `frus1904/d207` 70, `frus1902/d313` 87, `frus1903/d333` 92, `frus1922v01/d830` 94, `frus1905/d279` 97, `frus1933v05/d241` 98, and others at 101–103.
  - `frus1941v07/d134`: `frus1941v07/d137` 60, `frus1948v09/d420` 69, `frus1941v07/d141` 70, `frus1958-60v06/d328` 78, and others at 80–87.
  - `frus1977-80v23/d18`: `frus1969-76ve11p1/d299` 69, `frus1958-60v06/d364` 71, `frus1948v09/d420` 77, ... to 82.
  - `frus1977-80v01/d129` (Carter address): `frus1977-80v01/d87` 77, `frus1961-63v06/d83` 79, `frus1961-63v11/d266` 81, ... to 86; two of the ten (`frus1969-76v01/d118` and `frus1977-80v01/d111`) do not name Cuba, so the neighbour set here is partly a genre match (presidential addresses and briefings).
  Each distance is read against V1: the first (nearest) neighbour of each of the eight anchors is at 43 to 77, at or below the nearest-neighbour median of 82, so none of the eight is an isolate; the later entries of the lists for `frus1902/d273`, `frus1941v07/d134`, `frus1961-63v11/d21` and `frus1977-80v01/d129` lie at 84 to 103, which is ordinary for the 5th to 25th neighbour (25th-neighbour median 106) and is not evidence of a link. Neighbours are suggestions to read, not evidence of a relationship; I read every neighbour that I cite. Recall of the funnel is 0.902 for this generation (index `retrieval`), so absence of a neighbour proves nothing.
- **V3 Volume similarity from centroids (cosine of int8 centroid times scale over the 553 volume centroids; vec_ops2.py, vec_ops_2.out).** `frus1874` → `frus1875v02` 0.993, `frus1876` 0.992, `frus1875v01` 0.992; `frus1898` → `frus1899` 0.983, `frus1897` 0.982, `frus1896` 0.977; `frus1941v07` → `frus1942v06` 0.986, `frus1941v06` 0.985; `frus1958-60v06` → `frus1961-63v10-12mSupp` 0.973, `frus1961-63v10` 0.971, `frus1964-68v32` 0.965; `frus1961-63v11` → the supplement 0.988, `frus1961-63v10` 0.977; `frus1977-80v23` → `frus1969-76ve11p1` 0.981, `frus1977-80v24` 0.972, `frus1969-76ve10` 0.972. Baseline: 3,000 random volume pairs (seed 1877): mean 0.904, sd 0.032. Found: Cuba-bearing volumes sit beside the adjacent annual or sister volumes, not beside each other across eras, so centroids do not carry the Cuba question across time.
- **V4 The map (semantic-map.bin, semantic-map-index.json, 140 clusters, same digest).** Cluster of selected documents: `frus1958-60v06/d535`, `frus1961-63v11/d21`, `frus1969-76ve10/d205`, `frus1977-80v23/d18`, `frus1977-80v01/d129`, `frus1981-88v03/d10` are all in cluster 42 (castro, somoza, cuban, cuba); `frus1902/d273` is in cluster 72 (sanguily, inclosure, azcuy, inclose); `frus1874/d552`, `frus1898/d498`, `frus1941v07/d134`, `frus1948v09/d420`, `frus1950v02/d440` are unclustered. Era shares: N07 (baseline: the era-matched unclustered share of all dated non-apparatus documents).
- **V5 Near-duplicates (vec_dup.py).** Pairs: `frus1881/d405` and `frus1894app2/d394` (Blaine to Comly): Hamming **4** (a reprint; the second sits in an appendix volume, so tier-1 counts include some reprints twice); `frus1961-63v06/d74` and `frus1961-63v11/d155` (Kennedy to Khrushchev, 6 November 1962): **23**; `frus1961-63v11/d18` and `d21` (two meetings, same day): **43**. For the 13 selected documents the nearest neighbour is below 20 in none; the nearest are 32 (`frus1898/d498`, with `d497`), 43 (`frus1961-63v11/d21`) and 52 (`frus1969-76ve10/d205`).
- **V6 Semantic join into the database (vec_join.py, vec_join.out).** The ten nearest neighbours of `frus1950v02/d440` and `frus1874/d552` joined to `document_dates`, `document_sources` and `external_citations` on both keys: for `d440` the neighbours are dated 1946 to 1974, came from the Department's decimal file (`frus1948v09/d420`, `frus1946v11/d658`, `frus1958-60v06/d364`, `d527`), a central foreign policy file (`frus1969-76ve11p1/d278`), a lot file (`frus1952-54v04/d351`, lot 70D467) and the Nixon, Johnson and Eisenhower libraries; for `d552` the ten are all 1896–1902 despatches with no recorded source (consistent with N10 below).
- **V7 Documents in the overview reached through a vector operation and through no full-text query: none.** Every neighbour cited contains Cuba (V2) and so is also in the tier-1 set. Three overview documents were also surfaced by a vector operation: `frus1948v09/d420` (nearest to the 1951 statement; I had already met it in the text scan's 1940–1957 ranking), `frus1898/d498` (ninth-nearest to the 1874 instruction; already in the text scan's 1880–1899 ranking), `frus1969-76ve10/d205` (second-nearest to the 1951 statement; already in the 1964–1976 ranking). The vector work supplied two leads that I then read (the 1874–1898 continuity; the 1951–1969 continuity) and the map finding of N07.

## 6. Archival scope (two channels, labelled, never summed)

Volume set: the tier-2 set (4,107 documents, S3). All counts from the index unless marked [JSON]. [HARVEST]: not available to this run.

**Channel one, "came-from" (`document_sources`, one row per document).** SQL (arch1.py): `SELECT s.date, ds.citation_era, ds.repository, ds.record_group, ds.lot_file_norm, ds.series_name FROM sc s JOIN document_sources ds ON ds.volume_id=s.volume_id AND ds.document_id=s.document_id` with `sc` = scope.csv loaded into a TEMP table.

- **A01 Coverage of the channel by band:** 1870–1899: **1 of 309** documents has a source row (citation_era 'unrecognized'); 1900–1939: **636 of 731**; 1940–1957: **616 of 616**; 1958–1989: **2,451 of 2,451**.
- **A02 1900–1939:** `decimal`/Department of State/RG 59: 613; `published`: 18; `decimal`/RG 256: 3; other: 2. **1940–1957:** `decimal`/RG 59: 574; `lot_file`/RG 59: 31; `named_series`: 6; `structured`: Eisenhower Library 3, CIA 1; other 1. **1958–1989** top: `decimal`/RG 59: 436; `structured` Kennedy Library: 355; `lot_file`/RG 59: 309; `structured` Carter Library: 259; Central Intelligence Agency: 207; `cfpf`/RG 59: 158; Nixon Presidential Materials: 130; Eisenhower Library: 89.
- **A03 Decimal classes, scope documents with citation_era 'decimal' and date before 1958 (arch2.py):** 837.51: 171 (1917-08-01 to 1949-11-01); 837.61351: 155 (1917-09-27 to 1949-09-22); 837.00: 151 (1912-05-24 to 1954-07-26); 611.3731: 73 (1911-01-06 to 1947-12-31); 837.24: 30; 811.34537: 28; 810.20: 18; no class: 27. [JSON] `decimal-class-labels.json` gates glossing by the document's own date: `coverage.glossableYears` = 1910–1949, 1950–1959, 1960–1963; country 37 = Cuba in all three schedules; under the 1910–1949 schedule, class 8 = "Internal Affairs of States", subject 00 = "Political affairs", 51 = "Financial conditions", 61351 = "Cane". I glossed 837.00, 837.51, 837.61351 only for documents dated 1910–1949 and made no gloss of 837.00 in the 1950–54 documents (post-renumbering), nor of 611.3731 or 811.34537.
- **A04 Structured collections (all bands):** Kennedy Library National Security Files 225 and "NSF" 81 (two spellings of one collection, 306); Carter Library National Security Affairs 215 (and 29 under National Security Council); Central Intelligence Agency 208; Nixon Presidential Materials NSC Files 118; Johnson Library National Security File 69; Eisenhower Library Whitman File 66 and Project "Clean Up" Records 11; National Archives OASD (C) A Files, FRC 71 A 2896: 40; Ford Library National Security Adviser 31.
- **A05 Lot files (came-from, date from 1940), counts of documents:** 65D438 28, 62D24 14, 62D418 13, 66D501 12, 70D149 12, 64D199 11, 65D330 11, 67D548 11, 74D272 9, 77D163 9.
- **A06 Lots resolved [JSON] (arch3.py, central-files-index.json `lotFiles`, series-facts-index.json `byNaId`; access = `as` through `statuses`; creator = `c` through `headings`):** 65D438 "Records Relating to the Cuban Missile Crisis", RG 59, entry A1 3053, NAID 27022950, creator Executive Secretariat, inclusive 1962–1963, 6 linear feet 2 inches, **Restricted - Partly**. 62D24 "Subject Files", RG 59, A1 3148, NAID 2363836, creator ARA Office of the Special Assistant on Communism, inclusive 1958–1961 (coverage 1956–1961), **Restricted - Partly**. 62D418 "Subject Files", A1 3147, NAID 2068466, creator ARA Assistant Secretary, 1959–1962, Restricted - Partly. 66D501 "Files Pertaining to Operation Mongoose", entry UD-UP 293-B, NAID 648748, creator Office of the Coordinator of Cuban Affairs, inclusive 1963–1965 (coverage 1960–1999), **Unrestricted**. 64D199 and 65D330 both resolve to "The Secretary's and the Under Secretary's Memorandums of Conversation", A1 1566, NAID 602231 (two lots converging on one series), Executive Secretariat, 1953–1964, **Unrestricted**. 66D204 "Presidential and Secretary of State Correspondence with Foreign Heads of State", A1 1590, NAID 2538452, 1953–1964, Restricted - Possibly. The creator headings were checked against the titles (NARA's creator attribution is a decoy surface at 56 per cent precision): each of the six is on topic by its own title and creator heading.
- **A07 Presidential libraries [JSON] (presidential-library-catalog.json):** Kennedy National Security Files JFK-4 (NAID 1164; Country Files series 193236); Johnson National Security Files LBJ-NSF (NAID 567979; Latin America Country Files 567985); Carter Office of the National Security Advisor JC-NSA (NAID 560131; Brzezinski Country Files 560151). Eisenhower's Whitman File and the Nixon NSC Files were not matched to a catalogue NAID in the bundled catalogue (not resolved); the catalogue carries no access status.
- **A08 The pre-1906 shelf [JSON] (central-files-index.json `countrySeries`):** `diplomaticDespatches` "Despatches from U.S. Ministers to Spain, 1792-1906", file-unit NAID 177380726 (134 rolls 1792-08-15 to 1906-12-15), series 603720; "Despatches from U.S. Ministers to Cuba, 1902-1906", file-unit NAID 177380758 (18 rolls, from 1902-05-27); `notesFromForeignMissions` "Notes from the Spanish Legation in the United States to the Department of State, 1790-1906" NAID 183303928; "Notes from the Cuban Legation ... 1844-1906" NAID 183303950; `diplomaticInstructions` series 593313 (10 Spain rolls, 1833-03-12 to 1906-08-10). `series-facts-index.json` holds no row for these series: access status not in the bundled data. The series titles are quoted in the overview from these JSON rows, in italics; they are not document quotations. The offline stack barely reaches before 1940 (11 of 695 bundled series): the empty pre-1900 channel is a limit of the data, not an archival absence.

**Channel two, "pointed-at" (`external_citations`, many rows per document; no row before 1910-12-06; stores the citation fragment; lot, library and decimal anchors only).** SQL (arch1.py, arch2.py): `SELECT s.date, ec.anchor, ec.repository, ec.collection, ec.lot_file_norm FROM sc s JOIN external_citations ec ON ec.volume_id=s.volume_id AND ec.document_id=s.document_id`.

- **A09 Rows by band:** 1870–1899: **0**; 1900–1939: 7 (all `centralFileClass`); 1940–1957: 179 (161 `centralFileClass`, lot files 53D26 3, 57D284 2, 65D212 2, 57D295 2, 59D376 2, ...); 1958–1989: 774 (256 `centralFileClass`; Carter Library National Security Affairs 134; Kennedy Library National Security Files 65; lot 66D95 28; Johnson Library National Security File 26; Nixon NSC Files 20; lot 65D438 13; 62D24 10; Carter Presidential Materials 10; 66D204 8). **Scope documents with at least one row: 621 of 4,107.**
- **A10 Lots most cited as pointed-at (rows; distinct documents):** 66D95 28; 24 — 65D438 13; 11 — 62D24 10; 8 — 65D330 8; 8 — 66D204 8; 8 — 64D199 7; 5 — 65D533 6; 5 — 84D241 6; 4.
- **A11 66D95 [JSON] "Records Relating to National Security Council Policy Papers", RG 59, A1 1586E, NAID 2839192, creator Office of the Secretary Executive Secretariat, inclusive 1947–1979, 26 feet 3 inches, **Restricted - Partly**; `lot-claimants-index.json` gives the lot a second claimant, "Subject Files", A1 1586F, NAID 2839193, 1947–1965 (so there are two correct answers).** 65D212 "Records Relating to Sugar", RG 59, UD-UP 215, NAID 27022874, creator Bureau of Economic Affairs, Office of International Resources, inclusive 1955–1962 (coverage 1932–1962), **Restricted - Fully**.
- **A12 Collection-usage index [JSON], a third surface, not summed with A01–A11:** `collection-usage-index.json` (generated 2026-10-20) summed over five Cuba-focused volumes (`frus1958-60v06`, `frus1961-63v10`, `frus1961-63v11`, `frus1964-68v32`, `frus1977-80v23`; entry `n` counts by volume index `v`): Department of State Central Files 434; Kennedy Library National Security Files 230; Carter Library National Security Affairs 197; Johnson Library National Security File 164; Central Files 1964–66 97; Eisenhower Whitman File 62; Naval Historical Area Files 39; lot 65D438 29; OASD (C) A Files FRC 71 A 2896 27; lot 74D272 (Ball Files) 26; Kennedy President's Office Files 23; lot 66D501 22; CIA DCI (McCone) Files Job 80-B01285A 18; Carter National Security Council 17.

## 7. Reading accounting

- **R01** Retrieved whole to disk: **65** documents (dump.py: `SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0`); captured length = `length(body_text)` for **65 of 65** (character counts). Read: windows around Cuba and theme words for most of those 65, the opening of many, and the whole text of fewer than ten (the Fish instruction of 1874, the Roosevelt message of 1902, the 1934 treaty, the 1948 and 1951 papers, the June 1960 notes and memorandum, the Gates letter, the Carter address). Quoted: **22** documents, **32** verified quotations (31 used in the collection).
- **R02** Documents never retrieved but ranked: the 4,107 tier-2 documents were scanned by machine (scan.py), not read; their count-based findings (N05, N07) are about vocabulary, not content.
- **R03** Unread: the 1,137 Havana-only documents (N06); the 1960s microfiche-supplement documents beyond the ones ranked in the top lists.

## 8. Limits, thin results and things not done

- No TEI scan was run, so no spelling-variant or apparatus/document separation was done; the vocabulary windows (N05) include editors' footnotes, which `body_text` blends with document text.
- The Cuba family count is a lower bound (N06), the tier-2 rule (5 mentions, case-sensitive) misses capitalised "CUBA" and counts reprints twice (V5), and the arbitration volumes of the 1870s (`frus1872p2v*`) contribute incidental mentions to the earliest band (they date from 1811–1872 and mostly fall outside the 1870s; 122 tier-2 documents fall in the 1870s, 30 of them in `frus1874`).
- Pre-1900: the index has a source row for 1 of 309 tier-2 documents and no pointed-at rows, so any archival statement about the 1870s–1890s is by series title only (A08).
- 1990s: 177 dated documents and no Cuba match; the series as indexed ends in 1988–89.
- The reading of the missile-crisis transcripts rests on two unscripted transcripts whose speaker labels are the editors' and whose text is partly unintelligible.
- Neighbour lists were read only for the 13 anchors named (8 in V2, 13 in V5).
- Threads proposed in the overview's "Read next" and the collection's closing note were checked only for existence: `... MATCH 'crowder AND cuba'` returns documents in `frus1919v02` (22), `frus1921v01` (103), `frus1922v01` (45), `frus1923v01` (19), `frus1925v02` (15); `... MATCH 'mariel'` returns 55 non-apparatus documents (earliest dated 1866, a name, latest 1980-09-30); `... MATCH 'cuba AND angola'` returns 312 (1951-02-08 to 1989-01-08). The Ferrara sugar-tariff exchanges are `frus1927v02/d595` (1927-12-15), `frus1928v02/d662` (1928-06-13) and `frus1929v02/d924` (1929-01-10), seen in the ranked lists, not read beyond windows.
- `frus1873p1v2/d71` (Sickles, January 1873) and `frus1871/d340`, `d347` were read in windows and not used: they are claims and neutrality correspondence, not statements of national interest; the 1870 circular `frus1870/d197` (the Monroe doctrine "invoked in consequence of the supposed peril of Cuba on the side of Europe") was read in windows and not used because it is a historical review in a trade circular.

## 9. TRACE TABLE (one row per number and per quotation in overview.md)

(Appended below; line numbers are lines of this file.)

| overview item | memo line |
|---|---|
| 553 volumes indexed (bottom line 1, Scope, How this was done) | line 5 (coverage), 19 (C1) |
| 22 documents the argument rests on (bottom line 1, Scope, How this was done, Read next) | line 192 (R01); the 22 are the document entries of collection.fruscollection, listed with dates in section 4 and verified by line 144 |
| about 4,100 documents naming Cuba five or more times (4,107) (bottom line 1 and 2, Scope, How this was done) | lines 13 (S3), 52 (N03) |
| about 12,300 documents that name Cuba at all (12,256) (bottom line 1, Scope) | line 26 (N01) |
| Cuba file class 837 glossed as political affairs, financial conditions, cane sugar (documents dated 1910 to 1949) | line 176 (A03) |
| for 1900 to 1957 most documents came from the central decimal file in Record Group 59 | line 175 (A02) |
| Missile Crisis lot: entry A1 3053, identifier 27022950, 1962–1963, partly restricted | line 179 (A06) |
| Memorandums of Conversation: A1 1566, identifier 602231, 1953–1964, unrestricted | line 179 (A06) |
| Special Assistant on Communism subject files: A1 3148, identifier 2363836, 1958–1961, partly restricted | line 179 (A06) |
| Operation Mongoose files: UD-UP 293-B, identifier 648748, 1963–1965, unrestricted | line 179 (A06) |
| presidential libraries (Kennedy, Johnson, Nixon, Carter, Eisenhower Whitman File) and CIA files as sources | lines 177 (A04), 180 (A07) |
| 621 of the same 4,100 documents carry at least one footnote citation of unprinted files | line 185 (A09) |
| NSC Policy Papers lot: A1 1586E, identifier 2839192, 1947–1979, partly restricted; second series A1 1586F | line 187 (A11) |
| Records Relating to Sugar: UD-UP 215, identifier 27022874, 1955–1962, coverage from 1932, fully restricted | line 187 (A11) |
| index records a source for 1 of 309 documents (1870–1899); no footnote entry before December 1910 | lines 174 (A01), 183 (channel two header), 185 (A09) |
| National Archives series for Spain and Cuba: identifiers 177380726, 603720, 177380758, 183303928, 183303950 | line 181 (A08) |
| 177 indexed documents dated in the 1990s, none naming Cuba | line 26 (N01) |
| a nonsense word returned nothing; Department of State appeared in all 553 volumes (also: 'Department of State' and 'national security' in quotation marks are search terms, not quotations) | line 19 (C1) |
| 1,137 documents about Havana that never use the word Cuba, across four periods | line 82 (N06) |
| only 10 documents before 1947 pair 'national security' with Cuba (para 3, Decisions) | line 56 (N04) |
| 10 of 40 sampled documents use 'national security' in any sense but the Council's name | line 56 (N04) |
| literal in 39 of 40 sampled documents, all 40 with plurals | line 48 (N02) |
| about 62 per thousand in the 1870s, 17 in the 1940s, 114 in the 1960s | line 26 (N01) |
| about 65 documents read in full or in windows | line 192 (R01) |
| 2,982 of 6,124 documents naming Cuba from 1958 in one cluster; none of the 1,240 from 1870 to 1899 | line 86 (N07) |
| fingerprints put the 1874 instruction nearest 1897–98 despatches; the 1951 statement beside a 1948 memorandum and the 1969 study | line 152 (V2); V7 at line 166 |
| share of documents with defence or Soviet vocabulary near Cuba: between one in five and one in three before 1958 (0.304, 0.219, 0.330), about four in five from 1958 (0.783) | line 69 (N05, narrow list) |
| share with sugar, trade or investment vocabulary near Cuba: seven in ten in 1940–1957 (0.705) to one in two from 1958 (0.505) | line 69 (N05, narrow list) |
| quota reduction 'by a fifth to a quarter' (20 to 25 per cent) | line 126 (Q15) |
| 'five days later' (22 June to 27 June 1960) and 'nearly a year earlier' | lines 126 (Q15 date), 127 (Q28 date and passage) |
| 'three months later' (treaty 29 May 1934; trade agreement 24 August 1934) | lines 119 (Q09), 120 (Q32) |
| dates in the text: February 1874; October 1897; April 1898; March 1902; August 1917; 1933; 1941; 1948; 1951; 1952; September 1959; June and July 1960; 16 October 1962 (morning, evening); July 1969; 1977; 1979; 1981 | lines 109 to 140 (section 4 table), times of day at line 142 |
| six sections and 31 passages in the collection | line 144 (check_overview.out summary) |
| Crowder missions of 1919–1923; sugar-tariff exchanges of 1927–1929; Mariel exodus of 1980 (existence only) | line 204 |
| quotation: “almost contiguous to the United States” | line 109 (Q01, with its volume_id/document_id and the retrieving SELECT stated at the head of section 4) |
| quotation: “a large and lucrative market” | line 110 (Q02, with its volume_id/document_id and the retrieving SELECT stated at the head of section 4) |
| quotation: “the commerce, trade, and business of our people” | line 114 (Q06, with its volume_id/document_id and the retrieving SELECT stated at the head of section 4) |
| quotation: “a constant menace to our peace” and the Q05 sentence | line 113 (Q05, with its volume_id/document_id and the retrieving SELECT stated at the head of section 4) |
| quotation: “of great strategic importance” and the Q12 sentence | line 123 (Q12, with its volume_id/document_id and the retrieving SELECT stated at the head of section 4) |
| quotation: “a domestic, political problem” | line 132 (Q26, with its volume_id/document_id and the retrieving SELECT stated at the head of section 4) |
| quotation: “strategic weapons” and the Q19 sentence | line 134 (Q19, with its volume_id/document_id and the retrieving SELECT stated at the head of section 4) |
| quotation: “It presents no direct threat to us” | line 138 (Q22, with its volume_id/document_id and the retrieving SELECT stated at the head of section 4) |
| quotation: “perpetual solicitude” | line 111 (Q03, with its volume_id/document_id and the retrieving SELECT stated at the head of section 4) |
| quotation: “our great commerce with Cuba has thus been practically destroyed” | line 112 (Q04, with its volume_id/document_id and the retrieving SELECT stated at the head of section 4) |
| quotation: the Q07 sentence on foreign lodgment | line 115 (Q07, with its volume_id/document_id and the retrieving SELECT stated at the head of section 4) |
| quotation: the Q08 sentence | line 117 (Q08, with its volume_id/document_id and the retrieving SELECT stated at the head of section 4) |
| quotation: the Q09 sentence | line 119 (Q09, with its volume_id/document_id and the retrieving SELECT stated at the head of section 4) |
| quotation: “economic and defense reasons” and the Q10 sentence | line 121 (Q10, with its volume_id/document_id and the retrieving SELECT stated at the head of section 4) |
| quotation: the Q11 sentence | line 122 (Q11, with its volume_id/document_id and the retrieving SELECT stated at the head of section 4) |
| quotation: “retaliatory instruments” and the Q13 sentence | line 125 (Q13, with its volume_id/document_id and the retrieving SELECT stated at the head of section 4) |
| quotation: the Q15 sentence | line 126 (Q15, with its volume_id/document_id and the retrieving SELECT stated at the head of section 4) |
| quotation: “one Rubicon” and the Q14 sentence | line 128 (Q14, with its volume_id/document_id and the retrieving SELECT stated at the head of section 4) |
| quotation: “intolerable and not acceptable” and the Q18 sentence | line 129 (Q18, with its volume_id/document_id and the retrieving SELECT stated at the head of section 4) |
| quotation: “doesn’t mean that much” and the Q16 sentence | line 130 (Q16, with its volume_id/document_id and the retrieving SELECT stated at the head of section 4) |
| quotation: the Q17 sentence | line 131 (Q17, with its volume_id/document_id and the retrieving SELECT stated at the head of section 4) |
| quotation: “subsidiary and lesser” | line 135 (Q20, with its volume_id/document_id and the retrieving SELECT stated at the head of section 4) |
| quotation: the Q21 passage | line 136 (Q21, with its volume_id/document_id and the retrieving SELECT stated at the head of section 4) |
