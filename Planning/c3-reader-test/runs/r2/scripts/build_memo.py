# Build memo.md from this run's output files, with line anchors [Mxx] that the trace table resolves to line numbers.
import csv, json, re
from collections import Counter
csv.field_size_limit(10**9)
J = lambda p: json.load(open(p))
scope = list(csv.DictReader(open("out/scope.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE))
tiers = Counter(r["tier"] for r in scope)
C = [r for r in scope if r["tier"] in ("C", "T+C")]; T = [r for r in scope if r["tier"] in ("T", "T+C")]
chapters = list(csv.DictReader(open("out/scope_chapters.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE))
ls = J("out/literal_share_T.json"); lr = J("out/literal_share_R1R2.json")
ref = list(csv.DictReader(open("out/referent_coding_T.tsv"), delimiter="\t"))
refc = Counter(x["code"] for x in ref)
post_ref = [x for x in ref if x["pair"].split("/")[0] >= "frus1951"]
dec = J("out/decades.json")["rows"]
tc = J("out/tei_census.json"); tv = J("out/tei_variants.json")
ff = J("out/false_friend.json"); ab = J("out/absence_checks.json")
qv = J("quotes/quotes_verified.json"); ql = {x["id"]: x for x in J("quotes/quotes_tei_location.json")}
cc = J("out/collection_check.json")
cfj = J("out/archival_camefrom.json"); paj = J("out/archival_pointedat.json")
cf_units = [l.rstrip("\n").split("\t", 1) for l in open("out/archival_camefrom_units.tsv")]
ds = list(csv.DictReader(open("out/arch_document_sources.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE))
ec = list(csv.DictReader(open("out/arch_external_citations.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE))
ra = open("out/reading_accounting.txt").read().splitlines()
L = []
def w(s=""): L.append(s)
P = ["1861-1912", "1913-1929", "1930-1942", "1943-1950", "1951-1981"]
def cell(tier, fam, p, side="pres_doc"): return f"{tc[tier][side][fam].get(p, 0)} of {tc[tier]['den'].get(p, 0)}"
w("# Scope memo: recognition of governments that came to power by force in Latin America")
w()
w("Operator memo for the overview and collection in this run directory. Every number below gives its query or script, its counting surface and its denominator; the trace table at the end maps each number and quotation in the overview to the line of this memo it comes from. Database: read-only copy `/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db` (taken 2026-10-25). TEI: `.../FRUSExplorer/volumes/*.xml` (553 files). Bundled JSON: `/Applications/FRUS Explorer.app/Contents/Resources/` (build 1.0 (1776)). Every SQL statement a script ran is also appended, verbatim, to `out/sql_trace.log`.")
w()
w("## 1. Coverage and access checks")
w()
w("[M-COV] Canary, first tool call: `sqlite3 \"file:...frus-copy-2026-10-25.db?mode=ro\" \"SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;\"` returned `553|321749|1103|8481`, as required: 553 volumes, 321,749 documents, 1,103 front-matter rows, 8,481 editorial notes. Every count in this memo is conditional on these 553 volumes (the full series as the manifest lists it).")
w("[M-THIN] Thin results in this run (the 1980s, the post-1950 Latin American chapters) reflect the published series, not a partial download: the copy holds all 553 manifest volumes. The series' 1981–1988 volumes that concern Latin America are frus1981-88v16 (South America) and frus1981-88v13 (Conflict in the South Atlantic); no 1981–1988 Central America volume is in the manifest.")
w("[M-RO] Read-only proof, second tool call: `sqlite3 -readonly ... \"BEGIN; CREATE TABLE zz(x); ROLLBACK;\"` failed with `attempt to write a readonly database`, as required.")
w("[M-TEI-N] TEI corpus: `ls .../volumes/*.xml | wc -l` = 553 (the folder also holds 96 `.figures` directories, not read).")
w()
w("## 2. Scope: what was chosen and how it was found")
w()
w("### 2.1 The editors' headings were read first")
w("[M-HEAD] `scripts/headings_dump.py` walked `volume_structures.structure_json` for all 553 volumes (`SELECT volume_id, structure_json FROM volume_structures ORDER BY volume_id`) into `out/headings.tsv`: 25,115 section rows. `scripts/doc_sections.py` mapped 314,616 documents to their deepest listing section (`out/doc_sections.tsv`). Headings were then scanned (Python `re`, lower-cased) for `recogni`, and separately for `revolution|coup|junta|provisional government|de facto|overthrow|golpe|military government|tobar|nonrecognition|non-recognition|diplomatic relations|insurrection|uprising|rebellion|seizure of power|unconstitutional` (`out/headings_recogn.tsv`, 253 rows; `out/headings_force.tsv`, 254 rows).")
w("[M-HEAD-POST] `scripts/chapter_candidates.py` kept the 186 sections whose OWN title uses the recognition/force formula and whose documents classify as Latin American (`out/chapter_candidates.tsv`). The two latest are candidates 185 (frus1950v02, *Recognition by the United States of the military junta government of Haiti*, 1950) and 186 (frus1958-60v06, *U.S. interest in the Cuban revolution, the overthrow of the Batista government...*). No Latin American heading from 1950 on names recognition except candidate 185, and none names an overthrow except candidate 186. The post-1949 Latin American volumes' headings were listed in full and are country titles (*Political and economic relations of the United States and X*; from 1958, *U.S. relations with X*; from 1961, the country name alone).")
w()
w("### 2.2 Latin American classification")
w("[M-LATAM] `scripts/latam_classify.py` (v4) walks each document's breadcrumb from the deepest heading upward: the first heading naming exactly one of the twenty republics (period spellings: Hayti, Santo Domingo, New Granada, Salvador, Argentine Republic, Mosquito/Bluefields for Nicaragua) assigns that country; a heading naming several republics counts as regional; a heading naming only Guyana, British Guiana, Jamaica, Bahamas, Eastern Caribbean, Suriname, Trinidad, Grenada, Barbados, Canada or Newfoundland excludes the document; inter-American headings or Latin-America-only volumes assign *Regional*; single-country volumes take the volume's country. Result: 61,412 Latin American documents (`out/latam_docs.tsv`), 1,824 excluded as non-republic. Known quirk: a heading like *...meeting at Montevideo, Uruguay* assigns Uruguay to a regional committee document (frus1943v05/d33); the country label is not used for any count in the overview.")
w()
w("### 2.3 Inclusion rule")
w("[M-RULE] SCOPE = C ∪ T, apparatus excluded (`is_front_matter = 0 AND is_editorial_note = 0`).")
w("- **C (editors' tier)**: every document directly listed in 51 curated sections whose own titles name recognition, non-recognition, withholding of recognition or continuance of relations for a Latin American government that took power by revolution, coup or other unconstitutional means. Chosen from the 186 candidates by reading each title (list in 2.4). Excluded as off-topic: meat-inspection labels, consuls, judgments, naturalization certificates, blockade, Monroe Doctrine, a constitution clause, protection of a citizen, Mexico's international personality, the 1896 Central American union, and the 1912 Haiti succession after Leconte's death. Mixed chapters whose titles bundle recognition with other matters (Mexico 1911–1916, Nicaragua 1911, Paraguay 1912, Haiti 1914–1915, Dominican Republic 1916, Costa Rica 1919, Argentina 1945, the 1930–1931 *Revolution in X* chapters, Cuba 1933) enter only through T.")
w("- **T (text tier)**: Latin American documents matching `frus_documents MATCH '(NEAR(recogn* govern*, 6) OR NEAR(recogn* regim*, 6) OR NEAR(recogn* junta, 6)) AND (revolut* OR coup OR junta OR \"de facto\" OR overthrow* OR insurrect* OR golpe OR \"provisional government\" OR usurp* OR unconstitut*)'` (`scripts/scope_text.py`; SQL `SELECT f.volume_id, f.document_id, c.is_front_matter, c.is_editorial_note, d.date_iso FROM frus_documents f JOIN document_cache c ON c.volume_id = f.volume_id AND c.document_id = f.document_id LEFT JOIN document_dates d ON d.volume_id = f.volume_id AND d.document_id = f.document_id WHERE frus_documents MATCH ?`).")
w(f"[M-T] The MATCH returns 3,496 documents corpus-wide (66 of them apparatus); 1,358 sit in Latin American sections; 1,348 of those are not apparatus = T. (Shell re-run: `SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH '<same>'` = 3496.)")
w(f"[M-C] C: the 51 sections list 1,209 documents; 3 are apparatus; C = 1,206 documents, dated {min(r['date_iso'] for r in C)} to {max(r['date_iso'] for r in C)}, in {len({r['volume_id'] for r in C})} volumes.")
w(f"[M-SCOPE] SCOPE = {len(scope)} documents in {len({r['volume_id'] for r in scope})} volumes (`out/scope.tsv`): T only {tiers['T']}, C only {tiers['C']}, both {tiers['T+C']}. Dated {min(r['date_iso'] for r in scope)} to {max(r['date_iso'] for r in scope)}; the single pre-1861 document is frus1902app2 (Pious Fund claims appendix, 1836). T: {len(T)} documents dated {min(r['date_iso'] for r in T)} to {max(r['date_iso'] for r in T)}.")
w(f"[M-ED2] Second editions: no scope volume ends in `Ed2` (frus1951-54IranEd2, frus1969-76ve15p2Ed2 and frus1977-80v09Ed2 hold no Latin American section document in the set); no collection volume ends in `Ed2`. Counting surface for every scope count: this index, apparatus excluded by column.")
w(f"[M-POST] Scope documents dated 1951 or later: {sum(1 for r in scope if r['date_iso'] >= '1951')}, all from T (no C chapter after 1950).")
w(f"[M-ANCH] Seven documents outside SCOPE were added to the collection because they state the policy without the T vocabulary, each found by a logged targeted search: frus1913/d7 (contains no `recogni` at all: `SELECT instr(lower(body_text),'recogni') FROM document_cache WHERE volume_id='frus1913' AND document_id='d7'` = 0), frus1913/d1028, frus1914/d544, frus1914/d568, frus1943v05/d33, frus1943v05/d142, frus1964-68v31/d206 (`out/collection_check.json`, field `in_scope_tier`).")
w("[M-STEMTRAP] Correction inside this run: an exploratory count typed the stem `\"provision govern*\"` and returned 2,975; the query stems its terms again (`provision` -> `provis`), so it matched almost nothing for that clause. Re-run with the words `\"provisional government\"`: 3,496. Both queries are in `queries.log`; only the second is used.")
w()
w("### 2.4 The 51 editors' chapters in C")
w("| idx | volume | docs listed | heading (deepest title) |")
w("|---|---|---|---|")
for c in chapters:
    t = c["breadcrumb"].split(" > ")[-1]
    w(f"| {c['idx']} | {c['volume_id']} | {c['n_docs_listed']} | {t[:150]} |")
w()
w("## 3. Measurements")
w()
w("### 3.1 Literal shares of the FTS rules (house rule (a)) and the referent test")
w(f"[M-LS-T] T rule, hit list = the {ls['N']:,} Latin American non-apparatus hits sorted by (volume_id, document_id), evenly spaced sample of {ls['K']} (indices {ls['indices'][:5]}... in `out/literal_share_T.json`). Text = header+dateline+source_note+body_text, whitespace-collapsed; Python `re` with `re.I` (case-insensitive) for both forms. STRICT (base words, single spaces: recognize/recognized/recognition within 6 tokens of government/regime/junta, plus a base-form force word) = **{ls['strict_pass']} of {ls['K']}**; TOLERANT (inflections, any non-word separators) = **{ls['tolerant_pass']} of {ls['K']}**. Strict misses are inflections (recognizing, governments, revolutionary). `scripts/literal_share_T.py`.")
w(f"[M-REF] Referent test (a 1.000 tolerant share tests the stemmer, not the referent): the same 40 coded by reading header + KWIC (`out/referent_coding_T.tsv`): ON (recognition of a government that took power by force, or policy on it) **{refc['ON']} of 40**; RELATED (belligerency, or recognition between factions) {refc['RELATED']} of 40; OFF (other senses of 'recognize') {refc['OFF']} of 40. Of the 8 sampled documents dated after 1950, {sum(1 for x in post_ref if x['code']=='ON')} are ON. T is therefore published as candidates, not as a count of recognition documents.")
w(f"[M-LS-R] Comparison rules (used only in 3.2): R1 = `NEAR(recogn* govern*, 6) OR NEAR(recogn* regim*, 6) OR NEAR(recogn* junta, 6)` — Latin American non-apparatus hit list {lr['R1']['N']:,}; STRICT {lr['R1']['strict']} of 40, TOLERANT {lr['R1']['tolerant']} of 40. R2 = `recogn*` — hit list {lr['R2']['N']:,}; STRICT {lr['R2']['strict']} of 40, TOLERANT {lr['R2']['tolerant']} of 40. Same method (`scripts/literal_share_R1R2.py`, `out/literal_share_R1R2.json`).")
w()
w("### 3.2 Recall of text rules against the editors' chapters")
w("[M-RECALL] `scripts/rule_recall.py`, Latin American non-apparatus documents only (same MATCH strings; SQL `SELECT volume_id, document_id FROM frus_documents WHERE frus_documents MATCH ?`):")
w("- R0 (= T rule): 1,348 hits; contains **221 of the 1,206** C documents; 1,127 hits outside C (835 dated to 1950, 292 from 1951).")
w("- R1 (recognition NEAR government/regime/junta, no force words): 2,898 hits; 444 of 1,206.")
w("- R2 (`recogn*` alone): 8,172 hits; 634 of 1,206 — about half of the editors' recognition-chapter documents never use a recognition word; the editors file whole episodes under the heading.")
w("- [M-R3] R3 (R0's force clause widened with `\"diplomatic relations\" OR NEAR(continu* relations, 3) OR NEAR(resum* relations, 3)`): 1,464 hits, i.e. **116 more** than R0's 1,348; 238 of 1,206.")
w()
w("### 3.3 Decade shape (periodised on each document's own date)")
w("[M-DEC] `scripts/decades.py`. Denominators: (corpus) dated non-apparatus documents per decade, SQL `SELECT substr(d.date_iso,1,3) || '0s' AS decade, COUNT(*) FROM document_cache c JOIN document_dates d ON d.volume_id = c.volume_id AND d.document_id = c.document_id WHERE c.is_front_matter = 0 AND c.is_editorial_note = 0 AND d.date_iso GLOB '[0-9][0-9][0-9][0-9]*' GROUP BY decade`; (LatAm) the same restricted to `out/latam_docs.tsv`. Numerators from `out/scope.tsv`. Per-1,000 and the numerator's top volume:")
w("| decade | dated docs, corpus | dated docs, LatAm sections | C n (per 1,000 corpus; per 1,000 LatAm) | C top volume | T n (per 1,000 corpus; per 1,000 LatAm) | T top volume |")
w("|---|---|---|---|---|---|---|")
for r in dec:
    if r["den_all"] < 1000: continue
    w(f"| {r['decade']} | {r['den_all']:,} | {r['den_latam']:,} | {r['C']} ({r['C_per1000_all']}; {r['C_per1000_latam']}) | {r['C_topvol'] or '—'} {r['C_topvol_n'] or ''} of {r['C']} | {r['T']} ({r['T_per1000_all']}; {r['T_per1000_latam']}) | {r['T_topvol'] or '—'} {r['T_topvol_n'] or ''} of {r['T']} |")
d60 = [r for r in dec if r["decade"] == "1960s"][0]
w(f"[M-DEC60] 1960s: T top volume frus1961-63v10 holds {d60['T_topvol_n']} of the {d60['T']} T documents — the planning of a provisional Cuban government to be set up by the invasion force and recognized ({round(100*d60['T_topvol_n']/d60['T'])}%, about a fifth). A small decade's rate can be one episode: the 1940s C numerator is {[r for r in dec if r['decade']=='1940s'][0]['C_topvol_n']} of {[r for r in dec if r['decade']=='1940s'][0]['C']} from frus1944v07.")
w("[M-DATE] Periodisation check (`scripts/decades.py`): `document_dates.date_iso` agrees with the TEI `frus:doc-dateTime-min` local day for 2,311 of 2,333 scope documents; the 22 differences are one-day shifts from the attribute's −05:00 instant convention (18 one day later, 4 one day earlier in `date_iso`), none crossing a year or decade (`out/date_diffs.json`).")
w()
w("### 3.4 TEI vocabulary census (document text separated from apparatus)")
w("[M-TEI] `scripts/tei_pass.py` (v2) parsed the 137 scope volumes' TEI. Counting surface: TEI, tag-stripped, whitespace-collapsed. For each scope document, DOC = everything inside `<div type=\"document\">` except `<note>` (source note and footnotes) and `<head>` (the editors' heading); APP = those notes and heads. Families are case-insensitive Python regexes (listed in the script). All 2,333 scope documents were found in the TEI. Unit = documents with at least one match in DOC text, by tier and period (`out/tei_census.txt`, `out/tei_census.json`; `scripts/tei_census.py`).")
w(f"[M-CTRL] Controls in the same pass, over each whole volume file tag-stripped: positive control `department of state` (case-insensitive) nonzero in all 137 volumes (minimum 33, frus1902app2); negative control `ZZZ_IMPOSSIBLE_ZZZ` = 0 in all 137.")
w("[M-TEI-FIX] Correction inside this run: v1 of the RECOG family (`recogni[sz]\\w*`) missed `recognition`. The final files show it (command `grep -n \"^RECOG \" out/tei_census_v1_buggy.txt out/tei_census.txt`):")
w("| tier C, DOC text | 1861–1912 | 1913–1929 | 1930–1942 | 1943–1950 |")
w("|---|---|---|---|---|")
w("| v1 `recogni[sz]\\w*` (out/tei_census_v1_buggy.txt) | 33 of 128 | 97 of 341 | 106 of 321 | 113 of 416 |")
w(f"| v2 `recogni\\w*` (out/tei_census.txt) | {cell('C','RECOG','1861-1912')} | {cell('C','RECOG','1913-1929')} | {cell('C','RECOG','1930-1942')} | {cell('C','RECOG','1943-1950')} |")
w("Only v2 is used. v1 outputs are kept in `out/tei_v1/`.")
w()
w("Tier C (editors' chapters), documents whose DOC text matches, N of the period's C documents:")
w("| family | 1861–1912 | 1913–1929 | 1930–1942 | 1943–1950 |")
w("|---|---|---|---|---|")
for fam, tag in [("CONSTITUTIONAL", "M-T-CONST"), ("CA_TREATY", "M-T-CA"), ("CONSULT_FORMAL", "M-T-CONS"), ("AXIS_NAZI", "M-T-AXIS"), ("ELECTIONS_ANY", None), ("ELECTIONS_FREE_HOLD", None), ("INTL_OBLIG", None), ("FULFIL_OBLIG", None), ("DE_FACTO", None), ("LIVES_PROPERTY", None), ("CONTROL_ACQUIESCE", None), ("COMMUNISM", None), ("HUMAN_RIGHTS", None), ("BY_FORCE", None), ("SEIZED_POWER", None)]:
    w(f"| {fam}{(' ['+tag+']') if tag else ''} | {cell('C',fam,'1861-1912')} | {cell('C',fam,'1913-1929')} | {cell('C',fam,'1930-1942')} | {cell('C',fam,'1943-1950')} |")
w("Readings used in the overview: [M-T-CONST] constitutional vocabulary 91 of 341 (about one in four) for 1913–1929 against 13 of 128 (about one in ten) for 1861–1912; [M-T-CA] the Central American treaty (`treaty of peace and amity`, `Washington treaties/conventions`, `treaty of 1907/1923`, `Tobar`) in 66 of 321 (about one in five) for 1930–1942 and 0, 1 and 1 elsewhere; [M-T-CONS] the formal consultation machinery (`Resolution XXII/XXXV`, `political defense`, `Emergency Advisory Committee`, `Bogotá Resolution`, `Montevideo Committee`) in 0 documents before 1943 and 36 of 416 (about one in twelve) for 1943–1950; [M-T-AXIS] Axis/Nazi/fascist/totalitarian in 65 of 416 (about one in six) for 1943–1950 and 2 of 321 for 1930–1942.")
w(f"[M-T-POST] Tier T, 1951–1981 (292 candidates, about half on topic per M-REF): COMMUNISM {cell('T','COMMUNISM','1951-1981')} (about three in five), HUMAN_RIGHTS {cell('T','HUMAN_RIGHTS','1951-1981')} (about one in twelve), ELECTIONS_ANY {cell('T','ELECTIONS_ANY','1951-1981')}, INTL_OBLIG {cell('T','INTL_OBLIG','1951-1981')}.")
vd, va = tv["doc"], tv["app"]
CK = "coup d'etat (any accent/apostrophe)"
coup_d, coup_a = vd[CK], va[CK]
w(f"[M-VAR] Variant split over all 2,333 scope documents, occurrences in DOC / APP text (TEI tag-stripped): recognize {vd['recognize']}/{va['recognize']}, recognise {vd['recognise']}/{va['recognise']}, recognized {vd['recognized']}/{va['recognized']}, recognised {vd['recognised']}/{va['recognised']}, recognizing {vd['recognizing']}/{va['recognizing']}, recognising {vd['recognising']}/{va['recognising']}, recognition {vd['recognition']}/{va['recognition']}, nonrecognition {vd['nonrecognition']}/{va['nonrecognition']}, non-recognition {vd['non-recognition']}/{va['non-recognition']}, unrecognized/-ised {vd['unrecognized/-ised']}/{va['unrecognized/-ised']}; de facto {vd['de facto']}/{va['de facto']}, de-facto {vd['de-facto']}/{va['de-facto']}, defacto {vd['defacto']}/{va['defacto']}; coup d'état (any accent or apostrophe) {coup_d}/{coup_a}, bare coup {vd['coup (bare)']}/{va['coup (bare)']}, golpe {vd['golpe']}/{va['golpe']}; junta {vd['junta']}/{va['junta']}, juntas {vd['juntas']}/{va['juntas']}; Tobar {vd['Tobar']}/{va['Tobar']}; fulfill- {vd['fulfill-']}/{va['fulfill-']}, fulfil- (single l) {vd['fulfil-(single l)']}/{va['fulfil-(single l)']}. British spellings are effectively absent; the hyphenated `non-recognition` outnumbers `nonrecognition` about three to one.")
w()
w("### 3.5 False-friend test (terms the question supplied)")
w("[M-FF] `scripts/false_friend.py`: one method for the whole family, SQL `LIKE` (case-insensitive for ASCII) over `body_text` (which includes footnotes), apparatus excluded. ON = the 1,206 C documents; LATAM = all Latin American section documents; ALL = corpus. The ON and LATAM statements join a `VALUES` list on both keys (`out/ff_sql_on.sql`, `out/ff_sql_latam.sql`); ALL: `SELECT COUNT(*), SUM(c.body_text LIKE '%recogni%'), ... FROM document_cache c WHERE c.is_front_matter = 0 AND c.is_editorial_note = 0`.")
w("| term | ON (editors' chapters) | LATAM sections | ALL corpus |")
w("|---|---|---|---|")
for t in ["recogni", "by force", "came to power", "latin america", "revolution", "de facto", "CONTROL department of state"]:
    w(f"| {t} | {ff['ON'][t]} of {ff['ON']['n']} ({ff['ON'][t]/ff['ON']['n']:.3f}) | {ff['LATAM'][t]} of {ff['LATAM']['n']} ({ff['LATAM'][t]/ff['LATAM']['n']:.3f}) | {ff['ALL'][t]} of {ff['ALL']['n']} ({ff['ALL'][t]/ff['ALL']['n']:.3f}) |")
w("[M-FF-READ] Reading: `came to power` (2 of 1,206), `by force` (25 of 1,206) and `latin america` (32 of 1,206) sit within a factor of two of the corpus rate (0.002 vs 0.001; 0.021 vs 0.013; 0.027 vs 0.028), while the control phrase itself moves by a factor of 2.6 between sets (0.114 vs 0.299), so these three terms measure the corpus, not the question: they were not used as search terms. `recogni` is 3.4 times the corpus rate in ON but at the corpus rate in LATAM (0.135 vs 0.156): alone it measures the generic verb, which is why T requires the NEAR-government clause and a force word. The period's terms `revolution` (5.8x) and `de facto` (9.3x) are strongly on topic.")
w()
w("### 3.6 Absence checks, each with controls in the same pass")
w("[M-ABS] `scripts/absence_checks.py`; SQL `SELECT f.volume_id, f.document_id, d.date_iso, c.header FROM frus_documents f JOIN document_cache c ON ... JOIN document_dates d ON ... WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 AND f.volume_id IN (...) [date window]`, run three times per check (query, `\"Department of State\"`, `ZZZ_IMPOSSIBLE_ZZZ`):")
for a in ab:
    w(f"- {a['check']}: volumes {a['volumes']} {a['extra']}; MATCH `{a['match']}` -> **{a['n_query']}** documents; positive control {a['n_pos']}; negative control {a['n_neg']}. Hits: {', '.join(a['hits'][:10])}{' ...' if len(a['hits']) > 10 else ''}")
w("[M-ABS-SQL] Full statement (from the script): `SELECT f.volume_id, f.document_id, d.date_iso, c.header FROM frus_documents f JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id LEFT JOIN document_dates d ON d.volume_id=f.volume_id AND d.document_id=f.document_id WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 AND f.volume_id IN (<volumes>) <date window> ORDER BY d.date_iso`.")
w("[M-ABS-BR] None of the 8 Brazil 1964 hits is in SCOPE (checked against `out/scope.tsv`); frus1964-68v31/d206 was read and added as an anchor.")
w("[M-ABS-81] The single 1981–1988 hit in frus1981-88v16 is d402 (Paraguay, 1984-05-18). frus1981-88v13 (*Conflict in the South Atlantic, 1981–1984*) is not classified Latin American by the breadcrumb rule (its only chapter heading names no republic), so it was checked separately with the same MATCH (`SELECT f.volume_id, COUNT(*) FROM frus_documents f JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id WHERE frus_documents MATCH 'NEAR(recogn* govern*, 6) OR NEAR(recogn* regim*, 6) OR NEAR(recogn* junta, 6)' AND c.is_front_matter=0 AND c.is_editorial_note=0 AND f.volume_id IN ('frus1981-88v13','frus1981-88v16') GROUP BY f.volume_id`): 8 documents in v13 (d9, d70, d71, d73, d89, d90, d189, d424), read in snippet: all concern sovereignty over the islands, recognition of British support, or a successor government's attitude, none the recognition of a government. Controls in the same pass: `\"Department of State\"` 337 (v13) and 67 (v16); `ZZZ_IMPOSSIBLE_ZZZ` 0.")
w("[M-ABS-CAR] The 26 Grenada/Suriname hits are outside SCOPE by the inclusion rule (non-republic Caribbean).")
w()
w("## 4. Archival scope, two channels, never summed")
w()
w("### 4.1 Came-from (document_sources, one row per document), volume set = the 137 scope volumes, unit = scope documents")
w(f"[M-CF] `scripts/archival_sql.py`: `WITH s(v, d) AS (VALUES <2,333 scope pairs>) SELECT ds.volume_id, ds.document_id, ds.repository, ds.record_group, ds.lot_file_norm, ds.series_name, ds.citation_era, ds.decimal_class, ds.raw_text FROM document_sources ds JOIN s ON ds.volume_id = s.v AND ds.document_id = s.d` (full statement `out/arch_sql_document_sources.sql`; rows `out/arch_document_sources.tsv`). **{len(ds)} of 2,333** scope documents carry a source row; 404 carry none (382 dated through 1905, 11 dated 1906–1909, 11 dated 1910 or later).")
era = Counter(r["citation_era"] for r in ds)
w("[M-PRE1906] Of the 384 scope documents dated through 1905, 382 carry no source row (query in M-CF; count by `python3 -I -c` over `out/scope.tsv` and `out/arch_document_sources.tsv`).")
w(f"[M-CF-ERA] citation_era (a citation FORM, not a date): {', '.join(f'{k} {v}' for k, v in era.most_common())}. Record group: 59 for {sum(1 for r in ds if r['record_group']=='59')} rows.")
w("[M-CF-DEC] Decimal rows with a class number: 1,673; by class (`out/archival_summary.txt`): 8xx.00 *Political affairs* 893; 8xx.01 *Government* 378; 711.12 United States–Mexico relations 47; 7xx.00/.02 (1950–1963 *Internal Political and National Defense Affairs*) 56; 710.x Pan-America 18; other 281. In the editors' chapters (tiers C and T+C) the split is 632 political affairs and 317 government of 1,102 decimal rows.")
w("[M-CF-GLOSS] Glosses from `decimal-class-labels.json`, gated by each document's own year against `coverage.glossableYears` (1910–1949, 1950–1959, 1960–1963; `keyOutsideGlossableYears` = no-gloss): e.g. 812.00 *Internal Affairs of States: Mexico — Political affairs* (168 documents), 816.01 *El Salvador — Government* (146), 824.00 *Bolivia — Political affairs* (144), 818.00 *Costa Rica — Political affairs* (80), 824.01 *Bolivia — Government* (64), 823.00 *Peru — Political affairs* (63), 817.00 *Nicaragua — Political affairs* (59), 711.1211 *Political Relations of States: United States – Mexico* (37; subdivision .11 not glossed by the file). Full list `out/archival_camefrom_units.tsv`. The file's 1910–1949 schedule has no label containing 'recogn': recognition correspondence sits under *Government* (.01) and *Political affairs* (.00). The file names no series NAID, entry, date span or access status for the Central Decimal File; `volume-sources-index.json` gives Record Group 59, *General Records of the Department of State*, NAID 388.")
w("[M-CF-SNF] Subject-Numeric rows: 30 (raw texts such as `POL 16 DOM REP`, `POL 16 ARG`, `POL 23–9 ARG`). Glossed from `subject-numeric-labels.json`, gated by year: POL 16 in the 1963 schedule = *INDEPENDENCE. RECOGNITION.* (frus1961-63v12/d363, 1963); the 1964–1973 schedule prints no POL 16 entry, so POL 16 ARG (1966) and POL 16 PERU get no gloss; POL 23-9 (1964–1973) = *Rebellion. Coups.*; POL 15 = *GOVERNMENT*; POL 26 (1963) = *REBELLION. COUPS. INSURGENCY.* Five bilateral keys (`POL ARG–US` and the like) and one `AV 12` did not parse to a subject (`out/snf_unparsed.txt`). No series NAID or entry is bundled.")
w(f"[M-CF-CFPF] Central Foreign Policy File rows (citation_era `cfpf`): {era['cfpf']}, on documents dated 1973-09-15 to 1981-01-10. No identifier bundled.")
w("[M-CF-LOT] Lot rows resolved via `central-files-index.json` `lotFiles` (lotNumber folded) -> `series-facts-index.json` `byNaId` (decoded through its `legend`): 62D1 (6 documents) -> NAID 2838992 *Records Relating to Activities with the National Security Council*, entries A1 1583E, A1 1583F, inclusive 1948–1961, Restricted – Partly, creator Policy Planning Council; 62D430 (3) -> NAID 2839191 *Subject and Special Files*, A1 1586C, 1953–1961 (coverage 1952–1961), Restricted – Partly; 63D351 (2) and 66D95 (2) -> NAID 2839192 *Records Relating to National Security Council Policy Papers*, A1 1586E, 1947–1979, Restricted – Partly; 53D26 (2) -> NAID 2108774 *Subject Files*, A1 1130, 1949–1953, Unrestricted, creator Bureau of Inter-American Affairs, Office of the Assistant Secretary; 64D199 (2) -> NAID 602231 *The Secretary's and the Under Secretary's Memorandums of Conversation*, A1 1566, 1953–1964, Unrestricted; 64D16 (1) -> NAID 1750062 *Records Relating to El Salvador*, A1 3159, 1958–1975, Restricted – Partly; also 61D279 -> 2108779, 62D24 -> 2363836, 61D110 -> 2602882, 61D473 -> 2113324, 58D776 -> 596518, 64D563 -> 1136548 (lot-claimants-index lists more than one claimant), 66D149 -> 610077; 90D410, 70D442 and a parse `NO` have no row. Detail: `out/archival_camefrom.json`.")
w("[M-CF-LIB] Library rows matched against `presidential-library-catalog.json` (by `citedAs`, then collection title): Kennedy Library *National Security Files* 15 documents -> collection NAID 1164 (JFK-4); Johnson Library *National Security File* 6 -> NAID 567979 (LBJ-NSF); Carter Library *National Security Council* 2 -> NAID 623746 (JC-NSC); not matched: Nixon Presidential Materials *NSC Files* 15, Carter Library *National Security Affairs* 9, Eisenhower Library *Whitman File* 8. Central Intelligence Agency (structured) 36.")
w("[M-CF-PRE] Pre-1906 (no source notes printed): `central-files-index.json` `countrySeries` lists the National Archives' filmed file units by country, e.g. *Despatches from U.S. Ministers to Mexico, 1823-1906* file unit NAID 177380741 (179 rolls); Venezuela 177380736; Colombia 177380752; Central America 177380749; Haiti 177380737; Dominican Republic 177380740; Peru 177380755; Chile 177380724; Ecuador 177380753; and *Diplomatic Instructions* and *Notes from Foreign Missions* by country (`out/despatch_file_units.txt`). This is an INFERRED shelf, not a came-from attribution by the edition.")
w()
w("### 4.2 Pointed-at (external_citations, many rows per document), same volume set")
nd = len({(r['volume_id'], r['document_id']) for r in ec})
w(f"[M-PA] `WITH s(v, d) AS (VALUES <scope pairs>) SELECT ec.volume_id, ec.document_id, ec.note_ordinal, ec.citation_index, ec.anchor, ec.repository, ec.collection, ec.lot_file_norm, ec.file_id, ec.decimal_class, ec.inherited, ec.raw_text FROM external_citations ec JOIN s ON ec.volume_id = s.v AND ec.document_id = s.d` (`out/arch_sql_external_citations.sql`): **{len(ec)} rows on {nd} scope documents**; anchors {', '.join(f'{k} {v}' for k, v in Counter(r['anchor'] for r in ec).most_common())}; earliest citing document dated 1912-11-27. The channel has no row before 1910-12-06, stores the citation fragment not the sentence, and holds lot, library and decimal anchors only.")
w("[M-PA-TOP] Leading pointed-at units (rows / documents): Carter Library *National Security Affairs* 18/7 (raw texts name Brzezinski Material and Staff Material, Pastor Files; not matched in the catalogue); decimal 817.00 Nicaragua political affairs 11/9; 737.00 Cuba (1950s schedule) 11/5; 824.00 Bolivia 9/7; 816.01 El Salvador government 6/5; 714.00 Guatemala 5/4; 738.00 Haiti 4/3; 738.02 Haiti 4/4; lot 60D665 6/1 -> NAID 2660902 *Records Relating to the Inter-American Cultural Council...* (creator check FAILS for a recognition document: flagged, not used); lot 81D64 4/1 -> NAID 27499857 *Assistant Secretary's Files*, entry UD-14D 61, 1978–1981, Restricted – Fully, Bureau of Inter-American Affairs; lot 61D279 3/2 -> NAID 2108779 *Subject Files*, A1 1135, 1957–1959, Unrestricted. Other lot resolutions whose creator does not fit (57D284 -> Torquay GATT delegation, RG 43; 60D533 -> Iran files) are flagged and not used. Detail `out/archival_pointedat.json`, `out/archival_resolve.txt`.")
w()
w("## 5. Reading accounting")
w(f"[M-READ] {ra[0]}")
w(f"[M-QUOTED] {ra[1]}. Reading SELECT (`scripts/read_docs.py`, once per pair): `SELECT c.volume_id, c.document_id, c.document_number, c.header, c.dateline, c.source_note, c.body_text, length(c.body_text), c.is_front_matter, c.is_editorial_note, d.date_iso FROM document_cache c LEFT JOIN document_dates d ON d.volume_id = c.volume_id AND d.document_id = c.document_id WHERE c.volume_id = ? AND c.document_id = ?` — `summary_text` and `note_text` were never selected. Raw text of every retrieved document is in `raw/<volume>__<document>.txt`; captured vs body length in `out/reading_log.tsv`.")
w(f"[M-READ2] {ra[3]}")
w()
w("## 6. Quotations (all verified)")
w("Verification (`scripts/verify_quotes.py`): `SELECT body_text, length(body_text) FROM document_cache WHERE volume_id = ? AND document_id = ?`; each quotation is an exact substring of the raw `body_text`, of its whitespace-collapsed form, and of the on-disk raw file. TEI location (`scripts/quotes_in_tei_doc_text.py`): each quotation lies in the document's own text, not in a `<note>` (one, Q14, matches only with whitespace ignored because the extractor writes `( a)` for `(<hi>a</hi>)`).")
w()
for q in qv:
    loc = ql[q["id"]]
    w(f"[M-{q['id']}] {q['id']} — {q['pair']} (offset {q['offset']} of {q['body_chars']} characters; raw={q['raw_substring']}, collapsed={q['collapsed_substring']}, TEI document text={loc['in_doc_text'] or loc.get('in_doc_text_ignoring_whitespace')}, in notes={loc['in_notes']}): \"{q['text']}\"")
w()
w("[M-QUSED] The overview quotes 23 of these 26 passages, from 18 documents (Q1–Q18 with their b parts); Q19–Q21 were verified but then turned into paraphrase so that each finding quotes at most three documents. The collection carries the same 23 as excerpts.")
w()
w("## 7. Collection")
w(f"[M-COLL] `collection.fruscollection`, built and validated by `scripts/build_collection.py`: 41 document entries (no duplicate pair, none apparatus, none Ed2, every pair present in `document_cache` on both keys, every one retrieved whole this session), 23 excerpts (each an exact substring of its document's `body_text`, one per quotation the overview relies on), 7 headings (six findings plus the closing heading), 7 prose blocks (one per finding plus the closing block naming the threads not followed), and a final `archivalSources` generated block. 34 of the 41 are SCOPE documents; 7 are the anchors of M-ANCH. Pairs and edition titles: `out/collection_check.json`.")
w("[M-FIND] Six findings; the overview cites 41 documents in total (the same 41 as the collection, checked by `scripts/check_overview.py`: cited not in collection = none; collection not cited = none; every double-quoted string in the overview is a substring of a verified quotation, except the question's own phrase in a heading).")
w("[M-SYNTH] The overview's 'three departures' from the de facto test are: (1) the Wilson administration's test of constitutional origin, 1913–1920 (M-Q3, M-Q4, M-Q4b, M-Q5; frus1913/d7, frus1913/d1028, frus1917/d378); (2) the Central American treaty rule, 1923–1936 (M-Q9, M-Q11; frus1923v02/d345, frus1936v05/d112); (3) wartime recognition by consultation from December 1943 (M-Q12; frus1943v05/d33). The return to the de facto test is shown by M-Q10 (1930), M-Q14 (1945) and M-Q15 (1948).")
w("[M-COUNTS-DOC] Counts read off documents: frus1914/d544 lists five matters (First–Fifth): the customs convention plus four other undertakings; frus1914/d540 is dated 1914-11-04 and d544 1914-11-12 (eight days, 'a week earlier'); frus1923v02/d472 lists five points (first to fifth); frus1958-60v06/d217: Batista fled on January 1 and recognition was given on January 7, 1959 ('within a week'); frus1945v09/d880: fourteen of sixteen replies; frus1948v09/d7: three factors; frus1914/d1812 (1914-05-26) recognizes Benavides's provisional government of Peru with Argentina, Brazil and Chile; frus1919v02/d720 (1919-08-28) recognizes Leguía as head of the de facto government of Peru.")
w()
w("## 8. Trace table (overview -> memo line)")
w("Line numbers are lines of this file, resolved after writing by `scripts/build_memo.py`.")
w()
open("memo.md", "w").write("\n".join(L) + "\n")
print("memo body lines:", len(L))

TRACE = [
 ("BL1: quotation, 1900 instruction (Document 530)", "M-Q1"),
 ("BL1: quotation, three factors of 1948 (Document 7); 'three factors'", "M-Q15"),
 ("BL1: 'three departures'", "M-SYNTH"),
 ("BL1: quotation 'elected by legal and constitutional means'", "M-Q5"),
 ("BL1: quotation 'a coup d’état or a revolution'", "M-Q9"),
 ("BL1: quotation 'instituted by force'", "M-Q12"),
 ("BL1: 'a customs convention and four other undertakings'", "M-COUNTS-DOC"),
 ("BL1 / Scope: about 2,300 documents (2,333); 137 volumes", "M-SCOPE"),
 ("BL1 / Scope: about 1,200 (1,206) in 51 chapters, dated 1895 to 1950", "M-C"),
 ("BL2: about 1,900 of the 2,300 documents carry a source note (1,929 of 2,333)", "M-CF"),
 ("BL2: Central Decimal File, about 1,700 documents (1,714 decimal rows)", "M-CF-ERA"),
 ("BL2: 8xx.00 about 900 (893); 8xx.01 about 380 (378); 711.12", "M-CF-DEC"),
 ("BL2: Record Group 59 NAID 388; Decimal File 1910–1963; no bundled series NAID/entry/access", "M-CF-GLOSS"),
 ("BL2: Subject-Numeric File 30 documents; POL 16 gloss 1963 only; POL 23-9, POL 15, POL 26", "M-CF-SNF"),
 ("BL2: Central Foreign Policy File 17 documents, 1973–1981", "M-CF-CFPF"),
 ("BL2: lot files 62 D 1, 62 D 430, 63 D 351/66 D 95, 53 D 26, 64 D 199, 64 D 16 (entries, NAIDs, dates, access)", "M-CF-LOT"),
 ("BL2: libraries Kennedy 15 (NAID 1164), Johnson 6 (567979), Carter NSC 2 (623746); unmatched Nixon 15, Carter NSA 9, Whitman 8", "M-CF-LIB"),
 ("BL2: about 240 citations on about 150 documents (240 on 155); none before November 1912", "M-PA"),
 ("BL2: 817.00 11 from 9; 824.00 9 from 7; 816.01 6 from 5; 737.00, 738.00, 738.02; Lot 81 D 64 4 from 1; Lot 61 D 279 3 from 2; Carter NSA 18 from 7", "M-PA-TOP"),
 ("BL3 / How / Scope: all 553 volumes; counts conditional on them", "M-COV"),
 ("BL3: thin 1980s result reflects the published series", "M-THIN"),
 ("BL3: headings read; from 1950 on one recognition heading (Haiti 1950) and one overthrow heading (Cuba 1958–1960)", "M-HEAD-POST"),
 ("BL3: about 290 candidates for 1951–1981 (292)", "M-POST"),
 ("BL3 / F6: only about half on topic (4 of 8 post-1950 sampled; 23 of 40 overall)", "M-REF"),
 ("BL3: Brazil 1964, eight documents; control 27; impossible string none", "M-ABS"),
 ("BL3: Brazil hits all outside the scope", "M-ABS-BR"),
 ("BL3: all but two of the 384 documents dated through 1905 lack a source note", "M-PRE1906"),
 ("BL3: Despatches from U.S. Ministers to Mexico, 1823–1906, file unit NAID 177380741 (inferred shelf)", "M-CF-PRE"),
 ("BL3: 'came to power', 'by force', 'Latin America' in two, 25 and 32 of about 1,200; within a factor of two of the series rate", "M-FF"),
 ("BL3: reading of the false-friend test", "M-FF-READ"),
 ("BL3: 1981–1988 volumes, one candidate (Paraguay 1984); South Atlantic hits off topic; controls 67 and 337; impossible string none", "M-ABS-81"),
 ("Scope: dated 1861–1981 with one earlier stray paper; 1,127 more (T only)", "M-SCOPE"),
 ("Scope: no duplicate second edition in the set", "M-ED2"),
 ("Scope: seven documents outside the set; Wilson's declaration never uses 'recognition'", "M-ANCH"),
 ("Decisions: about a fifth of the 1960s candidates (33 of 149)", "M-DEC60"),
 ("Decisions: about two dozen Grenada/Suriname documents (26)", "M-ABS-CAR"),
 ("Decisions: about a hundred more candidates, roughly a tenth (116; 1,464 vs 1,348)", "M-R3"),
 ("Decisions / How: three of the forty sampled were belligerency or faction recognition; 23 of 40 on topic", "M-REF"),
 ("F1: quotation, Hay 1899 (Document 792)", "M-Q18"),
 ("F1: quotation, Díaz 1877 (Document 222), first passage", "M-Q2"),
 ("F1: quotation, Díaz 1877 (Document 222), condition precedent", "M-Q2b"),
 ("F2: quotation, Wilson declaration (Document 7)", "M-Q3"),
 ("F2: quotation, Huerta not a candidate (Document 1028)", "M-Q4"),
 ("F2: quotation, pledge to recognize (Document 1028)", "M-Q4b"),
 ("F2: quotation, Tinoco circular (Document 378)", "M-Q5"),
 ("F2: Wilson test applied selectively: Peru 1914 (Document 1812) and 1919 (Document 720)", "M-COUNTS-DOC"),
 ("F2: constitutional vocabulary about one in four 1913–1929 (91 of 341) vs one in ten before 1913 (13 of 128)", "M-T-CONST"),
 ("F3: quotation, Haiti recognition terms (Document 544)", "M-Q6"),
 ("F3: quotation, Mole St. Nicholas (Document 544)", "M-Q6b"),
 ("F3: 'five matters'; 'a week earlier'; Mexico's 'five points'", "M-COUNTS-DOC"),
 ("F3: quotation, Hughes 1921 (Document 344)", "M-Q7"),
 ("F3: quotation, Pani 1923 (Document 472)", "M-Q8"),
 ("F4: quotation, Article II (Document 345)", "M-Q9"),
 ("F4: quotation, Stimson 1930 (Document 375)", "M-Q10"),
 ("F4: quotation, 1936 decision (Document 112)", "M-Q11"),
 ("F4: treaty vocabulary about one in five 1930–1942 (66 of 321), almost nowhere else", "M-T-CA"),
 ("F5: quotation, Resolution XXII (Document 33)", "M-Q12"),
 ("F5: quotation, Ecuador security angle (Document 1018)", "M-Q13"),
 ("F5: quotation, El Salvador consultation, fourteen of sixteen (Document 880)", "M-Q14"),
 ("F5: consultation machinery none before 1943, about one in twelve 1943–1950 (36 of 416)", "M-T-CONS"),
 ("F5: Axis about one in six 1943–1950 (65 of 416)", "M-T-AXIS"),
 ("F6: quotation, neither approval nor disapproval (Document 7, 1948)", "M-Q15b"),
 ("F6: Cuba 1959 recognized 'within a week'", "M-COUNTS-DOC"),
 ("F6: quotation, Honduras/Dominican 1963 (Document 363)", "M-Q16"),
 ("F6: quotation, Resolution XXVI statements (Document 141)", "M-Q17"),
 ("F6: quotation, omission on elections (Document 141)", "M-Q17b"),
 ("F6: communism about three in five (174 of 292), human rights about one in twelve (25 of 292)", "M-T-POST"),
 ("How: every quotation verified in the memo and found in the document's own text", "M-QUOTED"),
 ("How / Read next: 41 documents in the collection; every cited document in it", "M-COLL"),
 ("Read next: six findings; cited set equals the collection", "M-FIND"),
]
memo = open("memo.md").read().splitlines()
def line_of(tag):
    for i, l in enumerate(memo, 1):
        if l.startswith(f"[{tag}]") or f"[{tag}]" in l:
            return i
    raise SystemExit("anchor not found: " + tag)
rows = ["| # | overview item (number or quotation) | memo anchor | memo line |", "|---|---|---|---|"]
for k, (item, tag) in enumerate(TRACE, 1):
    rows.append(f"| {k} | {item} | [{tag}] | {line_of(tag)} |")
memo += rows
memo += ["", "## 9. Files", "- `overview.md`, `collection.fruscollection`, `queries.log` (ends with its ELIDED line), this memo.", "- Scripts: `scripts/`; intermediate outputs: `out/`; raw text of every retrieved document: `raw/`; quotations: `quotes/`.", "- Full SQL trace of every statement run by a script: `out/sql_trace.log`."]
open("memo.md", "w").write("\n".join(memo) + "\n")
print("trace rows:", len(TRACE), "| memo lines:", len(memo))

# ---- SQL appendix: every distinct statement scripts ran (VALUES lists and long MATCH args shortened; full text in out/sql_trace.log)
seen = []
for line in open("out/sql_trace.log"):
    s = line.rstrip("\n")
    s = re.sub(r"VALUES \(.*?\)\) SELECT", "VALUES <scope pairs>) SELECT", s)
    if s not in seen: seen.append(s)
memo = open("memo.md").read().splitlines()
memo += ["", "## 10. SQL run by scripts (distinct statements, in order)", "VALUES lists of (volume_id, document_id) pairs are shown as `<scope pairs>`; their full text is in the `out/ff_sql_*.sql` and `out/arch_sql_*.sql` files. Every line below is copied from `out/sql_trace.log`.", ""]
for s in seen: memo.append("- `" + s.replace("`", "'") + "`")
open("memo.md", "w").write("\n".join(memo) + "\n")
print("sql appendix statements:", len(seen))
