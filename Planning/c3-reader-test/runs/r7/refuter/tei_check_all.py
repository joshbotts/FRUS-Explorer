# For every collection excerpt: is the passage in the document's TEI text with every <note> removed (document text),
# or only inside a <note> (editorial footnote)? Needle = the excerpt, whitespace-collapsed, compared on a normalised surface.
import json, re, xml.etree.ElementTree as ET
V="/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/volumes/"
NS="{http://www.w3.org/XML/1998/namespace}id"
def norm(s): return re.sub(r"[^a-z0-9]","",s.lower())
def flat(el, skip_notes):
    parts=[]
    def walk(e):
        if skip_notes and e.tag.endswith("}note"):
            if e.tail: parts.append(e.tail)
            return
        if e.text: parts.append(e.text)
        for c in e: walk(c)
        if e.tail: parts.append(e.tail)
    walk(el); return norm("".join(parts))
coll=json.load(open("/Users/jbotts/frus-analysis/c3/runs/r7/collection.fruscollection"))
ex=[e for e in coll["entries"] if e["kind"]=="excerpt"]
trees={}
inbody=innote=neither=0
for e in ex:
    vid,did=e["volumeId"],e["documentId"]
    if vid not in trees: trees[vid]=ET.parse(V+vid+".xml").getroot()
    root=trees[vid]; el=None
    for x in root.iter():
        if x.get(NS)==did: el=x; break
    if el is None: print("NOT FOUND", vid, did); neither+=1; continue
    body=flat(el,True); notes="".join(flat(n,False) for n in el.iter() if n.tag.endswith("}note"))
    nd=norm(e["text"])
    b=nd in body; n=nd in notes
    if b: inbody+=1
    elif n: innote+=1; print("IN FOOTNOTE ONLY:", vid, did, e["text"][:80])
    else:
        neither+=1
        # try segments split at the first 60 chars
        print("NEITHER (normalised excerpt not contiguous in TEI div):", vid, did, e["text"][:80], "| head60 in body:", nd[:60] in body, "| head60 in notes:", nd[:60] in notes)
print(f"excerpts: {len(ex)}; in document text (notes removed): {inbody}; only in a <note>: {innote}; not located contiguously: {neither}")
