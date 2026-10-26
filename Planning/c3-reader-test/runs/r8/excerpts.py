import sqlite3,re,json
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
# (id, vol, doc, start words, end words) -> raw span of body_text from start to end inclusive, whitespace inside allowed to vary
Q=[
("Q1","frus1913","d7","We hold, as I am sure","public conscience and approval."),
("Q2","frus1913","d1028","Mexico has a great and enviable future","honest constitutional government."),
("Q3","frus1917","d379","the desire which this Government has","entitled to recognition."),
("Q4","frus1920v01","d391","the elections to be held in Bolivia","before recognizing it."),
("Q5","frus1921v01","d238","in view of the fact that the election of Dr. Bautista Saavedra","Constitutional Government of that Republic."),
("Q6","frus1923v02","d345","will not recognize any other Government","constitutionally reorganized the country."),
("Q7","frus1930v01","d375","In reaching the conclusion to accord recognition","elections to regularize its status."),
("Q8","frus1932v05","d639","The Department cannot escape the conviction","resign the Presidency outright."),
("Q9","frus1936v05","d112","the United States should no longer be guided","fail to take"),
("Q10","frus1943v05","d486","Considerations of the security of the Hemisphere","unfriendly to the Allied cause played any part."),
("Q11","frus1943v05","d334","recognition of the new Government, if and when accorded","developments in Argentina."),
("Q29","frus1913","d7","We can have no sympathy with those","personal interests or ambition."),
("Q30","frus1913","d1028","(a) An immediate cessation of fighting","supporting the new administration."),
("Q12","frus1945v09","d1170","the seven man Junta in Venezuela","fulfill its international obligations."),
("Q13","frus1948v09","d115","Recognition of a government by the United States should imply","national interests would be served thereby."),
("Q14","frus1948v09","d89","The Bogotá Resolution was also intended","formal term “recognition”."),
("Q15","frus1950v02","d478","(1) Junta will honor","soon as practicable."),
("Q16","frus1961-63v12","d359","you should state clearly and emphatically","representative constitutional democracy."),
("Q17","frus1964-68v31","d132","In keeping with international practice","1965 Rio Conference."),
("Q18","frus1964-68v31","d512","Herein I shall seek to open dialogue","variant of Estrada Doctrine"),
("Q19","frus1969-76v21","d349","as to the question of recognition the issue has not arisen","but rather countries."),
("Q20","frus1977-80v24","d137","When we continue relations with a country","not been our practice to do so."),
("Q21","frus1947v08","d742","In all honesty we must take into account","meeting its international commitments, et cetera."),
("Q22","frus1958-60v05mSupp","es_d43","In view of the assurances set forth in your note","provisional Government of El Salvador."),
("Q23","frus1944v07","d231","it is almost incredible that any American regime","to this common effort"),
("Q24","frus1961-63v12","d421","It seems clear that the sharp reaction","leaders of the previous government and of APRA"),
("Q25","frus1946v11","d312","Likewise it is favorably impressed","international obligations will be fulfilled."),
("Q26","frus1949v02","d448","(1) all agree that there was no outside intervention","public statement to that effect."),
("Q27","frus1913","d1029","His Excellency Mr. Wilson is laboring under a serious delusion","tolerable in Central America."),
("Q28","frus1934v05","d199","In accordance with a policy, already announced","recognize General Martínez."),
]
out={}; log=open("excerpt_verify.tsv","w")
for qid,v,d,a,b in Q:
    body=db.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()[0]
    pa=r"\s+".join(map(re.escape,a.split())); pb=r"\s+".join(map(re.escape,b.split()))
    m=re.search(pa+r".*?"+pb,body,re.S)
    if not m: print(qid,v,d,"NOT FOUND"); log.write(f"{qid}\t{v}\t{d}\tNOT FOUND\n"); continue
    ex=m.group(0)
    pos=db.execute("SELECT instr(body_text,?) FROM document_cache WHERE volume_id=? AND document_id=?",(ex,v,d)).fetchone()[0]
    out[qid]={"volumeId":v,"documentId":d,"text":ex}
    log.write(f"{qid}\t{v}\t{d}\tinstr={pos}\tlen={len(ex)}\n")
    print(f"{qid} {v}/{d} instr={pos} len={len(ex)} :: {' '.join(ex.split())[:160]}")
json.dump(out,open("excerpts.json","w"),ensure_ascii=False,indent=1)
