# Scope memo: recognition of Latin American governments that took power by force (run r4, 2026-10-25)

Operator's memo. Every number is given in its audit form. Scripts, inputs and outputs are in `/Users/jbotts/frus-analysis/c3/runs/r4/`; the command log is `queries.log`. Line labels (M1, M2, …) are what the trace table at the end refers to.

## 0. Coverage and access proofs

- **M0a**: `SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;` returns `553|321749|1103|8481`. All 553 volumes of the series are in this copy, so every count below is conditional on the full 553-volume library, not a partial download.
- **M0b**: `sqlite3 -readonly … "BEGIN; CREATE TABLE zz(x); ROLLBACK;"` fails with "attempt to write a readonly database".
- Surfaces used: THIS DATABASE (coverage, scope, counts, the two archival channels) and the BUNDLED JSON (subjects of decimal keys, lot→series, series facts, manifest titles). I did **not** open the TEI XML. No number below is a [TEI] counting-surface, spelling-variant or apparatus/document-split number. **Statement required by the house rules: every density here mixes document text and editorial footnotes, because body_text contains both; I have not separated them.** No [HARVEST] path was given, so the NARA harvest surface was unavailable.

## 1. How the scope was found

1. I read the editors' chapter headings before writing any query. `headings.py` runs `SELECT volume_id, structure_json FROM volume_structures` and prints every section title matching `/recogni/i`, giving 253 titles (`recog_headings.txt`). `headings2.py` repeats the walk for volumes ≥ `frus1945` with `coup|junta|overthrow|de facto|continuity of|military government|military regime|resumption of (diplomatic )?relations|recogni`. This turned up the 1948 chapter "Continuance by the United States of diplomatic relations with new governments on the basis of the Bogota Resolution…". After 1950 the editors' Latin American chapters are titled by country only (`toc.py`, see `toc1.txt`), so a heading rule cannot reach them.
2. `scope.py` (final version in the run directory; the three patches are logged) builds `scope.tsv`, with 3,040 candidate documents in 74 volumes. A document is admitted by one of three rules:
   - **heading** (2,654 docs): the document is in a chapter whose title matches the GOV pattern (recognition plus government/regime/president/junta/de facto/provisional/named leader, or nonrecognition), whose path names a Latin American country, and whose volume is before `frus1951`. Excluded by title: `blockade|Monroe Doctrine|divest his government`, and the volume frus1917Supp01v01 (Greek). Hand-added chapters: frus1936v05 "article II of the General Treaty…", frus1948v09 "…Bogota Resolution…", frus1907p2 "Central American peace protocol…", frus1922v01 "Conference on Central American Affairs…", frus1923v01 "Agreements between the United States and Central American Republics…", frus1913 "Political affairs: assassination of President Madero…", frus1946v11 "…violence accompanying the Bolivian revolution and the problem of recognition". Hand-added document: frus1913/d7 (Wilson's statement of 11 March 1913).
   - **revchapter** (122 docs): the document is in a Latin American chapter before 1951 whose title matches `revolution|coup|overthrow|insurrection|junta|provisional|seizure of power|upheaval|political affairs|political situation|internal affairs|political conditions|uprising|revolt` but does not name recognition, and its text matches NEAR (below). I added this rule after finding that Stimson's 1930 recognitions (frus1930v01) sat under headings that never name recognition.
   - **postwar** (264 docs): the document is in one of the 26 Latin American volumes from 1949 to 1988 (the `POST` list in `scope.py`) and matches NEAR.
   - NEAR (Python `re`, IGNORECASE, over header+dateline+source_note+body_text): `recogni[sz]\w*(?:(?!recogni).){0,150}?(?:junta|coup|de facto|new government|provisional government|military government|regime|golpe)|(?:junta|coup|de facto|new government|provisional government|military government|regime|golpe).{0,150}?recogni[sz]`.
   - In every rule, rows with is_front_matter=1 or is_editorial_note=1 are dropped in the script.
3. **Working set ("core", M1)**: heading docs whose text matches `/recogni/i` (841 of 2,654), plus all revchapter (122) and postwar (264) docs, gives **1,227 documents in 73 volumes** (`core.tsv`). frus1913/d7 is in the collection but **not** in the core, because it never uses the word.
4. Second editions: none of frus1951-54IranEd2, frus1969-76ve15p2Ed2 or frus1977-80v09Ed2 is in `scope_vols.txt`.
5. Periodisation uses `document_dates.date_iso`, which this run treats as the index's stored form of `frus:doc-dateTime-min`; I did not verify that against the TEI. Every core document has a date.
6. **Thin-result flag**: the 1890s (17 docs) and 1900s (36) are small, and one negotiation dominates several decades (see M3).

## 2. Controls and false-friend test (M2)

- **M2a, controls**: over the 74 scope volumes, apparatus excluded:
  `SELECT COUNT(*), SUM(pos>0), SUM(neg>0), SUM(pos), SUM(neg), SUM(n), SUM(rec) FROM (SELECT volume_id, SUM((header||' '||coalesce(dateline,'')||' '||coalesce(source_note,'')||' '||body_text) LIKE '%Department of State%') pos, SUM((…) LIKE '%ZZZ_IMPOSSIBLE_ZZZ%') neg, SUM((…) LIKE '%recogni%') rec, COUNT(*) n FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0 AND volume_id IN (<the 74 volumes of scope_vols.txt>) GROUP BY volume_id);`
  returns `74|74|0|16905|0|61288|8290`. The positive control is nonzero in 74 of 74 volumes (16,905 of 61,288 documents); the negative control appears in 0 of 74 volumes. LIKE is case-insensitive.
- **M2b, false-friend test for "recognize/recognition"** (the question's own term). Same LIKE predicates. In the heading chapters, `recogni` appears in 841 of 2,654 documents (0.317); elsewhere in the same 74 volumes it appears in 7,449 of 58,634 (8,290−841 of 61,288−2,654; 0.127). The control "Department of State" appears in 600 of 2,654 (0.226) in the chapters and in 16,305 of 58,634 (0.278) outside them. The term is enriched about 2.5 times while the control is not, so it measures the question. (`falsefriend.txt`, `controls.txt`.)

## 3. Decade shape (M3)

Numerator: core docs by `substr(date_iso,1,3)`. Denominator (`decade_denoms.txt`):
`SELECT substr(dd.date_iso,1,3)||'0s', COUNT(*) FROM document_dates dd JOIN document_cache d ON d.volume_id=dd.volume_id AND d.document_id=dd.document_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND dd.date_iso IS NOT NULL AND dd.date_iso>='1890' AND dd.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') GROUP BY 1;`
(My 1940s denominator is 75,872, not the 74,043 the brief quotes; the predicates differ, and I report mine.)

| decade | core docs | dated non-apparatus docs | per 1,000 | top volume (share of numerator) |
|---|---|---|---|---|
| 1890s | 17 | 9,845 | 1.73 | frus1899, 12 of 17 |
| 1900s | 36 | 10,261 | 3.51 | frus1907p2, 9 of 36 |
| 1910s | 290 | 30,842 | 9.40 | frus1913, 91 of 290 |
| 1920s | 139 | 20,374 | 6.82 | frus1920v03, 32 of 139 |
| 1930s | 259 | 40,073 | 6.46 | frus1932v05, 62 of 259 |
| 1940s | 231 | 75,872 | 3.04 | frus1944v07, 86 of 231 |
| 1950s | 85 | 42,801 | 1.99 | frus1950v02, 26 of 85 |
| 1960s | 113 | 27,654 | 4.09 | frus1961-63v10-12mSupp, 20 of 113 |
| 1970s | 50 | 22,258 | 2.25 | frus1977-80v15, 16 of 50 |
| 1980s | 7 | 6,038 | 1.16 | frus1977-80v15, 5 of 7 |

(`decade_shape.txt`.) The selection rule changes at 1949 (heading-based before, passage-based after), so the shape across 1949 is not a like-for-like series. The overview does not publish the decade shape.

## 4. Condition language (M4)

`families.py`. Literal counts, not index phrase matches: Python `re`, IGNORECASE throughout, over header+dateline+source_note+body_text concatenated and whitespace-collapsed, run over **all** 1,227 core documents (a census, so no sampling). STRICT means the phrase with single spaces. TOLERANT allows the listed inflections and any run of `[\s\-,().]+` between the words. Because these are direct literal counts, no index-stem share is involved. Era denominators: to 1912 = 80, 1913–1932 = 523, 1933–1947 = 329, 1948–1988 = 295; all = 1,227. Each cell reads "TOLERANT/STRICT of denominator".

| family (strict form) | ALL tolerant (strict) of 1,227 | to 1912 | 1913–32 | 1933–47 | 1948–88 |
|---|---|---|---|---|---|
| international obligations | 102 (100) | 5/5 of 80 | 26/25 of 523 | 35/35 of 329 | 36/35 of 295 |
| constitutional government | 71 (71) | 4/4 | 37/37 | 11/11 | 19/19 |
| free elections | 44 (38) | 5/3 | 4/1 | 5/5 | 30/29 |
| effective control | 18 (18) | 0/0 | 0/0 | 3/3 | 15/15 |
| lives and property | 24 (12) | 3/0 | 21/12 | 0/0 | 0/0 |
| other American republics | 71 (68) | 0/0 | 1/1 | 51/50 | 19/17 |
| treaty of peace and amity | 28 (28) | 0/0 | 9/9 | 19/19 | 0/0 |
| Axis (`\bAxis\b`) | 41 (41) | 0/0 | 0/0 | 41/41 | 0/0 |
| communist (`\bcommunist\b`; tol. `\bcommunis(m|t|ts)\b`) | 176 (147) | 0/0 | 11/7 | 11/7 | 154/133 |
| de facto | 181 (181) | 21/21 | 96/96 | 29/29 | 35/35 |
| Article 27 (tol. adds XXVII) | 14 (13) | 0/0 | 14/13 | 0/0 | 0/0 |
| human rights | 28 (28) | 0/0 | 0/0 | 0/0 | 28/28 |

- **M4a**: "international obligations", 102 of 1,227 tolerant (0.083), so "about one in twelve"; present in every era.
- **M4b**: "treaty of peace and amity", only 1913–1947 (9 of 523 and 19 of 329; 0 of 295 after).
- **M4c**: "Article 27", 14 of 523, all in frus1920v03–frus1923v02 Mexico chapters. The ids are in `families_ids.json`: frus1920v03/d224, d225, d237; frus1921v02/d340, d345, d348, d349; frus1922v02/d572, d573, d576, d578, d579; frus1923v02/d472, d481.
- **M4d**: "Axis", 41 of 329 in 1933–47, 0 elsewhere; "other American republics", 51 of 329 in 1933–47, against 1 of 523 before and 19 of 295 after (51 of 71 of all its tolerant hits).
- **M4e**: "communist", 154 of 295 after 1948 (0.52, "about half"), against 11 of 523 and 11 of 329 before; "human rights", 28 of 295 (0.095, "about one in ten") after 1948, 0 before.
- Caveats: the 1948–88 rows come from the passage-level rule, so documents there are selected for proximity to coup and junta language and may differ in kind. "Communist" includes footnotes. A 1.000 strict/tolerant agreement (e.g. "de facto") shows only that the pattern is stable, not that each hit is about recognition. The referent was tested only by the reading in §6.

## 5. Named doctrines and resolutions: literal census of index hits (M5)

Candidate lists: `SELECT d.volume_id, d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '<term>' AND d.is_front_matter=0 AND d.is_editorial_note=0 ORDER BY d.volume_id, d.document_id;` over the WHOLE corpus (553 volumes, not only the scope). Each list is under 300, so `census.py` reads every hit (a census). Python `re`, IGNORECASE, same text surface as §4.

| MATCH term | hits | STRICT | TOLERANT (published) |
|---|---|---|---|
| "Estrada doctrine" | 28 | 27 of 28 | **27 of 28** |
| "Betancourt doctrine" | 3 | 3 of 3 | **3 of 3** |
| "Stimson doctrine" | 10 | 10 of 10 | 10 of 10 (all Asian/Manchurian nonrecognition; not the question's referent) |
| "Resolution XXXV" | 9 | 8 of 9 | 9 of 9 |
| "Resolution XXII" | 23 | 22 of 23 | 23 of 23 |
| "Montevideo formula" | 1 | 1 of 1 | 1 of 1 |
| Tobar (bare) → literal "Tobar doctrine" | 85 | 1 of 85 | **1 of 85** (frus1932v05/d546) |
| Larreta (bare) → "Larreta proposal/note/doctrine" | 30 | 1 of 30 | 2 of 30 |

- **M5a**: Estrada doctrine named in 27 documents; Betancourt in 3; Tobar doctrine in 1. The overview's claim that "the other 84 documents the index returns for the name Tobar do not name the doctrine" is the 85−1 non-matches. I did not read those 84 and do not say who they name.
- Rule breach, declared: "Tobar" and "Larreta" were run as bare-surname index searches. They were used only to produce candidate lists, which were then filtered by the literal doctrine phrase; no person count is published from them.
- The 1.000 tolerant shares (Betancourt, Resolution XXII and XXXV) test the stemmer, not the referent. The referent of Resolution XXXV and XXII was tested by reading frus1948v09/d89 and frus1944v07/d1023 (§6).

## 6. Reading and quotations (M6)

Reading SELECT, in `grab.py`: `SELECT header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?`. The script saves the whole collapsed text to `texts/<vol>__<doc>.txt` and prints `len(body_text)` beside the captured length. **Retrieved whole: 29 documents**, each with captured length equal to length(body_text) (list in `texts/`). frus1913/d7 was retrieved **partially**, its first 1,500 of 3,106 characters via `SELECT volume_id, document_id, header, dateline, length(body_text), substr(body_text,1,1500) FROM document_cache WHERE volume_id='frus1913' AND document_id='d7';`. `coregrep.py` also printed short windows (about 280 characters) from other documents, which were read but are not quoted. **Quoted: 19 documents, 19 quotations** (one per document, plus one shorter sub-span of the frus1917/d414 quotation).

Verification: `verify_quotes.py`, via `SELECT body_text, length(body_text), is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?`, checks each quotation as an exact substring of the raw body_text **and** of the whitespace-collapsed body_text. Result: **19 of 19 match both** (`verify_quotes_out.txt`); none is from front matter or an editorial note. The quotations (the exact strings are in `quotes.json`):

| # | pair | edition | quotation (opening words) |
|---|---|---|---|
| Q1 | frus1895p1/d244 | FRUS 1895, Part I, Doc. 244 (Adee to Tillman, 6 Sept 1895) | "intercourse for the disposal of current matters …" |
| Q2 | frus1913/d894 | FRUS 1913, Doc. 894 (28 Feb 1913) | "the question of the degree to which the population of Mexico acquiesce …" |
| Q3 | frus1930v01/d375 | FRUS 1930, Vol. I, Doc. 375 (press release, 17 Sept 1930) | "the evidence has satisfied me that these provisional governments …" |
| Q4 | frus1949v02/d439 | FRUS 1949, Vol. II, Doc. 439 (Davis, Panama, 1 Dec 1949) | "three conditions viz. “de facto” control …" |
| Q5 | frus1913/d7 | FRUS 1913, Doc. 7 (circular, 12 Mar 1913) | "Cooperation is possible only when supported …" |
| Q6 | frus1917/d378 | FRUS 1917, Doc. 378 (Lansing to Leavell, 9 Feb 1917) | "it will not give recognition or support …" |
| Q7 | frus1917/d414 | FRUS 1917, Doc. 414 (Fernández Guardia, 4 July 1917) | "The Governments of the High Contracting Parties shall not recognize …" |
| Q8 | frus1932v05/d623 | FRUS 1932, Vol. V, Doc. 623 (23 Jan 1932) | "he is not related through consanguinity …" |
| Q9 | frus1936v05/d112 | FRUS 1936, Vol. V, Doc. 112 (Hull to Keena, 30 Apr 1936) | "the United States should no longer be guided by Article II …" |
| Q10 | frus1920v03/d225 | FRUS 1920, Vol. III, Doc. 225 (Davis memo, 30 Aug 1920) | "it was necessary to have a proper and final interpretation of Article 27 …" |
| Q11 | frus1921v02/d344 | FRUS 1921, Vol. II, Doc. 344 (Hughes to Summerlin, 8 June 1921) | "In short, when it appears that there is a government in Mexico …" |
| Q12 | frus1943v05/d335 | FRUS 1943, Vol. V, Doc. 335 (Armour, 6 June 1943) | "it was not my Government’s intention or desire to bargain …" |
| Q13 | frus1944v07/d1023 | FRUS 1944, Vol. VII, Doc. 1023 (8 June 1944) | "consultation is automatically called for …" |
| Q14 | frus1944v07/d432 | FRUS 1944, Vol. VII, Doc. 432 (2 June 1944) | "the pro-Nazi record of the MNR leaders …" |
| Q15 | frus1948v09/d74 | FRUS 1948, Vol. IX, Doc. 74 (Bogotá Final Act, Res. XXXV) | "That the establishment or maintenance of diplomatic relations …" |
| Q16 | frus1948v09/d89 | FRUS 1948, Vol. IX, Doc. 89 (Daniels, 8 Nov 1948) | "In the absence of any compelling reason to the contrary …" |
| Q17 | frus1958-60v06/d217 | FRUS 1958–60, Vol. VI, Doc. 217 (Herter to Eisenhower, 7 Jan 1959) | "The Provisional Government appears free from Communist taint …" |
| Q18 | frus1961-63v12/d421 | FRUS 1961–63, Vol. XII, Doc. 421 (Ball to Kennedy, 27 July 1962) | "the sharp reaction of the United States and other Latin American countries …" |
| Q19 | frus1969-76v21/d348 | FRUS 1969–76, Vol. XXI, Doc. 348 (WSAG minutes, 12 Sept 1973) | "we should take the public position that we recognize governments …" |

Notes on the readings:
- The phrase "usual tests" in the overview is from Q2's document (frus1913/d894: "the light of the usual tests applied to such cases").
- Q10 is the Under Secretary's record of the Mexican side's position ("He fully realized that … it was necessary …"), not a demand in his own voice. The overview words it that way.
- The Bolivian recognition after Q14 is asserted from the editors' chapter heading ("Recognition by the United States and other American Republics of the revolutionary junta in Bolivia"), not from a document I read.
- Q4 cites a "Deptcircinstr June 8, 1948", marked "Not printed" in the document. That is the basis for the overview's "cited but not printed".
- Pre-1925 volumes are cited by their history.state.gov document numbers; the printed volumes of that era were paginated, not numbered by document.

## 7. Archival channels: came-from and pointed-at, never summed (M7)

`channels.py`, over the 1,227 core docs, per pair:
came-from: `SELECT citation_era, repository, record_group, series_name, lot_file_norm, decimal_class FROM document_sources WHERE volume_id=? AND document_id=?`;
pointed-at: `SELECT anchor, repository, collection, lot_file_norm, decimal_class, file_id, inherited FROM external_citations WHERE volume_id=? AND document_id=?`. Output in `channels_out.txt` and `channels.json`.

**Came-from (document_sources), volume set = the 73 core volumes:**
- **M7a**: 1,180 of 1,227 core docs have a source row. citation_era: decimal 995, structured 96, subject_numeric 27, lot_file 25, cfpf 22, named_series 14, published 1. Decimal is 995 of 1,180 (0.84), which the overview gives as "more than four in five". Repository/RG: Department of State RG 59, 1,047 of 1,180.
- **M7b**: top decimal classes, glossed by `gloss.py` with decimal-class-labels.json and gated on the citing documents' own years (every listed key's documents fall inside the 1910–1949 glossable span; `gloss_out.txt`): 812.00 Mexico political affairs, 199 docs, 1910–1922; 816.01 El Salvador government, 120, 1931–1948; 824.00 Bolivia political affairs, 69, 1920–1946; 824.01 Bolivia government, 48, 1930–1946; 818.00 Costa Rica political affairs, 46, 1911–1920; 838.00 Haiti political affairs, 31, 1911–1946; 823.00 Peru political affairs, 28, 1913–1930; 814.01 Guatemala government, 24, 1931–1944; 822.01 Ecuador government, 23, 1928–1947; 835.00 Argentina political affairs, 20, 1930–1945.
- **M7c**: the Central Decimal File's own series identity. collection-authority.json holds only "Central Decimal File 1910–1929" (RG 59, no naId) and "Central Files" (no naId); no bundled file gives a NAID, entry or access status for it (greps logged). The overview says so.
- **M7d**: lots (central-files-index.json `lotFiles` keyed on `lotNumber`, series facts from series-facts-index.json `byNaId` decoded via `legend`; `lots.py`, `lots_out.txt`). All are thin, 1 to 3 docs each: 63D351 (3) and 66D95 (1) → Records Relating to National Security Council Policy Papers, RG 59, A1 1586E, NAID 2839192, 1947–1979, Restricted – Partly; 64D199 (3) → The Secretary's and the Under Secretary's Memorandums of Conversation, A1 1566, NAID 602231, 1953–1964, Unrestricted; 63D75 (3) → Records Related to the Secretary's Staff Meetings, A1 1609, NAID 2521274, 1952–1961, Restricted – Possibly; 66D65 (2) and 73D115 (1) → ARA Subject and Country Files, A1 5763, NAID 1074073, 1962–1975, Restricted – Partly; 64D16 (1) → Records Relating to El Salvador, A1 3159, NAID 1750062, 1958–1975, Restricted – Partly; 67D46 (1) → Records Relating to Honduras, A1 5732, NAID 2602882, 1957–1974, Restricted – Partly. Not resolved: 57D649 and the junk value "NO".
- Presidential libraries (came-from): Kennedy 16, Carter 15, Eisenhower 10, Nixon 10, Johnson 6. CIA 32.

**Pointed-at (external_citations), volume set = the 73 core volumes.** The channel has no row before 1910-12-06, stores the citation fragment rather than the sentence, and holds lot, library and decimal anchors only.
- **M7e**: 155 rows in 97 of 1,227 docs (0.079, "fewer than one in twelve"). Anchors: centralFileClass 93, presidentialLibrary 38, lotFile 24.
- **M7f**: decimal classes, glossed under the governing schedule (`gloss_pointed.txt`): 737.00, 9 rows, 1959–1962, glossed as Cuba [Internal Political and National Defense Affairs] under the 1950–59 and 1960–63 schedules (subject 00 not in the shipped subject list); 723.00, 5, 1962, Peru, same class; 738.00, 4, 1950–1959, Haiti, same class.
- **M7g**: libraries. Carter Library "National Security Affairs", 27 rows. The bundled catalogue has no collection by that exact name; the nearest is "Records of the Office of the National Security Advisor (Carter Administration)", JC-NSA, NAID 560131, but the match is by name only and unconfirmed, so the overview says "files cited as". Johnson Library "National Security File", 6 rows → LBJ-NSF NAID 567979, series Latin America Country Files NAID 567985, 1963–1969.
- **M7h**: lots, pointed-at: 59D573 (1) and 61D279 (1) → Subject Files, Office of the Asst. Sec. for Inter-American Affairs, A1 1135, NAID 2108779, 1957–1959, Unrestricted; 63D127 (2) → Subject and Country Files, Office of Central American and Panamanian Affairs, A1 3157, NAID 2363840, 1955–1963, Restricted – Possibly; 67D46 (1) → Records Relating to Honduras (in both channels); 61D385 (2), not in lotFiles.
- **M7i**: before 1910, for Q1's case: central-files-index.json `countrySeries`. Diplomatic Despatches (series NAID 603720), roll "Despatches from U.S. Ministers to Ecuador, 1848-1906", May 14 1894–Dec 28 1896, NAID 189312130. Diplomatic Instructions (series NAID 593313), roll "Volume 1-2: Ecuador", 1848–1906, NAID 149303924. The bundle's archival stack barely reaches before 1940 (11 of 695 series, per the brief); I did not re-measure that figure.
- I did not use collection-usage-index.json, external-citation-index.json, lot-claimants beyond the claimant lines printed in `lots_out.txt`, accession-series-index.json, or the digitized-range indexes. Volume-level ranking was not attempted.
- NARA creator attribution was not used to decide on-topic status. Every series named was reached from a FRUS citation, not from a creator heading.

## 8. Absences (M8)

- **M8a**: no Central America volume after 1980. The manifest lists 13 frus1981-88 volumes (`python3 -c` logged), and the only Latin American one is frus1981-88v16 South America. `SELECT COUNT(DISTINCT volume_id) FROM document_cache WHERE volume_id LIKE 'frus1981%';` returns 13. frus1981-88v16 contributed 0 core documents under NEAR.
- **M8b**: the Latin American side. M5 counts; foreign archives are outside every bundled index.
- Controls for these absences: M2a.

## 9. Collection

`collection.fruscollection`, built by `make_collection.py`. It holds 19 document entries and 19 excerpts (the strings in `quotes.json`) under five headings that follow the findings, in date order within each, plus a closing prose block and a `generated` `archivalSources` block. Each pair was checked with `SELECT 1 FROM document_cache WHERE volume_id=? AND document_id=?`; there are no duplicates and no Ed2 volume. `check_overview.py` confirms that the overview cites 19 pairs, all in the collection, with no collection document left uncited. Every quoted span of 25 or more characters in the overview is a substring of a verified quotation; the two exceptions it flags are a series label and the collection's name, not quotations. All 19 excerpts equal verified quotations.

## 10. Trace table (overview → memo)

| overview item | source line |
|---|---|
| "all 553 volumes" | M0a |
| "about twelve hundred documents in 73 volumes"; "1,227 documents in 73 volumes"; "74 of them" | §1.3 (M1), `scope_vols.txt` |
| "more than four in five … Central Decimal File in Record Group 59" | M7a |
| decimal files named, with their dates | M7b |
| "no NARA identifier, entry number or access status" for the decimal file | M7c |
| lot files with NAID, entry, dates, access (came-from); "never more than three from any one" | M7d |
| "fewer than one document in twelve has a citation the index can resolve" | M7e |
| Cuba 1959–62, Haiti 1950s, Peru 1962 decimal files (pointed-at) | M7f |
| Johnson NSF NAID 567985; "files cited as the Carter Library's 'National Security Affairs'" | M7g |
| pointed-at lots 2108779, 2363840; Honduras in both | M7h, M7d |
| Ecuador 1895 despatch and instruction rolls | M7i |
| Estrada 27, Betancourt 3, Tobar 1, "other 84" | M5a |
| 8 June 1948 circular cited, not printed | §6 note on Q4 |
| no Central America volume after 1980 | M8a |
| "before December 1910 … barely reach before 1940" | M7 channel caveat, M7i |
| controls: "every one of the 74 volumes … a nonsense string in none" | M2a |
| "about one in three … against about one in eight … control does not rise" | M2b |
| "international obligations … roughly one … in twelve" | M4a |
| treaty only 1913–1947 | M4b |
| Article 27 only in Mexican chapters 1920–1923 | M4c |
| Axis only 1933–1947; "other American republics" mostly then | M4d |
| communism about half, human rights about one in ten after 1948; earlier a few in a hundred and none | M4e |
| "usual tests" | §6 note, Q2 |
| Q1–Q19 quotations | §6 table and `quotes.json`; verified in `verify_quotes_out.txt` |
| Q7 sub-span "into power in any of the five Republics …" | §6, Q7 |
| Bolivian recognition "the editors' chapter heading records" | §6 note on Q14 |
| "Mexico's 1917 Constitution that vested subsoil oil in the nation" (gloss of Article 27) | contextual gloss, not from a retrieved document; supported only by the Article 27 documents' language (frus1922v02/d576: "petroleum deposits of the subsoil to be the property of the Nation", window from `coregrep.py 'Article 27'`) |
