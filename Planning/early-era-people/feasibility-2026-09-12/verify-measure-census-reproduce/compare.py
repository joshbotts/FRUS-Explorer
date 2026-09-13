import json
c = json.load(open("/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad/measure-census/census.json"))
v = json.load(open("verify.json"))
diffs = []
def cmp(name, a, b):
    if a != b: diffs.append((name, a, b))
cmp("docs_total", c["scope"]["documents"], v["docs_total"])
cmp("docs_band", c["scope"]["documents_by_band"], v["docs_band"])
cmp("typed", c["arms"]["marked"]["typed_split"], v["typed"])
cmp("head_doc_mismatch", c["head_docs_mismatch"], v["head_doc_mismatch"])
print("zero_marked", v["zero_marked"]); print("body_head_mismatch", v["body_head_mismatch"])
for a, ca in c["arms"].items():
    va = v["arms"][a]
    cmp(a+".rows", ca["rows"], va["rows"])
    cmp(a+".rows_band", ca["mentions_by_band"], va["rows_band"])
    cmp(a+".K1", ca["distinct_K1"], va["K1"]); cmp(a+".K2", ca["distinct_K2"], va["K2"])
    cmp(a+".pairs", ca["pairs_volume_doc_K2"], va["pairs"]); cmp(a+".pairs_band", ca["pairs_by_band"], va["pairs_band"])
    cmp(a+".docs", ca["docs_with_mention"], va["docs"]); cmp(a+".docs_share", ca["docs_with_mention_share"], va["docs_share"])
    cmp(a+".docs_band", {k: [x["docs"], x["share"]] for k, x in ca["docs_with_mention_by_band"].items()}, va["docs_band"])
    cmp(a+".only_ft", ca["docs_only_marked_fromto"], va["only_ft"]); cmp(a+".only_ft_share", ca["docs_only_marked_fromto_share_of_docs_with_mention"], va["only_ft_share"])
    ck = ca["concentration_K2"]; vk = va["concK2"]
    for cf, vf in [("mentions_in_singleton_surfaces","single"),("mentions_in_surfaces_ge5","ge5"),("mentions_in_surfaces_ge20","ge20"),("share_singleton","share_single"),("share_ge5","share_ge5"),("share_ge20","share_ge20"),("surfaces_singleton","surf_single"),("surfaces_ge5","surf_ge5"),("surfaces_ge20","surf_ge20"),("top30","top30")]:
        cmp(a+".K2."+cf, ck[cf], vk[vf])
    ck = ca["concentration_K1"]; vk = va["concK1"]
    for cf, vf in [("mentions_in_singleton_surfaces","single"),("share_singleton","share_single"),("share_ge5","share_ge5"),("share_ge20","share_ge20"),("surfaces_singleton","surf_single"),("surfaces_ge5","surf_ge5"),("surfaces_ge20","surf_ge20")]:
        cmp(a+".K1."+cf, ck[cf], vk[vf])
    cmp(a+".pv_k2", ca["per_volume_distinct_K2"], {"median": va["pv_k2"]["median"], "max": va["pv_k2"]["max"], "max_volume": va["pv_k2"]["max_vol"], "min": va["pv_k2"]["min"]})
    cmp(a+".pv_pairs", ca["per_volume_pairs"], va["pv_pairs"])
    if "rows_dedup_span" in ca:
        cmp(a+".dedup", ca["rows_dedup_span"], va["dedup_span"]); print(a, "overlap", va["overlap_span"], "rows-dedup", ca["rows"]-ca["rows_dedup_span"])
print("DIFFS:", len(diffs))
for d in diffs: print(d)
