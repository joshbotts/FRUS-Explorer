# Aggregate out/tei/*.json (TEI pass) over the scope set. Counting surface: TEI tag-stripped, whitespace-collapsed;
# DOC = document text without <note>/<head>; APP = <note> + <head> inside the document div. Case-insensitive regex.
# Unit: documents with >=1 match (presence), and total match counts, by tier and period.
import csv, json, glob
from collections import defaultdict, Counter
csv.field_size_limit(10**9)
scope = {(r["volume_id"], r["document_id"]): r for r in csv.DictReader(open("out/scope.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE)}
tei = {}
for f in glob.glob("out/tei/*.json"):
    j = json.load(open(f))
    for d, rec in j["docs"].items(): tei[(j["volume_id"], d)] = rec
def period(dt):
    y = int(dt[:4])
    if y <= 1912: return "1861-1912"
    if y <= 1929: return "1913-1929"
    if y <= 1942: return "1930-1942"
    if y <= 1950: return "1943-1950"
    return "1951-1981"
P = ["1861-1912", "1913-1929", "1930-1942", "1943-1950", "1951-1981"]
fams = list(next(iter(tei.values()))["fam_doc"].keys())
res = {}
for tier_name, test in (("C", lambda t: t in ("C", "T+C")), ("T", lambda t: t in ("T", "T+C")), ("U", lambda t: True)):
    den = Counter(); pres_doc = defaultdict(Counter); pres_app = defaultdict(Counter); cnt_doc = defaultdict(Counter); cnt_app = defaultdict(Counter)
    chars_doc = Counter(); chars_app = Counter()
    for k, r in scope.items():
        if not test(r["tier"]): continue
        p = period(r["date_iso"]); den[p] += 1; rec = tei[k]
        chars_doc[p] += rec["doc_chars"]; chars_app[p] += rec["app_chars"]
        for fm in fams:
            if rec["fam_doc"][fm]: pres_doc[fm][p] += 1
            if rec["fam_app"][fm]: pres_app[fm][p] += 1
            cnt_doc[fm][p] += rec["fam_doc"][fm]; cnt_app[fm][p] += rec["fam_app"][fm]
    res[tier_name] = {"den": den, "pres_doc": pres_doc, "pres_app": pres_app, "cnt_doc": cnt_doc, "cnt_app": cnt_app, "chars_doc": chars_doc, "chars_app": chars_app}
json.dump(res, open("out/tei_census.json", "w"), indent=1)
for tier_name in ("C", "T", "U"):
    R = res[tier_name]
    print(f"\n=== tier {tier_name}: documents per period:", {p: R['den'][p] for p in P})
    print("   chars DOC:", {p: R['chars_doc'][p] for p in P}, " chars APP:", {p: R['chars_app'][p] for p in P})
    print("family".ljust(20), " | ".join(p.center(17) for p in P), "   [cell = docs with match in DOC text / in APP text]")
    for fm in fams:
        print(fm.ljust(20), " | ".join(f"{R['pres_doc'][fm][p]:>4} / {R['pres_app'][fm][p]:<4} of {R['den'][p]:<4}".center(17) for p in P))
# variant splits over the whole scope set
vd = Counter(); va = Counter()
for k in scope:
    for x, n in tei[k]["var_doc"].items(): vd[x] += n
    for x, n in tei[k]["var_app"].items(): va[x] += n
print("\n=== variant split, whole scope set (2,333 docs), occurrences in DOC text / APP text:")
for x in tei[next(iter(scope))]["var_doc"]: print(f"   {x}: {vd[x]} / {va[x]}")
json.dump({"doc": vd, "app": va}, open("out/tei_variants.json", "w"), indent=1)
