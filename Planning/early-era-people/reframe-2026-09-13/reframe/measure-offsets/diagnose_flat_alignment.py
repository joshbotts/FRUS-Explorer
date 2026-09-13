#!/usr/bin/env python3
"""Why do some sampled documents fail the R-0(minus footnotes) == flat-text whitespace-stripped test?
Read-only. difflib over the non-whitespace strings of the failing documents; classifies each diff op
and prints examples. Also counts, in the TEI, nested <div> openings inside each failing document
(harvest_embeddings.py truncates R-0 at the next <div) and whether located-footnote count < footnotes.
Writes flat-alignment-diagnosis.json."""
import sys, os, json, re, html, difflib, collections
sys.path.insert(0, '/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/tools/semantic-harvest')
import ner_store as ns
OUT = os.path.dirname(os.path.abspath(__file__))
TEXT = os.path.expanduser('~/frus-semantic-raw/text')
flat = {(r['volume'], r['d']): r for r in map(json.loads, open(os.path.join(OUT, 'swiftcli', 'flat-sample.jsonl')))}
docs = [json.loads(l) for l in open(os.path.join(OUT, 'flat-docs.jsonl'))]
bad = [d for d in docs if not d['flat_missing'] and not d['ws_strip_minus_footnotes']]
res = {'failing_docs': len(bad), 'by_band': dict(collections.Counter(d['band'] for d in bad)), 'docs': []}
cause = collections.Counter()
for d in bad:
    key = (d['volume'], d['d']); f = flat[key]
    a = ns.volume_text(TEXT, d['volume'])[d['d']]
    dec = html.unescape(a)
    dn = ''.join(dec.split()); fn_ = ''.join(f['flat'].split())
    notes = [''.join(n.split()) for n in f['footnotes']]
    # remove footnotes in order
    cursor = 0; keep = []; located = 0; last = 0; mask = [False] * len(dn)
    for nn in notes:
        if not nn: located += 1; continue
        j = dn.find(nn, cursor)
        if j == -1: continue
        for k in range(j, j + len(nn)): mask[k] = True
        cursor = j + len(nn); located += 1
    rem = ''.join(ch for ch, m in zip(dn, mask) if not m)
    sm = difflib.SequenceMatcher(None, rem, fn_, autojunk=False)
    ops = [op for op in sm.get_opcodes() if op[0] != 'equal']
    r0_extra = sum(i2 - i1 for op, i1, i2, j1, j2 in ops if op in ('delete', 'replace'))
    flat_extra = sum(j2 - j1 for op, i1, i2, j1, j2 in ops if op in ('insert', 'replace'))
    ex = [[op, rem[max(0, i1 - 20):i2 + 5][:160], fn_[max(0, j1 - 20):j2 + 5][:160]] for op, i1, i2, j1, j2 in ops[:4]]
    # TEI nested div check
    xml = open('/Users/jbotts/Development/frus/volumes/%s.xml' % d['volume'], encoding='utf-8').read()
    m = re.search(r'<div\b[^>]*xml:id="%s"[^>]*>' % re.escape(d['d']), xml)
    nested = None
    if m:
        seg = xml[m.end():]
        # end of this document div: count div depth
        depth = 1; pos = 0; nested = 0
        for t in re.finditer(r'<(/?)div\b[^>]*?(/?)>', seg):
            if t.group(1): depth -= 1
            elif not t.group(2): depth += 1; nested += 1
            if depth == 0: break
    rec = {'volume': d['volume'], 'd': d['d'], 'band': d['band'], 'footnotes': len(notes), 'footnotes_located': located,
           'ops': len(ops), 'r0_extra_chars': r0_extra, 'flat_extra_chars': flat_extra, 'rem_len': len(rem), 'flat_len': len(fn_),
           'nested_divs_in_tei': nested, 'examples': ex}
    if nested: c = 'nested_div_truncates_r0'
    elif located < len(notes): c = 'footnote_not_located_in_r0'
    elif flat_extra and not r0_extra: c = 'flat_has_text_r0_lacks'
    elif r0_extra and not flat_extra: c = 'r0_has_text_flat_lacks'
    else: c = 'both_differ'
    rec['cause'] = c; cause[c] += 1
    res['docs'].append(rec)
res['causes'] = dict(cause)
json.dump(res, open(os.path.join(OUT, 'flat-alignment-diagnosis.json'), 'w'), indent=1, ensure_ascii=False)
print(json.dumps({k: res[k] for k in ('failing_docs', 'by_band', 'causes')}, indent=1))
for r in res['docs'][:46]:
    print(r['cause'], r['volume'], r['d'], 'fn', r['footnotes'], r['footnotes_located'], 'nested', r['nested_divs_in_tei'], 'r0x', r['r0_extra_chars'], 'flx', r['flat_extra_chars'], 'len', r['rem_len'], r['flat_len'])
    for e in r['examples'][:2]: print('   ', e)
