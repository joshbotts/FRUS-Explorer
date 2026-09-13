#!/usr/bin/env python3
"""Aggregate INFERRED totals from cost-jobs.json for the headline job set A(queue)+B+C(armB, summary.json)+D(volume). Writes totals.json."""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
J = {j["job"]: j for j in json.load(open(os.path.join(HERE, "cost-jobs.json")))["jobs"]}
SET = ["A:union_minus_agree_net", "B:agree", "C:armB:summary.json pre-#1292 approximation", "D:volume-guide"]
out = {}
for model in ("haiku-4.5", "sonnet-5", "opus-5"):
    for key in ("low|batch|cached", "high|batch|cached", "high|standard|uncached"):
        out["%s %s" % (model, key)] = [round(sum(J[j]["models"][model][key]["usd"][i] for j in SET), 0) for i in range(3)]
        out["%s %s +chapter1500" % (model, key)] = [round(out["%s %s" % (model, key)][i] + J["D:chapter-guide-1500w"]["models"][model][key]["usd"][i], 0) for i in range(3)]
out["local no-think central hours (two time models)"] = [round(sum(J[j]["local"]["no-think 14B"]["hours_central_scenario_two_time_models"][k] for j in SET), 1) for k in range(2)]
json.dump({"set": SET, "totals": out}, open(os.path.join(HERE, "totals.json"), "w"), indent=1)
print(json.dumps(out, indent=1))
