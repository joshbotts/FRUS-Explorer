import sys,re,glob
pat=re.compile(sys.argv[2],re.I); w=int(sys.argv[3]) if len(sys.argv)>3 else 300
for a in sys.argv[1].split(','):
    v,d=a.split('/')
    t=open(f"docs/{v}__{d}.txt").read()
    t=re.sub(r'\s+',' ',t)
    print('###',a,len(t))
    last=-1
    for m in pat.finditer(t):
        if m.start()<last: continue
        s=max(0,m.start()-w); e=min(len(t),m.end()+w); last=e
        print('  ...',t[s:e],'...')
