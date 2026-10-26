# Literal counts of condition families over the 1105 core documents (core.tsv).
# Text = header+dateline+source_note+body_text concatenated, whitespace collapsed. Python re, IGNORECASE throughout.
# SQL: SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?
import csv, sqlite3, re, json, collections
con = sqlite3.connect("file:/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db?mode=ro", uri=True)
S = r'[\s\-,().]+'
F = {
 'international obligations': (r'international obligations', r'international'+S+r'obligations?'),
 'constitutional government': (r'constitutional government', r'constitutional(?:ly)?'+S+r'govern(?:ment|ments)'),
 'free elections': (r'free elections', r'free'+S+r'elections?'),
 'effective control': (r'effective control', r'effective(?:ly)?'+S+r'control(?:s|led|ling)?'),
 'lives and property': (r'lives and property', r'li(?:fe|ves)'+S+r'and'+S+r'propert(?:y|ies)'),
 'other American republics': (r'other American republics', r'other'+S+r'American'+S+r'republics?'),
 'treaty of peace and amity': (r'treaty of peace and amity', r'treat(?:y|ies)'+S+r'of'+S+r'peace'+S+r'and'+S+r'amity'),
 'Axis': (r'\bAxis\b', r'\bAxis\b|pro-Axis'),
 'communist': (r'\bcommunist\b', r'\bcommunis(?:m|t|ts)\b'),
 'de facto': (r'de facto', r'de'+r'[\s\-]+'+r'facto'),
 'Article 27': (r'Article 27\b', r'article'+S+r'(?:27|XXVII)\b'),
 'human rights': (r'human rights', r'human'+S+r'rights?'),
}
def era(d):
    y = int(d[:4])
    return 'E1 to 1912' if y <= 1912 else 'E2 1913-1932' if y <= 1932 else 'E3 1933-1947' if y <= 1947 else 'E4 1948-1988'
rows = [r for r in csv.reader(open('/Users/jbotts/frus-analysis/c3/runs/r4/core.tsv'), delimiter='\t')]
eras = collections.Counter(era(r[4]) for r in rows)
res = {k: {'strict': collections.Counter(), 'tolerant': collections.Counter(), 'tol_ids': []} for k in F}
for r in rows:
    h, dl, sn, b = con.execute("SELECT header, dateline, source_note, body_text FROM document_cache WHERE volume_id=? AND document_id=?", (r[0], r[1])).fetchone()
    t = re.sub(r'\s+', ' ', ' '.join(x or '' for x in (h, dl, sn, b)))
    e = era(r[4])
    for k, (st, tol) in F.items():
        if re.search(st, t, re.I): res[k]['strict'][e] += 1; res[k]['strict']['ALL'] += 1
        if re.search(tol, t, re.I): res[k]['tolerant'][e] += 1; res[k]['tolerant']['ALL'] += 1; res[k]['tol_ids'].append(r[0]+'/'+r[1])
E = sorted(eras)
print('denominators (core docs per era):', dict(eras), 'ALL', len(rows))
print('family | TOLERANT ALL (STRICT ALL) of', len(rows), '| ' + ' | '.join(E) + ' (tolerant/strict of era denominator)')
for k in F:
    print(k, '|', '%d (%d)' % (res[k]['tolerant']['ALL'], res[k]['strict']['ALL']), '|', ' | '.join('%d/%d of %d' % (res[k]['tolerant'][e], res[k]['strict'][e], eras[e]) for e in E))
json.dump({k: res[k]['tol_ids'] for k in F}, open('/Users/jbotts/frus-analysis/c3/runs/r4/refuter/families_ids_rerun.json', 'w'))
