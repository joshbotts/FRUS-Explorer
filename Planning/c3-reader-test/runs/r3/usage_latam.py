import json,re,collections
R='/Applications/FRUS Explorer.app/Contents/Resources/'
u=json.load(open(R+'collection-usage-index.json'))
pairs=[l.split() for l in open('/Users/jbotts/frus-analysis/c3/runs/r3/pairs.txt')]
S=sorted(set(p[0] for p in pairs)); vi={v:i for i,v in enumerate(u['volumes'])}
early=[v for v in S if re.match(r'frus19(1\d|2\d|3\d|4[0-5])',v)]
E={vi[v] for v in early}
print('early (<=1945) scope volumes:',len(early),early)
rx=re.compile(r'^8(1[2-9]|2[0-5]|3[1-9])\.0[01]')   # 1910-1949 schedule: class 8 + country 12-39 (Mexico..Dominican Rep.), subclass .00/.01
tot=collections.Counter(); allc=0
for e in u['classes']:
    key=u['classKeys'][e['k']]
    s=sum(n for n,v in zip(e['n'],e['v']) if v in E)
    if s: allc+=s
    if s and rx.match(key): tot[key]+=s
print('all class-keyed note citations in those volumes:',allc)
print('Latin American internal-affairs political keys (8[12-39].00/.01):',sum(tot.values()))
for k,n in tot.most_common(20): print(' ',k,n)
