# Scope memo — corruption and allegations of corruption in U.S. foreign policy (run s2, 2026-10-30)

Operator memo. Every number below carries its query, its counting surface and its denominator. The raw outputs named here are all in this run directory.

## M1. Coverage (house-rule COVERAGE)

    SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;
    -> 553|321749|1103|8481

553 volumes = the full series as the house rules define it. Every count below is conditional on this 553-volume index copy (2026-10-25). Read-only proof: `BEGIN; CREATE TABLE zz(x); ROLLBACK;` under `-readonly` failed with "attempt to write a readonly database".

Second editions: `frus1951-54IranEd2` and `frus1969-76ve15p2Ed2` are dropped everywhere (explicit `NOT IN` list); `frus1977-80v09Ed2` is kept. Defect logged and fixed: the first three probe passes (p1.out, p2.out, p3.out) used `NOT LIKE '%Ed2'`, which also dropped `frus1977-80v09Ed2`; it holds 3 family documents (d247, d334, d348; census.out), none cited. probe.py was corrected before p4 and every count used for a finding (scope1.out, census.out, lockheed.out, ff.out, p4.out) uses the explicit list.

Non-apparatus denominator (front matter, editorial notes, the two Ed2 volumes excluded): 311,429 documents (ff.out, `SELECT COUNT(*) FROM document_cache c WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')`).

## M2. Scope chosen and how it was found

- Question terms, looked up as index forms (stems) in `frus_documents_vocab` (queries.log line 3; output in the log): corrupt (2,253 docs in vocab), bribe (431), briberi (309), graft (372), embezzl (174), kickback (18). Vocab doc counts include apparatus.
- Editors' headings: heads.py walked every `volume_structures.structure_json` (553 volumes) for corrupt|brib|graft|kickback|embezzl|lockheed|payoff|illicit/improper/questionable payment|Corrupt Practices. Two headings only (heads.out): a 1936 Mexico stolen-vehicle convention and one 1958–60 Vietnam chapter title ("THE CAN LAO PARTY, CORRUPTION, AND THE USE OF U.S. AID"). Header field: `MATCH 'header:(corrupt OR bribe OR briberi OR graft OR kickback OR embezzl)'` returned 2 documents (header_hits.out). The editors do not organise by this subject; the scope is therefore built from document text.
- FAMILY (the working scope set): non-apparatus documents matching `corrupt OR bribe OR briberi OR graft OR kickback OR embezzl`:

      SELECT c.volume_id, c.document_id, substr(t.date_iso,1,3) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid
      LEFT JOIN document_dates t ON t.volume_id=c.volume_id AND t.document_id=c.document_id
      WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN (?,?)

  -> 3,036 documents in 447 volumes (scope1.out; ids in family_hits.json). Share of the non-apparatus index: 3,036 of 311,429. After the reprint check (M7) 3,020 distinct documents.
  Controls in the same pass (scope1.out): POSITIVE `"department of state"` 93,824 documents in 550 of 551 volumes (the one with none: frus1919Parisv05); NEGATIVE `ZZZ_IMPOSSIBLE_ZZZ` 0.
  Cross-check: the same family written as full words (`corruption OR bribery OR bribe OR graft OR kickback OR embezzlement`) gives the same count (3,033 under the over-broad Ed2 filter both ways; p3.out).
- Per-term (scope1.out): corrupt 2,175 docs / 399 vols; bribe OR briberi 654 / 280; graft 363 / 162; embezzl 169 / 84; kickback 18 / 17.
- Inclusion rule for the CITED set (the collection): a document is cited when it records corruption or a corruption allegation entering a U.S. decision, a U.S. démarche, or a foreign government's dealings with Washington; I read it whole first. Periodised on `document_dates.date_iso` (the document's own date), not the series year.

## M3. Literal share of the family (KNOWN TRAPS (a), (b))

share1.py: evenly spaced 40 from the (volume_id, document_id)-sorted family list of 3,036; text = header+dateline+source_note+body_text, whitespace-collapsed; Python `re` with `re.I` for the whole family.
- STRICT `\b(corrupt|corruption|bribe|bribery|graft|kickback|embezzlement)\b`: 36 of 40.
- TOLERANT `\b(corrupt\w*|brib\w*|graft(s|ing|er|ers|ed)?|kick[\s\-]?backs?|embezzl\w*)\b`: 40 of 40 (publish this). The four strict misses are inflections (bribes, bribed, grafting x2).
- Referent test (a 1.000 tests the stemmer): of the 40, 37 use the words for official or financial corruption; 3 use them in a moral or abstract sense (frus1874/d147 "corrupt doctrines", frus1882/d8 "corruption of infancy", frus1961-63v02/d330 "corruption of unbridled power"). A telegraphic-garble test (`corrupt group|text corrupt|garble…`) hit 0 of 40.
- False-friend test (ff.py): family share in the 14 cited volumes 370 of 7,361 vs whole index 3,036 of 311,429 (ratio 5.16); controls `"united states"` ratio 0.74, `"department of state"` 1.01. The family concentrates where the subject is; the controls do not. (Partly circular: the volumes were chosen by the family.)

Phrase censuses (census.py; whole hit set, each under 300; same text surface, Python `re.I`):

| MATCH | N | STRICT | TOLERANT | verdict |
|---|---|---|---|---|
| "questionable payments" | 9 | 1 of 9 | 1 of 9 | UNUSABLE: the index folds "questionable" into "question"; 8 hits are "question payment", "question. Payment" |
| "foreign corrupt practices" | 4 | 4 of 4 | 4 of 4 | usable; all in 1977–80 (frus1977-80v03/d152, d230, d248; frus1977-80v18/d57) |
| "illicit payments" | 16 | 16 of 16 | 16 of 16 | usable; 15 of 16 in 1977–80 volumes (ids in census.out) |
| "corrupt practices" | 81 | 74 of 81 | 81 of 81 | usable |

Lockheed set (lockheed.py, census of 50): `MATCH 'lockheed AND (bribe OR bribery OR payments OR scandal OR corruption)'` -> 50 docs. Literal "Lockheed" plus one of the words: 42 of 50. Referent (Lockheed with bribe/scandal/corrupt/payoff wording): 27 of 50, all dated 1973-07-06 to 1977-01-03, in 7 volumes (ve12 10, ve09p2 7, ve09p1 3, ve15p2 3, v31 2, v18 1, 1977-80v18 1). The other 23 are aircraft sales and balance-of-payments.
Trap logged: `MATCH 'lockhe'` (the vocab stem) returned 0 because the query stem is re-stemmed; `MATCH 'lockheed'` returns 190 docs in 78 volumes (p3.out, p4.out).

## M4. Decade shape (per 1,000 dated non-apparatus documents; scope1.out)

Numerator = family documents with that decade's `date_iso`; denominator = that decade's dated non-apparatus documents; top-volume share beside each.

| decade | family | denominator | per 1,000 | top volume (share of numerator) |
|---|---|---|---|---|
| 1860s | 109 | 11,268 | 9.7 | frus1868p2 16 of 109 |
| 1870s | 103 | 5,821 | 17.7 | frus1874 11 of 103 |
| 1880s | 82 | 6,484 | 12.6 | frus1888p2 14 of 82 |
| 1890s | 123 | 9,845 | 12.5 | frus1894app2 45 of 123 |
| 1900s | 108 | 10,261 | 10.5 | frus1906p1 16 of 108 |
| 1910s | 186 | 30,842 | 6.0 | frus1917 17 of 186 |
| 1920s | 79 | 20,374 | 3.9 | frus1922v01 8 of 79 |
| 1930s | 118 | 40,073 | 2.9 | frus1933v02 11 of 118 |
| 1940s | 475 | 75,872 | 6.3 | frus1947v07 71 of 475 |
| 1950s | 554 | 42,801 | 12.9 | frus1951-54Iran 31 of 554 |
| 1960s | 555 | 27,654 | 20.1 | frus1964-68v05 42 of 555 |
| 1970s | 435 | 22,258 | 19.5 | frus1969-76ve11p1 35 of 435 |
| 1980s | 104 | 6,038 | 17.2 | frus1981-88v05 11 of 104 |

(1840s 1 of 143 and 1850s 1 of 158 are too small to read; 3 family documents undated.) The 1890s figure leans on one volume (frus1894app2, the Hawaii appendix: 45 of 123). Body text includes editorial footnotes, so these rates blend document and editor language; I did not separate apparatus on the TEI surface (not needed for any finding, and stated in the overview's methods). The decade densities were not de-duplicated (M7 removes 16 reprints from the family, 13 of them dated before 1960).

Concentration (scope1.out top volumes): frus1947v07 71, frus1894app2 48, frus1964-68v05 42, frus1958-60v01 39, frus1948v07 37, frus1969-76ve11p1 35, frus1961-63v22 34, frus1944v06 33, frus1951-54Iran 31, frus1958-60v15 31.

## M5. Threads probed (probe.py; template SQL at the head of p1.out–p3.out; ranked by bm25 ASC)

| thread | MATCH | volumes | hits |
|---|---|---|---|
| China | corrupt OR graft | frus1943China, 1944v06, 1945v07, 1946v10, 1947v07, 1948v07, 1948v08, 1949v08, 1949v09 | 250 |
| Vietnam 1958–63 | corrupt | 1958-60v01, 1961-63v01–v04 | 63 |
| Vietnam 1964–68 | corrupt | 1964-68v01–v07 | 103 |
| Korea | corrupt | 1958-60v18, 1961-63v22, 1964-68v29p1, 1952-54v15p1 | 57 |
| Iran | corrupt OR bribe OR briberi | 1951-54Iran, 1958-60v12, 1961-63v17, 1964-68v22 | 70 |
| Saudi bribery | bribe OR briberi | 1955-57v13, 1958-60v12, 1958-60v13 | 21 |
| Central America | corrupt | 1977-80v15, 1969-76ve11p1 | 55 |
| Africa | corrupt | 1969-76ve05p1, 1977-80v17p2, 1964-68v23 | 34 |
| Lockheed | lockheed AND (bribe OR bribery OR payments OR scandal OR corruption) | all | 50 |
| FCPA / payments | "questionable payments" OR "foreign corrupt practices" | all | 13 (see M3: "questionable payments" unusable) |

(These probe counts were taken under the over-broad `NOT LIKE '%Ed2'` filter, M1; frus1977-80v09Ed2 is outside every one of these volume lists except the two all-volume probes.)

Central America and Africa were probed and are not written up as findings (thin on decisions in the top ranks; named as unfollowed threads in the overview and the collection).

## M6. Documents read and quoted

Reading SELECT (readdocs.py; raw text in texts/<volume>__<doc>.txt):

    SELECT c.header, COALESCE(c.dateline,''), COALESCE(c.source_note,''), c.body_text, length(c.body_text), t.date_iso
    FROM document_cache c LEFT JOIN document_dates t ON t.volume_id=c.volume_id AND t.document_id=c.document_id
    WHERE c.volume_id=? AND c.document_id=?

Retrieved whole (captured length = length(body_text) for every one; read.out): 26 documents — the 19 cited plus 7 neighbours read for the vector pass (frus1947v07/d900, frus1958-60v01/d176, frus1958-60v01/d155, frus1961-63v22/d204 [cited], frus1955-57v13/d321, frus1969-76ve09p2/d130, frus1977-80v03/d119). Counting d204 once: 25 distinct documents retrieved whole; 19 quoted (one passage each). For the longer texts (d161, d248, d308, d79, d152, d202) I read the passages around the family terms (350/450-character windows) rather than every line; the whole text is on disk.

Quotations: each passage below was checked as an exact substring of its document's body_text (verify.py, verify.out: 19 of 19, each occurring once; SQL `SELECT body_text, is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?`). All 19 documents are non-apparatus (fm=0, en=0).

| # | pair | date | passage (verbatim) | note |
|---|---|---|---|---|
| Q1 | frus1944v06/d148 | 1944-09-22 | "the two departments in which mismanagement and corruption are most flagrant and most dangerous to the continuance of the Government itself are the Ministries of Food and War" | Gauss despatch |
| Q2 | frus1946v10/d373 | 1947-01-07 | "The Generalissimo could use it to wipe out graft, corruption and incompetence in the government and in the Kuomintang." | Marshall to Soong (minutes) |
| Q3 | frus1947v07/d908 | 1947-05-08 | "I referred to a widespread feeling in United States that the present Government is controlled largely by reactionary elements and that there is much corruption and graft throughout the system." | Stuart, on the $1 billion loan request |
| Q4 | frus1948v07/d43 | 1948-01-28 | "many US reporters, when they come across any corruption or graft, play up the cases, making the US public believe that the entire Chinese Government is corrupt" | Stuart transmits Hollington Tong speech |
| Q5 | frus1958-60v01/d131 | 1960-04-07 | "it might prove difficult obtain adequate aid FY 61 if disturbing reports continue re alleged corrupt practices Can Lao party" | Durbrow to Diem |
| Q6 | frus1958-60v01/d135 | 1960-04-11 | "there is a risk that such rumors, even if untrue, might be picked up and exaggerated in a way which would not be helpful to the interests of Viet-Nam or the United States, particularly if there were any implication that US aid funds were involved, even indirectly" | Wood memcon, quoted by the editors in a footnote |
| Q7 | frus1964-68v05/d395 | 1967-11-13 | "There was unanimous agreement that a visible and credible anti-corruption effort would help a great deal in improving the Administration’s position, and in building a more effective GVN." | Katzenbach to Johnson |
| Q8 | frus1961-63v22/d202 | 1961-03-06 | "they seriously endanger the whole U.S. position in Korea, and threaten to discredit, not only the aid program in Korea, but the Mutual Security program as a whole" | Farley report summary |
| Q9 | frus1961-63v22/d204 | 1961-03-15 | "The underlying fact is that all hands agree the situation in Korea is not good; and American policy in Korea requires a fresh look." | Rostow to Kennedy; vector-reached (M8) |
| Q10 | frus1955-57v13/d16 | 1956-01-30 | "The fact was, however, that high Government officials were being bribed by the Saudis and the British could not be certain what would happen." | Lloyd, Eden visit, on Jordan |
| Q11 | frus1958-60v12/d168 | 1959-03-28 | "the possibility of raising the prices, if bribery is more useful than reduction of Kassem’s income" | Burke to Herter |
| Q12 | frus1964-68v22/d79 | 1965-04-23 | "giving rise to charges that Washington had bribed the Iranian Government to grant widespread immunities to US personnel" | CIA current intelligence |
| Q13 | frus1969-76ve09p2/d161 | 1975-09-11 | "Sultan said the Department or President Ford must do whatever is necessary to make sure the names are never divulged." | Akins telegram (its own summary) |
| Q14 | frus1969-76ve09p2/d152 | 1975-08-07 | "They don’t want to change. They are being forced to change by us, and they are going to go to other suppliers." | Kissinger, staff meeting |
| Q15 | frus1969-76ve15p2/d293 | 1975-10-07 | "We must do everything possible to keep this quiet." | Kissinger to Ford, 8 Oct 1975, as quoted by the editors in the source note |
| Q16 | frus1969-76ve12/d218 | 1976-02-24 | "if the whole issue is kept unsolved with the names of the officials involved remaining in doubt, democracy in Japan may suffer a fatal blow" | Miki to Ford |
| Q17 | frus1969-76ve12/d219 | 1976-03-11 | "I hope the Government of Japan can support the United States proposal for an international agreement to curtail such practices" | Ford to Miki |
| Q18 | frus1977-80v03/d248 | 1980-07-29 | "some exports are lost because foreign companies can bribe foreign officials while U.S. companies cannot" | Klutznick and Askew to Carter |
| Q19 | frus1977-80v03/d308 | 1978-06-22 | "Consensus for international agreement on illicit payments appears to be developing in UN working group on corrupt practices." | State paper |

Q6 and Q15 sit in editorial matter inside body_text (a footnote and a source note quoting another record); the overview attributes each to the record the editors quote.

## M7. Reprints and near-duplicates (before any count)

Run in vec.py at the digest in M8; line = random-pair mean − 8 sd = 167.1 − 8×14.8 = 49.0 bits.
- Cited set (19 pairs, all with a vector row): no pair under the line. Each member's nearest distance inside the set (vec.out): from 54 (frus1969-76ve12/d218 with d219, the letter and its reply; different texts) up to 151; the Vietnam pair d131/d135 at 96. No document is cited twice.
- Family set (3,036 pairs, 3,031 with a vector row; 5 have none): 66 pairs under the line. dups.py compared both texts of every pair (token sequence ratio over the first 3,000 tokens; agree at ≥ 0.80; dups.out): 28 agree. dups_headers.out shows the 28 fall into 21 groups. Five of those groups are not reprints but form documents with different dates or parties (presidential proclamations of 1902–1914 extradition treaties naming bribery among extraditable crimes; Estonia/Bulgaria/Czechoslovakia and Latvia/Lithuania treaties of 1923–25): counted as distinct. The other 16 groups are one document printed twice (same date and text; e.g. frus1894Nicaragua/d12 = frus1894app1/d263; frus1950v03/d728 = frus1950v07/d977; frus1951-54Iran/d355 = frus1952-54v10/d403): 16 copies removed -> 3,020 distinct family documents. A reprint farther apart than 49 bits is not caught by this check.

## M8. VECTORS

All cosines below are raw. (No cosine was computed; every distance is a Hamming distance over the 512-bit sign rows. The index's retrieval.scoreCalibration offsets were not applied because no comparison with the app's percentage was made.)

Provenance (vec.out): `provenanceDigest` 89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101, identical in semantic-vectors-index.json, bytes 20–51 of semantic-vectors-binary.bin, bytes 20–51 of semantic-map.bin, semantic-shards-manifest.json, the shard folder's .generation file, and bytes 16–47 of the one shard header read (frus1947v07.vec). They agree. Index `generated`: 2026-10-15. Binary: FRSV version 1, 512 dims, 314,616 documents, 660 centroids. Identity round trip: decoded length = n for all 553 volumes (314,616 rows). Identity taken only from the index's id segments.

Baselines at this digest (vec.py; seeds as in the card): random pairs 20,000 (seed 1877): mean 167.1, sd 14.8, 1st percentile 132. 25th-neighbour distance over 200 random documents (seed 1878): min 73, 10th pct 93, median 107, 90th pct 119.

REQUIRED 1 — nearest 25 by Hamming over the corpus binary (Ed2 rows masked), each joined on both keys to document_cache and document_dates (vec_neighbours.json; flags: scope = the 3,036-document family; literal = the tolerant family regex, re.I):

| anchor | nearest / 25th | in scope | literal | not in DB | read and outcome |
|---|---|---|---|---|---|
| frus1947v07/d908 | 81 / 98 | 0 of 25 | 0 of 25 | 0 | read d900 (Stuart, 27 Apr 1947): aid/loan politics, no bearing on corruption (vocabulary scan: 0 hits) |
| frus1958-60v01/d131 | 81 / 101 | 10 of 25 | 10 of 25 | 0 | read d176 (Diem–USOM memcon on the Civil Guard) and d155 (Williams letter): no bearing (0 hits) |
| frus1961-63v22/d202 | 97 / 119 | 9 of 25 | 9 of 25 | 0 | read d204 (nearest, 97): Rostow tells Kennedy the Farley report requires a fresh look at Korea policy — BEARS, added to scope and collection |
| frus1955-57v13/d16 | 85 / 104 | 4 of 25 | 4 of 25 | 0 | read d321 (another record of the same 30 Jan 1956 meeting, on Syria): no bearing |
| frus1969-76ve09p2/d161 | 75 / 112 | 4 of 25 | 4 of 25 | 0 | read d130 (Akins, Mar 1975): no bearing (0 hits) |
| frus1977-80v03/d248 | 72 / 108 | 3 of 25 | 3 of 25 | 0 | read d119 (Blumenthal, Mar 1978, export policy): no bearing (0 hits) |

"Vocabulary scan" = shady|irregular|squeeze|rake-off|payoff|commission|agents' fees|favoritism|nepotism|venal|misuse|diversion|black market|profiteer|graft|corrupt|brib|Khashoggi|integrity|honest over each neighbour's text (queries.log). No anchor's neighbour lay in a volume absent from document_cache (the database holds all 553). The d908 neighbours are within 81–98 of the anchor, the d202 neighbour at 97: both inside the random 25th-neighbour range (73–119), i.e. ordinary near neighbours, not unusual closeness. A neighbour is a lead, not evidence; absence of a neighbour proves nothing (the index's retrieval block records the funnel's measured recall; not re-measured here).

REQUIRED 2 — near-duplicates before any count: M7.

CONDITIONAL — the map: NOT RUN. No finding claims the subject forms a region, and no cluster figure is published, so the label test was not needed.

Vector-reached documents cited in the overview:
- STRICT (returned by no logged query): frus1961-63v22/d204. Re-run of every logged MATCH against the pair: `MATCH 'corrupt OR bribe OR briberi OR graft OR kickback OR embezzl OR lockheed OR "corrupt practices" OR "illicit payments" OR "questionable payments"' AND c.volume_id='frus1961-63v22' AND c.document_id='d204'` -> 0; relaxed control on the same pair `MATCH 'farley'` -> 1. It is not in family_hits.json.
- PRACTICAL (in no result set read before the neighbour list surfaced it): frus1961-63v22/d204 (same document). No other cited document is vector-reached under either reading.

## M9. Archival scope (two channels, never summed; JSON surfaces named)

Volume set for the archival pass: the 14 volumes of the 19 cited documents.

CAME-FROM (document_sources, one row per cited document; arch1.out, plus d204 in queries.log):

| source as stored | cited documents | resolved to (bundled JSON) |
|---|---|---|
| Department of State, Central (Decimal) Files, RG 59: 893.20, 893.51, 811.20200(D), 751K.00, 751K.5, 787.00 | frus1944v06/d148, 1947v07/d908, 1948v07/d43, 1958-60v01/d131, d135, 1958-60v12/d168 | not resolved: no Central Decimal File series row in series-facts-index.json; decimal keys not glossed in this pass |
| Marshall Mission Files, Lot 54 D 270, RG 59 | frus1946v10/d373 | curated-lot-resolutions.json: "candidates" — NARA arranged it under creator NAID 10481258 (Office of the Special Envoy to China), ten series, e.g. 872088 Cables Received, 872091 Records Relating to Political Affairs; none has a series-facts row |
| Conference Files, Lot 62 D 181, RG 59 | frus1955-57v13/d16 | curated "possible": series NAID 602875, Conference Files, entry A1 3051B, 1949–1972, Unrestricted, College Park (series-facts-index.json; creator Office of the Secretary, Executive Secretariat; matched by name, not control number) |
| Johnson Library, National Security File, Country File, Vietnam | frus1964-68v05/d395 | presidential library; not resolved to an identifier |
| Kennedy Library, President's Office Files, Countries, Korea; Kennedy Library, National Security Affairs (Files), Countries, Korea | frus1961-63v22/d202; d204 | not resolved |
| CIA files, Job 79-T00472A | frus1964-68v22/d79 | not resolved (no CIA job in the bundled indexes) |
| RG 59, Transcripts of Secretary of State Kissinger's Staff Meetings, Entry 5177 | frus1969-76ve09p2/d152 | volume-sources-index.json majorCollections names it "E5177 [formerly Lot 78D433]"; no series-facts row reached |
| Ford Library, NSA, Presidential Country Files for the Middle East and South Asia (stored with RG 84 Jidda Embassy Files, from the footnote) | frus1969-76ve09p2/d161 | stored row mixes two sources (raw text begins "Ford Library"); not resolved |
| RG 59, Records of Secretary of State Henry Kissinger, Entry 5403 | frus1969-76ve15p2/d293 | not resolved |
| Ford Library, NSA, Presidential Correspondence with Foreign Leaders, Japan | frus1969-76ve12/d218, d219 | not resolved |
| Carter Library, White House Central Files, Subject File TA; Carter Library, NSA, Brzezinski Material, Evening Reports | frus1977-80v03/d248; d308 | not resolved |

POINTED-AT (external_citations within the cited documents; arch1.out): Central Files 751K.00/4–1360 and 851K.392/4–460 (d131); Saigon Embassy Files, Lot 65 F 115, 350.1 Political Parties—Can Lao (d131; not in central-files-index, lot-claimants or curated lots); FE Files, Lot 62 D 26, MC-Vietnam (d135; central-files-index.json lotFiles: NAID 1965953, "Subject, Personal Name, and Country Files", RG 59, entry A1 3113, control match; series-facts: creator Bureau of Far Eastern Affairs, Office of the Assistant Secretary — consistent with "FE Files" — 1960–1963, Restricted–Partly, FOIA (b)(1), College Park); Eisenhower Library, Herter Papers, Iraq (d168); Johnson Library, President's Daily Diary (d395); Kennedy Library POF Korea (d202); Central Files 795B.00/3-1561 (d204); Carter Library WHCF TA-8 (d248). d161's footnote names RG 84, Jidda Embassy Files, Lot 79F80, POL Northrop and Lockheed, read in the text; the pointed-at table stores no row for it, and 79F80 is not in central-files-index.json.

Pointed-at ranking over the 14 volumes (collection-usage-index.json, generated 2026-10-20; arch4.py; footnote notes naming each collection): Department of State central file 918; Lot 54D270 (Marshall Mission) 439; Johnson Library NSF 214; Ford Library NSA 211; Nixon NSC Files 178; Central Files 1967–69 171; Carter Library NSA 150; Kennedy Library NSF 79; Eisenhower Library Whitman File 73. These are notes, not documents, and a different channel from the came-from table.

Pointed-at channel limits (re-derived): earliest dated row 1910-12-06 (`SELECT MIN(t.date_iso) FROM external_citations e JOIN document_dates t ON …`); 1,545 rows in 891 documents of the 14 volumes; it stores fragments, and lot, library and decimal anchors only.
Pre-1940 reach (re-derived, arch5.py): series-facts-index.json holds 698 series, 11 of 698 with an inclusive start before 1940. The pre-1940 family (about 900 documents, M4) has essentially no bundled shelf; that is a limit of the offline stack, not an archival absence.
[HARVEST]: no path given; surface unavailable.

## M10. Absence searches (p4.py; same predicate as M2 plus `c.volume_id LIKE ?`; controls in the same pass: "department of state" 93,824 in 550 volumes; ZZZ_IMPOSSIBLE_ZZZ 0)

| search | volumes | result | relaxed form, same surface |
|---|---|---|---|
| "foreign corrupt practices" | frus1981-88% (13 volumes, 4,140 non-apparatus documents) | 0 | "corrupt practices" 1 doc / 1 vol; corrupt OR bribe OR briberi 59 docs / 11 vols |
| "church committee" AND (bribe OR bribery OR payments) | all | 3 docs / 2 vols | "church committee" 42 / 15 |
| lockheed AND (bernhard OR netherlands OR dutch) | all | 13 / 8 | lockheed 190 / 78 |
| lockheed AND (italy OR italian) | all | 20 / 15 | — |
| (bribe OR bribery) AND (consul OR consular) AND (fee OR fees) | all | 27 / 21 | bribe OR bribery 654 / 280 |
| "anti corruption" OR anticorruption | all | 55 / 29 | — |

Thin: the post-1980 record (13 volumes) and anything after 1980 may reflect what is published, not what happened.

## M11. TRACE TABLE (overview -> memo)

| overview item | memo line |
|---|---|
| "about one document in a hundred" (3,036 of 311,429; 3,020 after reprints) | M2, M7 |
| "447 of the 553 volumes" | M2 |
| "about three in every thousand in the 1930s … about twenty in the 1960s and 1970s" | M4 rows 1930s, 1960s, 1970s |
| "the editors gave the subject a chapter heading once" | M2 (heads.out) |
| "nearly all of the forty sampled use the words for official or financial wrongdoing" (37 of 40) | M3 |
| Lockheed: "about two dozen documents in seven volumes, 1973–1977" (27 of 50) | M3 |
| "'questionable payments' … the index cannot isolate" (1 of 9) | M3 |
| "Foreign Corrupt Practices Act appears in four documents, all 1977–80; none in the thirteen 1981–88 volumes" | M3, M10 |
| "sixteen documents printed twice" | M7 |
| "eleven of nearly seven hundred series start before 1940" (11 of 698) | M9 |
| Conference Files series details | M9 |
| FE Files Lot 62 D 26 details | M9 |
| Marshall Mission Files candidates | M9 |
| Q1–Q19 quotations | M6 rows Q1–Q19 |
| Korea Rostow memorandum "found by its similarity" | M8 |
| collection membership of every cited document | M12 |

## M12. Collection check

collection.fruscollection holds 19 document entries = the 19 cited pairs (cited.txt), each verified present in document_cache (verify.py), no duplicate pair, no Ed2 volume; 19 excerpt entries = Q1–Q19 (verified 19 of 19). Every document the overview cites is in the collection; every quotation in the overview is one of Q1–Q19.
