import json
R="/Applications/FRUS Explorer.app/Contents/Resources/"
cf=json.load(open(R+"central-files-index.json")); sf=json.load(open(R+"series-facts-index.json"))
want=[("colombia","1900-09-08"),("venezuela","1899-10-23"),("ecuador","1895-11-06"),("venezuela","1899-11-18")]
for c in cf['countrySeries']:
    if c['category'] not in ('diplomaticInstructions','diplomaticDespatches'): continue
    for g,d in want:
        for r in c['rolls']:
            if g in r.get('geoKeys',[]) and r.get('startISO') and r.get('endISO') and r['startISO']<=d<=r['endISO']:
                f=sf['byNaId'].get(r.get('fileUnitNaId'))
                print(c['category'],g,d,'|',r.get('fileUnitTitle'),'|',r['title'],'| roll NAID',r['naId'],'| file unit NAID',r.get('fileUnitNaId'),'| series-facts for file unit:',bool(f))
