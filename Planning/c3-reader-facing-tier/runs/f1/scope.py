import sqlite3,re,json
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
INFO='(USIA OR USIS OR "information program" OR "psychological warfare" OR "psychological strategy" OR "psychological operations" OR "voice of america" OR "public diplomacy" OR "cultural exchange" OR "information agency" OR "information activities" OR "image of the united states" OR "american image" OR "U.S. image")'
GEO='(asia OR asian OR "far east" OR japan OR japanese OR china OR chinese OR korea OR korean OR vietnam OR vietnamese OR indochina OR philippines OR indonesia OR thailand OR laos OR cambodia OR burma OR malaya OR malaysia OR singapore OR taiwan OR australia OR pacific)'
SQL=f"""SELECT d.volume_id, d.document_id FROM frus_documents f JOIN document_cache d ON d.volume_id=f.volume_id AND d.document_id=f.document_id
JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
WHERE frus_documents MATCH '{INFO} AND {GEO}' AND d.is_front_matter=0 AND d.is_editorial_note=0
AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2') AND dd.date_iso>='1945-01-01' AND dd.date_iso<'1981-01-01' ORDER BY d.volume_id, d.document_id"""
hits=c.execute(SQL).fetchall()
print("SQL:",SQL.replace("\n"," "))
print("scope set:",len(hits),"docs in",len(set(v for v,_ in hits)),"volumes")
json.dump(hits,open('scope_hits.json','w'))
step=len(hits)/40; sample=[hits[int(k*step)] for k in range(40)]
SEP=r'[\s\-,().]+'
info_strict=re.compile(r'\b(USIA|USIS|information program|psychological warfare|psychological strategy|psychological operations|voice of america|public diplomacy|cultural exchange|information agency|information activities|image of the united states|american image|U\.S\. image)\b',re.I)
def tol(words):
    return SEP.join(w+r'\w*' for w in words)
fam=[['USIA'],['USIS'],['information','program'],['psychological','warfare'],['psychological','strateg'],['psychological','operation'],['voice','of','america'],['public','diplomac'],['cultural','exchange'],['information','agenc'],['information','activit'],['image','of','the','united','states'],['american','image'],['U','S','image']]
info_tol=re.compile(r'\b('+'|'.join(tol(f) for f in fam)+r')',re.I)
geo=re.compile(r'\b(asia\w*|far east|japan\w*|chin\w*|korea\w*|viet\s*-?nam\w*|indochin\w*|philippine\w*|indonesia\w*|thai\w*|lao\w*|cambodia\w*|burm\w*|malay\w*|singapore|taiwan\w*|australia\w*|pacific)\b',re.I)
ns=nt=ng=0;miss=[]
for v,d in sample:
    r=c.execute("SELECT header||' '||coalesce(dateline,'')||' '||coalesce(source_note,'')||' '||body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()[0]
    t=re.sub(r'\s+',' ',r)
    s=bool(info_strict.search(t)); tt=bool(info_tol.search(t)); g=bool(geo.search(t))
    ns+=s and g; nt+=tt and g; ng+=g
    if not (tt and g): miss.append((v,d,s,tt,g))
print(f"sample of {len(sample)}: STRICT both families {ns} of 40; TOLERANT both {nt} of 40; geo family alone {ng} of 40")
print("misses:",miss)
