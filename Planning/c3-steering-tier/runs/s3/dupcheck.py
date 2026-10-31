import json, sqlite3, re, difflib
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
con=sqlite3.connect("file:"+DB+"?mode=ro",uri=True)
nd=json.load(open("vectors_out.json"))["nd_hits"]
def txt(k):
    r=con.execute("SELECT header, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?",k).fetchone()
    return r
agree=0; out=[]
for h,a,b in nd:
    ra,rb=txt(tuple(a)),txt(tuple(b))
    ta=re.sub(r"\s+"," ",ra[1]); tb=re.sub(r"\s+"," ",rb[1])
    ratio=difflib.SequenceMatcher(None,ta[:6000],tb[:6000],autojunk=False).ratio()
    same=ratio>=0.90; agree+=same
    out.append((h,"/".join(a),"/".join(b),ra[2],rb[2],round(ratio,3),same,ra[0][:60],rb[0][:60]))
for o in out: print(*o,sep=" | ")
print("pairs",len(nd),"texts agree (ratio>=0.90 over first 6000 chars):",agree)
json.dump(out,open("dupcheck.json","w"),indent=1)
