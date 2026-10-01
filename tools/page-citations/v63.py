#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""#1509, #1510, #1511 (index v63): what the v63 parser and page rule change, against v62.

  REP62  replica.py's output with RULE=v62 — the emission every earlier figure was measured over
  REP63  replica.py's output (v63): heading-only containers left out, prose containers narrowed to
         their own text, the breaks either leaves given to the section that begins after them (#1510)
  SCAN   scan_corpus.py's output: the references, their notes, and each document's @n and date

Pages are read under simulate.py's rule F (v62) over REP62 and G (v63: a digit break with a `pg-seq`
id is another pagination, #1511) over REP63. A reference's stored target is, under v62, the first
document its page names; under v63, `PageSpanResolver.citedDocument(among:facts:citing:)` (#1509),
mirrored below: a document number the note gives a document ("Doc. No. 497") that exactly one of
them carries, else the first whose day the note names ("July 7", "Oct. 9, 1909" — a printed year must
agree), else the first. A document's day is the one `document_dates.date_iso` stores (#1326: the
dateline's own day where it names the same instant as `frus:doc-dateTime-min`), counted only at day
precision; its number is its @n. A section has neither.

Prints, in order: the emission (#1510), the printed volumes' pages (#1510, then #1511 alone), and
the references (all three). Every count is over the 533 printed volumes — not the five microfiche
supplements and not the fifteen that number their pages per document — except the emission's,
which is over all 553.

Usage: v63.py REP62 REP63 SCAN
"""
import collections, datetime, json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import simulate as ns


# --- PageCitationHint / CitedDocumentFacts / citedDocument (PageSpanResolver.swift) ---------------
DOCNO = re.compile(r'\b(?:Docs?\.|[Dd]ocuments?)\s*(?:[Nn]os?\.\s*)?(\d+[A-Za-z]?)\b')
MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
DAY = re.compile(r'\b(January|February|March|April|May|June|July|August|September|October|November|'
                 r'December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sept|Sep|Oct|Nov|Dec)\.?\s*(\d{1,2})'
                 r'(?:st|nd|rd|th)?(?!\d)(?:,?\s*(\d{4})(?!\d))?')

def hint(text):
    nums = [m.group(1) for m in DOCNO.finditer(text)]
    days = []
    for m in DAY.finditer(text):
        d = int(m.group(2))
        if 1 <= d <= 31:
            days.append((MONTHS.index(m.group(1)[:3]) + 1, d, int(m.group(3)) if m.group(3) else None))
    return (nums, days) if nums or days else None

def instant(raw):
    if not raw or 'T' not in raw: return None
    try:
        t = datetime.datetime.fromisoformat(raw.replace('Z', '+00:00'))
    except ValueError:
        return None
    return t if t.tzinfo else None

def app_day(d):
    """(year, month, day) as document_dates stores it at day precision, else None."""
    dt, win = d.get('date') or None, d.get('date_win')
    if dt:
        same = instant(dt) is not None and instant(win) is not None and instant(dt) == instant(win)
        iso = (win if same else dt)[:10]
        prec = 'day' if not win else ('day' if len((win[:10] if 'T' in win else win).split('-')) >= 3 else 'other')
    elif win:
        iso = win[:10]
        prec = 'day' if len((win[:10] if 'T' in win else win).split('-')) >= 3 else 'other'
    else:
        return None
    if prec != 'day': return None
    p = [int(x) for x in iso.split('-') if x.isdigit()]
    return (p[0], p[1], p[2]) if len(p) == 3 else None

def names(hd, day):
    return hd[0] == day[1] and hd[1] == day[2] and (hd[2] is None or hd[2] == day[0])

def cited(ids, facts, h):
    """(chosen id, which cue decided)"""
    if len(ids) < 2 or h is None: return ids[0], 'first'
    nums, days = h
    numbered = [i for i in ids if facts.get(i, (None, None))[0] and
                any(n.lower() == facts[i][0].lower() for n in nums)]
    if len(numbered) == 1: return numbered[0], 'number'
    for i in ids:
        day = facts.get(i, (None, None))[1]
        if day and any(names(hd, day) for hd in days): return i, 'day'
    return ids[0], 'first'

def tables(v, regime):
    t = ns.rows(v['docs'], regime); pd = ns.per_document(t)[0]
    return t, pd, {d['id']: ns.spans(d, pd) for d in t}

def answers(t, sp, pd, regime):
    pages = set()
    for d in t:
        pages.update(d['breaks'])
        if d['start'] is not None: pages.add(d['start'])
    return {p: ns.lookup(p, t, sp, pd, regime) for p in pages}

def main(R62, R63, S):
    C = collections.Counter(); PV = collections.defaultdict(collections.Counter); EX = collections.defaultdict(list)
    for fn, v62 in ns.replica_volumes(R62):
        v63 = json.load(open(os.path.join(R63, fn)))
        vid = v62['volumeId']
        # --- emission (#1510), every volume --------------------------------------------------------
        a = {d['id']: d for d in v62['docs']}; b = {d['id']: d for d in v63['docs']}
        C['emission: ASTs v62'] += len(a); C['emission: ASTs v63'] += len(b)
        gone = [i for i in a if i not in b]
        for i in gone: C['emission: left out, %s' % a[i]['kind']] += 1
        if gone: C['emission: volumes losing an AST'] += 1; PV['left out'][vid] = len(gone)
        for i, d in b.items():
            if d.get('carried'): C['emission: sections given breaks'] += 1
            own = d['pbs'][d.get('carried', 0):]
            if i in a and own != a[i]['pbs']:
                C['emission: containers narrowed'] += 1
                C['emission: breaks a narrowed container gave up'] += len(a[i]['pbs']) - len(own)
        for k, n in v63.get('carried_to', {}).items(): C['emission: carried breaks to a %s' % k] += n
        if ns.micro(v62): continue
        t62, pd62, sp62 = tables(v62, 'F')
        t63, pd63, sp63 = tables(v63, 'G')
        if pd62 or pd63: continue
        kinds62 = {d['id']: d['kind'] for d in v62['docs']}; kinds63 = {d['id']: d['kind'] for d in v63['docs']}
        # --- pages (#1510 + #1511) -----------------------------------------------------------------
        an62 = answers(t62, sp62, pd62, 'F'); an63 = answers(t63, sp63, pd63, 'G')
        for p in set(an62) | set(an63):
            k62, ids62 = an62.get(p, ('none', [])); k63, ids63 = an63.get(p, ('none', []))
            secs62 = [i for i in ids62 if not kinds62[i] in ('document', 'editorialNote')]
            secs63 = [i for i in ids63 if not kinds63[i] in ('document', 'editorialNote')]
            if len(secs62) > 1: C['pages: several sections at once, v62'] += 1; PV['several sections v62'][vid] += 1
            if len(secs63) > 1: C['pages: several sections at once, v63'] += 1; PV['several sections v63'][vid] += 1
            if secs62: C['pages: a section among the answers, v62'] += 1
            if secs63: C['pages: a section among the answers, v63'] += 1
            if ids62 and not ids63:
                C['pages: answered under v62, nothing under v63'] += 1
                if len(EX['lost']) < 20: EX['lost'].append((vid, p, ids62))
            if ids63 and not ids62: C['pages: answered under v63 only'] += 1
            if ids62 and ids63 and ids62 != ids63: C['pages: answer changes'] += 1
            if ids62 and ids62[0] in gone:
                C['pages: first answer a left-out container under v62'] += 1
                if len(ids62) == 1:
                    C['pages: answered by a left-out container alone under v62'] += 1
                    C['pages: ... now answered (%s)' % ('yes' if ids63 else 'NO')] += 1
                    if len(EX['container alone']) < 40: EX['container alone'].append((vid, p, ids62[0], ids63))
        # --- #1511 alone: the v63 emission under F and under G --------------------------------------
        tF, pdF, spF = tables(v63, 'F')
        if not pdF:
            anF = answers(tF, spF, pdF, 'F')
            for p in set(anF) | set(an63):
                if anF.get(p, ('none', []))[1] != an63.get(p, ('none', []))[1]:
                    C['#1511: pages whose answer the pg-seq rule changes'] += 1; PV['#1511'][vid] += 1
                    if len(anF.get(p, ('none', []))[1]) > 1 and len(an63.get(p, ('none', []))[1]) == 1:
                        C['#1511: ... from several to one'] += 1
                    if not an63.get(p, ('none', []))[1]: C['#1511: ... to no answer'] += 1
        # --- references --------------------------------------------------------------------------
        sc = json.load(open(os.path.join(S, fn)))
        if not sc['refs']: continue
        byid = {d['id']: d for d in sc['docs']}
        facts = {i: (d.get('n') or None, app_day(d)) for i, d in byid.items()}
        for r in sc['refs']:
            if not re.match(r'^\d+$', r['n']) or int(r['n']) <= 0: continue
            p = int(r['n']); C['refs'] += 1
            k62, ids62 = an62.get(p) or ns.lookup(p, t62, sp62, pd62, 'F')
            k63, ids63 = an63.get(p) or ns.lookup(p, t63, sp63, pd63, 'G')
            old = ids62[0] if ids62 else None
            h = hint(r['note']) if r['note'] else None
            new, why = cited(ids63, facts, h) if ids63 else (None, None)
            if old == new: C['refs: stored target unchanged'] += 1
            elif new is None: C['refs: resolved under v62, not v63'] += 1
            elif old is None: C['refs: resolved under v63 only'] += 1
            elif ids62 == ids63 or (ids63 and old == ids63[0]):
                C['refs: moved by the tie-break, by the %s' % why] += 1
                if C['refs: moved by the tie-break, by the %s' % why] % 100 == 1:   # every 100th, to read
                    EX['moved by the %s (every 100th)' % why].append((vid, r['src'], p, ids63, new, r['note'][:200]))
            else:
                C['refs: moved by the page table'] += 1
                if why != 'first': C['refs: ... and the tie-break, by the %s' % why] += 1
            if len(ids63) > 1 and k63 == 'begins':
                C['refs to a page several begin on, v63'] += 1
                C['refs to a page several begin on: chosen by the %s' % why] += 1
                if why != 'first' and new != ids63[0]: C['refs to a page several begin on: a later document chosen'] += 1
                if why == 'number' and len(EX['number']) < 12: EX['number'].append((vid, r['src'], p, ids63, new, r['note'][:160]))
                if h and h[1]:
                    dated = [i for i in ids63 if facts.get(i, (None, None))[1] and any(names(hd, facts[i][1]) for hd in h[1])]
                    C['refs to a page several begin on: note names %s' % (
                        'none of their days' if not dated else 'the chosen document\'s day' if new in dated
                        else 'only another\'s day')] += 1
    for k in sorted(C): print('%8d  %s' % (C[k], k))
    for k in sorted(PV):
        print('== by volume: %s (%d volumes)' % (k, len(PV[k])))
        for vid, n in sorted(PV[k].items(), key=lambda x: (-x[1], x[0]))[:12]: print('   %-22s %d' % (vid, n))
    for k in sorted(EX):
        print('== examples: %s' % k)
        for e in EX[k]: print('   ', e)


if __name__ == '__main__':
    if len(sys.argv) != 4:
        sys.exit('usage: v63.py REP62 REP63 SCAN')
    main(*sys.argv[1:])
