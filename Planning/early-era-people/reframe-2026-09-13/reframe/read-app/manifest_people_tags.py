# Read-only: do the 267 volumes with no persons rows in the live index (app view) carry OH
# volume-grain PEOPLE tags in manifest.json (volume-tag-taxonomy category "people")?
import json, os, sqlite3, collections
REPO = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
DB = "/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/frus.db"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "manifest_people_tags.json")
con = sqlite3.connect('file:' + DB + '?mode=ro', uri=True)
vols = set(r[0] for r in con.execute("SELECT DISTINCT volume_id FROM document_cache"))
tagged = set(r[0] for r in con.execute("SELECT DISTINCT volume_id FROM persons"))
untagged = sorted(vols - tagged)
tax = json.load(open(os.path.join(REPO, "FRUSExplorer/Resources/volume-tag-taxonomy.json")))
people_slugs = {t["slug"]: t for t in tax if t.get("category") == "people"}
man = json.load(open(os.path.join(REPO, "FRUSExplorer/Resources/manifest.json")))
entries = man.get("volumes", man) if isinstance(man, dict) else man
first = entries[0]
res = {"manifest_entry_keys": list(first.keys())}
tagkey = next((k for k in first if "tag" in k.lower()), None)
res["tag_key"] = tagkey
by_id = {e.get("id") or e.get("volumeId"): e for e in entries}
def people_tags(v):
    e = by_id.get(v) or {}
    tags = e.get(tagkey) or []
    out = []
    for t in tags:
        s = t if isinstance(t, str) else (t.get("slug") or t.get("id"))
        if s in people_slugs: out.append(s)
    return out
cnt_u = sum(1 for v in untagged if people_tags(v))
cnt_t = sum(1 for v in sorted(tagged & vols) if people_tags(v))
sub = collections.Counter()
per_vol = []
for v in untagged:
    pt = people_tags(v)
    per_vol.append(len(pt))
    for s in pt: sub[people_slugs[s].get("subcategory")] += 1
res.update({
    "population": "app-view: live index volumes (index v50)",
    "volumes_in_index": len(vols), "untagged_volumes": len(untagged), "tagged_volumes": len(tagged & vols),
    "people_taxonomy_tags": len(people_slugs),
    "people_subcategories": collections.Counter(t.get("subcategory") for t in people_slugs.values()).most_common(),
    "untagged_volumes_with_any_people_tag": cnt_u,
    "tagged_volumes_with_any_people_tag": cnt_t,
    "untagged_people_tag_assignments_by_subcategory": sub.most_common(),
    "untagged_people_tags_per_volume_max": max(per_vol) if per_vol else 0,
    "untagged_people_tags_total": sum(per_vol),
    "example": [(v, people_tags(v)) for v in untagged[:5]],
})
json.dump(res, open(OUT, "w"), indent=1, default=str)
print(json.dumps(res, indent=1, default=str))
