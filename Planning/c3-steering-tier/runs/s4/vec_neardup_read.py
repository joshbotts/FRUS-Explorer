import pickle,re,difflib,sqlite3
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
nd=pickle.load(open("work/neardups.pkl","rb"))
def get(k):
    r=con.execute("SELECT header,dateline,body_text FROM document_cache WHERE volume_id=? AND document_id=?",k).fetchone()
    return r[0],re.sub(r"\s+"," ",r[2])
ed2=lambda k:k[0].endswith("Ed2")
rows=[x for x in nd if not (ed2(x[1]) or ed2(x[2]))]
print("pairs below line:",len(nd),"; involving an Ed2 volume (known reprint, Ed2 suppressed):",len(nd)-len(rows),"; remaining:",len(rows))
out=[]
for h,a,b in rows:
    ha,ta=get(a); hb,tb=get(b)
    # ratio on the body, bounded
    r=difflib.SequenceMatcher(None,ta[:4000],tb[:4000],autojunk=False).quick_ratio() if len(ta)+len(tb)>0 else 0
    exact= ta==tb
    real=difflib.SequenceMatcher(None,ta[:2500],tb[:2500],autojunk=False).ratio()
    verdict="SAME TEXT" if (exact or real>=0.9) else "DIFFERENT TEXT"
    out.append((h,a,b,len(ta),len(tb),round(real,3),verdict,ha[:45],hb[:45]))
for o in out: print(*o,sep=" | ")
pickle.dump(out,open("work/neardup_read.pkl","wb"))
print("SAME:",sum(1 for o in out if o[6]=="SAME TEXT"),"DIFFERENT:",sum(1 for o in out if o[6]!="SAME TEXT"))
