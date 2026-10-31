#!/bin/zsh
# usage: q.sh "SQL"  -- logs and runs read-only
D=/Users/jbotts/frus-analysis/c3f/runs/f4
printf '%s\n' "sqlite3 -readonly /Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db \"$1\"" >> $D/queries.log
sqlite3 -readonly -header -separator '|' /Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db "$1"
