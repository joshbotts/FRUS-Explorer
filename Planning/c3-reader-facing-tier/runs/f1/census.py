import sqlite3,re,json,sys
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
hits=json.load(open('scope_hits.json'))
SEP=r'[\s\-,().]+'
fam=[['USIA'],['USIS'],['USIE'],['information','program'],['psychological','warfare'],['psychological','strateg'],['psychological','operation'],['voice','of','america'],['public','diplomac'],['cultural','exchange'],['information','agenc'],['information','activit'],['image','of','the','united','states'],['american','image'],['U','S','image']]
info_tol=re.compile(r'\b('+'|'.join(SEP.join(w+r'\w*' for w in f) for f in fam)+r')',re.I)
geo=re.compile(r'\b(asia\w*|far east|japan\w*|chin\w*|korea\w*|viet\s*-?nam\w*|indochin\w*|philippine\w*|indonesia\w*|thai\w*|lao\w*|cambodia\w*|burm\w*|malay\w*|singapore|taiwan\w*|australia\w*|pacific)\b',re.I)
usi=re.compile(r'\bUSI\b')
out=[];n=0
for k,(v,d) in enumerate(hits):
    t=re.sub(r'\s+',' ',' '.join(x or '' for x in c.execute("SELECT header,dateline,source_note,body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()))
    a=bool(info_tol.search(t)); g=bool(geo.search(t)); u=bool(usi.search(t))
    out.append((v,d,a,g,u))
    if k%500==0: print(k,flush=True)
json.dump(out,open('census.json','w'))
both=sum(1 for o in out if o[2] and o[3]); onlyusi=sum(1 for o in out if not o[2] and o[4])
print(f"TOLERANT census (incl. USIE): {both} of {len(out)} contain an info-family literal and a geo literal; {sum(1 for o in out if not o[2])} lack an info literal, of which {onlyusi} contain the bare token USI")
