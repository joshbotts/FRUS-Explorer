import json,os,re
R="/Applications/FRUS Explorer.app/Contents/Resources/"
files=["collection-authority.json","central-files-index.json","volume-sources-index.json","presidential-library-catalog.json","external-citation-index.json","series-facts-index.json","accession-series-index.json","lot-claimants-index.json"]
targets={"40967285":"NAID Subject Files of the Director","1257679":"NAID Subject Files (Policy and Plans)","2839191":"NAID OCB Files lot 62 D 430","193936":"NAID RFK Papers AG General Correspondence","50827304":"NAID Marks Work Files (series)","50809179":"NAID Papers of Leonard H. Marks (collection)","1487627":"NAID D Files lot 81D113","1127750":"NAID Vietnamese Public Opinion Surveys","721251":"NAID International Survey Research Reports","1257657":"NAID Research Reports"}
strs={"62D430":"lot 62 D 430","81D113":"lot 81D113","A1-42":"Entry A1-42","A1–42":"Entry A1–42","UD WW 257":"Entry UD WW 257","P-14":"Entry P-14","P–14":"Entry P–14","Leonard H. Marks":"Marks papers","Robert F. Kennedy":"RFK papers","72A5121":"accession 72A5121"}
def walk(o,path=""):
    if isinstance(o,dict):
        for k,v in o.items(): yield path+"/"+str(k),k,v; yield from walk(v,path+"/"+str(k))
    elif isinstance(o,list):
        for i,v in enumerate(o): yield path+"[%d]"%i,i,v; yield from walk(v,path+"[%d]"%i)
hits={t:[] for t in list(targets)+list(strs)}
for fn in files:
    p=R+fn
    if not os.path.exists(p): print("MISSING",fn); continue
    J=json.load(open(p)); print("%-36s %9.1f KB  top:%s"%(fn,os.path.getsize(p)/1024,(list(J.keys())[:8] if isinstance(J,dict) else "list[%d]"%len(J))))
    for path,k,v in walk(J):
        sv=str(v) if not isinstance(v,(dict,list)) else None
        sk=str(k)
        for t in targets:
            if (sv is not None and sv==t) or sk==t: hits[t].append((fn,path))
        for t in strs:
            if (sv is not None and t.lower() in sv.lower()) or t.lower() in sk.lower(): hits[t].append((fn,path))
# series-facts and others: print the parent object for each NAID hit (first few)
cache={}
def get(fn,path):
    J=cache.setdefault(fn,json.load(open(R+fn))); o=J
    for part in re.findall(r"/([^/\[\]]+)|\[(\d+)\]",path):
        o=o[part[0]] if part[0] else o[int(part[1])]
    return o
def parent(path): 
    m=re.match(r"(.*)(/[^/\[\]]+|\[\d+\])$",path); return m.group(1) if m else ""
print()
for t,lab in list(targets.items())+list(strs.items()):
    h=hits[t]; print("=== %s (%s): %d hits"%(t,lab,len(h)))
    seen=set()
    for fn,path in h[:12]:
        pp=parent(path)
        if (fn,pp) in seen: continue
        seen.add((fn,pp))
        try: o=get(fn,pp)
        except Exception as e: o="ERR %s"%e
        print("   %s %s => %s"%(fn,pp,json.dumps(o,ensure_ascii=False)[:700] if not isinstance(o,list) else "list[%d] "%len(o)+json.dumps(o[:3],ensure_ascii=False)[:500]))
    if len(h)>12: print("   ... %d more"%(len(h)-12))
