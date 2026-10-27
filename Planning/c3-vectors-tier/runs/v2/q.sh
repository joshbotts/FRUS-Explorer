#!/bin/zsh
# logs the command verbatim to queries.log then runs it
print -r -- "$1" >> /Users/jbotts/frus-analysis/c3v/runs/v2/queries.log
eval "$1"
