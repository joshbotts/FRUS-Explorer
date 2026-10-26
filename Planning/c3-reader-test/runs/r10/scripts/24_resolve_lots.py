# Resolve the lot numbers of the scope S2 on both channels (came-from = out/18_ds_S2.tsv lot_file_norm;
# pointed-at = out/21_ec_S2.tsv lot_file_norm) through central-files-index.json (lotFiles: list keyed on lotNumber),
# lot-claimants-index.json (lots: list), curated-lot-resolutions.json (lots: list), collection-authority.json
# (collections by lotFileNorm), and series-facts-index.json (byNaId, one-letter keys per its legend).
import json, collections
RES = "/Applications/FRUS Explorer.app/Contents/Resources/"
R = "/Users/jbotts/frus-analysis/c3/runs/r10/"
cf = json.load(open(RES + "central-files-index.json"))
lots = {}
for row in cf["lotFiles"]:
    lots.setdefault(row["lotNumber"].replace(" ", ""), []).append(row)
lc = {r["lotNumber"].replace(" ", "") if "lotNumber" in r else r.get("lot", ""): r for r in json.load(open(RES + "lot-claimants-index.json"))["lots"]}
cr = json.load(open(RES + "curated-lot-resolutions.json"))
crl = {}
for r in cr["lots"]:
    k = (r.get("lotNumber") or r.get("lot") or r.get("lotFileNorm") or "").replace(" ", "")
    crl[k] = r
ca = {c.get("lotFileNorm"): c for c in json.load(open(RES + "collection-authority.json"))["collections"] if c.get("lotFileNorm")}
sf = json.load(open(RES + "series-facts-index.json"))
def facts(naid):
    r = sf["byNaId"].get(str(naid))
    if not r: return None
    out = {}
    for k, v in r.items():
        spec = sf["legend"]["keys"].get(k, {})
        if spec.get("kind") == "index": out[spec["field"]] = sf[spec["into"]][v]
        elif spec.get("kind") == "indexList": out[spec["field"]] = [sf[spec["into"]][i] for i in v]
        else: out[spec.get("field", k)] = v
    return out
came = collections.defaultdict(list); pointed = collections.defaultdict(list)
# The came-from row of frus1948v09/d115 reads "Lot No. 64-D-563"; its stored norm is "NO", so the lot is also probed
# by hand under 64D563 (the number printed in its source note).
came["64D563"].append("frus1948v09/d115 (source note: Lot No. 64-D-563)")
for line in open(R + "out/18_ds_S2.tsv"):
    f = line.rstrip("\n").split("\t")
    if f[6]: came[f[6]].append("%s/%s" % (f[0], f[1]))
for line in open(R + "out/21_ec_S2.tsv"):
    f = line.rstrip("\n").split("\t")
    if f[9]: pointed[f[9]].append("%s/%s" % (f[0], f[1]))
print("keys of a lot-claimants row:", sorted(next(iter(lc.values())).keys()) if lc else None)
print("keys of a curated-lot row:", sorted(cr["lots"][0].keys()) if cr["lots"] else None)
for chan, d in (("CAME-FROM", came), ("POINTED-AT", pointed)):
    print("=====", chan, "lots:", len(d))
    for lot in sorted(d):
        docs = sorted(set(d[lot]))
        print("--", lot, "docs:", len(docs), " ".join(docs[:6]))
        for row in lots.get(lot, []):
            print("   central-files-index: RG %s | NAID %s | entry %s | %s | match %s" % (row.get("recordGroup"), row.get("naId"), ",".join(row.get("hmsMlrEntryNumbers") or []), row.get("title"), row.get("matchType")))
            fx = facts(row.get("naId"))
            if fx: print("     series-facts:", json.dumps(fx, ensure_ascii=False))
        if lot in lc:
            print("   lot-claimants:", json.dumps(lc[lot], ensure_ascii=False)[:600])
        if lot in crl:
            print("   curated-lot-resolution:", json.dumps(crl[lot], ensure_ascii=False)[:600])
        if lot in ca:
            print("   collection-authority:", ca[lot].get("name"), "|", ca[lot].get("repository"), "| naId", ca[lot].get("naId"))
        if lot not in lots and lot not in lc and lot not in crl:
            print("   (no central-files-index, claimant or curated row)")
