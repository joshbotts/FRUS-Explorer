import json,re
m=json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))
pat=re.compile(r"china|japan|korea|vietnam|indochina|laos|cambodia|pacific|east asia|far east|philippin|taiwan|southeast asia|asia|thailand|indonesia|australia|burma|information|psychological|cultural",re.I)
for v in m:
    t=" ".join(v["title"].split())
    if v["publicationDate"] and pat.search(t) and v["dateRange"]["earliest"][:4]>="1941":
        print(v["volumeId"],"|",t[:130],"|",v["dateRange"]["earliest"][:4],v["dateRange"]["latest"][:4])
