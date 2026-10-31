import json, re
R="/Applications/FRUS Explorer.app/Contents/Resources/"
def load(n): return json.load(open(R+n))
sf=load("series-facts-index.json"); by=sf["byNaId"]
print("byNaId entries:", len(by), "| sample key:", next(iter(by)), "| sample entry keys:", list(next(iter(by.values())).keys()))
for naid in ("602875","2839192","2658382"):
    print(f"\nseries-facts byNaId[{naid}] =", json.dumps(by.get(naid), ensure_ascii=False)[:900])
print("\nlegend:", json.dumps(sf.get("legend"))[:600])
# pre-1940 reach: count entries whose inclusive start year < 1940
def start_year(e):
    for k in ("inclusiveStart","inclusiveStartYear","startYear","inclusiveDates","inclusive","dates","coverage"):
        v=e.get(k)
        if isinstance(v,int): return v
        if isinstance(v,str):
            m=re.search(r'\b(1[6-9]\d\d|20\d\d)\b', v)
            if m: return int(m.group(1))
        if isinstance(v,dict):
            for kk in ("start","from","startYear","min"):
                if isinstance(v.get(kk),int): return v[kk]
        if isinstance(v,list) and v and isinstance(v[0],int): return v[0]
    return None
ys={k:start_year(e) for k,e in by.items()}
known=[y for y in ys.values() if y]
print("entries with a start year:", len(known), "| start < 1940:", sum(1 for y in known if y<1940), "| those:", sorted([(y,k) for k,y in ys.items() if y and y<1940])[:15])
cl=load("curated-lot-resolutions.json")
print("\ncurated-lot-resolutions note:", cl.get("note"))
print("curated series block:", json.dumps(cl.get("series"), ensure_ascii=False)[:1500])
print("curated lot 59D95:", [l for l in cl["lots"] if l.get("lotNumber")=="59D95"])
cf=load("central-files-index.json")
for i in (409,255):
    print("\ncentral-files lotFiles[%d]:"%i, json.dumps(cf["lotFiles"][i], ensure_ascii=False))
print("\ncentral-files numericalFile:", json.dumps(cf["numericalFile"], ensure_ascii=False)[:1200])
print("central-files countrySeries titles:", [ (c.get("title"), c.get("naId")) for c in cf["countrySeries"]][:12])
ca=load("collection-authority.json")["collections"]
cent=[c for c in ca if re.search(r'central file', c.get("name",""), re.I)]
print("\ncollection-authority 'central file' entries:", len(cent))
for c in cent[:12]: print("  ", c.get("id"), "| naId:", c.get("naId"), "| RG", c.get("recordGroup"), "|", c.get("name"), "| vols", len(c.get("volumeIds",[])))
print("any central-file entry with a naId:", any(c.get("naId") for c in cent))
l89=[c for c in ca if c.get("id")=="lot:89D149"][0]
print("\nlot:89D149 full:", json.dumps({k:v for k,v in l89.items()}, ensure_ascii=False)[:1200])
l59=[c for c in ca if c.get("id")=="lot:59D95"][0]
print("\nlot:59D95:", json.dumps({k:(v if k!='volumeIds' else len(v)) for k,v in l59.items()}, ensure_ascii=False)[:1200])
vs=load("volume-sources-index.json")
print("\nvolume-sources-index lots sample:", json.dumps(vs["lots"][:2] if isinstance(vs["lots"],list) else list(vs["lots"].items())[:2], ensure_ascii=False)[:600])
hit=[l for l in (vs["lots"] if isinstance(vs["lots"],list) else vs["lots"].values()) if "59D95" in json.dumps(l) or "89D149" in json.dumps(l)]
print("volume-sources-index lots mentioning 59D95/89D149:", json.dumps(hit, ensure_ascii=False)[:800])
