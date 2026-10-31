# Scope memo, run f7, 2026-10-31

Question: how U.S. policymakers assessed American soft power in the East Asia and Pacific region; the messaging strategies; their view of effectiveness; the beliefs about the regional audience behind the strategies.

Run directory: /Users/jbotts/frus-analysis/c3f/runs/f7. Scripts and their raw outputs are in `work/` (names given at each number). Dumped document texts are in `docs/`. Every shell command is in `queries.log`.

## §1 Coverage (reported first, as the house rules require)

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;
-- 553|321749|1103|8481   (first tool call of the run; the read-only proof, `BEGIN; CREATE TABLE zz(x); ROLLBACK;` failed with "attempt to write a readonly database", as required)
```

The index holds all 553 volumes of the series, so every count below is conditional on this index as taken 2026-10-25, not on a partial library. Counts of documents exclude `is_front_matter = 1` and `is_editorial_note = 1`. `summary_text` and `note_text` were never selected. No cross_references or person tables were used, so the broken-reference exclusion did not arise. Second editions (`frus1951-54IranEd2`, `frus1969-76ve15p2Ed2`) are not in the scope; the 718/701 overlap rule did not arise.

Reading set: 79 volumes, 35,874 non-apparatus documents (`work/falsefriend.out`, first line). Date span of the volumes: 1946 to 1981 by the manifest. All identities are (volume_id, document_id) pairs.

## §2 Scope: what I chose and how I found it

**Chosen scope.** (a) The 74 volumes of the series' East Asia, Pacific, China, Japan, Korea, Southeast Asia, Indochina and Vietnam compilations from 1946 to 1980 (list in `work/ea_vols_list.txt`; 34,944 non-apparatus documents, `work/ea_vol_counts.txt`), and (b) five public diplomacy volumes: `frus1917-72PubDipv06`, `v07`, `v08` (1961-1972), `frus1969-76v38p2` (1973-1976) and `frus1977-80v30` (1977-1980), 930 non-apparatus documents (`work/misc_counts.out`). Total 79 volumes, 35,874 documents. Inclusion rule for the 33 collection documents: a document in that set in which a U.S. official (or the information agency) describes the audience, the message or method, or the effect, of American persuasion, information, exchange or psychological work directed at an East Asian or Pacific audience, selected by reading.

**How found.**
1. `manifest.json` titles filtered by region words (`work/manifest_scan.py`, output on screen, titles in `work/ea_vols.txt`) gave the East Asia volumes. Public diplomacy volumes were found from per-volume counts of information vocabulary (`work/scope1.sql`, `work/scope1.out`):

```sql
SELECT d.volume_id, COUNT(*) n FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
WHERE frus_documents MATCH '"information agency" OR "information service" OR "information program" OR "psychological strategy" OR "psychological warfare" OR "voice of america" OR propaganda'
AND d.is_front_matter=0 AND d.is_editorial_note=0 GROUP BY d.volume_id ORDER BY n DESC LIMIT 60;
```
(The join on the full-text table's internal row number is used only to attach columns; no row number is reported anywhere.) `frus1917-72PubDipv06/07/08` came out at 134, 141, 122 hits.
2. Headers of the three public diplomacy volumes with Asian place names: `work/scope2.sql` (24 documents). Headers in the 74 volumes with information/psychological/propaganda words: `work/scope4.py` (62 documents; its FTS predicate is `header:("information agency" OR "information service" OR "information program" OR "information policy" OR "psychological" OR propaganda OR "voice of america" OR usia OR usis OR "cultural" OR "public affairs" OR "public diplomacy" OR "educational exchange" OR "information activities" OR "information and cultural" OR "image of the united states")`, restricted to the 74 volumes and apparatus excluded).
3. A per-volume count of the broad information vocabulary in the 74 volumes (`work/scope3.py`, `work/scope3.out`, 5,248 documents in total; the word "psychological" makes this set too wide, so it was used to rank volumes, not as a count I rely on).
4. Ranked candidate lists (`work/cand.py`, outputs `work/cand_image.out`, `work/cand_eff.out`, `work/cand_img2.out`) for image/prestige/audience and effectiveness language, over the 74 volumes + PubDip v06-08 + `frus1955-57v09` + `frus1961-63v25` + `frus1952-54v02p2`.
5. Vector nearest neighbours of four anchors (§8) added `frus1969-76v38p2` and the later public diplomacy volumes; I then ran a header scan of `frus1969-76v38p2`, `frus1977-80v30`, `frus1964-68v33`, `frus1969-76v02` (`work/scope5.out`):

```sql
SELECT volume_id||'/'||document_id, substr(replace(header,char(10),' '),1,170), length(body_text) FROM document_cache
WHERE volume_id IN ('frus1969-76v38p2','frus1977-80v30','frus1964-68v33','frus1969-76v02') AND is_front_matter=0 AND is_editorial_note=0
AND (header LIKE '%Asia%' OR header LIKE '%Japan%' OR header LIKE '%Korea%' OR header LIKE '%Vietnam%' OR header LIKE '%Viet%' OR header LIKE '%China%' OR header LIKE '%Philippin%' OR header LIKE '%Pacific%' OR header LIKE '%Thailand%' OR header LIKE '%Indonesia%') ORDER BY volume_id, rowid;
```
(SQL `LIKE` is case-insensitive.)
6. Reading: documents were dumped whole to disk and read (§6).

**Editors' headings.** The formula in the series is "public affairs", "information program", "psychological strategy", "USIE/USIS", "public diplomacy" (not "soft power"). I read the headings first (`work/scope2.out`, `work/scope4.out`) and queried in the editors' vocabulary.

**Periodisation.** By `document_dates.date_iso` (the document date, from `frus:doc-dateTime-min`), for the decade table (§5); the 1950-1977 span of the collection is from the documents' own dates.

## §3 Controls and the false-friend test

Positive and negative controls in the same pass (`work/falsefriend.py`, `work/falsefriend.out`; also `work/phr1.py`, `work/phr1.out`):

```sql
-- on-topic = the 79 volumes; control = 220 other volumes whose manifest earliest year >= 1946, Ed2 and microfiche supplements dropped
SELECT d.volume_id, COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
WHERE frus_documents MATCH '"<term>"' AND d.is_front_matter=0 AND d.is_editorial_note=0 GROUP BY d.volume_id;   -- summed by set in Python
-- denominators: SELECT volume_id, COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0 GROUP BY volume_id;
```

| term (FTS phrase; stems) | on-topic: N of 35,874 (per 1,000) | control: N of 83,746 (per 1,000) |
|---|---|---|
| ZZZ_IMPOSSIBLE_ZZZ (negative control) | 0 of 35,874 (0.0) | 0 of 83,746 (0.0) |
| department of state (positive control) | 14,251 of 35,874 (397.3) | 43,703 of 83,746 (521.9) |
| soft power | 0 of 35,874 (0.0) | 0 of 83,746 (0.0) |
| public diplomacy | 80 of 35,874 (2.2) | 129 of 83,746 (1.5) |
| usis | 749 of 35,874 (20.9) | 458 of 83,746 (5.5) |
| prestige | 1,700 of 35,874 (47.4) | 3,673 of 83,746 (43.9) |
| image | 518 of 35,874 (14.4) | 1,525 of 83,746 (18.2) |
| psychological | 2,306 of 35,874 (64.3) | 4,136 of 83,746 (49.4) |
| propaganda | 2,808 of 35,874 (78.3) | 5,843 of 83,746 (69.8) |
| information program | 205 of 35,874 (5.7) | 361 of 83,746 (4.3) |
| oriental | 1,060 of 35,874 (29.5) | 2,903 of 83,746 (34.7) |

Positive control also: "department of state" matched 14,090 documents in all 77 of 77 volumes (`work/phr1.out`, the 74 plus PubDip v06-08). Both controls behaved. Reading: "soft power" is absent from the series in both sets (the absence is a vocabulary absence, because the controls prove the scan works; porter stemming would also fold "soft powers"). **False-friend result:** "prestige" (47.4 vs 43.9), "image" (14.4 vs 18.2), "propaganda" (78.3 vs 69.8) and "oriental" (29.5 vs 34.7) sit at the control's rate, so they measure the series, not the question; I did not scope on them. "usis" (20.9 vs 5.5, a ratio of 3.8) does discriminate, so scoping went by the agency's own institutional vocabulary and records. Note the control mixes in other regions' USIS material, so the ratio is a floor on regional specificity, not a proof.

## §4 Phrase-family audit (the "Oriental mind" family and the other phrase counts I publish)

Both obligations of the phrase-count rule are met by a **census** (every hit, since each set is under 300), not a sample.

**Family: "oriental mind", "asian mind", "asian psychology", "psychology of asians", "oriental psychology", "asiatic mind".**
```sql
SELECT d.volume_id,d.document_id,d.header,d.dateline,d.source_note,d.body_text FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
WHERE frus_documents MATCH '"oriental mind" OR "asian mind" OR "asian psychology" OR "psychology of asians" OR "oriental psychology" OR "asiatic mind"'
AND d.volume_id IN (<79 volumes>) AND d.is_front_matter=0 AND d.is_editorial_note=0 ORDER BY d.volume_id,d.document_id;   -- work/belief_share.py
```
32 documents returned. Regex over header+dateline+source_note+body, whitespace-collapsed, Python `re`, case-insensitive:
- STRICT (single spaces; the six phrases; word-bounded): **25 of 32**.
- TOLERANT (`(oriental|asian|asiatic)s?` then any run of space, comma, hyphen, parenthesis or full stop, then `mind|minds|psycholog\w*|mentality`; or `psycholog\w*` of the Asian/Oriental): **32 of 32** (`work/belief_share.out`). The seven strict misses are inflections ("Southeast Asian minds", "Asian minds", "Asian psychological attitudes", "psychology of Asian people") and are all genuine instances.
- Referent test (separate, by reading each hit's 500-character window; `work/belief.out`, classification in `work/belief_classes.tsv`): 17 of 32 apply the wording to how U.S. policy, aid or messaging would be received ("audience"); 15 of 32 are other uses (a Japanese official or an Asian leader's own claim, a remark about negotiators, praise of a general, a flattery in a presidential letter). The 17/15 split is my reading, and contestable at the margin (for example `frus1955-57v22/d148` relays a Dutch complaint and I counted it with the 17 because the object is U.S. prestige).
- Share of the volumes holding hits: not computed (not used).

**Family: "public opinion poll" OR "opinion survey"** over the 77 volumes (74 + PubDip v06-08; 35,453 non-apparatus documents, `work/misc_counts.out`): 31 documents; STRICT literal ("public opinion poll", "opinion survey") 8 of 31; TOLERANT (poll/polls, survey/surveys, public opinion survey) 31 of 31 (`work/phrase_census.out`). The overview's "about thirty documents" is 31 of 35,453.

**Phrase "Office of War Information"** over the nine wartime Far East volumes (`frus1941v04, frus1942China, frus1942v01, frus1943China, frus1943v03, frus1944v05, frus1944v06, frus1945v06, frus1945v07`; 8,704 non-apparatus documents, `work/prewar.out`): 50 documents; STRICT 49 of 50; TOLERANT 50 of 50. The acronym "owi" matched 60 of 8,704 (60 of 60 literal); the two overlap and I did not sum them. Controls in the same pass (`work/prewar.out`): ZZZ_IMPOSSIBLE_ZZZ 0 of 8,704; "department of state" 1,138 of 8,704.

A 1.000 tolerant share tests the stemmer, not the referent; the referent test above is why I report 17 of 32, not 32.

## §5 Decade shape of the agency vocabulary (per 1,000 dated documents, with top-volume share)

`work/decade.py`, `work/decade.out`. Periodised on `document_dates.date_iso`. Numerator: documents in the 79 volumes (apparatus excluded) matching `"information agency" OR usis OR usia OR "information service" OR "voice of america" OR "information program"`; denominator: dated non-apparatus documents of the same volumes in that decade.

```sql
SELECT d.volume_id, substr(dd.date_iso,1,3)||'0s' FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
WHERE frus_documents MATCH '"information agency" OR usis OR usia OR "information service" OR "voice of america" OR "information program"'
AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN (<79 volumes>);
```

| decade | hits of dated documents | per 1,000 | top volume (share of the hits) |
|---|---|---|---|
| 1940s | 372 of 11,453 | 32.5 | frus1948v06, 93 of 372 (25%) |
| 1950s | 337 of 12,112 | 27.8 | frus1955-57v21, 33 of 337 (10%) |
| 1960s | 699 of 8,272 | 84.5 | frus1917-72PubDipv07, 150 of 699 (21%) |
| 1970s | 304 of 3,894 | 78.1 | frus1977-80v30, 138 of 304 (45%) |
| 1980s | 7 of 122 | 57.4 | frus1977-80v30, 7 of 7 (100%) |

The 1970s rate depends on one volume (45%) and the public diplomacy volumes are inside the set, so a rise is partly built in; the 1980s row is seven documents and not interpretable. The overview says "about one in twelve" (1960s: 1 in 11.8) and "about one in thirty-six" (1950s: 1 in 36.0).

## §6 Reading accounting

- Documents dumped whole to disk with captured length equal to `length(body_text)` (in characters): **93 of 93** unique documents (`work/dump_log.tsv`, one line per dump; all "OK"). The 33 collection documents are among them (`work/dump_final.out`: 33 OK, 0 MISMATCH). The reading SELECT (`work/dump.py`): `SELECT header,dateline,source_note,body_text,length(body_text) FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0`.
- Of the 33 collection documents, **23 displayed to me in full**: `frus1950v06/d31, frus1917-72PubDipv06/d127, frus1917-72PubDipv07/d147, frus1917-72PubDipv08/d24, d30, d58, d88, d92, d127, d129, d143, d146, d149, frus1952-54v12p2/d403, d60, frus1952-54v12p1/d103, frus1955-57v22/d361, d447, frus1964-68v26/d106, frus1969-76v38p2/d105, frus1977-80v30/d79, d81, d83`.
- **10 read in part** (passage windows or a leading span): `frus1950v06/d15` (most of it; the opening was truncated in my display), `frus1950v06/d32` (opening, plus three passage windows), `frus1952-54v12p2/d359` (the information-services section, about 3,700 of 22,856 characters, plus two windows), `frus1950v06/d266`, `frus1952-54v14p2/d551`, `frus1952-54v13p2/d992`, `frus1958-60v01/d26`, `frus1955-57v22/d271` (one 500-character window each, around the audience-belief phrase), `frus1964-68v29p2/d123` (first 11,000 of 18,808 characters), `frus1917-72PubDipv08/d31` (first 12,000 of 20,792 characters).
- Quoted: 33 of 33 documents, 45 quotations (§7); each verified by substring against `body_text` fetched from the database at build time (`work/verify_quotes.py`: 45 ok, 0 bad; whitespace collapsed).
- Other documents read whole or in part but not in the collection (examples): `frus1949v09/d465`, `frus1917-72PubDipv08/d121`, `frus1917-72PubDipv07/d171`, `frus1955-57v21/d244`, `frus1961-63v02/d199`, `frus1917-72PubDipv06/d140`.

Documents deliberately left out: two covert-rumour documents on Korea (`frus1952-54v15p1/d251`, `d258`), which are propaganda tactics, not soft power.

## §7 Quotations, each with the SELECT that retrieved it

All 45 are listed in the generated table at the end of this memo (§13), one row per quotation. Retrieval SELECT for each: `SELECT body_text FROM document_cache WHERE volume_id='<v>' AND document_id='<d>' AND is_front_matter=0 AND is_editorial_note=0;` then substring test in `work/verify_quotes.py`. Typographic apostrophes and quotes in the sources are curly; the overview check (`work/check_overview.py`) normalises curly to straight on both sides before comparing; nothing else is altered. The overview's quoted fragments (`work/check_overview.py` output: 56 quoted spans, 10 flagged "not found") were all located except spans that are not document text: my own search terms ("soft power", "opinion survey"), finding-aid titles ("Program Files", "Records Relating to the Voice of America"), the decision label "policymakers'", the collection name, and two spans mispaired by the checker's quote-matching across my own prose. I read these ten and none is a quotation from a document. Documents cited in the overview by URL: 24 distinct; 24 of 24 are in the collection (same script).

## §8 VECTORS

Files: `semantic-vectors-index.json`, `semantic-vectors-binary.bin`, `semantic-map.bin`, `semantic-map-index.json` in the app bundle, and the 553 Tier-2 shards in `/Users/jbotts/frus-analysis/c3/SemanticVectors/` (`work/vec_check.py`, `work/vec_lib.py`). Digest check before scoring: `provenanceDigest` = 89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101 equals bytes 20-52 of the binary, bytes 20-52 of the map, bytes 16-48 of all 553 shards (0 mismatches), and the shard folder's generation file. Generation: EmbeddingGemma 2 (Q8_0), index `generated` 2026-10-15, `harvestGenerated` 2026-10-15T06:55:14. Identity: decoded from the index's id segments (Appendix A §A.3 decode; round trip 553 of 553 volumes; 314,616 documents, 0 missing). `retrieval.measuredRecallAt10` = 0.9021, so an absent neighbour is not evidence of absence.

**Baselines at this digest (`work/vec1.out`).** Random pairs, 20,000 drawn with `random.Random(1877)`: mean 167.1, sd 14.8, 1st percentile 132, minimum 95 (of 512 bits). k-th-neighbour: over 200 documents drawn with `random.Random(1878)`, the median 1st-nearest neighbour is 83 and the median 25th-nearest neighbour is 107 (quartiles 99 and 114). So a neighbour at 90 to 100 is a tail of the distribution by construction and not "top 0.1%" evidence of a link.

**Operations run.**

1. *Nearest neighbours of a document* (`work/vec2.py`, output `work/vec2.out`). Anchors: `frus1917-72PubDipv08/d31` (1969 PAO conference summary), `frus1964-68v29p2/d123` (Tokyo 1968), `frus1950v06/d32` (Jessup 1950), `frus1917-72PubDipv08/d149` (overseas Chinese 1971). File: `semantic-vectors-binary.bin` (Hamming over 512 sign bits, top 800) then rerank by int8 cosine from the Tier-2 shards. The cosine the reader sees is calibrated for document-to-document pairs, `(cosine − 0.40) / 0.60` (`retrieval.scoreCalibration.documentOffset` 0.4); raw cosines are printed beside. Baseline: the 1st-NN median 83 and 25th-NN median 107 above. For anchor `PubDipv08/d31` the top twelve ran from Hamming 81 to 104 (calibrated cosine 0.867 to 0.837; raw 0.920 to 0.902); they include `frus1917-72PubDipv07/d106` (Hamming 81), `frus1969-76v38p2/d105` (96; calibrated 0.862), `frus1917-72PubDipv08/d99` (90), `frus1917-72PubDipv07/d32` (97), and `frus1950v06/d9`, an editorial note (excluded from counts). For `v29p2/d123`: the top two were `frus1969-76v19p2/d84` (72; 0.909) and `frus1958-60v18/d203` (72; 0.900). For `1950v06/d32`: `frus1950v06/d22` (68; 0.888). For `PubDipv08/d149`: `frus1969-76v17/d105` (79; 0.838). No neighbour's volume was absent from the index (`grep -c ABSENT_FROM_DB work/vec2.out` = 0). These are suggestions with distances, not evidence of relationship. I read `frus1969-76v38p2/d105`, `frus1917-72PubDipv08/d99`, `frus1917-72PubDipv07/d69`, `frus1958-60v18/d203` and `frus1964-68v29p2/d35`; only d105 is in the collection.
2. *Semantic join into the database* (`work/vec2.py` prints `document_cache` headers and `document_dates` dates for each neighbour; `work/src_final.py` joins the collection documents into `document_sources` and `external_citations`). Question answered: neighbours of a 1969 USIA conference summary that are from a different decade (1955, 1951, 1952, 1966, 1975) and a different volume family, for example `frus1955-57v09/d190` (a 1955 National Security Council report on the information program). Not a finding on its own.
3. *Centroid similarity* (`work/vec3.py`, `work/vec3.out`). File: the 660 centroids after the sign block of `semantic-vectors-binary.bin`. Volume nearest `frus1917-72PubDipv08`: `PubDipv07` (raw cosine 0.981), `PubDipv06` (0.977), `frus1977-80v30` (0.976), `frus1969-76v38p2` (0.965). Baseline: random volume pairs (2,000, `Random(1877)`): mean 0.904, sd 0.032, 99th percentile 0.972. Raw, uncalibrated (calibration applies to query and document scores, not to centroid cosines). numpy printed divide/overflow warnings in the matrix product; results are in line with adjacency (PubDipv07 to v06 0.987) and I treat the third decimal as unreliable. This pointed to the later public diplomacy volumes (v38p2, 77-80 v30) as the same family.
4. *The map* (`work/vec3.py`). File: `semantic-map.bin` with `semantic-map-index.json`. Anchors: `frus1964-68v29p2/d123` is in cluster 7 (terms japanese, sato, japan, kishi; 1,713 documents); `frus1950v06/d32` is in cluster 31 (indochina, minh, bao, dai; 2,775 documents); `PubDipv08/d31`, `PubDipv08/d149`, `frus1969-76v38p2/d105` and `frus1977-80v30/d83` are unclustered. Unclustered share corpus-wide 88,059 of 314,616 (28.0%); of the 79 volumes' documents (all, including apparatus) 6,357 of 37,310 (17.0%) against an era-matched baseline of volumes dated 1945-1980 by the mean of first and last year, not in the scope, 33,957 of 102,523 (33.1%, 227 volumes); the five public diplomacy volumes 282 of 968 (`work/vec4.out`); the 33 collection documents 9 of 33. So the public diplomacy genre falls outside the map's clusters at about the corpus rate, and a cluster-based claim about it would be unreliable. I used the map only to sample, not to measure.
5. *Near-duplicates* (`work/vec4.py`). Pairwise Hamming among the 33 collection documents: 528 pairs, minimum 96, median 146, none under 60 and none under 40. Baseline: random-pair minimum 95, and the 1st-NN median 83; so the collection holds no reprinted document under these distances (the distance for a reprint at this generation is not given in my brief and I did not measure it; "none under 40" is my cut, flagged as such).

**Documents in the overview reached through a vector operation and through no full-text query:** `frus1969-76v38p2/d105` (the May 1975 East Asia assessments, overview Finding 6 and the bottom line). It was the second neighbour of `PubDipv08/d31`, and `frus1969-76v38p2` was outside my scope list until then. `frus1977-80v30/d79`, `d81`, `d83` were reached by the header scan of §2 step 5 after the centroid and neighbour results sent me to the later public diplomacy volumes (that volume had also appeared, unread, at rank 6 in the §2 step 1 count), so they were reached by a header query that a vector result prompted; I list them for candour. All other documents were reached by full-text queries.

## §9 Archival scope (labelled by channel; never summed)

**Came-from channel, the 33 collection documents (`work/src_final.out`, SQL `SELECT record_group,repository,citation_era,lot_file_norm,series_name,raw_text FROM document_sources WHERE volume_id=? AND document_id=?`):** Record Group 59, central files (decimal 1950-1957: 11; Central Files 1967-69: 1; Central Files 1970-73: 1; Central Foreign Policy File 1977: 2) = 15 documents; Record Group 306 (USIA) = 10; Record Group 305 = 1; State lots = 3 (61 D 167; 61 D 385; and 65 F 98, Record Group 84); presidential libraries = 4 (Kennedy Library RFK papers; Johnson Library National Security File; Johnson Library Marks Papers; Nixon NSC Files). 15 + 10 + 1 + 3 + 4 = 33.

JSON resolution (`work/archival1.py` through `work/archival4.py`, bundled `central-files-index.json`, `collection-authority.json`, `collection-usage-index.json`, `series-facts-index.json`, `curated-lot-resolutions.json`; container shapes read first):
- Lot 61 D 167: one row, identifier 2198167, Record Group 59, "Alphabetical Files", creator Policy Planning Council, inclusive dates 1948-1961, access "Restricted - Partly", use "Restricted - Possibly", 48 linear feet 7 inches, control-number match; FRUS labels the lot "S/P - NSC files", so I report the match as the index's, not mine. Entry A1 1583A/B.
- Lot 61 D 385 and Lot 65 F 98: no row in `central-files-index.json`; unresolved. Lot 58 D 726 (cited, not printed, in the same document): identifier 2544398, Subject Files, Officer in Charge for Malaya Affairs, 1955-1956, "Restricted - Possibly".
- RG 306 "Director's Subject Files" / "Office of the Director": the usage index gives name, record group 306 and the three public diplomacy volumes but no identifier; no series in `series-facts-index.json` could be tied to entry A1-42. I state no identifier or access status for them. The usage index ranks, for the five public diplomacy volumes, "Director's Subject Files" first (112 notes), then Carter Library "National Security Affairs" (68), Nixon "NSC Files" (64), "USIA Historical Collection" (43).
- For the 74 East Asia volumes, the usage index ranks State "Central Files" (5,535 notes), Nixon NSC Files (1,775), Johnson Library National Security File (1,276), Lot 54 D 270 (1,038).

**Pointed-at channel, whole volumes (`work/ext1.py`, `work/ext1.out`; `SELECT repository, lot_file_norm, collection, COUNT(*) ... FROM external_citations WHERE volume_id IN (...) GROUP BY ...`).** The channel has no row before 1910-12-06 (`SELECT MIN(substr(dd.date_iso,1,10)) FROM external_citations e JOIN document_dates dd ...`), stores the citation fragment and not the sentence, and holds lot, library and decimal anchors only.
- Five public diplomacy volumes: 202 rows in 143 documents. Top lots: 84 D 204 (7 rows, 5 documents; not in the bundled index), 78 D 295 (5; NAID 27022973, RG 59, "Administrative Correspondence and Policy and Procedural Files", Deputy Under Secretary for Management, entry UD-UP 80, 1968-1975, "Restricted - Partly", 7 linear feet 2 inches), 78 D 184 (4; NAID 5038052, "Subject Files of Assistant Secretary John Richardson", Bureau of Educational and Cultural Affairs, entry P 242, 1968-1976, "Restricted - Partly", 4 linear feet 8 inches); library series: Nixon NSC Files 27 rows, Carter Library National Security Affairs 21, Ford Library National Security Adviser 21.
- 74 East Asia volumes: 12,830 rows in 7,905 documents. Top lots: 66 D 95 (208 rows, 171 documents) and 63 D 351 (121; 89), both resolved by the index to NAID 2839192, "Records Relating to National Security Council Policy Papers", Executive Secretariat, entry A1 1586E, 1947-1979, "Restricted - Partly", 26 linear feet 3 inches; also 55 D 128 (NAID 2127218, Records Related to the Korean War), 53 D 413 (NAID 2127212, Military Telegrams Relating to Korea), 54 D 423 (NAID 2127217, Japanese Petitions, "Unrestricted"). None of the top lots I resolved has a USIA creator.
- Cited-by-the-editors but unprinted for the collection documents themselves: lot 61 D 385 and 58 D 726 (`frus1955-57v22/d447`), Eisenhower Library papers (`frus1952-54v12p2/d359`), Johnson Library National Security File (`frus1964-68v26/d106`), Nixon Kissinger Office Files (`frus1917-72PubDipv08/d143`).

**USIA-created series in the bundled facts (candidates for the historian; the creator heading is NARA's attribution and is a decoy surface at about 56% precision elsewhere, so none is verified on-topic):** 14 rows with a USIA creator heading. Example: NAID 1257679, "Subject Files" (lots 59 D 260 and 61 D 445), Office of Policy and Plans, inclusive 1953-1971, coverage 1949-1971, 47 linear feet, "Restricted - Partly"; NAID 7542975 "Records Relating to the Voice of America (VOA)" (lot 59 D 242), Broadcasting Service Office of the Director, 1948-1959, 6 linear feet 6 inches, "Restricted - Partly"; NAID 1254251 "Program Files" (lot 60 D 147), Office of Research and Intelligence, Intelligence Production Division, inclusive 1954-1958, coverage 1951-1958, 9 linear feet 2 inches, "Restricted - Partly". No creator heading in the bundled facts is the USIA East Asia and Pacific area office. The offline stack barely reaches before 1940 (11 of 695 bundled series), so nothing is said about earlier shelves.

## §10 What I did not do, and thinness flags

- Wartime and Japan-occupation information work: not read (§4 gives the OWI count only).
- The collection rests on 33 documents chosen by reading from 35,874; the sample of the dominant themes is not random. The Vietnam-era material is the largest cluster because the agency's own archive is best printed there (public diplomacy volumes 1961-1980); Japan, Korea, the Philippines and Australia/New Zealand are thinner (Japan appears through three collection documents (Tokyo 1963 and 1968, and Ridgway's 1952 telegram), Korea through none retained, Australia/New Zealand through none).
- The index is complete (553 volumes), but the thinness is in the reading, not the library.
- South Asia, the 1980s and the Pacific islands: not searched.
- The "audience" (17 of 32) classification is my reading.

## §11 Files

`overview.md`, `memo.md`, `collection.fruscollection`, `queries.log`; `work/` (scripts and outputs); `docs/` (93 dumped documents and meta files).

## §12 Trace table

One row per number and per quotation in `overview.md`. "Memo line" gives the section; quotations are traced in §13.

| overview item | value | memo line |
|---|---|---|
| "soft power" not found in the 79 volumes | 0 of 35,874 documents | §3 table, row "soft power" |
| 79 volumes read | 74 + 5 | §2 chosen scope |
| about 35,900 documents | 35,874 | §1, §2 |
| 33 documents carry the argument | 33 pairs in `collection.fruscollection` | §6, §13 |
| thirty-two documents using the wording | 32 | §4 |
| seventeen apply it to reception; fifteen other | 17 / 15 of 32 | §4 |
| twenty-five of thirty-two exact form | 25 of 32 | §4 |
| fifteen from State central files | 15 of 33 | §9 came-from |
| eleven from the information agency's records (ten RG 306, one RG 305) | 10 + 1 | §9 |
| three from State office files (lots) | 3 | §9 |
| four from presidential libraries | 4 | §9 |
| 202 unprinted items in 143 documents (public diplomacy volumes) | 202 rows / 143 documents | §9 pointed-at |
| lots 84 D 204, 78 D 295 (27022973), 78 D 184 (5038052) | as listed | §9 |
| lots 66 D 95 and 63 D 351 -> 2839192, 1947-1979 | as listed | §9 |
| identifier 2198167 (Alphabetical Files 1948-1961) | NAID 2198167 | §9 |
| identifier 1254251 ("Program Files" 1954-1958) | NAID 1254251 | §9 USIA-created series |
| identifier 7542975 (VOA records 1948-1959) | NAID 7542975 | §9 USIA-created series |
| about thirty documents on opinion polls/surveys among roughly 35,000 in 77 volumes | 31 of 35,453 | §4 |
| 77 volumes; "Department of State" in every one | 14,090 documents, 77 of 77 volumes | §3 (positive control) |
| nine 1941-1945 volumes; about 8,700 documents | 9 volumes, 8,704 documents | §4, §6 |
| fifty of their documents mention the Office of War Information | 50 of 8,704 | §4 |
| 553 volumes in the index | 553 | §1 |
| fourteen-country tour | 14 nations (quote in `frus1950v06/d32`'s opening note) | §13 row for d32 (source: "14-nation fact-finding tour") |
| March 1950 programme (stepped up; Manila; local press) | text of `frus1950v06/d31` | §13, §6 |
| four centers, 13 American and 111 local staff; 122 newspapers; 18 radio stations; film program halved | `frus1952-54v12p2/d359` passage: "4 Information Services centers employing 13 Americans and 111 local inhabitants", "122 newspapers and magazines, 18 radio stations", "reduction in the USIS film program by 50%" | §6 (read), §13 |
| French and British officials believed Asians wait and see | `frus1950v06/d32` | §13 |
| 26 percent rated the U.S. very or rather dependable | `frus1917-72PubDipv08/d88` | §13 |
| nearly fifteen percent of overseas programming | `frus1917-72PubDipv07/d147` | §13 |
| one dated document in twelve (1960s), one in thirty-six (1950s) | 84.5 and 27.8 per 1,000 | §5 |
| 1970s rate nearly as high, nearly half from one volume | 78.1 per 1,000; 138 of 304 (45%) | §5 |
| USIS nearly four times as often as in other postwar volumes | 749 of 35,874 (20.9/1,000) vs 458 of 83,746 (5.5/1,000), ratio 3.8 | §3 |
| prestige, image, propaganda at the control rate | 47.4 vs 43.9; 14.4 vs 18.2; 78.3 vs 69.8 per 1,000 | §3 |
| four anchor documents | `PubDipv08/d31`, `v29p2/d123`, `1950v06/d32`, `PubDipv08/d149` | §8 operation 1 |
| nine volumes would be added by starting in 1941, about 8,700 documents | 9; 8,704 | §4 |
| Hong Kong, Thailand, security programs lacked credibility | quotations of `frus1969-76v38p2/d105` | §13 |
| quotations in overview Findings 1-6 and bottom line | each located in §13 table (45 rows) | §13 |

## §13 Quotations table (generated)

| # | document (volume/document) | quotation (verbatim) | retrieving SELECT |
|---|---|---|---|
| Q1 | frus1950v06/d15 | Generally agreed USIE materials designed for world-wide or even area-wide distribution not satisfactory. | `SELECT body_text FROM document_cache WHERE volume_id='frus1950v06' AND document_id='d15' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q2 | frus1950v06/d15 | US committed demonstrate value American way life in Japan, Korea, Philippines republic, and lesser extent Indonesia and failure will greatly lower our prestige and effectiveness Asia. | `SELECT body_text FROM document_cache WHERE volume_id='frus1950v06' AND document_id='d15' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q3 | frus1950v06/d31 | There is already evidence, however, of increased usage of USIE news and feature material in the local press throughout the area. | `SELECT body_text FROM document_cache WHERE volume_id='frus1950v06' AND document_id='d31' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q4 | frus1950v06/d32 | Ambassador Jessup considered that we are weak on propaganda. He raised the question of whom we are trying to reach and recommended that more thought be given to methods of reaching our audience and to the themes we are trying to put across. | `SELECT body_text FROM document_cache WHERE volume_id='frus1950v06' AND document_id='d32' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q5 | frus1950v06/d32 | Both Pignon, the French High Commissioner for Indochina, and MacDonald, Commissioner for the United Kingdom in Southeast Asia, believe that the Asians are inclined by their psychology to wait and see who is winning. | `SELECT body_text FROM document_cache WHERE volume_id='frus1950v06' AND document_id='d32' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q6 | frus1952-54v12p2/d359 | During FY 1954 a reduction in the USIS film program by 50% will be necessary because of lack of funds. | `SELECT body_text FROM document_cache WHERE volume_id='frus1952-54v12p2' AND document_id='d359' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q7 | frus1952-54v12p2/d403 | Wherever possible in cooperation with local governments and making use chiefly of indigenous outlets, develop or expand U.S. overt information programs directed to Thailand and the adjacent area. | `SELECT body_text FROM document_cache WHERE volume_id='frus1952-54v12p2' AND document_id='d403' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q8 | frus1950v06/d266 | it is in the pattern of the Oriental psychology to respect and follow aggressive, resolute and dynamic leadership—to quickly turn on a leadership characterized by timidity or vacillation | `SELECT body_text FROM document_cache WHERE volume_id='frus1950v06' AND document_id='d266' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q9 | frus1952-54v14p2/d551 | Finally, we must by word and deed do everything within our power to overcome any feeling in the Oriental mind that our interest in Asia is casual, temporary or overshadowed by our interests in other regions. | `SELECT body_text FROM document_cache WHERE volume_id='frus1952-54v14p2' AND document_id='d551' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q10 | frus1952-54v12p2/d60 | One of our most serious handicaps has been that we have necessarily been too conspicuous in Burma with too many Americans in evidence and too much involvement in what Burmese consider their own internal affairs. | `SELECT body_text FROM document_cache WHERE volume_id='frus1952-54v12p2' AND document_id='d60' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q11 | frus1952-54v12p2/d60 | Bulk of Burmese people simply unable understand aid in terms of altruism. | `SELECT body_text FROM document_cache WHERE volume_id='frus1952-54v12p2' AND document_id='d60' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q12 | frus1952-54v13p2/d992 | In Asia give-away programs are too frequently mistaken in the oriental mind as meaning that the donor not only has a soft heart but also a soft head. | `SELECT body_text FROM document_cache WHERE volume_id='frus1952-54v13p2' AND document_id='d992' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q13 | frus1955-57v22/d361 | Said further Americans do not understand Asian mind when they fail realize importance gifts to friendly visitors | `SELECT body_text FROM document_cache WHERE volume_id='frus1955-57v22' AND document_id='d361' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q14 | frus1958-60v01/d26 | Not being Asians, Americans do not understand the Oriental mind and point of view. | `SELECT body_text FROM document_cache WHERE volume_id='frus1958-60v01' AND document_id='d26' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q15 | frus1952-54v12p1/d103 | Tendency in SEA to attribute some “pure nationalism” to Viet Minh aims will make more difficult characterization of invasion as “naked aggression.” | `SELECT body_text FROM document_cache WHERE volume_id='frus1952-54v12p1' AND document_id='d103' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q16 | frus1955-57v22/d447 | a fear of placing the U.S. in the position of appearing to support colonialism | `SELECT body_text FROM document_cache WHERE volume_id='frus1955-57v22' AND document_id='d447' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q17 | frus1955-57v22/d271 | US support for a Dutch trusteeship would be widely interpreted as evidence of a US desire to maintain Western control over Asian peoples or, to Asian minds, of US “colonialism”. | `SELECT body_text FROM document_cache WHERE volume_id='frus1955-57v22' AND document_id='d271' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q18 | frus1917-72PubDipv06/d127 | what was probably the most successful visit by an American, from a public image standpoint | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv06' AND document_id='d127' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q19 | frus1964-68v26/d106 | We shall soon have nothing worthwhile left in the way of an information operation. | `SELECT body_text FROM document_cache WHERE volume_id='frus1964-68v26' AND document_id='d106' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q20 | frus1964-68v29p2/d123 | popular respect for US political institutions, infatuation with many aspects of American mass culture, genuine respect for our intellectual attainments, and visible attractions of the American way of life, have kept America a strongly positive symbol. | `SELECT body_text FROM document_cache WHERE volume_id='frus1964-68v29p2' AND document_id='d123' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q21 | frus1964-68v29p2/d123 | Racial violence and social unrest in America have roused concern over basic stability of American society, made American image a rather less positive political symbol. | `SELECT body_text FROM document_cache WHERE volume_id='frus1964-68v29p2' AND document_id='d123' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q22 | frus1917-72PubDipv08/d31 | Asians are, to varying degrees, America watchers. | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv08' AND document_id='d31' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q23 | frus1917-72PubDipv08/d31 | PAOs emphasized that the image of the US usually depended more on the state of bi-lateral relations (security treaty, Okinawa, Korean military modernization, trade restrictions) than on developments within the US. | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv08' AND document_id='d31' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q24 | frus1917-72PubDipv08/d31 | Many PAOs reported uncertainty as to the direction of US foreign policy and especially the strength of US commitments in Asia. | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv08' AND document_id='d31' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q25 | frus1917-72PubDipv07/d147 | Some of these tasks appear to lie outside the Agency’s appropriate sphere of operations. | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv07' AND document_id='d147' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q26 | frus1917-72PubDipv07/d147 | These three country operations absorb nearly fifteen percent of the Agency’s resources available for overseas programming. | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv07' AND document_id='d147' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q27 | frus1917-72PubDipv08/d24 | Thus modified, Agency objectives for the Midway Meeting are to strengthen the public image of: | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv08' AND document_id='d24' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q28 | frus1917-72PubDipv08/d58 | USIA has, from the beginning, considered its psychological operations (PSYOP) support program in Viet-Nam as short-term in nature. | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv08' AND document_id='d58' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q29 | frus1917-72PubDipv08/d88 | Rating of the U.S. as a dependable ally of SVN reached the lowest point in thirteen Saigon surveys, with only 26 percent of the general public and 23 percent of the college-educated thinking of U.S. as “very dependable” or “rather dependable.” | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv08' AND document_id='d88' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q30 | frus1917-72PubDipv08/d92 | The Lon Nol Government has very little at hand to counter this serious propaganda threat. | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv08' AND document_id='d92' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q31 | frus1917-72PubDipv08/d129 | is now engaged in a massive campaign, using every tool of the communication arts, to sell the Thieu Government to the people of Vietnam. | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv08' AND document_id='d129' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q32 | frus1917-72PubDipv08/d30 | Peace in Asia—which is a precondition to peace in the world—cannot result primarily from American conceptions but has to involve Asian initiatives and regional and sub-regional arrangements that have an Asian origin. | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv08' AND document_id='d30' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q33 | frus1917-72PubDipv08/d127 | The Communists appear to be more alert than we to the use of the cultural approach. | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv08' AND document_id='d127' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q34 | frus1917-72PubDipv08/d127 | The Agency is somewhere between a decade and a generation behind in the use of audio visual techniques which in themselves attest to American progress. | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv08' AND document_id='d127' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q35 | frus1917-72PubDipv08/d143 | While we do not want to appear as having gone “soft” on Chinese Communism neither do we want to appear anti-Chinese or anti-Peking. | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv08' AND document_id='d143' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q36 | frus1917-72PubDipv08/d146 | The President’s projected visit to Peking presents us with opportunities to build what is now a temporary psychological asset into a long-range one. | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv08' AND document_id='d146' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q37 | frus1917-72PubDipv08/d149 | Thus, we are compelled to take a very close look at the overseas Chinese as a USIS audience. | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv08' AND document_id='d149' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q38 | frus1917-72PubDipv08/d149 | Although the overseas Chinese appear proud of the achievements of Peking, they are reluctant to accept communist political and economic models. | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv08' AND document_id='d149' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q39 | frus1969-76v38p2/d105 | During this waiting period, programs on U.S. security relations in Asia lack credibility and may in fact do damage to our relations. | `SELECT body_text FROM document_cache WHERE volume_id='frus1969-76v38p2' AND document_id='d105' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q40 | frus1969-76v38p2/d105 | Thais still see us as friends and admire much in the American system. | `SELECT body_text FROM document_cache WHERE volume_id='frus1969-76v38p2' AND document_id='d105' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q41 | frus1969-76v38p2/d105 | The denouement in Indochina has left Hong Kong viewing USG as “very clearly in default.” | `SELECT body_text FROM document_cache WHERE volume_id='frus1969-76v38p2' AND document_id='d105' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q42 | frus1977-80v30/d79 | I don’t think there should be any serious doubt that this Administration believes shoring up the confidence of East Asians in America’s long-term staying power and positive involvement in the area is real and necessary. | `SELECT body_text FROM document_cache WHERE volume_id='frus1977-80v30' AND document_id='d79' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q43 | frus1977-80v30/d81 | I would welcome any comments that you, in collaboration with your PAOs, might have on the future role of public diplomacy in support of our policies in Asia. | `SELECT body_text FROM document_cache WHERE volume_id='frus1977-80v30' AND document_id='d81' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q44 | frus1977-80v30/d83 | In general, public diplomacy of the new administration in this area has been effective. | `SELECT body_text FROM document_cache WHERE volume_id='frus1977-80v30' AND document_id='d83' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q45 | frus1977-80v30/d83 | We still face deeply implanted and persistent feeling that new administration is “withdrawing” or, at least, “reducing priority” in East Asia. | `SELECT body_text FROM document_cache WHERE volume_id='frus1977-80v30' AND document_id='d83' AND is_front_matter=0 AND is_editorial_note=0;` |
