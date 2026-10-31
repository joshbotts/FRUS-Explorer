#!/bin/zsh
# usage: sq.sh "SQL"  -- logs then runs read-only
printf 'sqlite3 -readonly DB "%s"\n' "$1" | tr '\n' ' ' | sed 's/ $//' >> /Users/jbotts/frus-analysis/c3s/runs/s8/queries.log
echo >> /Users/jbotts/frus-analysis/c3s/runs/s8/queries.log
sqlite3 -readonly /Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db "$1"
