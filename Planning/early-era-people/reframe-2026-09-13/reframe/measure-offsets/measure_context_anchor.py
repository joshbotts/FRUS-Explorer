#!/usr/bin/env python3
"""#234 reframe — a context-anchored R-0 -> flat-text mapping, checked against ground truth.

Read-only, stdlib only. For each detected span in the 400-document sample, take the span's non-whitespace
characters plus L non-whitespace characters of R-0 context on each side (L = 20, then 10, then 0 as a
cascade), and look for that needle in the flat text's non-whitespace string. A unique hit maps back to a
flat-text (UTF-16 == code point here; no non-BMP in the sample) offset. Scored against flat-spans.jsonl's
ground truth (the whole-document alignment) where that exists; reported as found-unique-unverifiable where
it does not. Footnote spans have no body offset, so any hit for one is counted as a false placement.
Writes summary-context-anchor.json."""
import sys, os, json, html, collections
sys.path.insert(0, '/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/tools/semantic-harvest')
import ner_store as ns
OUT = os.path.dirname(os.path.abspath(__file__))
TEXT = os.path.expanduser('~/frus-semantic-raw/text')
flat = {(r['volume'], r['d']): r for r in map(json.loads, open(os.path.join(OUT, 'swiftcli', 'flat-sample.jsonl')))}
fspans = [json.loads(l) for l in open(os.path.join(OUT, 'flat-spans.jsonl'))]
texts = {}
for v in sorted({s['volume'] for s in fspans}):
    t = ns.volume_text(TEXT, v)
    for s in fspans:
        if s['volume'] == v: texts[(v, s['d'])] = t[s['d']]
cache = {}
def prep(key):
    if key in cache: return cache[key]
    a = texts[key]
    # decoded R-0 with per-code-point map, non-ws projection
    import re
    ENTITY = re.compile(r'&(#x[0-9a-fA-F]+|#[0-9]+|[A-Za-z][A-Za-z0-9]*);')
    out = []; m = [0] * (len(a) + 1); i = 0; pos = 0
    for mo in ENTITY.finditer(a):
        for k in range(i, mo.start()): m[k] = pos; out.append(a[k]); pos += 1
        rep = html.unescape(mo.group(0))
        for k in range(mo.start(), mo.end()): m[k] = pos
        out.append(rep); pos += len(rep); i = mo.end()
    for k in range(i, len(a)): m[k] = pos; out.append(a[k]); pos += 1
    m[len(a)] = pos
    dec = ''.join(out)
    didx = [i for i, ch in enumerate(dec) if not ch.isspace()]
    inv = {p: k for k, p in enumerate(didx)}
    dn = ''.join(dec[i] for i in didx)
    fl = flat[key]['flat']
    fidx = [i for i, ch in enumerate(fl) if not ch.isspace()]
    fn_ = ''.join(fl[i] for i in fidx)
    cache[key] = (a, dec, m, didx, inv, dn, fl, fidx, fn_)
    return cache[key]
def count(needle, hay, cap=3):
    res = []; i = hay.find(needle)
    while i != -1 and len(res) < cap:
        res.append(i); i = hay.find(needle, i + 1)
    return res
rows = []
for s in fspans:
    key = (s['volume'], s['d'])
    a, dec, m, didx, inv, dn, fl, fidx, fn_ = prep(key)
    start = s['s']; end = start + len(s['n'])
    ds, de = m[start], m[end]
    nw = [inv[i] for i in range(ds, de) if i in inv]
    r = {'store': s['store'], 'band': s['band'], 'cls': s['cls']}
    if not nw:
        r['result'] = 'empty'; rows.append(r); continue
    k0, k1 = nw[0], nw[-1]
    placed = None; used = None
    for L in (20, 10, 0):
        lo = max(0, k0 - L); hi = min(len(dn), k1 + 1 + L)
        occ = count(dn[lo:hi], fn_)
        if len(occ) == 1:
            o = occ[0] + (k0 - lo)
            placed = (fidx[o], fidx[o + (k1 - k0)] + 1); used = L; break
        if len(occ) > 1 and L == 0:
            used = 'ambiguous'
    r['L'] = used
    if placed is None:
        r['result'] = 'ambiguous' if used == 'ambiguous' else 'not_found'
    elif s['cls'].startswith('body'):
        r['result'] = 'correct' if placed[0] == s['flat_s'] and placed[1] == s['flat_e'] else 'wrong'
    elif s['cls'] in ('in_footnote', 'straddles_footnote'):
        r['result'] = 'placed_footnote_span_in_body'
    else:
        r['result'] = 'unique_unverifiable'
    rows.append(r)
summ = {}
for store in ('sweep_filtered', 'control_filtered'):
    for lab in ['ALL'] + [b[2] for b in ns.BANDS]:
        rs = [r for r in rows if r['store'] == store and (lab == 'ALL' or r['band'] == lab)]
        grp = collections.defaultdict(collections.Counter)
        for r in rs:
            g = 'body' if r['cls'].startswith('body') else r['cls']
            grp[g][r['result']] += 1
            if r['result'] in ('correct', 'wrong'): grp[g]['L=%s' % r['L']] += 1
        summ['%s/%s' % (store, lab)] = {g: dict(c) for g, c in grp.items()}
json.dump(summ, open(os.path.join(OUT, 'summary-context-anchor.json'), 'w'), indent=1)
for k, v in summ.items():
    b = v.get('body', {}); nb = sum(b.get(x, 0) for x in ('correct', 'wrong', 'not_found', 'ambiguous'))
    na = v.get('no_alignment', {}); nna = sum(na.values()) - sum(val for kk, val in na.items() if kk.startswith('L='))
    fnv = {**v.get('in_footnote', {})}
    print(k, 'body n', nb, 'correct', b.get('correct', 0), 'wrong', b.get('wrong', 0), 'notfound', b.get('not_found', 0), 'ambig', b.get('ambiguous', 0),
          '| no_align n', nna, dict(na), '| footnote', fnv, '| straddle', v.get('straddles_footnote', {}))
