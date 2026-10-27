# Scope memo: U.S. thinking about Cuba, national security and prosperity since the 1870s

Operator memo for the run of 2026-10-27. Files are in this directory: `queries.log` (commands), `overview.md`, `collection.fruscollection`, and the scripts and outputs named below. Every number here is conditional on this library: a SQLite copy of the index taken 2026-10-25, holding **553 of 553 volumes**.

## M0. Coverage query, canary and read-only proof

First tool call, output exactly as required:

```
sqlite3 "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro" "SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;"
553|321749|1103|8481
```

Second tool call, the read-only proof, failed as required: `Error in 3rd command line argument: attempt to write a readonly database`.

Exclusions applied everywhere unless stated: `is_front_matter = 0 AND is_editorial_note = 0 AND volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')` (the second editions; `frus1977-80v09Ed2` kept). After these, `SELECT COUNT(*) FROM document_cache d WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN (...)` = **311,429** documents (M0.1). `summary_text` and `note_text` were never read or selected.

## M1. Scope: what I chose and how I found it

**Question.** How have U.S. policymakers' thinking about Cuba's impact on national security and prosperity changed since the 1870s?

**Two scopes, never mixed.**

- **Scope B (broad): documents that mention Cuba.** FTS predicate `frus_documents MATCH '(cuba OR cuban OR cubans OR havana OR habana)'`, joined to `document_cache` on `rowid` and to `document_dates`, with the exclusions above. **13,899 documents in 481 volumes** (M2.1, query Q-B). This is the only scope available before 1895, because the nineteenth-century volumes are arranged by correspondent and have no Cuba chapters.
- **Scope A (the editors' own Cuba chapters).** Built by `setA.py`, which walks `volume_structures.structure_json` and takes every document under a section whose title is Cuba (exact forms: `Cuba`, `Cuba:`, `CUBA`, `Cuba, 1961–1962`, `The American Republics > Cuba`, `Cuban Missile Crisis and Aftermath`), plus the `Cuba` subsections of four multi-country volumes (`frus1964-68v32`, `frus1977-80v23`, `frus1969-76ve10`, `frus1969-76ve11p1`). **4,897 documents in 62 volumes, 1900–1980** (after the exclusions; `setA.tsv` holds the pairs). Section headings that merely contain the word Cuba inside another country's chapter (for example 1902's thirty circulars on protecting Cuban interests) were not included. The 1890s Cuba material sits in Spain chapters (`cuba_sections.tsv` lists 321 headings that name Cuba/Havana/Guantánamo), so Scope A is a lower bound and starts in 1900.

**How I found it.** (1) Read the chapter headings first (`sections.py` → `cuba_sections.tsv`): the editors' formula in each era is "Cuba" chapters with sub-headings (sugar crops, financial assistance, naval station at Guantánamo, political unrest, Operation Mongoose). (2) FTS rates by decade (M2.1). (3) FTS searches by era for the security and prosperity vocabulary, reading the top hits (`find.py`, M1.1). (4) Read the documents named in M4/M5.

**Inclusion rule for the collection:** every document the argument rests on, taken from Scope A chapters where they exist and from text searches where they do not; nothing else. 23 documents.

**Span.** 1874–1981 for the findings; the corpus holds Cuba material to January 1989 (two documents dated 1989-01, see M2.1).

**Periodised on** `document_dates.date_iso` as stored (I did not re-derive dates from the TEI), not on the volume's series year.

### M1.1 Searches run (all through `find.py`: `frus_documents MATCH ?`, `ORDER BY bm25(frus_documents)`, same exclusions, `document_dates.date_iso >= lo AND < hi`)

The exact MATCH strings and ranges are in `queries.log`. Summary: annexation/key-to-the-Gulf 1865–1895; sugar/tariff/reciprocity 1875–1898; naval stations/coaling/Platt/independence 1898–1912; Guantánamo naval/coaling 1898–1925; American investments/capital 1910–1935; intervention/Platt 1925–1936; bases/air bases 1939–1950; Soviet/subversion/threat 1981–1989; stability/strategic/sugar 1950–1959; sugar quota/Castro 1959–1961; Soviet burden/economy 1964–1981; normalization/embargo 1974–1981; missiles/strategic balance 14–30 Oct 1962; sugar/war/purchase 1941–1945; machado/property 1933–34. One query (`$` inside an FTS expression) raised an FTS5 syntax error and was rerun without it (the failed call returned nothing and is logged).

## M2. Measurements (audit form)

Counting surface for everything in M2: **the index** (`frus_documents`, porter-stemmed, unicode61), i.e. document counts under stem matching, **not** raw TEI, tag-stripped XML or word-bounded counts. I did not open the TEI. Where a literal share is given it is a Python `re` (case-insensitive) pass over `header || dateline || source_note || body_text` of the same documents, whitespace-collapsed. **No count here separates a footnote from a body** (body_text contains editorial footnotes); I say so rather than imply a density.

### M2.1 Documents mentioning Cuba, by decade (Scope B)

Script `themes2.py` (group ALL), predicate: `frus_documents MATCH '(cuba OR cuban OR cubans OR havana OR habana)'` joined `document_cache d ON d.rowid=f.rowid` and `document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id`, `GROUP BY substr(dd.date_iso,1,3)||'0s', d.volume_id`, with the exclusions. Denominator: `SELECT substr(dd.date_iso,1,3)||'0s', count(*) FROM document_cache d JOIN document_dates dd ... WHERE <exclusions> GROUP BY 1`.

| decade | dated docs (M) | Cuba docs (N) | per 1,000 | top volume share of N |
|---|---|---|---|---|
| 1860s | 11,268 | 448 | 39.8 | frus1872p2v1 0.19 |
| 1870s | 5,821 | 400 | 68.7 | frus1874 0.29 |
| 1880s | 6,484 | 306 | 47.2 | frus1885 0.20 |
| 1890s | 9,845 | 783 | 79.5 | frus1898 0.40 |
| 1900s | 10,261 | 408 | 39.8 | frus1902 0.24 |
| 1910s | 30,842 | 1,033 | 33.5 | frus1917 0.20 |
| 1920s | 20,374 | 767 | 37.6 | frus1921v01 0.18 |
| 1930s | 40,073 | 1,192 | 29.7 | frus1933v05 0.29 |
| 1940s | 75,872 | 1,725 | 22.7 | frus1940v05 0.12 |
| 1950s | 42,801 | 1,032 | 24.1 | frus1958-60v06 0.34 |
| 1960s | 27,654 | 3,173 | 114.7 | frus1961-63v10-12mSupp 0.18 |
| 1970s | 22,258 | 1,931 | 86.8 | frus1969-76ve11p1 0.09 |
| 1980s | 6,038 | 643 | 106.5 | frus1981-88v03 0.11 |

Sum over the table = 13,841 dated; total (undated and pre-1860 decades included) **13,899 in 481 volumes** (query Q-B: `SELECT COUNT(*) docs, COUNT(DISTINCT d.volume_id) vols FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '(cuba OR cuban OR cubans OR havana OR habana)' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')` → 13899|481). Overview's "one in fifteen / thirteen / forty-five / nine" = 1000/68.7, 1000/79.5, 1000/22.7, 1000/114.7.

**Thinness flag:** the 1870s denominator (5,821) is small, and 0.29 of its numerator is one volume (`frus1874`, the Virginius year); the 1890s 0.40 is `frus1898` alone. A decade rate there can be one episode.

**Referent test** (`central.py`): of the FTS hits, literal `\bCub(a|an|ans)\b|\bHa[bv]ana\b` ≥ 1 in 13,830 of 13,841 dated hits (share 0.999; the stems are the words), but ≥ 5 mentions in only 5,249 of 13,841 (0.38): 1870s 146 of 400, 1960s 1,551 of 3,173, 1980s 164 of 643. So about three in five hits mention Cuba fewer than five times (8,592 of 13,841 = 0.62). Havana-as-conference-site (1928, 1940) is in these counts; Scope A is the cleaner measure.

**After 1988:** `... WHERE ... dd.date_iso>='1989'` → 2 documents (`frus1981-88v01/d335` 1989-01-11; `frus1981-88v06/d183` 1989-01-08).

### M2.2 The editors' Cuba chapters (Scope A), by decade

`setA.py` output: 1900s 209; 1910s 741; 1920s 399; 1930s 620; 1940s 665; 1950s 449; 1960s 1,578; 1970s 192; 1980s 44 (the 1980s documents are dated 1980, the end of `frus1977-80v23`); total **4,897** in **62** volumes. Source of the volume count: `len({v for v,d,dt,t in setA})` in `arch4.py` (62).

### M2.3 Theme groups, by decade, and corpus baselines (stem groups; literal shares)

`themes2.py` (numerators, within Scope B: `MATCH '(cuba OR ...) AND (<group>)'`) and `baseline2.py` (the same groups, no Cuba condition, over all dated non-apparatus documents of the decade). The first version of this pass (`themes.py`) is **discarded**: its "claims" group contained `nationalization`, whose stem `nation` matches nearly every document (98% in the 1970s), and its `communism` and `base` terms collide with `communication` and `based` under the porter stemmer. `themes2.py` replaced it. Group definitions:

- sugar_tariff_reciprocity: `(sugar OR tariff OR reciprocity)`
- naval_base_terms: `(guantanamo OR coaling OR marines OR "naval station" OR "naval base" OR "air base" OR "air bases")`
- soviet_communist_missile_subversion: `(soviet OR communist OR missile OR missiles OR subversion)`
- intervention_protectorate_platt: `(intervention OR intervene OR protectorate OR "platt amendment")`
- claims_expropriation: `(claims OR expropriation OR confiscation)`; yellow_fever: `"yellow fever"`.

Share of Cuba docs (N of M, M = Cuba docs of the decade in M2.1) from `themes2.py` output:

| decade | sugar etc. | naval/base | Soviet etc. | interv. etc. | yellow fever | claims |
|---|---|---|---|---|---|---|
| 1860s | 37 of 448 | 59 | 5 | 49 | 8 | 100 |
| 1870s | 70 of 400 | 82 | 4 | 59 | 3 | 156 |
| 1880s | 95 of 306 | 29 | 1 | 24 | 1 | 88 |
| 1890s | 75 of 783 | 50 | 3 | 65 | 6 | 131 |
| 1900s | 54 of 408 | 46 | 0 | 61 | 21 | 79 |
| 1910s | 152 of 1,033 | 167 | 6 | 123 | 1 | 164 |
| 1920s | 180 of 767 | 54 | 12 | 86 | 2 | 131 |
| 1930s | 285 of 1,192 | 48 | 80 | 114 | 0 | 106 |
| 1940s | 467 of 1,725 | 108 | 213 | 107 | 0 | 203 |
| 1950s | 263 of 1,032 | 132 | 452 | 203 | 0 | 187 |
| 1960s | 468 of 3,173 | 359 | 2,305 | 466 | 0 | 400 |
| 1970s | 245 of 1,931 | 160 | 1,411 | 488 | 0 | 483 |
| 1980s | 84 of 643 | 56 | 522 | 156 | 0 | 140 |

Corpus baselines (`baseline2.py`, N of M over all dated documents of the decade), Soviet etc.: 1930s 3,437 of 40,073 (8.6%), 1940s 23,943 of 75,872 (31.6%), 1950s 19,109 of 42,801 (44.6%), 1960s 13,849 of 27,654 (50.1%), 1970s 10,620 of 22,258 (47.7%), 1980s 3,720 of 6,038 (61.6%). Cuba docs on the same group: 1960s 2,305 of 3,173 (72.6%), 1970s 1,411 of 1,931 (73.1%), 1980s 522 of 643 (81.2%). **False-friend reading:** the Soviet group is elevated in Cuba documents but only by about 20 points over a high baseline; the overview says "real but moderate". Sugar group: Cuba 1940s 467 of 1,725 (27.1%) against baseline 2,819 of 75,872 (3.7%), 1930s 285 of 1,192 (23.9%) against 2,977 of 40,073 (7.4%): a Cuba-specific theme. Naval/base: Cuba 1910s 167 of 1,033 (16.2%) against 1,675 of 30,842 (5.4%). Intervention: Cuba 1900s 61 of 408 (15.0%) against 415 of 10,261 (4.0%).

**Literal share (obligation (a), census, not sample)** — `literal2.py`, Cuba hits only, regex over the concatenated text, STRICT vs TOLERANT:

| group | FTS hits (M) | STRICT | TOLERANT |
|---|---|---|---|
| sugar_tariff_reciprocity | 2,479 | 2,020 of 2,479 = 0.815 | 2,394 of 2,479 = 0.966 |
| naval_base_terms | 1,357 | 874 of 1,357 = 0.644 | 1,153 of 1,357 = 0.850 |
| soviet_communist_missile_subversion | 5,017 | 4,947 of 5,017 = 0.986 | 5,017 of 5,017 = 1.000 |
| intervention_protectorate_platt | 2,007 | 1,901 of 2,007 = 0.947 | 1,987 of 2,007 = 0.990 |

STRICT regexes: `\b(sugars?|tariffs?|reciprocity)\b`; `guant[aá]namo|coaling|marines|naval stations?|naval bases?|air bases?`; `soviets?|communists?|missiles?|subversion`; `intervention|intervene|protectorate|platt amendment`. TOLERANT: inflections and any run of `[\s\-,().]` between words. All four are ≥ 0.80 tolerant (naval_base_terms is the lowest at 0.850, so its counts are published only in this memo, not in the overview). A tolerant share near 1.000 tests the stemmer, not the referent; the referent is tested in M2.1 (centrality) and by reading.

### M2.4 The two terms the question supplied: 'national security' and 'prosperity' (false-friend test)

`literal.py` (census): `MATCH '(cuba OR cuban OR cubans OR havana OR habana) AND "national security"'` → **2,643** hits; STRICT regex `national security` 2,626 of 2,643 (0.994); TOLERANT `\bnation(?:al|s)?['’]?s?['’]?[\s\-,().]+secur(?:ity|ities)\b` 2,642 of 2,643 (1.000). By decade (hits / strict / tolerant): 1880s 1/1/1; 1910s 4/4/4; 1920s 1/1/1; 1930s 3/2/2; 1940s 19/18/19; 1950s 90/87/90; 1960s 1,081/1,078/1,081; 1970s 1,122/1,118/1,122; 1980s 322/317/322. Pre-1940 hits: **9 returned, 8 contain the words** (`nsec.py` prints each context): `frus1887/d491` (a legal code), `frus1918/d343` and `frus1918/d1` (US bond and agriculture acts), `frus1919Parisv03/d8` (China at the peace conference), `frus1919Parisv07/d42` (Bolshevism), `frus1929v01/d42` (arms reduction), `frus1937v01/d741` (armaments), `frus1939v05/d493` (Colombian coast guard; no Cuba context), and `frus1938v02/d156` (returned by the stem, no literal). **None is about Cuba's bearing on U.S. security.**

Baseline (`baseline.py`), `MATCH '"national security"'` over all dated non-apparatus docs: 1910s 43 of 30,842; 1920s 34 of 20,374; 1930s 68 of 40,073; 1940s 1,066 of 75,872 (14.0 per 1,000); 1950s 3,151 of 42,801 (73.6); 1960s 10,169 of 27,654 (367.7); 1970s 12,176 of 22,258 (547.0); 1980s 2,621 of 6,038 (434.1). Cuba docs: 1960s 1,081 of 3,173 (34.1%) vs corpus 10,169 of 27,654 (36.8%); 1970s 1,122 of 1,931 (58.1%) vs 12,176 of 22,258 (54.7%); 1980s 322 of 643 (50.1%) vs 2,621 of 6,038 (43.4%); 1950s 90 of 1,032 (8.7%) vs 3,151 of 42,801 (7.4%). **Verdict:** the term matches the baseline, so it measures the decade's vocabulary, not Cuba. I stopped using it as a Cuba finding and say so in the overview.

`prosperity` (FTS stem `prosper`: also prosperous, prosper): Cuba hits 449; STRICT `prosperity` 318 of 449 (0.708), TOLERANT `\bprosper(?:ity|ous|ed|ing|s)?\b` 448 of 449 (0.998). Below 0.80 strict, so only the tolerant form is usable. Baseline per 1,000: 1860s 57.9, 1870s 81.3, 1960s 14.7, 1980s 24.7; Cuba docs 1860s 31 of 448 (6.9%) vs corpus 5.8%, 1960s 71 of 3,173 (2.2%) vs 1.5%: also the baseline. **Not used as a finding.**

**Controls, same pass** (`baseline.py`): positive `MATCH '"department of state"'` is non-zero in every decade (1860s 4,269 of 11,268 … 1980s 3,423 of 6,038); negative `MATCH 'ZZZ_IMPOSSIBLE_ZZZ'` = 0 in every decade. These are decade-level controls, not volume-level; the positive control was not tested volume by volume.

### M2.5 Vocabulary inside the editors' Cuba chapters (Scope A), literal census

`setA_vocab.py`: per Scope A document, case-insensitive regex over `header || dateline || source_note || body_text`, whitespace-collapsed (N of M, M = Scope A documents of the decade: 1900s 209, 1910s 741, 1920s 399, 1930s 620, 1940s 665, 1950s 449, 1960s 1,578, 1970s 192, 1980s 44):

| phrase (regex) | 1900s | 1910s | 1920s | 1930s | 1940s | 1950s | 1960s | 1970s | 1980s |
|---|---|---|---|---|---|---|---|---|---|
| `national[\s\-]+security` | 0 | 1 | 0 | 0 | 2 | 23 | 483 | 127 | 39 |
| `security of the (United States\|U.S.)\|(American\|U.S.) security` | 0 | 0 | 0 | 0 | 0 | 6 | 33 | 3 | 2 |
| `\bdefen[sc]e\b` | 6 | 19 | 4 | 5 | 119 | 81 | 532 | 52 | 9 |
| `\bsugars?\b` | 15 | 87 | 59 | 72 | 275 | 127 | 183 | 19 | 0 |
| `\binvestments?\b\|American capital` | 1 | 2 | 7 | 3 | 22 | 42 | 48 | 7 | 1 |
| `\bindependence\b` | 32 | 30 | 13 | 15 | 8 | 10 | 51 | 17 | 0 |
| `\binterven(tion\|e\|ed\|ing)\b` | 33 | 56 | 32 | 70 | 17 | 83 | 207 | 35 | 3 |
| `\bcommunists?\b\|\bsoviets?\b\|\bmissiles?\b` | 0 | 0 | 0 | 29 | 19 | 154 | 1,013 | 103 | 13 |

The one 1910s `national security` document is `frus1918/d343` (1917-09-20, a bond act). Overview words: "about one in twenty" (1950s: 23 of 449), "one in three" (1960s: 483 of 1,578), "two in three" (1970s: 127 of 192), "nearly nine in ten" (1980s: 39 of 44); sugar "about two in five" (1940s: 275 of 665), "about one in ten" (1960s 183 of 1,578; 1970s 19 of 192); communist etc. "one in twenty" (1930s 29 of 620), "one in three" (1950s 154 of 449), "nearly two in three" (1960s 1,013 of 1,578).

Caveat: these are the editors' chapters, whose weight is itself a 20th-century editorial choice; the 1900s start is where the chapters start.

## M3. Archival scope (channels never summed)

### M3.1 Channel CAME-FROM (where printed documents came from): `document_sources`

`arch1.py`: Scope A joined to `document_sources` on both keys: **4,707 of 4,897** Scope A documents have a source row. `citation_era`: decimal 3,006; structured 1,199; lot_file 288; named_series 83; unrecognized 48; cfpf 39; subject_numeric 33; published 11 (`SELECT s.citation_era, count(*) FROM document_sources s JOIN setA a ON a.volume_id=s.volume_id AND a.document_id=s.document_id GROUP BY 1`). 3,006 of 4,707 = 0.639 ("about two in three"). `citation_era` is a citation FORM, not a date. Top by `GROUP BY repository, record_group, lot_file_norm, series_name` (documents): Central Intelligence Agency 295 (58 of them "Job 80-B01285A", the DCI McCone files); Kennedy Library "National Security Files" 233 and "NSF" 112; Carter Library "National Security Affairs" 85; Eisenhower Library "Whitman File" 65; Johnson Library "National Security File" 47 (+6 "NSF"); National Archives RG 330 "OASD (C) A Files: FRC 71 A 2896" 47; Nixon Presidential Materials "NSC Files" 47; RG 59 Lot 65 D 438 46; Lot 74 D 272 46; Lot 66 D 501 21; Lot 62 D 24 15; Lot 62 D 418 15; Lot 70 D 149 14 (not resolved in `central-files-index.json`: 0 rows; not in `lot-claimants-index.json`; not in `curated-lot-resolutions.json`).

Decimal classes (`arch2.py`, within `citation_era='decimal'`): 1910s 837.00 ×237; 1920s 837.51 ×116, 837.00 ×97; 1930s 837.00 ×403; 1940s 837.61351 ×197; 1950s 737.00 ×179; 1960s 737.00 ×85. Glossing per `decimal-class-labels.json`: country 37 = Cuba in all three schedules; class 8 = Internal Affairs of States (1910–1949); class 7 = Internal Political and National Defense Affairs (1950–1959, 1960–1963); subject 00 in class 8 = "Political affairs" (1910–1949 schedule). I glossed only 837.00 (1910–1949) and 737.00 (1950–1963) and I do **not** gloss the 1960s keys dated after 1963, where the file has no gloss. No NAID for the central decimal file is in the bundle (the `lotFiles` rows `60D171`/`60D648` titled "Decimal Files" are other lots).

### M3.2 Resolution of lots (`arch3.py`: `central-files-index.json` `lotFiles` by `lotNumber`; `series-facts-index.json` `byNaId` decoded through `legend`/`into`)

| lot | title (bundled) | RG | entry | NAID | dates | access | extent | creator |
|---|---|---|---|---|---|---|---|---|
| 65D438 | Records Relating to the Cuban Missile Crisis | 59 | A1 3053 | 27022950 | 1962–1963 | Restricted – Partly (FOIA b1) | 6 ft 2 in | State Executive Secretariat |
| 74D272 | Records of Under Secretary of State George W. Ball | 59 | A1 5175 | 614703 | 1961–1966 | Unrestricted | 16 ft 3 in | Office of the Under Secretary |
| 66D501 | Files Pertaining to Operation Mongoose | 59 | UD-UP 293-B | 648748 | 1963–1965 | Unrestricted | 2 ft 8 in | ARA, Office of the Coordinator of Cuban Affairs |
| 62D24 | Subject Files | 59 | A1 3148 | 2363836 | 1958–1961 | Restricted – Partly | 4 ft 10 in | ARA, Office of the Special Assistant on Communism |
| 62D418 | Subject Files | 59 | A1 3147 | 2068466 | 1959–1962 | Restricted – Partly | 1 ft 9 in | Office of the Assistant Secretary for Inter-American Affairs |
| 66D95 | Records Relating to National Security Council Policy Papers | 59 | A1 1586E | 2839192 | 1947–1979 | Restricted – Partly | 26 ft 3 in | State Executive Secretariat |
| 66D95 (second claimant) | Subject Files | 59 | – | 2839193 | 1947–1965 | – | – | – |
| 66D204 | Presidential and Secretary of State Correspondence with Foreign Heads of State | 59 | A1 1590 | 2538452 | 1953–1964 | Restricted – Possibly | 9 ft 8 in | State Executive Secretariat |
| 73D191 | Records Relating to Cuba | 59 | A1-5758 | 1040618 | 1957–1975 | Restricted – Partly | 27 ft 8 in | ARA, Coordinator of Cuban Affairs |
| 65D212 | Records Relating to Sugar | 59 | UD-UP 215 | 27022874 | 1955–1962 | Restricted – Fully | 3 ft 1 in | Bureau of Economic Affairs, Office of International Resources |

`lot-claimants-index.json` has an entry only for 66D95 among the lots above (two claimants); `matchType` for every row is `control` (the control number is NARA's assertion). Presidential libraries from `presidential-library-catalog.json`: Kennedy Library, "Papers of John F. Kennedy: Presidential Papers: National Security Files" (identifier JFK-4, NAID 1164; Country Files series NAID 193236, 1961–1963); Johnson Library "National Security Files" (LBJ-NSF, NAID 567979; Latin America Country Files NAID 567985, 1963–1969); Carter Library "Records of the Office of the National Security Advisor" (JC-NSA, NAID 560131; Brzezinski's Country Files NAID 560151, 1977–1981). Access to library collections is not in `series-facts-index.json`; I state none. RG 330 FRC 71 A 2896: `accession-series-index.json` has no `330/71A2896` key; unresolved. CIA: no shelf in the bundle. **NARA's creator attribution is a decoy surface** (56% precision on one route); for each lot above I read the creator heading against the title and the figures, and it is plausible, but I did not open the series.

### M3.3 Channel POINTED-AT (cited in footnotes, not printed): `external_citations`

`arch5.py`: Scope A joined to `external_citations`: **711 citations** (anchor `centralFileClass` 395, `presidentialLibrary` 189, `lotFile` 127) in **501 of 4,897** documents, from 28 volumes. Top lots (`GROUP BY lot_file_norm`: citations / documents): 66D95 25/22; 65D438 15/13; 62D24 10/8; 66D204 7/7; 74D272 7/6; 62D418 5/5; 64D199 5/3; 73D191 5/4; 65D212 4/3. Presidential-library anchors: Kennedy Library National Security Files 67 (58 docs); Carter Library National Security Affairs 40 (27); Johnson Library National Security File 22 (16). Central-file classes cited: 737.00 127; 611.37 35; 837.61351 29; 737.56361 22. The channel has no row before 1910-12-06, stores the citation fragment, and holds lot, library and decimal anchors only; the Cuba-chapter volumes before 1911 therefore contribute nothing here.

**Pre-1910 shelf.** `central-files-index.json` `countrySeries` (RG 59 microfilm): Diplomatic Despatches (series NAID 603720): "Despatches from U.S. Ministers to Spain, 1792–1906" (file unit NAID 177380726; 134 rolls) and "… to Cuba, 1902–1906" (177380758; 18 rolls); Consular Despatches (302031): "Despatches from United States Consuls in Havana, Cuba, 1783–1906" (196006797; 133 rolls), also Santiago de Cuba (17 rolls), Matanzas (17), Cienfuegos (8); Notes from Foreign Missions (594363): "Notes from the Cuban Legation in the United States …, 1844–1906" (183303950; 2 rolls). `series-facts-index.json` has no row for these; access status therefore not stated. The offline stack barely reaches before 1940 (11 of 695 bundled series); this is a shelf pointer, not a count.

## M4. Quotations and the SELECT that retrieved each

Retrieval SELECT, run for each pair by `quotes.py` (and by `get.py` / `capture.py` for the reading): 
`SELECT body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?`.
Verification: Python `quote in body_text` (exact) for all **35 of 35** (`quotes_verified.json`); Q04 first failed on one comma and was corrected to the source's punctuation before the file was built. The collection's excerpts are these strings; `build_collection.py` re-asserts each against `body_text`. `check_overview.py` checks every double-quoted span in `overview.md` against the retrieved bodies (30 spans, 0 unmatched).

| id | volume/document | date | text (verbatim) |
|---|---|---|---|
| Q01 | frus1874/d552 | 1874-02-06 | Cuba is the largest insular possession still retained by any European power in America. It is almost contiguous to the United States. |
| Q02 | frus1874/d552 | 1874-02-06 | In fine, Cuba, like the former continental colonies of Spain in America, ought to belong to the great family of American republics, … |
| Q03 | frus1874/d552 | 1874-02-06 | In short, the state of Cuba is the one great cause of perpetual solicitude in the foreign relations of the United States. |
| Q04 | frus1881/d405 | 1881-12-01 | That rich island, the key to the Gulf of Mexico, and the field for our most extended trade in the Western Hemisphere is, though in the hands of Spain, a part of the American commercial system. |
| Q05 | frus1886/d414 | 1886-10-22 | which buys about 95 per cent, of the sugar exported from Cuba |
| Q06 | frus1898/d498 | 1897-10-05 | the sugar plantations of Cuba are as necessary to the food supply of the United States as are the cotton fields of India … and to other countries |
| Q07 | frus1898/d498 | 1897-10-05 | the United States does not seek to annex Cuba or to establish a protectorate over Cuba |
| Q08 | frus1898/ch83 | 1898-04-12 | The present condition of affairs in Cuba is a constant menace to our peace, and entails upon this Government an enormous expense. |
| Q09 | frus1898/ch83 | 1898-04-12 | The right to intervene may be justified by the very serious injury to the commerce, trade, and business of our people, and by the wanton destruction of property and devastation of the island. |
| Q10 | frus1904/d207 | 1904-07-02 | That to enable the United States to maintain the independence of Cuba, … for coaling or naval stations … |
| Q11 | frus1904/d207 | 1904-07-02 | That the government of Cuba consents that the United States may exercise the right to intervene for the preservation of Cuban independence, … |
| Q12 | frus1929v02/d924 | 1929-01-10 | there is invested in Cuba at the present time, nearly 1,500 million dollars of American capital |
| Q13 | frus1930v02/d747 | 1930-10-02 | A great many people seem to think that the Platt Amendment gives us a protectorate over the internal affairs of Cuba |
| Q14 | frus1933v05/d299 | 1933-08-08 | the purpose of my mission here is to avoid the existence of a situation which would give rise to intervention by the United States |
| Q15 | frus1934v05/d127 | 1934-07-26 | eliminating the permissive right of intervention by this Government, has removed a chronic source of friction between our two countries, and has placed our political relations on a basis of true and friendly equality. |
| Q16 | frus1934v05/d127 | 1934-07-26 | The magnitude of this concession is a further indication of the desire of this Government to assist the Cuban people in regaining an adequate and satisfactory standard of living. |
| Q17 | frus1952-54v04/d342 | 1954-06-04 | It would seem to ignore the fact that Cuba has been a reliable expansible source of sugar in both war and peace, a strategic concept which should not be jeopardized. |
| Q18 | frus1941v07/d119 | 1941-07-14 | The principle of leased areas over which the United States forces exercise unquestioned jurisdiction could not be applied to other countries of the Hemisphere |
| Q19 | frus1944v07/d878 | 1944-12-20 | Plans of the President and of the Joint Chiefs of Staff call for a defense facility in western Cuba under the exclusive jurisdiction of the United States Government, … |
| Q20 | frus1945v09/d741 | 1945-01-12 | President Grau, as a matter of sovereignty, is adamant on the proposition that there shall not be a lease of the bases to anyone. |
| Q21 | frus1958-60v06/d70 | 1958-06-27 | If the security of the nation is destroyed or an avenue is opened up for leftist exploitation, this would certainly weaken the nation’s stability and affect hemispheric defense. |
| Q22 | frus1958-60v05/d112 | 1959-03-15 | Fidel Castro, the instigator of the present unsettled situation, is advocating a neutralistic bloc in Latin America, while actually supporting Communist-dominated revolutionary groups conspiring against the Dominican Republic and Nicaragua. |
| Q23 | frus1958-60v06/d499 | 1960-04-06 | it follows that every possible means should be undertaken promptly to weaken the economic life of Cuba. |
| Q24 | frus1958-60v06/d499 | 1960-04-06 | The principal item in our economic quiver would be flexible authority in the sugar legislation. |
| Q25 | frus1961-63v11/d21 | 1962-10-16 | What is the strategic impact on the position of the United States of MRBMs in Cuba? How gravely does this change the strategic balance? McNamara: Mac, I asked the Chiefs that this afternoon, in effect. And they said, substantially. My own personal view is, not at all. |
| Q26 | frus1961-63v11/d34 | 1962-10-20 | However, the existence of strategic missiles in Cuba had an entirely different impact throughout Latin America. |
| Q27 | frus1961-63v11/d34 | 1962-10-20 | In his view the existence of fifty planes in Cuba did not affect the balance of power, but the missiles already in Cuba were an entirely different matter. |
| Q28 | frus1961-63v10-12mSupp/d729 | 1963-12-15 | The bare minimum objective of our policy is a Cuba which poses no threat to its neighbors and which is not a Soviet satellite. |
| Q29 | frus1961-63v10-12mSupp/d729 | 1963-12-15 | intensifying Cuba’s already-serious economic difficulties; increasing the cost and unpleasantness to the Soviets of maintaining Cuba; … |
| Q30 | frus1969-76ve10/d205 | 1969-07-02 | Cuba has been a double-barreled problem for the U.S.: —as a base for Soviet military power, and —as an exporter of revolutionary doctrine and violence to Latin America. |
| Q31 | frus1977-80v23/d21 | 1977-08-12 | The political significance of both sides of the trade issue far outweighs economic effects. |
| Q32 | frus1977-80v23/d21 | 1977-08-12 | Even on sugar, our leverage in economic terms is quite modest. |
| Q33 | frus1981-88v03/d5 | 1981-01-26 | The intent of the 1962 Understanding was to prevent Cuba from becoming a threat to the security of the US—and to countries friendly to us in the Hemisphere. |
| Q34 | frus1898/d498 | 1897-10-05 | our native cane-sugar crop, raised mostly in Louisiana and Texas, does not furnish more than one-tenth of the sugar we consume |
| Q35 | frus1977-80v23/d21 | 1977-08-12 | U.S. claims now total about $2 billion, on which a settlement of at least $600 million (the usual 30%) might well be possible. |

The full strings (not the ellipses used in this table for width) are in `quotes_verified.json` and the collection.

Attribution notes the overview relies on: Q12 is the Cuban ambassador's assertion; Q25 is a transcript with an unidentified inline speaker structure (the McNamara label is in the text); Q26/Q27 are the minutes-taker's report of the President's view, not a transcript; Q29 and Q28 are Bundy's memorandum to President Johnson (document header). Q08/Q09 are the President's message; the index dates `frus1898/ch83` 1898-04-12 and gives it no author or dateline; the overview calls it "the President's message on Cuba, April 1898".

## M5. Reading accounting

- **Retrieved whole (captured length = `length(body_text)`, in characters):** 23 of 23 collection documents (`capture.py` → `capture_report.tsv`; bodies in `raw/`; full text with header in `docs/`).
- **Actually read (portions displayed in the session):** parts of each of the 23; in addition portions of these documents that were read and **not used**: `frus1949v02/d422` (Panama defence sites, a vector neighbour), `frus1955-57v06/d195`, `frus1977-80v23/d6`, `d7`, `frus1969-76v12/d228`, `frus1981-88v03/d127`, `frus1917/d516`, `d471`, `frus1961-63v11/d18`, `d38`. Several hundred further search-result snippets appeared in `find.py` output; none was quoted.
- **Quoted:** 35 passages from 23 documents (M4).
- Documents retrieved whole and relied on for reading: `frus1874/d552` (15,209 characters), `frus1898/d498` (10,535), `frus1961-63v11/d21` (100,069), `frus1961-63v10-12mSupp/d729` (33,660) are the largest; I read only the passages quoted from d21 (about 1,000 characters of 100,069) and a few thousand characters of d729. The overview's claims about those two documents rest on those passages only.
- **Duplicates:** `frus1881/d405` and `frus1894app2/d394` are the same Blaine despatch (Hamming 4 bits); only the 1881 copy is cited (M6.5).

## M6. VECTORS

Files touched: `/Applications/FRUS Explorer.app/Contents/Resources/semantic-vectors-index.json`, `semantic-vectors-binary.bin`, `semantic-map.bin`, `semantic-map-index.json`; `/Users/jbotts/frus-analysis/c3/SemanticVectors/*.vec` (headers only; **I did not rerank with Tier-2 shards**). Code: `vec.py` (loader), `vec1.py`–`vec6.py`; outputs in `vec_neighbours.txt` and the session log.

### M6.0 Checks before scoring (Appendix A addendum)

- **Digest.** Index `provenanceDigest`, the corpus binary's header (offset 20), the map's header and every one of the 553 shard headers (offset 16) and the shard folder's `.generation` file all read `89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101` (embeddinggemma-2-Q8_0; 0 shards mismatched). No generation mixing. `generated` 2026-10-15; `harvestGenerated` 2026-10-15T06:55:14.
- **Identity.** The §A.3 decode ran for all volumes: decoded length = `n` for **553 of 553**, 314,616 rows mapped. Ids come only from the index segments.
- **Tier-1 flag.** All 553 volumes are in `document_cache`, so no neighbour is outside the SQLite library; none needed a canonical-URL-only flag. One collection document, `frus1898/ch83`, has no row in the vector index (22 of 23 collection documents are in it).
- **Baselines at this digest** (`vec2.py`): 20,000 random pairs (`random.Random(1877)`): mean 167.1, sd 14.8, 1st percentile 132, minimum 95 of 512. k-th-neighbour distribution over 30 random documents (`random.Random(2026)`): median first neighbour 80; median 25th neighbour 104 (quartiles 97 and 109). A neighbour at or below 80 is in the near tail; one near 105 is no closer than a median 25th neighbour.

### M6.1 Nearest neighbours of a document (§A.5): anchors, file, baseline, result

`vec3.py`: Hamming over the sign block of `semantic-vectors-binary.bin`, k = 15, joined to `document_cache`/`document_dates` (date, header, `instr(lower(body_text),'cuba')>0`, `is_front_matter`, `is_editorial_note`). Full lists in `vec_neighbours.txt`.

| anchor | nearest (Hamming) | read against |
|---|---|---|
| frus1874/d552 (Fish 1874) | frus1898/d490 61; frus1898/d503 68; frus1898/d531 71; frus1898/d495 73; … frus1866p1/d422 81; frus1870/d197 83 | nearest at 61 is below the 80 median first neighbour; the list is Cuba-war despatches across 1866–1898 and 1902 |
| frus1898/d498 (Woodford) | frus1898/d497 32; frus1898/d492 50; frus1898/d544 74; frus1898/d557 75; frus1897/d581 79; frus1874/d552 80 | 32 and 50 are far below chance (mean 167) and the first-neighbour median; the 1874 Fish note reappears at 80 |
| frus1934v05/d127 (Hull 1934) | frus1941v07/d169 68; frus1934v05/d114 75; frus1941v07/d171 78 … | trade-agreement instructions cluster by topic, not period |
| frus1944v07/d878 (JCS bases) | frus1944v07/d874 83; d876 87; d875 89; frus1945v09/d741 99 … frus1949v02/d422 109 | the 1949 neighbour is about Panama defence sites, not Cuba (`cuba_in_text`=0); read and **discarded**: at 109 it sits at the quartile of ordinary 25th neighbours |
| frus1958-60v06/d499 (Mallory) | frus1958-60v06/d594 101; d555 103; d579 103; d527 104; **frus1958-60v05/d112 106**; … | all between 101 and 109, i.e. around the median 25th neighbour (104): weak leads, justified by reading |
| frus1969-76ve10/d205 (NSSM 32) | **frus1961-63v10-12mSupp/d729 52**; …/d670 54; frus1958-60v06/d620 56; d616 57; frus1961-63v10/d202 60; frus1969-76ve11p1/d278 61; frus1950v02/d440 64 | 52–67 is well below the first-neighbour median: strong, and cross-decade (1951 to 1974) |

### M6.2 Semantic join into the database (§A.5)

The `vec3.py` join takes each neighbour's `(volume_id, document_id)` into `document_dates` and `document_cache` (date, header, apparatus flags, Cuba in text) in one pass. Two cross-decade facts came from the join and not from either surface alone: the NSSM 32 anchor (1969) has 1951 (`frus1950v02/d440`, a State Department policy statement), 1960 (`frus1958-60v06/d620`) and 1963 (`frus1961-63v10-12mSupp/d729`) documents among its 15 nearest; and the Mallory memo's neighbour `frus1958-60v05/d112` has `cuba_in_text` = 0 (it never uses the word) yet is on topic.

### M6.3 Centroid similarity (§A.5)

`vec4.py`: cosine of int8 centroids (dequantised) from the corpus binary, 553 volumes. Random volume pairs (2,000, `random.Random(1877)`): median 0.905, 5th percentile 0.851, 95th 0.956. Nearest volumes: frus1874 → frus1875v02 0.993, frus1876 0.992, frus1875v01 0.992; frus1898 → frus1899 0.983, frus1897 0.982, frus1896 0.977; frus1934v05 → frus1936v05 0.980, frus1935v04 0.980; frus1944v07 → frus1945v09 0.985, frus1943v05 0.984; frus1958-60v06 → frus1961-63v10-12mSupp 0.973, frus1961-63v10 0.971, frus1964-68v32 0.965; frus1961-63v11 → …Supp 0.988; frus1977-80v23 → frus1969-76ve11p1 0.981. Reading: neighbours are adjacent years, as expected; all are above the 95th percentile of random pairs (0.956). Used for orientation only; no claim in the overview depends on it.

### M6.4 The map (§A.5)

`vec4.py`, `vec5.py`: `semantic-map.bin` placements and `semantic-map-index.json` (140 clusters, 88,059 of 314,616 unclustered). Anchors: `frus1958-60v06/d499`, `frus1961-63v11/d21`, `frus1969-76ve10/d205`, `frus1977-80v23/d21`, `frus1981-88v03/d5`, `frus1958-60v05/d112`, `frus1961-63v10-12mSupp/d729` all in cluster 42 (terms castro, somoza, cuban, cuba; 7,650 documents); `frus1944v07/d878` in cluster 35 (cuban, habana, braden, cuba; 731); `frus1881/d405` in cluster 72 (sanguily, inclosure, azcuy, inclose; 15,484); `frus1874/d552`, `frus1898/d498`, `frus1904/d207`, `frus1934v05/d127` unclustered. Scope A cluster mix by decade (N of M): 1900s: c72 88 of 209, unclustered 101; 1910s: c52 (panaman, panama, loubet, lefevre) 432 of 741, unclustered 254; 1920s: c43 (zaya, crowder, airway, guatemala) 205 of 399, unclustered 174; 1930s: c39 (grau, machado, habana, mendieta) 335 of 620, unclustered 152; 1940s: c35 487 of 665; 1950s: c42 369 of 449; 1960s: c42 1,353 of 1,578; 1970s: c42 157 of 192; 1980s: c42 41 of 44. **Era-matched baseline** of unclustered share, all dated non-apparatus documents (`vec5.py`): 1900s 3,623 of 9,924 (0.37); 1910s 7,303 of 30,358 (0.24); 1920s 6,343 of 19,733 (0.32); 1930s 9,382 of 39,195 (0.24); 1940s 20,635 of 74,044 (0.28); 1950s 12,161 of 42,342 (0.29); 1960s 6,273 of 27,650 (0.23); 1970s 8,122 of 22,258 (0.36); 1980s 1,929 of 6,038 (0.32). Scope A unclustered: 1900s 101 of 209 (0.48), 1910s 254 of 741 (0.34), 1920s 174 of 399 (0.44), 1930s 152 of 620 (0.25), 1940s 150 of 665 (0.23), 1950s 55 of 449 (0.12), 1960s 183 of 1,578 (0.12), 1970s 22 of 192 (0.11), 1980s 3 of 44 (0.07). Overview: "about five in six of the Cuba chapter documents from 1950 on sit in one cluster": (369+1,353+157+41) of (449+1,578+192+44) = 1,920 of 2,263 = 0.848. Caveats (A.8): the map is a projection; cluster terms are c-TF-IDF over a sample; the layout input was the 256-dim cut; clusters are for exploration only. That the 1910s Cuba chapters fall mostly in a cluster labelled for Panama is a layout reading, not evidence about policy.

### M6.5 Near-duplicates (§A.5)

`vec6.py`: Hamming of `frus1881/d405` and `frus1894app2/d394` = **4** (the 1894 appendix reprints the Blaine despatch); next nearest to d405 is 77. Pairwise Hamming over the 22 collection documents that are in the vector index: closest pair is frus1961-63v10-12mSupp/d729 and frus1969-76ve10/d205 at 52 (different documents, 1963 and 1969); next 80 (frus1874/d552, frus1898/d498); no pair is a near-duplicate. The 1881 copy is cited; `frus1894app2` is not.

### M6.6 Documents in the overview reached through a vector operation and no full-text query

1. `frus1961-63v10-12mSupp/d729` (Bundy to President Johnson, 15 December 1963): first appeared as the nearest neighbour (52 bits) of the NSSM 32 study. No full-text query I ran covered December 1963 with this vocabulary (the missile-crisis query ended on 30 October 1962; the burden/economy query began in 1964).
2. `frus1958-60v05/d112` (Dulles, March 1959): first appeared as a neighbour (106 bits) of the Mallory memo. Its text never contains "Cuba" (it says Castro, Caribbean); no Cuba query could return it. 106 is no closer than a median 25th neighbour, so it is a lead that reading, not distance, justified.

Every other document in the overview was reached by a full-text query or by the editors' chapter headings; the vectors only confirmed neighbours (for example d498's neighbours are other Woodford despatches, not added). **Similarity is a lead, not evidence;** no claim in the overview rests on a distance. Recall@10 of the funnel is 0.902 (index `retrieval.measuredRecallAt10`), so absence of a neighbour from a list proves nothing.

## M7. Limits and thin spots

- **Library:** all 553 volumes; every count is of this index. The index stores porter stems; phrase counts above carry literal shares (M2.3, M2.4).
- **The nineteenth century is thin and arranged by correspondent;** my 1870s–1880s finding rests on three documents (`frus1874/d552`, `frus1881/d405`, `frus1886/d414`) and the 1897–98 finding on two (`frus1898/d498`, `frus1898/ch83`). The statement that security was "not yet the vocabulary" is supported by the zero rate of `national security` and by reading these few documents, not by a census of the vocabulary of that period; I did not run a census for `defence` or `safety` in the 1870s.
- **Scope A is a 20th-century construct** (starts 1900; excludes the Spain chapters where 1895–1900 Cuba material sits) and reflects editors' selection.
- **Not read:** the 1906–1909 intervention, the 1898–1902 occupation, the Bay of Pigs, Mariel and Africa material; the consular despatches from Cuba in the nineteenth century.
- **Sugar and capital figures:** one investment total (Q12, Cuba's claim); one claims total (Q35, Blumenthal's memo). No trade statistics were extracted.
- **TEI not consulted;** nothing here is a count of spellings or acronyms, and no number is a density of document text versus footnotes.
- **Excluded second editions** (`frus1951-54IranEd2`, `frus1969-76ve15p2Ed2`) from every SQL count; the vector artifacts include them, but none of my anchors or neighbours is from them.
- The `statuses` for restricted series reflect NARA's catalog fields as bundled (2026-09-10 for series facts; 2026-10-20 for the usage and authority indexes).

## M8. TRACE TABLE (overview → memo)

| # | overview statement | memo item |
|---|---|---|
| 1 | "23 printed documents"; "35 passages" | M5, M4 |
| 2 | "about 4,900 documents in the editors' Cuba chapters" (4,897); "62 volumes", "1900–1980" | M1, M2.2 |
| 3 | "about 13,900 documents that mention Cuba" (13,899), "481 volumes" | M2.1 |
| 4 | "553 volumes", "311,429 documents" | M0, M0.1 |
| 5 | decade rates "one in fifteen / thirteen / forty-five / nine" | M2.1 (68.7, 79.5, 22.7, 114.7 per 1,000) |
| 6 | "about three in five … fewer than five times" | M2.1 (8,592 of 13,841) |
| 7 | "about two chapter documents in three whose source is stated" | M3.1 (3,006 of 4,707) |
| 8 | Lot 65 D 438, A1 3053, 27022950, 1962–1963, partly restricted | M3.2 |
| 9 | Lot 74 D 272, A1 5175, 614703, 1961–1966, unrestricted | M3.2 |
| 10 | Lot 66 D 501, UD-UP 293-B, 648748, 1963–1965, unrestricted | M3.2 |
| 11 | Lot 62 D 24, A1 3148, 2363836, 1958–1961, partly restricted | M3.2 |
| 12 | libraries: Kennedy 1164, Johnson 567979, Carter 560131 | M3.2 |
| 13 | Lot 66 D 95, A1 1586E, 2839192, 1947–1979, partly restricted; second series 2839193 | M3.2 |
| 14 | Lot 73 D 191, A1-5758, 1040618, 1957–1975, partly restricted, 27 linear feet | M3.2 |
| 15 | Lot 65 D 212, UD-UP 215, 27022874, 1955–1962, fully restricted | M3.2 |
| 16 | Lot 66 D 204, A1 1590, 2538452, 1953–1964, possibly restricted | M3.2 |
| 17 | pre-1910 microfilm series (Spain 1792–1906; Cuba 1902–1906; Havana consuls 1783–1906; Cuban legation 1844–1906) | M3.3 |
| 18 | "only eight such documents" before 1940; "about 2,600 in all, almost all after 1950" | M2.4 (8 strict of 9; 2,643 hits; 2,615 after 1950) |
| 19 | control results ("returned documents in every decade"; "none") | M2.4 controls |
| 20 | "one document gives a total … the Cuban ambassador's claim of 1929" | M1.1, M4 (Q12) |
| 21 | "two documents … dated 1989, both from January" | M2.1 |
| 22 | "none of the Cuba chapter documents from 1900 to 1916 and a single one from the 1910s (a bond act)" | M2.5, M2.4 |
| 23 | 'national security': "almost none of the 1940s; about one in twenty of the 1950s; about one in three of the 1960s; about two in three of the 1970s; nearly nine in ten of the 1980s" | M2.5 (2 of 665; 23 of 449; 483 of 1,578; 127 of 192; 39 of 44) |
| 24 | "about as often as the whole series … about one in three in the 1960s in both" | M2.4 (1,081 of 3,173 vs 10,169 of 27,654) |
| 25 | sugar "about two in five … 1940s; about one in ten in the 1960s and 1970s; none of the 44 … 1980s" | M2.5 (275 of 665; 183 of 1,578; 19 of 192; 0 of 44) |
| 26 | communism etc. "one in twenty … 1930s; one in three … 1950s; nearly two in three … 1960s"; "about half of all its documents of the 1960s" | M2.5 (29 of 620; 154 of 449; 1,013 of 1,578); M2.3 (13,849 of 27,654) |
| 27 | "five in six" on the map | M6.4 (1,920 of 2,263) |
| 28 | "two documents … reached that way and by no word search"; "reprint … set aside" | M6.6, M6.5 |
| 29 | Q01, Q03 quoted ("is the largest insular possession … United States." ; "the one great cause of perpetual solicitude") | M4 Q01, Q03 |
| 30 | Q04 | M4 Q04 |
| 31 | "buys about 95 per cent, of the sugar exported from Cuba" | M4 Q05 |
| 32 | Q07, Q06, Q34 (Woodford quotations; "one-tenth") | M4 Q07, Q06, Q34 |
| 33 | Q09, Q08 (the 1898 message) | M4 Q09, Q08 |
| 34 | Q10 (naval-station clause), Q11 ("for the preservation of Cuban independence") | M4 Q10, Q11 |
| 35 | Q13 (Stimson) | M4 Q13 |
| 36 | Q15 (Hull; "eliminating the permissive right of intervention …") | M4 Q15 |
| 36b | Hull "pairs political understanding with profitable commercial relationships" (paraphrase) | the text of `frus1934v05/d127` read ("mutually helpful political understanding and … mutually profitable commercial relationships"); not quoted in the overview |
| 37 | Welles 1933 "still treats intervention as a live obligation"; "nearly 1,500 million dollars" | M4 Q14; Q12 |
| 38 | Navy 1941 wish to enlarge Guantánamo station; Q18 ("could not be applied to other countries of the Hemisphere") | M4 Q18 |
| 39 | Q19, Q20 | M4 Q19, Q20 |
| 40 | Q17 ("has been a reliable expansible source … jeopardized") | M4 Q17 |
| 41 | 1958 State–JCS meeting "defining Cuban internal stability as part of hemispheric defense" | M4 Q21 (cited, not quoted in the overview) |
| 42 | Q22 | M4 Q22 |
| 43 | Q23, with "the sugar legislation as the principal instrument" | M4 Q23, Q24 |
| 44 | Q25 ("What is the strategic impact …"; "substantially"; "My own personal view is, not at all") | M4 Q25 |
| 45 | Q26 ("an entirely different impact throughout Latin America") | M4 Q26 (Q27 in the collection) |
| 46 | Q28 ("a Cuba which poses no threat to its neighbors and which is not a Soviet satellite"); "isolation and covert measures as the main weapons" | M4 Q28; Q29 and the text of d729 (isolation measures and covert measures named as the two chief weapons) |
| 47 | Q30 ("Cuba has been a double-barreled problem …"); "ranked preventing strategic weapons as the only vital interest" | M4 Q30; the NSSM 32 text read (priority list: one "vital interest", then "major" and "important") |
| 48 | Q31; "claims … about two billion dollars" | M4 Q31, Q35 |
| 49 | Q33 | M4 Q33 |
| 50 | document dates and printed-edition titles in the citations | `manifest.json` titles; M4 dates (`document_dates.date_iso`) |
| 51 | "I checked that every quotation … is one the memo verified … and that every document cited … is in the collection" | M4 (35 of 35 exact; `check_overview.py`: 30 spans, 0 unmatched; 23 cited URLs, 0 missing from the collection, 0 collection documents uncited) |

ELIDED: nothing is shortened in this memo except the following. (a) Table M4 shows ellipses for Q02, Q06, Q10, Q11, Q19, Q29 (full strings are in `quotes_verified.json`). (b) The three per-anchor neighbour lists beyond rank 6 are in `vec_neighbours.txt`, not here. (c) The top-40 and top-30 listings from `arch1.py`/`arch4.py` are abbreviated to the rows used. (d) The 321-row `cuba_sections.tsv` is referenced, not reproduced. (e) The 15-row decimal and presidential-library tables are cut to the rows used.
