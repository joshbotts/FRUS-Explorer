# Scope memo — run r8 (2026-10-25)

Question: How did the United States decide whether to recognize governments that came to power by force in Latin America, and what did it ask of them before recognizing?

All counts below are conditional on the library in this copy of the index: **553 volumes, 321,749 documents, 1,103 front-matter rows, 8,481 editorial notes** (M0; canary query, output `553|321749|1103|8481`). The read-only proof failed with `attempt to write a readonly database` as required. Resources: the SQLite copy (SQL below), the bundled JSON under `/Applications/FRUS Explorer.app/Contents/Resources/` (scripts named), no TEI pass was run (no counting-surface claim is made from the XML).

## 1. How the scope was found

**M1. Candidate pool (index, FTS).** 233 volumes were selected from `manifest.json` as Latin-America-related (title regex on American Republics / Western Hemisphere / Latin America / country names, or ≥3 Latin American country tags; `la_volumes.py` → `la_volumes.tsv`). Over them, the query

```
SELECT d.volume_id, d.document_id, dd.date_iso, d.header FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
WHERE frus_documents MATCH 'NEAR(recogn* government, 6) OR NEAR(recogn* regime, 6) OR NEAR(recogn* junta, 6)'
  AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN (<233 ids>) ORDER BY 1,2
```
returned **5,518 documents in 228 of the 233 volumes** (`scope.py` → `scope_hits.tsv`). Controls in the same pass over the whole corpus (`scan1.py`): `"department of state"` → 94,049 documents in 552 volumes (positive; one volume has no non-apparatus hit); `ZZZ_IMPOSSIBLE_ZZZ` → 0 (negative). Both second editions (frus1951-54IranEd2, frus1969-76ve15p2Ed2) were excluded from every count; the surface counted is this index with apparatus excluded.

**M2. The editors' formula.** `volume_structures.structure_json` was walked for chapter titles containing "recogni" (253 headings, 165 in the 233 volumes; `headings.py` → `headings_recognition.tsv`) and, in the 233 volumes, "revolution|coup|junta|overthrow|de facto|usurp|insurrection|regime" (142; `headings2.py` → `headings_revolution_LA.tsv`). Before 1950 the editors title these episodes as "Revolution in X", "Recognition of the Y Government", "Refusal of the United States to recognize …", "Withholding of recognition …". After 1950 chapters are by country and the episodes were located from the FTS hits mapped to chapter (`chapters_post1950.py` → `chapters_post1950_AR.tsv`) and bracketed by hand from headers and dates (`hdr.py`).

**M3. Core scope (inclusion rule).** A document is in the core if it sits in one of 90 hand-selected chapters whose editors' title names the recognition of, or a revolution/coup/overthrow producing, a government in a Latin American republic (list `CH` in `core_build.py`), or in one of eight hand-bracketed post-1950 ranges (El Salvador 1960, Peru 1962, Dominican Republic 1963, Honduras 1963, Argentina 1966, Peru 1968, Chile 1973, Bolivia 1978–80; list `RANGES`). Chapters about claims, asylum, border incursions and revolutionary bands, the Cuban intervention of 1906, the Haitian political chapters of 1914–1915, the Dominican chapters of 1912–1915 and the Mexican financial chapter of 1916 were left out, as were the Mexican insurrection of 1929 and the Cuban Machado chapter of 1933 (an elected president's fall, not a government's rise by force). Result (`core_scope.tsv`): **3,549 slots, all present in `document_cache`; 8 editorial notes dropped; 3,541 non-apparatus documents in 52 volumes, dated 1895–1980, none undated.** Per-volume counts: frus1914 353, frus1913 343, frus1915 236, frus1933v05 224, frus1944v07 187, frus1932v05 163, frus1931v02 131, frus1911 119, frus1930v03 109, frus1937v05 103, frus1945v09 102 … frus1950v02 3 (full list in `core_build.out`). The Mexican chapters of 1913–1916 are 932 of the 3,541.

**M4. Decade shape** (date = `document_dates.date_iso`, the document's own date, not the volume year; denominator = dated non-apparatus documents in the 233 volumes):

| decade | core docs | LA dated docs | per 1,000 |
|---|---|---|---|
| 1890s | 50 | 8,748 | 5.7 |
| 1900s | 40 | 9,947 | 4.0 |
| 1910s | 1,411 | 19,206 | 73.5 |
| 1920s | 295 | 19,471 | 15.2 |
| 1930s | 1,096 | 15,936 | 68.8 |
| 1940s | 531 | 19,816 | 26.8 |
| 1950s | 4 | 12,538 | 0.3 |
| 1960s | 72 | 9,265 | 7.8 |
| 1970s | 35 | 8,057 | 4.3 |
| 1980s | 7 | 2,319 | 3.0 |

Top-volume share of the 1910s numerator: frus1914 + frus1913 + frus1915 = 932 of 1,411 (Mexico). The 1950s figure (4 of 12,538) is a scope artefact: the editors of the 1950s volumes titled no chapter for recognition (M2), and the FTS hits inside their country chapters were not read (see §5).

## 2. What was measured in the core (FTS count, then literal share; `core_build.py` → `core_phrase_shares.tsv`)

Query shape for every row: `SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN core c ON … WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0` (TEMP TABLE `core` holds the 3,541 pairs). Literal share: Python `re` over header+dateline+source_note+body_text whitespace-collapsed, on an evenly spaced sample of 40 from the (volume_id, document_id)-sorted hit list, or the whole set when under 300. STRICT = single spaces; TOLERANT = inflections and any run of space/hyphen/comma/parenthesis/full stop, case-insensitive. SQL `LIKE` was not used; all literal tests are Python `re`.

| family | FTS query | FTS hits (of 3,541) | sample | STRICT | TOLERANT |
|---|---|---|---|---|---|
| M5 international obligations | `"international obligations"` | 129 | 129 | 127 of 129 | 129 of 129 |
| M6 de facto | `"de facto"` | 220 | 220 | 219 of 220 | 220 of 220 |
| M7 free elections | `"free elections" OR "free election"` | 54 | 54 | 54 of 54 | 54 of 54 |
| M8 constitutional government | `"constitutional government"` | 137 | 137 | 98 of 137 | 125 of 137 |
| M9 recognition | `recognition` | 959 | 40 | 40 of 40 | 40 of 40 |
| M10 consult | `consult*` | 254 | 254 | 248 of 254 | 254 of 254 |
| M11 withhold recognition | `NEAR(withhold recognition,4) OR NEAR(withheld recognition,4) OR NEAR(withholding recognition,4)` | 43 | 43 | 31 of 43 | 38 of 43 |
| control + | `"department of state"` | 590 | 40 | 40 of 40 | 40 of 40 |
| control − | `ZZZ_IMPOSSIBLE_ZZZ` | 0 | — | — | — |

M8's 12 tolerant misses were read (`misses.py`, `misses2.py`): 11 are "constituted government(s)", which the porter stemmer folds with "constitutional government" (constitut + govern), and one (frus1920v02/d628) has no constitut*+govern* adjacency at all, so the family's published form is "constitutional or constituted government"; M11's 5 misses are the reversed order "recognition … withheld" (frus1931v02/d225, frus1937v05/d701, d710, frus1964-68v31/d127) and one with no withh* context (frus1931v02/d998), which `NEAR` matches order-free. A 1.000 share tests the stemmer, not the referent; the referent (what recognition was asked for) was tested by reading (§4).

**M12. False-friend test** (corpus-wide `SELECT COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0`; denominator 312,169 non-apparatus documents): `recognition` 959 of 3,541 in the core (0.271) against 15,991 of 312,169 corpus-wide (0.051); `"international obligations"` 129 of 3,541 (0.036) against 1,301 of 312,169 (0.004); `"de facto"` 220 of 3,541 (0.062) against 3,497 of 312,169 (0.011); control `"department of state"` 590 of 3,541 (0.167) against 94,049 of 312,169 (0.301). The question's terms are five to nine times enriched in the core while the control is depressed, so they measure the question, not the corpus.

## 3. Archival channels over the core (never summed)

**M13. Came-from** (`document_sources`, one row per document): 3,450 of 3,541 core documents have a row. By citation form (`citation_era`, a FORM not a date): decimal 3,281; structured 37; subject_numeric 32; cfpf 20; unrecognized 11; lot_file 4; published 3; named_series 1. Top decimal classes (`decimal_class`): 812.00 929, 837.00 227, 818.00 173, 816.01 170, 824.00 138, 814.00 126, 823.00 101, 839.00 99, 825.00 85, 834.00 75, 816.00 73, 815.00 70, 835.00 69, 817.00 67. Glossed through `decimal-class-labels.json` (`json_resolve.py`), each with the document's own year inside the 1910–1949 glossable span (`coverage.glossableYears`; renumbered 1950): class 8 = Internal Affairs of States; country 12 Mexico, 37 Cuba, 18 Costa Rica, 16 El Salvador, 24 Bolivia, 14 Guatemala, 23 Peru, 39 Dominican Republic, 35 Argentina, 31 Venezuela; subclass .00 political affairs, .01 government/recognition; 710.11 = Political Relations of States, Pan-America. Named series among the structured/subject-numeric rows: National Archives RG 59 Central Files 1964–66 (12 docs), 1967–69 (7), `POL 15 HOND` (7); Nixon Presidential Materials NSC Files (9); Carter Library National Security Affairs (7); Johnson Library National Security File (7); Kennedy Library National Security Files (4); Eisenhower Library Whitman File (4). Came-from lots: 64D16, 66D149, 66D95, 84D241 (1 each; a fifth value "NO" is a parse artefact). **No bundled series row exists for the Central Decimal File 1910–1963 itself**: `series-facts-index.json` has no row naming "Central Decimal" (0 of 698), and `central-files-index.json`'s `numericalFile` names only the 1906–1910 Numerical File (series NAID 654171, microfilm M862), which is not in `series-facts-index.json` either. The offline stack barely reaches before 1940, so the came-from channel for 1895–1949 resolves to a class gloss, not a shelf.

**M14. Pointed-at** (`external_citations`, many rows per document; no row before 1910-12-06; holds lot, library and decimal anchors only): 160 rows over 118 core documents. Repository/collection: Department of State, no collection, 138 rows / 102 docs; Carter Library, National Security Affairs 16 / 12; Nixon Presidential Materials, NSC Files 2 / 1; Carter Library Plains File 1 / 1; Carter Library Presidential Materials 1 / 1. Pointed-at lots (`lot_file_norm`): 63D127 (2), 64D16, 65D330, 66D95, 71F154, 82D100 (1 each).

**M15. Lot resolution** (`central-files-index.json` `lotFiles`, matched on `lotNumber`; facts from `series-facts-index.json` `byNaId`, legend-expanded; `json_resolve.py`, `sf_lookup.py`):

| lot | channel | RG / entry | NAID | title | creator / dates / access |
|---|---|---|---|---|---|
| 63D127 | pointed-at | 59 / A1 3157 | 2363840 | Subject and Country Files | Office of Central American and Panamanian Affairs, 1955–1963, Restricted–Possibly |
| 64D16 | both | 59 / A1 3159 | 1750062 | Records Relating to El Salvador | Office of Central American Affairs, Restricted–Partly (FOIA b1) |
| 65D330 | pointed-at | 59 / A1 1566 | 602231 | The Secretary's and the Under Secretary's Memorandums of Conversation | Executive Secretariat, 1953–1964, Unrestricted |
| 66D149 | came-from | 59 / A1 5158 | 610077 | Presidential Memorandums of Conversation | Executive Secretariat, 1956–1964, Unrestricted |
| 66D95 | both | 59 / A1 1586E | 2839192 | Records Relating to National Security Council Policy Papers | Executive Secretariat, 1947–, Restricted–Partly |
| 71F154 | pointed-at | 59 / UD-WX 660 | 27023004 | Records Relating to Petroleum Issues in Lima, Peru | U.S. Embassy Peru, 1962–1966, Restricted–Fully |
| 82D100 | pointed-at | 59 / UD-05D 71–72 | 26309182 | Official Files and Briefing Books of Edmund Muskie | Office of the Secretary, 1977–1981, Restricted–Fully |
| 84D241 | came-from | 59 / UD-14D 69 | 26309216 | Briefing Books of Cyrus R. Vance | Office of the Secretary, 1978, Restricted–Partly |

Presidential libraries (`presidential-library-catalog.json`): Kennedy, Papers of John F. Kennedy, National Security File, collection NAID 1164, Country Files series NAID 193236 (1961–1963); Johnson, National Security Files, NAID 567979, Latin America Country Files NAID 567985 (1963–1969); Carter, Records of the Office of the National Security Advisor, NAID 560131, Zbigniew Brzezinski's Country Files NAID 560151 (1977–1981). None of these NAIDs has a `series-facts-index.json` row (access status unknown from the bundle). Nixon NSC Files were not resolved: my filter on the catalog matched no Nixon collection and I did not guess. NARA creator headings above were read from the rows, not inferred.

## 4. Reading and quotations

**M16.** 52 documents were retrieved whole (captured length = `length(body_text)` for all 52; `reading_log.tsv`; texts in `texts/`), through `SELECT volume_id, document_id, header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?` (`readdoc.py`). 30 passages were quoted; each was cut from the raw `body_text` and verified with `SELECT instr(body_text, ?) FROM document_cache WHERE volume_id=? AND document_id=?` (`excerpts.py` → `excerpt_verify.tsv`, every `instr` > 0; `excerpts.json` holds the exact text). `summary_text` and `note_text` were never read. Chosen by `top.py` (bm25 for `recogn*` within the chapter's id range) and `hdr.py`.

| Q | (volume_id, document_id) | date | what it shows |
|---|---|---|---|
| Q1 | frus1913, d7 | 1913-03-12 | Wilson's declaration: just government rests on the consent of the governed |
| Q2 | frus1913, d1028 | 1913-08-27 | Wilson's address: Mexico's future lies in constitutional government |
| Q30 | frus1913, d1028 | 1913-08-27 | the Lind proposals (a)–(d) |
| Q29 | frus1913, d7 | 1913-03-12 | no sympathy for those who seize power |
| Q27 | frus1913, d1029 | 1913-08-16 | Gamboa's refusal |
| Q3 | frus1917, d379 | 1917-02-09 | only a constitutionally elected government is entitled to recognition (Tinoco) |
| Q4 | frus1920v01, d391 | 1920-09-27 | wait for Bolivia's elections; act with Argentina and Brazil |
| Q5 | frus1921v01, d238 | 1921-01-31 | Bolivia recognized as constitutional, not de facto, government |
| Q6 | frus1923v02, d345 | 1923-06-30 | Article II of the 1923 treaty adopted as US policy |
| Q8 | frus1932v05, d639 | 1932-02-27 | Martínez must resign outright |
| Q28 | frus1934v05, d199 | 1934-01-08 | the US declined to recognize Martínez under the treaty |
| Q9 | frus1936v05, d112 | 1936-04-30 | no longer guided by Article II |
| Q7 | frus1930v01, d375 | 1930-09-17 | Stimson's three tests |
| Q11 | frus1943v05, d334 | 1943-06-06 | recognition as nearly simultaneous as possible, after consultation (Argentina) |
| Q10 | frus1943v05, d486 | 1943-12-22 | hemisphere security first; outside influence (Bolivia) |
| Q23 | frus1944v07, d231 | 1944-05-18 | recognition expected only for a contribution to the war effort |
| Q12 | frus1945v09, d1170 | 1945-10-25 | Venezuela junta: control, support, obligations; Resolution XXII |
| Q25 | frus1946v11, d312 | 1946-07-26 | Bolivia junta: elections and obligations |
| Q21 | frus1947v08, d742 | 1947-08-21 | Nicaragua: a stable de facto government in all but name |
| Q14 | frus1948v09, d89 | 1948-11-08 | Bogotá Resolution XXXV avoids the word recognition |
| Q13 | frus1948v09, d115 | 1948-12-10 | PPS: recognition implies neither approval nor disapproval; not a political weapon |
| Q26 | frus1949v02, d448 | 1949-12-08 | Panama: three questions of the consultation |
| Q15 | frus1950v02, d478 | 1950-06-01 | Haiti junta's three assurances |
| Q22 | frus1958-60v05mSupp, es_d43 | 1960-12-01 | El Salvador recognition note: constitution, treaties, human rights, free elections |
| Q24 | frus1961-63v12, d421 | 1962-07-27 | Peru: the suspension moved the junta on elections |
| Q16 | frus1961-63v12, d359 | 1963-10-04 | Dominican Republic: no recognition as the regime stands |
| Q17 | frus1964-68v31, d132 | 1966-06-28 | Argentina: relations suspended; consult under Rio Resolution XXVI |
| Q18 | frus1964-68v31, d512 | 1968-10-06 | Peru: toward a variant of the Estrada doctrine |
| Q19 | frus1969-76v21, d349 | 1973-09-12 | Chile: we recognize countries, not governments |
| Q20 | frus1977-80v24, d137 | 1978-08-03 | Bolivia: recognition need not be addressed |

Documents read but not quoted (24): frus1917/d407, frus1923v02/d550, frus1932v05/d622, frus1936v05/d108, frus1944v07/d386, d390, frus1945v09/d251, frus1947v08/d755, frus1948v09/d74, d75, d109, d114, d119, frus1950v02/d477, frus1958-60v05mSupp/es_d29, frus1961-63v12/d422, d360, frus1961-63v10-12mSupp/d160, d165, d166, frus1964-68v31/d128, frus1969-76v21/d355, frus1977-80v24/d134, d158.

Caveat on Q17: the sentence quoted is the Department's; the criteria of Rio Resolution XXVI that follow it in `body_text` are the editors' footnote (body_text includes footnotes), and are described in the overview as the editors' summary.

## 5. What was not done / negatives

- **M17.** The 1950s: the core holds 4 documents dated 1950–1959 (M4). The candidate pool (M1) holds hits inside the 1952–1957 country chapters (Cuba d326, d327, d336; Bolivia d136–d163; Guatemala d410–d512 in frus1952-54v04; Argentina d193–d232 in frus1955-57v07; `chapters_post1950_AR.tsv`), none under a recognition heading; none was read. This is a scoping limit, not a finding that the series is silent.
- Brazil 1964 (frus1964-68v31 d205, d206, d228, d236) and Argentina 1976 (frus1969-76ve11p2 d9, d34, d51) have hits and were not read. Pre-1895 decades show 198–324 pool hits each (M1 decade table in `scope_decades.tsv`) and were outside the chosen scope.
- No TEI counting was done; no variant-spelling census is claimed. The 1923 treaty text is quoted as Hughes quoted it (Q6), not from the treaty.
- An FTS lookup for the editorial note on Acheson's recognition speech of September 19, 1949 (`recogn* AND acheson AND september`, frus1949v02, `is_editorial_note=1`) returned no rows; the speech is cited in Q26's document as "see editorial note p. 462" and was not located.
- The `terms` table and `person_mentions` were not used; no person count is reported.

## 6. Trace table (overview → memo)

| overview item | memo line |
|---|---|
| "553 volumes … what I downloaded" | M0 |
| "about three and a half thousand documents in 52 volumes" | M3 (3,541; 52) |
| "a wider net … about five and a half thousand in 228 volumes" | M1 (5,518; 228 of 233) |
| "roughly one document in four … about one in twenty across the index" | M12 (959 of 3,541; 15,991 of 312,169) |
| "the 1910s and the 1930s each about seven in a hundred … the 1950s four documents" | M4 |
| "two thirds of the 1910s documents are Mexico" | M4 (932 of 1,411) |
| "international obligations … about one in twenty-seven" | M5 (129 of 3,541) |
| "free elections … 54 documents" | M7 |
| "controls" (positive 590; negative 0) | §2 table; M1 |
| came-from: decimal file, classes glossed, no series row | M13 |
| pointed-at: 160 citations over 118 documents; lots table | M14, M15 |
| libraries and NAIDs | M15 |
| 52 read whole, 30 quoted and verified | M16 |
| every quotation Q1–Q30 | §4 table |
| 1950s, Brazil 1964, Argentina 1976, pre-1895 not read | M17 |
| Wilson's four Lind proposals (a)–(d) | Q30 |
| Rio Resolution XXVI criteria as the editors' summary | §4 caveat on Q17 |

Files: `queries.log`, `la_volumes.tsv`, `scan1_counts.json`, `rank1.tsv`, `headings_recognition.tsv`, `headings_revolution_LA.tsv`, `scope_hits.tsv`, `scope_decades.tsv`, `scope_per_volume.tsv`, `chapters_post1950_AR.tsv`, `core_scope.tsv`, `core_decades.tsv`, `core_phrase_shares.tsv`, `core_came_from.tsv`, `core_pointed_at.tsv`, `core_archival_keys.json`, `core_build.out`, `json_resolve.out.json`, `reading_log.tsv`, `texts/`, `excerpts.json`, `excerpt_verify.tsv`, `collection.fruscollection`.
