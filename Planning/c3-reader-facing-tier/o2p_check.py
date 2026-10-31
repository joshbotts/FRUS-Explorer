#!/usr/bin/env python3
"""O2' by script (Planning/C-3-Reader-Facing-Tier-Design.md §5.3). Lists the overview's numbers,
finds the memo's trace table, and classes each number:
  traced    a row's first column holds the same value followed by the same word;
  weak      some row holds the value without that word;
  untraced  no row holds the value.
Writes <out>/o2p_flags.json and <out>/o2p_flags.txt (the weak and untraced numbers, each with its
sentence), which the scorer reads; it never lists the overview's numbers itself.

    python3 o2p_check.py <run directory> [--trace <file holding the trace table>] [--out <dir>]

Left out, as the rubric excepts them: years and dates; document, volume and part numbers; numbers
inside a citation or a link; the Documents cited list; list markers. Ordinals count only where they
rank a quantity ("second-largest"). Archival identifiers stay in."""
import json, re, sys, pathlib

ONES = ['one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine']
WORDNUM = {w: i + 1 for i, w in enumerate(ONES)}
WORDNUM.update({'ten': 10, 'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15,
                'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19, 'twenty': 20, 'thirty': 30,
                'forty': 40, 'fifty': 50, 'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90,
                'hundred': 100, 'hundreds': 100, 'thousand': 1000, 'thousands': 1000, 'million': 10**6,
                'millions': 10**6, 'billion': 10**9, 'dozen': 12, 'dozens': 12, 'half': 0.5, 'halves': 0.5,
                'quarter': 0.25, 'quarters': 0.25, 'twice': 2, 'double': 2, 'doubled': 2, 'doubles': 2,
                'triple': 3, 'tripled': 3, 'thrice': 3})
TENS = r'(?:twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety)'
WORDS_ALT = TENS + r'-(?:' + '|'.join(ONES) + r')|' + '|'.join(sorted(WORDNUM, key=len, reverse=True))
WORDS_RE = r'\b(?:' + WORDS_ALT + r')\b'
ORD = r'(?:first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth)'
SUPER = (r'(?:largest|greatest|most|biggest|highest|lowest|smallest|best|worst|least|longest|richest|'
         r'densest|heaviest|commonest|fewest|strongest|weakest|leading)')
MONTHS = (r'(?:January|February|March|April|May|June|July|August|September|October|November|December|'
          r'Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sept|Sep|Oct|Nov|Dec)')
ROMAN = r'[IVXLC]+'
CIT = re.compile(r'\((?:[^()]|\([^()]*\))*?(?:Foreign Relations|history\.state\.gov|Document \d)(?:[^()]|\([^()]*\))*\)')
IDENT = re.compile(r'\b(?:\d+\s?[A-Z]{1,2}\s?\d+[A-Z\d]*|[A-Z]{1,3}\d?[- ]\d{2,}[A-Z\d]*|\d{3}\.\d+(?:/[\w.-]+)?)\b')


def clean_overview(text):
    """The overview's prose with what the rubric excepts removed, line structure kept."""
    lines, out, skip = text.splitlines(), [], False
    for line in lines:
        if re.match(r'^#+\s*Documents cited', line, re.I):
            skip = True
            continue
        if skip and re.match(r'^#+\s', line):
            skip = False
        if skip:
            continue
        out.append(line)
    t = '\n'.join(out)
    t = re.sub(r'\]\([^)]*\)', ']', t)                       # markdown link targets
    t = re.sub(r'https?://\S+', ' ', t)
    t = re.sub(r'\[\^?\d+\]', ' ', t)                         # footnote markers
    t = CIT.sub(' ', t)
    t = re.sub(r'Foreign Relations of the United States,?[^;)\n]*?Document\s+\d+[a-z]?', ' ', t)
    short = (r'\b1[6-9]\d\d(?:[–-]\d{2,4})?,\s*(?:(?:Volume|Vol\.)\s+(?:' + ROMAN + r'|\d+),?\s*)?'
             r'(?:Part\s+\d+,?\s*)?(?:(?:Supplement|Appendix)[^,;)]*,\s*)?Documents?\s+\d+[a-z]?(?:\s*(?:and|,|–|-)\s*\d+[a-z]?)*')
    t = re.sub(short, ' ', t)
    t = re.sub(r'\bDocuments?\s+(?:Nos?\.\s*)?\d+[a-z]?(?:\s*(?:,|and|–|-|to)\s*\d+[a-z]?)*', ' ', t)
    vol = r'(?:[A-Z]?[–-]?\d+|' + ROMAN + r')'
    t = re.sub(r'\b(?:Volume|Vol\.|Volumes)\s+' + vol + r'(?:\s*(?:,|and|–|-)\s*' + vol + r')*', ' ', t)
    t = re.sub(r'\bPart\s+\d+\b', ' ', t)
    t = re.sub(r'\bNo\.\s*\d+\b', ' ', t)
    t = re.sub(r'\bfrus[\w-]*(?:/d\d+[a-z]?)?', ' ', t)
    t = re.sub(r'\bd\d+[a-z]?\b', ' ', t)
    t = re.sub(r'\b\d{1,2}(?:st|nd|rd|th)?\s+' + MONTHS + r'\.?,?\s+1[6-9]\d\d\b', ' ', t)
    t = re.sub(r'\b' + MONTHS + r'\.?\s+\d{1,2}(?:st|nd|rd|th)?,?\s+1[6-9]\d\d\b', ' ', t)
    t = re.sub(r'\b' + MONTHS + r'\.?\s+\d{1,2}(?:st|nd|rd|th)?\b', ' ', t)
    t = re.sub(r'\b' + MONTHS + r'\.?,?\s+1[6-9]\d\d\b', ' ', t)
    t = re.sub(r'\b\d{1,2}\s+' + MONTHS + r'\b', ' ', t)
    t = re.sub(r'\b1[6-9]\d\d-\d\d-\d\d\b', ' ', t)
    t = re.sub(r'\b(?:mid-|early |late )?(?:1[6-9]\d\d|20[0-4]\d)(?:s|’s|\'s)?(?:\s*[–-]\s*\d{2,4}s?)?\b', ' ', t)
    t = re.sub(r'(?m)^\s*(?:#+\s*)?(?:\d+[.)]|[-*])\s+', ' ', t)   # list markers and numbered headings
    t = re.sub(r'\*\*\d+\.', ' ', t)
    t = re.sub(r'\b(?:Finding|Section|Step|Chapter)\s+\d+\b', ' ', t, flags=re.I)
    return t


def sentences(t):
    t = re.sub(r'\s+', ' ', t)
    return [s.strip() for s in re.split(r'(?<=[.!?;:])\s+(?=[A-Z“"(\[])', t) if s.strip()]


SKIP = {'of', 'the', 'a', 'an', 'per', 'in', 'and', 'or', 'more', 'than', 'about', 'such', 'other', 'its'}


def next_words(s, end, n=2):
    """The first n content words within the six words after a number, singular."""
    out = []
    for k, m in enumerate(re.finditer(r'[A-Za-z][A-Za-z-]*', s[end:])):
        if k >= 6 or len(out) == n:
            break
        w = m.group(0).lower()
        if w not in SKIP:
            out.append(sing(w))
    return out


def next_word(s, end):
    """The first content word after a number, singular, or ''."""
    w = next_words(s, end, 1)
    return w[0] if w else ''


def sing(w):
    w = w.lower()
    return w[:-1] if len(w) > 3 and w.endswith('s') and not w.endswith('ss') else w


def word_value(w):
    w = w.lower()
    if '-' in w and w.split('-')[0] in WORDNUM and w.split('-')[1] in WORDNUM:
        a, b = w.split('-')
        return WORDNUM[a] + WORDNUM[b]
    return WORDNUM.get(w)


def fmt(v):
    if isinstance(v, float) and v.is_integer():
        v = int(v)
    return str(v)


def mentions_of(s):
    """Each number in one sentence: (text, values, next word, kind)."""
    found, taken = [], []

    def free(a, b):
        return all(b <= x or a >= y for x, y in taken)

    for m in re.finditer(r'\b(?:Record Group|RG)\s+(\d+)\b', s):
        taken.append(m.span())
        found.append((m.group(0), ['rg' + m.group(1)], '', 'identifier', m.start()))
    for m in IDENT.finditer(s):
        tok = m.group(0)
        if re.fullmatch(r'\d+', tok) or not free(*m.span()):
            continue
        taken.append(m.span())
        found.append((tok, [re.sub(r'\s', '', tok).lower()], '', 'identifier', m.start()))
    for m in re.finditer(r'(?<![\w/.,-])\d{5,}(?![\w,])', s):    # a catalogue number, not a count
        if free(*m.span()):
            taken.append(m.span())
            found.append((m.group(0), [m.group(0)], '', 'identifier', m.start()))
    for m in re.finditer(r'(?<![\d.])\b(?:about |roughly |nearly |almost |some |only |just )?(one|two|three|four|five|\d+(?:\.\d+)?)\s+(?:in|out of)\s+(?:a |every |each )?([\d,]+|' + WORDS_ALT + r')\b', s, re.I):
        if not free(*m.span()):
            continue
        a = WORDNUM.get(m.group(1).lower()) or m.group(1)
        b = word_value(m.group(2)) or m.group(2).replace(',', '')
        taken.append(m.span())
        found.append((m.group(0), [fmt(a), fmt(b)], next_word(s, m.end()), 'ratio', m.start()))
    for m in re.finditer(r'\b' + ORD + r'[- ]' + SUPER + r'\b', s, re.I):
        if free(*m.span()):
            taken.append(m.span())
            found.append((m.group(0), [m.group(0).split()[0].split('-')[0].lower()], next_word(s, m.end()), 'rank', m.start()))
    for m in re.finditer(r'(?<![\w/.-])\$?\d+(?:,\d{3})*(?:\.\d+)?(?![\w])(?:\s?(?:%|per ?cent\b))?', s):
        if not free(*m.span()):
            continue
        tok = m.group(0).strip()
        num = re.sub(r'[^\d.]', '', tok)
        if not num or num == '.':
            continue
        taken.append(m.span())
        found.append((tok, [num.rstrip('.')], next_word(s, m.end()), 'numeral', m.start()))
    for m in re.finditer(WORDS_RE, s, re.I):
        if not free(*m.span()):
            continue
        w = m.group(0).lower()
        if w == 'one' and re.search(r'\b(?:no|any|every|each|some|the|this|that|which)\s+$', s[:m.start()], re.I) and \
                re.match(r'\s*(?:$|[,.;:)]|(?:that|which|who|whom|of|in|is|was|will|would|could|has|had|with|to|'
                         r'for|from|at|by|on|and|or|but|I|he|she|they|we|it)\b)', s[m.end():], re.I):
            continue                                           # "no one", "the one that", but not "the one measure"
        if w == 'one' and re.match(r'\s+(?:another|of (?:them|us|those|these))\b', s[m.end():], re.I):
            continue
        v = word_value(w)
        taken.append(m.span())
        found.append((m.group(0), [fmt(v)], next_word(s, m.end()), 'word', m.start()))
    return sorted(found, key=lambda x: x[4])


def norm_row(text):
    t = text.lower().replace('’', "'").replace('record group ', 'rg')
    t = re.sub(r'\brg\s+(\d)', r'rg\1', t)
    t = re.sub(r'(?<=\d),(?=\d{3})', '', t)
    for m in sorted(set(re.findall(r'\b' + TENS + r'-(?:' + '|'.join(ONES) + r')\b', t)), key=len, reverse=True):
        t = t.replace(m, fmt(word_value(m)))
    t = re.sub(WORDS_RE, lambda m: ' ' + fmt(word_value(m.group(0))) + ' ', t, flags=re.I)
    return t


def find_trace(text):
    """Every table under the heading that names the trace table, down to the next heading of the
    same or a higher level; in each, the overview's side is the column headed "overview", else the
    first. Returns (line of the first table, [[overview cell, other cells…], …])."""
    lines = text.splitlines()
    start, level = None, 0
    for i, l in enumerate(lines):
        m = re.match(r'^(#+).*trace', l, re.I)
        if m or re.match(r'^\*\*.*trace.*\*\*\s*$', l, re.I):
            start, level = i, len(m.group(1)) if m else 9
            break

    def tables(a, b):
        out, first, k = [], None, a
        while k < b:
            if not lines[k].lstrip().startswith('|'):
                k += 1
                continue
            first = k if first is None else first
            block = []
            while k < b and lines[k].lstrip().startswith('|'):
                cells = [c.strip() for c in lines[k].strip().strip('|').split('|')]
                if not all(re.fullmatch(r':?-{2,}:?', c) or c == '' for c in cells):
                    block.append(cells)
                k += 1
            if len(block) > 1:
                col = next((j for j, c in enumerate(block[0]) if 'overview' in c.lower()), 0)
                out += [[r[col]] + [c for j, c in enumerate(r) if j != col] if col < len(r) else r for r in block[1:]]
        return first, out

    if start is not None:
        end = next((k for k in range(start + 1, len(lines))
                    if re.match(r'^(#+)\s', lines[k]) and len(re.match(r'^(#+)', lines[k]).group(1)) <= level), len(lines))
        first, rows = tables(start + 1, end)
        if rows:
            return first, rows
    for i, l in enumerate(lines):                              # fallback: a table headed "overview"
        if l.lstrip().startswith('|') and 'overview' in l.lower():
            first, rows = tables(i, len(lines))
            if rows:
                return first, rows
    return None, []


def check(run_dir, trace_file=None, out_dir=None):
    run_dir = pathlib.Path(run_dir)
    ov = (run_dir / 'overview.md').read_text(errors='replace')
    trace_src = pathlib.Path(trace_file) if trace_file else run_dir / 'memo.md'
    header_line, rows = find_trace(trace_src.read_text(errors='replace')) if trace_src.exists() else (None, [])
    firsts = [norm_row(r[0]) if r else '' for r in rows]
    fulls = [norm_row(' | '.join(r)) for r in rows]
    result = []
    for s in sentences(clean_overview(ov)):
        for text, values, nxt, kind, pos in mentions_of(s):
            nxt_two = next_words(s, pos + len(text), 2) if nxt else []
            def holds(t, v):
                if kind == 'identifier':
                    return v in re.sub(r'\s', '', t)
                if kind == 'rank':
                    return v in t
                return re.search(r'(?<![\d.])' + re.escape(v) + r'(?![\d])', t) is not None
            # A small value (one to twelve) recurs in rows about other sets ("13 documents in 10 volumes"
            # beside "the ten volumes richest in it"), so it must be followed by the next TWO words.
            want = nxt_two if kind == 'word' or (values[-1].isdigit() and int(values[-1]) <= 12) else nxt_two[:1]

            def followed(t, v):
                """The value in the row's first column, followed within six words by the same words."""
                if kind in ('identifier', 'rank') or not want:
                    return holds(t, v)
                for m in re.finditer(r'(?<![\d.])' + re.escape(v) + r'(?![\d])', t):
                    words = [sing(w) for w in re.findall(r'[a-z][a-z-]*', t[m.end():])[:8] if w not in SKIP][:6]
                    if all(w in words for w in want):
                        return True
                return False
            cls, row = 'untraced', None
            for i, f in enumerate(firsts):
                if all(holds(f, v) for v in values) and followed(f, values[-1]):
                    cls, row = 'traced', i
                    break
            if cls != 'traced':
                for i, f in enumerate(fulls):
                    if all(holds(f, v) for v in values):
                        cls, row = 'weak', i
                        break
            result.append({'text': text, 'values': values, 'next': nxt, 'kind': kind, 'class': cls,
                           'row': (' | '.join(rows[row]))[:200] if row is not None else None, 'sentence': s})
    counts = {c: sum(1 for r in result if r['class'] == c) for c in ('traced', 'weak', 'untraced')}
    out = pathlib.Path(out_dir) if out_dir else run_dir / 'checks'
    out.mkdir(parents=True, exist_ok=True)
    payload = {'run': str(run_dir), 'traceSource': str(trace_src), 'traceTableLine': None if header_line is None else header_line + 1,
               'traceRows': len(rows), 'mentions': len(result), 'counts': counts, 'list': result}
    (out / 'o2p_flags.json').write_text(json.dumps(payload, indent=1, ensure_ascii=False) + '\n')
    txt = [f"O2' check of {run_dir.name}: {len(result)} numbers in overview.md; "
           f"{counts['traced']} traced, {counts['weak']} weak, {counts['untraced']} untraced.",
           ('TRACE TABLE: not found in ' + trace_src.name) if not rows else
           f'TRACE TABLE: {len(rows)} rows, from line {header_line + 1} of {trace_src.name}.',
           'Each flagged number is WEAK (a row holds the value without the word after it) or UNTRACED '
           '(no row holds the value). Decide each: TRACED (name the row), NOT A NUMBER, or UNTRACED.', '']
    for r in result:
        if r['class'] != 'traced':
            txt.append(f"[{r['class'].upper()}] {r['text']!r} (value {'/'.join(r['values'])}, next word {r['next']!r})"
                       + (f"; nearest row: {r['row']}" if r['row'] else ''))
            txt.append(f"    sentence: {r['sentence'][:400]}")
    (out / 'o2p_flags.txt').write_text('\n'.join(txt) + '\n')
    return payload


if __name__ == '__main__':
    args = sys.argv[1:]
    trace = out = None
    if '--trace' in args:
        k = args.index('--trace'); trace = args[k + 1]; del args[k:k + 2]
    if '--out' in args:
        k = args.index('--out'); out = args[k + 1]; del args[k:k + 2]
    p = check(args[0], trace, out)
    print(f"{p['mentions']} numbers: {p['counts']}; trace rows {p['traceRows']}")
