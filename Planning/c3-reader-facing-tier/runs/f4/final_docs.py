import json,sqlite3,re
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
m={v['volumeId']:v for v in json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))}
H=[
("Before 1945: a precedent under another name",[("frus1924v01","d540")]),
("Persuasion as the companion of aid, 1949–1953",[("frus1949v09","d558"),("frus1950v06","d50"),("frus1952-54v12p2","d403")]),
("Keeping the American hand low, 1955–1968",[("frus1955-57v23p2","d50"),("frus1955-57v22","d447"),("frus1961-63v23","d289"),("frus1917-72PubDipv07","d32"),("frus1964-68v27","d386")]),
("How the practitioners judged the results, 1964–1966",[("frus1964-68v01","d122"),("frus1964-68v26","d106"),("frus1964-68v02","d160"),("frus1964-68v29p2","d46"),("frus1917-72PubDipv07","d85")]),
("Retrenchment, reassurance and China, 1969–1978",[("frus1917-72PubDipv08","d31"),("frus1917-72PubDipv08","d58"),("frus1917-72PubDipv08","d99"),("frus1917-72PubDipv08","d146"),("frus1917-72PubDipv08","d149"),("frus1969-76v38p2","d105"),("frus1977-80v30","d79"),("frus1977-80v30","d152")]),
]
out=[];seen=set()
SQL="SELECT volume_id,document_id,document_number,header,dateline,is_front_matter,is_editorial_note,length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?"
for h,l in H:
    for v,d in l:
        assert (v,d) not in seen; seen.add((v,d))
        r=c.execute(SQL,(v,d)).fetchone(); assert r and r[5]==0 and r[6]==0,(v,d)
        t=re.sub(r'\s+',' ',m[v]['title']).strip()
        cit=t if t.startswith('Foreign Relations') else t
        num=r[2] or d[1:]
        out.append({'heading':h,'v':v,'d':d,'num':num,'header':re.sub(r'\s+',' ',r[3]),'dateline':r[4],'title':t,'len':r[7]})
        print(v,d,num,'|',t[:110],'|',(r[4] or '')[:32])
json.dump(out,open('final_docs.json','w'),ensure_ascii=False,indent=1)
print(len(out),'docs; ed2 present:',any(x['v'].endswith('Ed2') for x in out))
