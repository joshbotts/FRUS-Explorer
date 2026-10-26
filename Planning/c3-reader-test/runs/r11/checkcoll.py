# Check: every history.state.gov URL in overview.md is a document in the collection; every collection excerpt is an exact substring of its document (whitespace-collapsed).
import json,re
from db import q
c=json.load(open("collection.fruscollection"))
docs={(e["volumeId"],e["documentId"]) for e in c["entries"] if e["kind"]=="document"}
ov=set(re.findall(r'historicaldocuments/([^/\s]+)/(d\d+)',open("overview.md").read()))
print("overview-cited docs",len(ov),"missing from collection",sorted(ov-docs),"in collection not cited in overview",sorted(docs-ov))
bad=0
for e in c["entries"]:
    if e["kind"]=="excerpt":
        r=q("SELECT header, coalesce(dateline,''), coalesce(source_note,''), body_text FROM document_cache WHERE volume_id=? AND document_id=?",(e["volumeId"],e["documentId"]),tag="checkcoll")[0]
        if e["text"] not in re.sub(r"\s+"," "," ".join(r)): bad+=1; print("BAD",e)
print("excerpts",sum(1 for e in c["entries"] if e["kind"]=="excerpt"),"unverified",bad)
print("all document/excerpt entries carry both ids:",all(e.get("volumeId") and e.get("documentId") for e in c["entries"] if e["kind"] in ("document","excerpt")))
