"""Where do the corresp-carrying <persName> elements in the 267 scope volumes sit? For each, find the
nearest enclosing/preceding <div ...> and the <front>/<body>/<back> region; also scan the marked store's
`c` field independently of the runbook."""
import json, os, re, gzip, collections
scope = json.load(open(os.path.expanduser("~/frus-ner-raw/scope.json")))["volumes"]
vd = "/Users/jbotts/Development/frus/volumes"
TAG = re.compile(r"<persName\b([^>]*)>")
DIV = re.compile(r"<div\b([^>]*)>")
byvol = collections.Counter(); region = collections.Counter(); divtypes = collections.Counter(); samples = []
in_doc_div = 0
for v in scope:
    t = open(os.path.join(vd, v + ".xml"), encoding="utf-8", errors="replace").read()
    body_s = t.find("<body"); back_s = t.find("<back")
    divs = [(m.start(), m.group(1)) for m in DIV.finditer(t)]
    for m in TAG.finditer(t):
        a = m.group(1)
        if "corresp=" not in a: continue
        byvol[v] += 1
        pos = m.start()
        reg = "front" if body_s == -1 or pos < body_s else ("back" if back_s != -1 and pos > back_s else "body")
        region[reg] += 1
        # nearest preceding <div>
        prev = None
        for dpos, dattr in divs:
            if dpos < pos: prev = dattr
            else: break
        ty = re.search(r'type="([^"]*)"', prev or "")
        xid = re.search(r'xml:id="([^"]*)"', prev or "")
        key = (reg, ty.group(1) if ty else None)
        divtypes[key] += 1
        if ty and ty.group(1) == "document": in_doc_div += 1
        if len(samples) < 8:
            cv = re.search(r'corresp="([^"]*)"', a).group(1)
            samples.append((v, reg, ty.group(1) if ty else None, xid.group(1) if xid else None, cv, t[pos:pos+120].replace("\n"," ")))
print("volumes with corresp persName:", len(byvol), "total:", sum(byvol.values()))
print("top volumes:", byvol.most_common(8))
print("by region:", dict(region))
print("by (region, nearest-div type):", dict(divtypes))
print("nearest div is type=document:", in_doc_div)
for s in samples: print("SAMPLE", s)
# marked store c-field
nonnull = 0; rows = 0; cvals = collections.Counter()
for fn in sorted(os.listdir(os.path.expanduser("~/frus-ner-raw/marked"))):
    if not fn.endswith(".jsonl.gz"): continue
    for ln in gzip.open(os.path.join(os.path.expanduser("~/frus-ner-raw/marked"), fn), "rt", encoding="utf-8"):
        r = json.loads(ln); rows += 1
        if r.get("c"): nonnull += 1; cvals[r["c"]] += 1
print("marked rows:", rows, "rows with non-null c:", nonnull, "distinct c:", len(cvals), cvals.most_common(5))
