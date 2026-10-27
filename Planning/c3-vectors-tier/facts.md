# C-3 vectors tier — run record (guide §13)

- Design: `Planning/C-3-Vectors-Tier-Design.md`; the owner's four decisions of 2026-10-26 at its head.
- Question (the owner's, verbatim, 2026-10-26): "how have u.s. policymakers' thinking about cuba's
  impact on national security and prosperity changed since the 1870s?" (`question.txt`). The owner
  weighed it against a second candidate ("when have u.s. decision makers chosen policies to
  strengthen american legitimacy and did those choices generate tangible subsequent benefits?"),
  which has no seed set and no scope for a document-to-document run.
- Index copy: C-3's, `~/frus-analysis/c3/frus-copy-2026-10-25.db` (version 71, 553 volumes); the app
  still 1.0 (1776). TEI and bundled JSON as C-3. Shards: `~/frus-analysis/c3/SemanticVectors/`, 553
  files, 156 MB, copied 2026-10-26 23:07 with the app not running; `.generation`, the index, the shards
  manifest and the binary's header all carry digest 89481b18….
- Guide: v1.35 at the time of generation (Appendix A's worked figures re-taken at this digest on
  2026-10-26, after `appendix_recheck.py` found them to be the 300m generation's; `vectors_check.py`
  holds the canary's known answer). The appendix in the prompt: 328 lines, sha256 ad397712ca8c03d6.
- Rubric: C-3's 35 items plus V1–V6 = 41. Keymap: O-med+V (1) v2, S-high+V (1) v3, O-med+V (2) v4,
  S-high+V (2) v1 (random.Random(20261026)); calv = C-3's r5 scored with the 41 items.
- Tooling note added to the prompt: Python 3.9 has no int.bit_count().
- Budget: the owner's line, 92% of the weekly meter (80% at the decisions); ask before stopping.
