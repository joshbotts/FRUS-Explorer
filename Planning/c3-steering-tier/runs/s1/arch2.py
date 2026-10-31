import json, sqlite3, csv, collections
from final_set import FINAL
R="/Applications/FRUS Explorer.app/Contents/Resources/"
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
vols={v for v,d in FINAL}
hits=[(r["volume_id"],r["document_id"]) for r in csv.DictReader(open("scan1.csv")) if r["volume_id"] in vols]
lots=collections.Counter()
for k in hits:
    for (l,) in con.execute("SELECT lot_file_norm FROM external_citations WHERE volume_id=? AND document_id=? AND anchor='lotFile'",k): lots[l]+=1
print("lot-file citations on hit docs:",dict(lots))
cf=json.load(open(R+"central-files-index.json"))["lotFiles"]
sf=json.load(open(R+"series-facts-index.json"))
lc=json.load(open(R+"lot-claimants-index.json"))["lots"]
cur=json.load(open(R+"curated-lot-resolutions.json"))["lots"]
for l in lots:
    print("==",l)
    for r in cf:
        if r["lotNumber"]==l: 
            f=sf["byNaId"].get(r["naId"],{})
            print(" central-files:",r["naId"],r["recordGroup"],r["title"][:90],"| entries",r.get("hmsMlrEntryNumbers"),"| facts",{k:(sf[{'as':'statuses','ar':'restrictions','c':'headings'}[k]][v] if k in('as','c') else v) for k,v in f.items() if k in('y0','y1','as','c','x')} if f else None)
    for r in lc:
        if r.get("lotNumber")==l or r.get("lot")==l: print(" claimants:",json.dumps(r)[:300])
    for r in cur:
        if r.get("lotNumber")==l: print(" curated:",json.dumps(r)[:300])
