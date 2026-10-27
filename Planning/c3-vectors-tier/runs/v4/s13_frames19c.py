# Same frames as s12, over M19 = documents matching FTS 'cuba OR cuban' (any column) dated 1865-1889, non-apparatus, non-Ed2. BODY_TEXT, re.I.
import sqlite3,re,collections,importlib.util
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
SQL="SELECT dc.volume_id, dc.document_id, dd.date_iso, dc.body_text FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid JOIN document_dates dd ON dd.volume_id=dc.volume_id AND dd.document_id=dc.document_id WHERE frus_documents MATCH 'cuba OR cuban' AND dc.is_front_matter=0 AND dc.is_editorial_note=0 AND dd.date_iso BETWEEN '1865' AND '1890'"
src=open('s12_frames.py').read(); F={}
exec(src[src.index('SEP='):src.index('cp=')])
cp={k:re.compile(v,re.I) for k,v in F.items()}
cuba2=re.compile(r'\bCuba(?:n|ns)?\b')  # case-sensitive: count docs naming Cuba at least twice
N=collections.Counter(); R=collections.defaultdict(collections.Counter); vols=collections.Counter()
for v,d,iso,b in c.execute(SQL):
    b=' '.join(b.split())
    if len(cuba2.findall(b))<2: continue
    dec=iso[:3]+'0s'; N[dec]+=1; vols[v]+=1
    for k,p in cp.items():
        if p.search(b): R[k][dec]+=1
print("SQL:",SQL); print("filter: >=2 case-sensitive \\bCuba(n|ns)?\\b in body")
decs=sorted(N); print('frame\t'+'\t'.join(decs)); print('N\t'+'\t'.join(str(N[x]) for x in decs))
for k in F: print(k+'\t'+'\t'.join(str(R[k][x]) for x in decs))
print("top volumes:",vols.most_common(8))
