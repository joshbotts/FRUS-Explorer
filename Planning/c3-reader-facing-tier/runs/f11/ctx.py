import re,sys
f,pat=sys.argv[1],sys.argv[2]; w=int(sys.argv[3]) if len(sys.argv)>3 else 700
t=re.sub(r"\s+"," ",open("docs/%s.txt"%f).read().split("BODY:",1)[1])
n=0
for m in re.finditer(pat,t):
    print("[%s @%d]"%(f,m.start()),t[max(0,m.start()-w//3):m.start()+w]); print("---"); n+=1
    if n>=int(sys.argv[4] if len(sys.argv)>4 else 3): break
if n==0: print("NO MATCH",f,pat)
