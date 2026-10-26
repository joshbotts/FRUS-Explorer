import json, re, sqlite3
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
c = json.load(open("collection.fruscollection"))
assert c["format"] == "fruscollection" and c["formatVersion"] == 2 and c["minimumReaderVersion"] == 1
need = {"defaultBodyDepth","footnoteStyle","includeSourceNote","tocStyle","applyHighlights","includeNotes","includeWordCloud"}
assert set(c["composition"]) == need, c["composition"].keys()
for k in ("name","authorLine","introductionText"): assert c[k].strip(), k
E = c["entries"]
docs=[]; exc=[]; heads=0; prose=0
for i,e in enumerate(E):
    k=e["kind"]
    if k=="heading": heads+=1; assert e["level"]==1; assert E[i+1]["kind"]=="prose"
    elif k=="prose": prose+=1
    elif k in ("document","excerpt"):
        assert e.get("volumeId") and e.get("documentId"), e
        r=db.execute("SELECT is_front_matter,is_editorial_note,body_text FROM document_cache WHERE volume_id=? AND document_id=?",(e["volumeId"],e["documentId"])).fetchone()
        assert r and r[0]==0 and r[1]==0, e
        if k=="document":
            assert e["notes"] and e["notes"][0].startswith("Agent finding, run r12, 2026-10-26: "); docs.append((e["volumeId"],e["documentId"]))
        else:
            assert e["text"] in r[2]; exc.append(e["text"])
    elif k=="generated": assert e["generatedBlockType"]=="archivalSources" and i==len(E)-1
assert len(docs)==len(set(docs)); assert not any("Ed2" in v for v,_ in docs)
assert E[-2]["kind"]=="prose"
ov=open("overview.md").read()
cited=set(re.findall(r"historicaldocuments/([^/\s,)]+)/(d\d+)",ov))
assert cited<=set(docs), cited-set(docs)
quoted=[q for q in re.findall(r"“([^”]+)”",ov) if len(q)>12]
ex=set(exc)
missing=[q for q in quoted if q not in ex]
print("headings",heads,"prose",prose,"documents",len(docs),"excerpts",len(exc),"cited in overview",len(cited))
print("overview quoted passages not in collection excerpts:",missing)
bad=[q for q in exc if q not in ov.replace("“","").replace("”","") and q not in ov]
print("excerpts not appearing in overview:",bad)
