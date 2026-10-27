# Vector operations over the shipped artifacts (digest 89481b18...): (A) nearest neighbours of four anchors with a
# semantic join to document_dates / document_cache; (B) centroid cosine among Cuba-heavy volumes; (C) the map: cluster
# distribution of the Cuba core set (coreset.json) by era band, unclustered share vs an era-matched baseline.
import json, heapq, math, sqlite3, collections
from veclib import *
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
def date_of(v, d):
    r = db.execute("SELECT date_iso FROM document_dates WHERE volume_id=? AND document_id=?", (v, d)).fetchone(); return r[0] if r else None
def in_index(v, d):
    return db.execute("SELECT is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?", (v, d)).fetchone()
out = {"A": {}, "B": {}, "C": {}}
ANCH = [("frus1881", "d405"), ("frus1898", "d490"), ("frus1952-54v04", "d343"), ("frus1961-63v10", "d202")]
for v, d in ANCH:
    a = row_of[(v, d)]; best = []
    for r in range(DOCS):
        if r == a: continue
        h = bin(SIGNS[a] ^ SIGNS[r]).count("1")
        if len(best) < 25: heapq.heappush(best, (-h, r))
        elif -best[0][0] > h: heapq.heapreplace(best, (-h, r))
    best = sorted((-x, r) for x, r in best)
    k25 = best[-1][0]; ad = date_of(v, d)
    rows = []
    for h, r in best[:15]:
        nv, nd = doc_of[r]; dt = date_of(nv, nd); ii = in_index(nv, nd)
        rows.append((h, f"{nv}/{nd}", dt, None if ii is None else list(ii)))
    out["A"][f"{v}/{d}"] = {"date": ad, "k25": k25, "top15": rows}
    print(f"\n== anchor {v}/{d} ({ad}); 25th-neighbour distance {k25}", flush=True)
    for x in rows: print("  ", x)
VOLS = ["frus1874", "frus1898", "frus1902", "frus1917", "frus1933v05", "frus1944v07", "frus1958-60v06", "frus1961-63v11", "frus1977-80v23"]
C = {}
for vv in VOLS:
    c = centroid(vol_rows[vv][2]); n = math.sqrt(sum(x * x for x in c)); C[vv] = [x / n for x in c]
print("\n== centroid cosine (volume centroids, int8 dequantized, renormalized)")
print("\t" + "\t".join(v[4:] for v in VOLS))
for a in VOLS:
    row = [sum(x * y for x, y in zip(C[a], C[b])) for b in VOLS]; out["B"][a] = row
    print(a[4:] + "\t" + "\t".join("%.3f" % x for x in row))
MI = json.load(open(R + "semantic-map-index.json")); lab = {c["id"]: ", ".join(c["terms"]) for c in MI["clusters"]}
core = json.load(open("coreset.json"))
BANDS = [(1861, 1898), (1899, 1933), (1934, 1958), (1959, 1980)]
print("\n== map: Cuba core set by era band (date_iso year); top clusters; unclustered vs era-matched baseline (all dated non-apparatus docs in band, Ed2 dropped)")
for lo, hi in BANDS:
    S = [x for x in core if x["date"] and lo <= int(x["date"][:4]) <= hi and (x["v"], x["d"]) in row_of]
    cl = collections.Counter(placement(row_of[(x["v"], x["d"])])[2] for x in S)
    un = cl.pop(65535, 0)
    keys = db.execute("SELECT c.volume_id, c.document_id FROM document_cache c JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') AND CAST(substr(d.date_iso,1,4) AS INT) BETWEEN ? AND ?", (lo, hi)).fetchall()
    bk = [k for k in keys if k in row_of]; bun = sum(placement(row_of[k])[2] == 65535 for k in bk)
    top = [(c, n, lab.get(c)) for c, n in cl.most_common(5)]
    out["C"][f"{lo}-{hi}"] = {"N": len(S), "unclustered": un, "baseN": len(bk), "baseUn": bun, "top": top}
    print(f"{lo}-{hi}: core {len(S)}, unclustered {un} of {len(S)}; baseline unclustered {bun} of {len(bk)}")
    for t in top: print("    cluster", t)
json.dump(out, open("vec_ops.json", "w"), indent=1)
