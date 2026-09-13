# Search every evidence JSON under reframe/ (and llm-pass, chapter-context) for numeric values; read-only, stdlib.
import json, os, sys, gzip
S='/private/tmp/claude-501/-Users-jbotts-Development-FRUS-Explorer--claude-worktrees-234-feasibility-assessment-518fe5/1ccebcd5-11bc-42dd-8b13-b2025658e2f3/scratchpad'
roots=[S+'/reframe', S+'/llm-pass', S+'/chapter-context']
skip=('journal-results.json','/synthesis/','/critique/critique.json')
targets=[]
for a in sys.argv[1:]:
    targets.append(float(a))
def match(v,t):
    if isinstance(v,bool): return False
    if isinstance(v,(int,float)):
        if t==int(t) and abs(t)>=100: return v==t
        return abs(v-t) <= max(abs(t)*0.0005, 0.00051)
    return False
cache={}
for root in roots:
    for dp,dn,fn in os.walk(root):
        if 'swiftcheck' in dp: continue
        for f in fn:
            p=os.path.join(dp,f)
            if any(s in p for s in skip): continue
            if not f.endswith('.json'): continue
            if os.path.getsize(p)>60_000_000: continue
            try: d=json.load(open(p))
            except Exception: continue
            hits=[]
            def w(o,path):
                if isinstance(o,dict):
                    for k,v in o.items(): w(v,path+'/'+str(k))
                elif isinstance(o,list):
                    if len(o)>5000: return
                    for i,v in enumerate(o): w(v,path+'[%d]'%i)
                else:
                    for t in targets:
                        if match(o,t): hits.append((t,path,o))
            w(d,'')
            for h in hits[:6]:
                print('%s\t%s\t%s\t%s'%(h[0],p.replace(S+'/',''),h[1][:160],h[2]))
