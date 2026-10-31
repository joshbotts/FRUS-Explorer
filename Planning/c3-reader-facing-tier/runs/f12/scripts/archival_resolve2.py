# Targeted resolution: authority rows for lot 61D385, RG 306 rows naming the scope's entries/series; series-facts for any naIds found.
import json,re
B="/Applications/FRUS Explorer.app/Contents/Resources/"
ca=json.load(open(B+"collection-authority.json"))["collections"]
sf=json.load(open(B+"series-facts-index.json"))
pats=["61D385","A1–42","A1-42","P–104","P-104","UD WW 257","UD WW 193","P–207","P-207","Director’s Subject Files","Office of the Director","DIRCTR","Office of Policy and Plans","JUSPAO","Kissinger Office","Marks Paper","National Security File"]
found=set()
for c in ca:
    s=json.dumps(c,ensure_ascii=False)
    if any(p in s for p in pats) and (c.get("recordGroup") in ("306","59",None)):
        print("AUTH",s[:700]); 
        for m in re.findall(r'"naId": "(\d+)"',s): found.add(m)
def facts(n):
    r=sf["byNaId"].get(n)
    if not r: return None
    out={}
    for k,v in r.items():
        lg=sf["legend"]["keys"].get(k,{})
        f=lg.get("field",k); into=lg.get("into")
        if into and isinstance(v,int): v=sf[into][v]
        elif into and isinstance(v,list): v=[sf[into][i] if isinstance(i,int) else i for i in v]
        out[f]=v
    return out
for n in sorted(found|{"2544398"}):
    print("FACTS",n,json.dumps(facts(n),ensure_ascii=False)[:700])
