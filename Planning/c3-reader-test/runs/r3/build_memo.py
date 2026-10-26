import json,sqlite3,re
R='/Users/jbotts/frus-analysis/c3/runs/r3/'
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
rd=lambda f:open(R+f).read().rstrip()
col=json.load(open(R+'collection.fruscollection'))
partial={('frus1923v02','d481'):'first 9,500 of 33,346 chars read; remainder retrieved to disk, not read',
 ('frus1921v02','d349'):'first read to char 9,000, then the rest (10,057 total); whole text read',
 ('frus1961-63v12','d421'):'first read to char 8,000, then the rest (9,453 total); whole text read',
 ('frus1943v05','d142'):'first read to char 3,500, then the rest (4,027 total); whole text read'}
head=None; rows=[]
for e in col['entries']:
    if e['kind']=='heading': head=e['text']
    if e['kind']=='document':
        v,d=e['volumeId'],e['documentId']
        h,n,dt=c.execute("select substr(replace(header,char(10),' '),1,60),length(body_text),(select date_iso from document_dates x where x.volume_id=? and x.document_id=?) from document_cache where volume_id=? and document_id=?",(v,d,v,d)).fetchone()
        rows.append("| %s/%s | %s | %s | %d | %s | %s |"%(v,d,dt,h,n,partial.get((v,d),'whole text read'),head[:48]))
M=[]
M.append("""# Memo: recognition of governments that came to power by force in Latin America (run r3, 2026-10-25)

For the operator. The historian's overview is overview.md; the collection is collection.fruscollection; every shell command is in queries.log.

## 0. Coverage, controls and what every number is conditional on

Canary (first tool call, exactly): `sqlite3 "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro" "SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;"` returned `553|321749|1103|8481`, as required. Second call (read-only proof): `sqlite3 -readonly <db> "BEGIN; CREATE TABLE zz(x); ROLLBACK;"` failed with "attempt to write a readonly database", as required.

Every count below is conditional on this database: 553 volumes (the full series is 553), 321,749 rows of which 1,103 are front matter and 8,481 editorial notes. Excluded throughout: is_front_matter = 1, is_editorial_note = 1. The two second editions (frus1951-54IranEd2, frus1969-76ve15p2Ed2) were suppressed in the library-wide counts; no first edition and second edition are both in the collection, and none of the 38 cited volumes is an Ed2. summary_text and note_text were never read or quoted. cross_references was not used (no is_broken filter needed). The three surfaces: (1) this database: used for coverage, identity, headings, sources and all document counts; (2) the TEI XML: NOT USED, so this memo publishes no spelling-variant count, no term density and no apparatus/document split; every text count here is on the index's flattened, stemmed text, not on raw, tag-stripped or word-bounded TEI; (3) bundled JSON, app build 1.0 (1776): used for archival scope. [HARVEST]: no path was given, so the offline NARA record-group harvest is unavailable and no [HARVEST] number appears.

### Controls (positive and negative, same pass)
SQL file ctl.sql, output ctl.out:
```
""")
M.append(rd('ctl.sql')); M.append("```\nOutput:\n```\n"+rd('ctl.out')+"\n```")
M.append("""Positive control: the phrase "department of state" matches in 552 of 553 volumes; the one volume without it is frus1919Parisv05 (ontopic.out, last line; SELECT in ontopic.sql). Negative control: `ZZZ_IMPOSSIBLE_ZZZ` matches 0 rows. The scan is therefore working; the lone volume without the control phrase is a Paris Peace Conference volume, which is a volume-specific absence, not a failure of the scan.

### False-friend test (the question's own term)
On-topic set = 41 volumes whose manifest title contains American Republics, Western Hemisphere, Latin America, Central America, South America, Mexico, Cuba, Caribbean, Americas or Organization of American (list in onTopicVolumes.txt). It is a title filter: the 1920s to 1931 volumes are titled by year only and are not in it, so it understates the on-topic shelf. SQL in ontopic.sql; outputs in ontopic.out:
```
""")
M.append(rd('ontopic.out')+"\n```")
M.append("""Result, word stem recogni* in body_text (porter-stemmed; covers recognize, recognition, recognized): corpus-wide 16,912 of 311,429 non-apparatus documents (5.43%; Ed2 suppressed, 551 volumes counted after suppression); on-topic 1,527 of 27,240 (5.61%). Control phrase "department of state": corpus-wide 93,824 of 311,429 (30.1%); on-topic 7,197 of 27,240 (26.4%). The on-topic share of recogni* equals the corpus baseline, so the bare word measures the corpus (China, Korea, Eastern Europe, the United Nations) and not this question. It was therefore never used alone: the scoping used country names, regime words (junta, coup, revolution, de facto) and the editors' chapter headings beside it.

### Literal-share check (house rule a) for the two phrase-like counts published
Script share_check.py, output share_check.out. Surface: header + dateline + source_note + body_text concatenated and whitespace-collapsed (index text, not TEI). Sample: 40 documents, evenly spaced (index floor(i*N/40), i = 0..39) from the (volume_id, document_id)-sorted hit list. STRICT = case-insensitive, literal words, single spaces; TOLERANT = case-insensitive, inflections allowed (`departments?` / `states?`), any run of space, hyphen, comma, parenthesis or full stop between words. For recogni* strict and tolerant are the same single pattern `recogni`.
```
""")
M.append(rd('share_check.out')+"\n```")
M.append("""All four are 40 of 40, strict and tolerant. A 1.000 share tests the stemmer, not the referent: the referent test is that the overview's findings rest on the 38 documents READ, not on any count. LIKE/FTS (SQL) is case-insensitive; Python regexes here use re.I; one convention (case-insensitive) across the family.

## 1. The scope I chose, and how I found it

Question: how did the US decide whether to recognize governments that came to power by force in Latin America, and what did it ask before recognizing. Inclusion rule: a document is in scope if (a) it is dated 1900 to 1973, (b) it is a US statement, instruction or decision memorandum about whether, when or on what terms to recognize (or to resume or continue relations with) a Latin American government that came to power by coup, revolution, or irregular succession, and (c) it states a test or a demand, not only a report of events. Periodised on document date (document_dates.date_iso), not on the volume's series year. No decade-shape counts are published (so no per-1,000 rates are owed).

Method, in order (all queries logged):
1. Headings: editors' chapter headings with "recogni" in the header, via FTS `header:recogni*` plus country terms. Result in heads.sql / heads.out: 17 chapter headings about Latin American governments (Bolivia 2, Peru 1, Mexico 5, Guatemala 2, Ecuador 1, Cuba 1, El Salvador 2, Argentina 2, Haiti 1) in 11 volumes; all 17 satisfy header LIKE '%ecogni%' (last column 1). One further heading (frus1948v06/ch7subch1) matched the search and was dropped because it is about Siam.
2. Phrase search of body_text (q2.sh): "policy of recognition", "recognition policy", "policy regarding recognition", "question of recognition"; then recognition with revolution/coup/junta/de facto and country terms, per period (1913 to 1923; 1930 to 1934; 1943 to 1945; 1961 to 1968; 1969 to 1980; 1955 to 1957; 1900 to 1912). Each SQL is in queries.log.
3. Reading: 38 documents chosen, see section 2.
4. Archival scope from the bundled JSON, section 4.

## 2. The 38 documents, and what was read

Reading accounting: 38 documents retrieved whole to disk (docs_body/, captured length = length(body_text) for all 38, total 154,469 characters; check printed by verify_quotes.py in verify_quotes.out). Read whole on screen: 37; read in part: 1 (frus1923v02/d481, 9,500 of 33,346 characters). Three others were first read in part and then to the end. Quoted in the collection: 37 excerpts from 37 documents (frus1943v05/d33 has none); quoted in the overview: 18 document quotations from 18 documents, plus 4 short search-phrase strings; all verbatim (section 5). The reading SELECT for each is `SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id='V' AND document_id='D';` (dump.sh; raw text in docs/ with header lines, and body only in docs_body/).

| pair | date (document_dates) | header (60 chars) | body chars | reading | collection heading |
|---|---|---|---|---|---|""")
M.append("\n".join(rows))
M.append("""
Printed-edition citation note: volumes before 1952 did not number their documents; the d-numbers are index positions and also the history.state.gov addresses, so the overview cites those by date and sender. From 1955 onward the d-number is the printed Document number.

Documents dropped after reading or seeing: frus1932v05/d663 (British recognition of Martinez, not US test), frus1944v07/d1137 (Bolivian view of consultation; relevant, not used), frus1933v05/d633 (Mexican mediation for El Salvador). Seen only in snippets and not read: the Argentina 1944 to 1945 documents (frus1944v07/d250, d267, d274, d392), the 1963 Dominican/Honduras cases (frus1961-63v12/d363, frus1961-63v10-12mSupp/d159), the Argentina 1962 item (frus1961-63v12/d185).

## 3. Findings (the 6 headings) and their basis

1. 1900 baseline and Wilson's constitutional test: frus1900/d530, frus1911/d353, frus1913/d7, frus1913/d894, frus1917/d379, frus1917/d407, frus1919v01/d869. Note: frus1913/d894 is dated 28 February 1913, before Wilson took office; it is Taft's Secretary Knox.
2. Mexico 1920 to 1923: frus1920v03/d199, frus1921v02/d344, frus1921v02/d349, frus1923v02/d481.
3. Central America treaty rule and Hoover-Stimson: frus1926v02/d476, frus1930v01/d375, frus1930v01/d476, frus1931v02/d208, frus1932v05/d478, frus1934v05/d218. Limit: I did not read when the US recognized El Salvador; the chapter heading frus1934v05/ch13 says recognition by the US occurred, no date was read.
4. Cuba 1933 to 1934: frus1933v05/d430, frus1933v05/d508, frus1934v05/d75.
5. Consultation and the separation of recognition from approval: frus1943v05/d33, d142, d34; frus1944v07/d403; frus1945v09/d1170; frus1948v09/d7; frus1949v02/d446, d448.
6. Cold War assurances and the retreat from the word: frus1955-57v06/d354; frus1958-60v05mSupp/es_d33 (source text bears "Overtaken By Events", so it records a recommendation not carried out); es_d40; frus1961-63v12/d421, d423; frus1964-68v31/d152, d141, d518; frus1969-76ve08/d6 (an instruction about Afghanistan, cited only as a statement of general Department practice); frus1969-76v21/d358.

Thin spots (may reflect partial reading, not the corpus): the 1950s (one Haiti document read, El Salvador 1960); Argentina 1944 to 1945 (headings only); anything 1974 to 1980 (Bolivia 1980 is mentioned in one memorandum, frus1977-80v24/d113, not used).

## 4. Archival scope (two channels, never summed)

**Came-from channel** (document_sources, one row per document), over the 38 cited documents only, from tally.sql / tally.out:
```
""")
M.append("SQL (tally.sql):\n"+rd('tally.sql')+"\n```\nOutput (tally.out):\n```\n"+rd('tally.out')+"\n```")
M.append("""37 of 38 documents have a document_sources row; frus1900/d530 has none (extra.out; it has no file number). By citation_era: decimal 31, cfpf 1, subject_numeric 1, structured 4 (Eisenhower Library Whitman File: frus1958-60v05mSupp/es_d40; Johnson Library National Security File: frus1964-68v31/d518; Nixon NSC Files: frus1969-76v21/d358; and frus1964-68v31/d152, which the index classes under National Archives RG 59 but whose own source note reads "Johnson Library, National Security File, Country File, Bolivia" with a Department copy at RG 59 POL 16 BOL, i.e. both). Hence "nearly all from RG 59 central files" = 34 of 37 (31 + 1 + 1 + the Bolivia item), 3 of 37 presidential-only. Decimal glosses: the class-8 country numbers used (812 Mexico, 817 Nicaragua, 818 Costa Rica, 837 Cuba) are glossable only for documents dated 1910 to 1949 (decimal-class-labels.json, coverage.glossableYears: 1910 to 1949, 1950 to 1959, 1960 to 1963; renumbered 1950); the memo glosses them only for the early volumes.

**Pointed-at channel** (external_citations), over the same 38 documents: 9 rows in 7 documents (tally.out): centralFileClass 6 rows in 5 documents, lotFile 1, presidentialLibrary 2 rows in 1 document. The channel has no row before 1910-12-06, stores the citation fragment and holds lot, library and decimal anchors only. Lot 63 D 127 (frus1958-60v05mSupp/es_d33): central-files-index.json lotFiles row lotNumber 63D127 -> recordGroup 59, naId 2363840, title "Subject and Country Files", hmsMlrEntryNumbers ["A1 3157"]; series-facts-index.json byNaId 2363840: creator Department of State, Bureau of Inter-American Affairs, Office of Central American and Panamanian Affairs; inclusive 1955 to 1963; extent 3 linear feet, 6 inches; access status "Restricted - Possibly"; use "Unrestricted"; College Park textual reference (series_facts.out). Creator checked against the FRUS citation ("ARA/OAP Files"); consistent. lot-claimants-index.json has no row for 63D127, so it is not a divided lot.

**Footnote usage across whole volumes** (collection-usage-index.json, generated 2026-10-20; scripts usage_scope.py -> usage_scope.out, usage_latam.py -> usage_latam.out). Scope = the 25 volumes of the collection, whole volumes, NOT narrowed to recognition: 19,570 note citations by volumeNoteCounts; category split in usage_scope.out (centralDecimalFile 17,683; presidentialLibrary 666; lotFile 345; subjectNumericFile 303; namedFileSeries 181; previouslyPublished 93; intelligence 91; naraCollection 85; centralForeignPolicyFile 83; unrecognized 39; foreignArchive 1). For the 16 of those volumes dated 1911 to 1945: 15,671 class-keyed note citations, of which 3,413 are Latin American internal-affairs keys matched by the regex `^8(1[2-9]|2[0-5]|3[1-9])\\.0[01]` (schedule 1910-1949: class 8 = Internal Affairs of States, country codes 12 Mexico to 39 Dominican Republic): top keys 812.00 (839), 837.00 (484), 817.00 (357), 818.00 (188), 815.00 (176), 816.01 (169). 812.00 is inflated by frus1911, which prints a Mexican revolution. These are a footnote-usage channel (pointed-at), over whole volumes; they are not summed with the came-from tallies.

**Shelves the bundled data does not resolve:** the Central Decimal File (1910 to 1963), Central Files 1964 to 1966 and the Central Foreign Policy File carry no NARA series identifier, entry, dates or access status in series-facts-index.json or collection-authority.json (ids "txt:department of state|central file", no naId). digitized-ranges-index.json covers decimal classes 131 and 763 only; roll-scans-index.json covers M862 (the pre-1910 Numerical File). Presidential libraries (presidential-library-catalog.json, generated 2026-08-06; pl_lookup.out): Johnson Library National Security Files naId 567979, "Latin America Country Files" naId 567985, 1963 to 1969; Nixon "National Security Files (Nixon Administration)" naId 572235 (the FRUS name "NSC Files" is presumed, not proved, to be this); Eisenhower: no certain match for "Whitman File" (the catalogue has "Ann C. Whitman Papers" naId 643447, not claimed). The catalogue states no access status. Discrepancy noted, not used: collection-usage-index/collection-authority gives lot 60D665 "OAS Files" while central-files-index gives that lot NAID 2660902 the title "Records Relating to the Inter-American Cultural Council and the Committee for Cultural Action"; NARA's creator attribution is a decoy surface, so this lot was not named in the overview. The offline stack barely reaches before 1940; pre-1940 shelves are named by file number only.

## 5. Quotations: every one verified against its document

For each quotation the retrieving SELECT is `SELECT body_text FROM document_cache WHERE volume_id='V' AND document_id='D';` and the check is Python `excerpt in body_text` (verify_quotes.py, printed `collection excerpts 37 not verbatim: 0`). Offsets below are 0-based character offsets into body_text (excerpts_verified.tsv):

| pair | body chars | offset | excerpt chars |
|---|---|---|---|""")
for l in rd('excerpts_verified.tsv').split('\n')[1:]:
    f=l.split('\t'); M.append("| %s | %s | %s | %s |"%(f[0],f[1],f[2],f[3]))
M.append("""
Overview quotation strings: 22 of 12 or more characters were found verbatim in a cited document: 18 document quotations (one per document, 18 documents; one of them the fragment "a great mistake") and 4 search-phrase strings ("policy of recognition", "recognition policy", "question of recognition", "Department of State"). verify_quotes.out lists each string with the first document that contains it (the 1900 sentence also appears inside the 1948 Policy Planning paper, which quotes it, so verify_quotes.out shows frus1948v09/d7 for it; frus1900/d530 also contains it, see excerpts_verified.tsv). Five quoted strings in the overview are labels, not document text: "Subject and Country Files" and "Restricted, possibly" (the National Archives' title and status in the bundled data), the editors' heading "Recognition of the Leguia government by the United States" (frus1920v03/ch23, heads.out), the user's phrase "came to power by force", and the collection's name.

Check performed before finishing: (1) every quotation in overview.md is one this memo verified against its document (verify_quotes.out: 22 of 27 quoted strings of 12+ characters found verbatim in a cited document, 18 of them document quotations; the other 5 are the labels above); (2) every document the overview cites by address (21 distinct) is in the collection (printed `all in collection: True`); (3) every collection document exists in document_cache, none is front matter or an editorial note, none Ed2, no duplicate pair (build_collection.py assertions; pairs.txt = 38).

## 6. Methods notes and limits

- Counting surface for every text count: the index's flattened, stemmed text (FTS5 porter unicode61), not TEI. No variant/acronym scan was run, so none is claimed.
- Phrase searches (q2.sh) were used for discovery and ranking (bm25, negative, better = more negative, ORDER BY ASC), not for published counts, except the two shares above.
- Case convention: SQL LIKE and FTS are case-insensitive; Python used re.I for the same families.
- Thin: the cases read are a selection driven by headings and search rank. A larger library (the hosts of the missing cases) may change the picture; with 553 of 553 volumes indexed the limit is reading, not coverage.
- Argentina 1944 to 1945 and Haiti 1950 appear only as headings. The 1948 PPS paper (frus1948v09/d7) states in its source note that it was "Approved by the Secretary of State" (retrieved text).

## 7. TRACE TABLE (every number and quotation in overview.md)

| overview statement | memo line / file |
|---|---|
| 553-volume library | section 0, canary |
| 38 documents in 25 volumes | tally.out "pairs/volumes|38|25"; section 2 |
| 37 of 38 have a source note (the 1900 instruction has none) | tally.out "came-from rows total|37"; extra.out |
| nearly all from RG 59 central files; Eisenhower Whitman File, Johnson NSF (Peru 1968, Bolivia 1964), Nixon NSC | section 4 came-from (tally.out era/repository rows) |
| Johnson NSF 567979, Latin America Country Files 567985, 1963 to 1969 | pl_lookup.out |
| nine citations in seven documents; six decimal, two Nixon, one lot | tally.out "pointed-at rows|9|7" and anchor breakdown (6 rows/5 docs, 1/1, 2/1) |
| lot 63 D 127, RG 59, entry A1 3157, NAID 2363840, 1955 to 1963, about 3.5 linear feet, "Restricted, possibly" | section 4 pointed-at; series_facts.out; central-files-index.json lotFiles |
| about 3,400 of about 15,700 footnotes, sixteen volumes 1911 to 1945 | usage_latam.out: 3,413 of 15,671, 16 volumes |
| foreign archive cited once in about 19,600 footnotes | usage_scope.out: foreignArchive 1; total 19,570 |
| "Department of State" in 552 of 553 volumes; nonsense word in none | ctl.out; ontopic.out |
| 17 chapter headings, 9 countries | heads.out (17 rows); section 1 |
| about 13,600 documents in 1900 to 1912 volumes; Honduras 1907, Haiti 1908 and 1911, Nicaragua 1910 | extra.out: 13,648; queries.log q2.sh for 1900 to 1912 (frus1907p2/d26-28, frus1908/ch78, frus1911/d353, frus1910/d816) |
| 41 volumes titled for the American republics | onTopicVolumes.txt; ontopic.sql |
| one document in eighteen, both sets | ctl.out 16,912 of 311,429; ontopic.out 1,527 of 27,240 |
| forty of forty | share_check.out |
| first 9,500 of 33,346 characters of 1923 briefing; three others read to the end | section 2 table (frus1923v02/d481 etc.) |
| 1900 "to base the recognition of a foreign government solely on its de facto ability ..." | excerpts_verified.tsv row frus1900/d530; verify_quotes.out |
| 1913 "Cooperation is possible only when ..." | excerpts_verified.tsv frus1913/d7 |
| 1911 "communicate satisfactory assurances ..." | frus1911/d353 (substring of excerpt) |
| 1917 "no Government except such as may be elected legally ..." | frus1917/d379 |
| 1921 "when it appears that there is a government in Mexico ..." | frus1921v02/d344 |
| 1921 "In entering into this treaty with you recognition would be effected, ipso facto." | frus1921v02/d349 |
| 1920 "Recognition cannot be accomplished by inference ..." | frus1920v03/d199 |
| 1926 "has adopted the principles of that Treaty as its policy ..." | frus1926v02/d476 |
| 1930 "the evidence has satisfied me ..." | frus1930v01/d375 |
| 1931 "if the Vice President was a leader in the coup d’état ..." | frus1931v02/d208 |
| 1933 "We have maintained that the criteria of Cuban recognition ..." | frus1933v05/d508 |
| 1933 Welles "if we recognize a government now ..." | frus1933v05/d430 |
| 1934 "a great mistake" | frus1934v05/d75 |
| 1944 "All of the nineteen republics ..." | frus1944v07/d403 |
| 1948 "Recognition of a government by the United States should imply neither approval nor disapproval ..." | frus1948v09/d7 |
| 1962 "Some civilianizing of Cabinet ..." | frus1961-63v12/d423 |
| 1964 "Barrientos and his principal advisers ..." | frus1964-68v31/d152 |
| 1973 "the Department’s policy is to minimize ..." | frus1969-76ve08/d6 |
| claims of fact in Findings 1 to 6 (dates, senders) | section 2 table (dates from document_dates) and the dumps in docs/ |

ELIDED: nothing is elided from this memo; see queries.log for its own ELIDED line.
""")
open(R+'memo.md','w').write("\n".join(M))
print(len("\n".join(M)))
