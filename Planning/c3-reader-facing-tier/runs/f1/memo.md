# Scope memo — American "soft power" in East Asia and the Pacific (run f1, 2026-10-31)

Operator memo. Every number below gives its query or script; scripts and their outputs are in
`/Users/jbotts/frus-analysis/c3f/runs/f1/`. Commands are listed in order in `queries.log`.
DB = `/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db`, opened read-only throughout (through `q.sh`, which runs `sqlite3 -readonly`, or Python `?mode=ro`).

## M0. Coverage and controls

- **M0.1 Coverage:** `SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;` → `553|321749|1103|8481`. All 553 volumes of the series are in this index. Every count is conditional on this 553-volume library.
- **M0.2 Read-only proof:** `BEGIN; CREATE TABLE zz(x); ROLLBACK;` → `attempt to write a readonly database`.
- **M0.3 Positive control.** Query: `SELECT COUNT(*), COUNT(DISTINCT d.volume_id) FROM frus_documents f JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id WHERE frus_documents MATCH '"department of state"' AND d.is_front_matter=0 AND d.is_editorial_note=0;`
  - Result: 94049 documents in 552 volumes.
  - The one volume without it is frus1919Parisv05, found with `SELECT DISTINCT volume_id FROM document_cache WHERE volume_id NOT IN (…same…)`.
- **M0.4 Negative control.** The same query with `ZZZ_IMPOSSIBLE_ZZZ` returned 0|0. It ran in the same pass as M1.1.

## M1. Scoping: vocabulary, false friends, and the scope set

Same FTS form as M0.3: count of non-apparatus documents, then count of distinct volumes.

- **M1.1 Term census (corpus-wide, 1861–1988):**

  | Search term | Documents | Volumes |
  |---|---|---|
  | "soft power" | 0 | 0 |
  | USIA | 1965 | 213 |
  | USIS | 1242 | 184 |
  | "information program" | 592 | 169 |
  | "psychological warfare" | 642 | 175 |
  | "psychological strategy" | 157 | 34 |
  | propaganda | 12107 | 516 |
  | "voice of america" | 542 | 139 |
  | "american image" | 25 | 17 |
  | "image of the united states" | 43 | 35 |
  | "cultural exchange" | 662 | 172 |
  | "public diplomacy" | 211 | 38 |
  | "public opinion" | 10292 | 548 |

  These are index matches (porter stems), NOT literal counts. None of them is published in the overview except the zero for "soft power", which needs no share. The phrase counts carry no literal share and must not be quoted.
- **M1.2 False-friend test** (terms the question supplied). The on-topic set is the four public-diplomacy volumes PubDipv06, PubDipv07 and PubDipv08 plus frus1977-80v30, holding 721 non-apparatus documents. It is compared with the corpus's 312,169 non-apparatus documents.
  - Query: `SELECT SUM(d.volume_id IN PD), (SELECT COUNT(*) … IN PD …), COUNT(*), (SELECT COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0) FROM frus_documents f JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id WHERE frus_documents MATCH '<t>' AND …`

  | Term | Public-diplomacy volumes | Corpus |
  |---|---|---|
  | "soft power" | 0 of 721 | 0 of 312169 |
  | messaging (index stem `messag`) | 125 of 721 | 32754 of 312169 |
  | audience | 200 of 721 | 2834 of 312169 |
  | control: "department of state" | 226 of 721 | 94049 of 312169 |

  - "messaging" in the index is the stem of "message". Its rate in the on-topic volumes (about 1 in 6) is near the corpus rate (about 1 in 10), and the control's rates are almost equal (31 against 30 per 100). It is therefore measuring the corpus's word "message", not the question, and I stopped using it.
  - Literal check: `SELECT COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0 AND body_text LIKE '%messaging%';` → 3. This is SQL LIKE, case-insensitive, over body_text only.
  - "audience" is strongly topical: 200 of 721 against 2834 of 312169.
- **M1.3 Editors' chapter headings** (`headings.py`, output `headings.txt`). The editors' formula is "Information Policy" (1961–63 v25), "United States Foreign Information Program" (1955–57 v9), "International Information Policy, Public Diplomacy, and Cultural Affairs" (1969–76 v38 pt 2), and "Public Diplomacy" (the 1917–72 vols VI–VIII and 1977–80 v30). The PubDip volumes are organised by year, not by region.
- **M1.4 Volumes missing from the indexed library** (`manifest_scan2.txt` plus the inline manifest scan in `queries.log`). Among the 553, the 1917–1972 public-diplomacy sub-series has only "World War I" and vols VI–VIII (1961–72). No public-diplomacy volume covers 1945–1960, and none covers 1981–88. The thirteen 1981–88 volumes indexed are not public-diplomacy volumes.
- **M1.5 Scope set** (`scope.py`, output `scope_out.txt`, pairs in `scope_hits.json`). The SQL, as printed by the script:
  ```
  SELECT d.volume_id, d.document_id FROM frus_documents f JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE frus_documents MATCH '(USIA OR USIS OR "information program" OR "psychological warfare" OR "psychological strategy" OR "psychological operations" OR "voice of america" OR "public diplomacy" OR "cultural exchange" OR "information agency" OR "information activities" OR "image of the united states" OR "american image" OR "U.S. image") AND (asia OR asian OR "far east" OR japan OR japanese OR china OR chinese OR korea OR korean OR vietnam OR vietnamese OR indochina OR philippines OR indonesia OR thailand OR laos OR cambodia OR burma OR malaya OR malaysia OR singapore OR taiwan OR australia OR pacific)' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') AND dd.date_iso>='1945-01-01' AND dd.date_iso<'1981-01-01' ORDER BY d.volume_id, d.document_id
  ```
  - Result: **2860 documents in 273 volumes**, counted in the index with apparatus excluded and the second editions dropped.
  - Dating uses `document_dates.date_iso`, the index's document date. It derives from `frus:doc-dateTime-min` after the app's same-day correction, and is not the volume's series year.
- **M1.6 Literal share of the scope set** (`scope.py`; Python `re` with `re.IGNORECASE`, used for the whole family). The text surface is header + dateline + source_note + body_text, concatenated and whitespace-collapsed. The sample is 40, evenly spaced from the (volume_id, document_id)-sorted list of 2860.
  - STRICT (exact phrases, single spaces): **35 of 40** contain an information-family literal and a geography literal.
  - TOLERANT (each word may take inflections; any run of space, hyphen, comma, parenthesis or full stop between words): **36 of 40**.
  - The geography family alone matched 40 of 40.
  - Misses, read through FTS `snippet()`: frus1947v06/d693, frus1948v06/d142 and frus1949v07p1/d296 matched on the token `USI`. The index stems USIS to `usi`, so it matches the bare abbreviation "USI", which 1946–1950 documents use for Indonesia; for example frus1949v07p1/d296 reads "stable non-Communist USI". frus1951v06p2/d494 matched on `USIE`, which IS on topic (the U.S. Information and Educational Exchange program) but was absent from my regex.
- **M1.7 Census of all 2860** (`census.py`, output `census_out.txt`, rows in `census.json`). The tolerant regex now includes USIE.
  - **2692 of 2860** contain an information-family literal and a geography literal.
  - 165 lack an information-family literal; 161 of those contain the bare token `USI` (case-sensitive `\bUSI\b`).
  - Only 9 of the 161 spell out "United States of Indonesia" (re.I), but all 161 sit in the 1946–1950 Indonesia-bearing Far East volumes: frus1948v06 84, frus1949v07p1 56, frus1947v06 14, frus1946v08 3, frus1950v06 2, frus1949v09 1.
  - The confirmed set is **2692 documents in 273 volumes** (`scope_confirmed.csv`). The overview's "about 2,700" and "273 volumes" are this set, and its "about 94 in every 100" is 2692 of 2860.
  - The phrase-family share therefore tests the literal words, not the referent. The referent was tested by reading (M3).
- **M1.8 Decade shape** (index hits before the M1.7 literal correction; no 1945 floor; Ed2 dropped; apparatus excluded; dated by `date_iso`). Query: the `WITH hits AS (…MATCH INFO AND GEO…), base AS (SELECT substr(dd.date_iso,1,3) dec, COUNT(*) n FROM document_cache d JOIN document_dates dd … WHERE non-apparatus AND not Ed2 GROUP BY 1)` query in `queries.log`.

  | Decade | Hits | Dated non-apparatus documents | Per 1,000 | Top volume's hits |
  |---|---|---|---|---|
  | 1940s | 404 | 75872 | 5.3 | 92 |
  | 1950s | 1019 | 42801 | 23.8 | 43 |
  | 1960s | 973 | 27654 | 35.2 | 86 |
  | 1970s | 466 | 22258 | 20.9 | 56 |
  | 1980s | 125 | 6038 | 20.7 | 33 |

  - The 1940s figure is inflated by the USI false friend: frus1948v06's 92 hits include 84 USI documents (M1.7). Not published in the overview.
  - Denominators differ from the house rules' 74,043 for the 1940s because my base counts every dated non-apparatus document with Ed2 dropped.
- **M1.8a Survey vocabulary** (scoping only; unaudited single-word stems, not published). INFO AND (survey OR surveys OR poll OR polls) AND an Asian place returned 277 documents; INFO AND "office of research" returned 30; INFO AND "opinion research" returned 7. Same FTS form as M0.3.

## M2. How the reading set was chosen

1. **Header query** (`header_hits.txt`, 330 rows). The header had to name an information term, while INFO and GEO matched anywhere, with `date_iso>='1945'`. I then kept rows whose header names an Asian place (`grep -iE` in `queries.log`): 57 rows (`header_hits_asia.txt`). Near East, South Asia and Soviet-bloc office headers were set aside by reading.
2. **BM25 query** over the INFO family within 25 East Asian regional volumes, `ORDER BY bm25 ASC LIMIT 40` (`ea_bm25.txt`).
3. **Reading list** of 46 pairs (`readlist.txt`), dumped by `dump.py`. Its SQL: `SELECT header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0`. It writes `raw/<vol>__<doc>.txt` with BODYLEN = length(body_text).
4. **Two more pairs** reached through the vector neighbours (M5) went into `read2.txt`: frus1955-57v09/d190 and frus1917-72PubDipv08/d99.

**Reading accounting:**
- **48 documents retrieved whole.** Each file's captured length equals length(body_text), 392,917 characters in all.
- I read 8 entire: frus1950v06/d50, frus1952-54v03/d475, frus1952-54v12p2/d396, frus1955-57v22/d447, frus1961-63v01/d49, frus1961-63v01/d265, frus1961-63v02/d5 and frus1964-68v27/d386. Of the other 40, I read the opening 1,800–7,000 characters of 11 and, for all 40, the passages that keyword-in-context passes found (`queries.log`: the KWIC regex over `raw/*.txt` and the targeted `find()` reads of PubDipv07/d85 and PubDipv08/d31). Each quoted passage was read in its surrounding context, at least 200 characters either side.
- **22 documents quoted** (28 passages).
- **Inclusion rule for the argument set (22):** a document in the confirmed scope set (M1.7) in which an official assesses, plans or measures the American image or the information, cultural or psychological program toward an audience in East Asia or the Pacific. Purely tactical operations and press-procedure documents were excluded.
- All 22 are in `scope_confirmed.csv`, checked by script: "all in confirmed: True".
- Read but not used: frus1952-54v03/d475, frus1952-54v12p2/d396, frus1955-57v22/d448, frus1955-57v23p1/d249 (Ryukyus), frus1961-63v02/d5, d179, d311, the PubDipv06 Laos and Hilsman exchanges (d103, d110–d112, d128, d133, d146), frus1961-63v04/d81 (a reprint of PubDipv06/d140), PubDipv07/d103 and d171, frus1964-68v26/d106, PubDipv08/d24, d30, d92, d121, d127, d143 and d146, and frus1977-80v30/d2.

## M3. Quotations (every one verified)

Verifier: `verify.py`, output `verify_out.txt`.
- SELECT: `SELECT body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0`.
- Each passage is an exact substring of the raw body_text: 28 of 28 exact_in_body=True, FAILED: 0.
- The raw text of each is on disk at `raw/<vol>__<doc>.txt`.

| # | Pair | Length (characters) | Passage (verbatim) |
|---|---|---|---|
| Q1 | frus1950v06/d50 | 6446 | the generally meager knowledge and understanding of the United States on the part of the peoples of this area |
| Q2 | frus1952-54v13p1/d116 | 8958 | Since many new customs FE can be traced to Amer films, must be assumed that films is effective program though difficult to determine degree. |
| Q3 | frus1952-54v13p1/d116 | | Commie propaganda which exploits nationalist and racial feeling |
| Q4 | frus1952-54v12p2/d403 | 8401 | utilizing every suitable operation to prepare the minds and emotions of the people to collaborate in the effort |
| Q5 | frus1955-57v09/d190 | 51295 | In the Far East USIA was forced to deal with mixed emotions regarding the use of atomic weapons against Asiatic peoples, and to counter communist propaganda designed to stir up race hatred. |
| Q6 | frus1955-57v22/d447 | 3751 | a fear of placing the U.S. in the position of appearing to support colonialism |
| Q7 | frus1961-63v01/d49 | 1711 | We are in the process of cranking up a major propaganda campaign on Viet Cong insurgency in VietNam. |
| Q8 | frus1961-63v01/d265 | 3369 | But the spectre of charges that “U.S. imperialists are waging germ warfare on Asians” haunts me. |
| Q9 | frus1961-63v02/d16 | 5995 | the image of the GVN in the world press can be no better than the face the GVN presents to the public |
| Q10 | frus1917-72PubDipv06/d140 | 13295 | With Orientals in general and notably with the Ngo Dinhs, capitulation is virtually impossible if they are painted into a corner. |
| Q11 | frus1917-72PubDipv06/d140 | | the U.S. image was being hurt |
| Q12 | frus1917-72PubDipv06/d126 | 4751 | much of our audience would tend to regard it as mere words without deeds |
| Q13 | frus1917-72PubDipv07/d73 | 4186 | In all cases, however, the image of American strength, reliability and friendship is basic to our objectives. |
| Q14 | frus1917-72PubDipv07/d73 | | In almost every country of the area, our programs are directed at elite groups |
| Q15 | frus1917-72PubDipv07/d85 | 19705 | there is an unfortunately large amount of anti-Americanism under the surface in Viet-Nam |
| Q16 | frus1917-72PubDipv08/d31 | 20792 | Asians are, to varying degrees, America watchers. |
| Q17 | frus1917-72PubDipv08/d31 | | PAOs emphasized that the image of the US usually depended more on the state of bi-lateral relations |
| Q18 | frus1917-72PubDipv08/d31 | | the total exercise as presently constituted has not been worth the effort |
| Q19 | frus1917-72PubDipv08/d149 | 10253 | The predominant mood is apolitical, seeking to be neutral, and concerned with economic and trade problems rather than strong ideological convictions. |
| Q20 | frus1917-72PubDipv07/d32 | 27974 | The teams have given us more of an insight into rural attitudes than any other device that has been used. |
| Q21 | frus1917-72PubDipv08/d88 | 1861 | Rating of the U.S. as a dependable ally of SVN reached the lowest point in thirteen Saigon surveys |
| Q22 | frus1969-76v19p2/d67 | 3697 | public opinion surveys and other assessments of Japanese attitudes have tended to confirm the seriousness of these strains |
| Q23 | frus1964-68v27/d386 | 1589 | The Thai Government has not given proper attention to the need for a national information program designed to gain popular support. |
| Q24 | frus1917-72PubDipv08/d58 | 4685 | USIA has, from the beginning, considered its psychological operations (PSYOP) support program in Viet-Nam as short-term in nature. |
| Q25 | frus1917-72PubDipv08/d99 | 25695 | it will disengage as rapidly as feasible from information support to governments there |
| Q26 | frus1917-72PubDipv08/d99 | | Far from taking for granted a favorable psychological climate in Japan and key countries of Western Europe |
| Q27 | frus1969-76v38p2/d105 | 11622 | programs on U.S. security relations in Asia lack credibility and may in fact do damage to our relations |
| Q28 | frus1977-80v30/d79 | 2409 | shoring up the confidence of East Asians in America’s long-term staying power and positive involvement in the area is real and necessary |

The overview quotes shorter substrings of several of these, marked with … where cut. A script check is in `queries.log`: every quoted span in the overview that is a document passage was matched against this table, and all matched. The remaining quoted spans are search terms ("soft power", "messaging", "message", "Department of State", "USI", "East Asia and Pacific", "Far East") or the class gloss in M4.4, which comes from the bundled JSON, not from a document.

Two passages need a reading note:
- **Q10/Q11 duplicate.** The same memorandum is printed as frus1961-63v04/d81, and that copy reads "painted into a comer" (an OCR-type error). I cite the PubDip copy.
- **Q2 wording.** The telegram's own grammar ("films is") is preserved verbatim.

## M4. Archival scope (two channels, never summed)

- **M4.1 Came-from** (`document_sources`). Scope = the confirmed 2692 (`archival.py scope_confirmed.csv`, output `archival_scope.txt`).
  - Q1: `SELECT coalesce(ds.repository,'?'),coalesce(ds.record_group,'-'),coalesce(ds.lot_file_norm,'-'),coalesce(substr(ds.series_name,1,60),'-'),ds.citation_era,COUNT(*) FROM s JOIN document_sources ds ON ds.volume_id=s.v AND ds.document_id=s.d GROUP BY 1,2,3,4,5 ORDER BY 6 DESC LIMIT 25`, where s is a temporary table of the pairs.
  - 2690 of 2692 have a row. Top rows, in documents:

    | Source | Documents |
    |---|---|
    | Nixon Presidential Materials, NSC Files | 161 |
    | Johnson Library, NSF | 113 |
    | Eisenhower Library, Whitman File | 106 |
    | Lot 63D351 | 73 |
    | Kennedy Library, NSF | 70 |
    | Carter Library, NSA | 53 |
    | CIA | 49 |
    | Eisenhower papers | 49 |
    | RG 59 Central Files 1964–66 | 34 |
    | Lot 62D430 | 29 |
    | RG 306 Director's Subject Files | 29 |
    | Lot 61D385 | 14 |
    | RG 306 DIRCTR Sub Files | 12 |
    | Lot 62D333 | 10 |
    | Lot 67D54 | 10 |

  - citation_era is a citation form, not a date.
- **M4.2 Pointed-at** (`external_citations`, distinct documents). Same scope.
  - Q2: `SELECT coalesce(ec.repository,'?'),coalesce(substr(ec.collection,1,60),'-'),coalesce(ec.lot_file_norm,'-'),ec.anchor,COUNT(DISTINCT ec.volume_id||'/'||ec.document_id) FROM s JOIN external_citations ec ON … GROUP BY 1,2,3,4 ORDER BY 5 DESC LIMIT 20`.
  - Top rows:

    | Cited | Documents |
    |---|---|
    | centralFileClass | 302 |
    | Lot 66D95 | 108 |
    | Lot 63D351 | 66 |
    | Nixon NSC Files | 62 |
    | Johnson NSF | 40 |
    | Lot 62D430 | 29 |
    | Carter NSA | 27 |
    | Whitman File | 23 |
    | Kennedy NSF | 22 |
    | Lot 62D1 | 18 |

  - This channel has no row before 1910-12-06, stores citation fragments, and holds lot, library and decimal anchors only. It is not ranked further here.
- **M4.3 Argument set (22)** (`archival.py argset.csv`, output `archival_argset.txt`).
  - Came-from: 22 of 22 have a row. RG 306 USIA files account for 13 rows: Director's Subject Files and its variants; DIRCTR Files Bx 33–36, two documents; Office of Policy and Plans; Office of the Director Box 130; USIA/TOP FRC 67 A 222; and USIA/I/S FRC 68 A 4933.
  - Also came-from: RG 59 decimal files 511.90/6–2150, 511.51G/9–2052 and 790.5/9–1453; Lot 61D385; Lot 63D351; Johnson NSF; Kennedy NSF; Nixon NSC Files; and one row each recorded as "RG 305, Records of the USIA" (frus1969-76v38p2/d105) and "RG 34" (frus1961-63v01/d49). These two are as printed in the source notes. I did not correct them, though the record group numbers look doubtful.
  - Pointed-at (query in `queries.log`, `SELECT … FROM external_citations ec WHERE (ec.volume_id,ec.document_id) IN (VALUES …22 pairs…)`), 8 rows:

    | Cited | Document |
    |---|---|
    | 511.90/7–550 | frus1950v06/d50 |
    | 511.00/8–2352 | frus1952-54v13p1/d116 |
    | 511.00/6–3055, 511.00/5–2755 and 6–655, 511.00/4–2455 | frus1955-57v09/d190 |
    | Lot 61 D 385 | frus1955-57v22/d447 |
    | Lot 58 D 726 | frus1955-57v22/d447 |
    | Kennedy NSF Meetings and Memoranda | frus1917-72PubDipv06/d140 |

- **M4.4 Resolutions** (`resolve.py`: central-files-index `lotFiles` by `lotNumber`, then series-facts-index `byNaId` through its legend).

  | Lot | Record group, entry | NAID | Series | Creator | Dates | Extent | Access | Use |
  |---|---|---|---|---|---|---|---|---|
  | 63D351, 66D95 | RG 59, A1 1586E | 2839192 | Records Relating to National Security Council Policy Papers | Executive Secretariat | 1947–1979 | 26 linear feet 3 inches | Restricted – Partly | Restricted – Possibly |
  | 62D430 | RG 59, A1 1586C | 2839191 | Subject and Special Files | Executive Secretariat | 1953–1961 | | Restricted – Partly | |
  | 62D333 | RG 59, A1 1462 | 2124692 | Psychological Strategy Board Working Files | Executive Secretariat | 1951–1953 | | Restricted – Possibly | Unrestricted |
  | 67D54 | RG 59, A1 5305/A1 5414 | 631403 | Subject Files of the Vietnam Working Group | Bureau of East Asian and Pacific Affairs | 1963–1974 | | Unrestricted | |
  | 62D1 | RG 59, A1 1583E/F | 2838992 | Records Relating to Activities with the NSC | Policy Planning Council | 1948–1961 | | Restricted – Partly | |
  | 58D726 | RG 59, UD 53 | 2544398 | Subject Files | Officer in Charge for Malaya Affairs | 1955–1956 | | Restricted – Possibly | |
  | 61D385 (OCB files) | NOT in central-files-index, curated-lot-resolutions or lot-claimants-index | | | | | | | |

  - RG 306 "Director's Subject Files" and "DIRCTR Subj Files" exist in collection-authority.json only as text collections with no naId, so no identifier, dates or access can be given.
  - Nearby USIA series with a naId: 40967285, U.S. Information Agency, Office of the Director, Executive Secretariat, 1956–1972, 103 linear feet 1 inch, access Restricted – Partly. It is named in the authority for Lots 67 D 317, 67 D 333 and 70 D 449 (v25). I did NOT assert that it is the same series as Entry A1–42.
  - Decimal class gloss (decimal-class-labels.json, schedule 1950-1959). The documents are dated 1950, 1952 and 1955, inside the `glossableYears` span 1950–1959. Class 5 is "International Informational and Educational Relations, Cultural Affairs and Programs"; country 11 is "United States"; country 90 is "Asia" (alternate "Far East (including all of Asia)"); 00 is "World, The"; 51G is "Indo China". So 511.90 is U.S. informational relations with Asia, 511.00 with the world, and 511.51G with Indochina.
  - central-files-index has no series row with a NAID for the 1950s decimal file (its `numericalFile` is the pre-1910 Numerical File), so none is given.
  - The offline stack barely reaches before 1940, which does not affect this scope.

## M5. VECTORS

Files: semantic-vectors-index.json, semantic-vectors-binary.bin and semantic-map.bin (bundle), and Tier-2 shards in `/Users/jbotts/frus-analysis/c3/SemanticVectors/`. Script `vec.py`; outputs `vec_dups.txt` and `vec_nn.txt`.

- **Digest check.** The index `provenanceDigest`, the binary header (offset 20), the map header (offset 20) and the shards' `.generation` all carry `89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101` ("match: True"). Each shard read asserts its header digest equals the index's.
  - Index stamps: generated 2026-10-15, harvestGenerated 2026-10-15T06:55:14.
  - Dims 512; documents 314,616.
- **Identity.** The §A.3 decode round trip gives 553 of 553 volumes decoding to n. No id is derived from an ordinal.
- **Baselines at this digest:**
  - Random pairs (20,000 drawn with `random.Random(1877)`): mean 167.1, sd 14.8, 1st percentile 132, minimum 95.
  - k-th neighbour, over 200 random documents (`Random(1878)`): nearest neighbour median 83 (quartiles 73 and 92); 25th neighbour median 107 (quartiles 99 and 114).
- **Operation 1: near-duplicates.**
  - Anchors: each of the 46 reading-list documents. Method: the 3 nearest neighbours by Hamming distance over the full 314,616-row sign block. Read against the nearest-neighbour distribution, whose median is 83.

    | Copy A | Copy B | Hamming | Reading |
    |---|---|---|---|
    | PubDipv06/d146 | frus1961-63v04/d199 | 34 | same letter, read |
    | PubDipv06/d128 | frus1961-63v03/d152 | 42 | same letter, same date and header |
    | PubDipv06/d140 | frus1961-63v04/d81 | 53 | same memorandum, read both: PubDip copy has "corner", v04 copy "comer" |

  - All three distances are far below the nearest-neighbour first quartile of 73.
  - Consequence: only PubDipv06/d140 is in the argument set, and no reprint is counted twice. The reprint question was not run over the full 2,692.
  - Also seen in a header listing, but its Hamming distance was NOT measured: PubDipv06/d150 and frus1961-63v25/d156, the same 1963-10-28 USIA employee memorandum.
- **Operation 2: nearest neighbours of a document**, with Tier-2 rerank.
  - Anchor: frus1917-72PubDipv08/d31, the 1969 PAO conference. Method: the 800 nearest by Hamming, reranked by int8 cosine `scale_a·scale_b·dot(codes)` from the shards.
  - Cosines are given raw and calibrated through `retrieval.scoreCalibration.documentOffset` 0.40, as (cos−0.40)/0.60.

    | Neighbour | Hamming | Raw cosine | Calibrated |
    |---|---|---|---|
    | PubDipv07/d106 | 81 | 0.920 | 87% |
    | frus1969-76v38p2/d105 | 96 | 0.917 | 86% |
    | PubDipv08/d99 | 90 | 0.915 | 86% |
    | frus1955-57v09/d190 | 100 | 0.908 | 85% |
    | frus1951v06p2/d105 | 94 | 0.908 | 85% |
    | frus1952-54v13p1/d116 | 88 | 0.906 | 84% |
    | frus1955-57v09/d185 | 104 | 0.905 | 84% |
    | frus1961-63v25/d156 | 102 | 0.905 | 84% |
    | PubDipv06/d150 | 99 | 0.905 | 84% |
    | PubDipv07/d69 | 95 | 0.904 | 84% |

  - Read against the k-th-neighbour distribution, Hamming distances of 81–104 are ordinary (the 25th-neighbour median is 107). They are suggestions, not evidence of a relationship.
  - All 10 neighbours' volumes are in the index; none is outside the library.
  - Recall@10 at this generation is 0.9021 (`retrieval.measuredRecallAt10`), so about one true neighbour in ten may be missing.
- **Operation 3: semantic join.** The neighbour list was joined on (volume_id, document_id) to `document_cache` and `document_dates` (headers and dates), and to the confirmed scope set. All four checked neighbours, PubDipv07/d106, PubDipv08/d99, 1955-57v09/d190 and 1955-57v09/d185, are members of the full-text scope set (`grep -c` = 1 each).
- **Centroid similarity:** none. **The map:** none.
- **Documents reached through a vector operation:** frus1955-57v09/d190 (Finding 1, Q5) and frus1917-72PubDipv08/d99 (Finding 5, Q25 and Q26). I came to both through the neighbour list of PubDipv08/d31 and through no ranked full-text query I read. Both are, however, members of the 2,692-document full-text scope set, so **no document in the overview was reachable only through the vectors**.

## M6. Collection

`collection.fruscollection`, written by `make_collection.py`.
- Contents: 22 document entries and 28 excerpts, one for each verified passage, under 5 headings in date order within each. Each heading has a prose entry, and there is a closing prose block and a final `archivalSources` generated block.
- The script asserts:
  - no duplicate pair;
  - volumeId and documentId on every document and excerpt entry;
  - every pair exists (`SELECT 1 FROM document_cache WHERE volume_id=? AND document_id=?`);
  - no Ed2 volume;
  - the pairs equal `argset.csv`;
  - every quoted document is in the collection.
- Every note opens "Agent finding, Agent run f1, 2026-10-31:".
- Overview check (`queries.log`): the 21 distinct document URLs in the overview are all collection entries ("missing from collection set()"). The 22nd collection document, frus1961-63v02/d16, is cited in the collection's Finding 2 but not quoted in the overview.

## M7. Trace table (overview → memo)

| Overview item | Memo source |
|---|---|
| "about 2,700 documents", "273 volumes" | M1.7 (2692 of 2860; 273 volumes) |
| "22 documents, each retrieved in full" | M2 (accounting), M6 |
| "about 94 in every 100" | M1.7 (2692 of 2860) |
| "161 false matches on the abbreviation USI" | M1.7 |
| "found nothing" for "soft power" | M1.1, M1.2 |
| "Department of State" in 552 of 553 volumes; nonsense string nothing | M0.3, M0.4 |
| "messaging" in three documents; treated as "message" | M1.2 |
| "48 in full" | M2 |
| "three pairs … printed twice" | M5 Operation 1 |
| "added two documents" | M5 Operation 2 and the vector-reached paragraph |
| no public-diplomacy volume for 1945–1960 or the 1980s | M1.4 |
| "more than forty matching documents" in the 1949 China volume and the 1955–57 China microfiche supplement | M7 note below (57 and 43 in `scope_confirmed.csv`) |
| RG 59 NAID 2839192, Entry A1 1586E, 1947–1979, partly restricted | M4.4 |
| PSB Working Files NAID 2124692 | M4.4 |
| Vietnam Working Group NAID 631403 | M4.4 |
| Lot 58 D 726 NAID 2544398 | M4.4 |
| Lot 61 D 385 not placed | M4.4 |
| class 511 gloss "International Informational and Educational Relations" | M4.4 |
| RG 306 entries A1–42, UD WW 257, UD WW 193, P–207, P–104, FRC 67 A 222, 68 A 4933 | M4.3; the source notes in `argset_meta.txt` |
| lot-file series that appears most often in both channels | M4.1, M4.2 (63D351 73 came-from; 66D95 108 + 63D351 66 pointed-at) |
| Quotation in ¶1 "the generally meager knowledge…" | Q1 |
| ¶1 "the image of American strength, reliability and friendship" | Q13 |
| ¶1 paraphrase of film / thirteen surveys / credibility | Q2, Q21, Q27 |
| Finding 1 quotations | Q1, Q4, Q3, Q5, Q6 |
| Finding 2 quotations | Q7, Q8, Q11, Q10 |
| Finding 3 quotations | Q13, Q14, Q12, Q16, Q17, Q19, Q15 |
| Finding 4 quotations | Q2, Q20, Q18, Q21, Q22 |
| Finding 5 quotations | Q23, Q24, Q25, Q26, Q27, Q28 |

The count behind "more than forty": `cut -d, -f1 scope_confirmed.csv | sort | uniq -c | sort -rn | head -12` (logged) gives frus1949v08 57 and frus1955-57v03mSupp 43.

## M8. Thin-result flags

- The argument rests on 22 documents. That is a reading selection, not a sample, and most come from the three 1961–72 public-diplomacy volumes.
- The 1950s rest on five documents, and 1973–1980 on two.
- The scope is the whole 553-volume series, so thinness reflects FRUS's selection, not a partial library.
