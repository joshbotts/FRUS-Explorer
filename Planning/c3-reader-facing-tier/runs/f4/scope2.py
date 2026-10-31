import json,re
m=json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))
vols=[]
for v in m:
    t=re.sub(r'\s+',' ',v['title'])
    vid=v['volumeId']
    if re.search(r'1969-76ve12|1977-80v22|1977-80v13|1958-60v16|1952-54v12|1950v06|1951v06|1955-57v21|1955-57v22|1961-63v22|1961-63v23|1964-68v26|1964-68v27|1964-68v29|1964-68v30|1952-54v14|1952-54v15|1952-54v13|1955-57v23|1958-60v18|1958-60v17|1969-76v1[789]|1969-76v20|1969-76ve13|PubDip|1961-63v25|1955-57v09|1969-76v38p2|1977-80v30|1955-57v0[123]|1958-60v1[19]|1948v06|1949v07|1946v08|1947v06|1950v07|1951v07|1952-54v13|1964-68v0|1961-63v0|1969-76v0|1969-76v10|1969-76v42|1964-68v28|1961-63v24',vid):
        vols.append(vid)
print(len(vols)); print(' '.join(vols))
json.dump(vols,open('scope_vols.json','w'))
