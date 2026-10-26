# Refuter's own re-derivation of the headline numbers with its own SQL, from the reproduced classification in refuter/out/.
import csv, sqlite3, re
from collections import Counter
csv.field_size_limit(10**9)
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
latam={}
for r in csv.DictReader(open("out/latam_docs.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE):
    latam[(r["volume_id"], r["document_id"])]=r["country"]
print("latam docs:", len(latam))
MATCH='(NEAR(recogn* govern*, 6) OR NEAR(recogn* regim*, 6) OR NEAR(recogn* junta, 6)) AND (revolut* OR coup OR junta OR "de facto" OR overthrow* OR insurrect* OR golpe OR "provisional government" OR usurp* OR unconstitut*)'
rows=con.execute("SELECT f.volume_id, f.document_id, c.is_front_matter, c.is_editorial_note FROM frus_documents f JOIN document_cache c ON c.volume_id=f.volume_id AND c.document_id=f.document_id WHERE frus_documents MATCH ?", (MATCH,)).fetchall()
print("T MATCH corpus hits:", len(rows), "apparatus:", sum(1 for r in rows if r[2] or r[3]))
inl=[r for r in rows if (r[0],r[1]) in latam]; T={(r[0],r[1]) for r in inl if not r[2] and not r[3]}
print("in LatAm sections:", len(inl), "| T (non-apparatus):", len(T))
# C: the 51 chapters, from the session's chapter index list, resolved through MY reproduced candidates + headings
C_ALL=[1,7,8,9,19,20,21,36,48,77,86,100,101,102,106,108,110,112,113,115,117,118,121,127,128,141,148,153,154,155,157,162,163,164,165,166,168,169,170,171,172,173,174,176,177,178,179,180,181,184,185]
cand={int(r["idx"]):r for r in csv.DictReader(open("out/chapter_candidates.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE)}
heads=list(csv.DictReader(open("out/headings.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE))
C_listed={}
for i in C_ALL:
    c=cand[i]; hits=[h for h in heads if h["volume_id"]==c["volume_id"] and h["breadcrumb"][:400]==c["title"] and h["doc_ids"]]
    assert len(hits)==1, (i,len(hits))
    for d in hits[0]["doc_ids"].split(","): C_listed[(c["volume_id"],d)]=i
print("C chapters:", len(C_ALL), "| docs listed:", len(C_listed))
app=set(con.execute("SELECT volume_id, document_id FROM document_cache WHERE is_front_matter=1 OR is_editorial_note=1"))
C={k for k in C_listed if k not in app}
print("C apparatus dropped:", len(C_listed)-len(C), "| C:", len(C), "| C volumes:", len({v for v,_ in C}))
dates=dict(((v,d),iso) for v,d,iso in con.execute("SELECT volume_id, document_id, date_iso FROM document_dates"))
cd=sorted(dates.get(k) or '' for k in C if dates.get(k)); print("C date span:", cd[0], cd[-1])
SCOPE=T|C
print("SCOPE:", len(SCOPE), "| volumes:", len({v for v,_ in SCOPE}), "| T only:", len(T-C), "| C only:", len(C-T), "| both:", len(T&C))
sd=sorted(dates.get(k) for k in SCOPE if dates.get(k)); print("scope date span:", sd[0], sd[-1], "| undated:", sum(1 for k in SCOPE if not dates.get(k)))
print("pre-1861 scope docs:", [(k,dates[k]) for k in SCOPE if dates.get(k) and dates[k]<'1861'])
print("post-1950 (date_iso >= 1951):", sum(1 for k in SCOPE if dates.get(k) and dates[k]>='1951'))
# compare with the session's out/scope.tsv
sess={(r["volume_id"],r["document_id"]):r for r in csv.DictReader(open("../out/scope.tsv"), delimiter="\t", quoting=csv.QUOTE_NONE)}
print("session scope.tsv pairs:", len(sess), "| equal to my SCOPE:", set(sess)==SCOPE, "| sym diff:", len(set(sess)^SCOPE))
vols=sorted({v for v,_ in SCOPE}); open("scope_volumes.txt","w").write("\n".join(vols)+"\n")
print("volumes:", ", ".join(vols))
# Ed2 check
print("Ed2 volumes in scope:", [v for v in vols if v.endswith("Ed2")])
# ---- came-from (document_sources), one row per document
vals=",".join("('%s','%s')"%p for p in sorted(SCOPE))
ds=con.execute(f"WITH s(v,d) AS (VALUES {vals}) SELECT ds.volume_id, ds.document_id, ds.repository, ds.record_group, ds.lot_file_norm, ds.series_name, ds.citation_era, ds.decimal_class, ds.raw_text FROM document_sources ds JOIN s ON ds.volume_id=s.v AND ds.document_id=s.d").fetchall()
print("\nscope docs with a document_sources row:", len({(r[0],r[1]) for r in ds}), "rows:", len(ds), "| without:", len(SCOPE)-len({(r[0],r[1]) for r in ds}))
nos=[k for k in SCOPE if k not in {(r[0],r[1]) for r in ds}]
print("  without a row by date: through 1905:", sum(1 for k in nos if (dates.get(k) or '9999')<='1905-12-31'), "1906-1909:", sum(1 for k in nos if '1906'<=(dates.get(k) or '')<'1910'), "1910+:", sum(1 for k in nos if (dates.get(k) or '')>='1910'), "undated:", sum(1 for k in nos if not dates.get(k)))
thru1905=[k for k in SCOPE if dates.get(k) and dates[k]<='1905-12-31']; print("  scope docs dated through 1905:", len(thru1905), "| of them with a source row:", sum(1 for k in thru1905 if k not in set(nos)))
print("citation_era:", Counter(r[6] for r in ds).most_common())
print("record_group:", Counter(r[3] for r in ds).most_common(5))
dec=[r for r in ds if r[6]=='decimal']
cls=[r[7] for r in dec if r[7]]
print("decimal rows with a class:", len(cls))
def bucket(c):
    if re.match(r'^8\d\d\.00\b', c): return '8xx.00'
    if re.match(r'^8\d\d\.01\b', c): return '8xx.01'
    if c.startswith('711.12'): return '711.12'
    return 'other'
print("decimal class buckets:", Counter(bucket(c) for c in cls).most_common())
print("decimal top classes:", Counter(cls).most_common(10))
print("subject_numeric rows:", sum(1 for r in ds if r[6]=='subject_numeric'), "| raw:", Counter(" ".join((r[8] or '').split())[:30] for r in ds if r[6]=='subject_numeric').most_common(8))
cf=[r for r in ds if r[6]=='cfpf']; cfd=sorted(dates.get((r[0],r[1])) or '' for r in cf); print("cfpf rows:", len(cf), "dates:", cfd[0], cfd[-1])
print("lot_file_norm counts:", Counter(r[4] for r in ds if r[4]).most_common(20))
print("repository counts:", Counter(r[2] for r in ds).most_common(15))
lib=[r for r in ds if r[2] and 'Library' in (r[2] or '')]
print("library rows by repository+series:", Counter((r[2], (r[5] or '')[:40]) for r in lib).most_common(15))
print("Nixon-ish:", Counter((r[2],(r[5] or '')[:40]) for r in ds if r[2] and 'Nixon' in r[2]).most_common(5))
# ---- pointed-at (external_citations)
ec=con.execute(f"WITH s(v,d) AS (VALUES {vals}) SELECT ec.volume_id, ec.document_id, ec.anchor, ec.repository, ec.collection, ec.lot_file_norm, ec.decimal_class, ec.raw_text FROM external_citations ec JOIN s ON ec.volume_id=s.v AND ec.document_id=s.d").fetchall()
ecd={(r[0],r[1]) for r in ec}
print("\nexternal_citations rows:", len(ec), "on documents:", len(ecd), "| earliest citing doc date:", min(dates.get(k) or '9999' for k in ecd))
print("anchors:", Counter(r[2] for r in ec).most_common())
def rd(sel): 
    c=Counter(); dcs={}
    for r in ec:
        k=sel(r)
        if k: c[k]+=1; dcs.setdefault(k,set()).add((r[0],r[1]))
    return c, dcs
c,d=rd(lambda r: r[6]); print("decimal_class rows/docs:", [(k,n,len(d[k])) for k,n in c.most_common(12)])
c,d=rd(lambda r: r[5]); print("lot rows/docs:", [(k,n,len(d[k])) for k,n in c.most_common(10)])
c,d=rd(lambda r: (r[3],(r[4] or '')[:45]) if r[2]=='presidentialLibrary' else None); print("library rows/docs:", [(k,n,len(d[k])) for k,n in c.most_common(8)])
