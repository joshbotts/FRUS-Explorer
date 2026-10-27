# (1) Phrase "national security": FTS hit list within W vs literal STRICT/TOLERANT census (all of W's FTS hits; set >300 so census, not sample).
# (2) Same, restricted to body_text with archive/institution names removed: national security (files?|council|action|adviser|affairs|agency|archive|memorandum|study|decision|staff) excluded.
import sqlite3,re,collections
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
W={tuple(l.split('\t')[:2]):l.split('\t')[2] for l in open('cuba_set.tsv')}
FTS="SELECT dc.volume_id, dc.document_id FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid WHERE frus_documents MATCH '\"national security\"'"
H=sorted(k for k in c.execute(FTS).fetchall() if k in W)
SEP=r'[\s\-,().]+'
strict=re.compile(r'\bnational security\b',re.I); tol=re.compile(r'\bnational'+SEP+r'securit(?:y|ies)\b',re.I)
inst=re.compile(r'\bnational'+SEP+r'securit(?:y|ies)'+SEP+r'(?:files?|council|action|advis[eo]r|affairs|agency|archives?|memorand\w*|stud\w*|decision\w*|staff|policy papers?|documents?)\b',re.I)
S=T=0; B=collections.Counter(); N=collections.Counter()
for v,d in H:
    r=c.execute("SELECT header,coalesce(dateline,''),coalesce(source_note,''),body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    t=' '.join(' '.join(r).split()); body=' '.join(r[3].split())
    S+=bool(strict.search(t)); T+=bool(tol.search(t))
    dec=W[(v,d)][:3]+'0s'; N[dec]+=1
    if tol.search(inst.sub(' ',body)): B[dec]+=1
print("FTS:",FTS)
print("FTS hits in W:",len(H)); print("literal STRICT:",S,"of",len(H)); print("literal TOLERANT:",T,"of",len(H))
print("decade: FTS hits / docs whose BODY uses the phrase outside institution & file names (tolerant, re.I)")
for dec in sorted(N): print(dec,N[dec],B[dec])
