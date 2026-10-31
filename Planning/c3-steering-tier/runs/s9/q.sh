#!/bin/zsh
# usage: q.sh "SQL"  -- runs read-only, logs command to queries.log
R=/Users/jbotts/frus-analysis/c3s/runs/s9
print -r -- "sqlite3 \"file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro\" \"$1\"" >> $R/queries.log
sqlite3 "file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro" "$1"
