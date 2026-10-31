import sqlite3,json,re
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
R="/Users/jbotts/frus-analysis/c3f/runs/f10/"
eap=open(R+"eap_vols.txt").read().strip().split(","); scope=open(R+"scope105.txt").read().strip().split(",")
info="frus1917-72PubDipv06 frus1917-72PubDipv07 frus1917-72PubDipv08 frus1977-80v30 frus1955-57v09 frus1961-63v25".split()
ph=lambda L: ",".join("?"*len(L))
pairs=[tuple(p) for p in json.load(open(R+"refuter/pairs.json"))['cited']]
def fts(match,vols=None):
    q="select f.volume_id,f.document_id from frus_documents f join document_cache d on d.volume_id=f.volume_id and d.document_id=f.document_id where frus_documents match ? and d.is_front_matter=0 and d.is_editorial_note=0"; a=[match]
    if vols: q+=f" and f.volume_id in ({ph(vols)})"; a+=vols
    return set(db.execute(q,a).fetchall())
# Every MATCH the log ran (lines 9,10,14,15,19,22,38-41,67,68,72-77,84,86,88,89,131-133), without the display LIMIT (reach = returned by the query)
Q={
 "L9 region words, 6 info vols": ('(Asia OR Asian OR Vietnam OR Japan OR Japanese OR Korea OR Korean OR China OR Chinese OR Philippines OR Indonesia OR Thailand OR Taiwan OR Laos OR Cambodia OR Pacific)',info),
 "L14 psychological warfare (all)": ('"psychological warfare"',None),
 "L15 hearts and minds (all)": ('"hearts and minds"',None),
 "L19 census family (EAP99)": ('"information program" OR "information agency" OR USIA OR USIS OR propaganda OR "psychological warfare" OR "psychological" OR "cultural exchange" OR "educational exchange" OR "Voice of America"',eap),
 "L22 USIS snippets (EAP99)": ('"United States Information Service" OR "USIS"',eap),
 "L38 NEAR Asians psychology (all)": ('NEAR((Asian OR Asians OR Orientals) (psychology OR psychological OR attitude OR attitudes OR audience OR audiences OR mentality), 12)',None),
 "L39 Asians AND propaganda.. (EAP99)": ('(Asian OR Asians) AND (propaganda OR psychological OR "information program" OR USIS OR USIA)',eap),
 "L40 bandwagon/wait and see (105)": ('bandwagon OR "wait and see" OR "lose face" OR "save face"',scope),
 "L41 USIA/PSB/OCB (EAP99)": ('"United States Information Agency" OR USIA OR "Psychological Strategy Board" OR "Operations Coordinating Board"',eap),
 "L67 Bandung (105)": ('Bandung AND (propaganda OR information OR USIA OR USIS OR "psychological")',scope),
 "L68 USIS/information program (7 vols)": ('USIS OR "information program" OR "cultural program" OR "cultural exchange" OR "educational exchange"','frus1958-60v18,frus1961-63v22,frus1964-68v29p2,frus1955-57v23p1,frus1969-76v19p2,frus1964-68v26,frus1958-60v17'.split(',')),
 "L72 Boxer indemnity (EAP99)": ('"Boxer indemnity"',eap),
 "L73 OWI (EAP99)": ('"Office of War Information"',eap),
 "L74 American prestige (EAP99)": ('"American prestige" OR "prestige of the United States" OR "United States prestige"',eap),
 "L75 missionaries (EAP99)": ('"American missionaries" OR "missionary schools"',eap),
 "L76 cultural relations (EAP99)": ('"cultural relations"',eap),
 "L77 Boxer AND education (EAP99)": ('"Boxer indemnity" AND (education OR educational OR universities OR scholarships OR students OR "good will" OR goodwill)',eap),
 "L84/86/88/89/133 Family A (105)": ('"United States Information Agency" OR "United States Information Service" OR USIA OR USIS',scope),
 "L84/131 propaganda (105)": ('propaganda',scope),
 "L84/132 prestige (105)": ('prestige',scope),
}
hits={}
for k,(m,v) in Q.items():
    try: hits[k]=fts(m,v)
    except Exception as e: print("QUERY ERROR",k,e); hits[k]=set()
# heading query (L8): header LIKE on PubDipv06
hdr=set(db.execute("select volume_id,document_id from document_cache where volume_id='frus1917-72PubDipv06' and is_front_matter=0 and is_editorial_note=0 and (header like '%Asia%' or header like '%Vietnam%' or header like '%Japan%' or header like '%China%' or header like '%Korea%' or header like '%Philipp%' or header like '%Indones%' or header like '%Thai%')").fetchall())
hits["L8 header LIKE (PubDipv06)"]=hdr
# the displayed lists, with the log's LIMITs and bm25 order (what the session could have READ)
def fts_top(match,vols,lim):
    q="select f.volume_id,f.document_id from frus_documents f join document_cache d on d.volume_id=f.volume_id and d.document_id=f.document_id where frus_documents match ? and d.is_front_matter=0 and d.is_editorial_note=0"; a=[match]
    if vols: q+=f" and f.volume_id in ({ph(vols)})"; a+=vols
    q+=" order by bm25(frus_documents) limit ?"; a.append(lim)
    return [tuple(r) for r in db.execute(q,a).fetchall()]
disp={
 "L9 top60": fts_top(Q["L9 region words, 6 info vols"][0],info,60),
 "L22 top25": fts_top(Q["L22 USIS snippets (EAP99)"][0],eap,25),

 "L39 cand100": fts_top(Q["L39 Asians AND propaganda.. (EAP99)"][0],eap,100),
 "L40 cand80": fts_top(Q["L40 bandwagon/wait and see (105)"][0],scope,80),
 "L41 cand112": fts_top(Q["L41 USIA/PSB/OCB (EAP99)"][0],eap,112),
 "L67 cand40": fts_top(Q["L67 Bandung (105)"][0],scope,40),
 "L68 cand56": fts_top(Q["L68 USIS/information program (7 vols)"][0],Q["L68 USIS/information program (7 vols)"][1],56),
 "L77 cand40": fts_top(Q["L77 Boxer AND education (EAP99)"][0],eap,40),
}
print("REACH: for each cited pair, the logged queries that RETURN it (any limit) / the displayed candidate lists (with the log's LIMIT*4 for ctx.py) that contain it")
for p in pairs:
    ret=[k for k,s in hits.items() if p in s]
    dis=[k for k,l in disp.items() if p in l]
    print(f"{p[0]}/{p[1]}: returned by {len(ret)} :: {ret}")
    print(f"      displayed-candidates: {dis}")
json.dump({f"{p[0]}/{p[1]}":{"returned":[k for k,s in hits.items() if p in s],"displayed":[k for k,l in disp.items() if p in l]} for p in pairs},open(R+"refuter/reach.json","w"),indent=1)
