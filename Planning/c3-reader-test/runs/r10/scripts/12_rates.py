# Per-decade rates for a hit list: numerator = hits in decade (by date_iso), denominator = dated non-apparatus documents
# in the decade (corpus-wide, and Latin American universe), from out/06_decades.txt; plus the top volume's share of
# the numerator. argv: hits_file (LA-restricted, from 08_fts_family.py), corpus-wide decade counts parsed from the
# family's 08 output file (argv[2]).
import collections, sys
hits_file, fam_out = sys.argv[1], sys.argv[2]
den_all, den_la = {}, {}
for line in open("/Users/jbotts/frus-analysis/c3/runs/r10/out/06_decades.txt"):
    f = line.rstrip("\n").split("\t")
    if len(f) == 3 and f[0].endswith("0s"):
        den_all[f[0]] = int(f[1]); den_la[f[0]] = int(f[2])
corp = {}
for line in open(fam_out):
    f = line.rstrip("\n").split("\t")
    if len(f) == 3 and f[0].endswith("0s"):
        corp[f[0]] = int(f[1])
byvol = collections.defaultdict(collections.Counter)
for line in open(hits_file):
    v, d, di, p = line.rstrip("\n").split("\t")[:4]
    if di:
        byvol[di[:3] + "0s"][v] += 1
print("decade\tLA_hits\tLA_denom\tLA_per1000\ttop_volume\ttop_share\tcorpus_hits\tcorpus_denom\tcorpus_per1000")
for dec in sorted(den_all):
    if dec < "1860s": continue
    n = sum(byvol[dec].values())
    top = byvol[dec].most_common(1)
    tv, tn = (top[0] if top else ("-", 0))
    print("%s\t%d\t%d\t%.1f\t%s\t%d of %d\t%d\t%d\t%.1f" % (dec, n, den_la[dec], 1000.0 * n / den_la[dec] if den_la[dec] else 0,
          tv, tn, n, corp.get(dec, 0), den_all[dec], 1000.0 * corp.get(dec, 0) / den_all[dec]))
