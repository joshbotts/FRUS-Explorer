import json,re
m=json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))
R=[];G=[]
for v in m:
    t=re.sub(r'\s+',' ',v['title']).replace('Foreign Relations of the United States, ','')
    vid=v['volumeId']
    if vid.endswith('Ed2') or 'mSupp' in vid: pass
    # year from the title start
    y=re.match(r'(?:Diplomatic Papers, )?(\d{4})',t)
    yr=int(y.group(1)) if y else 0
    if yr>=1945 and re.search(r'Far East|China|Japan|Korea|Vietnam|Indochina|Southeast Asia|East Asia|Pacific|Indonesia|Laos|Northeast Asia|Cambodia|Philippines|Australasia|Asia',t) and not re.search(r'South Asia|Near East|Documents on South Asia|South and Southeast',t.replace('South and Southeast Asia','South and Southeast')) :
        R.append((vid,t))
    if re.search(r'Public Diplomacy|Information Policy|Foreign Information Program|Organization and Management of Foreign Policy',t):
        G.append((vid,t))
for a in (R,G):
    for x in a: print(x[0],'|',x[1][:100])
    print('---')
json.dump({'R':[x[0] for x in R],'G':[x[0] for x in G]},open('scope_sets.json','w'))
