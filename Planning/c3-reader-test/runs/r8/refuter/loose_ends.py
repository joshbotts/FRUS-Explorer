import sqlite3, json, re, ast, collections
R8="/Users/jbotts/frus-analysis/c3/runs/r8/"
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
src=open(R8+"core_build.py").read()
CH=ast.literal_eval(src[src.index("CH=[")+3:src.index("]\n# post-1950")+1])
chap_docs=collections.defaultdict(list)
def walk(vid,sec,path):
    t=" ".join((sec.get("title") or "").split()); p=path+[t] if t else path
    for d in sec.get("documentIds",[]): chap_docs[(vid," > ".join(p))].append(d)
    for s in sec.get("subsections",[]): walk(vid,s,p)
vols=sorted(set(v for v,_ in CH))
for vid,sj in db.execute("SELECT volume_id, structure_json FROM volume_structures WHERE volume_id IN (%s)"%",".join("'%s'"%v for v in vols)):
    for s in json.loads(sj).get("sections",[]): walk(vid,s,[])
sel2ch=collections.defaultdict(list)
for v,sub in CH:
    for k in chap_docs:
        if k[0]==v and sub in k[1]: sel2ch[k].append(sub)
print("distinct chapters matched by the 85 selectors:",len(sel2ch))
for k,subs in sel2ch.items():
    if len(subs)>1: print("  chapter matched by %d selectors:"%len(subs),k[0],k[1][:110],"<-",subs)
# 'continuing relations' in the collection's documents and the core
coll=json.load(open(R8+"collection.fruscollection")); docs=[(e["volumeId"],e["documentId"]) for e in coll["entries"] if e["kind"]=="document"]
def N(s): return re.sub(r"[^a-z0-9]","",s.lower())
hits=[]
for v,d in docs:
    r=db.execute("SELECT header,dateline,source_note,body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    t=N("".join(x or "" for x in r))
    if "continuingrelations" in t: hits.append((v,d))
print("'continuing relations' (normalized) in the 52 collection documents:",hits)
print("FTS \"continuing relations\" corpus-wide:",db.execute("SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH '\"continuing relations\"'").fetchone(),
      "| in frus1948v09/frus1949v02/frus1950v02/frus1977-80v24:",db.execute("SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH '\"continuing relations\"' AND d.volume_id IN ('frus1948v09','frus1949v02','frus1950v02','frus1977-80v24')").fetchall())
# PPS paper of March 1948 in frus1948v09
print("frus1948v09 PPS March 1948:",db.execute("""SELECT d.document_id, dd.date_iso, substr(d.header,1,110) FROM document_cache d LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
 WHERE d.volume_id='frus1948v09' AND (d.header LIKE '%Policy Planning%' OR d.body_text LIKE '%PPS/24%' OR d.body_text LIKE '%PPS 24%') ORDER BY dd.date_iso""").fetchall()[:8])
print("d115 mentions of March 1948 paper:",[m.group(0) for m in re.finditer(r".{60}PPS[ /]?2[34].{80}",db.execute("SELECT body_text FROM document_cache WHERE volume_id='frus1948v09' AND document_id='d115'").fetchone()[0],re.S)][:3])
# d359: seven conditions
b=db.execute("SELECT body_text FROM document_cache WHERE volume_id='frus1961-63v12' AND document_id='d359'").fetchone()[0]
print("d359 numbered points:",sorted(set(re.findall(r"\((\d)\)",b))), "| mentions OAS & elections & year:", bool(re.search(r"OAS",b)), bool(re.search(r"elections?",b)), bool(re.search(r"(within|in) (a|one) year|year",b)))
print("d359 snippet:",re.sub(r"\s+"," ",b[2990:3700]))
# memo M14 figures vs index
print("M14 DoS no-collection rows/docs:",db.execute("""SELECT COUNT(*), COUNT(DISTINCT e.volume_id||'/'||e.document_id) FROM external_citations e WHERE e.repository='Department of State' AND e.collection IS NULL AND (e.volume_id||'/'||e.document_id) IN (%s)"""%",".join("'%s/%s'"%(f.split('\t')[0],f.split('\t')[1]) for f in open(R8+"core_scope.tsv").read().splitlines())).fetchone())
