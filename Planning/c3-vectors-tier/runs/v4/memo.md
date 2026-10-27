# Scope memo — Cuba in U.S. thinking about national security and prosperity, 1870s–1980

Run v4, 2026-10-27. Every number below is conditional on the index copy of 2026-10-25, which holds **553 volumes** (all 553 of the series), 321,749 documents, 1,103 front-matter and 8,481 editorial-note rows. Tag `M-nn` at the start of a line is the anchor the trace table uses.

## 0. Coverage and controls

M-01 Coverage: `SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;` → `553|321749|1103|8481`. Read-only proof: `BEGIN; CREATE TABLE zz(x); ROLLBACK;` under `-readonly` → "attempt to write a readonly database".
M-02 Positive control: `SELECT COUNT(DISTINCT dc.volume_id) FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid WHERE frus_documents MATCH '"department of state"'` → 552 of 553 volumes; the one without it is frus1919Parisv05 (90 rows, Council of Four minutes), off-topic. 98,970 documents match (s4_themes.out). Negative control `MATCH 'ZZZ_IMPOSSIBLE_ZZZ'` → 0 (rows and documents). Both ran in the same pass as the theme counts (s4_themes.py) and again directly.

## 1. Scope chosen and how it was found

M-03 Editors' headings first (s2_headings.py over `SELECT volume_id, structure_json FROM volume_structures`, Python `re.I` on /cuba/): 315 headings name Cuba. Their formulae run from "Cuban correspondence, 1866–1871" (frus1872p2v1) and "Destruction of American property in Cuba" (1895), through "Political situation in Cuba" and "Relief of suffering in Cuba" (1898), "Political unrest in Cuba" (1930–32), "Reciprocal trade agreement" (1934), "military measures for hemisphere defense" (1941–44), "strategic air bases" (1945), "Cuban–Soviet relations and Communist activities" (1946), "policy to weaken the Cuban economy" (1960), to the Missile Crisis volumes and "U.S.-Cuba Hijacking Agreement" (1969–73). Full list: s2_headings.out.
M-04 Six volumes carry Cuba in their title (s1_manifest_cuba.out): frus1958-60v06, frus1961-63v10, frus1961-63v10-12mSupp, frus1961-63v11, frus1964-68v32, frus1977-80v23. 195 of 553 volumes carry the manifest tag `cuba`.
M-05 Inclusion rule (working set W, s3_set.py → cuba_set.tsv): (A) every document under an editors' heading matching /cuba/i at any depth, UNION (B) every document matching `SELECT dc.volume_id, dc.document_id FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid WHERE frus_documents MATCH 'header:(cuba OR cuban)'`; then drop is_front_matter=1, is_editorial_note=1, frus1951-54IranEd2 and frus1969-76ve15p2Ed2. A=6,668, B=2,236, union 6,928, kept **6,718** (A-only 4,482, B-only 260, both 1,976); 6 undated. Periodised on document_dates.date_iso (the frus:doc-dateTime-min the index stores), not on series year.
M-06 Known over-inclusion: rule A takes multi-country headings ("Responses to the notification of a state of war … by Cuba", frus1917Supp01v01; "Enemy aliens in Panama, Cuba, and the Dominican Republic") and the 1902 "Protection of Cuban interests by United States consular officials" chapters (consular business in third countries). Known under-inclusion: 1865–1889 Cuba business sits in Spain chapters under headers such as "Mr. Fish to Mr. Cushing", so W holds only 3 documents in the 1870s and 0 in the 1880s. For those decades I used a second set M19 (M-10).
M-07 W per decade, against dated non-apparatus documents of the decade (s3_set.out):

| decade | W | dated non-apparatus | per 1,000 | top volume (share of W) |
|---|---|---|---|---|
| 1860s | 149 | 11,268 | 13.2 | frus1872p2v1 146 of 149 |
| 1870s | 3 | 5,821 | 0.5 | frus1872p2v1 3 of 3 |
| 1880s | 0 | 6,484 | 0.0 | — |
| 1890s | 290 | 9,845 | 29.5 | frus1898 149 of 290 |
| 1900s | 305 | 10,261 | 29.7 | frus1902 97 of 305 |
| 1910s | 1,004 | 30,842 | 32.6 | frus1917 224 of 1,004 |
| 1920s | 500 | 20,374 | 24.5 | frus1921v01 135 of 500 |
| 1930s | 682 | 40,073 | 17.0 | frus1933v05 344 of 682 |
| 1940s | 775 | 75,872 | 10.2 | frus1944v07 132 of 775 |
| 1950s | 460 | 42,801 | 10.7 | frus1958-60v06 355 of 460 |
| 1960s | 2,002 | 27,654 | 72.4 | frus1961-63v10-12mSupp 515 of 2,002 |
| 1970s | 453 | 22,258 | 20.4 | frus1977-80v23 289 of 453 |
| 1980s | 89 | 6,038 | 14.7 | frus1977-80v23 89 of 89 |

M-08 Mention set M (any column `MATCH 'cuba OR cuban'`, non-apparatus, dated; s4_themes.out), per 1,000 dated non-apparatus: 1860s 27.2 (306 of 11,268); 1870s **62.4 (363 of 5,821)**; 1880s 45.3 (294 of 6,484); 1890s 60.1 (592 of 9,845); 1900s 35.8; 1910s 28.4; 1920s 34.9; 1930s 27.3; 1940s **17.3 (1,316 of 75,872)**; 1950s 22.9; 1960s **113.8 (3,147 of 27,654)**; 1970s 84.8 (1,887 of 22,258); 1980s 103.8 (627 of 6,038). Mention counts include editors' footnotes (body_text blends them).
M-09 Thinness: the 1980s numerator is one volume (frus1977-80v23, 89 of 89, all 1980); the 1870s W figure is 3 documents. Neither is a trend.

## 2. Frames measured

M-10 19th-century frame census (s13_frames19c.py): M19 = FTS `MATCH 'cuba OR cuban'`, non-apparatus, date_iso 1865–1890, kept only where body_text has ≥2 case-sensitive `\bCuba(n|ns)?\b`; frames by Python `re.I` over body_text whitespace-collapsed (footnotes included). N: 1860s 68, 1870s 240, 1880s 167. 1870s: insurrection/revolution/filibuster 121 of 240; commerce/trade 81 of 240; annex/intervene 68 of 240; slavery/emancipation **57 of 240**; American citizens/property/interests 54 of 240; prosperity 26 of 240; sugar 22 of 240. 1880s: commerce/trade 72 of 167; American property 39 of 167; slavery 8 of 167. The 1870s "strategic_defense" figure (56 of 240) is a FALSE FRIEND: the regex catches "defense" of prisoners in the Virginius and embargo cases; not used. Top volumes: frus1874 64, frus1885 33, frus1873p1v2 32.
M-11 W frame census, body_text only, `re.I`, whitespace-collapsed (s12_frames.py → s12_frames.tsv). Patterns are printed in the script. Counts are documents, "N of M" with M = W's dated documents in the decade:

| frame | 1890s (290) | 1900s (305) | 1910s (1,004) | 1920s (500) | 1930s (682) | 1940s (775) | 1950s (460) | 1960s (2,002) | 1970s (453) | 1980s (89) |
|---|---|---|---|---|---|---|---|---|---|---|
| American citizens/property/interests/capital | 63 | 25 | 51 | 20 | 25 | 46 | 54 | 51 | 20 | 4 |
| commerce/commercial/trade | 30 | 45 | 95 | 63 | 107 | 160 | 55 | 304 | 122 | 14 |
| sugar | 14 | 15 | 90 | 59 | 73 | 283 | 127 | 223 | 37 | 3 |
| insurrection/revolution/filibuster | 82 | 37 | 130 | 7 | 110 | 16 | 171 | 367 | 76 | 9 |
| order/stability | 6 | 15 | 18 | 23 | 58 | 20 | 34 | 101 | 28 | 5 |
| annex/intervene | 34 | 37 | 63 | 44 | 81 | 36 | 87 | 319 | 74 | 8 |
| strategic/defense/Guantanamo | 10 | 14 | 115 | 12 | 14 | 161 | 117 | 765 | 131 | 29 |
| communism/Soviet | 0 | 0 | 0 | 2 | 41 | 28 | 172 | 1,203 | 191 | 27 |
| missiles | 0 | 0 | 0 | 0 | 1 | 0 | 1 | 437 | 47 | 5 |
| refugee/exile/migration/Mariel | 5 | 3 | 4 | 6 | 12 | 7 | 44 | 409 | 87 | 48 |
| prosper* | 17 | 18 | 13 | 17 | 11 | 11 | 10 | 22 | 7 | 0 |

The 1910s strategic/defense count is driven by the multi-country First World War headings (M-06). Not separated: document text from footnotes (body_text holds both); all densities here blend editor language.
M-12 FTS stem trap measured: FTS `communist OR communism` returns 31 of 149 W documents in the 1860s and 156 of 306 M documents (s4_themes.out); the literal regex `\bcommunis(?:m|t|ts|tic)\b` returns 0 of 149 in the 1860s, while `\bcommunicat\w*` returns 31 (s5_literal.out). The index treats "communism" and "communication" as one word. FTS theme counts in s4_themes.out are therefore NOT published except where the literal census agrees.
M-13 Phrase "national security" (s11_ns.py). FTS `MATCH '"national security"'` → 1,039 W documents. Literal census (whole set, header+dateline+source_note+body_text, whitespace-collapsed, `re.I`): STRICT `\bnational security\b` 1,035 of 1,039; TOLERANT `\bnational[\s\-,().]+securit(?:y|ies)\b` 1,035 of 1,039. The 1.000-ish share tests the stemmer, not the referent. Referent test: in body_text, after deleting institution and file names (`national security (files?|council|action|adviser|affairs|agency|archives|memorandum|study|decision|staff|policy papers|documents)`), the phrase survives in **47 of 1,039**: 1910s 1 of 1; 1930s 1 of 1; 1940s 1 of 1; 1950s 1 of 21; 1960s **32 of 681**; 1970s 9 of 266; 1980s 2 of 68. The question's own phrase is overwhelmingly the name of the archive (Kennedy Library "National Security Files") or the Council, not the officials' argument.
M-14 FALSE-FRIEND TEST (s12_frames.out), 1960s, FTS: "national security" W 681 of 2,002 vs all dated non-apparatus 1960s documents 10,169 of 27,654; "prosperity OR prosperous" W 22 of 2,002 vs corpus 407 of 27,654; control "department of state" W 883 of 2,002 vs 17,322 of 27,654. Both of the question's terms sit at or below the corpus baseline, so they measure the corpus, not Cuba; I stopped using them as counts and used the period's vocabulary (M-10, M-11) instead.
M-15 "prosper*" literal (s12_frames.tsv): never more than 22 documents in any decade of W (1960s 22 of 2,002; 1890s 17 of 290). Contemporaries wrote of commerce, property, sugar, tariffs and reciprocity, not prosperity.

## 3. Archival channels (never summed)

M-16 CAME-FROM channel over W (s6_archival.py; `SELECT volume_id, document_id, repository, record_group, lot_file_norm, series_name, citation_era, decimal_class FROM document_sources`, filtered in Python to W): 5,934 of 6,718 W documents have a row. citation_era (a citation FORM, not a date): decimal 3,554; structured 1,556; lot_file 313; subject_numeric 157; cfpf 154; named_series 136; unrecognized 53; published 11. Record group 59 on 4,191 rows; RG 330 on 101. Top repository/series: Central Intelligence Agency 328; Department of State (unnamed) 287; Kennedy Library National Security Files 249 (+ "NSF" 112); Carter Library National Security Affairs 198; Johnson Library National Security File 165; National Archives Central Files 1964–66 97; Nixon NSC Files 79; Eisenhower Library Whitman File 65.
M-17 Decimal classes glossed ONLY by the schedule governing each document's own date (s10_gloss.py, `SELECT volume_id,document_id,decimal_class FROM document_sources WHERE citation_era='decimal' AND decimal_class IS NOT NULL`, decimal-class-labels.json coverage.glossableYears 1910–49, 1950–59, 1960–63): 1910–49 837.00 (Internal affairs, Cuba, Political affairs) 766; 837.51 (Cuba, Financial conditions) 367; 837.61 (Cuba, Agriculture) 269; 611.37 (Commerce, United States–Cuba) 145; 837.15 (Cuba, Public works) 72; 1950–59 737.00 (Internal political and national defense affairs, Cuba) 184; 1960–63 737.00 102; 611.37 54. The decimal file opens in 1910; nothing before it is glossable.
M-18 Lots resolved through central-files-index.json `lotFiles` (lotNumber) and series-facts-index.json `byNaId` (s8_resolve.out; 62D1 by inline python):
- 65D438 — RG 59, entry A1 3053, NAID 27022950, Records Relating to the Cuban Missile Crisis, 1962–1963, Executive Secretariat; Restricted – Partly. came-from 51 W docs; pointed-at 15 rows.
- 74D272 — RG 59, A1 5175, NAID 614703, Records of Under Secretary George W. Ball, 1961–1966; Unrestricted. came-from 46; pointed-at 7.
- 66D501 — RG 59, UD-UP 293-B, NAID 648748, Files Pertaining to Operation Mongoose, 1963–1965 (Office of the Coordinator of Cuban Affairs); Unrestricted. came-from 23.
- 62D418 — RG 59, A1 3147, NAID 2068466, Subject Files (Office of the Assistant Secretary for Inter-American Affairs), 1959–1962; Restricted – Partly. came-from 15 (incl. frus1958-60v06/d517); pointed-at 5.
- 62D24 — RG 59, A1 3148, NAID 2363836, Subject Files of the Special Assistant on Communism (ARA), 1958–1961; Restricted – Partly. came-from 15; pointed-at 10.
- 62D1 — RG 59, A1 1583E/F, NAID 2838992, Records Relating to Activities with the National Security Council, 1948–1961; Restricted – Partly. came-from 7 (incl. frus1961-63v10/d202).
- 66D95 — RG 59, A1 1586E, NAID 2839192, Records Relating to NSC Policy Papers, 1947–1979; Restricted – Partly. pointed-at 25 rows (the largest pointed-at lot).
- 66D204 — RG 59, A1 1590, NAID 2538452, Presidential and Secretary of State Correspondence with Foreign Heads of State, 1953–1964; access Restricted – Possibly. came-from 8; pointed-at 9.
- 64D199 and 65D330 — both RG 59, A1 1566, NAID 602231, Secretary's and Under Secretary's Memorandums of Conversation, 1953–1964; Unrestricted (two lots converge on one series).
- 73D191 — RG 59, A1-5758, NAID 1040618, Records Relating to Cuba, 1957–1975 (Coordinator of Cuban Affairs); Restricted – Partly. pointed-at 5.
- 70D149 and 65D533 — NOT in central-files-index.json; unresolved.
M-19 POINTED-AT channel over W (s6_archival.py; `SELECT volume_id, document_id, anchor, repository, collection, lot_file_norm, decimal_class FROM external_citations`, filtered to W): 960 rows in 681 of 6,718 documents; anchors centralFileClass 466, presidentialLibrary 344, lotFile 150. Top: Department of State 616 rows; Carter Library National Security Affairs 100; Kennedy NSF 72; Johnson NSF 71. Decimal prefixes pointed at: 737.00 143; 611.37 35; 837.613 33. This channel has no row before 1910-12-06 and stores the citation fragment only.
M-20 Presidential library collections (presidential-library-catalog.json, s19_preslib2.out): Kennedy NSF = collection JFK-4, NAID 1164 (Country Files 1961–1963, NAID 193236); Johnson NSF = LBJ-NSF, NAID 567979 (Latin America Country Files 1963–1969, NAID 567985); Eisenhower "Whitman File" = probably DDE-EPRES, Papers as President, NAID 1124 (name match by me, not by the file). Carter Library "National Security Affairs, Brzezinski Material" did NOT resolve (only the Brzezinski Collection, NAID 1104, which is a different collection). The catalogue gives no access status for library collections.
M-21 Nineteenth-century shelves (central-files-index.json `countrySeries`, s8_resolve.out, s9_decimal.out): Despatches from U.S. Consuls in Havana, 1783–1906 (file unit NAID 196006797, 133 rolls); Notes from the Cuban Legation, 1844–1906 (file unit NAID 183303950); Despatches from U.S. Ministers to Cuba, 1902–1906 (file unit NAID 177380758, 18 rolls); 15 other Cuban consular posts (Santiago, Matanzas, Cienfuegos …). These are microfilmed RG 59 series; the bundled data give no entry numbers or access status for them. The despatches from Madrid, where most 1870s Cuba diplomacy ran, are not in the Cuba rows I filtered. The offline stack reaches only 11 of 695 series before 1940.

## 4. Quotations (all verified, s17_verify.py: `SELECT body_text, is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?`; raw substring = True and collapsed substring = True for all 18; all fm/en 0/0)

Reading SELECT for every document read: `SELECT header, dateline, source_note, body_text, length(body_text), is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?` (s14_read.py and three inline runs); raw text in texts/.
M-22 frus1870/d197 (1870-08-19, Fish circular): "With the Spanish islands of Cuba and Porto Rico we maintain, in spite of their adverse legislation, a large commerce by reason of our necessities and of their proximity."
M-23 frus1873p1v2/d50 (1872-11-24, Sickles to Fish): "a question touching so large a number of colored people dwelling almost within sight of our southern boundary"
M-24 frus1874/d552 (1874-02-06, Fish to Cushing): "Commercially, as well as geographically, it is by nature more closely connected with the United States than with Spain."
M-25 frus1874/d552: "the existence of slave-labor in Cuba, and its influence over the feelings and interests of the peninsular Spaniards, lie at the foundation of all the calamities"
M-26 frus1898/d490 (1897-07-16, Sherman to Woodford): "Not only are our citizens largely concerned in the ownership of property and in the industrial and commercial ventures which have been set on foot in Cuba through our enterprising initiative and sustained by their capital, but the chronic condition of trouble and violent derangement in that island constantly causes disturbance in the social and political condition of our own people."
M-27 frus1898/ch83 (1898-04-12, the President's message): "The present condition of affairs in Cuba is a constant menace to our peace, and entails upon this Government an enormous expense."
M-28 frus1902/d294 (1902-06-02, Squiers to Hay, enclosing the Cuban President's message — a Cuban voice): "The immediate remedy would be to obtain a satisfactory reduction in the American tariffs"
M-29 frus1933v05/d241 (1933-05-01, Hull to Welles): "a speedy improvement in economic and commercial conditions in Cuba would result in an immediate allaying of popular unrest and of political agitation"
M-30 frus1933v05/d241: "They are, on the contrary, measures intended to prevent the necessity of intervention."
M-31 frus1934v05/d170 (1934-05-29, Treaty of Relations): "the stipulations of that agreement with regard to the naval station of Guantánamo shall continue in effect."
M-32 frus1945v09/d745 (1945-08-22, Norweb): "The military advantages to the United States of access to the Batista base, at the very least on conditions permitting unlimited use at all times during the life of the convention, are of course very great."
M-33 frus1958-60v06/d517 (1960-05-11, Rubottom): "use judiciously selected economic pressures at those points where Castro’s domestic and international policies have weakened Cuba’s economic structure in order to engender more public discomfort and discontent"
M-34 frus1958-60v06/d567 (1960-07-26, Gates to Herter): "Since we have crossed one Rubicon with our sugar and oil actions, should we not consider other economic measures that could have a significant impact on Castro’s regime?"
M-35 frus1961-63v10/d202 (1961-05-04, NSC task-force paper): "there is no doubt that Cuba is being used as a base for export of the communist-fidelista revolution."
M-36 frus1961-63v11/d34 (1962-10-20, 505th NSC meeting): "This route is aimed at preventing any addition to the strategic missiles already deployed to Cuba and eventually to eliminate these missiles."
M-37 frus1969-76ve11p1/d278 (1974-01-21, Rush to Kubisch): "The United States has no vital interests in Cuba."
M-38 frus1977-80v23/d19 (1977-08-03, PRC meeting): "The embargo was our biggest bargaining chip, and we should not “puncture” it without getting some commitment to international restraint."
M-39 frus1977-80v23/d98 (1980-04-28, Brzezinski and Watson): "trying to control the flow of Cuban refugees into the United States."

M-40 Reading accounting: retrieved whole 22 documents (captured length = length(body_text) in every case: s14_read.out and the inline runs): frus1876/d298, frus1898/d490, frus1898/ch83, frus1902/d294, frus1933v05/d241, frus1934v05/d170, frus1941v07/d444, frus1945v09/d745, frus1958-60v06/d517, frus1958-60v06/d567, frus1961-63v10/d202, frus1961-63v11/d34, frus1977-80v23/d19, frus1977-80v23/d98, frus1875v01/message (front matter — read, NOT used), frus1870/d197, frus1876/d281, frus1873p1v2/d50, frus1876/d252, frus1874/d552, frus1902/d313, frus1969-76ve11p1/d278. Quoted: 16 documents (18 passages). Read but not used: frus1876/d298 (Burriel affair, no Cuba-policy argument), frus1941v07/d444 (mostly Peru), frus1875v01/message (front matter), frus1876/d281, frus1876/d252, frus1902/d313. I read keyword-in-context sentences of each, not every line.

## VECTORS

All on digest 89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101 — identical in semantic-vectors-index.json, semantic-vectors-binary.bin (offset 20), semantic-map.bin (offset 20) and SemanticVectors/.generation; index generated 2026-10-15, harvestGenerated 2026-10-15T06:55:14. Id decode round-trip: 553 of 553 volumes. Scripts s15_vectors.py → s15_vectors.out, s16_kth.py → s16_kth.out. Tier-2 shards were NOT used (no rerank).
M-41 Baselines at this digest: random pairs (20,000, random.Random(1877)) mean 167.1, sd 14.8, 1st percentile 132, minimum 95 of 512. k-th neighbour: 25th-nearest distance over 40 documents drawn with random.Random(1877): median 108, quartiles 103 and 113 (s16_kth.out).
- **Nearest neighbours of a document** (Hamming over Tier-1 sign bits, full scan, 314,616 rows): anchors frus1898/d490, frus1958-60v06/d517, frus1933v05/d241; top 25 each.
M-42 frus1898/d490: 25th neighbour at 90 (tighter than the median 108). Neighbours outside the 1890s: frus1874/d552 at **61**, frus1872p1/d431 at 73, frus1902/d313 at 82, frus1873p1v2/d94 at 86, frus1878/d484 at 88, frus1961-63v06/d11 and d83 at 89.
M-43 frus1958-60v06/d517: 25th at 86; nearest of all is frus1969-76ve11p1/d278 at **66** (1974), then frus1948v09/d420 at 73, frus1950v02/d440 at 77, frus1977-80v06/d194 at 82.
M-44 frus1933v05/d241: 25th at 97; neighbours across eras: frus1902/d313 83, frus1898/d503 84, frus1927v02/d598 87, frus1904/d207 88, frus1902/d294 89, frus1874/d552 92, frus1898/d490 93.
- **Semantic join** into document_dates (flagging OTHER-DECADE) and document_cache (flagging NOT-IN-INDEX): all 75 neighbours are in the index; 8 of 25, 8 of 25 and 18 of 25 respectively fall in another decade than their anchor. Read as suggestions measured against the k-th-neighbour baseline (M-41), not as evidence; I read frus1874/d552 and frus1969-76ve11p1/d278 and both bear the claims they are cited for.
- **Centroid similarity** (volume centroids, int8 × scale, cosine; s15_vectors.out): annual volumes 1872–1902 sit at 0.95–0.97 with each other; the 1933–1945 volumes at 0.96–0.97; the Cuba volumes of 1958–1980 at 0.94–0.98. Across the divide: frus1898 to frus1961-63v11 0.865, frus1872p2v1 to frus1961-63v11 0.861, frus1933v05 to frus1958-60v06 0.930. Nearest volumes to frus1977-80v23: frus1969-76ve11p1 0.981, frus1977-80v24 0.972. Centroid cosines are high everywhere (one corpus, one genre), so only the ordering is used.
- **The map** (semantic-map.bin, 2026-10-15 layout, 140 clusters): frus1958-60v06/d517, frus1961-63v10/d202 and frus1977-80v23/d19 all sit in cluster 42 (terms castro, somoza, cuban, cuba; 7,650 documents). frus1898/d490, frus1933v05/d241, frus1874/d552 and frus1969-76ve11p1/d278 are unclustered (28.0% of all placements are; no era-matched baseline computed, so no claim rests on it).
- **Near-duplicates**: nearest-neighbour distance for each read document (s15_vectors.out): smallest 48 (frus1898/d490 → frus1898/d495, a different Sherman–Woodford despatch in the same exchange); no distance below 48, so no quoted document is a reprint of another in the set. frus1898/ch83 and frus1875v01/message have no vector (not keyed in the index's segments).
M-45 Reached through a vector operation and through NO full-text query: **frus1874/d552** (nearest neighbour of frus1898/d490; my 1870s full-text query `body_text:(cuba AND (insurrection OR independence) AND (intervention OR mediation))`, 1869–1880, top 15 by bm25, did not return it) and **frus1969-76ve11p1/d278** (nearest neighbour of frus1958-60v06/d517; no full-text query of mine touched frus1969-76ve11p1). Both are in the overview and the collection. Recall@10 is 0.902; the absence of a neighbour proves nothing.

## 5. Decisions left open (see overview)
Rule A's multi-country headings; whether the Spain chapters of 1865–1897 count as "Cuba" (I used the mention set M19 for them); whether a Cuban voice (frus1902/d294) counts as U.S. thinking (I cite it as context only).

## TRACE TABLE (overview number or quotation → memo line)

| overview item | memo |
|---|---|
| 553 volumes, all indexed | M-01 |
| about 6,700 documents in the working set | M-05 |
| controls (State Department phrase in all but one volume; nonsense term in none) | M-02 |
| 1870s about 62 per 1,000; 1940s about 17; 1960s about 114 | M-08 |
| 1960s headed share about 72 per 1,000, a quarter from one microfiche volume | M-07 |
| slavery in about a quarter of 1870s Cuba documents (57 of 240) | M-10 |
| commerce in about a third of 1870s documents (81 of 240) | M-10 |
| property/citizens in about one in five 1890s documents (63 of 290) | M-11 |
| sugar in more than a third of 1940s documents (283 of 775) | M-11 |
| strategic/defense one in five 1940s (161 of 775); three in eight 1960s (765 of 2,002) | M-11 |
| communism/Soviet in three in five 1960s documents (1,203 of 2,002) | M-11 |
| refugees/migration one in five 1960s (409 of 2,002); about half of 1980 (48 of 89) | M-11 |
| "national security" own prose 47 of about 1,040; 32 of 681 in 1960s | M-13 |
| false-friend comparison | M-14 |
| "prosperity" never above 22 documents a decade | M-15 |
| came-from: 5,934 documents with a source; decimal file classes | M-16, M-17 |
| lots and NAIDs | M-18 |
| pointed-at: 681 documents, 960 citations | M-19 |
| presidential library NAIDs | M-20 |
| 19th-century despatch series | M-21 |
| communication/communism trap | M-12 |
| quotations 1–18 | M-22 … M-39 (one each, in order) |
| vector-reached documents | M-42, M-43, M-45 |
| baselines | M-41 |

## Final checks (s20_collection.py → s20_collection.out)
M-46 Collection: 16 document entries, 18 excerpts; every pair found in document_cache; every excerpt an exact substring of its body_text; no Ed2 volume; no duplicate pair. Every document the overview cites by URL (16 pairs; the script's 17th "pair" is frus1958-60v06/d517 with a trailing semicolon from the regex) is in the collection. Every quotation in the overview is inside one of the 18 verified passages M-22…M-39 (the script's leftover list is terms and names in quotation marks, not quotations).
M-47 Constraint breach, disclosed: one command wrote a two-line copy of reading_ids.txt (two volume/document id pairs, no corpus text) to /tmp/x, outside the run directory. It was deleted (`rm -f /tmp/x`, logged). Nothing else was written outside the run directory, and nothing under the forbidden trees was read.
