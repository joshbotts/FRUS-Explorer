# EditableContent — Repository README

Part of the owner’s editing surface, `Docs/EditableContent/` (read `README.md` there first). Covers §8. Every block’s text is what the app ships after lane WB wrote your 2026-09-30 review back (the build-49 wave); the ✎ boxes that listed your unlanded 2026-09-21 edits are gone, each adopted where you changed its block and dropped where you left it alone. Section numbers are the ones the single file used, so references like “§18’s rule” still point somewhere.

**In this file:** 1 blocks · no ✎ edits held · no ⚑ wording issues

---

## 8. Repository README

*The public-facing description of the project at `README.md` — the first thing anyone sees on the
repository. It is prose you may want to rewrite, so it round-trips here like everything else.*

*Unlike every other block in this file, this one is the **whole file**, not a string inside Swift
source. Edit it freely; the whole thing is written back to `README.md`.*

*Condensed 2026-08-02 (build 37) from 385 lines to 162. The review that drove it found eleven false
or stale claims — a search cap that had doubled, a ⌘F shortcut that had moved to ⌘S, a window-scene
table missing eleven scenes and naming one that no longer exists, a "600+ tests" count that
understated by four times, and a pbxproj UUID convention that does not exist. The rule that keeps it
short: **build, test and generator commands live in `CLAUDE.md`, and features live in the user
manuals.** The README points at both rather than restating either, so there is only one copy of each
to keep correct.*

<!-- SOURCE: README.md | key: repo.readme | whole-file -->

# FRUS Explorer

A macOS, iPadOS, and iOS application providing tools to help researchers use the
[Foreign Relations of the United States (FRUS)](https://history.state.gov/historicaldocuments)
series more effectively.

FRUS is the official documentary record of U.S. foreign policy since 1861. The app's bundled
manifest covers 553 volumes; a full local index holds roughly 317,000 documents. FRUS Explorer
downloads the Office of the Historian's TEI editions, indexes them on your device, and adds the
reading, searching, sourcing and analysis tools a corpus that size needs — all of it working
offline once volumes are downloaded.

It is an independent project, developed with [Claude Code](https://claude.ai/code), and is **not**
an official product of the Office of the Historian or the U.S. Department of State. Current build:
**48** (version 0.2).

## Screenshots

| Search (macOS) | Cross-reference graph (macOS) | Semantic map (iPad) |
|---|---|---|
| ![Search results with facets and filters](Docs/screenshots/macos/search.png) | ![Cross-reference graph](Docs/screenshots/macos/cross-reference-graph.png) | ![Semantic map](Docs/screenshots/ipad/semantic-map.png) |

More in [`Docs/screenshots/`](Docs/screenshots).

## What it does

- **Read** — TEI documents rendered with footnotes, page breaks, and live cross-references, plus
  highlights, notes, and a per-document Research rail.
- **Search** — full-text keyword FTS5/BM25 search with stemming, phrases, `NEAR(...)` proximity, `=exact` word matching, saved scopes, and working corpora captured from a result set. Semantic search relies on an optional query encoder download to execute natural language queries against vector embeddings.
- **Read a result set four ways** — ranked list, timeline, concordance (every hit lined up on the
  search term), and collocates (the words that keep company with it).
- **Inspect the query** — the Query Inspector shows the FTS5 expression your search actually became,
  each term's index form, and its corpus-wide versus in-scope counts.
- **Facet** — break a result set down by year, volume, person, document type, and archival
  provenance; sort, page, and filter each breakdown; tap a row to narrow.
- **Analyze** — corpus, series, person, and cross-reference dashboards; a chronology view; and a
  word cloud with keyness and collocation.
- **Trace sources** — Source Explorer resolves FRUS source notes to NARA record groups, lot files,
  and collections, with archival neighbors and cross-volume provenance, from bundled indexes.
  Where the records are **not** at the National Archives it names the institution that holds them
  — including two that have been renamed since FRUS printed them — rather than returning
  catalog rows that cannot be right.
- **Organize** — projects, collections, exports (PDF, HTML, Word, BibTeX, RIS), Zotero, a research
  trail, and iCloud sync of your own work.
- **Summarize** — on-device Apple Intelligence summaries, one document at a time or as unattended
  bulk runs, with authorship recorded on every summary.

For anything beyond this list, read the user manuals — they are the feature documentation.

## Requirements

**To run**

- iPhone or iPad on iOS/iPadOS 26, or a Mac on macOS 26.
- An iCloud account is optional; with one, your notes, tags, collections, and projects sync via
  CloudKit and the iCloud key-value store.
- On-device summarization requires an Apple Intelligence–capable device.
- A NARA Catalog API key is optional. The bundled archival indexes resolve with no network and no
  key; a key adds live catalog lookups.

**To build**

- Xcode 26 or later, Swift 6.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — `project.yml` is the source of truth for the Xcode project.
- An Apple Developer account for signing, with iCloud/CloudKit, Keychain Sharing, and Background
  Modes capabilities.

## Getting the app

Test builds are distributed through TestFlight:

- [TestFlight instructions — iPhone and iPad](Docs/TestFlight-Instructions-ios.md)
- [TestFlight instructions — Mac](Docs/TestFlight-Instructions-mac.md)

## Documentation

- [iOS / iPadOS User Manual](Docs/iOS-User-Manual.md) — the full feature documentation.
- [macOS User Manual](Docs/macOS-User-Manual.md) — the same, for the Mac app.
- [Agentic Analysis with the FRUS Explorer Database](Docs/Agentic-Analysis-Guide.md) — for researchers pointing an AI agent at the local SQLite index: schema reference, working query patterns, the ways the data will quietly mislead you, and how to keep provenance intact.
- [`Planning/FRUS-Explorer-Specification.md`](Planning/FRUS-Explorer-Specification.md) — the original design specification.
- [`CLAUDE.md`](CLAUDE.md) — build, test, and data-generator commands; coding standards; release gates. This is the maintainer's reference and the canonical copy of every command.

## How it works

Volumes are TEI XML files published by the Office of the Historian. The app downloads them per
volume, parses each into an abstract syntax tree, and serializes that to HTML rendered in a web
view — so footnotes, page breaks, and internal references keep their editorial structure rather
than being flattened into plain text.

Search is SQLite FTS5 with BM25 ranking and English stemming, built on device as volumes finish
downloading. Semantic features rely on vector embeddings generated ahead of time with Google's
EmbeddingGemma model; searching by meaning runs the same model on your device. Everything you
write — notes, tags, highlights, collections, projects, prompts — lives
in SwiftData and syncs through CloudKit; nothing you write leaves your devices for a server we run.
Summarization uses Apple's on-device `FoundationModels` framework, so document text is never sent
off the device.

The archival layer is bundled and offline. Indexes built ahead of time from the NARA Catalog and
from the volumes' own front-matter source sections — central files, lot files, collection authority,
per-volume provenance — ship inside the app and resolve without a network call or an API key. The
tools that generate them live in `Package.swift` as SPM targets; their invocations and environment
variables are documented in `CLAUDE.md`.

## Building

`project.yml` is the source of truth for the Xcode project; regenerate with XcodeGen after changing
it. **`xcodegen generate` deletes `FRUSExplorer.xcodeproj/xcshareddata/xcschemes/` and regenerates
the schemes with incorrect values — always restore them afterwards with
`git checkout -- FRUSExplorer.xcodeproj/xcshareddata/xcschemes/`.** Build and version bumps must not go through XcodeGen at all; see `CLAUDE.md` for that procedure.

Two shared schemes: `FRUSExplorer` (iOS/iPadOS) and `FRUSExplorerMac`. Test, generator, and release
commands all live in [`CLAUDE.md`](CLAUDE.md) — they are not repeated here so there is only one copy
to keep correct.

Every archive needs the query encoder's debug symbols cached locally first: run [`Scripts/fetch-llama-dsyms.sh`](Scripts/fetch-llama-dsyms.sh) once after cloning (and after any rebuild of `Vendor/llama.xcframework`). The dSYMs are too large for the repository, so an archive-only build phase copies them from that cache and refuses to archive without them; the `CLAUDE.md` entry explains why.

## Data and credits

- The **FRUS series** is published by the [Office of the Historian](https://history.state.gov), U.S. Department of State, and is in the public domain. TEI editions come from the [HistoryAtState](https://github.com/HistoryAtState) repositories.
- The bundled person-authority crosswalk derives from the Office of the Historian's public-domain
  (CC0) `HistoryAtState/people` registry; volume subject profiles derive from its public-domain
  `frus-subjects` document–subject mappings.
- Archival records come from the [National Archives Catalog](https://www.archives.gov/research/catalog/help/api). FRUS Explorer is not affiliated with, endorsed by, or sponsored by NARA, and catalog data is subject to NARA's terms of use.
- TEI rendering approaches were informed by the [TEI Publisher](https://teipublisher.com) project (Apache 2.0).

Commentary, advice, and guidance about the FRUS series contained in the application reflect personal
views and not necessarily those of the Department of State or the U.S. Government.

## License

Apache 2.0. See [LICENSE](LICENSE) for the full license text.

All source files carry the Apache 2.0 license header.

The optional natural-language search feature downloads Google's EmbeddingGemma model at the user's request and runs it on-device. The model weights are never part of this repository and are not covered by the Apache License: Gemma is provided under and subject to the [Gemma Terms of Use](https://ai.google.dev/gemma/terms), including its [Prohibited Use Policy](https://ai.google.dev/gemma/prohibited_use_policy). The app ships the model unmodified (the Q4_0 QAT GGUF build, SHA-256-pinned in the semantic artifacts) and embeds [llama.cpp](https://github.com/ggml-org/llama.cpp) (MIT) to run it. See [NOTICE](NOTICE) and `Planning/semantic-vectors/Gemma-Compliance-Runbook.md`.

## Contributing

Read [`CLAUDE.md`](CLAUDE.md) for the architecture, build commands, and coding standards, and [`Planning/DEVELOPMENT-PLAN.md`](Planning/DEVELOPMENT-PLAN.md) for the session sequence. Both app targets must build and the full test suite must pass before a change lands. Update `FRUS-API.openapi.yaml` when you touch a stored or queryable data surface — that one is mechanically enforced.

<!-- END SOURCE: repo.readme -->

---
