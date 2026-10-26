# [TEI] For given documents, tells whether a passage sits in the document's own text or inside an editorial <note>.
# Surface: tag-stripped, whitespace-collapsed TEI text of the div with that xml:id; notes = every <note> descendant.
import sys, re, xml.etree.ElementTree as ET
V="/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/volumes/"
NS="{http://www.w3.org/XML/1998/namespace}id"
def flat(el, skip_notes):
    parts=[]
    def walk(e):
        if skip_notes and e.tag.endswith("}note"): 
            if e.tail: parts.append(e.tail)
            return
        if e.text: parts.append(e.text)
        for c in e: walk(c)
        if e.tail: parts.append(e.tail)
    walk(el); return " ".join("".join(parts).split())
for spec in sys.argv[1:]:
    vid,did,needle=spec.split("|",2)
    root=ET.parse(V+vid+".xml").getroot()
    el=None
    for e in root.iter():
        if e.get(NS)==did: el=e; break
    if el is None: print("##",vid,did,"NOT FOUND"); continue
    body=flat(el,True); notes=" ".join(flat(n,False) for n in el.iter() if n.tag.endswith("}note"))
    print(f"## {vid}/{did}: needle in body-without-notes: {needle in body}; in notes: {needle in notes}")
