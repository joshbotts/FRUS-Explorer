import json, re, sqlite3
RES = "/Applications/FRUS Explorer.app/Contents/Resources"
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
con = sqlite3.connect(DB, uri=True)
ov = open("/Users/jbotts/frus-analysis/c3s/runs/s1/overview.md", encoding="utf-8").read()

# 1. every URL the overview cites -> pair, in reading order, distinct
urls = re.findall(r"https://history\.state\.gov/historicaldocuments/([A-Za-z0-9\-]+)/(d\d+)", ov)
pairs = []
for v, d in urls:
    if (v, d) not in pairs:
        pairs.append((v, d))
print("distinct cited pairs in overview:", len(pairs), "from", len({v for v, _ in pairs}), "volumes")

# 2. the printed citation that precedes each URL: "Foreign Relations of the United States, <title>, Document N (URL)"
cites = re.findall(r"Foreign Relations of the United States, ([^()]*?), Document (\d+)[,]? \(https://history\.state\.gov/historicaldocuments/([A-Za-z0-9\-]+)/(d\d+)\)", ov)
print("printed citations with a URL:", len(cites))
m = json.load(open(RES + "/manifest.json"))
# find the volumes array and a title field
def volumes(m):
    if isinstance(m, dict):
        for k in ("volumes", "items", "entries"):
            if k in m and isinstance(m[k], list):
                return m[k]
        for v in m.values():
            if isinstance(v, list) and v and isinstance(v[0], dict) and any("id" in x or "volumeId" in x for x in v[:3]):
                return v
    return m
vols = volumes(m)
print("manifest volumes:", len(vols), "sample keys:", sorted(vols[0].keys())[:20])
byid = {}
for x in vols:
    vid = x.get("id") or x.get("volumeId") or x.get("volume_id")
    byid[vid] = x
def title(vid):
    x = byid.get(vid)
    if not x:
        return None
    for k in ("title", "fullTitle", "citationTitle", "name"):
        if k in x:
            return x[k]
    return str({k: x[k] for k in list(x)[:6]})
seen = set()
bad = 0
for printed, docno, v, d in cites:
    if (printed, docno, v, d) in seen:
        continue
    seen.add((printed, docno, v, d))
    t = title(v)
    # printed title tokens must all appear in the manifest title (ignoring punctuation/dash variants)
    def toks(s):
        return [w for w in re.findall(r"[A-Za-z0-9]+", s.replace("–", "-")) if w.lower() not in ("the", "of", "and", "on", "documents", "part", "volume")]
    pt, mt = toks(printed), toks(t or "")
    missing = [w for w in pt if w not in mt]
    docok = (d == "d" + docno)
    row = con.execute("SELECT document_number, substr(header,1,60) FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
    flag = "OK" if (not missing and docok) else "CHECK"
    if flag != "OK":
        bad += 1
    print(flag, f"{v}/{d}", "| printed:", printed, "Doc", docno, "| manifest:", t, "| doc_number:", row[0] if row else None, "| missing tokens:", missing, "| doc id matches printed number:", docok)
print("printed citations needing a look:", bad, "of", len(seen))

# 3. are the ids that resolve to a first edition when an Ed2 exists?
print("\nEd2 ids in manifest:", [k for k in byid if k and k.endswith("Ed2")])
for k in ("frus1969-76ve15p2", "frus1969-76ve15p2Ed2", "frus1951-54Iran", "frus1951-54IranEd2"):
    print(k, "->", title(k))

# 4. collection membership of the cited pairs
c = json.load(open("/Users/jbotts/frus-analysis/c3s/runs/s1/collection.fruscollection", encoding="utf-8"))
coll = {(e["volumeId"], e["documentId"]) for e in c["entries"] if e["kind"] == "document"}
inc = [p for p in pairs if p in coll]
print("\ncited pairs in collection:", len(inc), "of", len(pairs), "| not in collection:", [p for p in pairs if p not in coll], "| in collection but not cited:", sorted(coll - set(pairs)))
import collections
kinds = collections.Counter(e["kind"] for e in c["entries"])
print("entries by kind:", dict(kinds), "total", len(c["entries"]))
print("documents with notes:", sum(1 for e in c["entries"] if e["kind"] == "document" and e.get("notes")))
print("documents with excerpts:", len({(e["volumeId"], e["documentId"]) for e in c["entries"] if e["kind"] == "excerpt"}))
json.dump(pairs, open("/Users/jbotts/frus-analysis/c3s/runs/s1/refuter/cited_pairs.json", "w"))
