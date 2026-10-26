# setB_snips.py: for each Set B pair, concatenate header+dateline+source_note+body_text, collapse whitespace,
# find every literal 'recogni...' (case-insensitive, Python re) and print +-160 chars around each; also test
# STRICT and TOLERANT literal forms of the NEAR query (recognition word within 12 words of a companion term).
import sqlite3,re,sys
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
pairs=[l.strip().split('\t') for l in open('setB_pairs.tsv')]
comp_strict=r'(junta|coup|new government|military government|de facto|revolutionary government|provisional government|new regime|military regime|constitutional government)'
comp_tol=r'(juntas?|coups?|new[\s,.\-()]+governments?|military[\s,.\-()]+governments?|de[\s\-]+facto|revolutionary[\s,.\-()]+governments?|provisional[\s,.\-()]+governments?|new[\s,.\-()]+regimes?|military[\s,.\-()]+regimes?|constitutional[\s,.\-()]+governments?)'
w12=r'(?:\S+\s+){0,12}'
strict=re.compile(r'(recogni\w*\s+'+w12+comp_strict+r'\b|\b'+comp_strict+r'\s+'+w12+r'recogni\w*)',re.I)
tol=re.compile(r'(recogni\w*[\s,.\-()]+'+w12+comp_tol+r'\b|\b'+comp_tol+r'[\s,.\-()]+'+w12+r'recogni\w*)',re.I)
snip=open('setB_snippets.txt','w'); ns=nt=0; rows=[]
for v,d in pairs:
    r=con.execute("SELECT header,dateline,source_note,body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()
    txt=' '.join(' '.join(x or '' for x in r).split())
    s=bool(strict.search(txt)); t=bool(tol.search(txt)); ns+=s; nt+=t
    rows.append(f"{v}\t{d}\t{int(s)}\t{int(t)}")
    snip.write(f"=== {v}/{d} strict={int(s)} tolerant={int(t)} len={len(txt)}\n")
    for m in list(re.finditer(r'recogni\w*',txt,re.I))[:4]:
        a=max(0,m.start()-160); b=min(len(txt),m.end()+160)
        snip.write('  ...'+txt[a:b]+'...\n')
snip.close()
open('setB_share.tsv','w').write('\n'.join(rows)+'\n')
print(f"Set B literal share: STRICT {ns} of {len(pairs)}; TOLERANT {nt} of {len(pairs)}")
