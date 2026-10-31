# census.py: per-document flags for term families over the 77 scope volumes (non-apparatus). Counting surface: document_cache header+dateline+body_text, whitespace-collapsed (index text, footnotes included; not TEI).
import sys,re,csv
sys.path.insert(0,'/Users/jbotts/frus-analysis/c3f/runs/f5')
from h import *
FAM={
 "USIA":re.compile(r"\b(USIA|U\.S\.I\.A\.|United States Information Agency|U\.S\. Information Agency)\b"),
 "USIS":re.compile(r"\b(USIS|United States Information Service|U\.S\. Information Service)\b"),
 "VOA":re.compile(r"\b(Voice of America|VOA)\b"),
 "psywar":re.compile(r"\bpsychological (?:warfare|operations?|strategy)\b",re.I),
 "cultural/educational exchange":re.compile(r"\b(?:cultural|educational) (?:exchanges?|programs?|relations)\b|\bexchange of persons\b|\bFulbright (?:program|scholar\w*|grants?|exchange)\b",re.I),
 "info program":re.compile(r"\binformation(?:al)? (?:programs?|activit(?:y|ies)|campaigns?)\b",re.I),
 "public diplomacy":re.compile(r"\bpublic diplomacy\b",re.I),
 "soft power":re.compile(r"\bsoft[- ]power\b",re.I),
 "hearts and minds":re.compile(r"\bhearts and minds\b",re.I),
 "POS Department of State":re.compile(r"\bDepartment of State\b"),
 "NEG ZZZ_IMPOSSIBLE_ZZZ":re.compile(r"ZZZ_IMPOSSIBLE_ZZZ"),
}
names=list(FAM)
c=conn()
out=csv.writer(open('census.tsv','w'),delimiter='\t'); out.writerow(["volume_id","document_id","date_iso"]+names)
SQL="SELECT d.volume_id,d.document_id,d.header,d.dateline,d.body_text,dd.date_iso FROM document_cache d LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE d.volume_id=? AND d.is_front_matter=0 AND d.is_editorial_note=0 ORDER BY d.rowid"
open(LOG,"a").write("SQL [census.py, once per scope volume x77]: "+SQL+"\n")
for v in SCOPE:
    for vi,di,h,dl,b,dt in c.execute(SQL,[v]).fetchall():
        t=re.sub(r'\s+',' ',(h or '')+' '+(dl or '')+' '+(b or ''))
        out.writerow([vi,di,dt or '']+[len(FAM[n].findall(t)) for n in names])
    print(v,flush=True)
