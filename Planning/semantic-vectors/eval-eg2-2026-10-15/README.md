# The 25 judged queries through EmbeddingGemma 2 — a sheet to judge

**Date:** 2026-10-15 · **For:** plan of record Track B, step B3 (#1659) · **Memo:**
`../EmbeddingGemma-2-Stage-2-2026-10-15.md` §6 · **The sitting this extends:** `../eval-2026-08-27/`

`RetrievalEvalHarness`, unchanged, ran the owner's 25 queries of 2026-08-27 through EmbeddingGemma 2:
`llama-server` at llama.cpp `a0e6dc73` serving `embeddinggemma-2-Q8_0.gguf` (SHA-256 `2188ac1d…`), the
query prompt the sitting judged (`task: search result | query: `), and the shipping funnel at 512 over
the scratch pack of B2 (provenance digest `89481b18…`; Hamming over 512 sign bits, a pool of 800, an
int8-512 rerank). `report.md` is its report; `stats.json` its counts.

**What to judge.** The `semantic` rows of `verdicts.csv` whose `relevant` is blank: **183 of 250**. Use
the August rubric, at the top of `report.md`: *would you open this document while pursuing this
question?* 1, 0, or blank when the row's evidence underdetermines it.

**What is already filled in.** Every row whose query and document the 2026-08-27 sitting judged carries
that judgment, as that sitting carried a judged value across routes: 67 semantic rows, 131 lexical and
55 PRF. The lexical rows are the August ones again (the lexical route did not change); the PRF rows
are the August route through the new model's vectors, and judging their blanks is optional.

**Why the old sheet cannot score the new model.** EmbeddingGemma 2 shares on average 3.6 of its ten
documents a query with the 300m's ten. With the 183 rows unjudged its precision lies anywhere between
0.236 and 0.968 and its MRR between 0.545 and 0.980, so the sitting cannot rank the two models until
they are judged. The 300m's own figures, re-run the same day through the same runtime, reproduce the
August sitting's (precision 0.652 over judged rows, MRR 0.771).

Once judged, `../eg2-b2-2026-10-15/score_judged.py` (run from the repository root, with its paths
pointed at this file) gives the comparison by register.

---

Version history:
  1.0 — 2026-10-15: the sheet, written for B3 with the August judgments carried over.
