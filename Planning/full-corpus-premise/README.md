# The full-corpus premise — the record of the measurements of 2026-11-02

Assessment: `../Agentic-Guide-Full-Corpus-Premise-Assessment-2026-11-02.md`. Every figure in its §2
comes from a script here, run read-only on the owner's Mac (Apple M5, 10 cores, 32 GB, macOS 27.2,
Python 3.9.6) on 2026-11-02 between 21:41 and 21:56 EST. No agent ran and nothing was written
outside this folder and the session's scratchpad.

**The inputs.** The app data folder is the sandbox container's
`~/Library/Containers/bottsywattsy.FRUS-Explorer/Data/Library/Application Support/FRUSExplorer/`,
whose TEI folder is spelled `volumes/` on disk. The bundle is the installed 1.0 (1787),
`/Applications/FRUS Explorer.app/Contents/Resources/`. The index copy is C-3's,
`~/frus-analysis/c3/frus-copy-2026-10-25.db` (a `.backup` of the live index at version 71, 553
volumes, `journal_mode=DELETE`), opened with `?mode=ro`; the live `frus.db` was not opened.

**The scripts, and what each wrote:**
- `sizes.py` → `sizes.out`: bytes and file counts of every surface (§2.1).
- `tei_pass.py` → `tei_pass.tsv` and `tei_pass.out`: one `ElementTree` pass over the manifest's 553
  files, timed per file, run through `Scripts/heavy.sh` from 21:41:59 to 21:42:50 (§2.2, §2.4). The
  `.tsv` has one row per volume: bytes, parse and walk seconds, document divisions by subtype, the
  two kinds of `<graphic>`, and the characters of body, source-note and other-note text.
- `ids.py` → `ids-volumes.tsv` and `ids.out`: the TEI's document ids against the vector index's
  decoded segments and the index copy's rows, volume by volume, through `Scripts/heavy.sh` (§2.3).
  Its first run printed the same three lines in 28.5 s; `ids.out` is the second, at 21:55.
- `checks.py` → `checks.out`: the smaller checks in one run — the footnote share by era band, the
  second editions' overlap, the guide's document predicate against the TEI, the undated rows, the
  TEI files against the manifest's `sizeBytes`, the shards against their manifest, and the encoder
  against its pin (§2.3, §2.4, §5.7).

To run again: `python3 -I <script>` with the arguments its header names. `tei_pass.py` and `ids.py`
each read the whole 3.34 GB of TEI, so run them through `Scripts/heavy.sh`.
