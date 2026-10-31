import json,sys
R="/Applications/FRUS Explorer.app/Contents/Resources"
ci=json.load(open(R+"/central-files-index.json")); sf=json.load(open(R+"/series-facts-index.json"))
def facts(na):
    r=sf['byNaId'].get(str(na))
    if not r: return None
    g=lambda k,arr: sf[arr][r[k]] if k in r else None
    return dict(creator=g('c','headings'), y0=r.get('y0'), y1=r.get('y1'), extent=r.get('x'), access=g('as','statuses'), use=g('us','statuses'), ref=g('ru','referenceUnits'))
for lot in sys.argv[1:]:
    rows=[x for x in ci['lotFiles'] if x['lotNumber']==lot]
    if not rows: print(lot,'-> NOT IN central-files-index'); continue
    for x in rows:
        print(lot,'->',x['recordGroup'],x.get('hmsMlrEntryNumbers'),x['naId'],x['title'][:90],x['matchType'],'|',facts(x['naId']))
