# builds scope.db with tables scope(volume_id,document_id) and core(volume_id,document_id); the main index is attached READ-ONLY by later scripts
import sqlite3
d=sqlite3.connect('/Users/jbotts/frus-analysis/c3/runs/r5/scope.db')
d.execute("drop table if exists scope");d.execute("drop table if exists core")
d.execute("create table scope(volume_id,document_id,primary key(volume_id,document_id))")
d.execute("create table core(volume_id,document_id,primary key(volume_id,document_id))")
d.executemany("insert or ignore into scope values(?,?)",[l.split() for l in open('/Users/jbotts/frus-analysis/c3/runs/r5/scope_docs.tsv')])
d.executemany("insert or ignore into core values(?,?)",[l.split() for l in open('/Users/jbotts/frus-analysis/c3/runs/r5/core_docs.txt')])
d.commit();print(d.execute("select count(*) from scope").fetchone(),d.execute("select count(*) from core").fetchone())
