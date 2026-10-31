import json,re,sys
R="/Applications/FRUS Explorer.app/Contents/Resources/"
pats=sys.argv[1:]
import glob
for f in sorted(glob.glob(R+"*.json")):
    s=open(f,encoding='utf8').read()
    for p in pats:
        n=len(re.findall(p,s))
        if n: print(f.split('/')[-1],repr(p),n)
