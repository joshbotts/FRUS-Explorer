# Alvey — Specification

**Version**: 0.1 (draft)
**Date**: 2026-11-23
**Status**: DRAFT for the owner's review. Nothing in it is approved or scheduled; §21 lists the
decisions it needs, and until each is made the recommendation beside it stands in for it.
**Written against**: this repository at `4556c4d` (FRUS Explorer 1.0 (1861); index format version
75; FTS schema version 4) and `Docs/Agentic-Analysis-Guide.md` at v1.50.

> **Alvey in one paragraph.** Alvey is a macOS app that runs the method of the Agentic Analysis
> Guide (scope a question, read the documents, contest the result, decide whether to stop, deliver)
> on a language model the researcher runs locally in **LM Studio**. Wherever code can enforce the
> guide's rules, Alvey does. The model chooses vocabulary, judges relevance, reads and writes
> prose. Code does the counting, citing, quoting, recording and refusing. Alvey reads what FRUS
> Explorer exports and hands back files that FRUS Explorer opens. It never writes to FRUS
> Explorer's library, and the researcher adjudicates everything there.

**How to read this document.**

- Requirements carry an area prefix and a number (`SRC-3`, `LMS-7`, `VER-2`), so later plans,
  issues and tests can cite them. **MUST**, **SHOULD** and **MAY** are used as in RFC 2119.
- A claim about FRUS Explorer cites the file or document it was checked against at `4556c4d`.
- A claim about LM Studio is marked **[LMS]** and comes from the sources §8 names. One known only
  from a search extract is marked **[LMS, unverified]**.
- A figure from the owner's machines is marked **[MEASURED]** with its record. A figure derived
  here and not measured is marked **[DERIVED]** and is not a budget (§18 says why).
- The guide is cited by section (guide §12). This document never restates a rule it can cite.

---

## Contents

1. [Why Alvey](#1-why-alvey)
2. [Scope](#2-scope)
3. [Definitions](#3-definitions)
4. [Design principles](#4-design-principles)
5. [Platform, toolchain and repository](#5-platform-toolchain-and-repository)
6. [Architecture](#6-architecture)
7. [Sources: what Alvey reads](#7-sources-what-alvey-reads)
8. [LM Studio](#8-lm-studio)
9. [The tool layer](#9-the-tool-layer)
10. [Runs, rounds and templates](#10-runs-rounds-and-templates)
11. [Verification and rule enforcement](#11-verification-and-rule-enforcement)
12. [Deliverables](#12-deliverables)
13. [Interoperability with FRUS Explorer](#13-interoperability-with-frus-explorer)
14. [Privacy, security and safety](#14-privacy-security-and-safety)
15. [The run record and reproducibility](#15-the-run-record-and-reproducibility)
16. [User interface](#16-user-interface)
17. [Calibration and evaluation](#17-calibration-and-evaluation)
18. [Performance model](#18-performance-model)
19. [Accessibility and localization](#19-accessibility-and-localization)
20. [Phasing](#20-phasing)
21. [Owner decisions](#21-owner-decisions)
22. [Placeholders requiring future input](#22-placeholders-requiring-future-input)

---

## 1. Why Alvey

### 1.1 The loop as it runs today

The agentic loop's working rhythm is *curate in the app → compute over the curation → adjudicate in
the app → claim* (`Planning/Agentic-Loop-Development-Plan.md`). Wave W-19 built the affordances it
runs on: Export Research Database… (L-2), tag names beside tag ids (L-3), the embedder on disk
(L-4), `frusexplorer://` deep links (L-5), the corpus-wide shard fetch (L-6), the research-state
record (L-7) and the `.fruscollection` write-minimum (L-1). The method lives in the guide, and the
§12 house-rules block is the instrument: across C-0, C-2 and C-0b to C-0d, the block arm obeyed
95.2–100% of the rubric's items against a no-rules control of 75–84% (guide §12, "Which surface
answers which block"). In C-3, Opus 5.5 at `medium` and Sonnet 5.5 at `high` obeyed 34 of 34 items
in both of their runs (guide §3a; `Planning/C-3-Results-2026-10-26.md`).

Three facts limit who can use it:

1. **It needs a frontier model and an operator.** Every measured run used Claude. The recommended
   cells spend about 170,000 to 540,000 output tokens a run (guide §3a), driven from a terminal. A
   historian who does not run agents depends on someone who does (guide, opening: "hand §12 to
   whoever runs the agents").
2. **Almost every rule holds only because a strong model obeys prose.** When the 2026-08-31
   assessment counted, exactly one of §12's roughly 40 rules was enforced by a mechanism, the
   export's privacy strip (`Planning/Completed/MCP-Server-Assessment-2026-08-31.md` §1). The
   export's `research_*` views have since taken four more off the agent's memory (guide §12, after
   the block). The assessment's own line still describes the rest: "a description is prose with
   exactly the authority of §12's prose. Only implementations bind."
3. **Sending the work to a cloud model is a decision, not a default** (guide §11). The decision
   covers the researcher's own writing and "an unpublished argument visible in the shape of your
   queries."

### 1.2 What a local model changes

A model served by LM Studio on the researcher's own Mac answers the third fact and the cost half of
the first, and makes the second acute. The owner has measured local models on this corpus:

- **Quotation fidelity is not free.** Over an 11.55-day sweep of 330,979 chunks with a JSON schema
  enforced, Qwen3 14 B (no-think, Q8_0) returned 2,601,312 strings. Of those, 88,009 (3.38%) did not
  occur verbatim in their passage; Qwen3 1.7 B failed 112 of 1,538 in the pilot
  (`tools/semantic-harvest/NER-RUNBOOK.md` §4.7, §4.8.3) **[MEASURED]**.
- **Configuration dominates speed.** With Qwen3's reasoning trace on by default, both models
  generated about 735 tokens per chunk where the answer was about 25. That moved a
  prefill-bound workload into decode, the axis the fanless Air is worst at (same file, §4.7)
  **[MEASURED]**.
- **The machine matters fourfold.** The same no-think run took 4.68 s a chunk on the M1 Max Mac
  Studio and 19.27 s on the M5 MacBook Air, the Air's figure an average over 4.4 fanless hours
  (same file, §4.8.2) **[MEASURED]**.

Nothing measured so far says that a model in the 14–30 B range holds the 221-line block of prose
rules the way Opus 5.5 does, and the sweep's figures give reason to doubt it. Alvey is built on the
premise that it does not, and A0 measures the premise (§20).

### 1.3 The thesis: the rules become implementations

The 2026-08-31 assessment counted what a constrained tool surface could make structural: 12 to 16
of the ~40 rules, about 20 with a corpus scanner, against the 1 it found (its §1). It recommended a
fixed-subcommand binary over MCP. C-0 and C-2 then showed that frontier agents obeyed the block
without one, so C-1 closed as not needed (`Planning/Agentic-Loop-Development-Plan.md`, C-1). That
reasoning holds for Claude. It does not hold for a local model, and Alvey is where the tool surface
earns its keep. Alvey goes further than the assessment's count, because it also owns the pipeline
and the deliverables, not only the tools:

- **The tools** make identity, exclusions, controls, counting surfaces, denominators and channels
  structural (§9).
- **The pipeline** makes ordering rules structural: coverage first, the editors' headings before
  queries, archival scope on every reading scope, a critic's verdict before another round (§10).
- **The verifiers** make output rules checkable: every quotation re-located in a retrieved text,
  every number traced, every citation generated, the reader-facing lint (§11).

§11.2 maps each of the C-3 rubric's 35 items to the mechanism that carries it: 30 structural, four
checked by a verifier and one shared with the model. So an Alvey run can be scored with the
instrument that scored Claude (§17), and a structural item that fails is a bug in Alvey.

### 1.4 What success looks like

- **SUC-1** A historian with a Mac, FRUS Explorer and LM Studio asks a question in Alvey and,
  without a terminal, receives the four artifacts of guide §14.16: the memo, the overview with its
  three-part bottom line, a `.fruscollection` that opens in FRUS Explorer, and the operator's kit,
  which in Alvey is the run record (§15).
- **SUC-2** Every number in the overview traces to a recorded tool call, every quotation was
  re-located in a document retrieved in the run, and every citation was generated from a document
  key. Each of these holds by construction and is checked before the overview is released.
- **SUC-3** Scored with the C-3 rubric (`Planning/c3-reader-test/RUBRIC.md`), every item §11.2
  calls structural passes in every Alvey run, and the run states which items it left to the model.
- **SUC-4** A run that cannot meet a rule (no TEI for a variant count, no encoder for a text
  query, a model that fails calibration for a role) says so in its deliverables and does not
  approximate. The rule is guide §12's own: "An approximation here is indistinguishable from an
  answer."

---

## 2. Scope

### 2.1 In scope for the first release

- The guide's two round types, scoping and reading, with refutation and a critic's verdict, as
  templates (§10). Three smaller templates: batch extraction over a set of documents, a single
  document's dossier, and a bounded exploratory session.
- Reading the index copy FRUS Explorer exports, the TEI volumes, the bundled JSON and the vector
  artifacts (§7).
- Driving models served by LM Studio on the same Mac or on another Mac on the local network (§8).
- Writing the guide's deliverables, including a `.fruscollection` FRUS Explorer opens, and linking
  every document into FRUS Explorer's reader (§12, §13).

### 2.2 Non-goals, and decisions this document does not reopen

- **No MCP server in either app.** L-8 was assessed NO-BUILD (MCP) on 2026-08-31, and the plan of
  record lists "the MCP server" under Declined (`Planning/Plan-Of-Record-2026-11-15.md`, §5). Alvey's
  tools are Swift calls its own orchestrator makes. LM Studio's own MCP hosting is not used (§8.4).
- **No writes to FRUS Explorer's live index, its SwiftData store or CloudKit.** Alvey's only routes
  into the researcher's library are files the researcher opens or imports in FRUS Explorer (§13.3).
  Nothing Alvey requires adds a `@Model`, a stored property or a CloudKit identifier to FRUS
  Explorer, so the #488 gate (CLAUDE.md, "CloudKit schema-deploy gate") is untouched. The optional
  FX-1 of §13.6 would touch it, and says so.
- **Not a reader, search UI, editor or library manager.** FRUS Explorer is all four. Alvey shows
  the evidence it holds and links into FRUS Explorer for everything else.
- **Not a chat client.** Free conversation exists only as the bounded exploratory template
  (§10.4), under the same verifiers.
- **No cloud model, account, analytics or telemetry.** §21 records a cloud backend as out of scope
  for this specification.
- **Not iOS or iPadOS in the first release** (§5.1).

---

## 3. Definitions

| Term | Meaning here |
|---|---|
| **FRUS Explorer** | The app in this repository. |
| **The kits** | The shared targets FRUS Explorer compiles and other hosts reuse: FRUSCoreKit, FTS5Store, SourceNoteKit, TEIHeaderKit, SemanticVectorsKit, WordCloudKit (CLAUDE.md, "SPM package targets"). |
| **LM Studio** | The local model server Alvey drives over HTTP (§8). |
| **Model** | One model as LM Studio serves it, identified by its model key, its weights file and that file's SHA-256 (§8.2). |
| **Index copy** | A SQLite file written by FRUS Explorer's *Export Research Database…*, or a hand-made `.backup` (guide §2), opened read-only. |
| **Surface** | One of the sources guide §12 names: the index copy, the TEI XML, the bundled JSON, the vector artifacts, the offline harvest. |
| **Document key** | The pair `(volumeId, documentId)`, the only identity a document has anywhere in Alvey (guide §4.1). |
| **Brief** | The researcher's question, with its scope, budget, deliverables and model profile (§10.1). |
| **Run** | One execution of a template over a brief: a folder on disk (§6.3). |
| **Round** | The guide's unit of work: a scoping or a reading round (guide §14.16), followed by refutation (guide §14.12) and a critic's verdict (guide §14.15). |
| **Step** | One bounded unit of a round. A *code step* runs no model. A *model step* is one role, one task, one fresh context and one output schema. |
| **Role** | What a model step is for: planner, reader, writer, refuter or critic. Each role names a model profile (§8.3). |
| **Tool** | A typed, read-only function backed by the kits (§9). |
| **Ledger** | The run's record of everything retrieved, counted, quoted and decided, keyed by document key and tool call. A deliverable may draw only on the ledger. |
| **Trace table** | The memo's table that maps every number and quotation in a reader-facing deliverable to its ledger line (guide §8, §14.16). |
| **Calibration** | Alvey's measurement of one model, at one quantization, under one LM Studio runtime, on this machine (§17). |

---

## 4. Design principles

- **P1 — Code counts; the model reads.** No number reaches a deliverable unless a tool computed it.
  The model may choose what to count and say what a count means; it never states a count.
- **P2 — Quotations are re-located, not trusted.** A quotation is a span of a retrieved text,
  stored by offset. The model's string is a request to find that span (§11.1).
- **P3 — Code writes the citations.** The model names document keys. FRUS Explorer's own citation
  formatter and canonical URLs, through the kits, write every citation, every "Documents cited"
  line and every deep link.
- **P4 — The researcher's writing is never a source.** No tool can read the index copy's
  `summary_text`, `note_text`, `user_tag_ids` or `user_tags`. Curation the researcher chooses to
  share (§7.5) reaches a model only as labelled context and can never be quoted.
- **P5 — Read-only by construction.** Every source is opened read-only. Alvey writes only inside
  its own run folders and to the files the researcher asks it to export.
- **P6 — Everything on disk as it happens.** Each step's inputs, outputs, tool calls and timings
  are written before the next step starts. A killed run leaves a resumable draft (guide §14.12
  items 5–6).
- **P7 — Short steps over long sessions.** A model step sees one task, the rules that bear on it,
  and the ledger lines it needs, in a fresh context. The orchestrator holds the plan, so a rule is
  re-presented at every step rather than remembered across a long session (§10.6).
- **P8 — Ask for the exception, not the guarantee.** The machine log is complete because code
  writes it, and anything shortened is listed by code (guide §14.15a). Alvey never asks a model to
  assert that it complied.
- **P9 — Honest about the instrument.** Every deliverable names the models, their calibration on
  this machine, the rules Alvey enforced and the rules it left to the model.
- **P10 — Local and quiet.** Alvey makes no network request except to the model servers the
  researcher names and, when asked, to the sources of §7. It collects nothing.
- **P11 — The researcher adjudicates in FRUS Explorer.** Alvey proposes: a collection, a reading
  list, a deep link and, once FX-1 exists, an import file. It never edits the library itself.

---

## 5. Platform, toolchain and repository

### 5.1 Platform

- **PLAT-1** macOS 26 or later on Apple silicon, the floor FRUS Explorer's Mac app has
  (`project.yml`, `deploymentTarget: "26.0"`).
- **PLAT-2** No iOS or iPadOS in the first release, for four reasons. Export Research Database… is
  Mac-only (`FRUSExplorer/Export/ResearchDataExportView.swift:212-214`). iOS has no route to the
  index file (guide §2). LM Studio does not run there. A reading round needs hours of a Mac's power
  and thermal budget (§18).
- **PLAT-3** One Mac or two. LM Studio may run on the Mac that runs Alvey, or on another Mac on the
  local network: for the owner, the M1 Max Studio serving while Alvey runs on the Air (§8.1).

### 5.2 Toolchain and standards

- **STD-1** Swift 6 with complete strict concurrency and zero warnings on a clean build; SwiftUI;
  XcodeGen with `project.yml` as the source of truth; the Apache 2.0 header on every source file; a
  doc comment on every public and internal declaration; `String(localized:)` for every user-facing
  string. These are this repository's standards (CLAUDE.md, "Coding Standards"), carried into
  Alvey's own CLAUDE.md with the gates that enforce them.
- **STD-2** On a Mac that builds this repository, Alvey MAY hold the one-heavy-job lock
  (`$HOME/Library/Caches/FRUS-Explorer/heavy-job.lock`, `Scripts/heavy.sh:54`) while a run's model
  steps execute on that Mac, so that a run and a build never contend. The option is off by default.
  CLAUDE.md records why the lock exists: on 2026-10-18 concurrent heavy jobs drove the load average
  to 785 and the Mac had to be restarted.

### 5.3 Repository arrangement and the kits

- **REPO-1** Alvey lives in its own repository. It takes this repository as a git submodule pinned
  to a commit and declares SwiftPM targets of its own over the kit folders, which is how FRUS
  Explorer Light consumes them (`Planning/DEVELOPMENT-PLAN.md`'s web-edition entries). This
  repository's `Package.swift` declares no `products:`, so `.package(url:)` cannot reach the kits.
  The redeclared targets MUST be named exactly `FTS5Store`, `SourceNoteKit` and `TEIHeaderKit`,
  because FRUSCoreKit imports them behind `#if canImport`.
- **REPO-2** Alvey calls the kits' public API only. It MUST NOT compile the kit folders into its own
  module, as FRUS Explorer's `project.yml` does for the app, because that makes `internal`
  declarations visible and couples Alvey to internals no boundary test protects.
- **REPO-3** When Alvey needs a change in a kit, an Alvey session writes it as a pull request to
  this repository for the owner to merge, under the four rules of CLAUDE.md's web-edition section.
  Alvey never forks or patches kit code. §13.5 lists the gaps known today.
- **REPO-4** The pinned commit is recorded in Alvey's build and in every run record (§15). Moving
  the pin is a deliberate change that runs Alvey's full test suite (EVAL-4).
- **REPO-5** This repository's sessions owe Alvey nothing beyond what CLAUDE.md already says for
  the web edition. They do not hold back kit API, index-version or export changes for it, and
  Alvey follows ("Not asked of sessions here").
- **REPO-6** The kits Alvey compiles: FRUSCoreKit, FTS5Store, SourceNoteKit, TEIHeaderKit and
  SemanticVectorsKit; and WordCloudKit for its stopword sets (`WordCloudStopwordSet(contentsOf:)`),
  which the lexical tools need because the app's own stopwords are app code.

### 5.4 Targets

| Target | Kind | What it holds |
|---|---|---|
| `AlveyKit` | SwiftPM library | The run engine, the model client, the tool layer, the verifiers and the deliverable writers. Foundation and the kits; no SwiftUI. |
| `alvey` | SwiftPM executable | Runs a brief headless; calibrates a model; replays and verifies a run folder. It is A0's prototype (§20) and the overnight runner. |
| `Alvey.app` | XcodeGen app | The SwiftUI app over AlveyKit (§16). |
| `AlveyKitTests`, `AlveyUITests` | tests | The unit suite, with a mock model server (EVAL-5), and the UI suite. |

---

## 6. Architecture

### 6.1 Layers

```
            Alvey.app (SwiftUI)                 alvey (command line)
                     └──────────────┬──────────────┘
                                 AlveyKit
   ┌───────────────┬───────────────┬────────────────┬──────────────────┐
   │ Run engine    │ Model client  │ Tool layer     │ Verifiers and    │
   │ briefs, steps,│ LM Studio:    │ typed, read-   │ deliverable      │
   │ gates, ledger,│ chat, schemas,│ only (§9)      │ writers (§11,    │
   │ checkpoints   │ tools, embed. │                │ §12)             │
   └───────────────┴───────────────┴───────┬────────┴──────────────────┘
                                           │
        the kits, compiled from a pinned commit of this repository (§5.3)
     FRUSCoreKit · FTS5Store · SourceNoteKit · TEIHeaderKit · SemanticVectorsKit · WordCloudKit
                                           │
   sources, read-only (§7): index copy · TEI volumes · bundled JSON · vectors
                                           │
   outputs (§12): run folders → .fruscollection · overview · memo · CSV
```

### 6.2 The run engine

- **ENG-1** A run is a state machine over its template's steps (§10). A step is a value: its kind,
  its inputs as ledger ids, its status, its outputs and its record. The engine alone decides what
  runs next. No model output changes the plan except through a step's declared output, such as the
  planner's families (S2) or the critic's verdict (R7).
- **ENG-2** A scheduler keeps a pool of parallel slots per server (§8.8) and runs independent
  steps, such as the reader steps of R1, in parallel. Steps that depend on each other run in order.
- **ENG-3** The ledger is append-only. A step adds lines, and a later correction is a new line that
  names the line it supersedes, so the memo can show what was refuted and by what (guide §14.16
  item 1).

### 6.3 Storage

- **STOR-1** Alvey's data lives in its container's Application Support: `Sources/` (one folder per
  index copy, with its bookmark, provenance and check results), `TEI/` (files named by blob SHA-1),
  `Runs/` (one folder per run), `Calibrations/` and `Profiles/`.
- **STOR-2** A run folder holds only plain files: `brief.json`, `run.json`, `transcript.jsonl`, the
  ledger, one folder per step with its exact request and response, `drafts/` and `exports/`. Every
  file is JSON, JSONL, Markdown, CSV or SQLite, readable without Alvey.
- **STOR-3** Alvey's lists of runs and sources are an index over these folders and can be rebuilt
  from them. Nothing syncs: runs belong to the Mac that ran them, and a sync would be its own
  decision.

---

## 7. Sources: what Alvey reads

### 7.1 The index copy

- **SRC-1** The researcher adds an index copy by choosing the file FRUS Explorer's Export Research
  Database… wrote (Settings ▸ System ▸ Data & Recovery, on the Mac; default name
  `frus-index.sqlite`). FRUS Explorer makes it with SQLite's backup API, switches it to a single
  file with a rollback journal, verifies it with `quick_check` and the `rank`-1 FTS check, and only
  then moves it into place (`FRUSExplorer/Export/ResearchDataExporter.swift:881-899`, `1082-1098`,
  `1313-1337`).
- **SRC-2** Alvey opens it with the kits' immutable opens: `FTS5Store(readingDatabaseAt:schema:)`
  (`FTS5Store/FTS5Store.swift:151`) and
  `IndexingPipeline(readingIndexAt:fts5Store:resources:volumesDirectory:userStore:)`
  (`FRUSCoreKit/Search/IndexingPipeline.swift:2557`). The resources are
  `IndexingResources.loading(fromDirectory:)` over Alvey's copies of the five files it names
  (`FRUSCoreKit/Search/IndexingSeams.swift:177`, `202`).
- **SRC-3** On adding a copy, Alvey re-runs `PRAGMA quick_check` and the `rank`-1 integrity check
  on both FTS tables (guide §2), records the file's SHA-256 and size, and reads
  `research_provenance` (`exported_at`, `my_writing_included`, `app_version`, `app_build`, the
  installed and current index and FTS schema versions, `semantic_provenance_digest`;
  `ResearchDataExporter.swift:1263-1280`; guide §4.7).
- **SRC-4** Neither read-only open checks the index version (`IndexingPipeline.swift:2557`,
  `2594`), so Alvey MUST. It refuses a copy whose `installed_index_version` differs from the pinned
  kit's `IndexingPipeline.currentDateIndexVersion` (75 at `4556c4d`, `IndexingPipeline.swift:1703`).
  It also refuses one whose installed and current versions differ, a sign that FRUS Explorer has not
  finished re-indexing (guide §13 reads a disagreeing FTS pair the same way). `FTS5Store` itself
  refuses an FTS schema generation other than its own. The message says which app to update, or to
  export again once FRUS Explorer has finished re-indexing.
- **SRC-5** A hand-made `.backup` (guide §2) has no `research_provenance`. Alvey accepts one only
  with the researcher's research-state record pasted beside it (Settings ▸ Volumes & Storage ▸
  Advanced ▸ Index Health ▸ Copy Research-State Record; `ResearchDataExporter.swift:1378-1451`).
  It checks the record's versions as SRC-4 does, and the record's indexed-volume list must equal the
  copy's.
- **SRC-6** Alvey never opens FRUS Explorer's live index (guide §11: "Do not point an agent at the
  live index while the app is running"), and reads nothing else inside FRUS Explorer's container
  except a folder the researcher grants (SRC-9, SRC-14).
- **SRC-7** A newer export of the same library is a new source. Alvey shows what changed (volumes
  added or removed, the index version) and keeps the older copy while any run refers to it.

### 7.2 The TEI volumes

- **SRC-8** The TEI carries every rule guide §12 marks [TEI] (the counting surface, variant scans,
  the apparatus split) and gives footnotes as their own text. Since index version 75 a copy records,
  for each volume, the git blob SHA-1 and size of the file its last store pass parsed
  (`IndexingPipeline.indexedVolumeFile(forVolumeId:)`, `IndexingPipeline.swift:3834`). Alvey fetches
  each volume in scope from the URL FRUS Explorer downloads it from
  (`https://raw.githubusercontent.com/HistoryAtState/frus/master/volumes/<file>`,
  `FRUSCoreKit/Models/Manifest/ManifestModels.swift:96`). It keeps the file only when its blob
  SHA-1 (`VolumeUpdateChecker.gitBlobSHA1(for:)`, `FRUSCoreKit/Downloads/VolumeUpdateChecker.swift:147`)
  and its size match the record.
- **SRC-9** When they differ, the Office has corrected the volume since the index was built, and
  Alvey MUST NOT use the newer file. It offers three routes. The researcher can grant FRUS
  Explorer's Volumes folder once, and Alvey uses the file there if its hash matches. Alvey can
  fetch the historical blob by its SHA-1 from GitHub's API. Or the volume has no TEI, and its [TEI]
  results read "unavailable", as guide §12 requires ("say so and stop").
- **SRC-10** Alvey fetches TEI lazily, a volume at a time as a scope needs it, and caches it by blob
  SHA-1, since a blob never changes. It reads the files through the kits' `FRUSDocumentParser`
  (`FRUSCoreKit/TEI/FRUSDocumentParser.swift:168`) with its own `DocumentASTSource` conformer.

### 7.3 The bundled JSON

- **SRC-11** Alvey bundles copies of the files FRUS Explorer bundles that its tools read, taken from
  `FRUSExplorer/Resources/` at the pinned commit. They are the five `IndexingResources` files,
  `manifest.json`, the archival indexes guide §12 lists, the subject profiles,
  `resolved-edge-index.json` and `cited-page-map.json`. Each loads through the kits'
  `init(contentsOf:)` where one exists, and by a plain decode where none does (`CentralFilesIndex`,
  `VolumeSourcesIndex`, `LotClaimantsIndex`).
- **SRC-12** The run record carries each file's SHA-256. When the index copy came from a FRUS
  Explorer build other than the pinned commit's, Alvey says so, because some identifiers move
  between builds: rebuilding `collection-authority.json` changes record ids (CLAUDE.md, "Rules
  that span entries").

### 7.4 The vector artifacts and the query encoder

- **SRC-13** Alvey bundles the corpus tier (`semantic-vectors-index.json`, its binary and the map
  index) from the pinned commit and reads it through SemanticVectorsKit
  (`SemanticVectorIndex(file:)`, `SemanticCorpusVectors(contentsOf:expecting:)`). Neighbours of a
  document need no encoder (guide §A.5), so they are available whenever the corpus tier is.
- **SRC-14** Tier-2 shards (`<volumeId>.vec`) come from the host FRUS Explorer fetches them from,
  verified as FRUS Explorer verifies them (`FRUSExplorer/Semantic/SemanticShardFetcher.swift:61`,
  `238`), or from FRUS Explorer's own vectors folder through a grant. A row whose shard is missing
  is dropped from the rerank, never scored zero.
- **SRC-15** A text query needs the pinned encoder: EmbeddingGemma 2 at Q8_0, the GGUF whose
  SHA-256 the artifact's provenance pins (`2188ac1d…`, `provenance.modelFileSHA256`). FRUS Explorer
  shows its verified copy at Settings ▸ Volumes & Storage ▸ Natural-Language Search ▸ Model File,
  with Show in Finder (`FRUSExplorer/Settings/SemanticModelSection.swift`). The researcher loads
  that file into LM Studio, or into another OpenAI-compatible embeddings server (§8.12). Alvey
  verifies the served model id and the file's SHA-256 as
  `RetrievalEvalHarnessCore/LMStudioEmbeddingClient.swift:37` does.
- **SRC-16** A text query follows the artifact's own recipe through SemanticVectorsKit's functions:
  - the prefix `SemanticQueryPrompt.queryPrefix` (`"task: search result | query: "`);
  - the 768-dimension normalized vector cut to 512 and renormalized (`SemanticQuantization.truncate`);
  - int8 quantization and sign-bit packing (`quantizeInt8`, `packSignBits`);
  - a Hamming pool of `max(limit, 800)` (`SemanticRetrievalKernel.hammingCandidates`) and an exact
    rerank against the shards (`rerank`);
  - the edition-twin fold (`SemanticEditionTwins.foldingTwins`) and the calibrated display score.

  `RetrievalEvalHarnessCore/EvalRoutes.swift:156` already runs this route from an HTTP
  `/v1/embeddings` endpoint, without the fold and the calibration.
- **SRC-17 The parity gate.** Before text queries are enabled for a server, Alvey embeds the 25
  queries of `FRUSExplorerTests/Fixtures/query-parity-fixture-embeddinggemma-2.json` through it. It
  requires a cosine of at least 0.999 against each reference vector, the bar
  `QueryEncoderParityTests` holds FRUS Explorer's own encoder to (`QueryEncoderParityTests.swift:27`).
  If a server cannot load the model or misses the bar, text queries stay off and the reason is
  shown. The run's VECTORS section then reads "none" or "neighbours of documents only" (guide
  §14.16).
- **SRC-18** A vector result is a lead for reading, never evidence. It reaches a deliverable only
  through a document the run read (guide §14.17, §A.8).

### 7.5 The researcher's curation, when shared

- **SRC-19** From a FRUS Explorer JSON export (Settings ▸ System ▸ Data & Recovery ▸ Export as
  JSON; format version 7; decoded with the kits' `ResearchDataEnvelope.makeDecoder()`), Alvey MAY
  read collections, tags and tag assignments, working corpora, saved searches and projects, to set
  a brief's scope or seed a reading list. It reads notes and summaries only when the brief opts in
  (PRIV-4). FRUS Explorer leaves summaries out of the export unless the researcher includes them.
- **SRC-20** A `.fruscollection` exported from FRUS Explorer is a seed for the next round: its
  documents, its headings and the historian's notes on them (guide §14.16, "The collection is the
  feedback channel"; §15.4). Alvey decodes it with `NativeCollectionSerializer.decode(_:)`. Notes
  travel only when the researcher turns on "Include my research notes", which is off by default.

### 7.6 The offline harvest

- **SRC-21** The [HARVEST] surface of guide §12 (the offline NARA record-group harvest, one machine,
  gitignored) is not in the first release. When it comes it is operator-only, labelled on every
  count, and never summed with a bundled count.

### 7.7 Compatibility

- **SRC-22** Alvey declares what it reads and writes: the index format and FTS schema versions
  (SRC-4); research-data files of format versions 1 to 7, as the kits' decoder reads them;
  `.fruscollection` files up to version 2, writing version 2 with a reader floor of 1 (§13.3). It
  refuses anything outside these, and the message names the app to update.

---

## 8. LM Studio

**[LMS]** facts come from LM Studio's documentation source (`github.com/lmstudio-ai/docs` at
`8c7159b`, 2026-10-20), its MIT-licensed `lms`, SDK and MLX-engine repositories, read on 2026-11-23.
lmstudio.ai itself was not reachable from the session that wrote this. A fact known only from a
search extract of an lmstudio.ai page is marked **[LMS, unverified]**. Every [LMS] fact this
section relies on is re-checked against the installed version in A0 (§20).

### 8.1 Servers

- **LMS-1** Alvey talks to one or more servers by base URL. The default is
  `http://localhost:1234`. LM Studio binds to 127.0.0.1 unless "Serve on Local Network" (or
  `--bind 0.0.0.0`) is set, and its documentation says to turn authentication on when it is **[LMS]**.
- **LMS-2** Since 0.4.0 LM Studio has API tokens. They are off by default, created in the app's
  Manage Tokens with per-token permissions, and sent as `Authorization: Bearer` **[LMS]**. Alvey
  keeps a token per server in the Keychain (PRIV-8). Before it sends document text to a server on
  another Mac that does not require a token, it warns, and it waits for the operator to confirm.
- **LMS-3** Alvey neither starts nor stops a server. It shows the operator how: the app's "run the
  LLM server on login", `lms server start`, or the headless `llmster` daemon (`lms daemon up`, since
  0.4.0) **[LMS]**. It reads a server's state from `GET /api/v1/models`.
- **LMS-4** The native model list, tokens and continuous batching need LM Studio 0.4.0 or later.
  The owner ran 0.4.25 in October 2026 (`Planning/DEVELOPMENT-PLAN.md`, the harvest's entry). A0
  sets the minimum version (§22).
- **LMS-5** Any server that speaks the subset of the OpenAI-compatible API Alvey uses
  (`/v1/models`, `/v1/chat/completions` with `response_format`, `/v1/embeddings`) MAY stand in, with
  model management off. `llama-server` already stands in for LM Studio in the harvest with no
  change (`tools/semantic-harvest/README.md`, field notes of 2026-10-14). So Alvey does not depend
  on one closed-source app: LM Studio's desktop app is closed source, while its `lms` CLI and SDKs
  are MIT-licensed **[LMS]**.

### 8.2 Model identity: the two guards

- **LMS-6 Listed and loaded.** LM Studio routes an unknown model id to whatever model is loaded
  (observed 2026-08-10; the first guard of `RetrievalEvalHarnessCore/LMStudioEmbeddingClient.swift`).
  With just-in-time loading on, `/v1/models` lists every downloaded model, not only the loaded
  ones **[LMS]**. So before each phase Alvey reads `GET /api/v1/models` and requires the profile's
  model to have a loaded instance whose `context_length` and `parallel` are the profile's
  (`loaded_instances[].config` **[LMS]**). Otherwise it loads the model (LMS-19) or stops.
- **LMS-7 The file.** A model's identity, for calibration and for the record, is its weights file's
  SHA-256, because "a quantized GGUF is a *different model*"
  (`Planning/M2-Semantic-Pipeline-Ride-Along.md` §5 item 2). LM Studio's list reports format,
  quantization and size, not the file or its hash **[LMS]**. So Alvey hashes the file in LM Studio's
  models folder, which the researcher grants once, and matches it to the listing by size. For a
  server on another Mac the hash is computed there (with `alvey` or `shasum -a 256`) and entered.
  Until it is, the record says "file unverified".
- **LMS-8** Each response's `model` field is checked against the profile. A mismatch fails the step.

### 8.3 Roles and profiles

- **LMS-9** A profile names, for each role: a model; a context length; the sampling parameters
  (temperature, `top_p`, `top_k`, seed); `max_tokens`; the reasoning setting; native tool calls or the
  structured-action protocol (§8.5); and the parallel slots. The starting values in the table below
  are A0's inputs, not its results (§22).

| Role | Temperature | Reasoning | Tools |
|---|---|---|---|
| planner | low | on, capped by `max_tokens` | native if CAL-2 passes, else §8.5 |
| reader | 0 | off | none: one structured output |
| writer | low | off | none: one structured output per section |
| refuter | 0 | on, capped | §8.5 |
| critic | 0 | on, capped | none: one structured verdict |

- **LMS-10** The refuter and the critic SHOULD run on a different model from the planner and the
  writer, so that the contest of guide §14.12 is not one model grading its own work. On a 32 GB Air
  that means changing models between phases, and the scheduler groups steps by model to keep the
  changes few (ENG-2).

### 8.4 Requests

- **LMS-11 One wire format.** Every chat request is `POST /v1/chat/completions`, streamed, with
  `stream_options.include_usage` **[LMS]**. It is the one endpoint documented to take custom tools,
  `response_format` and the sampling parameters together. Alvey does not use the stateful
  `POST /api/v1/chat`, which takes no custom tools **[LMS]**, nor the server-side state of
  `/v1/responses`. Alvey keeps all state itself (P6).
- **LMS-12 Schemas Alvey can trust.** Structured output is
  `response_format: {type: "json_schema", json_schema: {name, strict, schema}}` **[LMS]**. The
  engine enforces a grammar: llama.cpp's for GGUF; for MLX, Outlines, or mlx-vlm's processor when
  batching **[LMS]**. LM Studio documents no limit on the JSON Schema features it honours. llama.cpp's
  own converter skips unsupported keywords silently and does not support `anyOf` or `oneOf` beside
  `properties` (its `grammars/README.md`). Alvey's schemas therefore keep to objects with `properties`
  and `required`, arrays, strings, integers, booleans and `enum`, and Alvey validates every output
  against the full schema in code.
- **LMS-13** Every request sets `max_tokens`. A model held to a schema can fail to close it and
  generate until the context fills **[LMS]**.
- **LMS-14 Native tool calls only where measured.** For a model without native tool support, LM
  Studio injects its own tool prompt ("Results will vary by model"), and a small model's malformed
  call comes back as plain content **[LMS]**. So Alvey passes `tools` only to a model that passes
  CAL-2. It accumulates streamed calls from `delta.tool_calls` **[LMS]** and runs them one at a time,
  in order, as both of LM Studio's SDKs do by default **[LMS]**.
- **LMS-15 Not used:** LM Studio's MCP hosting, through `/api/v1/chat` integrations or MCP tools on
  `/v1/responses`, in which the server runs the tools **[LMS]**. Alvey's tools are its own code (§2.2).

### 8.5 The structured-action protocol

- **LMS-16** A step that may call tools, on a model without measured native tool calls, runs in two
  calls a turn, each under a schema. The first returns
  `{"action": <one of the step's tools, or "final">, "reason": <a sentence>}`. The second returns
  the chosen tool's arguments, or the step's output for `final`, under that schema alone. Two calls
  avoid `anyOf`, the construct the grammar engines handle worst (LMS-12). The orchestrator runs the
  tool and adds its result. The step's tool-call budget bounds the loop.

### 8.6 Reasoning

- **LMS-17** Reasoning is set per role, through `reasoning_effort` where the model takes it (since
  0.4.8 **[LMS, unverified]**), or else the model's own switch, such as Qwen3's think and no-think.
  CAL-6 proves the setting takes effect on this server. The sweep's record shows why that matters:
  the no-think template's only trace was a fixed four prompt tokens a chunk, and the run manifest
  could not see the toggle (`NER-RUNBOOK.md` §4.8.2).
- **LMS-18** Reasoning text (`message.reasoning`, `delta.reasoning` **[LMS]**) is kept in the
  operator's log. It is never parsed as output and never shown to the historian.

### 8.7 Model lifecycle and memory

- **LMS-19 Load explicitly.** With just-in-time loading on, Auto-Evict keeps at most one model
  loaded that way, and that model unloads after 60 idle minutes by default **[LMS]**. A two-model
  profile would thrash. So Alvey loads each model of a profile explicitly with
  `POST /api/v1/models/load` and its `context_length` **[LMS]**. Parallel slots and a TTL exist only
  as `lms load` flags (`--parallel`, `--ttl`) **[LMS]**, so a profile that needs them shows the
  operator the exact `lms load` command.
- **LMS-20** Before loading, Alvey estimates the profile's memory: the weights from `size_bytes`
  **[LMS]**, plus the KV cache for its context length and slots, or `lms load --estimate-only`
  **[LMS]**. It refuses a profile that will not fit this Mac.
- **LMS-21 The prefix cache.** LM Studio's engines reuse the longest cached prefix of a request:
  MLX at 256-token boundaries, with a disk-backed cache since 2026-07, and llama.cpp through
  per-slot context checkpoints **[LMS, partly unverified]**. CTX-2 puts the stable part of every
  prompt first, and CAL-5 measures what that saves.
- **LMS-22** A profile MAY use speculative decoding (`draft_model`) or a quantized KV cache. On the
  MLX engine either one turns batching off, and a draft model on a batched MLX model raises an
  error (`lmstudio-ai/mlx-engine` issue 269) **[LMS]**. So CAL-5 measures such a profile as a
  profile of its own.

### 8.8 Concurrency

- **LMS-23** LM Studio serves parallel requests by continuous batching: on llama.cpp since 0.4.0,
  with Max Concurrent Predictions defaulting to 4, and on MLX for text models since 0.4.2 **[LMS]**.
  Alvey sends at most the loaded instance's `parallel` requests at once, and only for independent
  steps (ENG-2). On the Studio four workers gave 3.9× in a burst and 1.55× sustained (§18.1). On a
  fanless Mac the default is one until CAL-5 measures more.

### 8.9 Liveness and failure

- **LIVE-1** Every request streams. A request that produces no token for longer than its expected
  prefill time (CAL-5) plus a margin, and never less than 180 seconds, is cancelled and retried
  once. 180 s is the harness runbook's silence watchdog (`Planning/Agentic-Harness-Runbook.md` §2),
  adopted here as a floor.
- **LIVE-2** An HTTP 4xx is recorded with its body and not retried blindly; the 11.55-day sweep's
  first attempt ended on a traceback at an HTTP 400 (`NER-RUNBOOK.md` §4.8.3). A 5xx or a lost
  connection is retried with backoff. A server that disappears pauses the run, which resumes once
  the model is listed and loaded again (RUN-2).
- **LIVE-3** A prompt that would exceed the loaded context is split, never truncated (CTX-3; guide
  §3: "Never `substr()` a document you intend to call read").
- **LIVE-4** An output that fails its schema check in code (LMS-12) is retried once with the error.
  A second failure is recorded, and the step fails.

### 8.10 Thermal state and power

- **POW-1** When the server is on this Mac, Alvey reads `ProcessInfo.thermalState` and the power
  source. By default it starts no new step at `.serious`, resumes at `.fair`, and records every
  pause. The measurements bear on both sides: the Air held within 10% of its early rate over a
  25-minute probe with no thermal warning (`DEVELOPMENT-PLAN.md`, the EmbeddingGemma 2 entry), and
  its 4.4-hour average was still four times the Studio's time a chunk (§18.1).
- **POW-2** Options: run only on mains power; pause between batches, as the harvester's
  `BATCH_SLEEP` does (`NER-RUNBOOK.md` §4.3); keep the Mac awake during a run (UI-8); hold the
  heavy-job lock (STD-2).
- **POW-3** For a server on another Mac, Alvey cannot read the thermal state. It watches the
  decode rate of each stream and flags a sustained drop.

### 8.11 Determinism

- **DET-1** Reader, refuter and critic steps run at temperature 0 with a seed. A generation is still
  not reproducible: LM Studio's batched MLX generation ignores `seed` **[LMS]**, and the owner's
  sweep found differences between runs from batching and cache state, across an OS and an LM Studio
  build (`NER-RUNBOOK.md` §4.8.2). So Alvey reproduces tool results exactly (REC-2), records every
  generation, and never claims a generation can be reproduced.

### 8.12 Embeddings

- **EMB-1** Text queries use `POST /v1/embeddings` **[LMS]** on an embeddings server set apart from
  the chat server. The pinned encoder may need a newer runtime than LM Studio ships: the harvest
  moved to `llama-server` for EmbeddingGemma 2 (`tools/semantic-harvest/README.md`, field notes of
  2026-10-14), and LM Studio's runtime 2.21 was reported to fall back 2 to 3× slower on M5 Macs
  (`DEVELOPMENT-PLAN.md`, the same entry). The parity gate (SRC-17) decides which server qualifies,
  not the server's name.

### 8.13 Models for A0

No model is recommended until A0 has measured one (§21, decision 9). These are the candidates A0
should start from, with sizes as LM Studio's catalogue and the vendors state them **[LMS,
unverified]**. The one measured on this corpus is the first:

| Model | Shape | Weights at the catalogue's quantization | Context | Note |
|---|---|---|---|---|
| Qwen3 14 B | dense | about 15 GB at Q8_0 | — | Measured here: 3.38% of strings not verbatim, schema never broken (§1.2, §18.1) |
| gpt-oss-20b | 21 B, 3.6 B active | about 12 GB (MXFP4) | 128 K | Reasoning effort settable |
| Qwen3.6-35B-A3B, Qwen3.8-27B | mixture of experts; dense | 16–21 GB | up to 262 K | Tool-capable |
| Gemma 4 26B A4B | 3.8 B active | about 18 GB at Q4_K_M | 256 K | Native function calling |
| GLM-4.7-Flash | 30 B, 3 B active | about 16 GB | 128 K | — |
| Mistral Small | dense | about 14 GB | 128 K | — |

A model of 16–21 GB leaves little room for a long context's KV cache on the 32 GB Air. The
Studio's 64 GB takes any of them.

---

## 9. The tool layer

### 9.1 The contract every tool keeps

- **TOOL-1** A tool is a Swift function over the kits, with a `Codable` input and output. The
  schema a model sees is derived from the input type, and its description is one or two sentences.
  The rules a tool carries are enforced by its code, so the description does not need to state
  them. The 2026-08-31 assessment's point was that a description has only the authority of prose.
- **TOOL-2** Every tool is read-only. Its one effect is the line it adds to the ledger.
- **TOOL-3** Every result carries its surface; its scope signature
  (`SearchScopeSignature.signature(for:)`); the exclusions it applied; each count as numerator,
  denominator, grain and a file that lists the members; the controls of any scan; the query it ran
  (`SearchService.matchExpressions(for:)`, `QueryInspector`); and its timing.
- **TOOL-4** A document in a result is its key, date, header and printed number. A result never
  carries a rowid.
- **TOOL-5** A result over a set size is written to disk. The model receives a summary and the
  file's ledger id, never the whole result (guide §3: "keep the big files out of context").
- **TOOL-6** Every search sets `includeSummaries` and `includeNotes` to false
  (`FRUSCoreKit/Search/SearchParameters.swift:251-257`), so a document is found by its own text and
  never by the researcher's writing about it, whatever the copy holds.

### 9.2 The catalogue

These are the tools a model step may call. Each step's role card lists the subset it may use
(CTX-1). With the page lookups that code makes, they cover the eight query patterns of guide §6.

| Tool | Returns | Backed by | Rules it carries |
|---|---|---|---|
| `coverage` | Volumes, documents, front matter and editorial notes indexed, and the library's condition in words | `allIndexedVolumeIds()` and counts | COVERAGE |
| `volumes` | The manifest's volumes: title, years, subseries, whether indexed, whether partially published | `FixedVolumeCatalogue(contentsOf:)` over `manifest.json` | COVERAGE |
| `outline` | A volume's chapter headings and the documents under each | `cachedVolumeStructure(forVolumeId:)` | SCOPING: editors' headings (guide §14.8) |
| `search` | Ranked documents (key, date, header, snippet), the exact count, the match expression | `SearchService.search`, `searchCount`, `matchExpressions` | IDENTITY; EXCLUSIONS; BM25 order; T1 |
| `count_phrase` | A phrase's count with its STRICT and TOLERANT literal shares on the deterministic sample, as N of M | `matchKeys`, the four fields, one matcher | KNOWN TRAPS (a) and (b) |
| `timeline` | Counts by decade or year with per-1,000 rates over dated non-apparatus documents and the top volume's share | `CorpusAnalyticsService`, `documentTotalsByDecade` | SCOPING: periodisation, decade shape |
| `false_friend` | A term's concentration in the on-topic volumes beside a control phrase's | counts | SCOPING: false-friend test (guide §14.5) |
| `concordance` | Keyword-in-context lines for a result set | `SearchService.concordance(for:parameters:radius:)` | — |
| `facets` | Years, volumes, people, document types, provenance and subjects of a result set | `resultSetFacets(parameters:request:documentKeys:)` | — |
| `variants` | A term's mechanical spelling, hyphenation, plural and case variants | code | S3 |
| `tei_scan` | Counts per variant over the verified TEI, on a declared surface, with body and apparatus apart and both controls | `FRUSDocumentParser` | [TEI] SCOPING |
| `read` | A document's text, whole or a part at a time, with header, dateline, source note, date and length; its footnotes apart when its TEI is present | `fetchDocumentBodyText`, `document(forDocumentId:inVolume:)`, `dateMetadataByDocumentKey`, the parser | REPORTING: reading accounting |
| `cross_references` | References in and out, broken ones excluded | `CrossReferenceStore.inboundEdges`, `outboundEdges` | E3 |
| `related` | Related documents, ranked, with the reason for each | `RelatedDocumentsEngine.rank` | — |
| `persons` | The people in a document; a person's documents and career; every count a lower bound | `PersonMentionStore`, `POCOMIndex` | KNOWN TRAPS: person counts |
| `glossary` | Abbreviations and terms | `glossaryLookup`, `allTerms(forVolumeId:)` | — |
| `source` | Where a document came from: repository, record group, series and NAID, with decimal-file labels read only for the document's own date | `SourceExplorerResolution`, `ArchivalResolver` | ARCHIVAL SCOPE |
| `archival_scope` | Came-from and pointed-at units over a scope, labelled by channel and never summed | `CollectionUsageIndex`, `ExternalCitationIndex`, `externalCitations` | ARCHIVAL SCOPE |
| `neighbours` | A document's nearest neighbours, as leads | SemanticVectorsKit | guide §14.17, §A.8 |
| `meaning_search` | Documents near a text query, as leads, once the parity gate is passed | SemanticVectorsKit and an embeddings server (SRC-16, SRC-17) | guide §A.7, §A.8 |

Code alone calls what writes the deliverables, and no model sees these as tools: the citation
formatter (`CitationStyle.makeFormatter()`, `FRUSCanonicalURL`), the excerpt check
(`ExcerptVerifier.verify(_:bodyTexts:)`), page lookups (`PageRangeStore`), the method appendix
(`QueryMethodAppendix`), the provenance statement (`ProvenanceStatement`) and the collection writer
(`NativeCollectionSerializer`).

### 9.3 No SQL tool in the first release

The guide's method is written for an agent that writes SQL, and its traps are the ways SQL goes
wrong (guide §7, §9). A local model with raw SQL is the combination those traps describe, and the
catalogue above covers guide §6's patterns without it. So the first release has no SQL tool
(§21, decision 8). If one is built later it MUST be operator-only, open a read-only connection
whose authorizer denies `summary_text`, `note_text`, `user_tag_ids`, `user_tags`, `user_content`
and every write, refuse `rowid`, write its results to disk, and give the model guide §12's block as
its rules.

---

## 10. Runs, rounds and templates

Alvey's unit of work is the guide's round, run as a pipeline of short steps that the orchestrator
sequences. Each step's kind is *code*, or *model* with its role. The ordering rules of guide
§12 and §14 are carried by the order of the steps, not by an instruction to the model.

### 10.1 The brief

- **BRF-1** A brief MUST carry: the question as the researcher typed it; the scope (every indexed
  volume, a volume list, a date range, or a FRUS Explorer collection or working corpus read from an
  export, §7.5); the template; the model profile; the deliverables wanted; the budget (wall clock,
  tokens, and whether to run only on mains power); the pre-registered reading floors for documents
  read and quoted (guide §9 item 8); and the gates (§10.5).
- **BRF-2** A brief is frozen when its run starts, and its SHA-256 goes in the run record. A changed
  brief starts a new run that names its predecessor.
- **BRF-3** Alvey MUST refuse to start a run whose sources fail their checks on open (§7), and
  MUST say which check failed.

### 10.2 The scoping round

A scoping round reads nothing. Its product is the scope memo and the reader's summary, the bottom
line's first three paragraphs (guide §14.16).

| Step | Kind | What it does | Rules it carries |
|---|---|---|---|
| S0 | code | Opens every source read-only and proves it with a write that must fail (guide §2). Runs the coverage query. Makes one canary call per role's model against a known answer (guide §14.12 item 7; `Planning/Agentic-Harness-Runbook.md` §1). Any failure stops the run before a model step. | COVERAGE; the environment proof |
| S1 | code | Builds the candidate volumes from the brief, applies the Ed2 fold, and reads each candidate volume's chapter headings. | SCOPING: edition fold, editors' headings (guide §14.8) |
| S2 | model: planner | Proposes term families from the question and the headings: the editors' formulas, the era's own terms, the counterpart's vocabulary (guide §14.6), acronyms and variants. States a reason for each. Produces no counts. | SCOPING: vocabulary (prompted) |
| S3 | code | Measures each family: index counts as N of M; STRICT and TOLERANT literal shares on the sample of 40, or a census under 300; the TEI variant split on a declared counting surface; the false-friend concentration against the control phrase (guide §14.5); the decade shape per 1,000 dated non-apparatus documents with the top volume's share. A positive and a negative control run in the same pass and fail the step if either fails. | KNOWN TRAPS (a), (b); SCOPING: controls, surface, variants, false friends, decade shape, periodisation |
| S4 | model: planner | Keeps, revises or drops each family on S3's numbers, with reasons. May send new families back to S3, for as many iterations as the budget allows. Proposes the scope (volume set and inclusion rule) and the definitional decisions the question leaves open. | SCOPING (prompted, measured by S3) |
| S5 | code | Resolves the archival scope of the proposed scope through the kits: came-from and pointed-at, each labelled, never summed (guide §14.11). | ARCHIVAL SCOPE |
| S6 | code | Runs each absence the planner proposes as a logged search, with its terms, volumes and controls, over the unfiltered surface with the apparatus exclusion lifted (guide §9 item 6). | REPORTING: empty results; guide §14.6 |
| S7 | model: writer | Writes the scope memo's prose and the bottom line's three paragraphs from ledger lines cited by id. Code renders every number, citation and list. | READER-FACING OUTPUT |
| S8 | code | Verifies (§11) and stops at the scope gate (§10.5). | — |

### 10.3 The reading round

| Step | Kind | What it does | Rules it carries |
|---|---|---|---|
| R0 | code | Builds the reading list from the approved scope, ranked by search order, cross-references, related documents and, where the brief allows, vector neighbours. Sizes it in documents and characters against the reading floors. | guide §14.17 (vectors as leads) |
| R1 | model: reader, in parallel | Reads each document whole. A document longer than the reader's context is read in parts, and counts as read in full only when every part was read (guide §3, §9 item 8). Returns per document: relevance and to which thread, what it shows in at most a set number of words, quotation requests as exact text, actors, dates, and the documents it points to. Code re-locates every quotation (§11.1). An unlocated quotation goes back to the reader once with its passage; if it still fails, it is dropped and counted. | REPORTING: quoting, reading accounting |
| R2 | code | Follows the cross-references and pointers the readers raised, within the budget. Attaches persons and archival source to each document read (§9). | IDENTITY; ARCHIVAL SCOPE |
| R3 | model: planner | Forms three to six findings from the ledger, each with the document keys and quotation ids it rests on, placed in the narrative the documents give (guide §14.16). | prompted |
| R4 | model: writer | Writes the overview finding by finding, citing ledger ids. Code writes "how this was done" and "documents cited" from the ledger. | READER-FACING OUTPUT |
| R5 | code | Builds the collection: headings that follow the overview, entries in date order, a `prose` entry per heading (the writer's), a note per document (from R1, edited by the writer), an `excerpt` for every quotation the overview relies on, and the manifest companion (guide §14.16 item 3, §15.1a). | §15 |
| R6 | code, then model: refuter | Code re-runs every decisive count, re-derives each by an alternative route (guide §9 item 5) and re-locates every quotation in a fresh read. Then the refuter model, given the overview and the ledger, looks for what code cannot see: an inflated reading, a quotation that does not say what its sentence says, a superlative without its scope (guide §14.12, §14.13). Its findings send R3 and R4 back once. | guide §14.12 |
| R7 | model: critic | Gives CONTINUE or STOP with the evidence guide §14.15 asks for, in that order. Code supplies the mechanical lists: numbers re-derived, artifacts not opened, documents named and never read. | guide §14.15 |
| R8 | code | Verifies (§11), writes the deliverables (§12) and stops at the release gate (§10.5). | — |

### 10.4 Other templates

- **TPL-1 Batch extraction.** One schema applied to every document of a set (a collection exported
  from FRUS Explorer, a volume, or a search's results). The schema is the researcher's or one of
  Alvey's: correspondents, date, decision points, persons named verbatim, places, topics. Writes a
  CSV with a column per field and the evidence offsets beside each value. Every extracted string is
  re-located like a quotation; an unlocated value is flagged and never kept silently. This is the
  workload the owner has already measured (§18).
- **TPL-2 Document dossier.** One document with its text and footnotes, cross-references both ways,
  related documents with the reason each is related, the persons in it with their careers, its
  archival source and the series its footnotes point at, and a short reader's summary with verified
  quotations. Writes a short memo and a one-document collection.
- **TPL-3 Exploratory session.** A bounded loop over the tool catalogue (default 30 tool calls) for
  a question the researcher is still forming. Quotations and citations are verified as everywhere
  else, it is labelled exploratory in every view and file, none of its numbers is a finding, and it
  ends with a draft brief for a scoping round.

### 10.5 The researcher's gates

- **GATE-1 Scope.** After a scoping round the researcher reads the bottom line and the open
  decisions, sets each decision, edits the scope, then approves or stops. A reading round MUST NOT
  start without this approval.
- **GATE-2 Spot check.** Before release the researcher opens five rows in FRUS Explorer by deep
  link: the extremes and three at random (guide §9 item 4). They mark each one "as claimed" or not.
  A mismatch blocks release until it is explained.
- **GATE-3 Release.** The researcher reads the verification report (§11) and releases the
  deliverables. Nothing leaves the run folder before release, and everything that does carries the
  run id.
- **GATE-4** A batch template MAY set its gates to notify and continue. The move from a scoping
  round to a reading round is never automatic.

### 10.6 Context discipline for small windows

- **CTX-1** A model step's prompt is assembled from four parts: a role card; only the rules that
  bear on the step, drawn from a rules registry keyed by step and tool; the step's inputs as ledger
  lines; and the output schema. Each rule in the registry is the guide's text, cited by section, so
  a revision of the guide moves Alvey's text with it, through a reviewed change. A step never
  inherits another step's transcript.
- **CTX-2** The stable part of a prompt (role card, rules, tool definitions, schema) comes first and
  the inputs last, so that the server can reuse a cached prefix across a batch of reader steps
  (§8.7).
- **CTX-3** Alvey budgets every prompt against the model's loaded context length. It counts tokens
  as the server reports them where it can, and otherwise at the corpus's measured 4.16 characters a
  token (`NER-RUNBOOK.md` §4.1), correcting the estimate from each response's usage figures.
- **CTX-4** Retrieved text is fenced and labelled as a document, and the role card says that a
  document's words are evidence, not instructions (PRIV-6).

### 10.7 Budgets, checkpoints and resume

- **RUN-1** Before launch Alvey estimates the run's time and tokens from the calibration of each
  role's model on this machine (§17) and the brief's scope, and shows the estimate with its basis.
  A run whose estimate exceeds its budget asks before it starts.
- **RUN-2** Each step's result is committed to disk before the next step starts. After a crash, a
  quit, a sleep or a lost server, a run resumes at the first uncommitted step.
- **RUN-3** A model step's cache key is the SHA-256 of its exact request bytes together with the
  model's identity (§8.2), the harness runbook's rule (`Planning/Agentic-Harness-Runbook.md` §3).
  A resumed run reuses a step only when both match, and the record lists the reused steps.
- **RUN-4** A dead step's partial output is a claim, not a result (guide §14.12 item 6). A retried
  step starts fresh, and the record keeps both attempts.
- **RUN-5** The operator can pause, resume and cancel. A cancelled run's folder is complete up to
  its last committed step.

---

## 11. Verification and rule enforcement

### 11.1 The verifiers

- **VER-1 Quotations are re-located.** A quotation is stored as a document key, a start and an end
  offset into the text the run retrieved, and its text. The model's string is located by exact
  match, then by a match that folds only whitespace and quotation-mark forms and maps back to exact
  offsets, and by nothing fuzzier. A quotation with an ellipsis is a sequence of fragments, each
  located this way and in order. Alvey MUST apply the check FRUS Explorer applies to an excerpt
  before every export (`FRUSCoreKit/Export/ExcerptVerifier.swift`; guide §14.16 item 3), so that a
  quotation Alvey releases is one FRUS Explorer accepts. Lengths are counted in Unicode scalars,
  which is what SQLite's `length()` counts. Swift's `String.count` counts grapheme clusters and is
  never used for accounting (guide §12 KNOWN TRAPS, characters against bytes).
- **VER-2 Numbers are traced.** Every numeral and number-word in a reader-facing deliverable MUST
  match a trace-table row, except inside the citations, dates and URLs that code wrote. When one
  does not, the writer step is re-run once with the list. If it still does not, the sentence is
  removed and the removal recorded, which is guide §12's own remedy: "Add the row for any you cannot
  find, or take the number out, and say you did."
- **VER-3 Citations are checked.** Every cited key exists in the index copy. Every document the
  overview cites is in the collection, and every collection entry exists (guide §14.16).
- **VER-4 Reader-facing lint.** Checks the overview and the collection's prose and notes for SQL,
  the index's table and column names, document keys outside a history.state.gov URL, file paths and
  issue numbers (rubric O1), and for bare percentages. It flags sentences over 30 words, technical
  words left unexplained ("stem", "hits", "returned", "TEI", "cosine", "Hamming", "cluster"), and
  every *only*, *first*, *earliest*, *last*, *never* and *none* with no scope beside it (guide
  §14.13). A failed check blocks release; a flag is shown to the researcher.
- **VER-5 Reading is measured.** Documents read whole, documents quoted and passages quoted, with
  the whole/partial split, computed from the ledger and set against the brief's floors (guide §9
  item 8).
- **VER-6 Counts are refuted.** Each decisive count is re-derived by an alternative route: a
  distinct-document count against a join count, the index against the TEI where both exist.
  A disagreement is a finding and blocks release until it is explained.
- **VER-7 The log declares what it shortened.** The memo's log ends with an `ELIDED:` line that code
  writes from what it shortened for display. The log on disk is never shortened (guide §12
  REPORTING; §14.15a).

### 11.2 The rule matrix

Each row is a C-3 rubric item (`Planning/c3-reader-test/RUBRIC.md`) and the guide §12 rule behind
it.
**Structural** means no model output can break the rule. **Checked** means a verifier blocks
release when the rule is broken. **Prompted** means the rule depends on the model and is examined by
the refuter, the critic or the researcher.

| Item | Rule | How Alvey carries it | Class |
|---|---|---|---|
| C1 | Run the coverage query first and report it | Step S0 of every run; the result goes into the memo, the overview's scope sentence and the run record | Structural |
| C2 | Every count is conditional on the library | The renderer prints the library's volume count with every count, and the scope sentence is generated | Structural |
| I1 | Cite by `volume_id/document_id` | Tools return document keys; code writes the memo's citations from keys and the overview's through FRUS Explorer's formatter | Structural |
| I2 | Never use `rowid` | No tool returns one, and no model has SQL (§9.3) | Structural |
| I3 | Join on the pair | Joins happen inside the kits, and no tool accepts a bare document id | Structural |
| E1 | Exclude front matter and editorial notes | The default of every tool; the brief's `includeApparatus` is recorded with each call; absences re-run with it lifted | Structural |
| E2 | Never read `summary_text` or `note_text` | No tool reads them, every search excludes them (TOOL-6), and no model has SQL | Structural |
| E3 | Exclude broken cross-references | The cross-reference tool filters them | Structural |
| T1 | Porter stemming | Results carry the matched stem beside the surface form, and every phrase count carries its literal shares | Structural |
| T2 | `citation_era` is not a date | Never exposed as a time field | Structural |
| T3 | Never combine came-from and pointed-at | The archival tools return a channel with no union value, and the renderer refuses a sum across channels | Structural |
| R1, P6 | The query behind every number | Every number is a ledger line pointing at a tool call whose full input and generated SQL, regex or scan specification are on disk | Structural |
| R2, P5 | "N of M" | A count is a value with numerator, denominator, grain and a file listing its members; the renderer cannot print a bare percentage | Structural |
| R3 | Verify an empty result | Every zero triggers the tool's relaxed re-run and a positive control, recorded beside it | Structural |
| R4 | Flag thin results | The renderer flags small counts and scopes whose relevant volumes are mostly unindexed | Checked |
| S1 | Controls in the same pass | Every scan runs both controls and fails if either fails | Structural |
| S2 | State the counting surface | The TEI scan requires a surface and every result carries it | Structural |
| S3 | Expand variants and report the split | Code generates the mechanical variants; the planner adds acronyms and the era's forms; the scan refuses a single literal and reports the split | Structural and Prompted |
| S4 | Periodise on document dates | Timeline tools read only the document dates the kits derive | Structural |
| S5 | The Ed2 fold | Applied by default to every scope and recorded | Structural |
| A1, A2 | Came-from and pointed-at units | Step S5 resolves both over every scope | Structural |
| A3 | Label channels, never sum | The channel type | Structural |
| A4 | Open the bundled archival artifacts | The kits' resolvers read them | Structural |
| A5, A6 | Name and resolve archival targets | The resolvers' output; the bottom line's second paragraph is rendered from resolved series | Structural as far as the bundled indexes reach, reported as unresolved beyond them |
| P1 | Literal share for the question's own terms | Every phrase count carries both shares | Structural |
| P2 | A change claimed over time is measured on both sides | Timelines return both periods; the refuter checks the claim | Checked |
| P3 | Quote only what this run retrieved | VER-1 against the ledger | Structural |
| P4 | Documents read, apart from documents matched | VER-5 | Structural |
| O1 | No SQL, column, id pair or path in the overview | VER-4 | Checked |
| O2 | Every overview number traced | VER-2 | Checked |
| O3 | The three-part bottom line | The overview's template has the three paragraphs; the second is rendered from resolved series and the third from logged absence searches | Structural |
| — | `ELIDED:` line | VER-7 | Structural |
| — | Prose for a historian: "I", one claim to a sentence, terms explained | VER-4 flags; the reader judge (§17) | Prompted and Checked |

Of the rubric's 35 items, this design makes 30 structural (A5 and A6 as far as the bundled indexes
reach) and four checked, and shares one with the model (S3). The 2026-08-31 assessment's count for
a tool surface alone was 12 to 16 of the ~40 rules, about 20 with a corpus scanner. The reader
judge's five items are outside the rubric and stay with the model.

### 11.3 What stays with the model

The model chooses vocabulary and recognises the era's and the counterpart's terms (guide §14.6). It
drafts the definitional decisions, judges relevance, reads, finds the narrative, writes the prose,
and as critic decides whether another round would learn anything. These are what calibration
measures (§17) and what the refuter, the critic and the researcher examine. Every run lists them
as model-dependent in its colophon (DEL-2).

---

## 12. Deliverables

- **DEL-1 The memo** (Markdown), guide §14.16 item 1. It holds the coverage, the sources and their
  digests, every step, every count with its query or scan specification, the controls, surfaces,
  shares and denominators, the trace table, the VECTORS section (the word "none" when the vectors
  were not used), every refuted number with what refuted it, and the `ELIDED:` line.
- **DEL-2 The overview** (Markdown, with RTF and HTML renderings), in guide §14.16 item 2's order:
  the bottom line's three paragraphs, the scope, the decisions it needs from the researcher, three
  to six findings, how it was done, what to read next, and the documents cited. It ends with
  Alvey's colophon: the models and their calibration, the Alvey version and the kit commit, the
  rules enforced and the rules left to the model, and a plain statement that a language model
  drafted the prose and code checked every quotation, number and citation.
- **DEL-3 The collection** (`.fruscollection`), guide §15 and §15.1a, written as §13.3 specifies.
- **DEL-4 The run record** (§15): the guide's kit for the operator (guide §14.16 item 4), never for the
  historian.
- **DEL-5 Optional files**: the reading list (CSV: date, volume title, printed number, header and
  URL, with the key pair beside them; the guide's manifest companion), the batch extraction CSV
  (TPL-1), the method appendix in FRUS Explorer's own shape (§13.3), and a research-data import
  file (§13.3).
- **DEL-6** Every deliverable carries the run id and the Alvey version. Before the release gate
  (GATE-3) a deliverable exists only as a draft inside its run folder.

---

## 13. Interoperability with FRUS Explorer

Every surface in §13.1 to §13.4 exists in FRUS Explorer 1.0 today. Alvey needs no change to FRUS
Explorer to work. §13.6 lists the changes that would make the two apps fit better, each its own
decision.

### 13.1 Shared identity

- **IO-1** A document is its key, `(volumeId, documentId)`, in Alvey as in the index and every
  FRUS Explorer file format. Its public address is the canonical URL
  `https://history.state.gov/historicaldocuments/<volumeId>/<documentId>`, written by
  `FRUSCanonicalURL`. Its address in FRUS Explorer is `frusexplorer://document/<volumeId>/<documentId>`.
  That is the only route FRUS Explorer accepts from outside: both ids must be of
  `[A-Za-z0-9_-]`, and query strings and fragments are ignored (`DeepLinkRoute`,
  `FRUSExplorer/App/AppActivityTypes.swift:228-277`).

### 13.2 From FRUS Explorer to Alvey

| Surface | Where the researcher finds it | What Alvey takes from it | Requirement |
|---|---|---|---|
| Export Research Database… (Mac only) | Settings ▸ System ▸ Data & Recovery | The index copy, its provenance and its views | SRC-1 to SRC-7 |
| Copy Research-State Record | Settings ▸ Volumes & Storage ▸ Advanced ▸ Index Health | The versions and volume list a hand-made copy lacks | SRC-5 |
| Export as JSON (format version 7) | Settings ▸ System ▸ Data & Recovery | The researcher's curation, when the brief opts in | SRC-19 |
| A collection's `.fruscollection` | The collection's Export sheet | A seed, and the historian's feedback | SRC-20, §13.4 |
| The embedder on disk | Settings ▸ Volumes & Storage ▸ Natural-Language Search ▸ Model File | The pinned query encoder, loaded into LM Studio | SRC-15 |
| The Volumes and vectors folders | Inside FRUS Explorer's container, granted once | The exact TEI files and the shards | SRC-9, SRC-14 |

### 13.3 From Alvey to FRUS Explorer

- **IO-2 The collection is the way back.** Alvey builds a `CollectionExport` and writes it with the
  kits' `NativeCollectionSerializer.makeFile(from:includeNotes:resolveNoteTexts:)` and
  `encode(_:)` (`FRUSCoreKit/Collections/NativeCollectionFormat.swift:419`, `472`), so the file
  has the shape FRUS Explorer's own files have. Its contents follow guide §15.1a:
  - the bottom line in `introductionText`; the one-line answer in `note`; the run in `authorLine`
    (`Alvey <version>, run <id>, <date>, <model>`), which prints on the title page of every export;
  - headings that follow the overview, a `prose` entry under each saying why these documents, and
    a closing `prose` entry naming the threads the round could not follow;
  - on each document, one short note opening with an attribution line naming the run and the date,
    because an imported note carries no author (guide §15.1a, limit 2);
  - an `excerpt` for every quotation the overview relies on, carrying its text and its document
    pair as guide §15.1a's example does. Alvey does not write the optional anchors. They are UTF-16
    offsets into the reader's flat text at a rendering version
    (`NativeCollectionFormat.swift:232-239`), a text Alvey never renders, and FRUS Explorer checks
    an excerpt's wording against its document without them;
  - a `generated` `archivalSources` block at the end, and `chronology` at the top for a question
    about a crisis;
  - `formatVersion` 2 with `minimumReaderVersion` 1 (guide §15.3), and a `generator` key. FRUS
    Explorer ignores the key and, by design, drops it on re-export (guide §15.3), so the stamp that
    lasts is `authorLine`.
- **IO-3 The file is checked before it is written.** Alvey runs guide §15.2's checks in code: the
  extension, the format gate, the six composition keys, both ids on every document entry, no
  duplicate pairs, every pair present in the index copy, and no first edition beside its Ed2. An
  entry missing an id opens in FRUS Explorer and exports as nothing, with no error anywhere
  (guide §15.2). Alvey also runs `ExcerptVerifier.verify(_:bodyTexts:)` on every excerpt, so the
  check FRUS Explorer makes before every export, and again when a corrected volume arrives, passes.
- **IO-4 Opening it.** Alvey hands the file to FRUS Explorer by bundle id
  (`bottsywattsy.FRUS-Explorer`), as FRUS Explorer hands RIS files to Zotero
  (`FRUSExplorer/App/SupportingViews.swift:1457-1466`). FRUS Explorer imports it as a new
  collection in the active project, and opens a byte-identical file only once a session
  (`FRUSExplorer/App/FRUSExplorerApp.swift:2436-2479`).
- **IO-5 Deep links.** Every document Alvey shows has *Open in FRUS Explorer*, which opens its
  `frusexplorer://` address. If FRUS Explorer has not downloaded the volume, the link lands on its
  Volume Not Downloaded state, which offers the download. A volume FRUS Explorer's manifest lacks
  gets an alert (`FRUSExplorerApp.swift:3614-3626`). The memo carries the deep link for every
  document it cites. The overview carries only the history.state.gov URL, the one id-bearing string
  guide §12 allows there.
- **IO-6 No import file in the first release.** Import from JSON would accept an Alvey file: any
  file that decodes is imported, and it can add notes, tags, tag assignments and summaries. But
  four facts make that unsafe today:
  - a note has no author field, so an Alvey note becomes indistinguishable from the researcher's
    own (`FRUSCoreKit/Export/ResearchDataEnvelope.swift:302-348`);
  - a summary's `authorship` has three values, and the default means "produced by the on-device
    summarizer (Apple Intelligence)" (`FRUSCoreKit/Models/SummaryTypes.swift:85-92`), so an Alvey
    summary would be attributed to Apple Intelligence;
  - an import deletes nothing, and importing an old file again brings back records deleted since
    (`FRUSExplorer/Export/ResearchDataImporter.swift:397-399`);
  - a file that carries `syncedPreferences` applies them and syncs them to every device (`:145-183`).

  So Alvey writes no import file until FX-1. When it does, it MUST leave out `summaries` and
  `syncedPreferences` unless FX-1 has made them attributable. It MUST mark every record as FX-1
  provides. And it MUST show the kits' `ResearchImportPlan(file:library:)` report, run against the
  researcher's latest JSON export, before it hands the file over.
- **IO-7 The method appendix in FRUS Explorer's shape.** The query log behind "how this was done"
  is rendered by the kits' `QueryMethodAppendix` from `RecordedSearch` values, so it reads as FRUS
  Explorer's own appendix does (guide §14.16).
- **IO-8 Citations in the researcher's style.** The kits' formatter writes them
  (`CitationStyle.makeFormatter()`), in the style the researcher picks in Alvey. FRUS Explorer's
  own setting lives in its defaults, and Alvey does not read it.
- **IO-9 Handoff (MAY).** FRUS Explorer declares the activity `com.joshbotts.frus-explorer.document`
  with `volumeId` and `documentId` (`FRUSExplorer/App/AppActivityTypes.swift:17`). Alvey MAY
  advertise the same activity for the document it shows, so FRUS Explorer on the researcher's iPad
  can continue it. Handoff between two apps of one team is UNVERIFIED here and needs a device test.

### 13.4 The round trip

1. Alvey's collection opens in FRUS Explorer (IO-4).
2. The historian reads it, tags documents, adds and removes some, writes notes, and may turn it into
   research targets with Add to Archives Visit… (guide §14.16).
3. They export the collection with "Include my research notes" on, and may also Export as JSON.
4. Alvey reads the export as the next round's seed (SRC-20). It shows the difference from what it
   wrote: documents added and removed, notes added and edited. The historian's additions become
   threads to follow, and their notes are context, never sources.

### 13.5 Shared code

Alvey compiles the kits as §5.3 describes. The inventory of their public API at `4556c4d` found
these gaps. Each one, when Alvey needs it closed, is a small pull request here (REPO-3):

| Gap | Today | What Alvey needs |
|---|---|---|
| KG-1 | No reader for the export's `research_provenance` or its views | A kit reader. Until then, Alvey reads the table with plain SQLite. |
| KG-2 | The Meaning search funnel (filter intersection, result rows) is app code, in `FRUSExplorer/Semantic/SemanticQuerySearcher.swift` | Moved into the kits without the llama encoder, so a text query ranks the same in both apps |
| KG-3 | Tier-2 shard fetching and verification are app code (`SemanticShardFetcher`) | Moved into the kits, with a type for the shard manifest |
| KG-4 | `IndexingResources`' initialiser is internal (`IndexingSeams.swift:153`), so a host cannot supply the collection-alias fallback, and its archival neighbours can differ from the app's (`IndexingPipeline.swift:11940`) | A public way to supply it |
| KG-5 | `DocumentSubjectIndex.subjects(forDocument:)` and `hierarchy(forDocument:)` are internal | Public |
| KG-6 | The one-call document fetch (`fetchCache`) is private, and `extractDateRange` and `sameInstantDay` are internal | Public, if the tools need them |
| KG-7 | Collocates are app code (`FRUSExplorer/Search/CollocationService.swift`) | Moved into the kits, if the planner's tools need them |

### 13.6 Changes to FRUS Explorer that would help

None is required, and each is the owner's decision.

| Row | The change | What it gives Alvey | What it touches |
|---|---|---|---|
| **FX-1** | Provenance for records another app writes: an author or source mark on notes, a `SummaryAuthorship` value for an outside model, and a top-level `alvey` key that the import view names, as it names FRUS Explorer Light's (`FRUSCoreKit/Export/ResearchImportPlan.swift:712-729`) | Notes and summaries that FRUS Explorer attributes honestly (IO-6) | `SummaryAuthorship` is stored by raw value in `GeneratedSummary.authorship`, whose CloudKit field already exists, so a new case adds no field. But a build on another device that predates the case meets a value it cannot read, and the row must say what that build does. A note author is a new stored property, so it goes through the #488 gate. |
| **FX-2** | *Analyze with Alvey…* on a collection, which writes the collection's file and opens it with Alvey by bundle id | A brief starts from the app's own curation in one step | The Mac's collection menus; no format change |
| **FX-3** | A shared App Group container where FRUS Explorer writes its research database export on request | No save panel between the apps, and "the newest export" always in one place | Entitlements on both apps (there are none today) and a sandbox decision |
| **FX-4** | The import alert names a collection file's `generator` | The researcher sees which run made a file as they open it | The import path. The stamp is still dropped on re-export, as guide §15.3 says it must be. |

App Intents (the A7 design, deferred by decision 57, #1723) would give Alvey nothing it needs that
the routes above lack.

---

## 14. Privacy, security and safety

- **PRIV-1 Hosts.** Alvey connects to the model servers named in its settings. Only when the
  researcher asks does it connect to the TEI source (`raw.githubusercontent.com/HistoryAtState/frus`,
  and `api.github.com` for a historical blob, SRC-9) and the vector shards' host
  (`raw.githubusercontent.com/joshbotts/frus-semantic-vectors`, SRC-14). It connects to no other
  host. It has no analytics, crash reporting or telemetry of any kind.
- **PRIV-2 Sandbox.** Alvey is sandboxed with outgoing network access and user-selected file
  access, the capabilities FRUS Explorer's Mac app has
  (`FRUSExplorer/FRUSExplorer-AppStore.entitlements`,
  `FRUSExplorer/FRUSExplorer-DirectDistribution.entitlements`). It reaches each source through a
  security-scoped bookmark the researcher grants once.
- **PRIV-3 The researcher's writing.** The export leaves the researcher's writing out by default
  (guide §2). When the copy's `research_provenance` says it was included, Alvey says so on the
  source's page and in the run record, and no tool reads those columns either way (rubric E2).
- **PRIV-4 Shared curation is opt-in.** Collections, tags, working corpora and notes read from a
  FRUS Explorer JSON export (§7.5) reach a model only when the brief says so. Every prompt labels
  them as the researcher's material. They are never a source, never quoted, and their use is
  recorded.
- **PRIV-5 A server on another Mac.** When the model server is not on this Mac, Alvey says on the
  brief that prompts, document text and any shared curation will cross the local network. It sends
  the server's API token when one is configured, and LM Studio's tokens are off by default (LMS-2).
  It refuses an address outside the loopback and private ranges unless the operator overrides it,
  and records the override.
- **PRIV-6 Documents are data.** Retrieved text and tool output are fenced in every prompt (CTX-4).
  No tool has an effect outside the run folder, so an instruction inside a document can at worst
  mislead one step, and the verifiers and the refuter look at every step.
- **PRIV-7 Read-only, proven.** Step S0 proves every source read-only before any model step (§10.2).
- **PRIV-8 Secrets** (a server's API token) are kept in the Keychain and never written to a run
  record or a log.
- **PRIV-9 Model weights.** Alvey distributes none and downloads none. The researcher manages
  models in LM Studio.

---

## 15. The run record and reproducibility

The run record answers guide §13's table without the operator assembling it.

| Guide §13 row | Where Alvey takes it from |
|---|---|
| Date of the copy | The export's `research_provenance`; for a hand-made `.backup`, the file's date, labelled as such |
| App build and version | `research_provenance` |
| Index format version (and the FTS schema version) | `research_provenance` and the index's own stamps |
| Indexed volume list | The sorted list, saved whole |
| Subject vocabulary digest | `SELECT DISTINCT digest FROM document_subject_volumes` |
| The vector artifacts' generation | `provenanceDigest` and `generated` of the semantic index, `generated` of the map index |
| The queries | Every tool call, with its full input, the SQL, regex or scan specification it ran, and its result counts |
| Whether the copy holds the researcher's writing | `research_provenance`, or counted for a hand-made copy |
| Models, sessions, run id, cost | Per step: the model key, the weights file's SHA-256, quantization, format and engine, LM Studio's version and runtime version, loaded context length, sampling parameters, seed and reasoning mode; prompt and completion tokens; wall clock; retries and failures |
| The exact text each agent was given | Every request body, byte for byte |
| Tool versions | Alvey's version and build, the kit commit (§5.3), SQLite's version, macOS's version, the chip and its memory |

Alvey adds what the guide's table predates: the TEI files used, each with the git blob SHA-1 and
size that index version 75 records for the file the index was built from (§7.2); the bundled
JSON's digests; the calibration each role's model was assigned on; the gates, with when each was
passed; thermal and power events.

- **REC-1** The record is a JSON file and a JSONL transcript in the run folder, plain files
  readable without Alvey.
- **REC-2 Replay.** Alvey can re-execute a run's tool calls against the same sources and compare
  each result with the recorded one. Tool results are code and MUST match exactly. Generations are
  not expected to (§8.11), so a replay re-checks the numbers and quotations, not the prose.
- **REC-3** A run folder can be exported as one archive for the researcher's records or a
  colleague, with the researcher's shared curation left out unless they include it.

---

## 16. User interface

A Mac app in the house's idiom: a sidebar window, SwiftUI throughout.

- **UI-1 Library.** Each index copy with its provenance (FRUS Explorer's version, the index
  version, the volumes, whether it holds the researcher's writing, its date) and the result of
  its checks; the TEI cache's coverage of it; the bundled JSON's version; the vectors' status and
  the query encoder's parity (§7.4).
- **UI-2 New run.** The question; the scope (volumes, dates, or a collection or working corpus from
  a FRUS Explorer export); the template; the model profile; the budget, floors and gates; and the
  estimate with its basis (RUN-1).
- **UI-3 Run.** The steps as a timeline with their status; the current step's output as it
  streams; every tool call with its input and result; the ledger's counters (documents read whole,
  quoted, passages, quotations not located); tokens, time, the server's state and the thermal
  state; pause, resume and cancel; the gate panels.
- **UI-4 Deliverables.** The overview rendered, the memo, the collection's outline and the
  verification report, every check with its result and reason. *Open in FRUS Explorer* on every
  document and on the collection.
- **UI-5 Evidence.** Every quotation with its document, offsets and verification status, and a deep
  link to the document in FRUS Explorer.
- **UI-6 Models.** The servers, their loaded models, the profiles, and each model's calibration on
  this machine.
- **UI-7 Two audiences.** A historian's view shows the deliverables, the gates and the evidence,
  with no tool calls or token counts. The operator's view shows everything (guide, opening, and
  §14.16 item 4).
- **UI-8** A local notification when a gate needs the researcher or a run ends. An option keeps the
  Mac awake while a run is active and the Mac is on mains power.

---

## 17. Calibration and evaluation

### 17.1 Calibrating a model for a role

A calibration belongs to one model file, at one quantization, under one LM Studio runtime, on one
machine, and Alvey re-runs it when any of the four changes.

- **CAL-1 Schema adherence.** The share of valid outputs over a fixed set of structured requests on
  fixture documents.
- **CAL-2 Tool calls.** Validity of native tool calls and of the structured-action protocol (§8.5),
  measured separately.
- **CAL-3 Verbatim fidelity.** The share of quotation requests located verbatim on fixed passages:
  the sweep's `unlocated` measure, against its own denominator (`NER-RUNBOOK.md` §4.7's warning).
- **CAL-4 Relevance.** Agreement with a labelled set of documents for a fixed question (§22).
- **CAL-5 Speed.** Prefill and decode rates and seconds per reader step on this machine, at one
  request and at the server's parallel slots, sustained long enough to see throttling.
- **CAL-6 Reasoning control.** Proof that the model's think and no-think settings change its
  completion length as configured. The sweep's lesson is that a run manifest cannot see a
  server-side toggle (`NER-RUNBOOK.md` §4.8.2).
- **CAL-7 Floors.** Alvey refuses to assign a model to a role whose calibration falls below the
  role's floor. The owner sets the floors (§22).

### 17.2 Accepting Alvey itself

- **EVAL-1** The C-3 question (guide §3a) runs through Alvey with each candidate profile, on the
  Studio and on the Air. The C-3 instruments score it, blind to the arm: the 35-item scorer, the
  refuter and the reader judge, as `Planning/c3-reader-test/` holds them. The result is compared
  with the nine Claude cells already recorded there. The instruments are cloud models (Claude
  Fable 5.1 at `max`, as in C-3), run by the owner as development tooling. Nothing in Alvey calls
  them.
- **EVAL-2** The reading is pre-registered and frozen before launch, as C-3's design was. The
  proposed reading: every structural item of §11.2 passes in every run, and a failure there is a
  bug in Alvey, not a finding about a model; the refuter finds no misquotation; every headline
  number re-derives; the reader judge's five items and the wall clock are reported against the
  Claude cells without a pass mark, until the owner sets one.
- **EVAL-3** At least one second question, taken from the later C-3 tiers (vectors, steering or
  reader-facing), so that no conclusion rests on one question, which is the limit guide §3a states
  for its own table.
- **EVAL-4** Every tool is tested against a fixture index built through the kits (their test
  support already builds one), and every verifier against seeded failures: a quotation one
  character off, a bare percentage, a column name in the overview, a count without its
  denominator.
- **EVAL-5** A mock model server makes the pipeline's tests deterministic, as the embedding
  harvester was verified against a mock `/v1/embeddings` before it was handed over
  (`Planning/M2-Semantic-Pipeline-Ride-Along.md` §5).

---

## 18. Performance model

### 18.1 The measured anchors

Every figure here is from the owner's two machines and the record that holds it.

| Measurement | Mac Studio, M1 Max, 64 GB | MacBook Air, M5, 32 GB | Record |
|---|---|---|---|
| Qwen3 14 B no-think, Q8_0, about 670 prompt tokens a chunk | 4.68 s a chunk | 19.27 s a chunk, averaged over 4.4 fanless hours | `NER-RUNBOOK.md` §4.8.2 |
| The same with its reasoning trace on | — | about 735 generated tokens a chunk where about 25 were needed; decode about 5.7 tokens/s against a ceiling near 10 | `NER-RUNBOOK.md` §4.7 |
| Four parallel requests | 3.9× in an 8-chunk burst; 1.55× sustained over 330,979 chunks | not measured | `NER-RUNBOOK.md` §4.8.2, §4.8.3 |
| Memory bandwidth | 400 GB/s | 153 GB/s | `NER-RUNBOOK.md` §4.2 |
| LM Studio against `llama-server`, embeddings | — | LM Studio's engine 2.57.0 at 0.85–0.88× `llama-server`'s rate | `tools/semantic-harvest/README.md`, field notes 2026-10-14 |

The derived table in `NER-RUNBOOK.md` §4.2 was once wrong by two orders of magnitude, and its own
banner says nothing in it should be treated as a budget. The same holds here: Alvey's estimates
come from its calibration on the machine (CAL-5), never from this section.

### 18.2 What the anchors decide

- **Generation is the scarce resource.** The recommended Claude cells emitted about 170,000 output
  tokens a run (guide §3a). At the 14 B's measured 5.7 tokens a second on the Air, 170,000 tokens
  would be about eight hours of decode alone **[DERIVED]**. So Alvey keeps generation short:
  structured outputs, notes of bounded length, and code-written tables, lists, citations and
  method text (P1, P3).
- **Reading is prefill.** A reader step takes a whole document and the stable prefix in and gives a
  few hundred tokens out. Prefix caching (CTX-2) and the server's parallel slots on the Studio
  (§8.8) are its levers. The Air is about four times slower a step and throttles over hours, which
  favours several resumable sessions over one long one (`NER-RUNBOOK.md` §4.2).
- **Reasoning is a setting with a price.** Reader and extraction roles default to no-think (§8.6),
  and the planner's and critic's reasoning is capped by `max_tokens`.
- **Mixture-of-experts models** generate at a rate set by their active parameters, which suits the
  writer and planner roles on paper. A0 measures whether it does (§20).

### 18.3 Estimating a run

- **PERF-1** Alvey estimates a run as the sum over its steps of uncached prompt tokens over the
  prefill rate, generated tokens over the decode rate, and a per-request overhead, with the rates
  and a throttle factor from CAL-5. It shows the estimate with its basis, and refines it as steps
  complete.
- **PERF-2** A brief MAY say "run only on mains power" and "pause above a thermal state". The run
  record keeps every pause.

---

## 19. Accessibility and localization

- **A11Y-1** FRUS Explorer's standards apply (`Planning/FRUS-Explorer-Specification.md` §18):
  VoiceOver labels, hints and traits on every custom view; text that follows the system size;
  contrast of at least 4.5:1; colour never the only carrier of meaning; full keyboard operation;
  Reduce Motion respected.
- **A11Y-2** HTML deliverables SHOULD use the kits' reader stylesheet (`ReaderPage`), whose
  contrast `ReaderPageTests` already gates, rather than a stylesheet of Alvey's own.
- **L10N-1** Every user-facing string uses `String(localized:)`. The first release writes its
  deliverables in English. The prompts are English, and deliverables in another language would be
  a change to the role cards, measured by calibration.

---

## 20. Phasing

The repository's convention is that a strategic item enters as an assessment ending in a
build/no-build recommendation (L-8, `Planning/Agentic-Loop-Development-Plan.md`). Alvey enters the
same way.

| Phase | What it delivers | Gate |
|---|---|---|
| **A0 Assessment** | A headless prototype, the `alvey` command over the kits, runs the C-3 question's scoping and reading rounds with two candidate profiles on the Studio and on the Air, scored as EVAL-1 to EVAL-3. Ends with BUILD, BUILD NARROWER (for example batch extraction and dossiers only) or NO-BUILD. | The owner's verdict on the record |
| **A1 Foundation** | AlveyKit's core tools over the index copy (coverage, search, phrase counts, reading, metadata, outlines, cross-references); the LM Studio client with its two guards; structured outputs; the ledger; VER-1, VER-3, VER-5 and VER-7; batch extraction (TPL-1) and the dossier (TPL-2); deep links; the collection writer; the run record | A0's BUILD |
| **A2 Scoping** | The TEI surface (download and verification); variant scans; controls; false friends; timelines; the archival tools; the writer with VER-2 and VER-4; the scope gate; the scoping round | A1 complete |
| **A3 Reading** | The reading round; refuter and critic; spot-check and release gates; the full overview and collection; the calibration suite; EVAL-1 rerun on the app | A2 complete |
| **A4 Reach** | A server on another Mac; parallel requests; thermal policy; the vectors and the query encoder behind the parity gate; curation from a JSON export; the import file; replay; any FX row the owner approves (§13.6) | A3 complete |

---

## 21. Owner decisions

Each decision has a recommendation, which stands in for it until the owner decides.

1. **Whether to build.** *Recommended:* run A0 first and decide on its record, as L-8 was decided.
2. **Repository.** *Recommended:* a separate repository that compiles the kits from a pinned
   commit, as FRUS Explorer Light does (§5.3). *Alternative:* a target in this repository, which
   avoids pin moves but couples Alvey's releases and tests to this repository's.
3. **Platform.** *Recommended:* macOS only in the first release. The index copy, the TEI and LM
   Studio all live on a Mac, and the guide's export is Mac-only.
4. **Distribution.** *Recommended:* a notarized direct download first, the App Store once the
   sandbox story is proven on a release.
5. **Corpus access.** *Recommended:* the export only in the first release. *Alternative:* the
   shared container of FX-3, for a live index.
6. **TEI source.** *Recommended:* download each volume and verify it against the blob SHA-1 the
   index records (§7.2), with FRUS Explorer's own Volumes folder, granted once, as the alternative.
7. **Write-back.** *Recommended:* collections only in the first release. Notes and tags through
   Import from JSON wait for FX-1 (§13.6).
8. **The SQL tool.** *Recommended:* absent from the first release (§9.3).
9. **Model roster and machine.** No recommendation until A0 has measured one.
10. **Gate defaults.** *Recommended:* as §10.5.
11. **A cloud backend.** *Recommended:* out of scope. Alvey's case is the local one (§1.2).
12. **Licence.** *Recommended:* Apache 2.0, as this repository is, since Alvey compiles its kits.
13. **The name.** The About window's sentence on where the name comes from is the owner's to write.
14. **The guide.** Whether `Docs/Agentic-Analysis-Guide.md` gains a short section pointing to
    Alvey, once Alvey exists.

---

## 22. Placeholders requiring future input

- The role floors for CAL-7, set from A0's record.
- A labelled relevance set for CAL-4: a fixed question, and documents the owner has judged.
- The default model profiles, after A0.
- The minimum LM Studio version, after A0 checks the features §8 relies on.
- The range of index format versions Alvey supports, set in A1 against the pinned kit.
- The app icon and the About text.

---

Version history:

- 0.1 — 2026-11-23: first draft, for the owner's review.
