#!/usr/bin/env python3
"""Task 1 (live index side). Read-only (mode=ro). Per volume: persons rows, person_mentions rows, distinct refs,
distinct documents, rows whose person_ref joins no persons row in the SAME volume (orphans), and whether the orphan
ref resolves to a persons row in ANY other volume. Scoped to the 267 TEI-rule volumes, the 1873 pair and the three
sibling parts; corpus-wide orphan totals too. Also the index version histogram."""
import sqlite3, json, collections
P="/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/frus.db"
c=sqlite3.connect('file:'+P+'?mode=ro',uri=True)
scope=json.load(open("/Users/jbotts/frus-ner-raw/scope.json"))
SCOPE=set(scope["volumes"])
out={"db":P}
out["index_version_hist"]=dict(c.execute("select index_version,count(*) from document_revisions group by 1").fetchall())
out["persons_rows"]=c.execute("select count(*) from persons").fetchone()[0]
out["person_mentions_rows"]=c.execute("select count(*) from person_mentions").fetchone()[0]
pv=collections.Counter(dict(c.execute("select volume_id,count(*) from persons group by 1").fetchall()))
refs_by_vol=collections.defaultdict(set)
for v,r in c.execute("select volume_id,ref from persons"): refs_by_vol[v].add(r)
all_refs=collections.defaultdict(set)
for v,s in refs_by_vol.items():
    for r in s: all_refs[r].add(v)
docs=dict(c.execute("select volume_id,count(*) from document_cache group by 1").fetchall())
per=collections.defaultdict(lambda:{"mentions":0,"refs":set(),"docs":set(),"orphan_rows":0,"orphan_refs":set(),"orphan_docs":set(),"orphan_rows_ref_exists_elsewhere":0})
for v,d,r in c.execute("select volume_id,document_id,person_ref from person_mentions"):
    x=per[v]; x["mentions"]+=1; x["refs"].add(r); x["docs"].add(d)
    if r not in refs_by_vol.get(v,()):
        x["orphan_rows"]+=1; x["orphan_refs"].add(r); x["orphan_docs"].add(d)
        if all_refs.get(r): x["orphan_rows_ref_exists_elsewhere"]+=1
def row(v):
    x=per.get(v)
    return {"docs_in_index":docs.get(v,0),"persons_rows":pv.get(v,0),
            "mentions":x["mentions"] if x else 0,"distinct_refs":len(x["refs"]) if x else 0,"docs_with_mentions":len(x["docs"]) if x else 0,
            "orphan_rows":x["orphan_rows"] if x else 0,"orphan_refs":len(x["orphan_refs"]) if x else 0,"orphan_docs":len(x["orphan_docs"]) if x else 0,
            "orphan_rows_ref_exists_in_another_volume":x["orphan_rows_ref_exists_elsewhere"] if x else 0}
focus=["frus1932v04","frus1918Supp01v02","frus1917Supp02v02","frus1932v03","frus1918Supp01v01","frus1917Supp02v01","frus1873p1v1","frus1873p1v2","frus1941-43","frus1914","frus1915","frus1916"]
out["focus"]={v:row(v) for v in focus}
out["scope_volumes_with_any_mentions"]={v:row(v) for v in sorted(SCOPE) if per.get(v)}
out["scope_totals"]={"volumes":len(SCOPE),"volumes_in_index":sum(1 for v in SCOPE if v in docs),
   "docs_in_index":sum(docs.get(v,0) for v in SCOPE),"persons_rows":sum(pv.get(v,0) for v in SCOPE),
   "mentions":sum(per[v]["mentions"] for v in SCOPE if v in per),"orphan_rows":sum(per[v]["orphan_rows"] for v in SCOPE if v in per),
   "docs_with_mentions":sum(len(per[v]["docs"]) for v in SCOPE if v in per)}
orph=sorted(((v,x["orphan_rows"],len(x["orphan_refs"])) for v,x in per.items() if x["orphan_rows"]),key=lambda t:-t[1])
out["corpus_orphan_rows"]=sum(t[1] for t in orph)
out["corpus_orphan_by_volume"]=orph
json.dump(out,open("live-index-links.json","w"),indent=1)
print(json.dumps({k:out[k] for k in ("index_version_hist","persons_rows","person_mentions_rows","scope_totals","corpus_orphan_rows")},indent=1))
for v,r in out["focus"].items(): print(v,r)
print("scope volumes with mentions:",len(out["scope_volumes_with_any_mentions"]))
for v,r in out["scope_volumes_with_any_mentions"].items(): print(" ",v,r)
print("orphans top:",orph[:15])
