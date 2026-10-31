import re, sqlite3, difflib, ast
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
def norm(k):
    r=con.execute("SELECT header||' '||body_text FROM document_cache WHERE volume_id=? AND document_id=?",k).fetchone()
    return re.sub(r"\s+"," ",r[0]).strip().lower() if r else None
lines=[l for l in open("vec3.out") if re.match(r"^\d+ \(",l)]
out=open("nd_read.out","w"); same=0; rows=[]
for l in lines:
    h,rest=l.split(" ",1); a,b=ast.literal_eval("["+rest.replace(") (","),(")+"]")
    ta,tb=norm(a),norm(b)
    if ta is None or tb is None: out.write(f"{h} {a} {b} MISSING\n"); continue
    # compare body after header number: strip leading "NNN." doc numbers
    ta2=re.sub(r"^\d+\.\s*","",ta); tb2=re.sub(r"^\d+\.\s*","",tb)
    if ta2==tb2: v="IDENTICAL"
    else:
        sm=difflib.SequenceMatcher(None,ta2[:6000],tb2[:6000],autojunk=False); v="ratio6000=%.3f lens=%d/%d"%(sm.ratio(),len(ta2),len(tb2))
    if v=="IDENTICAL": same+=1
    out.write(f"{h} {a[0]}/{a[1]} | {b[0]}/{b[1]} | {v}\n")
out.write(f"IDENTICAL pairs: {same} of {len(lines)}\n"); out.close()
