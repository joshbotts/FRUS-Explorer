import json,re
m=json.load(open('/Applications/FRUS Explorer.app/Contents/Resources/manifest.json'))
out=open('/Users/jbotts/frus-analysis/c3/runs/r9/volumes.tsv','w')
for v in m:
    t=re.sub(r'\s+',' ',v.get('title','')).strip()
    dr=v.get('dateRange') or {}
    out.write('\t'.join([v['volumeId'],v.get('subseries',''),str(dr.get('earliest',''))[:10],str(dr.get('latest',''))[:10],v.get('publicationDate',''),t])+'\n')
out.close()
