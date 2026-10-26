import sqlite3, csv, json
from collections import Counter
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
core = [r for r in csv.reader(open('/Users/jbotts/frus-analysis/c3/runs/r4/core.tsv'), delimiter='\t')]
pairs = [(r[0], r[1]) for r in core]
print("core pairs:", len(pairs), "distinct:", len(set(pairs)), "volumes:", len(set(v for v,_ in pairs)))
# sanity: every pair exists and is non-apparatus
missing=0; appar=0
for v,d in pairs:
    r = con.execute("SELECT is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=? AND document_id=?", (v,d)).fetchone()
    if not r: missing+=1
    elif r[0] or r[1]: appar+=1
print("missing rows:", missing, "apparatus rows in core:", appar)
# M7a came-from
era=Counter(); rg=Counter(); have=0; dec=Counter(); lots=Counter(); lib=Counter(); repo=Counter()
for v,d in pairs:
    r = con.execute("SELECT citation_era, repository, record_group, series_name, lot_file_norm, decimal_class FROM document_sources WHERE volume_id=? AND document_id=?", (v,d)).fetchone()
    if not r: continue
    have+=1; era[r[0]]+=1; rg[(r[1], r[2])]+=1; repo[r[1]]+=1
    if r[0]=='decimal' and r[5]: dec[r[5]]+=1
    if r[4]: lots[r[4]]+=1
print("\nM7a: docs with a source row:", have, "of", len(pairs))
print("citation_era:", dict(era))
print("decimal share:", era['decimal'], "/", have, "=", round(era['decimal']/have,4))
print("repository counts:", repo.most_common(12))
print("top (repository, record_group):", rg.most_common(6))
print("\nM7b top decimal classes (decimal era rows):", dec.most_common(12))
print("\nM7d came-from lots (lot_file_norm) over core:", sorted(lots.items(), key=lambda x:-x[1]))
print("max docs from any one lot:", max(lots.values()) if lots else None)
# M7e pointed-at
rows=0; docs=0; anchors=Counter(); cls=Counter(); libs=Counter(); plots=Counter(); mind='9999'
for v,d in pairs:
    rs = con.execute("SELECT anchor, repository, collection, lot_file_norm, decimal_class, file_id, inherited FROM external_citations WHERE volume_id=? AND document_id=?", (v,d)).fetchall()
    if rs: docs+=1
    for a,rep,colc,lot,dc,fid,inh in rs:
        rows+=1; anchors[a]+=1
        if dc: cls[dc]+=1
        if lot: plots[lot]+=1
        if a=='presidentialLibrary': libs[(rep,colc)]+=1
print("\nM7e: external_citations rows:", rows, "in docs:", docs, "of", len(pairs), "=", round(docs/len(pairs),4))
print("anchors:", dict(anchors))
print("decimal classes (pointed-at):", cls.most_common(10))
print("libraries (pointed-at):", libs.most_common(10))
print("lots (pointed-at):", sorted(plots.items(), key=lambda x:-x[1]))
# earliest external citation in the whole index
print("\nearliest dated doc with an external_citations row (whole index):",
  con.execute("SELECT MIN(dd.date_iso) FROM external_citations e JOIN document_dates dd ON dd.volume_id=e.volume_id AND dd.document_id=e.document_id").fetchone())
json.dump({'lots_came_from': dict(lots), 'lots_pointed_at': dict(plots), 'libs': {f"{k[0]}|{k[1]}":v for k,v in libs.items()}, 'dec_came_from': dict(dec), 'cls_pointed': dict(cls)}, open('channels_check.json','w'), indent=1)
