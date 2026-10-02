#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""Self-test for tools/oh-report: the readers, the simulated repair, and each scan rule, driven over
small synthetic volumes written to a temporary directory. No corpus needed.

    python3 tools/oh-report/selftest.py

Every rule of the pagination and date scans has one fixture that it alone should catch and the test
names the row it expects, so a rule that stops firing, or starts firing on a neighbour's fixture,
fails by name. Prints the number of checks and exits 1 on the first failure.
"""
import os
import sys
import tempfile
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ohlib  # noqa: E402
import build_oh_report as report  # noqa: E402

CHECKS = 0


def check(condition, message):
    global CHECKS
    CHECKS += 1
    if not condition:
        sys.exit('FAILED (check %d): %s' % (CHECKS, message))


def raises(kind, action, message):
    try:
        action()
    except kind:
        check(True, message)
        return
    check(False, message + ' (nothing was raised)')


HEADER = '<TEI xmlns:frus="http://history.state.gov/frus/ns/1.0"><text><body>\n'
FOOTER = '</body></text></TEI>\n'

# A chapter whose closing tag is written after the chapter that follows it: ch2 sits inside ch1.
DISPLACED = HEADER + '''<div type="compilation" xml:id="comp1">
<head>Compilation</head>
<!-- a comment that mentions <div type="chapter" xml:id="ghost"> and </div> -->
<div type="chapter" subtype="x" xml:id="ch1">
<head>One</head>
<div type="document" xml:id="d1" n="1"><p>text</p></div>
<div type="chapter" xml:id="ch2">
<head>Two</head>
<div type="subchapter" xml:id="ch2subch1">
<head>Early</head>
</div>
<div type="subchapter" xml:id="ch2subch2">
<head>Late</head>
</div>
</div>
</div>
</div>
''' + FOOTER


def test_readers_and_repair():
    v = ohlib.Volume('frusTEST.xml', DISPLACED.encode())
    check(len(v.divs) == 6, 'six divs, the one in the comment not among them: %d' % len(v.divs))
    check(v.div('ghost') is None, 'a div named only in a comment is not read')
    check(v.parent_id('ch2') == 'ch1' and v.parent_id('ch1') == 'comp1' and v.parent_id('comp1') == '',
          'the parents as the file asserts them')
    check(v.div('ch2')['line'] == 8 and v.div('ch1')['close'] == 17, 'line numbers are 1-based and those of the file')
    check(v.div('ch1')['head'] == 'One', 'the head is read')
    lines = DISPLACED.split('\n')
    check(lines[16].strip() == '</div>' and lines[7].startswith('<div type="chapter" xml:id="ch2"'), 'the fixture is as numbered')
    # One move: the tag on line 17 (closing ch1) belongs before line 8 (ch2).
    fixed = ohlib.move_close_tags(v, [(17, 8)])
    check(fixed.parent_id('ch2') == 'comp1' and fixed.parent_id('ch2subch1') == 'ch2', 'ch2 is beside ch1 after the move')
    check(len(fixed.divs) == len(v.divs), 'the move changes no div count')
    check(v.parent_id('ch2') == 'ch1', 'the original is untouched')
    # Two moves in one call, both numbered against the ORIGINAL file: line 17 to 8, and line 12 (closing
    # ch2subch1) to 16, which nests ch2subch2 inside ch2subch1.
    twice = ohlib.move_close_tags(v, [(17, 8), (12, 16)])
    check(twice.parent_id('ch2') == 'comp1' and twice.parent_id('ch2subch2') == 'ch2subch1',
          'two moves are both read against the original numbering')
    one_at_a_time = ohlib.move_close_tags(ohlib.move_close_tags(v, [(17, 8)]), [(13, 17)])
    check(one_at_a_time.raw == twice.raw, 'and equal the same two edits applied one after the other, renumbered')
    raises(ValueError, lambda: ohlib.move_close_tags(v, [(8, 3)]), 'a from-line that is not a lone </div> is refused')
    raises(ValueError, lambda: ohlib.move_close_tags(v, [(17, 8), (17, 9)]), 'one tag cannot be moved twice')
    raises(ET.ParseError, lambda: ohlib.move_close_tags(v, [(17, 2)]), 'a move that breaks well-formedness is refused')
    retyped = ohlib.retype_div(v, 'ch1', 'compilation')
    check(retyped.div('ch1')['type'] == 'compilation' and retyped.div('ch1')['subtype'] == 'x',
          'retype changes type and leaves subtype alone')
    check(v.enclosing_div(DISPLACED.encode().find(b'<p>text'), 'document')['id'] == 'd1', 'the enclosing document is found')
    check(v.children('ch2') and [n['id'] for n in v.children('ch2')] == ['ch2subch1', 'ch2subch2'], 'children in order')
    check([n['id'] for n in v.children('ch1')] == ['ch2'] and len(v.children('ch1', documents=True)) == 2,
          'documents are left out of children unless asked for')


def pb(n, xml_id, facs):
    return '<pb facs="%s" n="%s" xml:id="%s"/>' % (facs, n, xml_id)


def doc(xml_id, body, subtype='historical-document', extra=''):
    return '<div type="document" subtype="%s" xml:id="%s" n="%s"%s>%s</div>\n' % (subtype, xml_id, xml_id[1:], extra, body)


def write(directory, name, body, front=''):
    with open(os.path.join(directory, name), 'w', encoding='utf-8') as handle:
        handle.write('<TEI xmlns:frus="http://history.state.gov/frus/ns/1.0"><teiHeader/><facsimile>%s</facsimile>'
                     '<text><body>\n%s</body></text></TEI>\n' % (front, body))


def rows_of(rows, kind):
    return [r for r in rows if r['class'] == kind]


def test_pagination(directory):
    # One fixture per rule. Each row expected is named by its page id.
    clean = ''.join(doc('d%d' % k, pb(k, 'pg_%d' % k, '%04d' % (k + 10)) + '<p>x</p>') for k in range(1, 6))
    write(directory, 'frus1900.xml', clean)
    # reversed pair: d2 (page 12, image 0022) is written before d3 (page 11, image 0021)
    write(directory, 'frus1901.xml',
          doc('d1', pb(10, 'pg_10', '0020')) + doc('d2', pb(12, 'pg_12', '0022'), 'editorial-note')
          + doc('d3', pb(11, 'pg_11', '0021'), 'editorial-note') + doc('d4', pb(13, 'pg_13', '0023')))
    # numbers out of order while the images run forward
    write(directory, 'frus1902.xml',
          doc('d1', pb(30, 'pg_30', '0040') + pb(32, 'pg_32', '0041') + pb(31, 'pg_31', '0042') + pb(33, 'pg_33', '0043')))
    # id disagrees with n
    write(directory, 'frus1903.xml', doc('d1', pb(50, 'pg_50', '0060') + pb(50, 'pg_51', '0061') + pb(52, 'pg_52', '0062')))
    # a missing break (page 71: image 0081 exists by the arithmetic), and a jump that is NOT one
    # (page 73 to 75 where the images do not jump with it: a plate was skipped in the numbering)
    write(directory, 'frus1904.xml',
          doc('d1', pb(70, 'pg_70', '0080') + pb(72, 'pg_72', '0082') + pb(73, 'pg_73', '0083') + pb(75, 'pg_75', '0084')))
    # malformed ids, one of each kind, each with its surface; and a legitimate unnumbered pg-seq page
    write(directory, 'frus1905.xml',
          doc('d1', pb(1, 'pg_1', '0001') + pb(2, 'pgg_2', '0002') + pb(3, 'pg_3', '0003') + pb(4, 'pg-seq-14', '0004')
              + pb(5, 'pg_5', '0005') + pb('[6]', 'pg-seq-16', '0006') + pb(7, 'pg_7', '0007')
              + pb('VII', 'pg_VII', '0101') + pb('VIII', 'VIII', '0102') + pb('VIIII', 'VIIII', '0103')),
          front='<surface start="#pgg_2"/>\n<surface start="#VIII"/>')
    # wrong facs: a duplicate fixed by its neighbours, and a short image name
    write(directory, 'frus1906.xml',
          doc('d1', pb(1, 'pg_1', '0011') + pb(2, 'pg_2', '0011') + pb(3, 'pg_3', '0013') + pb(4, 'pg_4', '014')
              + pb(5, 'pg_5', '0015')))
    # zero-padded ids
    write(directory, 'frus1907.xml', doc('d1', pb(1, 'pg_001', '0001') + pb(2, 'pg_002', '0002') + pb(3, 'pg_3', '0003')))
    # the other branch of each rule: two pages without a break (a question), a hyphen for the underscore,
    # a duplicate image only the break's own id can fix, and one nothing in the file can fix (a question)
    write(directory, 'frus1908.xml',
          doc('d1', pb(90, 'pg_90', '0100') + pb(93, 'pg_93', '0103') + pb(94, 'pg-94', '0104') + pb(95, 'pg_95', '0105'))
          + doc('d2', pb(3, 'pg_d2-3', 'd2-4') + pb(4, 'pg_d2-4', 'd2-4'))
          + doc('d3', pb('XXX', 'pg_XXX', '0031') + pb('XXXI', 'pg_XXXI', '0031') + pb(1, 'pg_1', '0032')))

    ohlib.VOLUMES_DIR = directory
    report._VOLUMES.clear()
    counts, rows = {}, []
    report.pagination(counts, rows)
    check(not [r for r in rows if r['volume'] == 'frus1900'], 'a clean volume gives no row')
    everything, rows = rows, [r for r in rows if r['volume'] != 'frus1908']  # frus1908 is read at the end

    pair = rows_of(rows, 'reversed-pair')
    check(len(pair) == 1 and pair[0]['volume'] == 'frus1901' and pair[0]['pb_xml_id'] == 'pg_11'
          and pair[0]['document'] == 'd3' and 'd2, which holds the later page' in pair[0]['what_is_wrong'],
          'the reversed pair is reported once, at the break that runs backwards: %s' % pair)
    check(counts['pagination']['reversedPairsBothEditorialNotes'] == 1
          and counts['pagination']['reversedPairsSecondIsEditorialNote'] == 1, 'both divisions are counted as editorial notes')

    order = rows_of(rows, 'numbers-out-of-order')
    check(len(order) == 1 and order[0]['volume'] == 'frus1902' and order[0]['pb_xml_id'] == 'pg_31',
          'numbers out of order: %s' % order)
    check(not [r for r in pair if r['volume'] == 'frus1902'] and not [r for r in order if r['volume'] == 'frus1901'],
          'the two backward shapes are told apart by the image numbers')

    mismatch = rows_of(rows, 'id-disagrees-with-n')
    check(len(mismatch) == 1 and mismatch[0]['pb_xml_id'] == 'pg_51' and 'n="51"' in mismatch[0]['correction'],
          'id against n: %s' % mismatch)

    missing = rows_of(rows, 'missing-break')
    check(len(missing) == 1 and missing[0]['volume'] == 'frus1904' and 'page 71' in missing[0]['what_is_wrong']
          and '<pb facs="0081" n="71" xml:id="pg_71"/>' in missing[0]['correction'] and missing[0]['confidence'] == 'confirmed',
          'one missing break, with the tag to insert: %s' % missing)
    check(counts['pagination']['missingPages'] == 3, 'pages 73-75 with images 0083-0084 are not a missing break: '
          'one page here and two in frus1908')

    malformed = {r['pb_xml_id']: r for r in rows_of(rows, 'malformed-id')}
    check(sorted(malformed) == ['VIII', 'VIIII', 'pg-seq-14', 'pgg_2'], 'four malformed ids: %s' % sorted(malformed))
    check('xml:id="pg_2"' in malformed['pgg_2']['correction'] and '<surface start="#pgg_2"> at line 1' in malformed['pgg_2']['correction'],
          'the prefix typo names its surface')
    check('xml:id="pg_4"' in malformed['pg-seq-14']['correction'] and 'surface' not in malformed['pg-seq-14']['correction'],
          'a numbered page on a pg-seq id; no surface is claimed where the facsimile has none')
    check('xml:id="pg_VIII"' in malformed['VIII']['correction'], 'a Roman id without its prefix')
    check('not a Roman numeral' in malformed['VIIII']['what_is_wrong'] and 'n="IX" xml:id="pg_IX"' in malformed['VIIII']['correction'],
          'a malformed numeral is given the numeral after the break before it')
    check('pg-seq-16' not in malformed, 'an unnumbered page on a pg-seq id is the corpus\'s own convention')

    facs = rows_of(rows, 'wrong-facs')
    check(len(facs) == 2 and all(r['volume'] == 'frus1906' for r in facs), 'two wrong-facs rows: %s' % facs)
    duplicate = [r for r in facs if 'Two breaks name image 0011' in r['what_is_wrong']]
    check(len(duplicate) == 1 and 'line 2 (n="2"), set facs="0012"' in duplicate[0]['correction']
          and duplicate[0]['confidence'] == 'confirmed', 'the duplicate is fixed on the break its neighbours contradict')
    short = [r for r in facs if '3 digits' in r['what_is_wrong']]
    check(len(short) == 1 and short[0]['pb_xml_id'] == 'pg_4' and 'facs="0014"' in short[0]['correction'], 'the short image name')

    padded = rows_of(rows, 'zero-padded-ids')
    check(len(padded) == 1 and padded[0]['volume'] == 'frus1907' and '2 page ids' in padded[0]['what_is_wrong'],
          'zero-padded ids are one row for the volume: %s' % padded)
    check(len(rows) == 11, 'eleven rows in the first eight volumes, none unaccounted for: %d' % len(rows))
    other = [r for r in everything if r['volume'] == 'frus1908']
    two = [r for r in other if r['class'] == 'missing-break']
    check(len(two) == 1 and two[0]['confidence'] == 'question' and 'pages 91, 92' in two[0]['what_is_wrong']
          and '<pb facs="0101" n="91" xml:id="pg_91"/> and <pb facs="0102" n="92" xml:id="pg_92"/>' in two[0]['correction'],
          'two pages without a break are a question, with both tags: %s' % two)
    hyphen = [r for r in other if r['class'] == 'malformed-id']
    check(len(hyphen) == 1 and hyphen[0]['pb_xml_id'] == 'pg-94' and 'xml:id="pg_94"' in hyphen[0]['correction'],
          'a hyphen for the underscore: %s' % hyphen)
    twins = {r['pb_xml_id']: r for r in other if r['class'] == 'wrong-facs'}
    check(sorted(twins) == ['pg_XXXI', 'pg_d2-4'], 'two duplicate images: %s' % sorted(twins))
    check('line 3 (xml:id="pg_d2-3"), set facs="d2-3"' in twins['pg_d2-4']['correction'] and twins['pg_d2-4']['confidence'] == 'confirmed',
          'a duplicate fixed by the break\'s own id, on the break that has the wrong one: %s' % twins['pg_d2-4']['correction'])
    check(twins['pg_XXXI']['confidence'] == 'question' and 'Check both against the images' in twins['pg_XXXI']['correction'],
          'a duplicate the file cannot settle is a question')
    check(len(other) == 4, 'four rows in frus1908, none unaccounted for: %d' % len(other))


def test_parts(directory):
    # Three volumes in two parts with one pagination: a clean join, a gap, and trailing breaks that
    # carry the next part's numbers; and one whose parts are paginated apart.
    def pages(first, last):
        return ''.join(doc('d%d' % k, pb(k, 'pg_%d' % k, '%04d' % k)) for k in range(first, last + 1))
    write(directory, 'frus1911p1.xml', pages(1, 20))
    write(directory, 'frus1911p2.xml', pages(21, 40))
    write(directory, 'frus1952-54v09p1.xml', pages(1, 20))
    write(directory, 'frus1952-54v09p2.xml', pages(31, 40))
    write(directory, 'frus1913p1.xml', pages(1, 20) + pb(21, 'pg_21', '0021') + pb(22, 'pg_22', '0022'))
    write(directory, 'frus1913p2.xml', pages(21, 40))
    write(directory, 'frus1914p1.xml', pages(1, 20))
    write(directory, 'frus1914p2.xml', pages(1, 20))
    report._VOLUMES.clear()
    counts, rows = {'pagination': {'rows': 0, 'byClass': {}}}, []
    report.parts(counts, rows)
    check(counts['parts']['continuousPairs'] == 3, 'three pairs share one pagination; frus1914 does not')
    check(counts['parts']['gaps'] == [{'volume': 'frus1952-54v09p1', 'lastPage': 20, 'nextPartFirstPage': 31}], 'the gap')
    check(len(rows) == 1 and rows[0]['volume'] == 'frus1913p1' and rows[0]['pb_xml_id'] == 'pg_21'
          and '2 page breaks' in rows[0]['what_is_wrong'] and 'outside every division' in rows[0]['what_is_wrong'],
          'the trailing breaks: %s' % rows)
    # A second gap is a failure, not a row: the report says there is one.
    write(directory, 'frus1915p1.xml', pages(1, 20))
    write(directory, 'frus1915p2.xml', pages(50, 60))
    report._VOLUMES.clear()
    raises(report.Failed, lambda: report.parts({'pagination': {'rows': 0, 'byClass': {}}}, []), 'a second gap stops the run')
    os.remove(os.path.join(directory, 'frus1915p1.xml'))
    os.remove(os.path.join(directory, 'frus1915p2.xml'))


def dated(xml_id, when, text, source='', low='', high=''):
    span = (' frus:doc-dateTime-min="%s" frus:doc-dateTime-max="%s"' % (low, high)) if low else ''
    note = '<note type="source">%s</note>' % source if source else ''
    return doc(xml_id, note + '<dateline>Washington, <date when="%s">%s</date></dateline><p>x</p>' % (when, text), extra=span)


def test_dates(directory):
    for name in os.listdir(directory):
        os.remove(os.path.join(directory, name))
    write(directory, 'frus1950v01.xml',
          dated('d1', '1950-03-01', 'March 1, 1950')                                        # clean
          + dated('d2', '1951-03-02', 'March 2, 1950')                                      # the year contradicts the text
          + dated('d3', '1949-03-03', 'March 3, 1949', 'Central Files, 611.00/3–350')   # ... and the file number
          + dated('d4', '1949-03-04', 'March 4, 1949', 'Central Files, 611.00/3–449')   # a real 1949 document
          + dated('d5', '1949-04-04', 'April 4, 1949', 'Central Files, 611.00/3–450')   # another day: not the same date
          + dated('d6', '1950-03-05', 'March 5, 1950', low='1950-03-05T12:00:00-05:00', high='1950-03-05T10:00:00-05:00')
          + dated('d7', '1950-03-06', 'March 6, 1950', low='1950-03-06T12:35:00-03:00', high='1950-03-06T10:43:00-05:00')
          + dated('d8', '1950-03-07', 'undated'))
    report._VOLUMES.clear()
    counts, rows = {}, []
    report.dates(counts, rows)
    by = {(r['class'], r['element']) for r in rows}
    check(by == {('year-contradicts-text', 'd2'), ('year-contradicts-file-number', 'd3'), ('range-inverted', 'd6')},
          'three rows, one per rule: %s' % sorted(by))
    check(counts['dates']['invertedDocuments'] == 1 and counts['dates']['invertedDivisions'] == 0,
          'd7 is not inverted: 12:35 at -03:00 is 10:35 Eastern, before 10:43')


def test_predicates():
    check(report._candidates('d12fn3') == ['d12fn3', 'd12'], 'a footnote falls back to its document')
    check(report._candidates('pg101') == ['pg101', 'pg_101'] and report._candidates('page7') == ['page7', 'pg_7'],
          'pgN and pageN fall back to pg_N')
    check(report._candidates('pg_XVIII') == ['pg_XVIII'] and report._candidates('in4') == ['in4'], 'nothing else falls back')
    check(report._from_roman('XXVIII') == 28 and report._to_roman(28) == 'XXVIII' and report._from_roman('XVIIII') is None
          and report._from_roman('') is None, 'Roman numerals')
    for wrong in ('Department op State, Washington, May 21, 1864.', 'Departmrnt of State, Washington',
                  'D epartment of S tate , Washington', 'Department of Stats , Washington'):
        check(report._department_misspelling(wrong) is not None, 'misspelt: %s' % wrong)
    for right in ('Department of State, Washington', 'Executive Department, State of Louisiana, Baton Rouge',
                  'Department of the Interior, Washington', 'Legation of the United States, Paris'):
        check(report._department_misspelling(right) is None, 'not a misspelling: %s' % right)
    check(report._NEVER_HELD.match('Central Intelligence Agency, Langley, Virginia')
          and report._NEVER_HELD.match('Department of State')
          and not report._NEVER_HELD.match('Department of State, Record Group 84, Files of U.S. Foreign Service Posts')
          and not report._NEVER_HELD.match('Lyndon B. Johnson Library, Austin, Texas'),
          'the Sources-list rule reports four repositories and not a record group under one')


def main():
    test_readers_and_repair()
    test_predicates()
    saved = ohlib.VOLUMES_DIR
    with tempfile.TemporaryDirectory() as directory:
        try:
            test_pagination(directory)
            for name in os.listdir(directory):
                os.remove(os.path.join(directory, name))
            test_parts(directory)
            test_dates(directory)
        finally:
            ohlib.VOLUMES_DIR = saved
            report._VOLUMES.clear()
    print('tools/oh-report selftest: %d checks passed' % CHECKS)


if __name__ == '__main__':
    main()
