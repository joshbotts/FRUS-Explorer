import os, sys, json, random, collections
M2A="/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-m2a"
os.environ["GROUND_TRUTH"]=M2A+"/m2a-ground-truth.jsonl"
os.environ["STORE"]=os.path.expanduser("~/frus-ner-raw")
sys.path.insert(0,"/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/tools/semantic-harvest")
import score_detections as sd
gold,bands=sd.load_ground_truth(sd.GROUND_TRUTH)
stores={"editor":(sd.MARKED_STORE,"marked"),
 "raw":("/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-ner-raw","detected"),
 "bnd":(os.path.expanduser("~/frus-ner-raw-filtered-boundary"),"detected"),
 "filt":(os.path.expanduser("~/frus-ner-raw-filtered"),"detected"),
 "ctl":(os.path.expanduser("~/frus-ner-raw-control"),"detected"),
 "ctlf":(os.path.expanduser("~/frus-ner-raw-control-filtered"),"detected")}
preds={}
for k,(p,layer) in stores.items():
    pr,ref=sd.collect_predictions(p,layer,gold,False); assert not ref,(k,ref); preds[k]=pr
# unions: editor + detector, dedupe exact (s,e)
def union(a,b):
    out={}
    for key in gold:
        seen=set(); rows=[]
        for sp in list(a.get(key,[]))+list(b.get(key,[])):
            if (sp[0],sp[1]) in seen: continue
            seen.add((sp[0],sp[1])); rows.append(sp)
        out[key]=rows
    return out
preds["ed+ctlf"]=union(preds["editor"],preds["ctlf"])
preds["ed+filt"]=union(preds["editor"],preds["filt"])
preds["ed+ctl"]=union(preds["editor"],preds["ctl"])
# per-doc stats
keys=sorted(gold)
per={k:{} for k in preds}
for k in preds:
    for key in keys:
        s,r,_,_=sd.match(gold[key],preds[k][key]); per[k][key]=(s,r,len(preds[k][key]),len(gold[key]))
def f1(h,p,g):
    P=h/p if p else 0; R=h/g if g else 0; return 2*P*R/(P+R) if P+R else 0
def agg(k,sample,which):
    h=p=g=0
    for key in sample:
        s,r,np_,ng=per[k][key]; h+= s if which=="strict" else r; p+=np_; g+=ng
    return f1(h,p,g),(h/p if p else 0),(h/g if g else 0)
print("== point estimates (all 64) F1 strict/relaxed, and strict_hits/relaxed_hits (boundary accuracy among found)")
for k in preds:
    fs=agg(k,keys,"strict"); fr=agg(k,keys,"relaxed")
    sh=sum(per[k][x][0] for x in keys); rh=sum(per[k][x][1] for x in keys)
    print("%-8s strict F1 %.4f P %.3f R %.3f | relaxed F1 %.4f P %.3f R %.3f | exact-of-found %d/%d=%.3f"%(k,fs[0],fs[1],fs[2],fr[0],fr[1],fr[2],sh,rh,sh/rh if rh else 0))
bybd=collections.defaultdict(list)
for key in keys: bybd[bands[key]].append(key)
bandnames=sorted(bybd)
print("bands", {b:len(v) for b,v in bybd.items()})
def rule_met(sample):
    # raw arms only: |strict gap|>=0.10 and same winner in every band
    a=agg("raw",sample,"strict")[0]; b=agg("ctl",sample,"strict")[0]
    if abs(a-b)<0.10: return False
    w=a>b
    for bn in bandnames:
        sub=[x for x in sample if bands[x]==bn]
        if not sub: return False
        aa=agg("raw",sub,"strict")[0]; bb=agg("ctl",sub,"strict")[0]
        if (aa>bb)!=w or aa==bb: return False
    return True
print("rule met at 64:", rule_met(keys), "gap ctl-raw strict %.4f"%(agg("ctl",keys,"strict")[0]-agg("raw",keys,"strict")[0]))
rng=random.Random(234); N=10000
diffs=collections.defaultdict(list); met=0
for i in range(N):
    sample=[]
    for bn in bandnames: sample+= [rng.choice(bybd[bn]) for _ in bybd[bn]]
    if rule_met(sample): met+=1
    for nm,(x,y,w) in {"ctl-filt strict":("ctl","filt","strict"),"ctl-raw strict":("ctl","raw","strict"),
                       "ctl-filt relaxed":("ctl","filt","relaxed"),"ctl-raw relaxed":("ctl","raw","relaxed"),
                       "filt-raw strict":("filt","raw","strict"),"filt-raw relaxed":("filt","raw","relaxed"),
                       "ctlf-filt relaxed":("ctlf","filt","relaxed"),
                       "ed+ctlf - filt relaxed":("ed+ctlf","filt","relaxed"),"ed+ctlf - ctlf relaxed":("ed+ctlf","ctlf","relaxed"),
                       "ed+ctlf - ed+filt relaxed":("ed+ctlf","ed+filt","relaxed")}.items():
        diffs[nm].append(agg(x,sample,w)[0]-agg(y,sample,w)[0])
    for nm in ("ed+ctlf","filt","ctl","ctlf","raw"):
        diffs[nm+" relaxed F1"].append(agg(nm,sample,"relaxed")[0])
        diffs[nm+" strict F1"].append(agg(nm,sample,"strict")[0])
print("== band-stratified document bootstrap, N=%d, seed 234"%N)
print("stopping rule met in %.2f%% of resamples"%(100*met/N))
for nm,v in diffs.items():
    v=sorted(v); print("%-30s point %+.4f  95%% [%+.4f, %+.4f]"%(nm, v[N//2], v[int(0.025*N)], v[int(0.975*N)-1]))
# 8 unkeyed simulation: add 2/3/3 docs drawn from their bands to the fixed 64
need={"1900-1929":2,"1930-1945":3,"1946-":3}; met8=0; gaps=[]
for i in range(N):
    sample=list(keys)
    for bn,n in need.items(): sample+= [rng.choice(bybd[bn]) for _ in range(n)]
    if rule_met(sample): met8+=1
    gaps.append(agg("ctl",sample,"strict")[0]-agg("raw",sample,"strict")[0])
print("8-unkeyed simulation: rule met %d of %d; strict gap ctl-raw range [%.4f, %.4f]"%(met8,N,min(gaps),max(gaps)))
