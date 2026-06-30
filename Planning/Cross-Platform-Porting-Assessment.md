# FRUS Explorer — Cross-Platform Porting Feasibility & Effort Assessment

*Prepared 2026-06-30 · Measured against the repository at `/Users/jbotts/Development/FRUS-Explorer`, branch `v2`*

> **About this document.** This brief synthesizes three internal analyses: a measured architecture/coupling inventory of the codebase, a cross-platform strategy survey, and a Claude-Code-assisted build/budget framework. It is intended for the project owner and collaborators. It is balanced and honest about uncertainty, not a sales pitch. Figures marked ⚠️ — especially Claude Max pricing/limits — must be re-verified before any external sharing or budget commitment.

---

## 1. Executive summary

- **A port is feasible, and the codebase is unusually well-positioned for one.** Roughly **a third of the ~87k LOC of shipping code is pure, platform-agnostic logic** (TEI parsing, FTS5 search, citation) already isolated in `import Foundation`-only files with near-zero `#if os` branching — and it is backed by a **~46k-LOC test suite** that can validate any reimplementation regardless of UI.
- **The cost concentrates in three seams, not the whole app:** the **SwiftUI view + multi-window layer (~45–50%, ~40k LOC must be rewritten)**, **SwiftData + CloudKit persistence/sync** (replace with a new local store + sync backend), and **Apple FoundationModels on-device AI** (the single biggest gap — no drop-in cross-platform equivalent). All three already sit behind clean protocol/actor/container boundaries.
- **Do not pursue three separate native rewrites** (Web in TS, Windows in C#, Android in Kotlin). The view layer is the *small* part; the heavy logic would be re-implemented 3× more, on top of the existing Swift copy. Only justified with a large per-platform team.
- **Two defensible shared-codebase paths.** Choose based on whether you want to eventually retire the Swift apps. **(A) Kotlin Multiplatform + Compose Multiplatform** — one logic core, can target all platforms and eventually subsume the Apple apps; highest ceiling, steepest learning curve, Compose-for-Web still Beta. **(B) Web-core (TypeScript + SQLite-WASM/OPFS) wrapped by Tauri 2 (Windows) and Capacitor (Android)** — fastest to three new platforms, reuses the already-HTML renderer almost verbatim, keeps the Swift app for iOS/macOS; lower native-feel ceiling.
- **Recommended path:** start with the **Web-core route (B)** because it delivers Web, Windows, and Android from one build and reuses the most portable subsystems first — *then* reassess KMP once the sync and AI gaps are de-risked. The two routes share the same hard decisions (sync backend, AI backend), so early spike work is not wasted either way.
- **Claude Code is a strong force-multiplier on the mechanical 60–80% of the work** (view porting, translation, test scaffolding) but a human must own architecture, the sync backend, release signing/notarization, and on-device QA. Plan calendar time around the human-driven 20–40%, not agent throughput. A single Max seat plus modest API-credit overage is a small cost relative to engineering time.

---

## 2. What the app is, and why it is currently Apple-coupled

FRUS Explorer is an **offline-first, data-heavy reading and research app** for the State Department's *Foreign Relations of the United States* series. Users download TEI XML volumes from GitHub at runtime; the app indexes them **on-device** into a SQLite FTS5 store and renders them as HTML. On top of that sit notes, tags, highlights, collections, cross-reference graphs, citation export, term-frequency analytics, and on-device AI summarization — with user data synced across the user's own devices via iCloud.

The Apple coupling is real but **concentrated**, not pervasive. Measured import footprint across shipping code (files importing each framework):

| Framework | Files | Framework | Files |
|---|---:|---|---:|
| SwiftUI | 79 | CloudKit | 2 |
| SwiftData | 63 | BackgroundTasks | 2 |
| Foundation | 111 | ActivityKit | 2 |
| WebKit | 4 | FoundationModels | 2 |
| UIKit / AppKit | 4 / 4 | NaturalLanguage | 1 |

**Conditional-compilation load:** 66 files contain `#if os(...)`, 322 total branch lines — but this is an **iOS-vs-macOS** seam, not an Apple-vs-non-Apple one. A third platform inherits those 322 branch points. Crucially, the branching is concentrated in UI/glue; the pure-logic areas are nearly free of it (**TEI 1/11 files, Models 1/27, Citation 1/9**).

**Scale (raw `wc -l`, includes comments/blank lines):**

| Bucket | Files | LOC |
|---|---:|---:|
| App target (`FRUSExplorer/`) | 185 | 85,034 |
| `FTS5Store` (SPM lib, compiled in) | 7 | 2,134 |
| Live Activity widget ext. | 2 | 185 |
| **Shipping app code** | **194** | **~87,353** |
| Tests | ~75 | ~45,759 |
| **Repo total (excl. `.build`)** | **~305** | **~116,242** |

The largest port hotspots are the SwiftUI view files and the **4,921-LOC `IndexingPipeline.swift`** (the TEI→FTS5 ingestion engine — which, despite its size, is portable). Note also a structural signal: the iOS and macOS settings screens are **duplicated** (`SettingsView.swift` 3,592 + `FRUSSettingsView.swift` 3,348 ≈ 6,940 LOC of parallel UI). The team already maintains two SwiftUI variants; a third platform multiplies that UI cost.

The app is Apple-coupled because it leans on the convenient, free, OS-provided Apple stack: SwiftUI for UI, SwiftData+CloudKit for zero-backend synced persistence, FoundationModels for free on-device AI, plus smaller niceties (Live Activities, BGProcessingTask, CoreSpotlight, Keychain sync). None of these have a single cross-platform equivalent — but most are replaceable, and the genuinely valuable logic does not depend on them.

---

## 3. Portability assessment by subsystem

Ratings: **PORTABLE** (reuse as-is or trivially reimplement) · **REPLACEABLE** (clean swap exists) · **HARD-BLOCKER** (rewrite / re-architect / drop).

| Subsystem | Rating | Replacement on other platforms | Risk |
|---|---|---|---|
| **TEI parser → AST → render nodes** (~5,155 LOC) | PORTABLE | Reimplement in Kotlin/TS, or reuse logic; output is already portable HTML. Uses Foundation `XMLParser` (exists in swift-corelibs-foundation). | Low — the crown jewel; well-tested |
| **FTS5 search** (`FTS5Store`, `SearchService`) | PORTABLE | Native SQLite+FTS5 everywhere; SQLDelight (KMP) or SQLite-WASM/OPFS (web). Confirm FTS5+BM25 compiled into WASM build. | Low |
| **IndexingPipeline** (4,921 LOC) | PORTABLE (2 trivial guards) | Strip a single UIKit memory-warning observer and optional CoreSpotlight; the TEI→FTS5 + persons/dates/cross-refs engine is pure. | Low |
| **Citation engine** (formatter, parser, BibTeX/RIS) | PORTABLE | Pure string logic, thorough tests; 1/9 files touch SwiftUI. | Low |
| **Person clustering / authority crosswalk** | PORTABLE | Foundation heuristics + bundled JSON. | Low |
| **Cross-reference graph** | PORTABLE (model) / REPLACEABLE (view) | Data/layout model ports; the 1,989-LOC Canvas view is reimplemented per UI framework. | Medium (view) |
| **WKWebView document host + JS** (offset/highlight/selection) | REPLACEABLE | WebView2 (Windows/Tauri), Android WebView (Capacitor), DOM (web). Injected JS is plain DOM code, reusable. Host + custom URL-scheme handler reimplemented per platform; contract is small and clean. | Low–Medium |
| **NaturalLanguage NER** (word-cloud lenses, 1 file) | REPLACEABLE | Transformers.js/ONNX Runtime, or classic ICU/dictionary tokenization fallback. Quality/locale differs from Apple. | Medium |
| **Swift Charts** (3 files) | REPLACEABLE | ECharts/Victory/Recharts (web), Vico/Compose charts (KMP). Underlying data computed in portable logic. | Low |
| **Background downloads** | REPLACEABLE | Foreground HTTP trivially portable; OS-managed *background* transfer needs a platform substitute (WorkManager, etc.). | Low–Medium |
| **CoreSpotlight / Keychain sync** | REPLACEABLE / DROP | OS search + secure store substitutes exist; cross-device keychain nicety lost off-Apple. | Low |
| **NARA SourceExplorer / Zotero / DOCX-HTML export** | PORTABLE | HTTP+JSON and document-construction logic; PDF export (Core Graphics) is REPLACEABLE. | Low |
| **SwiftData + CloudKit user data** (63 files) | HARD-BLOCKER | New local store (GRDB/SQLite) + new sync backend (PowerSync recommended). Data *shapes* port; framework does not. | High |
| **SwiftUI view + multi-window scene layer** (~79 files) | HARD-BLOCKER (rewrite) | Compose Multiplatform or HTML/JS framework. Largest single cost; ~13 window scenes concentrated in `FRUSExplorerApp.swift`. | High |
| **FoundationModels on-device AI** (2 files) | HARD-BLOCKER | Cloud LLM API and/or per-platform on-device runtime (llama.cpp/ONNX/LiteRT) behind the existing `SummarizationProvider` protocol. | High |
| **BGProcessingTask background indexing** | HARD-BLOCKER (mechanism) / PORTABLE (work) | WorkManager (Android), desktop background thread (Windows), foreground/visible-tab on web. | Medium |
| **Live Activities / WidgetKit** (185 LOC) | HARD-BLOCKER / DROP | No equivalent off-Apple; replace with standard notifications/progress UI. Pure nice-to-have. | Low (droppable) |
| **App Sandbox / entitlements** | N/A off-Apple | Map to ordinary OS permissions (Android manifest, Windows MSIX/signing, web origin sandbox). | Low |

**Composition estimate:** Pure portable logic ~30–35% (~26–30k LOC, well-tested) · UI to rewrite ~45–50% (~40k LOC) · Apple-API glue ~15–20% (~15k LOC, mostly thin and behind clean seams).

**Bundled assets port verbatim.** ~14.4 MB of platform-neutral JSON (`subject-appearances.json` 9.09 MB, `central-files-index.json` 3.38 MB, `person-authority-index.json` 1.30 MB, `manifest.json` 735 KB, taxonomies, word-cloud lexicons/stopwords, and the reusable web-layer JS/CSS). The four SPM generators that produce them are developer-side macOS tooling, not shipped. Corpus TEI XML is downloaded at runtime from GitHub, so only the *background-transfer* mechanism is Apple-specific.

---

## 4. The hard problems

These three dominate the budget and the risk. Be explicit about them with stakeholders.

### 4.1 CloudKit + SwiftData → cross-platform offline-first sync

CloudKit is Apple-only and unreachable from Android/Windows/web. You must replace the **sync backend**, not just the local store. This is the most consequential decision because it changes your cost structure *and* your privacy story: CloudKit keeps user data in the user's own iCloud at zero backend cost; any hosted alternative means you (or a vendor) run and pay for a database and hold user data.

| Option | Fit | Consequence |
|---|---|---|
| **PowerSync** (recommended) | Syncs Postgres/MongoDB/MySQL → on-device SQLite (local source of truth) with an upload queue. Broadest 2026 client coverage: **KMP, Swift, web, RN, Flutter.** Best match given the app is already SQLite-centric. | You design server-side conflict resolution for notes/tags/highlights/collections; managed cloud from ~$49/mo (Free open-source edition exists). |
| ElectricSQL | Postgres→SQLite, very simple, open-source | Read-path focused; weak two-way write-conflict story for user data. |
| Turso / libSQL | Distributed SQLite with local replicas, offline support | SQLite-native without Postgres; newer sync semantics for rich two-way user data. |
| Replicache/Zero | Excellent web UX | Web/JS-only; Replicache in maintenance mode. Not for native mobile. |
| Firebase / Supabase / Parse (SashiDo) | Cross-platform BaaS, offline caching; Parse markets itself as a CloudKit-equivalent DX | Pulls you into a document-store model rather than your existing SQLite/FTS5 shape. |

**Realistic plan:** PowerSync, with a deliberate conflict-resolution design pass and a SwiftData→SQLite schema migration. Budget meaningful design + ops time. **Risk: HIGH.**

### 4.2 Apple FoundationModels on-device AI — the biggest gap

**There is no drop-in cross-platform equivalent to "a free, OS-provided, on-device model with a Swift API."** The map/reduce orchestration and prompt/template management are portable logic; only the provider is Apple-bound, and it already sits behind a 53-LOC `SummarizationProvider` protocol. Three options, all with real costs:

1. **Cloud LLM API** (Claude/Gemini/GPT) — easiest cross-platform, but **breaks the offline-first promise**, adds per-call cost and a privacy change, needs network. Best as an *optional* tier.
2. **Per-platform on-device runtimes** (keep offline, but fragmented): Android → Gemini Nano / LiteRT-LM / MediaPipe+Gemma / ONNX; Web → WebLLM or Transformers.js v4 (WebGPU; heavy first-load model download); Windows → ONNX Runtime / Phi-3 / Windows AI APIs / llama.cpp (GGUF). LiteRT-LM is emerging as a "universal" runtime but you still ship/quantize your own model and write per-platform glue.
3. **Drop summarization on non-Apple platforms initially**, ship later.

**Recommended:** keep FoundationModels on Apple; on other platforms offer **(a) optional cloud summarization** for parity now and **(b) a per-platform on-device runtime** as a later milestone. Do not assume one runtime cleanly covers Web + Windows + Android in 2026. **Risk: HIGH and unavoidable.**

### 4.3 The SwiftUI UI layer

The single largest rewrite cost — roughly the App (10.9k) + Settings (8.2k, duplicated) + Browser (3.7k) + Onboarding (2.7k) + Theme + the view half of every other area, plus ~13 window scenes concentrated in `FRUSExplorerApp.swift`.

- **KMP route:** **Compose Multiplatform.** iOS scroll physics now "matches native SwiftUI feel"; **Web is Beta** — accessibility for long scholarly documents is the specific area to prototype first.
- **Web-core route:** **HTML/CSS + a JS framework** (React/Svelte/Solid). For a *reading* app this is arguably the best fit, because the document view is already HTML.

**Risk: Medium** — most rewrite-heavy, but the best-understood layer.

---

## 5. Per-target plans

Each LoE range is in **person-months** (low / expected / high), counting *total human calendar effort including review and QA*, not raw agent-hours. Ranges assume a small team (1–2 engineers) using Claude Code as a force-multiplier on the mechanical portion (see §7). The single biggest swing factor across all three targets is whether on-device AI and full two-way sync are in-scope for v1 or deferred.

### Web

- **Recommended stack:** TypeScript + a JS UI framework (React/Svelte/Solid); **SQLite-WASM + OPFS** for FTS5/BM25; the **TEI→HTML renderer reused directly in the DOM**; **PowerSync (web SDK)** for sync; optional Transformers.js/WebLLM (WebGPU) for AI with a cloud fallback.
- **Ports cleanly:** TEI rendering (already HTML), FTS5 search, citation, analytics computation, bundled JSON, the JS highlight/offset engine, the test suite (as behavioral oracle).
- **Rebuilt / dropped:** entire UI; sync backend; AI provider; background indexing becomes foreground/visible-tab (Safari has no reliable background sync). **Live Activities dropped.**
- **Risk watch:** Safari PWA storage eviction (~7 days for non-installed PWAs — request persistent storage, design re-index-on-demand); no service workers in iOS WKWebView.
- **LoE: 4 / 7 / 11 person-months.** *Assumes:* AI shipped as optional cloud tier (not on-device) in v1; PowerSync as sync backend; renderer reused; UI is the dominant cost. Best ROI of the three — the web build also seeds the Windows and Android wrappers.

### Windows

- **Recommended stack:** **Tauri 2** (system WebView2, tiny binary, low memory) wrapping the web build; SQLite via the Rust side or SQLite-WASM. *(KMP-route alternative: Compose Multiplatform desktop/JVM + SQLDelight. .NET MAUI/WinUI 3 only if you commit to a .NET shop — strongest native Windows integration but no Web help.)*
- **Ports cleanly:** everything the web build already produces; native SQLite is straightforward; foreground downloads + desktop background thread for indexing.
- **Rebuilt / dropped:** Windows packaging/code-signing/MSIX; on-device AI via ONNX/llama.cpp if offline AI is wanted; tray/window-management polish.
- **LoE: 1.5 / 3 / 5 person-months — *incremental, assuming a web build already exists.*** Mostly wrapper, packaging, native-integration polish, and Windows-specific QA. As a standalone from-scratch effort it would be far higher; the low number is the whole point of doing Web first.

### Android

- **Recommended stack (highest quality):** **KMP shared core + native Kotlin/Jetpack Compose**, FTS5 via SQLDelight, PowerSync (Android SDK), Gemini Nano/LiteRT or ONNX on-device. **Faster/lower-ceiling alternative:** **Capacitor wrapping the web build** (Android's WebView avoids the iOS WKWebView caveats).
- **Ports cleanly:** the shared logic core (KMP) or the entire web build (Capacitor); FTS5; renderer.
- **Rebuilt / dropped:** UI (Compose) if going native; background indexing via WorkManager; Play Store packaging; on-device AI runtime.
- **LoE:**
  - **Capacitor wrapper (after Web exists): 2 / 4 / 6 person-months** — wrapper, native shims, Play Store, device QA.
  - **Native KMP build: 6 / 10 / 16 person-months** — includes porting the logic core to Kotlin and a full Compose UI; higher quality, and the shared core becomes reusable for a future Apple migration.
  - *Assumes:* if KMP, the logic-core port is counted here and partially amortized into any later platform.

> **Note on additivity:** these ranges are **not** simply summed. Web-first makes Windows and Android *incremental* (wrapper + packaging + per-platform QA + AI). Doing all three as independent native builds would roughly **double or triple** the combined figure — which is the core argument of §6.

---

## 6. Strategy: separate native builds vs. one shared codebase

### Separate native implementations (Web in TS, Windows in C#/WinUI, Android in Kotlin)
**Not recommended for a solo/small team.** The view layer is the *small* part of FRUS Explorer; the bulk is indexing, FTS5 search, cross-reference, citation, TEI parsing/rendering, summarization orchestration, and sync. Three native apps means re-implementing all of that **3× in 3 languages, on top of the existing Swift copy = 4 copies of the hard logic.** Justified only if each platform needs deeply idiomatic UX *and* you have dedicated per-platform engineers.

### One shared codebase — two realistic shapes

**Route A — "Unify everything" (Kotlin Multiplatform + Compose Multiplatform).** Port the heavy logic into a KMP shared module once; SQLDelight for FTS5; PowerSync for sync; Compose UI on Android/Desktop/Web, retaining SwiftUI on Apple via interop (or migrating later). **Highest ceiling; one logic codebase; can eventually retire Swift.** Costs: steepest learning curve, Compose-for-Web is Beta, biggest upfront port. Several "production-ready 2026" KMP claims come from advocacy blogs; the strongest objective signals are JetBrains' own Beta announcement, Google's official KMP support, and named adopters (Netflix, Cash App).

**Route B — "Fill the gaps fast" (web core + wrappers).** Build a TypeScript web app (SQLite-WASM/OPFS + the already-HTML renderer + PowerSync + optional Transformers.js/WebLLM); ship **Web** directly, **Windows via Tauri 2**, **Android via Capacitor**. Keep the Swift app as the iOS/macOS implementation. **Fastest path to three new platforms; reuses the most portable subsystems; lowest learning curve.** Costs: a second codebase alongside Swift, lower native-feel ceiling, Safari/PWA storage caveats, weaker on-device AI on web.

### Recommendation

**Start with Route B (web core + Tauri/Capacitor wrappers).** Rationale:

1. It delivers all three requested targets (Web, Windows, Android) from one build, and front-loads the **most portable** subsystems (TEI→HTML rendering, FTS5).
2. It reuses the renderer *almost verbatim* because the output is already HTML — the highest-leverage reuse available.
3. The two genuinely hard decisions — **sync backend (PowerSync)** and **AI backend** — are identical under both routes, so the spike work (see §8) de-risks either future.
4. It does **not** require betting on Compose-for-Web (still Beta) for long-form scholarly text before that maturity is proven.

**Should the shared codebase also replace the existing Apple apps?** Not initially. Route B keeps the polished, native SwiftUI Apple apps as-is — there is no reason to regress a working, shipping product. Revisit a **KMP migration (Route A)** only if (a) maintaining two codebases proves costly, and (b) Compose-for-Web accessibility for long documents has matured in a prototype. Treat that as a *future* strategic option, not a v1 commitment.

---

## 7. Building it with Claude Code

### What Claude Code can realistically do here

**Delegate aggressively (mechanical 60–80% of the work):**
- **Cross-language/cross-platform translation at scale** — re-expressing the TEI parser, citation engine, indexing logic, and models in Kotlin/TS. Vendor-reported best cases: Wiz migrated ~50k lines Python→Go in ~20 hours (scoped at 2–3 months); a Scala→Java port did ~10k lines in 4 days (vs ~10 engineer-weeks) — **~10–30× on the mechanical portion** (⚠️ best-case *library* ports; discount for greenfield).
- **Agentic navigation of the large SwiftUI codebase** — greps and follows references on the live repo rather than a stale index; well-suited to the 322 `#if os` branch points.
- **Repetitive view porting, scaffolding, and test generation** — the bread-and-butter of a platform port.

**A human must drive (do not delegate blind, ~20–40%):**
- **Architecture decisions** — choosing the sync backend, target app structure, data-model boundaries.
- **The sync-backend / data migration** itself (SwiftData→SQLite + PowerSync conflict policy) — high-stakes, modifies the data layer.
- **Release engineering** — Windows code-signing/MSIX, Android Play Store, Apple notarization/entitlements. Not in any cited capability claim; human-owned.
- **On-device QA** — FoundationModels behavior, WebGPU AI performance, Safari/PWA storage eviction, background indexing, real-device CPU. The agent writes code; it does not qualify it.

**Central caveat:** Claude Code's effectiveness is gated by codebase legibility. The headline multiples assume good setup (layered `CLAUDE.md`, scoped lint/test commands, subagents). This repo already has much of that (root `CLAUDE.md`, XcodeGen as source of truth, an auto-memory index, a large test suite) — favorable, but the new target codebases will need the same scaffolding built up.

### Suggested human + agent workflow

1. **Human:** make the two architecture decisions (sync = PowerSync; AI = cloud tier now / on-device later) and run the de-risking spike (§8).
2. **Agent:** port the pure-logic kernel (TEI, FTS5, citation, indexing) to the target language, validated continuously against the **existing ~46k-LOC test suite** translated as the behavioral oracle.
3. **Agent:** scaffold the UI and repetitively port views; **human** reviews for correctness and idiomatic feel, fixes hallucinated APIs, steers.
4. **Human:** own the sync integration, packaging/signing, and device QA. **Agent** assists with glue and test scaffolds.
5. Keep one human reviewer per active agent workstream — **review is the real bottleneck**, not agent throughput.

### Max-plan usage budget framework

> ⚠️ **Re-verify all Claude Max pricing and limits before committing or sharing externally.** Anthropic stopped publishing exact usage numbers in May 2026 and now publishes only relative multipliers. The numbers below are a mix of official tiers and independent-testing estimates.

**Tiers (official):** Pro $20/mo (1× baseline) · **Max 5x $100/mo** ("5× per session") · **Max 20x $200/mo** ("20× per session"). Claude Code, Claude.ai chat, and Cowork draw from **one shared pool**. Two reset clocks: a **5-hour rolling window** and **weekly limits** (Max carries two: one all-model, one Sonnet-specific; **Opus is the scarcer, separately-throttled bucket**). At the cap you can enable API-credit overage (pay-as-you-go), upgrade, or wait.

**⚠️ Estimated absolute numbers (independent testing, hold loosely):** weekly hours Max 5x ~140–280 Sonnet + 15–35 Opus; Max 20x ~240–480 Sonnet + 24–40 Opus. A common heuristic: ~$13 equivalent API spend per developer per active day. ⚠️ A **May 13, 2026 +50% weekly promotion was set to expire ~July 13, 2026** — i.e. right after this brief; confirm whether it has lapsed.

**Budget method (size in KLOC, split mechanical vs human-driven, bracket low/expected/high):**

- **Agent-hours per KLOC of *mechanical* code:** low ~0.5 · expected ~1.5 · high ~3 hr/KLOC. Add **0.5–1.5 human-review-hours per agent-hour**.
- **Weekly throughput ceiling (⚠️ estimated):** Max 5x ~25–40 productive agent-hrs/wk; Max 20x ~60–120 for one heavy user. **Months ≈ total agent-hours ÷ (weekly throughput × seats).**
- **Seats = concurrency:** one Max 20x seat per active human reviewer; add a shared Max 5x for lighter exploration. Adding seats beyond review capacity wastes money.
- **Overage:** low +0% (stay inside Max 20x) · expected +15–30% of subscription as API credits for spike weeks · high +50–100% if running multiple concurrent Opus-heavy agents past the weekly Opus ceiling.

**Worked illustration — one platform, ~30 KLOC net new, 70% mechanical (21 KLOC) / 30% human (9 KLOC):**

| Scenario | Agent-hrs (mech.) | Seats | Calendar | Subscription | + Overage |
|---|---|---|---|---|---|
| **Low** | ~11 hr | 1× Max 5x | <1 mo agent-time; human review dominates | $100/mo | +0% |
| **Expected** | ~32 hr | 1× Max 20x | ~2–3 mo incl. human-driven 30% + QA | $200/mo | +15–30% (~$30–60) |
| **High** | ~63 hr | 2× Max 20x | 3–4+ mo incl. sync backend + signing + device QA | $400/mo | +50–100% (~$200–400) |

**Headline:** calendar time is dominated by the human-driven 20–40% (architecture, sync, signing, device QA), **not** by agent throughput. Even the high scenario's subscription ($400–800/mo) is small relative to engineering time — so optimize seats for **review capacity** and treat the Max subscription as the cheap input.

---

## 8. Risks, unknowns, and recommended next step

### Key risks and unknowns
- **Sync (HIGH):** leaving CloudKit means standing up and paying for a backend, designing a conflict-resolution policy for notes/tags/highlights/collections, migrating the schema, and **changing the privacy story** (user-owned iCloud → vendor-held data).
- **On-device AI (HIGH):** no single 2026 runtime cleanly covers Web + Windows + Android + Apple at FoundationModels-level convenience; expect a cloud tier now and fragmented per-platform on-device runtimes later, or accept a feature gap.
- **Compose-for-Web is Beta (Route A unknown):** accessibility for long scholarly documents is unproven — prototype before any KMP commitment.
- **Web storage (MEDIUM):** Safari PWA eviction and no reliable background sync constrain the web target; design re-index-on-demand and request persistent storage.
- **Estimate confidence:** LoE ranges assume Claude-Code-assisted mechanical porting at the cited (discounted) multiples and AI deferred to a cloud tier in v1. Real numbers depend on how much UX polish and offline-AI parity v1 demands.
- **⚠️ Max pricing/limits** must be re-verified (see §7).

### Recommended next step: a small de-risking spike (≈2–4 weeks, 1 engineer + Claude Code)

Before committing to any route, build a **thin vertical slice** that exercises the two hard seams together:

1. **Web shell** that loads SQLite-WASM/OPFS, indexes 2–3 real TEI volumes with **FTS5 + BM25**, and renders them via the **existing HTML serializer** in the DOM — confirming the most portable subsystems work end-to-end off-Apple.
2. **PowerSync** wired to a minimal backend, syncing **one user-data type** (e.g., highlights) two-way with a deliberate conflict case — validating the sync replacement and surfacing the conflict-resolution design cost early.
3. **One summarization call** behind the `SummarizationProvider` interface against **both** a cloud API and a small on-device WebGPU model — measuring the real AI gap (latency, model download size, quality) on actual hardware.

This slice directly attacks the three highest-risk items (sync, AI, off-Apple FTS5/render), is reusable under either Route A or B, and converts the biggest unknowns into measured numbers before any large commitment.

---

## Sources

*Carried through from the strategy and budget analyses. Several "production-ready 2026" KMP claims originate from vendor/advocacy blogs; the strongest objective signals are JetBrains' own announcements, Google's official KMP page, and named adopters. ⚠️ All Claude Max absolute numbers are independent-testing estimates, not official — re-verify.*

**Kotlin Multiplatform / Compose:**
- https://www.kmpship.app/blog/is-kotlin-multiplatform-production-ready-2026
- https://developer.android.com/kotlin/multiplatform
- https://volpis.com/blog/is-kotlin-multiplatform-production-ready/
- https://blog.jetbrains.com/kotlin/2025/09/compose-multiplatform-1-9-0-compose-for-web-beta/
- https://kotlinlang.org/docs/wasm-overview.html
- https://kotlinlang.org/docs/multiplatform/compose-swiftui-integration.html
- https://touchlab.co/compose-swift-bridge-launch
- https://vocal.media/01/compose-multiplatform-for-i-os-production-readiness-in-2026

**SQLite FTS5 (KMP + WASM):**
- https://sqldelight.github.io/sqldelight/2.3.0-SNAPSHOT/android_sqlite/fts5_virtual_tables/
- https://wsoh.released.at/blog/bundledsqlitedriver/
- https://github.com/subframe7536/sqlite-wasm
- https://blog.ouseful.info/2022/04/06/compiling-full-text-search-fts5-into-sqlite-wasm-build/
- https://sqlite.org/wasm/doc/trunk/persistence.md

**Offline sync engines / CloudKit alternatives:**
- https://queryplane.com/blog/electricsql-vs-powersync-vs-replicache/
- https://turso.tech/blog/local-first-cloud-connected-sqlite-with-turso-embedded-replicas
- https://dev.to/dataformathub/distributed-sqlite-why-libsql-and-turso-are-the-new-standard-in-2026-58fk
- https://www.sashido.io/en/sashido-vs-cloudkit
- https://blog.back4app.com/cloudkit-alternatives/
- https://slashdot.org/software/p/CloudKit/alternatives

**On-device LLM / NER:**
- https://developers.googleblog.com/on-device-genai-in-chrome-chromebook-plus-and-pixel-watch-with-litert-lm/
- https://developers.googleblog.com/litert-the-universal-framework-for-on-device-ai/
- https://docs.octomil.com/blog/on-device-llm-inference-2025-2026/
- https://github.com/ggml-org/llama.cpp/discussions/8273
- https://www.buildmvpfast.com/blog/on-device-llm-mobile-llama-ios-android-2026
- https://huggingface.co/docs/transformers.js/index
- https://www.pkgpulse.com/guides/transformersjs-vs-onnx-runtime-web-2026
- https://techcommunity.microsoft.com/blog/educatordeveloperblog/use-webgpu--onnx-runtime-web--transformer-js-to-build-rag-applications-by-phi-3-/4190968

**Desktop / RN-Windows / PWA frameworks:**
- https://www.pkgpulse.com/guides/best-desktop-app-frameworks-2026
- https://codenote.net/en/posts/cross-platform-dev-tools-comparison-2026/
- https://www.digisoftsolution.com/blog/dotnet-maui-vs-flutter
- https://www.tatvasoft.com/outsourcing/2026/02/net-maui-vs-flutter.html
- https://microsoft.github.io/react-native-windows/docs/new-architecture
- https://devblogs.microsoft.com/react-native/🚀react-native-windows-v0-82-is-here/
- https://www.magicbell.com/blog/pwa-ios-limitations-safari-support-complete-guide
- https://docs.bswen.com/blog/2026-04-07-browser-storage-quotas-eviction/
- https://capacitorjs.com/docs/web/progressive-web-apps
- https://capacitorjs.com/

**Charts:**
- https://lalatenduswain.medium.com/the-complete-guide-to-javascript-charting-libraries-in-2026-choosing-the-right-visualization-tool-dac9aeb15f60

**Claude Code capability & Max plans (⚠️ limits/pricing to re-verify):**
- https://claude.com/blog/how-claude-code-works-in-large-codebases-best-practices-and-where-to-start
- https://www.anthropic.com/product/claude-code
- https://code.claude.com/docs/en/large-codebases
- https://www.anthropic.com/engineering/claude-code-best-practices
- https://support.claude.com/en/articles/11049741-what-is-the-max-plan
- https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan
- https://www.morphllm.com/claude-code-usage-limits
- https://ccforeveryone.com/guides/claude-code-limits-and-pricing
- https://intuitionlabs.ai/articles/claude-max-plan-pricing-usage-limits
