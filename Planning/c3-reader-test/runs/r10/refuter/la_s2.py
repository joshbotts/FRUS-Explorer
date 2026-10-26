# Independent re-derivation of the LA universe (memo §1 rule), R2∩LA, S2, its volumes, dates, overlap.
import json, re, sqlite3, collections
DB="/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db"
RES="/Applications/FRUS Explorer.app/Contents/Resources/"
con=sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
LA=re.compile(r"Argentin|Bolivi|Brazil|Chile|Colombia|Costa Rica|Cuba|Dominican|Santo Domingo|Ecuador|Salvador|Guatemala|Haiti|Honduras|Mexic|Nicaragua|Panam|Paraguay|Peru\b|Peruvian|Uruguay|Venezuela|Central America|American Republics|Latin America|Western Hemisphere|Inter-American|South America|Soccer War", re.I)
MIXED=re.compile(r"United Nations|Appendix I\b", re.I)
man=json.load(open(RES+"manifest.json"))
print('manifest type', type(man).__name__, 'len', len(man), 'keys of first:', list(man[0].keys()) if isinstance(man,list) else list(man.keys())[:10])
def ttl(v): return re.sub(r"\s+"," ", v.get("title") or "")
la_vol={v["volumeId"] for v in man if LA.search(ttl(v)) and not MIXED.search(ttl(v))}
print('LA volumes by title (mixed excluded):', len(la_vol))
paths={}
for vid,sj in con.execute("SELECT volume_id, structure_json FROM volume_structures"):
    st=json.loads(sj)
    def walk(secs,path):
        for s in secs:
            t=re.sub(r"\s+"," ",(s.get("title") or "")).strip(); p=path+[t]
            for d in s.get("documentIds") or []: paths[(vid,d)]=" > ".join(p)
            walk(s.get("subsections") or [],p)
    walk(st.get("sections") or [],[])
def isdoc(d): return re.match(r'^d[0-9]',d) is not None or re.match(r'^[a-z]+_d[0-9]',d) is not None
DROP={"frus1951-54IranEd2","frus1969-76ve15p2Ed2"}
dates={(v,d):di for v,d,di in con.execute("SELECT volume_id, document_id, date_iso FROM document_dates")}
def la(v,d): return bool(LA.search(paths.get((v,d),"")) or v in la_vol)
r2=set(tuple(l.split('\t')) for l in open('r2_raw.tsv').read().split('\n') if l)
r2la=sorted(p for p in r2 if la(*p))
print('R2 ∩ LA:', len(r2la), 'volumes:', len({v for v,_ in r2la}))
sess=set(tuple(l.rstrip('\n').split('\t')[:2]) for l in open('/Users/jbotts/frus-analysis/c3/runs/r10/out/hits_R2.tsv'))
print('identical to session hits_R2.tsv?', set(r2la)==sess, 'diff:', set(r2la)^sess)
a1=set(tuple(l.split('\t')) for l in open('a1_mine.tsv').read().split('\n') if l)
s2=sorted(a1|set(r2la))
print('A1:', len(a1), 'overlap A1∩R2LA:', len(a1&set(r2la)), 'S2:', len(s2), 'S2 volumes:', len({v for v,_ in s2}))
ds=sorted(dates[p] for p in s2 if dates.get(p))
print('S2 date span:', ds[0], ds[-1], 'undated:', len(s2)-len(ds))
sess_s2=set(tuple(l.rstrip('\n').split('\t')[:2]) for l in open('/Users/jbotts/frus-analysis/c3/runs/r10/out/scope_S2.tsv'))
print('identical to session scope_S2.tsv?', set(s2)==sess_s2)
dec=collections.Counter((dates[p][:3]+'0s') for p in s2)
print('S2 by decade:', dict(sorted(dec.items())), 'after 1949:', sum(n for k,n in dec.items() if k>='1950s'))
open('s2_mine.tsv','w').write('\n'.join(f"{v}\t{d}" for v,d in s2)+'\n')
vols=sorted({v for v,_ in s2}); open('s2_volumes.txt','w').write('\n'.join(vols)+'\n')
print('S2 volumes:', ' '.join(vols))
# LA universe dated printed documents (denominator)
n=0
for v,d,fm,ed in con.execute("SELECT volume_id, document_id, is_front_matter, is_editorial_note FROM document_cache"):
    if fm==0 and ed==0 and isdoc(d) and v not in DROP and la(v,d) and dates.get((v,d)): n+=1
print('LA universe dated printed documents:', n)
