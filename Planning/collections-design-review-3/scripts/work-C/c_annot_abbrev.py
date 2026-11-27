# Sum the bundled annotations index's abbreviations documents at a revision (JSON on stdin).
import json, sys
d = json.load(sys.stdin)
f = d['fields']
print('fields:', f)
i = f.index('abbreviations')
vals = [v[1][i] for v in d['volumes'].values()]
print('index version', d['indexVersion'], 'abbreviations documents', sum(vals), 'volumes > 0', sum(1 for x in vals if x > 0))
