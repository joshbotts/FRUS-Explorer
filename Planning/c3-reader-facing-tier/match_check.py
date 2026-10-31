#!/usr/bin/env python3
"""R8's occasions (Planning/C-3-Reader-Facing-Tier-Design.md §5.4). Reads queries.log and the run
directory's .sql, .py and .sh files (not the refuter's or the checks'), takes the terms of every MATCH
expression written as a literal, and counts each term alone against the index copy, read-only. A term
that returns no document is listed with the line that ran it and the nearest form that does. For each
prefix, says whether a frus_documents_vocab lookup of its stem comes before its first use in the log.
Terms passed to MATCH as query parameters are seen only when they carry a `*`.

    python3 match_check.py <run directory> [--out <dir>]"""
import ast, json, re, sqlite3, sys, pathlib

DB = '/Users/jbotts/frus-analysis/c3/frus-copy-2026-10-25.db'
SKIPDIRS = {'refuter', 'checks'}
LIT = re.compile(r"MATCH\s*\(?\s*(['\"])([^\n{}]{1,200}?)(?<!\\)\1")
OPS = {'AND', 'OR', 'NOT', 'NEAR'}


def sources(run):
    log = run / 'queries.log'
    out = [('queries.log', log.read_text(errors='replace'))] if log.exists() else []
    for p in sorted(run.rglob('*')):
        if p.is_file() and p.suffix in ('.sql', '.py', '.sh') and not (set(p.relative_to(run).parts) & SKIPDIRS):
            out.append((str(p.relative_to(run)), p.read_text(errors='replace')))
    return out


def py_prefix_literals(text):
    try:
        tree = ast.parse(text)
    except SyntaxError:
        return []
    out = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Constant) and isinstance(node.value, str) and len(node.value) <= 120:
            v = node.value
            if re.search(r'\w\*', v) and re.fullmatch(r'[\w\s"*()\'-]+', v) and 'MATCH' not in v:
                out.append(v)
    return out


def terms_of(expr):
    """Phrases in double quotes, prefixes and bare words; operators, NEAR groups and column filters
    dropped."""
    expr = re.sub(r'\b\w+\s*:\s*(?=["\w(])', ' ', expr.replace("''", "'"))
    out = []
    for m in re.finditer(r'"([^"]+)"(\*?)|([\w\'-]+\*?)', expr):
        if m.group(1) is not None:
            out.append(('"' + m.group(1).strip() + '"' + m.group(2)) if m.group(1).strip() else None)
        else:
            t = m.group(3)
            if t.upper().rstrip('*') in OPS or re.fullmatch(r'\d+', t):
                continue
            out.append(t)
    return [t for t in out if t]


def returns(con, term):
    q = term if term.startswith('"') else ('"' + term.rstrip('*') + '"' + ('*' if term.endswith('*') else ''))
    try:
        return con.execute('SELECT 1 FROM frus_documents WHERE frus_documents MATCH ? LIMIT 1', (q,)).fetchone() is not None, q
    except sqlite3.OperationalError as e:
        return None, f'{q} ({e})'


def nearest_live(con, term):
    base = term.strip('"').rstrip('*').rstrip('"')
    if ' ' in base:
        return None
    for k in range(len(base), 2, -1):
        ok, _ = returns(con, base[:k] + '*')
        if ok:
            return base[:k] + '*'
    return None


def check(run_dir, out_dir=None):
    run = pathlib.Path(run_dir)
    con = sqlite3.connect('file:' + DB + '?mode=ro', uri=True)
    srcs = sources(run)
    seen, rows = {}, []
    for name, text in srcs:
        exprs = [(m.group(2), text.count('\n', 0, m.start()) + 1) for m in LIT.finditer(text)]
        if name.endswith('.py'):
            exprs += [(v, None) for v in py_prefix_literals(text)]
        for expr, line in exprs:
            for t in terms_of(expr):
                key = t.lower()
                if key in seen:
                    continue
                ok, q = returns(con, t)
                seen[key] = ok
                rows.append({'term': t, 'source': name, 'line': line, 'returns': ok, 'query': q,
                             'nearestLive': nearest_live(con, t) if ok is False else None})
    log = next((t for n, t in srcs if n == 'queries.log'), '')
    loglines = log.splitlines()
    lookups = [i for i, l in enumerate(loglines) if 'frus_documents_vocab' in l]
    prefixes = []
    for r in rows:
        if not r['term'].endswith('*'):
            continue
        stem = r['term'].strip('"').rstrip('*').rstrip('"').lower()
        first = next((i for i, l in enumerate(loglines) if r['term'].lower() in l.lower()), None)
        before = [i for i in lookups if first is not None and i < first and stem[:max(3, len(stem) - 2)] in loglines[i].lower()]
        prefixes.append({'prefix': r['term'], 'firstLogLine': None if first is None else first + 1,
                         'vocabLookupBefore': (bool(before) if first is not None else None)})
    dead = [r for r in rows if r['returns'] is False]
    out = pathlib.Path(out_dir) if out_dir else run / 'checks'
    out.mkdir(parents=True, exist_ok=True)
    payload = {'run': str(run), 'termsTested': len(rows), 'dead': dead, 'syntaxErrors': [r for r in rows if r['returns'] is None],
               'prefixes': prefixes, 'vocabLookupsInLog': len(lookups), 'all': rows}
    (out / 'match_check.json').write_text(json.dumps(payload, indent=1, ensure_ascii=False) + '\n')
    txt = [f'Full-text terms in {run.name}: {len(rows)} tested alone against the index copy; {len(dead)} return no document. '
           f'{len(prefixes)} prefixes; {len(lookups)} frus_documents_vocab lookups in the log. '
           'Terms passed to MATCH as query parameters are seen only when they carry a `*`.', '']
    for r in dead:
        txt.append(f"DEAD {r['term']!r} ({r['source']}{':' + str(r['line']) if r['line'] else ''}); nearest form that returns documents: {r['nearestLive']}")
    for p in prefixes:
        txt.append(f"PREFIX {p['prefix']!r}: first in the log at line {p['firstLogLine']}; vocab lookup of its stem before it: {p['vocabLookupBefore']}")
    (out / 'match_check.txt').write_text('\n'.join(txt) + '\n')
    return payload


if __name__ == '__main__':
    args = sys.argv[1:]
    out = None
    if '--out' in args:
        k = args.index('--out'); out = args[k + 1]; del args[k:k + 2]
    p = check(args[0], out)
    print(f"{p['termsTested']} terms, {len(p['dead'])} dead: {[d['term'] for d in p['dead']][:12]}; "
          f"{len(p['prefixes'])} prefixes, {sum(1 for x in p['prefixes'] if x['vocabLookupBefore'])} looked up first")
