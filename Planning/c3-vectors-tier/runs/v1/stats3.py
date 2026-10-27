# stats3.py: literal-share audit of the 'national security' and 'prosper' FTS families (sample 40, evenly spaced from the sorted hit list)
import re
from h import *
c=con()
ED2="('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"
def hitlist(q,lo,hi):
    return sorted(c.execute("""SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
      WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN %s AND dd.date_iso>=? AND dd.date_iso<?"""%ED2,(q,lo,hi)).fetchall())
def text(v,d):
    r=c.execute("SELECT header||' '||ifnull(dateline,'')||' '||ifnull(source_note,'')||' '||body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()[0]
    return re.sub(r"\s+"," ",r)
INST=r"(?:\s+(?:council|act|advis[eo]r\w*|affairs|action|study|decision|agency|files|staff|archive\w*|directive|resolution|planning|review|policy|information|adviser|memorandum|presidential|study memorandum)\b)"
strict=re.compile(r"national security",re.I)
tol=re.compile(r"national[\s,\-()\.]+securit(?:y|ies)",re.I)
nonin=re.compile(r"national[\s,\-()\.]+securit(?:y|ies)(?!%s)"%INST,re.I)
def audit(label,q,lo,hi,rx_list):
    L=hitlist(q,lo,hi); step=len(L)/40.0; S=[L[int(i*step)] for i in range(40)]
    res=[0]*len(rx_list)
    for v,d in S:
        t=text(v,d)
        for i,rx in enumerate(rx_list): res[i]+=bool(rx.search(t))
    print("%s: hit list %d; sample 40 (every %.1fth): %s"%(label,len(L),step," ; ".join("%s %d of 40"%(n,r) for (n,_),r in zip(rx_list_names[label],res))))
rx_list_names={}
A=[("STRICT 'national security'",strict),("TOLERANT",tol),("NON-INSTITUTIONAL (not followed by Council/Act/Adviser/Affairs/Action/Study/Decision/Agency/Files/Staff...)",nonin)]
for lab,q,lo,hi in [("Cuba docs 1947-1989 [(cuba OR cuban) AND \"national security\"]",'(cuba OR cuban) AND "national security"',"1947","1990"),
                    ("Mexico docs 1947-1989 [(mexico OR mexican) AND \"national security\"]",'(mexico OR mexican) AND "national security"',"1947","1990"),
                    ("Cuba docs 1870-1946 [(cuba OR cuban) AND \"national security\"]",'(cuba OR cuban) AND "national security"',"1870","1947")]:
    rx_list_names[lab]=[(n,r) for n,r in A]; audit(lab,q,lo,hi,[r for n,r in A])
P=[("STRICT 'prosperity'",re.compile(r"prosperity",re.I)),("TOLERANT prosper(ity|ous|ing|ed|s)?",re.compile(r"prosper(?:ity|ous|ing|ed|s)?\b",re.I))]
for lab,q,lo,hi in [("Cuba docs 1870-1946 [(cuba OR cuban) AND prosper]","(cuba OR cuban) AND prosper","1870","1947"),("Cuba docs 1947-1989 [(cuba OR cuban) AND prosper]","(cuba OR cuban) AND prosper","1947","1990"),("Mexico docs 1870-1946 [(mexico OR mexican) AND prosper]","(mexico OR mexican) AND prosper","1870","1947")]:
    rx_list_names[lab]=P; audit(lab,q,lo,hi,[r for n,r in P])
