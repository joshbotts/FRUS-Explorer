# Scope memo: how the United States decided whether to recognize governments that came to power by force in Latin America, and what it asked of them

Run: research run of 2026-10-25 (working directory /Users/jbotts/frus-analysis/c3/runs/r1). Library: the copy of the FRUS Explorer index taken 2026-10-25, opened read-only. This memo is for the operator; the overview is for the historian. Every count below is conditional on this library, which holds **553 volumes**, the whole series [N01]. Nothing here is thin because of a partial library; where a result is thin it is thin in the corpus itself, and the memo says so. No number comes from the NARA record-group harvest: no [HARVEST] path was given, so that surface is unavailable to this run.

Labels. A line that begins [Nxx] carries a number reported in the overview; [Qxx] marks a verified quotation; [Rxx] marks a date or figure the overview takes from a document. The TRACE TABLE at the end maps every number and quotation of the overview to the line that holds it. Counting surfaces: INDEX = the SQLite copy (full text in which different forms of a word share one entry; documents flattened to text); TEI = the tag-stripped, whitespace-collapsed, case-insensitive text of each historical-document division of the XML volumes (inline markup removed, block elements separated by a space; BODY excludes footnotes and the source note, NOTES is those); JSON = the bundled reference files. The query log is queries.log (commands in the order they were run, one per line; its last line, ELIDED, names what it shortens or leaves out); scripts are in scripts/, work files in work/, and the text of every document retrieved is in raw/.

## 1. Coverage and controls

[N01] Coverage query, run first as the canary (INDEX):

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;
```
Result: `553|321749|1103|8481`, as expected. The read-only proof (`BEGIN; CREATE TABLE zz(x); ROLLBACK;` against the file opened with -readonly) failed with "attempt to write a readonly database", as expected.

[N16] Positive and negative controls, one pass over all 553 volumes (INDEX):

```sql
SELECT ctl, COUNT(*) AS volumes, SUM(n>0) AS volumes_with_hit, MIN(n) AS min_docs_in_a_volume, SUM(n) AS docs_hit FROM (SELECT 'positive: Department of State' AS ctl, v.volume_id, COALESCE(h.n,0) AS n FROM (SELECT DISTINCT volume_id FROM document_cache) v LEFT JOIN (SELECT volume_id, COUNT(*) AS n FROM frus_documents WHERE frus_documents MATCH '"department of state"' GROUP BY volume_id) h ON h.volume_id=v.volume_id UNION ALL SELECT 'negative: ZZZ_IMPOSSIBLE_ZZZ', v.volume_id, COALESCE(h.n,0) FROM (SELECT DISTINCT volume_id FROM document_cache) v LEFT JOIN (SELECT volume_id, COUNT(*) AS n FROM frus_documents WHERE frus_documents MATCH 'ZZZ_IMPOSSIBLE_ZZZ' GROUP BY volume_id) h ON h.volume_id=v.volume_id) GROUP BY ctl;
```
Result: positive 552 of 553 volumes with a hit (98,970 documents); the one volume with none is frus1919Parisv05 (Paris Peace Conference minutes, no Latin American section), found with `SELECT v.volume_id FROM (SELECT DISTINCT volume_id FROM document_cache) v WHERE v.volume_id NOT IN (SELECT volume_id FROM frus_documents WHERE frus_documents MATCH '"department of state"' GROUP BY volume_id)`. Negative: 0 of 553, 0 documents. On the TEI surface the positive phrase has no hit in 2 of 553 volumes (frus1919Parisv05 and frus1919Parisv13; the TEI surface counts the literal phrase only) and the negative phrase has none anywhere (work/tei_summary.txt). Header controls used in section 9: `SELECT COUNT(*) FROM document_cache WHERE header LIKE '%ZZZ_IMPOSSIBLE_ZZZ%'` gave 0 and `SELECT COUNT(*) FROM document_cache WHERE header LIKE '%Memorandum%'` gave 58,391. (SQLite LIKE is case-insensitive for ASCII; every test written in Python in this run uses re.IGNORECASE, so the two agree.)

## 2. What counts as a document

[N02] The index holds 321,749 rows; a row is not always a document. The run built a derived table (work/scope.db, table scope_docs; script scripts/build_scope.py) with one row per document_cache row, reading

```sql
SELECT c.volume_id, c.document_id, c.document_number, c.is_front_matter, c.is_editorial_note, length(c.body_text), d.date_iso FROM document_cache c LEFT JOIN document_dates d ON d.volume_id = c.volume_id AND d.document_id = c.document_id;
```
and setting: numbered = document_number is not empty; apparatus = is_front_matter = 1 or is_editorial_note = 1; ed2_dup = the volume is frus1951-54IranEd2 or frus1969-76ve15p2Ed2 (second editions whose first editions are present; frus1977-80v09Ed2 has no first edition to duplicate and is kept, and is outside the scope anyway). Breakdown, from `SELECT COUNT(*), SUM(apparatus=1), SUM(apparatus=0 AND numbered=0), SUM(apparatus=0 AND numbered=1 AND ed2_dup=1), SUM(apparatus=0 AND numbered=1 AND ed2_dup=0) FROM scope_docs`: 321,749 rows = 9,580 front matter or editorial notes + 5,991 unnumbered container rows (chapter and compilation heads, which hold the editors' chapter text but are not documents) + 740 second-edition duplicates (358 in frus1951-54IranEd2 and 382 in frus1969-76ve15p2Ed2 on the numbered rule; the brief's figure of 701 uses another rule) + **305,438 numbered non-apparatus documents**. Every document count below is over that last set unless it says otherwise. The house exclusion (the two flags) is applied; the further exclusions (container rows, duplicates) are mine and are stated here. The brief's decade figures (74,043 documents for the 1940s, 5,798 for the 1870s) differ slightly from mine on this rule (74,049 and 5,795, from `SELECT decade, COUNT(*) FROM scope_docs WHERE numbered=1 AND apparatus=0 AND ed2_dup=0 AND date_iso IS NOT NULL GROUP BY decade`): a different definition, not an error in either.

## 3. The Latin American scope and how it was found

[N03] How found. manifest.json (JSON) gave volume titles and subseries (work/manifest_list.tsv, scripts/manifest_list.py). volume_structures.structure_json (INDEX) gave every volume's section tree, flattened by scripts/flatten_structures.py into work/structure_flat.tsv (314,616 document ids placed in sections, from `SELECT volume_id, structure_json FROM volume_structures ORDER BY volume_id`). The scope rule (scripts/build_scope.py): (a) a document is in scope if its volume is one of 46 hemisphere volumes (the whole volume: work/hemisphere_volumes.txt; chosen from the manifest titles that name the American Republics, the Western Hemisphere, a Latin American country or region; two appendix volumes of 1894 and 1902 that mention Mosquito Territory and a Mexican arbitration were not taken whole), or (b) a section on its path begins with a Latin American country name or spelling variant (Hayti, Chili, Argentine Republic, San Domingo, United States of Colombia, Central American States, Dominion Republic), the Greater Republic of Central America, 'Affairs at Bluefields', 'Mosquito Territory', or an inter-American conference (the regular expression is in scripts/build_scope.py). Result, from

```sql
SELECT lat_basis, COUNT(*), SUM(numbered=1 AND apparatus=0 AND ed2_dup=0) FROM scope_docs WHERE latam=1 GROUP BY 1;
```
hemisphere volumes 28,686 and Latin American sections of other volumes 28,458, total **57,144 scope documents**, in **157 volumes** (46 + 111; work/scope_volumes.tsv, from `SELECT volume_id, MIN(lat_basis), COUNT(*) FROM scope_docs WHERE latam=1 AND numbered=1 AND apparatus=0 AND ed2_dup=0 GROUP BY volume_id`). All 57,144 are dated, 1861-04-06 to 1988-12-30 (`SELECT MIN(date_iso), MAX(date_iso) FROM scope_docs WHERE latam=1 AND numbered=1 AND apparatus=0 AND ed2_dup=0`). Dated scope documents by decade (work/memo/decade_denominators.tsv, from `SELECT decade, COUNT(*) FROM scope_docs WHERE latam=1 AND numbered=1 AND apparatus=0 AND ed2_dup=0 GROUP BY decade`): [N03b] the 1970s hold 3,185 and the 1980s 391. For 1981-88 the library holds one volume on South America (frus1981-88v16, 88 documents in scope) and one on the South Atlantic conflict (frus1981-88v13, outside the scope rule) and none on Central America or the Caribbean (manifest.json titles).

Known limit of the rule: a document under a country heading need not be about that country's government, and a document about it can sit under a general heading. frus1913/d7 (Wilson's statement of 11 March 1913, addressed to the American diplomatic officers in Latin America) is outside the section rule; it was found by a phrase search with the scope filter off (scripts/browse.py --latam 0) and is in the collection by hand. It is the only cited document outside the scope (every other document retrieved is inside it, section 10).

## 4. The editors' own chapter titles (read before any phrase query was run)

[N18] The editors' chapter titles name recognition far more often than any modern phrasing would. Method (scripts/headings_grep.py, scripts/headings_latam.py, scripts/build_editors_set.py): every section path in work/structure_flat.tsv that contains 'recogni', 'nonrecogni' or 'non-recogni' and a Latin American segment, minus 12 explicit exclusions (headings that use the word for meat-inspection labels, naturalization certificates, a blockade, a Colombian-Spanish judgments convention, an asylum clause in Peru in 1913, the Monroe Doctrine, a Boston statement, an American citizen's protection, a Panamanian constitution, and the recognition of a union of states, the Greater Republic of Central America of 1896). Result: **62 headings in 36 volumes holding 2,257 document ids, 2,255 of them numbered non-apparatus documents**, dated 1895-09-06 to 1950-06-01 (work/editors_recog_headings.tsv; per heading in work/memo/editors_headings_counts.tsv; SQL `SELECT e.volume_id, COUNT(*), e.heading FROM editors_recog e GROUP BY e.volume_id, e.heading`). By decade (per 1,000 = per 1,000 dated Latin American scope documents of the decade; top share = the largest single volume's share of the numerator):

```
decade | docs_under_editors_recognition_headings | latam_dated_docs_in_decade | per_1000 | volumes | top_volume | top_share
1890 | 50 | 2349 | 21.3 | 2 | frus1899 | 0.92
1900 | 40 | 3084 | 13.0 | 4 | frus1900 | 0.33
1910 | 1142 | 10441 | 109.4 | 10 | frus1911 | 0.37
1920 | 278 | 4972 | 55.9 | 9 | frus1920v03 | 0.25
1930 | 306 | 9470 | 32.3 | 5 | frus1937v05 | 0.36
1940 | 436 | 11083 | 39.3 | 6 | frus1944v07 | 0.43
1950 | 3 | 3086 | 1.0 | 1 | frus1950v02 | 1.0
```

Reading: the editors stop titling chapters by recognition after 1950, so the later cases were found by phrase search. The 1910s peak is the Mexican Revolution chapters (frus1911 alone is 37%). The threads I did not read, with document counts from the same table: Argentina 1943-45 (17 + 36 + 65 = 118), Nicaragua 1947 (40), Ecuador 1944 and 1947 (23 + 14 = 37), Guatemala 1944 (28), El Salvador 1944-45 (39 + 9 = 48), Bolivia 1946 (53), Dominican Republic 1916 (69), Mexico 1920 provisional government (67), Paraguay and Bolivia 1937 (50 + 33 = 83). [N18c] Cases named in the decisions: Brazil 1937, 'continuance of diplomatic relations without formal act of recognition' (frus1937v05, 8 documents); Nicaragua 1925-26, 'Efforts by the United States to preserve constitutional government in Nicaragua' (frus1925v02, 19 documents; frus1926v02, 62 documents; titles that do not use the word recognition, so these are outside set E); Cuba 1933-34, 'Revolution in Cuba' (frus1933v05, 92 + 53 + 161 documents) and 'Recognition of the Provisional Government of Cuba' (frus1934v05, 31 documents) (`SELECT volume_id, COUNT(*), path FROM structure_flat ...` by scripts/headings_latam.py). [N18b] Of the 2,255 documents under these chapters, 50 were among the documents I retrieved (section 10).

[N21] Guatemala in 1954, followed in part. The editors' chapter titles for 1954 do not name recognition, so the case is outside set E. It was found by browse listings of family C (scripts/browse.py with the family C expression, once with --vol frus1952-54Guat and once with --vol frus1952-54v04 and --path guatemala, both limited to 1954; the SELECTs are in queries.log). The Guatemala volume (frus1952-54Guat) has 5 family C documents dated 1954 (24 April, 28 April, 24 May, 19 June and 24 June; by their headers, memoranda of the Central Intelligence Agency, a contact report and cables of the operation's headquarters, and by their snippets documents 135, 163 and 234 speak of recognizing a new government while 133 and 205 use the word in other senses). The American Republics volume (frus1952-54v04) has 15 dated 1954; 6 of them sit under a Guatemala heading (documents 471, 490, 498, 502, 508 and 512), and by their snippets 471 (planning for recognition), 490 and 502 are about recognition of the new government, while 498, 508 and 512 use the word in other senses. Documents 490 and 502 were retrieved whole (section 10) and are in the collection as finding 6; every other 1954 document was seen as a snippet only.

## 5. Candidate families, literal shares and the referent test

[N04] Family C (candidates): scope documents whose text has recognition within six tokens of government, regime, junta or administration (INDEX; the index drops punctuation and reduces words to a common form, so this is a proximity of word forms, not a phrase):

```sql
ATTACH 'file:/Users/jbotts/frus-analysis/c3/runs/r1/work/scope.db?mode=ro' AS s;
SELECT COUNT(*) FROM frus_documents f JOIN s.scope_docs sd ON sd.volume_id=f.volume_id AND sd.document_id=f.document_id WHERE frus_documents MATCH 'NEAR(recogn* government*, 6) OR NEAR(recogn* regime*, 6) OR NEAR(recogn* junta, 6) OR NEAR(recogn* administration*, 6)' AND sd.latam=1 AND sd.numbered=1 AND sd.apparatus=0 AND sd.ed2_dup=0;
```
Result **2,883** (stratum A, hemisphere volumes, 1,241; stratum B, Latin American sections of other volumes, 1,642; from the GROUP BY in scripts/false_friend.py); 2,883 of 57,144 is 5.0%, about one in twenty.

[N05] Literal share for family C (scripts/share_test.py C_recognition_near_government; sample and verdicts in work/shares/C_recognition_near_government.tsv). Hit list: the SQL above with columns `f.volume_id, f.document_id, sd.date_iso` and `ORDER BY f.volume_id, f.document_id` (text order). N = 2,883, which is over 300, so an evenly spaced sample of 40 (indices round(i*(n-1)/39)). Text tested: header + dateline + source_note + body_text, whitespace collapsed, case-insensitive. Both forms are published and labelled. STRICT (exact forms recognition, recognitions, recognize, recognizes, recognized, recognizing and government(s), regime(s), junta(s), administration(s), single spaces and no punctuation between, up to six words between): **37 of 40**. TOLERANT (each word with its inflections, with non- and un- forms and recognise, and any run of space, hyphen, comma, parenthesis or full stop between the words): **40 of 40**. The three strict misses (frus1882/d37, frus1886/d41, frus1981-88v16/d444) are punctuation or inflection cases. A tolerant share of 1.000 tests the word forms, not the referent, so the referent was tested separately by reading the printed passage of each of the 40 (verdicts below): **23 concern recognition or its withholding for a Latin American government (Y), 2 concern recognition of a government in exile (P), 15 use the words in other senses (N)**. About three in five candidates are therefore on the question (23 of 40 is 57.5%; 25 of 40 is 62.5% with the exile cases); a sample of forty gives a wide interval.

| n | volume_id/document_id | judgment | reason (judged by reading the printed snippet; 17 also by reading the whole document) |
|---|---|---|---|
| 1 | frus1861/d307 | N | Chile 1861: states that declined to recognize the Union (U.S. Civil War), not a Latin American government |
| 2 | frus1866p3/d143 | N | recognized government of the State of Apure: domestic Venezuelan state government |
| 3 | frus1872p1/d266 | N | a Mexican state government refusing to recognize Juarez's election: not U.S. recognition |
| 4 | frus1879/d106 | N | government recognizes citizens' right to buy foreign-built ships |
| 5 | frus1882/d37 | N | President "recognizes Peru and Chili to be independent republics" |
| 6 | frus1886/d41 | N | governments "recognize" treaties in force |
| 7 | frus1892/d513 | Y | whether action taken on instructions about recognizing the new government (Venezuela 1892) |
| 8 | frus1899/d789 | Y | Can I recognize the Government just formed? (Venezuela 1899) |
| 9 | frus1904/d227 | Y | correspondence on recognizing the Dominican provisional government |
| 10 | frus1907p2/d83 | Y | Having also recognized the provisional government of Honduras |
| 11 | frus1912/d1425 | Y | whether the U.S. would recognize the new government as a fait accompli |
| 12 | frus1913/d849 | Y | Mexico, Feb 1913: those seeking recognition as the new Provisional Government to be told U.S. wants assurances |
| 13 | frus1914/d594 | Y | No government in Haiti has been recognized by the United States |
| 14 | frus1915/d1445 | Y | your government is not yet recognized (Haiti) |
| 15 | frus1916/d731 | Y | refers to U.S. recognition of the de facto (Carranza) government |
| 16 | frus1919v01/d792 | Y | representing a government "not officially recognized" (Costa Rica) |
| 17 | frus1920v03/d201 | Y | this Government has not recognized the de facto authority in Mexico (read whole) |
| 18 | frus1921v02/d435 | Y | Mexico would be implicitly recognized by relations being re-established |
| 19 | frus1924v02/d426 | Y | Hughes: whether U.S. can "consistently recognize the new administration on January 1" |
| 20 | frus1927v03/d435 | N | a recognized government in a loan comparison (Nicaragua) |
| 21 | frus1930v03/d140 | Y | Guatemala Dec 1930: policy on recognition of new governments in the five Central American republics |
| 22 | frus1931v02/d237 | Y | Costa Rica decides not to recognize the Salvadoran regime |
| 23 | frus1932v05/d653 | Y | reorganizing the Salvadoran Government so recognition can be extended |
| 24 | frus1933v05/d453 | Y | South American states agreeing on recognition of a government in Cuba |
| 25 | frus1934v05/d250 | Y | Guatemala recognizes the government headed by Martinez |
| 26 | frus1936v05/d780 | Y | recognition of a new regime (Paraguay 1936) by Argentina and others |
| 27 | frus1938v05/d611 | N | Haitian Government "recognizes" something due bondholders |
| 28 | frus1941v07/d483 | N | U.S. "recognizes" Uruguay's need to control imports |
| 29 | frus1944v07/d1090 | Y | Recognition of the new Administration in El Salvador will depend in part on its willingness and ability to fulfill its international commitments |
| 30 | frus1944v07/d383 | Y | Argentina extends recognition to the new Bolivian regime |
| 31 | frus1945v09/d1173 | Y | Haiti consulted on recognizing the Venezuelan junta |
| 32 | frus1947v08/d135 | N | coffee agreement |
| 33 | frus1949v02/d309 | N | Argentine Government recognizes losses |
| 34 | frus1952-54v04/d234 | N | Chile economy |
| 35 | frus1958-60v05/d11 | Y | NSC report ("22. Recognition. a. Recognize all Latin American governments qualifying ...") |
| 36 | frus1958-60v06/d613 | P | recognize a government in exile (Cuban exiles 1960): recognition, but of an exile body, not a government that seized power |
| 37 | frus1961-63v11/d141 | N | Soviet Government "must recognize" |
| 38 | frus1964-68v32/d278 | P | recognition of a Cuban government-in-exile: same |
| 39 | frus1969-76ve11p2/d361 | N | government recognized the subject's importance |
| 40 | frus1981-88v16/d444 | N | administration recognized Uruguay as important |

[N06] Family W (non-recognition and withholding language), INDEX:

```sql
SELECT COUNT(*) FROM frus_documents f JOIN s.scope_docs sd ON sd.volume_id=f.volume_id AND sd.document_id=f.document_id WHERE frus_documents MATCH 'nonrecogn* OR "non recogn*" OR unrecogn* OR NEAR(withh* recogn*, 5) OR NEAR(withheld recogn*, 5) OR NEAR(refus* recogn*, 5) OR NEAR(declin* recogn*, 5) OR NEAR(postpon* recogn*, 5) OR NEAR(defer* recogn*, 5)' AND sd.latam=1 AND sd.numbered=1 AND sd.apparatus=0 AND sd.ed2_dup=0;
```
Result **452**. Literal share (same sampling, N = 452, sample of 40, work/shares/W_withholding_recognition.tsv): STRICT **33 of 40**; TOLERANT **37 of 40**. Misses read: two are reversed word order that the proximity query accepts and the pattern does not ("recognition be withheld", frus1931v02/d998; "recognition may be deferred", frus1937v05/d719); one (frus1977-80v15/d363) is unrelated (Salvadorans not recognized as refugees). Referent: **Y 24, P 2 (recognition of belligerency), N 14**. Family W is used only for the decade shape (section 7) and to find documents, not for any number in the overview.

| n | volume_id/document_id | judgment | reason |
|---|---|---|---|
| 1 | frus1861/d307 | N | states that declined to recognize the Union's authority (Civil War) |
| 2 | frus1866p3/d3 | Y | French occupation of Mexico "unrecognized as it was by our government" |
| 3 | frus1868p2/d425 | N | declining to refuse recognition of an individual (agent), not a government |
| 4 | frus1868p2/d632 | Y | President "does not feel authorized to withhold his recognition of the present de facto executive head" (Colombia 1867) |
| 5 | frus1878/d350 | Y | postponement of our recognition for a year and a half (Mexico, Diaz) |
| 6 | frus1881/d583 | N | could not refuse to recognize annexation as a treaty condition |
| 7 | frus1887/d488 | Y | When Barillas made his coup d'etat we considered it prudent to withhold our recognition |
| 8 | frus1893/d110 | P | unrecognized insurgents (Brazil 1893): belligerency, not a government |
| 9 | frus1902/d1022 | N | refusal to recognize a blockade |
| 10 | frus1903/d558 | N | refusal to recognize U.S. citizenship of a Guatemalan |
| 11 | frus1907p1/d92 | N | immigration contract |
| 12 | frus1912/d1055 | P | non-recognition of belligerency (Mexico, Orozco) |
| 13 | frus1913/d524 | N | arbitrator refusing to recognize an Ecuadorean court |
| 14 | frus1914/d1740 | N | Panama declines to recognize a judicial decision |
| 15 | frus1915/d1493 | Y | petition that the U.S. withhold recognition of any Mexican government not granting freedom of worship |
| 16 | frus1916/d238 | Y | Dominican official "whom we refused to recognize" |
| 17 | frus1919v01/d839 | Y | U.S. refusal to recognize Tinoco |
| 18 | frus1921v02/d363 | Y | Austria "refuse the Government of Mexico the recognition" (Obregon chapter) |
| 19 | frus1925v01/d270 | N | Brazil and a boundary |
| 20 | frus1928v01/d394 | Y | non-recognition of the regime in Ecuador; de jure recognition extended to Dr. Ayora's regime |
| 21 | frus1931v02/d1001 | Y | Peru 1931: uprising will postpone recommendation on recognition |
| 22 | frus1931v02/d998 | Y | Peru 1931 junta: "urge recognition be withheld" (a reversed-order form the regular expression does not match) |
| 23 | frus1932v05/d662 | Y | Martinez "concerned regarding nonrecognition" |
| 24 | frus1933v05/d151 | Y | For months we withheld recognition and finally accorded it only after the Chilean Government pledged in writing respect for its international obligations |
| 25 | frus1934v05/d197 | Y | non-recognition of the Martinez regime |
| 26 | frus1935v04/d635 | Y | non-recognition under Article II of the 1923 treaty (Constituent Assembly) |
| 27 | frus1937v05/d719 | Y | Paraguay 1937: recognition "may be deferred" (reversed-order form) |
| 28 | frus1940v05/d328 | N | neutral rights |
| 29 | frus1943v05/d491 | Y | Bolivia 1943: "prolonged period of nonrecognition" |
| 30 | frus1944v07/d217 | Y | Argentina 1944: withhold recognition / non-recognition to secure a break |
| 31 | frus1944v07/d392 | Y | nonrecognition of the Bolivian regime |
| 32 | frus1945v09/d251 | Y | recognition to be extended simultaneously by the non-recognizing republics |
| 33 | frus1947v08/d603 | Y | Nicaragua 1947: "Our withholding recognition now" |
| 34 | frus1951v02/d800 | Y | Guatemala "refuses to recognize de jure" governments of four states |
| 35 | frus1958-60v05mSupp/dr_d10 | Y | planning: withhold U.S. recognition of a successor to Trujillo |
| 36 | frus1961-63v10-12mSupp/d109 | Y | Ecuador 1963: withholding recognition until junta indicates return to civilian government |
| 37 | frus1964-68v31/d303 | N | unrecognizable |
| 38 | frus1969-76ve11p1/d128 | N | exports "recognized" by U.S. |
| 39 | frus1977-80v15/d363 | N | refugees "not recognized" (the tolerant pattern also misses it; unrelated) |
| 40 | frus1981-88v16/d405 | N | unrecognized opposition parties |

## 6. The false-friend test

[N08] Test (scripts/false_friend.py): the share of documents containing each term, by stratum (A = hemisphere volumes, B = Latin American sections of other volumes, C = everything else); INDEX; documents numbered, non-apparatus, no second-edition duplicates. Stratum sizes: `SELECT CASE WHEN sd.lat_basis='hemisphere volume' THEN 'A' WHEN sd.lat_basis='latam section' THEN 'B' ELSE 'C' END, COUNT(*) FROM scope_docs sd WHERE sd.numbered=1 AND sd.apparatus=0 AND sd.ed2_dup=0 GROUP BY 1` gives A 28,686, B 28,458, C 248,294. Each term: `SELECT <stratum>, COUNT(*) FROM frus_documents f JOIN s.scope_docs sd ON sd.volume_id=f.volume_id AND sd.document_id=f.document_id WHERE frus_documents MATCH '<term>' AND sd.numbered=1 AND sd.apparatus=0 AND sd.ed2_dup=0 GROUP BY 1` (the expression for each row is in the table).

| term | kind | A hemisphere volumes | B Latin American sections | C everything else | A/C | B/C |
|---|---|---|---|---|---|---|
| recogn* (any form) | question's own term | 4251 of 28686 (14.8%) | 3604 of 28458 (12.7%) | 40300 of 248294 (16.2%) | 0.91 | 0.78 |
| recognition near government/regime/junta/administration (6) | question's own term | 1241 of 28686 (4.3%) | 1642 of 28458 (5.8%) | 8845 of 248294 (3.6%) | 1.21 | 1.62 |
| nonrecogn* / non recogn* | editors' term | 51 of 28686 (0.2%) | 23 of 28458 (0.1%) | 186 of 248294 (0.1%) | 2.37 | 1.08 |
| revolut* | editors' term | 2132 of 28686 (7.4%) | 2893 of 28458 (10.2%) | 6502 of 248294 (2.6%) | 2.84 | 3.88 |
| coup | editors' term | 809 of 28686 (2.8%) | 135 of 28458 (0.5%) | 2965 of 248294 (1.2%) | 2.36 | 0.40 |
| junta | editors' term | 973 of 28686 (3.4%) | 239 of 28458 (0.8%) | 473 of 248294 (0.2%) | 17.81 | 4.41 |
| overthrow* | editors' term | 927 of 28686 (3.2%) | 488 of 28458 (1.7%) | 2887 of 248294 (1.2%) | 2.78 | 1.47 |
| de facto | editors' term | 278 of 28686 (1.0%) | 665 of 28458 (2.3%) | 2537 of 248294 (1.0%) | 0.95 | 2.29 |
| constitutional government | editors' term | 307 of 28686 (1.1%) | 402 of 28458 (1.4%) | 773 of 248294 (0.3%) | 3.44 | 4.54 |
| provisional government | editors' term | 317 of 28686 (1.1%) | 690 of 28458 (2.4%) | 2262 of 248294 (0.9%) | 1.21 | 2.66 |
| military junta | editors' term | 170 of 28686 (0.6%) | 33 of 28458 (0.1%) | 96 of 248294 (0.0%) | 15.33 | 3.00 |
| CONTROL treati* | control (common word) | 3529 of 28686 (12.3%) | 4031 of 28458 (14.2%) | 38028 of 248294 (15.3%) | 0.80 | 0.92 |
| CONTROL "department of state" | positive control | 7466 of 28686 (26.0%) | 8665 of 28458 (30.4%) | 76848 of 248294 (30.9%) | 0.84 | 0.98 |
| CONTROL ZZZ_IMPOSSIBLE_ZZZ | negative control | 0 of 28686 (0.0%) | 0 of 28458 (0.0%) | 0 of 248294 (0.0%) | n/a (no hits) | n/a (no hits) |

FTS expressions, in order: `recogn*`; `NEAR(recogn* government*, 6) OR NEAR(recogn* regime*, 6) OR NEAR(recogn* junta, 6) OR NEAR(recogn* administration*, 6)`; `nonrecogn* OR "non recogn*"`; `revolut*`; `coup`; `junta`; `overthrow*`; `de facto`; `constitutional government`; `provisional government`; `military junta`; `treati*`; `department of state`; `ZZZ_IMPOSSIBLE_ZZZ`

Reading. The question's own term, recogn*, sits at baseline: 14.8% of stratum A and 12.7% of B against 16.2% elsewhere, the same pattern as the control treati* (12.3% and 14.2% against 15.3%) and the positive control "department of state" (26.0% and 30.4% against 31.0%). [N08b] Pooled, recogn* is in 7,855 of 57,144 Latin American scope documents (13.7%; 4,251 + 3,604) against 40,300 of 248,294 elsewhere (16.2%). By the false-friend rule it measures the corpus, not the question, and it was not used alone as a topic marker. The collocation (family C) is only weakly elevated (4.3% and 5.8% against 3.6%; ratios 1.2 and 1.6), so it was used as a candidate generator and validated by reading (N05), never as a measurement of the topic. The editors' vocabulary is topic-specific (junta 17.8 times in A and 4.4 in B; constitutional government 3.4 and 4.5; military junta 15 and 3; revolut* 2.8 and 3.9).

## 7. Decade shapes (never raw counts alone)

[N19] Method (scripts/decade_table.py). Numerator: `SELECT sd.decade, sd.volume_id, COUNT(*) FROM frus_documents f JOIN s.scope_docs sd ON sd.volume_id=f.volume_id AND sd.document_id=f.document_id WHERE frus_documents MATCH ? AND sd.latam=1 AND sd.numbered=1 AND sd.apparatus=0 AND sd.ed2_dup=0 AND sd.date_iso IS NOT NULL GROUP BY sd.decade, sd.volume_id`. Denominator: `SELECT sd.decade, COUNT(*) FROM scope_docs sd WHERE sd.latam=1 AND sd.numbered=1 AND sd.apparatus=0 AND sd.ed2_dup=0 AND sd.date_iso IS NOT NULL GROUP BY sd.decade`. Rate = hits per 1,000 dated scope documents of the decade; the last column is the top volume and its share of the hits. Periodised on the index's day for frus:doc-dateTime-min (check in section 8), not on the volume's series year.

Family C in the Latin American scope:

```
## C_recognition_near_government  | MATCH NEAR(recogn* government*, 6) OR NEAR(recogn* regime*, 6) OR NEAR(recogn* junta, 6) OR NEAR(recogn* administration*, 6) | scope=latam
decade | hits | dated docs in decade | per 1,000 | volumes | top volume (share of hits)
1860s | 137 | 1968 | 69.6 | 8 | frus1868p2 (0.31)
1870s | 104 | 1528 | 68.1 | 13 | frus1878 (0.20)
1880s | 171 | 2039 | 83.9 | 12 | frus1881 (0.27)
1890s | 117 | 2349 | 49.8 | 16 | frus1899 (0.19)
1900s | 165 | 3084 | 53.5 | 15 | frus1904 (0.18)
1910s | 453 | 10441 | 43.4 | 17 | frus1913 (0.19)
1920s | 295 | 4972 | 59.3 | 24 | frus1920v03 (0.11)
1930s | 520 | 9470 | 54.9 | 16 | frus1932v05 (0.15)
1940s | 432 | 11083 | 39.0 | 14 | frus1944v07 (0.35)
1950s | 156 | 3086 | 50.6 | 10 | frus1952-54v04 (0.27)
1960s | 202 | 3548 | 56.9 | 11 | frus1961-63v10 (0.19)
1970s | 118 | 3185 | 37.0 | 10 | frus1969-76v21 (0.18)
1980s | 13 | 391 | 33.2 | 5 | frus1977-80v24 (0.38)
total hits (dated): 2883
```

Family C over the whole index (same expression, scope filter off; denominators are all dated numbered documents of the decade):

```
## C_recognition_near_government_whole_index  | MATCH NEAR(recogn* government*, 6) OR NEAR(recogn* regime*, 6) OR NEAR(recogn* junta, 6) OR NEAR(recogn* administration*, 6) | scope=whole index
decade | hits | dated docs in decade | per 1,000 | volumes | top volume (share of hits)
1810s | 2 | 100 | 20.0 | 2 | frus1872p2v1 (0.50)
1830s | 2 | 5 | 400.0 | 1 | frus1902app2 (1.00)
1840s | 5 | 139 | 36.0 | 1 | frus1894app2 (1.00)
1850s | 5 | 150 | 33.3 | 3 | frus1872p2v1 (0.40)
1860s | 391 | 11250 | 34.8 | 23 | frus1868p2 (0.13)
1870s | 302 | 5795 | 52.1 | 18 | frus1878 (0.11)
1880s | 334 | 6471 | 51.6 | 15 | frus1881 (0.20)
1890s | 372 | 9711 | 38.3 | 18 | frus1894app2 (0.18)
1900s | 367 | 9924 | 37.0 | 20 | frus1903 (0.11)
1910s | 1433 | 30358 | 47.2 | 45 | frus1913 (0.08)
1920s | 1034 | 19733 | 52.4 | 30 | frus1920v03 (0.08)
1930s | 1383 | 39196 | 35.3 | 51 | frus1931v02 (0.07)
1940s | 3033 | 74049 | 41.0 | 96 | frus1949v09 (0.08)
1950s | 1450 | 42345 | 34.2 | 102 | frus1950v06 (0.05)
1960s | 850 | 27650 | 30.7 | 102 | frus1961-63v10 (0.05)
1970s | 630 | 22258 | 28.3 | 85 | frus1969-76ve07 (0.05)
1980s | 130 | 6038 | 21.5 | 34 | frus1981-88v01 (0.12)
1990s | 1 | 177 | 5.6 | 1 | frus1989-92v31 (1.00)
total hits (dated): 11724
```

Family W in the Latin American scope:

```
## W_withholding_recognition  | MATCH nonrecogn* OR "non recogn*" OR unrecogn* OR NEAR(withh* recogn*, 5) OR NEAR(withheld recogn*, 5) OR NEAR(refus* recogn*, 5) OR NEAR(declin* recogn*, 5) OR NEAR(postpon* recogn*, 5) OR NEAR(defer* recogn*, 5) | scope=latam
decade | hits | dated docs in decade | per 1,000 | volumes | top volume (share of hits)
1860s | 37 | 1968 | 18.8 | 7 | frus1868p2 (0.51)
1870s | 16 | 1528 | 10.5 | 8 | frus1878 (0.31)
1880s | 22 | 2039 | 10.8 | 10 | frus1881 (0.27)
1890s | 17 | 2349 | 7.2 | 10 | frus1891 (0.24)
1900s | 32 | 3084 | 10.4 | 10 | frus1903 (0.25)
1910s | 65 | 10441 | 6.2 | 12 | frus1913 (0.25)
1920s | 34 | 4972 | 6.8 | 15 | frus1927v03 (0.21)
1930s | 85 | 9470 | 9.0 | 14 | frus1932v05 (0.19)
1940s | 73 | 11083 | 6.6 | 12 | frus1944v07 (0.42)
1950s | 16 | 3086 | 5.2 | 6 | frus1958-60v05mSupp (0.25)
1960s | 27 | 3548 | 7.6 | 9 | frus1964-68v31 (0.26)
1970s | 22 | 3185 | 6.9 | 9 | frus1977-80v24 (0.27)
1980s | 6 | 391 | 15.3 | 4 | frus1977-80v24 (0.33)
total hits (dated): 452
```

Reading: family C runs at 33 to 84 per 1,000 in every decade, lowest in the 1970s and 1980s, and no decade is owned by one volume beyond 38%; it is a persistent topic, not a timeline, and in the Latin American scope it runs above the whole-index rate in most decades (for example 1880s 83.9 against 51.6; 1960s 56.9 against 30.7). Family W runs 5 to 19 per 1,000 (the 1860s peak rests on one volume: frus1868p2 holds 51% of that decade's hits). The decade shape is not used as evidence in the overview; the decade tables are here so that nobody reads a raw count as a trend.

## 8. Counting surface: the TEI, and the date check

[N14] Spelling variants cannot be counted in the index (it merges forms), so the volumes' XML was scanned (scripts/tei_scan.py over all 553 files, summarized by scripts/tei_summary.py; output work/tei_summary.txt, work/tei/variants_by_volume.tsv, work/tei/variants_latam_docs.tsv). Counting surface: TEI, tag-stripped and whitespace-collapsed, case-insensitive, per historical-document division (306,148 divisions; the 57,144 scope documents are all among them); BODY excludes footnotes and the source note. The patterns are listed in scripts/tei_scan.py (VARIANTS). Results in the 57,144 scope documents, body and notes together: non-recognition hyphenated 123 documents (164 hits), closed 65 documents (72 hits), spaced 1 (1); de facto with a space 941 documents (hyphenated 2, closed 2); de jure 82; coup d'etat with the acute accent 197 documents, with a plain e 70; golpe 59; junta 1,212; recognise (British -s-) 16 documents; Spanish reconoc- 11 documents. Recognition within six words of government, regime, junta or administration, either order: any **2,832** scope documents, in the BODY **2,759**, only in footnotes or the source note **73** (73 of 2,832 is 2.6%, about one in forty). The index (N04) counts 2,883 for the same idea; the two surfaces differ (the index also matches inflections and ignores punctuation), and the overview uses the index figure for the candidate set and the TEI figures only for the variant split. Full output:

```
volumes scanned: 553 | historical-document divs: 306148
== whole-corpus totals by variant (hits, documents containing it), all 553 volumes, body+notes
  recognition_noun                   hits    27750  docs   15861
  recognize_verb_z                   hits    62309  docs   38769
  recognise_verb_s                   hits     1895  docs     950
  unrecognized_z                     hits      203  docs     177
  unrecognised_s                     hits        7  docs       5
  nonrecognition_hyphen              hits      615  docs     500
  nonrecognition_closed              hits      299  docs     227
  nonrecognition_spaced              hits        4  docs       3
  non_recognition_emdash_or_other    hits        0  docs       0
  de_facto_space                     hits     4887  docs    3478
  de_facto_hyphen                    hits       16  docs      12
  defacto_closed                     hits       40  docs      28
  de_jure_space                      hits      929  docs     682
  de_jure_hyphen                     hits        0  docs       0
  coup_detat_acute_straight          hits      881  docs     650
  coup_detat_plain_e                 hits      456  docs     338
  coup_alone                         hits     9189  docs    3963
  golpe                              hits      100  docs      59
  junta                              hits     4977  docs    1689
  revolution_family                  hits    25380  docs   11483
  reconocimiento_spanish             hits       58  docs      24
  CTRL_pos_department_of_state       hits   146112  docs   92408
  CTRL_neg_zzz                       hits        0  docs       0
  PH_recog_gov_6                     hits    10168  docs    7107
  PH_gov_recog_6                     hits     8473  docs    6774
  PH_withhold_recog                  hits     1510  docs    1335
positive control 'department of state': volumes with zero hits: 2 ['frus1919Parisv05', 'frus1919Parisv13']
negative control: total hits 0
== Latin American scope documents scanned: 57144
  variant                             body hits notes hits | docs: body-only / notes-only / both
  recognition_noun                         5157        214 | 2698 / 81 / 88  (documents with any: 2867)
  recognize_verb_z                        10108        139 | 6116 / 86 / 45  (documents with any: 6247)
  recognise_verb_s                           20          0 | 16 / 0 / 0  (documents with any: 16)
  unrecognized_z                             37          2 | 35 / 2 / 0  (documents with any: 37)
  unrecognised_s                              0          0 | 0 / 0 / 0  (documents with any: 0)
  nonrecognition_hyphen                     158          6 | 117 / 6 / 0  (documents with any: 123)
  nonrecognition_closed                      69          3 | 62 / 3 / 0  (documents with any: 65)
  nonrecognition_spaced                       1          0 | 1 / 0 / 0  (documents with any: 1)
  non_recognition_emdash_or_other             0          0 | 0 / 0 / 0  (documents with any: 0)
  de_facto_space                           1455         20 | 922 / 14 / 5  (documents with any: 941)
  de_facto_hyphen                             2          0 | 2 / 0 / 0  (documents with any: 2)
  defacto_closed                              2          0 | 2 / 0 / 0  (documents with any: 2)
  de_jure_space                             112          3 | 79 / 3 / 0  (documents with any: 82)
  de_jure_hyphen                              0          0 | 0 / 0 / 0  (documents with any: 0)
  coup_detat_acute_straight                 247         14 | 183 / 13 / 1  (documents with any: 197)
  coup_detat_plain_e                         78          4 | 66 / 3 / 1  (documents with any: 70)
  coup_alone                               2164        239 | 777 / 55 / 108  (documents with any: 940)
  golpe                                      95          5 | 56 / 1 / 2  (documents with any: 59)
  junta                                    3488        335 | 986 / 84 / 142  (documents with any: 1212)
  revolution_family                       11561        698 | 4354 / 444 / 216  (documents with any: 5014)
  reconocimiento_spanish                      9          2 | 9 / 2 / 0  (documents with any: 11)
  CTRL_pos_department_of_state            15623       6996 | 11034 / 3157 / 1810  (documents with any: 16001)
  CTRL_neg_zzz                                0          0 | 0 / 0 / 0  (documents with any: 0)
  PH_recog_gov_6                           2808        134 | 1821 / 70 / 51  (documents with any: 1942)
  PH_gov_recog_6                           2051         32 | 1577 / 24 / 7  (documents with any: 1608)
  PH_withhold_recog                         358         10 | 301 / 9 / 1  (documents with any: 311)
scope documents with any recognition-family word (TEI, body+notes): 7872
scope documents with recognition within six words of government/regime/junta/administration: any 2832 | in the body 2759 | only in footnotes/source note 73
```

[N15] Periodisation check (scripts/date_check.py): the index's day (document_dates.date_iso, copied into scope_docs) against the first ten characters of frus:doc-dateTime-min read from the XML for all 57,144 scope documents: same day 56,499; different day 645; different decade 0; no date on either side 0. So every decade table is the same on either date.

## 9. What the request cannot get from FRUS: the searches

[N09] Internal reasoning. Family C documents in the Latin American scope, by decade, with a header test for internal memoranda, papers and minutes (INDEX; headers can begin with a document number, hence the leading %; LIKE is case-insensitive for ASCII):

```sql
SELECT sd.decade, COUNT(*) AS candidate_docs, SUM(c.header LIKE '%Memorandum%' OR c.header LIKE '%Paper Prepared%' OR c.header LIKE '%Minutes%' OR c.header LIKE '%Summary of Conclusions%' OR c.header LIKE '%Briefing%') AS internal FROM frus_documents f JOIN s.scope_docs sd ON sd.volume_id=f.volume_id AND sd.document_id=f.document_id JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id WHERE frus_documents MATCH 'NEAR(recogn* government*, 6) OR NEAR(recogn* regime*, 6) OR NEAR(recogn* junta, 6) OR NEAR(recogn* administration*, 6)' AND sd.latam=1 AND sd.numbered=1 AND sd.apparatus=0 AND sd.ed2_dup=0 AND sd.date_iso IS NOT NULL GROUP BY 1 ORDER BY 1;
```
Result by decade (candidates / internal): 1860s 137/0; 1870s 104/1; 1880s 171/0; 1890s 117/1; 1900s 165/0; 1910s 453/4; 1920s 295/13; 1930s 520/46; 1940s 432/73; 1950s 156/79; 1960s 202/124; 1970s 118/60; 1980s 13/4. So 1861-1919: **6 of 1,147** (0+1+0+1+0+4 of 137+104+171+117+165+453); 1950-79: **263 of 476** (79+124+60 of 156+202+118), 55%. Controls: the same header test finds 58,391 'Memorandum' headers across the whole index (positive) and 0 for a phrase that cannot occur (negative). Shelf: the instruction and despatch series for the early period and, from 1910, the Central Decimal File (section 11).

[N13] Doctrine labels (INDEX; phrase queries; counts over numbered non-apparatus documents): 

```sql
SELECT SUM(sd.latam=1) AS in_latam_scope, COUNT(*) AS whole_index FROM frus_documents f JOIN s.scope_docs sd ON sd.volume_id=f.volume_id AND sd.document_id=f.document_id WHERE frus_documents MATCH '"estrada doctrine"' AND sd.numbered=1 AND sd.apparatus=0 AND sd.ed2_dup=0;
```
run for each phrase. Results (scope | whole index): "estrada doctrine" 25 | 28; "tobar doctrine" 1 | 1; "betancourt doctrine" 3 | 3; "mann doctrine" 0 | 0; "wilson doctrine" 0 | 0 (the positive control is the first phrase, which returns rows). Literal shares, whole sets under 300 (scripts/share_test.py, files work/shares/X_*.tsv): Estrada STRICT 24 of 25 and TOLERANT 24 of 25 (the miss, frus1945v09/d55, prints "Estrada" in quotation marks before 'doctrine'); Tobar 1 of 1; Betancourt 3 of 3. 'Larreta' and other bare surnames were not scanned. Spanish recognition vocabulary: `... frus_documents MATCH 'reconoc*'` gives 11 in the scope and 24 in the whole index; the TEI finds 11 scope documents with reconoc- (9 body hits, 2 note hits). Foreign ministries' files (JSON): `grep -l -i -E "Relaciones Exteriores|Itamaraty|Cancill|Foreign Ministry|Ministry of Foreign|Ministerio de Relaciones" "/Applications/FRUS Explorer.app/Contents/Resources/"*.json` lists keyness-baseline-printed.json, keyness-baseline.json and person-authority-index.json only, that is, the word-frequency tables and the registry of persons; no archival finding aid in the bundle names those files (the search covers these six names and spellings, not every possible one).

[N03c] The 1980s. Dated scope documents: 391 in the 1980s against 3,185 in the 1970s (section 3); family C has 13 hits in the 1980s (section 7).

[N22] The shelf for the 1980s (JSON, presidential-library-catalog.json, libraries[9], citedAs 'Reagan Library'; the inline lookups are in queries.log, after the grep for 'Reagan'). Collection RR-0313, 'Records of the National Security Council, Latin American Affairs Directorate (Reagan Administration)', NAID 12024796, has 11 series with inclusive dates between 1983 and 1989 (General Office Files 1983-1989 NAID 12025085; Jacqueline Tillman's files 1984-1988; Constantine C. Menges' Office Files 1983-1985; Ludlow Flower's Country Files 1987-1988; others). Collection RR-WHORM, 'White House Office of Records Management File Systems (White House Central Files)', NAID 1191, has series 'Subject Files on South America, Central and Latin America' (NAID 6207697), 'on the Argentine Republic' (6210141), 'on the Republic of Bolivia' (6210163), 'on Chile' (6210421), 'on the Republic of El Salvador' (6211313), 'on the Republic of Guatemala' (6235174), 'on the Republic of Honduras' (6235187), 'on Nicaragua' (6282791) and 'on the Republic of Panama' (6282797), all inclusive 1981-1989. series-facts-index.json (byNaId) has no row for any of these NAIDs, so the bundle gives no access status, extent or creator heading for them. Nothing here says that recognition decisions are in these series; they are the Latin American units the finding aids name for the decade, and the creator headings were not verified (the brief warns that NARA's creator attribution is unreliable).

## 10. What was read, and the quotations

[N17] Reading accounting. Every document retrieved was fetched with an explicit statement `SELECT volume_id, document_id, header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id = ? AND document_id = ?` (scripts/readdocs.py; one logged line per retrieval), written to raw/<volume>__<document>.body.txt (exactly body_text) and .meta.txt (header, dateline, source note), and checked: captured length in characters equals length(body_text). Ledger: work/reading_ledger.tsv (one line per retrieval). Totals (computed by the assembler from the ledger): 106 distinct documents retrieved (113 retrievals in the ledger), all 106 whole (captured length equal to length(body_text) in characters; 385,342 characters in all); 96 printed to the screen in full at least once and 10 only in part (the opening plus windows around the recognition words; the full text is on disk); 105 of the 106 are inside the Latin American scope; all 45 cited documents were retrieved whole, 39 of them printed in full and 6 in part (frus1913/d1028, frus1948v09/d74, frus1958-60v05/d11, frus1961-63v10-12mSupp/d137, frus1964-68v31/d132, frus1969-76v21/d361); 17 documents are quoted (19 quotations). Documents retrieved that sit under the editors' recognition chapters: 50 of 2,255. The summary_text and note_text columns were never selected.

[N07] The cited set. 45 documents (work/cited_docs.tsv, loaded into scope.db as table cited by scripts/load_cited.py, which checked each pair with `SELECT is_front_matter, is_editorial_note, document_number FROM document_cache WHERE volume_id = ? AND document_id = ?`: all 45 exist, none is front matter or an editorial note, all are numbered). By finding: 5, 8, 9, 5, 9 and 9 documents (findings 1 to 6). 17 of the 45 are quoted and carry 19 quotations; the other 28 are cited in the text and appear in the collection with a note. No document appears twice and no volume ends in Ed2.

The 19 quotations used in the overview and as excerpts in the collection. Each is the exact substring of body_text between a start marker and an end marker (scripts/extract_quotes.py), found exactly once, with no line break; the retrieval is `SELECT body_text FROM document_cache WHERE volume_id = '<volume>' AND document_id = '<document>'`, logged once per quotation in queries.log. The collection builder re-checks every excerpt with the same SELECT (scripts/build_collection.py) and the checker confirms the overview's block quotations equal the collection's excerpts (scripts/check_overview.py). The numbering runs Q01 to Q20 without Q04: Q04 was a passage of frus1949v02/d489 that was extracted and checked, then left out of the overview, and its number was not reused.

- [Q01] frus1900/d530 (447 characters, finding 1): “the rule of the United States is to defer recognition of another executive in its place until it shall appear that it is in possession of the machinery of the state, administering government with the assent of the people thereof and without substantial resistance to its authority, and that it is in a position to fulfill all the international obligations and responsibilities incumbent upon a sovereign state under treaties and international law.”
- [Q02] frus1948v09/d7 (295 characters, finding 1): “(a) de facto control of the territory and the administrative machinery of State, including the maintenance of public order; (b) the ability and willingness of a government to discharge its international obligations; (c) general acquiescence of the people of a country in the government in power.”
- [Q03] frus1948v09/d7 (162 characters, finding 1): “Recognition should not be withheld as a political weapon or to express moral censure except in extreme cases when U.S. national interests would be served thereby.”
- [Q05] frus1949v02/d489 (172 characters, finding 1): “This Government, furthermore, is of the opinion that nonrecognition is seldom, if ever, effective in bringing about the broader aim of strengthening democratic governments.”
- [Q06] frus1913/d7 (169 characters, finding 2): “just government rests always upon the consent of the governed, and that there can be no freedom without order based upon law and upon the public conscience and approval.”
- [Q07] frus1931v02/d232 (325 characters, finding 2): “The Department has stated on various occasions that the policy of the Government of the United States in its dealings with the Central American republics is to be guided by the principles established in the Treaty of 1923. The United States Government, therefore, will not recognize General Martínez as President of Salvador.”
- [Q08] frus1936v05/d109 (241 characters, finding 2): “Under our new policy, if General Somoza headed a régime which effectively governed the country and fulfilled its international obligations we would extend recognition to him regardless of his eligibility to recognition under the 1923 Treaty.”
- [Q09] frus1877/d222 (331 characters, finding 3): “In the present case it waits before recognizing General Diaz as the President of Mexico until it shall be assured that his election is approved by the Mexican people, and that his administration is possessed of stability to endure and of disposition to comply with the rules of international comity and the obligations of treaties.”
- [Q10] frus1932v05/d518 (645 characters, finding 3): “You are correct in your understanding that the policy of this Government is not to associate recognition with the particular type of government or political institution which the people may decide to adopt. In this connection there is a two-fold criterion: First, that there should be no discrimination in the protection which must be accorded to the nationals of other countries and their property, to both of which must be accorded a degree of protection at least as high as that given to the natives of the country, and secondly, that this standard of protection must not fall below the minimum standard set by international law and practice.”
- [Q11] frus1961-63v12/d359 (481 characters, finding 4): “to secure their agreement prior to our recognition or resumption of aid on following main points: 1. Free political activity of all non-Communist parties in preparation for OAS supervised elections in not more than one year, with provision for drafting new constitution thereafter. 2. Restoration of some semblance of constitutionality to present regime and recognition of normal role of PRD in DomRep by substituting for one member of the triumvirate Juan Casasnovas as President.”
- [Q12] frus1944v07/d388 (249 characters, finding 5): “You should indicate to the Minister of Foreign Affairs that the available evidence indicating foreign involvement in the Bolivian revolt is considered here to be very strong and that it is unlikely that this government will recognize the new regime.”
- [Q13] frus1944v07/d1090 (259 characters, finding 5): “Recognition of the new Administration in El Salvador will depend in part on its willingness and ability to fulfill its international commitments, including that to the other American Republics not to recognize unilaterally the present Government of Argentina.”
- [Q14] frus1948v09/d115 (172 characters, finding 5): “(d) In the light of the above, it seems evident to us that non-recognition is not a suitable weapon for influencing the course of internal events in Venezuela at this time.”
- [Q15] frus1955-57v06/d354 (143 characters, finding 6): “While fully appreciating significance of fair and free elections Department would prefer recognition independent of election pledge from Junta.”
- [Q16] frus1955-57v06/d354 (234 characters, finding 6): “does not wish to find itself recognizing a new de facto regime every few weeks and would like reasonable assurance that Junta is actually in effective control of country as well as ready to abide by nation’s international obligations.”
- [Q17] frus1964-68v31/d518 (145 characters, finding 6): “The Military Government is in full control, and no significant opposition has materialized. It has met all the traditional tests for recognition.”
- [Q18] frus1969-76v21/d361 (69 characters, finding 6): “Right now would be a good time. They have satisfied the requirements.”
- [Q19] frus1934v05/d85 (189 characters, finding 4): “This Government will recognize a Cuban provisional Government which is substantially supported by the Cuban people and is able to maintain law, order and the normal functions of Government.”
- [Q20] frus1921v02/d344 (200 characters, finding 3): “In short, when it appears that there is a government in Mexico willing to bind itself to the discharge of primary international obligations, concurrently with that act its recognition will take place.”

## 11. Archival scope: two channels, never summed

Volume sets are named in each line. CAME-FROM = the source note printed with the document (document_sources, one row per document; JSON collection-usage-index.json counts the same notes by volume). POINTED-AT = what a footnote cites without printing (external_citations, many rows per document; it holds lot, library and decimal-class anchors only, stores the citation fragment rather than the sentence, and has no row before 1910-12-06). The two are different questions and are not added.

[N10] CAME-FROM, candidates (family C, 2,883 documents; INDEX):

```sql
SELECT ds.citation_era, ds.repository, ds.record_group, CASE WHEN ds.citation_era='decimal' THEN '(file number)' ELSE ds.series_name END AS series, COUNT(*) AS documents FROM frus_documents f JOIN s.scope_docs sd ON sd.volume_id=f.volume_id AND sd.document_id=f.document_id LEFT JOIN document_sources ds ON ds.volume_id=f.volume_id AND ds.document_id=f.document_id WHERE frus_documents MATCH 'NEAR(recogn* government*, 6) OR NEAR(recogn* regime*, 6) OR NEAR(recogn* junta, 6) OR NEAR(recogn* administration*, 6)' AND sd.latam=1 AND sd.numbered=1 AND sd.apparatus=0 AND sd.ed2_dup=0 GROUP BY 1,2,3,4 ORDER BY documents DESC;
```
Result: decimal file numbers (Department of State, Record Group 59) **1,874**; no source-note row **671** (by decade of the document: 1860s 135, 1870s 102, 1880s 171, 1890s 117, 1900s 127, 1910s 17, 1940s 2, so **652 before 1910**; query: the same join with `AND NOT EXISTS (SELECT 1 FROM document_sources ds WHERE ds.volume_id=f.volume_id AND ds.document_id=f.document_id) GROUP BY sd.decade`); everything else 338, the largest being Central Intelligence Agency files 44, Department lot files 41 (+4 +2 under other labels), Nixon NSC Files 26, Carter Library National Security Affairs 18, Kennedy Library National Security Files 17, subject-numeric Central Files 1964-66 16, 1967-69 11 and 1970-73 6, Johnson Library National Security File 12, Eisenhower Library Whitman File 9. 1,874 of 2,883 is 65%, about two in three; 671 of 2,883 is 23%, nearly a quarter.

CAME-FROM, the 45 cited documents (work/scope.db table cited; `SELECT COALESCE(ds.citation_era,'(none)'), ds.repository, ds.record_group, CASE WHEN ds.citation_era='decimal' THEN '(decimal file number)' ELSE ds.series_name END, COUNT(*) FROM cited c LEFT JOIN document_sources ds ON ds.volume_id=c.volume_id AND ds.document_id=c.document_id GROUP BY 1,2,3,4`): decimal file number **30**; no source note 4 (frus1877/d222, frus1878/d344, frus1900/d530, frus1948v09/d74); lot file 2 (frus1948v09/d115, frus1958-60v05/d11); presidential-library or National Archives structured citations 5 (Eisenhower Library Project Clean Up Records; Johnson Library National Security File; Kennedy Library National Security Files; Nixon Presidential Materials NSC Files; and National Archives RG 59 Central Files 1964-66 for frus1964-68v31/d152); subject-numeric 4 (POL 16 DOM REP; POL 26 DOM REP; POL 2 GUAT; Central Files 1964-66 POL 23-9 ARG). 30 + 4 + 2 + 5 + 4 = 45.

CAME-FROM, volume level, the 46 hemisphere volumes (JSON collection-usage-index.json; scripts/usage_rank.py): 28,679 source notes; by category centralDecimalFile 21,188, presidentialLibrary 2,887, centralForeignPolicyFile 1,134, lotFile 968, intelligence 833, subjectNumericFile 714, naraCollection 462, namedFileSeries 368; largest named collections Central Files 1,733, Carter Library National Security Affairs 631, Nixon NSC Files 587, Kennedy Library National Security Files 396, Johnson Library National Security File 368, Central Files 1970-73 259, 1964-66 190, 1967-69 158, Whitman File 149.

[N11] POINTED-AT, candidates (volume set: the 2,883):

```sql
SELECT COUNT(DISTINCT f.volume_id||'/'||f.document_id) FROM frus_documents f JOIN s.scope_docs sd ON sd.volume_id=f.volume_id AND sd.document_id=f.document_id JOIN external_citations ec ON ec.volume_id=f.volume_id AND ec.document_id=f.document_id WHERE frus_documents MATCH 'NEAR(recogn* government*, 6) OR NEAR(recogn* regime*, 6) OR NEAR(recogn* junta, 6) OR NEAR(recogn* administration*, 6)' AND sd.latam=1 AND sd.numbered=1 AND sd.apparatus=0 AND sd.ed2_dup=0;
```
Result **208** of 2,883 (7.2%, about one in fourteen). By anchor (same join, `GROUP BY ec.anchor`): centralFileClass 214 rows in **148** documents (dated 1912-05-08 to 1962-11-03), lotFile 56 rows in **34** documents (1950-01-04 to 1980-05-26), presidentialLibrary 51 rows in **36** documents (1955-09-23 to 1980-09-04); a document can carry more than one kind, so 148 + 34 + 36 exceeds 208. Editors' recognition chapters (E, 2,257 ids): 63 rows in 55 documents, all centralFileClass. Cited set: 5 of 45 documents carry a row, 11 rows in all (frus1944v07/d432, frus1952-54v04/d490, frus1952-54v04/d502, frus1955-57v06/d354 and frus1958-60v06/d217, all centralFileClass). Earliest footnote citation (`SELECT MIN(dd.date_iso), COUNT(*), COUNT(DISTINCT ec.volume_id||'/'||ec.document_id) FROM external_citations ec JOIN document_dates dd ON dd.volume_id=ec.volume_id AND dd.document_id=ec.document_id`): 1910-12-06, 50,173 rows in 32,419 documents in the whole index; the same query joined to the Latin American scope gives 1910-12-06, 5,169 rows in 3,490 documents; the earliest among the family C candidates is 1912-05-08. Lot files cited by the candidates (the family C join with `ec.anchor='lotFile'`, `GROUP BY ec.lot_file_norm`): 38 distinct lot numbers in the 34 documents; central-files-index.json resolves 32 of the 38 (not found: 61 D 386, 62 D 230, 64 D 559, 64 D 560, 69 D 371, 69 D 665), and the creator heading of the resolved series names the Bureau of Inter-American Affairs for 20 of the 32 (the other 12: Executive Secretariat, Office of the Secretary, Deputy Secretary, Policy Planning Council, the Embassy at Panama, the GATT delegation at Torquay, the Near Eastern bureau (60 D 533, the mismatch flagged in section 11) and the Bureau of Human Rights) - scripts/pointed_at_lots.py; creator headings are NARA's and were not otherwise verified. Whole Latin American scope for comparison (`SELECT ec.anchor, COUNT(*), COUNT(DISTINCT ec.volume_id||'/'||ec.document_id) FROM external_citations ec JOIN scope_docs sd ON sd.volume_id=ec.volume_id AND sd.document_id=ec.document_id WHERE sd.latam=1 AND sd.numbered=1 AND sd.apparatus=0 AND sd.ed2_dup=0 GROUP BY 1`): centralFileClass 3,023 rows in 2,166 documents, lotFile 859 in 659, presidentialLibrary 1,287 rows in 896 (Carter 699, Johnson 271, Kennedy 108, Eisenhower 107, others).

[N12] JSON resolution of the series named in the overview (scripts/resolve_archival.py and scripts/claimants_62d1.py for the lots: central-files-index.json lotFiles by lotNumber, series-facts-index.json byNaId with its legend, lot-claimants-index.json; scripts/library_curated_lookup.py, scripts/library_catalog_lookup.py and scripts/library_facts_lookup.py for the presidential libraries: curated-library-resolutions.json, presidential-library-catalog.json, series-facts-index.json). A late pass over the libraries corrected the first one, which had read the curated file only: the catalog gives collection and series identifiers and dates for the Kennedy, Johnson and Nixon files, and the first pass had also spelled the Nixon repository 'Nixon Presidential Materials' where the curated file has 'Nixon'. What the files say, nothing added:

| lot as printed | NARA series (title) | NAID | RG | entry | inclusive dates | access status | note |
|---|---|---|---|---|---|---|---|
| 64 D 563 (PPS Papers) | Numbered Staff Studies (one of 12 claimant series) | 1151288 | 59 | A1 558-A | 1947-1949 | Unrestricted | lot-claimants lists 12 series (Chronological Files 1136548 A1 558-D unrestricted 1947-1962; Subject Files 1151314; Country Files 1151315; Record Copies Files 1151881; Member Chronological Files 1154560; Working Papers 1154562; Meeting Minutes 1154583; Area Files 7432703; Notes of Meetings 7433609; Records Relating to Meetings with the Department of Defense and the Joint Chiefs of Staff 7433611; Speeches and Articles 7433905). The bundle cannot say which holds PPS/24; "the staff studies are the likeliest" is my inference |
| 62 D 1 (NSC files), claimant 1 of 3 | Alphabetical Files | 2198167 | 59 | A1 1583A, A1 1583B | 1948-1961 | Restricted - Partly ((b)(1)) | creator heading Department of State. Policy Planning Council; extent 48 linear feet 7 linear inches; lot-claimants-index.json lists three series for the lot (scripts/claimants_62d1.py) |
| 62 D 1 (NSC files), claimant 2 of 3 | Numerical Files | 2838991 | 59 | A1 1583C, A1 1583D | 1947-1961 | none in the bundle (no series-facts row) | the cited document (frus1958-60v05/d11) is a numbered policy paper, 'NSC 5902 Series', so this is the likeliest home: my inference, which the data does not settle |
| 62 D 1 (NSC files), claimant 3 of 3 | Records Relating to Activities with the National Security Council | 2838992 | 59 | A1 1583E, A1 1583F | 1948-1961 | Restricted - Partly ((b)(1)) | the series central-files-index.json names for the lot; creator heading Policy Planning Council, while the footnote printed in frus1958-60v05/d11 reads "S/S-NSC Files" (the Executive Secretariat): the creator headings were not verified as on-topic and no claimant is called the answer |
| 59 D 573 and 61 D 279 (Rubottom Files) | Subject Files, Office of the Assistant Secretary for Inter-American Affairs | 2108779 | 59 | A1 1135 | 1957-1959 | Unrestricted | both lot numbers resolve to the same series |
| 63 D 127 (ARA/OAP Files) | Subject and Country Files, Office of Central American and Panamanian Affairs | 2363840 | 59 | A1 3157 | 1955-1963 | Restricted - Possibly | bureau matches; the printed office abbreviation differs |
| 64 D 16 (ARA/OAP Files, "Junta Correspondence: El Salvador, 1960") | Records Relating to El Salvador, Office of Central American Affairs | 1750062 | 59 | A1 3159 | 1958-1975 | Restricted - Partly ((b)(1)) | country matches |
| 70 D 247 (ARA/EP/E Files, POL 15 Arosemena Government) | Subject Files Relating to Ecuador, Office of Andean Affairs | 26309336 | 59 | A1 5741; UD-16D 21, 31, 61 | inclusive 1964-1978 (coverage 1963-1978) | Restricted - Partly ((b)(1)) | country matches |
| Johnson Library, National Security File, Country File (frus1964-68v31/d152, d518) | National Security Files (LBJ-NSF) with the catalog series Latin America Country Files | collection 567979; series 567985 | | | 1963-1969 | not in the bundle (no series-facts row) | presidential-library-catalog.json (scripts/library_catalog_lookup.py); curated-library-resolutions.json gives the library's folder title list for Country File, naId null |
| Kennedy Library, National Security Files, Countries Series (frus1961-63v10-12mSupp/d109) | Papers of John F. Kennedy: Presidential Papers: National Security Files (JFK-4) with the catalog series Country Files | collection 1164; series 193236 | | | 1961-1963 | not in the bundle (no series-facts row) | catalog; the curated resolution is the library's one finding aid for the sub-collection, naId null. The first pass of this run reported no identifier because it read the curated file only |
| Carter Library, National Security Affairs | National Security Advisor (Brzezinski and Staff Material), parent collection 560131 per the curated rationale | none for the sub-collections | | | | not in the bundle | not cited among the 45 documents |
| Nixon Presidential Materials, NSC Files, NSC Institutional Files (H-Files) (frus1969-76v21/d361) | National Security Files (Nixon Administration) (RN-NSF) with the catalog series Institutional Files | collection 572235; series 572247 | | | 1969-1974 | not in the bundle (no series-facts row) | catalog; the curated file has entries for NSC Files and for NSC Institutional Files (H-Files) (library pages, naId null; 105 feet, boxes H-1 to H-315). That the catalog's Institutional Files are the cited H-Files is my inference from the names. The first pass reported no resolution because it searched the repository name 'Nixon Presidential Materials', which the file spells 'Nixon' |
| Eisenhower Library, Project "Clean Up" Records (frus1958-60v06/d217) | none | | | | | | no curated entry and no catalog title containing 'Clean Up' (scripts/library_catalog_lookup.py, scripts/library_curated_lookup.py); unresolved |

Flags found while resolving (data quality, not findings): (i) lot 60 D 533 resolves in central-files-index.json to "Subject Files Relating to Iran" (NAID 2124188, Office of Greek, Turkish and Iranian Affairs) although the footnote that cites it reads "Rubottom Files, Lot 60 D 533": a creator mismatch, so it was not used. (ii) Lot 60 D 665 resolves to "Records Relating to the Inter-American Cultural Council and the Committee for Cultural Action" (NAID 2660902) while the footnotes call it "OAS Files": off-topic for recognition and not used. (iii) document_sources has lot_file "No" for frus1948v09/d115 (a mis-parse of "Lot No. 64-D-563"); the lot was read from raw_text. (iv) Central Decimal File: decimal-class-labels.json glosses the keys (below) but no bundled file carries a NARA series identifier, entry or access status for the 1910-1963 file or for the subject-numeric files, and none is given in the overview. (v) Microfilm series for the nineteenth-century instructions (central-files-index.json countrySeries, categories diplomaticInstructions and diplomaticDespatches): Diplomatic Instructions series NAID 593313, "Volume 19: Mexico: May 7, 1873 - June 19, 1879" roll NAID 149324017, "Volume 19: Colombia: Nov. 1, 1898 - Aug. 8, 1906" roll NAID 149302787; Diplomatic Despatches series NAID 603720 (for example Mexico, Volume 57 and 58, August 26, 1876 - April 1, 1877, roll NAID 189125561; Colombia, Sept. 7, 1900 - Jan. 31, 1902, roll NAID 189300896). The bundle gives no access status for them. They are placed by country and date only; the printed volumes carry no source note for these documents. (vi) The Numerical File on microfilm (central-files-index.json numericalFile: microfilm M862, series NAID 654171, 1,261 rolls indexed by case number; the bundle gives no dates for it, so the overview names it as a shelf without dating it; scripts/numerical_file_peek.py).

Decimal keys of the cited documents (decimal-class-labels.json; a key is glossed only when the document's own date is inside a glossable span, 1910-1963; scripts/gloss_cited.py output in queries.log runs): class 8 "Internal Affairs of States" with the country number and subject .00 "Political affairs" or .01 "Government" for 824.00 (Bolivia), 824.01 (Bolivia), 816.01 (El Salvador), 817.00 (Nicaragua), 818.00 (Costa Rica), 825.00 (Chile), 831.01 (Venezuela), 835.00 and 835.01 (Argentina), 837.00 (Cuba), 838.51 (Haiti, "Financial conditions"), 812.00 (Mexico) under the 1910-1949 schedule; 738.00 (Haiti), 714.00 and 714.02 (Guatemala) are class 7 "Internal Political and National Defense Affairs" under the 1950-1959 schedule, which the table glosses for class and country only. Class 7 keys of the 1910-1949 schedule (710.11, 711.38, 711.1211) are compound and name a second country, which the table does not express, so only the first is read. Subject-numeric keys (subject-numeric-labels.json): POL 16 "INDEPENDENCE. RECOGNITION." and POL 26 "REBELLION. COUPS. INSURGENCY." in the Records Classification Handbook of March 1963; POL 23-9 "Rebellion. Coups." (under INTERNAL SECURITY. COUNTER-INSURGENCY.) in the 1965 handbook.

## 12. Corrections made during the run

[N20] Errors of mine, found and fixed, with the decisive query on both sides.

| item | before the fix | after the fix | decisive query |
|---|---|---|---|
| tolerant pattern of the literal-share test for family C | TOLERANT 35 of 40 (below STRICT 37 of 40, impossible for a superset: the pattern `recogni[sz]\w*` does not match "recognition") | TOLERANT 40 of 40 with `recogni(?:tion\w*|[sz]\w*)` | scripts/share_test.py C_recognition_near_government, run twice, both runs logged in queries.log |
| snippet patterns in scripts/browse.py, scripts/chapter_docs.py, scripts/readdocs.py | documents that use only the noun "recognition" were dropped from the lists I read | re-run with --newonly for 1861-1924, 1925-1937 and 1937-1989; the new lists surfaced frus1925v02/d498, frus1914/d567, frus1937v05/d265 and others, later read and cited | the three browse runs with --newonly in queries.log |
| TEI scan phrase patterns (PH_*) | same flaw; first run stopped at volume 1961-63v09 and its outputs moved to work/tei_old_partial/ | scan re-run from scratch over all 553 volumes | work/tei_scan.out, work/tei/ |
| lemma/proximity expression for family W | FTS error "syntax error near (" when OR groups were put inside NEAR | each NEAR written separately | scripts/decade_table.py W_withholding |
| Kennedy Library National Security Files, identifier | "no NARA identifier": the first archival pass read curated-library-resolutions.json only (the resolve_archival.py line in queries.log with the argument 'Kennedy Library\|National Security Files') | NARA 1164 (collection) and 193236 (Country Files, 1961-1963) from presidential-library-catalog.json; the curated entry still has naId null | scripts/library_curated_lookup.py 'Kennedy' 'National Security' 'Kennedy Library' JFK-4 prints both sides: curated naId null, catalog naId 1164 |
| Nixon NSC Files | "the reference data does not resolve": the first pass searched the repository name 'Nixon Presidential Materials' | curated entries exist under the repository name 'Nixon' (NSC Files; NSC Institutional Files (H-Files)), and the catalog has National Security Files (Nixon Administration), NAID 572235, with Institutional Files, NAID 572247, 1969-1974 | scripts/library_curated_lookup.py 'Nixon' 'NSC\|National Security' 'Nixon' RN-NSF returns those entries; the first pass's arguments returned none |
| Johnson Library National Security File | NARA 567979 (the collection) and no series | also the catalog series Latin America Country Files, NARA 567985, 1963-1969 | scripts/library_curated_lookup.py 'Johnson' 'National Security' 'Johnson Library' LBJ-NSF |
| lot 62 D 1 | presented as one series, NARA 2838992 (central-files-index.json has one row for the lot) | three claimant series (2198167, 2838991, 2838992); the bundle cannot say which holds NSC 5902 | scripts/resolve_archival.py 62D1 (one row) against scripts/claimants_62d1.py (lot-claimants-index.json: three rows) |
| first footnote citation in the pointed-at channel | "begin in 1912" (the earliest among the family C candidates) | December 1910: 1910-12-06 in the whole index (50,173 rows) and in the Latin American scope (5,169 rows) | the two SELECT MIN(dd.date_iso) ... queries quoted in N11, logged |
| lot files cited by the candidates' footnotes | "lot files of the Bureau of Inter-American Affairs", said of all 34 documents | 20 of the 32 lots the index resolves are Inter-American Affairs files; 6 of the 38 lots cited are not in the index | scripts/pointed_at_lots.py, run on the 38 lot numbers returned by the family C lotFile query in queries.log |
| the shelf for the 1980s | "the Reagan Library and the Department's central foreign policy files, which the finding aids do not itemize" | the catalog itemizes the Reagan Library's NSC Latin American Affairs Directorate (NAID 12024796) and White House Central Files subject files (N22); nothing is said about the Department's central foreign policy files | the catalog lookups after the grep for 'Reagan' in queries.log |
| foreign ministries' files (part c of the third paragraph) | "printed in English translation if at all, and no finding aid names the foreign ministries' files", with no search behind it | replaced by the checked statement in N13 | the grep -l line in queries.log |
| statements about documents, checked in a late re-read of the cited texts | frus1930v01/d375 "recognized on 18 September"; frus1913/d1028 "In August" Lind went to Mexico; frus1921v01/d238 "until a constitutional convention had chosen a president"; frus1934v05/d255 "recognized Martínez on 26 January"; frus1877/d222 and frus1878/d344 "a guarantee against frontier raids" and recognition "after peace, firmer measures ... and payment"; frus1932v05/d560 "caretaker government"; frus1944v07/d437 "proposed on 17 June to recognize"; frus1964-68v31/d152 "keep out of relations with Cuba"; Haiti 1915 "a treaty that would bind the government to protect property" | announcement of 17 September for the next day; the document does not date Lind's mission, and Wilson laid the terms and the rejection before Congress on 27 August; constitution as amended by a convention and a government shown to represent the people; the request of 25 January and the approval dated 26 January; a guarantee of an arrangement on frontier raids and other complaints, which the 1878 instruction waived; the government formed under Oyanedel; "willing to recognize on 23 June", the date Mexico suggested; a pledge not to restore relations with Cuba or Czechoslovakia; a treaty giving financial control and a right to intervene | the retrieval SELECT of each document (the readdocs.py lines in queries.log); the text is in raw/<volume>__<document>.body.txt |
| reading accounting and the cited set | 104 documents retrieved, 94 read end to end, 43 cited | 106 and 96, and 45 cited, after frus1952-54v04/d490 and d502 were read and added | work/reading_ledger.tsv (N17) and work/cited_docs.tsv (N07) |

## 13. Decisions and the inclusion rule used meanwhile

The six decisions are in the overview. Inclusion rule used meanwhile: a document is a candidate if it is in the Latin American scope and either has recognition within six tokens of government, regime, junta or administration (family C) or sits under an editors' chapter whose title names recognition (set E); it enters the collection only if it was retrieved whole and states how the Department decided or what it asked, or is the first or clearest statement of a test the overview describes. Recognition of belligerents, of exile governments (Cuban Revolutionary Council 1961-64, family C items 36 and 38 of the sample) and of states or unions was not treated as this question.

## 14. Dates and figures the overview takes from documents

Each line gives the document, the date as printed in it, and the words that carry the figure; the assembler checked that each phrase occurs in the document's body_text (case-insensitive, whitespace collapsed). These are not counts of the corpus; they are what the documents say.

[R01] frus1900/d530 (1900-09-08): “September 8, 1900” — verified

[R02] frus1930v01/d375 (1930-09-17): “September eighteenth”; “June, 1923” — verified

[R03] frus1937v05/d265 (1937-07-16): “July 16, 1937”; “(4) Any available information as to what steps” — verified

[R04] frus1948v09/d7 (1948-03-15): “March 15, 1948” — verified

[R05] frus1949v02/d489 (1949-02-03): “February 3, 1949”; “Since the administration of President Jefferson” — verified

[R06] frus1913/d7 (1913-03-12): “March 11, 1913”; “March 12, 1913” — verified

[R07] frus1913/d1028 (1913-08-27): “August 27, 1913”; “(b) Security given for an early and free election”; “pledges itself to recognize” — verified

[R08] frus1919v01/d867 (1919-08-16): “August 16, 1919”; “de jure or even a legitimately de facto Government” — verified

[R09] frus1921v01/d238 (1921-01-31): “January 31, 1921”; “not as the de facto Government, but as the Constitutional Government” — verified

[R10] frus1925v02/d498 (1925-12-09): “December 9, 1925” — verified

[R11] frus1931v02/d232 (1931-12-20): “December 20, 1931”; “within 6 months” — verified

[R12] frus1934v05/d255 (1934-01-25): “January 25, 1934”; “Approved, Jan. 26” — verified

[R13] frus1936v05/d109 (1936-04-21): “April 21, 1936” — verified

[R14] frus1877/d222 (1877-05-16): “May 16, 1877”; “condition precedent to any recognition” — verified

[R15] frus1878/d344 (1878-03-23): “March 23, 1878” — verified

[R16] frus1914/d567 (1914-12-12): “December 12, 1914”; “consent of the governed” — verified

[R17] frus1915/d448 (1915-08-12): “August 12, 1915”; “simultaneously conclude” — verified

[R18] frus1921v02/d344 (1921-06-08): “June 8, 1921” — verified

[R19] frus1932v05/d518 (1932-07-16): “July 16, 1932” — verified

[R20] frus1932v05/d560 (1932-10-12): “October 12, 1932”; “not bargaining over the question of recognition” — verified

[R21] frus1932v05/d561 (1932-10-16): “October 16, 1932”; “does not imply recognition nor is it a bargain for recognition” — verified

[R22] frus1932v05/d567 (1932-10-21): “October 21, 1932” — verified

[R23] frus1934v05/d85 (1934-01-14): “January 14, 1934”; “in advance of the fulfillment of the conditions” — verified

[R24] frus1961-63v10-12mSupp/d109 (1963-07-18): “July 18, 1963”; “within approximately one year”; “will not extend recognition until at least several other Latin American countries” — verified

[R25] frus1961-63v10-12mSupp/d137 (1963-04-24): “April 17”; “two years” — verified

[R26] frus1961-63v12/d359 (1963-10-04): “October 4, 1963”; “7. Commitment to institutional reforms” — verified

[R27] frus1964-68v31/d152 (1964-12-03): “December 3, 1964” — verified

[R28] frus1943v05/d335 (1943-06-06): “June 6, 1943”; “to bargain with the new Government” — verified

[R29] frus1944v07/d388 (1944-01-10): “January 10, 1944” — verified

[R30] frus1944v07/d403 (1944-01-28): “January 28, 1944”; “nineteen republics” — verified

[R31] frus1944v07/d432 (1944-06-02): “June 2, 1944”; “no MNR official” — verified

[R32] frus1944v07/d437 (1944-06-17): “June 17, 1944”; “June 23” — verified

[R33] frus1944v07/d1090 (1944-10-27): “October 27, 1944” — verified

[R34] frus1945v09/d1170 (1945-10-25): “October 25, 1945” — verified

[R35] frus1948v09/d74 (1948-03-30): “does not imply any judgment upon the domestic policy”; “March 30–May 2, 1948” — verified

[R36] frus1948v09/d115 (1948-12-10): “December 10, 1948” — verified

[R37] frus1955-57v06/d354 (1957-07-11): “July 11, 1957”; “past seven months” — verified

[R38] frus1958-60v06/d217 (1959-01-07): “January 7, 1959”; “5 p.m. that day” — verified

[R39] frus1958-60v05/d11 (1959-02-16): “February 16, 1959”; “unless a substantial question should arise with respect to Communist control” — verified

[R40] frus1961-63v12/d363 (1963-12-13): “December 13, 1963”; “recognized the new Dominican Government on December 14” — verified

[R41] frus1964-68v31/d132 (1966-06-28): “June 28, 1966”; “Resolution XXVI of 1965 Rio Conference” — verified

[R42] frus1964-68v31/d518 (1968-10-19): “October 19, 1968” — verified

[R43] frus1969-76v21/d361 (1973-09-20): “September 20, 1973”; “24 September 1973” — verified

[R44] frus1952-54v04/d490 (1954-06-28): “June 28, 1954”; “one of criteria for recognition is that new government be in control of territory”; “Castillo Armas controlled a portion of territory” — verified

[R45] frus1952-54v04/d502 (1954-07-09): “July 9, 1954”; “formally established on July 2”; “prepared to fulfill the international obligations of Guatemala”; “conspicuously in the lead or behind”; “recognition to the new Guatemalan Government on July 13, 1954” — verified

## 15. Where each number lives

| item | file |
|---|---|
| canary, controls, the queries run (its last line, ELIDED, names what it shortens) | queries.log |
| scope table (scope_docs, editors_recog, cited) | work/scope.db (built by scripts/build_scope.py, build_editors_set.py, load_cited.py) |
| volume titles and subseries | work/manifest_list.tsv |
| section tree per document | work/structure_flat.tsv |
| scope volumes | work/scope_volumes.tsv, work/hemisphere_volumes.txt |
| editors' recognition chapters | work/editors_recog_headings.tsv, work/memo/editors_headings_counts.tsv |
| literal-share samples and referent verdicts | work/shares/*.tsv |
| false-friend table | work/false_friend.tsv |
| decade tables | work/memo/decade_C.txt, decade_C_whole_index.txt, decade_W.txt, decade_E.txt, decade_denominators.tsv |
| TEI census | work/tei_summary.txt, work/tei/variants_by_volume.tsv, work/tei/variants_latam_docs.tsv |
| periodisation check | scripts/date_check.py (output in this memo, section 8) |
| documents read | raw/ (text), work/reading_ledger.tsv |
| quotations | work/quotes.tsv |
| cited documents and citation metadata | work/cited_docs.tsv, work/cite_meta.tsv |
| archival resolution | scripts/resolve_archival.py, scripts/usage_rank.py, scripts/gloss_cited.py |
| late addition of Guatemala in 1954 to the cited set | scripts/add_guatemala_1954.py |

File notes. The brief says all six composition keys must be present in the collection file, and its own example shows seven (defaultBodyDepth, footnoteStyle, includeSourceNote, tocStyle, applyHighlights, includeNotes, includeWordCloud); the file carries all seven, so it meets either reading. The cited set grew from 43 to 45 documents late in the run, when Guatemala in 1954 (frus1952-54v04/d490 and d502) was followed up from the list of threads not followed; scripts/add_guatemala_1954.py is that change, and the overview, the collection and this memo were rebuilt from the files afterwards (the assembler stops if a label is missing). Housekeeping: near the end a temporary copy of the task text was saved to the session's scratchpad folder, outside this run directory, to reread the requirements, and was deleted at once; to my knowledge nothing else of this run was written outside the run directory. Two directory listings went beyond the run directory without opening anything: the names in the session scratchpad folder, and, at the very end, the names in this run directory's parent folder (runs/), which showed two sibling folders; I read no file in them.

## 16. Claims not made

The overview does not claim that the United States applied any stated rule consistently; it reports what the Department said it was doing in the documents read. It does not say how many recognition decisions there were, because the series is a selection. It does not say whether any new government kept its promises. It gives no NARA identifier, entry or access status that the bundled reference data does not carry. The documents under the editors' recognition chapters that I did not read (2,205 of 2,255) may modify the picture for Argentina in 1943-45, Nicaragua in 1947 and Guatemala in 1944.

## 17. The citations used in the overview

Each full citation in the overview is the manifest title of the volume (shortened to the conventional form for the volumes whose title carries the President's message), the document number, and the address https://history.state.gov/historicaldocuments/<volume>/<document>. Day is the index's day for the document; page is the first printed page from the page-range table (`SELECT page_number_raw FROM page_ranges WHERE volume_id = ? AND document_id = ? AND is_start = 1`).

| finding | volume/document | printed citation | day | printed page | role |
|---|---|---|---|---|---|
| 1 | frus1900/d530 | Papers Relating to the Foreign Relations of the United States, 1900, Document 530 | 1900-09-08 | 410 | quoted |
| 1 | frus1930v01/d375 | Papers Relating to the Foreign Relations of the United States, 1930, Volume I, Document 375 | 1930-09-17 | 387 | cited |
| 1 | frus1937v05/d265 | Foreign Relations of the United States, Diplomatic Papers, 1937, The American Republics, Volume V, Document 265 | 1937-07-16 | 253 | cited |
| 1 | frus1948v09/d7 | Foreign Relations of the United States, 1948, The Western Hemisphere, Volume IX, Document 7 | 1948-03-15 | 17 | quoted |
| 1 | frus1949v02/d489 | Foreign Relations of the United States, 1949, The United Nations; The Western Hemisphere, Volume II, Document 489 | 1949-02-03 | 797 | quoted |
| 2 | frus1913/d7 | Papers Relating to the Foreign Relations of the United States, 1913, Document 7 | 1913-03-12 | 7 | quoted |
| 2 | frus1913/d1028 | Papers Relating to the Foreign Relations of the United States, 1913, Document 1028 | 1913-08-27 | 820 | cited |
| 2 | frus1919v01/d867 | Papers Relating to the Foreign Relations of the United States, 1919, Volume I, Document 867 | 1919-08-16 | 852 | cited |
| 2 | frus1921v01/d238 | Papers Relating to the Foreign Relations of the United States, 1921, Volume I, Document 238 | 1921-01-31 | 282 | cited |
| 2 | frus1925v02/d498 | Papers Relating to the Foreign Relations of the United States, 1925, Volume II, Document 498 | 1925-12-09 | 642 | cited |
| 2 | frus1931v02/d232 | Papers Relating to the Foreign Relations of the United States, 1931, Volume II, Document 232 | 1931-12-20 | 203 | quoted |
| 2 | frus1934v05/d255 | Foreign Relations of the United States, Diplomatic Papers, 1934, The American Republics, Volume V, Document 255 | 1934-01-25 | 255 | cited |
| 2 | frus1936v05/d109 | Foreign Relations of the United States, Diplomatic Papers, 1936, The American Republics, Volume V, Document 109 | 1936-04-21 | 132 | quoted |
| 3 | frus1877/d222 | Papers Relating to the Foreign Relations of the United States, 1877, Document 222 | 1877-05-16 | 403 | quoted |
| 3 | frus1878/d344 | Papers Relating to the Foreign Relations of the United States, 1878, Document 344 | 1878-03-23 | 543 | cited |
| 3 | frus1914/d567 | Papers Relating to the Foreign Relations of the United States, 1914, Document 567 | 1914-12-12 | 367 | cited |
| 3 | frus1915/d448 | Papers Relating to the Foreign Relations of the United States, 1915, Document 448 | 1915-08-12 | 431 | cited |
| 3 | frus1921v02/d344 | Papers Relating to the Foreign Relations of the United States, 1921, Volume II, Document 344 | 1921-06-08 | 406 | quoted |
| 3 | frus1932v05/d518 | Foreign Relations of the United States, Diplomatic Papers, 1932, The American Republics, Volume V, Document 518 | 1932-07-16 | 463 | quoted |
| 3 | frus1932v05/d560 | Foreign Relations of the United States, Diplomatic Papers, 1932, The American Republics, Volume V, Document 560 | 1932-10-12 | 500 | cited |
| 3 | frus1932v05/d561 | Foreign Relations of the United States, Diplomatic Papers, 1932, The American Republics, Volume V, Document 561 | 1932-10-16 | 501 | cited |
| 3 | frus1932v05/d567 | Foreign Relations of the United States, Diplomatic Papers, 1932, The American Republics, Volume V, Document 567 | 1932-10-21 | 505 | cited |
| 4 | frus1934v05/d85 | Foreign Relations of the United States, Diplomatic Papers, 1934, The American Republics, Volume V, Document 85 | 1934-01-14 | 100 | quoted |
| 4 | frus1961-63v10-12mSupp/d137 | Foreign Relations of the United States, 1961–1963, Volumes X/XI/XII, Microfiche Supplement, American Republics; Cuba 1961–1962; Cuban Missile Crisis and Aftermath, Document 137 | 1963-04-24 | 339 | cited |
| 4 | frus1961-63v10-12mSupp/d109 | Foreign Relations of the United States, 1961–1963, Volumes X/XI/XII, Microfiche Supplement, American Republics; Cuba 1961–1962; Cuban Missile Crisis and Aftermath, Document 109 | 1963-07-18 | 273 | cited |
| 4 | frus1961-63v12/d359 | Foreign Relations of the United States, 1961–1963, Volume XII, American Republics, Document 359 | 1963-10-04 | 740 | quoted |
| 4 | frus1964-68v31/d152 | Foreign Relations of the United States, 1964–1968, Volume XXXI, South and Central America; Mexico, Document 152 | 1964-12-03 | 342 | cited |
| 5 | frus1943v05/d335 | Foreign Relations of the United States, Diplomatic Papers, 1943, The American Republics, Volume V, Document 335 | 1943-06-06 | 371 | cited |
| 5 | frus1944v07/d388 | Foreign Relations of the United States, Diplomatic Papers, 1944, The American Republics, Volume VII, Document 388 | 1944-01-10 | 430 | quoted |
| 5 | frus1944v07/d403 | Foreign Relations of the United States, Diplomatic Papers, 1944, The American Republics, Volume VII, Document 403 | 1944-01-28 | 443 | cited |
| 5 | frus1944v07/d432 | Foreign Relations of the United States, Diplomatic Papers, 1944, The American Republics, Volume VII, Document 432 | 1944-06-02 | 463 | cited |
| 5 | frus1944v07/d437 | Foreign Relations of the United States, Diplomatic Papers, 1944, The American Republics, Volume VII, Document 437 | 1944-06-17 | 468 | cited |
| 5 | frus1944v07/d1090 | Foreign Relations of the United States, Diplomatic Papers, 1944, The American Republics, Volume VII, Document 1090 | 1944-10-27 | 1104 | quoted |
| 5 | frus1945v09/d1170 | Foreign Relations of the United States, Diplomatic Papers, 1945, The American Republics, Volume IX, Document 1170 | 1945-10-25 | 1409 | cited |
| 5 | frus1948v09/d74 | Foreign Relations of the United States, 1948, The Western Hemisphere, Volume IX, Document 74 | 1948-03-30 | 98 | cited |
| 5 | frus1948v09/d115 | Foreign Relations of the United States, 1948, The Western Hemisphere, Volume IX, Document 115 | 1948-12-10 | 141 | quoted |
| 6 | frus1952-54v04/d490 | Foreign Relations of the United States, 1952–1954, The American Republics, Volume IV, Document 490 | 1954-06-28 | 1192 | cited |
| 6 | frus1952-54v04/d502 | Foreign Relations of the United States, 1952–1954, The American Republics, Volume IV, Document 502 | 1954-07-09 | 1211 | cited |
| 6 | frus1955-57v06/d354 | Foreign Relations of the United States, 1955–1957, American Republics: Multilateral; Mexico; Caribbean, Volume VI, Document 354 | 1957-07-11 | 957 | quoted |
| 6 | frus1958-60v06/d217 | Foreign Relations of the United States, 1958–1960, Cuba, Volume VI, Document 217 | 1959-01-07 | 347 | cited |
| 6 | frus1958-60v05/d11 | Foreign Relations of the United States, 1958–1960, American Republics, Volume V, Document 11 | 1959-02-16 | 91 | cited |
| 6 | frus1961-63v12/d363 | Foreign Relations of the United States, 1961–1963, Volume XII, American Republics, Document 363 | 1963-12-13 | 747 | cited |
| 6 | frus1964-68v31/d132 | Foreign Relations of the United States, 1964–1968, Volume XXXI, South and Central America; Mexico, Document 132 | 1966-06-28 | 307 | cited |
| 6 | frus1964-68v31/d518 | Foreign Relations of the United States, 1964–1968, Volume XXXI, South and Central America; Mexico, Document 518 | 1968-10-19 | 1075 | quoted |
| 6 | frus1969-76v21/d361 | Foreign Relations of the United States, 1969–1976, Volume XXI, Chile, 1969–1973, Document 361 | 1973-09-20 | 930 | quoted |

## TRACE TABLE

One row per number, date, figure and quotation in the overview, in the order it appears; the label points to the memo line (counted in this file) that carries the source, the query or the verification. [N..] are counts of the corpus, [R..] dates and figures read in documents, [Q..] verified quotations, C-table the citations table in section 17.

| overview location | item as the overview words it | memo labels | memo lines |
|---|---|---|---|
| Bottom line 1 | 553 volumes (whole series); index taken 25 October 2026 | N01 | 3 |
| Bottom line 1 | From 1877 to 1949 (1877 instruction; 1949 letter) | R14, R05 | 482, 464 |
| Bottom line 1 | full citations: 1877 Document 222; 1900 Document 530; 1948 Volume IX Document 7; 1913 Document 7; 1931 Volume II Document 232; 1936 Volume V Document 109 | N07, C-table | 359, 573 |
| Bottom line 1 | from 1923 to 1936 (treaty rule: June 1923 statement; 1936 decision) | R02, R13 | 458, 480 |
| Bottom line 1 | Mexico, 1877; Chile, 1932; Haiti, 1915; Mexico, 1921; Cuba, 1934; Dominican Republic and Ecuador, 1963; Bolivia, 1943-44 and 1964; from 1943 | R14, R19, R20, R21, R22, R17, R18, R23, R26, R24, R28, R29, R30, R31, R32, R27 | 482, 492, 494, 496, 498, 488, 490, 500, 506, 502, 510, 512, 514, 516, 518, 508 |
| Bottom line 1 | about 2,900 of the 57,000 documents; roughly one in twenty | N04, N03 | 64, 34 |
| Bottom line 1 | about three in five of those, judging from a sample of forty | N05 | 72 |
| Bottom line 1 | Forty-five documents carry the argument | N07 | 359 |
| Bottom line 2 | 30 of the 45 documents; about two in three of the 2,900 candidates; central decimal file 1910-1963; Record Group 59 | N10, N12 | 387, 405 |
| Bottom line 2 | 1963-73; POL 16; POL 26, later POL 23-9 | N12 | 405 |
| Bottom line 2 | lot 64 D 563, twelve series; 1947-49, NARA 1151288, entry A1 558-A, dates 1947-1949, unrestricted | N12 | 405 |
| Bottom line 2 | lot 62 D 1, three series: Alphabetical Files NARA 2198167, A1 1583A-B, 1948-1961, partly restricted; Numerical Files NARA 2838991, A1 1583C-D, 1947-1961, no access status; Records Relating to Activities with the National Security Council NARA 2838992, A1 1583E-F, 1948-1961, partly restricted | N12 | 405 |
| Bottom line 2 | presidential libraries: Kennedy NARA 1164, Country Files NARA 193236, 1961-1963; Johnson NARA 567979, Latin America Country Files NARA 567985, 1963-1969; Nixon Institutional Files NARA 572247, 1969-1974; Eisenhower Project Clean Up unresolved | N12 | 405 |
| Bottom line 2 | nearly a quarter of the candidates, almost all before 1910 | N10 | 387 |
| Bottom line 2 | series 593313; Mexico 1873-79 roll 149324017; Colombia 1898-1906 roll 149302787; series 603720 | N12 | 405 |
| Bottom line 2 | only about one candidate in fourteen; about 150 documents 1912-62; about 35 documents 1950-80; about 35 documents 1955-80 | N11 | 398 |
| Bottom line 2 | subject files for 1957-59: lots 59 D 573 and 61 D 279, NARA 2108779, A1 1135, 1957-1959; lot 63 D 127, NARA 2363840, A1 3157, 1955-1963; lot 64 D 16, NARA 1750062, A1 3159, 1958-1975; lot 70 D 247, NARA 26309336, A1 5741, 1964-1978 | N12 | 405 |
| Bottom line 2 | Recorded footnote citations begin in December 1910, Latin American parts and whole series alike | N11 | 398 |
| Bottom line 2 | lot files of Department offices, most of them the Bureau of Inter-American Affairs' (about 35 documents, 1950-80) | N11 | 398 |
| Bottom line 3 (a) | all 553 volumes; about 1,150 documents dated 1861-1919; only six; 263 of 476 in 1950-79 | N01, N09 | 3, 337 |
| Bottom line 3 (a) | tens of thousands of memoranda across the series; nothing for a phrase that cannot occur | N16, N09 | 16, 337 |
| Bottom line 3 (a) | from 1910, in the central decimal file; before 1920; Numerical File series NARA 654171 indexed by case number | N02, N12 | 25, 405 |
| Bottom line 3 (b) | Wilson Doctrine and Mann Doctrine in no document; Tobar Doctrine in one; Betancourt Doctrine in three; Estrada Doctrine in 25; 24 of the 25 | N13 | 344 |
| Bottom line 3 (c) | Spanish recognition vocabulary in only eleven of the 57,000 documents | N13, N03 | 344, 34 |
| Bottom line 3 (d) | 1981-88: one volume on South America and one on the South Atlantic conflict; about 400 documents dated in the 1980s against about 3,200 for the 1970s | N03, N03b, N03c | 34, 39, 351 |
| Bottom line 3 (d) | Reagan Library: NSC Latin American Affairs Directorate records, NARA 12024796, series dated 1983-1989; White House Central Files subject files on South and Central America and eight countries, 1981-1989; no access status | N22 | 353 |
| Bottom line 3 | positive phrase in 552 of 553 volumes; impossible phrase in none | N16 | 16 |
| Scope | all 553 volumes; 25 October 2026; 46 volumes devoted to the hemisphere; 111 other volumes; about 57,000 documents; 1861 to 1988; two unrelated volumes (second editions) | N01, N02, N03 | 3, 25, 34 |
| Decisions 1 | editors titled for recognition, which stop in 1950; Brazil in 1937; Bogota resolution of 1948 | N18, N18c, R35 | 45, 58, 524 |
| Decisions 2 | Bolivia in 1920-21 and Chile in 1932; Nicaragua in 1925-26 | R09, R19, R20, R21, R22, N18c, R10 | 472, 492, 494, 496, 498, 58, 474 |
| Decisions 3 | twenty republics (the Latin American republics are Argentina, Bolivia, Brazil, Chile, Colombia, Costa Rica, Cuba, Dominican Republic, Ecuador, El Salvador, Guatemala, Haiti, Honduras, Mexico, Nicaragua, Panama, Paraguay, Peru, Uruguay, Venezuela); Haiti in 1915; Cuban decisions of 1933-34 | N03, R17, N18c, R23 | 34, 488, 58, 500 |
| Decisions 4 | 1861 to 1988; tests as written in 1877 and 1900; after 1945; findings 5 and 6 | N03, R14, R01 | 34, 482, 456 |
| Decisions 5 | Haiti in 1915, Mexico in 1921 and the Dominican Republic in 1963; Chile in 1932, Ecuador and Guatemala in 1963 and Bolivia in 1964; Chile in 1932, Argentina in 1943 | R17, R18, R26, R19, R20, R21, R24, R25, R27, R28 | 488, 490, 506, 492, 494, 496, 502, 504, 508, 510 |
| Decisions 6 | Guatemala in 1963: no public timetable for elections obtained | R25 | 504 |
| Finding 1 | September 1900; 17 September 1930 and the next day (18 September); 1937 and four questions; 15 March 1948; the following year 1949, 3 February 1949 | R01, R02, R03, R04, R05 | 456, 458, 460, 462, 464 |
| Finding 1 | quotations Q01, Q02, Q03, Q05 | Q01, Q02, Q03, Q05 | 363, 364, 365, 366 |
| Finding 2 | 11 March 1913; 12 March 1913; 27 August (1913); 1919; 1921 (31 January 1921) | R06, R07, R08, R09 | 466, 468, 470, 472 |
| Finding 2 | 1923 treaty; December 1925; December 1931 (20 December 1931); 25 January 1934 and the approval of 26 January; 1936 (21 April 1936); 1948 staff paper | R02, R10, R11, R12, R13, R04 | 458, 474, 476, 478, 480, 462 |
| Finding 2 | quotations Q06, Q07, Q08 | Q06, Q07, Q08 | 367, 368, 369 |
| Finding 3 | May 1877 (16 May 1877); March 1878; December 1914; August 1915; June 1921 (8 June 1921) | R14, R15, R16, R17, R18 | 482, 484, 486, 488, 490 |
| Finding 3 | 1932; 16 July 1932; October; 21 October (1932) | R19, R20, R21, R22 | 492, 494, 496, 498 |
| Finding 3 | quotations Q09, Q20, Q10 | Q09, Q20, Q10 | 370, 381, 371 |
| Finding 4 | January 1934 (14 January 1934); 1963; seven points; about a year; about two years; 1964 | R23, R26, R24, R25, R27 | 500, 506, 502, 504, 508 |
| Finding 4 | 4 October 1963; quotations Q19, Q11 | R26, Q19, Q11 | 506, 380, 372 |
| Finding 5 | June 1943; January 1944 (10 January 1944); all nineteen republics; end of the month (28 January 1944) | R28, R29, R30 | 510, 512, 514 |
| Finding 5 | 17 June and 23 June (1944); 2 June 1944 (Axis aliens expelled) | R32, R31 | 518, 516 |
| Finding 5 | October 1945; Bogota 1948; 27 October 1944; 10 December 1948 | R34, R35, R33, R36 | 522, 524, 520, 526 |
| Finding 5 | quotations Q12, Q13, Q14 | Q12, Q13, Q14 | 373, 374, 375 |
| Finding 6 | 28 June 1954; 2 July, 9 July and 13 July (1954); Castillo Armas | R44, R45 | 542, 544 |
| Finding 6 | February 1959; 7 January 1959; 14 December 1963; Rio 1965 | R39, R38, R40, R41 | 532, 530, 534, 536 |
| Finding 6 | July 1957 and seven months; 19 October 1968; 20 September 1973 | R37, R42, R43 | 528, 538, 540 |
| Finding 6 | quotations Q15, Q16, Q17, Q18 | Q15, Q16, Q17, Q18 | 376, 377, 378, 379 |
| How this was done | 553 volumes; 157 volumes, about 57,000 documents | N01, N03 | 3, 34 |
| How this was done | 62 chapters holding about 2,250 documents between 1895 and 1950; six words | N18, N04 | 45, 64 |
| How this was done | forty hits: 23 concerned recognizing a Latin American government, 2 exile governments, 15 other senses | N05 | 72 |
| How this was done | about 14 documents in 100 against 16 | N08, N08b | 169, 190 |
| How this was done | non-recognition 123 documents against 65; about one document in forty with recognition near government, regime, junta or administration has it only in a footnote or the source note | N14 | 268 |
| How this was done | 106 documents retrieved whole, 96 read end to end, 17 quoted | N17, N07 | 357, 359 |
| Read next | agent run, 25 October 2026; six findings; 19 quoted passages as excerpts | N01, N07 | 3, 359 |
| Read next | Argentina in 1943-45, Nicaragua in 1947, Ecuador in 1944 and 1947, Guatemala in 1944 and, beyond the two documents I read, in 1954, El Salvador in 1944-45, Bolivia in 1946, the Dominican Republic in 1916, Mexico in 1920, Paraguay and Bolivia in 1937 | N18, N21 | 45, 60 |
| Collection, closing block | about 120 (Argentina), 40, 37, 28, 48, 53, 69, 67, 83; 50 of the 2,255 documents read | N18, N18b | 45, 58 |
