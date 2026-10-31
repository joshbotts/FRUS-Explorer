import re,sqlite3
ov=open("overview.md").read()
body=ov.split("## Documents cited")[0]
qs=[l.rstrip("\n").split("\t") for l in open("quotes.tsv")]
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
quotes=re.findall(r"“([^”]+)”|\"([^\"]+)\"",body)
for a,b in quotes:
    q=a or b
    hit=[x[0] for x in qs if q.rstrip(".,") in x[3]]
    if not hit:
        # check against any collection doc
        found=[]
        for v,d in [l.split() for l in open("coll.txt")]+[["frus1955-57v09","d190"]]:
            t=c.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()[0]
            if q.rstrip(".,") in t: found.append(v+"/"+d)
        print("NOT IN Q-LIST:",repr(q),"| found verbatim in:",found)
    else: print("ok",hit[0],repr(q[:60]))
bl=ov.split("**1. What FRUS answers directly.**")[1].split("**2.")[0]
print("part1 words",len(bl.split()))
nums=re.findall(r"\b(\d[\d,–\-]*|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fifteen|eighteen|hundred|million|half|third)\b",body,re.I)
print(sorted(set(n.lower() for n in nums)))
