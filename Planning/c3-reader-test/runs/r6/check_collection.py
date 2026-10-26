# Re-reads collection.fruscollection as written and checks the contract and the cross-references with overview.md.
# SQL: SELECT body_text, is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?
import json, re, sqlite3
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
c=json.load(open("collection.fruscollection",encoding="utf-8"))
assert c["format"]=="fruscollection" and c["formatVersion"]==2 and c["minimumReaderVersion"]==1
assert set(c["composition"])=={"defaultBodyDepth","footnoteStyle","includeSourceNote","tocStyle","applyHighlights","includeNotes","includeWordCloud"}
docs=[]; ex=[]
for e in c["entries"]:
    if e["kind"] in ("document","excerpt"):
        assert e.get("volumeId") and e.get("documentId"), e
        r=con.execute("SELECT body_text, is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?",(e["volumeId"],e["documentId"])).fetchone()
        assert r is not None and r[1]==0 and r[2]==0
        assert not e["volumeId"].endswith("Ed2")
        if e["kind"]=="document":
            docs.append((e["volumeId"],e["documentId"])); assert e["notes"][0].startswith("Agent finding, run r6, 2026-10-25:")
        else:
            assert e["text"] in r[0], e; ex.append((e["volumeId"],e["documentId"],e["text"]))
assert len(docs)==len(set(docs))
assert {(v,d) for v,d,_ in ex} <= set(docs)
assert c["entries"][-1]=={"kind":"generated","generatedBlockType":"archivalSources"}
t=open("overview.md",encoding="utf-8").read()
urls=set(re.findall(r"https://history\.state\.gov/historicaldocuments/([^/\s,;)]+)/(d\d+)",t))
print("overview docs",len(urls),"collection docs",len(docs),"equal:",urls==set(docs))
ALLOW=set(json.loads(open("raw/allow.json").read())) if False else None
exec(open("check_overview.py").read().split("t=open(\"overview.md\"")[0].split("ALLOW=")[1].join(["ALLOW=",""]) if False else "")
src=open("check_overview.py").read(); allow=eval(src.split("ALLOW=")[1].split("\n")[0])
spans=[s for s in re.findall(r'"([^"]+)"',t) if s not in allow]
miss=[s for s in spans if not any(s in x for _,_,x in ex)]
print("overview quoted spans",len(spans),"without a collection excerpt:",len(miss),miss[:3])
print("excerpts",len(ex),"all verified against body_text")
