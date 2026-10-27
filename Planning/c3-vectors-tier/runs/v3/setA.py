import sqlite3, json, re, csv
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
pat = re.compile(r'^\W*(the american republics\W*>?\s*)?cuba(,\s*19\d\d.*|\W*)$|^cuban missile crisis and aftermath$', re.I)
def alldocs(s):
    ids=list(s.get("documentIds") or [])
    for y in s.get("subsections") or []: ids+=alldocs(y)
    return ids
found={}
def walk(vid, secs):
    for s in secs:
        t=(s.get("title") or "").strip()
        if pat.match(t) or t.lower() in ("cuba","cuba:"):
            for i in alldocs(s): found[(vid,i)]=t
            continue
        walk(vid, s.get("subsections") or [])
for vid, js in db.execute("select volume_id, structure_json from volume_structures order by volume_id"):
    walk(vid, json.loads(js).get("sections") or [])
# add sub-sections within multi-country chapters
def walk2(vid, secs, anc):
    for s in secs:
        t=(s.get("title") or "").strip()
        if t.lower() in ("cuba",) and anc and ";" in anc[-1] : pass
        walk2(vid, s.get("subsections") or [], anc+[t])
extra={('frus1964-68v32','Cuba'),('frus1977-80v23','Cuba')}
for vid, js in db.execute("select volume_id, structure_json from volume_structures where volume_id in ('frus1964-68v32','frus1977-80v23','frus1969-76ve10','frus1969-76ve11p1','frus1961-63v12')"):
    def w(secs,anc):
        for s in secs:
            t=(s.get("title") or "").strip()
            if (vid,t) in extra or (vid=='frus1969-76ve10' and t=='Cuba') or (vid=='frus1969-76ve11p1' and t=='Cuba'):
                for i in alldocs(s): found[(vid,i)]=t
            else: w(s.get("subsections") or [], anc+[t])
    w(json.loads(js).get("sections") or [],[])
print(len(found))
# attach dates, exclusions
rows=[]
for (v,d),t in found.items():
    r=db.execute("select c.is_front_matter,c.is_editorial_note,dd.date_iso from document_cache c left join document_dates dd on dd.volume_id=c.volume_id and dd.document_id=c.document_id where c.volume_id=? and c.document_id=?",(v,d)).fetchone()
    if r is None: continue
    if r[0] or r[1]: continue
    rows.append((v,d,r[2] or '',t))
rows.sort(key=lambda x:(x[2],x[0],x[1]))
with open("setA.tsv","w") as f:
    for r in rows: f.write("\t".join(r)+"\n")
from collections import Counter
c=Counter((r[2][:3]+'0s') if r[2] else 'undated' for r in rows)
print(len(rows)); 
for k in sorted(c): print(k,c[k])
vols=Counter(r[0] for r in rows); print(len(vols))
