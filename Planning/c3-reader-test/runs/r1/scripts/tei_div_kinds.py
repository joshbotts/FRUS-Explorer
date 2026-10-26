# survey the <div> type/subtype combinations in a sample of TEI volumes (read-only), to define the counting surface
import re, collections, sys, glob, os
V = "/Users/jbotts/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/volumes"
sample = sys.argv[1:] or ["frus1933v05", "frus1944v07", "frus1961-63v12", "frus1923v02", "frus1913"]
rx = re.compile(r"<div\b([^>]*)>", re.S)
for vid in sample:
    s = open(os.path.join(V, vid + ".xml"), encoding="utf-8").read()
    c = collections.Counter()
    for m in rx.finditer(s):
        a = m.group(1)
        t = re.search(r'\btype="([^"]*)"', a); st = re.search(r'\bsubtype="([^"]*)"', a)
        c[(t.group(1) if t else None, st.group(1) if st else None)] += 1
    print(vid, len(s), dict(c))
