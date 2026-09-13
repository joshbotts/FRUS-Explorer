"""Band-stratified document bootstrap (10,000 resamples, seed 1) over per-document hit counts, re-using rescore.py's loaders."""
import random, json, os, sys, importlib.util
spec=importlib.util.spec_from_file_location("rs", os.path.join(os.path.dirname(os.path.abspath(__file__)),"rescore.py"))
# re-execute rescore's loaders without rewriting its json output: import as module (it will re-run and rewrite same file; acceptable)
rs=importlib.util.module_from_spec(spec); sys.stdout=open(os.devnull,"w"); spec.loader.exec_module(rs); sys.stdout=sys.__stdout__
docs=rs.docs; P=rs.P
# per-document (strict, relaxed, pred, gold)
def perdoc(preds):
    out={}
    for k,g in docs.items():
        p=preds[k]; gs=g["spans"]
        strict=len({(s,e) for s,e,_ in p}&{(s,e) for s,e,_ in gs}); rel=rs.maxmatch(gs,p)
        out[k]=(strict,rel,len(p),len(gs))
    return out
D={n:perdoc(p) for n,p in P.items()}
bands={}
for k,g in docs.items(): bands.setdefault(g["band"],[]).append(k)
def f1(h,p,g):
    P_=h/p if p else 0; R=h/g if g else 0; return 2*P_*R/(P_+R) if P_+R else 0
def score(name, keys, idx):
    h=sum(D[name][k][idx] for k in keys); p=sum(D[name][k][2] for k in keys); g=sum(D[name][k][3] for k in keys); return f1(h,p,g)
rng=random.Random(1); N=10000
gaps_sf=[]; gaps_rel=[]; gaps_raw=[]; rule_met=0; filt_gain=[]
for _ in range(N):
    sample=[k for b,ks in bands.items() for k in rng.choices(ks,k=len(ks))]
    gaps_sf.append((score("control",sample,0)-score("sweep_filtered",sample,0))*100)
    gaps_rel.append((score("control",sample,1)-score("sweep_filtered",sample,1))*100)
    gaps_raw.append((score("control",sample,0)-score("sweep",sample,0))*100)
    filt_gain.append((score("sweep_filtered",sample,0)-score("sweep",sample,0))*100)
    # stopping rule on this resample: |raw gap|>=10 and same winner in every band
    per_band=[]
    for b,ks in bands.items():
        s=[k for k in sample if docs[k]["band"]==b]
        per_band.append(score("control",s,0)-score("sweep",s,0))
    g=gaps_raw[-1]
    if abs(g)>=10 and (all(x>0 for x in per_band) or all(x<0 for x in per_band)): rule_met+=1
def ci(a): a=sorted(a); return round(a[int(0.025*N)],1), round(a[int(0.975*N)-1],1)
res={"control_minus_filtered_sweep_strict":{"point":round(gaps_sf and (score("control",list(docs),0)-score("sweep_filtered",list(docs),0))*100,1),"ci95":ci(gaps_sf)},
     "control_minus_filtered_sweep_relaxed":{"point":round((score("control",list(docs),1)-score("sweep_filtered",list(docs),1))*100,1),"ci95":ci(gaps_rel)},
     "control_minus_raw_sweep_strict":{"point":round((score("control",list(docs),0)-score("sweep",list(docs),0))*100,1),"ci95":ci(gaps_raw)},
     "filter_gain_strict":{"point":round((score("sweep_filtered",list(docs),0)-score("sweep",list(docs),0))*100,1),"ci95":ci(filt_gain)},
     "stopping_rule_met_fraction":rule_met/N,"resamples":N,"seed":1}
print(json.dumps(res,indent=1)); json.dump(res,open(os.path.join(os.path.dirname(os.path.abspath(__file__)),"bootstrap.json"),"w"),indent=1)
