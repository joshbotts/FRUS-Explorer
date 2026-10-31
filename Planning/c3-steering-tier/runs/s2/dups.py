# compare both texts of every near-duplicate pair (Hamming < mean-8sd) in the family scope
import json, sqlite3, re, difflib
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
SQL="SELECT body_text, length(body_text) FROM document_cache WHERE volume_id=? AND document_id=?"
print("SQL:", SQL)
b=json.load(open("vec_baselines.json"))
def toks(t): return re.findall(r"[a-z0-9]+", t.lower())
agree=[]; parent={}
def find(x):
    while parent.get(x,x)!=x: x=parent[x]
    return x
for h,a,c in b["nd_family"]:
    ta=con.execute(SQL,tuple(a.split("/"))).fetchone(); tc=con.execute(SQL,tuple(c.split("/"))).fetchone()
    A,C=toks(ta[0]),toks(tc[0]); sa,sc=set(A),set(C); jac=len(sa&sc)/max(1,len(sa|sc))
    r=difflib.SequenceMatcher(None,A[:3000],C[:3000],autojunk=False).ratio()
    same = r>=0.8
    print("%3d %-28s %-28s len %6d %6d  jaccard %.2f  seqratio %.2f  %s" % (h,a,c,ta[1],tc[1],jac,r,"AGREE" if same else "DIFFER"))
    if same:
        agree.append((a,c)); parent[find(c)]=find(a)
docs={x for p in agree for x in p}; groups={}
for x in docs: groups.setdefault(find(x),set()).add(x)
extra=sum(len(g)-1 for g in groups.values())
print("pairs agreeing: %d of %d; documents in agreeing groups %d in %d groups; copies to drop %d" % (len(agree), len(b["nd_family"]), len(docs), len(groups), extra))
for g in groups.values(): print("  group:", sorted(g))
