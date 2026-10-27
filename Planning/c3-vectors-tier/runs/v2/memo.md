# Scope memo — Cuba in U.S. thinking about national security and prosperity, 1870s–1980

Run directory: /Users/jbotts/frus-analysis/c3v/runs/v2. Session date 2026-10-26. Every command is in queries.log (with its ELIDED line). All counts are conditional on the library copy: **553 volumes, 321,749 documents (1,103 front matter, 8,481 editorial notes)** — the full 553-volume series is present in this copy, so "the library" and "the series" coincide for volume coverage here.

## 0. Canary and coverage
- `SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;` → `553|321749|1103|8481` (matches the brief).
- `BEGIN; CREATE TABLE zz(x); ROLLBACK;` under `-readonly` → `attempt to write a readonly database` (read-only proven).

## 1. Scope chosen, and how it was found
**Inclusion rule (the "Cuba core set").**
(A) every document filed by the editors in a section whose title matches `/cuba|havana/i` (case-insensitive Python regex over `volume_structures.structure_json` section titles, all depths; `chapters.py` → `cuba_chapters.tsv`, 159 sections, 6,735 listed document ids), except the frus1896 section about the British steamship named *Cuban*; plus
(B) for the volumes frus1861 … frus1894* (which have no Cuba chapter — Cuba is filed under Spain), every document whose `body_text` has ≥3 matches of `\b(Cuba|Cuban|Cubans|Havana)\b` (re.I).
Always: `is_front_matter=0 AND is_editorial_note=0`; frus1951-54IranEd2 and frus1969-76ve15p2Ed2 dropped (neither touches the set).
Script: `coreset.py` → `coreset.json`, `coreset_out.txt`. Result: **7,013 documents (6,515 by rule A, 498 by rule B) in 130 volumes, dated 1849-08-09 to 1980-12-25**; by band (year of `document_dates.date_iso`): 1840–1860 8; 1861–1898 891; 1899–1933 2,206; 1934–1958 1,181; 1959–1980 2,727.
**Periodisation**: on `document_dates.date_iso` (the index's day for `frus:doc-dateTime-min`), never on the volume's series year.

**How found.** (1) An exploratory mention count per decade (FTS `{header dateline body_text}: (cuba OR cuban OR havana OR habana)`, apparatus excluded, Ed2 dropped) — `decade_cuba2.txt`; (2) volume ranking (`vol_cuba.txt`); (3) the editors' chapter headings (`chapters_out.txt`, `subsec.py` output in queries.log) — the 1870s–1890s have no Cuba chapter (Cuba sits under "Spain"), the annuals carry a "Cuba" chapter from frus1902, and dedicated Cuba volumes begin with frus1958-60v06.

Decade mention table (exploratory, NOT the core set), `decade_cuba2.txt`, SQL:
```
WITH base AS (SELECT c.volume_id, c.document_id, substr(d.date_iso,1,3)||'0s' AS dec FROM document_cache c JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') AND d.date_iso IS NOT NULL),
hits AS (SELECT c.volume_id, c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH '{header dateline body_text}: (cuba OR cuban OR havana OR habana)')
SELECT b.dec, COUNT(*), SUM(h.volume_id IS NOT NULL), ROUND(1000.0*SUM(h.volume_id IS NOT NULL)/COUNT(*),1) FROM base b LEFT JOIN hits h ON h.volume_id=b.volume_id AND h.document_id=b.document_id WHERE b.dec BETWEEN '1860s' AND '1980s' GROUP BY b.dec;
```
| decade | dated docs | mention Cuba | per 1,000 |
|---|---|---|---|
| 1860s | 11,268 | 448 | 39.8 |
| 1870s | 5,821 | 400 | 68.7 |
| 1880s | 6,484 | 306 | 47.2 |
| 1890s | 9,845 | 783 | 79.5 |
| 1900s | 10,261 | 408 | 39.8 |
| 1910s | 30,842 | 1,033 | 33.5 |
| 1920s | 20,374 | 767 | 37.6 |
| 1930s | 40,073 | 1,192 | 29.7 |
| 1940s | 75,872 | 1,725 | 22.7 |
| 1950s | 42,801 | 1,032 | 24.1 |
| 1960s | 27,654 | 3,173 | 114.7 |
| 1970s | 22,258 | 1,931 | 86.8 |
| 1980s | 6,038 | 643 | 106.5 |
Top-volume share of a decade's numerator (header-level variant, `decade_cuba_header.txt`, without habana): e.g. 1930s frus1933v05 285 of 542; 1950s frus1958-60v06 201 of 238; 1980s frus1977-80v23 7 of 7. Core-set top-volume shares are in §2. An earlier run of this table without `habana` (`decade_cuba.txt`) undercounted 1890s (649 vs 783) and 1940s (1,423 vs 1,725) — see §3 variant scan.

**Literal share of the mention family** (`litshare.py`): hit list (without habana) M = 13,140, evenly spaced 40 from the (volume_id, document_id)-sorted list; surface header+dateline+source_note+body_text, whitespace-collapsed; Python `re`, re.I. **TOLERANT 40 of 40; STRICT 39 of 40** (STRICT `\b(cuba|cuban|havana)\b`; TOLERANT `\b(cuba|cubans?|havana|havannah?)('s)?\b`). A 1.000 tolerant share tests the stemmer only; the referent test is the core set's rule A (the editors filed these documents under Cuba) — the one known non-island referent (the steamship *Cuban*) is excluded by name.

## 2. What was measured — vocabulary families in the core set vs a decade baseline
Script `coreset.py` (core, output `coreset_out.txt`) and `baseline.py` (300 random dated non-apparatus documents per decade, `random.Random(1877)`, Ed2 dropped; output `baseline_out.txt`). Surface for both: header+dateline+body_text whitespace-collapsed (body_text INCLUDES editorial footnotes; apparatus not separated from document text), Python `re`, re.I, word-bounded:
- security_word `\bsecurity\b`
- strategic_naval `\b(strategic\w*|naval|navy|coaling|Guantanamo|base|bases)\b`
- soviet_communist_missile `\b(Soviets?|Sino-Soviet|communis[mt]s?|missiles?|subversi\w+|Castroism|Castroite)\b`
- economy `\b(sugar|tariffs?|reciprocity|trade|commerce|commercial|investments?|tobacco)\b`
- property_claims `\b(property|properties|claims?|expropriat\w+|nationaliz\w+|compensation)\b`
- order_intervention `\b(insurrection\w*|revolution\w*|intervention|intervene|Platt|annexation|stability|disorder)\b`
These are literal regex tests (no FTS phrase), so the phrase-share obligation is met by construction; each is a "document contains ≥1" share.

| decade | core N (top vol) | security | strategic/naval | Soviet/communist/missile | economy | property/claims | order/intervention |
|---|---|---|---|---|---|---|---|
| 1860s core | 266 (frus1872p2v1 152/266) | 19/266 | 72/266 | 3/266 | 66/266 | 43/266 | 38/266 |
| 1860s base | 300 | 9/300 | 47/300 | 1/300 | 49/300 | 44/300 | 34/300 |
| 1870s core | 210 (frus1874 56/210) | 29/210 | 87/210 | 4/210 | 90/210 | 114/210 | 108/210 |
| 1870s base | 300 | 18/300 | 42/300 | 2/300 | 93/300 | 97/300 | 44/300 |
| 1880s core | 138 (frus1885 28/138) | 9/138 | 22/138 | 1/138 | 86/138 | 56/138 | 33/138 |
| 1880s base | 300 | 12/300 | 26/300 | 2/300 | 69/300 | 78/300 | 34/300 |
| 1890s core | 300 (frus1898 147/300) | 13/300 | 33/300 | 0/300 | 90/300 | 66/300 | 62/300 |
| 1890s base | 300 | 16/300 | 34/300 | 0/300 | 36/300 | 64/300 | 31/300 |
| 1900s core | 289 (frus1902 91/289) | 8/289 | 24/289 | 0/289 | 54/289 | 58/289 | 57/289 |
| 1900s base | 300 | 11/300 | 22/300 | 1/300 | 43/300 | 53/300 | 31/300 |
| 1910s core | 975 (frus1917 223/975) | 17/975 | 175/975 | 1/975 | 172/975 | 221/975 | 167/975 |
| 1910s base | 300 | 7/300 | 34/300 | 3/300 | 65/300 | 39/300 | 24/300 |
| 1920s core | 461 (frus1921v01 133/461) | 20/461 | 30/461 | 1/461 | 106/461 | 103/461 | 59/461 |
| 1920s base | 300 | 5/300 | 39/300 | 9/300 | 50/300 | 46/300 | 19/300 |
| 1930s core | 651 (frus1933v05 344/651) | 22/651 | 41/651 | 37/651 | 148/651 | 82/651 | 172/651 |
| 1930s base | 300 | 10/300 | 42/300 | 29/300 | 65/300 | 41/300 | 20/300 |
| 1940s core | 728 (frus1944v07 124/728) | 25/728 | 142/728 | 20/728 | 389/728 | 122/728 | 38/728 |
| 1940s base | 300 | 34/300 | 44/300 | 88/300 | 56/300 | 38/300 | 22/300 |
| 1950s core | 449 (frus1958-60v06 354/449) | 70/449 | 124/449 | 168/449 | 159/449 | 95/449 | 207/449 |
| 1950s base | 300 | 102/300 | 63/300 | 143/300 | 50/300 | 23/300 | 47/300 |
| 1960s core | 2,001 (frus1961-63v10-12mSupp 515/2001) | 1006/2001 | 770/2001 | 1280/2001 | 485/2001 | 201/2001 | 510/2001 |
| 1960s base | 300 | 161/300 | 72/300 | 155/300 | 52/300 | 36/300 | 47/300 |
| 1970s core | 450 (frus1977-80v23 289/450) | 304/450 | 141/450 | 193/450 | 162/450 | 75/450 | 135/450 |
| 1970s base | 300 | 197/300 | 85/300 | 140/300 | 73/300 | 45/300 | 63/300 |
| 1980s core | 89 (frus1977-80v23 89/89) | 73/89 | 25/89 | 29/89 | 26/89 | 8/89 | 18/89 |
| 1980s base | 300 | 187/300 | 118/300 | 192/300 | 87/300 | 37/300 | 81/300 |
(1840s 2 docs and 1850s 4 docs in core, all frus1872p2v1 — too thin to read.)

Readings (each is a lead, not a measurement of "thinking"):
- **M1** 1870s: order/intervention vocabulary in 108 of 210 core vs 44 of 300 baseline; strategic/naval 87 of 210 vs 42 of 300 (the *Virginius* affair; top volume frus1874 has 56 of the 210). Property/claims 114 of 210 vs 97 of 300.
- **M2** 1880s: economy 86 of 138 core vs 69 of 300 baseline (top volume frus1885, 28 of 138 — reciprocity negotiations; thin). Note: the 1880s numerator contains a reprint pair (frus1881/d405 and frus1894app2/d394, Hamming 4; §VECTORS) — one document counted twice in 138.
- **M3** 1910s: property/claims 221 of 975 vs 39 of 300; strategic/naval 175 of 975 vs 34 of 300 (top volume frus1917 223 of 975).
- **M4** 1940s: economy 389 of 728 vs 56 of 300 — the highest relative excess in the table (sugar, Lend-Lease, credit).
- **M5** 1950s: Soviet/communist/missile 168 of 449 core vs 143 of 300 baseline — Cuba's documents were LESS Cold-War-worded than the corpus in the 1950s (354 of the 449 are frus1958-60v06, i.e. 1958–59 revolution reporting).
- **M6** 1960s: Soviet/communist/missile 1,280 of 2,001 vs 155 of 300; strategic/naval 770 of 2,001 vs 72 of 300; economy 485 of 2,001 vs 52 of 300 (economic denial is now a weapon, see heading "Inauguration by the U.S. Government of a policy to weaken the Cuban economy").
- **M7** the word "security" in the 1960s core is 1,006 of 2,001 vs 161 of 300 baseline, and in the 1970s 304 of 450 vs 197 of 300: **at the corpus baseline** — see false-friend test below.

**False-friend test of the question's own terms** (`ff.py`, output `ff_out.txt`; baseline 400 random documents per band, Random(1877); same surface; re.I):
| band | set | N | "national security" STRICT | TOLERANT | prosper* | control "Secretary of State" |
|---|---|---|---|---|---|---|
| 1861–1898 | core | 891 | 0/891 | 0/891 | 69/891 | 304/891 |
| 1861–1898 | base | 400 | 0/400 | 0/400 | 15/400 | 92/400 |
| 1899–1933 | core | 2,206 | 1/2206 | 1/2206 | 56/2206 | 1888/2206 |
| 1899–1933 | base | 400 | 1/400 | 1/400 | 3/400 | 332/400 |
| 1934–1958 | core | 1,181 | 9/1181 | 9/1181 | 18/1181 | 848/1181 |
| 1934–1958 | base | 400 | 10/400 | 10/400 | 3/400 | 292/400 |
| 1959–1980 | core | 2,727 | 1021/2727 | 1021/2727 | 33/2727 | 601/2727 |
| 1959–1980 | base | 400 | 181/400 | 181/400 | 6/400 | 103/400 |
- **M8** "national security" (STRICT `\bnational security\b`, TOLERANT `\bnational[\s\-,.()]+securit(y|ies)\b`): absent before 1934 in both sets; 1959–1980 core 1,021 of 2,727 vs baseline 181 of 400 — at or below baseline, and its referent in this era is overwhelmingly the institution (National Security Council / Assistant for National Security Affairs in headers). **It measures the corpus, not the question; not used further.**
- **M9** "prosper*": 1861–1898 core 69 of 891 vs 15 of 400; 1899–1933 56 of 2,206 vs 3 of 400; 1934–1958 18 of 1,181 vs 3 of 400; 1959–1980 33 of 2,727 vs 6 of 400. The baseline numerators are tiny (3–15), so only the direction is safe: the word is Cuba-distinctive before 1959 and at baseline after. The control phrase is NOT stable between sets (core runs higher in every band — e.g. 1,888 of 2,206 vs 332 of 400), so the core set is more State-Department-correspondence-heavy than the baseline; ratios are confounded by that and are not published as rates.

**Editors' headings theme tally** (`headings.py` → `headings_out.txt`, `headings_leaves.tsv`; leaf sections under a Cuba-titled section; themes by re.I on the heading path; docs counted once per matching theme):
| band | docs | security | economy | property/claims | politics/order | other |
|---|---|---|---|---|---|---|
| 1840–1898 | 401 | 3/401 | 37/401 | 18/401 | 41/401 | 303/401 |
| 1899–1933 | 2,206 | 208/2206 | 642/2206 | 173/2206 | 956/2206 | 492/2206 |
| 1934–1958 | 1,231 | 250/1231 | 796/1231 | 10/1231 | 330/1231 | 191/1231 |
| 1959–1980 | 2,677 | 485/2677 | 46/2677 | 0/2677 | 241/2677 | 1979/2677 |
- **M10** Between the wars the editors' own headings file roughly two Cuba documents in three under economic headings for 1934–58 (796 of 1,231), against 642 of 2,206 for 1899–1933. After 1959 the compilations are chronological ("Cuba, 1961–1962", month headings in the microfiche supplement), so 1,979 of 2,677 fall under no thematic heading — the tally cannot measure the post-1959 era, and the 46 economy documents are the heading "Inauguration by the U.S. Government of a policy to weaken the Cuban economy, April–July 1960".

## 3. [TEI] spelling-variant scan with controls
Script `tei_scan.py` → `tei_scan.tsv` (one row per volume, 553 rows), `tei_scan.log` ("finished"). **Counting surface: tag-stripped (`<[^>]+>` → space), `html.unescape`, whitespace-collapsed, WHOLE volume (apparatus NOT separated from document text).** Case-sensitive, word-bounded Python `re`. Totals (sum over volumes; volumes with ≥1):
| form | count | volumes |
|---|---|---|
| Cuba | 50,771 | 472 |
| CUBA | 364 | 55 |
| Cuban | 29,249 | 372 |
| Cubans | 5,041 | 195 |
| CUBAN/CUBANS | 82 | 13 |
| Havana | 4,623 | 260 |
| **Habana** | **6,076** | 165 |
| Havanna/Havannah | 1 | 1 |
| HAVANA/HABANA | 12 | 7 |
| island/Island of Cuba | 1,029 | 86 |
| POSITIVE "Department of State" | 177,748 | 552 of 553 (zero only in frus1919Parisv05) |
| NEGATIVE "ZZZ_IMPOSSIBLE_ZZZ" | 0 | 0 |
- **M11** "Habana" outnumbers "Havana" (6,076 vs 4,623). FTS check: `{header body_text dateline}: habana NOT (cuba OR cuban OR havana)` → **759** documents (apparatus excluded) of 3,079 matching `habana`; the decade table was rerun with habana added (§1). The core set is unaffected (rule A is by the editors' filing; rule B is pre-1895, before the Habana spelling took hold in this corpus — not separately verified).

## 4. Archival scope — two channels, never summed (core set, 7,013 documents)
Script `archival.py` → `archival_out.txt` (core ids in a TEMP table of an in-memory connection; the index ATTACHed read-only).
**Came-from** (document_sources; one row per document; 5,831 of the 7,013 core documents have a row):
```
SELECT s.repository, s.record_group, COALESCE(s.lot_file_norm, s.series_name), s.citation_era, COUNT(*) n, MIN(c.yr), MAX(c.yr)
FROM core c JOIN f.document_sources s ON s.volume_id=c.volume_id AND s.document_id=c.document_id GROUP BY 1,2,3,4 ORDER BY n DESC LIMIT 30
```
Top rows: CIA (structured) 328, 1958–1980; Kennedy Library National Security Files 249 (+ "NSF" 112), 1961–63; Carter Library National Security Affairs 197; Johnson Library National Security File 165; RG 59 Central Files 1964–66 (subject_numeric) 96; Nixon NSC Files 79; Eisenhower Whitman File 65; RG 59 lot 65D438 51; RG 330 OASD(C) A Files FRC 71 A 2896 47; RG 59 lot 74D272 46; lot 66D501 23; lot 65A987 19 (1947); lot 62D24 15; lot 62D418 15.
Came-from decimal classes (`SELECT s.decimal_class, COUNT(*) … WHERE s.decimal_class IS NOT NULL GROUP BY 1 ORDER BY 2 DESC`): 837.00 749; 837.51 331; 737.00 279; 837.61351 235; 611.3731 140; 763.72 73; 811.34537 71; 611.37 63.
[JSON] Gloss (`gloss.py`; decimal-class-labels.json, schedule 1910-1949, glossable 1910–1949 per `coverage.glossableYears`): 837.00 = class 8 Internal Affairs of States, country 37 Cuba, subject 00 Political affairs (came-from rows corpus-wide dated 1911-11-10 to **1960-02-25** — rows after 1949 fall outside this schedule and are NOT glossed by it); 837.51 = Cuba, Financial conditions (1917–1949); 837.61351 = Cuba, subject 61351 "Cane" (1917–1949); 611.3731 = class 6 Commerce, country 11 United States — the file glosses no subject for the suffix (1911–1947). 737.00 (1953–1963) falls under the 1950-1959 schedule, whose class 7 is "Internal Political and National Defense Affairs" and country 37 Cuba; that schedule ships no subject vocabulary, so ".00" is not glossed.
**Pointed-at** (external_citations; footnote mentions; many rows per document; no row before 1910-12-06; holds lot, library and decimal anchors only, as the citation fragment):
```
SELECT e.repository, e.collection, e.lot_file_norm, COUNT(*) n, COUNT(DISTINCT e.volume_id||'/'||e.document_id) docs, MIN(c.yr), MAX(c.yr)
FROM core c JOIN f.external_citations e ON e.volume_id=c.volume_id AND e.document_id=c.document_id GROUP BY 1,2,3 ORDER BY docs DESC LIMIT 30
```
Top rows: Department of State (decimal anchors, no collection) 467 rows / 342 docs, 1913–1962; Carter Library National Security Affairs 100/73; Kennedy NSF 72/62; Johnson NSF 71/59; lot 66D95 25/22 (1958–60); lot 65D438 15/13; Johnson Recordings and Transcripts 14/13; lot 66D204 9/9; lot 62D24 10/8; Eisenhower Project "Clean Up" 8/8; lot 74D272 7/6; lot 62D418 5/5; lot 65D330 5/5; lot 64D199 5/3; lot 65D212 4/3.
[JSON] Lot resolution (`lots.py`; central-files-index.json `lotFiles` by `lotNumber`, then series-facts-index.json `byNaId`, decoded with `headings`/`statuses`):
| lot | title (NARA) | RG / entry | NAID | creator heading | dates (y0–y1) | access | channel(s) in core |
|---|---|---|---|---|---|---|---|
| 65D438 | Records Relating to the Cuban Missile Crisis | RG 59, A1 3053 | 27022950 | Dept. of State, Executive Secretariat | 1962–1963 | Restricted – Partly | came-from 51; pointed-at 13 docs |
| 74D272 | Records of Under Secretary of State George W. Ball | RG 59, A1 5175 | 614703 | Office of the Under Secretary | 1961–1966 | Unrestricted | came-from 46; pointed-at 6 |
| 66D501 | Files Pertaining to Operation Mongoose | RG 59, UD-UP 293-B | 648748 | ARA, Office of the Coordinator of Cuban Affairs | 1963–1965 | Unrestricted | came-from 23 |
| 62D24 | Subject Files | RG 59, A1 3148 | 2363836 | ARA, Special Assistant on Communism | 1958–1961 | Restricted – Partly | came-from 15; pointed-at 8 |
| 62D418 | Subject Files | RG 59, A1 3147 | 2068466 | ARA, Office of the Assistant Secretary | 1959–1962 | Restricted – Partly | came-from 15; pointed-at 5 |
| 66D95 | Records Relating to NSC Policy Papers | RG 59, A1 1586E | 2839192 | Office of the Secretary, Executive Secretariat | 1947–1979 | Restricted – Partly | pointed-at 22 docs |
| 66D204 | Presidential and Secretary of State Correspondence with Foreign Heads of State | RG 59, A1 1590 | 2538452 | Executive Secretariat | 1953–1964 | Restricted – Possibly | pointed-at 9 |
| 62D1 | Records Relating to Activities with the NSC | RG 59, A1 1583E/F | 2838992 | Policy Planning Council | 1948–1961 | Restricted – Partly | came-from of frus1961-63v10/d202 |
| 65D212 | Records Relating to Sugar | RG 59, UD-UP 215 | 27022874 | Bureau of Economic Affairs, Office of International Resources | 1955–1962 | Restricted – Fully | pointed-at 3 docs; came-from of frus1955-57v06/d260 |
| 65A987 | Records Relating to the Havana Convention on Commercial Aviation | RG 59, P 184 | 2945755 | Division of International Conferences | 1938–1944 | Restricted – Possibly | came-from 19 docs, all 1947 — **creator/title mismatch with 1947 dates; treat this resolution as unverified** |
70D149 is not in central-files-index.json. Creator headings were read but not verified against each series' description beyond title fit.
[JSON] Nineteenth-century shelves (central-files-index.json `countrySeries`, geoKeys cuba/spain): Despatches from U.S. Ministers to Spain, 1792–1906 (file unit NAID 177380726, 134 rolls); Despatches from U.S. Ministers to Cuba, 1902–1906 (177380758, 18 rolls); Notes from the Spanish Legation, 1790–1906 (183303928, 31 rolls); Notes from the Cuban Legation, 1844–1906 (183303950, 2 rolls); Diplomatic Instructions and Notes to Foreign Missions rolls (no file-unit title in the file). The offline stack barely reaches before 1940 (11 of 695 bundled series); pre-1906 roadmap is the microfilm country series only.

## 5. Quotations — every one verified (`verify.py` → `verify_out.txt`: 17 of 17, exact substring of raw body_text AND of the collapsed header+dateline+source_note+body_text; 16 documents)
Reading SELECT (`dump.py`): `SELECT header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?`; raw text in `raw/<volume>__<doc>.txt`. **29 documents retrieved whole (captured length = length(body_text) for all 29); 16 quoted.**
| # | pair | date | quotation |
|---|---|---|---|
| Q1 | frus1870/d197 | 1870-08-19 | "With the Spanish islands of Cuba and Porto Rico we maintain, in spite of their adverse legislation, a large commerce by reason of our necessities and of their proximity." |
| Q2 | frus1881/d405 | 1881-12-01 | "That rich island, the key to the Gulf of Mexico, and the field for our most extended trade in the Western Hemisphere is, though in the hands of Spain, a part of the American commercial system." |
| Q3 | frus1898/d490 | 1897-07-16 | "The commerce of Cuba has dwindled to such unprofitable proportions that its ability for self-support is questionable even if peace was restored to day." |
| Q4 | frus1898/ch83 | 1898-04-12 (text dated April 11, 1898) | "The right to intervene may be justified by the very serious injury to the commerce, trade, and business of our people, and by the wanton destruction of property and devastation of the island." |
| Q5 | frus1898/ch83 | same | "The present condition of affairs in Cuba is a constant menace to our peace, and entails upon this Government an enormous expense." |
| Q6 | frus1902/d313 | 1902-11-21 | "Cuba consents that the United States shall reserve and retain the right to intervene for the preservation of the independence of Cuba, and the maintenance of a stable government that will duly protect life, property, and individual liberty" (in the enclosed Cuban commission report) |
| Q7 | frus1903/d331 | 1903-02-16 | "To enable the United States to maintain the independence of Cuba, and to protect the people thereof, as well as for its own defense, the Cuban Government will sell or lease to the United States the lands necessary for coaling or naval stations" |
| Q8 | frus1906p1/d427 | 1906-09-14 | "This nation asks nothing of Cuba, save that it shall continue to develop as it has developed during these past seven years" |
| Q9 | frus1933v05/d281 | 1933-07-17 | "We will likewise regain an exceedingly important market for our exports." |
| Q10 | frus1941v07/d119 | 1941-07-14 | "a cooperative defense agreement with the Cubans is nevertheless essential for its effect on United States relations with Cuba and the other American republics." |
| Q11 | frus1952-54v04/d343 | 1954-06-07 | "It would result in corresponding reductions in the considerable United States exports to Cuba and would jeopardize the concept of Cuba as a strategic sugar reserve." |
| Q12 | frus1961-63v10/d202 | 1961-05-04 | "There is the remote possibility of an attempt to convert Cuba into a Russian base for strategic attack on the United States." |
| Q13 | frus1961-63v11/d34 | 1962-10-20 | "In his view the existence of fifty planes in Cuba did not affect the balance of power, but the missiles already in Cuba were an entirely different matter." (the speaker is the President; preceding sentence: "The President stated flatly that the Soviet planes in Cuba did not concern him particularly.") |
| Q14 | frus1969-76ve10/d205 | 1969-07-02 | "Cuba has been a double-barreled problem for the U.S.: —as a base for Soviet military power, and —as an exporter of revolutionary doctrine and violence to Latin America." |
| Q15 | frus1969-76v12/d211 | 1970-09-22 | "The latest and perhaps the most serious challenge to US security interests is occurring in Cuba." |
| Q16 | frus1977-80v23/d21 | 1977-08-12 | "The political significance of both sides of the trade issue far outweighs economic effects." |
| Q17 | frus1977-80v23/d98 | 1980-04-28 | "the influx of Cuban and Haitian refugees requires the highest degree of coordination of the Federal government’s domestic resources" |
FTS queries that surfaced these (all in queries.log via `find.sh`, whose body is `SELECT c.volume_id||'/'||c.document_id, d.date_iso, length(c.body_text), substr(header…) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid LEFT JOIN document_dates d ON (both keys) WHERE frus_documents MATCH '<q>' AND c.volume_id GLOB '<g>' AND c.is_front_matter=0 AND c.is_editorial_note=0 ORDER BY bm25(frus_documents) LIMIT n`): Q1, Q3–Q5 from `{body_text}: cuba AND (proximity OR vicinity OR neighboring) AND commerce AND "interests of the united states"` over frus18[6789]*; Q2 from `{body_text}: cuba AND reciprocity AND sugar AND treaty` over frus188*; Q6–Q7 from `… ("Platt amendment" OR "naval stations" OR "coaling stations") AND independence` over frus190*; Q8 from `roosevelt AND quesada …` over frus1906p1; Q9 from `welles AND sugar AND (economic OR prosperity)` over frus1933v05; Q10 from `(defense OR defence) AND (hemisphere) AND (airfield* OR bases OR "naval")` over frus1941v07; Q11 from `cuba AND communis* AND (sugar OR investment*) AND (strategic OR guantanamo)` over frus195[25]*; Q12 from `cuba AND ("base for" OR "platform") AND subversion AND (…)` over frus1961-63v1[01]; Q13 from `missiles AND cuba AND ("strategic balance" OR "balance of power") AND ("first strike" OR "warning")`; Q15 from `cienfuegos AND submarine AND (understanding OR 1962)`; Q16 from `cuba AND embargo AND (normaliz* OR normalization) AND (africa OR angola) AND (trade OR economic)`; Q17 from `("Mariel" OR boatlift OR refugees) AND ("security" …) AND castro`. **Q14 came from a vector neighbour, through no full-text query** (§VECTORS).
These are bm25-ranked purposive reads, not a sample: the quotations illustrate the measured shifts; they do not by themselves establish them.

## VECTORS
Artifacts: semantic-vectors-index.json, semantic-vectors-binary.bin, semantic-map.bin, semantic-map-index.json (bundle); shard folder's .generation. **Digest check** (`vec_check.py` → `vec_check_out.txt`): index, binary (offset 20), map (offset 20) and the shard folder's .generation all `89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101`; index `generated` 2026-10-15, `harvestGenerated` 2026-10-15T06:55:14; `retrieval.measuredRecallAt10` 0.9021. **Round trip**: 553 of 553 volumes decode to their `n`; 314,616 rows. **Random-pair baseline** (20,000 pairs, Random(1877)): mean 167.1, sd 14.8, 1st percentile 132, min 95 of 512. No Tier-2 shard was scored (none touched), so no shard digest needed checking beyond the folder's .generation. frus1898/ch83 (McKinley's message) has NO vector row (the index's frus1898 ids are all d-numbers), so it was not used as an anchor.
1. **Nearest neighbours of a document** (`vec_ops.py` → `vec_ops_out.txt`, `vec_ops.json`; full Hamming scan over the binary's sign block; baseline = random pairs above and each anchor's own 25th-neighbour distance):
   - frus1881/d405 (25th neighbour at 100): nearest frus1894app2/d394 at **4** (a reprint), then frus1894app2/d114 77, … **frus1870/d197 at 87** (Fish's 1870 report — the document of Q1, found independently by FTS), frus1874/d552 96, frus1878/d257 96.
   - frus1898/d490 (25th at 90): frus1898/d495 48, frus1874/d552 61, … frus1872p1/d431 73, **frus1902/d313 at 82** (the document of Q6).
   - frus1952-54v04/d343 (25th at 104): frus1955-57v06/d260 79 (1955 Holland–Waugh sugar memorandum), frus1952-54v04/d342 83, frus1948v09/d420 90, … frus1958-60v06/d328 97.
   - frus1961-63v10/d202 (25th at 77): frus1961-63v10/d182 55, d274 55, **frus1969-76ve10/d205 at 60** (NSSM 32, 1969), frus1961-63v10-12mSupp d725/d729 62, frus1958-60v06/d466 65.
2. **Semantic join** (neighbour lists joined to document_dates and document_cache flags, in `vec_ops.py`): every neighbour above is present in document_cache with is_front_matter=0 except frus1958-60v04/d308 (an editorial note, flag `[0, 1]`); cross-era neighbours are: d405 → 1870 and 1874–78 documents; d490 → 1872 and 1902; d343 → 1948 and 1955–60; d202 → 1969. The cross-decade neighbours chain the eras' arguments to each other (they are leads; read before used).
3. **Centroid similarity** (volume centroids, int8 dequantized, renormalized; `vec_ops_out.txt`): the 1870s–1900s Cuba-bearing annuals are mutually at 0.950–0.974; frus1874 vs frus1961-63v11 0.867; frus1933v05 vs frus1944v07 0.962; frus1958-60v06 vs frus1977-80v23 0.959. Caveat: an annual's centroid is the whole volume (all countries), not its Cuba chapter, so this measures volume style as much as Cuba.
4. **The map** (`vec_ops.py`; placements from semantic-map.bin, labels from semantic-map-index.json, 2026-10-15 layout, 140 clusters). Core set by band, top cluster, unclustered vs an era-matched baseline (all dated non-apparatus documents in the band):
   - 1861–1898: 891; cluster 72 "sanguily, inclosure, azcuy, inclose" 457; cluster 41 "sickle, hoar, mcculloch, barlow" 106; unclustered 271 of 891 vs 8,337 of 32,364.
   - 1899–1933: 2,206; cluster 52 "panaman, panama, loubet, lefevre" 485; cluster 39 "grau, machado, habana, mendieta" 310; cluster 43 "zaya, crowder, airway, guatemala" 296; unclustered 783 of 2,206 vs 20,352 of 74,033.
   - 1934–1958: 1,181; cluster 35 "cuban, habana, braden, cuba" 489; cluster 42 "castro, somoza, cuban, cuba" 206; unclustered 346 of 1,181 vs 38,685 of 139,702.
   - 1959–1980: 2,727; cluster 42 2,186; cluster 115 "edc, nato, nuclear, soviet" 50; unclustered 416 of 2,727 vs 15,775 of 54,420.
   Reading: Cuba's documents sit in a different cluster in each era — the projection does not hold "Cuba" as one subject across 1870–1980. Clusters explore; they do not measure.
5. **Near-duplicates** (`vec_dups.py` → `vec_dups.tsv`, all core-set pairs at Hamming ≤20, i.e. >9 sd below the random mean): 3 pairs — frus1881/d405 ↔ frus1894app2/d394 (4; the Blaine instruction reprinted in the 1894 Hawaii appendix), frus1969-76v12/d211 ↔ frus1969-76ve10/d225 (19; cross-volume reprint), frus1865p2/d33 ↔ frus1865p2/d647 (14). No count was adjusted for them except as flagged at M2. Recall@10 is 0.9021, so absence of further near-duplicates is not proven.
**Documents in the overview reached through a vector operation:** frus1969-76ve10/d205 (NSSM 32) — reached ONLY through the neighbour list of frus1961-63v10/d202, through no full-text query. frus1870/d197 and frus1902/d313 were reached by FTS first and re-surfaced as neighbours.

## 6. What FRUS cannot answer here (searches run)
- **After 1980**: `{header dateline body_text}: (cuba OR cuban OR havana OR habana)` with `date_iso >= '1981-01-21'` → 358 mentions across 13 frus1981-88 volumes (top frus1981-88v03 72, v01 64, v04 40); `{header}: (…)` same window → **0**. No 1981–1988 Cuba compilation is in the library; manifest latest coverage is 1991-11-20. Shelves: Reagan Library NSC files (no bundled record; not resolvable offline).
- **The Ten Years' War instruction of November 1875 (Fish's No. 266) was not found**: the only Cuba document dated November 1875 (`d.date_iso BETWEEN '1875-11-01' AND '1875-11-30' AND body_text LIKE '%Cuba%'`) is frus1876/d298, Fish to Cushing No. 265 of November 5, 1875 (on the *Virginius*/Burriel case). Absent by that name in this test only.
- **Domestic economic interests' own view** (planters, sugar refiners, chambers): FRUS prints them only through State Department correspondence; the bundled "Records Relating to Sugar" (lot 65D212) is the nearest shelf, 1955–1962, Restricted – Fully.

## TRACE TABLE (overview claim → memo line)
| overview item | memo source |
|---|---|
| 7,013 documents, 130 volumes, 1849–1980 | §1 inclusion result |
| 553 volumes in the library | §0 |
| 1870s order/intervention ~half vs ~one in seven | M1 (108 of 210; 44 of 300) |
| 1870s strategic/naval ~two in five vs one in seven | M1 (87 of 210; 42 of 300) |
| 1880s economy ~three in five vs ~one in four | M2 (86 of 138; 69 of 300) |
| 1910s property/claims ~one in four vs ~one in eight | M3 (221 of 975; 39 of 300) |
| 1940s economy over half vs about one in five | M4 (389 of 728; 56 of 300) |
| 1950s Cold War vocabulary below the corpus | M5 (168 of 449; 143 of 300) |
| 1960s Soviet/communist/missile ~two in three vs ~one in two | M6 (1,280 of 2,001; 155 of 300) |
| "security"/"national security" at baseline; "almost never" before 1930s | M7, M8 (1 of 2,206 core, 1899–1933) |
| 1910s property/claims "nearly twice" | M3 (221 of 975 vs 39 of 300) |
| any-mention set "roughly double" the core | §1 litshare M = 13,140 hits without habana, +759 habana-only, vs 7,013 core |
| about 340 footnoted decimal documents, 1913–1962 | §4 pointed-at first row (342 docs) |
| a few hundred mentions in thirteen Reagan-era volumes | §6 (358 across 13 volumes) |
| "prosperity" distinctive before 1959, baseline after | M9 |
| headings: ~two in three economic 1934–58; chronological after 1959 | M10 |
| Habana outnumbers Havana; ~760 documents only "Habana" | M11 (6,076 vs 4,623; 759) |
| archival series names, NAIDs, entries, access | §4 lot table |
| decimal file 837.00 / 837.51 / 837.61351 / 611.3731 | §4 gloss |
| nineteenth-century despatch series | §4 countrySeries |
| no Reagan-era Cuba compilation; 0 headed documents after Jan 1981 | §6 |
| Fish November 1875 instruction not found | §6 |
| Q1–Q17 | §5 table rows Q1–Q17 |
| NSSM 32 reached by vector neighbour | VECTORS 1, closing line |
| reprint of Blaine 1881 in 1894 appendix | VECTORS 5 |
| eras in separate map clusters | VECTORS 4 |
| checks: all quotations verified; all cited documents in the collection | §5 (verify_out.txt) and §7 |

## 7. Final checks
- Every overview quotation and every collection excerpt is one of Q1–Q17, verified 17 of 17 (`verify_out.txt`).
- Every document the overview cites (16) is a `document` entry in collection.fruscollection; checked by `check_collection.py` (output `check_collection_out.txt`).
- Thin-result flags: 1880s (138 documents, one negotiation-heavy volume), 1980s (89, all one volume), the prosper* baseline numerators (3–15).
