import os, sys, json, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import grains as G
sd = G.sd
S="/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad/measure-grains"
gj=json.load(open(S+"/grains.json"))
M, P = gj["mention_grain"], gj["presence_grain"]

print("== 1. ranking by relaxed mention F1 vs presence F1 ==")
rm=sorted(M, key=lambda a:-M[a]["overall"]["relaxed"]["f1"]); rp=sorted(P, key=lambda a:-P[a]["overall"]["f1"])
for a,b in zip(rm,rp): print("  %-40s %.3f | %-40s %.3f" % (a, M[a]["overall"]["relaxed"]["f1"], b, P[b]["overall"]["f1"]))
print("  same order:", rm==rp)
print("== 2. grain shift presence F1 - relaxed mention F1 ==")
for a in M: print("  %-40s %+.3f" % (a, P[a]["overall"]["f1"]-M[a]["overall"]["relaxed"]["f1"]))

print("== 3. MG-6 per-band figures from grains.json ==")
for a in ["editor","filtered_control","filtered_sweep","intersection_control_side","editor+filtered_control","editor+intersection_control_side","editor+intersection_sweep_side","editor+filtered_sweep"]:
    print("  %-34s" % a, "; ".join("%s %.3f/%.3f/%.3f" % (b, P[a]["by_band"][b]["precision"], P[a]["by_band"][b]["recall"], P[a]["by_band"][b]["f1"]) for b in sorted(P[a]["by_band"])))
    print("     gold keys per band:", {b:P[a]["by_band"][b]["gold_keys"] for b in sorted(P[a]["by_band"])}, "docs", {b:P[a]["by_band"][b]["documents"] for b in sorted(P[a]["by_band"])})
print("  editor+int_ctrl 1930-1945 P ci:", P["editor+intersection_control_side"]["by_band"]["1930-1945"]["ci95"]["precision"])

print("== 4. MG-2 mention per band, intersection_control_side ==")
for b in sorted(M["intersection_control_side"]["by_band"]):
    x=M["intersection_control_side"]["by_band"][b]; print("  ",b,x["documents"],x["relaxed"], x["ci95"]["relaxed_precision"])
print("  overall predicted:", M["intersection_control_side"]["overall"]["relaxed"]["predicted"], M["intersection_sweep_side"]["overall"]["relaxed"]["predicted"], "editor+fc:", M["editor+filtered_control"]["overall"]["relaxed"]["predicted"], "3way:", M["editor+filtered_control+filtered_sweep"]["overall"]["relaxed"]["predicted"])

# load arms
gold, bands = sd.load_ground_truth(os.environ["GROUND_TRUTH"])
arms={}
for name,(path,layer) in G.STORES.items():
    arms[name],_=sd.collect_predictions(path,layer,gold,True)
E,FC,FS=arms["editor"],arms["filtered_control"],arms["filtered_sweep"]
arms["intersection_control_side"]=G.intersection(FC,FS); arms["intersection_sweep_side"]=G.intersection(FS,FC)
arms["editor+filtered_control"]=G.union_exact(E,FC); arms["editor+filtered_sweep"]=G.union_exact(E,FS)
arms["editor+intersection_control_side"]=G.union_exact(E,arms["intersection_control_side"])
arms["editor+intersection_sweep_side"]=G.union_exact(E,arms["intersection_sweep_side"])
arms["editor+filtered_control+filtered_sweep"]=G.union_exact(E,FC,FS)

print("== 5. band of false keys, intersection_control_side ==")
fk=P["intersection_control_side"]["false_predicted_keys_by_document"]
byband=collections.defaultdict(list)
for row in fk:
    vd,k=row.split(": ",1); v,d=vd.split("/"); byband[bands[(v,d)]].append(k)
for b in sorted(byband): print("  ",b,len(byband[b]),byband[b])

print("== 6. missed gold pairs of intersection_sweep_side: band + text position ==")
missed=P["intersection_sweep_side"]["missed_gold_keys_by_document"]
pos=[]; bandc=collections.Counter()
for row in missed:
    vd,k=row.split(": ",1); v,d=vd.split("/")
    text=sd.cached_volume_text(v)[d]; L=len(text); bandc[bands[(v,d)]]+=1
    for s,e,n in gold[(v,d)]:
        if G.surface_key(n)==k: pos.append((s/L, k, bands[(v,d)]))
print("  missed pairs by band:", dict(bandc))
last10=sum(1 for p,_,_ in pos if p>=0.9); print("  missed gold mentions under missed keys:", len(pos), "in last 10%% of doc: %d (%.1f%%)" % (last10, 100*last10/len(pos)))
allpos=[]
for (v,d),spans in gold.items():
    if not spans: continue
    L=len(sd.cached_volume_text(v)[d])
    for s,e,n in spans: allpos.append(s/L)
print("  all gold mentions in last 10%%: %d of %d (%.1f%%)" % (sum(1 for p in allpos if p>=0.9), len(allpos), 100*sum(1 for p in allpos if p>=0.9)/len(allpos)))
sig=[(p,k,b) for p,k,b in pos if k in ("seward","bayard","hay","william h. seward","adams")]
print("  seward/bayard/hay/w.h.seward/adams missed mentions: %d, in last 10%%: %d, bands %s" % (len(sig), sum(1 for p,_,_ in sig if p>=0.9), collections.Counter(b for _,_,b in sig)))
# are those missed by filtered_control too?
fcm=set(P["filtered_control"]["missed_gold_keys_by_document"]); im=set(missed); icm=set(P["intersection_control_side"]["missed_gold_keys_by_document"])
print("  int_sweep misses subset of fc misses:", im>=fcm, "fc misses subset of int_sweep misses:", fcm<=im, "| extra beyond fc:", len(im-fcm), sorted(im-fcm)[:12])
print("  int_ctrl misses ⊇ fc misses:", icm>=fcm, "extra:", len(icm-fcm))

print("== 7. key-identity presence variant (pred key true only if EQUAL to a gold key in the doc) ==")
def keyid(preds):
    tp=fp=fn=0
    for key,gspans in gold.items():
        gk={G.surface_key(n) for _,_,n in gspans}; pk={G.surface_key(n) for _,_,n in preds[key]}
        tp+=len(gk&pk); fp+=len(pk-gk); fn+=len(gk-pk)
    p=tp/(tp+fp) if tp+fp else 0; r=tp/(tp+fn) if tp+fn else 0; f=2*p*r/(p+r) if p+r else 0
    return p,r,f,tp,fp,fn
for a in ["editor","filtered_control","filtered_sweep","intersection_control_side","intersection_sweep_side","editor+filtered_control","editor+intersection_control_side","editor+intersection_sweep_side","editor+filtered_sweep","editor+filtered_control+filtered_sweep"]:
    p,r,f,tp,fp,fn=keyid(arms[a]); print("  %-40s P %.3f R %.3f F1 %.3f (tp %d fp %d fn %d) | report presence P %.3f R %.3f F1 %.3f" % (a,p,r,f,tp,fp,fn,P[a]["overall"]["precision"],P[a]["overall"]["recall"],P[a]["overall"]["f1"]))

print("== 8. same-person gold key over-count: gold keys that are a token-suffix of another gold key in the same document ==")
tot=0; sub=0; ex=[]
for key,gspans in gold.items():
    gk=sorted({G.surface_key(n) for _,_,n in gspans}); tot+=len(gk)
    for k in gk:
        for o in gk:
            if o!=k and (o.endswith(" "+k)):
                sub+=1; ex.append((k,o)); break
print("  gold keys", tot, "that are a suffix of another gold key in same doc:", sub, ex[:15])
print("  gold docs with >1 key sharing a last token:", sum(1 for key,gspans in gold.items() if len({G.surface_key(n) for _,_,n in gspans})>len({G.surface_key(n).split()[-1] for _,_,n in gspans})))
lt=0
for key,gspans in gold.items():
    ks={G.surface_key(n) for _,_,n in gspans}; lt+=len({k.split()[-1] for k in ks})
print("  gold keys collapsed by last token:", lt, "vs", tot)
