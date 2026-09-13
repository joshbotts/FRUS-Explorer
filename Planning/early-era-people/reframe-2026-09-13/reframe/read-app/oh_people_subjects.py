# Read-only: do the bundled OH subject artifacts already carry PEOPLE at any grain, and for which volumes?
import json, os, collections, sqlite3
R = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/FRUSExplorer/Resources"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "oh_people_subjects.json")
res = {}
tax = json.load(open(os.path.join(R, "volume-tag-taxonomy.json")))
res["taxonomy_top_keys"] = list(tax.keys())[:20] if isinstance(tax, dict) else type(tax).__name__
dsi = json.load(open(os.path.join(R, "document-subject-index.json")))
res["dsi_top_keys"] = list(dsi.keys())[:20]
# find subject vocabulary and categories
def find_list(obj, depth=0):
    if depth > 3: return
    if isinstance(obj, dict):
        for k, v in obj.items():
            if isinstance(v, list) and v and isinstance(v[0], dict):
                yield k, v
            elif isinstance(v, dict):
                yield from find_list(v, depth+1)
for k, v in find_list(dsi):
    res.setdefault("dsi_lists", {})[k] = {"len": len(v), "first_keys": list(v[0].keys())}
for k, v in find_list(tax):
    res.setdefault("tax_lists", {})[k] = {"len": len(v), "first_keys": list(v[0].keys())}
json.dump(res, open(OUT, "w"), indent=1, default=str)
print(json.dumps(res, indent=1, default=str)[:4000])
