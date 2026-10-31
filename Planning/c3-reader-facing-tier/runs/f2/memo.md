# Scope memo — American soft power in East Asia and the Pacific (run f2, 2026-10-31)

Operator memo. Every number below carries its query or script; files named are in
`/Users/jbotts/frus-analysis/c3f/runs/f2/`. Commands in order are in `queries.log`.

## 0. Coverage and access proofs

- Canary (first call), verbatim:
  `sqlite3 "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro" "SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;"`
  -> `553|321749|1103|8481`. The index holds all 553 volumes of the series (the library is complete
  at this snapshot); 321,749 rows, 1,103 front matter, 8,481 editorial notes.
- Read-only proof: `sqlite3 -readonly ... "BEGIN; CREATE TABLE zz(x); ROLLBACK;"` ->
  `Error in 3rd command line argument: attempt to write a readonly database` (as required).
- Every count below is conditional on this 553-volume index.

## 1. Scope chosen, and how

**Question vocabulary first (false-friend test).** The question's own terms do not exist in the
period's vocabulary:
- `"soft power"`: FTS MATCH over non-apparatus rows -> 0 in the corpus, 0 in scope (fts.py; SQL:
  `SELECT d.volume_id, d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '"soft power"' AND d.is_front_matter=0 AND d.is_editorial_note=0`).
  Positive control `"Department of State"` in the same pass -> 94,049 corpus-wide; negative control
  `ZZZ_IMPOSSIBLE_ZZZ` -> 0. The term is a later coinage; I did not use it.
- `messaging`: the stemmer folds it with "message"; 32,754 documents corpus-wide. Share in the
  public-diplomacy volumes 151 of 968 non-apparatus documents (0.156) against 8,534 of 61,852 in the
  East Asia volumes (0.138); the control "Department of State" runs 327 of 968 (0.338) against 17,195
  of 61,852 (0.278). The term tracks the corpus's telegram vocabulary, not the question. Dropped.
- I used the contemporaries' vocabulary instead: the agency's name, "psychological"
  warfare/strategy/operations, propaganda, "image of the United States", "information program",
  cultural exchange (counts in §2).

**Volume set (scope_volumes.tsv, built by a python pass over manifest.json titles).** 109 volumes:
103 whose title names an East Asian or Pacific place (regex `China|Japan|Korea|East Asia|Southeast
Asia|Vietnam|Indochina|Philippine|Indonesia|Pacific|Far East|Laos|Cambodia|Northeast Asia|Burma|
Thailand`) and 6 whose title names Public Diplomacy (frus1917-72PubDip [WWI], frus1917-72PubDipv06,
v07, v08, frus1969-76v38p2, frus1977-80v30). Non-apparatus documents in the 109:
`SELECT COUNT(*) FROM document_cache WHERE volume_id IN (<109 ids>) AND is_front_matter=0 AND is_editorial_note=0`
-> 61,852. In the 6 public-diplomacy volumes -> 968. Positive control per volume: every one of the
109 volumes has at least one "Department of State" match (0 volumes with zero; per-volume GROUP BY
query in queries.log). No Ed2 volume falls in the set.

**Inclusion rule for the collection.** A document is in when it is a policymaker's or the
information agency's own assessment of how Americans and American policy were received by an East
Asian or Pacific audience, of what themes to use there, or of what that audience believed — and it
was read in full or in the relevant section in this session. Wartime military psychological
operations are included only where they show a belief about the audience or the method of
persuasion. Date span of the collection: 1953-09-14 to 1977-01-06 (document_dates.date_iso, which is
the periodisation surface I used throughout; not the series year).

**How the reading list was found.**
1. rank_pd.py: `SELECT volume_id, document_id, header, body_text FROM document_cache WHERE volume_id IN (6 PD volumes) AND is_front_matter=0 AND is_editorial_note=0`;
   python `re` (case-SENSITIVE) count of East Asian place words (pattern in rank_pd.py) -> pd_ranked.tsv
   (968 rows). 119 documents have 10 or more such matches ("the wide set", used for archival channels).
2. Header scan in the East Asia volumes:
   `SELECT volume_id, document_id, substr(header,1,160) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0 AND (header LIKE '%psycholog%' OR header LIKE '%Information Agency%' OR header LIKE '%information program%' OR header LIKE '%propaganda%' OR header LIKE '%Operations Coordinating Board%' OR header LIKE '%USIA%' OR header LIKE '%cultural%')`
   (LIKE, case-insensitive), filtered in python to the 103 East Asia volumes.
3. BM25: `SELECT d.volume_id, d.document_id, bm25(frus_documents) s, length(d.body_text), substr(d.header,1,120) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '(USIS OR USIA OR "information program" OR "information activities") AND (Asian OR Asians) AND (attitude OR attitudes OR image OR prestige)' AND d.is_front_matter=0 AND d.is_editorial_note=0 ORDER BY s ASC`
   filtered to the East Asia volumes -> 92 documents; I read from the top 40.
4. Nearest-neighbour search (VECTORS below) added frus1955-57v09/d190.

## 2. Phrase counts, each with its literal share (share.py, share.out)

Surface: FTS MATCH, non-apparatus rows, restricted to the 109 volumes. Share: 40 evenly spaced
(volume_id, document_id)-sorted pairs (all 30 where under 40), regex over header+dateline+
source_note+body_text concatenated and whitespace-collapsed, Python `re` with IGNORECASE for every
family. STRICT = the literal with single spaces; TOLERANT = inflections and any run of space,
hyphen, comma, parenthesis or full stop between words (patterns in share.py).

| MATCH | docs in scope | corpus | TOLERANT | STRICT |
|---|---|---|---|---|
| `"United States Information Agency" OR USIA` | 913 (PD 580, EA 333) | 2,194 | 40 of 40 | 40 of 40 |
| `"psychological warfare" OR "psychological strategy" OR "psychological operations"` | 363 (PD 28, EA 335) | 863 | 40 of 40 | 39 of 40 |
| `propaganda` | 3,495 (PD 157, EA 3,338) | 12,107 | 40 of 40 | 40 of 40 |
| `"image of the United States" OR "American image" OR "U.S. image"` | 30 (PD 18, EA 12) | 109 | 30 of 30 | 30 of 30 |
| `"information program"` | 207 (PD 65, EA 142) | 592 | 38 of 40 | 38 of 40 |
| `"cultural exchange" OR "exchange of persons"` | 289 (PD 113, EA 176) | 901 | 40 of 40 | 38 of 40 |

The two tolerant misses for "information program" (frus1949v07p2/d317, frus1958-60v16/d294) both
read "informational program" — the same referent, folded by the stemmer. A 1.000 share tests the
stemmer, not the referent; the referent was tested by reading (§4). None of these counts reaches
the overview except as the share statement in R2 below.

Opinion-research search (fts.py), same surface:
`(poll OR polls OR survey OR surveys) AND (Japanese OR Korean OR Koreans OR Filipino OR Filipinos OR Thai OR Indonesian OR Indonesians OR Vietnamese) AND (USIA OR USIS OR "Information Agency")`
-> 108 corpus-wide, 75 in scope (EA 51, PD 24); negative control 0 in the same pass. Literal share
not taken (boolean of single words, not a phrase); not published in the overview.

## 3. Archival channels (never summed)

### Came-from (document_sources, one row per document)
Collection (14 of 15 documents have a row; query with the 14 pairs in coll.txt):
`SELECT volume_id, document_id, repository, record_group, lot_file_norm, series_name, citation_era FROM document_sources WHERE (volume_id, document_id) IN (VALUES <pairs>)`
-> RG 306 eight (v06 d128; v07 d32; v08 d31, d58, d88, d149; frus1961-63v03 d308; frus1977-80v30
d2); RG 305 one (frus1969-76v38p2 d105, "Records of the USIA" — the editors' RG 305 as printed);
RG 59 three (d352 decimal 696.00/2–1054; d403 decimal 790.5/9–1453; frus1964-68v29p2 d46 subject-
numeric Central Files 1964–66); Kennedy Library one (d127, RFK papers); Nixon Presidential Materials
one (frus1969-76v19p2 d67, NSC Files). frus1955-57v09/d190 was added later; its source note reads
"S/S – NSC Files: Lot 63 D 351" (raw/frus1955-57v09_d190.txt).

Wide set, 119 documents (channels.py, channels.out; tally in queries.log):
`SELECT repository, record_group, series_name FROM document_sources WHERE volume_id=? AND document_id=?`
-> National Archives RG 306: 74 of 119; Nixon materials 14; Johnson Library 9; National Archives
RG 59 6; Kennedy 5; Carter 3; Department of State RG 59 3; Library of Congress 2; RG 305 1; Ford 1;
RG 63 1. Top series strings: "Director's Subject Files" 29; "DIRCTR Sub/Subj Files" (three
spellings) 19; Nixon "NSC Files" 10.

### Pointed-at (external_citations, many rows per document)
Caveat stated before use: the channel has no row before 1910-12-06, stores the citation fragment,
not the sentence, and holds lot, library and decimal anchors only.
Collection: one row in all 15 — d352, centralFileClass, 696.00/2–1054 (its own file).
Wide set: `SELECT repository, collection, lot_file_norm, anchor FROM external_citations WHERE volume_id=? AND document_id=?`
-> 11 of 119 documents carry any row. Distinct targets: Kennedy National Security Files 2; Nixon
White House Central Files 2; Johnson Marks Papers 1 and Papers of Leonard H. Marks 1; Nixon
Kissinger Office Files 1, White House Special Files 1, NSC Files 1, Kissinger telephone transcripts
1; Ford National Security Adviser 1; Department of State lot 81D113 1.

### Resolution in the bundled JSON (json_lookup.out and the python calls logged)
| Series | RG / entry | NAID | Dates | Access | Channel | How resolved |
|---|---|---|---|---|---|---|
| Subject Files of the Director (USIA Office of the Director, Executive Secretariat) | RG 306 | 40967285 | 1956–1972 (inclusive) | Restricted – Partly; use unrestricted; 103 linear feet | came-from, CANDIDATE | series-facts byNaId; accession index titles it "Subject Files of the Director" under 306/64A0536. FRUS cites "Director's Subject Files, 1968–1972, Entry A1–42" and "DIRCTR Subj Files 1963–69 … Acc #72A5121, Entry UD WW 257"; the accession index lists 18 series under 306/72A5121 and NOT this NAID, so the match is by title and creator only |
| Subject Files (USIA Office of Policy and Plans) | RG 306 | 1257679 | 1953–1971 (coverage 1949–1971) | Restricted – Partly; 47 linear feet | came-from, CANDIDATE | claimed by both 306/72A5121 (18 claimants) and 306/69A3445 (9 claimants) |
| OCB Files, Lot 62 D 430 (Executive Secretariat) | RG 59 | 2839191 | 1953–1961 | Restricted – Partly | came-from (OCB country plans in the East Asia volumes, e.g. frus1952-54v12p2/d174, frus1955-57v23p2/d99, read and set aside) | collection-authority lot:62D430 + series-facts |
| Central Decimal File 790.5 / 696.00 | RG 59 | not resolved | doc dates 1953, 1954 | — | came-from | decimal-class-labels 1950–1959 schedule glosses country 90 = Asia, 96 = Philippines, class 7 = Internal Political and National Defense Affairs, class 6 = International Political Relations (document dates inside glossableYears) |
| RFK Papers, Attorney General Papers: General Correspondence | Kennedy Library | 193936 | 1961–1964 | not in bundle | came-from (d127) | presidential-library-catalog JFK-RFK |
| Papers of Leonard H. Marks, Work Files | Johnson Library | collection 50809179, series 50827304 | 1965–1968 | not in bundle | came-from and pointed-at | presidential-library-catalog LBJ-P69098 |
| D Files, Lot 81D113 (Entry P–14), Office of the Deputy Secretary | RG 59 | 1487627 | 1975–1981 | Restricted – Partly; 14 linear feet | pointed-at | collection-authority + series-facts |
| Nixon NSC Files (NSC Institutional "H" Files); Kennedy National Security Files; Nixon White House Central Files; Ford National Security Adviser | libraries | not resolved | — | — | came-from / pointed-at | no title match in presidential-library-catalog |
| Vietnamese Public Opinion Surveys | RG 306 | 1127750 | not in bundle | not in bundle | SHELF for an unprinted series (not a channel) | accession-series-index 306/870087 |
| International Survey Research Reports; Research Reports | RG 306 | 721251; 1257657 | not in bundle | not in bundle | SHELF (not a channel) | accession-series-index 306/66A1170; 306/64W0853B |

The offline stack barely reaches before 1940; irrelevant here (all collection documents 1953–1977).

## 4. Reading accounting

Reading SELECT (dump.py): `SELECT d.header, d.dateline, d.source_note, d.body_text, length(d.body_text), t.date_iso FROM document_cache d LEFT JOIN document_dates t ON t.volume_id=d.volume_id AND t.document_id=d.document_id WHERE d.volume_id=? AND d.document_id=?`
- Retrieved whole to disk: 29 documents (raw/*.txt; readset.txt, readset2.txt, readset3.txt), each
  with captured length = length(body_text) on its LEN line; 369,229 characters in all.
- Read whole in the session: v06 d103, d110, d112, d127, d128; d403; d352; frus1961-63v02 d16;
  frus1961-63v03 d308; frus1964-68v29p2 d46; v08 d31 (first 11,000 characters of 20,792), d58, d88,
  d149; frus1969-76v19p2 d67; frus1969-76v38p2 d105; frus1977-80v30 d2.
- Read in part: v07 d32 (first 9,000 of 27,974 characters); frus1955-57v09 d190 (opening 1,500 and
  the Far East section, characters 34,947–40,147 of 51,295, plus a sentence grep); v07 d172 (first
  5,000 of 47,196 plus a grep); frus1952-54v12p2 d174, frus1955-57v23p2 d99, frus1955-57v22 d448,
  d449 (opening and grep only). Set aside as off-question: d174 (arms sales), d99 (internal
  security), d448/d449, d172 (a global Vietnam talking paper), d103/d110/d112 (Laos media control,
  relevant but not used), d16.
- Never read: v07 d85, d171; v08 d24; frus1964-68v26 d106 (dumped only).
- Quoted: 15 documents, 24 passages (quotes.tsv).

## 5. Quotations, each verified (verify_quotes.py -> quotes_verified.out)

Verification SELECT: `SELECT body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?`
then an exact Python substring test. All 24: EXACT.

| # | pair | offset | passage |
|---|---|---|---|
| Q1 | frus1952-54v12p2/d403 | 2524 | utilizing every suitable operation to prepare the minds and emotions of the people to collaborate in the effort |
| Q2 | frus1952-54v12p2/d403 | 4369 | In projecting U.S. leadership, however, we must work with and through indigenous leadership wherever possible. |
| Q3 | frus1952-54v12p2/d352 | 1078 | would carry unsavory recollections of Japanese wartime slogan and could easily be misinterpreted by public at large to be anti-Western in intent |
| Q4 | frus1955-57v09/d190 | 5645 | In the Far East USIA was forced to deal with mixed emotions regarding the use of atomic weapons against Asiatic peoples, and to counter communist propaganda designed to stir up race hatred. |
| Q5 | frus1955-57v09/d190 | 36880 | Unparalleled enthusiasm, admiration and good will were produced throughout Japan by the tour of the Symphony of the Air |
| Q6 | frus1917-72PubDipv06/d127 | 813 | probably the most successful visit by an American, from a public image standpoint |
| Q7 | frus1917-72PubDipv06/d128 | 3118 | may only serve to increase the dimensions of the threat that looms from the North |
| Q8 | frus1917-72PubDipv06/d128 | 3696 | with over one million Chinese residents in South Viet-Nam who will also hear these broadcasts, we must exercise caution |
| Q9 | frus1961-63v03/d308 | 982 | Editorialists are almost unanimously critical of the Diem Government actions and generally blame the U.S. for continuing it in power. |
| Q10 | frus1917-72PubDipv07/d32 | 2060 | Vietnamese peasants are, in the main, going to be persuaded by other Vietnamese. |
| Q11 | frus1917-72PubDipv07/d32 | 3188 | family-oriented, selfish and opportunistic even in the best of times |
| Q12 | frus1964-68v29p2/d46 | 7191 | the basic emotional response remains unchanged and is probably unchangeable over the short run |
| Q13 | frus1964-68v29p2/d46 | 7664 | Only a rather clear-cut success for American policies is likely to reverse the trend. |
| Q14 | frus1964-68v29p2/d46 | 3768 | their ready identification of the American position with that of the Japanese armies in China |
| Q15 | frus1917-72PubDipv08/d31 | 2802 | PAOs emphasized that the image of the US usually depended more on the state of bi-lateral relations |
| Q16 | frus1917-72PubDipv08/d31 | 8469 | One caveat: US visibility should be low. |
| Q17 | frus1917-72PubDipv08/d58 | 1254 | functions in this field properly belong to and must ultimately be performed by the Government of Viet-Nam (GVN) |
| Q18 | frus1917-72PubDipv08/d88 | 1477 | Rating of the U.S. as a dependable ally of SVN reached the lowest point in thirteen Saigon surveys |
| Q19 | frus1969-76v19p2/d67 | 1799 | public opinion surveys and other assessments of Japanese attitudes have tended to confirm the seriousness of these strains |
| Q20 | frus1917-72PubDipv08/d149 | 1013 | The predominant mood is apolitical, seeking to be neutral, and concerned with economic and trade problems rather than strong ideological convictions. |
| Q21 | frus1917-72PubDipv08/d149 | 1648 | we are compelled to take a very close look at the overseas Chinese as a USIS audience |
| Q22 | frus1969-76v38p2/d105 | 4489 | During this waiting period, programs on U.S. security relations in Asia lack credibility and may in fact do damage to our relations. |
| Q23 | frus1969-76v38p2/d105 | 6933 | hoping that we have all learned the lesson that America is not omnipotent |
| Q24 | frus1977-80v30/d2 | 6026 | We are dealing here with gut issues rather than some of the frothier aspects of cultural exchange. |
| Q25 | frus1952-54v12p2/d352 | (substring test, check_overview.py) | Asia for Asians |

Two figures the overview takes from document text (not SQL), read in raw files retrieved by the
reading SELECT: frus1917-72PubDipv08/d88 — "only 26 percent of the general public" rate the U.S.
dependable (raw/frus1917-72PubDipv08_d88.txt); frus1964-68v29p2/d46 — those naming the United States
among their three favourite countries fell "from 52 percent to 38 percent" (raw/frus1964-68v29p2_d46.txt).
Both appear in the overview in paraphrase with the figures; check: `grep -c "52 percent to 38 percent" raw/frus1964-68v29p2_d46.txt` and `grep -c "only 26 percent" raw/frus1917-72PubDipv08_d88.txt` (both 1; run during the final check).

## 6. VECTORS

Files: semantic-vectors-index.json, semantic-vectors-binary.bin, semantic-map.bin (header only),
SemanticVectors/.generation and 187 Tier-2 shards (each shard's header digest checked at load).
Provenance digest `89481b1869da1880…` (provenanceDigest of the index); binary header, map header and
the shard folder's .generation all equal it; every shard opened passed the same assertion
(vec.py, nn.py; vec.out, nn.out). Index `generated` and `harvestGenerated` stamps are in the index
(not printed). Id decode round trip: 553 of 553 volumes.

Baselines at this digest (vec.py): random pairs (20,000, `random.Random(1877)`): mean 167.1, sd 14.8,
1st percentile 132, minimum 95 of 512. k-th-neighbour distribution over a 200-document sample: median
1st-neighbour 84; median 10th-neighbour 101 (quartiles 93 and 109); median 25th-neighbour 107.
Calibration: `retrieval.scoreCalibration.documentOffset` 0.40 -> calibrated = (cos − 0.40)/0.60;
`measuredRecallAt10` 0.9021, rerank pool 800.

Operations run:
1. **Nearest neighbours of a document**, anchor frus1969-76v38p2/d105 (nn.py: Hamming top 800 over the
   sign block, rerank by int8 cosine over Tier-2 shards, Ed2 volumes suppressed). Top 10 include
   frus1917-72PubDipv08/d31 at Hamming 96 (raw cosine 0.917, calibrated 0.862), frus1969-76ve12/d16 and
   d10, frus1977-80v22/d104 and d107, frus1977-80v01/d88. Hamming 76–96: inside the 10th-neighbour
   interquartile range or shorter — ordinary neighbours, far outside random pairs (1st percentile 132).
2. **Nearest neighbours of a document**, anchor frus1917-72PubDipv08/d31: top 10 include
   frus1969-76v38p2/d105 (Hamming 96, cal. 0.862; the two anchors find each other), frus1917-72PubDipv08/d99,
   frus1955-57v09/d190 (Hamming 100, raw 0.908, cal. 0.847), frus1955-57v09/d185, frus1961-63v25/d156,
   frus1917-72PubDipv06/d150. d190 sits at the median 10th-neighbour distance — a lead, not a link.
   Every neighbour's volume is present in the index (553 of 553), so none needed flagging.
- Semantic join: none. Centroid similarity: none. The map: none (header digest read only).
  Near-duplicates: none.

Reached through a vector operation and through no full-text query I ran that surfaced it for
reading: **frus1955-57v09/d190** (it falls in the corpus-wide USIA MATCH set of 2,194, but outside my
109-volume scope, and no query of mine listed it). It was read (Far East section) before it was
cited. Every other overview document was found by full-text or header queries.

Not claimed: absence of further similar documents (recall@10 is 0.902).

## 7. Trace table — every number and quotation in the overview

| Overview item | Memo source |
|---|---|
| "553 volumes" / "the whole series" (Scope) | §0 canary |
| "109 volumes", "about 62,000 documents" (Scope) | §1 volume set: 109; 61,852 |
| "fifteen documents" (Scope, part 1) | §4 quoted 15; coll.txt 14 + d190 |
| "five Public Diplomacy volumes" (part 3, How) | §1: six PD-titled volumes, one is WWI (frus1917-72PubDip); five cover 1961–1980 |
| "nearly two in three" of agency-name finds in those volumes (part 3) | §2: 580 of 913 |
| "about three in five" of 119 documents from the agency's own records (part 2) | §3 wide set: RG 306 74 of 119 |
| "119 documents" (part 2) | §3 wide set |
| "about one in eleven" carry a footnote pointer (part 2) | §3: 11 of 119 |
| "eighteen series" under one transfer number (part 2) | §3 table: 306/72A5121 lists 18 |
| "no document" uses "soft power" (part 3) | §1 false-friend: 0 |
| "from 52 to 38 percent" (Finding 3) | §5 note, d46 raw text |
| "only 26 percent" (Finding 3) | §5 note, d88 raw text |
| "thirteen Saigon surveys" (Finding 3, quotation Q18) | Q18 |
| "one million Chinese residents" (Finding 2, Q8) | Q8 |
| NAIDs 40967285, 1257679, 2839191, 193936, 50827304, 1487627, 1127750, 721251, 1257657; dates 1956–1972, 1953–1971, 1953–1961, 1961–1964, 1965–1968, 1975–1981 | §3 resolution table |
| Record groups 306, 59; entries A1–42, UD WW 257, P–14; lots 62 D 430, 81D113; accession 72A5121 | §3 table and source notes in raw/ files |
| Citation years, volume and document numbers | §8 documents cited |
| Quotations Q1–Q24 used in the overview, whole or as substrings | §5 (each EXACT); substring test by check_overview.py |
| "Asia for Asians" (Finding 1) | Q25: frus1952-54v12p2/d352, verified verbatim in body_text by check_overview.py (queries.log) |
| "Director's Subject Files" (part 2) | series_name in document_sources ("Director’s Subject Files", 29 of the wide set) and the source notes; a citation, not a document quotation |
| "information program", "psychological strategy", "image of the United States", "soft power", "informational program" | search terms of §1–2, not quotations |
| "dated from 1953 to 1977" (Scope) | §1 collection span 1953-09-14 to 1977-01-06 |
| "the printed documents date from 1953 and 1954" (part 2) | §3: d403 1953-09-14, d352 1954-02-13 |
| "anything after 1980" (part 3) | §1: last Public Diplomacy volume is frus1977-80v30 (manifest latest 1980-12-16) |
| "1963–1969" for Entry UD WW 257; "1968–1972" for Entry A1–42 | source notes in raw/frus1917-72PubDipv06_d128.txt and raw/frus1917-72PubDipv08_d149.txt |
| Heading spans (1950s, 1963–1969, 1963–1970, 1969–1971, 1975–1977) | dates of the documents under each heading, §8 / document_dates |
| "one" in "one in eleven", "two in three", "three in five" | rows above (11 of 119; 580 of 913; 74 of 119) |

## 8. Documents cited (pairs)
frus1952-54v12p2/d403; frus1952-54v12p2/d352; frus1955-57v09/d190; frus1917-72PubDipv06/d127;
frus1917-72PubDipv06/d128; frus1961-63v03/d308; frus1917-72PubDipv07/d32; frus1964-68v29p2/d46;
frus1917-72PubDipv08/d31; frus1917-72PubDipv08/d58; frus1917-72PubDipv08/d88; frus1969-76v19p2/d67;
frus1917-72PubDipv08/d149; frus1969-76v38p2/d105; frus1977-80v30/d2. Each verified present in
document_cache (collection check, queries.log).

## 9. Not done
- No TEI-surface counting: no density, variant split or apparatus/document separation is published;
  body_text includes editorial footnotes, so no term frequency here separates document from editor.
- No per-decade rate is published.
- Volumes not mined: frus1977-80v22 (Southeast Asia and the Pacific), the 1969–76 Vietnam and China
  volumes beyond the header scan, frus1961-63v25 (organization of foreign policy; USIA).
- Final checks, run at the end (build_collection.py, check_overview.py; logged in queries.log):
  all 15 document pairs and 25 excerpts exist in document_cache; every excerpt is an exact substring
  of its document's body_text; no duplicate pair, no Ed2 volume; the overview cites 15 documents and
  every one is in the collection, with none in the collection uncited; every quotation in the
  overview is a substring of a verified passage (Q1–Q25), the rest of its quoted strings being search
  terms or citation forms (trace table). The positive control was checked per volume over the 109
  scoped volumes only, not all 553; the overview says so.
