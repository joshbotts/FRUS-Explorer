#!/bin/zsh
# q.sh "SQL" [extra sqlite3 flags...]  -- runs read-only, logs the command to queries.log
DB='file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro'
SQL="$1"; shift
ONE=$(printf '%s' "$SQL" | tr '\n' ' ' | tr -s ' ')
printf 'sqlite3 %s "%s" "%s"\n' "$*" "$DB" "$ONE" >> /Users/jbotts/frus-analysis/c3/runs/r7/queries.log
sqlite3 "$@" "$DB" "$SQL"
