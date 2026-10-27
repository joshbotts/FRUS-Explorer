# Refuter: scope and headline numbers, recomputed from the index with my own code (no session CSV read).
import sqlite3, re, json, collections
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
c=sqlite3.connect(DB,uri=True)
ED2=('frus1951-54IranEd2','frus1969-76ve15p2Ed2')
print("COVERAGE:", c.execute("SELECT COUNT(DISTINCT volume_id), COUNT(*), SUM(is_front_matter), SUM(is_editorial_note) FROM document_cache").fetchone())
print("Ed2 volumes present:", c.execute("SELECT volume_id, COUNT(*) FROM document_cache WHERE volume_id LIKE '%Ed2' GROUP BY 1").fetchall())
# N01: tier-1 set
rows=c.execute("""SELECT d.volume_id, d.document_id, dd.date_iso, d.body_text
 FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
 JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
 WHERE frus_documents MATCH 'cuba OR cuban' AND d.is_front_matter=0 AND d.is_editorial_note=0
 AND d.volume_id NOT IN (?,?)""",ED2).fetchall()
dec=collections.Counter()
tier1=[]
for v,d,dt,b in rows:
    if dt and '1870'<=dt<'1990':
        tier1.append((v,d,dt,b)); dec[dt[:3]+'0s']+=1
print("tier-1 (cuba OR cuban, non-apparatus, not Ed2, dated 1870-1989):", len(tier1))
print("per decade:", sorted(dec.items()))
print("tier-1 date span:", min(t[2] for t in tier1), max(t[2] for t in tier1))
print("rows with NULL/empty date among raw hits:", sum(1 for r in rows if not r[2]))
print("hits dated <1870:", sum(1 for r in rows if r[2] and r[2]<'1870'), "; dated >=1990:", sum(1 for r in rows if r[2] and r[2]>='1990'))
# denominators per decade
den=dict(c.execute("SELECT substr(dd.date_iso,1,3)||'0s', COUNT(*) FROM document_cache d JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN (?,?) GROUP BY 1",ED2).fetchall())
print("denominator 1870s-1980s:", sum(v for k,v in den.items() if k and '1870s'<=k<='1980s'), "; 1990s:", den.get('1990s'))
for k in ['1870s','1940s','1960s']:
    print(k, "per 1000:", round(1000*dec[k]/den[k],1))
# tier-2: >=5 case-sensitive mentions
CUB=re.compile(r"\bCub(?:a|an|ans)\b")
tier2=[(v,d,dt) for v,d,dt,b in tier1 if len(CUB.findall(b))>=5]
print("tier-2 (>=5 case-sensitive Cuba/Cuban/Cubans in body_text):", len(tier2))
def band(dt):
    y=int(dt[:4]); return "1870-1899" if y<1900 else "1900-1939" if y<1940 else "1940-1957" if y<1958 else "1958-1989"
print("tier-2 by band:", sorted(collections.Counter(band(t[2]) for t in tier2).items()))
print("tier-2 date span:", min(t[2] for t in tier2), max(t[2] for t in tier2))
# 621: tier-2 docs with >=1 external_citations row; 1 of 309 with a document_sources row
c.execute("CREATE TEMP TABLE sc(volume_id TEXT, document_id TEXT, date TEXT)")
c.executemany("INSERT INTO sc VALUES(?,?,?)", tier2)
print("tier-2 docs with >=1 external_citations row:", c.execute("SELECT COUNT(DISTINCT s.volume_id||'/'||s.document_id) FROM sc s JOIN external_citations ec ON ec.volume_id=s.volume_id AND ec.document_id=s.document_id").fetchone())
print("tier-2 1870-1899 docs with a document_sources row:", c.execute("SELECT COUNT(*) FROM sc s JOIN document_sources ds ON ds.volume_id=s.volume_id AND ds.document_id=s.document_id WHERE s.date<'1900'").fetchone(), "of", c.execute("SELECT COUNT(*) FROM sc WHERE date<'1900'").fetchone())
print("earliest-dated external_citations row in tier-2:", c.execute("SELECT MIN(s.date) FROM sc s JOIN external_citations ec ON ec.volume_id=s.volume_id AND ec.document_id=s.document_id").fetchone())
print("earliest-dated external_citations row in whole index:", c.execute("SELECT MIN(dd.date_iso) FROM external_citations ec JOIN document_dates dd ON dd.volume_id=ec.volume_id AND dd.document_id=ec.document_id").fetchone())
# 1990s: 177 docs, 0 Cuba
print("1990s dated non-apparatus docs (not Ed2):", den.get('1990s'), "; Cuba hits dated 1990s:", sum(1 for r in rows if r[2] and r[2][:3]=='199'))
# 22 in collection
col=json.load(open('/Users/jbotts/frus-analysis/c3v/runs/v1/collection.fruscollection'))
docs=[(e['volumeId'],e['documentId']) for e in col['entries'] if e['kind']=='document']
print("collection document entries:", len(docs), "distinct:", len(set(docs)))
# are the 22 all in tier-2?
t2=set((v,d) for v,d,dt in tier2)
t1=set((v,d) for v,d,dt,b in tier1)
for v,d in docs:
    b=c.execute("SELECT body_text, is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    n=len(CUB.findall(b[0])) if b else None
    print("  %s/%s  tier1=%s tier2=%s  Cuba mentions=%s fm=%s ed=%s"%(v,d,(v,d) in t1,(v,d) in t2,n,b[1] if b else None,b[2] if b else None))
# N06 Havana-only check (1,137)
tot=0
for lo,hi in [('1870','1900'),('1900','1940'),('1940','1958'),('1958','1990')]:
    n=c.execute("""SELECT COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
      WHERE frus_documents MATCH '(havana OR habana) NOT (cuba OR cuban)' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN (?,?) AND dd.date_iso>=? AND dd.date_iso<?""",ED2+(lo,hi)).fetchone()[0]
    tot+=n; print("Havana-only",lo,hi,n)
print("Havana-only total:", tot)
# controls
print("positive control volumes:", c.execute("SELECT COUNT(DISTINCT d.volume_id) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH 'department AND state' AND d.is_front_matter=0 AND d.is_editorial_note=0").fetchone(), "; negative:", c.execute("SELECT COUNT(*) FROM frus_documents WHERE frus_documents MATCH 'zzz_impossible_zzz'").fetchone())
# pre-1947 'national security' with Cuba
print("pre-1947 (cuba OR cuban) AND \"national security\":", c.execute("""SELECT COUNT(*) FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
  WHERE frus_documents MATCH '(cuba OR cuban) AND "national security"' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN (?,?) AND dd.date_iso>='1870' AND dd.date_iso<'1947'""",ED2).fetchone())
