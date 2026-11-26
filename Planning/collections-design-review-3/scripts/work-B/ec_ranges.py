import re, sys, glob, collections
root = sys.argv[1]
pat = re.compile(r'<!--\s*SOURCE:\s*([^|]+?)\s*\|[^>]*?\|\s*lines:\s*([0-9]+)[^|]*\|\s*key:\s*([^|\s]+)')
counts = collections.Counter()
keys = collections.defaultdict(list)
files_by = collections.defaultdict(set)
for f in sorted(glob.glob(root + '/Docs/EditableContent/*.md')):
    for line in open(f, encoding='utf-8'):
        for m in pat.finditer(line):
            src = m.group(1).strip()
            base = src.split('/')[-1]
            counts[base] += 1
            keys[base].append(m.group(3))
            files_by[base].add(f.split('/')[-1])
for b in ['CollectionExporter.swift','CollectionEditorView.swift','CollectionEntryInspector.swift','CollectionEntryRows.swift','MacCollectionManagerView.swift','CollectionCompositionRows.swift','Collection.swift','CollectionExporter+App.swift','CollectionOutline+App.swift']:
    print(b, counts[b], sorted(files_by[b]))
pre = [k for k in keys['CollectionExporter.swift'] if k.startswith('collection.preset')]
print('preset keys', len(pre))
print([k for k in keys['CollectionExporter.swift'] if not k.startswith('collection.preset')])
