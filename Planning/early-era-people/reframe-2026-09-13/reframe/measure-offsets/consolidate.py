#!/usr/bin/env python3
"""Consolidates the measure-offsets outputs into consolidated.json (read-only over the files beside it)."""
import json, os, collections
OUT = os.path.dirname(os.path.abspath(__file__))
te = json.load(open(os.path.join(OUT, 'summary-text-equality.json')))
ft = json.load(open(os.path.join(OUT, 'summary-flat-text.json')))
pop = te['population_docs_by_band']; tot = sum(pop.values())
bands = ['1861-1899', '1900-1929', '1930-1945', '1946-']
def weighted(src, key):
    return round(sum(src[b][key]['rate'] * pop[b] for b in bands) / tot, 4)
c = {'population': pop, 'population_total': tot,
     'body_text_weighted': {k: weighted(te['docs'], k) for k in ('exact', 'ws_norm', 'dec_exact')},
     'flat_weighted': {k: weighted(ft['docs'], k) for k in ('exact', 'ws_norm', 'ws_strip', 'ws_strip_minus_footnotes')}}
fspans = [json.loads(l) for l in open(os.path.join(OUT, 'flat-spans.jsonl'))]
# re-run the no-fallback cascade classification per band from the saved variant summary
v = json.load(open(os.path.join(OUT, 'summary-context-anchor-c20_10.json')))
v3 = json.load(open(os.path.join(OUT, 'summary-context-anchor-c20_10_0.json')))
c['anchor'] = {}
for store in ('sweep_filtered', 'control_filtered'):
    for lab in ['ALL'] + bands:
        k = '%s/%s' % (store, lab)
        n_all = sum(1 for r in fspans if r['store'] == store and (lab == 'ALL' or r['band'] == lab))
        b = v[k].get('body', {}); na = v[k].get('no_alignment', {}); fn = v[k].get('in_footnote', {}); st = v[k].get('straddles_footnote', {})
        nbody = sum(b.get(x, 0) for x in ('correct', 'wrong', 'not_found', 'ambiguous'))
        nfn = sum(val for kk, val in fn.items() if not kk.startswith('L=')) + sum(val for kk, val in st.items() if not kk.startswith('L='))
        nna = sum(val for kk, val in na.items() if not kk.startswith('L='))
        b3 = v3[k].get('body', {}); fn3 = v3[k].get('in_footnote', {})
        c['anchor'][k] = {'spans': n_all, 'body_with_ground_truth': nbody,
                          'c20_10_correct': b.get('correct', 0), 'c20_10_wrong': b.get('wrong', 0), 'c20_10_refused_or_not_found': b.get('ambiguous', 0) + b.get('not_found', 0),
                          'footnote_or_straddling': nfn, 'c20_10_footnote_misplaced': fn.get('placed_footnote_span_in_body', 0),
                          'no_alignment_docs_spans': nna, 'c20_10_no_alignment_unique_unverified': na.get('unique_unverifiable', 0),
                          'c20_10_0_correct': b3.get('correct', 0), 'c20_10_0_footnote_misplaced': fn3.get('placed_footnote_span_in_body', 0)}
json.dump(c, open(os.path.join(OUT, 'consolidated.json'), 'w'), indent=1)
print(json.dumps(c, indent=1))
