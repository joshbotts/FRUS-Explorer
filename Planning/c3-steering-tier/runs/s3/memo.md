# Scope memo — corruption and U.S. foreign policy (run s3, 2026-10-30)

Question: *How has corruption, or allegations of corruption, affected U.S. foreign policy decisions or the conduct of diplomacy?*

All files named below are in `/Users/jbotts/frus-analysis/c3s/runs/s3/`. Every shell command is in `queries.log` in run order; SQL run through `q.sh` is logged with its full text.

## 1. Coverage (M1)

```
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;
-> 553|321749|1103|8481
```
The index holds all 553 volumes of the series (the full set), 321,749 documents, 1,103 front matter, 8,481 editorial notes. Read-only proof: `BEGIN; CREATE TABLE zz(x); ROLLBACK;` under `-readonly` failed with "attempt to write a readonly database". Every count below is conditional on this 553-volume index copy of 2026-10-25.

Working denominator (M2): non-apparatus documents, second editions dropped:
```
SELECT COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0
 AND volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2');   -> 311429
```

## 2. Scope and how it was found

**Inclusion rule (term family).** A document is in the scope set if it matches, in the index's full-text search, any of the stems for corruption, bribery, graft, kickback or embezzlement, with front matter, editorial notes and the two second editions excluded. Stems were looked up first (M3):
```
SELECT term, doc FROM frus_documents_vocab WHERE term LIKE 'brib%' OR term LIKE 'corrupt%' OR term LIKE 'graft%' OR term LIKE 'kickback%' OR term LIKE 'embezzl%'
-> bribe|431  briberi|309  corrupt|2253  corruptionist|8  corruptli|13  embezzl|174  graft|372  grafter|19  grafton|80 (excluded: a name)  kickback|18 ...
```
Family MATCH: `'corrupt* OR bribe OR briberi OR graft OR grafter OR kickback OR embezzl'`.

(M4) Raw hits: 3,163 documents in 451 volumes; 3,096 non-apparatus (first q.sh MATCH count in queries.log). (M5) With the Ed2 volumes also dropped: **3,057 documents in 447 volumes**, i.e. 3,057 of 311,429 non-apparatus documents (9.8 per 1,000):
```
SELECT COUNT(DISTINCT f.volume_id) FROM frus_documents f JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id
 WHERE frus_documents MATCH 'corrupt* OR bribe OR briberi OR graft OR grafter OR kickback OR embezzl'
 AND c.is_front_matter=0 AND c.is_editorial_note=0 AND f.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2');  -> 447
```
(3,057 is printed by `share.py`, "hit list M = 3057", same predicate ordered by volume_id, document_id.)

**Literal share (M6), family is single words, not a phrase; done anyway.** `share.py`, sample of 40 evenly spaced (index int(i*3057/40)) from the (volume_id, document_id)-sorted hit list; text = header+dateline+source_note+body_text, whitespace-collapsed; Python `re`.
- TOLERANT (re.I, `\b(corrupt\w*|brib(e|es|ed|ing|ery|eries)\b|graft\w*|kick[\s-]?backs?|embezzl\w*)`): **40 of 40**.
- STRICT (case-sensitive, base forms only `\b(corrupt|corruption|bribe|bribery|graft|kickback|embezzlement)\b`): **30 of 40**; every miss an inflection or capital (bribes, corrupted, corrupting, Embezzlement, bribing, Bribes).
- REFERENT test (hand-classified, `referent.txt`): **31 of 40** use the word of official or political corruption or bribery; 9 of 40 are other senses (decay of parcels, cable text "corrupted", "grafted on", inducements called "a bribe", extradition-treaty embezzlement, moral or jocular "corrupted"). So the family over-counts the subject by roughly a quarter; the 3,057 is an upper bound on documents about corruption.
- The garble-sense regex (`corrupt(ed)? (group|text|in transmission)…`) caught 0 of 40, but the referent reading caught one such case (frus1948v06/d51); the regex is too narrow to use as a filter.

**Second family (M7): "improper / illicit / questionable payment".** `payments.py`, census of all 27 MATCH hits (non-apparatus, Ed2 dropped) of `'"improper payment" OR "illicit payment" OR "questionable payment"'`. TOLERANT **19 of 27**, STRICT 18 of 27. 19 of 27 is below 0.80: the family is **unusable in its published form**; misses read as stemmer collisions (e.g. "question" + "payment" across punctuation). Of the 19 literal documents, 10 are in frus1977-80v03 and 4 in frus1977-80v24 (`payments.txt`); 7 of 27 also carry a corruption-family word.

**Decade shape (M8)** (`decades.txt`), periodised on document_dates.date_iso (the index's date for the document, taken from the frus:doc-dateTime-min attribute as the index stores it; not the volume's series year); per 1,000 dated non-apparatus documents, Ed2 dropped:
```
... base = document_cache JOIN document_dates (both keys) WHERE is_front_matter=0 AND is_editorial_note=0 AND volume_id NOT IN (Ed2 x2) AND date_iso IS NOT NULL;
 SELECT dec, COUNT(*), SUM(hit), 1000.0*SUM(hit)/COUNT(*) ... GROUP BY substr(date_iso,1,3)
```
| decade | dated docs | hits | per 1,000 |
|---|---|---|---|
| 1860s | 11,268 | 109 | 9.7 |
| 1870s | 5,821 | 103 | 17.7 |
| 1880s | 6,484 | 82 | 12.6 |
| 1890s | 9,845 | 124 | 12.6 |
| 1900s | 10,261 | 112 | 10.9 |
| 1910s | 30,842 | 191 | 6.2 |
| 1920s | 20,374 | 80 | 3.9 |
| 1930s | 40,073 | 121 | 3.0 |
| 1940s | 75,872 | 477 | 6.3 |
| 1950s | 42,801 | 556 | 13.0 |
| 1960s | 27,654 | 558 | 20.2 |
| 1970s | 22,258 | 435 | 19.5 |
| 1980s | 6,038 | 104 | 17.2 |
| 1990s | 177 | 0 | 0.0 |

Top-volume shares not computed per decade; the top volumes overall (`topvols.txt`, non-apparatus, Ed2 not yet dropped): frus1947v07 71, frus1894app2 49, frus1964-68v05 42, frus1958-60v01 39, frus1948v07 38. The 1890s rate leans on frus1894app2 (Hawaii, 49 of the 124 1890s hits at most). Rates are not adjusted for the 18 reprinted copies (§VECTORS) or the referent rate (31 of 40).

**Controls (M9)**, same surface (FTS index), same session:
- Positive `"Department of State"`: present in 552 of 553 volumes; the one without it, frus1919Parisv05 (Paris Peace Conference minutes, 90 documents), is searchable (`state` matches 89 of 90) and has 2 family hits.
- Negative `ZZZ_IMPOSSIBLE_ZZZ`: 0. Relaxed `zzz*`: 0 (no such stem; the negative needs no relaxation).

**Reading the hits.** Top 80 by bm25 (`top_bm25.txt`; `ORDER BY bm25(frus_documents)`). From them I chose five threads and read documents whole.

## 3. Documents read (M10)

Reading SELECT (read.py): `SELECT header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?`; raw text in `raw/<volume>__<doc>.txt`.
**17 documents retrieved whole**, 202,357 characters (`SUM(length(body_text))` over the 17, logged): frus1944v06/d292, frus1947v07/d583, frus1948v07/d43, frus1948v07/d471, frus1969-76ve12/d418, frus1969-76ve09p2/d122, frus1969-76ve15p2/d292, frus1977-80v03/d248, frus1969-76ve11p1/d159, frus1961-63v22/d244, frus1961-63v23/d356, frus1922v01/d841, frus1977-80v18/d154, frus1969-76ve09p2/d155, frus1948v07/d68, frus1969-76v31/d138, frus1969-76v31/d145. **12 cited and quoted** (13 quotations). Read but not cited: ve12/d418 ("venal and corrupt" banter about Thai leaders: not substantive), 1977-80v18/d154 and 1948v07/d68 (vector leads with no corruption content), v31/d138 and d145 (OECD 1976 bribery language: thread not taken up).

## 4. Quotations (M11), each verified

`verify.py`: each quote is an exact substring of the whitespace-collapsed body_text (`SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?`) AND of the raw dump: **13 of 13 verified**; `build_collection.py` re-checked each excerpt and all 13 are exact substrings of body_text without collapsing.

| # | pair | quotation |
|---|---|---|
| Q1 | frus1922v01/d841 | "I have not been able to present much in the way of specific instances of corruption. There is here almost a conspiracy to conceal facts" |
| Q2 | frus1944v06/d292 | "graft, bribery and corruption are standard practices to be found in every section of the province" |
| Q3 | frus1947v07/d583 | "A thorough investigation should be made into the charges of corruption among army officers" |
| Q4 | frus1948v07/d43 | "many US reporters, when they come across any corruption or graft, play up the cases, making the US public believe that the entire Chinese Government is corrupt" (Hollington Tong, as translated in Stuart's telegram) |
| Q5 | frus1948v07/d471 | "Nationalist failures in suppression rebellion entirely due to Nationalist corruption and impotence" (Fu Tso-yi's speech, as transmitted by Clubb) |
| Q6 | frus1961-63v22/d244 | "Military government’s efforts to deal with wholesale graft, bribery and corruption in government and business" |
| Q7 | frus1961-63v23/d356 | "the graft and corruption in the Garcia Administration which he views as the principal cause for the low state of Garcia’s public image" |
| Q8 | frus1969-76ve09p2/d122 | "As we have watched corruption mount we have asked ourselves what we might do to counter it—not from any moralistic concern, but as a means of guarding U.S. interests." |
| Q9 | frus1969-76ve09p2/d122 | "Our own U.S. government reputation for incorruptability may one day prove to be our most valued asset in Saudi Arabia." |
| Q10 | frus1969-76ve11p1/d159 | "The Department just learned of the bribe. It refused to help cover it up." |
| Q11 | frus1969-76ve09p2/d155 | "Problems arising from publicity over the enormous commissions being paid by American firms to promote sales of defense articles and services to the Saudi Government threaten to strain US-Saudi relations." |
| Q12 | frus1969-76ve15p2/d292 | "At that point apparently, Lockheed bribed Prince Bernard to weigh in with the Germans." |
| Q13 | frus1977-80v03/d248 | "As a nation we have decided that bribery in international trade is reprehensible and that American companies must forego exports that can be attained only by illicit payments." |

Edition metadata (`cited_meta.json`, from manifest.json titles and document_cache.document_number): every cited document's printed number equals its id's numeral.

## 5. Archival scope (M12–M14), two channels, never summed

Scope: the 3,057-document set. Counting surface: the index's document_sources (came-from) and external_citations (pointed-at) tables.

**Came-from (M12)** (`camefrom.txt`): 2,547 of 3,057 documents have a source row.
```
... h = family hit set ...; SELECT s.citation_era, COUNT(*) FROM h JOIN document_sources s ON s.volume_id=h.volume_id AND s.document_id=h.document_id GROUP BY 1
-> decimal 1297, structured 637, lot_file 202, subject_numeric 182, cfpf 119, named_series 59, published 34, unrecognized 15, foreign 2
SELECT s.repository, s.record_group, coalesce(s.lot_file_norm, s.series_name), COUNT(*) ... GROUP BY 1,2,3 ORDER BY n DESC LIMIT 25
```
Top: Central Intelligence Agency 117; Nixon Presidential Materials, NSC Files 95; Johnson Library, National Security File 77; Carter Library, National Security Affairs 56; RG 59 Central Files 1970–73 43, 1967–69 40, 1964–66 23; Kennedy Library NSF 29; Eisenhower Library Whitman File 26; Ford Library National Security Adviser 26; RG 59 Lot 54D270 17; Lot 63D351 16; CFPF 16; Lot 62D430 7.
(citation_era is a citation form, not a date.)

**Pointed-at (M13)** (`pointedat.txt`): 746 rows over 435 documents. Anchors: centralFileClass 448, presidentialLibrary 162, lotFile 136. Ranked: central file classes (Department of State) 448; Carter Library National Security Affairs 41; Johnson Library NSF 28; Nixon NSC Files 27; Lot 66D95 17; Lot 63D351 12; Eisenhower Whitman File 7; Lot 62D1 6; Lot 62D430 6; Lot 89D149 6. The pointed-at channel has no row before 1910-12-06 and stores the citation fragment, lot, library and decimal anchors only (house-rule statement, not re-measured).

**Resolution through the bundled JSON (M14)** (`lots.py`, `sfacts.py`, presidential-library lookup in queries.log; central-files-index and series-facts-index schemaVersion 3, generated 2026-09-10; presidential-library-catalog schemaVersion 1, generated 2026-08-06):
| unit | channel | resolution |
|---|---|---|
| Lot 63D351 | came-from 16, pointed-at 12 | RG 59, naId 2839192, entry A1 1586E, "Records Relating to National Security Council Policy Papers", creator Executive Secretariat, inclusive 1947–1979, 26 ft 3 in, access Restricted – Partly (FOIA b1), College Park |
| Lot 66D95 | pointed-at 17 | same series, naId 2839192, A1 1586E |
| Lot 62D430 | came-from 7, pointed-at 6 | RG 59, naId 2839191, A1 1586C, "Subject and Special Files", 1953–1961, Restricted – Partly |
| Lot 62D1 | pointed-at 6 | RG 59, naId 2838992, A1 1583E/A1 1583F, "Records Relating to Activities with the National Security Council", creator Policy Planning Council, 1948–1961, Restricted – Partly |
| Lot 54D270 | came-from 17 | not in central-files-index; curated-lot-resolutions: "Marshall Mission Files", RG 59, NARA arranged under creator naId 10481258 (Office of the Special Envoy to China) as ten series; collection-authority volumes frus1944v06, 1945v07, 1946v09, 1946v10, 1947v07 |
| Lot 79F80 (RG 84, Jidda post files; source of d122) | came-from | not resolved (`lots.py 79F80` -> null) |
| Kennedy NSF | both | presidential-library-catalog JFK-4, naId 1164, 1961–1963 (match by title; access status not in the bundle) |
| Johnson NSF | both | LBJ-NSF, naId 567979, 1963–1969 |
| Nixon NSC Files | both | RN-NSF "National Security Files (Nixon Administration)", naId 572235, 1969–1974 (title match, unverified) |
| Carter National Security Affairs | both | not resolved (catalog has only JC-NSC Institutional Files, naId 623746) |
| Eisenhower Whitman File | both | not resolved with confidence (catalog's "Ann C. Whitman Papers" DDE-1424 naId 643447 is not obviously the Ann Whitman File) |
| Central Decimal File (1,297 decimal-form sources) | came-from | no series naId in central-files-index; d841's file is 837.51/764 (not glossed) |

Pre-1940 reach of the offline stack (M15): series-facts-index byNaId rows with an inclusive start year: 698; starting before 1940: **11 of 698** (`sfacts.py`). The pre-war part of the roadmap (Cuba 1922) has no bundled series row; that is the stack's reach, not an archival absence.
NARA creator headings above are NARA's and were not verified against finding aids.

## 6. Absences and limits (M16–M19)

- (M16) Nothing after the series: 1990s, 177 dated documents, 0 hits (decade table). Relaxed (widen to the 1980s): 104 of 6,038.
- (M17) `"foreign corrupt practic*"`: 4 documents in 2 volumes (frus1977-80v03/d152, d230, d248; frus1977-80v18/d57) — thin. `oecd AND (bribe OR briberi)`: 12 documents, 1976–1980 (7 in frus1969-76v31).
- (M18) `klepto*`: 0 vocabulary rows (`term LIKE 'klepto%'`); relaxed: `anticorrupt` 4 documents, phrase `"anti corrupt*"` 54 documents (top: frus1964-68v05 8, frus1950v05 6).
- (M19) Withheld text: of 580 family hits dated from 1969-01-20, 104 contain "not declassified" (SQL LIKE, case-insensitive):
```
... h7 = hit set JOIN document_dates (both keys) WHERE date_iso >= '1969-01-20'; SELECT COUNT(*), SUM(c.body_text LIKE '%not declassified%') FROM h7 JOIN document_cache c (both keys) -> 580|104
```
- Crowder's Memorandum No. 8 on "Graft, Corruption and Immorality in the Public Administration" is marked "Not printed" in frus1922v01/d841.
- Church subcommittee: `"church subcommittee" OR "church committee"` matches 113 documents (not read); the committee's and the SEC's own records are not a FRUS surface and no bundled index names them.
- Threads in the hit set left unread: South Vietnam (frus1964-68v05 42 hits), Iran 1951–54 (32), Southeast Asia 1958 (frus1958-60v01 39), Congo covert payments (frus1964-68v23/d91 in the share sample).

## VECTORS

All cosines below are raw. (None is used: every figure is a Hamming distance on 512-bit sign vectors.)

**Provenance (V1)** (`vec.py`, output `vectors.txt`): digest `89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101` from all six: the index's provenanceDigest, binary bytes 20–51, map bytes 20–51, shards manifest, shard frus1947v07.vec bytes 16–47, and the shard folder's .generation. All agree. Index `generated` 2026-10-15. Header: 314,616 documents, 512 dims, 660 centroids. Round trip: decoded length = n for all 553 volumes (assert), 314,616 rows. retrieval.scoreCalibration: documentOffset 0.4, queryOffset 0.47 (not applied; no percentage compared).

**Baselines at this digest (V2):** random pairs (20,000, seed 1877): mean 167.1, sd 14.8, 1st percentile 132. 25th-neighbour distance over 200 random rows (seed 1878): min 73, p10 93, median 107, p90 119. Near-duplicate line = mean − 8 sd = 49.0.

**Required op 1: nearest 25 of four anchors, over the Tier-1 binary, joined on both keys to document_cache and document_dates, flagged scope / decade / literal (V3).** Scope = the 3,057 family set; literal regex (re.I) `corrupt\w*|brib\w*|graft\w*|kick-?backs?|embezzl\w*|pay-?offs?|illicit payment|improper payment|questionable payment`. Read against the 25th-neighbour distribution.
- frus1947v07/d583 (Sprouse, 1947): nearest 82–93, all inside or below the random-row median 107: tightly embedded in the China 1947–48 reporting. 12 of 25 in scope; 13 outside, all ABSENT. Read the nearest outside: frus1948v07/d68 (Clubb, 82) — no corruption content.
- frus1969-76ve09p2/d122 (Jidda airgram, 1974): nearest frus1977-80v18/d154 (West report, 81, OUTSIDE/ABSENT) — read whole, no corruption content. **frus1969-76ve09p2/d155 (103, OUTSIDE, LITERAL)** — read whole: Atherton's 1975 briefing on agents' fees ("improper payments", "illicit payments") — **added to the scope and the collection**.
- frus1969-76ve11p1/d159 (United Brands, 1975): nearest at 119–138, at or beyond the p90 of the k-th distribution: no close neighbours; all 25 OUTSIDE/ABSENT (Honduras and Central America files). Nothing read from this list.
- frus1922v01/d841 (Crowder, 1922): nearest frus1922v01/d842 (73, in scope) and 24 more Crowder telegrams 1921–23; not read (the thread is one document in this run).
No anchor's list contained a volume absent from document_cache (the index holds all 553).

**Required op 2: near-duplicates before any count (V4).** Over the 3,057 set: 66 pairs under 49.0. Both texts of each pair compared by `dupcheck.py` (difflib ratio on whitespace-collapsed first 6,000 characters of body_text; agree at ≥ 0.90) — a mechanical comparison, not a human reading of 132 documents; declared as such. **18 of 66 pairs agree**; union-find gives 18 components, 18 redundant copies (`dup_components.txt`; e.g. frus1933v02/d593 = frus1933-39/d31, frus1951-54Iran/d355 = frus1952-54v10/d403, frus1969-76v12/d212 = frus1969-76ve10/d225; seven are 1894 Nicaragua/Hawaii appendix reprints). The set therefore holds at most 3,039 distinct texts (3,057 − 18); the decade rates above are not adjusted. The 48 other pairs are similar but different documents (e.g. sequential telegrams). Over the 12 cited documents: nearest-in-set distances 114–152, no pair under the line; every cited document counted once.

**Conditional op: the map (V5).** Not run: no claim here depends on whether corruption forms a region, and no cluster figure is given.

**Vector-reached documents among those the overview cites (V6).**
- STRICT: frus1969-76ve09p2/d155. Re-run against the pair: the family MATCH restricted to `volume_id='frus1969-76ve09p2' AND document_id='d155'` returns 0; `"improper payments" OR "illicit payments"` against it returns 1, but that query was run only after the neighbour list surfaced it. No earlier logged query (top_bm25, header hits, share sample) returned it.
- PRACTICAL: the same document; it was in no result set I had read. It sits in a volume already in scope (ve09p2), so it is a within-volume find.
- No other cited document was vector-reached.

## 7. Trace table (overview -> memo)

| overview item | memo |
|---|---|
| "all 553 volumes"; "about one document in a hundred" | §1 M1, M2; §2 M5 (3,057 of 311,429) |
| "about three in four of a sample use the word in the political sense" | §2 M6 referent 31 of 40 |
| decade rise from the 1940s to the 1960s–70s; peak about one in fifty in the 1960s and 1970s | §2 M8 (20.2 and 19.5 per 1,000) |
| "a few dozen texts printed twice" (18) | VECTORS V4 |
| "about one matching document in six from 1969 on" withheld text | §6 M19 (104 of 580) |
| no 1990s document matched | §6 M16 |
| law named in only four documents | §6 M17 |
| no word for "kleptocracy" | §6 M18 |
| "Department of State" control in every volume but one | §2 M9 |
| channel series and identifiers in paragraph 2 | §5 M12–M14 |
| pre-1940 reach, 11 of 698 series | §5 M15 |
| seventeen documents read whole, twelve cited | §3 M10 |
| Q1–Q13 | §4 M11 |
| Atherton briefing found by similarity | VECTORS V3, V6 |
| "about twenty Crowder telegrams" that do not use the words | VECTORS V3 (20 of the 25 nearest to frus1922v01/d841 are OUTSIDE/ABSENT) |
| "the 1980s still hold about a hundred" | §6 M16 (104) |
| "about one in three hundred in the 1930s", "one in fifty" | §2 M8 (3.0; 20.2, 19.5 per 1,000) |
| "about eighteen documents printed twice" | VECTORS V4 |

## 8. Checks before finishing

Every quotation in the overview and every excerpt in the collection is one of Q1–Q13, verified (verify.py 13 of 13; build_collection.py substring check). Every document the overview cites (12) is in the collection; the collection holds those 12 and no others; every pair exists in document_cache; no duplicates; no Ed2 volume.
