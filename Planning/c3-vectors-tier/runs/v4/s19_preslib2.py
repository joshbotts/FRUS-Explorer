# Match collection title within each library (citedAs) to the name FRUS uses.
import json,re
p=json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/presidential-library-catalog.json"))
want=[('Kennedy Library',r'national security files'),('Johnson Library',r'national security file'),('Carter Library',r'national security affairs|brzezinski'),('Eisenhower Library',r'whitman|ann whitman|papers as president')]
for lib,pat in want:
    L=[x for x in p['libraries'] if x['citedAs']==lib]
    for x in L:
        for col in x['collections']:
            if re.search(pat,col['title'],re.I): print(lib,'|',col['identifier'],'| collection NAID',col['naId'],'|',col['title'],'| series',len(col.get('series',[])), [ (s['title'],s['inclusiveDates'],s['naId']) for s in col.get('series',[])][:3])
