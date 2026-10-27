#!/bin/zsh
# usage: q.sh "SQL"   (logs then runs)
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
echo "sqlite3 \"$DB\" \"$1\"" >> /Users/jbotts/frus-analysis/c3v/runs/v3/queries.log
sqlite3 -header "$DB" "$1"
