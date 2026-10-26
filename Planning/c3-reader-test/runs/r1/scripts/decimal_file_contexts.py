# Print up to N short contexts where each bundled JSON file names the central decimal file (case-insensitive). usage: decimal_file_contexts.py [N]
import re, sys, glob
R = "/Applications/FRUS Explorer.app/Contents/Resources/"
N = int(sys.argv[1]) if len(sys.argv) > 1 else 3
pat = re.compile(r"central decimal|decimal file", re.I)
for f in sorted(glob.glob(R + "*.json")):
    t = open(f, encoding="utf-8").read()
    ms = list(pat.finditer(t))
    if not ms: continue
    print("==", f.split("/")[-1], "| hits:", len(ms))
    for m in ms[:N]:
        print("   ...", t[max(0, m.start() - 160): m.end() + 200].replace("\n", " "))
