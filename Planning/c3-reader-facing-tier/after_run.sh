#!/bin/zsh
# After a run agent finishes: the harness's four scripts on its run directory. Usage: after_run.sh <label> <arm>
cd /Users/jbotts/frus-analysis/c3f || exit 1
l=$1; a=$2
[ -f runs/$l/overview.md ] || { echo "no overview.md in runs/$l"; }
python3 o2p_check.py runs/$l; python3 match_check.py runs/$l; python3 figures_check.py runs/$l $a
python3 style_measure.py runs/$l | python3 -c "import sys,ast; d=ast.literal_eval(sys.stdin.read()); print('style: median', d['median_sentence'], 'over40', d['share_over40'], 'part1', d['part1_words'], 'DocCited', d['documents_cited_list'].get('present'), 'unresolved', d['documents_cited_list'].get('unresolvedCount'), 'part2', d['part2'])"
ls runs/$l | wc -l | xargs echo files:
