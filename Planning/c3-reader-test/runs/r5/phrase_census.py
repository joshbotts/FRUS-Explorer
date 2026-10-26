# phrase_census.py: for each phrase family, (1) index hits via FTS5 phrase MATCH (stemmed, non-apparatus docs), (2) census of ALL hits (all < 300) re-tested with literal regex on header+dateline+source_note+body collapsed (case-insensitive): STRICT single spaces; TOLERANT inflections + any run of space/hyphen/comma/paren/full stop. Output phrase_census_out.txt
import sqlite3,re
out=open('/Users/jbotts/frus-analysis/c3/runs/r5/phrase_census_out.txt','w')
def P(*a):
    s=' '.join(str(x) for x in a); print(s); out.write(s+'\n'); out.flush()
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
# controls in the same pass
q1="SELECT count(DISTINCT d.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '\"department of state\"' AND d.is_front_matter=0 AND d.is_editorial_note=0"
q2="SELECT count(*) FROM frus_documents WHERE frus_documents MATCH '\"ZZZ_IMPOSSIBLE_ZZZ\"'"
P("CONTROL SQL (positive):",q1); P("  volumes (of 553) with >=1 non-apparatus doc matching 'department of state':",c.execute(q1).fetchone()[0])
P("CONTROL SQL (negative):",q2); P("  rows matching ZZZ_IMPOSSIBLE_ZZZ:",c.execute(q2).fetchone()[0])
sep=r'[\s\-,\(\)\.]+'
FAM=[
 ('Estrada Doctrine','"Estrada doctrine"', r'Estrada Doctrine', r'Estrada'+sep+r'doctrines?'),
 ('Tobar doctrine','"Tobar doctrine"', r'Tobar doctrine', r'Tobar'+sep+r'doctrines?'),
 ('non-recognition','nonrecognition OR "non-recognition"', r'non-recognition|nonrecognition', r'non[\s\-,\(\)\.]*recogni\w*'),
]
for name,fts,strict,tol in FAM:
    sql="SELECT d.volume_id,d.document_id,d.header,d.dateline,d.source_note,d.body_text FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 ORDER BY d.volume_id,d.document_id"
    P("FAMILY:",name,"| SQL:",sql.replace('?',repr(fts)))
    rows=c.execute(sql,(fts,)).fetchall()
    n=len(rows); s=t=0; vols=set()
    for v,d,h,dl,sn,b in rows:
        txt=' '.join(' '.join([h or '',dl or '',sn or '',b]).split())
        if re.search(strict,txt,re.I): s+=1
        if re.search(tol,txt,re.I): t+=1
        if not re.search(tol,txt,re.I): P('   TOLERANT MISS:',v+'/'+d)
        vols.add(v)
    P(f"  index hits (stem-level, non-apparatus): {n} documents in {len(vols)} volumes; literal-regex census of ALL {n}: STRICT {s} of {n}; TOLERANT {t} of {n}")
