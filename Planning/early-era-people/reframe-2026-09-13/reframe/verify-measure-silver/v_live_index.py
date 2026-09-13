#!/usr/bin/env python3
"""VERIFY live index figures with SQL joins (not Python sets). Read-only mode=ro."""
import sqlite3, json, os
P="/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/frus.db"
c=sqlite3.connect('file:'+P+'?mode=ro',uri=True)
SCOPE=json.load(open("/Users/jbotts/frus-ner-raw/scope.json"))["volumes"]
c.execute("create temp table scope(v text primary key)"); c.executemany("insert into temp.scope values(?)",[(v,) for v in SCOPE])
out={}
out["persons_total"]=c.execute("select count(*) from persons").fetchone()[0]
out["mentions_total"]=c.execute("select count(*) from person_mentions").fetchone()[0]
out["index_version_hist"]=c.execute("select index_version,count(*) from document_revisions group by 1").fetchall()
q="""select m.volume_id, count(*), count(distinct m.person_ref), count(distinct m.document_id),
 sum(case when p.ref is null then 1 else 0 end), count(distinct case when p.ref is null then m.person_ref end),
 count(distinct case when p.ref is null then m.document_id end)
 from person_mentions m left join persons p on p.volume_id=m.volume_id and p.ref=m.person_ref where m.volume_id=? group by 1"""
focus=["frus1932v04","frus1918Supp01v02","frus1917Supp02v02","frus1873p1v1","frus1873p1v2","frus1941-43"]
out["focus"]={}
for v in focus:
    r=c.execute(q,(v,)).fetchone()
    out["focus"][v]={"persons_rows":c.execute("select count(*) from persons where volume_id=?",(v,)).fetchone()[0],
       "mentions,distinct_refs,docs,orphan_rows,orphan_refs,orphan_docs":list(r[1:]) if r else [0]*6}
out["scope_volumes_with_mentions"]=c.execute("select m.volume_id,count(*) from person_mentions m join temp.scope s on s.v=m.volume_id group by 1").fetchall()
out["scope_volumes_with_persons"]=c.execute("select p.volume_id,count(*) from persons p join temp.scope s on s.v=p.volume_id group by 1").fetchall()
out["corpus_orphan_rows"]=c.execute("select count(*) from person_mentions m left join persons p on p.volume_id=m.volume_id and p.ref=m.person_ref where p.ref is null").fetchone()[0]
out["corpus_orphan_by_volume"]=c.execute("select m.volume_id,count(*) from person_mentions m left join persons p on p.volume_id=m.volume_id and p.ref=m.person_ref where p.ref is null group by 1 order by 2 desc").fetchall()
split=("frus1932v04","frus1918Supp01v02","frus1917Supp02v02")
out["split_orphan_refs_total"]=c.execute("select count(*) from (select distinct volume_id,person_ref from person_mentions where volume_id in (?,?,?))",split).fetchone()[0]
out["split_orphan_docs_total"]=c.execute("select count(*) from (select distinct volume_id,document_id from person_mentions where volume_id in (?,?,?))",split).fetchone()[0]
json.dump(out,open(os.path.dirname(os.path.abspath(__file__))+"/v-live-index.json","w"),indent=1)
print(json.dumps(out,indent=1)[:4000])
