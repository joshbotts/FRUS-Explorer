# Rank archival targets for a volume scope with collection-usage-index.json (CAME-FROM channel: one count per source note) and
# the pointed-at channel with external-citation-index.json (targets). Scope = the 48 hemisphere volumes in work/hemisphere_volumes.txt (volume-level, all their documents).
import json, sys, collections
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
RUN = "/Users/jbotts/frus-analysis/c3/runs/r1"
hemi = [l.strip() for l in open(RUN + "/work/hemisphere_volumes.txt") if l.strip()]
u = json.load(open(R + "collection-usage-index.json"))
auth = json.load(open(R + "collection-authority.json"))["collections"]
names = {c["id"]: c for c in auth}
vidx = {v: i for i, v in enumerate(u["volumes"])}
want = set(vidx[v] for v in hemi if v in vidx)
print("hemisphere volumes in scope:", len(want), "of", len(hemi), "| notes in these volumes (volumeNoteCounts):", sum(u["volumeNoteCounts"][i] for i in want))
tot = collections.Counter()
for k, c in enumerate(u["collections"]):
    cid = u["collectionIds"][c["k"]]
    for n, v in zip(c["n"], c["v"]):
        if v in want: tot[cid] += n
print("notes carried by a named collection in these volumes:", sum(tot.values()))
print("-- top collections (came-from channel, source notes)")
for cid, n in tot.most_common(22):
    c = names.get(cid, {})
    print("  %5d  %-62s | %s | RG %s | %s" % (n, cid[:62], c.get("name", "(not in authority)")[:48], c.get("recordGroup", ""), c.get("repository", "")))
cat = collections.Counter()
for c in u["volumeCategories"]:
    for n, v in zip(c["n"], c["v"]):
        if v in want: cat[u["categories"][c["k"]]] += n
print("-- by category (notes):", dict(cat.most_common()))
cls = collections.Counter()
for k, c in enumerate(u["classes"]):
    for n, v in zip(c["n"], c["v"]):
        if v in want: cls[u["classKeys"][c["k"]].split(".")[0][:3]] += n
print("-- decimal class keys by first three digits (top 14):", cls.most_common(14))
