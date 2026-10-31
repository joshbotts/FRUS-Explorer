# Scope memo — corruption and U.S. foreign policy (run s8, 2026-10-30)

Operator memo. Every number carries its query or its script and output file. All counts are conditional on the
library: the coverage query returned **553 volumes, 321,749 rows, 1,103 front-matter rows, 8,481 editorial-note rows**
(`SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;` →
`553|321749|1103|8481`). The library holds all 553 volumes of the series, so no result here is thin because of a
partial library; results can still be thin because FRUS selected few documents.

Read-only proof: `sqlite3 -readonly … "BEGIN; CREATE TABLE zz(x); ROLLBACK;"` failed with "attempt to write a readonly database".

## 1. Scope chosen, and how

**Question.** How has corruption, or allegations of corruption, affected U.S. foreign policy decisions or the conduct of diplomacy?

**Scoping set (the "corruption set").** Non-apparatus documents matching the full-text query `corrupt*`, second editions
suppressed (frus1951-54IranEd2 and frus1969-76ve15p2Ed2 dropped; their first editions kept; 25 hits removed by the drop):

```sql
SELECT COUNT(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid
WHERE frus_documents MATCH 'corrupt*' AND c.is_front_matter=0 AND c.is_editorial_note=0
  AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2');            -- 2186
-- same predicate, COUNT(DISTINCT c.volume_id)                                     -- 399
-- same predicate with volume_id IN (the two Ed2 ids)                              -- 25 (suppressed)
SELECT COUNT(*) FROM document_cache c WHERE c.is_front_matter=0 AND c.is_editorial_note=0
  AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2');            -- 311429
```

So the corruption set is **2,186 of 311,429** non-apparatus documents (about 7.0 per 1,000), in **399 of 553** volumes.
Counting surface: the FTS5 index (porter stems; `corrupt*` covers corrupt, corruption, corrupted, corruptly, corruptible, …).
A companion family `brib*` returns 658 documents (census below). Ed2 surface: this index with apparatus excluded.

**Inclusion rule for the argument (the collection).** A document enters the argument only if (a) it matches `corrupt*`,
`brib*` or the Lockheed-payments query below, (b) it was read in this session around every match, and (c) its text shows
corruption, or an allegation of it, bearing on a U.S. decision, instruction, negotiation or representation — not merely
describing a foreign government. 28 documents met it, in five episodes chosen because they lead the per-volume ranking of
the corruption set (raw/top_vols_corrupt.txt; titles in raw/top_vols_titles.txt) and because the documents read show a
decision turning on the issue. The 28 pairs are in raw/set.txt; all 28 verified present and non-apparatus:

```sql
WITH s(v,d) AS (VALUES <the 28 pairs in raw/set_values.sql>)
SELECT s.v, s.d, c.document_number, dd.date_iso, c.is_front_matter, c.is_editorial_note
FROM s JOIN document_cache c ON c.volume_id=s.v AND c.document_id=s.d
LEFT JOIN document_dates dd ON dd.volume_id=s.v AND dd.document_id=s.d;   -- 28 rows, all 0|0 (raw/set_meta.txt)
```

**Date span of the argument:** 1947-02-07 to 1978-08-26 (document_dates.date_iso of the 28).

**Chapter headings read first** (TEI, script raw/heads.py, output raw/heads.out and raw/heads_hits.txt). Surface: every
`<head>` element, tag-stripped and whitespace-collapsed, regex (case-insensitive)
`corrupt|brib|lockheed|illicit payment|questionable payment|improper payment|payoff|graft\b|kickback|venal`.
36 heads hit (raw/heads_hits.txt). Positive control: 61,353 heads contain "Memorandum"; negative control
"ZZZ_IMPOSSIBLE_ZZZ": 0. The editors have **no chapter devoted to corruption** in any volume; the hits are document heads
whose editorial summary names it — concentrated in the 1973–76 electronic volumes (Saudi agents' fees, Lockheed in Japan,
Libya, Western Europe, Nicaragua, Haiti). The editors' formula for the 1975–76 affair is "Lockheed" plus "payments"/"bribery",
which drove the Lockheed query below.

## 2. Measurements

### 2.1 Literal share of the scoping families (census, whole sets)

Script raw/census.py (SQL printed in raw/census_corrupt.out, raw/census_brib.out):

```sql
SELECT c.volume_id, c.document_id, c.header||' '||coalesce(c.dateline,'')||' '||coalesce(c.source_note,'')||' '||c.body_text
FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ?
AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
ORDER BY c.volume_id, c.document_id          -- ? = 'corrupt*' / 'brib*'
```

Text = header+dateline+source_note+body_text, whitespace-collapsed. Python `re`.
STRICT = lower-case `\bcorrupt` (case-SENSITIVE); TOLERANT = `\bcorrupt\w*` case-insensitive (any inflection, any case).
(Single-word family, so the between-word clause of the tolerant form does not apply.)

| family | TOLERANT | STRICT | evenly spaced sample of 40 (tolerant / strict) |
|---|---|---|---|
| corrupt* | 2,186 of 2,186 | 2,159 of 2,186 | 40 of 40 / 40 of 40 |
| brib* | 658 of 658 | 634 of 658 | 40 of 40 / 40 of 40 |

The strict misses are capitalised forms ("Corruption", "CORRUPT"). A 1.000 tolerant share tests the stemmer, not the
referent, so the referent was tested separately:

- **Garbled-telegram false friend** ("text corrupt", "corrupt group"): regex in raw/census.py; documents whose every match is
  in that sense: **9 of 2,186** (corrupt*), **0 of 658** (brib*).
- **Hand-coded referent**, the 40-document evenly spaced sample of corrupt* (raw/sample40_corrupt.json, coding in
  raw/notes_referent.txt): venality / political corruption of officials or governments **36 of 40**; legal term of art
  ("corruption of the blood") 1 of 40 (frus1917/d1144); rhetorical epithet without an allegation 3 of 40
  (frus1894app2/d306, frus1933v02/d187, frus1943/d231); garbled sense 0 of 40.
  So about nine in ten corrupt* hits are on-referent, and the set over-counts by roughly one in ten.

Lockheed and Foreign Corrupt Practices families — script raw/phrase.py (same SELECT; Python `re`, re.I for both forms):

| query | hits | volumes | dates | TOLERANT | STRICT | file |
|---|---|---|---|---|---|---|
| `Lockheed AND (brib* OR payoff* OR payment*)` | 43 | 20 | 1957-04-23 – 1983-04-19 | 43 of 43 (`\bLockheed\w*`) | 43 of 43 (`\bLockheed\b`) | raw/phrase_lockheed.out |
| `"foreign corrupt practic*"` | 4 | 2 | 1978-07-28 – 1980-07-29 | 4 of 4 (`foreign[\s\-,().]+corrupt\w*[\s\-,().]+practic\w*`) | 4 of 4 (`foreign corrupt practices`, single spaces, re.I) | raw/phrase_fcpa.out |

Volumes/dates from:
```sql
SELECT COUNT(*), COUNT(DISTINCT c.volume_id), MIN(d.date_iso), MAX(d.date_iso) FROM frus_documents f
JOIN document_cache c ON c.rowid=f.rowid LEFT JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id
WHERE frus_documents MATCH '<query>' AND c.is_front_matter=0 AND c.is_editorial_note=0
AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2');
```
Same form gave: `"Church Subcommittee" OR "Multinational Subcommittee" OR "Subcommittee on Multinational Corporations"`
24 documents / 15 volumes / 1950-09-01–1976-06-04 (literal share NOT taken — not published in the overview as a phrase count;
used only as a pointer); `corrupt* AND ("American personnel" OR "U.S. personnel" OR "American officials")` 76 / 54 (not read,
not published); `"black market" AND corrupt*` 28 / 25 (not read, not published); `ZZZ_IMPOSSIBLE_ZZZ` 0 / 0.

The FCPA family's referent: all 4 are documents of 1978–80 (frus1977-80v03/d152, d230, d248; frus1977-80v18/d57) — listed in
raw/phrase_fcpa.out; not read beyond the census. Lockheed's referent is the company in all 43 (single proper noun); not every
one concerns payments (the AND clause can be satisfied by an unrelated "payment" — not measured).

### 2.2 Controls and the false-friend test

Positive control "Department of State" (phrase) present in **552 of 553** volumes:
```sql
SELECT COUNT(*) vols, SUM(n=0) zero_vols FROM (SELECT v.volume_id, (SELECT COUNT(*) FROM frus_documents f JOIN document_cache c
ON c.rowid=f.rowid WHERE frus_documents MATCH '"Department of State"' AND c.volume_id=v.volume_id) n
FROM (SELECT DISTINCT volume_id FROM document_cache) v);                       -- 553|1
```
The one volume without it is frus1919Parisv05 (90 rows; minutes of the Council of Four), which returns 89 documents for
`"United States"` — the scan works there. Negative control `ZZZ_IMPOSSIBLE_ZZZ`: 0 documents (this pass and 2.1).

False-friend test for the question's own term (raw/falsefriend.txt):
```sql
WITH base AS (SELECT c.rowid rid, c.volume_id, CASE WHEN c.volume_id IN ('frus1947v07','frus1948v07','frus1958-60v01',
 'frus1964-68v04','frus1964-68v05','frus1964-68v06','frus1961-63v22','frus1969-76ve09p2','frus1969-76ve12','frus1969-76ve15p2',
 'frus1969-76ve09p1','frus1977-80v15') THEN 'on_topic_12' ELSE 'rest' END grp FROM document_cache c
 WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')),
cor AS (SELECT rowid rid FROM frus_documents WHERE frus_documents MATCH 'corrupt*'),
ctl AS (SELECT rowid rid FROM frus_documents WHERE frus_documents MATCH '"Department of State"'),
neg AS (SELECT rowid rid FROM frus_documents WHERE frus_documents MATCH 'ZZZ_IMPOSSIBLE_ZZZ')
SELECT grp, COUNT(*), SUM(rid IN (SELECT rid FROM cor)), SUM(rid IN (SELECT rid FROM ctl)), SUM(rid IN (SELECT rid FROM neg)) FROM base GROUP BY grp;
```
| group | documents | corrupt* | "Department of State" (control) | negative |
|---|---|---|---|---|
| the 12 volumes of the argument | 5,222 | 294 of 5,222 (56.3 per 1,000) | 1,779 of 5,222 (0.341) | 0 |
| all other volumes | 306,207 | 1,892 of 306,207 (6.2 per 1,000) | 92,045 of 306,207 (0.301) | 0 |

corrupt* is about nine times as dense in the argument's volumes; the control is about 1.1 times. The term measures the
question, not the corpus. Caveat: the 12 volumes were chosen partly by corrupt* density, so the ratio is partly circular;
the control's flatness is the informative half.

### 2.3 Decade shape (periodised on document_dates.date_iso, the index's stored document date)

Surface: the FTS index, non-apparatus, Ed2 dropped, documents with a stored date. Periodised on `document_dates.date_iso`
(the index's stored rendering of the document's `frus:doc-dateTime-min`; not re-derived from the TEI in this run), not on
the volume's series year. Query (raw/decade_corrupt.txt):
```sql
WITH hits AS (<corrupt* set as in §1>), base AS (SELECT c.volume_id, c.document_id, substr(d.date_iso,1,3)||'0s' dec
FROM document_cache c JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id
WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND d.date_iso IS NOT NULL AND c.volume_id NOT IN (<two Ed2>))
SELECT b.dec, COUNT(*), SUM(h.document_id IS NOT NULL), ROUND(1000.0*SUM(h.document_id IS NOT NULL)/COUNT(*),1)
FROM base b LEFT JOIN hits h ON h.volume_id=b.volume_id AND h.document_id=b.document_id GROUP BY b.dec;
```
Top-volume share (raw/decade_topvol.txt): same hit set grouped by decade and volume, `MAX(n)/SUM(n)`.

| decade | dated docs | corrupt* | per 1,000 | top volume (its share of the decade's hits) |
|---|---|---|---|---|
| 1860s | 11,268 | 74 | 6.6 | frus1865p4, 10 of 74 |
| 1870s | 5,821 | 64 | 11.0 | frus1875v01, 8 of 64 |
| 1880s | 6,484 | 43 | 6.6 | frus1883, 7 of 43 |
| 1890s | 9,845 | 72 | 7.3 | frus1894app2, **38 of 72** (one volume: Hawaii) |
| 1900s | 10,261 | 40 | 3.9 | frus1909, 8 of 40 |
| 1910s | 30,842 | 131 | 4.2 | frus1913, 11 of 131 |
| 1920s | 20,374 | 40 | 2.0 | frus1922v01, 7 of 40 |
| 1930s | 40,073 | 61 | 1.5 | frus1930v02, 7 of 61 |
| 1940s | 75,872 | 354 | 4.7 | frus1947v07, 59 of 354 |
| 1950s | 42,801 | 407 | 9.5 | frus1952-54v13p2, 22 of 407 |
| 1960s | 27,654 | 457 | 16.5 | frus1964-68v05, 40 of 457 |
| 1970s | 22,258 | 354 | 15.9 | frus1969-76ve11p1, 32 of 354 |
| 1980s | 6,038 | 85 | 14.1 | frus1981-88v01, 10 of 85 |

(Decades before 1840 hold 0 hits over 182 dated documents; 1840s 1 of 143; 1850s 1 of 158; 1990s 0 of 177.)
Footnotes are not separated from document text here: body_text contains the editors' notes, so these rates blend
document and editor language. No TEI apparatus split was run for density.

### 2.4 Readings

Reader: raw/read.py. SELECT:
```sql
SELECT c.header, coalesce(c.dateline,''), coalesce(c.source_note,''), c.body_text, length(c.body_text), d.date_iso
FROM document_cache c LEFT JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id
WHERE c.volume_id=? AND c.document_id=?
```
Each document's whole text is saved to raw/docs/<volume>_<doc>.txt. **32 documents retrieved whole** (for every one,
captured length = length(body_text); printed by read.py as `len=… captured=…`), **22 quotations (Q1–Q22) from 22 documents**
(one quotation per document). Characters, not bytes.

### 2.5 Quotations (verified)

Verification script raw/verify.py, output raw/verify.out:
`SELECT body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0`
— each quotation tested as an exact substring of body_text (no whitespace folding, curly apostrophes as printed). All 22: exact_count=1 (Q21 and Q22 added after the overview draft, verified in the same way).
Retrieving SELECT for each: raw/read.py's SELECT above (the windows printed in the session), then raw/verify.py's.

| id | pair | offset / length | speaker / layer | text |
|---|---|---|---|---|
| Q1 | frus1947v07/d628 | 5666 / 9576 | Marshall to Patterson, document text | "those reactionaries in the Chinese Government who have been counting on substantial American support regardless of their actions and party corruption would have cause to conclude that they were right" |
| Q2 | frus1947v07/d617 | 4870 / 10346 | Vincent to Marshall, document text | "should be carefully examined to determine whether they will be made ineffectual by waste, or corrupt management on the part of Chinese officials seeking personal financial gain" |
| Q3 | frus1947v07/d582 | 208 / 3521 | Wedemeyer to Marshall | "The information received in Shanghai serves to reaffirm earlier certainty of corrupt and inept practices, both political and economic." |
| Q4 | frus1948v07/d322 | 2176 / 3815 | Stuart reporting Chiang | "It is precisely because he knows the Government to be corrupt and inefficient, he says, that he has repeatedly asked for American aid" |
| Q5 | frus1958-60v01/d267 | 4790 / 6169 | Durbrow reporting Diem | "no country Asia more diligent in prosecuting corruption than GVN" |
| Q6 | frus1964-68v05/d395 | 1836 / 5952 | Katzenbach to Johnson | "There was unanimous agreement that a visible and credible anti-corruption effort would help a great deal in improving the Administration’s position, and in building a more effective GVN." |
| Q7 | frus1964-68v06/d31 | 3820 / 4174 | "The President:" (Johnson), notes of meeting | "We cannot have perfection. We have corruption here." |
| Q8 | frus1961-63v22/d221 | 795 / 1248 | R. H. Johnson (NSC staff), recommendation 2 | "Make it absolutely clear that U.S. assistance in the future, above a minimum maintenance level, will be conditional upon Korean performance" |
| Q9 | frus1961-63v22/d297 | 5417 / 7981 | Department to Embassy Seoul | "Who is to decide who is corrupt?" |
| Q10 | frus1961-63v22/d202 | 2050 / 4694 | Farley (ICA) report | "The extent and depth of graft, corruption and fraud in the major institutions of Korean society today" |
| Q11 | frus1969-76ve09p2/d122 | 1389 / 28403 | Embassy Jidda airgram | "At the same time we have concluded that corruption has been on the increase." |
| Q12 | frus1969-76ve09p2/d152 | 4298 / 9755 | "MR. MAW:", Secretary's staff meeting | "I have taken the position that fees should not be paid to these intermediaries unless disclosed to and approved by the paying government" |
| Q13 | frus1969-76ve15p2/d293 | 881 / 4361 | **editors' source note** quoting Kissinger to Ford, 8 Oct 1975 (Ford Library memcon) | "We must do everything possible to keep this quiet." |
| Q14 | frus1969-76ve15p2/d292 | 1055 / 3590 | Hartman memorandum, document text | "Such payments coming when Strauss was Defense Minister paved the way for the sale of the Starfighter to the FRG." |
| Q15 | frus1969-76ve12/d219 | 2963 / 3402 | Ford to Miki | "I hope the Government of Japan can support the United States proposal for an international agreement to curtail such practices" |
| Q16 | frus1969-76ve12/d227 | 1067 / 6206 | Embassy Tokyo | "THIS IS THE BIGGEST POLITICAL SCANDAL FOR JAPAN’S RULING LIBERAL DEMOCRATIC PARTY SINCE ITS FORMATION TWENTY-ONE YEARS AGO." |
| Q17 | frus1977-80v15/d83 | 1891 / 4061 | Matthews (ARA/CEN) memorandum | "It’s not primarily his corruption, his human rights record, or anything else he has done." |
| Q18 | frus1977-80v15/d80 | 3087 / 5998 | Embassy Managua transmitting the opposition's program | "Eradication of the corruption which has characterized the Somocist dictatorship" |
| Q19 | frus1969-76ve09p2/d155 | 5752 / 30108 | Atherton briefing memorandum | "to pay large agents’ fees to a Saudi businessman, Adnan Khashoggi, who may have made improper payments to Saudi military officers" |
| Q20 | frus1977-80v15/d68 | 4912 / 8572 | **editors' footnote** quoting Pérez's letter to Carter | "corrupt dictatorship that has systemically violated human rights" |
| Q21 | frus1964-68v06/d134 | 2019 / 4564 | Embassy Saigon telegram | "meet criticism in the U.S." |
| Q22 | frus1969-76ve09p2/d161 | 961 / 7879 | **editors' source note**, file title in RG 84 Jidda Lot 79F80 | "POL Northrop and Lockheed" |

Other passages used in paraphrase only (read in the session; not quoted): frus1958-60v01/d135 (Parsons and Wood raised
corruption with Thuan, April 1960); frus1964-68v04/d215 (Ky told Lodge senior generals were corrupt; Lodge's telegram cited as
Central Files POL 27 VIET S); frus1964-68v06/d134 (embassy urged the Loc anti-corruption speech, 74 officials disciplined, as
"another useful point to meet criticism in the U.S."); frus1947v07/d583 (Sprouse's reform list for the Control Yuan);
frus1948v07/d407 (Gimo appointing comrades "regardless their proven corruption"); frus1969-76ve09p2/d161 (editors' note: the
Department instructed Akins to tell Sa'ud and Sultan "that the matter was outside executive branch control"); frus1969-76ve12/d218
(editors' summary: Miki asked Ford to disclose the names); frus1969-76ve12/d219 (editors' note: Japanese cabinet accepted the
President's proposal for sharing information, March 12, 1976); frus1969-76ve09p1/d50 (Qadhafi alleged a Libyan official had
been bribed by Lockheed); frus1977-80v15/d80 (opposition program).

## 3. Archival channels (never summed)

### 3.1 Came-from (document_sources: where the printed document came from)

Corruption set (2,186): **1,904 of 2,186** have a document_sources row (earlier-era documents largely lack a parsed source).
```sql
WITH hits AS (<corrupt* set>) SELECT s.citation_era, coalesce(s.repository,'-'), coalesce(s.record_group,'-'),
coalesce(s.series_name,'-'), coalesce(s.lot_file_norm,'-'), COUNT(*) n FROM hits h JOIN document_sources s
ON s.volume_id=h.volume_id AND s.document_id=h.document_id GROUP BY 1,2,3,4,5 ORDER BY n DESC LIMIT 25;   -- raw/came_from_corrupt.txt
```
Leading rows: CIA 92; Nixon Presidential Materials, NSC Files 78; Johnson Library, National Security File 65; Carter Library,
National Security Affairs 47; RG 59 Central Files 1970–73 39, 1967–69 35, 1964–66 22; Kennedy Library NSF 23; RG 59 Lot 63D351 16;
Lot 54D270 15; Ford Library, National Security Adviser 15; Eisenhower Library, Whitman File 14. (citation_era is a form, not a date.)

Argument set (28; raw/set_came_from.txt plus the source notes read for d155, d161, d218, d219, d68, d83):

| series (came-from) | record group / entry | NARA id | dates / access | documents |
|---|---|---|---|---|
| Department of State, Central Decimal File | RG 59; entry and NAID **not resolvable in the bundled JSON** (collection-authority.json carries the name only) | — | — | 8: frus1947v07/d617, d628, d582, d583; frus1948v07/d322, d407; frus1958-60v01/d135, d267 |
| Subject-Numeric Central Files | RG 59; not resolved in bundle | — | — | 2: frus1964-68v06/d134; frus1961-63v22/d297 |
| Central Foreign Policy File | RG 59; not resolved in bundle | — | — | 3: frus1969-76ve12/d227; frus1969-76ve09p1/d50; frus1977-80v15/d80 |
| Jidda Embassy Files, Lot 79F80 | RG 84; lot **absent** from central-files-index.json lotFiles | — | — | 1: frus1969-76ve09p2/d122 |
| Transcripts of Secretary of State Kissinger's Staff Meetings | RG 59 | not resolved | — | 1: frus1969-76ve09p2/d152 |
| Records of Secretary of State Henry Kissinger | RG 59 | not resolved | — | 2: frus1969-76ve15p2/d292, d293 |
| Records of Deputy Secretary Warren Christopher, Lot 81D113 | RG 59, entry P 14 | NAID 1487627 | 1975–1981; Restricted – Partly (FOIA (b)(1)) | 1: frus1977-80v15/d68 |
| Johnson Library, National Security File, Vietnam Country Files | — | series NAID 591194 (LBJ-NSF, collection 567979) | 1963–1969; access not in bundle | 2: frus1964-68v04/d215; frus1964-68v05/d395 |
| Johnson Library, Tom Johnson's Notes of Meetings | — | Papers of Tom Johnson, Meeting Notes series NAID 23657995 | 1966–1968; access not in bundle | 1: frus1964-68v06/d31 |
| Kennedy Library, President's Office Files / National Security Files | — | POF collection 1166 (Country Files 193654); NSF collection 1164 (Country Files 193236) | 1961–1963 | 2: frus1961-63v22/d202 (POF), d221 (NSF) |
| Ford Library, NSA, Presidential Correspondence with Foreign Leaders | — | collection 572571, series 572583 | 1974–1977 | 2: frus1969-76ve12/d218, d219 |
| Ford Library, NSA, Presidential Country Files for Middle East and South Asia | — | collection 568221, series 568224 | 1974–1977 | 1: frus1969-76ve09p2/d161 |
| Carter Library, National Security Affairs, Staff Material (Pastor Files) | — | Records of the Office of the NSA, collection 560131; Brzezinski's Country Files 560151 (closest match; staff-material series not resolved) | 1977–1981 | 1: frus1977-80v15/d83 |
| Library of Congress, Manuscript Division, Kissinger Papers | — | not in bundle | — | 1: frus1969-76ve09p2/d155 |

Sum check: 8+2+3+1+1+2+1+2+1+2+2+1+1+1 = 28.

**Correction to the parsed source (decisive query run both ways):** document_sources gives frus1969-76ve09p2/d161 as
"National Archives | 84 | Jidda Embassy Files:, Box 30". Its own source note (same row, raw_text and c.source_note) begins
"Source: Ford Library, National Security Adviser, Presidential Country Files for the Middle East and South Asia, Box 30"; the
RG 84 Jidda reference sits later in the note as a pointer. Query:
`SELECT c.source_note, s.raw_text FROM document_cache c JOIN document_sources s ON … WHERE c.volume_id='frus1969-76ve09p2' AND c.document_id='d161';`
The table above uses the source note (came-from = Ford Library); the Jidda file goes to pointed-at.

JSON lookups: raw/lots.py (central-files-index.json lotFiles, keyed on lotNumber with spaces folded) → raw/lots.out;
raw/facts.py (series-facts-index.json byNaId, decoded through legend) → raw/facts.out; raw/plc.py, raw/plc2.py
(presidential-library-catalog.json) → raw/plc2.out; inline python for LBJ-NSF / JC-NSA series and for series-facts on library
NAIDs (all library NAIDs: NOT IN series-facts-index, so their access status is not in the bundle); raw/auth.py, raw/auth2.py
(collection-authority.json) → raw/auth2.out. Lots 54D270, 59D95 and 79F80: 0 rows in lotFiles.
central-files-index.json `numericalFile.seriesNaId` 654171 is not in series-facts-index. The bundle carries no NAID for the RG 59
Central Decimal File, Subject-Numeric files or CFPF; they are named and their shelf is RG 59 at College Park, but no entry
number or identifier can be given from this stack.

### 3.2 Pointed-at (external_citations: what the editors' footnotes cite)

Caveat stated before ranking: this channel has no row before **1910-12-06**
(`SELECT MIN(d.date_iso) FROM external_citations e JOIN document_dates d ON …` → 1910-12-06), stores the citation fragment
not the sentence, and holds lot, library and decimal anchors only.

Corruption set:
```sql
WITH hits AS (<corrupt* set>) SELECT e.anchor, coalesce(e.repository,''), coalesce(e.collection,''), coalesce(e.lot_file_norm,''),
COUNT(*) rows_, COUNT(DISTINCT e.volume_id||'/'||e.document_id) docs FROM hits h JOIN external_citations e
ON e.volume_id=h.volume_id AND e.document_id=h.document_id GROUP BY 1,2,3,4 ORDER BY docs DESC LIMIT 20;   -- raw/pointed_at_corrupt.txt
```
Leading rows (documents citing): Department of State central-file class 184; Carter Library, National Security Affairs 23;
Johnson Library, National Security File 21; Nixon Presidential Materials, NSC Files 19; Lot 66D95 9; Lot 63D351 7;
Johnson Library, President's Daily Diary 5; Lot 62D1 4; Eisenhower Library, Whitman File 4; Kennedy Library NSF 4.

Resolved (raw/lots.out, raw/facts.out):
- Lot 66D95 and Lot 63D351 → both converge on **Records Relating to National Security Council Policy Papers**, RG 59, entry
  A1 1586E, NAID 2839192, creator Executive Secretariat, 1947–1979, Restricted – Partly (FOIA (b)(1)).
- Lot 62D1 → Records Relating to Activities with the National Security Council, RG 59, A1 1583E/A1 1583F, NAID 2838992,
  Policy Planning Council, 1948–1961, Restricted – Partly.

Argument set (raw/set_pointed_at.txt, 10 rows in 8 documents):
- **Lot 62D26** (cited in frus1958-60v01/d135) → Subject, Personal Name, and Country Files, RG 59, entry A1 3113, NAID 1965953,
  creator Bureau of Far Eastern Affairs, Office of the Assistant Secretary, 1960–1963, 10 linear feet, Restricted – Partly (FOIA (b)(1)).
  Creator heading checked: Far Eastern Affairs is on-topic for a 1960 Vietnam conversation.
- Kennedy Library, President's Office Files (frus1961-63v22/d202, d297).
- Johnson Library, President's Daily Diary (frus1964-68v05/d395); National Security File (frus1964-68v06/d134); Papers of Clark M.
  Clifford (frus1964-68v06/d31).
- Carter Library, National Security Affairs, Box 33 (frus1977-80v15/d68).
- Central-file class anchor (frus1958-60v01/d267).
Pointers read in the text but **not in the table** (so this channel misses them): RG 84 Jidda Embassy Files Lot 79F80,
"POL Northrop and Lockheed" and "POL Lockheed" (frus1969-76ve09p2/d161 note); RG 59 Central Files POL 27 VIET S
(frus1964-68v04/d215); Ford Library, NSA, Memoranda of Conversations, Box 15 (frus1969-76ve15p2/d293 note).

The offline stack barely reaches before 1940 (11 of 695 bundled series, per the house rules); the pre-1910 corruption hits
(about 300 of the 2,186) have no pointed-at rows at all. Not an archival absence.

No [HARVEST] path was given: the offline NARA harvest surface is unavailable to this run.

## VECTORS

Digest check (raw/vec.py → raw/vec.out): index `provenanceDigest`, binary header offset 20, map header offset 20 and the
shards' `.generation` all **89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101**; every shard opened in
raw/tier2.py asserted the same digest at offset 16. Index `generated` 2026-10-15, `harvestGenerated` 2026-10-15T06:55:14;
dims 512, 314,616 documents, 660 centroids. Id decode round trip: 0 mismatches of 553 volumes; all 28 argument pairs resolved.
`retrieval.measuredRecallAt10` 0.9021; `scoreCalibration.documentOffset` 0.40.

Baselines at this digest (raw/vec.out): random pairs (20,000 drawn with `random.Random(1877)`): mean 167.1, sd 14.8,
1st percentile 132, minimum 95 of 512. k-th-neighbour distribution over 200 documents drawn with `random.Random(1877)`:
1st-nearest median 82; 10th-nearest median 102 (quartiles 95, 108); 25th-nearest median 108 (quartiles 101, 114).

Operations run:

1. **Nearest neighbours of a document** — anchors frus1947v07/d628 and frus1969-76ve09p2/d122, over
   semantic-vectors-binary.bin (Hamming on the sign bits, numpy bitwise_count).
   - d628 (Marshall, March 1947): 15 neighbours at 52–70, all China 1945–49 (first: frus1947v07/d617 at 52, d625 at 55,
     frus1948v07/d506 at 60). Below the median 1st-neighbour distance (82): an unusually tight neighbourhood. Read against
     the k-th-neighbour distribution. Suggestions only.
   - d122 (Jidda airgram on corruption, Dec 1974): 15 neighbours at 81–106 — Saudi Arabia, 1969–80 (frus1977-80v18/d154 at 81,
     d176 at 88; frus1969-76ve09p2/d107 at 91; …; frus1969-76ve09p2/d155 at 103). The 1st at 81 is typical (median 82), the
     10th at 103 typical (median 102): an ordinary neighbourhood, not a tight one. All far inside chance (random mean 167).
2. **Semantic join** — d122's 15 neighbours joined into document_cache, document_dates and the full-text index
   (raw/semjoin_d122.txt): all 15 volumes present in the database (none absent, so no canonical-URL flag needed); 4 of 15
   match `corrupt* OR brib*`. One neighbour, frus1969-76ve09p2/d155 (Atherton's August 1975 briefing), was read and added to
   the argument (Q19). It also appears in the full-text list for the Lockheed-payments query in §2.1, so it was **not reached
   only** through the vectors. frus1977-80v18/d154 was read (no passage on fees, commissions or agents found; not used).
3. **Tier-2 rerank cosines** (raw/tier2.py → raw/tier2.out, shards frus1969-76ve09p2.vec and frus1947v07.vec, ids from the
   index segments): d122–d155 raw 0.882, calibrated 0.803; d122–d107 raw 0.882, calibrated 0.803; d628–d617 raw 0.972,
   calibrated 0.954; d628–d582 raw 0.824, calibrated 0.707. Calibration: (cosine − 0.40) / 0.60 (documentOffset).
4. **Near-duplicates** — every argument document against the whole corpus, Hamming ≤ 20 (raw/vec.out): only
   frus1969-76ve15p2/d292 and d293, each at 0 to its own Ed2 copy (frus1969-76ve15p2Ed2/d292, d293). The Ed2 copies are
   excluded from every count and from the collection. No other reprint among the 28. Within-set pairwise Hamming: mean 153.7,
   minimum 52.
5. Centroid similarity: none. The map: none.

Recall caveat: at recall@10 0.90, about one true neighbour in ten is missing from any list above; no claim of the form "no
similar document exists" is made.

**Documents in the overview reached through a vector operation:** frus1969-76ve09p2/d155 (neighbour of d122), which was also
in a full-text result list. **Reached through no full-text query: none.**

## 4. Threads not followed

Corruption of U.S. personnel (76 documents match corrupt* with "American officials/personnel", unread); the black market
(28, unread); the 1950s Indochina and 1951–54 Iran volumes (high in the ranking, unread); the 1973–76 Latin American
electronic volumes (frus1969-76ve11p1 leads the 1970s with 32 hits); the Philippines and Indonesia (frus1964-68v26);
nineteenth-century claims and the 1894 Hawaii appendix; Carter's note on Brzezinski's memorandum (frus1977-80v19/d241,
found by the heads scan, not read); the FCPA documents of 1978–80 (4, census only).

## 5. Checks before finishing

- Every quotation in the overview and every collection excerpt is one of Q1–Q22 above, all verified exact (raw/verify.out); raw/check.py found the only other quoted strings in the overview to be search terms, the control phrase and the collection's name.
- Every document the overview cites is among the 28 collection documents (checked by the script in queries.log: raw/check.py).

## TRACE TABLE (overview → memo)

| overview item | memo source |
|---|---|
| 553 volumes, the whole series | §0 coverage line |
| about 2,200 documents mention corruption, about 7 in 1,000, in about 400 volumes | §1 (2,186 of 311,429; 399 of 553) |
| about nine in ten hits are on-referent | §2.1 referent coding (36 of 40) |
| rate low in 1920s–30s, rising to about 16 in 1,000 in 1960s–70s; 1890s one volume | §2.3 table |
| about nine times as dense in the argument's volumes; control flat | §2.2 |
| 28 documents in the argument / collection | §1 inclusion rule, raw/set.txt |
| 43 Lockheed-payments documents in 20 volumes | §2.1 Lockheed row |
| 4 FCPA documents in 2 volumes, 1978–80 | §2.1 FCPA row |
| 24 documents naming the Church subcommittee in 15 volumes | §2.1 (pointer only) |
| no chapter on corruption; 36 heads | §1 chapter headings |
| Central Decimal File 8 of 28, etc. (came-from) | §3.1 table |
| Lot 62D26 → NAID 1965953, A1 3113; NSC Policy Papers NAID 2839192 | §3.2 |
| pointed-at has no rows before December 1910 | §3.2 |
| Q1 Marshall | §2.5 Q1 |
| Q2 Vincent | Q2 |
| Q3 Wedemeyer | Q3 |
| Q4 Chiang via Stuart | Q4 |
| Q5 Diem via Durbrow | Q5 |
| Q6 Katzenbach | Q6 |
| Q7 Johnson | Q7 |
| Q8 Korea aid conditional | Q8 |
| Q9 "Who is to decide who is corrupt?" | Q9 |
| Q10 Farley | Q10 |
| Q11 Jidda | Q11 |
| Q12 Maw | Q12 |
| Q13 Kissinger (editors' note) | Q13 |
| Q14 Strauss / Starfighter | Q14 |
| Q15 Ford to Miki | Q15 |
| Q16 Tanaka arrest | Q16 |
| Q17 Matthews | Q17 |
| Q18 opposition program | Q18 |
| Q19 Khashoggi | Q19 |
| Q20 Pérez (editors' note) | Q20 |
| "meet criticism in the U.S." | Q21 |
| "POL Northrop and Lockheed" | Q22 |
| paraphrases of d135, d215, d134, d583, d407, d161, d218, d219, d50 | §2.5 "Other passages" |
| vector neighbour d155 | VECTORS item 2 |
