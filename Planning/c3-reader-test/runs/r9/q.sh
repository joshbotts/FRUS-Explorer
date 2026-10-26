#!/bin/zsh
# q.sh: log the SQL to queries.log and run it read-only against the index copy
R=/Users/jbotts/frus-analysis/c3/runs/r9
DB="file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro"
printf 'sqlite3 "%s" %q\n' "$DB" "$1" >> $R/queries.log
sqlite3 "$DB" "$1"
