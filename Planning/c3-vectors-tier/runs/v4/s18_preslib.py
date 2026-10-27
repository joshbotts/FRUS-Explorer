import json
R="/Applications/FRUS Explorer.app/Contents/Resources/"
p=json.load(open(R+'presidential-library-catalog.json'))
print({k:(type(v).__name__,len(v) if hasattr(v,'__len__') else v) for k,v in p.items()})
rows=None
for k,v in p.items():
    if isinstance(v,list) and v and isinstance(v[0],dict): rows=v; print('rows key',k,list(v[0])); break
want=[('Kennedy','National Security Files'),('Johnson','National Security File'),('Carter','National Security Affairs'),('Eisenhower','Whitman')]
for lib,col in want:
    hits=[r for r in rows if lib.lower() in json.dumps(r).lower() and col.lower() in json.dumps(r).lower()]
    print(lib,col,len(hits))
    for r in hits[:2]: print('  ',json.dumps(r)[:400])
