import json, re, sqlite3, sys
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
con=sqlite3.connect("file:"+DB+"?mode=ro", uri=True)
def norm(s): return re.sub(r'[^a-z0-9]','',s.lower())
def doc_text(v,d):
    r=con.execute("SELECT header,dateline,source_note,body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    if r is None: return None
    return "".join(x or "" for x in r)
def check(quote, v, d):
    t=doc_text(v,d)
    if t is None: return ("NO SUCH ROW", [])
    nt=norm(t)
    segs=[s for s in re.split(r'…|\.\.\.|\[\.\.\.\]', quote) if norm(s)]
    pos=0; offs=[]
    for s in segs:
        ns=norm(s); i=nt.find(ns,pos)
        if i<0: return ("FAIL at segment %r"%s[:50], offs)
        offs.append(i); pos=i+len(ns)
    return ("OK", offs)
ov=open("/Users/jbotts/frus-analysis/c3s/runs/s7/overview.md",encoding="utf-8").read()
# every passage inside curly or straight double quotes
passages=re.findall(r'“([^”]+)”|"([^"]+)"', ov)
passages=[a or b for a,b in passages]
print("quoted passages in overview.md:",len(passages))
for i,p in enumerate(passages,1): print(" P%02d |%s|"%(i,p))
# attribution map (overview citation -> pair), from the memo's trace M13 / the URL beside each quotation
attr={
 "The alleged corruption of the arbitral commission which awarded those claims is Blanco’s pretext for the proposed bad faith of his government.":("frus1875v01","d199"),
 "and have been met by vague promises, and still more vague allegations of corruption on the part of individuals":("frus1875v02","d393"),
 "serves to reaffirm earlier certainty of corrupt and inept practices, both political and economic":("frus1947v07","d582"),
 "fear that the Central Government contemplates bleeding their island to support the tottering and corrupt Nanking machine and I think their fears well founded":("frus1947v07","d582"),
 "many US reporters, when they come across any corruption or graft, play up the cases, making the US public believe that the entire Chinese Government is corrupt":("frus1948v07","d43"),
 "seriously endanger the whole U.S. position in Korea, and threaten to discredit, not only the aid program in Korea, but the Mutual Security program as a whole":("frus1961-63v22","d202"),
 "The underlying fact is that all hands agree the situation in Korea is not good":("frus1961-63v22","d204"),
 "Earlier in the day he had decided not to raise this subject with General Ky because he did not want to urge on Ky a step which might precipitate a coup":("frus1964-68v04","d215"),
 "There is no doubt in his mind that there is widespread disgust with corruption and that it shakes confidence in the government and in the integrity of the elections":("frus1964-68v04","d215"),
 "has become a key obstacle to pacification":("frus1964-68v05","d258"),
 "I do not think it would be wise for us to seek such control":("frus1964-68v05","d258"),
 "coming when Strauss was Defense Minister paved the way for the sale of the Starfighter to the FRG":("frus1969-76ve15p2","d292"),
 "if the whole issue is kept unsolved with the names of the officials involved remaining in doubt, democracy in Japan may suffer a fatal blow":("frus1969-76ve12","d218"),
 "terminate or severely curtail our arms sales and human rights efforts and repeal the foreign bribery and Arab boycott laws":("frus1977-80v03","d152"),
 "GVN Corruption 1967":("frus1964-68v05","d258"),
}
print("\n== overview document quotations, segment-strict against the exact cited pair")
nq=0; nok=0
for p in passages:
    if p in attr:
        v,d=attr[p]; res,offs=check(p,v,d); nq+=1; nok+=(res=="OK")
        print(" %-4s %s/%s offs=%s |%s|"%(res,v,d,offs,p[:70]))
    else:
        print(" TERM (no document attributed) |%s|"%p)
print("overview: %d document quotations, %d OK"%(nq,nok))
print("\n== collection excerpts")
col=json.load(open("/Users/jbotts/frus-analysis/c3s/runs/s7/collection.fruscollection",encoding="utf-8"))
ne=0; neok=0
for e in col["entries"]:
    if e["kind"]=="excerpt":
        res,offs=check(e["text"],e["volumeId"],e["documentId"]); ne+=1; neok+=(res=="OK")
        print(" %-4s %s/%s offs=%s |%s|"%(res,e["volumeId"],e["documentId"],offs,e["text"][:70]))
print("collection: %d excerpts, %d OK"%(ne,neok))
# cross-corpus control: is any overview quotation findable in a DIFFERENT row too (would it matter for mis-citation)?
print("\n== for each overview quotation, how many rows of the whole index hold segment 1 (FTS phrase on first 6 words)")
for p,(v,d) in attr.items():
    words=re.findall(r"[A-Za-z0-9']+",p)[:6]
    phr='"'+" ".join(words)+'"'
    try:
        n=con.execute("SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH ?",(phr,)).fetchone()[0]
    except Exception as ex: n="err "+str(ex)
    print(" %s/%s phrase %s -> %s rows"%(v,d,phr,n))
