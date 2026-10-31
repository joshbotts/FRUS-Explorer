from vec_setup import *
import csv
con=sqlite3.connect("file:"+DB+"?mode=ro",uri=True)
scope=set()
for r in csv.DictReader(open("scan1.csv")):
    if r["volume_id"] not in ED2: scope.add((r["volume_id"],r["document_id"]))
literal=re.compile(r"corrupt\w*|brib\w*|graft|kick-?backs?|embezzl\w*|venal\w*|malfeasance|nepotism|cronyism|misappropriat\w*",re.I)
def joined(key):
    return con.execute("SELECT c.header,c.body_text,t.date_iso,c.is_front_matter,c.is_editorial_note FROM document_cache c LEFT JOIN document_dates t ON t.volume_id=c.volume_id AND t.document_id=c.document_id WHERE c.volume_id=? AND c.document_id=?",key).fetchone()
anchors=[("SAUDI-1974",("frus1969-76ve09p2","d122")),("PHIL-1950",("frus1950v06","d832")),("VIET-1967",("frus1964-68v05","d258")),
 ("HAITI-1978",("frus1977-80v23","d252")),("HOND-1975",("frus1969-76ve11p1","d159")),("KOREA-1961",("frus1961-63v22","d249")),("IRAN-1973",("frus1969-76v27","d45")),("CHINA-1943",("frus1943China","d202"))]
out=open("vec2.out","w")
for name,a in anchors:
    ad=(joined(a) or ("","","",0,0))[2] or ""
    out.write(f"\n### ANCHOR {name} {a[0]}/{a[1]} date={ad}\n")
    for h,key in nearest(a,25):
        row=joined(key)
        if row is None: out.write(f"{h:4d} {key[0]}/{key[1]} NOT IN THIS DATABASE https://history.state.gov/historicaldocuments/{key[0]}/{key[1]}\n"); continue
        header,body,date,fm,en=row
        date=date or ""
        out.write("%4d %s/%s %s %s %s %s%s | %s\n"%(h,key[0],key[1],date,"IN-SCOPE" if key in scope else "OUTSIDE","SAME-DECADE" if date[:3]==ad[:3] else "OTHER-DECADE","LITERAL" if literal.search(header+" "+body) else "ABSENT"," [APPARATUS]" if fm or en else "",header[:70]))
out.close()
