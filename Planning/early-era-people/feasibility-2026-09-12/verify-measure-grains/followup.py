import os, sys, json, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import grains as G
sd=G.sd
S="/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad/measure-grains"
P=json.load(open(S+"/grains.json"))["presence_grain"]
gold,bands=sd.load_ground_truth(os.environ["GROUND_TRUTH"])
arms={}
for name,(path,layer) in G.STORES.items(): arms[name],_=sd.collect_predictions(path,layer,gold,True)
FC,FS,E=arms["filtered_control"],arms["filtered_sweep"],arms["editor"]
IS=G.intersection(FS,FC); IC=G.intersection(FC,FS)
print("== (a) position of intersection_sweep_side missed signatory-type mentions ==")
missed=P["intersection_sweep_side"]["missed_gold_keys_by_document"]
rows=[]
for row in missed:
    vd,k=row.split(": ",1); v,d=vd.split("/")
    if k not in ("seward","bayard","hay","william h. seward","adams"): continue
    text=sd.cached_volume_text(v)[d]; L=len(text)
    for s,e,n in gold[(v,d)]:
        if G.surface_key(n)==k: rows.append((round(s/L,3), v, d, n, text[max(0,s-40):e+25].replace("\n"," ")))
rows.sort()
first10=sum(1 for r in rows if r[0]<0.1); print("  n=%d first-10%%: %d last-10%%: %d" % (len(rows), first10, sum(1 for r in rows if r[0]>=0.9)))
for r in rows[:28]: print("  ", r)
print("== (b) filtered_control: predicted keys overlap-TRUE but not equal to any gold key in the doc ==")
def mismatch(preds, label, limit=25):
    c=collections.Counter(); ex=[]
    for key,gspans in gold.items():
        _,_,used_pred,used_gold=sd.match(gspans,preds[key])
        gk={G.surface_key(n) for _,_,n in gspans}
        # map pred index -> gold index via re-running match internals is not exposed; approximate: for each used pred, find overlapping gold
        for i,(s,e,n) in enumerate(preds[key]):
            if i in used_pred and G.surface_key(n) not in gk:
                gnames=[gn for gs,ge,gn in gspans if min(e,ge)-max(s,gs)>0]
                c[(G.surface_key(n), tuple(G.surface_key(x) for x in gnames))]+=1
                if len(ex)<limit: ex.append((key[0],key[1],n,gnames))
    print("  %s: %d overlap-true predicted mentions whose key equals no gold key in the document" % (label, sum(c.values())))
    kinds=collections.Counter()
    for (pk,gks),n in c.items():
        if any(pk!=gk and (gk.endswith(" "+pk) or gk.startswith(pk+" ")) for gk in gks): kinds["pred is a sub-name of gold (partial)"]+=n
        elif any(pk!=gk and (pk.endswith(" "+gk) or pk.startswith(gk+" ")) for gk in gks): kinds["pred is a super-string of gold (title/extra)"]+=n
        else: kinds["other"]+=n
    print("   kinds:", dict(kinds))
    for e in ex[:limit]: print("   ", e)
mismatch(FC,"filtered_control"); mismatch(IC,"intersection_control_side",10); mismatch(IS,"intersection_sweep_side",10); mismatch(E,"editor",5)
