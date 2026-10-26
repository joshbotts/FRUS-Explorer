# Builds the scope. Writes scope.tsv: volume_id, document_id, set, chapter, date_iso, mentions_recogn, header
# SQL used: SELECT volume_id, structure_json FROM volume_structures;
#   SELECT volume_id, document_id, header, dateline, source_note, body_text, is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=?
#   SELECT date_iso FROM document_dates WHERE volume_id=? AND document_id=?
import sqlite3, json, re, csv
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
LA = re.compile(r"Mexic|Guatemal|Hondur|Salvador|Nicarag|Costa Rica|Panam|Cuba|Dominican|Santo Domingo|Haiti|Venezuel|Colombi|Ecuador|Peru|Bolivi|Chile|Argentin|Brazil|Paraguay|Urugu|Central Americ|American Republics", re.I)
GOV = re.compile(r"recogni\w*.*(government|regime|president|junta|de facto|provisional|Tinoco|Mart[ií]nez|Obreg|Legu|Busch|Paiva|Enriquez|Ramirez|Farrell|Leconte|Auguste|Plaza|Saavedra|Orellana|Henr[ií]quez|union)|(government|regime|Tinoco|Mart[ií]nez|Farrell).*recogni|nonrecognition|non-recognition", re.I)
EXCL = re.compile(r'blockade|Monroe Doctrine|divest his government', re.I)
EXTRA_TITLES = [
 ('frus1946v11', r'violence accompanying the Bolivian revolution and the problem of recognition'),  # (volume, title regex) chapters added by hand: general policy + treaties + Huerta
 ('frus1936v05', r'article II of the General Treaty'),
 ('frus1948v09', r'Bogota Resolution'),
 ('frus1907p2', r'Central American peace protocol'),
 ('frus1922v01', r'Conference on Central American Affairs'),
 ('frus1923v01', r'Agreements between the United States and Central American Republics'),
 ('frus1913', r'^Political affairs: assassination of President Madero'),
]
EXTRA_DOCS = [('frus1913','d7')]
def ids_of(s):
    ids = list(s.get('documentIds') or [])
    for ss in s.get('subsections') or []: ids += ids_of(ss)
    return ids
chap = {}  # (vol,doc) -> chapter title
chap2 = {}  # revolution/coup chapters whose heading does not name recognition
REV = re.compile(r'revolution|coup|overthrow|insurrection|junta|provisional|seizure of power|upheaval|political affairs|political situation|internal affairs|political conditions|uprising|revolt', re.I)
def walk(vol, secs, path):
    for s in secs:
        t = (s.get('title') or '').strip(); p = path + [t]
        full = ' > '.join(p)
        hit = False
        if vol < 'frus1951' and GOV.search(t) and LA.search(full) and not EXCL.search(t) and vol != 'frus1917Supp01v01': hit = True
        for v, rx in EXTRA_TITLES:
            if v == vol and re.search(rx, t): hit = True
        if hit:
            for d in ids_of(s): chap.setdefault((vol, d), full[-160:])
        elif vol < 'frus1951' and REV.search(t) and LA.search(full):
            for d in ids_of(s): chap2.setdefault((vol, d), full[-160:])
        walk(vol, s.get('subsections') or [], p)
for vol, js in con.execute("SELECT volume_id, structure_json FROM volume_structures"):
    walk(vol, json.loads(js).get('sections', []), [])
for k in EXTRA_DOCS: chap.setdefault(k, 'Circular: President Wilson statement of March 11, 1913')
POST = ['frus1949v02','frus1950v02','frus1951v02','frus1952-54Guat','frus1952-54v04','frus1955-57v06','frus1955-57v07','frus1958-60v05','frus1958-60v05mSupp','frus1958-60v06','frus1961-63v10','frus1961-63v10-12mSupp','frus1961-63v12','frus1964-68v31','frus1964-68v32','frus1969-76v21','frus1969-76v22','frus1969-76ve10','frus1969-76ve11p1','frus1969-76ve11p2','frus1969-76ve16','frus1977-80v15','frus1977-80v23','frus1977-80v24','frus1977-80v29','frus1981-88v16']
REC = re.compile(r'recogni', re.I)
NEAR = re.compile(r'recogni[sz]\w*(?:(?!recogni).){0,150}?(?:junta|coup|de facto|new government|provisional government|military government|regime|golpe)|(?:junta|coup|de facto|new government|provisional government|military government|regime|golpe).{0,150}?recogni[sz]', re.I|re.S)
POSTRX = re.compile(r'recogni[sz]\w*', re.I)
CTX = re.compile(r'junta|coup|de facto|military government|new government|provisional government|regime|golpe', re.I)
rows = []
vols = sorted(set(v for v, d in chap) | set(v for v, d in chap2) | set(POST))
for vol in vols:
    for vid, did, h, dl, sn, b, fm, en in con.execute("SELECT volume_id, document_id, header, dateline, source_note, body_text, is_front_matter, is_editorial_note FROM document_cache WHERE volume_id=?", (vol,)):
        if fm or en: continue
        txt = ' '.join(x or '' for x in (h, dl, sn, b))
        key = (vid, did)
        st = None
        if key in chap: st = 'heading'
        elif key in chap2 and NEAR.search(txt): st = 'revchapter'
        elif vid in POST and NEAR.search(txt): st = 'postwar'
        if not st: continue
        dt = con.execute("SELECT date_iso FROM document_dates WHERE volume_id=? AND document_id=?", key).fetchone()
        rows.append([vid, did, st, chap.get(key, chap2.get(key, '')), (dt[0] if dt and dt[0] else ''), 1 if REC.search(txt) else 0, re.sub(r'\s+', ' ', h)[:150]])
with open('/Users/jbotts/frus-analysis/c3/runs/r4/refuter/scope_rerun.tsv', 'w') as f:
    w = csv.writer(f, delimiter='\t'); w.writerow(['volume_id','document_id','set','chapter','date_iso','mentions_recogni','header']); w.writerows(rows)
from collections import Counter
print('rows', len(rows), Counter(r[2] for r in rows), 'heading mentions', sum(r[5] for r in rows if r[2]=='heading'))
print('volumes', len(set(r[0] for r in rows)))
for (v, c), n in sorted(Counter((r[0], r[3]) for r in rows if r[2]=='heading').items()): print(v, n, c[-110:])
