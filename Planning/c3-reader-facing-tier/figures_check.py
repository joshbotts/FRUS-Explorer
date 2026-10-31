#!/usr/bin/env python3
"""R7's occasions (Planning/C-3-Reader-Facing-Tier-Design.md §5.4). Lists each occurrence, in memo.md
and overview.md, of a measurement figure the arm's house rules print, with its sentence. The refuter
decides whether each is re-derived, attributed, or presented as the session's own finding.

    python3 figures_check.py <run directory> <arm: A, W or K> [--out <dir>]"""
import json, re, sys, pathlib

COMMON = [('74,043 (the 1940s dated documents)', r'\b74,043\b'), ('5,798 (the 1870s dated documents)', r'\b5,798\b'),
          ('14% (the counting surfaces)', r'\b14\s?(?:%|per ?cent)'), ('4-10% (persName coverage)', r'\b4\s?[-–]\s?10\s?(?:%|per ?cent)'),
          ('56% (creator attribution)', r'\b56\s?(?:%|per ?cent)'), ('718 (the Ed2 overlap, vectors)', r'\b718\b'),
          ('701 (the Ed2 overlap, index)', r'\b701\b'), ('35,125 / 36,615 (characters and bytes)', r'\b35,125\b|\b36,61[56]\b'),
          ('1910-12-06 (the pointed-at channel starts)', r'1910-12-06|6 December 1910|December 6, 1910')]
ARCH = {'A': ('11 of 695 (series before 1940)', r'\b11\s+of\s+695\b|\b695\b'),
        'W': ('11 of 695 (series before 1940)', r'\b11\s+of\s+695\b|\b695\b'),
        'K': ('one bundled series in sixty (series before 1940)', r'one (?:bundled )?series in sixty|\bone in sixty\b|\b1 in 60\b')}


def check(run_dir, arm, out_dir=None):
    run = pathlib.Path(run_dir)
    figs = COMMON + [ARCH[arm]]
    hits = []
    for name in ('memo.md', 'overview.md'):
        p = run / name
        if not p.exists():
            continue
        for n, line in enumerate(p.read_text(errors='replace').splitlines(), 1):
            for label, pat in figs:
                for m in re.finditer(pat, line):
                    hits.append({'file': name, 'line': n, 'figure': label, 'match': m.group(0),
                                 'context': line[max(0, m.start() - 220): m.end() + 220].strip()})
    out = pathlib.Path(out_dir) if out_dir else run / 'checks'
    out.mkdir(parents=True, exist_ok=True)
    (out / 'figures_check.json').write_text(json.dumps({'run': str(run), 'arm': arm, 'occurrences': hits}, indent=1, ensure_ascii=False) + '\n')
    txt = [f"The house rules' figures in {run.name}'s memo and overview: {len(hits)} occurrences. A number that only "
           "coincides with one of them (a document number, say) is not one of them.", '']
    for h in hits:
        txt.append(f"{h['file']}:{h['line']} {h['figure']} [{h['match']}]: …{h['context']}…")
    (out / 'figures_check.txt').write_text('\n'.join(txt) + '\n')
    return hits


if __name__ == '__main__':
    args = sys.argv[1:]
    out = None
    if '--out' in args:
        k = args.index('--out'); out = args[k + 1]; del args[k:k + 2]
    h = check(args[0], args[1], out)
    print(len(h), 'occurrences:', sorted({x['figure'] for x in h}))
