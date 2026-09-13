import json, collections, re
E = json.load(open("/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad/measure-errors/errors.json"))
A = E["arms"]; S = E["summary"]
def C(items, key="category"): return collections.Counter(x[key] for x in items)
def CB(items, key="category"):
    d=collections.defaultdict(collections.Counter)
    for x in items: d[x["band"]][x[key]]+=1
    return {b:dict(c) for b,c in sorted(d.items())}
fc=A["filtered_control"]; fs=A["filtered_sweep"]; rs=A["raw_sweep"]
print("ARMS", list(A), "relaxed", {a:A[a]["relaxed"] for a in A})
print("FC FP", len(fc["false_positives"]), dict(C(fc["false_positives"])))
print("FC FP by band", CB(fc["false_positives"]))
print("FC MS", len(fc["misses"]), dict(C(fc["misses"])))
print("FC MS by band", CB(fc["misses"]))
print("FC MS flags", collections.Counter(f for x in fc["misses"] for f in x["flags"]))
print("FS FP", len(fs["false_positives"]), dict(C(fs["false_positives"])))
print("FS FP by band", CB(fs["false_positives"]))
print("FS MS", len(fs["misses"]), dict(C(fs["misses"])))
print("FS MS by band", CB(fs["misses"]))
VOC={"place","institution","title-only","pronoun-common","other:document-furniture","other:date","other:calendar-month"}
CTX={"partial-name-boundary","ship-treaty-conference","other:citation-caption-name"}
for n,a in (("FC",fc),("FS",fs)):
    f=a["false_positives"]
    print(n,"vocab",sum(x["category"] in VOC for x in f),"ctx",sum(x["category"] in CTX for x in f),"other",[x["n"] for x in f if x["category"] not in VOC|CTX])
    print(n,"danger",collections.Counter(x["danger_tier"] for x in f), "A excl nested", [x["n"] for x in f if x["danger_tier"]=="A" and x["category"]!="partial-name-boundary"], "B",[x["n"] for x in f if x["danger_tier"]=="B"])
    print(n,"nested",[x["n"] for x in f if x["category"]=="partial-name-boundary"], "overlaps_gold on nested", [x["overlaps_gold"] for x in f if x["category"]=="partial-name-boundary"], "overlaps_gold on non-nested", sum(x["overlaps_gold"] for x in f if x["category"]!="partial-name-boundary"))
    print(n,"FP with editor overlap", sum(bool(x["editor_overlap"]) for x in f), [x["n"] for x in f if x["editor_overlap"]])
    m=a["misses"]
    print(n,"miss editor covers",sum(x["editor_covers"] for x in m),"by cat",{c:(sum(x["editor_covers"] for x in m if x["category"]==c),sum(1 for x in m if x["category"]==c)) for c in C(m)})
    print(n,"miss editor covers by band",{b:(sum(x["editor_covers"] for x in m if x["band"]==b),sum(1 for x in m if x["band"]==b)) for b in sorted(set(x["band"] for x in m))})
    print(n,"miss found by other arm",{o:sum(o in x["found_by_other_arms"] for x in m) for o in ("filtered_control","filtered_sweep","raw_sweep","raw_control")})
# danger A control excl nested: doc concentration
dA=[x for x in fc["false_positives"] if x["danger_tier"]=="A" and x["category"]!="partial-name-boundary"]
print("FC danger A docs", collections.Counter((x["v"],x["d"]) for x in dA))
# neither editor nor either filtered arm
print("FC misses found by neither editor nor filtered_sweep:", [(x["v"],x["d"],x["n"]) for x in fc["misses"] if not x["editor_covers"] and "filtered_sweep" not in x["found_by_other_arms"]])
print("FS misses found by neither editor nor filtered_control:", [(x["v"],x["d"],x["n"]) for x in fs["misses"] if not x["editor_covers"] and "filtered_control" not in x["found_by_other_arms"]])
print("FS misses editor covers:", [(x["v"],x["d"],x["n"]) for x in fs["misses"] if x["editor_covers"]])
print("FS misses in 1861-1899:", sum(x["band"]=="1861-1899" for x in fs["misses"]))
# ME-2 sub-claims
inst=[x for x in fs["false_positives"] if x["category"]=="institution"]
GW=re.compile(r"\b(govt?|government|governments|embassy|emb|legation|ministry|fleet|army)\b", re.I)
print("FS institution with govt-word", sum(bool(GW.search(x["n"])) for x in inst), "of", len(inst))
tit=[x for x in fs["false_positives"] if x["category"]=="title-only"]
print("FS title-only multiword", sum(len(x["n"].split())>1 for x in tit), "of", len(tit))
sf=collections.Counter(x["n"].strip().lower() for x in fs["false_positives"])
for k in ("polish government","mexican government","the imperial government","the powers","officers","japs","jap","queen mother","the khedive","hunzedal","seville","commanding general seville","liu chieh","greek govt","greek emb"):
    print("  FS surface",k,sf.get(k))
cf=collections.Counter(x["n"].strip().lower() for x in fc["false_positives"])
print("FC surfaces", cf.most_common(60))
# ME-9
print("RS fp_by_rule", rs["fp_by_filter_rule"], "removed", rs["fp_removed_by_filter"], "kept via key", sum(x["survives_filter"] for x in rs["false_positives"]), "rule None", sum(x["filter_rule"] is None for x in rs["false_positives"]))
print("RS rule-None but not survives:", [(x["v"],x["d"],x["n"]) for x in rs["false_positives"] if x["filter_rule"] is None and not x["survives_filter"]])
print("RS rule set but survives:", [(x["v"],x["d"],x["n"],x["filter_rule"]) for x in rs["false_positives"] if x["filter_rule"] and x["survives_filter"]])
print("RS top", rs["fp_surface_frequency_top40"][:26])
print("RS washington rules", collections.Counter(x["filter_rule"] for x in rs["false_positives"] if x["n"].strip().lower()=="washington"))
print("RS misses", len(rs["misses"]), "shared", rs["misses_shared_with_filtered_sweep"], [x["n"] for x in rs["misses"] if x["category"]=="not-in-filtered-sweep-misses"])
print("RS boundary-rule FP surfaces", collections.Counter(x["n"] for x in rs["false_positives"] if x["filter_rule"]=="boundary").most_common(30))
# ME-10
print("FC doubled", [(x["v"],x["d"],x["n"],x["pred_overlapped"]) for x in fc["misses"] if x["category"]=="other:footnote-doubled-name"])
print("FS list-merged", [(x["v"],x["d"],x["n"],x["pred_overlapped"]) for x in fs["misses"] if x["category"]=="other:list-span-merged"])
print("caption FPs FC", [x["n"] for x in fc["false_positives"] if x["category"]=="other:citation-caption-name"], "FS", [x["n"] for x in fs["false_positives"] if x["category"]=="other:citation-caption-name"])
print("FS nested dup w/ gold_overlapped", [(x["n"],x["gold_overlapped"]) for x in fs["false_positives"] if x["category"]=="partial-name-boundary"])
print("King's miss", [(x["n"],x["category"],x["found_by_other_arms"]) for x in fs["misses"] if "King" in x["n"]])
print("GW misses FS", [(x["n"],x["found_by_other_arms"],x["editor_covers"]) for x in fs["misses"] if "Washington" in x["n"]])
print("GW misses FC", [(x["n"],x["found_by_other_arms"],x["editor_covers"]) for x in fc["misses"] if "Washington" in x["n"]])
