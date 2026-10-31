# Scope memo — American "soft power" in East Asia and the Pacific (run f9, 2026-10-31)

Operator memo. Every number carries its query, counting surface and denominator. Labels [M1]…[M30] are the lines the trace table at the end points to. All files named here are in `/Users/jbotts/frus-analysis/c3f/runs/f9/`.

## 0. Coverage and canaries

[M1] Coverage query (first tool call), output `553|321749|1103|8481`:

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;
```

553 volumes of the 553-volume series are in this index copy (taken 2026-10-25), 321,749 documents, 1,103 front matter, 8,481 editorial notes. Every count below is conditional on this copy; here the library is the whole series, so no result is thin *because of the library*, but several are thin in themselves and are flagged.

[M2] Read-only proof: `sqlite3 -readonly … "BEGIN; CREATE TABLE zz(x); ROLLBACK;"` failed with `attempt to write a readonly database` (exit 1).

## 1. Scope and how it was found

The question's own term, "soft power", postdates every document (Nye, 1990). It was translated into the contemporaries' vocabulary by reading the editors' chapter headings first (`headings.py` over `volume_structures.structure_json`, output `headings_all.txt`, 25,115 section rows; filtered `headings_hits.txt`, 151 rows). The formulas the editors use are "Information Policy" (1961–63 vol. XXV ch. 5), "United States Foreign Information Program" (1955–57 vol. IX comp. 6), "International Information Policy, Public Diplomacy, and Cultural Affairs" (1969–76 vol. XXXVIII pt 2 ch. 2), "Public Diplomacy" (the three 1917–72 Public Diplomacy volumes for 1961–72 and 1977–80 vol. XXX), plus in the regional volumes "closing of offices of United States Information Service" (1949 vol. VIII chs 12–14) and "Cultural relations program" (China, 1942–44, outside the chosen period).

[M3] Two volume sets (`scopevols.py`, from `manifest.json` titles via `scan_manifest.py` → `manifest_scan.txt`):
- **R** — 76 regional East Asia & Pacific volumes covering 1945–1980 (Far East, China, Japan, Korea, Indochina/Vietnam, Southeast Asia, Indonesia, Laos, East Asia–Pacific; 1958–60 vol. XV "South and Southeast Asia" included). 37,199 non-apparatus documents.
- **I** — 8 information/public-diplomacy volumes: frus1917-72PubDipv06, v07, v08, frus1955-57v09, frus1961-63v25, frus1969-76v38p2, frus1977-80v30, frus1950-55Intel. 1,816 non-apparatus documents.
- R+I = 84 volumes, 39,015 non-apparatus documents. Denominator SQL (in `scan_families.py`): `SELECT COUNT(*) FROM document_cache WHERE volume_id=? AND is_front_matter=0 AND is_editorial_note=0` per volume, summed (`scan_families.tsv`, rows R_total, I_total).

Date span: 1945–1980 (periodised on `document_dates.date_iso`, which is `frus:doc-dateTime-min`). No Ed2 volume is in R or I, so no second-edition suppression was needed.

Inclusion rule for the reading set: a document in I whose header names an East Asian or Pacific place (42 documents, `i_asia_headers.txt`), or a document in R whose header names an information agency, psychological or propaganda function, public affairs, or the OCB/PSB (99 documents, `r_info_headers.txt`) — together the 141-document **candidate set** (`candidate_set.txt`); plus documents surfaced by a ranked body query ([M8]) and by vector neighbours ([M24]). The collection keeps the 25 the argument rests on.

[M4] Header queries (exact):

```sql
-- i_asia_headers.txt (42 rows)
SELECT d.volume_id, d.document_id, dd.date_iso, substr(replace(d.header,char(10),' '),1,150)
FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
WHERE frus_documents MATCH 'header:(japan OR japanes OR china OR chines OR korea OR vietnam OR vietnames OR asia OR asian OR indonesia OR philippin OR thailand OR lao OR laos OR burma OR "far east" OR pacif OR southeast OR taiwan OR cambodia)'
AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN (<I, 8 volumes>) ORDER BY d.volume_id, dd.date_iso;
-- r_info_headers.txt (99 rows)
... WHERE frus_documents MATCH 'header:(usia OR usi OR "information agency" OR "information service" OR psycholog OR propaganda OR "public affairs" OR "information program" OR "operations coordinating board" OR "psychological strategy board" OR cultur OR "public opinion")'
AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN (<R, 76 volumes, list in R_in.txt>) ORDER BY dd.date_iso;
```

## 2. Measurements

### 2.1 Family scan with controls [M5]

`scan_families.py` → `scan_families.tsv`. SQL per family: `SELECT d.volume_id, COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN (<R+I>) GROUP BY d.volume_id`. Counting surface: the index (porter-stemmed, apparatus excluded by column; footnotes inside body_text are NOT separated — densities blend document and editor language).

- Positive control `"Department of State"`: nonzero in all 84 volumes (lowest frus1969-76v08, 10 documents); R 14,315, I 786.
- Negative control `ZZZ_IMPOSSIBLE_ZZZ`: 0 in all 84.
- Document counts (R / I): propaganda 2,744 / 228; `psycholog` 2,229 / 228; `usia OR usi` 849 / 589; "information program" 140 / 97; "image of the United States" 4 / 8; `prestig` 1,717 / 80; "public diplomacy" 2 / 78; "cultural exchange" 95 / 102; "Voice of America" 75 / 153; "soft power" 0 / 0; "psychological warfare" 260 / 58; "hearts and minds" 20 / 0.
- Union of the information-programme family `usia OR usi OR "information program" OR "psychological warfare" OR "Voice of America" OR "public diplomacy" OR "cultural exchange"` (same join and exclusions): R 1,288, I 721, R+I 2,009 documents (`collection_channels.txt`, first three lines).

### 2.2 Literal shares [M6]

`shares.py` → `shares.txt`/`shares.json`. Hit list = same MATCH over R+I, sorted by (volume_id, document_id); census when under 300 hits, else 40 evenly spaced. Text = header+dateline+source_note+body_text, whitespace-collapsed; Python `re` with IGNORECASE throughout (one test for every family). STRICT = single spaces; TOLERANT = inflections plus any run of space, hyphen, comma, parenthesis or full stop between words.

| Family (MATCH) | Hits R+I | Checked | TOLERANT | STRICT |
|---|---|---|---|---|
| "psychological warfare" | 318 | sample 40 | 40 of 40 | 40 of 40 |
| "information program" | 237 | census | 236 of 237 | 218 of 237 |
| "public diplomacy" | 80 | census | 80 of 80 | 80 of 80 |
| "cultural exchange" | 197 | census | 197 of 197 | 196 of 197 |
| "Voice of America" | 228 | census | 228 of 228 | 228 of 228 |
| `usia OR usi` | 1,438 | sample 40 | 36 of 40 | 36 of 40 |
| "Asian/Oriental mind…" (6 phrases, [M10]) | 30 | census | 30 of 30 | 29 of 30 |

Misses read: "information program" — frus1964-68v05/d257 ("Informant Program", a stemmer collision). `usia OR usi` — all four misses (frus1948v06/d146, d356; frus1949v07p1/d173, d353) are **"USI" = United States of Indonesia** (1948–49), a referent false friend, not an inflection (checked with `\bUSI\w*` over the same text, inline python logged). Consequence: the `usia OR usi` counts in frus1948v06 (89) and frus1949v07p1 (63) are inflated by Indonesia; both volumes were dropped from the decade table [M7]. The 1.000 shares test the stemmer only; the referent was tested by reading (section 3).

### 2.3 Decade shape [M7]

`decades.py` → `decades.tsv`. Numerator: the union family of [M5] over R minus frus1948v06 and frus1949v07p1, joined to `document_dates` and grouped by `substr(date_iso,1,3)||'0s'`; R denominator = same join without MATCH; corpus denominator = all dated non-apparatus documents.

| Decade | Docs | R dated docs | per 1,000 (R) | Corpus dated docs | per 1,000 (corpus) | Top volume share |
|---|---|---|---|---|---|---|
| 1940s | 219 | 12,328 | 17.8 | 75,872 | 2.9 | frus1949v08: 79 of 219 |
| 1950s | 389 | 12,112 | 32.1 | 43,159 | 9.0 | frus1955-57v21: 34 of 389 |
| 1960s | 414 | 7,884 | 52.5 | 27,654 | 15.0 | frus1961-63v02: 43 of 414 |
| 1970s | 109 | 3,370 | 32.3 | 22,640 | 4.8 | frus1969-76v08: 21 of 109 |
| 1980s | 1 | 106 | 9.4 | 6,038 | 0.2 | frus1977-80v13: 1 of 1 (too thin to read) |

The 1940s rate leans on one volume (the 1949 closing of USIS offices in Communist China: 79 of 219).

### 2.4 Ranked body query [M8]

```sql
SELECT d.volume_id, d.document_id, dd.date_iso, round(bm25(frus_documents),1) s, length(d.body_text), substr(...header...)
FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid LEFT JOIN document_dates dd ON ...
WHERE frus_documents MATCH '(usia OR usi OR propaganda OR psycholog OR "information program") AND (asian OR asia OR "far east" OR "far eastern") AND (attitud OR opinion OR imag OR prestig) AND (effect OR effective OR impact OR assess)'
AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN (<R+I>) ORDER BY s ASC LIMIT 45;
```
1,284 documents match (COUNT form of the same predicate); top 45 in `ranked1.txt`. It added the three NSC status reports on the information program (frus1955-57v09/d185, d190, d207), Jessup's 1949 outline (frus1949v07p2/d386) and others to the reading list.

### 2.5 Gap searches [M9]

`gaps.py` → `gaps.txt`, same join, R+I, non-apparatus, with controls in the same pass (POS "Department of State" 15,101 documents in 84 volumes; NEG 0 in 0).
- "soft power": 0 documents. Relaxed form `soft`: 349 documents in 76 volumes (e.g. frus1917-72PubDipv08/d143 "gone 'soft' on Chinese Communism"; frus1952-54v13p2/d992 "soft heart … soft head").
- `(poll OR survey) AND (usia OR usi)`: 157 documents in 36 volumes; adding `(japan OR japanes)`: 38 in 17.
- `(usia OR usi) AND (australia OR "new zealand")`: 69 in 36 volumes. `(usia OR usi) AND (micronesia OR fiji OR "trust territory" OR samoa OR guam)`: 6 in 5 volumes.
- `fulbright`: 381 in 59; with `(evaluat OR effect OR impact)`: 229 in 50. Not read; no claim made about exchange evaluation.
- loss-of-face phrases: 494 in 77 (not read; not published in the overview).

[M10] Audience-stereotype family `"Asian mind" OR "Oriental mind" OR "Asian mentality" OR "Oriental mentality" OR "Asian psychology" OR "Oriental psychology"`: 30 documents in 22 volumes of R+I (all in R); census in `gaps.txt` with a 240-character context per hit. Tolerant 30 of 30, strict 29 of 30. Referent test by reading the contexts: the large majority are American officials characterising Asian audiences (e.g. frus1952-54v12p2/d60, frus1952-54v13p2/d992, frus1958-60v01/d26 reports a Vietnamese/French view, frus1969-76ve13/d11); a few put the phrase in an Asian speaker's mouth (frus1952-54v14p2/d768, frus1958-60v17/d35 Garcia). Dates run 1949–1972; 26 of the 30 hits are in volumes covering 1949–1963 (counted by hand from the volume ids in `gaps.txt`: 1949 3, 1950 3, 1952–54 5, 1955–57 8, 1958–60 3, 1961–63 4; then 1964–68 2, 1969–76 2).

### 2.6 Archival channels [M11]–[M13]

[M11] **Came-from** (`document_sources`, one row per document) over the 141-document candidate set (`channels.py` → `channels.txt`; SQL `SELECT repository, record_group, lot_file_norm, series_name, citation_era FROM document_sources WHERE volume_id=? AND document_id=?`). All 141 have a row. Grouped by record group (inline python, logged): RG 59 66; RG 306 40; Johnson Library 9; Kennedy Library 7; RG 84 7; Nixon materials 2; Eisenhower Library 2; unparsed 2; one each RG 34, CIA, Library of Congress, RG 330, RG 305, Carter Library (sum 141). citation_era: structured 73, lot_file 44, decimal 14, subject_numeric 5, cfpf 3, named_series 2. Top units: Lot 62 D 430 (OCB files) 16; Lot 63 D 351 7; Johnson Library NSF 6; Kennedy NSF 5; Lot 61 D 385 5; RG 306 "USIA/I/S Files: FRC 68 A 4933" 5; RG 306 Director's Subject Files Box 10 4; Lot 67 D 54 4.

[M12] **Pointed-at** (`external_citations`, many rows per document; SQL `SELECT repository, collection, lot_file_norm, decimal_class, anchor FROM external_citations WHERE volume_id=? AND document_id=?`) over the same 141: unattributed Department of State rows 16 (11 documents); Lot 62 D 430 8 rows (7 documents); Lot 66 D 95 4 (4); Lot 67 D 54 2 (1); one row each for Lots 60 D 627, 65 D 101, 63 D 351, 71 D 273 and several presidential-library collections. Caveat: this channel has no row before 1910-12-06, stores the citation fragment not the sentence, and holds lot, library and decimal anchors only; it was not summed with [M11].

[M13] Resolution through the bundled JSON (`resolve.py` → `resolve.txt`, `resolve3.txt`; `resolve2.py` → `resolve2.txt`): `central-files-index.json` `lotFiles` keyed on `lotNumber` with spaces folded → `naId` → `series-facts-index.json` `byNaId` decoded through `legend`.

| Lot | Channel(s) | RG / entry | NAID | Title | Dates | Access (NARA) | Creator heading (verified) |
|---|---|---|---|---|---|---|---|
| 62 D 430 | came-from 16, pointed-at 7 docs | RG 59, A1 1586C | 2839191 | Subject and Special Files | 1953–1961 | Restricted – Partly (FOIA b1) | State, Executive Secretariat |
| 63 D 351 | came-from 7 | RG 59, A1 1586E | 2839192 | Records Relating to NSC Policy Papers | 1947–1979 | Restricted – Partly (FOIA b1) | State, Office of the Secretary, Executive Secretariat |
| 66 D 95 | pointed-at 4 | RG 59, A1 1586E | 2839192 | (same series) | 1947–1979 | Restricted – Partly | (same) |
| 67 D 54 | came-from 4, pointed-at 1 | RG 59, A1 5305 / A1 5414 | 631403 | Subject Files of the Vietnam Working Group | 1963–1974 | Unrestricted | State, Bureau of East Asian and Pacific Affairs |
| 72 D 192 | came-from 2 | RG 59, A1 5376/5376A | 631695 | Speeches and Statements | 1961–1969 | Unrestricted (use possibly restricted) | State, Office of the Secretary |
| 65 D 101 | pointed-at 1 | RG 59, A1 558-D | 1136548 | Chronological Files | 1947–1962 | Unrestricted | Policy Planning Council |
| 71 D 273 | pointed-at 1 | RG 59, A1 5441 | 2131139 | Files of Ernest K. Lindley | 1961–1969 | Unrestricted | Policy Planning Council |
| 59 D 260 | pointed-at (from frus1955-57v09/d207) | RG 306, UD-WW 151, 197, 234, 264, 287, 288, 365, 366, 372, 379, 382 | 1257679 | Subject Files | 1953–1971 | Restricted – Partly (FOIA b1); 47 linear feet | USIA, Office of Policy and Plans |
| 61 D 385, 60 D 627, 63 D 224, 62 D 255, 60 D 322 | various | — | — | not in `lotFiles`; 60 D 627 is a "possible" Conference Files match in `curated-lot-resolutions.json` | | | |

The RG 306 series that most of the USIA documents came from — "Director's Subject Files, 1968–1972, Entry A1–42" (frus1917-72PubDipv08/d58, d88, d146, d149), "General Records Relating to the Joint U.S. Public Affairs Office (JUSPAO), 1966–1975, Entry A1–31" (frus1917-72PubDipv07/d48), "Office of Policy and Plans … Subject Files, Entry P–207" (frus1917-72PubDipv08/d31), "DIRCTR Subject Files 1963–69, Entry UD WW 257, Acc. 72A5121" (frus1917-72PubDipv07/d32), "DIRCTR Files 1966, Entry UD WW 193, Acc. 69-A-3445" (frus1917-72PubDipv07/d73) — appear in `collection-authority.json` as named collections **without a NAID**. `accession-series-index.json` (keyed `<RG>/<accession>`) maps 306/72A5121 and 306/69A3445 each to several series (e.g. 1257679, 40943515, 48349732, 53279603), so the accession does not pick one shelf; 306/68A4933 maps to several including "Vietnam Working Group Subject Files" (42125423). None was promoted to a NAID here. `series-facts-index.json` holds 14 series whose creator heading names the USIA; none is an East Asia/Far East area office (list in `resolve2.txt`). Pre-1940 coverage of the archival stack, re-derived: 11 of 698 `series-facts` rows start before 1940 (irrelevant to this 1945–80 scope).

## 3. Reading

[M14] Retrieved whole (captured length = `length(body_text)` recorded per document): 61 documents, 658,318 characters, in four batches (`dump.py`; `reading_list.txt`, `reading_list2.txt`, `reading_list3.txt`, `reading_list4.txt`; lengths in `docs/_lengths*.tsv`; raw text in `docs/<volume>__<doc>.txt`). One of the 61 (frus1955-57v09/d184) proved an editorial note and was excluded. Reading SELECT:

```sql
SELECT header, dateline, source_note, body_text, length(body_text), is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?;
```

Long documents were read through keyword-in-context passes (`kwic.py`, Python `re` IGNORECASE, sentence split) plus full reading of the passages quoted. Quoted: 34 quotation strings (Q1–Q34) from 25 documents (all 25 are the collection). Documents read and set aside as off-question or marginal: frus1917-72PubDipv06/d111, d112 (Laos/Vietnam press tactics), frus1952-54v12p2/d174 (arms to Burma), frus1955-57v22/d448, frus1955-57v23p2/d99, frus1958-60v16/d199, frus1952-54v15p1/d251, frus1950v07/d736, frus1951v06p1/d22, frus1958-60v16/d58, frus1917-72PubDipv07/d171, d85, d103, frus1917-72PubDipv08/d24, d92, d121, d127, frus1969-76v19p2/d67, frus1977-80v30/d2, d81, d101, frus1964-68v01/d122, frus1964-68v03/d138, frus1917-72PubDipv07/d37, frus1964-68v26/d106, frus1950-55Intel/d226, frus1917-72PubDipv06/d135, d140, frus1917-72PubDipv08/d99, frus1961-63v02/d179, d199, frus1961-63v03/d23, d28, frus1961-63v04/d81, frus1977-80v22/d104.

### 3.1 Quotations [M15]

Every quotation below was tested as an exact substring of the raw `body_text` (`verify_quotes.py` → `verify_quotes.txt`: 34 of 34 RAW, each occurring once; Q30–Q34 are fragments the overview quotes inside its sentences). Verification SELECT: `SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?`. Quotation table = `quotes.tsv`.

| Q | Pair | Text |
|---|---|---|
| Q1 | frus1949v07p2/d386 | More important than any temporary ebb or flow in the political tide is the basic attitude of the peoples of Asia towards the United States. |
| Q2 | frus1917-72PubDipv08/d31 | PAOs emphasized that the image of the US usually depended more on the state of bi-lateral relations (security treaty, Okinawa, Korean military modernization, trade restrictions) than on developments within the US. |
| Q3 | frus1917-72PubDipv08/d31 | But there was general agreement that US prestige is diminished when we are not able to solve our own problems at home. |
| Q4 | frus1969-76v38p2/d105 | The results in Indochina have heightened the ever-present doubts on Taiwan about USG intentions and capabilities in Asia. |
| Q5 | frus1977-80v30/d83 | We still face deeply implanted and persistent feeling that new administration is “withdrawing” or, at least, “reducing priority” in East Asia. |
| Q6 | frus1977-80v30/d79 | this Administration believes shoring up the confidence of East Asians in America’s long-term staying power and positive involvement in the area is real and necessary. |
| Q7 | frus1952-54v13p1/d116 | Yet they are primary target for VM propaganda which follows Soviet line of giving masses saturation treatment. |
| Q8 | frus1917-72PubDipv07/d73 | In almost every country of the area, our programs are directed at elite groups: government officials, university and high school teachers, media representatives, top-level business executives. |
| Q9 | frus1917-72PubDipv07/d32 | Granted, there is undeniable value in programs aimed at intellectuals, urban leaders and students, but I believe the war is going to be won or lost out in the hamlets, where the VC are. |
| Q10 | frus1952-54v12p2/d403 | suitable information programs for the general public, taking into account local cultural attitudes |
| Q11 | frus1955-57v09/d185 | Major Japanese newspapers continued to reprint from a translated wireless bulletin prepared by USIA in Japan an average of 8,000 column inches a month. |
| Q12 | frus1917-72PubDipv08/d88 | Rating of the U.S. as a dependable ally of SVN reached the lowest point in thirteen Saigon surveys |
| Q13 | frus1917-72PubDipv06/d127 | Astronaut John Glenn and family left Japan last night after what was probably the most successful visit by an American, from a public image standpoint, since that of Attorney General. |
| Q14 | frus1955-57v09/d207 | Lack of awareness in top Indonesian Government circles of the dangers of Communism and apathy, and lack of organization by Indonesian anti-Communists would appear to indicate that the Agency’s program in Indonesia during the coming year will meet heavy odds. |
| Q15 | frus1961-63v01/d265 | But the spectre of charges that “U.S. imperialists are waging germ warfare on Asians” haunts me. |
| Q16 | frus1917-72PubDipv07/d48 | The American presence is a “foreign” presence that unavoidably generates resentments which are likely to grow as the presence grows. |
| Q17 | frus1917-72PubDipv08/d58 | USIA has, from the beginning, considered its psychological operations (PSYOP) support program in Viet-Nam as short-term in nature. |
| Q18 | frus1961-63v02/d16 | the image of the GVN in the world press can be no better than the face the GVN presents to the public |
| Q19 | frus1955-57v09/d190 | In the Far East USIA was forced to deal with mixed emotions regarding the use of atomic weapons against Asiatic peoples, and to counter communist propaganda designed to stir up race hatred. |
| Q20 | frus1917-72PubDipv08/d149 | Although the overseas Chinese appear proud of the achievements of Peking, they are reluctant to accept communist political and economic models. |
| Q21 | frus1947v07/d245 | But American policy toward China, which they conceive to be the product of a stupid or wicked government rather than the will of the American people, is heartily condemned by all student liberals. |
| Q22 | frus1917-72PubDipv08/d146 | The President’s projected visit to Peking presents us with opportunities to build what is now a temporary psychological asset into a long-range one. |
| Q23 | frus1917-72PubDipv08/d143 | While we do not want to appear as having gone “soft” on Chinese Communism neither do we want to appear anti-Chinese or anti-Peking. |
| Q24 | frus1977-80v30/d152 | But the Chinese appear to be determined to go down this road, and until the line changes—which it can do although at considerable cost—we have an opportunity to enhance the communication process to a significant degree. |
| Q25 | frus1950v06/d31 | There is already evidence, however, of increased usage of USIE news and feature material in the local press throughout the area. |
| Q26 | frus1917-72PubDipv08/d31 | PAOs noted that the Japanese image in Southeast Asia is not good. |
| Q27 | frus1952-54v13p1/d116 | All factors recited must be viewed as effective though degree cannot be accurately measured. |
| Q28 | frus1917-72PubDipv07/d73 | the image of American strength, reliability and friendship is basic to our objectives |
| Q29 | frus1952-54v12p2/d60 | Bulk of Burmese people simply unable understand aid in terms of altruism. |
| Q30 | frus1952-54v13p1/d116 | are not a primary target group |
| Q31 | frus1952-54v12p2/d403 | with and through indigenous leadership |
| Q32 | frus1955-57v09/d190 | saturated |
| Q33 | frus1977-80v30/d83 | public diplomacy of the new administration in this area has been effective |
| Q34 | frus1952-54v12p2/d60 | failure or inability explain our motives convincingly to oriental mind |

Note on Q11 and Q12: they are figures the documents report (the agency's own measures), not measurements of this session. Q12's survey figures (637 interviews, 26 percent "very" or "rather dependable") are in frus1917-72PubDipv08/d88 as read in `docs/`.

### 3.2 Collection [M16]

25 documents (`collection_pairs.txt`), each verified present, non-apparatus and not duplicated (`collection_check.tsv`: every row `is_front_matter=0`, `is_editorial_note=0`); no Ed2 volume. Came-from for the 25 (`collection_channels.txt`): RG 306 USIA 11 (Director's Subject Files A1–42 ×4; Office of Policy and Plans P–207; Office of the Director P–104; DIRCTR UD WW 257; DIRCTR UD WW 193; JUSPAO A1–31; FRC 67 A 222; FRC 68 A 4933); RG 305 1 (frus1969-76v38p2/d105, "Records of the USIA … Entry UD–UP 7", as the source note gives it); RG 59 Central Decimal File 6; RG 59 Lot 63 D 351 3; RG 59 Central Foreign Policy File 2; Kennedy Library (RFK papers) 1; Nixon materials NSC Files 1. Pointed-at rows for the 25: 12 rows on 5 documents (frus1955-57v09/d185, d190, d207; frus1952-54v13p1/d116; frus1917-72PubDipv08/d143).

## VECTORS

Artifacts: `semantic-vectors-index.json`, `semantic-vectors-binary.bin`, `semantic-map.bin`, `semantic-map-index.json`, Tier-2 shards in `/Users/jbotts/frus-analysis/c3/SemanticVectors/`. Scripts `vectors.py` → `vectors.txt`, `vec2.py` → `vec2.txt`.

[M17] **Digest check**: index `provenanceDigest` 89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101; identical at offset 20 of the binary and the map, at offset 16 of every shard read (asserted in code for each shard loaded; spot-printed for frus1917-72PubDipv08 and frus1969-76v38p2), and in the shard folder's `.generation`. Index `generated` 2026-10-15, `harvestGenerated` 2026-10-15T06:55:14. One generation, no mixing.

[M18] **Identity**: §A.3 decode round-trips 553 of 553 volumes. Every id below comes from the decoded segments.

[M19] **Baselines at this digest**: random pairs (20,000, `random.Random(1877)`): mean 167.2, sd 14.9, 1st percentile 131, minimum 90 bits of 512. k-th-neighbour over 200 documents (`random.Random(2026)`): 1st-neighbour median 83; 10th median 100 (quartiles 94, 108); 25th median 106 (quartiles 100, 113).

[M20] **Nearest neighbours of a document** (Hamming-800 pool over sign bits, rerank by Tier-2 int8 cosine, `retrieval.rerankPool` 800). Calibrated = (cosine − 0.40)/0.60, the index's `scoreCalibration.documentOffset`; raw cosines labelled raw. Anchor frus1917-72PubDipv08/d31 (1969 Manila PAO conference): top 15 include frus1917-72PubDipv07/d106 (Hamming 81, raw 0.920, calibrated 0.867), frus1969-76v38p2/d105 (96, 0.917, 0.862), frus1917-72PubDipv08/d99 (90), frus1955-57v09/d190 (100), frus1951v06p2/d105 (94), **frus1952-54v13p1/d116** (88, raw 0.906, calibrated 0.843), frus1955-57v09/d185 (104), frus1961-63v25/d156 and frus1917-72PubDipv06/d150 (reprints of one USIA memorandum to employees: 102 and 99), frus1917-72PubDipv07/d32 (97), frus1950v06/d9 (an editorial note, 90), frus1955-57v09/d207 (98). Anchor frus1969-76v38p2/d105 (1975 post-Indochina post reports): frus1969-76v01/d54 (78, 0.922/0.870), frus1969-76v38p1/d54, frus1917-72PubDipv08/d31 (96), frus1977-80v22/d104 (82), frus1977-80v01/d88, frus1981-88v01/d229, frus1969-76ve12/d16, d10, d17, frus1977-80v22/d107, d102, d3, frus1951v06p1/d12, frus1961-63v02/d142, frus1950v06/d89. Read against [M19]: all listed neighbours sit between Hamming 76 and 104, i.e. within the ordinary 1st-to-25th-neighbour band (medians 83 to 106), and far inside chance for random pairs (1st percentile 131). They are suggestions, not evidence of relationship. All neighbour volumes are present in `document_cache` (all 553 are), so none needed a canonical-URL flag. Recall caveat: `retrieval.measuredRecallAt10` = 0.9021, so about one true top-10 neighbour in ten is missing; no absence is claimed from these lists.

[M21] **Semantic join**: each neighbour was joined to `document_cache` (header, apparatus flags), `document_dates` and `document_sources` (columns printed in `vectors.txt`). For anchor d31 the join shows the neighbours split between RG 306 USIA series and RG 59 lots (63 D 351) and decimal files, i.e. the vectors pull State's regional reporting (Saigon 1952, Rangoon/NEA 1951) next to USIA's own planning paper.

[M22] **Centroid similarity** (cosine of int8 centroids, normalised): frus1917-72PubDipv08 nearest volumes frus1917-72PubDipv07 0.981, PubDipv06 0.977, frus1977-80v30 0.976, frus1969-76v38p2 0.965, frus1969-76v02 0.962, frus1961-63v25 0.962 — confirming the I set is a coherent group. Numpy warned of an overflow/NaN in the full-matrix product (one or more centroid rows); the printed values were finite and are reported as read, unverified beyond that.

[M23] **The map**: clusters of the 25 collection documents (`vec2.txt`): cluster 29 (terms lao, vietnamese, vietnam, thieu) 9 documents; cluster 138 (cia, nsc, usia, inglis) 3; cluster 103 (kissinger, chou, taiwan, huang) 3; cluster 20 (grc, formosa, chiang, taiwan) 1; cluster 3 (nanking, shanghai, chinese, tientsin) 1; unclustered 8 of 25. Era-matched baseline on this layout: 40,679 of 141,003 documents in volumes whose manifest midpoint year is 1945–1980 are unclustered. The collection's unclustered share is in line with that baseline; clusters used only to describe, not to measure.

[M24] **Near-duplicates**: pairwise Hamming among the 25 collection documents (300 pairs; mean 139.2). Closest: frus1955-57v09/d190–d185 at 32, d190–d207 at 50, d185–d207 at 56 — three successive NSC status reports in one template (different dates, lengths 51,295 / 42,785 / 48,892 characters; each quotation used occurs once in its own document), so not reprints; each is counted once. Next pair at 85. A reprint pair did appear among neighbours of d31 (frus1961-63v25/d156 and frus1917-72PubDipv06/d150, same 1963 memorandum in two volumes); neither is in the collection.

**Reached through a vector operation and through no full-text query**: frus1952-54v13p1/d116 (Heath, Saigon, 20 September 1952). It is not in the 141-document candidate set and not in the 1,284 hits of [M8] (COUNT of that predicate restricted to this pair returned 0, logged). It is in the overview (Findings 2 and 3) and the collection. Also reached by vectors but not used: frus1977-80v22/d104 (read; on policy credibility, not messaging).

## 4. Findings as argued (operator form)

- F1 Credibility of commitment, more than culture, governs the image — Q1, Q2, Q3, Q4, Q5, Q6 (frus1949v07p2/d386; frus1917-72PubDipv08/d31; frus1969-76v38p2/d105; frus1977-80v30/d79, d83).
- F2 Elites versus masses — Q7, Q8, Q9, Q10, Q28 (frus1952-54v13p1/d116; frus1952-54v12p2/d403; frus1955-57v09/d190; frus1917-72PubDipv07/d32, d73).
- F3 How effectiveness was judged — Q11, Q12, Q13, Q14, Q25, Q27 (frus1950v06/d31; frus1955-57v09/d185, d207; frus1917-72PubDipv06/d127; frus1917-72PubDipv08/d88; frus1952-54v13p1/d116).
- F4 Vietnam: the American presence as the message's liability — Q15, Q16, Q17, Q18 (frus1961-63v01/d265; frus1961-63v02/d16; frus1917-72PubDipv07/d48; frus1917-72PubDipv08/d58).
- F5 Beliefs about the audience — Q19, Q20, Q21, Q26, Q29, plus [M10] (frus1955-57v09/d190; frus1917-72PubDipv08/d149, d31; frus1947v07/d245; frus1952-54v12p2/d60).
- F6 China, 1971–78 — Q22, Q23, Q24 (frus1917-72PubDipv08/d143, d146; frus1977-80v30/d152).

## 5. Checks before finishing

[M25] Every quotation in the overview and every excerpt in the collection is one of Q1–Q34, verified in `verify_quotes.txt` (34 of 34 RAW). `check_outputs.py` → `check_outputs.txt` re-tests mechanically: all 34 collection excerpts are exact substrings of their document's `body_text`; every double-quoted span in the overview is a substring of a collection document's text except four that are not document quotations — "soft power" (the question's term), "South and Southeast Asia" (a volume title, `manifest_scan.txt`), "cultural relations program" (an editors' chapter heading, `headings_hits.txt`) and the collection's own name — plus single-word spans "saturated" and "effective", confirmed present. Inner quotation marks in the overview were changed to the source's curly marks so the spans match exactly.

[M26] The overview cites 25 (volume, document) pairs by URL; `check_outputs.txt` reports none missing from the collection and no collection document uncited. The collection passes the contract checks (format, version 2, minimum reader 1, six composition keys, both ids on every document and excerpt, no duplicate pair, no Ed2 volume, every pair present and non-apparatus, notes opening with the run attribution, `archivalSources` block last).

## TRACE TABLE

| Overview item | Memo line |
|---|---|
| 553 volumes in the index; whole series present | [M1] |
| 84 volumes, about 39,000 documents in scope; 1945–1980; front matter and editorial notes excluded | [M3] |
| about 2,000 documents use the information-programme vocabulary | [M5] |
| 141 documents whose headings name the information agencies (candidate set) | [M4], [M11] |
| rate rises from about 18 per 1,000 (1940s) to about 52 (1960s), falls to about 32 (1970s); 1940s lean on 1949 China volume | [M7] |
| "soft power" never appears; the plain word "soft" in about 350 | [M9] |
| polls/surveys with USIA/USIS: about 160 documents; about 40 also mention Japan | [M9] |
| Pacific islands with USIA/USIS: 6 documents; Australia/New Zealand: about 70 | [M9] |
| "Oriental/Asian mind" phrases: 30 documents in 22 volumes, 26 of them in volumes covering 1949–1963 ("most of them from 1949 to 1963") | [M10] |
| Vietnam about a quarter of the collection: 7 of 25 (frus1952-54v13p1/d116, frus1917-72PubDipv07/d32, frus1917-72PubDipv08/d88, frus1961-63v01/d265, frus1961-63v02/d16, frus1917-72PubDipv07/d48, frus1917-72PubDipv08/d58) | [M16] |
| "USI" for United States of Indonesia trap (methods paragraph) | [M6] |
| came-from among the 141: 66 RG 59, 40 RG 306 | [M11] |
| Lot 62 D 430, Lot 63 D 351, Lot 67 D 54, Lot 59 D 260 and their NAIDs, dates, access | [M13] |
| RG 306 Director's Subject Files A1–42, JUSPAO A1–31 etc. have no identifier in the bundled data | [M13] |
| 61 documents retrieved whole, 25 quoted | [M14] |
| 25 documents in the collection | [M16] |
| one document reached only through semantic neighbours (Saigon 1952) | [M20], [M24] |
| Quotations Q1–Q34 | [M15] |
| 25 documents, about 2,000 in scope (bottom line) | [M16], [M5] |
| nearly half of the 141 from State (66), more than a quarter from USIA (40) | [M11] |
| 30 documents / 22 volumes "Oriental mind" (Finding 5) | [M10] |
| Saigon 1970 survey figure (in Q12) | [M15] note |
| checks of quotations and citations | [M25], [M26] |
