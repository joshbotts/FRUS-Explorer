import sqlite3, re, json
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
con=sqlite3.connect(DB, uri=True)
def norm(s): return re.sub(r'[^a-z0-9]','',s.lower())
def rowtext(v,d):
    r=con.execute("SELECT header, coalesce(dateline,''), coalesce(source_note,''), body_text, is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    if r is None: return None
    return r[0]+r[1]+r[2]+r[3], r[4], r[5]
def check(q,v,d):
    rt=rowtext(v,d)
    if rt is None: return ("NO ROW",[])
    text=norm(rt[0]); segs=[norm(s) for s in re.split(r'…|\.\.\.|\[\.\.\.\]',q)]; segs=[s for s in segs if s]
    pos=0; offs=[]
    for s in segs:
        i=text.find(s,pos)
        if i<0: return ("FAIL",offs+[(s[:40],-1)])
        offs.append(i); pos=i+len(s)
    return ("OK",offs)
# overview quotations mapped to pairs (memo trace / overview citation)
ovq=[
 (1,"reactionaries","frus1947v07","d628"),
 (2,"party corruption","frus1947v07","d628"),
 (3,"conditional upon Korean performance","frus1961-63v22","d221"),
 (4,"the Administration’s position","frus1964-68v05","d395"),
 (5,"We must do everything possible to keep this quiet","frus1969-76ve15p2","d293"),
 (6,"POL Northrop and Lockheed","frus1969-76ve09p2","d161"),
 (10,"corrupt","frus1961-63v22","d297"),
 (15,"corrupt management","frus1947v07","d617"),
 (16,"reactionaries","frus1947v07","d628"),
 (17,"earlier certainty of corrupt and inept practices","frus1947v07","d582"),
 (18,"those reactionaries in the Chinese Government who have been counting on substantial American support regardless of their actions and party corruption would have cause to conclude that they were right","frus1947v07","d628"),
 (19,"The information received in Shanghai serves to reaffirm earlier certainty of corrupt and inept practices, both political and economic.","frus1947v07","d582"),
 (20,"It is precisely because he knows the Government to be corrupt and inefficient, he says, that he has repeatedly asked for American aid","frus1948v07","d322"),
 (21,"the Administration’s position","frus1964-68v05","d395"),
 (22,"meet criticism in the U.S.","frus1964-68v06","d134"),
 (23,"We cannot have perfection.","frus1964-68v06","d31"),
 (24,"no country Asia more diligent in prosecuting corruption than GVN","frus1958-60v01","d267"),
 (25,"There was unanimous agreement that a visible and credible anti-corruption effort would help a great deal in improving the Administration’s position, and in building a more effective GVN.","frus1964-68v05","d395"),
 (26,"We cannot have perfection. We have corruption here.","frus1964-68v06","d31"),
 (27,"graft, corruption and fraud","frus1961-63v22","d202"),
 (28,"corrupt","frus1961-63v22","d297"),
 (29,"The extent and depth of graft, corruption and fraud in the major institutions of Korean society today","frus1961-63v22","d202"),
 (30,"Make it absolutely clear that U.S. assistance in the future, above a minimum maintenance level, will be conditional upon Korean performance","frus1961-63v22","d221"),
 (31,"Who is to decide who is corrupt?","frus1961-63v22","d297"),
 (32,"an international agreement to curtail such practices","frus1969-76ve12","d219"),
 (33,"At the same time we have concluded that corruption has been on the increase.","frus1969-76ve09p2","d122"),
 (34,"We must do everything possible to keep this quiet.","frus1969-76ve15p2","d293"),
 (35,"I hope the Government of Japan can support the United States proposal for an international agreement to curtail such practices","frus1969-76ve12","d219"),
 (36,"corrupt dictatorship","frus1977-80v15","d68"),
 (37,"Eradication of the corruption","frus1977-80v15","d80"),
 (38,"corrupt dictatorship that has systemically violated human rights","frus1977-80v15","d68"),
 (39,"Eradication of the corruption which has characterized the Somocist dictatorship","frus1977-80v15","d80"),
 (40,"It’s not primarily his corruption, his human rights record, or anything else he has done.","frus1977-80v15","d83"),
]
print("== overview quotations (document-attributed) ==")
ok=0
for n,qt,v,d in ovq:
    r=check(qt,v,d); ok+= r[0]=="OK"
    print(f"#{n:2d} {v}/{d} {r[0]} offsets={r[1]} :: {qt[:70]}")
print("overview document quotations checked:",len(ovq),"OK:",ok)
# non-document quoted strings
print("non-document quoted strings (search terms, controls, euphemism examples, collection name): #7 Department of State, #8 United States, #9 corruption, #11 corruption, #12 commissions, #13 agents' fees, #14 squeeze, #41 corruption, #42 bribery, #43-45 corruption/corrupt/corrupted, #46 collection name")
# also check the 'euphemism' examples exist somewhere in the 28 (informational)
pairs=[tuple(l.strip().split("|")) for l in open("/Users/jbotts/frus-analysis/c3s/runs/s8/raw/set.txt") if l.strip()]
for term in ["commissions","agents' fees","agents’ fees","squeeze"]:
    hits=[f"{v}/{d}" for v,d in pairs if norm(term) in norm(rowtext(v,d)[0])]
    print("  euphemism example",repr(term),"present in set documents:",hits)
print("== collection excerpts ==")
c=json.load(open("/Users/jbotts/frus-analysis/c3s/runs/s8/collection.fruscollection"))
ex=[e for e in c["entries"] if e["kind"]=="excerpt"]; okx=0
for i,e in enumerate(ex,1):
    r=check(e["text"],e["volumeId"],e["documentId"]); okx+= r[0]=="OK"
    print(f"X{i:2d} {e['volumeId']}/{e['documentId']} {r[0]} offsets={r[1]} :: {e['text'][:70]}")
print("excerpts:",len(ex),"OK:",okx)
# also: exact (unnormalised) substring of body_text, as the session's verify did
print("== exact substring of body_text (session's own test) ==")
for i,e in enumerate(ex,1):
    b=con.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",(e["volumeId"],e["documentId"])).fetchone()[0]
    print(f"X{i:2d} exact_count={b.count(e['text'])}")
