#!/usr/bin/env python3
# Refuter: every archival identifier in the overview's bottom-line paragraph 2, against the bundled artifacts and the index. Read-only.
import json, re, sqlite3
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
DB = "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
con = sqlite3.connect(DB, uri=True)
cf = json.load(open(R + "central-files-index.json"))
sf = json.load(open(R + "series-facts-index.json"))
ca = json.load(open(R + "collection-authority.json"))
ec = json.load(open(R + "external-citation-index.json"))
vs = json.load(open(R + "volume-sources-index.json"))
pl = json.load(open(R + "presidential-library-catalog.json"))
lots = {}
for r in cf["lotFiles"]:
    lots.setdefault(r["lotNumber"].replace(" ", ""), []).append(r)
def facts(nid):
    r = sf["byNaId"].get(str(nid))
    if not r: return None
    return dict(status=sf["statuses"][r["as"]] if "as" in r else None, restrictions=[sf["restrictions"][i] for i in r.get("ar", [])],
                years=(r.get("y0"), r.get("y1")), creator=sf["headings"][r["c"]] if "c" in r else None, extent=r.get("x"))
print("== State lots named in the overview (central-files-index lotFiles + series-facts)")
for ln in ["91D414", "78D443", "79F80", "65D330", "85D240", "66D193"]:
    rows = lots.get(ln, [])
    if not rows:
        print(" ", ln, "-> NOT in central-files-index lotFiles")
    for r in rows:
        print(" ", ln, "| NAID", r["naId"], "| entry", r["hmsMlrEntryNumbers"], "| RG", r["recordGroup"], "| match", r["matchType"], "| title", r["title"])
        print("      series facts:", facts(r["naId"]))
print()
print("== collection-authority entries for lot 79F80 and the three pointed-at lots")
for c in ca["collections"]:
    if c["id"] in ("lot:79F80", "lot:65D330", "lot:85D240", "lot:66D193"):
        print(" ", c["id"], "| name", c["name"], "| RG", c.get("recordGroup"), "| repo", c.get("repository"), "| naIds", c.get("naIds") or c.get("naId"), "| aliases", [a for a in c.get("aliases", []) if "Agent" in a or "Fees" in a][:3])
print()
print("== pointed-at index: cited volumes present, and the kinds of reference it holds")
cited_vols = sorted({k.split("/")[0] for k in open("/Users/jbotts/frus-analysis/c3s/runs/s6/scope_keys.txt").read().split()})
print("  cited volumes:", len(cited_vols), "| in ec.volumes:", sum(1 for v in cited_vols if v in ec["volumes"]))
print("  ec.coverage keys with 'References':", {k: v for k, v in ec["coverage"].items() if "Reference" in k})
print("  ec top-level keys:", list(ec.keys()))
# earliest volume in the pointed-at index
import json as _j
print("  ec volumes count:", len(ec["volumes"]), "| any pre-1910 volume:", [v for v in ec["volumes"] if re.match(r"frus1[89]\d\d", v) and int(re.match(r"frus(\d{4})", v).group(1)) < 1910][:5])
# re-count the pointed-at targets over the 20 cited volumes
names = {c["id"]: c for c in ca["collections"]}
import collections
tt = collections.Counter()
for r in ec["targets"]:
    s = sum(n for n, v in zip(r["n"], r["v"]) if ec["volumes"][v] in set(cited_vols))
    if s: tt[ec["targetIds"][r["k"]]] += s
print("  pointed-at top 8 over the cited volumes:")
for cid, n in tt.most_common(8):
    print("    ", n, cid, "|", (names.get(cid, {}).get("name") or "")[:70])
for lot in ("lot:65D330", "lot:85D240", "lot:66D193"):
    print("    ", lot, "->", tt.get(lot))
print()
print("== came-from: document_sources rows of the cited documents")
rows = con.execute("SELECT volume_id||'/'||document_id, repository, record_group, lot_file, series_name, citation_era, decimal_class, substr(raw_text,1,120) FROM document_sources WHERE (volume_id,document_id) IN (VALUES %s) ORDER BY citation_era, 1" % ",".join("('%s','%s')" % tuple(k.split("/")) for k in open("/Users/jbotts/frus-analysis/c3s/runs/s6/scope_keys.txt").read().split())).fetchall()
for r in rows: print("  ", " | ".join(str(x) for x in r))
print("  rows:", len(rows))
print("  decimal classes cited:", sorted({r[6] for r in rows if r[5] == "decimal"}))
print()
print("== decimal central file: does any bundled artifact give a NARA series id / access status for the RG 59 decimal file?")
print("  central-files-index keys:", list(cf.keys()), "(no decimalFile section)" if "decimalFile" not in cf else "has decimalFile")
hits = [r for r in cf["lotFiles"] if re.search(r"Central Decimal|Decimal File", r["title"], re.I)]
print("  lotFiles rows whose title names a decimal file:", [(r["lotNumber"], r["title"][:60], r["naId"]) for r in hits][:8])
print("  volume-sources-index recordGroups 59/84:", {k: v for k, v in vs["recordGroups"].items() if k in ("59", "84")})
auth_dec = [c for c in ca["collections"] if re.search(r"central decimal|central files?$", c.get("name", ""), re.I) and c.get("repository") == "Department of State"][:5]
print("  authority entries named like the central files:", [(c["id"], c["name"][:50], c.get("naIds") or c.get("naId")) for c in auth_dec])
print()
print("== presidential libraries named: the cited documents' source lines")
for r in rows:
    if r[1] and "Library" in r[1]: print("  ", r[0], "|", r[1], "|", r[4], "|", r[7][:100])
print("  library catalog libraries:", [l["citedAs"] for l in pl["libraries"]])
