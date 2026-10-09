#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""Where each item of the report to the Office of the Historian stands at another corpus revision.

`build_oh_report.py` re-checks the report at the revision it was written against and stops at the first
row that no longer holds. Once the editors have corrected the corpus that is every run, so this script
asks the other question: of the rows the report filed, which are still as reported, which are corrected
as the report suggested, and which are changed some other way.

    VOLUMES_DIR=<volumes at the new revision> python3 tools/oh-report/status_at_commit.py dump new.json
    VOLUMES_DIR=<volumes at the report's revision> python3 tools/oh-report/status_at_commit.py dump old.json
    python3 tools/oh-report/status_at_commit.py compare old.json new.json

`dump` reads one corpus copy: it states each structure edit's nesting there and runs every scan, keeping
the rows of a class whose own re-check stops (the message is kept with them). The cross-reference class
reads `XREF_CSV`, which must come from a `CrossRefValidationGenerator` run over the same copy. `compare`
matches rows on every column but the line and the byte offset, which move when a tag is moved in a file.
It writes nothing but the file named, posts nothing, and changes neither the report nor its CSVs.
"""

import collections
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import build_oh_report as report  # noqa: E402
from ohlib import Volume  # noqa: E402

POSITIONAL = ('line', 'byte_offset')


def structure_status():
    """One record per structure edit: still as reported, corrected as suggested, or changed otherwise."""
    out = []
    for entry in report.STRUCTURE:
        v = Volume(entry['volume'] + '.xml')
        now = {xml_id: v.parent_id(xml_id) for xml_id in entry['before']}
        retypes = [e['retype'] for e in entry['edits'] if 'retype' in e]
        types = {xml_id: v.div(xml_id)['type'] for xml_id, _, _ in retypes}
        as_reported = now == entry['before'] and all(types[i] == old for i, old, _ in retypes)
        as_suggested = (all(v.parent_id(i) == p for i, p in entry['after'].items())
                        and all(types[i] == new for i, _, new in retypes))
        status = 'as-reported' if as_reported else 'corrected-as-suggested' if as_suggested else 'changed-otherwise'
        differs = {i: {'reported': entry['before'][i], 'suggested': entry['after'].get(i), 'now': now[i]}
                   for i in now if now[i] != entry['after'].get(i)}
        out.append({'volume': entry['volume'], 'elements': [e['element'] for e in entry['edits']],
                    'confidence': sorted({e['confidence'] for e in entry['edits']}), 'status': status,
                    'notAsSuggested': {} if as_suggested else differs,
                    'types': {i: {'reported': old, 'suggested': new, 'now': types[i]} for i, old, new in retypes}})
    return out


def scans():
    """Every other class's rows at this corpus copy, and the message of a re-check that stopped."""
    xref_csv = os.environ.get('XREF_CSV')
    manifest = os.environ.get('MANIFEST', os.path.join(report.REPO, 'FRUSExplorer', 'Resources', 'manifest.json'))
    tables = {k: [] for k in ('gap', 'sources', 'pagination', 'xref', 'dates', 'transcription', 'glued', 'headers')}
    counts, stopped = {}, {}
    runs = [('gap', lambda: report.gap(counts, tables['gap'])),
            ('sources', lambda: report.sources_lists(counts, tables['sources'])),
            ('pagination', lambda: report.pagination(counts, tables['pagination'])),
            ('parts', lambda: report.parts(counts, tables['pagination'])),
            ('dates', lambda: report.dates(counts, tables['dates'])),
            ('transcription', lambda: report.transcription(counts, tables['transcription'], tables['glued'])),
            ('headers', lambda: report.headers(counts, tables['headers']))]
    if xref_csv:
        runs.append(('xref', lambda: report.cross_references(counts, tables['xref'], xref_csv, manifest)))
    for name, run in runs:
        try:
            run()
        except report.Failed as failure:
            stopped[name] = str(failure)
    return tables, stopped


def key(row):
    return json.dumps({k: v for k, v in row.items() if k not in POSITIONAL}, sort_keys=True, ensure_ascii=False)


def compare(old_path, new_path):
    with open(old_path, encoding='utf-8') as handle:
        old = json.load(handle)
    with open(new_path, encoding='utf-8') as handle:
        new = json.load(handle)
    print('Structure edits at the new revision:')
    tally = collections.Counter(item['status'] for item in new['structure'])
    print('  ' + ', '.join('%d %s' % (n, s) for s, n in sorted(tally.items())))
    for item in new['structure']:
        print('  %-24s %-24s %s' % (item['volume'], item['status'], ', '.join(item['elements'])))
        for xml_id, where in sorted(item['notAsSuggested'].items()):
            print('      %s: reported under %s, suggested %s, now %s'
                  % (xml_id, where['reported'], where['suggested'], where['now']))
        for xml_id, kind in sorted(item['types'].items()):
            print('      %s: typed %s, suggested %s, now %s' % (xml_id, kind['reported'], kind['suggested'], kind['now']))
    for side, data in (('report\'s revision', old), ('new revision', new)):
        for name, message in sorted(data['stopped'].items()):
            print('\nRe-check stopped at the %s, class %s: %s' % (side, name, message))
    print('\nScan rows (matched on every column but line and byte offset):')
    for name in sorted(new['tables']):
        before = collections.Counter(key(r) for r in old['tables'].get(name, []))
        after = collections.Counter(key(r) for r in new['tables'][name])
        gone, came = before - after, after - before
        print('  %-14s %5d before, %5d now, %4d gone, %4d new'
              % (name, sum(before.values()), sum(after.values()), sum(gone.values()), sum(came.values())))
        for label, rows in (('gone', gone), ('new', came)):
            for text in sorted(rows)[:int(os.environ.get('SHOW', '12'))]:
                print('      %s: %s' % (label, text[:300]))


def main(argv):
    if len(argv) == 3 and argv[1] == 'dump':
        tables, stopped = scans()
        with open(argv[2], 'w', encoding='utf-8') as handle:
            json.dump({'volumesDir': report.ohlib.VOLUMES_DIR, 'structure': structure_status(), 'tables': tables,
                       'stopped': stopped}, handle, indent=1, sort_keys=True, ensure_ascii=False)
        print('wrote %s' % argv[2])
    elif len(argv) == 4 and argv[1] == 'compare':
        compare(argv[2], argv[3])
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    main(sys.argv)
