import re,json,sqlite3,collections
RUN="/Users/jbotts/frus-analysis/c3f/runs/f7/"; W=RUN+"work/"
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
db=sqlite3.connect(f"file:{DB}?mode=ro",uri=True)
ov=open(RUN+"overview.md",encoding="utf-8").read()
cited=[]
for m in re.finditer(r"historicaldocuments/(frus[\w\-]+)/(d\w+)",ov):
    p=(m.group(1),m.group(2))
    if p not in cited: cited.append(p)
coll=json.load(open(RUN+"collection.fruscollection"))
docs=[(e["volumeId"],e["documentId"]) for e in coll["entries"] if e["kind"]=="document"]
print("cited pairs (distinct, by URL):",len(cited))
print("cited but not in collection:",[p for p in cited if p not in docs])
print("in collection but not cited:",[p for p in docs if p not in cited])
# saved result sets
def pairs_in(fname,pat):
    s=open(W+fname,encoding="utf-8").read()
    return set((m.group(1),m.group(2)) for m in re.finditer(pat,s))
sets={
 "scope2 (header LIKE, PubDip v06-08)":pairs_in("scope2.out",r"^(frus[\w\-]+)/(d\w+)\|"),
 "scope4 (header FTS, 74 EA vols)":pairs_in("scope4.out",r"^(frus[\w\-]+)\|(d\w+)\|"),
 "cand_image (FTS ranked)":pairs_in("cand_image.out",r"^(frus[\w\-]+)/(d\w+) \|"),
 "cand_eff (FTS ranked)":pairs_in("cand_eff.out",r"^(frus[\w\-]+)/(d\w+) \|"),
 "cand_img2 (FTS ranked)":pairs_in("cand_img2.out",r"^(frus[\w\-]+)/(d\w+) \|"),
 "belief (FTS oriental-mind family, 79 vols)":pairs_in("belief_share.out",r"^(frus[\w\-]+)/(d\w+) strict"),
 "scope5 (header LIKE, 4 later vols)":pairs_in("scope5.out",r"^(frus[\w\-]+)/(d\w+)\|"),
}
# fix scope2/scope5 patterns (multiline)
sets["scope2 (header LIKE, PubDip v06-08)"]=set(re.findall(r"(?m)^(frus[\w\-]+)/(d\w+)\|",open(W+"scope2.out").read()))
sets["scope5 (header LIKE, 4 later vols)"]=set(re.findall(r"(?m)^(frus[\w\-]+)/(d\w+)\|",open(W+"scope5.out").read()))
sets["scope4 (header FTS, 74 EA vols)"]=set(re.findall(r"(?m)^(frus[\w\-]+)\|(d\w+)\|",open(W+"scope4.out").read()))
for k in ["cand_image (FTS ranked)","cand_eff (FTS ranked)","cand_img2 (FTS ranked)"]:
    f={"cand_image (FTS ranked)":"cand_image.out","cand_eff (FTS ranked)":"cand_eff.out","cand_img2 (FTS ranked)":"cand_img2.out"}[k]
    sets[k]=set(re.findall(r"(?m)^(frus[\w\-]+)/(d\w+) \|",open(W+f).read()))
sets["belief (FTS oriental-mind family, 79 vols)"]=set(re.findall(r"(?m)^(frus[\w\-]+)/(d\w+) strict",open(W+"belief_share.out").read()))
for k,v in sets.items(): print(f"  result set {k}: {len(v)} pairs")
# vector-surfaced documents (vec2.out neighbour lists)
vec=set(re.findall(r"(frus[\w\-]+)/(d\w+)",open(W+"vec2.out").read()))
print("  vec2 neighbour-list pairs (incl anchors):",len(vec))
# dump order
dump=[l.split("\t") for l in open(W+"dump_log.tsv") if l.strip()]
print("dump_log columns sample:",dump[0])
order={}
for i,l in enumerate(dump):
    key=l[0] if "/" in l[0] else (l[0]+"/"+l[1] if len(l)>1 else l[0])
    order.setdefault(key,i)
print("\nREACH per cited document:")
for v,d in cited:
    hits=[k for k,s in sets.items() if (v,d) in s]
    print(f"  {v}/{d}: text/heading sets={hits if hits else 'NONE'} | in vec2 lists={ (v,d) in vec } | dump order={order.get(v+'/'+d)}")
# re-run the four reproducible listing queries to confirm the saved sets
ea=[l.strip() for l in open(W+"ea_vols_list.txt") if l.strip()]
pd3=['frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08']; v79=ea+pd3+['frus1969-76v38p2','frus1977-80v30']
ph=lambda L:",".join("?"*len(L))
s2=set(db.execute(f"SELECT volume_id,document_id FROM document_cache WHERE volume_id IN ({ph(pd3)}) AND is_front_matter=0 AND is_editorial_note=0 AND (header LIKE '%Asia%' OR header LIKE '%Vietnam%' OR header LIKE '%Japan%' OR header LIKE '%Korea%' OR header LIKE '%Indonesia%' OR header LIKE '%Philippin%' OR header LIKE '%Thailand%' OR header LIKE '%China%' OR header LIKE '%Laos%' OR header LIKE '%Pacific%' OR header LIKE '%Taiwan%' OR header LIKE '%Australia%' OR header LIKE '%Cambodia%' OR header LIKE '%Malaysia%' OR header LIKE '%Singapore%' OR header LIKE '%Burma%')",pd3).fetchall())
print("\nre-run scope2:",len(s2),"== saved:",s2==sets["scope2 (header LIKE, PubDip v06-08)"])
q4='header:("information agency" OR "information service" OR "information program" OR "information policy" OR "psychological" OR propaganda OR "voice of america" OR usia OR usis OR "cultural" OR "public affairs" OR "public diplomacy" OR "educational exchange" OR "information activities" OR "information and cultural" OR "image of the united states")'
s4=set(db.execute(f"SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.volume_id IN ({ph(ea)}) AND d.is_front_matter=0 AND d.is_editorial_note=0",[q4]+ea).fetchall())
print("re-run scope4:",len(s4),"== saved:",s4==sets["scope4 (header FTS, 74 EA vols)"])
v4=['frus1969-76v38p2','frus1977-80v30','frus1964-68v33','frus1969-76v02']
s5=set(db.execute(f"SELECT volume_id,document_id FROM document_cache WHERE volume_id IN ({ph(v4)}) AND is_front_matter=0 AND is_editorial_note=0 AND (header LIKE '%Asia%' OR header LIKE '%Japan%' OR header LIKE '%Korea%' OR header LIKE '%Vietnam%' OR header LIKE '%Viet%' OR header LIKE '%China%' OR header LIKE '%Philippin%' OR header LIKE '%Pacific%' OR header LIKE '%Thailand%' OR header LIKE '%Indonesia%')",v4).fetchall())
print("re-run scope5:",len(s5),"== saved:",s5==sets["scope5 (header LIKE, 4 later vols)"], "| contains v38p2/d105:",("frus1969-76v38p2","d105") in s5, "| contains 77-80v30 d79,d81,d83:",[("frus1977-80v30",d) in s5 for d in ("d79","d81","d83")])
fam='"oriental mind" OR "asian mind" OR "asian psychology" OR "psychology of asians" OR "oriental psychology" OR "asiatic mind"'
sb=set(db.execute(f"SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.volume_id IN ({ph(v79)}) AND d.is_front_matter=0 AND d.is_editorial_note=0",[fam]+v79).fetchall())
print("re-run belief:",len(sb),"== saved:",sb==sets["belief (FTS oriental-mind family, 79 vols)"])
# does any MATCH query whose text we have return v38p2/d105?
for name,q,vols in [("scope1 predicate (all vols)",'"information agency" OR "information service" OR "information program" OR "psychological strategy" OR "psychological warfare" OR "voice of america" OR propaganda',None),("decade predicate (79)",'"information agency" OR usis OR usia OR "information service" OR "voice of america" OR "information program"',v79)]:
    if vols: r=db.execute(f"SELECT 1 FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.volume_id='frus1969-76v38p2' AND d.document_id='d105'",[q]).fetchone()
    else: r=db.execute("SELECT 1 FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.volume_id='frus1969-76v38p2' AND d.document_id='d105'",[q]).fetchone()
    print(f"  v38p2/d105 matched by {name}: {bool(r)} (count-only query in the log; lists no documents)")
