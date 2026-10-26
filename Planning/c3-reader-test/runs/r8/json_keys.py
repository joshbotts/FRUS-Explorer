import json
R="/Applications/FRUS Explorer.app/Contents/Resources/"
for fn in ["decimal-class-labels.json","central-files-index.json","series-facts-index.json","collection-usage-index.json","presidential-library-catalog.json","lot-claimants-index.json","external-citation-index.json","volume-sources-index.json","curated-lot-resolutions.json"]:
    j=json.load(open(R+fn))
    print("##",fn,type(j).__name__, list(j.keys())[:25] if isinstance(j,dict) else len(j))
    if isinstance(j,dict):
        for k,v in j.items():
            if isinstance(v,dict): print("   ",k,"dict",len(v),"keys e.g.",list(v.keys())[:6])
            elif isinstance(v,list): print("   ",k,"list",len(v),"e.g.",json.dumps(v[0])[:300] if v else "")
            else: print("   ",k,"=",str(v)[:120])
