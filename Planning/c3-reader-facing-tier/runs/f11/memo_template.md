# Scope memo, run f11, 2026-10-31

Question: how did policymakers assess American soft power in the East Asia and Pacific region; what messaging strategies, how effective did they think they were, what beliefs about the regional audience lay behind them.
Operator memo. Every number in overview.md is traced in section 8. Every command is in queries.log; the scripts named here sit in this directory with their outputs.

## 0. Coverage and controls

Canary (first command) and read-only proof (second) both behaved as specified.

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;
-- 553|321749|1103|8481
```

All counts below are conditional on this index: 553 volumes, the full series, so the partial-library caveat does not bite on volume coverage. It still bites on reading: I retrieved 52 documents whole out of 1,176 + 42 candidates, so every claim about "the officials" is a claim about the documents I read.

Positive control ("Department of State", 69 regional volumes, apparatus excluded): 13,470 documents, and none of the 76 candidate volumes in eap_core.txt returned zero (density.py). Negative control (ZZZ_IMPOSSIBLE_ZZZ): 0 in the same pass. Both run in the same pass in density.py and again in stats.py.

## 1. Scope chosen and how it was found

Inclusion rule. REGIONAL set (69 volumes): every volume whose manifest.json title names China, Japan, Korea, Vietnam, Indochina, Southeast Asia, East Asia, Northeast Asia, Pacific, Indonesia, Philippines, Laos, Cambodia, Malaysia, Taiwan or "Asia", dated 1948-1980, minus South Asia and Near East titles removed by name (frus1944v05, frus1948v05p1/p2, frus1949v06, frus1950v05, frus1952-54v11p1/p2, frus1955-57v08, frus1961-63v19, frus1964-68v25, frus1969-76v11, frus1969-76ve07, ve08, frus1977-80v19), minus the 1942-1947 China volumes and any Ed2 or Supp title (build_eap_list.py, eap_core.txt, scope_vols.txt). INFORMATION set (7 volumes): frus1917-72PubDipv06, v07, v08, frus1969-76v38p2, frus1977-80v30, frus1955-57v09, frus1961-63v25. Total scope 76 volumes. Second editions: none in scope, so the Ed2 rule was not triggered. Exclusions: is_front_matter=1 and is_editorial_note=1 throughout; cross_references not used (no is_broken filter needed).

How found. (1) manifest titles; (2) density.py ran one broad FTS family over each regional volume and ranked them by rate (that family included "propaganda", which in the Korea and Vietnam volumes mostly describes enemy propaganda, so I narrowed the family to American information work and did not use the density ranking to pick documents; the share of enemy propaganda was not measured); (3) the seven information volumes were found by title and then scanned by header (pd_headers.py, 42 rows); (4) ranked FTS queries (search.py) over scope_vols.txt for audience-belief, effectiveness, neutralism and prestige vocabulary, from which candidates were read; (5) vector neighbours of four anchors (section 6). I did NOT read the editors' chapter headings before writing queries (house rule), I read volume titles and document headers only.

Period. Periodised on document_dates.date_iso (the index's date for the document), not on the volume's series year. Start 1948 is a decision (overview, "Decisions").

Counting surface for every SQL count in this memo: the SQLite index (porter-stemmed full text, body_text including editorial footnotes). No [TEI] scan was run, so there are no spelling-variant, tag-stripped or word-bounded counts, and none is claimed. The phrase counts carry the literal-share check of section 2.

## 2. Measurements (audit forms)

Predicates used (python wrappers in stats.py, share.py, absent.py, density.py; "REG" = the 69 regional volumes listed in scope_vols.txt minus the 7 information volumes):

```sql
-- base predicate on every count
FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
WHERE d.volume_id IN (REG) AND d.is_front_matter=0 AND d.is_editorial_note=0
-- FAMILY A match string
frus_documents MATCH '(USIA OR USIS OR "Voice of America" OR "information program" OR "psychological warfare" OR "psychological strategy" OR "United States Information")'
```

(The rowid join is used only to join the FTS table to its content table inside the query; no rowid is reported as an identifier.)

Full output of stats.py:

```
{{stats.out}}
```

- N1. 69 regional volumes, 1948-1980. List in scope_vols.txt (first 69 lines are the regional ones; the last 7 are the information set).
- N2. 30,092 documents in REG: `SELECT count(*) FROM document_cache d WHERE volume_id IN (REG) AND is_front_matter=0 AND is_editorial_note=0` (stats.out line 2).
- N3. Family A: 1,176 of 30,092 documents in REG (one in 25.6). Counting surface: index.
- N4. 7 information volumes hold 1,582 non-apparatus documents: `SELECT count(*) FROM document_cache WHERE volume_id IN (7 volumes) AND is_front_matter=0 AND is_editorial_note=0` (final_numbers.out).
- N5. 42 documents in the information volumes whose header names an Asian or Pacific place or office: `frus_documents MATCH 'header:(Asia OR Asian OR "Far East" OR Vietnam OR Vietnamese OR Japan OR Japanese OR Korea OR Korean OR Indonesia OR Philippines OR Thailand OR China OR Chinese OR Taiwan OR Pacific OR Laos OR Cambodia OR Burma OR Malaysia OR Singapore OR Australia)'` restricted to the 7 volumes (pd_headers.py, pd_headers.out). This is a loose test: 9 of the 42 headers name South Asia or Near East offices (grep -c "South Asia|Near East" pd_headers.out = 9), and at least three are State Department documents, not USIA ones (frus1955-57v09/d131, frus1961-63v25/d179, d431). It is a finding aid, not a measured set.
- N6. Absences (REG, apparatus excluded): "soft power" 0, NEAR(soft power, 3) 0, "cultural diplomacy" 0, "Radio Free Asia" 0, "public diplomacy" 2. Relaxed form of the first that did return rows: `soft AND power` returned 127 documents (the two words anywhere in a document, mostly "soft" with unrelated "power"; not read). The corpus-wide first count (including front matter) was also 0 (initial term counts, run before the scope was set).
- N7. Asia Foundation 12, Peace Corps 59, "cultural exchange" 92, "educational exchange" 54, Fulbright 278 (mostly the Senator, not read, and not used) (absent.out).
- N8. 11 of 698 bundled series start before 1940 (one in 63.5): series-facts-index.json byNaId, field y0 (absent.out). The guide's figure was "about one in sixty"; this is the re-derived one.

### Phrase shares (house rule a and b)

```
{{share.out}}
```

For all four phrase families the whole set was under 300, so the whole set was checked, not a sample of 40. STRICT = single spaces; TOLERANT = each word with up to four extra letters, any run of space, hyphen, comma, parenthesis or full stop between. Case-insensitive Python `re` over header+dateline+source_note+body_text whitespace-collapsed; the FTS side is SQLite's case-insensitive stem match. The 13 misses for "United States Information" are "United States informed/inform/informal" (stem collision), so that family's tolerant share is 101 of 114 (0.886) and it was used only inside the mixed family A; the 1 miss for "information program" was read as a stem collision as well. Acronyms (USIA, USIS) are exact tokens in the index; Voice of America was not share-tested separately.

A 1.000 share tests the stemmer, not the referent. The referent test: every document quoted in the overview was read, and in each the phrase refers to American government information work.

### Decade shape (periodised on document_dates.date_iso; per 1,000 dated non-apparatus REG documents; numerator's top-volume share)

See the table at the end of stats.out above. The 1940s row's top volume (frus1948v06, 93 of 303) is large, and the 1980s row is one document dated 1980 in frus1977-80v22; neither is used. The overview uses 1950s 33, 1960s 53, 1970s 19 per thousand (this is N17) with the caveat in its text that single volumes carry much of each figure (top volume 35 of 395, 43 of 414, 20 of 63).

### False-friend tests (for terms the question or the method supplied; this is N16)

REG vs 201 control volumes (all 1948-1980 volumes not in scope, 77,265 documents): "audience OR audiences" 8.2 per thousand in REG against 11.8 in control, so "audience" is NOT a marker of the question and was not used; "USIS OR USIA" 26.3 per thousand against 18.0, only 1.5 times as common, so the acronym family does not by itself identify the region and the argument rests on documents read, not on this count; "propaganda" 80.2 against 70.3, also not specific, and it was dropped from family A after density.py showed it mostly describes enemy propaganda. ‘soft power’ is the question's own term and is absent (N6).

## 3. Reading accounting

Documents retrieved whole (captured length = length(body_text)): 52 of 52 files in docs/ (final_numbers.out: "dumped whole 52 of 52"). Reading SELECT (dump.py):

```sql
SELECT volume_id,document_id,header,dateline,source_note,body_text,length(body_text),is_front_matter,is_editorial_note
FROM document_cache WHERE volume_id=? AND document_id=?
```

Of the 52, I read some bodies to the end and the relevant passages (by position or by regex context, ctx.py) of the rest; I did not keep a count of which were read to the end. 25 documents are in the collection and are the ones I quote or rest an argument on; 36 excerpts in the collection; 23 quotations in the overview. A document not in docs/ was never read beyond a search snippet.

Documents read but not used, for the record: frus1917-72PubDipv06/d111, d112 (1963 press relations and Laos, whole), frus1917-72PubDipv08/d92 (Cambodia information vacuum, 1970), frus1917-72PubDipv07/d171 (educational television, 1967), frus1958-60v01/d26 (Durbrow reporting Diem's belief that Americans do not understand the Oriental mind; it is Diem's belief, not a US policymaker's, so it is not argued from), frus1961-63v04/d81, frus1961-63v02/d16, frus1949v07p2/d338, frus1958-60v18/d193, frus1977-80v30/d2 and frus1958-60v16/d12.

## 4. Quotations (each with its SELECT and id pair)

Overview quotation = text inside “ ” in overview.md; every one is a verbatim substring of its document's body_text after collapsing whitespace (check_overview.py). Spacing artefacts in the source (for example "ICA -funded") are preserved in the collection's excerpts. Excerpts in the collection are listed with their anchors in excerpts.out and re-verified by verify_collection.py.

| ID | volume_id/document_id | SELECT that retrieved it | check | text |
|---|---|---|---|---|
{{QUOTES}}

Verification outputs:

```
{{verify_collection.out}}
{{check_overview.out}}
```

Facts stated in the overview that are not quotations but are read from a document: the 1950 mission report says white troops "will always be associated with colonialism" (frus1950v06/d89; retrieved by ctx.py on docs/frus1950v06__d89.txt, pattern "white troops will always"), Tokyo poll 49 to 40, 22 to 32 percent, with the 52 to 38 and 4 to 8 percent favourable and dislike figures (frus1964-68v29p2/d46), Saigon survey 637 adults, 26 percent and 23 percent college-educated (frus1917-72PubDipv08/d88), film audiences of 28 million (frus1964-68v01/d197), the 1957 Japan hedge (frus1955-57v09/d207), the Hong Kong and Japan abstracts (frus1969-76v38p2/d105).

## 5. Archival scope (labelled by channel, never summed)

[JSON] sources: manifest.json, central-files-index.json (lotFiles as a list keyed by lotNumber), series-facts-index.json (byNaId with one-letter keys per its legend; headings array), accession-series-index.json (byAccession, key "<record group>/<accession>"), collection-authority.json. Scripts: arch.py, lots.py, json_usia.py, acc.py, absent.py. [HARVEST] path: none was given, so the record-group harvest is unavailable and no count here comes from it.

CAME-FROM channel (document_sources, one row per document; volume set = the 7 information volumes, set A of 42 header-matched documents; and the 69 regional volumes, set B of 1,176 family-A documents).

```
{{arch.out}}
```

Set A by record group (document_sources.record_group): RG 306: 27 of 42; RG 59: 8; RG 305: 1; none recorded (libraries): 6. Entries printed in the source notes of documents I quote: RG 306 Director's Subject Files 1968-1972, Entry A1-42 (frus1917-72PubDipv08/d88, d149); Office of Policy and Plans, Entry P-207 (d31); DIRCTR Sub Files 1963-69 Acc 72A5121 Entry UD WW 257 (frus1917-72PubDipv06/d111, d112 and others; source line quoted from document_sources.raw_text); Director's office Executive Secretariat Correspondence Files 1973-1980 Entry P-104 (frus1977-80v30/d79). Resolution against the bundled stack: none of A1-42, UD WW 257, P-207, UD WW 193 or P-104 occurs in any bundled JSON (grep -F over all *.json; P-104 matched only "P 1047", another series). accession-series-index.json matches 306/72A5121 and 306/69A3445 and 306/68A4933 to many NAIDs each (4,750 accession keys in the file); that is accession level, not entry level, so no single shelf is resolved. The two series named in the overview are candidates by creator only: NAID 40967285 (creator "U.S. Information Agency. Office of the Director. Executive Secretariat.", 103 linear feet 1 inch, 1956-1972, access "Restricted - Partly") and NAID 1257679 (creator "U.S. Information Agency. Office of Policy and Plans.", 47 linear feet, 1953-1971, "Restricted - Partly"). NARA's creator attribution is a decoy surface; neither is verified against the boxes cited. The Office of Research and Intelligence series, NAID 1254251 (9 linear feet 2 inches, 1954-1958, "Restricted - Partly"), is named in the overview as the nearest bundled research series, same caveat.

POINTED-AT channel (external_citations; volume set = the 69 regional volumes; documents = set B). The channel has no row before 1910-12-06 (not relevant here), stores the citation fragment and not the sentence, and holds lot, library and decimal anchors only. Output above: 322 of 1,176 documents have at least one row; 551 rows, of which centralFileClass 296, lotFile 134, presidentialLibrary 121 (36 Johnson NSF, 25 Nixon NSC Files, 18 Kennedy NSF, others). Lots resolved through central-files-index.json and series-facts-index.json:

```
{{lots.out}}
```

The came-from and pointed-at counts are over different documents and different sets and are not added anywhere.

## 6. VECTORS

Artifacts: semantic-vectors-index.json, semantic-vectors-binary.bin, semantic-map.bin, semantic-map-index.json, semantic-shards-manifest.json in the app bundle, and the 553 .vec shards in /Users/jbotts/frus-analysis/c3/SemanticVectors/. Provenance digest 89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101 compared across the index, the corpus binary (offset 20), the map (offset 20), the shard folder's .generation file, the shard manifest, and the header of every one of 553 shards (offset 16): identical, 0 mismatches. Index generated 2026-10-15, harvestGenerated 2026-10-15T06:55:14; measuredRecallAt10 0.9021 (so absence of a neighbour is not evidence of absence); scoreCalibration documentOffset 0.40 (scale 0.60 for document-to-document), queryOffset 0.47 (no query was embedded; no embedder). Identity from the index's segments only (decode of section A.3, 553 of 553 volumes round-trip, 314,616 rows). The Python-3.9 form `bin(x).count("1")` was not needed: numpy `bitwise_count` was used.

```
{{vec_setup.out}}
```

Operations run (each with anchor, file, baseline, finding):

1. Nearest neighbours of a document. Anchors: frus1917-72PubDipv08/d31 (Manila PAO conference, 1969), frus1969-76v38p2/d105 (1975 East Asia reassessment), frus1964-68v29p2/d46 (Reischauer, 1965), frus1917-72PubDipv07/d100 (Marks, 1966). File: semantic-vectors-binary.bin sign bits (Hamming over 512 bits), reranked for display by int8 cosine from the .vec shards, shown raw and as (cos-0.40)/0.60. Baselines, both at this digest: random pairs (20,000, seed 1877) mean 167.1, sd 14.8, 1st percentile 132, minimum 95; and the k-th neighbour distribution over a 200-document sample (seed 1877): 25th neighbour median 108 (quartiles 101 and 114), nearest neighbour median 82 (quartiles 71 and 92). Every neighbour listed is far inside random-pair chance, and the nearest neighbours (76 to 94) sit at ordinary nearest-neighbour distances, not unusual ones; the anchor of 1975 has a 25th neighbour at 90 against a median 108, so it sits in a dense area. Findings: neighbours are suggestions. No neighbour was outside document_cache (all in_db=True). Output:

```
{{vec_nn.out}}
```

2. Semantic join. Top 60 Hamming neighbours of frus1969-76v38p2/d105 joined to document_dates and document_sources (vec_ops2.py). Result in vec_ops2.out below: by decade 1940s 2, 1950s 24, 1960s 14, 1970s 19, 1980s 1; came-from, the six largest groups: State Department files recorded under RG 59 (32 as "Department of State" and 8 as "National Archives"), Ford Library 5, none recorded 4, Nixon Presidential Materials 3, Carter Library 2; 11 of the 60 lie outside the 76-volume scope. It says the neighbours of a 1975 USIA reassessment are mostly NSC-level and State policy papers from the 1950s onward, not other USIA reports.
3. Centroid similarity. Anchor: the centroid of frus1917-72PubDipv08 (and frus1977-80v30, frus1964-68v27), from the centroid block of the corpus binary; baseline: 5,000 random volume pairs, mean cosine 0.905, sd 0.032, 99th percentile 0.974 (raw cosines, not calibrated). Volume nearest PubDipv08: PubDipv07 0.981, PubDipv06 0.977, frus1977-80v30 0.976, frus1969-76v38p2 0.965. Nearest to frus1964-68v27: frus1961-63v23 0.980, frus1969-76v20 0.976. Finding: the public-diplomacy volumes are each other's nearest volumes, as expected. numpy printed divide-by-zero/overflow matmul warnings on the float32 product; the results are plausible and the order stable, but I did not investigate the warning.
4. The map. Cluster and label of each of the 25 collection documents (semantic-map.bin, semantic-map-index.json), in vec_ops2.out. Cluster 29 (terms lao, vietnamese, vietnam, thieu) holds 9 of the 25, cluster 7 (japanese, sato, japan, kishi) 2, cluster 20 (grc, formosa, chiang, taiwan) 2, cluster 138 (cia, nsc, usia, inglis) 2, clusters 115 and 103 one each. Unclustered: 8 of 25 (32%) against 18.3% for all 33,206 rows of the 76 scope volumes (apparatus included, so only a rough era-matched baseline) and 28.0% corpus-wide (88,059 of 314,616). The collection is somewhat more often unclustered than its volumes, which fits long policy memoranda that mix topics; no figure in the overview rests on clusters.
5. Near-duplicates. All 300 pairs among the 25 collection documents: closest pair 50 (frus1955-57v09/d190 and d207, two successive National Security Council reports on the same programme, not copies), then 70, 76, 77, 79; median pair 129. No reprint pair among them; the guide's reprint threshold was not given to me, so I read the closest pair and they are different documents.

Documents in the overview reached through a vector operation and through no full-text query I read: frus1977-80v22/d104 (it matches none of the three ranked queries run in search.py) and frus1969-76ve12/d10 (it matches the broad ranked query at rank 505 of 1,665, beyond the 25 I read, and so was in practice reached by the vector operation). Both are neighbours of frus1969-76v38p2/d105 (distance 82 and 76; raw cosine 0.915 and 0.910; calibrated 86% and 85%, between two documents). Every other document in the overview was found by a full-text query or by header scan. The other vector neighbours were listed and mostly not read.

```
{{vec_ops2.out}}
```

## 7. Caveats and threads not followed

- The documents are US government writing; the audience's views are the officials' reports of them. The overview says so.
- 52 documents read whole against a candidate pool of 1,176 + 42: any statement about officials in general is a sample. Thin areas: Korea after 1960, the Philippines, Indonesia, Australia and New Zealand, the Voice of America's audience in China, exchange programs.
- Fulbright counts mix the Senator and the program; not used.
- Family A does not include "propaganda"; its 1940s mass is partly "United States Information" (tolerant share 0.886).
- Exclusions: second editions none in scope; South Asia and Near East volumes excluded by name; 1942-1947 China volumes not searched.
- No second pass was possible.

## 8. TRACE TABLE (overview item -> memo line)

| Overview item | Where in the overview | Memo line |
|---|---|---|
| 'soft power' in none of 30,092 documents of 69 volumes | Bottom line 1; Bottom line 3 | N6, N2, N1 (section 2) |
| 25 documents from 1949 to 1978 | Bottom line 1; Read next | section 4 table; verify_collection.out |
| 1955 report reported placements (a fact read from document, not a quotation) | Bottom line 1; Finding 3 | Q row for d190 (section 4) |
| 27 of 42 from RG 306; 42 headings | Bottom line 2 | N5, section 5 (Set A record group counts) |
| Entries A1-42, UD WW 257, 72 A 5121, P-207, P-104 | Bottom line 2 | section 5 (entries printed in source notes) |
| NAID 40967285, 103 ft, 1956-1972, partly restricted; NAID 1257679, 47 ft, 1953-1971 | Bottom line 2 | section 5; lots.out; absent.out last lines |
| 1,176 regional documents; 322 with footnote citation | Bottom line 2 | N3; section 5 (arch.out, POINTED-AT Set B: 322 of 1,176) |
| NAIDs 2839192, 2839191, 2838992 and their extents | Bottom line 2 | lots.out (POINTED-AT list) |
| Johnson / Nixon / Kennedy library files named | Bottom line 2 | arch.out Set B pointed-at rows (36, 25, 18) |
| 'cultural diplomacy', 'Radio Free Asia' none; 'public diplomacy' 2 | Bottom line 3 | N6 |
| Control: 13,470 for 'Department of State' | Bottom line 3 | section 0 and stats.out |
| Tokyo poll 1965; Saigon survey 637 adults | Bottom line 3; Finding 3, 4 | section 4 (facts read from documents) |
| NAID 1254251, 9 ft, partly restricted | Bottom line 3 | section 5 |
| Asia Foundation 12, Peace Corps 59, 'cultural exchange' 92 | Bottom line 3 | N7 |
| 11 of 698 series before 1940, one in sixty-three | Bottom line 3 | N8 |
| 69 volumes; 30,092; 7 volumes; 1,582; 553 volumes | Scope; How this was done | N1, N2, N4, section 0 |
| Wartime/1942-47 China volumes excluded; South Asia excluded | Scope; Decisions | section 1 |
| 1950 mission report: white troops, local armies | Finding 2 | section 4 (facts read), ctx.py output |
| 28 million film audiences | Finding 3 | section 4 (facts read) |
| 1957 Japan hedge | Finding 3 | section 4 (facts read) |
| 26 percent, lowest of thirteen surveys | Finding 3 | section 4 (facts read) |
| January 1966 summary, elites, budgets | Finding 3 | Q rows for v07/d73 are in the collection excerpts (excerpts.out); text facts read |
| poll 49 to 40, 22 to 32; "unchangeable over the short run" | Finding 4 | section 4 (facts read) and Q row for d46 |
| 1971 overseas Chinese pulled by feeling not ideology | Finding 4 | excerpts.out (PubDipv08/d149) |
| 1974 Smyser; 1977 Sullivan | Finding 5 | section 6 (vector-reached); excerpts.out |
| Beijing 1978 | Finding 5 | excerpts.out (30/d152) |
| 134 of 135 tolerant, 80 of 135 strict; 252 of 252; 15 of 15 | How this was done | share.out |
| about 26 vs 18 per thousand; about 8 vs 12 per thousand | How this was done | stats.out false-friend lines |
| 53, 33, 19 per thousand by decade | How this was done | stats.out decade table (N17) |
| 52 documents retrieved whole; 25 quoted | How this was done | section 3 |
| four documents, nearest volumes, map; two of the 25 came via vectors | How this was done | section 6 |
| all quotations and excerpts verified; all cited documents in the collection | How this was done | section 4 verification outputs |

Quotation rows (one per “ ” quotation in the overview, in order of appearance):

| ID | Overview section | Quoted text (start) | Memo line |
|---|---|---|---|
{{QTRACE}}

Every quotation in the overview is in section 4's table (Q1 to Q23); the table gives each one's SELECT.

## 9. Files in this directory

overview.md, memo.md, collection.fruscollection, queries.log; scripts (build_eap_list.py, density.py, pd_scan.py, pd_headers.py, search.py, dump.py, ctx.py, stats.py, share.py, arch.py, lots.py, json_usia.py, json_probe.py, acc.py, absent.py, final_numbers.py, titles.py, vec_setup.py, vec_nn.py, vec_ops2.py, extract_excerpts.py, build_collection.py, verify_collection.py, check_overview.py, build_memo.py); outputs (*.out); docs/ (the 52 raw documents read); excerpts.json; titles.json.

ELIDED: this memo shortens the long source text of documents (it prints quotations and anchors, not the 52 bodies, which are in docs/); it prints the top 12 or 14 rows of each ranked or frequency list, not all rows (the full lists are regenerable with the named scripts); and the scripts' python bodies are in the files named, not repeated here.
