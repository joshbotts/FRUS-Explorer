# Read-only: category census of the two bundled OH subject artifacts, to see whether either names PEOPLE.
import json, os, collections
R = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/FRUSExplorer/Resources"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "oh_people_subjects2.json")
res = {}
tax = json.load(open(os.path.join(R, "volume-tag-taxonomy.json")))
res["taxonomy_len"] = len(tax)
res["taxonomy_first_item_keys"] = list(tax[0].keys()) if tax and isinstance(tax[0], dict) else str(type(tax[0]))
cat = collections.Counter()
peo = []
def walk(o, path=""):
    if isinstance(o, dict):
        c = o.get("category") or o.get("type")
        if c:
            cat[str(c)] += 1
            if "people" in str(c).lower() or "person" in str(c).lower():
                peo.append({k: o[k] for k in o if k in ("name", "id", "label", "volumes", "subcategory")} )
        for v in o.values(): walk(v)
    elif isinstance(o, list):
        for v in o: walk(v)
walk(tax)
res["taxonomy_categories"] = cat.most_common()
res["taxonomy_people_tags_count"] = len(peo)
res["taxonomy_people_tags_sample"] = [{k: (v if not isinstance(v, list) else f"list[{len(v)}]") for k, v in p.items()} for p in peo[:12]]
dsi = json.load(open(os.path.join(R, "document-subject-index.json")))
vc = collections.Counter(s.get("c") for s in dsi["vocab"])
res["dsi_vocab_categories"] = vc.most_common()
res["dsi_person_like"] = [s.get("n") for s in dsi["vocab"] if "people" in str(s.get("c")).lower() or "person" in str(s.get("c")).lower()][:30]
json.dump(res, open(OUT, "w"), indent=1, default=str)
print(json.dumps(res, indent=1, default=str)[:5000])
