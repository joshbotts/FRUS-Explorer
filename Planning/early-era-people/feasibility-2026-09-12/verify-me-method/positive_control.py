import json, os, sys, collections
GT = "/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-m2a/m2a-ground-truth.jsonl"
os.environ["GROUND_TRUTH"] = GT
os.environ["STORE"] = "/Users/jbotts/frus-ner-raw"
os.environ["TEXT_DIR"] = os.path.expanduser("~/frus-semantic-raw/text")
REPO = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
sys.path.insert(0, os.path.join(REPO, "tools/semantic-harvest"))
import score_detections as sd
ARMS = collections.OrderedDict([
    ("editor", ("/Users/jbotts/frus-ner-raw","marked")),
    ("filtered_control", ("/Users/jbotts/frus-ner-raw-control-filtered","detected")),
    ("filtered_sweep", ("/Users/jbotts/frus-ner-raw-filtered","detected")),
    ("raw_sweep", ("/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-ner-raw","detected")),
    ("raw_control", ("/Users/jbotts/frus-ner-raw-control","detected")),
])
gold, bands = sd.load_ground_truth(GT)
print("gold docs", len(gold), "mentions", sum(len(v) for v in gold.values()), "empty", sum(1 for v in gold.values() if not v))
preds = {}
for name,(p,layer) in ARMS.items():
    pr, refused = sd.collect_predictions(p, layer, gold, True)
    assert not refused, (name, refused); assert set(pr)==set(gold)
    preds[name]=pr
    r = sd.score_one(name, pr, gold, bands, refused)
    print("%-17s relaxed %s strict hits %d" % (name, {k:r["relaxed"][k] for k in ("hits","predicted","gold","precision","recall")}, r["strict"]["hits"]))
# which relaxed hits does the filter cost, control and sweep?
def hitset(name):
    out=set()
    for key in gold:
        s,rl,up,ug = sd.match(gold[key], preds[name][key])
        out |= {(key, gold[key][i]) for i in ug}
    return out
for a,b in (("raw_control","filtered_control"),("raw_sweep","filtered_sweep")):
    ha,hb = hitset(a),hitset(b)
    print(a,"->",b,"lost gold hits:", sorted(ha-hb), "gained:", sorted(hb-ha))
# union recall, two ways: (1) naive miss-minus-editor-covers; (2) merged span list re-matched
for arm in ("filtered_control","filtered_sweep"):
    hits=0; pred=0
    for key in gold:
        merged = sorted(set(preds["editor"][key]) | set(preds[arm][key]))
        s,rl,up,ug = sd.match(gold[key], merged)
        hits+=rl; pred+=len(merged)
    print("union editor+%s (set-union of spans, rematched): hits %d predicted %d P %.4f R %.4f" % (arm,hits,pred,hits/pred,hits/406))
