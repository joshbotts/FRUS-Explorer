import json, os, re
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
js = {f: os.path.getsize(R+f) for f in os.listdir(R) if f.endswith(".json")}
tot = sum(js.values()); print("all bundled JSON:", len(js), "files,", f"{tot/1e6:.2f} MB (decimal) / {tot/2**20:.2f} MiB   memo: 24.79 MB")
arch = ["accession-series-index.json","central-files-index.json","collection-authority.json","collection-usage-index.json","curated-library-resolutions.json","curated-lot-resolutions.json","decimal-class-labels.json","digitized-ranges-index.json","external-citation-index.json","lot-claimants-index.json","presidential-library-catalog.json","provenance-flow-index.json","roll-scans-index.json","series-facts-index.json","source-provenance-index.json","volume-sources-index.json","subject-numeric-labels.json"]
s = sum(js[f] for f in arch if f in js); print("17 archival-resolution candidates:", f"{s/1e6:.2f} MB; memo: 15 artifacts, 11.83 MB")
# try 15-subsets by dropping two: show the sizes so a reader can see
for f in arch: print(f"   {js.get(f,0)/1e6:6.2f} MB  {f}")
sm = json.load(open(R+"semantic-shards-manifest.json")); 
print("semantic-shards-manifest keys:", list(sm.keys())[:10])
for k, v in sm.items():
    if isinstance(v, (list, dict)): print("  ", k, len(v))
sv = json.load(open(R+"semantic-vectors-index.json"))
print("semantic-vectors-index keys:", list(sv.keys())[:14])
for k, v in sv.items():
    if isinstance(v, (list, dict)): print("  ", k, len(v))
    elif k in ("digest","provenanceDigest","generated","volumeCount","documentCount"): print("  ", k, v)
shards = "/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/"
for root, dirs, files in os.walk(shards):
    n = sum(1 for f in files if f.endswith((".bin",".shard",".vec")))
    if n > 100: print("shard-like files under", root, ":", n)
print("volumes on disk:", sum(1 for f in os.listdir(shards+"volumes") if f.endswith(".xml")))
print("db copy size:", os.path.getsize("/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db")/1e9, "GB; memo: frus.db 3.2 GB")
