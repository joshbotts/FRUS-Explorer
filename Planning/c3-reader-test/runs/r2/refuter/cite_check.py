# Resolve every printed edition citation in overview.md "(<title>, Document N, <url>)" through manifest.json and document_cache.document_number.
import json, re, sqlite3
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
man={v['volumeId']: re.sub(r'\s+',' ',v['title']).strip() for v in json.load(open("/Applications/FRUS Explorer.app/Contents/Resources/manifest.json"))}
ov=open('/Users/jbotts/frus-analysis/c3/runs/r2/overview.md',encoding='utf-8').read()
cites=re.findall(r'\(((?:Papers Relating to the )?Foreign Relations of the United States[^()]*?), Document (\d+), https://history\.state\.gov/historicaldocuments/([A-Za-z0-9\-]+)/(d\d+)\)', ov)
print("citation instances:", len(cites))
bad=0; seen=set()
for title, num, vol, doc in cites:
    mt=man.get(vol)
    dn=con.execute("SELECT document_number FROM document_cache WHERE volume_id=? AND document_id=?", (vol,doc)).fetchone()
    # printed title must match the manifest title; the 1861-1912 annual volumes print a long "With the Annual Message..." title, so accept a prefix match on the year
    t_ok = (mt == title) or (mt is not None and mt.startswith(title)) or (mt is not None and re.sub(r', With the Annual Message.*$','',mt)==title)
    n_ok = dn is not None and dn[0]==num
    key=(vol,doc)
    flag="OK " if (t_ok and n_ok) else "BAD"
    if not (t_ok and n_ok): bad+=1
    if key not in seen:
        seen.add(key)
        print(f"{flag} {vol}/{doc} doc#={dn[0] if dn else None} printed='Document {num}' | title_ok={t_ok} | printed='{title}' | manifest='{mt}'")
print("distinct pairs:", len(seen), "| bad instances:", bad)
# any URL citation not in the parenthetical form?
allurls=re.findall(r'https://history\.state\.gov/historicaldocuments/([A-Za-z0-9\-]+)/(d\d+)', ov)
print("all URL instances:", len(allurls), "| parenthetical:", len(cites))
