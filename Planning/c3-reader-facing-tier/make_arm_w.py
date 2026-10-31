#!/usr/bin/env python3
"""Arm W of the reader-facing tier (Planning/C-3-Reader-Facing-Tier-Design.md §2.2): the guide's v1.39
candidate W, made from the guide at v1.38 (848f3781) by exact, once-only replacements:
  R1  the §12 block's READER-FACING OUTPUT section replaced by the style review's §4 text at 848f3781;
  R2  §14.16's template: part 1 about 150 words, part 2 as bulleted lists, a Documents cited list;
  R6  the vocabulary bullet (R16's arm B, the last bullet of its SEMANTIC VECTORS section) appended to
      §A.8's addendum;
and a version-history entry that marks it a candidate. Writes guides/W.md."""
import pathlib, subprocess

REPO = '/Users/jbotts/Development/FRUS-Explorer/.claude/worktrees/elastic-kowalevski-07a5ac'
BASE = '848f3781'
OUT = pathlib.Path('/Users/jbotts/frus-analysis/c3f/guides/W.md')

def show(path):
    return subprocess.run(['git', '-C', REPO, 'show', f'{BASE}:{path}'], capture_output=True, text=True, check=True).stdout

g = show('Docs/Agentic-Analysis-Guide.md')
review = show('Planning/Agentic-Guide-Reader-Facing-Style-Review-2026-10-30.md')

def once(old, new):
    global g
    n = g.count(old)
    assert n == 1, (n, old[:80])
    g = g.replace(old, new)

# R1: the section, cut from the block and from the review by marker
b0 = g.index('\n## 12. A house-rules block to paste into your agent')
i = g.index('READER-FACING OUTPUT —', b0)
j = g.index('\n\nSCOPING —', i)
SECTION_OLD = g[i:j].rstrip('\n') + '\n'
a = review.index('```text\nREADER-FACING OUTPUT') + len('```text\n')
b = review.index('\n```\n', a)
R1 = review[a:b].rstrip('\n') + '\n'
assert SECTION_OLD.count('\n') == 17 and R1.count('\n') == 30, (SECTION_OLD.count('\n'), R1.count('\n'))
once(SECTION_OLD, R1)

# R2: §14.16's template (no prompt carries it; it makes "W goes into the guide as its text" literal)
once('   document is not a finding and does not go here.\n',
     '   document is not a finding and does not go here. It is one paragraph of about 150 words.\n')
once("   by the Carter Library's National Security Affairs files: that is the paragraph.\n",
     "   by the Carter Library's National Security Affairs files: that is the paragraph. In the\n"
     "   overview the two lists are bulleted, one series to a line.\n")
once("floor), the raw log beside it; and **read next**: the collection, by name, what the historian's\n"
     "additions would unlock, and what they can do next in the app.\n",
     "floor), the raw log beside it; **read next**: the collection, by name, what the historian's\n"
     "additions would unlock, and what they can do next in the app; and **documents cited**: every\n"
     "document the overview cites, once each, in full as the printed edition (§8) with its\n"
     "history.state.gov URL, in the order first cited. In the text a document is cited by year,\n"
     "volume and document number, and this list resolves the short form.\n")

# R6's vocabulary bullet, at the end of §A.8's addendum
BULLET = ('- None of this vocabulary reaches the overview or the collection: no Hamming, cosine, cluster\n'
          '  number, "vector" or "neighbour at N". Say "found by its similarity to [the document], by no word\n'
          '  search, and read before it was cited".\n')
once('  (§A.7), or is labelled raw. Four runs of four skipped this in the 2026-10-27 measurement.\n```\n',
     '  (§A.7), or is labelled raw. Four runs of four skipped this in the 2026-10-27 measurement.\n'
     + BULLET + '```\n')

# The version history
once('- 1.38 — 2026-10-30:', """- 1.39 (candidate W) — 2026-10-31: **arm W of the reader-facing tier**, on a branch of its own
  and not adopted (`Planning/C-3-Reader-Facing-Tier-Design.md` §2.2). The §12 block's READER-FACING
  OUTPUT section becomes the style review's R1 (30 lines, its numbers bullet as revised after the
  pilot); §14.16's template takes R2 (part 1 about 150 words, part 2 as bulleted lists, a closing
  Documents cited list); §A.8's addendum gains R6's vocabulary bullet. Measured against v1.38 by the
  reader-facing tier, and merged only if its readings adopt it. The §15.1 and §15.1a blocks are
  unchanged.
- 1.38 — 2026-10-30:""")

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(g)
print('wrote', OUT, len(g.splitlines()), 'lines')
