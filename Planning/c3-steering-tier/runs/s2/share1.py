# literal share (strict/tolerant) on evenly spaced 40 of the family hit list, plus a referent check
import sqlite3, json, re
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
hits = json.load(open("family_hits.json"))
N = len(hits); step = N/40.0
sample = [hits[int(i*step)] for i in range(40)]
STRICT = re.compile(r"\b(corrupt|corruption|bribe|bribery|graft|kickback|embezzlement)\b", re.I)
TOL = re.compile(r"\b(corrupt\w*|brib\w*|graft(s|ing|er|ers|ed)?|kick[\s\-]?backs?|embezzl\w*)\b", re.I)
TELEG = re.compile(r"(corrupt(ed)?\s+(group|text|word|passage|telegram|in transmission))|(group[s]?\s+corrupt)|(text\s+(is\s+)?corrupt)|garble", re.I)
SQL = "SELECT header, COALESCE(dateline,''), COALESCE(source_note,''), body_text FROM document_cache WHERE volume_id=? AND document_id=?"
print("SQL:", SQL); print("STRICT:", STRICT.pattern); print("TOLERANT:", TOL.pattern); print("TELEGRAPHIC:", TELEG.pattern)
s=t=0; rows=[]
for v,d in sample:
    r = con.execute(SQL,(v,d)).fetchone()
    txt = re.sub(r"\s+"," "," ".join(r))
    a = bool(STRICT.search(txt)); b = bool(TOL.search(txt)); s+=a; t+=b
    m = [x.group(0) for x in TOL.finditer(txt)][:4]
    # referent: political/financial sense vs other: show contexts
    ctx = [txt[max(0,x.start()-60):x.end()+60] for x in TOL.finditer(txt)][:2]
    rows.append((v,d,a,b,m, bool(TELEG.search(txt)), ctx))
print("hit list N =", N)
print("STRICT share: %d of 40; TOLERANT share: %d of 40" % (s,t))
for r in rows: print(r[0], r[1], "S" if r[2] else "-", "T" if r[3] else "-", r[4], "TELEG" if r[5] else "", "|", r[6][0][:150] if r[6] else "")
