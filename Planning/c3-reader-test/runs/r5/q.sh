#!/bin/zsh
# usage: q.sh "SQL"   -- logs SQL then runs read-only
R=/Users/jbotts/frus-analysis/c3/runs/r5
printf 'sqlite3 -readonly DB "%s"\n' "$(echo "$1" | tr '\n' ' ')" >> $R/queries.log
sqlite3 -readonly -separator '|' /Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db "$1"
