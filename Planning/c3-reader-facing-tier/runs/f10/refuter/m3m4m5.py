import sqlite3,re,collections
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
R="/Users/jbotts/frus-analysis/c3f/runs/f10/"
scope=open(R+"scope105.txt").read().strip().split(",")
eap=open(R+"eap_vols.txt").read().strip().split(",")
info="frus1917-72PubDipv06 frus1917-72PubDipv07 frus1917-72PubDipv08 frus1977-80v30 frus1955-57v09 frus1961-63v25".split()
assert len(scope)==105 and len(eap)==99 and set(scope)==set(eap)|set(info)
ph=lambda L: ",".join("?"*len(L))
n105=db.execute(f"select count(*) from document_cache where is_front_matter=0 and is_editorial_note=0 and volume_id in ({ph(scope)})",scope).fetchone()[0]
n6=db.execute(f"select count(*) from document_cache where is_front_matter=0 and is_editorial_note=0 and volume_id in ({ph(info)})",info).fetchone()[0]
n99=db.execute(f"select count(*) from document_cache where is_front_matter=0 and is_editorial_note=0 and volume_id in ({ph(eap)})",eap).fetchone()[0]
print("M3 scope105 non-apparatus:",n105,"(memo 58,244) | six info vols:",n6,"(memo 1,373) | 99 EAP:",n99)
FA='"United States Information Agency" OR "United States Information Service" OR USIA OR USIS'
def fts_count(match,vols):
    return db.execute(f"select count(*) from frus_documents f join document_cache d on d.volume_id=f.volume_id and d.document_id=f.document_id where frus_documents match ? and d.is_front_matter=0 and d.is_editorial_note=0 and f.volume_id in ({ph(vols)})",[match]+vols).fetchone()[0]
fa105=fts_count(FA,scope); fa99=fts_count(FA,eap)
print("M4 Family A FTS scope105:",fa105,"(memo 1,538) | EAP99:",fa99,"(memo 898)")
print("   propaganda scope105:",fts_count('propaganda',scope),"(memo 3,407) | prestige:",fts_count('prestige',scope),"(memo 2,108)")
print("   Boxer indemnity EAP99:",fts_count('"Boxer indemnity"',eap),"(memo 99)")
# literal census
tol=re.compile(r"(U\.?\s?S\.?|United\s+States)[\s-]+Information[\s,.-]+(Agenc|Servic)\w*|USIA|USIS|U\.S\.I\.[AS]\.",re.I)
rows=db.execute(f"select f.volume_id,f.document_id,d.header,d.dateline,d.source_note,d.body_text,dd.date_iso from frus_documents f join document_cache d on d.volume_id=f.volume_id and d.document_id=f.document_id left join document_dates dd on dd.volume_id=d.volume_id and dd.document_id=d.document_id where frus_documents match ? and d.is_front_matter=0 and d.is_editorial_note=0 and f.volume_id in ({ph(scope)})",[FA]+scope)
n=0;fts=0;dec=collections.Counter();byvol=collections.defaultdict(collections.Counter);conf=set()
for v,d,h,dl,sn,b,di in rows:
    fts+=1
    t=" ".join(((h or '')+" "+(dl or '')+" "+(sn or '')+" "+b).split())
    if tol.search(t):
        n+=1; conf.add((v,d)); de=(di[:3]+"0s") if di else "none"; dec[de]+=1; byvol[de][v]+=1
print("M4 literal census:",n,"of",fts,"(memo 1,329 of 1,538) =",round(100*n/fts,1),"%")
print("   1 in",round(n105/n,1),"(memo 1 in 43.8; overview 'one in forty-four')")
den=collections.Counter()
for de,c in db.execute(f"select substr(dd.date_iso,1,3)||'0s',count(*) from document_cache d join document_dates dd on dd.volume_id=d.volume_id and dd.document_id=d.document_id where d.is_front_matter=0 and d.is_editorial_note=0 and d.volume_id in ({ph(scope)}) group by 1",scope): den[de]=c
print("M5 by decade (num / den / per1000 / top volume):")
for de in sorted(dec):
    tv=byvol[de].most_common(1)[0] if byvol[de] else ('',0)
    print("  ",de,dec[de],"of",den.get(de,0),round(1000*dec[de]/den[de],1) if den.get(de) else None,"| top",tv[0],tv[1])
print("   1960s: 1 in",round(den['1960s']/dec['1960s'],1),"(memo 1 in 12.8; overview 'one in thirteen')")
# are the three vector-reached docs in the famA literal set?
for p in [("frus1952-54v13p1","d116"),("frus1917-72PubDipv07","d32"),("frus1917-72PubDipv08","d34")]:
    print("   in famA literal census:",p,p in conf)
# compare with session's famA_literal.tsv
sess=set(tuple(l.split("\t")[:2]) for l in open(R+"famA_literal.tsv") if l.strip())
print("session famA_literal.tsv rows:",len(sess),"| equal to my census:",sess==conf)
