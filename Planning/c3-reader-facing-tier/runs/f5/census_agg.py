import csv,collections,sys
csv.field_size_limit(10**9)
rows=list(csv.DictReader(open('census.tsv'),delimiter='\t'))
fam=[k for k in rows[0].keys() if k not in('volume_id','document_id','date_iso')]
print("documents (non-apparatus) in 77 scope volumes:",len(rows))
print("\nFAMILY COUNTS (documents with >=1 match, of %d):"%len(rows))
for f in fam: print("  %-32s %6d"%(f,sum(1 for r in rows if int(r[f])>0)))
core=lambda r: int(r['USIA'])>0 or int(r['USIS'])>0 or int(r['VOA'])>0
print("\nCORE (USIA or USIS or VOA) documents:",sum(core(r) for r in rows))
print("  USIA only/any:",sum(int(r['USIA'])>0 for r in rows),"USIS any:",sum(int(r['USIS'])>0 for r in rows),"VOA any:",sum(int(r['VOA'])>0 for r in rows))
# controls
vols=collections.defaultdict(lambda:[0,0,0])
for r in rows:
    v=vols[r['volume_id']]; v[0]+=1; v[1]+= int(r['POS Department of State'])>0; v[2]+=int(r['NEG ZZZ_IMPOSSIBLE_ZZZ'])>0
print("\nPOSITIVE control 'Department of State': volumes with zero matching docs:",[k for k,v in vols.items() if v[1]==0],"of",len(vols))
print("NEGATIVE control ZZZ_IMPOSSIBLE_ZZZ total docs:",sum(v[2] for v in vols.values()))
# decades
den=collections.Counter(); num=collections.Counter(); topv=collections.defaultdict(collections.Counter)
for r in rows:
    d=r['date_iso'][:3]+'0s' if r['date_iso'] else 'undated'
    den[d]+=1
    if core(r): num[d]+=1; topv[d][r['volume_id']]+=1
print("\nDECADE (date_iso from document_dates, i.e. the document's own date; scope77 non-apparatus)  core docs / dated docs, per 1,000, top-volume share of numerator")
for d in sorted(den):
    if num[d]:
        tv,tn=topv[d].most_common(1)[0]
        print(f"  {d:8s} {num[d]:4d} of {den[d]:6d}  = {1000*num[d]/den[d]:5.1f} per 1,000   top volume {tv} {tn} of {num[d]}")
    else: print(f"  {d:8s}    0 of {den[d]:6d}")
# other families by decade (public diplomacy, hearts and minds, psywar, exchange)
for f in ["psywar","cultural/educational exchange","info program","public diplomacy","hearts and minds"]:
    n=collections.Counter(); 
    for r in rows:
        if int(r[f])>0: n[r['date_iso'][:3]+'0s' if r['date_iso'] else 'undated']+=1
    print("\n",f,{d:f"{n[d]} of {den[d]}" for d in sorted(den) if n[d]})
# top volumes for core
tv=collections.Counter(r['volume_id'] for r in rows if core(r))
print("\nTop volumes by core docs:",[(v,n,vols[v][0]) for v,n in tv.most_common(10)])
