import sqlite3,re,json,collections
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
R="/Applications/FRUS Explorer.app/Contents/Resources/"
RUN="/Users/jbotts/frus-analysis/c3f/runs/f2/"
c=sqlite3.connect("file:"+DB+"?mode=ro",uri=True)
scope={l.split("\t")[0]:l.split("\t")[1] for l in open(RUN+"scope_volumes.tsv")}
EA=[v for v,k in scope.items() if k=="EA"]; PD=[v for v,k in scope.items() if k=="PD"]
print("scope file: %d volumes, EA %d, PD %d"%(len(scope),len(EA),len(PD)))

# --- #1 fifteen documents: collection count ---
coll=json.load(open(RUN+"collection.fruscollection"))
docs=[(e["volumeId"],e["documentId"]) for e in coll["entries"] if e["kind"]=="document"]
print("#1 collection document entries:",len(docs),"distinct",len(set(docs)))

# --- #3 119: rank_pd replication (same regex as rank_pd.py) ---
vols=['frus1917-72PubDip','frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1969-76v38p2','frus1977-80v30']
pat=re.compile(r"\b(Japan\w*|Korea\w*|China|Chinese|Taiwan|Vietnam\w*|Viet-Nam\w*|Philippin\w*|Indonesia\w*|Thai\w*|Laos|Lao|Cambodia\w*|Burm\w*|Malaysia\w*|Singapore|East Asia\w*|Far East\w*|Asian?s?|Pacific|Australia\w*|New Zealand|Okinawa\w*|Peking|Hanoi|Saigon|Tokyo)\b")
rows=c.execute("SELECT volume_id, document_id, body_text FROM document_cache WHERE volume_id IN (%s) AND is_front_matter=0 AND is_editorial_note=0"%",".join("?"*6),vols).fetchall()
counts={(v,d):len(pat.findall(b)) for v,d,b in rows}
wide=[k for k,n in counts.items() if n>=10]
print("#3 PD non-apparatus rows:",len(rows),"| >=10 place-word matches (wide set):",len(wide))
# compare with the session's pd_ranked.tsv
sess=[(l.split("\t")[2],l.split("\t")[3],int(l.split("\t")[0])) for l in open(RUN+"pd_ranked.tsv")]
sess_wide={(v,d) for v,d,n in sess if n>=10}
print("   session's pd_ranked.tsv rows:",len(sess),"wide:",len(sess_wide),"| set equal to mine:",sess_wide==set(wide))

# --- #2 three in five (74 of 119 RG 306 came-from) and #5 one in eleven (11 of 119 with any external_citations row) ---
rg=collections.Counter(); any_pa=0; norow=0
for v,d in wide:
    r=c.execute("SELECT repository, record_group FROM document_sources WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    if r: rg[(r[0],r[1])]+=1
    else: norow+=1
    n=c.execute("SELECT COUNT(*) FROM external_citations WHERE volume_id=? AND document_id=?",(v,d)).fetchone()[0]
    if n: any_pa+=1
print("#2 came-from by (repository, record_group) over the wide set:")
for k,n in rg.most_common(): print("   ",n,k)
print("   no document_sources row:",norow)
rg306=sum(n for (rep,g),n in rg.items() if g=="306")
print("   RG 306 total:",rg306,"of",len(wide),"=",round(rg306/len(wide),3),"(three in five = 0.600)")
print("#5 wide-set documents with any external_citations row:",any_pa,"of",len(wide),"=",round(any_pa/len(wide),4),"(one in eleven = 0.0909)")

# --- #4 eighteen series under 306/72A5121 ---
import os
for fn in ["accession-series-index.json"]:
    J=json.load(open(R+fn))
    print("#4",fn,"top keys:",list(J.keys())[:12] if isinstance(J,dict) else type(J))
    def walk(o,path=""):
        if isinstance(o,dict):
            for k,v in o.items():
                if "72A5121" in str(k): yield path+"/"+str(k),v
                yield from walk(v,path+"/"+str(k))
        elif isinstance(o,list):
            for i,v in enumerate(o): yield from walk(v,path+"[%d]"%i)
    for p,v in walk(J):
        print("   key path:",p,"| type",type(v).__name__,"| len",len(v) if hasattr(v,"__len__") else "-")
        if isinstance(v,list):
            for s in v[:30]: print("      ",json.dumps(s,ensure_ascii=False)[:160])
        elif isinstance(v,dict):
            print("      ",json.dumps(v,ensure_ascii=False)[:1500])

# --- extras: 553; 109 via regex over manifest titles; 61,852; 968 ---
print("\n== extras ==")
print("canary:",c.execute("SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache").fetchone())
M=json.load(open(R+"manifest.json"))
print("manifest type",type(M).__name__, list(M.keys())[:10] if isinstance(M,dict) else "")
vol_list=None
if isinstance(M,dict):
    for k,v in M.items():
        if isinstance(v,list) and v and isinstance(v[0],dict): vol_list=v; print("manifest list key:",k,"len",len(v),"sample keys",list(v[0].keys())[:15]); break
rx=re.compile(r"China|Japan|Korea|East Asia|Southeast Asia|Vietnam|Indochina|Philippine|Indonesia|Pacific|Far East|Laos|Cambodia|Northeast Asia|Burma|Thailand")
if vol_list:
    tk=[k for k in vol_list[0].keys() if "title" in k.lower()]; ik=[k for k in vol_list[0].keys() if k.lower() in ("id","volumeid","volume_id")]
    print("title key",tk,"id key",ik)
    ea=sorted(v[ik[0]] for v in vol_list if rx.search(str(v.get(tk[0],""))))
    pd_=sorted(v[ik[0]] for v in vol_list if "Public Diplomacy" in str(v.get(tk[0],"")))
    print("regex EA titles:",len(ea),"| PD titles:",len(pd_),"| union:",len(set(ea)|set(pd_)))
    print("   EA regex set == scope EA:",set(ea)==set(EA),"| diff mine-scope:",sorted(set(ea)-set(EA)),"| scope-mine:",sorted(set(EA)-set(ea)))
    print("   PD set == scope PD:",set(pd_)==set(PD), sorted(set(pd_)^set(PD)))
    print("   Ed2 in scope:",[v for v in scope if v.endswith("Ed2")])
    indexed={r[0] for r in c.execute("SELECT DISTINCT volume_id FROM document_cache")}
    print("   scope volumes present in index:",sum(v in indexed for v in scope),"of",len(scope))
q="SELECT COUNT(*) FROM document_cache WHERE volume_id IN (%s) AND is_front_matter=0 AND is_editorial_note=0"
print("non-apparatus in 109:",c.execute(q%",".join("?"*len(scope)),list(scope)).fetchone()[0],"(memo 61,852; overview 'about 62,000')")
print("non-apparatus in 6 PD:",c.execute(q%",".join("?"*len(PD)),PD).fetchone()[0],"(memo 968)")
print("non-apparatus in 103 EA:",c.execute(q%",".join("?"*len(EA)),EA).fetchone()[0])
sql="SELECT d.volume_id, d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0"
for term in ['"United States Information Agency" OR USIA','"Department of State"','"soft power"','ZZZ_IMPOSSIBLE_ZZZ','messaging']:
    rows=c.execute(sql,(term,)).fetchall(); n=len(rows)
    ea=sum(1 for v,d in rows if scope.get(v)=="EA"); pd=sum(1 for v,d in rows if scope.get(v)=="PD")
    print("MATCH %-55s corpus %6d | scope %5d | EA %5d | PD %4d"%(term,n,ea+pd,ea,pd))
    if "USIA" in term: print("   'nearly two in three' = PD/scope =",pd,"/",ea+pd,"=",round(pd/(ea+pd),3), "| d190 in corpus set:",("frus1955-57v09","d190") in set(rows))
    if "Department" in term:
        vols=collections.Counter(v for v,d in rows); print("   scope volumes with zero 'Department of State' matches:",[v for v in scope if vols[v]==0])
