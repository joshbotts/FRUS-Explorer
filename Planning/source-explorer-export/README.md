# `source-explorer-export/` — a 2026-07-29 snapshot, not a current measurement

These files are the committed remainder of a `SourceExplorerExportGenerator` run (#335). **They
are a snapshot of the resolution landscape on 2026-07-29 and nothing keeps them current.** The
summary records `generated: 2026-07-29`, `recordCount: 264464`, `schemaVersion: 1` — and, being
the honesty gap this note exists to close, **it records nothing about which bundled artifacts it
resolved against.**

It matters because the artifacts moved underneath it. Measured 2026-08-26:

| | this export | bundled today |
|---|---|---|
| `central-files-index.json` | (unrecorded) | generated **2026-08-19**, **1,065** lot files |
| `collection-authority.json` | (unrecorded) | generated **2026-08-19**, **4,429** collections |

So every outcome tallied here — `resolvedLotBundle`, `noResolution`, `liveRouteOnly` — was
computed against an older, smaller lot index and a differently-clustered authority. The counts
are a record of what that run saw, not of what the app resolves now.

**The standing rule this snapshot is the reason for**, stated in CLAUDE.md's
`CollectionUsageIndexGenerator` entry: *never* build a downstream artifact from an existing
export. The authority is re-clustered independently, so ids do not survive between runs —
measured, the 2026-07-29 export against the 2026-08-06 authority carried 28 dead collection ids
covering 2,040 documents, including the largest presidential-library collection, because #696
folded `president's ` to `presidential `. Re-run the generator instead; it is offline and
deterministic.

**What is here, and what is not.** `source-explorer-export.json` (the full 264k-record ~182 MB
export) is gitignored and exists only on the machine that last ran the generator — the committed
files are the summary, the every-200th-record sample, and the two ranked TSVs. Regenerate all of
them with `swift run -c release SourceExplorerExportGenerator` (see CLAUDE.md for the env).
