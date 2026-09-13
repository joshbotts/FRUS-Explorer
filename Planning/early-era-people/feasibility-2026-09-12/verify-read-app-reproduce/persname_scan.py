"""Independent RA-2 check: over the 267 scope volumes' TEI, count <persName ...> elements and how many
carry corresp= / ref= / sameAs= (the app parser reads corresp ?? ref). Reads the corpus, not the marked store."""
import json, os, re, sys
scope = json.load(open(os.path.expanduser("~/frus-ner-raw/scope.json")))["volumes"]
vd = "/Users/jbotts/Development/frus/volumes"
TAG = re.compile(r"<persName\b([^>]*)>")
tot = 0; with_link = 0; with_ref = 0; with_corresp = 0; with_xmlid = 0; vols = 0; missing = []
per_vol = {}
for v in scope:
    p = os.path.join(vd, v + ".xml")
    if not os.path.exists(p): missing.append(v); continue
    vols += 1
    t = open(p, encoding="utf-8", errors="replace").read()
    n = 0; l = 0; r = 0; c = 0; x = 0
    for m in TAG.finditer(t):
        a = m.group(1); n += 1
        if "xml:id=" in a: x += 1
        if "corresp=" in a: c += 1
        if re.search(r'\bref=', a): r += 1
        if re.search(r'\b(corresp|ref|sameAs)=', a): l += 1
    tot += n; with_link += l; with_ref += r; with_corresp += c; with_xmlid += x
    per_vol[v] = n
res = dict(scope_volumes=len(scope), volumes_read=vols, missing=missing, persName_elements=tot,
           with_corresp_or_ref_or_sameAs=with_link, with_ref=with_ref, with_corresp=with_corresp, with_xmlid=with_xmlid)
print(json.dumps(res, indent=1))
json.dump(dict(res, per_volume=per_vol), open(sys.argv[1], "w"), indent=1)
