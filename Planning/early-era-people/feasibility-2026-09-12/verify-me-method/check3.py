import json, os, sys, collections, re
GT = "/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-m2a/m2a-ground-truth.jsonl"
os.environ["GROUND_TRUTH"] = GT; os.environ["STORE"] = "/Users/jbotts/frus-ner-raw"; os.environ["TEXT_DIR"] = os.path.expanduser("~/frus-semantic-raw/text")
REPO = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
sys.path.insert(0, os.path.join(REPO, "tools/semantic-harvest"))
import score_detections as sd, filter_detections as fd
gold, bands = sd.load_ground_truth(GT)
arms={"filtered_control":"/Users/jbotts/frus-ner-raw-control-filtered","filtered_sweep":"/Users/jbotts/frus-ner-raw-filtered","raw_control":"/Users/jbotts/frus-ner-raw-control"}
NONNAME = fd.TITLE_WORDS|fd.FUNCTION_WORDS
for name,p in arms.items():
    pr,_=sd.collect_predictions(p,"detected",gold,True)
    frag=[]; total=0
    for key in sorted(gold):
        s,rl,up,ug=sd.match(gold[key],pr[key])
        # reconstruct pairing: re-run match internals: easier — for each matched pred, find overlapping gold
        for pi in up:
            ps=pr[key][pi]; total+=1
            gs=[g for g in gold[key] if min(g[1],ps[1])-max(g[0],ps[0])>0]
            ptoks=set(fd.words(ps[2]))
            if ptoks and all(t in NONNAME for t in ptoks):
                frag.append((key,ps[2],[g[2] for g in gs]))
    print(name,"relaxed hits",total,"hits whose predicted surface is ONLY title/function words:",len(frag))
    print("   ",collections.Counter(f[1] for f in frag).most_common(12))
# F: doubled-name text
t=sd.cached_volume_text("frus1951v01")["d410"]
i=t.find("Berthoud Eric A. Berthoud"); print("R-0:",repr(t[i-80:i+120]))
t2=sd.cached_volume_text("frus1937v01")["d566"]; i=t2.find("Ernest Powell Ernest Powell"); print("R-0:",repr(t2[i-60:i+100]))
