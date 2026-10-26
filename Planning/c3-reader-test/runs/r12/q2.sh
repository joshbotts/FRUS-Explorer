#!/bin/zsh
# usage: q2.sh "SQL" -- read-only main DB + scope.db attached as s (read-only)
echo "sqlite3 -readonly DB (ATTACH scope.db AS s) \"$1\"" >> /Users/jbotts/frus-analysis/c3/runs/r12/queries.log
sqlite3 -readonly -separator '|' /Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db "ATTACH 'file:/Users/jbotts/frus-analysis/c3/runs/r12/scope.db?mode=ro' AS s; $1"
