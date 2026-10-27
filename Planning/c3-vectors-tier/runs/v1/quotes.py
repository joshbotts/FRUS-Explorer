# quotes.py: extract each quotation verbatim from document_cache.body_text by (start phrase .. end phrase); writes quotes.json
import re,json
from h import *
c=con()
Q=[
("Q01","frus1874","d552","It is almost contiguous to the United States.",None),
("Q02","frus1874","d552","it would afford a large and lucrative market","productions of this country"),
("Q03","frus1874","d552","In short, the state of Cuba is the one great cause of perpetual solicitude","foreign relations of the United States."),
("Q04","frus1898","d498","our great commerce with Cuba has thus been practically destroyed",None),
("Q05","frus1898","ch83","The present condition of affairs in Cuba is a constant menace to our peace","enormous expense."),
("Q06","frus1898","ch83","The right to intervene may be justified by the very serious injury","devastation of the island."),
("Q07","frus1902","d273","nor in any manner authorize or permit any foreign power","control over any portion of said island"),
("Q08","frus1918","d333","Cuba’s greatest aid to the United States in the prosecution of the war would be economic rather than military",None),
("Q09","frus1934v05","d170","the stipulations of that agreement with regard to the naval station of Guantánamo shall continue in effect",None),
("Q10","frus1941v07","d134","our interest in the Cuban situation for economic and defense reasons is such",None),
("Q11","frus1948v09","d420","we could, by manipulation of tariff or quota affecting sugar, plunge the entire island into poverty",None),
("Q12","frus1950v02","d440","Cuba, lying 90 miles to the south of Key West, Florida, is of great strategic importance","source of sugar"),
("Q13","frus1958-60v06","d362","our retaliatory instruments, such as GATT and the sugar quota, are likely to be used",None),
("Q14","frus1958-60v06","d567","Since we have crossed one Rubicon with our sugar and oil actions",None),
("Q15","frus1958-60v06","d532","Amendment of the preferential sugar quota act","Cuba’s quota."),
("Q16","frus1961-63v11","d21","Geography doesn’t mean that much.",None),
("Q17","frus1961-63v11","d21","I don’t think there is a military problem here.",None),
("Q18","frus1961-63v11","d18","this kind of a base is intolerable and not acceptable",None),
("Q19","frus1969-76ve10","d205","We have a vital interest: 1. In preventing the introduction into Cuba of strategic weapons.",None),
("Q20","frus1969-76ve10","d205","to promote meanwhile the realization of subsidiary and lesser U.S. interests in improved relations with Cuba",None),
("Q21","frus1977-80v23","d18","to gain access to U.S. markets and technology to stimulate its economy",None),
("Q22","frus1977-80v01","d129","It presents no direct threat to us.",None),
("Q23","frus1977-80v01","d129","In contrast to the 1962 crisis, no nuclear threat to the United States is involved.",None),
("Q24","frus1981-88v03","d10","Cuba has been a sore spot in the US-Soviet relationship since the 1962 missile crisis",None),
("Q25","frus1952-54v04","d331","It is the policy, and in the best interest, of the United States to assist Cuba to maintain its economic and political stability",None),
("Q26","frus1961-63v11","d21","this is a domestic, political problem",None),
("Q28","frus1958-60v06","d535","it would be impossible to carry on friendly relations with the Castro Government in Cuba","help bring about his overthrow"),
("Q29","frus1977-80v23","d18","U.S. Objectives are to get Cuba to demonstrate","restraint in Puerto Rico, Latin America, and Africa"),
("Q30","frus1902","d273","wise and beneficient legislation aiming to stimulate the commerce between the two countries",None),
("Q31","frus1933v05","d241","must be determined primarily by its rights and obligations as set forth in the first five articles of the treaty",None),
("Q32","frus1934v05","d154","in continuation of the policy adopted in the Convention of Commercial Reciprocity of 1902",None),
("Q27","frus1961-63v11","d21","it doesn’t make any difference if you get blown up by an ICBM","ninety miles away."),
]
out=[]
for qid,v,d,a,b in Q:
    body=c.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0",(v,d)).fetchone()[0]
    rx=re.escape(a) if b is None else re.escape(a)+r".{0,1500}?"+re.escape(b)
    m=re.search(rx,body,re.S|re.I if False else re.S)
    if not m:
        # try whitespace-flexible
        flex=r"\s+".join(re.escape(w) for w in a.split()) if b is None else r"\s+".join(re.escape(w) for w in a.split())+r".{0,1500}?"+r"\s+".join(re.escape(w) for w in b.split())
        m=re.search(flex,body,re.S)
    if not m: print(qid,"NOT FOUND",v,d,a[:50]); continue
    txt=m.group(0); ok=txt in body
    print(qid,v+"/"+d,"found; exact-substring:",ok,"; has newline:","\n" in txt,"; double-space:","  " in txt,"; chars",len(txt))
    out.append({"id":qid,"volumeId":v,"documentId":d,"text":txt,"bodyChars":len(body)})
json.dump(out,open("quotes.json","w"),ensure_ascii=False,indent=1)
