#!/usr/bin/env python3
"""Compact view of cost-jobs.json: per job, requests/tokens (central), $ for three treatments x three models, pilots x3,
local no-think hours and electricity. Writes summary-costs.md here. INFERRED figures only."""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
J = json.load(open(os.path.join(HERE, "cost-jobs.json")))
f = open(os.path.join(HERE, "summary-costs.md"), "w")
def fm(x):
    return " / ".join(("{:,.0f}".format(v) if v >= 100 else "{:,.1f}".format(v)) for v in x)
f.write("| job | req C | in MTok C (Sonnet 5) | out MTok C | Haiku 4.5 batch+cache low | Sonnet 5 batch+cache low | Sonnet 5 std high | Opus 5 batch+cache low | Opus 5 std high | local 14B no-think h (C scen.) | local h range / 27-31B | kWh / $ range |\n|---|---|---|---|---|---|---|---|---|---|---|---|\n")
for j in J["jobs"]:
    m = j["models"]
    s = m["sonnet-5"]
    L = j["local"]["no-think 14B"]
    reps = 3 if j["job"].startswith("E:") else 1
    x = lambda key, model: [v * reps for v in m[model][key]["usd"]]
    f.write("| %s%s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s / %s | %s / %s |\n" % (
        j["job"], " (x3 reps)" if reps == 3 else "", "{:,}".format(j["scenarios"][1]["requests"]), s["low|batch|cached"]["input_MTok"][1],
        s["low|batch|cached"]["visible_output_MTok"][1], fm(x("low|batch|cached", "haiku-4.5")), fm(x("low|batch|cached", "sonnet-5")),
        fm(x("high|standard|uncached", "sonnet-5")), fm(x("low|batch|cached", "opus-5")), fm(x("high|standard|uncached", "opus-5")),
        L["hours_central_scenario_two_time_models"], L["hours_range_all_scenarios"], L["hours_range_27_31B_judge"], L["kWh_range"], L["electricity_usd_range"]))
f.close()
print(open(os.path.join(HERE, "summary-costs.md")).read())
print(json.dumps(J["local_time_model"], indent=1))
