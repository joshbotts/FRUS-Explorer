# read_docs.py PAIR [PAIR...] [--grep REGEX] : reads each document whole (SELECT header, dateline, source_note, body_text,
# length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?), writes the raw text to reading/<vol>__<doc>.txt,
# appends (pair, length(body_text), captured length) to reading_log.tsv, and prints the header, the date and
# every match of REGEX (default recogni) with 220 characters either side, whitespace-collapsed, at most 8 per document.
import sqlite3,sys,re,os
os.chdir('/Users/jbotts/frus-analysis/c3/runs/r9')
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
args=sys.argv[1:]; rx='recogni'; width=220; maxm=8
if '--grep' in args: i=args.index('--grep'); rx=args[i+1]; del args[i:i+2]
if '--width' in args: i=args.index('--width'); width=int(args[i+1]); del args[i:i+2]
if '--max' in args: i=args.index('--max'); maxm=int(args[i+1]); del args[i:i+2]
log=open('reading_log.tsv','a')
for pair in args:
    v,d=pair.split('/')
    r=con.execute("SELECT header, dateline, source_note, body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    if not r: print('NO ROW',pair); continue
    h,dl,sn,body,L=r
    with open(f'reading/{v}__{d}.txt','w') as f: f.write(f"HEADER: {h}\nDATELINE: {dl}\nSOURCE: {sn}\nBODY:\n{body}")
    log.write(f"{v}\t{d}\t{L}\t{len(body)}\n")
    dd=con.execute("SELECT date_iso FROM document_dates WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    print(f"##### {pair} | {' '.join((h or '').split())[:100]} | {dd[0] if dd else None} | len(body_text)={L} captured={len(body)}")
    txt=' '.join(body.split())
    for m in list(re.finditer(rx,txt,re.I))[:maxm]:
        a=max(0,m.start()-width); b=min(len(txt),m.end()+width)
        print('   >>', txt[a:b])
log.close()
