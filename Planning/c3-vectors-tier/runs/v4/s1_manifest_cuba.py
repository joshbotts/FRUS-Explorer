import json
m=json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))
t=[v for v in m if 'cuba' in v['title'].lower()]
g=[v for v in m if 'cuba' in v.get('tags',[])]
print("title has Cuba:",len(t)); 
for v in t: print(" ",v['volumeId'],'|',' '.join(v['title'].split()),'|',v['dateRange']['earliest'][:10],v['dateRange']['latest'][:10])
print("tagged cuba:",len(g),"of",len(m))
