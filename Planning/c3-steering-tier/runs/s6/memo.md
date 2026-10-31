# Memo: corruption and U.S. foreign policy (run s6, 2026-10-30)

For the operator. Every number in the overview is traced in the TRACE TABLE at the end. Files named here are in this run directory.

## 0. Coverage and controls

Canary (first command, `queries.log` line 1): `SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;` returned `553|321749|1103|8481`, as required. Read-only proof (second command) failed with "attempt to write a readonly database". All counts below are conditional on this library: **553 of the 553 volumes of the series are indexed**, so there is no partial-library qualifier on volume coverage (FRUS itself is a selection). Two second-edition volumes (frus1951-54IranEd2, frus1969-76ve15p2Ed2) are set aside wherever a count is said to exclude them, and no cited document is from an Ed2 volume. After excluding both Ed2 volumes, front matter and editorial notes, the denominator is 311,429 documents (see N2).

Counting surface: the index's `document_cache.body_text` (flattened, editors' footnotes included) for the FTS inventory and the regex counts; no TEI scan was run, so the spelling-variant rule is met only by the regex family and its limit is stated (the family missed "grafters"). Periodised on `document_dates.date_iso`, never on the volume's series year. Regex flavour: Python `re`, case-insensitive for the family (TOLERANT), case-sensitive for the STRICT list; FTS matches are SQLite porter-stem matches, whose case-insensitivity differs, so a family was counted with one tool (Python regex over the stored text) for every published share.

## 1. Scope chosen and how found

**Question.** How has corruption, or allegations of corruption, affected U.S. foreign policy decisions or the conduct of diplomacy?

**Inclusion rule.** (i) Inventory: a document is a candidate if the index's FTS MATCH hits any of `corrupt OR bribe OR bribery OR kickback OR embezzle OR malfeasance OR peculation OR graft OR venal OR nepotism OR cronyism OR payoff` (3,353 documents, non-apparatus, Ed2 volumes excluded). (ii) Family (final): the Python regex `\b(corrupt\w*|brib\w*|kickback\w*|embezzl\w*|malfeasance|peculat\w*|graft|venal\w*|nepotism|cronyism)\b` (case-insensitive) over `body_text`; `payoff` was dropped after the referent sample showed it (and figurative "bribe") was the main false friend. (iii) Core set: at least 3 family matches in the document body: 479 documents in 203 volumes (the referent sample passed 0.80 only here). (iv) Cited set: 30 documents read whole and chosen because an official links corruption (or the allegation) to an American action, or says why not.

**How found.** I read the editors' headings first (header-only FTS: `frus_documents MATCH 'header:(corrupt OR bribe OR bribery OR graft OR kickback OR embezzle OR scandal OR malfeasance OR nepotism OR peculation OR "improper payments" OR "illegal payments" OR "questionable payments")'` returned 2 documents, neither relevant), so there is no editors' chapter-heading formula for this subject; I therefore went to the body text. I ranked the 3,353 candidates by number of family matches (`scan1.csv`, then `scan2.csv`), read passages around the matches of the top ~60 (`snips_*.txt`), and followed the threads that emerged (Vietnam, China, client-regime stability, Lockheed, Koreagate, Hawaii) with targeted FTS queries (q5.sql: the Lockheed/FCPA/illegal-payments query) and, for Koreagate, `"Tongsun Park" OR Koreagate` (q8.sql). The Koreagate thread came from my own background knowledge of the episode, not from the inventory or from a vector operation: the family regex does not catch it.

**Controls (SCOPING).** Positive control, phrase "Department of State": nonzero in 550 of 551 non-Ed2 volumes (the exception is frus1919Parisv05, 89 non-apparatus documents, `zero_dos.out`; I did not investigate why, so a count of that phrase is not a clean per-volume control for that volume); negative control "ZZZ_IMPOSSIBLE_ZZZ": 0 documents everywhere (`ff.out`, `q1.out`). Both controls were also run for pre-1860 (97 of 483 and 0 of 483, `q8.sql`).

**False-friend test.** See N8: the family is 5.8 per 100 documents in the ten volumes richest in it and 0.9 elsewhere (a contrast guaranteed in part by the choice of volumes); "Department of State" is 35.1 and 30.0 per 100 in the same groups. The family measures the subject; the control moves little.

## 2. Numbers (audit form)

Surface for all of N2 to N14: index (`frus-copy-2026-10-25.db`), non-apparatus, Ed2 volumes excluded, regex or FTS as stated.

- **N1** 553 volumes; 321,749 documents; 1,103 front matter; 8,481 editorial notes. SQL: the canary above.
- **N2** 311,429 documents, the denominator. SQL (`ff.py`): `SELECT volume_id,COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0 AND volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') GROUP BY volume_id;` summed in Python = 5,851 (top-10 volumes) + 305,578 (others) = 311,429. Output `ff.out`.
- **N3** 3,174 documents with at least one family match. Script `scan2.py`; predicate: `SELECT d.volume_id,d.document_id,d.header,length(d.body_text),d.body_text FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH 'corrupt OR bribe OR bribery OR kickback OR embezzle OR malfeasance OR peculation OR graft OR venal OR nepotism OR cronyism OR payoff' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')` (3,353 rows), then the family regex on `body_text` (3,174 with at least one match). The identity of every row is (volume_id, document_id); `rowid` is used only to join the FTS table to its content table and is never reported. Output `scan2.csv`.
- **N4** 479 documents with at least 3 matches in 203 volumes (`scan2.csv`, `decade2.out`: "core docs 479 volumes 203"; at least 5: 140 documents, 86 volumes).
- **N5** "About one in a hundred" = 3,174 of 311,429 (1.02 per 100); "one in 650" = 311,429 / 479 = 650.1.
- **N6 (referent shares)**. Core set (>=3): 40 evenly spaced from the (volume_id, document_id)-sorted list, index `int(i*(N-1)/39)`, N=479, second match shown (`core_sample40.txt`, `core_sample.py`); I judged the family meant corruption or bribery in public or commercial life in **35 of 40** (the 5 that did not: three extradition-treaty crime lists, two figurative uses: 12, 85, 110, 183, 220 in the file's index). The wider candidate list (3,353 FTS hits, family including `payoff`): 40 evenly spaced (`sample40.txt`, `share.py`), judged **27 of 40** on-referent (0.675, below 0.80, so that list is not used for any claim except to choose what to read). A 1.000 tolerant share tests the stemmer, not the referent, so the referent was tested separately as above.
- **N7 (tolerant and strict, labelled)**. Over header+dateline+source_note+body_text, whitespace-collapsed (`share2.py`, `share2.out`): core set TOLERANT (the family regex) 479 of 479, STRICT (`\b(corruption|corrupt|bribery|bribe|graft)\b`, case-sensitive) 419 of 479; in the 40-sample TOLERANT 40 of 40, STRICT 37 of 40. Candidate list (old regex with payoff, `share.py`): TOLERANT 3,306 of 3,353, STRICT 2,509 of 3,353.
- **N8 (controls)**. `ff.out`: top-10 volumes by core count (frus1894app2, frus1958-60v01, frus1947v07, frus1961-63v22, frus1964-68v05, frus1950v06, frus1951-54Iran, frus1969-76ve04, frus1903, frus1906p1): family (>=1) 342 of 5,851 (5.8 per 100) vs other volumes 2,832 of 305,578 (0.9 per 100); `MATCH '"Department of State"'` 2,052 of 5,851 (35.1 per 100) vs 91,772 of 305,578 (30.0 per 100); `MATCH 'ZZZ_IMPOSSIBLE_ZZZ'` 0 of 5,851 and 0 of 305,578. Overview rounds to 6, 0.9, 35, 30.
- **N9 (decade shape, per 1,000 dated non-apparatus documents)**. `decade2.py`, `decade2.out`; numerator = documents in `scan2.csv` with at least 3 matches, denominator = documents with a non-empty `document_dates.date_iso` (SQL in `queries.log`), decade = first three characters of `date_iso`. Core (>=3), numerator of denominator, per 1,000, top-volume share: 1860s 13 of 11,268 = 1.2 (frus1868p2 3 of 13); 1870s 18 of 5,821 = 3.1 (frus1876 3 of 18); 1880s 19 of 6,484 = 2.9 (frus1888p2 4 of 19); 1890s 28 of 9,845 = 2.8 (**frus1894app2 18 of 28**); 1900s 36 of 10,261 = 3.5 (frus1903 6 of 36); 1910s 26 of 30,842 = 0.8 (frus1918 3 of 26); 1920s 20 of 20,374 = 1.0 (frus1922v01 3 of 20); 1930s 13 of 40,073 = 0.3 (frus1932v04 3 of 13); 1940s 48 of 75,872 = 0.6 (frus1947v07 11 of 48); 1950s 65 of 42,801 = 1.5 (frus1950v06 7 of 65); 1960s 93 of 27,654 = 3.4 (frus1958-60v01 11 of 93); 1970s 76 of 22,258 = 3.4 (frus1969-76ve04 6 of 76); 1980s 24 of 6,038 = 4.0 (frus1977-80v15 4 of 24); 1990s 0 of 177. The 1840s and 1850s have 0 of 143 and 0 of 158. Several decades' numerators rest on a few volumes (1890s: 18 of 28 from the Hawaii appendix).
- **N10** The Hawaii appendix share: 18 of 28 (1890s, N9).
- **N11 (pre-1860)** `q8.sql`: 483 non-apparatus dated documents before 1860-01-01 in 9 volumes; "Department of State" 97 of 483 (positive control), ZZZ 0 of 483 (negative control); the family (>=1) returns 2 (one in the 1840s, one in the 1850s: `decade2.out`); the wider query `corrupt OR bribe OR bribery OR peculation OR defalcation OR extortion OR exactions OR embezzle OR malversation OR venal OR "presents to" OR squeeze OR irregularities` returns 49 of 483, which I did not read, and which includes the false friends "extortion", "exactions" and "irregularities".
- **N12 (after 1989)** 177 dated documents in the 1990s decade, 0 with a family match (`decade2.out`).
- **N13 (other terms; FTS counts of non-apparatus documents, `q7.sh`)**: Watergate 183 documents in 51 volumes; "Teapot Dome" 2 in 2; "Bank of Credit and Commerce" 1 in 1; "Iran-Contra" 11 in 5; `Church AND Subcommittee AND Multinational` 13 in 10; "Tongsun Park" or Koreagate: 5 documents (q8.sql; 4 for "Tongsun Park" and 3 for Koreagate, overlapping).
- **N14** Term split (`split.out`) over the 3,353 candidates, occurrences/documents: corrupt* 3,369/2,176; brib* 917/654; graft 375/314; embezzl* 360/169; venal* 180/157; malfeasance 80/69; nepotism 52/47; peculat* 35/33; kickback* 21/18; cronyism 7/6. Top surface forms: corruption 2,231; corrupt 938; bribery 392; graft 375; embezzlement 260; bribe 205; bribes 179. "About 50" documents for nepotism and cronyism = 47 + 6 = 53 documents (some may overlap).
- **N15** Cited set: 30 documents in 20 volumes (`scope_keys.txt`); 28 of 30 have a `document_sources` row, 5 of 30 have rows in `external_citations` (queries in `queries.log`; the two without a source line are the two Hawaii appendix statements); 21 of the 30 are in the core set (>=3 matches).

## 3. Quotations (each verified against its document)

Method: each document was retrieved whole into `docs/<volume>__<doc>.txt` by `dump.py` (`SELECT header,dateline,source_note,body_text,length(body_text),is_front_matter,is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?`), and `verify_quotes.py` checks each passage below as a substring of the whitespace-collapsed text (`quotes_verified.json`: 40 of 40 verified, occurrences column). The collection's 16 excerpts are the same passages, checked as substrings of the raw (uncollapsed) stored text. The overview's 16 quoted documents use Q1, Q3, Q4, Q5, Q8, Q10 (with Q33, Q34 inside it), Q11, Q14, Q17, Q19, Q26, Q27, Q28, Q29, Q30, Q32. The overview also quotes the single words and short phrases "Koreagate", "grafters" and "straight unadulterated corruption", which are inside Q29/Q30, Q4 and Q6. Q19 sits in the **editors' note** to document 293 (it quotes a memorandum of conversation of 8 October 1975), not in the body of the memorandum; the overview says so.

| Id | Document (volume/doc) | SELECT | Passage | Occurrences |
|---|---|---|---|---|
| Q1 | frus1943China/d202 | SELECT body_text FROM document_cache WHERE volume_id='frus1943China' AND document_id='d202'; | “Nepotism and favoritism are rife. Graft and bribery are commonplace.” | 1 |
| Q2 | frus1944v06/d269 | SELECT body_text FROM document_cache WHERE volume_id='frus1944v06' AND document_id='d269'; | “ridding the Government of corrupt and inefficient high ranking civil and military officials” | 1 |
| Q3 | frus1947v07/d591 | SELECT body_text FROM document_cache WHERE volume_id='frus1947v07' AND document_id='d591'; | “the widespread corruption and graft among Government officials and military officers on all levels have cost the Government the confidence and support of the people.” | 1 |
| Q4 | frus1948v07/d590 | SELECT body_text FROM document_cache WHERE volume_id='frus1948v07' AND document_id='d590'; | “The same old inefficient grafters are still occupying the same old positions (with some musical chairs variations)” | 1 |
| Q4b | frus1948v07/d590 | SELECT body_text FROM document_cache WHERE volume_id='frus1948v07' AND document_id='d590'; | “General Marshall has borne witness to the manner in which our aid already given has been wasted, our advice disregarded and our best efforts on China’s behalf rendered abortive.” | 1 |
| Q5 | frus1958-60v01/d160 | SELECT body_text FROM document_cache WHERE volume_id='frus1958-60v01' AND document_id='d160'; | “Diem somewhat irritably then reiterated Can Lao party’s principal job is to ferret out and stop corruption rather than engage in any corrupt practices.” | 1 |
| Q5b | frus1958-60v01/d160 | SELECT body_text FROM document_cache WHERE volume_id='frus1958-60v01' AND document_id='d160'; | “Whether they were true or not more and more people are believing them and this is causing discontentment in the country.” | 1 |
| Q6 | frus1958-60v01/d111 | SELECT body_text FROM document_cache WHERE volume_id='frus1958-60v01' AND document_id='d111'; | “In Ladejinsky’s opinion, this is straight unadulterated corruption” | 1 |
| Q7 | frus1964-68v04/d280 | SELECT body_text FROM document_cache WHERE volume_id='frus1964-68v04' AND document_id='d280'; | “The worst problem in Vietnam is the problem of corruption.” | 1 |
| Q7b | frus1964-68v04/d280 | SELECT body_text FROM document_cache WHERE volume_id='frus1964-68v04' AND document_id='d280'; | “The President then picked up this theme and asked if there were any steps we can take to find and deal with corruption before his critics got there.” | 1 |
| Q8 | frus1964-68v05/d197 | SELECT body_text FROM document_cache WHERE volume_id='frus1964-68v05' AND document_id='d197'; | “Most of the generals are corrupt. Most of the senior officials in the provinces are corrupt.” | 1 |
| Q9 | frus1964-68v05/d258 | SELECT body_text FROM document_cache WHERE volume_id='frus1964-68v05' AND document_id='d258'; | “Komer suggested blacklisting GVN officials believed to be engaged in corruption and then instructing U.S. advisers to avoid them.” | 1 |
| Q10 | frus1969-76v06/d175 | SELECT body_text FROM document_cache WHERE volume_id='frus1969-76v06' AND document_id='d175'; | “The inability of the GVN to do anything about high level corruption is sharply affecting my ability—the American ability—to help you.” | 1 |
| Q11 | frus1961-63v23/d355 | SELECT body_text FROM document_cache WHERE volume_id='frus1961-63v23' AND document_id='d355'; | “State argues that corruption is mostly at the top, that it is characteristic of Philippine politics and may be no worse than in a good many other countries.” | 1 |
| Q12 | frus1961-63v22/d249 | SELECT body_text FROM document_cache WHERE volume_id='frus1961-63v22' AND document_id='d249'; | “They have produced convincing evidence that they will not tolerate corruption, graft, bribes, smuggling, tax evasion, or political blackmail in government, military or civilian life.” | 1 |
| Q13 | frus1961-63v17/d27 | SELECT body_text FROM document_cache WHERE volume_id='frus1961-63v17' AND document_id='d27'; | “though the Shah himself is honest, many of his family and entourage are not.” | 1 |
| Q14 | frus1969-76ve09p2/d122 | SELECT body_text FROM document_cache WHERE volume_id='frus1969-76ve09p2' AND document_id='d122'; | “the unchecked growth of corruption at the present rate would probably start to breed political instability fairly soon after King Faisal (who is honest and admires honesty in others) passes from the scene.” | 1 |
| Q15 | frus1969-76ve09p2/d122 | SELECT body_text FROM document_cache WHERE volume_id='frus1969-76ve09p2' AND document_id='d122'; | “the U.S. government will not become a party to facilitating corruption” | 1 |
| Q16 | frus1977-80v18/d206 | SELECT body_text FROM document_cache WHERE volume_id='frus1977-80v18' AND document_id='d206'; | “The issue of corruption is the greatest single threat to the continued stability of the SAG ruling family.” | 1 |
| Q16b | frus1977-80v18/d206 | SELECT body_text FROM document_cache WHERE volume_id='frus1977-80v18' AND document_id='d206'; | “I do not know of any truly effective means that we can use to help correct the situation.” | 1 |
| Q17 | frus1977-80v23/d252 | SELECT body_text FROM document_cache WHERE volume_id='frus1977-80v23' AND document_id='d252'; | “it is the toughest, most ambitious U.S. aid package ever presented to the GOH, and one which focuses squarely on one of the most important factors in Haiti’s development equation today: corruption.” | 1 |
| Q18 | frus1969-76ve15p2/d292 | SELECT body_text FROM document_cache WHERE volume_id='frus1969-76ve15p2' AND document_id='d292'; | “Lockheed paid bribes to Franz Josef Strauss, his wife and the CSU.” | 1 |
| Q18b | frus1969-76ve15p2/d292 | SELECT body_text FROM document_cache WHERE volume_id='frus1969-76ve15p2' AND document_id='d292'; | “I frankly do not believe that there is anything useful we can do at this point.” | 1 |
| Q19 | frus1969-76ve15p2/d293 | SELECT body_text FROM document_cache WHERE volume_id='frus1969-76ve15p2' AND document_id='d293'; | “We must do everything possible to keep this quiet.” | 1 |
| Q20 | frus1969-76ve09p2/d152 | SELECT body_text FROM document_cache WHERE volume_id='frus1969-76ve09p2' AND document_id='d152'; | “Except that that is the way business is done in the Middle East.” | 1 |
| Q20b | frus1969-76ve09p2/d152 | SELECT body_text FROM document_cache WHERE volume_id='frus1969-76ve09p2' AND document_id='d152'; | “I can find nothing good that comes out of them.” | 1 |
| Q21 | frus1969-76ve09p2/d161 | SELECT body_text FROM document_cache WHERE volume_id='frus1969-76ve09p2' AND document_id='d161'; | “Lockheed had admitted paying some $20 million in bribes overseas” | 1 |
| Q22 | frus1969-76ve09p1/d49 | SELECT body_text FROM document_cache WHERE volume_id='frus1969-76ve09p1' AND document_id='d49'; | “complete details concerning commissions and bribes paid to Libyans and non-Libyans in connection with the deal of C–130’s bought by the Libyan Arab Republic from Lockheed” | 1 |
| Q23 | frus1969-76ve12/d219 | SELECT body_text FROM document_cache WHERE volume_id='frus1969-76ve12' AND document_id='d219'; | “I hope the Government of Japan can support the United States proposal for an international agreement to curtail such practices.” | 1 |
| Q24 | frus1969-76ve12/d222 | SELECT body_text FROM document_cache WHERE volume_id='frus1969-76ve12' AND document_id='d222'; | “As you know, I have kept myself out of the Lockheed matter.” | 1 |
| Q25 | frus1969-76ve12/d224 | SELECT body_text FROM document_cache WHERE volume_id='frus1969-76ve12' AND document_id='d224'; | “The Prime Minister asked me to stress the extremely political nature of the Lockheed question in Japan.” | 1 |
| Q26 | frus1977-80v03/d248 | SELECT body_text FROM document_cache WHERE volume_id='frus1977-80v03' AND document_id='d248'; | “As a nation we have decided that bribery in international trade is reprehensible and that American companies must forego exports that can be attained only by illicit payments.” | 1 |
| Q27 | frus1894app2/d255 | SELECT body_text FROM document_cache WHERE volume_id='frus1894app2' AND document_id='d255'; | “It started from the lottery bill and the opium bill and the bribery and corruption we had heard of.” | 1 |
| Q28 | frus1894app2/d306 | SELECT body_text FROM document_cache WHERE volume_id='frus1894app2' AND document_id='d306'; | “There has been no fraud discovered nor malfeasance unearthed, nor great wrong righted” | 1 |
| Q29 | frus1977-80v13/d94 | SELECT body_text FROM document_cache WHERE volume_id='frus1977-80v13' AND document_id='d94'; | “But at least 100 votes in the House have been lost on the compensatory package simply because of Koreagate.” | 1 |
| Q30 | frus1977-80v13/d95 | SELECT body_text FROM document_cache WHERE volume_id='frus1977-80v13' AND document_id='d95'; | “However, Koreagate has made many Congressmen reluctant to vote for any aid to Seoul this year.” | 1 |
| Q31 | frus1977-80v13/d92 | SELECT body_text FROM document_cache WHERE volume_id='frus1977-80v13' AND document_id='d92'; | “The decisions would be justified on grounds that Congress cannot address Korean policy while the Tongsun Park affair hangs over it.” | 1 |
| Q32 | frus1969-76ve09p2/d161 | SELECT body_text FROM document_cache WHERE volume_id='frus1969-76ve09p2' AND document_id='d161'; | “It would mean the end of the special U.S. -Saudi relationship, and Sultan did not exclude Saudi Arabia’s turning to the Soviets on the rebound.” | 1 |
| Q33 | frus1969-76v06/d175 | SELECT body_text FROM document_cache WHERE volume_id='frus1969-76v06' AND document_id='d175'; | “the number one problem” | 1 |
| Q34 | frus1969-76v06/d175 | SELECT body_text FROM document_cache WHERE volume_id='frus1969-76v06' AND document_id='d175'; | “sharply affecting” | 1 |

Documents cited (all 30, with the stored date and a URL; the first column is the identity used everywhere):

| Document | date_iso | Header (first 80 characters) | URL |
|---|---|---|---|
| frus1943China/d202 | 1943-06-24 | Memorandum by the Second Secretary of Embassy in China (Davies), Temporarily in  | https://history.state.gov/historicaldocuments/frus1943China/d202 |
| frus1944v06/d269 | 1944-02-03 | The Ambassador in China (Gauss) to the Secretary of State | https://history.state.gov/historicaldocuments/frus1944v06/d269 |
| frus1947v07/d591 | 1947-08-23 | Memorandum by Mr. Philip D. Sprouse to General Wedemeyer | https://history.state.gov/historicaldocuments/frus1947v07/d591 |
| frus1948v07/d590 | 1948-12-30 | The Consul General at Shanghai (Cabot) to the Director of the Office of Far East | https://history.state.gov/historicaldocuments/frus1948v07/d590 |
| frus1958-60v01/d111 | 1960-03-02 | 111. Despatch From the Ambassador in Vietnam (Durbrow) to the Department of Stat | https://history.state.gov/historicaldocuments/frus1958-60v01/d111 |
| frus1958-60v01/d160 | 1960-05-13 | 160. Telegram From the Ambassador in Vietnam (Durbrow) to the Department of Stat | https://history.state.gov/historicaldocuments/frus1958-60v01/d160 |
| frus1964-68v04/d280 | 1966-10-23 | 280. Notes of Meeting | https://history.state.gov/historicaldocuments/frus1964-68v04/d280 |
| frus1964-68v05/d197 | 1967-06-13 | 197. Memorandum From the President’s Special Counsel (McPherson) to President Jo | https://history.state.gov/historicaldocuments/frus1964-68v05/d197 |
| frus1964-68v05/d258 | 1967-07-27 | 258. Memorandum From the Minister-Counselor for Political Affairs of the Embassy | https://history.state.gov/historicaldocuments/frus1964-68v05/d258 |
| frus1969-76v06/d175 | 1970-01-31 | 175. Telegram From the Embassy in Vietnam to the Department of State | https://history.state.gov/historicaldocuments/frus1969-76v06/d175 |
| frus1961-63v23/d355 | 1961-07-14 | 355. Memorandum From Robert H. Johnson of the National Security Council Staff to | https://history.state.gov/historicaldocuments/frus1961-63v23/d355 |
| frus1961-63v22/d249 | 1961-12-15 | 249. Letter From the Ambassador to Korea (Berger) to Secretary of State Rusk | https://history.state.gov/historicaldocuments/frus1961-63v22/d249 |
| frus1961-63v17/d27 | 1961-03-27 | 27. Memorandum From the Vice Chairman of the Policy Planning Council (Morgan) to | https://history.state.gov/historicaldocuments/frus1961-63v17/d27 |
| frus1969-76ve09p2/d122 | 1974-12-16 | 122. Airgram From the Embassy in Saudi Arabia to the Department of State | https://history.state.gov/historicaldocuments/frus1969-76ve09p2/d122 |
| frus1977-80v18/d206 | 1980-01-01 | 206. Report Prepared by the Ambassador to Saudi Arabia (West) | https://history.state.gov/historicaldocuments/frus1977-80v18/d206 |
| frus1977-80v23/d252 | 1978-07-25 | 252. Airgram From the Embassy in Haiti to the Department of State | https://history.state.gov/historicaldocuments/frus1977-80v23/d252 |
| frus1969-76ve09p2/d152 | 1975-08-07 | 152. Minutes of the Secretary of State’s Staff Meeting | https://history.state.gov/historicaldocuments/frus1969-76ve09p2/d152 |
| frus1969-76ve15p2/d292 | 1975-09-30 | 292. Memorandum From the Assistant Secretary of State for European and Canadian  | https://history.state.gov/historicaldocuments/frus1969-76ve15p2/d292 |
| frus1969-76ve15p2/d293 | 1975-10-07 | 293. Memorandum From the Deputy Assistant Secretary of State for European and Ca | https://history.state.gov/historicaldocuments/frus1969-76ve15p2/d293 |
| frus1969-76ve09p2/d161 | 1975-09-11 | 161. Telegram From the Embassy in Saudi Arabia to the Department of State | https://history.state.gov/historicaldocuments/frus1969-76ve09p2/d161 |
| frus1969-76ve09p1/d49 | 1976-04-07 | 49. Telegram 83386 From the Department of State to the Embassy in Libya | https://history.state.gov/historicaldocuments/frus1969-76ve09p1/d49 |
| frus1969-76ve12/d219 | 1976-03-11 | 219. Letter From President Ford to Japanese Prime Minister Miki, Washington, Mar | https://history.state.gov/historicaldocuments/frus1969-76ve12/d219 |
| frus1969-76ve12/d222 | 1976-04-22 | 222. Memorandum of Conversation, Washington, April 22, 1976. | https://history.state.gov/historicaldocuments/frus1969-76ve12/d222 |
| frus1969-76ve12/d224 | 1976-05-14 | 224. Memorandum of Conversation, Washington, May 14, 1976. | https://history.state.gov/historicaldocuments/frus1969-76ve12/d224 |
| frus1977-80v03/d248 | 1980-07-29 | 248. Memorandum From Secretary of Commerce Klutznick and the United States Trade | https://history.state.gov/historicaldocuments/frus1977-80v03/d248 |
| frus1894app2/d255 | 1893-05-04 | No. 7. Mr. Blount to Mr. Gresham. | https://history.state.gov/historicaldocuments/frus1894app2/d255 |
| frus1894app2/d306 | 1893-05-08 | No. 23. Statement of Charles T. Gulick. | https://history.state.gov/historicaldocuments/frus1894app2/d306 |
| frus1977-80v13/d92 | 1978-04-04 | 92. Memorandum From the Assistant Secretary of State for East Asian and Pacific  | https://history.state.gov/historicaldocuments/frus1977-80v13/d92 |
| frus1977-80v13/d94 | 1978-04-11 | 94. Memorandum of Conversation | https://history.state.gov/historicaldocuments/frus1977-80v13/d94 |
| frus1977-80v13/d95 | 1978-04-18 | 95. Memorandum From the President’s Assistant for National Security Affairs (Brz | https://history.state.gov/historicaldocuments/frus1977-80v13/d95 |

Reading accounting. Retrieved whole (captured length equal to `length(body_text)`): **37 of 37** (`docs/manifest.json`): the 30 cited and 7 read and not cited (frus1964-68v07/d91, frus1917-72PubDipv07/d177, frus1969-76ve05p2/d119, frus1961-63v22/d244, frus1969-76ve12/d218, frus1893/d652, frus1894/d703). Quoted: **30 documents** have a verified passage above; 16 are quoted in the overview and in the collection's excerpts. Read only as passages around matches (`snips_*.txt`, `sample40.txt`, `core_sample40.txt`): 57 distinct documents, overlapping the above; nothing from these is quoted unless the document was also retrieved whole.

## 4. Findings, with the reading behind each

1. **Vietnam, 1960 to 1970** (d111, d160, d280, d197, d258, d175): the Embassy raised corruption first by reporting (March 1960) and by speaking to Diem (May 1960); in 1966 to 1967 President Johnson and the Embassy's committee cite Congressional investigations; in January 1970 Bunker links it to aid and a Congressional inquiry. Claim limit: no document read records aid cut for corruption.
2. **China, 1943 to 1948** (d202, d269, d591, d590).
3. **Tolerance, excuse, condition** (d27, d355, d249, d122, d252, d206). Document d206 is dated 1980-01-01 in the index (its title says as of 1 January 1980; it was sent with a January 11 letter).
4. **American firms** (d152, d161, d292, d293, d219, d49, d222, d224, d248). Documents d292 and d293 have second-edition twins in frus1969-76ve15p2Ed2 (Hamming distance 0 for d292); only the first edition is used.
5. **Koreagate** (d92, d94, d95).
6. **Hawaii, 1893** (d255, d306). I describe the two statements as opposed claims; I did not establish who the persons were beyond what the documents state.

## 5. Archival scope (two channels, never summed)

**Came-from (document_sources, the 30 cited documents; 28 of 30 have a row).** Read from `q6.out` and q9: Department of State decimal central files, record group 59 (decimal classes 711.93, 893.00, 121.893, 751K.00, 651H.51K, 795B.00; `citation_era` = decimal); National Archives RG 59 Records of Secretary of State Henry Kissinger, Entry 5403, Box 24 (Lot 91D414; `central-files-index.json` lot row: A1 5403, NAID 2131131, "Records of Henry Kissinger", control-number match); RG 59 Transcripts of Secretary of State Kissinger's Staff Meetings, Entry 5177, Box 3 (Lot 78D443; A1 5177, NAID 619160); RG 84 Jidda Embassy Files Lot 79F80 (`collection-authority.json` lot:79F80, record group 84, alias "Agent's Fees"; **no NAID in `central-files-index.json`: unresolved**); RG 59 Central Foreign Policy Files (cfpf, P-numbers) for d222, d224, d252; RG 59 Central Files 1970 to 73, POL 15-1 VIET S (subject-numeric) for d175; d161's source line cites both the Ford Library (National Security Adviser, Presidential Country Files, Box 30) and the RG 84 Jidda Embassy Files; Johnson Library National Security File (d280, d197); Kennedy Library National Security Files (d27, d355); Ford Library National Security Adviser (d219, d49); Carter Library National Security Affairs (d206, d92, d94, d95) and White House Central Files (d248); d258 (Center for Military History, Dep CORDS/MACV files) has `citation_era` unrecognized.
Series facts (`series-facts-index.json`, `arch2.py`): NAID 2131131 inclusive 1973 to 1977, 11 linear feet 5 inches, access "Restricted - Partly", restriction FOIA (b)(1) National Security, creator Department of State Office of the Secretary, College Park; NAID 619160 inclusive 1973 to 1977, 4 linear feet 10 inches, "Unrestricted", same creator.

**Pointed-at (external_citations and `external-citation-index.json`).** The rows for the cited documents themselves (`q10.sql`) are few: decimal classes 751K.11, 651H.51K, 751K.00, 795B.00; Lot 67 D 586 (NAID 602875, "Conference Files", A1 3051B, 1949 to 1972, unrestricted) in d280; Carter Library White House Central Files in d248 (three rows). For the 20 volumes that hold the cited documents (`arch3b.out`; 15 of the 20 are in the pointed-at index), the top targets are Carter Library National Security Affairs (340), Johnson Library National Security File (154), Nixon NSC Files (144), Kennedy Library National Security Files (113), and the State lots 65D330 (20; NAID 602231, A1 1566, 1953 to 1964, unrestricted), 85D240 (20; NAID 2131132, A1 5408, 1961 to 1974, unrestricted), 66D193 (16; NAID 2658382, A1 5155, 1955 to 1962, "Restricted - Possibly"). The editors call 85D240 "Bundy Files" and 66D193 "Vietnam Working Group Files"; NARA's matching series are titled differently (`arch4.out`), and none of these lots is in `lot-claimants-index.json`. These counts are about the volumes, not about corruption; I did not test which boxes hold corruption material. The pointed-at index has no row before 1910 and stores the fragment, not the sentence, and holds lot, library and decimal anchors only.
For the core set of 479 documents (not the cited 30): `arch5.out`, came-from: 363 of 479 have a `document_sources` row; top 142 State decimal (RG 59), 26 CIA, 19 National Archives RG 59 subject-numeric, 16 Johnson NSF, 16 Nixon NSC files; pointed-at: 122 rows over 71 core documents of 479.

The bundled offline stack barely reaches before 1940; I make no archival claim for the 1893 and 1943 to 1948 documents beyond the source lines printed in the volumes and the decimal numbers. The decimal-class glosses were not composed (`decimal-class-labels.json` glosses only 1910 to 1963 and I did not need them).

## 6. VECTORS

Digest check before any scoring (`vec_setup.out`): index `provenanceDigest`, the corpus binary header, the map header, the `.generation` file and all 553 shard headers carry the same 32-byte digest `89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101`; index `generated` 2026-10-15, `harvestGenerated` 2026-10-15T06:55:14; model embeddinggemma-2-Q8_0; `retrieval.measuredRecallAt10` 0.9021, so a neighbour list misses about one in ten true neighbours and absence of a neighbour proves nothing. Identity came only from the index's id segments (decoded and asserted for 553 volumes in `vec.py`; no ordinal rule). Hamming distances are over the 512 sign bits; raw cosines from the Tier-2 shards; where a cosine is shown it is also given through the document-to-document calibration `(cos - 0.40)/0.60`. No neighbour in any list was absent from `document_cache` (the library holds all 553 volumes).

Baselines at this digest (`vec_setup.out`): random pairs (20,000, `random.Random(1877)`): mean 167.1, sd 14.8, 1st percentile 132, minimum 95; k-th-neighbour over a 200-document sample (`random.Random(7)`): median 84 (quartiles 74, 94) for the 1st neighbour, 102 for the 10th, 108 (102, 115) for the 25th.

- **Nearest neighbours of a document** (Hamming over the sign block of `semantic-vectors-binary.bin`; raw cosine from `SemanticVectors/<volume>.vec`). Anchors: frus1958-60v01/d111, frus1969-76ve09p2/d122, frus1943China/d202, frus1969-76ve15p2/d292 (`nbrs1.out`); frus1969-76ve09p2/d161, frus1969-76ve12/d224, frus1977-80v03/d248, frus1964-68v05/d258 (`nbrs2.out`). Baselines: random pairs and the k-th-neighbour medians above. Findings (all suggestions, not evidence of relationship): d202's 4th neighbour is frus1948v07/d590 at distance 67 (raw cosine 0.935, calibrated 89%; closer than the median first neighbour, 84), the document which I then read and cite for "grafters", a form the word family missed; d224's 2nd neighbour is frus1969-76ve12/d222 at 96 (raw 0.905, calibrated 84%; about the median 10th-neighbour distance, 102), which I then read and cite; the neighbours of d111 are Vietnam despatches (frus1955-57v01/d409 at 70 and frus1958-60v01/d176 at 79 contain no family word and were read as passages: not about corruption); d122's 21st neighbour is frus1977-80v18/d206 at 109 (the median 25th-neighbour distance is 108), so that link is unremarkable by distance and rests on reading the two documents. Neighbours of d292 are its own Ed2 twin (0) and d293 (81).
- **Semantic join into the database**: the 25 nearest neighbours of d122 joined to `document_dates` and `document_sources` (`neardup.out`; SQL in `queries.log`), giving dates from 1950-03-19 to 1980-06-03 and sources spread across Carter Library, Nixon Presidential Materials, State central files and the National Archives; I used it to see whether the Saudi neighbours cluster by archive (they do not strongly), not to count.
- **Centroid similarity**: nearest volumes by centroid cosine to frus1958-60v01 (frus1961-63v01 0.985, v02 0.983, v03 0.980, frus1955-57v01 0.979), to frus1969-76ve09p2 (frus1977-80v18 0.982, frus1969-76v24 0.979, frus1964-68v21 0.973) and to frus1943China (frus1942China 0.986, frus1944v06 0.986, frus1945v07 0.979, frus1947v07 0.971) (`mapops.out`). Raw cosines (not calibrated; they compare volumes, not documents or queries). NumPy emitted divide/overflow warnings from the centroid block's float32 products; the lists are plausible and were not used for any claim.
- **The map** (`semantic-map.bin`, `semantic-map-index.json`; digest equal): frus1958-60v01/d111 and frus1964-68v05/d197 sit in cluster 29 (terms lao, vietnamese, vietnam, thieu; 8,631 documents, all in the latest era band); frus1943China/d202 in cluster 3 (nanking, shanghai, chinese, tientsin; 37,899); frus1969-76ve15p2/d292 in cluster 115 (edc, nato, nuclear, soviet); frus1961-63v22/d249 in cluster 22 (rok, korea, rhee, korean); frus1894app2/d255 in cluster 72; frus1969-76ve09p2/d122 is **unclustered**. Corpus-wide 88,059 of 314,616 placements (28.0%) are unclustered; the core set, 142 of the 478 placed documents (29.7%), compared to the corpus figure and **not** to an era-matched baseline, so no conclusion is drawn.
- **Near-duplicates**: pairwise Hamming among the 30 cited documents (`neardup.out`): smallest 56 (frus1947v07/d591 with frus1948v07/d590), then 59, 62, 67, 81, 93; median 154; no pair near zero, and the only zero distance seen is d292 against its own Ed2 twin, consistent with the 718-document overlap the guide states; no cited document is a reprint of another.

**Documents in the overview reached through a vector operation and through no full-text query I ran**: frus1948v07/d590 (the Cabot letter; the family regex gave it zero matches and the FTS inventory did not return it) and frus1969-76ve12/d222 (the Kissinger conversation with Ambassador Togo; it uses "Lockheed" but none of the family words, and my Lockheed full-text queries either required a co-term or only counted, so I reached it as a neighbour of d224; an unqualified search for Lockheed would also have returned it). Every other cited document was reached by full-text query; d206 was also confirmed as a (weak) neighbour of d122.

## 7. Flags

- Thin or partial: the pre-1860 negative rests on 483 documents in 9 volumes; the 1990s on 177; many decades' numerators rest on a few volumes (N9). The pointed-at channel is the whole volumes' footnotes, not corruption-specific.
- The referent of the family is ordinary-language corruption at 35 of 40 in the core set and 27 of 40 in the wider list; the referent sample was judged by me, in one pass.
- Disclosed uncertainty: the overview says that the strategic interest "usually won"; that is my reading of six to twelve documents per thread and not a census.
- Not done: no TEI scan; no check of footnote versus body split (body_text mixes them; d293's quoted words are in an editors' note, said in the overview).
- The semantic neighbours are suggestions with distances against stated baselines; recall@10 is 0.9021.

## 8. TRACE TABLE (overview item to memo line)

| Overview item | Memo line |
|---|---|
| 553 volumes; "two second-edition volumes set aside" | N1; §0 |
| 3,174 of 311,429; "about one document in a hundred" | N3, N2, N5 |
| 479 documents in 203 volumes; "one in 650"; "three or more times" | N4, N5 |
| "30 of those and related documents"; "30 documents"; "all 30" | N15; §3 document table |
| "28 of them carry a source line" | N15; §5 came-from |
| "20 volumes"; "15 of those 20" | N15; §5 pointed-at (`arch3b.out`) |
| Lot 91D414 / A1 5403 / 2131131 / 1973 to 1977 / partly restricted / (b)(1) | §5 series facts (`arch2.out`) |
| Lot 78D443 / A1 5177 / 619160 / 1973 to 1977 / unrestricted | §5 series facts |
| Lot 79F80, Record Group 84, "Agent's Fees", no series identifier | §5 came-from |
| 65 D 330, A1 1566, 602231, 1953 to 1964, unrestricted | §5 pointed-at |
| 85 D 240, A1 5408, 2131132, 1961 to 1974, unrestricted | §5 pointed-at |
| 66 D 193, A1 5155, 2658382, 1955 to 1962, possibly restricted | §5 pointed-at |
| 893.00, 751K.00, 795B.00 file numbers; 1943 to 1960 | §5 came-from; `q6.out` |
| 13 documents in 10 volumes (Church subcommittee) | N13 |
| 483 documents in 9 volumes; 2; 49; 97; none | N11 |
| 177 dated documents after 1989; none | N12 |
| Watergate 183 in 51; Teapot Dome 2; BCCI 1; 11 Iran-Contra | N13 |
| 311,429; 3,174; 479; 30 (Scope sentence) | N2, N3, N4, N15 |
| "about 50" nepotism and cronyism | N14 |
| 419 of 479; all 479 | N7 |
| sample of 40; 35 of 40; 27 of 40 | N6 |
| 6 in 100, 0.9 in 100; 35 in 100, 30 in 100; nonsense word none | N8 |
| 1.2 to 3.5; 0.3 to 1.0; 1.5 to 4.0 per thousand; 1890s mostly one appendix | N9 |
| 18 of the 28 documents (1890s) | N9, N10 |
| eight documents (semantic neighbours); 4th; 21st-nearest neighbour; 25th neighbour | §6 (anchors list; d202 to d590 4th; d122 to d206 21st) |
| "$20 million" bribes (Lockheed); "100 votes" | Q32 and Q29 in §3; document d161, d94 |
| Dates and years of the cited documents (1893, 1943, 1944, 1947, 1948, 1960, 1961, 1966, 1967, 1970, 1974, 1975, 1976, 1978, 1980) | Document table in §3 (`date_iso`), and `meta.json` |
| "the 479 core documents" (Read next); "the rest of the 479" | N4 |
| Quotation "the number one problem" | Q33 |
| Quotation "sharply affecting" | Q34 and Q10 |
| Quotation (Diem, Durbrow) | Q5 |
| Quotation (Ky, "Most of the generals ...") | Q8 |
| Quotation (Bunker, "The inability of the GVN ...") | Q10 |
| Quotation (Davies, "Nepotism and favoritism ...") | Q1 |
| Quotation (Sprouse, "the widespread corruption and graft ...") | Q3 |
| Quotation (Cabot, "The same old inefficient grafters ...") | Q4 |
| Quotation (State view of Philippines) | Q11 |
| Quotation (Jidda 1974, "the unchecked growth ...") | Q14 |
| Quotation (Haiti, "it is the toughest ...") | Q17 |
| Quotation (Sultan, "It would mean the end ...") | Q32 |
| Quotation (Kissinger to Ford, "We must do everything possible ...") | Q19 (editors' note) |
| Quotation (FCPA, "As a nation we have decided ...") | Q26 |
| Quotation (Holbrooke, "But at least 100 votes ...") | Q29 |
| Quotation (Brzezinski, "However, Koreagate ...") | Q30 |
| Quotation (Waterhouse, "It started from the lottery bill ...") | Q27 |
| Quotation (Gulick, "There has been no fraud ...") | Q28 |
| "straight unadulterated corruption" | Q6 |
| Paraphrased facts about documents without quotation marks (Johnson at Manila, Calhoun and Komer, Gauss plot, Iran memo, Berger, West, staff meeting, Ford to Miki, Libya note, Kissinger to Togo, Saito, Koreagate options, Hawaii) | Q7b, Q9, Q2, Q13, Q12, Q16 and Q16b, Q20 and Q20b, Q23, Q22, Q24, Q25, Q31; read whole in `docs/` |

ELIDED: the 37-key argument lists of `dump.py` and the 30-key `meta.py` KEYS string are shortened in `queries.log` to "<N keys>" (the full lists are in `scope_keys.txt` and `docs/manifest.json`); the VALUES lists in `q6.sql`, `q9.sql` and `q10.sql` are pasted in full there; the per-document term counts, the 3,353-row candidate list and the 25-row neighbour lists are in `scan2.csv`, `nbrs1.out`, `nbrs2.out` and `neardup.out`, not reproduced here; the quoted passages in §3 are complete.
