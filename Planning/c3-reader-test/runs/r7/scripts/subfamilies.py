# For each "what was asked" sub-family, runs the FTS MATCH over the whole corpus (non-editorial-note rows), writes the hit list
# to out/subfam_<name>.tsv, and reports the count inside the core set (A|B) and inside channel A, by period.
import sqlite3, collections, json
R="/Users/jbotts/frus-analysis/c3/runs/r7/out/"
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
rows=[l.rstrip("\n").split("\t") for l in open(R+"core_set.tsv")][1:]
core={(v,d):(iso,a) for v,d,iso,a,b,p in rows}
fams = {
 "intl_obligations": 'NEAR(recogn* "international obligations", 20)',
 "obligations_any": 'NEAR(recogn* obligations, 15)',
 "elections": 'NEAR(recogn* election*, 15)',
 "free_elections": 'NEAR(recogn* "free elections", 20)',
 "constitutional": 'NEAR(recogn* constitution*, 15)',
 "consultation": 'NEAR(recogn* consult*, 15)',
 "effective_control": 'NEAR(recogn* "control", 15)',
 "popular_support": 'NEAR(recogn* "support of the people", 20) OR NEAR(recogn* "popular support", 20) OR NEAR(recogn* acquiescence, 15)',
 "civil_liberties": 'NEAR(recogn* "civil liberties", 20) OR NEAR(recogn* "civil rights", 20) OR NEAR(recogn* "freedom of the press", 20) OR NEAR(recogn* "political prisoners", 20)',
 "human_rights": 'NEAR(recogn* "human rights", 20)',
 "amnesty": 'NEAR(recogn* amnesty, 20)',
 "communist": 'NEAR(recogn* communis*, 20)',
 "nazi_axis": 'NEAR(recogn* nazi*, 20) OR NEAR(recogn* axis, 20)',
 "approval": 'NEAR(recogn* approval, 15) OR NEAR(recogn* approve, 15)',
 "treaty_1923": 'NEAR(recogn* "treaty of peace and amity", 30) OR NEAR(recogn* "1923 treaty", 30) OR NEAR(recogn* "article II", 30)',
 "bogota_resolution": 'NEAR(recogn* bogota, 30) OR NEAR(recogn* "resolution xxxv", 30) OR NEAR(recogn* "resolution 35", 30)',
 "estrada_tobar": 'NEAR(estrada doctrine, 20) OR NEAR(tobar doctrine, 20)',
 "intervention": 'NEAR(recogn* intervention, 15) OR NEAR(recogn* "internal affairs", 15)',
 "assurances": 'NEAR(recogn* assurances, 15) OR NEAR(recogn* undertakings, 15) OR NEAR(recogn* pledge*, 15) OR NEAR(recogn* commitments, 15)',
 "conditions": 'NEAR(recogn* conditions, 15) OR NEAR(recogn* condition, 15)',
 "withhold": 'NEAR(recogn* withh*, 10) OR NEAR(recogn* refus*, 10) OR NEAR(recogn* suspend*, 10) OR NEAR(recogn* deferr*, 10) OR NEAR(recogn* delay*, 10)',
 "resume_relations": '"resumption of diplomatic relations" OR "resume diplomatic relations" OR "resumption of relations" OR "resume relations" OR "continue diplomatic relations" OR "continuation of diplomatic relations" OR "continuance of diplomatic relations" OR "normal relations"',
}
def period(iso):
    y=int(iso[:4]) if iso[:4].isdigit() else 0
    if y<1909: return "1861-1908"
    if y<1921: return "1909-1920"
    if y<1933: return "1921-1932"
    if y<1943: return "1933-1942"
    if y<1952: return "1943-1951"
    if y<1961: return "1952-1960"
    if y<1969: return "1961-1968"
    if y<1977: return "1969-1976"
    return "1977-1988"
periods=["1861-1908","1909-1920","1921-1932","1933-1942","1943-1951","1952-1960","1961-1968","1969-1976","1977-1988"]
base=collections.Counter(period(iso) for (iso,a) in core.values()); baseA=collections.Counter(period(iso) for (iso,a) in core.values() if a=="1")
print("core A|B by period:", [ (p,base[p]) for p in periods]); print("core A by period:", [ (p,baseA[p]) for p in periods])
import os
summary=open(R+"subfamilies_summary.tsv","a")
for name,q in fams.items():
    if os.path.exists(R+f"subfam_{name}.tsv") and name!="estrada_tobar": continue
    hits=con.execute("SELECT volume_id, document_id FROM frus_documents WHERE frus_documents MATCH ? AND is_editorial_note=0", (q,)).fetchall()
    f=open(R+f"subfam_{name}.tsv","w")
    inc=collections.Counter(); nA=0; ncore=0
    for v,d in hits:
        k=(v,d); flag = k in core
        f.write(f"{v}\t{d}\t{int(flag)}\n")
        if flag:
            ncore+=1; inc[period(core[k][0])]+=1
            if core[k][1]=="1": nA+=1
    f.close()
    line=f"{name}\t{q}\t{len(hits)}\t{ncore}\t{nA}\t"+"\t".join(f"{inc[p]}/{base[p]}" for p in periods)
    print(line); summary.write(line+"\n"); summary.flush()
summary.close()
