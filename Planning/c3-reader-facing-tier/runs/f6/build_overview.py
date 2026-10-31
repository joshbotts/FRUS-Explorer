import re,sqlite3,json
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
man={v["filename"][:-4]:" ".join(v["title"].split()) for v in json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))}
VOL={ # short volume label as printed
"frus1949v07p2":"Volume VII, Part 2","frus1950v06":"Volume VI","frus1952-54v12p2":"Volume XII, Part 2","frus1952-54v14p2":"Volume XIV, Part 2",
"frus1961-63v01":"Volume I","frus1961-63v02":"Volume II","frus1961-63v04":"Volume IV","frus1961-63v23":"Volume XXIII",
"frus1964-68v01":"Volume I","frus1964-68v02":"Volume II","frus1964-68v03":"Volume III","frus1964-68v26":"Volume XXVI","frus1964-68v27":"Volume XXVII",
"frus1917-72PubDipv06":"Public Diplomacy, Volume VI","frus1917-72PubDipv07":"Public Diplomacy, Volume VII","frus1917-72PubDipv08":"Public Diplomacy, Volume VIII",
"frus1969-76v19p2":"Volume XIX, Part 2","frus1969-76v38p2":"Volume XXXVIII, Part 2","frus1969-76ve12":"Volume E–12",
"frus1977-80v22":"Volume XXII","frus1977-80v30":"Volume XXX"}
def year(v,d):
    return con.execute("select substr(date_iso,1,4) from document_dates where volume_id=? and document_id=?",(v,d)).fetchone()[0]
def num(v,d):
    return con.execute("select document_number from document_cache where volume_id=? and document_id=?",(v,d)).fetchone()[0]
order=[]
def cite(m):
    key=m.group(1); v,d=key.split('/')
    if key not in order: order.append(key)
    return f"({year(v,d)}, {VOL[v]}, Document {num(v,d)})"
def full(key):
    v,d=key.split('/')
    t=man[v]
    # "Foreign Relations of the United States, 1958–1960, Volume VII, Part 1" + ", Document N"
    return f"{t}, Document {num(v,d)}"
src=open('overview_src.md',encoding='utf8').read()
text=re.sub(r'\{C:([^}]+)\}',cite,src)
docs="\n".join(f"{i+1}. {full(k)}. https://history.state.gov/historicaldocuments/{k.split('/')[0]}/{k.split('/')[1]}" for i,k in enumerate(order))
text=text.replace("{{DOCS}}",docs)
open('overview.md','w',encoding='utf8').write(text)
json.dump(order,open('cited_order.json','w'))
print(len(order),"documents cited")
