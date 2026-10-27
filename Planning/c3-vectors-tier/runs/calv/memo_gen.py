# memo_gen.py: writes memo.md (numbers are recomputed here from the index / scratch tables; read-only on the index)
import sqlite3, json, re, sys, collections
sys.path.insert(0, '/Users/jbotts/frus-analysis/c3/runs/r5')
from final_docs import F, ALL
from quotes import Q
import content as C
R = '/Users/jbotts/frus-analysis/c3/runs/r5/'
RES = "/Applications/FRUS Explorer.app/Contents/Resources/"
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
sc = sqlite3.connect(R + 'scope.db'); st = sqlite3.connect(R + 'struct.db')
scope = set(tuple(l.split()) for l in open(R + 'scope_docs.tsv'))
scope_vols = sorted({v for v, d in scope})

def one(sql, *a): return db.execute(sql, a).fetchone()
cov = one("SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache")
tot, nonapp = one("SELECT count(*), sum(is_front_matter=0 AND is_editorial_note=0) FROM document_cache")
ph = ','.join('?' * len(scope_vols))
n38 = one("SELECT count(*) FROM document_cache WHERE volume_id IN (%s) AND is_front_matter=0 AND is_editorial_note=0" % ph, *scope_vols)[0]
# came-from
have_src = 0; rg59 = 0; dec_after = 0; dec_after_nocls = 0; numf = 0; nosrc_pre = 0
byc = collections.Counter(); dmin = '9999'; dmax = '0'
for v, d in scope:
    r = db.execute("SELECT ds.citation_era, ds.repository, ds.record_group, ds.decimal_class, dd.date_iso FROM document_sources ds LEFT JOIN document_dates dd ON dd.volume_id=ds.volume_id AND dd.document_id=ds.document_id WHERE ds.volume_id=? AND ds.document_id=?", (v, d)).fetchone()
    if r is None:
        continue
    have_src += 1
    era, rep, rgp, dc, di = r
    if rep == 'Department of State' and rgp == '59': rg59 += 1
    if era == 'decimal' and di and di >= '1910-08':
        dec_after += 1
        dmin = min(dmin, di); dmax = max(dmax, di)
        if not dc: dec_after_nocls += 1
        if dc and dc[0] == '8': byc[dc[1:3]] += 1
    if era == 'decimal' and di and di < '1910-08': numf += 1
nosrc = len(scope) - have_src
nosrc_early = sum(1 for v, d in scope if v in ('frus1895p1', 'frus1899', 'frus1900', 'frus1903', 'frus1904') and db.execute("SELECT 1 FROM document_sources WHERE volume_id=? AND document_id=?", (v, d)).fetchone() is None)
# external citations (document level)
ext = db.execute("SELECT e.volume_id, e.document_id, e.anchor, e.decimal_class, dd.date_iso FROM external_citations e LEFT JOIN document_dates dd ON dd.volume_id=e.volume_id AND dd.document_id=e.document_id").fetchall()
ext = [x for x in ext if (x[0], x[1]) in scope]
ext_docs = len({(x[0], x[1]) for x in ext}); ext_anch = collections.Counter(x[2] for x in ext)
ext_min = min(x[4] for x in ext); ext_cls = collections.Counter(x[3] for x in ext)
# decimal-class gloss
dl = json.load(open(RES + 'decimal-class-labels.json'))
ctry = dl['schedules'][0]['countries']
# argument set
arg_in_field = sum(1 for v, d in ALL if (v, d) in scope)
arg_vols = len({v for v, d in ALL})
datel = {}
for v, d in ALL:
    r = db.execute("SELECT dateline, length(body_text), document_number FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    datel[(v, d)] = r
partial = {'frus1877/d222', 'frus1913/d1028', 'frus1913/d1064', 'frus1915/d987', 'frus1923v02/d345', 'frus1944v07/d388', 'frus1945v09/d70', 'frus1948v09/d7', 'frus1952-54v04/d490', 'frus1977-80v15/d276', 'frus1964-68v31/d141', 'frus1961-63v12/d427'}
whole_read = len(ALL) - len(partial)
secs = [l.rstrip('\n').split('\t') for l in open(R + 'scope_sections.tsv')]
sec_counts = []
for v, s, lab in secs:
    ids = [r[0] for r in st.execute("select document_id from sd where volume_id=? and section_id=?", (v, s))]
    n = sum(1 for d in ids if (v, d) in scope)
    path = st.execute("select path from sd where volume_id=? and section_id=? limit 1", (v, s)).fetchone()[0]
    sec_counts.append((v, s, len(ids), n, path))
QUOTED_OVERVIEW = [q for h, p, qs in C.FINDINGS for q, vd in qs]
analysis = open(R + 'analysis_out.txt').read()
phr = open(R + 'phrase_census_out.txt').read()

L = []
w = L.append
w("# Scope memo: recognition of governments that came to power by force in Latin America")
w("")
w("Run r5, 2026-10-25. For the operator. Every number carries its query or script; the overview and the collection are for the historian.")
w("")
w("**Question.** How did the United States decide whether to recognize governments that came to power by force in Latin America, and what did it ask of them before recognizing?")
w("")
w("**Surfaces used.** (1) THE DATABASE: the read-only SQLite copy of the FRUS Explorer search index of 2026-10-25 (opened with `sqlite3 -readonly` or Python `mode=ro`; one proof that a write fails is the second line of the log). (2) THE BUNDLED JSON in the app build 1.0 (1776). (3) THE TEI XML: not used. I made no spelling-variant scan, no apparatus/document split and publish no density; every count of a word below is on the index's flattened body_text, which includes editorial footnotes. (4) [HARVEST]: no path was given, so that surface is unavailable and no harvest count appears.")
w("")
w("## M0. Coverage, and what every count is conditional on")
w("")
w("First command (verbatim, and the output the run required):")
w("")
w("```")
w('sqlite3 "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro" "SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache;"')
w("%d|%d|%d|%d" % cov)
w("```")
w("")
w("Second command (read-only proof): `sqlite3 -readonly DB \"BEGIN; CREATE TABLE zz(x); ROLLBACK;\"` failed with: Error in 3rd command line argument: attempt to write a readonly database.")
w("")
w("Every count below is conditional on this index: all %d volumes of the series are present (the full series is 553), %s documents, of which %s are front matter or editorial notes and are excluded unless stated. SQL: `SELECT count(*), sum(is_front_matter=0 AND is_editorial_note=0) FROM document_cache;` gives %d | %d. The non-apparatus total, %s, is the denominator of \"the whole series\" below." % (cov[0], format(cov[1], ','), format(tot - nonapp, ','), tot, nonapp, format(nonapp, ',')))
w("")
w("## M1. The scope I chose, and how I found it")
w("")
w("**M1.1 Two tiers.** (a) THE FIELD: documents under an editors' section heading that names recognition, its refusal or withholding, or continuance of diplomatic relations with a Latin American or Caribbean government that took power by revolution, coup or other irregular means; 1895-09-06 to 1950-06-01 (document dates). (b) THE ARGUMENT: the %d documents I read and cite, from %d volumes, 1877 to 1979; %d of them lie inside the field, %d outside it (policy statements, and every case after 1950, where the editors' headings stop naming recognition)." % (len(ALL), arg_vols, arg_in_field, len(ALL) - arg_in_field))
w("")
w("**M1.2 How found.** First the editors' own headings, because the instructions say my modern phrasing is usually absent. The index stores each volume's table of contents as JSON in volume_structures; `build_struct.py` walks it and writes struct.db (document to section path), 314,616 document rows. I searched headings with `frus_documents MATCH 'header:recognition'` (list in queries.log) and by regular expression over section paths (recognition, de facto, coup, junta, revolution, overthrow, and so on, crossed with Latin American country names), which produced scratch_struct_sections.tsv (106 sections). I then curated those by hand to the 62 sections in Appendix A (scope_sections.tsv), dropping false friends (meat-inspection labels, a Japanese consul-general, blockades, naturalization certificates, military-mission agreements, the Panama separation of 1903, non-intervention sections that do not mention recognition).")
w("")
w("**M1.3 Size.** `scope_docs.tsv` lists the documents of those 62 sections that are not front matter and not editorial notes: **%s documents in %d volumes** (sum of Appendix A column n). The same 38 volumes hold %s non-apparatus documents, so the field is %s of %s (%.1f percent) of them, and %s of %s (%.2f percent) of the whole series. SQL for the 38-volume denominator: `SELECT count(*) FROM document_cache WHERE volume_id IN (<the 38 ids of Appendix A>) AND is_front_matter=0 AND is_editorial_note=0;` = %s." % (format(len(scope), ','), len(scope_vols), format(n38, ','), format(len(scope), ','), format(n38, ','), 100 * len(scope) / n38, format(len(scope), ','), format(nonapp, ','), 100 * len(scope) / nonapp, format(n38, ',')))
w("")
w("Existence and exclusion check for every pair (script scopedb.py and the loop in the log): `SELECT is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?`; no pair missing; none front matter or editorial note.")
w("")
w("**M1.4 Second editions.** None of the 38 field volumes or 31 argument volumes ends in Ed2, so frus1951-54IranEd2 and frus1969-76ve15p2Ed2 are not involved; nothing needed suppressing.")
w("")
w("**M1.5 Period basis.** Decades below use document_dates.date_iso (the index's per-document date). I did not read frus:doc-dateTime-min from the TEI and did not check how the index derives date_iso. I did not use the volume's series year.")
w("")
w("## M2. What I measured")
w("")
w("### M2.1 Controls and the false-friend test (script analysis.py; its output is analysis_out.txt and is pasted here)")
w("")
w("```")
w(analysis.rstrip())
w("```")
w("")
w("Reading: the positive control (\"department of state\") is found in 552 of 553 volumes; the one volume without it is frus1919Parisv05 (89 documents; not a field volume). The negative control is found in 0 rows, and 0 of the %d field documents and 0 of 38,510 others." % len(scope))
w("")
w("False-friend test for the question's own term \"recogni\": it appears in 721 of 1,667 field documents (43.3 percent) against 4,062 of 38,510 other non-apparatus documents of the same 38 volumes (10.5 percent), about 4.1 times as often; the control phrase \"Department of State\" runs the other way, 236 of 1,667 (14.2 percent) against 8,830 of 38,510 (22.9 percent). So the term discriminates and is not just measuring the corpus. It is high in the field partly by construction, since the field is chosen by headings that name recognition; the comparison is a check, not a finding.")
w("")
w("### M2.2 Phrase counts with their literal shares (script phrase_census.py; output phrase_census_out.txt, pasted)")
w("")
w("```")
w(phr.rstrip())
w("```")
w("")
w("Each family is a census of every document the index returned (all under 300), re-tested by regular expression over header, dateline, source note and body collapsed to single spaces, case-insensitive. STRICT = the words with single spaces; TOLERANT = any run of space, hyphen, comma, parenthesis or full stop between the words (and inflections where stated). Published: **\"Estrada Doctrine\": 28 documents in 18 volumes (index), literal 27 of 28 strict, 27 of 28 tolerant**; the one miss is frus1945v09/d55, a true instance with the name in quotation marks (\"Estrada\" doctrine), which my tolerant pattern does not allow. **\"Tobar doctrine\": 1 document, literal 1 of 1 strict and tolerant** (frus1932v05/d546; the editors' note there defines it as Tobar's 1907 call for non-recognition of governments sprung from revolutions against the constitution). A 1.000 share tests the stemmer, not the referent: all 28 and the 1 were read in their context to see that they name the doctrines. The third family in the file (non-recognition, 701 documents in 219 volumes, 698 of 701 strict, 701 of 701 tolerant) is corpus-wide and mostly non-Latin American, and I publish no figure from it. A first run of this script put a defective \"recognition of the de facto government\" family and a defective tolerant pattern in the log; both were removed and the script was re-run (the log keeps both runs).")
w("")
w("### M2.3 Census inside the field (analysis_out.txt)")
w("")
w("Of the %d field documents, STRICT / TOLERANT: \"de facto\" 138 / 138; \"free election(s)\" 23 / 23; \"constitutional government/order/methods/procedures/processes\" 66 / 66; \"international obligation(s)\" 69 / 69; \"civil liberties\" 1 / 1; a form of \"consult\" 79 / 137 (strict is \"consultation\"). These are censuses of the field, not samples, so no sampled share is needed; they were used to decide what to read, and none appears as a figure in the overview." % len(scope))
w("")
w("### M2.4 Decade shape of the field (analysis_out.txt, DECADE TABLE)")
w("")
w("Raw count, per 1,000 of that decade's dated non-apparatus documents, and the top volume's share of the numerator (periodised on document_dates.date_iso): 1890s 50 (5.1 per 1,000; frus1899 holds 46 of 50, 92 percent); 1900s 40 (3.9; frus1900 13 of 40, 32 percent); 1910s 534 (17.3; frus1914 119 of 534, 22 percent); 1920s 241 (11.8; frus1920v03 70 of 241, 29 percent); 1930s 314 (7.8; frus1937v05 111 of 314, 35 percent); 1940s 485 (6.4; frus1944v07 187 of 485, 39 percent); 1950s 3 (0.1; frus1950v02 3 of 3). The 1890s rate is one volume (Venezuela, 1899); the 1950s figure reflects only that the editors' headings stop naming recognition, not a fall in cases. The overview uses no decade rate.")
w("")
w("## M3. The archival scope")
w("")
w("### M3.1 CAME-FROM channel, over the field (%d documents, 38 volumes) [index: document_sources]" % len(scope))
w("")
w("SQL (as logged): `select count(*), sum(ds.decimal_class is not null), sum(ds.citation_era='decimal') from scope s join m.document_sources ds on ds.volume_id=s.volume_id and ds.document_id=s.document_id` with scope.db holding the field and the index attached read-only as m.")
w("")
w("- Field documents with a source row: **%d of %d**; without: %d (the %d documents of 1895 to 1904 in the field have no source row, nor do %d later ones)." % (have_src, len(scope), nosrc, nosrc_early, nosrc - nosrc_early))
w("- Source is Department of State, Record Group 59: **%d of %d** (%.1f percent)." % (rg59, len(scope), 100 * rg59 / len(scope)))
w("- Of those, decimal-era file numbers on documents dated 1910-08 or later: **%d of %d** (%.1f percent, about fifteen in sixteen), dated %s to %s; %d of the %d carry no parsed decimal class. Another **%d** documents, all frus1907p2 (Honduras, 1907), cite the older numerical file (File No. 3691/485, 6775/52, 7357/2 and so on). One carries a lot-file source (frus1948v09/d115, whose lot_file_norm reads NO, a parse artefact for \"Lot No. 64-D-563\")." % (dec_after, len(scope), 100 * dec_after / len(scope), dmin[:10], dmax[:10], dec_after_nocls, dec_after, numf))
w("- By country number (class 8, internal affairs of states; gloss from decimal-class-labels.json schedule 1910-1949, applied only because every one of these documents is dated 1910 to 1949 and the gate `coverage.glossableYears` covers it): " + "; ".join("%s %s %d" % (k, ctry.get(k, '?'), n) for k, n in byc.most_common(8)) + ". Haiti (%d) exceeds Bolivia (%d) by %d." % (byc['38'], byc['24'], byc['38'] - byc['24']))
w("- The country-and-class counts came from `decimal_gloss.py` (first version mis-parsed the country digits and was discarded) and the corrected query logged as `select substr(ds.decimal_class,1,1) cls, substr(ds.decimal_class,2,2) country, count(*) ...`.")
w("- Series naming: collection-authority.json holds `txt:department of state|central decimal file 1910-1929`, record group 59, with no NAID; no bundled table gives the Central Decimal File an identifier, entry number, extent or access status. UNRESOLVED OFFLINE, said so in the overview.")
w("")
w("Volume-level, JSON (usage_scope.py; **volume-scoped, all source notes of the 38 volumes, not only field documents**): collection-usage-index.json counts 33,554 notes in the category centralDecimalFile, 174 previouslyPublished, 95 namedFileSeries, 73 unrecognized, 19 lotFile and 8 presidentialLibrary across the 38 volumes, and 16 authority collections (114 notes), the largest 84 for \"IO Files\". It adds nothing to the field-level picture and is not used in the overview.")
w("")
w("### M3.2 POINTED-AT channel, over the field [index: external_citations]")
w("")
w("SQL (logged): `select count(distinct e.volume_id||'/'||e.document_id), count(*), min(s.volume_id), max(s.volume_id) from scope s join m.external_citations e on e.volume_id=s.volume_id and e.document_id=s.document_id` gives 56 | 65 | frus1921v01 | frus1950v02. All 65 have anchor `centralFileClass` (query `select e.anchor, count(*) ... group by 1`); none is a lot file or a library anchor. **56 of %d field documents** (%.1f percent, about one in thirty) have such a citation. Earliest dated document with one: %s. Most cited classes (`select e.decimal_class, count(*) ... group by 1 order by 2 desc`): 817.00 (11 citations, 2 volumes), 824.00 (7, 4 volumes), 816.01 (6, 4 volumes), then 814.00 (3), 816.00 (3), 817.51 (3), 838.01 (3). By the stated limits of this channel: it has no row before 1910-12-06, stores the citation fragment, and holds lot, library and decimal anchors only." % (len(scope), 100 * 56 / len(scope), ext_min))
w("")
w("Volume-level, JSON (extcit_scope.py; **volume-scoped, all footnotes of the 38 volumes; 30 of the 38 are in the index's volume list**): 1,079 citations to central-file classes in 465 classes; lot or library targets: 12 citations of 7 targets (lots 53 D 250, 60 D 137, 53 D 26, 53 D 444, 56 D 625, 66 D 95 and Hyde Park). The database query `select ... from m.external_citations e where e.lot_file_norm in ('53D26','53D444','53D250','60D137','66D95','56D625') and e.volume_id in (select distinct volume_id from scope)` places every one of them in frus1950v02 (documents d359, d460, d329, d335, d148, d120, d377, d402, d409, d128), a volume that is in the field only through three Haiti documents; none is a recognition source, so the overview calls them \"other subjects\". Lot 56 D 625 is the Office of Chinese Affairs: a creator heading that is a decoy for this topic. The two channels are two numbers over different scopes and are never summed.")
w("")
w("### M3.3 What the bundled JSON resolves [JSON]")
w("")
w("- **Lot 64 D 563.** central-files-index.json lotFiles row: lotNumber 64D563, naId 1136548, \"Chronological Files\", hmsMlrEntryNumbers A1 558-D, recordGroup 59, matchType control. series-facts-index.json (byNaId, decoded through its legend): creator \"Department of State. Policy Planning Council.\" (a later body: the creator heading is NARA's and I did not verify it), accessStatus Unrestricted, useStatus Unrestricted, extent 5 linear feet 3 inches, 1947 to 1962. lot-claimants-index.json lists **12 claimant series** for the lot (A1 558-A Numbered Staff Studies naId 1151288, 1947-1949; -B Subject Files 1151314; -CA Country Files 1151315; -CB Area Files 7432703; -D Chronological Files 1136548; -E Record Copies Files 1151881; -F Member Chronological Files 1154560; -G Working Papers 1154562; -H Meeting Minutes 1154583; -I Notes of Meetings 7433609; -J Records Relating to Meetings with the Department of Defense and the Joint Chiefs of Staff 7433611; -L Speeches and Articles 7433905). Series 1151288: creator Policy Planning Staff, Unrestricted, 1 linear foot 9 inches, 1947-1949. That the PPS paper sits in 1151288 is **my inference from its being a numbered paper (PPS/47)**; the data does not say which of the twelve holds it.")
w("- **Numerical file (pre-1910).** central-files-index.json numericalFile: microfilm M862, seriesNaId 654171, 1,261 reels; the reels holding the cited cases: 3691/485 in 'Numerical File: 3691/400-End of case' (19503073); 6775/52 in 'Numerical File: 6747-6775/80' (19748403); 7357 items 1 to 215 in 'Numerical File: 7357-7357/215' (19794147 and 19792913). series-facts-index has no row for 654171: extent, dates and access UNRESOLVED.")
w("- **Presidential libraries.** presidential-library-catalog.json: Johnson Library LBJ-NSF naId 567979 \"National Security Files\"; Nixon RN-NSF naId 572235 \"National Security Files (Nixon Administration)\" (the footnotes cite \"NSC Files\"; I take them to be the same, flagged as an inference); Kennedy Library JFK-4 naId 1164 \"National Security Files\" (not cited by a field or argument document); Eisenhower Library: no title containing \"Clean\" (the cited \"Project Clean Up Records\" is UNRESOLVED). Access status is not carried by that catalog.")
w("- **Subject-numeric file.** subject-numeric-labels.json, schedule 1963: subjects POL 16 = \"INDEPENDENCE. RECOGNITION.\" (category POL = Political Affairs & Relations; area DOM REP = Dominican Republic); schedule 1964-1973: POL 16 has no label. So only frus1961-63v12/d363 (dated 1963, \"POL 16 DOM REP\") is glossed; the 1964 to 1966 files (\"POL 16 ARG\") are not, by the file's own gate (`keyOutsideGlossableYears: no-gloss`).")
w("- **Central Foreign Policy File (1973 on)** and **the subject-numeric file as a series:** named in collection-authority.json and volume-sources-index.json text entries; no identifier. UNRESOLVED OFFLINE.")
w("- **Reach before 1940.** series-facts-index.json byNaId holds 698 series; 11 have an inclusive start year before 1940; 1 ends before 1940. (The briefing said 11 of 695; I measured 11 of 698.)")
w("- Not used: accession-series-index.json (its Central Foreign Policy and Subject-Numeric entries are Record Group 286, the Agency for International Development), lot-claimants for other lots, curated-lot-resolutions.json (no row for any lot here).")
w("")
w("### M3.4 Decimal class gate")
w("")
w("decimal-class-labels.json: glossableYears 1910-1949, 1950-1959, 1960-1963; renumbered at 1950; keys outside those years have no gloss. Every field document I glossed (country numbers in M3.1) is dated 1911 to 1949 and is glossed under the 1910-1949 schedule (country 38 = Haiti, 24 = Bolivia, 16 = El Salvador, 18 = Costa Rica, 12 = Mexico, 35 = Argentine Republic/Argentina, 17 = Nicaragua, 39 = Dominican Republic, 23 = Peru, 34 = Paraguay, 22 = Ecuador, 14 = Guatemala, 31 = Venezuela, 37 = Cuba, 15 = Honduras, 32 = Brazil). The three Haiti documents of 1950 (frus1950v02) are outside this schedule and I did not gloss them.")
w("")
w("## M4. Things searched for and not found (with controls)")
w("")
w("- **Resumption of relations with Peru's junta, August 1962.** `find.py '(\"resumption\" OR \"resume\" OR \"resumed\") AND relations AND Peru AND (junta OR Pérez OR Godoy OR Lindley)'` over frus1961-63v12 returned the Peru papers d421, d427, d423 and d424; the same with \"recognized\" over frus1961-63v10-12mSupp returned d109, d102 and d105 (not about Peru's junta); a further search over v12 for resumption in August returned d421, d424 and two unrelated papers (d148, d29). d421, d423, d424 and d427 were read; none records the act. Positive control: the same query form returns the Peru papers, so it can return rows. Not a research negative: the shelf is the Department's file 723.00 (the cited file numbers are 723.00/7-3062 and 723.00/8-1662).")
w("- **Latin American governments' own reasoning.** M2.2: the doctrines appear only inside Department reports.")
w("- **Unsearched:** 1861 to 1876; 1981 onward (the frus1981-88 volumes are in the index and were not read); the Eastern-hemisphere cases.")
w("- **Post-1950 cases read (eleven):** Guatemala 1954 (frus1952-54v04/d490), Cuba 1959 (frus1958-60v06/d217), Peru 1962 (frus1961-63v12/d421, d423, d427), Honduras 1963 (frus1961-63v10-12mSupp/d160), Dominican Republic 1963 (frus1961-63v12/d363), Brazil 1964 (frus1964-68v31/d206), Argentina 1966 (d135, d141), Peru 1968 (d515), Chile 1973 (frus1969-76v21/d358, d360), Bolivia 1978 (frus1977-80v24/d132), Nicaragua 1979 (frus1977-80v15/d276). Volume patterns searched for them: frus1952-54v04, frus1958-60v06, frus1961-63v12, frus1961-63v10-12mSupp, frus1964-68v3%, frus1969-76ve1%, frus1969-76v21, frus1977-80v%, frus1977-80v15, frus1977-80v24 (find.py lines in queries.log). Panama 1968, Argentina 1962 and 1976, Bolivia 1964, 1971 and 1980, Ecuador 1963, Guatemala 1963 and Uruguay 1973 were NOT searched and are not claimed absent.")
w("- **Thin results.** The post-1950 part of the argument is eleven cases read from a search, not a census; the field (1895 to 1950) is thin in the 1950s by construction (M2.4). The index holds the whole series, so none of this is a partial-library effect, but the series is itself a selection.")
w("")
w("## M5. Quotations (each verbatim, each verified against its document)")
w("")
w("Verification SELECT for every row: `SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?`, then the test `quote in body_text` (exact, raw) in `quotes.py`. Result: **%d of %d verified raw** (all %d also verify after whitespace collapse). The retrieving SELECT for reading is the one in show.py / ctx.py: `SELECT header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?`. Rows marked O are used in the overview and as excerpts in the collection (%d); the others are verified and kept on file." % (len(Q), len(Q), len(Q), len(QUOTED_OVERVIEW)))
w("")
w("| id | pair | in overview | quotation |")
w("|---|---|---|---|")
for qid, v, d, t in Q:
    w("| %s | %s/%s | %s | %s |" % (qid, v, d, 'O' if qid in QUOTED_OVERVIEW else '', t.replace('|', '/')))
w("")
w("Q45 comes from an editors' footnote (the editors quote Rostow's covering memorandum) inside the body_text of frus1964-68v31/d515; body_text includes footnotes. Q48 and Q46 are in the body of the telegrams. Q15 is the text of Article II as Hughes quoted it.")
w("")
w("## M6. Reading accounting")
w("")
w("Documents retrieved whole (captured text length equals length(body_text) in characters; `ledger.py`, table reading_ledger.tsv): **%d of %d**. Read end to end on screen: **%d**; read in part (windows around matches, or the first part, or head and tail): **%d** (%s). Quoted in the overview: **%d** documents (%d quotations); quotations verified in all: %d. The raw text of every document is in the run's texts/ folder, one file per pair; the reading SELECT and the regular expressions used for windows are logged by ctx.py, show.py and sec.py in queries.log." % (len(ALL), len(ALL), whole_read, len(partial), ", ".join(sorted(partial)), len({vd for h, p, qs in C.FINDINGS for q, vd in qs}), len(QUOTED_OVERVIEW), len(Q)))
w("")
w("Characters, not bytes: length(body_text) counts characters; the captured files are compared in characters (Python len on the decoded text), not with wc -c.")
w("")
w("## M7. TRACE TABLE (one row per number and per quotation in the overview)")
w("")
w("| # | in the overview | value | memo line | source |")
w("|---|---|---|---|---|")
rows = [
 ("T1", "\"fifty-six documents in 31 volumes\"", "%d documents; %d volumes" % (len(ALL), arg_vols), "M1.1, Appendix B", "final_docs.py; `final_docs.py` existence check"),
 ("T2", "\"about seventeen hundred documents ... in 38 volumes\"", "%d of %s non-apparatus documents; 38 of 553 volumes" % (len(scope), format(nonapp, ',')), "M1.3", "scope_docs.tsv; SQL in M1.3"),
 ("T3", "\"1877 to 1950\", \"up to 1979\", \"1895 to 1950\"", "argument dated 1877-05-16 to 1979-07-15; field 1895-09-06 to 1950-06-01", "M1.1, Appendix B", "datelines; analysis.py date query"),
 ("T4", "\"a field of 62 sections\"", "62", "Appendix A", "scope_sections.tsv"),
 ("T5", "\"553 volumes, 312,169 documents\"", "553; %s" % format(nonapp, ','), "M0", "coverage SQL; `SELECT count(*), sum(is_front_matter=0 AND is_editorial_note=0)`"),
 ("T6", "\"About fifteen in sixteen\" cite the central decimal file", "%d of %d (%.1f percent)" % (dec_after, len(scope), 100 * dec_after / len(scope)), "M3.1", "document_sources join"),
 ("T7", "\"Haiti, Bolivia, El Salvador, Costa Rica and Mexico\"", "%d, %d, %d, %d, %d documents" % (byc['38'], byc['24'], byc['16'], byc['18'], byc['12']), "M3.1", "decimal-class country query"),
 ("T8", "\"dates from 1911 into 1950\"", "%s to %s" % (dmin[:10], dmax[:10]), "M3.1", "document_dates join"),
 ("T9", "\"Ten papers of 1907 ... M862 ... 654171 ... case 7357 ... 19794147 and 19792913\"", "10; M862; 654171; reels as listed", "M3.1, M3.3", "document_sources; central-files-index.numericalFile"),
 ("T10", "\"Papers before 1907 in the field carry no file number\"", "%d of 79 documents of 1895 to 1904 lack a source row" % nosrc_early, "M3.1", "left join document_sources"),
 ("T11", "\"twelve series, 1947 to 1962, A1 558-A through A1 558-L\"", "12", "M3.3", "lot-claimants-index.json"),
 ("T12", "\"1151288, 1947 to 1949, unrestricted\"; \"1136548, A1 558-D, 1947 to 1962, unrestricted\"", "as stated", "M3.3", "series-facts-index.json; central-files-index.json"),
 ("T13", "\"567979\"; \"572235\"", "as stated", "M3.3", "presidential-library-catalog.json"),
 ("T14", "\"Only 11 of the 698 series ... before 1940\"", "11 of 698", "M3.3", "series-facts-index.json byNaId y0"),
 ("T15", "\"about one document in thirty\"; \"none is earlier than 1921\"", "56 of %d (%.1f percent); earliest %s" % (len(scope), 100 * 56 / len(scope), ext_min[:10]), "M3.2", "external_citations join"),
 ("T16", "\"Nicaragua (817.00), Bolivia (824.00) and El Salvador (816.01)\"", "11, 7, 6 citations", "M3.2", "external_citations group by decimal_class"),
 ("T17", "\"about eleven hundred citations ... some 465 classes ... a dozen citations to lot files and one library\"", "1,079 in 465 classes; 12 citations of 7 targets", "M3.2", "extcit_scope.py"),
 ("T18", "\"read eleven cases\"", "11", "M4", "list in M4"),
 ("T19", "\"28 documents in 18 volumes and in 1 document\"", "28 / 18; 1", "M2.2", "phrase_census_out.txt"),
 ("T20", "\"552 of 553 volumes\"", "552", "M2.1", "positive-control SQL"),
 ("T21", "\"Haiti alone supplies more papers\"", "%d > %d" % (byc['38'], byc['24']), "M3.1", "country query"),
 ("T22", "\"1861 to 1876, and everything after 1980\" unsearched", "statement of omission", "M4", "no query"),
 ("T23", "dates and attributions in the findings paragraphs", "datelines of the cited documents", "Appendix B", "document_cache.dateline"),
]
for r in rows: w("| " + " | ".join(r) + " |")
for qid, vd in [(q, vd) for h, p, qs in C.FINDINGS for q, vd in qs]:
    w("| %s | quotation, finding %d | pair %s | M5 row %s | verification SELECT in M5 |" % ('TQ' + qid[1:], [i for i, (h, p, qs) in enumerate(C.FINDINGS, 1) if any(q == qid for q, _ in qs)][0], vd, qid))
w("")
w("## M8. Flags, errors, and how to read the thin parts")
w("")
w("- The overview's three-paragraph opening, its two lists and the archival counts were written from M3. The two channels (came-from; pointed-at) are never summed.")
w("- **Inferences flagged:** that PPS/47 sits in series 1151288; that the Nixon \"NSC Files\" are the catalog's National Security Files; that the Honduras 1907 numbered cases map to the reels named. **Creator headings:** series-facts creators for 1136548 (\"Policy Planning Council\") and for lot 56 D 625 are NARA's; not verified.")
w("- **Errors in my own passes (kept in the log):** analysis.py's first run printed two ERR lines (the controls, tried through an attached database, failed with `no such column`); I re-ran the controls on a plain connection (M2.1). phrase_census.py's first run included a badly framed AND family and a tolerant pattern that was narrower than the strict one; both were fixed (M2.2). decimal_gloss.py's first version took the first two digits as the country and glossed Haiti as Egypt; discarded. chapters.db (a rowid-order chapter map) was abandoned because older volumes list chapter headings after their documents; struct.db from volume_structures replaced it.")
w("- **Date-order and the Peru, Argentina, Honduras and Dominican cases:** the collection puts Honduras (Oct 1963) before the December 1963 reversal; the printed volume prints the Honduran coup documents in a microfiche supplement, cited as the Microfiche Supplement.")
w("- **Not claimed:** I do not claim the field is complete for 1895 to 1950 (it is the set of sections I judged to name recognition of a government that took power irregularly) nor that no other recognition decision exists in the series.")
w("")
w("## Appendix A. The 62 sections of the field")
w("")
w("| volume | section | documents in section | in field (non-apparatus) | editors' heading path |")
w("|---|---|---|---|---|")
for v, s, n, nf, path in sec_counts:
    w("| %s | %s | %d | %d | %s |" % (v, s, n, nf, path[:150].replace('|', '/')))
w("")
w("Total in field: %d." % sum(x[3] for x in sec_counts))
w("")
w("## Appendix B. The %d argument documents" % len(ALL))
w("")
w("Order is the collection's. 'In field' says whether the pair is in the 62 sections. Read: W = end to end, P = in part.")
w("")
w("| finding | pair | edition document number | dateline | length (chars) | in field | read | quoted in overview |")
w("|---|---|---|---|---|---|---|---|")
for i, (h, docs) in enumerate(F, 1):
    for v, d, date in docs:
        dlx, ln, num = datel[(v, d)]
        qs = [q for q, vd in [(q, vd) for hh, pp, qq in C.FINDINGS for q, vd in qq] if vd == v + '/' + d]
        w("| %d | %s/%s | %s | %s | %d | %s | %s | %s |" % (i, v, d, num, (dlx or '').replace('|', '/').replace('\n', ' ')[:60], ln, 'yes' if (v, d) in scope else 'no', 'P' if (v + '/' + d) in partial else 'W', ', '.join(qs)))
w("")
w("## Appendix C. Files in the run directory")
w("")
w("memo.md (this file); overview.md; collection.fruscollection; queries.log; analysis.py, analysis_out.txt; phrase_census.py, phrase_census_out.txt; build_chapters.py (abandoned) and build_struct.py, struct.db; scope_sections.tsv, scope_docs.tsv, scope.db, scopedb.py; core_docs.txt (the first, shorter list of argument documents, superseded by final_docs.py); final_docs.py; quotes.py (the 53 quotations and their verifier); ledger.py, reading_ledger.tsv; usage_scope.py, extcit_scope.py, decimal_gloss.py; find.py, ctx.py, show.py, sec.py (search and reading helpers; each logs its own SQL); q.sh, qa.sh, qc.sh, qs.sh (SQL wrappers that log); content.py, notes.py, build_deliverables.py, build_report.txt (builds and checks the overview and the collection); memo_gen.py (builds this file); scratch_struct_sections.tsv, scratch_headings_latam_events.tsv (candidate lists); texts/ (raw text of every document read).")
w("")
w("## Appendix D. Search expressions used (from queries.log, find.py lines)")
w("")
w("```")
for line in open(R + 'queries.log'):
    if line.startswith('find.py:'):
        m = re.search(r"MATCH (.*?) AND d\.is_front_matter", line)
        v = re.search(r"LIKE (.*?) ORDER BY", line)
        w("MATCH %s ; volume LIKE %s" % (m.group(1) if m else '?', v.group(1) if v else '?'))
w("```")
w("")
w("## Appendix E. Reproduction of the checks run by build_deliverables.py")
w("")
w("```")
w(open(R + 'build_report.txt').read().rstrip())
w("```")
w("")
w("## Appendix F. Ledger statement")
w("")
w("The overview says (and this memo confirms) that every quotation in the overview and every excerpt in the collection is one of the verified rows of M5, and that every document the overview cites is in the collection: `build_report.txt` lines 1 to 6.")
w("")
open(R + 'memo.md', 'w').write('\n'.join(L) + '\n')
print('memo written', len(L), 'lines')
