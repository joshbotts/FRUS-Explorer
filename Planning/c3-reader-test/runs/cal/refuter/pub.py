import json
m = json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))
byid = {v["volumeId"]: v for v in m}
nine = ["frus1961-63v10","frus1961-63v11","frus1961-63v12","frus1961-63v10-12mSupp","frus1964-68v32","frus1969-76ve10","frus1969-76ve11p1","frus1977-80v23","frus1977-80v24"]
memo_pub = {"frus1961-63v10":1997,"frus1961-63v11":1996,"frus1961-63v12":1996,"frus1961-63v10-12mSupp":2021,"frus1964-68v32":2005,"frus1969-76ve10":2009,"frus1969-76ve11p1":2015,"frus1977-80v23":2016,"frus1977-80v24":2018}
for vid in nine:
    v = byid[vid]
    print(vid, "publicationDate=", v.get("publicationDate"), "status=", v.get("status"), "memo says", memo_pub[vid], "OK" if str(v.get("publicationDate","")).startswith(str(memo_pub[vid])) else "MISMATCH")
print("statuses over manifest:", {})
from collections import Counter
print(Counter(v.get("status") for v in m))
# volumes in American Republics / Latin America by title among 1981-88
for v in m:
    if v["volumeId"].startswith("frus1981-88"):
        t = " ".join(v["title"].split())
        tags = v.get("tags")
        print(v["volumeId"], "|", t.split("Volume")[-1].strip(), "| tags:", tags if tags else None)
