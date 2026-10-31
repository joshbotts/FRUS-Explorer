from vec import *
fam='corrupt OR bribe OR briberi OR kickback OR payoff OR venal OR embezzl OR malfeas OR misappropri OR nepot OR payola'
scope=set((v,d) for v,d in con.execute("SELECT c.volume_id,c.document_id FROM frus_documents f JOIN document_cache c ON c.rowid=f.rowid WHERE frus_documents MATCH ? AND c.is_front_matter=0 AND c.is_editorial_note=0",(fam,)))
print("scope = documents matching the corruption-family FTS query (apparatus excluded):",len(scope))
literal=re.compile(r"corrupt|brib|graft|kickback|payoff|venal|embezzl|nepot|scandal",re.I)
anchors={"China 1947 Wedemeyer":("frus1947v07","d582"),"Hawaii 1892 Stevens":("frus1894app2","d172"),"Cuba 1922 White to Secretary":("frus1922v01","d864"),
"Vietnam 1967 Calhoun on corruption":("frus1964-68v05","d258"),"Lockheed 1975 Akins-Sultan":("frus1969-76ve09p2","d161"),"Haiti 1979 Habib-Salomon":("frus1977-80v23","d257")}
import pickle
res={}
for name,a in anchors.items():
    rows=flagged(a,scope,literal,25)
    res[name]=rows
    print("\n### ANCHOR",name,a,"date",(joined(a) or ['','',''])[2])
    for r in rows:
        print(r[0],f"{r[1][0]}/{r[1][1]}",*r[2:])
pickle.dump(res,open("work/neighbors.pkl","wb"))
