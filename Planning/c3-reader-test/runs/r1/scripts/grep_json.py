# usage: grep_json.py REGEX [files...] -- search the bundled JSON files (raw text) for a regex; print file, count, and up to 4 snippets
import re, sys, glob, os
R = "/Applications/FRUS Explorer.app/Contents/Resources"
rx = re.compile(sys.argv[1], re.I)
files = sys.argv[2:] or sorted(glob.glob(R + "/*.json"))
for f in files:
    s = open(f, encoding="utf-8").read()
    ms = list(rx.finditer(s))
    if ms:
        print("%s: %d matches" % (os.path.basename(f), len(ms)))
        for m in ms[:4]:
            print("    ...%s..." % s[max(0, m.start() - 150):m.end() + 200].replace("\n", " "))
