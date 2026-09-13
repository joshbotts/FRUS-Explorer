#!/usr/bin/env python3
"""#234 reframe — how hard is an R-0 -> app-text offset mapping?

Read-only. Stdlib only. Writes under OUT (this script's directory).

1. Enumerates the TEI-rule scope (~/frus-ner-raw/scope.json, 267 volumes) through the
   R-0 text layer, groups documents into ner_store.BANDS, samples PER_BAND documents
   per band (seeded, uniform within band).
2. For each sampled document compares R-0 text with document_cache.body_text in the
   live index (opened mode=ro): exact, whitespace-normalised, whitespace-stripped, and
   the same three after html.unescape on R-0 (diagnostic).
3. For every detected span from the filtered sweep and filtered control stores in the
   sampled documents: can the surface be located uniquely in body_text near the R-0
   offset? A ground-truth location is derived from an alignment (entity-aware offset
   map when the decoded R-0 equals body_text, else difflib opcodes) so the heuristic can
   be checked, not just counted.
"""
import sys, os, json, gzip, random, re, html, time, difflib, sqlite3, collections
sys.path.insert(0, '/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/tools/semantic-harvest')
import ner_store as ns

OUT = os.path.dirname(os.path.abspath(__file__))
DB = "/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/frus.db"
TEXT = os.path.expanduser('~/frus-semantic-raw/text')
STORES = {'sweep_filtered': os.path.expanduser('~/frus-ner-raw-filtered'),
          'control_filtered': os.path.expanduser('~/frus-ner-raw-control-filtered')}
PER_BAND = int(os.environ.get('PER_BAND', '100'))
SEED = int(os.environ.get('SEED', '234077'))
WINDOWS = (50, 200, 1000)

ENTITY = re.compile(r'&(#x[0-9a-fA-F]+|#[0-9]+|[A-Za-z][A-Za-z0-9]*);')

def decode_with_map(s):
    """(decoded, m) where m[i] = decoded index of R-0 code point i (len(s)+1 entries)."""
    out = []; m = [0] * (len(s) + 1); i = 0; pos = 0
    for mo in ENTITY.finditer(s):
        for k in range(i, mo.start()):
            m[k] = pos; out.append(s[k]); pos += 1
        rep = html.unescape(mo.group(0))
        for k in range(mo.start(), mo.end()):
            m[k] = pos
        out.append(rep); pos += len(rep); i = mo.end()
    for k in range(i, len(s)):
        m[k] = pos; out.append(s[k]); pos += 1
    m[len(s)] = pos
    return ''.join(out), m

def ws_norm(s): return ' '.join(s.split())
def ws_strip(s): return ''.join(s.split())

def occurrences(needle, hay):
    res = []; i = hay.find(needle)
    while i != -1:
        res.append(i); i = hay.find(needle, i + 1)
    return res

def main():
    t0 = time.time()
    scope = ns.scope_volumes(os.path.expanduser('~/frus-ner-raw'))
    by_band = collections.defaultdict(list); vol_docs = {}
    ordinal_ids = 0
    for v in scope:
        rows = ns.read_jsonl_gz(ns.one_jsonl(TEXT, v, 'text'))
        vol_docs[v] = len(rows)
        for r in rows:
            if r['d'].startswith('ord'): ordinal_ids += 1
            by_band[ns.band_of(v)].append((v, r['d']))
    pop = {b: len(x) for b, x in by_band.items()}
    rng = random.Random(SEED)
    sample = []
    for low, high, label in ns.BANDS:
        docs = sorted(by_band[label])
        sample += [(label, v, d) for v, d in rng.sample(docs, PER_BAND)]
    con = sqlite3.connect('file:' + DB + '?mode=ro', uri=True)
    need = collections.defaultdict(set)
    for b, v, d in sample: need[v].add(d)
    texts = {}
    for v in need:
        t = ns.volume_text(TEXT, v)
        for d in need[v]: texts[(v, d)] = t[d]
    spans = {name: collections.defaultdict(list) for name in STORES}
    scanned = {name: {} for name in STORES}
    for name, store in STORES.items():
        for v in need:
            head = ns.layer_head(store, 'detected', v)
            scanned[name][v] = None if head is None else (head.get('docs_scanned'), head.get('docs_in_volume'), head.get('sampled_doc_ids'))
            for row in ns.volume_layer(store, 'detected', v):
                if row['d'] in need[v]:
                    spans[name][(v, row['d'])].append((row['s'], row['e'], row['n']))
    docs_out = []; span_out = []
    tally = collections.Counter()
    for b, v, d in sample:
        a = texts[(v, d)]
        row = con.execute('select body_text from document_cache where volume_id=? and document_id=?', (v, d)).fetchone()
        rec = {'band': b, 'volume': v, 'd': d, 'r0_len': len(a)}
        if row is None:
            rec['in_index'] = False; docs_out.append(rec); continue
        body = row[0]; rec['in_index'] = True; rec['app_len'] = len(body)
        dec, dmap = decode_with_map(a)
        rec.update(exact=a == body, ws_norm=ws_norm(a) == ws_norm(body), ws_strip=ws_strip(a) == ws_strip(body),
                   dec_exact=dec == body, dec_ws_norm=ws_norm(dec) == ws_norm(body), dec_ws_strip=ws_strip(dec) == ws_strip(body),
                   entities_in_r0=len(ENTITY.findall(a)))
        # ground-truth map R-0 index -> body index
        if dec == body:
            gt = lambda i: dmap[i]; rec['align'] = 'entity_map'
        else:
            sm = difflib.SequenceMatcher(None, dec, body, autojunk=False)
            blocks = [(i, j, n) for i, j, n in sm.get_matching_blocks() if n]
            rec['align'] = 'difflib'; rec['diff_ratio'] = round(sm.ratio(), 5)
            ops = [op for op in sm.get_opcodes() if op[0] != 'equal']
            rec['diff_ops'] = len(ops)
            rec['diff_examples'] = [[op[0], dec[max(0, op[1]-25):op[2]+10], body[max(0, op[3]-25):op[4]+10]] for op in ops[:3]]
            def gt(i, blocks=blocks, dmap=dmap):
                di = dmap[i]
                for bi, bj, n in blocks:
                    if bi <= di < bi + n: return bj + (di - bi)
                return None
        docs_out.append(rec)
        for name in STORES:
            for s, e, n in sorted(set(spans[name][(v, d)])):
                if a[s:e] != n:
                    tally[(name, 'span_mismatch_r0')] += 1; continue
                surface = html.unescape(n)
                occ = occurrences(surface, body)
                true_start = gt(s)
                true_ok = true_start is not None and body[true_start:true_start + len(surface)] == surface
                prop = s * len(body) / max(1, len(a))
                sr = {'store': name, 'band': b, 'volume': v, 'd': d, 's': s, 'n': n, 'occ_total': len(occ),
                      'true_start': true_start if true_ok else None}
                for w in WINDOWS:
                    near = [o for o in occ if abs(o - prop) <= w]
                    sr['near%d' % w] = len(near)
                    sr['near%d_correct' % w] = (len(near) == 1 and true_ok and near[0] == true_start)
                nearest = min(occ, key=lambda o: abs(o - prop)) if occ else None
                sr['nearest_correct'] = bool(occ) and true_ok and nearest == true_start
                sr['nearest_shift'] = None if not true_ok else (true_start - s)
                span_out.append(sr)
    with open(os.path.join(OUT, 'sample-docs.jsonl'), 'w') as f:
        for r in docs_out: f.write(json.dumps(r, ensure_ascii=False) + '\n')
    with open(os.path.join(OUT, 'sample-spans.jsonl'), 'w') as f:
        for r in span_out: f.write(json.dumps(r, ensure_ascii=False) + '\n')
    # summary
    def rate(rows, key):
        n = len(rows); k = sum(1 for r in rows if r.get(key)); return {'k': k, 'n': n, 'rate': round(k / n, 4) if n else None}
    summ = {'seed': SEED, 'per_band': PER_BAND, 'population_docs_by_band': pop, 'population_docs': sum(pop.values()),
            'population_volumes': len(scope), 'r0_ordinal_fallback_ids': ordinal_ids,
            'detector_heads': {name: {v: scanned[name][v][:2] if scanned[name][v] else None for v in sorted(need)} for name in STORES},
            'tally': {'%s/%s' % k: c for k, c in tally.items()}, 'docs': {}, 'spans': {}}
    indexed = [r for r in docs_out if r['in_index']]
    summ['docs_not_in_index'] = [(r['volume'], r['d']) for r in docs_out if not r['in_index']]
    for label in ['ALL'] + [b[2] for b in ns.BANDS]:
        rows = [r for r in indexed if label == 'ALL' or r['band'] == label]
        summ['docs'][label] = {k: rate(rows, k) for k in ('exact', 'ws_norm', 'ws_strip', 'dec_exact', 'dec_ws_norm', 'dec_ws_strip')}
        summ['docs'][label]['docs_with_entities'] = sum(1 for r in rows if r['entities_in_r0'])
    for name in STORES:
        for label in ['ALL'] + [b[2] for b in ns.BANDS]:
            rows = [r for r in span_out if r['store'] == name and (label == 'ALL' or r['band'] == label)]
            n = len(rows)
            d = {'spans': n, 'docs_with_spans': len({(r['volume'], r['d']) for r in rows})}
            d['found_anywhere'] = rate([{'x': r['occ_total'] > 0} for r in rows], 'x')
            d['unique_in_document'] = rate([{'x': r['occ_total'] == 1} for r in rows], 'x')
            d['true_location_recovered_by_alignment'] = rate([{'x': r['true_start'] is not None} for r in rows], 'x')
            for w in WINDOWS:
                d['unique_within_%d' % w] = rate([{'x': r['near%d' % w] == 1} for r in rows], 'x')
                d['unique_within_%d_and_correct' % w] = rate(rows, 'near%d_correct' % w)
            d['nearest_occurrence_correct'] = rate(rows, 'nearest_correct')
            d['unique_in_document_and_correct'] = rate([{'x': r['occ_total'] == 1 and r['true_start'] is not None} for r in rows], 'x')
            summ['spans']['%s/%s' % (name, label)] = d
    summ['elapsed_s'] = round(time.time() - t0, 1)
    json.dump(summ, open(os.path.join(OUT, 'summary-text-equality.json'), 'w'), indent=1, ensure_ascii=False)
    print(json.dumps({k: summ[k] for k in ('population_docs_by_band', 'population_docs', 'population_volumes', 'r0_ordinal_fallback_ids', 'tally', 'docs_not_in_index', 'elapsed_s')}, indent=1))
    print(json.dumps(summ['docs'], indent=1))
    for k, d in summ['spans'].items():
        print(k, d['spans'], d['docs_with_spans'], 'any', d['found_anywhere']['rate'], 'uniqDoc', d['unique_in_document']['rate'],
              'u50', d['unique_within_50']['rate'], 'u200', d['unique_within_200']['rate'], 'u200ok', d['unique_within_200_and_correct']['rate'],
              'u1000', d['unique_within_1000']['rate'], 'nearestOK', d['nearest_occurrence_correct']['rate'], 'gt', d['true_location_recovered_by_alignment']['rate'])

main()
