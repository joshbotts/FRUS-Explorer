import json
R="/Applications/FRUS Explorer.app/Contents/Resources/"
sf=json.load(open(R+"series-facts-index.json")); out=[]
def show(n):
    f=sf["byNaId"].get(str(n))
    if not f: out.append(f"NAID {n}: no series-facts row (no dates/access/extent offline)"); return
    out.append(f"NAID {n}: creator={sf['headings'][f['c']] if 'c' in f else None}; inclusive={f.get('y0')}-{f.get('y1')}; coverage={f.get('cy0')}-{f.get('cy1')}; access={sf['statuses'][f['as']] if 'as' in f else None}; extent={f.get('x')}")
for n in [2839192,2839193,2839191,2838992,1257679,40967285,40943515,1254251,42125423,48349732,5552237,5585931,2386675,2839190,2842737]: show(n)
a=json.load(open(R+"accession-series-index.json"))["byAccession"]
for k in ["306/67A222","306/68A4933","306/72A5121","306/840003"]: out.append(f"accession {k}: {len(a[k])} series: "+"; ".join(f"{x['n']} {x['t']}" for x in a[k]) if isinstance(a[k],list) else f"accession {k}: 1 series {a[k]}")
c=json.load(open(R+"central-files-index.json")); rows={r["lotNumber"]:r for r in c["lotFiles"]}
lc={r["lotNumber"]:r for r in json.load(open(R+"lot-claimants-index.json"))["lots"]}
for lot in ["63D351","66D95","62D430","62D1"]:
    r=rows[lot]; out.append(f"lot {lot}: control match NAID {r['naId']} RG {r['recordGroup']} '{r['title']}' entries {r.get('hmsMlrEntryNumbers')}; claimants: "+(str([(x['naId'],x['title'],x['dateRange']) for x in lc[lot]['claimants']]) if lot in lc else "none listed"))
pl=json.load(open(R+"presidential-library-catalog.json"))
for l in pl["libraries"]:
    for c2 in l["collections"]:
        if c2["naId"] in (567979,1164,572235,1104,50809179,645643):
            out.append(f"{l['citedAs']} {c2['identifier']} NAID {c2['naId']} '{c2['title']}' series: "+"; ".join(f"{s['naId']} {s['title']} {s['inclusiveDates']}" for s in c2.get('series',[]) if c2['naId']!=567979 or s['naId'] in (591194,587358)))
d=json.load(open(R+"decimal-class-labels.json"))
sch={s['id']:s for s in d['schedules']}
out.append("decimal: 1910-1949 country 90 = "+sch['1910-1949']['countries']['90']+"; 1950-1959 country 90 = "+sch['1950-1959']['countries']['90']+"; 1960-1963 country 98 = "+sch['1960-1963']['countries']['98'])
open("archival_facts.txt","w").write("\n".join(out)+"\n"); print("\n".join(out)[:6000])
