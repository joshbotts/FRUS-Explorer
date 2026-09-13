#!/usr/bin/env python3
"""Stage-1 pilot sizing (read-only): gold-doc chars from R-0, candidate counts per arm, Qwen chars/token fit."""
import json, os, sys, glob, collections
REPO="/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
sys.path.insert(0, REPO+"/tools/semantic-harvest")
import ner_store as st
STUDIO="/Users/jbotts/FRUS Explorer Development Files from Mac Studio"
GOLD=STUDIO+"/frus-m2a/m2a-ground-truth.jsonl"
DOCS=STUDIO+"/frus-m2a/m2a-ground-truth-documents.jsonl"
TEXT=os.path.expanduser("~/frus-semantic-raw/text")
H=os.path.expanduser("~")
arms={"editor":(H+"/frus-ner-raw","marked"),
      "control_raw":(H+"/frus-ner-raw-control","detected"),
      "control_filtered":(H+"/frus-ner-raw-control-filtered","detected"),
      "sweep_filtered":(H+"/frus-ner-raw-filtered","detected"),
      "sweep_raw":(STUDIO+"/frus-ner-raw","detected")}
docs=[json.loads(l) for l in open(DOCS)]
gold=collections.Counter()
for l in open(GOLD):
    r=json.loads(l); gold[(r["v"],r["d"])]+=1
out={"documents":len(docs),"gold_mentions":sum(gold.values())}
byvol=collections.defaultdict(list)
for d in docs: byvol[d["v"]].append(d)
chars={}; cand={a:{} for a in arms}; union3={}
for v,ds in sorted(byvol.items()):
    texts=st.volume_text(TEXT,v)
    layers={a:st.spans_by_document(st.volume_layer(p,layer,v)) for a,(p,layer) in arms.items()}
    for d in ds:
        k=(v,d["d"]); t=texts[d["d"]]; chars[k]=len(t)
        for a in arms: cand[a][k]=len(layers[a].get(d["d"],[]))
        u=set()
        for a in ("editor","control_filtered","sweep_filtered"):
            u |= {(s,e) for s,e,_ in layers[a].get(d["d"],[])}
        union3[k]=len(u)
band=collections.defaultdict(lambda:{"docs":0,"chars":0,"gold":0,"pre1910":0})
for d in docs:
    k=(d["v"],d["d"]); b=band[d["band"]]; b["docs"]+=1; b["chars"]+=chars[k]; b["gold"]+=gold[k]
    yr=int(st.VOLUME_YEAR.search(d["v"]).group(1))
    if yr<1910: b["pre1910"]+=1
out["r0_chars_total"]=sum(chars.values())
out["r0_chars_min_median_max"]=[min(chars.values()),sorted(chars.values())[len(chars)//2],max(chars.values())]
out["by_band"]=band
out["pre1910_docs"]=sum(1 for d in docs if int(st.VOLUME_YEAR.search(d["v"]).group(1))<1910)
out["candidate_spans_total_by_arm"]={a:sum(c.values()) for a,c in cand.items()}
out["three_way_union_distinct_offsets_total"]=sum(union3.values())
out["three_way_union_max_per_doc"]=max(union3.values())
# Qwen tokenizer chars/token over the sweep heads: prompt_tokens = a*chunks + b*chunk_chars
rows=[]
for hp in glob.glob(STUDIO+"/frus-ner-raw/detected/*.head.json"):
    h=json.load(open(hp))
    if h.get("prompt_tokens") and h.get("chunks"):
        # chunk chars ~ chars + overlap*(chunks - docs)
        cc=h["chars_scanned"]+h["overlap_chars"]*max(0,h["chunks"]-h["docs_scanned"])
        rows.append((h["chunks"],cc,h["prompt_tokens"],h["chars_scanned"]))
n=len(rows)
Sxx=sum(c*c for c,_,_,_ in rows); Sxy=sum(c*x for c,x,_,_ in rows); Syy=sum(x*x for _,x,_,_ in rows)
Sxz=sum(c*z for c,_,z,_ in rows); Syz=sum(x*z for _,x,z,_ in rows)
det=Sxx*Syy-Sxy*Sxy
a=(Sxz*Syy-Syz*Sxy)/det; b=(Syz*Sxx-Sxz*Sxy)/det
out["qwen_fit"]={"heads":n,"tokens_per_chunk_overhead":round(a,1),"tokens_per_char":round(b,5),
  "chars_per_token":round(1/b,3),"sum_prompt_tokens":sum(z for *_,z,_ in rows),
  "sum_chunks":sum(c for c,*_ in rows),"sum_chars_scanned":sum(r[3] for r in rows)}
json.dump(out,open(os.path.join(os.path.dirname(os.path.abspath(__file__)),"stage1_sizing.json"),"w"),indent=1,default=dict)
print(json.dumps(out,indent=1,default=dict))
