#!/usr/bin/env python3
"""Verifier: footnote/label exclusion and anchored mapping, derived from the TEI (not from
the original's aligner). Read-only; stdlib only.

For each sampled document, re-runs harvest_embeddings' R-0 rule on the TEI copy R-0 was built
from (~/frus-volumes), but tracks for every character which elements enclose it. Checks the
reconstruction equals the stored R-0 text exactly. Flags characters the render flat text cannot
contain, per the parser/converter rules read from source:
  FN    inside a <note> that is not transparent (rend=inline and type!=source is transparent)
  LIST  inside a non-<item> child of <list>  (ASTToRenderNodeConverter compactMap on .listItem)
  TAB   inside a non-<row> child of <table> or non-<cell> child of <row>
  FIG   inside a child of <figure> (figureBlock keeps only altText)
  CHO   inside a non-preferred child of <choice>
Compares the remaining non-whitespace text with the Swift flat text the original produced
(flat-sample.jsonl, the app's own buildFlatText) and, where equal, uses that as ground truth
to score an anchored exact-unique search written here.
"""
import os, re, json, gzip, html, hashlib, collections
HERE = os.path.dirname(os.path.abspath(__file__))
R0SRC = os.path.expanduser('~/frus-volumes')
CUR = '/Users/jbotts/Development/frus/volumes'
TEXT = os.path.expanduser('~/frus-semantic-raw/text')
MO = '/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad/reframe/measure-offsets'
STORES = {'sweep': os.path.expanduser('~/frus-ner-raw-filtered/detected'),
          'control': os.path.expanduser('~/frus-ner-raw-control-filtered/detected')}
TAG = re.compile(r"<[^>]+>")
DOCSPLIT = re.compile(r'(?=<div\b[^>]*type="document")')
XMLID = re.compile(r'xml:id="([^"]+)"')
ATTR = re.compile(r'([\w:.-]+)\s*=\s*"([^"]*)"')
FN, LIST, TAB, FIG, CHO = 1, 2, 4, 8, 16
ENT = re.compile(r'&(#x[0-9a-fA-F]+|#[0-9]+|[A-Za-z][A-Za-z0-9]*);')

def rd(p):
    op = gzip.open if p.endswith('.gz') else open
    with op(p, 'rt', encoding='utf-8') as f:
        return [json.loads(l) for l in f if l.strip()]

def segments(xml):
    out = {}
    for seg in DOCSPLIT.split(xml)[1:]:
        tag_end = seg.find('>'); cut = len(seg)
        nxt = seg.find('<div', tag_end + 1)
        if nxt != -1: cut = min(cut, nxt)
        be = seg.find('</body>')
        if be != -1: cut = min(cut, be)
        m = XMLID.search(seg[:600])
        if m: out.setdefault(m.group(1), seg[:cut])
    return out

def reconstruct(seg):
    els = []  # dicts: name, attrs, parent, kids
    stack = []
    raw_chars = []; owner = []  # owner = innermost element index or -1
    pos = 0
    def emit(text):
        o = stack[-1] if stack else -1
        for ch in text:
            raw_chars.append(ch); owner.append(o)
    for m in TAG.finditer(seg):
        emit(seg[pos:m.start()])
        raw_chars.append(' '); owner.append(-2)
        t = m.group(0); pos = m.end()
        if t.startswith('<!') or t.startswith('<?'): continue
        mm = re.match(r'<\s*(/)?\s*([^\s/>]+)', t)
        if not mm: continue
        closing, name = mm.group(1), mm.group(2)
        if closing:
            if name in [els[i]['name'] for i in stack]:
                while stack:
                    i = stack.pop()
                    if els[i]['name'] == name: break
            continue
        idx = len(els)
        par = stack[-1] if stack else -1
        els.append({'name': name, 'attrs': dict(ATTR.findall(t)), 'parent': par, 'kids': []})
        if par >= 0: els[par]['kids'].append(idx)
        if not t.endswith('/>'): stack.append(idx)
    emit(seg[pos:])
    # per-element own drop flag
    own = [0] * len(els)
    for i, e in enumerate(els):
        a = e['attrs']; p = els[e['parent']] if e['parent'] >= 0 else None
        if e['name'] == 'note' and not (a.get('rend') == 'inline' and a.get('type') != 'source'):
            own[i] |= FN
        if p is not None:
            if p['name'] == 'list' and e['name'] != 'item': own[i] |= LIST
            if (p['name'] == 'table' and e['name'] != 'row') or (p['name'] == 'row' and e['name'] != 'cell'): own[i] |= TAB
            if p['name'] in ('figure', 'formula'): own[i] |= FIG
            if p['name'] == 'choice':
                kids = p['kids']
                pref = next((k for k in kids if els[k]['name'] == 'corr'), None)
                if pref is None: pref = next((k for k in kids if els[k]['name'] == 'reg'), None)
                if pref is None: pref = next((k for k in kids if els[k]['name'] != 'sic'), None)
                if i != pref: own[i] |= CHO
    cum = [0] * len(els)
    for i, e in enumerate(els):
        cum[i] = own[i] | (cum[e['parent']] if e['parent'] >= 0 else 0)
    def cflag(o):
        if o < 0: return 0
        f = cum[o]
        n = els[o]['name']
        if n in ('list', 'table', 'row'): f |= LIST if n == 'list' else TAB
        if n == 'figure': f |= FIG
        if n == 'choice' and els[o]['kids']: f |= CHO
        return f
    flags = [cflag(o) for o in owner]
    # whitespace normalisation exactly as " ".join(text.split())
    out = []; of = []; word = []; wf = []
    for ch, f in zip(raw_chars, flags):
        if ch.isspace():
            if word:
                if out: out.append(' '); of.append(0)
                out.extend(word); of.extend(wf); word = []; wf = []
        else:
            word.append(ch); wf.append(f)
    if word:
        if out: out.append(' '); of.append(0)
        out.extend(word); of.extend(wf)
    counts = collections.Counter(e['name'] for e in els)
    return ''.join(out), of, counts

def decode(raw, flags):
    dec = []; dflag = []; m = [0] * (len(raw) + 1); i = 0
    for mo in ENT.finditer(raw):
        for k in range(i, mo.start()):
            m[k] = len(dec); dec.append(raw[k]); dflag.append(flags[k])
        rep = html.unescape(mo.group(0))
        for k in range(mo.start(), mo.end()): m[k] = len(dec)
        for ch in rep: dec.append(ch); dflag.append(flags[mo.start()])
        i = mo.end()
    for k in range(i, len(raw)):
        m[k] = len(dec); dec.append(raw[k]); dflag.append(flags[k])
    m[len(raw)] = len(dec)
    return ''.join(dec), dflag, m

def count_occ(needle, hay, limit=2):
    res = []; i = hay.find(needle)
    while i != -1 and len(res) < limit:
        res.append(i); i = hay.find(needle, i + 1)
    return res

def main():
    orig = [(r['band'], r['volume'], r['d']) for r in map(json.loads, open(os.path.join(MO, 'sample-docs.jsonl')))]
    fresh = [(r['band'], r['volume'], r['d']) for r in map(json.loads, open(os.path.join(HERE, 'v1-sampleB.jsonl')))]
    swift = {(r['volume'], r['d']): r for r in map(json.loads, open(os.path.join(MO, 'swiftcli', 'flat-sample.jsonl')))}
    their_docs = {(r['volume'], r['d']): r for r in map(json.loads, open(os.path.join(MO, 'flat-docs.jsonl')))}
    report = {}
    drift = {}
    for tag, sample in (('A', orig), ('B', fresh)):
        need = collections.defaultdict(set)
        for b, v, d in sample: need[v].add(d)
        for v in need:
            if v not in drift:
                h1 = hashlib.md5(open(os.path.join(R0SRC, v + '.xml'), 'rb').read()).hexdigest()
                h2 = hashlib.md5(open(os.path.join(CUR, v + '.xml'), 'rb').read()).hexdigest()
                drift[v] = h1 == h2
        docs = {}
        for v in need:
            xml = open(os.path.join(R0SRC, v + '.xml'), encoding='utf-8').read()
            segs = segments(xml)
            r0 = {r['d']: r['t'] for r in rd(os.path.join(TEXT, v + '.jsonl.gz')) if r['d'] in need[v]}
            for d in need[v]:
                raw, fl, counts = reconstruct(segs[d])
                docs[(v, d)] = (raw, fl, counts, r0[d])
        spans = {s: collections.defaultdict(set) for s in STORES}
        for s, dp in STORES.items():
            for v in need:
                p = os.path.join(dp, v + '.jsonl.gz')
                if not os.path.exists(p): p = os.path.join(dp, v + '.jsonl')
                for r in rd(p):
                    if r['d'] in need[v]: spans[s][(v, r['d'])].add((r['s'], r['e'], r['n']))
        rep = {'docs': len(sample), 'reconstruct_equals_r0': 0, 'element_counts_docs_with': collections.Counter(),
               'flat_cmp': collections.Counter(), 'flat_cmp_by_band': collections.defaultdict(collections.Counter),
               'spankind': {s: collections.Counter() for s in STORES},
               'spankind_by_band': {s: collections.defaultdict(collections.Counter) for s in STORES},
               'anchor': {s: collections.Counter() for s in STORES},
               'anchor_their354': {s: collections.Counter() for s in STORES},
               'residual_docs': []}
        for b, v, d in sample:
            raw, fl, counts, r0 = docs[(v, d)]
            if raw == r0: rep['reconstruct_equals_r0'] += 1
            else: rep.setdefault('reconstruct_mismatch', []).append([v, d]); continue
            for k in ('label', 'choice', 'figure', 'table', 'list', 'note'):
                if counts.get(k): rep['element_counts_docs_with'][k] += 1
            dec, dfl, m = decode(raw, fl)
            nw = [i for i, ch in enumerate(dec) if not ch.isspace()]
            A = ''.join(dec[i] for i in nw); Af = [dfl[i] for i in nw]
            pos_in_A = {}
            for j, i in enumerate(nw): pos_in_A[i] = j
            gt_map = None
            if tag == 'A':
                F = ''.join(swift[(v, d)]['flat'].split())
                variants = {'minus_fn': FN, 'minus_fn_list': FN | LIST, 'minus_all': FN | LIST | TAB | FIG | CHO}
                ok = {}
                for name, mask in variants.items():
                    em = ''.join(ch for ch, f in zip(A, Af) if not (f & mask))
                    ok[name] = em == F
                    if ok[name]:
                        rep['flat_cmp'][name] += 1; rep['flat_cmp_by_band'][b][name] += 1
                if ok['minus_all']:
                    mask = FN | LIST | TAB | FIG | CHO
                    gt_map = {}; c = 0
                    for j, f in enumerate(Af):
                        if not (f & mask): gt_map[j] = c; c += 1
                else:
                    rep['residual_docs'].append([b, v, d, dict(counts)])
                if their_docs[(v, d)]['ws_strip_minus_footnotes'] != ok['minus_fn']:
                    rep['flat_cmp']['disagree_with_original_minus_fn'] += 1
            for s in STORES:
                for st, en, n in spans[s][(v, d)]:
                    ds, de = m[st], m[en]
                    idxs = [pos_in_A[i] for i in range(ds, de) if i in pos_in_A]
                    if not idxs: rep['spankind'][s]['empty'] += 1; continue
                    fs = [Af[j] for j in idxs]
                    if all(f == 0 for f in fs): kind = 'body'
                    elif all(f & FN for f in fs): kind = 'footnote'
                    elif any(f & FN for f in fs): kind = 'partly_footnote'
                    else: kind = 'dropped_other'
                    rep['spankind'][s][kind] += 1; rep['spankind'][s]['all'] += 1
                    rep['spankind_by_band'][s][b][kind] += 1; rep['spankind_by_band'][s][b]['all'] += 1
                    if tag != 'A' or gt_map is None: continue
                    a0, a1 = idxs[0], idxs[-1] + 1
                    for cascade_name, cascade in (('c20_10', (20, 10)), ('c20_10_0', (20, 10, 0))):
                        placed = None
                        for c in cascade:
                            lo = max(0, a0 - c)
                            occ = count_occ(A[lo:a1 + c], F)
                            if len(occ) == 1: placed = occ[0] + (a0 - lo); break
                        key = cascade_name + '/' + kind
                        cnt = rep['anchor'][s]
                        cnt[key + '/n'] += 1
                        truth = gt_map.get(a0) if kind == 'body' else None
                        if placed is None: cnt[key + '/refused'] += 1
                        elif kind == 'body' and placed == truth: cnt[key + '/correct'] += 1
                        else: cnt[key + '/placed_wrong_or_nonbody'] += 1
                        if their_docs[(v, d)]['ws_strip_minus_footnotes']:
                            c2 = rep['anchor_their354'][s]
                            c2[key + '/n'] += 1
                            if placed is None: c2[key + '/refused'] += 1
                            elif kind == 'body' and placed == truth: c2[key + '/correct'] += 1
                            else: c2[key + '/placed_wrong_or_nonbody'] += 1
        def plain(x):
            if isinstance(x, (collections.Counter, dict, collections.defaultdict)):
                return {k: plain(val) for k, val in x.items()}
            return x
        report[tag] = plain(rep)
    report['volumes_identical_r0_copy_vs_current'] = sum(drift.values())
    report['volumes_checked'] = len(drift)
    report['volumes_differing'] = sorted(v for v, same in drift.items() if not same)
    json.dump(report, open(os.path.join(HERE, 'v2-flat.json'), 'w'), indent=1)
    print(json.dumps(report, indent=1)[:12000])

main()
