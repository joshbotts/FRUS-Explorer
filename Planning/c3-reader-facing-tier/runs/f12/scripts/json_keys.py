# print top-level keys/shapes of bundled JSON files
import json,sys
B="/Applications/FRUS Explorer.app/Contents/Resources/"
for f in sys.argv[1:]:
    j=json.load(open(B+f)); print("##",f,type(j).__name__)
    if isinstance(j,dict):
        for k,v in j.items(): print("  ",k,type(v).__name__, (len(v) if hasattr(v,'__len__') else v) if not isinstance(v,(str,int,float)) else str(v)[:100])
