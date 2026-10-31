import sqlite3, json, re
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
R="/Applications/FRUS Explorer.app/Contents/Resources"
man={m["volumeId"]:m for m in json.load(open(R+"/manifest.json"))}
KEYS="""frus1943China/d202 frus1944v06/d269 frus1947v07/d591 frus1948v07/d590 frus1958-60v01/d111 frus1958-60v01/d160 frus1964-68v04/d280 frus1964-68v05/d197 frus1964-68v05/d258 frus1969-76v06/d175 frus1961-63v23/d355 frus1961-63v22/d249 frus1961-63v17/d27 frus1969-76ve09p2/d122 frus1977-80v18/d206 frus1977-80v23/d252 frus1969-76ve09p2/d152 frus1969-76ve15p2/d292 frus1969-76ve15p2/d293 frus1969-76ve09p2/d161 frus1969-76ve09p1/d49 frus1969-76ve12/d219 frus1969-76ve12/d222 frus1969-76ve12/d224 frus1977-80v03/d248 frus1894app2/d255 frus1894app2/d306""".split()
out={}
for k in KEYS:
    v,d=k.split("/")
    r=con.execute("SELECT d.header,d.dateline,d.document_number,dd.date_iso,d.is_front_matter,d.is_editorial_note FROM document_cache d LEFT JOIN document_dates dd ON dd.volume_id=d.volume_id AND dd.document_id=d.document_id WHERE d.volume_id=? AND d.document_id=?",(v,d)).fetchone()
    t=re.sub(r"\s+"," ",man[v]["title"]).strip()
    out[k]=dict(header=r[0],dateline=r[1],num=r[2],date=r[3],vol_title=t,pub=man[v]["publicationDate"],subseries=man[v].get("subseries"))
    print(k,"|",r[3],"|",r[2],"|",r[0][:70],"|",t[:110],"|",r[4],r[5])
json.dump(out,open("meta.json","w"),indent=1,ensure_ascii=False)
