# usage: readdoc.py VOL:DOC [VOL:DOC ...] [--ctx N] -> saves full text to texts/, appends reading_log.tsv, prints recogn* context
import sqlite3,sys,re,os
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
args=[a for a in sys.argv[1:] if not a.startswith("--")]
ctx=600
for a in sys.argv[1:]:
    if a.startswith("--ctx="): ctx=int(a[6:])
SQL="SELECT volume_id, document_id, header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?"
pat=re.compile(r"recogni|condition|election|constitution|obligation|de facto|consult|junta|coup",re.I)
with open("reading_log.tsv","a") as log:
    for a in args:
        v,d=a.split(":")
        r=db.execute(SQL,(v,d)).fetchone()
        if not r: print("MISSING",v,d); continue
        body=r[5]; cap=len(body)
        path=f"texts/{v}__{d}.txt"
        with open(path,"w") as f:
            f.write(f"VOLUME: {v}\nDOCUMENT: {d}\nHEADER: {r[2]}\nDATELINE: {r[3]}\nSOURCE: {r[4]}\nLENGTH(body_text)={r[6]} captured={cap}\n----\n{body}")
        log.write(f"{v}\t{d}\t{r[6]}\t{cap}\t{path}\n")
        flat=" ".join(body.split())
        print(f"=== {v}/{d} | {' '.join((r[2] or '').split())[:90]} | {' '.join((r[3] or '').split())[:60]} | len={r[6]} captured={cap}")
        # print windows around matches, merged
        spans=[]
        for m in pat.finditer(flat):
            s,e=max(0,m.start()-ctx//2),min(len(flat),m.end()+ctx//2)
            if spans and s<=spans[-1][1]: spans[-1][1]=max(spans[-1][1],e)
            else: spans.append([s,e])
        shown=0
        for s,e in spans[:6]:
            print("   …"+flat[s:e]+"…"); shown+=e-s
            if shown>2500: break
