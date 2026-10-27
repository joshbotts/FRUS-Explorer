import sqlite3, re, collections
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
pats={
 "national security":re.compile(r"national[\s\-]+security",re.I),
 "security of the United States|American security|U.S. security":re.compile(r"security of the (?:United States|U\.?\s?S\.?)|(?:American|U\.?\s?S\.?) security",re.I),
 "defense/defence":re.compile(r"\bdefen[sc]e\b",re.I),
 "sugar":re.compile(r"\bsugars?\b",re.I),
 "investment(s)|American capital":re.compile(r"\binvestments?\b|American capital",re.I),
 "independence":re.compile(r"\bindependence\b",re.I),
 "intervention|intervene":re.compile(r"\binterven(?:tion|e|ed|ing)\b",re.I),
 "communist|soviet|missile":re.compile(r"\bcommunists?\b|\bsoviets?\b|\bmissiles?\b",re.I),
}
setA=[l.rstrip("\n").split("\t") for l in open("setA.tsv")]
tot=collections.Counter(); hit={k:collections.Counter() for k in pats}; first={}
for v,d,dt,t in setA:
    r=db.execute("select header||' '||coalesce(dateline,'')||' '||coalesce(source_note,'')||' '||body_text from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()[0]
    r=re.sub(r"\s+"," ",r); dec=dt[:3]+"0s"; tot[dec]+=1
    for k,p in pats.items():
        if p.search(r):
            hit[k][dec]+=1
            if k=="national security" and k not in first: first[k]=(v,d,dt)
decs=sorted(tot)
print("decade docs:",{d:tot[d] for d in decs})
for k in pats: print(k,{d:f"{hit[k][d]}/{tot[d]}" for d in decs})
print("first national security in Set A:",first)
