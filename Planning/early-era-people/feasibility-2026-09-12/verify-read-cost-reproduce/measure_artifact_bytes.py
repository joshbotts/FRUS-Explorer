# Measures REAL serialized bytes for the shape (a) and shape (b) artifacts RC-5/RC-6 only estimated.
# Rows exactly as verify_rows.py derives them: persons = per-volume distinct normalised names,
# mentions = distinct (doc, name) pairs. Two layouts each: (1) flat JSON with spelled-out keys and a
# deterministic synthetic ref per (volume, name) — sha1 prefix, 8 hex; (2) compact per-volume
# layout: persons as a name array, mentions as doc -> [person index]. gzip sizes alongside.
import json, gzip, os, re, hashlib, unicodedata
H = os.path.expanduser
scope = sorted(json.load(open(H('~/frus-ner-raw/scope.json')))['volumes'])
def norm(n): return re.sub(r'\s+', ' ', unicodedata.normalize('NFC', n)).strip().lower()
def body(path):
    op = gzip.open if path.endswith('.gz') else open
    with op(path, 'rt', encoding='utf-8') as f:
        for line in f:
            if line.strip(): yield json.loads(line)
def pick(d, v):
    for ext in ('.jsonl', '.jsonl.gz'):
        p = os.path.join(d, v + ext)
        if os.path.exists(p): return p
    raise FileNotFoundError(v)
MARKED = H('~/frus-ner-raw/marked'); CTRL = H('~/frus-ner-raw-control-filtered/detected')
def build(stores):
    flat = {'generated': '2026-09-12', 'persons': [], 'mentions': []}
    compact = {'g': '2026-09-12', 'v': {}}
    for v in scope:
        names = {}; pairs = set()
        for d in stores:
            for r in body(pick(d, v)):
                nn = norm(r['n']); pairs.add((r['d'], nn))
                if nn not in names: names[nn] = len(names)
        idx = {}
        for nn, i in names.items():
            ref = 'x' + hashlib.sha1(f'{v}|{nn}'.encode()).hexdigest()[:8]
            idx[nn] = ref
            flat['persons'].append({'volumeId': v, 'ref': ref, 'name': nn})
        for d, nn in sorted(pairs):
            flat['mentions'].append({'volumeId': v, 'documentId': d, 'ref': idx[nn]})
        docs = {}
        for d, nn in sorted(pairs): docs.setdefault(d, []).append(names[nn])
        compact['v'][v] = {'p': list(names.keys()), 'm': docs}
    return flat, compact
out = {}
for label, stores in (('shape_a_marked', [MARKED]), ('shape_b_union', [MARKED, CTRL])):
    flat, compact = build(stores)
    fb = json.dumps(flat, ensure_ascii=False, separators=(',', ':'), sort_keys=True).encode('utf-8')
    cb = json.dumps(compact, ensure_ascii=False, separators=(',', ':'), sort_keys=True).encode('utf-8')
    out[label] = {
        'persons_rows': len(flat['persons']), 'mention_rows': len(flat['mentions']),
        'flat_json_bytes': len(fb), 'flat_json_gzip_bytes': len(gzip.compress(fb, 9)),
        'compact_json_bytes': len(cb), 'compact_json_gzip_bytes': len(gzip.compress(cb, 9)),
        'flat_bytes_per_person_row_incl_mentions': round(len(fb) / len(flat['persons']), 1),
    }
here = os.path.dirname(os.path.abspath(__file__))
json.dump(out, open(os.path.join(here, 'artifact-bytes-output.json'), 'w'), indent=1)
print(json.dumps(out, indent=1))
