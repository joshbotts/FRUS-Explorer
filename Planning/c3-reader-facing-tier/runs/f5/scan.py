# scan.py: regex scan of scope + functional volumes; writes scan_docs.tsv (one row per non-apparatus document)
import sys,re,csv
sys.path.insert(0,'/Users/jbotts/frus-analysis/c3f/runs/f5')
from h import *
FUNC="frus1955-57v09 frus1961-63v25 frus1969-76v38p2 frus1977-80v30 frus1952-54v02p1 frus1952-54v02p2 frus1950v01 frus1951v01 frus1955-57v19 frus1958-60v03 frus1964-68v33 frus1969-76v02 frus1969-76v01 frus1977-80v01 frus1969-76v38p1 frus1964-68v10 frus1961-63v08 frus1949v01 frus1958-60v04 frus1977-80v28".split()
A=re.compile(r"\b(USIA|USIS|U\.?S\.?I\.?A\.?|United States Information (?:Agency|Service)|U\.?S\.? Information (?:Agency|Service)|Voice of America|VOA|information programs?|information activit\w+|psychological (?:warfare|operations?|strategy|program\w*|impact)|cultural (?:exchange\w*|programs?|relations|centers?|activit\w+)|educational exchange\w*|exchange (?:of persons|programs?)|Fulbright (?:program|scholar\w*|grants?|exchange)|leader grants?|binational cent\w+|information centers?|propaganda)\b",re.I)
B=re.compile(r"\b(prestige|image of (?:the )?(?:United States|America|U\.?S\.?)|American image|U\.?S\.? image|hearts and minds|good ?will|credibility|moral leadership|ideological|ideas|persuasion|world opinion|public opinion|Asian opinion)\b",re.I)
C=re.compile(r"\b(Asians?|Orientals?|Asian (?:mind|mentality|psychology|attitudes?|opinion|audiences?|peoples?|intellectuals?|students?|leaders?|countries|nationalists?)|face[- ]saving|lose face|loss of face|neutralis[mt]\w*|colonial\w*|racial|race|white man|Western (?:ideas|values|culture)|anti-?American\w*)\b",re.I)
D=re.compile(r"\b(effective(?:ness|ly)?|ineffective\w*|impact|failed|failure|success\w*|credib\w+|counterproductive|backfire\w*|results|lost ground|made (?:little|no) headway|little (?:effect|impact)|not (?:been )?effective|assess\w*|evaluat\w+)\b",re.I)
R=re.compile(r"\b(Asia\w*|Far East\w*|Japan\w*|China|Chinese|Korea\w*|Vietnam\w*|Indochin\w*|Philippin\w*|Indonesia\w*|Thai\w*|Siam\w*|Burm\w*|Taiwan|Formosa|Pacific|Laos|Lao|Cambodia\w*|Malay\w*|Singapore|Hong Kong|Okinawa)\b",re.I)
def clean(s): return re.sub(r'\s+',' ',s or '')
c=conn()
vols=SCOPE+FUNC
out=csv.writer(open('scan_docs.tsv','w'),delimiter='\t')
out.writerow(["volume_id","document_id","date_iso","len","A","B","C","D","R","Adistinct","header"])
for v in vols:
    sql="""SELECT d.volume_id,d.document_id,d.header,d.dateline,d.body_text,dd.date_iso FROM document_cache d LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id
           WHERE d.volume_id=? AND d.is_front_matter=0 AND d.is_editorial_note=0 ORDER BY d.rowid"""
    rows=run(c,sql,[v],"scan volume") if v==vols[0] else c.execute(sql,[v]).fetchall()
    for vi,di,h,dl,b,dt in rows:
        t=clean((h or '')+' '+(dl or '')+' '+(b or ''))
        a=A.findall(t)
        out.writerow([vi,di,dt,len(t),len(a),len(B.findall(t)),len(C.findall(t)),len(D.findall(t)),len(R.findall(t)),len({x.lower() for x in a}),clean(h)[:140]])
    print(v,len(rows),flush=True)
