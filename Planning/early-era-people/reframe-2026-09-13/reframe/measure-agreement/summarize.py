#!/usr/bin/env python3
"""Derived shares over agreement-census.json + followup.json (exact arithmetic on the measured counts).
Writes summary.json."""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
r = json.load(open(os.path.join(HERE, "agreement-census.json")))
f = json.load(open(os.path.join(HERE, "followup.json")))
B = ["1861-1899", "1900-1929", "1930-1945", "1946-"]
def sh(a, b): return round(a / b, 4) if b else None
t2 = r["task2_beyond_editor"]
out = {"script": os.path.abspath(__file__), "added_pairs_region": {}, "added_rows_region": {}}
tot = {"pairs": 0, "any_prose": 0, "heading_only": 0, "apparatus_only": 0, "note_only": 0, "no_prose": 0, "any_heading": 0}
rows_tot = {}
for b in B:
    sig = t2["added_pair_region_signature"][b]
    n = sum(sig.values())
    anyp = sum(v for s, v in sig.items() if "prose" in s.split("+"))
    head_only = sum(v for s, v in sig.items() if set(s.split("+")) <= {"head", "other_head"})
    app_only = sig.get("apparatus", 0)
    note_only = sig.get("note", 0)
    any_head = sum(v for s, v in sig.items() if set(s.split("+")) & {"head", "other_head"})
    assert n == t2["added_pairs"][b], (b, n, t2["added_pairs"][b])
    d = {"pairs": n, "any_prose": anyp, "heading_only": head_only, "apparatus_only": app_only, "note_only": note_only,
         "no_prose": n - anyp, "any_heading": any_head}
    for k in list(tot):
        tot[k] += d[k]
    out["added_pairs_region"][b] = dict(d, share_any_prose=sh(anyp, n), share_heading_only=sh(head_only, n),
                                        share_apparatus_only=sh(app_only, n), share_note_only=sh(note_only, n),
                                        share_any_heading=sh(any_head, n))
    rr = t2["added_rows_by_region"][b]
    rn = sum(rr.values())
    out["added_rows_region"][b] = {k: v for k, v in rr.items()}
    out["added_rows_region"][b].update({"rows": rn, "share_prose": sh(rr["prose"], rn),
                                        "share_heading": sh(rr["head"] + rr["other_head"], rn)})
    for k, v in rr.items():
        rows_tot[k] = rows_tot.get(k, 0) + v
out["added_pairs_region"]["all"] = dict(tot, share_any_prose=sh(tot["any_prose"], tot["pairs"]),
                                        share_heading_only=sh(tot["heading_only"], tot["pairs"]),
                                        share_apparatus_only=sh(tot["apparatus_only"], tot["pairs"]),
                                        share_note_only=sh(tot["note_only"], tot["pairs"]),
                                        share_any_heading=sh(tot["any_heading"], tot["pairs"]))
rn = sum(rows_tot.values())
out["added_rows_region"]["all"] = dict(rows_tot, rows=rn, share_prose=sh(rows_tot["prose"], rn),
                                       share_heading=sh(rows_tot["head"] + rows_tot["other_head"], rn),
                                       share_apparatus=sh(rows_tot["apparatus"], rn), share_note=sh(rows_tot["note"], rn))
t1 = r["task1_agreement_arm"]; comp = r["comparators_same_pass"]
out["arm_vs_comparators"] = {
    "pairs_arm_over_editor_union_fc": sh(t1["pairs"]["all"], comp["editor_union_filtered_control"]["pairs"]),
    "pairs_arm_minus_editor_union_fc": t1["pairs"]["all"] - comp["editor_union_filtered_control"]["pairs"],
    "docs_arm_minus_editor_union_fc": t1["documents_reached"]["all"]["docs"] - comp["editor_union_filtered_control"]["docs"],
    "pairs_arm_over_editor": sh(t1["pairs"]["all"], comp["editor"]["pairs"]),
    "gzip_arm_minus_editor_union_fc_bytes": t1["artifact_grouped_one_letter"]["gzip_bytes"] - comp["editor_union_filtered_control"]["gzip_bytes"],
    "pairs_by_band_arm_over_editor_union_fc": {b: sh(t1["pairs"][b], comp["editor_union_filtered_control"]["pairs_by_band"][b]) for b in B},
    "docs_share_by_band_editor_union_fc": {b: sh(comp["editor_union_filtered_control"]["docs_by_band"][b], r["scope"]["documents_by_band"][b]) for b in B},
    "docs_share_by_band_editor": {b: sh(comp["editor"]["docs_by_band"][b], r["scope"]["documents_by_band"][b]) for b in B},
}
t4 = r["task4_pocom_ceiling"]
out["pocom_shares"] = {o: {b: {"share_surname_known": sh(t4["pairs_" + o][b]["surname_known"], t4["pairs_" + o][b]["pairs"]),
                              "share_in_office": t4["pairs_" + o][b]["share_in_office"],
                              "share_exactly_one": t4["pairs_" + o][b]["share_exactly_one_in_office"]} for b in B + ["all"]}
                       for o in ("all_agreement", "editor", "added")}
t3 = r["task3_pools"]
out["pools_net_pairs_per_scope_doc"] = {p: {b: sh(t3[p]["pairs_net_of_agreement"][b], r["scope"]["documents_by_band"][b] if b != "all" else r["scope"]["documents"]) for b in B + ["all"]} for p in t3}
out["pools_net_vs_arm_added_pairs"] = {p: sh(t3[p]["pairs_net_of_agreement"]["all"], t2["added_pairs"]["all"]) for p in t3}
out["added_last_token_duplicate_share"] = {b: sh(t2["added_pairs_last_token_equals_an_editor_key_last_token_same_doc"][b], t2["added_pairs"][b]) for b in B + ["all"]}
out["followup_single_token_shares"] = {k: v["share_single_token"] for k, v in f["keys"].items()}
out["followup_pairs_on_corpus_singleton_keys_share"] = {k: sh(v["pairs_on_keys_seen_once_corpus_wide"], v["pairs"]) for k, v in f["keys"].items()}
json.dump(out, open(os.path.join(HERE, "summary.json"), "w"), indent=1)
print(json.dumps(out, indent=1))
