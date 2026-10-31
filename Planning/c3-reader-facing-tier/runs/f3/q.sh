#!/bin/zsh
# usage: q.sh "SQL"  -- logs the SQL then runs it read-only
echo "sqlite3 -readonly DB \"$1\"" >> /Users/jbotts/frus-analysis/c3f/runs/f3/queries.log
sqlite3 -readonly -separator '|' /Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db "$1"
