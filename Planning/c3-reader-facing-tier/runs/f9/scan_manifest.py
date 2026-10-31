import json,re
m=json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))
pat=re.compile(r'(east asia|china|japan|korea|southeast asia|indochina|vietnam|laos|cambodia|philippin|indonesia|burma|thailand|pacific|public diplomacy|information|propaganda|psycholog|asia|far east)',re.I)
for v in m:
    t=re.sub(r'\s+',' ',v['title']); y=v['dateRange']['earliest'][:4]
    if int(y)>=1940 and pat.search(t): print(v['volumeId'],'|',t.replace('Foreign Relations of the United States, ',''),'|',v['dateRange']['earliest'][:10],v['dateRange']['latest'][:10])
