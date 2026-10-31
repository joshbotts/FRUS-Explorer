# beliefs.py: sentences in info-vocabulary documents (scan_docs.tsv Adistinct>=1 and A>=2) that state a belief about the regional audience
import csv,re,sys
sys.path.insert(0,'/Users/jbotts/frus-analysis/c3f/runs/f5')
from h import *
csv.field_size_limit(10**9)
rows=[r for r in csv.DictReader(open('scan_docs.tsv'),delimiter='\t') if int(r['A'])>=2 and int(r['R'])>=2]
print(len(rows),file=sys.stderr)
BEL=re.compile(r"\b(Asians?|Orientals?|Asian (?:peoples?|mind|mentality|psychology|attitudes?|opinion|intellectuals?|students?|leaders?|nationalists?|audiences?|countries)|the (?:Vietnamese|Thai|Japanese|Filipinos?|Indonesians?|Burmese|Koreans?|Chinese|Cambodians?|Lao(?:tians)?|Malays?|Malayans?|peasants?|rural population|masses|people) (?:are|is|do not|does not|tend|resent|respect|admire|fear|distrust|suspect|believe|think|feel|view|regard|look|have little|have no|want|prefer|remain|see)|face|prestige|race|racial|colonial\w*|neutralis\w+|anti-?American\w*|white)\b",re.I)
INFO=re.compile(r"(USIA|USIS|information|propaganda|psychological|cultural|exchange|image|Voice of America|radio|film|indoctrinat|persuad|messages?|themes?)",re.I)
EFF=re.compile(r"\b(effective(?:ness|ly)?|ineffective|impact|failed|failure|success\w*|credib\w+|counterproductive|backfire\w*|little (?:effect|impact|value)|not (?:been )?effective|made (?:little|no) headway|fell short|disappointing|worthless|futile|wasted)\b",re.I)
c=conn()
out=open('beliefs_hits.tsv','w')
SQL="SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?"
for i,r in enumerate(rows):
    b=c.execute(SQL,[r['volume_id'],r['document_id']]).fetchone()[0]
    t=re.sub(r'\s+',' ',b)
    for s in re.split(r'(?<=[.;?!])\s+(?=[A-Z0-9“"(])',t):
        if len(s)>700: continue
        nb=len(BEL.findall(s)); ni=len(INFO.findall(s)); ne=len(EFF.findall(s))
        if nb and ni and (ne or True):
            out.write("\t".join([r['volume_id'],r['document_id'],r['date_iso'][:10],str(nb),str(ni),str(ne),s])+"\n")
