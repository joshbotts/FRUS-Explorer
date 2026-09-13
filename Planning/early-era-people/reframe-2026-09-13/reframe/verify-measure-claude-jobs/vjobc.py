#!/usr/bin/env python3
"""vjobc.py — job C class counts from the ORIGINAL chapter-context/coverage/measure_chapter_rule.py re-run (copied to
jobc/mcr_after.py; only the HARNESS path and output filename changed) on before-docs.jsonl (positive control vs
summary.json) and after-docs.jsonl (post-#1292), tallied with summarize.py's rules. Compared against the measured
run's se-pocom-cases-post1292.json positive_control block. Read-only."""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
SP = "/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad"
def classes(T):
    g = lambda k: T.get(k, 0)
    s2o = sum(v for k, v in T.items() if k.startswith("T:several:->one"))
    conv = g("T:several:->one(dept-tier1-over-same-surname-tier2)")
    return {"rows": g("rows"), "rows_with_hypothesis": g("rows_with_hypothesis"),
            "contradicted": sum(v for k, v in T.items() if k.startswith("T:one:CONTRADICTED")),
            "narrowed_by_location": s2o - conv, "seward_assumption": conv}
summ = {(s["arm"], s["band"]): s for s in json.load(open(SP + "/chapter-context/coverage/summary.json"))}
theirs = json.load(open(SP + "/reframe/measure-claude-jobs/se-pocom-cases-post1292.json"))["positive_control_vs_summary_json"]
out = {}
for lab in ("before", "after"):
    T = json.load(open(os.path.join(HERE, "jobc", lab + "-chapter-rule.json")))["tallies"]
    for arm in ("A", "B"):
        for b in ("1861-1899", "1900-1905"):
            c = classes(T["%s|%s" % (arm, b)])
            row = {"mine": c}
            if lab == "before":
                s = summ[(arm, b)]
                row["summary_json"] = {"contradicted": s["one_contradicted"], "narrowed_by_location": s["several_to_one_other"], "seward_assumption": s["several_to_one_by_secretary_over_same_surname_assistant"], "rows_with_hypothesis": s["rows_with_hypothesis"]}
            else:
                m = theirs["%s|%s" % (arm, b)]["measured"]
                row["measured_run_post1292"] = {"contradicted": m["one_contradicted"], "narrowed_by_location": m["several_to_one"] - m["several_to_one_by_secretary_over_same_surname_assistant"], "seward_assumption": m["several_to_one_by_secretary_over_same_surname_assistant"], "rows_with_hypothesis": m["rows_with_hypothesis"]}
            ref = row.get("summary_json") or row.get("measured_run_post1292")
            row["match"] = all(c[k] == ref[k] for k in ref)
            out["%s|%s|%s" % (lab, arm, b)] = row
for lab in ("before", "after"):
    for arm in ("A", "B"):
        out["%s|%s|core_total" % (lab, arm)] = sum(out["%s|%s|%s" % (lab, arm, b)]["mine"][k] for b in ("1861-1899", "1900-1905") for k in ("contradicted", "narrowed_by_location", "seward_assumption"))
json.dump(out, open(os.path.join(HERE, "vjobc.json"), "w"), indent=1)
print(json.dumps(out, indent=1))
