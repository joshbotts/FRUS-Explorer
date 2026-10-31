import json,re
m=json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))
for v in m:
    t=re.sub(r'\s+',' ',v['title']).replace('Foreign Relations of the United States, ','')
    y=v['dateRange']['earliest'][:4] if v.get('dateRange') else '?'
    if int(y)>=1940 and re.search(r'China|Japan|Korea|Vietnam|Indochina|Southeast Asia|East Asia|Pacific|Philipp|Indonesia|Laos|Cambodia|Thailand|Taiwan|Australia|Burma|Malaysia|Far East|Information|Cultural|Public Diplom|Propaganda|Psychological|Asia|Mongolia|Oceania',t):
        print(v['volumeId'], y, '|', t[:130])
