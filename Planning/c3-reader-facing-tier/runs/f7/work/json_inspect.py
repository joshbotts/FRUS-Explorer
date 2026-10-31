import json
R="/Applications/FRUS Explorer.app/Contents/Resources/"
for f in ["collection-usage-index","external-citation-index","collection-authority","series-facts-index","central-files-index"]:
    d=json.load(open(R+f+".json"))
    print("==",f,type(d).__name__, list(d.keys())[:20] if isinstance(d,dict) else len(d))
    if isinstance(d,dict):
        for k,v in d.items():
            if isinstance(v,(list,dict)): print("  ",k,type(v).__name__,len(v), (str(list(v.items())[0])[:300] if isinstance(v,dict) and v else str(v[0])[:300] if isinstance(v,list) and v else ""))
            else: print("  ",k,str(v)[:150])
