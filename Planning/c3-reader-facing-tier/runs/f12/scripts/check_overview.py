# checks: (1) every double-quoted span in overview.md (len>=12) is a substring of some verified quote in quotes.json (after splitting on ' … ');
# (2) every history.state.gov URL in overview.md names a pair in collection.fruscollection. No SQL.
import re,json
R="/Users/jbotts/frus-analysis/c3f/runs/f12"
ov=open(R+"/overview.md").read(); qs=[q[2] for q in json.load(open(R+"/quotes.json"))]
col=json.load(open(R+"/collection.fruscollection")); pairs={(e["volumeId"],e["documentId"]) for e in col["entries"] if e["kind"]=="document"}
exc={e["text"] for e in col["entries"] if e["kind"]=="excerpt"}
bad=0; n=0
pos=[i for i,ch in enumerate(ov) if ch=='"']
print("straight double quotes:",len(pos),"(even)" if len(pos)%2==0 else "(ODD)")
spans=[ov[pos[i]+1:pos[i+1]] for i in range(0,len(pos)-1,2)]
NONQUOTE={"soft power","image of the United States","psychological","public diplomacy","Public Opinion Research","RG 305","Restricted - Possibly","Department of State","the region","American soft power in East Asia and the Pacific: how officials judged it, 1950–1977"}
for m in spans:
    if m in NONQUOTE: print("term/name, not a document quotation:",m); continue
    for part in m.split(" … "):
        n+=1
        if not any(part in q for q in qs): print("UNVERIFIED:",part[:90]); bad+=1
print("quoted spans",n,"unverified",bad)
urls=set(re.findall(r"historicaldocuments/([^/\s)]+)/(d\d+\w*)",ov))
miss=[u for u in urls if u not in pairs]; print("cited docs",len(urls),"missing from collection",miss)
print("excerpts in collection",len(exc),"all in verified quotes:",all(e in qs for e in exc))
