#!/usr/bin/env python3
"""Arithmetic over v-census.json + v-gold.json: prose sub-type split of added pairs, three-way pool sources,
band-weighted false-pair illustration (INFERRED), POCOM loader variants. Writes derived.json."""
import collections, json, os
HERE = os.path.dirname(os.path.abspath(__file__))
V = json.load(open(os.path.join(HERE, "v-census.json"))); G = json.load(open(os.path.join(HERE, "v-gold.json")))
B = ["1861-1899", "1900-1929", "1930-1945", "1946-"]
fine = V["task2"]["pair_signature_fine_all"]; tot = sum(fine.values()); c = collections.Counter()
for s, n in fine.items():
    p = set(s.split("+"))
    c["has_prose_p" if "prose:p" in p else "prose_quote_no_p" if "prose:quote" in p else "prose_list_only" if "prose:list" in p else "prose_table_only" if "prose:table" in p else "prose_other_only" if "prose:other" in p else "no_prose"] += n
rows = collections.Counter()
for b in B:
    for r, n in V["task2"]["rows_region_fine"][b].items():
        rows[r] += n
src = V["task3_extra"]["three_net_pair_sources"]; net3 = V["task3"]["three_way_minus_agreement"]["pairs_net"]["all"]
pairs = V["task1"]["pairs"]; bp = G["arms"]["agreement_sweep_side"]["presence_gkey_by_band"]
bw = {b: pairs[b] * (1 - bp[b]["P"]) for b in B}
out = {"added_pairs": tot, "added_pairs_by_prose_subtype": {k: [v, round(v / tot, 4)] for k, v in c.items()},
       "added_rows_fine": {k: [v, round(v / sum(rows.values()), 4)] for k, v in rows.most_common()},
       "three_way_net_pairs": net3, "three_way_net_pairs_supported_only_by_control_side_spans_of_agreed_mentions": [src["int_fc"]["all"], round(src["int_fc"]["all"] / net3, 4)],
       "three_way_net_pairs_last_token_of_an_arm_key": [V["task3_extra"]["three_net_pairs_last_token_equals_an_arm_key_last_token"]["all"], round(V["task3_extra"]["three_net_pairs_last_token_equals_an_arm_key_last_token"]["all"] / net3, 4)],
       "illustration_pooled_false_pairs": round(pairs["all"] * (1 - 0.898)), "illustration_band_weighted_false_pairs": round(sum(bw.values())),
       "band_weighted_P": round(1 - sum(bw.values()) / pairs["all"], 4), "by_band": {b: round(v) for b, v in bw.items()},
       "gold_predicted_key_share_by_band": {b: round(bp[b]["pred_keys"] / 245, 3) for b in B}, "corpus_pair_share_by_band": {b: round(pairs[b] / pairs["all"], 3) for b in B},
       "pocom_added": {L: V["task4"][L]["pairs"]["added"]["all"] for L in ("quirk_loader", "elementtree_loader")},
       "pocom_all": {L: {k: V["task4"][L]["pairs"]["all"]["all"][k] for k in ("in_office", "exactly_one")} for L in ("quirk_loader", "elementtree_loader")}}
json.dump(out, open(os.path.join(HERE, "derived.json"), "w"), indent=1)
print(json.dumps(out, indent=1))
