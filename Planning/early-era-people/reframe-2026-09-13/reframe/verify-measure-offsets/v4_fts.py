#!/usr/bin/env python3
"""Verifier FTS check. Read-only (mode=ro, no temp tables). Stdlib only."""
import os, json, time, re, sqlite3, statistics, gzip, collections, html
HERE = os.path.dirname(os.path.abspath(__file__))
DB = "/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/frus.db"
con = sqlite3.connect('file:' + DB + '?mode=ro', uri=True)
scope = json.load(open(os.path.expanduser('~/frus-ner-raw/scope.json')))['volumes']
out = {'sqlite': sqlite3.sqlite_version}
def timed(sql, args, runs=3):
    ts = []; val = None
    for _ in range(runs):
        t = time.perf_counter(); val = con.execute(sql, args).fetchall(); ts.append(round((time.perf_counter() - t) * 1000, 2))
    return val, ts
# rowid contiguity
rows = con.execute('select volume_id, min(rowid), max(rowid), count(*) from document_cache group by volume_id').fetchall()
out['volumes_in_cache'] = len(rows)
out['contiguous_volumes'] = sum(1 for v, a, b, c in rows if b - a + 1 == c)
rng = {v: (a, b) for v, a, b, c in rows}
# overlapping ranges?
srt = sorted((a, b, v) for v, (a, b) in rng.items())
out['overlapping_rowid_ranges'] = sum(1 for i in range(1, len(srt)) if srt[i][0] <= srt[i-1][1])
out['scope_in_cache'] = sum(1 for v in scope if v in rng)
out['scope_docs_in_cache'] = sum(c for v, a, b, c in rows if v in set(scope))
names = ['Seward', 'Hull', 'Wells', 'Bliss', 'Blaine', 'Smith', 'Hay', 'Adams', 'Hughes', 'Root']
q = {}
ph = ','.join('?' * len(scope))
for n in names:
    (c,), ts = timed('select count(*) from frus_documents where frus_documents match ?', ('body_text:' + n,))
    c = c[0] if isinstance(c, tuple) else c
    scoped_sql = ('select dc.rowid, dc.body_text from frus_documents f join document_cache dc on dc.rowid = f.rowid '
                  'where frus_documents match ? and dc.volume_id in (%s)' % ph)
    t = time.perf_counter(); srows = con.execute(scoped_sql, ['body_text:' + n] + scope).fetchall(); tsc = round((time.perf_counter() - t) * 1000, 1)
    wb = re.compile(r'(?<![A-Za-z])' + n + r'(?![A-Za-z])')
    wb2 = re.compile(r'\b' + n + r'\b')
    k = sum(1 for _, b in srows if wb.search(b)); k2 = sum(1 for _, b in srows if wb2.search(b))
    ki = sum(1 for _, b in srows if re.search(r'(?<![A-Za-z])' + n + r'(?![A-Za-z])', b, re.I))
    q[n] = {'corpus_count': c, 'corpus_ms_3runs': ts, 'scope_matches': len(srows), 'scope_fetch_ms': tsc,
            'scope_case_sensitive_word_letters': k, 'scope_case_sensitive_word_b': k2, 'scope_case_insensitive_word': ki}
out['surnames'] = q
# vocab: what does Wells stem to
out['vocab_well'] = con.execute("select term, doc, cnt from frus_documents_vocab where term in ('well','wells','seward','hull','hay','root')").fetchall()
# phrase confirm for detected surfaces in the original 400 sample
ORIG = '/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad/reframe/measure-offsets/sample-docs.jsonl'
sample = [json.loads(l) for l in open(ORIG)]
need = collections.defaultdict(set)
for r in sample: need[r['volume']].add(r['d'])
STORES = {'sweep': os.path.expanduser('~/frus-ner-raw-filtered/detected'), 'control': os.path.expanduser('~/frus-ner-raw-control-filtered/detected')}
pc = {}
for s, dp in STORES.items():
    pairs = set()
    for v in need:
        p = os.path.join(dp, v + '.jsonl.gz')
        op = gzip.open
        if not os.path.exists(p): p = os.path.join(dp, v + '.jsonl'); op = open
        with op(p, 'rt') as f:
            for l in f:
                r = json.loads(l)
                if r['d'] in need[v]: pairs.add((v, r['d'], r['n']))
    ok = 0; miss = []; lat = []; tokenless = 0; case_word_ok = 0
    for v, d, n in sorted(pairs):
        rid, body = con.execute('select rowid, body_text from document_cache where volume_id=? and document_id=?', (v, d)).fetchone()
        phrase = '"' + n.replace('"', '""') + '"'
        t = time.perf_counter()
        try:
            hit = con.execute('select 1 from frus_documents where frus_documents match ? and rowid = ?', ('body_text:' + phrase, rid)).fetchone()
        except sqlite3.OperationalError as e:
            hit = None; tokenless += 1
        lat.append((time.perf_counter() - t) * 1000)
        if hit: ok += 1
        else: miss.append(n)
    lat.sort()
    pc[s] = {'pairs': len(pairs), 'confirmed': ok, 'misses': miss[:10], 'errors': tokenless,
             'median_ms': round(statistics.median(lat), 3), 'p99_ms': round(lat[int(0.99 * (len(lat) - 1))], 3)}
out['phrase_confirm_origA'] = pc
json.dump(out, open(os.path.join(HERE, 'v4-fts.json'), 'w'), indent=1)
print(json.dumps(out, indent=1))
