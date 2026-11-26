---
paths:
  - "SemanticVectorsKit/**"
  - "SemanticVectorsKitTests/**"
  - "SemanticVectorsGenerator*/**"
  - "FRUSExplorer/Semantic/**"
  - "FRUSCoreKit/Semantic/**"
---

# SemanticVectorsKit, the shards and their storage

Claude Code loads this file when a session reads or edits a file its `paths` name. `CLAUDE.md`'s
`SemanticVectorsKit` entry keeps the two rules to know before touching the kernel; this is the
whole entry, moved here from `CLAUDE.md`'s *Directory Map* word for word on 2026-11-26.

- `SemanticVectorsKit` — the semantic-vector artifact contract: binary layouts, the
  document-id run-length encoding that keys every row, mmap readers for the bundled
  corpus tier and the per-volume shards, and the retrieval kernel. Compiled into the app
  targets via `project.yml` (the WordCloudKit/FTS5Store pattern) **and** an SPM library
  target, so `SemanticVectorsGenerator` writes through the declarations the device reads
  through. **The kernel's tie-breaks are the measurement**: driving it over the shipped
  artifacts reproduces the corpus gates' reference neighbour lists in exact order for
  600/600 queries, so changing one silently invalidates the recall the artifact states.
  Two device-side rules worth knowing before touching it — a full corpus Hamming scan is
  1.43 ms and the whole funnel 2.44 ms (so no ANN index, measured rather than assumed) — but **both were measured at the 256 width**, and the bundle has shipped at 512 since #933: `Planning/semantic-vectors/Dimension-Ladder-Spike.md` drove this same kernel over both artifact sets and got a Hamming scan of 0.96–1.11 ms at 256 against **1.53–1.68 ms** at 512, and a whole funnel of ~1.03 ms against **~1.64 ms**, so the CONCLUSION survives the width change and neither quoted number does,
  and identity NEVER comes from a shard's position in local XML but always from the
  bundled index's segments, because a re-published volume changes the XML and not the
  artifact. App-side, `BundledSemanticVectors` (prepare()-shape loader, maps the 19.53 MB
  binary) and `SemanticShardStore` (filesystem-truthed, no SQLite registry — the app
  already reads downloaded-ness from disk, and a table would drift) are in
  `FRUSExplorer/Semantic/`, beside the map's loader (`Semantic/Map/BundledSemanticMap.swift`), whose load
  by URL and refusals are the kit's (`SemanticBundledMap`) since FRUS Explorer Light's S28a; the query encoder's model store (`SemanticModelStore`: the file's name,
  length and pin, the marker and the purge) is the kit's since FRUS Explorer Light's S27a, and its
  fetcher and the llama encoder are the app's. **Tier 2 now has a host**: `SemanticShardFetcher` fetches through
  `adoptShard(from:for:)`, which validates before it keeps, and `AppState.fetchSemanticShardIfNeeded`
  drives it on a deliberate split — **eagerly** when a volume downloads (~294 KB beside ~6 MB is
  invisible, and it makes the volume semantic-ready exactly when it becomes search-ready) and
  **lazily** for volumes already on disk, so an existing library does not silently pull 162 MB at
  launch for a feature the reader has not opened. **#900 added the storage UI**: one
  `SemanticStorageSection` mounted by *both* hubs (they are hand-maintained twins, so a section
  written twice is two places to drift), reporting disk usage against the published total, the
  problems the app has actually noticed, and a Remove control. **Two of its four figures are
  structurally partial** — a fetch failure lives only in memory for the session, and a refusal is
  recorded only for volumes something has already asked about — so the screen may say what it has
  noticed and may never say there is nothing wrong; `SemanticStorageReport` owns that distinction
  and its wording. **No progress is reported, deliberately**: the transfer is a one-shot
  `URLSession.download(from:)` with no callback, a shard is ~294 KB on average (988 KB at the largest), fetched in a fraction of a second, and the app
  shows no byte progress for the ~6 MB volume download beside it. **#926 added the controls**: a
  device-local `SettingsKeys.autoDownloadSemanticShards` (default ON, so its introduction changes
  nothing for anyone who never touches it) gating both automatic paths, and a manual **Download
  Missing Vectors** that ignores the switch — pressing a button is the consent it withholds. The
  preference is deliberately NOT on `SyncedPreferences`: a download policy is about one device's
  storage and network, and a stored property on a mirrored `@Model` would need a CloudKit
  Production deploy (the #488 gate) to ship. The manual run reports a **count** ("12 of 340"),
  which is observable where per-file bytes are not, and the missing count is computed over
  **downloaded volumes only** — `published − onDisk` would tell a 12-volume library it was missing
  544.
