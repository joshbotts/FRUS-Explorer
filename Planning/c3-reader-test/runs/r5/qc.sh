#!/bin/zsh
R=/Users/jbotts/frus-analysis/c3/runs/r5
printf 'sqlite3 chapters.db "%s"\n' "$(echo "$1" | tr '\n' ' ')" >> $R/queries.log
sqlite3 -separator '|' $R/chapters.db "$1"
