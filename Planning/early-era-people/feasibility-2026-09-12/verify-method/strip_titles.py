import os,sys,re,json
D="/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-m2a"; GT=D+"/m2a-ground-truth.jsonl"
os.environ.update(GROUND_TRUTH=GT,DETECTORS="unused",OUT="/dev/null",TEXT_DIR="/Users/jbotts/frus-semantic-raw/text",STORE="/Users/jbotts/frus-ner-raw")
sys.path.insert(0,"/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/tools/semantic-harvest")
import score_detections as sd
ARMS=[("editor","/Users/jbotts/frus-ner-raw","marked"),("llm","/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-ner-raw","detected"),("llm-filtered","/Users/jbotts/frus-ner-raw-filtered","detected"),("control","/Users/jbotts/frus-ner-raw-control","detected"),("control-filtered","/Users/jbotts/frus-ner-raw-control-filtered","detected")]
gold,bands=sd.load_ground_truth(GT); DOCS=sorted(gold); texts={v:sd.cached_volume_text(v) for v,_ in DOCS}
preds={n:sd.collect_predictions(p,l,gold,False)[0] for n,p,l in ARMS}
# the harness's own core(), copied verbatim from m2a_analysis64.py
TITLE = set("mr mrs ms miss messrs dr doctor general gen admiral president vice señor senor sir lord earl count baron hon honorable generalissimo secretary ambassador minister senator governor m mme monsieur herr signor prince marshal colonel col captain capt commander consul judge chief justice premier prime excellency don madame major mayor".split())
def core(s, e, text):
    toks = list(re.finditer(r"\S+", text[s:e])); i = 0
    while i < len(toks) - 1 and toks[i].group().rstrip(".,").lower() in TITLE: i += 1
    cs, ce = s + (toks[i].start() if toks else 0), e
    while True:
        t = text[cs:ce]
        if t.endswith("’s") or t.endswith("'s"): ce -= 2
        elif t[-1:] in "’'.,;:" and len(t) > 1: ce -= 1
        else: break
    return cs, ce
for arm in preds:
    h=pn=gn=0
    for k in DOCS:
        t=texts[k[0]][k[1]]; g={core(s,e,t) for s,e,_ in gold[k]}; p=[core(s,e,t) for s,e,_ in preds[arm].get(k,[])]
        h+=len(set(p)&g); pn+=len(p); gn+=len(gold[k])
    P,R=h/pn,h/gn; print("%-17s stripped strict P %.3f R %.3f F1 %.3f"%(arm,P,R,2*P*R/(P+R)))
