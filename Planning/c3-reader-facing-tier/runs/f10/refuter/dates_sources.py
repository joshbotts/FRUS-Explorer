import sqlite3,json,collections
db=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
R="/Users/jbotts/frus-analysis/c3f/runs/f10/"
scope=open(R+"scope105.txt").read().strip().split(",")
eap=open(R+"eap_vols.txt").read().strip().split(",")
ph=lambda L: ",".join("?"*len(L))
print("scope105 non-apparatus date span:",db.execute(f"select min(dd.date_iso),max(dd.date_iso),count(dd.date_iso) from document_cache d join document_dates dd on dd.volume_id=d.volume_id and dd.document_id=d.document_id where d.is_front_matter=0 and d.is_editorial_note=0 and d.volume_id in ({ph(scope)})",scope).fetchone())
print("EAP99 non-apparatus date span:",db.execute(f"select min(dd.date_iso),max(dd.date_iso) from document_cache d join document_dates dd on dd.volume_id=d.volume_id and dd.document_id=d.document_id where d.is_front_matter=0 and d.is_editorial_note=0 and d.volume_id in ({ph(eap)})",eap).fetchone())
pairs=json.load(open(R+"refuter/pairs.json"))['docs']
dates=[]; tally=collections.Counter(); lib=collections.Counter(); rows=[]
for v,d in pairs:
    r=db.execute("select dd.date_iso,s.repository,s.record_group,s.lot_file,s.series_name,s.citation_era,s.decimal_class from document_cache c left join document_dates dd on dd.volume_id=c.volume_id and dd.document_id=c.document_id left join document_sources s on s.volume_id=c.volume_id and s.document_id=c.document_id where c.volume_id=? and c.document_id=?",(v,d)).fetchone()
    dates.append(r[0]); tally[(r[1],r[2])]+=1; rows.append((v,d)+tuple(r))
    if r[1] and 'Library' in (r[1] or '') or (r[1] or '').startswith('Nixon'): lib[(r[1],r[4])]+=1
print("30 docs date span:",min(dates),max(dates))
print("M9 tally (repository, RG):",dict(tally))
rg59=sum(n for (rep,rg),n in tally.items() if rg=='59'); rg306=sum(n for (rep,rg),n in tally.items() if rg=='306')
print("  RG59:",rg59,"(memo 13) | RG306:",rg306,"(memo 10) | libraries:",sum(lib.values()),"(memo 7)")
print("  library detail:",dict(lib))
for r in rows: print("  ",r)
