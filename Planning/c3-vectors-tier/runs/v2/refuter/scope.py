# Independent reproduction of the memo's scope: rule A (sections titled /cuba|havana/i, minus the frus1896 steamship section)
# + rule B (frus1861..frus1894*, >=3 matches of \b(Cuba|Cuban|Cubans|Havana)\b re.I in body_text); fm/en excluded; Ed2 dropped.
import sqlite3, json, re, collections
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
pat = re.compile(r"cuba|havana", re.I)
A = {}
def alldocs(s):
    out = list(s.get("documentIds", []))
    for x in s.get("subsections", []): out += alldocs(x)
    return out
def walk(v, s, path):
    t = (s.get("title") or "").strip(); p = path + [t]
    if pat.search(t):
        if v == "frus1896" and "steamship Cuban" in " > ".join(p): return
        for d in alldocs(s): A.setdefault((v, d), " > ".join(p))
        return
    for x in s.get("subsections", []): walk(v, x, p)
nsec = 0
for v, js in db.execute("SELECT volume_id, structure_json FROM volume_structures ORDER BY volume_id"):
    j = json.loads(js)
    for s in j.get("sections", []): walk(v, s, [])
print("rule A listed pairs (distinct)", len(A))
B = set()
cuba_re = re.compile(r"\b(Cuba|Cuban|Cubans|Havana)\b", re.I)
for (v,) in db.execute("SELECT DISTINCT volume_id FROM document_cache WHERE volume_id GLOB 'frus18[6-9]*' AND volume_id < 'frus1895' ORDER BY 1"):
    for d, body in db.execute("SELECT document_id, body_text FROM document_cache WHERE volume_id=? AND is_front_matter=0 AND is_editorial_note=0", (v,)):
        if len(cuba_re.findall(body or "")) >= 3: B.add((v, d))
print("rule B pairs", len(B), "of which also in A", len(B & set(A)))
ED2 = {"frus1951-54IranEd2", "frus1969-76ve15p2Ed2"}
core = {}
for k in set(A) | B:
    v, d = k
    if v in ED2: continue
    r = db.execute("SELECT is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?", k).fetchone()
    if not r or r[0] or r[1]: continue
    core[k] = "A" if k in A else "B"
dates = {}
for k in core:
    r = db.execute("SELECT date_iso FROM document_dates WHERE volume_id=? AND document_id=?", k).fetchone(); dates[k] = r[0] if r else None
print("CORE", len(core), "A", sum(x == "A" for x in core.values()), "B", sum(x == "B" for x in core.values()), "volumes", len({v for v, _ in core}))
dd = [x for x in dates.values() if x]; print("dated", len(dd), "undated", len(core) - len(dd), "span", min(dd), max(dd))
band = collections.Counter()
for k, dt in dates.items():
    y = int(dt[:4]); band["1840-1860" if y < 1861 else "1861-1898" if y <= 1898 else "1899-1933" if y <= 1933 else "1934-1958" if y <= 1958 else "1959-1980" if y <= 1980 else "post-1980"] += 1
print("bands", dict(sorted(band.items())))
sess = {(x["v"], x["d"]) for x in json.load(open("/Users/jbotts/frus-analysis/c3v/runs/v2/coreset.json"))}
print("session coreset.json", len(sess), "my core", len(core), "symmetric difference", len(sess ^ set(core)), sorted(sess ^ set(core))[:10])
cited = [("frus1870","d197"),("frus1881","d405"),("frus1898","d490"),("frus1898","ch83"),("frus1902","d313"),("frus1903","d331"),("frus1906p1","d427"),("frus1933v05","d281"),("frus1941v07","d119"),("frus1952-54v04","d343"),("frus1961-63v10","d202"),("frus1961-63v11","d34"),("frus1969-76ve10","d205"),("frus1969-76v12","d211"),("frus1977-80v23","d21"),("frus1977-80v23","d98")]
print("cited pairs in core set:")
for k in cited: print("  ", "/".join(k), core.get(k, "NOT IN CORE"), (A.get(k) or "")[:120])
json.dump(sorted(["/".join(k) for k in core]), open("my_core_pairs.json", "w"))
