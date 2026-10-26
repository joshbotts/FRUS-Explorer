# usage: headings_grep.py REGEX  -- list distinct (volume, section path) from work/structure_flat.tsv whose path matches REGEX (case-insensitive), with document counts
import re, sys, collections
rx = re.compile(sys.argv[1], re.I)
cnt = collections.OrderedDict()
for line in open("/Users/jbotts/frus-analysis/c3/runs/r1/work/structure_flat.tsv"):
    v, d, p = line.rstrip("\n").split("\t")
    if rx.search(p):
        cnt[(v, p)] = cnt.get((v, p), 0) + 1
print(len(cnt), "distinct (volume, path) headings;", sum(cnt.values()), "document ids")
for (v, p), n in cnt.items():
    print("%s | %d | %s" % (v, n, p[:230]))
