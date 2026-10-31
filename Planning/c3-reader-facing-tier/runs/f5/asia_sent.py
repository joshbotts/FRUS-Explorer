import sys,re
R=re.compile(r"\b(Asia\w*|Far East\w*|Japan\w*|China|Chinese|Korea\w*|Vietnam\w*|Viet-?Nam\w*|Indochin\w*|Philippin\w*|Indonesia\w*|Thai\w*|Burm\w*|Taiwan|Formosa|Pacific|Laos|Lao|Cambodia\w*|Malay\w*|Singapore)\b")
K=re.compile(r"(USIA|USIS|information|propaganda|psychological|cultural|exchange|prestige|image|opinion|neutralis|attitude|audience|Voice of America|radio|film)",re.I)
n=int(sys.argv[1]); 
for a in sys.argv[2:]:
    v,d=a.split('/'); t=open(f"docs/{v}__{d}.txt").read(); t=t[t.index('BODY:')+5:]
    t=re.sub(r'\s+',' ',t)
    sents=re.split(r'(?<=[.;:?!])\s+(?=[A-Z0-9“"(])',t)
    hits=[s for s in sents if R.search(s) and K.search(s)]
    print("=====",a,len(hits),"of",len(sents),"sentences have region+info terms")
    # choose the n with most key terms
    hits.sort(key=lambda s:-(len(K.findall(s))+len(R.findall(s))))
    for s in hits[:n]: print("  -",s[:600])
