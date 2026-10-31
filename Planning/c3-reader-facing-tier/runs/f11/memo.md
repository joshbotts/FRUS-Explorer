# Scope memo, run f11, 2026-10-31

Question: how did policymakers assess American soft power in the East Asia and Pacific region; what messaging strategies, how effective did they think they were, what beliefs about the regional audience lay behind them.
Operator memo. Every number in overview.md is traced in section 8. Every command is in queries.log; the scripts named here sit in this directory with their outputs.

## 0. Coverage and controls

Canary (first command) and read-only proof (second) both behaved as specified.

```sql
SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;
-- 553|321749|1103|8481
```

All counts below are conditional on this index: 553 volumes, the full series, so the partial-library caveat does not bite on volume coverage. It still bites on reading: I retrieved 52 documents whole out of 1,176 + 42 candidates, so every claim about "the officials" is a claim about the documents I read.

Positive control ("Department of State", 69 regional volumes, apparatus excluded): 13,470 documents, and none of the 76 candidate volumes in eap_core.txt returned zero (density.py). Negative control (ZZZ_IMPOSSIBLE_ZZZ): 0 in the same pass. Both run in the same pass in density.py and again in stats.py.

## 1. Scope chosen and how it was found

Inclusion rule. REGIONAL set (69 volumes): every volume whose manifest.json title names China, Japan, Korea, Vietnam, Indochina, Southeast Asia, East Asia, Northeast Asia, Pacific, Indonesia, Philippines, Laos, Cambodia, Malaysia, Taiwan or "Asia", dated 1948-1980, minus South Asia and Near East titles removed by name (frus1944v05, frus1948v05p1/p2, frus1949v06, frus1950v05, frus1952-54v11p1/p2, frus1955-57v08, frus1961-63v19, frus1964-68v25, frus1969-76v11, frus1969-76ve07, ve08, frus1977-80v19), minus the 1942-1947 China volumes and any Ed2 or Supp title (build_eap_list.py, eap_core.txt, scope_vols.txt). INFORMATION set (7 volumes): frus1917-72PubDipv06, v07, v08, frus1969-76v38p2, frus1977-80v30, frus1955-57v09, frus1961-63v25. Total scope 76 volumes. Second editions: none in scope, so the Ed2 rule was not triggered. Exclusions: is_front_matter=1 and is_editorial_note=1 throughout; cross_references not used (no is_broken filter needed).

How found. (1) manifest titles; (2) density.py ran one broad FTS family over each regional volume and ranked them by rate (that family included "propaganda", which in the Korea and Vietnam volumes mostly describes enemy propaganda, so I narrowed the family to American information work and did not use the density ranking to pick documents; the share of enemy propaganda was not measured); (3) the seven information volumes were found by title and then scanned by header (pd_headers.py, 42 rows); (4) ranked FTS queries (search.py) over scope_vols.txt for audience-belief, effectiveness, neutralism and prestige vocabulary, from which candidates were read; (5) vector neighbours of four anchors (section 6). I did NOT read the editors' chapter headings before writing queries (house rule), I read volume titles and document headers only.

Period. Periodised on document_dates.date_iso (the index's date for the document), not on the volume's series year. Start 1948 is a decision (overview, "Decisions").

Counting surface for every SQL count in this memo: the SQLite index (porter-stemmed full text, body_text including editorial footnotes). No [TEI] scan was run, so there are no spelling-variant, tag-stripped or word-bounded counts, and none is claimed. The phrase counts carry the literal-share check of section 2.

## 2. Measurements (audit forms)

Predicates used (python wrappers in stats.py, share.py, absent.py, density.py; "REG" = the 69 regional volumes listed in scope_vols.txt minus the 7 information volumes):

```sql
-- base predicate on every count
FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
WHERE d.volume_id IN (REG) AND d.is_front_matter=0 AND d.is_editorial_note=0
-- FAMILY A match string
frus_documents MATCH '(USIA OR USIS OR "Voice of America" OR "information program" OR "psychological warfare" OR "psychological strategy" OR "United States Information")'
```

(The rowid join is used only to join the FTS table to its content table inside the query; no rowid is reported as an identifier.)

Full output of stats.py:

```
REGIONAL volumes: 69 ; info/PD volumes: 7
SQL: select count(*) from document_cache d where volume_id in (REG) and is_front_matter=0 and is_editorial_note=0 -> 30092
SQL (family A): SELECT d.volume_id,d.document_id,dd.date_iso FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE frus_documents MATCH ? AND d.volume_id IN (REG...) AND d.is_front_matter=0 AND d.is_editorial_note=0 MATCH (USIA OR USIS OR "Voice of America" OR "information program" OR "psychological warfare" OR "psychological strategy" OR "United States Information")
family A hits in REG: 1176 of 30092
REG positive control 'Department of State' -> 13470
REG negative control ZZZ_IMPOSSIBLE_ZZZ -> 0
REG "soft power" -> 0
REG soft AND power -> 127
REG "public diplomacy" -> 2
REG "cultural diplomacy" -> 0
family A undated hits: 0
decade | hits | dated non-apparatus docs in REG | per 1,000 | top volume (share)
1940s | 303 | 6608 | 46 | frus1948v06 93 of 303
1950s | 395 | 12112 | 33 | frus1955-57v21 35 of 395
1960s | 414 | 7884 | 53 | frus1961-63v02 43 of 414
1970s | 63 | 3370 | 19 | frus1969-76v08 20 of 63
1980s | 1 | 106 | 9 | frus1977-80v22 1 of 1
control volumes (1948-80 non-scope): 201 docs 77265
FALSE-FRIEND 'audience OR audiences': REG 247 of 30092 (8.2 per 1,000) vs control 915 of 77265 (11.8 per 1,000)
FALSE-FRIEND 'USIS OR USIA': REG 790 of 30092 (26.3 per 1,000) vs control 1388 of 77265 (18.0 per 1,000)
FALSE-FRIEND 'propaganda': REG 2414 of 30092 (80.2 per 1,000) vs control 5434 of 77265 (70.3 per 1,000)
```

- N1. 69 regional volumes, 1948-1980. List in scope_vols.txt (first 69 lines are the regional ones; the last 7 are the information set).
- N2. 30,092 documents in REG: `SELECT count(*) FROM document_cache d WHERE volume_id IN (REG) AND is_front_matter=0 AND is_editorial_note=0` (stats.out line 2).
- N3. Family A: 1,176 of 30,092 documents in REG (one in 25.6). Counting surface: index.
- N4. 7 information volumes hold 1,582 non-apparatus documents: `SELECT count(*) FROM document_cache WHERE volume_id IN (7 volumes) AND is_front_matter=0 AND is_editorial_note=0` (final_numbers.out).
- N5. 42 documents in the information volumes whose header names an Asian or Pacific place or office: `frus_documents MATCH 'header:(Asia OR Asian OR "Far East" OR Vietnam OR Vietnamese OR Japan OR Japanese OR Korea OR Korean OR Indonesia OR Philippines OR Thailand OR China OR Chinese OR Taiwan OR Pacific OR Laos OR Cambodia OR Burma OR Malaysia OR Singapore OR Australia)'` restricted to the 7 volumes (pd_headers.py, pd_headers.out). This is a loose test: 9 of the 42 headers name South Asia or Near East offices (grep -c "South Asia|Near East" pd_headers.out = 9), and at least three are State Department documents, not USIA ones (frus1955-57v09/d131, frus1961-63v25/d179, d431). It is a finding aid, not a measured set.
- N6. Absences (REG, apparatus excluded): "soft power" 0, NEAR(soft power, 3) 0, "cultural diplomacy" 0, "Radio Free Asia" 0, "public diplomacy" 2. Relaxed form of the first that did return rows: `soft AND power` returned 127 documents (the two words anywhere in a document, mostly "soft" with unrelated "power"; not read). The corpus-wide first count (including front matter) was also 0 (initial term counts, run before the scope was set).
- N7. Asia Foundation 12, Peace Corps 59, "cultural exchange" 92, "educational exchange" 54, Fulbright 278 (mostly the Senator, not read, and not used) (absent.out).
- N8. 11 of 698 bundled series start before 1940 (one in 63.5): series-facts-index.json byNaId, field y0 (absent.out). The guide's figure was "about one in sixty"; this is the re-derived one.

### Phrase shares (house rule a and b)

```
PHRASE information program        FTS MATCH "information program"          hits in REG: 135 ; checked 135 (whole set) ; STRICT 80 of 135 ; TOLERANT 134 of 135
PHRASE psychological warfare      FTS MATCH "psychological warfare"        hits in REG: 252 ; checked 252 (whole set) ; STRICT 252 of 252 ; TOLERANT 252 of 252
PHRASE psychological strategy     FTS MATCH "psychological strategy"       hits in REG: 15 ; checked 15 (whole set) ; STRICT 15 of 15 ; TOLERANT 15 of 15
PHRASE United States Information  FTS MATCH "United States Information"    hits in REG: 114 ; checked 114 (whole set) ; STRICT 100 of 114 ; TOLERANT 101 of 114
```

For all four phrase families the whole set was under 300, so the whole set was checked, not a sample of 40. STRICT = single spaces; TOLERANT = each word with up to four extra letters, any run of space, hyphen, comma, parenthesis or full stop between. Case-insensitive Python `re` over header+dateline+source_note+body_text whitespace-collapsed; the FTS side is SQLite's case-insensitive stem match. The 13 misses for "United States Information" are "United States informed/inform/informal" (stem collision), so that family's tolerant share is 101 of 114 (0.886) and it was used only inside the mixed family A; the 1 miss for "information program" was read as a stem collision as well. Acronyms (USIA, USIS) are exact tokens in the index; Voice of America was not share-tested separately.

A 1.000 share tests the stemmer, not the referent. The referent test: every document quoted in the overview was read, and in each the phrase refers to American government information work.

### Decade shape (periodised on document_dates.date_iso; per 1,000 dated non-apparatus REG documents; numerator's top-volume share)

See the table at the end of stats.out above. The 1940s row's top volume (frus1948v06, 93 of 303) is large, and the 1980s row is one document dated 1980 in frus1977-80v22; neither is used. The overview uses 1950s 33, 1960s 53, 1970s 19 per thousand (this is N17) with the caveat in its text that single volumes carry much of each figure (top volume 35 of 395, 43 of 414, 20 of 63).

### False-friend tests (for terms the question or the method supplied; this is N16)

REG vs 201 control volumes (all 1948-1980 volumes not in scope, 77,265 documents): "audience OR audiences" 8.2 per thousand in REG against 11.8 in control, so "audience" is NOT a marker of the question and was not used; "USIS OR USIA" 26.3 per thousand against 18.0, only 1.5 times as common, so the acronym family does not by itself identify the region and the argument rests on documents read, not on this count; "propaganda" 80.2 against 70.3, also not specific, and it was dropped from family A after density.py showed it mostly describes enemy propaganda. ‘soft power’ is the question's own term and is absent (N6).

## 3. Reading accounting

Documents retrieved whole (captured length = length(body_text)): 52 of 52 files in docs/ (final_numbers.out: "dumped whole 52 of 52"). Reading SELECT (dump.py):

```sql
SELECT volume_id,document_id,header,dateline,source_note,body_text,length(body_text),is_front_matter,is_editorial_note
FROM document_cache WHERE volume_id=? AND document_id=?
```

Of the 52, I read some bodies to the end and the relevant passages (by position or by regex context, ctx.py) of the rest; I did not keep a count of which were read to the end. 25 documents are in the collection and are the ones I quote or rest an argument on; 36 excerpts in the collection; 23 quotations in the overview. A document not in docs/ was never read beyond a search snippet.

Documents read but not used, for the record: frus1917-72PubDipv06/d111, d112 (1963 press relations and Laos, whole), frus1917-72PubDipv08/d92 (Cambodia information vacuum, 1970), frus1917-72PubDipv07/d171 (educational television, 1967), frus1958-60v01/d26 (Durbrow reporting Diem's belief that Americans do not understand the Oriental mind; it is Diem's belief, not a US policymaker's, so it is not argued from), frus1961-63v04/d81, frus1961-63v02/d16, frus1949v07p2/d338, frus1958-60v18/d193, frus1977-80v30/d2 and frus1958-60v16/d12.

## 4. Quotations (each with its SELECT and id pair)

Overview quotation = text inside “ ” in overview.md; every one is a verbatim substring of its document's body_text after collapsing whitespace (check_overview.py). Spacing artefacts in the source (for example "ICA -funded") are preserved in the collection's excerpts. Excerpts in the collection are listed with their anchors in excerpts.out and re-verified by verify_collection.py.

| ID | volume_id/document_id | SELECT that retrieved it | check | text |
|---|---|---|---|---|
| Q1 | frus1917-72PubDipv07/d32 | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv07' AND document_id='d32'` | substring found after whitespace collapse: yes | “by other Vietnamese” |
| Q2 | frus1964-68v29p2/d46 | `SELECT body_text FROM document_cache WHERE volume_id='frus1964-68v29p2' AND document_id='d46'` | substring found after whitespace collapse: yes | “ostrich-like pacifism” |
| Q3 | frus1964-68v01/d197 | `SELECT body_text FROM document_cache WHERE volume_id='frus1964-68v01' AND document_id='d197'` | substring found after whitespace collapse: yes | “there is no conceivable information program that will make defeats look like victories” |
| Q4 | frus1949v07p2/d386 | `SELECT body_text FROM document_cache WHERE volume_id='frus1949v07p2' AND document_id='d386'` | substring found after whitespace collapse: yes | “A considerably expanded information program both in Communist and non-Communist areas of Asia is called for” |
| Q5 | frus1955-57v09/d189 | `SELECT body_text FROM document_cache WHERE volume_id='frus1955-57v09' AND document_id='d189'` | substring found after whitespace collapse: yes | “We can anticipate, too, an upsurge of neutralism. Our information program must energetically combat these tendencies.” |
| Q6 | frus1917-72PubDipv06/d135 | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv06' AND document_id='d135'` | substring found after whitespace collapse: yes | “avoiding a preoccupation with the negative side” |
| Q7 | frus1917-72PubDipv06/d135 | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv06' AND document_id='d135'` | substring found after whitespace collapse: yes | “our credibility on this negative aspect is relatively low” |
| Q8 | frus1950v06/d89 | `SELECT body_text FROM document_cache WHERE volume_id='frus1950v06' AND document_id='d89'` | substring found after whitespace collapse: yes | “At present we are talking over the heads of Southeast Asia, and doing so inadequately.” |
| Q9 | frus1958-60v16/d65 | `SELECT body_text FROM document_cache WHERE volume_id='frus1958-60v16' AND document_id='d65'` | substring found after whitespace collapse: yes | “relatively privileged positions” |
| Q10 | frus1917-72PubDipv07/d32 | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv07' AND document_id='d32'` | substring found after whitespace collapse: yes | “Vietnamese peasants are, in the main, going to be persuaded by other Vietnamese” |
| Q11 | frus1917-72PubDipv07/d32 | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv07' AND document_id='d32'` | substring found after whitespace collapse: yes | “family-oriented, selfish and opportunistic even in the best of times” |
| Q12 | frus1955-57v09/d190 | `SELECT body_text FROM document_cache WHERE volume_id='frus1955-57v09' AND document_id='d190'` | substring found after whitespace collapse: yes | “the national press remained generally unreceptive to explanatory material on U.S. policy and Communism” |
| Q13 | frus1955-57v09/d190 | `SELECT body_text FROM document_cache WHERE volume_id='frus1955-57v09' AND document_id='d190'` | substring found after whitespace collapse: yes | “a remarkable placement of material on the peaceful uses of atomic energy was achieved” |
| Q14 | frus1964-68v01/d197 | `SELECT body_text FROM document_cache WHERE volume_id='frus1964-68v01' AND document_id='d197'` | substring found after whitespace collapse: yes | “there is no conceivable information program that will make defeats look like victories, or GVN lassitude appear to be fiery enthusiasm” |
| Q15 | frus1917-72PubDipv07/d100 | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv07' AND document_id='d100'` | substring found after whitespace collapse: yes | “The image of a huge white nation attempting to suppress an Asian struggle for freedom.” |
| Q16 | frus1964-68v29p2/d46 | `SELECT body_text FROM document_cache WHERE volume_id='frus1964-68v29p2' AND document_id='d46'` | substring found after whitespace collapse: yes | “the basic emotional response remains unchanged and is probably unchangeable over the short run” |
| Q17 | frus1964-68v29p2/d123 | `SELECT body_text FROM document_cache WHERE volume_id='frus1964-68v29p2' AND document_id='d123'` | substring found after whitespace collapse: yes | “Racial violence and social unrest in America have roused concern over basic stability of American society” |
| Q18 | frus1917-72PubDipv08/d31 | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv08' AND document_id='d31'` | substring found after whitespace collapse: yes | “Asians are, to varying degrees, America watchers” |
| Q19 | frus1917-72PubDipv08/d31 | `SELECT body_text FROM document_cache WHERE volume_id='frus1917-72PubDipv08' AND document_id='d31'` | substring found after whitespace collapse: yes | “usually depended more on the state of bi-lateral relations” |
| Q20 | frus1969-76v38p2/d105 | `SELECT body_text FROM document_cache WHERE volume_id='frus1969-76v38p2' AND document_id='d105'` | substring found after whitespace collapse: yes | “The American defeat has been in good part written off by the Japanese since the US withdrawal two years ago” |
| Q21 | frus1969-76v38p2/d105 | `SELECT body_text FROM document_cache WHERE volume_id='frus1969-76v38p2' AND document_id='d105'` | substring found after whitespace collapse: yes | “very clearly in default” |
| Q22 | frus1977-80v30/d79 | `SELECT body_text FROM document_cache WHERE volume_id='frus1977-80v30' AND document_id='d79'` | substring found after whitespace collapse: yes | “shoring up the confidence of East Asians in America’s long-term staying power” |
| Q23 | frus1977-80v30/d83 | `SELECT body_text FROM document_cache WHERE volume_id='frus1977-80v30' AND document_id='d83'` | substring found after whitespace collapse: yes | “deeply implanted and persistent feeling” |

Verification outputs:

```
documents 25 excerpts 36 verified verbatim 36 failed 0
first entry kinds: ['heading', 'prose', 'document', 'excerpt', 'document', 'excerpt'] last: {'kind': 'generated', 'generatedBlockType': 'archivalSources'}
quotations 23 not found 0
distinct documents cited by URL: 25 ; not in collection: []
collection documents not cited in overview: []
id-like strings outside URLs: []
```

Facts stated in the overview that are not quotations but are read from a document: the 1950 mission report says white troops "will always be associated with colonialism" (frus1950v06/d89; retrieved by ctx.py on docs/frus1950v06__d89.txt, pattern "white troops will always"), Tokyo poll 49 to 40, 22 to 32 percent, with the 52 to 38 and 4 to 8 percent favourable and dislike figures (frus1964-68v29p2/d46), Saigon survey 637 adults, 26 percent and 23 percent college-educated (frus1917-72PubDipv08/d88), film audiences of 28 million (frus1964-68v01/d197), the 1957 Japan hedge (frus1955-57v09/d207), the Hong Kong and Japan abstracts (frus1969-76v38p2/d105).

## 5. Archival scope (labelled by channel, never summed)

[JSON] sources: manifest.json, central-files-index.json (lotFiles as a list keyed by lotNumber), series-facts-index.json (byNaId with one-letter keys per its legend; headings array), accession-series-index.json (byAccession, key "<record group>/<accession>"), collection-authority.json. Scripts: arch.py, lots.py, json_usia.py, acc.py, absent.py. [HARVEST] path: none was given, so the record-group harvest is unavailable and no count here comes from it.

CAME-FROM channel (document_sources, one row per document; volume set = the 7 information volumes, set A of 42 header-matched documents; and the 69 regional volumes, set B of 1,176 family-A documents).

```
SET A (PD/info volumes, header names an East Asia/Pacific place or office): 42 docs
SET B (regional volumes, family A): 1176 docs

CAME-FROM channel, Set A : documents with a document_sources row: 42 of 42
   4 ('National Archives', '306', 'Director’s Subject Files, Box 10')
   3 ('National Archives', '306', 'DIRCTR Files Bx 33–36, Box 33')
   2 ('National Archives', '306', 'DIRCTR Sub Files')
   2 ('Kennedy Library', None, 'National Security Files')
   2 ('National Archives', '306', 'Director’s Subject Files')
   2 ('National Archives', '306', 'Office of Policy and Plans')
   2 ('National Archives', '306', 'Director’s Subject Files, Box 22')
   2 ('National Archives', '59', 'Central Files 1960–63')
   1 ('National Archives', '306', 'Office of Plans')
   1 ('Kennedy Library', None, 'Personal Papers of Robert F.  Kennedy')
   1 ('National Archives', '306', 'DIRCTR Subj. Files, Box 16')
   1 ('National Archives', '306', None)

POINTED-AT channel, Set A : documents with >=1 external_citations row: 4 of 42 ; rows 4
   1 ('Kennedy Library', 'National Security Files', 'presidentialLibrary')
   1 ('Johnson Library', 'Marks Papers', 'presidentialLibrary')
   1 ('Nixon Presidential Materials', 'Kissinger Office Files', 'presidentialLibrary')
   1 ('Department of State', None, 'lotFile')

CAME-FROM channel, Set B : documents with a document_sources row: 1176 of 1176
   118 ('Department of State', '59', None)
   67 ('Johnson Library', None, 'National Security File')
   39 ('Kennedy Library', None, 'National Security Files')
   39 ('Nixon Presidential Materials', None, 'NSC Files')
   17 ('National Archives', '59', 'Central Files 1964–66')
   13 ('Eisenhower Library', None, 'Eisenhower papers')
   13 ('Central Intelligence Agency', None, None)
   11 ('Department of State', '59', 'POL 27 VIET S')
   10 ('National Defense University', None, 'Taylor Papers')
   9 ('Library of Congress', None, 'Manuscript Division')
   9 ('National Archives', '59', 'Central Files 1967–69')
   8 ('Eisenhower Library', None, 'Whitman File')

POINTED-AT channel, Set B : documents with >=1 external_citations row: 322 of 1176 ; rows 551
   296 ('Department of State', None, 'centralFileClass')
   134 ('Department of State', None, 'lotFile')
   36 ('Johnson Library', 'National Security File', 'presidentialLibrary')
   25 ('Nixon Presidential Materials', 'NSC Files', 'presidentialLibrary')
   18 ('Kennedy Library', 'National Security Files', 'presidentialLibrary')
   5 ('Johnson Library', 'President’s Daily Diary', 'presidentialLibrary')
   3 ('Eisenhower Library', 'Eisenhower papers', 'presidentialLibrary')
   3 ('Eisenhower Library', 'Whitman File', 'presidentialLibrary')
   3 ('Kennedy Library', 'President’s Office Files', 'presidentialLibrary')
   3 ('Johnson Library', 'Rusk Appointment Book', 'presidentialLibrary')
   3 ('Johnson Library', 'Ball Papers', 'presidentialLibrary')
   2 ('Eisenhower Library', 'indicates that Eisenhower raised “one or two questions” about the draft of the speech sent to him', 'presidentialLibrary')
```

Set A by record group (document_sources.record_group): RG 306: 27 of 42; RG 59: 8; RG 305: 1; none recorded (libraries): 6. Entries printed in the source notes of documents I quote: RG 306 Director's Subject Files 1968-1972, Entry A1-42 (frus1917-72PubDipv08/d88, d149); Office of Policy and Plans, Entry P-207 (d31); DIRCTR Sub Files 1963-69 Acc 72A5121 Entry UD WW 257 (frus1917-72PubDipv06/d111, d112 and others; source line quoted from document_sources.raw_text); Director's office Executive Secretariat Correspondence Files 1973-1980 Entry P-104 (frus1977-80v30/d79). Resolution against the bundled stack: none of A1-42, UD WW 257, P-207, UD WW 193 or P-104 occurs in any bundled JSON (grep -F over all *.json; P-104 matched only "P 1047", another series). accession-series-index.json matches 306/72A5121 and 306/69A3445 and 306/68A4933 to many NAIDs each (4,750 accession keys in the file); that is accession level, not entry level, so no single shelf is resolved. The two series named in the overview are candidates by creator only: NAID 40967285 (creator "U.S. Information Agency. Office of the Director. Executive Secretariat.", 103 linear feet 1 inch, 1956-1972, access "Restricted - Partly") and NAID 1257679 (creator "U.S. Information Agency. Office of Policy and Plans.", 47 linear feet, 1953-1971, "Restricted - Partly"). NARA's creator attribution is a decoy surface; neither is verified against the boxes cited. The Office of Research and Intelligence series, NAID 1254251 (9 linear feet 2 inches, 1954-1958, "Restricted - Partly"), is named in the overview as the nearest bundled research series, same caveat.

POINTED-AT channel (external_citations; volume set = the 69 regional volumes; documents = set B). The channel has no row before 1910-12-06 (not relevant here), stores the citation fragment and not the sentence, and holds lot, library and decimal anchors only. Output above: 322 of 1,176 documents have at least one row; 551 rows, of which centralFileClass 296, lotFile 134, presidentialLibrary 121 (36 Johnson NSF, 25 Nixon NSC Files, 18 Kennedy NSF, others). Lots resolved through central-files-index.json and series-facts-index.json:

```
SET A (PD/info volumes, header names an East Asia/Pacific place or office): 42 docs
SET B (regional volumes, family A): 1176 docs

CAME-FROM (document_sources.lot_file_norm), Set A: distinct lots 1
  lot 81D5       docs   1 | central-files-index: 59 NAID 6862866 Records of Under Secretary of State Philip C. Habib | facts: {'creator': 'Department of State. Office of the Under Secretary of State for Political Affairs.', 'extent': '9 linear feet, 2 linear inches', 'years': '1974-1978', 'access': 'Restricted - Partly'}

CAME-FROM (document_sources.lot_file_norm), Set B: distinct lots 57
  lot 63D351     docs  19 | central-files-index: 59 NAID 2839192 Records Relating to National Security Council Policy Papers | facts: {'creator': 'Department of State. Office of the Secretary. Executive Secretariat.', 'extent': '26 linear feet, 3 linear inches', 'years': '1947-1979', 'access': 'Restricted - Partly'}
  lot 62D430     docs  12 | central-files-index: 59 NAID 2839191 Subject and Special Files | facts: {'creator': 'Department of State. Executive Secretariat.', 'extent': '4 linear feet, 5 linear inches', 'years': '1953-1961', 'access': 'Restricted - Partly'}
  lot 61D417     docs   8 | central-files-index: 59 NAID 2103073 Meeting Summaries and Project Files | facts: {'creator': 'Department of State. Executive Secretariat.', 'extent': '2 linear feet, 7 linear inches', 'years': '1951-1959', 'access': 'Unrestricted'}
  lot 61D385     docs   7 | central-files-index: NOT IN INDEX | facts: None
  lot 67D54      docs   7 | central-files-index: 59 NAID 631403 Subject Files of the Vietnam Working Group | facts: {'creator': 'Department of State. Bureau of East Asian and Pacific Affairs.', 'extent': '21 linear feet', 'years': '1963-1974', 'access': 'Unrestricted'}
  lot 66D193     docs   6 | central-files-index: 59 NAID 2658382 Subject Files Relating to Political, Military, Economic Aid, | facts: {'creator': 'Department of State. Bureau of Far Eastern Affairs.', 'extent': '5 linear feet, 7 linear inches', 'years': '1955-1962', 'access': 'Restricted - Possibly'}
  lot 61D167     docs   4 | central-files-index: 59 NAID 2198167 Alphabetical Files | facts: {'creator': 'Department of State. Policy Planning Council.', 'extent': '48 linear feet, 7 linear inches', 'years': '1948-1961', 'access': 'Restricted - Partly'}
  lot 58D207     docs   4 | central-files-index: 59 NAID 2103059 Subject Files | facts: {'creator': 'Department of State. Bureau of Far Eastern Affairs. Office of Philippine and Southeast Asian Affairs. Office of the Director.', 'extent': '8 linear inches', 'years': '1950-1956', 'access': 'Restricted - Partly'}
  lot 59D95      docs   3 | central-files-index: NOT IN INDEX | facts: None
  lot 72D316     docs   3 | central-files-index: 59 NAID 603185 National Security Action Memorandum Files | facts: {'creator': 'Department of State. Office of the Secretary. Executive Secretariat.', 'extent': '3 linear feet, 11 linear inches', 'years': '1961-1968', 'access': 'Unrestricted'}
  lot 68D451     docs   3 | central-files-index: 59 NAID 622921 Records of the Special Group on Counter Insurgency | facts: {'creator': 'Department of State. Office of the Secretary. Executive Secretariat.', 'extent': '3 linear feet, 11 linear inches', 'years': '1962-1966', 'access': 'Unrestricted'}
  lot 70D199     docs   3 | central-files-index: 59 NAID 604801 Subject Files | facts: {'creator': 'Department of State. Planning and Coordination Staff.', 'extent': '33 linear feet, 8 linear inches', 'years': '1963-1973', 'access': 'Unrestricted'}
  lot 53D250     docs   2 | central-files-index: NOT IN INDEX | facts: None
  lot 64D563     docs   2 | central-files-index: 59 NAID 1136548 Chronological Files | facts: {'creator': 'Department of State. Policy Planning Council.', 'extent': '5 linear feet, 3 linear inches', 'years': '1947-1962', 'access': 'Unrestricted'}

POINTED-AT (external_citations.lot_file_norm), Set B: distinct lots 49
  lot 66D95      docs  17 | central-files-index: 59 NAID 2839192 Records Relating to National Security Council Policy Papers | facts: {'creator': 'Department of State. Office of the Secretary. Executive Secretariat.', 'extent': '26 linear feet, 3 linear inches', 'years': '1947-1979', 'access': 'Restricted - Partly'}
  lot 62D430     docs  11 | central-files-index: 59 NAID 2839191 Subject and Special Files | facts: {'creator': 'Department of State. Executive Secretariat.', 'extent': '4 linear feet, 5 linear inches', 'years': '1953-1961', 'access': 'Restricted - Partly'}
  lot 63D351     docs   9 | central-files-index: 59 NAID 2839192 Records Relating to National Security Council Policy Papers | facts: {'creator': 'Department of State. Office of the Secretary. Executive Secretariat.', 'extent': '26 linear feet, 3 linear inches', 'years': '1947-1979', 'access': 'Restricted - Partly'}
  lot 62D1       docs   7 | central-files-index: 59 NAID 2838992 Records Relating to Activities with the National Security Co | facts: {'creator': 'Department of State. Policy Planning Council.', 'extent': '3 linear feet, 1 linear inch', 'years': '1948-1961', 'access': 'Restricted - Partly'}
  lot 62D181     docs   4 | central-files-index: NOT IN INDEX | facts: None
  lot 80D212     docs   2 | central-files-index: 59 NAID 2990007 National Security Council National Security Study Memorandum | facts: {'creator': 'Department of State. Office of the Secretary. Executive Secretariat.', 'extent': '17 linear feet', 'years': '1967-1977', 'access': 'Restricted - Fully'}
  lot 74D417     docs   1 | central-files-index: 84 NAID 588795 Files of Ambassador Ellsworth Bunker | facts: {'creator': 'Department of State. U.S. Embassy, South Vietnam. Office of the Ambassador.', 'extent': '3 linear feet', 'years': '1967-1973', 'access': 'Unrestricted'}
  lot 55D128     docs   2 | central-files-index: 59 NAID 2127218 Records Related to the Korean War | facts: {'creator': 'Department of State. Bureau of Far Eastern Affairs.', 'extent': '3 linear feet, 6 linear inches', 'years': '1950-1952', 'access': 'Restricted - Partly'}
  lot 64D563     docs   3 | central-files-index: 59 NAID 1136548 Chronological Files | facts: {'creator': 'Department of State. Policy Planning Council.', 'extent': '5 linear feet, 3 linear inches', 'years': '1947-1962', 'access': 'Unrestricted'}
  lot 61D385     docs   3 | central-files-index: NOT IN INDEX | facts: None
  lot 67D54      docs   2 | central-files-index: 59 NAID 631403 Subject Files of the Vietnam Working Group | facts: {'creator': 'Department of State. Bureau of East Asian and Pacific Affairs.', 'extent': '21 linear feet', 'years': '1963-1974', 'access': 'Unrestricted'}
  lot 54D423     docs   1 | central-files-index: 59 NAID 2127217 Japanese Petitions | facts: {'creator': 'Department of State. Bureau of Far Eastern Affairs. Office of Northeast Asian Affairs.', 'extent': '5 linear feet, 6 linear inches', 'years': '1951-1954', 'access': 'Unrestricted'}
  lot 60D627     docs   2 | central-files-index: NOT IN INDEX | facts: None
  lot 65D101     docs   2 | central-files-index: 59 NAID 1136548 Chronological Files | facts: {'creator': 'Department of State. Policy Planning Council.', 'extent': '5 linear feet, 3 linear inches', 'years': '1947-1962', 'access': 'Unrestricted'}
```

The came-from and pointed-at counts are over different documents and different sets and are not added anywhere.

## 6. VECTORS

Artifacts: semantic-vectors-index.json, semantic-vectors-binary.bin, semantic-map.bin, semantic-map-index.json, semantic-shards-manifest.json in the app bundle, and the 553 .vec shards in /Users/jbotts/frus-analysis/c3/SemanticVectors/. Provenance digest 89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101 compared across the index, the corpus binary (offset 20), the map (offset 20), the shard folder's .generation file, the shard manifest, and the header of every one of 553 shards (offset 16): identical, 0 mismatches. Index generated 2026-10-15, harvestGenerated 2026-10-15T06:55:14; measuredRecallAt10 0.9021 (so absence of a neighbour is not evidence of absence); scoreCalibration documentOffset 0.40 (scale 0.60 for document-to-document), queryOffset 0.47 (no query was embedded; no embedder). Identity from the index's segments only (decode of section A.3, 553 of 553 volumes round-trip, 314,616 rows). The Python-3.9 form `bin(x).count("1")` was not needed: numpy `bitwise_count` was used.

```
index digest 89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101
binary digest 89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101 dims 512 docs 314616 cents 660
map digest 89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101
shard .generation 89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101
shard manifest keys ['generated', 'provenanceDigest', 'schema', 'shards', 'shippingDims']
  generated 2026-10-15
  provenanceDigest 89481b1869da1880c599a6923df9a90bef19fc402c3db5a370ead2809b7e6101
  schema 1
  shippingDims 512
shards checked 553 digest mismatches 0
volumes round-trip ok 553 of 553 rows 314616
random pairs: mean 167.1 sd 14.8 p1 132 min 95
scoreCalibration {'documentOffset': 0.4, 'measuredBy': "Planning/semantic-vectors/EmbeddingGemma-2-B4-Move-2026-10-15.md §1b, fitted to EmbeddingGemma 300m's scores over 90 typed queries and 600 anchor documents against the 314,616-document corpus", 'queryOffset': 0.47}
measuredRecallAt10 0.9021 generated 2026-10-15 harvestGenerated 2026-10-15T06:55:14
```

Operations run (each with anchor, file, baseline, finding):

1. Nearest neighbours of a document. Anchors: frus1917-72PubDipv08/d31 (Manila PAO conference, 1969), frus1969-76v38p2/d105 (1975 East Asia reassessment), frus1964-68v29p2/d46 (Reischauer, 1965), frus1917-72PubDipv07/d100 (Marks, 1966). File: semantic-vectors-binary.bin sign bits (Hamming over 512 bits), reranked for display by int8 cosine from the .vec shards, shown raw and as (cos-0.40)/0.60. Baselines, both at this digest: random pairs (20,000, seed 1877) mean 167.1, sd 14.8, 1st percentile 132, minimum 95; and the k-th neighbour distribution over a 200-document sample (seed 1877): 25th neighbour median 108 (quartiles 101 and 114), nearest neighbour median 82 (quartiles 71 and 92). Every neighbour listed is far inside random-pair chance, and the nearest neighbours (76 to 94) sit at ordinary nearest-neighbour distances, not unusual ones; the anchor of 1975 has a 25th neighbour at 90 against a median 108, so it sits in a dense area. Findings: neighbours are suggestions. No neighbour was outside document_cache (all in_db=True). Output:

```
BASELINE 200-doc sample (seed 1877): 25th-neighbour median 108 quartiles 101/114 ; nearest-neighbour median 82, quartiles 71/92

ANCHOR frus1917-72PubDipv08/d31 25th-neighbour distance 98 nearest 81
  ham  81  frus1917-72PubDipv07/d106  rawcos 0.920 calibrated 87%  in_db=True  106. Minutes of a Meeting of the President’s General Advisory Committee on Foreign Assista
  ham  86  frus1917-72PubDipv06/d3  rawcos 0.899 calibrated 83%  in_db=True  3. Report Prepared by Deputy Director-Designate Donald M. Wilson
  ham  88  frus1917-72PubDipv06/d5  rawcos 0.894 calibrated 82%  in_db=True  5. Report Prepared by the Task Force on the United States Information Agency
  ham  88  frus1952-54v13p1/d116  rawcos 0.906 calibrated 84%  in_db=True  The Ambassador at Saigon (Heath) to the Department of State
  ham  89  frus1955-57v22/d275  rawcos 0.850 calibrated 75%  in_db=True  275. Telegram From the Embassy in Indonesia to the Department of State
  ham  90  frus1917-72PubDipv08/d99  rawcos 0.915 calibrated 86%  in_db=True  99. Paper Prepared in the United States Information Agency
  ham  90  frus1950v06/d9  rawcos 0.902 calibrated 84%  in_db=True  Editorial Note
  ham  91  frus1958-60v16/d65  rawcos 0.876 calibrated 79%  in_db=True  65. National Security Council Report
  ham  92  frus1917-72PubDipv07/d140  rawcos 0.897 calibrated 83%  in_db=True  140. Letter From the Director of the United States Information Agency (Marks) to All Unite
  ham  92  frus1952-54v02p2/d374  rawcos 0.891 calibrated 82%  in_db=True  Memorandum for the National Security Council by the Executive Secretary (Lay)
  ham  92  frus1977-80v30/d68  rawcos 0.902 calibrated 84%  in_db=True  68. Memorandum From the Director of the United States Information Agency (Reinhardt) to al
  ham  94  frus1951v06p1/d12  rawcos 0.888 calibrated 81%  in_db=True  Report to the National Security Council by the Executive Secretary (Lay)

ANCHOR frus1969-76v38p2/d105 25th-neighbour distance 90 nearest 76
  ham  76  frus1969-76ve12/d10  rawcos 0.910 calibrated 85%  in_db=True  10. Memorandum From W.R. Smyser of the National Security Council Staff to Secretary of Sta
  ham  77  frus1958-60v16/d65  rawcos 0.896 calibrated 83%  in_db=True  65. National Security Council Report
  ham  78  frus1969-76v01/d54  rawcos 0.922 calibrated 87%  in_db=True  54. Paper Prepared in the National Security Council Staff
  ham  80  frus1969-76ve12/d16  rawcos 0.913 calibrated 85%  in_db=True  16. Memorandum From Secretary of State Kissinger to President Ford, Washington, June 13, 1
  ham  82  frus1969-76ve12/d15  rawcos 0.890 calibrated 82%  in_db=True  15. Minutes of the Acting Secretary of State’s Staff Meeting, Washington, June 13, 1975, 8
  ham  82  frus1977-80v22/d104  rawcos 0.915 calibrated 86%  in_db=True  104. Telegram From the Consulate in Hong Kong to the Department of State
  ham  84  frus1949v07p2/d387  rawcos 0.887 calibrated 81%  in_db=True  Memorandum by the Executive Secretary of the National Security Council (Souers) to the Nat
  ham  84  frus1955-57v21/d119  rawcos 0.891 calibrated 82%  in_db=True  119. National Security Council Report
  ham  84  frus1969-76v38p1/d54  rawcos 0.918 calibrated 86%  in_db=True  54. Memorandum From the Counselor of the Department of State (Sonnenfeldt) and the Directo
  ham  85  frus1949v07p2/d386  rawcos 0.894 calibrated 82%  in_db=True  Memorandum by the Ambassador at Large (Jessup) to the Secretary of State
  ham  85  frus1958-60v16/d12  rawcos 0.892 calibrated 82%  in_db=True  12. National Security Council Report
  ham  85  frus1969-76v38p1/d58  rawcos 0.896 calibrated 83%  in_db=True  58. Telegram From the Department of State to All Diplomatic and Consular Posts

ANCHOR frus1964-68v29p2/d46 25th-neighbour distance 110 nearest 94
  ham  94  frus1958-60v18/d203  rawcos 0.892 calibrated 82%  in_db=True  203. Telegram From the Embassy in Japan to the Department of State
  ham  95  frus1961-63v03/d226  rawcos 0.856 calibrated 76%  in_db=True  226. Memorandum of Conversation
  ham 101  frus1917-72PubDipv07/d100  rawcos 0.867 calibrated 78%  in_db=True  100. Memorandum From the Director of the United States Information Agency (Marks) to the P
  ham 102  frus1964-68v03/d110  rawcos 0.859 calibrated 77%  in_db=True  110. Summary Notes of the 554th Meeting of the National Security Council
  ham 103  frus1964-68v04/d100  rawcos 0.877 calibrated 79%  in_db=True  100. Telegram From the Embassy in Vietnam to the Department of State
  ham 105  frus1961-63v02/d325  rawcos 0.827 calibrated 71%  in_db=True  325. Letter From the Director of the Vietnam Working Group (Wood) to the Ambassador in Vie
  ham 105  frus1964-68v04/d239  rawcos 0.832 calibrated 72%  in_db=True  239. Memorandum From the Presidentʼs Special Assistant (Rostow) to President Johnson
  ham 105  frus1969-76v11/d151  rawcos 0.827 calibrated 71%  in_db=True  151. Telegram From the Embassy in India to the Department of State
  ham 105  frus1981-88v01/d239  rawcos 0.853 calibrated 75%  in_db=True  239. Address by Secretary of State Shultz
  ham 106  frus1961-63v03/d239  rawcos 0.851 calibrated 75%  in_db=True  239. Report From the Assistant Secretary of State for Public Affairs (Manning) to the Pres
  ham 106  frus1964-68v29p2/d123  rawcos 0.894 calibrated 82%  in_db=True  123. Telegram From the Embassy in Japan to the Department of State
  ham 107  frus1961-63v03/d277  rawcos 0.846 calibrated 74%  in_db=True  277. Memorandum From the Counselor for Public Affairs of the Embassy in Vietnam (Mecklin) 

ANCHOR frus1917-72PubDipv07/d100 25th-neighbour distance 99 nearest 89
  ham  89  frus1917-72PubDipv07/d176  rawcos 0.856 calibrated 76%  in_db=True  176. Memorandum From the Director of the United States Information Agency (Marks) to Presi
  ham  92  frus1917-72PubDipv08/d17  rawcos 0.892 calibrated 82%  in_db=True  17. Memorandum From the Deputy Director for Policy and Research, United States Information
  ham  92  frus1961-63v01/d210  rawcos 0.869 calibrated 78%  in_db=True  210. Letter From the President’s Military Representative (Taylor) to the President
  ham  93  frus1917-72PubDipv07/d157  rawcos 0.880 calibrated 80%  in_db=True  157. Memorandum From the Director of the United States Information Agency (Marks) to Presi
  ham  95  frus1917-72PubDipv07/d71  rawcos 0.881 calibrated 80%  in_db=True  71. Memorandum From the Director of the United States Information Agency (Marks) to Presid
  ham  95  frus1917-72PubDipv07/d169  rawcos 0.876 calibrated 79%  in_db=True  169. Memorandum From the Director of the United States Information Agency (Marks) to Presi
  ham  95  frus1917-72PubDipv08/d66  rawcos 0.855 calibrated 76%  in_db=True  66. Memorandum From the Acting Director of the United States Information Agency (Loomis) t
  ham  95  frus1958-60v01/d47  rawcos 0.857 calibrated 76%  in_db=True  47. Paper Prepared by the Operations Coordinating Board
  ham  95  frus1958-60v01/d147  rawcos 0.882 calibrated 80%  in_db=True  147. Paper Prepared by the Operations Coordinating Board
  ham  95  frus1961-63v03/d19  rawcos 0.872 calibrated 79%  in_db=True  19. Memorandum From the Director of the Bureau of Intelligence and Research (Hilsman) and 
  ham  95  frus1961-63v04/d115  rawcos 0.870 calibrated 78%  in_db=True  115. Draft Letter From President Kennedy to President Diem
  ham  96  frus1964-68v01/d197  rawcos 0.853 calibrated 75%  in_db=True  197. Memorandum From the Director of the United States Information Agency (Rowan) to the P
```

2. Semantic join. Top 60 Hamming neighbours of frus1969-76v38p2/d105 joined to document_dates and document_sources (vec_ops2.py). Result in vec_ops2.out below: by decade 1940s 2, 1950s 24, 1960s 14, 1970s 19, 1980s 1; came-from, the six largest groups: State Department files recorded under RG 59 (32 as "Department of State" and 8 as "National Archives"), Ford Library 5, none recorded 4, Nixon Presidential Materials 3, Carter Library 2; 11 of the 60 lie outside the 76-volume scope. It says the neighbours of a 1975 USIA reassessment are mostly NSC-level and State policy papers from the 1950s onward, not other USIA reports.
3. Centroid similarity. Anchor: the centroid of frus1917-72PubDipv08 (and frus1977-80v30, frus1964-68v27), from the centroid block of the corpus binary; baseline: 5,000 random volume pairs, mean cosine 0.905, sd 0.032, 99th percentile 0.974 (raw cosines, not calibrated). Volume nearest PubDipv08: PubDipv07 0.981, PubDipv06 0.977, frus1977-80v30 0.976, frus1969-76v38p2 0.965. Nearest to frus1964-68v27: frus1961-63v23 0.980, frus1969-76v20 0.976. Finding: the public-diplomacy volumes are each other's nearest volumes, as expected. numpy printed divide-by-zero/overflow matmul warnings on the float32 product; the results are plausible and the order stable, but I did not investigate the warning.
4. The map. Cluster and label of each of the 25 collection documents (semantic-map.bin, semantic-map-index.json), in vec_ops2.out. Cluster 29 (terms lao, vietnamese, vietnam, thieu) holds 9 of the 25, cluster 7 (japanese, sato, japan, kishi) 2, cluster 20 (grc, formosa, chiang, taiwan) 2, cluster 138 (cia, nsc, usia, inglis) 2, clusters 115 and 103 one each. Unclustered: 8 of 25 (32%) against 18.3% for all 33,206 rows of the 76 scope volumes (apparatus included, so only a rough era-matched baseline) and 28.0% corpus-wide (88,059 of 314,616). The collection is somewhat more often unclustered than its volumes, which fits long policy memoranda that mix topics; no figure in the overview rests on clusters.
5. Near-duplicates. All 300 pairs among the 25 collection documents: closest pair 50 (frus1955-57v09/d190 and d207, two successive National Security Council reports on the same programme, not copies), then 70, 76, 77, 79; median pair 129. No reprint pair among them; the guide's reprint threshold was not given to me, so I read the closest pair and they are different documents.

Documents in the overview reached through a vector operation and through no full-text query I read: frus1977-80v22/d104 (it matches none of the three ranked queries run in search.py) and frus1969-76ve12/d10 (it matches the broad ranked query at rank 505 of 1,665, beyond the 25 I read, and so was in practice reached by the vector operation). Both are neighbours of frus1969-76v38p2/d105 (distance 82 and 76; raw cosine 0.915 and 0.910; calibrated 86% and 85%, between two documents). Every other document in the overview was found by a full-text query or by header scan. The other vector neighbours were listed and mostly not read.

```
== CENTROID SIMILARITY (semantic-vectors-binary.bin centroid block; first 553 = volumes in index order; raw cosine; random-volume-pair baseline below)
baseline random volume pairs: mean 0.905 sd 0.032 p99 0.974
/Users/jbotts/frus-analysis/c3f/runs/f11/vec_ops2.py:21: RuntimeWarning: divide by zero encountered in matmul
  i=vl.index(a); s=C[:553]@C[i]; s[i]=-1; o=np.argsort(-s)[:8]
/Users/jbotts/frus-analysis/c3f/runs/f11/vec_ops2.py:21: RuntimeWarning: overflow encountered in matmul
  i=vl.index(a); s=C[:553]@C[i]; s[i]=-1; o=np.argsort(-s)[:8]
/Users/jbotts/frus-analysis/c3f/runs/f11/vec_ops2.py:21: RuntimeWarning: invalid value encountered in matmul
  i=vl.index(a); s=C[:553]@C[i]; s[i]=-1; o=np.argsort(-s)[:8]
frus1917-72PubDipv08 -> [('frus1917-72PubDipv07', 0.981), ('frus1917-72PubDipv06', 0.977), ('frus1977-80v30', 0.976), ('frus1969-76v38p2', 0.965), ('frus1969-76v02', 0.962), ('frus1961-63v25', 0.962), ('frus1964-68v33', 0.961), ('frus1969-76ve01', 0.961)]
frus1977-80v30 -> [('frus1917-72PubDipv08', 0.976), ('frus1917-72PubDipv07', 0.973), ('frus1917-72PubDipv06', 0.97), ('frus1977-80v28', 0.962), ('frus1969-76v38p2', 0.961), ('frus1977-80v20', 0.956), ('frus1961-63v25', 0.955), ('frus1977-80v02', 0.953)]
frus1964-68v27 -> [('frus1961-63v23', 0.98), ('frus1969-76v20', 0.976), ('frus1964-68v01', 0.973), ('frus1964-68v02', 0.971), ('frus1977-80v22', 0.971), ('frus1955-57v21', 0.971), ('frus1958-60v16', 0.969), ('frus1964-68v04', 0.968)]

== MAP (semantic-map.bin placements; cluster labels from semantic-map-index.json)
map-index keys ['clusters', 'documentCount', 'generated', 'gridExtent', 'layout', 'provenanceDigest', 'schema']
corpus unclustered: 88059 of 314616 (28.0%)
  frus1949v07p2/d386 cluster 20 ['grc', 'formosa', 'chiang', 'taiwan']
  frus1952-54v12p2/d403 cluster 29 ['lao', 'vietnamese', 'vietnam', 'thieu']
  frus1955-57v09/d189 cluster 115 ['edc', 'nato', 'nuclear', 'soviet']
  frus1917-72PubDipv06/d135 cluster 20 ['grc', 'formosa', 'chiang', 'taiwan']
  frus1917-72PubDipv08/d24 cluster 29 ['lao', 'vietnamese', 'vietnam', 'thieu']
  frus1950v06/d89 cluster UNCLUSTERED 
  frus1958-60v16/d65 cluster 29 ['lao', 'vietnamese', 'vietnam', 'thieu']
  frus1917-72PubDipv07/d32 cluster 29 ['lao', 'vietnamese', 'vietnam', 'thieu']
  frus1964-68v29p2/d46 cluster 7 ['japanese', 'sato', 'japan', 'kishi']
  frus1955-57v09/d190 cluster 138 ['cia', 'nsc', 'usia', 'inglis']
  frus1955-57v09/d207 cluster UNCLUSTERED 
  frus1964-68v01/d197 cluster 29 ['lao', 'vietnamese', 'vietnam', 'thieu']
  frus1917-72PubDipv07/d73 cluster 29 ['lao', 'vietnamese', 'vietnam', 'thieu']
  frus1917-72PubDipv07/d100 cluster 29 ['lao', 'vietnamese', 'vietnam', 'thieu']
  frus1917-72PubDipv08/d88 cluster 29 ['lao', 'vietnamese', 'vietnam', 'thieu']
  frus1964-68v29p2/d123 cluster 7 ['japanese', 'sato', 'japan', 'kishi']
  frus1917-72PubDipv08/d31 cluster UNCLUSTERED 
  frus1917-72PubDipv08/d149 cluster UNCLUSTERED 
  frus1969-76ve12/d10 cluster 29 ['lao', 'vietnamese', 'vietnam', 'thieu']
  frus1969-76v38p2/d105 cluster UNCLUSTERED 
  frus1977-80v22/d104 cluster UNCLUSTERED 
  frus1977-80v30/d79 cluster UNCLUSTERED 
  frus1977-80v30/d81 cluster 138 ['cia', 'nsc', 'usia', 'inglis']
  frus1977-80v30/d83 cluster UNCLUSTERED 
  frus1977-80v30/d152 cluster 103 ['kissinger', 'chou', 'taiwan', 'huang']
collection unclustered: 8 of 25
scope-volume baseline (76 volumes, all rows incl. apparatus): unclustered 6079 of 33206 (18.3%)

== SEMANTIC JOIN: top-60 Hamming neighbours of frus1969-76v38p2/d105 into document_dates and document_sources
decades: [('1940s', 2), ('1950s', 24), ('1960s', 14), ('1970s', 19), ('1980s', 1)]
came-from (repository, RG): [(('Department of State', '59'), 32), (('National Archives', '59'), 8), (('Ford Library', None), 5), ((None, None), 4), (('Nixon Presidential Materials', None), 3), (('Carter Library', None), 2)]
not in db: 0 ; outside the 76-volume scope: 11 ; nearest 76 60th 96

== NEAR-DUPLICATE SCAN among the 25 collection documents (min Hamming over all pairs)
closest 5 pairs: [(50, ('frus1955-57v09', 'd190'), ('frus1955-57v09', 'd207')), (70, ('frus1949v07p2', 'd386'), ('frus1958-60v16', 'd65')), (76, ('frus1969-76ve12', 'd10'), ('frus1969-76v38p2', 'd105')), (77, ('frus1958-60v16', 'd65'), ('frus1969-76v38p2', 'd105')), (79, ('frus1950v06', 'd89'), ('frus1958-60v16', 'd65'))]
median pair distance 129.0
```

## 7. Caveats and threads not followed

- The documents are US government writing; the audience's views are the officials' reports of them. The overview says so.
- 52 documents read whole against a candidate pool of 1,176 + 42: any statement about officials in general is a sample. Thin areas: Korea after 1960, the Philippines, Indonesia, Australia and New Zealand, the Voice of America's audience in China, exchange programs.
- Fulbright counts mix the Senator and the program; not used.
- Family A does not include "propaganda"; its 1940s mass is partly "United States Information" (tolerant share 0.886).
- Exclusions: second editions none in scope; South Asia and Near East volumes excluded by name; 1942-1947 China volumes not searched.
- No second pass was possible.

## 8. TRACE TABLE (overview item -> memo line)

| Overview item | Where in the overview | Memo line |
|---|---|---|
| 'soft power' in none of 30,092 documents of 69 volumes | Bottom line 1; Bottom line 3 | N6, N2, N1 (section 2) |
| 25 documents from 1949 to 1978 | Bottom line 1; Read next | section 4 table; verify_collection.out |
| 1955 report reported placements (a fact read from document, not a quotation) | Bottom line 1; Finding 3 | Q row for d190 (section 4) |
| 27 of 42 from RG 306; 42 headings | Bottom line 2 | N5, section 5 (Set A record group counts) |
| Entries A1-42, UD WW 257, 72 A 5121, P-207, P-104 | Bottom line 2 | section 5 (entries printed in source notes) |
| NAID 40967285, 103 ft, 1956-1972, partly restricted; NAID 1257679, 47 ft, 1953-1971 | Bottom line 2 | section 5; lots.out; absent.out last lines |
| 1,176 regional documents; 322 with footnote citation | Bottom line 2 | N3; section 5 (arch.out, POINTED-AT Set B: 322 of 1,176) |
| NAIDs 2839192, 2839191, 2838992 and their extents | Bottom line 2 | lots.out (POINTED-AT list) |
| Johnson / Nixon / Kennedy library files named | Bottom line 2 | arch.out Set B pointed-at rows (36, 25, 18) |
| 'cultural diplomacy', 'Radio Free Asia' none; 'public diplomacy' 2 | Bottom line 3 | N6 |
| Control: 13,470 for 'Department of State' | Bottom line 3 | section 0 and stats.out |
| Tokyo poll 1965; Saigon survey 637 adults | Bottom line 3; Finding 3, 4 | section 4 (facts read from documents) |
| NAID 1254251, 9 ft, partly restricted | Bottom line 3 | section 5 |
| Asia Foundation 12, Peace Corps 59, 'cultural exchange' 92 | Bottom line 3 | N7 |
| 11 of 698 series before 1940, one in sixty-three | Bottom line 3 | N8 |
| 69 volumes; 30,092; 7 volumes; 1,582; 553 volumes | Scope; How this was done | N1, N2, N4, section 0 |
| Wartime/1942-47 China volumes excluded; South Asia excluded | Scope; Decisions | section 1 |
| 1950 mission report: white troops, local armies | Finding 2 | section 4 (facts read), ctx.py output |
| 28 million film audiences | Finding 3 | section 4 (facts read) |
| 1957 Japan hedge | Finding 3 | section 4 (facts read) |
| 26 percent, lowest of thirteen surveys | Finding 3 | section 4 (facts read) |
| January 1966 summary, elites, budgets | Finding 3 | Q rows for v07/d73 are in the collection excerpts (excerpts.out); text facts read |
| poll 49 to 40, 22 to 32; "unchangeable over the short run" | Finding 4 | section 4 (facts read) and Q row for d46 |
| 1971 overseas Chinese pulled by feeling not ideology | Finding 4 | excerpts.out (PubDipv08/d149) |
| 1974 Smyser; 1977 Sullivan | Finding 5 | section 6 (vector-reached); excerpts.out |
| Beijing 1978 | Finding 5 | excerpts.out (30/d152) |
| 134 of 135 tolerant, 80 of 135 strict; 252 of 252; 15 of 15 | How this was done | share.out |
| about 26 vs 18 per thousand; about 8 vs 12 per thousand | How this was done | stats.out false-friend lines |
| 53, 33, 19 per thousand by decade | How this was done | stats.out decade table (N17) |
| 52 documents retrieved whole; 25 quoted | How this was done | section 3 |
| four documents, nearest volumes, map; two of the 25 came via vectors | How this was done | section 6 |
| all quotations and excerpts verified; all cited documents in the collection | How this was done | section 4 verification outputs |

Quotation rows (one per “ ” quotation in the overview, in order of appearance):

| ID | Overview section | Quoted text (start) | Memo line |
|---|---|---|---|
| Q1 | 1. What FRUS answers directly | by other Vietnamese | section 4 row Q1 |
| Q2 | 1. What FRUS answers directly | ostrich-like pacifism | section 4 row Q2 |
| Q3 | 1. What FRUS answers directly | there is no conceivable information program that will make d | section 4 row Q3 |
| Q4 | 1. The message was contrast, strength and reassurance, not attraction | A considerably expanded information program both in Communis | section 4 row Q4 |
| Q5 | 1. The message was contrast, strength and reassurance, not attraction | We can anticipate, too, an upsurge of neutralism. Our inform | section 4 row Q5 |
| Q6 | 1. The message was contrast, strength and reassurance, not attraction | avoiding a preoccupation with the negative side | section 4 row Q6 |
| Q7 | 1. The message was contrast, strength and reassurance, not attraction | our credibility on this negative aspect is relatively low | section 4 row Q7 |
| Q8 | 2. Officials believed the audience was nationalist, poor, wary of whites and best persuaded by its own people | At present we are talking over the heads of Southeast Asia,  | section 4 row Q8 |
| Q9 | 2. Officials believed the audience was nationalist, poor, wary of whites and best persuaded by its own people | relatively privileged positions | section 4 row Q9 |
| Q10 | 2. Officials believed the audience was nationalist, poor, wary of whites and best persuaded by its own people | Vietnamese peasants are, in the main, going to be persuaded  | section 4 row Q10 |
| Q11 | 2. Officials believed the audience was nationalist, poor, wary of whites and best persuaded by its own people | family-oriented, selfish and opportunistic even in the best  | section 4 row Q11 |
| Q12 | 3. Their own judgments of effect moved from counting output to doubting that messages could outrun events | the national press remained generally unreceptive to explana | section 4 row Q12 |
| Q13 | 3. Their own judgments of effect moved from counting output to doubting that messages could outrun events | a remarkable placement of material on the peaceful uses of a | section 4 row Q13 |
| Q14 | 3. Their own judgments of effect moved from counting output to doubting that messages could outrun events | there is no conceivable information program that will make d | section 4 row Q14 |
| Q15 | 3. Their own judgments of effect moved from counting output to doubting that messages could outrun events | The image of a huge white nation attempting to suppress an A | section 4 row Q15 |
| Q16 | 4. Officials concluded that the image followed policy and America at home | the basic emotional response remains unchanged and is probab | section 4 row Q16 |
| Q17 | 4. Officials concluded that the image followed policy and America at home | Racial violence and social unrest in America have roused con | section 4 row Q17 |
| Q18 | 4. Officials concluded that the image followed policy and America at home | Asians are, to varying degrees, America watchers | section 4 row Q18 |
| Q19 | 4. Officials concluded that the image followed policy and America at home | usually depended more on the state of bi-lateral relations | section 4 row Q19 |
| Q20 | 5. After Vietnam the message became reassurance, and the audience was reported to doubt it | The American defeat has been in good part written off by the | section 4 row Q20 |
| Q21 | 5. After Vietnam the message became reassurance, and the audience was reported to doubt it | very clearly in default | section 4 row Q21 |
| Q22 | 5. After Vietnam the message became reassurance, and the audience was reported to doubt it | shoring up the confidence of East Asians in America’s long-t | section 4 row Q22 |
| Q23 | 5. After Vietnam the message became reassurance, and the audience was reported to doubt it | deeply implanted and persistent feeling | section 4 row Q23 |

Every quotation in the overview is in section 4's table (Q1 to Q23); the table gives each one's SELECT.

## 9. Files in this directory

overview.md, memo.md, collection.fruscollection, queries.log; scripts (build_eap_list.py, density.py, pd_scan.py, pd_headers.py, search.py, dump.py, ctx.py, stats.py, share.py, arch.py, lots.py, json_usia.py, json_probe.py, acc.py, absent.py, final_numbers.py, titles.py, vec_setup.py, vec_nn.py, vec_ops2.py, extract_excerpts.py, build_collection.py, verify_collection.py, check_overview.py, build_memo.py); outputs (*.out); docs/ (the 52 raw documents read); excerpts.json; titles.json.

ELIDED: this memo shortens the long source text of documents (it prints quotations and anchors, not the 52 bodies, which are in docs/); it prints the top 12 or 14 rows of each ranked or frequency list, not all rows (the full lists are regenerable with the named scripts); and the scripts' python bodies are in the files named, not repeated here.
