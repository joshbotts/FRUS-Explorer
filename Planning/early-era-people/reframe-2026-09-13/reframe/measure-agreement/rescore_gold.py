#!/usr/bin/env python3
"""Task 5: confirm agreement.py reproduces the scored arm, by re-scoring it on the M2a gold.

Uses the scorer's own load_ground_truth / collect_predictions / match / score_one (imported from the repo,
read-only) and grains.py's presence grain + bootstrap (imported from a verbatim copy, sha256 5e717c11...).
Builds the arm TWO ways per gold document — grains' union_exact(E, intersection(FS, FC)) and
agreement.agreement_spans(E, FC, FS) — asserts they are identical, then scores it.
Writes rescore-gold.json beside this script.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import grains_copy as g        # noqa: E402  (sets GROUND_TRUTH/STORE/TEXT_DIR env, imports score_detections)
import agreement as A          # noqa: E402

sd = g.sd


def main():
    gold, bands = sd.load_ground_truth(os.environ["GROUND_TRUTH"])
    n_docs, n_mentions = len(gold), sum(len(v) for v in gold.values())
    assert (n_docs, n_mentions) == (64, 406), (n_docs, n_mentions)
    arms = {}
    for name in ("editor", "filtered_control", "filtered_sweep"):
        path, layer = g.STORES[name]
        preds, refused = sd.collect_predictions(path, layer, gold, True)
        assert not refused and set(preds) == set(gold), name
        arms[name] = preds
    E, FC, FS = arms["editor"], arms["filtered_control"], arms["filtered_sweep"]

    via_grains = g.union_exact(E, g.intersection(FS, FC))
    via_module = {k: sorted(A.agreement_spans(E[k], FC[k], FS[k])) for k in gold}
    identical = all(via_grains.get(k, []) == via_module[k] for k in gold)
    assert identical, "agreement.py disagrees with grains.py on the gold documents"

    doc_keys = sorted(gold)
    res = sd.score_one("agreement (module)", via_module, gold, bands, [])
    pcounts, false_keys, missed_keys, true_keys, _, _ = g.presence_doc_counts(gold, via_module)
    psum = g.presence_summary(pcounts, doc_keys)
    band_names, by_band, resamples = g.make_resamples(bands, doc_keys)
    pcis = g.bootstrap_presence(pcounts, resamples, band_names)
    pband = {b: g.presence_summary(pcounts, by_band[b]) for b in band_names}

    # the same arm, scored in census K2 (29-token, one honorific) instead of grains' 74-token key
    saved = g.surface_key
    g.surface_key = A.k2_of
    pcounts_k2 = g.presence_doc_counts(gold, via_module)[0]
    g.surface_key = saved
    psum_k2 = g.presence_summary(pcounts_k2, doc_keys)

    expected = {"precision": 0.898, "recall": 0.767, "ci95_precision": [0.852, 0.942],
                "predicted_keys": 245, "predicted_keys_false": 25, "strict_f1_mention": 0.672}
    got = {"precision": round(psum["precision"], 3), "recall": round(psum["recall"], 3),
           "ci95_precision": [round(x, 3) for x in pcis["overall"]["precision"]],
           "predicted_keys": psum["predicted_keys"], "predicted_keys_false": psum["predicted_keys_false"],
           "strict_f1_mention": round(res["strict"]["f1"], 3)}
    out = {
        "script": os.path.abspath(__file__),
        "ground_truth": os.environ["GROUND_TRUTH"],
        "sample": {"documents": n_docs, "mentions": n_mentions, "bands": {b: len(v) for b, v in by_band.items()}},
        "arm_built_two_ways_identical_on_all_64_documents": identical,
        "presence_grain_grains_key_74_token": {"overall": psum, "ci95": pcis["overall"], "by_band": pband},
        "presence_grain_census_K2_29_token_one_honorific": psum_k2,
        "mention_grain": {"strict": res["strict"], "relaxed": res["relaxed"]},
        "expected_from_assessment_s2_2": expected,
        "got": got,
        "reproduced": got == expected,
    }
    with open(os.path.join(HERE, "rescore-gold.json"), "w") as h:
        json.dump(out, h, indent=1, sort_keys=True, ensure_ascii=False)
    print(json.dumps({"got": got, "expected": expected, "reproduced": out["reproduced"],
                      "census_K2_presence": {k: psum_k2[k] for k in ("precision", "recall", "f1", "predicted_keys", "predicted_keys_false", "gold_keys")}},
                     indent=1))


if __name__ == "__main__":
    main()
