# Builds the Cuba working set: (A) documents under any editors' heading whose title matches /cuba/i (Python re, IGNORECASE),
# any depth; UNION (B) documents whose header matches FTS 'header:(cuba OR cuban)'. Excludes front matter, editorial notes, Ed2 duplicates.
import sqlite3,json,re,collections,csv
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
A=set()
def walk(n,vol,inside):
    if isinstance(n,dict):
        t=n.get('title') or ''
        hit=inside or bool(re.search(r'cuba',t,re.I))
        if hit:
            for d in n.get('documentIds',[]) or []: A.add((vol,d))
        for s in n.get('subsections',[]) or []: walk(s,vol,hit)
        for s in n.get('sections',[]) or []: walk(s,vol,hit)
for vol,js in c.execute("SELECT volume_id, structure_json FROM volume_structures"):
    walk(json.loads(js),vol,False)
SQLB="SELECT dc.volume_id, dc.document_id FROM frus_documents f JOIN document_cache dc ON dc.rowid=f.rowid WHERE frus_documents MATCH 'header:(cuba OR cuban)'"
B=set(c.execute(SQLB).fetchall())
U=A|B
ED2={'frus1951-54IranEd2','frus1969-76ve15p2Ed2'}
meta={}
for v,d,fm,en in c.execute("SELECT volume_id,document_id,is_front_matter,is_editorial_note FROM document_cache"):
    meta[(v,d)]=(fm,en)
dates={(v,d):iso for v,d,iso in c.execute("SELECT volume_id,document_id,date_iso FROM document_dates")}
keep=[k for k in U if k in meta and meta[k]==(0,0) and k[0] not in ED2]
missing=[k for k in U if k not in meta]
keep.sort()
with open('cuba_set.tsv','w') as f:
    for k in keep: f.write("%s\t%s\t%s\t%s\n"%(k[0],k[1],dates.get(k) or '', 'A' if k in A else '')+'' if False else "%s\t%s\t%s\t%s%s\n"%(k[0],k[1],dates.get(k) or '','A' if k in A else '','B' if k in B else ''))
print("SQL B:",SQLB)
print("A (heading) =",len(A),"B (header FTS) =",len(B),"union =",len(U),"not in document_cache =",len(missing))
print("kept after apparatus/Ed2 exclusion:",len(keep), " A-only",sum(1 for k in keep if k in A and k not in B)," B-only",sum(1 for k in keep if k in B and k not in A)," both",sum(1 for k in keep if k in A and k in B))
# per-decade with denominator
den=collections.Counter(); num=collections.Counter(); topv=collections.defaultdict(collections.Counter)
for k,(fm,en) in meta.items():
    if fm or en or k[0] in ED2: continue
    iso=dates.get(k)
    if not iso: continue
    den[iso[:3]+'0s']+=1
nodate=0
for k in keep:
    iso=dates.get(k)
    if not iso: nodate+=1; continue
    dec=iso[:3]+'0s'; num[dec]+=1; topv[dec][k[0]]+=1
print("undated in set:",nodate)
print("decade\tset\tdated_nonapparatus\tper1000\ttop_volume\ttop_share")
for dec in sorted(den):
    if dec<'1860s': continue
    tv=topv[dec].most_common(1)
    print("%s\t%d\t%d\t%.1f\t%s\t%s"%(dec,num[dec],den[dec],1000*num[dec]/den[dec],tv[0][0] if tv else '-', "%d of %d"%(tv[0][1],num[dec]) if tv else '-'))
