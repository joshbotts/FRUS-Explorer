#!/usr/bin/env python3
"""#234 reframe — R-0 offsets -> the reader's HIGHLIGHT coordinate space (render flat text).

Read-only, stdlib only. Inputs (all produced under this directory):
  swiftcli/flat-sample.jsonl  — buildFlatText(from:) + footnote flat texts for the 400 sampled
                                documents, computed by swiftcli/flatcli, which compiles the app's own
                                FRUSDocumentParser / ASTToRenderNodeConverter / FRUSRenderNode sources.
  sample-docs.jsonl, sample-spans.jsonl — from measure_text_equality.py.
R-0 text is re-read through ner_store.volume_text.

Per document: exact / whitespace-normalised / whitespace-stripped equality of R-0 (entity-decoded)
with the flat text, and whether R-0 minus its footnote texts equals the flat text once whitespace
is stripped (the flat text excludes footnote bodies and fuses block seams with no separator).

Per detected span: whether it falls in a footnote (no body flat-text offset exists for it), whether a
ground-truth flat offset is recovered through the non-whitespace alignment, whether the surface
string sits verbatim at that offset (or only with whitespace changed, e.g. a <lb/> rendered "\n"),
and how a no-alignment string search near the proportionally mapped offset performs against the
ground truth.
"""
import sys, os, json, re, html, collections
sys.path.insert(0, '/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/tools/semantic-harvest')
import ner_store as ns
OUT = os.path.dirname(os.path.abspath(__file__))
TEXT = os.path.expanduser('~/frus-semantic-raw/text')
ENTITY = re.compile(r'&(#x[0-9a-fA-F]+|#[0-9]+|[A-Za-z][A-Za-z0-9]*);')
WINDOWS = (50, 200, 1000)

def decode_with_map(s):
    out = []; m = [0] * (len(s) + 1); i = 0; pos = 0
    for mo in ENTITY.finditer(s):
        for k in range(i, mo.start()):
            m[k] = pos; out.append(s[k]); pos += 1
        rep = html.unescape(mo.group(0))
        for k in range(mo.start(), mo.end()): m[k] = pos
        out.append(rep); pos += len(rep); i = mo.end()
    for k in range(i, len(s)):
        m[k] = pos; out.append(s[k]); pos += 1
    m[len(s)] = pos
    return ''.join(out), m

def nonws(s):
    idx = [i for i, ch in enumerate(s) if not ch.isspace()]
    return ''.join(s[i] for i in idx), idx

def occurrences(needle, hay):
    res = []; i = hay.find(needle)
    while i != -1:
        res.append(i); i = hay.find(needle, i + 1)
    return res

def rate(k, n): return {'k': k, 'n': n, 'rate': round(k / n, 4) if n else None}

def main():
    flat = {(r['volume'], r['d']): r for r in map(json.loads, open(os.path.join(OUT, 'swiftcli', 'flat-sample.jsonl')))}
    docs = [json.loads(l) for l in open(os.path.join(OUT, 'sample-docs.jsonl'))]
    spans = [json.loads(l) for l in open(os.path.join(OUT, 'sample-spans.jsonl'))]
    texts = {}
    for v in sorted({d['volume'] for d in docs}):
        t = ns.volume_text(TEXT, v)
        for d in docs:
            if d['volume'] == v: texts[(v, d['d'])] = t[d['d']]
    doc_rows = []; maps = {}
    for d in docs:
        key = (d['volume'], d['d']); f = flat.get(key)
        rec = {'band': d['band'], 'volume': d['volume'], 'd': d['d']}
        if f is None:
            rec['flat_missing'] = True; doc_rows.append(rec); continue
        a = texts[key]; dec, dmap = decode_with_map(a); fl = f['flat']
        rec.update(flat_missing=False, r0_len=len(a), flat_len=len(fl), non_bmp=f['flat_utf16'] != f['flat_scalars'],
                   footnotes=len(f['footnotes']), exact=dec == fl, ws_norm=' '.join(dec.split()) == ' '.join(fl.split()))
        dn, didx = nonws(dec); fn_, fidx = nonws(fl)
        rec['ws_strip'] = dn == fn_
        # remove footnote texts (in order) from the decoded R-0 non-ws string
        infn = [False] * len(dn); cursor = 0; fn_found = 0
        for note in f['footnotes']:
            nn = ''.join(note.split())
            if not nn: fn_found += 1; continue
            j = dn.find(nn, cursor)
            if j == -1: continue
            for k in range(j, j + len(nn)): infn[k] = True
            cursor = j + len(nn); fn_found += 1
        body_chars = [k for k in range(len(dn)) if not infn[k]]
        remainder = ''.join(dn[k] for k in body_chars)
        rec['footnotes_located'] = fn_found
        rec['ws_strip_minus_footnotes'] = remainder == fn_
        rec['footnote_share_of_r0_nonws'] = round(sum(infn) / max(1, len(dn)), 4)
        # ground-truth map: R-0 code point -> flat index (None when whitespace, in footnote, or no alignment)
        gt = None
        if rec['ws_strip_minus_footnotes']:
            nonws_pos = {didx[k]: None for k in range(len(dn))}
            b = 0
            for k in range(len(dn)):
                if infn[k]: nonws_pos[didx[k]] = 'fn'
                else: nonws_pos[didx[k]] = fidx[b]; b += 1
            gt = nonws_pos
        maps[key] = (a, dec, dmap, fl, gt)
        doc_rows.append(rec)
    span_rows = []
    for s in spans:
        key = (s['volume'], s['d'])
        if key not in maps: continue
        a, dec, dmap, fl, gt = maps[key]
        start = s['s']; surface = s['n']; end = start + len(surface)
        dsurf = html.unescape(surface)
        ds, de = dmap[start], dmap[end]
        row = {'store': s['store'], 'band': s['band'], 'volume': s['volume'], 'd': s['d'], 's': start, 'n': surface}
        if gt is None:
            row['cls'] = 'no_alignment'; span_rows.append(row); continue
        # first and last non-ws chars of the span in decoded coordinates
        nw = [i for i in range(ds, de) if not dec[i].isspace()]
        if not nw:
            row['cls'] = 'empty'; span_rows.append(row); continue
        firsts = gt.get(nw[0]); lasts = gt.get(nw[-1])
        kinds = {gt.get(i) == 'fn' for i in nw}
        if kinds == {True}:
            row['cls'] = 'in_footnote'; span_rows.append(row); continue
        if True in kinds:
            row['cls'] = 'straddles_footnote'; span_rows.append(row); continue
        fs, fe = firsts, lasts + 1
        row['flat_s'] = fs; row['flat_e'] = fe
        seg = fl[fs:fe]
        if seg == dsurf: row['cls'] = 'body_verbatim'
        elif ''.join(seg.split()) == ''.join(dsurf.split()): row['cls'] = 'body_whitespace_differs'
        else: row['cls'] = 'body_other'
        row['flat_segment'] = seg
        occ = occurrences(dsurf, fl)
        prop = start * len(fl) / max(1, len(a))
        row['occ_total'] = len(occ)
        for w in WINDOWS:
            near = [o for o in occ if abs(o - prop) <= w]
            row['near%d' % w] = len(near)
            row['near%d_correct' % w] = len(near) == 1 and near[0] == fs
        nearest = min(occ, key=lambda o: abs(o - prop)) if occ else None
        row['nearest_correct'] = nearest == fs if occ else False
        row['shift'] = fs - start
        span_rows.append(row)
    with open(os.path.join(OUT, 'flat-docs.jsonl'), 'w') as fh:
        for r in doc_rows: fh.write(json.dumps(r, ensure_ascii=False) + '\n')
    with open(os.path.join(OUT, 'flat-spans.jsonl'), 'w') as fh:
        for r in span_rows: fh.write(json.dumps(r, ensure_ascii=False) + '\n')
    summ = {'docs': {}, 'spans': {}}
    labels = ['ALL'] + [b[2] for b in ns.BANDS]
    for lab in labels:
        rows = [r for r in doc_rows if not r['flat_missing'] and (lab == 'ALL' or r['band'] == lab)]
        n = len(rows)
        summ['docs'][lab] = {k: rate(sum(1 for r in rows if r[k]), n) for k in ('exact', 'ws_norm', 'ws_strip', 'ws_strip_minus_footnotes', 'non_bmp')}
        summ['docs'][lab]['docs_with_footnotes'] = sum(1 for r in rows if r['footnotes'])
        summ['docs'][lab]['footnote_share_of_r0_nonws_mean'] = round(sum(r['footnote_share_of_r0_nonws'] for r in rows) / max(1, n), 4)
        summ['docs'][lab]['flat_missing'] = sum(1 for r in doc_rows if r['flat_missing'] and (lab == 'ALL' or r['band'] == lab))
    for store in ('sweep_filtered', 'control_filtered'):
        for lab in labels:
            rows = [r for r in span_rows if r['store'] == store and (lab == 'ALL' or r['band'] == lab)]
            n = len(rows); c = collections.Counter(r['cls'] for r in rows)
            body = [r for r in rows if r['cls'].startswith('body')]
            d = {'spans': n, 'classes': dict(c)}
            d['in_footnote_or_straddling'] = rate(c['in_footnote'] + c['straddles_footnote'], n)
            d['body_offset_recovered'] = rate(len(body), n)
            d['body_verbatim_at_offset'] = rate(c['body_verbatim'], len(body))
            for w in WINDOWS:
                d['search_unique_within_%d_and_correct' % w] = rate(sum(1 for r in body if r['near%d_correct' % w]), len(body))
            d['search_nearest_correct'] = rate(sum(1 for r in body if r['nearest_correct']), len(body))
            d['search_unique_in_document'] = rate(sum(1 for r in body if r['occ_total'] == 1), len(body))
            shifts = sorted(abs(r['shift']) for r in body)
            d['abs_shift_p50_p90_max'] = [shifts[len(shifts) // 2], shifts[int(len(shifts) * .9)], shifts[-1]] if shifts else None
            summ['spans']['%s/%s' % (store, lab)] = d
    json.dump(summ, open(os.path.join(OUT, 'summary-flat-text.json'), 'w'), indent=1, ensure_ascii=False)
    print(json.dumps(summ, indent=1, ensure_ascii=False))

main()
