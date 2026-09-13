#!/usr/bin/env python3
"""Verifier side checks. Read-only; stdlib only."""
import os, re, json, gzip, html, random, time, sqlite3, collections
HERE = os.path.dirname(os.path.abspath(__file__))
MO = '/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad/reframe/measure-offsets'
DB = "/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/frus.db"
TEXT = os.path.expanduser('~/frus-semantic-raw/text')
STORES = {'sweep': os.path.expanduser('~/frus-ner-raw-filtered/detected'),
          'control': os.path.expanduser('~/frus-ner-raw-control-filtered/detected')}
def rd(p):
    op = gzip.open if p.endswith('.gz') else open
    with op(p, 'rt', encoding='utf-8') as f:
        return [json.loads(l) for l in f if l.strip()]
def band(v):
    y = int(re.match(r'frus(\d{4})', v).group(1))
    return '1861-1899' if y <= 1899 else '1900-1929' if y <= 1929 else '1930-1945' if y <= 1945 else '1946-'
out = {}
scope = json.load(open(os.path.expanduser('~/frus-ner-raw/scope.json')))['volumes']
keys = collections.defaultdict(list); r0keys = set(); nonbmp_r0_scope_docs = 0
for v in scope:
    for r in rd(os.path.join(TEXT, v + '.jsonl.gz')):
        keys[band(v)].append((v, r['d'])); r0keys.add((v, r['d']))
        if any(ord(ch) > 0xFFFF for ch in r['t']): nonbmp_r0_scope_docs += 1
out['nonbmp_r0_docs_in_scope'] = nonbmp_r0_scope_docs
# (a) regenerate original sample from its stated seed
rng = random.Random(234077); regen = []
for b in ('1861-1899', '1900-1929', '1930-1945', '1946-'):
    regen += [(v, d) for v, d in rng.sample(sorted(keys[b]), 100)]
orig = [json.loads(l) for l in open(os.path.join(MO, 'sample-docs.jsonl'))]
out['seed_regenerates_original_sample'] = regen == [(r['volume'], r['d']) for r in orig]
# (b) original's span classes by whether the doc aligned
fd = {(r['volume'], r['d']): r['ws_strip_minus_footnotes'] for r in map(json.loads, open(os.path.join(MO, 'flat-docs.jsonl')))}
tab = collections.Counter()
for l in open(os.path.join(MO, 'flat-spans.jsonl')):
    r = json.loads(l); tab[(r['store'], 'aligned' if fd[(r['volume'], r['d'])] else 'unaligned', r['cls'])] += 1
out['original_span_classes'] = {'/'.join(k): c for k, c in sorted(tab.items())}
# (c) non-BMP in Swift flat text
out['nonbmp_flat_docs'] = sum(1 for r in map(json.loads, open(os.path.join(MO, 'swiftcli', 'flat-sample.jsonl'))) if any(ord(ch) > 0xFFFF for ch in r['flat']))
# (d) weighted arithmetic
pop = {b: len(keys[b]) for b in keys}
ex = {'1861-1899': 65, '1900-1929': 97, '1930-1945': 98, '1946-': 98}
out['weighted_exact_orig'] = round(sum(pop[b] * ex[b] / 100 for b in pop) / sum(pop.values()), 4)
exB = {'1861-1899': 51, '1900-1929': 96, '1930-1945': 100, '1946-': 99}
out['weighted_exact_fresh'] = round(sum(pop[b] * exB[b] / 100 for b in pop) / sum(pop.values()), 4)
con = sqlite3.connect('file:' + DB + '?mode=ro', uri=True)
# (e) app-view rows in scope volumes vs R-0 docs
ph = ','.join('?' * len(scope))
rows = con.execute('select volume_id, document_id, is_front_matter, is_editorial_note from document_cache where volume_id in (%s)' % ph, scope).fetchall()
cache_keys = {(v, d) for v, d, _, _ in rows}
out['app_view_rows_in_scope_volumes'] = len(rows)
out['app_rows_not_in_r0'] = len(cache_keys - r0keys)
out['r0_docs_not_in_app'] = len(r0keys - cache_keys)
out['app_rows_front_matter'] = sum(1 for r in rows if r[2])
out['app_rows_not_in_r0_examples'] = sorted(cache_keys - r0keys)[:8]
# (f) scoped COUNT join timings
tim = {}
for n in ('Seward', 'Hull', 'Wells'):
    ts = []; c = None
    for _ in range(3):
        t = time.perf_counter()
        c = con.execute('select count(*) from frus_documents f join document_cache dc on dc.rowid = f.rowid where frus_documents match ? and dc.volume_id in (%s)' % ph, ['body_text:' + n] + scope).fetchone()[0]
        ts.append(round((time.perf_counter() - t) * 1000, 1))
    tim[n] = {'count': c, 'ms': ts}
out['scoped_count_join'] = tim
# (g) would wrapping EVERY occurrence of a detected surface over-highlight?
samples = {'A': [(r['volume'], r['d']) for r in orig],
           'B': [(r['volume'], r['d']) for r in map(json.loads, open(os.path.join(HERE, 'v1-sampleB.jsonl')))]}
wrap = {}
for tag, sample in samples.items():
    need = collections.defaultdict(set)
    for v, d in sample: need[v].add(d)
    r0 = {}
    for v in need:
        for r in rd(os.path.join(TEXT, v + '.jsonl.gz')):
            if r['d'] in need[v]: r0[(v, r['d'])] = r['t']
    for s, dp in STORES.items():
        spans = collections.defaultdict(set)
        for v in need:
            p = os.path.join(dp, v + '.jsonl.gz')
            if not os.path.exists(p): p = os.path.join(dp, v + '.jsonl')
            for r in rd(p):
                if r['d'] in need[v]: spans[(v, r['d'])].add((r['s'], r['e'], r['n']))
        c = collections.Counter()
        for key in sample:
            body = con.execute('select body_text from document_cache where volume_id=? and document_id=?', key).fetchone()[0]
            a = r0[key]
            det_starts = collections.defaultdict(set)
            for st, en, n in spans[key]:
                det_starts[html.unescape(n)].add(len(html.unescape(a[:st])))
            for surf, starts in det_starts.items():
                pat = re.compile(r'(?<!\w)' + re.escape(surf) + r'(?!\w)')
                occ = [m.start() for m in pat.finditer(body)]
                c['surfaces'] += 1; c['occurrences_wordbounded'] += len(occ)
                c['occ_detected'] += sum(1 for o in occ if o in starts)
                if len(occ) > 1:
                    c['repeated_surfaces'] += 1; c['repeated_occ'] += len(occ)
                    c['repeated_occ_detected'] += sum(1 for o in occ if o in starts)
        wrap[tag + '/' + s] = dict(c)
out['wrap_all_occurrences'] = wrap
json.dump(out, open(os.path.join(HERE, 'v3-checks.json'), 'w'), indent=1)
print(json.dumps(out, indent=1))
