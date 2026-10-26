# Dumps whole documents to raw/<vid>__<did>.txt (header, dateline, source_note, body_text) and records captured vs stored
# length in out/reading_log.tsv. Then prints the windows around recogni* (up to W windows of C chars each side).
import sqlite3, re, sys, os
R="/Users/jbotts/frus-analysis/c3/runs/r7/"
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
pairs=[a.split("/") for a in sys.argv[1].split(",")]
W=int(sys.argv[2]) if len(sys.argv)>2 else 3; C=int(sys.argv[3]) if len(sys.argv)>3 else 350
log=open(R+"out/reading_log.tsv","a"); q=open(R+"queries.log","a")
for vid,did in pairs:
    sql="SELECT header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0"
    q.write(f'sqlite3 ro "{sql}" -- ({vid}, {did})  -> raw/{vid}__{did}.txt\n')
    row=con.execute(sql,(vid,did)).fetchone()
    if not row: print("## NOT FOUND or apparatus:", vid, did); continue
    h,dl,sn,b,n=row
    fn=R+f"raw/{vid}__{did}.txt"
    with open(fn,"w") as f: f.write(f"HEADER: {h}\nDATELINE: {dl}\nSOURCE: {sn}\nLENGTH(body_text): {n}\n---BODY---\n{b}")
    log.write(f"{vid}\t{did}\t{n}\t{len(b)}\twhole\n")
    print(f"## {vid}/{did} | {' '.join((h or '').split())[:100]} | {' '.join((dl or '').split())[:70]} | body {n} chars (captured {len(b)})")
    text=" ".join(b.split())
    shown=0; last=-10**9
    for m in re.finditer(r"recogni", text, re.I):
        if m.start()-last < C: continue
        s=max(0,m.start()-C); e=min(len(text), m.end()+C)
        print("   …"+text[s:e]+"…"); shown+=1; last=m.start()
        if shown>=W: break
    if shown==0: print("   (no 'recogni' in body) first 500: "+text[:500])
log.close(); q.close()
