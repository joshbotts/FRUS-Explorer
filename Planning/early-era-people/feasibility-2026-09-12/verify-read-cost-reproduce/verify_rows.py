# Independent re-derivation of RC-4 / RC-6 / RC-13 row counts.
# Differences from the author's slice.py/persons_rows.py: mention counts come from
# BODY line counts (not head['mentions']); head vs body parity is asserted; the
# pair-level union of marked+ctrl_filt is computed (the author left it as an upper bound);
# names are normalised with re.sub(r'\s+',' ') then casefold() on the NFC form.
import json, gzip, os, re, sys, unicodedata, collections
H = os.path.expanduser
REPO = '/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5'
STUDIO = '/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-ner-raw'
scope = json.load(open(H('~/frus-ner-raw/scope.json')))
vols = sorted(scope['volumes'])
assert len(vols) == 267, len(vols)
man = {m['volumeId']: m for m in json.load(open(REPO + '/FRUSExplorer/Resources/manifest.json'))}
def yr(v): return int(man[v]['dateRange']['earliest'][:4])
def norm(n): return re.sub(r'\s+', ' ', unicodedata.normalize('NFC', n)).strip().lower()
def body(path):
    op = gzip.open if path.endswith('.gz') else open
    with op(path, 'rt', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line: yield json.loads(line)
def pick(d, v):
    for ext in ('.jsonl', '.jsonl.gz'):
        p = os.path.join(d, v + ext)
        if os.path.exists(p): return p
    raise FileNotFoundError(v)
STORES = {
 'marked': H('~/frus-ner-raw/marked'),
 'ctrl_raw': H('~/frus-ner-raw-control/detected'),
 'ctrl_filt': H('~/frus-ner-raw-control-filtered/detected'),
 'sweep_raw': STUDIO + '/detected',
 'sweep_filt': H('~/frus-ner-raw-filtered/detected'),
 'sweep_bnd': H('~/frus-ner-raw-filtered-boundary/detected'),
}
R = collections.defaultdict(lambda: collections.Counter())  # group -> counter
corpus = {'marked': set(), 'ctrl_filt': set(), 'union': set()}
corpus_pre = {'marked': set(), 'ctrl_filt': set(), 'union': set()}
corpus_marked_casepres = set()
mention_len_sum = 0
parity_fail = []
for v in vols:
    pre = yr(v) < 1910
    groups = ['ALL', 'PRE1910' if pre else 'POST1910']
    heads = {k: json.load(open(os.path.join(d, v + '.head.json'))) for k, d in STORES.items()}
    for g in groups:
        R[g]['vols'] += 1
        R[g]['docs'] += heads['marked']['docs']
        R[g]['chars'] += heads['marked']['chars']
        R[g]['sweep_secs'] += heads['sweep_raw'].get('secs', 0)
        R[g]['ctrl_secs'] += heads['ctrl_raw'].get('secs', 0)
        for k in ('ctrl_raw', 'sweep_raw', 'sweep_filt', 'sweep_bnd'):
            R[g]['head_' + k] += heads[k]['mentions']
    # body reads for marked and ctrl_filt
    sets = {}
    for k in ('marked', 'ctrl_filt'):
        n = 0; pairs = set(); names = set()
        for r in body(pick(STORES[k], v)):
            n += 1
            nn = norm(r['n'])
            pairs.add((r['d'], nn)); names.add(nn)
            if k == 'marked':
                mention_len_sum += len(nn)
                corpus_marked_casepres.add(re.sub(r'\s+', ' ', r['n']).strip())
        if n != heads[k]['mentions']: parity_fail.append((v, k, n, heads[k]['mentions']))
        sets[k] = (pairs, names)
        for g in groups:
            R[g]['body_' + k] += n
            R[g]['pairs_' + k] += len(pairs)
            R[g]['persons_' + k] += len(names)
            R[g]['namebytes_' + k] += sum(len(x.encode('utf-8')) for x in names)
        corpus[k] |= names
        if pre: corpus_pre[k] |= names
    upairs = sets['marked'][0] | sets['ctrl_filt'][0]
    unames = sets['marked'][1] | sets['ctrl_filt'][1]
    for g in groups:
        R[g]['pairs_union'] += len(upairs)
        R[g]['persons_union'] += len(unames)
        R[g]['pairs_overlap'] += len(sets['marked'][0] & sets['ctrl_filt'][0])
        R[g]['persons_overlap'] += len(sets['marked'][1] & sets['ctrl_filt'][1])
    corpus['union'] |= unames
    if pre: corpus_pre['union'] |= unames
out = {g: dict(R[g]) for g in ('ALL', 'PRE1910', 'POST1910')}
for g in out:
    out[g]['sweep_days'] = round(out[g]['sweep_secs'] / 86400, 2)
out['corpus_distinct'] = {k: len(s) for k, s in corpus.items()}
out['corpus_distinct_pre1910'] = {k: len(s) for k, s in corpus_pre.items()}
out['corpus_distinct_marked_casepreserved'] = len(corpus_marked_casepres)
out['mean_marked_name_len_per_mention'] = round(mention_len_sum / out['ALL']['body_marked'], 2)
out['mean_marked_name_bytes_per_persons_row'] = round(out['ALL']['namebytes_marked'] / out['ALL']['persons_marked'], 2)
out['head_body_parity_failures'] = parity_fail
here = os.path.dirname(os.path.abspath(__file__))
json.dump(out, open(os.path.join(here, 'verify-rows-output.json'), 'w'), indent=1)
print(json.dumps(out, indent=1))
