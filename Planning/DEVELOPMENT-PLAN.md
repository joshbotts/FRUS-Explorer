# FRUS Explorer — Development Plan

**Version**: 1.1  
**Date**: 2026-05-14

Each task below corresponds to a single development session. Tasks are ordered so that each session's outputs are available as inputs for subsequent sessions. All sessions share the same Xcode workspace.

---

## Session Sequence

| # | Task | Key Output | Depends On |
|---|---|---|---|
| 01 | Project Setup & Build Configuration | Xcode project, SPM manifest, entitlements, two Mac configs | — |
| 02 | Manifest Generator Tool | `manifest.json`, `ManifestGenerator` executable | 01 |
| 03 | SQLite FTS5 Swift Wrapper (`FTS5Store`) | Reusable documented wrapper + tests | 01 |
| 04 | SwiftData Models & CloudKit Sync | All SwiftData model types + CloudKit configuration | 01 |
| 05 | Volume Download & Storage Manager | Download pipeline, queue, storage reporting | 02, 04 |
| 06 | TEI Parser — Core Elements (Layer 1 + 2) | Swift AST, rendering model, core element coverage | 01 |
| 07 | TEI Parser — Full Element Coverage | Complete element coverage, edge case fixtures | 06 |
| 08 | Subject Tag Bundle Integration | Taxonomy + appearance data loading, `SubjectTag` model | 04 |
| 09 | Search Index Pipeline | FTS5 indexing of volumes, summaries, notes, tags | 03, 05, 07, 08 |
| 10 | Onboarding View | Full onboarding flow, project creation, download initiation | 02, 05, 09 |
| 11 | Browser View | Corpus → subseries → volume → compilation → chapter hierarchy | 05, 06, 08 |
| 12 | Document View — Core | TEI rendering, toolbar, citation, tags below document | 06, 07, 08, 04 |
| 13 | Citation Formatter | `CitationFormatter` protocol, history.state.gov style, tests | 06, 12 |
| 14 | Research Note Editor | Note creation, tag selector, summary promotion, cross-project visibility | 04, 12 |
| 15 | Project & Global Context | AppState, project switching, activity tagging, global view | 04, 14 |
| 16 | Search View | Full composable search UI, all filter types, results list | 09, 08, 15 |
| 17 | Cross-Reference Graph — Data | Edge extraction during indexing, edge table queries | 09 |
| 18 | Cross-Reference Graph — UI | Canvas renderer, standard + fallback layouts, interaction | 17, 12 |
| 19 | AI Summarization — Core | `SummarizationProvider` protocol, Apple Intelligence implementation, chunking | 04, 06 |
| 20 | AI Summarization — UI & Prompts | Prompt management UI, schema templates, Document view integration | 19, 12, 15 |
| 21 | Background Summarizer | Concurrent background summarization, scope configuration, Settings integration | 19, 20 |
| 22 | Collection Editor & Export | Collection management UI, PDF + HTML export, share sheet | 04, 12, 14 |
| 23 | NARA Source Explorer | Source note parser, provenance switching, NARA API integration | 12 |
| 24 | Settings Screen | All settings panels, storage management, reindex, prompt management | 05, 09, 21, 23 |
| 25 | Global Context View | Aggregated reading history, notes browser, collections browser | 15, 14, 22 |
| 26 | About Screen & App Polish | About screen, attribution, links, disclaimers | All prior |
| 27 | Accessibility Audit & Fixes | VoiceOver, Dynamic Type, Reduce Motion, tap targets | All prior |
| 28 | OpenAPI Document Review & Finalization | Complete `FRUS-API.openapi.yaml` | All prior |
| 29 | Direct Distribution Build & Notarization | Sparkle integration, Developer ID signing, notarization workflow | All prior |
| 30 | Citation Lookup | Citation parser, page range store, matching engine, Citation Lookup view | 07, 09, 12, 16 |
| 31 | Final Integration Testing | End-to-end tests, performance testing, corpus-scale validation | All prior |

---

## Dependency Graph (simplified)

```
01 ──┬── 02 ──── 05 ──┬── 10
     │               │
     ├── 03 ──────────┤
     │               │
     ├── 04 ──────────┼── 08 ──── 09 ──┬── 16 ──┐
     │               │               │          │
     └── 06 ──── 07 ─┤               ├── 17 ── 18
                     │               │
                     └── 11          └── 21

12 ──┬── 13
     ├── 14 ── 15 ── 16
     ├── 18
     ├── 20 ── 21
     ├── 22
     └── 23

07 ──┐
09 ──┼── 30 (Citation Lookup) ── 31 (Final Testing)
12 ──┤
16 ──┘
```

---

## Task File Index

Present these files to Claude Code in order. The leading number matches the session number(s) inside each file.

| File | Sessions |
|---|---|
| `01-Project-Setup.md` | 01 |
| `02-Manifest-Generator.md` | 02 |
| `03-FTS5-Wrapper.md` | 03 |
| `04-08-Models-Parser-Tags.md` | 04, 05, 06, 07, 08 |
| `09-16-Search-Views.md` | 09, 10, 11, 12, 13, 14, 15, 16 |
| `17-24-Graph-AI-Export-Settings.md` | 17, 18, 19, 20, 21, 22, 23, 24 |
| `25-29-Polish-Audit-Distribution.md` | 25, 26, 27, 28, 29 |
| `30-Citation-Lookup.md` | 30 |
| `31-Final-Integration-Testing.md` | 31 |

---

## Notes for All Sessions

- Read `FRUS-Explorer-Specification.md` before beginning any session
- All code must compile under Swift 6 strict concurrency checking
- All user-facing strings must use `String(localized:)`
- All new types and functions require documentation comments
- `#if DEBUG` telemetry logging required for all significant operations
- Update `FRUS-API.openapi.yaml` if the session touches GitHub API or local volume data
- Run all existing tests before committing session output
- Each session produces its own unit tests

---

## Implementation Notes for All Sessions

### `lastModified` must be updated explicitly at the call site
`@Model` transforms stored properties into computed properties backed by persistent storage. `didSet`/`willSet` observers are syntactically accepted but do not fire reliably in practice. Any code that writes to a SwiftData model must set `instance.lastModified = .now` explicitly at the mutation site — never rely on an observer to do it automatically. This applies to every model type that carries `lastModified` (Session 04 models and any new models added in later sessions).

---

## Cross-Session Dependency Additions

The following items were added to earlier sessions by later feature requirements. Confirm they are implemented in the named session before beginning the dependent session.

### Session 07 — TEI Parser Full Coverage
**Added by Session 30 (Citation Lookup)**:
- `<pb>` element must be surfaced in the AST as `pageBreak(pageNumber: PageNumber)`
- `PageNumber` enum: `.arabic(Int)`, `.roman(Int)`, `.prefixed(String)`, `.unparseable(String)`
- Normalization rules for `@n` attribute values documented in Session 31 task file

### Session 09 — Search Index Pipeline
**Added by Session 30 (Citation Lookup)**:
- `page_ranges` SQLite table built during indexing pass alongside cross-reference edge table
- Schema and index definitions documented in Session 31 task file
- Population logic: extract `<pb>` nodes from AST, record document containment and section grouping
- `FRUS-API.openapi.yaml` updated with `GET /volumes/{volumeId}/page-ranges`
