#!/usr/bin/env python3
"""Verifier: for a converter route that wraps EVERY word-bounded occurrence of a document's detected
surfaces, how many wrapped occurrences are not a detected span, and how many of those sit inside a
longer detected span (so they would nest rather than add a new name). Read-only; stdlib only."""
import os, re, json, gzip, html, sqlite3, collections
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
con = sqlite3.connect('file:' + DB + '?mode=ro', uri=True)
samples = {'A': [(r['volume'], r['d']) for r in map(json.loads, open(os.path.join(MO, 'sample-docs.jsonl')))],
           'B': [(r['volume'], r['d']) for r in map(json.loads, open(os.path.join(HERE, 'v1-sampleB.jsonl')))]}
out = {}
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
        c = collections.Counter(); examples = collections.Counter()
        for key in sample:
            body = con.execute('select body_text from document_cache where volume_id=? and document_id=?', key).fetchone()[0]
            a = r0[key]
            det = []
            for st, en, n in spans[key]:
                un = html.unescape(n); bs = len(html.unescape(a[:st])); det.append((bs, bs + len(un), un))
            starts = {(b0, u) for b0, b1, u in det}
            for surf in {u for _, _, u in det}:
                for m in re.finditer(r'(?<!\w)' + re.escape(surf) + r'(?!\w)', body):
                    o0, o1 = m.start(), m.end()
                    c['wrapped'] += 1
                    if (o0, surf) in starts: c['is_detected_span'] += 1; continue
                    if any(b0 <= o0 and o1 <= b1 for b0, b1, _ in det): c['inside_longer_detection'] += 1
                    elif any(b0 < o1 and o0 < b1 for b0, b1, _ in det): c['overlaps_detection'] += 1
                    else:
                        c['new_undetected_position'] += 1; examples[surf] += 1
        out[tag + '/' + s] = dict(c)
        out[tag + '/' + s + '/top_new_surfaces'] = examples.most_common(15)
json.dump(out, open(os.path.join(HERE, 'v5-wrap.json'), 'w'), indent=1, ensure_ascii=False)
print(json.dumps(out, indent=1, ensure_ascii=False))
