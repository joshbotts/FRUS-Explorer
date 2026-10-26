#!/usr/bin/env python3 -I
"""Refuter: re-run the memo's SQL for the headline numbers of overview.md (cell r1).
Opens the index copy read-only and attaches the session's work/scope.db read-only."""
import sqlite3, time, csv, sys, os

DB = "/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
SCOPE = "/Users/jbotts/frus-analysis/c3/runs/r1/work/scope.db"
RUN = "/Users/jbotts/frus-analysis/c3/runs/r1"

con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
con.execute(f"ATTACH 'file:{SCOPE}?mode=ro' AS s")

def q(label, sql, params=()):
    t = time.time()
    rows = con.execute(sql, params).fetchall()
    print(f"\n### {label}  ({time.time()-t:.1f}s)\n{sql.strip()[:400]}{'...' if len(sql.strip())>400 else ''}")
    for r in rows[:60]:
        print("  ", r)
    if len(rows) > 60: print("   ...", len(rows), "rows")
    sys.stdout.flush()
    return rows

FAMC = "NEAR(recogn* government*, 6) OR NEAR(recogn* regime*, 6) OR NEAR(recogn* junta, 6) OR NEAR(recogn* administration*, 6)"
SCOPEF = "sd.latam=1 AND sd.numbered=1 AND sd.apparatus=0 AND sd.ed2_dup=0"

# Canary [N01]
q("N01 canary", "SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache")

# scope.db sanity: one row per document_cache row?
q("scope_docs row count vs document_cache", "SELECT (SELECT COUNT(*) FROM s.scope_docs), (SELECT COUNT(*) FROM document_cache)")
q("scope_docs rows not in document_cache", "SELECT COUNT(*) FROM s.scope_docs sd LEFT JOIN document_cache c ON c.volume_id=sd.volume_id AND c.document_id=sd.document_id WHERE c.volume_id IS NULL")
# N02 breakdown
q("N02 breakdown", "SELECT COUNT(*), SUM(apparatus=1), SUM(apparatus=0 AND numbered=0), SUM(apparatus=0 AND numbered=1 AND ed2_dup=1), SUM(apparatus=0 AND numbered=1 AND ed2_dup=0) FROM s.scope_docs")
# check flags against document_cache
q("N02 apparatus flag agrees with document_cache flags", "SELECT COUNT(*) FROM s.scope_docs sd JOIN document_cache c ON c.volume_id=sd.volume_id AND c.document_id=sd.document_id WHERE sd.apparatus <> (c.is_front_matter=1 OR c.is_editorial_note=1)")
q("N02 numbered flag agrees with document_number", "SELECT COUNT(*) FROM s.scope_docs sd JOIN document_cache c ON c.volume_id=sd.volume_id AND c.document_id=sd.document_id WHERE sd.numbered <> (COALESCE(c.document_number,'')<>'')")
q("N02 ed2_dup volumes", "SELECT volume_id, COUNT(*) FROM s.scope_docs WHERE ed2_dup=1 GROUP BY 1")

# N03 scope
q("N03 scope by basis", "SELECT lat_basis, COUNT(*), SUM(numbered=1 AND apparatus=0 AND ed2_dup=0) FROM s.scope_docs WHERE latam=1 GROUP BY 1")
q("N03 scope volumes", "SELECT COUNT(DISTINCT volume_id), SUM(b='hemisphere volume'), SUM(b='latam section') FROM (SELECT volume_id, MIN(lat_basis) b FROM s.scope_docs WHERE latam=1 AND numbered=1 AND apparatus=0 AND ed2_dup=0 GROUP BY volume_id)")
q("N03 scope date span", "SELECT MIN(date_iso), MAX(date_iso), SUM(date_iso IS NULL), COUNT(*) FROM s.scope_docs WHERE latam=1 AND numbered=1 AND apparatus=0 AND ed2_dup=0")
q("N03b decades", "SELECT decade, COUNT(*) FROM s.scope_docs WHERE latam=1 AND numbered=1 AND apparatus=0 AND ed2_dup=0 GROUP BY decade")
# date_iso in scope_docs agrees with document_dates?
q("scope_docs.date_iso vs document_dates (scope docs)", "SELECT SUM(sd.date_iso IS NOT d.date_iso), COUNT(*) FROM s.scope_docs sd LEFT JOIN document_dates d ON d.volume_id=sd.volume_id AND d.document_id=sd.document_id WHERE sd.latam=1 AND sd.numbered=1 AND sd.apparatus=0 AND sd.ed2_dup=0")

# N04 family C
q("N04 family C count", f"SELECT COUNT(*) FROM frus_documents f JOIN s.scope_docs sd ON sd.volume_id=f.volume_id AND sd.document_id=f.document_id WHERE frus_documents MATCH '{FAMC}' AND {SCOPEF}")
q("N04 by stratum", f"SELECT sd.lat_basis, COUNT(*) FROM frus_documents f JOIN s.scope_docs sd ON sd.volume_id=f.volume_id AND sd.document_id=f.document_id WHERE frus_documents MATCH '{FAMC}' AND {SCOPEF} GROUP BY 1")

# N05 sample of forty: regenerate the hit list in text order and the evenly spaced indices
hits = q("N05 hit list (first 3 shown)", f"SELECT f.volume_id, f.document_id, sd.date_iso FROM frus_documents f JOIN s.scope_docs sd ON sd.volume_id=f.volume_id AND sd.document_id=f.document_id WHERE frus_documents MATCH '{FAMC}' AND {SCOPEF} ORDER BY f.volume_id, f.document_id")
n = len(hits)
idx = [round(i*(n-1)/39) for i in range(40)]
sample = [hits[i] for i in idx]
print("\n### N05 regenerated sample (n=%d):" % n)
for i, s_ in zip(idx, sample): print("  ", i, s_[0]+"/"+s_[1], s_[2])
# compare with the session's sample files
for fn in ["C_recognition_near_government.tsv", "C_recognition_near_government.referent.tsv"]:
    p = os.path.join(RUN, "work", "shares", fn)
    with open(p, newline="") as fh:
        rows = list(csv.reader(fh, delimiter="\t"))
    print(f"\n### {fn}: {len(rows)} rows; header={rows[0]}")
    for r in rows[1:4]: print("   ", r)
    body = rows[1:]
    hdr = rows[0]
    if "volume_id" in hdr and "document_id" in hdr:
        vi, di = hdr.index("volume_id"), hdr.index("document_id")
        file_pairs = [(r[vi], r[di]) for r in body if len(r) > max(vi, di)]
        mine = [(a, b) for a, b, _ in sample]
        print("   pairs equal to regenerated sample:", file_pairs == mine, "| file n=", len(file_pairs))
        if file_pairs != mine:
            print("   in file not mine:", [p_ for p_ in file_pairs if p_ not in mine][:10])
            print("   mine not in file:", [p_ for p_ in mine if p_ not in file_pairs][:10])
    # tally judgement columns
    for col in ("judgment", "referent", "verdict", "strict", "tolerant", "STRICT", "TOLERANT"):
        if col in hdr:
            ci = hdr.index(col)
            from collections import Counter
            print(f"   tally of {col}:", Counter(r[ci] for r in body if len(r) > ci))

# N07 cited set
q("N07 cited rows", "SELECT COUNT(*), COUNT(DISTINCT volume_id||'/'||document_id), SUM(role='quoted'), SUM(role='cited') FROM s.cited")
q("N07 cited by finding", "SELECT finding, COUNT(*) FROM s.cited GROUP BY 1")
q("N07 cited exist / flags", "SELECT COUNT(*), SUM(c.is_front_matter), SUM(c.is_editorial_note), SUM(COALESCE(c.document_number,'')=''), SUM(ct.volume_id LIKE '%Ed2') FROM s.cited ct LEFT JOIN document_cache c ON c.volume_id=ct.volume_id AND c.document_id=ct.document_id")
q("N07 cited inside the scope?", "SELECT SUM(sd.latam=1), SUM(sd.latam=0 OR sd.latam IS NULL), group_concat(CASE WHEN sd.latam=1 THEN NULL ELSE ct.volume_id||'/'||ct.document_id END) FROM s.cited ct LEFT JOIN s.scope_docs sd ON sd.volume_id=ct.volume_id AND sd.document_id=ct.document_id")

# N10 came-from, cited set
q("N10 came-from cited", "SELECT COALESCE(ds.citation_era,'(none)'), ds.repository, ds.record_group, CASE WHEN ds.citation_era='decimal' THEN '(decimal file number)' ELSE ds.series_name END, COUNT(*) FROM s.cited c LEFT JOIN document_sources ds ON ds.volume_id=c.volume_id AND ds.document_id=c.document_id GROUP BY 1,2,3,4 ORDER BY 5 DESC")
q("N10 came-from cited, decimal total", "SELECT SUM(ds.citation_era='decimal'), COUNT(*) FROM s.cited c LEFT JOIN document_sources ds ON ds.volume_id=c.volume_id AND ds.document_id=c.document_id")
q("N10 document_sources rows per cited doc (should be <=1)", "SELECT MAX(n), SUM(n>1) FROM (SELECT c.volume_id, c.document_id, COUNT(ds.volume_id) n FROM s.cited c LEFT JOIN document_sources ds ON ds.volume_id=c.volume_id AND ds.document_id=c.document_id GROUP BY 1,2)")
q("N10 came-from cited: raw rows", "SELECT c.volume_id, c.document_id, ds.citation_era, ds.repository, ds.record_group, ds.lot_file, ds.series_name, substr(ds.raw_text,1,80) FROM s.cited c LEFT JOIN document_sources ds ON ds.volume_id=c.volume_id AND ds.document_id=c.document_id ORDER BY 1,2")

# N10 came-from, candidates
q("N10 came-from candidates", f"SELECT ds.citation_era, ds.repository, ds.record_group, CASE WHEN ds.citation_era='decimal' THEN '(file number)' ELSE ds.series_name END AS series, COUNT(*) AS documents FROM frus_documents f JOIN s.scope_docs sd ON sd.volume_id=f.volume_id AND sd.document_id=f.document_id LEFT JOIN document_sources ds ON ds.volume_id=f.volume_id AND ds.document_id=f.document_id WHERE frus_documents MATCH '{FAMC}' AND {SCOPEF} GROUP BY 1,2,3,4 ORDER BY documents DESC LIMIT 15")
q("N10 candidates with no source-note row, by decade", f"SELECT sd.decade, COUNT(*) FROM frus_documents f JOIN s.scope_docs sd ON sd.volume_id=f.volume_id AND sd.document_id=f.document_id WHERE frus_documents MATCH '{FAMC}' AND {SCOPEF} AND NOT EXISTS (SELECT 1 FROM document_sources ds WHERE ds.volume_id=f.volume_id AND ds.document_id=f.document_id) GROUP BY sd.decade")

# N11 pointed-at
q("N11 pointed-at candidates", f"SELECT COUNT(DISTINCT f.volume_id||'/'||f.document_id) FROM frus_documents f JOIN s.scope_docs sd ON sd.volume_id=f.volume_id AND sd.document_id=f.document_id JOIN external_citations ec ON ec.volume_id=f.volume_id AND ec.document_id=f.document_id WHERE frus_documents MATCH '{FAMC}' AND {SCOPEF}")
q("N11 by anchor", f"SELECT ec.anchor, COUNT(*), COUNT(DISTINCT f.volume_id||'/'||f.document_id), MIN(sd.date_iso), MAX(sd.date_iso) FROM frus_documents f JOIN s.scope_docs sd ON sd.volume_id=f.volume_id AND sd.document_id=f.document_id JOIN external_citations ec ON ec.volume_id=f.volume_id AND ec.document_id=f.document_id WHERE frus_documents MATCH '{FAMC}' AND {SCOPEF} GROUP BY ec.anchor")
q("N11 earliest footnote citation, whole index", "SELECT MIN(dd.date_iso), COUNT(*), COUNT(DISTINCT ec.volume_id||'/'||ec.document_id) FROM external_citations ec JOIN document_dates dd ON dd.volume_id=ec.volume_id AND dd.document_id=ec.document_id")
q("N11 earliest footnote citation, latam scope", "SELECT MIN(dd.date_iso), COUNT(*), COUNT(DISTINCT ec.volume_id||'/'||ec.document_id) FROM external_citations ec JOIN document_dates dd ON dd.volume_id=ec.volume_id AND dd.document_id=ec.document_id JOIN s.scope_docs sd ON sd.volume_id=ec.volume_id AND sd.document_id=ec.document_id WHERE sd.latam=1 AND sd.numbered=1 AND sd.apparatus=0 AND sd.ed2_dup=0")
q("N11 cited set with external_citations rows", "SELECT c.volume_id, c.document_id, COUNT(ec.volume_id), group_concat(DISTINCT ec.anchor) FROM s.cited c JOIN external_citations ec ON ec.volume_id=c.volume_id AND ec.document_id=c.document_id GROUP BY 1,2")

# N09 internal memoranda by decade
q("N09 internal by decade", f"SELECT sd.decade, COUNT(*) AS candidate_docs, SUM(c.header LIKE '%Memorandum%' OR c.header LIKE '%Paper Prepared%' OR c.header LIKE '%Minutes%' OR c.header LIKE '%Summary of Conclusions%' OR c.header LIKE '%Briefing%') AS internal FROM frus_documents f JOIN s.scope_docs sd ON sd.volume_id=f.volume_id AND sd.document_id=f.document_id JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id WHERE frus_documents MATCH '{FAMC}' AND {SCOPEF} AND sd.date_iso IS NOT NULL GROUP BY 1 ORDER BY 1")

# N13 doctrine labels
for ph in ["estrada doctrine", "tobar doctrine", "betancourt doctrine", "mann doctrine", "wilson doctrine"]:
    q(f"N13 {ph}", f"SELECT SUM(sd.latam=1), COUNT(*) FROM frus_documents f JOIN s.scope_docs sd ON sd.volume_id=f.volume_id AND sd.document_id=f.document_id WHERE frus_documents MATCH '\"{ph}\"' AND sd.numbered=1 AND sd.apparatus=0 AND sd.ed2_dup=0")
q("N13 reconoc*", "SELECT SUM(sd.latam=1), COUNT(*) FROM frus_documents f JOIN s.scope_docs sd ON sd.volume_id=f.volume_id AND sd.document_id=f.document_id WHERE frus_documents MATCH 'reconoc*' AND sd.numbered=1 AND sd.apparatus=0 AND sd.ed2_dup=0")

# N16 controls
q("N16 positive control volumes", "SELECT COUNT(*), SUM(n>0) FROM (SELECT v.volume_id, COALESCE(h.n,0) n FROM (SELECT DISTINCT volume_id FROM document_cache) v LEFT JOIN (SELECT volume_id, COUNT(*) n FROM frus_documents WHERE frus_documents MATCH '\"department of state\"' GROUP BY volume_id) h ON h.volume_id=v.volume_id)")
q("N16 negative control", "SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH 'ZZZ_IMPOSSIBLE_ZZZ'")

# N18 editors set
q("N18 editors_recog", "SELECT COUNT(*), COUNT(DISTINCT volume_id), COUNT(DISTINCT heading), COUNT(DISTINCT volume_id||'/'||heading) FROM s.editors_recog")
q("N18 editors_recog schema", "SELECT sql FROM s.sqlite_master WHERE name='editors_recog'")
q("N18 editors_recog numbered non-apparatus and date span", "SELECT COUNT(*), SUM(sd.numbered=1 AND sd.apparatus=0 AND sd.ed2_dup=0), MIN(sd.date_iso), MAX(sd.date_iso) FROM s.editors_recog e JOIN s.scope_docs sd ON sd.volume_id=e.volume_id AND sd.document_id=e.document_id")
print("\nDONE")
