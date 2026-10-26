# Came-from channel over the scope, by document date band, with decimal keys glossed ONLY where the
# document's own date (document_dates.date_iso) falls in a glossable span of decimal-class-labels.json.
# SQL: SELECT s.volume_id, s.document_id, s.rule, dd.date_iso, ds.citation_era, ds.decimal_class, ds.raw_text
#      FROM s LEFT JOIN document_dates dd ON dd.volume_id=s.volume_id AND dd.document_id=s.document_id
#      LEFT JOIN document_sources ds ON ds.volume_id=s.volume_id AND ds.document_id=s.document_id
import sqlite3, json, collections, re
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
con.execute("CREATE TEMP TABLE s(volume_id TEXT, document_id TEXT, rule TEXT)")
for l in open("raw/scope_all.tsv"):
    v,d,r,_=l.rstrip("\n").split("\t"); con.execute("INSERT INTO s VALUES(?,?,?)",(v,d,r))
L=json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/decimal-class-labels.json"))
sched={s["id"]:s for s in L["schedules"]}
spans=L["coverage"]["glossableYears"]
def gloss(key, year):
    sp=[x for x in spans if x["startYear"]<=year<=x["endYear"]]
    if not sp: return None
    s=sched[sp[0]["scheduleId"]]
    m=re.match(r"^(\d)(\d\d[a-z]?)\.?(\w*)",key)
    if not m: return None
    cl,co,su=m.groups()
    cname=s["countries"].get(co)
    clname=s["classes"].get(cl)
    if cname is None or clname is None: return None
    subj=""
    if su and s.get("subjects") and cl in s["subjects"]:
        subj=s["subjects"][cl].get(su,"?")
    return "%s | %s | %s"%(clname,cname,subj or "-")
rows=con.execute("""SELECT s.volume_id, s.document_id, s.rule, dd.date_iso, ds.citation_era, ds.decimal_class, ds.raw_text
 FROM s LEFT JOIN document_dates dd ON dd.volume_id=s.volume_id AND dd.document_id=s.document_id
 LEFT JOIN document_sources ds ON ds.volume_id=s.volume_id AND ds.document_id=s.document_id""").fetchall()
band=collections.Counter(); era=collections.Counter(); gl=collections.Counter(); nogl=collections.Counter()
for v,d,r,dt,e,dc,raw in rows:
    y=int(dt[:4]) if dt else None
    b = "pre-1906-08" if dt and dt<"1906-08-15" else ("1906-08..1910-07" if dt and dt<"1910-08-01" else ("1910-08..1949" if y and y<=1949 else ("1950-1963" if y and y<=1963 else ">1963")))
    band[b]+=1; era[(b,e or "NO SOURCE ROW")]+=1
    if e=="decimal" and dc and y:
        g=gloss(dc,y)
        if g: gl[(dc[:6] if '.' in dc else dc, g)]+=1
        else: nogl[(b,dc[:3])]+=1
print("DATE BANDS (document_dates.date_iso):",sorted(band.items()))
print("CAME-FROM ERA BY BAND:"); [print("  ",k,n) for k,n in sorted(era.items())]
print("GLOSSED DECIMAL KEYS (top 30, key truncated to 6 chars):"); [print("  ",n,k) for k,n in gl.most_common(30)]
print("decimal rows glossed:",sum(gl.values()),"not glossed:",sum(nogl.values()), nogl.most_common(10))
