# resolve lots from channels.txt via central-files-index.json lotFiles (lotNumber spaces folded) -> naId -> series-facts-index byNaId
# also scan collection-authority / series-facts headings for RG 306 USIA series
import json,re
P="/Applications/FRUS Explorer.app/Contents/Resources/"
cf=json.load(open(P+'central-files-index.json')); sf=json.load(open(P+'series-facts-index.json'))
L=sf['legend']['keys']
def facts(naid):
    r=sf['byNaId'].get(str(naid))
    if not r: return None
    o={}
    for k,v in r.items():
        spec=L.get(k)
        if not spec: o[k]=v; continue
        if spec['kind']=='index': o[spec['field']]=sf[spec['into']][v]
        elif spec['kind']=='indexList': o[spec['field']]=[sf[spec['into']][i] for i in v]
        else: o[spec['field']]=v
    return o
lots={}
for row in cf['lotFiles']: lots.setdefault(row['lotNumber'].replace(' ',''),[]).append(row)
for lot in ['59D260','63D224','62D255','60D322']:
    for row in lots.get(lot,[]):
        print(lot,'| RG',row.get('recordGroup'),'| NAID',row.get('naId'),'| entry',row.get('hmsMlrEntryNumbers'),'|',row.get('title'),'|',row.get('matchType'))
        f=facts(row.get('naId'));
        if f: print('    facts:',{k:f.get(k) for k in ['creator','inclusiveStartYear','inclusiveEndYear','accessStatus','useStatus','extent','accessRestrictions']})
    if lot not in lots: print(lot,'NOT IN central-files-index lotFiles')
# RG 306 series present in series-facts?
n306=0
for naid,r in sf['byNaId'].items():
    f=facts(naid); c=str(f.get('creator',''))
    if 'Information Agency' in c: n306+=1
print('series-facts rows whose creator names Information Agency:',n306)
# pre-1940 share
tot=len(sf['byNaId']); pre=sum(1 for n in sf['byNaId'] if (facts(n).get('inclusiveStartYear') or 9999)<1940)
print('series-facts rows',tot,'with inclusiveStartYear<1940:',pre)
