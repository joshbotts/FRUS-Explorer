# Verifier check for read-cost RC-1/RC-7: score the M2a gold at (document, name-string) grain,
# the grain person_mentions actually has, for the arms the report ranks. 64 docs / 406 mentions.
import json, gzip, os, glob, collections
H=os.path.expanduser
M2A='/Users/jbotts/FRUS Explorer Development Files from Mac Studio/frus-m2a'
gold=[json.loads(l) for l in open(M2A+'/m2a-ground-truth.jsonl') if l.strip()]
docs=[json.loads(l) for l in open(M2A+'/m2a-ground-truth-documents.jsonl') if l.strip()]
print('gold rows',len(gold),'docs',len(docs),'fields',sorted(gold[0].keys()))
doc_keys={(d['v'],d['d']) for d in docs}
def norm(n): return ' '.join(n.split()).lower()
def rows(pattern):
    for p in glob.glob(pattern):
        f=gzip.open(p,'rt',encoding='utf-8') if p.endswith('.gz') else open(p,encoding='utf-8')
        with f:
            for line in f:
                if line.strip(): yield json.loads(line)
vols=sorted({v for v,_ in doc_keys})
stores={
 'marked (editor)':'~/frus-ner-raw/marked/{v}.jsonl.gz',
 'control filtered':'~/frus-ner-raw-control-filtered/detected/{v}.jsonl*',
 'sweep filtered':'~/frus-ner-raw-filtered/detected/{v}.jsonl*',
 'control raw':'~/frus-ner-raw-control/detected/{v}.jsonl*',
}
pred={k:set() for k in stores}
for k,pat in stores.items():
    for v in vols:
        for r in rows(H(pat.format(v=v))):
            if (v,r['d']) in doc_keys: pred[k].add((v,r['d'],norm(r['n'])))
pred['editor + control filtered']=pred['marked (editor)']|pred['control filtered']
pred['editor + sweep filtered']=pred['marked (editor)']|pred['sweep filtered']
G={(g['v'],g['d'],norm(g['n'])) for g in gold}
print('gold distinct (doc,name) pairs',len(G),'from',len(gold),'mentions')
def toks(s): return set(t.strip('.,;:') for t in s.split())
def prf(tp,np_,ng):
    P=tp/np_ if np_ else 0; R=tp/ng if ng else 0; F=2*P*R/(P+R) if P+R else 0
    return round(P,3),round(R,3),round(F,3)
out={}
for k,S in pred.items():
    # strict: exact normalised string in same doc
    tp=len(S&G)
    strict=prf(tp,len(S),len(G))
    # relaxed: a predicted pair counts if some gold string in that doc shares a token (>=3 chars) or contains/is contained
    gold_by_doc=collections.defaultdict(list); 
    for v,d,n in G: gold_by_doc[(v,d)].append(n)
    pred_by_doc=collections.defaultdict(list)
    for v,d,n in S: pred_by_doc[(v,d)].append(n)
    def match(a,b): 
        return a in b or b in a or bool({t for t in toks(a) if len(t)>=3}&{t for t in toks(b) if len(t)>=3})
    ptp=sum(1 for (v,d,n) in S if any(match(n,g) for g in gold_by_doc[(v,d)]))
    gtp=sum(1 for (v,d,n) in G if any(match(n,p) for p in pred_by_doc[(v,d)]))
    relP=ptp/len(S) if S else 0; relR=gtp/len(G) if G else 0; relF=2*relP*relR/(relP+relR) if relP+relR else 0
    out[k]=dict(pairs=len(S),strict=strict,relaxed=(round(relP,3),round(relR,3),round(relF,3)))
    print(f"{k:28s} pairs={len(S):5d}  strict P/R/F1={strict}  relaxed P/R/F1={(round(relP,3),round(relR,3),round(relF,3))}")
json.dump(out,open('pair-grain-output.json','w'),indent=1)
