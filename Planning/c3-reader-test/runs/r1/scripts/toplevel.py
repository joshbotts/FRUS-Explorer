# usage: toplevel.py VOLUME [depth] -- print the distinct section paths (to given depth, default 1) of a volume with document counts
import sys, collections
v0 = sys.argv[1]; depth = int(sys.argv[2]) if len(sys.argv) > 2 else 1
c = collections.OrderedDict()
for line in open("/Users/jbotts/frus-analysis/c3/runs/r1/work/structure_flat.tsv"):
    v, d, p = line.rstrip("\n").split("\t")
    if v != v0:
        continue
    k = " > ".join(p.split(" > ")[:depth])
    c[k] = c.get(k, 0) + 1
for k, n in c.items():
    print("%5d  %s" % (n, k[:200]))
