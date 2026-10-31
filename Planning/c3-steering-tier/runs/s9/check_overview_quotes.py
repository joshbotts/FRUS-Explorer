import re, json, sqlite3
R="/Users/jbotts/frus-analysis/c3s/runs/s9"
s=open(R+"/overview.md").read()
c=json.load(open(R+"/collection.fruscollection"))
pairs={(e["volumeId"],e["documentId"]) for e in c["entries"] if e["kind"]=="document"}
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
texts={p:con.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",p).fetchone()[0] for p in pairs}
# cited URLs
urls=set(re.findall(r"historicaldocuments/([^/\s)]+)/(d\d+)", s))
print("URL-cited pairs:", len(urls), "missing from collection:", sorted(urls-pairs))
# quotations of 25+ chars in straight double quotes
qs=[q for q in re.findall(r"\"([^\"]*)\"", s) if len(q)>=20]
bad=0
for q in qs:
    qq=q.rstrip(".,")
    hit=[p for p,t in texts.items() if qq in t or qq in re.sub(r"\s+"," ",t)]
    if not hit: bad+=1; print("UNVERIFIED:", qq[:90])
print("quotations checked:", len(qs), "unverified:", bad)
# excerpts
eb=0
for e in c["entries"]:
    if e["kind"]=="excerpt" and e["text"] not in texts[(e["volumeId"],e["documentId"])]: eb+=1
print("excerpts:", sum(e["kind"]=="excerpt" for e in c["entries"]), "not found in own document:", eb)
