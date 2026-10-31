# ctx.py file pattern [width]: print the header and +-width chars around each regex match (case-insensitive) in a dumped doc
import re,sys
t=open(sys.argv[1]).read(); w=int(sys.argv[3]) if len(sys.argv)>3 else 700
print('##',t.split('\n')[0][:160]); print('##',t.split('\n')[1][:80])
for m in re.finditer(sys.argv[2],t,re.I):
    print('...'+t[max(0,m.start()-w):m.end()+w].replace('\n',' ')+'...\n')
