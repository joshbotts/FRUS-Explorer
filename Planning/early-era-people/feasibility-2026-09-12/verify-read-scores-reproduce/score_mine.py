#!/usr/bin/env python3
"""Independent re-scoring of the M2a gold against the six arms. Does NOT import the author's
modules; re-implements strict (exact span) and relaxed (maximum bipartite matching over any
overlap, via Hopcroft-Karp-style BFS/DFS rather than the author's Kuhn recursion) matching,
band splits, band-stratified bootstrap, the stopping rule, the 8-unkeyed simulation, unions
and a titles/possessives-stripped strict variant."""
import json, gzip, os, random, re, sys, collections
M="/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-m2a"
SWEEP="/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-ner-raw"
H=os.path.expanduser
ARMS=[("editor",SWEEP,"marked"),("raw_sweep",SWEEP,"detected"),("boundary",H("~/frus-ner-raw-filtered-boundary"),"detected"),
      ("filtered_sweep",H("~/frus-ner-raw-filtered"),"detected"),("nltagger",H("~/frus-ner-raw-control"),"detected"),
      ("filtered_nltagger",H("~/frus-ner-raw-control-filtered"),"detected")]
TEXT=H("~/frus-semantic-raw/text")
def jl(p):
    op=gzip.open if p.endswith(".gz") else open
    with op(p,"rt",encoding="utf-8") as f: return [json.loads(l) for l in f if l.strip()]
def layer(store,layer,vol):
    for suf in (".jsonl",".jsonl.gz"):
        p=os.path.join(store,layer,vol+suf)
        if os.path.exists(p): return jl(p)
    raise SystemExit("missing %s/%s/%s"%(store,layer,vol))
# ---- gold
gold=collections.defaultdict(list); band={}; docs=[]
for r in jl(os.path.join(M,"m2a-ground-truth-documents.jsonl")):
    docs.append((r["v"],r["d"])); band[(r["v"],r["d"])]=r["band"]; gold[(r["v"],r["d"])]
marks=collections.Counter(r["mark"] for r in jl(os.path.join(M,"m2a-ground-truth-documents.jsonl")))
for r in jl(os.path.join(M,"m2a-ground-truth.jsonl")):
    gold[(r["v"],r["d"])].append((r["s"],r["e"],r["n"],r["seeded"]))
docs=sorted(set(docs)); NG=sum(len(v) for v in gold.values())
print("gold docs",len(docs),"mentions",NG,"docs with 0 mentions",sum(1 for k in docs if not gold[k]),"marks",dict(marks))
bd=collections.Counter(band[k] for k in docs); bm=collections.Counter()
for k in docs: bm[band[k]]+=len(gold[k])
print("band docs",dict(sorted(bd.items())),"band mentions",dict(sorted(bm.items())))
SEG1={"frus1864p2","frus1865p1","frus1866p3","frus1872p2v5"}
print("gold docs in seg1 vols",sum(1 for k in docs if k[0] in SEG1),"mentions",sum(len(gold[k]) for k in docs if k[0] in SEG1),
      "| 1861-1899 docs",bd["1861-1899"],"mentions",bm["1861-1899"])
print("seeded gold spans",sum(1 for v in gold.values() for x in v if x[3]))
# verify gold against R-0 text
texts={}
for vol in sorted({v for v,_ in docs}):
    texts[vol]={r["d"]:r["t"] for r in layer(TEXT,"",vol) } if False else None
def vtext(vol):
    if texts.get(vol) is None:
        p=os.path.join(TEXT,vol+".jsonl.gz"); texts[vol]={r["d"]:r["t"] for r in jl(p)}
    return texts[vol]
bad=0
for k,spans in gold.items():
    t=vtext(k[0])[k[1]]
    for s,e,n,_ in spans:
        if t[s:e]!=n: bad+=1
print("gold spans not matching R-0 text:",bad)
# ---- predictions
def maxmatch(g,p):
    """maximum bipartite matching size over overlap graph, iterative augmenting paths (not Kuhn recursion)."""
    adj=[[j for j,(ps,pe,_) in enumerate(p) if min(ge,pe)-max(gs,ps)>0] for gs,ge,_ in g]
    mp=[-1]*len(p); mg=[-1]*len(g)
    def aug(i):
        # iterative DFS
        stack=[(i,iter(adj[i]))]; seen=set(); path={}
        while stack:
            u,it=stack[-1]
            for j in it:
                if j in seen: continue
                seen.add(j); path[j]=u
                if mp[j]==-1:
                    # flip along path
                    while True:
                        u2=path[j]; prev=mg[u2]; mg[u2]=j; mp[j]=u2
                        if prev==-1: break
                        j=prev
                    return True
                stack.append((mp[j],iter(adj[mp[j]])))
                break
            else:
                stack.pop()
        return False
    return sum(1 for i in range(len(g)) if aug(i))
def dedupe(rows,doc):
    return sorted({(r["s"],r["e"],r["n"]) for r in rows if r["d"]==doc})
preds={}
for name,store,lay in ARMS:
    per={}
    for vol in sorted({v for v,_ in docs}):
        rows=layer(store,lay,vol)
        if lay=="detected":
            h=json.load(open(os.path.join(store,lay,vol+".head.json")))
            assert h["sampled"] is False and h.get("docs_scanned")==h.get("docs_in_volume"), (name,vol)
        for v,d in docs:
            if v!=vol: continue
            sp=dedupe(rows,d)
            t=vtext(v)[d]
            for s,e,n in sp: assert t[s:e]==n,(name,v,d,s,e,n)
            per[(v,d)]=sp
    preds[name]=per
def score_doc(g,p):
    gs={(s,e) for s,e,_,_ in g}; strict=len({(s,e) for s,e,_ in p}&gs)
    return strict, maxmatch([(s,e,n) for s,e,n,_ in g],p), len(p), len(g)
def prf(h,p,g):
    P=h/p if p else 0.0; R=h/g if g else 0.0; F=2*P*R/(P+R) if P+R else 0.0; return P,R,F
perdoc={name:{k:score_doc(gold[k],preds[name][k]) for k in docs} for name in preds}
def agg(name,keys):
    s=r=p=g=0
    for k in keys: a,b,c,d=perdoc[name][k]; s+=a;r+=b;p+=c;g+=d
    return prf(s,p,g),prf(r,p,g),(s,r,p,g)
print("\n== OVERALL (64 docs) strict P/R/F1 | relaxed P/R/F1 | strict hits, relaxed hits, predicted, gold")
for name in preds:
    (sp,sr,sf),(rp,rr,rf),c=agg(name,docs)
    print("%-18s %.3f/%.3f/%.3f | %.3f/%.3f/%.3f | %s"%(name,sp,sr,sf,rp,rr,rf,c))
print("\n== BY BAND strict F1 / relaxed F1 / strict P / relaxed P / relaxed R")
bands=sorted(set(band.values()))
for name in preds:
    row=[]
    for b in bands:
        keys=[k for k in docs if band[k]==b]; (sp,sr,sf),(rp,rr,rf),_=agg(name,keys); row.append("%s %.3f/%.3f/%.3f/%.3f/%.3f"%(b,sf,rf,sp,rp,rr))
    print("%-18s %s"%(name," | ".join(row)))
# stopping rule on raw arms
def gap(a,b,keys,metric):  # F1(a)-F1(b) in points
    ia=0 if metric=="strict" else 1
    return 100*(agg(a,keys)[ia][2]-agg(b,keys)[ia][2])
def rule_met(keys):
    g=gap("nltagger","raw_sweep",keys,"strict")
    if abs(g)<10: return False
    w=1 if g>0 else -1
    for b in bands:
        kb=[k for k in keys if band[k]==b]
        gb=gap("nltagger","raw_sweep",kb,"strict")
        if gb==0 or (1 if gb>0 else -1)!=w: return False
    return True
print("\nNLTagger - raw sweep strict gap (points): %.1f"%gap("nltagger","raw_sweep",docs,"strict"),"rule met:",rule_met(docs))
print("band strict winners raw (nlt-sweep):",{b:round(gap("nltagger","raw_sweep",[k for k in docs if band[k]==b],"strict"),1) for b in bands})
print("band relaxed winners raw (nlt-sweep):",{b:round(gap("nltagger","raw_sweep",[k for k in docs if band[k]==b],"relaxed"),1) for b in bands})
print("band relaxed (nlt-filtered sweep):",{b:round(gap("nltagger","filtered_sweep",[k for k in docs if band[k]==b],"relaxed"),1) for b in bands})
# bootstrap
rng=random.Random(20260912); bykey={b:[k for k in docs if band[k]==b] for b in bands}
def resample():
    out=[]
    for b in bands: out+= [rng.choice(bykey[b]) for _ in bykey[b]]
    return out
N=10000; samples=[resample() for _ in range(N)]
def ci(a,b,metric):
    vals=sorted(gap(a,b,s,metric) for s in samples); return vals[int(0.025*N)],vals[int(0.975*N)-1]
print("\n== band-stratified bootstrap 95%% intervals (N=%d, seed 20260912)"%N)
for a,b,m in (("nltagger","filtered_sweep","strict"),("nltagger","raw_sweep","strict"),("nltagger","filtered_sweep","relaxed"),("nltagger","raw_sweep","relaxed"),("filtered_sweep","raw_sweep","strict"),("filtered_sweep","raw_sweep","relaxed")):
    lo,hi=ci(a,b,m); print("%s - %s %s: point %.1f  CI %.1f to %.1f"%(a,b,m,gap(a,b,docs,m),lo,hi))
print("stopping rule met in bootstrap: %.1f%%"%(100*sum(rule_met(s) for s in samples)/N))
# simulate 8 unkeyed: 2 in 1900-1929, 3 in 1930-1945, 3 in 1946-
extra={"1900-1929":2,"1930-1945":3,"1946-":3}; met=0; gaps=[]
for _ in range(N):
    s=list(docs)
    for b,n in extra.items(): s+=[rng.choice(bykey[b]) for _ in range(n)]
    met+=rule_met(s); gaps.append(gap("nltagger","raw_sweep",s,"strict"))
print("8-unkeyed simulation: rule met %d of %d; strict gap range %.1f to %.1f"%(met,N,min(gaps),max(gaps)))
# unions with editor layer (relaxed)
def union_score(det, mode):
    s=r=p=g=0
    for k in docs:
        e=preds["editor"][k]; d=preds[det][k]
        if mode=="naive": u=sorted(set(e)|set(d))
        else: u=sorted(set(d)|{x for x in e if not any(min(x[1],y[1])-max(x[0],y[0])>0 for y in d)})
        a=score_doc(gold[k],u); s+=a[0]; r+=a[1]; p+=a[2]; g+=a[3]
    return prf(r,p,g), prf(s,p,g)
print("\n== unions (relaxed P/R/F1 ; strict P/R/F1)")
for det in ("filtered_nltagger","nltagger","filtered_sweep"):
    for mode in ("naive","nonoverlap"):
        (rp,rr,rf),(sp,sr,sf)=union_score(det,mode); print("editor+%s [%s] relaxed %.3f/%.3f/%.3f strict %.3f/%.3f/%.3f"%(det,mode,rp,rr,rf,sp,sr,sf))
# stripped titles/possessives strict (approximate rule: leading honorific tokens + trailing possessive)
TITLES=r"(Mr|Mrs|Messrs|Ms|Dr|Hon|Sir|Se[ñn]or|Se[ñn]ora|Mme|Mlle|Monsieur|Madame|Herr|General|Gen|Lord|Lady|Count|Countess|Baron|Prince|Princess|President|Secretary|Colonel|Col|Captain|Capt|Major|Maj|Admiral|Commodore|Lieutenant|Lieut|Governor|Gov|Judge|Senator|Rev|Reverend|Earl|Marquis|Duke|Ambassador|Minister|Consul|King|Queen|Emperor|Citizen|Charg[ée]|Generalissimo|Marshal|Commander|Professor|Prof|Bishop|Archbishop|Cardinal|Don|Sheik|Sheikh|Emir|Pasha|Bey|Viscount|Chancellor|Commissioner|Excellency|Attorney|Comrade|Vice|Under|Assistant|Deputy|Acting|His|Her|the|The|de|d'|of)"
LEAD=re.compile(r"^(?:%s\.?\s+)+"%TITLES); TRAIL=re.compile(r"(?:['’]s|['’])$")
def strip_span(s,e,n):
    m=LEAD.match(n)
    if m and m.end()<len(n): s+=m.end(); n=n[m.end():]
    m=TRAIL.search(n)
    if m and m.start()>0: e-=len(n)-m.start(); n=n[:m.start()]
    return (s,e,n)
print("\n== titles/possessives stripped, strict F1 (APPROXIMATE rule, mine)")
for name in ("raw_sweep","filtered_sweep","nltagger","filtered_nltagger"):
    s=p=g=0
    for k in docs:
        gs={strip_span(a,b,n)[:2] for a,b,n,_ in gold[k]}; ps={strip_span(a,b,n)[:2] for a,b,n in preds[name][k]}
        s+=len(gs&ps); p+=len(ps); g+=len(gs)
    print("%-18s strict P/R/F1 %.3f/%.3f/%.3f"%((name,)+prf(s,p,g)))
# editor baseline: 88 spans, 53 exact
e=agg("editor",docs); print("\neditor baseline counts (strict hits, relaxed hits, predicted, gold):",e[2])
# FP sample check: first 40 in sorted order
fp=[]
for k in docs:
    g=[(s,e,n) for s,e,n,_ in gold[k]]; p=preds["raw_sweep"][k]
    # unmatched by my matching: rebuild via matching indices — approximate: predictions with no overlap to any gold
    for s,e2,n in p:
        if not any(min(e2,ge)-max(s,gs)>0 for gs,ge,_ in g) and len(fp)<40: fp.append((k[0],n))
print("raw sweep zero-overlap FPs (first 40 sorted): vols",collections.Counter(v for v,_ in fp))
