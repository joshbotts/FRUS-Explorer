#!/usr/bin/env python3
"""Verifier (independent of measure-offsets code). Read-only, stdlib only.
Population by band from the R-0 text layer over scope.json volumes; also documents
carrying marks. Two samples: A = the original 400 keys (read from its sample-docs.jsonl),
B = a fresh sample, seed 5150, 100 per band. For each: R-0 vs document_cache.body_text
exact / whitespace-normalised / html.unescape. For detected spans (filtered sweep,
filtered control): body offset by prefix-unescape length, surface uniqueness.
"""
import os, sys, json, gzip, random, html, collections, sqlite3, re
HERE = os.path.dirname(os.path.abspath(__file__))
DB = "/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/frus.db"
TEXT = os.path.expanduser('~/frus-semantic-raw/text')
NER = os.path.expanduser('~/frus-ner-raw')
STORES = {'sweep': os.path.expanduser('~/frus-ner-raw-filtered/detected'),
          'control': os.path.expanduser('~/frus-ner-raw-control-filtered/detected')}
ORIG = '/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad/reframe/measure-offsets/sample-docs.jsonl'

def band(v):
    y = int(re.match(r'frus(\d{4})', v).group(1))
    return '1861-1899' if y <= 1899 else '1900-1929' if y <= 1929 else '1930-1945' if y <= 1945 else '1946-'

def rd(path):
    op = gzip.open if path.endswith('.gz') else open
    with op(path, 'rt', encoding='utf-8') as f:
        return [json.loads(l) for l in f if l.strip()]

scope = json.load(open(os.path.join(NER, 'scope.json')))['volumes']
pop = collections.Counter(); keys = collections.defaultdict(list); marked_docs = collections.Counter(); marks = 0
ids_dup = 0
for v in scope:
    p = os.path.join(TEXT, v + '.jsonl.gz')
    if not os.path.exists(p): p = os.path.join(TEXT, v + '.jsonl')
    rows = rd(p)
    ds = [r['d'] for r in rows]
    ids_dup += len(ds) - len(set(ds))
    pop[band(v)] += len(rows)
    keys[band(v)].extend((v, d) for d in ds)
    mp = os.path.join(NER, 'marked', v + '.jsonl.gz')
    if os.path.exists(mp):
        mr = rd(mp); marks += len(mr)
        marked_docs[band(v)] += len({r['d'] for r in mr})
out = {'scope_volumes': len(scope), 'r0_docs_by_band': dict(pop), 'r0_docs_total': sum(pop.values()),
       'dup_doc_ids_within_volume': ids_dup, 'marked_rows': marks, 'docs_with_marks_by_band': dict(marked_docs),
       'docs_with_marks_total': sum(marked_docs.values())}

orig = [json.loads(l) for l in open(ORIG)]
sampleA = [(r['band'], r['volume'], r['d']) for r in orig]
rng = random.Random(5150)
sampleB = []
for b in ('1861-1899', '1900-1929', '1930-1945', '1946-'):
    sampleB += [(b, v, d) for v, d in rng.sample(sorted(keys[b]), 100)]
out['orig_sample_band_counts'] = dict(collections.Counter(b for b, _, _ in sampleA))
out['orig_sample_band_label_matches_mine'] = sum(1 for b, v, d in sampleA if band(v) == b)
out['overlap_A_B'] = len({(v, d) for _, v, d in sampleA} & {(v, d) for _, v, d in sampleB})

con = sqlite3.connect('file:' + DB + '?mode=ro', uri=True)

def evaluate(sample, tag):
    need = collections.defaultdict(set)
    for b, v, d in sample: need[v].add(d)
    r0 = {}
    for v in need:
        p = os.path.join(TEXT, v + '.jsonl.gz')
        for r in rd(p):
            if r['d'] in need[v]: r0[(v, r['d'])] = r['t']
    spans = {s: collections.defaultdict(set) for s in STORES}; rawrows = collections.Counter(); heads = {}
    for s, dirp in STORES.items():
        for v in need:
            p = os.path.join(dirp, v + '.jsonl.gz')
            if not os.path.exists(p): p = os.path.join(dirp, v + '.jsonl')
            if not os.path.exists(p): continue
            h = json.load(open(os.path.join(dirp, v + '.head.json')))
            heads[(s, v)] = (h.get('docs_scanned'), h.get('docs_in_volume'))
            for r in rd(p):
                if r['d'] in need[v]:
                    rawrows[s] += 1
                    spans[s][(v, r['d'])].add((r['s'], r['e'], r['n']))
    res = {'n': len(sample), 'in_index': 0, 'exact': collections.Counter(), 'wsnorm': collections.Counter(),
           'unescaped_exact': collections.Counter(), 'docs_with_entity': 0, 'band_n': collections.Counter()}
    sp = {s: collections.Counter() for s in STORES}
    for b, v, d in sample:
        res['band_n'][b] += 1
        row = con.execute('select body_text from document_cache where volume_id=? and document_id=?', (v, d)).fetchone()
        if not row: continue
        res['in_index'] += 1
        a = r0[(v, d)]; body = row[0]
        if a == body: res['exact'][b] += 1
        if ' '.join(a.split()) == ' '.join(body.split()): res['wsnorm'][b] += 1
        ua = html.unescape(a)
        if ua == body: res['unescaped_exact'][b] += 1
        if '&' in a and ua != a: res['docs_with_entity'] += 1
        for s in STORES:
            for (st, en, n) in spans[s][(v, d)]:
                c = sp[s]
                c['spans'] += 1
                if a[st:en] != n: c['r0_slice_mismatch'] += 1; continue
                off = len(html.unescape(a[:st])); un = html.unescape(n)
                if body[off:off + len(un)] == un: c['offset_by_prefix_unescape_ok'] += 1
                cnt = 0; i = body.find(un)
                while i != -1: cnt += 1; i = body.find(un, i + 1)
                if cnt == 0: c['absent'] += 1
                if cnt == 1: c['unique_in_doc'] += 1
                if body.count(un) == 1: c['unique_nonoverlap'] += 1
                if ' ' not in un.strip(): c['single_token'] += 1
    res = {k: (dict(x) if isinstance(x, collections.Counter) else x) for k, x in res.items()}
    for k in ('exact', 'wsnorm', 'unescaped_exact'):
        res[k + '_total'] = sum(res[k].values())
    res['spans'] = {s: dict(sp[s]) for s in STORES}
    res['raw_rows_before_dedupe'] = dict(rawrows)
    res['volumes'] = len(need)
    res['heads_full_scan'] = sum(1 for (s, v), (a_, b_) in heads.items() if a_ == b_)
    res['heads_total'] = len(heads)
    return res

out['A_original_sample'] = evaluate(sampleA, 'A')
out['B_fresh_sample'] = evaluate(sampleB, 'B')
with open(os.path.join(HERE, 'v1-sampleB.jsonl'), 'w') as f:
    for b, v, d in sampleB: f.write(json.dumps({'band': b, 'volume': v, 'd': d}) + '\n')
json.dump(out, open(os.path.join(HERE, 'v1-equality.json'), 'w'), indent=1)
print(json.dumps(out, indent=1))
