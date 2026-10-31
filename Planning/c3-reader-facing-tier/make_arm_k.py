#!/usr/bin/env python3
"""Arm K of the reader-facing tier (Planning/C-3-Reader-Facing-Tier-Design.md §2.3): the guide's v1.39
candidate K, made from the guide at v1.38 (848f3781) by R16's make_arm_b.py replacements for R8, R10
and R7, unchanged, and a version-history entry that marks it a candidate. Writes guides/K.md."""
import pathlib, subprocess

REPO = '/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/elastic-kowalevski-07a5ac'
BASE = '848f3781'
OUT = pathlib.Path('/Users/jbotts/frus-analysis/c3f/guides/K.md')
g = subprocess.run(['git', '-C', REPO, 'show', f'{BASE}:Docs/Agentic-Analysis-Guide.md'],
                   capture_output=True, text=True, check=True).stdout

def once(old, new):
    global g
    n = g.count(old)
    assert n == 1, (n, old[:80])
    g = g.replace(old, new)

# R8: KNOWN TRAPS, after the stemming bullet (make_arm_b.py, unchanged)
once("""      number a reader must be able to re-derive from what you printed; it is not a claim.
""",
"""      number a reader must be able to re-derive from what you printed; it is not a claim.
- A `term*` prefix is matched against STEMS: `normaliz*` cannot reach `normalization` (stem
  `normal`), and `communis*` misses `communism` (stem `commun`) while it still returns every
  `communist`. Look the stem up in frus_documents_vocab and write the prefix no longer than it.
""")

# R10 and R7: REPORTING (make_arm_b.py, unchanged)
once("""- If a query returns no rows, say so explicitly and verify the query can return rows at all
  before drawing any conclusion from the emptiness.
""",
"""- If a query returns no rows, say so, and print beside it the relaxed form of the same query, on
  the same surface, that did return rows (drop one term, or widen the date), with its count. A
  zero printed with no such query beside it is an assertion, not a measurement.
- A figure you take from these rules or from the guide is the guide's measurement at its date,
  not yours: re-derive it or attribute it, and never present it as a result of this session.
""")

# R7: ARCHIVAL SCOPE's figure (make_arm_b.py, unchanged)
once("""- The offline stack barely reaches before 1940 (11 of 695 bundled series). Say so rather than
  reporting an empty pre-war roadmap as an archival absence.
""",
"""- The offline stack barely reaches before 1940: the guide counted about one bundled series in
  sixty starting before 1940. Re-derive the figure from series-facts-index.json before you print
  one, and say so rather than reporting an empty pre-war roadmap as an archival absence.
""")

once('- 1.38 — 2026-10-30:', """- 1.39 (candidate K) — 2026-10-31: **arm K of the reader-facing tier**, on a branch of its own
  and not adopted (`Planning/C-3-Reader-Facing-Tier-Design.md` §2.3). The §12 block gains the
  steering review's R8 (the prefix-on-stem trap, looked up in `frus_documents_vocab`), R10 (a zero
  printed beside the relaxed query that returns rows) and R7 (ARCHIVAL SCOPE's figure as the
  guide's measurement, and the REPORTING rule to re-derive or attribute a figure taken from the
  guide), as the steering tier's arm B carried them. Measured against v1.38 by the reader-facing
  tier, and merged only if its readings adopt it. The §15.1 and §15.1a blocks are unchanged.
- 1.38 — 2026-10-30:""")

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(g)
print('wrote', OUT, len(g.splitlines()), 'lines')
