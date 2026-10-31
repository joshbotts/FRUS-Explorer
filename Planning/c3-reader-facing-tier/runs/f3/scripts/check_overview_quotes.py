# check_overview_quotes.py: every "..." / “...” span in overview.md (split on ' … ') must occur case-sensitively in the body_text of one of the 23 collection docs
import re,sqlite3
con=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
ids=[p.split('/') for p in open('raw/collection_ids.txt').read().split()]
bodies=[con.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=?",(v,d)).fetchone()[0] for v,d in ids]
t=open('overview.md').read()
spans=re.findall(r'"([^"]+)"',t)
bad=0
for s in spans:
    for part in s.split(' … '):
        part=part.strip()
        hit=[ '/'.join(ids[i]) for i,b in enumerate(bodies) if part in b]
        print(('OK  ' if hit else 'MISS'),repr(part[:90]),hit[:2]); bad+= not hit
print('misses',bad,'of',sum(len(s.split(' … ')) for s in spans))
