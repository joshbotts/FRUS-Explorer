# Scope memo — recognition of governments that came to power by force in Latin America

Run r11, 2026-10-25. Operator-facing. Every number below names its query or script; scripts and outputs are in this run directory.

## M1. Coverage and controls

- Coverage query (canary, first command of the run):
  `SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;` -> `553|321749|1103|8481`.
  The index holds all 553 volumes of the series, so "my partial library" is the full series here; every count below is conditional on these 553 volumes.
- Read-only proof: `sqlite3 -readonly ... "BEGIN; CREATE TABLE zz(x); ROLLBACK;"` -> `attempt to write a readonly database`.
- Non-apparatus documents in the corpus: `SELECT COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0;` -> 312,169.
- Controls, same pass over the 87 scope volumes (controls.py, output controls_final.out):
  positive `frus_documents MATCH '"Department of State"'` joined on (volume_id, document_id), non-apparatus, GROUP BY volume_id -> nonzero in 87 of 87 volumes (minimum 22 documents, frus1952-54Guat);
  negative `frus_documents MATCH 'ZZZ_IMPOSSIBLE_ZZZ'` -> 0.
  Also run corpus-wide early: `"Department of State"` 98,970 FTS rows; ZZZ 0.

## M2. How the scope was found (editors' headings first)

1. TEI heading scan (heads.py -> heads_recog.tsv, 396 headings; surface: raw TEI `<div type=chapter|compilation|section|subchapter>` first `<head>`, tags stripped, whitespace collapsed). Filter for government recognition -> heads_gov.tsv (140 headings). The editors' formula is "Recognition of the X Government", "Withholding of recognition", "Refusal of the United States to recognize", "Question of the recognition of", "revolution ... and recognition of new Government".
2. Inclusion rule. A non-apparatus document is in scope when ANY of:
   - **Path A (heading rule)**: it sits under a div whose head matches `recogni` + (govern|regime|junta|provisional|de facto|president|revolution|administration|withhold|refusal|question of), excluding naturalization/consul/meat/blockade etc., in a chain naming a Latin American state (chapters.py -> chap_docs.tsv, 2,374 docs); three false chapters removed by hand (Egypt Mixed Courts — a footnote inside the head named Ecuador; a Mexican citizenship case; a 1917 Austria-Hungary chapter): 2,338; apparatus dropped 1; and the document itself matches `frus_documents MATCH 'recogni*'` -> **592 docs, 36 volumes** (scopeA.py -> scopeA.tsv).
   - **Path B (proximity rule)**: it matches
     `body_text:(NEAR(recogni* junta, 6) OR NEAR(recogni* regime, 6) OR NEAR(recogni* "new government", 6) OR NEAR(recogni* "provisional government", 6) OR NEAR(recogni* "de facto", 6) OR NEAR(recogni* "military government", 6))` (nearq.txt; 1,772 non-apparatus hits corpus-wide)
     AND is Latin American by TEI chain (latamdocs.py -> latam_docs.tsv, 59,654 docs) or sits in a whole-volume Latin American volume (modvols.txt, 20 volumes 1948–1988; frus1949v02, frus1950v02, frus1951v02 removed from the whole-volume list because they mix UN material), AND is not in A, AND not an Ed2 volume -> **346 docs** (scopeB.py -> scopeB.tsv).
   - **Path C (policy statements found by targeted phrase search, outside A and B)**: frus1913/d7 (found by `MATCH '"cooperation is possible only when supported" OR "just government based upon law"'`) and frus1949v02/d454 (found by `MATCH '"does not imply any judgment"'`). 2 docs.
   - Total: **940 documents in 87 volumes** (scope_final.tsv). No Ed2 volume in scope (`grep -c Ed2 scope_final.tsv` -> 0).
3. Precision. Path A is on-topic by construction (a recognition chapter plus the word). Path B, hand-judged on 40 evenly spaced documents of the sorted 346 (precB.py -> precB.out): **32 of 40 on topic**; the 8 misses are the Confederacy (frus1865p3/d695), a customs agreement (frus1918/d401), Uruguay small talk (frus1948v09/d214), a Bolivia estimate (frus1958-60v05mSupp/bl_d1), Bay of Pigs exile-government planning (frus1961-63v10/d35, frus1961-63v10-12mSupp/d248, frus1969-76ve10/d204) and Berlin (frus1961-63v15/d148). So the 940 is an upper bound, roughly 1 in 5 of Path B off topic.
4. False-friend test for the question's own terms (python, db.py, tag falsefriend; denominators: 2,337 non-apparatus documents in the Path A chapters, 312,169 corpus):
   - `recogni*`: 592 of 2,337 in the chapters vs 16,951 of 312,169 corpus — about 4.6 times the baseline: discriminates.
   - `"by force"` (the question's "came to power by force"): 35 of 2,337 vs 4,263 of 312,169 — the baseline rate: **it measures the corpus, not the question**; not used. The editors' and diplomats' words are revolution, coup d'état, de facto, junta, provisional government.
   - control `"Department of State"`: 497 of 2,337 vs 94,049 of 312,169 — not elevated.
5. Periodisation on `document_dates.date_iso` (the index's day from frus:doc-dateTime-min), NOT series year (decades.py -> decades_final.out). Denominator = dated non-apparatus documents of the decade, Ed2 volumes excluded:
   `SELECT substr(dd.date_iso,1,3)||'0s', COUNT(*) FROM document_dates dd JOIN document_cache c ON c.volume_id=dd.volume_id AND c.document_id=dd.document_id WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND dd.date_iso IS NOT NULL AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') GROUP BY 1`
   (my 1940s denominator is 75,872, not the 74,043 the house rules cite; different exclusions — stated, not reconciled).

| decade | scope docs | of dated docs | per 1,000 | top volume share of numerator |
|---|---|---|---|---|
| 1860s | 4 | 11,268 | 0.35 | frus1868p2 3 of 4 |
| 1870s | 3 | 5,821 | 0.52 | frus1875v02 2 of 3 |
| 1880s | 10 | 6,484 | 1.54 | frus1881 6 of 10 |
| 1890s | 17 | 9,845 | 1.73 | frus1899 10 of 17 |
| 1900s | 15 | 10,261 | 1.46 | frus1904 5 of 15 |
| 1910s | 144 | 30,842 | 4.67 | frus1915 28 of 144 |
| 1920s | 122 | 20,374 | 5.99 | frus1921v02 26 of 122 |
| 1930s | 240 | 40,073 | 5.99 | frus1934v05 57 of 240 |
| 1940s | 249 | 75,872 | 3.28 | frus1944v07 127 of 249 |
| 1950s | 39 | 42,801 | 0.91 | frus1952-54v04 10 of 39 |
| 1960s | 76 | 27,654 | 2.75 | frus1961-63v10-12mSupp 16 of 76 |
| 1970s | 20 | 22,258 | 0.90 | frus1977-80v15 8 of 20 |
| 1980s | 1 | 6,038 | 0.17 | frus1977-80v24 1 of 1 |

   The 1940s rate is half one volume (127 of 249 in frus1944v07). The post-1950 drop is partly a rule artefact: post-1950 volumes have no "Recognition of ..." chapter heads, so only Path B reaches them. Apparatus inside a document (footnotes) is NOT separated: body_text includes the editors' footnotes; these are counts of documents, not term densities.

## M3. Phrase counts and literal shares (shares.py -> shares.out)

FTS phrase MATCH, restricted to the 940-doc scope (computed on the 938 of Paths A+B; the two Path C docs were added after). Literal test: Python `re` with re.IGNORECASE over header+dateline+source_note+body_text, whitespace-collapsed. All hit lists under 300, so census. STRICT = single spaces; TOLERANT = each word with its inflections, separators `[\s\-,().]+`.

| phrase | FTS docs in scope | TOLERANT | STRICT |
|---|---|---|---|
| "de facto government" | 95 | 95 of 95 | 94 of 95 |
| "free elections" | 33 | 33 of 33 | 30 of 33 |
| "international obligations" | 96 | 96 of 96 | 94 of 96 |
| "constitutionally reorganized" | 5 | 5 of 5 | 5 of 5 |

A 1.000 tolerant share tests the stemmer only. Referent test: done by reading only for the quoted documents below (each uses the phrase as a recognition condition); the 95/96 counts are NOT claimed to be all recognition-condition uses. The overview uses none of these counts as a finding.

## M4. Archival channels (never summed)

Came-from = document_sources (one row per document). Pointed-at = external_citations (inherited=0), which has no row before 1910-12-06, stores the citation fragment, and holds lot, library and decimal anchors only. Scripts: arch.py (arch_final.out, arch_rows.json), glosscf.py (glosscf.out), glosspa.py (glosspa_final.out), lots.py (lots_final.out). Volume set: the 87 scope volumes, 940 docs.

- CAME-FROM: 894 of 940 docs have a source row. citation_era (a citation FORM, not a date): decimal 803, structured 53, subject_numeric 15, lot_file 13, cfpf 5, named_series 4, published 1. repository: Department of State 825, CIA 15, National Archives 14, Eisenhower Library 8, Kennedy 7, Johnson 7, Nixon materials 6, Carter 6, Ford 1, none 5. record_group: 59 in 837 rows.
- Decimal keys glossed with decimal-class-labels.json, schedule 1910-1949, only where the DOCUMENT is dated 1910–1949 (coverage.glossableYears): 771 decimal rows carry a class; 45 dated outside 1910–1949 left unglossed; of the 726 glossed, 287 are country "Government" subfiles (8xx.01) and 341 "Political affairs" (8xx.00); 70 are class 7 (bilateral political relations, e.g. 711.12 United States–Mexico). Top keys: 816.01 El Salvador/Government 108; 812.00 Mexico/Political affairs 90; 824.00 Bolivia/Political affairs 66; 824.01 Bolivia/Government 45; 835.01 Argentina/Government 35; 818.00 Costa Rica/Political affairs 34; 822.01 Ecuador/Government 23; 814.01 Guatemala/Government 21.
  The bundled data carries NO series-facts row for the Central Decimal File itself (series-facts-index.json byNaId searched; none matched), so its entry, identifier and access status cannot be stated from the bundle.
- Pre-1906 shelves (central-files-index.json countrySeries; series-level NAIDs carry no series-facts row): Despatches from U.S. Ministers, series NAID 603720 — file units Ecuador 177380753, Colombia 177380752, Venezuela 177380736, Mexico 177380741, Peru 177380755, Haiti 177380737; Diplomatic Instructions, series NAID 593313. This attribution is by document FORM (minister's despatch / Department instruction), not from a stored citation: the pre-1906 scope documents have no document_sources row.
- Came-from lots (lots.py; central-files-index lotFiles + series-facts byNaId), each 1–2 documents (thin):
  63D351 & 66D95 -> RG 59 A1 1586E, NAID 2839192, Records Relating to NSC Policy Papers, Executive Secretariat, 1947–1979, Restricted–Partly;
  66D149 -> A1 5158, NAID 610077, Presidential Memorandums of Conversation, 1956–1964, Unrestricted;
  64D16 -> A1 3159, NAID 1750062, Records Relating to El Salvador, Office of Central American Affairs, 1958–1975, Restricted–Partly;
  53D26 -> A1 1130, NAID 2108774, Subject Files, Office of the Assistant Secretary for Inter-American Affairs, 1949–1953, Unrestricted;
  60D513 -> A1 1137, NAID 2108782, Office Files, 1956–1958, Unrestricted;
  66D65 -> A1 5763, NAID 1074073, Subject and Country Files, Bureau of Inter-American Affairs, 1962–1975, Restricted–Partly;
  62D1 -> A1 1583E/F, NAID 2838992; 62D430 -> A1 1586C, NAID 2839191; 63D75 -> A1 1609, NAID 2521274; 70D442 not in the index.
- POINTED-AT: 90 rows in 66 of 940 docs. Anchors: centralFileClass 74, lotFile 11, presidentialLibrary 4. Most-cited classes (date-gated gloss): 824.00 Bolivia/Political affairs 5; 738.00 Haiti (1950–59 schedule) 5; 816.01 El Salvador/Government 4; 738.02 Haiti 4; 737.00 Cuba 4; 723.00 Peru (1960–63 schedule) 4.
  Lots: 63D127 (2 docs) -> A1 3157, NAID 2363840, Subject and Country Files, Office of Central American and Panamanian Affairs, 1955–1963, Restricted–Possibly; 59D573 & 61D279 -> A1 1135, NAID 2108779, Subject Files of the Assistant Secretary for Inter-American Affairs, 1957–1959, Unrestricted; 62D418 -> A1 3147, NAID 2068466, 1959–1962, Restricted–Partly; 64D16, 66D95, 53D26, 63D75 as above; 72D192 -> A1 5376, NAID 631695, Speeches and Statements, 1961–1969, Unrestricted; 57D284 -> RG 43 Torquay (off topic, from a 1951 policy statement).
  Library: Eisenhower Library, Dulles Papers, General Telephone Conversations (frus1958-60v06/d235); Johnson Library, Papers of George W. Ball, Brazil 3/30/64–4/21/66 (frus1964-68v31/d205); Johnson Library, Tom Johnson Meeting Notes (frus1964-68v31/d452; presidential-library-catalog.json lists Papers of Tom Johnson, Meeting Notes series NAID 23657995, 1966–1968); Kennedy Library row (frus1961-63v15/d134) is the Berlin false positive.
- The offline stack barely reaches before 1940; the empty pre-1910 pointed-at channel is a property of that table, not an archival absence.

## M5. Searches for what FRUS does not hold

- Mexico's 1930 Estrada declaration itself: `MATCH 'Estrada AND recogni*'`, non-apparatus, dated 1929-01-01..1931-06-30 -> 2 docs, frus1929v03/d657 (Feb 1929, Morrow on Mexico–Nicaragua) and frus1932v05/d775 (June 1931, claims conventions): neither is the declaration (read, raw/). Corpus-wide `"Estrada doctrine"` -> 28 FTS rows, earliest frus1931v02/d228. The doctrine reaches FRUS second-hand (described in frus1948v09/d7, footnoted in frus1964-68v31/d512). Shelf: the Mexican foreign ministry's archive, not in the bundled data.
- The Department's 1947 study of recognition policy: frus1948v09/d7 says the RE study is "Not printed" (editors' insertion read in raw/frus1948v09__d7.txt); no file citation in that note, so no shelf can be named.
- Recognition practice after 1980: scope holds 1 document dated in the 1980s against 6,038 dated non-apparatus 1980s documents; `SELECT COUNT(*) ... date_iso>='1981-01-01'` non-apparatus -> 4,415. The corpus is not silent on the 1980s generally; it prints almost nothing on recognising coup governments then.
- The 1977-era shift toward recognising states rather than governments: `MATCH 'NEAR(recogni* states governments, 4)'`, non-apparatus, dated >=1969 -> 8 docs (frus1969-76ve04/d319, frus1969-76ve11p1/d434, frus1969-76ve11p2/d123, frus1977-80v22/d282, d285, d290, frus1977-80v23/d312, d329). Not read: reported as a lead, not a finding.

## M6. Reading

39 documents retrieved whole (captured length = length(body_text) for all 39; 482,314 characters in total), raw text in raw/<volume>__<document>.txt, retrieved by readdocs.py:
`SELECT header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?`.
Quoted: 24 passages from 22 documents (quotes.json), each verified by verifyq.py (exact, case-sensitive substring of header+dateline+source_note+body_text, whitespace-collapsed) -> verifyq.out, all 24 VERIFIED, all inside body_text.
Not read whole but excerpted/inspected: precB.out snippets (40 docs, 240-character windows).

## M7. Quotations (all VERIFIED, verifyq.out)

| id | document | date | passage (verbatim) | note |
|---|---|---|---|---|
| Q1 | frus1868p2/d632 | 1867-08-17 | "It has been the practice of this government to refrain from recognizing the various revolutionary changes which have occurred in the neighboring States of this continent until it had received satisfactory evidence of the acquiescence of the people concerned therein." | Seward, Colombia |
| Q2 | frus1895p1/d246 | 1895-11-06 | "the practice of this Government has been to enter into effective relations with the de facto government when it shall have been fully established with the general consent of the people." | Olney, Ecuador |
| Q3 | frus1895p1/d246 | 1895-11-06 | "being satisfied that the new Government is in possession of the executive forces of the nation, and administering the same with due regard for the obligations of international law and treaties, you will enter into full relations with it." | |
| Q4 | frus1913/d7 | 1913-03-12 | "Cooperation is possible only when supported at every turn by the orderly processes of just government based upon law, not upon arbitrary or irregular force." | Wilson statement of Mar 11, circulated |
| Q5 | frus1917/d379 | 1917-02-09 | "no Government except such as may be elected legally and established according to the Constitution shall be considered entitled to recognition." | Lansing, Tinoco |
| Q6 | frus1923v02/d345 | 1923-06-30 | "will not recognize any other Government which may come into power in any of the five Republics through a coup d’état or a revolution against a recognized Government, so long as the freely elected representatives of the people thereof have not constitutionally reorganized the country." | Hughes quoting Art. II |
| Q7 | frus1932v05/d618 | 1932-01-13 | "Martínez can under no circumstances be recognized. This is not due to any animus against Martínez, but because of the clear provisions of the Treaty." | Stimson (collection only) |
| Q8 | frus1921v02/d344 | 1921-06-08 | "when it appears that there is a government in Mexico willing to bind itself to the discharge of primary international obligations, concurrently with that act its recognition will take place." | Hughes, Obregón |
| Q9 | frus1930v01/d375 | 1930-09-17 | "the evidence has satisfied me that these provisional governments are de facto in control of their respective countries, and that there is no active resistance to their rule. Each of the present governments has also made it clear that it is its intention to fulfill its respective international obligations and to hold, in due course, elections to regularize its status." | Stimson |
| Q10 | frus1936v05/d112 | 1936-04-30 | "the United States should no longer be guided by Article II of the General Treaty of Peace and Amity of 1923 in extending or denying recognition to Governments in Central America" | quoting enclosed memo |
| Q11 | frus1934v05/d220 | 1934-01-17 | "recognition of the Government of Salvador by the Governments of Guatemala, Honduras and Nicaragua, and subsequently by the Government of the United States" | Welles |
| Q12 | frus1943v05/d33 | 1943-12-24 | "they do not proceed to the recognition of a new government instituted by force, before consulting among themselves for the purpose of determining whether this government complies with the Inter-American undertakings for the defense of the continent" | Guani transmits the resolution; translation |
| Q13 | frus1944v07/d428 | 1944-05-18 | "the Provisional Government of Bolivia wished to expel from Bolivia the most dangerous Axis aliens" | Hull |
| Q14 | frus1946v11/d773 | 1946-03-01 | "pointing out that junta controls machinery of Govt and is maintaining order, appears to enjoy popular support and has promised to fulfill its international commitments." | Byrnes, Haiti |
| Q15 | frus1948v09/d7 | 1948-03-15 | "(a) the effective control by the regime of the national territory and of the administration of the State, and (b) the ability of the regime to discharge the international obligations of the State." | PPS/24 (collection only) |
| Q16 | frus1948v09/d119 | 1948-12-16 | "An important consideration in this Govt’s approval Bogotá Res 35 was belief that non-recognition is not a suitable approach to much broader problem of dictatorships and use of force as a political procedure" | Lovett, Venezuela |
| Q17 | frus1961-63v12/d421 | 1962-07-27 | "What actions should we propose to representatives of the junta as necessary to permit us to resume relations and to recommend such resumption to other countries" | Ball, Peru (collection only) |
| Q18 | frus1961-63v12/d359 | 1963-10-04 | "to secure their agreement prior to our recognition or resumption of aid on following main points: 1. Free political activity of all non-Communist parties in preparation for OAS supervised elections in not more than one year" | Dominican Republic |
| Q19 | frus1964-68v31/d132 | 1966-06-28 | "whether the new regime promised to hold free elections, to honor its international obligations, and to respect human rights" | **EDITORS' FOOTNOTE** summarising Rio Resolution XXVI (1965), inside body_text |
| Q20 | frus1969-76v21/d361 | 1973-09-20 | "The new government is an established fact, so it’s okay to go ahead with recognition" | Porter, WSAG (collection only) |
| Q21 | frus1964-68v31/d512 | 1968-10-06 | "our developing practices as to responses to coups no longer fits exactly within the textbook doctrinal pattern" | Oliver (collection only) |
| Q22 | frus1949v02/d454 | 1949-02-07 | "there is some question whether suspension relations wld effectively encourage democratic processes or increase polit stability" | Acheson, Paraguay (collection only) |
| Q23 | frus1944v07/d1088 | 1944-10-24 | "recognition will not be extended to either Government until an exchange of information has taken place between this Government and that of the other American Republics" | Stettinius (collection only) |
| Q24 | frus1964-68v31/d132 | 1966-06-28 | "In keeping with international practice in such cases, diplomatic relations are suspended." | Department's own text |

## M8. Trace table (overview -> memo)

| overview item | memo line |
|---|---|
| "all 553 volumes", coverage | M1 coverage query |
| "about 940 documents in 87 volumes" | M2.2 total |
| "about four in five of the documents the wider net caught were on topic" | M2.3, 32 of 40 |
| "densest between 1910 and 1939, about six documents per thousand"; 1940s half one volume; 1950s under one per thousand | M2.5 table |
| "by force" no more common in recognition chapters than corpus | M2.4 |
| "nearly nine in ten" came-from rows decimal file | M4, 803 of 894 rows (scope docs with a row) |
| "about four in ten" glossed keys are Government subfiles | M4, 287 of 726 |
| El Salvador 108, Mexico 90, Bolivia | M4 top keys |
| pointed-at: "about one document in fourteen" | M4, 66 of 940 |
| lot shelves named | M4 lots |
| Estrada not printed; RE study not printed; post-1980 thin | M5 |
| Q1–Q6, Q8–Q14, Q16, Q18, Q19, Q24 quotations | M7 |
| 39 read whole, 24 passages verified | M6 |
| 26 documents in the collection; all cited docs in it | M9, checkcoll.out |
| Chile 1973: agreed 20 Sept to announce recognition 24 Sept; "an established fact" | M7 Q20; raw/frus1969-76v21__d361.txt |
| "28 documents" name the Estrada Doctrine, earliest 1931 | M5 (`MATCH '"Estrada doctrine"'`, earliest frus1931v02/d228, 1931-12-16) |
| Scope dated 1863 to 1980 | scope-range query: min frus1865p3/d695 1863-09-21 (an off-topic Path B doc), max frus1977-80v24/d115 1980-10-01 |

## M9. Collection

collection.fruscollection: 26 documents (cited.txt), each verified present in document_cache (python, tag verify-cited: all exist, all is_front_matter=0, is_editorial_note=0), no duplicates, no Ed2 volume; 24 excerpts = Q1–Q24, all VERIFIED. Every document cited in the overview is in the collection (checked with checkcoll.py -> checkcoll.out).
