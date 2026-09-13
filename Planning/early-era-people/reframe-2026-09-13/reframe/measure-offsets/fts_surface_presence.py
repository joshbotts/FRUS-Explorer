#!/usr/bin/env python3
"""#234 reframe task 3b — can FTS5 confirm, per document, a surface the detectors found?

Read-only. For every distinct (document, surface) detected in the 400-document sample
(sample-spans.jsonl from measure_text_equality.py), runs
    SELECT 1 FROM frus_documents WHERE rowid = ? AND frus_documents MATCH 'body_text:"<surface tokens>"'
and reports the confirm rate and per-query latency. Also times checking a 1,000-name list
against one document (the shape of a runtime "known names present here" list), and
checks whether document_cache rowids are contiguous per volume (a rowid-range scope).
"""
import sqlite3, json, os, re, time, statistics, collections
DB = "/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/frus.db"
OUT = os.path.dirname(os.path.abspath(__file__))
con = sqlite3.connect('file:' + DB + '?mode=ro', uri=True)
spans = [json.loads(l) for l in open(os.path.join(OUT, 'sample-spans.jsonl'))]
TOK = re.compile(r'[^\W_]+', re.UNICODE)
def phrase(surface):
    toks = TOK.findall(surface)
    return ('body_text:"%s"' % ' '.join(toks)) if toks else None
rowids = {}
res = {}
for store in ('sweep_filtered', 'control_filtered'):
    pairs = sorted({(r['volume'], r['d'], r['n']) for r in spans if r['store'] == store})
    ok = 0; nq = 0; lat = []; skipped = 0
    for v, d, n in pairs:
        if (v, d) not in rowids:
            rowids[(v, d)] = con.execute('select rowid from document_cache where volume_id=? and document_id=?', (v, d)).fetchone()[0]
        q = phrase(n)
        if q is None: skipped += 1; continue
        t = time.perf_counter(); hit = con.execute('SELECT 1 FROM frus_documents WHERE rowid = ? AND frus_documents MATCH ?', (rowids[(v, d)], q)).fetchone(); lat.append((time.perf_counter() - t) * 1000)
        nq += 1; ok += bool(hit)
    res[store] = {'distinct_doc_surface_pairs': len(pairs), 'queried': nq, 'no_word_tokens': skipped, 'confirmed': ok,
                  'rate': round(ok / nq, 4), 'latency_ms_median': round(statistics.median(lat), 4), 'latency_ms_p99': round(sorted(lat)[int(len(lat) * .99)], 4), 'latency_ms_total': round(sum(lat), 1)}
    print(store, res[store])
# 1,000 surnames checked against one document
names = sorted({t for r in spans for t in TOK.findall(r['n']) if t[:1].isupper() and len(t) > 2})[:1000]
v, d = 'frus1866p1', 'd113'
rid = con.execute('select rowid from document_cache where volume_id=? and document_id=?', (v, d)).fetchone()[0]
t = time.perf_counter(); present = [nm for nm in names if con.execute('SELECT 1 FROM frus_documents WHERE rowid = ? AND frus_documents MATCH ?', (rid, 'body_text:"%s"' % nm)).fetchone()]
res['name_list_against_one_document'] = {'names': len(names), 'document': '%s/%s' % (v, d), 'present': len(present), 'total_ms': round((time.perf_counter() - t) * 1000, 1)}
print(res['name_list_against_one_document'])
# rowid contiguity per volume
rows = con.execute('select volume_id, min(rowid), max(rowid), count(*) from document_cache group by volume_id').fetchall()
contig = sum(1 for _, lo, hi, c in rows if hi - lo + 1 == c)
res['rowid_contiguous_volumes'] = {'contiguous': contig, 'volumes': len(rows)}
print(res['rowid_contiguous_volumes'])
lo, hi = con.execute("select min(rowid), max(rowid) from document_cache where volume_id='frus1885'").fetchone()
ts = []
for _ in range(3):
    t = time.perf_counter(); n = con.execute("SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH 'body_text:Wells' AND rowid BETWEEN ? AND ?", (lo, hi)).fetchone()[0]; ts.append(round((time.perf_counter() - t) * 1000, 2))
res['volume_rowid_range_wells'] = {'volume': 'frus1885', 'count': n, 'ms': ts}
print(res['volume_rowid_range_wells'])
json.dump(res, open(os.path.join(OUT, 'fts-surface-presence.json'), 'w'), indent=1)
