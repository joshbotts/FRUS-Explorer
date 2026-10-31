# core_clean.py: census over raw/coreset.tsv. A doc is kept (raw/coreset_clean.tsv) when the TOLERANT regex below matches
# (Python re, IGNORECASE, header+dateline+source_note+body_text whitespace-collapsed); USIE (Information and Educational Exchange) added.
# Docs dropped are mostly "USI" = United States of Indonesia (false friend of the stem 'usi').
import sqlite3,re,collections
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
T=re.compile(r'\b(USIAs?|USIS|USIE|information[\s\-,().]+programs?|psychological[\s\-,().]+(strateg\w*|warfare)|cultural[\s\-,().]+exchanges?|U\.\s?S\.\s?I\.\s?[AS]\.?|Information Agency|Information Service)',re.I)
USI=re.compile(r'\bUSI\b')
core=[tuple(l.split('\t')) for l in open('raw/coreset.tsv').read().split('\n') if l]
keep=[];drop=collections.Counter();usi=0
for v,d in core:
    x=re.sub(r'\s+',' ',' '.join(con.execute("SELECT header,coalesce(dateline,''),coalesce(source_note,''),body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()))
    if T.search(x): keep.append((v,d))
    else:
        drop[v]+=1
        if USI.search(x): usi+=1
open('raw/coreset_clean.tsv','w').write('\n'.join(v+'\t'+d for v,d in keep)+'\n')
print('core',len(core),'kept',len(keep),'dropped',len(core)-len(keep),'of which contain bare USI',usi)
print('dropped by volume',drop.most_common(8))
print('kept volumes',len(set(v for v,d in keep)))
