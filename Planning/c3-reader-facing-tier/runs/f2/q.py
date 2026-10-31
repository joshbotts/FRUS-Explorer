import sys, sqlite3, os
LOG="/Users/jbotts/frus-analysis/c3f/runs/f2/queries.log"
sql=sys.argv[1]
with open(LOG,"a") as f: f.write('sqlite3 -readonly /Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db "'+" ".join(sql.split())+'"\n')
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
for r in c.execute(sql): print("|".join("" if x is None else str(x) for x in r))
