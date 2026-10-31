import json, sqlite3
RES = "/Applications/FRUS Explorer.app/Contents/Resources"
DB = "/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
print("== Marshall Mission candidates: dates / entry numbers in curated-lot-resolutions.json (overview: 'no dates or access status in the bundled data')")
cur = json.load(open(RES + "/curated-lot-resolutions.json"))
for l in cur["lots"]:
    if l.get("lotNumber") == "54D270":
        for c in l["candidates"]: print("  ", c.get("naId"), c.get("title")[:60], "| entry", c.get("entryNumber"), "| dateRange", c.get("dateRange"), "| other keys", sorted(set(c) - {"naId","title","catalogURL","entryNumber","dateRange"}))
print("\n== Kissinger transcripts (Entry 5177) and records (Entry 5403): any NAID in the bundle?")
cf = json.load(open(RES + "/central-files-index.json"))
for l in cf["lotFiles"]:
    s = json.dumps(l)
    if "5177" in s or "5403" in s or "Kissinger" in s: print("   central-files lotFiles:", s[:300])
ca = json.load(open(RES + "/collection-authority.json"))["collections"]
for r in ca:
    s = json.dumps(r)
    if ("5177" in s or "5403" in s) and ("issinger" in s):
        print("   collection-authority:", r.get("id"), "| naId", r.get("naId"), "| catalogURL", r.get("catalogURL"), "| name", (r.get("name") or "")[:90])
sf = json.load(open(RES + "/series-facts-index.json"))
leg = sf["legend"]["keys"]
hits = []
for naid, r in sf["byNaId"].items():
    # creator/heading text search for Kissinger
    c = r.get("c"); h = sf["headings"][c] if c is not None else ""
    if "issinger" in h: hits.append((naid, h))
print("   series-facts creators naming Kissinger:", hits[:5])
ac = json.load(open(RES + "/accession-series-index.json"))
s = json.dumps(ac["byAccession"])
for needle in ("Kissinger", "Staff Meetings"):
    i = s.find(needle); print(f"   accession-series {needle!r}: " + (("…" + s[max(0,i-250):i+150] + "…") if i >= 0 else "absent"))
print("\n== was d204 in any printed result set before vec.py? (grep of the .out files written before it)")
import glob, os, re
RUN = "/Users/jbotts/frus-analysis/c3s/runs/s2"
for f in ["p1.out", "p2.out", "p3.out", "scope1.out", "share1.out", "census.out", "lockheed.out", "heads.out", "header_hits.out", "arch1.out", "read.out"]:
    t = open(f"{RUN}/{f}", encoding="utf-8", errors="replace").read()
    print(f"   {f}: 'frus1961-63v22 d204' or 'frus1961-63v22/d204' present =", ("frus1961-63v22 d204" in t) or ("frus1961-63v22/d204" in t))
print("   p2.out korea block:")
t = open(f"{RUN}/p2.out", encoding="utf-8").read()
i = t.find("=== korea"); print("   " + t[i:i+1400].replace("\n", "\n   "))
print("\n== date span of the index and of the cited set")
print("  index:", con.execute("SELECT MIN(date_iso), MAX(date_iso) FROM document_dates WHERE date_iso IS NOT NULL").fetchone())
cited = [tuple(l.strip().split("/")) for l in open(f"{RUN}/cited.txt") if l.strip()]
ds = sorted(con.execute("SELECT date_iso FROM document_dates WHERE volume_id=? AND document_id=?", p).fetchone()[0] for p in cited)
print("  cited:", ds[0], ds[-1], "; volumes:", sorted({v for v, d in cited}), len({v for v, d in cited}))
print("  non-apparatus docs in the 14 cited volumes:", con.execute("SELECT COUNT(*) FROM document_cache WHERE is_front_matter=0 AND is_editorial_note=0 AND volume_id IN (%s)" % ",".join("?"*14), sorted({v for v, d in cited})).fetchone())
