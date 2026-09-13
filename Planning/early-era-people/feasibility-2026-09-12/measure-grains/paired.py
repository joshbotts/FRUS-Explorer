#!/usr/bin/env python3
"""Paired bootstrap differences between arms (same seed-234 resample set as grains.py), both grains.
POST-HOC, like everything in this directory."""
import os, sys, json, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import grains as G
sd = G.sd

def main():
    gold, bands = sd.load_ground_truth(os.environ["GROUND_TRUTH"])
    arms = {}
    for name, (path, layer) in G.STORES.items():
        arms[name], _ = sd.collect_predictions(path, layer, gold, True)
    E, FC, FS = arms["editor"], arms["filtered_control"], arms["filtered_sweep"]
    arms["intersection_control_side"] = G.intersection(FC, FS)
    arms["intersection_sweep_side"] = G.intersection(FS, FC)
    arms["editor+filtered_control"] = G.union_exact(E, FC)
    arms["editor+filtered_sweep"] = G.union_exact(E, FS)
    arms["editor+intersection_control_side"] = G.union_exact(E, arms["intersection_control_side"])
    arms["editor+intersection_sweep_side"] = G.union_exact(E, arms["intersection_sweep_side"])
    arms["editor+filtered_control+filtered_sweep"] = G.union_exact(E, FC, FS)
    doc_keys = sorted(gold)
    band_names, by_band, resamples = G.make_resamples(bands, doc_keys)

    # spot-check of the key normalisation on real surfaces
    samples = ["Mr. Mariscal’s", "General Stoessel", "Sir Edward Grey", "the Secretary", "Messrs. Adams and Seward",
               "Rt. Hon. Lord Lyons", "Vyshinsky’s", "Earl Russell", "Count von Bismarck", "Señor Romero's"]
    print("key spot-check:", {s: G.surface_key(s) for s in samples})

    mcounts = {a: G.mention_doc_counts(gold, p) for a, p in arms.items()}
    pcounts = {a: G.presence_doc_counts(gold, p)[0] for a, p in arms.items()}

    def stats_m(counts, keys):
        s, r, p, g = G.aggregate(counts, keys)
        pr = r / p if p else 0.0; rc = r / g if g else 0.0
        f1 = 2*pr*rc/(pr+rc) if pr+rc else 0.0
        sp = s / p if p else 0.0; sr = s / g if g else 0.0
        sf = 2*sp*sr/(sp+sr) if sp+sr else 0.0
        return {"relaxed_f1": f1, "relaxed_precision": pr, "relaxed_recall": rc, "strict_f1": sf}
    def stats_p(counts, keys):
        pkh, pk, gkh, gk = G.aggregate(counts, keys)
        pr = pkh / pk if pk else 0.0; rc = gkh / gk if gk else 0.0
        f1 = 2*pr*rc/(pr+rc) if pr+rc else 0.0
        return {"f1": f1, "precision": pr, "recall": rc}

    comparisons = [
        ("editor+intersection_sweep_side", "editor+filtered_control"),
        ("editor+intersection_control_side", "editor+filtered_control"),
        ("editor+intersection_sweep_side", "editor+intersection_control_side"),
        ("editor+filtered_control", "editor+filtered_sweep"),
        ("editor+filtered_control", "editor"),
        ("editor+intersection_sweep_side", "editor"),
        ("intersection_control_side", "filtered_control"),
        ("intersection_sweep_side", "filtered_sweep"),
        ("intersection_sweep_side", "intersection_control_side"),
        ("editor+filtered_control+filtered_sweep", "editor+filtered_control"),
        ("filtered_control", "filtered_sweep"),
    ]
    out = {}
    for a, b in comparisons:
        keys_all = doc_keys
        pm = {k: stats_m(mcounts[a], keys_all)[k] - stats_m(mcounts[b], keys_all)[k] for k in ("relaxed_f1", "relaxed_precision", "relaxed_recall", "strict_f1")}
        pp = {k: stats_p(pcounts[a], keys_all)[k] - stats_p(pcounts[b], keys_all)[k] for k in ("f1", "precision", "recall")}
        dm = collections.defaultdict(list); dp = collections.defaultdict(list)
        for draw in resamples:
            keys = [k for bnd in band_names for k in draw[bnd]]
            sa, sb = stats_m(mcounts[a], keys), stats_m(mcounts[b], keys)
            for k in sa: dm[k].append(sa[k] - sb[k])
            pa, pb = stats_p(pcounts[a], keys), stats_p(pcounts[b], keys)
            for k in pa: dp[k].append(pa[k] - pb[k])
        rec = {"mention": {k: {"diff": round(pm[k], 4), "ci95": G.ci(v), "p_le_0": round(sum(1 for x in v if x <= 0)/len(v), 4)} for k, v in dm.items()},
               "presence": {k: {"diff": round(pp[k], 4), "ci95": G.ci(v), "p_le_0": round(sum(1 for x in v if x <= 0)/len(v), 4)} for k, v in dp.items()}}
        out["%s MINUS %s" % (a, b)] = rec
        print("%-38s - %-38s | mention relaxed F1 %+.3f [%+.3f,%+.3f] strict F1 %+.3f [%+.3f,%+.3f] | presence F1 %+.3f [%+.3f,%+.3f] P %+.3f [%+.3f,%+.3f] R %+.3f [%+.3f,%+.3f]" % (
            a, b, pm["relaxed_f1"], *rec["mention"]["relaxed_f1"]["ci95"], pm["strict_f1"], *rec["mention"]["strict_f1"]["ci95"],
            pp["f1"], *rec["presence"]["f1"]["ci95"], pp["precision"], *rec["presence"]["precision"]["ci95"], pp["recall"], *rec["presence"]["recall"]["ci95"]))
    json.dump({"label": "POST-HOC paired bootstrap differences; same seed-234 band-stratified document resamples as grains.json; "
               "p_le_0 = share of resamples where the difference is <= 0", "comparisons": out},
              open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "paired-differences.json"), "w"), indent=1, sort_keys=True)

if __name__ == "__main__":
    main()
