# Find series identities for the Department's central files in the bundled JSON: collection-authority.json
# (collections whose name/aliases mention central files), volume-sources-index.json (recordGroups['59'] and
# majorCollections mentioning central files), and series-facts-index.json rows for candidate NAIDs.
import json, re
RES = "/Applications/FRUS Explorer.app/Contents/Resources/"
pat = re.compile(r"central (decimal|foreign policy|files)|subject[- ]numeric|decimal file", re.I)
ca = json.load(open(RES + "collection-authority.json"))
hits = [c for c in ca["collections"] if pat.search(c.get("name", "")) or any(pat.search(a) for a in c.get("aliases", []))]
print("collection-authority hits:", len(hits))
for c in hits[:25]:
    print("  ", c["id"], "|", c.get("name")[:120], "|", c.get("repository"), "| vols", len(c.get("volumeIds", [])), "| keys", sorted(c.keys()))
vs = json.load(open(RES + "volume-sources-index.json"))
print("RG 59:", vs["recordGroups"].get("59"))
mc = [m for m in vs["majorCollections"] if pat.search(m.get("text", ""))]
print("majorCollections hits:", len(mc))
for m in sorted(mc, key=lambda m: -m["occurrences"])[:15]:
    print("  ", m["key"][:80], "| occ", m["occurrences"], "| rep", m.get("repository"), "| keys", sorted(m.keys()))
sf = json.load(open(RES + "series-facts-index.json"))
for naid in ["302021", "654099", "1238", "302022", "2156", "604801", "631"]:
    print("series-facts", naid, sf["byNaId"].get(naid))
