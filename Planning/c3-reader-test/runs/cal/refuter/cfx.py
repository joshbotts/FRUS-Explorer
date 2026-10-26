import json
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
cf = json.load(open(R+"central-files-index.json"))
lf = cf["lotFiles"]
print("lotFiles type:", type(lf).__name__, "len:", len(lf))
if isinstance(lf, dict):
    ks = list(lf.keys()); print("sample keys:", ks[:8]); print("sample:", json.dumps(lf[ks[0]], ensure_ascii=False)[:700])
    for want in ["65D438","74D272","81D113","65 D 438","74 D 272","81 D 113"]:
        for k in ks:
            if k.replace(" ","").upper() == want.replace(" ","").upper():
                print("\n", k, "=>", json.dumps(lf[k], ensure_ascii=False)[:900])
else:
    print("sample:", json.dumps(lf[0], ensure_ascii=False)[:700])
    for e in lf:
        s = json.dumps(e)
        if any(w in s.replace(" ","") for w in ["65D438","74D272","81D113"]): print("\n", s[:900])
lc = json.load(open(R+"lot-claimants-index.json"))
print("\nlot-claimants keys:", list(lc.keys())[:10])
s = json.dumps(lc)
for w in ["65D438","74D272","81D113"]: print(w, "in lot-claimants:", w in s.replace(" ",""))
cur = json.load(open(R+"curated-lot-resolutions.json"))
s = json.dumps(cur)
for w in ["65D438","74D272","81D113"]: print(w, "in curated-lot-resolutions:", w in s.replace(" ",""))
# presidential library catalog
pl = json.load(open(R+"presidential-library-catalog.json"))
print("\npresidential-library-catalog keys:", list(pl.keys())[:12])
for k, v in pl.items():
    if isinstance(v, list): print(" ", k, "list", len(v), json.dumps(v[0], ensure_ascii=False)[:400] if v else "")
    elif isinstance(v, dict): print(" ", k, "dict", len(v), json.dumps(list(v.items())[:1], ensure_ascii=False)[:400])
    else: print(" ", k, "=", v)
s = json.dumps(pl, ensure_ascii=False)
for w in ["National Security Files","NSC Files","National Security Affairs","Brzezinski","Staff Material","Recordings and Transcripts","National Security File","Backchannel"]:
    print(f"  '{w}' occurrences in library catalog: {s.count(w)}")
