#!/usr/bin/env python3
"""VERIFY (independent of scan_links.py): ElementTree iterparse over every manifest volume's TEI, read-only.
Different method from the regex scan: a real XML parser, document extents from the element tree, the document's OWN
head = first direct <head> child of the innermost <div type="document">.
Per volume returns: persName xml:id set; persName attribute-name census; every corresp/ref on a persName (in/out of a
document, type, in own head); every from/to persName inside a document with doc id, frus:doc-dateTime-min year, name
text, link, in-head (subtree, and excluding <note>), the notes-stripped head text and the head text preceding the name.
Writes v-fromto.jsonl, v-links-scope.jsonl (links in the 267 scope volumes + 1873 pair), v-scan.json."""
import sys, os, json, collections, multiprocessing as mp
import xml.etree.ElementTree as ET
V="/Users/jbotts/Development/frus/volumes"
REPO="/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/234-feasibility-assessment-518fe5"
OUT=os.path.dirname(os.path.abspath(__file__))
TEI="{http://www.tei-c.org/ns/1.0}"; FR="{http://history.state.gov/frus/ns/1.0}"; XID="{http://www.w3.org/XML/1998/namespace}id"
PERS=TEI+"persName"; DIV=TEI+"div"; HEAD=TEI+"head"; NOTE=TEI+"note"
DETAIL={"frus1873p1v1","frus1873p1v2"}
def an(k):
    if k==XID: return "xml:id"
    return k
def norm(s): return " ".join(s.split())
def head_text(head):
    parts=[]; marks={}
    def rec(x):
        if x.tag==PERS: marks[id(x)]=sum(len(p) for p in parts)
        if x.text: parts.append(x.text)
        for ch in x:
            if ch.tag!=NOTE: rec(ch)
            if ch.tail: parts.append(ch.tail)
    rec(head)
    return "".join(parts), marks
def parse_link(v,link):
    first=link.split()[0]
    if "#" in first:
        pre,tid=first.split("#",1); tv=pre[:-4] if pre.endswith(".xml") else (pre if pre else v)
    else: tv,tid=v,first
    return tv,tid
def scan(args):
    v,scope=args
    ids=set(); census=collections.Counter(); fromto=[]; links=[]; linkc=collections.Counter()
    doc_depth=0
    def process_doc(d):
        did=d.get(XID); dm=d.get(FR+"doc-dateTime-min"); y=int(dm[:4]) if dm and dm[:4].isdigit() else None
        own=None
        for ch in d:
            if ch.tag==HEAD: own=ch; break
        if own is not None:
            raw,marks=head_text(own); sub={id(x) for x in own.iter()}
        else: raw,marks,sub="",{},set()
        st=[d]
        while st:
            x=st.pop()
            for ch in x:
                if ch.tag==DIV and ch.get("type")=="document": continue
                st.append(ch)
                if ch.tag!=PERS: continue
                ty=ch.get("type"); link=ch.get("corresp") or ch.get("ref")
                inh=id(ch) in sub; inh_nn=id(ch) in marks
                if link:
                    linkc[("in_doc",ty in ("from","to"),inh)]+=1
                    if scope or v in DETAIL:
                        tv,tid=parse_link(v,link); links.append([v,did,ty,inh,tv,tid])
                if ty in ("from","to"):
                    rec={"v":v,"d":did,"y":y,"t":ty,"n":norm("".join(ch.itertext())),"link":link,"head":inh,"head_nn":inh_nn}
                    if inh:
                        rec["ht"]=norm(raw)
                        if inh_nn: rec["before"]=norm(raw[:marks[id(ch)]])
                    fromto.append(rec)
    for ev,el in ET.iterparse(f"{V}/{v}.xml",events=("start","end")):
        if ev=="start":
            if el.tag==DIV and el.get("type")=="document": doc_depth+=1
            elif el.tag==PERS:
                for k in el.attrib: census[an(k)]+=1
                if XID in el.attrib: ids.add(el.attrib[XID])
                link=el.get("corresp") or el.get("ref")
                if link:
                    linkc["all"]+=1
                    if doc_depth==0:
                        linkc[("out_doc",)]+=1
                        tv,tid=parse_link(v,link)
                        if scope or v in DETAIL or tv!=v: links.append([v,None,el.get("type"),False,tv,tid])
        else:
            if el.tag==DIV and el.get("type")=="document":
                doc_depth-=1; process_doc(el); el.clear()
            elif doc_depth==0: el.clear()
    # cross-volume/dangling targets from in-doc links of list volumes
    return v,scope,ids,census,fromto,links,{"|".join(map(str,k)):n for k,n in linkc.items()}
if __name__=="__main__":
    man=json.load(open(REPO+"/FRUSExplorer/Resources/manifest.json")); man=man["volumes"] if isinstance(man,dict) else man
    vols=[m["volumeId"] for m in man]
    SCOPE=set(json.load(open("/Users/jbotts/frus-ner-raw/scope.json"))["volumes"])
    jobs=sorted([(v,v in SCOPE) for v in vols],key=lambda a:-os.path.getsize(f"{V}/{a[0]}.xml"))
    res={}; ft=open(OUT+"/v-fromto.jsonl","w"); lk=open(OUT+"/v-links-scope.jsonl","w")
    with mp.Pool(8) as pool:
        for v,scope,ids,census,fromto,links,linkc in pool.imap_unordered(scan,jobs):
            for r in fromto: r["scope"]=scope; ft.write(json.dumps(r,ensure_ascii=False)+"\n")
            for l in links: lk.write(json.dumps(l)+"\n")
            res[v]={"scope":scope,"persName_xml_ids":sorted(ids),"attr_census":dict(census),"linkc":linkc,"fromto_in_doc":len(fromto)}
            print(v,len(fromto),len(links),file=sys.stderr)
    json.dump({"manifest_volumes":len(vols),"scope_json_volumes":len(SCOPE),"scope_not_in_manifest":sorted(SCOPE-set(vols)),"volumes":res},open(OUT+"/v-scan.json","w"))
    print("done",len(res))
