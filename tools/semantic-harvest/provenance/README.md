# Harness revisions that produced stores, kept byte-for-byte

A harvest store's `run-manifest.json` records the SHA-256 of the scripts that wrote it. The early-era
NER sweep (#234 R-1) recorded two hashes that resolve to **no commit**: both scripts were edited and
run on the Mac Studio. They are kept here so the hash in the manifest resolves to bytes a reader can
open. Do not run them — the living scripts are one directory up.

| file | sha256 | what it produced |
|---|---|---|
| `13b70f9e-harvest_ner.py` | `13b70f9e2827a6ad48f2053a693fd87d29f614fd2bdfba4223587351f456d278` | the qwen3-14b `detected/` layer for volumes 28–267, 2026-08-31 → 09-10 (manifest `script_sha256`) |
| `77a1af99-harvest_embeddings.py` | `77a1af999923da6ba6b4f109c880285c46aec26fc833b58973085c24dffcdd0b` | the R-0 extraction recorded as `extractor_sha256` by the sweep and by the earlier marked-layer run |

**Not recoverable:** the revision that wrote volumes 1–27 (`frus1861` … `frus1872p2v5`, 2026-08-28 →
08-29). It predates the retry hardening — its heads carry no `failed_chunks` — and it was overwritten
on the Studio before anything hashed it. The manifest records only the last invocation's script.
NER-RUNBOOK.md §4.8.3 describes what that mixes into the store.

`../harvest_ner.py` is `13b70f9e`'s code with one later docstring correction re-applied (the
245,747 / 267-volume figure from commit 979aa413), so it deliberately does not hash to `13b70f9e`.
`../harvest_embeddings.py` is a different, later-dated revision (commit 31b001d0, 2026-09-02); it is
not a superset of `77a1af99` by construction, which is why that file is kept here rather than
assumed recoverable from history.
