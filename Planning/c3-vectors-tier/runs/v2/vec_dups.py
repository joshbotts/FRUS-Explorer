# Near-duplicate scan within the Cuba core set (coreset.json): every pair with Hamming <= 20 of 512 bits
# (random-pair mean 167.1, sd 14.8, min 95 at this digest; see vec_check_out.txt). Writes vec_dups.tsv.
import json
from veclib import *
core = [(x["v"], x["d"]) for x in json.load(open("coreset.json")) if (x["v"], x["d"]) in row_of]
miss = len(json.load(open("coreset.json"))) - len(core)
S = [SIGNS[row_of[k]] for k in core]; out = open("vec_dups.tsv", "w"); n = 0
for i in range(len(S)):
    a = S[i]
    for j in range(i + 1, len(S)):
        h = bin(a ^ S[j]).count("1")
        if h <= 20:
            out.write(f"{h}\t{core[i][0]}/{core[i][1]}\t{core[j][0]}/{core[j][1]}\n"); n += 1
    if i % 1000 == 0: print("progress", i, flush=True)
out.close(); print("core rows in vectors", len(core), "not in vectors", miss, "pairs<=20", n)
