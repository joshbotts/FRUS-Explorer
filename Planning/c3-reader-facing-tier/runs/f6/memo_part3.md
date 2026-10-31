## 10. Trace table: every number and quotation in the overview

Memo lines are the M-numbers above and the sections named. A year inside a citation parenthesis, e.g. (1964, Volume I, Document 197), is taken from the cite table (section 6). 

| number or set of numbers in the overview | memo line it comes from |
|---|---|
| 76 (volumes on East Asia and the Pacific) | M2 (SELECT COUNT(DISTINCT volume_id) ... IN the 76 ids = 76) |
| 553 (volumes of the series in the index) | M1 (canary: COUNT(DISTINCT volume_id) = 553) |
| 14 (volumes on information policy and public diplomacy) | M3 (= 14 volumes; also Lot count 'Kennedy 14' row in M13, same numeral different meaning) |
| 1,300 (documents in the family, rounded from 1,296) | M4 (COUNT(*) = 1296) |
| 61 (documents retrieved whole) | Section 7 reading accounting and retrieval_check.txt (61 of 61 whole) |
| 1945, 1980 (period searched), 1951 (kept volume), 1945-1963 (no decimal-file series bundled) | Section 2 scope (earliest document year 1944 or later; 1945 volume first; document_dates up to 1981); 1951 = frus1951v06p1/p2 in eap_volumes.txt; 1945-1963 = archival_facts.txt decimal line and the check that central-files-index.json has no decimal-file series for those years (jsonscan.py) |
| 1910 (no pointed-at row before 1910) | House rule stated in the brief (external_citations has no row before 1910-12-06); not a measurement of mine |
| 3, 15, 18 (series per USIA accession); two (series of FRC 306-84-0003) | M11 (accession-series-index.json: 306/67A222 = 3, 306/68A4933 = 15, 306/72A5121 = 18, 306/840003 = 2); the isolated '3' in the binational-centre sentence is M14 |
| four (series of lot 62 D 430), three (series of lot 62 D 1) | M12 (lot-claimants-index.json: 4 and 3 claimants) - also 'three' counts the vector-found documents, see below |
| 41, 16, 13, 9 (documents citing Lots 66 D 95, 62 D 430, 63 D 351, 62 D 1); 19, 25, 14, 7 (Nixon, Johnson, Kennedy, Carter library citations); 178 (central file numbers) | M13 (docs column of the pointed-at query; 14 for Kennedy is the same '14' token as M3) |
| 64 (documents), 28 (volumes) - survey/poll scan; 33 (documents), 17 (volumes) - leaflet/script/film scan; 3 (binational centres); 60 (Peace Corps) | M14 table rows 1, 3, 6 and 4 respectively (absence_results.txt); '33' also appears as the sample hits in M5 (33 of 40) |
| 40 (sample), 33 (held the intended words), seven (the other seven) | M5 and M6 (33 of 40 tolerant and strict; seven misses, searched, none held the words) |
| Three (documents found by similarity); Three (days later) | Three vector-found documents: section 8 (frus1969-76ve12/d16, ve12/d17, frus1977-80v22/d3). 'Three days later': document_dates 1965-02-24 (frus1964-68v02/d160) to 1965-02-27 (frus1964-68v02/d172) |
| 28 million (in a quotation) | Q14 (frus1964-68v01/d197 passage 'Vietnamese audiences at USIS film showings last year totalled an estimated 28 million.') |
| Years of documents and series, and dates (1949, 1950, 1953, 1954, 1961, 1962, 1963, 1964, 1965, 1967, 1968, 1969, 1971, 1975, 1977; 1960s, 1963-1969, 1969-1974, 1953-1961, 1947-1979 and similar) | Each year in a document description is the first four characters of date_iso of the cited document (cite table C1-C27, section 6); each series date range is from archival_facts.txt (series-facts-index.json inclusive years y0-y1; library series dates from presidential-library-catalog.json) |
| NAIDs, entry numbers, FRC accession numbers, record groups, file numbers, lot numbers, linear feet (26, 47, 9, 4 etc.) | NAIDs and extents: archival_facts.txt; accession and entry strings (FRC 67 A 222, 68 A 4933, 72 A 5121, UD WW 257, P-207, P-104, 306-84-0003; decimal 711.90, 611.90, 790.5, 611.98; Lot 63 D 351 Entry A1 1586E): the source notes in section 6 and archival_facts.txt; report number R-10-65: footnote text of frus1964-68v02/d172 |
| The structural numerals: '1.', '2.', '3.' headings of the skeleton, 'Document N' inside citations | Not counts. Document numbers: cite table column 'document_number' (SELECT document_number FROM document_cache). |

### Quotations

| quotation in the overview | verified passage |
|---|---|
| "has not thus far been effective" | Q4 (frus1952-54v14p2/d820) |
| "not progressed to my satisfaction" | Q15 (frus1964-68v02/d160) |
| "effective." | Q4 (frus1952-54v14p2/d820), Q9 (frus1917-72PubDipv06/d126) |
| "[a] considerably expanded information program" | Q1 (frus1949v07p2/d386) |
| "are inclined by their psychology to wait and see who is winning" | Q2 (frus1950v06/d32) |
| "thus gradually creating a climate of victory" | Q3 (frus1952-54v12p2/d403) |
| "sensationally represented in their press," | Q32 (frus1952-54v14p2/d820) |
| "has not thus far been effective" | Q4 (frus1952-54v14p2/d820) |
| "a major propaganda campaign on Viet Cong insurgency" | Q6 (frus1961-63v01/d49) |
| "a harvest of ill-will" | Q7 (frus1961-63v01/d265) |
| "We cannot do more with the image of the GVN than is made available by the GVN itself" | Q29 (frus1961-63v01/d339) |
| "to get my American propaganda from a source which restricts its outlets to its own people" | Q8 (frus1961-63v02/d5) |
| "much of our audience would tend to regard it as mere words without deeds" | Q9 (frus1917-72PubDipv06/d126) |
| "questionable" | Q10 (frus1917-72PubDipv06/d133) |
| "virtually no sympathy for the Diem regime, except in South Korea and the Philippines" | Q11 (frus1961-63v04/d108) |
| "there is no conceivable information program that will make defeats look like victories" | Q13 (frus1964-68v01/d197) |
| "Vietnamese audiences at USIS film showings last year totalled an estimated 28 million," | Q14 (frus1964-68v01/d197) |
| "have not progressed to my satisfaction" | Q15 (frus1964-68v02/d160) |
| "largely apathetic" | Q30 (frus1964-68v02/d172) |
| "inadequate security and ineffective Government" | Q31 (frus1964-68v02/d172) |
| "have also expanded and grown more effective" | Q16 (frus1964-68v03/d138) |
| "the effort should not be construed as a propaganda mechanism" | Q17 (frus1917-72PubDipv07/d171) |
| "patient persistence," | Q35 (frus1961-63v23/d289) |
| "a demonstrated respect for Indonesia’s neutral stance" | Q12 (frus1961-63v23/d289) |
| "Such an action would be interpreted by both our enemies and friends as a retreat" | Q18 (frus1964-68v26/d106) |
| "has not given proper attention to the need for a national information program designed to ..." | Q19 (frus1964-68v27/d386) |
| "Asians are, to varying degrees, America watchers," | Q20 (frus1917-72PubDipv08/d31) |
| "a psychological threshold for economic frictions" | Q22 (frus1969-76v19p2/d67) |
| "very clearly in default" | Q34 (frus1969-76v38p2/d105) |
| "lack credibility" | Q36 (frus1969-76v38p2/d105) |
| "our affirmations of good intentions are welcomed by all," | Q24 (frus1969-76ve12/d16) |
| "is something that happens to other people" | Q25 (frus1969-76ve12/d17) |
| "have become accustomed to seeing the United States go through periodic cycles of intense i..." | Q26 (frus1977-80v22/d3) |
| "shoring up the confidence of East Asians in America’s long-term staying power" | Q27 (frus1977-80v30/d79) |
| "an especially close working relationship between State and USIA" | Q28 (frus1977-80v30/d81) |

### Word-numbers that are not counts

'first' ("reading the editors' headings first") and 'one' ("a Thai-initiated one"; "is one I verified") are not counts. 'Channel' labels are names, not numbers.
