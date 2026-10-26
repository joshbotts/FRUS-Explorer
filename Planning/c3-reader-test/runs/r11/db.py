# helper: read-only connection; every SQL statement run through q() is appended to queries.log
import sqlite3
LOG="/Users/jbotts/frus-analysis/c3/runs/r11/queries.log"
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
def q(sql,params=(),tag=""):
    with open(LOG,"a") as f: f.write("python3(db.py %s): %s  params=%s\n"%(tag," ".join(sql.split()),str(params)[:300]))
    return con.execute(sql,params).fetchall()
