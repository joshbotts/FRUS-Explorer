import sqlite3, re, collections
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
FAM=re.compile(r"\b(corrupt\w*|brib\w*|kickback\w*|embezzl\w*|malfeasance|peculat\w*|graft|venal\w*|nepotism|cronyism)\b",re.I)
sql="""SELECT d.volume_id,d.document_id,d.body_text FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid WHERE frus_documents MATCH 'corrupt OR bribe OR bribery OR kickback OR embezzle OR malfeasance OR peculation OR graft OR venal OR nepotism OR cronyism OR payoff' AND d.is_front_matter=0 AND d.is_editorial_note=0 AND d.volume_id NOT IN ('frus1951-54IranEd2','frus1969-76ve15p2Ed2')"""
occ=collections.Counter(); docs=collections.Counter(); forms=collections.Counter()
for v,d,b in con.execute(sql):
    seen=set()
    for m in FAM.finditer(b):
        w=m.group(1).lower()
        stem=re.sub(r"^(corrupt|brib|kickback|embezzl|peculat|venal).*",r"\1*",w)
        occ[stem]+=1; seen.add(stem); forms[w]+=1
    for s in seen: docs[s]+=1
for s,n in occ.most_common(): print("%-14s occurrences %6d  documents %5d"%(s,n,docs[s]))
print("top surface forms:",forms.most_common(14))
