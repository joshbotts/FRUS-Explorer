import sys,re
f=sys.argv[1]; pat=re.compile(sys.argv[2],re.I); w=int(sys.argv[3]) if len(sys.argv)>3 else 500
t=open(f,encoding='utf8').read(); t=re.sub(r'\s+',' ',t)
last=-1; n=0
for m in pat.finditer(t):
    if m.start()<last: continue
    s=max(0,m.start()-w); e=min(len(t),m.end()+w); last=e; n+=1
    print(f"[{m.start()}] ...{t[s:e]}...\n")
    if n>=int(sys.argv[4] if len(sys.argv)>4 else 6): break
