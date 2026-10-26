# usage: read2.py vol/doc:start:end ...   prints raw/<vol>__<doc>.txt[start:end]; logs the span displayed to display_ledger.csv
import sys
led=open("display_ledger.csv","a")
for a in sys.argv[1:]:
    p,s,e=a.split(':'); v,d=p.split('/')
    t=open("raw/%s__%s.txt"%(v,d)).read(); s=int(s); e=min(int(e),len(t))
    led.write("%s,%s,%d,%d,%d\n"%(v,d,len(t),s,e)); print("=====",p,"[%d:%d] of %d"%(s,e,len(t))); print(t[s:e])
