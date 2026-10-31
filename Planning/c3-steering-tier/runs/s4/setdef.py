import json,sqlite3,re
t=json.load(open("work/titles.json"))
S=[
("F1","frus1944v06","d292"),("F1","frus1947v07","d553"),("F1","frus1947v07","d582"),("F1","frus1947v07","d570"),("F1","frus1948v07","d322"),("F1","frus1949v08","d576"),("F1","frus1949v08","d131"),
("F2","frus1920v03","d66"),("F2","frus1922v01","d852"),("F2","frus1922v01","d864"),("F2","frus1922v01","d872"),("F2","frus1947v05","d23"),("F2","frus1961-63v22","d221"),
("F3","frus1958-60v01","d63"),("F3","frus1964-68v04","d145"),("F3","frus1964-68v05","d185"),("F3","frus1964-68v05","d258"),("F3","frus1964-68v05","d395"),("F3","frus1969-76v08","d191"),
("F4","frus1894app1","d27"),("F4","frus1894app2","d172"),("F4","frus1894app2","d199"),("F4","frus1894app2","d316"),
("F5","frus1969-76ve11p1","d159"),("F5","frus1969-76ve09p2","d135"),("F5","frus1969-76ve09p2","d161"),("F5","frus1969-76ve15p2","d292"),("F5","frus1969-76ve15p2","d293"),("F5","frus1969-76ve12","d218"),("F5","frus1969-76ve12","d224"),
("F6","frus1961-63v20","d422"),("F6","frus1977-80v24","d14"),("F6","frus1977-80v23","d257"),("F6","frus1977-80v23","d264"),
]
json.dump(S,open("work/set.json","w"))
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
for f,v,d in S:
    r=con.execute("select c.header,t.date_iso,c.is_front_matter,c.is_editorial_note,length(c.body_text) from document_cache c left join document_dates t on t.volume_id=c.volume_id and t.document_id=c.document_id where c.volume_id=? and c.document_id=?",(v,d)).fetchone()
    print(f,v,d,r[1],r[2],r[3],r[4],"|",re.sub(r"\s+"," ",r[0])[:70],"|",t[v][:110])
