# SQL per quote: SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0
# test 1: exact substring of raw body_text; test 2: substring after whitespace-collapse
import sqlite3,json,re,sys
c=sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro",uri=True)
qs=json.load(open(sys.argv[1])); bad=0
for v,d,q in qs:
    r=c.execute("SELECT body_text FROM document_cache WHERE volume_id=? AND document_id=? AND is_front_matter=0 AND is_editorial_note=0",(v,d)).fetchone()
    if not r: print("NODOC",v,d); bad+=1; continue
    raw=q in r[0]; col=re.sub(r'\s+',' ',q) in re.sub(r'\s+',' ',r[0])
    print(("OK " if raw else ("COLLAPSED-ONLY " if col else "FAIL ")),v,d,q[:60]); bad+= (not raw)
print("not-raw:",bad,"of",len(qs))
