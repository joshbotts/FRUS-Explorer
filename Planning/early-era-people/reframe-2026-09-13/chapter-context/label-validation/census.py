#!/usr/bin/env python3
"""Census: per manifest volume, from/to persName count, how many carry corresp/ref to a local
persName xml:id, coverage years. Read-only over TEI + manifest."""
import re, json, sys
V="/Users/jbotts/Development/frus/volumes"
MAN="/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5/FRUSExplorer/Resources/manifest.json"
man=json.load(open(MAN)); vols=man["volumes"] if isinstance(man,dict) else man
FT=re.compile(r'<persName\b([^>]*)\btype="(from|to)"([^>]*)>|<persName\b([^>]*)>')
out=[]
for v in vols:
    vid=v["volumeId"]; lo=int(v["dateRange"]["earliest"][:4]); hi=int(v["dateRange"]["latest"][:4])
    if lo>1925: continue
    t=open(f"{V}/{vid}.xml",encoding="utf-8",errors="replace").read()
    ids=set(re.findall(r'<persName\b[^>]*xml:id="([^"]+)"',t))
    ft=0; linked=0
    for m in re.finditer(r'<persName\b([^>]*)>',t):
        a=m.group(1)
        ty=re.search(r'type="(from|to)"',a)
        if not ty: continue
        ft+=1
        c=re.search(r'(?:corresp|ref)="#?([^"]+)"',a)
        if c and c.group(1).lstrip('#') in ids: linked+=1
    out.append((vid,lo,hi,len(ids),ft,linked))
for r in out:
    if r[3] or r[5]: print(*r,sep="\t")
print("volumes<=1925:",len(out),"with list:",sum(1 for r in out if r[3]),"with linked from/to:",sum(1 for r in out if r[5]),file=sys.stderr)
json.dump(out,open("census.json","w"))
