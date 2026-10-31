import sqlite3,re,collections,json
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
ED2="('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
FAM='corrupt OR bribe OR briberi OR kickback OR payoff OR venal OR embezzl OR malfeas OR misappropri OR nepot OR payola'
hits=sorted(con.execute(f"SELECT c.volume_id,c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0 AND c.volume_id NOT IN {ED2}",(FAM,)).fetchall())
print("FAMILY hits (apparatus excluded, Ed2 excluded):",len(hits))
json.dump(hits,open("work/family_hits.json","w"))
dates={ (v,d):x for v,d,x in con.execute("select volume_id,document_id,date_iso from document_dates")}
den=collections.Counter(); 
for v,d in con.execute(f"select volume_id,document_id from document_cache where is_front_matter=0 and is_editorial_note=0 and volume_id not in {ED2}"):
    x=dates.get((v,d)); 
    if x: den[x[:3]+"0s"]+=1
num=collections.defaultdict(collections.Counter)
undated=0
for v,d in hits:
    x=dates.get((v,d))
    if x: num[x[:3]+"0s"][v]+=1
    else: undated+=1
print("decade | N hits | M dated non-apparatus docs | per 1,000 | top volume share")
for dec in sorted(den):
    if dec in num or den[dec]>3000:
        n=sum(num[dec].values()); tv=num[dec].most_common(1)[0] if n else ("",0)
        print(f"{dec} | {n} of {den[dec]} | {1000*n/den[dec]:.1f} | {tv[0]} {tv[1]} of {n}")
print("undated hits:",undated)
# literal share on evenly spaced 40
strict=re.compile(r"\b(corruption|corrupt|bribe|bribery|kickback|payoff|venal|embezzlement|nepotism|malfeasance|misappropriation|payola)\b",re.I)
toler=re.compile(r"corrupt\w*|brib\w*|kickback\w*|pay-?off\w*|venal\w*|embezzl\w*|nepot\w*|malfeas\w*|misappropriat\w*|payola",re.I)
n=len(hits); step=n/40
sample=[hits[int(i*step)] for i in range(40)]
s_ok=t_ok=0; rows=[]
for v,d in sample:
    h,dl,sn,b=con.execute("select header,coalesce(dateline,''),coalesce(source_note,''),body_text from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()
    txt=re.sub(r"\s+"," "," ".join([h,dl,sn,b]))
    ms=strict.search(txt); mt=toler.search(txt)
    s_ok+=bool(ms); t_ok+=bool(mt)
    m=mt or ms
    ctx=txt[max(0,m.start()-110):m.end()+110] if m else ""
    rows.append((v,d,bool(ms),bool(mt),ctx))
print(f"LITERAL SHARE (regex over header+dateline+source_note+body_text, whitespace-collapsed, case-insensitive Python re; 40 evenly spaced of {n}): STRICT {s_ok} of 40; TOLERANT {t_ok} of 40")
json.dump(rows,open("work/sample40.json","w"))
for r in rows: print(r[0]+"/"+r[1],"S" if r[2] else "-","T" if r[3] else "-","|",r[4])
