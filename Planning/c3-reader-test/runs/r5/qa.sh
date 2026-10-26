#!/bin/zsh
# usage: qa.sh "SQL" -- runs on scope.db with main index attached READ-ONLY as m (logs SQL)
R=/Users/jbotts/frus-analysis/c3/runs/r5
printf 'python sqlite3 scope.db + ATTACH main index mode=ro as m: %s\n' "$(echo "$1" | tr '\n' ' ')" >> $R/queries.log
python3 - "$1" <<'PY'
import sqlite3,sys
c=sqlite3.connect('file:/Users/jbotts/frus-analysis/c3/runs/r5/scope.db?mode=ro',uri=True)
c.execute("attach database 'file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro' as m")
for r in c.execute(sys.argv[1]): print('|'.join(str(x) for x in r))
PY
