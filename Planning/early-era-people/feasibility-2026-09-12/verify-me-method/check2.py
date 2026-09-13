import json, os, sys, collections, re
GT = "/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-m2a/m2a-ground-truth.jsonl"
os.environ["GROUND_TRUTH"] = GT; os.environ["STORE"] = "/Users/jbotts/frus-ner-raw"; os.environ["TEXT_DIR"] = os.path.expanduser("~/frus-semantic-raw/text")
REPO = "/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
sys.path.insert(0, os.path.join(REPO, "tools/semantic-harvest"))
import score_detections as sd, filter_detections as fd, ner_store as store
gold, bands = sd.load_ground_truth(GT)
rc,_ = sd.collect_predictions("/Users/jbotts/frus-ner-raw-control","detected",gold,True)
fc,_ = sd.collect_predictions("/Users/jbotts/frus-ner-raw-control-filtered","detected",gold,True)
ed,_ = sd.collect_predictions("/Users/jbotts/frus-ner-raw","marked",gold,True)
gaz = fd.load_gazetteer(os.path.join(REPO,"FRUSExplorer/Resources/volume-tag-taxonomy.json"), os.path.join(REPO,"FRUSExplorer/Resources/decimal-class-labels.json"))
# A: rule that removed the control's Seward hits
for key,g in ((("frus1866p3","d175"),(952,974)),(("frus1866p3","d206"),(2826,2848))):
    text = sd.cached_volume_text(key[0])[key[1]]
    for sp in rc[key]:
        if min(sp[1],g[1])-max(sp[0],g[0])>0:
            print("A raw-control span", key, sp, "rule", fd.rule_for(sp[2],text,sp[0],sp[1],fd.ALL_RULES,gaz), "in filtered?", sp in fc[key], "context", repr(text[sp[0]-30:sp[1]+30]))
# B: editor-cover discrepancy: per doc, control hits + editor-covered misses vs union rematch
tot_naive=0; tot_union=0
for key in sorted(gold):
    s,rl,up,ug = sd.match(gold[key], fc[key])
    misses=[gold[key][i] for i in range(len(gold[key])) if i not in ug]
    covered=[m for m in misses if any(min(m[1],e[1])-max(m[0],e[0])>0 for e in ed[key])]
    merged=sorted(set(ed[key])|set(fc[key]))
    s2,rl2,_,_ = sd.match(gold[key], merged)
    naive=rl+len(covered); tot_naive+=naive; tot_union+=rl2
    if naive!=rl2:
        print("B doc", key, "control hits",rl,"covered misses",len(covered),"naive",naive,"union rematch",rl2, "covered:",covered, "editor spans:",ed[key])
print("B totals naive",tot_naive,"union",tot_union)
