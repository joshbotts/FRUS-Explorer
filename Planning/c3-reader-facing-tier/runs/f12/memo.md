# Scope memo: run f12, 2026-10-31

Question: how policymakers assessed American soft power in East Asia and the Pacific; the messaging strategies they used; how effective they thought those strategies were; and what beliefs about the regional audience shaped them.

Run directory: /Users/jbotts/frus-analysis/c3f/runs/f12. Database: /Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db, opened read-only through `scripts/q.sh` (`sqlite3 -readonly`), which logs every SQL line to `queries.log`. The Python scripts open it with `?mode=ro`. Each section has a line id (M-n) so the trace table at the end can point to it.

## M-1 Coverage, and proof that the copy is read-only

```
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;
-> 553|321749|1103|8481
```
- The index holds all 553 volumes of the series: 321,749 rows, 1,103 front-matter rows and 8,481 editorial notes. Every count below is conditional on this 553-volume index.
- The read-only proof (`BEGIN; CREATE TABLE zz(x); ROLLBACK;` under `-readonly`) failed with "attempt to write a readonly database", rc=1.

## M-2 How the scope was found

1. **Volumes.** A manifest title scan (inline python; output in `out/manifest_candidates.txt`) found:
   - seven information and public-diplomacy volumes: frus1917-72PubDipv06, frus1917-72PubDipv07, frus1917-72PubDipv08, frus1955-57v09, frus1961-63v25, frus1969-76v38p2 and frus1977-80v30;
   - the East Asia area volumes, 1942–1980.
2. **Chapter headings.** `scripts/chapters.py` read `volume_structures`. The public-diplomacy volumes are arranged by date only, so they gave no subject vocabulary.
3. **A broad probe, not used for the argument.** An information-words AND Asia-words MATCH across the corpus returned China-volume "propaganda" (the Communist side's) at the top (`out/info_asia_by_vol.txt`). It was too broad and was set aside. Its SQL is the first line of queries.log containing `GROUP BY d.volume_id ORDER BY 2 DESC LIMIT 45`: MATCH '(usia OR usis OR propaganda OR "psychological warfare" OR "psychological strategy" OR "psychological operations" OR "information program" OR "voice of america" OR "public affairs" OR "image of the united states" OR "cultural exchange") AND (asia OR asian OR "far east" OR japan OR … OR chinese)', with is_front_matter=0 AND is_editorial_note=0, GROUP BY volume_id.
4. **SCOPE SET A (the header family).**
   ```
   SELECT d.volume_id, d.document_id, dd.date_iso, d.header, length(d.body_text)
   FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
   LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
   WHERE frus_documents MATCH 'header:(asia OR asian OR "far east" OR japan OR japanese OR vietnam OR vietnamese OR korea OR korean OR philippines OR indonesia OR thailand OR burma OR laos OR cambodia OR malaya OR pacific OR china OR chinese OR okinawa OR australia)'
     AND d.volume_id IN ('frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1977-80v30','frus1961-63v25','frus1955-57v09','frus1969-76v38p2')
     AND d.is_front_matter=0 AND d.is_editorial_note=0 ORDER BY dd.date_iso;
   ```
   - This returns 42 hits (`out/core_headers_full.txt`) out of 1,582 non-apparatus documents in the seven volumes. The 1,582 comes from `SELECT COUNT(*) FROM document_cache WHERE volume_id IN (the seven) AND is_front_matter=0 AND is_editorial_note=0`.
   - Removing South Asia and Near East headings (frus1955-57v09/d131, frus1917-72PubDipv07/d74, frus1917-72PubDipv08/d74, d87, d106, d155, frus1977-80v30/d15, d74, d170) leaves **33 documents** (`scope_set_info_volumes.txt`). The 9 dropped were found by `comm`.
   - Literal share, which is a census because 42 is under 300 (`scripts/literal_share.py` → `out/literal_share.txt`). The test is Python `re` with IGNORECASE over the header column, whitespace-collapsed, since the MATCH was on the header column. **TOLERANT 42 of 42; STRICT 42 of 42.**
   - Referent test, made separately because a 1.000 share only tests the index's word-folding: reading the 42 headings, **33 of 42** concern East Asia or the Pacific. The 9 misses are "South Asia" or "Near East" offices that the word "Asia" also matches.
5. **SCOPE SET B (area volumes, headings).** The same MATCH form with `header:(psychological OR propaganda OR "information agency" OR usia OR usis OR "information program" OR "public affairs" OR "information policy" OR "cultural")` ran over the East Asia area volumes and all frus1961-63v0* and frus1964-68v0* volumes. The full volume list is in queries.log.
   - It returned 55 hits (`out/area_info_headers.txt`).
   - 40 of the 55 are in Vietnam volumes (frus1961-63v01–v04, frus1964-68v01–v07, frus1955-57v01, frus1958-60v01, frus1952-54v13p1/p2). Of those, 31 of the 55 are in frus1961-63v01–v04: v01 5, v02 12, v03 9, v04 5. Counted with `grep -c` and `uniq -c` over that file.
   - The other 15 come from volumes the `LIKE 'frus1961-63v0%'` clause also swept in (v05, v07, v09) and from the regional volumes.
6. **SCOPE SET C (area volumes, ranked).** The MATCH `'"united states information agency" OR usia OR usis OR "information program" OR "psychological" OR "image of the united states" OR "american image"'` over 16 regional volumes, ORDER BY bm25 ASC LIMIT 30, is in `out/area_bm25_top30.txt`. It surfaced the 1953 Thailand psychological-strategy cluster (frus1952-54v12p2/d401, d403, d405, d407) and the 1955 Malaya cluster (frus1955-57v22/d447, d448).
7. **Vector addition.** One document was added by vector search alone: frus1952-54v13p1/d116 (see VECTORS).

**Inclusion rule used in the meantime.** A document is in the argument if it is an assessment, plan or instruction about U.S. information, cultural, psychological or public-diplomacy work aimed at East Asian or Pacific audiences, and I read it. It is excluded if it is mainly about press relations in Washington, UN negotiation, internal reporting procedure or South Asia.

**Date span.** 1950-03-28 to 1977-08-01, by `document_dates.date_iso` (the document's own date, not the volume year).

## M-3 Reading accounting

`scripts/dump.py` ran `SELECT header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?` for `reading_list.txt` (37 pairs) and `reading_list_vectors.txt` (3 pairs). The raw text is in `raw/<vol>__<doc>.txt` and the lengths in `out/reading_lengths.tsv`.

- **Retrieved whole: 40 of 40.** Captured length equals length(body_text) for every one. Total 300,743 characters of body_text.
- **Read in full: 29.** frus1950v06/d31; frus1952-54v12p2/d403, d405, d407; frus1955-57v22/d447; frus1961-63v23/d289; PubDipv06/d111, d112, d127; frus1961-63v25/d431; PubDipv07/d171; frus1964-68v26/d106; frus1964-68v27/d386; PubDipv08/d24, d58, d88, d92, d121, d127, d143, d146; frus1969-76v19p2/d67; frus1969-76v38p2/d105, d121; frus1977-80v30/d2, d79, d81, d83; frus1952-54v13p1/d116.
- **Read in part: 7.**
  - PubDipv07/d73: the first 3,800 of about 4,400 collapsed characters.
  - PubDipv07/d32: the first 12,000 of 27,974.
  - PubDipv08/d31: the first 11,000 of 20,792.
  - PubDipv08/d149: the first 6,500 of 10,253.
  - frus1955-57v22/d448, frus1958-60v16/d65 and frus1955-57v22/d275: passage search only (grep -o for USIA, information, psycholog, propaganda, image and prestige, ±250 to 300 characters).
- **Retrieved but not read: 4.** frus1952-54v12p2/d401, frus1961-63v02/d16, frus1964-68v01/d197 and frus1977-80v30/d152.
- **Quoted: 38 quotations from 25 documents** (`quotes.json`). Of the 26 collection documents, only frus1977-80v30/d81 is unquoted.

**Retrieved but set aside as off-topic after reading:**
- frus1961-63v25/d431 (outer-space resolution);
- frus1969-76v38p2/d121 (reporting procedure);
- PubDipv06/d111 (press relations in Saigon);
- PubDipv06/d112 (a harder line in Laos);
- PubDipv08/d24 (Midway image objectives, a close call);
- PubDipv08/d121 (nation-building guidance, mostly about Latin America);
- PubDipv08/d127 (worldwide media).

## M-4 Quotations: retrieval and verification

The quotations were retrieved by `scripts/dump.py` (SELECT above) and verified by `scripts/verify_quotes.py`:
```
SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0
test: quote is an exact substring of the raw body_text (no whitespace or case folding)
```
Result (`out/quote_verification.txt`): **38 of 38 exact (not-raw: 0 of 38).**

| # | pair | quotation (verbatim) |
|---|---|---|
| Q1 | frus1950v06/d31 | There is already evidence, however, of increased usage of USIE news and feature material in the local press throughout the area. |
| Q2 | frus1952-54v12p2/d403 | utilizing every suitable operation to prepare the minds and emotions of the people to collaborate in the effort |
| Q3 | frus1952-54v12p2/d403 | It is recognized that Southeast Asia is not a political entity but that each nation is an entity basically different from the others and requires special treatment. |
| Q4 | frus1952-54v12p2/d405 | Must strengthen “will and ability of Thai people resist Commie aggression” |
| Q5 | frus1952-54v12p2/d407 | informing Thai of threat to monarchy, religion, tradition of independence |
| Q6 | frus1955-57v22/d447 | a fear of placing the U.S. in the position of appearing to support colonialism |
| Q7 | frus1961-63v23/d289 | we should refrain from glamorous, immediate-impact actions |
| Q8 | frus1961-63v23/d289 | any actions the U.S. undertakes in furtherance of better relations with Indonesia must be pegged to a real understanding of and a demonstrated respect for Indonesia’s neutral stance |
| Q9 | frus1917-72PubDipv06/d127 | probably the most successful visit by an American, from a public image standpoint |
| Q10 | frus1917-72PubDipv06/d127 | Many seemed, for first time, to appreciate openness of the U.S. space program as compared to Russian. |
| Q11 | frus1917-72PubDipv07/d32 | Vietnamese peasants are, in the main, going to be persuaded by other Vietnamese. |
| Q12 | frus1917-72PubDipv07/d32 | family-oriented, selfish and opportunistic even in the best of times |
| Q13 | frus1964-68v26/d106 | Anti-American activities in Indonesia, particularly those directed against USIS during the last six months, have created a situation that I can describe only as intolerable. |
| Q14 | frus1917-72PubDipv07/d73 | the image of American strength, reliability and friendship is basic to our objectives |
| Q15 | frus1917-72PubDipv07/d73 | In almost every country of the area, our programs are directed at elite groups |
| Q16 | frus1917-72PubDipv07/d171 | the effort should not be construed as a propaganda mechanism |
| Q17 | frus1964-68v27/d386 | The Thai Government has not given proper attention to the need for a national information program designed to gain popular support. |
| Q18 | frus1917-72PubDipv08/d31 | Asians are, to varying degrees, America watchers. |
| Q19 | frus1917-72PubDipv08/d31 | PAOs emphasized that the image of the US usually depended more on the state of bi-lateral relations (security treaty, Okinawa, Korean military modernization, trade restrictions) than on developments within the US. |
| Q20 | frus1917-72PubDipv08/d31 | One caveat: US visibility should be low. |
| Q21 | frus1917-72PubDipv08/d58 | USIA has, from the beginning, considered its psychological operations (PSYOP) support program in Viet-Nam as short-term in nature. |
| Q22 | frus1917-72PubDipv08/d88 | Rating of the U.S. as a dependable ally of SVN reached the lowest point in thirteen Saigon surveys |
| Q23 | frus1917-72PubDipv08/d92 | The Cambodians want to do as much as possible on their own and we should respect that desire. |
| Q24 | frus1969-76v19p2/d67 | public opinion surveys and other assessments of Japanese attitudes have tended to confirm the seriousness of these strains |
| Q25 | frus1917-72PubDipv08/d143 | While we do not want to appear as having gone “soft” on Chinese Communism neither do we want to appear anti-Chinese or anti-Peking. |
| Q26 | frus1917-72PubDipv08/d146 | by virtue of immense Chinese interest and curiosity about space, could generate favorable opinion toward the U.S. and its scientific accomplishments |
| Q27 | frus1917-72PubDipv08/d149 | Although the overseas Chinese appear proud of the achievements of Peking, they are reluctant to accept communist political and economic models. |
| Q28 | frus1969-76v38p2/d105 | The American defeat has been in good part written off by the Japanese since the US withdrawal two years ago. |
| Q29 | frus1969-76v38p2/d105 | During this waiting period, programs on U.S. security relations in Asia lack credibility and may in fact do damage to our relations. |
| Q30 | frus1969-76v38p2/d105 | Thais still see us as friends and admire much in the American system. |
| Q31 | frus1977-80v30/d2 | We are dealing here with gut issues rather than some of the frothier aspects of cultural exchange. |
| Q32 | frus1977-80v30/d79 | shoring up the confidence of East Asians in America’s long-term staying power and positive involvement in the area is real and necessary |
| Q33 | frus1977-80v30/d83 | We still face deeply implanted and persistent feeling that new administration is “withdrawing” or, at least, “reducing priority” in East Asia. |
| Q34 | frus1977-80v30/d83 | seeks to implant American models on other societies |
| Q35 | frus1952-54v13p1/d116 | Such demand can only be construed as intense interest in US by educated groups. |
| Q36 | frus1952-54v13p1/d116 | It should deliberately soft-pedal suggestions which may be expected to foster anti-Fr attitudes or to stimulate unbridled nationalism. |
| Q37 | frus1952-54v13p1/d116 | Since many new customs FE can be traced to Amer films, must be assumed that films is effective program though difficult to determine degree. |
| Q38 | frus1952-54v13p1/d116 | Rural and village populations which make up as much as 80 percent of the 12 million in the non- VM zone are not a primary target group. |

The overview quotes fragments of these, joined with "…" where it elides. `scripts/check_overview.py` (output in `out/overview_check.txt`) tests every straight-quoted span of the overview against this list.
- **39 quoted spans, 0 unverified.**
- The spans that are terms or names rather than quotations from documents are listed separately in that file: "soft power", "RG 305", "Restricted - Possibly", "Department of State", "the region", "image of the United States", "psychological", "public diplomacy", "Public Opinion Research" and the collection title.

## M-5 TEI vocabulary scan with controls

**Script:** `scripts/tei_scan.py` writes `out/tei_scan.tsv`; per-million rates come from `scripts/rates.py` and are in `out/rates.txt`.

**Counting surface:** raw TEI with every tag stripped, HTML entities unescaped, and whitespace collapsed. The count runs over the WHOLE FILE, so apparatus (front matter, footnotes, index) is NOT separated from document text. The regexes are Python, case-insensitive.

**Volumes (21):**
- the 7 information volumes;
- 14 East Asia area volumes: frus1950v06, frus1952-54v12p1, frus1952-54v12p2, frus1955-57v21, frus1955-57v22, frus1958-60v16, frus1961-63v22, frus1961-63v23, frus1964-68v26, frus1964-68v27, frus1969-76v19p2, frus1969-76v20, frus1969-76ve12 and frus1977-80v22.

**Controls, run in the same pass:**
- POSITIVE "Department of State" was nonzero in **21 of 21** volumes: 2,023 occurrences in the information volumes and 8,351 in the area volumes.
- NEGATIVE "ZZZ_IMPOSSIBLE_ZZZ" was **0 in 21 of 21**.

| family (regex in script) | information vols (7; 12,259,751 chars) | area vols (14; 34,944,488 chars) |
|---|---|---|
| soft power `\bsoft[\s\-]+power\b` | 0 (0 of 7 volumes) | 0 (0 of 14) |
| image of US, both orders | 45 = 3.67 per million chars (7 of 7 volumes) | 7 = 0.20 per million (6 of 14) |
| psychological\w* | 438 = 35.73 per million | 577 = 16.51 per million |
| propaganda\w* | 441 = 35.97 per million | 640 = 18.31 per million |
| public diplomacy | 342 = 27.90 per million (5 of 7 volumes; frus1977-80v30 alone has 247) | 1 = 0.03 per million |

Notes on the table:
- The split for "image of US" is in the TSV. In the information volumes it is: "U.S./American image" form 6+7+3+0+0+2+7 = 25, and "image of the United States/America" form 5+3+2+1+2+5+2 = 20.
- **Variant split, all families:** the per-variant regexes are in the script. The USIA/USIS acronym outnumbers the spelled name in every information volume (for example PubDipv07: 1,003 acronym against 337 spelled). The acronym-form PSYOP/psywar family occurs only in PubDipv07 (43) and PubDipv08 (35) among the information volumes.
- **False-friend test.** "Soft power", the question's own term, is absent everywhere, so it cannot be used to search. "Image of the United States" runs at about 18 times its area-volume rate in the information volumes (3.67 against 0.20 per million), so it measures the topic and not the corpus. "Public diplomacy" partly measures the volumes' own titles and running heads, because apparatus is not separated. It was not used as an argument term. "Propaganda" in the area volumes mostly names the Communist side's output (read in M-2 step 3), so it was not used to scope.

## M-6 Absence and coverage checks

- **No volume after 1980 on this subject.** An inline python manifest filter on ids beginning frus1981 or frus1989 found **14** volumes; titles matching public diplomacy, asia, china, japan, korea or information: **none printed (0 of 14)**. The positive check for this filter is the earlier scan of the same file, which returned the matching 1942–1980 titles.
- **Surveys.** The FTS MATCH `'(survey OR poll OR "public opinion") AND (usia OR usis OR "information agency") AND (asia OR asian OR "far east" OR japan OR japanese OR vietnam OR vietnamese OR korea OR thailand OR indonesia OR philippines)'`, with apparatus excluded, returned **320** documents corpus-wide. The top volumes were PubDipv08 22, PubDipv07 21, frus1977-80v30 17 and PubDipv06 10.
  - The negative control MATCH 'zzzimpossiblezzz' returned 0.
  - No literal-share test was run on this family and it is **not published in the overview as a count**. The overview says only that surveys are summarised in some documents, which rests on reading frus1917-72PubDipv08/d88 and frus1969-76v19p2/d67.

## M-7 Archival channels (labelled; never summed)

**COLLECTION, CAME-FROM channel** (document_sources, 26 documents):
```
WITH s(v,d) AS (VALUES <25 pairs from collection_set.txt; the 26th, frus1952-54v13p1/d116, queried separately>)
SELECT ds.volume_id, ds.document_id, ds.repository, ds.record_group, ds.lot_file_norm, ds.series_name, ds.citation_era, substr(ds.raw_text,1,160)
FROM s JOIN document_sources ds ON ds.volume_id=s.v AND ds.document_id=s.d
```
The output is in `out/came_from.txt`. The d116 row came from a separate SELECT on that pair.

- RG 306 (National Archives), by Entry, from raw_text:
  - A1–42, Director's Subject Files 1968–1972: **5** (PubDipv08/d58, d88, d92, d146, d149);
  - UD WW 257: **1** (PubDipv07/d32);
  - UD WW 193: **1** (PubDipv07/d73);
  - P–207: **1** (PubDipv08/d31);
  - P–104: **2** (frus1977-80v30/d2, d79).
- "RG 305, Records of the USIA", Entry UD–UP 7: **1** (frus1969-76v38p2/d105). Record group 305 is as printed in the source note; its FRC accession number begins 306, so it is probably a misprint for RG 306. This is not corrected in the overview, only flagged ("which the edition prints as 'RG 305'").
- RG 59 decimal: **6 documents** under five decimal files: frus1950v06/d31 511.90; frus1952-54v13p1/d116 511.51G; frus1952-54v12p2/d403 790.5; d405 792.5 MSP; d407 792.5 MSP; frus1961-63v23/d289 611.98. The overview names the five files and gives no document count.
- RG 59 lot 61D385: **1** (frus1955-57v22/d447).
- RG 59 CFPF: **2** (frus1977-80v30/d81, d83).
- Presidential libraries: **6**. Kennedy Library, RFK papers, 1 (PubDipv06/d127). Johnson Library: NSF 2 (frus1964-68v26/d106, frus1964-68v27/d386) and Marks Papers 1 (PubDipv07/d171). Nixon Presidential Materials, NSC Files: 2 (PubDipv08/d143, frus1969-76v19p2/d67).
- Total 5+1+1+1+2+1+6+1+2+6 = 26.

**COLLECTION, POINTED-AT channel** (external_citations), same VALUES list:
```
SELECT ec.volume_id, ec.document_id, ec.anchor, ec.repository, ec.collection, ec.lot_file_norm, ec.file_id, ec.decimal_class, substr(ec.raw_text,1,120) FROM s JOIN external_citations ec ON ...
```
The output is in `out/pointed_at.txt`. **5 rows from 4 documents:**
- lot 61D385 and lot 58D726, both from frus1955-57v22/d447;
- Johnson Library Marks Papers (PubDipv07/d171);
- Nixon Kissinger Office Files Box 86 (PubDipv08/d143);
- Johnson Library NSF Country File Indonesia (frus1964-68v26/d106).

The d116 pair has 1 row (`SELECT COUNT(*) FROM external_citations WHERE volume_id='frus1952-54v13p1' AND document_id='d116'` → 1). Its content was not printed, so it is not in the overview. **OMISSION, declared.**

Caveat: this channel holds lot, library and decimal anchors only, stores the citation fragment and not the sentence, and has no row before 1910-12-06.

**SCOPE SET A (33 docs), both channels** (`out/scope_came_from.txt`, `out/scope_entries.txt`, `out/scope_pointed_at.txt`):
- Came-from: RG 306 entries are A1–42 ×7, UD WW 193 ×3, UD WW 257 ×3, P–104 ×2, and P–100, P–207, A1–31, UD WW 288 and UD–264 ×1 each. There is also RG 305 [sic] UD–UP 7 ×1.
- Pointed-at: 3 rows (Marks Papers; Kennedy Library NSF; Kissinger Office Files).

**JSON resolution** (`scripts/archival_resolve.py` → `out/archival_resolve.txt`; `scripts/archival_resolve2.py` → `out/archival_resolve2.txt`; `scripts/decimal_gloss.py`):
- **collection-authority.json** (`collections` list) recognises "Director’s Subject Files" (RG 306), "Office of Policy and Plans" (RG 306), "DIRCTR Subj Files" (RG 306), "Associate Directorate for Programs" (RG 306, Entry P-100) and "General Records Relating to the Joint U.S. Public Affairs Office (JUSPAO), 1966–1975 (Entry A1–31)". **None carries a naId**, so series-facts cannot be reached for them, and the overview says this.
- **lot:61D385** "OCB Files: Lot 61 D 385", RG 59: no naId in the authority row. **central-files-index.json** `lotFiles` (a list keyed on `lotNumber`) has **no row for 61D385**. It has one for **58D726**: naId 2544398, HMS/MLR entry "UD 53", title "Subject Files", matchType control.
- **series-facts-index.json** `byNaId["2544398"]`, decoded through `legend`, gives:
  - creator: "Department of State. Bureau of Far Eastern Affairs. Office of Southeast Asian Affairs. Office of the Officer in Charge for Malaya Affairs.";
  - accessStatus "Restricted - Possibly" and useStatus "Restricted - Possibly";
  - extent "5 linear inches";
  - inclusive 1955–1956.
  - The creator heading was checked against the lot's own title in authority ("SEA Files"; child "Subject files of the Office of Southeast Asian Affairs for the years 1955–1956"); they agree.
- **decimal-class-labels.json.** The gate `coverage.glossableYears` is 1910–1949, 1950–1959 and 1960–1963, and every key below was glossed inside its document's year:
  - 511.90 (1950): class 5 "International Informational and Educational Relations, Cultural Affairs and Programs", country 11 United States, second number 90 = Asia;
  - 511.51G (1952): class 5, 51g = Indochina (Annam, Cambodia, Cochin China, Laos, Tonkin, Vietnam) from `countryAlternates`;
  - 790.5 (1953): class 7 "Internal Political and National Defense Affairs", 90 = Asia;
  - 792.5 (1953): class 7, 92 = Siam;
  - 611.98 (1962): class 6 "International Political Relations…", 98 = Java (Indonesia).
  - The ".5" subdivision has no gloss: the `subjects` dict is empty, so "defence affairs" in the overview rests on class 7's label alone.
- **The offline stack barely reaches before 1940.** This scope begins in 1950, so that is not a constraint here.

## VECTORS

**Operations run:** nearest neighbours of a document (Tier 1, three anchors). **None** of the following were run: a semantic join, centroid similarity, the map, near-duplicates, or a Tier-2 rerank.

**Files:** semantic-vectors-index.json, semantic-vectors-binary.bin and semantic-map.bin (digest read only), plus /Users/jbotts/frus-analysis/c3/SemanticVectors/frus1917-72PubDipv08.vec (digest read only). Script `scripts/vectors.py`, output `out/vectors.txt`.

**Provenance:**
- The digest is 89481b1869da1880… in the index, binary, map and shard: ALL EQUAL.
- generated 2026-10-15; harvestGenerated 2026-10-15T06:55:14.
- measuredRecallAt10 0.9021, so about one of any document's true ten nearest neighbours is missing from the funnel's answer. Absence of a neighbour proves nothing.
- scoreCalibration: documentOffset 0.40, queryOffset 0.47. No cosine was computed or shown, so no calibration was applied.

**Identity:** decoded from the `seg` runs, round trip **553 of 553**. The first run crashed on the volume key, which is `v`, not `id`. The fix and rerun are logged.

**Baselines at this digest:**
- Random pairs (20,000 drawn with `random.Random(1877)`): mean 167.1, sd 14.8, 1st percentile 132, minimum 95 of 512 bits.
- k-th neighbour over 200 random documents (`random.Random(7)`): 1st-neighbour median 84; 10th-neighbour median 102 (quartiles 95 and 108); 25th-neighbour median 108.

**Anchor PubDipv08/d31** (1969 PAO conference). Top 12 (Hamming):
- 81 PubDipv07/d106; 86 PubDipv06/d3; 88 PubDipv06/d5; 88 frus1952-54v13p1/d116; 89 frus1955-57v22/d275; 90 PubDipv08/d99; 90 frus1950v06/d9 (an editorial note, excluded); 91 frus1958-60v16/d65; 92 PubDipv07/d140; 92 frus1952-54v02p2/d374; 92 frus1977-80v30/d68; 94 frus1951v06p1/d12.
- All are far outside random pairs (more than 5 sd below the mean). Against the k-th-neighbour distribution, everything at 81–94 sits inside the typical first-to-tenth band (84 to 102), so these are ordinary neighbours, not exceptional ones.

**Anchor frus1969-76v38p2/d105** (1975 reassessment). Top:
- 76 frus1969-76ve12/d10; 77 frus1958-60v16/d65; 78 frus1969-76v01/d54; 80 ve12/d16; 82 ve12/d15; 82 frus1977-80v22/d104; …

**Anchor PubDipv07/d73** (1966 summary). Top:
- 87 PubDipv07/d69; 103 PubDipv07/d159; 104 frus1952-54v13p1/d116; 105 frus1955-57v01/d2; 108 PubDipv08/d31; …
- Beyond the first, these sit at about the median 10th-to-25th-neighbour distance, so they are weak leads.

**Every neighbour volume is present in document_cache** (553 of 553 volumes indexed), so none needed flagging as outside the index.

**What was read:** frus1952-54v13p1/d116 was read in full; frus1958-60v16/d65 and frus1955-57v22/d275 got a passage search only.
- d116 is the 1952 Saigon assessment of information-program effectiveness written for a Senate inquiry, and it is used in Finding 1.
- d65 (NSC policy for Southeast Asia, 1960) and d275 (Jakarta 1957, military aid) are leads that were not used.

**Documents in the overview reached through a vector operation and through no full-text query:** frus1952-54v13p1/d116 only. That volume appears in the broad M-2 step 3 volume-count probe, but no query I ran listed d116; it is absent from `out/area_info_headers.txt` and `out/area_bm25_top30.txt`. Shown by the logged `grep -c 'frus1952-54v13p1|d116'` over out/area_info_headers.txt, out/area_bm25_top30.txt, out/core_headers_full.txt and out/info_asia_by_vol.txt, which returned 0, 0, 0 and 0. The last file is per volume, so it lists no document ids at all.

## M-8 Collection

`scripts/build_collection.py` writes `collection.fruscollection` and prints "documents 26 excerpts 38 entries 76".
- Every pair was checked against document_cache with apparatus excluded (assert on `SELECT body_text … AND is_front_matter=0 AND is_editorial_note=0`), and every excerpt is an exact substring of body_text.
- No duplicates. No Ed2 volume.
- Five headings follow the overview's findings, in date order within each.
- formatVersion 2, minimumReaderVersion 1, and all six composition keys.
- The closing prose names the unfollowed threads, followed by a `generated` archivalSources block.

`scripts/check_overview.py`: all **22** documents the overview cites by URL are among the 26 in the collection (missing: none). All 38 excerpts are in the verified quote list. The four collection documents not cited by URL in the overview are frus1952-54v12p2/d405, d407, PubDipv07/d171 and PubDipv08/d92. They support Findings 1 and 3 and carry notes.

## M-9 Thinness flags

- **Most of the argument rests on 1962–1977 USIA documents.** Of the 26 documents, 16 come from the four public-diplomacy volumes and frus1969-76v38p2.
- **1956–1961 is nearly empty in this set.** That may reflect search choices, not the corpus: frus1958-60v16/d65 is an unread lead.
- **Korea, Burma, Australia and New Zealand** appear only inside frus1969-76v38p2/d105's round-up.
- **Thinness and the library.** The library is the full 553-volume series, so thinness here is a property of the edition or of the searches, not of a partial download.

## TRACE TABLE

| Overview statement (number or quotation) | Memo source |
|---|---|
| "Twenty-six printed documents", 1950 to 1977 | M-8 (26); M-2 date span |
| "the image of American strength, reliability and friendship" (bottom line; Finding 2) | M-4 Q14 |
| "the image of the US usually depended more on the state of bi-lateral relations … than on developments within the US" | M-4 Q19 |
| Two channels; A1–42 five, UD WW 257 one, UD WW 193 one, P–207 one, P–104 two, UD–UP 7 / "RG 305" one | M-7 came-from |
| Decimal files 511.90, 511.51G, 790.5, 792.5, 611.98 with glosses; CFPF two telegrams | M-7 came-from and decimal-class-labels |
| Lot 61 D 385; Kennedy, Johnson, Nixon sources | M-7 came-from |
| "Only five such citations"; 58 D 726, identifier 2544398, five linear inches, Restricted - Possibly, 1955–1956 | M-7 pointed-at; series-facts |
| Bundled indexes give no identifier for USIA entries | M-7 JSON resolution |
| "soft power" in none of 21 volumes; check phrase in every volume; made-up string in none | M-5 |
| 1970 Saigon survey, 1971 Japanese attitudes, "Public Opinion Research" folder | M-3 (d88, d67 read); M-7 came-from (d149, Box 22, REA—Public Opinion Research 1971) |
| None of fourteen post-1980 volumes | M-6 |
| 33 documents; 42 with nine set aside; 553 volumes | M-2 step 4; M-1 |
| fourteen East Asia volumes | M-5 volume list |
| "about three in four" area-volume heading hits from Vietnam volumes | M-2 step 5 (40 of 55) |
| "about thirty" in the four 1961–1963 Vietnam volumes | M-2 step 5 (31) |
| forty retrieved whole | M-3 |
| "every suitable operation to prepare the minds and emotions of the people to collaborate in the effort" | M-4 Q2 |
| "each nation is an entity basically different from the others and requires special treatment" | M-4 Q3 |
| "increased usage of USIE news and feature material in the local press throughout the area" | M-4 Q1 |
| "intense interest in US by educated groups" | M-4 Q35 |
| "not a primary target group" | M-4 Q38 |
| "though difficult to determine degree" | M-4 Q37 |
| "soft-pedal" / "unbridled nationalism" | M-4 Q36 |
| "a fear of placing the U.S. in the position of appearing to support colonialism" | M-4 Q6 |
| "In almost every country of the area, our programs are directed at elite groups" | M-4 Q15 |
| "probably the most successful visit by an American, from a public image standpoint" | M-4 Q9 |
| "seemed, for first time, to appreciate openness of the U.S. space program as compared to Russian" | M-4 Q10 |
| "must be pegged to a real understanding of and a demonstrated respect for Indonesia’s neutral stance" | M-4 Q8 |
| "we should refrain from glamorous, immediate-impact actions" | M-4 Q7 |
| "Asians are, to varying degrees, America watchers" | M-4 Q18 |
| "US visibility should be low" | M-4 Q20 |
| "Vietnamese peasants are, in the main, going to be persuaded by other Vietnamese" | M-4 Q11 |
| "family-oriented, selfish and opportunistic even in the best of times" | M-4 Q12 |
| "has not given proper attention to the need for a national information program designed to gain popular support" | M-4 Q17 |
| "from the beginning" / "as short-term in nature" | M-4 Q21 |
| "as a dependable ally of SVN reached the lowest point in thirteen Saigon surveys" | M-4 Q22 |
| "a situation that I can describe only as intolerable"; White House aide's "over-reaction" (paraphrase of the editors' note) | M-4 Q13; M-3 (d106 read in full) |
| "public opinion surveys and other assessments of Japanese attitudes have tended to confirm the seriousness of these strains" | M-4 Q24 |
| "While we do not want to appear as having gone “soft” on Chinese Communism…" | M-4 Q25 |
| "could generate favorable opinion toward the U.S." | M-4 Q26 |
| "Although the overseas Chinese appear proud of the achievements of Peking, they are reluctant to accept communist political and economic models" | M-4 Q27 |
| "The American defeat has been in good part written off by the Japanese" | M-4 Q28 |
| "programs on U.S. security relations in Asia lack credibility and may in fact do damage to our relations" | M-4 Q29 |
| "Thais still see us as friends and admire much in the American system" | M-4 Q30 |
| "shoring up the confidence of East Asians in America’s long-term staying power and positive involvement in the area" | M-4 Q32 |
| "We still face deeply implanted and persistent feeling that new administration is “withdrawing” …" | M-4 Q33 |
| "seeks to implant American models on other societies" | M-4 Q34 |
| "gut issues rather than some of the frothier aspects of cultural exchange" | M-4 Q31 |
| Semantic-neighbour search added the 1952 Saigon assessment | VECTORS |
| Quotation and citation checks done | M-4 (39 spans, 0 unverified); M-8 (22 of 22 in collection) |
