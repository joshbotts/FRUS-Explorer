# core_audit.py: (1) literal share of the core-set family on 40 evenly spaced docs of raw/coreset_clean.tsv (sorted by volume_id,document_id)
#  regex (Python re, IGNORECASE) over header+dateline+source_note+body_text, whitespace-collapsed.
#  STRICT: \b(USIA|USIS|information program|psychological strategy|psychological warfare|cultural exchange)\b
#  TOLERANT: adds inflections and separators: information[\s\-,().]+programs?|psychological[\s\-,().]+(strategy|warfare)|cultural[\s\-,().]+exchanges?|U\.\s?S\.\s?I\.\s?[AS]\.?|Information Agency|Information Service
# (2) per-decade counts of the regional part of the core set vs. dated non-apparatus docs of the regional volumes, using document_dates.date_iso
import sqlite3,re,collections
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
core=[tuple(l.split('\t')) for l in open('raw/coreset_clean.tsv').read().split('\n') if l]
n=len(core); samp=[core[int(i*n/40)] for i in range(40)]
S=re.compile(r'\b(USIA|USIS|information program|psychological strategy|psychological warfare|cultural exchange)\b',re.I)
T=re.compile(r'\b(USIAs?|USIS|information[\s\-,().]+programs?|psychological[\s\-,().]+(strateg\w*|warfare)|cultural[\s\-,().]+exchanges?|U\.\s?S\.\s?I\.\s?[AS]\.?|Information Agency|Information Service)',re.I)
s=t=0; miss=[]
for v,d in samp:
    r=con.execute("SELECT header,coalesce(dateline,''),coalesce(source_note,''),body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    x=re.sub(r'\s+',' ',' '.join(r)); a=bool(S.search(x)); b=bool(T.search(x)); s+=a; t+=b
    if not b: miss.append(v+'/'+d)
print('literal share on sample of 40 of',n,': STRICT',s,'of 40; TOLERANT',t,'of 40; tolerant misses',miss)
GLOBAL={'frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1955-57v09','frus1961-63v25','frus1969-76v38p2','frus1977-80v30','frus1952-54v02p2','frus1950-55Intel'}
vols=[l.strip() for l in open('scope_volumes.txt') if l.strip()]; REG=[v for v in vols if v not in GLOBAL]
ql=",".join("'%s'"%v for v in REG)
den=collections.Counter(); 
for (dec,c) in con.execute("SELECT substr(d.date_iso,1,3)||'0s', COUNT(*) FROM document_cache c JOIN document_dates d ON d.volume_id=c.volume_id AND d.document_id=c.document_id WHERE c.is_front_matter=0 AND c.is_editorial_note=0 AND d.date_iso IS NOT NULL AND c.volume_id IN (%s) GROUP BY 1"%ql): den[dec]=c
num=collections.Counter(); top=collections.defaultdict(collections.Counter)
regcore=[(v,d) for v,d in core if v not in GLOBAL]
for v,d in regcore:
    r=con.execute("SELECT date_iso FROM document_dates WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    if r and r[0]: dec=r[0][:3]+'0s'; num[dec]+=1; top[dec][v]+=1
print('decade | core(regional) | dated non-apparatus docs in regional volumes | per 1,000 | top volume share')
for dec in sorted(den):
    tv=top[dec].most_common(1)
    print(dec,'|',num[dec],'|',den[dec],'|',round(1000*num[dec]/den[dec],1),'|',(tv[0][0]+' '+str(tv[0][1])+' of '+str(num[dec])) if tv else '-')
print('undated regional core docs:',len(regcore)-sum(num.values()))
