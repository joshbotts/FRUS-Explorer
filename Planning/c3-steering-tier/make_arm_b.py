#!/usr/bin/env python3
"""Arm B of the steering tier (C-3-Steering-Tier-Design.md §2.2): the guide's v1.38 candidate, made
from the guide as it stands (v1.37, with the owner's 2026-10-30 answers recorded) by exact,
once-only replacements. Writes the candidate to ~/frus-analysis/c3s/guide/Agentic-Analysis-Guide.md."""
import pathlib, sys

SRC = pathlib.Path(sys.argv[1])
OUT = pathlib.Path('/Users/jbotts/frus-analysis/c3s/guide/Agentic-Analysis-Guide.md')
g = SRC.read_text()

def once(old, new):
    global g
    n = g.count(old)
    assert n == 1, (n, old[:80])
    g = g.replace(old, new)

# §3a: the block's section applies, and a prompt carries the card
once("""and this appendix, paste §A.8's addendum into the §12 block, and expect few cited documents to be
reachable no other way:""",
"""and Appendix A's operating card ([§A.9](#a9-the-vectors-operating-card)), with the guide as a file
for the rest of the appendix; the §12 block's SEMANTIC VECTORS section applies. Expect few cited
documents to be reachable no other way:""")
once("""§A.7's last paragraph, the calibration offsets on a cosine the reader sees, which the addendum now
states.""",
"""§A.7's last paragraph, the calibration offsets on a cosine the reader sees, which the block's
SEMANTIC VECTORS section now states.""")

# R8: KNOWN TRAPS, after the stemming bullet
once("""      number a reader must be able to re-derive from what you printed; it is not a claim.
""",
"""      number a reader must be able to re-derive from what you printed; it is not a claim.
- A `term*` prefix is matched against STEMS: `normaliz*` cannot reach `normalization` (stem
  `normal`), and `communis*` misses `communism` (stem `commun`) while it still returns every
  `communist`. Look the stem up in frus_documents_vocab and write the prefix no longer than it.
""")

# R10 and R7: REPORTING
once("""- If a query returns no rows, say so explicitly and verify the query can return rows at all
  before drawing any conclusion from the emptiness.
""",
"""- If a query returns no rows, say so, and print beside it the relaxed form of the same query, on
  the same surface, that did return rows (drop one term, or widen the date), with its count. A
  zero printed with no such query beside it is an assertion, not a measurement.
- A figure you take from these rules or from the guide is the guide's measurement at its date,
  not yours: re-derive it or attribute it, and never present it as a result of this session.
""")

# R5: the Ed2 line
once("""  counted: the overlap is 718 documents in the vector artifacts and 701 in this index with
  apparatus excluded.
""",
"""  counted: the overlap is 718 documents in the vector artifacts and 701 in this index with
  apparatus excluded. With the vector artifacts in hand, the SEMANTIC VECTORS section's
  near-duplicate check finds the reprints the ids do not.
""")

# R7: ARCHIVAL SCOPE's figure
once("""- The offline stack barely reaches before 1940 (11 of 695 bundled series). Say so rather than
  reporting an empty pre-war roadmap as an archival absence.
""",
"""- The offline stack barely reaches before 1940: the guide counted about one bundled series in
  sixty starting before 1940. Re-derive the figure from series-facts-index.json before you print
  one, and say so rather than reporting an empty pre-war roadmap as an archival absence.
""")

# R6: the SEMANTIC VECTORS section, inside the block after ARCHIVAL SCOPE
SECTION = """
SEMANTIC VECTORS — only when your brief hands you the artifacts of Appendix A. If it does not, run
none of this and write "VECTORS: none" in the memo.
- Before any scoring, print the provenance digest from every artifact you touch and say they agree;
  on a mismatch stop. Identity comes ONLY from semantic-vectors-index.json's id segments: show the
  round trip (decoded length = n for every volume). Never an ordinal, a rowid or a shard's position.
- Compute both baselines at this digest before reading any distance: random pairs (mean, sd, 1st
  percentile) and the k-th-neighbour distribution over a random sample. Read one neighbour against
  the second and a set's cohesion against the first. The figures in the guide are one generation's.
- REQUIRED: for one anchor per era or finding, the nearest 10 to 25 by Hamming over the corpus
  binary, each joined on BOTH keys to document_dates and document_cache and flagged three ways: in
  your scope set or outside it; the anchor's decade or another; the question's literal present in
  its text or absent. A neighbour flagged outside or absent is the candidate the vectors exist to
  find: read it whole before the scope closes, and if it bears on the question add it to the scope
  and the collection.
- REQUIRED: before any count over a set you built, each member's nearest-neighbour distance in the
  set. Read both documents of every pair closer than the random-pair mean less eight sd at this
  digest, and count a pair as one document printed twice only when the two texts agree. Cite one
  copy, say which, and count it once.
- CONDITIONAL: the map, only to test whether the subject forms a region (one label test), and any
  cluster figure with the set's unclustered share, N of M, against an era-matched baseline on this
  layout, or no cluster figure.
- Head the VECTORS section "All cosines below are raw." If you compare a cosine with the app's
  percentage, apply the index's retrieval.scoreCalibration offsets to it and say so.
- A neighbour is a reading lead, never evidence: no claim in the overview rests on a distance.
  Tier 1 covers all 553 volumes even when this database does not: flag a neighbour whose volume is
  absent from document_cache and cite it by its history.state.gov URL. Absence of a neighbour
  proves nothing: the index's retrieval block states the funnel's measured recall.
- Say which cited documents were vector-reached, in both readings: STRICT, returned by no query you
  logged (re-run them against the pair and show it); PRACTICAL, in no result set you had read when
  the neighbour list surfaced it. A document inside your own heading scope is practical at most.
- None of this vocabulary reaches the overview or the collection: no Hamming, cosine, cluster
  number, "vector" or "neighbour at N". Say "found by its similarity to [the document], by no word
  search, and read before it was cited".
"""
once("""  fragment, not the sentence, and holds lot, library and decimal anchors only. Say so before
  ranking anything on it.
```
""",
"""  fragment, not the sentence, and holds lot, library and decimal anchors only. Say so before
  ranking anything on it.
""" + SECTION + """```
""")

# The surface table gains the section's row
once("""| ARCHIVAL SCOPE: a `[HARVEST]` count | **The offline record-group harvest**, only when the brief names its path | Say the surface is unavailable. A bundled count is a projection of it, not a substitute — see [§14.11](#1411-the-second-half-of-scoping-where-the-documents-came-from-and-point-at). |
""",
"""| ARCHIVAL SCOPE: a `[HARVEST]` count | **The offline record-group harvest**, only when the brief names its path | Say the surface is unavailable. A bundled count is a projection of it, not a substitute — see [§14.11](#1411-the-second-half-of-scoping-where-the-documents-came-from-and-point-at). |
| SEMANTIC VECTORS | **The bundled vector artifacts** ([Appendix A](#appendix-a-the-semantic-vector-artifacts)), only when the brief hands them over | Write "VECTORS: none" and run none of the section. |
""")

# §A.8: the addendum becomes a pointer to the block
a = g.index('A short addendum for the §12 house-rules block, when a session touches the vectors.')
b = g.index('```text\nSEMANTIC VECTORS\n', a)
c = g.index('\n```\n', b + 10) + len('\n```\n')
assert g.count('A short addendum for the §12 house-rules block') == 1
g = g[:a] + """The rules for a session that touches the vectors are the §12 block's SEMANTIC VECTORS section,
which replaced the addendum this paragraph carried until v1.38. What to run, and when, is
[§14.17](#1417-the-second-finding-aid-when-the-vectors-enter-the-pass), and what a prompt carries of
this appendix is [§A.9](#a9-the-vectors-operating-card)'s card.
""" + g[c:]

# R15: §A.9, the operating card, at the end of Appendix A
CARD = (pathlib.Path(__file__).parent / 'card.md').read_text()
once('\n## Glossary\n', '\n' + CARD.rstrip('\n') + '\n\n---\n\n## Glossary\n')

# The version history
once('- 1.37 — 2026-10-29:', """- 1.38 (candidate) — 2026-10-30: **arm B of the steering tier**, on a branch of its own and not
  adopted (`Planning/C-3-Steering-Tier-Design.md` §2.2, on the owner's answers of 2026-10-30). The
  §12 block gains a SEMANTIC VECTORS section: the review's R6, with centroid similarity cut and the
  near-duplicate line at the random-pair mean less eight sd. It also gains R5's clause on the Ed2
  line, R7's figure as the guide's measurement with its REPORTING rule, R8's prefix-on-stem trap
  (looked up in `frus_documents_vocab`, which the review had called the `terms` table) and R10's
  zero rule. Appendix A gains §A.9, the operating card a prompt carries in place of the appendix;
  §A.8's addendum becomes a pointer to the block, and §3a says the section applies. Measured against
  v1.37 by the steering tier, and merged only if its readings adopt it. The §15.1 and §15.1a
  blocks are unchanged.
- 1.37 — 2026-10-29:""")

OUT.write_text(g)
print('wrote', OUT, len(g.splitlines()), 'lines')
