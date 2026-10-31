# Literal-share check (house rule (a)): for each phrase family, take the FTS hit list in the EA scope,
# sorted by (volume_id, document_id), an evenly spaced sample of 40 (whole set if <300 -> census),
# and test the literal with Python re (IGNORECASE) over header+dateline+source_note+body_text, whitespace-collapsed.
import sqlite3,re,json,sys
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
vols=[l.strip() for l in open('ea_vols.txt') if l.strip()]
vl=",".join("'%s'"%v for v in vols)
fams={
 'information program':(r'information program', r'information[\s\-,().]+programs?'),
 'psychological warfare':(r'psychological warfare', r'psychological[\s\-,().]+warfare'),
 'Voice of America':(r'Voice of America', r'Voices?[\s\-,().]+of[\s\-,().]+America'),
 'USIS':(r'\bUSIS\b', r'\bU\.?\s?S\.?\s?I\.?\s?S\b'),
 'USIA':(r'\bUSIA\b', r'\bU\.?\s?S\.?\s?I\.?\s?A\b'),
 'psychological strategy':(r'psychological strategy', r'psychological[\s\-,().]+strateg(y|ies)'),
}
out={}
for name,(strict,tol) in fams.items():
    q='"%s"'%name if ' ' in name else name
    rows=c.execute(f"""SELECT dc.volume_id, dc.document_id FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid
      WHERE frus_documents MATCH ? AND dc.volume_id IN ({vl}) AND dc.is_front_matter=0 AND dc.is_editorial_note=0
      ORDER BY dc.volume_id, dc.document_id""",(q,)).fetchall()
    n=len(rows)
    if n<300: samp=rows; kind='census'
    else:
        step=n/40; samp=[rows[int(i*step)] for i in range(40)]; kind='sample40'
    s_ok=t_ok=0; misses=[]
    for v,d in samp:
        h,dl,sn,b=c.execute("SELECT header,coalesce(dateline,''),coalesce(source_note,''),body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
        txt=re.sub(r'\s+',' ',' '.join([h,dl,sn,b]))
        s=bool(re.search(strict,txt,re.I)); t=bool(re.search(tol,txt,re.I))
        s_ok+=s; t_ok+=t
        if not t: misses.append(f"{v}/{d}")
    out[name]=dict(fts_hits=n,kind=kind,checked=len(samp),strict=s_ok,tolerant=t_ok,tolerant_misses=misses[:10])
    print(name, json.dumps(out[name]),flush=True)
json.dump(out,open('literal_share.json','w'),indent=1)
