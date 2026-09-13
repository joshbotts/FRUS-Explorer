# Count TEI-rule-scope (267 volumes) R-0 documents by volume-id year era, to size the share of the
# untagged scope that pre-1906 Source Explorer-based features can reach. Stdlib only, read-only.
import json, os, gzip, re, sys
scope = json.load(open(os.path.expanduser('~/frus-ner-raw/scope.json')))
vols = scope['volumes']
base = os.path.expanduser('~/frus-semantic-raw/text')
def year(v):
    m = re.match(r'frus(\d{4})', v)
    return int(m.group(1)) if m else None
eras = {'<=1899': (0, 1899), '1900-1905': (1900, 1905), '1906-1909': (1906, 1909), '1910-1929': (1910, 1929),
        '1930-1945': (1930, 1945), '1946-': (1946, 9999)}
out = {k: {'volumes': 0, 'documents': 0} for k in eras}
total = 0
for v in vols:
    y = year(v)
    n = 0
    with gzip.open(os.path.join(base, v + '.jsonl.gz'), 'rt') as fh:
        for line in fh:
            if line.strip():
                n += 1
    total += n
    for k, (a, b) in eras.items():
        if a <= y <= b:
            out[k]['volumes'] += 1
            out[k]['documents'] += n
res = {'population': 'TEI-rule scope, 267 volumes (~/frus-ner-raw/scope.json); documents = lines in R-0 text layer; era by volume-id year',
       'total_documents': total, 'by_era': out,
       'le_1905_documents': out['<=1899']['documents'] + out['1900-1905']['documents']}
res['le_1905_share'] = round(res['le_1905_documents'] / total, 4)
json.dump(res, open(os.path.join(os.path.dirname(__file__), 'era_reach.json'), 'w'), indent=1)
print(json.dumps(res, indent=1))
