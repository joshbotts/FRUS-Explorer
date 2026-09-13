# Locate documents where the maximum matching is non-unique in a way that changes presence-grain keys:
# compare the scorer's Kuhn matching (sd.match) against my Hopcroft-Karp on the same inputs.
import os, sys, json, gzip, collections
sys.path.insert(0, "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/tools/semantic-harvest")
os.environ["DETECTORS"]=""; os.environ["OUT"]="/dev/null"
import score_detections as sd
def noop(*a,**k): pass
sys.argv=["x"]; exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)),"verify.py")).read().split("# ---- presence grain")[0].replace('print(', 'noop('))
for arm in ("filtered_control","intersection_control_side","editor+filtered_control","raw_control"):
    for k in docs:
        _, _, up_sd, ug_sd = sd.match(gold[k], arms[arm][k])
        _, up_me, ug_me = max_match(gold[k], arms[arm][k])
        if up_sd != up_me or ug_sd != ug_me:
            preds = arms[arm][k]
            print(arm, k, "gold-used sd", sorted(ug_sd - ug_me), "me", sorted(ug_me - ug_sd),
                  "| pred-used only-sd", [preds[i] for i in sorted(up_sd - up_me)], "only-me", [preds[i] for i in sorted(up_me - up_sd)],
                  "| gold spans", [gold[k][i] for i in sorted((ug_sd ^ ug_me))] or [gold[k][i] for i in ug_sd if any(ov(gold[k][i], preds[j]) for j in (up_sd ^ up_me))])
