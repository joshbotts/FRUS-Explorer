# Scope memo — recognition of Latin American governments that came to power by force

Run r10, 2026-10-25. Operator document: every number below carries its query, its counting surface and its denominator.
Run directory files named here are relative to the run directory (scripts/, out/, raw/). Every script that produced a
number is kept in scripts/ with its SQL in its header comment; every output is kept in out/.

## 0. Resources and checks run first

- Index copy: frus-copy-2026-10-25.db (read-only URI `file:...?mode=ro`); TEI corpus: 553 volume files; bundled JSON of build 1.0 (1776).
- Canary (first tool call): `SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;` returned `553|321749|1103|8481` — as required.
- Read-only proof (second call): `sqlite3 -readonly ... "BEGIN; CREATE TABLE zz(x); ROLLBACK;"` failed with `attempt to write a readonly database` — as required.
[T-COV] Coverage: 553 distinct volumes, 321,749 document_cache rows, 1,103 front-matter rows, 8,481 editorial-note rows. All 553 volumes of the series are present, so no count below is conditional on a partial library; every count is conditional on the 553 volumes as indexed on 2026-10-25.

## 1. The scope I chose and how I found it

**Question.** How did the United States decide whether to recognize governments that came to power by force in Latin America, and what did it ask of them before recognizing?

**Inclusion rule.** S2 = A1 ∪ (R2 ∩ LA), restricted to printed documents (is_front_matter = 0, is_editorial_note = 0, document_id GLOB 'd[0-9]*' or '*_d[0-9]*'), with the second editions frus1951-54IranEd2 and frus1969-76ve15p2Ed2 dropped (first editions kept; frus1977-80v09Ed2 is not in the set).

- **LA universe** (scripts/05_doc_paths.py → out/doc_paths.tsv). A document is in the Latin American universe when the path of editors' headings above it (from `SELECT volume_id, structure_json FROM volume_structures`) matches `Argentin|Bolivi|Brazil|Chile|Colombia|Costa Rica|Cuba|Dominican|Santo Domingo|Ecuador|Salvador|Guatemala|Haiti|Honduras|Mexic|Nicaragua|Panam|Paraguay|Peru\b|Peruvian|Uruguay|Venezuela|Central America|American Republics|Latin America|Western Hemisphere|Inter-American|South America|Soccer War` (case-insensitive), or when its volume's manifest title does (48 volumes; titles that also name the United Nations or an appendix of several subjects are flagged by path only). Structural rows of document_cache whose document_id is a chapter, compilation, section or appendix record (6,039 non-apparatus rows; `SELECT COUNT(*) FROM document_cache c WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND NOT (c.document_id GLOB 'd[0-9]*' OR c.document_id GLOB '*_d[0-9]*');` → 6039) carry a heading and the editors' lead footnote, not a document, and are excluded. Known leak: a chapter of the Berlin-crisis volume titled for the Cuban missile crisis is flagged Latin American by its heading (frus1961-63v15/d148 appeared in a referent sample).
- [T-A1] **A1 — the editors' recognition chapters** (scripts/02_heading_scan.py, scripts/03_heading_scan_la.py, scripts/07 candidate list in out/07_candidate_recog_headings.tsv, scripts/09b_build_scope_R2.py). I read every heading of the 553 volumes matching `recogni` (253 headings, out/02_headings_recogni.txt) and every Latin American heading matching force or recognition terms (203, out/03_headings_la_force.txt), took the 83 that name recognition, non-recognition, continuance of relations or the 1923 treaty, and kept the 56 whose subject is the recognition (or its refusal, withholding, or the policy governing it) of a Latin American government. I dropped other senses (meat-inspection labels, naturalization certificates, blockades, ship certificates, the Monroe Doctrine, Mexico as an "international person", asylum), state recognitions (Panama 1903, the Central American union of 1896) and multi-topic chapters in which recognition is one item among many (Mexico 1911, 1915; Haiti 1914, 1915; Nicaragua 1911; Paraguay 1912; Dominican Republic 1916; Honduras 1919; Guatemala 1920) — those chapters' recognition documents enter through R2. A1 = 1,339 documents in 56 chapters of 35 volumes, dated 1895-09-06 to 1950-06-01. After 1950 no Latin American heading names recognition except Haiti 1950, which is why the text rule is needed.

| chapter | documents kept | editors' heading (first 110 characters) |
|---|---|---|
| frus1895p1/ch41 | 4 | Recognition of de facto government |
| frus1899/ch123 | 46 | Revolution in Venezuela and recognition of de facto government |
| frus1900/ch33 | 9 | Recognition of new Government of Colombia |
| frus1900/ch36 | 4 | Recognition of new Government |
| frus1903/ch45 | 4 | Revolution in Santo Domingo, and recognition of new Government |
| frus1903/ch71 | 5 | Revolution in Honduras, and recognition of new Government |
| frus1904/ch55 | 7 | Recognition of the provisional government of the Dominican Republic |
| frus1907p2/ch5 | 11 | Recognition of the provisional Government of Honduras by the United States and Mexico |
| frus1911/ch69 | 37 | Revolution in Haiti—Recognition by the United States of the Leconte Government—Temporary refuge offered Pr |
| frus1912/ch58 | 4 | Death of President Leconte and recognition by the United States of President Auguste |
| frus1913/ch47 | 1 | Recognition of President Plaza by the United States |
| frus1914/ch124 | 19 | Political affairs: Revolution; resignation of President Billinghurst; recognition by the United States of the |
| frus1917/ch21 | 66 | Political affairs. Revolution; overthrow of President Alfredo Gonzáles by the Minister of War, Federico Tinoc |
| frus1919v01/ch37subch2 | 38 | Surrender of power by the Tinocos: assassination of Joaquín; departure of Federico, August 12—Succession of |
| frus1919v02/ch69subch1 | 39 | Presumptive election of Augusto B. Leguía as President—Overthrow of President Pardo, July 4, 1919; assumpti |
| frus1920v01/ch21subch1 | 31 | Coup d’état by the Republican Party, July 12, 1920—Attitude of the United States; understandings with Arg |
| frus1920v01/ch39 | 4 | Recognition of the Government of Costa Rica by the United States |
| frus1920v03/ch9 | 67 | Question of the recognition of the Provisional Government by the United States |
| frus1920v03/ch23 | 6 | Recognition of the Leguia government by the United States |
| frus1921v01/ch15 | 16 | Recognition of the Saavedra Government by the United States |
| frus1921v02/ch38 | 14 | Question of the recognition of the Government of General Obregon by the United States: Proposed Treaty of Amit |
| frus1921v02/ch39 | 24 | Attitude of other governments toward recognition of the Obregon Government |
| frus1922v02/ch32 | 7 | Recognition of the Orellana government by the United States |
| frus1922v02/ch50 | 12 | Question of the recognition of the government of General Obregon by the United States |
| frus1922v02/ch51 | 7 | Attitude of other governments toward recognition of the Obregon government |
| frus1923v02/ch37 | 24 | Recognition of the Government of General Obregón by the United States and the resumption of diplomatic relati |
| frus1925v02/ch7 | 4 | Withholding of recognition by the United States of the revolutionary government in Ecuador |
| frus1928v02/ch53 | 2 | Extension by the United States of de jure recognition to the Government of Ecuador |
| frus1931v02/ch31 | 24 | Recognition of constitutional government in Guatemala |
| frus1932v05/ch6 | 25 | Efforts of Costa Rica to effect the denunciation of the General Treaty of Peace and Amity, signed February 7, |
| frus1932v05/ch14 | 68 | Refusal of the United States to recognize the Martínez regime in El Salvador |
| frus1933v05/ch15 | 10 | Refusal of the United States to recognize the Martínez regime in El Salvador |
| frus1934v05/ch5 | 31 | Recognition of the Provisional Government of Cuba |
| frus1934v05/ch13 | 62 | Recognition of the Martínez Government of El Salvador by Guatemala, Honduras, and Nicaragua, and by the Unite |
| frus1936v05/ch5 | 8 | Decision of the Department of State that the United States should no longer be guided by article II of the Gen |
| frus1937v05/ch14 | 33 | Revolution in Bolivia; recognition of the Busch Government |
| frus1937v05/ch17 | 8 | Abrogation of Brazilian constitution and promulgation of a new one continuing President Vargas in office; cont |
| frus1937v05/ch28 | 20 | Forced resignation of President Paez of Ecuador; recognition of the Enriquez Government |
| frus1937v05/ch43 | 50 | Revolution in Paraguay; recognition of the Paiva Government |
| frus1940v05/ch37 | 7 | Refusal of the United States to indicate whether it would or would not recognize a future government of Cuba |
| frus1943v05/ch11 | 17 | Discussions leading to the recognition of the Government of General Pedro P. Ramirez |
| frus1943v05/ch18 | 9 | Non-recognition by the United States of the revolutionary regime established in Bolivia by the Movimiento Naci |
| frus1944v07/ch13 | 36 | Withholding of recognition from the regime of Edelmiro Farrell by the United States |
| frus1944v07/ch18 | 61 | Recognition by the United States and other American Republics of the revolutionary junta in Bolivia |
| frus1944v07/ch56 | 23 | Recognition by the United States and the other American Republics of the new government of Ecuador |
| frus1944v07/ch60 | 39 | Revolutions in El Salvador; policies of the United States and other American Republics regarding the right of |
| frus1944v07/ch62 | 28 | Revolution in Guatemala and recognition of a new regime by the United States and other American Republics |
| frus1945v09/ch13 | 65 | Problems arising in connection with the recognition of the Farrell government followed by the deterioration of |
| frus1945v09/ch57 | 9 | Recognition by the United States and other American Republics of the government of Osmín Aguirre y Salinas |
| frus1945v09/ch99 | 28 | Consultation concerning and recognition of the Venezuelan revolutionary junta |
| frus1946v11/ch13 | 53 | Concern of the United States with respect to the violence accompanying the Bolivian revolution and the problem |
| frus1946v11/ch52 | 8 | United States recognition of the new Haitian Government |
| frus1947v08/ch43 | 14 | The question of recognizing the Mancheno, the Suarez, and the Arosemena regimes in Ecuador |
| frus1947v08/ch63 | 39 | Political upheaval in Nicaragua: United States policies of nonintervention and nonrecognition |
| frus1948v09/ch5 | 49 | Continuance by the United States of diplomatic relations with new governments on the basis of the Bogota Resol |
| frus1950v02/ch21subch1 | 3 | Recognition by the United States of the military junta government of Haiti |

- [T-R2EXPR] **R2 — the recognition-of-a-government phrase family** (scripts/08_fts_family.py; expression in scripts/R2_expr.txt, 52 quoted phrases): `"recognition of the government" OR "recognition of the new government" OR "recognition of the provisional government" OR "recognition of the de facto government" OR "recognition of the revolutionary government" OR "recognition of the military government" OR "recognition of the junta" OR "recognition of the new junta" OR "recognition of the military junta" OR "recognition of the regime" OR "recognition of the new regime" OR "recognition of a government" OR "recognition of new governments" OR "recognition of governments" OR "recognition of de facto governments" OR "recognition to the government" OR "recognition to the new government" OR "recognition to the provisional government" OR "recognition to the junta" OR "recognition to the regime" OR "recognize the government" OR "recognize the new government" OR "recognize the provisional government" OR "recognize the de facto government" OR "recognize the revolutionary government" OR "recognize the military government" OR "recognize the junta" OR "recognize the new junta" OR "recognize the military junta" OR "recognize the regime" OR "recognize the new regime" OR "recognize a government" OR "recognize new governments" OR "recognize governments" OR "extend recognition" OR "accord recognition" OR "grant recognition" OR "withhold recognition" OR "nonrecognition" OR "non recognition" OR "question of recognition" OR "problem of recognition" OR "recognition policy" OR "policy of recognition" OR "recognition question" OR "recognition of president" OR "recognize president" OR "de facto recognition" OR "de jure recognition" OR "formal recognition" OR "recognition of his government" OR "recognize his government"`.
  SQL: `SELECT f.volume_id, f.document_id FROM frus_documents f JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id WHERE frus_documents MATCH :expr AND c.is_front_matter=0 AND c.is_editorial_note=0;` then, in the script, Ed2 dropped, structural rows dropped, and the LA flag applied.
[T-R2] R2 hits: 3,669 printed documents corpus-wide; 1,076 in the LA universe, in 114 volumes (out/08_fam_R2.txt).
[T-S2] S2 = 2,115 documents in 115 volumes, dated 1862-07-14 to 1980-10-05: A1 1,339 + R2∩LA 1,076 − overlap 300 (out/09b_scope_S2.txt; `cut -f1 out/scope_S2.tsv | sort -u | wc -l` → 115).
[T-S2DEC] S2 by decade (out/09b_scope_S2.txt; A1 share in brackets): 1860s 40 [0] · 1870s 20 [0] · 1880s 33 [0] · 1890s 75 [50] · 1900s 56 [40] · 1910s 324 [207] · 1920s 274 [215] · 1930s 507 [339] · 1940s 592 [485] · 1950s 61 [3] · 1960s 91 [0] · 1970s 39 [0] · 1980s 3 [0]; after 1949: 61 + 91 + 39 + 3 = 194.
- **Date span and periodisation.** Dates are document_dates.date_iso, the index's day for each document, derived from the TEI attribute frus:doc-dateTime-min (read as the document's own date where both name the same instant; checked on frus1930v01/d358–d360 against the TEI). Eras used below: E1 to 1912, E2 1913–1929, E3 1930–1942, E4 1943–1948, E5 1949–1960, E6 1961–1988.

## 2. Denominators

`SELECT substr(dd.date_iso,1,3)||'0s' AS decade, COUNT(*) FROM document_cache c JOIN document_dates dd ON dd.volume_id=c.volume_id AND dd.document_id=c.document_id WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND (c.document_id GLOB 'd[0-9]*' OR c.document_id GLOB '*_d[0-9]*') AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') AND dd.date_iso IS NOT NULL AND dd.date_iso<>'' AND dd.date_iso>='1860' GROUP BY 1 ORDER BY 1;`
→ 1860s 11,250 · 1870s 5,795 · 1880s 6,471 · 1890s 9,711 · 1900s 9,924 · 1910s 30,358 · 1920s 19,733 · 1930s 39,195 · 1940s 74,044 · 1950s 42,342 · 1960s 27,650 · 1970s 22,258 · 1980s 6,020 · 1990s 177. Total printed non-apparatus documents (Ed2 dropped): 305,390; none is undated once structural rows are excluded. The brief quotes 74,043 for the 1940s and 5,798 for the 1870s; this rule gives 74,044 and 5,795 (the brief's exact rule is not stated). Latin American universe (scripts/06_decades.py, out/06_decades.txt): 59,562 dated documents — 1860s 2,098 · 1870s 1,369 · 1880s 1,702 · 1890s 2,661 · 1900s 3,414 · 1910s 11,159 · 1920s 5,653 · 1930s 9,639 · 1940s 11,431 · 1950s 3,111 · 1960s 3,591 · 1970s 3,300 · 1980s 399. Era totals (out/13_conditions.txt): E1 13,987 · E2 14,104 · E3 13,851 · E4 6,993 · E5 3,849 · E6 6,778.

## 3. The recognition vocabulary: literal shares, referent tests, shape

### 3.1 R2 literal share (house rule (a))
Script scripts/10_literal_share.py; evenly spaced sample of 40 from the (volume_id, document_id)-sorted R2∩LA list (M = 1,076); text = header + dateline + source_note + body_text, whitespace-collapsed; Python `re` with IGNORECASE for both passes. Reading SQL (5 per call): `SELECT volume_id, document_id, header, dateline, source_note, body_text FROM document_cache WHERE (volume_id, document_id) IN (VALUES (?,?),...);`
- STRICT (the base phrases, single spaces; regex in scripts/R2_strict.txt):
[T-R2S] STRICT 30 of 40.
- TOLERANT (any inflection of recogni-/government/junta/regime/extend/accord/grant/withhold, any run of space, hyphen, comma, parenthesis or full stop between words; regex in scripts/R2_tolerant.txt):
[T-R2T] TOLERANT 40 of 40. Published form: tolerant 40 of 40, strict 30 of 40 beside it. The ten strict misses are all inflections or a hyphen: "recognized" in seven (frus1868p2/d256, frus1894/d296, frus1904/d231, frus1915/d468, frus1917/d425, frus1925v02/d293, frus1955-57v06/d354), "recognizing" (frus1944v07/d484), "non-recognition" (frus1947v08/d739) and "withholds recognition" (frus1969-76ve11p2/d153). On an earlier list of 1,080 (before structural rows were excluded) the tolerant share was 38 of 40; the two misses were a bracketed editorial insertion ("grant [recognition]", frus1937v05/d701) and a curly quotation mark ("“recognized” Government", frus1940v05/d92) — punctuation the tolerant rule does not allow, not inflections.
- Sample (out/10_share_R2.txt): frus1862/d594 frus1868p2/d256 frus1877/d226 frus1883/d458 frus1894/d296 frus1904/d231 frus1913/d1008 frus1913/d947 frus1914/d818 frus1915/d468 frus1917/d425 frus1920v01/d373 frus1920v03/d252 frus1922v02/d383 frus1925v02/d293 frus1927v03/d264 frus1930v02/d814 frus1931v02/d153 frus1931v02/d427 frus1932v05/d626 frus1933v04/d531 frus1934v04/d516 frus1934v05/d520 frus1936v05/d754 frus1937v05/d481 frus1940v05/d311 frus1944v07/d1081 frus1944v07/d227 frus1944v07/d386 frus1944v07/d484 frus1945v09/d878 frus1947v08/d739 frus1948v09/d77 frus1950v02/d529 frus1955-57v06/d354 frus1958-60v05mSupp/es_d37 frus1961-63v10/d38 frus1961-63v12/d362 frus1964-68v31/d512 frus1969-76ve11p2/d153

### 3.2 R2 referent test
A 1.000 tolerant share tests the stemmer, not the referent. I read the first tolerant context of each of the same 40 (scripts/11_kwic_sample.py → out/11_kwic_R2.txt) and asked: is this about recognizing (or not recognizing) a Latin American government that came to power by force or irregularly, or the policy governing that?
[T-R2REF] Referent: 35 of 40 yes. The five no: frus1894/d296 ("constitutionally recognized Government" as an adjective), frus1925v02/d293 (the 1923 treaty's ban on fomenting revolution against a recognized government), frus1933v04/d531 (non-recognition of territory, Leticia), frus1940v05/d311 (non-recognition of territory conquered by force), frus1944v07/d484 (the phrase sits only in an editors' footnote).

### 3.3 The broad family R, tried and dropped
R = `NEAR(recogn* govern*, 8) OR NEAR(recogn* regim*, 8) OR NEAR(recogn* junta*, 8) OR NEAR(recogn* administr*, 8) OR NEAR(recogn* presid*, 8) OR nonrecogn* OR "non recognit*"` (same SQL as R2). 14,744 printed documents corpus-wide; 3,559 in the LA universe (162 volumes; out/08_fam_R.txt).
[T-RREF] Literal share on 40 (out/10_share_R.txt): STRICT 31 of 40, TOLERANT 37 of 40 (misses: "governing", "régime" with an accent, quotation marks). Referent (out/11_kwic_R.txt, read): 20 of 40 — half the hits are "recognize the right", "recognized as belligerents", the Confederacy, contracts, territory. Dropped in favour of R2.

### 3.4 Recall check of R2
Telegrams drop articles ("recognize new government"), so I ran 28 further phrasings (scripts/R2_extra_expr.txt: telegraphic forms, "barred from recognition", "recognition will be extended", "before recognizing", "withholding recognition", "conditions for recognition", ...) with the same SQL (out/08_fam_R2extra.txt).
[T-RECALL] 469 printed documents corpus-wide, 213 in the LA universe (59 volumes), of which 50 are not already in S2 (out/33_R2extra_new.tsv; 2 in the 1870s, 1 in the 1890s, 12 in the 1910s, 3 in the 1920s, 12 in the 1930s, 6 in the 1940s, 2 in the 1950s, 10 in the 1960s, 2 in the 1970s) — about 2 per cent of S2. S2 was not rebuilt. Of the 52 documents in the collection, 44 are in S2; of the 8 outside it, 3 are among these 50 (frus1931v02/d232, frus1943v05/d33, frus1964-68v31/d135) and 5 were reached only by reading chapters and cross-references (frus1913/d7 and frus1913/d1028, which say "recognize and ... assist"; frus1914/d544, "recognition by the United States will be granted"; frus1933v05/d508, "criteria of Cuban recognition"; frus1977-80v24/d160, whose recognition wording is in a footnote).

### 3.5 Shape by decade (R2, index text)
Script scripts/12_rates.py (out/12_rates_R2.txt). Numerator: R2 documents in the decade; denominator: dated printed documents of the decade (§2). Index text = body_text including editors' footnotes (see §5 for the split).

| decade | LA hits | LA denominator | per 1,000 | top volume (share of hits) | corpus hits | corpus denominator | per 1,000 |
|---|---|---|---|---|---|---|---|
| 1860s | 40 | 2,098 | 19.1 | frus1868p2, 14 of 40 | 79 | 11,250 | 7.0 |
| 1870s | 20 | 1,369 | 14.6 | frus1877, 5 of 20 | 47 | 5,795 | 8.1 |
| 1880s | 33 | 1,702 | 19.4 | frus1881, 18 of 33 | 54 | 6,471 | 8.3 |
| 1890s | 29 | 2,661 | 10.9 | frus1892, 7 of 29 | 73 | 9,711 | 7.5 |
| 1900s | 28 | 3,414 | 8.2 | frus1907p2, 10 of 28 | 41 | 9,924 | 4.1 |
| 1910s | 145 | 11,159 | 13.0 | frus1913, 35 of 145 | 325 | 30,358 | 10.7 |
| 1920s | 115 | 5,653 | 20.3 | frus1920v01, 16 of 115 | 316 | 19,733 | 16.0 |
| 1930s | 257 | 9,639 | 26.7 | frus1932v05, 44 of 257 | 645 | 39,195 | 16.5 |
| 1940s | 216 | 11,431 | 18.9 | frus1944v07, 92 of 216 | 1,012 | 74,044 | 13.7 |
| 1950s | 60 | 3,111 | 19.3 | frus1952-54v04, 12 of 60 | 475 | 42,342 | 11.2 |
| 1960s | 91 | 3,591 | 25.3 | frus1964-68v31, 21 of 91 | 350 | 27,650 | 12.7 |
| 1970s | 39 | 3,300 | 11.8 | frus1969-76v21, 11 of 39 | 225 | 22,258 | 10.1 |
| 1980s | 3 | 399 | 7.5 | frus1977-80v24, 2 of 3 | 26 | 6,020 | 4.3 |

Thin cells: the 1870s (20 hits), 1900s (28) and 1980s (3) rest on a handful of volumes; the 1880s rate is 18 of 33 one volume (frus1881, the War of the Pacific). The 1940s rate leans on frus1944v07 (92 of 216).

## 4. What was asked: condition families

Script scripts/13_conditions.py (census over every S2 hit; SQL per family: `SELECT f.volume_id, f.document_id FROM frus_documents f JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id WHERE frus_documents MATCH :expr AND c.is_front_matter=0 AND c.is_editorial_note=0;` texts read 15 per call with `SELECT volume_id, document_id, header, dateline, source_note, body_text FROM document_cache WHERE (volume_id, document_id) IN (VALUES ...)`); scripts/16_conditions_in_R2.py restricts to R2 documents. Literal shares are a CENSUS of each family's S2 hits (Python `re`, IGNORECASE, on header+dateline+source_note+body_text, whitespace-collapsed); the strict and tolerant regexes of each family are in scripts/conditions.json. All families clear 0.80 tolerant; C3_constitutional is lowest at 162 of 178; reading 8 of its 16 misses (FTS snippets, logged): "constituted Government" (the index folds constituted, constitution and constitutional to one stem), "constitutional régime" with an accent the tolerant regex did not allow, and "Constitution" followed by other words.

| family | FTS expression | S2 hits (census) | STRICT | TOLERANT | LA-universe hits |
|---|---|---|---|---|---|
| C1_obligations | `"international obligations" OR "treaty obligations" OR "international engagements"` | 156 | 152 of 156 | 156 of 156 | 654 |
| C2_elections | `"free elections" OR "hold elections" OR "holding of elections" OR "elections be held" OR "elections will be held" OR "elections would be held" OR "call elections" OR "calling of elections" OR "constitutional elections" OR "general elections" OR "presidential elections" OR "popular elections" OR "early elections"` | 164 | 123 of 164 | 161 of 164 | 1380 |
| C3_constitutional | `"constitutional government" OR "constitutional order" OR "constitutional regime" OR "constitutional normality" OR "return to constitutional" OR "constitutional procedure" OR "constitutional processes" OR "constitutional means"` | 178 | 146 of 178 | 162 of 178 | 1107 |
| C4_control_defacto | `"de facto" OR "in control" OR "effective control" OR "control of the country" OR "control of the government" OR "control of the situation" OR "control of the territory"` | 326 | 321 of 326 | 326 of 326 | 1777 |
| C5_popular_consent | `"acquiescence of the people" OR "consent of the people" OR "will of the people" OR "support of the people" OR "popular support" OR "assent of the people" OR acquiesc*` | 127 | 125 of 127 | 127 of 127 | 1288 |
| C6_lives_property | `"lives and property" OR "life and property" OR "american interests" OR "foreign interests"` | 96 | 91 of 96 | 96 of 96 | 1975 |
| C7_consultation | `NEAR(consult* republ*, 10) OR "resolution xxii" OR guani OR "emergency advisory committee"` | 91 | 88 of 91 | 91 of 91 | 579 |
| C8_axis | `axi* OR nazi*` | 110 | 107 of 110 | 110 of 110 | 1344 |
| C9_communist | `communist*` | 147 | 136 of 147 | 147 of 147 | 3037 |
| C10_liberties | `"human rights" OR "civil liberties" OR "political prisoners" OR "constitutional guarantees" OR "freedom of the press" OR "individual liberties" OR "civil rights"` | 87 | 81 of 87 | 86 of 87 | 1486 |
| C11_claims_property | `"american claims" OR "claims commission" OR "claims convention" OR expropriat* OR confiscat* OR "article 27"` | 54 | 43 of 54 | 53 of 54 | 917 |
| C12_treaty_rule | `"peace and amity" OR "treaty of 1923" OR "treaty of 1907" OR "1923 treaty" OR "1907 treaty" OR "washington treaties" OR "washington conventions" OR tobar*` | 134 | 123 of 134 | 134 of 134 | 395 |
| C13_bogota_continuance | `"bogota resolution" OR "resolution xxxv" OR "resolution 35" OR "continuance of relations" OR "continuation of relations" OR "continuity of relations" OR "continuance of diplomatic relations" OR "continuation of diplomatic relations" OR "continuity of diplomatic relations" OR "resumption of relations" OR "resumption of diplomatic relations" OR "continue relations" OR "continue diplomatic relations"` | 70 | 65 of 70 | 69 of 70 | 213 |

Within R2 documents (documents in the LA universe using recognition-of-a-government phrasing), by era: FTS-matched N of M (tolerant-confirmed in brackets). Era denominators M: E1 159 · E2 251 · E3 266 · E4 189 · E5 98 · E6 113 (out/16_conditions_in_R2.txt).

| family | E1 to 1912 | E2 1913–29 | E3 1930–42 | E4 1943–48 | E5 1949–60 | E6 1961–88 |
|---|---|---|---|---|---|---|
| C1_obligations | 12 of 159 [12] | 17 of 251 [17] | 29 of 266 [29] | 20 of 189 [20] | 24 of 98 [24] | 18 of 113 [18] |
| C2_elections | 10 of 159 [9] | 20 of 251 [20] | 14 of 266 [13] | 14 of 189 [14] | 30 of 98 [30] | 27 of 113 [27] |
| C3_constitutional | 22 of 159 [19] | 35 of 251 [32] | 19 of 266 [16] | 8 of 189 [8] | 21 of 98 [19] | 30 of 113 [29] |
| C4_control_defacto | 35 of 159 [35] | 60 of 251 [60] | 44 of 266 [44] | 36 of 189 [36] | 30 of 98 [30] | 24 of 113 [24] |
| C5_popular_consent | 23 of 159 [23] | 18 of 251 [18] | 20 of 266 [20] | 16 of 189 [16] | 15 of 98 [15] | 12 of 113 [12] |
| C6_lives_property | 17 of 159 [17] | 36 of 251 [36] | 13 of 266 [13] | 2 of 189 [2] | 8 of 98 [8] | 1 of 113 [1] |
| C7_consultation | 2 of 159 [2] | 0 of 251 [0] | 5 of 266 [5] | 48 of 189 [48] | 5 of 98 [5] | 2 of 113 [2] |
| C8_axis | 0 of 159 [0] | 1 of 251 [1] | 3 of 266 [3] | 47 of 189 [47] | 3 of 98 [3] | 1 of 113 [1] |
| C9_communist | 0 of 159 [0] | 0 of 251 [0] | 20 of 266 [20] | 10 of 189 [10] | 53 of 98 [53] | 45 of 113 [45] |
| C10_liberties | 4 of 159 [4] | 3 of 251 [3] | 5 of 266 [5] | 11 of 189 [11] | 13 of 98 [13] | 32 of 113 [32] |
| C11_claims_property | 5 of 159 [5] | 25 of 251 [25] | 2 of 266 [2] | 1 of 189 [0] | 2 of 98 [2] | 0 of 113 [0] |
| C12_treaty_rule | 4 of 159 [4] | 12 of 251 [12] | 69 of 266 [69] | 1 of 189 [1] | 0 of 98 [0] | 0 of 113 [0] |
| C13_bogota_continuance | 3 of 159 [3] | 8 of 251 [8] | 2 of 266 [2] | 8 of 189 [8] | 15 of 98 [15] | 15 of 113 [14] |

Within S2 (all scope documents) and in the LA universe (baseline), by era: S2 N of M / LA N of M (out/13_conditions.txt). S2 era denominators: E1 273 · E2 549 · E3 523 · E4 556 · E5 101 · E6 113.

| family | E1_to1912 | E2_1913-29 | E3_1930-42 | E4_1943-48 | E5_1949-60 | E6_1961-88 |
|---|---|---|---|---|---|---|
| C1_obligations | 18 of 273 / 153 of 13987 | 20 of 549 / 99 of 14104 | 40 of 523 / 158 of 13851 | 36 of 556 / 73 of 6993 | 24 of 101 / 84 of 3849 | 18 of 113 / 87 of 6778 |
| C2_elections | 11 of 273 / 167 of 13987 | 37 of 549 / 276 of 14104 | 21 of 523 / 132 of 13851 | 38 of 556 / 91 of 6993 | 30 of 101 / 188 of 3849 | 27 of 113 / 526 of 6778 |
| C3_constitutional | 24 of 273 / 279 of 13987 | 50 of 549 / 250 of 14104 | 27 of 523 / 119 of 13851 | 26 of 556 / 61 of 6993 | 21 of 101 / 117 of 3849 | 30 of 113 / 281 of 6778 |
| C4_control_defacto | 52 of 273 / 294 of 13987 | 92 of 549 / 550 of 14104 | 63 of 523 / 259 of 13851 | 65 of 556 / 164 of 6993 | 30 of 101 / 176 of 3849 | 24 of 113 / 334 of 6778 |
| C5_popular_consent | 27 of 273 / 354 of 13987 | 23 of 549 / 171 of 14104 | 26 of 523 / 232 of 13851 | 24 of 556 / 84 of 6993 | 15 of 101 / 158 of 3849 | 12 of 113 / 289 of 6778 |
| C6_lives_property | 26 of 273 / 530 of 13987 | 43 of 549 / 774 of 14104 | 14 of 523 / 403 of 13851 | 4 of 556 / 91 of 6993 | 8 of 101 / 117 of 3849 | 1 of 113 / 60 of 6778 |
| C7_consultation | 2 of 273 / 24 of 13987 | 0 of 549 / 16 of 14104 | 5 of 523 / 238 of 13851 | 77 of 556 / 223 of 6993 | 5 of 101 / 49 of 3849 | 2 of 113 / 29 of 6778 |
| C8_axis | 0 of 273 / 15 of 13987 | 1 of 549 / 10 of 14104 | 5 of 523 / 461 of 13851 | 100 of 556 / 804 of 6993 | 3 of 101 / 24 of 3849 | 1 of 113 / 30 of 6778 |
| C9_communist | 0 of 273 / 3 of 13987 | 0 of 549 / 4 of 14104 | 26 of 523 / 124 of 13851 | 23 of 556 / 220 of 6993 | 53 of 101 / 1096 of 3849 | 45 of 113 / 1590 of 6778 |
| C10_liberties | 7 of 273 / 144 of 13987 | 6 of 549 / 69 of 14104 | 5 of 523 / 88 of 13851 | 24 of 556 / 94 of 6993 | 13 of 101 / 160 of 3849 | 32 of 113 / 931 of 6778 |
| C11_claims_property | 5 of 273 / 155 of 13987 | 44 of 549 / 493 of 14104 | 2 of 523 / 173 of 13851 | 1 of 556 / 40 of 6993 | 2 of 101 / 25 of 3849 | 0 of 113 / 31 of 6778 |
| C12_treaty_rule | 4 of 273 / 60 of 13987 | 12 of 549 / 107 of 14104 | 116 of 523 / 217 of 13851 | 2 of 556 / 5 of 6993 | 0 of 101 / 6 of 3849 | 0 of 113 / 0 of 6778 |
| C13_bogota_continuance | 3 of 273 / 22 of 13987 | 12 of 549 / 31 of 14104 | 2 of 523 / 20 of 13851 | 21 of 556 / 35 of 6993 | 17 of 101 / 34 of 3849 | 15 of 113 / 71 of 6778 |

### 4.1 Referent tests for the families the overview argues from
Script scripts/17_referent_kwic.py: 15 evenly spaced documents from the family's R2 documents in the window, first tolerant context read (out/17_ref_*.txt). Question: does the mention bear on the recognition decision (a condition sought, an assurance given, or a stated test)?
[T-REF-C12] C12 treaty rule, 1930–1942 (69 R2 documents): 15 of 15 yes.
[T-REF-C7] C7 consultation, 1943–1948 (48): 12 of 15 yes (no: frus1943v05/d22, Guani's report on Argentina; frus1944v07/d280, consultation on the world organization; frus1945v09/d72, consultation in case of aggression).
[T-REF-C2] C2 elections, 1949–1988 (57): 7 of 15 yes (yes: frus1955-57v06/d349, frus1955-57v07/d465, es_d26, es_d43, d273a, frus1964-68v31/d152, frus1977-80v15/d263; the others mention elections as background, and one is the Berlin document that leaks into the LA universe).
[T-REF-C10] C10 civil liberties and human rights, 1961–1988 (32): 8 of 15 yes (d273a, frus1961-63v12/d363, d421, frus1964-68v31/d137, d141, d516, frus1977-80v24/d133, d137).
[T-REF-C9] C9 communist, 1949–1988 (98): 5 of 15 yes (frus1952-54v04/d327, es_d26, es_d37, frus1961-63v12/d425, frus1964-68v32/d31); the rest are general Cold War reporting. The LA baseline is itself high (1,096 of 3,849 LA documents in 1949–1960), so this family largely measures the period's vocabulary.

### 4.2 The statements the overview makes from these tables (R2 documents, by era)
[T-C12] Treaty rule: 69 of 266 in 1930–1942 (about one in four); 12 of 251 in 1913–1929 and 4 of 159 to 1912 (about one in twenty or fewer); 1 of 189, 0 of 98, 0 of 113 after 1942.
[T-C11] Claims, expropriation, confiscation, claims conventions: 25 of 251 in 1913–1929 (about one in ten); 5 of 159, 2 of 266, 1 of 189, 2 of 98, 0 of 113 in the other eras.
[T-C7C8] Consultation: 48 of 189 in 1943–1948; Axis: 47 of 189 in 1943–1948 (each about one in four); other eras: consultation 2 of 159, 0 of 251, 5 of 266, 5 of 98, 2 of 113; Axis 0, 1, 3, 3, 1 (the highest, 5 of 98, is about five in a hundred).
[T-C1C2] International obligations: 24 of 98 in 1949–1960 (about one in four) against 78 of 865 before 1949 (12+17+29+20; about one in ten). Elections: 30 of 98 in 1949–1960 (about three in ten) and 27 of 113 after 1961, against 58 of 865 before 1949 (10+20+14+14; fewer than one in ten).
[T-C10] Civil liberties or human rights: 32 of 113 after 1961 (about three in ten); before 1949 4 of 159, 3 of 251, 5 of 266, 11 of 189 (one in twenty or fewer in each era).
[T-C9] Communist: 53 of 98 in 1949–1960 (about half), 45 of 113 after 1961 (two in five); referent 5 of 15 (§4.1).

## 5. The TEI surface: spelling variants, document text against footnotes, false friends

Scripts: scripts/28_tei_scan.py (one pass over all 553 volume files with lxml; per-document counts in out/tei/<volume>.tsv, columns in out/tei_columns.txt), scripts/31_tei_aggregate.py (out/31_tei_aggregate.txt), scripts/35_compare_tei_v1_v2.py (out/35_compare_tei_v1_v2.txt).
**Counting surface.** Tag-stripped, whitespace-collapsed text of each `<div type="document">`, split in two: DOC = the document's own text, every descendant text except `<note>` subtrees (source note and footnotes) and the document's own `<head>` (the editors' title); NOTE = the editors' footnotes (`<note>` other than type="source"). Variants are matched with Python `re`, CASE-SENSITIVE, word-bounded, one regex per variant (listed in the script). Text fragments are concatenated with no separator and then whitespace-collapsed (scan v2). A first scan (v1, kept in out/tei_v1_spacejoin/) joined fragments with a space; the recognition-family counts moved by at most 5 occurrences per variant between v1 and v2 (largest: "recognizing" 5,117 → 5,122 in DOC), but the control phrase "Department of State" moved from 152,703 to 136,160 occurrences, because markup such as line breaks inside datelines separates words without whitespace. The control count is therefore surface-sensitive by about 11 per cent; the variant counts are not.
All 553 files scanned; every TEI document div matched an index row (0 unmatched); 305,390 printed non-apparatus documents counted (Ed2 dropped), equal to the SQL total of §2.

[T-CTRL] Controls in the same pass: positive "Department of State" (whole div) occurs in 549 of 551 volumes (Ed2 dropped); the two without it are frus1919Parisv05 (the raw file contains no occurrence: `grep -c "Department of State"` → 0, logged) and frus1919Parisv13 (39 raw occurrences, all outside its 2 document divs). Negative "ZZZ_IMPOSSIBLE_ZZZ": 0 occurrences.

**Variant split** (occurrences on DOC | NOTE; documents with the variant in DOC), LA universe (59,562 documents), S2 (2,115) and A1 (1,339):

| variant | LA DOC | LA NOTE | LA docs | S2 DOC | S2 NOTE | S2 docs | A1 DOC | A1 NOTE | A1 docs |
|---|---|---|---|---|---|---|---|---|---|
| recognize | 3460 | 42 | 2631 | 725 | 17 | 448 | 231 | 4 | 178 |
| recognized | 4932 | 54 | 3466 | 798 | 11 | 460 | 232 | 4 | 167 |
| recognizes | 940 | 3 | 826 | 64 | 0 | 55 | 20 | 0 | 19 |
| recognizing | 835 | 20 | 732 | 190 | 10 | 154 | 73 | 3 | 64 |
| Recognize_cap | 127 | 6 | 114 | 15 | 1 | 6 | 2 | 0 | 2 |
| recognise | 8 | 0 | 8 | 0 | 0 | 0 | 0 | 0 | 0 |
| recognised | 13 | 0 | 11 | 0 | 0 | 0 | 0 | 0 | 0 |
| recognises | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| recognising | 2 | 0 | 2 | 0 | 0 | 0 | 0 | 0 | 0 |
| recognition | 5042 | 182 | 2802 | 2695 | 123 | 1109 | 1263 | 40 | 545 |
| Recognition_cap | 183 | 7 | 145 | 89 | 5 | 72 | 19 | 4 | 15 |
| RECOGNITION_caps | 9 | 1 | 4 | 0 | 1 | 0 | 0 | 0 | 0 |
| nonrecognition | 67 | 3 | 60 | 67 | 3 | 60 | 17 | 0 | 12 |
| non-recognition | 144 | 6 | 113 | 144 | 6 | 113 | 45 | 2 | 36 |
| non_recognition_space | 1 | 0 | 1 | 1 | 0 | 1 | 0 | 0 | 0 |
| Nonrecognition_cap | 1 | 0 | 1 | 1 | 0 | 1 | 1 | 0 | 1 |
| unrecognized | 39 | 2 | 38 | 13 | 0 | 12 | 8 | 0 | 7 |
| de_facto | 1480 | 19 | 944 | 419 | 13 | 227 | 174 | 7 | 123 |
| de-facto | 2 | 0 | 2 | 1 | 0 | 1 | 0 | 0 | 0 |
| defacto | 2 | 0 | 2 | 0 | 0 | 0 | 0 | 0 | 0 |
| de_jure | 119 | 1 | 85 | 32 | 1 | 24 | 12 | 1 | 8 |
| coup_detat | 330 | 18 | 239 | 151 | 4 | 81 | 72 | 3 | 46 |
| coup_detat_noapos | 1 | 0 | 1 | 1 | 0 | 1 | 0 | 0 | 0 |
| coup_bare | 1863 | 142 | 685 | 268 | 13 | 82 | 26 | 2 | 21 |
| golpe | 91 | 5 | 58 | 4 | 1 | 4 | 0 | 0 | 0 |
| cuartelazo | 4 | 0 | 1 | 4 | 0 | 1 | 0 | 0 | 0 |
| junta | 1399 | 76 | 518 | 265 | 14 | 73 | 35 | 5 | 19 |
| Junta_cap | 2168 | 204 | 708 | 603 | 36 | 180 | 345 | 18 | 118 |
| JUNTA_caps | 3 | 0 | 3 | 0 | 0 | 0 | 0 | 0 | 0 |
| by_force | 748 | 5 | 598 | 77 | 4 | 63 | 22 | 2 | 20 |
| force_of_arms | 154 | 2 | 134 | 12 | 0 | 10 | 1 | 0 | 1 |
| international_obligations | 509 | 11 | 420 | 169 | 7 | 131 | 78 | 1 | 67 |
| free_elections | 490 | 18 | 368 | 50 | 2 | 44 | 17 | 0 | 15 |
| CTRL_DeptOfState | 21602 | 0 | 15673 | 582 | 0 | 387 | 176 | 0 | 145 |
| CTRL_impossible | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

(CTRL_ rows count the whole div, footnotes included, in the DOC column.) Reading of the split: the British -s spellings are negligible (23 occurrences in the LA universe); the hyphenated "non-recognition" (144 in LA document text) outnumbers the closed "nonrecognition" (67), and the index folds both, so an index count cannot report this split; "de facto" (1,480) dwarfs "de-facto" (2) and "defacto" (2); "coup d’état" with an apostrophe (330) against 1 without; capitalized "Junta" (2,168) outnumbers "junta" (1,399).

[T-APP] Document text against footnotes (recognition family = the 17 recognize/recognise/recognition/non-recognition/unrecognized variants summed): S2 documents with a form in their own text 1,427 of 2,115; in footnotes 124; only in footnotes 23. Occurrences in footnotes by era, S2: 1 of 688 (to 1912), 2 of 1,013 (1913–29), 10 of 1,268 (1930–42), 75 of 996 (1943–48), 54 of 530 (1949–60), 35 of 484 (1961–88) — at most about one in ten; LA universe: 9 of 4,259, 12 of 2,794, 13 of 2,867, 115 of 1,844, 84 of 1,699, 93 of 2,666. The editors' apparatus therefore barely moves the recognition counts; the index-based rates of §3.5, which include footnotes, are not materially inflated by them.

[T-FF] FALSE-FRIEND TEST (documents with the term in DOC text; A1 = the on-topic recognition chapters, LA = Latin American universe, ALL = corpus):
- recognition family: A1 671 of 1,339 (50 per cent) · LA 7,900 of 59,562 (13 per cent) · ALL 47,186 of 305,390 (15 per cent) — about four times the LA baseline: the term measures the question.
- control "Department of State" (whole div): A1 145 of 1,339 (11 per cent) · LA 15,673 of 59,562 (26 per cent) · ALL 85,411 of 305,390 (28 per cent) — below baseline in the on-topic chapters, as a neutral phrase should be.
- the question's own phrase "by force": A1 20 of 1,339 (1.5 per cent) · LA 598 of 59,562 (1.0 per cent) · ALL 3,579 of 305,390 (1.2 per cent) — barely above the baseline: it measures the corpus, not the question, and I did not use it to search.
- the documents' own terms: "coup d’état" A1 46 of 1,339 (3.4 per cent) against LA 239 of 59,562 (0.40 per cent), about 8.6 times; "de facto" A1 123 of 1,339 (9.2 per cent) against LA 944 of 59,562 (1.6 per cent), about 5.8 times; capitalized "Junta" A1 118 against LA 708 (about 7.4 times), lowercase "junta" A1 19 against LA 518 (about 1.6 times).

**Decade shape of the word itself** (TEI DOC surface, all senses of recognize/recognition, LA documents with a form ÷ LA dated documents): 1860s 331 of 2,098 (158 per 1,000; frus1868p2 90 of 331) · 1870s 256 of 1,369 (187) · 1880s 310 of 1,702 (182) · 1890s 369 of 2,661 (139) · 1900s 429 of 3,414 (126) · 1910s 972 of 11,159 (87) · 1920s 597 of 5,653 (106) · 1930s 1,177 of 9,639 (122) · 1940s 1,218 of 11,431 (107; frus1944v07 252 of 1,218) · 1950s 644 of 3,111 (207; frus1952-54v04 147 of 644) · 1960s 780 of 3,591 (217) · 1970s 733 of 3,300 (222) · 1980s 79 of 399 (198). This counts every sense of the word (recognize a right, a claim, a fact); it is the false-friend baseline, not the referent, and is not used in the overview.

## 6. Searches behind "what FRUS cannot give"

[T-GUANI] Named doctrines, one UNION query over the whole corpus, non-apparatus, with both controls in the same pass:
Full SQL, as run (one statement): `SELECT 'Mann+Notre Dame (1964-68 vols)' AS search, COUNT(*), group_concat(f.volume_id||'/'||f.document_id, ' ') FROM frus_documents f JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id WHERE frus_documents MATCH '"notre dame" AND mann' AND c.is_front_matter=0 AND c.is_editorial_note=0 UNION ALL SELECT 'September 19, 1949 + recognition', COUNT(*), group_concat(f.volume_id||'/'||f.document_id, ' ') FROM frus_documents f JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id WHERE frus_documents MATCH '("september 19, 1949" OR "september 19") AND recogn* AND (acheson OR secretary)' AND f.volume_id IN ('frus1949v02','frus1950v02','frus1951v02') AND c.is_front_matter=0 AND c.is_editorial_note=0 UNION ALL SELECT 'Senate Resolution 205 / Cranston', COUNT(*), group_concat(f.volume_id||'/'||f.document_id, ' ') FROM frus_documents f JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id WHERE frus_documents MATCH '"resolution 205" OR "cranston resolution"' AND c.is_front_matter=0 AND c.is_editorial_note=0 UNION ALL SELECT 'Guani doctrine', COUNT(*), group_concat(f.volume_id||'/'||f.document_id, ' ') FROM frus_documents f JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id WHERE frus_documents MATCH '"guani doctrine"' AND c.is_front_matter=0 AND c.is_editorial_note=0 UNION ALL SELECT 'CTRL Department of State (non-apparatus)', COUNT(*), '' FROM frus_documents f JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id WHERE frus_documents MATCH '"department of state"' AND c.is_front_matter=0 AND c.is_editorial_note=0 UNION ALL SELECT 'CTRL ZZZ_IMPOSSIBLE_ZZZ', COUNT(*), '' FROM frus_documents f WHERE frus_documents MATCH '"ZZZ_IMPOSSIBLE_ZZZ"';` → rows: Mann+Notre Dame 1 (frus1964-68v31/d17) · September 19, 1949 + recognition 12 · Senate Resolution 205 / Cranston 3 · "guani doctrine" 0 · CTRL "department of state" (non-apparatus) 94,049 documents · CTRL "ZZZ_IMPOSSIBLE_ZZZ" 0. A zero needs no literal share; the controls in the same statement show it can return rows. The practice itself is printed as Resolution XXII (frus1943v05/d33). (An earlier run of named doctrines without the apparatus exclusion gave Tobar 88, Betancourt doctrine 3, Larreta 30, Estrada doctrine 28, Resolution XXVI 10, Senate Resolution 205 3, Guani doctrine 0, controls 98,970 and 0; those counts are not published, their literal and referent shares not having been tested — Tobar is also a surname. That earlier SQL, as run: `SELECT 'Tobar', COUNT(*) FROM frus_documents WHERE frus_documents MATCH 'tobar' UNION ALL SELECT 'Betancourt doctrine', COUNT(*) FROM frus_documents WHERE frus_documents MATCH '"betancourt doctrine"' UNION ALL SELECT 'Larreta', COUNT(*) FROM frus_documents WHERE frus_documents MATCH 'larreta' UNION ALL SELECT 'Estrada doctrine', COUNT(*) FROM frus_documents WHERE frus_documents MATCH '"estrada doctrine"' UNION ALL SELECT 'Resolution XXVI', COUNT(*) FROM frus_documents WHERE frus_documents MATCH '"resolution xxvi" OR "resolution 26"' UNION ALL SELECT 'Senate Resolution 205', COUNT(*) FROM frus_documents WHERE frus_documents MATCH '"senate resolution 205" OR "resolution 205" OR "cranston resolution"' UNION ALL SELECT 'Guani doctrine', COUNT(*) FROM frus_documents WHERE frus_documents MATCH '"guani doctrine"' UNION ALL SELECT 'CTRL Department of State', COUNT(*) FROM frus_documents WHERE frus_documents MATCH '"department of state"' UNION ALL SELECT 'CTRL ZZZ_IMPOSSIBLE_ZZZ', COUNT(*) FROM frus_documents WHERE frus_documents MATCH '"ZZZ_IMPOSSIBLE_ZZZ"';`.)

[T-STMT] Statements cited but not printed. FTS hits (non-apparatus) and a census of every hit (scripts/37_cited_statements.py → out/37_cited_statements.txt; Python `re`, case-sensitive):
- Acheson's address of 19 September 1949: the second SELECT of the statement above (`... WHERE frus_documents MATCH '("september 19, 1949" OR "september 19") AND recogn* AND (acheson OR secretary)' AND f.volume_id IN ('frus1949v02','frus1950v02','frus1951v02') AND c.is_front_matter=0 AND c.is_editorial_note=0`) → 12 documents; literal "September 19" 12 of 12; referent (refers to the Acheson address) 6 of 12: frus1949v02/d444, d446, d448, d467, frus1950v02/d329, d334 (the others are an airgram date, a Bulletin issue date, a memorandum date and General Assembly opening dates). None prints the address; the editors' footnotes (frus1949v02/d444, d467; frus1950v02/d329) point to the Department of State Bulletin, 26 September 1949, p. 462.
- Mann's Notre Dame speech: the first SELECT of the statement above (`... MATCH '"notre dame" AND mann' AND c.is_front_matter=0 AND c.is_editorial_note=0`, whole corpus) → 1 document, frus1964-68v31/d17, literal 1 of 1; its footnote points to the Department of State Bulletin, 29 June 1964, pp. 995–1000.
- Senate Resolution 205: the third SELECT of the statement above (`... MATCH '"resolution 205" OR "cranston resolution"' AND c.is_front_matter=0 AND c.is_editorial_note=0`, whole corpus) → 3 documents; literal 2 of 3 (frus1969-76ve10/d14 "The Cranston Resolution helps"; frus1969-76ve16/d148 "Senate Resolution (205)"; frus1977-80v22/d43 matched the index but not the phrase).

[T-1980S] The 1980s. `SELECT volume_id, COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache WHERE volume_id LIKE 'frus1981-88%' GROUP BY 1;` → 13 volumes of 1981–1988 are indexed; the only Latin American one, frus1981-88v16 (South America), has 91 rows, 88 of them printed documents (3 front matter), in four country chapters (Ecuador, Paraguay, Uruguay, Venezuela; out/02c_headings_la_post1949.txt). R2 hits in any 1981–1988 volume: 0 (`grep -c "frus1981-88" out/hits_R2.tsv` → 0). No 1981–1988 Central America volume is in the corpus. LA dated documents of the 1980s: 399 (§2), R2 hits 3, all of 1980.

[T-PRE1907] Source notes before 1907. S2 documents without a document_sources row: 216 of 2,115 (out/25_s2_no_source_note.tsv): 40 of the 1860s, 20 of the 1870s, 33 of the 1880s, 75 of the 1890s, 44 of the 1900s, 3 of the 1910s, 1 of the 1940s. The 1900s S2 documents that do carry a source note are all of 1907 ("File No. 7357/…", the Numerical File). The footnote channel's earliest S2 row is dated 1913-03-01 (out/21_pointed_at_S2.txt).

## 7. Archival scope — two channels, never summed

### 7.1 Came-from: where the printed documents were filed (document_sources, one row per document)
Script scripts/18_sources_S2.py → out/18_sources_S2.txt, out/18_ds_S2.tsv. SQL (15 per call): `SELECT volume_id, document_id, repository, record_group, lot_file, lot_file_norm, series_name, citation_era, raw_text, decimal_class FROM document_sources WHERE (volume_id, document_id) IN (VALUES (?,?),...);`
[T-CAME] S2 documents with a source-note row: 1,899 of 2,115. Citation form (a FORM, not a date): decimal 1,763 · structured 72 · lot_file 17 · subject_numeric 17 · cfpf 13 · unrecognized 7 · published 5 · named_series 5. Repository / record group: Department of State, RG 59 — 1,798; National Archives, RG 59 — 17; none stated — 17; Kennedy Library 13; Nixon Presidential Materials 13; Central Intelligence Agency 11; Johnson Library 11; Eisenhower Library 10; Carter Library 8; National Defense University 1. Central files (decimal + subject-numeric + Central Foreign Policy File forms): 1,763 + 17 + 13 = 1,793 of 1,899 (more than nine in ten); decimal alone 1,763 of 1,899.
**Decimal classes, glossed** (scripts/20_gloss_came_from.py → out/20_gloss_came_from.txt) with decimal-class-labels.json under its own gate: a key is glossed only against the schedule whose span (coverage.glossableYears: 1910–1949, 1950–1959, 1960–1963) holds the DOCUMENT's date; subjects are read only where the file ships them (class 8 of 1910–1949), otherwise left unglossed. Top came-from classes (documents): Bolivia — Political affairs (824.00) 149 · El Salvador — Government (816.01) 147 · Mexico — Political affairs (812.00) 135 · Costa Rica — Political affairs (818.00) 115 · Argentina — Political affairs (835.00) 66 · Bolivia — Government (824.01) 64 · Peru — Political affairs (823.00) 62 · Nicaragua — Political affairs (817.00) 61 · El Salvador — Political affairs (816.00) 55 · Cuba — Political affairs (837.00) 50 · Haiti — Political affairs (838.00) 44 · Argentina — Government (835.01) 42 · Guatemala — Political affairs (814.00) 37 · United States–Mexico relations (711.1211, subject not glossed) 37 · Paraguay — Political affairs (834.00) 35 · Ecuador — Government (822.01) 35 · Guatemala — Government (814.01) 31 · Central America relations (713.1311, subject not glossed) 30; 1950–1963 classes appear as "Internal Political and National Defense Affairs — [country] — [subject 02 not glossed by the file]" (El Salvador 716.02, 8 documents; Haiti 738.02, 5). Keys outside the glossable years: 13 documents, all subject-numeric keys of 1963–1973 (POL 16 ARG 2, POL 23-9 ARG 2, POL 15 CHILE 2, …).
[T-POL16] **Subject-numeric** (scripts/27_libraries_and_subjnum.py, out/27c_subjnum_pol.txt; subject-numeric-labels.json, glossable 1963 and 1964–1973 by document date): POL 16 = "INDEPENDENCE. RECOGNITION." in the 1963 schedule (frus1961-63v12/d363, 1963-12-13, POL 16 DOM REP); the 1964–1973 schedule in the file has no heading for POL 16 (null), so the 1966 and 1968 citations (frus1964-68v31/d137, d141 POL 16 ARG; d512 POL 16 PERU) stay unglossed; POL 23-9 = "Rebellion. Coups." (1964–1973); POL 26 = "REBELLION. COUPS. INSURGENCY." (1963).
[T-CDF] **The Central Decimal File as a series**: the bundled data identify it only through Record Group 59 (volume-sources-index.json recordGroups["59"]: "General Records of the Department of State", naId 388) and through the two decimal-file series identifiers that digitized-ranges-index.json lists as seriesNaIds (302021, 2555709) with no title, dates or access; series-facts-index.json has no row for either; none of this scope's 208 came-from classes has a digitised range there except one document's 763.72 (out/26_digitized.txt). collection-authority.json holds "Central Files" (Department of State, 158 volumes) with no naId. So entry, series identifier, dates and access for the file itself are reported as not in the bundled data.
[T-LOTS-CAME] **Lots on the came-from channel** (scripts/24_resolve_lots.py → out/24_resolve_lots.txt; central-files-index.json lotFiles keyed on lotNumber; lot-claimants-index.json; curated-lot-resolutions.json; series-facts-index.json byNaId decoded through its legend):

| lot | S2 documents | series (RG 59 unless stated) | entry | NAID | inclusive years | access |
|---|---|---|---|---|---|---|
| 64 D 563 | frus1948v09/d115 (stored norm "NO"; probed by the printed number) | Policy Planning Council, Chronological Files | A1 558-D | 1136548 | 1947–1962 | Unrestricted |
| 53 D 26 | frus1950v02/d329 | ARA, Office of the Assistant Secretary, Subject Files | A1 1130 | 2108774 | 1949–1953 | Unrestricted |
| 61 D 110 | frus1955-57v07/d83 | Records Relating to Honduras | A1 5732 | 2602882 | 1957–1974 | Restricted - Partly |
| 67 D 46 | frus1964-68v31/d72 | Records Relating to Honduras | A1 5732 | 2602882 | 1957–1974 | Restricted - Partly |
| 64 D 16 | frus1958-60v05mSupp/es_d35 | Records Relating to El Salvador | A1 3159 | 1750062 | 1958–1975 | Restricted - Partly |
| 66 D 65 | frus1964-68v31/d310, frus1964-68v32/d278 | ARA, Subject and Country Files | A1 5763 | 1074073 | 1962–1975 | Restricted - Partly |
| 66 D 149 | frus1961-63v12/d425 | Presidential Memorandums of Conversation | A1 5158 | 610077 | 1956–1964 | Unrestricted |
| 61 D 411 | frus1958-60v06/d116 | ARA Deputy Assistant Secretary, Office Files | A1 1136 | 2108780 | 1956–1959 | Unrestricted |
| 62 D 1 | frus1958-60v05/d11, frus1961-63v10/d202 | Policy Planning Council, Records Relating to Activities with the NSC (three claimants) | A1 1583E, 1583F | 2838992 | 1948–1961 | Restricted - Partly |
| 62 D 24 | frus1958-60v05mSupp/dr_d9 | ARA Special Assistant on Communism, Subject Files | A1 3148 | 2363836 | 1958–1961 | Restricted - Partly |
| 62 D 430 | frus1958-60v05/d12 | Executive Secretariat, Subject and Special Files (OCB) | A1 1586C | 2839191 | 1953–1961 | Restricted - Partly |
| 63 D 351 | frus1952-54v04/d4 | Executive Secretariat, Records Relating to NSC Policy Papers | A1 1586E | 2839192 | 1947–1979 | Restricted - Partly |
| 66 D 95 | frus1958-60v05mSupp/es_d31 | same NAID as 63 D 351 (two claimants) | A1 1586E | 2839192 | 1947–1979 | Restricted - Partly |
| 63 D 75 | frus1955-57v06/d352 | Records Related to the Secretary's Staff Meetings | A1 1609 | 2521274 | 1952–1961 | Restricted - Possibly |
| 64 D 560, 65 D 366 | frus1958-60v05/d164, frus1961-63v12/d413 | Conference Files (curated "possible"; no NAID) | – | – | – | – |

[T-LIB] **Presidential libraries on the came-from channel** (presidential-library-catalog.json): Kennedy Library, "Papers of John F. Kennedy: Presidential Papers: National Security Files" (collection NAID 1164; series Country Files 1961–1963, NAID 193236); Johnson Library, "National Security Files" (NAID 567979; Latin America Country Files 1963–1969, NAID 567985). The catalog matched no collection that is clearly the Eisenhower "Whitman File", the Nixon "NSC Files" or the Carter "National Security Affairs" files, so those are reported without identifiers. The catalog carries no access field.
[T-DESP] **Before 1907** (no source notes): central-files-index.json countrySeries, diplomaticDespatches (out/25_country_series.txt): Despatches from U.S. Ministers to Peru, 1826-1906 (fileUnit NAID 177380755) · Mexico, 1823-1906 (177380741) · Venezuela, 1835-1906 (177380736) · Colombia, 1820-1906 (177380752) · Ecuador, 1848-1906 (177380753) · Central America, 1824-1906 (177380749) · the Dominican Republic, 1883-1906 (177380740) · Haiti, 1862-1906 (177380737) · Paraguay and Uruguay, 1858-1906 (177380743) · Bolivia, 1848-1906 (177380754) · Chile, 1823-1906 (177380724) · Brazil, 1809-1906 (177380742). The diplomaticInstructions rolls for these countries carry no file-unit title. Assigning a despatch to its series is an inference from the sender; no source note says so. The 1907 documents cite the Numerical File (central-files-index.json numericalFile, microfilm M862, rolls listed with NAIDs).

### 7.2 Pointed-at: what the editors' footnotes cite (external_citations, many rows per document)
Script scripts/21_pointed_at_S2.py → out/21_pointed_at_S2.txt, out/21_ec_S2.tsv. SQL (15 per call): `SELECT volume_id, document_id, note_ordinal, citation_index, anchor, repository, collection, lot_file, lot_file_norm, file_id, inherited, raw_text, decimal_class FROM external_citations WHERE (volume_id, document_id) IN (VALUES (?,?),...);` (note_ordinal is the footnote's position; checked on frus1915/d1010, whose source note is 812.00/16549 and whose footnote 52 cites 812.00/16528.) This channel has no row before 1910-12-06, stores the citation fragment rather than the sentence, and holds lot, library and decimal anchors only.
[T-POINT] 208 rows in 151 of the 2,115 S2 documents; anchors: central-file class 163, presidential library 27, lot file 18; inherited 4; earliest dated document with a row 1913-03-01. Glossed classes (scripts/20b_gloss_pointed_at.py → out/20b_gloss_pointed_at.txt, same gate): Nicaragua — Political affairs (817.00) 13 · Bolivia — Political affairs (824.00) 11 · Peru 723.00 (1960–63 schedule, subject unglossed) 7 · El Salvador — Government (816.01) 6 · Haiti 738.00 6 and 738.02 5 (1950–59) · Panama — Political affairs (819.00) 5 and Government (819.01) 4 · Cuba 737.00 5 · Guatemala 714.00 4 and 714.02 3 · Colombia 721.02 3 · El Salvador 716.02 3 (1960–63).
[T-LOTS-PT] Lots on the pointed-at channel (same resolution path):

| lot | S2 documents | series (RG 59 unless stated) | entry | NAID | inclusive years | access |
|---|---|---|---|---|---|---|
| 63 D 127 | frus1958-60v05mSupp/es_d33, es_d37 | Office of Central American and Panamanian Affairs, Subject and Country Files | A1 3157 | 2363840 | 1955–1963 | Restricted - Possibly |
| 59 D 573 | frus1955-57v07/d464 | ARA Assistant Secretary, Subject Files | A1 1135 | 2108779 | 1957–1959 | Unrestricted |
| 61 D 279 | frus1958-60v05/d12 | Rubottom Files (same series) | A1 1135 | 2108779 | 1957–1959 | Unrestricted |
| 62 D 418 | frus1958-60v06/d235 | Rubottom–Mann Files, Subject Files | A1 3147 | 2068466 | 1959–1962 | Restricted - Partly |
| 72 D 192 | frus1964-68v31/d203, d206 | Rusk Files, Speeches and Statements (several claimants) | A1 5376, 5376A | 631695 | 1961–1969 | Unrestricted |
| 65 D 330 | frus1961-63v12/d427 | The Secretary's and Under Secretary's Memorandums of Conversation | A1 1566 | 602231 | 1953–1964 | Unrestricted |
| 81 D 64 | frus1977-80v15/d217 | ARA Assistant Secretary's Files (Nicaragua/El Salvador working files) | UD-14D 61 | 27499857 | 1978–1981 | Restricted - Fully |
| 57 D 284 | frus1951v02/d786 | RG 43, Records of the Fifth Session at Torquay | A1 713 | 1422076 | 1950 | Restricted - Partly |
| 53 D 26, 62 D 1, 63 D 75, 64 D 560, 66 D 95, 67 D 46 | (also on this channel) | as in 7.1 | | | | |
| 61 D 386 | frus1958-60v05/d164 | no central-files row; collection-authority name only | – | – | – | – |

Presidential libraries on this channel (27 rows): Carter Library 11 (National Security Affairs 10, Brzezinski Donated Material 1), Johnson Library 7, Eisenhower Library 5, Kennedy Library 2, Nixon Presidential Materials 2 (`awk` count over out/21_ec_S2.tsv).
Labels: every archival count above is labelled by channel and by the volume set (S2's 115 volumes); the two channels are not summed anywhere. The offline stack barely reaches before 1940, so the nineteenth-century roadmap is the despatch series only.

## 8. Reading accounting

[T-READ] Documents retrieved whole: 97 (scripts/15_fetch.py; raw text of each kept in raw/<volume_id>__<document_id>.txt; reading SQL `SELECT volume_id, document_id, document_number, header, dateline, source_note, body_text, length(body_text), is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?;`). For all 97, captured length = length(body_text) (out/15_fetch_01.txt … out/15_fetch_19.txt; no mismatch); together 730,351 characters (length(body_text), characters not bytes). Quoted: 53 passages from 51 of those documents verified (§9); 18 of them, from 18 documents, are quoted in the overview. Samples read programmatically for literal and referent tests (§3, §4.1) were read as contexts, not retrieved whole.

## 9. Quotations — every passage, its document, its SELECT and its checks

[T-VERIFY] Verification script scripts/30_verify_quotes.py (spec scripts/quotes_spec.json: start and end phrase per quotation). For each: `SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?;` → the passage is cut from body_text between the start phrase and the first following end phrase (so it is exact by construction), then checked (1) to be a substring of body_text and (2) to lie, whitespace-collapsed, inside the TEI document text with all `<note>` elements and the document's own `<head>` removed — i.e. the document's own words, not an editors' footnote spliced into body_text. Result (out/30_verify_quotes.txt, out/quotes_verified.json): 53 of 53 pass both checks. The 18 marked "overview" are the overview's block quotations; scripts/38_check_overview.py (out/38_check_overview.txt) confirms each overview block quotation equals its verified passage character for character, is an excerpt in collection.fruscollection, and that all 42 documents the overview cites by URL are in the collection.

| id | (volume_id, document_id) | in body_text | in TEI document text (not notes) | overview | collection excerpt | quotation, exactly as retrieved |
|---|---|---|---|---|---|---|
| [T-Q01] Q01 | frus1866p2/d502 | yes | yes | no | no | The policy of the United States is settled upon the principle that revolutions in republican states ought not to be accepted until the people have adopted them by organic law, with the solemnities which would seem sufficient to guarantee their stability and permanency. |
| [T-Q02] Q02 | frus1868p2/d499 | yes | yes | yes | yes | What we do require, and all that we do require, is when a change of administration has been made, not by peaceful constitutional processes, but by force, that then the new administration shall be sanctioned by the formal acquiescence and acceptance of the people. |
| [T-Q03] Q03 | frus1877/d226 | yes | yes | yes | yes | the United States, prior to deciding in favor of official recognition of the Diaz government, would expect that efficient measures would be taken toward checking inroads into their States and territories, and toward the repeal of the “Zona Libre.” |
| [T-Q04] Q04 | frus1899/d792 | yes | yes | no | no | Test of recognition is complete regency of affairs by de facto government capable of fulfilling international obligations. |
| [T-Q05] Q05 | frus1900/d530 | yes | yes | yes | yes | the rule of the United States is to defer recognition of another executive in its place until it shall appear that it is in possession of the machinery of the state, administering government with the assent of the people thereof and without substantial resistance to its authority, and that it is in a position to fulfill all the international obligations and responsibilities incumbent upon a sovereign state under treaties and international law. |
| [T-Q06] Q06 | frus1904/d227 | yes | yes | no | no | That the present Government pledge itself to recognize all the engagements entered into between this legation and the Dominican Republic, and all former engagements made with preceding administrations. |
| [T-Q07] Q07 | frus1913/d7 | yes | yes | no | no | Cooperation is possible only when supported at every turn by the orderly processes of just government based upon law, not upon arbitrary or irregular force. |
| [T-Q08] Q08 | frus1913/d1028 | yes | yes | no | no | It pledges itself to recognize and in every way possible and proper to assist the administration chosen and set up in Mexico in the way and on the conditions suggested. |
| [T-Q09] Q09 | frus1917/d378 | yes | yes | no | no | it will not give recognition or support to any Government which may be established unless it is clearly proven that it is elected by legal and constitutional means. |
| [T-Q10] Q10 | frus1914/d544 | yes | yes | yes | yes | recognition by the United States will be granted him as provisional president when a commission to be named by the Haitian Government with full powers to act upon certain questions of interest to this Government and to the Republic of Haiti is in position to give necessary assurances. |
| [T-Q11] Q11 | frus1921v02/d344 | yes | yes | yes | yes | In short, when it appears that there is a government in Mexico willing to bind itself to the discharge of primary international obligations, concurrently with that act its recognition will take place. |
| [T-Q12] Q12 | frus1923v02/d345 | yes | yes | yes | yes | will not recognize any other Government which may come into power in any of the five Republics through a coup d’état or a revolution against a recognized Government, so long as the freely elected representatives of the people thereof have not constitutionally reorganized the country. |
| [T-Q13] Q13 | frus1930v01/d375 | yes | yes | yes | yes | the evidence has satisfied me that these provisional governments are de facto in control of their respective countries, and that there is no active resistance to their rule. Each of the present governments has also made it clear that it is its intention to fulfill its respective international obligations and to hold, in due course, elections to regularize its status. |
| [T-Q14] Q14 | frus1931v02/d232 | yes | yes | no | no | the regime headed by General Martínez is barred from recognition by the terms of Article 2 of the General Treaty of Peace and Amity of 1923. |
| [T-Q15] Q15 | frus1933v05/d502 | yes | yes | no | no | we have not believed that it would be a policy of friendship and of justice to the Cuban people as a whole to accord recognition to any provisional government in Cuba unless such government clearly possessed the support and the approval of the people of that Republic. |
| [T-Q16] Q16 | frus1936v05/d112 | yes | yes | yes | yes | we are no longer warranted in invoking the Treaty as a reason for denying recognition to any régime in Central America |
| [T-Q17] Q17 | frus1937v05/d340 | yes | yes | no | no | A formal act of recognition is not required where the existing government has executed a coup d’état displacing the Constitution by a new one or setting it aside. |
| [T-Q18] Q18 | frus1943v05/d33 | yes | yes | yes | yes | they do not proceed to the recognition of a new government instituted by force, before consulting among themselves for the purpose of determining whether this government complies with the Inter-American undertakings for the defense of the continent |
| [T-Q19] Q19 | frus1944v07/d227 | yes | yes | yes | yes | we do not intend to recognize until there is concrete evidence in the form of significant anti-Nazi measures that the Government is no longer linked to the Extreme Nationalist and pro-German elements. |
| [T-Q20] Q20 | frus1944v07/d432 | yes | yes | no | no | the pro-Nazi record of the MNR leaders made recognition by the other American republics impossible. |
| [T-Q21] Q21 | frus1945v09/d250 | yes | yes | yes | yes | (a) Declared by decree the existence of a state of war with Germany and Japan; (b) Expressed conformity with the principles and declarations of the Final Act and complied with such principles and declarations; (c) Signed the Final Act of Mexico City at the Pan American Union. |
| [T-Q22] Q22 | frus1948v09/d74 | yes | yes | no | no | 3. That the establishment or maintenance of diplomatic relations with a government does not imply any judgment upon the domestic policy of that government. |
| [T-Q23] Q23 | frus1948v09/d115 | yes | yes | no | no | Recognition should not be withheld as a political weapon or to express moral censure except in extreme cases when U.S. national interests would be served thereby. |
| [T-Q24] Q24 | frus1949v02/d457 | yes | yes | yes | yes | Suspension is a feeble sanction, is not clearly a deterrent to other military coups, and has not been shown in the past to have made any lasting contribution to establishment of representative government |
| [T-Q25] Q25 | frus1952-54v04/d327 | yes | yes | yes | yes | The Batista regime has formally requested our recognition and has made satisfactory public and private statements with regard to Cuban intention to fulfill its international obligations; its attitude towards private capital; and its intention to take steps to curtail international communist activities in Cuba. |
| [T-Q26] Q26 | frus1958-60v05mSupp/es_d43 | yes | yes | no | no | In view of the assurances set forth in your note and of the official affirmations made public concerning the holding of free elections, my Government has instructed me to state that it welcomes these assurances, and that it is pleased to extend recognition to the Junta of Government as the provisional Government of El Salvador. |
| [T-Q27] Q27 | frus1961-63v12/d363 | yes | yes | no | no | In cases both countries our principal objective in withholding recognition has been return at earliest possible date constitutionally elected government. |
| [T-Q28] Q28 | frus1961-63v12/d421 | yes | yes | yes | yes | It seems clear that the sharp reaction of the United States and other Latin American countries has led the junta to take a position with respect to new elections, with respect to current civil rights, with respect to leaders of the previous government and of APRA, and with respect to the private business community and the Alliance for Progress more liberal and more in accordance with United States views than would otherwise have been the case. |
| [T-Q29] Q29 | frus1964-68v31/d135 | yes | yes | yes | yes | we should seek the usual assurances regarding acceptance of international obligations, as well as respect for civil liberties and an early return to constitutional government, before recognizing. But we should not take too rigid a position on the scheduling of elections which might preclude recognition if we did not get the commitment. |
| [T-Q30] Q30 | frus1964-68v31/d512 | yes | yes | no | no | At some appropriate time, I think USG ought to shift toward the notion that a coup affects the intensity, intimacy and levels of our relations but does not automatically cut them off. |
| [T-Q31] Q31 | frus1969-76ve10/d14 | yes | yes | no | no | On the question of recognition, we should go for automatic recognition. We shouldn’t bite on the Cuban problem. It must be mentioned in the speech. Automatic recognition avoids the problem of judgments whether regimes are good or bad. |
| [T-Q32] Q32 | frus1969-76ve16/d148 | yes | yes | yes | yes | In recent years, the United States has moved away from the concept of recognition, focusing instead on whether diplomatic relations are to continue. This avoids the value judgments often attributed to “recognition” of a Government. |
| [T-Q33] Q33 | frus1977-80v24/d137 | yes | yes | no | no | Continuation of relations implies neither approval nor disapproval of the nature or programs of a new government. |
| [T-Q34] Q34 | frus1964-68v31/d152 | yes | yes | no | no | The new regime is in control of the country, has encountered no resistance, has reestablished constitutional liberties, and has reiterated its intentions to hold elections. |
| [T-Q35] Q35 | frus1949v02/d448 | yes | yes | no | no | the present government apparently intends to live up to its international commitments and the Foreign Minister has made a public statement to that effect. |
| [T-Q36] Q36 | frus1977-80v24/d160 | yes | yes | no | no | The IG also endorsed for the rest of 1980 a short-term strategy to isolate the regime, diplomatically and politically, to promote moderation and to exert economic pressures on Bolivia. |
| [T-Q37] Q37 | frus1895p1/d246 | yes | yes | no | no | As to formal recognition, the practice of this Government has been to enter into effective relations with the de facto government when it shall have been fully established with the general consent of the people. |
| [T-Q38] Q38 | frus1907p2/d27 | yes | yes | no | no | Being advised of the competency of the provisional government to perform international obligations, and being satisfied with the steps taken to revive the constitutional régime in Honduras and to provide for the election of the executive thereof, the President has directed the recognition of the provisional government |
| [T-Q39] Q39 | frus1955-57v07/d465 | yes | yes | no | no | The new regime, welcomed by the people, has given evidence of being firmly in control and has expressed its intention of complying with all its international obligations. |
| [T-Q40] Q40 | frus1969-76ve11p2/d34 | yes | yes | yes | yes | at present it is the US Government’s policy to recognize a government that effectively exercises power and responsibly discharges its international obligations. |
| [T-Q41] Q41 | frus1944v07/d403 | yes | yes | no | no | All of the nineteen republics participating in the consultations and exchange of information regarding the Bolivian revolution have refused recognition to the Junta in public statements. |
| [T-Q42] Q42 | frus1933v05/d508 | yes | yes | no | no | We have maintained that the criteria of Cuban recognition are: (1) popular support, and (2) ability to maintain law and order and carry on the functions incumbent upon any stable government. |
| [T-Q43] Q43 | frus1914/d506 | yes | yes | no | no | the Government of the United States will be probably disposed to recognize the Government of Oreste Zamor as the duly elected constitutional government of the Republic of Haiti, since it appears from the support which it received in the north and in the other parts of the Republic that the advent of this Government is based upon the consent of the governed. |
| [T-Q44] Q44 | frus1866p2/d498 | yes | yes | no | no | Your course in not recognizing the government thus forcibly established by Colonel Prado is approved by the President. |
| [T-Q45] Q45 | frus1917/d382 | yes | yes | no | no | By authorization of the President you are instructed to inform Tinoco that even if he is elected he will not be given recognition by the United States. |
| [T-Q46] Q46 | frus1923v02/d488 | yes | yes | no | no | have resolved to renew diplomatic relations between them, and therefore, pending the appointment of ambassadors, they are taking the necessary steps to accredit, formally, their respective Chargés d’Affaires.” |
| [T-Q47] Q47 | frus1943v05/d486 | yes | yes | no | no | Considerations of the security of the Hemisphere and of the war effort of the United Nations must have first importance in any matter of this or similar character. Included in the relevant considerations is the question whether outside influence unfriendly to the Allied cause played any part. |
| [T-Q48] Q48 | frus1961-63v12/d417 | yes | yes | no | no | Publicly announce we withholding recognition of imposed government; publicly announce suspension aid programs; recall Ambassador for consultation; withdraw at least top aid officials |
| [T-Q49] Q49 | frus1877/d216 | yes | yes | no | no | Porfirio Diaz would have no important adversary in arms, and might be regarded as the actual ruler of the country. |
| [T-Q50] Q50 | frus1934v05/d257 | yes | yes | no | no | Under authorization of the President please extend on behalf of the United States a formal and cordial recognition to the Government of El Salvador. |
| [T-Q51] Q51 | frus1948v09/d7 | yes | yes | no | no | (a) de facto control of the territory and the administrative machinery of State, including the maintenance of public order; (b) the ability and willingness of a government to discharge its international obligations; (c) general acquiescence of the people of a country in the government in power. |
| [T-Q52] Q52 | frus1948v09/d7 | yes | yes | yes | yes | 10. Recognition of a government by the United States should imply neither approval nor disapproval of the policies of that government with respect to strictly domestic affairs. 11. Recognition should not be withheld as a political weapon or to express moral censure except in extreme cases when U.S. national interests would be served thereby. |
| [T-Q53] Q53 | frus1948v09/d7 | yes | yes | no | no | Ability and willingness of the de facto government to discharge international obligations has been one of the principles upon which U.S. recognition has been based for many years. At some periods such as those of our own Civil War and during the Wilson Administration a requirement of “constitutionality” was a factor |

## 10. The collection

collection.fruscollection, built and validated by scripts/34_build_collection.py (out/34_build_collection.txt): format "fruscollection", formatVersion 2, minimumReaderVersion 1, all six composition keys; 52 document entries under six headings that follow the overview's findings (date order within each), 18 excerpts (the overview's block quotations, each placed after its document), one prose block under each heading, a closing heading and prose block naming the threads not followed, and the archivalSources generated block last. Every document and excerpt entry carries both volumeId and documentId; no document pair repeats; every pair was checked to exist in document_cache (`SELECT COUNT(*) FROM document_cache WHERE volume_id=? AND document_id=?;` → 1 for each) and none is front matter or an editorial note (out/32_collection_docs_check.tsv); no volume ending in Ed2 is used. Every note opens "Agent finding, run r10, 2026-10-25:".
[T-COLL] 52 documents: 44 are in S2 (A1 only 10, A1 and R2 9, R2 only 25 — counted before frus1948v09/d7 was added: 24 + 1); 8 are outside the scope rule and were reached by reading (§3.4). Rule: every document the argument rests on, and nothing else.

## 11. Limitations and decisions taken meanwhile

- S2's inclusion rule mixes an editorial rule (A1, to 1950) and a text rule (R2, all years); the eras are therefore composed differently, and the condition rates are compared within R2 documents (§4, second table), which are text-selected in every era.
- R2 recall: about 50 more Latin American documents use telegraphic or other phrasings (§3.4); S2 was not rebuilt.
- [T-CARIB] The LA universe leaks a little: the Berlin-crisis chapter titled for the Cuban missile crisis; the nine Commonwealth Caribbean documents (out/36_s2_caribbean.tsv: frus1964-68v32 5, frus1969-76ve11p1 2, frus1977-80v23 2) are inside it by the editors' volume titles.
- body_text includes editors' footnotes; the TEI split (§5) shows they carry at most about one in ten recognition occurrences in any era.
- citation_era is a citation form, never plotted as a date; document_sources and external_citations are never combined.
- Persons were not counted; person tables were not used.
- The bundled archival indexes do not identify the Central Decimal File or the Subject-Numeric file as series; the offline stack barely reaches before 1940.
- No [HARVEST] path was given; the NARA record-group harvest is not available to this run.
- Second-edition rule: frus1951-54IranEd2 and frus1969-76ve15p2Ed2 dropped throughout (neither intersects the LA universe); the overlap figures of the brief (718 / 701) were not re-measured.

**Changes between my own passes** (the house rule on correcting an earlier pass). The TEI scan is the only earlier pass whose files are kept (out/tei_v1_spacejoin/); the decisive query was run on both sides (`python3 -B -u scripts/35_compare_tei_v1_v2.py`, out/35_compare_tei_v1_v2.txt). The index-side lists were overwritten when rebuilt; their earlier values are the outputs printed in this session before each fix, and the final values are read from the final files (`wc -l out/hits_R2.tsv out/scope_S2.tsv` → 1,076 and 2,115).

| item | earlier pass | final pass | what changed | decisive query |
|---|---|---|---|---|
| R2 ∩ LA documents | 1,122, then 1,080 | 1,076 | mixed UN/Western Hemisphere volumes flagged by path only; then structural rows excluded | scripts/08_fts_family.py R2 (same MATCH) after scripts/05_doc_paths.py fixes |
| S2 documents | 2,161, then 2,119 | 2,115 | the same two fixes | scripts/09b_build_scope_R2.py |
| LA universe, dated printed documents | 62,158, then 60,180 | 59,562 | the same two fixes | scripts/06_decades.py |
| R2 literal share (sample of 40) | strict 26, tolerant 40 (M = 1,122); then strict 26, tolerant 38 (M = 1,080) | strict 30, tolerant 40 (M = 1,076) | different evenly spaced sample after the list changed | scripts/10_literal_share.py |
| R2 referent (sample of 40) | 33 of 40 (M = 1,122); then 35 of 40 (M = 1,080) | 35 of 40 (M = 1,076) | re-read on the new sample | out/11_kwic_R2.txt |
| TEI control "Department of State", all documents | 152,703 | 136,160 | v1 joined text fragments with a space, v2 without | scripts/35_compare_tei_v1_v2.py on both directories |
| TEI "recognizing", document text, all documents | 5,117 | 5,122 | same | same |

## 12. The 52 collection documents, by heading (date from document_dates; header from document_cache)
[T-COLLIST] `SELECT c.volume_id, c.document_id, c.document_number, dd.date_iso, c.is_front_matter, c.is_editorial_note, length(c.body_text), substr(c.header,1,90) FROM document_cache c LEFT JOIN document_dates dd ON ... WHERE (c.volume_id, c.document_id) IN (VALUES ...)` (out/32_collection_docs_check.tsv, plus frus1948v09/d7):

| heading | (volume_id, document_id) | date | header |
|---|---|---|---|
| 1 | frus1866p2/d498 | 1865-12-28 | Mr. Seward to Mr. Hovey. |
| 1 | frus1866p2/d502 | 1866-03-08 | Mr. Seward to Mr. Hovey. |
| 1 | frus1868p2/d499 | 1868-05-07 | Mr. Seward to Mr. Hovey. |
| 1 | frus1877/d216 | 1877-01-19 | No. 216. Mr. Fish to Mr. Foster. |
| 1 | frus1895p1/d246 | 1895-11-06 | Mr. Olney to Mr. Tillman. |
| 1 | frus1899/d792 | 1899-10-23 | Mr. Hay to Mr. Loomis. |
| 1 | frus1900/d530 | 1900-09-08 | Mr. Hill to Mr. Hart. |
| 1 | frus1907p2/d27 | 1907-08-23 | The Acting Secretary of State to the Provisional Minister for Foreign Affairs of Honduras. |
| 1 | frus1930v01/d375 | 1930-09-17 | Press Release Issued by the Department of State on September 17, 1930 |
| 1 | frus1933v05/d502 | 1933-11-23 | The Acting Secretary of State to President Roosevelt, at Warm Springs, Georgia |
| 1 | frus1933v05/d508 | 1933-11-28 | The Acting Secretary of State to the Secretary of State |
| 1 | frus1937v05/d340 | 1938-01-11 | Memorandum by the Legal Adviser (Hackworth) to the Chief of the Division of the American Republics ( |
| 1 | frus1955-57v07/d465 | 1957-05-15 | 465. Memorandum From the Secretary of State to the President |
| 1 | frus1969-76ve11p2/d34 | 1976-02-21 | 34. Telegram 1186 From the Embassy in Argentina to the Department of State |
| 2 | frus1907p2/d148 | 1908-03-20 | By Mr. William I. Buchanan, Representing the United States of America. |
| 2 | frus1913/d7 | 1913-03-12 | [Untitled] |
| 2 | frus1913/d1028 | 1913-08-27 | The Secretary of State to the American Chargé d’Affaires. |
| 2 | frus1917/d378 | 1917-02-09 | The Secretary of State to Minister Leavell |
| 2 | frus1917/d382 | 1917-02-17 | The Secretary of State to Minister Hale |
| 2 | frus1923v02/d345 | 1923-06-30 | The Secretary of State to the Minister in Honduras (Morales) |
| 2 | frus1931v02/d232 | 1931-12-20 | The Secretary of State to the Chargé in Costa Rica (Werlich) |
| 2 | frus1934v05/d257 | 1934-01-26 | The Secretary of State to the Chargé in El Salvador (McCafferty) |
| 2 | frus1936v05/d112 | 1936-04-30 | The Secretary of State to the Minister in Honduras (Keena) |
| 3 | frus1877/d226 | 1877-06-20 | No. 226. Mr. Foster to Mr. Evarts. |
| 3 | frus1904/d227 | 1903-12-03 | Mr. Powell to Mr. Hay. |
| 3 | frus1914/d506 | 1914-02-26 | The Secretary of State to Minister Smith. |
| 3 | frus1914/d544 | 1914-11-12 | The Secretary of State to Minister Blanchard. |
| 3 | frus1921v02/d344 | 1921-06-08 | The Secretary of State to the Chargé in Mexico (Summerlin) |
| 3 | frus1923v02/d488 | 1923-08-28 | The Acting Secretary of State to the Belgian Chargé (D’Hermalle) |
| 4 | frus1943v05/d486 | 1943-12-22 | The Secretary of State to the Diplomatic Representatives in the American Republics |
| 4 | frus1943v05/d33 | 1943-12-24 | The Chairman of the Emergency Advisory Committee for Political Defense (Guani) to the Secretary of S |
| 4 | frus1944v07/d403 | 1944-01-28 | The Secretary of State to the Diplomatic Representatives in the American Republics Except Argentina  |
| 4 | frus1944v07/d227 | 1944-04-13 | The Ambassador in Argentina (Armour) to the Secretary of State |
| 4 | frus1944v07/d432 | 1944-06-02 | The Secretary of State to the Ambassador in Brazil (Caffery) |
| 4 | frus1945v09/d250 | 1945-04-03 | The Secretary of State to the Diplomatic Representatives in the American Republics |
| 5 | frus1948v09/d7 | 1948-03-15 | Paper Prepared by the Policy Planning Staff |
| 5 | frus1948v09/d74 | 1948-03-30 | Final Act of the Ninth International Conference of American States, Bogotá, March 30–May 2, 1948 |
| 5 | frus1948v09/d115 | 1948-12-10 | Memorandum by the Director of the Policy Planning Staff (Kennan) to the Acting Secretary of State |
| 5 | frus1949v02/d457 | 1949-02-21 | Memorandum by the Director of the Office of American Republic Affairs (Daniels) to the Secretary of  |
| 5 | frus1949v02/d448 | 1949-12-08 | Memorandum by the Assistant Secretary of State for Inter-American Affairs (Miller) to the Secretary  |
| 5 | frus1952-54v04/d327 | 1952-03-24 | Memorandum by the Secretary of State to the President |
| 5 | frus1958-60v05mSupp/es_d43 | 1960-12-01 | ES–43. Telegram from the Acting Secretary of State to the Embassy in El Salvador |
| 6 | frus1961-63v12/d417 | 1962-06-07 | 417. Telegram From the Department of State to the Embassy in Peru |
| 6 | frus1961-63v12/d421 | 1962-07-27 | 421. Memorandum From the Under Secretary of State (Ball) to President Kennedy |
| 6 | frus1961-63v12/d363 | 1963-12-13 | 363. Telegram From the Department of State to the Embassy in Venezuela |
| 6 | frus1964-68v31/d152 | 1964-12-03 | 152. Memorandum From Acting Secretary of State Harriman to President Johnson |
| 6 | frus1964-68v31/d135 | 1966-06-29 | 135. Memorandum From the President’s Special Assistant (Rostow) to President Johnson |
| 6 | frus1964-68v31/d512 | 1968-10-06 | 512. Telegram From the Department of State to the Embassy in Peru |
| 6 | frus1969-76ve10/d14 | 1969-10-15 | 14. Minutes of National Security Council Meeting |
| 6 | frus1969-76ve16/d148 | 1973-09-14 | 148. Memorandum From the Executive Secretary of the Department of State (Pickering) to the President |
| 6 | frus1977-80v24/d137 | 1978-08-03 | 137. Telegram From the Department of State to the Embassy in Bolivia |
| 6 | frus1977-80v24/d160 | 1980-10-03 | 160. Memorandum From the Bureau of Inter-American Affairs Staff Director for NSC Interdepartmental G |



## 13. TRACE TABLE — every number and quotation in overview.md, and the memo line it comes from

| overview section | number or quotation | memo line(s) |
|---|---|---|
| Bottom line 1 | all 553 volumes indexed | 12 (T-COV) |
| Bottom line 1 | about 2,100 documents in 115 of the 553 volumes | 85 (T-S2) |
| Bottom line 1 | about 1,300 documents under 56 chapters, 1895–1950 | 21 (T-A1) |
| Bottom line 1 | about 1,100 documents whose wording speaks of recognizing a government, 1862–1980 | 84 (T-R2), 85 (T-S2) |
| Bottom line 1 | overlapping by some 300 | 85 (T-S2) |
| Bottom line 1 | fifty-two documents in the collection | 402 (T-COLL), 429 (T-COLLIST) |
| Bottom line 1 | documents cited in the paragraph (dates, identities) | 429 (T-COLLIST) |
| Bottom line 2 | more than nine in ten of the documents with a source note cite the central files | 287 (T-CAME) |
| Bottom line 2 | Central Decimal File: RG 59, record-group identifier 388; no entry, series identifier, dates or access in the bundled data | 290 (T-CDF) |
| Bottom line 2 | country Political affairs / Government classes; post-1950 Internal Political and National Defense Affairs classes | 287 (T-CAME) |
| Bottom line 2 | Subject-Numeric file POL 16, Independence. Recognition. (1963 handbook) | 289 (T-POL16) |
| Bottom line 2 | came-from lots with entry, NAID, years, access | 291 (T-LOTS-CAME) |
| Bottom line 2 | Kennedy and Johnson National Security Files identifiers; access not in bundled data | 311 (T-LIB) |
| Bottom line 2 | despatch series identifiers before 1907 (inference) | 312 (T-DESP) |
| Bottom line 2 | about 200 footnote citations in about 150 documents | 316 (T-POINT) |
| Bottom line 2 | pointed-at decimal-file countries | 316 (T-POINT) |
| Bottom line 2 | pointed-at lots with entry, NAID, years, access; Carter National Security Affairs | 317 (T-LOTS-PT) |
| Bottom line 3 | six documents refer to the Acheson address, one to the Mann speech, two to Senate Resolution 205; none prints the text; Bulletin footnotes | 274 (T-STMT) |
| Bottom line 3 | Guani doctrine in no document; control about 94,000; nonsense string none | 271 (T-GUANI) |
| Bottom line 3 | 1981–1988 South America volume: 88 documents, four countries, no recognition phrasing; no Central America volume | 279 (T-1980S) |
| Bottom line 3 | no source notes before 1907; footnotes cite no archival file before 1913 | 281 (T-PRE1907) |
| Scope | 56 chapters (1895–1950); about 2,100 documents in 115 volumes; exclusions | 21 (T-A1), 85 (T-S2) |
| Decisions | about 200 documents after 1949 | 86 (T-S2DEC) |
| Decisions | nine documents on Guyana, the Bahamas and the eastern Caribbean | 408 (T-CARIB) |
| Finding 1 | quotation, 1900, Document 530 | 349 (T-Q05) |
| Finding 1 | quotation, 1930, Volume I, Document 375 | 357 (T-Q13) |
| Finding 1 | quotation, 1969–1976, Volume E–11, Part 2, Document 34 | 384 (T-Q40) |
| Finding 1 | seventy-six years apart (1900 and 1976 documents) | 429 (T-COLLIST) |
| Finding 2 | quotation, 1868, Part II, Document 499 | 346 (T-Q02) |
| Finding 2 | quotation, 1923, Volume II, Document 345 | 356 (T-Q12) |
| Finding 2 | quotation, 1936, Volume V, Document 112 | 360 (T-Q16) |
| Finding 2 | treaty rule: about one in four (1930–42), one in twenty before 1930, almost none after 1942 | 202 (T-C12), 195 (T-REF-C12) |
| Finding 3 | quotation, 1877, Document 226 | 347 (T-Q03) |
| Finding 3 | quotation, 1914, Document 544 | 354 (T-Q10) |
| Finding 3 | quotation, 1921, Volume II, Document 344 | 355 (T-Q11) |
| Finding 3 | claims or expropriation: about one in ten in 1913–1929, almost nowhere else | 203 (T-C11) |
| Finding 4 | quotation, 1943, Volume V, Document 33 | 362 (T-Q18) |
| Finding 4 | quotation, 1944, Volume VII, Document 227 | 363 (T-Q19) |
| Finding 4 | quotation, 1945, Volume IX, Document 250 | 365 (T-Q21) |
| Finding 4 | consultation and Axis each about one in four in 1943–48; a few in a hundred elsewhere | 204 (T-C7C8), 196 (T-REF-C7) |
| Finding 5 | quotation, 1948, Volume IX, Document 7 | 396 (T-Q52) |
| Finding 5 | quotation, 1949, Volume II, Document 457 | 368 (T-Q24) |
| Finding 5 | quotation, 1952–1954, Volume IV, Document 327 | 369 (T-Q25) |
| Finding 5 | obligations about one in four (1949–60) against one in ten before; elections about three in ten against fewer than one in ten | 205 (T-C1C2), 197 (T-REF-C2) |
| Finding 6 | quotation, 1961–1963, Volume XII, Document 421 | 372 (T-Q28) |
| Finding 6 | quotation, 1964–1968, Volume XXXI, Document 135 | 373 (T-Q29) |
| Finding 6 | quotation, 1969–1976, Volume E–16, Document 148 | 376 (T-Q32) |
| Finding 6 | civil liberties or human rights about three in ten after 1961; one in twenty or fewer before 1949 | 206 (T-C10), 198 (T-REF-C10) |
| Finding 6 | communism about half (1949–60), two in five after 1961; 5 of 15 bear on the decision | 207 (T-C9), 199 (T-REF-C9) |
| How this was done | 52 phrasings | 82 (T-R2EXPR) |
| How this was done | sample of 40: tolerant 40 of 40, strict 30 of 40 | 99 (T-R2S), 101 (T-R2T) |
| How this was done | 35 of the 40 on the referent | 106 (T-R2REF) |
| How this was done | looser family right in 20 of 40 | 110 (T-RREF) |
| How this was done | footnotes carry little of the recognition language | 259 (T-APP) |
| How this was done | 'by force' about 3 in 200 against 2 in 200; coup d'état and de facto six to nine times commoner | 261 (T-FF) |
| How this was done | every quotation checked against its document and outside the footnotes | 341 (T-VERIFY) |
| How this was done | finding aids stop at the record group for the central files | 290 (T-CDF) |
| Read next | 52 documents in the collection | 402 (T-COLL) |
| Finding 1 | paraphrase: Roosevelt 1933 popular support (1933, Volume V, Document 502) | 359 (T-Q15) |
| Finding 1 | paraphrase: Legal Adviser 1938 on self-coups (1937, Volume V, Document 340) | 361 (T-Q17) |
| Finding 1 | paraphrase: Policy Planning Staff three factors, March 1948 | 395 (T-Q51) |
| Finding 2 | paraphrase: Seward 1866, organic law (1866, Part II, Document 502) | 345 (T-Q01) |
| Finding 2 | paraphrase: Fish January 1877, Díaz as actual ruler (1877, Document 216) | 393 (T-Q49) |
| Finding 2 | paraphrase: Wilson March 1913 statement; August 1913 terms (1913, Documents 7 and 1028) | 351 (T-Q07), 352 (T-Q08) |
| Finding 2 | paraphrase: Lansing 1917 circular; Tinoco not recognized even if elected (1917, Document 378) | 353 (T-Q09), 389 (T-Q45) |
| Finding 2 | paraphrase: Martínez barred, 1931; recognized January 1934 (1931, Volume II, Document 232; 1934, Volume V, Document 257) | 358 (T-Q14), 394 (T-Q50) |
| Finding 3 | paraphrase: pledge to honor engagements, 1903 (1904, Document 227) | 350 (T-Q06) |
| Finding 3 | paraphrase: relations renewed 1923, claims conventions (1923, Volume II, Document 488) | 390 (T-Q46) |
| Finding 4 | paraphrase: Hull December 1943, security first (1943, Volume V, Document 486) | 391 (T-Q47) |
| Finding 4 | paraphrase: all nineteen republics refused the Bolivian junta (1944, Volume VII, Document 403) | 385 (T-Q41) |
| Finding 4 | paraphrase: MNR leaders removed, Axis firms and aliens (1944, Volume VII, Document 432) | 364 (T-Q20) |
| Finding 5 | paraphrase: Kennan, December 1948 (1948, Volume IX, Document 115) | 367 (T-Q23) |
| Finding 5 | paraphrase: Panama 1949 criteria (1949, Volume II, Document 448) | 379 (T-Q35) |
| Finding 5 | paraphrase: El Salvador 1960 recognition note (1958–1960, Volume V, Microfiche Supplement, Document ES–43) | 370 (T-Q26) |
| Finding 6 | paraphrase: Peru 1962 contingency (1961–1963, Volume XII, Document 417) | 392 (T-Q48) |
| Finding 6 | paraphrase: Dominican Republic and Honduras 1963 (1961–1963, Volume XII, Document 363) | 371 (T-Q27) |
| Finding 6 | paraphrase: Barrientos 1964 (1964–1968, Volume XXXI, Document 152) | 378 (T-Q34) |
| Finding 6 | paraphrase: Oliver 1968 (1964–1968, Volume XXXI, Document 512) | 374 (T-Q30) |
| Finding 6 | paraphrase: Nixon 1969, automatic recognition (1969–1976, Volume E–10, Document 14) | 375 (T-Q31) |
| Finding 6 | paraphrase: Bolivia 1978, continuing relations; Bolivia 1980, isolation (1977–1980, Volume XXIV, Documents 137 and 160) | 377 (T-Q33), 380 (T-Q36) |
| Bottom line 3 | paraphrase: Resolution XXII is the printed form of the practice (1943, Volume V, Document 33) | 362 (T-Q18) |
