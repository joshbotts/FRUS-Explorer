# EDI: A11, "Chronology, by administration": a heading where the presidency changes.
# The Chronology block sorts by the stored start day, `date_iso`, which pads a year-only date to
# January 1 and a month-only date to the 1st (IndexingPipeline.normalizeToFullDate), and prints the
# date at its precision (CollectionGeneratedBlocks.chronologyRows). The administrations' terms are
# the bundled administration-profiles-index.json's, where each term's end day is the next term's
# start day.
# For every document of a manifest volume this takes the date the index would (the dateline's
# <date when>, else @from, else @notBefore, else any <date when>; else frus:doc-dateTime-min as a
# day), its precision by the attribute's component count, and asks:
#   - day precision ON a transition day (both terms name that day);
#   - month precision in a month a term begins in, the term beginning after the 1st;
#   - year precision in a year a term begins in (padded to Jan 1, so it sorts under the outgoing
#     president whatever part of the year it means);
#   - a range (min day != max day) that a transition falls inside.
# Stdlib only. Usage: python3 -I a11_transitions.py <volumes-dir> <manifest.json> <admins.json>
import sys, os, json, re, collections
import xml.etree.ElementTree as ET
TEI = '{http://www.tei-c.org/ns/1.0}'
XMLID = '{http://www.w3.org/XML/1998/namespace}id'
vdir, manifest, admins = sys.argv[1], sys.argv[2], sys.argv[3]
vols = [v['volumeId'] for v in json.load(open(manifest))]
terms = [(a['id'], a['start'], a.get('end')) for a in json.load(open(admins))['administrations']]
starts = sorted(set(t[1] for t in terms))           # transition days
start_years = collections.defaultdict(list)
start_months = collections.defaultdict(list)
for s in starts:
    start_years[s[:4]].append(s)
    if s[8:10] != '01':
        start_months[s[:7]].append(s)

def admin_of(day):
    # the rule a heading "where the presidency changes" most simply follows: a day belongs to the
    # term whose start is the latest start not after it
    cur = None
    for tid, s, e in terms:
        if s <= day:
            cur = tid
    return cur

def date_nodes(div):
    out = []
    def walk(el, in_dl):
        dl = in_dl or el.tag == TEI + 'dateline'
        if el.tag == TEI + 'date':
            out.append((dl, el.get('when'), el.get('from'), el.get('notBefore'), el.get('to'), el.get('notAfter')))
        for ch in el:
            if ch.tag == TEI + 'div' and ch.get('type') == 'document':
                continue
            walk(ch, dl)
    walk(div, False)
    return out

def precision(raw):
    d = raw[:10] if 'T' in raw else raw
    n = len(d.split('-'))
    return 'year' if n == 1 else ('month' if n == 2 else 'day')

c = collections.Counter()
ex = collections.defaultdict(list)
for vid in vols:
    p = os.path.join(vdir, vid + '.xml')
    if not os.path.exists(p):
        continue
    root = ET.parse(p).getroot()
    for div in root.iter(TEI + 'div'):
        if div.get('type') != 'document':
            continue
        dmin = dmax = None
        for k, v in div.attrib.items():
            if k.endswith('doc-dateTime-min'): dmin = v
            if k.endswith('doc-dateTime-max'): dmax = v
        nodes = date_nodes(div)
        raw = None
        for dl, when, frm, nb, to, na in nodes:
            if dl and when: raw = when; break
        if raw is None:
            for dl, when, frm, nb, to, na in nodes:
                if dl and frm: raw = frm; break
        if raw is None:
            for dl, when, frm, nb, to, na in nodes:
                if dl and nb: raw = nb; break
        if raw is None:
            for dl, when, frm, nb, to, na in nodes:
                if when: raw = when; break
        if raw is None and dmin:
            raw = dmin
        if not raw or not raw[:4].isdigit():
            c['undated'] += 1
            continue
        c['dated'] += 1
        prec = precision(raw)
        c['precision ' + prec] += 1
        if prec != 'day' and dmax and dmin and dmin[:10] != dmax[:10]:
            c['  coarse precision with a min/max span (prints start - end at that precision)'] += 1
        day = raw[:10] if len(raw) >= 10 else (raw + '-01-01' if len(raw) == 4 else raw + '-01')
        y, ym = raw[:4], raw[:7]
        if prec == 'day' and day in starts:
            c['day precision, on a transition day'] += 1
            c['  on ' + day] += 1
            if len(ex['day']) < 10: ex['day'].append((vid, div.get(XMLID), day))
        if prec == 'month' and ym in start_months:
            c['month precision, in a month a term begins after the 1st'] += 1
            if len(ex['month']) < 10: ex['month'].append((vid, div.get(XMLID), raw))
        if prec == 'year' and y in start_years:
            c['year precision, in a year a term begins'] += 1
            if len(ex['year']) < 10: ex['year'].append((vid, div.get(XMLID), raw, admin_of(y + '-01-01')))
        if dmin and dmax and dmin[:10] != dmax[:10]:
            lo, hi = dmin[:10], dmax[:10]
            if any(lo < s <= hi for s in starts):
                c['range a transition falls inside'] += 1
                if len(ex['range']) < 10: ex['range'].append((vid, div.get(XMLID), lo, hi))
print(dict(c))
for k, v in ex.items():
    print(k, v[:10])
