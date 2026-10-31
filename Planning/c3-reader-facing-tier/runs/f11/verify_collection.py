import json,sqlite3,re
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
c=json.load(open("collection.fruscollection"))
assert c["format"]=="fruscollection" and c["formatVersion"]==2 and c["minimumReaderVersion"]==1
assert set(c["composition"])=={"defaultBodyDepth","footnoteStyle","includeSourceNote","tocStyle","applyHighlights","includeNotes","includeWordCloud"}
seen=set(); ok=0; bad=0; ne=0
for e in c["entries"]:
    if e["kind"] in ("document","excerpt"):
        assert e.get("volumeId") and e.get("documentId")
        assert not e["volumeId"].endswith("Ed2")
    if e["kind"]=="document":
        k=(e["volumeId"],e["documentId"]); assert k not in seen; seen.add(k)
        assert e["notes"][0].startswith("Agent run f11, 2026-10-31")
    if e["kind"]=="excerpt":
        ne+=1
        b=db.execute("select body_text from document_cache where volume_id=? and document_id=?",(e["volumeId"],e["documentId"])).fetchone()[0]
        if re.sub(r"\s+"," ",e["text"]) in re.sub(r"\s+"," ",b): ok+=1
        else: bad+=1; print("FAIL",e["volumeId"],e["documentId"],e["text"][:80])
print("documents",len(seen),"excerpts",ne,"verified verbatim",ok,"failed",bad)
print("first entry kinds:",[e["kind"] for e in c["entries"]][:6],"last:",c["entries"][-1])
