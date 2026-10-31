import json, re
R="/Applications/FRUS Explorer.app/Contents/Resources/"
def load(n): return json.load(open(R+n))
sf=load("series-facts-index.json"); by=sf["byNaId"]
print("statuses:", sf["statuses"]); print("restrictions:", sf["restrictions"]); print("useRestrictions:", sf["useRestrictions"]); print("referenceUnits:", sf["referenceUnits"])
for naid in ("602875","2839192"):
    e=by[naid]
    print(f"\nNAID {naid}: creator={sf['headings'][e['c']]!r} | extent={e['x']} | years {e['y0']}-{e['y1']} | accessStatus={sf['statuses'][e['as']]!r} | useStatus={sf['statuses'][e['us']]!r} | restrictions={[sf['restrictions'][i] for i in e.get('ar',[])]} | refUnit={sf['referenceUnits'][e['ru']]!r}")
y0=[e.get("y0") for e in by.values() if isinstance(e.get("y0"),int)]
print("\nentries with y0:", len(y0), "of", len(by), "| y0 < 1940:", sum(1 for y in y0 if y<1940), "| y0 < 1900:", sum(1 for y in y0 if y<1900), "| y1 < 1940:", sum(1 for e in by.values() if isinstance(e.get('y1'),int) and e['y1']<1940))
vs=load("volume-sources-index.json")
print("\nvolume-sources-index:", {k:(type(v).__name__, len(v) if hasattr(v,'__len__') else v) for k,v in vs.items()})
for k in ("lots","majorCollections","recordGroups"):
    v=vs[k]
    if isinstance(v,dict): print(f"  {k} sample:", json.dumps(list(v.items())[:1], ensure_ascii=False)[:500])
    elif isinstance(v,list): print(f"  {k} sample:", json.dumps(v[:1], ensure_ascii=False)[:500])
txt=json.dumps(vs)
for s in ("59D95","89D149","602875","2839192","66D95","63D351"):
    print(f"  '{s}' occurs in volume-sources-index.json text:", s in txt, "| count:", txt.count(s))
ec=load("external-citation-index.json")
etxt=json.dumps(ec)
for s in ("59D95","89D149","66D95","63D351","National Security Affairs","Rosenberg","Whitman"):
    print(f"  '{s}' occurs in external-citation-index.json text:", etxt.count(s))
print("external-citation-index coverage:", json.dumps(ec.get("coverage"))[:400])
