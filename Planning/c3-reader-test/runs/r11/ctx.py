# print regex contexts from a raw dump: ctx.py file regex [width]
import re,sys
t=open(sys.argv[1]).read(); w=int(sys.argv[3]) if len(sys.argv)>3 else 400
for m in list(re.finditer(sys.argv[2],t,re.I))[:6]:
    print("...",t[max(0,m.start()-w):m.end()+w].replace("\n"," "),"...\n")
