import sqlite3,json,re
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
S=json.load(open('/Users/jbotts/frus-analysis/c3f/runs/f4/scope_sets.json'))
def conn():
    c=sqlite3.connect(DB,uri=True)
    c.execute("CREATE TEMP TABLE R(volume_id TEXT PRIMARY KEY)")
    c.executemany("INSERT INTO R VALUES (?)",[(v,) for v in S['R']])
    c.execute("CREATE TEMP TABLE G(volume_id TEXT PRIMARY KEY)")
    c.executemany("INSERT INTO G VALUES (?)",[(v,) for v in S['G']])
    return c
