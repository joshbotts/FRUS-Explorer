import sqlite3
c=sqlite3.connect('file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro',uri=True)
print('--- frus1907p2 field docs: source rows ---')
field=[tuple(l.split()) for l in open('field_pairs.tsv') if l.strip()]
for v,d in [p for p in field if p[0]=='frus1907p2']:
    r=c.execute("select ds.citation_era, ds.decimal_class, ds.record_group, ds.raw_text, dc.source_note, dd.date_iso from document_cache dc left join document_sources ds using(volume_id,document_id) left join document_dates dd using(volume_id,document_id) where dc.volume_id=? and dc.document_id=?",(v,d)).fetchone()
    print(v,d,r[5],'|',r[0],r[1],r[2],'|',(r[3] or '')[:80],'|| source_note:',(r[4] or '')[:90])
print('--- decimal-era rows dated before 1910-08 (any volume in field) ---')
c.execute("create temp table scope(volume_id,document_id,primary key(volume_id,document_id))"); c.executemany("insert into scope values(?,?)",field)
print(c.execute("select s.volume_id,count(*),min(dd.date_iso),max(dd.date_iso) from scope s join document_sources ds using(volume_id,document_id) join document_dates dd using(volume_id,document_id) where ds.citation_era='decimal' and dd.date_iso<'1910-08' group by 1").fetchall())
print('--- other cited archival sources ---')
for v,d in [('frus1948v09','d115'),('frus1961-63v12','d363'),('frus1964-68v31','d135'),('frus1964-68v31','d141'),('frus1964-68v31','d206'),('frus1964-68v31','d515'),('frus1969-76v21','d358'),('frus1969-76v21','d360'),('frus1952-54v04','d490'),('frus1977-80v24','d132'),('frus1977-80v15','d276'),('frus1961-63v10-12mSupp','d160'),('frus1961-63v12','d421'),('frus1961-63v12','d423'),('frus1961-63v12','d427'),('frus1958-60v06','d217'),('frus1948v09','d7')]:
    r=c.execute("select dc.header, dc.source_note, ds.repository, ds.record_group, ds.lot_file, ds.series_name, ds.citation_era, ds.decimal_class, ds.raw_text from document_cache dc left join document_sources ds using(volume_id,document_id) where dc.volume_id=? and dc.document_id=?",(v,d)).fetchone()
    print(f'{v}/{d} | {r[0][:70]!r}\n    source_note: {(r[1] or "")[:160]!r}\n    ds: repo={r[2]!r} rg={r[3]!r} lot={r[4]!r} series={r[5]!r} era={r[6]!r} class={r[7]!r}')
print('--- field docs whose source_note mentions a library or Project Clean Up ---')
print(c.execute("select count(*) from scope s join document_cache dc using(volume_id,document_id) where dc.source_note like '%Library%'").fetchone())
print(c.execute("select volume_id,document_id,substr(source_note,1,120) from document_cache where source_note like '%Clean Up%' limit 5").fetchall())
