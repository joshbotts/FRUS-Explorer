#!/usr/bin/env python3
"""VERIFY 'exactly 1 cross-volume persName link and 2 dangling in the list volumes': every persName corresp/ref in the
286 non-scope volumes (ElementTree iterparse, start events), target parsed, resolved against ALL volumes' persName
xml:id sets from v-scan.json. Also names the manifest volume(s) absent from the crosswalk. Read-only."""
import json, os, collections, multiprocessing as mp
import xml.etree.ElementTree as ET
D=os.path.dirname(os.path.abspath(__file__)); V="/Users/jbotts/Development/frus/volumes"
REPO="/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
TEI="{http://www.tei-c.org/ns/1.0}"; PERS=TEI+"persName"; DIV=TEI+"div"
def targets(v):
    c=collections.Counter(); depth=0
    for ev,el in ET.iterparse(f"{V}/{v}.xml",events=("start","end")):
        if el.tag==DIV and el.get("type")=="document": depth+= 1 if ev=="start" else -1
        if ev=="start" and el.tag==PERS:
            l=el.get("corresp") or el.get("ref")
            if l:
                f=l.split()[0]
                if "#" in f: pre,tid=f.split("#",1); tv=(pre[:-4] if pre.endswith(".xml") else pre) or v
                else: tv,tid=v,f
                c[(tv,tid,depth>0)]+=1
        if ev=="end" and depth==0: el.clear()
    return v,c
if __name__=="__main__":
    S=json.load(open(D+"/v-scan.json"))["volumes"]; ids={v:set(x["persName_xml_ids"]) for v,x in S.items()}
    vols=[v for v,x in S.items() if not x["scope"]]
    out={"nonscope_volumes":len(vols),"cross":[],"dangling":[],"total":0}
    with mp.Pool(8) as p:
        for v,c in p.imap_unordered(targets,vols):
            for (tv,tid,indoc),n in c.items():
                out["total"]+=n
                if tv!=v: out["cross"].append([v,tv,tid,indoc,n,tid in ids.get(tv,())])
                if tid not in ids.get(tv,()): out["dangling"].append([v,tv,tid,indoc,n])
    cw=json.load(open(REPO+"/FRUSExplorer/Resources/person-authority-index.json"))["crosswalk"]
    out["nonscope_not_in_crosswalk"]=sorted(set(vols)-set(cw)); out["crosswalk_not_nonscope"]=sorted(set(cw)-set(vols))
    json.dump(out,open(D+"/v-crossvol.json","w"),indent=1); print(json.dumps(out,indent=1)[:3000])
