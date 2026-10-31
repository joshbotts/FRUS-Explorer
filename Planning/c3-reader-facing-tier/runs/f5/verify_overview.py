import re,sys
sys.path.insert(0,'/Users/jbotts/frus-analysis/c3f/runs/f5')
from quotes import norm
txt=open('overview.md').read()
big=" ".join(norm(open(f'docs/{l.strip().split("/")[0]}__{l.strip().split("/")[1]}.txt').read()) for l in open('collection_set.txt') if l.strip())
qs=[]
for line in txt.split("\n"):
    qs+=re.findall(r'"([^"\n]+)"',line)
bad=[]; n=0
for q in qs:
    q2=norm(q).strip(' .,;')
    if len(q2)<10: continue
    n+=1
    if q2 not in big: bad.append(q)
print("straight-quoted strings >=10 chars:",n,"not found verbatim in the 31 documents:",len(bad))
for b in bad: print("  ?",b[:140])
# citations in overview vs collection
import json
col=json.load(open('collection.fruscollection'))
inc={(e['volumeId'],e['documentId']) for e in col['entries'] if e['kind']=='document'}
cited=set(re.findall(r'historicaldocuments/([^/\s)]+)/(d\d+[a-z]?)',txt))
print("cited in overview:",len(cited),"not in collection:",sorted(cited-inc))
