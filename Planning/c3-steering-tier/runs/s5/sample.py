import sqlite3, json, re
db = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
hits = sorted(tuple(x) for x in json.load(open("core_hits.json")))
EXC = {"frus1951-54IranEd2","frus1969-76ve15p2Ed2"}
hits = [h for h in hits if h[0] not in EXC]
print("core hits after Ed2 suppression:", len(hits), "of 3096 before; excluded", 3096-len(hits))
n=40
idx=[int(i*len(hits)/n) for i in range(n)]
samp=[hits[i] for i in idx]
STRICT = re.compile(r"\b(corruption|corrupt|bribery|bribe|bribes|graft|embezzlement|kickbacks?|questionable payments|illicit payments)\b")
TOL = re.compile(r"(corrupt\w*|brib\w*|graft\w*|embezzl\w*|kickback\w*|(?:questionable|illicit)[\s\-,().]+payments?)", re.I)
s_ok=t_ok=0; out=[]
for v,d in samp:
    r=db.execute("SELECT header,coalesce(dateline,''),coalesce(source_note,''),body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    t=" ".join((r[0]+" "+r[1]+" "+r[2]+" "+r[3]).split())
    ms=bool(STRICT.search(t)); mt=TOL.search(t)
    s_ok+=ms; t_ok+= bool(mt)
    kw = t[max(0,mt.start()-130):mt.end()+130] if mt else ""
    out.append({"v":v,"d":d,"strict":ms,"tol":bool(mt),"kwic":kw})
json.dump(out,open("sample40.json","w"),indent=1)
print("STRICT",s_ok,"of",n,"TOLERANT",t_ok,"of",n)
for i,o in enumerate(out):
    print(i+1,o["v"]+"/"+o["d"],"S" if o["strict"] else "-", "T" if o["tol"] else "-","|",o["kwic"])
