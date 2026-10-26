# Resolve scope lots (came-from and pointed-at, kept separate) via central-files-index.lotFiles + series-facts-index.byNaId; also lot-claimants-index
import json,collections
R="/Applications/FRUS Explorer.app/Contents/Resources"
c=json.load(open(R+"/central-files-index.json")); sf=json.load(open(R+"/series-facts-index.json")); lc=json.load(open(R+"/lot-claimants-index.json"))
rows=json.load(open("arch_rows.json"))
by=collections.defaultdict(list)
for r in c['lotFiles']: by[r['lotNumber']].append(r)
claim={r.get('lotNumber'):r for r in lc['lots']} if isinstance(lc.get('lots'),list) else {}
def facts(n):
    r=sf['byNaId'].get(str(n))
    if not r: return "no series-facts row"
    return "creator=%s; inclusive %s-%s; access=%s; extent=%s"%(sf['headings'][r['c']] if 'c' in r else None, r.get('y0'),r.get('y1'),sf['statuses'][r['as']] if 'as' in r else None, r.get('x'))
for chan,key,idx in (("CAME-FROM","camefrom",4),("POINTED-AT","pointedat",5)):
    cnt=collections.Counter(r[idx] for r in rows[key] if r[idx] and r[idx]!="NO")
    print("==",chan,"distinct lots",len(cnt))
    for lot,n in sorted(cnt.items()):
        docs=sorted({"%s/%s"%(r[0],r[1]) for r in rows[key] if r[idx]==lot})
        hits=by.get(lot,[])
        if not hits: print(lot,n,"docs",docs,"-> not in central-files-index"); continue
        for h in hits:
            print(lot,n,"docs",docs,"-> RG",h['recordGroup'],"entry",h.get('hmsMlrEntryNumbers'),"NAID",h['naId'],"|",h['title'],"|",facts(h['naId']),"| claimants:" ,"yes" if lot in claim else "no")
