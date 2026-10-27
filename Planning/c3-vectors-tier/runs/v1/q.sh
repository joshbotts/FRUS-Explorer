#!/bin/zsh
# usage: q.sh "SQL"  -- logs the SQL and runs read-only
R=/Users/jbotts/frus-analysis/c3v/runs/v1
echo "sqlite3 -readonly DB \"$1\"" >> $R/queries.log
sqlite3 -readonly -separator '|' /Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db "$1"
