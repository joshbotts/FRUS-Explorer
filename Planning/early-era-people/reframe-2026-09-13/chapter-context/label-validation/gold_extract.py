#!/usr/bin/env python3
"""Editor-asserted identities: for each list volume, every <persName type=from|to> inside a
<div type="document"> whose corresp/ref points at a local persName xml:id -> the list entry
(name, the item's role text, the nearest preceding centred list heading). Also records every
UNLINKED from/to mention so coverage has a denominator. Read-only over TEI."""
import re, json
V="/Users/jbotts/Development/frus/volumes"
vols=[r[0] for f in ("census.json","census-1926-1950.json") for r in json.load(open(f)) if r[5]>0]
def txt(s): return " ".join(re.sub(r"<[^>]+>","",s).split())
DOCSPLIT=re.compile(r'(?=<div\b[^>]*type="document")')
out=open("gold-mentions.jsonl","w"); ent=open("gold-entries.jsonl","w")
for v in vols:
    t=open(f"{V}/{v}.xml",encoding="utf-8").read()
    # list entries: <item> containing <persName xml:id>; heading = last <p rend="center"> or <head> before it in the list div
    entries={}
    for m in re.finditer(r'<item>(.*?)</item>',t,re.S):
        pm=re.search(r'<persName\b[^>]*xml:id="([^"]+)"[^>]*>(.*?)</persName>(.*)',m.group(1),re.S)
        if not pm: continue
        before=t[max(0,m.start()-6000):m.start()]
        hs=re.findall(r'<p rend="center">(.*?)</p>',before,re.S)
        entries[pm.group(1)]={"volume":v,"id":pm.group(1),"name":txt(pm.group(2)),"role":txt(pm.group(3)).lstrip(", ").strip(),
                              "heading":txt(hs[-1]) if hs else None}
    for e in entries.values(): ent.write(json.dumps(e)+"\n")
    for seg in DOCSPLIT.split(t)[1:]:
        head=seg[:800]
        hend=seg.find("</head>")  # end of the document's OWN first <head>; later heads are enclosures
        did=re.search(r'xml:id="([^"]+)"',head).group(1)
        dmin=re.search(r'frus:doc-dateTime-min="([^"]+)"',head)
        # stop at the next nested document? DOCSPLIT already splits at every document div.
        for pm in re.finditer(r'<persName\b([^>]*)>(.*?)</persName>',seg,re.S):
            a=pm.group(1); ty=re.search(r'\btype="(from|to)"',a)
            if not ty: continue
            c=re.search(r'\b(?:corresp|ref)="#?([^"]+)"',a)
            cid=c.group(1).lstrip("#") if c else None
            out.write(json.dumps({"v":v,"d":did,"t":ty.group(1),"n":txt(pm.group(2)),"raw_inner":pm.group(2)[:300],"link":cid,
                "linked":cid in entries,"tei_date":dmin.group(1)[:10] if dmin else None,"off":pm.start(),"in_doc_head":0 <= pm.start() < hend})+"\n")
    print(v,len(entries))
