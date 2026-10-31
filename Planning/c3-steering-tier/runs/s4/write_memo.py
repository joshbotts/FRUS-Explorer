import json,re,pickle
def rd(f): return open(f).read().rstrip()
quotes=[l.rstrip("\n").split("\t") for l in open("quotes_verified.tsv")][1:]
ovq=json.load(open("work/overview_quotes.json"))
nd=pickle.load(open("work/neardup_read.pkl","rb"))
same=[o for o in nd if o[6]=="SAME TEXT"]
M=[]
A=M.append
A("""# Memo: corruption, or allegations of corruption, and U.S. foreign policy (run s4, 2026-10-30)

For the operator. Every number and quotation in overview.md is traced in section M10. Scripts and outputs named below are in this run directory.

Library note: every count below is conditional on this library, which holds **553 volumes** (the whole series) in the index copy dated 2026-10-25.

## M1. Coverage, canary and controls

Canary (first call): `SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;` returned `553|321749|1103|8481`, exactly as required. Read-only proof (second call): `sqlite3 -readonly <db> "BEGIN; CREATE TABLE zz(x); ROLLBACK;"` failed with "attempt to write a readonly database".

Controls, in the same pass (q1.sql, q10.sql; every FTS query joins `frus_documents f JOIN document_cache c ON c.rowid=f.rowid` and keeps `c.is_front_matter=0 AND c.is_editorial_note=0`):

- POSITIVE: `... WHERE frus_documents MATCH '"department of state"'` gave 94,049 documents (nonzero, as expected).
- NEGATIVE: `... WHERE frus_documents MATCH 'zzz_impossible_zzz'` gave 0.
- RELAXED form beside the zero: `MATCH 'corrupt'` gave 2,200 documents on the same surface, so the scan works and the zero is a measurement.

## M2. Surfaces used, and what is not claimed

- THIS DATABASE: coverage, identity, exclusions, every document count.
- BUNDLED JSON (app build 1.0 (1776) Resources): manifest.json (titles), collection-usage-index.json, external-citation-index.json, collection-authority.json, central-files-index.json, series-facts-index.json, presidential-library-catalog.json, lot-claimants-index.json (read for its shape only). Used for every archival statement (M7).
- TEI XML: **not consulted.** So this memo makes no spelling-variant count, no counting-surface comparison and no apparatus/body split. All counts are of porter stems in the index; `body_text` includes editorial footnotes, so a hit can come from an editor's footnote (the Kissinger line quoted from Document 293, the Haiti Senate committee line in Document 257, and Carter's FCPA signing statement in the 1977-80 Foreign Economic Policy volume are footnote text inside `body_text`).
- HARVEST: not given; the harvest-level surface is unavailable and no figure here is from it.
- Dates: `document_dates.date_iso`, the index's own per-document date (the index derives it from the TEI's instant by its same-instant-day rule); I did not read `frus:doc-dateTime-min` from the TEI. The volume's series year was not used to periodise.
- Second editions: `frus1951-54IranEd2` and `frus1969-76ve15p2Ed2` are excluded from every count (`c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')`); `frus1977-80v09Ed2` was never in play. Surface counted: this index, apparatus excluded. The two cited Western Europe documents (d292, d293) were cited from the first edition, `frus1969-76ve15p2`; their Ed2 reprints are the same text after whitespace collapse (checked, section M8.4).
- `summary_text` and `note_text` were never read or quoted.

## M3. Scope chosen and how it was found

**Scope:** all 553 volumes; documents dated from the 1840s to 1988 (a single document each in the 1840s, 1850s and after 1989), with the substance in 1861-1988. **Inclusion rule for the collection:** a document in which a U.S. official, a foreign official, or a legislator reports or alleges bribery, embezzlement, graft, kickbacks, nepotism or venality, of a government, an official or a company, AND in which the allegation is tied to a U.S. decision, condition, request or line of action. Excluded: treaty lists of crimes, metaphors ("beg, bribe, bully"), "payoff" meaning result, scandals without money (Watergate, 183 documents, not counted), and smuggling by itself.

**How found (in order):**
1. Vocabulary: q2.sql (output q2.out) listed the porter stems of the family and their document frequencies from an fts5vocab table (`CREATE VIRTUAL TABLE temp.v USING fts5vocab(main, frus_documents, 'row')`; these frequencies include apparatus and the Ed2 volumes, so `corrupt` is 2,253 there against 2,200 in the apparatus-excluded count of M1); `corrupt` 2,253 documents, `bribe` 431, `briberi` 309, `venal` 161, `embezzl` 174, `payoff` 155, `malfeas` 78, `misappropri` 94, `nepot` 50, `kickback` 18, `payola` 1. `graft` (372) was left out of the family because the stem is ambiguous.
2. The family query (FAM): `corrupt OR bribe OR briberi OR kickback OR payoff OR venal OR embezzl OR malfeas OR misappropri OR nepot OR payola` gave 3,123 documents (M4.1).
3. The policy-nexus query (NEXUS, in nexus.txt): `NEAR(corrupt aid, 25) OR NEAR(corrupt assistance, 25) OR NEAR(corrupt support, 25) OR NEAR(corrupt withhold, 25) OR NEAR(corrupt condition, 25) OR NEAR(corrupt suspend, 25) OR NEAR(corrupt confidence, 25) OR NEAR(corrupt congress, 25) OR NEAR(corrupt reform, 25)` gave 595 documents (q8.sql), used to choose what to read, not as a published finding.
4. Reading: `python3 q7.py <from> <to> <n> '<match>'` printed bm25-ranked snippets (`snippet(frus_documents,6,...)`) for date windows 1860-1930, 1940-1949, 1950-1961, 1963-1989, and for named volumes (`VOL=`). Documents were then retrieved whole with getdoc.py and read around the hits with ctx.py (M5).
5. Editors' headings: python over `volume_structures.structure_json` for corruption-ish words in section titles (headings.py, output headings.out; the only heading naming corruption is `frus1958-60v01` chapter 1, "THE CAN LAO PARTY, CORRUPTION, AND THE USE OF U.S. AID"; the only other family match is a convention on "stolen or embezzled motor vehicles", frus1936v05; the other matches of the wider pattern, improper, misconduct and so on, are not corruption). That heading led to the Can Lao documents (d131, d185 of that volume).
6. Vectors (M8) added one document (frus1922v01/d872).

## M4. What was measured

### M4.1 Family count, with SQL
```
SELECT c.volume_id, c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid
WHERE frus_documents MATCH 'corrupt OR bribe OR briberi OR kickback OR payoff OR venal OR embezzl OR malfeas OR misappropri OR nepot OR payola'
  AND c.is_front_matter=0 AND c.is_editorial_note=0
  AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
```
(stats.py runs this with the match string as a bound parameter.) Result: **3,123 documents** (see stats.out line 1).

Denominator for "about one in a hundred": non-apparatus, Ed2-excluded documents = 11,384 + 300,045 = 311,429 (stats2.out; `SELECT count(*) FROM document_cache c WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN (...)` split inside/outside the collection volumes). 3,123 of 311,429 = 1.0%.

### M4.2 Decade shape (stats.py, `document_dates.date_iso`); counting surface: index stems, apparatus excluded
Per-1,000 is the family count over the decade's dated non-apparatus Ed2-excluded documents, with the numerator's top-volume share. Denominator predicate: `SELECT volume_id, document_id FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0 AND volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')`, joined in Python to `SELECT volume_id, document_id, date_iso FROM document_dates` and counted by `substr(date_iso,1,3)` (the decade); the numerator is the M4.1 hit list joined the same way.

```
""")
A(rd("stats.out").split("LITERAL SHARE")[0].strip())
A("""```
Reading: the rate falls from 10-18 per 1,000 in the 1860s-1900s to 2.8-5.8 in the 1910s-1930s, then climbs to 21-23 per 1,000 in the 1960s-1980s. The 1894 appendix (Hawaii) is 46 of the 126 hits of the 1890s, and `frus1964-68v05` 44 of 580 in the 1960s, so the small decades' rates are partly single-volume effects (1840s and 1850s: one hit each; do not read as a rate). 3 hits are undated.

### M4.3 Literal share (rule a) and referent test, 40 evenly spaced of the 3,123
Method: the hit list sorted by (volume_id, document_id); item `int(i*3123/40)` for i in 0..39; Python `re`, case-INSENSITIVE (`re.I`), over header+dateline+source_note+body_text whitespace-collapsed. SQL was used only for the hit list; the regex test is Python's (so SQL LIKE was not used for the family).

- STRICT = exact headwords with word boundaries: `\\b(corruption|corrupt|bribe|bribery|kickback|payoff|venal|embezzlement|nepotism|malfeasance|misappropriation|payola)\\b`. **36 of 40.** The four misses are inflections ("bribes", "embezzle", "venality", "bribe(s)" forms).
- TOLERANT = stem prefixes `corrupt\\w*|brib\\w*|kickback\\w*|pay-?off\\w*|venal\\w*|embezzl\\w*|nepot\\w*|malfeas\\w*|misappropriat\\w*|payola`. **40 of 40.**
- REFERENT (read from the contexts printed in stats.out): the matched word is about corrupt dealing in **30 of 40**. The ten that are not: frus1873p2v3/d25 (embezzling property of fishermen, seizure not corruption), frus1911/d239 and frus1924v02/d573 (extradition-treaty lists), frus1933v02/d395 (a private embezzlement charge), frus1941v02/d244 ("beg, bribe, bully", metaphor), frus1894app2/d501 (a constitutional disqualification clause), frus1969-76v16/d177, frus1969-76v31/d129 and frus1977-80v19/d452 ("payoff" meaning a result), frus1969-76ve10/d225 ("bribes in the form of more aid", metaphor). A 1.000 tolerant share tests the stemmer, not the referent: the referent share, 30 of 40 = 0.75, is below 0.80, so the family count is an upper bound and is used only for scale ("nearer 2,300": 0.75 x 3,123 = 2,342; with a 40-document sample the 95% interval is about 0.59-0.87, i.e. roughly 1,850-2,700).

### M4.4 The nexus set (stats2.py)
NEXUS = 595 documents (q8.sql, SQL above). Literal share, 40 evenly spaced: tokens `[A-Za-z]+` of header+dateline+source_note+body; STRICT = `corrupt|corruption` within 25 tokens of an exact second word (aid, assistance, support, withhold(ing), condition(s), suspend, confidence, congress, reform(s)): **33 of 40**; TOLERANT (prefix forms): **39 of 40**. Not published in the overview except as a tool.

### M4.5 False-friend test (stats2.py)
The question supplied the term "corruption". Share of non-apparatus documents (Ed2 excluded) matching, inside the collection's 20 volumes vs the other 533:
```
""")
A(rd("stats2.out").split("\n",1)[1].split("NEXUS")[0].strip())
A("""```
`corrupt` is 5.9 times as frequent inside as outside; the controls are 0.96 and 1.14. So the term is not measuring the corpus's baseline. Caveat: the 20 volumes were chosen by reading, after the term had pointed to them, so the test shows selection by the term more than independent on-topic status; I did not find an independent on-topic volume set.

### M4.6 Absence and presence tests (q10.sql, SQL printed in the file; output in the session)
`Teapot Dome` 2 documents; `spoils system` 9; `Abscam` 0; `watergate` 183; `"foreign corrupt practices"` 4 (frus1977-80v03 d152, d230, d248; frus1977-80v18 d57); `"questionable payments"` 9; `lockheed` 196; `"transparency international"` 0; `"anti corruption"` 52. Positive control `"department of state"` 94,049; negative `zzz_impossible_zzz` 0; relaxed form of the negative: `corrupt` 2,200. Latest dated document with `corrupt`: 1988-12-30 (`SELECT MAX(d.date_iso) ... MATCH 'corrupt'`). Dated documents in 1990s: 177, of which 1 carries a family word (stats.out).

### M4.7 Archival scale
Re-derived from series-facts-index.json (work/pre1940.txt): 698 rows, 11 with `inclusiveStartYear` < 1940, about one in 63. (The guide's "one in sixty" is its own measurement; this is mine.)

## M5. Reading accounting
- Documents retrieved whole: **69** (getdoc.py writes work/docs/<vol>__<doc>.txt from `SELECT header,dateline,body_text,length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?`); captured length (characters) equals `length(body_text)` for all 69 (reading_accounting.txt). Of these, 35 are in the collection; the rest were read and not used (the 1944 Gauss despatch, Liberia 1920, Marshall 1948, and the vector neighbours listed in M8.3, among others).
- Documents quoted in the overview: **27** distinct documents (50 verified double-quoted passages, trace.py). Excerpts in the collection: **36**, across 33 of the 35 documents (quotations table, M6).
- The reading SELECT is the one above; the raw text is on disk in work/docs.

## M6. Quotations: each with its SELECT and its document
Every quotation below is a substring of the whitespace-collapsed `body_text` of its document (build_collection.py asserts it for every excerpt; verify_overview.py asserts it for every double-quoted passage in overview.md). SELECT for each: `SELECT body_text FROM document_cache WHERE volume_id=<v> AND document_id=<d>;`.

| finding | volume_id/document_id | verbatim text |
|---|---|---|
""")
for f,k,t,sel in quotes:
    A(f"| {f} | {k} | {t} |")
A("""
(The Kissinger sentence in frus1969-76ve15p2/d293, the Haiti Senate-committee sentence in frus1977-80v23/d257 and Carter's FCPA statement are editors' footnote text inside those documents' `body_text`; the overview says so where it uses them. The Carter signing statement itself is not quoted.)

## M7. Archival scope (channels labelled, never summed)

**Volume set for these counts:** the collection's 20 volumes: frus1894app1, frus1894app2, frus1922v01, frus1947v05, frus1947v07, frus1948v07, frus1949v08, frus1958-60v01, frus1961-63v20, frus1961-63v22, frus1964-68v04, frus1964-68v05, frus1969-76v08, frus1969-76ve09p2, frus1969-76ve11p1, frus1969-76ve12, frus1969-76ve15p2, frus1977-80v03, frus1977-80v23, frus1977-80v24. This set was chosen by reading for the question; it is not the whole scope.

### M7.1 CAME-FROM, the 35 documents' own source notes (arch1.out; `SELECT repository,record_group,lot_file,series_name,citation_era,raw_text FROM document_sources WHERE volume_id=? AND document_id=?` per document)
Tally read from `raw_text` (the repository/record_group columns mis-parse two rows, frus1969-76ve09p2/d161 and frus1958-60v01/d185, which I read from `raw_text`): Department of State central files, RG 59, 16 (decimal 12, central foreign policy file 3, subject-numeric 1); Department of State INR-NIE files, 1; Records of Henry Kissinger, RG 59 (Lot 91D414, entry A1 5403), 2; Jidda Embassy Files, RG 84, Lot 79F80, 1; presidential libraries 9 (Johnson 3, Kennedy 1, Carter 3, Ford 2); Library of Congress, Kissinger Papers, 1; Center for Military History, 1; no `document_sources` row (the four 1894-appendix documents), 4. Total 35. `external_citations` rows for these documents (pointed-at, per document; `SELECT count(*) FROM external_citations WHERE volume_id=? AND document_id=?`): 1 each for frus1958-60v01/d63, frus1964-68v05/d395, frus1969-76v08/d191 and frus1977-80v03/d230, 3 for frus1958-60v01/d131, none for the others (these are footnote mentions, not summed with the above).

NARA identifiers, from the JSON (arch3.out, arch3.py): Records of Henry Kissinger = central-files-index.json `lotFiles` row lotNumber 91D414, `hmsMlrEntryNumbers` ["A1 5403"], naId 2131131; series-facts-index.json `byNaId["2131131"]`: creator "Department of State. Office of the Secretary.", extent 11 linear feet 5 inches, 1973-1977, status "Restricted - Partly", restriction "FOIA (b)(1) National Security". Numerical File: central-files-index.json `numericalFile` microfilm M862, seriesNaId 654171 (no row in series-facts-index.json, so no access status). Presidential libraries from presidential-library-catalog.json: Johnson LBJ-NSF naId 567979 (series titles dated 1963-1969), Kennedy JFK-4 naId 1164 (1961-1963), Carter JC-NSA naId 560131 (1977-1981). The catalogue gives no access status. The Hawaii despatch shelf: central-files-index.json `countrySeries` category diplomaticDespatches, "Despatches from U.S. Ministers to Hawaii, 1843-1900", fileUnitNaId 177380751, the roll 1890-09-04 to 1893-07-31 naId 189267012: a candidate shelf by place and date, not proved to be the source of these printed documents.

### M7.2 POINTED-AT, footnote references of the same volumes (arch2.out; external-citation-index.json `targets`, summed over the volumes)
14 of the 20 volumes are in that index's volume list (absent: frus1894app1, frus1894app2, frus1969-76ve09p2, frus1969-76ve11p1, frus1969-76ve12, frus1969-76ve15p2); 1,218 references to 115 targets. Largest targets: Carter Library National Security Affairs 393; Johnson Library National Security File 152; Kennedy Library National Security Files 75; Nixon NSC Files 55; lot 81D113 32; President's Daily Diary 27; lot 85D240 19; lot 65D330 17; lot 80D177 10. Resolution through central-files-index.json and series-facts-index.json (arch3.out): 81D113 = naId 1487627, "Records of Deputy Secretary Warren Christopher", entry P 14, 1975-1981, Restricted - Partly; 85D240 = naId 2131132, EAP Assistant Secretary subject files, A1 5408, 1961-1974, Unrestricted; 65D330 = naId 602231, A1 1566, 1953-1964, Unrestricted; 80D177 = naId 111879278, Bureau of Human Rights and Humanitarian Affairs subject files, P 534, 1976-1979, Restricted - Partly. I did not use lots 66D193 and 72D192, whose NARA titles (Far Eastern bureau subject files 1955-62; "Speeches and Statements") do not agree with the authority's names (Vietnam Working Group Files; Rusk Files): the creator attribution is a decoy surface. Stated limits: the pointed-at channel stores citation fragments and anchors of lot, library and decimal kinds only, and its volume list begins at frus1911.

Not done: the harvest-level (HARVEST) surface was not provided; no record-group shard was read; `collection-usage-index.json` ranked collection counts (e.g. 741 notes citing Department of State central files across the 20 volumes) describe the volumes' notes generally and are not used in the overview.

## M8. VECTORS

**All cosines below are raw.** (No cosine was computed in this run: every distance below is a Hamming distance, the number of differing bits out of 512 between two documents' sign vectors. I did not compare any distance with the app's percentage, so the index's `retrieval.scoreCalibration` offsets (document 0.4, query 0.47) were not applied.)

### M8.1 Provenance and identity
Provenance digest in every artifact touched: index `provenanceDigest`, binary bytes 20-51, map bytes 20-51, shards manifest `provenanceDigest`, shard folder `.generation`, and the header of one shard (`frus1964-68v05.vec`, bytes 16-47) all equal **89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101**. Index `generated` stamp: **2026-10-15** (harvestGenerated 2026-10-15T06:55:14); model embeddinggemma-2-Q8_0, 512 shipping dims, `measuredRecallAt10` 0.9021, rerankPool 800 (the funnel's measured recall: a neighbour list can miss documents). Round trip (vec_baseline.out): 553 volumes, sum of `n` = 314,616 = `documents` in the binary header = rows mapped; decoded length = n asserted for every volume. Identity comes only from the index's id segments (vec.py).

### M8.2 Baselines at this digest (vec_baseline.out)
""")
A("```\n"+rd("vec_baseline.out")+"\n```")
A("""
Random pairs (20,000, seed 1877): mean 167.14, sd 14.77, 1st percentile 132. The near-duplicate line is mean - 8 sd = 48.99. The 25th-neighbour distance over 200 random anchors (seed 1878): 73-136, median 107. So a neighbour at 85-100 of 512 bits is well inside the random cloud's tail but is a reading lead, not a duplicate; a set's cohesion is read against 167.

### M8.3 Required operation 1: nearest 25 of an anchor, joined to the database and flagged (vec_neighbors.py, output vec_neighbors.out)
The scope for the IN-SCOPE flag is the 3,165 documents of the family and nexus queries together (apparatus excluded, Ed2 volumes included in the flag set but skipped in the scan). Literal = `corrupt|brib|graft|kickback|payoff|venal|embezzl|nepot|scandal` (Python `re.I`) over header+body. Each neighbour is joined on both keys to `document_dates` and `document_cache`. One anchor per finding:

| anchor | distances (25 nearest) | IN-SCOPE | OUTSIDE | OUTSIDE and ABSENT | OTHER-DECADE | not in this database |
|---|---|---|---|---|---|---|
| China 1947, Wedemeyer (frus1947v07/d582) | 85-103 | 11 | 14 | 11 | 2 | 0 |
| Hawaii 1892, Stevens (frus1894app2/d172) | 97-108 | 7 | 18 | 17 | 0 | 0 |
| Cuba 1922, White (frus1922v01/d864) | 94-113 | 2 | 23 | 23 | 4 | 0 |
| Vietnam 1967, Calhoun (frus1964-68v05/d258) | 97-104 | 7 | 18 | 18 | 3 | 0 |
| Lockheed 1975, Akins-Sultan (frus1969-76ve09p2/d161) | 75-112 | 4 | 21 | 21 | 14 | 0 |
| Haiti 1979, Habib (frus1977-80v23/d257) | 87-105 | 6 | 19 | 18 | 14 | 0 |

Read whole (OUTSIDE and ABSENT neighbours, chosen as the most likely to bear on the question): frus1922v01/d863 (loan law passed, Crowder to come to Washington: no bearing on corruption, not added), **frus1922v01/d872 (Acting Secretary to the Cuban chargé, 4 November 1922: no objection to the loan after revenue assurances, "great concern" about the amnesty bill and the cabinet; bears on the question and was added to the scope and the collection)**, frus1977-80v23/d260 (Haiti assessment 1980: aid cuts, no corruption content), frus1958-60v01/d55 (Durbrow letter on the Anderson visit: nothing on corruption in the whole document, 18,798 characters, searched for honest/integrity/squeeze/misuse words as well as the family), frus1964-68v04/d222 (Leonhart's pacification visit: nothing), frus1948v07/d310 (Stuart's August 1948 survey: leaders chosen "on the basis of personal reliability rather than military competence"; cronyism, not corruption by my rule, not added). The rule's quoted phrase in that last item is a note for you; it is not in the overview.

### M8.4 Required operation 2: near-duplicates before any count over a set I built
Over the 3,165-document scope (vec_neardup.py, vec_neardup.out): 3,160 of 3,165 are in the vector index (the 5 missing are chapter-heading rows, such as frus1958-60v01/ch1, that the index stores as pseudo-documents and that have no vector). Pairs closer than the line (48.99): 110. Of these 40 involve an Ed2 volume (the known reprints; Iran 1951-54 and Western Europe 1973-76, distance 0-4, excluded from every count). The other 70 were read by comparing the first 2,500 characters of both documents after whitespace collapse (vec_neardup_read.py, vec_neardup_read.out; difflib ratio >= 0.9 or equal = same text): 12 pairs carry the same text (4 pairs of 1894 Nicaragua despatches printed in both the main 1894 volume or Appendix I and the Nicaragua series; 2 Stevens despatches in the Hawaii appendix printed twice, one of 18 January 1893; a Soviet statement printed in two volumes; Truman-Attlee minutes; Lord Stanley to Colonel Stanton in 1867 and 1868; a 1981-88 memorandum in two volumes; a proclamation; a treaty text) and 58 do not (treaty and proclamation texts of different years, national intelligence estimates, meeting minutes). The published family count of 3,123 therefore contains roughly 12 documents printed twice, a 0.4% effect, which I left in and state here. For the collection set (vec_collection_dups.py, vec_collection_dups.out): 0 pairs inside the 35 below the line; each member's nearest neighbour within the set is 81-144 bits (median 110), none below 48.99. Cited copy for the Western Europe pair: the first edition, counted once.

### M8.5 Conditional operation: the map
**Not run.** The question cuts across regions and eras (Hawaii, Cuba, China, Vietnam, Saudi Arabia); a one-label region test would need an era-matched baseline on this layout, and I judged that a cluster figure would not bear on any claim. No cluster figure appears in either deliverable.

### M8.6 Which cited documents were vector-reached
- STRICT (returned by no query I logged; re-run against the pair): **one document**, frus1922v01/d872. The pair is outside the family query (`SELECT ... MATCH FAM` returns 3,123 documents, none is this pair), outside the nexus query, outside the Lockheed/FCPA query and outside every q7.py query that I ran (they are bm25 lists of the same match strings); it appeared only in the neighbour list of frus1922v01/d864 (distance 99). The other 34 documents each appear in the family result set (reach.out has the table).
- PRACTICAL (in no result set I had read when the neighbour list surfaced it): d872 is inside the same Crowder-mission chapter of the same volume as d852 and d864 (read whole) and d841 and d842 (seen in snippets), so it is practical at most and I count it as **not practically vector-reached**: the vectors confirmed a region already open and added the one document that carries the Department's own reply to the loan.
- Neighbours of other anchors that were also in the collection (frus1948v07/d322, frus1964-68v05/d395, frus1969-76ve09p2/d135) were already in the family set.

## M9. Per-finding provenance in the collection (collection.fruscollection)
35 documents, 36 excerpts, 6 findings (headings) plus a closing block of threads not followed and a generated archival-sources block. Each agent note opens "Agent finding, run s4, 2026-10-30". Every pair was asserted present and non-apparatus in `document_cache` by build_collection.py; no Ed2 volume; no duplicate pair; all seven composition keys present (the brief says six and lists seven; I followed the example).

## M10. TRACE TABLE (overview.md -> memo)

| overview statement | memo location |
|---|---|
| 553 volumes; 321,749 documents; 1,103 front matter; 8,481 editorial notes | M1 canary |
| second editions of two volumes left out | M2 |
| 35 documents; 20 of the 553 volumes | M9, M7 (volume list) |
| 3,123 documents carry a corruption word | M4.1 (stats.out line 1) |
| about one in a hundred among roughly 311,000 | M4.1 (3,123 of 311,429) |
| about three in four of those are really about corrupt dealing; nearer 2,300 | M4.3 (30 of 40; 0.75 x 3,123) |
| sample of 40: all 40 contain a form, 36 in plain forms; about 30 of 40 use it for corrupt dealing | M4.3 |
| 595 documents (nexus) | M4.4 / M3.3 |
| 94,049 control; none for the nonsense string | M1, M4.6 |
| Teapot Dome 2; spoils system 9; Abscam none | M4.6 |
| Watergate 183 | M4.6 |
| 177 documents dated 1990 or later; one carries a corruption word | M4.2 (1990s row), M4.6 |
| only one chapter heading names corruption (Vietnam 1958-60) | M3.5 |
| 69 documents retrieved whole | M5 |
| six anchors, nearest 25; one document added (Cuba, November 1922); none of the 35 printed twice | M8.3, M8.4 |
| Sixteen / one / two / one / nine / one / one / four (sources of the 35) | M7.1 |
| Kissinger records: lot 91D414, A1 5403, 2131131, 1973-1977, 11 ft 5 in, partly restricted | M7.1 |
| Numerical File 654171 | M7.1 |
| Johnson 567979 (1963-1969), Kennedy 1164 (1961-1963), Carter 560131 (1977-1981) | M7.1 |
| Hawaii despatches 177380751; roll 189267012 (Sept 1890-July 1893) | M7.1 |
| 14 of 20 volumes; 1,218 references to 115 targets; 393, 152, 75, 55 | M7.2 |
| lot 81D113 (1487627, 1975-1981, 32 refs); 85D240 (2131132, 1961-1974, 19); 65D330 (602231, 1953-1964, 17); 80D177 (111879278, 1976-1979, 10) | M7.2 |
| 11 of 698 series start before 1940, about one in sixty | M4.7 |
| begins with the 1911 volume | M7.2 |
""")
for q,k in ovq:
    qq=q[:90]+("..." if len(q)>90 else "")
    A("| quotation: '"+qq+"' | M6 row "+k[0]+"/"+k[1]+" |")
A("""
Numbers inside quotations (dates, $2.5 million, $5-10 billion, $18.4 million, FY 61 and so on) are the documents' own and are traced by their quotation rows. Statements of the form "the editors add" or "the editors record" are traced to the same document's text (retrieved whole, M5).

## M11. Checks made before finishing
1. Every double-quoted passage in overview.md that is a quotation of a document is a substring of that document's whitespace-collapsed `body_text` (verify_overview.py: 50 found; the 26 others are citation titles and search terms, not quotations). Every one of the 36 excerpts in the collection verified in its own document (build_collection.py assertion; verify_overview.py).
2. Every document the overview cites by URL (35) is in the collection, and every collection document is cited (verify_overview.py).
3. Reader-facing text has no SQL, table or column names, file paths or issue numbers; the history.state.gov addresses the brief asks for contain the id pair, which is the only place ids appear.

## M12. Limits and flags
- Thin or partial-library flag: this library holds the full series, so thinness here is not a partial-library effect; but several findings rest on 2-8 documents each, chosen by reading, and they are illustrations of a pattern, not a census.
- The family count is an upper bound (referent share 0.75).
- The Hawaii findings rest on one minister's despatches and the contrary statement of the Queen; I report both and do not decide.
- The China findings are about positions, not decisions; no document in the set records aid withheld because of corruption alone, and the overview says so.
- The 20-volume archival set was chosen by reading; its channel counts describe those volumes only.

## M13. Reproduction
Scripts in order: getdoc.py, ctx.py, q7.py, stats.py, stats2.py, arch1.py, arch2.py, arch3.py, vec.py, vec_baseline.py, vec_neighbors.py, vec_neardup.py, vec_neardup_read.py, vec_collection_dups.py, reach.py, quotes.py, build_collection.py, verify_overview.py, trace.py, write_memo.py. SQL files: q1.sql, q2.sql, q3.sql, q4.sql, q5.sql, q6.sql, q8.sql, q9.sql, q10.sql.
""")
open("memo.md","w").write("\n".join(M))
print("memo lines:",len("\n".join(M).splitlines()))
