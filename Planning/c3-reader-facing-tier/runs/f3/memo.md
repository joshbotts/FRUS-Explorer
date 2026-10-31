# Scope memo — American soft power in East Asia and the Pacific (run f3, 2026-10-31)

Operator memo. Every number carries its query or script; scripts and their outputs are under
`/Users/jbotts/frus-analysis/c3f/runs/f3/scripts/` and `/Users/jbotts/frus-analysis/c3f/runs/f3/raw/`.
The command log is `queries.log`. All counts are conditional on this index copy: **553 volumes**
(`frus-copy-2026-10-25.db`), which is the full series of 553, but every figure below is still "in this
index", and most are confined to the 81-volume scope.

## 0. Coverage and read-only proof

```
sqlite3 "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro" "SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;"
-> 553|321749|1103|8481                                                         [M0]
sqlite3 -readonly ... "BEGIN; CREATE TABLE zz(x); ROLLBACK;"  -> Error: attempt to write a readonly database
```
Non-apparatus documents corpus-wide: `SELECT COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0;` -> 312,169 [M0b].

## 1. Scope chosen and how it was found

**The question's own term is absent.** `"soft power"` (FTS phrase) returns 0 documents corpus-wide and 0 in
scope [M1]; the relaxed form `soft` returns 345 non-apparatus documents in 73 of the 81 scope volumes [M1b]
(`SELECT COUNT(*), COUNT(DISTINCT c.volume_id) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'soft' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id IN (<scope>)`).
The term is Joseph Nye's (1990) and postdates every document; the contemporaries' vocabulary is
"information program", USIA/USIS, "psychological strategy/warfare", "cultural exchange", "image of the
United States", "prestige". I scoped on that vocabulary.

**Volume scope (81 volumes, `scope_volumes.txt`).** Found from `manifest.json` titles (regex
`east asia|pacific|southeast asia|far east|china|japan|korea|…|public diplomacy|information`, earliest
date >= 1940; output `raw/manifest_candidates.txt`, 93 rows) and from a volume ranking of the
co-occurrence query in `raw/scope_rank.txt`:
- 72 regional volumes: the Far East / East Asia–Pacific, China, Japan, Korea, Indochina/Vietnam,
  Southeast Asia, Laos, Indonesia volumes from frus1946v08 to frus1977-80v22 (wartime 1940–45 Far East
  volumes excluded: the question is about the postwar information state).
- 9 global information volumes: frus1917-72PubDipv06, v07, v08; frus1955-57v09; frus1961-63v25;
  frus1969-76v38p2; frus1977-80v30; frus1952-54v02p2 (Psychological Strategy Board); frus1950-55Intel.
  In these, a document counts only if it also names an Asian place.
- Not in scope, a gap: the 1981–88 volumes (frus1981-88v01, v04 ranked in `raw/scope_rank.txt` with 19 and 17 hits) and
  the Public Diplomacy volumes before 1961 (frus1917-72PubDip, the WWI volume, is in the index but
  outside the period).

`SELECT COUNT(DISTINCT volume_id), COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0 AND volume_id IN (<scope>)` -> **81 | 35,214** [M2].
Regional volumes alone: 72 volumes, 33,067 non-apparatus documents [M2b] (`raw/coreset_out.txt`).

**Inclusion rule (core set C).** Script `scripts/coreset.py`, output `raw/coreset_out.txt`:
```
SELECT c.volume_id,c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid
 WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id IN (<volumes>)
 regional MATCH: (usia OR usi OR "information program" OR "psychological strategy" OR "psychological warfare" OR "cultural exchange")
 global   MATCH: the same AND (asia OR asian OR "far east" OR japan OR japanese OR korea OR vietnam OR "viet nam" OR philippines OR indonesia OR thailand OR laos OR cambodia OR burma OR china OR chinese OR taiwan OR australia OR pacific)
```
-> regional 1,221, global 352, union **1,573** in 80 volumes [M3].

**False friend found and removed.** Literal share of C on 40 evenly spaced documents (`scripts/core_audit.py`,
`raw/core_audit_out.txt`; Python `re`, IGNORECASE, header+dateline+source_note+body_text whitespace-collapsed):
STRICT 33 of 40, TOLERANT 35 of 40 [M4]. The five tolerant misses all carried only the token `USI`
(`raw/docs` not needed; inline check in queries.log): four were **"USI" = United States of Indonesia**
(frus1948v06/d153, frus1948v06/d42, frus1949v07p1/d249, frus1949v07p1/d385) and one was USIE, the
U.S. Information and Educational Exchange program (frus1951v07p2/d94), a true referent. Census over all
1,573 (`scripts/core_clean.py`, `raw/core_clean_out.txt`), keeping a document only when the TOLERANT regex
`\b(USIAs?|USIS|USIE|information[\s\-,().]+programs?|psychological[\s\-,().]+(strateg\w*|warfare)|cultural[\s\-,().]+exchanges?|U\.\s?S\.\s?I\.\s?[AS]\.?|Information Agency|Information Service)`
matches: kept **1,401**, dropped 172, of which 166 contain bare `USI`; dropped mostly from frus1948v06
(82) and frus1949v07p1 (61) [M5]. **C = 1,401 documents in 80 volumes** (`raw/coreset_clean.tsv`).
Literal share of the cleaned C, same method: STRICT 39 of 40, TOLERANT 40 of 40 [M6]
(`raw/core_audit_clean_out.txt`). That 1.000 tests the regex, not the subject; the referent was tested
by reading (Section 4).

## 2. Controls (same pass, same scope, apparatus excluded)

```
MATCH '"department of state"'  -> 14,755 documents, 81 of 81 volumes          [M7]
MATCH 'ZZZ_IMPOSSIBLE_ZZZ'     -> 0 documents, 0 volumes                       [M7b]
```
SQL: `SELECT COUNT(*), COUNT(DISTINCT c.volume_id) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH '<term>' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id IN (<scope>);`

## 3. Phrase families measured (all with literal share; `scripts/phrase_audit.py`)

Counting surface: FTS hit list over the 81 scope volumes, apparatus excluded; literal test Python `re`
IGNORECASE over header+dateline+source_note+body_text, whitespace-collapsed. Census when hits < 300,
otherwise 40 evenly spaced from the (volume_id, document_id)-sorted list. Outputs `raw/phrase_audit.jsonl`,
`raw/phrase_audit2.jsonl`.

| family (FTS MATCH) | hits | checked | STRICT | TOLERANT (published) | note |
|---|---|---|---|---|---|
| "information program" | 257 | census | 163 of 257 | 256 of 257 | strict misses are plurals |
| "psychological warfare" | 321 | sample 40 | 40 of 40 | 40 of 40 | |
| "psychological strategy" | 80 | census | 79 of 80 | 79 of 80 | |
| "cultural exchange" | 197 | census | 130 of 197 | 197 of 197 | |
| "image of the united states" | 12 | census | 11 of 12 | 11 of 12 | |
| "american image" | 14 | census | 14 of 14 | 14 of 14 | |
| "united states/us/american prestige" | 131 | census | 131 of 131 | 131 of 131 | INVALID AUDIT: regex was the bare word "prestige", tests the stemmer only; not published |
| "asian mind" | 7 | census | 2 of 7 | 7 of 7 | strict misses are "Asian minds" |
| "asian opinion" | 38 | census | 38 of 38 | 38 of 38 | |
| "people to people" | 61 | census | 3 of 61 | 61 of 61 | hyphenated in print |
| "anti american" | 508 | sample 40 | 0 of 40 | 40 of 40 | always hyphenated |
| "oriental mind" | 14 | census | 14 of 14 | 14 of 14 | [M8] |
| "lose face" | 67 | census | 50 of 67 | **53 of 67 = 0.79** | below 0.80: UNUSABLE as published (misses are "losing face", "loss of face"); not used in the overview |

**False-friend test for "oriental mind" [M9].** Corpus-wide, apparatus excluded: 25 documents in 24
volumes (`SELECT COUNT(*), COUNT(DISTINCT c.volume_id) … MATCH '"oriental mind"' AND c.is_front_matter=0 AND c.is_editorial_note=0`);
14 of those 25 fall in the 81 scope volumes, which hold 35,214 of the corpus's 312,169 non-apparatus
documents (about 1 in 9). The phrase is concentrated in the region's volumes, so it measures the question,
not the corpus. Control phrase "department of state": 94,049 documents in 552 volumes corpus-wide vs
14,755 in scope, i.e. about 1 in 6.4 in scope — near the scope's share of documents, as a baseline should be.
"asian mind": 7 of 13 corpus documents in scope. (Corpus queries in queries.log.)

## 4. Periodisation of C (regional part)

Script `scripts/core_audit_clean.py`, output `raw/core_audit_clean_out.txt`. Date: `document_dates.date_iso`
(the index's stored document date; NOT the volume's series year; I did not independently confirm it is the
`frus:doc-dateTime-min` attribute). Denominator: dated non-apparatus documents **in the 72 regional
volumes** (`SELECT substr(d.date_iso,1,3)||'0s', COUNT(*) FROM document_cache c JOIN document_dates d ON … WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND d.date_iso IS NOT NULL AND c.volume_id IN (<regional>) GROUP BY 1`),
not the corpus decade — a deliberate departure from the house rule, because the question is about the
region's volumes; a corpus-decade rate would mix in every other region's volume selection.

| decade | C (regional) | dated non-apparatus docs, regional vols | per 1,000 | top volume share of numerator |
|---|---|---|---|---|
| 1940s | 165 | 9,577 | 17.2 | frus1949v08 72 of 165 |
| 1950s | 382 | 12,112 | 31.5 | frus1955-57v21 34 of 382 |
| 1960s | 397 | 7,884 | 50.4 | frus1961-63v02 43 of 397 |
| 1970s | 104 | 3,370 | 30.9 | frus1969-76v08 19 of 104 |
| 1980s | 1 | 106 | 9.4 | frus1977-80v13 1 of 1 (too thin to read) [M10] |

Before the USI cleaning the 1940s rate was 331 of 9,577 (34.6 per 1,000) with frus1948v06 holding 93 of
331 — the Indonesian false friend had doubled the decade (`raw/core_audit_out.txt`). This density
includes editorial footnotes (body_text carries them); I have not separated apparatus from document text.

## 5. Archival channels (never summed)

Script `scripts/channels.py`, output `raw/channels_out.txt`. Set: C (1,401 documents, 80 volumes).
- came-from: `SELECT repository, record_group, lot_file_norm, series_name, citation_era FROM document_sources WHERE volume_id=? AND document_id=?`
- pointed-at: `SELECT repository, collection, lot_file_norm FROM external_citations WHERE volume_id=? AND document_id=?`

**Came-from [M11]** (1,401 of 1,401 have a row): Department of State RG 59 731; National Archives RG 306
(USIA) 177; Johnson Library 100; Nixon Presidential Materials 78; Kennedy Library 70; National Archives
RG 59 57; no repository 35; Eisenhower Library 28; Carter Library 24; RG 330 22. Citation form:
structured 596, decimal 484, lot_file 181, subject_numeric 91, named_series 25, cfpf 14, published 7,
foreign 2, unrecognized 1 (a citation form, not a date). Top named units: Nixon NSC Files 71; Johnson NSF
68; Kennedy NSF 42; RG 306 "Director's Subject Files" 24; lot 63D351 23; Carter NSA 19; RG 59 Central Files
1964–66 18; lot 62D430 11; lot 61D417 8; lot 61D385 7.

**Pointed-at [M12]** (390 of 1,401 documents carry at least one row; this channel stores the citation
fragment, lot/library/decimal anchors only, and has no row before 1910-12-06, irrelevant here): Department
of State (no lot, i.e. decimal files) 183 citing documents; Johnson NSF 27; Nixon NSC Files 25; lot 63D351
19; lot 66D95 19; Kennedy NSF 17; lot 62D430 16; lot 62D1 7.

**Resolved through bundled JSON** (`scripts/resolve_lots.py`, `raw/lots_resolved.txt`, `raw/rg306_resolved.txt`):

| unit | channel | resolves to (central-files-index -> series-facts-index) |
|---|---|---|
| lot 63D351 and lot 66D95 | came-from and pointed-at | RG 59, entry A1 1586E, NAID 2839192, "Records Relating to National Security Council Policy Papers", Executive Secretariat, 1947–1979, Restricted – Partly (FOIA (b)(1)), College Park |
| lot 62D430 | came-from and pointed-at | RG 59, entry A1 1586C, NAID 2839191, "Subject and Special Files", Executive Secretariat, 1953–1961, Restricted – Partly |
| lot 61D417 | came-from | RG 59, entry A1 1261, NAID 2103073, "Meeting Summaries and Project Files", 1951–1959, Unrestricted |
| lot 62D1 | pointed-at | RG 59, entries A1 1583E/F, NAID 2838992, "Records Relating to Activities with the NSC", Policy Planning Council, 1948–1961, Restricted – Partly |
| lot 59D260 (USIA/IOP files, cited unprinted in frus1955-57v09/d207) | pointed-at | RG 306, entries UD-WW 151 … 382, NAID 1257679, "Subject Files", USIA Office of Policy and Plans, 1953–1971 (coverage 1949–1971), 47 linear feet, Restricted – Partly |
| lot 70D398 (USIA/IOP/G Files, in volume-sources-index) | (volume-level only) | RG 306, entry P 311, NAID 40943515, "Alphabetical Subject Files Containing Policy Guidance Records", USIA Office of Policy, 1953–1969, Restricted – Partly |
| RG 306 accessions 72A5121, 69A3445, 67A222, 68A4933 (the USIA Director's and area files the PubDip volumes print from) | came-from | accession-series-index (key `306/<accession>`) fans each out to many series: 18, 9, 3 and 15 series respectively — NOT resolvable to one shelf from the bundle. 67A222 includes "Regional Subject Files" (NAID 48349732); 68A4933 includes "Subject Files of the Director" (NAID 1102141) and "Vietnam Working Group Subject Files" (NAID 42125423); none of those three has a series-facts row |
| lots 61D385, 63D224, 62D255, 60D322, 65F98, 62D181, 55D339 | various | NOT in central-files-index; lot-claimants and curated-lot-resolutions return no row |
| RG 306 overall | — | volume-sources-index `recordGroups['306']`: NAID 622, "Records of the U.S. Information Agency" |

Decimal file 511.51G/9–2052 (frus1952-54v13p1/d116) and 511.00/8–2352 (its footnote): document dated 1952,
inside the 1950–1959 glossable span of `decimal-class-labels.json`; class 5 = "International Informational
and Educational Relations, Cultural Affairs and Programs"; the subject digits and country 51G have no gloss
in the file; country 00 = "World, The" (`raw/decimal_511.txt`).

`collection-usage-index.json` over the 81 scope volumes (whole volumes, not the topic;
`raw/collection_usage_scope.txt`): Department of State central file 5,629 notes in 34 volumes; Nixon NSC
Files 1,839 in 16; Johnson NSF 1,290 in 19; Kennedy NSF 628 in 9.

**Pre-1940 note:** the scope begins in 1946, so the "offline stack barely reaches before 1940" caveat does
not bite; I did not re-derive the one-in-sixty figure.

## 6. Reading

Reading SELECT (`scripts/dump.py`): `SELECT header, coalesce(dateline,''), coalesce(source_note,''), body_text, length(body_text), is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?`.
**121 documents retrieved whole** (captured length = length(body_text) for 121 of 121, 1,518,807 characters;
check in queries.log), saved in `raw/docs/`. About 35 were read at length or in their relevant sections; the
92 hits of the audience-vocabulary query (`raw/audience_ids.txt`) were read only at the matching sentence
(`raw/docs` + inline sentence extraction). **23 documents quoted, 29 quotations.** Never read: summary_text, note_text.

Editorial headnotes and footnotes are interleaved in body_text (e.g. frus1917-72PubDipv07/d73 carries an
editor's paraphrase of Marks's memo); every quotation below was checked by reading its context to be the
document's own words, not the editor's.

### Quotations — verified (`scripts/verify_quotes.py`, output `raw/verify_quotes_out.txt`)
Verification SELECT: `SELECT instr(body_text, ?), length(body_text), is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?` — **29 of 29 found** [M13]. Texts in `raw/quotes.json`.

| id | pair | char offset / length | quotation |
|---|---|---|---|
| Q1 | frus1949v07p2/d386 | 7346/13086 | "A considerably expanded information program both in Communist and non-Communist areas of Asia is called for, both to demonstrate our understanding and sympathy for the nationalist aspirations of the Asian peoples and to expose the menace to these aspirations created by Soviet imperialism." |
| Q2 | frus1952-54v13p1/d116 | 3512/8958 | "Such demand can only be construed as intense interest in US by educated groups." |
| Q3 | frus1952-54v13p1/d116 | 4433/8958 | "Daily VM broadcasts maligning US effort AS go unanswered except for sporadic efforts by VOA which not timely nor too effective because of difficulty of reception with average type of radio receiver used here." |
| Q4 | frus1955-57v09/d190 | 5646/51295 | "In the Far East USIA was forced to deal with mixed emotions regarding the use of atomic weapons against Asiatic peoples, and to counter communist propaganda designed to stir up race hatred." |
| Q5 | frus1955-57v09/d207 | 39375/48892 | "Despite all efforts, the trend toward accommodation to Communist pressures in the area continued." |
| Q6 | frus1952-54v12p2/d403 | 7687/8401 | "It is recognized that Southeast Asia is not a political entity but that each nation is an entity basically different from the others and requires special treatment." |
| Q7 | frus1952-54v13p2/d992 | 18445/20615 | "In Asia give-away programs are too frequently mistaken in the oriental mind as meaning that the donor not only has a soft heart but also a soft head." |
| Q8 | frus1952-54v14p2/d551 | 6028/6225 | "we must by word and deed do everything within our power to overcome any feeling in the Oriental mind that our interest in Asia is casual, temporary or overshadowed by our interests in other regions." |
| Q9 | frus1952-54v12p2/d60 | 2289/3422 | "Bulk of Burmese people simply unable understand aid in terms of altruism." |
| Q10 | frus1958-60v01/d26 | 1600/6543 | "Not being Asians, Americans do not understand the Oriental mind and point of view." (Durbrow reporting Diem's conviction) |
| Q11 | frus1961-63v02/d29 | 1683/7806 | "American concepts, policies and capabilities do not always fit the oriental mind." (Martin reporting Diem and Thuan's views as presented by McGarr) |
| Q12 | frus1961-63v01/d265 | 3147/3369 | "But the spectre of charges that “U.S. imperialists are waging germ warfare on Asians” haunts me." |
| Q13 | frus1961-63v02/d197 | 3678/5869 | "Is it possible, for example, to laugh at the VC, to make them look ridiculous and thus lose face?" |
| Q14 | frus1917-72PubDipv07/d37 | 5835/30966 | "On the American side, these programs to affect what the Vietnamese people think must be given the same status, the same concern, the same adequacy of working resources, as our military and economic operations." |
| Q15 | frus1964-68v01/d197 | 6610/14277 | "The Committee believes that courage is contagious" (memo only; not in overview) |
| Q16 | frus1952-54v14p2/d820 | 4725/20124 | "Vigorous information programs have been carried on to give the Japanese a better understanding of the United States and of world problems and to combat leftist and neutralist influences." |
| Q17 | frus1917-72PubDipv06/d127 | 1153/3245 | "Glenn and his family, through the warmth and sincerity of their personalities and their genuine enthusiasm and friendliness, were effective demonstration of typical American virtues." |
| Q18 | frus1964-68v29p2/d46 | 7035/10516 | "Intellectually we have met with some success, and there is a growing awareness of the U.S. point of view, which has perhaps blunted the attack somewhat, but the basic emotional response remains unchanged and is probably unchangeable over the short run." |
| Q19 | frus1964-68v29p2/d46 | 1894/10516 | "Such simplistic attitudes are possible in Japan because of the ostrich-like pacifism of the Japanese during the past twenty years." |
| Q20 | frus1917-72PubDipv07/d73 | 2350/4186 | "In all cases, however, the image of American strength, reliability and friendship is basic to our objectives." |
| Q21 | frus1917-72PubDipv07/d73 | 2773/4186 | "In almost every country of the area, our programs are directed at elite groups: government officials, university and high school teachers, media representatives, top-level business executives." |
| Q22 | frus1917-72PubDipv08/d31 | 2803/20792 | "PAOs emphasized that the image of the US usually depended more on the state of bi-lateral relations (security treaty, Okinawa, Korean military modernization, trade restrictions) than on developments within the US." |
| Q23 | frus1917-72PubDipv08/d31 | 2386/20792 | "Asians are, to varying degrees, America watchers." |
| Q24 | frus1917-72PubDipv08/d31 | 8470/20792 | "One caveat: US visibility should be low." |
| Q25 | frus1917-72PubDipv08/d146 | 1841/3823 | "The President’s projected visit to Peking presents us with opportunities to build what is now a temporary psychological asset into a long-range one." |
| Q26 | frus1917-72PubDipv08/d149 | 1643/10253 | "Thus, we are compelled to take a very close look at the overseas Chinese as a USIS audience." |
| Q27 | frus1969-76v38p2/d105 | 6844/11622 | "We should focus our programming on the benefits accruing from the end of our involvement; hoping that we have all learned the lesson that America is not omnipotent and that other nations cannot rely on Uncle Sam to do what they should be doing themselves." (USIS Singapore's reply, abstracted) |
| Q28 | frus1969-76v38p2/d105 | 7587/11622 | "Confidence in US economic power, technological and scientific capability, and our leadership role in seeking solutions for world economic and social problems remains." (USIS Kuala Lumpur, abstracted) |
| Q29 | frus1977-80v30/d2 | 6027/6124 | "We are dealing here with gut issues rather than some of the frothier aspects of cultural exchange." |

### The 23 documents (collection; per-document channels in `raw/collection_channels.txt`)
All 23 verified to exist with apparatus flags 0 (`SELECT 1 FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0` -> 23 of 23, 23 distinct) [M14]. No Ed2 volume.
Came-from per document: RG 59 decimal (d386 711.90; d116 511.51G; d403 790.5; d551 795.00; d60 890B.00 TA; d992 751G.00; v02/d29 751K.5-M SP); RG 59 lot 63D351 (v09/d190, v09/d207, v14p2/d820); RG 84 lot 65F98 (v01/d26) and RG 84 Saigon Embassy Files FRC 67 A 677 (v02/d197); RG 306 (v01/d265 FRC 67 A 222; PubDipv07/d37; PubDipv07/d73 acc. 69A3445; PubDipv08/d31 Office of Policy and Plans, entry P-207; PubDipv08/d146 and d149 Director's Subject Files entry A1-42; 1977-80v30/d2 entry P-104); RG 59 Central Files 1964–66 POL 27 VIET S (v29p2/d46); Johnson Library NSF (1964-68v01/d197); Kennedy Library, RFK papers (PubDipv06/d127); and frus1969-76v38p2/d105, which the parse stores as RG 305 — the printed note reads "RG 305, Records of the USIA", evidently a misprint for 306 in the volume, but I report it as stored.
Pointed-at: only v09/d207 (lots 59D260, 63D224, 62D255, 62D430, 60D322), v09/d190 (3 decimal rows), d116, d992, v02/d29 (1 decimal row each).

## 7. Findings (operator form)

1. 1949–57, the information program is framed as aligning the US with Asian nationalism against communism
   (Q1, frus1949v07p2/d386), country-by-country (Q6, frus1952-54v12p2/d403), and assessed as uphill: Q4
   (frus1955-57v09/d190), Q5 (frus1955-57v09/d207); posts measured reach (film audiences, library attendance,
   English-class waiting lists) and read it as interest, while conceding the rural majority was not a target
   (Q2, Q3, frus1952-54v13p1/d116).
2. Beliefs about the audience: a stock vocabulary of "the Oriental mind" (14 documents in scope [M8]) — aid
   read as weakness (Q7), doubts about US staying power (Q8), inability to read aid as altruism (Q9); by 1958–62
   the same phrase is used by Diem's government against the Americans (Q10, Q11).
3. Vietnam: information as a weapon of the war and a regional liability (Q12, Q13, Q14).
4. Japan and the elite model: OCB 1954 (Q16), Glenn 1963 (Q17), Reischauer 1965 (Q18, Q19), area-wide
   elite targeting and the "image of American strength" (Q20, Q21), the 1969 Manila PAO conference (Q22–Q24).
5. Credibility after the opening to China and the fall of Saigon (Q25–Q28) and the turn to Japan as a
   partner in "communication" among industrialised democracies (Q29).

## VECTORS

Script `scripts/vectors.py` (output `raw/vectors_out.txt`) and `scripts/neardup.py` (output `raw/neardup_out.txt`).
Artifacts: `semantic-vectors-index.json` (generated 2026-10-15, harvestGenerated 2026-10-15T06:55:14),
`semantic-vectors-binary.bin`, `semantic-map.bin`, `semantic-map-index.json`, Tier-2 shards in
`/Users/jbotts/frus-analysis/c3/SemanticVectors/` (`.generation` = 89481b18…).

- **Digest check:** index `provenanceDigest` = binary header @20 = map header @20 =
  `89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101`; each shard opened was asserted equal
  at header @16 (no assertion failed). Id decode round trip: 553 of 553 volumes; 314,616 documents, 512 dims.
- **Baselines at this digest:** random pairs (random.Random(1877), 20,000 draws, self-pairs skipped):
  mean 167.1, sd 14.8, 1st percentile 132, minimum 95. 25th-nearest-neighbour distance over 200 random
  documents (random.Random(1878)): median 107, quartiles 99 and 114. Retrieval recall@10 (index's
  `retrieval.measuredRecallAt10`) = 0.9021, so about one true neighbour in ten is missed.
- **Nearest neighbours of a document** (Hamming top 800, reranked by Tier-2 int8 cosine; cosines shown raw and
  calibrated as (cos − 0.40)/0.60 per `retrieval.scoreCalibration.documentOffset`):
  - anchor frus1917-72PubDipv08/d31 (Oleksiw 1969): frus1917-72PubDipv07/d106 Hamming 81 (raw 0.920, cal. 0.867);
    frus1969-76v38p2/d105 96 (0.917/0.862); frus1917-72PubDipv08/d99 90 (0.915/0.858); frus1955-57v09/d190
    100 (0.908/0.847); frus1951v06p2/d105 94; **frus1952-54v13p1/d116 88 (0.906/0.843)**; frus1955-57v09/d185;
    frus1961-63v25/d156; frus1917-72PubDipv06/d150; frus1917-72PubDipv07/d69. All at or below the
    25th-neighbour median (107), far below the random-pair mean (167). All volumes are in this index (553 of 553).
  - anchor frus1964-68v29p2/d46 (Reischauer 1965): ten Japan documents, Hamming 94–125, all in map cluster 7
    (`japanese, sato, japan, kishi`), e.g. frus1958-60v18/d203 94; one outside, frus1931-41v02/d12 125 —
    not read.
  - anchor frus1952-54v13p2/d992 (McClintock 1954): Indochina documents 71–84, cluster 31 (`indochina, minh, bao, dai`); not read.
- **The map:** anchors' clusters — d31 unclustered (0xFFFF); d46 cluster 7; d992 cluster 31. Most of d31's
  neighbours sit in cluster 138 (`cia, nsc, usia, inglis`, 2,189 documents). Used to describe, not measure.
- **Near-duplicates:** nearest corpus neighbour of each of the 23 collection documents: minimum 32 bits
  (frus1955-57v09/d190 to frus1955-57v09/d185, the March 1955 report in the same annual NSC status-report
  series — NOT read, so "reprint" is not established; it is not in the collection); all others 49–123.
  Minimum pairwise within the collection: 50 (v09/d190 vs v09/d207). No document in the collection is a
  reprint of another in it.
- **Centroid similarity:** none.
- **Semantic join:** none.
- **Reached through a vector operation:** frus1952-54v13p1/d116 (Heath, 1952) — found as the 6th reranked
  neighbour of Oleksiw's 1969 letter, then read. It is also in the full-text core set C, so **no document in
  the overview was reached through no full-text query.** Similarity is reported as a lead; the claim about
  d116 rests on reading it.

## 8. Threads not followed (for the overview's closing)
- The other posts' 1952 replies to Department circular 208 on the effectiveness of information programs:
  only Saigon's is printed (`MATCH '"circular telegram 208"'` -> 1 document, frus1952-54v13p1/d116; relaxed
  `'"circular telegram" AND 208'` -> 11) — the rest are in RG 59 decimal file 511.00 (1950–54).
- USIA's own East Asia country plans, PAO conference transcripts (the 60-page Manila 1969 report) and
  public-opinion surveys (Office of Research) — RG 306, unresolvable to a series from the bundle.
- 1981–88 volumes; Korea, Philippines, Indonesia, Australia/New Zealand were sampled only through
  regional reports.
- The 1975 post cables themselves (d105 notes "The cables were not found attached").

## TRACE TABLE (overview item -> memo line)

| overview item | memo source |
|---|---|
| 553 volumes in the index | §0 [M0] |
| 81 volumes, ~35,000 documents in scope | §1 [M2] |
| "soft power" absent; "soft" in 345 docs | §1 [M1], [M1b] |
| ~1,400 documents on the information program (C = 1,401 in 80 volumes) | §1 [M5] |
| Indonesia false friend removed (172 dropped, 166 "USI") | §1 [M4], [M5] |
| controls: "Department of State" in every scope volume; impossible term zero | §2 [M7], [M7b] |
| density rising to about 1 in 20 in the 1960s (50.4 per 1,000), ~1 in 30 in 1950s/1970s, ~1 in 60 in 1940s | §4 [M10] |
| "Oriental mind" in 14 scope documents, 14 of 25 corpus-wide | §3 [M8], [M9] |
| came-from: about half State RG 59 (731+57 of 1,401), about 1 in 8 USIA RG 306 (177) | §5 [M11] |
| pointed-at: 390 of 1,401 carry a citation | §5 [M12] |
| lots 63D351/66D95, 62D430, 62D1, 59D260, 70D398 resolutions | §5 table |
| decimal class 5 gloss for 511.x | §5 |
| circular 208: only one reply printed | §8 |
| 23 documents, 29 quotations verified | §6 [M13], [M14] |
| Heath 1952 reached by vector neighbour of Oleksiw 1969 | VECTORS |
| Q1–Q14, Q16–Q29 | §6 quotation table (Q15 is memo-only) |
| "more than half" from State RG 59 | §5 [M11]: 731 + 57 = 788 of 1,401 |
| "about one in eight" from RG 306 | §5 [M11]: 177 of 1,401 |
| "about one document in four" carries a citation | §5 [M12]: 390 of 1,401 |
| "Oriental mind": 14 in scope, more than half of 25 series-wide; scope holds about one document in nine | §3 [M8], [M9]: 14 of 25; 35,214 of 312,169 |
| RG 306 accessions split across "3 to 18 series" | §5 table: 3, 9, 15, 18 |
| 121 read whole, 23 quoted | §6 |
| Q30 (OCB 1954, "a serious increase in neutralist sentiment") | §6 addendum below |

### Addendum (written after the overview draft)
- **Q30** frus1952-54v14p2/d820, char 5684 of 20124: "there have arisen a serious increase in neutralist sentiment, periodic flare-ups of anti-Americanism and an intensification of communist overtures to Japan." Verified by `scripts/verify_quotes.py` rerun: **30 of 30** (`raw/verify_quotes_out.txt`).
- **Overview quotation check** (`scripts/check_overview_quotes.py`, `raw/check_overview_quotes_out.txt`): every double-quoted span in overview.md, split on " … ", searched case-sensitively in the body_text of the 23 collection documents: 52 of 62 spans found. The 10 not found are not document quotations: "soft power" (3), "messaging" (the question's word), the collection's title, and five archival series titles/class labels quoted from the bundled JSON (`raw/lots_resolved.txt`, `raw/rg306_resolved.txt`, `raw/decimal_511.txt`). One overview fragment that failed on case ("a considerably…") was rewritten to quote Q1's opening verbatim.
- **Citation coverage:** documents cited in overview.md (by history.state.gov URL) = 23; all 23 are in the collection; none of the collection is uncited.
- **Collection** (`scripts/make_collection.py`): 23 documents, 29 excerpts (every quotation the overview relies on: Q1–Q14, Q16–Q30; Q15 is memo-only), each pair asserted present with apparatus flags 0, no duplicate pair, no Ed2 volume, each excerpt asserted by `instr(body_text, ?) > 0`.
