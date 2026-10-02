#!/usr/bin/env python3
# Copyright 2026 The FRUS Explorer Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
"""Re-check every item of the Office of the Historian report (#1309) against the corpus and write
its CSVs.

Each class is either a SCAN (a rule run over all of volumes/*.xml, whose rows are whatever the rule
finds) or an ADJUDICATED table (rows written by hand in this file, each one re-verified here: a
structural correction is applied to a copy of the file, re-parsed, and its stated before and after
nesting asserted; a suggested cross-reference target must exist). The run exits 1, writing nothing
and printing "NOT WRITTEN", when an adjudicated row no longer holds, when a scan finds nothing, when
the regenerated broken-reference CSV and the corpus disagree, when CORPUS_COMMIT is missing, and
when its arguments are anything but none or `--check FILE`.

Every quotation in the CSVs is the file's own text: ohlib.plain() adds no space where an inline tag
stands, so a quotation can be compared with the file character for character.

    CORPUS_COMMIT   required: the corpus revision every line number is relative to
    VOLUMES_DIR     the corpus' volumes/ directory (default ~/Development/frus/volumes)
    XREF_CSV        CrossRefValidationGenerator's broken-refs-report.csv for that revision
                    (default Planning/cross-ref-validation/broken-refs-report.csv)
    MANIFEST        the app manifest (default FRUSExplorer/Resources/manifest.json)
    OUT_DIR         where the CSVs and counts.json go (default Planning/OH-Report-2026-10-01)
    GENERATED_DATE  the date stamped into counts.json (default today)

    build_oh_report.py                 write the CSVs and counts.json
    build_oh_report.py --check FILE    also require Part A of FILE (the report) to carry every figure
                                       sentence of this run, each as a whole figure (missing_figures)
"""
import collections
import csv
import datetime
import difflib
import json
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ohlib  # noqa: E402
from ohlib import Volume, attrs, move_close_tags, plain, retype_div, volume_files  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HSG = 'https://history.state.gov/historicaldocuments/'


class Failed(Exception):
    """A re-check that did not hold."""


def require(condition, message):
    if not condition:
        raise Failed(message)


_VOLUMES = {}


def volume(vid):
    """A cached Volume by id."""
    if vid not in _VOLUMES:
        _VOLUMES[vid] = Volume(vid + '.xml')
    return _VOLUMES[vid]


# ---------------------------------------------------------------------------------------------
# G. The missing documents of frus1952-54v09p1
# ---------------------------------------------------------------------------------------------

GAP_SOURCE_COMMIT = 'd7c15c90c'


def gap(counts, out_rows):
    p1, p2 = volume('frus1952-54v09p1'), volume('frus1952-54v09p2')
    arabic = [p for p in p1.pbs if p['n'] and p['n'].isdigit()]
    docs1 = [d for d in p1.divs if d['type'] == 'document']
    docs2 = [d for d in p2.divs if d['type'] == 'document']
    last_page = arabic[-1]
    first_page2 = [p for p in p2.pbs if p['n'] and p['n'].isdigit()][0]
    require(last_page['n'] == '1660' and docs1[-1]['id'] == 'd899', 'v09p1 no longer ends at d899 / p. 1660')
    require(docs2[0]['id'] == 'd947' and first_page2['n'] == '1743', 'v09p2 no longer begins at d947 / p. 1743')
    errata = p1.div('errata')
    require(errata is not None and errata['line'] > docs1[-1]['close'], 'errata no longer follows d899')
    toc = re.search(rb'<ref target="frus1952-54v09p2#pg_1743">', p1.blanked)
    require(toc is not None, 'v09p1 no longer links Part 2 at p. 1743')
    v14 = volume('frus1955-57v14')
    cite = re.search(rb'<ref target="frus1952-54v09p1#pg_1660">.*?</ref>\s*\xe2\x80\x93\s*1741', v14.blanked, re.S)
    require(cite is not None, 'frus1955-57v14 no longer cites Part 1, pages 1660-1741')
    counts['gap'] = {
        'lastDocument': docs1[-1]['id'], 'lastDocumentLine': docs1[-1]['line'],
        'lastPage': int(last_page['n']), 'lastPageLine': last_page['line'],
        'errataLine': errata['line'], 'documentsInPart1': len(docs1),
        'part2FirstDocument': docs2[0]['id'], 'part2FirstDocumentLine': docs2[0]['line'],
        'part2FirstPage': int(first_page2['n']), 'part2FirstPageLine': first_page2['line'],
        'tocLinkLine': p1.line(toc.start()), 'laterCitationLine': v14.line(cite.start()),
        'sourceCommit': GAP_SOURCE_COMMIT,
    }
    # The documents themselves, read from the corpus' own history when it is available.
    repo = os.path.dirname(os.path.abspath(ohlib.VOLUMES_DIR))
    try:
        old = subprocess.run(['git', '-C', repo, 'show', GAP_SOURCE_COMMIT + '^:volumes/frus1952-54v09p1.xml'],
                             capture_output=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        counts['gap']['historyChecked'] = False
        return
    before = Volume('frus1952-54v09p1.xml', old)
    old_docs = [d for d in before.divs if d['type'] == 'document']
    old_pages = [p for p in before.pbs if p['n'] and p['n'].isdigit()]
    counts['gap'].update({'historyChecked': True, 'documentsBefore': len(old_docs),
                          'lastPageBefore': int(old_pages[-1]['n'])})
    require(len(old_docs) == 946 and old_pages[-1]['n'] == '1741', 'the pre-delivery file is not 946 documents to p. 1741')
    for d in old_docs:
        number = int(d['n']) if d['n'] and d['n'].isdigit() else None
        if number is None or number < 900:
            continue
        body = before.raw[d['off']:d['close_off']]
        head = re.search(rb'<head\b[^>]*>(.*?)</head>', body, re.S)
        date = re.search(rb'<date\b[^>]*when="([^"]+)"', body)
        inside = [p['n'] for p in old_pages if d['off'] <= p['off'] <= d['close_off']]
        prior = [p['n'] for p in old_pages if p['off'] < d['off']]
        first = prior[-1] if prior else ''
        out_rows.append({
            'document_number': number, 'xml_id': d['id'],
            'heading': re.sub(r'^No\. \d+\s*', '', plain(head.group(1))) if head else '',
            'date': date.group(1).decode()[:10] if date else '',
            'begins_on_page': first, 'page_breaks_inside': ' '.join(inside),
            'line_in_' + GAP_SOURCE_COMMIT + '_parent': d['line'],
        })
    require(len(out_rows) == 47, 'expected documents 900-946 in the pre-delivery file, found %d' % len(out_rows))


# ---------------------------------------------------------------------------------------------
# S. Structure: adjudicated corrections, each simulated
# ---------------------------------------------------------------------------------------------

def _same(ids, parent):
    return {i: parent for i in ids}


# 'sweep_rows' names the row(s) of Planning/corpus-structure-sweep/structure-sweep.csv an edit replaces. It is
# for this repository's record (the report's B.2) and is not written to the CSV that goes to the editors.
STRUCTURE = [
    {
        'volume': 'frus1945Malta',
        'before': dict(_same(['ch9', 'ch10', 'ch11'], 'ch8'), ch8subch22='ch8subch21',
                       **_same(['ch8subch23', 'ch8subch31', 'ch8subch40', 'ch8subch45'], 'ch8subch19')),
        'after': dict(_same(['ch9', 'ch10', 'ch11'], 'comp3'), ch8subch22='ch8subch19',
                      **_same(['ch8subch23', 'ch8subch31', 'ch8subch40', 'ch8subch45'], 'ch8')),
        'edits': [{
            'element': 'ch8subch22', 'confidence': 'confirmed', 'move': (94240, 71605),
            'wrong': 'One closing tag is written 22,635 lines late. Chapters 9, 10 and 11 (Other conference documents, '
                     'Signed agreements, Post-conference documents) sit inside chapter 8 (Minutes and related documents); '
                     'Thursday 8 to Sunday 11 February sit inside Wednesday 7 February; and the Fourth plenary meeting '
                     'sits inside the Foreign Ministers\' meeting of the same day.',
            'correction': 'Move the </div> at line 94240 to line 71605, immediately before <div xml:id="ch8subch22">. '
                          'One move repairs all eight divisions.',
            'evidence': 'The volume\'s contents list prints 7., 8., 9., 10. and 11. at one level (lines 9471, 9474, 9674, '
                        '9678, 9692); February 7 and February 8 at one level (lines 9552, 9567); and the Foreign '
                        'Ministers\' meeting and the Fourth plenary meeting of February 7 side by side (lines 9559, 9563).',
            'evidence_lines': [(9674, '9. <hi'), (9678, '10. <hi'), (9692, '11. <hi'), (9552, 'Wednesday, February 7, 1945'),
                               (9567, 'Thursday, February 8, 1945'), (9559, 'Meeting of the Foreign Ministers'),
                               (9563, 'Fourth plenary meeting')],
            'sweep_rows': 'ch8subch22',
        }],
    },
    {
        'volume': 'frus1945Berlinv02',
        'before': dict(_same(['ch7subch3', 'ch7subch4', 'ch7subch5', 'ch7subch6', 'ch7subch7'], 'ch7subch2'),
                       ch9subch11='ch9subch10', ch9subch12='ch9subch10', ch10='ch9',
                       **{'d710a-83': 'd710a-82'},
                       **_same(['ch20subsubch%d' % k for k in range(11, 23)], 'ch20')),
        'after': dict(_same(['ch7subch3', 'ch7subch4', 'ch7subch5', 'ch7subch6', 'ch7subch7'], 'ch7'),
                      ch9subch11='ch9', ch9subch12='ch9', ch10='comp2',
                      **{'d710a-83': 'ch9subch11'},
                      **_same(['ch20subsubch%d' % k for k in range(11, 23)], 'ch20subch4')),
        'edits': [
            {
                'element': 'ch7subch3', 'confidence': 'confirmed', 'move': (47016, 45167),
                'wrong': 'Five sessions of Saturday, July 21 (the Combined Chiefs of Staff at 3:30 p.m. through the '
                         'Economic Subcommittee) sit inside the Joint Chiefs of Staff meeting of 12:15 p.m.',
                'correction': 'Move the </div> at line 47016 to line 45167, immediately before <div xml:id="ch7subch3">.',
                'evidence': 'The contents list prints all seven sessions of July 21 at one level (lines 15128-15143).',
                'evidence_lines': [(15130, 'Meeting of the Joint Chiefs of'), (15132, 'Meeting of the Combined Chiefs of')],
                'sweep_rows': 'ch7subch3',
            },
            {
                'element': 'ch9subch11', 'confidence': 'confirmed', 'move': (58944, 53927),
                'wrong': 'The Tripartite dinner meeting and the Mosely-Gusev conversation sit inside the Seventh plenary '
                         'meeting, and Tuesday, July 24 (ch10) sits inside Monday, July 23 (ch9). It is one displaced tag.',
                'correction': 'Move the </div> at line 58944 to line 53927, immediately before <div xml:id="ch9subch11">.',
                'evidence': 'The contents list prints the dinner meeting and the Mosely-Gusev conversation beside the '
                            'Seventh plenary meeting under July 23 (lines 15195-15202) and opens a separate list for '
                            'July 24 (line 15205); the compilation holds one chapter per day, July 16 to August 1.',
                'evidence_lines': [(15197, 'Tripartite dinner meeting, 8:30'), (15205, 'Tuesday, July 24, 1945')],
                'sweep_rows': 'ch9subch11; ch10',
            },
            {
                'element': 'd710a-83', 'confidence': 'confirmed', 'move': (54172, 54090),
                'wrong': 'Bohlen\'s memorandum to the President (d710a-83) is nested inside the Editor\'s Note before it '
                         '(d710a-82): a document inside a document, the only one in the volume.',
                'correction': 'Move the </div> at line 54172 to line 54090, immediately before <div xml:id="d710a-83">.',
                'evidence': 'The note itself says "Aside from the Bohlen memorandum printed immediately below" (line 54054).',
                'evidence_lines': [(54055, 'memorandum printed immediately below')],
                'sweep_rows': 'd710a-83',
            },
            {
                'element': 'ch20subsubch11', 'confidence': 'confirmed', 'move': (91910, 106647),
                'wrong': 'Here the tag is written too EARLY: "Germany:" (ch20subch4) closes after its first topic, so its '
                         'other twelve topics, Reparations through German forces in Norway (ch20subsubch11-22), sit '
                         'beside the countries instead of under Germany.',
                'correction': 'Move the </div> at line 91910 to line 106647, after the </div> that closes ch20subsubch22 '
                              'and before <pb n="1041"/>.',
                'evidence': 'The contents list prints all thirteen topics under "Germany:" (lines 15479-15507).',
                'evidence_lines': [(15479, 'Germany: <list>'), (15505, 'German forces in')],
                'sweep_rows': 'ch20subsubch11',
            },
        ],
    },
    {
        'volume': 'frus1873p1v2',
        'before': {'ch5subsubch14': 'ch5subch3', 'ch5subsubch15': 'ch5subch3', 'ch5subsubch16': 'ch5subsubch15'},
        'after': {'ch5subsubch14': 'ch5', 'ch5subsubch15': 'ch5', 'ch5subsubch16': 'ch5subsubch15', 'ch5subch4': 'ch5'},
        'edits': [{
            'element': 'ch5subsubch14', 'confidence': 'confirmed', 'move': (61319, 57993),
            'wrong': 'In Appendix No. I, Part IV (Correspondence between the United States and Great Britain) and Part V '
                     '(... and Other Countries) sit inside Part III (Laws of Other Countries), after its last country.',
            'correction': 'Move the </div> at line 61319, which closes Part III (ch5subch3), to line 57993, immediately '
                          'before <div xml:id="ch5subsubch14">. Parts III to VI are then siblings and Part V keeps its '
                          'nine countries.',
            'evidence': 'The List of Papers prints Parts III, IV, V and VI at one level (lines 48063, 48114, 48118, 48285).',
            'evidence_lines': [(48063, 'Part III.'), (48114, 'Part IV.'), (48118, 'Part V.'), (48285, 'Part VI.')],
            'sweep_rows': 'ch5subsubch16 (whose stated edit, 61318 to 58025, was wrong: see the report, B.2)',
        }],
    },
    {
        'volume': 'frus1943CairoTehran',
        'before': {'ch12subsubch24': 'ch12subsubch23'},
        'after': {'ch12subsubch24': 'ch12subch5'},
        'edits': [{
            'element': 'ch12subsubch24', 'confidence': 'confirmed', 'move': (71095, 71015),
            'wrong': 'The Combined Chiefs of Staff dinner meeting of Monday, December 6 sits inside the 7:30 p.m. meeting '
                     'before it.',
            'correction': 'Move the </div> at line 71095 to line 71015, immediately before <div xml:id="ch12subsubch24">.',
            'evidence': 'The contents list prints the dinner meeting beside the day\'s other seven sessions (lines 8791-8816).',
            'evidence_lines': [(8790, 'Monday, December 6, 1943'), (8814, 'Dinner meeting of the')],
            'sweep_rows': 'ch12subsubch24',
        }],
    },
    {
        'volume': 'frus1949v07p2',
        'before': {'comp2': 'comp1'},
        'after': {'comp2': ''},
        'edits': [{
            'element': 'comp2', 'confidence': 'confirmed', 'move': (48905, 41483),
            'wrong': 'The compilation "East Asian-Pacific area" sits inside the compilation "Northeast Asia:".',
            'correction': 'Move the </div> at line 48905 to line 41483, immediately before <div xml:id="comp2">.',
            'evidence': 'The contents list prints "Northeast Asia" and "East Asian-Pacific Area" at one level (lines 5554, 5576).',
            'evidence_lines': [(5554, 'Northeast Asia'), (5576, 'East Asian-Pacific Area')],
            'sweep_rows': 'comp2',
        }],
    },
    {
        'volume': 'frus1874',
        'before': _same(['comp28', 'comp29', 'comp30'], 'comp27'),
        'after': _same(['comp28', 'comp29', 'comp30'], ''),
        'edits': [{
            'element': 'comp28', 'confidence': 'confirmed', 'move': (115159, 106516),
            'wrong': 'Three countries, "Sweden and Norway.", "Turkish Empire." and "Venezuela." (comp28-comp30), sit '
                     'inside "Spain." (comp27).',
            'correction': 'Move the </div> at line 115159 to line 106516, immediately before <div xml:id="comp28">.',
            'evidence': 'The volume\'s 29 country compilations (comp2 to comp30) are in alphabetical order, Argentine '
                        'Republic to Venezuela. The 26 through Spain are siblings; these three continue the alphabet.',
            'evidence_lines': [],
            'alphabetical': ['comp%d' % k for k in range(2, 31)],
            'sweep_rows': 'comp28',
        }],
    },
    {
        'volume': 'frus1900',
        'before': {'ch19': 'ch18'},
        'after': {'ch19': 'comp6'},
        'edits': [{
            'element': 'ch19', 'confidence': 'confirmed', 'move': (37213, 33397),
            'wrong': '"Negotiations with China for settlement and reparation" (ch19) sits inside "The Siege and relief of '
                     'the legations at Pekin" (ch18).',
            'correction': 'Move the </div> at line 37213 to line 33397, immediately before <div xml:id="ch19">.',
            'evidence': 'The contents list prints the two as consecutive items under China (lines 6653, 6655).',
            'evidence_lines': [(6653, 'Siege and relief of legations at'), (6655, 'Negotiations with China for settlement')],
            'sweep_rows': 'ch19',
        }],
    },
    {
        'volume': 'frus1915',
        'before': {'ch90subsubch1': 'ch90'},
        'after': {'ch90subsubch1': 'ch90subch2'},
        'edits': [{
            'element': 'ch90subsubch1', 'confidence': 'confirmed', 'move': (126758, 127506),
            'wrong': 'The tag is written too early: "Spanish interests" (ch90subch2) closes before its own sub-topic, '
                     '"Expulsion of the Spanish Minister from Mexico" (ch90subsubch1), which is left beside it.',
            'correction': 'Move the </div> at line 126758 to line 127506, immediately before <div xml:id="ch90subch3">.',
            'evidence': 'The contents list nests "Expulsion of the Spanish Minister from Mexico" under "Spanish interests" '
                        '(lines 9350-9357).',
            'evidence_lines': [(9350, 'Spanish interests'), (9353, 'Expulsion of the Spanish')],
            'sweep_rows': 'ch90subsubch1',
        }],
    },
    {
        'volume': 'frus1943',
        'before': _same(['ch11subsubch11', 'ch11subsubch12'], 'ch11'),
        'after': _same(['ch11subsubch11', 'ch11subsubch12'], 'ch11subch6'),
        'edits': [{
            'element': 'ch11subsubch11', 'confidence': 'confirmed', 'move': (113917, 114064),
            'wrong': 'The tag is written too early: "Wednesday, September 8, 1943" (ch11subch6) closes after its first '
                     'meeting, leaving its luncheon and early-afternoon meetings beside the days.',
            'correction': 'Move the </div> at line 113917 to line 114064, immediately before <div xml:id="ch11subch7">.',
            'evidence': 'The contents list prints all three meetings under September 8 (lines 10102-10115).',
            'evidence_lines': [(10102, 'Wednesday, September 8, 1943'), (10109, 'luncheon meeting,')],
            'sweep_rows': 'ch11subsubch11',
        }],
    },
    {
        'volume': 'frus1947v03',
        'before': dict(_same(['ch8subch5', 'ch8subch6', 'ch8subch7', 'ch8subch8'], 'comp2'),
                       **_same(['ch8subch9', 'ch8subch10', 'ch8subch11', 'ch8subch12', 'ch8subch13'], '')),
        'after': _same(['ch8subch%d' % k for k in range(5, 14)], 'ch8'),
        'edits': [
            {
                'element': 'ch8subch5', 'confidence': 'confirmed', 'move': (66239, 84336),
                'wrong': 'Both tags are written too early. "Western Europe:" (ch8) closes after France, so Germany, Greece, '
                         'Iceland and Italy sit directly in "Europe:" (comp2).',
                'correction': 'Move the </div> at line 66239 to line 84336, immediately before </body>.',
                'evidence': 'The contents list prints Austria through Sweden in one list under "Western Europe" '
                            '(lines 8553-8682).',
                'evidence_lines': [(8553, 'Western Europe'), (8634, 'Netherlands'), (8674, 'Sweden')],
                'sweep_rows': 'ch8subch5',
            },
            {
                'element': 'ch8subch9', 'confidence': 'confirmed', 'move': (77930, 84336),
                'wrong': '"Europe:" (comp2) closes after Italy, so the Netherlands, Norway, Portugal, Spain and Sweden sit '
                         'at the root of <body>, outside every compilation.',
                'correction': 'Move the </div> at line 77930 to line 84336 as well.',
                'evidence': 'As above. One point is left to you: the contents list prints "Western Europe" beside '
                            '"Europe", where the file makes it a chapter of "Europe".',
                'evidence_lines': [],
                'sweep_rows': 'ch8subch9',
            },
        ],
    },
    {
        'volume': 'frus1955-57v13',
        'before': _same(['terms', 'persons'], 'sources'),
        'after': _same(['terms', 'persons'], ''),
        'edits': [{
            'element': 'sources', 'confidence': 'confirmed', 'move': (8915, 7411),
            'wrong': 'The Sources division does not close until the end of the front matter, so the List of Abbreviations '
                     '(terms) and the List of Persons (persons) sit inside it.',
            'correction': 'Move the </div> at line 8915 to line 7411, after the </list> that ends the sources and before '
                          'the two <pb/> that precede <div xml:id="terms">.',
            'evidence': 'The contents list prints List of Sources, List of Abbreviations and List of Persons at one level '
                        '(lines 7068-7071).',
            'evidence_lines': [(7068, 'List of Sources'), (7071, 'List of Persons')],
            'sweep_rows': 'sources',
        }],
    },
    {
        'volume': 'frus1964-68v06',
        'before': _same(['terms', 'persons', 'actionsstatement'], 'sources'),
        'after': _same(['terms', 'persons', 'actionsstatement'], ''),
        'edits': [{
            'element': 'sources', 'confidence': 'confirmed', 'move': (11160, 9808),
            'wrong': 'The Sources division does not close until the end of the front matter, so Abbreviations and Terms, '
                     'Names, and the Note on U.S. Covert Actions sit inside it.',
            'correction': 'Move the </div> at line 11160 to line 9808, after the </list> that ends the sources and before '
                          'the two <pb/> that precede <div xml:id="terms">.',
            'evidence': 'The contents list prints Sources XIII, Abbreviations and Terms XXV, Persons XXXI and Note on U.S. '
                        'Covert Actions XXXVII at one level (lines 9011-9014).',
            'evidence_lines': [(9011, 'Sources XIII'), (9012, 'Abbreviations and Terms XXV'), (9014, 'Note on U.S. Covert Actions')],
            'sweep_rows': 'sources',
        }],
    },
    {
        'volume': 'frus1868p1',
        'before': {'comp1': ''},
        'after': {'comp1': ''},
        'edits': [{
            'element': 'comp1', 'confidence': 'confirmed', 'retype': ('comp1', 'chapter', 'compilation'),
            'wrong': 'The root division "Correspondence." is typed chapter, though its id is comp1 and it holds ten chapters.',
            'correction': 'Change type="chapter" to type="compilation" on the div that opens at line 10663 (the attribute is on '
                          'line 10664). No tag moves.',
            'evidence': 'The same division of the companion volume, frus1868p2 comp1 "Correspondence.", is typed compilation.',
            'evidence_lines': [],
            'sweep_rows': 'comp1',
        }],
    },
    {
        'volume': 'frus1888p2',
        'before': {'ch12': 'ch11'},
        'after': {'ch12': 'comp25'},
        'edits': [{
            'element': 'ch12', 'confidence': 'question', 'move': (66900, 66446),
            'wrong': 'In Supplement A, the chapter "Appendix: British Official Publication. United States No. 4 (1888)." '
                     '(ch12) sits inside the chapter "Great Britain." (ch11).',
            'correction': 'If the appendix belongs to the supplement, move the </div> at line 66900 to line 66446, '
                          'immediately before <div xml:id="ch12">. If it belongs to "Great Britain.", it is a subchapter.',
            'evidence': 'Nothing in the file settles it: "Great Britain." is the supplement\'s only chapter. Please check '
                        'the printed volume.',
            'evidence_lines': [],
            'sweep_rows': 'ch12',
        }],
    },
    {
        'volume': 'frus1902app1',
        'before': _same(['ch1', 'ch2', 'ch3', 'ch4'], 's05'),
        'after': _same(['ch1', 'ch2', 'ch3', 'ch4'], 'comp6'),
        'edits': [{
            'element': 'ch1', 'confidence': 'question', 'move': (36690, 34449),
            'wrong': 'In the Counter memorandum (comp6), the four CASE chapters sit inside the historical-document section '
                     's05 instead of beside it.',
            'correction': 'Move the </div> at line 36690 to line 34449, immediately before <div xml:id="ch1">.',
            'evidence': 'The Rejoinder (comp7) and the Surrejoinder (comp8) of the same file place their four CASE chapters '
                        'beside the memorandum section. Please check the printed volume.',
            'evidence_lines': [],
            'sweep_rows': 'ch1',
        }],
    },
]


def structure(counts, rows, withdrawn):
    edits = volumes = 0
    by_confidence = collections.Counter()
    for entry in STRUCTURE:
        v = volume(entry['volume'])
        ET.fromstring(v.raw)  # the file is well-formed as it stands: the defect is not a syntax error
        for xml_id, parent in entry['before'].items():
            require(v.parent_id(xml_id) == parent,
                    '%s: %s is under %r, not %r' % (v.vid, xml_id, v.parent_id(xml_id), parent))
        repaired = v
        moves = [e['move'] for e in entry['edits'] if 'move' in e]
        if moves:
            repaired = move_close_tags(repaired, moves)
        for e in entry['edits']:
            if 'retype' in e:
                xml_id, old, new = e['retype']
                require(v.div(xml_id)['type'] == old, '%s: %s is not typed %s' % (v.vid, xml_id, old))
                repaired = retype_div(repaired, xml_id, new)
                require(repaired.div(xml_id)['type'] == new, '%s: retype did not take' % v.vid)
            for line, needle in e['evidence_lines']:
                require(needle in v.line_text(line), '%s line %d does not hold %r' % (v.vid, line, needle))
            heads = [re.sub(r'^Correspondence\. ', '', v.div(x)['head']) for x in e.get('alphabetical', [])]
            require(heads == sorted(heads), '%s: the compilations are not in alphabetical order' % v.vid)
        for xml_id, parent in entry['after'].items():
            require(repaired.parent_id(xml_id) == parent,
                    '%s: after the repair %s is under %r, not %r' % (v.vid, xml_id, repaired.parent_id(xml_id), parent))
        require(len(repaired.divs) == len(v.divs), '%s: the repair changed the div count' % v.vid)
        volumes += 1
        for e in entry['edits']:
            node = v.div(e['element'])
            edits += 1
            by_confidence[e['confidence']] += 1
            rows.append({
                'volume': v.vid, 'element': e['element'], 'file': v.name, 'line': node['line'],
                'byte_offset': node['off'], 'confidence': e['confidence'], 'what_is_wrong': e['wrong'],
                'correction': e['correction'], 'evidence': e['evidence'],
                'repair_simulated': 'yes: the file still parses and the stated nesting results',
                'hsg_url': HSG + v.vid + '/' + e['element'],
            })
    # Evidence stated in the rows above that is about another division or file, asserted here.
    require(volume('frus1868p2').div('comp1')['type'] == 'compilation' and volume('frus1868p2').div('comp1')['head'] == 'Correspondence.',
            'frus1868p2 comp1 is no longer a compilation headed Correspondence.')
    app = volume('frus1902app1')
    require(all(app.parent_id('ch%d' % k) == 'comp7' for k in range(5, 9))
            and all(app.parent_id('ch%d' % k) == 'comp8' for k in range(9, 13)),
            'frus1902app1: the CASE chapters of comp7 and comp8 are no longer beside their sections')
    require([n['id'] for n in volume('frus1888p2').children('comp25')] == ['ch11'], 'frus1888p2: comp25 holds more than ch11')
    require([n['id'] for n in volume('frus1945Berlinv02').children('comp2')] == ['ch%d' % k for k in range(2, 19) if k != 10],
            'frus1945Berlinv02: comp2 no longer holds one chapter per day but July 24')
    require(len(volume('frus1943CairoTehran').children('ch12subch5')) == 7, 'frus1943CairoTehran: December 6 no longer holds seven sessions')
    berlin = volume('frus1945Berlinv02')
    nested = [d['id'] for d in berlin.divs if d['type'] == 'document' and d['parent'] is not None and d['parent']['type'] == 'document']
    require(nested == ['d710a-83'], 'frus1945Berlinv02: the documents inside documents are now %s' % nested)
    require('Seventh plenary meeting' in berlin.line_text(15195), 'frus1945Berlinv02: line 15195 moved')
    chapters = [n['type'] for n in volume('frus1868p1').children('comp1')]
    require(chapters == ['chapter'] * 10, 'frus1868p1: comp1 no longer holds ten chapters')

    # Sweep rows this report withdraws, each with the reason re-checked.
    v = volume('frus1866p2')
    note = v.raw.split(b'\n')[47403:47406]
    require(b'nested correctly here' in b' '.join(note), 'frus1866p2: the editors\' comment before ch17 is gone')
    require(v.parent_id('ch17') == 'ch16', 'frus1866p2: ch17 is no longer inside ch16')
    withdrawn.append(('frus1866p2', 'ch17', 'The editors\' own comment at lines 47404-47406 says the nesting is deliberate: '
                      '"tagged as a chapter, but is technically a subchapter of the Chili chapter. It is nested correctly '
                      'here, but we\'ve not changed the type or xml:id to prevent the URL from changing."'))
    v = volume('frus1868p2')
    legations = [d for d in v.divs if re.search(r'legation', d['head'], re.I) and d['type'] in ('chapter', 'subchapter')]
    inside = [d for d in legations if d['parent'] is not None and d['parent']['type'] == 'chapter']
    require(len(legations) == len(inside) and len(legations) >= 8, 'frus1868p2: a legation is not inside its country')
    withdrawn.append(('frus1868p2', 'ch33', 'All %d legations of this volume are nested inside their countries; ch33 '
                      '"Peruvian legation." differs only in being typed chapter, the case the frus1866p2 comment says is '
                      'left alone to keep the URL.' % len(legations)))
    v = volume('frus1945v01')
    require(v.parent_id('persons') == 'ch1', 'frus1945v01: persons is no longer inside ch1')
    require('Introductory Note by the Editor 1' in v.line_text(12011) and 'Chapter I: January 1' in v.line_text(12014),
            'frus1945v01: the contents lines moved')
    pages = [p['n'] for p in v.pbs if v.div('ch1')['off'] <= p['off'] <= v.div('ch1')['close_off'] and p['n']]
    require('5' in pages and '9' in pages, 'frus1945v01: ch1 no longer spans pp. 5-9')
    withdrawn.append(('frus1945v01', 'persons', 'The nesting matches the book: the contents list gives the Introductory '
                      'Note pp. 1-9 and Chapter I from p. 10, and the list of persons begins on p. 5, inside the note.'))
    counts['structure'] = {
        'edits': edits, 'volumes': volumes, 'confirmed': by_confidence['confirmed'],
        'questions': by_confidence['question'],
        'confirmedVolumes': len({r['volume'] for r in rows if r['confidence'] == 'confirmed'}),
        'questionVolumes': len({r['volume'] for r in rows if r['confidence'] == 'question'}),
        'sweepRowsWithdrawn': len(withdrawn),
    }


# ---------------------------------------------------------------------------------------------
# Sources lists: a repository nested inside another repository's list (scan)
# ---------------------------------------------------------------------------------------------

_NEVER_HELD = re.compile(r'^(Central Intelligence Agency\b|Library of Congress\b'
                         r'|National Archives and Records Administration\b|Department of State(, Washington.*)?$)')
_HOLDER = re.compile(r'^(Central Intelligence Agency|Library of Congress|Department of State|Department of Defense'
                     r'|National Security Council|Washington National Records Center'
                     r'|National Archives and Records Administration|[A-Z][A-Za-z. ]+ Library)\b')


def sources_lists(counts, rows):
    divisions = 0
    for name in volume_files():
        v = volume(name[:-4])
        for d in v.divs:
            if d['subtype'] != 'sources':
                continue
            divisions += 1
            body = v.blanked[d['off']:d['close_off']]
            stack = []
            for m in re.finditer(rb'<item\b[^>]*>|</item>', body):
                if m.group(0).startswith(b'</'):
                    if stack:
                        stack.pop()
                    continue
                lead = body[m.end():m.end() + 400]
                cut = re.search(rb'<list\b|</item>', lead)
                text = plain(lead[:cut.start()] if cut else lead)[:90]
                bold = lead.lstrip().startswith(b'<hi')
                holders = [s for s in stack if s[1] and _HOLDER.match(s[0])]
                if bold and holders and _NEVER_HELD.match(text) and not text.startswith(holders[-1][0][:20]):
                    rows.append({
                        'volume': v.vid, 'file': v.name, 'line': v.line(d['off'] + m.start()),
                        'nested_heading': text, 'inside_heading': holders[-1][0], 'confidence': 'question',
                        'correction': 'Close the list of "%s" before this item, if the printed list sets the two '
                                      'headings at one level.' % holders[-1][0][:60],
                    })
                stack.append((text, bold))
    require(divisions > 0 and rows, 'the Sources-list scan read nothing')
    counts['sourcesLists'] = {'divisionsRead': divisions, 'rows': len(rows),
                              'volumes': len({r['volume'] for r in rows})}


# ---------------------------------------------------------------------------------------------
# P. Pagination (scans)
# ---------------------------------------------------------------------------------------------

def _num(value):
    return int(value) if value and value.isdigit() else None


_ROMAN = (('M', 1000), ('CM', 900), ('D', 500), ('CD', 400), ('C', 100), ('XC', 90), ('L', 50), ('XL', 40),
          ('X', 10), ('IX', 9), ('V', 5), ('IV', 4), ('I', 1))


def _to_roman(number):
    out = ''
    for glyph, value in _ROMAN:
        while number >= value:
            out += glyph
            number -= value
    return out


def _from_roman(text):
    """The value of a well-formed Roman numeral, else None."""
    if not text or not re.fullmatch(r'M{0,3}(CM|CD|D?C{0,3})(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})', text):
        return None
    total, rest = 0, text
    for glyph, value in _ROMAN:
        while rest.startswith(glyph):
            total += value
            rest = rest[len(glyph):]
    return total


_SPELLED = {3: 'three', 4: 'four'}


def _surface(v, xml_id):
    """' and <surface start="#ID"> at line N' when the facsimile repeats a page id, else ''."""
    m = re.search(rb'<surface\b[^>]*\bstart="#' + re.escape(xml_id.encode()) + rb'"', v.blanked)
    return ', and <surface start="#%s"> at line %d with it' % (xml_id, v.line(m.start())) if m else ''


def pagination(counts, rows):
    c = collections.Counter()
    vols = collections.defaultdict(set)
    files = missing_pages = 0
    reversed_notes = collections.Counter()
    reversed_between = []

    def add(kind, v, pb, wrong, correction, confidence, document=''):
        c[kind] += 1
        vols[kind].add(v.vid)
        rows.append({
            'class': kind, 'volume': v.vid, 'file': v.name, 'line': pb['line'], 'document': document,
            'pb_n': pb['n'] if pb['n'] is not None else '', 'pb_xml_id': pb['id'] or '', 'pb_facs': pb['facs'] or '',
            'what_is_wrong': wrong, 'correction': correction, 'confidence': confidence,
        })

    for name in volume_files():
        v = volume(name[:-4])
        pbs = v.pbs
        if not pbs:
            continue
        files += 1
        ids = v.ids()
        fiche = 'mSupp' in v.vid
        facs_lengths = collections.Counter(len(p['facs']) for p in pbs if p['facs'] and p['facs'].isdigit())
        usual = facs_lengths.most_common(1)[0][0] if facs_lengths else None
        seen_facs = {}
        for k, p in enumerate(pbs):
            prev = pbs[k - 1] if k else None
            nxt = pbs[k + 1] if k + 1 < len(pbs) else None
            n, i, facs = p['n'] or '', p['id'] or '', p['facs'] or ''
            doc = v.enclosing_div(p['off'], 'document')
            doc_id = doc['id'] if doc else ''

            # (1) two divisions in reverse page order. The rule compares two page breaks that follow one
            # another, so the divisions holding them need not: one with no break of its own may stand between.
            if (prev and not fiche and _num(n) is not None and _num(prev['n']) is not None
                    and _num(facs) is not None and _num(prev['facs']) is not None
                    and _num(n) < _num(prev['n']) and _num(facs) < _num(prev['facs'])):
                before = v.enclosing_div(prev['off'], 'document')
                reversed_notes['second'] += 1 if doc and doc['subtype'] == 'editorial-note' else 0
                reversed_notes['both'] += 1 if (doc and before and doc['subtype'] == before['subtype'] == 'editorial-note') else 0
                between = [d['id'] for d in v.divs if d['type'] == 'document' and before and doc
                           and before['close_off'] < d['off'] and d['close_off'] < doc['off']]
                reversed_notes['between'] += 1 if between else 0
                if between:
                    reversed_between.append('%s: %s, then %s, then %s' % (v.vid, before['id'], ' and '.join(between), doc_id))
                add('reversed-pair', v, p,
                    'Page %s (image %s) follows page %s (image %s) in the file: %s, which holds the later page, is '
                    'written before %s, which holds the earlier one.%s'
                    % (n, facs, prev['n'], prev['facs'], before['id'] if before else '?', doc_id or '?',
                       ' Between them stands %s, which holds no page break: the images must say on which side '
                       'of the pair it belongs.' % ' and '.join(between) if between else ''),
                    'Put the %s divisions back in page order (the text as well as the breaks), after checking the images.'
                    % ('two' if not between else _SPELLED.get(len(between) + 2, str(len(between) + 2))),
                    'confirmed', doc_id)
            # (2) the numbers run backwards while the images run forwards
            elif (prev and not fiche and _num(n) is not None and _num(prev['n']) is not None
                  and _num(facs) is not None and _num(prev['facs']) is not None
                  and _num(n) < _num(prev['n']) and _num(facs) > _num(prev['facs'])
                  and i.startswith('pg_') and (prev['id'] or '').startswith('pg_')):
                run = [q for q in pbs[max(0, k - 3):k + 2]]
                add('numbers-out-of-order', v, p,
                    'The images run forward but the page numbers do not: %s.'
                    % ', '.join('%s (image %s)' % (q['n'], q['facs']) for q in run),
                    'Renumber @n and xml:id so that they rise with the images.', 'confirmed', doc_id)

            # (3) @n and xml:id name different pages
            if _num(n) is not None and re.fullmatch(r'pg_\d+', i) and int(i[3:]) != _num(n):
                add('id-disagrees-with-n', v, p,
                    'xml:id says page %s and @n says page %s; the break before it is %s and the one after is %s.'
                    % (i[3:], n, prev['n'] if prev else '?', nxt['n'] if nxt else '?'),
                    'Set n="%s", or n="%s [%s]" if the folio is misprinted in the book.' % (i[3:], n, i[3:]),
                    'confirmed', doc_id)

            # (4) no break at all for one or more pages whose images exist
            if (nxt and re.fullmatch(r'pg_\d+', i) and re.fullmatch(r'pg_\d+', nxt['id'] or '')
                    and _num(facs) is not None and _num(nxt['facs']) is not None):
                a, b = int(i[3:]), int(nxt['id'][3:])
                if 2 <= b - a <= 8 and _num(nxt['facs']) - _num(facs) == b - a:
                    missing = [q for q in range(a + 1, b) if 'pg_%d' % q not in ids]
                    if len(missing) == b - a - 1:
                        width = len(facs)
                        missing_pages += len(missing)
                        add('missing-break', v, p,
                            'No <pb/> for page%s %s: the break after p. %d (image %s) is p. %d (image %s), %d lines on.'
                            % ('s' if len(missing) > 1 else '', ', '.join(map(str, missing)), a, facs, b, nxt['facs'],
                               nxt['line'] - p['line']),
                            'Insert %s, placed from the image%s.%s'
                            % (' and '.join('<pb facs="%s" n="%d" xml:id="pg_%d"/>'
                                            % (str(_num(facs) + q - a).zfill(width), q, q) for q in missing),
                               's' if len(missing) > 1 else '',
                               '' if len(missing) == 1 else ' Check first whether the pages are blank or their text is missing too.'),
                            'confirmed' if len(missing) == 1 else 'question', doc_id)

            # (5) malformed page ids
            if i and re.fullmatch(r'p[a-z]*g[-_]?\d+', i) and not re.fullmatch(r'pg_\d+', i) and not i.startswith('pg-seq'):
                add('malformed-id', v, p,
                    'The page id is %s where the corpus writes pg_%s; no pg_%s anchor exists.' % (i, n.strip('[]'), n.strip('[]')),
                    'Rename it to xml:id="pg_%s"%s.' % (n.strip('[]'), _surface(v, i)), 'confirmed', doc_id)
            if (re.fullmatch(r'pg-seq-\d+', i) and _num(n) is not None and prev and nxt
                    and (prev['id'] or '') == 'pg_%d' % (_num(n) - 1) and (nxt['id'] or '') == 'pg_%d' % (_num(n) + 1)):
                add('malformed-id', v, p,
                    'Page %s, between pg_%d and pg_%d, carries the id %s, the form used for unnumbered pages; no pg_%s '
                    'anchor exists.' % (n, _num(n) - 1, _num(n) + 1, i, n),
                    'Rename it to xml:id="pg_%s"%s.' % (n, _surface(v, i)), 'confirmed', doc_id)
            if i and re.fullmatch(r'[IVXLC]+', i) and not fiche:
                if _from_roman(i) is not None:
                    add('malformed-id', v, p,
                        'The page id is %s, without the pg_ prefix every other page id has; no pg_%s anchor exists.' % (i, i),
                        'Rename it to xml:id="pg_%s"%s.' % (i, _surface(v, i)), 'confirmed', doc_id)
                else:
                    before = _from_roman(prev['n']) if prev else None
                    likely = _to_roman(before + 1) if before else '?'
                    add('malformed-id', v, p,
                        'The page id and @n are both %s, which is not a Roman numeral, and the id lacks the pg_ prefix. '
                        'The break before it is %s and the one after is %s.' % (i, prev['n'] if prev else '?', nxt['n'] if nxt else '?'),
                        'Probably n="%s" xml:id="pg_%s"%s; check the image.' % (likely, likely, _surface(v, i)),
                        'confirmed', doc_id)

            # (6) @facs names the wrong image
            if facs:
                if facs in seen_facs:
                    first = seen_facs[facs]
                    suggestion = ''
                    for cand in (p, first):
                        ck = pbs.index(cand)
                        left = pbs[ck - 1] if ck else None
                        right = pbs[ck + 1] if ck + 1 < len(pbs) else None
                        own = re.sub(r'^pg_', '', cand['id'] or '')
                        if (left and right and _num(left['facs']) is not None and _num(right['facs']) is not None
                                and _num(right['facs']) - _num(left['facs']) == 2 and _num(facs) != _num(left['facs']) + 1):
                            suggestion = 'On the break at line %d (n="%s"), set facs="%s".' % (
                                cand['line'], cand['n'], str(_num(left['facs']) + 1).zfill(len(facs)))
                        elif not facs.isdigit() and own and own != facs:
                            suggestion = 'On the break at line %d (xml:id="%s"), set facs="%s", as its own id says.' % (
                                cand['line'], cand['id'], own)
                    add('wrong-facs', v, p,
                        'Two breaks name image %s: n="%s" at line %d and n="%s" here; the break after this one is n="%s" '
                        '(image %s).' % (facs, first['n'], first['line'], n, nxt['n'] if nxt else '', nxt['facs'] if nxt else ''),
                        suggestion or 'Check both against the images.', 'confirmed' if suggestion else 'question', doc_id)
                else:
                    seen_facs[facs] = p
                if facs.isdigit() and usual and len(facs) != usual:
                    add('wrong-facs', v, p,
                        'facs="%s" has %d digits where the volume\'s image names have %d; no such image exists.'
                        % (facs, len(facs), usual),
                        'Set facs="%s".' % (str(_num(prev['facs']) + 1).zfill(usual)
                                           if prev and _num(prev['facs']) is not None else facs.zfill(usual)),
                        'confirmed', doc_id)

        padded = [p for p in pbs if re.fullmatch(r'pg_0\d+', p['id'] or '')]
        if padded:
            add('zero-padded-ids', v, padded[0],
                '%d page ids are zero-padded (%s to %s) where the rest of the volume, and every other volume, writes pg_N.'
                % (len(padded), padded[0]['id'], padded[-1]['id']),
                'Optional: rename them pg_1 to pg_%d and update the references to them.' % len(padded), 'question')
            counts.setdefault('paginationDetail', {})['zeroPaddedIds'] = len(padded)
    require(files > 0 and rows, 'the pagination scan read nothing')
    for kind in ('reversed-pair', 'missing-break', 'malformed-id', 'wrong-facs', 'id-disagrees-with-n',
                 'numbers-out-of-order'):
        require(c[kind] > 0, 'the pagination scan found no %s' % kind)
    counts['pagination'] = {'filesRead': files, 'rows': len(rows),
                            'byClass': {k: {'rows': c[k], 'volumes': len(vols[k])} for k in sorted(c)}}
    counts['pagination']['missingPages'] = missing_pages
    counts['pagination']['reversedPairsSecondIsEditorialNote'] = reversed_notes['second']
    counts['pagination']['reversedPairsBothEditorialNotes'] = reversed_notes['both']
    counts['pagination']['reversedPairsWithADivisionBetween'] = reversed_notes['between']
    counts['pagination']['reversedPairsAdjacent'] = c['reversed-pair'] - reversed_notes['between']
    counts['pagination']['reversedPairsWithADivisionBetweenWhere'] = reversed_between


def parts(counts, rows):
    """Volumes published in parts that share one pagination: a gap or an overlap between two parts."""
    names = [f[:-4] for f in volume_files()]
    continuous, gaps = 0, []
    for vid in names:
        m = re.fullmatch(r'(.*p)(\d+)', vid)
        following = m.group(1) + str(int(m.group(2)) + 1) if m else None
        if following not in names:
            continue
        a, b = volume(vid), volume(following)
        pages_a = [p for p in a.pbs if re.fullmatch(r'pg_\d+', p['id'] or '')]
        pages_b = [p for p in b.pbs if re.fullmatch(r'pg_\d+', p['id'] or '')]
        if not pages_a or not pages_b or min(int(p['id'][3:]) for p in pages_b) <= 10:
            continue  # each part has its own pagination
        continuous += 1
        last, first = max(int(p['id'][3:]) for p in pages_a), min(int(p['id'][3:]) for p in pages_b)
        if first - last > 3:
            gaps.append({'volume': vid, 'lastPage': last, 'nextPartFirstPage': first})
        shared = [p for p in pages_a if int(p['id'][3:]) >= first]
        if shared:
            inside = [p for p in shared if a.enclosing_div(p['off']) is not None]
            rows.append({
                'class': 'numbered-as-next-part', 'volume': a.vid, 'file': a.name, 'line': shared[0]['line'], 'document': '',
                'pb_n': shared[0]['n'], 'pb_xml_id': shared[0]['id'], 'pb_facs': shared[0]['facs'] or '',
                'what_is_wrong': '%d page breaks at the end of this part (pp. %s-%s, lines %d-%d, %s) carry numbers and '
                                 'ids that belong to pages of %s, which begins at p. %d.'
                                 % (len(shared), shared[0]['n'], shared[-1]['n'], shared[0]['line'], shared[-1]['line'],
                                    'outside every division' if not inside else 'some inside a division', b.vid, first),
                'correction': 'If these are the part\'s unnumbered end leaves, give them pg-seq ids and n=""; otherwise '
                              'remove them.',
                'confidence': 'question',
            })
    require(continuous > 0, 'no volume in parts was read')
    require([g['volume'] for g in gaps] == ['frus1952-54v09p1'], 'the part gaps are now %s' % gaps)
    overlaps = [r for r in rows if r['class'] == 'numbered-as-next-part']
    counts['parts'] = {'continuousPairs': continuous, 'gaps': gaps, 'overlaps': [r['volume'] for r in overlaps]}
    counts['pagination']['rows'] = len(rows)
    counts['pagination']['volumes'] = len({r['volume'] for r in rows})
    counts['pagination']['byClass']['numbered-as-next-part'] = {'rows': len(overlaps),
                                                                'volumes': len({r['volume'] for r in overlaps})}


# ---------------------------------------------------------------------------------------------
# X. Cross-references: the generator's CSV, re-checked row by row and grouped by cause
# ---------------------------------------------------------------------------------------------

# (source volume, byte offset) -> (cause, suggested target, confidence, note). Every suggested target is checked to exist.
XREF = {
    ('frus1875v02', 5068833): ('wrong-volume', 'frus1875v01#pg_678', 'confirmed',
                               'The index serves both volumes; p. 678 is in Volume I.'),
    ('frus1890', 4361423): ('wrong-volume', 'frus1873p1v2#pg_1206', 'confirmed',
                            'No frus1873p2v2 exists. The passage quoted is on p. 1208 of frus1873p1v2.'),
    ('frus1890', 4361540): ('wrong-volume', 'frus1873p1v2#pg_1208', 'confirmed',
                            'The sentence quoted ("equal security over every sea") is on this page.'),
    ('frus1901', 3951029): ('wrong-volume', 'frus1887#pg_1077', 'confirmed',
                            'The text cites Foreign Relations, 1887; the target names 1877.'),
    ('frus1901', 3951165): ('wrong-volume', 'frus1887#pg_1078', 'confirmed',
                            'The text cites Foreign Relations, 1887; the target names 1877.'),
    ('frus1904', 3042487): ('wrong-volume', 'frus1873p1v2#pg_1191', 'confirmed',
                            'The sentence quoted ("to all intents and purposes aliens") is on this page.'),
    ('frus1909', 3008450): ('wrong-volume', 'frus1907p2#pg_708', 'confirmed', 'Part 1 ends at p. 587.'),
    ('frus1909', 4534188): ('wrong-volume', 'frus1907p2#pg_840', 'confirmed', 'Part 1 ends at p. 587.'),
    ('frus1909', 4555068): ('wrong-volume', 'frus1907p2#pg_840', 'confirmed', 'Part 1 ends at p. 587.'),
    ('frus1910', 5421745): ('wrong-volume', 'frus1907p2#pg_773', 'confirmed', 'Part 1 ends at p. 587.'),
    ('frus1910', 6529743): ('wrong-volume', 'frus1907p2#pg_1058', 'confirmed', 'Part 1 ends at p. 587.'),
    ('frus1913', 5119370): ('wrong-volume', 'frus1906p2#pg_1432', 'confirmed', 'Part 1 ends at p. 868.'),
    ('frus1913', 10468909): ('wrong-volume', 'frus1888p2#pg_1544', 'confirmed', 'No frus1888 exists; p. 1544 is in Part 2.'),
    ('frus1914-20v02', 1167863): ('wrong-volume', 'frus1918Supp01v01#pg_805', 'confirmed',
                                  'Ibid. follows a citation of Foreign Relations, 1918, supp. 1, vol. I; telegram 1635 is on this page.'),
    ('frus1923v01', 2058302): ('wrong-volume', 'frus1907p2#pg_1239', 'confirmed',
                               'The text reads "pt. 1", which ends at p. 587; the Hague convention cited is on p. 1239 of Part 2.'),
    ('frus1923v02', 5648987): ('wrong-volume', 'frus1873p1v2#pg_1100', 'question',
                               'frus1873p2v3 ends at p. 424. In the other two citations of "1873, part 2" the page is in frus1873p1v2.'),
    ('frus1928v02', 5991397): ('wrong-volume', 'frus1907p1#pg_548', 'confirmed',
                               'Part 2 begins at p. 589; the Borneo correspondence cited is on p. 548 of Part 1.'),
    ('frus1946v08', 4549612): ('wrong-volume', 'frus1945v06#pg_1158', 'confirmed',
                               'The text reads 1946, vol. VI, which ends at p. 993; the Netherlands East Indies compilation '
                               'the note calls "previous documentation" begins on p. 1158 of 1945, vol. VI.'),
    ('frus1958-60v05', 4232610): ('wrong-volume', 'frus1958-60v05#d302', 'confirmed',
                                  'Document 302 is this volume\'s own editorial note on the microfiche supplement, which has no d302.'),
    ('frus1958-60v05', 4233867): ('wrong-volume', 'frus1958-60v05#d302', 'confirmed',
                                  'Document 302 is this volume\'s own editorial note on the microfiche supplement, which has no d302.'),
    ('frus1981-88v01', 7803861): ('wrong-volume', 'frus1969-76v40#d17', 'confirmed',
                                  'The text cites Foreign Relations, 1969-1976, vol. XL; the target names 1981-88.'),
    ('frus1981-88v11', 6124771): ('wrong-volume', 'frus1969-76v32#d316', 'confirmed',
                                  'The text cites Foreign Relations, 1969-1976, vol. XXXII; the target names 1981-88.'),
    ('frus1872p2v3', 3509089): ('page-number-typo', '', 'question', 'The volume ends at p. 654; the table\'s neighbours are 397 and 418.'),
    ('frus1880', 8183102): ('page-number-typo', 'frus1880#pg_977', 'question',
                            'The range reads 974-1177 and the volume ends at p. 1091; the Kummeran case ends on p. 977.'),
    ('frus1895p2', 5681149): ('page-number-typo', 'frus1895p2#pg_1034', 'question', 'The range reads 1025-10346.'),
    ('frus1913', 10820480): ('page-number-typo', 'frus1913#pg_1413', 'question', 'The range reads 1375-3413; the volume ends at p. 1444.'),
    ('frus1917Supp02v02', 3790644): ('page-number-typo', 'frus1917Supp02v02#pg_1158', 'question', 'The range reads 1154-1518; the volume ends at p. 1323.'),
    ('frus1919Parisv07', 5019474): ('page-number-typo', 'frus1919Parisv07#pg_592', 'question', 'The range reads 590-5921.'),
    ('frus1933v03', 4809317): ('page-number-typo', 'frus1933v03#pg_378', 'question', 'The range reads 377-878; the volume ends at p. 794.'),
    ('frus1933v03', 4977797): ('page-number-typo', 'frus1933v03#pg_371', 'question', 'The range reads 370-871; the volume ends at p. 794.'),
    ('frus1937v04', 5275865): ('page-number-typo', 'frus1937v04#pg_820', 'question', 'The run reads 819-920, 821, 822; the volume ends at p. 911.'),
    ('frus1944v03', 9081272): ('page-number-typo', 'frus1944v03#pg_1276', 'question', 'The range reads 1275-4276.'),
    ('frus1944v04', 8212392): ('page-number-typo', 'frus1944v04#pg_1227', 'question', 'The range reads 1226-12227.'),
    ('frus1952-54v13p2', 6958898): ('page-number-typo', 'frus1952-54v13p2#pg_2262', 'question', 'The range reads 2261-2662; the volume ends at p. 2497.'),
    ('frus1952-54v15p2', 6589176): ('page-number-typo', 'frus1952-54v15p2#pg_1241', 'question', 'The range reads 1240-2141; the volume ends at p. 1997.'),
    ('frus1955-57v21', 6157238): ('page-number-typo', 'frus1955-57v21#pg_1033', 'question', 'The range reads 1032-3033; the volume ends at p. 1102.'),
    ('frus1918', 7309936): ('letter-case', 'frus1918#pg_XVIII', 'confirmed', 'The id is pg_XVIII; the target writes pg_xviii.'),
    ('frus1913', 8941679): ('page-beyond-volume', 'frus1887#pg_1076', 'question',
                            'frus1897 ends at p. 610. Bayard to Kloss, on the protection of Swiss citizens, is on p. 1076 of 1887.'),
    ('frus1928v02', 5928518): ('page-beyond-volume', '', 'question', 'frus1910 ends at p. 884; the instruction cited is dated 1912.'),
    ('frus1939v04', 2838795): ('page-beyond-volume', '', 'question', 'frus1938v04 ends at p. 638.'),
    ('frus1951v02', 8117828): ('page-beyond-volume', '', 'question', 'frus1950v01 ends at p. 952.'),
    ('frus1951v03p2', 5418206): ('missing-hash', 'frus1951v03p2#pg_1602', 'confirmed', 'target="pg_1602" lacks the #.'),
    ('frus1952-54v09p2', 5528880): ('missing-hash', 'frus1952-54v09p2#pg_1743', 'confirmed', 'target="pg_1743" lacks the #.'),
    ('frus1952-54v09p2', 6481433): ('missing-hash', 'frus1952-54v09p2#pg_1743', 'confirmed', 'target="pg_1743" lacks the #.'),
}

# The last (or first) arabic page each note above states, re-read from the file on every run.
LAST_PAGES = {'frus1907p1': 587, 'frus1906p1': 868, 'frus1873p2v3': 424, 'frus1897': 610, 'frus1910': 884,
              'frus1938v04': 638, 'frus1950v01': 952, 'frus1872p2v3': 654, 'frus1880': 1091, 'frus1913': 1444,
              'frus1917Supp02v02': 1323, 'frus1933v03': 794, 'frus1937v04': 911, 'frus1952-54v13p2': 2497,
              'frus1952-54v15p2': 1997, 'frus1955-57v21': 1102, 'frus1946v06': 993}
FIRST_PAGES = {'frus1907p2': 589}

_REF = re.compile(rb'<ref\b[^>]*?\btarget\s*=\s*"([^"]*)"', re.S)


def _candidates(anchor):
    """CrossRefKit.RefClassification.anchorCandidates, transcribed."""
    out = [anchor]
    m = re.fullmatch(r'(d\d+[A-Za-z]?)fn\d+', anchor)
    if m and m.group(1) != anchor:
        out.append(m.group(1))
    low = anchor.lower()
    if low.startswith('pg') or low.startswith('page'):
        digits = re.sub(r'^\D+', '', anchor)
        if digits and digits.isdigit() and 'pg_' + digits != anchor:
            out.append('pg_' + digits)
    return out


def cross_references(counts, rows, xref_csv, manifest_path):
    files = set(volume_files())
    source = list(csv.DictReader(open(xref_csv, newline='', encoding='utf-8')))
    require(len(source) > 0, 'the broken-reference CSV is empty')
    manifest = {e['filename'][:-4] for e in json.load(open(manifest_path, encoding='utf-8'))}
    ids = {}

    def id_set(vid):
        if vid not in ids:
            ids[vid] = volume(vid).ids() if vid + '.xml' in files else None
        return ids[vid]

    def stub(vid):
        return vid + '.xml' in files and not any(d['type'] == 'document' for d in volume(vid).divs) and not volume(vid).pbs

    for vid, page in list(LAST_PAGES.items()) + list(FIRST_PAGES.items()):
        numbers = [int(p['n']) for p in volume(vid).pbs if p['n'] and p['n'].isdigit()]
        found = max(numbers) if vid in LAST_PAGES else min(numbers)
        require(found == page, '%s: the page the notes state is %d, the file says %d' % (vid, page, found))

    by_cause = collections.Counter()
    used = set()
    for r in source:
        v = volume(r['source_volume'])
        offset = int(r['byte_offset'])
        m = _REF.match(v.blanked, offset)
        require(m is not None and r['raw_target'] in m.group(1).decode().split(),
                '%s byte %d no longer holds <ref target="%s">' % (v.vid, offset, r['raw_target']))
        target_ids = id_set(r['resolved_volume'])
        require(target_ids is None or not any(c in target_ids for c in _candidates(r['resolved_anchor']))
                or r['reason'] == 'malformedTarget',
                '%s byte %d: %s now resolves' % (v.vid, offset, r['raw_target']))
        key = (r['source_volume'], offset)
        cause, suggested, confidence, note = '', '', '', ''
        if (r['source_volume'] == 'frus1952-54v09p2' and r['resolved_volume'] == 'frus1952-54v09p1'
                and r['reason'] == 'unknownPage'):
            cause, confidence = 'target-in-missing-pages', 'confirmed'
            note = 'Resolves once Documents 900-946 are restored to frus1952-54v09p1.'
        elif r['reason'] == 'unknownAnchor' and re.fullmatch(r'in\d+', r['resolved_anchor']):
            cause, confidence = 'index-id-never-assigned', 'confirmed'
            note = 'An index "See" reference to an entry id the index does not carry.'
        elif key in XREF:
            cause, suggested, confidence, note = XREF[key]
            used.add(key)
        elif stub(r['resolved_volume']):
            cause, confidence = 'not-a-defect-forward-reference', 'not-a-defect'
            note = 'The target volume is not yet digitized: its file holds no documents and no pages.'
        require(cause, 'no cause adjudicated for %s byte %d (%s)' % (v.vid, offset, r['raw_target']))
        if suggested:
            tv, anchor = suggested.split('#')
            require(id_set(tv) is not None and anchor in id_set(tv), 'suggested target %s does not exist' % suggested)
        by_cause[cause] += 1
        end = v.raw.find(b'</ref>', offset)
        rows.append({
            'cause': cause, 'confidence': confidence, 'source_volume': r['source_volume'],
            'source_document': r['source_document'], 'file': r['source_filename'], 'line': r['line'],
            'byte_offset': r['byte_offset'], 'target': r['raw_target'], 'printed_reference': plain(v.raw[offset:end + 6])[:120],
            'suggested_target': suggested, 'note': note,
        })
    require(used == set(XREF), 'adjudicated rows not in the CSV: %s' % sorted(set(XREF) - used))

    # An independent scan of every file, by the same rule, to compare with the generator's rows.
    whole = [f[:-4] for f in files]
    mine, worked_around, scanned = set(), [], 0
    for vid in sorted(whole):
        v = volume(vid)
        own = id_set(vid)
        for m in _REF.finditer(v.blanked):
            for t in m.group(1).decode('utf-8', 'replace').split():
                scanned += 1
                if t.startswith(('http://', 'https://', 'mailto:')):
                    continue
                if '#' not in t:
                    if t + '.xml' not in files:
                        mine.add((vid, m.start(), t))
                    continue
                tv, anchor = t.split('#', 1)
                tv = tv or vid
                if not anchor:
                    continue
                target = id_set(tv)
                if target is None:
                    mine.add((vid, m.start(), t))
                    continue
                cands = _candidates(anchor)
                if not any(c in target for c in cands):
                    mine.add((vid, m.start(), t))
                elif anchor not in target and cands[0] == anchor and re.fullmatch(r'(pg|page)\d+', anchor):
                    worked_around.append((vid, m.start(), t, [c for c in cands if c in target][0]))
    theirs = {(r['source_volume'], int(r['byte_offset']), r['raw_target']) for r in source}
    require(theirs <= mine, 'rows in the CSV the independent scan resolves: %s' % sorted(theirs - mine)[:5])
    extra = sorted(mine - theirs)
    # The generator reports the app's shippable volumes: a reference made in, or into, a file outside the
    # manifest is tallied there, not listed. Anything else the independent scan finds beyond the CSV is a failure.
    not_shipped = [e for e in extra if e[0] not in manifest
                   or ((e[2].split('#')[0] or e[0]) + '.xml' in files and (e[2].split('#')[0] or e[0]) not in manifest)]
    for vid, offset, t, canonical in worked_around:
        v = volume(vid)
        end = v.raw.find(b'</ref>', offset)
        by_cause['missing-underscore'] += 1
        rows.append({
            'cause': 'missing-underscore', 'confidence': 'confirmed', 'source_volume': vid,
            'source_document': (v.enclosing_div(offset, 'document') or {'id': ''})['id'], 'file': v.name,
            'line': v.line(offset), 'byte_offset': offset, 'target': t,
            'printed_reference': plain(v.raw[offset:end + 6])[:120], 'suggested_target': vid + '#' + canonical,
            'note': 'The underscore is missing. FRUS Explorer reads pgN as pg_N, so the link works there.',
        })
    defects = sum(n for k, n in by_cause.items() if not k.startswith('not-a-defect'))
    counts['crossReferences'] = {
        'generatorRows': len(source), 'refTargetsScanned': scanned, 'byCause': dict(sorted(by_cause.items())),
        'defects': defects, 'notDefects': by_cause['not-a-defect-forward-reference'],
        'gapRows': by_cause['target-in-missing-pages'],
        'gapDistinctPages': len({r['target'] for r in rows if r['cause'] == 'target-in-missing-pages'}),
        'indexIdRows': by_cause['index-id-never-assigned'],
        'indexIdDistinctTargets': len({(r['source_volume'], r['target']) for r in rows if r['cause'] == 'index-id-never-assigned'}),
        'indexIdByVolume': dict(collections.Counter(r['source_volume'] for r in rows if r['cause'] == 'index-id-never-assigned')),
        'indexIdDistinctByVolume': dict(collections.Counter(
            v for v, _ in {(r['source_volume'], r['target']) for r in rows if r['cause'] == 'index-id-never-assigned'})),
        'independentScanBroken': len(mine), 'independentScanBeyondCSV': len(extra),
        'independentScanBeyondCSVNotShipped': len(not_shipped),
        'confirmedWithTarget': sum(1 for r in rows if r['suggested_target'] and r['confidence'] == 'confirmed'),
        'pageNumberTyposWithALikelyPage': sum(1 for r in rows if r['cause'] == 'page-number-typo' and r['suggested_target']),
    }
    counts['crossReferences']['independentScanBeyondCSVSample'] = ['%s@%d %s' % e for e in extra[:12]]
    require(len(extra) == len(not_shipped), 'the independent scan finds broken references the CSV lacks: %s'
            % [e for e in extra if e not in not_shipped][:5])


# ---------------------------------------------------------------------------------------------
# D. Dates (scans)
# ---------------------------------------------------------------------------------------------

_DATELINE = re.compile(rb'<dateline\b.*?</dateline>', re.S)
_DATE = re.compile(rb'<date\b([^>]*)>(.*?)</date>', re.S)
_SOURCE = re.compile(rb'<note\b[^>]*type="source"[^>]*>(.*?)</note>', re.S)
_FILE_DATE = re.compile(r'/(\d{1,2})[–-](\d{1,2})(\d{2})\b')


def _instant(text):
    try:
        value = datetime.datetime.fromisoformat(text)
    except ValueError:
        return None
    if value.tzinfo is None:
        value = value.replace(tzinfo=datetime.timezone(datetime.timedelta(hours=-5)))
    return value


def dates(counts, rows):
    c = collections.Counter()
    vols = collections.defaultdict(set)
    documents = 0
    for name in volume_files():
        v = volume(name[:-4])
        m = re.match(r'frus(\d{4})(?:-(\d{2}))?', v.vid)
        first = int(m.group(1))
        last = int(str(first)[:2] + m.group(2)) if m.group(2) else first
        for d in v.divs:
            low, high = d['attrs'].get('frus:doc-dateTime-min'), d['attrs'].get('frus:doc-dateTime-max')
            if low and high and _instant(low) and _instant(high) and _instant(low) > _instant(high):
                kind = 'range-inverted'
                c[kind] += 1
                vols[kind].add(v.vid)
                rows.append({
                    'class': kind, 'volume': v.vid, 'element': d['id'] or '', 'element_type': d['type'] or '',
                    'file': v.name, 'line': d['line'], 'encoded': 'min %s / max %s' % (low, high), 'printed': '',
                    'what_is_wrong': 'frus:doc-dateTime-min is later than frus:doc-dateTime-max.',
                    'confidence': 'confirmed',
                })
            if d['type'] != 'document':
                continue
            documents += 1
            body = v.blanked[d['off']:d['close_off']]
            nested = body.find(b'<div', 10)
            segment = body if nested < 0 else body[:nested]
            dateline = _DATELINE.search(segment)
            if not dateline:
                continue
            date = _DATE.search(dateline.group(0))
            if not date:
                continue
            when = attrs(date.group(1)).get('when') or ''
            text = plain(date.group(2))
            printed = re.findall(r'\b(1[789]\d\d|20\d\d)\b', text)
            line = v.line(d['off'] + dateline.start())
            if when[:4].isdigit() and printed and when[:4] not in printed:
                kind = 'year-contradicts-text'
                c[kind] += 1
                vols[kind].add(v.vid)
                rows.append({
                    'class': kind, 'volume': v.vid, 'element': d['id'], 'element_type': 'document', 'file': v.name,
                    'line': line, 'encoded': 'when="%s"' % when, 'printed': text[:60],
                    'what_is_wrong': 'The date is encoded %s and prints %s (the volume covers %s).'
                                     % (when[:4], ', '.join(printed), first if first == last else '%d-%d' % (first, last)),
                    'confidence': 'confirmed',
                })
                continue
            source = _SOURCE.search(segment)
            if not (source and len(when) >= 10 and when[:4].isdigit()):
                continue
            filed = _FILE_DATE.search(plain(source.group(1)))
            if not filed:
                continue
            month, day, year = int(filed.group(1)), int(filed.group(2)), 1900 + int(filed.group(3))
            if (month, day) == (int(when[5:7]), int(when[8:10])) and year != int(when[:4]) \
                    and first <= year <= last and not first <= int(when[:4]) <= last:
                kind = 'year-contradicts-file-number'
                c[kind] += 1
                vols[kind].add(v.vid)
                # A row reaches here with its printed year equal to the encoded one (the rule above took the
                # rest), or with no year printed at all: "undated", where @when is the editors' inference.
                if printed:
                    wrong = 'The document is dated %s, outside the volume\'s years, while its own file number ' \
                            '(%s) carries the same month and day in %d.' % (when[:4], filed.group(0)[1:], year)
                else:
                    c['file-number-no-year-printed'] += 1
                    ana = attrs(date.group(1)).get('ana')
                    wrong = 'The dateline prints "%s", with no year; the date encoded for it%s is %s, outside the ' \
                            'volume\'s years, while the document\'s own file number (%s) carries the same month and ' \
                            'day in %d. The page prints no year to settle it.' \
                            % (text[:40], ' (ana="%s")' % ana if ana else '', when[:4], filed.group(0)[1:], year)
                rows.append({
                    'class': kind, 'volume': v.vid, 'element': d['id'], 'element_type': 'document', 'file': v.name,
                    'line': line, 'encoded': 'when="%s"' % when, 'printed': text[:60],
                    'what_is_wrong': wrong, 'confidence': 'question',
                })
    require(documents > 0 and c['year-contradicts-text'] > 0 and c['range-inverted'] > 0, 'the date scan read nothing')
    contradicted = [r for r in rows if r['class'] == 'year-contradicts-text']
    in_1891 = [r for r in contradicted if r['volume'] == 'frus1891']
    if 'frus1891.xml' in volume_files():  # the report's sentence about this volume, asserted when it is read
        require(in_1891 and all(r['encoded'].startswith('when="1891') for r in in_1891),
                'frus1891: a contradicted date is no longer encoded 1891')
    by_file_number = c['year-contradicts-file-number']
    no_year = c.pop('file-number-no-year-printed', 0)
    counts['dates'] = {'documentsRead': documents, 'rows': len(rows), 'volumes': len({r['volume'] for r in rows}),
                       'fileNumberRowsPrintingTheEncodedYear': by_file_number - no_year,
                       'fileNumberRowsPrintingNoYear': no_year,
                       'yearContradictsTextTopVolumes': collections.Counter(r['volume'] for r in contradicted).most_common(6),
                       'yearContradictsTextInFrus1891': len(in_1891),
                       'byClass': {k: {'rows': c[k], 'volumes': len(vols[k])} for k in sorted(c)},
                       'invertedDocuments': sum(1 for r in rows if r['class'] == 'range-inverted' and r['element_type'] == 'document'),
                       'invertedDivisions': sum(1 for r in rows if r['class'] == 'range-inverted' and r['element_type'] != 'document')}


# ---------------------------------------------------------------------------------------------
# T. Transcription (scans)
# ---------------------------------------------------------------------------------------------

_INNER_NOTE = re.compile(rb'<note\b[^>]*>(?:(?!<note\b).)*?</note>', re.S)
_MARKING = r'(?:Top Secret|Secret|Confidential|Unclassified|Limited Official Use|Official Use Only)'
_DEPARTMENT = 'department of state'


def _department_misspelling(text):
    if _DEPARTMENT in text.lower() or re.search(r'Department,? State of', text):
        return None
    words = text.split()
    best = None
    for k in range(len(words)):
        for size in (2, 3, 4):
            phrase = ' '.join(words[k:k + size])
            core = re.sub(r'[^a-z ]', '', phrase.lower())
            ratio = difflib.SequenceMatcher(None, core, _DEPARTMENT).ratio()
            last = core.split()[-1] if core.split() else ''
            if ratio >= 0.86 and difflib.SequenceMatcher(None, last[-5:], 'state').ratio() >= 0.7 \
                    and (best is None or ratio > best[0]):
                best = (ratio, phrase)
    return best[1] if best else None


_ENUMERATOR = re.compile(r'(?:^|(?<=[\s;:,.\u201c\u2018"\'\[]))(?:\d{1,2}|[A-Za-z]|[ivxIVX]{1,4})$')


def _stray_closers(text):
    """The offset of each ")" in a text that closes nothing, list enumerators left out.

    The parentheses are walked in order, so "(a (b))" leaves none and "1) x (y)) z" leaves the one
    after "(y)". An enumerator is a number of one or two digits, one letter or a short Roman numeral
    that stands at the start of the text or after a space, an opening quotation mark, a bracket or
    one of ; : , . and is closed by a ")" that has no "(" to match: the "1)" and "2)" of a list.
    Counting the two signs instead reads every such list as that many parentheses too many. A dash
    does not introduce one: the "45" of the file number "3–19–45)" is not a list item.
    """
    depth, out = 0, []
    for k, sign in enumerate(text):
        if sign == '(':
            depth += 1
        elif sign == ')':
            if depth:
                depth -= 1
            elif not _ENUMERATOR.search(text, max(0, k - 8), k):
                out.append(k)
    return out


def _around(data, start, end, before=160, after=40):
    """plain() of the bytes around a span, cut so that it neither begins nor ends inside a tag."""
    chunk = data[max(0, start - before):end + after]
    closes, opens = chunk.find(b'>'), chunk.find(b'<')
    if closes >= 0 and (opens < 0 or closes < opens):
        chunk = chunk[closes + 1:]
    if chunk.rfind(b'<') > chunk.rfind(b'>'):
        chunk = chunk[:chunk.rfind(b'<')]
    return plain(chunk)


def transcription(counts, rows, glued_rows):
    c = collections.Counter()
    vols = collections.defaultdict(set)
    stray_notes, stray_volumes = 0, set()
    glued_total = collections.Counter()
    glued_files = collections.Counter()
    files = 0

    def add(kind, v, line, element, text, wrong):
        c[kind] += 1
        vols[kind].add(v.vid)
        rows.append({'class': kind, 'volume': v.vid, 'file': v.name, 'line': line, 'element': element,
                     'text': text, 'what_is_wrong': wrong})

    for name in volume_files():
        v = volume(name[:-4])
        files += 1
        b = v.blanked
        per_file = {}
        for label, pattern in (('comma', rb',<gloss\b'), ('comma_persName', rb',<persName\b'), ('semicolon', rb';<gloss\b')):
            n = len(re.findall(pattern, b))
            if n:
                per_file[label] = n
                glued_total[label] += n
                glued_files[label] += 1
        if per_file:
            glued_rows.append({'volume': v.vid, 'file': v.name, 'comma_then_gloss': per_file.get('comma', 0),
                               'comma_then_persName': per_file.get('comma_persName', 0),
                               'semicolon_then_gloss': per_file.get('semicolon', 0)})
        source_notes = []
        for m in _INNER_NOTE.finditer(b):
            opening = m.group(0)[:m.group(0).find(b'>')]
            shown = plain(m.group(0)[len(opening) + 1:-len(b'</note>')])
            line = v.line(m.start())
            note_id = attrs(opening).get('xml:id', '')
            stray = _stray_closers(shown) if ')' in shown else []
            if stray:
                stray_notes += 1
                stray_volumes.add(v.vid)
            # Reported only where the note also holds "))": without that condition the rule finds the far
            # larger class of a "(" lost, which nobody has read row by row (counted below, not listed).
            if stray and '))' in shown:
                at = stray[0]
                add('unbalanced-parenthesis', v, line, note_id, shown[max(0, at - 90):at + 1],
                    'The ")" that ends this quotation closes nothing: walking the note\'s parentheses in order, '
                    'with list enumerators such as "1)" set aside, leaves it unmatched. One ")" too many, or a "(" lost.')
            if not re.search(rb'type="source"', opening):
                continue
            source_notes.append((m.start(), m.end()))
            if re.search(r'\bS VIEI\b', shown):
                c['viei-in-source-note'] += 1
                add('viei-for-viet', v, line, note_id, shown[:110], '"S VIEI" for "S VIET" in the file designation.')
            glued = re.search(r'Central Files(\d{4})', shown)
            if glued:
                add('central-files-year-glued', v, line, note_id, shown[max(0, glued.start() - 60):glued.end() + 46],
                    'No space between "Central Files" and "%s".' % glued.group(1))
            hit = re.search(r'Central Files,[^.]{3,60}?[A-Za-z0-9/)–-] (' + _MARKING + r')\b[;.]', shown)
            if hit:
                add('no-stop-before-classification', v, line, note_id, shown[:110],
                    'No full stop between the file designation and "%s".' % hit.group(1))
            if re.search(r'[—–a-z0-9)]\.(?=' + _MARKING + r'\b)', shown):
                add('no-space-before-classification', v, line, note_id, shown[:110],
                    'No space between the full stop and the classification.')
            doubled = re.search(r'(?<!\.)\.\.(?!\.)', shown)
            if doubled:
                add('doubled-full-stop', v, line, note_id, shown[max(0, doubled.start() - 100):doubled.end() + 20],
                    'Two full stops together.')
            label = re.search(r'Centrals Files|Central piles', shown)
            if label:
                add('central-files-label', v, line, note_id, shown[:110], '"%s" for "Central Files".' % label.group(0))
        # The same misreading outside a source note (a Sources list glosses the designation in prose).
        for m in re.finditer(rb'\bVIEI\b', b):
            if any(start <= m.start() < end for start, end in source_notes):
                continue
            shown = _around(b, m.start(), m.end())
            if re.search(r'\bS VIEI\b', shown):
                inside = v.enclosing_div(m.start())
                add('viei-for-viet', v, v.line(m.start()), inside['id'] if inside else '', shown[-110:],
                    '"S VIEI" for "S VIET", outside a source note.')
        year = re.match(r'frus(\d{4})', v.vid)
        if year and int(year.group(1)) < 1906:
            for d in v.divs:
                if d['type'] != 'document':
                    continue
                segment = b[d['off']:min(d['close_off'], d['off'] + 6000)]
                dateline = _DATELINE.search(segment)
                if not dateline:
                    continue
                shown = plain(dateline.group(0))
                wrong = _department_misspelling(shown)
                if wrong:
                    add('department-of-state-misspelt', v, v.line(d['off'] + dateline.start()), d['id'], shown[:110],
                        '"Department of State" is misspelt in the dateline.')
    # Three statements the report makes about one volume each, asserted where that volume is read. The
    # self-test's synthetic corpus holds none of them; main() refuses a corpus that lacks one (NAMED).
    # The heading is one misprint met while reading section 1's volume; it is asserted, not scanned for.
    if 'frus1952-54v09p1.xml' in volume_files():
        v = volume('frus1952-54v09p1')
        require('Hashe\u2013Mite Kingdom' in re.sub(r'\s+', ' ', v.line_text(67638) + v.line_text(67639)),
                'frus1952-54v09p1: the ch4 heading no longer reads Hashe-Mite')
        add('heading-misprint', v, 67638, 'ch4', 'United States Relations with Israel, the Hashe\u2013Mite Kingdom of Jordan',
            '"Hashe\u2013Mite" for "Hashemite" in the chapter heading.')
    require(files > 0 and rows and glued_rows, 'the transcription scan read nothing')
    for kind in ('unbalanced-parenthesis', 'viei-for-viet', 'no-stop-before-classification', 'doubled-full-stop',
                 'department-of-state-misspelt', 'central-files-year-glued', 'no-space-before-classification',
                 'central-files-label'):
        require(c[kind] > 0, 'the transcription scan found no %s' % kind)
    if 'frus1981-88v16.xml' in volume_files():
        v16 = [r for r in rows if r['class'] == 'unbalanced-parenthesis' and r['volume'] == 'frus1981-88v16']
        require(len(v16) == 1 and v16[0]['element'] == 'd395fn4', 'frus1981-88v16 d395fn4 no longer holds the doubled )')
    if 'frus1961-63v03.xml' in volume_files():  # section 6.3 names the two volumes
        top = collections.Counter(r['volume'] for r in rows if r['class'] == 'no-stop-before-classification')
        require({name for name, _ in top.most_common(2)} == {'frus1961-63v03', 'frus1961-63v04'},
                'the notes with no stop before the classification are no longer mostly in frus1961-63v03 and v04')
    viei_notes = c.pop('viei-in-source-note', 0)
    stop = [r for r in rows if r['class'] == 'no-stop-before-classification']
    stop_top = collections.Counter(r['volume'] for r in stop).most_common(2)
    counts['transcription'] = {
        'filesRead': files, 'rows': len(rows),
        'byClass': {k: {'rows': c[k], 'volumes': len(vols[k])} for k in sorted(c)},
        'vieiSourceNotes': viei_notes, 'vieiElsewhere': c['viei-for-viet'] - viei_notes,
        'noStopTopTwoVolumes': [name for name, _ in stop_top], 'noStopInTopTwoVolumes': sum(n for _, n in stop_top),
        'notesWithAnUnmatchedCloser': {'notes': stray_notes, 'volumes': len(stray_volumes),
                                       'reported': c['unbalanced-parenthesis']},
        'gluedCommaGloss': {'sites': glued_total['comma'], 'files': glued_files['comma']},
        'gluedCommaPersName': {'sites': glued_total['comma_persName'], 'files': glued_files['comma_persName']},
        'gluedSemicolonGloss': {'sites': glued_total['semicolon'], 'files': glued_files['semicolon']},
        'gluedFiles': len(glued_rows),
    }


# ---------------------------------------------------------------------------------------------
# H. Headers (scans)
# ---------------------------------------------------------------------------------------------

_CHANGE = re.compile(rb'<change\b([^>]*?)/?>', re.S)
_TITLES = re.compile(rb'<titleStmt>(.*?)</titleStmt>', re.S)


def headers(counts, rows):
    tally = collections.Counter()
    for name in volume_files():
        v = volume(name[:-4])
        head = v.blanked[:v.blanked.find(b'</teiHeader>')]
        own = [(v.line(m.start()), attrs(m.group(1))) for m in _CHANGE.finditer(head)]
        own = [(line, a) for line, a in own if a.get('corresp') == '#' + v.vid and a.get('status') == 'published']
        if not own:
            tally['none'] += 1
        elif any('when' in a for _, a in own):
            tally['dated'] += 1
        else:
            tally['undated'] += 1
            rows.append({'class': 'published-change-without-when', 'volume': v.vid, 'file': v.name, 'line': own[0][0],
                         'what_is_wrong': '<change corresp="#%s" status="published"/> carries no @when.' % v.vid,
                         'confidence': 'question'})

    def titles(vid):
        block = _TITLES.search(volume(vid).blanked).group(1)
        return {attrs(a).get('type'): plain(t) for a, t in re.findall(rb'<title\b([^>]*?)(?:/>|>(.*?)</title>)', block, re.S)}

    require(titles('frus1877app') == titles('frus1877'), 'frus1877app\'s titles no longer equal frus1877\'s')
    line = volume('frus1877app').line(volume('frus1877app').blanked.find(b'<titleStmt>'))
    rows.append({'class': 'appendix-title', 'volume': 'frus1877app', 'file': 'frus1877app.xml', 'line': line,
                 'what_is_wrong': 'The titleStmt is word for word that of frus1877: no title names the Appendix, and the '
                                  'volume-number title is empty.', 'confidence': 'question'})
    app2, app1 = titles('frus1894app2'), titles('frus1894app1')
    require('Appendix' not in app2['complete'] and 'Appendix I' in app1['complete'],
            'the frus1894 appendix titles changed')
    line = volume('frus1894app2').line(volume('frus1894app2').blanked.find(b'<titleStmt>'))
    rows.append({'class': 'appendix-title', 'volume': 'frus1894app2', 'file': 'frus1894app2.xml', 'line': line,
                 'what_is_wrong': 'The complete title stops at "Foreign Relations of the United States, 1894"; that of '
                                  'frus1894app1 goes on to name Appendix I and its contents.', 'confidence': 'question'})
    require(tally['undated'] > 0, 'the header scan found nothing')
    counts['headers'] = {'publishedChangeDated': tally['dated'], 'publishedChangeUndated': tally['undated'],
                         'noPublishedChange': tally['none'], 'appendixTitleRows': 2}


# ---------------------------------------------------------------------------------------------
# The figure sentences the report must carry, each built from this run
# ---------------------------------------------------------------------------------------------

def figure_sentences(n):
    """Every sentence of Part A that states a figure of the run, as the run would write it."""
    x, p, s, d, t = n['crossReferences'], n['pagination']['byClass'], n['structure'], n['dates'], n['transcription']
    g, tc, cause = n['gap'], t['byClass'], x['byCause']
    first_missing, last_missing = int(g['lastDocument'][1:]) + 1, int(g['part2FirstDocument'][1:]) - 1
    return [
        '%d files' % n['filesRead'],
        'Documents %d–%d' % (first_missing, last_missing),
        'The last %d documents' % (last_missing - first_missing + 1),
        '%d of the %d broken references' % (x['gapRows'], x['generatorRows']),
        '%d distinct pages' % x['gapDistinctPages'],
        '%d edits in %d volumes' % (s['edits'], s['volumes']),
        '%d confirmed in %d volumes' % (s['confirmed'], s['confirmedVolumes']),
        '%d questions in %d volumes' % (s['questions'], s['questionVolumes']),
        '%d Sources lists' % n['sourcesLists']['volumes'],
        '`sources-lists.csv` has the %d rows' % n['sourcesLists']['rows'],
        '%d rows in %d volumes' % (n['pagination']['rows'], n['pagination']['volumes']),
        '%d pairs in %d volumes' % (p['reversed-pair']['rows'], p['reversed-pair']['volumes']),
        'In %d the two divisions are adjacent' % n['pagination']['reversedPairsAdjacent'],
        'In the other %d' % n['pagination']['reversedPairsWithADivisionBetween'],
        'an editorial note in all %d' % n['pagination']['reversedPairsSecondIsEditorialNote'],
        'both are editorial notes in %d' % n['pagination']['reversedPairsBothEditorialNotes'],
        'the only gap among the %d' % n['parts']['continuousPairs'],
        '%d pages at %d places in %d volumes' % (n['pagination']['missingPages'], p['missing-break']['rows'],
                                                p['missing-break']['volumes']),
        '%d page ids in %d volumes' % (p['malformed-id']['rows'], p['malformed-id']['volumes']),
        '%d breaks in %d volumes' % (p['wrong-facs']['rows'], p['wrong-facs']['volumes']),
        '`cross-references.csv` has %d rows' % (x['defects'] + x['notDefects']),
        '%d references to %d index ids' % (x['indexIdRows'], x['indexIdDistinctTargets']),
        '%d rows are defects' % x['defects'],
        '%d are not defects' % x['notDefects'],
        'The wrong volume | %d |' % cause['wrong-volume'],
        'A mistyped page number | %d |' % cause['page-number-typo'],
        'names the likely page for %d' % x['pageNumberTyposWithALikelyPage'],
        'A page past the end of the volume cited | %d |' % cause['page-beyond-volume'],
        'A target with no `#` | %d |' % cause['missing-hash'],
        '`dates.csv` has %d rows in %d volumes' % (d['rows'], d['volumes']),
        '%d documents in %d volumes' % (d['byClass']['year-contradicts-text']['rows'],
                                        d['byClass']['year-contradicts-text']['volumes']),
        '%d of them are in frus1891' % d['yearContradictsTextInFrus1891'],
        '%d more documents' % d['byClass']['year-contradicts-file-number']['rows'],
        'In %d of them the text and the attribute agree' % d['fileNumberRowsPrintingTheEncodedYear'],
        'In %d the dateline prints no year' % d['fileNumberRowsPrintingNoYear'],
        '%d document and %d divisions' % (d['invertedDocuments'], d['invertedDivisions']),
        '`transcription.csv` has %d rows' % t['rows'],
        '%s sites in %d files' % (format(t['gluedCommaGloss']['sites'], ','), t['gluedCommaGloss']['files']),
        'occurs %d times in %d files' % (t['gluedSemicolonGloss']['sites'], t['gluedSemicolonGloss']['files']),
        'each of the %d files' % t['gluedFiles'],
        '%d source notes in %d volumes' % (tc['central-files-year-glued']['rows'], tc['central-files-year-glued']['volumes']),
        '%d notes in %d volumes' % (tc['unbalanced-parenthesis']['rows'], tc['unbalanced-parenthesis']['volumes']),
        '%d source notes have no full stop' % tc['no-stop-before-classification']['rows'],
        '%d of the %d are in these two volumes' % (t['noStopInTopTwoVolumes'], tc['no-stop-before-classification']['rows']),
        '%d source notes read "S VIEI"' % t['vieiSourceNotes'],
        'stands %d more time' % t['vieiElsewhere'],
        '%d source notes have a doubled full stop' % tc['doubled-full-stop']['rows'],
        '%d have no space between the full stop' % tc['no-space-before-classification']['rows'],
        '%d misspell the label' % tc['central-files-label']['rows'],
        '%d datelines in %d volumes' % (tc['department-of-state-misspelt']['rows'],
                                        tc['department-of-state-misspelt']['volumes']),
        '`headers.csv` has %d rows' % (n['headers']['publishedChangeUndated'] + n['headers']['appendixTitleRows']),
        '%d files carry' % n['headers']['publishedChangeUndated'],
        'The other %d that have' % n['headers']['publishedChangeDated'],
    ]


def missing_figures(sentences, report):
    """The figure sentences the report does not carry, and the reason when it cannot be read at all.

    Each sentence is looked for in PART A only (Part B repeats some figures, and a figure standing
    only there is not one the Office of the Historian will read), and as a whole figure: where a
    sentence begins or ends with a number, a longer number that merely contains it does not count,
    so "1 files carry" is not found in "11 files carry", nor "4 datelines" in "34 datelines", nor
    "13 sites" in "1,213 sites". The preamble above Part A must state how many sentences there are.
    """
    opens, closes = report.find('\n# Part A'), report.find('\n# Part B')
    if opens < 0 or closes < opens:
        return None, 'the report has no "# Part A" heading followed by a "# Part B" heading'
    preamble, part_a = report[:opens], report[opens:closes]

    def carried(sentence, text):
        return re.search(r'(?<![\d,.])' + re.escape(sentence) + r'(?![\d])(?![,.]\d)', text) is not None

    absent = [sentence for sentence in sentences if not carried(sentence, part_a)]
    stated = '%d figure sentences' % len(sentences)
    if not carried(stated, preamble):
        absent.append(stated + ' (in the lines above Part A)')
    return absent, None


# ---------------------------------------------------------------------------------------------

def write_csv(path, rows, columns=None):
    columns = columns or list(rows[0].keys())
    with open(path, 'w', newline='', encoding='utf-8') as handle:
        writer = csv.DictWriter(handle, fieldnames=columns, lineterminator='\n')
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


USAGE = 'usage: build_oh_report.py [--check REPORT.md]'

# Volumes a scan asserts a sentence of the report about, each "if the file is read". A corpus without
# one would skip that assertion in silence, so the run requires them all before it scans.
NAMED = ('frus1891', 'frus1952-54v09p1', 'frus1961-63v03', 'frus1981-88v16')


def report_to_check(argv):
    """The text of the report named by `--check FILE`, or None when no argument is given.

    Anything else stops the run before it reads the corpus: `--check` with no file, the file before
    the flag, a file that does not exist, an unknown flag. Each used to run to the end with no check
    made and no word said.
    """
    arguments = argv[1:]
    if not arguments:
        return None
    if len(arguments) != 2 or arguments[0] != '--check':
        sys.exit('NOT WRITTEN: unrecognised arguments %s\n%s' % (arguments, USAGE))
    if not os.path.isfile(arguments[1]):
        sys.exit('NOT WRITTEN: --check names no file: %s\n%s' % (arguments[1], USAGE))
    return open(arguments[1], encoding='utf-8').read()


def main(argv):
    report = report_to_check(argv)
    commit = os.environ.get('CORPUS_COMMIT')
    if not commit:
        sys.exit('NOT WRITTEN: CORPUS_COMMIT is required: every line number in the report is relative to one '
                 'corpus revision.')
    out_dir = os.environ.get('OUT_DIR', os.path.join(REPO, 'Planning', 'OH-Report-2026-10-01'))
    xref_csv = os.environ.get('XREF_CSV', os.path.join(REPO, 'Planning', 'cross-ref-validation', 'broken-refs-report.csv'))
    manifest = os.environ.get('MANIFEST', os.path.join(REPO, 'FRUSExplorer', 'Resources', 'manifest.json'))
    counts = {'corpusCommit': commit, 'filesRead': len(volume_files()),
              'generated': os.environ.get('GENERATED_DATE', datetime.date.today().isoformat())}
    tables = {k: [] for k in ('gap', 'structure', 'sources', 'pagination', 'xref', 'dates', 'transcription', 'glued', 'headers')}
    withdrawn = []
    try:
        require(counts['filesRead'] > 0, 'no volumes under %s' % ohlib.VOLUMES_DIR)
        absent = [name for name in NAMED if name + '.xml' not in volume_files()]
        require(not absent, 'the corpus under %s lacks %s, which the report names' % (ohlib.VOLUMES_DIR, absent))
        gap(counts, tables['gap'])
        structure(counts, tables['structure'], withdrawn)
        sources_lists(counts, tables['sources'])
        pagination(counts, tables['pagination'])
        parts(counts, tables['pagination'])
        ill_formed = []
        for name in volume_files():
            try:
                ET.fromstring(volume(name[:-4]).raw)
            except ET.ParseError as error:
                ill_formed.append('%s: %s' % (name, error))
        require(not ill_formed, 'not well-formed: %s' % ill_formed[:3])
        counts['wellFormedFiles'] = counts['filesRead']
        cross_references(counts, tables['xref'], xref_csv, manifest)
        dates(counts, tables['dates'])
        transcription(counts, tables['transcription'], tables['glued'])
        headers(counts, tables['headers'])
    except Failed as failure:
        sys.exit('NOT WRITTEN: %s' % failure)
    counts['structure']['withdrawn'] = [{'volume': a, 'element': b, 'reason': c} for a, b, c in withdrawn]
    sentences = figure_sentences(counts)
    counts['figureSentences'] = len(sentences)
    if report is not None:
        absent, unreadable = missing_figures(sentences, report)
        if unreadable:
            sys.exit('NOT WRITTEN: %s' % unreadable)
        if absent:
            sys.exit('NOT WRITTEN: Part A of the report does not carry these figures of this run: %s' % absent)
    os.makedirs(out_dir, exist_ok=True)
    if tables['gap']:
        write_csv(os.path.join(out_dir, 'missing-documents.csv'), tables['gap'])
    write_csv(os.path.join(out_dir, 'structure.csv'), tables['structure'])
    write_csv(os.path.join(out_dir, 'sources-lists.csv'), tables['sources'])
    write_csv(os.path.join(out_dir, 'pagination.csv'), tables['pagination'])
    write_csv(os.path.join(out_dir, 'cross-references.csv'), tables['xref'])
    write_csv(os.path.join(out_dir, 'dates.csv'), tables['dates'])
    write_csv(os.path.join(out_dir, 'transcription.csv'), tables['transcription'])
    write_csv(os.path.join(out_dir, 'transcription-glued-tags.csv'), tables['glued'])
    write_csv(os.path.join(out_dir, 'headers.csv'), tables['headers'])
    with open(os.path.join(out_dir, 'counts.json'), 'w', encoding='utf-8') as handle:
        json.dump(counts, handle, indent=2, sort_keys=True, ensure_ascii=False)
        handle.write('\n')
    print(json.dumps(counts, indent=2, sort_keys=True, ensure_ascii=False))
    print('\nFigure sentences of this run%s:' % ('' if report is None else ', each found in Part A of the report'))
    for sentence in sentences:
        print('  ' + sentence)


if __name__ == '__main__':
    main(sys.argv)
