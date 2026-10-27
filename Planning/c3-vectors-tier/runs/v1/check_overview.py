# check_overview.py: every “quotation” in overview.md must be a substring (whitespace-collapsed) of body_text of a collection document; every history.state.gov URL in it must be a document entry of collection.fruscollection
import re,json,sqlite3
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
s=open("overview.md").read(); col=json.load(open("collection.fruscollection"))
pairs={(e["volumeId"],e["documentId"]) for e in col["entries"] if e["kind"]=="document"}
bodies={p:re.sub(r"\s+"," ",c.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",p).fetchone()[0]) for p in pairs}
qs=re.findall(r"“([^”]+)”",s); bad=[]
for q in qs:
    qq=re.sub(r"\s+"," ",q)
    if not any(qq in b for b in bodies.values()): bad.append(qq)
urls=set(re.findall(r"historicaldocuments/([^/\s,;)]+)/([^\s,;)]+)",s))
print("quotations in overview:",len(qs),"; not found in any collection document:",bad)
print("distinct cited documents:",len(urls),"; cited but not in collection:",sorted(u for u in urls if u not in pairs),"; in collection but not cited:",sorted(p for p in pairs if p not in urls))
ex=[e for e in col["entries"] if e["kind"]=="excerpt"]
okx=sum(1 for e in ex if e["text"] in c.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",(e["volumeId"],e["documentId"])).fetchone()[0])
print("excerpts in collection:",len(ex),"; verbatim in their document's body_text:",okx)
