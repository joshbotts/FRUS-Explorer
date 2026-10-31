# Scope memo (operator copy), run s5, 2026-10-30

Question: How has corruption, or allegations of corruption, affected U.S. foreign policy decisions or the conduct of diplomacy?

All files are in the run directory (/Users/jbotts/frus-analysis/c3s/runs/s5). Commands are in `queries.log`; scripts are named beside each number. Item labels (N1, N2 ... A1 ... Q1 ... V1 ...) are the anchors the TRACE TABLE at the end points to.

## 0. Coverage (reported first, as required)

**N1 coverage.** `SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;` returned `553|321749|1103|8481` (first tool call of the run). The read-only proof, `BEGIN; CREATE TABLE zz(x); ROLLBACK;` under `sqlite3 -readonly`, failed with "attempt to write a readonly database" (second call). Every count below is conditional on this index: 553 volumes, 321,749 documents, of which 312,169 are neither front matter nor editorial note (`SELECT COUNT(*) FROM document_cache c WHERE c.is_front_matter=0 AND c.is_editorial_note=0;`). The two second-edition volumes frus1951-54IranEd2 and frus1969-76ve15p2Ed2 hold 740 of those (`... AND volume_id IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')`), leaving **311,429** documents (N2) in 551 volumes when the second editions are suppressed (their first editions are present). The surface counted is this index with apparatus excluded; the 740 is the size of the two second-edition volumes, not a measured overlap with their first editions (I did not re-derive the overlap).

**Thinness flags.** (i) The index holds all 553 series volumes but is dated by `document_dates`; before 1860 it holds 143 dated non-apparatus documents for the 1840s, 158 for the 1850s and under 120 in each earlier decade (`ctrl_results.txt`, COVERAGE block). (ii) The 1990s hold 177 documents, all in frus1989-92v31. (iii) Search results in a decade with a handful of documents are not rates.

## 1. Scope chosen, and how it was found

**Inclusion rule (used meanwhile for the unresolved definitional choices in the overview):** a document is in the argument when it uses corruption, bribery, graft, embezzlement, kickback or illicit/questionable-payment vocabulary AND, in its own words, ties it to an American choice or to American conduct: aid, a loan, supervision, a démarche, jurisdiction, a treaty, a reporting requirement. Corruption or an allegation of it by or against a foreign government, or by Americans, all count. The wide set (vocabulary only) is the 3,058 hit documents (N3); the argument set is the 38 documents in the collection, drawn from 27 volumes (A1 lists them).

**Steps.** (1) Vocabulary scan: a per-term count over the full-text index with controls (q3.py, output below, N6). (2) Decade and volume distribution of the union family (q4b.py, N4), to see where the vocabulary lives. (3) Reading the editors' own headings was not productive here: chapter headings rarely name corruption; candidate documents came instead from proximity searches (s.py) pairing the stem with aid, loan, supervision, Congress, extraterritoriality, and with named clients (see section 3). (4) Candidate documents were dumped whole to `docs/` (dump.py) and read in windows around each hit (kw.py). (5) A forty-document literal-share sample (sample.py, N5). (6) Archival resolution from the document source lines and the bundled JSON (section 5). (7) Vector operations (section 7).

## 2. Measurements

### N3 The hit family

Expression (FTS5 on `frus_documents`, column `body_text`; stems because the index is porter-stemmed): `body_text:(corrupt OR brib* OR graft OR embezzl OR kickback OR "questionable payments" OR "illicit payments")`, joined to `document_cache` on `rowid`, with `c.is_front_matter=0 AND c.is_editorial_note=0`; second editions suppressed with `AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')`. Result: **3,058 documents in 447 volumes** (3,096 in 449 before suppression). The single stem `body_text:corrupt` alone: **2,175 documents in 399 volumes** (2,200 in 401 before). Script: q4b.py (output `q4b_results.txt`, counting surface: this index's body_text, which includes editors' footnotes, so a density blends document and editor language).

Caution on the phrase operators: `"questionable payments"` and `"illicit payments"` are phrase matches over stems. The index's `"questionable payments"` query returns documents such as frus1947v08/d338 ("question payment") that have nothing to do with bribery; the literal TEI count for the true phrase is 1 occurrence in 1 volume (N8). The family is therefore dominated by the first five stems; the phrase terms contribute almost nothing and are not relied on.

### N4 Decade shape (periodised on `document_dates.date_iso`, i.e. the document's own date, not the volume's series year)

```
== core total docs 3058 volumes 447 undated 3
1840s     1 of    143 per1000=  6.99 topvol=frus1902app2 1 (1.00)
1850s     1 of    158 per1000=  6.33 topvol=frus1894app2 1 (1.00)
1860s   111 of  11268 per1000=  9.85 topvol=frus1868p2 18 (0.16)
1870s   103 of   5821 per1000= 17.69 topvol=frus1874 11 (0.11)
1880s    82 of   6484 per1000= 12.65 topvol=frus1888p2 14 (0.17)
1890s   123 of   9845 per1000= 12.49 topvol=frus1894app2 45 (0.37)
1900s   108 of  10261 per1000= 10.53 topvol=frus1906p1 16 (0.15)
1910s   188 of  30842 per1000=  6.10 topvol=frus1917 17 (0.09)
1920s    79 of  20374 per1000=  3.88 topvol=frus1922v01 8 (0.10)
1930s   118 of  40073 per1000=  2.94 topvol=frus1933v02 11 (0.09)
1940s   478 of  75872 per1000=  6.30 topvol=frus1947v07 71 (0.15)
1950s   559 of  42801 per1000= 13.06 topvol=frus1951-54Iran 31 (0.06)
1960s   555 of  27654 per1000= 20.07 topvol=frus1964-68v05 42 (0.08)
1970s   443 of  22258 per1000= 19.90 topvol=frus1969-76ve11p1 35 (0.08)
1980s   106 of   6038 per1000= 17.56 topvol=frus1981-88v05 11 (0.10)
== corrupt_only total docs 2175 volumes 399 undated 2
1840s     1 of    143 per1000=  6.99 topvol=frus1902app2 1 (1.00)
1850s     1 of    158 per1000=  6.33 topvol=frus1894app2 1 (1.00)
1860s    74 of  11268 per1000=  6.57 topvol=frus1865p4 10 (0.14)
1870s    64 of   5821 per1000= 10.99 topvol=frus1875v01 8 (0.12)
1880s    42 of   6484 per1000=  6.48 topvol=frus1883 7 (0.17)
1890s    71 of   9845 per1000=  7.21 topvol=frus1894app2 37 (0.52)
1900s    38 of  10261 per1000=  3.70 topvol=frus1909 8 (0.21)
1910s   128 of  30842 per1000=  4.15 topvol=frus1913 11 (0.09)
1920s    39 of  20374 per1000=  1.91 topvol=frus1922v01 7 (0.18)
1930s    60 of  40073 per1000=  1.50 topvol=frus1930v02 7 (0.12)
1940s   353 of  75872 per1000=  4.65 topvol=frus1947v07 59 (0.17)
1950s   407 of  42801 per1000=  9.51 topvol=frus1952-54v13p2 22 (0.05)
1960s   456 of  27654 per1000= 16.49 topvol=frus1964-68v05 40 (0.09)
1970s   354 of  22258 per1000= 15.90 topvol=frus1969-76ve11p1 32 (0.09)
1980s    85 of   6038 per1000= 14.08 topvol=frus1981-88v01 10 (0.12)
```

Reading: the shape is per 1,000 dated non-apparatus documents of the decade (denominator in each row, Ed2 volumes suppressed), with the top volume's share of the numerator. The 1840s and 1850s rows each rest on a single document and are not rates. The 1890s are 37% one volume (frus1894app2, the Hawaii papers), so the 1890s rate is mostly Hawaii; every later decade's top volume holds 5% to 10%. The shape: roughly 10 to 18 per 1,000 in the 1860s to 1900s, 3 to 6 in 1910 to 1949 (2.94 in the 1930s, one in 340), then 13, 20, 20 and 18 in the 1950s to 1980s.

SQL behind each row (q4b.py): numerator `SELECT ... FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid LEFT JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE frus_documents MATCH <expr> AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN (<Ed2>)`, grouped on `substr(d.date_iso,1,3)||'0s'`; denominator `SELECT substr(d.date_iso,1,3)||'0s', COUNT(*) FROM document_cache c JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN (<Ed2>) AND d.date_iso IS NOT NULL GROUP BY 1`. Three hit documents and two `corrupt` documents are undated and fall out of the table.

### N5 Literal share and referent test on the family (house rule: a phrase count owes its literal share)

Sample: 40 documents evenly spaced (`idx = int(i*len(hits)/40)`) from the (volume_id, document_id)-sorted list of the 3,058 hits (`core_hits.json` minus the Ed2 volumes; sample.py). The text tested is header + dateline + source_note + body_text, whitespace-collapsed. Regexes, case-insensitive for TOLERANT and case-sensitive for STRICT (stated: Python `re`, so STRICT is case-sensitive; SQL's LIKE was not used anywhere in this family):

- STRICT (single spaces, headline forms only): `\b(corruption|corrupt|bribery|bribe|bribes|graft|embezzlement|kickbacks?|questionable payments|illicit payments)\b` -> **35 of 40**. The five misses (frus1944v06/d481, frus1946v08/d320, frus1951v05/d389, frus1964-68v31/d259, frus1969-76v42/d26) are all inflections (bribed, bribing, corrupting, corrupted).
- TOLERANT (any inflection; any run of space, hyphen, comma, parenthesis or full stop between the phrase words): `(corrupt\w*|brib\w*|graft\w*|embezzl\w*|kickback\w*|(?:questionable|illicit)[\s\-,().]+payments?)` -> **40 of 40**.
- A 1.000 tolerant share tests the stemmer, not the referent. REFERENT test (hand coding of each sample window, judgement not SQL; `sample40_coding.json`): the sense of the question (corruption, bribery or graft in government or commerce, or an allegation of it) in **33 of 40**. The seven that are not: frus1882/d8 (corruption of the young, a sermon), frus1894app2/d506 (constitutional bar on bribe-takers), frus1904/d578 (embezzlement extradition), frus1952-54v08/d27 (aid as a 'bribe' to Poland, propaganda), frus1964-68v24/d653 (corruption of a legal system), frus1964-68v31/d259 (upper classes 'corrupting' the Radicals), frus1969-76v42/d26 (a joke, 'Haig has been corrupted by Lord'). The family is usable (tolerant 1.000 and referent 0.825, above the 0.80 floor), with the margin thin.
- DECISION-LINK test (coded the same way): the window ties the vocabulary to an American decision or to American conduct in **8 of 40** (frus1862/d176, frus1952-54v13p1/d60, frus1955-57v06/d328, frus1955-57v22/d14, frus1958-60v05mSupp/dr_d1, frus1958-60v15/d411, frus1964-68v02/d265, frus1977-80v02/d190). This is a judgement by one coder reading a 260-character window, not the whole document; n=40 gives a wide interval.

Sample table (n, pair, strict, tolerant, KWIC window):

```
 1 frus1862/d176                  S=Y T=Y referent=Y decision=Y | m a credible source intimations that some of the escapes from the blockade are known here to have been effected by connivance and bribes to the officers commanding United States vessels. I know not my
 2 frus1867p2/d115                S=Y T=Y referent=Y decision=n | ith a check for $250,000, for his signature of the decree. General Flores is reported to have been so incensed at this attempt to bribe him that he was determined to resign, and would have done so but
 3 frus1874/d109                  S=Y T=Y referent=Y decision=n | l authors of these foolish projects, exhibited in open light and confessed to me myself, and against those who were attempting to corrupt some of the worthy chiefs of an army that had given me undoubt
 4 frus1882/d8                    S=Y T=Y referent=n decision=n | olution and Orangeism. Let us act and pray as we think of the 13th of June and its consequences. It involves the salvation or the corruption of infancy and our youth. It involves the peace or spoliati
 5 frus1893/d475                  S=Y T=Y referent=Y decision=n | very freely on the subject. He states that the whole matter was traceable to the agitation by the Armenian priests, and that they bribed the officials to induce them to close the church and school. He
 6 frus1894app2/d506              S=Y T=Y referent=n decision=n | n of certain classes. No idiot or insane person, and no person who shall be expelled from the Legislature for giving or receiving bribes, or being accessory thereto; and no person who in due course of
 7 frus1904/d578                  S=Y T=Y referent=n decision=n | ther Government of Panama will entertain request for surrender as act of comity of a fugitive from the United States charged with embezzlement. While United States Government can not, until treaty bec
 8 frus1912/d1141                 S=Y T=Y referent=Y decision=n | or European markets in all lines but is harassing and discriminating against American interests, at the instigation of a group of corrupt men who surround the President, and manifested recently in the
 9 frus1917/d55                   S=Y T=Y referent=Y decision=n |  1917, 10 p.m. The state of affairs is not encouraging. General dissatisfaction prevails partly because of unprecedented official corruption, lack of policy and authority; partly because of great infl
10 frus1919Parisv10/d31           S=Y T=Y referent=Y decision=n | struction. (6) Lack of suitable machinery. (7) Lack of fuel. (8) Complete lack of organisation. (9) Incapacity of officials. (10) Bribery and corruption rampant. With the advance of Denikin’s army mor
11 frus1922v02/d576               S=Y T=Y referent=Y decision=n | e; but in the future we shall demand an equitable share in her development. We have now broken forever with the policy of grants, bribery, and submission. We shall invite foreign capital, and it will 
12 frus1932v04/d463               S=Y T=Y referent=Y decision=n | Pei-Piao and other places in Jehol. The items of this plan are as follows:— (1) The Japanese at Chao-Yang-Tze have been trying to bribe a few Chinese soldiers hoping to obtain from them confessions th
13 frus1938v02/d364               S=Y T=Y referent=Y decision=n | ation, peace and good relations between peoples, a country burdened with unemployed, its public affairs agitated and disturbed by corruption and scandals and its foreign policy guided by persons who g
14 frus1943China/d21              S=Y T=Y referent=Y decision=n | ares to be bluntly outspoken in his criticism of conditions in China when speaking to the Generalissimo. Feng’s verbal attacks on corruption and incompetence, he said, have earned him the enmity of ot
15 frus1944v06/d481               S=n T=Y referent=Y decision=n | y should recommend some compromise or form of agreement displeasing to Chiang or Kmt they would at once be accused of having been bribed by the Communists. They are therefore considering laying before
16 frus1946v08/d320               S=n T=Y referent=Y decision=n | ave been avoided. He gave two examples: First, that an Occupational authority spokesman had stated that a Mitsubishi official had bribed or given a large sum of money to Tojo. Gen. Hideki Tojo, Japane
17 frus1947v07/d245               S=Y T=Y referent=Y decision=n |  Youth Corps in their midst. They compare the small sums which are granted for educational work with the vast amounts diverted to corrupt ends. And their emotions are especially excited by the continu
18 frus1948v07/d155               S=Y T=Y referent=Y decision=n | ion at the Assembly and that Li’s paper has been resorting to smear tactics against Sun Fo, making wild assertions and charges of graft, etc. Sun’s two papers are less vitriolic and are using the defe
19 frus1949v08/d501               S=Y T=Y referent=Y decision=n |  face is economic rather than military or political. Cumulative effects of over-population maladjustments, prolonged warring, Kmt corruption and incompetence, continuing inflationary factors and natio
20 frus1950v06/d140               S=Y T=Y referent=Y decision=n | ere. The Taiwanese gave those in group three a hearty welcome upon their return but their enthusiasm later changed because of: a) corruption, b) the bad discipline of the troops and police, and c) the
21 frus1951v05/d389               S=n T=Y referent=Y decision=n | ation and thus endeavor hold up drainage works indefinitely, Syria wld be in as morally weak position as Israel if latter in fact bribing or coercing Shaab Arabs to prevent return to Zone. As stated b
22 frus1952-54v08/d27             S=Y T=Y referent=n decision=n | ance with line taken on Marshall Plan) as effort to dump low grade surplus commodities piled up by “sick” US economy and attempt “bribe” Poland; as proving US knows so little of conditions in Poland a
23 frus1952-54v13p1/d60           S=Y T=Y referent=Y decision=Y | y longterm loans. (3) High [garble], or its equivalent, shld be reinvigorated, given adequate personnel and funds in order reduce corruption. (4) US to help finance and possibly staff with third party
24 frus1955-57v06/d328            S=Y T=Y referent=Y decision=Y | given for these recommendations were the inability of the Dominican Navy to maintain ships and material in a seaworthy condition, graft in purchasing and repair contracts and the assignment of trained
25 frus1955-57v22/d14             S=Y T=Y referent=Y decision=Y |  situation with explanation of why he had taken so strongly a personal stand against requesting a loan. In addition to reasons of corruption reported Embtel 1146 May 19 Document 7. (which he did not m
26 frus1958-60v05mSupp/dr_d1      S=Y T=Y referent=Y decision=Y | asons for these recommendations were the inability of the Dominican Navy to maintain ships and materiel in a seaworthy condition, graft, and failure to utilize trained personnel effectively. Since Aug
27 frus1958-60v15/d411            S=Y T=Y referent=Y decision=Y | y touchy subject. Moreover, in the last election the Church had on the whole exercised a beneficent influence in fighting against corruption. The President, agreeing with Secretary Herter’s point, sai
28 frus1961-63v03/d11             S=Y T=Y referent=Y decision=n | to antagonize the peasantry further. Insensitivity to real or fancied popular grievances or to issues of popular interest such as corruption has done little to enhance the regime’s internal image. 10.
29 frus1961-63v18/d136            S=Y T=Y referent=Y decision=n | nt pressures threatened to liquidate gains achieved through a substantial, but haphazard economic development program. High-level corruption was widespread. A new and positive U.S. course of action ha
30 frus1964-68v02/d265            S=Y T=Y referent=Y decision=Y | aramilitary forces or their families are short of food. They said that an earlier food-distribution plan was abandoned because of corruption and difficulties in administration. It was agreed, however,
31 frus1964-68v06/d112            S=Y T=Y referent=Y decision=n | e fighting a war which cannot be won; that unending hordes of North Vietnamese are surging against South Vietnam; that the GVN is corrupt and inept; that the South Vietnamese people are either solely 
32 frus1964-68v24/d653            S=Y T=Y referent=n decision=n | greater crime to do such things in court than in heat of moment. He said that continuation of SAG’s present actions would lead to corruption of its legal system. He could not understand why SA was wil
33 frus1964-68v31/d259            S=n T=Y referent=n decision=n | o turn back. While under-estimating the resiliency of the upper classes would be foolhardy (they seem to have succeeded nicely in corrupting the Radicals), the ideology and spirit of the PDC seems to 
34 frus1969-76v20/d191            S=Y T=Y referent=Y decision=n | are peculiar to the Philippines. Your arrival comes at a time when the Philippines are facing many urgent problems. Domestically, corruption and inefficiency in government have reached proportions suf
35 frus1969-76v42/d26             S=n T=Y referent=n decision=n | e words. We don’t have to worry about that. The technicians will go over the text. You don’t want spelling changes. Haig has been corrupted by Lord. They are becoming very conservative. Le Duc Tho: Th
36 frus1969-76ve07/d1             S=Y T=Y referent=Y decision=n | o what the policy should be, but many of the opposition tend to be hawkish. 4. There is wide spread feeling that Ayub’s regime is corrupt. Ayub has removed his son—the prime example—from the limelight
37 frus1969-76ve11p1/d190         S=Y T=Y referent=Y decision=n |  MLN congressional bloc. This tactic runs the risk of the President closing down Congress. Laugerud also could apply pressure and bribery to undermine Congressmen. (B) Continue present level of MLN cr
38 frus1977-80v02/d190            S=Y T=Y referent=Y decision=Y |  Up to what level? Is it adequate in rural areas? What is the level of literacy? —Is fulfillment of vital human needs hindered by corruption? If so, what is being done about it? Section 3: Respect for
39 frus1977-80v17p3/d131          S=Y T=Y referent=Y decision=n |  own people, and there have been several assassination attempts against him recently. His much publicized recent campaign against corruption and dissent seems to have further alienated the military. H
40 frus1977-80v24/d283            S=Y T=Y referent=Y decision=n |  the Military and attempt to persecute them for the pecadilloes that they might have committed while in power. Certainly cases of corruption and abuses would continue to be uncovered in the normal cou
```

### N6 Controls (positive and negative, same pass)

From q3.py (apparatus excluded, Ed2 not suppressed in this table; `SELECT COUNT(*), COUNT(DISTINCT c.volume_id) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0`):
```
body_text:"Department of State"   docs= 94049 vols=552   (POSITIVE control, expected nonzero everywhere)
body_text:"ZZZ_IMPOSSIBLE_ZZZ"   docs=     0 vols=0     (NEGATIVE control)
body_text:corrupt               docs=  2200 vols=401
body_text:bribe                 docs=   423 vols=224
body_text:bribery               docs=   303 vols=164
body_text:graft                 docs=   367 vols=163
body_text:embezzl               docs=   169 vols=84
body_text:kickback              docs=    18 vols=17
```
The positive control fails in one volume, frus1919Parisv05 (`SELECT volume_id FROM document_cache GROUP BY volume_id EXCEPT SELECT DISTINCT c.volume_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH 'body_text:"Department of State"'`), a Paris Peace Conference volume whose text does not use the phrase; this does not affect the corruption scan (the volume has the family zero times by the TEI scan, N8). The negative control also returned 0 in the TEI scan (551 volumes) and 0 in the false-friend pass (`body_text:zzzimpossiblezzz`). Note the string ZZZ_IMPOSSIBLE_ZZZ tokenises to three tokens in the index; it is a phrase there.

### N7 False-friend test (a term the question supplied)

```
FALSE-FRIEND TEST. on-topic scope S = 27 volumes (18436 non-apparatus docs, Ed2 suppressed); rest = 292993 docs
corrupt (term supplied by the question)       S: 423 of 18436 (22.9/1000)   rest: 1752 of 292993 (6.0/1000)
core family                                   S: 512 of 18436 (27.8/1000)   rest: 2546 of 292993 (8.7/1000)
CONTROL phrase 'Department of State'          S: 5567 of 18436 (302.0/1000)   rest: 88257 of 292993 (301.2/1000)
CONTROL term 'Ambassador'                     S: 7527 of 18436 (408.3/1000)   rest: 103341 of 292993 (352.7/1000)
NEGATIVE control zzzimpossiblezzz             S: 0 of 18436 (0.0/1000)   rest: 0 of 292993 (0.0/1000)

SQL for each row: SELECT COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH <expr> AND is_front_matter=0 AND is_editorial_note=0 AND volume_id NOT IN (Ed2 volumes) AND volume_id [NOT] IN (scope S)
```

Reading: 'corrupt' is 22.9 per 1,000 documents in the 27 volumes the argument rests on (scope S, A1) against 6.0 per 1,000 in the other 524. The control phrase 'Department of State' holds the baseline (302.0 against 301.2 per 1,000) and 'Ambassador' drifts mildly (408.3 against 352.7). So the term is not measuring the corpus; it is concentrated in the on-topic volumes. Caveat that matters: S was chosen from documents that contain the term, so some of the 3.8-fold concentration is by construction. The fair reading is only that the term is far from a baseline word. 'Ambassador' moving 16% shows that on-topic volumes also run more diplomatic (cables) than the rest.

### N8 Spelling variants (TEI, tag-stripped counting surface), and the index's blind spots

[TEI] surface: `tei_scan.py` read the 551 first-edition volume files, stripped tags, collapsed whitespace, and counted case-insensitive word-bounded regexes (front matter and footnotes NOT separated from document text; occurrences, not documents). Results (`tei_scan_summary.txt`):
```
files scanned: 551 (Ed2 duplicates suppressed). COUNTING SURFACE: tag-stripped, whitespace-collapsed raw TEI (front matter and apparatus NOT separated), case-insensitive, word-bounded regex per variant
Department of State (POSITIVE control)                  occurrences= 178193 in 551 of 551 volumes
ZZZ_IMPOSSIBLE_ZZZ (NEGATIVE control)                   occurrences=      0 in 0 of 551 volumes
corruption                                              occurrences=   2384 in 329 of 551 volumes
corrupt                                                 occurrences=    964 in 293 of 551 volumes
corrupted                                               occurrences=     95 in 76 of 551 volumes
corrupting                                              occurrences=     51 in 42 of 551 volumes
corruptly                                               occurrences=     13 in 12 of 551 volumes
bribery                                                 occurrences=    429 in 165 of 551 volumes
bribe/bribes                                            occurrences=    401 in 191 of 551 volumes
bribed/bribing                                          occurrences=    139 in 88 of 551 volumes
graft                                                   occurrences=    389 in 139 of 551 volumes
peculation                                              occurrences=     24 in 19 of 551 volumes
defalcation(s)                                          occurrences=     23 in 13 of 551 volumes
malversation                                            occurrences=     32 in 27 of 551 volumes
embezzlement/embezzle*                                  occurrences=    381 in 88 of 551 volumes
kickback(s)                                             occurrences=     27 in 22 of 551 volumes
payoff(s)                                               occurrences=    240 in 105 of 551 volumes
venal/venality                                          occurrences=    179 in 103 of 551 volumes
squeeze (Chinese/Levantine sense not separated)         occurrences=    649 in 246 of 551 volumes
illicit payment(s)                                      occurrences=     32 in 4 of 551 volumes
questionable payment(s)                                 occurrences=      1 in 1 of 551 volumes
Foreign Corrupt Practices Act                           occurrences=      9 in 2 of 551 volumes
FCPA                                                    occurrences=     11 in 1 of 551 volumes
anti-corruption / anticorruption                        occurrences=     70 in 29 of 551 volumes
corrupt practices                                       occurrences=     93 in 55 of 551 volumes
```

What this shows: (a) the spelled-out family splits as corruption 2,384, corrupt 964, corrupted 95, corrupting 51, corruptly 13; bribery 429, bribe/bribes 401, bribed/bribing 139; graft 389; embezzle* 381. (b) Acronyms do not dominate here: FCPA 11 occurrences in one volume against 9 for the spelled-out act in two volumes. (c) The index cannot see some variants: `peculat` returns 0 in the index (stemmed `pecul*` also matches 'peculiar', 3,140 documents) while the TEI holds 'peculation' 24 times in 19 volumes; `defalc*` finds 16 and `malvers*` 36 documents, and the TEI holds 'defalcation' 23 and 'malversation' 32 times. The earlier per-era table in `ctrl_results.txt` (peculat/defalcat*/malversat* = 0) is a stem artefact and is retracted here; 'squeeze' (649 occurrences) is mostly the Chinese-trade and Levantine 'squeeze' and was not separated, so it is outside the family.

### N9 What the index cannot reach (absences, with the controls that make them findings)

- After 1989: the 1990s hold 177 non-apparatus dated documents, all in one volume (frus1989-92v31); the family has zero hits there (no 1990s row in N4), and the positive control 'Department of State' finds 130 documents dated 1990 or later (`SELECT COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE frus_documents MATCH 'body_text:"Department of State"' AND d.date_iso>='1990' AND c.is_front_matter=0 AND c.is_editorial_note=0` -> 130). The absence is the index's limit.
- Before 1860: see N1's thinness flag; not a finding about the century.
- Period and counterpart vocabulary (N10 in `ctrl_results.txt`, the eras table): extortion (5.6 per 1,000 before 1900 against 1.0 and 1.4 later), malfeasance (0.6, 0.1, 0.3), 'jobbery' (0.3 before 1900) show that the nineteenth century used other words; so the family under-counts the earlier decades relative to later ones. The counterpart vocabulary of merchants or chambers was not scanned; I flag that as undone.

## 3. Candidate-finding searches (all with `s.py`, FTS5 MATCH on body_text, bm25 ascending, apparatus excluded)

```
body_text:corrupt AND body_text:aid                                   (914 docs)
body_text:NEAR(corrupt aid, 10), date 1944-01-01..1950-12-31           (5)
body_text:corrupt AND body_text:(China OR Chinese OR Kuomintang), 1947-06-01..1949-12-31   (120)
body_text:corrupt AND body_text:(Chiang OR Generalissimo), 1943..1946  (70)
body_text:corrupt AND (Chiang OR Generalissimo OR Nationalist*) AND (aid OR assistance) AND (withdraw* OR terminate* OR cease OR "further aid" OR "white paper"), 1949..1950   (21)
body_text:NEAR(corrupt Diem, 40) OR NEAR(corrupt Vietnam, 30), 1954..1963  (57)
body_text:corrupt AND (Marcos OR Philippine*), 1983..1990                  (8)
body_text:("questionable payments" OR "illicit payments" OR "foreign corrupt practices" OR "corrupt practices act")   (30)
body_text:(brib* OR corrupt) AND (Minister OR Legation OR Department), 1860..1899   (343)
body_text:corrupt AND (loan OR receivership OR customs OR financial) AND (control OR supervision OR reform), 1900..1925   (92)
body_text:corrupt AND (extraterritorial* OR "consular court*" OR capitulations), 1860..1935   (30)
body_text:NEAR(corrupt Congress, 25) AND (aid OR assistance), 1950..1980  (9)
body_text:(corrupt AND (suspend* OR terminat* OR cutoff OR "cut off" OR halt*) AND (aid OR assistance OR loan*)), 1953..1980   (145)
```

Hits were ranked by bm25 (negative; ascending) and only the top 8 to 16 of each were looked at; the other ~1,500 hits of these queries were not read. This is why the argument set is a reading sample and not a census. Phrase counts above are search-set sizes, not published phrase counts; none is relied on as a count of a phrase.

## 4. What I did not do

The counterpart-vocabulary scan for pre-1900 corruption (merchants, chambers, the foreign ministry's own words) was not run beyond the TEI variant table. No density was published for 'document text' as distinct from footnotes (the index cannot separate them): every density in this memo blends the two.

## 5. Archival scope (channels never summed)

### A1 Came-from channel, the 38 collection documents (`document_sources`, one row per document)

```
SQL: SELECT COALESCE(s.repository,'(no source row)') repo, COALESCE(s.record_group,'-') rg, COALESCE(s.citation_era,'-') era, COUNT(*) n, group_concat(c.volume_id||'/'||c.document_id,' ') docs FROM coll c LEFT JOIN document_sources s ON s.volume_id=c.volume_id AND s.document_id=c.document_id GROUP BY 1,2,3 ORDER BY n DESC
('Department of State', '59', 'decimal', 20, 'frus1944v06/d269 frus1947v05/d23 frus1947v07/d553 frus1948v07/d440 frus1949v08/d576 frus1912/d1502 frus1922v01/d836 frus1922v01/d841 frus1922v01/d842 frus1922v01/d862 frus1922v01/d864 frus1950v06/d802 frus1952-54v12p2/d324 frus1955-57v22/d7 frus1958-60v01/d135 frus1958-60v01/d160 frus1949v06/d330 frus1950v05/d289 frus1961-63v22/d252 frus1921v01/d275')
('Carter Library', '-', 'structured', 5, 'frus1977-80v03/d35 frus1977-80v24/d337 frus1977-80v03/d65 frus1977-80v03/d230 frus1977-80v03/d248')
('Department of State', '59', 'lot_file', 3, 'frus1981-88v01/d247 frus1981-88v01/d264 frus1950v03/d728')
('Library of Congress', '-', 'structured', 2, 'frus1969-76v08/d191 frus1969-76ve09p2/d155')
('National Archives', '59', 'subject_numeric', 2, 'frus1964-68v32/d8 frus1964-68v05/d301')
('(no source row)', '-', '-', 1, 'frus1893/d628')
('(no source row)', '-', 'named_series', 1, 'frus1961-63v01/d298')
('(no source row)', '-', 'unrecognized', 1, 'frus1964-68v05/d258')
('Department of State', '59', 'subject_numeric', 1, 'frus1961-63v20/d422')
('Eisenhower Library', '-', 'structured', 1, 'frus1958-60v01/d156')
('Reagan Library', '-', 'structured', 1, 'frus1981-88v41/d251')
SQL: SELECT s.repository, s.record_group, COUNT(*) FROM coll c JOIN document_sources s ON s.volume_id=c.volume_id AND s.document_id=c.document_id WHERE s.repository IN ('Department of State','National Archives') AND s.record_group='59' AND s.citation_era IN ('decimal','subject_numeric') GROUP BY 1,2
('Department of State', '59', 21)
('National Archives', '59', 2)
```

Overview counts: 37 of 38 carry a source line (`frus1893/d628` has no `document_sources` row); the 1961-63v01/d298 and 1964-68v05/d258 rows exist in the source lines but their repository is not stored (named_series 'Department of State, Johnson Files'; unrecognized 'Center for Military History, Dep CORDS / MACV Files, GVN Corruption 1967'). RG 59 Central Files = decimal 20 + subject_numeric 3 = **23 of 37**; lot files 3 (59 D 95 once; 89D149 twice); presidential libraries 7 (Carter 5, Eisenhower 1, Reagan 1); Library of Congress 2; Center for Military History 1; State Johnson Files 1. 23+3+7+2+1+1 = 37.

### A2 Pointed-at channel, the 3,058 hit documents (`external_citations`, many rows per document)

```
core-vocabulary hit documents (apparatus excluded, Ed2 suppressed): 3058

-- CAME-FROM (document_sources, one row per document) over the hit documents
SQL: SELECT COALESCE(s.repository,'(none)') repo, COALESCE(s.record_group,'-') rg, s.citation_era, COUNT(*) FROM hit h LEFT JOIN document_sources s ON s.volume_id=h.volume_id AND s.document_id=h.document_id GROUP BY 1,2,3 ORDER BY 4 DESC LIMIT 14
('Department of State', '59', 'decimal', 1251)
('(none)', '-', None, 508)
('Department of State', '59', 'lot_file', 184)
('Department of State', '59', 'cfpf', 120)
('National Archives', '59', 'subject_numeric', 118)
('Central Intelligence Agency', '-', 'structured', 117)
('Johnson Library', '-', 'structured', 104)
('Nixon Presidential Materials', '-', 'structured', 103)
('Carter Library', '-', 'structured', 78)
('Department of State', '59', 'subject_numeric', 62)
('(none)', '-', 'named_series', 59)
('Eisenhower Library', '-', 'structured', 40)
('Kennedy Library', '-', 'structured', 35)
('(none)', '-', 'published', 34)
hit docs with no document_sources row: 508

-- POINTED-AT (external_citations, many rows per document) over the hit documents, by anchor type
SQL: SELECT e.anchor, COUNT(*) citations, COUNT(DISTINCT e.volume_id||'/'||e.document_id) docs FROM hit h JOIN external_citations e ON e.volume_id=h.volume_id AND e.document_id=h.document_id GROUP BY 1 ORDER BY 2 DESC
('centralFileClass', 450, 259)
('presidentialLibrary', 176, 124)
('lotFile', 138, 93)
SQL: SELECT e.repository, COALESCE(NULLIF(e.collection,''),NULLIF(e.lot_file_norm,''),'(decimal/class)') tgt, COUNT(*) FROM hit h JOIN external_citations e ON e.volume_id=h.volume_id AND e.document_id=h.document_id WHERE e.anchor IN ('lotFile','presidentialLibrary') GROUP BY 1,2 ORDER BY 3 DESC LIMIT 14
('Carter Library', 'National Security Affairs', 53)
('Johnson Library', 'National Security File', 28)
('Nixon Presidential Materials', 'NSC Files', 27)
('Department of State', '66D95', 17)
('Department of State', '63D351', 12)
('Eisenhower Library', 'Whitman File', 7)
('Carter Library', 'Presidential Materials', 6)
('Department of State', '62D1', 6)
('Department of State', '62D430', 6)
('Department of State', '89D149', 6)
('Johnson Library', 'President’s Daily Diary', 6)
('Department of State', '67D548', 5)
('Department of State', '59D518', 4)
('Kennedy Library', 'National Security Files', 4)
earliest external_citations document date among all rows: ('1910-12-06',)
```

Caveats stated before ranking: `external_citations` has no row before 1910-12-06 (earliest document date among all rows), stores the citation fragment and not the sentence, and holds only lot, library and decimal anchors. 'Came-from' over the same 3,058 documents (first block) is a different count of different things (508 of them have no source row at all). They are not added.

### A3 Bundled-JSON resolution (script archival.py; arch3_results.txt)

Whole-volume rankings over scope S (27 volumes of the collection; `archival_results.txt`), labelled: they are topic-undifferentiated counts for the whole volumes, not for the corruption documents. Came-from (collection-usage-index.json, generated 2026-10-20) ranks Central Files (1,133), Carter National Security Affairs (280), Johnson National Security File (278); pointed-at (external-citation-index.json, schemaVersion 2) ranks Carter National Security Affairs (293), Johnson NSF (162), Kennedy NSF (84).

```
SCOPE S: 27 volumes: frus1893, frus1912, frus1921v01, frus1922v01, frus1944v06, frus1947v05, frus1947v07, frus1948v07, frus1949v06, frus1949v08, frus1950v03, frus1950v05, frus1950v06, frus1952-54v12p2, frus1955-57v22, frus1958-60v01, frus1961-63v01, frus1961-63v20, frus1961-63v22, frus1964-68v05, frus1964-68v32, frus1969-76v08, frus1969-76ve09p2, frus1977-80v03, frus1977-80v24, frus1981-88v01, frus1981-88v41

== CAME-FROM channel (collection-usage-index.json, source notes), ranked over scope S
scope volumes found in index: 27
 1133  txt:department of state|central file | Central Files | RG 59 | Department of State
  280  txt:carter library|national security affair | National Security Affairs | RG None | Carter Library
  278  txt:johnson library|national security file | National Security File | RG None | Johnson Library
  187  txt:department of state|central files 1967-69 | Central Files 1967–69 | RG 59 | Department of State
  166  txt:kennedy library|national security file | National Security Files | RG None | Kennedy Library
  135  txt:nixon|nsc file | NSC Files | RG None | Nixon
   97  txt:department of state|central files 1964-66 | Central Files 1964–66 | RG 59 | Department of State
   85  txt:library of congress|manuscript division | Manuscript Division | RG None | Library of Congress
   59  lot:M88 | CFM Files, Lot M–88 | RG 59 | Department of State
   54  txt:reagan library|executive secretariat | Executive Secretariat, National Security Council | RG None | Reagan Library
   51  lot:89D149 | Lot 89D149: S/P , Memoranda/Correspondence from the Director of the Policy Planning Staff | RG 59 | Department of State
   42  lot:55D36 | Lot 55–D36 | RG 59 | Department of State
   38  lot:66D193 | Vietnam Working Group Files: Lot 66 D 193 | RG 59 | Department of State | NAID 2658382 entry ['A1 5155'] | series 'Subject Files Relating to Political, Military, Economic Aid, and Admin' | 1955-1962 | access Restricted - Possibly
   37  txt:carter library|national security council | National Security Council | RG None | Carter Library
total notes mapped to a collection in scope: 4116

== POINTED-AT channel (external-citation-index.json targets), ranked over scope S
scope volumes found in index: 25
  293  txt:carter library|national security affair | National Security Affairs | RG None | Carter Library
  162  txt:johnson library|national security file | National Security File | RG None | Johnson Library
   84  txt:kennedy library|national security file | National Security Files | RG None | Kennedy Library
   55  txt:nixon|nsc file | NSC Files | RG None | Nixon
   40  txt:carter library|presidential material | Presidential Materials | RG None | Carter Library
   35  lot:59D95 | Conference Files, Lot 59 D 95 | RG 59 | Department of State
   33  txt:reagan library|presidential daily diary | President’s Daily Diary | RG None | Reagan Library
   32  lot:81D113 | D Files: Lot 81D113 (Entry P–14) | RG 59 | Department of State | NAID 1487627 entry ['P 14'] | series 'Records of Deputy Secretary Warren Christopher' | 1975-1981 | access Restricted - Partly
   27  lot:63D351 | S/S – NSC Files: Lot 63 D 351 | RG 59 | Department of State | NAID 2839192 entry ['A1 1586E'] | series 'Records Relating to National Security Council Policy Papers' | 1947-1979 | access Restricted - Partly
   23  lot:66D95 | S/S – NSC (Miscellaneous) Files: Lot 66 D 95 | RG 59 | Department of State | NAID 2839192 entry ['A1 1586E'] | series 'Records Relating to National Security Council Policy Papers' | 1947-1979 | access Restricted - Partly
   21  txt:carter library|staff office file | Staff Office Files | RG None | Carter Library
   21  txt:johnson library|presidential daily diary | President’s Daily Diary | RG None | Johnson Library
   20  lot:65D330 | Secretary’s Memoranda of Conversation: Lot 65 D 330 | RG 59 | Department of State | NAID 602231 entry ['A1 1566'] | series 'The Secretary's and the Under Secretary's Memorandums of Conversation' | 1953-1964 | access Unrestricted
   20  lot:66D193 | Vietnam Working Group Files: Lot 66 D 193 | RG 59 | Department of State | NAID 2658382 entry ['A1 5155'] | series 'Subject Files Relating to Political, Military, Economic Aid, and Admin' | 1955-1962 | access Restricted - Possibly
total citations in scope: 1498

602875 creator: Department of State. Office of the Secretary. Executive Secretariat. | extent: 238 linear feet | inclusive 1949 1972 | access: Unrestricted | use: Unrestricted | restrictions: [] | ref unit: National Archives at College Park - Textual Reference
2658382 creator: Department of State. Bureau of Far Eastern Affairs. | extent: 5 linear feet, 7 linear inches | inclusive 1955 1962 | access: Restricted - Possibly | use: Restricted - Possibly | restrictions: [] | ref unit: National Archives at College Park - Textual Reference
2839192 creator: Department of State. Office of the Secretary. Executive Secretariat. | extent: 26 linear feet, 3 linear inches | inclusive 1947 1979 | access: Restricted - Partly | use: Restricted - Possibly | restrictions: ['FOIA (b)(1) National Security'] | ref unit: National Archives at College Park - Textual Reference
602231 creator: Department of State. Executive Secretariat. | extent: 13 linear feet, 2 linear inches | inclusive 1953 1964 | access: Unrestricted | use: Unrestricted | restrictions: [] | ref unit: National Archives at College Park - Textual Reference
1487627 creator: Department of State. Office of the Deputy Secretary of State. | extent: 14 linear feet | inclusive 1975 1981 | access: Restricted - Partly | use: Restricted - Possibly | restrictions: ['FOIA (b)(1) National Security'] | ref unit: National Archives at College Park - Textual Reference
66D193 2658382 59 ['A1 5155'] Subject Files Relating to Political, Military, Economic Aid, and Administrative Affairs control
63D351 2839192 59 ['A1 1586E'] Records Relating to National Security Council Policy Papers control
66D95 2839192 59 ['A1 1586E'] Records Relating to National Security Council Policy Papers control
65D330 602231 59 ['A1 1566'] The Secretary's and the Under Secretary's Memorandums of Conversation control
81D113 1487627 59 ['P 14'] Records of Deputy Secretary Warren Christopher control
```

Resolution notes. (1) Lot 59 D 95 appears in `curated-lot-resolutions.json` as kind `possible`, seriesRef conferenceFiles, NAID 602875 'Conference Files', RG-59, entry A1 3051B, 1949-1972, 'matched by collection name, not by control number'; `series-facts-index.json` gives creator Department of State. Office of the Secretary. Executive Secretariat, 238 linear feet, inclusive 1949-1972, access Unrestricted. NARA's creator attribution measured 56% precision on one route; the creator was checked only against the lot's description in `collection-authority.json` (Executive Secretariat) and is consistent. The match is probable, not confirmed. (2) Lot 89D149 is in `collection-authority.json` (S/P memoranda and correspondence from the Director of the Policy Planning Staff, RG 59, 12 volumes) but in none of `central-files-index.json`'s `lotFiles`, `curated-lot-resolutions.json` or `lot-claimants-index.json`: no NAID. (3) Lots 66D95 and 63D351 both resolve in `central-files-index.json` (matchType control) to NAID 2839192, 'Records Relating to National Security Council Policy Papers', RG 59, entry A1 1586E; `series-facts-index.json`: Executive Secretariat, 26 linear feet 3 inches, 1947-1979, access Restricted - Partly, FOIA (b)(1). (4) Presidential-library mapping, `presidential-library-catalog.json` (generated 2026-08-06, by title search): Johnson 'National Security Files' NAID 567979 (LBJ-NSF); Nixon 'National Security Files (Nixon Administration)' NAID 572235 (RN-NSF); Kennedy 'National Security Files' NAID 1164 (JFK-4); Eisenhower 'Ann C. Whitman Papers' NAID 643447 is the nearest title to the 'Whitman File' (unverified); no Carter 'National Security Affairs' (Brzezinski Material) or Reagan 'Rosenberg Files' record by title (Carter 'Brzezinski Collection' NAID 1104 is a different collection). Access for library holdings is not in the bundle. (5) The Central Files (decimal, RG 59) are not resolved to a NAID by `central-files-index.json` (its `numericalFile` is the Numerical File M862, an earlier series). `decimal-class-labels.json` was not used: its glosses are year-gated and I did not need a gloss. (6) Offline reach before 1940 is 11 of 695 bundled series.

### A4 Intelligence as a source

In the came-from block over the hit documents (A2 output), `Central Intelligence Agency | - | structured` = **117** documents. The CIA's files are outside the offline data.

## 6. Quotations: every quotation in the overview, with the SELECT that retrieved it

Reading accounting: 66 documents were retrieved whole to `docs/` (captured length = `length(body_text)` for 66 of 66; `docs/_retrieved.jsonl`), including all 38 of the collection. Windows of 300 to 900 characters around each corruption word were read for the candidates (kw.py); only frus1922v01/d836 and the extract d842 were read end to end. 22 passages from 20 documents are quoted in the overview and as collection excerpts. Every one is verified as a whitespace-collapsed substring of the document's `body_text` (verify_ov.py -> `ov_quotes_verified.json`).

| Q# | pair | quotation | SELECT |
|---|---|---|---|
| Q1 | frus1947v05/d23 | unprecedented corruption and ineffectiveness in the working of the Government | `SELECT body_text FROM document_cache WHERE volume_id='frus1947v05' AND document_id='d23' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q2 | frus1949v08/d576 | come to aid of existing government, corrupt as it is | `SELECT body_text FROM document_cache WHERE volume_id='frus1949v08' AND document_id='d576' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q3 | frus1981-88v01/d247 | The war against the Communist NPA is going badly, partly because the military are corrupt, politicized, and incompetent. | `SELECT body_text FROM document_cache WHERE volume_id='frus1981-88v01' AND document_id='d247' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q4 | frus1944v06/d269 | no part of the criticism of corruption and inefficiency attaches to the Generalissimo except in relation to his failure to rid the Government of corrupt and inefficient elements | `SELECT body_text FROM document_cache WHERE volume_id='frus1944v06' AND document_id='d269' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q5 | frus1922v01/d864 | General Crowder feels that the Department should not consent to a loan unless this amnesty bill is definitely killed. | `SELECT body_text FROM document_cache WHERE volume_id='frus1922v01' AND document_id='d864' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q6 | frus1950v06/d802 | Philippine performance must precede consideration of any additional American aid | `SELECT body_text FROM document_cache WHERE volume_id='frus1950v06' AND document_id='d802' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q7 | frus1922v01/d841 | I am utterly unable to obtain evidence which would satisfy beyond a reasonable doubt or to establish even a prima facie case | `SELECT body_text FROM document_cache WHERE volume_id='frus1922v01' AND document_id='d841' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q8 | frus1958-60v01/d135 | these reports had reached certain circles on Capitol Hill and certain business circles | `SELECT body_text FROM document_cache WHERE volume_id='frus1958-60v01' AND document_id='d135' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q9 | frus1964-68v05/d258 | it has become a key obstacle to pacification | `SELECT body_text FROM document_cache WHERE volume_id='frus1964-68v05' AND document_id='d258' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q10 | frus1964-68v05/d258 | an invasion of the sovereignty of the Republic of Viet-Nam | `SELECT body_text FROM document_cache WHERE volume_id='frus1964-68v05' AND document_id='d258' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q11 | frus1981-88v41/d251 | The government conduit weakens conditionality; when reform fails to occur, aid continues to flow for political reasons. | `SELECT body_text FROM document_cache WHERE volume_id='frus1981-88v41' AND document_id='d251' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q12 | frus1949v06/d330 | I pointed to Nationalist China as an example of the wrong policy. | `SELECT body_text FROM document_cache WHERE volume_id='frus1949v06' AND document_id='d330' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q13 | frus1949v06/d330 | the Shah observed that China’s downfall was largely due to corruption | `SELECT body_text FROM document_cache WHERE volume_id='frus1949v06' AND document_id='d330' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q14 | frus1950v05/d289 | What is the corruption in Persia in comparison with corruption elsewhere | `SELECT body_text FROM document_cache WHERE volume_id='frus1950v05' AND document_id='d289' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q15 | frus1961-63v22/d252 | Therefore, recommend we do not change for the present our aid policies on account of this latest political action. | `SELECT body_text FROM document_cache WHERE volume_id='frus1961-63v22' AND document_id='d252' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q16 | frus1969-76ve09p2/d155 | Problems arising from publicity over the enormous commissions being paid by American firms to promote sales of defense articles and services to the Saudi Government threaten to strain US-Saudi relations. | `SELECT body_text FROM document_cache WHERE volume_id='frus1969-76ve09p2' AND document_id='d155' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q17 | frus1977-80v24/d337 | President Carter placed high priority on the negotiation of an international treaty on illicit payments, | `SELECT body_text FROM document_cache WHERE volume_id='frus1977-80v24' AND document_id='d337' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q18 | frus1977-80v03/d248 | some exports are lost because foreign companies can bribe foreign officials while U.S. companies cannot | `SELECT body_text FROM document_cache WHERE volume_id='frus1977-80v03' AND document_id='d248' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q19 | frus1893/d628 | the officials at Amadia were corrupt men | `SELECT body_text FROM document_cache WHERE volume_id='frus1893' AND document_id='d628' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q20 | frus1921v01/d275 | delay, improper influence, squeeze and corruption all but universal today | `SELECT body_text FROM document_cache WHERE volume_id='frus1921v01' AND document_id='d275' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q21 | frus1981-88v01/d264 | as in Manila | `SELECT body_text FROM document_cache WHERE volume_id='frus1981-88v01' AND document_id='d264' AND is_front_matter=0 AND is_editorial_note=0;` |
| Q22 | frus1912/d1502 | arbitrary and corrupt government | `SELECT body_text FROM document_cache WHERE volume_id='frus1912' AND document_id='d1502' AND is_front_matter=0 AND is_editorial_note=0;` |

All 22 rows: verified = True.

## 7. VECTORS

Files touched: `semantic-vectors-index.json`, `semantic-vectors-binary.bin`, `semantic-map.bin`, `semantic-map-index.json` (bundle, build 1.0 (1776)), and the Tier-2 shards under /Users/jbotts/frus-analysis/c3/SemanticVectors/ for every volume holding a candidate in the Hamming-800 pools (about 150 shards). Scripts: vecsetup.py, v0.py (digests), v1.py (baselines), v2.py (neighbours and funnel), v3.py (centroids, map, near-duplicates). Outputs: vec_v0.txt, vec_v1.txt, vec_v2.txt, vec_v3.txt.

**V0 Digest comparison (all artifacts touched).** index `89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101`; binary header, map header and the shard folder's `.generation` file carry the same 32 bytes; every shard read in v2.py was asserted equal to the index digest at read time. No mismatch; one generation throughout. Index `generated` 2026-10-15, `harvestGenerated` 2026-10-15T06:55:14, measuredRecallAt10 0.9021 (funnel Hamming-800 over 512 sign bits -> int8-512). Id round trip: 553 of 553 volumes decode to their stated n; rows covered 314,616 of 314,616. Identity throughout comes from the index segments (vecsetup.py `decode_segments`), never from an ordinal.

**V1 Baselines at this digest.** Random pairs (Random(1877), 20,000): mean 167.1, sd 14.8, 1st percentile 132, minimum 95 of 512. k-th-neighbour distribution over a 200-document sample (Random(1877)): 1st neighbour median 82 (quartiles 71, 92); 10th median 102 (95, 108); 25th median 108 (101.25, 114). A neighbour is read against the k-th-neighbour distribution; a set's cohesion against random pairs. (vec_v1.txt)

**V2 Nearest neighbours of a document (operation 1), with the funnel rerank (operation 6 of the appendix).** Anchors: frus1964-68v05/d258 (Calhoun, 'Coping with Corruption'), frus1922v01/d841 (Crowder's graft memorandum), frus1969-76ve09p2/d155 (Saudi agents' fees briefing). Each: exact Hamming over all 314,616 sign rows (numpy `bitwise_count`), top 10; then the Hamming-800 pool reranked by int8 cosine from the Tier-2 shards, top 10, with the calibrated figure `(cos-0.40)/0.60` (document-to-document offset 0.40 from `retrieval.scoreCalibration`; the raw cosine is labelled raw). Full lists: `vec_v2.txt`. Summary: the Calhoun memo's nearest neighbours are at Hamming 97 to 101, which is at the 10th-neighbour median (102) and nowhere near the 1st (82); they are Vietnam documents of 1959 to 1970 and half contain no corruption vocabulary (frus1958-60v01/d55, frus1964-68v04/d21, d222, frus1961-63v04/d347, frus1961-63v02/d300, d322). The Crowder graft memorandum's nearest is its sibling lottery memorandum at 73 and the next at 92; the rest sit at 99 to 103, i.e. the other Crowder despatches. The Saudi briefing's nearest are Saudi-policy documents at 69 to 81. Funnel calibrated figures run 0.80 to 0.89. All of these are suggestions: they show the vectors cluster by country and period, not by the theme of corruption. I read the non-vocabulary neighbours listed above for corruption language (kw.py with a wider pattern: venal, dishonest, squeeze, payoff, racket, profiteer, honest, scandal, improper, extort, theft, steal, pilfer, black market, irregularity) and found none in frus1964-68v04/d21, d222, frus1961-63v04/d347, frus1958-60v01/d55, frus1977-80v18/d151, frus1969-76ve09p2/d118. Baseline for the distances: V1.

**V3 Semantic join into the database.** The V2 neighbours were joined to `document_cache` (header, is_front_matter, is_editorial_note) and `document_dates` and flagged against the corruption-vocabulary hit list (`corevocab` column in vec_v2.txt): all 30 Hamming neighbours and all 30 funnel rows are in `document_cache` (all 553 volumes are present, so no neighbour is absent from the local index), and none is front matter or an editorial note. Of the 30 Hamming neighbours, 18 are not in the vocabulary hit list (5, 6 and 7 for the three anchors).

**V4 Centroid similarity (operation 3).** Volume centroids (the 553 volumes in index order, dequantised code x scale, raw cosine, float64; numpy printed divide/overflow warnings from its matmul that I traced to the library, not the data: all 553 centroid scales finite and norms 0.997 to 1.002). Nearest volumes: frus1964-68v05 -> v04 (0.991), v06 (0.988), v03, v02, v01; frus1922v01 -> 1922v02, 1921v01 (0.988), 1923v01; frus1977-80v03 -> 1969-76v31 (0.976), 1981-88v38 (0.971), 1969-76v03; frus1947v07 -> 1948v08 (0.985), 1948v07, 1946v10. Baseline: random volume pairs (5,000, Random(1877)) mean 0.904, sd 0.031, max 0.992. These are centroid-to-centroid raw cosines, not calibrated (the calibration offsets apply to document-to-query or document-to-document scores). They find neighbouring annuals, not a corruption theme.

**V5 The map (operation 4).** Placement of the 38 collection documents in semantic-map.bin (layout of 2026-10-15; 140 clusters): 9 of 38 unclustered (0.237); the baseline is the unclustered share among all documents of the same 27 volumes, 4,552 of 18,886 (0.241), against 88,059 of 314,616 (0.280) corpus-wide, so the collection is not unusual on that measure. Clusters hit (terms from `semantic-map-index.json`): 29 (lao, vietnamese, vietnam, thieu; 7 documents), 3 (nanking, shanghai, chinese, tientsin; 5), 43 (zaya, crowder, airway, guatemala; 4), 42 (castro, somoza, cuban, cuba; 3), 5 (philippine ...; 2), 37 (shah, iran ...; 2) and singles in Greece, Congo, Korea, summitry, IMF and Constantinople clusters. Clusters are geography and period, not corruption; no cluster is a corruption cluster, which is why the map was used only to check where the argument documents fall.

**V6 Near-duplicates (operation 5).** For each of the 38 collection documents, the nearest other document in the whole corpus by Hamming. One document is a reprint: frus1950v03/d728 (Truman-Attlee, second meeting, 42,064 characters) against frus1950v07/d977 (42,091 characters, 'United States Delegation Minutes of the Second Meeting of President Truman and Prime Minister...') at Hamming 13: the same meeting printed in two volumes. It is counted once in the collection. No other document has a neighbour under 65. Within the collection the closest pairs are frus1977-80v03/d230 and d248 (72), frus1922v01/d841 and d842 (73), d836 and d842 (77), frus1977-80v03/d35 and d65 (79); the mean within-collection pair distance is 155.4 against the random 167.1 (sd 14.8), a moderate cohesion explained by shared sub-topics.

**Which overview documents were reached through a vector operation and no full-text query.** Exactly one is in the collection: frus1922v01/d836 (Crowder's letter of 5 April 1922), found as the second Hamming and funnel neighbour of the graft memorandum (V2); its text contains none of the family's words (it is the only one of the 38 collection documents absent from `core_hits.json`, the list of the 3,096 family hits; checked in a one-line comparison of `collection.fruscollection` against that file). It is cited in the overview only as the first step of the memoranda sequence. Everything else in the overview was reached by full-text queries (section 3) or by following a document's own cross-reference. No document was added from the map or from centroids.

**Limits of this section.** Absence of a neighbour is not evidence of absence: the funnel's recall@10 is 0.9021, so about one of ten true neighbours is missed. Similarity is a lead: nothing here supports 'related' as a historical claim without reading, and the neighbours of the three anchors were read only for corruption vocabulary, not for substantive relation. No free-text embedding was possible (no embedder in this session), so no vector search by the word 'corruption' was attempted.

## 8. TRACE TABLE (one row per number and per quotation in the overview)

| Overview item | memo anchor |
|---|---|
| About three thousand documents use the vocabulary (3,058) | N3 |
| one in a hundred of the 311,000 documents in the 551 first-edition volumes | N1 (311,429 after suppression), N3 (3,058 / 311,429 = 0.98%) |
| forty-document test; eight of forty; about one in five | N5 (decision-link 8 of 40) |
| the choices fall into four kinds; Burma 1955; Vietnam; 1975 onward | section 1 and Q-rows of the cited documents; no number |
| 38 documents in the collection; 37 carry a source line; one (1893 despatch) does not | A1 |
| 23 of the 37 from RG 59 Central Files | A1 (decimal 20 + subject_numeric 3) |
| Conference Files, entry A1 3051B, NAID 602875, 1949-1972, 238 linear feet, unrestricted; one document; probable match by name | A1 (frus1950v03/d728), A3 note 1 |
| lot 89 D 149, 1981-1988, two documents, no NAID | A1 (frus1981-88v01/d247, d264), A3 note 2 |
| Carter National Security Affairs five documents; Eisenhower one; Reagan one; not resolved | A1, A3 note 4 |
| Library of Congress Kissinger Papers two; Center of Military History folder one; State Johnson Files one | A1 |
| Carter 53, Johnson 28, Nixon 27, lot 66 D 95 17, lot 63 D 351 12 citations | A2 output (second block, 'Carter Library National Security Affairs 53' etc.) |
| NAID 2839192, entry A1 1586E, 1947-1979, partly restricted | A3 note 3 |
| 450 decimal-file class citations | A2 output (centralFileClass 450 citations in 259 documents) |
| no entry before December 1910 | A2 caveat (earliest 1910-12-06) |
| offline data barely reaches before 1940 | guide rule (11 of 695 bundled series), A3 note 6 |
| positive control 94,049 documents, every volume but one | N6 |
| negative control found nowhere | N6 |
| 143 dated documents 1840s; 158 1850s; 177 in the 1990s from one volume; none uses the vocabulary; 130 of those use 'Department of State' | N1 flags, N9 |
| CIA source of 117 hit documents | A4 |
| 38 documents from 27 volumes dated 1893 to 1986; about 311,000 searched | A1 (27 volumes in archival_results.txt scope line), N1 |
| from about one in five to nearly all of the 3,058 | N5, N3 |
| How this was done: 3,058 hits; 40 of 40; 35 of 40; 33 of 40; 8 of 40 | N3, N5 |
| How this was done: nearer neighbours of three anchors | V2 |
| quotation: 'unprecedented corruption and ineffectiveness in the working of the Gov...' (frus1947v05/d23) | Q1 |
| quotation: 'come to aid of existing government, corrupt as it is...' (frus1949v08/d576) | Q2 |
| quotation: 'The war against the Communist NPA is going badly, partly because the m...' (frus1981-88v01/d247) | Q3 |
| quotation: 'no part of the criticism of corruption and inefficiency attaches to th...' (frus1944v06/d269) | Q4 |
| quotation: 'General Crowder feels that the Department should not consent to a loan...' (frus1922v01/d864) | Q5 |
| quotation: 'Philippine performance must precede consideration of any additional Am...' (frus1950v06/d802) | Q6 |
| quotation: 'I am utterly unable to obtain evidence which would satisfy beyond a re...' (frus1922v01/d841) | Q7 |
| quotation: 'these reports had reached certain circles on Capitol Hill and certain ...' (frus1958-60v01/d135) | Q8 |
| quotation: 'it has become a key obstacle to pacification...' (frus1964-68v05/d258) | Q9 |
| quotation: 'an invasion of the sovereignty of the Republic of Viet-Nam...' (frus1964-68v05/d258) | Q10 |
| quotation: 'The government conduit weakens conditionality; when reform fails to oc...' (frus1981-88v41/d251) | Q11 |
| quotation: 'I pointed to Nationalist China as an example of the wrong policy....' (frus1949v06/d330) | Q12 |
| quotation: 'the Shah observed that China’s downfall was largely due to corruption...' (frus1949v06/d330) | Q13 |
| quotation: 'What is the corruption in Persia in comparison with corruption elsewhe...' (frus1950v05/d289) | Q14 |
| quotation: 'Therefore, recommend we do not change for the present our aid policies...' (frus1961-63v22/d252) | Q15 |
| quotation: 'Problems arising from publicity over the enormous commissions being pa...' (frus1969-76ve09p2/d155) | Q16 |
| quotation: 'President Carter placed high priority on the negotiation of an interna...' (frus1977-80v24/d337) | Q17 |
| quotation: 'some exports are lost because foreign companies can bribe foreign offi...' (frus1977-80v03/d248) | Q18 |
| quotation: 'the officials at Amadia were corrupt men...' (frus1893/d628) | Q19 |
| quotation: 'delay, improper influence, squeeze and corruption all but universal to...' (frus1921v01/d275) | Q20 |
| quotation: 'as in Manila...' (frus1981-88v01/d264) | Q21 |
| quotation: 'arbitrary and corrupt government...' (frus1912/d1502) | Q22 |

## 9. Files

`overview.md`, `collection.fruscollection`, `queries.log`, this memo; scripts and outputs in the same directory: s.py, dump.py, kw.py, q1.sql, q2.sql, q3.py, q4.py, q4b.py, sample.py, ctrl.py, tei_scan.py, archival.py, arch2.py, arch_collection.py, vecsetup.py, v0..v3.py, gen_overview.py, build_collection.py, verify_quotes.py, verify_ov.py; outputs *_results.txt, vec_*.txt, tei_scan.json; documents in `docs/`.

## 10. Honest limits

(1) The argument set is a reading sample: of 3,058 hit documents I scanned about 150 snippet lines from the top of targeted searches, retrieved 66 documents whole and read keyword windows in them; selection toward documents that state a link is built in, so the 'one in five' is the better guide to prevalence than the collection is. (2) The decision-link coding is one coder's judgement of 260-character windows. (3) Counting surfaces: the index counts (body_text, blends document and footnote language, stems) and the TEI counts (tag-stripped occurrences, apparatus not separated) are different surfaces and are never mixed in a single number. (4) The `Foreign Relations` printed titles in the overview come from `manifest.json`. (5) Dates: the periodisation uses `document_dates.date_iso` (derived from the corpus's frus:doc-dateTime-min); the one visible disagreement is frus1977-80v03/d65, whose database date is 1977-10-01 while its printed dateline reads October 5, 1977; the overview uses the printed date. (6) q1.sql in the run directory had a parse error on its second statement after the first (a `.mode` dot-command ordering); its first statement produced the decade table, since superseded by q4b.
