"""Independent re-score of the M2a gold against the six arms (SC-5..SC-11).
Own reader, own maximum-matching (Hopcroft-Karp-style BFS/DFS, different from the scorer's Kuhn order),
own band-stratified bootstrap, stopping-rule simulation, unions, and an approximate stripped-titles check."""
import json, gzip, os, glob, random, re, sys
from collections import defaultdict, deque
M2A="/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-m2a"
SWEEP="/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-ner-raw"
H=os.path.expanduser
ARMS=[("editor",SWEEP,"marked"),("raw_sweep",SWEEP,"detected"),("boundary",H("~/frus-ner-raw-filtered-boundary"),"detected"),
      ("filtered_sweep",H("~/frus-ner-raw-filtered"),"detected"),("control",H("~/frus-ner-raw-control"),"detected"),
      ("filtered_control",H("~/frus-ner-raw-control-filtered"),"detected")]
SEG1={"frus1864p2","frus1865p1","frus1866p3","frus1872p2v5"}
def rows(path):
    op=gzip.open if path.endswith(".gz") else open
    with op(path,"rt",encoding="utf-8") as f: return [json.loads(l) for l in f if l.strip()]
# gold
gold=defaultdict(list); band={}
for r in rows(os.path.join(M2A,"m2a-ground-truth.jsonl")):
    gold[(r["v"],r["d"])].append((r["s"],r["e"],r["n"])); band[(r["v"],r["d"])]=r["band"]
docs=rows(os.path.join(M2A,"m2a-ground-truth-documents.jsonl"))
print("doc-list rows",len(docs),"keys",sorted(docs[0].keys()))
for r in docs:
    k=(r["v"],r["d"]); gold.setdefault(k,[]); band[k]=r["band"]
    assert r["mentions"]==len(gold[k]),(k,r["mentions"],len(gold[k]))
keys=sorted(gold); nm=sum(len(v) for v in gold.values())
print("gold docs",len(keys),"mentions",nm,"zero-mention docs",[k for k in keys if not gold[k]])
print("marks by value:",{m:sum(1 for r in docs if r.get("mark")==m) for m in set(r.get("mark") for r in docs)})
bd=defaultdict(lambda:[0,0])
for k in keys: bd[band[k]][0]+=1; bd[band[k]][1]+=len(gold[k])
print("by band docs/mentions:",dict(bd))
s1=[k for k in keys if k[0] in SEG1]
print("segment-1 gold docs",len(s1),"mentions",sum(len(gold[k]) for k in s1),"of 1861-1899 docs",bd["1861-1899"][0],"mentions",bd["1861-1899"][1])
print("gold volumes",len({k[0] for k in keys}), "docs per volume min/max", min(sum(1 for k in keys if k[0]==v) for v in {k[0] for k in keys}), max(sum(1 for k in keys if k[0]==v) for v in {k[0] for k in keys}))
# predictions
def load_arm(store,layer):
    out={}
    vols={k[0] for k in keys}
    for v in sorted(vols):
        p=[q for q in (os.path.join(store,layer,v+".jsonl"),os.path.join(store,layer,v+".jsonl.gz")) if os.path.exists(q)]
        assert len(p)==1,(store,v,p)
        bydoc=defaultdict(set)
        for r in rows(p[0]): bydoc[r["d"]].add((r["s"],r["e"],r["n"]))
        for k in keys:
            if k[0]==v: out[k]=sorted(bydoc.get(k[1],set()))
    return out
preds={n:load_arm(s,l) for n,s,l in ARMS}
def maxmatch(g,p):
    """Hopcroft–Karp over overlap graph; returns (matched_g_set, matched_p_set)."""
    adj=[[j for j,(ps,pe,_) in enumerate(p) if min(ge,pe)-max(gs,ps)>0] for gs,ge,_ in g]
    mg=[-1]*len(g); mp=[-1]*len(p)
    def bfs():
        dist={}; q=deque()
        for i in range(len(g)):
            if mg[i]==-1: dist[i]=0; q.append(i)
        found=False
        while q:
            i=q.popleft()
            for j in adj[i]:
                k=mp[j]
                if k==-1: found=True
                elif k not in dist: dist[k]=dist[i]+1; q.append(k)
        return found,dist
    def dfs(i,dist):
        for j in adj[i]:
            k=mp[j]
            if k==-1 or (dist.get(k)==dist[i]+1 and dfs(k,dist)):
                mg[i]=j; mp[j]=i; return True
        dist[i]=float("inf"); return False
    while True:
        f,dist=bfs()
        if not f: break
        for i in range(len(g)):
            if mg[i]==-1: dfs(i,dist)
    return {i for i in range(len(g)) if mg[i]!=-1},{j for j in range(len(p)) if mp[j]!=-1}
def perdoc(g,p):
    strict=len({(s,e) for s,e,_ in g}&{(s,e) for s,e,_ in p})
    mgs,_=maxmatch(g,p)
    return strict,len(mgs),len(p),len(g)
def prf(h,pc,gc):
    P=h/pc if pc else 0.0; R=h/gc if gc else 0.0; F=2*P*R/(P+R) if P+R else 0.0
    return P,R,F
PD={n:{k:perdoc(gold[k],preds[n][k]) for k in keys} for n,_,_ in ARMS}
def agg(n,ks):
    S=R=PC=G=0
    for k in ks:
        s,r,pc,g=PD[n][k]; S+=s;R+=r;PC+=pc;G+=g
    return prf(S,PC,G),prf(R,PC,G),PC,S,R
print("\n== OVERALL (64 docs)")
for n,_,_ in ARMS:
    (sp,sr,sf),(rp,rr,rf),pc,sh,rh=agg(n,keys)
    print("%-17s strict %.3f/%.3f/%.3f relaxed %.3f/%.3f/%.3f pred %d strictHits %d relaxedHits %d"%(n,sp,sr,sf,rp,rr,rf,pc,sh,rh))
print("\n== BY BAND F1 (strict | relaxed), and precision")
for b in sorted(bd):
    ks=[k for k in keys if band[k]==b]
    line=[]
    for n,_,_ in ARMS:
        (sp,sr,sf),(rp,rr,rf),pc,_,_=agg(n,ks); line.append("%s S%.3f(P%.3f) R%.3f(P%.3f)"%(n,sf,sp,rf,rp))
    print(b, " | ".join(line))
# bootstrap
random.seed(20260912)
bands=sorted(bd); bk={b:[k for k in keys if band[k]==b] for b in bands}
def resample():
    out=[]
    for b in bands: out+= [random.choice(bk[b]) for _ in bk[b]]
    return out
def f1s(ks):
    return {n:(agg(n,ks)[0][2],agg(n,ks)[1][2]) for n,_,_ in ARMS}
def rule_met(ks):
    # raw arms only: |strict gap|>=0.10 and same winner in every band (strict)
    f=f1s(ks); gap=f["control"][0]-f["raw_sweep"][0]
    if abs(gap)<0.10: return False
    w=gap>0
    for b in bands:
        kb=[k for k in ks if band[k]==b]
        fb=agg("control",kb)[0][2]-agg("raw_sweep",kb)[0][2]
        if (fb>0)!=w or fb==0: return False
    return True
N=int(sys.argv[1]) if len(sys.argv)>1 else 10000
gaps=defaultdict(list); met=0
for i in range(N):
    ks=resample(); f=f1s(ks)
    gaps["ctrl-filt strict"].append(f["control"][0]-f["filtered_sweep"][0])
    gaps["ctrl-raw strict"].append(f["control"][0]-f["raw_sweep"][0])
    gaps["ctrl-filt relaxed"].append(f["control"][1]-f["filtered_sweep"][1])
    gaps["ctrl-raw relaxed"].append(f["control"][1]-f["raw_sweep"][1])
    gaps["filt-raw strict"].append(f["filtered_sweep"][0]-f["raw_sweep"][0])
    gaps["filt-raw relaxed"].append(f["filtered_sweep"][1]-f["raw_sweep"][1])
    if rule_met(ks): met+=1
f=f1s(keys)
print("\n== POINT GAPS: ctrl-filt strict %.1f relaxed %.1f; ctrl-raw strict %.1f relaxed %.1f; filt-raw strict %.1f relaxed %.1f"%(
 100*(f["control"][0]-f["filtered_sweep"][0]),100*(f["control"][1]-f["filtered_sweep"][1]),100*(f["control"][0]-f["raw_sweep"][0]),100*(f["control"][1]-f["raw_sweep"][1]),100*(f["filtered_sweep"][0]-f["raw_sweep"][0]),100*(f["filtered_sweep"][1]-f["raw_sweep"][1])))
print("== BOOTSTRAP %d band-stratified resamples, 95%% percentile intervals (points)"%N)
for k,v in gaps.items():
    v=sorted(v); print("  %-20s %.1f to %.1f"%(k,100*v[int(0.025*N)],100*v[int(0.975*N)-1]))
print("  stopping rule met in %.1f%% of resamples (point estimate met: %s)"%(100*met/N,rule_met(keys)))
# simulate 8 unkeyed: 2 in 1900-1929, 3 in 1930-1945, 3 in 1946-
add={"1900-1929":2,"1930-1945":3,"1946-":3}; met2=0; g2=[]
for i in range(N):
    ks=list(keys)
    for b,c in add.items(): ks+=[random.choice(bk[b]) for _ in range(c)]
    ff=f1s(ks); g2.append(ff["control"][0]-ff["raw_sweep"][0])
    if rule_met(ks): met2+=1
print("== SIM 8 unkeyed (%d draws): rule met %d; strict gap range %.1f to %.1f"%(N,met2,100*min(g2),100*max(g2)))
# unions (relaxed)
def union_eval(a,b,mode):
    S=R=PC=G=0
    for k in keys:
        if mode=="set": p=sorted(set(preds[a][k])|set(preds[b][k]))
        else: # keep editor spans; add detector spans that overlap no editor span
            ed=preds[a][k]; p=list(ed)
            for s,e,n in preds[b][k]:
                if not any(min(e,ee)-max(s,ss)>0 for ss,ee,_ in ed): p.append((s,e,n))
            p=sorted(set(p))
        s,r,pc,g=perdoc(gold[k],p); S+=s;R+=r;PC+=pc;G+=g
    return prf(R,PC,G),prf(S,PC,G)
for b in ("filtered_control","filtered_sweep","control"):
    for mode in ("set","overlap-dedupe"):
        (rp,rr,rf),(sp,sr,sf)=union_eval("editor",b,mode)
        print("UNION editor+%s [%s]: relaxed P %.3f R %.3f F1 %.3f | strict F1 %.3f"%(b,mode,rp,rr,rf,sf))
# approximate stripped-titles check (rule is not specified in the record; this is my approximation)
TITLE=re.compile(r"^(?:(?:Mr|Mrs|Ms|Messrs|Dr|Hon|Right Hon|Sir|Lord|Earl|Lady|Señor|Senor|Sr|Mme|Monsieur|M|Herr|General|Gen|Admiral|Adm|Colonel|Col|Major|Maj|Captain|Capt|Lieutenant|Lieut|Lt|Commander|Marshal|Judge|Governor|Gov|President|Pres|Secretary|Ambassador|Minister|Count|Baron|Prince|Princess|King|Queen|Duke|Bishop|Archbishop|Cardinal|Reverend|Rev|Father|Consul|Commodore|Chargé|Citizen|Mayor|Acting Rear-Admiral|Rear-Admiral|Generalissimo|Marquis|Viscount|Don|Doña|Professor|Prof)\.?\s+)+",re.I)
def norm(s,e,n):
    m=TITLE.match(n); 
    if m and m.end()<len(n): s+=m.end(); n=n[m.end():]
    m2=re.search(r"(’s|'s|’|')$",n)
    if m2: e-=len(m2.group(0)); n=n[:m2.start()]
    return (s,e,n)
for n in ("filtered_sweep","control","raw_sweep"):
    S=PC=G=0
    for k in keys:
        g={(s,e) for s,e,_ in map(lambda t:norm(*t),gold[k])}; p={(s,e) for s,e,_ in map(lambda t:norm(*t),preds[n][k])}
        S+=len(g&p); PC+=len(p); G+=len(g)
    print("STRIPPED-TITLES (approx rule) %s strict F1 %.3f"%(n,prf(S,PC,G)[2]))
