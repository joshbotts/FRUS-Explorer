import json,sqlite3,re
RUN="/Users/jbotts/frus-analysis/c3f/runs/f6/"
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
eap=open(RUN+"eap_in.txt").read().strip(); info=open(RUN+"info_in.txt").read().strip(); jp=open(RUN+"jp_in.txt").read().strip()
cited=[tuple(p) for p in json.load(open("cited_pairs.json"))]
QA='(USIA OR USIS OR "Information Agency" OR "Information Service" OR "Voice of America" OR "information program" OR "psychological program" OR "psychological strategy" OR "cultural exchange" OR "educational exchange")'
# every full-text / heading query the log shows, with its IN-list and the LIMIT the session read (None = count only / full list)
queries=[
 ("cnt USIS",'"USIS"',eap,None,"count"),("cnt USIA",'"USIA"',eap,None,"count"),("cnt Voice of America",'"Voice of America"',eap,None,"count"),
 ("cnt information program",'"information program"',eap,None,"count"),("cnt psychological",'"psychological"',eap,None,"count"),("cnt propaganda",'"propaganda"',eap,None,"count"),
 ("cnt cultural exchange",'"cultural exchange"',eap,None,"count"),("cnt educational exchange",'"educational exchange"',eap,None,"count"),("cnt prestige",'"prestige"',eap,None,"count"),
 ("cnt hearts and minds",'"hearts and minds"',eap,None,"count"),("cnt soft power",'"soft power"',eap,None,"count"),("cnt image of the United States",'"image of the United States"',eap,None,"count"),
 ("cnt Asian mind",'"Asian mind"',eap,None,"count"),("cnt ZZZ",'"ZZZ_IMPOSSIBLE_ZZZ"',eap,None,"control"),("cnt Department of State",'"Department of State"',eap,None,"control"),
 ("header query",'header : (USIA OR USIS OR information OR psychological OR propaganda OR cultural OR educational OR "public diplomacy" OR "Voice of America" OR prestige)',eap,None,"heading list"),
 ("rank assessment",'(USIA OR USIS OR "information program" OR "information activities" OR "Voice of America" OR "psychological program" OR "cultural program") AND (effectiveness OR impact OR image OR attitudes) AND (Asian OR Asians OR "Far East")',eap,50,"ranked"),
 ("rank audience beliefs",'("Asian mind" OR "Asian psychology" OR "Oriental mind" OR "Asian mentality" OR "Asians are" OR "peoples of Asia" OR "Asian peoples") AND (propaganda OR information OR psychological OR USIA OR USIS OR prestige)',eap,30,"ranked"),
 ("rank exchange",'("hearts and minds" OR "Voice of America" OR "cultural exchange" OR "educational exchange" OR Fulbright OR "leader grant")',eap,30,"ranked"),
 ("rank info-set Asia",'(Asia OR Asian OR Vietnam OR Japan OR Japanese OR Korea OR China OR Chinese OR Thailand OR Philippines OR Indonesia OR Indochina OR Laos OR Pacific)',info,60,"ranked"),
 ("rank Japan a",'(USIS OR USIA OR "information program" OR "cultural exchange" OR "educational exchange" OR propaganda OR "psychological") AND (Japan OR Japanese) AND (image OR opinion OR attitudes OR anti-American OR effective)',jp,25,"ranked"),
 ("rank Japan b",'(USIS OR USIA OR "information program" OR "cultural exchange" OR "educational exchange" OR propaganda OR psychological) AND (Japan OR Japanese) AND (image OR opinion OR attitudes OR "anti American" OR effective)',jp,25,"ranked"),
 ("M4 QA family",QA,eap,None,"family list"),
 ("absence survey/poll",'(USIA OR USIS) AND (poll OR survey OR "opinion research" OR "research report" OR "audience research")',eap,None,"count"),
 ("absence Asian opinion",'("public opinion" OR poll OR survey) AND (Asian OR Asians) AND (USIA OR USIS OR propaganda)',eap,None,"count"),
 ("absence leaflet",'(leaflet OR leaflets OR "radio script" OR "film script" OR "VOA script") AND (USIA OR USIS OR "Voice of America")',eap,None,"count"),
 ("absence Peace Corps",'"Peace Corps"',eap,None,"count"),("absence Fulbright",'(Fulbright AND (grant OR scholar OR exchange OR educational))',eap,None,"count"),
 ("absence binational",'("binational center" OR "bi-national center" OR "Binational Centers")',eap,None,"count"),
 ("rank survey/poll top10",'(USIA OR USIS) AND (poll OR survey OR "opinion research" OR "research report" OR "audience research")',eap,10,"ranked"),
 ("falsefriend public diplomacy",'"public diplomacy"',eap,None,"count"),("falsefriend messaging",'messaging',eap,None,"count"),("falsefriend audience",'audience',eap,None,"count"),
]
reach={p:[] for p in cited}; reach_noncontrol={p:[] for p in cited}; reach_read={p:[] for p in cited}
for name,q,IN,lim,kind in queries:
    try:
        rows=con.execute(f"SELECT d.volume_id,d.document_id FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN ({IN}) ORDER BY bm25(frus_documents)",(q,)).fetchall()
    except Exception as e:
        print("QUERY ERROR",name,e); continue
    rs=set(rows); pos={p:i for i,p in enumerate(rows)}
    hits=[p for p in cited if p in rs]
    print(f"{name:32s} rows={len(rows):6d} cited-hits={len(hits):2d}", "" if lim is None else f"(limit {lim}: within={sum(1 for p in hits if pos[p]<lim)})")
    for p in hits:
        reach[p].append(name)
        if kind!="control": reach_noncontrol[p].append(name)
        if lim is None and kind in ("heading list","family list","ranked"): reach_read[p].append(name)
        elif lim is not None and pos[p]<lim: reach_read[p].append(f"{name}#{pos[p]+1}")
print("\n=== per cited document ===")
for p in cited:
    print(f"{p[0]}/{p[1]:6s} ANY={len(reach[p]):2d} non-control={len(reach_noncontrol[p]):2d} | non-control queries: {reach_noncontrol[p]} | within read lists: {reach_read[p]}")
print("\nSTRICT (returned by no logged full-text/heading query at all):",[p for p in cited if not reach[p]])
print("STRICT excluding the two controls:",[p for p in cited if not reach_noncontrol[p]])
print("Returned by no ranked/heading/family LIST the session read (only by count queries or controls):",[p for p in cited if not reach_read[p]])
