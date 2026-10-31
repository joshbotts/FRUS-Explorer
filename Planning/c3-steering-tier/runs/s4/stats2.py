import sqlite3,re,json
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
ED2="('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
S=json.load(open("work/set.json")); vols=sorted({v for f,v,d in S})
vl=",".join("'%s'"%v for v in vols)
def share(match,inside):
    cond=f"c.volume_id IN ({vl})" if inside else f"c.volume_id NOT IN ({vl})"
    tot=con.execute(f"select count(*) from document_cache c where c.is_front_matter=0 and c.is_editorial_note=0 and c.volume_id not in {ED2} and {cond}").fetchone()[0]
    n=con.execute(f"SELECT count(*) FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN {ED2} AND {cond}",(match,)).fetchone()[0]
    return n,tot
print("FALSE-FRIEND TEST: share of non-apparatus documents matching, inside the collection's "+str(len(vols))+" volumes vs the other "+str(553-len(vols))+" (Ed2 excluded)")
for label,m in [("corrupt (stem; the question's own term)","corrupt"),("CONTROL phrase 'department of state'",'"department of state"'),("CONTROL term 'ambassador'","ambassador"),("NEGATIVE ZZZ_IMPOSSIBLE_ZZZ","zzz_impossible_zzz")]:
    a,b=share(m,True); c,d=share(m,False)
    print(f"{label}: inside {a} of {b} = {a/b:.4f}; outside {c} of {d} = {c/d:.4f}; ratio {((a/b)/(c/d) if c else float('nan')):.2f}")
# nexus literal share
nx=open("nexus.txt").read().strip()
hits=sorted(con.execute(f"SELECT c.volume_id,c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN {ED2}",(nx,)).fetchall())
print("NEXUS set size:",len(hits))
second=["aid","assistance","assist\\w*","support\\w*","withhold\\w*","condition\\w*","suspend\\w*","confidence","congress\\w*","reform\\w*"]
strict_second=re.compile(r"^(aid|assistance|support|withhold|withholding|condition|conditions|suspend|confidence|congress|reform|reforms)$",re.I)
tol_second=re.compile(r"^(aid\w*|assist\w*|support\w*|withhold\w*|condition\w*|suspend\w*|suspens\w*|confiden\w*|congress\w*|reform\w*)$",re.I)
strict_c=re.compile(r"^(corrupt|corruption)$",re.I); tol_c=re.compile(r"^corrupt\w*$",re.I)
def near(tokens,c,s,w=25):
    ci=[i for i,t in enumerate(tokens) if c.match(t)]
    si=[i for i,t in enumerate(tokens) if s.match(t)]
    return any(abs(i-j)<=w for i in ci for j in si)
n=len(hits); step=n/40; sample=[hits[int(i*step)] for i in range(40)]
so=to=0
for v,d in sample:
    h,dl,sn,b=con.execute("select header,coalesce(dateline,''),coalesce(source_note,''),body_text from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
    tk=re.findall(r"[A-Za-z]+"," ".join([h,dl,sn,b]))
    so+=near(tk,strict_c,strict_second); to+=near(tk,tol_c,tol_second)
print(f"NEXUS LITERAL SHARE (token regex, window 25 tokens, 40 evenly spaced of {n}): STRICT {so} of 40; TOLERANT {to} of 40")
json.dump(sample,open("work/nexus_sample40.json","w"))
