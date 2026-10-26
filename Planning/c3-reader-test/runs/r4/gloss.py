# Gloss decimal keys from channels.py output with decimal-class-labels.json, gated on the DOCUMENT dates (min/max year of docs carrying the key).
# Reads channels_out.txt-derived lists via channels.json + core.tsv/document_sources per doc for year bounds.
import json, sqlite3, csv, collections, re
D = "/Applications/FRUS Explorer.app/Contents/Resources/decimal-class-labels.json"
j = json.load(open(D)); sch = {s['id']: s for s in j['schedules']}
spans = j['coverage']['glossableYears']
def schedule_for(y):
    for g in spans:
        if g['startYear'] <= y <= g['endYear']: return sch[g['scheduleId']]
def gloss(key, y):
    s = schedule_for(y)
    if not s: return 'NO GLOSS (outside glossableYears)'
    m = re.match(r'^(\d)(\d\d[a-z]?)(?:\.(\w+))?$', key)
    if not m: return 'unparsed'
    c, rest, sub = m.groups()
    cls = s['classes'].get(c, '?')
    if c in s['relationsClasses']:
        a = rest[:2]; b = sub[:2] if sub else ''
        return '%s [%s]: %s - %s%s' % (s['id'], cls, s['countries'].get(a, a), s['countries'].get(b, b) if b else '', (' / sub ' + sub[2:]) if sub and len(sub) > 2 else '')
    ctry = s['countries'].get(rest, rest)
    subj = s.get('subjects', {}).get(c, {}).get(sub, None) if sub else None
    return '%s [%s] %s: %s' % (s['id'], cls, ctry, subj or ('subject %s not in shipped subject list' % sub))
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
rows = [r for r in csv.reader(open('/Users/jbotts/frus-analysis/c3/runs/r4/core.tsv'), delimiter='\t')]
years = collections.defaultdict(list)
for r in rows:
    s = con.execute("SELECT decimal_class FROM document_sources WHERE volume_id=? AND document_id=?", (r[0], r[1])).fetchone()
    if s and s[0]: years[s[0]].append(int(r[4][:4]))
ch = json.load(open('/Users/jbotts/frus-analysis/c3/runs/r4/channels.json'))
print('CAME-FROM decimal classes (docs, year span, gloss under the schedule governing BOTH ends)')
for k, n in ch['came_dc'][:20]:
    y0, y1 = min(years[k]), max(years[k]); g0, g1 = gloss(k, y0), gloss(k, y1)
    print(' %s | %d docs | %d-%d | %s' % (k, n, y0, y1, g0 if g0 == g1 else 'SPANS SCHEDULES: ' + g0 + ' || ' + g1))
