# Literal share for the header FTS family. Hit list = SQL:
#  SELECT d.volume_id, d.document_id, d.header FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
#  WHERE frus_documents MATCH 'header:(asia OR asian OR "far east" OR japan OR japanese OR vietnam OR vietnamese OR korea OR korean OR philippines OR indonesia OR thailand OR burma OR laos OR cambodia OR malaya OR pacific OR china OR chinese OR okinawa OR australia)'
#  AND d.volume_id IN (7 information volumes) AND d.is_front_matter=0 AND d.is_editorial_note=0
# Census (42 < 300). Python re, IGNORECASE (stated). Surface: header+dateline+source_note+body_text? -> NO: the MATCH was on the header column, so the literal test is on header only, whitespace-collapsed.
import sqlite3,re
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
rows=c.execute("""SELECT d.volume_id, d.document_id, d.header FROM frus_documents f JOIN document_cache d ON d.rowid=f.rowid
 WHERE frus_documents MATCH 'header:(asia OR asian OR "far east" OR japan OR japanese OR vietnam OR vietnamese OR korea OR korean OR philippines OR indonesia OR thailand OR burma OR laos OR cambodia OR malaya OR pacific OR china OR chinese OR okinawa OR australia)'
 AND d.volume_id IN ('frus1917-72PubDipv06','frus1917-72PubDipv07','frus1917-72PubDipv08','frus1977-80v30','frus1961-63v25','frus1955-57v09','frus1969-76v38p2')
 AND d.is_front_matter=0 AND d.is_editorial_note=0 ORDER BY d.volume_id, d.document_id""").fetchall()
W=["Asia","Asian","Far East","Japan","Japanese","Vietnam","Vietnamese","Korea","Korean","Philippines","Indonesia","Thailand","Burma","Laos","Cambodia","Malaya","Pacific","China","Chinese","Okinawa","Australia"]
strict=re.compile(r"\b("+"|".join(re.escape(w) for w in W).replace(r"Far\ East",r"Far East")+r")\b",re.I)
tol=re.compile(r"\b(Asia\w*|Far[\s\-,().]+East\w*|Japan\w*|Viet[\s\-,().]*Nam\w*|Korea\w*|Philippin\w*|Indonesia\w*|Thai\w*|Burm\w*|Lao\w*|Cambodia\w*|Malaya\w*|Pacific|China|Chinese|Okinawa\w*|Australia\w*)\b",re.I)
s=t=0
for v,d,h in rows:
    h=re.sub(r"\s+"," ",h); a=bool(strict.search(h)); b=bool(tol.search(h)); s+=a; t+=b
    if not (a and b): print("MISS",v,d,"strict" if not a else "","tolerant" if not b else "",h[:150])
print("hits",len(rows),"STRICT",s,"of",len(rows),"TOLERANT",t,"of",len(rows))
