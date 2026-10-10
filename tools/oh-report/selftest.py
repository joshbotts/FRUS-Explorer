#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""Self-test for tools/oh-report: the readers, the simulated repair, the report check, and the
pagination, part, date, transcription and Sources-list scans, driven over small synthetic volumes
written to a temporary directory. No corpus needed.

    python3 tools/oh-report/selftest.py

What it covers, and what it does not:

- Each rule of those five scans has a fixture the rule should catch, and the test names the row it
  expects. A condition that narrows a rule should have a control beside it: a fixture one step
  outside the rule, which must give no row (a list's "1)" beside a stray ")", small capitals
  splitting "Department of State" beside a real misspelling, a microfiche supplement beside a
  printed volume, a footnote beside a source note). A condition with no control is one a change can
  drop unnoticed.
- The controls here are the ones somebody's mutant asked for: seventeen from the round-1 review, four
  from the round-2 review, and twenty from a sweep of fifty more single-condition mutants in round 2.
  Three of that sweep still pass every check, each a condition that another condition of the same
  rule already implies. That is not a proof that every condition has a control: one nobody has
  mutated may have none. The session's DEVELOPMENT-PLAN entry itemises the mutants that asked for
  a control; the sweep's full list of fifty is in a scratch log outside the repository.
- `--check`: the whole-figure match, Part A alone, the stated count above Part A, and the arguments.
- main()'s refusals that need no corpus: no CORPUS_COMMIT, no volumes, and a corpus that lacks a
  volume the report names (NAMED), each before anything is scanned or written.
- The chapter-heading misprint the transcription scan asserts in `frus1952-54v09p1`: the same row
  at the report's line and 648 lines lower, and a stop when the heading is corrected.
- NOT covered: the cross-reference scan, the header scan, the missing-documents check and the
  adjudicated structure rows. They read the corpus, or name its files and lines, and are checked
  only by a run over it. Nor is figure_sentences(): no self-test calls it (the `--check` tests
  hand missing_figures() sentences of their own), so the run's sentences are checked only by a
  run with `--check` on the report.

Prints the number of checks and exits 1 on the first failure.
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
<!-- a comment that mentions <div type="chapter" xml:id="ghost"> and </div> and <pb n="9" xml:id="pg_ghost" facs="0009"/> -->
<div type="chapter" subtype="x" xml:id="ch1">
<head>One</head>
<div type="document" xml:id="d1" n="1"><pb n="1" xml:id="pg_1" facs="0001"/><p>text</p></div>
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
    check([p['id'] for p in v.pbs] == ['pg_1'], 'a page break named only in a comment is not read: %s' % v.pbs)
    check('pg_1' in v.ids() and 'ch1' in v.ids() and 'pg_ghost' not in v.ids() and 'ghost' not in v.ids(),
          'an id named only in a comment is not an id of the file')


def test_plain():
    # A quote must be the file's text. An inline tag adds no space; a block tag is one.
    check(ohlib.plain(b'D<hi rend="smallcaps">epartment of</hi> S<hi rend="smallcaps">tate</hi>, Washington')
          == 'Department of State, Washington', 'small capitals that split a word leave the word whole')
    check(ohlib.plain(b'<hi rend="smallcaps">Department of Stat</hi>e,') == 'Department of State,',
          'a letter left outside the small capitals stays on its word')
    check(ohlib.plain(b'Department of State,<gloss target="#t_NEA1">NEA</gloss>/IAI Files') == 'Department of State,NEA/IAI Files',
          'a space the file lacks is not supplied: the glued gloss reads glued')
    check(ohlib.plain(b'The Charg\xc3\xa9 in Israel (<persName corresp="#p_R1">Russell</persName>) to the Department<note n="1">x</note>.')
          == 'The Charg\u00e9 in Israel (Russell) to the Department.', 'no space inside the parentheses or before the stop')
    check(ohlib.plain(b'7slK 5-<gloss target="#t_MSP1">MSP</gloss>/6-2861 Secret; <gloss target="#t_N1">Niact</gloss>. Drafted')
          == '7slK 5-MSP/6-2861 Secret; Niact. Drafted', 'a file number keeps its shape')
    check(ohlib.plain(b'<p>One</p><p>Two</p> line<lb/>break  and\n  <item>three</item>') == 'One Two line break and three',
          'a block tag separates words and whitespace is collapsed')
    # The one place a quotation holds a space the file lacks, which the report's section 6 states.
    check(ohlib.plain(b'<hi rend="smallcaps">Department of Stat</hi><lb/><hi rend="italic"\n   >Washington</hi>, July 22')
          == 'Department of Stat Washington, July 22'
          and ohlib.plain(b'<hi rend="smallcaps">Dapartment of State</hi>,<lb/><hi rend="italic">Washington</hi>')
          == 'Dapartment of State, Washington',
          'a line break reads as one space where the file has no whitespace, and an inline tag beside it as none')


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
    # id disagrees with n: the id above its number (pg_51 on n="50"), and below it (pg_53 on n="54")
    write(directory, 'frus1903.xml',
          doc('d1', pb(50, 'pg_50', '0060') + pb(50, 'pg_51', '0061') + pb(52, 'pg_52', '0062') + pb(54, 'pg_53', '0063')))
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
    # CONTROLS: each is one step outside a rule and must give no row.
    # A microfiche supplement is not paginated like a book: a reversed pair, numbers out of order and a
    # Roman id without its prefix are all left alone there.
    write(directory, 'frus1909mSupp.xml',
          doc('d1', pb(10, 'pg_10', '0020')) + doc('d2', pb(12, 'pg_12', '0022')) + doc('d3', pb(11, 'pg_11', '0021'))
          + doc('d4', pb(30, 'pg_30', '0040') + pb(32, 'pg_32', '0041') + pb(31, 'pg_31', '0042') + pb(33, 'pg_33', '0043'))
          + doc('d5', pb('VIII', 'VIII', '0102')))
    # A second pagination (pg-seq1_N) may run against the first: numbers out of order need pg_ ids.
    write(directory, 'frus1912.xml',
          doc('d1', pb(30, 'pg-seq1_30', '0040') + pb(32, 'pg-seq1_32', '0041') + pb(31, 'pg-seq1_31', '0042')
              + pb(33, 'pg-seq1_33', '0043')))
    # A plate between two numbered pages carries a pg-seq id and one neighbour's number: it is malformed
    # only when BOTH neighbours say its own pg_N is missing. Here pg_8 follows, and there pg_21 is absent.
    write(directory, 'frus1917.xml',
          doc('d1', pb(7, 'pg_7', '0010') + pb(8, 'pg-seq-11', '0011') + pb(8, 'pg_8', '0012') + pb(9, 'pg_9', '0013'))
          + doc('d2', pb(20, 'pg_20', '0030') + pb(22, 'pg-seq-31', '0031') + pb(23, 'pg_23', '0032')))
    # Image names of three digits throughout are the volume's own usage, not a wrong @facs.
    write(directory, 'frus1918.xml', doc('d1', pb(1, 'pg_1', '001') + pb(2, 'pg_2', '002') + pb(3, 'pg_3', '003')))
    # Pages 81 and 82 have no break between pg_80 and pg_83, but pg_81 stands further on (on a leaf with no
    # number): a page whose id exists is not a page without a break, so nothing is reported.
    # Then two duplicate images in which the FIRST break named is the right one: by its neighbours (d2:
    # image 0111 is pg_102's, and pg_104 needs 0113), and by its own id (d3: image d3-1 is pg_d3-1's).
    # Last, a page number that runs backwards on the SAME image (d4): a duplicate image, and not "numbers
    # out of order while the images run forward".
    write(directory, 'frus1919.xml',
          doc('d1', pb(80, 'pg_80', '0090') + pb(83, 'pg_83', '0093') + pb('', 'pg_81', '0094'))
          + doc('d2', pb(101, 'pg_101', '0110') + pb(102, 'pg_102', '0111') + pb(103, 'pg_103', '0112')
                + pb(104, 'pg_104', '0111') + pb(105, 'pg_105', '0114'))
          + doc('d3', pb(1, 'pg_d3-1', 'd3-1') + pb(2, 'pg_d3-2', 'd3-1'))
          + doc('d4', pb(205, 'pg_205', '0210') + pb(204, 'pg_204', '0210') + pb(206, 'pg_206', '0212')))
    # THE EDGES OF TWO RULES.
    # Three reversed pairs, to tell the two editorial-note counters apart: in the first two only the
    # FIRST division is an editorial note; in the third only the SECOND is, and a division with no page
    # break of its own (d8) stands between the two.
    write(directory, 'frus1910.xml',
          doc('d1', pb(12, 'pg_12', '0022'), 'editorial-note') + doc('d2', pb(11, 'pg_11', '0021'))
          + doc('d3', pb(32, 'pg_32', '0042'), 'editorial-note') + doc('d4', pb(31, 'pg_31', '0041'))
          + doc('d5', pb(40, 'pg_40', '0050') + pb(41, 'pg_41', '0051'))
          + doc('d6', pb(42, 'pg_42', '0052'))
          + doc('d7', pb(52, 'pg_52', '0062')) + doc('d8', '<p>no break</p>', 'editorial-note')
          + doc('d9', pb(51, 'pg_51', '0061'), 'editorial-note'))
    # Five pages without a break are still within the rule (a question); eight are past it.
    write(directory, 'frus1916.xml',
          doc('d1', pb(10, 'pg_10', '0020') + pb(16, 'pg_16', '0026') + pb(17, 'pg_17', '0027') + pb(26, 'pg_26', '0036')))

    first_eight = {'frus190%d' % k for k in range(0, 8)}
    ohlib.VOLUMES_DIR = directory
    report._VOLUMES.clear()
    counts, rows = {}, []
    report.pagination(counts, rows)
    check(not [r for r in rows if r['volume'] == 'frus1900'], 'a clean volume gives no row')
    for control, why in (('frus1909mSupp', 'a microfiche supplement is not read for page order or Roman ids'),
                         ('frus1912', 'a second pagination is not numbers out of order'),
                         ('frus1917', 'a pg-seq plate is malformed only when both neighbours say so'),
                         ('frus1918', 'three-digit image names throughout are the volume\'s usage')):
        check(not [r for r in rows if r['volume'] == control],
              '%s: %s' % (why, [(r['class'], r['pb_xml_id']) for r in rows if r['volume'] == control]))
    everything, rows = rows, [r for r in rows if r['volume'] in first_eight]  # the others are read at the end

    pair = rows_of(rows, 'reversed-pair')
    check(len(pair) == 1 and pair[0]['volume'] == 'frus1901' and pair[0]['pb_xml_id'] == 'pg_11'
          and pair[0]['document'] == 'd3' and 'd2, which holds the later page' in pair[0]['what_is_wrong'],
          'the reversed pair is reported once, at the break that runs backwards: %s' % pair)
    edges = {r['pb_xml_id']: r for r in everything if r['volume'] == 'frus1910'}
    check(sorted(edges) == ['pg_11', 'pg_31', 'pg_51'] and all(r['class'] == 'reversed-pair' for r in edges.values()),
          'three reversed pairs in frus1910: %s' % sorted(edges))
    check(counts['pagination']['reversedPairsSecondIsEditorialNote'] == 2,
          'the SECOND division is an editorial note in two pairs (frus1901, and frus1910 d9), not in the two '
          'whose first is: %d' % counts['pagination']['reversedPairsSecondIsEditorialNote'])
    check(counts['pagination']['reversedPairsBothEditorialNotes'] == 1,
          'both are editorial notes in frus1901 alone: %d' % counts['pagination']['reversedPairsBothEditorialNotes'])
    check('Between them stands d8, which holds no page break' in edges['pg_51']['what_is_wrong']
          and 'd7, which holds the later page' in edges['pg_51']['what_is_wrong']
          and edges['pg_51']['correction'].startswith('Put the three divisions back'),
          'a division between the pair is named, and the correction counts it: %s' % edges['pg_51'])
    check('Between them' not in edges['pg_11']['what_is_wrong'] and edges['pg_11']['correction'].startswith('Put the two divisions back')
          and 'Between them' not in pair[0]['what_is_wrong'], 'an adjacent pair says nothing of a third division')
    check(counts['pagination']['reversedPairsWithADivisionBetween'] == 1 and counts['pagination']['reversedPairsAdjacent'] == 3,
          'one pair of the four has a division between it')

    order = rows_of(rows, 'numbers-out-of-order')
    check(len(order) == 1 and order[0]['volume'] == 'frus1902' and order[0]['pb_xml_id'] == 'pg_31',
          'numbers out of order: %s' % order)
    check(not [r for r in pair if r['volume'] == 'frus1902'] and not [r for r in order if r['volume'] == 'frus1901'],
          'the two backward shapes are told apart by the image numbers')

    mismatch = {r['pb_xml_id']: r['correction'] for r in rows_of(rows, 'id-disagrees-with-n')}
    check(sorted(mismatch) == ['pg_51', 'pg_53'] and 'n="51"' in mismatch['pg_51'] and 'n="53"' in mismatch['pg_53'],
          'id against n, the id above its number and below it: %s' % mismatch)

    missing = rows_of(rows, 'missing-break')
    check(len(missing) == 1 and missing[0]['volume'] == 'frus1904' and 'page 71' in missing[0]['what_is_wrong']
          and '<pb facs="0081" n="71" xml:id="pg_71"/>' in missing[0]['correction'] and missing[0]['confidence'] == 'confirmed',
          'one missing break, with the tag to insert: %s' % missing)
    check(counts['pagination']['missingPages'] == 8, 'pages 73-75 with images 0083-0084 are not a missing break: '
          'one page here, two in frus1908 and five in frus1916: %d' % counts['pagination']['missingPages'])
    wide = [r for r in everything if r['volume'] == 'frus1916']
    check(len(wide) == 1 and wide[0]['class'] == 'missing-break' and 'pages 11, 12, 13, 14, 15' in wide[0]['what_is_wrong']
          and wide[0]['confidence'] == 'question', 'five pages without a break are reported, eight (pp. 18-25) are not: %s' % wide)

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
    check(len(rows) == 12, 'twelve rows in the first eight volumes, none unaccounted for: %d' % len(rows))
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
    first_is_right = {r['pb_xml_id']: r for r in everything if r['volume'] == 'frus1919'}
    check(sorted(first_is_right) == ['pg_104', 'pg_204', 'pg_d3-2'] and all(r['class'] == 'wrong-facs' for r in first_is_right.values())
          and len([r for r in everything if r['volume'] == 'frus1919']) == 3,
          'frus1919: three duplicate images, no missing break (pg_81 has its id) and no numbers out of order: %s'
          % [(r['class'], r['pb_xml_id']) for r in everything if r['volume'] == 'frus1919'])
    check('line 3 (n="104"), set facs="0113"' in first_is_right['pg_104']['correction']
          and 'line 4 (xml:id="pg_d3-2"), set facs="d3-2"' in first_is_right['pg_d3-2']['correction'],
          'the suggestion is for the break its neighbours, or its own id, contradict, not for the first one named: %s'
          % [r['correction'] for r in first_is_right.values()])


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
    # A step of three pages between two parts (unnumbered leaves) is not a gap; four is, below.
    write(directory, 'frus1916p1.xml', pages(1, 20))
    write(directory, 'frus1916p2.xml', pages(23, 40))
    report._VOLUMES.clear()
    counts, rows = {'pagination': {'rows': 0, 'byClass': {}}}, []
    report.parts(counts, rows)
    check(counts['parts']['continuousPairs'] == 4, 'four pairs share one pagination; frus1914 does not')
    check(counts['parts']['gaps'] == [{'volume': 'frus1952-54v09p1', 'lastPage': 20, 'nextPartFirstPage': 31}], 'the gap')
    check(len(rows) == 1 and rows[0]['volume'] == 'frus1913p1' and rows[0]['pb_xml_id'] == 'pg_21'
          and '2 page breaks' in rows[0]['what_is_wrong'] and 'outside every division' in rows[0]['what_is_wrong'],
          'the trailing breaks: %s' % rows)
    # A second gap is a failure, not a row: the report says there is one. Four pages is the smallest gap.
    write(directory, 'frus1915p1.xml', pages(1, 20))
    write(directory, 'frus1915p2.xml', pages(24, 34))
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
          + dated('d8', '1950-03-07', 'undated')
          # a date that prints two years agrees with either of them
          + dated('d9', '1950-01-02', 'December 31, 1949\u2013January 2, 1950')
          # a document that only wraps another has no dateline of its own: the inner one's is not read twice
          + '<div type="document" subtype="historical-document" xml:id="d10" n="10"><p>cover</p>\n'
          + dated('d11', '1951-03-08', 'March 8, 1950') + '</div>\n'
          # the file number's own year is outside the volume too: it settles nothing
          + dated('d12', '1949-03-09', 'March 9, 1949', 'Central Files, 611.00/3\u2013948')
          # no year is printed: the encoded date is the editors' inference, and the row says so
          + dated('d13', '1951-03-11', 'undated', 'Central Files, 611.00/3\u20131150')
          # a time with no zone is read at -05:00, the corpus' own offset: 12:00 is then after 10:00 at -05:00
          + dated('d14', '1950-03-12', 'March 12, 1950', low='1950-03-12T10:00:00-05:00', high='1950-03-12T12:00:00')
          # a range of one instant does not end before it begins
          + dated('d15', '1950-03-13', 'March 13, 1950', low='1950-03-13T10:00:00-05:00', high='1950-03-13T10:00:00-05:00')
          # the file number carries the same month and another day: not the same date
          + dated('d16', '1949-03-15', 'March 15, 1949', 'Central Files, 611.00/3\u20131050'))
    # A year before 1900 is a printed year too. The volume is one the report names: its contradicted
    # dates must each be encoded 1891, which dates() asserts when it reads the file.
    write(directory, 'frus1891.xml',
          dated('d1', '1891-12-30', 'December 30, 1890') + dated('d2', '1891-01-05', 'January 5, 1891'))
    # A volume of two years: a date inside them is not contradicted by a file number of the other year.
    # Its chapter carries a range that ends before it begins.
    write(directory, 'frus1950-51v02.xml',
          '<div type="chapter" xml:id="ch1" frus:doc-dateTime-min="1950-05-01T00:00:00-05:00" '
          'frus:doc-dateTime-max="1950-04-01T00:00:00-05:00">\n<head>Chapter</head>\n'
          + dated('d1', '1950-03-10', 'March 10, 1950', 'Central Files, 611.00/3\u20131051') + '</div>\n')
    report._VOLUMES.clear()
    counts, rows = {}, []
    report.dates(counts, rows)
    by = {(r['class'], r['volume'], r['element']) for r in rows}
    one = 'frus1950v01'
    check(by == {('year-contradicts-text', one, 'd2'), ('year-contradicts-file-number', one, 'd3'), ('range-inverted', one, 'd6'),
                 ('year-contradicts-text', one, 'd11'), ('year-contradicts-file-number', one, 'd13'),
                 ('range-inverted', 'frus1950-51v02', 'ch1'), ('year-contradicts-text', 'frus1891', 'd1')},
          'seven rows and no other: d4, d5, d9, d10, d12, d14, d15, d16, the two-year volume\'s d1 and frus1891\'s d2 '
          'are controls: %s' % sorted(by))
    check(counts['dates']['invertedDocuments'] == 1 and counts['dates']['invertedDivisions'] == 1,
          'd7 is not inverted (12:35 at -03:00 is 10:35 Eastern, before 10:43); the chapter is, and is counted as a division')
    filed = {r['element']: r for r in rows if r['class'] == 'year-contradicts-file-number'}
    check(filed['d3']['what_is_wrong'].startswith('The document is dated 1949')
          and filed['d13']['what_is_wrong'].startswith('The dateline prints "undated", with no year; the date encoded for it is 1951')
          and filed['d13']['what_is_wrong'].endswith('The page prints no year to settle it.'),
          'an undated document is not said to be dated: %s' % filed['d13']['what_is_wrong'])
    check(counts['dates']['fileNumberRowsPrintingTheEncodedYear'] == 1 and counts['dates']['fileNumberRowsPrintingNoYear'] == 1
          and counts['dates']['byClass']['year-contradicts-file-number']['rows'] == 2
          and 'file-number-no-year-printed' not in counts['dates']['byClass'],
          'the two kinds of file-number row are counted apart, inside one class')
    check(counts['dates']['rows'] == 7 and counts['dates']['volumes'] == 3 and counts['dates']['yearContradictsTextInFrus1891'] == 1,
          'the totals the report states')


def note(xml_id, text, source=False):
    return '<note n="%s"%s xml:id="%s">%s</note>' % (xml_id[-1], ' type="source"' if source else '', xml_id, text)


def test_transcription(directory):
    for name in os.listdir(directory):
        os.remove(os.path.join(directory, name))
    files = 'Source: Department of State, Central Files, '
    write(directory, 'frus1961v01.xml',
          # a list's "1)" is not a parenthesis: this note is balanced, "))" and all
          doc('d1', note('d1fn1', 'The telegram set out three points: 1) the first; 2) the second (Memorandum by Mr. A to '
                               'Mr. B (ibid.)); and 3) the third.'))
          # one ")" too many
          + doc('d2', note('d2fn1', 'Not printed. (Ibid., 611.00/1-261))'))
          # nested and balanced
          + doc('d3', note('d3fn1', 'See telegram 5 (ibid., 611.00/1-361 (not printed)) and its reply.'))
          # the stray one is not the doubled one: the quotation must end at the stray
          + doc('d4', note('d4fn0', files + '737.56361/11-562). Top Secret. A copy is in another file (ibid. (Lot 62 D 1)).', True))
          # a lost "(" with no "))" in the note is outside this class
          + doc('d5', note('d5fn1', 'Printed ante, p. 427.)'))
          # "S VIEI", and no stop before the classification; beside it the same note read correctly. The note
          # runs on past the designation, as a real one does: the scan for "S VIEI" outside the source notes
          # reads 40 bytes after the word, and must skip this note itself, not lose it inside a whole <note>.
          + doc('d6', note('d6fn0', files + '<gloss target="#t_POL1">POL</gloss> 27 <gloss target="#t_S1">S</gloss> VIEI Secret; Priority. '
                                 'Drafted by Mr. Smith and cleared in substance with Mr. Jones of the Bureau.', True))
          + doc('d7', note('d7fn0', files + '<gloss target="#t_POL1">POL</gloss> 27 <gloss target="#t_S1">S</gloss> VIET. Secret; Priority.', True))
          # the year glued to the label, and the label spaced
          + doc('d8', note('d8fn0', 'Source: National Archives, <gloss target="#t_RG1">RG</gloss> 59, Central\n   Files1970-73, POL 12 IRAQ. Confidential.', True))
          + doc('d9', note('d9fn0', 'Source: National Archives, <gloss target="#t_RG1">RG</gloss> 59, Central Files 1970-73, POL 12 IRAQ. Confidential.', True))
          # a doubled full stop, and an ellipsis, which is not one
          + doc('d10', note('d10fn0', files + 'IRAN-U.S.. Secret.', True))
          + doc('d11', note('d11fn0', files + '611.00/1-1161. Secret. The text ends "and so on..." in the original.', True))
          # no space after the stop: in the text, and where only a tag separates the two
          + doc('d12', note('d12fn0', files + 'US/A/M(SR)/1\u2014.Confidential. Drafted by X.', True))
          + doc('d13', note('d13fn0', files + '611.00/1-1361.<gloss target="#t_S2">Secret</gloss>; Priority.', True))
          + doc('d14', note('d14fn0', files + '611.00/1-1461. <gloss target="#t_S2">Secret</gloss>; Priority.', True))
          # the label misspelt
          + doc('d15', note('d15fn0', 'Source: Department of State, Centrals Files, 611.00/1-1561. Secret.', True))
          # tags glued to the punctuation before them
          + doc('d16', note('d16fn0', 'Source: Department of State,<gloss target="#t_NEA1">NEA</gloss>/IAI Files: Lot 63 D 351,'
                                 '<gloss target="#t_NSC1">NSC</gloss>;<gloss target="#t_X1">X</gloss>, by Mr.,<persName>Y</persName>. Secret.', True))
          # a footnote is not a source note: the label, the doubled stop and the glued year are not reported in one
          + doc('d18', note('d18fn1', 'See Centrals Files, 611.00/1-1861.. Secret. A copy is in Central Files1961-63.'))
          # a marking word that begins a phrase ("Secret Service") is not a classification with its stop
          # lost, and "VIEI" with no "S" before it is not this misreading
          + doc('d19', note('d19fn0', files + 'POL 27 VIEI Secret Service file. Confidential.', True))
          # a stop with no space before a capital that is not a marking
          + doc('d20', note('d20fn0', files + '611.00/1-2061. Secret. Drafted by Mr.Smith.', True))
          # a misspelt dateline in a volume after 1905 is outside the scan
          + doc('d17', '<dateline>Departmrnt of State, Washington, <date when="1961-01-17">January 17, 1961</date></dateline>')
          # "S VIEI" in prose, outside any source note
          + '<div type="section" xml:id="sources"><p>the file is SOC 14-1 <gloss\n target="#t_S1">S</gloss> VIEI SOC is the general category</p></div>\n')
    caps = 'D<hi rend="smallcaps">%s of</hi> S<hi rend="smallcaps">tate</hi>, Washington'

    def line(text):
        return '<dateline>%s, <date when="1865-03-13">March 13, 1865</date>.</dateline><p>x</p>' % text
    write(directory, 'frus1865p2.xml',
          # small capitals split the words: the text reads "Department of State"
          doc('d1', line('<placeName>' + caps % 'epartment' + '</placeName>'))
          + doc('d2', line('<hi rend="smallcaps">Department of Stat</hi>e, Washington'))
          # the same markup over a real misspelling
          + doc('d3', line(caps % 'epartmrnt'))
          + doc('d4', line('Department op State, Washington'))
          + doc('d5', line('Legation of the United States, Paris')))
    report._VOLUMES.clear()
    counts, rows, glued = {}, [], []
    report.transcription(counts, rows, glued)
    by = {(r['class'], r['volume'], r['element']) for r in rows}
    one, two = 'frus1961v01', 'frus1865p2'
    check(by == {('unbalanced-parenthesis', one, 'd2fn1'), ('unbalanced-parenthesis', one, 'd4fn0'),
                 ('viei-for-viet', one, 'd6fn0'), ('no-stop-before-classification', one, 'd6fn0'),
                 ('viei-for-viet', one, 'sources'), ('central-files-year-glued', one, 'd8fn0'),
                 ('doubled-full-stop', one, 'd10fn0'), ('no-space-before-classification', one, 'd12fn0'),
                 ('no-space-before-classification', one, 'd13fn0'), ('central-files-label', one, 'd15fn0'),
                 ('department-of-state-misspelt', two, 'd3'), ('department-of-state-misspelt', two, 'd4')},
          'twelve rows and no other; d1, d3, d5, d7, d9, d11, d14, d17, d18, d19, d20, a second row for d6\'s own '
          'note, and the datelines d1, d2, d5 are controls: %s' % sorted(by))
    text = {(r['class'], r['element']): r['text'] for r in rows}
    check(text[('unbalanced-parenthesis', 'd2fn1')].endswith('611.00/1-261))'), 'the quotation ends at the ")" that closes nothing')
    stray = text[('unbalanced-parenthesis', 'd4fn0')]
    check(stray.endswith('Central Files, 737.56361/11-562)') and 'Lot 62' not in stray,
          'where the doubled ")" is balanced, the stray one is quoted, not the doubled one: %s' % stray)
    check(counts['transcription']['notesWithAnUnmatchedCloser'] == {'notes': 3, 'volumes': 1, 'reported': 2},
          'a lost "(" with no "))" is counted and not listed: %s' % counts['transcription']['notesWithAnUnmatchedCloser'])
    check(text[('department-of-state-misspelt', 'd3')].startswith('Departmrnt of State, Washington, March 13, 1865.'),
          'the dateline is quoted as the file reads it: %s' % text[('department-of-state-misspelt', 'd3')])
    check('RG 59, Central Files1970-73, POL 12 IRAQ.' in text[('central-files-year-glued', 'd8fn0')],
          'the glued year is quoted with the text round it: %s' % text[('central-files-year-glued', 'd8fn0')])
    check(text[('viei-for-viet', 'd6fn0')].startswith('Source: Department of State, Central Files, POL 27 S VIEI Secret; Priority.')
          and text[('viei-for-viet', 'sources')].endswith('SOC 14-1 S VIEI SOC is the general category'),
          'a quotation holds no space at an inline tag: %s' % text[('viei-for-viet', 'sources')])
    check(counts['transcription']['vieiSourceNotes'] == 1 and counts['transcription']['vieiElsewhere'] == 1,
          'the misreading in prose is counted apart from the source notes')
    check(glued == [{'volume': one, 'file': one + '.xml', 'comma_then_gloss': 2, 'comma_then_persName': 1, 'semicolon_then_gloss': 1}],
          'the glued tags of one file: %s' % glued)
    check(counts['transcription']['rows'] == 12 and counts['transcription']['noStopInTopTwoVolumes'] == 1, 'the totals the report states')


def test_heading_misprint(directory):
    """The one row the report asserts and does not scan for: `frus1952-54v09p1`'s chapter heading.

    It is found from the chapter's own start tag, so it is the same row wherever the lines above put
    it. Read by line number, it was reported gone once Documents 900-946 came back 648 lines above.
    Runs after test_transcription and keeps its two volumes, which the scan's other classes need."""
    heading = ('<div type="chapter" xml:id="ch4">\n<head>United States Relations with Israel, the %s\n'
               'Kingdom of Jordan, Lebanon, and Syria</head>\n')

    def scan(lines_above, word='Hashe\u2013Mite'):
        write(directory, 'frus1952-54v09p1.xml',
              '<div type="compilation" xml:id="comp1">\n' + '<p>x</p>\n' * lines_above
              + heading % word + doc('d1', '<p>x</p>') + '</div>\n</div>\n')
        report._VOLUMES.clear()
        counts, rows, glued = {}, [], []
        report.transcription(counts, rows, glued)
        return rows_of(rows, 'heading-misprint')
    # 67,634 lines above put the misprint on line 67638, where it stood at the report's revision.
    first = scan(67634)
    check(len(first) == 1 and (first[0]['volume'], first[0]['element'], first[0]['line']) == ('frus1952-54v09p1', 'ch4', 67638),
          'the heading is one row, on its chapter, at the line the report gave: %s' % first)
    lower = scan(67634 + 648)
    check(len(lower) == 1 and lower[0]['line'] == 68286
          and {k: v for k, v in lower[0].items() if k != 'line'} == {k: v for k, v in first[0].items() if k != 'line'},
          'with 648 more lines above it, it is the same row at line 68286: %s then %s' % (first, lower))
    raises(report.Failed, lambda: scan(67634, 'Hashemite'), 'a heading that reads Hashemite stops the class')
    os.remove(os.path.join(directory, 'frus1952-54v09p1.xml'))
    report._VOLUMES.clear()


def test_sources_lists(directory):
    for name in os.listdir(directory):
        os.remove(os.path.join(directory, name))
    archives = 'National Archives and Records Administration, College Park, Maryland'
    write(directory, 'frus1970v01.xml',
          '<div type="section" subtype="sources" xml:id="sources"><list>\n'
          '<item><hi rend="strong">' + archives + '</hi>\n<list>\n'
          '<item>Record Group 59</item>\n'
          # a repository's heading inside another repository's list
          '<item><hi rend="strong">Central Intelligence Agency</hi><list><item>Job 80</item></list></item>\n'
          # the same words in an entry that is not a heading
          '<item>Central Intelligence Agency, records cited from the Archives\' copies</item>\n'
          # a presidential library under the Archives is where it belongs
          '<item><hi rend="strong">Lyndon B. Johnson Library, Austin, Texas</hi></item>\n'
          '</list></item>\n'
          # a heading at the top level is nested in nothing
          '<item><hi rend="strong">Library of Congress, Washington, D.C.</hi></item>\n'
          # a repository's heading under a heading that is not a repository
          '<item><hi rend="strong">Unpublished Sources</hi><list><item><hi rend="strong">Department of State</hi></item></list></item>\n'
          # ... and under an entry that names a repository but is not a heading
          '<item>National Archives and Records Administration holdings, as follows<list>'
          '<item><hi rend="strong">Library of Congress</hi></item></list></item>\n'
          # a heading that repeats the repository it stands under
          '<item><hi rend="strong">Department of State</hi><list>'
          '<item><hi rend="strong">Department of State, Washington, D.C.</hi></item></list></item>\n'
          '</list></div>\n'
          # the nesting the rule reports, in a division that is not a Sources list
          '<div type="section" subtype="persons" xml:id="persons"><list>\n'
          '<item><hi rend="strong">' + archives + '</hi><list><item><hi rend="strong">Central Intelligence Agency</hi></item></list></item>\n'
          '</list></div>\n')
    report._VOLUMES.clear()
    counts, rows = {}, []
    report.sources_lists(counts, rows)
    check(len(rows) == 1 and rows[0]['nested_heading'] == 'Central Intelligence Agency' and rows[0]['inside_heading'] == archives
          and rows[0]['line'] == 6,
          'one heading nested in another\'s list; the plain entry, the library, the top-level heading, the three items '
          'after it and the persons division are controls: %s'
          % [(r['line'], r['nested_heading']) for r in rows])
    check(counts['sourcesLists'] == {'divisionsRead': 1, 'rows': 1, 'volumes': 1}, 'the totals the report states')


def test_predicates():
    check(report._candidates('d12fn3') == ['d12fn3', 'd12'], 'a footnote falls back to its document')
    check(report._candidates('pg101') == ['pg101', 'pg_101'] and report._candidates('page7') == ['page7', 'pg_7'],
          'pgN and pageN fall back to pg_N')
    check(report._candidates('pg_XVIII') == ['pg_XVIII'] and report._candidates('in4') == ['in4'], 'nothing else falls back')
    check(report._from_roman('XXVIII') == 28 and report._to_roman(28) == 'XXVIII' and report._from_roman('XVIIII') is None
          and report._from_roman('') is None, 'Roman numerals')
    for wrong in ('Department op State, Washington, May 21, 1864.', 'Departmrnt of State, Washington',
                  'Dapartment of State, Washington', 'Department of Stats, Washington'):
        check(report._department_misspelling(wrong) is not None, 'misspelt: %s' % wrong)
    # "Dept. of State" is an abbreviation, 0.81 like the name: under the 0.86 the rule asks for.
    for right in ('Department of State, Washington', 'Executive Department, State of Louisiana, Baton Rouge',
                  'Department of the Interior, Washington', 'Legation of the United States, Paris',
                  'Dept. of State, Washington'):
        check(report._department_misspelling(right) is None, 'not a misspelling: %s' % right)
    walk = report._stray_closers
    check(walk('(a (b)) c') == [] and walk('x (y)) z') == [5] and walk('a) x (y)) z') == [8] and walk('none') == [],
          'the parentheses are walked in order; a leading "a)" is an enumerator')
    check(walk('notes: 1) one; 2) two (see (ibid.)); and 3) three') == [] and walk('reads: \u201c1) Return (now)\u201d') == []
          and walk('of two kinds, iv) the last') == [], 'enumerators after a colon, a semicolon, a quotation mark or a comma')
    check(walk('Central Files, 737.56361/11-562). Top Secret') == [31] and walk('p. 427.)') == [7]
          and walk('la)r people') == [2] and walk('CCS 383.21 Korea 3\u201319\u201345)') == [24] and walk('March 1945)') == [10]
          and walk('see p. 427)') == [10],
          'a ")" after a file number, a stop, a year, a page of three digits or inside a word is not an enumerator')
    check(report._NEVER_HELD.match('Central Intelligence Agency, Langley, Virginia')
          and report._NEVER_HELD.match('Department of State')
          and not report._NEVER_HELD.match('Department of State, Record Group 84, Files of U.S. Foreign Service Posts')
          and not report._NEVER_HELD.match('Lyndon B. Johnson Library, Austin, Texas'),
          'the Sources-list rule reports four repositories and not a record group under one')


REPORT = '''# Report
Run it with `--check` and it stops when one of 4 figure sentences here no longer matches.

# Part A
The scan read 744 files. 11 files carry no date; 34 datelines in 23 volumes; 1,213 sites in 40 files.
It is the only gap among the 22 pairs. Its own scan read 2,714,283 targets, 1.5 for each page, and
names the likely page for 13.

# Part B
The audit had 9 datelines in 23 volumes.
'''


def test_check(directory):
    absent = lambda sentences, text=REPORT: report.missing_figures(sentences, text)  # noqa: E731
    carried = ['11 files carry', '34 datelines in 23 volumes', '1,213 sites in 40 files', 'the only gap among the 22']
    check(absent(carried) == ([], None), 'every figure of the run is in Part A: %s' % (absent(carried),))
    # A stale report must not pass because the run's smaller figure is the tail, or the head, of its own.
    for stale in ('1 files carry', '4 datelines in 23 volumes', '213 sites in 40 files', '13 sites in 40 files',
                  'the only gap among the 2', '34 datelines in 2 volumes'):
        check(absent([stale] + carried[1:])[0] == [stale], 'a figure inside a longer number is not carried: %s' % stale)
    # The same at the END of a sentence: its last number is not the head of a longer one, grouped or decimal.
    for stale in ('Its own scan read 2', 'targets, 1'):
        check(absent([stale] + carried[1:])[0] == [stale], 'a figure that a comma or a stop and more digits follow is not carried: %s' % stale)
    check(absent(['names the likely page for 13', 'Its own scan read 2,714,283 targets'] + carried[2:]) == ([], None),
          'a full stop or a comma that ends the clause is not part of the number')
    check(absent(['9 datelines in 23 volumes'] + carried[1:])[0] == ['9 datelines in 23 volumes'],
          'a figure that stands only in Part B is not carried')
    check(absent(carried[:3])[0] == ['3 figure sentences (in the lines above Part A)'],
          'the lines above Part A must say how many sentences there are')
    stated = '4 figure sentences (in the lines above Part A)'
    unstated = REPORT.replace('one of 4 figure sentences here', 'one of the figure sentences here')
    check(unstated != REPORT and absent(carried, unstated.replace('The audit had', 'It has 4 figure sentences. The audit had'))[0] == [stated]
          and absent(carried, unstated.replace('The scan read 744 files.', 'The scan read 744 files for 4 figure sentences.'))[0] == [stated],
          'the number of sentences stated only in Part B, or only in Part A, is not stated above Part A')
    check(absent(carried, REPORT.replace('# Part B', '# Annex'))[0] is None and absent(carried, REPORT.replace('# Part A', '# One'))[0] is None,
          'a report without the two headings is not checked against the whole file')
    path = os.path.join(directory, 'report.md')
    with open(path, 'w', encoding='utf-8') as handle:
        handle.write(REPORT)
    tool = 'build_oh_report.py'
    check(report.report_to_check([tool]) is None and report.report_to_check([tool, '--check', path]) == REPORT,
          'no argument means no check; --check FILE reads the file')
    for wrong in ([tool, '--check'], [tool, path, '--check'], [tool, path], [tool, '--check', path + '.missing'],
                  [tool, '--chek', path], [tool, '--check', path, path]):
        raises(SystemExit, lambda: report.report_to_check(wrong), 'refused before the corpus is read: %s' % wrong[1:])
    os.remove(path)


def stopped(action):
    """What a run stopped with: sys.exit's message, or the name of whatever else it died of."""
    try:
        action()
    except SystemExit as stop:
        return str(stop.code)
    except Exception as error:  # a run that passed a refusal dies further on, of anything
        return '%s: %s' % (type(error).__name__, error)
    return 'ran to the end'


def test_refusals(directory):
    # main() refuses three things before it scans or writes. Each is run for real, on a corpus that
    # is one step short; a refusal that is dropped lets the run go on and stop with something else.
    for name in os.listdir(directory):
        os.remove(os.path.join(directory, name))
    ohlib.VOLUMES_DIR = directory
    out = os.path.join(directory, 'written')
    saved = {key: os.environ.get(key) for key in ('CORPUS_COMMIT', 'OUT_DIR')}

    def run():
        report._VOLUMES.clear()
        return stopped(lambda: report.main(['build_oh_report.py']))
    try:
        os.environ['OUT_DIR'] = out
        os.environ.pop('CORPUS_COMMIT', None)
        check(run().startswith('NOT WRITTEN: CORPUS_COMMIT is required'), 'no CORPUS_COMMIT: %s' % run())
        os.environ['CORPUS_COMMIT'] = 'selftest'
        check(run() == 'NOT WRITTEN: no volumes under %s' % directory, 'an empty corpus: %s' % run())
        # One fixture for each volume the report names: the corpus holds the other three and lacks it.
        for lacking in report.NAMED:
            for name in report.NAMED:
                path = os.path.join(directory, name + '.xml')
                if name == lacking:
                    if os.path.exists(path):
                        os.remove(path)
                else:
                    write(directory, name + '.xml', doc('d1', pb(1, 'pg_1', '0001') + '<p>x</p>'))
            check(run() == "NOT WRITTEN: the corpus under %s lacks ['%s'], which the report names" % (directory, lacking),
                  'a corpus without %s is refused by name: %s' % (lacking, run()))
        check(len(report.NAMED) == 4 and not os.path.exists(out), 'four volumes are named, and a refused run creates no output directory')
    finally:
        for key, value in saved.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


def main():
    test_readers_and_repair()
    test_plain()
    test_predicates()
    saved = ohlib.VOLUMES_DIR
    with tempfile.TemporaryDirectory() as directory:
        try:
            test_check(directory)
            test_pagination(directory)
            for name in os.listdir(directory):
                os.remove(os.path.join(directory, name))
            test_parts(directory)
            test_dates(directory)
            test_transcription(directory)
            test_heading_misprint(directory)
            test_sources_lists(directory)
            test_refusals(directory)
        finally:
            ohlib.VOLUMES_DIR = saved
            report._VOLUMES.clear()
    print('tools/oh-report selftest: %d checks passed' % CHECKS)


if __name__ == '__main__':
    main()
