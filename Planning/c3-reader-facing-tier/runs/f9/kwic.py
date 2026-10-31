import sys,re
pat=re.compile(sys.argv[1],re.I)
for f in sys.argv[2:]:
    t=re.sub(r'\s+',' ',open(f).read())
    print('===',f.split('/')[-1], t[t.find('HEADER:')+8:t.find('HEADER:')+120].split('DATELINE')[0])
    sents=re.split(r'(?<=[.;])\s+',t)
    for s in sents:
        if pat.search(s): print('  *',s[:500])
