#!/usr/bin/env python3
"""Tasks 1+2, read-only over the TEI (/Users/jbotts/Development/frus/volumes) for every manifest volume.
Pass 1: persName xml:id set per volume.
Pass 2: every <persName> element. Records
  - attribute-name census (scope vs list volumes);
  - every persName carrying corresp= or ref= (any location): source volume, in document div or not, type, target
    volume (prefix before '#', else the source volume), target id, whether the target id is a persName xml:id in
    the target volume;
  - every from/to persName inside a <div type="document"> (innermost), with: document id, doc year
    (frus:doc-dateTime-min), whether it lies inside the document's OWN first <head>, the head text (notes removed),
    the name text, the link (if any) and its resolution.
Document extents come from a div open/close stack, not from splitting at the next document, so back matter is not
attributed to the last document.
Writes: links.jsonl (every corresp/ref persName), fromto.jsonl (every from/to persName in a document), census JSON."""
import re, json, bisect, collections, sys, time
V="/Users/jbotts/Development/frus/volumes"
REPO="/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
man=json.load(open(REPO+"/FRUSExplorer/Resources/manifest.json")); man=man["volumes"] if isinstance(man,dict) else man
vols=[v["volumeId"] for v in man]
SCOPE=set(json.load(open("/Users/jbotts/frus-ner-raw/scope.json"))["volumes"])
PERSID=re.compile(r'<persName\b[^>]*\bxml:id="([^"]+)"')
PERS=re.compile(r'<persName\b([^>]*)>(.*?)</persName>',re.S)
PERS_SELF=re.compile(r'<persName\b([^>]*)/>')
ATTR=re.compile(r'([\w:.-]+)\s*=\s*"([^"]*)"')
DIVTOK=re.compile(r'<div\b([^>]*)>|</div>')
NOTE=re.compile(r'<note\b.*?</note>',re.S)
def txt(s): return " ".join(re.sub(r"<[^>]+>","",s).split())
t0=time.time()
ids={}
texts={}
for v in vols:
    t=open(f"{V}/{v}.xml",encoding="utf-8",errors="replace").read()
    ids[v]=set(PERSID.findall(t))
print("pass1",round(time.time()-t0,1),"s",file=sys.stderr)
attr_census={"scope":collections.Counter(),"list":collections.Counter()}
lk=open("links.jsonl","w"); ft=open("fromto.jsonl","w")
counts=collections.Counter()
for v in vols:
    t=open(f"{V}/{v}.xml",encoding="utf-8",errors="replace").read()
    grp="scope" if v in SCOPE else "list"
    # document extents
    stack=[]; docs=[]
    for m in DIVTOK.finditer(t):
        if m.group(0).startswith("</"):
            if stack:
                s,a=stack.pop()
                if a is not None: docs.append([s,m.end(),a])
        else:
            a=m.group(1)
            if re.search(r'\btype="document"',a): stack.append((m.start(),a))
            else: stack.append((m.start(),None))
    docs.sort()
    starts=[d[0] for d in docs]
    dinfo=[]
    for s,e,a in docs:
        did=re.search(r'xml:id="([^"]+)"',a); ym=re.search(r'frus:doc-dateTime-min="(\d{4})',a)
        hs=t.find("<head",s); he=t.find("</head>",s)
        # the doc's own head must open before any nested div
        nd=t.find("<div",s+5)
        if hs==-1 or he==-1 or hs>e or (nd!=-1 and nd<hs): hs,he=-1,-1
        dinfo.append({"id":did.group(1) if did else None,"year":int(ym.group(1)) if ym else None,"hs":hs,"he":he})
    def doc_of(off):
        i=bisect.bisect_right(starts,off)-1
        while i>=0:
            if docs[i][0]<=off<docs[i][1]: return i
            i-=1
        return None
    headtext={}
    for m in list(PERS.finditer(t))+[None]:
        if m is None: break
        a=m.group(1); at=dict(ATTR.findall(a))
        for k in at: attr_census[grp][k]+=1
        counts[(grp,"persName")]+=1
        ty=at.get("type")
        link=at.get("corresp") or at.get("ref")
        if not link and ty not in ("from","to"): continue
        di=doc_of(m.start())
        doc=dinfo[di] if di is not None else None
        in_head=bool(doc and doc["hs"]!=-1 and doc["hs"]<=m.start()<doc["he"])
        rec={"v":v,"scope":grp=="scope","t":ty,"n":txt(m.group(2)),"off":m.start(),
             "d":doc["id"] if doc else None,"y":doc["year"] if doc else None,"head":in_head}
        if link:
            raw=link; tv,tid=v,link
            first=link.split()[0]
            if "#" in first:
                pre,tid=first.split("#",1); tv=pre.replace(".xml","") if pre else v
            else: tid=first
            rec.update({"link_raw":raw,"link_attr":"corresp" if at.get("corresp") else "ref","tv":tv,"tid":tid,
                        "tv_known":tv in ids,"resolves":tid in ids.get(tv,()),"cross":tv!=v,"multi":len(link.split())>1})
            lk.write(json.dumps(rec)+"\n"); counts[(grp,"linked")]+=1
        if ty in ("from","to") and doc is not None:
            if in_head and di not in headtext:
                headtext[di]=txt(NOTE.sub("",t[doc["hs"]:doc["he"]]))[:400]
            if in_head: rec["ht"]=headtext[di]
            ft.write(json.dumps(rec)+"\n"); counts[(grp,"fromto_in_doc")]+=1
    for m in PERS_SELF.finditer(t):
        for k in dict(ATTR.findall(m.group(1))): attr_census[grp]["SELFCLOSING:"+k]+=1
print("pass2",round(time.time()-t0,1),"s",file=sys.stderr)
json.dump({"attr_census":{g:dict(c.most_common()) for g,c in attr_census.items()},"counts":{"|".join(k):n for k,n in counts.items()},
           "manifest_volumes":len(vols),"scope_volumes":len(SCOPE)},open("scan-census.json","w"),indent=1)
print(json.dumps({"|".join(k):n for k,n in counts.items()},indent=1))
