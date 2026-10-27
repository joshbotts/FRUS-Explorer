# kwic.py VOL/DOC REGEX [WIDTH] [MAX]: print windows around regex matches from docs/VOL__DOC.txt
import sys,re
v,d=sys.argv[1].split("/"); rx=re.compile(sys.argv[2],re.I); W=int(sys.argv[3]) if len(sys.argv)>3 else 300; M=int(sys.argv[4]) if len(sys.argv)>4 else 8
t=open("docs/%s__%s.txt"%(v,d)).read(); t=re.sub(r"\s+"," ",t)
last=-10**9; n=0
for m in rx.finditer(t):
    if m.start()-last<W: continue
    last=m.start(); n+=1
    print("[%d] ...%s..."%(m.start(),t[max(0,m.start()-W):m.start()+W])); print()
    if n>=M: break
print("matches shown",n,"doc chars",len(t))
