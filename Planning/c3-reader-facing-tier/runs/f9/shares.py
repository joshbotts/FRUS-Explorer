# literal shares for phrase families over R+I volumes (non-apparatus).
# hit list: SELECT d.volume_id,d.document_id, d.header||' '||coalesce(d.dateline,'')||' '||coalesce(d.source_note,'')||' '||d.body_text
#   FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND is_front_matter=0 AND is_editorial_note=0 AND volume_id IN (R+I)
# sorted by (volume_id, document_id); census if <300 else 40 evenly spaced. Python re, IGNORECASE, whitespace collapsed.
import sqlite3,sys,re,json
sys.path.insert(0,'.'); from scopevols import R,I
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
vols=R+I; ph=','.join('?'*len(vols))
SEP=r'[\s\-,().]+'
fam={
 'psychological warfare':('"psychological warfare"', r'psychological warfare', r'psycholog\w*'+SEP+r'warfare\w*'),
 'information program':('"information program"', r'information program', r'information\w*'+SEP+r'program\w*'),
 'public diplomacy':('"public diplomacy"', r'public diplomacy', r'public\w*'+SEP+r'diplomac\w*'),
 'cultural exchange':('"cultural exchange"', r'cultural exchange', r'cultural\w*'+SEP+r'exchang\w*'),
 'Voice of America':('"Voice of America"', r'voice of america', r'voice\w*'+SEP+r'of'+SEP+r'america\b'),
 'USIA/USIS':('usia OR usi', r'\bUSI[AS]\b', r'\bU\.?\s?S\.?\s?I\.?\s?[AS]\.?\b'),
}
out={}
for k,(q,strict,tol) in fam.items():
    rows=c.execute(f"SELECT d.volume_id,d.document_id, d.header||' '||coalesce(d.dateline,'')||' '||coalesce(d.source_note,'')||' '||d.body_text FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH ? AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id IN ({ph}) ORDER BY d.volume_id,d.document_id",[q]+vols).fetchall()
    n=len(rows)
    if n<300: samp=rows; kind='census'
    else:
        step=n/40; samp=[rows[int(i*step)] for i in range(40)]; kind='sample40'
    s=t=0; miss=[]
    for v,d,txt in samp:
        txt=re.sub(r'\s+',' ',txt)
        a=bool(re.search(strict,txt,re.I)); b=bool(re.search(tol,txt,re.I))
        s+=a; t+=b
        if not b: miss.append((v,d,[m for m in re.findall(r'\w*'+k.split()[0][:5]+r'\w*\W+\w+\W+\w+',txt,re.I)][:3]))
    out[k]=dict(query=q,hits=n,kind=kind,checked=len(samp),strict=s,tolerant=t,misses=miss[:10])
    print(f"{k}: hits={n} {kind} checked={len(samp)} STRICT={s}/{len(samp)} TOLERANT={t}/{len(samp)} misses={miss[:4]}")
json.dump(out,open('shares.json','w'),indent=1)
