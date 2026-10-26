#!/bin/zsh
# logs the command body to queries.log, then runs it
print -r -- "$1" >> /Users/jbotts/frus-analysis/c3/runs/r8/queries.log
eval "$1"
